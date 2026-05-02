---
order: 12
title: "UC-S2 — Поиск заявок со схожими комментариями"
properties:
  - Тип контента: Требование
  - Фаза: PoC
  - Статус: Draft
  - Сценарий: F-Patterns
---

# UC-S2 — Поиск заявок со схожими комментариями

> **Новый UC.** Не покрывался UC2. Зависит от UC-V2 — реализуется после sign-off на `comment.text` в whitelist (OQ-V2-1).
>
> **BA-003 (2026-05-01):** переработан по итогам ITSM-mini-review (BA-003-C1, Variant B). JTBD-1 переформулирован: фокус на closing/resolution комментарии агента, не на произвольные discussion-реплики. JTBD-2 удалён из этого UC (аналитический кластерный сценарий находится в UC-C2). Добавлен precondition comment_kind. Результаты MCP-проверки метамодели `comment` зафиксированы в OQ-S2-5.

## JTBD

### JTBD-1. Оператор Service Desk

Когда оператор находит в заявке комментарий-резюме агента (написанный при закрытии заявки или содержащий root cause / диагностические данные), я (оператор Service Desk) хочу найти все заявки, где в переписке обсуждался тот же root cause, чтобы быстро получить список кейсов с аналогичным диагнозом и готовыми решениями — без ручного перебора очереди.

<note type="info">

**Обоснование scope-narrowing (BA-003-C1):** ни один из лидирующих ITSM-вендоров (ServiceNow, BMC Helix, Zendesk, Moogsoft) не строит поиск похожих инцидентов по единичному произвольному discussion-комментарию. Ценный single-comment signal — только resolution note / closing comment / комментарий с диагностическими данными (стек-трейс, код ошибки). KCS v6 классифицирует промежуточные комментарии как «discussion threads» — шум с точки зрения knowledge content. Источники: `content/10-domain/research/itsm-similarity-search-patterns.md` §2, §5; ITSM-ревью `ba-002-full-catalog-review.md` §2.4.

</note>

## Описание

UC-S2 ищет похожие заявки по **векторам комментариев**, а не атрибутов. В отличие от UC-S1 (атрибутный поиск), UC-S2 работает с вектором `chunk_kind='related'` — комментарными строками таблицы `pg_vector_service__vectors`.

**Ключевая особенность — агрегация на уровне заявки.** Один `issue` может иметь до 15 комментариев (p95). Если несколько комментариев одной заявки попали в top-K по сходству, заявка возвращается в выдаче **один раз** (дедупликация по `parent_id`). Ранжирование заявок — по максимальной similarity среди её комментариев (max-sim aggregation, OQ-S2-1).

**Precondition comment_kind (PoC scope-down, Resolved OQ-S2-5 / OQ-ITSM-3, 2026-05-02):** в PoC UC-S2 работает по любому комментарию без pre-filter по comment_kind. Pre-filter по типу комментария (closing/resolution vs discussion) — будущая фича MVP+, требует расширения SMP-метамодели или эвристики. Рекомендация остаётся в контексте: для discussion-реплик с низкой информационной плотностью результаты могут быть менее точными.

**Зависимость от UC-V2:** UC-S2 работает только при наличии комментарных векторов. Без UC-V2 поиск возвращает пустой список с кодом `CommentVectorsNotAvailable`.

**ACL:** фильтрация по доступу к родительской заявке (`parent_id`), не по доступу к комментарию напрямую.

## Функциональные требования

- **FR-001. Поиск по комментарию.** Запрос: `{comment_id, parent_meta_class='issue', K}`. Модуль берёт вектор комментария `C`, ищет top-(K×oversample) похожих comment-векторов, агрегирует по `parent_id`, возвращает top-K уникальных заявок. **Precondition:** поиск по `comment_id` наиболее эффективен для closing/resolution комментариев (комментарий содержит root cause, диагностику или итог решения). Для discussion-реплик — UC-S1 является более подходящим сценарием (OQ-S2-5).
- **FR-002. Поиск по тексту.** Запрос: `{text, target_meta_class='issue', K}`. Embedding через `text-search-query` (ADR-010), поиск в comment-векторах, агрегация по `parent_id`.
- **FR-003. Дедупликация.** Если N комментариев одной заявки попали в oversample-результат, заявка возвращается один раз с max-similarity среди этих N (BR-001).
- **FR-004. Параметр K.** Default = 10. Диапазон — как в UC-S1 (≤ 100). Oversample factor = 5× (внутренний параметр).
- **FR-005. ACL по parent-объекту.** Из выдачи исключаются заявки, к которым у пользователя нет доступа (проверка по `parent_id` через SMP API). Фильтрация post-aggregation (BR-002).
- **FR-006. Исключение source-заявки.** Если источник — `comment_id` из заявки `I`, заявка `I` исключается из выдачи (аналогично UC-S1 FR-007).
- **FR-007. Поля в ответе.** Каждая запись: `object_id` (issue), `meta_class`, `max_score` (максимальный cosine similarity среди комментариев), `matching_comment_count` (сколько комментариев заявки попало в oversample).
- **FR-008. Ошибки.** Если comment-векторов для целевого класса нет — `CommentVectorsNotAvailable`. Если комментарий-источник не векторизован — `VectorNotReady`. Оба без stack-trace.
- **FR-009. Логирование.** `correlationId`, `targetMetaClass`, K, `latencyMs`, `resultCount`. Полный текст запроса в лог не пишется.

## Нефункциональные требования

- **NFR-S2-001. Latency p95.** Ожидаемый бюджет — выше чем UC-S1 из-за GROUP BY и оверсэмплинга. Черновой бюджет: p95 ≤ 1 000 ms (2× от UC-S1, RES-009.2 §7 Dimension-7 D-режим: 2 round-trips ≈ 25–80 ms + SMP overhead). Финальный — после smoke-замера, в ADR.
- **NFR-S2-002. Оверсэмпл.** При K=10 и oversample=5×: выбираем top-50 comment-векторов → GROUP BY parent_id → ACL-фильтр → top-10. На корпусе 31 844 комментариев (llm2) ожидаемый distinct parents в top-50 >> 10 (высока вероятность полного результата).
- **NFR-S2-003. ACL-инвариант.** Фильтрация только по `parent_id`, не по `comment_id`. Это неизменяемое требование (BR-002).
- **NFR-S2-004. Зависимость от UC-V2.** Без выполнения OQ-V2-1 (sign-off `comment.text`) UC-S2 не реализуется. Сценарий активируется через feature-flag в конфигурации.
- **NFR-S2-005. Тенант-изоляция.** Векторы комментариев другого тенанта не возвращаются.

## User Journey

### Journey-1. Оператор — «похожий root cause в переписке»

1. Оператор работает с заявкой `I` и видит комментарий `C`, где агент зафиксировал: «проблема оказалась в SSL-сертификате на proxy — истёк срок действия».
2. UI вызывает UC-S2: `{comment_id=C.id, target_meta_class='issue', K=10}`.
3. UC-S2 берёт вектор `C`, ищет top-50 похожих comment-векторов (oversample 5×).
4. GROUP BY `parent_id`, исключение `I`, ACL-фильтр.
5. Возвращается top-10 заявок с `max_score` и `matching_comment_count`.
6. Оператор видит заявки, в которых обсуждался похожий root cause, переходит по ссылкам, смотрит как решали.

**Альтернатива:** UC-V2 не активирован (sign-off не получен) → UC-S2 возвращает `CommentVectorsNotAvailable`; UI скрывает блок «Похожие по переписке».

### Journey-2. Поиск по произвольному тексту

1. Оператор вводит в поле поиска: «ошибка VPN после обновления Windows».
2. UC-S2 получает `{text='...', target_meta_class='issue', K=10}`.
3. Embedding через `text-search-query` → поиск в comment-векторах → GROUP BY → ACL → top-10.
4. Выдача: заявки, в комментариях которых обсуждалась похожая проблема.

## Бизнес-правила

- **BR-001. Дедупликация по parent_id с max-sim.** Если M комментариев одной заявки попали в oversample — заявка в выдаче один раз; score = max(similarity среди M). Ranking aggregation: max-similarity как default для PoC (OQ-S2-1).
- **BR-002. ACL по parent-объекту, не по комментарию.** Пользователь не должен видеть заявки, к которым у него нет доступа в SMP, даже если комментарии этих заявок близки к запросу. Проверка — post-aggregation по `parent_id`.
- **BR-003. PII в логах.** Полный текст запроса в лог не пишется (аналогично UC-S1 BR-004).
- **BR-004. Только user-комментарии.** В поиске участвуют только комментарии с `chunk_kind='related'` и без флага system (унаследовано от UC-V2 BR-002).
- **BR-005. Тенант-изоляция.** Только векторы текущего тенанта.
- **BR-006. Precondition-информирование.** Если UI передаёт `comment_id`, модуль не отклоняет запрос из-за типа комментария — это ответственность UI/вызывающего. Однако FR-001 фиксирует рекомендацию: для discussion-реплик результаты могут быть менее точными.

## Доменные события

- **CommentSearchRequested** (`mode='by_comment'|'by_text'`, `K`, `correlationId`) — UC-S2 принял запрос.
- **CommentSearchCompleted** (`correlationId`, `resultCount`, `latencyMs`) — запрос обработан.
- **CommentSearchFailed** (`correlationId`, `errorCode`) — ошибка (`CommentVectorsNotAvailable` / `VectorNotReady`).

## Acceptance Criteria

- [ ] **AC-001.** Поиск по `comment_id` возвращает top-K заявок (K=10 по умолчанию) с `max_score` и `matching_comment_count`.
- [ ] **AC-002.** Если N комментариев одной заявки попали в oversample — заявка возвращается один раз (дедупликация, BR-001). *(supersedes: нет; новый критерий)*
- [ ] **AC-003.** ACL: заявки, к которым у пользователя нет доступа, не возвращаются даже при высоком сходстве комментариев (BR-002). Проверяется тестовым аккаунтом.
- [ ] **AC-004.** Исходная заявка (от которой взят comment_id-источник) исключена из выдачи (FR-006).
- [ ] **AC-005.** Free-text запрос возвращает непустой список на репрезентативной выборке из llm2-комментариев.
- [ ] **AC-006.** При отсутствии comment-векторов (`UC-V2 not activated`) — ответ `CommentVectorsNotAvailable`, не ошибка 500.
- [ ] **AC-007. Latency (черновой).** p95 ≤ 1 000 ms на корпусе ≥ 30k комментариев. Финальный бюджет — после smoke-замера в ADR.
- [ ] **AC-008.** Логи содержат `correlationId`, `latencyMs`, `resultCount`; не содержат текст запроса (BR-003).
- [ ] **AC-009. Precondition-валидация (Variant B).** При поиске по closing/resolution комментарию (если OQ-S2-5 закрыт и comment_kind доступен) — результаты должны быть более релевантны, чем по discussion-реплике той же заявки. Проверяется на ground truth с размеченными comment-парами (post-PoC eval). *(зависит от OQ-S2-5)*

## Открытые вопросы

| ID | Статус | Решение / Описание | Кому |
|----|--------|--------------------|------|
| OQ-S2-1 | **Resolved (2026-05-02)** | Вариант A — max-similarity для PoC. RRF — в OQ-FUTURE (post-eval). Owner: Демьянов. | BA + SA → ADR |
| OQ-S2-2 | **Resolved (2026-05-02)** | Вариант C — не делать cross-mode в PoC. Owner: Демьянов. | BA + Owner |
| OQ-S2-3 | **Resolved (2026-05-02)** | Вариант A — 5× для PoC. SA фиксирует в ADR. Owner: Демьянов. | SA → ADR |
| OQ-S2-4 | **Resolved (2026-05-02)** | Вариант A — молча исключить заявки с 0 комментариев из выдачи. Owner: Демьянов. | BA + SA |
| OQ-S2-5 (= OQ-ITSM-3) | **Resolved (2026-05-02)** | Вариант C — не делаем pre-filter по comment_kind в PoC. UC-S2 работает по любому комментарию без pre-filter. Pre-filter по типу комментария — будущая фича MVP+, требует расширения SMP-метамодели или эвристики. Pre-condition про `comment.kind` снят. Owner: Демьянов. | SA + Сахабетдинов + Owner |

## Бриф для SA

**Требование:** `content/30-requirements/functional/uc-s2-find-similar-by-comments.md`
**Фаза:** PoC

**Спроектировать:**
- SQL-паттерн: oversample KNN по comment-векторам (`chunk_kind='related'`) → GROUP BY parent_id → MIN(dist) per parent → ACL-фильтр (паттерн из RES-009.2 §5).
- ACL-алгоритм (BR-002): Step 1 SQL + Step 2 Java-фильтр, аналогично KB-ACL в UC-S1.
- Ranking aggregation (OQ-S2-1): max-similarity как default, зафиксировать в ADR после offline-eval.
- Feature-flag: UC-S2 активируется только при `comment_vectorization.enabled=true`.
- **Решение по OQ-S2-5 (comment_kind):** ADR должен зафиксировать выбор между эвристикой «последний комментарий перед final-статусом» vs LLM-классификацией vs scope-down без pre-filter. До решения OQ-ITSM-3 (owner-decision) UC-S2 работает по любому комментарию.

**Бизнес-правила для валидаций:** BR-001 (дедупликация + max-sim), BR-002 (ACL post-aggregation), BR-004 (только user-комментарии).

**AC для проверки архитектуры:** AC-002 (дедупликация), AC-003 (ACL), AC-006 (feature-flag поведение).

**Решение по OQ-S2-5 закрепится в ADR-comment-acl** (или отдельном ADR-comment-kind).
