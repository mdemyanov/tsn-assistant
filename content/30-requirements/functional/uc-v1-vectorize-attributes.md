---
order: 5
title: "UC-V1 — Векторизация атрибутов SMP-объектов"
properties:
  - Тип контента: Требование
  - Фаза: PoC
  - Статус: Draft
  - Сценарий: A-Workload
---

# UC-V1 — Векторизация атрибутов SMP-объектов

> **Supersedes:** `content/30-requirements/functional/uc1-scheduled-vectorization.md` (split).
> Все AC из UC1 переезжают в UC-V1 и UC-V2; трассируемость: UC1.AC-001..014 → UC-V1.AC-001..014.

## JTBD

### JTBD-1. Владелец продукта

Когда в SMP накапливаются новые или изменённые объекты целевых классов (`knowledgeBase`, `problem`, `issue`) и для них нет актуального векторного представления атрибутов, я (владелец продукта pg_vector_service, Демьянов) хочу, чтобы фоновая джоба по расписанию пакетно векторизовала атрибутный whitelist этих объектов через YC FM и сохраняла результат в pgvector-таблицу, чтобы сценарии семантического поиска (UC-S1, UC-S4) и кластерного анализа (UC-C1) работали на свежих векторах без ручных операций и без перерасхода квоты Yandex Cloud Foundation Models.

### JTBD-2. Аналитик качества

Когда аналитик планирует запустить отчёт о группах похожих заявок, я (аналитик качества) хочу быть уверен, что векторы атрибутов (`subject`, `decisionReport`, `feedback`) актуальны для всех объектов за выбранное окно, чтобы результаты кластеризации отражали реальное состояние базы, а не устаревшие описания.

## Описание

UC-V1 — фоновая массовая векторизация **атрибутных полей** SMP-объектов. Запускается по cron-расписанию, обрабатывает объекты, для которых вектор отсутствует или устарел, и складывает результат в pgvector-таблицу через SMP API.

Payload UC-V1 — **композитный текст** из whitelist-атрибутов объекта (subject, description, decisionReport, feedback для `issue`; title, description, keywords, content для KB; subject, workaround, rootCause для `problem`). Комментарии объекта (`comment.text`) в payload UC-V1 **не входят** — это отдельный payload-класс UC-V2.

Данные RES-009.1/2: `issue.composite_extended` (subject+cancelReason+decisionReport+feedback) имеет p95 = 209 токенов, и 99,6 % объектов укладываются в лимит модели → стратегия A (single-vector). KB.content p95 = 26 014 токенов, 47,8 % превышают лимит → стратегия C (chunking обязателен). Выбрана стратегия D (hybrid): issue → A, KB → C.

Модуль отвечает только за векторизацию переданного текста и поиск по нему. Триггеры запуска, отбор и формирование composite-текста — на стороне caller'а (SMP-сценарий, scheduled job). UC-V1 описывает business intent и контекст потребления.

### Что НЕ входит

- Векторизация комментариев (`comment.text`) — это UC-V2.
- Similarity-поиск — UC-S1..S4.
- Кластерный анализ — UC-C1..C2.
- Sync-векторизация по событиям SMP — out of scope PoC.
- Выбор модели эмбеддинга — зафиксирован в ADR-010.
- Прямой JDBC-доступ к БД — архитектурно запрещён (CLAUDE.md).

## Функциональные требования

- **FR-001. Триггер по расписанию.** Джоба запускается планировщиком SMP (`scheduledTask`) по cron-расписанию. Параметры расписания настраиваются администратором без изменения кода. Решение по расписанию по умолчанию — в ADR.
- **FR-002. Целевые классы.** В PoC: `knowledgeBase$*`, `issue` и подклассы (`issue$issue`, `issue$incident`, `issue$SAP`, `issue$equipmentReq`), `faq` (новый класс, см. BA-005). `problem` — defer to Pilot (Resolved OQ-V1-5, 2026-05-02). Список — параметр конфигурации, изменяется без перекомпиляции JAR.
- **FR-003. Очерёдность подключения классов.** В PoC: сначала `knowledgeBase$*`, затем `problem`, затем `issue`. Каждый следующий класс — gate с подтверждением owner'а о завершении PII-аудита whitelist'а.
- **FR-004. Whitelist атрибутов.** Векторизуются **только** атрибуты из явного whitelist'а (BR-001). Атрибуты вне whitelist'а в composite-текст не попадают.
- **FR-005. Preprocessing.** Composite-текст перед отправкой в YC FM нормализуется по политике из `content/30-requirements/non-functional/nfr-preprocessing.md`. HTML-поля конвертируются в plain text (HTML-strip). Результат должен быть детерминирован для одного и того же входа.
- **FR-006. Стратегия D (hybrid): single-vector для issue, chunking для KB.** Для `issue` — 1 вектор на объект (composite_extended укладывается в лимит у 99,6 %). Для `knowledgeBase$article` — чанкинг с chunk_size=2 048 ток. (Resolved OQ-V1-3, 2026-05-02; подтвердить smoke-тестом), overlap=10 %, с хранением summary-вектора (chunk_index=0) и content-чанков (chunk_index=1,2,...). Решение закреплено в ADR-011.
- **FR-007. Маркер `dirty`.** Объект помечается `dirty=true` при изменении любого whitelist-атрибута или при смене версии модели/whitelist'а. Способ реализации — в ADR (dirty-tracking).
- **FR-008. Идемпотентность через composite_hash.** Ключ идемпотентности: `sha256(normalized_text + model_version + whitelist_version + chunk_size + overlap + algorithm_version)`. Повторный запуск при неизменном hash → 0 вызовов YC FM.
- **FR-009. Версионирование модели.** Каждая запись содержит полный `modelUri` (версия модели). При смене модели все векторы помечаются `dirty` и пересчитываются в следующий запуск.
- **FR-010. Сохранение через SMP API.** Запись выполняется только через SMP API. Прямые JDBC-вызовы запрещены (CLAUDE.md).
- **FR-011. Пакетная обработка.** Обработка батчами. Размер батча — параметр конфигурации.
- **FR-012. Retry при ошибках YC FM.** HTTP 429 или таймаут → retry с экспоненциальной задержкой. Исчерпание ретраев → объект остаётся `dirty`, попадает в следующий запуск.
- **FR-013. Обработка deprecated-модели.** Ошибка «модель недоступна» → джоба прерывается, owner получает алёрт, существующие векторы не трогаются.
- **FR-014. Логирование.** Старт, батчи, итог запуска, failed-объекты с `correlationId`. Stack traces — только в лог, не в ответы.
- **FR-015. Защита от параллельных запусков.** Если предыдущий запуск не завершился — новый не стартует.

## Нефункциональные требования

- **NFR-V1-001. PII-фильтрация на входе модели.** В YC FM не уходит ни один атрибут вне whitelist'а (BR-001). Инвариант, проверяемый автоматически (AC-008).
- **NFR-V1-002. Preprocessing-версионирование.** Алгоритм нормализации текста (`algorithm_version`) включён в `composite_hash`. Смена алгоритма → инвалидация всех хешей → полный пересчёт. См. `content/30-requirements/non-functional/nfr-preprocessing.md`.
- **NFR-V1-003. Бюджет YC FM.** Расход на full-rescan: issue 6 223 × p50=62 ток./1000×0,0101 ≈ 3,9 ₽; KB 113 ст. с chunking ≈ 6–8 ₽. Итого первичная индексация llm2 ≈ 10–12 ₽. Дневной лимит — 1 000 ₽/сутки (Resolved OQ-V1-1, 2026-05-02). Расчёт unit economics — OQ-FUTURE-1.
- **NFR-V1-004. Throughput.** Целевой throughput задаётся на основе квоты YC FM RPS (ожидает финализации RES-002 OQ-5).
- **NFR-V1-005. Тенант-изоляция.** Векторы тенанта A не попадают в выдачу для тенанта B. На PoC — single-tenant `llm2`.

## User Journey

**Действующее лицо — планировщик SMP.**

1. **Триггер.** Планировщик запускает `scheduledTask` по cron (FR-001).
2. **Pre-flight.** Джоба проверяет: lock не занят (FR-015); версия модели прочитана из конфигурации; доступ к pgvector-таблице активен; IAM-токен / API-Key актуален.
3. **Выбор кандидатов.** Запрос объектов с `dirty=true` или устаревшей версией модели, пагинированный по батчам (FR-011).
4. **Обработка батча.**
   - Caller формирует composite-текст из whitelist-атрибутов (FR-004, FR-005).
   - Для KB: текст чанкируется (FR-006), каждый чанк векторизуется.
   - Вызов YC FM `text-search-doc` на composite-текст или чанки (ADR-010).
   - Запись вектора + метаданных (object_id, meta_class, model_version, composite_hash, vectorized_at, chunk_index) в pgvector через SMP API (FR-010).
   - `dirty` → false (атомарно с записью).
5. **Альтернатива A. Rate limit.** Retry с backoff (FR-012); исчерпание → объект остаётся dirty.
6. **Альтернатива B. Deprecated модель.** Прерывание + алёрт (FR-013).
7. **Завершение.** Лог итогов (FR-014), снятие lock (FR-015).

## Бизнес-правила

- **BR-001. Whitelist атрибутов (baseline PoC).**

  | Класс | Атрибут | PII-риск | Whitelist PoC |
  |---|---|:---:|:---:|
  | `knowledgeBase$article` | `title` | low | ✓ |
  | `knowledgeBase$article` | `description` | low | ✓ |
  | `knowledgeBase$article` | `content` | low | ✓ |
  | `knowledgeBase$article` | `keywords` | low | ✓ |
  | `knowledgeBase$section` | `title` | low | ✓ |
  | `knowledgeBase$section` | `description` | low | ✓ |
  | `knowledgeBase$section` | `keywords` | low | ✓ |
  | `problem` | `subject` | low | ✓ |
  | `problem` | `workaround` | low | ✓ |
  | `problem` | `rootCause` | low | ✓ |
  | `problem` | `description` | medium | ✓ (gate 2) |
  | `problem` | `decisionReport` | medium | ✓ (gate 2) |
  | `issue` | `subject` | medium | требует sign-off |
  | `issue` | `cancelReason` | low | требует sign-off |
  | `issue` | `decisionReport` | medium | требует sign-off (см. примечание) |
  | `issue` | `feedback` | medium | требует sign-off |
  | `issue` | `description` | high | НЕ включаем в PoC без решения owner'а |
  | `issue` | `lastComment` | high | НЕ включаем в PoC |

  > **BA-003-m1 (2026-05-01):** атрибут `decisionReport` у `issue` — проверен через MCP `metamodel_export_class issue$incident`. Результат: `decisionReport` присутствует как **inherited attribute** (`richtext`) на подклассе `issue$incident` и, предположительно, на всём семействе `issue$*`. В терминологии ITIL 4 это аналог поля итогового решения/закрытия (не только RCA как у `problem.decisionReport`). Атрибут в whitelist `issue` **оставлен**, ошибки нет — поле действительно существует. Аннотация: `decisionReport` у `issue` = поле «Отчёт о решении» при закрытии заявки (не путать с `problem.decisionReport` = RCA).

  Комментарии (`comment.text`) — **не в этом whitelist**, они в UC-V2.

- **BR-002. Один объект — одна актуальная векторная запись.** Для single-vector (issue, problem): 1 строка на объект. Для KB-chunking: N строк (чанки) + 1 summary (chunk_index=0). Стратегия закреплена в ADR-011.
- **BR-003. Версия модели обязательна.** Запись без `model_version` не создаётся.
- **BR-004. Атрибуты вне whitelist'а не уходят в YC FM.** Инвариант безопасности. Утечка — дефект критической степени.
- **BR-005. Доступ к БД — только через SMP API.** Прямой JDBC — запрещён.
- **BR-006. Preprocessing-версия в composite_hash.** `algorithm_version` входит в hash. Смена preprocessing → инвалидация существующих векторов.

## Доменные события

- **VectorJobStarted** — джоба стартовала, версия модели и целевые классы зафиксированы.
- **VectorJobBatchCompleted** — батч: successful / skipped / failed.
- **VectorComputed** — вектор объекта посчитан и сохранён, `dirty` снят.
- **VectorComputeFailed** — векторизация провалена, объект остаётся `dirty`.
- **VectorJobCompleted** — джоба завершилась, итоговая статистика.
- **VectorJobAborted** — прервана (deprecated-модель, превышен time-cap).

## Acceptance Criteria

- [ ] **AC-001.** На стенде `llm2` зарегистрирован `scheduledTask` с конфигурируемым расписанием; период изменяется без правок кода.
- [ ] **AC-002.** Список целевых FQN-классов — в конфигурации; добавление класса без перекомпиляции JAR.
- [ ] **AC-003.** Whitelist в конфигурации; smoke: удаление атрибута из whitelist прекращает его отправку в YC FM (проверяется через инспекцию исходящего payload в log).
- [ ] **AC-004.** Два последовательных запуска на одном snapshot: второй запуск делает 0 вызовов YC FM (идемпотентность по composite_hash).
- [ ] **AC-005.** Изменение whitelist-атрибута объекта → `dirty=true` → в следующий запуск объект пересчитывается.
- [ ] **AC-006.** Каждая запись в pgvector содержит непустой `model_version`; запись без него не создаётся.
- [ ] **AC-007.** Смена model_version в конфигурации → все объекты этого класса получают `dirty=true` → следующий запуск пересчитывает.
- [ ] **AC-008.** Smoke на `llm2`: для тестового `issue` с `description` (high-PII) исходящий payload в YC FM не содержит `description` (он не в whitelist PoC).
- [ ] **AC-009.** Smoke с mock-429: джоба делает retry с backoff; при исчерпании — объект остаётся `dirty`, не теряется.
- [ ] **AC-010.** Smoke с mock «модель deprecated»: джоба прерывается, owner получает алёрт, существующие векторы не изменяются.
- [ ] **AC-011.** Сбой после вызова YC FM, до записи в pgvector → объект остаётся `dirty`; нет «полу-записи» (нет записи без `model_version`).
- [ ] **AC-012.** Ручной запуск джобы во время её работы отклоняется; в лог пишется «уже выполняется».
- [ ] **AC-013.** Code review: нет прямых JDBC-зависимостей; все обращения к pgvector через SMP API.
- [ ] **AC-014.** Лог запуска содержит VectorJobStarted, ≥1 VectorJobBatchCompleted, VectorJobCompleted/VectorJobAborted; для каждого failed-объекта — VectorComputeFailed с `correlationId`.
- [ ] **AC-015. KB chunking.** Для KB-статьи длиннее лимита в pgvector создаётся summary-строка (chunk_index=0) и N content-чанков (chunk_index=1,2,...); `chunk_total` корректен.
- [ ] **AC-016. Preprocessing-версия в hash.** При смене `algorithm_version` все существующие хеши инвалидируются; джоба пересчитывает объекты (BR-006).

## Открытые вопросы

| # | Статус | Решение | Адресат |
|---|--------|---------|---------|
| OQ-V1-1 | **Resolved (2026-05-02)** | Вариант B — 1 000 ₽/день. Создан OQ-FUTURE-1 «unit economics calculation» (см. README, nfr-cross-cutting). Owner: Демьянов. | Owner (Демьянов) |
| OQ-V1-2 | **Resolved (2026-05-02)** | Вариант A — ручной запуск в PoC iter 1-2, затем ежедневно ночью. Owner: Демьянов. | Owner |
| OQ-V1-3 | **Resolved (2026-05-02)** | chunk_size=2 048 как default. Smoke-task создан в DevOps backlog для подтверждения лимита модели. FR-006 обновлён. Owner: Демьянов. | Owner |
| OQ-V1-4 | **Resolved (2026-05-02)** | Вариант B — low+medium PII открыты для PoC (внутренний периметр). Owner: Демьянов. | Owner + юр-аудит |
| OQ-V1-5 | **Resolved (2026-05-02)** | PoC scope = issue + knowledgeBase + faq (новый класс, BA-005). problem — defer to Pilot. FR-002 обновлён. Owner: Демьянов. | Owner / PM |
| OQ-V1-6 | **Resolved (2026-05-02)** | Вариант A — системный пользователь с правами на whitelist-атрибуты. Action item: запрос Сахабетдинову о подходящем пресете (dependency DevOps). Owner: Демьянов. | Сахабетдинов / DevOps |

## Бриф для SA

**Требование:** `content/30-requirements/functional/uc-v1-vectorize-attributes.md`
**Фаза:** PoC

**Спроектировать:**
- Компоненты: scheduler-entry, batch-processor, composite-text-composer (per-class whitelist), chunker (KB only), embedding-client (YC FM `text-search-doc`), pgvector-writer (через SMP API), dirty-tracker, model-version-manager.
- Интеграции: SMP API (read objects / write vectors), YC FM (REST + API-Key), SMP scheduler.
- Модель данных: схема `pg_vector_service__vectors` (DDL из RES-009.2 §4/Dimension-4: object_id, meta_class, tenant_id, model_version, whitelist_version, embedding vector(256), composite_hash, chunk_index, chunk_total, parent_id, source_attr, chunk_kind, dirty, vectorized_at).
- ADR: ADR-011 (финальный DDL + HNSW-параметры), ADR-012 (chunk aggregation rollup), ADR для preprocessing (нормализация richtext), ADR для job-state.

**Бизнес-правила для валидаций:** BR-001 (whitelist), BR-003 (model_version обязателен), BR-004 (за whitelist ничего не уходит), BR-005 (только SMP API), BR-006 (preprocessing-версия в hash).

**AC для проверки архитектуры:** AC-004 (идемпотентность), AC-008 (PII-инвариант), AC-011 (атомарность), AC-013 (нет JDBC), AC-015 (KB chunking), AC-016 (preprocessing-версия).

**Решение по § закрепится в ADR-011** (DDL) и **ADR-012** (rollup strategy).
