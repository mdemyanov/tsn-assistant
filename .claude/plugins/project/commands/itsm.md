---
description: "ITSM-аналитик (subagent, Sonnet). Консультант по ITIL/KCS/vendor practice. НЕ пишет требования и ADR — только review/советы. Пример: /itsm review content/30-requirements/functional/uc-s2-find-similar-by-comments.md, /itsm является ли single-comment типичным сигналом оператора Service Desk?"
allowed-tools: Task
---

Запусти subagent `itsm-analyst-agent` через Task tool.

**Входы пользователя:** `$ARGUMENTS`

## Что передать subagent'у

Сформируй prompt по контракту из AGENTS.md («Вызов субагентов — контракт»):

1. **Цель** одной фразой (что оценить / валидировать / уточнить с точки зрения ITSM-методологии).
2. **Кто потребитель ответа** — BA / SA / PM / owner. Это влияет на формат рекомендации.
3. **Входные файлы** — конкретные пути:
   - Канон роли: `content/30-requirements/roles/itsm-analyst.md`
   - Объект ревью: путь к UC / ADR / архитектурному фрагменту (из `$ARGUMENTS`)
   - Расширенный glossary (если есть): `content/10-domain/itsm-knowledge.md`
   - Связанные требования / ADR — **только** упомянутые пользователем или явно связанные
4. **Ожидаемый формат ответа**:
   - Inline-ответ — для коротких вопросов
   - Gramax-комментарий через `gramax:comments-write` — для ревью одного файла
   - Mini-review в `content/10-domain/itsm-reviews/<slug>.md` — только для сложных кейсов (3+ паттерна, явный запрос фиксации)
5. **Критерии приёмки**:
   - Указан контекст в ITSM-практике (ITIL practice / KCS / vendor pattern)
   - Оценка с уровнем уверенности [established/emerging/contested]
   - Pros/Cons (если есть альтернативы)
   - Конкретная рекомендация для BA/SA/PM (без правок в файле)
   - References на ITIL/KCS/vendor docs (или явная пометка «требуется /research», если нет уверенной ссылки)

## Режимы (распарсь $ARGUMENTS)

- `review <path>` — ревью UC / ADR / архитектурного фрагмента по указанному пути (Gramax-комментарий или inline).
- `validate-jtbd <path>` — валидация JTBD и acceptance criteria в указанном требовании.
- `mini-review <slug>` — фиксация развёрнутого review как Gramax-статьи в `content/10-domain/itsm-reviews/<slug>.md` (для сложных кейсов).
- (свободный текст) — консультация по ITSM-вопросу. Если запрос неоднозначен — субагент задаст 1-2 уточняющих вопроса.

## Красные линии для PM (вызывающего)

- НЕ запрашивай у субагента создания файлов в `content/30-requirements/`, `content/00-project/adr/`, `content/40-architecture/` — это нарушение контракта роли.
- НЕ делегируй субагенту web-search / ctx7-запросы — это зона `/research`. Если ITSM-вопрос требует свежей vendor-документации, сначала запусти `/research`, потом передай выжимку в `/itsm`.
- НЕ переключай модель на Opus без явного запроса owner'а / необходимости (сложный ADR-review). Стандарт — Sonnet.
