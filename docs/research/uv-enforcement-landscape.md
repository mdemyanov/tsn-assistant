---
properties:
  - name: Тип контента
    value: [Research]
  - name: Статус
    value: [Draft]
---

# uv enforcement landscape

**Дата:** 2026-05-14
**Исследователь:** researcher-agent
**Запрос PM/BA:** Все Python-скрипты должны запускаться только через uv/uvx; init.sh должен явно направлять пользователя на установку package manager, Python (если нужно), uv/uvx. Owner выбрал Option A — PEP 723 inline metadata.
**Глубина:** standard

## TL;DR

`uv run script.py` — правильный инструмент для локальных `.py`-скриптов с PEP 723 inline metadata. `uvx` предназначен для CLI-инструментов из PyPI, не для локальных скриптов. Миграция inline `python3 -c "..."` в init.sh возможна двумя путями: `uv run --with pyyaml python -c "..."` (ad-hoc) или вынос в отдельные `.py`-файлы с PEP 723-заголовками — второй вариант чище и соответствует Owner-требованию единообразия. Prereq-gate должна проверять только наличие `uv` (hard-fail с install-инструкциями); Python проверять отдельно не нужно — uv ставит нужную версию сам. `uv.lock` для single-dep шаблона не нужен. Python pin: `requires-python = ">=3.11"` — разумный минимум для macOS Sequoia и Ubuntu 24.04 LTS.

## Ключевые находки

1. PEP 723 синтаксис — `# /// script` блок в начале файла — [established] — [primary: astral-sh/uv docs]
2. `uv run script.py` читает PEP 723, создаёт ephemeral venv, кэширует по `UV_CACHE_DIR` (default: `~/.cache/uv` на Linux, `~/Library/Caches/uv` на macOS) — [established] — [primary: astral-sh/uv docs]
3. `uvx` = `uv tool run` для CLI-инструментов, опубликованных на PyPI; для локальных `.py` не применяется — [established] — [primary: astral-sh/uv docs]
4. `uv run --with pyyaml python -c "..."` работает: флаг `--with` добавляет dep ad-hoc без изменения скрипта — [established] — [primary: context7/astral-sh/uv]
5. uv автоматически скачивает нужный Python если `requires-python` в PEP 723 не удовлетворён — [established] — [primary: astral-sh/uv docs]
6. macOS Sequoia 15 (Xcode CLT) поставляет Python 3.9.6; Ubuntu 22.04 — 3.10.x; Ubuntu 24.04 — 3.12.x — [established] — [measured locally + known Ubuntu defaults]
7. GitHub Actions: `astral-sh/setup-uv` с `enable-cache: true` — стандартный способ кэшировать uv-окружения; `uv cache prune --ci` уменьшает размер кэша — [established] — [primary: astral-sh/uv GitHub Actions guide]
8. `INIT_FORCE=1` bypass'ит confirm gate в init.sh — это UX-флаг, НЕ safety; prereq-check должна выполняться всегда — [established] — [вывод из кода init.sh]

## Подтемы

### 1. PEP 723 inline script metadata

Точный синтаксис заголовка (должен быть в начале файла):

```python
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pyyaml>=6.0",
# ]
# ///
```

Правила:
- Блок начинается с `# /// script` и заканчивается `# ///` (ровно три слэша).
- `dependencies` обязателен (даже пустой список `[]`) если используется `requires-python` — иначе uv игнорирует блок.
- Порядок ключей не важен; допустимы произвольные `[tool.uv]` секции внутри блока (например, `exclude-newer` для pin по дате).
- Блок должен быть в самом начале файла (до `import`).

Как `uv run` обрабатывает PEP 723:
1. Парсит `# /// script` блок.
2. Резолвит `dependencies` в ephemeral venv (изолированном от project-level `uv.lock`).
3. Кэширует resolved env в `UV_CACHE_DIR`. При повторном запуске с теми же зависимостями — env берётся из кэша (~0мс overhead).
4. Первый запуск (cache miss): solve + download — ориентировочно 3-15с в зависимости от сети; для PyYAML это 1-3с.
5. Если `requires-python` не удовлетворён текущим Python — uv скачивает нужную версию автоматически (через `uv python`).

Pin зависимостей:
- Версионный pin в `dependencies`: `"pyyaml>=6.0,<7"` — достаточно для воспроизводимости без lock-файла при single-dep.
- Жёсткий pin по дате: `[tool.uv] exclude-newer = "2025-01-01T00:00:00Z"` — максимальный детерминизм.
- `uv.lock` при PEP 723 не генерируется (это проектный механизм, не скриптовый).

Источники: [primary] [astral-sh/uv scripts guide](https://docs.astral.sh/uv/guides/scripts/) — canonical reference; [primary] [context7/astral-sh/uv](https://context7.com/astral-sh/uv/llms.txt).

### 2. Альтернативы (краткий контраст — Owner выбрал A)

**Option B: `pyproject.toml` + `uv sync` + `uv run python ...`**
- Когда оправдано: multi-file проект с несколькими зависимостями, где нужен `uv.lock` для воспроизводимых CI-сборок.
- Почему хуже для шаблона: добавляет `pyproject.toml`, `uv.lock` в репо; требует `uv sync` перед первым запуском; сложнее клонировать в новый проект без адаптации; противоречит «single-file self-contained scripts» философии.

**Option C: hybrid wrapper `_py.sh`**
- Идея: bash-обёртка активирует venv перед вызовом python.
- Почему противоречит требованию: пользователь может обойти обёртку и вызвать `python3 script.py` напрямую; нет механизма enforcement на уровне инструмента; добавляет indirection без гарантии.

### 3. `uvx` vs `uv run`

| Характеристика | `uv run script.py` | `uvx tool-name` |
|---|---|---|
| Назначение | Локальные `.py`-скрипты | CLI-инструменты из PyPI |
| Env isolation | Ephemeral venv из PEP 723 deps | Dedicated tool cache |
| Requires PyPI package | Нет | Да (tool — это установленный пакет) |
| Кэш | `UV_CACHE_DIR/scripts/` | `UV_TOOL_DIR/` |
| Флаг `--with` | Да | Да (для плагинов к tool) |
| Project isolation | Да (`--no-project` по умолчанию для inline metadata) | Всегда |

**Применимость к нашим скриптам:** `uvx` неприменим. `validate-content.py`, `validate-profile.py`, `_apply_profile.py`, `_resolve_agents.py`, `_validate_common.py` — локальные файлы, не CLI-пакеты на PyPI. Корректный вызов: `uv run scripts/validate-content.py`.

**Где `uvx` полезен в шаблоне:** будущий lint-эпик (`uvx ruff check .`, `uvx mypy src/`), pre-commit хуки, одноразовые инструменты. Это отдельный эпик, не текущий.

Источники: [primary] [uv tools concepts](https://github.com/astral-sh/uv/blob/main/docs/concepts/tools.md).

### 4. Prereq-gate паттерны в bash

**POSIX-корректная проверка:**

```bash
check_prerequisites() {
  if ! command -v uv >/dev/null 2>&1; then
    echo "ERROR: 'uv' не найден в PATH." >&2
    echo "" >&2
    echo "Установите uv:" >&2
    echo "  macOS:   brew install uv" >&2
    echo "           curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
    echo "  Linux:   curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
    echo "  Windows: winget install --id=astral-sh.uv -e" >&2
    echo "" >&2
    echo "После установки перезапустите init.sh." >&2
    exit 1
  fi
}
```

Почему `command -v` лучше `which`:
- `which` — внешняя утилита, может отсутствовать или иметь разное поведение.
- `command -v` — POSIX shell builtin, работает везде включая `set -e` контекст.
- Возвращает путь к бинарнику или пустую строку; exit code 0/1.

**«uv в нестандартном PATH»:** практически неотличимо от «не установлен» в bash без дополнительных эвристик (проверка `~/.cargo/bin/uv`, `~/.local/bin/uv`). Рекомендация: не усложнять — если `command -v uv` не находит, сообщить пользователю добавить uv в PATH и дать ссылку.

**Non-TTY / CI:** `command -v uv` работает идентично в pipe и TTY. Сообщение на `stderr` + `exit 1` — стандартный паттерн для CI. Интерактивный offer установить uv (`y/n?`) НЕ уместен в init.sh: скрипт destructive (правит файлы, делает git commit), автоматическая модификация хоста нежелательна.

**Python отдельно:** prereq-gate НЕ должна проверять `python3`. uv сам управляет Python через `uv python install` при несоответствии `requires-python` в PEP 723. Проверка `python3` — избыточна и сбивает с толку.

### 5. Install-инструкции uv per-OS

Актуальность проверена через WebFetch на `https://docs.astral.sh/uv/getting-started/installation/` (2026-05-14).

**macOS**
```bash
# Homebrew (рекомендован как "дефолтный пакетный менеджер macOS")
brew install uv

# Официальный curl-installer (работает без Homebrew)
curl -LsSf https://astral.sh/uv/install.sh | sh
```
Homebrew = дефолт для macOS-разработчиков. curl-installer — fallback для окружений без brew (CI, minimal images).

**Linux**
```bash
# curl-installer (рекомендован официально)
curl -LsSf https://astral.sh/uv/install.sh | sh

# wget-альтернатива
wget -qO- https://astral.sh/uv/install.sh | sh

# pipx (если pipx уже есть)
pipx install uv
```
На Linux нет единого «дефолтного» пакетного менеджера для developer-tools; curl-installer — наименьший denominator.

**Windows**
```powershell
# WinGet (рекомендован)
winget install --id=astral-sh.uv -e

# PowerShell standalone installer
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

Шаблон ориентирован на macOS/Linux (bash scripts). Windows-инструкции — для README, не для init.sh.

Источник: [primary] [uv installation docs](https://docs.astral.sh/uv/getting-started/installation/) — актуально на дату исследования.

### 6. Inline `python3 -c "..."` в init.sh — миграция

В init.sh насчитывается ~10 inline `python3 -c "..."` вызовов. Группируются по назначению:

1. **YAML-парсинг профилей** (строки 12, 76, 366) — используют `import yaml`; требуют PyYAML.
2. **JSON-обработка** (строки 49, 55, 302-309) — используют только `import json`; stdlib, PyYAML не нужен.
3. **Валидационные вызовы** (строки 388-395) — уже вызывают отдельные `.py`-файлы.

**Вариант A (ad-hoc `--with`):**
```bash
# Для YAML-inline (вместо python3 -c "import yaml...")
uv run --no-project --with 'pyyaml>=6.0' python -c "import yaml, json; ..."

# Для JSON-inline (stdlib, без PyYAML)
uv run --no-project python -c "import json; ..."
```
Плюс: не плодит файлы. Минус: `uv run --no-project --with 'pyyaml>=6.0' python -c "..."` многословно; каждый вызов — потенциальный cache-miss при первом запуске (отдельный ephemeral env для `python -c` без файла).

**Вариант B (вынос в `.py`-файлы с PEP 723):**
Создать `scripts/_init_helpers.py` (или несколько файлов) с PEP 723-заголовком. Inline логика переезжает в функции. init.sh вызывает `uv run scripts/_init_helpers.py <subcommand>`.
Плюс: единый env для всех helper-вызовов (один cache entry); читаемость; тестируемость. Минус: +1 файл в репо.

**Рекомендация для SA:** Вариант B предпочтителен. Вынести YAML-зависимые inline-блоки в `scripts/_init_helpers.py` с PEP 723-заголовком (`dependencies = ["pyyaml>=6.0"]`). JSON-only блоки (stdlib) мигрировать на `uv run --no-project python -c "..."` — там нет external deps, overhead минимален.

### 7. CI и автоматизация

**GitHub Actions — рекомендованный паттерн:**
```yaml
- name: Install uv
  uses: astral-sh/setup-uv@v4
  with:
    enable-cache: true   # кэширует ~/.cache/uv между runs

- name: Run validators
  run: |
    uv run scripts/validate-content.py
    uv run scripts/validate-profile.py
```

**Первый запуск (cache miss):** uv resolve + download PyYAML — ~3-8с. При `enable-cache: true` последующие runs используют кэш (~0.1с).

**Ручное управление кэшем (если не используется setup-uv):**
```yaml
env:
  UV_CACHE_DIR: /tmp/.uv-cache
steps:
  - uses: actions/cache@v5
    with:
      path: /tmp/.uv-cache
      key: uv-${{ runner.os }}-pyyaml
  - run: uv run scripts/validate-content.py
  - run: uv cache prune --ci   # уменьшить размер кэша
```

**Полезные env vars для CI:**
- `UV_CACHE_DIR` — явный путь к кэшу (для cache action).
- `UV_OFFLINE=1` — запрет сетевых запросов (только кэш); полезно для air-gapped окружений или после `uv sync`.
- `UV_NO_SYNC=1` — запрет автоматической синхронизации project env (не применимо для PEP 723 скриптов напрямую, актуально для project-mode).
- `UV_PYTHON_DOWNLOADS=never` — запрет автоматической загрузки Python (если Python заведомо есть в образе).

**`INIT_FORCE=1` и prereq:** `INIT_FORCE=1` bypass'ит только confirm-gate (интерактивный y/n). Prereq-check (`check_prerequisites`) НЕ должна зависеть от `INIT_FORCE`. Логика: INIT_FORCE — UX-ускоритель для CI, но CI тоже должен иметь uv установленным (через `astral-sh/setup-uv` step до вызова init.sh).

### 8. Open questions — рекомендации для SA

**Q1: Hard-fail prereq (exit 1) vs interactive offer to install?**
Рекомендация: **hard-fail**. init.sh — destructive скрипт (git rewrite, file mutation). Автоматическая установка uv на хост без явного согласия нарушает принцип минимального воздействия. Корректный UX: ясное сообщение на stderr с инструкциями, exit 1. Пользователь устанавливает uv сам и перезапускает.

**Q2: `uv.lock` коммитить или нет?**
Рекомендация: **нет**. `uv.lock` генерируется для project-mode (`pyproject.toml`). При PEP 723 inline metadata lock-файл не создаётся. Единственная dep — PyYAML — достаточно пинится версионным constraint в `dependencies`. Коммит `uv.lock` в шаблон создал бы артефакт, который каждый downstream-проект получает «по ошибке» и должен удалять.

**Q3: Pin Python version (`requires-python`)?**
Рекомендация: `requires-python = ">=3.11"`.
Обоснование: macOS Sequoia (Xcode CLT) поставляет Python 3.9.6 — слишком старый для ряда современных конструкций; macOS Homebrew Python сейчас 3.13+. Ubuntu 22.04 LTS — Python 3.10; Ubuntu 24.04 LTS — Python 3.12. Минимум 3.11 охватывает Ubuntu 22.04 через uv python install (uv скачает нужную версию сам) и даёт доступ к `tomllib` в stdlib, `ExceptionGroup`, улучшенным type hints. Использовать 3.10 как минимум тоже допустимо, но 3.11 — лучший trade-off стабильности и возможностей.

**Q4: Где prereq-check — в init.sh или отдельный `_check_prereqs.sh`?**
Рекомендация: **функция `check_prerequisites()` внутри init.sh**, вызываемая в самом начале main-блока. Обоснование: prereq для init.sh специфичны; отдельный `_check_prereqs.sh` нужен только если ту же проверку хотят переиспользовать из нескольких скриптов. Сейчас это только init.sh. `check.sh` и тест-раннеры имеют свои prereq (uv обязателен там тоже, но проверка может быть inline). Если в будущем появится общая потребность — вынести в `scripts/_check_prereqs.sh` через обычный рефакторинг.

**Q5: Должны ли `check.sh --fast` и тест-раннеры валидировать наличие uv в начале?**
Рекомендация: **да**. После миграции все `python3 script.py` → `uv run script.py` вызовы перейдут в check.sh и test-*.sh. Если uv не установлен, они упадут с неочевидным `command not found`. Лучше: добавить short prereq-guard в начало check.sh и каждого test-*.sh (2-3 строки), выводящий ясный hint. Это не блокирует эпик — может быть отдельным ticket'ом, но желательно в том же PR.

## Что НЕ удалось выяснить

- Точная latency первого `uv run` с PyYAML на cold cache (без локальных замеров): документация даёт «несколько секунд», реальные числа зависят от сети и зеркала.
- Поведение `uv run --with pyyaml python -c "..."` при отсутствии сети (`UV_OFFLINE=1`) — нет явного указания в docs: скорее всего cache-hit работает, cold miss — ошибка. Требует проверки Dev'ом.
- Windows-специфика init.sh (WSL2 vs native PowerShell) — не исследовалась; шаблон bash-only.

## Рекомендации для BA

- Зафиксировать как **FR**: все Python-скрипты в `scripts/` запускаются ТОЛЬКО через `uv run`; прямой вызов `python3 script.py` запрещён.
- Зафиксировать как **FR**: init.sh, check.sh и test-*.sh должны содержать prereq-check на наличие `uv` в PATH; при отсутствии — сообщение с инструкциями по установке + exit 1.
- Зафиксировать как **NFR**: prereq-check не должна зависеть от `INIT_FORCE=1`.
- Зафиксировать как **NFR**: скрипты должны запускаться в CI (GitHub Actions) без ручной установки Python — только uv (который сам управляет Python).
- Зафиксировать как **BR**: README.md должен содержать секцию Prerequisites с install-командами для uv per-OS.

## Рекомендации для SA

- Выбрать PEP 723 inline metadata для всех 5 существующих `.py`-скриптов: добавить `# /// script` блок с `requires-python = ">=3.11"` и `dependencies = ["pyyaml>=6.0"]` (для тех, кто использует YAML; для остальных — пустой `dependencies = []`).
- Для inline `python3 -c "..."` в init.sh с YAML: вынести в `scripts/_init_helpers.py` с PEP 723-заголовком, вызывать через `uv run scripts/_init_helpers.py <subcmd>`.
- Для inline `python3 -c "..."` в init.sh без внешних deps (только stdlib `json`): мигрировать на `uv run --no-project python -c "..."`.
- Добавить функцию `check_prerequisites()` в init.sh (вызов в начале); аналогичный guard в check.sh и test-*.sh.
- `uv.lock` не создавать и не коммитить.
- В GitHub Actions использовать `astral-sh/setup-uv@v4` с `enable-cache: true`.
- `INIT_FORCE=1` не должен bypass'ить prereq-check — это UX-флаг, не safety override.

## Источники

- [primary] [uv scripts guide](https://docs.astral.sh/uv/guides/scripts/) — PEP 723, `uv run`, `--with` flag
- [primary] [uv tools concepts](https://github.com/astral-sh/uv/blob/main/docs/concepts/tools.md) — uvx vs uv run distinction
- [primary] [uv GitHub Actions integration](https://github.com/astral-sh/uv/blob/main/docs/guides/integration/github.md) — CI caching patterns
- [primary] [uv installation docs](https://docs.astral.sh/uv/getting-started/installation/) — per-OS install commands (verified 2026-05-14)
- [primary] [context7/astral-sh/uv](https://context7.com/astral-sh/uv/llms.txt) — comprehensive uv docs with code examples
- [secondary] [astral-sh/uv README](https://github.com/astral-sh/uv/blob/main/README.md) — overview and positioning
- [primary] scripts/init.sh (local) — inventory of python3 call sites (measured: ~10 inline calls, 6 .py files)
