---
order: 40
title: "ADR-004: Vector storage schema"
properties:
  - Тип контента: ADR
  - Фаза: PoC
  - Статус: Draft
---

# ADR-004: Vector storage schema

**Status:** Draft
**Date:** 2026-05-01

## Context

Векторы SMP-объектов нужно где-то хранить. Возможные базовые варианты:

1. **Отдельная таблица в той же БД, что и SMP-объекты** (одна схема или отдельная schema/tablespace). Связь по UUID объекта.
2. **Колонка `embedding vector(N)` в основной таблице SMP-объекта** (расширение существующей FQN-таблицы).
3. **Внешний vector store** (Qdrant, Milvus, отдельный PostgreSQL-инстанс).

Вариант 3 архитектурно отвергнут CLAUDE.md (стек фиксирован: PostgreSQL + pgvector). Вариант 2 разрушает изоляцию данных модуля, делает невозможным версионирование без миграции SMP-таблицы и физически невозможен через SMP API (нельзя добавить колонку `vector(1536)` в системную таблицу `issue` через `api.db.query` read-only).

Use case-входы:

- **UC1** (`content/30-requirements/functional/uc1-scheduled-vectorization`):
    - BR-002 «Один объект — одна актуальная векторная запись на `(id_объекта, fqn, версия_модели)`».
    - BR-003 «Версия модели эмбеддинга — обязательная часть записи; нельзя сохранить вектор без указания, какой моделью он посчитан».
    - BR-004 «Размерность вектора привязана к модели; смена модели на модель с другой размерностью требует полного пересчёта (миграция)».
    - BR-008 «Тенант-изоляция: векторы тенанта A не попадают в выдачу для тенанта B». Конкретная реализация (отдельная таблица / discriminator-колонка) — закрепляется здесь.
    - FR-006 «Чанкинг длинных текстов»: способ агрегации эмбеддингов чанков (один вектор на объект vs хранение нескольких векторов) — open question, отдельный ADR; данная схема должна **не блокировать** оба варианта.
    - FR-009 «Версионирование модели эмбеддинга»: имя и версия модели сохраняются вместе с вектором.
    - NFR-UC1-004 «Целостность данных»: атомарность «вектор записан + `vector_dirty = false`».

- **NFR cross-cutting** (`content/30-requirements/non-functional/nfr-cross-cutting`):
    - NFR-020 (идемпотентность) — детерминированный ключ «текст + версия модели + версия whitelist'а».
    - NFR-030 (версионирование embedding-модели) — `modelUri` + дата pin'а в каждой записи.
    - NFR-032 (версионирование whitelist'а) — изменения whitelist'а инвалидируют затронутые векторы.
    - NFR-042 (размерность и `modelUri` в ADR) — данный ADR оставляет размерность как параметр (фиксируется в отдельном ADR-009 после yc CLI).

- **Research** (`content/10-domain/research/pgvector-indexes`):
    - Рекомендованный индекс — HNSW с операторным классом `vector_cosine_ops` (для медианы 100k–300k векторов).
    - Открытые вопросы: версия pgvector на стенде (OQ-IDX-1), стратегия DDL (OQ-IDX-2), `maintenance_work_mem` (OQ-IDX-3), вариант `halfvec` для 1M+ (секция 6), schema/tablespace (OQ-IDX-7).

- **CLAUDE.md** red-line: «доступ к БД — только через SMP API» — DDL не выполняется кодом модуля (см. ADR-002).

## Decision

**Векторы хранятся в отдельной таблице `pg_vector_service__vectors`** (имя финализируется в DDL-runbook'е DBA — может потребоваться префикс схемы). Структура колонок:

| Колонка | Тип | PK / Unique | Назначение |
|---|---|---|---|
| `object_id` | `uuid` | PK part | UUID SMP-объекта (`api.types.UUID` строкой). |
| `meta_class` | `text` | PK part | FQN целевого класса (`issue$incident`, `knowledgeBase$article`, `problem$problem`). |
| `tenant_id` | `text` | PK part / index | Идентификатор тенанта SMP (BR-008). На PoC `llm2` — один тенант, но колонка обязательна для будущего multi-tenant; точное значение и mapping — open question OQ-UC1-1. |
| `model_version` | `text` | not null | Полный `modelUri` модели + pinned-версия (NFR-030, BR-003). Например, `gpt://b1g.../doc/1` (точная форма — после yc CLI). |
| `whitelist_version` | `int` | not null, default 1 | Версия whitelist'а атрибутов (NFR-032), часть ключа идемпотентности. |
| `embedding` | `vector(N)` | not null | Сам вектор. **N — параметр, фиксируется в отдельном ADR-009** после yc CLI и подтверждения модели (см. NFR-042). На момент PoC ожидается ~256/512/1024/1536 — точное значение зависит от выбранной модели YC FM. |
| `composite_hash` | `bytea` | not null, indexed | SHA-256 от композитного текста (whitelist-атрибуты в фиксированном порядке, нормализованные richtext) + версия чанкинг-стратегии. Используется для идемпотентности (NFR-020). |
| `vectorized_at` | `timestamptz` | not null | Время записи вектора. |
| `dirty` | `bool` | not null, default false | Дублирующий маркер «требует пересчёта» — используется в случае, если стратегия dirty-tracking (отдельный ADR по UC1 FR-007) выбирает «маркер в этой же таблице». Не противоречит варианту «маркер в SMP-атрибуте». |

**Композитный первичный ключ:** `(object_id, meta_class, tenant_id)`. BR-002 «одна актуальная запись на объект» — обеспечивается этим PK при стратегии «один вектор на объект». Если стратегия чанкинга по UC1 FR-006 выберет «несколько векторов на объект», PK расширяется на `chunk_index int` — это решение выносится в отдельный ADR (chunk-aggregation), но колонка `chunk_index` может быть добавлена миграцией без переноса данных, если в `pg_vector_service__vectors` сразу заложить `chunk_index = 0` default'ом.

**Индексы (создаются DBA-миграцией, не runtime):**

- HNSW на `embedding`: `CREATE INDEX … ON pg_vector_service__vectors USING hnsw (embedding vector_cosine_ops)` (по рекомендации `pgvector-indexes.md` § 3.1).
    - Параметры build: `m = 16`, `ef_construction = 64` (defaults v0.8.x). Для верхней планки 1M+ — `m = 32`, `ef_construction = 128` (зависит от RES-001 объёма).
    - `maintenance_work_mem` ≥ 2 GB на время build (OQ-IDX-3, координация с DBA).
- B-tree на `composite_hash` — для idempotency-проверки.
- Partial-индексы / per-class партиционирование — open question (OQ-UC1-1, OQ-IDX-7); если на одном тенанте миллионы объектов разных классов, можно партиционировать по `meta_class`. На PoC — не партиционируем, проверяем по smoke.

**Метрика расстояния:** `vector_cosine_ops` (cosine similarity). Окончательный выбор зависит от того, нормализует ли YC FM-модель эмбеддинги (RES-002 OQ-IDX-5): для нормализованных векторов `vector_ip_ops` (inner product) быстрее cosine при том же качестве. Это закрепится в отдельном ADR (метрика расстояния), не противоречит данной схеме (тип колонки `vector(N)` совместим со всеми тремя операторными классами).

**Пометка о версионировании при смене модели (NFR-030):**

- Смена модели → `modelUri` меняется → старые векторы становятся «несовместимы» с новыми запросами (другая размерность / семантика).
- Стратегия миграции (отдельная таблица для новой модели vs одна таблица с фильтром по `model_version`) — закрепится в отдельном ADR (model-versioning + migration-runbook).
- Ключевой инвариант данного ADR: **`model_version` — обязательная колонка**, без неё запись физически нельзя вставить (NOT NULL constraint).

**DDL-процедура:**

- DDL пишется DBA-стороной до первой Dev-итерации; модуль `pg_vector_service` не выполняет `CREATE TABLE` / `CREATE INDEX` runtime (см. ADR-002).
- Migration script хранится в `content/70-operations/runbooks/pgvector-ddl.md` (DevOps-артефакт).
- Включает: `CREATE EXTENSION IF NOT EXISTS vector` (или подтверждение, что уже стоит); `CREATE TABLE pg_vector_service__vectors`; `CREATE INDEX hnsw_…`; `ANALYZE`.
- Откат: `DROP TABLE pg_vector_service__vectors CASCADE` — runbook DBA.

## Consequences

**Positive:**

- **Изоляция:** векторы и метаданные `pg_vector_service` живут в отдельной таблице, не смешиваются с системными SMP-таблицами — апгрейд платформы (см. эталон, ADR-013) на них не влияет.
- **Версионирование вектора:** `model_version` + `whitelist_version` в каждой записи — позволяют постепенно мигрировать на новую модель (часть данных уже на новой, часть — ещё на старой; UC2 фильтрует по `model_version`, выбирая актуальную).
- **Idempotency:** `composite_hash` обеспечивает NFR-020 — повторный запуск UC1-джобы на неизменённом тексте не делает YC FM-вызов (хеш совпадает с уже сохранённым).
- **Тенант-изоляция:** `tenant_id` в PK — UC2 BR-006, UC1 BR-008 закрываются фильтром `WHERE tenant_id = :ctx.tenantId` через SMP API; невозможно «случайно» вернуть чужие векторы.
- **Размер таблицы предсказуем:** одна строка на объект (или на чанк) + индекс HNSW — оценка памяти из `pgvector-indexes.md` § 3 применима.

**Negative:**

- **DDL вне runtime:** изменение схемы (новая колонка для `chunk_index`, миграция на `halfvec`, добавление partial-индекса) требует ручной координации с DBA; задержка между «решили» и «сделали» — потенциально дни.
- **Размерность фиксируется заранее:** `vector(N)` — N задаётся при `CREATE TABLE`. Смена модели на модель с другой размерностью требует **новой таблицы** (или ALTER, если pgvector ≥ 0.7.0 это поддерживает — open question OQ-IDX-1) и blue-green миграции.
- **Дублирование `model_version` в каждой строке** — overhead на storage. Для 1M записей × ~50 байт `text` — ~50 MB; приемлемо для PoC.
- **`composite_hash` нужно считать на стороне модуля** (не на стороне БД) — детерминированность зависит от стабильности порядка whitelist-атрибутов и нормализации текста (UC1 FR-005). Любое изменение конкатенации меняет хеш и инвалидирует все векторы — это feature, но требует дисциплины при правках кода.

**Mitigations:**

- **DDL-runbook** оформляется DevOps-ом до первой Dev-итерации (`content/70-operations/runbooks/pgvector-ddl.md`), включая rollback и smoke-чеклист (`SELECT count(*) FROM pg_vector_service__vectors`, `EXPLAIN ANALYZE` HNSW-запроса).
- **Инкрементальная эволюция схемы:** все будущие колонки (например, `chunk_index`) добавляются с `DEFAULT` так, чтобы не требовать backfill'а; крупные миграции — отдельные ADR с supersede.
- **Тест на детерминированность `composite_hash`:** unit-тест `CompositeHashSpec` фиксирует, что хеш одного и того же объекта одинаков на двух запусках; smoke на стенде проверяет, что повторный запуск UC1 даёт нулевой YC FM-расход (UC1 AC-004).
- **`model_version` валидируется на запись:** SMP script-метод записи в pgvector проверяет not-null `model_version`; запись без него — отклонена с ошибкой (UC1 BR-003 / AC-006).

## Alternatives Considered

- **Колонка `embedding vector(N)` в основной таблице SMP-объекта** (например, добавить `embedding` в `issue` или в наследник `vectorizable`): отвергнуто. Во-первых, физически невозможно через SMP API — `ALTER TABLE issue ADD COLUMN embedding vector(1536)` не доступен read-only HQL. Во-вторых, нарушает изоляцию модуля — апгрейд платформы потенциально перетирает дополнительные колонки или ломает их совместимость. В-третьих, версионирование модели становится невозможным (либо одна актуальная версия, либо несколько колонок `embedding_v1`, `embedding_v2` — мусор).
- **Один вектор на объект без `model_version`** (одна актуальная модель, при смене — full reindex без истории): отвергнуто — нарушает NFR-030 «новые векторы пишутся в новую таблицу/колонку, старые остаются доступны до миграции запросов на новую модель». Blue-green миграция требует совместного существования двух моделей хотя бы временно (UC1 BR-004).
- **Отдельная таблица per FQN** (`pg_vector_service__issue_vectors`, `pg_vector_service__kb_vectors`, …): теоретически даёт более компактные индексы. Отвергнуто на PoC — увеличивает количество DDL-операций при добавлении нового класса; UC2 cross-class similarity (FR-005) требует UNION между таблицами с осторожной HNSW-сортировкой; одна таблица с `meta_class`-колонкой и (опц.) партиционированием решает то же без overhead'а.
- **Вектор как BLOB / `bytea` без `vector(N)` типа** (хранить float-массивы как байты, обходить pgvector-индекс): отвергнуто — теряем HNSW-индекс, similarity-запрос становится full-scan, NFR-001 (UC2 latency) не выполняется на 100k+ объектах.

## Связанные статьи

- [UC1 — Scheduled vectorization](../../30-requirements/functional/uc1-scheduled-vectorization) — BR-002 (одна запись на объект), BR-003 (версия модели обязательна), BR-004 (размерность от модели), BR-008 (тенант-изоляция), FR-009 (версионирование), AC-006 (версия модели в записи), AC-011 (атомарность).
- [UC2 — Similarity search](../../30-requirements/functional/uc2-similarity-search) — потребитель таблицы; FR-005 (cross-class через одну таблицу с `meta_class`), NFR-001 (latency p95 — обеспечивается HNSW-индексом), Q2 (метрика расстояния — отдельный ADR).
- [UC3 — Duplicate detection](../../30-requirements/functional/uc3-duplicate-detection) — потребитель таблицы; FR-002 (поиск среди векторизованных того же класса — фильтр `meta_class`).
- [Cross-cutting NFR](../../30-requirements/non-functional/nfr-cross-cutting) — NFR-020 (idempotency через `composite_hash`), NFR-030 (версионирование модели), NFR-032 (версионирование whitelist'а), NFR-042 (размерность в ADR).
- [pgvector — выбор индекса](../../10-domain/research/pgvector-indexes) — § 3.1 рекомендация HNSW, § 4 метрика расстояния, § 7 DDL через DBA, § 8 OQ-IDX-1…7.
- ADR-001 (Hexagonal architecture) — `VectorStoragePort` в `ports/outbound/`, реализация в `adapters/smp/`.
- ADR-002 (SMP-only data access) — DDL не runtime, координация с DBA; запись через SMP script-метод.
- ADR-003 (Job-based vectorization) — `vector_dirty` маркер согласован со структурой таблицы (колонка `dirty` или внешний SMP-атрибут).
- Будущий ADR-009 (вынесет окончательное N для `vector(N)` после yc CLI и подтверждения модели YC FM).
- Будущий ADR (chunk-aggregation) — может расширить PK на `chunk_index` без перестройки таблицы.
- Будущий ADR (метрика расстояния) — выбор `vector_cosine_ops` vs `vector_ip_ops` после RES-002 OQ-IDX-5.
