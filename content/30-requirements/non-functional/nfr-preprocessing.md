---
order: 60
title: "NFR — Preprocessing-политика (нормализация текста)"
properties:
  - Тип контента: Требование
  - Фаза: PoC
  - Статус: Draft
---

# NFR — Preprocessing-политика (нормализация текста)

Политика нормализации текстов SMP-объектов перед отправкой в Yandex Cloud Foundation Models. Применяется во всех UC-V* (векторизация). Ссылаются: UC-V1 FR-005, UC-V2 FR-001, `composite_hash` (NFR-020 в `content/30-requirements/non-functional/nfr-cross-cutting.md`).

## Контекст и мотивация

### Постановка вопроса

SMP-атрибуты имеют разные форматы: richtext (HTML), plain text, RTF. Перед отправкой в YC FM необходимо решить, какой формат подавать на вход модели. Кандидаты:

- **Plain text** — HTML-strip, оставить только текст.
- **Markdown** — конвертация HTML → markdown (flexmark или аналог), сохранить структуру заголовков и списков.
- **Mixed** — KB.content → markdown (где структура важна), issue.* и comment → plain text.

### Литобзор: что делают RAG-фреймворки

**LangChain** (RecursiveCharacterTextSplitter, HTMLHeaderTextSplitter): для длинных KB-документов рекомендует конвертировать HTML → markdown перед чанкингом, чтобы сохранить семантику заголовков (`<h2>` → `##`). Для коротких текстов (< 200 токенов) — plain text достаточен.

**LlamaIndex** (HTMLNodeParser, MarkdownNodeParser): аналогичная стратегия — HTML → markdown для структурированных документов, plain для неструктурированных. SentenceWindowNodeParser: всегда plain text (разбивка по предложениям, markdown-теги мешают).

**Unstructured.io** (2024): рекомендует strip HTML → plain text для embedding-задач (векторный поиск), сохранять markdown только для LLM-задач (summarization, Q&A). Обоснование: embedding-модели (в т.ч. `text-search-doc`) обучены на plain text; markdown-символы (`#`, `*`, `-`) воспринимаются как токены и могут вносить шум.

**Weaviate chunking guide**: для richtext HTML — конвертация в plain text или markdown до чанкинга. Markdown предпочтительнее при сохранении документальной структуры.

**Microsoft Azure RAG best practices**: HTML normalization before chunking обязательна. Конкретный выбор plain vs markdown — «по содержанию»: информационные KB-статьи → markdown; operational logs / ticket descriptions → plain.

### Trade-off по трём измерениям

| Измерение | Plain text | Markdown | Mixed (KB=md, issue/comment=plain) |
|---|---|---|---|
| Семантическое качество embedding | Потеря структуры документов KB (заголовки, списки, таблицы) | Сохранение структуры KB; для issue/comment структуры нет → markdown = plain + лишние символы | Оптимально для каждого типа |
| Стоимость токенов | Базовая | +5–15 % за markdown-теги | KB: +5–15 %; issue/comment: 0 % |
| Whitelist-аудит / PII | Чище: URL'ы, ссылки, emoji удаляются при HTML-strip | Остаются URL'ы из `<a href>`, emoji в markdown | Mixed: KB-ссылки могут содержать URL → PII-риск при KB; issue/comment — чисто |
| Детерминированность composite_hash | Однозначна при фиксированном алгоритме strip | Зависит от HTML→markdown-конвертора (flexmark/marked) | Требует отдельный algorithm_version per payload-тип |

## Рекомендация для PoC

**Выбранная стратегия: Mixed (вариант C из BA-002 §3).**

| Payload | Формат на вход YC FM | Алгоритм |
|---|---|---|
| `issue.*` (composite_extended) | **Plain text** | HTML-strip (jsoup или аналог), collapse whitespace, trim |
| `problem.*` | **Plain text** | Те же правила |
| `comment.text` | **Plain text** | HTML-strip, collapse whitespace |
| `knowledgeBase$article.content` | **Markdown** | HTML → markdown (flexmark-java `HtmlRenderer`), затем normalize |
| `knowledgeBase$article.title/description/keywords` | **Plain text** | HTML-strip, collapse whitespace |

**Обоснование:**
- `issue` и `comment` — неструктурированный текст (операционные описания, тред переписки). p95 = 209 токенов — маловато для семантики разметки. Plain text KISS и соответствует Unstructured.io-рекомендации.
- `KB.content` — HTML richtext с заголовками и списками. 47,8 % > 2 048 токенов → обязательный chunking. Markdown сохраняет структурные сигналы между чанками и соответствует LangChain/LlamaIndex best practices для KB-документов.
- PII: URL'ы в KB.content markdown остаются → нужна явная фильтрация ссылок при PII-аудите KB-whitelist (см. OQ-PRE-2).

**Pересмотр после offline-eval:** финальный выбор фиксируется в ADR (ADR-preprocessing) после offline-eval (DEV-033). Если offline-eval покажет, что plain text для KB не уступает markdown по Recall@10 → упростить до uniform plain.

## Правила нормализации

### Plain text pipeline

```
input (HTML / plain) →
  1. html_strip(jsoup.parse(text).text())       — удалить все HTML-теги
  2. collapse_whitespace(text)                   — заменить \t, \n, \r, множественные пробелы → одиночный пробел
  3. trim(text)                                  — убрать leading/trailing whitespace
  4. если result.isEmpty() → return null         — пустой текст не отправляется в YC FM
output: normalized plain text string
```

### Markdown pipeline (только KB.content)

```
input (HTML richtext) →
  1. flexmark_convert(HTML → markdown)           — HtmlRenderer (flexmark-java), опции: no_inline_images, no_tables_as_html
  2. strip_html_remnants(text)                   — удалить незаконвертированные HTML-теги (safety net)
  3. normalize_headings(text)                    — убедиться, что h1→#, h2→##, etc.
  4. collapse_multiple_newlines(max=2)           — не более двух последовательных пустых строк
  5. trim(text)
  6. если result.isEmpty() → return null
output: normalized markdown string
```

### Инварианты (обязательны для всех pipeline)

- **Детерминированность.** Один и тот же входной текст → всегда один и тот же выход. Ни randomness, ни state между вызовами.
- **Idempotency.** Повторное применение pipeline к уже нормализованному тексту не меняет результат.
- **Null/empty safety.** Пустой или null input → return null (не отправлять в YC FM, не записывать вектор).
- **No PII leakage.** После нормализации полученный текст должен проходить через whitelist-фильтр (UC-V1 FR-004) — только тогда отправляется в YC FM.
- **Отсутствие потери порядка атрибутов.** Composite-текст формируется в фиксированном порядке (порядок whitelist), нормализация не меняет порядок конкатенации.

## Версионирование preprocessing

`algorithm_version` входит в `composite_hash` (BR-006 UC-V1):

```
composite_hash = sha256(
    normalized_text
    + "|" + model_version
    + "|" + whitelist_version
    + "|" + chunk_size (если chunking)
    + "|" + overlap (если chunking)
    + "|" + algorithm_version   // например "v1.0-plain" или "v1.0-mixed"
)
```

**Текущая версия preprocessing для PoC:** `algorithm_version = "v1.0-mixed"`.

При любом изменении алгоритма (например, переход с Mixed на Pure plain, или обновление flexmark) — `algorithm_version` инкрементируется → все `composite_hash` инвалидируются → джоба UC-V1 пересчитывает векторы при следующем запуске.

**Практика именования:** `v{MAJOR}.{MINOR}-{strategy}`:
- `v1.0-mixed` — plain для issue/comment, markdown для KB (PoC baseline)
- `v2.0-plain` — если offline-eval покажет, что plain для KB не хуже → переход с bumped version
- `v1.1-mixed` — если поменяли flexmark-опции, не меняя стратегии

## NFR-требования (локальные)

- **NFR-PRE-001. Детерминированность (инвариант).** При фиксированном `algorithm_version` и одном и том же входном тексте preprocessing ВСЕГДА даёт один и тот же результат. Нарушение — критический дефект.
- **NFR-PRE-002. Idempotency.** Повторный вызов preprocessing на уже нормализованном тексте → идентичный результат.
- **NFR-PRE-003. algorithm_version в composite_hash.** При смене `algorithm_version` все ранее сохранённые хеши инвалидируются (dirty=true для всех объектов затронутых классов).
- **NFR-PRE-004. Нет сырых текстов в логах.** Нормализованный текст не пишется в обычные логи. В аудит-лог пишется только `{length_chars, length_tokens_est, algorithm_version, payload_type}`.
- **NFR-PRE-005. Тестируемость без SMP.** Preprocessing-компонент должен тестироваться unit-тестами без SMP-контекста (изолирован в core/, не в adapters/).

## Acceptance Criteria

- [ ] **AC-PRE-001.** Один и тот же HTML-текст, поданный дважды, даёт идентичный нормализованный результат (NFR-PRE-001).
- [ ] **AC-PRE-002.** `issue.description` с HTML-тегами (`<b>`, `<p>`, `<a href="...">`) после plain-pipeline: нет тегов, нет URL'ов от ссылок, нет лишних пробелов.
- [ ] **AC-PRE-003.** `KB.content` с `<h2>` секциями после markdown-pipeline: заголовки конвертированы в `##`, таблицы → markdown-таблицы, изображения (`<img>`) удалены.
- [ ] **AC-PRE-004.** Пустой / null `comment.text` → null из pipeline; YC FM не вызывается.
- [ ] **AC-PRE-005.** `algorithm_version` изменён (v1.0-mixed → v2.0-plain) → все векторы получают `dirty=true` при следующем запуске джобы UC-V1 (NFR-PRE-003).
- [ ] **AC-PRE-006.** Unit-тест preprocessing работает без SMP-context (только JVM + flexmark dependency) (NFR-PRE-005).

## Открытые вопросы

| # | Статус | Решение / Описание | Адресат |
|---|--------|--------------------|---------|
| OQ-PRE-1 | **Resolved (2026-05-02)** | Decision-by-evidence: финальный выбор plain vs markdown для KB — после offline-eval (DEV-033). До eval: Mixed strategy (текущий baseline) сохраняется. Owner: Демьянов. | SA + BA → ADR-preprocessing |
| OQ-PRE-2 | **Resolved (2026-05-02)** | Помечено на проработку в будущем. Текущее: URL'ы остаются в тексте PoC. Создан OQ-FUTURE-2 «URL/PII-mask в preprocessing» (см. nfr-cross-cutting OQ-FUTURE-2). Owner: Демьянов. | Owner + юр-аудит |
| OQ-PRE-3 | **Resolved (2026-05-02)** | Вариант A — оставить emoji (не strip). Owner: Демьянов. | BA + SA |
| OQ-PRE-4 | **Resolved (2026-05-02)** | Default — flexmark-java (плановый выбор для markdown-стратегии); fallback / verification — jsoup. SA-action: подтвердить наличие flexmark-java в Maven mirror Naumen; если недоступен — jsoup-based custom. Закрепляется в ADR-preprocessing. Owner: Демьянов. | SA → ADR |

## Связи с другими требованиями

- UC-V1 FR-005, FR-008 — ссылаются на эту политику как нормативный документ.
- UC-V2 FR-001 — аналогичная ссылка для comment.text (plain pipeline).
- `content/30-requirements/non-functional/nfr-cross-cutting.md` NFR-020 (idempotency key) — `algorithm_version` входит в `composite_hash`.
- RES-009.2 §7 (OQ-6 детерминированность) — закрывается этим разделом.
