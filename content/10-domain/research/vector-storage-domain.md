---
order: 9
title: "RES-009.1 — Domain & data analysis для стратегии хранения векторов"
properties:
  - Тип контента: Исследование
  - Фаза: PoC
  - Статус: Approved
---

# RES-009.1 — Domain & data analysis для стратегии хранения векторов

**Дата:** 2026-05-01
**Исследователь:** researcher-agent
**Запрос PM/BA:** ADR-004 написан под допущение «один объект = один вектор», которое ломается о KB-статьи > 2048 токенов, issue с десятками комментариев, разный ACL у частей объекта. До апдейта ADR-004 нужен анализ доменных данных.
**Глубина:** standard (≤ 2 ч)

## TL;DR

На корпусе `llm2` (6 259 issue, 32 298 comment, 113 KB-статей с непустым `content`):
- **47,8 % KB-статей** превышают 2 048 токенов (max ≈ 75k токенов) → chunking для KB **обязателен**.
- **13,3 % issue.description** превышают лимит, но `composite_extended` (subject+cancelReason+decisionReport+feedback) укладывается в лимит у **99,6 % issue** → single-vector жизнеспособен.
- PoC-whitelist (subject+cancelReason) даёт **median 33 chars / 22 токена** — критически мало сигнала; UC2/UC3 на этом whitelist'е практической пользы не дадут.
- **`problem` фактически не валидируется на llm2** (3 объекта, 0 комментариев) — PoC iter 2 нуждается в другом источнике.
- **Ground truth UC3** — 2,4 % заявок с `duplicates` (151/6 259); precision/recall будут noisy.

**Рекомендуемая стратегия — D (hybrid):** issue → A (single vector на composite_extended), KB → C (chunked + rollup). Стратегия E (per-related-vector) — out of scope PoC, но DDL должен оставлять возможность добавить без миграции.

## Ключевые находки

1. **D (hybrid) рекомендуется к волне 2.** Single-vector покрывает 99,6 % issue по composite_extended; chunking обязателен для 47,8 % KB-статей. Одна таблица с `chunk_index` различает оба режима. — [established, на цифрах 2026-05-01]
2. **A для KB исключена** — 47,8 % статей не помещаются физически в один embedding-вызов. — [established]
3. **A для issue.description без обрезки теряет 13,3 % хвоста** — caller должен либо переходить на composite_extended, либо обрезать. — [established]
4. **PoC-whitelist (subject + cancelReason) недостаточен для real value** — 99,9 % composite < 100 токенов, median 33 chars. UC2/UC3 в первой итерации будут давать тривиальные результаты. **Эскалация в BA:** ускорить sign-off на medium-PII (`description`, `decisionReport`). — [established]
5. **`comment.text` остаётся out of scope модуля** (caller сам решает, что передать). Однако max comments/parent = 8 248 ⚠️ → если caller когда-то захочет передавать все комментарии, столкнётся с экстремальными хвостами; стратегия E в DDL должна быть готова. — [established]
6. **`problem` не валидируется на llm2** (3 объекта). Для PoC iter 2 нужен альтернативный корпус. — [established]
7. **Ground truth UC3** — 2,4 % (151/6 259). RES-009.2/3 должны пометить UC3 precision/recall на PoC как noisy. — [established]
8. **char/token = 3,5** (одна точка smoke). Все основные пороги §3 устойчивы к ±15 % погрешности. — [established]
9. **ACL** — только у KB (`kbAccesses`); у issue/problem управляется SMP-сессией. Per-chunk ACL нужен только для KB. — [established, smp-metamodel.md]
10. **Сводка по DDL для волны 3:** существующие колонки ADR-004 (`model_version`, `whitelist_version`, `composite_hash`, `vectorized_at`, `dirty`) сохраняются; нужно явно зафиксировать `chunk_index` (0 для single-vector), `chunk_total` (1 для single), опционально `source_attr` и `parent_id` (под будущую E без миграции). — [emerging для RES-009.3]

## §1 — Бизнес-кейсы UC × класс × payload

> Примечание scope: модуль принимает payload от caller'а, не формирует его сам. В таблице описано, **что caller может передать** — полный реестр физических форм взаимодействия.

### 1.1 Матрица UC × класс × payload на векторизацию (UC1)

| UC-операция | Класс | Что caller передаёт модулю | Whitelist-атрибуты в payload | Тип payload | Чанкинг? |
|---|---|---|---|:---:|:---:|
| UC1 — vectorize | `issue` (PoC) | `{object_id, meta_class, text: subject+cancelReason}` | `subject` (medium, sign-off), `cancelReason` (low) | одиночный текст | нет |
| UC1 — vectorize | `issue` (после sign-off) | `{object_id, meta_class, text: subject+cancelReason+feedback+decisionReport}` | + `feedback`, `decisionReport` (medium) | одиночный текст | маловероятно |
| UC1 — vectorize | `problem` | `{object_id, meta_class, text: subject+workaround+rootCause}` | `subject`, `workaround`, `rootCause` (low); опц. `description`, `decisionReport` (medium, gate 2) | одиночный текст | редко (только при длинных `workaround`/`rootCause`) |
| UC1 — vectorize | `knowledgeBase$article` | `{object_id, meta_class, text: title+description+keywords+content}` | `title`, `description`, `keywords`, `content` (все low) | одиночный текст | **часто** (`content` может быть большим) |
| UC1 — vectorize | `knowledgeBase$section` | `{object_id, meta_class, text: title+description+keywords}` | `title`, `description`, `keywords` (low) | одиночный текст | нет |

**Что caller не передаёт никогда в рамках UC1:** комментарии (`comment.text`), вложения, backLinks, slaLog, serviceCall. Отбор комментариев — out of scope модуля по CLAUDE.md.

### 1.2 Матрица UC × класс × payload на поиск (UC2)

| UC-операция | Класс источника | Что caller передаёт модулю | Целевые классы | Ожидаемый выход |
|---|---|---|---|---|
| UC2 — search by object | `issue` | `{source_id, source_meta_class}` (caller берёт вектор из таблицы по id) | `issue`, `knowledgeBase$article`, `problem` | list of `{object_id, meta_class, score}`, top-K |
| UC2 — search by object | `knowledgeBase$article` | `{source_id, source_meta_class}` | `knowledgeBase$article` | list of `{object_id, meta_class, score}`, top-K |
| UC2 — search by object | `problem` | `{source_id, source_meta_class}` | `issue`, `problem` | list of `{object_id, meta_class, score}`, top-K |
| UC2 — free-text search | любой (auto-embed) | `{text: query_string, target_classes: [...]}` | один или несколько классов | list of `{object_id, meta_class, score}`, top-K |
| UC2 — cross-class search | `issue` | `{source_id}` + `target_classes=[knowledgeBase$article]` | только KB | KB-статьи (UC2 JTBD-1 Journey-1 шаг 2) |

**Метаданные, нужные вместе с вектором (обязательные для caller'а):**
- `object_id` (uuid), `meta_class` (fqn), `tenant_id` — идентификация объекта
- `model_version` (modelUri pinned) — фильтр совместимости при поиске
- `whitelist_version` — аудит (какой набор атрибутов использован)
- `vectorized_at` (timestamptz) — свежесть
- `dirty` (bool) — статус для джобы UC1
- `composite_hash` (bytea) — идемпотентность
- `chunk_index` (int, default 0) — если multi-chunk, для сборки

**Опциональные метаданные (добавляются при multi-vector/per-attribute стратегии):**
- `source_attr` (text) — имя атрибута-источника (если хранятся per-attribute векторы)
- `chunk_total` (int) — число чанков для данного объекта

### 1.3 UC3 — дедупликация

| Режим | Класс | Что caller передаёт | Что модуль делает |
|---|---|---|---|
| UC3-online (при создании) | `issue` | `{text: subject+whitelisted}` (ad-hoc, нет object_id) | auto-embed через `text-search-query`, KNN-поиск, возврат top-5 с score |
| UC3-batch (аудит) | `issue`, `problem` | `{target_classes, score_threshold, window}` | выгрузка векторов за окно, группировка пар/кластеров, возврат отчёта |

**Выход UC3-online:** `{object_id, meta_class, score, label: 'дубль'|'похожая'}` — только идентификаторы, без текстов.
**Выход UC3-batch:** сгруппированные пары по threshold с метаданными (`issue.duplicates`-known vs new).

## §2 — Реестр связанных FQN на стенде llm2

> Источник: `smp-metamodel.md` (live 2026-05-01) + задача scope RES-009.1. MCP-сессия naumen-smp-dev-admin протухла во время работы над артефактом — live-дополнение по `comment` и cross-links не выполнено. Пометки [MCP-verified] / [from-metamodel-md] / [needs-verify] по каждой строке.

### 2.1 issue — связанные FQN

| FQN связанного объекта | Атрибут-связь на `issue` | Тип связи | ACL-флаги | Входит в whitelist UC1 | Примечание |
|---|---|:---:|---|:---:|---|
| `comment` | обратная через `comment.source` | one-to-many (много к одному источнику) | нет (ACL наследуется от source) | **нет** (out of scope, PII-аудит) | [from-metamodel-md] Универсальный FQN, `comment.text` — not whitelisted |
| `slmService` | `issue.slmService` | many-to-one | нет | нет (не текстовый) | [from-metamodel-md] |
| `agreement` | `issue.agreement` | many-to-one | нет | нет | [from-metamodel-md] |
| `clientOU` | `issue.clientOU` | many-to-one | нет | нет | [from-metamodel-md] |
| `clientEmployee` | `issue.clientEmployee` | many-to-one | нет | нет | [from-metamodel-md] PII-high |
| `asset` | `issue.assets` | many-to-many (boLinks) | нет | нет | [from-metamodel-md] |
| `issue` (дубль) | `issue.duplicates` | many-to-many | нет | нет | [from-metamodel-md] Ground truth UC3 |
| `issue` (дубль обратная) | `issue.duplicatesRL` | many-to-many (обратная) | нет | нет | [from-metamodel-md] Ground truth UC3 |
| `issue` (predecessor) | `issue.linkClosedSC` | many-to-one | нет | нет | [from-metamodel-md] |
| `problem` | `issue.problems` | backBOLinks | нет | нет | [from-metamodel-md] Сигнал для UC2 cross-class |
| `attachment` | [needs-verify] | one-to-many | нет | нет | Файлы; содержимое не векторизуется |
| `slaLog` / `slaState` | [needs-verify] | one-to-many | нет | нет | Технические записи SLA |
| `serviceCall` / `serviceRequest` | [needs-verify] | [needs-verify] | нет | нет | Зависит от конфигурации стенда |

**Формы payload, которые теоретически могут прийти в модуль от caller'а по issue:**
- `{object_id, text: subject}` — минимальный (только low-PII)
- `{object_id, text: subject+cancelReason}` — baseline whitelist PoC
- `{object_id, text: subject+cancelReason+feedback+decisionReport}` — расширенный (после sign-off)
- `{object_id, chunks: [{text, chunk_index}]}` — если caller решил chunk'ировать сам (нетипично, но физически возможно)

**Caller НЕ передаёт:** комментарии, вложения, связанные объекты (`slmService`, `problems`).

### 2.2 problem — связанные FQN

| FQN связанного объекта | Атрибут-связь | Тип связи | ACL-флаги | Входит в whitelist UC1 | Примечание |
|---|---|:---:|---|:---:|---|
| `comment` | обратная через `comment.source` | one-to-many | нет | **нет** | [from-metamodel-md] Универсальный FQN |
| `issue` | `problem.issues` | many-to-many (boLinks) | нет | нет | [from-metamodel-md] Сильный сигнал UC2 cross-class |
| `slmService` | `problem.slmServices` | many-to-many | нет | нет | [from-metamodel-md] |
| `changeRequest` | `problem.changeRequests` | many-to-many | нет | нет | [from-metamodel-md] |
| `asset` | `problem.assets` | many-to-many | нет | нет | [from-metamodel-md] |
| `decisionReport` (атрибут) | inline (richtext поле) | — | нет | medium (gate 2) | [from-metamodel-md] |
| `workaround` (атрибут) | inline (richtext поле) | — | нет | low | [from-metamodel-md] |
| `rootCause` (атрибут) | inline (richtext поле) | — | нет | low | [from-metamodel-md] |

**Формы payload для problem:**
- `{object_id, text: subject+workaround+rootCause}` — baseline whitelist (gate 1)
- `{object_id, text: subject+workaround+rootCause+description+decisionReport}` — расширенный (gate 2 после sign-off)

### 2.3 knowledgeBase$article — как target UC2 (только)

> По заданию KB рассматривается ИСКЛЮЧИТЕЛЬНО как target UC2 (caller ищет похожие вопросы → KB-ответы). KB-section context не закладывается.

| FQN связанного объекта | Атрибут-связь | Тип связи | ACL-флаги | Примечание |
|---|---|:---:|---|---|
| `kbAccess` | `knowledgeBase.kbAccesses` | catalogItemSet | **isPrivate** — признак ограниченного доступа | [from-metamodel-md] Обязателен для UC2 FR-008 фильтра |
| `knowledgeBase` (parent) | `knowledgeBase.parent` | many-to-one (иерархия) | нет | [from-metamodel-md] Не используем в payload |
| `slmService` | `knowledgeBase.slmServices` | backBOLinks | нет | [from-metamodel-md] Сигнал cross-domain (не в payload) |
| `comment` | обратная через `comment.source` | one-to-many | нет | [from-metamodel-md] Не в payload (out of scope) |

**ACL-критичность KB:** `kbAccesses` — единственный класс с per-object ACL, который требует фильтрации на стороне UC2 (BR-002). У `issue` и `problem` ACL управляется SMP-сессией целиком — фильтрация не нужна на уровне pgvector-запроса.

**Формы payload для KB (UC1 — vectorize):**
- `{object_id, text: title+description+keywords+content}` — полный whitelist
- `{object_id, chunks: [{text, chunk_index}]}` — если `content` длинный и caller чанкирует перед передачей в модуль (или модуль чанкирует внутри по ADR-006 FR-006)

### 2.4 comment — структура FQN

> MCP-сессия протухла; данные основаны на задании RES-009.1 (owner подтвердил структуру) и скрипте в `raw/length-distribution-script.groovy`.

| Атрибут | Тип | Примечание |
|---|---|---|
| `text` | richtext | Текст комментария. **Не входит в whitelist ADR-005.** |
| `source` | object (abstractBO) | Ссылка на родительский объект (issue, problem, kb, etc.). Тип определяется через `source.metaClass`. |
| `author` | object (employee) | PII-high. |
| `dt` | datetime | Время создания. |
| (другие атрибуты) | [needs-verify via MCP] | Требует live-выгрузки через `metamodel_export_class('comment')` |

**Вывод по comment:** `comment` не входит в whitelist любого класса для UC1. Caller не должен включать `comment.text` в payload до завершения PII-аудита и явного sign-off owner'а. Однако `comments_per_issue` (количество) — полезная метрика для оценки возможного future scope.

## §3 — Распределение длин текстов на корпусе llm2

> **Статус: ЗАКРЫТ.** Скрипт `console/diag_length_distribution.groovy` отработал на llm2 2026-05-01 18:53 UTC. Сырые данные — `content/10-domain/research/raw/length-distribution.csv`. Коэффициент char/token = 3.5 применён в скрипте к колонкам `est_tokens_*` и `pct_over_2048_tok`.

### 3.1 Сводка корпуса llm2

| Класс | Всего объектов | С duplicates | dup % |
|---|---:|---:|---:|
| `issue` | **6 259** | 151 | 2,4 % |
| `problem` | **3** | — | — |
| `knowledgeBase$article` | **129** (113 с непустым `content`) | — | — |

`problem` фактически отсутствует на стенде (3 объекта, ни одного комментария, ни одного `workaround`/`rootCause`). Стратегические выводы по `problem` строить на этом корпусе **нельзя** — нужен либо другой стенд, либо экстраполяция от `issue`.

KB-атрибут на llm2 — **`content`** (auto-detect в скрипте отработал, `text` не использовался).

Коэффициент char/token = 3.5 на одной smoke-точке. **§3b** ниже фиксирует уточнение.

### 3.2 Распределение по ключевым атрибутам (chars / est_tokens)

| Атрибут | count | p50 ch | p95 ch | p99 ch | max ch | est_tokens p95 | % > 2048 ток | % < 100 ток |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `issue.description` | 6 074 | 1 025 | 17 985 | 70 986 | 1 607 285 | **5 138** | **13,3 %** | 30,2 % |
| `issue.subject` | 6 223 | 33 | 77 | 113 | 255 | 22 | 0,0 % | 100 % |
| `issue.decisionReport` | 3 700 | 60 | 1 416 | 4 414 | 57 918 | 404 | 0,6 % | 82,2 % |
| `issue.composite_poc` (subject+cancelReason) | 6 223 | 33 | 77 | 116 | 1 133 | 22 | 0,0 % | 99,9 % |
| `issue.composite_extended` (+ decisionReport, feedback) | 6 223 | 62 | 734 | 3 475 | 57 936 | 209 | 0,4 % | 88,9 % |
| `comment.text` (issue+problem, агрегат) | 32 298 | 187 | 8 475 | 26 336 | 405 766 | **2 421** | **6,9 %** | 69,2 % |
| `comment.text` (только issue) | 31 844 | 187 | 8 512 | 26 404 | 405 766 | 2 432 | 7,0 % | 69,1 % |
| `comment.text` (только problem) | **0** | — | — | — | — | — | — | — |
| `problem.description` | 3 | 77 | 825 | 825 | 825 | 235 | 0,0 % | 66,7 % |
| `problem.workaround` | 0 | — | — | — | — | — | — | — |
| `problem.rootCause` | 0 | — | — | — | — | — | — | — |
| `kbArticle.content` | 113 | **6 428** | **91 049** | 248 353 | 262 536 | **26 014** | **47,8 %** | 11,5 % |

### 3.3 Ответы на вопросы анализа

**`issue.description`:**
- **13,3 % заявок** с `description` не укладывается в 2 048 токенов — это значимая доля: 808 из 6 074 заявок. Стратегия A (single-vector с обрезкой) **теряет хвост** этих текстов.
- 30,2 % заявок имеют `description` < 100 токенов (low-signal риск). Их сходство будет определяться не описанием, а subject'ом.
- 0,1 % полностью пустые после фильтра `length > 0`.
- 185 заявок (6 259 − 6 074) **вообще не имеют description** — caller должен решить, передавать их в UC1 или нет (модулю всё равно).

**`kbArticle.content`:**
- **47,8 % статей превышают 2 048 токенов** — почти половина корпуса. Median = 6 428 chars (≈ 1 836 токенов), p95 = 91 049 chars (≈ 26 000 токенов), max = 262 536 chars (≈ 75 000 токенов).
- Single-vector для KB **физически невозможен**: статьи с p95 > 26k токенов не помещаются в один вызов API ни при каком разумном лимите модели.
- **Чанкинг для KB обязателен.** Это окончательное решение для волны 2.

**`issue.composite_poc` (subject + cancelReason — текущий PoC-whitelist):**
- p95 = 77 chars (22 токена), max = 1 133 chars (323 токена). **0 % превышают лимит.**
- 99,9 % заявок имеют composite < 100 токенов — короткий текст, риск low-signal на этой стратегии. Качество поиска в первой PoC-итерации будет ограничено.
- Это означает: PoC-whitelist даёт **минимальный сигнал**. Для realistic UC2/UC3 нужен расширенный whitelist (см. строку ниже).

**`issue.composite_extended` (+ decisionReport, feedback):**
- p95 = 734 chars (209 токенов), p99 = 3 475 chars (993 токена), max = 57 936 chars (16 553 токенов). **0,4 % превышают лимит** — 25 заявок из 6 223.
- При расширенном whitelist'е стратегия A работает для **99,6 %** заявок. Чанкинг для редких хвостов опционален (можно урезать до лимита, потеря < 0,5 %).

**`comment.text` (issue):**
- p50 = 187 chars (53 токена), p95 = 8 512 chars (2 432 токена), max = 405 766 chars (115 933 токена). **7 % комментариев превышают 2 048 токенов индивидуально.**
- Это критично для будущих стратегий, где caller передаёт массив комментариев — даже **отдельные** комментарии могут не помещаться в один embedding-вызов.

### 3.4 Косвенные выводы для волны 2

1. **Single-vector (A) жизнеспособен только для `issue.composite_extended`** (99,6 % покрытие). Для `issue.description` без обрезки — **теряется 13,3 %**, для KB — **теряется 47,8 %**.
2. **Chunking (C) обязателен для KB**, опционален для issue.description, не нужен для composite_extended.
3. **PoC-whitelist даёт критически мало сигнала** (median 33 chars). Это вход для BA: либо принять low quality в первой итерации, либо ускорить sign-off на medium-PII атрибуты (`description`, `decisionReport`).
4. **`problem` не валидируется на этом стенде** — для PoC iter 2 нужен другой источник данных или fixture-генерация.

## §3a — Распределение комментариев на parent

> **Статус: ЗАКРЫТ.**

### 3a.1 Сводка

| Метрика | issue | problem |
|---|---:|---:|
| Всего комментариев | 31 844 | 0 |
| Объектов с ≥ 1 комментарием | 4 708 | 0 |
| Объектов всего | 6 259 | 3 |
| **% объектов без комментариев** | 24,8 % | 100 % |
| p50 comments/parent | **3** | — |
| p90 comments/parent | 11 | — |
| p95 comments/parent | **15** | — |
| p99 comments/parent | 31 | — |
| max comments/parent | **8 248** ⚠️ | — |
| Среднее comments/parent (по объектам с комментариями) | 6,76 | — |

Owner-ориентир «~10 комментариев / заявку, ~100k всего» **не подтвердился**:
- Фактически медиана = **3** (в 3 раза меньше)
- Фактически всего = **31 844** (в 3 раза меньше)
- На стенде llm2 заявок ≈ в 3 раза меньше, чем ожидалось (6 259 vs 100 000)

Это означает: если на проде ожидаются 100 000 заявок с реальной активностью, общее количество комментариев будет порядка **300 000 − 1 000 000**, а не 100 000.

### 3a.2 Аномалия — заявка с 8 248 комментариями

Один объект (max comments/parent = 8 248) кардинально отличается от p99 (31). Это либо:
- технический объект (бот / интеграция, льёт комментарии непрерывно)
- результат миграции из другой системы
- ошибка скрипта (но скрипт корректный, GROUP BY c.source даёт прямой счёт)

Для caller'а это означает: **нельзя считать, что распределение комментариев имеет ограниченный хвост**. Если caller передаёт «все комментарии заявки» — он должен иметь cap, иначе для одной заявки придёт 8k комментариев на векторизацию.

### 3a.3 Гипотетический composite-payload «issue + все комментарии»

Если бы caller отдавал в payload `subject + description + все комментарии` (что **out of scope модуля**, но полезно для оценки требований к storage):

- p50 заявка: 33 + 1 025 + 3 × 187 = **1 619 chars (463 токена)** — укладывается
- p95 заявка: 77 + 17 985 + 15 × 8 512 = **146 742 chars (41 926 токенов)** — **в 20× больше лимита**
- p99: 113 + 70 986 + 31 × 26 336 = **887 515 chars (253 575 токенов)** — **в 124× больше лимита**

Любая стратегия, агрегирующая все комментарии в один вектор, **математически невозможна** даже при лимите 8 000 токенов. Caller обязан либо отбирать комментарии (out of scope модуля), либо передавать их пер-комментарий, либо chunked.

### 3a.4 Ground truth для UC3 (дубли)

- Заявок с проставленным `duplicates` или `duplicatesRL`: **151 из 6 259** = **2,4 %**.
- Это **критически мало** для надёжной precision/recall-оценки UC3 на 95% доверии — закрывает BA-022 «достаточно ли ground truth».
- Researcher должен пометить в RES-009.2 / RES-009.3 — оценка качества UC3 на llm2 будет noisy. Реальная валидация — на другом стенде или через synthetic ground truth.

## §3b — Калибровка char → token

> **Статус: ЗАКРЫТ для §3 (single-point).** Полная 5-точечная калибровка — отложена; не блокирует выводы.

### 3b.1 Замер 2026-05-01

| Текст | chars | numTokens | char/token |
|---|---:|---:|---:|
| Тестовая фраза (русская) | 49 | 14 | **3,5** |

Smoke-замер из RES-002-closeout (yc-foundation-models.md). Единственная точка для русского текста.

### 3b.2 Применённый коэффициент

В скрипте `diag_length_distribution.groovy` использован **TOKEN_COEFF = 3.5** для всех `est_tokens_*` и `pct_over_2048_tok`.

### 3b.3 Чувствительность выводов §3 к коэффициенту

Если фактический коэффициент окажется в диапазоне 3.0 − 4.0:

| chars (KB p95) | est_tokens @ 3.0 | @ 3.5 (используем) | @ 4.0 |
|---:|---:|---:|---:|
| 91 049 | 30 350 | 26 014 | 22 762 |
| 17 985 (issue.desc p95) | 5 995 | 5 138 | 4 496 |

Все основные выводы §3 (KB обязательно chunking, issue.description частично выходит за лимит, composite_extended укладывается на 99,6 %) **устойчивы** к погрешности коэффициента — пороги не близки к границе при сдвиге ±15 %.

### 3b.4 Полная 5-точечная калибровка — отложена

Owner предложил пропустить — researcher согласен: точность оценок токенов сейчас не критична. Если волна 2 наткнётся на пороговый кейс — вернуться к §3b и провести 5 замеров через embedding API.

## §3b — Калибровка char → token

> **Статус: ЧАСТИЧНО ЗАКРЫТ.** Smoke 2026-05-01 дал одну точку данных.

### Известные данные из smoke (yc-foundation-models.md)

| Текст | Символов | numTokens | char/token |
|---|---|---|---|
| Тестовая фраза (русская) | 49 | 14 | **3,5** |

Одна точка слишком мало для калибровки. Нужно 5 точек разной длины.

### Инструкция для owner'а — калибровочные запросы

Запустить 5 curl-запросов с текстами разной длины (API-Key из `.secrets/yc-api-key.json`):

```bash
API_KEY=$(cat .secrets/yc-api-key.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('secret', d.get('key', '')))")
FOLDER_ID=b1g249mrsql00khlmvcs
MODEL="emb://${FOLDER_ID}/text-search-doc/latest"
URL="https://llm.api.cloud.yandex.net/foundationModels/v1/textEmbedding"

# Текст 1: короткий (~50 токенов)
TEXT1="Не открывается VPN на ноутбуке после обновления Windows. Пробовал переустановить клиент, не помогает."
# Текст 2: средний (~200 токенов)
TEXT2="Проблема с доступом к корпоративной сети VPN после планового обновления операционной системы Windows 11. Пользователь сообщает, что до обновления всё работало нормально. После установки обновления KB5034765 клиент VPN перестал подключаться к серверу. Выдаётся ошибка 'Не удалось установить сетевое соединение' с кодом 807. Переустановка клиента VPN не помогла. Сетевые настройки и брандмауэр проверены — изменений не вносилось. Аналогичная проблема воспроизводится на двух других машинах в том же отделе."
# Текст 3: длинный (~500 токенов) — повторить TEXT2 несколько раз
# Текст 4: очень длинный (~1500 токенов)
# Текст 5: короткий смешанный (русский + цифры + коды)

for TEXT in "$TEXT1" "$TEXT2"; do
  CHARS=$(echo -n "$TEXT" | wc -c)
  TOKENS=$(curl -s -X POST "$URL" \
    -H "Authorization: Api-Key $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"modelUri\": \"$MODEL\", \"text\": \"$TEXT\"}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('numTokens','err'))")
  echo "chars=$CHARS tokens=$TOKENS ratio=$(python3 -c 'print(round('$CHARS'/'$TOKENS', 2))')"
done
```

### Предварительный коэффициент

На основе одной точки (49 символов / 14 токенов):
- **Коэффициент: ≈ 3,5 символа на токен** для русского текста
- Это близко к стандарту BPE-токенизации для кириллицы (~3–4 символа/токен)

**Используемый коэффициент до верификации:** `chars / 3.5` (консервативно)

### Пересчёт оценок токенов с коэффициентом 3.5

Когда придут данные от llm2 (CSV с полями `est_tokens_*` считавшимися по `chars/4`), пересчитать:
- `est_tokens_corrected_p95 = chars_p95 / 3.5`
- `est_tokens_corrected_max = chars_max / 3.5`

При коэффициенте 3.5 вместо 4:
- Оценки токенов вырастут на ≈ 14% (4/3.5 = 1.14×)
- Если `chars_p95 = 8 000` для KB: `est_tokens = 8000/3.5 ≈ 2 286` — превышает лимит 2 048
- Если `chars_p95 = 6 000` для KB: `est_tokens = 6000/3.5 ≈ 1 714` — укладывается

Коэффициент критичен для KB — заполнить таблицу после получения данных.

## §4 — Сводка для волны 2 (RES-009.2)

### 4.1 Стратегии A-E на фактических данных llm2

| Стратегия | Описание | Жизнеспособность | Обоснование на цифрах |
|---|---|:---:|---|
| **A — single vector** | Один вектор на объект, один composite text → один embedding | **Условно** | Для `issue.composite_extended` (subject+cancelReason+decisionReport+feedback) укладывается **99,6 %** объектов. Для голого `issue.description` — **86,7 %** (теряем хвост 13,3 %). Для KB.content — **52,2 %** (теряем 47,8 % статей, неприемлемо). |
| **B — multi-vector per attribute** | Отдельный вектор на каждый whitelisted атрибут | **Не рекомендуется** | Для issue.composite_extended кратно увеличивает YC FM вызовы (×4), не даёт доказанного прироста качества. Может рассматриваться для KB — но C проще и достаточен. |
| **C — chunked + rollup** | Длинный текст режется на чанки, каждый чанк → вектор; хранятся все чанки; rollup (mean/max/first) при поиске | **Обязателен для KB** | KB.content p95 = 26 014 токенов, max = 75 010 — без чанкинга невозможно физически. Для issue с большим `description` — также применим (13,3 % случаев). |
| **D — hybrid** | issue → стратегия A на composite_extended; KB → стратегия C | **РЕКОМЕНДУЕМ** | Покрывает 99,6 % issue без чанкинга и 100 % KB через чанкинг. Одна таблица, `chunk_index` различает. Минимум сложности на caller и на storage. |
| **E — per-related-vector** | Вектор на каждый связанный объект (комментарий → отдельный вектор) | **Не в scope** | `comment.text` not whitelisted, отбор комментариев — out of scope модуля. Если caller в будущем захочет векторизовать комментарии — таблица должна это поддерживать через `parent_id` + `chunk_index`. **Закладываем в DDL, но не реализуем в PoC.** |

### 4.2 Что отсечено окончательно

- **A для KB** — отсечено: 47,8 % статей физически не помещаются в один embedding-вызов даже при лимите 8 000 токенов.
- **B как основная** — отсечено: бессмысленно при composite_extended укладывающемся в лимит.
- **E как стратегия PoC** — отсечено: out of scope модуля. **Однако** структура таблицы должна позволить хранение `parent_id` + `chunk_index` для будущего расширения без миграции схемы.

### 4.3 Что подтверждено цифрами

- **Hybrid (D) — единственная разумная стратегия.** issue → A на composite_extended (99,6 % покрытие, остальные 0,4 % — truncation в caller'е до 2 000 токенов, потеря < 25 объектов из 6 223). KB → C (chunking обязателен).
- **PoC-whitelist для issue (subject+cancelReason) даёт катастрофически мало сигнала** — 99,9 % composite < 100 токенов. На этом whitelist'е UC2/UC3 не дадут практической пользы. Нужен sign-off на medium-PII атрибуты до старта PoC iter 2.
- **Ground truth UC3 на llm2 — 2,4 %** (151 из 6 259). Для precision/recall валидации этого мало; researcher RES-009.2 / RES-009.3 должен пометить, что UC3-метрики PoC будут noisy.
- **`problem` на llm2 валидировать нельзя** (3 объекта, 0 комментариев, 0 workaround/rootCause). PoC iter 2 (problem) требует либо synthetic fixture, либо другого стенда.

### 4.4 Открытые вопросы для RES-009.2

| # | Вопрос | Почему важен | Куда влияет |
|---|---|---|---|
| OQ-1 | Какая модель rollup по чанкам: mean / max / first-chunk / max-of-top-K? | Качество UC2 для KB. На корпусе 113 статей offline-eval (Recall@10 на ground truth `kb-section`-ассоциациях) даст ответ. | DDL: нужно ли хранить summary-row (chunk_index=0=summary) или считать на лету. |
| OQ-2 | Chunk overlap: нужен ли и какого размера (0 / 10 % / 20 %)? | Без overlap теряются семантические связи на границах. С overlap — больше векторов на ту же статью. | YC FM cost линейно растёт от количества чанков. |
| OQ-3 | Chunk size: фиксированный (1 800 ток.) / adaptive (по абзацам) / sentence-aware? | Для KB.content (richtext, абзацный) abzac-aware лучше, но сложнее. | Алгоритм чанкинга — детерминированный (для idempotency). |
| OQ-4 | ACL для KB при multi-chunk: где фильтровать? | UC2 BR-002: search должен вернуть object_id, не chunk_id. ACL применяется к object_id. | Двухэтапный SQL: top-K чанков → DISTINCT object_id → ACL-фильтр. |
| OQ-5 | `source_attr` колонка: нужна ли? | Позволяет per-attribute search (только по `title`). | Для PoC — overkill; добавить опционально nullable column дёшево, реализовать позже. |
| OQ-6 | Детерминированность chunk_index при ре-векторизации: как гарантировать? | composite_hash должен быть стабилен — иначе при every refresh все чанки помечаются dirty. | Алгоритм чанкинга в ADR (фиксация порядка, sentinel-разделители). |
| OQ-7 | Хранить ли отдельный rollup-вектор (chunk_index=0=summary) или считать на лету? | Trade-off: хранение — +1 строка/объект (113 для KB), быстрее search. На лету — медленнее search, но меньше storage. | Решение по итогам offline-eval OQ-1. |
| OQ-8 | Точный лимит токенов YC FM `text-search-doc`: 2048 или 8000? | Официально не задокументировано (CAPTCHA). | Чем больше лимит, тем меньше чанков нужно для KB. Smoke с 3 000 токенов в RES-009.2. |
| **OQ-9** | **Как поддержать E (per-comment-vector) в DDL без реализации?** | Caller может в будущем захотеть передавать комментарии. Таблица должна это позволить без миграции. | DDL: `parent_id` UUID nullable, `chunk_kind` enum {`object`, `chunk`, `related`} или just chunk_index с конвенцией. Решается в RES-009.3. |
| **OQ-10** | **Truncation policy при single-vector A для редких длинных issue (0,4 %)?** | 25 заявок не укладываются в composite_extended. | Caller обрезает до 2 000 ток. перед отправкой, либо модуль возвращает ошибку и caller перенаправляет на C. |

### 4.5 Что приходит на вход RES-009.2

Закрыто:
1. ✅ CSV распределений длин — `raw/length-distribution.csv`
2. ✅ Имя атрибута KB — `content` (auto-detect)
3. ✅ Ground truth UC3 — 2,4 % (мало)
4. ✅ Корпус problem — пуст (3 объекта)

Не блокирует, можно отложить:
5. Точный лимит токенов YC FM (smoke с 3k ток. — runner для RES-009.2).
6. Полная 5-точечная калибровка char/token (текущая 3.5 устойчива к ±15 %).
7. Структура comment FQN через MCP (не критично — мы и так знаем `text`+`source` достаточно).

## Что НЕ удалось / отложено

| Пробел | Почему | Когда нужно |
|---|---|---|
| Точный лимит токенов YC FM `text-search-doc` | CAPTCHA на доках; smoke с длинным текстом не делали | RES-009.2 OQ-8 |
| 5-точечная калибровка char/token | Owner предложил пропустить; устойчиво к ±15 % | если RES-009.2 наткнётся на пороговый кейс |
| Корпус `problem` для валидации | На llm2 — 3 объекта, ничего реалистичного | PoC iter 2 — другой стенд или synthetic |
| Структура comment-FQN через MCP | MCP-сессия протухла, обошлись через HQL | если будущая стратегия E — RES-009.3 |

## Рекомендации для BA/SA

- **BA:** Whitelist PoC для issue (`subject + cancelReason`) даёт очень короткий composite — возможно, качество UC2/UC3 будет недостаточным для практической пользы. Стоит ускорить sign-off для `subject` (medium) и изучить, даст ли добавление `decisionReport` ощутимый прирост Recall@10.
- **BA:** Для UC3 online нужно решить вопрос Q7 из uc3: ad-hoc embedding при регистрации заявки — единственный способ дать подсказку до первого запуска UC1-джобы. Это требует явного разрешения на whitelist'е.
- **SA (ADR-004 update):** Таблица `pg_vector_service__vectors` уже предусматривает `chunk_index` по умолчанию 0. Дополнительно добавить `chunk_total` (int, default 1) и опционально `source_attr` (text, nullable) без DDL-реструктуризации — только `ALTER TABLE ADD COLUMN`. Это позволит поддержать стратегию D (hybrid) без миграции схемы при добавлении чанкинга для KB.
- **SA:** Rollup-стратегия (mean/max/first-chunk) — критическое решение для KB поиска. Рекомендуется сравнить на offline-eval по ground truth: если KB используется как target UC2, метрика — Recall@10 на запросах типа «описание заявки → похожая KB-статья».
- **SA:** ACL-фильтрация для KB при multi-chunk: поиск должен идти по chunk-векторам, но rollup и ACL-фильтрация — по `object_id`. Это означает двухэтапный запрос: `SELECT DISTINCT object_id ORDER BY min_distance LIMIT K` из chunk-таблицы, затем ACL-фильтр на уровне SMP API.

## Источники

- [primary] `content/30-requirements/functional/uc1-scheduled-vectorization.md` — FR-004/005/006, BR-001/002/003, whitelist baseline
- [primary] `content/30-requirements/functional/uc2-similarity-search.md` — BR-002 (kbAccesses), FR-005 (cross-class)
- [primary] `content/30-requirements/functional/uc3-duplicate-detection.md` — FR-001..015, пороги сходства
- [primary] `content/30-requirements/non-functional/nfr-cross-cutting.md` — NFR-013 (чанкинг), NFR-020 (идемпотентность), NFR-032 (whitelist-версионирование)
- [primary] `content/00-project/adr/004-vector-storage-schema.md` — схема таблицы, chunk_index
- [primary] `content/00-project/adr/005-whitelist-pii-default-deny.md` — whitelist состав и PII-уровни
- [primary] `content/00-project/adr/006-composite-text-composition.md` — формула composite text, чанкинг
- [primary] `content/10-domain/research/smp-metamodel.md` — live метамодель 2026-05-01, связи FQN
- [primary] `content/10-domain/research/yc-foundation-models.md` — smoke 2026-05-01, numTokens=14 на 49 символов
- [primary] `content/10-domain/research/raw/length-distribution-script.groovy` — скрипт для §3
- [secondary] `content/10-domain/research/pgvector-indexes.md` — HNSW параметры, mem оценки
- [secondary] `content/10-domain/research/yc-pricing.md` — калькулятор стоимости
- [secondary] CLAUDE.md — scope модуля, red lines
