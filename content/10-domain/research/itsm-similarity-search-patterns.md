---
order: 91
title: "ITSM Similarity Search — паттерны single-signal vs composite"
properties:
  - Тип контента: Исследование
  - Фаза: PoC
  - Статус: Draft
---

# ITSM Similarity Search — паттерны single-signal vs composite

**Дата:** 2026-05-01
**Исследователь:** researcher-agent
**Запрос PM/BA:** Разобрать вопрос owner'а: «по одному комментарию нормального поиска не получится — нужен комплексный сигнал». Собрать ITSM-практику и индустриальные паттерны для пересмотра UC-S2.
**Глубина:** standard (≈ 2 ч, 10+ источников)

---

## §1. TL;DR — ответ на вопрос owner'а

**Тезис Демьянова подтверждается практикой и исследованиями.**

Ни один из ведущих ITSM-продуктов (ServiceNow, BMC Helix, Zendesk, Moogsoft) не строит поиск похожих инцидентов по тексту одного произвольного комментария. Все они используют:
- основной атрибутный сигнал (subject/short_description/description) как первичный,
- структурные метаданные (сервис, CI, категория) как фильтр,
- комментарии — только в специальных режимах и только агрегированно.

Академическая литература по дедупликации bug-репортов (ближайший аналог ITSM-тикетов) подтверждает: title + description дают f1 98%+, тогда как изолированные разделы «шагов воспроизведения» и «фактических результатов» снижают точность. Комментарии ценны в **post-submission** сценарии, когда заявитель частично разбивает описание на несколько сообщений, или когда оператор вносит root cause — но только при условии агрегации, не как отдельный запрос.

**Итог для UC-S2:** JTBD «оператор ищет похожие заявки по одному комментарию» — валидный edge-case, но не основной сценарий. Основной сценарий — composite: issue-атрибуты + агрегат комментариев. UC-S2 требует переработки.

---

## §2. Как индустрия решает задачу «найти похожие инциденты»

### 2.1. ServiceNow Predictive Intelligence / Now Assist

**Similarity framework (традиционный ML, pre-GenAI):**
ServiceNow строит поиск похожих записей на основе **word corpus** (TF-IDF взвешенный словарь терминов) по полям записи. Поддерживаемые поля для similarity solution: **short_description** (обязательный, 80 символов) и **description**. Work notes и additional comments в модель similarity *не входят* в конфигурации по умолчанию — в официальных примерах конфигурации упоминается только short_description + description + CI/service offering.

Цитата из официальной документации community: «short_description — gist of the incident, ≤80 chars. Work notes — strictly for technical ITIL users, of little interest to the Caller.» Запрос по work notes через Predictive Intelligence требует явной кастомизации.

**Now Assist — Similar Resolved Incidents (GenAI-режим):**
Новый функционал Now Assist ITSM использует для поиска аналогов **short description + description + resolution notes** (итоговое решение). Модель находит закрытые инциденты со схожим описанием проблемы и предлагает агенту готовое решение. Work notes здесь тоже не первичный сигнал — focus на resolution.

**Минимум данных для обучения:** 10 000+ инцидентов для similarity model.

[primary] [ServiceNow Predictive Intelligence — Community Guide](https://inlk.ai/2025/04/15/predictive-intelligence-in-servicenow-concepts-and-implementation/) — [established]

[primary] [ServiceNow community: how to find similar incidents by description/work notes](https://www.servicenow.com/community/itsm-forum/what-is-the-best-way-to-identify-a-similar-or-related-incident-s/m-p/565056) — [established]

### 2.2. BMC Helix ITSM Insights

BMC Helix Insights использует для кластеризации инцидентов **DistilBERT** (облегчённый BERT) — семантическое сходство по полям description/summary. Ключевые параметры кластеризации:
- primary field: **description** (textual similarity)
- group-by fields: service, product category, tenant company, operational category (структурные фильтры)
- до 5 дополнительных text-полей настраиваются вручную
- similarity threshold: 1–10 (default 7), configurable

Комментарии (work notes, notes) **не являются частью кластеризационного алгоритма** в официальной документации. Они служат для человеческого изучения «как похожий инцидент был решён» — но в вычислении сходства не участвуют.

[primary] [BMC Helix ITSM Insights — Incident Correlation](https://docs.bmc.com/xwiki/bin/view/Service-Management/IT-Service-Management/BMC-Helix-ITSM-Insights/itsminsights262/Administering/Configuring-incident-correlation-to-detect-similar-incident-clusters/) — [established]

### 2.3. Zendesk «Similar Tickets»

Zendesk Similar Tickets — наиболее полно задокументированный пример multi-signal подхода в коммерческом продукте.

**Сигналы (обновлённый алгоритм 2024):**
1. **Subject + text of the first public comment** — базовый входной сигнал для intent classification
2. **Intent matching** — тематическая классификация тикета (причина обращения); если intent совпадает с высокой уверенностью — result boost
3. **Entity matching** — упомянутые сущности в тикете (например, имя продукта, устройство); совпадение сущностей — boost
4. **Time decay** — недавние похожие тикеты получают приоритет над старыми

**Ключевой факт:** сигнал для intent берётся из **subject + первого публичного комментария** — то есть из первоначального описания проблемы клиентом. Последующие комментарии (ответы агента, системные уведомления) в алгоритм **не входят**.

[primary] [Zendesk — Announcing enhanced similar ticket results](https://support.zendesk.com/hc/en-us/articles/8948823362458-Announcing-enhanced-similar-ticket-results-boosted-by-intents-and-entities) — [established]

[primary] [Zendesk — Automatically classifying intent, sentiment, language](https://support.zendesk.com/hc/en-us/articles/4550640560538-Automatically-detecting-customer-intent-sentiment-and-language) — [established]

### 2.4. Moogsoft APEX AIOps — Similar Incidents

Moogsoft (Dell APEX AIOps) использует **Jaccard index** для определения схожести инцидентов — но по **структурным полям** alert/event, а не по свободному тексту:
- deduplication key: source, service, check, class
- similarity fields: check, manager, class, type (конфигурируемые)
- threshold similarity ≥ 70% = похожий инцидент

Комментарии: «Remember that comments are key to understanding how a past incident was resolved. Be sure to mark resolving steps in the comments when resolving an incident.» — но комментарии **не входят в алгоритм similarity calculation**, они служат для human review при изучении похожих исторических инцидентов.

Паттерн Moogsoft: алгоритм основан на event-correlation (структурных сигналах), а не на семантике текста.

[primary] [Moogsoft APEX AIOps — Similar Incidents Overview](https://docs.moogsoft.com/moogsoft-cloud/en/similar-incidents-overview.html) — [established]

### 2.5. Jira Service Management «Find Similar Requests»

JSM имеет встроенную «Similar Requests Panel», которая работает по **summary (заголовку) тикета**. Для более глубокого семантического поиска JSM требует третьесторонних плагинов (например, «Find Duplicates» от Atlassian Marketplace) или кастомных решений на векторных эмбеддингах.

Нативный алгоритм JSM аналогично ориентирован на первоначальное описание, а не на комментарии в тикете.

[primary] [Atlassian Support — Find similar work items in JSM](https://support.atlassian.com/jira-service-management-cloud/docs/what-are-similar-requests/) — [established]

---

## §3. ITIL 4 / KCS-перспектива

### 3.1. ITIL 4 Problem Management

ITIL 4 описывает поиск похожих инцидентов в практике **Problem Management** — реактивное выявление проблем через анализ трендов инцидентов:

> «Problem Management анализирует incident records и операционные логи для нахождения паттернов и трендов, указывающих на наличие underlying errors. Incidents should be matched to other incidents, problems and known errors.»

ITIL не описывает конкретные алгоритмы, но фокус — на **incident records (описания, категории, CI)**, а не на комментариях. Линкование инцидентов к проблеме происходит через атрибутные поля.

[secondary] [ITIL Problem Management — IT Process Wiki](https://wiki.en.it-processmaps.com/index.php/Problem_Management) — [established]

### 3.2. KCS — Knowledge-Centered Service

KCS (Knowledge-Centered Service v6, Consortium for Service Innovation) описывает два контекста поиска в Solve Loop:

**«Search early, search often»** — поиск в Knowledge Base происходит **в начале обработки тикета**, по контексту текущей заявки. Это composite-сигнал: subject + description + environment context. Цель — найти статью KB, которая решит проблему.

**«Browse for pattern»** (не формальный термин KCS, но описываемый сценарий) — когда аналитик ищет не готовое решение, а паттерн для Problem creation. Здесь могут использоваться и комментарии, но **как артефакты уже решённых заявок** (resolution notes, KB articles), а не как запрос.

KCS явно различает:
- **Capture context** (что пишет заявитель при создании — этот текст важен для поиска),
- **Resolution context** (что пишет агент при закрытии — это ценный signal для knowledge base),
- **Discussion threads** (промежуточные комментарии — шум с точки зрения knowledge content).

[primary] [KCS v6 Practices Guide — The Solve Loop](https://library.serviceinnovation.org/KCS/KCS_v6/KCS_v6_Practices_Guide/030/030) — [established]

[primary] [Atlassian ITSM — What is KCS](https://www.atlassian.com/itsm/knowledge-management/kcs) — [secondary]

---

## §4. Multi-signal стратегии: классификация подходов

| Стратегия | Описание | Когда применять | Примеры |
|-----------|----------|-----------------|---------|
| **Single-signal: primary field** | Embedding только subject/description | Высокая информационная плотность первичного поля; новые заявки без комментариев | JSM summary-only, ServiceNow short_description |
| **Single-signal: resolution note** | Embedding только из resolution/close note | «Найти похожие закрытые случаи по итогу» | Now Assist Similar Resolved |
| **Single-signal: single comment** | Embedding одного произвольного комментария | **Проблематично**: высокий variance (см. §5) | UC-S2 в текущей формулировке |
| **Composite (early fusion)** | Конкатенация всех текстовых полей → один embedding | Один индекс, простой retrieval | ServiceNow word corpus (TF-IDF по составному тексту) |
| **Composite weighted (late fusion)** | Раздельные embeddings → взвешенная сумма scores | Разные веса значимости для полей | UC-C2 w1×issue + w2×comment_agg |
| **Multi-vector + max-sim aggregation** | Раздельные embeddings per comment → max similarity при запросе | «Есть ли хоть один комментарий с похожей темой» | UC-S2 (текущая архитектура max-sim) |
| **Hybrid BM25 + vector (RRF)** | BM25 keyword search + dense vector, rank fusion | Когда важны точные термины (номера ошибок, коды) + семантика | Общая best practice retrieval, не специфична для ITSM |

### 4.1. Reciprocal Rank Fusion (RRF)

RRF — алгоритм объединения ранжированных списков из разных retriever'ов без нормализации скоров. Формула: `RRF(d) = Σ 1/(k + rank_i(d))`, где k=60 (стандарт). Решает проблему несовместимых шкал BM25 и cosine similarity.

В контексте ITSM-поиска: использование RRF позволяет объединить keyword-поиск по exact-match (номера заявок, коды ошибок) с семантическим поиском по embeddings. Для OQ-S2-1 (aggregation ranking): RRF применим и для объединения результатов issue-поиска + comment-поиска.

[primary] [OpenSearch — Introducing RRF for hybrid search](https://opensearch.org/blog/introducing-reciprocal-rank-fusion-hybrid-search/) — [established]

[primary] [ParadeDB — What is RRF](https://www.paradedb.com/learn/search-concepts/reciprocal-rank-fusion) — [established]

---

## §5. Когда комментарии помогают, когда нет

### 5.1. Факторы, снижающие ценность одного комментария как search signal

**1. Информационная плотность коротких комментариев.** Типичные ответы в ITSM-тикете: «перезвоните», «принято в работу», «проверяем», «ждём ответа вендора». Такие комментарии несут **нулевой semantic content** для поиска похожих инцидентов. На данных llm2: медиана 3 комментария на заявку (p95 = 15), значительная часть — системные автоуведомления.

**2. Высокий variance length.** Короткий комментарий («та же ошибка») создаёт почти случайный вектор — embedding плохо обобщается при малом числе токенов. Длинный комментарий («после ребута 3 раза, потом помогло удалить кэш, но только временно...») может «утащить» поиск в нерелевантную область (конкретные детали кейса).

**3. Эволюция диалога.** По мере развития тикета комментарии отражают текущее состояние диагностики — могут включать dead ends, временные гипотезы, нерелевантные попытки. Embedding одного такого «промежуточного» комментария = embedding артефакта процесса, не проблемы.

**4. Academic evidence.** Исследование «Automated Duplicate Bugs Detection: Do We Really Need All Bug Report Sections?» (Springer, 2025): «title и description показывают наивысшую релевантность для duplicate detection (f1: 98.93% и 98.29% соответственно). Разделы "steps to reproduce" и "actual results" вносят путаницу и повышают misclassification rate». Комментарии в bug reports (supplementary post-submission text) частично аналогичны ITSM-комментариям.

[primary] [Springer — Automated Duplicate Bugs Detection: Do We Really Need All Bug Report Sections?](https://link.springer.com/chapter/10.1007/978-3-032-15538-2_46) — [established]

[primary] [Springer — Impact of Textual Dissimilarities of Bug Report Sections](https://link.springer.com/chapter/10.1007/978-981-96-7423-7_18) — [established]

### 5.2. Когда один комментарий может быть ценным сигналом

**H3 частично подтверждается** (см. §6 Проверка гипотез):

1. **Комментарий = root cause** написанный оператором при закрытии: «проблема оказалась в SSL-сертификате на proxy». Это высокоинформативный signal — аналог resolution notes. Условие: нужно различать тип комментария (resolution vs discussion).

2. **Комментарий = первое сообщение клиента** (Zendesk-паттерн): если канал — email/chat, первый «комментарий» фактически является описанием проблемы. Зендеск явно использует именно первый публичный комментарий как основной сигнал.

3. **Комментарий = диагностические данные с высокой плотностью**: стек-трейс, лог-сообщение, код ошибки. В таких случаях даже один комментарий несёт достаточно сигнала для поиска похожих кейсов по тексту.

[secondary] [Combining Retrieval and Classification for Duplicate Bug Detection (arXiv 2404.14877)](https://arxiv.org/html/2404.14877v1) — post-submission comments can improve detection when description is incomplete — [emerging]

### 5.3. Наблюдение: комментарии ценны как aggregate, не как single query

Академическая литература (2022–2024) показывает паттерн:
- **Post-submission** добавление комментариев к корпусу существующих записей (т.е. векторы комментариев хранятся и участвуют в retrieval по issue-запросу) — улучшает качество поиска,
- **Pre-submission** использование комментария как **query-source** для поиска других тикетов — специфичный режим с высоким шумом.

Это точно разграничивает два сценария:
- UC-S1 + UC-C2 (issue + aggregated comments → retrieval corpus): корректно, поддержано индустрией,
- UC-S2 текущий (single comment → query против comment-corpus): нишевый, требует ограничений.

---

## §6. Проверка гипотез Демьянова

| Гипотеза | Статус | Обоснование |
|----------|--------|-------------|
| **H1: Single-comment query имеет высокий variance** | **Подтверждена** [established] | Короткие комментарии → малоинформативные embeddings. Bug report research: короткие описания ломают duplicate detection. Индустриальные продукты не используют произвольный комментарий как query. |
| **H2: Composite (issue + comment_agg) стабильнее** | **Подтверждена** [established] | UC-C2 уже реализует этот паттерн (w1×issue + w2×comment_agg). Zendesk, BMC Helix — всё использует composite. Academic research: обработка элементов по отдельности с взвешенной агрегацией (SBERT MAP=0.829) лучше TF-IDF по всем данным вместе (MAP=0.751). |
| **H3: Single-comment ценен в нише** | **Частично подтверждена** [emerging] | Ценен когда: комментарий содержит root cause (написан агентом при закрытии), или является первым сообщением клиента, или содержит диагностические данные высокой плотности (стек-трейс). Не ценен: discussion-реплики в середине тикета. |
| **H4: KCS различает «search to solve» vs «browse for pattern»** | **Частично подтверждена** [established] | KCS Solve Loop явно ориентирован на поиск в момент создания тикета (composite context нового тикета против KB). «Browse for pattern» как отдельный поименованный workflow в KCS v6 не выделен, но семантически описан через аналитические активности Problem Management. |

---

## §7. Рекомендации для UC-S2

BA и SA получают три варианта переработки UC-S2 для принятия решения:

### Вариант A: UC-S2 = «Composite Search с comment-приоритетом»
**JTBD (новый):** «Оператор хочет найти похожие заявки, учитывая не только атрибутное описание, но и комментарии переписки — composite-запрос по заявке-источнику (issue vector + comment aggregate).»

- Поисковый запрос: вектор заявки-источника (composite issue + comment_agg), а не вектор одного комментария.
- Ближе к UC-S1 с обогащением comment-сигналом.
- Надстройка над UC-S1, а не отдельный UC.
- **Риск:** дублирует UC-S1 с параметром comment_weight > 0.

### Вариант B: UC-S2 = «Comment-browse» (scope narrowing, feature-flag)
**JTBD (уточнённый):** «Оператор видит конкретный комментарий-резюме (написанный агентом при закрытии или содержащий root cause / стек-трейс), и хочет найти все заявки, где в переписке обсуждался тот же root cause.»

- Сохраняет текущую архитектуру UC-S2 (comment_id → search in comment-corpus).
- Добавляет **pre-condition**: поиск работает только для комментариев с `comment_kind = 'resolution'` или содержащих диагностические маркеры (тюнинг на уровне фильтрации).
- Явно ограниченный scope, feature-flag, MVP-кандидат.
- **Риск:** требует классификации типов комментариев (UC-V2 расширение).

### Вариант C: UC-S2 = Split на UC-S2a и UC-S2b
- **UC-S2a:** Composite issue+comment search (Вариант A) — primary, scope PoC.
- **UC-S2b:** Single-comment browse (Вариант B, узкий scope) — secondary, scope MVP.
- Feature-flag: UC-S2b отключён в PoC, активируется при наличии comment-classification.
- **Риск:** усложняет backlog; оправдано только если оба JTBD чётко разграничены stakeholder'ами.

**Рекомендация Researcher:** Вариант B с явным сужением scope (precondition на тип комментария) — наименьшие изменения в архитектуре при максимальном улучшении precision. Если BA и owner подтверждают, что composite-поиск (Вариант A) — это отдельный ценный сценарий от UC-S1 — тогда Вариант C.

---

## §8. Открытые вопросы для BA/SA

| ID | Вопрос | Адресат |
|----|--------|---------|
| OQ-R10-1 | Разграничить типы комментариев в SMP: есть ли в метамодели атрибут, позволяющий отличить «resolution note» от «discussion reply»? (cf. UC-V2 BR-002 — system vs user, но нет semantic classification) | BA + MCP metamodel check |
| OQ-R10-2 | Zendesk-паттерн: если первый комментарий клиента = основное описание — нужна ли в SMP нормализация «первый комментарий клиента = extended description»? Влияет на UC-V2 whitelist. | BA |
| OQ-R10-3 | Composite search (Вариант A) vs UC-S1 с comment_weight: есть ли разница в JTBD с точки зрения оператора? Или это одна кнопка «найти похожее» с разными весами под капотом? | BA + Owner |
| OQ-R10-4 | Для Варианта B — есть ли в SMP маркер «closing comment» (комментарий добавленный при переводе в статус closed)? Или нужна LLM-классификация типа комментария? | BA + SA + MCP |
| OQ-R10-5 | Offline-eval: как оценивать качество comment-search? Ground truth `issue.duplicates` (из similarity-eval.md) построен на issue-парах, а не на комментариях. Нужен отдельный eval-набор для UC-S2? | SA |

**BA: обрати внимание на:**
- Текущий JTBD-1 UC-S2 (оператор ищет «по тексту конкретного комментария») описывает нишевый сценарий с высоким шумом. Необходимо уточнить с owner'ом и операторами: действительно ли они хотят «по одному комментарию» или «по заявке с учётом переписки».
- JTBD-2 (аналитик ищет системный сбой через комментарии) — более близок к UC-C2 (кластеризация) или к UC-S1 с аналитическим режимом (K=100), чем к comment-only search.

**SA: при проектировании учти:**
- Composite search (Вариант A) архитектурно ближе к UC-S1 с расширенным вектором (concat issue+comment_agg → один HNSW query) чем к current UC-S2 (два round-trip: query comment-corpus → group by parent_id).
- Если Вариант B сохраняется — comment-type classification как pre-filter снижает oversample-factor и повышает precision без изменения retrieval-логики.
- OQ-S2-1 (max vs sum vs RRF aggregation) — RRF применим для объединения issue-similarity и comment-similarity lists; формально решает проблему несовместимых scales.

---

## §9. Источники

**[primary] — первичные документальные источники:**

- [ServiceNow Predictive Intelligence — Concepts and Implementation (inlk.ai, 2025)](https://inlk.ai/2025/04/15/predictive-intelligence-in-servicenow-concepts-and-implementation/) — архитектура word corpus, поля similarity framework. [established]
- [ServiceNow Community — Identifying similar incidents by description/work notes](https://www.servicenow.com/community/itsm-forum/what-is-the-best-way-to-identify-a-similar-or-related-incident-s/m-p/565056) — практика кастомизации, нет OOB решения по work notes. [established]
- [ServiceNow Community — Guide to Incident Text Fields](https://www.servicenow.com/community/itsm-articles/guide-to-servicenow-incident-text-fields/ta-p/2316108) — семантика полей short_description, description, work notes. [established]
- [Zendesk — Enhanced similar ticket results (intents and entities)](https://support.zendesk.com/hc/en-us/articles/8948823362458-Announcing-enhanced-similar-ticket-results-boosted-by-intents-and-entities) — алгоритм similarity: subject + first comment + intent + entity + time decay. [established]
- [Zendesk — Automatically classifying intent](https://support.zendesk.com/hc/en-us/articles/4550640560538-Automatically-detecting-customer-intent-sentiment-and-language) — intent classification: subject + first public comment. [established]
- [BMC Helix ITSM Insights — Configuring incident correlation](https://docs.bmc.com/xwiki/bin/view/Service-Management/IT-Service-Management/BMC-Helix-ITSM-Insights/itsminsights262/Administering/Configuring-incident-correlation-to-detect-similar-incident-clusters/) — DistilBERT на description, структурные group-by fields. [established]
- [Moogsoft APEX AIOps — Similar Incidents Overview](https://docs.moogsoft.com/moogsoft-cloud/en/similar-incidents-overview.html) — Jaccard index по структурным fields; комментарии для human review, не в алгоритме. [established]
- [Atlassian JSM — Find similar work items](https://support.atlassian.com/jira-service-management-cloud/docs/what-are-similar-requests/) — summary-based native similarity. [established]
- [KCS v6 Practices Guide — The Solve Loop](https://library.serviceinnovation.org/KCS/KCS_v6/KCS_v6_Practices_Guide/030/030) — «search early, search often», composite context поиска. [established]
- [Springer — Automated Duplicate Bugs Detection: Do We Really Need All Bug Report Sections?](https://link.springer.com/chapter/10.1007/978-3-032-15538-2_46) — title f1=98.93%, description f1=98.29% для duplicate detection; steps/actual results = confusion. [established]
- [Springer — Impact of Textual Dissimilarities of Bug Report Sections](https://link.springer.com/chapter/10.1007/978-981-96-7423-7_18) — section-level analysis duplicate detection performance. [established]
- [OpenSearch — Introducing RRF for hybrid search](https://opensearch.org/blog/introducing-reciprocal-rank-fusion-hybrid-search/) — RRF как zero-shot rank fusion без нормализации. [established]

**[secondary] — пересказы и обзоры:**

- [Atlassian — What is KCS](https://www.atlassian.com/itsm/knowledge-management/kcs) — обзор KCS methodology. [established]
- [Combining Retrieval and Classification for Duplicate Bug Detection (arXiv 2404.14877)](https://arxiv.org/html/2404.14877v1) — post-submission comments improve detection for incomplete descriptions. [emerging]
- [AIOps Solutions for Incident Management — Literature Review (arXiv 2404.01363)](https://arxiv.org/html/2404.01363v1) — incident deduplication как AIOps phase; концептуально, без конкретных field-specs. [established]
- [IT Process Wiki — Problem Management](https://wiki.en.it-processmaps.com/index.php/Problem_Management) — ITIL 4 incident matching through Problem Management practice. [established]
