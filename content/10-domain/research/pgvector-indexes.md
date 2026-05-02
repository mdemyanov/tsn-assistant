---
order: 4
title: pgvector — выбор индекса и параметры
properties:
  - Тип контента: Исследование
  - Фаза: PoC
  - Статус: Draft
---

# pgvector — выбор индекса и параметры

> Источники сверены **2026-05-01**. Версия pgvector на стенде `llm2` —
> **open question** (см. секцию 8). Все цифры ниже привязаны к актуальному
> релизу `pgvector v0.8.2` ([README, sha at 2026-05-01](https://github.com/pgvector/pgvector)).

## 1. Резюме

- Для нашей медианы (100k–300k векторов на тенант) и use case'ов
  similarity-top-K + кластеризация **рекомендуется HNSW** (`vector_cosine_ops`)
  как индекс по умолчанию: лучший recall/latency, меньше тюнинга, работает
  с инкрементальными вставками без ручного rebuild.
- **IVFFlat** имеет смысл рассматривать только при ограничениях по памяти на
  стенде или при первичной массовой загрузке (быстрее строится, меньше RAM,
  но требует periodic rebuild и хуже на инкрементах).
- Для 1M–10M (верхняя планка диапазона) HNSW остаётся жизнеспособным, но
  требует ≥ 8–16 GB `maintenance_work_mem` для построения и тюнинга `m`/`ef`.
  Альтернатива — `halfvec` (см. секцию 6) или binary quantization (с v0.7.0),
  что даёт до 150× ускорение build при сохранении recall.
- Главный ограничитель PoC — **DDL только через DBA** (см. секцию 7),
  поэтому план миграций индекса фиксируется в ADR/runbook заранее.

## 2. HNSW vs IVFFlat — сравнение

| Параметр | HNSW | IVFFlat |
|---|---|---|
| Алгоритм | Иерархический navigable small-world граф | Inverted file (k-means кластеры) |
| Время построения | Дольше (на v0.5.0 в 5×, на v0.7.0 разрыв ~2×) | Быстрее на старте |
| Query latency (≈99% recall) | ~1.5 ms | ~2.4 ms (×30 хуже throughput при равном recall на современных бенчах) |
| Память (рост от размера) | Выше (на бенче 729 MB vs 257 MB IVFFlat при recall=0.998) | Ниже |
| Recall при default | 95%+ из коробки | Зависит от `lists`/`probes`; для высокого recall растут оба |
| Inserts/Updates | Инкрементальные, без rebuild; деградация при росте графа > `maintenance_work_mem` | После большого insert желательно `REINDEX` (центроиды k-means устаревают) |
| Минимальные данные | Работает на любом объёме | Нужна репрезентативная выборка для k-means (тысячи+) |
| Версия pgvector | C v0.5.0 (2023). Сильно ускорен в v0.7.0 (2024-04-30) и v0.8.x | С v0.4.x |
| Параметры | `m`, `ef_construction` (build); `ef_search` (query) | `lists` (build); `probes` (query) |
| Defaults (v0.8.2) | `m=16`, `ef_construction=64`, `ef_search=40` | `lists` — задаётся; `probes=1` |
| Iterative scans (v0.8) | `max_scan_tuples=20000`, `scan_mem_multiplier=1×work_mem` | `max_probes` — настраивается |

Источники: pgvector README ([github.com/pgvector/pgvector](https://github.com/pgvector/pgvector)),
AWS Database Blog ([Optimize generative AI applications with pgvector indexing](https://aws.amazon.com/blogs/database/optimize-generative-ai-applications-with-pgvector-indexing-a-deep-dive-into-ivfflat-and-hnsw-techniques/)),
Jonathan Katz ([The 150× pgvector speedup](https://jkatz05.com/post/postgres/pgvector-performance-150x-speedup/), 2024-04-30).

## 3. Рекомендация под наши объёмы

### 3.1. Медиана 100k–300k (целевой профиль PoC)

- **Индекс:** `HNSW` на `vector_cosine_ops`.
- **Build:** `m = 16`, `ef_construction = 64` (defaults).
  Поднимать `ef_construction` до 128–256 имеет смысл, если recall < 0.95
  на eval-выборке.
- **Query:** `ef_search = 40` (default). Для high-recall запросов
  кластеризации повышаем до 100–200 на сессию через `SET LOCAL`.
- **maintenance_work_mem:** ≥ 2 GB на построение
  (запросить у DBA на время DDL).

### 3.2. Верхняя планка 1M–10M

- **Индекс:** `HNSW` (если позволяет память) либо `HNSW` поверх `halfvec`
  (×2 экономия места при незначительной потере recall).
- **Build:** `m = 32`, `ef_construction = 128–256`.
  На v0.5.0 при ~58k записей build HNSW занимал ~81s, в v0.6.0 уже ~30s
  ([AWS](https://aws.amazon.com/blogs/database/optimize-generative-ai-applications-with-pgvector-indexing-a-deep-dive-into-ivfflat-and-hnsw-techniques/));
  в v0.7.0 на dbpedia-openai-1M build с recall 99% — 250s vs 7479s в v0.5.0
  ([Katz](https://jkatz05.com/post/postgres/pgvector-performance-150x-speedup/)).
- **Query:** `ef_search` в диапазоне 60–200 в зависимости от целевого recall.
- **maintenance_work_mem:** 8–32 GB для построения; иначе build деградирует
  по ссылке на issue #455 ([github.com/pgvector/pgvector/issues/455](https://github.com/pgvector/pgvector/issues/455)).
- **Альтернатива IVFFlat:** `lists ≈ sqrt(rows)` (для 1M это ~1000),
  `probes ≈ sqrt(lists)` ≈ 32. Ниже build, но REINDEX при дорастании.

## 4. Метрики расстояния

| Метрика | Оператор | Operator class | Когда выбирать |
|---|---|---|---|
| L2 (Euclidean) | `<->` | `vector_l2_ops` | Если эмбеддинги не нормализованы и важна абсолютная разница |
| Cosine | `<=>` | `vector_cosine_ops` | **Дефолт для трансформерных эмбеддингов** (BERT-like, sentence-transformers) |
| Inner product (negative) | `<#>` | `vector_ip_ops` | Если эмбеддинги уже L2-нормализованы (OpenAI, Jina) — эквивалентно cosine, но быстрее |
| L1 / Hamming / Jaccard | `<+>`, `<~>`, `<%>` | соответствующие *_ops | Out of scope (для бинарных/sparse-сценариев) |

**Что выбирать для нашего PoC:**

- Yandex Cloud Foundation Models (RES-002): дефолт — `vector_cosine_ops`,
  пока RES-002 не зафиксирует, нормализованы ли вектора у выбранной модели.
- Русскоязычные encoder-модели (sbert-ru, RuELECTRA и аналоги): cosine —
  каноничный выбор, в публикациях retrieval-метрики приводятся именно
  по cosine similarity.
- **Важно:** оператор класса индекса должен совпадать с оператором запроса.
  Запрос `<=>` по индексу `vector_l2_ops` индекс не использует — fallback
  в seq scan. Это влияет на ADR (фиксируем метрику + соответствующий
  operator class одной строкой).

Источники: pgvector README distance metrics, [DEV.to: pgvector Distance Functions](https://dev.to/philip_mcclarence_2ef9475/pgvector-distance-functions-cosine-vs-l2-vs-inner-product-57pd) (свериться 2026-05-01).

## 5. Update / Insert поведение

Для нашего сценария «джоба по расписанию векторизует новые/изменённые
объекты SMP» это критическая секция.

### 5.1. HNSW

- Поддерживает инкрементальные insert/update без перестроения индекса.
- **Известная боль (issues 2024–2025):**
  - Insert throughput деградирует на больших таблицах: ~20 rows/s
    у одного клиента, до ~3 rows/s на миллионных датасетах
    ([issue #810](https://github.com/pgvector/pgvector/issues/810)).
  - UPDATE на не-векторных колонках замедляется при наличии HNSW
    ([issue #875](https://github.com/pgvector/pgvector/issues/875)) —
    из-за HOT-update ограничений.
  - При выходе графа за `maintenance_work_mem` build/insert тормозит
    ([issue #455](https://github.com/pgvector/pgvector/issues/455)).
- **Митигация для джобы:** батчевые inserts, `maintenance_work_mem` ≥ 2 GB,
  при больших backfill — DROP INDEX → bulk insert → CREATE INDEX
  (даёт кратный выигрыш, но требует окна обслуживания и согласования с DBA).

### 5.2. IVFFlat

- Insert работает, но добавленные векторы попадают в существующие
  k-means клетки, построенные на старых данных → recall деградирует
  по мере дрейфа распределения.
- **Требует periodic REINDEX** для восстановления качества (AWS Blog: «It
  may be necessary to rebuild when adding or modifying vectors»).
- Для нашей джобы по расписанию это означает дополнительную операционную
  процедуру (REINDEX по cron) — ещё один аргумент в пользу HNSW.

### 5.3. Что заложить в ADR/runbook

- Окно для `REINDEX`/`DROP+CREATE INDEX` (если выбираем такую стратегию
  для backfill) — согласовать с DBA.
- Метрика recall на eval-наборе как health-check для индекса
  (RES-005 → eval-методология).
- Лимит на размер батча в джобе (чтобы не упереться в insert-throughput).

## 6. Размерность вектора

| Тип | Лимит без индекса | Лимит с индексом | Размер 1 значения |
|---|---|---|---|
| `vector` | 16 000 | 2 000 | 4 байта × dim |
| `halfvec` | 16 000 | 4 000 | 2 байта × dim |
| `bit` | n/a | 64 000 | 1 бит |
| `sparsevec` | 16 000 | 1 000 ненулевых | переменный |

Источник: pgvector README v0.8.2, секция «Vector Dimensions» (свериться
2026-05-01 — [github.com/pgvector/pgvector](https://github.com/pgvector/pgvector)).

**Влияние на нас:**

- Большинство современных embedding-моделей укладываются в 768–1536
  измерений → `vector` достаточно.
- Если RES-002 покажет модель с dim > 2 000 (редко, но возможно для
  multilingual-моделей с расширенным эмбеддингом) — переходим на `halfvec`
  (×2 экономия диска, recall падает на ~0.5–1 п.п. согласно бенчмаркам
  Katz 2024-04-30).
- Расчёт ориентировочного объёма таблицы:
  300 000 объектов × 1024 dim × 4 байта = **~1.2 GB на сырых векторах**
  (без индекса и метаданных). HNSW-индекс ×2–3 от размера данных
  по эмпирическим оценкам.
- Query latency растёт линейно с dim. Для dim=1536 на HNSW p95 ~5–10 ms
  на нашем объёме — приемлемо, но цифру обязательно перепроверить
  на стенде в RES-005.

## 7. DDL через SMP API — открытый вопрос

**Проблема.** В CLAUDE.md зафиксировано: прямого доступа к БД нет, всё
через SMP API. `api.db.query` — read-only HQL. Operations типа
`CREATE INDEX`, `ALTER TABLE`, `REINDEX`, `ANALYZE`, `SET maintenance_work_mem`
через HQL **недоступны**.

**Варианты решения (адресовать DevOps Сахабетдинову):**

1. **DBA-procedure.** DDL выполняет DBA по согласованной runbook-карте.
   Для PoC приемлемо, для production-роутинга индекса — узкое место.
2. **SMP script-метод с `executeUpdate`/JDBC из script-module.** Требует
   подтверждения, что SMP позволяет выполнить arbitrary DDL изнутри JAR
   (с какой ролью соединения, какими правами). По умолчанию это
   нарушает «прямого доступа к БД нет», но script-модуль формально
   ходит через тот же connection pool, что и платформа.
3. **Stored procedure / SQL-функция в БД.** Регистрируется DBA один раз,
   модуль её вызывает. Подходит для инкапсуляции `REINDEX`, `ANALYZE`,
   профилактики IVFFlat. Не подходит для разовых `CREATE INDEX` под
   новую модель эмбеддингов.
4. **Smps-утилита + миграционный SQL.** Аналог Liquibase/Flyway: миграции
   едут вместе с релизом JAR, но DDL применяет DBA-сторона (smps + ручной
   confirm). Лучший кандидат для production.

**Что нужно от DevOps до начала /sa и /dev:**

- Подтвердить, какая опция (1–4) применима на стенде `llm2`.
- Согласовать процедуру миграции индекса при смене модели эмбеддингов
  (см. красную линию в CLAUDE.md: смена размерности → новый ADR + миграция).
- Процедура `REINDEX` (если IVFFlat) или `DROP+CREATE INDEX` для backfill
  HNSW — окно, ответственный, как триггерится из модуля.

## 8. Open questions

| ID | Вопрос | Адресат | Блокер для |
|---|---|---|---|
| OQ-IDX-1 | Какая версия pgvector установлена на `llm2`? Поддерживает ли HNSW (≥ 0.5.0) и halfvec/binary quantization (≥ 0.7.0)? | DevOps (Сахабетдинов) | SA, ADR по индексу |
| OQ-IDX-2 | Какая стратегия DDL допустима через SMP API? (см. секцию 7, варианты 1–4) | DevOps | SA, runbook |
| OQ-IDX-3 | Можно ли получить `maintenance_work_mem` ≥ 2 GB на build HNSW и кто это выставляет (DBA / GUC / per-session)? | DBA через DevOps | Dev (ETA build на стенде) |
| OQ-IDX-4 | Согласовано ли окно для `REINDEX` / `DROP+CREATE INDEX` под backfill? | DevOps + Owner | Operations runbook |
| OQ-IDX-5 | Yandex Cloud FM-модель (RES-002) — нормализованные эмбеддинги? Если да → можно `vector_ip_ops` вместо `vector_cosine_ops` (быстрее). | Researcher (RES-002) | ADR по метрике расстояния |
| OQ-IDX-6 | Какой реальный объём по тенантам на `llm2`? (определяет, тюним под 100k или сразу под 1M+) | BA + Owner | Параметры HNSW |
| OQ-IDX-7 | Допустимо ли держать векторы в той же БД, что и SMP-объекты, или потребуется отдельный schema/tablespace? | DevOps | SA, схема таблицы |
| OQ-IDX-8 | Поведение HNSW-инсёртов в нашей джобе при батч-размере N — нужны smoke-измерения на стенде. | Dev (после первого билда) | Roadmap PoC → MVP |

## Источники (свериться 2026-05-01)

- [pgvector README v0.8.2 (github.com/pgvector/pgvector)](https://github.com/pgvector/pgvector)
- [AWS Database Blog: Optimize generative AI applications with pgvector indexing](https://aws.amazon.com/blogs/database/optimize-generative-ai-applications-with-pgvector-indexing-a-deep-dive-into-ivfflat-and-hnsw-techniques/)
- [Jonathan Katz: The 150× pgvector speedup — a year-in-review (2024-04-30)](https://jkatz05.com/post/postgres/pgvector-performance-150x-speedup/)
- [Mastra Blog: Benchmarking pgvector RAG performance across different dataset sizes](https://mastra.ai/blog/pgvector-perf)
- [Tembo: Vector Indexes in Postgres using pgvector — IVFFlat vs HNSW](https://www.tembo.io/blog/vector-indexes-in-pgvector)
- [Crunchy Data: HNSW Indexes with Postgres and pgvector](https://www.crunchydata.com/blog/hnsw-indexes-with-postgres-and-pgvector)
- [Google Cloud Blog: Faster similarity search performance with pgvector indexes](https://cloud.google.com/blog/products/databases/faster-similarity-search-performance-with-pgvector-indexes)
- [Microsoft Learn: Optimize performance of vector data on Azure Database for PostgreSQL](https://learn.microsoft.com/en-us/azure/postgresql/extensions/how-to-optimize-performance-pgvector)
- [DEV.to: pgvector Distance Functions — Cosine vs L2 vs Inner Product](https://dev.to/philip_mcclarence_2ef9475/pgvector-distance-functions-cosine-vs-l2-vs-inner-product-57pd)
- pgvector issues:
  [#455](https://github.com/pgvector/pgvector/issues/455),
  [#810](https://github.com/pgvector/pgvector/issues/810),
  [#822](https://github.com/pgvector/pgvector/issues/822),
  [#875](https://github.com/pgvector/pgvector/issues/875),
  [#877](https://github.com/pgvector/pgvector/issues/877)
