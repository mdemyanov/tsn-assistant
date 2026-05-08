---
properties:
  - name: Тип контента
    value: [Архитектура]
  - name: Статус
    value: [Approved]
---

# Spec: профиль product (stable)

## Manifest

`docs/overlays/profiles/product/manifest.yaml`:

```yaml
schema_version: 1
name: product
description: Разработка продукта/модуля — internal docs от vision до release (team-facing)
audience: Продуктовые менеджеры, системные аналитики, разработчики, QA
status: stable

subagents:
  pm: core
  ba: core
  sa: core
  dev: core
  qa: core
  tech-writer: core
  researcher: optional
  devops: optional
  devsecops: optional
  compliance: optional

pipelines:
  project-planning: optional
  ba-acceptance: optional
  critical-path: disabled
  scrum-agile: disabled

content_scaffold: content-scaffold/
doc_root: doc-root.yaml

operations:
  - op: add
    source: content-scaffold/
    target: content/
    reason: "product scaffold (10-vision, 20-discovery, 30-specs, 40-architecture, 50-releases)"
  - op: replace
    source: doc-root.yaml
    target: content/.doc-root.yaml
    reason: "product properties (Тип контента, Статус, Версия, Аудитория)"

agent_overrides:
  tech-writer:
    source: agent-overrides/tech-writer.md
  sa:
    source: agent-overrides/sa.md

init_prompts: []

compatible_stacks: []
maintainer: project_template
```

**Почему нет `op: delete`:**
После Wave 4b baseline `content/` содержит только `_index.md` + `.doc-root.yaml`. Удалять нечего — delivery-папок (00-project, 60-implementation, 70-operations) в базовом baseline нет. Каждый профиль декларирует весь scaffold через `op: add`. Ср. kb-product manifest (W4b-пост): те же два op (add + replace).

## content-scaffold/

### Дерево

```
docs/overlays/profiles/product/content-scaffold/
├── _index.md                       # корневой index с дашбордом
├── 10-vision/
│   └── _index.md
├── 20-discovery/
│   └── _index.md
├── 30-specs/
│   └── _index.md
├── 40-architecture/
│   └── _index.md
└── 50-releases/
    └── _index.md
```

Все `_index.md` — без блока `properties:` (правило Gramax).

### Содержимое `_index.md` файлов

**`content-scaffold/_index.md`:**

```markdown
---
order: 0
title: {{PROJECT_NAME}} — Product Docs
---

{{PROJECT_DESCRIPTION}}

## Навигация

- [Vision](10-vision/)
- [Discovery](20-discovery/)
- [Specs](30-specs/)
- [Architecture](40-architecture/)
- [Releases](50-releases/)

## Дашборд

<view defs="Тип контента=Vision&Discovery&Spec&ADR&Release Notes" groupby="Статус" display="List"/>
```

**`content-scaffold/10-vision/_index.md`:**

```markdown
---
order: 10
title: Vision
---

# Product Vision

Product vision, goals, scope и non-goals.

Типичные артефакты: vision.md, personas.md, success-metrics.md
```

**`content-scaffold/20-discovery/_index.md`:**

```markdown
---
order: 20
title: Discovery
---

# Discovery

Research, competitive analysis, user personas.

Типичные артефакты: research-*.md, competitive.md
```

**`content-scaffold/30-specs/_index.md`:**

```markdown
---
order: 30
title: Specs
---

# Feature Specs

Функциональные спеки, user stories, acceptance criteria.

Типичные артефакты: spec-<feature>.md; допускаются per-feature подпапки.
```

**`content-scaffold/40-architecture/_index.md`:**

```markdown
---
order: 40
title: Architecture
---

# Architecture

ADR, data model, архитектурные решения.

Типичные артефакты: NNN-title.md в формате MADR.
```

**`content-scaffold/50-releases/_index.md`:**

```markdown
---
order: 50
title: Releases
---

# Releases

Internal changelog и release notes для разработчиков и PM.

Аудитория — Internal. Customer-facing release notes публикуются в kb-product каталоге.

Типичные артефакты: CHANGELOG.md, v1.2.0.md
```

## doc-root.yaml

`docs/overlays/profiles/product/doc-root.yaml`:

```yaml
title: "{{PROJECT_NAME}} — Product Docs"
description: {{PROJECT_DESCRIPTION}}
syntax: XML
language: ru
editors:
  - {{EDITOR_EMAIL}}

properties:
  - name: Тип контента
    type: Enum
    style: blue
    icon: file-text
    values:
      - Vision
      - Discovery
      - Spec
      - ADR
      - Release Notes
      - Roadmap
    required: true

  - name: Статус
    type: Enum
    style: green
    icon: check
    values: [Draft, Review, Approved, Shipped, Deprecated]
    required: true

  - name: Версия
    type: String
    style: purple
    icon: tag
    placeholder: "v1.2.3"
    required: false

  - name: Аудитория
    type: Enum
    style: yellow
    icon: users
    values: [Internal, External]
    required: false

filterProperties: [Тип контента, Статус, Версия, Аудитория]
```

**Обоснование properties:**

- `Тип контента` (required) — охватывает все разделы scaffold: Vision/Discovery/Spec/ADR/Release Notes/Roadmap. ADR выделен отдельно (не обобщается в «Architecture»).
- `Статус` (required) — расширен до Shipped и Deprecated, критичных для release notes и устаревших specs.
- `Версия` (optional) — semver-строка; обязательна смыслово для Release Notes, не нужна для Vision/Discovery. Реализуется через required: false + бизнес-правило: при Тип контента = Release Notes команда должна заполнять.
- `Аудитория` (optional) — Internal / External; ключевое поле-маркер: если статья имеет Аудитория: External, это сигнал переместить в kb-product.

## Agent overrides

### tech-writer для product

`docs/overlays/profiles/product/agent-overrides/tech-writer.md`:

```markdown
---
extends: tech-writer
description: Технический писатель — внутренняя документация продуктового цикла
---

## Роль

Internal product tech writer. Пишешь **внутреннюю** документацию продукта: release notes и changelog для команды разработки, PM и QA — не для конечных пользователей.

Принципы:
- Аудитория — разработчики и PM, не конечные пользователи
- Ссылайся на тикеты и ADR, а не на UI-скриншоты
- Каждый внутренний release notes — технический diff с контекстом решений

## Domain

- **Changelog format (keep-a-changelog.org convention):** группируй изменения по категориям:
  - `Added` — новая функциональность
  - `Changed` — изменения в существующем функционале
  - `Fixed` — исправленные баги
  - `Removed` — удалённый функционал
  - `Deprecated` — функционал, помеченный к удалению
- **Internal links:** ссылки на тикеты (Jira, GitHub Issues) и ADR обязательны в release notes.
- **Internal vs External boundary:** внутренний CHANGELOG (аудитория Internal, `50-releases/`) — для команды. Customer-facing release notes (аудитория External) — делегируются в kb-product каталог. Если статья получает Аудитория: External — сообщи команде о необходимости перенести в kb-product.
- **ADR references:** в release notes при значимых product-решениях ссылайся на соответствующий ADR из `40-architecture/`.
- **Version tagging:** каждый release notes файл именуется по semver (`v1.2.0.md`) и содержит property Версия.
```

NB: секции `## Constraints` и `## Tools` наследуются из base tech-writer без изменений (AC-tw-4).

### sa для product

`docs/overlays/profiles/product/agent-overrides/sa.md`:

```markdown
---
extends: sa
description: Системный аналитик — product decision framing для ADR
---

## Роль

Product-context SA. Проектируешь архитектурные решения в контексте продуктового цикла: ADR охватывают не только технические, но и product decisions.

## Domain

- **Product ADR scope:** решения включают: build vs buy, feature scope (что входит/не входит в MVP), pricing model, интеграционные контракты с внешними системами.
- **ADR location:** `40-architecture/NNN-title.md` в формате MADR (canonical: adr.github.io/madr).
- **ADR нумерация:** последовательная (0001-, 0002-…); статус: Proposed → Accepted/Rejected/Superseded.
- **Product context в ADR:** в секции Context всегда указывай бизнес-драйвер (user story или product goal), не только технический контекст.
- **Cross-catalog references:** ссылки между product-каталогом и другими каталогами (kb-product, project) — только inline code, не markdown link.
```

## Operations

```yaml
operations:
  - op: add
    source: content-scaffold/
    target: content/
    reason: "product scaffold (10-vision, 20-discovery, 30-specs, 40-architecture, 50-releases)"
  - op: replace
    source: doc-root.yaml
    target: content/.doc-root.yaml
    reason: "product properties (Тип контента, Статус, Версия, Аудитория)"
```

**Почему только add + replace, без op:delete:**
После Wave 4b baseline `content/` создаётся пустым (только `_index.md` + `.doc-root.yaml`). Delivery-структура (`00-project/`, `60-implementation/`, `70-operations/`) в baseline не присутствует — удалять нечего. Это инвариант всех постW4b профилей: каждый профиль полностью декларирует свой scaffold через `op: add`.

## Verification

Checklist для DEV-W4c-A-30 после реализации:

- [ ] `python3 scripts/validate-profile.py` проходит без ошибок
- [ ] `bash scripts/apply-overlay.sh --profile product --dry-run` показывает ровно 2 операции (add + replace), без op:delete
- [ ] `docs/overlays/profiles/product/manifest.yaml` — валидный YAML, `status: stable`
- [ ] Scaffold содержит ровно 5 подпапок: `10-vision/`, `20-discovery/`, `30-specs/`, `40-architecture/`, `50-releases/`
- [ ] В каждой подпапке есть `_index.md`; ни один `_index.md` не содержит блок `properties:`
- [ ] Отсутствуют delivery-папки: `00-project/`, `60-implementation/`, `70-operations/` в scaffold
- [ ] `content-scaffold/_index.md` содержит корневой дашборд с `<view>` блоком
- [ ] Resolved tech-writer prompt содержит секцию `## Роль` с «Internal product tech writer» (AC-tw-1)
- [ ] Resolved tech-writer prompt содержит changelog-группировку Added/Changed/Fixed/Removed/Deprecated (AC-tw-2)
- [ ] Resolved tech-writer prompt явно разграничивает internal CHANGELOG vs customer release notes (AC-tw-3)
- [ ] Override применяется через `extends: tech-writer`, не полная замена (AC-tw-5)
- [ ] Resolved SA prompt содержит секцию `## Роль` с «Product-context SA» и product ADR framing
- [ ] `doc-root.yaml` содержит 4 properties: Тип контента (required), Статус (required), Версия (optional), Аудитория (optional)
- [ ] `examples/product-example/` создан с resolved agent prompts (аналогично kb-product-example)
- [ ] `bash scripts/init.sh --profile product "TestProduct" "TP" "desc" "test@x.com"` exit 0

## Решения по BRQ open questions

### 1. Дополнительный sa override

**Решение: YES — sa override включён.**

Обоснование: product ADR принципиально отличается от delivery ADR. В delivery-контексте SA фокусируется на технических решениях (выбор стека, разделение слоёв). В product-контексте ADR охватывает build vs buy, feature scope, pricing model — это product decisions, не только architectural. Без override SA будет давать delivery-framing в product-каталоге, что приведёт к некачественным ADR. Override минимальный: `## Роль` + `## Domain`, наследует base SA полностью через `extends: sa`.

### 2. Версия required только для Release Notes

**Решение: `required: false` в doc-root.yaml, бизнес-правило в документации.**

Обоснование: Gramax doc-root.yaml не поддерживает conditional required (required зависящий от другого поля). Реализация conditional через required: true сделает поле обязательным для всех типов, что неверно (у Vision нет версии). Решение: `required: false` + явное бизнес-правило в `content-scaffold/50-releases/_index.md` ("каждый release notes файл должен содержать property Версия") + в agent-override tech-writer ("Version tagging: каждый release notes файл содержит property Версия"). Enforcement — конвенция + review, не валидатор.

## Контракт с QA-author

**AC (полный список из BRQ):**
- AC-tw-1: Resolved tech-writer prompt содержит секцию «## Роль» с явным указанием «Internal product tech writer» и описанием аудитории
- AC-tw-2: Resolved prompt содержит секцию «## Domain» с правилами changelog-формата (Added/Changed/Fixed/Removed/Deprecated)
- AC-tw-3: Resolved prompt явно разграничивает internal CHANGELOG vs customer release notes
- AC-tw-4: Секции `## Constraints` и `## Tools` наследуются из base без изменений
- AC-tw-5: Override применяется через `extends: tech-writer`

**Архитектурный контекст для тестов:**
- Компоненты: manifest.yaml, content-scaffold/, doc-root.yaml, agent-overrides/tech-writer.md, agent-overrides/sa.md
- Интеграции: `scripts/apply-overlay.sh` (читает manifest.yaml, применяет operations), `scripts/validate-profile.py` (валидирует структуру профиля), `scripts/init.sh` (full init flow с resolve агентов)
- Trust boundaries: manifest.yaml → apply-overlay.sh → content/ (scaffold + doc-root); agent-overrides/ → init.sh → .claude/plugins/project/agents/ (resolved prompts)

**Edge cases / boundary conditions:**
- Scaffold init поверх существующего content/ с файлами — `op: add` не должен затирать существующие файлы (проверить поведение apply-overlay)
- `doc-root.yaml` с `required: false` для Версия — валидатор не должен требовать Версия для Vision/Discovery артефактов
- `extends: sa` в sa override — механизм resolve должен корректно merge base + override (как tech-writer)
- `<view>` блок в `_index.md` — Gramax должен корректно рендерить без ошибок

**Test-pyramid рекомендация:**

| AC group | Уровень | Обоснование |
|----------|---------|-------------|
| AC-tw-1/2/3/5 (override content) | unit/integration | grep resolved prompt после init |
| AC-tw-4 (inheritance) | integration | diff base vs resolved — Constraints/Tools присутствуют |
| scaffold structure (5 папок, _index.md без properties) | integration | file existence + grep |
| op plan (add+replace, no delete) | unit | dry-run output |
| full init flow (exit 0) | e2e | `scripts/init.sh --profile product` |
