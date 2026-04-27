## SMP-расширение

### DDD → SMP маппинг

| DDD | Реализация в SMP |
|---|---|
| Bounded Context | Сценарий A-F (или модуль) |
| Aggregate | SMP-объект (FQN) |
| Domain Service | HQL-запрос или REST-операция |
| Repository | `api.db.query(hql)` или REST `/find/{fqn}` |
| Anti-Corruption Layer | Mapper SMP JSON → DTO в `adapters/smp/` |
| Domain Event | SMP action / status change |
| Invariant | Guard в `core/` (вне зависимости от SMP) |

### Шаблон спеки MCP-инструмента (если проект делает MCP-tools)

```markdown
### Tool: [name]
**Описание:** [...]  **Сценарий:** [A-F]  **SMP Endpoint:** [REST / HQL]
**Parameters:** | Параметр | Тип | Обязательный | Описание |
**Response:**   | Поле    | Тип | Описание |
**Token estimate:** ~N input + ~M output  **Rate limit:** 60 req/min/тенант
**Error handling:** 404 → пустой ответ, 429 → retry с backoff, 5xx → circuit breaker
```

### Hexagonal Architecture (если применяется)

- `core/` — чистое ядро, **не импортирует** `ru.naumen.*` (кроме `core.*`/`ports.*`)
- `ports/` — интерфейсы (inbound/outbound)
- `adapters/smp/` — единственное место для `@InjectApi`
- `adapters/transport/` — JSON-RPC / MCP transport
- Нарушение boundary — ловится через `CoreBoundarySpec` или аналогичный архитектурный тест

### ADR-trail check (внешние ADR)

При ссылке на внешний ADR N (например, `Devel/naumen-smp-mcp/content/00-project/adr/016-*.md`) **обязательно** проверить ADR N+1..N+5 в той же теме — более поздний ADR может расширять / supersede'ить указанный прецедент.

### Version-dependent statements

Перед правкой «версия X» в статье — классифицируй утверждение:
- **Исторический факт** — «верифицировано на стенде (версия Y) 2026-DD-MM» — сохраняй дату+версию+стенд, добавляй пометку «текущая версия — vZ, см. ADR-NNN».
- **Целевая декларация** — «работает на версии Y» — заменяй версию на актуальную.

Замена без классификации ломает историю.

### «Частично closed» статус (для предложений / features)

При указании статуса «частично closed» — **всегда** разделяй: что закрыто на уровне framework, что остаётся ответственностью разработчика bundle / cookbook. Без разграничения разработчики воспринимают закрытие как снятие red-line.

### Cross-каталожные Gramax-ссылки

- Внутри текущего Gramax-каталога (`content/`) — markdown `[text](path)` работает.
- На файлы вне Gramax-каталога (например, `Devel/naumen-smp-mcp/content/...`) — **только inline code** `` `path/to/file.md` ``. Gramax не резолвит cross-каталожные ссылки.
- Исключение — публичный HTTP URL.
