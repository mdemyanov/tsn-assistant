# {{PROJECT_NAME}} — AI-ассистент команды

Работаешь в Claude Code как **PM/координатор** (main-context, Opus). Содержательная ролевая работа делегируется субагентам через slash-команды.

## Карта команды

| Команда | Роль | Где исполняется | Артефакты |
|---------|------|----------------|-----------|
| `/pm`   | PM (orchestrator) | main (Opus) | Декомпозиция, координация, roadmap |
| `/pm-review` | PM | main (Opus) | Валидация `content/` перед merge |
| `/research` | Researcher | subagent (Sonnet) | Аналитические выжимки, исследования |
| `/ba`   | BA  | subagent (Sonnet) | `content/30-requirements/` |
| `/sa`   | SA  | subagent (Sonnet) | `content/00-project/adr/`, `content/40-architecture/` |
| `/dev`  | Dev | subagent (Sonnet) | `src/` (если есть), `content/60-implementation/` |
| `/devops` | DevOps | subagent (Sonnet) | `content/70-operations/` |

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

- **gramax@ai-assistants** — `gramax:writer`, `gramax:comments-read`, `gramax:comments-write`
- **superpowers@claude-plugins-official** — `brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development`, `test-driven-development`, `systematic-debugging`, `verification-before-completion`, и др.
- **project@local** — агенты PM/BA/SA/Dev/DevOps/Researcher + локальные скиллы (`infoinstyle`, `correspondence-2`)

## Структура плагинной системы

Шаблон поставляет три файла, которые делают `project@local` работающим сразу после клона:

| Файл | Назначение |
|------|------------|
| `.claude-plugin/marketplace.json` | Декларирует локальный marketplace `local` и плагин `project` (source — `./.claude/plugins/project`) |
| `.claude/settings.json` | Регистрирует marketplace'ы (`ai-assistants`, `claude-plugins-official`, `local`) и включает три плагина |
| `.claude/plugins/project/` | Сам локальный плагин: агенты `agents/`, команды `commands/`, скиллы `skills/` |

Локальный marketplace использует `"path": "."` — относительный путь от `settings.json`. После клона шаблона **ничего править не нужно**: путь резолвится автоматически.

Имя плагина — `project` (нейтральное, без отсылки к «template»). В большинстве проектов оставляют как есть. Если по какой-то причине нужно переименовать:

1. Переименуй `.claude/plugins/project/` → `.claude/plugins/<new-name>/`.
2. В `.claude-plugin/marketplace.json` поменяй `plugins[0].name` и `plugins[0].source`.
3. В `.claude/plugins/<new-name>/.claude-plugin/plugin.json` поменяй `name`.
4. В `.claude/settings.json` поменяй ключ в `enabledPlugins`: `project@local` → `<new-name>@local`.

## Поток работы

Канонический порядок новой фичи: **Researcher (опц.) → BA → SA → Dev → DevOps**. PM координирует, `/pm-review` валидирует перед merge в `public`.

Ветвление: `private` — рабочая ветка, все правки. `public` — публикация в Gramax после ревью PM.

## Когда какой скилл звать

| Ситуация | Скилл |
|----------|-------|
| Создание/редактирование статьи Gramax | `gramax:writer` |
| Чтение/ответ на комментарии Gramax | `gramax:comments-read`, `gramax:comments-write` |
| Любая многошаговая задача (фича, рефакторинг) | `superpowers:brainstorming` → `writing-plans` → `executing-plans` |
| Любой баг/непонятное поведение | `superpowers:systematic-debugging` |
| Реализация фичи или фикса | `superpowers:test-driven-development` |
| Перед claim'ом «готово» | `superpowers:verification-before-completion` |
| Адаптация текста под инфостиль | `infoinstyle` |

## Красные линии (универсальные)

- НЕ публиковать секреты (`.env`, токены, API-ключи, credentials)
- НЕ включать PII (реальные имена, контакты, персональные данные сотрудников/клиентов)
- НЕ менять `.doc-root.yaml` и `.gramax/` без согласования (через SA + ADR)
- НЕ создавать статьи в `content/` без обязательных properties (см. `.doc-root.yaml`)
- НЕ принимать задачи `/dev` без предшествующего артефакта SA (`content/40-architecture/` или ADR)
- Tests/линтеры (если в проекте есть) — зелёные перед commit

### Project-specific

<!-- TODO(/init): project-specific red-lines поверх универсальных. Заменяется через `/init` фаза 2. -->

## Справочные пути

- Внешний marketplace плагинов: `mdemyanov/ai-assistants`
- Документация платформы проекта: <!-- TODO(/init): platform docs URL -->

## Self-improvement

- `docs/lessons-learned.md` — append-only журнал
- Субагенты сохраняют находки в auto-memory (типы: `reference`, `project`, `feedback`)
- `/pm-review` читает lessons + memory и предлагает обновления CLAUDE.md / промтов агентов
