# Research: Override mechanics для агент-промтов

**Дата:** 2026-05-07
**Автор:** Researcher subagent
**Источник запроса:** PM (Wave 4a, RES-410)
**Цель:** валидировать base + delta merge выбор для project_template

---

## Краткие выводы (TL;DR)

- **Нет единого отраслевого стандарта** inheritance для prompt-файлов: разные системы идут от «full replace» (Claude Code subagents) до «additive union» (Cline, OpenHands).
- **Наша модель (base + delta, section-level replace)** ближе всего к Jinja2 `{% block %}` — зрелому, хорошо понятому паттерну; это разумный выбор.
- **Ключевой риск:** ни одна из исследованных систем не реализует section-level merge через `extends:` в frontmatter prompt-файлов — паттерн оригинален для нас, сложнее в реализации и отладке, чем кажется.
- **Рекомендация:** добавить `super()` / `{{super}}` механику (Jinja2-паттерн) чтобы override мог расширять секцию base, а не только заменять — иначе дублирование неизбежно.
- **Validation критична:** Claude Code и OpenHands показывают, что «fail open» (игнорировать невалидный override) — опасно; нужен hard fail с чёткими сообщениями.

---

## По системам

### Claude Code plugins — subagents

**Формат:** Markdown-файл с YAML frontmatter. Обязательные поля: `name`, `description`. Опциональные: `model`, `tools`, `disallowedTools`, `maxTurns`, `permissionMode`, `hooks`, `mcpServers`, `memory`, `background`, `isolation`, `effort`, `color`, `skills`, `initialPrompt`.

**Extends mechanic:** Отсутствует. Нет поля `extends:` или аналога. Override реализован через **приоритет scope'а по location**, а не через merge:

| Приоритет | Location |
|-----------|----------|
| 1 (высший) | Managed settings (org-wide) |
| 2 | `--agents` CLI flag |
| 3 | `.claude/agents/` (project) |
| 4 | `~/.claude/agents/` (user) |
| 5 (низший) | Plugin's `agents/` directory |

**Merge granularity:** Full file replace. Если `.claude/agents/researcher.md` и `plugin/agents/researcher.md` имеют одинаковый `name`, побеждает высший приоритет — без merge тела.

**Multiple inheritance:** Нет. Single parent (winner-takes-all).

**Conflict resolution:** First match wins по таблице приоритетов. `claude agents` в CLI показывает, какие переопределены.

**Validation:** Проверяет корректность frontmatter полей; plugin-агенты не могут использовать `hooks`, `mcpServers`, `permissionMode` (игнорируются с предупреждением).

**Use cases:** Проектный агент "researcher" полностью заменяет одноимённый плагинный — пользователь редактирует весь файл. Нет механики «возьми базовый + добавь 3 строки».

**Источники:** [Claude Code Sub-agents docs](https://code.claude.com/docs/en/sub-agents), [Plugins reference](https://code.claude.com/docs/en/plugins-reference)

---

### Cursor — rules system

**Формат:** `.mdc` файлы (Markdown + YAML frontmatter) в `.cursor/rules/`. Legacy: `.cursorrules` (plain markdown).

**Frontmatter поля:**
```yaml
---
description: When to apply this rule
globs: ["src/**/*.ts"]
alwaysApply: false
---
```

**Extends mechanic:** Нет явного `extends:`. Вместо этого — **additive loading**: все подходящие `.mdc` файлы загружаются одновременно. «Inheritance» достигается разбивкой на файлы + ссылками в тексте.

**Merge granularity:** Additive concatenation (не merge). Все активные rules добавляются в контекст одновременно. Конфликты разрешает LLM на inference-time, не resolver.

**Multiple inheritance:** Поддерживается де-факто — несколько `.mdc` файлов активны одновременно при совпадении glob.

**Conflict resolution:** Нет формального resolver'а. При дублировании `.cursorrules` + `.cursor/rules/` инструкции могут дублироваться — документация рекомендует ручную миграцию.

**Validation:** Минимальная; неверный frontmatter не блокирует загрузку.

**Use cases:** Отдельный файл per-technology-stack, все загружаются когда нужны — вместо inheritance это feature composition.

**Источники:** [Cursor Rules docs](https://docs.cursor.com/context/rules), [DevShorts guide](https://www.devshorts.in/p/how-to-use-cursor-rules)

---

### Cline — .clinerules

**Формат:** `.md` или `.txt` файлы в `.clinerules/` директории. YAML frontmatter опциональный.

**Frontmatter поля:**
```yaml
---
paths:
  - "src/components/**"
  - "src/hooks/**"
---
```
Единственное поддерживаемое условие — `paths` (glob). Нет `extends:`.

**Extends mechanic:** Нет. Additive union: все `.md`/`.txt` файлы в `.clinerules/` объединяются в единый ruleset.

**Merge granularity:** Additive (concatenation). Workspace rules + global rules объединяются; при конфликте workspace берёт приоритет.

**Multiple inheritance:** Через множество файлов в директории — де-факто.

**Conflict resolution:** Workspace rules побеждают global rules при конфликте. Внутри workspace — no resolution, оба набора активны.

**Validation:** Fail-open: невалидный frontmatter — правило активируется с raw content (помогает отладке, но небезопасно).

**Use cases:** Команда держит `.clinerules/01-style.md`, `.clinerules/02-testing.md`, каждый с path-фильтрами — фактически feature flags per file-type.

**Источники:** [Cline Rules docs](https://docs.cline.bot/customization/cline-rules)

---

### OpenHands — microagents

**Формат:** Markdown файлы в `.openhands/microagents/` (repo-level) или `~/.openhands/microagents/` (user-level).

**Frontmatter поля:**
```yaml
---
agent: CodeActAgent
triggers:
  - "fix bug"
  - "write test"
---
```
Опциональный `agent:` (default: `CodeActAgent`); `triggers:` — keyword activation.

**Extends mechanic:** Нет явного extends. Precedence: repo > user. Файл без frontmatter — always-on (общий контекст). Файл с triggers — loaded on keyword match.

**Merge granularity:** Additive loading в контекст. Нет section-level merge.

**Multiple inheritance:** Нет — разные микроагенты сосуществуют, не мерджатся.

**Conflict resolution:** Repo-level microagents имеют приоритет над user-level для одного имени файла. Также поддерживаются model-specific варианты: `AGENTS.md` (universal), `CLAUDE.md` (Claude-specific), `GEMINI.md`.

**Validation:** Не документирована детально.

**Use cases:** Repo microagent описывает структуру проекта — грузится всегда. Trigger-агент "fix bug" — только при keywords. Нет override отдельных секций.

**Источники:** [OpenHands microagents docs](https://docs.openhands.dev/modules/usage/prompting/microagents-repo)

---

### GitHub Copilot — custom instructions

**Формат:** Markdown файлы. Два типа:
- `.github/copilot-instructions.md` — repo-wide, без frontmatter, plain markdown.
- `.github/instructions/*.instructions.md` — path-scoped, с frontmatter.

**Frontmatter поля (для `.instructions.md`):**
```yaml
---
applyTo: "**/*.ts,**/*.tsx"
excludeAgent: "code-review"
---
```

**Extends mechanic:** Нет. Layered accumulation:
1. Personal (`~/.copilot/copilot-instructions.md`) — высший приоритет.
2. Repository (`.github/copilot-instructions.md`).
3. Organization instructions — низший.

**Merge granularity:** Additive — все подходящие по `applyTo` файлы объединяются. `.github/copilot-instructions.md` всегда активен.

**Multiple inheritance:** Через множество `*.instructions.md` файлов с разными glob-паттернами.

**Conflict resolution:** Приоритет personal > repo > org. Конфликт внутри уровня — оба активны, LLM разрешает.

**Validation:** `applyTo` glob проверяется против текущего файла. Без `applyTo` файл не активируется автоматически.

**Use cases:** Разные инструкции для разных частей кодовой базы (models/, api/, frontend/). Agent-specific exclusion через `excludeAgent`.

**Источники:** [GitHub Copilot custom instructions](https://docs.github.com/en/copilot/how-tos/configure-custom-instructions), [VS Code custom instructions](https://code.visualstudio.com/docs/copilot/customization/custom-instructions)

---

### Continue.dev — config system

**Формат:** `config.yaml` (YAML). Legacy: `config.json` + `.continuerc.json`.

**Merge mechanic (`.continuerc.json`):**
```json
{
  "mergeBehavior": "merge"
}
```
`"merge"` (default): top-level arrays и objects мерджатся. `"overwrite"`: top-level properties полностью замещаются.

**Extends mechanic:** Нет `extends:`. Workspace (`.continuerc.json`) накладывается поверх user config. `modifyConfig` в `config.ts` — императивный override.

**Merge granularity:** Top-level key granularity (object merge / array merge / overwrite). Нет section-level для system prompt.

**System prompt override:** `model.baseAgentSystemMessage` — полная замена base message или ничего.

**Validation:** Схема YAML, но система prompt assembly признана технически долгом (issue #11671 в репо).

**Use cases:** Team shared `config.yaml` с company models + personal `config.ts` для fine-tuning.

**Источники:** [Continue configuration docs](https://docs.continue.dev/customize/deep-dives/configuration)

---

### Aider — conventions files

**Формат:** Plain Markdown (`.md`) или `.txt`. Никакого frontmatter.

**Extends mechanic:** Нет. `--read CONVENTIONS.md` передаёт файлы в контекст. Множество файлов: `read: [CONVENTIONS.md, team-style.md]`.

**Merge granularity:** Additive concatenation в контекст. Без resolver'а.

**Config file precedence:** `.aider.conf.yml` загружается из `~`, git root, `cwd` — последний выигрывает при конфликте ключей.

**Validation:** Минимальная.

**Use cases:** Одиночный файл CONVENTIONS.md с bullet points — самый простой паттерн.

**Источники:** [Aider conventions](https://aider.chat/docs/usage/conventions.html), [Aider config](https://aider.chat/docs/config/aider_conf.html)

---

## Сравнительная таблица

| Система | Override format | Extends mechanism | Merge granularity | Multiple inherit | Validation |
|---------|----------------|-------------------|-------------------|-----------------|------------|
| Claude Code plugins | Markdown + YAML frontmatter | Нет — scope priority | Full file replace | Нет | Frontmatter schema + security deny-list |
| Cursor | `.mdc` + YAML frontmatter | Нет — additive glob | Concatenation | Да (multiple files) | Минимальная |
| Cline | `.md`/`.txt` + YAML frontmatter | Нет — additive union | Concatenation | Да (directory) | Fail-open |
| OpenHands | Markdown + YAML frontmatter | Нет — precedence by level | Additive context | Нет (per file) | Не документирована |
| GitHub Copilot | Markdown + YAML frontmatter | Нет — layered accumulation | Additive by applyTo | Да (multiple files) | applyTo glob validation |
| Continue.dev | YAML config | Нет — workspace overlay | Top-level key merge/overwrite | Нет | YAML schema |
| Aider | Plain Markdown | Нет | Concatenation | Да (list) | Нет |

---

## Релевантные паттерны из соседних областей

### Jinja2 template inheritance

Самый релевантный аналог нашему дизайну. Паттерн: base template определяет `{% block name %}...{% endblock %}`, child делает `{% extends "base.html" %}` и переопределяет только нужные блоки. Ненаписанные блоки наследуются дословно.

**Ключевая функция `super()`:** `{{ super() }}` внутри block вставляет содержимое родительского block — позволяет расширять, а не только замещать.

**Чего нам не хватает в текущем design'е:** аналога `super()` для body секций. Без него override-файл при необходимости добавить 2 строки к существующей секции вынужден копировать всю секцию целиком.

### Helm values merge

Два режима: **deep merge для maps** (только указанные ключи override'ят, остальные наследуются) и **full replace для arrays** (нет merge lists). Это создаёт хорошо понятую, предсказуемую семантику.

Урок: явное разделение «что мерджится глубоко» vs «что заменяется полностью» помогает пользователям предсказывать поведение.

### Kustomize overlays

Два типа патчей: **strategic merge** (интуитивный, но неполный) и **JSON6902** (RFC 6902, явные операции: add/remove/replace). JSON6902 используется когда strategic merge не справляется (удаление элементов массива, reorder).

Урок: для сложных override-сценариев иногда нужны явные операции, а не только «замени секцию».

---

## Рекомендации для Wave 4a

### 1. Подтверждается ли «base + delta merge с full-section replace» как best practice?

**Partially.** Паттерн обоснован и нет прецедентов делать лучше в AI-tool пространстве — они все либо проще (full-file replace) либо additive без resolve. Наш дизайн — шаг вперёд. Но нужны доработки:

### 2. Что пересмотреть

**A. Добавить `super:` механику** для секций body. Без неё override-файл, который хочет добавить параграф в секцию «Красные линии», обязан скопировать весь base-контент секции. Вариант реализации:

```markdown
## Красные линии

{{super}}

- НЕ делать X (профиль-специфично)
```

Resolver при виде `{{super}}` подставляет соответствующую секцию из base. Это минимизирует объём override-файлов и снижает drift при изменении base.

**B. Уточнить semantics frontmatter merge.** Текущий дизайн: «поля override'а заменяют base, отсутствующие наследуются». Это корректно для scalar-полей. Для list-полей (например `disallowedTools: [Write, Edit]`) нужно явно зафиксировать: полная замена или additive merge? Рекомендация: **полная замена** (как Helm для arrays) — предсказуемо.

### 3. Edge cases, которые пропущены в текущем design'е

- **Circular extends:** `profile-A` extends `profile-B`, `profile-B` extends `profile-A`. Нужна детекция цикла в M11.
- **Пустой override body:** файл только с frontmatter `extends: researcher`, без секций body — должен быть валидным (все секции наследуются). Нужно протестировать в resolver'е.
- **Секция только в override, не в base:** добавляется в конец — ОК. Но нужна ли она перед какой-то существующей секцией? Нет механики `before:` / `after:`.
- **Переименованная секция:** `## Красные линии` в base vs `## Red Lines` в override — не совпадут, создадут дублирование вместо replace. Нужна нормализация заголовков (case-insensitive strip) или явная документация что регистр и пунктуация критичны.
- **`extends:` несуществующего base:** M11 должен давать Human-readable ошибку с путём и предложением проверить имя роли.

### 4. Конкретные improvements

**Frontmatter format:** добавить поле `description` (опционально) — кратко что меняет этот override и зачем. Помогает аудиту.

```yaml
---
extends: researcher
description: "KB-team profile: restrict researcher to internal knowledge only"
---
```

**Validation error messages (M11):**
- «Base agent file not found: `.claude/plugins/project/agents/researcher-agent.md`. Check role name in `extends:`.»
- «`extends:` field references role `qa`, but role is disabled in profile manifest. Remove override or enable role.»
- «Section heading `## Красные линии` in override does not match any section in base. Closest match: `## Красные линии` — check for trailing spaces or encoding differences.»

**Resolver output:** emit resolved file с комментарием-заголовком `# GENERATED — do not edit. Source: base + <profile>/agent-overrides/<role>.md` — предотвращает случайное редактирование resolved файлов.

---

## Источники

- [primary] [Claude Code Sub-agents documentation](https://code.claude.com/docs/en/sub-agents) — каноническая документация по subagent frontmatter и scope priority
- [primary] [Claude Code Plugins reference](https://code.claude.com/docs/en/plugins-reference) — agent structure в plugin system
- [primary] [Cursor Rules documentation](https://docs.cursor.com/context/rules) — формат `.mdc`, merge semantics
- [primary] [Cline Rules documentation](https://docs.cline.bot/customization/cline-rules) — workspace vs global rules, fail-open validation
- [primary] [OpenHands microagents](https://docs.openhands.dev/modules/usage/prompting/microagents-repo) — frontmatter triggers, repo vs user precedence
- [primary] [GitHub Copilot custom instructions](https://docs.github.com/en/copilot/how-tos/configure-custom-instructions) — layered instructions, `applyTo` frontmatter
- [secondary] [VS Code Copilot customization](https://code.visualstudio.com/docs/copilot/customization/custom-instructions) — path-specific instructions format
- [primary] [Continue.dev configuration deep-dive](https://docs.continue.dev/customize/deep-dives/configuration) — mergeBehavior semantics
- [primary] [Aider conventions](https://aider.chat/docs/usage/conventions.html) — plain-markdown convention files, no inheritance
- [primary] [Jinja2 template inheritance](https://jinja.palletsprojects.com/en/stable/templates/) — `{% extends %}`, `{% block %}`, `{{ super() }}` — лучший аналог нашему дизайну
- [primary] [Helm values files](https://helm.sh/docs/chart_template_guide/values_files/) — deep merge maps, full replace arrays
- [secondary] [Kustomize strategic merge vs JSON6902](https://www.linkedin.com/pulse/patches-kustomize-json-6902-vs-strategic-merge-patch-adamson-hwngc) — два режима patch для разных сценариев
