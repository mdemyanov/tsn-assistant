# 30-requirements — Требования

Функциональные и нефункциональные требования с JTBD и Acceptance Criteria.

> **Обновление BA-002 (2026-05-01):** каталог расширен с 3 UC до 9 UC. UC1/UC2/UC3 помечены `[SUPERSEDED]` — заменены новыми. Трассируемость: UC1 → UC-V1 + UC-V2; UC2 → UC-S1 + UC-S2 + UC-S3 + UC-S4; UC3 → UC-C1 + UC-C2.
>
> **Обновление BA-003 (2026-05-01):** применены рекомендации ITSM-mini-review (`content/10-domain/itsm-reviews/ba-002-full-catalog-review.md`). Изменения: UC-S2 переработан по Variant B (closing/resolution comment precondition); UC-S3 scope narrowing (JTBD-2/3 deferred to MVP/Pilot); UC-S1/UC-C1 добавлены post-PoC ITSM-метрики (MTTR, FCR/Duplicate Detection KPI); UC-V1 аннотирован по decisionReport; NFR-075 помечен как неполный до OQ-V2-2; glossary дополнен ITIL-mapping и KB Article lifecycle.
>
> **Обновление BA-004.1 (2026-05-02):** addendum к BA-004 — закрыты 6 owner-decisions по Open OQ (OQ-1..4 NFR, OQ-C1-3, OQ-CL-1); OQ-5 NFR переведён в `In Research (RES-011)`. Все pre-existing OQ по NFR закрыты или переданы в research. Добавлена задача RES-011 (YC FM batch/async API).

## Структура

- `functional/` — функциональные требования (UC-V*, UC-S*, UC-C*)
- `non-functional/` — NFR (производительность, безопасность, доступность, preprocessing)

## Правила

- Создаёт BA через `/ba new-requirement <slug>`.
- Каждое требование содержит JTBD и Acceptance Criteria.
- Все статьи имеют properties: Тип контента=Требование, Фаза, Статус (см. `.doc-root.yaml`).

---

## Каталог UC (актуальный, после BA-002)

### Векторизация (UC-V*)

| ID | Название | Payload | Сценарий | Статус | Файл |
|----|----------|---------|----------|--------|------|
| UC-V1 | Векторизация атрибутов SMP-объектов | composite_extended из whitelist-атрибутов (`subject`, `description`, `decisionReport`, KB.content и др.) | A-Workload | Draft | `functional/uc-v1-vectorize-attributes.md` |
| UC-V2 | Векторизация комментариев | `comment.text` (per-comment вектор, `chunk_kind='related'`, `parent_id` → объект-родитель) | A-Workload | Draft | `functional/uc-v2-vectorize-comments.md` |

**Ключевые различия UC-V1 vs UC-V2:**

| Аспект | UC-V1 | UC-V2 |
|--------|-------|-------|
| Payload | whitelist-атрибуты объекта | `comment.text` |
| Кардинальность | 1 вектор (issue/problem) или N чанков (KB) на объект | N векторов на объект (1 per comment) |
| Хранение | `chunk_kind='object'/'chunk'/'summary'` | `chunk_kind='related'`, `parent_id` → объект |
| ACL | по самому объекту | наследуется от родителя (NFR-070) |
| Статус PoC | Первый к реализации | Деferred, ждёт OQ-V2-1 (sign-off) |

---

### Семантический поиск (UC-S*)

| ID | Название | Вход | Сценарий | Статус | Файл |
|----|----------|------|----------|--------|------|
| UC-S1 | Найти похожие заявки (по атрибутам) | FQN-объект или free-text | F-Patterns | Draft | `functional/uc-s1-find-similar-issues.md` |
| UC-S2 | Найти похожие заявки (по комментариям) | FQN-объект | F-Patterns | Draft | `functional/uc-s2-find-similar-by-comments.md` |
| UC-S3 | Найти похожий FAQ / статью KB | Свободный текст пользователя (10–50 слов) | E-KB | Draft | `functional/uc-s3-find-similar-faq.md` |
| UC-S4 | Найти похожие KB-статьи | FQN-объект или free-text | E-KB | Draft | `functional/uc-s4-find-similar-kb.md` |

**Зависимости поиска:**

```
UC-S1 — зависит от UC-V1 (атрибутные векторы issue/KB/problem)
UC-S2 — зависит от UC-V2 (comment-векторы); feature-flag; отдельный latency-бюджет p95 ≤ 1 000 ms
UC-S3 — зависит от UC-V1 (KB-векторы); text-search-query для запроса; cutoff 0.75
UC-S4 — зависит от UC-V1 (KB chunking); parent-document retrieval (GROUP BY parent_id + MIN(dist))
```

---

### Кластерный анализ (UC-C*)

| ID | Название | Сигнал | Сценарий | Статус | Файл |
|----|----------|--------|----------|--------|------|
| UC-C1 | Кластеризация по описанию | composite_extended (UC-V1) | F-Patterns | Draft | `functional/uc-c1-cluster-by-description.md` |
| UC-C2 | Кластеризация по описанию + комментариям | w1 × issue_cosine + w2 × comment_agg_cosine | F-Patterns | Draft | `functional/uc-c2-cluster-by-description-comments.md` |

**Зависимости кластеризации:**

```
UC-C1 — зависит от UC-V1; online и batch-audit режимы; thresholds Дубль/Похожая
UC-C2 — зависит от UC-V1 + UC-V2; combined signal; fallback на UC-C1 для объектов без комментариев
```

---

## Mapping старых UC → новые (трассируемость)

| Старый UC | Статус | Заменён на | Трассируемость AC |
|-----------|--------|------------|-------------------|
| UC1 — Scheduled Vectorization | **Superseded** | UC-V1 (атрибуты) + UC-V2 (комментарии) | UC1.AC-001..014 → UC-V1.AC-001..016 |
| UC2 — Similarity Search | **Superseded** | UC-S1 (issue) + UC-S2 (по коммент.) + UC-S3 (FAQ) + UC-S4 (KB) | UC2.AC-1..14 → UC-S1.AC-001..014 |
| UC3 — Duplicate Detection | **Superseded** | UC-C1 (по описанию) + UC-C2 (описание + коммент.) | UC3.AC-001..010 → UC-C1.AC-001..010 |

Файлы устаревших UC сохранены с пометкой `[SUPERSEDED]` в заголовке и предупреждающим блоком.

---

---

## История волн доработки

| Волна | Дата | Содержание | Источник |
|-------|------|-----------|---------|
| BA-001 | 2026-05-01 | Инициализация каталога: 3 исходных UC (UC1, UC2, UC3) | PM init |
| BA-002 | 2026-05-01 | Расширение до 9 UC: UC-V1/V2, UC-S1..S4, UC-C1/C2 + NFR (cross-cutting, preprocessing). Трассируемость старых UC сохранена. | BA-002 волна |
| BA-003 | 2026-05-01 | ITSM-mini-review: Critical/Major/Minor/Nit фиксы + 5 OQ-ITSM для owner-decision. Scope-narrowing UC-S2/S3, post-PoC KPI для UC-S1/C1, MCP-верификация comment-метамодели. | `content/10-domain/itsm-reviews/ba-002-full-catalog-review.md` |
| BA-004 | 2026-05-02 | Фиксация 45 owner-decisions по всем OQ (BA-002+BA-003+ITSM-ревью). Создание задач BA-005 (FAQ-класс), SA-001 (архитектура comment-таблиц), RES-010 (распределение комментариев). Закрыты OQ-ITSM-1..5, OQ-V1-1..6, OQ-V2-1/3/4 + COMMENT-DELETE/EDIT, OQ-S2-1..5, OQ-S3-1..4, OQ-C1-1/2/4/5/6, OQ-PROBLEM-DATA, OQ-CL-2/3/4, OQ-6..10 NFR, OQ-PRE-1..4, OQ-Role-1..5. | owner-decisions Демьянов |
| BA-004.1 | 2026-05-02 | Addendum к BA-004: 6 owner-decisions по Open OQ. Закрыты OQ-1 (disk-resident), OQ-2 (PoC без окна; Production ≤ 6 ч), OQ-3 (Prometheus+Grafana), OQ-4 (40 RPS rate-limit), OQ-C1-3 (out of scope → API `clusters_audit`), OQ-CL-1 (default 50/50). OQ-5 переведён в `In Research (RES-011)`. Добавлена RES-011 (YC FM batch/async API). | owner-decisions Демьянов |

---

## Решения owner'а 2026-05-02 (BA-004)

Все решения зафиксированы в соответствующих UC/NFR-файлах. Консолидированная таблица.

### OQ-ITSM (из ITSM-ревью BA-003)

| ID | Статус | Решение | Локация |
|----|--------|---------|---------|
| OQ-ITSM-1 | **Resolved (2026-05-02)** | JTBD-2/3 — не в scope pg_vector_service в принципе (модуль = API, UX = caller). Метка «deferred MVP/Pilot» снята. | UC-S3 |
| OQ-ITSM-2 | **Resolved (2026-05-02)** | Вариант C — не делать Major Incident filter в PoC, в backlog MVP. | UC-S1 |
| OQ-ITSM-3 | **Resolved (2026-05-02)** | Вариант C — UC-S2 без pre-filter по comment_kind в PoC. Future фича MVP+. | UC-S2 OQ-S2-5 |
| OQ-ITSM-4 | **Resolved (2026-05-02)** | Sign-off получен: все комментарии разрешены. OQ-V2-5 (PII-mask) — defer to MVP. | UC-V2 OQ-V2-1 |
| OQ-ITSM-5 | **Resolved (2026-05-02)** | FAQ-класс — TBD, создана задача BA-005. Вероятный Вариант A. | `functional/uc-faq-class-design.md` |

### Новые задачи из BA-004

| Задача | Описание | Файл |
|--------|----------|------|
| **BA-005** | Проектирование FAQ-класса: JTBD, схема атрибутов (question+answer+links), ITSM best-practice, согласование с Сахабетдиновым | `functional/uc-faq-class-design.md` |
| **SA-001** | Архитектурная аналитика: per-class partitioning vs single table для comment-векторов. Cost/benefit: индекс, latency, ACL-фильтрация | Задача для SA |
| **RES-010** | Анализ распределения числа комментариев на issue/problem (max, p95, p99, mean) на llm2. Пересмотр default cap=50 | Задача для Researcher |

### Новые задачи из BA-004.1 (addendum)

| Задача | Описание | Файл |
|--------|----------|------|
| **RES-011** | YC FM batch/async API для embeddings: проверка наличия, лимитов, применимость к bulk-init. Дополнение к RES-002 (OQ-5 NFR → In Research). Артефакт: `content/10-domain/research/yc-fm-batch-api.md` | Задача для Researcher |

### Консолидированная таблица всех resolved OQ (BA-004)

| ID | Решение (краткое) | Файл |
|----|-------------------|------|
| OQ-V1-1 | 1 000 ₽/день | `uc-v1-vectorize-attributes.md` |
| OQ-V1-2 | Ручной запуск → ежедневно ночью | `uc-v1-vectorize-attributes.md` |
| OQ-V1-3 | chunk_size=2 048 (smoke-подтверждение) | `uc-v1-vectorize-attributes.md` |
| OQ-V1-4 | low+medium PII открыты для PoC | `uc-v1-vectorize-attributes.md` |
| OQ-V1-5 | PoC scope = issue + KB + faq; problem → Pilot | `uc-v1-vectorize-attributes.md` |
| OQ-V1-6 | Системный пользователь; запрос Сахабетдинову | `uc-v1-vectorize-attributes.md` |
| OQ-V2-1 | Все комментарии разрешены | `uc-v2-vectorize-comments.md` |
| OQ-V2-3 | cap=50 (conservative), пересмотр после RES-010 | `uc-v2-vectorize-comments.md` |
| OQ-V2-4 | Последние N по дате (`creationDate DESC`) | `uc-v2-vectorize-comments.md` |
| OQ-COMMENT-DELETE | SMP-event trigger (async) | `uc-v2-vectorize-comments.md` |
| OQ-COMMENT-EDIT | SMP-event trigger (async) | `uc-v2-vectorize-comments.md` |
| OQ-S2-1 | max-similarity для PoC | `uc-s2-find-similar-by-comments.md` |
| OQ-S2-2 | cross-mode не делаем в PoC | `uc-s2-find-similar-by-comments.md` |
| OQ-S2-3 | oversample=5× | `uc-s2-find-similar-by-comments.md` |
| OQ-S2-4 | молча исключить заявки с 0 комментариев | `uc-s2-find-similar-by-comments.md` |
| OQ-S2-5 | scope-down: без pre-filter в PoC | `uc-s2-find-similar-by-comments.md` |
| OQ-S3-1 | threshold=0.75 | `uc-s3-find-similar-faq.md` |
| OQ-S3-2 | только `question_text` | `uc-s3-find-similar-faq.md` |
| OQ-S3-3 | поиск по `question_id` не поддерживаем в PoC | `uc-s3-find-similar-faq.md` |
| OQ-S3-4 | pre-condition ≥ 50 FAQ | `uc-s3-find-similar-faq.md` |
| OQ-C1-1 | defaults: Дубль=0.92, Похожая=0.85 | `uc-c1-cluster-by-description.md` |
| OQ-C1-2 | окно=90 дней | `uc-c1-cluster-by-description.md` |
| OQ-C1-4 | cosine-threshold pairwise | `uc-c1-cluster-by-description.md` |
| OQ-C1-5 | silent skip | `uc-c1-cluster-by-description.md` |
| OQ-C1-6 | оба уровня: Дубль + Похожая | `uc-c1-cluster-by-description.md` |
| OQ-PROBLEM-DATA | problem → defer to Pilot | `uc-c1-cluster-by-description.md` |
| OQ-CL-2 | max-similarity aggregation | `uc-c2-cluster-by-description-comments.md` |
| OQ-CL-3 | UC-C2 → defer to MVP | `uc-c2-cluster-by-description-comments.md` |
| OQ-CL-4 | cosine-threshold pairwise | `uc-c2-cluster-by-description-comments.md` |
| OQ-6 (NFR) | 1 000 ₽/сутки | `nfr-cross-cutting.md` |
| OQ-7 (NFR) | logger.info (не FQN) | `nfr-cross-cutting.md` |
| OQ-8 (NFR) | native scheduledTask state, defer to /sa | `nfr-cross-cutting.md` |
| OQ-9 (NFR) | системный пользователь | `nfr-cross-cutting.md` |
| OQ-10 (NFR) | IAM-токен с JWT-обменом | `nfr-cross-cutting.md` |
| OQ-PRE-1 | decision-by-evidence (Mixed baseline сохраняется) | `nfr-preprocessing.md` |
| OQ-PRE-2 | URL остаются; OQ-FUTURE-2 на MVP | `nfr-preprocessing.md` |
| OQ-PRE-3 | emoji оставить | `nfr-preprocessing.md` |
| OQ-PRE-4 | flexmark-java default; SA подтверждает Maven mirror | `nfr-preprocessing.md` |
| OQ-Role-1 | reactive | `roles/itsm-analyst.md` |
| OQ-Role-2 | нет web-search | `roles/itsm-analyst.md` |
| OQ-Role-3 | только itsm-reviews (PoC) | `roles/itsm-analyst.md` |
| OQ-Role-4 | Sonnet default + Opus on-demand | `roles/itsm-analyst.md` |
| OQ-Role-5 | конвенции в промте + itsm-knowledge.md | `roles/itsm-analyst.md` |

### Open OQ (решение не дано owner'ом, остаются в работе)

| ID | Описание | Assignee | Блокирующая фаза |
|----|----------|----------|-----------------|
| OQ-V2-2 | Точный список `excluded_comment_meta_classes` на llm2 | SA + Сахабетдинов | PoC (UC-V2) |
| OQ-5 (NFR) | YC FM batch/async API для embeddings — передано в **RES-011** | Researcher | PoC / MVP |
| OQ-FUTURE-1 | Unit economics calculation | Owner / PM | MVP |
| OQ-FUTURE-2 | URL/PII-mask в preprocessing | BA + SA | MVP |
| OQ-V2-5 | PII-mask для comment.text | BA + SA | MVP |

### Resolved OQ (addendum BA-004.1, 2026-05-02)

| ID | Решение (краткое) | Файл |
|----|-------------------|------|
| OQ-1 (NFR) | Disk-resident. PostgreSQL shared-стенд, память не перегружать. | `nfr-cross-cutting.md` |
| OQ-2 (NFR) | PoC — по запросу; Production/Pilot+ — ночное окно ≤ 6 ч. | `nfr-cross-cutting.md` |
| OQ-3 (NFR) | Prometheus + Grafana доступны на llm2. | `nfr-cross-cutting.md` |
| OQ-4 (NFR) | YC FM RPS-квота — до 40 RPS. Rate-limiter обязателен. | `nfr-cross-cutting.md` |
| OQ-C1-3 | Out of scope модуля. Модуль = API `clusters_audit()`. Caller формирует отчёт. | `uc-c1-cluster-by-description.md` |
| OQ-CL-1 | Default 50/50 (`w1=0.5, w2=0.5`). Calibrate post-MVP offline-eval. | `uc-c2-cluster-by-description-comments.md` |

---

## Нефункциональные требования (non-functional/)

| Файл | Содержание |
|------|-----------|
| `nfr-cross-cutting.md` | Сквозные NFR: безопасность, производительность, надёжность, совместимость, observability, ACL комментариев (NFR-070..075) |
| `nfr-preprocessing.md` | Политика нормализации текста: Mixed strategy (plain для issue/comment, markdown для KB.content), pipeline, algorithm_version, версионирование |

---

## UC-матрица зависимостей

```
UC-V1 (атрибуты) ←── UC-S1, UC-S3, UC-S4, UC-C1
UC-V2 (комментарии) ←── UC-S2, UC-C2
```

Все поисковые и кластерные UC работают на векторах, созданных UC-V1/UC-V2. Запуск UC-S*/UC-C* до завершения соответствующей волны векторизации возвращает ошибку `VectorNotReady`.
