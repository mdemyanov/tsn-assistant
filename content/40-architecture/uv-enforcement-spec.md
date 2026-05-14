---
properties:
  - name: Тип контента
    value: [Спецификация]
  - name: Статус
    value: [Draft]
---

# Спецификация: принудительный запуск Python-скриптов через uv

## Контекст

Требование: `content/30-requirements/uv-enforcement.md` (commit fdf647c).  
Research: `docs/research/uv-enforcement-landscape.md` (commit db9ee0a).  
Архитектурный выбор: **Option A — PEP 723 inline metadata** — одобрен owner'ом.

Текущее состояние: 5 `.py`-файлов в `scripts/` используют PyYAML через глобальный `pip install pyyaml`; `init.sh` содержит ~10 inline `python3 -c "..."` блоков. При отсутствии PyYAML на хосте скрипты падают с непрозрачными ошибками. Шаблон должен быть самодостаточным без глобального Python-state.

---

## A. PEP 723 заголовки — точные тексты

PEP 723 блок должен быть **первым содержательным блоком файла** — сразу после shebang-строки (`#!/usr/bin/env python3`), до любых `import`. Синтаксис: открывается `# /// script`, закрывается `# ///` (ровно три слэша).

### `scripts/validate-content.py`

Файл использует PyYAML через `_validate_common.py` (транзитивный импорт — `require_yaml()` вызывается внутри). Внешняя зависимость: **pyyaml**.

```python
#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pyyaml>=6.0,<7.0",
# ]
# ///
```

### `scripts/validate-profile.py`

Аналогично — использует `_validate_common.py`. Внешняя зависимость: **pyyaml**.

```python
#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pyyaml>=6.0,<7.0",
# ]
# ///
```

### `scripts/_apply_profile.py`

Импортирует `_validate_common` напрямую (`from _validate_common import parse_yaml_file, require_yaml`). Внешняя зависимость: **pyyaml**.

```python
#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pyyaml>=6.0,<7.0",
# ]
# ///
```

### `scripts/_resolve_agents.py`

Использует `import yaml` напрямую (подтверждено `grep`). Внешняя зависимость: **pyyaml**.

```python
#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pyyaml>=6.0,<7.0",
# ]
# ///
```

### `scripts/_validate_common.py` — helper-модуль: нужен ли PEP 723?

**Решение SA: PEP 723 заголовок нужен.**

Обоснование: `_validate_common.py` является helper-модулем, импортируемым из других `.py`-файлов. При вызове через `uv run validate-content.py` зависимости берутся из PEP 723 блока основного скрипта (`validate-content.py`), а не из helper'а — таким образом, при транзитивном импорте PyYAML доступен. Однако `_validate_common.py` не вызывается как самостоятельный скрипт через `uv run`, поэтому с точки зрения исполнения PEP 723 блок в нём игнорируется (`uv run` читает PEP 723 только у точки входа).

Тем не менее, добавить заголовок в `_validate_common.py` необходимо по следующим причинам:

1. **AC-6 (grep-check)**: тест `T-UV-PREREQ-06` проверяет `# /// script` в каждом `.py`-файле `scripts/`. Без заголовка в helper'е тест падает.
2. **Целостность**: если кто-то запустит `uv run scripts/_validate_common.py` напрямую (случайно или для отладки) — файл не упадёт из-за отсутствия PyYAML.
3. **Единообразие правила BR-1**: все `.py` в `scripts/` имеют PEP 723 блок без исключений.

```python
#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pyyaml>=6.0,<7.0",
# ]
# ///
```

**Итог по пяти файлам:**

| Файл | PyYAML | PEP 723 блок | Примечание |
|------|--------|--------------|------------|
| `validate-content.py` | да (транзитивно) | `dependencies = ["pyyaml>=6.0,<7.0"]` | точка входа |
| `validate-profile.py` | да (транзитивно) | `dependencies = ["pyyaml>=6.0,<7.0"]` | точка входа |
| `_apply_profile.py` | да (прямой import) | `dependencies = ["pyyaml>=6.0,<7.0"]` | точка входа |
| `_resolve_agents.py` | да (прямой import) | `dependencies = ["pyyaml>=6.0,<7.0"]` | точка входа |
| `_validate_common.py` | да (прямой import) | `dependencies = ["pyyaml>=6.0,<7.0"]` | helper; PEP 723 нужен для AC-6 + целостности |

---

## B. Миграция inline `python3 -c "..."` в `init.sh`

### Инвентаризация inline-блоков

Полный список из `init.sh` (на дату спеки):

| # | Строка | Назначение | Зависимость | Группа |
|---|--------|------------|-------------|--------|
| 1 | 12 | `print_profile_menu`: парсит все `manifest.yaml`, строит JSON-массив профилей с name/description/audience/status | pyyaml (import yaml) | YAML |
| 2 | 49 | `print_profile_menu`: вычисляет max длину имени профиля из JSON | stdlib json | JSON |
| 3 | 55 | `print_profile_menu`: форматирует строки меню из JSON | stdlib json | JSON |
| 4 | 76 | `print_profile_summary`: парсит manifest выбранного профиля, печатает bulleted summary | pyyaml (import yaml) | YAML |
| 5 | 294 | `init_prompts`: парсит `init_prompts` из manifest.yaml выбранного профиля → JSON | pyyaml (import yaml) | YAML |
| 6 | 302 | `init_prompts`: `len()` JSON-массива prompts | stdlib json | JSON |
| 7 | 305 | `init_prompts`: extract `id` из prompt по индексу | stdlib json | JSON |
| 8 | 306 | `init_prompts`: extract `prompt` text | stdlib json | JSON |
| 9 | 307 | `init_prompts`: extract `type` | stdlib json | JSON |
| 10 | 308 | `init_prompts`: extract `default` | stdlib json | JSON |
| 11 | 309 | `init_prompts`: extract `choices` → join через `|` | stdlib json | JSON |
| 12 | 366 | `compat_stacks`: парсит `compatible_stacks` из manifest.yaml выбранного профиля | pyyaml (import yaml) | YAML |

Итого: **3 YAML-группы** (строки 12, 76, 294+366), **9 JSON-блоков** (строки 49, 55, 302–309).

### Решение SA по stdlib-only JSON-блокам (open question 1)

**Решение: все блоки (YAML и JSON) мигрируют в `scripts/_init_helpers.py`.**

Обоснование отказа от `uv run --no-project python -c "..."` для JSON-блоков:

1. **Кэш**: `uv run --no-project python -c "..."` создаёт отдельный ephemeral env без PEP 723 (нет файла = нет cache key по содержимому). Каждый вызов — отдельный env. При 9 JSON-блоках за один запуск `init.sh` это 9+ cache entries на cold start.
2. **Читаемость**: длинные однострочники `python3 -c "import json,sys; p=json.load(sys.stdin)[$i]; print(p.get('id', ''))"` трудно поддерживать в bash-heredoc.
3. **Тестируемость**: функции в `_init_helpers.py` тестируются отдельно (см. T-UV-PREREQ-10); inline `python -c` — нет.
4. **Единообразие**: один файл = один cache entry при warm cache. Первый запуск — один `uv run` install вместо 10.

Итог: `_init_helpers.py` содержит и YAML-, и JSON-блоки. `uv run --no-project python -c "..."` не используется нигде.

### Структура `scripts/_init_helpers.py` (open question 2)

**Решение SA: один файл с argparse-based subcommand dispatch.**

Объём: ~150–250 строк. Файл вызывается как `uv run scripts/_init_helpers.py <subcommand> [args...]`.

PEP 723 заголовок:

```python
#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pyyaml>=6.0,<7.0",
# ]
# ///
```

**Интерфейс subcommand'ов:**

| Subcommand | Аргументы | Вывод | Мигрирует из строк init.sh |
|------------|-----------|-------|---------------------------|
| `list-profiles` | — | JSON-массив объектов `{name, description, audience, status}`, отсортированный (project первый, stable алфавитно) | 12 |
| `menu-max-len` | JSON-строка на stdin | число (int) — max длина `name` | 49 |
| `menu-format` | `--max-len N`, JSON-строка на stdin | форматированные строки меню | 55 |
| `profile-summary` | `<profile>` | bulleted summary профиля на stdout | 76 |
| `init-prompts` | `<profile>` | JSON-массив prompt-объектов `{id, prompt, type, default, choices}` | 294 |
| `prompt-field` | `<index> <field>` + JSON на stdin | значение поля по индексу (строка) | 302–309 |
| `compat-stacks` | `<profile>` | строка через запятую (или пустая) | 366 |

**Примечание по `menu-max-len` и `menu-format`**: блоки строк 49 и 55 получают JSON через stdin (pipe). Subcommand'ы их сохраняют ту же семантику — stdin pipe. Альтернативный вариант: объединить `list-profiles` + `menu-max-len` + `menu-format` в единый `print-menu`, который делает всё сразу и пишет готовый вывод меню. Это уменьшает число `uv run` вызовов. **Dev решает**, какой вариант предпочесть; оба допустимы архитектурно.

**Блок строк 302–309** (`prompt-field`) реализует доступ к полям массива prompts. Альтернатива: `init-prompts` возвращает полный JSON, а `prompt-field` парсит его для каждого i и поля. Dev может объединить все поля в один `prompt-all-fields <profile> <index>` → JSON, чтобы сократить число вызовов `uv run` в цикле с 5× до 1× на итерацию. SA **рекомендует** `prompt-all-fields` как более эффективный вариант; интерфейс уточняет Dev.

---

## C. Функция `check_prerequisites()` в `init.sh`

### Место вызова

Разместить **после блока `set -euo pipefail` и вспомогательных функций** (helper definitions не требуют uv), **до первого обращения к аргументам и меню профилей**. Схема порядка в `init.sh`:

```
1. #!/usr/bin/env bash
2. set -euo pipefail
3. [helper functions: replace_in_file, print_profile_menu, ...]
4. check_prerequisites()   ← определение функции
5. # ===== Main =====
6. check_prerequisites     ← ВЫЗОВ (первой строкой main-блока)
7. [parse args]
8. [profile menu]
9. [destructive operations]
```

Правило BR-2: prereq-gate обязан выполниться до любых destructive операций.

### Псевдокод функции (bash)

```bash
check_prerequisites() {
  if ! command -v uv >/dev/null 2>&1; then
    echo "ERROR: 'uv' не найден в PATH." >&2
    echo "" >&2
    echo "Установите uv и перезапустите init.sh:" >&2
    echo "" >&2
    echo "  macOS (Homebrew — рекомендован):" >&2
    echo "    brew install uv" >&2
    echo "" >&2
    echo "  macOS / Linux (curl-installer):" >&2
    echo "    curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
    echo "" >&2
    echo "  Windows (WinGet):" >&2
    echo "    winget install --id=astral-sh.uv -e" >&2
    echo "" >&2
    echo "  Windows (PowerShell):" >&2
    echo "    powershell -ExecutionPolicy ByPass -c \"irm https://astral.sh/uv/install.ps1 | iex\"" >&2
    echo "" >&2
    echo "Примечание: если uv установлен, но не найден — добавьте его в PATH." >&2
    echo "  Типичные пути: ~/.local/bin, ~/.cargo/bin (зависит от установщика)." >&2
    echo "  Официальный установщик добавляет uv в PATH автоматически при следующем" >&2
    echo "  открытии shell. Перезапустите shell или выполните:" >&2
    echo "    source \$HOME/.local/bin/env   # или аналогичный файл из вывода установщика" >&2
    echo "" >&2
    echo "Документация: https://docs.astral.sh/uv/getting-started/installation/" >&2
    exit 1
  fi
}
```

**Поведенческие требования:**

- `command -v uv` — POSIX builtin, работает в `set -e` контексте, не требует внешних утилит.
- Весь вывод — в `stderr` (`>&2`), не в stdout.
- `exit 1` — жёсткое завершение.
- `INIT_FORCE=1` — не проверяется внутри функции; функция всегда выполняет проверку (FR-4, BR-3).
- non-TTY / CI: поведение идентично — `command -v uv` работает одинаково в TTY и pipe. Интерактивного предложения установить uv нет.
- Нестандартный PATH (`~/.cargo/bin`, `~/.local/bin`): функция не занимается heuristic-поиском. Если `command -v uv` не находит — выводит install-hint с явным указанием типичных путей (последний блок сообщения). Это достаточно для диагностики (open question 4 → resolved).

---

## D. uv-guard для `check.sh` и `test-*.sh`

Короткий guard вставляется в начало каждого файла — **после shebang и `set -euo pipefail`**, до первой содержательной команды:

```bash
# uv-guard: обязательная зависимость
if ! command -v uv >/dev/null 2>&1; then
  echo "ERROR: 'uv' не найден в PATH. Установите: https://docs.astral.sh/uv/getting-started/installation/" >&2
  exit 1
fi
```

**Файлы, требующие guard:**

| Файл | Обоснование |
|------|-------------|
| `scripts/check.sh` | Вызывает `uv run scripts/*.py` после миграции; без uv — `command not found` |
| `scripts/test-template.sh` | Запускает init.sh, который требует uv |
| `scripts/test-apply-overlay.sh` | Вызывает `uv run scripts/_apply_profile.py` |
| `scripts/test-resolve-agents.sh` | Вызывает `uv run scripts/_resolve_agents.py` |
| `scripts/test-validate-content.sh` | Вызывает `uv run scripts/validate-content.py` |
| `scripts/test-validate-profile.sh` | Вызывает `uv run scripts/validate-profile.py` |

Сообщение намеренно короче, чем в `check_prerequisites()`: guard в test-скриптах — диагностика для разработчиков, а не UX для конечных пользователей.

---

## E. Документация — точные изменения

### README.md

Добавить секцию `## Prerequisites` **перед секцией «Быстрый старт»** (или первой h2-секцией описывающей запуск). Точный текст:

```markdown
## Prerequisites

Шаблон требует **[uv](https://docs.astral.sh/uv/)** — менеджер Python-окружений.
Python устанавливать отдельно не нужно: uv управляет Python-версией автоматически.

**macOS (Homebrew — рекомендован):**
```bash
brew install uv
```

**macOS / Linux (curl-installer):**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Windows (WinGet):**
```powershell
winget install --id=astral-sh.uv -e
```

**Windows (PowerShell):**
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

> Первый запуск `uv run` на clean-machine занимает 5–15 сек (скачивает PyYAML).
> Повторные запуски — мгновенные (warm cache `~/.cache/uv`).
```

**Полезные команды** — все вхождения `python3 scripts/X.py` заменить на `uv run scripts/X.py`:

| Было | Стало |
|------|-------|
| `python3 scripts/validate-content.py` | `uv run scripts/validate-content.py` |
| `python3 scripts/validate-profile.py` | `uv run scripts/validate-profile.py` |
| `python3 scripts/_apply_profile.py` | `uv run scripts/_apply_profile.py` |

### CLAUDE.md

Раздел «Команды сборки и проверки» в шаблоне CLAUDE.md является **TODO-секцией** (заполняется при `/init` под проект). Однако конкретное вхождение `python3 scripts/validate-profile.py` в разделе «Профильная система» — замена:

```markdown
# Было:
- `python3 scripts/validate-profile.py` — валидация manifest'ов

# Стало:
- `uv run scripts/validate-profile.py` — валидация manifest'ов
```

Также строку в секции «Правила Gramax-каталога»:

```markdown
# Было:
- **Валидация:** `python3 scripts/validate-content.py` — обязательно зелёный перед merge `private→public`.

# Стало:
- **Валидация:** `uv run scripts/validate-content.py` — обязательно зелёный перед merge `private→public`.
```

### `docs/extending.md`

Найти и заменить все вхождения (~3 места):

```
python3 scripts/validate-profile.py  →  uv run scripts/validate-profile.py
python3 scripts/validate-content.py  →  uv run scripts/validate-content.py
python3 scripts/_apply_profile.py    →  uv run scripts/_apply_profile.py
```

### `docs/troubleshooting.md`

1. Заменить: `python3 scripts/_apply_profile.py` → `uv run scripts/_apply_profile.py` (1 вхождение).
2. Добавить новый раздел FAQ (в конец или в соответствующую секцию):

```markdown
### `uv` не найден

**Симптом:** `init.sh`, `check.sh` или `test-*.sh` завершается с `ERROR: 'uv' не найден в PATH`.

**Причины и решения:**

1. **uv не установлен** — установите через `brew install uv` (macOS) или `curl -LsSf https://astral.sh/uv/install.sh | sh` (Linux/macOS).
2. **uv установлен, но не в PATH** — добавьте `~/.local/bin` или `~/.cargo/bin` в `PATH`. Официальный установщик делает это автоматически при следующем открытии shell.
3. **uv в CI** — используйте `astral-sh/setup-uv@v4` (с `enable-cache: true`) до вызова скриптов шаблона.

Документация: [https://docs.astral.sh/uv/getting-started/installation/](https://docs.astral.sh/uv/getting-started/installation/)
```

### AGENTS.md

Проверить все вхождения `python3 scripts/` — заменить на `uv run scripts/`. Dev выполняет полный grep-pass перед commit.

---

## F. Тесты T-UV-PREREQ-* — точные ассерты

Группа тестов входит в `scripts/test-template.sh`. N = **10**. После эпика baseline: текущее число ассертов + 10 = **237** (согласно AC-9: baseline 227 + 10 = 237).

| Тег | Тип | Что проверяет |
|-----|-----|---------------|
| **T-UV-PREREQ-01** | positive | `bash scripts/init.sh --profile project --name test` при наличии uv в PATH завершается с exit code 0 |
| **T-UV-PREREQ-02** | negative | `PATH=/nonexistent bash scripts/init.sh` → exit code 1, stderr содержит подстроку `uv` |
| **T-UV-PREREQ-03** | INIT_FORCE no-bypass | `INIT_FORCE=1 PATH=/nonexistent bash scripts/init.sh` → exit code 1 (prereq-gate не пропускается) |
| **T-UV-PREREQ-04** | .git untouched | После T-UV-PREREQ-02: `.git/` существует и не пуст (destructive операции не выполнились) |
| **T-UV-PREREQ-05** | validate-content via uv | `uv run scripts/validate-content.py` → exit code 0 (PyYAML резолвится через PEP 723, не глобально) |
| **T-UV-PREREQ-06** | PEP 723 present | `grep -l '# /// script' scripts/*.py` содержит ровно 6 файлов: 5 существующих + `_init_helpers.py` |
| **T-UV-PREREQ-07** | no bare python3 | `grep -rn 'python3 ' scripts/ README.md CLAUDE.md docs/ \| grep -v '^\s*#'` — 0 совпадений (исключены shebang-строки и комментарии) |
| **T-UV-PREREQ-08** | check.sh guard | `PATH=/nonexistent bash scripts/check.sh --fast` → exit code 1 |
| **T-UV-PREREQ-09** | README Prerequisites | `grep -q '## Prerequisites' README.md` → найдено |
| **T-UV-PREREQ-10** | _init_helpers exists + PEP 723 | `scripts/_init_helpers.py` существует И содержит `# /// script` |

**Уточнение AC-9:** N = 10, итоговый baseline после эпика ≥ 237 ассертов.

---

## G. Resolve открытых вопросов BA (все 5)

### OQ-1: stdlib-only JSON-блоки

**Решение: централизовать всё в `_init_helpers.py`, не использовать `uv run --no-project python -c`.**

Критерий минимума cache entries: один файл с PEP 723 = один cache key = один ephemeral env для всех helper-вызовов в рамках одного сеанса `uv`. При `uv run --no-project python -c "..."` без файла cache key не фиксирован — каждый вызов потенциально отдельный cold-start env. Единый `_init_helpers.py` с PEP 723 выигрывает по всем метрикам: единообразие, читаемость, тестируемость, кэш.

### OQ-2: разбивка `_init_helpers.py`

**Решение: один файл, argparse-dispatch.**

Объём ~150–250 строк вписывается в один файл. Разбивка на `_init_yaml_helpers.py` + `_init_json_helpers.py` добавила бы два cache entry вместо одного и усложнила бы dispatch-логику в bash. Единый файл с subcommands покрывает весь контракт; тематический раздел функций внутри файла даёт достаточную структуру.

### OQ-3: GitHub Actions ADR

**Решение: отдельный ADR не нужен.** CI вне скопа эпика (BA явно исключил). Достаточно FAQ-записи в `docs/troubleshooting.md` (см. раздел E) со ссылкой на `astral-sh/setup-uv@v4`. Если CI-интеграция войдёт в следующий эпик — ADR создаётся тогда.

### OQ-4: нестандартные пути uv

**Решение: `command -v uv` достаточно, дополнительные эвристики не нужны.** Официальный curl-installer (`astral.sh/uv/install.sh`) автоматически добавляет `~/.local/bin` в PATH при следующем открытии shell. Homebrew кладёт в `/usr/local/bin` или `/opt/homebrew/bin` — всегда в PATH. Если пользователь не перезапустил shell после установки — install-hint в `check_prerequisites()` явно упоминает это (bullet про PATH + перезапуск shell). Усложнение guard'а эвристическим поиском по `~/.cargo/bin` создаёт false-positive риск и противоречит POSIX-минимализму.

### OQ-5: N ассертов

**Решение: N = 10** (T-UV-PREREQ-01 .. T-UV-PREREQ-10). Итоговый baseline после эпика: **237 ассертов** (текущий 227 + 10).

---

## Компоненты

| Компонент | Ответственность | Входы | Выходы | Зависимости |
|-----------|-----------------|-------|--------|-------------|
| PEP 723 заголовки | Декларация deps для uv; изоляция PyYAML | — | ephemeral venv при `uv run` | uv ≥ 0.4 |
| `check_prerequisites()` | Проверка наличия uv в PATH; hard-fail с install-hint | PATH env | stderr + exit 1 (при отсутствии uv) | bash builtin `command` |
| `scripts/_init_helpers.py` | Парсинг manifest.yaml и JSON для init.sh; subcommand dispatch | CLI args, stdin (JSON) | stdout JSON/text | pyyaml, argparse (stdlib) |
| uv-guard (check.sh, test-*.sh) | Быстрая проверка uv перед запуском тестов | PATH env | stderr + exit 1 | bash builtin `command` |

## Границы

- SA не описывает конкретный формат аргументов argparse — это задача Dev.
- SA не описывает внутреннюю реализацию функций `_init_helpers.py` — только интерфейс subcommands.
- GitHub Actions CI вне скопа: не описывается.
- `uv.lock` не создаётся, не коммитится (NFR-3).
- Ruff/mypy — отдельный эпик.

## Поток данных (основной сценарий)

```
[Пользователь] → bash scripts/init.sh
  → check_prerequisites()
      → command -v uv → найден → continue
  → uv run scripts/_init_helpers.py list-profiles
      → uv: parse PEP 723 → ephemeral venv (pyyaml) → _init_helpers.py main()
      → stdout: JSON массив профилей
  → [меню профилей в bash]
  → uv run scripts/_init_helpers.py profile-summary <profile>
      → stdout: bulleted text
  → [confirm gate]
  → [destructive операции: git, file mutation]
  → uv run scripts/validate-content.py
  → uv run scripts/validate-profile.py
```

## Интеграционные точки

| Точка | Механизм | Контракт | Error handling |
|-------|----------|----------|----------------|
| `uv run scripts/_init_helpers.py <cmd>` | subprocess (bash вызывает uv) | stdout: JSON или text; exit 0 | exit ≠ 0 → bash обрабатывает через `||` или `set -e` |
| `uv run scripts/validate-content.py` | subprocess | exit 0 = clean, exit 1 = errors | WARNING в stderr init.sh, не abort |
| `uv run scripts/validate-profile.py` | subprocess | exit 0 = clean, exit 1 = errors | WARNING в stderr init.sh, не abort |

## NFR Mapping

| NFR | Требование | Как обеспечивается |
|-----|------------|-------------------|
| NFR-1 | Zero global Python state | PEP 723 в каждом `.py` → uv создаёт ephemeral venv; `pip install` не нужен |
| NFR-2 | Воспроизводимость | `pyyaml>=6.0,<7.0` + `requires-python = ">=3.11"` в каждом PEP 723 блоке |
| NFR-3 | `uv.lock` не коммитится | PEP 723 mode не генерирует lock-файл; `.gitignore` не требует изменений |
| NFR-4 | Latency ≤ 15с cold, ≤ 1с warm | Свойство uv cache; документируется в README (> callout) |
| NFR-5 | Русский язык, code-fragments | Все error-сообщения на русском; install-команды в code-block |
| NFR-6 | Обратная совместимость | Глобальный PyYAML игнорируется при `uv run`; изолированный venv |

## Открытые вопросы

Нет. Все 5 open questions BA закрыты в разделе G настоящей спеки.

---

## Бриф для Dev

**Архитектура:** `content/40-architecture/uv-enforcement-spec.md`  
**Требование:** `content/30-requirements/uv-enforcement.md`  
**ADR:** `content/00-project/adr/ADR-002-uv-required.md`  
**Фаза:** Реализация

**Реализовать:**

1. Добавить PEP 723 заголовки в 5 файлов: `validate-content.py`, `validate-profile.py`, `_apply_profile.py`, `_resolve_agents.py`, `_validate_common.py` (точные тексты — раздел A).
2. Создать `scripts/_init_helpers.py` с PEP 723 заголовком и subcommand dispatch (разделы B, G-OQ1, G-OQ2).
3. Добавить `check_prerequisites()` в `init.sh` (раздел C) и заменить все `python3 -c "..."` вызовы на `uv run scripts/_init_helpers.py <subcommand>`.
4. Добавить uv-guard в `scripts/check.sh` и все `scripts/test-*.sh` (раздел D).
5. Обновить документацию (раздел E): README, CLAUDE.md, docs/extending.md, docs/troubleshooting.md, AGENTS.md.
6. Добавить 10 тестов T-UV-PREREQ-* в `scripts/test-template.sh` (раздел F).

**Порядок:** PEP 723 headers → `_init_helpers.py` → `check_prerequisites()` в init.sh → замена inline python3 → guards → docs → tests.

**Acceptance Criteria из BA:** AC-1 .. AC-9 (полный список — `content/30-requirements/uv-enforcement.md`).

---

## Контракт с QA-author

**AC (полный список из требования):**

- AC-1 (prereq positive): init.sh проходит при наличии uv; exit 0
- AC-2 (prereq negative): init.sh без uv → stderr содержит `uv is required`, exit 1, .git не тронут
- AC-3 (INIT_FORCE не bypass prereq): INIT_FORCE=1 + no-uv → exit 1
- AC-4 (validate-content без глобального PyYAML): `uv run scripts/validate-content.py` → exit 0
- AC-5 (no bare python3): grep 0 совпадений вне комментариев
- AC-6 (PEP 723 headers): каждый `.py` в `scripts/` содержит `# /// script`
- AC-7 (README Prerequisites): секция присутствует с install-командами per-OS
- AC-8 (check.sh/test-*.sh guard): при отсутствии uv → exit 1, install-hint в stderr
- AC-9 (smoke): `bash scripts/check.sh --full` зелёный; ассерты ≥ 237

**Архитектурный контекст для тестов:**

- Компоненты: `check_prerequisites()` (bash), `_init_helpers.py` (Python/uv), PEP 723 headers, uv-guard
- Интеграции: bash subprocess → uv → ephemeral venv → PyYAML
- Trust boundary: bash entry → uv process → Python script → файловая система

**Edge cases / boundary conditions:**

- `PATH=/nonexistent` должен блокировать и `init.sh`, и `check.sh`, и все `test-*.sh`
- `INIT_FORCE=1` не должен bypass prereq-check (важно проверить явно: это было явной ошибкой в предыдущих версиях init.sh)
- Первый запуск на cold cache: `uv run` скачивает PyYAML (~5–15с); тест должен иметь достаточный timeout (≥ 30с) или использовать warm-cache fixture
- `_validate_common.py` — helper, но PEP 723 должен быть там (grep-тест покрывает все `*.py`)
- Grep-тест AC-5 исключает shebang (`#!/usr/bin/env python3`) и строки-комментарии; pattern `grep -v '^\s*#'` недостаточен — shebang начинается с `#!`, нужен более точный exclude

**Test-pyramid рекомендация:**

| AC group | Уровень | Обоснование |
|----------|---------|-------------|
| AC-1, AC-2, AC-3 (prereq-gate behavior) | integration | требует реального bash process с управляемым PATH |
| AC-4 (uv + PyYAML isolation) | integration | требует реального uv на машине; нельзя mock'ать |
| AC-5 (grep no bare python3) | unit (статический анализ) | простой grep по файловой системе |
| AC-6 (PEP 723 grep) | unit (статический анализ) | grep по каждому .py |
| AC-7 (README section) | unit (статический анализ) | grep по README.md |
| AC-8 (guard in check.sh + test-*.sh) | integration | требует реального bash с пустым PATH |
| AC-9 (smoke full) | integration/e2e | полный прогон check.sh --full |
