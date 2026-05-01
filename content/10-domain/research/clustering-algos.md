---
order: 6
title: "Кластеризация векторов: поиск дубликатов и однотипных объектов"
properties:
  - Тип контента: Исследование
  - Фаза: PoC
  - Статус: Draft
---

# Кластеризация векторов: поиск дубликатов и однотипных объектов

> Источники сверены **2026-05-01**. Use case PoC: автоматическое выявление
> дублей `issue` и схожих `problem`. KB-кластеризация (тематическая
> группировка) — отложена до MVP. Объёмы: 100k–1M векторов на тенант,
> размерность эмбеддингов 768–3072 (фактическая — после RES-002).

## 1. Резюме

- Для **near-duplicate detection** на PoC достаточно простого порога
  cosine similarity поверх HNSW (`pgvector`): `sim ≥ 0.92` — кандидат
  на дубликат, `0.85 ≤ sim < 0.92` — «похожий, требует ручной проверки».
  Полноценная кластеризация всей коллекции для use case 3 не нужна —
  достаточно top-K nearest neighbors на новый объект. Это совпадает с
  паттерном «авто-мёрж не делаем, оператор подтверждает» из CLAUDE.md.
- Для **выявления групп однотипных проблем** (батч-режим, периодическая
  джоба «найди кластеры дублей за неделю») рекомендуется **HDBSCAN**:
  не требует заранее знать K, помечает шум, толерантен к разной плотности.
  Перед HDBSCAN — UMAP до 10–20 dim (curse of dimensionality на 768+).
- **K-means / Agglomerative** — отбраковываются: K-means требует K и
  плохо работает с шумом и неравномерными плотностями (а у нас есть
  «большие однородные группы» + «уникальные заявки», которые K-means
  принудительно припишет к ближайшему центроиду).
- **Online-кейс** («новая заявка → к какому кластеру?») решается не через
  online clustering, а через KNN-поиск ближайших + назначение метки
  кластера ближайшего соседа, если `sim ≥ threshold`. BIRCH рассматриваем
  только если потребуется поддерживать «живую» структуру кластеров
  без full rebuild — пока не нужно.
- Метрика качества: **precision/recall** против разметки `issue.duplicates`
  / `duplicatesRL`, проставленной операторами SMP (см. RES-001).

## 2. Сравнение алгоритмов

| Алгоритм | Семейство | Знаем K заранее? | High-dim (768+) | Online (incremental) | Шум | Сложность |
|---|---|---|---|---|---|---|
| **K-means** | centroid | да, обязательно | плохо без редукции | да (mini-batch K-means) | нет, всё в кластеры | O(n·k·i·d) |
| **DBSCAN** | density | нет | страдает от curse of dim | нет (в sklearn); есть Inc-DBSCAN | да (label = -1) | O(n²) худший, O(n log n) с индексом |
| **HDBSCAN** | density + hierarchical | нет | лучше DBSCAN, но всё равно нужен UMAP | нет, нужен full rebuild | да | O(n log n) на практике |
| **OPTICS** | density (reachability) | нет | хуже HDBSCAN, выше memory | нет | да | O(n log n) с индексом |
| **Agglomerative** | hierarchical | опц. (через cutoff) | страдает | нет | нет | O(n²) memory, O(n³) naive |
| **BIRCH** | hierarchical + summary | опц. | средне | **да, single-pass streaming** | нет (или после Phase 4) | O(n) на проход |

**Выводы под наш use case:**
- K-means не подходит из-за обязательного K и отсутствия шума.
- Agglomerative — O(n²) память, для 1M векторов невозможен на стенде.
- OPTICS уступает HDBSCAN по времени и хуже масштабируется на high-dim
  (см. [LinkedIn: HDBSCAN vs OPTICS](https://www.linkedin.com/advice/1/how-do-you-compare-performance-scalability-hdbscan)).
- HDBSCAN — основной кандидат для батчевой кластеризации.
- BIRCH — резерв для online-режима, если потребуется.

## 3. Near-duplicate detection через cosine threshold

Для use case «новая заявка пришла → найди дубликаты» полноценная
кластеризация **избыточна**. Достаточно:

1. Векторизовать новую заявку.
2. Запросить top-K ближайших через HNSW (`<=>` для cosine distance в
   pgvector; `1 - distance = similarity`).
3. Применить пороги:
   - `sim ≥ 0.92` → **дубликат**, предложить оператору слияние.
   - `0.85 ≤ sim < 0.92` → **похожая заявка**, показать в подсказках.
   - `sim < 0.85` → нет совпадения.

**Калибровка порога:**
- 0.95 — слишком жёстко для русскоязычных заявок с разной формулировкой
  одной проблемы (см. [OpenAI community: rule of thumb thresholds](https://community.openai.com/t/rule-of-thumb-cosine-similarity-thresholds/693670)).
- 0.92 — оптимум для гарантированных дубликатов на изображениях/текстах
  (см. [Towards Data Science: find and remove duplicates](https://towardsdatascience.com/find-and-remove-duplicate-images-in-your-dataset-3e3ec818b978/)).
- На PoC: подбираем по `duplicates`-разметке (precision/recall curve).

**Когда простого порога недостаточно и нужен clustering:**
- Когда нужно построить **группы** (3+ дубликата одной проблемы), а не
  пары — например, batch-задача «найди все группы дублей в очереди за
  месяц».
- Когда нужно отделить «уникальные заявки» от «известных частых типов» —
  тут HDBSCAN с метками шума даёт более информативный результат, чем
  серия попарных сравнений.

Для PoC use case 3 (issue + problem) **первая итерация — pure threshold,
clustering — после стабилизации эмбеддингов и сбора feedback**. См.
[Zilliz: embeddings for duplicate detection](https://zilliz.com/ai-faq/how-do-i-use-embeddings-for-duplicate-detection),
[SemHash semantic deduplication](https://github.com/MinishLab/semhash).

## 4. Параметры HDBSCAN

Источник: [HDBSCAN Parameter Selection](https://hdbscan.readthedocs.io/en/latest/parameter_selection.html).

### `min_cluster_size`

Минимальный размер группы, которая считается кластером. Всё мельче
становится шумом.

- **Стартовая эвристика**: 1–2% от размера датасета.
  - 100k заявок → 1000–2000.
  - 1M заявок → 10000–20000.
- **Для коротких текстов (заявки, темы 5–50 слов)**: ставим **меньше** —
  начинаем с `min_cluster_size=5`. Дубликаты часто идут парами/тройками,
  и большие пороги их съедят как шум.
- **Для длинных текстов (KB-статьи, 500+ слов)**: 10–30, тематические
  группы естественно крупнее.
- **Эффект**: больше → меньше кластеров, больше шума.

### `min_samples`

Параметр консервативности. Сколько точек должно быть в окрестности,
чтобы точку считали core.

- **Default**: равен `min_cluster_size`.
- **Рекомендация на практике**: ≈ половина `min_cluster_size`. Например,
  `min_cluster_size=10, min_samples=5`.
- **Для нашего кейса**: `min_samples=2–3` для коротких заявок, `5` для
  KB. Низкий `min_samples` снижает шум, но повышает риск ложных
  под-кластеров.

### `cluster_selection_epsilon`

Объединяет близкие кластеры в один (борьба с фрагментацией в плотных
областях). Зависит от метрики расстояния.

- При cosine distance в нормализованном пространстве разумный диапазон —
  `0.05–0.15` (т.е. «не разделять кластеры, центры которых ближе 0.05–0.15
  по cosine distance»).
- На PoC: оставить `0` (default), включить только если по результатам
  ручной проверки видно фрагментацию похожих групп.

### `cluster_selection_method`

- `'eom'` (default, Excess of Mass) — крупные стабильные кластеры,
  лучше для общей тематики.
- `'leaf'` — много мелких однородных групп, лучше для **поиска
  дубликатов** (наш use case 3 → пробуем `'leaf'`).

См. [How to use cluster_selection_epsilon](https://hdbscan.readthedocs.io/en/latest/how_to_use_epsilon.html).

## 5. High-dimensional issues и редукция размерности

Эмбеддинги Yandex FM (ожидаемо 768–3072 dim) попадают в зону **curse of
dimensionality**: density-based алгоритмы плохо работают, потому что в
high-dim все точки оказываются примерно одинаково далеко друг от друга,
и понятие плотности теряет смысл.

**Когда редукция нужна:**
- **HDBSCAN/DBSCAN на 768+ dim — почти всегда нужна редукция** до
  10–50 dim. Без неё HDBSCAN склонен помечать большую часть точек как
  шум и съедает память.
- Для **просто KNN-поиска (use case near-duplicate)** редукция **не
  нужна** — pgvector HNSW оптимизирован под high-dim, cosine остаётся
  осмысленным благодаря нормализации.

**Что использовать:**
- **PCA** — линейная, быстрая, сохраняет глобальную структуру. На
  бенче GDELT ([PCA vs UMAP for HDBSCAN](https://blog.gdeltproject.org/visualizing-an-entire-day-of-global-news-coverage-technical-experiments-pca-vs-umap-for-hdbscan-t-sne-dimensionality-reduction/))
  PCA-only результаты для HDBSCAN «practically useless» — большинство
  точек идёт в шум.
- **UMAP** — нелинейная, сохраняет локальную структуру, **рекомендована**
  как вход HDBSCAN. Прирост точности до 60% на стандартных датасетах
  ([Allaoui et al., 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7340901/)).
- **PCA → UMAP → HDBSCAN** — компромисс на больших датасетах: PCA до
  ~50 dim сначала (ускоряет UMAP в 5–10×), затем UMAP до 10–20 dim.

**Параметры UMAP под HDBSCAN** ([UMAP clustering guide](https://umap-learn.readthedocs.io/en/latest/clustering.html)):
- `n_neighbors=30` (вместо default 15) — больше глобальной структуры.
- `min_dist=0.0` — упаковываем точки плотно (нужно для density-based).
- `n_components=10–20` — целевая размерность для clustering (не 2 как
  для визуализации).
- `metric='cosine'` — для текстовых эмбеддингов.

**На PoC**: для HDBSCAN-эксперимента — `PCA(50) → UMAP(15) → HDBSCAN`.
Для near-duplicate (порог cosine) — без редукции, прямой KNN в pgvector.

## 6. Online clustering — нужно ли нам?

**Сценарий**: новая заявка пришла → присвоить ей метку кластера или
создать новый, без перерасчёта всей структуры.

**Опции:**

| Алгоритм | Single-pass | Качество | Подходит ли нам |
|---|---|---|---|
| **Online K-means** (mini-batch) | да | посредственное на high-dim | нет (нужен K, нет шума) |
| **BIRCH** | да | хорошее для центроидных, плохое для несферических | резерв |
| **Incremental DBSCAN** (IncGridDBC, 2025) | да | идентичный full DBSCAN | research-уровень, нет зрелых либ |
| **Streaming HDBSCAN** | условно (не в основной либе) | — | нет |
| **KNN + label propagation** | да (тривиально) | хорошее под наш use case | **рекомендация** |

**Решение для PoC:** не делаем online-кластеризацию. Вместо этого:

1. **Батчевая HDBSCAN-джоба** раз в N часов/дней пересобирает кластеры
   на актуальном корпусе (или его срезе — например, последние 3 месяца
   заявок). Метки кластеров пишутся в SMP-атрибут.
2. **На приём новой заявки** работает KNN: ищем top-K ближайших,
   берём метку кластера ближайшего соседа, если `sim ≥ threshold` —
   присваиваем; иначе — «без кластера, ждём следующей пересборки».

Это эквивалент **micro-batch + lazy assignment** и отлично ложится на
архитектуру «джоба по расписанию» из CLAUDE.md (sync-векторизация —
out of scope PoC).

BIRCH стоит рассмотреть только если в ходе MVP станет ясно, что
пересборка HDBSCAN на 1M векторов не укладывается в окно джобы. См.
[BIRCH: scikit-learn](https://scikit-learn.org/stable/modules/generated/sklearn.cluster.Birch.html),
[BIRCH original paper](https://www2.cs.sfu.ca/CourseCentral/459/han/papers/zhang96.pdf).

## 7. Ground truth и evaluation

**Источник разметки:** атрибуты `issue.duplicates` и `issue.duplicatesRL`
(reverse link) — операторы SMP помечают заявки как дубликаты вручную.
Это **готовый ground truth для use case 3**, доступный без отдельной
разметочной кампании. Подтвердить выгрузку и долю размеченных заявок —
RES-001.

**Метрики (parity с industry-стандартом near-dup):**

- **Precision @ threshold T**: из всех пар, помеченных алгоритмом как
  дубликат при `sim ≥ T`, какая доля действительно в `duplicates`.
- **Recall @ threshold T**: из всех известных пар-дубликатов в SMP,
  какую долю алгоритм нашёл при `sim ≥ T`.
- **F1 / Precision-Recall curve** по сетке T = [0.80, 0.85, 0.90, 0.92, 0.95].
- **Cluster-level метрики** (для HDBSCAN): Adjusted Rand Index, V-measure
  относительно меток операторов (нескольких заявок-дубликатов одной
  проблемы → одинаковая «настоящая метка»).

**Подводный камень:** разметка `duplicates` — **incomplete**. Оператор
видит только то, что нашёл сам. Реальный recall может быть выше «нашего»
recall'а по этой метрике (модель находит дубликаты, которые операторы
пропустили). Это нормально — в evaluation report фиксируем как
ограничение.

## 8. Open questions

| # | Вопрос | Адресат | Зачем нужно |
|---|---|---|---|
| 1 | Размерность эмбеддингов Yandex FM (768 / 1024 / 3072?) | RES-002 (`/research`) | определяет необходимость PCA-pre-step |
| 2 | Доля заявок с проставленным `duplicates` / `duplicatesRL` в выгрузке RES-001 | `/research` (RES-001) | пригодность ground truth для evaluation |
| 3 | Допустимо ли оператору видеть «similar items» с порогом 0.85 (низкий precision, высокий recall) или нужен только high-precision (0.92+)? | BA (Демьянов) | калибровка дефолтного порога в UI-подсказках |
| 4 | Окно для batch-кластеризации: всё, последние N месяцев, по типам заявок? | BA + SA | объём для HDBSCAN, нужно ли шардировать по типу `issue` |
| 5 | Хранить ли cluster_id в SMP-атрибуте объекта или в отдельной vector-таблице? | SA (ADR) | зависит от частоты пересборки и read-pattern UI |
| 6 | Java/Groovy-реализация HDBSCAN: вызов через нативную либу, отдельный сервис на Python, или порт? | SA + Dev | архитектурное решение PoC vs MVP |
| 7 | Нужен ли auto-merge дубликатов с порога 0.98+ или только manual confirm всегда? | BA + product owner | UX и риски ложных слияний |
| 8 | Для `problem` объёмы существенно меньше, чем для `issue` — нужна ли отдельная стратегия? | BA + SA | возможно, для problem хватит pure-threshold без HDBSCAN |

## Источники

- [HDBSCAN Parameter Selection](https://hdbscan.readthedocs.io/en/latest/parameter_selection.html)
- [HDBSCAN: combining with DBSCAN via epsilon](https://hdbscan.readthedocs.io/en/latest/how_to_use_epsilon.html)
- [scikit-learn DBSCAN](https://scikit-learn.org/stable/modules/generated/sklearn.cluster.DBSCAN.html)
- [scikit-learn HDBSCAN](https://scikit-learn.org/stable/modules/generated/sklearn.cluster.HDBSCAN.html)
- [scikit-learn BIRCH](https://scikit-learn.org/stable/modules/generated/sklearn.cluster.Birch.html)
- [UMAP for clustering](https://umap-learn.readthedocs.io/en/latest/clustering.html)
- [Allaoui et al., 2020 — UMAP improves clustering up to 60%](https://pmc.ncbi.nlm.nih.gov/articles/PMC7340901/)
- [GDELT: PCA vs UMAP for HDBSCAN](https://blog.gdeltproject.org/visualizing-an-entire-day-of-global-news-coverage-technical-experiments-pca-vs-umap-for-hdbscan-t-sne-dimensionality-reduction/)
- [Zilliz: embeddings for duplicate detection](https://zilliz.com/ai-faq/how-do-i-use-embeddings-for-duplicate-detection)
- [SemHash — semantic deduplication](https://github.com/MinishLab/semhash)
- [OpenAI community: cosine similarity thresholds](https://community.openai.com/t/rule-of-thumb-cosine-similarity-thresholds/693670)
- [BIRCH original paper (Zhang et al., 1996)](https://www2.cs.sfu.ca/CourseCentral/459/han/papers/zhang96.pdf)
- [IncGridDBC — incremental DBSCAN with grid (2025)](https://www.sciencedirect.com/science/article/abs/pii/S0925231225021320)
- [HDBSCAN vs OPTICS scalability](https://www.linkedin.com/advice/1/how-do-you-compare-performance-scalability-hdbscan)
- [BERTopic parameter tuning (UMAP+HDBSCAN reference pipeline)](https://maartengr.github.io/BERTopic/getting_started/parameter%20tuning/parametertuning.html)
