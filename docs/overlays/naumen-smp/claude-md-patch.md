## Стек Naumen SMP

- Платформа: Naumen SMP — FQN-объекты, HQL read-only через `api.db.query`, REST `/find`, `/get`, `/edit`, `/create`
- Инструменты для скриптов SMP: skill `naumen-smp-scripting` (глобальный)
- Документация локально: `/Users/mdemyanov/Devel/naumen-ecosystem/naumen-smp`, `/itsm365`

## DDD-карта (для SMP-проектов)

| DDD | Реализация в SMP |
|---|---|
| Bounded Context | Сценарий / модуль (например, A-Workload, B-Quality) |
| Aggregate | SMP-объект (FQN) |
| Repository | HQL-запрос или REST `/find` |
| Anti-Corruption Layer | Mapper SMP JSON → DTO |
| Domain Event | Событие SMP (action / status change) |

## Дополнительные красные линии (SMP)

- HQL — **только параметризованный** (`setParameter`); интерполяция строк запрещена
- `@InjectApi` — только в `adapters/smp/` (если используется hexagonal layout)
- Error responses наружу — **без stack traces**; stack → в лог с `correlationId`
- Cross-каталожные Gramax-ссылки — **только inline code** `` `path/to/file.md` ``, не markdown `[text](path)` (Gramax не резолвит cross-каталожные ссылки)
- ADR supersede — **НЕ** менять статус старого ADR без sign-off PM
- В MCP tool handler `call()` — обязательно `try/catch (Throwable) + logger.error(msg, e) + throw e` (SMP не логирует uncaught exceptions автоматически)
