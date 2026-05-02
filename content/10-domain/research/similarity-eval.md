---
order: 5
title: "Оценка качества similarity-поиска: метрики и ground truth"
properties:
  - Тип контента: Исследование
  - Фаза: PoC
  - Статус: Draft
---

# Оценка качества similarity-поиска: метрики и ground truth

> Источники сверены **2026-05-01**. Скоуп — use case 2 (top-K similarity
> по issue / KB / problem). Кластеризация дублей (UC3) рассматривается в
> [`research/clustering.md`](clustering.md) (RES-006) и здесь не дублируется.
> Артефакт готовит вход для SA: набор метрик и пороговых значений, на основе
> которых формулируются AC use case 2.

## 1. Резюме

- Базовый набор метрик для PoC: **Recall@10, MRR@10, nDCG@10** + latency
  **p50 / p95 / p99** на single-connection. Recall — приоритетный (важно
  «найти», порядок вторичен на этапе PoC); MRR/nDCG — для подстройки
  ранжирования.
- Ground truth собираем **без ручной разметки** из трёх SMP-сигналов:
  `issue.duplicates` / `duplicatesRL` (явные дубли от операторов),
  `problem.issues` (заявки-симптомы одной проблемы),
  `slmService` (cross-domain якорь между issue и KB).
- Стратегия PoC — **offline-evaluation на снапшоте** одного тенанта.
  Online A/B и shadow-mode откладываем до Pilot (после ADR на индекс и модель).
- Пороги для go/no-go PoC (предложение Researcher; финальные числа
  фиксирует SA в AC): **Recall@10 ≥ 0.80**, **MRR@10 ≥ 0.50**,
  **p95 latency ≤ 200 ms** на 100k объектов с `ef_search=40`.

## 2. Метрики качества top-K

Все метрики оцениваются на тестовом множестве запросов `Q`; для каждого `q ∈ Q`
известно множество релевантных объектов `R(q)` (см. §4 Ground truth) и список
из top-K выдач системы `S_K(q)`.

### 2.1. Precision@K — точность

`Precision@K = |S_K ∩ R| / K`.

Доля релевантных среди K выданных. **Не учитывает порядок**, не учитывает,
сколько всего релевантных в корпусе. Чувствительна к шуму в выдаче.
В semantic search применяется реже, чем Recall@K, потому что для редких
запросов `K > |R|`, и precision механически ограничен сверху.

### 2.2. Recall@K — полнота

`Recall@K = |S_K ∩ R| / |R|`.

Доля релевантных, которую удалось вернуть в top-K, от всех релевантных
в корпусе. **Главная метрика ANN-поиска**: показывает, насколько индекс
аппроксимирует exact-search. На бенчмарках pgvector / Qdrant / Weaviate
recall — ось X, latency — ось Y (`Pareto-плот`).

Чувствительна к выбору `K` и к полноте ground truth: если разметка
неполная (а у нас именно так — `duplicates` ставят не на все пары),
recall занижен; читать как **lower bound**.

Типичные production-ориентиры (внешние бенчмарки, не наш кейс):
на 1M векторов «все основные БД достигают **95%+ recall** с настройками
по умолчанию» ([CallSphere 2026](https://callsphere.ai/blog/vector-databases-pinecone-weaviate-qdrant-comparison)).
Это recall ANN vs exact, не recall vs human relevance — путать нельзя.

### 2.3. MRR@K — средний обратный ранг

`MRR@K = (1/|Q|) · Σ_q (1 / rank_q)`,

где `rank_q` — позиция **первого** релевантного в `S_K(q)` (если такого нет,
вклад = 0). Диапазон [0; 1]. Удобна, когда пользователю важен «первый
правильный ответ» (типичный сценарий «найти похожие на эту заявку — открой
самый похожий»). **Не учитывает остальные релевантные**: если первый ответ
на ранге 1 — MRR=1.0, даже если остальные 9 пунктов мусор.

### 2.4. nDCG@K — нормализованный DCG

`DCG@K = Σ_{i=1..K} rel_i / log₂(i+1)`, `nDCG@K = DCG@K / IDCG@K`.

Учитывает **градированную релевантность** (например: 2 — точный дубль,
1 — похожая заявка по той же услуге, 0 — нерелевантна) и логарифмически
штрафует низкие позиции. Стандарт BEIR ([beir-cellar/beir](https://github.com/beir-cellar/beir),
[arxiv 2104.08663](https://arxiv.org/abs/2104.08663)) — `nDCG@10`. Чувствительна
к качеству градации: если ground truth бинарный (как у нас на старте), nDCG
вырождается в близкое к MAP, и брать его поверх MRR избыточно.

### 2.5. Что выбираем для PoC

| Метрика | Берём? | Зачем |
|---|---|---|
| Recall@10 | ✅ primary | Можем мы вообще найти известный дубль/связку? |
| MRR@10 | ✅ primary | Достаточно ли «первая выдача = правильная»? |
| nDCG@10 | ⚠️ secondary | Включаем, когда появятся градации релевантности (Pilot, ручная разметка) |
| Precision@10 | ⚠️ secondary | Полезно для отчёта о «шуме» в top-10 |
| MAP | ❌ | Дублирует nDCG при бинарной разметке |

Поправка про RAG-смещение: классические IR-метрики (nDCG/MRR/MAP)
**не всегда коррелируют с end-to-end качеством downstream-задачи**
([Salemi & Zamani 2024, eRAG](https://arxiv.org/html/2510.21440v1)). Для нас
это означает: метрики §2.1–2.4 — **proxy**, финальная валидация — на бизнес-сценарии
оператора (см. §5 Стратегия evaluation, online-этап).

## 3. Latency и пропускная способность

### 3.1. Перцентили

- **p50 (медиана)** — ощущение «обычной скорости». Полезна для capacity-planning,
  но скрывает хвост.
- **p95** — рабочий потолок UX: 1 из 20 запросов медленнее. Стандарт большинства
  SLO для интерактивных API.
- **p99** — **главная метрика для UI-сценария** «оператор открыл карточку → блок
  similar issues». Внешний бенчмарк формулирует так: «система с 10 ms median
  и 500 ms p99 ощущается медленнее, чем 20 ms median и 50 ms p99»
  ([Tigerdata pgvector vs Qdrant](https://www.tigerdata.com/blog/pgvector-vs-qdrant)).

### 3.2. Методология замера

Минимум, который должен быть в любом отчёте latency:

1. **Warm-up**: ≥ 1000 запросов до фиксации перцентилей (HNSW кэширует страницы
   в shared_buffers; первый прогон не репрезентативен).
2. **Single-connection** + отдельный замер с **concurrent connections** (наш
   реальный сценарий — параллельные операторы; ANN-Benchmarks по умолчанию
   single-connection, AWS-блоги тоже,
   [AWS pgvector 0.8.0](https://aws.amazon.com/blogs/database/supercharging-vector-search-performance-and-relevance-with-pgvector-0-8-0-on-amazon-aurora-postgresql/)).
3. **Изоляция нагрузки**: на стенде `llm2` других тяжёлых джоб во время замера
   быть не должно (договариваемся с DevOps; см. open question Q3).
4. **Диапазон recall**: одно число latency без recall — мусор. Стандарт —
   таблица «recall vs p50/p95/p99» (по образцу
   [Tigerdata](https://www.tigerdata.com/blog/pgvector-vs-qdrant): Qdrant
   90% recall — `4.74 / 5.50 / 5.79 ms`; Postgres — `9.54 / 13.30 / 15.73 ms`
   на 50M × 768 dim. Наши абсолютные числа будут отличаться — берём только методологию).
5. **N запросов на перцентиль**: для p99 минимум 1000 запросов (устойчивая оценка),
   для p95 — 200+.
6. **QPS отдельно**: throughput замеряется при насыщении пула соединений,
   не одновременно с latency single-connection.

### 3.3. Предварительные ориентиры PoC

На 100k векторов с HNSW (`m=16, ef_construction=64, ef_search=40`,
[research/pgvector-indexes.md §3.1](pgvector-indexes.md)):
- ожидаемый p95 ≤ 50 ms на single-connection (внешние бенчи показывают
  единицы-десятки ms на сравнимых dimensionality);
- цель PoC — **p95 ≤ 200 ms на end-to-end SMP API** (включая HQL → JDBC → pgvector → JSON).
  Запас 4× учитывает overhead SMP-слоя; уточняем после первого smoke
  на `llm2`.

## 4. Ground truth — сбор без ручной разметки

Источник | Что есть | Плюсы | Минусы | Покрытие |
---|---|---|---|---
`issue.duplicates` / `duplicatesRL` (см. [smp-metamodel.md §issue](smp-metamodel.md)) | Пары заявок, помеченных оператором как дубль | Высокая precision: оператор подтвердил | Полнота низкая (помечают не всегда), bias на «громкие» дубли | ~ единицы % issue (требует подтверждения, см. open question Q1) |
`problem.issues` | Связь N заявок → 1 проблема (N≥2) | Семантически сильный сигнал «один корень» | Связь slabее «дубля»: заявки про одну проблему могут отличаться формулировкой; могут быть исторические рудименты | Зависит от тенанта; на ITSM-инсталляциях — десятки % инцидентов |
`slmService` (общая услуга) | issue ↔ KB, issue ↔ issue по `slmService` | Доступно для cross-domain (заявка ↔ статья KB) | Слабый сигнал: «по той же услуге» ≠ «похожие». Только как **soft label** (relevance grade 1, не 2) | 100% (атрибут required у issue) |
`problems.assets` / общие активы | Сужает «по тому же CI» | Доп. сигнал для технических инцидентов | Не у всех тенантов CMDB заполнена | Опционально |

### 4.1. Рекомендованная схема

Многоуровневая разметка (соответствует §2.4 nDCG-готова):

- **rel = 2 (strong positive)**: `(a, b) ∈ duplicates` ∨ оба входят в один `problem`.
- **rel = 1 (weak positive)**: общий `slmService` **И** косинус-similarity
  ≥ θ_low (используется только для оценки nDCG, не для recall — иначе циркулярно).
- **rel = 0**: всё остальное.

Test set: для каждого `q` (issue) релевантные = объекты с `rel ≥ 1`.
Для recall@k берём только `rel = 2` (избегаем циркулярности).

### 4.2. Размер и стратификация

- ≥ 200 запросов в test set (минимум для устойчивого MRR/Recall@10).
- Стратификация по подклассам issue (incident / serviceCall / request — см.
  [smp-metamodel.md](smp-metamodel.md)) и по длине текста описания (короткие
  заявки часто ломают эмбеддинги).
- Языковая стратификация: ru-only на старте (см. open question Q4).
- **Hold-out** по времени: train/eval-split не случайный, а **по дате создания**
  (test = последний месяц), чтобы поймать distribution shift.

## 5. Стратегия evaluation

| Этап | Метод | Что валидирует | Когда |
|---|---|---|---|
| PoC | **Offline на снапшоте** | Принципиальная работоспособность стека (модель + индекс + SMP API) | После RES-001..008, до `/dev` |
| MVP | Offline + **shadow-mode** на проде | Поведение на реальном трафике без риска UX | После Pilot-tenanta |
| Pilot | + ручная разметка top-10 для 50–100 запросов | Качество, которое не ловит автоматический ground truth | Перед prod-rollout |
| Prod | + **online A/B** (CTR на «похожие», time-to-resolution) | Бизнес-метрики | После Pilot |

Для PoC выбираем **только offline на снапшоте одного тенанта**:
- shadow-mode требует прод-трафика (нет на этапе PoC);
- A/B требует продуктового UI, которого в JAR-модуле нет;
- ручная разметка в PoC — too expensive, откладываем.

Ссылки на best-practice: BEIR ([beir-cellar/beir](https://github.com/beir-cellar/beir))
как формат хранения test-набора (`corpus.jsonl`, `queries.jsonl`,
`qrels.tsv`); apxml online vs offline
([apxml.com](https://apxml.com/courses/advanced-vector-search-llms/chapter-5-advanced-tuning-evaluation/online-offline-evaluation));
shadow tests AWS SageMaker
([docs.aws.amazon.com](https://docs.aws.amazon.com/sagemaker/latest/dg/shadow-tests.html))
как референс архитектуры shadow-стенда (для MVP, не для PoC).

## 6. Типичные ошибки

1. **Train/test contamination.** Модель эмбеддингов — внешняя (Yandex FM),
   но если в test-set попадают сами `(q, q)` пары или объекты, использованные
   для подбора порога — recall искусственно высокий. Mitigation: хранить
   `query_id ≠ doc_id` и `created_at(q) > created_at(d)` (имитация прода).
2. **Recall ANN vs Recall human.** Не путать: «recall=0.95 vs exact-search»
   (метрика индекса) и «recall=0.95 vs ground truth» (метрика релевантности).
   Первая — sanity-check pgvector, вторая — наша целевая.
3. **Один K без обоснования.** K=10 для UC2 (UI оператора покажет 10), K=100
   для UC3 (кластеризация). Считать K=10, **смотреть** K=100, чтобы понять,
   уезжают ли релевантные дальше top-10.
4. **Distribution shift игнорируется.** Случайный train/test даёт
   оптимистичный bias. Использовать time-split (см. §4.2).
5. **Смешивание языков.** Если в test попадают en-/ru-заявки в одну корзину —
   эмбеддинги Yandex FM могут давать разную геометрию; считать метрики
   отдельно per-language.
6. **Игнорирование редких классов.** Среднее по 200 запросам прячет провалы
   на подклассе `incident` vs `serviceCall`. Репортить **per-stratum**.
7. **Latency без recall.** «p95 = 30 ms» бессмысленно без указания
   `ef_search` / `probes` и достигнутого recall.
8. **Cold cache.** Замер сразу после restart Postgres даёт нерепрезентативные
   p99. Warm-up обязателен (§3.2).
9. **Тестирование на одном тенанте.** PoC — да, но в Pilot нужны минимум 2
   тенанта с разной структурой данных (open question Q5).
10. **Использование eRAG-style downstream-метрик в PoC.** Соблазн «померить
    качество саммаризации/RAG поверх retrieval» — преждевременно: у нас нет
    LLM-задачи в UC2, оценка делается на самом ranking-слое.
    ([Redefining Retrieval Eval, arxiv 2510.21440](https://arxiv.org/html/2510.21440v1)).

## 7. Open questions

| ID | Вопрос | Кому |
|---|---|---|
| Q1 | Какова реальная плотность `issue.duplicates` на стенде `llm2` (доля заявок с непустым `duplicatesRL`)? Достаточно ли для test-set ≥ 200 пар? | BA + Researcher (RES-001 follow-up через MCP `naumen-smp-dev-admin`: `issue_query_stats` по `duplicatesRL is not null`) |
| Q2 | Использовать ли `problem.issues` как **strong** (`rel=2`) или **weak** (`rel=1`)? Зависит от того, насколько в проде заявки в одной проблеме семантически близки | BA + домен (Сазонова) |
| Q3 | Можно ли получить **изолированное окно** на `llm2` для latency-замеров (нет фоновых джоб, конкурентных запросов)? | DevOps + Сахабетдинов |
| Q4 | Состав языков в корпусе issue/KB — только ru или встречается en? Влияет на стратификацию метрик | BA через MCP (sample 1000 issue, lang detect) |
| Q5 | Будут ли в PoC доступны ≥ 2 тенанта или только `llm2`? Влияет на план Pilot | PM + Демьянов |
| Q6 | Бинарная или градированная релевантность в PoC? Если бинарная — nDCG отбрасываем | SA (фиксируется в AC) |
| Q7 | Какой порог recall@10 считать «достаточным» для go-decision PoC? Researcher предлагает 0.80, нужна валидация SA | SA + Демьянов |
| Q8 | Включать ли cross-domain similarity (issue → KB) в метрики PoC или вынести в отдельный milestone? | BA + SA |
| Q9 | Где хранить test-set (BEIR-формат `qrels.tsv`)? В репо как фикстура или генерировать каждый раз из снапшота SMP? | SA |

## 8. Источники

- [Weaviate — Evaluation Metrics for Search and Recommendation](https://weaviate.io/blog/retrieval-evaluation-metrics) — формулы Precision/Recall/MRR/nDCG.
- [BEIR: Heterogeneous Benchmark (arxiv 2104.08663)](https://arxiv.org/abs/2104.08663) + [beir-cellar/beir](https://github.com/beir-cellar/beir) — стандарт `nDCG@10`, формат qrels.
- [Salemi & Zamani 2024, Redefining Retrieval Eval](https://arxiv.org/html/2510.21440v1) — расхождение IR-метрик и end-to-end качества (eRAG).
- [Tigerdata — pgvector vs Qdrant](https://www.tigerdata.com/blog/pgvector-vs-qdrant) — методология latency p50/p95/p99 на 50M × 768 dim.
- [AWS — Supercharging pgvector 0.8.0](https://aws.amazon.com/blogs/database/supercharging-vector-search-performance-and-relevance-with-pgvector-0-8-0-on-amazon-aurora-postgresql/) — методология ANN-Benchmarks (recall, build time, p99, QPS).
- [Pinecone — Offline Evaluation](https://www.pinecone.io/learn/offline-evaluation/) — формулы и интерпретация IR-метрик.
- [Pinecone vs Weaviate в проде (DZone)](https://dzone.com/articles/pinecone-vs-weaviate-the-trade-offs-you-only-disco) — drift recall в проде.
- [apxml — Online vs Offline Eval](https://apxml.com/courses/advanced-vector-search-llms/chapter-5-advanced-tuning-evaluation/online-offline-evaluation) — workflow offline → A/B.
- [AWS SageMaker Shadow Tests](https://docs.aws.amazon.com/sagemaker/latest/dg/shadow-tests.html) — референс архитектуры shadow-mode (для MVP).
- [CallSphere 2026 — Vector DB Comparison](https://callsphere.ai/blog/vector-databases-pinecone-weaviate-qdrant-comparison) — recall на 1M.
- Внутренние артефакты:
  [`research/smp-metamodel.md`](smp-metamodel.md) (атрибуты `duplicates`,
  `problem.issues`, `slmService`),
  [`research/pgvector-indexes.md`](pgvector-indexes.md) (выбранные параметры
  HNSW, на которых меряем latency).
