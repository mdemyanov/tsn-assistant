# Промт для BA-002 — пересмотр и расширение бизнес-кейсов pg_vector_service

> Запускать через `/ba BA-002 ...` или передавать как payload в Agent с
> subagent_type=`project:ba-agent`. Сессия — **новая**. Контекст волн research
> (RES-009.1/2) уже зафиксирован в `content/10-domain/research/`.

---

```
/ba BA-002 — пересмотр и расширение каталога use-case'ов с явным разделением
"эмбединги атрибутов" vs "эмбединги комментариев" + новые поисковые сценарии +
preprocessing-политика (plain text vs markdown)

КОНТЕКСТ
Текущие требования (UC1-3 в content/30-requirements/functional/) написаны до
RES-009.1/2 на верхнеуровневом понимании. Волны research показали:

  - issue.composite_extended (subject + description + decisionReport + ...) —
    p95 = 209 токенов, single-vector работает
  - comment.text individual — p95 = 2 432 токена, 7 % > 2 048 → один комментарий
    уже может не лезть в эмбединг → комментарий это самостоятельный payload
  - KB.content (HTML) — p95 = 26 014 токенов, 47,8 % > 2 048 → chunking обязателен
  - comments_per_issue: median 3, p95 15, max 8 248 — поиск "по комментариям"
    масштабно отличается от поиска "по описанию"

owner поднял два важных артикуляционных вопроса:

  1. У нас не один UC1 "vectorization", а два разных кейса:
     - эмбединги для атрибутов объекта (то, что писалось как UC1)
     - эмбединги для комментариев объекта (новый payload-класс)
     Это влияет на API-контракт: у каждого свой жизненный цикл (события "новый
     комментарий" vs "изменён атрибут"), своя политика хранения, свой ACL.

  2. У нас не один UC2 "similarity search", а минимум три варианта:
     - найти похожие заявки (issue → issue, по composite-вектору)
     - найти заявки с похожими комментариями (issue → issue, по comment-векторам)
     - найти похожий вопрос (FAQ-класс — отдельный объектный класс с короткими
       вопросами, например частыми; query → faq.question)

  3. Кластеризация (текущий UC3) тоже распадается:
     - похожие заявки по описанию (как сейчас)
     - похожие заявки по описанию + комментариям (combined-signal)

  4. Preprocessing-политика: текст идёт в эмбединг "как есть" или после
     конвертации? Кандидаты: plain text (strip HTML/RTF), markdown
     (HTML→markdown через flexmark / similar). Markdown сохраняет семантику
     заголовков и списков, но раздувает токены. Это влияет на:
       - длину payload (markdown vs plain — разница на 5-15 %)
       - whitelist-аудит (markdown оставляет URL'ы и emoji, plain — только текст)
       - детерминированность hash для re-vectorize

ВАЖНО — SCOPE МОДУЛЯ pg_vector_service
Модуль отвечает ТОЛЬКО за: создание структуры векторных таблиц, векторизацию
текстов от caller'а, поиск похожих, кластеризацию. Триггеры запуска и отбор
контента (когда вызвать, что вложить в payload, какие комментарии включать) —
out of scope модуля. Модуль предоставляет API; решение когда и что вызвать —
на стороне caller'а (SMP-сценарий, scheduled job, MCP-tool).

Это значит: BRQ описывает business intent (что хочет achieve user/role), но
архитектурно различает два уровня:
  - Внутренний контракт модуля: vectorize(text, kind, ownerRef) → vectorId
  - Внешний use case: оператор хочет "найти похожие заявки" — это композиция
    модульного API + SMP-обвязки (который НЕ в scope модуля, но В scope BRQ
    как контекст потребления).

═══════════════════════════════════════════════════════════════
ЗАДАЧИ ВОЛНЫ
═══════════════════════════════════════════════════════════════

§1. Каталог use-case'ов — пересмотр

Сформировать единый каталог UC по двум осям:
  - Vectorization (наполнение): UC-V1, UC-V2, ...
  - Search & cluster (потребление): UC-S1, UC-S2, ..., UC-C1, ...

Целевой набор (минимум; BA может расширить):

VECTORIZATION
  UC-V1. Векторизация атрибутов объекта (issue / problem / kb / faq)
    Trigger: создан/изменён объект (или по расписанию для bulk-init)
    Payload: composite text из whitelist'а атрибутов
    Артефакт хранения: 1 вектор на объект (или N чанков для длинных KB —
                       стратегия C из RES-009.2)

  UC-V2. Векторизация комментариев объекта
    Trigger: создан/изменён комментарий (или по расписанию для bulk-init)
    Payload: текст комментария (markdown или plain — см. §3)
    Артефакт хранения: 1 вектор на комментарий (или N чанков для p95+ — 7 %
                       комментариев > 2 048 токенов)
    ACL: наследуется от объекта-родителя (issue/problem); KB-комментарии
         наследуют kbAccesses

SEARCH
  UC-S1. Найти похожие заявки по описанию
    Query: object_id → composite-вектор → top-K issue
    Cross-class опционально: issue → kb-article (для подсказки решений)

  UC-S2. Найти заявки с похожими комментариями
    Query: текст или comment_id → top-K comment-векторов → GROUP BY
           issue_id → top-N issues
    Use case: оператор видит проблемный комментарий ("снова та же ошибка
              после ребута") → находит других пользователей с такой же
              ситуацией в треде

  UC-S3. Найти похожий вопрос (FAQ-сценарий)
    Контекст: создаётся отдельный SMP-класс faq$question (или используется
             knowledgeBase$article с признаком type=question) — короткие
             "частые вопросы" с эталонным ответом
    Query: текст пользователя → top-K faq.question → возврат связанного
           ответа
    Use case: self-service портал, чат-бот, suggested-answer для оператора

  UC-S4. Найти похожие KB-статьи (как UC2 текущий, без изменений по semantics)

CLUSTER
  UC-C1. Кластеризация заявок по описанию (текущий UC3)
    Signal: только composite-вектор issue
    Output: группы near-duplicates с threshold

  UC-C2. Кластеризация заявок по описанию + комментариям (combined signal)
    Signal: composite-вектор issue + агрегат по comment-векторам (max или
           mean — см. OQ-CL-1)
    Output: группы issue с учётом эволюции в треде; "две заявки с разной
           постановкой, но одинаковым обнаруженным root cause в комментах"
           попадают в один кластер

§1 итог:
  - Таблица UC × роль × trigger × payload × ACL × storage strategy (A/C из
    RES-009.2) × приоритет в PoC
  - Маппинг с текущими UC1-3 файлами: какие переименовать, какие split'ить,
    какие новые

§2. JTBD + AC для каждого UC из §1

Формат — как в существующих uc1/2/3.md:
  - Frontmatter (order, Тип контента: Требование, Фаза: PoC, Статус: Draft)
  - JTBD per role (минимум 1, до 3 ролей)
  - Описание (что модуль делает, что не делает)
  - Acceptance Criteria (Given-When-Then, нумерованные AC-N)
  - Связь с NFR (latency, throughput, ACL)
  - Open Questions (если что-то deferred на /sa или Pilot)

Особенный фокус на новых UC:
  - UC-V2 (vectorize comments) — новый, AC должны явно покрыть:
    a. наследование ACL от объекта-родителя
    b. поведение при удалении комментария (удалить вектор)
    c. поведение при редактировании комментария (re-vectorize по hash)
    d. что делать с system-комментариями (status changed by ...) — фильтр
       по comment.source.metaClass

  - UC-S2 (search by comments) — новый, AC должны покрыть:
    a. дедупликация: если 5 комментариев одной заявки матчат — заявка
       возвращается 1 раз
    b. ranking: max-similarity vs sum-similarity per issue (OQ-S2-1)
    c. ACL: filter по обзору заявки, не по обзору комментария

  - UC-S3 (FAQ) — новый, AC должны покрыть:
    a. что считается "вопросом" — отдельный класс или признак type=
       (owner-decision, BA фиксирует pros/cons)
    b. короткий запрос (10-50 слов) — какая модель эмбеддинга оптимальна
       (text-search-query, не -doc)
    c. порог релевантности (cutoff threshold) — ниже которого "не показывать"

  - UC-C2 (cluster by combined signal) — новый, AC должны покрыть:
    a. вес issue-вектора vs comment-агрегата (50/50, 70/30, learnable?)
    b. что делать с заявками без комментариев — fallback на UC-C1

§3. Preprocessing-политика (plain text vs markdown)

Owner поднял вопрос: что подавать в эмбединг — plain text или markdown?

Действия BA:
  a. Сравнить trade-off на 3 dimensions:
     - Семантическое качество эмбеддинга (markdown сохраняет структуру —
       headers, lists, code blocks; plain — теряет)
     - Стоимость токенов (markdown 5-15 % дороже на тех же текстах)
     - Whitelist-аудит / PII (markdown оставляет URL'ы, ссылки, emoji —
       plain очищает)

  b. Сценарии-кандидаты:
     - Все payload'ы → plain text (KISS)
     - Все payload'ы → markdown (семантика)
     - Mixed: KB.content → markdown (где структура важна), issue.* и
       comments → plain text (где структура минимальна)

  c. Литобзор: что делают LangChain / LlamaIndex / LangChain TextSplitter —
     обычно держат markdown для KB и plain для коротких текстов

  d. Рекомендация для PoC: предложить ОДИН подход (с обоснованием) +
     помеченное deferred решение, что пересмотр после offline-eval (DEV-033)

  e. Фиксация в виде:
     - Новый раздел в content/30-requirements/non-functional/
       nfr-preprocessing.md (или дополнить nfr-cross-cutting.md) с:
       - правилами нормализации (HTML→???, RTF→???, plain copy?)
       - инвариантами (детерминированность, idempotency)
       - связь с composite_hash (preprocessing_version в hash)

  f. Связать с UC-V1/UC-V2: AC должен явно ссылаться "preprocessing
     по nfr-preprocessing.md, версия N"

§4. Реестр payload'ов (обновление RES-009.1 §2)

В §2 RES-009.1 уже есть реестр FQN для issue/problem/kb. Расширить:
  - Добавить FAQ-класс (если решено — отдельный класс) или признак
    `type=question` на KB
  - Добавить FQN'ы атрибутов комментариев: `*$comment.text`,
    `*$comment.author`, `*$comment.created` — для UC-V2
  - Зафиксировать source-фильтрацию: какие comment.source.metaClass
    включать, какие фильтровать (например, system-комментарии "статус
    изменён" — вероятно out)

§5. Whitelist по UC

Текущий PoC-whitelist (subject + cancelReason) — критически узкий
(median 22 токена, см. §12 RES-009.2). Per-UC расширение:

  - UC-V1 (issue): subject + description + decisionReport + feedback
  - UC-V1 (kb): name + content (после HTML-нормализации)
  - UC-V1 (problem): subject + description + decisionReport
  - UC-V1 (faq): question + answer (или только question?)
  - UC-V2 (comments): text (с фильтром по source.metaClass: только
    user-comments, не system)

Эскалация: для каждого атрибута явно:
  - PII-классификация (low / medium / high)
  - кто из стейкхолдеров sign-off'ит
  - дедлайн sign-off'a (для медиум-PII — не позже PoC iter 1)

§6. NFR — что меняется

Существующий nfr-cross-cutting.md написан до волн research. Пересмотр:
  - NFR-001 (latency p95 ≤ 500 ms) — валидируется ли для UC-S2 (поиск по
    комментариям с GROUP BY)? Если нет — отдельный NFR-001b с большим
    бюджетом.
  - NFR по ACL: явное правило "ACL комментария наследуется от объекта-
    родителя" + "ACL FAQ через kbAccesses (или собственный механизм)"
  - NFR по preprocessing: версия алгоритма в hash (см. §3)
  - NFR по детерминированности (поднял RES-009.2 OQ-6) — подтянуть в
    nfr-cross-cutting

§7. Открытые вопросы для /sa (волна 3 research) и owner-decision

Сформулировать (НЕ решать):
  - OQ-FAQ: класс faq отдельный или признак type на kb?
  - OQ-CL-1: вес issue vs comment в combined cluster signal?
  - OQ-S2-1: ranking aggregation для UC-S2 (max/sum/RRF)?
  - OQ-PRE-1: финальное решение по preprocessing (после offline-eval)
  - OQ-COMMENT-DELETE: каскадное удаление вектора при удалении комментария —
    кто инициатор (SMP-trigger или scheduled GC по orphan-vectors)?
  - OQ-COMMENT-EDIT: re-vectorize по hash или по событию update?
  - OQ-PROBLEM-DATA: текущая невалидируемость problem на llm2 (3 объекта)
    — продолжаем считать problem за first-class UC или DEFER до Pilot?

═══════════════════════════════════════════════════════════════
ВХОДЫ
═══════════════════════════════════════════════════════════════

- content/30-requirements/functional/uc1-scheduled-vectorization.md (текущий)
- content/30-requirements/functional/uc2-similarity-search.md (текущий)
- content/30-requirements/functional/uc3-duplicate-detection.md (текущий)
- content/30-requirements/non-functional/nfr-cross-cutting.md (текущий)
- content/10-domain/research/vector-storage-domain.md (волна 1, Approved)
- content/10-domain/research/vector-storage-strategies.md (волна 2, Draft)
- content/10-domain/research/raw/length-distribution.csv (цифры llm2)
- content/10-domain/research/smp-metamodel.md (FQN-реестр)
- content/10-domain/research/yc-foundation-models.md (text-search-doc vs -query)
- ctx7 / web-search для §3 (markdown vs plain в RAG-туториалах)
- Owner — для §3 (выбор preprocessing) и §7 (FAQ-класс)

═══════════════════════════════════════════════════════════════
ОГРАНИЧЕНИЯ
═══════════════════════════════════════════════════════════════

- НЕ писать ADR — это работа /sa
- НЕ принимать решение по архитектурным вопросам §7 — формулировать
  pros/cons и помечать как owner/SA-decision
- НЕ переписывать существующие uc1-3 в null — split / extend / rename, но
  сохранить traceability (старый AC-N → новый UC-V1.AC-N)
- НЕ выбирать модель эмбеддинга — она уже в ADR-010
- НЕ описывать SMP-обвязку (scheduled job, MCP-tool, REST-API SMP) —
  это в scope SA, BA только указывает trigger как business-event

═══════════════════════════════════════════════════════════════
КРИТЕРИИ ПРИЁМКИ
═══════════════════════════════════════════════════════════════

- §1 — единый каталог UC × роль × trigger × payload × ACL × storage в
  виде матрицы; маппинг старые UC1-3 → новые UC-V*/UC-S*/UC-C*
- §2 — для каждого нового UC файл в content/30-requirements/functional/
  с frontmatter, JTBD, описанием, AC (Given-When-Then), NFR-связями, OQ
- §3 — раздел про preprocessing с pros/cons + рекомендация для PoC
- §4 — обновлённый реестр payload'ов (или ссылка на обновление в
  RES-009.1)
- §5 — whitelist по UC с PII-классификацией и эскалацией
- §6 — diff с текущим nfr-cross-cutting.md (что добавлено, что изменено)
- §7 — список OQ для /sa и owner-decision
- Все ссылки между UC и NFR — рабочие (cross-каталожные через inline code)
- Никакого PII клиентов; внутренние контакты Naumen — допустимы
- Перед закрытием — superpowers:verification-before-completion

═══════════════════════════════════════════════════════════════
АРТЕФАКТЫ
═══════════════════════════════════════════════════════════════

Создать:
  - content/30-requirements/functional/uc-v1-vectorize-attributes.md
  - content/30-requirements/functional/uc-v2-vectorize-comments.md (новый)
  - content/30-requirements/functional/uc-s1-find-similar-issues.md
  - content/30-requirements/functional/uc-s2-find-similar-by-comments.md (новый)
  - content/30-requirements/functional/uc-s3-find-similar-faq.md (новый)
  - content/30-requirements/functional/uc-s4-find-similar-kb.md
  - content/30-requirements/functional/uc-c1-cluster-by-description.md
  - content/30-requirements/functional/uc-c2-cluster-by-description-comments.md (новый)
  - content/30-requirements/non-functional/nfr-preprocessing.md (новый)

Обновить (или пометить deprecated с supersede-ссылками):
  - content/30-requirements/functional/uc1-scheduled-vectorization.md → split
  - content/30-requirements/functional/uc2-similarity-search.md → split
  - content/30-requirements/functional/uc3-duplicate-detection.md → split
  - content/30-requirements/non-functional/nfr-cross-cutting.md → diff
  - content/30-requirements/README.md → новая структура каталога

═══════════════════════════════════════════════════════════════
ПРОЦЕДУРА (рекомендуемая последовательность)
═══════════════════════════════════════════════════════════════

1. Прочитать текущие uc1-3.md + nfr-cross-cutting.md + RES-009.1/2 →
   внутренняя калибровка
2. §1 каталог UC — таблица + маппинг старое→новое
3. §3 preprocessing — литобзор через ctx7 → рекомендация
4. §4-5 — payload-реестр и whitelist-эскалация (на цифрах волны 1)
5. §2 — писать UC-файлы в порядке: V1 → V2 → S1 → S2 → S3 → S4 → C1 → C2
6. §6 — diff с текущим NFR
7. §7 — собрать список OQ
8. superpowers:verification-before-completion перед закрытием

═══════════════════════════════════════════════════════════════
NEXT
═══════════════════════════════════════════════════════════════

После закрытия BA-002 → user-review → /sa волна 3 (RES-009.3 + ADR-011/012):
финальный API-контракт модуля, DDL с HNSW-параметрами, поэтапная
рекомендация PoC iter 1→4, реестр изменений в ADR-001..010.
```
