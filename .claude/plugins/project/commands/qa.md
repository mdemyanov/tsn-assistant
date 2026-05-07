---
description: "QA с режимами author (тесты до Dev) и runner (прогон + регрессии). Пример: /qa --mode=author user-sessions, /qa --mode=runner auth-module"
allowed-tools: Task
---

# /qa — QA-агент с двумя режимами

Аргументы: `--mode=author <area-or-req>` или `--mode=runner <area-or-module>`.

## Логика

Распарсь `$ARGUMENTS`:

1. **`--mode=author`** — диспетч `qa-author-agent` через Task tool.
   - Цель: создать AC-driven test design + failing test stubs ДО Dev'а
   - Входы: требование `content/30-requirements/<req>.md` (с AC); опционально архитектурный артефакт SA в `content/40-architecture/`
   - Артефакты: `content/30-requirements/<req>/at-design.md` + failing test stubs в `tests/<area>/test_<req>.<ext>`
   - Критерии: stubs запускаются и падают (red); AC покрытие 100%

2. **`--mode=runner`** — диспетч `qa-runner-agent` через Task tool.
   - Цель: прогнать full test suite + регрессии после Dev'а; сформировать отчёт
   - Входы: код в `src/`, тесты `tests/`, требование с AC
   - Артефакт: `content/60-implementation/test-reports/<NNN>-<date>.md`
   - Критерии: отчёт включает passed/failed/skipped + regression analysis + рекомендация (merge/block/re-run)

3. **`--mode` пропущен** — попроси пользователя уточнить режим.

## Передача subagent'у

Сформируй prompt по контракту из AGENTS.md («Контракт вызова субагента»):

1. **Цель** одной фразой
2. **Входные файлы** — конкретные пути в зависимости от режима
3. **Ожидаемый артефакт** — путь и формат (см. логику выше)
4. **Критерии приёмки** — из контракта роли

## Примеры

- `/qa --mode=author user-sessions` → запускает qa-author-agent с задачей «написать AC-driven test design + failing stubs для user-sessions»
- `/qa --mode=runner auth-module` → запускает qa-runner-agent с задачей «прогнать full suite + регрессии для auth-module, написать отчёт»

## Pipeline-handoff

В `/pipelines/project-planning <epic>` qa-author вызывается ПОСЛЕ sa-agent'а, ДО dev-agent'а; qa-runner — ПОСЛЕ dev-agent'а, ПЕРЕД ba-acceptance gate'ом.
