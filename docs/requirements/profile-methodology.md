---
properties:
  - name: Тип контента
    value: [Требование]
  - name: Статус
    value: [Approved]
---

# Профиль methodology — функтребования

## Контекст

Профиль `methodology` предназначен для команд, которые создают и развивают собственную методологию, playbook или framework. Целевая аудитория — внутренние команды (engineering leads, agile coaches, центры компетенций), которым нужна структура «принципы → практики → playbooks → шаблоны → кейсы».

**Граница vs `kb-team`:** `kb-team` описывает операционные знания конкретной команды (runbooks, onboarding, роли). `methodology` описывает нормативную систему — правила и рекомендации, которым другие команды должны следовать. Контент `methodology` prescriptive («команды должны»), контент `kb-team` — descriptive («наша команда делает так»).

**Граница vs `project`:** `project` — delivery-ориентированный профиль с требованиями, архитектурой и имплементацией. `methodology` не содержит delivery-артефактов (нет `30-requirements/`, `40-architecture/`, `60-implementation/`).

## Решение по глубине иерархии

**Решение: flat (раздел > статья) с поддержкой необязательных подпапок.**

Обоснование: бенчмарки показывают, что GitLab Handbook (plоский) и LeSS (Principles → Rules → Guides) покрывают 80% реальных use case без глубокой вложенности. SAFe-уровень иерархии (4 уровня) нужен только для масштабных enterprise-фреймворков и избыточен для baseline scaffold. Пользователь вправе добавить подпапки внутри любого раздела самостоятельно — scaffold этому не препятствует. Flat-структура снижает порог входа и соответствует принципу минимализма (LeSS), который разделяют большинство команд, внедряющих playbook.

## Структурные требования

### content-scaffold/

```
content-scaffold/
├── _index.md
├── 10-principles/
│   └── _index.md
├── 20-practices/
│   └── _index.md
├── 30-playbooks/
│   └── _index.md
├── 40-templates/
│   └── _index.md
└── 50-cases/
    └── _index.md
```

Нумерованные папки (10-, 20-, ...) используются, так как порядок прохождения методологии значим: принципы → практики → playbooks — логическая прогрессия. Каждый раздел содержит только `_index.md` (без статей-примеров — пользователь наполняет сам).

**Опциональные блоки** (создаются пользователем при необходимости, не входят в baseline):

- `00-overview/` — введение и onboarding в методологию, scope, история версий
- `60-roles/` — если методология включает ролевую модель (по аналогии с Atlassian Team Playbook)
- `70-glossary/` — термины фреймворка (может быть единственным файлом `glossary.md`)

Подпапки внутри разделов (например, `20-practices/engineering/`, `20-practices/design/`) допустимы и не требуют изменения scaffold — пользователь добавляет их сам.

### subagents

| Роль | Status | Обоснование |
|------|--------|-------------|
| pm | core | always-on, координация работы над методологией |
| tech-writer | core | primary writer; prescriptive style критичен для методологических текстов |
| researcher | optional | сбор prior-art, бенчмарков, аналогичных фреймворков |
| ba | disabled | методология не имеет бизнес-требований в delivery-смысле; BA-роль не релевантна |
| sa | disabled | нет архитектурных решений; методология не описывает технические системы |
| dev | disabled | нет реализации кода |
| devops | disabled | нет операционной инфраструктуры |
| qa | disabled | нет тестируемой системы |
| devsecops | disabled | нет security-аспектов |
| compliance | optional | если методология создаётся для compliance-регулируемой области (например, ISO) |

### agent_overrides

Один override: `tech-writer.md` — prescriptive methodology writing (см. AC ниже).

Кандидат для Wave 4+: `researcher.md` — override на domain-specific prior-art search (методологические фреймворки), но не входит в baseline требования.

### .doc-root.yaml properties

| Property | Required | Values | Обоснование |
|----------|----------|--------|-------------|
| Тип контента | yes | Принцип, Практика, Playbook, Шаблон, Case Study | Покрывает всю иерархию методологических артефактов; соответствует scaffold-разделам 10-50 |
| Уровень | no | Strategic, Tactical, Operational | Различает принципы (Strategic), практики (Tactical/Operational), playbooks (Operational); marked [emerging] — не навязывать как required |
| Область применения | no | Engineering, Design, Operations, All | Свободный enum; команда может расширить при необходимости; [emerging] |
| Статус | yes | Draft, Review, Approved, Archived | Совпадает с kb-team; lifecycle методологического контента аналогичен |

## Override AC: tech-writer для methodology

Переопределяемое поведение: base tech-writer промт описательный («как есть»); методологический текст требует нормативного голоса.

**AC-tw-meth-1:** Resolved tech-writer prompt содержит секцию «## Роль» с явным указанием «Methodology writer — prescriptive voice». Секция описывает, что writer создаёт нормативный контент для аудитории, которая будет применять методологию.

**AC-tw-meth-2:** Resolved prompt содержит секцию «## Стиль» с правилами:
- Нормативные формулировки обязательны: «команда должна», «практика требует», «запрещено» вместо «команды обычно делают», «рекомендуется».
- Каждая практика включает явное обоснование («почему это правило существует»).
- Примеры (Cases) маркируются как иллюстративные, не нормативные.

**AC-tw-meth-3:** Resolved prompt содержит секцию «## Структура артефакта» с минимальным шаблоном для каждого Типа контента: Принцип (формулировка + обоснование + анти-паттерн), Практика (цель + шаги + роли + адаптации), Playbook (контекст-триггер + набор практик + ожидаемый результат).

**AC-tw-meth-4:** Секции `## Constraints` и `## Tools` наследуются из base без изменений.

**AC-tw-meth-5:** Проверка: при создании статьи с Типом контента «Принцип» resolved prompt не содержит описательных формулировок прошедшего времени («исторически команды...»), только нормативные настоящего/инфинитива.

## Operations

```yaml
operations:
  - op: add
    source: content-scaffold/
    target: content/
    reason: "methodology scaffold (10-principles, 20-practices, 30-playbooks, 40-templates, 50-cases)"
  - op: replace
    source: doc-root.yaml
    target: content/.doc-root.yaml
    reason: "methodology properties (Тип контента, Уровень, Область применения, Статус)"
  - op: delete
    target: content/30-requirements/
    reason: "delivery-артефакты не нужны в methodology профиле"
  - op: delete
    target: content/40-architecture/
    reason: "технические артефакты вне скоупа методологического профиля"
  - op: delete
    target: content/60-implementation/
    reason: "имплементационные артефакты вне скоупа"
  - op: delete
    target: content/70-operations/
    reason: "операционные артефакты вне скоупа"
```

Примечание для SA: op:delete применяется только к папкам базового `project` профиля, если методология инициализируется поверх него. Если init создаёт чистый каталог — op:delete не нужны. SA уточняет логику в spec §4.

## Out of scope

Профиль `methodology` НЕ покрывает:

- Delivery-артефакты: требования, архитектуру, ADR, implementation notes
- Customer-facing документацию (это `kb-product`)
- Операционные runbooks конкретной команды (это `kb-team`)
- Управление версиями методологии как software releases (semver, changelog) — методология версионируется через git, не через property «Версия»
- Трекинг задач и спринтов (это `project` профиль)
- Автоматическую валидацию соответствия практик (это инструменты compliance)

## Открытые вопросы для SA

1. **op:delete semantics.** Нужен ли op:delete в manifest или логика «не добавлять» реализуется через минимальный scaffold (только `content-scaffold/` методологии)? SA уточняет в спеке §4 и при необходимости вводит условный op:delete (применяется только если target существует).

2. **Уровень как required.** Property «Уровень» помечен [emerging]. SA решает: требовать ли его в `.doc-root.yaml` как required или оставить optional с пустым default? Если optional — как Gramax обрабатывает пустые enum-values в фильтрах?

3. **Область применения: enum vs free-text.** Research показывает оба варианта. SA оценивает, поддерживает ли `.doc-root.yaml` schema extensible enum (пользователь добавляет значения) или фиксированный список.

4. **researcher override.** Scope Wave 4 или Wave 5? SA определяет, входит ли researcher agent override в baseline spec или выносится в отдельный milestone.

## Бриф для SA

**Требование:** `docs/requirements/profile-methodology.md` **Фаза:** W4c-A

**Спроектировать:**
- content-scaffold структуру (5 папок + опциональные блоки) с `_index.md` в каждой
- doc-root.yaml с 4 properties (Тип контента required, Статус required, Уровень и Область применения optional)
- agent_overrides/tech-writer.md — prescriptive writing промт (5 AC выше)
- manifest.yaml обновление: status stub → stable, operations list, полный subagents map

**Бизнес-правила для валидаций:**
- Каждый `_index.md` в scaffold НЕ содержит блок `properties:` (правило Gramax)
- tech-writer override НЕ меняет секции `## Constraints` и `## Tools` из base
- op:delete применяется только к delivery-папкам; методология не трогает `00-project/` и `10-domain/`

**Acceptance criteria для проверки архитектуры:**
- После `bash scripts/apply-overlay.sh --profile methodology` каталог содержит ровно 5 пронумерованных папок
- `python3 scripts/validate-profile.py` проходит без ошибок (status=stable, все required поля manifest заполнены)
- Resolved tech-writer промт (через override механику) содержит слово «prescriptive» или «должен» в секции стиля
- Статья с Типом контента «Принцип» создаётся без ошибок валидации doc-root
