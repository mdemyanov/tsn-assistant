---
order: 90
title: "ADR-009: Decision frame for embedding model (deferred)"
properties:
  - Тип контента: ADR
  - Фаза: PoC
  - Статус: Draft
---

# ADR-009: Decision frame for embedding model (deferred)

**Status:** Draft
**Date:** 2026-05-01

## Context

Выбор конкретной embedding-модели Yandex Cloud Foundation Models (имя, версия, размерность вектора, прайс) — ключевое архитектурное решение для PoC: от него зависят размер pgvector-таблицы, тип индекса (NFR-012, ADR на pgvector-index — отдельная сессия), бюджет YC FM (NFR-061, RES-003), детерминизм идемпотентности (UC1 / NFR-020 через `model_version`).

Однако на 2026-05-01 данные для решения **не получены**:
- `yc-foundation-models.md` § 1: «Документация YC FM закрыта от автоматических краулеров. Все URL вида `yandex.cloud/ru/docs/foundation-models/*` отдают 301 → защищённый CAPTCHA хост `aistudio.yandex.ru`. В рамках бюджета research'а (5 WebFetch) ни одна из 4 страниц по Foundation Models не была получена».
- Все таблицы моделей / лимитов / цен в research отмечены `❌ источник заблокирован, верифицировать вручную`.
- `yc` CLI ещё не настроен (CLAUDE.md § План запуска / Phase 0.5 — на стороне owner'а).

Принимать архитектурное решение «выбираем модель X с размерностью Y и pin'ом версии Z» **прямо сейчас** означает либо guess, либо повторение неверифицированных предыдущих сведений. Оба варианта нарушают NFR-042 (`modelUri` фиксируется в ADR с явным обоснованием).

При этом `/dev` нельзя блокировать на сутки/неделю до получения данных — в проекте есть бэклог независимых задач (whitelist-конфиг, pgvector-storage skeleton, scheduler, тесты ядра), которые делаются на mock-провайдере (`FakeEmbeddingProvider` из ADR-001).

## Decision

**Выбор конкретной embedding-модели YC FM откладывается** до получения данных через `yc` CLI (CLAUDE.md / Phase 0.5) или ручной выгрузки документации owner'ом с раскрытием CAPTCHA-заблокированных страниц.

Этот ADR фиксирует **decision frame** — критерии и процедуру выбора, чтобы при появлении данных решение принималось **быстро и трассируемо**, без новой research-сессии и без переоткрытия дискуссии.

### Критерии выбора (приоритет — нисходящий)

1. **Поддержка русского языка** (must-have). Корпус SMP — русскоязычный (`smp-metamodel.md`); модель без качественной поддержки русского отбраковывается без обсуждения.
2. **Размерность вектора** — приоритет диапазону **256–1024**. Обоснование: HNSW pgvector эффективен в этом диапазоне (`pgvector-indexes.md` § 3); меньшая размерность (128) — обычно ниже качество для русского; большая (3072+) — ×4–×12 storage и память индекса (NFR-012, риск выхода за ресурсы стенда `llm2`).
3. **Стоимость за 1k токенов** — должна укладываться в бюджет PoC. Конкретное значение бюджета — RES-003 (открытый вопрос, NFR-061 / OQ-6); оценочная цена по `yc-foundation-models.md` § 4 — `0.20–0.30 ₽/1k токенов` (rough estimate, требует verify).
4. **Latency на single embedding** — `< 1 с` p95. Обоснование: для UC2 NFR-001 (черновой бюджет 200 мс на end-to-end) embedding-вызов составляет существенную часть бюджета; для UC3 NFR-001 (online ≤ 2 с) — критичен при ad-hoc embedding (UC3 / Q7).
5. **Batch API** — желательно (но не must-have). Обоснование: UC1 / NFR-022 — джоба обрабатывает сотни тысяч объектов; batch снижает overhead на N/batch_size раз. Если batch для embeddings отсутствует — fallback на параллельные синхронные вызовы с rate limiter'ом (`yc-foundation-models.md` § 3).
6. **Дифференциация `text-search-doc` vs `text-search-query`** — preferred. Обоснование: asymmetric retrieval даёт «ощутимый прирост relevance vs single-model при том же бюджете токенов» (`yc-foundation-models.md` § 1); UC2 free-text (FR-002) и UC3 ad-hoc embedding естественно укладываются в pattern «doc для индексации, query для запросов».

### Процедура

1. **Закрытие RES-002.** Researcher (или owner вручную при разблокировании страниц) заполняет матрицу моделей по критериям 1–6.
2. **Расчёт RES-003.** На основе цены за 1k токенов и оценок объёма текста (RES-001) — расчёт PoC-бюджета.
3. **SA выпускает ADR-XXX** в течение 1 рабочего дня (с пометкой `supersedes ADR-009`). В новом ADR — конкретные `modelUri` (с pinned версией, не `latest` — для воспроизводимости), размерность, обоснование выбора по критериям decision frame'а.
4. **Phase 0.5 → ADR-XXX → /dev iter 1.** Только после ADR-XXX на конкретную модель Dev может перейти от mock-embedding-провайдера к реальному адаптеру YC FM.

### Что фиксировано **до** появления ADR-XXX

- Тип-контракт `EmbeddingProviderPort` (ADR-001) — **не зависит** от выбора модели. Изменение модели на этапе PoC — замена адаптера в `adapters/yc/`, ядро не трогается.
- Поле `model_version` в записи pgvector (ADR-007) — обязательное; формат `{modelUri}@{pinned_version}` финализируется в ADR-XXX (зависит от того, как YC FM выдаёт версии).
- Размерность `vector(N)` в pgvector-таблице — фиксируется в момент DDL первой таблицы; миграция при смене размерности — по ADR-007.
- Алгоритм UC3 (ADR-008) и формула композита (ADR-006) — **не зависят** от модели; пороги `0.92` / `0.85` калибруются на ground truth `issue.duplicates` независимо от выбора.

### Mock-режим для Dev (до закрытия)

Dev iter 1 стартует с `FakeEmbeddingProvider` (детерминированный fake — например, hash → R^256 / нормализация), что позволяет:
- Покрыть unit-тестами ядро UC1/UC2/UC3 без сети.
- Прогнать smoke на стенде `llm2` с тестовой векторной таблицей (без расхода YC FM).
- Замерить overhead pgvector / SMP API / scheduler без зависимости от внешнего сервиса.

Замена fake → real embedding-адаптера — атомарная (одна строка в `config/`-сборке, ADR-001 composition root) после выпуска ADR-XXX.

## Consequences

**Positive:**
- **Трассируемость**: при появлении данных решение фиксируется с явной ссылкой на критерии, не «ad-hoc выбор по интуиции».
- **Быстрый close-out**: ADR-XXX выпускается за 1 рабочий день, не превращается в недельную дискуссию.
- **Dev iter 1 не заблокирован**: можно делать ядро, тесты, pgvector-storage skeleton, whitelist-инфру на mock-провайдере.
- **Соответствие NFR-042** (фиксация `modelUri` в ADR) — без преждевременного guess'а.

**Negative:**
- **Dev iter 1 не имеет real embeddings**: smoke на стенде `llm2` с реальной моделью — отложен до ADR-XXX. Получение первых реальных векторов на корпусе — задерживается на интервал «Phase 0.5 → ADR-XXX».
- **Риск, что mock-embedding скрывает интеграционные баги** YC FM-адаптера: контракт `EmbeddingProviderPort` тестируется fake'ом, но real-adapter может иметь специфики (timeout, IAM-token-обмен, format payload), которые проявятся только в первой реальной интеграции.
- **Возможность повторного отложения**: если данные не появятся в Phase 0.5, decision frame этого ADR превращается в «вечную ссылку», что нарушает обязательство NFR-042 фиксации.

**Mitigations:**
- **Контракт-тест `EmbeddingProviderPort`** (Dev iter 1) — общий для fake и для будущего real-adapter; позволяет сразу проверить real-adapter на тех же тестовых случаях, что и fake.
- **Сценарный smoke** на стенде `llm2` (UC1 fixture) — запускается на mock-embedding в Dev iter 1, **повторно** на real-embedding после ADR-XXX (паттерн «перезапуск smoke после смены адаптера»).
- **Hard deadline** для закрытия RES-002: если данные не получены через 5 рабочих дней — owner ставит в backlog задачу «ручная сверка страниц YC FM с раскрытым CAPTCHA + outbound-выгрузка»; этот ADR не конвертируется в постоянное решение, RES-002 — обязательно закрывается до /pm-review PoC.
- **Резервный сценарий**: если YC FM окажется неприемлемым по бюджету (NFR-061) — переход на on-prem embedding-модель (например, через отдельный адаптер). Это другая ADR-цепочка; здесь упоминается как option of last resort для трассировки.

## Alternatives Considered

Альтернативы по существу отсутствуют — это явно **deferred decision**, а не выбор между моделями. Все «альтернативы» в этой плоскости — это варианты процедуры закрытия:

- **Принять решение «вслепую»** на текущих неверифицированных данных (`text-search-doc/latest` 256-dim). Отвергнуто: нарушает NFR-042 (`modelUri` фиксируется в ADR с обоснованием), создаёт риск, что выпущенный ADR будет supersede'нут через неделю при появлении реальных данных, портит audit-trail.
- **Заблокировать /dev iter 1** до получения данных. Отвергнуто: бэклог Dev iter 1 имеет существенный объём независимой от модели работы (whitelist, storage, scheduler, тесты ядра); блокировка приведёт к простою команды.
- **Использовать `latest` без pin'а версии в первом ADR-XXX.** Отвергнуто как отдельная альтернатива (а не вариант текущего ADR): `latest` ломает воспроизводимость — любой rebuild индекса на новой версии модели даст другие координаты (`yc-foundation-models.md` § 2). Pin обязателен для NFR-030 / NFR-042.

## Связанные статьи

- [UC1 — Scheduled vectorization](../../30-requirements/functional/uc1-scheduled-vectorization) — FR-009 (версионирование модели), NFR-UC1-002 (бюджет YC FM), бриф для SA / Зависимости от research (RES-002, RES-003).
- [UC2 — Similarity search](../../30-requirements/functional/uc2-similarity-search) — Q2 (метрика расстояния — производна от выбора модели), NFR-001 (latency бюджет).
- [UC3 — Duplicate detection](../../30-requirements/functional/uc3-duplicate-detection) — Q7 (ad-hoc embedding регистрируемой заявки) — частично разрешается выбором модели (есть batch / latency).
- [Cross-cutting NFR](../../30-requirements/non-functional/nfr-cross-cutting) — NFR-005 (IAM/Api-Key), NFR-013 (чанкинг — лимит зависит от модели), NFR-042 (фиксация `modelUri` в ADR), NFR-061 (бюджет YC FM).
- [YC Foundation Models](../../10-domain/research/yc-foundation-models) — § 1 (резюме, что неясно), § 2 (модели), § 3 (лимиты), § 4 (цена), § 5 (auth).
- [PgVector indexes](../../10-domain/research/pgvector-indexes) — § 3 (HNSW зависит от размерности), § 3.1 (параметры) — формирует критерий 2 (размерность).
- [Sources](../../10-domain/research/sources) — RES-002 / RES-003 — бэклог research, который должен закрыть owner.
- [ADR-001: Hexagonal layout](001-hexagonal-architecture) — `EmbeddingProviderPort` независим от выбора модели; mock-режим возможен по архитектуре.
- [ADR-005: Whitelist + PII default-deny](005-whitelist-pii-default-deny) — `whitelist_version` как часть `composite_hash` независим от модели.
- [ADR-006: Composite text composition](006-composite-text-composition) — формула композита независима от модели; truncation-лимит зависит от модели (open question этого ADR).
- [ADR-007: Model versioning + migration](007-model-versioning-migration) — описывает процедуру supersede; этот ADR — её первая точка входа.
- [ADR-008: Near-duplicate algorithm](008-near-duplicate-algorithm) — пороги калибруются на ground truth независимо от выбора модели; супер-ADR при смене модели — отдельная процедура (ADR-007).
