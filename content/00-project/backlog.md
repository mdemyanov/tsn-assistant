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

> **Обновление 2026-05-02 (после волн BA-002 / BA-003 / BA-004 / BA-004.1):** каталог UC расширен с 3 до 9 (UC-V*/UC-S*/UC-C*); 3 исходных UC (UC1/UC2/UC3) помечены `[SUPERSEDED]`. Большинство BA-001..BA-024 закрыто owner-decisions из BA-004 — отмечено `Resolved (BA-004)` с traceability на конкретные OQ. Добавлены задачи BA-005 (FAQ-class), SA-021/022/023 (comment-storage + yc-auth + preprocessing ADR), DEVOPS-009/010 (rate-limiter, Prometheus), DEV-040..043 (UC-V2/S2/S3/C2 реализация), RES-010/011 (распределение комментариев + YC FM batch API), OWNER-005/006 (системный пользователь, excluded comment metaClasses).

**Префиксы ID:**
- `RES-XXX` — research
- `DEV-XXX` — реализация (`/dev`)
- `DEVOPS-XXX` — инфраструктура и smoke (`/devops`)
- `BA-XXX` — уточнение требований (`/ba`)
- `SA-XXX` — архитектурные решения / дополнительные ADR (`/sa`)
- `OWNER-XXX` — задачи owner'а (Демьянов / Сахабетдинов / Сазонова / Киселёва) — внешние блокеры
- `PM-XXX` — координация / PM-review

**Статусы:** `todo` / `ready` / `in-progress` / `done` / `blocked` / `deferred` / `resolved`.

## A. Внешние блокеры (Phase 0 pre-flight + волна BA-004)

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| OWNER-001 | ✅ Phase 0.4. pgvector 0.8.1, схема `public`, single-tenant, сетевой доступ к YC FM. SMP DB-user = `llm2`. Канал доступа — Hibernate `sessionFactory` через Spring `beanFactory`. DDL — bootstrap'ом модуля при первом старте JAR через `session.doWork(...)` | — | [owner-questions/owner-001-pgvector-ddl.md](owner-questions/owner-001-pgvector-ddl.md), [runbooks/runbook-vector-table-migration.md](../70-operations/runbooks/runbook-vector-table-migration.md) | done | Phase 0 |
| OWNER-002 | ✅ Phase 0.5. `yc` CLI установлен, SA `pg-vector-poc` (`aje98ipgmpnhaun6ov6e`) с ролью `ai.languageModels.user`, API-Key выпущен. Деплой ключа на `llm2` — DEVOPS-008 | — | `.secrets/yc-api-key.json`, `.env` (`YC_*`), [yc-foundation-models.md](../10-domain/research/yc-foundation-models.md) | done | Phase 0 |
| OWNER-003 | ✅ Закрыт 2026-05-01. Single-схема per стенд (один тенант на инстанс БД). Multi-tenant изоляция в PoC не нужна. Влияние: ADR-004 — без discriminator-колонки tenant | OWNER-001 | апдейт [ADR-004](adr/004-vector-storage-schema.md) (требуется); фиксация в этом backlog'е | done | Phase 0 |
| OWNER-004 | ✅ Закрыт 2026-05-01. IAM-token через JWT. Влияние: DEV-021 `IamTokenCache` обязателен; новый `ADR-yc-auth` (SA-022) | OWNER-002 | новый ADR `yc-auth` (`/sa` task SA-022) | done | Phase 0 |
| **OWNER-005** ⚠️ | **Открыт.** Системный пользователь scheduledTask на стенде `llm2` + права на чтение whitelist-атрибутов (low+medium PII по issue/KB). Источник: OQ-V1-6, OQ-9 NFR. Способ: запрос Сахабетдинову / Киселёвой о пресете (логин / FQN / role binding). Без него джоба UC-V1 не сможет читать issue.description / decisionReport под правильным контекстом | — | issue / wiki / Telegram-ping; зафиксировать пресет в `whitelist-config v2` | **in-progress** (PM-008) | Phase 0 / iter 1 |
| **OWNER-006** ⚠️ | **Открыт.** Точный список `excluded_comment_meta_classes` на стенде `llm2` (системные/аудитные подклассы `comment` — например, `commentprivate`, `commentaudit`, etc.). Источник: OQ-V2-2, NFR-075. Способ: MCP `metamodel_export_class comment` + анализ подклассов либо прямой запрос Сахабетдинову. Без него UC-V2 фильтрация и UC-S2 Variant B неполны | OWNER-001 | issue / wiki + `whitelist-comment-exclusions.yaml` | **in-progress** (PM-008) | Phase 0 / iter 3 |
| RES-002-closeout | ✅ Закрыт. `text-search-doc/latest` + `text-search-query/latest`, `dim=256`, modelVersion `06.12.2023`, endpoint `https://llm.api.cloud.yandex.net/foundationModels/v1/textEmbedding`. ADR-010 принят | OWNER-002 | [yc-foundation-models.md](../10-domain/research/yc-foundation-models.md), [ADR-010](adr/010-embedding-model-selection.md) | done | Phase 0 |
| RES-003-pricing / RES-003 | ✅ Закрыт 2026-05-01. Embedding 0,0101 ₽ / 1k юнитов; медиана 100k ≈ 200 ₽; верх 10M ≈ 50 500 ₽. Бюджет PoC = 1 000 ₽/сутки (OQ-V1-1) | — | [yc-pricing.md](../10-domain/research/yc-pricing.md) | done | Phase 0 |
| RES-009.1 | ✅ Закрыт 2026-05-01. Domain & data analysis на корпусе llm2: 6 259 issue / 32 298 comment / 113 KB. Рекомендация — стратегия D (hybrid) | OWNER-001, OWNER-002, RES-002-closeout | [vector-storage-domain.md](../10-domain/research/vector-storage-domain.md), `length-distribution.csv` | done | Phase 0 / iter 1 |
| RES-009.2 | ✅ Закрыт 2026-05-01. Сравнение стратегий A-E + закрытие OQ-1..10 из RES-009.1 + рекомендация D | RES-009.1 | [vector-storage-strategies.md](../10-domain/research/vector-storage-strategies.md) | done | Phase 0 / iter 1 |
| RES-009.3 | API-контракт модуля + DDL-скелет + поэтапная рекомендация. Может быть консолидирован с SA-021 (comment-storage-architecture) и SA-003 (uc-api-contract) — на усмотрение `/sa` | RES-009.2 | `content/10-domain/research/vector-storage-strategy.md` (финал) или включение в SA-003/SA-021 | deferred (consolidated into SA-003/SA-021) | iter 1 |
| **RES-010** | **NEW.** Анализ распределения числа комментариев на issue/problem на стенде `llm2` (max, p95, p99, mean). Цель: пересмотр default `comment_cap=50` (NFR-074). Метод: HQL-запросы через MCP `naumen-smp-dev-admin` или `issue_query_stats`. Артефакт: `content/10-domain/research/comment-count-distribution.md`. Источник: BA-004 / NFR-074 | OWNER-001 | `content/10-domain/research/comment-count-distribution.md` | todo | iter 3 |
| **RES-011** | **NEW.** YC FM batch/async API для embeddings: проверка наличия, лимитов, применимость к bulk-init. Дополнение к RES-002 (OQ-5 NFR → In Research). Источник: BA-004.1. Артефакт: `content/10-domain/research/yc-fm-batch-api.md`. Если найдено и применимо — может ускорить bulk-init MVP/Pilot (полный пересчёт ≤ 6 ч в ночное окно — OQ-2 NFR) | OWNER-002 | `content/10-domain/research/yc-fm-batch-api.md` | todo | iter 4 / MVP |

## B. Архитектурные решения, требующие исполнения

> ADR 001-010 уже приняты ([adr/](adr/)). Этот раздел — задачи на запись недостающих ADR и DDL/runbook'и, без которых Dev не стартует. Обновлено по результатам owner-decisions BA-004 / BA-004.1.

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| SA-001 | ✅ Принят [ADR-010](adr/010-embedding-model-selection.md): `text-search-doc` + `text-search-query`, `dim=256`, modelVersion `06.12.2023`, cosine, HNSW `m=16, ef_construction=64`. Закрывает frame [ADR-009](adr/009-embedding-model-decision-frame.md) | RES-002-closeout | [ADR-010](adr/010-embedding-model-selection.md) | done | Phase 0 / iter 1 |
| SA-002 | `ADR-pgvector-index` — HNSW vs IVFFlat на медиане 100k–300k и headroom ≥ 1M. **Обновление BA-004.1 / OQ-1 (2026-05-02): индекс должен быть disk-resident** (PostgreSQL общий на стенде llm2, память не перегружать; NFR-012). Кандидаты: HNSW с консервативными параметрами `m=16, ef_construction=64` (минимальный memory footprint) либо IVFFlat (по умолчанию disk-friendly). `vector` vs `halfvec` — тоже решается в этом ADR | OWNER-001 (закрыт), OWNER-003 (закрыт) | `content/00-project/adr/011-pgvector-index.md` | ready | Phase 0 / iter 1 |
| SA-011 | Апдейт [ADR-002](adr/002-smp-only-data-access.md) — переформулировать «SMP-only data access» в терминах Hibernate `SessionFactory` через Spring `beanFactory.getBean("sessionFactory")`. Зафиксировать паттерны: (a) script-as-binding-carrier для проброса `beanFactory`+`api` в JAR — обёртка `HibernateSessionProvider` в `adapters/db/` по образцу `SmpSuperUserRunner`; (b) `session.doWork` для DDL/JDBC-параметризации; (c) `createNativeQuery` для pgvector-операторов; (d) параметризация vector-аргумента через `CAST(:vec AS vector(N))` | OWNER-001 (закрыт) | апдейт [ADR-002](adr/002-smp-only-data-access.md) или новый ADR | todo | Phase 0 / iter 1 |
| SA-003 | `ADR-uc-api-contract` — публичный SPI: запрос/ответ `SimilaritySearchService` (UC-S1/S2/S3/S4), `DuplicateDetectionService` (UC-C1 online), `clusters_audit(period)` (UC-C1 batch — **API only, формат отчёта out of scope**, OQ-C1-3 / OQ-ITSM-2), `combined_cluster` (UC-C2 — defer to MVP). Формат ошибок без stack-traces; код `VectorNotReady` для not-yet-vectorized объектов | — | `content/00-project/adr/012-uc-api-contract.md` | todo | iter 1 |
| SA-004 | `ADR-audit-log sink` — где живёт журнал вызовов YC FM (NFR-003). **Resolved BA-004 / OQ-7 (2026-05-02): `logger.info` через SLF4J** (системный лог, не отдельный FQN). Retention policy — конфигурируется на стороне SMP-логирования. Метрики расхода — отдельный канал (Prometheus, см. SA-006) | OWNER-001 | `content/00-project/adr/013-audit-log-sink.md` | ready | iter 4 |
| SA-005 | `ADR-job-state` — где хранится прогресс scheduled-джобы (NFR-022). **Resolved BA-004 / OQ-8 (2026-05-02): native Naumen SMP scheduledTask state mechanism** (defer to /sa подтвердить конкретный механизм — `scheduledTask.subject` / отдельный FQN / state-таблица) | OWNER-001 | `content/00-project/adr/014-job-state.md` | ready | iter 1-2 |
| SA-006 | `ADR-observability` — стек метрик и логов. **Resolved BA-004.1 / OQ-3 (2026-05-02): Prometheus + Grafana через Micrometer** (внешний стек настроен и доступен на `llm2`). Реестр метрик: throughput векторизации, success-rate YC FM (200/4xx/5xx/network), размер pgvector-таблицы, частота similarity-запросов, p50/p95/p99 latency, расход YC FM (NFR-060) | OWNER-001, RES-003 | `content/00-project/adr/015-observability.md` | ready | iter 1-4 |
| SA-007 | `ADR-platform-versioning` — SemVer JAR + матрица совместимости с SMP-версиями. Адаптировать [эталонный ADR-013](file:///Users/mdemyanov/Devel/naumen-smp-mcp/content/00-project/adr/013-platform-versioning.md) | — | `content/00-project/adr/016-platform-versioning.md` | todo | iter 1 |
| SA-008 | `ADR-uc3-online-embedding` (для UC-C1 online) — ad-hoc embedding регистрируемой заявки vs lazy от UC-V1. Решается после первого замера latency YC FM на iter 1. Связь: silent-skip при timeout (OQ-C1-5) | DEV-005 (есть реальные данные latency) | `content/00-project/adr/017-uc3-online-embedding.md` | todo | iter 3 |
| SA-009 | `ADR-job-scheduling` — период / стратегия `from_start` vs `from_last_execution` / поведение при конфликте запусков. **Resolved BA-004 / OQ-V1-2 (2026-05-02): UC-V1 — ручной запуск на старте → переход на ежедневно ночью.** UC-C1 batch — еженедельно (OQ-C1-2 окно 90 дней) | SA-005 | `content/00-project/adr/018-job-scheduling.md` | ready | iter 1-2 |
| SA-010 | `ADR-batch-control` — лимит на one-shot batch (NFR-062), required confirmation, **дневной денежный лимит = 1 000 ₽/сутки** (NFR-061, OQ-V1-1 / OQ-6 NFR Resolved 2026-05-02) | RES-003 | `content/00-project/adr/019-batch-control.md` | ready | iter 1 / iter 4 |
| **SA-021** | **NEW.** `ADR-comment-storage-architecture` + `ADR-comment-acl`. Архитектурный анализ: **per-class partitioning** (`comment_vectors_by_issue`, `comment_vectors_by_problem`, `comment_vectors_by_kb`) **vs single comment-vectors table** (с дискриминатором `parent_class`). Cost/benefit по 4 measure'ам: (a) latency UC-S2 GROUP BY parent_id; (b) ACL-фильтрация (post-filter по parent_id, NFR-070); (c) индекс HNSW disk-resident memory footprint (NFR-012); (d) miграционные сценарии при добавлении новых parent-классов. Дополнительно — `ADR-comment-acl`: реализация ACL-наследования через post-filter по parent_id (BR-cross-5). Источник: BA-004 (новая SA-задача) | OWNER-001, RES-010 | `content/00-project/adr/020-comment-storage-architecture.md` + `content/00-project/adr/021-comment-acl.md` | todo | iter 3 (блокер для DEV-VectorStoreHibernateAdapter перед UC-V2) |
| **SA-022** | **NEW.** `ADR-yc-auth` — IAM-token JWT-flow (Resolved OWNER-004 / OQ-10 NFR). TTL ≤ 11ч, refresh за 1ч до истечения. Endpoint: `https://iam.api.cloud.yandex.net/iam/v1/tokens`. Static Api-Key — НЕ используется. Связь: NFR-005, DEV-021 (`IamTokenCache`) | OWNER-002, OWNER-004 | `content/00-project/adr/022-yc-auth.md` | ready | iter 1 |
| **SA-023** | **NEW.** `ADR-preprocessing` — Mixed strategy (`v1.0-mixed` baseline по `nfr-preprocessing.md`): plain для issue/comment/problem, markdown для KB.content. Библиотека HTML→markdown — **flexmark-java** default (OQ-PRE-4 Resolved BA-004); SA подтверждает наличие в Maven mirror Naumen — если недоступен, fallback jsoup-based custom. `algorithm_version` в `composite_hash` (NFR-071). Финальный выбор plain vs markdown для KB — после offline-eval DEV-033 (decision-by-evidence, OQ-PRE-1) | RES-002-closeout | `content/00-project/adr/023-preprocessing.md` | ready | iter 1 |

## C. DevOps задачи

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| DEVOPS-001 | DDL вектор-таблицы по [ADR-004](adr/004-vector-storage-schema.md) (с парамётрами parent_id / chunk_kind / algorithm_version после апдейта ADR-004) + HNSW/IVFFlat-индекс по SA-002 (disk-resident, см. NFR-012). Реализация переезжает в `/dev` (DEV-030 `VectorModuleBootstrap` через `session.doWork`) | [ADR-004](adr/004-vector-storage-schema.md), DEV-030, SA-002 | [runbook-vector-table-migration.md](../70-operations/runbooks/runbook-vector-table-migration.md) | ready | Phase 0 / iter 1 |
| DEVOPS-002 | Регистрация `scheduledTask` для UC-V1 на стенде `llm2`: код, период (manual trigger на старте → ежедневно ночью по SA-009 / OQ-V1-2), пользователь-исполнитель из OWNER-005 (системный пользователь) | DEV-001..023, SA-009, **OWNER-005** | runbook `register-uc-v1-scheduled-task.md` | blocked (OWNER-005) | iter 1 |
| DEVOPS-003 | Smoke-инфраструктура на `llm2`: команда деплоя JAR через `smps`, шаблон smoke-report (по образцу `Devel/naumen-smp-mcp/content/70-operations/smoke-reports/2026-04-23-llm2-m33.md`), процедура rollback | OWNER-001 | `content/70-operations/runbooks/smoke-procedure.md`; шаблон `smoke-reports/_template.md` | todo | iter 1 |
| DEVOPS-004 | Реализовать сбор метрик и логов по SA-006 (NFR-050/051/052). См. также DEVOPS-010 (Prometheus экспортер из JAR) | SA-006, DEVOPS-010 | runbook + Grafana dashboard шаблон | todo | iter 2-4 |
| DEVOPS-005 | Алерт по дневному бюджету YC FM = **1 000 ₽/сутки** (NFR-061, OQ-V1-1 / OQ-6 NFR Resolved). Источник метрики — DEVOPS-004; канал — Telegram / email. Проиграть alert-шторм | DEVOPS-004, RES-003, SA-010 | runbook `alert-yc-fm-budget.md` | todo | iter 4 / closeout |
| DEVOPS-006 | Регистрация `scheduledTask` для UC-C1 batch (`clusters_audit(period)`) с **еженедельной периодичностью**, окно 90 дней (OQ-C1-2). API only — формат отчёта out of scope (OQ-C1-3) | DEV-029, SA-009 | runbook `register-uc-c1-batch-task.md` | todo | iter 4 |
| DEVOPS-007 | Migration-runbook при смене embedding-модели (ADR-007) или смене `algorithm_version` preprocessing (NFR-071): процедура DROP+CREATE INDEX под новый `dim`, blue-green с двумя таблицами как опция, окно работ, откат | [ADR-007](adr/007-model-versioning-migration.md), SA-023, DEVOPS-001 | `content/70-operations/runbooks/runbook-model-migration.md` | todo | iter 4 / MVP |
| DEVOPS-008 | Secret rotation `sa-key.json` (NFR-005): процедура замены без перезапуска модуля, проверка обновления IAM-token-cache (DEV-021) | OWNER-002, OWNER-004 | `content/70-operations/runbooks/runbook-secret-rotation.md` | todo | iter 1 / closeout |
| **DEVOPS-009** | **NEW.** Rate-limiter 40 RPS YC FM в YC-адаптере (NFR-021, OQ-4 NFR Resolved BA-004.1). Реализация: **Bucket4j** (token bucket) или **Resilience4j RateLimiter** (40 permits/sec). Применяется в адаптере перед каждым вызовом `POST /foundationModels/v1/textEmbedding`. Тест: bulk-init 1 000 объектов укладывается в 25 секунд (1000/40), не превышает 40 RPS | DEV-020, SA-022 | `adapters/yc/RateLimitedHttpClient` (см. DEV-022) + integration test против fake YC | todo | iter 1 |
| **DEVOPS-010** | **NEW.** Prometheus экспортер метрик из JAR-модуля (NFR-050, OQ-3 NFR Resolved BA-004.1). Реализация: **Micrometer** + **Prometheus Java client** (или `simpleclient_pushgateway` если pull-режим из стенда `llm2` недоступен). Метрики: throughput векторизации (objects/min), success-rate YC FM (counter по статусам), размер pgvector-таблицы (gauge), частота similarity-запросов (counter по UC), p50/p95/p99 latency (histogram), расход YC FM в ₽ (counter, NFR-060). Grafana dashboard шаблоны. Связь: SA-006 ADR-observability | SA-006 | Pom.xml deps + `adapters/metrics/PrometheusMetricsAdapter.groovy` + `runbooks/grafana-dashboards.md` | todo | iter 1-4 |

## D. Dev задачи (по слоям hexagonal layout)

> Порядок исполнения соответствует §12 принципиальной архитектуры (fixtures → core → ports → adapters → integration tests → smoke). На итерациях PoC задачи DEV-001..017 идут параллельно в пределах слоя.

### D.1. Каркас и тестовая инфраструктура

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| DEV-001 | Каркас модуля по hexagonal layout ([ADR-001](adr/001-hexagonal-architecture.md)): `pom.xml` (Maven mirror Naumen), `src/main/groovy/ru/naumen/modules/pgvector/{core,ports,adapters,config,spi}/`, `src/test/groovy/`, базовые SLF4J. `JAVA_HOME=/opt/homebrew/opt/openjdk@21 mvn clean compile` зелёная | SA-007 | `pom.xml`, дерево пакетов; commit на `private` | todo | iter 1 |
| DEV-002 | CodeNarc + jar-secrets-scan по образцу эталона `naumen-smp-mcp`: запрет `String.execute()`, изоляция `@InjectApi`, запрет JDBC-зависимостей в `core/`, запрет интерполяции в HQL (NFR-043). `mvn verify` зелёный | DEV-001 | `codenarc/`, апдейт `pom.xml` | todo | iter 1 |
| DEV-003 | `CoreBoundarySpec`: запрет `ru.naumen.*` в `core/` (кроме `core.*`/`ports.*`); запрет `java.sql.*`/`org.postgresql.*` повсюду кроме `adapters/db/` (NFR-006/044, ADR-001/002) | DEV-001 | `src/test/groovy/.../arch/CoreBoundarySpec.groovy` | todo | iter 1 |
| DEV-004 | `JdbcImportBanSpec`: scan `pom.xml` + `target/<jar>.jar` на отсутствие `org.postgresql.*` транзитивных зависимостей | DEV-001 | `src/test/groovy/.../arch/JdbcImportBanSpec.groovy` | todo | iter 1 |
| DEV-005 | Test-fixtures: fake `EmbeddingProvider` (детерминированные векторы по hash); fake `VectorStore` (in-memory KNN); fake `SmpRepository` с фикстурами из [smp-metamodel.md](../10-domain/research/smp-metamodel.md) | DEV-001 | `src/test/groovy/.../fixtures/` | todo | iter 1 |

### D.2. Ports и core domain

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| DEV-006 | Inbound/outbound ports: `VectorizationJob` (UC-V1), `CommentVectorizationJob` (UC-V2), `SimilaritySearchService` (UC-S1/S2/S3/S4), `DuplicateDetectionService` (UC-C1 online), `ClustersAuditService` (UC-C1 batch); outbound — `SmpRepository`, `VectorStore`, `EmbeddingProvider`, `AuditLogger`, `MetricsCollector`, `KbAccessChecker`, `CommentAclChecker` (NFR-070), `TenantContextProvider`, `ClockProvider`. Контрактные тесты | DEV-001 | `src/main/groovy/.../ports/`, `src/test/groovy/.../ports/contracts/` | todo | iter 1 |
| DEV-007 | `core/model/`: value-objects `EmbeddingModelDescriptor`, `WhitelistVersion`, `AlgorithmVersion` (NFR-071), `VectorRecord`, `IdempotencyKey`-вычислитель (sha256 от composite-text + modelVersion + whitelistVersion + algorithm_version, NFR-020/071) | DEV-006 | `src/main/groovy/.../core/model/`, юнит-тесты | todo | iter 1 |
| DEV-008 | `WhitelistEnforcer` — гард PII-инварианта (ADR-005). Юнит-тесты на UC-V1 BR-005 (атрибуты вне whitelist не покидают enforcer) | DEV-007 | `core/vectorization/WhitelistEnforcer.groovy` + tests | todo | iter 1 |
| DEV-009 | Whitelist-конфиг: формат хранения per-class whitelist'а (resource в JAR + версия в `pom.xml`); поддержка PII-уровней low/medium/high. **Включить low+medium PII для issue/KB по умолчанию** (OQ-V1-4 Resolved) | DEV-008 | `config/whitelist-v1.yaml` + loader | todo | iter 1 |
| DEV-010 | `CompositeTextComposer` ([ADR-006](adr/006-composite-text-composition.md) + SA-023 ADR-preprocessing): конкатенация в фиксированном порядке, нормализация richtext через **Mixed strategy v1.0-mixed** (`nfr-preprocessing.md`): plain pipeline для issue/comment/problem, markdown pipeline (flexmark-java) для KB.content. Детерминированность (NFR-073). Юнит-тесты | DEV-008, SA-023 | `core/vectorization/CompositeTextComposer.groovy` + `core/preprocessing/PlainTextPipeline.groovy` + `core/preprocessing/MarkdownPipeline.groovy` + tests | todo | iter 1 |
| DEV-011 | `ChunkingStrategy` + `ChunkAggregator` (ADR-006): окно `chunk_size=2 048` (OQ-V1-3 smoke-подтверждение) + overlap; baseline-агрегация — mean-pooling (для UC-V1 issue) и chunked storage (для UC-V1 KB — UC-S4 parent-document retrieval) | DEV-010 | `core/vectorization/Chunking*.groovy` + tests | todo | iter 1 |
| DEV-012 | `EmbeddingPayloadBuilder`: формирует payload для YC FM (только whitelisted-текст). Юнит-тест: payload не содержит ни одного атрибута вне whitelist | DEV-010 | `core/vectorization/EmbeddingPayloadBuilder.groovy` + tests | todo | iter 1 |
| DEV-013 | `core/search/`: `QueryOrchestrator`, `WorkflowStatusFilter`, `SourceExclusion`, `TopKRanker`, **`CommentSearchAggregator` для UC-S2** (max-similarity aggregation — OQ-S2-1 Resolved, GROUP BY parent_id + MIN(distance), oversample 5× — OQ-S2-3, ACL post-filter по parent_id — NFR-070) | DEV-006 | `core/search/` + tests | todo | iter 1 (S1/S4); iter 3 (S2 aggregator) |
| DEV-014 | `core/duplicates/`: `ThresholdClassifier` (cosine; пороги Дубль ≥ 0.92 / Похожая 0.85 — OQ-C1-1 defaults, **decision-by-evidence через DEV-033 в closeout** — ADR-008), `DuplicateGroupComposer` (cosine-threshold pairwise — OQ-C1-4 / OQ-CL-4, транзитивное замыкание), `KnownGroupMarker` (помечает группы покрытые `issue.duplicates`). UC-C1 — оба уровня Дубль+Похожая (OQ-C1-6); UC-C1 batch API only — формат отчёта out of scope (OQ-C1-3 / OQ-ITSM-2). Юнит-тесты | DEV-006 | `core/duplicates/` + tests | todo | iter 3 (online); iter 4 (batch API) |

### D.3. Adapters

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| DEV-015 | `adapters/smp/SmpRepositoryAdapter`: HQL read целевых FQN (`issue` — НЕ `serviceCall`, см. CLAUDE convention; `knowledgeBase$article`; `problem` defer to Pilot) с `setParameter` (NFR-043), пагинация, фильтр по `vector_dirty` или `(modelVersion, algorithm_version)` mismatch | DEV-006 | + integration test против fake SMP | todo | iter 1 |
| DEV-016 | `adapters/db/VectorStoreHibernateAdapter`: read/write/search вектор-таблицы через Hibernate `sessionFactory` (ADR-002 апдейт SA-011) + `vector(256)`-типизация (ADR-004). Параметризация через `setParameter('vec', '[…]') + CAST(:vec AS vector(256))`. Атомарная запись `(VectorRecord, modelVersion, whitelistVersion, algorithm_version, dirty=false)` в Hibernate-транзакции. Integration-тесты — testcontainers с pgvector | DEV-001, DEV-030, ADR-004, SA-002, SA-011, **SA-021** (схема per-class vs single для comment-таблиц) | + integration test | blocked (SA-021) | iter 1 (object); iter 3 (comment) |
| DEV-017 | `adapters/smp/KbAccessSmpAdapter`: проверка `kbAccesses` под пользователем (UC-S4 BR-002). Поддержка двух режимов: pre-filter в HQL и post-filter с oversample (SA-003) | DEV-006 | + integration test | todo | iter 1 |
| DEV-018 | `adapters/smp/DirtyTrackingAdapter`: реализация по выбранной в SA-005 стратегии — атрибут SMP / staging-таблица / mtime. Учитывает изменения по `algorithm_version` (NFR-071) | SA-005 | + tests | blocked | iter 1 |
| DEV-019 | `adapters/yc/MockYcEmbeddingAdapter` mock-mode: реализует `EmbeddingProvider`, генерирует детерминированные эмбеддинги. Нужен для разблокировки DEV-007..014 до закрытия SA-022 / DEV-020 | DEV-006 | `adapters/yc/MockYcEmbeddingAdapter.groovy` | todo | iter 1 (старт) |
| DEV-020 | `adapters/yc/YcEmbeddingProviderAdapter` real-mode: REST-клиент `POST /foundationModels/v1/textEmbedding`, обработка 429/5xx, лимит retry (NFR-021), **rate-limit 40 RPS** через DEV-022 / DEVOPS-009 | OWNER-002, RES-002-closeout, SA-001, **SA-022** | + integration test против YC | blocked (SA-022) | iter 1 |
| DEV-021 | `adapters/yc/IamTokenCache`: кеш IAM-токена с TTL ≤ 11ч, refresh за 1ч до истечения (NFR-005). **JWT-flow обязателен** (OQ-10 NFR Resolved). Endpoint `https://iam.api.cloud.yandex.net/iam/v1/tokens` с `jwtAssertion` payload | OWNER-002, OWNER-004, **SA-022** | + tests на mock-clock | ready | iter 1 |
| DEV-022 | `adapters/yc/RateLimitedHttpClient`: экспоненциальный backoff с jitter на 429/5xx, лимит попыток из конфига; **token bucket 40 permits/sec** (Bucket4j или Resilience4j RateLimiter) — DEVOPS-009 | DEV-006, DEVOPS-009 | + tests | todo | iter 1 |
| DEV-023 | `adapters/scheduler/ApiSchedulerEntry`: Groovy-обвязка `api.scheduler` для UC-V1 (`VectorizationJob`), UC-V2 (`CommentVectorizationJob`), UC-C1 batch (`ClustersAuditJob`) по [ADR-003](adr/003-job-based-vectorization.md) и SA-009. Исполнитель — системный пользователь из **OWNER-005** | SA-009, **OWNER-005** | + integration test (smoke) | blocked (OWNER-005) | iter 1 (UC-V1); iter 3 (UC-V2); iter 4 (UC-C1 batch) |
| DEV-024 | `adapters/smp/AuditLogSmpAdapter`: sink аудит-лога — **`logger.info` через SLF4J** (NFR-003, OQ-7 NFR Resolved BA-004 → SA-004) | SA-004 | + tests | ready | iter 4 |

### D.4. Оркестрация и сборка

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| DEV-025 | `VectorizationOrchestrator` (impl `VectorizationJob`): управление батчами, lock, transaction-границы, прогресс. Идемпотентность по `composite_hash` (NFR-020/071). Покрытие AC UC-V1 | DEV-008..018 | `core/vectorization/VectorizationOrchestrator.groovy` + integration tests | todo | iter 1 |
| DEV-026 | `JobLauncher`: lock через `api.scheduler.getStatus`, time-cap (UC-V1 FR-016), восстановление прерванной джобы (NFR-022). State через native scheduledTask state mechanism (SA-005, OQ-8 NFR Resolved) | SA-005, DEV-023 | + tests | todo | iter 1-2 |
| DEV-027 | `QueryOrchestrator` (impl `SimilaritySearchService` UC-S1/S3/S4): план запроса, формирование query-вектора (по объекту / free-text через `text-search-query`), вызов `VectorStore.search`, применение `WorkflowStatusFilter` + `KbAccessChecker` + `SourceExclusion`, ранжирование. UC-S4 — parent-document retrieval (GROUP BY parent_id + MIN(dist)). UC-S3 — threshold 0.75 на `question_text` only (OQ-S3-1/2 Resolved); pre-condition ≥ 50 FAQ (OQ-S3-4) | DEV-013, DEV-016, DEV-017, DEV-019/020 | + integration tests | todo | iter 1 (S1/S4); MVP (S3 после BA-005) |
| DEV-028 | `DuplicateDetector` (impl `DuplicateDetectionService` UC-C1 online): cosine-threshold (двойной порог Дубль/Похожая, оба уровня — OQ-C1-6), ACL-фильтр, self-match exclusion. **Silent-skip при timeout** (UC-C1 NFR p95 ≤ 2 с — OQ-C1-5 Resolved). Покрытие UC-C1 AC online | DEV-014, DEV-027, SA-008 | + integration tests | todo | iter 3 |
| DEV-029 | `ClustersAuditOrchestrator` (impl `ClustersAuditService` UC-C1 batch): batch-проход по корпусу за окно **90 дней** (OQ-C1-2), pairwise-группировка cosine-threshold (OQ-C1-4), `KnownGroupMarker` через `issue.duplicates`. **API only** — формат отчёта out of scope (OQ-C1-3). Возвращает группы Дубль+Похожая (OQ-C1-6). `embedding_model_id` + `whitelist_version` + `algorithm_version` + thresholds в журнале | DEV-014, DEV-016, DEV-023, SA-004 | + integration tests | todo | iter 4 |
| DEV-030 | `config/VectorModuleBootstrap`: DI-сборка, загрузка whitelist-конфига, инициализация `EmbeddingModelDescriptor` + `AlgorithmVersion`, регистрация `scheduledTask` точек входа, **DDL bootstrap** через `session.doWork` (DEVOPS-001) | все DEV-006..029, ADR-004 | `config/VectorModuleBootstrap.groovy` | todo | iter 1 |
| DEV-031 | Migration-логика при смене embedding-модели (ADR-007) или **смене `algorithm_version`** (NFR-071): trigger на изменение, массовая инвалидация `dirty=true`, поведение при non-compat dim. Юнит-тест: смена `modelUri` или `algorithm_version` → все векторы помечены stale | DEV-007, DEV-025, SA-023 | + tests | todo | iter 4 / MVP |
| DEV-032 | Минимальный публичный SPI (ADR-001 §3, SA-007): `SimilaritySearchSpi` + `ClustersAuditSpi` для внешних SMP-модулей (UC-C1 batch — caller'ы типа SD AI Assistant дёргают для формирования отчёта). Документация интерфейса. Контрактный тест | SA-003, SA-007, DEV-027, DEV-029 | `spi/SimilaritySearchSpi.groovy`, `spi/ClustersAuditSpi.groovy` + контрактный тест | todo | iter 1 / MVP |

### D.5. Реализация UC-V2 / UC-S2 / UC-S3 / UC-C2 (новые задачи BA-002+)

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| **DEV-040** | **NEW.** Реализация **UC-V2** (vectorize comments). `CommentVectorizationOrchestrator` (impl `CommentVectorizationJob`): per-comment вектор, `chunk_kind='related'`, `parent_id` → объект-родитель. **Cap=50 last comments by `creationDate DESC`** (NFR-074, OQ-V2-3/4); фильтрация системных подклассов из `excluded_comment_meta_classes` (NFR-075, **OWNER-006**). **SMP-event trigger для async delete/edit comment** (OQ-COMMENT-DELETE / OQ-COMMENT-EDIT Resolved BA-004): при `comment.delete` событии — асинхронное удаление вектора; при `comment.edit` — пересчёт. Реализация SMP event-trigger через `api.scheduler` + `CommentEventListener` (или эквивалент SMP). Покрытие UC-V2 AC | DEV-006..025, **SA-021** (per-class или single таблица), **OWNER-006** | + integration tests + SMP-event-trigger smoke | blocked (SA-021, OWNER-006) | iter 3 |
| **DEV-041** | **NEW.** Реализация **UC-S2** (search by comments). `CommentSearchOrchestrator`: input — FQN-объект; pipeline: KNN-поиск по comment_vectors → GROUP BY parent_id → MIN(distance) (max-similarity aggregation, OQ-S2-1) → oversample 5× (OQ-S2-3) → post-filter по ACL parent_id (NFR-070) → return top-K parent objects. Без pre-filter по comment_kind в PoC (OQ-S2-5 / OQ-ITSM-3). Молча исключить заявки с 0 комментариев (OQ-S2-4). Latency p95 ≤ **1 000 ms** (NFR-072). Cross-mode (search by comments + by attributes) — НЕ делаем в PoC (OQ-S2-2) | DEV-040, DEV-013 (`CommentSearchAggregator`), DEV-016 (vector-store с comment-таблицей) | + integration tests + latency benchmark | blocked (DEV-040) | iter 3 |
| **DEV-042** | **NEW.** Реализация **UC-S3** (FAQ search). `FaqSearchOrchestrator`: input — свободный текст пользователя (10–50 слов, threshold cutoff 0.75 — OQ-S3-1) через `text-search-query`. Векторизация только по `question_text` (OQ-S3-2). Поиск по `question_id` НЕ поддерживаем в PoC (OQ-S3-3). Pre-condition ≥ 50 FAQ (OQ-S3-4). **Зависит от создания FAQ-класса в SMP — после BA-005 завершения** | **BA-005**, DEV-027 | + integration tests | blocked (BA-005) | MVP |
| **DEV-043** | **NEW.** Реализация **UC-C2** (combined cluster, описание + комментарии). Combined signal: `combined_distance = w1 × issue_cosine + w2 × comment_agg_cosine`. **Default 50/50** (`w1=0.5, w2=0.5`, OQ-CL-1 Resolved). Calibrate weights post-MVP offline-eval. Aggregation: max-similarity (OQ-CL-2). Threshold pairwise (OQ-CL-4). Fallback на UC-C1 для объектов без комментариев. **Defer to MVP** (OQ-CL-3 Resolved) | DEV-014, DEV-029, DEV-040 | + integration tests + calibration script | deferred (MVP) | MVP |

### D.6. Offline-evaluation

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| DEV-033 | Offline-eval скрипт UC-S1/S4 + **decision-by-evidence для preprocessing strategy** (OQ-PRE-1) и **порогов UC-C1** (OQ-C1-1) по методологии [similarity-eval.md](../10-domain/research/similarity-eval.md). Ground truth: `issue.duplicates`/`duplicatesRL` (для UC-S1/UC-C1) + `kb-section`-ассоциации (для UC-S4). Метрики: Recall@10, MRR@10, Precision@T для сетки `T ∈ {0.80,0.85,0.90,0.92,0.95}`. Артефакт — основа для финальных порогов в ADR-008 + ADR-preprocessing | DEV-027, DEV-028 | `src/test/groovy/.../eval/OfflineEvalSpec.groovy` или standalone-script + report-template | todo | iter 1 (черновой) / closeout (финал) |
| DEV-034 | Offline-eval скрипт UC-C1 по [clustering-algos.md](../10-domain/research/clustering-algos.md): сетка порогов и финальная калибровка после iter 4. Подготовка к UC-C2 weights calibration post-MVP (OQ-CL-1) | DEV-028, DEV-029 | `eval/Uc-C1-OfflineEvalSpec.groovy` + report-template | todo | iter 3 (черновой) / closeout (финал) |

## E. BA — открытые вопросы из требований

> **Большинство BA-001..BA-024 закрыто owner-decisions BA-004 (2026-05-02).** Помечено `Resolved (BA-004)` с traceability на конкретный OQ. Активные — BA-005 + опциональные BA-006/007.

### E.1. Resolved (covered by BA-004 owner-decisions)

| ID | Источник OQ | Решение из BA-004 | Локация |
|----|-------------|-------------------|---------|
| BA-001 | UC1 OQ-UC1-2 (расписание UC1) | **Resolved.** OQ-V1-2: ручной запуск → ежедневно ночью. Закрепится в SA-009 ADR-job-scheduling | UC-V1 |
| BA-002 | UC1 OQ-UC1-3 (alert канал `VectorJobAborted`) | **Resolved.** В рамках NFR-061 → DEVOPS-005 alert по бюджету через Telegram/email; alert о падении джобы — стандартный SMP-механизм + Prometheus alert (DEVOPS-010) | NFR-061, SA-006 |
| BA-003 | UC1 OQ-UC1-6 (метрика «не деградировать стенд») | **Resolved.** Через NFR-050 (Prometheus метрики latency p95 SMP API + размер pgvector); конкретные пороги — на iter 1 после первого smoke (decision-by-evidence) | nfr-cross-cutting.md NFR-050 |
| BA-004 | UC1 OQ-UC1-7 (очерёдность подключения классов) | **Resolved.** OQ-V1-5: PoC scope = `issue + KB + faq` (faq → MVP после BA-005); `problem` → defer to Pilot | UC-V1 |
| BA-005 (старый, переиспользован ID — см. ниже E.2) | UC1 OQ-UC1-8 (whitelist medium-PII) | **Resolved.** OQ-V1-4: low+medium PII открыты для PoC (sign-off получен). High-PII (`description`/`lastComment`/`feedback` для issue) — допускается `description`/`decisionReport`/`feedback`; уточнения — в whitelist-конфиге | UC-V1 |
| BA-006 (старый) | UC1 OQ-UC1-10 (cap времени UC1) | **Resolved.** OQ-V1-2: ежедневно ночью; cap не нужен в PoC (пересчёт по запросу). Production/Pilot+: ≤ 6 ч окно (OQ-2 NFR Resolved BA-004.1) | NFR-010 |
| BA-007 (старый) | UC1 OQ-UC1-11 (нормализация richtext) | **Resolved.** OQ-PRE-1/3/4: Mixed strategy v1.0-mixed (plain для issue/comment, markdown KB через flexmark-java); URL остаются (OQ-PRE-2 → OQ-FUTURE-2 MVP); emoji оставить (OQ-PRE-3) | nfr-preprocessing.md |
| BA-008 (старый) | UC1 OQ-UC1-12 (размер батча) | **Resolved.** OQ-V1-3: chunk_size=2 048 (smoke-подтверждение). RPS-квота 40 RPS (OQ-4 NFR) | UC-V1 |
| BA-009 (старый) | UC2 Q3 (бинарная vs градированная разметка) | **Resolved.** Decision-by-evidence в DEV-033: для PoC — бинарная (`relevant ∈ {0,1}`) на основе `issue.duplicates`/`duplicatesRL`. Градация — после MVP, если потребуется | DEV-033 |
| BA-010 (старый) | UC2 Q4 (финальные пороги Recall/MRR/p95 GO/NO-GO) | **Resolved.** Черновые в NFR (Recall@10 ≥ 0.70 PoC iter 1; p95 ≤ 500 ms через NFR-011, p95 ≤ 1 000 ms для UC-S2 через NFR-072). Финальные — после offline-eval в closeout (PM-004) | UC-S1/S2/S4 |
| BA-011 (старый) | UC2 Q6 (cross-domain similarity) | **Resolved.** В PoC iter 2 — выборочная проверка `issue ↔ kb-article`; формальные метрики cross-domain — MVP | UC-S1 / UC-S4 |
| BA-012 (старый) | UC2 Q7 (подклассы issue) | **Resolved.** Использовать `issue` (НЕ `serviceCall`) — convention CLAUDE.md / project_smp_class_convention_issue. Фильтр targetClasses включает все подклассы `issue$*` через `is_assignable_from` HQL | UC-S1 |
| BA-013 (старый) | UC2 Q8 (холодный запуск UC2) | **Resolved.** Объекты без вектора возвращаются с кодом `VectorNotReady` (UC-S1/S4 AC); UC-V1 в фоне догоняет. Деградация плавная | UC-S1/S4 |
| BA-014 (старый) | UC2 Q9 (контекст пользователя для kbAccesses) | **Resolved.** SA-003 / DEV-017: `KbAccessChecker` под текущим SMP-пользователем через `api.user.getCurrent` (или эквивалент); системный пользователь UC-V1 — отдельно (OWNER-005). Закрепится в ADR-uc-api-contract | UC-S4, SA-003 |
| BA-015 (старый) | UC2 Q10 (пакетный запрос UC2) | **Resolved.** Не делаем в PoC; включаем в MVP при наличии Journey-3 потребителя. SPI-расширение | UC-S1/S4 |
| BA-016 (старый) | UC2 Q11 (test-set для evaluation) | **Resolved.** Фикстура в репо в `src/test/resources/eval/` + регенерация через DEV-033. Снапшот SMP — снимается owner-командой раз в спринт | DEV-033 |
| BA-017 (старый) | UC3 Q3 (окно объектов batch-аудита) | **Resolved.** OQ-C1-2: окно = 90 дней | UC-C1 |
| BA-018 (старый) | UC3 Q4 (частота batch-джобы) | **Resolved.** Еженедельно (через SA-009 / DEVOPS-006) | UC-C1 |
| BA-019 (старый) | UC3 Q5 (показывать ли «Похожая» оператору) | **Resolved.** OQ-C1-6: оба уровня — Дубль и Похожая | UC-C1 |
| BA-020 (старый) | UC3 Q6 (problem-конфигурация) | **Resolved.** OQ-PROBLEM-DATA: `problem` → defer to Pilot (нет данных, 3 объекта на llm2 — RES-009.1) | UC-C1 |
| BA-021 (старый) | UC3 Q8 (формат отчёта batch-аудита) | **Resolved.** OQ-C1-3 / OQ-ITSM-2: **Out of scope модуля**. Модуль = API `clusters_audit(period)`. Caller (SD AI Assistant и др.) формирует отчёт самостоятельно | UC-C1 |
| BA-022 (старый) | UC3 Q9 (доля issue.duplicates на llm2) | **Resolved.** RES-009.1: ground truth = 2,4 % (низкая, но достаточная для precision/recall на 95% доверии). Уверенность в AC помечена в UC-C1 | UC-C1 / RES-009.1 |
| BA-023 (старый) | UC3 Q10 (high-precision mode ≥ 0.95) | **Resolved.** Не делаем в PoC; backlog MVP | UC-C1 |
| BA-024 (старый) | NFR OQ-9 (исполнитель scheduledTask) | **Resolved.** OQ-V1-6 / OQ-9 NFR: системный пользователь; пресет — **OWNER-005** (Сахабетдинов) | NFR-001/002, OWNER-005 |

### E.2. Активные BA-задачи

| ID | Описание | Ответственный | Статус | Фаза |
|----|----------|---------------|:------:|------|
| **BA-005** | **NEW.** Проектирование FAQ-класса. Owner-decision OQ-ITSM-5 / OQ-FAQ: вероятный Вариант A — отдельный SMP-класс `faq$question` с атрибутами `question`, `answer`, ссылки на `knowledgeBase$article` (1..N), `slmService` (0..N), `problem` (0..N). Подзадачи: (1) JTBD на 3 роли; (2) схема атрибутов с PoC-минимумом; (3) ITSM-консультация через `/itsm`; (4) согласование с Сахабетдиновым о создании класса в SMP. Артефакт уже создан как Draft | BA + ITSM-аналитик + SA + Сахабетдинов | in-progress | MVP enrolment |
| **BA-006** | **NEW.** Расчёт unit economics (OQ-FUTURE-1). Стоимость на тенант, точки окупаемости PoC vs MVP vs Production, рекомендуемый лимит для production. Опциональная — после PoC closeout перед MVP-входом | Owner / PM | optional | post-PoC / MVP |
| **BA-007** | **NEW.** PII-mask preprocessing для `comment.text` (OQ-V2-5 / OQ-FUTURE-2). Проектирование: какие PII-паттерны маскировать (URL, email, phone, ФИО — паттерн), порядок применения относительно whitelist-фильтра. Закрепится в обновлении ADR-preprocessing (SA-023) | BA + SA | deferred | MVP |

## F. PM координация

| ID | Описание | Зависимости | Артефакт | Статус | Фаза |
|----|----------|-------------|----------|:------:|------|
| PM-001 | `/pm-review` всех BA/SA артефактов перед merge `private → public`: проверка обязательных properties в frontmatter, валидация JTBD/AC, NFR mapping, отсутствие секретов / PII | BA + SA артефакты готовы | issue/PR с чек-листом | recurring | каждая итерация |
| PM-002 | Координация Phase 0 unblockers: следить за OWNER-001/002/003/004, эскалация при простое > 5 рабочих дней | — | weekly status update | done | Phase 0 |
| PM-003 | Roadmap snapshot: еженедельный апдейт колонки «Статус» в [roadmap.md](roadmap.md) и в этом backlog'е | DEV / DevOps итерации | апдейт `roadmap.md` + `backlog.md` | recurring | вся PoC |
| PM-004 | PoC closeout report: сводный отчёт по всем UC-V/S/C AC + NFR-001..062 + NFR-070..075 + NFR-PRE-*, итоговые пороги, recall/precision/latency, расход YC FM, GO/NO-GO решение | iter 4 завершена; DEV-033/034 запущены | `content/70-operations/poc-closeout-report.md` | todo | closeout |
| PM-005 | После closeout — обновление [CLAUDE.md](../../CLAUDE.md) План запуска (Phase 4+) с фактом и ссылкой на closeout-отчёт | PM-004 | апдейт `CLAUDE.md` | todo | closeout |
| PM-006 | После каждой Dev-итерации — `superpowers:verification-before-completion`: запуск `mvn verify`, smoke-report на `llm2`, обновление [smoke-reports/](../70-operations/) | каждая итерация | smoke-reports | recurring | вся PoC |
| PM-007 | Обновление `docs/lessons-learned.md` после каждой итерации (append-only журнал) | каждая итерация | `docs/lessons-learned.md` | recurring | вся PoC |
| **PM-008** | **NEW.** Координация с Сахабетдиновым по **OWNER-005** (системный пользователь scheduledTask на llm2) и **OWNER-006** (точный список `excluded_comment_meta_classes` через MCP `metamodel_export_class comment` или прямой запрос). Эскалация owner'у Демьянову при простое > 3 рабочих дня | — | issue / Telegram-ping; запись в этом backlog'е | in-progress | Phase 0 / iter 1 / iter 3 |
| **PM-009** | **NEW.** Owner-review нового FAQ-класса в SMP: после BA-005 (детализация JTBD/AC/atributes scheme + sync с Сахабетдиновым) и SA-021 (архитектура comment-таблиц) — sign-off owner'а на создание `faq$question` или признака `type=question` на `knowledgeBase$article`. Координация с Сахабетдиновым о deploy класса в SMP-метамодель | BA-005, SA-021 | issue / sign-off запись | todo | MVP enrolment |

## G. Зависимости critical path (от старта до конца PoC)

Цепочка задач от текущего состояния до GO/NO-GO PoC. Пропуск любой ступени останавливает следующую.

```
[Phase 0 ✓] OWNER-001/002/003/004, RES-002-closeout, RES-003, RES-009.1/2, BA-002/003/004/004.1
              │
              ▼
[Open external blockers]
  OWNER-005 (системный пользователь) ──┐
  OWNER-006 (excluded_comment_meta_classes) ──┐
                                              │
[Open SA-задачи]                              │
  SA-002 (ADR-pgvector-index, disk-resident) ─┤
  SA-022 (ADR-yc-auth, JWT-flow) ─────────────┤
  SA-023 (ADR-preprocessing, v1.0-mixed) ─────┤
  SA-021 (ADR-comment-storage + ADR-comment-acl) ───────────┐
  SA-003 (ADR-uc-api-contract) ────────────────────────────┐│
  SA-004 (ADR-audit-log → logger.info) ────────────────────┤│
  SA-005 (ADR-job-state, native scheduledTask) ────────────┤│
  SA-006 (ADR-observability, Prometheus+Grafana) ──────────┤│
  SA-007 (ADR-platform-versioning) ────────────────────────┤│
  SA-009 (ADR-job-scheduling, ежедневно ночью) ────────────┤│
  SA-010 (ADR-batch-control, 1 000 ₽/сутки) ───────────────┤│
                                              │           ││
                                              ▼           ▼▼
                                  DEV-001..016 (core/ports/object adapters)
                                  + DEV-019/020 (mock + real YC), DEV-021 (IAM JWT), DEV-022 (rate-limit)
                                  + DEVOPS-001 (DDL bootstrap), DEVOPS-009 (40 RPS limiter), DEVOPS-010 (Prometheus)
                                              │
                                              ▼
                                  PoC iter 1 (UC-V1+UC-S4 KB)
                                              │
                                              ▼
                                  PoC iter 2 (UC-V1+UC-S1 issue, low+medium PII)
                                              │
                                              ▼
                                  DEV-040 (UC-V2 + SMP-event trigger) ──┐
                                  DEV-041 (UC-S2)                       │
                                  DEV-014/028 (UC-C1 online)            │
                                  RES-010 (comment-count distribution)  │
                                              │                         │
                                              ▼                         │
                                  PoC iter 3 (UC-V2 + UC-S2 + UC-C1 online)
                                              │
                                              ▼
                                  DEV-024 (audit-log → logger.info), DEV-029 (clusters_audit batch API)
                                  DEVOPS-005 (alert 1 000 ₽/сутки), DEVOPS-006 (UC-C1 batch scheduledTask)
                                              │
                                              ▼
                                  PoC iter 4 (UC-C1 batch API + audit + Prometheus)
                                              │
                                              ▼
                                  DEV-033/034 (offline-eval finals — calibrate UC-C1 thresholds, OQ-PRE-1)
                                              │
                                              ▼
                                  PoC closeout (PM-004) → GO/NO-GO MVP
                                              │
                                              ▼
                                  MVP: BA-005 FAQ + DEV-042 UC-S3 + DEV-043 UC-C2 + BA-007 PII-mask + RES-011 batch API
```

**Минимальный набор для запуска первой Dev-итерации (PoC iter 1, UC-V1+UC-S4 на KB):**

1. OWNER-001, OWNER-002, OWNER-003, OWNER-004 — закрыты ✓.
2. RES-002-closeout, RES-003-pricing — закрыты ✓.
3. SA-002 (ADR-pgvector-index, disk-resident), SA-022 (ADR-yc-auth JWT), SA-023 (ADR-preprocessing v1.0-mixed) — приняты.
4. DEVOPS-001 (DDL bootstrap через SessionFactory), DEVOPS-009 (rate-limiter 40 RPS), DEVOPS-010 (Prometheus экспортер) — стартуют параллельно с DEV.
5. DEV-001..006 (каркас + ports + fixtures) — закрыты.
6. DEV-019 (mock embedding-adapter) — позволяет идти параллельно DEV-007..014 / DEV-027 до закрытия SA-022.
7. DEV-021 (IamTokenCache JWT) — после SA-022 ADR.

**Минимальный набор для PoC iter 3 (UC-V2 + UC-S2):**

1. PoC iter 1 + iter 2 закрыты ✓.
2. **OWNER-005** (системный пользователь scheduledTask) — закрыт.
3. **OWNER-006** (excluded_comment_meta_classes) — закрыт.
4. **SA-021** (ADR-comment-storage-architecture + ADR-comment-acl) — принят.
5. **RES-010** (распределение комментариев) — закрыт; cap=50 подтверждён или обновлён.
6. DEV-040 (UC-V2 + SMP-event trigger) — закрыт.
7. DEV-041 (UC-S2) — закрыт.

## H. Связанные артефакты

- [Roadmap](roadmap.md)
- [Стейкхолдеры](stakeholders.md)
- **BA — функциональные UC:**
  - [UC-V1](../30-requirements/functional/uc-v1-vectorize-attributes.md)
  - [UC-V2](../30-requirements/functional/uc-v2-vectorize-comments.md)
  - [UC-S1](../30-requirements/functional/uc-s1-find-similar-issues.md)
  - [UC-S2](../30-requirements/functional/uc-s2-find-similar-by-comments.md)
  - [UC-S3](../30-requirements/functional/uc-s3-find-similar-faq.md)
  - [UC-S4](../30-requirements/functional/uc-s4-find-similar-kb.md)
  - [UC-C1](../30-requirements/functional/uc-c1-cluster-by-description.md)
  - [UC-C2](../30-requirements/functional/uc-c2-cluster-by-description-comments.md)
  - [BA-005 — FAQ-class design](../30-requirements/functional/uc-faq-class-design.md)
- **BA — нефункциональные:**
  - [NFR cross-cutting](../30-requirements/non-functional/nfr-cross-cutting.md)
  - [NFR preprocessing](../30-requirements/non-functional/nfr-preprocessing.md)
- **Роли:** [ITSM-аналитик](../30-requirements/roles/itsm-analyst.md)
- **Historical (Superseded):** UC1, UC2, UC3 (помечены `[SUPERSEDED]`, сохранены для трассируемости AC).
- **SA:** [Принципиальная архитектура](../40-architecture/principal-architecture.md), [adr/](adr/) (001-010 приняты; 011-023 в этом backlog'е как SA-002..023)
- **Research:** [sources](../10-domain/research/sources.md), [SMP metamodel](../10-domain/research/smp-metamodel.md), [YC Foundation Models](../10-domain/research/yc-foundation-models.md), [yc-pricing](../10-domain/research/yc-pricing.md), [pgvector indexes](../10-domain/research/pgvector-indexes.md), [similarity evaluation](../10-domain/research/similarity-eval.md), [clustering algos](../10-domain/research/clustering-algos.md), [SMP scheduled jobs](../10-domain/research/smp-scheduled-jobs.md), [reference project notes](../10-domain/research/reference-project-notes.md), [vector-storage-domain (RES-009.1)](../10-domain/research/vector-storage-domain.md), [vector-storage-strategies (RES-009.2)](../10-domain/research/vector-storage-strategies.md), [itsm-similarity-search-patterns](../10-domain/research/itsm-similarity-search-patterns.md)
- **Domain knowledge:** [itsm-knowledge.md](../10-domain/itsm-knowledge.md), [glossary.md](../10-domain/glossary.md)
- **ITSM-reviews:** [ba-002-full-catalog-review](../10-domain/itsm-reviews/ba-002-full-catalog-review.md)
