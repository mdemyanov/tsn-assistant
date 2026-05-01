---
order: 20
title: "ADR-002: SMP-only data access (запрет JDBC)"
properties:
  - Тип контента: ADR
  - Фаза: PoC
  - Статус: Draft
---

# ADR-002: SMP-only data access (запрет JDBC)

**Status:** Draft (требует апдейта по итогам [OWNER-001](../owner-questions/owner-001-pgvector-ddl.md), 2026-05-01 — см. SA-011)
**Date:** 2026-05-01

> **⚠ Апдейт ожидается (SA-011, 2026-05-01).** Owner уточнил, что доступ к БД из JAR-модуля идёт через **Hibernate `SessionFactory`** (Spring `beanFactory.getBean('sessionFactory')`), а не через `api.db.query` SMP. Это санкционированный платформой канал, не нарушает «прямого доступа нет» (он шире: запрещён прямой JDBC и тащить `org.postgresql.*` в `pom.xml` JAR'а). Текущая формулировка ADR-002 — частный случай этого правила и временно остаётся в силе как red-line по JDBC-зависимостям. Полная переформулировка в терминах Hibernate — задача [SA-011](../backlog.md#b-архитектурные-решения-требующие-исполнения).

## Context

База данных стенда `llm2`, где живут SMP-объекты и pgvector-таблица векторов, **физически защищена** от прямых сетевых подключений из модулей. Это не предмет архитектурного выбора, а данность инфраструктуры: подтверждено owner'ом (Демьянов) и зафиксировано в CLAUDE.md в разделе «Доступ к окружению»:

> PostgreSQL/pgvector: прямого подключения нет. Все операции с векторной таблицей — через SMP API (HQL `api.db.query` для чтения, REST `/edit`, `/create` или скрипт-метод модуля для записи). При проектировании в `/sa` это жёсткое ограничение: никаких JDBC-адаптеров напрямую к БД.

NFR из `content/30-requirements/non-functional/nfr-cross-cutting.md`:

- **NFR-006** — модуль не открывает JDBC-соединений к PostgreSQL стенда. Любые операции с векторной таблицей — через SMP API: HQL `api.db.query` (read-only), REST `/find` `/edit` `/create` или script-методы модуля.
- **NFR-040** — архитектурный red-line: проектное решение SA не должно вводить компонент с прямым JDBC к БД; «оптимизирующие» обходы (прямой connection-pool к pgvector) отклоняются.
- **NFR-043** — все HQL-запросы параметризованные через `setParameter`, без интерполяции строк.

Use case-уровневые подтверждения: BR-006 в [UC1](../../30-requirements/functional/uc1-scheduled-vectorization) («Доступ к БД — только через SMP API. Прямой JDBC-доступ из модуля к PostgreSQL запрещён архитектурно. DDL-операции — отдельный runbook DBA, не зона ответственности джобы»); AC-013 («Code review: ни одной прямой JDBC-зависимости в src/, проверяется автоматически — ban-list зависимостей в pom.xml / CodeNarc-правило»).

Открытые вопросы исследования (`content/10-domain/research/pgvector-indexes.md` § 7-8): какая стратегия DDL допустима через SMP API (`CREATE EXTENSION vector`, `CREATE INDEX … USING hnsw`), кто и через какой механизм её выполняет (DBA-side скрипт vs специальный SMP-метод модуля с `executeUpdate`), какие версии pgvector установлены на `llm2` — эти вопросы открыты к Сахабетдинову.

## Decision

Фиксируется: **все операции `pg_vector_service` с данными SMP и pgvector выполняются исключительно через SMP API**. Конкретные допустимые механизмы:

**Чтение:**
- `api.db.query(hql).setParameter(name, value)` — read-only HQL-запросы по SMP-объектам и собственной векторной таблице (если она зарегистрирована как FQN или доступна через HQL-mapping; иначе только через REST).
- REST `/find/{fqn}`, `/get/{uuid}` — операции выборки SMP-объектов (use case ACL-фильтрации `kbAccesses` для UC2 BR-002).

**Запись:**
- REST `/edit/{uuid}`, `/create/{fqn}` — для записи метаданных в SMP-атрибуты (например, маркер `vector_dirty` — UC1 FR-007, если выбираем атрибутный вариант в соответствующем ADR).
- Script-метод модуля (Groovy-метод на сервере SMP) с `api.db.query` или платформенным `executeUpdate` — для batch-записи в pgvector-таблицу.

**Запрещено архитектурно:**
- Прямой `java.sql.DriverManager.getConnection(...)` или любой JDBC-pool (HikariCP, c3p0 и т.д.) к PostgreSQL стенда.
- Любые библиотеки векторного клиента, открывающие собственное TCP-соединение к pgvector (например, неофициальные обёртки).
- Локальные JDBC-соединения в тестах против реального стенда (offline-eval допускает только in-memory фейки в `adapters/test/`).

**Защита границы (нативно поддерживается ADR-001 layout'ом):**
- В `pom.xml` нет JDBC-драйвера PostgreSQL и нет JDBC-pool библиотек.
- `adapters/smp/` использует только `@InjectApi` и `api.*` SMP-методы.
- `core/` (по ADR-001) не импортирует ни `java.sql.*`, ни `javax.sql.*` — это правило добавляется в `CoreBoundarySpec`.
- CodeNarc-правило (по образцу эталона `naumen-smp-mcp`): запрет интерполяции строк в HQL — `import` `java.sql.*` в любом пакете кроме `adapters/test/`.
- Code review релизной ветки проверяет: `mvn dependency:tree` не содержит `org.postgresql:postgresql`.

**DDL (создание таблицы / индекса HNSW / `CREATE EXTENSION vector`)** — выполняется DBA-стороной:

- Координация с Сахабетдиновым: миграционный SQL-скрипт согласовывается до первой Dev-итерации; runbook оформляет DevOps в `content/70-operations/`.
- Альтернативный путь (если DBA откажет в DDL-доступе) — выделенный SMP script-метод модуля с разовым `api.db.query` `executeUpdate` (если SMP API это допускает), вызываемый администратором вручную через console. Конкретный путь — open question (см. OQ-IDX-2 в `content/10-domain/research/pgvector-indexes.md`).

## Consequences

**Positive:**

- **Безопасность:** единая точка аудита — все обращения проходят через SMP-логирование и контекст пользователя; PII-доступ контролируется ACL платформы (важно для UC2 BR-002 `kbAccesses` и UC3 BR-003).
- **Изоляция от инфра-изменений:** смена расположения БД, миграция на managed PostgreSQL, изменение учётных записей — невидимы для модуля. Не нужны secret-файлы с DB-credentials в JAR (NFR-005 для YC IAM применяется только к Yandex-ключу).
- **Соответствие политике:** не будет конфликта с DBA / security-командой заказчика; модуль укладывается в стандартный профиль SMP-расширения.
- **Тестируемость ядра:** `core/` (ADR-001) тестируется в-памяти, без поднятия PostgreSQL — фейки `VectorStoragePort` не зависят от JDBC.

**Negative:**

- **DDL вне runtime:** `CREATE INDEX hnsw … vector_cosine_ops`, `ALTER TABLE …` через `api.db.query` read-only **не выполняются**. Любая миграция требует ручной координации с DBA, увеличивает срок на Dev-итерацию (Plan / runbook before code).
- **Performance overhead:** обращение через SMP API дороже прямого SQL (платформенный round-trip, ACL-фильтр); для batch-операций UC1 это компенсируется размером батча (FR-011), но точная оценка throughput требует smoke-замера на `llm2` (RES — открытый вопрос).
- **Ограничение в выборе фич pgvector:** некоторые фичи (например, GUC `hnsw.ef_search` per-session — `pgvector-indexes.md` § 3.1) требуют `SET LOCAL` через прямой SQL. Через SMP API это либо невозможно, либо требует platform-level настройки. Конкретный список ограничений — open question, фиксируется в архитектурной статье поверх SA-сессий.

**Mitigations:**

- **DDL runbook** оформляется до первой Dev-итерации в `content/70-operations/runbooks/pgvector-ddl.md` (DevOps): конкретный набор SQL-команд, кто их выполняет, как откатить, как мониторить (длительность build HNSW при `maintenance_work_mem` ≥ 2 GB — RES OQ-IDX-3).
- **Bench performance overhead** SMP API vs прямого SQL — обязательная Dev-итерация после первого smoke на `llm2` (включить в PoC roadmap).
- **Версионирование схемы:** изменения структуры pgvector-таблицы — отдельные ADR с superseded-ссылкой (red-line CLAUDE.md). DDL-runbook — приложение к ADR.
- **Architecture test:** `JdbcImportBanSpec` в `src/test/groovy/.../architecture/` проверяет на каждом CI-прогоне, что `java.sql.*` / `javax.sql.*` не импортируется ни в `core/`, ни в `adapters/`.

## Alternatives Considered

- **Read-only JDBC для метрик и offline-eval** (отдельный read-replica с ограниченными правами): сократил бы overhead на heavy-read сценариях UC2 NFR-001 (p95 ≤ 200 ms на 100k объектов). Отвергнуто — политически (DBA / security не одобрят прямое подключение даже к replica) и сетево (стенд `llm2` физически закрыт от внешних подключений). Вторая причина: смена на JDBC «только для чтения» легко мутирует в «и для записи на быстрых путях» — нарушение дисциплины через 1-2 рефакторинга.
- **Прямой JDBC только в DDL-инициализаторе (one-shot скрипт на старте модуля)**: сократил бы зависимость от DBA на этапе bootstrap. Отвергнуто — JDBC-драйвер всё равно попадает в JAR (vulnerability surface, `jar-secrets-scan` flag), а DDL — единичная операция, ручной runbook DBA её закрывает без зависимости в коде.
- **Локальный embedded PostgreSQL для тестов (Testcontainers)**: разрешить JDBC только в `src/test/`. Отвергнуто для PoC — увеличивает test-runtime, требует Docker на CI, дублирует логику фейков из `adapters/test/`. После PoC можно вернуть для интеграционных тестов адаптера, но это отдельный ADR.

## Связанные статьи

- [UC1 — Scheduled vectorization](../../30-requirements/functional/uc1-scheduled-vectorization) — BR-006 (только SMP API, без JDBC), AC-013 (CI-проверка отсутствия JDBC в `pom.xml`).
- [UC2 — Similarity search](../../30-requirements/functional/uc2-similarity-search) — BR-002 (`kbAccesses` фильтр через SMP API, не через прямой SQL), Q5 (стратегия фильтрации — открытый вопрос для отдельного ADR).
- [UC3 — Duplicate detection](../../30-requirements/functional/uc3-duplicate-detection) — бриф для SA: «обход через прямой доступ к векторной таблице запрещён».
- [Cross-cutting NFR](../../30-requirements/non-functional/nfr-cross-cutting) — NFR-006, NFR-040, NFR-043.
- [pgvector — выбор индекса](../../10-domain/research/pgvector-indexes) — § 7 «DDL только через DBA», открытые вопросы OQ-IDX-1…3.
- ADR-001 (Hexagonal architecture) — `adapters/smp/` как единственная точка SMP-доступа; `CoreBoundarySpec` ловит нарушения.
- ADR-004 (Vector storage schema) — конкретная схема таблицы и согласование DDL с DBA.
- CLAUDE.md, разделы «Доступ к окружению» и «Красные линии».
