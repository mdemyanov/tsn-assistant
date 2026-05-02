---
order: 10
title: "Runbook: миграция вектор-таблицы pg_vector_service__vectors"
properties:
  - Тип контента: Runbook
  - Фаза: PoC
  - Статус: Approved (исполняется bootstrap'ом модуля через Hibernate sessionFactory)
---

# Runbook: миграция вектор-таблицы `pg_vector_service__vectors`

**Статус:** Approved 2026-05-01. SMP DB-user = `llm2`, канал доступа — **Hibernate `sessionFactory` через Spring `beanFactory.getBean("sessionFactory").getCurrentSession()`** (не `modules.localSql`). DDL исполняется bootstrap'ом модуля при первом старте JAR через `session.doWork(...)` — отдельное окно работ не требуется (idempotent, секундная операция).
**Дата создания:** 2026-05-01
**Дата approval:** 2026-05-01 (owner)
**Авторы:** PM (Демьянов через AI-агенты)

## 1. Назначение

Создать таблицу `pg_vector_service__vectors` и сопутствующие индексы на БД стенда `llm2` для хранения векторных представлений SMP-объектов. Соответствует [ADR-004](../../00-project/adr/004-vector-storage-schema.md) и [ADR-010](../../00-project/adr/010-embedding-model-selection.md).

Этот runbook исполняется один раз на стенде до первой Dev-итерации (PoC iter 1). Пере-исполнение возможно только в сценариях:

- Смена embedding-модели на модель с другой размерностью (см. [ADR-007](../../00-project/adr/007-model-versioning-migration.md)) → отдельный runbook миграции.
- Перенос на отдельную схему/tablespace по решению DBA.

## 2. Предусловия (gates)

| # | Условие | Кто подтверждает | Статус |
|---|---------|------------------|:------:|
| G1 | Расширение `pgvector` ≥ 0.8.0 установлено на БД `llm2` | Сахабетдинов | ✅ 2026-05-01 (pgvector 0.8.1) |
| G2 | Согласована схема/tablespace для вектор-таблицы | Owner (по baseline) | ✅ 2026-05-01 — `public`, default tablespace |
| G3 | Подтверждён single-tenant режим на `llm2` | Owner | ✅ 2026-05-01 — single-tenant (`tenant_id = 'llm2'`) |
| G4 | `maintenance_work_mem` ≥ 2 GB на сессию исполнения DDL | Owner (по baseline) | ✅ 2026-05-01 — `SET LOCAL` per-session, специальных прав не требует |
| G5 | Согласована роль/пользователь, исполняющая DDL и получающая права | Owner | ✅ 2026-05-01 — DB-user **`llm2`** (имя пользователя БД равно имени стенда); CREATE даёт OWNER-права автоматически |
| G6 | Окно работ | Owner | ✅ 2026-05-01 — отдельное окно не требуется, DDL bootstrap'ом при первом старте JAR |
| G7 | Подтверждён исходящий доступ `llm2 → *.api.cloud.yandex.net:443` | Owner | ✅ 2026-05-01 |

**Все gate'ы закрыты.** DEVOPS-001 готов к исполнению — DDL исполнится автоматически при первом старте JAR-модуля на стенде через Hibernate `sessionFactory`.

## 3. Параметры миграции

| Параметр | Значение | Источник |
|----------|----------|----------|
| Имя таблицы | `pg_vector_service__vectors` | ADR-004 §Decision |
| Схема | `public` | baseline (`createVectorTable`) |
| Tablespace | default | baseline (явно не задаётся) |
| Размерность вектора | `vector(256)` | ADR-010 §1 (text-search-doc/query, dim=256) |
| Метрика расстояния | `vector_cosine_ops` (cosine) | ADR-010 §5, pgvector-indexes.md §3.1 |
| HNSW `m` | 16 | ADR-010 §5 (default для медианы 100k-300k) |
| HNSW `ef_construction` | 64 | ADR-010 §5 (default) |
| `maintenance_work_mem` на DDL | `2GB` (per-session `SET LOCAL`) | pgvector-indexes.md §3.1 |
| DB-user / owner-role таблицы | **`llm2`** | Owner, 2026-05-01 |
| Канал исполнения DDL | **Hibernate `SessionFactory`** через Spring `beanFactory.getBean("sessionFactory")`. DDL — через `session.doWork { Connection conn -> conn.prepareStatement(ddl).execute() }` | Owner, 2026-05-01 |
| Способ исполнения DDL | **Bootstrap модуля** при первом старте JAR (idempotent — `CREATE TABLE/INDEX IF NOT EXISTS`) | вариант A, Owner |

## 4. DDL (предлагаемый — ожидает sign-off)

```sql
-- ============================================================================
-- pg_vector_service: миграция вектор-таблицы (PoC iter 1)
-- Соответствует ADR-004 (schema) + ADR-010 (dim=256, cosine)
-- ============================================================================

-- 0. Подтверждаем наличие расширения (idempotent).
--    Если расширения нет — выполнить отдельно по runbook'у DBA.
CREATE EXTENSION IF NOT EXISTS vector;

-- 1. Сессионные параметры на время DDL.
SET LOCAL maintenance_work_mem = '2GB';

-- 2. Таблица.
CREATE TABLE IF NOT EXISTS pg_vector_service__vectors (
    object_id          uuid          NOT NULL,
    meta_class         text          NOT NULL,
    tenant_id          text          NOT NULL,
    model_version      text          NOT NULL,
    whitelist_version  integer       NOT NULL DEFAULT 1,
    embedding          vector(256)   NOT NULL,
    composite_hash     bytea         NOT NULL,
    vectorized_at      timestamptz   NOT NULL,
    dirty              boolean       NOT NULL DEFAULT false,
    created_at         timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT pg_vector_service__vectors_pk
        PRIMARY KEY (object_id, meta_class, tenant_id)
);

COMMENT ON TABLE pg_vector_service__vectors IS
    'Векторные представления SMP-объектов (issue / knowledgeBase / problem). См. ADR-004.';
COMMENT ON COLUMN pg_vector_service__vectors.model_version IS
    'modelUri + pinned-версия embedding-модели (ADR-010), формат: "text-search-doc:06.12.2023".';
COMMENT ON COLUMN pg_vector_service__vectors.composite_hash IS
    'SHA-256 от composite-text + версия чанкинг-стратегии. Идемпотентность UC1 (NFR-020).';
COMMENT ON COLUMN pg_vector_service__vectors.dirty IS
    'Маркер «требует пересчёта». Может дублировать SMP-атрибут vector_dirty (ADR-003).';

-- 3. HNSW-индекс на embedding (cosine).
CREATE INDEX IF NOT EXISTS pg_vector_service__vectors__embedding_hnsw_idx
    ON pg_vector_service__vectors
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- 4. B-tree на composite_hash для idempotency-проверки.
CREATE INDEX IF NOT EXISTS pg_vector_service__vectors__composite_hash_idx
    ON pg_vector_service__vectors (composite_hash);

-- 5. ANALYZE — статистика для планировщика после первой загрузки.
ANALYZE pg_vector_service__vectors;
```

**Замечания к DDL:**

- `IF NOT EXISTS` — на случай повторного исполнения (idempotency).
- `created_at` — добавлено сверх ADR-004 для отладки (когда строка появилась). Можно убрать, если DBA возражает.
- Нет `TABLESPACE …` — default. Если DBA выделит отдельный tablespace, добавить.
- Нет `WITH (fillfactor = …)` — pgvector на инкрементальных insert'ах не требует тюнинга fillfactor для HNSW; при необходимости — отдельная миграция.
- Нет partial-индексов на `meta_class` — на PoC одна таблица, partial-индексы можно добавить миграцией без перестройки данных, если расход на стенде станет проблемой.
- Нет grant'ов — права выдаются после sign-off G5 (см. §6).

## 5. Открытые вопросы к DBA / Сахабетдинову

См. структурированный список в [OWNER-001 tracking-doc](../../00-project/owner-questions/owner-001-pgvector-ddl.md). Кратко:

1. Схема (`public` или отдельная)?
2. Tablespace (default или dedicated)?
3. От чьего имени исполнять DDL? Какая роль владелец таблицы?
4. Какая роль у SMP-инстанса для read/write этой таблицы (пользователь, через которого SMP коннектится к БД)?
5. Какое окно работ?
6. Single-tenant или multi-tenant на `llm2`? (влияет на смысл `tenant_id`-колонки и фильтры в адаптере, не на DDL)
7. `maintenance_work_mem` 2GB — допустимо per-session, или нужно поднимать на инстансе?

## 6. Процедура исполнения

DDL исполняется автоматически при **первом старте JAR-модуля** на стенде. Логика — в bootstrap-классе модуля (DEV-030 `VectorModuleBootstrap`). Отдельный DBA-runbook не требуется (вариант B оставлен только для миграций при смене размерности по ADR-007).

### 6.1. Архитектура bootstrap'а

В JAR-классах **`@InjectApi` не работает runtime** (поля остаются null — известное ограничение, см. эталонный проект `naumen-smp-mcp`, memory `reference_inject_api_jar_limitation.md`). Поэтому SMP-binding (`api`, `beanFactory`) держит script-module и передаёт в JAR через конструктор. Паттерн полностью повторяет [`SmpSuperUserRunner`](file:///Users/mdemyanov/Devel/naumen-smp-mcp/src/main/groovy/ru/naumen/modules/mcp/adapters/smp/SmpSuperUserRunner.groovy) из эталона.

**Класс-обёртка:** `adapters/db/HibernateSessionProvider.groovy`

```groovy
package ru.naumen.modules.pgvector.adapters.db

import groovy.transform.CompileDynamic
import org.hibernate.Session
import org.hibernate.SessionFactory

@CompileDynamic
class HibernateSessionProvider {
    private final def beanFactory
    private final def api

    HibernateSessionProvider(def beanFactory, def api) {
        this.beanFactory = beanFactory
        this.api = api
    }

    /**
     * Запускает action в одной транзакции с Hibernate-сессией.
     * Аналог SmpSuperUserRunner.callAsSuper, но без elevation:
     * scheduledTask и так исполняется под системным юзером.
     */
    def <T> T inSession(Closure<T> action) {
        SessionFactory sf = beanFactory.getBean('sessionFactory') as SessionFactory
        (T) api.tx.call {
            action.call(sf.getCurrentSession())
        }
    }
}
```

**Bootstrap-логика DDL:** `config/VectorModuleBootstrap.groovy`

```groovy
package ru.naumen.modules.pgvector.config

@CompileDynamic
class VectorModuleBootstrap {
    private final HibernateSessionProvider sessionProvider

    VectorModuleBootstrap(HibernateSessionProvider sessionProvider /*, ... */) {
        this.sessionProvider = sessionProvider
    }

    void migrate() {
        sessionProvider.inSession { Session session ->
            session.doWork { java.sql.Connection conn ->
                conn.prepareStatement("CREATE EXTENSION IF NOT EXISTS vector").execute()
                conn.prepareStatement("SET LOCAL maintenance_work_mem = '2GB'").execute()

                conn.prepareStatement('''
                    CREATE TABLE IF NOT EXISTS pg_vector_service__vectors (
                        object_id          uuid          NOT NULL,
                        meta_class         text          NOT NULL,
                        tenant_id          text          NOT NULL,
                        model_version      text          NOT NULL,
                        whitelist_version  integer       NOT NULL DEFAULT 1,
                        embedding          vector(256)   NOT NULL,
                        composite_hash     bytea         NOT NULL,
                        vectorized_at      timestamptz   NOT NULL,
                        dirty              boolean       NOT NULL DEFAULT false,
                        created_at         timestamptz   NOT NULL DEFAULT now(),
                        CONSTRAINT pg_vector_service__vectors_pk
                            PRIMARY KEY (object_id, meta_class, tenant_id)
                    )
                ''').execute()

                conn.prepareStatement('''
                    CREATE INDEX IF NOT EXISTS pg_vector_service__vectors__embedding_hnsw_idx
                        ON pg_vector_service__vectors
                        USING hnsw (embedding vector_cosine_ops)
                        WITH (m = 16, ef_construction = 64)
                ''').execute()

                conn.prepareStatement('''
                    CREATE INDEX IF NOT EXISTS pg_vector_service__vectors__composite_hash_idx
                        ON pg_vector_service__vectors (composite_hash)
                ''').execute()
            }
        }
    }
}
```

**Точка входа из SMP script-module:** `public/InitVectorModule.groovy` (или регистрируемый action)

```groovy
import ru.naumen.modules.pgvector.adapters.db.HibernateSessionProvider
import ru.naumen.modules.pgvector.config.VectorModuleBootstrap

// `this` script держит SMP-binding (api, beanFactory, modules)
def sessionProvider = new HibernateSessionProvider(this.beanFactory, this.api)
new VectorModuleBootstrap(sessionProvider).migrate()
```

**Замечания:**

- Никакой string interpolation — DDL hard-coded строками; параметризация для DDL не нужна (нет user input'а).
- `IF NOT EXISTS` — idempotency, повторный старт JAR не падает.
- `api.tx.call` оборачивает в транзакцию (паттерн из эталона); commit при успешном выходе, rollback при исключении.
- GRANT не нужен — таблица создаётся под пользователем `llm2` (он же owner), который уже имеет полные права через CREATE.
- Elevation (`callAsSuperUser`) для DDL в свою таблицу не нужно — `scheduledTask` и обычный SMP-binding уже идут под системным юзером с правами на БД.

### 6.2. Verify (через тот же канал)

```groovy
session.createNativeQuery(
    "SELECT extname, extversion FROM pg_extension WHERE extname = 'vector'"
).getResultList()
// ожидаем: [vector, 0.8.1]

session.createNativeQuery('''
    SELECT indexname FROM pg_indexes
     WHERE tablename = 'pg_vector_service__vectors'
''').getResultList()
// ожидаем: 3 индекса (PK + hnsw_idx + composite_hash_idx)
```

### 6.3. Smoke (после bootstrap'а)

```groovy
// Тестовая вставка вектора
String testVector = '[' + (0..<256).collect { '0.01' }.join(',') + ']'
session.createNativeMutationQuery('''
    INSERT INTO pg_vector_service__vectors
      (object_id, meta_class, tenant_id, model_version, embedding, composite_hash, vectorized_at)
    VALUES
      (gen_random_uuid(), :metaClass, :tenant, :model, CAST(:vec AS vector(256)),
       decode('aabbcc', 'hex'), now())
''')
.setParameter('metaClass', 'knowledgeBase$article')
.setParameter('tenant', 'llm2')
.setParameter('model', 'text-search-doc:06.12.2023')
.setParameter('vec', testVector)
.executeUpdate()

// KNN-запрос с EXPLAIN ANALYZE — должен попадать в hnsw_idx (не Seq Scan)
session.createNativeQuery('''
    EXPLAIN ANALYZE
    SELECT object_id, embedding <=> CAST(:vec AS vector(256)) AS distance
      FROM pg_vector_service__vectors
     ORDER BY embedding <=> CAST(:vec AS vector(256))
     LIMIT 5
''').setParameter('vec', testVector).getResultList()

// Чистка теста
session.createNativeMutationQuery('''
    DELETE FROM pg_vector_service__vectors
     WHERE meta_class = 'knowledgeBase$article' AND tenant_id = 'llm2'
''').executeUpdate()
```

## 7. Rollback

```sql
BEGIN;
DROP TABLE IF EXISTS pg_vector_service__vectors CASCADE;
COMMIT;
```

Расширение `vector` НЕ удаляется (могут быть другие потребители; политика удаления — на стороне DBA).

## 8. История

| Дата | Кто | Что |
|------|-----|-----|
| 2026-05-01 | PM (Демьянов через AI-агенты) | Первый draft на основе ADR-004 + ADR-010. |
| 2026-05-01 | Owner (Демьянов) | Conditional approval: schema/tablespace/owner-role/maintenance_work_mem подтверждены через действующий baseline-скрипт. Single-tenant и сетевой доступ к YC FM подтверждены. |
| 2026-05-01 | Owner (Демьянов) | Approval (final): SMP DB-user = `llm2`. Канал доступа — Hibernate `sessionFactory` через Spring `beanFactory` (не `modules.localSql`). DDL переписан на bootstrap-логику через `session.doWork(...)` — отдельное окно работ не нужно. Все gate'ы закрыты. |

## 10. Референс baseline

В контуре уже работает PoC-скрипт, который реализует аналогичный паттерн на per-class-таблицах (`es_${classId}_vector`):

`/Users/mdemyanov/IdeaProjects/ITSM 365/src/ru/nsmp/yandex/gpt/modules/Вспомогательный модуль для векторизации.groovy`

Что мы наследуем как **установленный факт**:

- DDL исполняется через `modules.localSql.update(...)` — SMP-API на тот же connection pool, доступен из script-модуля.
- Схема — `public`, владельцем становится SMP DB-user (тот же, через которого SMP коннектится в БД).
- pgvector доступен из `modules.localSql` (тип `vector`, оператор `<=>` cosine distance), работает на инстансе.
- `CREATE TABLE` / `CREATE INDEX` / `INSERT` / `SELECT` / `DELETE` от имени SMP DB-user'а — права уже есть.

Что мы **меняем относительно baseline** (новый модуль):

| Аспект | Baseline | Новый модуль | Обоснование |
|--------|----------|--------------|-------------|
| Структура таблиц | per-class (`es_kb_vector`, `es_issue_vector`, ...) | одна `pg_vector_service__vectors` с дискриминатором `meta_class` | ADR-004 §Alternatives — упрощает cross-class similarity (UC2 FR-005), меньше DDL при добавлении класса |
| Foreign key | `FK ON tbl_${classId}(id)` | нет FK | ADR-004 — изоляция от системных SMP-таблиц, апгрейд платформы не ломает связи |
| Размерность | `vector` (без N) | `vector(256)` | ADR-010 — dim фиксирован моделью, явная типизация даёт constraint и оптимизирует HNSW |
| Версионирование модели | нет | колонка `model_version` (NOT NULL) | NFR-030, ADR-007 — поддержка blue-green миграции при смене модели |
| Идемпотентность | нет | колонка `composite_hash` + B-tree | NFR-020 — повторный прогон UC1-джобы не делает YC FM-вызов |
| Тенант-изоляция | нет | колонка `tenant_id` в PK | ADR-004 §Decision — multi-tenant ready, на PoC `'llm2'` константа |
| Whitelist-версия | нет | колонка `whitelist_version` | NFR-032, ADR-005 — изменения whitelist'а инвалидируют затронутые векторы |
| Индекс | B-tree на `ext_id` | HNSW на `embedding (vector_cosine_ops)` + B-tree на `composite_hash` | ADR-010, pgvector-indexes.md — KNN p95 ≤ 500ms |
| Чанкинг | хранится несколько строк на объект (`number`) | в PK заложена возможность расширения (`chunk_index` колонка default 0 — миграция без переноса данных) | ADR-006 (открытое решение) |

## 9. Связанные артефакты

- [ADR-004 — Vector storage schema](../../00-project/adr/004-vector-storage-schema.md)
- [ADR-010 — Embedding model selection](../../00-project/adr/010-embedding-model-selection.md)
- [ADR-002 — SMP-only data access](../../00-project/adr/002-smp-only-data-access.md) (DDL вне runtime модуля)
- [ADR-007 — Model versioning migration](../../00-project/adr/007-model-versioning-migration.md) (последующие миграции при смене модели)
- [pgvector-indexes.md — research](../../10-domain/research/pgvector-indexes.md) §3.1, §7
- [OWNER-001 tracking](../../00-project/owner-questions/owner-001-pgvector-ddl.md)
- [Backlog DEVOPS-001](../../00-project/backlog.md#c-devops-задачи)
