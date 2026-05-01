---
order: 50
title: "ADR-005: Whitelist атрибутов и PII default-deny"
properties:
  - Тип контента: ADR
  - Фаза: PoC
  - Статус: Draft
---

# ADR-005: Whitelist атрибутов и PII default-deny

**Status:** Draft
**Date:** 2026-05-01

## Context

Модуль `pg_vector_service` отправляет тексты SMP-объектов во внешний сервис Yandex Cloud Foundation Models (YC FM) для построения эмбеддингов. Внешняя граница — точка повышенного PII-риска: реальные `issue` на стенде содержат ФИО, телефоны, email, корп-структуру в свободной форме (см. PII-категоризацию в `content/10-domain/research/smp-metamodel.md` — для `issue.description` и `issue.lastComment` риск помечен как `high`). CLAUDE.md фиксирует красную линию: «векторы и сырые тексты, отправляемые в YC FM, проходят через явный список разрешённых атрибутов — никакой автоматической отправки всего объекта целиком».

Из требований:
- **UC1 / FR-004 + BR-001 + BR-005** — джоба векторизует только атрибуты из явного whitelist'а; любая утечка whitelisted-атрибута, не описанного в BR-001, считается дефектом критической степени.
- **NFR-001 / NFR-041 (cross-cutting)** — модуль отправляет в YC FM только текст из per-class whitelist'а; точка выхода в YC FM не имеет «прямого» доступа к произвольным атрибутам.
- **NFR-002** — каждый атрибут whitelist'а помечен уровнем PII-риска (low/medium/high); атрибуты high — запрещены к отправке без явного решения owner'а.
- **NFR-032 / BR-cross-3** — изменение whitelist'а инвалидирует затронутые векторы (`status = 'stale'`), пересчёт идёт инкрементально.

В legacy-реализации (см. auto-memory, `baseline_groovy_vector_module`) whitelist отсутствует — в YC FM уходят все richtext-атрибуты целиком. Этот ADR закрывает разрыв между legacy и целевым PoC-режимом и связывает воедино правила PII (NFR-001/002), идемпотентность (NFR-020) и инвариант компиляции (ADR-001 — `EmbeddingProviderPort` принимает только готовый `ComposedText`).

## Decision

Принимается **PII default-deny**: атрибут SMP-объекта попадает в композитный текст для YC FM **только** если он явно перечислен в whitelist-конфигурации текущей версии модуля. Все остальные атрибуты — игнорируются на этапе сборки композита, в payload YC FM не попадают.

**Состав whitelist-записи** (нормативные поля):
- FQN целевого класса (`knowledgeBase$article`, `problem`, `issue` и подклассы — см. UC1 / FR-002).
- Имя атрибута (как в метамодели SMP).
- PII-уровень (`low` / `medium` / `high`) — берётся из `smp-metamodel.md`.
- Признак «разрешён к отправке» — `true` для `low` по умолчанию, для `medium` требует sign-off owner'а, для `high` — заблокирован для PoC и требует отдельного управленческого решения с фиксацией в whitelist-конфиге.

**Версионирование.** Whitelist привязан к версии (`whitelist_version`, монотонно возрастающее целое или semver-строка). `whitelist_version` участвует в `composite_hash` (см. NFR-020): любое расширение / сужение whitelist'а — это новая версия. При смене версии затронутые объекты помечаются как требующие пересчёта (NFR-032), джоба UC1 пересчитывает их в следующий запуск.

**Базовый whitelist для PoC** (источник: `smp-metamodel.md` сводная таблица + UC1 / BR-001):

| Класс | Атрибуты `low` | Атрибуты `medium` (sign-off) | Атрибуты `high` (заблокированы PoC) |
|---|---|---|---|
| `knowledgeBase$article` | `title`, `description`, `content`, `keywords` | — | — |
| `knowledgeBase$section` | `title`, `description`, `keywords` | — | — |
| `problem` | `subject`, `workaround`, `rootCause` | `description`, `decisionReport` | — |
| `issue` (и подклассы) | `cancelReason` | `subject`, `feedback`, `decisionReport` | `description`, `lastComment` |

**Архитектурное закрепление.** Единственная точка фильтрации — компонент `WhitelistEnforcer` в `core/vectorization/`. Он принимает SMP-объект (через `SmpReadPort`, ADR-001) и `whitelist_version`, возвращает `ComposedText` (тип-контракт из ADR-001) или ошибку «атрибут не разрешён». `EmbeddingProviderPort` принимает только `ComposedText`; иной путь сборки текста для YC FM не существует на уровне типов. Обход `WhitelistEnforcer` в `core/` — нарушение архитектуры, ловится статическим тестом `WhitelistInvariantSpec` (по образцу `CoreBoundarySpec` из эталона, см. ADR-001).

**Формат конфигурации whitelist'а** — open question (решается в отдельном ADR-config-whitelist при первой Dev-итерации). Кандидаты: YAML-resource в JAR, JSON в SMP-объекте конфигурации, Groovy-DSL. Этот ADR фиксирует семантику и не предзадаёт формат хранения.

## Consequences

**Positive:**
- Защита от PII-утечки на уровне типов: невозможно «случайно» передать в YC FM весь объект (ADR-001 `ComposedText` + этот ADR).
- Простой rollback при обнаружении проблемы: достаточно убрать атрибут из whitelist'а и bumpнуть `whitelist_version` — следующий запуск UC1 перепосчитает векторы без удалённого атрибута, за один цикл джобы.
- Аудитопригодность: версия whitelist'а пишется рядом с вектором (NFR-030/032), всегда можно ответить «какие атрибуты ушли в YC FM по объекту X на момент Y».
- Соответствие NFR-001/002/041 без необходимости периодического code review: инвариант проверяется компилятором + статическим тестом.

**Negative:**
- Ручное обслуживание whitelist'а: при появлении нового полезного атрибута нужен явный шаг управления (sign-off owner'а для `medium`, юр-аудит для `high`) — это замедляет добавление функциональности.
- Риск пропуска полезного атрибута: если в `medium` есть нужный для качества контент (например, `issue.subject`), но sign-off задерживается — качество UC2/UC3 deteriorates на этапе PoC.
- Снижение recall в UC2/UC3 на классе `issue` относительно теоретического максимума, поскольку `description` (high-PII, заблокирован) — носитель основной семантики заявки.

**Mitigations:**
- Review whitelist'а на каждой Dev-итерации (паттерн «gate per class» из UC1 / FR-003: kb → problem → issue).
- Обновление whitelist'а по итогам smoke-замеров: если на корпусе KB и `problem` метрики Recall@10 / MRR@10 (UC2 NFR-002) выходят на целевые значения без `issue.description`, гипотеза «high-PII атрибуты не нужны» подтверждается; в обратном случае — отдельный управленческий цикл по PII-маскированию (см. ADR-pii-masking из NFR cross-cutting § 1).
- В состав unit-тестов добавляется фикстура «PII-инвариант» (UC1 / AC-008): объект `issue` с заполненным `description` и пустым `subject` — payload, переданный `EmbeddingProviderPort`, не содержит `description`.

## Alternatives Considered

- **Open-by-default + blocklist для PII.** Все текстовые атрибуты идут в YC FM по умолчанию, перечисляются только запрещённые. Отвергнуто: нарушает CLAUDE.md «никакой автоматической отправки всего объекта целиком», нарушает NFR-001/041 (default-deny — обязательное требование), увеличивает риск утечки при добавлении новых атрибутов в метамодель SMP (новый атрибут попадает в YC FM до того, как его проаудитили).
- **Runtime PII-классификатор (ML-модель определяет, есть ли в тексте ФИО/email/телефон).** Отвергнуто: слишком сложно для PoC; ML-bias-риск (модель пропустит редкие форматы PII); добавляет внешнюю зависимость. Рассматривается как возможное расширение для PII-маскирования medium-атрибутов в Pilot-фазе, не в PoC.
- **Whitelist на уровне строки (regexp-фильтр PII внутри атрибута).** Отвергнуто для PoC: добавляет недетерминизм в `composite_hash` (один и тот же атрибут с одним и тем же контентом может дать разный текст после маскирования при изменении regexp-конфига), ломает идемпотентность UC1 / FR-008. Может появиться в отдельном ADR-pii-masking как опт-ин для medium-атрибутов после PoC.

## Связанные статьи

- [UC1 — Scheduled vectorization](../../30-requirements/functional/uc1-scheduled-vectorization) — FR-004 (whitelist обязателен), BR-001 (baseline whitelist), BR-005 (атрибуты вне whitelist'а никогда не уходят), AC-008 (PII-инвариант, автоматическая проверка).
- [UC2 — Similarity search](../../30-requirements/functional/uc2-similarity-search) — BR-008 (UC2 переоценивается при изменении whitelist'а).
- [UC3 — Duplicate detection](../../30-requirements/functional/uc3-duplicate-detection) — BR-006 (UC3 не расширяет PII-периметр).
- [Cross-cutting NFR](../../30-requirements/non-functional/nfr-cross-cutting) — NFR-001 (whitelist default-deny), NFR-002 (PII-уровни), NFR-032 (версионирование whitelist'а), NFR-041 (PII-инвариант на границе адаптера), BR-cross-1, BR-cross-3.
- [SMP метамодель](../../10-domain/research/smp-metamodel) — таблицы PII-категоризации для issue, knowledgeBase, problem; сводный whitelist кандидатов.
- [ADR-001: Hexagonal layout](001-hexagonal-architecture) — `EmbeddingProviderPort` принимает `ComposedText`, не SMP-объект; границу обеспечивает `CoreBoundarySpec` + `WhitelistInvariantSpec` этого ADR.
- ADR-006 (composite text composition) — формула сборки текста после прохождения whitelist-фильтра.
- ADR-009 (decision frame для embedding-модели) — `whitelist_version` и `model_version` совместно образуют `composite_hash`.
