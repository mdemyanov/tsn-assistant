# Example Team KB — AI-ассистент команды

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

## Профильная система (Wave 2)

Шаблон поддерживает 7 **профилей** (тип проекта). Профиль выбирается на `/init` и определяет:

- структуру `content/` (scaffold)
- набор properties в `.doc-root.yaml`
- активные subagents (core / optional / disabled)
- активные pipelines

| Профиль | Назначение | Статус |
|---------|------------|--------|
| `project` | Delivery-проект (default) | stable |
| `kb-team` | Internal team KB (onboarding/runbook/role/incident) | stable |
| `product` | Разработка продукта | stub (Wave 3+) |
| `kb-product` | Документация продукта для клиентов | stub |
| `methodology` | Methodology / playbook | stub |
| `course` | Обучающий курс | stub |
| `custom` | Open-ended | stub |

### Команды

- `bash scripts/init.sh --profile <name> ...` — выбрать профиль на init (по умолчанию интерактивный fallback)
- `bash scripts/apply-overlay.sh --profile --dry-run <name>` — preview операций
- `python3 scripts/validate-profile.py` — валидация manifest'ов

### Файлы

- `docs/overlays/profiles/<name>/manifest.yaml` — декларация профиля
- `docs/overlays/profiles/<name>/content-scaffold/` — content scaffold
- `docs/overlays/profiles/<name>/doc-root.yaml` — шаблон `.doc-root.yaml`
- `.claude/plugins/project/agents/<role>-agent.md` — base prompts; per-profile overrides в `profiles/<name>/agent-overrides/<role>.md` (Wave 3)

### Каталог 10 ролей

PM (main, Opus) + 9 subagent'ов (Sonnet): researcher, ba, sa, dev, devops, qa (author/runner), tech-writer, devsecops, compliance.

### 3 pipeline'а

- `/pipelines/project-planning <epic>` — декомпозиция эпика
- `/pipelines/ba-acceptance <req>` — gate AC ↔ реализация
- `/pipelines/critical-path <epic>` — DAG + mermaid Gantt

См. `AGENTS.md` (полный реестр 10 ролей) и `docs/extending.md` (как добавить роль/pipeline/профиль).

## Правила Gramax-каталога (`content/`)

- **`_index.md` в каждой подпапке** (где есть `.md` файлы или вложенные подкаталоги). Без него Gramax не показывает раздел в навигации.
- **`_index.md` НЕ содержит блок `properties:`** — раздел не имеет своего типа/статуса; properties живут на статьях.
- **Корневой `content/_index.md`** разрешён и используется как главная страница каталога (навигация + дашборд `<view>`).
- **Frontmatter статьи — object-нотация:**
  ```yaml
  properties:
    - name: Тип контента
      value: [ADR]
  ```
  Плоская нотация (`- Тип контента: ADR`) — устарела, рендерится непредсказуемо.
- **Cross-каталожные ссылки** (между разными `.doc-root.yaml`) — только inline code (`` `other-catalog/path.md` ``), не markdown link.
- **Эталон production-каталога:** `/Users/mdemyanov/Devel/naumen-ecosystem/business-requirements/`.
- **Валидация:** `python3 scripts/validate-content.py` — обязательно зелёный перед merge `private→public`.

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
