# Расширение шаблона

Гайд по добавлению новой роли, pipeline или профиля в `project_template`.

## Как добавить новую роль (subagent)

1. Создать `.claude/plugins/project/agents/<role>-agent.md` с frontmatter:
   ```yaml
   ---
   name: <role>-agent
   description: |
     Что делает роль; триггеры активации.
   model: sonnet
   ---
   ```

2. Описать роль в `AGENTS.md` "Каталог ролей" (новая строка таблицы).

3. Добавить роль в матрицу «роль × профиль» в `AGENTS.md` (default: optional во всех профилях, кроме где явно core).

4. Создать slash-команду `.claude/plugins/project/commands/<role>.md` с frontmatter `description` + `allowed-tools: Task` и dispatch логикой.

5. Если роль будет в каком-то профиле — добавить в `subagents:` в `docs/overlays/profiles/<profile>/manifest.yaml` со статусом `core`/`optional`/`disabled`.

6. Прогнать `python3 scripts/validate-profile.py` — должно быть 0 errors (M4 проверит что роль объявлена в AGENTS.md).

## Как добавить новый pipeline

1. Создать `.claude/plugins/project/commands/pipelines/<name>.md` с orchestration-логикой:
   - Frontmatter: `description`, `allowed-tools`
   - Алгоритм: последовательность шагов (worktree → /research → /ba → ...)

2. Описать в `AGENTS.md` "Каталог pipelines" (новая строка таблицы: имя, назначение, артефакты, worktree).

3. Добавить в profile manifest'ы где relevant: `pipelines.<name>: enabled` или `optional` или `disabled`.

4. Прогнать `python3 scripts/validate-profile.py` — M5 проверит что файл pipeline'а существует.

## Как добавить новый профиль

1. Создать папку `docs/overlays/profiles/<name>/`.

2. Написать `manifest.yaml` (минимум 10 обязательных полей):
   ```yaml
   schema_version: 1
   name: <name>
   description: <human-readable>  # покажется в `init.sh` меню — пиши понятно для конечного пользователя
   audience: <human-readable>     # опц.; покажется как "[для: <audience>]" в меню
   status: stub  # или stable когда наполнишь scaffold
   subagents:
     pm: core
     # ... остальные роли (любые из AGENTS.md "Каталог ролей")
   pipelines: {}  # или конкретные pipeline'ы
   content_scaffold: ./   # или 'content-scaffold/' для stable
   doc_root: ./   # или 'doc-root.yaml' для stable
   operations: []
   compatible_stacks: []  # или ['*'] для совместимости с любым stack
   ```

   **W4c-B: при interactive `bash scripts/init.sh` profile menu показывает `<name> — <description> [для: <audience>]`.** Описание должно быть достаточно специфичным, чтобы пользователь мог отличить профили друг от друга в одной строке.

3. (Если `status: stable`) — наполнить `content-scaffold/` (минимум `_index.md` + поддиректории) + создать `doc-root.yaml` (шаблон `.doc-root.yaml` для профиля).

4. (Опц.) добавить в `init_prompts:` если профиль требует пользовательский ввод на init:
   ```yaml
   init_prompts:
     - id: <key>
       prompt: "Вопрос?"
       type: enum  # или string, bool
       choices: [a, b, c]  # для enum
       default: a
       on_value:
         a: { subagents.<role>: core }  # мутации manifest in-memory
   ```

5. Прогнать `python3 scripts/validate-profile.py docs/overlays/profiles/<name>` — exit 0.

6. Тест: `bash scripts/apply-overlay.sh --profile --dry-run <name>` — preview операций.

7. Добавить в матрицу «роль × профиль» в `AGENTS.md` (новая колонка).

8. (Опц.) добавить smoke-тест в `scripts/test-template.sh` (по образцу T-INIT-PROFILE-KB).

## Как добавить новый stack-overlay

(Существующая Wave 1 механика — справочно.)

1. Создать `docs/overlays/<stack-name>/` с patches для CLAUDE.md, agents, .doc-root.yaml, glossary (см. `docs/overlays/naumen-smp/` как пример).

2. Markers-based: каждый patch применяется через `apply-overlay.sh <stack-name>` (без `--profile`).

3. Если stack совместим с конкретными профилями — указать в `compatible_stacks:` соответствующих manifest'ов.

## Чеклист контроля

- [ ] `python3 scripts/validate-content.py` exit 0
- [ ] `python3 scripts/validate-profile.py` exit 0
- [ ] `bash scripts/test-validate-content.sh` PASS
- [ ] `bash scripts/test-validate-profile.sh` PASS
- [ ] `bash scripts/test-template.sh` PASS

## Дополнительно

- Полные prompt'ы агентов — в `.claude/plugins/project/agents/<role>-agent.md`.
- Полная схема manifest.yaml — в `docs/superpowers/specs/2026-05-06-multi-template-support-design.md` §4.1.
- Pipeline-orchestration model — в `AGENTS.md` секция "Pipeline-orchestration model".
