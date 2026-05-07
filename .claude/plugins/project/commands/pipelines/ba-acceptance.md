---
description: "Pipeline-gate: BA проверяет AC ↔ реализацию, выносит вердикт pass/block. Пример: /pipelines/ba-acceptance user-sessions"
allowed-tools: Task, Read
---

# /pipelines/ba-acceptance <req>

Gate-pipeline: BA в режиме acceptance проверяет, что реализация (код + тесты) реально покрывает AC требования.

**Аргументы:** `$ARGUMENTS` — slug требования. Пример: `user-sessions`.

## Алгоритм

### Шаг 1. Вызвать BA в режиме acceptance

```
/ba --mode=acceptance $ARGUMENTS
```

Передай subagent'у `ba-agent`:
- **Цель**: «BA --mode=acceptance: проверить AC ↔ реализация для требования $ARGUMENTS»
- **Входы**: `content/30-requirements/$ARGUMENTS.md`, `content/30-requirements/$ARGUMENTS/at-design.md` (если есть), последний `content/60-implementation/test-reports/`, реализация `src/`, тесты `tests/`
- **Артефакт**: секция «Acceptance log — YYYY-MM-DD» в требовании с матрицей AC × Test × Implementation × Status × Notes + вердикт
- **Критерии**: каждое AC проверено, вердикт pass или block (с action items если block)

### Шаг 2. Обработать вердикт

- **pass** → pipeline продолжается:
  - Если вызван из `project-planning` — переход к шагу 9 (PR)
  - Если вызван standalone — пользователь решает следующий шаг (обычно PR)

- **block** → pipeline ставится на паузу:
  - Action items из acceptance log → возврат к `/dev`
  - Обнови state в `content/00-project/plans/<epic>.md`: `Status: blocked`
  - Пользователь должен принять решение: fix → re-run gate; abandon → close pipeline

## Передача обратно в Dev

При block передай Dev'у:
- Acceptance log с конкретными «AC X не покрыт» / «AC Y failed»
- Список missing tests (если qa-author не покрыл) → возврат сначала в qa-author, потом в dev

## Anti-scope

- НЕ конвертируй block в pass без явного fix'а
- НЕ помечай AC «covered» без прямой ссылки на тест+impl
- НЕ заменяй BA-author эту gate-проверкой — это другая роль (см. `agents/ba-agent.md`)
