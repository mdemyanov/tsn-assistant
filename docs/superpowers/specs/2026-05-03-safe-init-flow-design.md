---
title: Safe init flow для project_template
date: 2026-05-03
status: Draft
authors: PM (main, Opus)
related:
  - docs/superpowers/specs/2026-04-27-project-template-design.md
  - .claude/plugins/project/commands/init.md
  - scripts/init.sh
---

# Safe init flow

## Контекст

Шаблон `project_template` клонируется командой как стартовый каталог нового внутреннего проекта. После клона пользователю нужно превратить шаблон в свой репозиторий — заполнить плейсхолдеры (`{{PROJECT_NAME}}` и др.), описать тематику/стек/red-lines, отвязать репозиторий от удалённого `origin` шаблона, чтобы случайный `git push` не уехал в `office-ai/project-template.git`.

Текущая инициализация (`scripts/init.sh` + slash-команда `/init`) делает первую часть (плейсхолдеры, ветка `private`, `.env`), но **не трогает git-remote** и не помогает пользователю обогатить CLAUDE.md проектной спецификой. Эталонный CLAUDE.md (например, `naumen-smp-mcp/CLAUDE.md`) содержит описание стека, команды сборки, архитектурные правила и project-specific красные линии — этих секций в обобщённом шаблонном CLAUDE.md нет.

## Цели

- **Безопасность git:** исключить кейс случайного push в репозиторий шаблона. Базовая мера — wipe `.git` и initial commit с трассировкой; защитная — валидация введённого URL против паттерна шаблона.
- **Структурное обогащение контента:** после `/init` `CLAUDE.md` имеет либо заполненные секции «Контекст проекта / Стек / Команды сборки / Архитектурные правила / Red-lines / Справочные пути», либо явные `<!-- TODO(/init): … -->` маркеры на пропусках.
- **Сохранение существующих контрактов:** `test-template.sh` продолжает работать; идемпотентность init остаётся (повторный запуск распознаётся и завершается без вреда).
- **CI-friendly:** механика остаётся в bash-скрипте, чтобы её можно было тестировать без Claude Code; интерактивные вопросы — поверх (slash-команда).

## Не-цели

- Создание удалённого репозитория (GitLab/GitHub) — пользователь делает это сам.
- Настройка CI/CD, secrets, dependency management — это задачи `/devops` после первой фичи.
- Применение overlays (`apply-overlay.sh naumen-smp` и т.п.) — остаётся отдельной осознанной командой.
- Делегирование интервью субагентам (`/sa`, `/ba`) — нарушает их контракт; на этапе init у проекта ещё нет input-артефактов.
- Восстановление истории шаблона после init — by design не предусматривается.

## Архитектура: двухфазный init

```
┌─────────────────────────────┐      ┌─────────────────────────────┐
│  Phase 1: scripts/init.sh   │      │  Phase 2: /init slash cmd   │
│  (bash)                     │      │  (Claude Code, main, Opus)  │
├─────────────────────────────┤      ├─────────────────────────────┤
│ • Sanity checks             │      │ • Запускает scripts/init.sh │
│ • Detect template state     │      │   с собранными аргументами  │
│ • Replace placeholders      │  →   │ • Интервью по 6 темам        │
│ • Wipe .git + git init      │      │ • Правка CLAUDE.md/AGENTS.md │
│ • Initial commit с traceback│      │   /.doc-root.yaml: блоки или │
│ • git remote add origin     │      │   <!-- TODO(/init): ... -->  │
│ • Скопировать .env.example  │      │ • Финальный отчёт + next-step│
└─────────────────────────────┘      └─────────────────────────────┘
        ↑                                        ↑
   запускается также из                  основной user-facing entrypoint
   test-template.sh (с                   ("открой Claude Code, /init …")
   INIT_SKIP_GIT_RESET=1)
```

**Граница ответственности:**
- `init.sh` — единственное место, где происходит работа с git и подстановка плейсхолдеров. Никаких смысловых правок content'а.
- `/init` — единственное место, где идёт интервью и правится content. Не дублирует mechanical-работу, а вызывает `init.sh`.

## Phase 1: `scripts/init.sh`

### Сигнатура

```bash
bash scripts/init.sh <PROJECT_NAME> [PROJECT_CODE] [PROJECT_DESCRIPTION] [EDITOR_EMAIL] [GIT_REMOTE_URL]
```

Все параметры кроме первого — опциональные. Если не переданы — скрипт спрашивает интерактивно. Один новый параметр относительно текущей версии: `GIT_REMOTE_URL` (5-й позиционный).

### Env-vars

- `INIT_SKIP_GIT_RESET=1` — пропускает блок wipe + git init + initial commit. Используется `test-template.sh`, чтобы тест не терял свой baseline. По умолчанию — не задан.

### Алгоритм

1. **Sanity checks:**
   - выполняется из корня проекта (есть `CLAUDE.md`);
   - если `CLAUDE.md` не содержит `{{PROJECT_NAME}}` → проект уже инициализирован, exit 0 с сообщением.

2. **Сбор параметров:** существующая логика `read -r -p` для всех 5 параметров. Default'ы:
   - `PROJECT_CODE` → `${NAME^^}`;
   - `PROJECT_DESCRIPTION` → `Knowledge base for $NAME`;
   - `EDITOR_EMAIL` → `editor@example.com`;
   - `GIT_REMOTE_URL` → пусто (промпт текстом: `URL нового origin (Enter — пропустить, добавить позже): `).

3. **Валидация GIT_REMOTE_URL** (только если непустое):
   - regex запрета: `(project[-_]template)(\.git)?/?$` — матчит и `…/project-template`, и `…/project-template.git`, и `…/project_template/`;
   - на матч → exit 1 с пояснением: «URL ведёт на репозиторий шаблона. Это запрещено защитой от случайного push. Создай новый репо и повтори init».
   - формат URL (https/ssh/иное) не валидируем — это сделает `git remote add` при попытке использовать.

4. **Capture template traceability** (до wipe):
   - `TEMPLATE_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)`;
   - `TEMPLATE_URL=$(git config --get remote.origin.url 2>/dev/null || echo unknown)`.

5. **Подстановка плейсхолдеров** в `CLAUDE.md`, `AGENTS.md`, `README.md`, `content/.doc-root.yaml` — без изменений (используется существующий `replace_in_file`).

6. **Wipe & re-init** (если `INIT_SKIP_GIT_RESET` не задан):
   - проверить `git config user.email` и `git config user.name` (любого scope) — если **хотя бы одно** пусто, fail с инструкцией `git config --global user.email …` / `…user.name …` (`git commit` без обоих не сработает);
   - `rm -rf .git`;
   - `git init -b main -q`;
   - `git add -A`;
   - `git commit -q -m "Initial commit from project_template" -m "Template: <TEMPLATE_URL>@<TEMPLATE_SHA>" -m "Initialized as: <PROJECT_NAME> (<PROJECT_CODE>)"`;
   - `git branch private`.

7. **Если `INIT_SKIP_GIT_RESET=1`** — пропустить wipe-блок, но создать ветку `private`, если её нет (как в текущей версии).

8. **Remote:**
   - если `GIT_REMOTE_URL` пустой → текстовый warning (без ANSI-цветов, чтобы не ломать CI-вывод): `WARNING: origin не настроен. До 'git remote add origin <url>' любой push провалится — это by design.`
   - если задан → `git remote add origin "$GIT_REMOTE_URL"` + сообщение `✓ origin set to <url>`.

9. **`.env`:** скопировать `.env.example` → `.env`, если `.env` отсутствует.

10. **Финальная подсказка:**
    ```
    Готово (фаза 1). Следующие шаги:
      1. Открой репо в Claude Code и выполни /init — фаза 2 (интервью по стеку, red-lines, …).
      2. (Опционально для SMP-проекта) bash scripts/apply-overlay.sh naumen-smp.
      3. /pm decompose <твоя первая фича>.
    ```

### Что НЕ меняется

- Сигнатура существующих 4 параметров.
- Логика `replace_in_file` (sed -i.bak с разделителем `|`).
- Контракт «выполняется идемпотентно» при повторном запуске.

## Phase 2: `/init` slash-команда

### Контракт

- **Тип:** main-context, Opus.
- **Триггер:** `/init [PROJECT_NAME]`.
- **Allowed-tools:** `Read, Edit, Write, Bash(git:*), Bash(bash scripts/init.sh:*), Bash(grep:*), Bash(ls:*)`.

### Алгоритм

#### Шаг 0. Идемпотентность

- `grep -q '{{PROJECT_NAME}}' CLAUDE.md`.
- Если плейсхолдеров нет и `grep -q 'TODO(/init)' CLAUDE.md` тоже false → проект уже полностью инициализирован, сообщить и выйти.
- Если плейсхолдеры есть → продолжить с фазы 1.
- Если плейсхолдеров нет, но есть `<!-- TODO(/init): … -->` → перейти сразу в фазу 2 (дозаполнение).

Перед запуском `init.sh` PM-агент в чате выводит результат `git log --oneline -10` и явно спрашивает: «Это история шаблона. После init она будет удалена. Продолжить?» — ждёт от пользователя «да/yes/y» или иное подтверждение в чате (не bash-prompt; промпт идёт через сообщение Claude Code).

#### Фаза 1: запуск механики

1. Собрать у пользователя 5 параметров. Если что-то передано через `$ARGUMENTS` — не переспрашивать.
2. Запустить `bash scripts/init.sh "$PROJECT_NAME" "$PROJECT_CODE" "$PROJECT_DESCRIPTION" "$EDITOR_EMAIL" "$GIT_REMOTE_URL"`.
3. Верифицировать: `grep -RE '{{(PROJECT_(NAME|CODE|DESCRIPTION)|EDITOR_EMAIL)}}' CLAUDE.md AGENTS.md README.md content/.doc-root.yaml` → пусто. Иначе fail.
4. Подтвердить git-состояние: `git log -1 --oneline` (ровно один commit с `Template: …@…`), `git remote -v` (либо origin задан, либо отсутствует), `git branch -a` (есть `main` и `private`).

#### Фаза 2: интервью с TODO-пропусками

Шесть тем, по одной за раз. Multiple-choice предпочтительнее open-ended. Skip → TODO-маркер.

| # | Тема | Куда писать | Маркер при пропуске |
|---|------|-------------|---------------------|
| 1 | Стек и язык | блок «## Стек» в CLAUDE.md | `<!-- TODO(/init): описать стек -->` |
| 2 | Команды сборки и тестов | блок «## Команды сборки и проверки» в CLAUDE.md | `<!-- TODO(/init): команды сборки/тестов -->` |
| 3 | Архитектурные правила | блок «## Архитектурные правила» в CLAUDE.md | `<!-- TODO(/init): архитектурные правила -->` |
| 4 | Domain / тематика | блок «## Контекст проекта» в CLAUDE.md | `<!-- TODO(/init): описать domain -->` |
| 5 | Project-specific red-lines | подраздел «### Project-specific» в блоке «## Красные линии» | `<!-- TODO(/init): project-specific red-lines -->` |
| 6 | Ссылки (документация платформы и др.) | секция «## Справочные пути» | `<!-- TODO(/init): platform docs URL -->` |

После каждого ответа PM-агент **сразу** редактирует соответствующий файл через `Edit`-tool: на содержательный ответ — заменяет соответствующий `<!-- TODO(/init): … -->` маркер на содержательный блок (с заголовком если нужно); на skip — оставляет маркер как есть.

Опциональный 7-й вопрос — адаптация `properties` в `.doc-root.yaml`. Если «нет» — оставить дефолт. Если «да» — спросить, какие значения добавить/заменить, обновить `filterProperties` синхронно. На skip — `<!-- TODO(/init): адаптировать properties -->` в начало файла.

#### Шаг финал: отчёт

- Что сделано: список файлов, новый git-стейт.
- Сводка TODO-маркеров: `grep -rn 'TODO(/init)' .` — список файлов и строк.
- Команда для следующего шага: `/pm decompose <твоя первая фича>`.

#### Anti-scope команды

- Не вызывает `/sa`, `/ba`, `/research` — нет input-артефактов.
- Не делает commit — после фазы 1 `init.sh` уже создал initial commit. Правки фазы 2 пользователь коммитит сам (или PM-агент предлагает `commit-commands:commit` в конце как опциональный шаг).

## Изменения в template-файлах

### `CLAUDE.md`

После «## Карта команды» вставить:

```markdown
## Контекст проекта

<!-- TODO(/init): описать domain — что это за проект, кому помогает, какую проблему решает -->

## Стек

<!-- TODO(/init): язык, фреймворки, ключевые зависимости. Для KB-only: "только база знаний Gramax, кода нет". -->

## Команды сборки и проверки

<!-- TODO(/init): команды сборки/тестов/линтеров. Для KB-only: оставить пустым или удалить раздел. -->

## Архитектурные правила

<!-- TODO(/init): hexagonal/layered/иные правила или "не применимо для KB-only". -->
```

В существующий «## Красные линии (универсальные)» в конце добавить:

```markdown

### Project-specific

<!-- TODO(/init): project-specific red-lines поверх универсальных -->
```

В «## Справочные пути» заменить `<заполнить под проект>` на `<!-- TODO(/init): platform docs URL -->`.

### `AGENTS.md`

Без изменений.

### `README.md`

Раздел «## Быстрый старт» переписывается:

```markdown
## Быстрый старт

1. **Открой клон в Claude Code** и выполни `/init` — slash-команда проведёт двухфазную инициализацию:
   - заполнит плейсхолдеры (имя проекта, код каталога Gramax, описание, email редактора);
   - спросит URL нового origin и **отвяжет репо от шаблона** (`rm -rf .git && git init`);
   - проведёт интервью по теме проекта (стек, команды сборки, red-lines), оставит `<!-- TODO(/init): … -->` на пропусках.
2. (Опционально для SMP-проекта) `bash scripts/apply-overlay.sh naumen-smp`.
3. `/pm decompose <твоя первая фича>` — поехали.

> **Без Claude Code:** `bash scripts/init.sh "<имя>" "<код>" "<описание>" "<email>" "<git-url>"` даст фазу 1; фазу 2 (интервью) тогда придётся пройти руками.
> **Backup до init:** `git clone` шаблона второй копией заранее, если хочется иметь возможность сравнить с оригиналом — wipe удаляет историю шаблона.
```

### `content/.doc-root.yaml`

Без структурных изменений.

### `.claude/plugins/project/commands/init.md`

Полностью переписывается под новый алгоритм (фаза 1 + фаза 2 + TODO-интервью + git-валидации).

### `scripts/init.sh`

Расширяется по разделу [Phase 1 / Алгоритм](#алгоритм).

### `scripts/test-template.sh`

Адаптируется:
- T5: `INIT_SKIP_GIT_RESET=1 bash scripts/init.sh "test-project"` (чтобы не терялся git-baseline теста).
- T6 (overlay): остаётся как есть, но запускается после T5 c `INIT_SKIP_GIT_RESET=1`.
- **Новый T7** (после T6) — полный init:
  1. Свежая копия в новом `mktemp -d`, `git init`, baseline commit;
  2. `bash scripts/init.sh "smoke" "SMOKE" "Smoke test" "test@example.com"` (без env-var, без `GIT_REMOTE_URL`);
  3. assert: `git log` содержит ровно 1 commit;
  4. assert: commit-message содержит `Template: `;
  5. assert: `git remote -v` пусто;
  6. assert: ветки `main` + `private` есть;
  7. отдельный sub-test: `bash scripts/init.sh "evil" "EVIL" "x" "x@y.z" "https://example.com/foo/project-template.git"` → exit code != 0.

## Инварианты после успешного `/init`

1. В `CLAUDE.md`, `AGENTS.md`, `README.md`, `content/.doc-root.yaml` нет ни одного `{{…}}`-плейсхолдера.
2. `git log --all --oneline | wc -l` = 1: ровно один initial commit с строкой `Template: <url>@<sha>`.
3. `git branch -a`: есть `main` и `private`, нет других веток шаблона.
4. `git remote -v`: либо пусто, либо origin указывает на не-template URL.
5. `.env` существует и не закоммичен (защищён `.gitignore`).
6. Если в файлах остались `<!-- TODO(/init): … -->` — `/init` показал их пользователю как явный список.

## Риски и митигации

| Риск | Вероятность | Митигация |
|------|-------------|-----------|
| Пользователь скопирует URL шаблона в промпт `GIT_REMOTE_URL` | средняя | Regex-валидация в `init.sh` → fail с пояснением |
| `rm -rf .git` сломает работу пользователя, который уже сделал свои коммиты | низкая | Шаг 0 `/init` проверяет наличие `{{PROJECT_NAME}}`; если нет → exit. `init.sh` дублирует ту же проверку |
| TODO-маркеры останутся незамеченными | средняя | `/pm-review` дополняется проверкой `grep -rn 'TODO(/init)'` |
| `test-template.sh` сломается из-за wipe | высокая | Env-var `INIT_SKIP_GIT_RESET=1` + новый блок T7 |
| Пользователь запустит `init.sh` напрямую и пропустит фазу 2 | средняя | Финальный echo в `init.sh` явно зовёт `/init` для фазы 2; `/init` идемпотентен и дозаполнит TODO позже |
| Wipe удалит коммит, который пользователь хотел сохранить (например, добавил LICENSE до init) | низкая | `/init` показывает `git log --oneline -10` и просит подтверждение перед `rm -rf .git` |
| `git config user.email/name` не настроены глобально → `git commit` упадёт | низкая | Проверка в `init.sh` перед commit; на отсутствие — fail с инструкцией |

## План реализации (high-level)

1. **`scripts/init.sh`** — расширение по Phase 1.
2. **`scripts/test-template.sh`** — env-var в T5/T6 + новый блок T7.
3. **Template-файлы** (`CLAUDE.md`, `README.md`) — добавление скелетных секций и TODO-маркеров.
4. **`.claude/plugins/project/commands/init.md`** — переписывание под новый алгоритм.
5. **Smoke-test** — `bash scripts/test-template.sh` должен пройти; manual smoke `/init` на свежем клоне.

Детальный пошаговый план — в `docs/superpowers/plans/2026-05-03-safe-init-flow.md` (создаётся следующим шагом через `superpowers:writing-plans`).

## Открытые вопросы

Нет (все развилки закрыты на этапе брейнсторминга: git-стратегия = wipe + ask remote, обогащение = двухфазное, валидация URL = regex в init.sh, исполнитель фазы 2 = `/init` без субагентов, обработка пропусков = TODO-маркеры).
