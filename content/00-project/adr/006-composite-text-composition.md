---
order: 60
title: "ADR-006: Composite text composition for embedding"
properties:
  - Тип контента: ADR
  - Фаза: PoC
  - Статус: Draft
---

# ADR-006: Composite text composition for embedding

**Status:** Draft
**Date:** 2026-05-01

## Context

После прохождения whitelist-фильтра (ADR-005) модулю нужно собрать из набора разрешённых атрибутов **один текстовый вход** для embedding-модели YC FM. Способ сборки влияет одновременно на качество (Recall@10 / MRR@10 — UC2 NFR-002), детерминированность идемпотентности (UC1 NFR-020 — `composite_hash`), бюджет токенов YC FM (NFR-061) и аудитопригодность (NFR-003).

Из требований и research:
- **UC1 / FR-005** — текст формируется конкатенацией значений whitelisted-атрибутов в фиксированном порядке; пустые/null-значения пропускаются. Решение по разделителю и нормализации richtext — закрепляется в ADR (этот документ).
- **UC1 / FR-006** — если итоговый текст превышает лимит токенов модели, он чанкуется; стратегия агрегации эмбеддингов чанков — отдельный ADR (не в этом документе).
- **NFR-013** — чанкинг обязателен для текстов сверх лимита (~2048 токенов по предварительным данным `yc-foundation-models.md` § 3, требует верификации).
- **NFR-020** — идемпотентность строится на `sha256(composite_text) + model_version + whitelist_version`. Если сборка недетерминирована (порядок атрибутов плавает, разделитель меняется) — `composite_hash` нестабилен и джоба теряет идемпотентность.
- **`smp-metamodel.md` § Композитный текст** — в research предложен черновик формулы; этот ADR его финализирует.

Целевые классы (`knowledgeBase$article`, `problem`, `issue` и подклассы) имеют разный набор атрибутов. Атрибут `title` есть только у `knowledgeBase$*`, `subject` — у `issue` и `problem`, `content` — только у `knowledgeBase$article`. Сборка должна быть достаточно общей, чтобы покрыть все три класса единым алгоритмом, но детерминированной для одного объекта в одной версии whitelist'а.

Richtext-поля (`description`, `content`, `decisionReport`, `workaround`, `rootCause`, `lastComment`) приходят из SMP с HTML-разметкой (`<p>`, `<br>`, `<table>`, иногда `<img>` со src на ассеты). HTML-теги добавляют токены, не несущие семантики (минус по бюджету), и сбивают токенизатор embedding-модели.

## Decision

**Формула сборки** для одного объекта SMP после прохождения `WhitelistEnforcer` (ADR-005):

```
composite_text = join("\n\n", [normalize(value(attr_i)) for attr_i in ordered_whitelist_attrs(class) if value(attr_i) is not blank])
```

**Порядок** — детерминированный, задаётся для каждого FQN-класса в whitelist-конфиге как часть записи (`whitelist[class].attrs = [{name: "title", order: 1}, …]`). Базовый порядок для трёх целевых классов на PoC (опираясь на `smp-metamodel.md`):

- `knowledgeBase$article`: `title` → `description` → `keywords` → `content`.
- `knowledgeBase$section`: `title` → `description` → `keywords`.
- `problem`: `subject` → `workaround` → `rootCause` (medium-атрибуты `description`, `decisionReport` добавляются в конец после sign-off, ADR-005).
- `issue`: `subject` (medium, после sign-off) → `cancelReason`. `description`, `lastComment` для PoC заблокированы (ADR-005).

**Разделитель** — двойной перевод строки (`\n\n`). Большинство embedding-моделей трактуют его как «conceptual separator», что экспериментально лучше одинарного `\n` или пустой склейки для асимметричного retrieval (гипотеза, проверяется в offline-eval по `similarity-eval.md` после первой Dev-итерации).

**Нормализация richtext** (`normalize`):
- HTML-strip: удаление всех тегов с сохранением видимого текстового содержимого; `<br>` и `</p>` заменяются на одинарный `\n`.
- Удаление множественных пробелов и пустых строк подряд (collapse в один пробел / в одну пустую строку).
- Сохранение Unicode-литер (русские буквы, диакритика) как есть.
- Декодирование HTML-entities (`&nbsp;`, `&quot;`, `&#1041;` → пробел / `"` / `Б` соответственно).

**Структурированные блоки в JSON-форме внутри richtext** (если SMP сохраняет такие — open question, требует verify в Dev iter 1) — flatten в plain text; если flatten недетерминирован (например, `Map.entrySet()` в Groovy) — берётся отсортированный по ключу обход. Это требование детерминированности — **жёсткое**, иначе ломается NFR-020.

**Truncation при превышении лимита токенов модели** (значение лимита — open question, NFR-061 / `yc-foundation-models.md` § 3):
- Сначала truncates длинные richtext-поля (`description`, `content`, `decisionReport`, `workaround`, `rootCause`) — обрезаются с конца, целиком или до целого предложения.
- В последнюю очередь truncates `title` / `subject` — короткие и семантически плотные поля.
- Если после max-truncation текст всё ещё превышает лимит — активируется чанкинг (UC1 / FR-006), стратегия чанкинга — отдельный ADR.

**Хеш `sha256(composite_text)`** — нормализованный композит после truncation и до чанкинга. Этот хеш — основной компонент `composite_hash` идемпотентности (UC1 / NFR-020), наряду с `whitelist_version` и `model_version`.

## Consequences

**Positive:**
- Просто и детерминированно: одна функция от (FQN, whitelist_version, набор значений атрибутов) → текст; легко тестируется unit-тестами без SMP.
- Легко аудитировать: composite_text при необходимости можно реконструировать из значений атрибутов и whitelist-конфига; в логи аудита (NFR-003) пишется длина и hash, сам текст не пишется (NFR-004).
- Совместимо с asymmetric retrieval (`text-search-doc` / `text-search-query` из `yc-foundation-models.md` § 2): ту же формулу применяет UC2 для индексации (doc) и для запросов (query) на free-text — единый код-пут.
- Чёткая deterministic-граница для truncation: длинные richtext обрезаются первыми — `title`/`subject` максимально сохраняются как «семантический якорь».

**Negative:**
- Потеря структурной информации richtext: таблицы, списки, заголовки flatten в plain text — embedding теряет визуальные/структурные сигналы. Гипотеза «для русских заявок и KB этого достаточно» — проверяется offline-eval, не предзадаётся.
- Truncation отрезает «хвост» длинных полей — если ключевая информация описана в конце `description`, она не попадёт в эмбеддинг.
- HTML-strip удаляет атрибуты тегов, которые иногда несут семантику (`<a href="...">` — может быть ссылка на смежную KB-статью).

**Mitigations:**
- В offline-eval первой Dev-итерации сравнить plain-text сборку и markdown-сборку (с сохранением заголовков и списков как `# ` / `- `) на ground truth `issue.duplicates` (UC3 / BR-002). Решение по итогам — отдельный ADR-text-normalization (если markdown даст значимый прирост).
- При truncation писать в audit-log поле `truncated: true` с количеством обрезанных символов — для post-hoc анализа корреляции «truncated → падение recall».
- Для `<a href>`-ссылок в KB рассмотреть отдельный сигнал (граф ссылок на смежные статьи) — out of scope этого ADR, потенциально новый use case.

## Alternatives Considered

- **Отдельные эмбеддинги per attribute и weighted-mean.** Каждый атрибут эмбеддится отдельно (`title`, `description` и т. д.), на выходе — взвешенное среднее. Отвергнуто: ×N стоимость YC FM при тех же объёмах, требует подбора весов на тюнинге, для модели `text-search-doc` ломает asymmetric pattern. Overkill для PoC.
- **Markdown-форматирование с разделителями (`# {title}\n\n## description\n\n…`).** Отвергнуто как стартовый вариант: добавляет токены (`# `, `## `), не улучшая качество для русскоязычной модели — гипотеза, основанная на сегменте русскоязычных embedding-моделей (требует подтверждения offline-eval). При подтверждении пользы — может быть принят отдельным ADR.
- **JSON-форма (отправка структурированного `{title: "...", description: "...", …}`).** Отвергнуто: `text-search-doc` обучен на естественных текстах, JSON-структура снижает качество эмбеддинга; кроме того, JSON-обвязка съедает токены без семантической нагрузки.
- **Truncation с начала, а не с конца длинных полей.** Отвергнуто: эвристика «head важнее tail» работает для KB-статей и `description` пользовательских заявок; обрезка с начала часто отрезает заголовок проблемы.

## Связанные статьи

- [UC1 — Scheduled vectorization](../../30-requirements/functional/uc1-scheduled-vectorization) — FR-005 (композитный текст), FR-006 (чанкинг), NFR-UC1-002 (бюджет YC FM).
- [UC2 — Similarity search](../../30-requirements/functional/uc2-similarity-search) — free-text запросы (FR-002) используют ту же формулу для входного текста.
- [UC3 — Duplicate detection](../../30-requirements/functional/uc3-duplicate-detection) — ad-hoc embedding регистрируемой заявки (BR-006) использует ту же формулу.
- [Cross-cutting NFR](../../30-requirements/non-functional/nfr-cross-cutting) — NFR-013 (чанкинг), NFR-020 (идемпотентность через `composite_hash`), NFR-061 (бюджет токенов).
- [SMP метамодель](../../10-domain/research/smp-metamodel) — § Композитный текст, открытый вопрос Q4 (нормализация richtext).
- [Similarity evaluation](../../10-domain/research/similarity-eval) — методология offline-eval, по которой проверяется гипотеза «plain vs markdown vs structured».
- [YC Foundation Models](../../10-domain/research/yc-foundation-models) — § 3 (лимиты токенов, открытый вопрос по точному значению).
- [ADR-005: Whitelist + PII default-deny](005-whitelist-pii-default-deny) — вход для этой формулы; сборка композита запускается только через `WhitelistEnforcer`.
- ADR-007 (model versioning + migration) — `model_version` участвует в `composite_hash` совместно с хешем композита.
