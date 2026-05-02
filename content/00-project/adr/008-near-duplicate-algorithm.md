---
order: 80
title: "ADR-008: Near-duplicate algorithm (cosine threshold for PoC)"
properties:
  - Тип контента: ADR
  - Фаза: PoC
  - Статус: Draft
---

# ADR-008: Near-duplicate algorithm (cosine threshold for PoC)

**Status:** Draft
**Date:** 2026-05-01

## Context

UC3 (`content/30-requirements/functional/uc3-duplicate-detection.md`) закрывает два смежных сценария:
- **Сценарий А (online)** — на форме регистрации заявки оператор видит до 5 ближайших по семантике уже зарегистрированных `issue` с метками `Дубль` / `Похожая` (FR-001…FR-008).
- **Сценарий Б (batch)** — еженедельная джоба формирует отчёт «N кандидатов на слияние» с группами потенциально однотипных `issue` и `problem` (FR-009…FR-014).

Из research `clustering-algos.md` § 1 / § 3 следует прямая рекомендация для PoC: «для near-duplicate detection достаточно простого порога cosine similarity поверх HNSW (`pgvector`): `sim ≥ 0.92` — кандидат на дубликат, `0.85 ≤ sim < 0.92` — похожий, требует ручной проверки. Полноценная кластеризация всей коллекции для UC3 не нужна — достаточно top-K nearest neighbors на новый объект».

Из требований:
- **UC3 / FR-003** — пороги `Дубль ≥ 0.92`, `Похожая 0.85…0.92` (черновые), кандидаты ниже `0.85` не возвращаются.
- **UC3 / FR-016 + FR-017** — финальные пороги фиксируются по итогам offline-eval на сетке `T ∈ {0.80, 0.85, 0.90, 0.92, 0.95}`.
- **UC3 / NFR-001** — online latency p95 ≤ 2 с (silent skip при превышении, FR-008).
- **UC3 / NFR-003** — batch-окно ≤ 4 ч на корпусе сотен тысяч векторов; превышение — пересмотр алгоритма с резервным путём HDBSCAN+UMAP (`clustering-algos.md` § 1).
- **UC3 / NFR-004 + NFR-005** — precision уровня `Дубль` ≥ 0.80, recall ≥ 0.50 на ground truth `issue.duplicates` / `duplicatesRL` (BR-002).
- **UC3 / BR-001** — никакого автомёрджа в PoC; подтверждение всегда — оператором или аналитиком.

ADR-001 (Hexagonal layout) уже фиксирует `core/` как место для алгоритмической логики; HNSW/pgvector — через `VectorStoragePort` в `adapters/smp/`. Этот ADR закрывает алгоритм, а не storage (storage — отдельный ADR).

## Decision

**Для UC3 PoC** принимается алгоритм **cosine-threshold поверх HNSW** для обоих сценариев (с разными режимами агрегации).

**Сценарий А (online).** При регистрации новой заявки `issue`:
1. Вычислить эмбеддинг `composite_text` регистрируемой заявки (через `EmbeddingProviderPort`, ADR-001; путь «ad-hoc embedding vs lazy» — отдельный ADR на UC3 / Q7).
2. Запросить top-K через HNSW-индекс (`VectorStoragePort`), `K=10` (запас над `N=5` для UC3 / FR-001 на случай выпадания кандидатов из-за ACL и фильтров).
3. Применить фильтры: исключить сам объект-источник (FR-004), применить ACL пользователя (FR-005), отбросить кандидатов в финальных «нерабочих» статусах (UC2 / FR-009 в качестве паттерна).
4. Применить пороги (черновые до offline-eval):
    - `cosine_similarity ≥ 0.92` → метка **`Дубль`**;
    - `0.85 ≤ cosine_similarity < 0.92` → метка **`Похожая`**;
    - `cosine_similarity < 0.85` → не возвращать.
5. Сократить выдачу до `N ≤ 5` (FR-001).

**Сценарий Б (batch-аудит).** Раз в установленную частоту (UC3 / Q4, в первой итерации — еженедельно):
1. Выгрузить векторы за окно (FR-010, по умолчанию — последние 90 дней по дате регистрации).
2. **Pairwise-режим** (baseline): для каждого `issue` вычислить top-K (K=10) ближайших; сформировать пары `(a, b)` с `cosine_similarity ≥ 0.92`; объединить пары в группы транзитивным замыканием (union-find).
3. Группы, целиком покрытые существующими `issue.duplicates` / `duplicatesRL` — помечаются как «известные» (FR-012), но не удаляются.
4. Сформировать отчёт «N кандидатов на слияние» (FR-011, FR-013); никаких автоматических связываний (BR-001).

**Калибровка порогов** — по offline-eval на ground truth `issue.duplicates` (UC3 / FR-016) на сетке `T ∈ {0.80, 0.85, 0.90, 0.92, 0.95}`. По итогам первой Dev-итерации SA выпускает supersede-ADR с финальными значениями (UC3 / FR-017). До тех пор используются стартовые `0.92` / `0.85`.

**Резервный путь HDBSCAN+UMAP** (для batch / Сценария Б, не для online):
- Триггер активации: precision уровня `Дубль` на pairwise-baseline на стенде `llm2` < `0.80` (UC3 / NFR-004) при offline-eval, или batch-джоба не укладывается в `NFR-003` (4 ч) на полном корпусе.
- Процедура: UMAP до 10–20 dim → HDBSCAN с `min_cluster_size=5` (для коротких текстов, `clustering-algos.md` § 4); параметры — отдельный ADR при активации.
- В PoC резервный путь **не реализуется** в коде — фиксируется только триггер активации и план перехода. Реализация — отдельный backlog-item.

**Online clustering и BIRCH** в PoC — не рассматриваются (`clustering-algos.md` § 1: «BIRCH рассматриваем только если потребуется поддерживать живую структуру кластеров без full rebuild — пока не нужно»).

**Никакого автомёрджа** (UC3 / BR-001). Архитектура **не имеет** записи в `issue.duplicates` / `issue.duplicatesRL` со стороны pg_vector_service в PoC. Подтверждение и фактическое связывание — действие оператора (Сценарий А) или аналитика (Сценарий Б) средствами SMP.

## Consequences

**Positive:**
- **Простота**: один и тот же алгоритм (cosine-threshold) для UC2 (top-K similarity) и UC3 (near-duplicate). Переиспользует существующую инфраструктуру HNSW, не вводит новых зависимостей (`clustering-algos.md` § 3 — «полноценная кластеризация избыточна»).
- **Быстрое получение результатов на PoC**: можно проверить гипотезу «эмбеддинги YC FM + cosine-threshold достаточны» на корпусе `llm2` за дни, а не недели.
- **Соответствие UC3 / NFR-001 (online latency ≤ 2с)**: HNSW top-K на 100k–300k векторах укладывается в десятки миллисекунд (`pgvector-indexes.md` § 3.1), запас на ad-hoc embedding и SMP-обвязку — большой.
- **Аудитопригодность**: точные пороги фиксируются в записи отчёта (UC3 / NFR-008, AC-010), результат воспроизводим по `embedding_model_id` + `thresholds`.

**Negative:**
- **Порог не адаптивен**: единые пороги `0.92` / `0.85` для всех подклассов `issue` — упрощение. На практике для коротких заявок `subject` («Не работает VPN») порог `0.92` может быть жёстким, для длинных `description` — мягким (UC3 / Q6 для `problem`, Q10 для high-precision подклассов).
- **Не строит многоэлементные группы напрямую**: для Сценария Б группы создаются транзитивным замыканием пар, что может «сшивать» слабо связанные группы при наличии «моста» (одной заявки, близкой к двум разным кластерам). HDBSCAN такого недостатка не имеет, но включается только по триггеру.
- **Тюнинг руками**: при росте корпуса на стенде ситуация с порогами может меняться; нужна периодическая калибровка через offline-eval.
- **Зависимость от качества `issue.duplicates` как ground truth**: UC3 / Q9 — доля заявок с проставленным `duplicates` на `llm2` неизвестна; при низком coverage метрики precision/recall могут быть нерепрезентативны.

**Mitigations:**
- **Offline-eval после первой Dev-итерации UC3** (UC3 / FR-016): прогон на сетке порогов, выпуск supersede-ADR с финальными значениями. Если на классе `problem` пороги отличаются от `issue` — два отдельных набора порогов в конфиге (UC3 / Q6).
- **План перехода на HDBSCAN+UMAP** зафиксирован в этом ADR (триггер + процедура); не нужно переписывать архитектуру при росте объёмов или провале baseline.
- **Pairwise → groups transitive closure** обмежается: размер группы capped (например, ≤ 50 объектов в одной группе на отчёт), при превышении — группа splits на «слабые мосты» через минимальное cosine_similarity внутри группы (детали — в отдельной задаче на /research после первой итерации).
- **Coverage `issue.duplicates`** проверяется в первой Dev-итерации (RES-005 / UC3 Q9); при недостаточном coverage — переход на качественную проверку аналитиком на нескольких группах (UC3 / BR-007).

## Alternatives Considered

- **K-means** для Сценария Б. Отвергнуто (`clustering-algos.md` § 2): требует знать K заранее, плохо работает с шумом и неравномерными плотностями (а у нас «большие однородные группы» + «уникальные заявки»), плохо в high-dim без редукции.
- **DBSCAN на full-dim эмбеддингах** (без UMAP). Отвергнуто (`clustering-algos.md` § 2): curse of dimensionality на 256+, density-based алгоритмы деградируют на high-dim; HDBSCAN с UMAP — строго лучший выбор, если переходим к density-based.
- **Online clustering (BIRCH)** для Сценария А. Отвергнуто (`clustering-algos.md` § 1): «BIRCH рассматриваем только если потребуется поддерживать живую структуру кластеров без full rebuild — пока не нужно». Online cluster assignment для одной новой заявки — это и есть KNN+threshold, что мы и делаем.
- **Жёсткий порог `≥ 0.95` без `Похожая`-уровня** (UC3 / Q5: оставить только `Дубль`). Сохраняется как опт-ин: BA может по итогам smoke решить, что `Похожая` создаёт шум для оператора. Этот ADR оставляет двухуровневую систему как baseline, supersede при необходимости.
- **HDBSCAN+UMAP сразу как baseline.** Отвергнуто для PoC: «полноценная кластеризация избыточна» (`clustering-algos.md` § 3) для случая «новая заявка → найди дубликаты»; существенный engineering-overhead (UMAP + HDBSCAN + параметры + offline-tuning) при недоказанной нужности на этапе PoC.

## Связанные статьи

- [UC3 — Duplicate detection](../../30-requirements/functional/uc3-duplicate-detection) — JTBD, FR-001…FR-017, NFR-001…NFR-008, BR-001…BR-007, AC-001…AC-010 (полностью покрывается этим ADR в части алгоритма; ad-hoc vs lazy embedding — отдельный ADR).
- [UC2 — Similarity search](../../30-requirements/functional/uc2-similarity-search) — переиспользует ту же HNSW-инфраструктуру; NFR-001 (latency) — общий бюджет.
- [Cross-cutting NFR](../../30-requirements/non-functional/nfr-cross-cutting) — NFR-007 (идемпотентность batch), NFR-011 (latency similarity), NFR-050 (метрики).
- [Clustering algorithms](../../10-domain/research/clustering-algos) — § 1 (резюме рекомендаций), § 2 (сравнение алгоритмов), § 3 (near-duplicate через cosine-threshold), § 4 (параметры HDBSCAN — резерв).
- [Similarity evaluation](../../10-domain/research/similarity-eval) — методика offline-eval для калибровки порогов.
- [SMP метамодель](../../10-domain/research/smp-metamodel) — `issue.duplicates` / `duplicatesRL` как ground truth, `problem.issues` как сильный сигнал.
- [PgVector indexes](../../10-domain/research/pgvector-indexes) — § 3.1 (HNSW-параметры, обоснование latency-бюджета).
- [ADR-001: Hexagonal layout](001-hexagonal-architecture) — алгоритм живёт в `core/`, не в `adapters/`.
- [ADR-006: Composite text composition](006-composite-text-composition) — формула композита для ad-hoc embedding регистрируемой заявки.
- [ADR-007: Model versioning + migration](007-model-versioning-migration) — пороги привязываются к `model_version` в записи отчёта (UC3 / AC-010).
