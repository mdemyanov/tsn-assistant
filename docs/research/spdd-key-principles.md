---
title: SPDD — ключевые принципы для эпика spdd-integration
properties:
  - name: Тип контента
    value: [Исследование]
  - name: Статус
    value: [Draft]
---

> **Источники:** Thoughtworks SPDD article (2026-04), internal comparative insight (2026-05-14). Полные пути — внизу статьи.

# SPDD — ключевые принципы для эпика spdd-integration

**Дата:** 2026-05-14
**Исследователь:** researcher-agent
**Запрос PM/BA:** собрать контекст по трём темам эпика — two-way sync, Safeguards, drift-check

## TL;DR

SPDD (Structured-Prompt-Driven Development, Thoughtworks, апрель 2026) рассматривает промпты как версионируемые delivery-артефакты. Ключевые принципы: фиксированная структура REASONS Canvas, двусторонняя синхронизация «спек ↔ код» и явные Safeguards-инварианты до генерации кода. Шаблон project_template уже реализует ~70% этих идей; эпик закрывает три оставшихся gap точечно.

## (а) Two-way sync

SPDD формулирует правило однозначно: **при любом расхождении между реальностью и спеком — сначала чинится спек, потом обновляется код**.

> «Когда реальность расходится — сначала исправь промпт, потом обнови код». [source 2]

> «Two-way sync: промпт остаётся текущим резюме системы, не историческим снимком». [source 2]

Инструментально это две команды: `/spdd-prompt-update` (изменение требований → обновление Canvas) и `/spdd-sync` (рефакторинг кода → синхронизация обратно в Canvas). Триггер — момент ревью или обнаружение расхождения. Исключение из правила — hotfix на production: Canvas пишется в post-mortem, а не вместо быстрого фикса.

**Для BA/SA:** нюанс — правило применяется именно в момент обнаружения, а не отложенно. Escalation предполагается к BA/PO при уточнении scope (шаг 2 workflow).

## (б) Safeguards

Компонент `S` (Safeguards) в REASONS Canvas — **неоспоримые границы**, которые нельзя нарушать при генерации или рефакторинге.

> «Неоспоримые границы. Инварианты, лимиты производительности, правила безопасности». [source 2]

Пример из статьи: «`modelId` — обязательное поле, не может быть null» [source 2]. В отличие от Acceptance Criteria (описывают ожидаемое поведение), Safeguards — это hard constraints: нарушение любого из них делает реализацию невалидной по определению. Safeguards фиксируются в Canvas явно как отдельная секция, а не размазываются по тексту требований.

## (в) Drift-check

SPDD не вводит отдельного ритуала «drift-check» как термина, но формализует проверку расхождений через:

1. **Автоматизацию** — команды `/spdd-sync` (код → Canvas) и `/spdd-prompt-update` (требования → Canvas); запускаются при каждом изменении.
2. **Code review на промпте** — ревью переходит от «заметь баг» к «проверь намерение» [source 2].

Будущее направление по статье — **автоматизированная верификация на уровне активов**: framework сам ловит gaps и inconsistencies между слоями. Сейчас это всё ещё требует дисциплины команды.

**Для SA:** логика drift-check в SPDD живёт в tooling (openspdd), а не в CI/CD. Для project_template — аналог в `/pm-review`; поле `drift_pairs` в manifest профиля — это наша параметризация, которой нет в оригинальном SPDD.

## SPDD vs SDD/SuperPowers

SPDD выигрывает у SDD в долгосрочной памяти (двусторонняя sync vs однонаправленный спек), а у SuperPowers — в формализме и аудитируемости, но проигрывает в скорости и параллелизации субагентов [source 1].

## Ссылки на источники

- [primary] Wei Zhang, Jessie Jie Xia. «Structured-Prompt-Driven Development». martinfowler.com, 2026-04-28.
  URL: https://martinfowler.com/articles/structured-prompt-driven/
  Файл: `/Users/mdemyanov/Documents/naumen-cto/55_SOURCES/articles/2026/2026-05-14_article_structured-prompt-driven-development.md` [source 2]
- [primary] Максим Демьянов. «SDD vs SPDD vs SuperPowers — три подхода к разработке через промпты». Insight, 2026-05-14.
  Файл: `/Users/mdemyanov/Documents/naumen-cto/50_KNOWLEDGE/insights/2026/2026-05-14_sdd-spdd-superpowers-comparison.md` [source 1]
