# Example: project profile

Этот каталог — пример проекта, инициализированного как `project` профиль.

## Как был создан

```bash
bash scripts/init.sh --profile project "Example Project" "EXMP" "Demo project for project-template" "owner@example.com"
```

(используя `INIT_SKIP_GIT_RESET=1 INIT_SKIP_PROMPTS=1` для воспроизводимости в CI; реальный init интерактивный.)

## Что внутри

- `content/` — каталог документации (Gramax) с baseline scaffold:
  - `00-project/` — ADR, plans, critical-path, security
  - `30-requirements/` — функциональные / нефункциональные
  - `40-architecture/` — компоненты, интеграции
  - `60-implementation/` — реализация, test-reports
  - `70-operations/` — runbook, мониторинг
- `CLAUDE.md` — конфигурация AI-ассистента
- `AGENTS.md` — каталог 10 ролей

## Профиль project — особенности

Полный delivery-проект: Researcher → BA → SA → Dev → DevOps цепочка. Активные subagent'ы: pm, ba, sa, dev, qa (core); researcher, devops, tech-writer, devsecops, compliance (optional).

## Для чего это пример

Чтобы новый пользователь шаблона видел «вот что получится» без запуска init. Структура заморожена — для актуального состояния запусти init на чистом репо.

> Это **static snapshot**. При изменениях шаблона (W4+) пример может устареть.
