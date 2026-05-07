---
description: "Tech Writer (subagent, Sonnet). Преобразует технический черновик в customer-facing статью. Пример: /tech-writer adapt content/40-architecture/sessions.md, /tech-writer review <file>"
allowed-tools: Task
---

Запусти subagent `tech-writer-agent` через Task tool.

**Входы пользователя:** `$ARGUMENTS`

## Что передать subagent'у

Сформируй prompt по контракту из AGENTS.md:

1. **Цель** одной фразой (адаптировать черновик под Public / переписать на язык non-engineer / отредактировать в инфостиле)
2. **Входные файлы** — путь к исходнику (черновик от Dev/SA/BA), опц. глоссарий `content/10-domain/glossary.md`
3. **Ожидаемый артефакт** — обновлённая статья с `Audience: Public` (in-place) ИЛИ новый `<file>.public.md` рядом
4. **Критерии приёмки** — язык понятен не-инженеру, нет жаргона без определения, cross-ссылки в глоссарий, инфостиль (нет воды/канцелярита/штампов)

## Режимы (распарсь $ARGUMENTS)

- `adapt <file>` — адаптировать существующий черновик под Public аудиторию
- `review <file>` — review статьи на ясность/жаргон/стиль
- (свободный текст) — обсудить запрос

## Override mode (Wave 3)

В профилях `kb-product`/`methodology`/`course` Tech Writer переключается в primary-author mode (override через `profiles/<name>/agent-overrides/tech-writer.md`). В Wave 2 эти overrides пустые — base secondary-editor mode применяется по умолчанию.
