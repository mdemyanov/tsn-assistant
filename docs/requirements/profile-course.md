---
properties:
  - name: Тип контента
    value: [Требование]
  - name: Статус
    value: [Approved]
---

# Профиль course — функтребования

## Контекст

Профиль `course` предназначен для создания и ведения обучающих курсов в Gramax: структурированных учебных материалов с последовательным прохождением модулей, уроков и итоговых заданий.

**Целевая аудитория:** обучающийся (студент, сотрудник на онбординге, самостоятельный слушатель), а также автор курса в роли instructional designer.

**Границы профиля:**
- vs `methodology` — методология описывает принципы и практики команды, не предполагает последовательного прохождения и оценки знаний; course ориентирован на learning path с assessments.
- vs `kb-product` — customer-facing база знаний рассчитана на произвольную навигацию (пользователь ищет ответ на конкретный вопрос); course предполагает линейное/модульное прохождение с learning objectives.
- vs `project` — project содержит delivery-артефакты (требования, ADR, реализацию); course не содержит технической документации проекта.

## Структурные требования

### content-scaffold/

Порядок прохождения материала является ключевым дидактическим требованием курса (Coursera, Vanderbilt CDR, UCalgary). В отличие от `kb-product`, где пользователь navigates произвольно, обучающийся движется по заданной траектории. Поэтому scaffold использует **нумерованные папки** (prefix `NN-`), а не slug-имена: это гарантирует корректную сортировку в Gramax, позволяет вставить новый модуль без переименования существующих и явно кодирует порядок прохождения в структуре файловой системы.

```
content-scaffold/
├── _index.md                          # Главная страница курса: цели, аудитория, структура
├── 00-overview/
│   └── _index.md                      # Введение, prerequisites, как пройти курс
├── 10-module-01-<slug>/
│   ├── _index.md                      # Обзор модуля + learning outcomes
│   ├── lesson-01.md                   # Урок 1
│   ├── lesson-02.md                   # Урок 2
│   └── exercises/                     # Опционально: практические упражнения модуля
│       └── _index.md
├── 20-module-02-<slug>/
│   ├── _index.md
│   └── lesson-01.md
├── 90-assessments/
│   └── _index.md                      # Итоговые задания, тесты, проекты
└── 99-resources/
    └── _index.md                      # Дополнительные материалы, ссылки, глоссарий
```

**Примечание по нумерации:** шаг 10 между модулями оставляет место для вставки нового модуля (например, `15-module-03-<slug>/`) без сдвига существующих. Разделы `90-assessments/` и `99-resources/` фиксированы как терминальные — они всегда в конце независимо от числа модулей. Папка `exercises/` внутри модуля опциональна; если упражнений нет — не создаётся.

**Конвенция slug:** `<NN>-module-<NN>-<human-readable-slug>` — например, `10-module-01-introduction`, `20-module-02-data-structures`. Slug — латиница, kebab-case, описывает тему модуля.

### subagents

| Роль | Status | Обоснование |
|------|--------|-------------|
| pm | core | Координация; всегда-on |
| tech-writer | core | Основной автор учебных материалов; instructional tone — ключевая компетенция |
| ba | optional | В роли instructional designer: формирует learning objectives, выстраивает assessment design; уместен при разработке курса с нуля или при глубоком редизайне |
| researcher | optional | Сбор prior art (аналогичные курсы, бенчмарки, актуальность материала); особенно полезен на фазе планирования курса |
| sa | disabled | Архитектура не нужна для учебного каталога |
| dev | disabled | Реализация кода не входит в scope профиля |
| devops | disabled | Нет инфраструктурного компонента |
| qa | disabled | QA учебного контента — задача instructional review, а не тестирования ПО |
| devsecops | disabled | Не применимо |
| compliance | disabled | Не применимо по умолчанию; может быть включён если курс проходит регуляторную аттестацию |

**Обоснование BA как optional:** при разработке курса роль BA трансформируется в instructional designer — формулирует learning objectives в формате «после прохождения обучающийся сможет [глагол действия]», проектирует alignment между objectives и assessments. Это отличается от бизнес-анализа delivery-проекта, но инструментальная база (JTBD, acceptance criteria) остаётся применимой.

### agent_overrides

Один override: `tech-writer.md` — instructional tone для учебных материалов (см. AC ниже).

Расположение: `docs/overlays/profiles/course/agent-overrides/tech-writer.md`.

Переопределяет: стиль обращения (second-person "вы/ты"), обязательность learning objectives, структуру статьи-урока, outcome-driven formulation.

### .doc-root.yaml properties

| Property | Required | Values / Примечание |
|----------|----------|---------------------|
| Тип контента | yes | Overview, Lesson, Exercise, Assessment, Resource |
| Уровень сложности | yes | Beginner, Intermediate, Advanced |
| Длительность | no | Строка: "15 мин", "1 час 30 мин"; позволяет обучающемуся планировать время |
| Статус | yes | Draft, Review, Approved, Published |
| Prerequisites | no | Свободный текст или ссылка на статью/раздел; указывает что нужно знать/пройти перед этим материалом |

**Примечание:** `Тип контента` и `Статус` — обязательный минимум для всех профилей (cross-cutting finding из research). `Уровень сложности` выделен как required для course, т.к. влияет на фильтрацию и навигацию обучающегося. `Длительность` — no (optional), т.к. не всегда известна на этапе draft.

## Override AC: tech-writer для course

**AC-tw-1:** Resolved tech-writer prompt содержит секцию «## Роль» с явным «Instructional designer / Tech writer для обучающего курса».

**AC-tw-2:** Resolved prompt содержит требование начинать каждую статью-урок с блока «Learning objectives» — перечня конкретных результатов в форме «После прохождения вы сможете [глагол действия + измеримый результат]».

**AC-tw-3:** Resolved prompt содержит инструкцию использовать второе лицо (обращение к обучающемуся напрямую: "вы узнаете", "вы научитесь", "выполните следующие шаги") — instructional tone, отличный от описательного стиля kb-product.

**AC-tw-4:** Resolved prompt содержит секцию «## Structure» с требованием явных переходов между секциями урока: recap предыдущего → новый материал → practice → check your understanding.

**AC-tw-5:** Секции `## Constraints` и `## Tools` наследуются из base без изменений.

## Operations

После init курс не должен содержать delivery-структуру (00-project, 30-requirements, 40-architecture, 60-implementation, 70-operations).

Ожидаемые операции при применении overlay:

| Операция | Объект | Назначение |
|----------|--------|------------|
| op:add scaffold | `00-overview/`, `10-module-01-introduction/`, `90-assessments/`, `99-resources/` | Создать baseline структуру |
| op:replace doc-root | `.doc-root.yaml` | Применить course-специфичные properties |
| op:delete | Папки delivery-профиля если они присутствуют в baseline | Удалить нерелевантные разделы |

**Примечание для SA:** конкретный список op:delete зависит от baseline scaffold шаблона — SA уточняет при написании spec. Если init происходит в пустом каталоге, op:delete не нужен.

## Out of scope

- Внутренняя delivery-структура проекта (требования, архитектура, реализация)
- Customer support / troubleshooting документация (это `kb-product`)
- LMS-функциональность (трекинг прогресса, сертификаты, интеграция с платформами) — только структура контента
- Автоматическая генерация assessment вопросов

## Открытые вопросы для SA

1. **Глубина вложенности exercises/:** нужна ли папка `exercises/` как часть baseline scaffold каждого модуля, или создаётся только при необходимости? SA уточняет при spec.
2. **op:delete baseline:** какие именно папки из default baseline шаблона подлежат удалению при init с профилем course? Зависит от решения о "minimal baseline" в SA-spec.
3. **Статус Published:** нужен ли отдельный статус `Published` в `.doc-root.yaml` или достаточно `Approved` как в kb-team? Актуально если планируется автоматическая публикация через pipeline.
4. **Нумерация модулей в одном курсе vs мета-каталог курсов:** текущий scaffold рассчитан на один курс = один каталог. Если нужна коллекция курсов в одном Gramax-каталоге — потребуется отдельный уровень вложенности. SA фиксирует решение в ADR.

## Бриф для SA

**Требование:** `docs/requirements/profile-course.md` **Фаза:** W4c-A (stub → stable)

**Спроектировать:**
- content-scaffold с нумерованными папками (конвенция `NN-module-NN-<slug>`)
- `.doc-root.yaml` с 5 properties (Тип контента, Уровень сложности, Длительность, Статус, Prerequisites)
- `agent-overrides/tech-writer.md` — instructional tone override
- manifest.yaml обновление: status stub → stable, operations заполнены

**Бизнес-правила для валидаций:**
- Каждая подпапка scaffold содержит `_index.md`
- Корневой `_index.md` не содержит блок `properties:`
- Статьи содержат `properties:` в object-нотации
- Шаг нумерации модулей = 10 (резерв для вставки)

**Acceptance criteria для проверки архитектуры:**
- AC-tw-1 — AC-tw-5 из секции Override AC
- Scaffold создаётся через `bash scripts/init.sh --profile course` без ошибок
- `python3 scripts/validate-profile.py` возвращает зелёный статус для профиля course
- Delivery-папки (30-requirements, 40-architecture, 60-implementation) отсутствуют после init
