---
properties:
  - name: Тип контента
    value: [Архитектура]
  - name: Статус
    value: [Approved]
---

# Spec: профиль custom (stable, anti-opinion)

**Требование:** `docs/requirements/profile-custom.md`
**Research:** `docs/research/2026-05-07-w4c-stub-profiles-shapes.md` (профиль 4)
**Фаза:** W4c-A

## Manifest

`docs/overlays/profiles/custom/manifest.yaml` — целевое состояние после промоции:

```yaml
schema_version: 1
name: custom
description: Open-ended catch-all — research-каталог, личный wiki, эксперимент, смешанный контент
status: stable

subagents:
  pm: core
  researcher: optional
  ba: optional
  sa: optional
  dev: optional
  devops: optional
  qa: optional
  tech-writer: optional
  devsecops: optional
  compliance: optional

pipelines: {}

content_scaffold: content-scaffold/
doc_root: doc-root.yaml

operations:
  - op: add
    source: content-scaffold/
    target: content/
    reason: "минимальный baseline: корень + templates/ + inbox/"
  - op: replace
    source: doc-root.yaml
    target: content/.doc-root.yaml
    reason: "custom properties: Тип контента (enum) + Статус"

agent_overrides: {}

init_prompts: []

compatible_stacks: ["*"]
maintainer: project_template
```

Ключевые точки:
- `status: stable` — промоция из stub
- Все 9 subagent'ов (кроме pm) = `optional`. Никаких `disabled` — custom не знает что понадобится
- `agent_overrides: {}` — пустой блок, явно зафиксирован (см. раздел Agent overrides)
- `operations` содержат только `op:add` и `op:replace`. `op:delete` не нужен: после W4b baseline minimization в `content/` только `_index.md` + `.doc-root.yaml`; нечего удалять

## content-scaffold/

### Дерево

```
docs/overlays/profiles/custom/content-scaffold/
├── _index.md                        # корень каталога (Gramax-обязательный, без properties)
├── templates/
│   ├── _index.md                    # index раздела templates, без properties
│   ├── article-example.md           # пример обычной статьи/заметки
│   ├── decision-example.md          # пример решения (ADR-лайт)
│   └── reference-example.md         # пример справочной статьи (термин/сущность)
└── inbox/
    └── _index.md                    # staging area, без properties
```

Числовые префиксы (`10-`, `20-`) отсутствуют везде — принцип anti-opinion, anti-pattern для custom (BRQ, APC-001).

### Содержимое файлов scaffold

#### `_index.md` (корень)

```markdown
# Мой каталог

Добро пожаловать. Этот каталог создан на профиле **custom** — без заданной структуры.

Начни с `templates/` — там примеры разных типов статей.
Используй `inbox/` для необработанных материалов.
Создавай любые папки и статьи по своему усмотрению.
```

_Без блока `properties:` — правило Gramax для `_index.md`._

#### `templates/_index.md`

```markdown
# Шаблоны

Примеры статей трёх типов. Скопируй нужный в свой раздел и заполни.
```

#### `inbox/_index.md`

```markdown
# Inbox

Место для необработанных материалов. Перемести статью в нужный раздел, когда разберёшься с ней.
```

### Содержимое templates/*.md

#### `templates/article-example.md`

Пример обычной статьи/заметки без жёсткой структуры. Содержит:
- frontmatter с `Тип контента: Заметка` и `Статус: Draft`
- Заголовок + краткое описание (1-2 предложения)
- Секции: **Контекст** (зачем это записано), **Содержание** (основная информация), **Ссылки** (опционально)
- Комментарий-подсказка: _«Удали секции, которые не нужны. Добавляй свои.»_

```markdown
---
properties:
  - name: Тип контента
    value: [Заметка]
  - name: Статус
    value: [Draft]
---

# Название статьи

Краткое описание — одна-две фразы о чём это.

## Контекст

Зачем ты это записал. Какая задача или вопрос стоял.

## Содержание

Основная информация.

## Ссылки

- [Источник 1](url)
```

#### `templates/decision-example.md`

Пример решения в формате ADR-лайт (легче полного ADR, достаточно для личного wiki и небольших команд). Содержит:
- frontmatter с `Тип контента: Решение` и `Статус: Draft`
- Секции: **Контекст** (какая ситуация), **Решение** (что выбрали), **Последствия** (что это меняет)
- Комментарий-подсказка: _«Для технических решений команды добавь секцию "Рассмотренные альтернативы".»_

```markdown
---
properties:
  - name: Тип контента
    value: [Решение]
  - name: Статус
    value: [Draft]
---

# Решение: [название]

**Дата:** YYYY-MM-DD

## Контекст

Какая ситуация потребовала решения.

## Решение

Что выбрали и почему.

## Последствия

Что это изменит. Какие компромиссы приняли.
```

#### `templates/reference-example.md`

Пример справочной статьи для описания термина, сущности или инструмента. Содержит:
- frontmatter с `Тип контента: Справка` и `Статус: Draft`
- Секции: **Определение** (одна строка), **Детали** (расширенное описание), **Примеры использования** (опционально), **Связанные понятия** (опционально)
- Комментарий-подсказка: _«Используй для глоссария, описания API, инструментов.»_

```markdown
---
properties:
  - name: Тип контента
    value: [Справка]
  - name: Статус
    value: [Draft]
---

# Термин / Название

**Определение:** одна строка.

## Детали

Расширенное описание, нюансы, особенности.

## Примеры использования

Когда и как применяется.

## Связанные понятия

- [[другой термин]]
```

### Обоснование inbox/

`inbox/` включается по рекомендации BRQ и подтверждается тремя независимыми Obsidian-шаблонами (voidashi, Magic-wei, Karpathy pattern). Семантика нейтральная — staging area без навязанного процесса обработки. Пользователь может переименовать или удалить. Включение в scaffold предпочтительнее его отсутствия: пустой `inbox/` с `_index.md` виден в навигации и сигнализирует о паттерне, при этом ни к чему не обязывает.

## doc-root.yaml

```yaml
title: "{{PROJECT_NAME}}"
properties:
  - name: Тип контента
    type: enum
    values: [Заметка, Решение, Справка]
    required: true
  - name: Статус
    type: enum
    values: [Draft, Review, Approved, Archived]
    required: true
```

**Решение по Тип контента: enum, не free string.**

Обоснование: enum из трёх значений (Заметка / Решение / Справка) покрывает большинство сценариев без навязывания структуры. Free string не даёт пользователю опоры при первом открытии — он вынужден придумывать значение. Три значения enum соответствуют трём template-файлам (article, decision, reference), что создаёт явный паттерн «тип → шаблон». Если пользователю нужны дополнительные типы — он добавит их в `.doc-root.yaml` после init. Это не нарушает anti-opinion принцип: enum является guidance, а не constraint на структуру папок.

Поля явно исключены: `Версия продукта` (kb-product), `Аудитория` (kb-product), `Уровень сложности` (course), `Область применения` (methodology), `Фаза` (project). BRQ APC-005.

`iconUrl` не задаётся — custom не имеет предметной области, иконка выбирается пользователем.

## Agent overrides

**НЕТ overrides. `agent_overrides: {}` (пустой блок).**

Обоснование: custom — anti-opinion профиль без предметного контекста. Любой agent override навязывает стиль или workflow. Для custom нет основания для предпочтительного стиля: пользователь может вести технический журнал, личный wiki, исследовательский каталог или методологию — каждый случай требовал бы разного override. Предоставить один override значит ошибиться для большинства сценариев. Если пользователю нужен специализированный агент — он выбирает другой профиль или настраивает агента вручную после init.

Директория `docs/overlays/profiles/custom/agent-overrides/` существует, но остаётся пустой. DEV не создаёт в ней файлы.

## Operations

При `init --profile custom` выполняются две операции:

| Op | Source | Target | Reason |
|----|--------|--------|--------|
| `op:add` | `content-scaffold/` | `content/` | Добавить корневой `_index.md`, `templates/`, `inbox/` |
| `op:replace` | `doc-root.yaml` | `content/.doc-root.yaml` | Заменить `.doc-root.yaml` на минимальный вариант |

`op:delete` отсутствует: baseline после W4b содержит только `content/_index.md` + `content/.doc-root.yaml`. Нечего удалять. Если пользователь мигрирует с другого профиля (project, kb-team) — операции удаления delivery-структуры — ответственность migration tooling (W4c-E), не custom manifest'а.

## Verification

Checklist для DEV после `init --profile custom`:

- [ ] `content/` не содержит папок с числовыми префиксами (`10-*`, `20-*`, `30-*`, ... )
- [ ] `content/templates/` существует и содержит ровно 3 файла: `article-example.md`, `decision-example.md`, `reference-example.md`
- [ ] `content/templates/_index.md` существует (Gramax-видимость раздела)
- [ ] `content/inbox/_index.md` существует
- [ ] `content/_index.md` существует (корень)
- [ ] `docs/overlays/profiles/custom/agent-overrides/` пуст (нет файлов `*.md`)
- [ ] `manifest.yaml`: `status: stable`
- [ ] `manifest.yaml`: все subagents (кроме pm) = `optional`, ни один не `disabled`
- [ ] `manifest.yaml`: `agent_overrides: {}` (пустой блок, не отсутствующий ключ)
- [ ] `.doc-root.yaml` содержит ровно 2 поля: `Тип контента` и `Статус`
- [ ] `_index.md` файлы (корень, templates/, inbox/) не содержат блока `properties:`

## Anti-pattern checks (для тестов DEV-W4c-A-34)

| ID | Проверка | Команда / assert |
|----|----------|-----------------|
| APC-001 | В `content/` отсутствуют папки с числовыми префиксами | `find content/ -maxdepth 2 -type d -name '[0-9]*' \| wc -l` == 0 |
| APC-002 | В `content/` отсутствует `requirements/` или `30-requirements/` | `[ ! -d content/requirements ] && [ ! -d content/30-requirements ]` |
| APC-003 | В `content/` отсутствует `adr/` или `40-architecture/` | `[ ! -d content/adr ] && [ ! -d content/40-architecture ]` |
| APC-004 | В `docs/overlays/profiles/custom/agent-overrides/` нет файлов | `find docs/overlays/profiles/custom/agent-overrides/ -name '*.md' \| wc -l` == 0 |
| APC-005 | `.doc-root.yaml` не содержит запрещённых полей | `grep -E "Версия продукта\|Аудитория\|Уровень сложности\|Область применения\|Фаза" content/.doc-root.yaml` возвращает пусто |

Дополнительный check (не в BRQ, но логичен):

| ID | Проверка |
|----|----------|
| APC-006 | `manifest.yaml` не содержит `disabled` ни для одного subagent |

## Открытые вопросы для DEV

1. **`op:add` merge-стратегия.** Если пользователь уже создал `content/templates/` вручную до init — `op:add` перезапишет или пропустит существующие файлы? Нужно явное поведение в `_apply_profile.py` (skip-existing vs overwrite с предупреждением).

2. **`_index.md` корня при `op:add`.** Baseline уже содержит `content/_index.md`. `op:add content-scaffold/` включает `_index.md` в scaffold. Нужно определить: scaffold `_index.md` заменяет baseline или пропускается если существует.

3. **Тест APC-001 глубина поиска.** `maxdepth 2` покрывает `content/папка/` и `content/папка/подпапка/`. Для custom пользователь может создавать произвольную глубину — тест проверяет только то, что создано init'ом, а не пользовательские изменения после. Это намеренное ограничение или тест должен быть рекурсивным?

4. **`agent_overrides: {}` в manifest YAML.** Python YAML parser может загружать `{}` как `None` или пустой dict в зависимости от версии. DEV должен проверить что `validate-profile.py` корректно обрабатывает оба случая.

---

## Контракт с QA-author

**AC (полный список из BRQ):**

- APC-001: В `content/` отсутствуют папки с числовыми префиксами
- APC-002: В `content/` отсутствует `requirements/` или `30-requirements/`
- APC-003: В `content/` отсутствует `adr/` или `40-architecture/`
- APC-004: В `agent-overrides/` нет файлов
- APC-005: `.doc-root.yaml` не содержит domain-специфичных полей других профилей
- AC-scaffold: scaffold содержит ровно 3 template-файла + inbox + корневой `_index.md`
- AC-manifest: `manifest.yaml` status = stable, все subagents (кроме pm) = optional

**Архитектурный контекст для тестов:**

- Компоненты: `manifest.yaml`, `content-scaffold/`, `doc-root.yaml`, `agent-overrides/` (пустой)
- Интеграции: `scripts/init.sh` → `scripts/_apply_profile.py` → файловая система
- Trust boundary: init.sh принимает `--profile custom`, передаёт в _apply_profile.py, который применяет operations manifest'а

**Edge cases / boundary conditions:**

- `op:add` при уже существующем `content/templates/` (пользователь создал вручную)
- `agent_overrides: {}` vs отсутствующий ключ — YAML парсинг в validate-profile.py
- `_index.md` корня: baseline уже имеет файл, scaffold тоже содержит — конфликт при `op:add`
- `manifest.yaml` с `agent_overrides:` без значения (implicit null) — должно трактоваться как `{}`

**Test-pyramid рекомендация:**

| AC group | Уровень | Обоснование |
|----------|---------|-------------|
| APC-001..003 (scaffold структура) | integration | проверка реального файлового дерева после init |
| APC-004 (agent-overrides пуст) | integration | проверка файловой системы |
| APC-005 (doc-root поля) | integration | парсинг YAML и проверка ключей |
| AC-manifest (subagents = optional) | unit | парсинг manifest.yaml, без запуска init |
| AC-scaffold (3 templates + inbox) | integration | полный прогон init --profile custom |
