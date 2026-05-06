---
description: "Двухфазная инициализация проекта из шаблона. Фаза 1: bash-скрипт (плейсхолдеры, wipe .git, initial commit с трассировкой, опционально origin). Фаза 2: интервью по 6 темам с TODO-маркерами на пропусках. Пример: /init my-project"
allowed-tools: Read, Edit, Write, Bash(git:*), Bash(bash scripts/init.sh:*), Bash(ls:*), Bash(grep:*)
---

Ты выполняешь первичную инициализацию проекта, созданного из шаблона `project_template`. Работа делится на две фазы: bash-механика (`scripts/init.sh`) и интервью с правками content'а.

## Твоя задача

Пользователь передал: `$ARGUMENTS`

Цель — превратить «шаблон» в готовый рабочий проект:
1. Заполнить плейсхолдеры (`{{PROJECT_NAME}}`, `{{PROJECT_CODE}}`, `{{PROJECT_DESCRIPTION}}`, `{{EDITOR_EMAIL}}`).
2. Wipe `.git`, initial commit с трассировкой (`Template: <url>@<sha>`).
3. Опционально установить новый `origin` (URL ≠ репозиторий шаблона).
4. Заполнить или явно отметить TODO-маркерами project-specific секции в `CLAUDE.md`.

## Алгоритм

### Шаг 0. Идемпотентность

1. Прочитай `CLAUDE.md`. Если там нет ни `{{PROJECT_NAME}}`, ни `TODO(/init)` — проект уже полностью инициализирован. Сообщи и выйди.
2. Если есть `{{PROJECT_NAME}}` → переходи к **Фазе 1**.
3. Если плейсхолдеров уже нет, но есть `<!-- TODO(/init): ... -->` → пропусти Фазу 1, переходи сразу к **Фазе 2** (дозаполнение).

### Шаг 0.5. Подтверждение wipe (только если идём в Фазу 1)

Покажи пользователю текущую историю git:

```bash
git log --oneline -10
```

Затем явно спроси в чате (это сообщение, а не bash-prompt):

> «Это история шаблона. После init она будет удалена (wipe `.git` + initial commit с трассировкой). Продолжить? (yes/no)»

Жди подтверждения. На отрицательный ответ или невнятный — остановись и предложи сначала сделать `git clone` шаблона второй копией как backup.

### Шаг 0.7. Выбор профиля (Wave 2)

Шаблон поддерживает несколько профилей (тип проекта). Профиль определяет:
- структуру `content/` (scaffold)
- набор properties в `.doc-root.yaml`
- активные subagents (core / optional / disabled) и pipelines

Покажи доступные профили:

```bash
ls docs/overlays/profiles/ | grep -v '^\.gitkeep$'
```

Спроси у пользователя: «Выбери профиль (default: `project`):»

| Профиль | Назначение | Status |
|---------|------------|--------|
| `project` | Delivery-проект (default) — Researcher → BA → SA → Dev → DevOps цепочка | stable |
| `kb-team` | Internal team KB (onboarding/runbook/role/incident) | stable |
| `product` | Разработка продукта/модуля | stub (Wave 3+) |
| `kb-product` | Документация продукта для клиентов | stub |
| `methodology` | Методология / playbook | stub |
| `course` | Обучающий курс | stub |
| `custom` | Open-ended (research-каталог, личный wiki) | stub |

Если пользователь выбрал stub-профиль — предупреди, что scaffold ещё не готов; предложи alternative (`project` для большинства случаев) или продолжить с stub'ом (тогда content/ будет минимальным после init).

Сохрани выбор в переменную `$PROFILE`.

### Шаг 0.8. Динамические init_prompts профиля

После выбора профиля прочитай его манифест:

```bash
cat docs/overlays/profiles/$PROFILE/manifest.yaml
```

Если в манифесте есть `init_prompts:` — задай каждый вопрос пользователю по очереди:
- Тип `enum` — покажи `choices`, default помечен; ответ должен быть из списка
- Тип `string` — свободный текстовый ввод
- Тип `bool` — y/n

Сохрани ответы в `INIT_PROMPT_<id>` env-переменных. Они передадутся в `apply-overlay.sh` (через bash-init после T40), который применит `on_value` мутации к manifest in-memory.

**Пример (для project профиля):**
- `compliance_domain` (enum): «Проект под compliance-надзором?» — choices: `none`, `152-fz`, `iso27001`, `other`. Если ответ ≠ `none`, manifest добавит `subagents.compliance: core` (через on_value).

Если `init_prompts: []` или отсутствует — пропусти этот шаг.

### Фаза 1. Запуск механики

1. **Собери параметры** (если не переданы в `$ARGUMENTS`, спроси по очереди):
   - `PROJECT_NAME` — человекочитаемое имя проекта (например, `SD AI Assistant`)
   - `PROJECT_CODE` — код каталога Gramax, UPPERCASE, без пробелов (например, `SD-AI-ASSISTANT`)
   - `PROJECT_DESCRIPTION` — короткое описание для шапки Gramax-каталога
   - `EDITOR_EMAIL` — email редактора Gramax (минимум один; добавить остальных можно потом руками)
   - `GIT_REMOTE_URL` — URL нового origin. **Не должен** содержать `project-template` / `project_template`. Если у пользователя ещё нет URL — оставь пустым (init.sh пропустит origin и предупредит).

2. **Запусти `scripts/init.sh`** (после T40 поддерживает `--profile` и dynamic init_prompts):
   ```bash
   bash scripts/init.sh --profile "$PROFILE" "$PROJECT_NAME" "$PROJECT_CODE" "$PROJECT_DESCRIPTION" "$EDITOR_EMAIL" "$GIT_REMOTE_URL"
   ```
   Скрипт:
   - читает `docs/overlays/profiles/$PROFILE/manifest.yaml`
   - применяет `INIT_PROMPT_*` env-переменные через `on_value` мутации
   - подставит плейсхолдеры в `CLAUDE.md`, `AGENTS.md`, `README.md`, `content/.doc-root.yaml`
   - вызовет `apply-overlay.sh --profile --init <profile>` для применения операций (add/replace/delete)
   - опц. предложит применить совместимые stack-overlay'и (`compatible_stacks` из manifest'а)
   - wipe `.git`, `git init -b main`, initial commit с `Template: <url>@<sha>`
   - создаст ветку `private`
   - опционально `git remote add origin <url>`
   - скопирует `.env.example` → `.env`

3. **Верифицируй:**
   - `grep -RE '{{(PROJECT_(NAME|CODE|DESCRIPTION)|EDITOR_EMAIL)}}' CLAUDE.md AGENTS.md README.md content/.doc-root.yaml` — пусто.
   - `git log --oneline -1` — один initial commit, в сообщении есть `Template: `.
   - `git remote -v` — либо origin задан, либо пусто.
   - `git branch -a` — есть `main` и `private`.
   - `python3 scripts/validate-content.py` — exit 0 (warnings допустимы; errors — блокер).
   - `python3 scripts/validate-profile.py` — exit 0 (warnings допустимы; M5 errors про pipelines резолвятся после T39)
   - `[ -f docs/overlays/profiles/$PROFILE/manifest.yaml ]` — true
   - Профиль-специфичный scaffold применён (для `kb-team` это `content/30-runbooks/`; для `project` — `content/00-project/plans/`)

### Фаза 2. Интервью по 6 темам

Задавай вопросы **по одному**. Multiple-choice предпочтительнее. На каждый ответ — сразу `Edit` соответствующего блока в `CLAUDE.md`. На skip («не знаю / позже / пропустить») — оставь TODO-маркер как есть.

| # | Тема | Вопрос (пример) | Куда пишем |
|---|------|-----------------|------------|
| 1 | Стек и язык | «Стек: [a] Python [b] Groovy/Maven [c] TypeScript/Node [d] KB-only без кода [e] другое» | `## Стек` |
| 2 | Команды сборки и тестов | «Команды сборки/тестов? Например: `mvn test`, `pytest`, `npm test`. Если KB-only — `skip`.» | `## Команды сборки и проверки` |
| 3 | Архитектурные правила | «Архитектурный стиль: [a] hexagonal/ports-adapters [b] layered/N-tier [c] нет правил [d] KB-only» | `## Архитектурные правила` |
| 4 | Domain / тематика | «Опиши проект одним абзацем: что это, кому помогает, какую проблему решает.» | `## Контекст проекта` |
| 5 | Project-specific red-lines | «Какие правила безопасности/процесса критичны именно для этого проекта поверх универсальных?» | `### Project-specific` под `## Красные линии` |
| 6 | Ссылки | «URL платформенной документации, гайдов, API-доков (можно несколько; Enter — пропустить).» | `## Справочные пути` (заменить TODO-маркер) |

После каждого ответа:
- Содержательный ответ → `Edit`-tool заменяет конкретный `<!-- TODO(/init): ... -->` на блок (markdown с заголовком если нужно).
- Skip → ничего не меняешь, маркер остаётся для последующего grep.

### Шаг 6.5 (опц.): Адаптация properties в .doc-root.yaml

Спроси: «Хочешь адаптировать `properties` (Тип контента / Фаза / Статус) под специфику проекта (добавить «Сценарий», «Интеграция» и т.п.)?»

- «Нет» → оставь дефолт.
- «Да» → спроси, какие значения добавить/заменить, обнови соответствующие блоки и `filterProperties` синхронно.
- Skip → вставь `<!-- TODO(/init): адаптировать properties -->` в начало `content/.doc-root.yaml`.

Референс по адаптации (production-эталон): `/Users/mdemyanov/Devel/naumen-ecosystem/business-requirements/.doc-root.yaml`. Старый каталог `sd-ai-assistant` — НЕ использовать как референс схемы (легаси, плоская frontmatter-нотация).

### Шаг финал. Отчёт

1. **Что сделано:**
   - Какие файлы изменены (CLAUDE.md / .doc-root.yaml / ...).
   - Git-стейт: `git log --oneline -1`, `git branch -a`, `git remote -v`.
2. **Что осталось:** список TODO-маркеров через `grep -rn 'TODO(/init)' CLAUDE.md content/`. Если пусто — поздравь.
3. **Следующий шаг:** `/pm decompose <твоя первая фича>`.

## Anti-scope

- НЕ вызывай `/sa`, `/ba`, `/research` — на этапе init у проекта нет input-артефактов; их вызов нарушит контракт.
- НЕ делай commit правок Фазы 2 — пользователь решает сам (можно опционально предложить `commit-commands:commit` в конце как next step).
- НЕ создавай удалённый репозиторий — пользователь делает это сам и передаёт URL.
- НЕ создавать `README.md` в `content/` — Gramax индексирует только `_index.md`.

## Контракт `.doc-root.yaml` (для верификации)

Минимальный набор полей, которые обязаны быть заполнены **после** Фазы 1:

| Поле | Источник | Пример |
|------|----------|--------|
| `code` | `PROJECT_CODE` | `SD-AI-ASSISTANT` |
| `title` | `PROJECT_NAME` | `SD AI Assistant` |
| `description` | `PROJECT_DESCRIPTION` | `Knowledge base for AI Assistant for Service Desk` |
| `editors` | `EDITOR_EMAIL` (можно дополнить руками) | `qutask@gmail.com` |

Если `properties` адаптируются (Шаг 6.5) — обязательно обновить `filterProperties` синхронно, иначе фильтры в Gramax не появятся.
