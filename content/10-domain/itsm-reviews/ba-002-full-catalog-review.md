---
order: 91
title: "ITSM Review — каталог требований pg_vector_service после BA-002"
properties:
  - Тип контента: Ревью
  - Фаза: PoC
  - Статус: Draft
  - Сценарий: Все
---

# ITSM Review — каталог требований pg_vector_service после BA-002

**Дата:** 2026-05-01
**Автор ревью:** ITSM-аналитик (subagent)
**Объекты ревью:** UC-V1, UC-V2, UC-S1, UC-S2, UC-S3, UC-S4, UC-C1, UC-C2, nfr-cross-cutting.md (NFR-070..075), nfr-preprocessing.md
**Потребители:** BA (основной — для BA-003), Owner и SA (вторичные)

---

## §1. Executive Summary

Каталог требований BA-002 — **зрелая работа** с точки зрения ITSM-методологии. Большинство UC описывают реалистичные сценарии, подтверждённые vendor practice. По итогам ревью — 6 findings с оценкой Critical (1), Major (2), Minor (2), Nit (1).

**Главные находки:**

1. **[Critical] UC-S2** — JTBD-1 («по тексту одного комментария») описывает нишевый, не лучший сценарий; ни один из лидирующих ITSM-вендоров не строит поиск похожих инцидентов по единичному произвольному комментарию. Research-агент это уже подтвердил. Требует переработки по одному из вариантов A/B/C.

2. **[Major] UC-S1, UC-S2, UC-C1** — отсутствуют AC, измеримые в терминах ITSM KPI (FCR, MTTR). Это не критично для PoC, но ослабляет обоснование ценности сценариев перед бизнесом (операционным блоком: Сазонова, Киселёва).

3. **[Major] UC-S3** — JTBD-2 (заявитель на self-service портале) и JTBD-3 (чат-бот) превышают изначальный scope PoC: требуют наличия оформленного каталога FAQ и пользовательского канала, которых на `llm2` может не быть. Требует owner-decision о scope.

4. **[Minor] UC-V1** — термин `decisionReport` в whitelist используется как атрибут `issue`, хотя в ITIL 4 и в Naumen SMP `decisionReport` — атрибут `problem` (RCA). Это терминологическая неточность, которая вводит в заблуждение при ревью.

5. **[Minor] UC-C1** — online-сценарий (подсказка при регистрации) не ссылается на триггер ITIL 4 Incident Management «detect related incidents». Добавление этой ссылки усилит обоснование сценария.

6. **[Nit] Терминология issue vs incident vs request** — везде используется SMP-термин `issue` (который = семья `serviceCall`). Это корректно для Naumen SMP, но нуждается в явном mapping в glossary для читателей с ITIL-бэкграундом.

**Общая оценка каталога:** соответствует ITSM best-practice с оговорками по UC-S2 (Critical) и UC-S3 scope (Major). Остальные 6 UC и NFR — валидные сценарии, хорошо выровненные с ITIL 4, KCS v6 и vendor practice.

**Приоритет для BA-003:** Critical → Major → Minor → Nit (детали в §7).

---

## §2. По каждому UC

### 2.1. UC-V1 — Векторизация атрибутов

**Verdict:** ✅ Соответствует ITSM best-practice с одним терминологическим замечанием.

**JTBD-оценка.** Batch-векторизация атрибутных полей по расписанию — стандартный паттерн для подготовки AI-features в ITSM. ServiceNow Predictive Intelligence, BMC Helix Cognitive ITSM, Atlassian JSM — все они требуют предварительного индексирования полей `short_description` / `description` / `summary` перед запуском similarity-engine. JTBD-1 (product owner хочет фоновую джобу) и JTBD-2 (аналитик хочет актуальные векторы для отчётов) — валидные операционные потребности [established].

**Whitelist BR-001.** Включение `subject`, `cancelReason`, `decisionReport`, `feedback` для `issue` — корректный subset атрибутов, несущих семантический сигнал. Отдельно:

- `issue.decisionReport` — Finding [Minor]: в Naumen SMP `decisionReport` — атрибут `problem`, а не `issue`. Для `issue` аналогичная роль у `cancelReason` + `feedback`. Рекомендую BA проверить с SA / MCP: присутствует ли `decisionReport` на FQN `serviceCall$incident` / `serviceCall$request` или только на `problem`. Если это атрибут только `problem` — его нужно убрать из whitelist `issue` или явно аннотировать как «только если issue linked to problem».

**ACL/PII.** Default-deny для high-PII (`description`, `lastComment`, `feedback`) — соответствует ISO 20000 (требование к контролю доступа к персональным данным клиентов) [established]. Механизм sign-off через owner — адекватный gate.

**AC-оценка.** AC-008 (PII-инвариант через лог) и AC-004 (идемпотентность) — измеримые и конкретные. Качественных ITSM-KPI в AC нет, но для UC-V1 (инфраструктурный UC) это уместно.

**Vendor-сопоставление.** ServiceNow Predictive Intelligence: индексация полей `short_description` + `description` перед обучением similarity-модели — точный аналог UC-V1. BMC Helix ITSM Insights: scheduled re-indexing при изменении записей — аналог dirty-флага (FR-007). [established]

**Рекомендации для BA:**
- Проверить наличие `decisionReport` у `issue` в SMP-метамодели (через MCP `metamodel_export_class serviceCall$incident`); если атрибут отсутствует — убрать из whitelist или добавить комментарий «только через linked problem».

**Рекомендации для SA:** нет (архитектурных вопросов от этого finding нет).

---

### 2.2. UC-V2 — Векторизация комментариев

**Verdict:** ✅ Соответствует ITSM best-practice. Статус «Deferred» корректен и обоснован.

**JTBD-оценка.** JTBD-1 (оператор ищет коллег с похожей перепиской) и JTBD-2 (аналитик ищет root cause в переписке) — реалистичные ITSM-сценарии. KCS v6 явно различает «capture context» (что пишет заявитель при создании), «resolution context» (что пишет агент при закрытии) и «discussion threads» (промежуточные комментарии — шум с точки зрения knowledge content) [established]. UC-V2 корректно направлен на векторизацию всего пула комментариев с фильтрацией системных (BR-002, FR-006) — это согласуется с KCS-подходом.

**ACL-модель (FR-003, BR-001).** ACL-наследование от parent-объекта — правильное архитектурное решение для SMP, где комментарии не имеют собственного ACL-объекта. Соответствует принципу least privilege в ISO 20000 и ITIL Service Management practice [established].

**PII (NFR-V2-001).** PII-default-deny на `comment.text` до sign-off — корректная позиция. В ITSM-контексте комментарии операторов содержат PII сразу нескольких категорий: данные заявителя (имена, контакты), внутренняя диагностика (IP-адреса, имена серверов), иногда credentials в «плохой» Service Desk. Требование sign-off до отправки в облачный API — хорошая практика [established].

**Finding: BR-002 «только user-комментарии».** Логично, но список `excluded_meta_classes` остаётся открытым вопросом (OQ-V2-2). Это нужно закрыть до реализации — без него фильтрация некорректна. Это блокер для UC-S2 Variant B (см. §2.4).

**Рекомендации для BA:**
- OQ-V2-2 (список system-метаклассов комментариев) — приоритизировать выяснение через MCP `naumen-smp-dev-admin`. Это блокер для UC-V2 и UC-S2.
- OQ-V2-4 (порядок выбора N комментариев при cap): с точки зрения ITSM-практики приоритет у последних N по дате (они содержат наиболее свежую диагностику и resolution notes) — рекомендую BA зафиксировать это как default.

---

### 2.3. UC-S1 — Поиск похожих заявок по описанию

**Verdict:** ✅ Соответствует ITSM best-practice. Эталонный UC каталога.

**JTBD-оценка.** JTBD-1 (оператор видит top-K похожих при открытии заявки) — наиболее распространённый ITSM AI-сценарий. Точный аналог: ServiceNow Now Assist «Similar Resolved Incidents» (short description + description + resolution notes → похожие закрытые инциденты), BMC Helix ITSM Insights (description-based similarity), Atlassian JSM «Similar Requests Panel» [established]. JTBD-2 (аналитик — K=100 для отчёта) — менее стандартизованный, но реалистичный сценарий Problem Management: ITIL 4 описывает «proactive problem identification» через анализ трендов инцидентов [established].

**Cross-class (issue → KB, issue → problem).** Возврат похожих KB-статей и проблем при поиске по заявке — валидный паттерн, соответствующий ITIL 4 Incident Management (связывание инцидентов с known errors / problems) и KCS Solve Loop (поиск в KB в начале обработки) [established].

**AC-оценка.** AC-007 (ACL-проверка через тестовый аккаунт) и AC-009 (VectorNotReady вместо пустого списка) — хорошие конкретные критерии. **Finding [Major]:** отсутствует AC, измеримый в ITSM-терминах. Предлагаю BA добавить как опциональный post-PoC target: «При наличии разметки ground truth — среднее время до нахождения дубля оператором снижается не менее чем на X% vs. ручной поиск (метрика MTTR для этапа идентификации дубля)». Это не обязательно для PoC, но усиливает обоснование перед операционным блоком (Сазонова, Киселёва).

**Терминология.** Использование термина `issue` для обозначения инцидентов и запросов — корректно для SMP (это FQN-семейство), но добавить в glossary mapping `issue = serviceCall$* (incident + service request)` желательно.

**Рекомендации для BA:**
- Добавить в AC-011 (Quality) пояснение: recall@10 ≥ 0.80 — это стандарт для semantic search в enterprise ITSM (ServiceNow PI target), так что порог обоснован.
- Добавить post-PoC AC (optional): измеримое снижение MTTR на этапе идентификации дубля / поиска решения (метрика для операционного блока).

**Рекомендации для SA:** Q5 (ACL pre-filter vs post-filter с оверсэмплингом) — post-filter с оверсэмплингом является стандартным паттерном в ITSM-продуктах (BMC Helix: Java-фильтр после SQL). Рекомендую зафиксировать этот выбор в ADR с явной ссылкой на vendor practice.

---

### 2.4. UC-S2 — Поиск заявок со схожими комментариями (КРИТИЧЕСКИЙ ФОКУС)

**Verdict:** ⚠ Требует доработки. JTBD-1 описывает нишевый сценарий с высоким шумом. JTBD-2 лучше реализуется через UC-C1/UC-C2.

**Исходная проблема.** Owner поставил под сомнение: «по одному комментарию нормального поиска не получится». Research-агент подтвердил: ни ServiceNow, ни BMC Helix, ни Atlassian JSM, ни Moogsoft не строят основной поиск похожих инцидентов по единичному произвольному комментарию [established].

**Детальный анализ JTBD-1.**

Текущая формулировка: «Оператор видит в треде комментарий "снова та же ошибка после ребута" и хочет найти похожие заявки по тексту или id этого комментария».

Три проблемы с этим JTBD:

1. **Информационная плотность.** Комментарий «снова та же ошибка после ребута» — типичный discussion-reply с крайне низкой информационной плотностью. Embedding такого текста создаёт почти случайный вектор, результаты поиска непредсказуемы. KCS v6 явно классифицирует такие комментарии как «discussion threads» — шум с точки зрения knowledge content [established].

2. **Нет vendor-аналога.** ServiceNow Predictive Intelligence использует `short_description` + `description` (не work notes). BMC Helix — `description` + структурные group-by поля. Zendesk — `subject` + первый публичный комментарий (= начальное описание клиента, не последующие ответы агента). Moogsoft — структурные event-поля по Jaccard index. Ни один не использует произвольный промежуточный комментарий как единственный signal [established].

3. **JTBD-2 — не UC-S2.** Сценарий аналитика «найти системный сбой через комментарии» — это кластеризация (UC-C2), не поиск по одному комментарию. JTBD-2 лучше удалить из UC-S2 и оставить в UC-C2.

**Рекомендация Variant A/B/C (из research):**

**Рекомендуемый вариант — B (scope narrowing)** с явным precondition:

JTBD переформулировать как: «Оператор видит конкретный комментарий-резюме (написанный агентом при закрытии заявки или содержащий root cause / диагностические данные), и хочет найти все заявки, где в переписке обсуждался тот же root cause».

Обоснование выбора B над A и C:

- **Вариант A** (composite issue+comment search) архитектурно ближе к UC-S1 с расширенным вектором. Если это ценный самостоятельный JTBD — он может быть параметром UC-S1 (comment_weight > 0), а не отдельным UC.
- **Вариант B** сохраняет уникальность UC-S2 (поиск именно по comment-корпусу) и решает проблему шума через precondition на тип комментария. Это соответствует Now Assist-паттерну «resolution notes» [established] и Zendesk «first public comment» паттерну.
- **Вариант C** (split на UC-S2a/S2b) оправдан только если BA и owner явно подтвердят два разных JTBD. Усложняет backlog без дополнительной ценности на PoC.

**Вопрос о comment_kind в SMP (OQ-R10-1 и OQ-R10-4).**

Есть ли в SMP атрибут, позволяющий отличить «resolution note» от «discussion reply»?

Проверка через MCP `naumen-smp-dev-admin` рекомендована BA+SA. Релевантные факты:

- В ServiceNow разделение: `work_notes` (internal, для агента) vs `additional_comments` (public, для клиента) — оба существуют как отдельные поля, не один `comment.text`. Это не типы комментариев, а разные поля [established].
- В BMC Helix: `work_info_type` (user comment / application log / email / etc.) — есть классификация, но не «resolution» vs «discussion».
- В Naumen SMP: `comment.source.metaClass` различает тип источника (author-объект), но не семантический тип содержания. Поле `comment.kind` с классификацией «resolution / discussion / system» стандартно отсутствует в базовой поставке Naumen SMP — требует MCP-проверки (OQ-R10-4) [emerging, требуется подтверждение через MCP metamodel].
- Альтернативная стратегия без `comment_kind`: использовать SMP-событие «перевод в статус closed» как маркер «closing comment» — последний комментарий перед закрытием с высокой вероятностью содержит resolution notes. Это технически реализуемо без новых полей в метамодели.

**Рекомендации для BA:**
- Переформулировать JTBD-1 UC-S2 по Варианту B: «Оператор ищет заявки с похожим root cause по comment-резюме или closing note».
- Удалить JTBD-2 из UC-S2 — перенести в UC-C2 JTBD-1 (там он уже присутствует).
- Добавить precondition к FR-001: «Поиск по comment_id оптимален для комментариев типа resolution/closing; для discussion-реплик рекомендуется использовать UC-S1».
- Уточнить OQ-S2-1 (ranking aggregation): добавить опцию «отфильтровать до поиска только closing-комментарии» как альтернативу max-sim aggregation.

**Рекомендации для SA:**
- Проверить через MCP `metamodel_export_class comment` — есть ли в SMP атрибут, позволяющий отличить closing comment от discussion reply (OQ-R10-4).
- Если такого атрибута нет — рассмотреть LLM-классификацию comment type (отдельный UC для preprocessing или pre-filter) или эвристику «последний комментарий перед финальным статусом».
- Зафиксировать в ADR: UC-S2 активируется только при выполнении двух условий: `comment_vectorization.enabled=true` И наличии comment_type pre-filter или пользовательского explicit выбора «искать именно по этому комментарию».

---

### 2.5. UC-S3 — Поиск похожего вопроса (FAQ-сценарий)

**Verdict:** ⚠ Требует owner-decision по scope. JTBD-1 валиден, JTBD-2/3 превышают реалистичный PoC-scope.

**JTBD-1 (оператор — подсказка на форме регистрации).** Реалистичный и хорошо описанный сценарий. Точный аналог: Zendesk ticket creation suggestions, Atlassian JSM «Similar Requests» при создании тикета, ServiceNow Virtual Agent intent matching [established]. Этот JTBD валиден при условии наличия подготовленного FAQ-каталога.

**JTBD-2 (заявитель на self-service портале).** Реалистичный ITSM-сценарий с точки зрения методологии: deflection через self-service FAQ — ключевой KCS-принцип (KCS v6, Solve Loop: «search early, search often») и основной способ влиять на deflection rate [established]. **Однако:** этот JTBD предполагает наличие:
- Self-service портала с интеграцией с pg_vector_service,
- Достаточного каталога FAQ-записей с ответами.

Ни того, ни другого на `llm2` (PoC-стенде) нет. Scope выходит за PoC. Требует owner-decision.

**JTBD-3 (чат-бот).** Аналогично: чат-бот-интеграция — явно за рамками PoC. Journey-3 с автоматическим ответом при score ≥ 0.90 — это MVP/Pilot-scope, не PoC.

**OQ-FAQ (класс FAQ-объектов).** С точки зрения ITSM best-practice:
- Вариант A (отдельный класс `faq$question`) — соответствует ITIL 4 Knowledge Management: KB-статьи (Knowledge Articles) и FAQ — разные типы контента с разным жизненным циклом.
- Вариант B (`knowledgeBase$article` с `type=question`) — компромисс для PoC, допустимый если нет ресурса на создание нового класса.

Рекомендация: **Вариант A**, если создание класса занимает ≤ 1 дня (по оценке Сахабетдинова). KCS v6 явно различает FAQ-статьи (вопрос + ответ, «Known Error Article») и информационные KB-статьи (Knowledge Article, «How-To») [established].

**AC-оценка.** BR-003 (cutoff обязателен, «пустой список лучше нерелевантного ответа») — отличное ITSM-правило, соответствующее принципу Atlassian JSM: лучше не показать ничего, чем показать нерелевантное [established].

**NFR-S3-002** (Precision@5 ≥ 0.80 при threshold=0.75) — черновой порог. С точки зрения ITSM: для оператора на форме регистрации precision важнее recall (false positive хуже, чем не показать). 0.80 — реалистичный PoC-target [established].

**Рекомендации для BA:**
- JTBD-2 и JTBD-3 пометить явно как «scope MVP/Pilot, не PoC» — или вынести в отдельные «candidate UC» с явным owner-decision gate.
- Journey-3 (чат-бот с auto-answer при score ≥ 0.90) — вынести за рамки PoC явным образом.
- OQ-FAQ — эскалировать owner (Демьянов) на ближайшем синке. До решения UC-S3 не проектируется (уже правильно указано в Бриф для SA).

**Рекомендации для SA:** проектировать UC-S3 только по JTBD-1 (operator FAQ suggestion) в рамках PoC. JTBD-2/3 учитывать как will-do после owner-decision.

---

### 2.6. UC-S4 — Поиск похожих KB-статей

**Verdict:** ✅ Соответствует ITSM best-practice.

**JTBD-оценка.** JTBD-1 (автор KB проверяет дубли перед публикацией) — прямая реализация KCS v6 принципа «Seek and Reuse before Create» [established]. ServiceNow Knowledge Management содержит аналог: «Duplicate Detection при создании статьи» [established]. JTBD-2 (оператор получает KB-подсказку из заявки — cross-class) — стандартный ITIL 4 Incident Management workflow (поиск Known Error / Workaround в KB при обработке инцидента) [established].

**ACL (BR-002, post-aggregation).** Применение `kbAccesses` post-aggregation (после GROUP BY чанков) — правильный подход. В KCS v6 доступность KB-статей регулируется ролями (Agent-only vs public vs self-service) — `kbAccesses` в SMP — это соответствующий механизм [established].

**Parent-document retrieval (FR-004, BR-005).** Паттерн MAX_SIMILARITY(chunks) per parent — стандарт LangChain/LlamaIndex для chunked KB, подходящий для ITSM Knowledge Management [established].

**Статус KB (FR-006, FR-009).** Исключение `closed`-статуса по умолчанию при `include_closed=true` как параметр — соответствует ITIL 4 Knowledge Management: Knowledge Articles проходят lifecycle (draft → reviewed → published → retired), поиск ведётся только по published [established].

**NFR-S4-002** (Recall@10 ≥ 0.80) — реалистичный threshold для ITSM KB-retrieval [established].

**Рекомендации для BA:**
- Q3 (нужна ли пометка «статья содержит N страниц» для multi-chunk KB-статей) — с точки зрения Knowledge Management это полезный UX-сигнал, но не критично для PoC. Рекомендую defer до MVP.
- Добавить в AC или JTBD явную связку с KCS «Seek and Reuse before Create» — это поможет обосновать UC перед операционным блоком.

---

### 2.7. UC-C1 — Кластеризация заявок по описанию

**Verdict:** ✅ Соответствует ITSM best-practice.

**JTBD-оценка.** JTBD-1 (online near-duplicate detection при регистрации) — стандартный ITSM-паттерн. Прямые аналоги: ServiceNow «Similar Incidents» при создании инцидента (Predictive Intelligence), BMC Helix «Similar Incidents» на карточке, Atlassian JSM «Similar Requests Panel» [established]. JTBD-2 (batch-аудит очереди, отчёт N кандидатов на слияние) — соответствует ITIL 4 Problem Management (proactive problem identification через анализ трендов инцидентов) [established].

**BR-001 «Никакого автомёрджа в PoC».** Правильная позиция. ITIL 4 явно требует human oversight при изменении incident records. Автоматическое слияние без участия оператора нарушает ITIL Change Enablement principle (изменения в производственных данных = change) [established].

**Пороги (FR-003: «Дубль» ≥ 0.92, «Похожая» ≥ 0.85).** Черновые, ожидают offline-eval. С точки зрения ITSM-практики: ServiceNow PI confidence threshold default = 70% (отображает suggested, не автоматизирует), BMC Helix similarity threshold default = 7/10. Пороги в UC-C1 выше (что разумно при отсутствии большого training set). Финальные значения должны быть откалиброваны под precision/recall-требования Service Desk конкретного тенанта [established].

**Online latency (NFR-C1-001: ≤ 2 с p95).** Соответствует UX-требованиям для подсказок при регистрации заявок: более 2 с — пользователь уходит и не ждёт. ServiceNow аналогичные фичи работают в sub-1s на продакшн [established].

**Сценарий А (online), FR-007 (silent skip при таймауте).** Правильная resilience-стратегия. ITIL Service Request Management: процесс регистрации заявки не должен блокироваться вспомогательными AI-фичами [established].

**Batch-алгоритм (OQ-C1-4: cosine-threshold vs HDBSCAN+UMAP).** HDBSCAN — инструмент из Google SRE / AIOps практики (мониторинг событий), известный в ITSM через Moogsoft. Cosine-threshold baseline — более предсказуем. Для первого PoC cosine-threshold baseline достаточен [established].

**Рекомендации для BA:**
- Добавить JTBD-1 явную ссылку на ITIL 4 Incident Management trigger: «Detect and link duplicate incidents» — это усиливает обоснование UC.
- В AC добавить post-PoC optional метрику: «После внедрения UC-C1 время первичной сортировки очереди (duplicate identification step) сокращается на X%». Это даст операционному блоку (Сазонова) понятный KPI.
- OQ-C1-6 (показывать ли «Похожая» или только «Дубль» в PoC) — рекомендую показывать оба уровня, но с разными CTA: «Дубль» — кнопка «Связать», «Похожая» — только информация.

---

### 2.8. UC-C2 — Кластеризация по описанию + комментариям (combined signal)

**Verdict:** ✅ Соответствует ITSM best-practice. Ключевая инновация относительно vendor baseline.

**JTBD-оценка.** JTBD-1 (аналитик находит группы с одинаковым root cause через переписку) и JTBD-2 (руководитель SD — кластеры по итоговой причине) — JTBD, которых нет в коробочных ITSM-продуктах. Это инновационный сценарий выше vendor baseline [emerging]. Бизнес-гипотеза («две заявки с разным описанием, но одинаковым root cause в переписке») — реалистична и соответствует операционной реальности Service Desk (заявители формулируют симптомы по-разному, но root cause выявляется в ходе диагностики) [established].

**Combined signal (FR-002: w1 × issue_cosine + w2 × comment_agg_cosine).** Корректный подход. Академически подтверждён: weighted combination issue-vector + comment-aggregate даёт лучший MAP, чем только issue-вектор (MAP=0.829 vs 0.751 в исследовании по дедупликации) [established, по данным research itsm-similarity-search-patterns.md §4].

**Fallback (FR-003): заявки без комментариев используют только issue-signal.** Правильная resilience-стратегия. В реальной Service Desk значительная часть заявок закрывается без комментариев (автоматические закрытия, быстрые решения «по телефону»). Fallback не искажает статистику [established].

**BR-002 (явный fallback в отчёте).** Хорошая практика прозрачности для аналитика. COBIT 2019 требует прозрачности данных в отчётах управления ИТ-услугами [established].

**NFR-C2-002: отчёт показывает, сколько заявок с combined signal vs issue-only.** Важный KPI для оценки эффективности UC-V2: если 80% заявок fallback на issue-only — UC-V2 не добавляет ценности [established].

**OQ-CL-3 (нужен ли UC-C2 в PoC).** Рекомендация с точки зрения ITSM: если OQ-V2-1 (sign-off на comment.text) не будет получен в PoC — UC-C2 полностью вырождается в UC-C1. Решение owner'а о sign-off является фактическим gate для UC-C2. BA и PM должны явно синхронизировать OQ-V2-1 и OQ-CL-3.

**Рекомендации для BA:**
- OQ-CL-3 — сделать явным: «UC-C2 в PoC реализуется только при sign-off OQ-V2-1 (comment.text whitelist) до конца iteration 1». Иначе UC-C2 = техдолг.
- В NFR-C2-002 добавить AC: «отчёт содержит ratio "combined signal / issue-only signal"; BA и аналитик должны видеть этот ratio перед принятием решения о ценности UC-C2».

---

## §3. NFR-секция

### 3.1. NFR-Cross-Cutting (NFR-070..075)

**NFR-070 (ACL-наследование комментариев).** ✅ Технически и методологически корректно. ACL от parent-объекта — единственно возможная модель при отсутствии собственного ACL у комментариев в SMP. Соответствует ISO 20000-1:2018 §9.4 (Information Management) и ITIL 4 (принцип минимального раскрытия информации) [established].

**NFR-071 (Preprocessing-версионирование в composite_hash).** ✅ Корректно. Включение `algorithm_version` в ключ идемпотентности — инженерная best practice, не ITSM. Для ITSM-контекста важно, что это обеспечивает reproduciblity результатов поиска и кластеризации при аудите (COBIT 2019 AI-04: обеспечение надёжности AI-результатов) [established].

**NFR-072 (Отдельный latency-бюджет для UC-S2: ≤ 1 000 ms).** ✅ Реалистичный бюджет. 2× overhead vs UC-S1 за счёт GROUP BY + aggregation — технически обоснованно. С точки зрения ITSM-UX: 1 000 ms p95 для оператора SD — допустимо для «secondary panel» (не для главной карточки заявки, а для вспомогательной панели «Похожие по переписке»). Для основной карточки (UC-S1, UC-C1) ≤ 500 ms / ≤ 2 s — корректнее [established].

**NFR-073 (Детерминированность preprocessing).** ✅ Критически важный инвариант. В ITSM-контексте: детерминированность обеспечивает воспроизводимость аудита («почему система показала именно эти заявки») — требование COBIT 2019 [established].

**NFR-074 (Cap=50 на comment-объект).** ✅ Обоснованный параметр. Finding: выбор «последние 50 по дате» vs «топ-50 по длине» (OQ-V2-4) имеет ITSM-смысл. С точки зрения KCS: наиболее ценные комментарии — «resolution context» (последние) и «high-density diagnostic comments» (длинные). Рекомендую **последние N по дате** как default: они содержат итог диагностики. «Топ-N по длине» — как опция для аналитического режима [established].

**NFR-075 (Системные комментарии — исключение).** ✅ Правильное решение. KCS v6 явно: «discussion threads» — шум для knowledge management. Системные/аудитные комментарии — тем более. Finding: до закрытия OQ-V2-2 (точный список excluded_meta_classes) это NFR является неполным. Рекомендую BA пометить его как «requires OQ-V2-2 closure».

**BR-cross-5 (comment-вектор виден пользователю только при наличии прав на родительский объект).** ✅ Соответствует ISO 20000. Единственное замечание: в тексте требования нет явного AC для этого правила в NFR-cross-cutting (AC есть в UC-V2 AC-003 и UC-S2 AC-003, но не в самом NFR). Рекомендую добавить сквозной acceptance criterion в раздел §9 Брифа для SA.

### 3.2. NFR-preprocessing.md

**Verdict:** ✅ Соответствует ITSM best-practice и RAG engineering best practices.

**Mixed strategy (plain для issue/comment, markdown для KB).** Соответствует Microsoft Azure RAG best practices: «operational logs / ticket descriptions → plain; informational KB articles → markdown» [established]. Конкретно для ITSM: issue-атрибуты действительно неструктурированы, KB-статьи действительно структурированы — выбор обоснован.

**NFR-PRE-001 (Детерминированность)** и **NFR-PRE-005 (Тестируемость без SMP)** — хорошие инженерные требования. Тестируемость preprocessing в isolation соответствует принципу hexagonal architecture (ссылка на эталон `naumen-smp-mcp`) [established].

**OQ-PRE-2 (URL'ы в KB.content после markdown).** Это PII-риск высокой степени: KB-статьи могут содержать ссылки на внутренние системы с параметрами (например, URLs с user-id в query string). Рекомендую BA эскалировать owner'у (Демьянов) как обязательный PII-аудит до активации KB-векторизации. Фильтрация `[text](url) → text` при markdown-pipeline — необходима до первого запуска на production данных.

**OQ-PRE-3 (emoji в комментариях).** Minor. В ITSM-контексте emoji в комментариях — скорее шум (операционные комментарии редко используют emoji семантически). Рекомендую strip как default [contested — зависит от культуры коммуникации конкретного тенанта].

---

## §4. Сквозные находки

### 4.1. Терминологическая консистентность

**issue vs incident vs request vs serviceCall.**

В каталоге используется `issue` — корректный SMP-термин для всего семейства `serviceCall$*`. Однако для читателей с ITIL-бэкграундом (операционный блок, будущие auditors) это создаёт confusion: в ITIL 4 `issue` = любая проблема, а `incident` и `service request` — строго разные типы объектов.

**Рекомендация:** добавить в glossary явный mapping:
```
issue (SMP/pg_vector_service) = serviceCall$* = ITIL 4 Incident + Service Request + Change Request (в одном FQN-пространстве)
```
Это не требует переименования в UC, но помогает при коммуникации с операционным блоком.

**decisionReport vs RCA.**

В glossary уже есть: `RCA = decisionReport (на problem)`. Но в UC-V1 BR-001 `decisionReport` упомянут как атрибут `issue` — это требует проверки через метамодель (см. Finding в §2.1). В SMP `decisionReport` типично является атрибутом `problem`, а у `issue` для этой цели существует `cancelReason` + `feedback`.

**knowledgeBase vs KCS Article.**

Глоссарий содержит: `knowledgeBase$article = KCS Article`. Это корректно как mapping по смыслу, но нужно дополнить: KCS различает Knowledge Article types (How-To, FAQ/Known Error, Process). В SMP все они хранятся в `knowledgeBase$article`. При общении с операционным блоком использовать «статья KB» (не «KCS Article») — последнее требует объяснения методологии.

### 4.2. Пропущенные ITSM use case'ы

**Потенциально ценные, не описанные в текущем каталоге:**

1. **Major Incident Similarity Search (P1/P2 Bridge).** Для on-call инженера, который занимается Major Incident: найти все исторические Major Incidents с похожим описанием и их resolution notes. Отличается от UC-C1/UC-S1: фокус только на P1/P2, срочность < 60 секунд на поиск, важны resolution notes (закрытые статусы обязательны, `include_closed=true`). Аналог: ServiceNow Major Incident Management «Similar Past Incidents» [established]. **Вывод:** реализуется как конфигурация UC-S1 (фильтр по priority, include_closed=true) без нового UC. Owner-decision: включать ли Major Incident filter в UC-S1 как отдельный preset.

2. **Predictive Resolution Suggest.** Предложение готового решения на основе resolution notes похожих закрытых заявок. Аналог: ServiceNow Now Assist «Similar Resolved Incidents → Suggested Resolution» [established]. **Вывод:** это MVP/Pilot-scope — требует LLM-генерации (summarization), что за рамками PoC (векторный поиск, не генерация).

3. **Automatic Problem Creation Candidate.** Выявление кластера заявок, превышающего threshold volume, и автоматическое предложение создать `problem`. Аналог: BMC Helix ITSM Auto Problem Detection [established]. **Вывод:** расширение UC-C1 Сценарий Б. Для PoC достаточно отчёта; автоматическое предложение — MVP.

**Вывод:** ни один из этих UC не является критически пропущенным для PoC. Major Incident filter — owner-decision (предложить как параметр UC-S1, не новый UC).

### 4.3. UC, которые в ITSM-практике делаются НЕ через similarity search

Обнаружено несколько requirement-паттернов, где similarity search — не лучший инструмент:

1. **UC-C1 Online-подсказка при регистрации** — в практике многих Service Desk это делается через **category-based routing** (структурные поля: услуга + категория + subcategory) или **rule-based deduplication** (keyword matching по exact-match). Similarity search добавляет ценность поверх категорий, но не заменяет их. BA/SA: UC-C1 online работает лучше в связке с фильтром по услуге / подклассу, а не только по composite_extended [established].

2. **UC-S3 FAQ-поиск** — в первые месяцы после запуска, при малом корпусе FAQ (< 100 записей), **simple keyword/BM25** достаточен и более предсказуем, чем vector search. Semantic FAQ search ценен при большом корпусе (500+ FAQ) или коротких нечётких запросах. BA: добавить OQ по минимальному объёму FAQ для обоснования vector vs keyword в PoC [emerging].

---

## §5. Приоритизированный backlog для BA-003

### Critical (блокирует качество продукта)

**BA-003-C1. Переформулировать JTBD-1 UC-S2.**
Текущий JTBD-1 описывает нишевый сценарий с высоким шумом. Переформулировать по Варианту B (resolution/closing comment как source):
- JTBD-1: «Оператор находит конкретный комментарий-резюме агента (написанный при закрытии или содержащий root cause) и хочет найти заявки, где в переписке обсуждался тот же root cause».
- Удалить JTBD-2 из UC-S2, перенести в UC-C2 (он там уже есть).
- Добавить precondition к FR-001: поиск по comment_id оптимален для closing/resolution комментариев; для discussion-реплик рекомендуется UC-S1.

### Major (ослабляет обоснование ценности перед бизнесом)

**BA-003-M1. Ограничить PoC-scope UC-S3.**
JTBD-2 (self-service портал) и JTBD-3 (чат-бот), Journey-3 (auto-answer при score ≥ 0.90) — пометить явно как «out of scope PoC, scope MVP/Pilot». Добавить owner-decision gate: «UC-S3 реализуется в PoC только для JTBD-1 (operator FAQ suggestion)». Добавить OQ: «Какой минимальный объём FAQ-записей необходим для обоснования vector vs keyword search?»

**BA-003-M2. Добавить ITSM-KPI в AC UC-S1 и UC-C1 (опционально, post-PoC).**
Добавить в AC-011/AC-012 UC-S1 и AC-001/AC-003 UC-C1 примечание: «Post-PoC optional target: снижение MTTR на этапе идентификации дубля / поиска решения на X% (измеряется пилотной группой операторов)». Это не обязательно для технического go/no-go, но критично для обоснования перед операционным блоком (Сазонова, Киселёва).

### Minor (улучшает качество требований)

**BA-003-m1. Проверить `decisionReport` в whitelist UC-V1 для `issue`.**
Через MCP `metamodel_export_class serviceCall$incident` проверить: присутствует ли `decisionReport` как атрибут `issue`. Если нет — убрать из BR-001 или добавить аннотацию «только при наличии в метамодели».

**BA-003-m2. Закрыть OQ-V2-2 (список excluded system comment meta_classes).**
Без этого NFR-075 и BR-002 (UC-V2) неполны, а Variant B для UC-S2 не реализуем. Приоритизировать через MCP или запрос к Сахабетдинову.

### Nit (полировка, не критично)

**BA-003-n1. Добавить ITIL-mapping в glossary.**
Добавить: `issue (SMP) = serviceCall$* = ITIL 4 Incident + Service Request`. Добавить: KB Article lifecycle (draft → reviewed → published → retired) — явную ссылку на ITIL 4 Knowledge Management lifecycle.

---

## §6. Открытые вопросы для owner-decision

Вопросы, которые BA не может решить самостоятельно:

| # | Вопрос | Контекст | Адресат |
|---|--------|----------|---------|
| OQ-ITSM-1 | Scope UC-S3: ограничить PoC только JTBD-1 (оператор FAQ suggestion) или включать JTBD-2 (self-service) с пониманием, что это требует дополнительной инфраструктуры? | self-service портал и чат-бот — за рамками PoC, но если owner хочет их в scope — нужна явная инфраструктурная оценка | Owner (Демьянов) |
| OQ-ITSM-2 | Major Incident filter в UC-S1: добавить preset «Major Incident mode» (фильтр по priority=P1/P2, include_closed=true)? Это не новый UC, а параметр UC-S1 | Ценный операционный сценарий, но требует наличия Priority-атрибута в whitelist | Owner + BA |
| OQ-ITSM-3 | UC-S2 Variant B: есть ли в SMP механизм отличить closing/resolution comment от discussion reply? (OQ-R10-4) | Если нет — нужна либо LLM-классификация, либо эвристика «последний комментарий перед финальным статусом» | SA + Сахабетдинов |
| OQ-ITSM-4 | sign-off на comment.text (OQ-V2-1): когда ожидается решение? От этого напрямую зависит scope UC-V2, UC-S2, UC-C2 в PoC | Если sign-off не будет получен в iteration 1 — UC-C2 и UC-S2 defer до MVP | Owner (Демьянов) |
| OQ-ITSM-5 | FAQ-класс: OQ-FAQ owner-decision (вариант A: `faq$question` vs вариант B: `knowledgeBase$article` с type=question). Рекомендация ITSM: вариант A при доступности создания класса | Блокер для UC-S3 в SA-фазе | Owner (Демьянов) + Сахабетдинов |

---

## §7. References

- [established] **ITIL 4 Practice Guide — Incident Management** — matching incidents to other incidents and known errors; structured linked record practice. Ключевая ссылка для UC-S1, UC-C1 JTBD обоснования. Требуется `/research` для точного номера страницы AXELOS ITIL 4 Incident Management Practice Guide (2020).

- [established] **ITIL 4 Practice Guide — Problem Management** — proactive problem identification through incident trend analysis; Problem Management uses incident records as primary signal. Ключевая ссылка для UC-S1 JTBD-2 (аналитик K=100), UC-C1 JTBD-2 (batch-аудит). Требуется `/research` для точного номера страницы.

- [established] **ITIL 4 Practice Guide — Knowledge Management** — Knowledge Article lifecycle (draft → reviewed → published → retired); KCS-aligned create/search/reuse practices; KB access by roles. Ключевая ссылка для UC-S4, UC-S3 обоснования.

- [established] **KCS v6 Practices Guide — The Solve Loop** (Consortium for Service Innovation, https://library.serviceinnovation.org/KCS/KCS_v6/KCS_v6_Practices_Guide/030/030) — «search early, search often»; composite context (subject+description+environment) как primary search signal; classification: capture context vs resolution context vs discussion threads. Ключевая ссылка для UC-S1, UC-S3, UC-V2 обоснований, против UC-S2 JTBD-1.

- [established] **KCS v6 Practices Guide — Knowledge Article Types** (Consortium for Service Innovation) — FAQ/Known Error Article vs Knowledge Article (How-To); разные типы с разным lifecycle. Ключевая ссылка для OQ-FAQ (UC-S3 вариант A vs B). Требуется `/research` для точной URL.

- [established] **ServiceNow Predictive Intelligence — Community Guide** (https://inlk.ai/2025/04/15/predictive-intelligence-in-servicenow-concepts-and-implementation/, 2025) — similarity framework: `short_description` + `description`; work notes не в основной конфигурации. Ключевая ссылка для UC-S2 анализа (против single comment), UC-S1 vendor validation.

- [established] **ServiceNow Now Assist ITSM — Similar Resolved Incidents** — GenAI-режим: short description + description + **resolution notes** как триада сигналов. Ключевая ссылка для UC-S2 Variant B (resolution notes как ценный comment signal).

- [established] **BMC Helix ITSM Insights — Incident Correlation** (https://docs.bmc.com/xwiki/bin/view/Service-Management/IT-Service-Management/BMC-Helix-ITSM-Insights/itsminsights262/Administering/Configuring-incident-correlation-to-detect-similar-incident-clusters/) — DistilBERT на `description`; структурные group-by; комментарии не в алгоритме. Ключевая ссылка для UC-S1, UC-C1 vendor validation; против UC-S2 JTBD-1.

- [established] **Zendesk — Enhanced similar ticket results** (https://support.zendesk.com/hc/en-us/articles/8948823362458, 2024) — subject + first public comment + intent + entity + time decay. Ключевая ссылка: «первый комментарий» = начальное описание клиента, не промежуточные реплики агента. Критически важно для UC-S2 Variant B обоснования.

- [established] **Atlassian JSM — Find similar work items** (https://support.atlassian.com/jira-service-management-cloud/docs/what-are-similar-requests/) — summary-based native similarity; KB suggestions at ticket creation. Ключевая ссылка для UC-S1, UC-S3, UC-S4 vendor validation.

- [established] **Moogsoft APEX AIOps — Similar Incidents** (https://docs.moogsoft.com/moogsoft-cloud/en/similar-incidents-overview.html) — Jaccard index на структурных полях; комментарии для human review, не в алгоритме. Ключевая ссылка против UC-S2 JTBD-1.

- [established] **ISO/IEC 20000-1:2018, §9.4 Information Management** — требования к контролю доступа к информации управления услугами; принцип least privilege. Ключевая ссылка для NFR-070 (ACL-наследование), NFR-002 (PII-категоризация).

- [established] **COBIT 2019, AI-04 (Ensure AI Reliability and Transparency)** — воспроизводимость и прозрачность AI-результатов для аудита. Ключевая ссылка для NFR-071 (preprocessing-версионирование), NFR-073 (детерминированность), UC-C2 BR-002 (явный fallback в отчёте).

- [established] **Microsoft Azure RAG Best Practices — HTML Normalization** — «operational logs/ticket descriptions → plain text; informational KB articles → markdown». Ключевая ссылка для nfr-preprocessing.md Mixed strategy обоснования.

- [emerging] **ServiceNow Major Incident Management — Similar Past Incidents** — P1/P2 bridge workflow: поиск похожих исторических Major Incidents при создании нового. Требуется `/research` для точного URL и версии.

---

*Ревью завершено. Критических нарушений контракта роли нет: файлы в `content/30-requirements/` не редактировались.*
