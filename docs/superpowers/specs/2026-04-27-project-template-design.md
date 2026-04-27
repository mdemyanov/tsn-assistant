# Project Template — Design Spec

**Дата:** 2026-04-27
**Автор:** mdemyanov + Claude (brainstorming)
**Статус:** Draft → User review

## Назначение

Репозиторий-шаблон в `/Users/mdemyanov/knowlage/project_template`. Используется как `git clone` (или GitHub template) для быстрого старта внутреннего проекта Naumen — нового модуля SMP, аналитического исследования, документной инициативы и т.п.

Целевые аудитории:
- **Аналитики** — пишут требования (BA), исследуют (Researcher), редактируют тексты (infoinstyle/correspondence-2).
- **Руководители** — оркестрируют через PM, ревьюят через `/pm-review`.
- **Разработчики** — проектируют (SA), реализуют (Dev), документируют деплой (DevOps).

Стартовый сценарий пользователя:
1. `git clone <template>` → переименование repo.
2. `bash scripts/init.sh` — задаёт имя проекта, создаёт ветку `private`, копирует `.env`.
3. (Опционально для SMP-проекта) `bash scripts/apply-overlay.sh naumen-smp`.
4. Открыть в Claude Code → плагины подцепляются через `.claude/settings.json`.
5. `/pm decompose <фича>` — поехали.

## Решения brainstorming

| # | Вопрос | Выбор |
|---|--------|-------|
| 1 | Фокус шаблона | **C** — Гибрид: универсальное ядро + SMP-overlay |
| 2 | Упаковка плагинов и скиллов | **C** — Гибрид: что есть в marketplace — оттуда; чего нет — локально. Обязательны `gramax@ai-assistants` и `superpowers@claude-plugins-official` |
| 3 | Состав субагентов | **C** — Полный-5 + Researcher (PM, BA, SA, Dev, DevOps, Researcher) |
| 4 | Структура контента и Gramax | **A** — Полный каркас + Naumen-properties + private/public ветвление |
| 5 | Состав SMP-overlay | **B** — Готовые patches: фрагменты CLAUDE.md, дополнения к промтам агентов, доменный glossary-скелет, apply-скрипт |

## Архитектура (карта каталогов)

```
project_template/
├── CLAUDE.md                          # Универсальное ядро (PM-координация, красные линии, ссылки)
├── AGENTS.md                          # Матрица ролей + контракт вызова субагентов
├── README.md                          # Как пользоваться шаблоном
├── .gitignore
├── .env.example
│
├── .claude/
│   ├── settings.json                  # Marketplaces + enabledPlugins
│   └── plugins/
│       └── project-template/
│           ├── .claude-plugin/plugin.json
│           ├── agents/                # 6 субагентов
│           │   ├── pm-agent.md
│           │   ├── ba-agent.md
│           │   ├── sa-agent.md
│           │   ├── dev-agent.md
│           │   ├── devops-agent.md
│           │   └── researcher-agent.md
│           ├── commands/              # 7 slash-команд
│           │   ├── pm.md
│           │   ├── pm-review.md
│           │   ├── ba.md
│           │   ├── sa.md
│           │   ├── dev.md
│           │   ├── devops.md
│           │   └── research.md
│           └── skills/                # Локальные снапшоты CTO-скиллов
│               ├── infoinstyle/SKILL.md (+ refs)
│               └── correspondence-2/SKILL.md (+ refs)
│
├── content/                           # Полный Gramax-каркас
│   ├── .doc-root.yaml                 # Properties: Тип контента, Фаза, Статус
│   ├── 00-project/
│   │   ├── adr/.gitkeep
│   │   └── README.md
│   ├── 10-domain/
│   │   └── glossary.md (skeleton)
│   ├── 30-requirements/
│   │   ├── functional/.gitkeep
│   │   ├── non-functional/.gitkeep
│   │   └── README.md
│   ├── 40-architecture/
│   │   └── README.md
│   ├── 60-implementation/
│   │   └── README.md
│   └── 70-operations/
│       └── README.md
│
├── docs/
│   ├── lessons-learned.md             # Append-only, пустой при старте
│   ├── superpowers/
│   │   ├── specs/.gitkeep
│   │   └── plans/.gitkeep
│   └── overlays/
│       └── naumen-smp/
│           ├── README.md
│           ├── claude-md-patch.md
│           ├── doc-root-properties-smp.yaml
│           ├── glossary-skeleton.md
│           ├── references.md
│           └── agent-patches/
│               ├── ba-smp-extension.md
│               ├── sa-smp-extension.md
│               └── dev-smp-extension.md
│
└── scripts/
    ├── init.sh                        # First-run init
    ├── apply-overlay.sh               # Применить/откатить overlay
    └── test-template.sh               # Smoke-тест шаблона
```

### Принципы

- Что есть в marketplace — подключаем через `settings.json` (gramax, superpowers); ничего не вендорим без причины.
- Локальный плагин `project-template` — только то, что специфично шаблону (агенты, скиллы CTO, которых нет в публичных marketplace).
- `content/` — Gramax-каркас работает «из коробки».
- `docs/overlays/` — необязательные наборы patches (сегодня — SMP, завтра — может появиться `aiops/`, `crewai/` и т.п.).
- `scripts/` — только то, что реально упрощает старт; никакой магии.

## Конфигурация

### `.claude/settings.json`

```json
{
  "extraKnownMarketplaces": {
    "ai-assistants": {
      "source": {
        "source": "github",
        "repo": "mdemyanov/ai-assistants"
      }
    },
    "claude-plugins-official": {
      "source": {
        "source": "github",
        "repo": "anthropics/claude-plugins"
      }
    }
  },
  "enabledPlugins": {
    "gramax@ai-assistants": true,
    "superpowers@claude-plugins-official": true,
    "project-template@local": true
  }
}
```

### `CLAUDE.md` (универсальное ядро, ~80 строк)

Содержит:
- Карта команды (таблица команд → ролей → артефактов).
- Список подключённых плагинов.
- Поток работы (Researcher → BA → SA → Dev → DevOps; PM координирует).
- Ветвление `private`/`public`.
- Таблица «когда какой скилл звать».
- Красные линии (универсальные: secrets, PII, .doc-root.yaml без согласования, properties в content/, нет /dev без артефакта SA).
- Справочные пути (placeholder).
- Self-improvement (lessons-learned, auto-memory).

`{{PROJECT_NAME}}` — placeholder, заменяется через `init.sh`.

NOT in универсальный CLAUDE.md (уезжает в overlay): DDD-маппинг, FQN/HQL/`@InjectApi`, ссылки на `/Devel/naumen-ecosystem/`, ADR-цепочки/supersede.

### `AGENTS.md`

Содержит:
- Матрица ролей: роль / где исполняется / модель / команда / артефакты.
- Контракт вызова субагента: Цель / Входы / Артефакт / Критерии приёмки.
- Поток работы: канонический порядок Researcher → BA → SA → Dev → DevOps.
- Шаблон декомпозиции фичи (по аналогии с эталоном).
- Матрица эскалации.
- Retrospective workflow.

## Субагенты

Все агенты — отдельные `.md` в `.claude/plugins/project-template/agents/` с frontmatter:
```yaml
---
name: <role>-agent
description: <когда использовать>
model: sonnet  # PM — opus
---
```

| Агент | Модель | Назначение | Целевые каталоги |
|-------|--------|-----------|------------------|
| `pm-agent` | opus | Декомпозиция, координация. Режимы: `decompose`, `status`, `review` | (координирует) |
| `ba-agent` | sonnet | Требования (BABOK + JTBD). Шаблон статьи: JTBD/FR/NFR/BR/AC/User Journey | `content/30-requirements/` |
| `sa-agent` | sonnet | Архитектура + ADR. Универсальные шаблоны Components / Boundaries / Data flow | `content/00-project/adr/`, `content/40-architecture/` |
| `dev-agent` | sonnet | TDD-реализация по дизайну SA | `src/` (если есть), `content/60-implementation/` |
| `devops-agent` | sonnet | Runbook, deploy, мониторинг. **Optional** для проектов без инфры | `content/70-operations/` |
| `researcher-agent` | sonnet | Аналитические выжимки, исследования. Не пишет требования/ADR | `content/10-domain/research/` (создаётся агентом при первом запуске) |

## Slash-команды

7 файлов в `.claude/plugins/project-template/commands/`. Каждый ~30–40 строк, структура одинаковая:

```markdown
---
description: "<роль>. <что делает>. Пример: /<cmd> <режим> <аргументы>"
allowed-tools: Task
---

Запусти subagent `<name>-agent` через Task tool.

**Входы:** `$ARGUMENTS`

## Что передать subagent'у

Сформируй prompt по контракту из AGENTS.md:
1. Цель одной фразой
2. Входные файлы — пути
3. Ожидаемый артефакт
4. Критерии приёмки

## Режимы (распарсь $ARGUMENTS)

- <режим 1> — ...
- <режим 2> — ...
```

`pm.md` имеет расширенный `allowed-tools: Read, Glob, Grep, Write, Edit, Bash(git status:*), Bash(git log:*), Task` (живёт в main, нужны больше инструментов для координации).

`pm-review.md` — без `Task`, только `Read+Bash` для проверки целостности `content/` и lessons-learned.

## SMP-overlay (`docs/overlays/naumen-smp/`)

### Файлы

- **`README.md`** — инструкция применения/отката, требования (`naumen-smp-scripting` глобальный).
- **`claude-md-patch.md`** — блок для CLAUDE.md между маркерами `<!-- OVERLAY:naumen-smp:start -->` / `:end`. Содержит: SMP-стек, DDD-карту (BC/Aggregate/Repository/ACL), дополнительные red-lines (HQL параметризация, @InjectApi, error responses без stack traces, cross-каталожные Gramax-ссылки, ADR supersede правила).
- **`doc-root-properties-smp.yaml`** — фрагмент: добавляет property `Сценарий` со значениями A-F (placeholder под проект).
- **`glossary-skeleton.md`** — базовые SMP-термины (заявка, обращение, услуга, сервис, ОО, исполнитель, договор SLA, очередь). Мерж append-only.
- **`references.md`** — пути и ссылки: `naumen-ecosystem/naumen-smp`, `/itsm365`, документация SMP API, CodeNarc, Maven mirror.
- **`agent-patches/sa-smp-extension.md`** — DDD→SMP-маппинг (Aggregate=FQN, Repository=HQL, ACL=mapper), шаблон Tool-спеки, hexagonal architecture правила, ADR supersede-процедура, version-dependent statements, ADR-trail check.
- **`agent-patches/ba-smp-extension.md`** — JTBD-примеры в SMP-домене, ссылки на glossary.
- **`agent-patches/dev-smp-extension.md`** — Groovy reserved methods, обязательный `try/catch (Throwable) + logger.error(msg, e) + throw e` в MCP `call()`, hexagonal boundary check, CodeNarc priority 1/2 = 0.

### Подключение

`bash scripts/apply-overlay.sh naumen-smp` дописывает блоки в целевые файлы через маркеры. Идемпотентно (повторный запуск даёт пустой diff). Откат: `--remove naumen-smp`.

## Скрипты

### `scripts/init.sh`

Запускается один раз после клонирования:
1. Проверка, что мы в git-репо.
2. Создание ветки `private` (если нет).
3. Запрос `PROJECT_NAME` → `sed` подстановка `{{PROJECT_NAME}}` в CLAUDE.md, README.md.
4. Копирование `.env.example` → `.env`, если нет.
5. Подсказка про доступные overlays.

### `scripts/apply-overlay.sh`

Использование:
- Применить: `scripts/apply-overlay.sh naumen-smp`
- Откатить:  `scripts/apply-overlay.sh --remove naumen-smp`

Алгоритм apply (идемпотентный):
1. Удалить существующие блоки между маркерами `OVERLAY:<name>:start/end` в целевых файлах.
2. Вставить актуальное содержимое патчей.
3. Файлы-цели:
   - `CLAUDE.md` ← `claude-md-patch.md`
   - `content/.doc-root.yaml` ← `doc-root-properties-smp.yaml` (мерж YAML с проверкой)
   - `content/10-domain/glossary.md` ← `glossary-skeleton.md` (append-only)
   - `.claude/plugins/project-template/agents/<role>-agent.md` ← `agent-patches/<role>-smp-extension.md` (для sa/ba/dev)

Реализация — bash + sed/awk; YAML-мерж — простой (если ключа нет — добавить). Без внешних зависимостей.

### `scripts/test-template.sh`

Smoke-тест шаблона на временной копии в `/tmp/`:
1. `cp -R . /tmp/template-test/` (исключая .git, .worktrees).
2. `cd /tmp/template-test/ && git init && git add -A && git commit -m init`.
3. `bash scripts/init.sh` с входом `test-project` — проверка: `{{PROJECT_NAME}}` исчез, ветка `private` создана, `.env` скопирован.
4. `bash scripts/apply-overlay.sh naumen-smp` — проверка: маркеры появились в CLAUDE.md и трёх агентах; SMP-термины в glossary.md.
5. `bash scripts/apply-overlay.sh --remove naumen-smp` — проверка: маркеры исчезли.
6. Двойной apply — идемпотентность (diff между запусками = пусто).
7. Валидация `.claude/settings.json` (jq).
8. Валидация frontmatter во всех `agents/*.md` (`name`, `description`, `model`).
9. Cleanup `/tmp/template-test/`.

Скрипт обязателен для контрибьюторов: «Перед PR в шаблон — прогони `scripts/test-template.sh`».

## Ветвление

- `private` — рабочая ветка, все правки идут сюда.
- `public` — публикация в Gramax после merge из `private`.
- Перед merge — `/pm-review`.

## Что НЕ делаем (scope-границы)

- **Не делаем CI/CD** для самого шаблона. `test-template.sh` запускается вручную или через локальный pre-commit.
- **Не настраиваем GitHub Template Repository flag** — это действие пользователя в UI GitHub.
- **Не добавляем `.mcp.json`** (не нужен).
- **Не вносим CrewAI/AIOps/etc-специфику** — это будущие overlays.
- **Не делаем автоматическую синхронизацию CTO-скиллов**. Они копируются один раз; обновление — ручное (зафиксировано в Maintenance-разделе README).
- **Не настраиваем pre-commit hooks в settings.json** — пользователь добавит при необходимости.
- **Не версионируем overlay**. Один источник правды — `docs/overlays/<name>/`.

## Maintenance

В `README.md` шаблона — раздел «Для мейнтейнеров»:
- Источники CTO-скиллов: `/Users/mdemyanov/Documents/naumen-cto/.claude/skills/{infoinstyle,correspondence-2}/`. При обновлении — `cp -R <src> .claude/plugins/project-template/skills/<name>/`.
- Источники эталонов агентов: `/Users/mdemyanov/knowlage/sd-ai-assistant`, `/Users/mdemyanov/Devel/naumen-smp-mcp`. Универсальный slice уже извлечён; SMP-специфика — в overlay.
- При апгрейде marketplace `ai-assistants` (gramax v2 и т.п.) — прогнать `test-template.sh`.

## Acceptance Criteria

Шаблон считается готовым, когда:

1. `bash scripts/init.sh` отрабатывает на чистом клоне за один проход.
2. После init: открытие репо в Claude Code загружает `gramax`, `superpowers`, `project-template@local` без ошибок (видны команды `/pm`, `/ba`, `/sa`, `/dev`, `/devops`, `/research`, `/pm-review` и скиллы `infoinstyle`, `correspondence-2`).
3. `/pm decompose "тестовая фича"` возвращает декомпозицию по шаблону BA→SA→Dev→DevOps без обращения к SMP-словарю (универсальный режим).
4. `bash scripts/apply-overlay.sh naumen-smp` отрабатывает за один проход; повторный запуск даёт пустой diff (идемпотентность).
5. После apply overlay `/sa "спроектируй MCP-tool"` упоминает FQN/HQL/`@InjectApi` (overlay вступил в силу).
6. `bash scripts/apply-overlay.sh --remove naumen-smp` возвращает файлы к pre-overlay состоянию (по ключевым строкам).
7. `bash scripts/test-template.sh` зелёный.
8. Каркас `content/` валидируется Gramax (`.doc-root.yaml` корректен, обязательные properties описаны).

## Open Questions

Нет. Все вопросы закрыты на этапе brainstorming (см. таблицу решений выше).
