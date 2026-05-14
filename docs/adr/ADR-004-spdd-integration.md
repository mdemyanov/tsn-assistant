---
title: "ADR-004: SPDD Integration — two-way sync, Safeguards, drift-check"
properties:
  - name: Тип контента
    value: [ADR]
  - name: Статус
    value: [Approved]
  - name: Фаза
    value: [MVP]
---

# ADR-004: SPDD Integration — two-way sync, Safeguards, drift-check

**Статус:** Approved
**Дата:** 2026-05-14

---

## Context

Thoughtworks опубликовали SPDD (Structured-Prompt-Driven Development) в апреле 2026. Сравнительный анализ (RES-001) показал: project_template уже реализует ~70% идей SPDD через workflow PM→BA→SA→Dev, но три gap остаются незакрытыми:

1. Правило двусторонней синхронизации слоёв нигде явно не зафиксировано и не проверяется механически.
2. Неоспоримые инварианты артефакта (Safeguards) отсутствуют в шаблонах BA и tech-writer — они либо размазаны по тексту, либо пропущены.
3. Расхождения между слоями (drift) не обнаруживаются автоматически — всё держится на дисциплине команды.

Шаблон поддерживает 7 профилей: project, product, kb-team, kb-product, methodology, course, custom. Четыре из них (kb-team, kb-product, methodology, course) — content-only: они не используют `src/` и роли SA/Dev. Любое решение должно работать для всех 7 профилей без специальных случаев для content-only.

Источники: kickoff-спека `docs/superpowers/specs/2026-05-14-spdd-integration-kickoff-prompt.md`; research-note `content/10-domain/spdd-key-principles.md`; BA-требования BA-001, BA-002, BA-003 (`content/30-requirements/spdd-*.md`).

---

## Decision

Принимаем **выборочную интеграцию трёх идей SPDD** как process-rules и расширения шаблона:

### 1. Правило two-way sync в CLAUDE.md

В шаблонный `CLAUDE.md` добавляется раздел «Правило two-way sync» с универсальной формулировкой: при любом расхождении нижестоящего слоя с вышестоящим — сначала обновляется вышестоящий, потом нижестоящий. Единственное исключение — hotfix на production с обязательным post-mortem обновлением upstream. Нарушение без bypass-trailer — блокер для /pm-review. В `README.md` — short pointer на этот раздел.

### 2. Секция «Инварианты и Safeguards» в шаблонах агентов

В `.claude/plugins/project/agents/ba-agent.md` и `tech-writer-agent.md` добавляется обязательная секция `## Инварианты и Safeguards` с тремя подразделами (Содержательные, Sensitive content, Жизненный цикл). Молчаливый пропуск — нарушение шаблона; допустим явный `N/A с обоснованием`. Формулировки — бинарные hard constraints, не AC.

### 3. Drift-check в /pm-review, параметризованный полем drift_pairs

Каждый из 7 манифестов профиля (`docs/overlays/profiles/*/manifest.yaml`) получает поле `drift_pairs` — список пар upstream/downstream path (glob-паттерны). При запуске `/pm-review` шаг drift-check читает активный профиль репозитория, загружает `drift_pairs` и сравнивает diff `private..public`. Если downstream изменён без upstream — WARN с именами файлов. Поддерживается bypass-trailer `skip-drift: <reason>`. Отсутствие `drift_pairs` → INFO-skip (backward-compat).

**Как определяется активный профиль:** через поле `profile:` в `content/.doc-root.yaml`. Это наименее invasive решение — файл уже обязателен в каждом Gramax-каталоге. Подробнее: `docs/superpowers/specs/2026-05-14-spdd-integration-design.md`, §3d.

---

## Consequences

**Positive:**
- Gap 30% закрывается без слома существующего workflow PM→BA→SA→Dev.
- Правило two-way sync становится явным и машинно-проверяемым, а не только командным соглашением.
- Safeguards-секция стандартизирует фиксацию инвариантов для всех 7 профилей, включая content-only.
- Backward-compat: pre-SPDD проекты не ломаются (INFO-skip при отсутствии drift_pairs).

**Negative:**
- Разработчики новых профилей обязаны определять `drift_pairs` в manifest — дополнительная ответственность при расширении шаблона.
- Drift-check покрывает только явно объявленные пары; неявные расхождения остаются вне проверки.
- Поле `profile:` в `.doc-root.yaml` — новое соглашение, требует документирования и опционального upgrade-playbook для старых проектов.

**Neutral / Mitigations:**
- `drift_pairs` для `custom` — пустой массив; заполняется на `/init` под конкретный проект.
- Bypass-trailer `skip-drift: <reason>` покрывает hotfix и pure-refactoring сценарии без блокирования команды.
- Опциональный `docs/upgrading-from-template.md` описывает шаги для миграции старых проектов.

---

## Alternatives Considered

### (a) Полная имплементация SPDD — Canvas, /spdd-generate, /spdd-sync команды

Реализовать SPDD-tooling в полном объёме: REASONS Canvas как артефакт, отдельные slash-команды `/spdd-generate` и `/spdd-sync`, интеграция с openspdd.

**Отклонено:** дублирует существующий workflow PM→BA→SA→Dev. REASONS Canvas семантически эквивалентен артефактам BA + SA, которые уже создаются. Новые slash-команды создают параллельный поток без ценности. Объём изменений несоразмерен закрываемому gap.

### (b) Status quo — ничего не менять

Принять, что шаблон уже реализует 70% и этого достаточно. Gap 30% покрывается командной дисциплиной.

**Отклонено:** drift без механической проверки игнорируется под давлением сроков. Отсутствие Safeguards-секции критично для regulated-контекстов и content-only профилей, где нет BA. Gap 30% документально зафиксирован (RES-001) и прямо запрошен owner'ом.

### (c) Выборочная интеграция трёх идей как process-rules (наш выбор)

Точечные изменения в CLAUDE.md, agent-промптах и manifest-файлах без создания новых команд или артефактных типов. Минимальный invasive, максимальная совместимость.

**Принято.**

---

## Влияние на 7 профилей

| Профиль | two-way sync | Safeguards | drift_pairs |
|---------|-------------|------------|-------------|
| `project` | CLAUDE.md — пары: `content/30-requirements/→src/`, `content/40-architecture/→src/`, `content/30-requirements/→content/60-implementation/`, `content/40-architecture/→content/70-operations/` | ba-agent | 4 пары (mixed: content→code и content→content) |
| `product` | пары: `content/10-vision/→content/30-specs/`, `content/30-specs/→content/40-architecture/`, `content/40-architecture/→src/`, `content/30-specs/→content/50-releases/` | ba-agent | 4 пары |
| `kb-team` | пары: `content/40-roles/→content/30-runbooks/`, `content/30-runbooks/→content/20-onboarding/`, `content/10-domain/→content/40-roles/`, `content/50-incidents/→content/30-runbooks/` | tech-writer-agent | 4 пары (content→content) |
| `kb-product` | пары: `content/reference/→content/guides/`, `content/guides/→content/troubleshooting/`, `content/reference/→content/getting-started/` | tech-writer-agent | 3 пары (content→content) |
| `methodology` | пары: `content/10-principles/→content/20-practices/`, `content/20-practices/→content/30-playbooks/`, `content/30-playbooks/→content/40-templates/` | tech-writer-agent | 3 пары (content→content) |
| `course` | пары: `content/*-module-*/→content/90-assessments/`, `content/00-overview/→content/*-module-*/` | tech-writer-agent | 2 пары с glob (content→content) |
| `custom` | пустой список, заполняется на `/init` | ba-agent или tech-writer-agent | `[]` |

**Примечание по `course`:** фактический scaffold использует `10-module-01-introduction` и `20-module-02-example` — оба имеют числовой префикс, но разный. Glob `content/*-module-*/` покрывает оба каталога. Это отклонение от PM-плана (`content/10-module-*/`), который покрыл бы только первый модуль.

**Примечание по `project` и `product`:** `src/` — не часть content-scaffold, но валидный target для code-профилей.

---

## Out-of-scope (явно)

- Новый профиль `regulated` — отдельный wave при появлении compliance-кейса.
- Slash-команда `/pm canvas` — отдельный wave.
- Переписывание workflow PM→BA→SA→Dev — не затрагивается.
- Изменение матрицы ролей и pipelines — не затрагивается.
- Изменение контракта вызова субагентов — не затрагивается.

---

## Связанные статьи

- Kickoff-спека: `docs/superpowers/specs/2026-05-14-spdd-integration-kickoff-prompt.md`
- PM-план: `docs/superpowers/plans/2026-05-14-spdd-integration.md`
- Research-note: `content/10-domain/spdd-key-principles.md`
- BA-001: `content/30-requirements/spdd-two-way-sync.md`
- BA-002: `content/30-requirements/spdd-safeguards-section.md`
- BA-003: `content/30-requirements/spdd-drift-check.md`
- Design-spec: `docs/superpowers/specs/2026-05-14-spdd-integration-design.md`
