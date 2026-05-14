# SPDD Integration — Design Spec (SA-001)

**Дата:** 2026-05-14
**Автор:** SA-agent
**Фаза:** MVP
**ADR:** `docs/adr/ADR-004-spdd-integration.md`
**BA-входы:** BA-001, BA-002, BA-003 (`docs/requirements/spdd-*.md`)

---

## §1. Two-way sync rule

### Готовый блок для CLAUDE.md (Dev копирует как есть)

```markdown
## Правило two-way sync

При расхождении любого нижестоящего слоя проекта с вышестоящим — сначала обновляется
вышестоящий слой (требование, архитектура, принципы, роли), затем нижестоящий
(реализация, runbook, playbook, assessment). Расхождение без предшествующего обновления
вышестоящего слоя — блокер для /pm-review.

**Единственное исключение — hotfix на production:** нижестоящий слой фиксируется немедленно.
Вышестоящий обновляется в post-mortem сразу после фикса, не позднее следующего рабочего
цикла. В commit message обязателен trailer `skip-drift: hotfix — <описание>`.

Конкретные пары upstream→downstream для профиля проекта — в `drift_pairs` manifest профиля
(`docs/overlays/profiles/<name>/manifest.yaml`).

| Профиль | Примеры пар upstream → downstream |
|---------|-----------------------------------|
| `project` | `content/30-requirements/` → `src/`; `content/40-architecture/` → `content/70-operations/` |
| `product` | `content/10-vision/` → `content/30-specs/`; `content/30-specs/` → `content/40-architecture/` |
| `kb-team` | `content/10-domain/` → `content/40-roles/`; `content/40-roles/` → `content/30-runbooks/` |
| `kb-product` | `content/reference/` → `content/guides/`; `content/guides/` → `content/troubleshooting/` |
| `methodology` | `content/10-principles/` → `content/20-practices/`; `content/20-practices/` → `content/30-playbooks/` |
| `course` | `content/00-overview/` → `content/*-module-*/`; `content/*-module-*/` → `content/90-assessments/` |
| `custom` | Определяется на `/init` (поле `drift_pairs` в manifest) |
```

### Место в CLAUDE.md

Блок вставляется после секции «Поток работы» и перед «Красные линии». В «Красные линии» добавляется отдельная строка:

```markdown
- Расхождение нижестоящего слоя с вышестоящим без предшествующего обновления вышестоящего
  (или без bypass-trailer `skip-drift: <reason>`) — блокер для /pm-review
```

### Hotfix-исключение (из RES-001 и BA-001/BR-002)

Формулировка уже включена в блок выше. Семантика: bypass-trailer `skip-drift: hotfix — <описание>` с непустым описанием — обязателен. Пустой reason → WARN (см. §3).

### README.md pointer

В README.md добавляется 1–2 предложения в секцию «Как работать с шаблоном» (или аналогичную):

```markdown
Шаблон следует правилу two-way sync: при расхождении слоёв проекта сначала обновляется
вышестоящий слой (требования, архитектура), затем нижестоящий. Подробнее — раздел
«Правило two-way sync» в `CLAUDE.md`.
```

### Таблица пар drift_pairs по профилям — сверка со scaffold

Фактические каталоги в `content-scaffold/` (проверено SA):

| Профиль | Scaffold-каталоги | drift_pairs (финальный) | Расхождения с PM-планом |
|---------|------------------|------------------------|------------------------|
| `project` | `00-project`, `10-domain`, `30-requirements`, `40-architecture`, `60-implementation`, `70-operations` | `content/30-requirements/→src/`; `content/40-architecture/→src/`; `content/30-requirements/→content/60-implementation/`; `content/40-architecture/→content/70-operations/` | нет; `src/` вне scaffold, но валидный target для code-проектов |
| `product` | `10-vision`, `20-discovery`, `30-specs`, `40-architecture`, `50-releases` | `content/10-vision/→content/30-specs/`; `content/30-specs/→content/40-architecture/`; `content/40-architecture/→src/`; `content/30-specs/→content/50-releases/` | нет расхождений |
| `kb-team` | `10-domain`, `20-onboarding`, `30-runbooks`, `40-roles`, `50-incidents` | `content/40-roles/→content/30-runbooks/`; `content/30-runbooks/→content/20-onboarding/`; `content/10-domain/→content/40-roles/`; `content/50-incidents/→content/30-runbooks/` | нет расхождений |
| `kb-product` | `getting-started`, `guides`, `reference`, `troubleshooting` | `content/reference/→content/guides/`; `content/guides/→content/troubleshooting/`; `content/reference/→content/getting-started/` | нет расхождений |
| `methodology` | `10-principles`, `20-practices`, `30-playbooks`, `40-templates`, `50-cases` | `content/10-principles/→content/20-practices/`; `content/20-practices/→content/30-playbooks/`; `content/30-playbooks/→content/40-templates/` | нет расхождений |
| `course` | `00-overview`, `10-module-01-introduction`, `20-module-02-example`, `90-assessments`, `99-resources` | `content/*-module-*/→content/90-assessments/`; `content/00-overview/→content/*-module-*/` | **РАСХОЖДЕНИЕ:** PM-план использовал `content/10-module-*/`, что покрывает только `10-module-01-introduction`, но не `20-module-02-example`. Исправлено на glob `content/*-module-*/` — покрывает все модульные каталоги. |
| `custom` | `inbox`, `templates` | `[]` | нет (open-ended по замыслу) |

---

## §2. Invariants & Safeguards section

### Шаблон секции — идентичный блок для ba-agent.md и tech-writer-agent.md

Dev вставляет этот блок в раздел «Структура статьи-требования» обоих агентов:

```markdown
## Инварианты и Safeguards

<!-- SA-NOTE: Safeguards — это hard constraints (инварианты), НЕ Acceptance Criteria.
     AC описывают ожидаемое поведение («система делает X при условии Y»).
     Safeguards — условия, нарушение которых делает артефакт невалидным по определению.
     Формулировки — бинарные, лаконичные. Если формулировка начинается с «система должна»
     или «пользователь видит» — это AC, а не Safeguard.
     Молчаливый пропуск секции недопустим. Если неприменимо — явный N/A с обоснованием. -->

**Содержательные:** [hard constraints, которые артефакт никогда не нарушает.
  Примеры для code: `modelId` не может быть null; timeout < 5s.
  Примеры для регламента: у каждой роли указан backup-owner; все исключения явно описаны.
  Примеры для курса: каждая лекция имеет assessment; каждое утверждение подкреплено источником.]

**Sensitive content:** [что НЕ должно попасть в public ветку:
  PII, NDA, коммерческая тайна, токены, secrets, реальные имена клиентов без согласования]

**Жизненный цикл:** [для контентных артефактов: дата следующей ревизии, owner.
  Для кода: deprecation policy, breaking changes policy.]
```

### Расширение чек-листа выхода обоих агентов

Dev добавляет пункт в секцию «Чек-лист выходного артефакта» (или аналогичную) обоих агентов:

```markdown
- [ ] Секция «Инварианты и Safeguards» заполнена или содержит явный `N/A — <обоснование>`
      (молчаливый пропуск недопустим)
```

### Семантика: Safeguards vs AC

Safeguards — это hard constraints: нарушение любого из них делает артефакт невалидным по определению. Это принципиальное отличие от Acceptance Criteria, которые описывают ожидаемое поведение системы. (Источник: SPDD REASONS Canvas, компонент `S`; research-note §б.)

Недопустимые формулировки в Safeguards: «следует избегать», «рекомендуется», «система должна попытаться». Корректные: «X не может быть null», «Y не превышает N», «каждый Z содержит W».

### Примеры по типам проектов

| Тип проекта | Пример Safeguard |
|-------------|-----------------|
| code (project/product) | `modelId` не может быть null; timeout < 5s; нет credentials в public ветке |
| регламент (kb-team) | у каждой роли указан backup-owner; дата ревизии runbook заполнена |
| курс (course) | каждая лекция имеет assessment; каждое утверждение подкреплено источником |
| методология (methodology) | каждый playbook ссылается на принцип; нет исключений без объяснений |
| продуктовая дока (kb-product) | нет NDA-контента в public; каждое утверждение верифицировано |

### Ответ на OQ-001 BA-002 (lint-check)

Автоматический lint наличия секции в статьях (`validate-content.py`) — **не включать**. Достаточно проверки в `test_safeguards_section_template.py` (наличие блока в шаблоне агентов). Lint существующих статей создаст ложные срабатывания на legacy-контент, несоразмерные пользе. Legacy-статьи: обновлять при следующем редактировании (OQ-002 BA-002 — стратегия lazy migration).

---

## §3. Drift-check в /pm-review

### a) Схема расширения manifest.yaml — поле drift_pairs

Поле добавляется в каждый из 7 манифестов. Формальная схема (YAML Schema / JSON Schema):

```yaml
# Тип: sequence of mapping
drift_pairs:
  - upstream: <string>    # required. Path или glob относительно корня репозитория.
    downstream: <string>  # required. Path или glob относительно корня репозитория.
    note: <string>        # optional. Пояснение для команды.
```

**JSON Schema для validate-profile.py:**

```json
{
  "drift_pairs": {
    "type": "array",
    "items": {
      "type": "object",
      "required": ["upstream", "downstream"],
      "properties": {
        "upstream":   {"type": "string", "minLength": 1},
        "downstream": {"type": "string", "minLength": 1},
        "note":       {"type": "string"}
      },
      "additionalProperties": false
    }
  }
}
```

Поле `drift_pairs` — опциональное на уровне манифеста (backward-compat: отсутствие → INFO-skip). Если присутствует, каждый элемент обязан иметь `upstream` и `downstream`.

### b) Glob patterns — семантика

Разрешаются shell-glob паттерны (`*`, `**`, `?`, `[...]`) в обоих полях (`upstream` и `downstream`). Реализация через `pathlib.Path.glob()` (стандартная библиотека Python). Семантика: POSIX glob, без рекурсии по умолчанию (`*` не пересекает разделители каталогов; `**` — пересекает).

Примеры:
- `content/*-module-*/` — все каталоги в `content/`, имя которых содержит `-module-`
- `content/30-requirements/*.md` — все markdown-файлы непосредственно в каталоге
- `src/**/*.py` — все Python-файлы рекурсивно в src/

Пути в `drift_pairs` — **относительно корня репозитория** (ответ на OQ-002 BA-003). Это унифицированная конвенция; `/pm-review` разрешает их от `git rev-parse --show-toplevel`.

### c) Алгоритм drift-check

```
1. ОПРЕДЕЛИТЬ активный профиль:
   - Читать content/.doc-root.yaml
   - Извлечь поле profile: <name>
   - Если поле отсутствует → INFO «profile not set in .doc-root.yaml, skipping drift-check»; exit gracefully

2. ЗАГРУЗИТЬ drift_pairs:
   - Читать docs/overlays/profiles/<name>/manifest.yaml
   - Если drift_pairs отсутствует → INFO «drift_pairs не настроен для профиля <name> — пропуск»; exit gracefully
   - Если drift_pairs пустой массив [] → INFO «drift_pairs пустой для профиля <name> — пропуск»; exit gracefully

3. ПОЛУЧИТЬ DIFF:
   - Команда: git diff --name-only private..HEAD
   - (или private..public при запуске в gate-контексте)
   - Результат: список изменённых файлов (relative paths)

4. ПАРСИНГ BYPASS:
   - Primary: git log private..HEAD --format=%B | grep -E '^skip-drift: .+'
   - Secondary: PR body grep (если доступен через gh CLI)
   - Если найден: извлечь reason (часть после «skip-drift: »)
   - Если reason пустой или содержит только пробелы → reason = EMPTY (см. шаг 6b)

5. ДЛЯ КАЖДОЙ ПАРЫ (upstream, downstream):
   a. Найти downstream-changed = changed_files, совпадающие с glob(downstream)
   b. Найти upstream-changed = changed_files, совпадающие с glob(upstream)
   c. Если downstream-changed пустой → continue (нет изменений downstream; тишина)
   d. Если upstream-changed непустой → continue (обе стороны изменены; тишина)
   e. Если bypass найден И reason != EMPTY:
      → INFO «[drift-check] bypass активен — "<reason>". Пара <upstream>→<downstream> пропущена.»
      → continue
   f. Если bypass найден И reason = EMPTY:
      → WARN «[drift-check] skip-drift без обоснования. Добавьте reason: skip-drift: <reason>.»
      → WARN «[drift-check] downstream изменён без upstream. Файлы: <downstream-changed>. Пара: <upstream>→<downstream>.»
   g. Иначе (downstream изменён, upstream не изменён, bypass отсутствует):
      → WARN «[drift-check] downstream изменён без upstream. Файлы: <downstream-changed>. Пара: <upstream>→<downstream>. Обновите upstream или добавьте skip-drift: <reason>.»
```

### d) Как определить активный профиль — принятое решение

**Выбран вариант: поле `profile:` в `content/.doc-root.yaml`.**

Обоснование:
- `.doc-root.yaml` уже обязателен в каждом Gramax-каталоге — не добавляет новый файл.
- Он находится в `content/`, что семантически корректно (профиль описывает тип content-каталога).
- Не требует изменений в `.claude/settings.json` (избегаем coupling конфигурации агентов с профилем контента).

Отклонённые варианты:
- Отдельный файл `.profile` в корне — лишний файл без естественного места.
- Поле в `.claude/settings.json` — coupling Claude-конфигурации с бизнес-доменом профиля.

Dev добавляет строку `profile: <name>` в шаблон `.doc-root.yaml` каждого профиля в `docs/overlays/profiles/*/doc-root.yaml`. Значение подставляется при `/init`.

**Ответ на OQ-001 BA-003:** активный профиль определяется через `profile:` в `content/.doc-root.yaml`.

### e) Финальные drift_pairs по 7 профилям — с учётом сверки scaffold

```yaml
# profile: project
drift_pairs:
  - upstream: content/30-requirements/
    downstream: src/
    note: "Требования → реализация (code-проекты)"
  - upstream: content/40-architecture/
    downstream: src/
    note: "Архитектура → реализация (code-проекты)"
  - upstream: content/30-requirements/
    downstream: content/60-implementation/
    note: "Требования → документация реализации"
  - upstream: content/40-architecture/
    downstream: content/70-operations/
    note: "Архитектура → операционная документация"

# profile: product
drift_pairs:
  - upstream: content/10-vision/
    downstream: content/30-specs/
    note: "Видение → спецификации"
  - upstream: content/30-specs/
    downstream: content/40-architecture/
    note: "Спеки → архитектурные решения"
  - upstream: content/40-architecture/
    downstream: src/
    note: "Архитектура → реализация"
  - upstream: content/30-specs/
    downstream: content/50-releases/
    note: "Спеки → release notes"

# profile: kb-team
drift_pairs:
  - upstream: content/40-roles/
    downstream: content/30-runbooks/
    note: "Роли → runbook'и"
  - upstream: content/30-runbooks/
    downstream: content/20-onboarding/
    note: "Runbook'и → onboarding"
  - upstream: content/10-domain/
    downstream: content/40-roles/
    note: "Доменные знания → определения ролей"
  - upstream: content/50-incidents/
    downstream: content/30-runbooks/
    note: "Инциденты → обновление runbook'ов"

# profile: kb-product
drift_pairs:
  - upstream: content/reference/
    downstream: content/guides/
    note: "Reference → guides"
  - upstream: content/guides/
    downstream: content/troubleshooting/
    note: "Guides → troubleshooting"
  - upstream: content/reference/
    downstream: content/getting-started/
    note: "Reference → getting started"

# profile: methodology
drift_pairs:
  - upstream: content/10-principles/
    downstream: content/20-practices/
    note: "Принципы → практики"
  - upstream: content/20-practices/
    downstream: content/30-playbooks/
    note: "Практики → playbook'и"
  - upstream: content/30-playbooks/
    downstream: content/40-templates/
    note: "Playbook'и → шаблоны"

# profile: course
# ИСПРАВЛЕНО по сравнению с PM-планом: glob изменён с content/10-module-*/
# на content/*-module-*/ для охвата всех модульных каталогов (10-module-01-*, 20-module-02-*, etc.)
drift_pairs:
  - upstream: content/*-module-*/
    downstream: content/90-assessments/
    note: "Модули → assessments"
  - upstream: content/00-overview/
    downstream: content/*-module-*/
    note: "Обзор курса → модули"

# profile: custom
drift_pairs: []
# Заполняется на /init под конкретный проект.
# Пустой массив — graceful INFO-skip, не WARN.
```

### f) Bypass syntax

**Primary — trailer в commit message:**
```
skip-drift: <reason>
```
Формат аналогичен `Co-Authored-By`. Размещение — в трейлерной секции commit message (после пустой строки). Примеры:
```
skip-drift: hotfix — критический баг авторизации, upstream обновится post-mortem
skip-drift: refactoring only — переименование переменных, бизнес-логика не изменилась
skip-drift: docs only — правка опечаток, требования не менялись
```

**Secondary — строка в PR body:**
```
Drift: skip — <reason>
```
Парсер `/pm-review` проверяет оба варианта. Primary имеет приоритет.

**Правила валидации reason:**
- Reason непустой и не только пробелы → bypass принят → INFO
- Reason пустой (`skip-drift:` без текста) → WARN о пустом reason + WARN о drift

### g) Backward-compat

Существующие проекты без `profile:` в `.doc-root.yaml` и без `drift_pairs` в manifest:
- Отсутствие `profile:` → INFO-skip, нет FAIL, нет WARN
- Наличие `profile:`, но отсутствие `drift_pairs` в manifest → INFO-skip
- Наличие `drift_pairs: []` → INFO-skip (пустой массив)

Опциональный upgrade-playbook: `docs/upgrading-from-template.md` — шаги для добавления `profile:` в `.doc-root.yaml` и `drift_pairs` в manifest существующего проекта.

---

## §4. Тестовый контракт (для QA-author)

QA-author пишет 4 файла стабов на основе этого контракта. **SA не пишет код тестов.**

### AC (полный список из требований)

**BA-001 (two-way sync):**
- AC-001: CLAUDE.md содержит раздел «Правило two-way sync»
- AC-002: Раздел содержит пары для ≥5 профилей (включая ≥2 content-only)
- AC-003: Раздел описывает hotfix-исключение и bypass-trailer
- AC-004: «Красные линии» содержат строку о блокере /pm-review
- AC-005: README.md содержит pointer на раздел
- AC-006: pre-SPDD проект без drift_pairs не получает ошибок (INFO-skip)
- AC-007: test_two_way_sync_in_claude_md.py зелёный

**BA-002 (Safeguards):**
- AC-001: ba-agent.md содержит блок `## Инварианты и Safeguards`
- AC-002: tech-writer-agent.md содержит аналогичный блок
- AC-003: чек-лист ba-agent.md упоминает Safeguards
- AC-004: чек-лист tech-writer-agent.md упоминает Safeguards
- AC-005: промпты агентов содержат разграничение «Safeguards — hard constraints, не AC»
- AC-006: test_safeguards_section_template.py зелёный
- AC-007: smoke-test создания артефакта порождает секцию или явный N/A

**BA-003 (drift-check):**
- AC-001: WARN при downstream-changes без upstream-changes (с именами файлов)
- AC-002: тишина при парных правках
- AC-003: INFO при bypass с непустым reason
- AC-004: WARN при пустом reason в skip-drift
- AC-005: INFO-skip при отсутствии drift_pairs в manifest
- AC-006: все 7 манифестов содержат drift_pairs
- AC-007: content-only профиль (kb-team) выдаёт WARN при content↔content drift
- AC-008: test_pm_review_drift_check.py зелёный
- AC-009: test_drift_pairs_in_manifests.py зелёный

### Архитектурный контекст для тестов

**Компоненты:**
- `content/.doc-root.yaml` — источник активного профиля (поле `profile:`)
- `docs/overlays/profiles/<name>/manifest.yaml` — источник `drift_pairs`
- `.claude/plugins/project/commands/pm-review.md` — оркестратор drift-check
- `scripts/validate-profile.py` — валидация схемы manifest
- `scripts/tests/test_*.py` — тест-файлы (создаёт QA-author)

**Интеграции:**
- git CLI: `git diff --name-only`, `git log --format=%B`
- pathlib.Path.glob() для разрешения glob-паттернов
- YAML parser для manifest и .doc-root.yaml

**Trust boundaries:** pm-review → git diff (read-only) → manifest (read-only) → output WARN/INFO

### Edge cases / boundary conditions

- Bypass с пустым reason: `skip-drift:` (только двоеточие, без текста) → WARN, не INFO
- Bypass в PR body (secondary): `Drift: skip — <reason>` — парсер должен поймать оба формата
- Profile не задан в .doc-root.yaml → graceful INFO-skip, не KeyError
- manifest.yaml отсутствует для профиля (поврежденный репозиторий) → graceful INFO-skip + WARNING о недостающем файле
- Glob pattern с `**` в drift_pairs → рекурсивный поиск через pathlib
- Пустой diff (нет изменений) → drift-check не выдаёт ни WARN, ни INFO (полная тишина)
- course: `content/20-module-02-example/` изменён → glob `content/*-module-*/` должен матчить

### Test-pyramid рекомендация

| Тест | Уровень | Обоснование |
|------|---------|-------------|
| test_two_way_sync_in_claude_md.py | unit (file-check) | grep паттернов в CLAUDE.md; нет внешних зависимостей |
| test_safeguards_section_template.py | unit (file-check) | grep паттернов в agent.md файлах |
| test_drift_pairs_in_manifests.py | unit (YAML parse) | parse 7 manifest.yaml, проверить структуру |
| test_pm_review_drift_check.py | integration | требует git repo с реальными коммитами или mock git diff |

---

## §5. Влияние на существующие компоненты

### scripts/validate-profile.py

Добавить валидацию схемы `drift_pairs`: если поле присутствует, каждый элемент должен иметь `upstream` (string, minLength=1) и `downstream` (string, minLength=1); `note` — опциональный string. Отсутствие поля — не ошибка (backward-compat). Это задача **DEV-004** (manifest changes) + скрипт правится в том же DEV-004.

### scripts/init.sh / _apply_profile.py

При `apply-overlay` — поле `drift_pairs` копируется как есть из manifest в финальный manifest проекта. `_apply_profile.py` не трансформирует его содержимое. Если профиль `custom` — `drift_pairs: []` остаётся пустым; интерактивный `/init` предлагает заполнить пары на основе фактической структуры `content/`.

Дополнительно: шаблон `doc-root.yaml` каждого профиля (`docs/overlays/profiles/*/doc-root.yaml`) получает строку `profile: <name>` — подставляется при `/init`.

### scripts/test-template.sh (OPS-001)

Расширение выходит за рамки SA-001. DevOps (OPS-001) добавляет проверки:
- Для каждого из 7 профилей: `init` → проверить наличие `profile:` в `.doc-root.yaml`, наличие `drift_pairs` в manifest, наличие секции Safeguards в шаблоне агента.
- Smoke-тест pm-review drift-check с тестовыми коммитами.

---

## §6. Риски и mitigations

| Риск | Вероятность | Mitigation |
|------|-------------|-----------|
| drift_pairs glob для course не матчит новые модульные каталоги с нестандартным именем | Средняя | Конвенция: все модульные каталоги course должны содержать `-module-` в имени. Зафиксировать в `docs/overlays/profiles/course/manifest.yaml` как note. |
| profile: в .doc-root.yaml не заполнен для pre-SPDD проектов | Высокая | Graceful INFO-skip; opтional upgrade-playbook в `docs/upgrading-from-template.md`. |
| Конфликт правок CLAUDE.md с Wave-4-C (agent overrides) | Низкая | DEV-001 (CLAUDE.md) выполняется первым; Wave-4-C мерджится после с rebase. |
| Bypass-trailer конфликтует с Co-Authored-By | Низкая | Парсер grep строго по префиксу `^skip-drift:` и `^Drift: skip —`; эти паттерны не совпадают с другими стандартными trailer'ами. |
| Manifest не содержит drift_pairs после DEV-004 | Средняя | test_drift_pairs_in_manifests.py (QA-001) ловит это на CI. |
| glob `content/*-module-*/` матчит несвязанные каталоги | Низкая | Конвенция именования course-каталогов достаточно специфична; если нужна строгость — `note` в drift_pair предупреждает Dev. |

**Дополнительный риск, выявленный SA:**
Если `/pm-review` реализован как Markdown-инструкция (prompting), а не исполняемый скрипт, то drift-check — это LLM-интерпретация алгоритма, а не детерминированный код. Надёжность зависит от качества промпта. Рекомендация Dev: реализовать drift-check как отдельный Python-скрипт `scripts/_drift_check.py` (вызывается из pm-review.md как bash-команда), а не как inline-инструкцию в Markdown. Это даёт тестируемость и детерминизм.

---

## Контракт с QA-author

**AC (полный список):** перечислен в §4 выше.

**Архитектурный контекст:** перечислен в §4 выше.

**Edge cases / boundary conditions:** перечислены в §4 выше.

**Test-pyramid:** перечислена в §4 выше.

---

## Открытые вопросы (resolved)

| Вопрос | Источник | Ответ |
|--------|---------|-------|
| Как определяется активный профиль? | OQ-001 BA-003 | `profile:` в `content/.doc-root.yaml` |
| Пути drift_pairs относительно чего? | OQ-002 BA-003 | Относительно корня репозитория |
| Glob-паттерны поддерживаются? | OQ-003 BA-003 | Да, POSIX glob через pathlib.Path.glob() |
| drift_pairs — наше изобретение? | BA-003 контекст | Да; в оригинальном SPDD нет аналога; наша параметризация для pm-review |
| Lint Safeguards в статьях? | OQ-001 BA-002 | Нет; только в шаблоне агентов (test_safeguards_section_template.py) |
| Legacy-статьи без Safeguards? | OQ-002 BA-002 | Lazy migration: обновлять при следующем редактировании |
| Bypass-reason — enum или free text? | OQ-002 BA-001 | Free text с валидацией на непустоту; enum — overengineering для текущего scope |
