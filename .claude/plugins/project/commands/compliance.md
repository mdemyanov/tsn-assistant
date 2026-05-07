---
description: "Compliance research-агент (subagent, Sonnet). Gap analysis по переданному стандарту. Пример: /compliance audit iso27001 path/to/standard.md, /compliance audit 152-fz inline:'требования стандарта'"
allowed-tools: Task
---

Запусти subagent `compliance-agent` через Task tool. **Opt-in роль** — research-mode (пользователь обязан передать список требований стандарта; агент НЕ имеет встроенного knowledge-base).

**Входы пользователя:** `$ARGUMENTS`

## Что передать subagent'у

Сформируй prompt по контракту:

1. **Цель** одной фразой (gap analysis по стандарту X для модуля Y / для всего проекта)
2. **Входные файлы**:
   - **Список требований стандарта** — обязательный input от пользователя (file path / URL / inline)
   - Артефакты проекта: требования (`content/30-requirements/`), ADR (`content/00-project/adr/`), архитектура (`content/40-architecture/`), код (`src/`)
   - Опц. DevSecOps findings (`content/00-project/security/`)
3. **Ожидаемый артефакт** — `content/00-project/compliance/<standard>-<YYYY-MM-DD>.md` с Coverage Matrix
4. **Критерии приёмки** — каждое требование стандарта прокомментировано (соответствует / частично / не соответствует / не применимо), gap-priorities выставлены, рекомендации actionable

## Режимы (распарсь $ARGUMENTS)

- `audit <standard> <source>` — где `<standard>` это `iso27001` / `152-fz` / `gdpr` / `internal` (имя для filename), `<source>` — путь / URL / `inline:текст`
- `update <standard>` — обновить существующий gap analysis новой версией стандарта
- (свободный текст) — обсудить scope

## Важно

Если пользователь не передал список требований стандарта — попроси его. **НЕ выдумывай** требования (компилаирование «знаний» из памяти модели для compliance is unsafe).
