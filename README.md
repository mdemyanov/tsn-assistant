# {{PROJECT_NAME}}

Внутренний проект Naumen на основе шаблона `project_template`.

## Быстрый старт

1. **Открой клон в Claude Code** и выполни `/init` — slash-команда проведёт двухфазную инициализацию:
   - покажет **интерактивное меню профилей** с описаниями (`<имя> — <описание> [для: <аудитория>]`);
   - после выбора профиля — **summary block** (operations / overrides / subagents) и **confirm gate** перед применением;
   - заполнит плейсхолдеры (имя проекта, код каталога Gramax, описание, email редактора);
   - спросит URL нового origin и **отвяжет репо от шаблона** (`rm -rf .git && git init`);
   - проведёт интервью по теме проекта (стек, команды сборки, red-lines), оставит `<!-- TODO(/init): … -->` на пропусках.
2. (Опционально для SMP-проекта) `bash scripts/apply-overlay.sh naumen-smp`.
3. `/pm decompose <твоя первая фича>` — поехали.

> **Без Claude Code:** `bash scripts/init.sh --profile <name> "<имя>" "<код>" "<описание>" "<email>" "<git-url>"` даст фазу 1 неинтерактивно; фазу 2 (интервью) тогда придётся пройти руками.
> **Backup до init:** склонируй шаблон второй копией заранее, если хочется иметь возможность сравнить с оригиналом — wipe удаляет историю шаблона.

### Обновление существующего проекта из шаблона

Дай ассистенту ссылку на [docs/upgrading-from-template.md](docs/upgrading-from-template.md) и скажи «обнови проект из шаблона». Playbook рассчитан на ситуации, когда структура старого проекта сильно отличается от текущей версии шаблона (нет профилей, нет плагинной папки, переименован плагин и т.п.).

### Доступные профили (7/7 stable)

| Профиль | Назначение |
|---------|------------|
| `project` | Delivery-проект (Researcher → BA → SA → Dev → DevOps). Default |
| `kb-team` | Internal team KB (onboarding/runbook/role/incident) |
| `kb-product` | Документация продукта для клиентов |
| `product` | Разработка продукта/модуля (vision → spec → ADR → release) |
| `methodology` | Methodology / playbook (principles → practices → playbooks) |
| `course` | Обучающий курс (modules → lessons → assessments) |
| `custom` | Open-ended catch-all (anti-opinion baseline) |

### Полезные команды

- `bash scripts/init.sh` — interactive: меню профилей с описаниями, summary, confirm
- `bash scripts/init.sh --profile <name> "Name" "CODE" "desc" "email" "git-url"` — non-interactive (CLI)
- `INIT_FORCE=1 bash scripts/init.sh --profile <name> ...` — пропустить confirm prompt (CI)
- `python3 scripts/validate-profile.py` — валидация manifest'ов профилей
- `bash scripts/apply-overlay.sh --profile --dry-run <name>` — preview операций профиля
- `bash scripts/check.sh --fast` — pre-commit gate (validate-content + validate-profile, ~3 сек)
- `bash scripts/check.sh --full` — pre-merge gate (+ tests, ~30 сек)

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

## Валидация

Структуру каталога `content/` проверяет валидатор:

```bash
python3 scripts/validate-content.py
```

Требует `pyyaml` (`pip install pyyaml`). Запускается автоматически в `bash scripts/test-template.sh` и в slash-команде `/pm-review`.

### Setup pre-commit hooks (опционально)

Чтобы валидаторы (`validate-content.py`, `validate-profile.py`) запускались автоматически перед каждым commit'ом:

```bash
bash scripts/install-hooks.sh
```

Это активирует `.githooks/pre-commit` (запускает `bash scripts/check.sh --fast`).

Bypass: `git commit --no-verify`.
Disable: `git config --unset core.hooksPath`.

## Для мейнтейнеров шаблона

### Источники

- CTO-скиллы (infoinstyle, correspondence-2): `/Users/mdemyanov/Documents/naumen-cto/.claude/skills/`. При обновлении: `cp -R <src> .claude/plugins/project/skills/<name>/`.
- Эталоны агентов: `/Users/mdemyanov/knowlage/sd-ai-assistant`, `/Users/mdemyanov/Devel/naumen-smp-mcp`.

### Тестирование

Перед PR в шаблон:
```bash
bash scripts/test-template.sh
```

Должен вывести `Template smoke test PASSED`.
