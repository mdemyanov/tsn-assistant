# pg_vector_service

Внутренний проект Naumen на основе шаблона `project_template`.

## Быстрый старт

1. `bash scripts/init.sh` — задаст имя проекта, создаст ветку `private`, скопирует `.env`.
2. (Опционально для SMP-проекта) `bash scripts/apply-overlay.sh naumen-smp`.
3. Открой репо в Claude Code — плагины подцепятся через `.claude/settings.json`.
4. `/pm decompose <твоя первая фича>` — поехали.

## Что внутри

| Что | Где | Кто использует |
|---|---|---|
| Карта команды и контракт вызова | `AGENTS.md` | PM |
| Универсальное ядро правил | `CLAUDE.md` | Все агенты |
| База знаний Gramax | `content/` | BA, SA, DevOps |
| Глоссарий и research-выжимки | `content/10-domain/` | BA, Researcher |
| Спеки (brainstorming) | `docs/superpowers/specs/` | PM |
| Планы реализации (writing-plans) | `docs/superpowers/plans/` | PM |
| Журнал уроков | `docs/lessons-learned.md` | Все агенты |
| Overlay-патчи (SMP и т.п.) | `docs/overlays/` | На старте проекта |

## Как пользоваться

- **Аналитики:** `/research <тема>` → `/ba new-requirement <slug>` → ревью `/pm-review`.
- **Руководители:** `/pm decompose <фича>` для новой задачи; `/pm status` для отчёта.
- **Разработчики:** получают артефакт SA через `/sa design <фича>`, реализуют через `/dev implement <фича>` (TDD), документируют runbook через `/devops runbook <процедура>`.
- **Все:** для текстов — `infoinstyle`; для многошаговых задач — `superpowers:brainstorming`.

## Ветвление

- `private` — рабочая ветка, все правки.
- `public` — публикация в Gramax, мерж только после `/pm-review`.

## Подключённые плагины

- `gramax@ai-assistants` — writer, comments-read, comments-write
- `superpowers@claude-plugins-official` — brainstorming, writing-plans, executing-plans, TDD, debugging, ...
- `project@local` — агенты PM/BA/SA/Dev/DevOps/Researcher + локальные скиллы CTO

Marketplaces и enabled-плагины описаны в `.claude/settings.json`.

## Доступные overlays

- `naumen-smp` — для проектов на платформе Naumen SMP. См. `docs/overlays/naumen-smp/README.md`.

## Для мейнтейнеров шаблона

### Источники

- CTO-скиллы (infoinstyle, correspondence-2): `/Users/mdemyanov/Documents/naumen-cto/.claude/skills/`. При обновлении: `cp -R <src> .claude/plugins/project-template/skills/<name>/`.
- Эталоны агентов: `/Users/mdemyanov/knowlage/sd-ai-assistant`, `/Users/mdemyanov/Devel/naumen-smp-mcp`.

### Тестирование

Перед PR в шаблон:
```bash
bash scripts/test-template.sh
```

Должен вывести `Template smoke test PASSED`.
