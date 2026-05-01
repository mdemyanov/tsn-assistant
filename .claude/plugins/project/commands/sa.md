---
description: "Системный аналитик (subagent, Sonnet). Архитектура, ADR, спеки интеграций. Пример: /sa design <фича>, /sa adr <решение>, /sa review content/40-architecture/foo.md"
allowed-tools: Task
---

Запусти subagent `sa-agent` через Task tool.

**Входы пользователя:** `$ARGUMENTS`

## Что передать subagent'у

Сформируй prompt по контракту из AGENTS.md:

1. **Цель** одной фразой (что спроектировать/решить/проверить).
2. **Входные файлы**:
   - BA-требование: `content/30-requirements/<file>.md`
   - Глоссарий: `content/10-domain/glossary.md`
   - Существующие ADR: `content/00-project/adr/`
   - Существующая архитектура: `content/40-architecture/`
3. **Ожидаемый артефакт** — путь `content/40-architecture/<file>.md` или `content/00-project/adr/<NNN>-<title>.md`.
4. **Критерии приёмки**:
   - Компоненты с зонами ответственности и интерфейсами
   - NFR mapping (как требования из BA закрываются)
   - Интеграционные точки описаны (протокол, контракт, error handling)
   - Если ADR — alternatives considered и consequences

## Режимы (распарсь $ARGUMENTS)

- `design <фича>` — архитектурный дизайн фичи (статья в 40-architecture)
- `adr <решение>` — оформить ADR
- `review <path>` — ревью архитектурного артефакта
- (свободный текст) — обсудить вопрос
