---
properties:
  - name: Тип контента
    value: [Прочее]
  - name: Фаза
    value: [PoC]
  - name: Статус
    value: [Draft]
---

# uv-enforce: заметки реализации

Фича `epic-uv-enforce`. Имплементация по TDD — 5 коммитов + 1 fix.

## Нетривиальные решения

### `_init_helpers.py` — argparse subcommand dispatch

Все `python3 -c "..."` inline блоки из `init.sh` мигрировали в единый helper-файл с argparse subparsers. Это позволяет тестировать каждый subcommand отдельно и избегает escape-hell в bash.

Добавлен subcommand `json-count` (читает JSON-массив из stdin, выводит длину), которого не было в изначальном дизайне — понадобился для подсчёта `init_prompts` без дополнительных pip-зависимостей.

### pipefail + grep -v = silent abort

`grep -vE` возвращает exit code 1 если ни одна строка не прошла фильтр. В контексте `set -euo pipefail` это убивает скрипт без сообщения об ошибке. Паттерн-fix: оборачивать chain в `{ ...; || true; }` перед финальным `wc -l`:

```bash
COUNT=$( { grep ... | grep -v ... || true; } | wc -l | tr -d ' ')
```

### eval + многострочный stderr = command injection в тестах

`assert()` делает `eval "$cond"`. Если `$cond` содержит развёрнутую переменную с многострочным текстом (например, текст ошибки содержит `iex` — команду PowerShell), bash пытается выполнить эти слова как команды. Fix: pre-compute boolean перед assert:

```bash
echo "$STDERR" | grep -q 'keyword' && MATCH=0 || MATCH=1
assert "desc" "[ \"$MATCH\" = '0' ]"
```

### T-UV-PREREQ-05: изоляция теста от рабочих артефактов

Тест проверяет PEP 723 resolution, а не валидность content/. Использование `rsync + init` копировало SA/BA WIP артефакты с несовместимыми property-values, что валидатор отвергал. Решение: синтетический минимальный content/ только с `_index.md`.

### PATH=/nonexistent требует /bin/bash абсолютным путём

`PATH=/nonexistent bash scripts/init.sh` не работает — bash сам не находится в PATH. Нужно `PATH=/nonexistent /bin/bash scripts/init.sh`.

## Предсуществующие проблемы в worktree (не в scope epic)

10 падающих тестов в `test-template.sh` — следствие того, что `epic-uv-enforce` worktree содержит SA/BA/SA артефакты в `content/` с property-values, не входящими в enum `.doc-root.yaml` (enum рассчитан на `project` profile после init). Эти тесты были красными до начала реализации uv-enforce и останутся таковыми до merge в main.

## Коммиты

| Hash | Тег | Описание |
|------|-----|----------|
| 9b27122 | RED | T-UV-PREREQ-* failing stubs |
| 7fa3865 | GREEN | PEP 723 headers + _init_helpers.py |
| d712f78 | GREEN | init.sh prerequisites gate + migration |
| e1c0f5a | GREEN | uv-guard: check.sh + test-*.sh + apply-overlay.sh |
| 54b7636 | GREEN | docs: Prerequisites + python3→uv |
| 9f2d5c6 | FIX | Test harness robustness (pipefail, eval, artifacts) |
