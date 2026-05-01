---
description: "Бизнес-аналитик (subagent, Sonnet). Создаёт требования и критерии приёмки. Пример: /ba new-requirement user-sessions, /ba review content/30-requirements/foo.md"
allowed-tools: Task
---

Запусти subagent `ba-agent` через Task tool.

**Входы пользователя:** `$ARGUMENTS`

## Что передать subagent'у

Сформируй prompt по контракту из AGENTS.md («Вызов субагентов — контракт»):

1. **Цель** одной фразой (что создать/проверить).
2. **Входные файлы** — конкретные пути:
   - Существующие требования: `content/30-requirements/`
   - Глоссарий: `content/10-domain/glossary.md`
   - Исследования (если есть): `content/10-domain/research/`
3. **Ожидаемый артефакт** — путь `content/30-requirements/<en-lowercase-hyphenated>.md`.
4. **Критерии приёмки**:
   - JTBD сформулирован
   - FR с параметрами и бизнес-правилами
   - NFR заполнены
   - Acceptance Criteria измеримые
   - Frontmatter с properties из `.doc-root.yaml`

## Режимы (распарсь $ARGUMENTS)

- `new-requirement <slug>` — создать новое требование
- `review <path>` — проверить существующее требование на полноту
- `glossary-add <term>` — добавить термин в глоссарий
- (свободный текст) — обсудить запрос
