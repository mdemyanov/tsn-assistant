---
order: 1
title: Источники research
properties:
  - Тип контента: Исследование
  - Фаза: PoC
  - Статус: Draft
---

# Источники research проекта pg_vector_service

Реестр источников, которые `/research` тянет до того, как BA/SA начнут писать. Каждый источник → один файл-выжимка в `content/10-domain/research/`.

## Бэклог research-задач Phase 0

| ID | Статус | Тема | Артефакт |
|----|:------:|------|----------|
| RES-001 | ✅ done | Метамодель `issue`, `knowledgeBase`, `problem` (live через MCP) | [smp-metamodel.md](smp-metamodel.md) |
| RES-002 | ✅ done | Yandex Cloud Foundation Models — embedding-модели | [yc-foundation-models.md](yc-foundation-models.md) — закрыт live-проверкой 2026-05-01: `text-search-doc` + `text-search-query`, dim=256, modelVersion `06.12.2023`. Решение в [ADR-010](../../00-project/adr/010-embedding-model-selection.md) |
| RES-003 | ✅ done | Бюджет: стоимость эмбеддинга для медианы и максимума объёма | [yc-pricing.md](yc-pricing.md) — owner вручную выгрузил прайс с `aistudio.yandex.ru` 2026-05-01. Эмбеддинг 0,0101 ₽ / 1 тыс. юнитов, медиана PoC ≈ 200 ₽/тенант, верхняя граница ≈ 50 500 ₽. На 2 порядка дешевле rough estimate. |
| RES-004 | ✅ done | pgvector — индексы (HNSW vs IVFFlat), тюнинг, лимиты | [pgvector-indexes.md](pgvector-indexes.md) — допущение: pgvector ≥0.8.x (свежий) |
| RES-005 | ✅ done | Similarity search — метрики качества и ground truth в SMP | [similarity-eval.md](similarity-eval.md) |
| RES-006 | ✅ done | Кластеризация на векторах: DBSCAN/HDBSCAN, near-duplicate threshold | [clustering-algos.md](clustering-algos.md) |
| RES-007 | ✅ done | Naumen SMP — scheduled tasks через `api.scheduler` | [smp-scheduled-jobs.md](smp-scheduled-jobs.md) |
| RES-008 | ✅ done | Эталон проекта `naumen-smp-mcp` — что копировать, что адаптировать | [reference-project-notes.md](reference-project-notes.md) |
| RES-009.1 | ✅ done | Domain & data analysis для стратегии хранения векторов (волна 1): распределение длин на llm2, матрица UC×класс×payload, реестр FQN | [vector-storage-domain.md](vector-storage-domain.md) — закрыт 2026-05-01. Рекомендация: стратегия D (hybrid: issue/A + KB/C) |
| RES-009.2 | ✅ done | Сравнение стратегий хранения (волна 2): матрица 5×8 dimensions, закрытие 10 OQ, DDL skeleton, эскалации BA/PM | [vector-storage-strategies.md](vector-storage-strategies.md) — закрыт 2026-05-01. Deferred: smoke OQ-8 (лимит токенов YC FM — ожидает owner'а) |

**Допущения для перехода в `/ba`** (зафиксированы owner'ом 2026-05-01):
- pgvector на стенде `llm2` свежий (≥0.8.x), HNSW поддерживается.
- Бюджет YC FM рассчитываем позже, когда будет `yc` CLI и доступ к pricing API.
- RES-002 закрывается на оставшиеся пункты (modelUri, размерность, лимиты, цены) сразу как появится `yc`.

## Регламент

- Один research-таск = один файл в `content/10-domain/research/`.
- Артефакт research содержит: краткое резюме (3-5 строк), факты с ссылками, открытые вопросы (если есть).
- При появлении новой темы — дописывается строка в эту таблицу через `/pm`.
- Findings, требующие архитектурного решения, → SA создаёт ADR со ссылкой на research-файл.
