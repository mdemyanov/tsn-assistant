---
order: 20
title: ITSM Knowledge — расширенный глоссарий
properties:
  - Тип контента: Глоссарий
  - Фаза: PoC
  - Статус: Draft
---

# ITSM Knowledge — расширенный глоссарий

База знаний для ITSM-аналитика (`itsm-analyst-agent`). Содержит ITSM-термины, которые **не входят** в основной [глоссарий проекта](glossary.md), но используются при ITSM-валидации use case'ов и архитектурных решений.

> **Назначение.** Файл существует, чтобы не раздувать system prompt субагента (OQ-5 спецификации роли). Базовые ITSM-конвенции проекта зашиты в промт `itsm-analyst-agent.md`; расширенный glossary — здесь, обновляется без смены промта.

## Правила

- Сюда попадают **ITSM-специфичные** термины: ITIL practices, KCS, COBIT, vendor practice (ServiceNow / BMC / Atlassian / Naumen), метрики Service Desk.
- Доменные термины проекта (FQN-объекты SMP, проектные сокращения) — в основной [глоссарий](glossary.md), не сюда.
- Новый термин добавляется ITSM-аналитиком через предложение PM (агент сам файл не правит — это противоречит контракту роли).
- При обнаружении проектного терминологического решения owner'а (например, «RCA = decisionReport в этом проекте») — добавляется сюда с пометкой «локальная конвенция».

## Структура записи

```markdown
### [Термин (EN / RU)]
**Определение:** [1-2 предложения]
**Источник:** ITIL 4 / KCS v6 / ISO 20000 / vendor (ServiceNow / BMC / Atlassian / Naumen) / локальная конвенция
**Уверенность:** [established / emerging / contested]
**Не путать с:** [если есть похожий термин]
**Применение в проекте:** [где встречается / какие UC затрагивает]
```

## Термины

<!-- Добавляй термины в алфавитном порядке. -->

### Локальные конвенции проекта

<!-- Зеркалирует таблицу из itsm-analyst-agent.md — единый источник правды.
     При расхождении приоритет у этого файла; промт обновляется через PM. -->

| SMP-термин | Соответствие ITIL/KCS | Источник конвенции |
|-----------|----------------------|---------------------|
| `issue` | Incident / Service Request (ITIL 4) — базовый класс заявок | Конвенция проекта: `serviceCall` НЕ используется, только `issue` |
| `issue$incident` | Incident (ITIL 4 Incident Management) | Метамодель SMP, RES-001 |
| `issue$SAP`, `issue$equipmentReq`, etc. | Service Request / специализированные подклассы | Метамодель SMP |
| `problem` | Problem (ITIL 4 Problem Management) | Метамодель SMP |
| `decisionReport` (атрибут `issue$incident`) | Closure note / Resolution summary при закрытии заявки | BA-003-m1: НЕ путать с `problem.decisionReport` = RCA |
| `decisionReport` (атрибут `problem`) | RCA / Root Cause Analysis | Локальная конвенция owner'а |
| `knowledgeBase$article` | KCS Article (KCS v6) | Метамодель SMP, KCS principles |
| `knowledgeBase` (раздел) | KB / Article Container | Метамодель SMP |
| `faq$question` | FAQ Entry (KCS v6 deflection pattern) | BA-005 — новый класс, TBD |

---

## Принципы ITIL 4

<!-- TODO: Наполняется ITSM-аналитиком после первого полноценного ревью. -->

<!-- Примеры разделов для наполнения:
### Incident Management (ITIL 4)
...
### Problem Management (ITIL 4)
...
### Knowledge Management (ITIL 4)
...
-->

> Раздел в стадии заполнения. ITSM-аналитик добавляет записи через предложение PM при каждом ревью UC.

---

## KCS v6

<!-- TODO: Наполняется ITSM-аналитиком по мере ревью UC-S3/S4/V1. -->

<!-- Примеры разделов:
### KCS Article Structure
...
### Deflection Rate
...
### Solve Loop vs Evolve Loop
...
-->

> Раздел в стадии заполнения.

---

## Vendor patterns

<!-- TODO: Наполняется по мере валидации UC на соответствие vendor best-practice. -->

<!-- Разделы: ServiceNow Predictive Intelligence, BMC Helix Cognitive, Atlassian JSM Similar Requests, Naumen SMP. -->

> Раздел в стадии заполнения.

---

## ITSM glossary extension

<!-- TODO: Термины, не вошедшие в основной glossary.md и не попавшие в локальные конвенции. -->

<!-- Структура записи:
### [Термин (EN / RU)]
**Определение:** ...
**Источник:** ...
**Уверенность:** established / emerging / contested
**Не путать с:** ...
**Применение в проекте:** ...
-->

> Раздел в стадии заполнения.

---

## Конвенции проекта

> Этот раздел — единый источник правды по терминологическим конвенциям. При расхождении с промтом `itsm-analyst-agent.md` — приоритет здесь; промт обновляется через PM.

- **`issue` vs `serviceCall`:** в проекте используется только `issue` (базовый класс заявок). `serviceCall` — архаичное имя из старых версий SMP, не применяется.
- **`decisionReport` у `issue$incident`:** поле «Отчёт о решении» при закрытии заявки (closure note). Не RCA. RCA — это `problem.decisionReport`.
- **FAQ-класс:** TBD — решается в BA-005. Предполагаемый FQN `faq$question` (Вариант A).

## Открытые вопросы

- OQ-1. Список ITIL practices, релевантных проекту pg_vector_service, нужно зафиксировать после первого ITSM-ревью UC-S2 (single-comment vs composite signal).
- OQ-2. KCS v6 принципы для оценки качества KB-статей (для UC-S3 / UC-S4) — раскрыть после ITSM-ревью соответствующих UC.
