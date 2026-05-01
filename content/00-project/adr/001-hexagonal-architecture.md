---
order: 10
title: "ADR-001: Hexagonal architecture (Ports & Adapters) layout"
properties:
  - Тип контента: ADR
  - Фаза: PoC
  - Статус: Draft
---

# ADR-001: Hexagonal architecture (Ports & Adapters) layout

**Status:** Draft
**Date:** 2026-05-01

## Context

`pg_vector_service` — JAR-модуль для Naumen SMP, реализующий три use case'а: scheduled-векторизация SMP-объектов через Yandex Cloud Foundation Models (UC1), similarity-поиск (UC2), кластерный анализ дублей (UC3). Сценарии описаны в [UC1](../../30-requirements/functional/uc1-scheduled-vectorization), [UC2](../../30-requirements/functional/uc2-similarity-search), [UC3](../../30-requirements/functional/uc3-duplicate-detection).

Модуль одновременно зависит от четырёх внешних подсистем: SMP API (чтение объектов, запись метаданных, scheduler), Yandex Cloud FM (REST + IAM), pgvector через SMP API (запись/поиск векторов), SMP scheduler (запуск джоб). Без архитектурной границы между ядром и адаптерами модуль превратится в god-object по образцу legacy `Вспомогательный модуль для векторизации.groovy` (см. baseline_groovy_vector_module в auto-memory): тестируется только on-stand, любая правка YC FM-клиента ломает всё.

Из NFR (`content/30-requirements/non-functional/nfr-cross-cutting.md`):

- **NFR-040** — нет JDBC-компонентов, БД только через SMP API.
- **NFR-041** — точка выхода в YC FM принимает только результат сборки whitelist-композита, без прямого доступа к произвольным атрибутам объекта (PII-инвариант).
- **NFR-044** — `@InjectApi` допустим только в `adapters/smp/` и `config/`. Доменное ядро тестируется без SMP-контекста.

CLAUDE.md фиксирует эталон: `/Users/mdemyanov/Devel/naumen-smp-mcp` — тот же стек (Groovy 3.0.21 / Java 21 / Maven), та же архитектура (см. `Devel/naumen-smp-mcp/content/00-project/adr/001-hexagonal-architecture.md`), та же CodeNarc-настройка и `CoreBoundarySpec` для статической проверки границ.

## Decision

Принимается **Hexagonal (Ports & Adapters)** layout, наследуемый из эталона `naumen-smp-mcp`. Структура исходников:

```
src/main/groovy/ru/naumen/modules/pg_vector_service/
├── core/                — чистый домен векторизации, similarity, кластеризации;
│                          не импортирует ru.naumen.* (кроме core/ports/spi)
├── ports/
│   ├── inbound/         — интерфейсы для входящих сценариев (SchedulerEntryPort,
│   │                      SimilaritySearchPort, DuplicateAuditPort)
│   └── outbound/        — интерфейсы наружу (SmpReadPort, VectorStoragePort,
│                          EmbeddingProviderPort, AuditLogPort)
├── adapters/
│   ├── smp/             — единственное место с @InjectApi:
│   │                      реализация SmpReadPort и VectorStoragePort через api.db.query
│   │                      и REST /find /edit /create
│   ├── yc/              — клиент Yandex Cloud Foundation Models (REST, IAM-token cache)
│   │                      реализует EmbeddingProviderPort
│   └── scheduler/       — обёртка scheduledTask, реализует SchedulerEntryPort
├── spi/                 — минимальный публичный контракт для tool-pack'ов и потребителей
│                          (если возникает потребность дать API наружу — отдельный ADR)
└── config/              — composition root: bootstrap модуля,
                           сборка core с конкретными адаптерами
```

**Правила границ** (защищаются архитектурным тестом `CoreBoundarySpec` по образцу эталона):

- `core/` импортирует только JDK, Groovy stdlib, `ports/`, `spi/`.
- `core/` не имеет ни одного `@InjectApi`, ни одного `import ru.naumen.core.*`.
- `@InjectApi` — только в `adapters/smp/` и `config/` (NFR-044).
- Любой outbound-вызов (SMP / YC FM / pgvector через SMP API) проходит через port, реализованный в соответствующем адаптере.
- Composition root (`config/`) — единственное место сборки графа объектов через constructor injection.

PII-инвариант (NFR-041) обеспечивается тем, что `EmbeddingProviderPort` принимает на вход уже собранный композитный текст (тип-контракт: `ComposedText` с указанием whitelist-версии), а не SMP-объект целиком. `core/` физически не имеет ссылок на `@InjectApi` и не может «обойти» whitelist.

## Consequences

**Positive:**

- TDD ядра без SMP: фейки портов (`InMemoryVectorStorage`, `FakeEmbeddingProvider`) позволяют покрыть всю логику UC1/UC2/UC3 unit-тестами; integration-проверка только в `adapters/`.
- Замена YC FM на другой embedding-провайдер (например, on-prem модель) — реализация нового адаптера в `adapters/`, ядро не трогается. То же — для замены SMP API-адаптера на mock-сервер при offline-evaluation (UC2 NFR-002).
- Изоляция SMP-зависимостей: апгрейд платформы (см. эталон, ADR-013) затрагивает только `adapters/smp/`.
- `CoreBoundarySpec` ловит нарушения boundary до code review — нет «случайных» утечек `@InjectApi` в core (как в legacy-модуле).
- PII-инвариант (NFR-041) превращается из «надо помнить» в «скомпилируется только так» — type-контракт `ComposedText` на границе порта.

**Negative:**

- Overhead на старте: каждый порт — отдельный интерфейс + реализация в адаптере + фейк для тестов. Для PoC из 3 use case'ов это ~7-8 интерфейсов, что больше «плоского» Groovy-модуля.
- Разработчики, привыкшие к SMP-стилю «всё в одном файле + `@InjectApi` где удобно» — требуют онбординга (есть в наличии: эталон + lessons-learned).

**Mitigations:**

- Раскладку наследовать дословно из эталона: `pom.xml`-структура, имена пакетов, `CoreBoundarySpec` — копируются 1:1 (см. `content/10-domain/research/reference-project-notes.md`). Не переизобретаем.
- Список портов фиксируется в архитектурной статье `content/40-architecture/components.md` на этапе SA-сессий по UC1/UC2/UC3.
- Number-of-files boilerplate компенсируется CodeNarc-порогами эталона (метод ≤20 строк, класс ≤200): структура остаётся читаемой.

## Alternatives Considered

- **Плоский Groovy-модуль без слоёв** (как legacy `Вспомогательный модуль для векторизации.groovy`): быстрее на первой итерации PoC, но провалит NFR-041 (нет физической границы между whitelist-сборщиком и YC FM-клиентом — текст любого атрибута может оказаться в payload-е). Не масштабируется на UC2/UC3, делает невозможным TDD ядра. Отвергнуто: ремонт стоимости позже превысит экономию на старте.
- **Classic 3-tier (presentation / business / data)**: предполагает UI-слой, которого у JAR-модуля SMP нет — сценарии вызываются из других модулей SMP или scheduledTask. Слой data в нашем случае — это `adapters/smp/` (доступ к pgvector через SMP API), что не соответствует классическому DAO-паттерну. Отвергнуто: модель неприменима к нашему контексту.
- **Onion architecture**: концептуально близка к Hexagonal, но без явных именованных портов — границы поддерживаются соглашениями. Отвергнуто: эталон уже использует Hexagonal, копировать `CoreBoundarySpec` проще, чем переизобретать onion-конвенции.

## Связанные статьи

- [UC1 — Scheduled vectorization](../../30-requirements/functional/uc1-scheduled-vectorization) — компоненты scheduler-entry / batch-processor / embedding-client / pgvector-writer ложатся на core + adapters.
- [UC2 — Similarity search](../../30-requirements/functional/uc2-similarity-search) — search use case в `core/`, ACL-фильтр (BR-002 `kbAccesses`) — в `adapters/smp/`.
- [UC3 — Duplicate detection](../../30-requirements/functional/uc3-duplicate-detection) — online-подсказка и batch-аудит в `core/`, ad-hoc embedding (если выберем по Q7) — через `EmbeddingProviderPort`.
- [Cross-cutting NFR](../../30-requirements/non-functional/nfr-cross-cutting) — NFR-040 (no JDBC), NFR-041 (PII-инвариант), NFR-044 (изоляция `@InjectApi`).
- [Reference project notes](../../10-domain/research/reference-project-notes) — раскладка эталона `naumen-smp-mcp`, копируем 1:1.
- Эталон: `Devel/naumen-smp-mcp/content/00-project/adr/001-hexagonal-architecture.md` (cross-каталожно — inline path).
- ADR-002 (SMP-only data access) — выводы для `adapters/smp/` и запрет JDBC в `core/`.
- ADR-009 (SPI-граница, эталон): `Devel/naumen-smp-mcp/content/00-project/adr/009-spi-package-boundary.md` — переиспользуем подход к `spi/`, когда возникнет публичный контракт.
