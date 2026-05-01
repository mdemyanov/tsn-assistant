---
order: 6
title: "Backlog проекта pg_vector_service"
properties:
  - Тип контента: Прочее
  - Фаза: PoC
  - Статус: Draft
---

# Backlog проекта pg_vector_service

Реестр задач PoC. Каждая задача имеет уникальный ID, привязку к фазе [roadmap'а](roadmap.md), статус и явные зависимости. PM (Opus) перетаскивает задачи в активный sprint и обновляет статусы по итогам каждой Dev-итерации.

**Префиксы ID:**
- `RES-XXX` — research
- `DEV-XXX` — реализация (`/dev`)
- `DEVOPS-XXX` — инфраструктура и smoke (`/devops`)
- `BA-XXX` — уточнение требований (`/ba`, преимущественно из BA open questions)
- `SA-XXX` — архитектурные решения / дополнительные ADR (`/sa`)
- `OWNER-XXX` — задачи owner'а (Демьянов) — внешние блокеры
- `PM-XXX` — координация / PM-review

**Статусы:** `todo` / `in-progress` / `done` / `blocked` / `deferred`.

## A. Внешние блокеры (Phase 0 pre-flight)

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| OWNER-001 | ✅ Phase 0.4 закрыто 2026-05-01. pgvector 0.8.1, схема `public`, single-tenant, сетевой доступ к YC FM — подтверждены. SMP DB-user = `llm2`. Канал доступа из JAR — Hibernate `sessionFactory` через Spring `beanFactory` (не `modules.localSql`). DDL исполняется bootstrap'ом модуля при первом старте JAR через `session.doWork(...)` — отдельное окно работ не нужно | — | [owner-questions/owner-001-pgvector-ddl.md](owner-questions/owner-001-pgvector-ddl.md), [runbooks/runbook-vector-table-migration.md](../70-operations/runbooks/runbook-vector-table-migration.md) | done | Phase 0 |
| OWNER-002 | ✅ Phase 0.5 done — `yc` CLI установлен, SA `pg-vector-poc` (`aje98ipgmpnhaun6ov6e`) с ролью `ai.languageModels.user` создан, API-Key выпущен в `.secrets/yc-api-key.json` (chmod 600, gitignored). Smoke-curl на embedding endpoint работает. Деплой ключа на `llm2` — отдельная задача DEVOPS-008 | — | `.secrets/yc-api-key.json`, `.env` (`YC_*`), [yc-foundation-models.md](../10-domain/research/yc-foundation-models.md) | done | Phase 0 |
| RES-002-closeout | ✅ Закрыт: `text-search-doc/latest` + `text-search-query/latest`, `dim=256`, modelVersion `06.12.2023`, endpoint `https://llm.api.cloud.yandex.net/foundationModels/v1/textEmbedding`. Решение зафиксировано в [ADR-010](adr/010-embedding-model-selection.md) | OWNER-002 | [yc-foundation-models.md](../10-domain/research/yc-foundation-models.md), [ADR-010](adr/010-embedding-model-selection.md) | done | Phase 0 |
| RES-003-pricing | ✅ Закрыт 2026-05-01. Прайс выгружен вручную owner'ом с `aistudio.yandex.ru`. Embedding: 0,0101 ₽ / 1 тыс. юнитов (плоский тариф для `text-search-doc/query`). Полная векторизация медианы 100k объектов ≈ 200 ₽. См. [yc-pricing.md](../10-domain/research/yc-pricing.md) | — | [yc-pricing.md](../10-domain/research/yc-pricing.md) | done | Phase 0 |
| RES-003 | ✅ Закрыт 2026-05-01 через [yc-pricing.md](../10-domain/research/yc-pricing.md). Калькулятор бюджета: медиана 100k × 200 токенов ≈ 200 ₽; верх 10M × 500 токенов ≈ 50 500 ₽. Embedding не является ограничителем PoC. LLM-валидация UC3 — доминирующая статья (16-66 тыс. ₽/100k валидаций), требует cap'а top-K | RES-003-pricing | [yc-pricing.md](../10-domain/research/yc-pricing.md) §Калькулятор | done | Phase 0 |
| OWNER-003 | ✅ Закрыт 2026-05-01. Решение owner'а: **single-схема per стенд** (для каждого стенда — своя БД/инстанс с одним тенантом). Multi-tenant изоляция в PoC не требуется. Влияние: ADR-004 — без discriminator-колонки tenant; OQ-UC1-1 / OA-3 закрыты | OWNER-001 | апдейт в [ADR-004](adr/004-vector-storage-schema.md) (требуется); фиксация в этом backlog'е | done | Phase 0 |
| OWNER-004 | ✅ Закрыт 2026-05-01. Решение owner'а: **IAM-token через JWT** (production-ready, не статический Api-Key). Влияние: DEV-021 `IamTokenCache` обязателен; новый `ADR-yc-auth` пишется `/sa` с фиксацией JWT-flow, TTL ≤ 11ч, refresh за 1ч | OWNER-002 | новый ADR `yc-auth` (`/sa` task) | done | Phase 0 |

## B. Архитектурные решения, требующие исполнения

> ADR 001-009 уже приняты ([adr/](adr/)). Этот раздел — задачи на запись недостающих ADR и DDL/runbook'и, без которых Dev не стартует.

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| SA-001 | ✅ Принят [ADR-010](adr/010-embedding-model-selection.md): `text-search-doc` (для UC1, UC2 obj→obj, UC3) + `text-search-query` (для UC2 free-text), `dim=256`, modelVersion `06.12.2023`, cosine, HNSW `m=16, ef_construction=64`. Закрывает frame [ADR-009](adr/009-embedding-model-decision-frame.md) | RES-002-closeout | [ADR-010](adr/010-embedding-model-selection.md) | done | Phase 0 / iter 1 |
| SA-002 | `ADR-XXX (pgvector index)` — HNSW vs IVFFlat (на ожидаемой медиане 100k–300k и headroom ≥ 1M) + параметры (`m`, `ef_construction`, `ef_search`), решение по `vector` vs `halfvec` (требует pgvector ≥ 0.7) | OWNER-001 (версия pgvector); OWNER-003 (single vs multi-tenant) | `content/00-project/adr/011-pgvector-index.md` | ready (OWNER-001 закрыт) | Phase 0 / iter 1 |
| SA-011 | **Апдейт [ADR-002](adr/002-smp-only-data-access.md)** — переформулировать «SMP-only data access» в терминах Hibernate `SessionFactory` через Spring `beanFactory.getBean("sessionFactory")` (ранее предполагалось через `api.db.query` SMP). Зафиксировать паттерны: (a) **script-as-binding-carrier** для проброса `beanFactory`+`api` в JAR — обёртка `HibernateSessionProvider` в `adapters/db/` по образцу `SmpSuperUserRunner` из эталона `naumen-smp-mcp/src/main/groovy/ru/naumen/modules/mcp/adapters/smp/SmpSuperUserRunner.groovy`; (b) `session.doWork` для DDL/JDBC-параметризации; (c) `createNativeQuery` для pgvector-операторов; (d) параметризация vector-аргумента через `CAST(:vec AS vector(N))`. Возможно — отдельный новый ADR `db-access-adapter` вместо апдейта (на усмотрение `/sa`) | OWNER-001 (закрыт) | апдейт [ADR-002](adr/002-smp-only-data-access.md) или новый ADR | todo | Phase 0 / iter 1 |
| SA-003 | `ADR-XXX (uc-api-contract)` — публичный SPI: запрос/ответ `SimilaritySearchService`, `DuplicateDetectionService`, формат ошибок без stack-traces (UC2 AC-14), коды ошибок «vector not ready» (UC2 AC-9). Привязан к §10 принципиальной архитектуры (ADR-014 в нумерации SA-документа) | — | `content/00-project/adr/012-uc-api-contract.md` | todo | iter 1 |
| SA-004 | `ADR-XXX (audit-log sink)` — где живёт журнал вызовов YC FM (NFR-003): отдельный FQN-объект SMP / лог-файл / внешний sink. Retention policy. Привязка к OA-8 | OWNER-001 (что разрешено DevOps) | `content/00-project/adr/013-audit-log-sink.md` | todo | iter 4 |
| SA-005 | `ADR-XXX (job-state)` — где хранится прогресс scheduled-джобы (NFR-022): атрибут `scheduledTask.subject` / отдельный FQN / state-файл. Cap времени работы (FR-016 UC1, OA-15) | OWNER-001 | `content/00-project/adr/014-job-state.md` | todo | iter 1-2 |
| SA-006 | `ADR-XXX (observability)` — стек метрик (NFR-050), формат структурированных логов (NFR-051), `correlationId`, реестр метрик расхода YC FM (NFR-060), алерт по дневному лимиту (NFR-061) | OWNER-001 (стек на `llm2`); RES-003 (дневной лимит) | `content/00-project/adr/015-observability.md` | todo | iter 1-4 |
| SA-007 | `ADR-XXX (platform-versioning)` — SemVer JAR + матрица совместимости с SMP-версиями. Адаптировать [эталонный ADR-013](file:///Users/mdemyanov/Devel/naumen-smp-mcp/content/00-project/adr/013-platform-versioning.md) под наш модуль | — | `content/00-project/adr/016-platform-versioning.md` | todo | iter 1 |
| SA-008 | `ADR-XXX (sync-vs-job-uc3-online)` — для UC3-A: ad-hoc embedding регистрируемой заявки vs lazy от UC1 (OA-12). Решается после первого замера latency YC FM на iter 1 | DEV-005 (есть реальные данные latency) | `content/00-project/adr/017-uc3-online-embedding.md` | todo | iter 3 |
| SA-009 | `ADR-XXX (job-locking + scheduling defaults)` — период / стратегия `from_start` vs `from_last_execution` / поведение при конфликте запусков (FR-015 UC1, FR-009/010 UC3) | SA-005 | `content/00-project/adr/018-job-scheduling.md` | todo | iter 1-2 |
| SA-010 | `ADR-XXX (batch-control)` — лимит на one-shot batch (NFR-062), required confirmation, дневной денежный лимит расхода (NFR-061) | RES-003 | `content/00-project/adr/019-batch-control.md` | todo | iter 1 / iter 4 |

## C. DevOps задачи

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| DEVOPS-001 | DDL вектор-таблицы по [ADR-004](adr/004-vector-storage-schema.md) + HNSW-индекс. Approved 2026-05-01: схема `public`, DB-user `llm2`, канал — Hibernate `sessionFactory`, способ — bootstrap модуля (вариант A). Тюнинг параметров индекса (ef_search) — в SA-002, не блокирует создание таблицы. **Реализация задачи переезжает в `/dev`:** код bootstrap'а — это часть DEV-030 `VectorModuleBootstrap` | [ADR-004](adr/004-vector-storage-schema.md), DEV-001 (каркас), DEV-030 (bootstrap) | [runbook-vector-table-migration.md](../70-operations/runbooks/runbook-vector-table-migration.md) §6.1 | ready | Phase 0 / iter 1 |
| DEVOPS-002 | Регистрация `scheduledTask` для UC1 на стенде `llm2`: код, период (manual trigger на старте по [SA-009](#b-архитектурные-решения-требующие-исполнения)), пользователь-исполнитель (OA-14) | DEV-001..007, SA-009 | runbook `register-uc1-scheduled-task.md` | todo | iter 1 |
| DEVOPS-003 | Smoke-инфраструктура на `llm2`: команда деплоя JAR через `smps`, шаблон smoke-report (по образцу `Devel/naumen-smp-mcp/content/70-operations/smoke-reports/2026-04-23-llm2-m33.md`), процедура rollback | OWNER-001 | `content/70-operations/runbooks/smoke-procedure.md`; шаблон `smoke-reports/_template.md` | todo | iter 1 |
| DEVOPS-004 | Реализовать сбор метрик и логов по [SA-006](#b-архитектурные-решения-требующие-исполнения) (NFR-050/051/052): получить `correlationId` сквозной, поднять приёмник для метрики «расход YC FM в токенах за сутки» | SA-006 | runbook + dashboard (TBD стек) | todo | iter 2-4 |
| DEVOPS-005 | Алерт по дневному бюджету YC FM (NFR-061): источник — метрика из DEVOPS-004; канал — Telegram / email owner'у (зависит от стека). Проиграть alert-шторм на стенде | DEVOPS-004, RES-003, SA-010 | runbook `alert-yc-fm-budget.md` | todo | iter 4 / closeout |
| DEVOPS-006 | Регистрация `scheduledTask` для UC3-batch (FR-009 UC3) с недельной периодичностью | DEV-011, SA-009 | runbook `register-uc3-audit-task.md` | todo | iter 4 |
| DEVOPS-007 | Migration-runbook при смене embedding-модели по [ADR-007](adr/007-model-versioning-migration.md): процедура DROP+CREATE INDEX под новый `dim`, blue-green с двумя таблицами как опция, окно работ, откат | [ADR-007](adr/007-model-versioning-migration.md), DEVOPS-001 | `content/70-operations/runbooks/runbook-model-migration.md` | todo | iter 4 / MVP |
| DEVOPS-008 | Secret rotation `sa-key.json` (NFR-005): процедура замены без перезапуска модуля, проверка обновления IAM-token-cache | OWNER-002, OWNER-004 | `content/70-operations/runbooks/runbook-secret-rotation.md` | todo | iter 1 / closeout |

## D. Dev задачи (по слоям hexagonal layout)

> Порядок исполнения соответствует §12 принципиальной архитектуры (fixtures → core → ports → adapters → integration tests → smoke). На итерациях PoC задачи `DEV-001..017` идут параллельно в пределах слоя.

### D.1. Каркас и тестовая инфраструктура

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| DEV-001 | Каркас модуля по hexagonal layout ([ADR-001](adr/001-hexagonal-architecture.md)): `pom.xml` (Maven mirror Naumen), `src/main/groovy/ru/naumen/modules/pgvector/{core,ports,adapters,config,spi}/`, `src/test/groovy/`, базовые SLF4J-зависимости. Сборка `JAVA_HOME=/opt/homebrew/opt/openjdk@21 mvn clean compile` зелёная | SA-007 | `pom.xml`, дерево пакетов; commit на `private` | todo | iter 1 |
| DEV-002 | CodeNarc + jar-secrets-scan по образцу эталона `/Users/mdemyanov/Devel/naumen-smp-mcp` ([reference-project-notes.md](../10-domain/research/reference-project-notes.md)): запрет `String.execute()`, изоляция `@InjectApi`, запрет JDBC-зависимостей в `core/`, запрет интерполяции в HQL (NFR-043). `mvn verify` зелёный | DEV-001 | `codenarc/`, апдейт `pom.xml`; CodeNarc-rules-файл | todo | iter 1 |
| DEV-003 | Архитектурный тест `CoreBoundarySpec`: запрет `ru.naumen.*` в `core/` (кроме `core.*`/`ports.*`); запрет `java.sql.*`/`org.postgresql.*` повсюду кроме `adapters/smp/` (NFR-006/044, [ADR-001](adr/001-hexagonal-architecture.md), [ADR-002](adr/002-smp-only-data-access.md)) | DEV-001 | `src/test/groovy/.../arch/CoreBoundarySpec.groovy` | todo | iter 1 |
| DEV-004 | Тест `JdbcImportBanSpec`: scan `pom.xml` + `target/<jar>.jar` на отсутствие `org.postgresql.*` транзитивных зависимостей (UC1 AC-013) | DEV-001 | `src/test/groovy/.../arch/JdbcImportBanSpec.groovy` | todo | iter 1 |
| DEV-005 | Test-fixtures: fake `EmbeddingProvider` (детерминированные векторы по hash от текста); fake `VectorStore` (in-memory KNN); fake `SmpRepository` с фикстурами из [smp-metamodel.md](../10-domain/research/smp-metamodel.md) | DEV-001 | `src/test/groovy/.../fixtures/` | todo | iter 1 |

### D.2. Ports и core domain

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| DEV-006 | Inbound/outbound ports: `VectorizationJob`, `SimilaritySearchService`, `DuplicateDetectionService`, `DuplicateAuditJob`; `SmpRepository`, `VectorStore`, `EmbeddingProvider`, `AuditLogger`, `MetricsCollector`, `KbAccessChecker`, `TenantContextProvider`, `ClockProvider`. Чистые интерфейсы + javadoc + контрактные тесты | DEV-001 | `src/main/groovy/.../ports/`, `src/test/groovy/.../ports/contracts/` | todo | iter 1 |
| DEV-007 | `core/model/`: value-objects `EmbeddingModelDescriptor`, `WhitelistVersion`, `VectorRecord`, `IdempotencyKey`-вычислитель (sha256 от composite-text + modelVersion + whitelistVersion, NFR-020) | DEV-006 | `src/main/groovy/.../core/model/`, юнит-тесты | todo | iter 1 |
| DEV-008 | `WhitelistEnforcer` — гард PII-инварианта ([ADR-005](adr/005-whitelist-pii-default-deny.md)): фильтрует исходящие атрибуты по версии whitelist, default-deny. Юнит-тесты на UC1 BR-005 (атрибуты вне whitelist не покидают enforcer) | DEV-007 | `core/vectorization/WhitelistEnforcer.groovy` + tests | todo | iter 1 |
| DEV-009 | Whitelist-конфиг: формат хранения per-class whitelist'а ([ADR-005](adr/005-whitelist-pii-default-deny.md)) — resource в JAR + версия в `pom.xml` (по дефолту); поддержка PII-уровней low/medium/high + `includedFromVersion` | DEV-008 | `config/whitelist-v1.yaml` + loader | todo | iter 1 |
| DEV-010 | `CompositeTextComposer` ([ADR-006](adr/006-composite-text-composition.md)): конкатенация в фиксированном порядке, нормализация richtext (HTML → plain), пропуск null/пустых, разделитель из ADR. Юнит-тесты + детерминированность (повтор → тот же hash) | DEV-008 | `core/vectorization/CompositeTextComposer.groovy` + tests | todo | iter 1 |
| DEV-011 | `ChunkingStrategy` + `ChunkAggregator` ([ADR-006](adr/006-composite-text-composition.md)): окно + overlap; baseline-агрегация — mean-pooling. Юнит-тесты на длинные тексты | DEV-010 | `core/vectorization/Chunking*.groovy` + tests | todo | iter 1 |
| DEV-012 | `EmbeddingPayloadBuilder`: формирует payload для YC FM (только whitelisted-текст, отсечение PII окончательно перед отправкой). Юнит-тест: payload не содержит ни одного атрибута вне whitelist | DEV-010 | `core/vectorization/EmbeddingPayloadBuilder.groovy` + tests | todo | iter 1 |
| DEV-013 | `core/search/`: `QueryOrchestrator`, `WorkflowStatusFilter`, `SourceExclusion`, `TopKRanker`. Юнит-тесты с fake `VectorStore` + `KbAccessChecker` | DEV-006 | `core/search/` + tests | todo | iter 1 |
| DEV-014 | `core/duplicates/`: `ThresholdClassifier` (cosine; пороги Дубль ≥ 0.92 / Похожая 0.85..0.92 — параметризовать, [ADR-008](adr/008-near-duplicate-algorithm.md)), `DuplicateGroupComposer` (pairwise + транзитивное замыкание), `KnownGroupMarker`. Юнит-тесты | DEV-006 | `core/duplicates/` + tests | todo | iter 3 (online); iter 4 (batch) |

### D.3. Adapters

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| DEV-015 | `adapters/smp/SmpRepositoryAdapter`: HQL read целевых FQN с `setParameter` (NFR-043), пагинация, фильтр по `vector_dirty` или `modelVersion` mismatch (FR-007 UC1) | DEV-006 | + integration test против fake SMP | todo | iter 1 |
| DEV-016 | `adapters/db/VectorStoreHibernateAdapter` (переименован с `SmpAdapter`): read/write/search вектор-таблицы через Hibernate `sessionFactory` ([ADR-002](adr/002-smp-only-data-access.md) — апдейт после OWNER-001) + `vector(256)`-типизация ([ADR-004](adr/004-vector-storage-schema.md)). Параметризация vector-аргумента через `setParameter('vec', '[...]')` + `CAST(:vec AS vector(256))`. Атомарная запись `(VectorRecord, modelVersion, whitelistVersion, dirty=false)` в Hibernate-транзакции (NFR-UC1-004). Integration-тесты — на стенде `llm2` или через testcontainers с pgvector | DEV-001, DEV-030 (bootstrap), [ADR-004](adr/004-vector-storage-schema.md), SA-002 | + integration test | ready | iter 1 |
| DEV-017 | `adapters/smp/KbAccessSmpAdapter`: проверка `kbAccesses` под пользователем (BR-002 UC2). Поддержка двух режимов: pre-filter в HQL и post-filter с oversample (OA-13, [SA-003](#b-архитектурные-решения-требующие-исполнения)) | DEV-006 | + integration test | todo | iter 1 |
| DEV-018 | `adapters/smp/DirtyTrackingAdapter`: реализация по выбранной в [ADR-005](adr/005-whitelist-pii-default-deny.md)/SA-005 стратегии — атрибут SMP / staging-таблица / mtime | SA-005 | + tests | blocked | iter 1 |
| DEV-019 | `adapters/yc/YcEmbeddingProviderAdapter` mock-mode: реализует `EmbeddingProvider`, но не вызывает YC FM — генерирует детерминированные эмбеддинги. Нужен для разблокировки DEV-001..014 до закрытия RES-002-closeout | DEV-006 | `adapters/yc/MockYcEmbeddingAdapter.groovy` | todo | iter 1 (старт) |
| DEV-020 | `adapters/yc/YcEmbeddingProviderAdapter` real-mode: REST-клиент `POST /foundationModels/v1/textEmbedding`, обработка 429/5xx, лимит retry (NFR-021) | OWNER-002, RES-002-closeout, SA-001 | + integration test против YC | blocked | iter 1 |
| DEV-021 | `adapters/yc/IamTokenCache`: кеш IAM-токена с TTL ≤ 11ч, refresh за 1ч до истечения (NFR-005) | OWNER-002, OWNER-004 | + tests на mock-clock | todo | iter 1 |
| DEV-022 | `adapters/yc/RateLimitedHttpClient`: экспоненциальный backoff с jitter на 429/5xx, лимит попыток из конфига (NFR-021) | DEV-006 | + tests | todo | iter 1 |
| DEV-023 | `adapters/scheduler/ApiSchedulerEntry`: Groovy-обвязка `api.scheduler` для UC1 (`VectorizationJob`) и UC3-batch (`DuplicateAuditJob`) по [ADR-003](adr/003-job-based-vectorization.md) и SA-009 | SA-009 | + integration test (smoke) | todo | iter 1 (UC1); iter 4 (UC3) |
| DEV-024 | `adapters/smp/AuditLogSmpAdapter`: sink аудит-лога (NFR-003) по выбранному в SA-004 sink'у (FQN-объект SMP / лог-файл) | SA-004 | + tests | blocked | iter 4 |

### D.4. Оркестрация и сборка

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| DEV-025 | `VectorizationOrchestrator` (impl `VectorizationJob`): управление батчами, lock, transaction-границы, прогресс. Идемпотентность по `compositeHash` ([ADR-005](adr/005-whitelist-pii-default-deny.md)/SA-005). Покрытие AC-004/006/008/011 UC1 | DEV-008..018 | `core/vectorization/VectorizationOrchestrator.groovy` + integration tests | todo | iter 1 |
| DEV-026 | `JobLauncher`: lock через `api.scheduler.getStatus`, time-cap (FR-016 UC1, OA-15), восстановление прерванной джобы (NFR-022) | SA-005, DEV-023 | + tests | todo | iter 1-2 |
| DEV-027 | `QueryOrchestrator` (impl `SimilaritySearchService`): план запроса, формирование query-вектора (по объекту / free-text), вызов `VectorStore.search`, применение `WorkflowStatusFilter` + `KbAccessChecker` + `SourceExclusion`, ранжирование. Покрытие UC2 AC-1..AC-9 | DEV-013, DEV-016, DEV-017, DEV-019/020 | + integration tests | todo | iter 1 |
| DEV-028 | `DuplicateDetector` (impl `DuplicateDetectionService`): UC3-online cosine-threshold (двойной порог, ACL-фильтр, self-match exclusion). Timeout-watcher (NFR-001 UC3 = 2с) с silent-skip. Покрытие UC3 AC-001..005 | DEV-014, DEV-027, SA-008 | + integration tests | todo | iter 3 |
| DEV-029 | `DuplicateAudit` (impl `DuplicateAuditJob`): batch-проход по корпусу за окно (FR-010 UC3), pairwise-группировка, `KnownGroupMarker` через `issue.duplicates`, формирование `DuplicateAuditReport`. Покрытие UC3 AC-006..010 | DEV-014, DEV-016, DEV-023, SA-004 (audit-log) | + integration tests | todo | iter 4 |
| DEV-030 | `config/VectorModuleBootstrap`: DI-сборка, загрузка whitelist-конфига, инициализация `EmbeddingModelDescriptor`, регистрация `scheduledTask` точек входа | все DEV-006..029 | `config/VectorModuleBootstrap.groovy` | todo | iter 1 |
| DEV-031 | Migration-логика при смене embedding-модели ([ADR-007](adr/007-model-versioning-migration.md)): trigger на `EmbeddingModelVersionChanged`, массовая инвалидация `dirty=true`, поведение при non-compat dim. Юнит-тест: смена `modelUri` → все векторы помечены stale | DEV-007, DEV-025 | + tests | todo | iter 4 / MVP |
| DEV-032 | Минимальный публичный SPI ([ADR-001](adr/001-hexagonal-architecture.md) §3, [SA-007](#b-архитектурные-решения-требующие-исполнения)): `SimilaritySearchSpi` для внешних SMP-модулей. Документация интерфейса. Контрактный тест | SA-003, SA-007, DEV-027 | `spi/SimilaritySearchSpi.groovy` + контрактный тест | todo | iter 1 / MVP |

### D.5. Offline-evaluation

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| DEV-033 | Offline-eval скрипт UC2 по методологии [similarity-eval.md](../10-domain/research/similarity-eval.md) §5: ground truth из `issue.duplicates`/`duplicatesRL`+`problem.issues`, расчёт Recall@10, MRR@10. Воспроизводимый прогон через `EmbeddingProvider` + `VectorStore` | DEV-027 | `src/test/groovy/.../eval/Uc2OfflineEvalSpec.groovy` или standalone-script + report-template | todo | iter 1 (черновой) / closeout (финал) |
| DEV-034 | Offline-eval скрипт UC3 по [clustering-algos.md](../10-domain/research/clustering-algos.md) + [similarity-eval.md](../10-domain/research/similarity-eval.md): сетка порогов `T ∈ {0.80,0.85,0.90,0.92,0.95}`, расчёт Precision@T / Recall@T (FR-016 UC3) | DEV-028 | `eval/Uc3OfflineEvalSpec.groovy` + report-template | todo | iter 3 (черновой) / closeout (финал) |

## E. BA — открытые вопросы из требований

> Уточнения требований / sign-off'ы owner'а. Каждый BA-* — отражение OQ из BA-артефактов или из принципиальной архитектуры.

| ID | Источник | Вопрос | Ответственный | Статус | Фаза |
|----|----------|--------|---------------|:------:|------|
| BA-001 | UC1 OQ-UC1-2 | Расписание UC1 по умолчанию: ежедневно ночью / каждые N часов / ручной запуск до отладки. Решение → SA-009 | Owner | todo | iter 1 |
| BA-002 | UC1 OQ-UC1-3 | Кому и как уходит алерт `VectorJobAborted` (FR-013 UC1)? Email / Telegram / SMP-уведомление | Owner | todo | iter 1 |
| BA-003 | UC1 OQ-UC1-6 | NFR-UC1-003 «не деградировать стенд» — что измеряем (latency p95 SMP API?) и какой порог | Owner / DevOps | todo | iter 1-2 |
| BA-004 | UC1 OQ-UC1-7 | Подтвердить очерёдность подключения классов: `kb` → `problem` → `issue` (или параллельно `kb` + `problem`) | Owner | todo | iter 1 |
| BA-005 | UC1 OQ-UC1-8 | Sign-off whitelist'а атрибутов `issue` medium-PII — после какого условия включаем `description`/`lastComment`/`feedback`? Формальный процесс PII-аудита | Owner + юр. аудит (если нужен) | todo | MVP |
| BA-006 | UC1 OQ-UC1-10 | Допустим ли cap времени работы UC1 (FR-016)? Альтернатива — без cap'а с правом ручного `interruptJob`. Решение → SA-005 | Owner | todo | iter 2 |
| BA-007 | UC1 OQ-UC1-11 | Нормализация richtext (HTML → plain) — до или после расчёта токенов? Решение → [ADR-006](adr/006-composite-text-composition.md) (если открыт) или follow-up | SA | todo | iter 1 |
| BA-008 | UC1 OQ-UC1-12 | Размер батча по умолчанию (FR-011) — стартовый ориентир. Зависит от RPS-квоты YC FM | SA + DevOps (после RES-002-closeout) | blocked | iter 1 |
| BA-009 | UC2 Q3 | Бинарная или градированная (`rel ∈ {0,1,2}`) разметка ground truth для evaluation | BA + SA → апдейт ADR-009 | todo | iter 1 |
| BA-010 | UC2 Q4 | Финальные пороги Recall@10 / MRR@10 / latency p95 для GO/NO-GO PoC. Черновые — NFR-002 / NFR-001; финальные — после offline-eval | SA + Owner (closeout) | todo | closeout |
| BA-011 | UC2 Q6 | Включать ли cross-domain similarity (`issue → knowledgeBase`) в метрики качества PoC или вынести в отдельный milestone | BA + SA | todo | iter 2 |
| BA-012 | UC2 Q7 | Как UC2 работает с подклассами: фильтр `targetClasses=[issue]` включает все подклассы `issue$*` или только сам `issue` | BA + SA → апдейт SA-003 | todo | iter 1 |
| BA-013 | UC2 Q8 | Допустим ли «холодный» запуск UC2 без полного первого прогона UC1 (часть объектов без векторов)? Как UC2 деградирует | BA + DevOps | todo | iter 1 |
| BA-014 | UC2 Q9 | Аутентификация / авторизация UC2 на стыке с SMP — какой контекст пользователя пробрасывается для проверки `kbAccesses` | SA → SA-003 | todo | iter 1 |
| BA-015 | UC2 Q10 | Нужна ли возможность пакетного запроса UC2 (массив источников за один вызов) для джобы аналитика (Journey-3 UC2) | BA + SA | todo | iter 1 / MVP |
| BA-016 | UC2 Q11 | Хранение и обновление test-set'а evaluation: фикстура в репо или регенерация из снапшота SMP | SA + DevOps | todo | iter 1 |
| BA-017 | UC3 Q3 | Окно объектов для batch-аудита (всё / последние N месяцев / по подклассу `issue`) | BA + SA | todo | iter 4 |
| BA-018 | UC3 Q4 | Частота batch-джобы (еженедельно / ежедневно / по запросу аналитика) | BA (после первого прогона на стенде) | todo | iter 4 / closeout |
| BA-019 | UC3 Q5 | Допустимо ли показывать оператору уровень `Похожая` (порог 0.85), или оставить только `Дубль` (≥ 0.92) для PoC | Owner | todo | iter 3 |
| BA-020 | UC3 Q6 | Для `problem` объёмы существенно меньше — нужна ли отдельная конфигурация / отдельные пороги | BA + SA | todo | iter 4 |
| BA-021 | UC3 Q8 | Формат и канал доставки отчёта batch-аудита (KB-статья / шара / письмо аналитику) | BA + аналитик качества | todo | iter 4 |
| BA-022 | UC3 Q9 | Доля заявок с проставленным `duplicates`/`duplicatesRL` на стенде `llm2` — достаточно ли для precision/recall на 95% доверии. Может ослабить уверенность в AC-001/AC-002 | Researcher (RES-001 апдейт) | todo | iter 3 |
| BA-023 | UC3 Q10 | Нужен ли отдельный режим «high-precision only» (порог ≥ 0.95) для CSI-критичных подклассов `issue` | Owner | todo | MVP |
| BA-024 | NFR OQ-9 | Кто исполнитель `scheduledTask` в SMP (системный пользователь / суперпользователь) и какие у него права на чтение PII-атрибутов. Решение → SA-005 | Сахабетдинов / Киселёва | todo | iter 1 |

## F. PM координация

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| PM-001 | `/pm-review` всех BA/SA артефактов перед merge `private → public`: проверка обязательных properties в frontmatter, валидация JTBD/AC, NFR mapping в принципиальной архитектуре, отсутствие секретов / PII в текстах | BA + SA артефакты готовы | issue/PR с чек-листом | todo | iter 1 / каждая итерация |
| PM-002 | Координация Phase 0 unblockers: следить за OWNER-001/002/003/004, эскалация при простое > 5 рабочих дней | — | weekly status update в issue | in-progress | Phase 0 |
| PM-003 | Roadmap snapshot: еженедельный апдейт колонки «Статус» в [roadmap.md](roadmap.md) и в этом backlog'е | DEV / DevOps итерации | апдейт `roadmap.md` + `backlog.md` | recurring | вся PoC |
| PM-004 | PoC closeout report по итогам iter 4: сводный отчёт по всем UC1/UC2/UC3 AC + NFR-001..062, итоговые пороги, recall/precision/latency, расход YC FM, GO/NO-GO решение owner'а | iter 4 завершена; DEV-033/034 запущены | `content/70-operations/poc-closeout-report.md` | todo | closeout |
| PM-005 | После closeout — обновление [CLAUDE.md](../../CLAUDE.md) План запуска (раздел Phase 4+) с фактом и ссылкой на closeout-отчёт | PM-004 | апдейт `CLAUDE.md` | todo | closeout |
| PM-006 | После каждой Dev-итерации — `superpowers:verification-before-completion` skill: запуск `mvn verify`, smoke-report on `llm2`, обновление [smoke-reports/](../70-operations/) перед закрытием задачи | каждая итерация | smoke-reports | recurring | вся PoC |
| PM-007 | Обновление `docs/lessons-learned.md` после каждой итерации (append-only журнал): что узнали о YC FM, pgvector на `llm2`, паттернах SMP scheduler, поведении модели | каждая итерация | `docs/lessons-learned.md` | recurring | вся PoC |

## G. Зависимости critical path (от старта до конца PoC)

Цепочка задач от текущего состояния до GO/NO-GO PoC. Пропуск любой ступени останавливает следующую.

```
OWNER-001 ──► DEVOPS-001 ──┐
              SA-002 ──────┤
                            ├──► DEV-016 (VectorStoreSmpAdapter) ──┐
OWNER-002 ──► RES-002-closeout ──► SA-001 ──► DEV-020 ─────────────┤
              RES-003 ─────► SA-010                                 │
              OWNER-004 ──► DEV-021 (IAM) ────────────────────────►├──► PoC iter 1 (UC1+UC2 на KB)
                                                                    │       │
DEV-001..015, DEV-017..019, DEV-022..023 ──────────────────────────►┤       ▼
                                                                            DEV-033 (offline-eval iter 1)
                                                                            │
                                                                            ▼
                                                                    PoC iter 2 (+ problem)
                                                                            │
                                                                            ▼
                                                                    PoC iter 3 (+ issue + UC3 online)
                                                                       │       │
                                                                       │       ▼
                                                                       │   DEV-028, DEV-034
                                                                       ▼
                                                                  PoC iter 4 (UC3 batch + audit)
                                                                       │
                                                                       ├─► DEV-029, DEV-024, DEVOPS-006
                                                                       ▼
                                                                  PoC closeout (PM-004)
                                                                       │
                                                                       ▼
                                                                  GO/NO-GO MVP
```

**Минимальный набор для запуска первой Dev-итерации (PoC iter 1):**

1. OWNER-001, OWNER-002 — закрыты Демьяновым / Сахабетдиновым.
2. RES-002-closeout — заполнено после OWNER-002.
3. SA-001 (`ADR-XXX concrete model`), SA-002 (`ADR-XXX pgvector index`) — приняты.
4. DEVOPS-001 (DDL вектор-таблицы) — выполнен на `llm2`.
5. DEV-001..006 (каркас + ports + fixtures) — закрыты.
6. DEV-019 (mock embedding-adapter) — позволяет идти параллельно DEV-007..014 / DEV-027.

После этого запускается `/dev iter 1` со всем core + `VectorStoreSmpAdapter` + real-mode `EmbeddingProvider`.

## H. Связанные артефакты

- [Roadmap](roadmap.md)
- [Стейкхолдеры](stakeholders.md)
- BA — [UC1](../30-requirements/functional/uc1-scheduled-vectorization.md), [UC2](../30-requirements/functional/uc2-similarity-search.md), [UC3](../30-requirements/functional/uc3-duplicate-detection.md), [NFR](../30-requirements/non-functional/nfr-cross-cutting.md)
- SA — [принципиальная архитектура](../40-architecture/principal-architecture.md), [adr/](adr/) (001-009 приняты; 010-019 в этом backlog'е как SA-001..010)
- Research — [sources](../10-domain/research/sources.md), [SMP metamodel](../10-domain/research/smp-metamodel.md), [YC Foundation Models](../10-domain/research/yc-foundation-models.md), [pgvector indexes](../10-domain/research/pgvector-indexes.md), [similarity evaluation](../10-domain/research/similarity-eval.md), [clustering algos](../10-domain/research/clustering-algos.md), [SMP scheduled jobs](../10-domain/research/smp-scheduled-jobs.md), [reference project notes](../10-domain/research/reference-project-notes.md)
