---
properties:
  - name: Тип контента
    value: [Требование]
  - name: Статус
    value: [Approved]
---

# init.sh UX customization — функтребования

## Контекст

После W4c-A все 7 профилей стали stable. Текущий `init.sh` показывает профили плоским списком имён (`- project`, `- kb-team` и т.д.) без описания — пользователь не понимает, что выбрать без чтения документации. Кроме того, после выбора профиля `apply-overlay.sh` запускается немедленно, без возможности отменить.

Меняем три вещи:

1. Меню профилей показывает `description` и `audience` из manifest.yaml.
2. После выбора выводится summary-блок с метаданными профиля и объёмом изменений.
3. Перед применением — confirm-gate с возможностью отказа.

Не меняем: логику `apply-overlay.sh`, формат manifest.yaml, поведение при `--profile` (CLI-режим).

## Функциональные требования

### FR-1: Профильное меню с описаниями

- **AC-1.1:** При запуске `bash scripts/init.sh` без `--profile` интерактивно показывается список профилей. Каждая строка — `<name> — <description>`. Выравнивание по имени профиля (пробелы/табы) для читаемости.
- **AC-1.2:** Если manifest содержит поле `audience`, оно выводится в скобках после description: `<name> — <description> [для: <audience>]`. Если `audience` отсутствует — строка без скобок (допустимо для `custom`, `project`).
- **AC-1.3:** Порядок строк в меню: `project` первым (default), затем остальные stable профили в алфавитном порядке. Статус `experimental`/`stub` — в конце (если появятся в будущем).
- **AC-1.4:** Под списком — строка-подсказка `Enter profile name (default: project):`. При пустом вводе принимается `project`.

### FR-2: Post-selection summary

- **AC-2.1:** После ввода имени профиля и до вызова `apply-overlay.sh` в stdout печатается summary-блок. Обязательные поля:
  - Имя профиля и description.
  - Количество операций в overlay (op:add / op:replace / op:resolve_agents суммарно).
  - Количество agent_overrides (если есть).
  - Разбивка subagents: N core, N optional, N disabled.
  - Количество init_prompts (вопросов, которые будут заданы после apply).
- **AC-2.2:** Summary форматируется как bulleted список или выровненная таблица; читаемо в 80-символьном терминале. Допустимо оба формата — окончательный выбор за SA.
- **AC-2.3:** Если разобрать manifest не удалось (файл отсутствует, невалидный YAML) — summary не печатается; init продолжается с предупреждением `Warning: cannot read manifest for profile '<name>'`.

### FR-3: Confirm gate

- **AC-3.1:** После summary печатается prompt `Apply profile '<name>'? (Y/n): `. Default — Y (Enter без ввода = Y).
- **AC-3.2:** Если `INIT_FORCE=1` env var установлен — confirm пропускается, init продолжается без ожидания ввода.
- **AC-3.3:** Если stdin не является TTY (`[[ ! -t 0 ]]`) — confirm пропускается, init продолжается (non-interactive safe).
- **AC-3.4:** При ответе `n`, `N` или `no` — init завершается с exit code 0, выводит `Init cancelled by user. Re-run when ready.` Никаких изменений файловой системы не производится (нет git wipe, нет scaffold).

## Нефункциональные требования

### NFR-1: Backwards compatibility

- **AC-1.1:** CLI-режим (`bash scripts/init.sh --profile product "Name" "CODE" "desc" "email" "git-url"`) работает без изменений. Новый UX (меню, summary, confirm) активируется исключительно в interactive mode без `--profile`.
- **AC-1.2:** `INIT_SKIP_PROMPTS=1` (W3-A1, управляет init_prompts) совместим с `INIT_FORCE=1` (управляет confirm-gate). Обе переменные независимы и могут использоваться вместе.
- **AC-1.3:** Существующие тесты в `tests/test-template.sh` (паттерн `T-W4*`) не ломаются. Новые тесты добавляются отдельными T-W4c-B-* кейсами.

### NFR-2: Тестовое покрытие

- **AC-2.1:** Каждый AC из FR-1, FR-2, FR-3 покрывается отдельным ассертом в `tests/test-template.sh` с именованием `T-W4c-B-<NN>`.
- **AC-2.2:** Тесты non-blocking: используют `INIT_FORCE=1` или non-interactive flow (`echo "" | bash scripts/init.sh`). Не требуют реального TTY в CI.
- **AC-2.3:** Тест на отмену (AC-3.4) проверяет, что ни один файл из scaffold не создан после ответа `n`.

## Out of scope (явно зафиксировано)

- Per-override confirm (y/n для каждой операции) — отложено в W4c-C.
- Profile recommendation wizard / опросник для подбора профиля — отложено.
- Migration tooling для смены профиля у уже инициализированного проекта — отложено.
- Изменения формата `manifest.yaml` (добавление полей) — на усмотрение SA по итогам open questions.
- Цветной вывод / ANSI escape — не в scope; допустимо, но не требуется.

## Open questions для SA

1. **Поле `audience` у `custom` и `project`:** У `custom` нет `audience` в manifest, у `project` есть (`PM, команда разработки`). Нужно ли добавить `audience` к `custom` (и зафиксировать «кому это нужно») — или оставить необязательным полем? SA решает при проектировании парсера summary.

2. **Формат summary:** AC-2.2 допускает bulleted list или таблицу. SA выбирает формат при проектировании `_print_profile_summary()` — приоритет: читаемость в 80 символах при `cat` (без ANSI), совместимость с CI-логами.

3. **Источник операций для summary:** Подсчёт op:add / op:replace / op:resolve_agents требует разбора `manifest.yaml` или dry-run вызова `apply-overlay.sh --dry-run`. SA выбирает механизм (прямой парсинг YAML vs вызов dry-run и grep) с учётом надёжности и производительности.
