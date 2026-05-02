---
order: 10
title: "OWNER-001: согласование DDL вектор-таблицы"
properties:
  - Тип контента: Прочее
  - Фаза: PoC
  - Статус: Approved
---

# OWNER-001 — согласование DDL вектор-таблицы (ADR-004)

**Адресат:** Марат Сахабетдинов (DevOps `llm2`) — Telegram `@u2mario`, email `msakhabetdinov@naumen.ru` *(не понадобился — все ответы получены от owner'а через baseline-скрипт)*
**Инициатор:** Максим Демьянов (Owner)
**Открыто:** 2026-05-01
**Закрыто:** 2026-05-01 — owner ответил на все 9 пунктов через baseline-скрипт + прямые подтверждения. Канал доступа уточнён: **Hibernate `sessionFactory` через `beanFactory.getBean("sessionFactory").getCurrentSession()`**, не `modules.localSql`.
**Блокирует:** [DEVOPS-001](../backlog.md#c-devops-задачи) — статус переведён в `ready` (без отдельного окна работ — DDL исполняется bootstrap'ом модуля при первом старте).
**Связано:** [OWNER-003](../backlog.md#a-внешние-блокеры-phase-0-pre-flight) (single vs multi-tenant — ответ owner: single)

## 1. Зачем нужен sign-off

`pg_vector_service` — JAR-модуль для Naumen SMP, добавляющий векторизацию SMP-объектов (issue / knowledgeBase / problem) для семантического поиска и обнаружения дублей. Векторы хранятся в выделенной таблице `pg_vector_service__vectors` в БД стенда `llm2` ([ADR-004](../adr/004-vector-storage-schema.md), [ADR-010](../adr/010-embedding-model-selection.md)). Доступ к БД — только через SMP API ([ADR-002](../adr/002-smp-only-data-access.md)), но **DDL не выполняется кодом модуля** — выполняется DBA-стороной по runbook'у. До исполнения DDL нужно согласовать ряд параметров с DevOps `llm2`.

Что уже подтверждено владельцем стенда (2026-05-01):

- ✅ pgvector **0.8.1** установлен на БД `llm2`.
- ⏳ согласование схемы / прав / окна — в работе.
- ⏳ исходящий доступ `llm2 → *.api.cloud.yandex.net:443` — в работе.

Текущая задача — закрыть открытые пункты письменным sign-off'ом и запустить DEVOPS-001.

## 2. Контекст в одном экране

| Параметр | Значение | Источник |
|----------|----------|----------|
| Назначение таблицы | Хранение векторов SMP-объектов (PoC: knowledgeBase$article, problem, issue + подклассы) | ADR-004 |
| Имя таблицы | `pg_vector_service__vectors` | ADR-004 |
| Размерность вектора | `vector(256)` (фиксировано — Yandex Cloud `text-search-doc`/`text-search-query`, modelVersion `06.12.2023`) | ADR-010 |
| Метрика | cosine (`vector_cosine_ops`) | ADR-010, pgvector-indexes.md |
| Индекс | HNSW `m=16, ef_construction=64` | ADR-010 §5 |
| Ожидаемые объёмы | медиана 100k–300k объектов на тенант, headroom до 1М (PoC — стенд `llm2`) | CLAUDE.md, roadmap |
| Доступ из модуля | только через SMP API (HQL read + SMP script-метод write) — JDBC напрямую запрещён ADR-002 | ADR-002 |
| Запись DDL | DBA-стороной по runbook'у, **не runtime** модуля | ADR-002, ADR-004 |

Полный draft DDL и процедура исполнения — в [Runbook: миграция вектор-таблицы](../../70-operations/runbooks/runbook-vector-table-migration.md).

## 3. Что просим у Сахабетдинова (sign-off-list)

Восемь пунктов. По каждому — конкретный ожидаемый ответ (Y / N / значение). Можно ответить одним сообщением «по пунктам».

| # | Вопрос | Что предлагаем по умолчанию | Ожидаемая форма ответа |
|---|--------|----------------------------|-----------------------|
| **Q1** | В какую **схему** создавать таблицу? | `public` | имя схемы (или `public`) |
| **Q2** | В какой **tablespace**? | default | `default` или имя tablespace'а |
| **Q3** | От имени какой **роли исполнять DDL** (CREATE TABLE/INDEX, GRANT)? | DBA-роль или роль с правом CREATE на схеме | имя роли |
| **Q4** | Какая роль будет **владельцем таблицы** (для будущих ALTER / DROP)? | роль из Q3 | имя роли |
| **Q5** | Какому **пользователю SMP-инстанса** дать `SELECT/INSERT/UPDATE/DELETE` на таблицу (через какого юзера SMP ходит в БД)? | — нужно указать | имя пользователя |
| **Q6** | Допустимо ли `SET LOCAL maintenance_work_mem = '2GB'` per-session на DDL, или нужно поднимать на инстансе? | per-session OK | `per-session OK` / иначе предложение |
| **Q7** | Какое **окно работ** для DDL (минут, ожидаемый downtime для SMP — нет, но согласовать)? | 30 минут в любое рабочее окно — DDL пустой таблицы быстрый | дата/время + длительность |
| **Q8** | На стенде `llm2` **single-tenant или multi-tenant**? Если multi — есть ли logical-name тенанта, который мы пишем в `tenant_id`? | single-tenant (`tenant_id = 'llm2'` константа) | `single` / `multi` + имена тенантов |

**Дополнительно (не блокер DDL, но просим закрыть тем же раундом):**

| # | Вопрос | По умолчанию | Ответ |
|---|--------|--------------|-------|
| **Q9** | Письменно подтвердить открытие сетевого доступа `llm2 → *.api.cloud.yandex.net:443` (для вызовов Yandex Cloud Foundation Models из JAR-модуля). | — открываете / уже открыто / нужны заявки | подтверждение или ETA |

## 4. Артефакты для согласования

- [Runbook миграции](../../70-operations/runbooks/runbook-vector-table-migration.md) — содержит полный draft DDL, процедуру и rollback. **Просим прочитать §3-§7.**
- [ADR-004 — Vector storage schema](../adr/004-vector-storage-schema.md) — обоснование структуры таблицы, альтернативы.
- [ADR-010 — Embedding model selection](../adr/010-embedding-model-selection.md) — обоснование `vector(256)` и cosine-метрики.

## 5. После sign-off

1. Зафиксировать ответы Сахабетдинова в этом файле (§7 ниже).
2. Обновить [Runbook миграции](../../70-operations/runbooks/runbook-vector-table-migration.md) — заполнить роли/схему/tablespace, статус `Draft → Approved`.
3. Согласовать конкретное окно (Q7) и запустить исполнение DDL (DEVOPS-001 → in-progress).
4. После исполнения — отчёт о выполнении DDL (verify-секция runbook'а) → DEVOPS-001 → done.
5. Закрыть OWNER-001 в backlog'е (`todo → done`).

## 6. Каналы и формат

- **Telegram (`@u2mario`)** — короткое сообщение со ссылкой на этот файл и runbook (используем для PoC-проектов, как в SD AI Assistant).
- **Email (`msakhabetdinov@naumen.ru`)** — дублирование с тем же содержанием (для письменного следа).
- Ожидаемый SLA ответа — 3 рабочих дня. После 5 дней — эскалация Сазоновой (cc на письме).

Тексты сообщений — в §8 этого файла.

## 7. Ответы

> Q1, Q3-Q6 закрыты ссылкой на действующий baseline-скрипт. Q8/Q9 — owner. Q7 и точное имя SMP DB-user'а — последний минимальный остаток для уточнения у Сахабетдинова.

**Источник для Q1, Q3-Q6:** действующий PoC-скрипт `Вспомогательный модуль для векторизации.groovy` (`/Users/mdemyanov/IdeaProjects/ITSM 365/src/ru/nsmp/yandex/gpt/modules/`). Скрипт уже работает на инстансе и:

- создаёт вектор-таблицы в схеме `public` (`CREATE TABLE public.es_${classId}_vector ...`);
- выполняет DDL/DML через `modules.localSql.update(...)` — это SMP-API, который ходит в БД от имени **того же пользователя, через которого SMP-инстанс коннектится к БД** (этот юзер уже имеет CREATE TABLE/INDEX в `public` + SELECT/INSERT/UPDATE/DELETE);
- использует pgvector-тип `vector` (без размерности — для baseline; в новом модуле фиксируем `vector(256)`);
- не настраивает `maintenance_work_mem` явно (default'а хватает на текущих объёмах baseline'а; для HNSW на 100k+ объектах — закладываем `SET LOCAL` per-session, специальных прав не требует).

| # | Вопрос | Ответ | Источник |
|---|--------|-------|----------|
| Q1 | Схема | **`public`** | baseline §`createVectorTable`, `isTableExist` |
| Q2 | Tablespace | **default** | baseline (явно не задаётся) |
| Q3 | Роль для DDL | **SMP DB-user** (тот, через которого работает `modules.localSql`) | baseline (DDL через `modules.localSql.update`) |
| Q4 | Owner таблицы | **SMP DB-user** (он же исполнитель DDL) | baseline |
| Q5 | SMP DB-user (grant target) | **`llm2`** (имя пользователя БД равно имени стенда; CREATE даёт автоматически OWNER-права; отдельный GRANT не нужен) | Owner (Демьянов), 2026-05-01 |
| Q6 | `maintenance_work_mem = '2GB'` | **`SET LOCAL` per-session** — не требует superuser-прав, baseline вообще не настраивает (default достаточен на нынешних объёмах). На время первой массовой загрузки ставим явно | pgvector-indexes.md §3.1 + baseline |
| Q7 | Окно работ | **не нужно отдельное окно** — DDL исполняется bootstrap'ом модуля при первом старте через `sessionFactory.doWork(...)`, операция секундная, idempotent (`CREATE TABLE/INDEX IF NOT EXISTS`) | вариант A + Hibernate-канал |
| Q8 | Single/multi-tenant | **single-tenant** (`tenant_id = 'llm2'` константа) | Owner (Демьянов), 2026-05-01 |
| Q9 | Сетевой доступ `llm2 → *.api.cloud.yandex.net:443` | **подтверждён** | Owner (Демьянов), 2026-05-01 |

**Архитектурный вопрос — закрыт 2026-05-01.**

Owner уточнил: **канал доступа к БД из JAR — Hibernate `sessionFactory` через Spring `beanFactory`**, не `modules.localSql` (он был приведён в baseline только для примера).

```groovy
// Получение Hibernate-сессии в SMP script-модуле / JAR-модуле:
import org.hibernate.Session
import org.hibernate.SessionFactory

SessionFactory sf = beanFactory.getBean("sessionFactory") as SessionFactory
Session session = sf.getCurrentSession()
```

Доступные методы (полный перечень `getCurrentSession().getMetaClass().getMethods()` сохранён в memory) включают:

- `createNativeQuery(String)` / `createNativeQuery(String, Class)` — для DDL и SQL с pgvector-операторами (`<=>`).
- `createMutationQuery(...)` / `createNativeMutationQuery(...)` — для INSERT/UPDATE/DELETE.
- `doWork(Work)` / `doReturningWork(ReturningWork)` — прямой доступ к JDBC `Connection` для PreparedStatement с binding `vector` через `PGobject`/`setObject` (важно для NFR-043 — параметризация вместо string interpolation).
- `beginTransaction()` / `getTransaction()` — управление транзакциями (NFR-UC1-004 атомарность).
- Полный JPA/Hibernate API (`createQuery`, `find`, `persist`, `merge`, `remove`, ...).

**Что меняется в архитектуре:**

- В hexagonal layout — класс-обёртка **`HibernateSessionProvider`** в `adapters/db/`, аналог `SmpSuperUserRunner` из эталона `naumen-smp-mcp`. Принимает `beanFactory` + `api` через конструктор.
- `core/` остаётся изолированным от Hibernate (NFR-006 / ADR-001) — работает только через port-интерфейс `VectorStore`.
- ADR-002 «SMP-only data access» нужно уточнить: **«доступ к БД через Hibernate `SessionFactory` из Spring `beanFactory`»** заменяет «через SMP API (`api.db.query`)». Это не нарушает CLAUDE.md «прямого доступа нет» — `sessionFactory` это санкционированный платформой Spring-bean.
- DDL исполняется bootstrap'ом модуля **через `session.doWork { conn -> conn.prepareStatement(ddl).execute() }`** — idempotent, при первом старте, без отдельного DBA-окна.
- Параметризация вектор-параметров — через `setParameter('vec', '[0.1,0.2,...]')` + `CAST(:vec AS vector(256))` в SQL (или `PGobject` через `doWork`) → устраняет SQL-инъекции baseline'а (см. memory `Baseline Groovy vector module`).

**Паттерн проброса `beanFactory` (script-as-binding-carrier):**

`@InjectApi` в JAR-классах не работает — компилируется, но runtime-поля null (известное ограничение, см. memory эталона `reference_inject_api_jar_limitation.md`). Поэтому **binding scope держит SMP script-module**, а в JAR передаётся через конструктор. Эталон — [`SmpSuperUserRunner.groovy`](file:///Users/mdemyanov/Devel/naumen-smp-mcp/src/main/groovy/ru/naumen/modules/mcp/adapters/smp/SmpSuperUserRunner.groovy):

```groovy
// adapters/db/HibernateSessionProvider.groovy (новый класс по образцу SmpSuperUserRunner)
@CompileDynamic
class HibernateSessionProvider {
    private final def beanFactory
    private final def api

    HibernateSessionProvider(def beanFactory, def api) {
        this.beanFactory = beanFactory
        this.api = api
    }

    def <T> T inSession(Closure<T> action) {
        def sf = beanFactory.getBean('sessionFactory')
        (T) api.tx.call {
            action.call(sf.getCurrentSession())
        }
    }
}
```

```groovy
// SMP script-module — держит binding и передаёт в JAR-bootstrap
// public/InitVectorModule.groovy
import ru.naumen.modules.pgvector.adapters.db.HibernateSessionProvider
import ru.naumen.modules.pgvector.config.VectorModuleBootstrap

def sessionProvider = new HibernateSessionProvider(this.beanFactory, this.api)
new VectorModuleBootstrap(sessionProvider, /* ... */).migrate()
```

**Решение зафиксировать в ADR (SA-011):**

- Апдейт **ADR-002** — переформулировать «SMP-only data access» в терминах Hibernate `sessionFactory` (а не `api.db.query`).
- Альтернатива — новый **ADR `db-access-adapter`** с паттерном `HibernateSessionProvider` + правилами работы с pgvector через `doWork` / `createNativeQuery` + script-as-binding-carrier по аналогии с `SmpSuperUserRunner` из эталона.

## 8. Тексты сообщений

### 8.1. Telegram (`@u2mario`)

```
Марат, привет!

По проекту pg_vector_service (векторизация SMP через pgvector + Yandex Cloud)
нужен твой sign-off на DDL вектор-таблицы — это блокер для старта /dev iter 1.

Подготовили draft runbook'а с полным SQL и 9 пунктами на согласование.
Большинство — выбор по умолчанию (schema=public, default tablespace,
HNSW m=16/ef=64, vector(256)), но точные роли и окно — за тобой.

Ссылки (в репо pg_vector_service, ветка private):
• Runbook: content/70-operations/runbooks/runbook-vector-table-migration.md
• Список вопросов: content/00-project/owner-questions/owner-001-pgvector-ddl.md
• ADR-004 (схема): content/00-project/adr/004-vector-storage-schema.md

Если удобнее — могу скинуть PDF-выгрузку или созвон на 15 минут.
Когда сможешь посмотреть?

Спасибо!
```

### 8.2. Email

**Subject:** `pg_vector_service — sign-off DDL вектор-таблицы (OWNER-001)`

**To:** msakhabetdinov@naumen.ru
**Cc:** eboronina@naumen.ru *(Сазонова — для информации, как gate-keeper стенда `llm2`)*

**Body:**

```
Марат, добрый день!

Прошу sign-off по DDL вектор-таблицы для модуля pg_vector_service
(векторизация SMP-объектов через pgvector + Yandex Cloud Foundation Models).
Это блокер для старта реализации (PoC iter 1) — без подтверждения схемы и прав
не запускаем DEVOPS-001 (миграцию таблицы на стенде llm2).

КОНТЕКСТ В ОДНОМ АБЗАЦЕ
Модуль будет хранить векторы SMP-объектов (knowledgeBase, problem, issue)
в выделенной таблице pg_vector_service__vectors. Размерность вектора 256
(модели Yandex Cloud text-search-doc / text-search-query). Индекс HNSW
с метрикой cosine. Доступ из модуля — только через SMP API (read через HQL,
write через SMP script-метод); прямого JDBC из JAR не будет (зафиксировано
в ADR-002). DDL выполняется DBA-стороной один раз, не runtime.

ЧТО ПРОШУ ПОДТВЕРДИТЬ (9 пунктов)
1. Схема для таблицы: предлагаем public.
2. Tablespace: default.
3. Роль, от которой исполнять DDL.
4. Владелец таблицы (для будущих ALTER/DROP).
5. Пользователь SMP-инстанса, которому давать GRANT SELECT/INSERT/UPDATE/DELETE.
6. Допустимо ли SET LOCAL maintenance_work_mem = '2GB' per-session на DDL.
7. Окно работ (DDL пустой таблицы — быстрый, downtime SMP не требуется).
8. Single-tenant или multi-tenant на llm2 (если multi — какие имена тенантов).
9. Письменное подтверждение исходящего доступа llm2 → *.api.cloud.yandex.net:443.

Полный draft DDL, обоснование выбора параметров и процедура исполнения —
в репо pg_vector_service на ветке private:

• Runbook (DDL + verify + rollback):
  content/70-operations/runbooks/runbook-vector-table-migration.md
• Структурированный список вопросов с предлагаемыми значениями:
  content/00-project/owner-questions/owner-001-pgvector-ddl.md
• ADR-004 (обоснование схемы таблицы):
  content/00-project/adr/004-vector-storage-schema.md
• ADR-010 (обоснование размерности 256 и cosine-метрики):
  content/00-project/adr/010-embedding-model-selection.md

Если по каким-то пунктам нужно созвониться — готов в любое удобное время,
предметный созвон на 15-30 минут.

Спасибо!
Максим
```

## 9. История

| Дата | Кто | Что |
|------|-----|-----|
| 2026-05-01 | PM (Демьянов через AI-агенты) | Открыта задача, подготовлен draft runbook'а и тексты сообщений. Статус: ожидает отправки owner'ом. |
| 2026-05-01 | Owner (Демьянов) | Ответ: Q1, Q3-Q6 закрыты ссылкой на действующий baseline-скрипт `Вспомогательный модуль для векторизации.groovy` (схема `public`, DDL через `modules.localSql.update` от имени SMP DB-user'а). Q8 — single-tenant. Q9 — сетевой доступ подтверждён. Открыто: Q7 (окно), точное имя SMP DB-user'а, sign-off на паттерн A vs B (DDL runtime vs DBA-runbook). |
| 2026-05-01 | Owner (Демьянов) | Финальное уточнение: SMP DB-user = `llm2` (имя пользователя БД равно имени стенда). Канал доступа к БД — **Hibernate `sessionFactory` через Spring `beanFactory.getBean("sessionFactory").getCurrentSession()`**, не `modules.localSql` (он был для примера, в JAR-модуле его не используем). Полный перечень доступных методов сессии — в memory. Q7 (окно) снимается: DDL исполняется bootstrap'ом модуля при первом старте. **OWNER-001 закрыт.** |
