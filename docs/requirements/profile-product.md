---
properties:
  - name: Тип контента
    value: [Требование]
  - name: Статус
    value: [Approved]
---

# Профиль product — функциональные требования

## Контекст

Профиль `product` предназначен для команд, ведущих разработку продукта или модуля: от формирования видения до выпуска версий. Целевая аудитория — продуктовые менеджеры, системные аналитики, разработчики и QA, работающие над внутренней документацией продуктового цикла.

### Граница vs kb-product

`product` = **internal product development docs**: vision, discovery, specs, ADR, технические решения, internal changelog. Аудитория — команда разработки.

`kb-product` = **external customer-facing docs**: getting started, guides, troubleshooting, user release notes. Аудитория — конечные пользователи и администраторы.

**Release notes — пограничный тип.** Решение: внутренний CHANGELOG (технический diff для разработчиков) живёт в `product` (`50-releases/`). Customer-facing release notes (narrative для пользователей) — в `kb-product`. Разграничение фиксируется через property **Аудитория**: `Internal` vs `External`. Дублирования нет: два каталога покрывают разные читательские потребности.

Профиль `product` не подменяет `project` (delivery-tracking, Jira-like задачи, runbook'и). Если команде нужен и delivery и product-docs — создаётся два каталога с разными профилями.

## Структурные требования

### content-scaffold/

```
content-scaffold/
├── _index.md
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

**Описание разделов:**

| Раздел | Назначение | Типичные артефакты |
|--------|------------|--------------------|
| `10-vision/` | Product vision, goals, scope, non-goals | vision.md, personas.md, success-metrics.md |
| `20-discovery/` | Research, competitive analysis, user personas | research-*.md, competitive.md |
| `30-specs/` | Feature specs, user stories, acceptance criteria | spec-<feature>.md; допускается per-feature subdir |
| `40-architecture/` | ADR, data model, архитектурные решения | NNN-title.md (canonical MADR формат) |
| `50-releases/` | Internal changelog, release notes (аудитория Internal) | CHANGELOG.md, v1.2.0.md |

Все `_index.md` — без блока `properties:` (правило Gramax). Статьи в подпапках содержат properties.

Нумерация папок (10-, 20-, …) используется, так как в product-цикле порядок прохождения артефактов значим: vision предшествует discovery, discovery — specs. Это согласуется с паттерном `project` и `kb-team`.

**Опциональные разделы** (не входят в scaffold, создаются вручную при необходимости):

- `60-roadmap/` — если roadmap ведётся как docs, а не в issue-tracker
- `70-metrics/` — OKR, success metrics, dashboards

### subagents

| Роль | Статус | Обоснование |
|------|--------|-------------|
| pm | core | Координация продуктового цикла, всегда нужен |
| ba | core | Elicitation requirements, specs — центральная роль в product |
| sa | core | ADR, data model, архитектурные решения |
| dev | core | Реализация по specs и ADR |
| qa | core | Acceptance tests для specs |
| tech-writer | core | Release notes и внутренние changelog'и |
| researcher | optional | Discovery phase, competitive analysis |
| devops | optional | Release pipeline, deploy процессы |
| devsecops | optional | Security review для product решений |
| compliance | optional | Если продукт под регуляторными требованиями |

Текущий manifest объявляет эту матрицу корректно. BRQ подтверждает без изменений.

### agent_overrides

**Обязательный override: `tech-writer.md`**

В контексте `product` tech-writer пишет **internal** release notes и changelog'и — аудитория разработчики и продуктовые менеджеры, не конечные пользователи. Это принципиально отличается от `kb-product`, где тот же tech-writer пишет для customers.

Без override tech-writer унаследует base-поведение (generic writing) и не будет знать:
- что changelog должен группироваться по типам изменений (Added / Changed / Fixed / Removed / Deprecated — keep-a-changelog.org convention)
- что внутренние release notes ссылаются на тикеты/ADR, а не на UI-скриншоты
- что аудитория — разработчики, а не пользователи

**Дополнительный кандидат: `sa.md`** (опциональный, решение оставлено SA)

Product ADR отличается от delivery ADR: фокус на product decisions (build vs buy, feature scope, pricing model), а не только на архитектуре. SA может потребоваться override на product decision framing. Оставить как open question для SA-фазы.

### .doc-root.yaml properties

| Property | Required | Тип | Значения | Обоснование |
|----------|----------|-----|---------|-------------|
| Тип контента | yes | enum | Vision, Discovery, Spec, ADR, Release Notes, Roadmap | Охватывает все разделы scaffold; ADR выделен отдельно (не просто «Architecture») |
| Статус | yes | enum | Draft, Review, Approved, Shipped, Deprecated | Shipped и Deprecated критичны для release notes и устаревших specs |
| Версия | no | string | semver, e.g. "v1.2.3" | Обязателен для Release Notes; опционален для Vision/Discovery |
| Аудитория | no | enum | Internal, External | Разграничивает internal changelog от customer-facing (External → kb-product) |

**Обоснование выбора:**
- `Тип контента` + `Статус` — минимальный знаменатель (cross-cutting finding из research).
- `Версия` — опциональна (не все артефакты версионируются; у vision нет версии).
- `Аудитория` — ключевое поле для разграничения internal/external release notes без создания отдельного каталога.
- Поле `Уровень сложности` (из course) и `Область применения` (из methodology) — не нужны для product.

## Override AC: tech-writer для product

**AC-tw-1:** Resolved tech-writer prompt содержит секцию «## Роль» с явным указанием «Internal product tech writer» и описанием аудитории (разработчики, PM, QA).

**AC-tw-2:** Resolved prompt содержит секцию «## Domain» с правилами changelog-формата: группировка по Added / Changed / Fixed / Removed / Deprecated; ссылки на тикеты и ADR вместо UI-скриншотов.

**AC-tw-3:** Resolved prompt явно разграничивает: internal CHANGELOG (аудитория Internal, живёт в `50-releases/`) vs customer release notes (аудитория External, делегируется в `kb-product`).

**AC-tw-4:** Секции `## Constraints` и `## Tools` наследуются из base tech-writer без изменений.

**AC-tw-5:** Override применяется через `extends: tech-writer` (аналогично `kb-product/agent-overrides/tech-writer.md`) — не полная замена, а дополнение.

## Operations

После init `product` в каталоге должны отсутствовать артефакты delivery-структуры из `project` профиля (00-project, 60-implementation, 70-operations не нужны). Нужные операции:

| Op | Source | Target | Причина |
|----|--------|--------|---------|
| `op: add` | `content-scaffold/` | `content/` | Развернуть scaffold (10-vision … 50-releases) |
| `op: replace` | `doc-root.yaml` | `content/.doc-root.yaml` | Применить product properties (Тип контента, Статус, Версия, Аудитория) |

Операция `op: delete` не нужна (новый каталог создаётся с нуля; если init поверх существующего — это отдельный сценарий миграции, вне скоупа данного BRQ).

## Out of scope

- **Customer-facing docs** (getting started, guides, troubleshooting, user release notes) — это `kb-product`.
- **Delivery tracking** (задачи, спринты, ретроспективы, runbook'и) — это `project`.
- **Публичный roadmap** в формате GitHub Projects или issue-tracker — не документируется в Gramax; только внутренний roadmap как markdown может жить в `60-roadmap/`.
- **API reference, CLI reference** — генерируется автоматически (OpenAPI/CLI tools); не создаётся вручную в `product` каталоге.
- **Team onboarding** (how-to для новых участников команды) — это `kb-team`.
- **Методология разработки** (playbook'и, фреймворки, принципы) — это `methodology`.

## Бриф для SA

**Требование:** `docs/requirements/profile-product.md`  **Фаза:** W4c-A / stub→stable промоция

**Спроектировать:**
1. Scaffold: 5 папок (10-vision … 50-releases) + все `_index.md` без properties.
2. `doc-root.yaml`: 4 properties (Тип контента, Статус, Версия, Аудитория) с типами и values из таблицы выше.
3. Agent override: `agent-overrides/tech-writer.md` с `extends: tech-writer`; содержание — по AC-tw-1…AC-tw-5.
4. `manifest.yaml`: заполнить `operations`, `agent_overrides`, `content_scaffold`, `doc_root`; поменять `status: stub` → `stable`.
5. Решить (open question): нужен ли `agent-overrides/sa.md` для product ADR framing.

**Бизнес-правила для валидаций:**
- Все `_index.md` в scaffold — без блока `properties:`.
- `Аудитория: External` в release notes — маркер для команды перенести статью в `kb-product`.
- `Версия` обязательна только для `Тип контента: Release Notes`.

**Acceptance criteria для проверки архитектуры:**
- `python3 scripts/validate-profile.py` проходит без ошибок после применения overlay.
- `bash scripts/apply-overlay.sh --profile product --dry-run` показывает корректный plan (add scaffold + replace doc-root).
- Resolved tech-writer prompt содержит секцию «## Роль» с «Internal product tech writer» (AC-tw-1).
- Scaffold разворачивается без delivery-папок (00-project, 60-implementation, 70-operations отсутствуют).
