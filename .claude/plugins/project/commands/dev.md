---
description: "Разработчик (subagent, Sonnet). TDD-реализация по архитектуре SA. Пример: /dev implement <фича>, /dev fix <bug>, /dev test <модуль>"
allowed-tools: Task
---

Запусти subagent `dev-agent` через Task tool.

**Входы пользователя:** `$ARGUMENTS`

## Что передать subagent'у

Сформируй prompt по контракту из AGENTS.md:

1. **Цель** одной фразой.
2. **Входные файлы**:
   - Архитектура: `content/40-architecture/<file>.md`
   - Требование (для AC): `content/30-requirements/<file>.md`
   - ADR (если применимо): `content/00-project/adr/<NNN>-*.md`
3. **Ожидаемый артефакт**:
   - Код в `src/` (или язык-специфичном пути)
   - Тесты в `tests/`
   - Заметки реализации в `content/60-implementation/<file>.md` (если есть нюанс)
4. **Критерии приёмки**:
   - Все Acceptance Criteria из BA-требования покрыты тестами
   - Тесты зелёные перед commit (показать вывод)
   - Соблюдён TDD-цикл (red → green → refactor → commit)

## Режимы (распарсь $ARGUMENTS)

- `implement <фича>` — реализация по дизайну SA
- `fix <bug>` — багфикс через `superpowers:systematic-debugging`
- `test <модуль>` — добавить покрытие
- `refactor <путь>` — рефакторинг с зелёными тестами
- (свободный текст) — обсудить
