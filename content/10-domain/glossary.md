---
title: Глоссарий
properties:
  Тип контента: Глоссарий
  Фаза: MVP
  Статус: Draft
---

# Глоссарий

Ubiquitous Language проекта. Термины, используемые в требованиях, архитектуре и коде.

## Правила

- Новый термин — через BA при формировании требования (`/ba glossary-add <term>`).
- Один термин — одно значение в проекте. Конфликт значений → дискуссия с PM.
- Сокращения и аббревиатуры расшифровывать при первом упоминании.

## Термины

<!-- Добавляй термины в алфавитном порядке. Шаблон:

### [Термин]
[Определение в 1-2 предложениях]
**Синонимы:** [если есть]
**Не путать с:** [если есть похожий термин]
**Используется в:** [BA / SA / Dev / DevOps]

-->

<!-- Проектные термины pg_vector_service -->

### pgvector
Расширение PostgreSQL для хранения и поиска векторных представлений. На стенде `llm2` установлена версия 0.8.1.
**Используется в:** SA, Dev, DevOps

### HNSW
Hierarchical Navigable Small World — иерархический ANN-индекс в pgvector. Используется как индекс по умолчанию для семантического поиска (`vector_cosine_ops`, `m=16`, `ef_construction=64`). См. ADR-010.
**Не путать с:** IVFFlat (альтернативный индекс на k-means).
**Используется в:** SA, Dev, DevOps

### IVFFlat
Inverted file (k-means) — альтернативный pgvector-индекс. Быстрее строится, но требует периодического `REINDEX` на инкрементах. На PoC не используем (см. ADR-010 / pgvector-indexes.md §3).
**Используется в:** SA

### Cosine similarity
Метрика близости векторов; в pgvector — оператор `<=>` (cosine distance, similarity = `1 - <=>`). Дефолт для трансформерных эмбеддингов.
**Синонимы:** косинусное сходство.
**Используется в:** BA, SA, Dev

### Embedding (эмбеддинг)
Векторное представление текста, получаемое от ML-модели. В нашем PoC — 256-мерный вектор от Yandex Cloud Foundation Models.
**Используется в:** BA, SA, Dev

### `modelUri`
Идентификатор embedding-модели в Yandex Cloud (`emb://<folder-id>/text-search-doc/latest`). Сохраняется в каждой записи `pg_vector_service__vectors.model_version` (NFR-030).
**Используется в:** SA, Dev

### `algorithm_version`
Строковой идентификатор версии preprocessing-алгоритма нормализации текста. Входит в `composite_hash`. При смене алгоритма все хеши инвалидируются и вызывается full-rescan. Текущее значение для PoC: `v1.0-mixed`. Формат: `v{MAJOR}.{MINOR}-{strategy}` (например, `v2.0-plain`). См. `nfr-preprocessing.md`.
**Используется в:** SA, Dev

### `chunk_kind`
Перечисление (enum), классифицирующее тип вектора в pgvector-таблице: `'object'` — единственный вектор атрибутов объекта (issue/problem); `'summary'` — summary-вектор KB-статьи (chunk_index=0); `'chunk'` — content-чанк KB-статьи (chunk_index=1,2,...); `'related'` — comment-вектор (UC-V2, parent_id → объект-родитель).
**Используется в:** SA, Dev

### `composite_hash`
SHA-256 от `normalized_text + "|" + model_version + "|" + whitelist_version + "|" + chunk_size + "|" + overlap + "|" + algorithm_version`. Ключ идемпотентности UC-V1/UC-V2 (NFR-020, NFR-071) — повторный прогон джобы при том же контенте и параметрах не делает YC FM-вызов.
**Используется в:** SA, Dev

### Whitelist (атрибутов)
Реестр атрибутов SMP-класса, разрешённых к отправке в Yandex Cloud. PII-default-deny (ADR-005). Изменения whitelist'а имеют версию (NFR-032) и инвалидируют затронутые векторы.
**Используется в:** BA, SA, Dev

### `tenant_id`
Колонка вектор-таблицы для будущей multi-tenant изоляции (BR-008). На PoC `llm2` — single-tenant, значение константа `'llm2'`.
**Используется в:** SA, Dev

### ACL-наследование (comment)
Принцип, по которому права доступа к comment-вектору определяются правами на родительский объект (`parent_id`). Реализуется постфильтрацией в Java-слое: после KNN-поиска по comment-векторам результаты фильтруются по parent_id с проверкой прав пользователя на родительский объект. Подробнее — NFR-070, ADR-comment-acl.
**Не путать с:** ACL-объект SMP (прямой контроль на уровне FQN-объекта).
**Используется в:** SA, Dev

### cap (comment_cap)
Максимальное число comment-векторов, создаваемых UC-V2 для одного родительского объекта. Default=50. Защищает от аномальных объектов с тысячами комментариев. При превышении обрабатываются последние N по `creationDate DESC`. Конфигурируемый параметр. NFR-074.
**Используется в:** BA, SA, Dev

### Combined signal
Комбинированная метрика сходства UC-C2: `w1 × issue_cosine + w2 × comment_agg_cosine`. Default веса 50/50. Позволяет учитывать и атрибутное сходство (UC-V1), и семантику переписки (UC-V2). Решение по финальным весам — OQ-CL-1 (после offline-eval).
**Используется в:** BA, SA

### `dirty` flag
Маркер объекта, означающий что вектор устарел и требует пересчёта в следующий запуск джобы UC-V1/UC-V2. Устанавливается в `true` при: изменении whitelist-атрибутов, смене `model_version`, смене `whitelist_version`, смене `algorithm_version`. Сбрасывается атомарно при успешной записи нового вектора.
**Используется в:** SA, Dev

### Payload-класс
Классификация входных данных для векторизации по типу содержимого и lifecycle. В pg_vector_service два класса: (1) атрибутные поля объекта (UC-V1, payload = composite_extended из whitelist); (2) комментарии (UC-V2, payload = `comment.text`). Отличаются кардинальностью, ACL-моделью, lifecycle (комментарии добавляются/удаляются независимо от объекта) и требованиями к cap.
**Используется в:** BA, SA

### Parent-document retrieval
Паттерн поиска в чанкированных KB-документах (UC-S4): KNN-поиск возвращает топ-K чанков → GROUP BY `parent_id` → MIN(distance) как агрегат → Java ACL-фильтр по родительским объектам → топ-N родительских статей. Стандартный паттерн LangChain/LlamaIndex для chunked KB. NFR-013, UC-S4 BR-005.
**Используется в:** SA, Dev

### Preprocessing-версия
Версия алгоритма нормализации текста, зафиксированная строкой `algorithm_version` в `composite_hash`. Изменение preprocessing без смены `algorithm_version` является ошибкой (нарушает детерминированность). Текущая PoC-версия: `v1.0-mixed`. Подробнее — `nfr-preprocessing.md`.
**Синонимы:** `algorithm_version`.
**Используется в:** BA, SA, Dev

### Mixed preprocessing strategy
Политика нормализации текста BA-002: plain text (HTML-strip) для `issue.*`, `problem.*`, `comment.text`; markdown (flexmark HTML→md) для `knowledgeBase$article.content`. Обоснование: issue/comment — неструктурированный текст без семантики разметки; KB — структурированные документы с заголовками. `algorithm_version = "v1.0-mixed"`. Финальный выбор подтверждается после offline-eval (OQ-PRE-1). Подробнее — `nfr-preprocessing.md`.
**Не путать с:** plain text strategy (uniform HTML-strip для всех классов).
**Используется в:** BA, SA, Dev

### Hibernate `SessionFactory` / script-as-binding-carrier
Канал доступа к БД из JAR-модуля. `beanFactory.getBean('sessionFactory').getCurrentSession()` — Spring-bean SMP-платформы. Паттерн `script-as-binding-carrier`: SMP script-module держит binding (`api`, `beanFactory`, `modules`) и передаёт в JAR-классы через конструктор (Runner-обёртка `HibernateSessionProvider` в `adapters/db/`, по образцу `SmpSuperUserRunner` из эталона `naumen-smp-mcp`). Заменяет `api.db.query` для JAR-кода. См. memory `reference_smp_db_access_hibernate.md`.
**Используется в:** SA, Dev

### Runner-pattern
Класс-обёртка в `adapters/{smp,db}/`, инкапсулирующий `api.tx.call { ... }` (+ опционально elevation через `authorizationRunnerServiceImpl.callAsSuperUser`). Принимает `beanFactory`+`api` через конструктор. Изолирует core от SMP-специфики.
**Используется в:** SA, Dev

<!-- ITSM-термины (добавлены при BA-003 — спецификация роли ITSM-аналитик) -->

### FCR (First Contact Resolution)
Метрика качества Service Desk: доля обращений, решённых при первом контакте без повторного обращения заявителя. ITIL 4 KPI для Service Request Management.
**Используется в:** BA

### MTTR (Mean Time To Restore / Resolve)
Среднее время восстановления сервиса / решения инцидента. В ITIL 4 — ключевой KPI для Incident Management. Не путать с MTTA (Mean Time To Acknowledge).
**Не путать с:** MTTF (Mean Time To Failure) — метрика надёжности, не Service Desk.
**Используется в:** BA

### Deflection rate
Доля обращений, которые пользователи решили самостоятельно через KB / self-service портал, не создав заявку. KPI для Knowledge Management (KCS v6). Прямой индикатор эффективности KB-поиска.
**Используется в:** BA

### KCS (Knowledge-Centered Service)
Методология создания базы знаний, при которой статьи создаются и обновляются в процессе решения обращений, а не отдельно. Стандарт Consortium for Service Innovation, версия 6 (KCS v6). Ключевые принципы: capture at point of experience, structure for reuse, seek and reuse before create.
**Используется в:** BA, SA

### Major Incident
Инцидент наивысшего приоритета (обычно P1/P2), влияющий на критичный бизнес-сервис. В ITIL 4 требует отдельного процесса управления и postmortem (Post-Incident Review). В SMP может отображаться через атрибут `priority` или отдельный подкласс.
**Не путать с:** Problem (Problem Management — анализ root cause после инцидента).
**Используется в:** BA

### RCA (Root Cause Analysis)
Анализ корневой причины инцидента / проблемы. В контексте Naumen SMP хранится в поле `decisionReport` объекта `problem`. В ITIL 4 — часть Problem Management practice.
**Синонимы:** Root Cause Analysis, root cause.
**Не путать с:** `decisionReport` — конкретная реализация RCA-поля в SMP. `issue.decisionReport` — поле «Отчёт о решении» при закрытии заявки (verified MCP BA-003-m1), не путать с `problem.decisionReport` = RCA.
**Используется в:** BA, SA

### KB Article lifecycle
Жизненный цикл статьи базы знаний по ITIL 4 Knowledge Management: **draft → reviewed → published → retired**. В SMP все статьи хранятся в `knowledgeBase$article`, статусы workflow соответствуют lifecycle. При общении с операционным блоком использовать «статья KB» (не «KCS Article» — требует объяснения методологии). KCS v6 различает типы KB-статей: FAQ/Known Error Article (вопрос + ответ), Knowledge Article (How-To, Process). В UC-S3 используется FAQ/Known Error Article тип.
**Используется в:** BA, SA

<!-- OVERLAY:naumen-smp:start -->
### Заявка
Запрос пользователя в Service Desk на выполнение какого-либо действия. В проекте pg_vector_service используется FQN-класс `issue` (с подклассами — incident, request и др.); класс `serviceCall` **не используется** в требованиях, архитектуре и коде проекта. См. memory `project_smp_class_convention_issue.md`.
**ITIL-mapping (BA-003-n1):** `issue (SMP/pg_vector_service) = serviceCall$* = ITIL 4 Incident + Service Request + Change Request` — всё семейство обращений в одном FQN-пространстве. В ITIL 4 `issue` — общий термин для любой проблемы; в SMP `issue` — конкретное семейство FQN-классов. При коммуникации с операционным блоком (ITIL-background): говорить «инцидент» или «запрос на обслуживание» в зависимости от подкласса `issue$*`.
**Не путать с:** `serviceCall` — устаревшее имя класса, в этом проекте не применяется.
**Используется в:** BA, SA, Dev

### Обращение
Сообщение пользователя, требующее обработки оператором. В SMP — общий термин для заявок, инцидентов, запросов на изменение.
**Используется в:** BA, SA

### Услуга
Сервис, который предоставляется в рамках Service Desk. Каталог услуг — основа SLA и приёма заявок.
**Используется в:** BA, SA

### Сервис
Технический объект SMP, поддерживающий услугу. Один сервис может поддерживать несколько услуг.
**Не путать с:** Услуга (бизнес-уровень)
**Используется в:** SA, Dev

### Ответственный объект (ОО)
Сотрудник/группа, на которого назначена заявка. В SMP представлен как FQN-объект `employee$user`.
**Синонимы:** Исполнитель, Назначенный
**Используется в:** BA, SA, Dev

### Договор SLA
Соглашение об уровне обслуживания: время реакции, время решения, доступность. В SMP — отдельный FQN-объект.
**Используется в:** BA, SA

### Очередь
Группа исполнителей, на которую распределяются заявки до назначения конкретному ОО.
**Используется в:** BA, SA, Dev

### FQN
Fully Qualified Name — полное имя SMP-объекта, например `issue$incident`. Используется в HQL и REST. В этом проекте базовый класс заявок — `issue`, а не `serviceCall`.
**Используется в:** SA, Dev
<!-- OVERLAY:naumen-smp:end -->
