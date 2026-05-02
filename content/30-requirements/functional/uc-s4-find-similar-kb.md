---
order: 14
title: "UC-S4 — Поиск похожих KB-статей"
properties:
  - Тип контента: Требование
  - Фаза: PoC
  - Статус: Draft
  - Сценарий: E-KB
---

# UC-S4 — Поиск похожих KB-статей

> **Supersedes:** `content/30-requirements/functional/uc2-similarity-search.md` (split, KB-режим).
> Трассируемость: UC2.AC-1..14 → UC-S4.AC-001..014 (KB-сценарий).

## JTBD

### JTBD-1. Автор статьи KB

Когда автор готовит к публикации новую KB-статью, я (автор / редактор KB) хочу до публикации увидеть список семантически похожих уже существующих статей, чтобы избежать дубликатов в базе знаний, переиспользовать или дополнить существующую статью и сохранить навигационную целостность раздела.

### JTBD-2. Оператор Service Desk (cross-class подсказка)

Когда оператор работает с заявкой и ищет инструкцию или решение, я (оператор Service Desk) хочу получить список KB-статей, семантически близких к описанию заявки, чтобы быстро найти пошаговую инструкцию или обходное решение без ручного поиска по разделам KB.

## Описание

UC-S4 — семантический поиск похожих KB-статей. Это KB-специфичная проекция UC-S1: source может быть `issue` (cross-class) или free-text, target — всегда `knowledgeBase$article`.

**Ключевая особенность — chunked KB.** KB-статьи хранятся в pgvector в виде чанков (UC-V1, стратегия C). Поиск идёт по chunk-векторам (chunk_kind='chunk' или 'summary'); агрегация — по `parent_id` (parent document retrieval, max-similarity strategy из RES-009.2 §3).

**ACL.** KB-статьи имеют per-object ACL через `kbAccesses`. Фильтрация post-aggregation: сначала GROUP BY parent_id, затем ACL-фильтр по списку `parent_id`.

## Функциональные требования

- **FR-001. Поиск по объекту.** Запрос: `{source_id, source_meta_class, K}`. Если источник — `issue` (cross-class): берётся атрибутный вектор issue, ищется в KB-чанках. Если источник — `knowledgeBase$article` (same-class): то же самое.
- **FR-002. Free-text поиск.** Запрос: `{text, K}`. Embedding через `text-search-query`, поиск в KB-чанках.
- **FR-003. Параметр K.** Default = 10. Диапазон ≤ 100.
- **FR-004. Алгоритм parent-document retrieval.** Внутренний oversample: K×5 chunk-векторов → GROUP BY parent_id → MIN(dist) per parent → top-K parents → ACL-фильтр. SQL-паттерн из RES-009.2 §2.1.
- **FR-005. ACL по kbAccesses.** Post-aggregation: после GROUP BY — Java-фильтр по `parent_id` через SMP kbAccessChecker. Если после фильтра результатов < K — возвращается partial result (допустимо для PoC).
- **FR-006. Фильтр статусов.** По умолчанию — только опубликованные (`closed`-статус исключается). `include_closed=true` — опциональный параметр.
- **FR-007. Исключение source.** Если source — `knowledgeBase$article I`, то `I` исключается из выдачи.
- **FR-008. Поля в ответе.** `object_id`, `meta_class='knowledgeBase$article'`, `score` (min-dist из chunk-агрегации), `title` (опционально, из SMP API).
- **FR-009. Ошибки.** `VectorNotReady` (вектор источника не построен), `FaqVectorsNotAvailable` (KB-индекс пуст). Без stack-trace.
- **FR-010. Логирование.** `correlationId`, K, `latencyMs`, `resultCount`. Текст запроса не пишется.

## Нефункциональные требования

- **NFR-S4-001. Latency p95.** Ожидаемый бюджет — как UC-S1 для KB-режима: 1 SQL (CTE GROUP BY) + 1 ACL-check (SMP API) ≈ 25–80 ms + overhead. Итого ≤ 500 ms. Финальный — после smoke в ADR.
- **NFR-S4-002. Качество (черновой).** Recall@10 ≥ 0.80 на KB-eval (методология `similarity-eval.md`). Финальные пороги — после offline-eval.
- **NFR-S4-003. ACL-инвариант.** Пользователь не получает KB-статьи, к которым у него нет доступа по `kbAccesses` (BR-002).
- **NFR-S4-004. Тенант-изоляция.** KB другого тенанта не возвращаются.

## User Journey

### Journey-1. Автор KB перед публикацией

1. Автор готовит черновик новой KB-статьи. В форме — кнопка «Найти похожие».
2. UI отправляет free-text запрос: `{text=title+content_preview, K=10}`.
3. UC-S4 строит embedding через `text-search-query`, ищет в KB-чанках (oversample 5×), GROUP BY, ACL, top-10.
4. UI показывает список похожих статей со ссылками и score.
5. Автор решает: публиковать новую, дополнить существующую или вложить как раздел.

### Journey-2. Оператор — cross-class поиск из заявки

1. Оператор открывает заявку `I`. UI запрашивает UC-S1 (получает похожие issue + KB + problem).
2. KB-часть ответа UC-S1 опирается на UC-S4 internals (cross-class: issue vector → KB chunks).
3. Оператор видит блок «Связанные статьи KB» и переходит по ссылке.

## Бизнес-правила

- **BR-001. Источник должен быть в whitelist.** Запрос «по объекту» только для векторизованных FQN. Иначе — `SourceNotVectorized`.
- **BR-002. kbAccesses обязателен.** Фильтрация post-aggregation, по `parent_id` (не по chunk_id). Реализация: Java-фильтр после SQL GROUP BY (RES-009.2 §5).
- **BR-003. Source не в выдаче.** KB-статья-источник исключается из выдачи.
- **BR-004. PII в логах.** Текст запроса не логируется.
- **BR-005. Rollup: max-similarity.** MIN(dist) per parent — стандарт parent-document-retrieval (LangChain, LlamaIndex), зафиксирован в ADR-012 как default для PoC.

## Доменные события

- **KbSearchRequested** (`source`, `K`, `correlationId`) — запрос принят.
- **KbSearchCompleted** (`correlationId`, `resultCount`, `latencyMs`) — обработан.
- **KbSearchFailed** (`correlationId`, `errorCode`) — ошибка.

## Acceptance Criteria

- [ ] **AC-001.** Запрос по `issue` (cross-class) возвращает top-K KB-статей (K=10 по умолчанию).
- [ ] **AC-002.** Free-text запрос возвращает непустой список на репрезентативной выборке запросов.
- [ ] **AC-003.** ACL: пользователь без доступа к KB-разделу `S` не получает статьи из `S`; с доступом — получает (BR-002, NFR-S4-003). Проверяется тестовым аккаунтом.
- [ ] **AC-004.** Source KB-статья `I` не возвращается в результатах same-class запроса.
- [ ] **AC-005.** Объекты в статусе `closed` не возвращаются по умолчанию; `include_closed=true` включает их.
- [ ] **AC-006.** При отсутствии вектора источника — `VectorNotReady`, не пустой список.
- [ ] **AC-007. Latency (черновой).** p95 ≤ 500 ms на корпусе 113 KB-статей (~390 чанков с overlap 10 %). Финальный — в ADR после smoke.
- [ ] **AC-008. Качество (черновой).** Recall@10 ≥ 0.80 на KB-offline-eval. Финальный порог — в ADR.
- [ ] **AC-009.** Логи содержат `correlationId`, `latencyMs`, `resultCount`; не содержат полный текст запроса.
- [ ] **AC-010.** Ошибки без stack-trace в теле ответа.

## Открытые вопросы

| ID | Вопрос | Кому |
|----|--------|------|
| Q1 | Rollup: max-sim vs mean-pool vs first-chunk — подтвердить на offline-eval (OQ-1 RES-009.2). | SA → ADR-012 |
| Q2 | Оверсэмпл-фактор для KB: 5× достаточно при ACL-ограниченных коллекциях? | SA → ADR |
| Q3 | KB-статьи с `chunk_total > 1` — нужна ли специальная пометка в ответе («статья содержит N страниц»)? | BA + Owner |
| Q4 | Нужна ли возможность поиска только по summary-чанку (chunk_index=0) для быстрого режима? | BA + SA |

## Бриф для SA

**Требование:** `content/30-requirements/functional/uc-s4-find-similar-kb.md`
**Фаза:** PoC

**Спроектировать:**
- SQL-паттерн: CTE с GROUP BY parent_id + MIN(dist) → Java ACL-фильтр (RES-009.2 §2.1 + §5).
- Rollup strategy (BR-005): max-similarity как default, pending offline-eval (ADR-012).
- ACL-механизм: Java-фильтр по parent_id через SMP kbAccessChecker (Step 2 из RES-009.2 §5).
- Оверсэмпл: K × 5, параметризуем.

**Бизнес-правила для валидаций:** BR-001, BR-002 (kbAccesses post-aggregation), BR-003, BR-005.

**AC для проверки архитектуры:** AC-003 (ACL), AC-006 (VectorNotReady), AC-007/AC-008 (latency/quality).
