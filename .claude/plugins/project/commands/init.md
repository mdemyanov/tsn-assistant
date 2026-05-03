---
description: "Инициализация проекта из шаблона. Заполняет плейсхолдеры в CLAUDE.md, AGENTS.md, README.md, content/.doc-root.yaml. Создаёт ветку private. Пример: /init my-project"
allowed-tools: Read, Edit, Write, Bash(git:*), Bash(bash scripts/init.sh:*), Bash(ls:*), Bash(grep:*)
---

Ты выполняешь первичную инициализацию проекта, созданного из шаблона `project_template`.

## Твоя задача

Пользователь передал: `$ARGUMENTS`

Цель — превратить «шаблон» в готовый рабочий проект: заполнить все плейсхолдеры, настроить Gramax-каталог, создать рабочую ветку.

## Алгоритм

1. **Проверь, что инициализация ещё не выполнена.** Прочитай [CLAUDE.md](CLAUDE.md) и поищи `{{PROJECT_NAME}}`. Если плейсхолдеров нет — проект уже инициализирован, сообщи пользователю и выйди.

2. **Собери параметры от пользователя** (если не переданы в `$ARGUMENTS`):
   - `PROJECT_NAME` — человекочитаемое имя проекта (например, `SD AI Assistant`)
   - `PROJECT_CODE` — код каталога Gramax, UPPERCASE, без пробелов (например, `SD-AI-ASSISTANT`)
   - `PROJECT_DESCRIPTION` — короткое описание для шапки Gramax-каталога
   - `EDITOR_EMAIL` — email редактора Gramax (минимум один; добавить остальных можно потом руками)

3. **Запусти `scripts/init.sh`** — он умеет принимать аргументы:
   ```bash
   bash scripts/init.sh "$PROJECT_NAME" "$PROJECT_CODE" "$PROJECT_DESCRIPTION" "$EDITOR_EMAIL"
   ```
   Скрипт:
   - подставит плейсхолдеры в `CLAUDE.md`, `AGENTS.md`, `README.md`, `content/.doc-root.yaml`
   - создаст ветку `private` (если её нет)
   - скопирует `.env.example` → `.env`

4. **Верифицируй результат:**
   - `grep -RE '{{(PROJECT_(NAME|CODE|DESCRIPTION)|EDITOR_EMAIL)}}' CLAUDE.md AGENTS.md README.md content/.doc-root.yaml` — должно быть пусто.
   - Прочитай [content/.doc-root.yaml](content/.doc-root.yaml) и подтверди, что `code`, `title`, `description`, `editors` заполнены.
   - Проверь, что текущая ветка `private` или есть возможность переключиться (`git branch -a`).

5. **Поясни пользователю**, что нужно ещё сделать вручную:
   - При необходимости адаптировать набор `properties` в `content/.doc-root.yaml` под специфику проекта (Сценарии, Типы контента, Фазы, Статусы) — см. пример в `/Users/mdemyanov/knowlage/sd-ai-assistant/content/.doc-root.yaml`.
   - Дополнить `editors:` в `content/.doc-root.yaml` остальными редакторами.
   - Заполнить секреты в `.env`.
   - (Опционально для SMP-проекта) `bash scripts/apply-overlay.sh naumen-smp`.

## Контракт `.doc-root.yaml`

Минимальный набор полей, которые обязаны быть заполнены **после** `/init`:

| Поле | Источник | Пример |
|------|----------|--------|
| `code` | `PROJECT_CODE` | `SD-AI-ASSISTANT` |
| `title` | `PROJECT_NAME` | `SD AI Assistant` |
| `description` | `PROJECT_DESCRIPTION` | `Knowledge base for AI Assistant for Service Desk` |
| `style` | по умолчанию `blue-green` | — |
| `language` / `supportedLanguages` | по умолчанию `ru` | — |
| `syntax` | `XML` (фиксировано шаблоном) | — |
| `properties` | стартовый набор: Тип контента, Фаза, Статус | адаптируется под проект |
| `filterProperties` | `[Тип контента, Фаза, Статус]` | синхронизировать с `properties` |
| `editors` | `EDITOR_EMAIL` (можно дополнить) | `qutask@gmail.com` |

Если `properties` адаптируется (добавляются «Сценарий», «Интеграция» и т.п.) — обязательно обновить `filterProperties`, иначе фильтры в Gramax не появятся.

## Формат ответа

- Что сделано (файлы изменены, ветка создана).
- Что осталось пользователю (TODO-список).
- Команда для следующего шага: `/pm decompose <твоя первая фича>`.
