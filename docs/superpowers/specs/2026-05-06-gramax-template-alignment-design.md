# Spec: Gramax Template Alignment — `_index.md`, валидатор, шпаргалка

**Дата:** 2026-05-06
**Автор:** PM (main, Opus)
**Источник:** `/Users/mdemyanov/Devel/pg_vector_service/docs/gramax-skills-update.md` (открытия из приведения 89 файлов к корректному формату Gramax 2026-05-05/06).

## Проблема

Шаблон `project_template` создаёт каталог `content/`, который **не отображается корректно в Gramax с первого раза**:

1. В подпапках лежат `README.md` — Gramax считает индексом подпапки **только `_index.md`**. Без него папка невидима в дереве навигации.
2. `content/10-domain/glossary.md` использует **плоскую frontmatter-нотацию** (`Тип контента: Глоссарий`) — устаревший формат, рендерится непредсказуемо.
3. `.doc-root.yaml` содержит `required: true` на каждом property — поле не используется в production-эталоне (`naumen-ecosystem/business-requirements/`), добавляет шум.
4. Slash-команда `/init` Шаг 6.5 ссылается на легаси-каталог `sd-ai-assistant/` как на референс property-схемы — этот каталог сам по себе устарел.
5. Нет автоматической проверки структуры `content/`. `pm-review` декларирует «проверь properties», но не предоставляет инструмента.
6. CLAUDE.md не содержит шпаргалки по правилам Gramax — агенты (BA/SA/Dev/DevOps) забывают их между сессиями.

Каждый новый проект, созданный через `/init`, унаследует эти проблемы и потратит несколько часов на отладку рендера в Gramax.

## Цель

Привести шаблон к состоянию, когда **сразу после `/init` каталог `content/` рендерится в Gramax корректно** и есть автоматический guard от регрессий.

## Архитектура

```
project_template/
├── content/
│   ├── _index.md                  [NEW]
│   ├── .doc-root.yaml             [EDIT]
│   ├── 00-project/
│   │   ├── _index.md              [RENAME README.md]
│   │   └── adr/
│   │       ├── _index.md          [NEW]
│   │       └── .gitkeep           (keep)
│   ├── 10-domain/
│   │   ├── _index.md              [RENAME README.md]
│   │   └── glossary.md            [EDIT frontmatter]
│   ├── 30-requirements/
│   │   ├── _index.md              [RENAME README.md]
│   │   ├── functional/
│   │   │   ├── _index.md          [NEW]
│   │   │   └── .gitkeep           (keep)
│   │   └── non-functional/
│   │       ├── _index.md          [NEW]
│   │       └── .gitkeep           (keep)
│   ├── 40-architecture/_index.md  [RENAME README.md]
│   ├── 60-implementation/_index.md [RENAME README.md]
│   └── 70-operations/_index.md    [RENAME README.md]
├── scripts/
│   ├── validate-content.py        [NEW]
│   ├── init.sh                    [EDIT]
│   └── test-template.sh           [EDIT]
├── CLAUDE.md                      [EDIT]
├── README.md                      [EDIT]
├── docs/lessons-learned.md        [EDIT]
└── .claude/plugins/project/commands/
    ├── init.md                    [EDIT]
    └── pm-review.md               [EDIT]
```

`apply-overlay.sh` остаётся без изменений — overlay по-прежнему патчит `.doc-root.yaml` и `glossary.md`, и должен продолжить работать после изменений.

## Компоненты

### 1. `_index.md` файлы

#### 1.1. Корневой `content/_index.md`

Главная страница Gramax-каталога. Подставляется через `init.sh`.

```markdown
---
order: 0
title: {{PROJECT_NAME}} — База знаний
---

{{PROJECT_DESCRIPTION}}

## Навигация

- [Проект и ADR](00-project/)
- [Доменная модель](10-domain/)
- [Требования](30-requirements/)
- [Архитектура](40-architecture/)
- [Реализация](60-implementation/)
- [Эксплуатация](70-operations/)

## Дашборд

<view defs="Тип контента=Требование&Архитектура&ADR&Runbook&Исследование&Глоссарий&Прочее" groupby="Статус" display="List"/>
```

#### 1.2. `_index.md` подпапок-разделов (6 шт.)

Каждый — короткое описание + список вложенных подпапок (если есть) + правила раздела. Содержимое перенесено из текущих `README.md`, frontmatter — только `order` + `title`. **Без `properties:`.**

Пример `30-requirements/_index.md`:

```markdown
---
order: 30
title: Требования
---

Функциональные и нефункциональные требования с JTBD и Acceptance Criteria.

- [Функциональные](functional/)
- [Нефункциональные](non-functional/)

## Правила

- Создаёт BA через `/ba new-requirement <slug>`.
- Каждое требование содержит JTBD и Acceptance Criteria.
- Properties статей: `Тип контента=Требование`, `Фаза`, `Статус` (см. `.doc-root.yaml`).
```

`order` для разделов: `0` (корень), `00-project=10`, `10-domain=20`, `30-requirements=30`, `40-architecture=40`, `60-implementation=60`, `70-operations=70`.

#### 1.3. `_index.md` пустых подпапок (3 шт.)

`00-project/adr/`, `30-requirements/functional/`, `30-requirements/non-functional/` — сейчас содержат только `.gitkeep`. Нужен минимальный `_index.md`:

```markdown
---
order: <число>
title: <Название>
---

<1-2 предложения, что хранится здесь.>

(пусто — статьи будут добавляться по мере роста проекта)
```

`.gitkeep` остаётся (не мешает; пустых подпапок без `.gitkeep` git не сохраняет, но `.gitkeep` рядом с `_index.md` не вреден — оставляем для совместимости).

### 2. Изменения в `glossary.md`

Frontmatter перевести в object-нотацию:

```yaml
---
order: 1
title: Глоссарий
properties:
  - name: Тип контента
    value: [Глоссарий]
  - name: Фаза
    value: [MVP]
  - name: Статус
    value: [Draft]
---
```

Тело статьи не меняется.

### 3. Изменения в `.doc-root.yaml`

Удалить `required: true` из всех трёх property-определений (строки 15, 29, 40 в текущей версии). Остальные поля (`name`, `type`, `style`, `icon`, `values`) — без изменений.

### 4. Валидатор `scripts/validate-content.py`

#### CLI

```
python3 scripts/validate-content.py [content_dir]
```

`content_dir` — необязательный, default `content/`.

#### Exit codes

- `0` — структура валидна (warnings допустимы)
- `1` — обнаружены errors
- `2` — пакет `pyyaml` не установлен (печатает `pip install pyyaml` и URL)

#### Зависимости

- Python ≥ 3.8 (доступен в репозитории — уже используется в `test-template.sh`)
- `pyyaml` (soft dep — graceful fallback с инструкцией `pip install pyyaml`)

#### Формат вывода

```
content/00-project/foo/: missing _index.md (Gramax не покажет раздел в навигации)  [error]
content/30-requirements/auth.md: использует плоскую frontmatter-нотацию; см. CLAUDE.md  [error]
content/00-project/_index.md: содержит блок properties:; _index.md не должен иметь properties  [error]
content/40-architecture/db.md: property "Тип контента" имеет значение "Бизнес-правило", не входящее в enum [Требование, Архитектура, ADR, Runbook, Исследование, Глоссарий, Прочее]  [error]

Errors: 4 | Warnings: 0
```

В чистом случае:
```
content/: OK (15 файлов проверены)
Errors: 0 | Warnings: 0
```

#### Проверки (релиз 1)

| # | Уровень | Описание |
|---|---------|----------|
| C1 | error | Каждая подпапка под `content/` (имеющая `.md` файлы или вложенные подкаталоги с `.md`) содержит `_index.md`. Корень `content/` тоже считается подпапкой → корневой `_index.md` обязателен. |
| C2 | error | `_index.md` не содержит блок `properties:` в frontmatter. |
| C3 | error | Frontmatter любого `.md` (кроме `_index.md`) использует object-нотацию: `properties:` — список dict-ов с ключами `name` (строка) и `value` (массив). Любая другая структура (dict с произвольным ключом, плоский `- Ключ: значение`) — error. |
| C4 | error | Имена property из frontmatter статей объявлены в `.doc-root.yaml` (поле `properties[].name`). |
| C5 | error | Значения property из frontmatter входят в `values:` соответствующего property (если `type: Enum`). |
| C6 | warning | Статья (не `_index.md`) не объявляет ни одного property из `filterProperties` — фильтр в Gramax не сработает. |
| C7 | warning | Frontmatter содержит литерал `{{...}}` (плейсхолдер шаблона до `init.sh`). Это нормально для свежего шаблона, но не должно встречаться после init. C4/C5 для такого frontmatter скипаются. |

Плейсхолдеры `{{PROJECT_NAME}}`, `{{PROJECT_CODE}}`, `{{PROJECT_DESCRIPTION}}`, `{{EDITOR_EMAIL}}` в frontmatter (актуально только до запуска `init.sh`) валидатор должен **скипать с warning**, а не падать с error — иначе нельзя запустить валидатор на свежем шаблоне до init.

#### Архитектура реализации

Один файл `scripts/validate-content.py`:
- `class Issue` (level, path, message)
- `def parse_frontmatter(file_path) -> dict | None` — извлекает YAML между `---`, возвращает None для файла без frontmatter
- `def load_doc_root(content_dir) -> dict` — читает `.doc-root.yaml`
- `def check_indexes(content_dir) -> list[Issue]` — C1
- `def check_index_no_properties(content_dir) -> list[Issue]` — C2
- `def check_object_notation(content_dir) -> list[Issue]` — C3
- `def check_property_names(content_dir, doc_root) -> list[Issue]` — C4
- `def check_property_values(content_dir, doc_root) -> list[Issue]` — C5
- `def check_filter_coverage(content_dir, doc_root) -> list[Issue]` — C6
- `def check_placeholders(content_dir) -> list[Issue]` — C7 + сторону: помечает «skip C4/C5 для этих файлов»
- `def main(argv) -> int` — собирает все checks, печатает, возвращает exit code

### 5. Изменения в `scripts/init.sh`

В цикле подстановки плейсхолдеров (строка 93) добавить `content/_index.md` к списку файлов:

```bash
for f in CLAUDE.md AGENTS.md README.md content/.doc-root.yaml content/_index.md; do
  ...
done
```

Никакой другой логики не меняем.

### 6. Изменения в `scripts/test-template.sh`

#### T4 (модификация)

Заменить ассерты `*/README.md` на `*/_index.md`:

```bash
assert ".doc-root.yaml exists" "[ -f content/.doc-root.yaml ]"
assert "root _index.md" "[ -f content/_index.md ]"
assert "00-project _index.md" "[ -f content/00-project/_index.md ]"
assert "10-domain _index.md" "[ -f content/10-domain/_index.md ]"
assert "30-requirements _index.md" "[ -f content/30-requirements/_index.md ]"
assert "30-requirements/functional _index.md" "[ -f content/30-requirements/functional/_index.md ]"
assert "30-requirements/non-functional _index.md" "[ -f content/30-requirements/non-functional/_index.md ]"
assert "00-project/adr _index.md" "[ -f content/00-project/adr/_index.md ]"
assert "40-architecture _index.md" "[ -f content/40-architecture/_index.md ]"
assert "60-implementation _index.md" "[ -f content/60-implementation/_index.md ]"
assert "70-operations _index.md" "[ -f content/70-operations/_index.md ]"
assert "glossary.md exists" "[ -f content/10-domain/glossary.md ]"
```

#### T5 (дополнение)

Добавить ассерт, что `init.sh` подставляет `{{PROJECT_NAME}}` также в `content/_index.md`:

```bash
assert "PROJECT_NAME replaced in content/_index.md" "! grep -q '{{PROJECT_NAME}}' content/_index.md"
```

#### T8 (новый)

После init и overlay — запуск валидатора:

```bash
echo ""
echo "==> T8: validate-content.py passes on initialized template"
assert "validate-content.py exit 0 after init" "python3 scripts/validate-content.py >/dev/null 2>&1"
```

В T6 (после apply-overlay) — добавить такой же ассерт, чтобы overlay не ломал валидацию:

```bash
assert "validate-content.py exit 0 after overlay apply" "python3 scripts/validate-content.py >/dev/null 2>&1"
```

#### T8.c (negative test, опционально)

Сломать структуру (например, удалить `_index.md` из одной подпапки), убедиться что валидатор exit 1:

```bash
echo ""
echo "==> T8.c: validate-content.py detects missing _index.md"
rm content/40-architecture/_index.md
set +e
python3 scripts/validate-content.py >/dev/null 2>&1
RC=$?
set -e
assert "validate-content.py exit 1 on missing _index.md" "[ \"$RC\" = '1' ]"
# восстановить — для последующих тестов (если будут)
git checkout -q content/40-architecture/_index.md
```

(Negative test — nice-to-have; включить при остатке времени, иначе отложить.)

### 7. Изменения в `CLAUDE.md`

В шаблонный CLAUDE.md (`/Users/mdemyanov/knowlage/project_template/CLAUDE.md`) после секции «## Структура плагинной системы» вставить новый раздел:

```markdown
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
```

Размер блока — ~20 строк, не разрастается. Никакие другие секции CLAUDE.md не трогаем (шаблонные `{{PROJECT_NAME}}` остаются как есть, заполняются через `/init`).

### 8. Изменения в `README.md`

В секцию «Полезные команды» (или эквивалент — нужно проверить) добавить строку:

```markdown
- `python3 scripts/validate-content.py` — валидация структуры `content/` под Gramax
```

Если такой секции нет — добавить как короткий пункт в «Быстрый старт» рядом с `bash scripts/init.sh`.

### 9. Изменения в `init.md` (slash-команда)

#### Шаг 6.5 — заменить ссылку на референс

Текущая строка (91):
> Референс по адаптации: `/Users/mdemyanov/knowlage/sd-ai-assistant/content/.doc-root.yaml`.

Заменить на:
> Референс по адаптации (production-эталон): `/Users/mdemyanov/Devel/naumen-ecosystem/business-requirements/.doc-root.yaml`. Старый каталог `sd-ai-assistant` — НЕ использовать как референс схемы (легаси, плоская frontmatter-нотация).

#### Раздел Anti-scope — дополнить

Добавить:
> - НЕ создавать `README.md` в `content/` — Gramax индексирует только `_index.md`.

#### Фаза 1, шаг 3 (Верификация) — добавить ассерт

В список проверок добавить:
```
- `python3 scripts/validate-content.py` — exit 0 (warnings допустимы; errors — блокер).
```

### 10. Изменения в `pm-review.md`

В разделе «Что проверить» → пункт 3 «Целостность `content/`» дополнить:

```markdown
3. **Целостность `content/`:**
   - **Запусти валидатор:** `python3 scripts/validate-content.py`. Любой error → блокер merge.
   - Все статьи в `content/` имеют обязательные properties (см. `content/.doc-root.yaml`).
   - В новых ADR (`content/00-project/adr/`) — все ссылки на предшественников ведут на наполненные статьи (не болванки <100 байт).
   - В новых требованиях (`content/30-requirements/`) — есть JTBD и Acceptance Criteria.
```

### 11. Запись в `docs/lessons-learned.md`

Добавить строку (формат уже принят в файле):

```markdown
| 2026-05-06 | PM | Шаблон / Gramax-структура | `README.md` в подпапках `content/` Gramax не индексирует — навигация ломается; плоская frontmatter-нотация рендерится непредсказуемо | Перевели на `_index.md`, добавили `validate-content.py`, шпаргалку в CLAUDE.md, ссылки на эталон `naumen-ecosystem/business-requirements/`. Источник — pg_vector_service/docs/gramax-skills-update.md. |
```

## Data flow

```
Пользователь
    │
    │ /init "My Project" "MY-PROJECT" "..." "user@x.com" "https://..."
    ▼
init.sh ─── replace_in_file для CLAUDE.md, AGENTS.md, README.md,
    │       content/.doc-root.yaml, content/_index.md  ◄── NEW
    │
    ▼
test-template.sh
    │
    ├── T4: assert _index.md в каждой подпапке  ◄── EDITED
    ├── T5: assert PROJECT_NAME replaced in content/_index.md  ◄── NEW
    ├── T6: assert overlay не ломает validate-content.py  ◄── NEW
    └── T8: validate-content.py exit 0  ◄── NEW
        │
        ▼
    validate-content.py  ◄── NEW
        ├── parse_frontmatter()
        ├── load_doc_root()
        └── checks C1-C6
        │
        ▼
    exit 0/1/2 + список Issue
```

```
PM (main)
    │
    │ /pm-review
    ▼
pm-review.md (slash)
    │
    ├── git status / git diff
    ├── python3 scripts/validate-content.py  ◄── NEW (блокер merge при error)
    ├── проверка ADR / требований
    └── lessons synthesis
```

## Error handling

### Валидатор
- `pyyaml` не установлен → exit 2 + сообщение `pip install pyyaml` (отдельный код, чтобы test-template отличал от validation errors).
- Несуществующий `content_dir` → exit 2 + сообщение.
- Невалидный YAML в frontmatter → error C0 («не удалось распарсить frontmatter»), не валит весь скрипт.
- Файл с плейсхолдерами `{{...}}` в frontmatter → warning, не error (актуально для свежего шаблона до init).

### init.sh
- Если в `content/_index.md` нет плейсхолдера `{{PROJECT_NAME}}` (например, после кастомизации) — `replace_in_file` молча скипает (поведение уже реализовано через `grep -q`).

### apply-overlay.sh
- Не меняем. Если overlay сломает frontmatter (теоретически), это поймает `validate-content.py` в T8.

## Тесты

Все ассерты — в `scripts/test-template.sh`, отдельных pytest/unit-тестов **не вводим** (правило шаблона: smoke через test-template.sh).

| ID | Что | Тип |
|----|-----|-----|
| T4-mod | `_index.md` в каждой подпапке content/ | sanity |
| T5-add | `init.sh` подставляет `{{PROJECT_NAME}}` в `content/_index.md` | integration |
| T6-add | `validate-content.py` зелёный после `apply-overlay.sh naumen-smp` | integration |
| T8 | `validate-content.py` зелёный на свежем `init`-нутом шаблоне | integration |
| T8.c | `validate-content.py` exit 1 на сломанной структуре (опц.) | negative |

Smoke-тесты валидатора на самом шаблоне (= ткущий `content/` после правок секции 1) выполняются как часть Фазы 1 разработки.

## Anti-scope

Что **не** делаем в этой итерации:

- НЕ переписываем `apply-overlay.sh` — overlay по-прежнему работает с теми же markers.
- НЕ меняем палитру `style:` в `.doc-root.yaml` (косметика, отложили в обсуждении).
- НЕ добавляем валидацию overlay-патчей сверх T6 (оставляем nice-to-have).
- НЕ создаём отдельный `docs/gramax-rules.md` — все правила в CLAUDE.md.
- НЕ меняем `content/_index.md` руками после `/init` (это делает пользователь по вкусу).
- НЕ удаляем `.gitkeep` из подпапок — пусть лежит рядом с `_index.md`.

## GO-критерии

- [ ] Все 6 `README.md` в `content/` переименованы в `_index.md` с обновлённым frontmatter.
- [ ] Корневой `content/_index.md` создан с плейсхолдерами `{{PROJECT_NAME}}` и `{{PROJECT_DESCRIPTION}}`.
- [ ] 3 пустые подпапки получили `_index.md`.
- [ ] `glossary.md` использует object-нотацию.
- [ ] `.doc-root.yaml` без `required: true`.
- [ ] `scripts/validate-content.py` создан и проходит на текущем `content/`.
- [ ] `scripts/init.sh` подставляет плейсхолдеры в `content/_index.md`.
- [ ] `scripts/test-template.sh`: T4 модифицирован, T5/T6/T8 добавлены — все зелёные.
- [ ] `CLAUDE.md`: добавлен блок «Правила Gramax-каталога».
- [ ] `init.md`: ссылка на референс заменена; antiscope дополнен; верификация включает валидатор.
- [ ] `pm-review.md`: добавлен запуск валидатора.
- [ ] `docs/lessons-learned.md`: добавлена запись.
- [ ] `bash scripts/test-template.sh` — все T1-T8 зелёные.
