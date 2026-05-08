# Example: custom profile

Этот каталог — пример проекта, инициализированного как `custom` профиль (anti-opinion, open-ended catch-all).

## Как был создан

```bash
bash scripts/init.sh --profile custom "Example Custom" "ECC" "Пример open-ended каталога" "example@custom.com"
```

## Что внутри

- `content/` — Gramax-каталог с минимальным scaffold (без числовых префиксов):
  - `templates/` — 3 примера статей (Заметка, Решение, Справка)
  - `inbox/` — нейтральный staging area для необработанных материалов
  - `_index.md` — корневая страница каталога
- `content/.doc-root.yaml` — минимальные properties (Тип контента, Статус)
- `CLAUDE.md`, `AGENTS.md` — заполненные шаблоны проекта (placeholder'ы заменены)

## Anti-opinion principle

Профиль `custom` сознательно не навязывает структуру, нумерацию, workflow или ролевую модель.

**Что это означает на практике:**

- **Нет числовых префиксов** в `content/` (`10-*`, `20-*`, `30-*` и т.д.) — папки называются по содержанию
- **Нет agent overrides** — все агенты работают с базовыми промптами без предметной настройки; custom не знает, что понадобится пользователю
- **Нет disabled-ролей** — все 9 subagent'ов (кроме pm) = `optional`; пользователь активирует по потребности
- **Нет pipeline'ов** — custom не активирует project-planning, ba-acceptance и другие автоматизированные процессы
- **Нет domain-специфичных properties** — только `Тип контента` и `Статус`

## Что отсутствует (намеренно)

- `content/30-requirements/` — custom не подразумевает BA-workflow
- `content/40-architecture/` — custom не подразумевает SA-workflow
- `content/60-implementation/`, `content/70-operations/` — нет delivery-структуры
- `agent-overrides/` с файлами — директория существует, но пуста (чистые base prompts)

## Профиль custom — особенности

- **Активные subagents:** pm (core); все остальные 9 = optional
- **Overrides:** отсутствуют (`agent_overrides: {}` в manifest)
- **Pipelines:** нет (`pipelines: {}`)
- **Compatible stacks:** `["*"]` — universal

## Для каких сценариев

- Research-каталог или личный wiki в Gramax
- Команда с уникальной методологией, не покрытой другим профилем
- Эксперимент или прототип без заданной структуры
- Смешанный контент без единого workflow

## Как обновить пример

После изменения custom манифеста или scaffold'а пересоздай example вручную:

```bash
TMP=$(mktemp -d)
cp -r . "$TMP/custom-example"
rm -rf "$TMP/custom-example/.git" "$TMP/custom-example/.worktrees"
cd "$TMP/custom-example"
git init -q && git add -A && git commit -q -m "snapshot" --allow-empty
bash scripts/init.sh --profile custom "Example Custom" "ECC" "Пример open-ended каталога" "example@custom.com"

cd /path/to/repo
mkdir -p examples/custom-example
cp -r "$TMP/custom-example/content" examples/custom-example/
cp "$TMP/custom-example/CLAUDE.md" examples/custom-example/
cp "$TMP/custom-example/AGENTS.md" examples/custom-example/
cp "$TMP/custom-example/README.md" examples/custom-example/
# Для custom: НЕ копируй agent-overrides — их нет (pure base prompts)
```

## Для чего это пример

Static snapshot для новых пользователей шаблона. Контрастирует с:
- `examples/project-example/` — delivery-проект (полная структура с ADR/req/arch/impl/ops)
- `examples/kb-team-example/` — internal team KB (onboarding/runbook/role/incident)
- `examples/kb-product-example/` — customer docs (getting-started/guides/reference/troubleshooting + tech-writer override)

Custom — наименее opinionated из всех профилей. Пользователь получает минимальный baseline и строит всё остальное самостоятельно.
