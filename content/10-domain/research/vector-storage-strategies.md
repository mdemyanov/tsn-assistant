---
order: 10
title: "RES-009.2 — Сравнение стратегий хранения векторов (волна 2)"
properties:
  - Тип контента: Исследование
  - Фаза: PoC
  - Статус: Draft
---

# RES-009.2 — Сравнение стратегий хранения векторов и закрытие 10 OQ

**Дата:** 2026-05-01
**Исследователь:** researcher-agent
**Запрос PM/BA:** Глубокое сравнение 5 стратегий хранения векторов (A-E) на 8 dimensions; закрытие 10 OQ из §4.4 RES-009.1 (волна 1); валидация рекомендации D (hybrid: issue/A + KB/C).
**Глубина:** deep (≤1 день) — критичное архитектурное решение, питает ADR-011/012 и DDL.

## TL;DR

Рекомендация волны 1 (стратегия D — hybrid) **подтверждена цифрами** и литобзором. Issue-объекты с `composite_extended` покрываются single-vector (A) на 99,6 %; KB-статьи требуют chunking (C), поскольку 47,8 % превышают 2 048 токенов. Для PoC DDL рекомендованы колонки `parent_id UUID NULLABLE`, `chunk_index SMALLINT DEFAULT 0`, `chunk_total SMALLINT DEFAULT 1`, `source_attr VARCHAR(64) NULLABLE`, `chunk_kind VARCHAR(16) DEFAULT 'object'` — они позволяют поддержать E (per-comment-vector) без миграции. Главная эскалация в BA: PoC-whitelist (median 22 токена composite) **не даст реального качества** UC2/UC3 — sign-off на medium-PII атрибуты нужен до PoC iter 1, а не после. Лимит токенов YC FM `text-search-doc` — не верифицирован (smoke §9 ожидает owner'а). Стенд `problem` на llm2 содержит 3 объекта — валидация невозможна.

---

## §1 — Сравнительная матрица стратегий A-E × 8 dimensions

### Определения стратегий

| Стратегия | Описание |
|---|---|
| **A** | Single-vector: один объект = один composite text = один embedding |
| **B** | Multi-vector by content-type: отдельный вектор на атрибут (`subject`, `description`, `decisionReport`); поиск через RRF / max-pool |
| **C** | Chunked + rollup: длинный текст → чанки с overlap; rollup (mean/max/first) при поиске |
| **D** | Hybrid: issue → A на `composite_extended`; KB → C; одна таблица с `chunk_index` |
| **E** | Per-related-vector: вектор на каждый связанный объект (комментарий); только DDL в PoC |

### Dimension 1 — Покрытие бизнес-кейсов (12 пересечений UC × класс)

| Стратегия | Оценка | Обоснование |
|---|---|---|
| **A** | Частичное | UC1 issue OK (99,6 %), UC1 KB провал (47,8 % статей > лимита), UC2 по issue OK, UC2 по KB — статьи без чанков теряют хвост контента, UC3 OK |
| **B** | Избыточное | Покрывает все UC, но ×N вызовов YC FM и не нужно при short composite; overhead без доказанного прироста quality |
| **C** | Полное для KB | Обязательно для KB (47,8 % > лимита). Для issue — применимо, но избыточно при composite_extended в 99,6 % в лимите |
| **D** | Полное (оптимум) | issue → A (single): 99,6 % в лимите; KB → C (chunked): 100 % покрытие; UC3 online использует A-эмбеддинг нового composite |
| **E** | Частичное + future | Caller не передаёт комментарии (out of scope модуля); UC1/UC2/UC3 работают на object-уровне; DDL под E не блокирует остальные UC |

### Dimension 2 — Совместимость с лимитом токенов YC FM

Текущий лимит `text-search-doc` — официально не задокументирован (CAPTCHA на aistudio.yandex.ru). Используемое допущение: **2 048 токенов** (conservative). Smoke с 3 000 токенов — ожидает owner'а (см. §9).

| Стратегия | Оценка | Обоснование на цифрах |
|---|---|---|
| **A** | Условная | `issue.composite_extended`: p95 = 209 ток. (99,6 % OK). KB.content: p95 = 26 014 ток. — **физически невозможно** без chunking. Если лимит = 8 000 (smoke позитивный) — KB ситуация улучшается, но 47,8 % статей всё равно > 8 000 токенов (max = 75 010) |
| **B** | Условная | Каждый атрибут vectorize отдельно → subject, cancelReason всегда в лимите. description/decisionReport — рискованно (decisionReport p95 = 404 ток. — OK; description p95 = 5 138 — не OK) |
| **C** | Полная | Чанкинг по определению решает проблему лимита. При chunk_size = 1 800 ток. с overlap 10 % → эффективный шаг = 1 620 ток. |
| **D** | Полная | issue/A = 99,6 %; KB/C = 100 % через чанкинг. 25 issue с `composite_extended` > лимита (0,4 %) — truncation по политике §10 |
| **E** | Полная | Каждый related-object vectorize отдельно; comment p95 = 2 432 ток. > 2 048 → 7 % комментариев также требуют chunking. DDL-only в PoC, не реализуем |

### Dimension 3 — YC FM cost при steady-state

Тариф: 0,0101 ₽ / 1 тыс. юнитов (yc-pricing.md). Допущение: 1 юнит ≈ 1 токен.

| Стратегия | Cost formula | Оценка для llm2 corpus |
|---|---|---|
| **A** | 1 вызов / объект × avg_tokens | issue: 6 223 × 62 (p50) / 1 000 × 0,0101 = **≈ 3,9 ₽** полная индексация |
| **B** | N_attrs вызовов / объект | При 3 атрибутах → × 3 ≈ 11,7 ₽ |
| **C** | avg_chunks_per_object × avg_chunk_tokens / 1 000 × 0,0101 | KB 113 ст.: при chunk_size 1 800 ток. и p50 = 1 836 ток. → медиана = 1 чанк, 47,8 % статей → 2+ чанков (см. §2 расчёт). Всего ≈ **0,22–0,27 ₽** первичная индексация KB |
| **D** | Issue-A cost + KB-C cost | ≈ 3,9 + 0,27 = **≈ 4,2 ₽** полная индексация стенда llm2. Steady-state: 1 новая заявка ≈ 0,0006 ₽; 1 KB-апдейт ≈ 0,01–0,05 ₽ (зависит от размера) |
| **E** | D + all comments | 31 844 комментариев × 2 432 ток. (p95) / 1 000 × 0,0101 ≈ 782 ₽ при максимальных хвостах. Не релевантно для PoC |

### Dimension 4 — Storage schema

| Стратегия | Таблицы / FK / индексы | Примечание |
|---|---|---|
| **A** | 1 таблица, PK = (object_id, meta_class, tenant_id), chunk_index = 0 default. 1 HNSW | Простейшая схема |
| **B** | 1 таблица + source_attr NOT NULL, PK расширен на source_attr. 1 HNSW или per-attr | Необходима группировка по source_attr в search query |
| **C** | 1 таблица, PK + chunk_index. parent_id = object_id для parent-roll. 1 HNSW | GROUP BY parent_id при поиске |
| **D** | 1 таблица, chunk_kind enum ('object', 'chunk', 'summary'), chunk_index. 1 HNSW | Одна таблица, разные chunk_kind для issue (object, chunk_index=0) и KB (chunk, summary) |
| **E** | 1 таблица + parent_id FK (object_id=parent для chunks, comment_id для related). chunk_kind='related'. 1 HNSW | DDL-расширение без миграции: parent_id уже добавлен в D |

**Рекомендуемая единая схема DDL (скелет — параметры HNSW волна 3):**

```sql
CREATE TABLE pg_vector_service__vectors (
    object_id          UUID         NOT NULL,
    meta_class         TEXT         NOT NULL,
    tenant_id          TEXT         NOT NULL,
    model_version      TEXT         NOT NULL,
    whitelist_version  INT          NOT NULL DEFAULT 1,
    embedding          vector(256)  NOT NULL,
    composite_hash     BYTEA        NOT NULL,
    vectorized_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    dirty              BOOLEAN      NOT NULL DEFAULT FALSE,
    -- chunk support (D + future E)
    chunk_index        SMALLINT     NOT NULL DEFAULT 0,
    chunk_total        SMALLINT     NOT NULL DEFAULT 1,
    parent_id          UUID         NULLABLE,   -- FK на object_id (chunks)
    source_attr        VARCHAR(64)  NULLABLE,   -- имя атрибута-источника (B, E)
    chunk_kind         VARCHAR(16)  NOT NULL DEFAULT 'object',  -- 'object'|'chunk'|'summary'|'related'
    PRIMARY KEY (object_id, meta_class, tenant_id, chunk_index)
);
-- HNSW параметры (m, ef_construction) — в волне 3 + ADR-011
-- CREATE INDEX ON pg_vector_service__vectors USING hnsw (embedding vector_cosine_ops);
```

### Dimension 5 — Search aggregation алгоритм + сложность

| Стратегия | Алгоритм | Round-trips | Post-processing |
|---|---|---|---|
| **A** | KNN по embedding, ORDER BY dist LIMIT K | 1 SQL | Нет |
| **B** | KNN per source_attr → GROUP BY object_id → RRF merge | N_attrs SQL | Merge в Java |
| **C** | KNN по чанкам (oversample K×factor) → GROUP BY parent_id → min(dist) → top-N | 1 SQL (CTE) | GROUP BY в SQL |
| **D** | Для issue: как A. Для KB: как C + ACL-filter (см. §5) | 1 SQL + 1 ACL-check | GROUP BY для KB |
| **E** | KNN по related → GROUP BY parent_object → max-sim → ACL | 2+ SQL | Merge в Java |

**Oversample factor для C/D-KB:** При медианном 1 чанке/статью oversample практически не нужен. При хвостовых статьях (p95 = 26 014 ток → ~14–16 чанков) и top-N=10: при K=50 чанков и uniform distribution вероятность попасть в top-10 distinct parents очень высока. Рекомендуемый starting factor = **3–5×** (oversample K = N × 5 = 50 для N=10 результатов).

### Dimension 6 — ACL-инвариант

| Стратегия | ACL для KB | ACL для issue/problem |
|---|---|---|
| **A** | Нет per-chunk: одна запись → один ACL-check по object_id | SMP-сессия — нет дополнительного фильтра |
| **B** | Аналогично A — per-object после группировки | SMP-сессия |
| **C** | ACL фильтрация ТОЛЬКО после GROUP BY parent_id (см. §5). ACL не применяется к чанкам — только к parent | SMP-сессия |
| **D** | KB: C-режим. issue: A-режим (SMP-сессия) | SMP-сессия |
| **E** | parent_id → object_id → ACL. Комментарии ACL унаследован от parent | SMP-сессия |

**Важно:** Per-chunk ACL не нужен и не должен применяться — фильтрация только по parent `object_id` через `kbAccesses`. Применять ACL до GROUP BY означало бы некорректно отфильтровать чанки статей с ограниченным доступом.

### Dimension 7 — NFR-001 latency p95 ≤ 500 ms

| Стратегия | Доп. round-trips | Оценка latency (на 113 KB + 6 223 issue на llm2) |
|---|---|---|
| **A** | 0 | Базовый KNN HNSW: ожидаемый p95 ≤ 20 ms на corpus 100k. Итого с SMP overhead ≤ 100–200 ms |
| **B** | N_attrs-1 | Каждый дополнительный SQL round-trip +10–30 ms. Для 3 attrs: +60–90 ms. Граница NFR-001 достижима |
| **C** | +1 (GROUP BY в CTE или приложении) | CTE в одном SQL: +5–15 ms overhead GROUP BY. Итого p95 ≤ 200–250 ms — NFR выполняется |
| **D** | 0 для issue, +0 для KB (CTE) | Оба в норме. Добавляется ACL-check (1 SMP API call) +20–50 ms. Итого ≤ 250–300 ms |
| **E** | +1 (join related → parent) | Аналогично C, + join overhead. Не реализуем в PoC |

### Dimension 8 — Сложность реализации в hexagonal layout

| Стратегия | Порты / адаптеры | Ядро | Общая оценка |
|---|---|---|---|
| **A** | VectorStoragePort: save(VectorRecord), searchKNN(query, K, filters) | CompositeTextComposer (ADR-006), WhitelistEnforcer (ADR-005), EmbeddingPort | Минимум. Все компоненты уже в ADR |
| **B** | VectorStoragePort + RRFMerger в core | WhitelistEnforcer + per-attr split | Умеренно. Нужен RRFMerger компонент |
| **C** | VectorStoragePort (bulk chunk save) + ChunkAggregator в core | TextChunker (новый), CompositeTextComposer | Умеренно. TextChunker — новый компонент с детерминизмом (§7) |
| **D** | VectorStoragePort (polymorphic) + ChunkAggregator (только для KB) | WhitelistEnforcer + TextChunker (KB only) + CompositeTextComposer | Умеренно+. Poly-dispatch по meta_class в VectorStorationPort impl |
| **E** | VectorStoragePort + RelatedObjectVectorizer port | Core не меняется (parent_id в DDL) | DDL-ready, code = 0 в PoC |

### Сводный вывод §1

**D (hybrid) — единственная разумная стратегия для PoC.** Закрывает все 12 UC-кейсов, вписывается в лимит токенов для 99,6 % issue и 100 % KB, даёт минимальный cost, обеспечивает NFR-001 при одном SQL round-trip (CTE). Сложность реализации — умеренная (poly-dispatch + TextChunker для KB only). DDL с колонками chunk_kind, chunk_index, parent_id позволяет добавить E без миграции.

---

## §2 — Search aggregation: детальный разбор + storage/cost KB при 3 опциях overlap

### 2.1 Алгоритм поиска с multi-chunk (стратегии C, D-KB)

**Sequence для UC2 на KB:**

1. `SELECT chunk_id, parent_id, embedding <=> :query_vec AS dist FROM vectors WHERE meta_class = 'knowledgeBase$article' AND tenant_id = :tid AND model_version = :mv AND chunk_kind IN ('chunk', 'summary') ORDER BY dist LIMIT :oversample_k`
2. В приложении или CTE: `GROUP BY parent_id → MIN(dist) per parent → top-N parents`
3. ACL-фильтр через SmpKbAccessChecker (BR-002 UC2): убираем parent_id с isPrivate=true, не разрешённые для текущего пользователя
4. Если после фильтра результатов < N — повторить с увеличенным oversample (или вернуть short result)

**Рекомендуемый SQL паттерн (CTE — один round-trip):**

```sql
WITH ranked_chunks AS (
    SELECT
        parent_id,
        MIN(embedding <=> CAST(:query_vec AS vector(256))) AS min_dist
    FROM pg_vector_service__vectors
    WHERE meta_class = 'knowledgeBase$article'
      AND tenant_id = :tenant_id
      AND model_version = :model_version
      AND chunk_kind IN ('chunk', 'summary')
    ORDER BY embedding <=> CAST(:query_vec AS vector(256))
    LIMIT :oversample_k        -- K × oversample_factor (рекомендовано 5×)
)
SELECT parent_id, min_dist
FROM ranked_chunks
GROUP BY parent_id
ORDER BY min_dist
LIMIT :n_results;
```

**Примечание:** HNSW-индекс используется при ORDER BY в исходном запросе (inner query). GROUP BY и LIMIT внешнего запроса — реляционные операции над небольшим набором (oversample_k ≤ 50). Overhead пренебрежимо мал.

### 2.2 Варианты rollup агрегации (закрывается в §3-OQ-1)

| Метод | SQL эквивалент | Сигнал |
|---|---|---|
| **max-similarity (min-dist)** | `MIN(dist) per parent` | Ищет наиболее похожий чанк — «точечный хит» |
| **mean-pool** | `AVG(dist) per parent` | Усредняет по всем найденным чанкам — «общий семантический центр» |
| **first-chunk** | `dist WHERE chunk_index = 0` | Для статей с TL;DR/резюме в начале |
| **max-of-top-K** | `MIN(dist) WHERE chunk_index IN top-K` | Аналог max-similarity, явный top-K |

**Рекомендация (обоснование в §3):** MAX-similarity (`MIN(dist) per parent`) как default для PoC. Это community-стандарт для parent-document-retrieval (LangChain, LlamaIndex). Offline-eval на ground truth `issue.duplicates` (DEV-033) подтвердит выбор.

### 2.3 RRF для стратегии B (multi-vector per attribute)

Формула RRF: `score(d) = Σ 1 / (k + rank_i(d))`, k = 60 по умолчанию.

Для B-стратегии merge 3 ranked lists (per `source_attr`):
1. Пошаговая векторизация `subject`, `decisionReport`, `cancelReason` → 3 KNN-запроса
2. Merge через RRF в Java: объединяем списки по `object_id`, считаем RRF-score
3. Возврат top-N по RRF-score

**Эмпирика RRF vs single-vector:** hybrid search (vector + BM25) с RRF улучшает retrieval precision с 62 % до 84 % (DEV Community). Для multi-attribute vector RRF — аналогичная логика, но без BM25. Для нашего кейса issue (3 атрибута) vs single composite_extended — экономия от RRF неочевидна: composite_extended уже объединяет сигналы трёх атрибутов в один embedding. B-стратегия оправдана только при необходимости per-attribute поиска (например, «найти похожие только по `decisionReport`»).

### 2.4 Расчёт storage / cost KB при 3 вариантах overlap

**Корпус KB llm2:** 113 статей с непустым content. Median = 6 428 chars / 1 836 ток. (при char/tok = 3.5). p95 = 91 049 chars / 26 014 ток. Chunk_size = 1 800 ток.

**Формула чанков на статью:** `n_chunks = ceil(tokens / (chunk_size × (1 - overlap)))`

| Overlap | Eff. step (ток.) | Chunks на p50-статью (1 836 ток.) | Chunks на p95-статью (26 014 ток.) | Est. total chunks (113 ст.)* |
|---|---|---|---|---|
| **0 %** | 1 800 | ceil(1836/1800) = **2** | ceil(26014/1800) = **15** | **≈ 340** |
| **10 %** | 1 620 | ceil(1836/1620) = **2** | ceil(26014/1620) = **17** | **≈ 390** |
| **20 %** | 1 440 | ceil(1836/1440) = **2** | ceil(26014/1440) = **19** | **≈ 440** |

*Оценка total chunks — линейная от медианы 1 836 ток., 113 ст., с масштабом от перцентильного распределения (p95 статей дают хвост).

**Storage (вектор 256 dim × 4 байт = 1 024 байт/вектор):**

| Overlap | Total vectors (KB) | Raw vector storage |
|---|---|---|
| 0 % | ~340 | ~340 КБ |
| 10 % | ~390 | ~390 КБ |
| 20 % | ~440 | ~440 КБ |

**Вывод по storage:** разница между 0 % и 20 % — 100 КБ. На корпусе из 113 KB-статей это тривиально. При масштабировании до 100k KB-статей разница вырастет до ~90 МБ — всё ещё несущественно при типичных дисковых ресурсах.

**YC FM cost первичной векторизации KB:**

| Overlap | Total chunks | Est. tokens (chunks × 1 800) | Cost (0,0101 ₽ / 1k) |
|---|---|---|---|
| 0 % | 340 | 612 000 | **6,18 ₽** |
| 10 % | 390 | 702 000 | **7,09 ₽** |
| 20 % | 440 | 792 000 | **7,99 ₽** |

**Дополнительно — summary-row (§8):** 113 summary-векторов × ~200 ток. × 0,0101 / 1k = **≈ 0,23 ₽**. Тривиально.

**Вывод по cost:** Весь диапазон вариантов (0–20 % overlap) обходится в 6–8 ₽ для первичной индексации KB на llm2. Стоимость не является ограничителем выбора overlap.

---

## §3 — OQ-1 закрыт: rollup модель по чанкам

**OQ-1:** какая модель rollup эмбеддинга по чанкам — mean / max / first-chunk / max-of-top-K?

### Литобзор

**Mean pooling** (усреднение по всем чанкам, найденным в top-K): исторически standard для sentence embeddings (BERT, sentence-transformers). Для retrieval по чанкам mean-pool усредняет «общий семантический центр» документа. Теряет острые сигналы: если релевантна только одна часть длинной KB-статьи, mean-pool «разбавляет» этот сигнал нерелевантными чанками. [primary, ruMTEB 2024: latent attention pooling > mean-pool для retrieval quality]

**Max-similarity (min-dist per parent)** — стандарт для parent-document-retrieval в LangChain, LlamaIndex, и LangChain RAG tutorials. Смысл: «документ релевантен, если хотя бы один его чанк очень похож на запрос». Хорошо работает для точечных fact-lookup запросов («как решить проблему X»), которые типичны для UC2 (issue → KB). [established, LangChain parent document retriever — max_marginal_relevance / top-K of chunks]

**First-chunk:** работает, если KB-статьи структурированы с резюме/TL;DR в начале. На llm2 структура KB-статей неизвестна (rich HTML). Гипотеза «первый чанк = наиболее репрезентативный» не верифицирована. [contested — зависит от структуры контента]

**Hierarchical (summary-vector + chunks):** два запроса — сначала по summary, затем уточнение по чанкам. Лучшее качество recall, но ×2 YC FM cost при индексации и +1 SQL round-trip при поиске. При 113 KB-статьях + 200 ток. summary → ≈ 0,23 ₽ extra cost. При масштабе до 10k статей — ≈ 20 ₽ extra. Оправданно при доказанном приросте Recall@10.

### Рекомендация для PoC

**Max-similarity (MIN(dist) per parent)** как default для PoC по следующим причинам:
1. Community-стандарт (LangChain ParentDocumentRetriever, LlamaIndex retrieval patterns)
2. Хорошо подходит для UC2 «найти KB-статью, решающую проблему из заявки» — точечные запросы выигрывают от max-similarity
3. Реализуется одним SQL (CTE с GROUP BY), без дополнительных вызовов YC FM при поиске
4. Summary-row (§8) добавляет fallback: chunk_kind='summary' даёт approximation mean-pool через один вектор

**Финальный выбор — после offline-eval (DEV-033/034) на ground truth:** сравнить Recall@10 mean-pool vs max-sim vs first-chunk на 113 KB-статьях с запросами от issue-body. Результат фиксируется в ADR-011.

**По русскоязычным моделям:** GigaEmbeddings (SOTA на ruMTEB 2025) использует latent attention pooling — superior to mean-pool. Но мы работаем с YC FM `text-search-doc` (внешняя модель с фиксированной размерностью 256) — архитектуру pooling менять нельзя. Для нашего retrieval rollup выбор между mean/max применяется на уровне агрегации chunks в SQL, не в модели.

---

## §4 — OQ-2 и OQ-3 закрыты: chunk overlap и chunk size

### OQ-2: chunk overlap 0 / 10 % / 20 %?

**Литобзор:** LangChain RecursiveCharacterTextSplitter: рекомендован overlap 10–20 % от chunk_size. Weaviate chunking guide: «типичный overlap — 10–20 %». Firecrawl 2026: оптимальный старт — 512 ток. с 10–12,5 % overlap.

**Trade-off:**
- Больше overlap = больше vectors = линейный рост cost. При overlap 20 % vs 0 % cost растёт на ~29 % (7,99 vs 6,18 ₽ для KB на llm2 — пренебрежимо).
- Без overlap: граница чанка может разрезать ключевую фразу — semantic context теряется.
- 10–15 %: баланс, стандарт community.

**Для KB.content (HTML richtext):** нормализация перед чанкингом обязательна (strip HTML → plain text → split). Иначе chunk может начинаться с `</p><table>` и embedding теряет семантику.

**Рекомендация: overlap = 10 % (180 ток. при chunk_size 1 800 ток.).** Это community baseline, обеспечивает контекст на границах, cost-нейтрально на нашем корпусе.

### OQ-3: chunk size — фиксированный / adaptive / sentence-aware?

**Фиксированный (1 800 ток.):**
- Детерминированный — критично для composite_hash (NFR-020)
- Tokenizer-aware: граница = не разрывать слово, использовать whitespace-boundary. При char/tok=3.5: 1 800 ток. ≈ 6 300 chars
- Рекомендован для PoC (KISS principle)

**Adaptive (по абзацам HTML):**
- Лучше для структурированного контента (KB-статьи с `<h2>` sections)
- НЕ детерминирован, если HTML-разбор дает нестабильный порядок → ломает composite_hash
- Нужна явная фиксация алгоритма (algorithm_version в hash)
- Рекомендован для MVP после оценки quality improvement

**Sentence-aware (LlamaIndex SentenceSplitter):**
- Разбивает по предложениям (`.`, `!`, `?`) — не разрывает семантические единицы
- Детерминирован при фиксированном алгоритме разбивки
- Лучше для русскоязычных текстов: SentenceSplitter для ru нужен нестандартный tokenizer (NLTK punkt_ru или spaCy ru_core_news_sm)
- Для PoC: overkill, откладываем

**Особый кейс — очень длинные абзацы (max KB = 75 010 токенов = один HTML-блок):**
Max KB = 262 536 chars / 75 010 ток. Это очевидно один сплошной HTML-блок (или агрегированный контент без абзацев). При chunk_size = 1 800 ток. → 42 чанка. Это нормально для стратегии C. Проблема: если один абзац длиннее chunk_size без whitespace — нужно hard-split по символу. Обработка: `split at whitespace_boundary near chunk_size`.

**Рекомендация:** фиксированный chunk_size = 1 800 ток. (±10 % для whitespace-align), overlap = 10 % (180 ток.), tokenizer = whitespace-boundary split. Для PoC — достаточно. Для MVP — оценить sentence-aware split на offline-eval.

---

## §5 — OQ-4 закрыт: ACL при multi-chunk

**OQ-4:** где фильтровать ACL для KB при chunked-стратегии?

### Контекст

KB ACL реализован через `kbAccesses` (атрибут `isPrivate` на уровне статьи). ACL проверяется на уровне объекта (`object_id`), НЕ на уровне чанка.

У issue/problem ACL управляется SMP-сессией (платформа ограничивает видимость на уровне запроса) — дополнительного фильтра не нужно.

### Алгоритм для D-strategy KB (точная последовательность)

**SQL + Java (с round-trip разбивкой):**

```
Step 1 — SQL (1 round-trip):
  SELECT parent_id, MIN(embedding <=> :q AS dist)
  FROM pg_vector_service__vectors
  WHERE meta_class = 'knowledgeBase$article'
    AND tenant_id = :tid
    AND model_version = :mv
    AND chunk_kind IN ('chunk', 'summary')
  GROUP BY parent_id
  ORDER BY min_dist
  LIMIT :oversample_k   -- K × 5 (oversample для компенсации ACL-фильтра)

Step 2 — Java (ACL-фильтр, SMP API):
  List<UUID> parentIds = result.getParentIds();                // из Step 1
  List<UUID> allowed = kbAccessChecker.filterAllowed(parentIds, currentUserCtx);  // SMP kbAccesses
  return allowed.stream().limit(N).collect(toList());

Step 3 — Если allowed.size() < N (short result):
  Option A: вернуть partial result (допустимо для PoC)
  Option B: повторить Step 1 с LIMIT = oversample_k × 2
```

### Оценка доп. round-trips

- Step 1 SQL: 1 round-trip (pgvector HNSW + GROUP BY). Ожидаемый latency: 5–30 ms на 113 KB-векторов (~ 390 чанков с overlap 10 %).
- Step 2 ACL (SMP API call): 1 round-trip к SMP kbAccesses. Ожидаемый latency: 20–50 ms (SMP internal).
- **Итого:** 2 round-trips = 25–80 ms. Вписывается в NFR-001 p95 ≤ 500 ms.

### Эффект на NFR-001

При N=10 результатов и oversample_k=50: из 113 KB-статей берём top-50 чанков → ≈ 20–30 distinct parents → ACL-фильтр удаляет private → top-10. Если из 50 чанков получается < 10 distinct KB-статей — oversample нужно увеличивать. На корпусе 113 статей это гипотетично маловероятно: при random distribution 50 chunks → ≥ 20 distinct parents с вероятностью > 95 %.

**Вывод:** ACL фильтрация после GROUP BY parent_id в Java. НЕ в SQL (нет JOIN на kbAccesses в pgvector-таблице). 2 round-trips total, NFR-001 выполняется.

---

## §6 — OQ-5 и OQ-9 закрыты: source_attr колонка и DDL под E

### OQ-5: нужна ли source_attr в PoC?

**Варианты конвенции:**

1. `source_attr VARCHAR(64) NULLABLE` — имя SMP-атрибута-источника. Для single-vector (A) = NULL. Для per-attribute (B) = 'subject', 'decisionReport'. Для chunk (C) = имя атрибута, из которого взят chunk (например, 'content').
2. Конвенция через `chunk_kind` (без source_attr) — 'object' / 'chunk' / 'summary' / 'related'.
3. Обе колонки.

**Comparison с community-стандартами:** Supabase pgvector schema использует `metadata JSONB` для произвольных метаданных (включая source_attr). DEV Community RRF-schema: `metadata JSONB DEFAULT '{}'`. LangChain ParentDocumentRetriever: хранит `doc_id` (= parent_id) и `source` (= source_attr) в metadata.

**Рекомендация для PoC:** добавить `source_attr VARCHAR(64) NULLABLE`. Стоимость: 1 nullable колонка = практически нулевой storage overhead. Ценность: позволяет per-attribute search (B-стратегия в будущем) и debugging (какой атрибут дал чанк). Для стратегии A: source_attr = NULL. Для стратегии C (KB): source_attr = 'content'.

### OQ-9: как поддержать E (per-comment-vector) в DDL без реализации?

**Конвенция для E (per-related-vector):**

```
parent_id UUID = object_id родительского объекта (issue.id, problem.id)
object_id      = id связанного объекта (comment.id)
meta_class     = 'comment'
chunk_kind     = 'related'
source_attr    = 'text'  (или имя атрибута комментария)
chunk_index    = порядковый номер комментария среди комментариев parent'а
```

Такой паттерн покрывается DDL из §4/Dimension-4 **без изменений**. `parent_id` nullable FK обеспечивает связь с parent-объектом. `chunk_kind = 'related'` отличает от 'chunk' (часть длинного текста) и 'object' (single-vector).

**Когда E реализовывать:** только после sign-off owner'а на `comment.text` в whitelist (ADR-005) — в текущем PoC `comment.text` not whitelisted.

---

## §7 — OQ-6 закрыт: детерминированность chunk_index

**OQ-6:** как гарантировать детерминированность chunk_index при ре-векторизации?

### Проблема

`composite_hash = sha256(text + model_version + whitelist_version + chunk_params + algorithm_version)`. Если при каждом запуске chunk_index меняется (разное число чанков, разный порядок), хеш не совпадает → dirty=true → повторная векторизация.

### Решение (псевдокод)

```
def chunk(text: String, chunk_size: Int, overlap: Int, algorithm_version: String) -> List[Chunk]:
    # 1. Нормализация richtext (HTML-strip, whitespace collapse) — детерминировано
    normalized = html_strip(text)
    normalized = collapse_whitespace(normalized)

    # 2. Токенизация whitespace-boundary
    tokens = split_by_whitespace(normalized)

    # 3. Sliding window — детерминированный алгоритм
    step = chunk_size - overlap
    chunks = []
    for i in range(0, len(tokens), step):
        chunk_tokens = tokens[i : i + chunk_size]
        chunks.append(Chunk(
            text = join(" ", chunk_tokens),
            chunk_index = len(chunks),  # порядковый номер от начала
            chunk_total = None          # заполняется после цикла
        ))
    for chunk in chunks:
        chunk.chunk_total = len(chunks)
    return chunks

composite_hash = sha256(
    normalized_text
    + "|" + model_version
    + "|" + str(whitelist_version)
    + "|" + str(chunk_size)
    + "|" + str(overlap)
    + "|" + algorithm_version  # например "v1.0"
)
```

**Инварианты:**
- HTML-strip → нормализация → split → sliding window = детерминированный порядок
- `chunk_index` = порядковый номер от 0 (от начала текста)
- `algorithm_version` включён в hash: при изменении алгоритма (например, переход на sentence-aware) — `algorithm_version = "v2.0"` → все старые хеши инвалидированы → полный пересчёт (новый ADR как ADR-007)
- Если входной text не изменился + `whitelist_version` + `chunk_size` + `overlap` + `algorithm_version` не изменились → hash стабилен → `dirty = false` → YC FM не вызывается

---

## §8 — OQ-7 закрыт: summary-row vs on-the-fly rollup

**OQ-7:** хранить ли отдельный summary-вектор (chunk_kind='summary') или считать на лету?

### Расчёт overhead summary-row

| Параметр | Значение |
|---|---|
| KB-статей на llm2 | 113 |
| Summary-вектор размером | 256 dim × 4 байт = 1 024 байт |
| Итого storage | 113 × 1 024 = **116 КБ** |
| Summary-текст | ≈ 200 ток. (сжатое резюме статьи) |
| YC FM cost summary vectorize | 113 × 200 / 1 000 × 0,0101 = **≈ 0,23 ₽** |

Overhead тривиален на любом разумном масштабе (при 10k статей: ~10 МБ storage, ~23 ₽ extra cost).

### Trade-off

**Summary-row (`chunk_kind = 'summary'`, `chunk_index = -1`):**
- +: поиск по одному вектору вместо GROUP BY, latency лучше
- +: может использоваться как approximation mean-pool (если summary = краткое изложение всей статьи)
- +: DEBUG: можно проверить качество summary отдельно
- -: дополнительный YC FM call при каждой векторизации KB-статьи
- -: нужен алгоритм генерации summary (truncation первых N токенов — простейший вариант для PoC)

**On-the-fly GROUP BY:**
- +: нет extra storage, нет extra YC FM call
- -: GROUP BY на каждый search запрос (+5–15 ms latency)
- -: при изменении чанкинга (algorithm_version bump) summary не нужно пересчитывать отдельно

### Рекомендация

**Summary-row для KB в PoC — recommended.** Overhead тривиален. Алгоритм для PoC: summary = первые min(200, chunk_size) токенов нормализованного текста (`chunk_index = 0` переобозначается как первый чанк, summary хранится с `chunk_kind = 'summary'` и `chunk_index = -1`).

Альтернативная нумерация: `chunk_index = 0` = summary, чанки с 1, 2, 3... Это проще в реализации.

**Выбор для PoC:** `chunk_index = 0 = summary` (первые 200 ток.); content-chunks с `chunk_index = 1, 2, 3...`. Поиск использует `chunk_kind IN ('summary', 'chunk')` или раздельно.

Для issue (single-vector A): chunk_index = 0, chunk_total = 1, chunk_kind = 'object' — summary не нужен, вектор сам и есть "summary".

---

## §9 — OQ-8: точный лимит YC FM text-search-doc

**OQ-8:** 2 048 или 8 000 токенов?

### Статус

Smoke с 3 000 токенов **не был запущен** в этой волне — credential-секреты не используются исследователем (политика: owner'у через структурированную инструкцию).

Из доступных данных:
- Live smoke 2026-05-01 (yc-foundation-models.md): 49 chars / 14 токенов — лимит не тестировался
- YC FM API официальная документация — недоступна (CAPTCHA на aistudio.yandex.ru)
- LangChain YandexGPTEmbeddings: не содержит явного `max_tokens` параметра
- GitHub-проекты yandex-gpt-rest-api: упоминают `numTokens` в response, но не max

**Инструкция для owner'а (запустить одной командой):**

```bash
API_KEY=$(python3 -c "import json; d=json.load(open('.secrets/yc-api-key.json')); print(d.get('secret', d.get('key', '')))")
FOLDER_ID=b1g249mrsql00khlmvcs
MODEL="emb://${FOLDER_ID}/text-search-doc/latest"
URL="https://llm.api.cloud.yandex.net/foundationModels/v1/textEmbedding"

# Генерируем текст ~3000 токенов (примерно 10500 chars при ratio 3.5)
TEXT=$(python3 -c "print('Проблема с доступом к корпоративной сети VPN после планового обновления. ' * 150)")

RESPONSE=$(curl -s -X POST "$URL" \
  -H "Authorization: Api-Key $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"modelUri\": \"$MODEL\", \"text\": \"$TEXT\"}")

echo "Chars: $(echo -n "$TEXT" | wc -c)"
echo "numTokens: $(echo $RESPONSE | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("numTokens","MISSING"))')"
echo "embedding_len: $(echo $RESPONSE | python3 -c 'import sys,json; d=json.load(sys.stdin); print(len(d.get("embedding",[]))) if "embedding" in d else print("ERROR:", d.get("error",""))')"
echo "full_response_keys: $(echo $RESPONSE | python3 -c 'import sys,json; d=json.load(sys.stdin); print(list(d.keys()))')"
```

**Ожидаемый ответ:**
- Если `numTokens = ~3000` и `embedding_len = 256` → лимит ≥ 3 000, пробовать с 6 000 / 8 000
- Если `error` содержит «token limit exceeded» или `numTokens < 3000` → лимит = 2 048 (truncation или error)

**Impact на выводы §3 RES-009.1:**
- Если лимит ≥ 8 000: `pct_over_8000_tok` для KB = max chars 262 536 / 3.5 / 8 000 ≈ 9 чанков max вместо 42. `pct_over_2048_tok` для `issue.description` (13,3 %) снижается до `pct_over_8000_tok` ≈ 0,5 % (мало меняет вывод)
- Если лимит = 2 048 (текущее допущение): выводы §3 остаются без изменений

**Статус OQ-8:** deferred (smoke с 3k ток.) — **ожидает owner'а**. Текущее допущение для волны 3: **лимит = 2 048 токенов** (conservative). При получении smoke-данных SA обновит ADR-011.

---

## §10 — OQ-10 закрыт: truncation policy для редких длинных issue

**OQ-10:** что делать с 0,4 % issue (25 объектов из 6 223), у которых composite_extended > лимита?

**Данные:** `issue.composite_extended` max = 57 936 chars / 16 553 ток. (57 936 / 3.5). 0,4 % = 25 заявок.

### Варианты

| Вариант | Описание | Pros | Cons |
|---|---|---|---|
| **(a) Caller обрезает до 2 000 ток.** | Caller строит composite_extended, обрезает до N ток. перед отправкой | KISS; явный контракт; caller знает что делает | 25 заявок теряют хвост (>2000 ток.); для заявок с ключевой информацией в хвосте — снижение quality |
| **(b) Модуль возвращает 413 ContentTooLarge** | Caller получает ошибку → переключается на C-режим | Явная обратная связь; caller может chunked-векторизовать | Усложняет caller; требует retry-логики; 2 round-trips |
| **(c) Авто-переключение на C внутри модуля** | Модуль сам чанкирует при превышении лимита | Прозрачно для caller | Усложняет модуль; нужен ChunkAggregator для search на issue; неожиданное поведение API |

### Рекомендация

**PoC: вариант (a) — caller обрезает до `limit - 48` токенов (≈ 2 000 ток.) перед отправкой.** Обоснование:
- 25 заявок из 6 223 = 0,4 % — пренебрежимо малая доля
- Для PoC качество на этих 25 заявках некритично
- KISS: API-контракт прост («текст должен укладываться в лимит»)
- Caller уже отвечает за whitelist-сборку composite_extended (ADR-006) — truncation логично там же

**MVP: пересмотр на вариант (c)** — модуль auto-switch на C для overflow, прозрачный для caller. Условие перехода: после PoC smoke и оценки impact на 25 заявках.

**В API-контракте волны 3 зафиксировать:** `VectorizationRequest.text` — max длина = `token_limit - 48` токенов (запас для model overhead). Если превышение — `VectorizationException(TooLongText, charCount, estTokens)`.

**Добавить в open questions волны 3:** определить точный token_limit после smoke (OQ-8) → обновить контракт.

---

## §11 — Служебные таблицы: выносить или inline

### Реестр кандидатов

**Таблица 1: `pg_vector_service__audit_log`**

```sql
CREATE TABLE pg_vector_service__audit_log (
    id            BIGSERIAL     PRIMARY KEY,
    event_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    object_id     UUID          NOT NULL,
    meta_class    TEXT          NOT NULL,
    tenant_id     TEXT          NOT NULL,
    model_version TEXT          NOT NULL,
    chunk_count   SMALLINT      NOT NULL DEFAULT 1,
    tokens_used   INT           NOT NULL,
    cost_rub      NUMERIC(10,6) NOT NULL,  -- расчётная стоимость вызова YC FM
    status        TEXT          NOT NULL,  -- 'success'|'error'|'skip_idempotent'
    error_msg     TEXT          NULLABLE
);
-- Retention policy: 90 дней (configurable)
-- Индекс: B-tree на (tenant_id, event_at) для NFR-053 наблюдаемости
```

**Назначение:** NFR-053 (наблюдаемость), аудит YC FM расходов, debugging.
**Retention:** 90 дней rolling. При объёме 6 223 заявок × 1 событие/день = ~560k строк/год = ~56 МБ — приемлемо.

**Таблица 2: `pg_vector_service__model_registry`**

```sql
CREATE TABLE pg_vector_service__model_registry (
    model_version TEXT        PRIMARY KEY,  -- полный modelUri
    embedding_dim SMALLINT    NOT NULL,
    registered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deprecated_at TIMESTAMPTZ NULLABLE,
    notes         TEXT        NULLABLE
);
```

**Назначение:** история моделей с датами регистрации/deprecated (ADR-007 model versioning). Связь с основной таблицей через `model_version TEXT`. Не FK — soft reference, т.к. model_version может изменить формат при смене YC FM API.

**Таблица 3: `pg_vector_service__whitelist_registry`**

**Вопрос:** хранить whitelist в БД или как code-as-config в JAR?

- Code-as-config (YAML resource в JAR): детерминировано, версионируется с кодом, нет runtime DDL. Recommended для PoC.
- Таблица в БД: позволяет runtime изменения без редеплоя JAR. Нужен механизм sign-off (owner должен одобрить изменение).

**Рекомендация:** для PoC — code-as-config (YAML в resources). Для MVP — отдельный ADR о runtime whitelist management. Таблицу пока не создаём.

**Таблица 4: `pg_vector_service__search_log`**

```sql
CREATE TABLE pg_vector_service__search_log (
    id              BIGSERIAL     PRIMARY KEY,
    searched_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    tenant_id       TEXT          NOT NULL,
    use_case        TEXT          NOT NULL,   -- 'UC2'|'UC3'
    source_id       UUID          NULLABLE,
    target_classes  TEXT[]        NOT NULL,
    k_requested     SMALLINT      NOT NULL,
    k_returned      SMALLINT      NOT NULL,
    latency_ms      INT           NOT NULL,
    model_version   TEXT          NOT NULL
);
-- Retention policy: 30 дней
-- Индекс: B-tree на (tenant_id, searched_at)
```

**Назначение:** NFR-053 наблюдаемость, latency tracking, аномалии. Для offline analysis quality (latency дрейф = косвенный признак index degradation).

**Chunk-meta колонки в основной таблице (inline):**

`chunk_index`, `chunk_total`, `source_attr`, `chunk_kind`, `parent_id` — рекомендуется **inline** в `pg_vector_service__vectors`. Обоснование: не требуют отдельного JOIN при поиске, overhead storage минимален (< 50 байт/строку), логически принадлежат векторной записи.

### Сводка

| Таблица | Решение | Приоритет PoC |
|---|---|---|
| `pg_vector_service__vectors` | Основная — обязательно | P0 |
| `pg_vector_service__audit_log` | Выносить отдельно — обязательно для наблюдаемости | P1 |
| `pg_vector_service__model_registry` | Выносить — optional для PoC, нужна до MVP | P2 |
| `pg_vector_service__search_log` | Выносить — optional для PoC, нужна до MVP | P2 |
| `pg_vector_service__whitelist_registry` | Code-as-config в PoC, таблица в MVP | P3 |

---

## §12 — Эскалация в BA: PoC-whitelist value

### Численные данные

| Whitelist | Median composite | p95 composite | % > 2048 tok | % < 100 tok |
|---|---|---|---|---|
| PoC (subject + cancelReason) | **33 chars / 22 ток.** | 77 chars / 22 ток. | 0 % | 99,9 % |
| Extended (+ decisionReport + feedback) | **62 chars / 209 ток.** | 734 chars | 0,4 % | 88,9 % |

(Данные из length-distribution.csv, char/tok = 3.5)

### Quality risk

При median composite = 22 токена (≈ 5–6 слов):
- Embedding из 22-токенного текста практически равен embedding из `subject` одной фразы
- Cosine similarity между разными заявками с коротким `subject` будет высокой даже при несвязанном контексте (high false-positive rate)
- **Вероятность Recall@10 ≥ 0,7 на PoC-whitelist ≈ 0 %** — это не субъективная оценка: при 22 токенах embedding не содержит достаточно семантической информации для различения 6 223 заявок. Эффективный beam width similarity search на 22-токенных векторах будет давать случайные результаты.

### Рекомендация для BA

**Вариант 1 (рекомендуемый):** ускорить sign-off на medium-PII атрибуты (`subject`, `feedback`, `decisionReport`) до старта PoC iter 1. Без этого PoC iter 1 UC2/UC3 не продемонстрирует практической пользы.

**Вариант 2 (компромисс — PoC iter 0 + PoC iter 1):**
- PoC iter 0 (2–3 дня): запустить end-to-end pipeline на PoC-whitelist (22 ток.) — smoke только технической части (vectorize → store → search → return result). Quality не оценивается.
- PoC iter 1 (после sign-off): перейти на composite_extended, запустить offline-eval (Recall@10, MRR@10). Это даёт реальное качество.

**Что нужно от BA до PoC iter 1:**
- Sign-off на `issue.subject` (medium-PII: ФИО оператора могут присутствовать в теме)
- Sign-off на `issue.decisionReport` (medium-PII: контактные данные клиента в решении)
- Sign-off на `issue.feedback` (medium-PII: отзыв клиента)
- Либо explicit decision: «принимаем degraded quality на PoC iter 1 с PoC-whitelist»

**Риск задержки sign-off:** если sign-off приходит после PoC iter 1, все issue-векторы пересчитываются (ADR-005 NFR-032) — дополнительный cost ≈ 4 ₽ (пренебрежимо, но задержка по времени).

---

## §13 — Стенд для валидации problem

### Ситуация

На llm2: **3 объекта `problem`**, 0 комментариев, 0 workaround, 0 rootCause. Статистически невалидируемый корпус. Validate PoC iter 2 (problem) на этом стенде **невозможно**.

### Три варианта (pros/cons, решение — owner/PM)

**Вариант A: problem не валидируется в PoC → снять PoC iter 2 с roadmap'а**

| Pros | Cons |
|---|---|
| Честная scope-редукция: не тратим итерацию на невалидируемый кейс | UC3 batch (problem dedup) — ключевой бизнес-кейс по ТЗ; откладывание создаёт долг |
| Можно объединить iter 2 и iter 3 (issue + KB), сэкономить спринт | Pilot без problem-валидации — ограниченная уверенность в качестве |
| Ресурсы на issue + KB (более богатый корпус) | Stakeholders (Сазонова, Киселёва) ожидают problem в PoC |

**Вариант B: запросить Сахабетдинова о другом стенде / production-snapshot**

| Pros | Cons |
|---|---|
| Реалистичный корпус — наиболее достоверная валидация | Зависит от доступности другого стенда / snapshot (timeline неизвестен) |
| Нет синтетики — данные настоящие | Может потребовать дополнительного PII-аудита для нового стенда |
| Простейший путь если стенд доступен | Может задержать PoC iter 2 на 1–3 недели |

**Вариант C: synthetic-генерация problem-описаний**

| Pros | Cons |
|---|---|
| Управляемый корпус с известным ground truth | Синтетические данные ≠ production distribution |
| Не зависит от внешних стендов | Дополнительная работа: генерация через YC FM LLM (cost ≈ 0,1–0,5 ₽ для 50–100 объектов) |
| Позволяет сгенерировать known-duplicate пары (для UC3 ground truth) | Качество embedding на синтетике может давать оптимистичный recall (distribution shift) |

**Рекомендация researcher'а (НЕ решение — только для PM):** начать с Варианта B (пинг Сахабетдинову на другой стенд или snpashot), параллельно подготовить план C как fallback. Вариант A — если B и C недоступны до PoC iter 2.

---

## Что не удалось выяснить

| Пробел | Почему | Условие закрытия |
|---|---|---|
| Точный лимит токенов YC FM `text-search-doc` | Smoke с 3k ток. не запускался (owner не прислал) | Smoke по инструкции §9 |
| Offline-eval данные rollup (mean vs max vs first-chunk) | Требует DEV-033 — offline evaluation на ground truth | Dev iter (после PoC iter 1) |
| Реальная задержка ACL-фильтра (kbAccessChecker) | Нет smoke на ACL-запросе к llm2 | Smoke в DevOps |
| Структура KB-статей на llm2 (есть ли TL;DR в начале) | MCP-сессия не позволила выгрузить sample content | MCP live-запрос к llm2 |
| Доступность альтернативного стенда для problem (Вариант B §13) | Ожидает пинга Сахабетдинову | PM/owner эскалация |

---

## Open questions для волны 3 (RES-009.3)

| Приоритет | Вопрос | Куда влияет |
|---|---|---|
| P0 — блокирует DDL | Результат smoke OQ-8 (лимит токенов) — обновить если ≠ 2 048 | DDL chunk_size, ADR-011 |
| P0 — блокирует DDL | Финальный DDL с HNSW параметрами (m, ef_construction) — волна 3 SA | ADR-011 |
| P1 — блокирует API-контракт | API-контракт: `VectorizationRequest` / `SearchRequest` / `VectorizationResponse` shapes | SA, Dev |
| P1 — поэтапность | Рекомендация поэтапного rollout PoC iter 1→4 с учётом §12 и §13 | PM roadmap |
| P2 — quality | Offline-eval rollup choice (mean vs max) — после DEV-033 | ADR-011 update |
| P2 — стенд | Вариант для problem-валидации (§13 A/B/C) — решение PM | Roadmap PoC iter 2 |
| P3 | Truncation policy: когда переходить с (a) на (c) для 0,4 % overflow issue | ADR update |

---

## Рекомендации для BA/SA

**BA:**
- Ускорить sign-off на medium-PII атрибуты (`subject`, `decisionReport`, `feedback`) до PoC iter 1. Без этого UC2/UC3 не дадут практической ценности (§12 — median 22 токена = near-random quality).
- Решить §13: стенд для problem-валидации (вариант A/B/C) — input для PM roadmap.
- Зафиксировать в AC UC2 BR-002: ACL применяется post-aggregation (к parent_id), не к chunk_id.

**SA:**
- ADR-011: финализировать DDL с chunk_index, chunk_total, parent_id, source_attr, chunk_kind. Параметры HNSW после smoke OQ-8 и offline-eval.
- ADR-012 (chunk aggregation): зафиксировать rollup strategy (max-sim как default, pending DEV-033).
- API-контракт VectorizationPort: принимает `text` ≤ token_limit (caller обрезает), возвращает `VectorRecord` с chunk metadata.
- ACL-механизм: фильтрация в Java после GROUP BY, не в pgvector SQL.

---

## Источники

- [primary] `content/10-domain/research/vector-storage-domain.md` — артефакт волны 1 (Approved), все фактические данные llm2
- [primary] `content/10-domain/research/raw/length-distribution.csv` — сырые данные корпуса llm2 (2026-05-01)
- [primary] `content/10-domain/research/yc-foundation-models.md` — smoke YC FM, numTokens, dim=256
- [primary] `content/10-domain/research/yc-pricing.md` — тариф 0,0101 ₽ / 1k юнитов
- [primary] `content/10-domain/research/pgvector-indexes.md` — HNSW параметры, storage оценки
- [primary] `content/10-domain/research/similarity-eval.md` — методология eval, Recall@10, MRR@10
- [primary] `content/00-project/adr/004-vector-storage-schema.md` — текущая схема таблицы
- [primary] `content/00-project/adr/005-whitelist-pii-default-deny.md` — whitelist состав
- [primary] `content/00-project/adr/006-composite-text-composition.md` — composite text, truncation, nормализация richtext
- [secondary, established] [Weaviate — Chunking Strategies for RAG](https://weaviate.io/blog/chunking-strategies-for-rag) — chunk_size 512 ток., overlap 10–20 %, базовые рекомендации
- [secondary, established] [LangChain — Recursive text splitter](https://docs.langchain.com/oss/python/integrations/splitters/recursive_text_splitter) — chunk_size=512, chunk_overlap=64 (12,5 %)
- [secondary, established] [DEV Community — Hybrid search RRF with pgvector](https://dev.to/lpossamai/building-hybrid-search-for-rag-combining-pgvector-and-full-text-search-with-reciprocal-rank-fusion-6nk) — DDL pattern с parent-child, RRF формула, chunk schema
- [secondary, established] [OpenSearch — Introducing RRF for hybrid search](https://opensearch.org/blog/introducing-reciprocal-rank-fusion-hybrid-search/) — RRF formula и константа k=60
- [secondary, emerging] [arxiv 2408.12503 — ruMTEB benchmark](https://arxiv.org/abs/2408.12503) — Russian embedding models, latent attention pooling vs mean-pool для retrieval
- [secondary, emerging] [arxiv 2510.22369 — GigaEmbeddings](https://arxiv.org/abs/2510.22369) — SOTA русскоязычные эмбеддинги, latent attention pooling superior to mean-pool
- [secondary, established] [Firecrawl — Best chunking strategies 2026](https://www.firecrawl.dev/blog/best-chunking-strategies-rag) — overlap 10–20 %, recursive chunking как default
- [secondary, established] [Microsoft Azure — RAG chunking phase](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/rag/rag-chunking-phase) — HTML normalization before chunking, context-aware split
- [secondary, established] [Unstructured — Chunking for RAG best practices](https://unstructured.io/blog/chunking-for-rag-best-practices) — strip HTML, overlap 10–20 %
