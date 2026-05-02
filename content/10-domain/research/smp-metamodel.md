---
order: 1
title: "Метамодель целевых SMP-классов (issue, knowledgeBase, problem)"
properties:
  - Тип контента: Исследование
  - Фаза: PoC
  - Статус: Draft
---

# Метамодель целевых SMP-классов

Live-разведка через MCP `naumen-smp-dev-admin` (`metamodel_export_class`, `metamodel_export_tree`) на стенде `https://llm2.itsm365.com`.

| Параметр | Значение |
|---|---|
| Дата выгрузки | 2026-05-01 |
| Стенд | `https://llm2.itsm365.com` |
| MCP `metamodel` модуль | v2.1.0 |
| Источник методов | `metamodel_export_class` (compact, scope=own), `metamodel_export_tree` (subclasses, depth=2) |

## Сводная таблица целевых классов

| FQN | Parent | WF | Resp | Attrs (own) | Подклассы | Ключевые текстовые атрибуты |
|-----|--------|:--:|:----:|:-----------:|-----------|-----------------------------|
| `issue` | `abstractBO` | ✓ | ✓ | ~83 own | `issue$issue`, `issue$incident`, `issue$SAP`, `issue$equipmentReq` | `subject`, `description`, `feedback`, `decisionReport`, `lastComment`, `cancelReason` |
| `knowledgeBase` | `abstractBO` | ✓ | ✓ | 10 own | `knowledgeBase$article`, `knowledgeBase$section` | `description`, `content`, `keywords` |
| `problem` | `abstractBO` | ✓ | ✓ | 18 own | `problem$problem` | `subject`, `description`, `workaround`, `decisionReport`, `rootCause` |

**Легенда:** WF — есть workflow; Resp — есть атрибут responsible; own — собственные атрибуты (не наследованные и не системные); UI — обязательно при заполнении формы (не на уровне БД).

## issue — Заявка

> **FQN:** `issue` | **Parent:** `abstractBO` | **Subclasses:** 4 | **Атрибуты:** 100 total (own + system)

### Подклассы (children)

- `issue$issue` — Заявка (родовой)
- `issue$incident` — Инцидент
- `issue$SAP` — Запрос доступа в SAP
- `issue$equipmentReq` — Заявка на новое оборудование

<note type="info">

В семействе issue более 4 подклассов в реальной экосистеме (например, `issue$newUserrequest`, `issue$reqForOutput` — встречались на стендах с другой конфигурацией). На стенде `llm2` зарегистрированы только 4 — фиксируем как baseline для PoC.

</note>

### Кандидаты на векторизацию (текстовые атрибуты)

| Атрибут | Тип | Required | Назначение | PII-риск |
|---------|-----|----------|------------|:--------:|
| `subject` | string | UI | Тема заявки — короткий заголовок | **средний** (имена/контакты в свободной форме) |
| `description` | richtext | — | Полное описание проблемы пользователя | **высокий** (контактные данные, ФИО, корп-информация) |
| `feedback` | richtext | — | Комментарий пользователя к оценке | **средний** |
| `decisionReport` | richtext | — | Отчёт о решении (внутренний) | **средний** (имена сотрудников) |
| `lastComment` | richtext | — | Последний комментарий по заявке | **высокий** |
| `cancelReason` | richtext | UI | Причина отмены | низкий |
| `newsInformer` | richtext | — | Новостной информер (системный) | низкий |
| `keywords` (нет в issue) | — | — | — | — |

<note type="warning">

В заявках систематически содержатся ПДн клиентов: ФИО, телефон, email, корп-структура. Перед отправкой в Yandex Cloud FM требуется PII-аудит и явная whitelist'а атрибутов (BA-задача). По умолчанию — **никаких** ПДн в эмбеддингах PoC; для description/lastComment рассмотреть редактирование (mask-replace ФИО / email / телефон) или их полное исключение из векторизации в первой итерации.

</note>

### Workflow

`issue` имеет workflow и атрибут `responsible`. Конкретные статусы и переходы выгружать в SA-фазе (через `metamodel_export_class` с секцией `workflow`).

### Связи (Relationships) — потенциальные сигналы для кластеризации

- `slmService` (object → `slmService`) — Услуга, по которой создана заявка. Required.
- `agreement` (object → `agreement`) — Договор. Required.
- `clientOU` (object → `ou`) — Заказчик (организация).
- `clientEmployee` (object → `employee`) — Контактное лицо.
- `assets` (boLinks → `asset`) — Связанные активы.
- `duplicates` / `duplicatesRL` — встроенный механизм SMP для маркировки дубликатов (использовать как ground truth для оценки качества кластеризации).
- `linkClosedSC` (object → `issue`) — заявка-предшественник (продолжение).
- `problems` (backBOLinks → `problem`) — обратная ссылка на связанную проблему.

## knowledgeBase — База знаний

> **FQN:** `knowledgeBase` | **Parent:** `abstractBO` | **Subclasses:** 2 | **Атрибуты:** 27 total

### Подклассы

- `knowledgeBase$article` — Статья (основной носитель контента)
- `knowledgeBase$section` — Раздел (контейнер)

### Кандидаты на векторизацию

| Атрибут | Тип | Required | Назначение | PII-риск |
|---------|-----|----------|------------|:--------:|
| `keywords` | text | — | Ключевые слова статьи | низкий |
| `description` | text | — | Краткое описание | низкий |
| `content` | richtext | — | Полный текст статьи | низкий (KB — корп-знания) |

**Системный атрибут `title`** — название статьи/раздела. Используется в [Список] Краткий и в [Мобильное приложение]. Стоит включить в композитный текст для эмбеддинга.

### Workflow

3 статуса: `registered` (initial) → `published` ↔ `closed` (final). Все переходы двусторонние, кроме закрытия.

### Связи

- `parent` (object → `knowledgeBase`) — иерархия (раздел → подраздел → статья). Влияет на скоринг похожести (статьи в одном разделе ближе).
- `slmServices` (backBOLinks → `slmService`) — обратная ссылка от услуг. Полезно для cross-domain similarity (заявка по услуге X → статья KB про услугу X).
- `kbAccesses` (catalogItemSet → `kbAccess`) — права доступа. **Учитывать в similarity-поиске:** не возвращать пользователю векторно-похожую статью, к которой у него нет доступа.

## problem — Проблема

> **FQN:** `problem` | **Parent:** `abstractBO` | **Subclasses:** 1 | **Атрибуты:** 35 total

### Подклассы

- `problem$problem` — родовая проблема (единственный подкласс на стенде).

### Кандидаты на векторизацию

| Атрибут | Тип | Required | Назначение | PII-риск |
|---------|-----|----------|------------|:--------:|
| `subject` | string | UI | Тема проблемы | низкий |
| `description` | richtext | UI | Описание проблемы | средний (могут попадать имена) |
| `workaround` | richtext | — | Описание обходного решения | низкий |
| `decisionReport` | richtext | — | Отчёт о решении | средний |
| `rootCause` | richtext | — | Корневая причина | низкий |

<note type="info">

Для problem PII-риск ниже, чем для issue: проблема — внутренний инцидент-management, а не клиентское обращение. `description`/`decisionReport` могут содержать имена сотрудников ИТ. Аудит в BA остаётся обязательным, но whitelist может быть шире, чем для issue.

</note>

### Workflow

7 статусов: `registered` (initial) → `onDiagnostics` → `inProgress` / `onDecision` / `postponed` → `resolved` → `closed` (final).

### Связи

- `issues` (boLinks → `issue`) — заявки, породившие проблему. **Сильный сигнал** для кластеризации: похожие заявки часто указывают на одну проблему.
- `slmServices` (boLinks → `slmService`) — затрагиваемые услуги.
- `changeRequests` (boLinks → `changeRequest`) — связанные изменения.
- `assets` (boLinks → `asset`) — затронутое оборудование.

## Сводный whitelist кандидатов (черновик для BA)

| Класс | Безопасные (низкий PII-риск) | Аудит обязателен |
|-------|------------------------------|------------------|
| `issue` | `subject` (с осторожностью), `cancelReason` | `description`, `lastComment`, `feedback`, `decisionReport` |
| `knowledgeBase$article` | `title`, `description`, `content`, `keywords` | — (KB обычно без ПДн) |
| `knowledgeBase$section` | `title`, `description`, `keywords` | — |
| `problem` | `subject`, `workaround`, `rootCause` | `description`, `decisionReport` |

**Рекомендация для PoC-итерации 1:** начать с `knowledgeBase$article` (PII-нейтральный класс) — даст быструю проверку всей цепочки (текст → эмбеддинг → pgvector → similarity-поиск) без блокеров от юр-аудита.

## Композитный текст для эмбеддинга

Эмбеддинг одного объекта = конкатенация выбранных атрибутов через разделитель. Черновик формата (на проработку SA):

```
{title}\n\n{subject}\n\n{description}\n\n{content_or_workaround_or_decisionReport}
```

**Открытый вопрос:** richtext-поля содержат HTML-разметку (`<p>`, `<br>`, `<table>`). Перед отправкой в YC FM — нормализация в plain text или сохранение структуры (повлияет на качество эмбеддинга). Решается в `/sa adr text-normalization`.

## Открытые вопросы

| # | Вопрос | Кому |
|---|--------|------|
| Q1 | Какие подклассы issue **реально используются** на стенде `llm2` (count объектов на класс)? | DevOps / live `issue_query_stats` |
| Q2 | Объём текста на объект — статистика по `description.length` для issue / problem / kb-article | Researcher / `issue_find` + `kb_search` с выборкой |
| Q3 | Whitelist атрибутов: какие текстовые поля разрешены к отправке в YC FM (по issue) | BA + юр-аудит (Демьянов) |
| Q4 | Нормализация richtext: HTML → plain или JSON-схема | SA |
| Q5 | Стратегия для подклассов: один общий векторный индекс на семейство (`issue.*`) или раздельные таблицы | SA |
| Q6 | Использовать ли SMP-механизм `duplicates` / `duplicatesRL` как ground truth для evaluation качества кластеризации | BA + Researcher |
| Q7 | Учитывать `kbAccesses` при similarity-поиске на стороне SMP API или в pgvector-фильтре | SA |

## Источники

- `metamodel_export_class` — issue, knowledgeBase, problem (compact, scope=own)
- `metamodel_export_tree` — issue/kb/problem (subclasses, depth=2)
- Эталон формата: `/Users/mdemyanov/knowlage/sd-ai-assistant/content/50-integrations/smp-mcp/pirelli-metamodel.md` (стенд Pirelli, refresh 2026-04-28)
- Полный дамп tree для issue (большой, 90 KB): `~/.claude/projects/-Users-mdemyanov-Devel-pg-vector-service/.../tool-results/mcp-naumen-smp-dev-admin-metamodel_export_tree-1777626221065.txt` (служебный — не публикуется в `content/`)

---

*Refresh procedure:* при следующем запросе live-метамодели — повторить вызовы `metamodel_export_class` для каждого FQN с `attributesScope=["own"]` и `metamodel_export_tree` с `traversal=subclasses depth=2`. Обновить таблицы и дату выгрузки в шапке.
