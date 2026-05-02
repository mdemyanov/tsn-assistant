---
order: 16
title: "BA-005 — Проектирование FAQ-класса"
properties:
  - Тип контента: Требование
  - Фаза: PoC
  - Статус: Draft
  - Сценарий: D-Catalog
---

# BA-005 — Проектирование FAQ-класса

> **Задача создана:** 2026-05-02 по итогам owner-decision OQ-ITSM-5 / OQ-FAQ (BA-004).
> **Блокируемые UC:** UC-S3 (`content/30-requirements/functional/uc-s3-find-similar-faq.md`) — не проектируется в деталях до закрытия этой задачи.
> **Предполагаемый результат:** owner-confirmed decision: отдельный SMP-класс `faq$question` (Вариант A) vs признак `type=question` на `knowledgeBase$article` (Вариант B).

## JTBD (owner)

Когда оператор регистрирует заявку и ищет быстрый ответ из каталога частых вопросов, я (owner, Демьянов) хочу иметь чёткую объектную модель FAQ-класса в SMP с поддержкой ссылок на связанные материалы (KB-статьи, услуги, проблемы), чтобы модуль `pg_vector_service` мог векторизовать FAQ-записи и возвращать их в UC-S3 с семантическим качеством, а операторы — находить релевантные ответы без ручного поиска.

## Требования owner'а к FAQ-классу

1. **Атрибуты:** не только `question` + `answer`, но и **ссылки на связанные материалы**:
   - ссылка на KB-статью (1..N `knowledgeBase$article`)
   - ссылка на услугу (0..N `slmService`)
   - ссылка на проблему (0..N `problem`)
2. **Отдельный класс** (вероятный Вариант A: `faq$question`) — позволяет иметь чистую модель и независимый ACL, расширять атрибуты (rating, source, lifecycle-статус).
3. **Финальное решение — после совместной аналитики**: BA + SA + ITSM-консультант → согласование с Сахабетдиновым (DevOps) о создании класса в SMP.

## Подзадачи

### Подзадача 1 — JTBD на FAQ (BA)

Сформулировать JTBD для трёх ролей-потребителей FAQ:
- Оператор Service Desk (кто создаёт записи, кто читает на форме регистрации)
- Администратор базы знаний (жизненный цикл: черновик → опубликовано → архив)
- pg_vector_service (потребитель API для векторизации)

**Вопросы для JTBD-анализа:**
- Кто создаёт FAQ-записи? Оператор? Аналитик KB? Автоматически из `decisionReport`?
- Как часто обновляется FAQ? Нужен ли lifecycle (draft → published → archived)?
- Нужен ли rating / feedback («помогло / не помогло»)?

### Подзадача 2 — Схема атрибутов (BA + SA)

Спроектировать минимальный набор атрибутов для PoC-версии класса:

| Атрибут | Тип | Обязательный | Описание |
|---------|-----|:---:|---------|
| `question` | richtext / string | да | Текст вопроса |
| `answer` | richtext | да | Текст ответа |
| `status` | enum (draft/published/archived) | да | Жизненный цикл |
| `relatedArticles` | link → `knowledgeBase$article` | нет | Связанные KB-статьи |
| `relatedServices` | link → `slmService` | нет | Связанные услуги |
| `relatedProblems` | link → `problem` | нет | Связанные проблемы |
| `keywords` | string | нет | Теги для keyword-поиска |
| `createdAt` | datetime | да | Дата создания |
| `modifiedAt` | datetime | да | Дата изменения |

> Схема предварительная — финализируется по итогам ITSM-ревью и согласования с Сахабетдиновым.

### Подзадача 3 — ITSM best-practice (ITSM-консультант)

Запросить у ITSM-аналитика ревью по:
- KCS Article structure: как KCS v6 рекомендует структурировать FAQ-записи
- ServiceNow KB Article linking: как в ServiceNow реализована привязка FAQ → KB → CI → Service
- BMC Helix: FAQ в контексте Service Catalog
- Рекомендация по lifecycle-статусам (draft/published/archived vs ITIL Knowledge Management lifecycle)

### Подзадача 4 — Согласование с Сахабетдиновым (DevOps)

- Создание нового FQN-класса `faq$question` в SMP: сколько времени занимает? Есть ли ограничения?
- Настройка ACL для нового класса: публичные FAQ vs защищённые
- Доступность через MCP `naumen-smp-dev-admin` для тестов

## Acceptance Criteria (для BA-005)

- [ ] **AC-BA005-001.** JTBD для FAQ-класса сформулированы (минимум 2 роли: оператор + администратор KB).
- [ ] **AC-BA005-002.** Схема атрибутов включает обязательные поля (`question`, `answer`, `status`) и поля связей (`relatedArticles`, `relatedServices`, `relatedProblems`).
- [ ] **AC-BA005-003.** ITSM-аналитик провёл ревью структуры и дал рекомендации по KCS v6 article structure.
- [ ] **AC-BA005-004.** Сахабетдинов подтвердил возможность создания класса `faq$question` в SMP и сроки.
- [ ] **AC-BA005-005.** Owner принял решение: Вариант A (`faq$question`) или Вариант B (`knowledgeBase$article` + `type=question`).
- [ ] **AC-BA005-006.** UC-S3 обновлён: FAQ-класс заменён конкретным FQN и схемой по итогам BA-005.
- [ ] **AC-BA005-007.** Новые термины добавлены в `content/10-domain/glossary.md`.

## Открытые вопросы

| # | Вопрос | Адресат | Тип |
|---|--------|---------|-----|
| OQ-BA005-1 | Вариант A (`faq$question`) vs Вариант B (`knowledgeBase$article` + type=question) — финальное решение после аналитики | Owner + Сахабетдинов | owner-decision |
| OQ-BA005-2 | Lifecycle-статусы FAQ: draft/published/archived или другая схема? | BA + ITSM-консультант | BA-decision |
| OQ-BA005-3 | Rating/feedback атрибуты на PoC: включать или defer? | Owner + BA | owner-decision |
| OQ-BA005-4 | Whitelist атрибутов для векторизации FAQ в pg_vector_service (PII-аудит) | BA + Owner | BA-decision |
| OQ-BA005-5 | Минимальный объём FAQ-записей для запуска PoC (связан с OQ-S3-4: ≥ 50) | Owner | owner-decision |

## Зависимости

- Блокирует: `content/30-requirements/functional/uc-s3-find-similar-faq.md` (детальное проектирование SA)
- Блокирует: UC-V1 FR-002 (добавление `faq` в список целевых классов)
- Зависит от: Сахабетдинов (DevOps) — подтверждение создания класса в SMP

## Бриф для SA (после закрытия BA-005)

После принятия owner-decision по Варианту A/B:

**Спроектировать:**
- Регистрация нового FQN-класса `faq$question` в SMP (если Вариант A)
- Схема FAQ-векторов в `pg_vector_service__vectors`: `meta_class = 'faq$question'`, `source_attr = 'question'`
- ACL-механизм для FAQ-записей
- Whitelist атрибутов для векторизации
- API-контракт `FaqSearchRequest` / `FaqSearchResponse` для UC-S3

**Решение по BA-005 закрепится в ADR** (ADR-faq-class или в ADR расширения UC-S3).
