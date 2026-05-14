---
properties:
  - name: Тип контента
    value: [Требование]
  - name: Статус
    value: [Draft]
  - name: Фаза
    value: [Production]
---

# Принудительный запуск Python-скриптов через uv

## JTBD

Когда разработчик клонирует шаблон и запускает `init.sh` или скрипты валидации без виртуального окружения,
я (сопровождающий шаблона) хочу, чтобы все Python-скрипты запускались только через `uv run`,
чтобы воспроизводимость работы шаблона не зависела от состояния Python-окружения хост-машины.

## Контекст

В текущей версии шаблона скрипты `scripts/validate-content.py`, `scripts/validate-profile.py`, `scripts/_apply_profile.py`, `scripts/_resolve_agents.py`, `scripts/_validate_common.py` вызываются через `python3 script.py` и требуют глобальной установки PyYAML. Скрипт `init.sh` содержит ~10 inline `python3 -c "..."` блоков с `import yaml`. Отсутствие PyYAML на хосте приводит к непрозрачным ошибкам при первом запуске. Owner требует: все Python-скрипты запускаются исключительно в управляемом виртуальном окружении через `uv run`; в момент инициализации пользователь явно получает инструкцию по установке uv при его отсутствии. Fallback на системный `python3` запрещён. Архитектурный выбор — **Option A: PEP 723 inline metadata** — одобрен owner'ом.

Детальная landscape-выжимка с зарезолвленными вопросами Q1–Q5: `docs/research/uv-enforcement-landscape.md`.

## Функциональные требования

- **FR-1** Все `.py`-файлы в `scripts/` запускаются исключительно через `uv run scripts/<name>.py`. Прямые вызовы `python3 script.py` или `python script.py` запрещены во всех скриптах шаблона (`init.sh`, `check.sh`, `test-*.sh`) и в документации (README, CLAUDE.md, `docs/extending.md`, `docs/troubleshooting.md`).

- **FR-2** Все `.py`-файлы в `scripts/` содержат PEP 723 inline metadata-блок (`# /// script`) с явным `requires-python` и `dependencies`. Файлы без внешних зависимостей указывают `dependencies = []`.

- **FR-3** `init.sh` содержит функцию `check_prerequisites()`, вызываемую в самом начале main-блока — до отображения меню профилей и до любых destructive операций (git-rewrite, file mutation). При отсутствии `uv` в `PATH` функция выводит в stderr: сообщение об ошибке, per-OS install-инструкции (macOS/Linux/Windows), предложение перезапустить init.sh после установки — и завершает процесс с `exit 1`.

- **FR-4** Переменная окружения `INIT_FORCE=1` не обходит prereq-gate. `INIT_FORCE=1` — UX-флаг (пропуск confirm-prompt); проверка наличия `uv` выполняется всегда.

- **FR-5** README содержит секцию «Prerequisites» с install-командами для macOS (Homebrew + curl-installer), Linux (curl-installer), Windows (winget + PowerShell). CLAUDE.md (раздел «Команды сборки и проверки»), `docs/extending.md`, `docs/troubleshooting.md` обновлены: все упоминания прямых `python3 script.py` заменены на `uv run scripts/<name>.py`.

- **FR-6** Inline `python3 -c "..."` блоки в `init.sh` мигрированы согласно типу:
  - YAML-зависимые блоки (используют `import yaml`) — выносятся в `scripts/_init_helpers.py` с PEP 723-заголовком; `init.sh` вызывает `uv run scripts/_init_helpers.py <subcommand>`.
  - stdlib-only блоки (только `import json`) — конкретный вариант миграции (`uv run --no-project python -c "..."` или перенос в helper-файл) решает SA.

- **FR-7** `scripts/check.sh` и все `scripts/test-*.sh` содержат в начале короткий uv-guard: при отсутствии `uv` в `PATH` — вывод install-hint в stderr и `exit 1`.

## Нефункциональные требования

- **NFR-1** Zero global Python state: шаблон не требует `pip install pyyaml` или аналогичных глобальных операций на хосте. Кэш `~/.cache/uv` разрешён (это не repo-state).

- **NFR-2** Воспроизводимость: PEP 723-заголовки фиксируют `requires-python = ">=3.11"` и pin major-версии PyYAML: `"pyyaml>=6.0,<7"`. `uv.lock` не создаётся и не коммитится (single-dep сценарий, Q2 из research).

- **NFR-3** `uv.lock` не коммитится. PEP 723-механизм для отдельных скриптов не генерирует lock-файл; он не должен появляться в репо.

- **NFR-4** Latency первого запуска `uv run` на чистой машине (cold cache) — не более 15 секунд (solve + download PyYAML). Последующие запуски (warm cache) — не более 1 секунды. Это свойство uv, не кода; документируется в README.

- **NFR-5** Вся документация шаблона на русском языке, bash-команды оформлены в code-фрагменты для копипаста.

- **NFR-6** Обратная совместимость для пользователей, у которых PyYAML установлен глобально: после перехода на `uv run` глобальная установка PyYAML игнорируется — скрипты используют изолированный ephemeral venv uv. Поведение не ухудшается.

## User Journey

**Основной сценарий — первый запуск init.sh:**

1. Пользователь клонирует шаблон.
2. Открывает README, читает секцию «Prerequisites», устанавливает `uv`.
3. Запускает `bash scripts/init.sh --profile project --name my-project`.
4. init.sh вызывает `check_prerequisites()` — uv найден, продолжает.
5. init.sh вызывает `uv run scripts/_init_helpers.py parse-manifest project` — uv автоматически создаёт ephemeral venv, устанавливает PyYAML (первый раз ~5–10 сек), запускает helper.
6. init.sh завершает фазу 1, делает initial commit.

**Альтернативный путь — uv не установлен:**

1. Пользователь запускает `bash scripts/init.sh`.
2. `check_prerequisites()` не находит `uv` в `PATH`.
3. В stderr выводятся: строка `ERROR: 'uv' is required`, per-OS install-инструкции, предложение перезапустить.
4. `exit 1` — никакие файлы не изменены, `.git` не тронут.
5. Пользователь устанавливает uv, перезапускает.

**Альтернативный путь — `INIT_FORCE=1` без uv:**

1. Пользователь запускает `INIT_FORCE=1 bash scripts/init.sh`.
2. `check_prerequisites()` всё равно проверяет uv — не находит.
3. `exit 1` с тем же сообщением. `INIT_FORCE=1` не помогает обойти проверку.

## Бизнес-правила

- **BR-1** Прямой вызов `python3` или `python` в контексте шаблонных скриптов и документации запрещён. Единственный легитимный способ исполнения `.py`-файлов шаблона — `uv run`.
- **BR-2** Prereq-gate выполняется до любых destructive операций init.sh. Порядок нарушать нельзя.
- **BR-3** `INIT_FORCE=1` — исключительно UX-флаг (пропуск интерактивного confirm). Он не расширяет права на bypass safety-проверок.
- **BR-4** `uv.lock` не является артефактом шаблона. Downstream-проекты не должны получать его «по ошибке» из шаблона.
- **BR-5** Python-версия: `requires-python = ">=3.11"`. uv скачивает нужную версию автоматически при несоответствии хост-Python.

## Доменные события

- `uv не найден при запуске init.sh` → prereq-gate выводит install-hint, exit 1, файлы не изменены.
- `uv найден, первый запуск скрипта` → uv создаёт ephemeral venv, resolve + download PyYAML, кэширует в `~/.cache/uv`.
- `uv найден, warm cache` → uv подбирает готовый env, скрипт стартует мгновенно.
- `INIT_FORCE=1 + uv не найден` → prereq-gate всё равно срабатывает, exit 1.

## Acceptance Criteria

- [ ] **AC-1 (prereq positive)** Given uv установлен; When `bash scripts/init.sh --profile project --name test`; Then init проходит фазу 1 без ошибок, exit code 0.
- [ ] **AC-2 (prereq negative)** Given uv не установлен (PATH без uv); When `bash scripts/init.sh`; Then stderr содержит строку `uv is required`, per-OS install-инструкции; `.git` не wipe'нут; exit code 1.
- [ ] **AC-3 (INIT_FORCE не bypass prereq)** Given uv не установлен И `INIT_FORCE=1`; When `bash scripts/init.sh`; Then exit code 1, то же сообщение об ошибке.
- [ ] **AC-4 (validate-content под uv, без глобального PyYAML)** Given uv установлен И PyYAML не установлен глобально; When `uv run scripts/validate-content.py`; Then скрипт завершается успешно (uv сам resolve'нул PyYAML через PEP 723).
- [ ] **AC-5 (no bare python3)** When `grep -rn 'python3 ' scripts/ README.md CLAUDE.md docs/`; Then 0 совпадений вне комментариев и PEP 723 shebang-строк.
- [ ] **AC-6 (PEP 723 headers)** When проверить каждый `.py`-файл в `scripts/`; Then каждый содержит блок `# /// script` с `requires-python` и `dependencies`.
- [ ] **AC-7 (README prerequisites)** Given свежий клон репозитория; When открыть README; Then секция «Prerequisites» содержит install-команды для macOS (brew + curl), Linux (curl), Windows (winget + PowerShell irm).
- [ ] **AC-8 (check.sh / test-*.sh guard)** When `check.sh` или `test-*.sh` запущены без uv в `PATH`; Then exit code 1, в stderr — install-hint.
- [ ] **AC-9 (smoke)** `bash scripts/check.sh --full` завершается зелёным; число assertions ≥ текущего baseline + N тестов из группы T-UV-PREREQ-*.

## Открытые вопросы для SA

1. **FR-6, выбор варианта для stdlib-only inline блоков:** research рекомендует `uv run --no-project python -c "..."` для JSON-only блоков, но это создаёт отдельный ephemeral env на каждый вызов (потенциально несколько cache entries). SA решает: оставить inline `uv run --no-project python -c "..."` или централизовать всё (включая stdlib) в `_init_helpers.py`. Критерий: минимум cache entries при первом запуске.

2. **Разбивка `_init_helpers.py`:** нужен один файл с subcommand-dispatch или несколько тематических (например, `_init_yaml_helpers.py`, `_init_json_helpers.py`)? SA решает исходя из читаемости и числа функций.

3. **CI-конфигурация:** SA определяет, нужен ли отдельный ADR для GitHub Actions step (`astral-sh/setup-uv@v4`). Если в шаблоне нет CI-файлов — фиксируем только документально.

4. **uv в `PATH` на нестандартных путях (`~/.cargo/bin`, `~/.local/bin`):** стоит ли в prereq-guard добавить проверку этих путей или ограничиться `command -v uv`? Research рекомендует не усложнять; SA подтверждает.

5. **Тест T-UV-PREREQ-*:** SA совместно с QA-author определяет тест-теги и ожидаемый прирост assertions в AC-9.

## Вне скопа эпика

- Добавление `ruff`, `mypy` или других linter'ов — отдельный эпик.
- Migration tooling для downstream проектов, уже использующих прямой `python3`.
- Изменение логики `_apply_profile.py` и `_resolve_agents.py` — только PEP 723-заголовок добавляется.
- Изменение формата `manifest.yaml` или структуры профилей.
- Windows-специфика init.sh (WSL2 vs native PowerShell) — шаблон bash-only.

## Риски

- **R-1 (блокировка пользователей без uv)** Пользователи, не читающие README, столкнутся с exit 1 при первом запуске. Mitigation: ясный install-hint в stderr init.sh + секция Prerequisites в README.
- **R-2 (latency первого запуска)** Cold-cache `uv run` занимает 3–15 сек. Пользователи могут воспринять это как зависание. Mitigation: задокументировать в README, что первый запуск медленнее из-за resolve PyYAML.
- **R-3 (новый major-релиз PyYAML)** Pin `pyyaml>=6.0,<7` будет блокировать PyYAML 7.x при выходе. Mitigation: minor risk, обновляется одной строкой в PEP 723-заголовке; можно автоматизировать через dependabot в будущем.
- **R-4 (uv в нестандартном PATH)** Пользователи, установившие uv в `~/.cargo/bin` или `~/.local/bin` без добавления в `PATH`, получат ложно-отрицательный prereq-fail. Mitigation: install-hint указывает на необходимость добавить uv в `PATH` (официальный installer делает это автоматически).
- **R-5 (cache-hit поведение при `UV_OFFLINE=1`)** Если скрипт запускается при `UV_OFFLINE=1` на cold cache — uv не сможет resolve PyYAML. Mitigation: документировать; в шаблоне не используем `UV_OFFLINE` по умолчанию.

## Definition of Done

- Все 9 AC (AC-1 — AC-9) проходят.
- `git grep 'python3 '` в `scripts/`, `README.md`, `CLAUDE.md`, `docs/` — 0 совпадений вне комментариев и PEP 723 shebang-строк (`#!/usr/bin/env python3`).
- Каждый `.py`-файл в `scripts/` имеет `# /// script` блок.
- Артефакт `docs/requirements/uv-enforcement.md` создан с корректным frontmatter.
- SA получил бриф (см. ниже) и создал архитектурный артефакт.

---

## Бриф для SA

**Требование:** `docs/requirements/uv-enforcement.md` **Фаза:** Анализ → Дизайн

**Спроектировать:**
- Функцию `check_prerequisites()` в `init.sh`: точное место вызова, POSIX-корректный синтаксис проверки (`command -v uv`), формат stderr-сообщения.
- Структуру `scripts/_init_helpers.py`: PEP 723-заголовок, dispatch-механизм subcommand'ов, перечень переносимых функций из inline `python3 -c "..."` блоков (YAML-группа: строки 12, 76, 366 init.sh).
- Решение по stdlib-only inline блокам (JSON): `uv run --no-project python -c "..."` inline или перенос в helper.
- PEP 723-заголовки для всех 5 существующих `.py`-файлов в `scripts/`: точный список с указанием deps (PyYAML / без внешних deps).
- Короткий uv-guard для `check.sh` и `test-*.sh`.
- Порядок изменений в документации (README, CLAUDE.md, docs/extending.md, docs/troubleshooting.md).

**Бизнес-правила для валидаций:**
- BR-1: запрет прямого `python3` / `python` — grep-проверка (AC-5).
- BR-2: prereq-gate до любых destructive операций.
- BR-3: `INIT_FORCE=1` не bypass'ит prereq.
- BR-4: `uv.lock` не коммитится.
- BR-5: `requires-python = ">=3.11"`.

**AC для проверки архитектуры:** AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-8, AC-9.

**Открытые вопросы к SA:** пункты 1–5 секции «Открытые вопросы».

**Решение по §FR-6 закрепится в ADR** (SA создаёт ADR по выбору варианта миграции inline-блоков).
