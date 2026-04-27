---
description: "DevOps (subagent, Sonnet). Runbook, deploy, мониторинг. Опционально для проектов без инфры. Пример: /devops runbook deploy, /devops monitor <сервис>"
allowed-tools: Task
---

Запусти subagent `devops-agent` через Task tool.

**Входы пользователя:** `$ARGUMENTS`

## Что передать subagent'у

Сформируй prompt по контракту из AGENTS.md:

1. **Цель** одной фразой.
2. **Входные файлы**:
   - Архитектура: `content/40-architecture/<file>.md`
   - NFR из BA: `content/30-requirements/non-functional/<file>.md`
   - Существующие runbook'и: `content/70-operations/`
3. **Ожидаемый артефакт** — путь `content/70-operations/<file>.md`.
4. **Критерии приёмки**:
   - Runbook содержит шаги, проверку здоровья, rollback
   - Мониторинг (метрики + алерты) определён
   - NFR из BA учтены

## Режимы (распарсь $ARGUMENTS)

- `runbook <процедура>` — написать runbook
- `monitor <сервис>` — описать мониторинг и алерты
- `deploy-plan <фича>` — план деплоя
- (свободный текст) — обсудить
