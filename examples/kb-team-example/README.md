# Example: kb-team profile

Этот каталог — пример проекта, инициализированного как `kb-team` профиль (внутренняя командная KB).

## Как был создан

```bash
bash scripts/init.sh --profile kb-team "Example Team KB" "EXKB" "Demo team KB" "owner@example.com"
```

## Что внутри

- `content/` — каталог KB:
  - `10-domain/` — понятия и контекст
  - `20-onboarding/` — onboarding для новых сотрудников
  - `30-runbooks/` — runbook'и (deploy, monitoring, incident response)
  - `40-roles/` — описание ролей в команде
  - `50-incidents/` — пост-мортемы инцидентов
- `.doc-root.yaml` (внутри content/) — kb-team schema (Owner, Эскалация, Тип контента: Onboarding/Runbook/Role/Incident)

## Что отсутствует (vs project)

- `00-project/` — нет ADR, plans, critical-path (kb-team не управляет delivery)
- `30-requirements/` — нет функциональных требований
- `40-architecture/` — нет компонентов
- `60-implementation/`, `70-operations/` — нет реализации/operations

(Эти папки удалены `op:delete` в kb-team manifest.)

## Профиль kb-team — особенности

Активные subagent'ы: pm, devops, tech-writer (core); researcher, devsecops, compliance (optional). Disabled: ba, sa, dev, qa (kb-team не пишет код).

## Для чего это пример

Static snapshot для новых пользователей шаблона. Контрастирует с `examples/project-example/` — показывает альтернативную структуру.
