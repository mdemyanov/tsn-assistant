# Обновление существующего проекта из `project_template`

> **Эта инструкция написана для AI-ассистента (Claude Code).**
> Пользователь даёт ссылку на этот файл и говорит «обнови проект из шаблона». Ассистент: выполняй шаги строго по порядку, не пропускай pre-flight и verification gate. На каждом шаге, который меняет файлы, останавливайся и показывай diff пользователю до коммита, если ты не в auto-mode.

## Контекст

После `/init` проект отвязан от `project_template` (`rm -rf .git && git init`). Общей git-истории нет — обычный `git pull upstream` не сработает. Обновление = **выборочный sync** через дополнительный remote, с учётом того, что **структура старого проекта может сильно отличаться** от текущей версии шаблона (профили появились в W2, overlays — раньше, набор ролей менялся, плагин мог быть переименован).

Цель: затащить улучшения шаблона (`scripts/`, базовые agents, manifest'ы профилей, валидаторы), не сломав кастомизации проекта (`content/`, перенастроенный `CLAUDE.md`, локальные `agent-overrides/`, project-specific `.claude/settings.json`).

---

## Шаг 0. Pre-flight

Прежде чем что-то трогать, собери паспорт текущего состояния. Не пропускай — без этого ты не сможешь оценить divergence.

```bash
# 1. Где я, на какой ветке, что грязное
pwd
git status
git log --oneline -10

# 2. Есть ли уже remote шаблона / basis-marker
git remote -v
test -f .template-basis && cat .template-basis || echo "no basis marker"

# 3. Что из ключевых маркеров шаблона уже есть в проекте
ls -la scripts/ 2>/dev/null | head
ls -la docs/overlays/profiles/ 2>/dev/null
ls -la .claude/plugins/ 2>/dev/null
test -f AGENTS.md && head -5 AGENTS.md
test -f .doc-root.yaml && head -5 .doc-root.yaml
```

Зафиксируй у себя в ответе пользователю короткий summary (3–5 строк): ветка, есть ли uncommitted changes, наличие `.template-basis`, какие из маркеров найдены / отсутствуют. **Если есть незакоммиченные изменения — стоп, попроси пользователя их закоммитить или stash'нуть. Sync поверх dirty working tree запрещён.**

## Шаг 1. Подключи шаблон

Спроси у пользователя путь к локальному клону шаблона (или URL). Предпочтительно — соседняя папка.

```bash
# если нет соседнего клона — попроси пользователя сделать:
#   git clone <template-url> ../project_template
#   cd ../project_template && git checkout private && git pull

# в проекте
git remote add template ../project_template 2>/dev/null || git remote set-url template ../project_template
git fetch template
git log template/private --oneline -5
```

Запомни SHA `template/private` — он понадобится в шаге 6 для `.template-basis`.

## Шаг 2. Определи «версию» проекта

По наличию/отсутствию маркеров оцени, насколько проект отстал. Это определяет тактику.

| Маркер | Что значит, если отсутствует |
|---|---|
| `docs/overlays/profiles/` | Проект до Wave 2 — профильной системы нет |
| `docs/overlays/` | Совсем старый шаблон — overlays не были введены |
| `.claude/plugins/project/` | Плагинной структуры нет (или плагин переименован — проверь `.claude/settings.json` и `.claude-plugin/marketplace.json`) |
| `AGENTS.md` | Контракт ролей не зафиксирован — проект может использовать кастомные субагенты |
| `scripts/check.sh` | Pre-Wave-3 — нет gate-скрипта |
| `scripts/_apply_profile.py` | Pre-Wave-4a — overlay applier ещё bash-only |
| `scripts/_resolve_agents.py` | Pre-Wave-4a — нет per-profile agent overrides |

Дальше выбери тактику:

- **Small drift** (есть `docs/overlays/profiles/` + `_apply_profile.py`, проект максимум на 2–3 wave отстаёт) → шаги 3–6 как обычно.
- **Large drift** (нет профилей или нет плагинной папки) → переходи в шаг 7 «Большое расхождение».

Озвучь пользователю свою оценку в формате: «Похоже на состояние ~Wave X. Рекомендую тактику Y. Подтверди.» Ничего не делай до подтверждения.

## Шаг 3. Картируй области изменений

```bash
# что вообще менялось в шаблоне с момента basis (если есть .template-basis)
BASIS=$(cat .template-basis 2>/dev/null || echo "")
if [ -n "$BASIS" ]; then
  git -C ../project_template log --oneline "$BASIS"..private
  git -C ../project_template diff --stat "$BASIS"..private
fi

# что отличается прямо сейчас (всегда работает)
git diff template/private --stat -- scripts/ docs/overlays/ .claude/plugins/ AGENTS.md CLAUDE.md README.md docs/extending.md docs/troubleshooting.md docs/glossary.md docs/architecture-overview.md
```

Сгруппируй вывод на 4 корзины и покажи пользователю:

1. **Safe overwrite** (не правится в проектах): `scripts/*.sh`, `scripts/*.py`, `scripts/test-*.sh`, `docs/overlays/profiles/*/manifest.yaml`, `docs/overlays/profiles/*/content-scaffold/`, `docs/overlays/profiles/*/doc-root.yaml`, `.claude/plugins/project/agents/*-agent.md` (если в `agent-overrides/` для этой роли пусто), `.githooks/`.
2. **Manual 3-way merge** (вероятны кастомизации): `CLAUDE.md`, `AGENTS.md`, `README.md`, `.claude/settings.json`, `.doc-root.yaml`, `.claude-plugin/marketplace.json`, base agent files если есть локальные overrides, `docs/extending.md`, `docs/glossary.md`, `docs/architecture-overview.md`, `docs/troubleshooting.md`.
3. **Skip — это контент проекта**: `content/`, `docs/lessons-learned.md`, `docs/superpowers/specs/`, `docs/superpowers/plans/`, `docs/audit/`, `docs/research/`, `docs/requirements/` (требования проекта, не шаблона), `docs/architecture/spec-*.md` (specs проекта).
4. **Decide case-by-case**: `.claude/plugins/project/skills/`, `.claude/plugins/project/commands/`, agent-overrides, любые проектные хуки в `.claude/`. Покажи пользователю и спроси.

## Шаг 4. Применяй по корзинам

### 4a. Safe overwrite

```bash
# по одной корзине; не делай всё одной командой
git checkout template/private -- scripts/
git checkout template/private -- docs/overlays/profiles/<name>/manifest.yaml
git checkout template/private -- docs/overlays/profiles/<name>/content-scaffold/
git checkout template/private -- docs/overlays/profiles/<name>/doc-root.yaml
git checkout template/private -- .githooks/

# для base agent файла — только если локальный override отсутствует
ROLE=ba
test -f .claude/plugins/project/agent-overrides/${ROLE}.md \
  || git checkout template/private -- .claude/plugins/project/agents/${ROLE}-agent.md
```

После каждого `checkout` покажи `git status` и `git diff --cached` пользователю. Не коммить ещё.

### 4b. Manual 3-way merge

Для каждого файла из корзины 2:

```bash
# показать чужую версию vs текущую
git diff template/private -- CLAUDE.md
```

Прочитай оба файла (свой и template), сделай merge **руками через `Edit`**, не `git checkout`:
- сохрани все project-specific блоки (заполненные плейсхолдеры, секции «Project-specific», кастомные red lines, упоминания platform docs URL и т.п.);
- забери из шаблона: новые подразделы документации, обновлённые таблицы команд/профилей, обновлённые красные линии, новые упоминания файлов/скриптов.

Особо внимательно:
- **`CLAUDE.md`** — `{{PROJECT_NAME}}` уже заменён на реальное имя; не возвращай плейсхолдер. Project-specific section в конце — оставить как есть.
- **`AGENTS.md`** — если в проекте отключены/добавлены роли, шаблонная карта 10 ролей может не подходить дословно; merge by section.
- **`.claude/settings.json`** — JSON, не markdown; merge ключей (`enabledPlugins`, `permissions`, `hooks`) аккуратно. Если плагин был переименован (`project@local` → `<other>@local`), не возвращай старое имя.
- **`.doc-root.yaml`** — properties менялись между waves; забирай новые поля, но сохраняй project-specific values (имя каталога, editor email, custom enums).

### 4c. Decide case-by-case

Для каждого файла из корзины 4:
- Покажи diff пользователю.
- Спроси: «Забрать из шаблона / оставить как есть / сделать ручной merge?»
- Не действуй без явного ответа.

## Шаг 5. Verification gate

**Не коммить, пока всё не зелёное.**

```bash
# базовая проверка контента
python3 scripts/validate-content.py

# валидация manifest'ов профилей
python3 scripts/validate-profile.py

# полный gate (если check.sh подъехал в этом проекте)
bash scripts/check.sh --full 2>/dev/null || bash scripts/check.sh --fast 2>/dev/null || echo "check.sh missing — skipped"

# python-зависимости (могли подъехать новые validators, требующие pyyaml/etc)
python3 -c "import yaml" 2>&1 || echo "needs: pip install pyyaml"
```

Если что-то падает — stop, разбирайся (используй `superpowers:systematic-debugging`). Типичные грабли:
- `validate-content.py` ругается на старые статьи без object-нотации properties → fix руками или попроси пользователя.
- `validate-profile.py` падает на профиле, которого в проекте нет → проверь `.doc-root.yaml`, какой профиль активен.
- Тесты `test-template.sh` падают, потому что `init.sh` нельзя запускать в worktree (см. lessons-learned). На реальном проекте это норм, тесты в проекте обычно не нужны.

## Шаг 6. Commit + record basis

Только после зелёного gate:

```bash
# зафиксируй SHA шаблона, на котором мы синханулись
git -C ../project_template rev-parse private > .template-basis
echo ".template-basis at $(cat .template-basis)"

git add -A
git status   # последняя проверка перед коммитом

git commit -m "$(cat <<'EOF'
chore(template): sync with project_template @ <short-sha>

- scripts/: <что забрано>
- profiles/: <какие>
- agents/: <какие>
- root: <CLAUDE.md/AGENTS.md/README.md merged manually>

Verification: validate-content + validate-profile + check.sh OK.
EOF
)"
```

Подставь реальный short-sha (`git -C ../project_template rev-parse --short private`). Если делал merge большими порциями — разбей на несколько коммитов по корзинам.

---

## Шаг 7. Большое расхождение (large drift)

Если на шаге 2 ты понял, что в проекте нет ключевых вех (профилей или плагинной папки), массовый `git checkout` — плохая идея: ты затащишь файлы, у которых нет инфраструктуры (manifest без validator, agent без `.claude/plugins/project/`).

Тактика:

1. **Не пытайся перепрыгнуть несколько wave'ов одной операцией.** Идём по wave'ам:
   - Wave 1 → введение `.claude/plugins/project/`, agents, базовый `AGENTS.md`. Если их нет — собирай вручную, копируя из template целиком + merge `.claude/settings.json`.
   - Wave 2 → `docs/overlays/profiles/`, `scripts/apply-overlay.sh`, `scripts/init.sh`. Подключаем профильную систему: копируем целиком, выбираем профиль, который соответствует существующему `content/`.
   - Wave 3 → `scripts/check.sh`, `.githooks/`, обновления docs.
   - Wave 4 → `_apply_profile.py`, `_resolve_agents.py`, override mechanic, init UX.
2. **На каждом wave — отдельный коммит**, отдельный verification gate.
3. **Если profile-привязки нет совсем**, спроси у пользователя, какой профиль ставим (`project` / `kb-team` / `kb-product` / `product` / `methodology` / `course` / `custom`). Затем:
   - копируешь `docs/overlays/profiles/<name>/` из шаблона целиком;
   - **аккуратно** мержишь существующий `content/` со scaffold'ом профиля — старые статьи пользователя не трогаем, добавляем только отсутствующие папки и `_index.md`.
4. **`content/` всегда трогаем последним** и только в части structural fixes (object-нотация properties, недостающие `_index.md`). Сами статьи — никогда без явного запроса.
5. После каждого wave'а — verification gate (шаг 5). Не переходи к следующему wave, пока текущий не зелёный.

## Антипаттерны (никогда)

- ❌ `git checkout template/private -- .` — затрёт `content/` и кастомизации root-файлов.
- ❌ `rsync -av --delete ../project_template/ ./` — то же самое, ещё и быстрее.
- ❌ Перезапуск `bash scripts/init.sh` для «обновления» — он wipe'нет `.git` и снесёт историю проекта.
- ❌ `git merge template/private` — нет общего предка, либо конфликт во всех файлах, либо «Refusing to merge unrelated histories».
- ❌ Применить всё одним коммитом без gate — если что-то сломается, bisect станет адом.
- ❌ Коммитить `.template-basis` ДО зелёного gate — basis должен означать «работающее состояние».

## Что обновлять не нужно

- `content/` — это контент проекта, шаблон его не диктует.
- `docs/lessons-learned.md` — журнал проекта.
- `docs/superpowers/{specs,plans}/` — артефакты brainstorming/writing-plans проекта.
- `docs/audit/`, `docs/research/`, `docs/requirements/`, `docs/architecture/` — рабочие артефакты ролей BA/SA/Researcher.
- `.git/`, `.worktrees/`, любые локальные не-tracked файлы.

---

## Краткий чек-лист (для быстрой ориентации)

- [ ] Шаг 0: pre-flight, working tree чистый
- [ ] Шаг 1: `template` remote подключён, `git fetch template` сделан
- [ ] Шаг 2: оценил версию проекта, согласовал тактику с пользователем
- [ ] Шаг 3: показал пользователю 4 корзины
- [ ] Шаг 4a: safe overwrite по одной корзине, diff пользователю
- [ ] Шаг 4b: ручной merge root-файлов через `Edit`
- [ ] Шаг 4c: edge cases — спросил, не угадывал
- [ ] Шаг 5: validate-content + validate-profile + check.sh зелёные
- [ ] Шаг 6: коммит + `.template-basis` обновлён

Если завис на любом шаге — `superpowers:systematic-debugging`. Никогда не «силовое решение» (force checkout, rm, --no-verify).
