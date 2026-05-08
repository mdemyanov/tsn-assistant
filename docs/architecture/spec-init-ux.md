---
properties:
  - name: Тип контента
    value: [Архитектура]
  - name: Статус
    value: [Approved]
---

# Spec: init.sh UX customization

**Требование:** `docs/requirements/init-ux.md`
**Контекст:** После W4c-A все 7 профилей stable. Текущий `init.sh` показывает плоский список имён без описания; пользователь не понимает, что выбрать. Нет возможности отменить перед применением.

---

## Решения по open questions BRQ

### OQ-1: Поле `audience` у `custom`

**Решение:** `audience` — необязательное поле для всех профилей; `custom` остаётся без него.

**Обоснование:** `custom` — catch-all для любого контента, аудитория не ограничена. Добавление фиксированного значения типа "Любой пользователь" создаёт ложную точность. Парсер `print_profile_menu()` пропускает секцию `[для: ...]` если поле отсутствует — это задокументированное поведение (см. Edge cases). Легаси-манифесты без `audience` продолжают работать без изменений.

### OQ-2: Формат summary

**Решение:** Bulleted список с отступом двух пробелов; заголовок секции — одна строка без рамки.

**Обоснование:** Таблица требует минимум 50+ символов на строку для читаемого вида и ломается при `cat` в узких CI-логах (Jenkins, GitHub Actions). Bulleted список с выравниванием по двоеточию читается в 40-символьном окне, не требует ANSI, корректно отображается при `grep` / `tail -f`. Пример:

```
Profile: kb-team — Внутренняя командная KB
  Description : Внутренняя командная KB (onboarding/runbook/role/incident)
  Audience    : Команда разработки, DevOps, on-call
  Operations  : 2 (add: 1, replace: 1)
  Overrides   : 1 (tech-writer)
  Subagents   : 3 core, 2 optional, 5 disabled
  Init prompts: 0
```

### OQ-3: Источник подсчёта операций

**Решение:** Прямой парсинг `manifest.yaml` через `python3 -c`.

**Обоснование:** `apply-overlay.sh --dry-run` содержит side-effect риски (запускает `_apply_profile.py`), требует дополнительного subprocess и может падать на edge-case манифестах независимо. Прямой YAML-парсинг через `python3 -c "import yaml..."` уже используется в `init.sh` (строки 152–157) — паттерн отработан, нет новых зависимостей. Если manifest битый — показываем предупреждение и продолжаем (AC-2.3).

---

## Новые функции в init.sh

### 1. `print_profile_menu()`

**Зона ответственности:** вывод меню профилей с `description` и опционально `audience`; гарантированный порядок (`project` первым, остальные stable — алфавитно).

**Псевдокод:**

```bash
print_profile_menu() {
  # Собрать список профилей через python3 (YAML parse + sort)
  PROFILES_JSON=$(python3 -c "
import yaml, json, os, glob
profiles = []
for mf in glob.glob('docs/overlays/profiles/*/manifest.yaml'):
    try:
        m = yaml.safe_load(open(mf))
        profiles.append({
            'name':        m.get('name', os.path.basename(os.path.dirname(mf))),
            'description': m.get('description', ''),
            'audience':    m.get('audience', ''),
            'status':      m.get('status', 'stable'),
        })
    except Exception:
        pass  # битый manifest — пропустить без crash
# sort: project first, stable alphabetically, остальные в конце
def sort_key(p):
    if p['name'] == 'project': return (0, '')
    if p['status'] == 'stable': return (1, p['name'])
    return (2, p['name'])
profiles.sort(key=sort_key)
print(json.dumps(profiles))
" 2>/dev/null)

  echo "Available profiles:"
  # Вычислить max_len для выравнивания
  MAX_LEN=$(echo "$PROFILES_JSON" | python3 -c "
import json, sys
ps = json.load(sys.stdin)
print(max(len(p['name']) for p in ps) if ps else 7)
")

  # Вывести строку на профиль
  echo "$PROFILES_JSON" | python3 -c "
import json, sys
ps = json.load(sys.stdin)
max_len = $MAX_LEN
for p in ps:
    line = '  {:<{w}} — {}'.format(p['name'], p['description'], w=max_len)
    if p.get('audience'):
        line += ' [для: {}]'.format(p['audience'])
    print(line)
"
}
```

**Входные данные:** `docs/overlays/profiles/*/manifest.yaml`
**Выходные данные:** stdout — отформатированный список
**Режим отказа:** если `python3` недоступен или ни одного manifest не найдено — fallback на legacy-вывод (plain names), без exit 1

### 2. `print_profile_summary <profile_name>`

**Зона ответственности:** вывод summary-блока после выбора профиля, до confirm-gate.

**Псевдокод:**

```bash
print_profile_summary() {
  local profile="$1"
  local mf="docs/overlays/profiles/$profile/manifest.yaml"

  if [[ ! -f "$mf" ]]; then
    echo "Warning: cannot read manifest for profile '$profile'"
    return 0
  fi

  python3 -c "
import yaml, sys
try:
    m = yaml.safe_load(open('$mf'))
except Exception as e:
    print('Warning: cannot read manifest for profile \\'$profile\\': ' + str(e))
    sys.exit(0)

desc      = m.get('description', '')
audience  = m.get('audience', '')
ops       = m.get('operations') or []
overrides = m.get('agent_overrides') or {}
subagents = m.get('subagents') or {}
prompts   = m.get('init_prompts') or []

op_add     = sum(1 for o in ops if o.get('op') == 'add')
op_replace = sum(1 for o in ops if o.get('op') == 'replace')
op_resolve = sum(1 for o in ops if o.get('op') == 'resolve_agents')
op_total   = len(ops)

override_names = list(overrides.keys())

core_count     = sum(1 for v in subagents.values() if v == 'core')
optional_count = sum(1 for v in subagents.values() if v == 'optional')
disabled_count = sum(1 for v in subagents.values() if v == 'disabled')

print('Profile: $profile — ' + desc)
print('  Description : ' + desc)
if audience:
    print('  Audience    : ' + audience)
ops_detail = 'add: {}, replace: {}'.format(op_add, op_replace)
if op_resolve:
    ops_detail += ', resolve_agents: {}'.format(op_resolve)
print('  Operations  : {} ({})'.format(op_total, ops_detail))
if override_names:
    print('  Overrides   : {} ({})'.format(len(override_names), ', '.join(override_names)))
else:
    print('  Overrides   : 0')
print('  Subagents   : {} core, {} optional, {} disabled'.format(
    core_count, optional_count, disabled_count))
print('  Init prompts: {}'.format(len(prompts)))
" 2>/dev/null || echo "Warning: cannot read manifest for profile '$profile'"
}
```

**Входные данные:** имя профиля → `docs/overlays/profiles/<name>/manifest.yaml`
**Выходные данные:** stdout — bulleted summary
**Режим отказа:** `Warning: cannot read manifest for profile '<name>'`; функция возвращает 0 (init продолжается согласно AC-2.3)

### 3. `confirm_apply <profile_name>`

**Зона ответственности:** интерактивный confirm-gate; поддержка `INIT_FORCE=1` и non-TTY bypass.

**Псевдокод:**

```bash
confirm_apply() {
  local profile="$1"

  # Bypass: INIT_FORCE=1
  if [[ "${INIT_FORCE:-0}" == "1" ]]; then
    return 0
  fi

  # Bypass: non-interactive (no TTY on stdin)
  if [[ ! -t 0 ]]; then
    return 0
  fi

  # Интерактивный confirm
  read -r -p "Apply profile '$profile'? (Y/n): " CONFIRM_ANSWER
  CONFIRM_ANSWER="${CONFIRM_ANSWER:-Y}"

  case "$CONFIRM_ANSWER" in
    n|N|no|NO)
      echo "Init cancelled by user. Re-run when ready."
      exit 0
      ;;
    *)
      return 0
      ;;
  esac
}
```

**Входные данные:** `INIT_FORCE` env var, `CONFIRM_ANSWER` stdin
**Выходные данные:** return 0 (продолжить) или exit 0 (отмена без FS-изменений)
**Режим отказа:** нет — функция всегда заканчивается корректно

---

## Integration

Вставка трёх функций в `init.sh` относительно существующих блоков:

### Место объявления функций

Добавить **после** объявления `replace_in_file()` (строка ~137) и **до** основного flow (`# 3.X — T40: Профиль`). Это сохраняет структуру: сначала все helper-функции, потом логика.

### Изменения в блоке profile selection (строки 78–95)

**До (существующий код):**
```bash
if [[ -z "$PROFILE" ]]; then
  if [[ ! -d "docs/overlays/profiles" ]]; then
    ...
  elif [[ ! -t 0 ]]; then
    PROFILE="project"
  else
    echo "Доступные профили:"
    for p in docs/overlays/profiles/*/; do
      ...
      [[ -f "$p/manifest.yaml" ]] && echo "  - $pname"
    done
    read -r -p "Профиль (default: project): " PROFILE
    PROFILE="${PROFILE:-project}"
  fi
fi
```

**После (с новыми функциями):**
```bash
if [[ -z "$PROFILE" ]]; then
  if [[ ! -d "docs/overlays/profiles" ]]; then
    PROFILE="project"
    echo "WARNING: docs/overlays/profiles/ не найдена — fallback на профиль 'project'"
  elif [[ ! -t 0 ]]; then
    PROFILE="project"
  else
    print_profile_menu                                      # <-- NEW
    echo ""
    read -r -p "Enter profile name (default: project): " PROFILE   # <-- UPDATED prompt
    PROFILE="${PROFILE:-project}"
  fi
fi
```

### Изменения после валидации профиля (после строки 111)

**Добавить после** `echo "Profile: $PROFILE"`:

```bash
if [[ -n "$PROFILE" ]]; then
  print_profile_summary "$PROFILE"    # <-- NEW
  confirm_apply "$PROFILE"            # <-- NEW
fi
```

`confirm_apply` вызывается **до** `init_prompts` и `apply-overlay.sh` — пользователь может отменить до любых FS-изменений. После `exit 0` в `confirm_apply` ни git-wipe, ни scaffold не запускаются (AC-3.4).

---

## Тестирование (T-W4c-B-* в test-template.sh)

### T-W4c-B-MENU (5 ассертов)

Контекст: init запускается в tmpdir с манифестами профилей. Вместо TTY подаётся `echo "project" |` чтобы ответить на prompt после вывода меню.

```bash
# T-W4c-B-MENU-01: меню активируется без --profile (присутствует заголовок "Available profiles:")
OUTPUT=$(echo "project" | bash scripts/init.sh ...)
assert "T-W4c-B-MENU-01: заголовок Available profiles" \
  "echo \"$OUTPUT\" | grep -qF 'Available profiles:'"

# T-W4c-B-MENU-02: description присутствует для профиля project
assert "T-W4c-B-MENU-02: project description в меню" \
  "echo \"$OUTPUT\" | grep -q 'project.*Delivery-проект'"

# T-W4c-B-MENU-03: project первым в списке (перед alphabetical)
assert "T-W4c-B-MENU-03: project первым" \
  "echo \"$OUTPUT\" | grep -n 'project\|kb-team' | head -1 | grep -q 'project'"

# T-W4c-B-MENU-04: audience показывается если есть в manifest (kb-team имеет audience)
assert "T-W4c-B-MENU-04: audience kb-team в меню" \
  "echo \"$OUTPUT\" | grep -qF '[для:'"

# T-W4c-B-MENU-05: custom без audience — строка без [для:]
assert "T-W4c-B-MENU-05: custom без audience-скобок" \
  "echo \"$OUTPUT\" | grep 'custom' | grep -qvF '[для:'"
```

### T-W4c-B-SUMMARY (4 ассерта)

Контекст: подаётся `INIT_FORCE=1` чтобы пропустить confirm. Вывод захватывается.

```bash
# T-W4c-B-SUMMARY-01: summary показывает description профиля kb-team
OUTPUT=$(INIT_FORCE=1 bash scripts/init.sh --profile kb-team ...)
assert "T-W4c-B-SUMMARY-01: description в summary" \
  "echo \"$OUTPUT\" | grep -qF 'Внутренняя командная KB'"

# T-W4c-B-SUMMARY-02: summary показывает operations count > 0
assert "T-W4c-B-SUMMARY-02: Operations > 0 в summary" \
  "echo \"$OUTPUT\" | grep -E 'Operations[[:space:]]*:[[:space:]]*[1-9]'"

# T-W4c-B-SUMMARY-03: summary показывает overrides count (kb-team имеет 1)
assert "T-W4c-B-SUMMARY-03: Overrides: 1 в summary" \
  "echo \"$OUTPUT\" | grep -E 'Overrides[[:space:]]*:[[:space:]]*1'"

# T-W4c-B-SUMMARY-04: summary показывает subagents breakdown (core/optional/disabled)
assert "T-W4c-B-SUMMARY-04: Subagents core/optional/disabled в summary" \
  "echo \"$OUTPUT\" | grep -E 'Subagents[[:space:]]*:.*core.*optional.*disabled'"
```

### T-W4c-B-CONFIRM (5 ассертов)

```bash
# T-W4c-B-CONFIRM-01: INIT_FORCE=1 bypasses confirm — init завершается успешно
RC=$(INIT_FORCE=1 bash scripts/init.sh --profile project ... ; echo $?)
assert "T-W4c-B-CONFIRM-01: INIT_FORCE=1 exit 0" "[ \"$RC\" = '0' ]"

# T-W4c-B-CONFIRM-02: no-TTY (echo "" | bash init.sh) bypasses confirm — exit 0
RC=$(echo "" | bash scripts/init.sh --profile project ... ; echo $?)
assert "T-W4c-B-CONFIRM-02: no-TTY bypass exit 0" "[ \"$RC\" = '0' ]"

# T-W4c-B-CONFIRM-03: ответ "n" — exit 0 (cancelled gracefully)
RC=$(echo "n" | bash scripts/init.sh ... ; echo $?)
assert "T-W4c-B-CONFIRM-03: cancel exit 0" "[ \"$RC\" = '0' ]"

# T-W4c-B-CONFIRM-04: ответ "n" — FS не изменён (нет scaffold, нет git-wipe)
TMPDIR_TEST=$(mktemp -d) && cp -r . "$TMPDIR_TEST/" && cd "$TMPDIR_TEST"
echo "project" | bash scripts/init.sh ... <<< $'project\nn'
assert "T-W4c-B-CONFIRM-04: scaffold не создан после cancel" \
  "[ ! -d content/00-project/plans ]"

# T-W4c-B-CONFIRM-05: stdout содержит "Init cancelled by user"
OUTPUT=$(echo $'project\nn' | bash scripts/init.sh ...)
assert "T-W4c-B-CONFIRM-05: cancelled message в stdout" \
  "echo \"$OUTPUT\" | grep -qF 'Init cancelled by user'"
```

**Итого: 14 ассертов** (MENU: 5, SUMMARY: 4, CONFIRM: 5).

---

## Edge cases

| Ситуация | Поведение |
|----------|-----------|
| Manifest без поля `audience` | `print_profile_menu` — строка без `[для: ...]`; `print_profile_summary` — строка Audience пропускается |
| Manifest без `init_prompts` или пустой список | Summary: `Init prompts: 0` |
| `agent_overrides: {}` (пустой dict) | Summary: `Overrides: 0` |
| `operations: []` или поле отсутствует | Summary: `Operations: 0 (add: 0, replace: 0)` |
| Сломанный YAML в manifest | `print_profile_menu` — профиль пропускается без crash; `print_profile_summary` — `Warning: cannot read manifest for profile '<name>'`, return 0; init продолжается |
| `python3` недоступен | `print_profile_menu` — legacy-fallback (plain names как сейчас); `print_profile_summary` — warning + return 0 |
| Директория `docs/overlays/profiles/` отсутствует | Существующий legacy-fallback (строка 80-81) срабатывает до вызова `print_profile_menu` — функции не вызываются |

---

## Backwards compatibility

- **CLI-режим** (`bash scripts/init.sh --profile product "Name" "CODE" ...`): `PROFILE` устанавливается до блока interactive selection → `print_profile_menu()` не вызывается. `print_profile_summary` и `confirm_apply` вызываются, но `confirm_apply` сразу делает bypass (non-TTY в большинстве CI-сценариев) или `INIT_FORCE=1`. Меню не показывается — поведение без изменений.
- **`INIT_SKIP_PROMPTS=1`**: управляет `init_prompts`-блоком (строки 178–202), не пересекается с `INIT_FORCE=1` (управляет confirm-gate). Обе переменные независимы; `INIT_SKIP_PROMPTS=1 INIT_FORCE=1 bash scripts/init.sh ...` — валидная комбинация.
- **Существующие тесты `T-INIT-PROFILE-*`, `T-W4a-P4`, `T-W4b-BASELINE`**: используют `--profile <name>` + `INIT_SKIP_PROMPTS=1`/`INIT_FORCE=1` или non-TTY stdin. Новые функции либо не вызываются (CLI mode без TTY) либо делают немедленный bypass.

---

## Verification для Dev

- [ ] `T-INIT-PROFILE`, `T-INIT-PROFILE-KB`, `T-W4a-P4`, `T-W4b-BASELINE` — все остаются зелёными
- [ ] 14 новых `T-W4c-B-*` ассертов зелёные
- [ ] Manual test: `bash scripts/init.sh` (без `--profile`) показывает меню с description и `[для: ...]` для профилей с audience
- [ ] Manual test: выбор профиля → summary-блок с 6-7 строками → confirm prompt
- [ ] Manual test: ответ `n` на confirm → `Init cancelled by user. Re-run when ready.` → FS не изменён
- [ ] Manual test: `INIT_FORCE=1 bash scripts/init.sh --profile kb-team ...` — без confirm, summary выводится

---

## Контракт с QA-author

**AC (полный список из требования):**

- AC-1.1: Без `--profile` — показывается список `<name> — <description>` с выравниванием
- AC-1.2: Если manifest содержит `audience` — добавляется `[для: <audience>]`; если нет — строка без скобок
- AC-1.3: Порядок: `project` первым, затем stable alphabetically
- AC-1.4: Подсказка `Enter profile name (default: project):`; пустой ввод → `project`
- AC-2.1: Summary-блок содержит description, operations count, overrides, subagents breakdown, init_prompts count
- AC-2.2: Bulleted список, читаемый в 80 символах
- AC-2.3: Сломанный manifest → `Warning: cannot read manifest for profile '<name>'`; init продолжается
- AC-3.1: Confirm prompt `Apply profile '<name>'? (Y/n):`; Enter → Y
- AC-3.2: `INIT_FORCE=1` → confirm bypass
- AC-3.3: Stdin не TTY → confirm bypass
- AC-3.4: Ответ `n`/`N`/`no` → exit 0, `Init cancelled by user. Re-run when ready.`, FS не тронут
- NFR-AC-1.1: CLI `--profile` работает без изменений (меню не показывается)
- NFR-AC-1.2: `INIT_SKIP_PROMPTS=1` и `INIT_FORCE=1` независимы
- NFR-AC-1.3: Существующие `T-INIT-PROFILE-*` не ломаются

**Архитектурный контекст для тестов:**

- Компоненты: `print_profile_menu()`, `print_profile_summary()`, `confirm_apply()` в `scripts/init.sh`
- Зависимость: `python3` + `yaml` (stdlib или pyyaml); уже используется в `init.sh`
- Данные: `docs/overlays/profiles/*/manifest.yaml` — YAML с полями `name`, `description`, `audience`, `operations[]`, `agent_overrides{}`, `subagents{}`, `init_prompts[]`
- Trust boundary: функции читают только manifest-файлы из репо; stdin только для confirm
- Non-TTY detection: `[[ ! -t 0 ]]` — стандартный bash-идиом; работает в CI

**Edge cases / boundary conditions:**

- Manifest без `audience` — обязательно протестировать отдельно (`custom` — идеальный кейс)
- `print_profile_summary` вызывается даже в `--profile`-режиме → нельзя исключать CI-прогоны где TTY есть, но `INIT_FORCE` не установлен; тест должен учесть это
- `confirm_apply` exit 0 при `n` — ни один файл не создан (проверять состояние tmpdir до/после)
- Сломанный YAML в manifest — python3 `yaml.safe_load` бросает исключение; нужен explicit try/except в каждой функции отдельно
- Python3 недоступен — вероятность низкая (уже проверяется в init.sh строка 151), но тест на graceful degradation полезен

**Test-pyramid рекомендация:**

| AC group | Уровень | Обоснование |
|----------|---------|-------------|
| AC-1.1 / 1.2 / 1.3 / 1.4 (menu format) | integration (bash + real manifests) | зависит от реальных manifest.yaml на диске |
| AC-2.1 / 2.2 (summary content) | integration (bash + real manifests) | парсинг YAML manifest; мокать не имеет смысла |
| AC-2.3 (broken manifest graceful) | integration (bash + injected bad YAML) | нужен tmpdir с намеренно сломанным файлом |
| AC-3.1 / 3.2 / 3.3 (confirm bypass) | integration (bash + env vars) | проверка env-переменных и TTY detection |
| AC-3.4 (cancel + FS integrity) | integration (bash + FS snapshot) | main concern — FS side effect; нужен реальный tmpdir |
| NFR-AC-1.3 (existing tests green) | regression (re-run T-INIT-PROFILE-*) | убедиться, что новые функции не ломают старые тесты |
