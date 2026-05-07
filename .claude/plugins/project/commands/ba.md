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

## Режимы

BA работает в двух режимах:

### Режим author (default)

`/ba <action>` или `/ba --mode=author <action>`

Распарсь `$ARGUMENTS`:
- `new-requirement <slug>` — создать новое требование
- `review <path>` — проверить существующее требование на полноту
- `glossary-add <term>` — добавить термин в глоссарий
- (свободный текст) — обсудить запрос

### Режим acceptance (gate AC ↔ реализация)

`/ba --mode=acceptance <req>` или из pipeline `/pipelines/ba-acceptance <req>`

Цель: проверить, что реализация (код + тесты) реально покрывает каждое Acceptance Criteria из требования. Вынести вердикт **pass** или **block**.

Передай subagent'у `ba-agent`:

1. **Цель**: «BA --mode=acceptance: проверить AC ↔ реализация для требования <req>»
2. **Входные файлы**:
   - Требование `content/30-requirements/<req>.md`
   - at-design `content/30-requirements/<req>/at-design.md` (если есть, от qa-author)
   - Test report (последний) `content/60-implementation/test-reports/`
   - Реализация `src/`, тесты `tests/`
3. **Ожидаемый артефакт** — секция «Acceptance log — YYYY-MM-DD (BA --mode=acceptance)» добавляется в конец файла требования с матрицей AC × Test × Implementation × Status
4. **Критерии приёмки** — каждое AC проверено (status: pass / block с причиной); вердикт сформулирован

**Pipeline-handoff:**
- pass → pipeline продолжается (PR в `private`, ждёт `/pm-review`)
- block → возврат к `/dev` с action items; pipeline ставится на паузу

**Не путай author и acceptance:**
- author **создаёт** требование
- acceptance **проверяет** реализацию против существующего требования
- В одном prompt'е не выполняй обе роли
