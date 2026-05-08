---
properties:
  - name: Тип контента
    value: [Архитектура]
  - name: Статус
    value: [Approved]
---

# Spec: профиль course (stable)

**BRQ:** `docs/requirements/profile-course.md`
**Research:** `docs/research/2026-05-07-w4c-stub-profiles-shapes.md` (профиль 3)
**Эталон:** `docs/architecture/spec-kb-product-profile.md`

---

## Manifest

`docs/overlays/profiles/course/manifest.yaml`:

```yaml
schema_version: 1
name: course
description: Обучающий курс — структурированный учебный материал с модулями, уроками и итоговыми заданиями
audience: Instructional designers, авторы курсов, обучающиеся
status: stable

subagents:
  pm: core
  tech-writer: core
  ba: optional
  researcher: optional
  sa: disabled
  dev: disabled
  devops: disabled
  qa: disabled
  devsecops: disabled
  compliance: disabled

pipelines: {}

content_scaffold: content-scaffold/
doc_root: doc-root.yaml

operations:
  - op: add
    source: content-scaffold/
    target: content/
    reason: "course scaffold (00-overview, 10-module-01-introduction, 20-module-02-example, 90-assessments, 99-resources)"
  - op: replace
    source: doc-root.yaml
    target: content/.doc-root.yaml
    reason: "course properties (Тип контента, Уровень сложности, Длительность, Статус, Prerequisites)"

agent_overrides:
  tech-writer:
    source: agent-overrides/tech-writer.md

init_prompts: []

compatible_stacks: []
maintainer: project_template
```

### Обоснование состава subagents

- **pm: core** — координация всегда нужна.
- **tech-writer: core** — основной автор учебного контента; instructional tone является ключевой компетенцией профиля.
- **ba: optional** — при разработке курса с нуля BA выступает как instructional designer: формулирует learning objectives в формате «после прохождения обучающийся сможет [глагол]», проектирует alignment objectives ↔ assessments. Инструментальная база (JTBD, AC) применима; роль нужна не всегда.
- **researcher: optional** — полезен на фазе планирования: сбор prior art, бенчмарки аналогичных курсов, актуальность материала. Не нужен при обновлении существующего курса.
- **sa/dev/devops/qa/devsecops: disabled** — учебный каталог не требует архитектуры, реализации кода, инфраструктуры или тестирования ПО. QA учебного контента = instructional review, не software QA.
- **compliance: disabled** — не применимо по умолчанию; включается вручную если курс проходит регуляторную аттестацию.

---

## content-scaffold/

### Дерево

```
docs/overlays/profiles/course/content-scaffold/
├── _index.md                                    # Главная страница курса: цели, аудитория, структура
├── 00-overview/
│   └── _index.md                                # Введение, prerequisites, как пройти курс
├── 10-module-01-introduction/
│   ├── _index.md                                # Обзор модуля + learning outcomes
│   └── lesson-01.md                             # Урок 1: пример структуры (objectives → материал → practice → check)
├── 20-module-02-example/
│   ├── _index.md                                # Обзор второго модуля
│   └── lesson-01.md                             # Урок 1 второго модуля
├── 90-assessments/
│   └── _index.md                                # Итоговые задания, тесты, проекты
└── 99-resources/
    └── _index.md                                # Дополнительные материалы, ссылки, глоссарий
```

### Конвенция нумерации

- Шаг 10 между модулями — оставляет место для вставки `15-module-03-<slug>/` без сдвига существующих.
- `90-assessments/` и `99-resources/` — терминальные разделы; всегда в конце независимо от числа модулей.
- Slug-часть: латиница, kebab-case, описывает тему (`10-module-01-introduction`, `20-module-02-data-structures`).

### Решение по exercises/

**`exercises/` НЕ входит в baseline scaffold.** Папка создаётся автором курса вручную при необходимости внутри нужного модуля. Обоснование:

1. Курс может быть чисто теоретическим (video/reading-only) — тогда `exercises/` в baseline засоряет структуру пустой папкой.
2. BRQ явно указывает: «папка `exercises/` внутри модуля опциональна; если упражнений нет — не создаётся».
3. Эталонный паттерн (MDN Learning Area, Vanderbilt CDR) не требует exercises в каждом модуле.

Когда упражнения нужны — автор добавляет `exercises/_index.md` внутри целевого модуля.

### Содержимое scaffold-файлов (шаблоны без properties-блока)

**`_index.md` (корень)** — без `properties:`, содержит `<view>` дашборд с навигацией по модулям.

**`00-overview/_index.md`** — без `properties:`, заголовок «Введение», placeholder-текст для целей курса, prerequisites, аудитории.

**`10-module-01-introduction/_index.md`** — без `properties:`, заголовок «Модуль 1: Введение», placeholder learning outcomes.

**`10-module-01-introduction/lesson-01.md`** — содержит `properties:` (Тип контента: Lesson; Уровень сложности: Beginner; Статус: Draft), демонстрирует структуру урока из четырёх секций.

**`20-module-02-example/`** — аналогично, для иллюстрации второго модуля.

**`90-assessments/_index.md`** — без `properties:`, placeholder для итоговых заданий.

**`99-resources/_index.md`** — без `properties:`, placeholder для доп. материалов.

---

## doc-root.yaml

`docs/overlays/profiles/course/doc-root.yaml`:

```yaml
title: "{{PROJECT_NAME}} — Курс"
description: "{{PROJECT_DESCRIPTION}}"
syntax: XML
language: ru
editors:
  - "{{EDITOR_EMAIL}}"

properties:
  - name: Тип контента
    type: Enum
    style: blue
    icon: file-text
    values:
      - Overview
      - Lesson
      - Exercise
      - Assessment
      - Resource
    required: true

  - name: Уровень сложности
    type: Enum
    style: purple
    icon: bar-chart
    values:
      - Beginner
      - Intermediate
      - Advanced
    required: true

  - name: Длительность
    type: String
    style: grey
    icon: clock
    placeholder: "15 мин"
    required: false

  - name: Статус
    type: Enum
    style: green
    icon: check
    values:
      - Draft
      - Review
      - Approved
      - Published
    required: true

  - name: Prerequisites
    type: String
    style: yellow
    icon: link
    placeholder: "Знание основ X; пройдите модуль 1"
    required: false

filterProperties: [Тип контента, Уровень сложности, Статус]
```

### Решение: Published vs Approved

Используем **оба**: `Approved` (редакционно готов) и `Published` (опубликован/доступен обучающимся). Обоснование:

- В `kb-team` и `kb-product` достаточно `Approved`, т.к. публикация = merge в `public`.
- Для курса важен дополнительный lifecycle: контент может быть `Approved` (готов к публикации), но ещё не `Published` (например, дата запуска в будущем или курс ещё идёт набор). `Published` отражает состояние видимости для обучающегося, а не только редакционного качества.
- Если автоматическая публикация через pipeline не планируется — статус `Published` используется как метка вручную.

---

## Agent overrides

### tech-writer для course

`docs/overlays/profiles/course/agent-overrides/tech-writer.md`:

```markdown
---
extends: tech-writer
description: Технический писатель / Instructional designer — обучающий курс
---

## Роль

Instructional designer / Tech writer для обучающего курса. Пишешь учебные материалы **для обучающегося** (студент, сотрудник на онбординге, самостоятельный слушатель), используя instructional tone.

Ключевые принципы:
- Обращайся к обучающемуся напрямую: «вы узнаете», «вы научитесь», «выполните следующие шаги».
- Каждый урок начинается с блока **Learning objectives** — что обучающийся сможет делать после прохождения.
- Структура урока всегда линейна: recap → новый материал → practice → check your understanding.
- Результат формулируется через действие, не через знание: «вы сможете настроить X» (не «вы узнаете о X»).

## Тон

Instructional tone: второе лицо (прямое обращение к обучающемуся), активный залог, короткие предложения. Отличие от `kb-product`: там «дружелюбно, но не фамильярно» для внешнего читателя; здесь — учительский голос, направляющий по шагам.

Запрещено:
- Пассивный залог в инструкциях («кнопка нажимается» → «нажмите кнопку»).
- Описательный стиль без action («В этом уроке рассматривается X» → «После этого урока вы сможете X»).
- Жаргон команды (sprints, tickets, PRs) — если курс не про разработку.

## Структура урока

Каждая статья типа Lesson следует структуре:

```
## Learning objectives
После прохождения этого урока вы сможете:
- [глагол действия + измеримый результат]
- [глагол действия + измеримый результат]

## [Recap / Что мы уже знаем]
(опционально, если есть предыдущий урок)

## [Новый материал]
(основное содержание; разбивай на подразделы)

## Practice
(задание / упражнение; «Попробуйте сами: ...»)

## Check your understanding
(вопросы для самопроверки или ссылка на exercise)
```

AC-tw-1: ✓ Секция «## Роль» содержит явное «Instructional designer / Tech writer для обучающего курса».
AC-tw-2: ✓ Prompt содержит требование начинать каждый урок с блока «Learning objectives» — конкретные результаты в форме «После прохождения вы сможете [глагол + измеримый результат]».
AC-tw-3: ✓ Prompt содержит инструкцию second-person instructional tone: «вы узнаете», «вы научитесь», «выполните».
AC-tw-4: ✓ Секция «## Структура урока» задаёт явные переходы: recap → новый материал → practice → check your understanding.
AC-tw-5: ✓ Секции Constraints и Tools наследуются из base (extends: tech-writer).
```

---

## Operations

Только `op:add` и `op:replace` — baseline после W4b minimization содержит только `_index.md` + `.doc-root.yaml`, delivery-папки (`00-project/`, `30-requirements/`, `40-architecture/`) отсутствуют.

| Операция | Source | Target | Назначение |
|----------|--------|--------|------------|
| `op:add` | `content-scaffold/` | `content/` | Создать baseline структуру курса |
| `op:replace` | `doc-root.yaml` | `content/.doc-root.yaml` | Применить course-специфичные properties |

**op:delete не нужен** — после W4b baseline minimization delivery-папки не являются частью дефолтного baseline. Если профиль применяется поверх `project`-каталога — это out of scope данного overlay; SA рекомендует в таком случае создавать новый каталог с нуля.

---

## Verification (checklist для DEV)

### Файловая структура

- [ ] `docs/overlays/profiles/course/manifest.yaml` — `status: stable`, все subagents явно объявлены
- [ ] `docs/overlays/profiles/course/content-scaffold/` — присутствует дерево из 7 `_index.md` + 2 `lesson-01.md`
- [ ] `docs/overlays/profiles/course/doc-root.yaml` — содержит все 5 properties (Тип контента, Уровень сложности, Длительность, Статус, Prerequisites)
- [ ] `docs/overlays/profiles/course/agent-overrides/tech-writer.md` — содержит `extends: tech-writer`, секции Роль / Тон / Структура урока

### _index.md правила Gramax

- [ ] Все `_index.md` в scaffold — без блока `properties:`
- [ ] Статьи-уроки (`lesson-01.md`) содержат `properties:` в object-нотации

### AC из BRQ

- [ ] AC-tw-1: `grep "Instructional designer" docs/overlays/profiles/course/agent-overrides/tech-writer.md`
- [ ] AC-tw-2: `grep "Learning objectives" docs/overlays/profiles/course/agent-overrides/tech-writer.md`
- [ ] AC-tw-3: `grep "second-person\|вы узнаете\|второе лицо" docs/overlays/profiles/course/agent-overrides/tech-writer.md`
- [ ] AC-tw-4: `grep "recap\|practice\|check your understanding" docs/overlays/profiles/course/agent-overrides/tech-writer.md`
- [ ] AC-tw-5: `grep "extends: tech-writer" docs/overlays/profiles/course/agent-overrides/tech-writer.md`

### Init / validate

- [ ] `bash scripts/init.sh --profile course "TestCourse" "TC" "desc" "test@x.com"` → exit 0
- [ ] После init: `[ -f content/00-overview/_index.md ]` → 0
- [ ] После init: `[ -f content/10-module-01-introduction/lesson-01.md ]` → 0
- [ ] После init: `[ -f content/90-assessments/_index.md ]` → 0
- [ ] После init: `[ -f content/99-resources/_index.md ]` → 0
- [ ] После init: `[ ! -d content/00-project ]` → delivery-папки отсутствуют
- [ ] `python3 scripts/validate-profile.py` → зелёный статус для профиля `course`

---

## Решения по BRQ open questions

### 1. exercises/ в baseline каждого модуля

**Решение: НЕТ — exercises/ не входит в baseline.**

`exercises/` создаётся автором курса вручную только при необходимости. Baseline scaffold содержит только `_index.md` и `lesson-01.md` внутри каждого модуля-примера. Пустые служебные папки в baseline создают шум и нарушают правило «каждая подпапка со смыслом». Паттерн MDN и Vanderbilt CDR подтверждает: exercises — дополнение к уроку, не обязательная структура каждого модуля.

### 2. Какие папки baseline удаляются через op:delete

**Решение: None (после W4b).**

После W4b baseline minimization (`content/` = только `_index.md` + `.doc-root.yaml`) delivery-папки уже не присутствуют в baseline. `op:delete` не нужен. Задача: только `op:add` scaffold + `op:replace` doc-root.

### 3. Статус Published отдельно или достаточно Approved

**Решение: обе метки присутствуют в enum (`Draft → Review → Approved → Published`).**

`Approved` = редакционно готов. `Published` = доступен обучающимся. Для курсов с плановой датой запуска или поэтапным раскрытием модулей различие принципиально. В `kb-team` и `kb-product` это не нужно, т.к. публикация совпадает с merge в `public`. Для course-профиля добавление `Published` не ломает совместимость (для всех stable-профилей Approved достаточен) и даёт авторам явный lifecycle.

### 4. Один каталог = один курс vs мета-уровень для коллекции

**Решение: один каталог = один курс.**

Граница ответственности профиля — содержимое одного курса. Если организации нужна коллекция курсов — это отдельный `kb-product`-подобный каталог-навигатор, который ссылается на отдельные course-каталоги. Мета-уровень внутри одного каталога усложняет scaffold, ломает нумерационную конвенцию и не соответствует паттерну Coursera/MDN (каждый курс = отдельная единица навигации). Фиксируется как convention, ADR не требуется (нет альтернатив с сопоставимым весом).

---

## Контракт с QA-author

**AC (полный список из требования):**
- AC-tw-1: Resolved tech-writer prompt содержит секцию «## Роль» с явным «Instructional designer / Tech writer для обучающего курса»
- AC-tw-2: Resolved prompt содержит требование начинать каждую статью-урок с блока «Learning objectives» в форме «После прохождения вы сможете [глагол действия + измеримый результат]»
- AC-tw-3: Resolved prompt содержит инструкцию второго лица: «вы узнаете», «вы научитесь», «выполните следующие шаги»
- AC-tw-4: Resolved prompt содержит секцию «## Structure» с явными переходами: recap → новый материал → practice → check your understanding
- AC-tw-5: Секции Constraints и Tools наследуются из base без изменений
- AC-scaffold: `bash scripts/init.sh --profile course ...` создаёт scaffold без ошибок, delivery-папки отсутствуют
- AC-validate: `python3 scripts/validate-profile.py` возвращает зелёный статус для профиля course

**Архитектурный контекст для тестов:**
- Компоненты: `manifest.yaml` (profile descriptor), `content-scaffold/` (file tree), `doc-root.yaml` (property schema), `agent-overrides/tech-writer.md` (prompt overlay)
- Интеграции: `scripts/init.sh` (scaffold deployment), `scripts/validate-profile.py` (manifest validation), `scripts/_apply_profile.py` (op:add / op:replace execution)
- Trust boundaries: init.sh → _apply_profile.py → op:add/op:replace → content/

**Edge cases / boundary conditions:**
- Модули с exercises/: scaffold не создаёт exercises/, но validate-profile.py не должен падать если автор добавил exercises/ вручную
- Повторный вызов init поверх существующего content/ — op:add не должен перезаписывать файлы с существующим контентом
- `_index.md` в корне content/ после `op:add` — не должен перезаписать существующий корневой `_index.md`
- lesson-01.md содержит `properties:` в object-нотации — validate-content.py должен принимать

**Test-pyramid рекомендация:**

| AC group | Уровень | Обоснование |
|----------|---------|-------------|
| AC-tw-1..5 (override content) | unit | grep-проверки на файловом содержимом; не требуют init |
| AC-scaffold (init + file tree) | integration | реальный вызов init.sh; проверка файловой системы |
| AC-validate (validate-profile.py) | integration | реальный Python-скрипт; читает manifest + doc-root |
| Idempotency (повторный init) | integration | состояние ФС до и после второго вызова |

---

## NFR Mapping

| NFR из BRQ | Как обеспечивается |
|------------|---------------------|
| Нумерованные папки с шагом 10 | scaffold использует `NN-module-NN-<slug>` конвенцию; шаг 10 обеспечивает резерв без переименования |
| `_index.md` в каждой подпапке | все scaffold-папки содержат `_index.md`; validate-profile.py проверяет |
| 5 properties в doc-root | doc-root.yaml содержит все 5: Тип контента, Уровень сложности, Длительность, Статус, Prerequisites |
| Instructional tone override | tech-writer.md с `extends: tech-writer` и AC-tw-1..5 покрыты явными секциями |
| Delivery-папки отсутствуют после init | baseline W4b minimization + только op:add/replace в operations; op:delete отсутствует (не нужен) |

---

## Открытые вопросы для DEV

1. **`_apply_profile.py` op:add idempotency:** должен ли op:add пропускать файл если он уже существует, или перезаписывать? Рекомендация: skip + warn (не ломать существующий контент). Уточнить поведение у PM.
2. **lesson-01.md в scaffold — placeholder или шаблон?** Включить frontmatter с `properties:` + placeholder-структуру четырёх секций (objectives / recap / material / practice / check) как scaffolded template, или только пустой файл с frontmatter? Рекомендация: включить структуру секций как комментарии или placeholder-заголовки — помогает автору сразу видеть ожидаемую форму.
3. **Корневой `_index.md` в scaffold:** включать `<view>` Gramax-блок с дашбордом (как в kb-product) или plain markdown? Если `<view>` — DEV должен проверить поддерживаемый синтаксис.
4. **validate-profile.py coverage:** нужно ли добавить проверку agent_overrides.tech-writer.source указывает на существующий файл? Сейчас validate-profile.py проверяет manifest schema — расширить на файловую систему.
