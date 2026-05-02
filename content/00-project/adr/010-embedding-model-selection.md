---
order: 100
title: "ADR-010: Выбор embedding-модели Yandex Cloud Foundation Models"
properties:
  - Тип контента: ADR
  - Фаза: PoC
  - Статус: Draft
---

# ADR-010: Выбор embedding-модели Yandex Cloud Foundation Models

**Status:** Draft (закрывает decision frame [ADR-009](009-embedding-model-decision-frame.md))
**Date:** 2026-05-01

## Context

[ADR-009](009-embedding-model-decision-frame.md) зафиксировал critical-frame для выбора embedding-модели и отложил решение до получения данных через `yc` CLI и smoke-тестов. 2026-05-01 эти блокеры закрыты:

- Установлен `yc` CLI, создан сервисный аккаунт `pg-vector-poc` (`aje98ipgmpnhaun6ov6e`) с ролью `ai.languageModels.user` на folder `applied-office` (`b1g249mrsql00khlmvcs`).
- Сгенерирован API-Key, сохранён в `.secrets/yc-api-key.json` (chmod 600, gitignored).
- Smoke-тесты подтвердили работу embedding API: `https://llm.api.cloud.yandex.net/foundationModels/v1/textEmbedding`.

Verified data — см. [yc-foundation-models.md](../../10-domain/research/yc-foundation-models.md).

В Yandex Cloud Foundation Models на 2026-05-01 доступны **две асимметричные** embedding-модели для русского языка:

| modelUri | Назначение | Размерность | modelVersion |
|----------|------------|:-----------:|:------------:|
| `emb://<folder-id>/text-search-doc/latest` | Индексация документов | 256 | `06.12.2023` |
| `emb://<folder-id>/text-search-query/latest` | Свободные поисковые запросы | 256 | `06.12.2023` |

Применение критериев из ADR-009:

| Критерий | Оценка text-search-doc + text-search-query |
|----------|---------------------------------------------|
| Поддержка русского (must) | ✅ нативная |
| Размерность 256-1024 (priority) | ✅ 256 — нижняя граница, оптимальна для HNSW и памяти |
| Стоимость (priority) | TBD — ручная сверка прайса (RES-003) |
| Latency single embedding < 1s p95 | ✅ smoke ~150ms на тест-фразу (вне нагрузки) |
| Batch API | ❌ только single text per request |
| Дифференциация doc vs query | ✅ — два URI, асимметричный retrieval |

## Decision

**Принимаем:**

1. **Размерность вектора фиксируется = 256.** В pgvector-таблице (см. [ADR-004](004-vector-storage-schema.md)) колонка `embedding` имеет тип `vector(256)`.
2. **Используем обе модели — асимметрично:**
   - **`text-search-doc/latest`** — для всех векторизаций SMP-объектов в фоновой джобе (UC1: `knowledgeBase`, `problem`, `issue`).
   - **`text-search-query/latest`** — только для embedding'а свободного текста запроса в UC2 (FR-002 «free-text similarity»).
   - Для UC2 «найти похожие на этот объект» (FR-001) — НЕ делаем повторный embedding объекта; используем уже сохранённый вектор из таблицы (он рассчитан через `text-search-doc`).
   - Для UC3 (cosine threshold) — оба объекта в сравнении уже векторизованы через `text-search-doc`; асимметрия не используется.
3. **modelVersion `06.12.2023` фиксируется** в каждой записи `VectorRecord.model_version` (формат: `text-search-doc:06.12.2023`). При появлении новой версии модели — миграция через [ADR-007](007-model-versioning-migration.md).
4. **Authentication для PoC — API-Key**, для production — IAM-token (через [NFR-005](../../30-requirements/non-functional/nfr-cross-cutting.md) ротации). Конкретный механизм рефреша IAM-token — отдельное решение DevOps (runbook).
5. **HNSW параметры под dim=256** — `m=16, ef_construction=64` (defaults, рекомендация [pgvector-indexes.md](../../10-domain/research/pgvector-indexes.md) для медианы 100k-300k и размерности ≤512). Operator class — `vector_cosine_ops`.
6. **Composite text для эмбеддинга** — соблюдает контракт [ADR-006](006-composite-text-composition.md). Минимальная длина текста — non-empty (API возвращает `code 3 "empty text"`); CompositeTextComposer должен фильтровать пустые/whitespace-only тексты.

## Consequences

**Positive:**
- Размерность 256 — оптимальный баланс: малый размер индекса HNSW (256 × 4 байта × 1M ≈ 1 GB), быстрый recall, меньше памяти на стенде `llm2`.
- Асимметрия doc/query — улучшает качество retrieval для UC2 free-text (доказанный приём в IR; см. [similarity-eval.md](../../10-domain/research/similarity-eval.md)).
- API-Key для PoC — простая аутентификация, можно гонять прямо из Groovy без процедуры рефреша.
- Single API endpoint — простая интеграция.

**Negative:**
- Только single text per request — для batch-векторизации на 100k+ объектов нужен concurrent dispatcher с N потоками. RPS-лимит TBD.
- Нет CLI команды `yc ai foundation-models embedding list` в актуальной версии CLI (0.140.x) — мониторинг новых моделей через смены modelVersion в smoke-проверках.
- Документация YC FM закрыта CAPTCHA — обновления отслеживать через release notes Yandex Cloud (по доступным каналам), не через WebFetch.
- Цены не верифицированы — RES-003 budget блокирован до ручной сверки.

**Mitigations:**
- DEV-задача: `EmbeddingClient` использует пул потоков для batch-режима, начнём с N=4, тюнинг — по итогам iter 1 smoke (NFR-022 chunked job).
- Periodic verification: ежемесячный smoke-тест — проверять что `modelVersion` не изменился (auto-tracking в DEVOPS-005 алёрт).
- Бюджет: первичный rough estimate 4-20 тыс. ₽/тенант (см. yc-foundation-models.md §Цена); финал — после ручной выгрузки прайса owner'ом, → RES-003.

## Alternatives Considered

- **Использовать только одну модель `text-search-doc` для всего** (включая query embedding'и). Отклонено: асимметрия документально улучшает MRR на 5-15% (см. similarity-eval.md §3) — небольшой gain бесплатно.
- **Symmetric model (если YC выпустит)** — на 2026-05-01 в наличии только doc/query пара; пересматриваем в новом ADR при появлении.
- **Альтернативные провайдеры (OpenAI, Cohere, multilingual-e5 self-hosted)** — отклонены: (a) outbound в OpenAI/Cohere заблокирован; (b) self-hosted требует отдельной инфры (out of scope PoC); (c) контекст проекта — Yandex Cloud по решению owner.
- **Размерность > 256** — недоступна (Yandex предоставляет фиксированный 256). При появлении модели бóльшей размерности — пересмотр в новом ADR.

## Связанные статьи

- Закрывает: [ADR-009 — Decision frame for embedding model](009-embedding-model-decision-frame.md)
- Уточняет: [ADR-004 — Vector storage schema](004-vector-storage-schema.md) (фиксирует `vector(256)`)
- Зависит от: [ADR-006 — Composite text composition](006-composite-text-composition.md), [ADR-007 — Model versioning migration](007-model-versioning-migration.md)
- Research: [yc-foundation-models.md](../../10-domain/research/yc-foundation-models.md), [pgvector-indexes.md](../../10-domain/research/pgvector-indexes.md), [similarity-eval.md](../../10-domain/research/similarity-eval.md)
- BA: [UC1](../../30-requirements/functional/uc1-scheduled-vectorization.md), [UC2](../../30-requirements/functional/uc2-similarity-search.md), [UC3](../../30-requirements/functional/uc3-duplicate-detection.md), [NFR cross-cutting](../../30-requirements/non-functional/nfr-cross-cutting.md)
- Дочерний для: [Принципиальная архитектура](../../40-architecture/principal-architecture.md)
