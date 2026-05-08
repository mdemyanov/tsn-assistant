---
properties:
  - name: Тип контента
    value: [Архитектура]
  - name: Статус
    value: [Approved]
---

# Spec: профиль methodology (stable)

## Manifest

`docs/overlays/profiles/methodology/manifest.yaml`:

```yaml
schema_version: 1
name: methodology
description: Методология / playbook / framework для команд, создающих нормативные системы
audience: Engineering leads, agile coaches, центры компетенций
status: stable

subagents:
  pm: core
  tech-writer: core
  researcher: optional
  compliance: optional
  ba: disabled
  sa: disabled
  dev: disabled
  devops: disabled
  qa: disabled
  devsecops: disabled

pipelines: {}

content_scaffold: content-scaffold/
doc_root: doc-root.yaml

operations:
  - op: add
    source: content-scaffold/
    target: content/
    reason: "methodology scaffold (10-principles, 20-practices, 30-playbooks, 40-templates, 50-cases)"
  - op: replace
    source: doc-root.yaml
    target: content/.doc-root.yaml
    reason: "methodology properties (Тип контента, Уровень, Область применения, Статус)"

agent_overrides:
  tech-writer:
    source: agent-overrides/tech-writer.md

init_prompts: []

compatible_stacks: []
maintainer: project_template
```

## content-scaffold/

Flat hierarchy (раздел > статья). Нумерация 10-50 используется, так как порядок прохождения методологии логически значим: принципы → практики → playbooks — прогрессия от нормативной основы к конкретным инструментам.

```
docs/overlays/profiles/methodology/content-scaffold/
├── _index.md                    # корневой index с навигацией и дашбордом
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

Все `_index.md` — без блока `properties:` (правило Gramax: properties живут на статьях, не на разделах).

Содержимое `content-scaffold/_index.md`:

```markdown
---
order: 0
title: {{PROJECT_NAME}} — Методология
---

{{PROJECT_DESCRIPTION}}

## Навигация

- [Принципы](10-principles/)
- [Практики](20-practices/)
- [Playbooks](30-playbooks/)
- [Шаблоны](40-templates/)
- [Кейсы](50-cases/)

## Дашборд

<view defs="Тип контента=Принцип&Практика&Playbook&Шаблон&Case Study" groupby="Статус" display="List"/>
```

Содержимое каждого `<раздел>/_index.md` — заголовок без properties:

```markdown
# <Название раздела>
```

**Опциональные блоки** (создаются пользователем при необходимости, не входят в baseline):

- `00-overview/` — введение и онбординг в методологию, scope, история версий
- `60-roles/` — если методология включает ролевую модель (по аналогии с Atlassian Team Playbook)
- `70-glossary/` — термины фреймворка (может быть единственным файлом `glossary.md`)

Подпапки внутри разделов (например, `20-practices/engineering/`, `20-practices/design/`) допустимы без изменения scaffold — пользователь добавляет самостоятельно.

## doc-root.yaml

```yaml
title: "{{PROJECT_NAME}} — Методология"
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
      - Принцип
      - Практика
      - Playbook
      - Шаблон
      - Case Study
    required: true

  - name: Статус
    type: Enum
    style: green
    icon: check
    values: [Draft, Review, Approved, Archived]
    required: true

  - name: Уровень
    type: Enum
    style: purple
    icon: layers
    values: [Strategic, Tactical, Operational]
    required: false

  - name: Область применения
    type: Enum
    style: yellow
    icon: tag
    values: [Engineering, Design, Operations, All]
    required: false

filterProperties: [Тип контента, Статус, Уровень, Область применения]
```

**Обоснование `required: false` для Уровень и Область применения:**

Gramax обрабатывает optional enum-поля (required: false) следующим образом: статья без этого значения проходит валидацию doc-root без ошибок; в фильтрах такие статьи попадают в категорию «без значения» / «—». Это приемлемо для [emerging]-свойств — они появляются в doc-root, но не блокируют создание статей командами, которые не готовы их заполнять. Форсировать `required: true` нецелесообразно до накопления реального опыта применения (подтверждено паттерном kb-team: Owner — required: false, несмотря на практическую важность).

## Agent overrides

### tech-writer для methodology

`docs/overlays/profiles/methodology/agent-overrides/tech-writer.md`:

```markdown
---
extends: tech-writer
description: Технический писатель — методология / playbook / framework
---

## Роль

Methodology writer. Пишешь **нормативный контент** для аудитории, которая будет применять методологию в своей работе.

Ключевая разница с descriptive docs:
- Контент prescriptive: «команда должна», «практика требует», «запрещено»
- Не descriptive: «команды обычно делают», «как правило», «исторически»
- Каждое правило сопровождается явным обоснованием («почему это правило существует»)
- Примеры (Case Study) явно маркируются как иллюстративные, не нормативные

## Стиль

**Нормативные формулировки обязательны:**

- Используй: «команда должна», «практика требует», «необходимо», «запрещено», «обязательно»
- Не используй: «команды обычно», «рекомендуется», «как правило», «принято», «исторически»

**Обоснование каждого правила:**

Каждая практика / принцип содержит секцию «Почему» или «Обоснование» — краткое объяснение, зачем правило существует. Без обоснования нормативный текст воспринимается как произвол.

**Маркировка иллюстративного контента:**

Статьи типа Case Study и примеры внутри практик явно помечаются: «Этот пример иллюстрирует применение практики, не является нормативным требованием».

**Анти-паттерны прошедшего времени:**

Не используй описательные формулировки прошедшего времени («исторически команды решали X через Y»). Если нужна историческая справка — выноси в отдельный блок «Контекст» и отграничивай от нормативной части.

## Структура артефакта

### Принцип (Тип контента: Принцип)

```
# <Название принципа>

## Формулировка
<Одно-два предложения в нормативном залоге: «Команды должны...»>

## Обоснование
<Почему этот принцип существует: проблема, которую он решает>

## Анти-паттерн
<Что происходит при нарушении принципа>

## Связанные практики
<Ссылки на практики, реализующие этот принцип>
```

### Практика (Тип контента: Практика)

```
# <Название практики>

## Цель
<Что практика обеспечивает>

## Шаги
1. <Шаг 1>
2. <Шаг 2>
...

## Роли
| Роль | Ответственность |
|------|-----------------|

## Адаптации
<Как практика адаптируется в зависимости от контекста (размер команды, тип проекта)>

## Связанные принципы
<Ссылки на принципы, которые данная практика реализует>
```

### Playbook (Тип контента: Playbook)

```
# <Название playbook>

## Контекст-триггер
<Ситуация, в которой применяется этот playbook: «Применяй когда...»>

## Набор практик
1. [<Практика 1>](<ссылка>) — <зачем в этом контексте>
2. [<Практика 2>](<ссылка>) — <зачем в этом контексте>

## Ожидаемый результат
<Что команда получит при выполнении playbook>

## Ограничения
<Когда playbook не применим>
```
```

**AC-tw-meth-1:** Resolved tech-writer prompt содержит секцию «## Роль» с явным указанием «Methodology writer» и «prescriptive» / «нормативный контент».

**AC-tw-meth-2:** Resolved prompt содержит секцию «## Стиль» с явными правилами нормативных формулировок (список «используй» / «не используй»).

**AC-tw-meth-3:** Resolved prompt содержит секцию «## Структура артефакта» с шаблонами для Принципа, Практики, Playbook.

**AC-tw-meth-4:** Секции `## Constraints` и `## Tools` наследуются из base без изменений — override не переопределяет их.

**AC-tw-meth-5:** Resolved prompt не содержит описательных формулировок прошедшего времени как нормативных («исторически команды...»). Присутствует явный запрет в секции «## Стиль».

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
```

**Почему op:delete не нужен:** После Wave 4b baseline minimization `content/` при fresh init содержит только `_index.md` и `.doc-root.yaml` — никаких delivery-папок (`30-requirements/`, `40-architecture/` и т.д.) нет. Op:delete был нужен в спеке kb-product (разработанной до W4b) для очистки папок, которые мог создать `project`-профиль поверх. С W4b baseline пуст — удалять нечего. Если в будущем потребуется поддержка миграции с `project`-профиля на `methodology` — условный op:delete можно добавить отдельным ADR.

## Verification

Checklist для DEV (DEV-W4c-A-31):

- [ ] `docs/overlays/profiles/methodology/manifest.yaml` — status: stable, все required поля заполнены
- [ ] `docs/overlays/profiles/methodology/content-scaffold/` — ровно 5 нумерованных папок (10-50) + корневой `_index.md`
- [ ] Каждая папка содержит `_index.md`; ни один `_index.md` не содержит блок `properties:`
- [ ] `docs/overlays/profiles/methodology/doc-root.yaml` — 4 properties: Тип контента (required), Статус (required), Уровень (optional), Область применения (optional)
- [ ] `docs/overlays/profiles/methodology/agent-overrides/tech-writer.md` — frontmatter `extends: tech-writer`; содержит `## Роль`, `## Стиль`, `## Структура артефакта`; НЕ содержит `## Constraints` и `## Tools` (наследуются из base)
- [ ] `bash scripts/apply-overlay.sh --profile methodology --dry-run` — exit 0, план содержит только `op:add` и `op:replace`
- [ ] `bash scripts/apply-overlay.sh --profile methodology "TestMeth" "TM" "desc" "test@x.com"` — exit 0
- [ ] После apply: `content/` содержит ровно 5 нумерованных папок, каждая с `_index.md`
- [ ] `python3 scripts/validate-profile.py` — зелёный, status=stable, все required поля manifest заполнены
- [ ] Resolved tech-writer агент содержит слово «prescriptive» или «должна» в секции стиля
- [ ] Статья с `Тип контента: Принцип` создаётся без ошибок валидации doc-root
- [ ] `[ ! -d content/30-requirements ]` && `[ ! -d content/40-architecture ]` — delivery-папок нет (baseline clean)

## Решения по BRQ open questions

### 1. Семантика op:delete

**Решение: op:delete не используется в профиле methodology.**

После W4b baseline minimization `content/` при fresh init содержит только `_index.md` + `.doc-root.yaml`. Delivery-папки отсутствуют — удалять нечего. Op:delete в manifest methodology был бы мёртвым кодом. Если потребуется поддержка «поверх project-профиля» — отдельный ADR и conditional op:delete с guard `if: exists(target)`.

### 2. Required vs optional enum для Уровень

**Решение: required: false (optional).**

Обоснование: Gramax обрабатывает optional enum без ошибок валидации при пустом значении; статьи без Уровень попадают в фильтр как «—». Уровень помечен [emerging] в BRQ — нет достаточного опыта применения, чтобы требовать его. Форсирование required создаёт friction без пользы. Рекомендация: повысить до required после 3+ реальных deployments профиля, если поле заполняется стабильно.

### 3. Область применения: extensible vs фиксированный enum

**Решение: фиксированный enum с предустановленными значениями [Engineering, Design, Operations, All].**

Обоснование: `.doc-root.yaml` в текущей реализации не поддерживает extensible enum (пользователь не может добавлять значения через UI без редактирования файла). Оба варианта требуют редактирования файла — значит, фиксированный enum предпочтительнее: он даёт предсказуемые фильтры и консистентную навигацию. Пользователь может добавить значения в `doc-root.yaml` вручную, это low-friction операция. Вариант «free-text» отклонён: потеря возможности фильтрации и несовместимость с `filterProperties`.

### 4. researcher override

**Решение: не входит в baseline W4c-A, откладывается на Wave 5.**

Обоснование: BRQ явно помечает researcher override как кандидат Wave 4+, не как baseline. Ценность override — prior-art search по методологическим фреймворкам — реальна, но не критична для stable-статуса профиля. tech-writer override закрывает 90% дифференцирующей ценности methodology vs kb-team. Добавление researcher override — отдельный milestone с собственным BRQ.

## Контракт с QA-author

**AC (полный список из BRQ):**

- AC-scaff-1: После `bash scripts/apply-overlay.sh --profile methodology` каталог содержит ровно 5 пронумерованных папок (10-principles, 20-practices, 30-playbooks, 40-templates, 50-cases)
- AC-scaff-2: Каждая из 5 папок содержит `_index.md`; ни один `_index.md` не содержит блок `properties:`
- AC-manifest-1: `python3 scripts/validate-profile.py` проходит без ошибок (status=stable, все required поля manifest заполнены)
- AC-tw-meth-1: Resolved tech-writer prompt содержит секцию `## Роль` с явным указанием «Methodology writer — prescriptive voice»
- AC-tw-meth-2: Resolved prompt содержит секцию `## Стиль` с нормативными формулировками (список «должна», «требует», «запрещено»)
- AC-tw-meth-3: Resolved prompt содержит секцию `## Структура артефакта` с шаблонами для Принципа, Практики, Playbook
- AC-tw-meth-4: Секции `## Constraints` и `## Tools` присутствуют в resolved prompt (наследуются из base)
- AC-tw-meth-5: Resolved prompt не содержит описательных формулировок прошедшего времени как нормативных
- AC-docroot-1: Статья с Типом контента «Принцип» создаётся без ошибок валидации doc-root
- AC-ops-1: `--dry-run` план содержит только `op:add` и `op:replace`, нет `op:delete`

**Архитектурный контекст для тестов:**

- Компоненты: `apply-overlay.sh` → `_apply_profile.py` (mutations engine), manifest.yaml parser, agent-override merge
- Интеграции: `validate-profile.py` (static validation), агент-override механика (extends + секции)
- Trust boundaries: manifest.yaml → Python mutations engine → filesystem

**Edge cases / boundary conditions:**

- `op:add` при уже существующем `content/10-principles/` — idempotency: не перезаписывать существующие файлы (или перезаписывать с предупреждением)
- `op:replace` doc-root при уже существующем `.doc-root.yaml` с пользовательскими изменениями — данные пользователя теряются; нужен explicit warning или backup
- tech-writer override merge при отсутствии base agent file — корректная ошибка, не silent fail
- Пустые optional enum (Уровень не заполнен) — Gramax не показывает ошибку, статья доступна в фильтре без значения

**Test-pyramid рекомендация:**

| AC group | Уровень | Обоснование |
|----------|---------|-------------|
| AC-scaff-1, AC-scaff-2 (filesystem) | integration | реальный filesystem, apply-overlay выполняется |
| AC-manifest-1 (validate-profile) | integration | реальный Python script, реальный manifest |
| AC-tw-meth-1..5 (override content) | integration | реальный resolved агент-файл после apply |
| AC-docroot-1 (doc-root валидация) | integration | реальный `.doc-root.yaml` + Gramax validation |
| AC-ops-1 (dry-run plan) | unit | парсинг JSON-плана без filesystem mutations |

## Бриф для DEV

**Архитектура:** `docs/architecture/spec-methodology-profile.md`
**Требование:** `docs/requirements/profile-methodology.md`
**Фаза:** W4c-A, задача DEV-W4c-A-31

**Реализовать:**

1. `docs/overlays/profiles/methodology/manifest.yaml` — по Manifest-секции выше; status: stable
2. `docs/overlays/profiles/methodology/content-scaffold/` — дерево из 6 файлов (_index.md корневой + 5 разделов)
3. `docs/overlays/profiles/methodology/doc-root.yaml` — 4 properties по doc-root секции выше
4. `docs/overlays/profiles/methodology/agent-overrides/tech-writer.md` — полный файл из Agent overrides секции выше

**Порядок:** manifest → content-scaffold → doc-root → agent-override → integration tests.

**НЕ создавать:** `examples/methodology-example/` (не в scope W4c-A).

**Acceptance criteria:** все пункты из Verification checklist выше.
