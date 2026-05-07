# Safe Init Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Реализовать двухфазный init шаблона `project_template`: bash-фаза (`init.sh` с wipe `.git`, URL-валидацией, initial commit с трассировкой) + slash-фаза (`/init` с интервью по 6 темам и TODO-маркерами на пропусках).

**Architecture:** `scripts/init.sh` остаётся CI-friendly (тестируется через `test-template.sh`); пользовательский entrypoint — `/init` slash-команда (Opus, main-context), которая запускает `init.sh` и проводит интервью. Wipe `.git` гарантирует, что после init нет связи с репозиторием шаблона.

**Tech Stack:** bash 5+, sed (portable), git 2.x, Markdown (для CLAUDE.md/README.md/init.md), Claude Code slash-commands.

**Spec:** `docs/superpowers/specs/2026-05-03-safe-init-flow-design.md`

---

## File Structure

| Файл | Создать/Модифицировать | Ответственность |
|------|------------------------|-----------------|
| `scripts/init.sh` | Modify | Phase 1: проверки, замена плейсхолдеров, wipe `.git`, initial commit, optional `git remote add` |
| `scripts/test-template.sh` | Modify | Smoke-тест шаблона; обновить T5/T6 под `INIT_SKIP_GIT_RESET=1`; добавить T7 (полный init + URL-валидация) |
| `CLAUDE.md` | Modify | Добавить скелетные секции `## Контекст проекта / Стек / Команды сборки и проверки / Архитектурные правила` с TODO-маркерами; добавить подраздел `### Project-specific` в «## Красные линии»; заменить placeholder в «## Справочные пути» |
| `README.md` | Modify | Переписать раздел `## Быстрый старт` под новый flow (через `/init` в Claude Code, упоминание wipe и backup) |
| `.claude/plugins/project/commands/init.md` | Modify | Переписать slash-команду под двухфазный алгоритм (sanity → init.sh → интервью с TODO) |

**Не трогаем:** `AGENTS.md`, `content/.doc-root.yaml` (структура), `scripts/apply-overlay.sh`, `.gitignore`, `.env.example`.

---

### Task 0: Зафиксировать baseline (existing 4-param init)

В рабочем дереве уже есть незакоммиченные правки `init.sh` (4-параметровая версия), `content/.doc-root.yaml` (расширенный набор полей: code/title/description/style/editors), и нетракнутый файл `.claude/plugins/project/commands/init.md` (первая редакция slash-команды). Это baseline, поверх которого мы делаем новую работу. Коммит-сепаратор нужен, чтобы дальнейшие изменения были атомарными и легко ревьюились.

**Files:**
- Modify: `scripts/init.sh` (уже изменён, не правим)
- Modify: `content/.doc-root.yaml` (уже изменён, не правим)
- Create: `.claude/plugins/project/commands/init.md` (уже создан, не правим)

- [ ] **Step 1: Проверить текущее состояние**

Run:
```bash
git status --short
```

Expected output (порядок строк может отличаться):
```
 M content/.doc-root.yaml
 M scripts/init.sh
?? .claude/plugins/project/commands/init.md
```

Если статус другой — остановиться и сверить с пользователем. Возможно, baseline уже закоммичен.

- [ ] **Step 2: Прочитать существующие файлы baseline**

Прочитай (через `Read`):
- `scripts/init.sh` — должен содержать функцию `replace_in_file` и цикл по 4 плейсхолдерам;
- `content/.doc-root.yaml` — должен содержать `code: {{PROJECT_CODE}}`, `editors: - {{EDITOR_EMAIL}}` и расширенный набор properties;
- `.claude/plugins/project/commands/init.md` — содержит описание текущего 4-шагового алгоритма.

Цель шага — убедиться, что baseline не повреждён.

- [ ] **Step 3: Запустить test-template.sh, убедиться что зелёный**

Run:
```bash
bash scripts/test-template.sh
```

Expected: финальная строка `✓ Template smoke test PASSED`.

Если фейлится — остановиться и зафиксировать, что baseline сломан. Не двигаемся дальше до починки.

- [ ] **Step 4: Закоммитить baseline**

```bash
git add scripts/init.sh content/.doc-root.yaml .claude/plugins/project/commands/init.md
git commit -m "feat(init): baseline 4-параметровая версия init.sh + расширенный .doc-root.yaml + slash-команда

Закрепляет текущее состояние перед добавлением phase-2 (wipe .git, URL-валидация, TODO-интервью).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

Run:
```bash
git status --short
```

Expected: пустой вывод (working tree clean).

---

### Task 1: Обновить test-template.sh — пропускать git-reset через env-var (forward-compat)

Сначала готовим тесты к будущему изменению `init.sh`: добавляем `INIT_SKIP_GIT_RESET=1` в T5 и T6. Сейчас это no-op (init.sh не читает env-var), но после Task 2 это будет защищать тесты от wipe.

**Files:**
- Modify: `scripts/test-template.sh:75-99`

- [ ] **Step 1: Прочитать текущий test-template.sh**

Используй `Read` на `scripts/test-template.sh`. Запомни строки 78 (`bash scripts/init.sh "test-project" >/dev/null`), 90 и 93 (`bash scripts/apply-overlay.sh naumen-smp >/dev/null`).

- [ ] **Step 2: Заменить запуски init.sh / apply-overlay в T5/T6 на env-var-обёртку**

`Edit` в `scripts/test-template.sh`:

old_string:
```
# ===== T5: init.sh works =====
echo ""
echo "==> T5: init.sh substitutes PROJECT_NAME and creates branch"
bash scripts/init.sh "test-project" >/dev/null
```

new_string:
```
# ===== T5: init.sh works =====
echo ""
echo "==> T5: init.sh substitutes PROJECT_NAME and creates branch"
INIT_SKIP_GIT_RESET=1 bash scripts/init.sh "test-project" >/dev/null
```

- [ ] **Step 3: Запустить test-template.sh, убедиться что всё ещё зелёный**

Run:
```bash
bash scripts/test-template.sh
```

Expected: `✓ Template smoke test PASSED`. Env-var сейчас игнорируется; тест не должен поменять поведение.

- [ ] **Step 4: Commit**

```bash
git add scripts/test-template.sh
git commit -m "test(init): включить INIT_SKIP_GIT_RESET=1 в T5 (forward-compat для wipe-блока)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Добавить failing-test T7 — полный init создаёт ровно 1 commit с traceback'ом

TDD-цикл стартует здесь. Добавляем новый блок T7, который проверяет ещё-не-реализованное поведение wipe + initial commit. Тест должен **упасть** на этом шаге.

**Files:**
- Modify: `scripts/test-template.sh` (добавить блок после T6 перед `# ===== Summary =====`)

- [ ] **Step 1: Добавить T7 блок в test-template.sh**

`Edit` в `scripts/test-template.sh`:

old_string:
```
bash scripts/apply-overlay.sh --remove naumen-smp >/dev/null
assert "marker removed from CLAUDE.md" "! grep -q 'OVERLAY:naumen-smp:start' CLAUDE.md"

# ===== Summary =====
```

new_string:
```
bash scripts/apply-overlay.sh --remove naumen-smp >/dev/null
assert "marker removed from CLAUDE.md" "! grep -q 'OVERLAY:naumen-smp:start' CLAUDE.md"

# ===== T7: full init (wipe .git + initial commit) =====
echo ""
echo "==> T7: full init wipes .git and creates traceable initial commit"
TMP2="$(mktemp -d)"
rsync -a --exclude='.git' --exclude='.worktrees' "$REPO_ROOT/" "$TMP2/"
cd "$TMP2"
git init -q -b main
git -c user.email=tpl@example.com -c user.name=tpl commit --allow-empty -q -m "tpl baseline"
# Запуск init.sh БЕЗ INIT_SKIP_GIT_RESET — должен сделать wipe + initial commit
bash scripts/init.sh "smoke" "SMOKE" "Smoke test" "smoke@example.com" >/dev/null
COMMITS="$(git log --all --oneline | wc -l | tr -d ' ')"
assert "exactly 1 commit after init" "[ \"$COMMITS\" = '1' ]"
assert "commit message contains Template:" "git log -1 --format=%B | grep -q '^Template: '"
assert "main branch exists" "git show-ref --verify --quiet refs/heads/main"
assert "private branch exists" "git show-ref --verify --quiet refs/heads/private"
assert "no origin remote (no URL passed)" "[ -z \"$(git remote)\" ]"
assert "PROJECT_NAME replaced in CLAUDE.md (T7)" "! grep -q '{{PROJECT_NAME}}' CLAUDE.md"

# T7.b: URL-валидация — URL шаблона должен быть отвергнут
TMP3="$(mktemp -d)"
rsync -a --exclude='.git' --exclude='.worktrees' "$REPO_ROOT/" "$TMP3/"
cd "$TMP3"
git init -q -b main
git -c user.email=tpl@example.com -c user.name=tpl commit --allow-empty -q -m "tpl baseline"
set +e
bash scripts/init.sh "evil" "EVIL" "x" "x@y.z" "https://gitlab.example.com/foo/project-template.git" >/dev/null 2>&1
TPL_REJECT_RC=$?
set -e
assert "init rejects template URL (project-template.git)" "[ \"$TPL_REJECT_RC\" != '0' ]"

# Cleanup T7 dirs (TMP cleanup ловит EXIT trap, но TMP2/TMP3 — отдельные)
cd "$TMP"
rm -rf "$TMP2" "$TMP3"

# ===== Summary =====
```

- [ ] **Step 2: Прогнать test-template.sh, увидеть FAIL на T7**

Run:
```bash
bash scripts/test-template.sh
```

Expected: финальная строка содержит `failed`, и в выводе T7 есть провалы вида:
```
  ✗ exactly 1 commit after init
  ✗ commit message contains Template:
  ✗ no origin remote (no URL passed)
  ✗ init rejects template URL (project-template.git)
```

T1–T6 должны остаться зелёными. T7 фейлится — это ожидаемо: код в `init.sh` ещё не написан.

- [ ] **Step 3: Commit failing test**

```bash
git add scripts/test-template.sh
git commit -m "test(init): T7 — full init wipes .git, traces template, валидирует URL [RED]

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Реализовать wipe + initial commit + URL-валидацию в init.sh

Переходим в зелёную фазу TDD: реализуем минимально достаточный код, чтобы T7 прошёл.

**Files:**
- Modify: `scripts/init.sh`

- [ ] **Step 1: Прочитать текущий init.sh**

`Read` на `scripts/init.sh`. Запомни существующую структуру: sanity checks, сбор 4 параметров, `replace_in_file`, цикл по 4 плейсхолдерам, создание ветки `private`, копия `.env`. Wipe-блока нет.

- [ ] **Step 2: Добавить сбор GIT_REMOTE_URL после EDITOR_EMAIL**

`Edit` в `scripts/init.sh`:

old_string:
```
if [[ $# -ge 4 ]]; then
  EDITOR_EMAIL="$4"
else
  read -r -p "Email редактора Gramax (EDITOR_EMAIL): " EDITOR_EMAIL
fi
EDITOR_EMAIL="${EDITOR_EMAIL:-editor@example.com}"
```

new_string:
```
if [[ $# -ge 4 ]]; then
  EDITOR_EMAIL="$4"
else
  read -r -p "Email редактора Gramax (EDITOR_EMAIL): " EDITOR_EMAIL
fi
EDITOR_EMAIL="${EDITOR_EMAIL:-editor@example.com}"

# 3.2. URL нового origin (опционально)
if [[ $# -ge 5 ]]; then
  GIT_REMOTE_URL="$5"
else
  read -r -p "URL нового origin (Enter — пропустить, добавить позже): " GIT_REMOTE_URL
fi
GIT_REMOTE_URL="${GIT_REMOTE_URL:-}"

# 3.3. Защита от случайного push в репозиторий шаблона
if [[ -n "$GIT_REMOTE_URL" ]]; then
  if [[ "$GIT_REMOTE_URL" =~ (project[-_]template)(\.git)?/?$ ]]; then
    echo "ERROR: URL ведёт на репозиторий шаблона ('$GIT_REMOTE_URL')."
    echo "  Это запрещено защитой от случайного push."
    echo "  Создай отдельный репозиторий для своего проекта и повтори init."
    exit 1
  fi
fi
```

- [ ] **Step 3: Захватить traceability шаблона до wipe (вставить перед блоком замены плейсхолдеров)**

`Edit` в `scripts/init.sh`:

old_string:
```
# 4. Подстановка плейсхолдеров в CLAUDE.md, AGENTS.md, README.md, content/.doc-root.yaml
```

new_string:
```
# 3.4. Capture traceability шаблона до wipe
TEMPLATE_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
TEMPLATE_URL="$(git config --get remote.origin.url 2>/dev/null || echo unknown)"

# 4. Подстановка плейсхолдеров в CLAUDE.md, AGENTS.md, README.md, content/.doc-root.yaml
```

- [ ] **Step 4: Заменить блок «создать ветку private» на wipe + initial commit + private-ветка с поддержкой INIT_SKIP_GIT_RESET**

`Edit` в `scripts/init.sh`:

old_string:
```
# 5. Создать ветку private (если нет)
if ! git show-ref --verify --quiet refs/heads/private; then
  git branch private
  echo "✓ created branch 'private'"
fi
```

new_string:
```
# 5. Wipe .git и initial commit (или skip для тестов)
if [[ "${INIT_SKIP_GIT_RESET:-0}" == "1" ]]; then
  # Тестовый режим: не трогаем .git, только создаём ветку private (если нет)
  if ! git show-ref --verify --quiet refs/heads/private; then
    git branch private
    echo "✓ created branch 'private' (INIT_SKIP_GIT_RESET=1)"
  fi
else
  # Проверка: для git commit нужны user.email и user.name (любого scope)
  GIT_EMAIL="$(git config user.email 2>/dev/null || true)"
  GIT_NAME="$(git config user.name 2>/dev/null || true)"
  if [[ -z "$GIT_EMAIL" || -z "$GIT_NAME" ]]; then
    echo "ERROR: git config user.email и/или user.name не настроены."
    echo "  Выполни:"
    echo "    git config --global user.email 'you@example.com'"
    echo "    git config --global user.name  'Your Name'"
    echo "  и повтори init."
    exit 1
  fi

  rm -rf .git
  git init -b main -q
  git add -A
  git commit -q \
    -m "Initial commit from project_template" \
    -m "Template: ${TEMPLATE_URL}@${TEMPLATE_SHA}" \
    -m "Initialized as: ${NAME} (${CODE})"
  git branch private
  echo "✓ wiped .git, created initial commit (Template: ${TEMPLATE_URL}@${TEMPLATE_SHA})"
  echo "✓ created branches 'main' and 'private'"
fi

# 5.1. Установить origin (если URL передан)
if [[ -n "$GIT_REMOTE_URL" ]]; then
  if git remote | grep -q '^origin$'; then
    git remote set-url origin "$GIT_REMOTE_URL"
  else
    git remote add origin "$GIT_REMOTE_URL"
  fi
  echo "✓ origin set to $GIT_REMOTE_URL"
else
  echo "WARNING: origin не настроен. До 'git remote add origin <url>' любой push провалится — это by design."
fi
```

- [ ] **Step 5: Обновить финальную подсказку в init.sh**

`Edit` в `scripts/init.sh`:

old_string:
```
# 7. Подсказка
echo ""
echo "Готово. Следующие шаги:"
echo "  1. (Опционально для SMP-проекта) bash scripts/apply-overlay.sh naumen-smp"
echo "  2. Открой репо в Claude Code — плагины подцепятся через .claude/settings.json"
echo "  3. /pm decompose <твоя первая фича>"
```

new_string:
```
# 7. Подсказка
echo ""
echo "Готово (фаза 1). Следующие шаги:"
echo "  1. Открой репо в Claude Code и выполни /init — фаза 2 (интервью по стеку, red-lines)."
echo "  2. (Опционально для SMP-проекта) bash scripts/apply-overlay.sh naumen-smp"
echo "  3. /pm decompose <твоя первая фича>"
```

- [ ] **Step 6: Прогнать test-template.sh, увидеть GREEN**

Run:
```bash
bash scripts/test-template.sh
```

Expected: финальная строка `✓ Template smoke test PASSED`. T7 теперь зелёный, T1–T6 не сломаны.

Если T1–T6 фейлятся — скорее всего, T5 сломался из-за `INIT_SKIP_GIT_RESET`-логики. Проверь, что новый wipe-блок корректно пропускается при `INIT_SKIP_GIT_RESET=1`.

- [ ] **Step 7: Commit**

```bash
git add scripts/init.sh
git commit -m "feat(init): wipe .git + initial commit с трассировкой + URL-валидация [GREEN]

scripts/init.sh теперь:
- принимает 5-й параметр GIT_REMOTE_URL (опц., интерактивно по умолчанию)
- валидирует URL против паттерна (project[-_]template)(\\.git)?/?$
- захватывает TEMPLATE_SHA и TEMPLATE_URL до wipe
- делает rm -rf .git && git init -b main, initial commit с Template: <url>@<sha>
- создаёт ветку private
- опционально git remote add origin <url>; иначе печатает WARNING
- env-var INIT_SKIP_GIT_RESET=1 пропускает wipe-блок (для test-template.sh)

T7 в test-template.sh теперь зелёный.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Добавить скелетные секции с TODO-маркерами в CLAUDE.md (template)

Чтобы фаза 2 (`/init`) имела куда писать или ставить TODO, в шаблонный CLAUDE.md добавляем 4 новые секции и подраздел.

**Files:**
- Modify: `CLAUDE.md:5` (после раздела «## Карта команды»), `CLAUDE.md` (раздел «## Красные линии»), `CLAUDE.md` (раздел «## Справочные пути»)

- [ ] **Step 1: Прочитать CLAUDE.md**

`Read` на `CLAUDE.md`. Найди границы блоков «## Карта команды», «## Красные линии (универсальные)», «## Справочные пути».

- [ ] **Step 2: Добавить 4 скелетных секции после «## Карта команды»**

`Edit` в `CLAUDE.md`:

old_string:
```
Полная матрица ролей и контракт вызова субагентов — в **AGENTS.md**.

## Подключённые плагины
```

new_string:
```
Полная матрица ролей и контракт вызова субагентов — в **AGENTS.md**.

## Контекст проекта

<!-- TODO(/init): описать domain — что это за проект, кому помогает, какую проблему решает. Заменяется через `/init` фаза 2. -->

## Стек

<!-- TODO(/init): язык, фреймворки, ключевые зависимости. Для KB-only проекта: «только база знаний Gramax, кода нет». Заменяется через `/init` фаза 2. -->

## Команды сборки и проверки

<!-- TODO(/init): команды сборки/тестов/линтеров. Для KB-only — оставить пустым или удалить раздел. Заменяется через `/init` фаза 2. -->

## Архитектурные правила

<!-- TODO(/init): hexagonal/layered/иные правила или «не применимо для KB-only». Заменяется через `/init` фаза 2. -->

## Подключённые плагины
```

- [ ] **Step 3: Добавить подраздел «### Project-specific» в «## Красные линии»**

`Edit` в `CLAUDE.md`:

old_string:
```
- Tests/линтеры (если в проекте есть) — зелёные перед commit

## Справочные пути
```

new_string:
```
- Tests/линтеры (если в проекте есть) — зелёные перед commit

### Project-specific

<!-- TODO(/init): project-specific red-lines поверх универсальных. Заменяется через `/init` фаза 2. -->

## Справочные пути
```

- [ ] **Step 4: Заменить placeholder в «## Справочные пути»**

`Edit` в `CLAUDE.md`:

old_string:
```
- Документация платформы проекта: <заполнить под проект>
```

new_string:
```
- Документация платформы проекта: <!-- TODO(/init): platform docs URL -->
```

- [ ] **Step 5: Проверить, что test-template.sh всё ещё зелёный**

Run:
```bash
bash scripts/test-template.sh
```

Expected: `✓ Template smoke test PASSED`. Изменения в CLAUDE.md не должны ломать тесты (T2 проверяет только frontmatter агентов; T7 проверяет, что `{{PROJECT_NAME}}` отсутствует после init — TODO-маркеры это не плейсхолдеры).

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(template): добавить скелетные секции CLAUDE.md с TODO(/init)-маркерами

Контекст проекта / Стек / Команды сборки и проверки / Архитектурные правила
+ ### Project-specific под Красные линии + TODO в Справочных путях.

Phase 2 в /init заменит маркеры на содержательные блоки или оставит TODO
на пропусках.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Переписать раздел «Быстрый старт» в README.md (template)

Текущий «Быстрый старт» в README указывает запустить `bash scripts/init.sh`. Меняем на flow через `/init` slash-команду в Claude Code, упоминая wipe и backup.

**Files:**
- Modify: `README.md:5-11`

- [ ] **Step 1: Прочитать README.md**

`Read` на `README.md`. Запомни границы раздела «## Быстрый старт».

- [ ] **Step 2: Заменить раздел «## Быстрый старт»**

`Edit` в `README.md`:

old_string:
```
## Быстрый старт

1. `bash scripts/init.sh` — задаст имя проекта, создаст ветку `private`, скопирует `.env`.
2. (Опционально для SMP-проекта) `bash scripts/apply-overlay.sh naumen-smp`.
3. Открой репо в Claude Code — плагины подцепятся через `.claude/settings.json`.
4. `/pm decompose <твоя первая фича>` — поехали.
```

new_string:
```
## Быстрый старт

1. **Открой клон в Claude Code** и выполни `/init` — slash-команда проведёт двухфазную инициализацию:
   - заполнит плейсхолдеры (имя проекта, код каталога Gramax, описание, email редактора);
   - спросит URL нового origin и **отвяжет репо от шаблона** (`rm -rf .git && git init`);
   - проведёт интервью по теме проекта (стек, команды сборки, red-lines), оставит `<!-- TODO(/init): … -->` на пропусках.
2. (Опционально для SMP-проекта) `bash scripts/apply-overlay.sh naumen-smp`.
3. `/pm decompose <твоя первая фича>` — поехали.

> **Без Claude Code:** `bash scripts/init.sh "<имя>" "<код>" "<описание>" "<email>" "<git-url>"` даст фазу 1; фазу 2 (интервью) тогда придётся пройти руками.
> **Backup до init:** склонируй шаблон второй копией заранее, если хочется иметь возможность сравнить с оригиналом — wipe удаляет историю шаблона.
```

- [ ] **Step 3: Проверить, что test-template.sh всё ещё зелёный**

Run:
```bash
bash scripts/test-template.sh
```

Expected: `✓ Template smoke test PASSED`.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs(template): обновить README «Быстрый старт» под /init slash-команду

Указано: /init из Claude Code (а не bash напрямую), упоминание wipe .git
и рекомендация backup до init.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Переписать `/init` slash-команду под двухфазный алгоритм

Главный артефакт работы. Заменяем содержимое `init.md` под новый алгоритм: sanity, опциональная git-history-confirmation, фаза 1 (init.sh с 5 параметрами), фаза 2 (интервью по 6 темам с TODO-маркерами), финальный отчёт.

**Files:**
- Modify: `.claude/plugins/project/commands/init.md`

- [ ] **Step 1: Прочитать текущий init.md**

`Read` на `.claude/plugins/project/commands/init.md`. Это будет полная замена содержимого.

- [ ] **Step 2: Полностью переписать init.md**

Используй `Write` (полная замена файла):

```markdown
---
description: "Двухфазная инициализация проекта из шаблона. Фаза 1: bash-скрипт (плейсхолдеры, wipe .git, initial commit с трассировкой, опционально origin). Фаза 2: интервью по 6 темам с TODO-маркерами на пропусках. Пример: /init my-project"
allowed-tools: Read, Edit, Write, Bash(git:*), Bash(bash scripts/init.sh:*), Bash(ls:*), Bash(grep:*)
---

Ты выполняешь первичную инициализацию проекта, созданного из шаблона `project_template`. Работа делится на две фазы: bash-механика (`scripts/init.sh`) и интервью с правками content'а.

## Твоя задача

Пользователь передал: `$ARGUMENTS`

Цель — превратить «шаблон» в готовый рабочий проект:
1. Заполнить плейсхолдеры (`{{PROJECT_NAME}}`, `{{PROJECT_CODE}}`, `{{PROJECT_DESCRIPTION}}`, `{{EDITOR_EMAIL}}`).
2. Wipe `.git`, initial commit с трассировкой (`Template: <url>@<sha>`).
3. Опционально установить новый `origin` (URL ≠ репозиторий шаблона).
4. Заполнить или явно отметить TODO-маркерами project-specific секции в `CLAUDE.md`.

## Алгоритм

### Шаг 0. Идемпотентность

1. Прочитай `CLAUDE.md`. Если там нет ни `{{PROJECT_NAME}}`, ни `TODO(/init)` — проект уже полностью инициализирован. Сообщи и выйди.
2. Если есть `{{PROJECT_NAME}}` → переходи к **Фазе 1**.
3. Если плейсхолдеров уже нет, но есть `<!-- TODO(/init): ... -->` → пропусти Фазу 1, переходи сразу к **Фазе 2** (дозаполнение).

### Шаг 0.5. Подтверждение wipe (только если идём в Фазу 1)

Покажи пользователю текущую историю git:

```bash
git log --oneline -10
```

Затем явно спроси в чате (это сообщение, а не bash-prompt):

> «Это история шаблона. После init она будет удалена (wipe `.git` + initial commit с трассировкой). Продолжить? (yes/no)»

Жди подтверждения. На отрицательный ответ или невнятный — остановись и предложи сначала сделать `git clone` шаблона второй копией как backup.

### Фаза 1. Запуск механики

1. **Собери параметры** (если не переданы в `$ARGUMENTS`, спроси по очереди):
   - `PROJECT_NAME` — человекочитаемое имя проекта (например, `SD AI Assistant`)
   - `PROJECT_CODE` — код каталога Gramax, UPPERCASE, без пробелов (например, `SD-AI-ASSISTANT`)
   - `PROJECT_DESCRIPTION` — короткое описание для шапки Gramax-каталога
   - `EDITOR_EMAIL` — email редактора Gramax (минимум один; добавить остальных можно потом руками)
   - `GIT_REMOTE_URL` — URL нового origin. **Не должен** содержать `project-template` / `project_template`. Если у пользователя ещё нет URL — оставь пустым (init.sh пропустит origin и предупредит).

2. **Запусти `scripts/init.sh`:**
   ```bash
   bash scripts/init.sh "$PROJECT_NAME" "$PROJECT_CODE" "$PROJECT_DESCRIPTION" "$EDITOR_EMAIL" "$GIT_REMOTE_URL"
   ```
   Скрипт:
   - подставит плейсхолдеры в `CLAUDE.md`, `AGENTS.md`, `README.md`, `content/.doc-root.yaml`;
   - wipe `.git`, `git init -b main`, initial commit с `Template: <url>@<sha>`;
   - создаст ветку `private`;
   - опционально `git remote add origin <url>`;
   - скопирует `.env.example` → `.env`.

3. **Верифицируй:**
   - `grep -RE '{{(PROJECT_(NAME|CODE|DESCRIPTION)|EDITOR_EMAIL)}}' CLAUDE.md AGENTS.md README.md content/.doc-root.yaml` — пусто.
   - `git log --oneline -1` — один initial commit, в сообщении есть `Template: `.
   - `git remote -v` — либо origin задан, либо пусто.
   - `git branch -a` — есть `main` и `private`.

### Фаза 2. Интервью по 6 темам

Задавай вопросы **по одному**. Multiple-choice предпочтительнее. На каждый ответ — сразу `Edit` соответствующего блока в `CLAUDE.md`. На skip («не знаю / позже / пропустить») — оставь TODO-маркер как есть.

| # | Тема | Вопрос (пример) | Куда пишем |
|---|------|-----------------|------------|
| 1 | Стек и язык | «Стек: [a] Python [b] Groovy/Maven [c] TypeScript/Node [d] KB-only без кода [e] другое» | `## Стек` |
| 2 | Команды сборки и тестов | «Команды сборки/тестов? Например: `mvn test`, `pytest`, `npm test`. Если KB-only — `skip`.» | `## Команды сборки и проверки` |
| 3 | Архитектурные правила | «Архитектурный стиль: [a] hexagonal/ports-adapters [b] layered/N-tier [c] нет правил [d] KB-only» | `## Архитектурные правила` |
| 4 | Domain / тематика | «Опиши проект одним абзацем: что это, кому помогает, какую проблему решает.» | `## Контекст проекта` |
| 5 | Project-specific red-lines | «Какие правила безопасности/процесса критичны именно для этого проекта поверх универсальных?» | `### Project-specific` под `## Красные линии` |
| 6 | Ссылки | «URL платформенной документации, гайдов, API-доков (можно несколько; Enter — пропустить).» | `## Справочные пути` (заменить TODO-маркер) |

После каждого ответа:
- Содержательный ответ → `Edit`-tool заменяет конкретный `<!-- TODO(/init): ... -->` на блок (markdown с заголовком если нужно).
- Skip → ничего не меняешь, маркер остаётся для последующего grep.

### Шаг 6.5 (опц.): Адаптация properties в .doc-root.yaml

Спроси: «Хочешь адаптировать `properties` (Тип контента / Фаза / Статус) под специфику проекта (добавить «Сценарий», «Интеграция» и т.п.)?»

- «Нет» → оставь дефолт.
- «Да» → спроси, какие значения добавить/заменить, обнови соответствующие блоки и `filterProperties` синхронно.
- Skip → вставь `<!-- TODO(/init): адаптировать properties -->` в начало `content/.doc-root.yaml`.

Референс по адаптации: `/Users/mdemyanov/knowlage/sd-ai-assistant/content/.doc-root.yaml`.

### Шаг финал. Отчёт

1. **Что сделано:**
   - Какие файлы изменены (CLAUDE.md / .doc-root.yaml / ...).
   - Git-стейт: `git log --oneline -1`, `git branch -a`, `git remote -v`.
2. **Что осталось:** список TODO-маркеров через `grep -rn 'TODO(/init)' CLAUDE.md content/`. Если пусто — поздравь.
3. **Следующий шаг:** `/pm decompose <твоя первая фича>`.

## Anti-scope

- НЕ вызывай `/sa`, `/ba`, `/research` — на этапе init у проекта нет input-артефактов; их вызов нарушит контракт.
- НЕ делай commit правок Фазы 2 — пользователь решает сам (можно опционально предложить `commit-commands:commit` в конце как next step).
- НЕ создавай удалённый репозиторий — пользователь делает это сам и передаёт URL.

## Контракт `.doc-root.yaml` (для верификации)

Минимальный набор полей, которые обязаны быть заполнены **после** Фазы 1:

| Поле | Источник | Пример |
|------|----------|--------|
| `code` | `PROJECT_CODE` | `SD-AI-ASSISTANT` |
| `title` | `PROJECT_NAME` | `SD AI Assistant` |
| `description` | `PROJECT_DESCRIPTION` | `Knowledge base for AI Assistant for Service Desk` |
| `editors` | `EDITOR_EMAIL` (можно дополнить руками) | `qutask@gmail.com` |

Если `properties` адаптируются (Шаг 6.5) — обязательно обновить `filterProperties` синхронно, иначе фильтры в Gramax не появятся.
```

- [ ] **Step 3: Прогнать test-template.sh**

Run:
```bash
bash scripts/test-template.sh
```

Expected: `✓ Template smoke test PASSED`. T3 (`init.md exists` и `init.md has description`) теперь должны проходить, потому что описание в frontmatter присутствует.

Если T3 фейлится для `init.md` — проверь, что `description:` в первой строке YAML-frontmatter и нет лишних пробелов.

- [ ] **Step 4: Commit**

```bash
git add .claude/plugins/project/commands/init.md
git commit -m "feat(init-cmd): /init под двухфазный алгоритм + 6-темное интервью

- Шаг 0: идемпотентность (плейсхолдеры / TODO-маркеры).
- Шаг 0.5: показ git log + явное подтверждение wipe.
- Фаза 1: запуск init.sh с 5 параметрами.
- Фаза 2: интервью по 6 темам (стек, команды сборки, архитектура, domain, red-lines, ссылки) с TODO-маркерами на пропусках.
- Шаг 6.5 (опц.): адаптация properties в .doc-root.yaml.
- Anti-scope: не вызывает субагентов, не создаёт удалённый репо.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Финальный smoke-тест и проверка инвариантов

Прогнать всю цепочку, убедиться, что инварианты из спеки выполняются.

**Files:** (никаких правок)

- [ ] **Step 1: Прогнать test-template.sh**

Run:
```bash
bash scripts/test-template.sh
```

Expected:
- T1–T6 зелёные (как раньше);
- T7 зелёный (новый блок: 1 commit, Template: в сообщении, ветки main+private, нет origin без URL, отвергнутый template-URL);
- финальная строка `✓ Template smoke test PASSED`.

- [ ] **Step 2: Проверить инварианты руками на временной копии**

Run:
```bash
TMP="$(mktemp -d)" && rsync -a --exclude='.git' --exclude='.worktrees' /Users/mdemyanov/knowlage/project_template/ "$TMP/" && cd "$TMP" && git init -q -b main && git -c user.email=tpl@example.com -c user.name=tpl commit --allow-empty -q -m "tpl baseline"
bash scripts/init.sh "Smoke Project" "SMOKE-PROJ" "Smoke description" "smoke@example.com"
```

Expected output из `init.sh` содержит строки `✓ replaced ... in ...`, `✓ wiped .git, created initial commit (Template: ...)`, `✓ created branches 'main' and 'private'`, `WARNING: origin не настроен ...`, `Готово (фаза 1) ...`.

Run для проверки инвариантов:
```bash
echo "=== Инвариант 1: нет плейсхолдеров"
! grep -RE '\{\{(PROJECT_(NAME|CODE|DESCRIPTION)|EDITOR_EMAIL)\}\}' CLAUDE.md AGENTS.md README.md content/.doc-root.yaml && echo "  ✓ ok" || echo "  ✗ FAIL"

echo "=== Инвариант 2: ровно 1 commit"
COMMITS="$(git log --all --oneline | wc -l | tr -d ' ')"
[[ "$COMMITS" == "1" ]] && echo "  ✓ ok ($COMMITS)" || echo "  ✗ FAIL ($COMMITS)"

echo "=== Инвариант 2b: commit-message содержит Template:"
git log -1 --format=%B | grep -q '^Template: ' && echo "  ✓ ok" || echo "  ✗ FAIL"

echo "=== Инвариант 3: ветки main + private"
git show-ref --verify --quiet refs/heads/main && git show-ref --verify --quiet refs/heads/private && echo "  ✓ ok" || echo "  ✗ FAIL"

echo "=== Инвариант 4: нет origin (URL не передан)"
[[ -z "$(git remote)" ]] && echo "  ✓ ok" || echo "  ✗ FAIL"

echo "=== Инвариант 5: .env создан и не закоммичен"
[[ -f .env ]] && git check-ignore .env >/dev/null && echo "  ✓ ok" || echo "  ✗ FAIL"

echo "=== Инвариант 6: TODO-маркеры в CLAUDE.md есть"
grep -q 'TODO(/init)' CLAUDE.md && echo "  ✓ ok" || echo "  ✗ FAIL"
```

Expected: все 6 инвариантов помечены `✓ ok`.

После проверки:
```bash
cd /Users/mdemyanov/knowlage/project_template && rm -rf "$TMP"
```

- [ ] **Step 3: Проверить, что в основном репо работа закрыта**

Run:
```bash
git status --short
git log --oneline -10
```

Expected:
- `git status --short` пуст (всё закоммичено).
- `git log --oneline -10` показывает 6 новых коммитов поверх baseline (Task 0): test forward-compat, T7 RED, init.sh GREEN, CLAUDE.md TODO-секции, README быстрый старт, /init slash-команда rewrite. Плюс Task 0 baseline-commit.

- [ ] **Step 4: Финальный no-op commit с metainfo (опционально)**

Если хочется сделать визуальный «маркер закрытия фичи» — это допустимо. Иначе пропусти. Команда:

```bash
git commit --allow-empty -m "chore(init): двухфазный init flow закрыт

Spec: docs/superpowers/specs/2026-05-03-safe-init-flow-design.md
Plan: docs/superpowers/plans/2026-05-03-safe-init-flow.md

Что добавлено:
- init.sh: wipe .git + initial commit (Template: <url>@<sha>) + URL-валидация + опц. origin
- test-template.sh: T7 на полный init и URL-валидацию + INIT_SKIP_GIT_RESET в T5
- CLAUDE.md: 4 скелетные секции + Project-specific red-lines с TODO-маркерами
- README.md: новый Быстрый старт через /init
- /init slash-команда: двухфазный flow с интервью по 6 темам

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Notes для исполнителя

- **TDD-дисциплина:** Task 2 фейлит RED умышленно. Не «пропускай» этот шаг — он подтверждает, что новые ассерты в T7 действительно реагируют на отсутствие реализации, а не игнорируют её.
- **Idempotency:** `init.sh` не должен запускаться второй раз на инициализированном проекте — sanity check на `{{PROJECT_NAME}}` не пройдёт. Это by design.
- **Manual smoke `/init` slash-команды** не покрывается автотестами — после Task 6 рекомендуется отдельный manual-проход на свежем клоне в Claude Code, но это вне scope этого плана.
- **Ничего не push'ить:** после плана работа остаётся в локальной ветке `private`. Решение о push принимает пользователь отдельно.
