# Spec: Wave 3 — Tech-debt closure + DX tooling + Documentation polish

**Дата:** 2026-05-07
**Автор:** PM (main, Opus, claude-opus-4-7[1m])
**Статус:** Design — input для writing-plans
**Источник:** [Wave 3 kickoff prompt](2026-05-07-wave-3-kickoff-prompt.md), brainstorming-сессия 2026-05-07
**Эталон:** [Wave 2 design](2026-05-06-multi-template-support-design.md) (892 строки, для архитектурного контекста)
**Зависимости от Wave 2:** все контракты стабильны (validate-content C1-C7, manifest schema 12 полей, AGENTS.md heading anchor для M4, `.doc-root.yaml` schema, `_index.md` everywhere, object-нотация frontmatter)

---

## 1. Проблема

Wave 2 завершён (53 коммита, 8 фаз, 121 ассерт зелёный, validate-profile.py зелёный на 7 профилях), но финальный code review выявил **2 Critical + 9 Important + 7 Minor** issue. Critical устранены в W2-T44b×4, остальное — debt.

Главные дефекты:

1. **on_value мутации не подключены end-to-end.** `init.sh` собирал ответы init_prompts, но `apply-overlay.sh` их не читал. В W2-T44b удалили заглушки из project manifest и docs/commands — фактически промт удалён, но capability не реализована. Это **обещание спека без impl**.

2. **`apply-overlay.sh` массово spawn'ит subprocess shells** (5×subprocess per operation: yaml→sed→jq→bash). Это медленно, шумит quoting hazards (`$profile_dir` нет escaping), хрупко на macOS bash 3.2.

3. **Мелкие edge-cases:** M4 defensive guard молчит при не-парсящемся AGENTS.md; `schema_version` декларируется но не проверяется; hidden-file glob шумит при отсутствии dotfiles; symlinks под target пропускаются в is_safe_to_delete; `kb-team` оставляет «мёртвую» директорию `00-project/`.

4. **DX gaps:** Нет single entry-point для всех валидаций (`scripts/check.sh`); нет precommit gate (пользователь рискует коммитить broken `_index.md`).

5. **Documentation gaps:** Нет high-level architecture-overview, troubleshooting guide, или living examples post-init проектов. Новый пользователь шаблона должен читать W2 spec (892 строки) для общей картины.

## 2. Цель

Закрыть Wave 2 на чистовик + добавить базовый DX-обвес + основу documentation.

- **Group A** (tech-debt): полностью устранить 7 deferred items (A1–A7).
- **Group F** (DX): single entry-point `check.sh` + git pre-commit hook.
- **Group G** (docs): architecture-overview + troubleshooting + 2 quick-start examples.

**Anti-scope:** профиль-расширения (B), agent overrides (C), scrum-agile pipeline impl (D), migration tooling (E) — отложены в Wave 4. F2 (cascading validators) — мало ценности, исключено.

Wave 3 acceptance — в §10 (GO-criteria).

## 3. Архитектура

### 3.1. Высокоуровневая декомпозиция

```
┌─ Phase 1 (sequential): A2 — bash→Python helper рефакторинг
│   └── new scripts/_apply_profile.py (читает manifest, эмиттит JSON ops plan)
│   └── refactor scripts/apply-overlay.sh — one-shot helper invocation, JSON consume
│
├─ Phase 2 (sequential, after A2): A1 — on_value мутации end-to-end
│   ├── scripts/init.sh — export INIT_PROMPT_<id>=<value> env vars
│   ├── _apply_profile.py — read os.environ, apply on_value к manifest in-memory
│   ├── docs/overlays/profiles/project/manifest.yaml — restore init_prompts (был удалён в W2-T44b)
│   ├── .claude/plugins/project/commands/init.md — restore mention init_prompts
│   └── tests/test-template.sh — integration assert end-to-end mutation
│
├─ Phase 3 (mostly parallel): A3 + A4 + A7 — small fixes
│   ├── A3 + A4 (same file validate-profile.py — sequential, один subagent делает оба)
│   └── A7 (отдельный файл kb-team manifest — parallel)
│   NB: A5 и A6 поглощены Phase 1 (внутри A2 рефакторинга)
│
├─ Phase 4 (sequential): F4 — scripts/check.sh single entry-point
│
├─ Phase 5 (parallel, 4 subagents): F3 + G1 + G2 + G3
│   ├── F3 — git pre-commit hook (.githooks/pre-commit + scripts/install-hooks.sh)
│   ├── G1 — docs/architecture-overview.md
│   ├── G2 — docs/troubleshooting.md
│   └── G3 — examples/{project,kb-team}-example/
│
└─ Phase 6: integration smoke + lessons + auto-memory
```

### 3.2. File structure

```
scripts/
├── _apply_profile.py            # NEW (Group A2): Python helper, читает manifest +
│                                #   INIT_PROMPT_* env vars, применяет on_value мутации
│                                #   in-memory, эмиттит JSON ops plan на stdout
├── apply-overlay.sh             # REFACTOR (A2): one-shot helper invoke + JSON consume
│                                #   вместо 5×subprocess per op; вбирает A5 (nullglob dotglob)
│                                #   и A6 (symlink edge + named const)
├── init.sh                      # EDIT (A1): export INIT_PROMPT_<id>=<value>
│                                #   перед apply-overlay.sh --init
├── validate-profile.py          # EDIT (A3, A4): M4 visibility warning + schema_version check
├── check.sh                     # NEW (F4): single entry-point все валидации с --fast/--full
└── install-hooks.sh             # NEW (F3): git config core.hooksPath .githooks

.githooks/
└── pre-commit                   # NEW (F3): вызывает check.sh --fast

docs/overlays/profiles/
├── project/
│   └── manifest.yaml            # EDIT (A1): restore init_prompts: блок (compliance_domain)
└── kb-team/
    └── manifest.yaml            # EDIT (A7): добавить op:delete content/00-project/

.claude/plugins/project/commands/
└── init.md                      # EDIT (A1): restore mention init_prompts (был удалён W2-T44b)

docs/
├── architecture-overview.md     # NEW (G1): high-level diagram + 10 ролей + pipelines
├── troubleshooting.md           # NEW (G2): apply-overlay refuse, validator errors, init failures
├── lessons-learned.md           # APPEND: запись «Wave 3 итог»
└── superpowers/specs/
    └── 2026-05-07-wave-3-design.md  # эта спека

examples/
├── project-example/             # NEW (G3): post-init snapshot для project profile
│   ├── README.md                # «Это пример проекта на профиле project. Что внутри:»
│   ├── content/
│   │   ├── _index.md
│   │   ├── 00-project/
│   │   ├── 30-requirements/
│   │   ├── 40-architecture/
│   │   ├── 60-implementation/
│   │   └── 70-operations/
│   ├── .doc-root.yaml
│   ├── CLAUDE.md
│   ├── AGENTS.md
│   └── README.md
└── kb-team-example/             # NEW (G3): post-init snapshot для kb-team profile
    ├── README.md
    ├── content/
    │   ├── _index.md
    │   ├── 10-domain/
    │   ├── 20-onboarding/
    │   ├── 30-runbooks/
    │   ├── 40-roles/
    │   └── 50-incidents/
    ├── .doc-root.yaml
    ├── CLAUDE.md
    ├── AGENTS.md
    └── README.md

tests/ (через scripts/test-*.sh — bash harness Wave 1+2)
└── test-template.sh             # EDIT: + integration assert on_value mutation; + smoke check.sh; + smoke pre-commit hook
```

## 4. Компоненты

### 4.1. `scripts/_apply_profile.py` (NEW — A2)

Python 3 helper, читает manifest, эмиттит JSON ops plan для `apply-overlay.sh`.

#### CLI

```
python3 scripts/_apply_profile.py <profile-dir> [--init]
```

- `<profile-dir>` — путь к `docs/overlays/profiles/<name>/`
- `--init` — флаг «фреш init», передаётся в plan для bash (skip strict delete check)

#### Алгоритм

```python
def main(profile_dir: Path, init: bool) -> int:
    manifest = parse_yaml(profile_dir / "manifest.yaml")

    # A1: применить on_value мутации
    init_prompt_values = read_env_vars()  # INIT_PROMPT_<id> -> value
    for prompt in manifest.get("init_prompts", []):
        if prompt["id"] in init_prompt_values:
            value = init_prompt_values[prompt["id"]]
            on_value = prompt.get("on_value", {})
            if value in on_value:
                apply_mutation(manifest, on_value[value])
            elif prompt.get("type") == "enum" and value not in prompt.get("choices", []):
                error(f"Invalid value for {prompt['id']}: expected one of {prompt['choices']}, got {value}")
                return 1

    # A6: safety verdict для каждой op:delete
    plan = []
    for op in manifest["operations"]:
        verdict = compute_safety_verdict(op, init=init)
        plan.append({**op, "verdict": verdict})

    # Эмит JSON plan
    print(json.dumps({"profile": manifest["name"], "init": init, "ops": plan}))
    return 0
```

#### Output (JSON plan)

```json
{
  "profile": "project",
  "init": true,
  "ops": [
    {"op": "add", "source": "content-scaffold/", "target": "content/", "verdict": "safe"},
    {"op": "replace", "source": "doc-root.yaml", "target": "content/.doc-root.yaml", "verdict": "safe"},
    {"op": "delete", "target": "content/00-project/", "verdict": "safe", "reason": "scaffold-only baseline"}
  ]
}
```

#### Mutation semantics

`on_value: { 152-fz: { subagents.compliance: core } }` — dotted path в manifest. Helper парсит «subagents.compliance» как `manifest["subagents"]["compliance"]`, ставит value `"core"`. Это **только** in-memory; manifest на диске НЕ меняется (профильный контракт стабилен).

#### Why Python (vs bash)

- macOS bash 3.2 не имеет associative arrays; mutations через JSON natural в Python (dict.update).
- yaml.safe_load + json.dumps стандарт; bash нужен `yq` или цепочка `python -c` (5×subprocess).
- Тестируется как module: `from _apply_profile import apply_mutation`.

### 4.2. `scripts/apply-overlay.sh` (REFACTOR — A2, A5, A6)

Текущая логика разбивается на:

- **Wave 1 path** (без `--profile`): markers-based stack-overlay, не трогаем.
- **Wave 2/3 path** (с `--profile`): один вызов `_apply_profile.py`, парсинг JSON, выполнение операций.

#### Pseudo

```bash
if [[ "$PROFILE_MODE" == "1" ]]; then
    # A2: one-shot helper
    PLAN=$(python3 scripts/_apply_profile.py "docs/overlays/profiles/$NAME" $INIT_FLAG) || exit 1

    # A5: nullglob dotglob для add operations
    shopt -s nullglob dotglob

    # parse JSON plan
    echo "$PLAN" | python3 -c '
import sys, json
plan = json.load(sys.stdin)
for op in plan["ops"]:
    print(f"{op[\"op\"]}\t{op.get(\"source\", \"\")}\t{op[\"target\"]}\t{op[\"verdict\"]}")
' | while IFS=$'\t' read -r OP SRC DST VERDICT; do
        case "$OP" in
            add)     do_add "$SRC" "$DST" ;;
            replace) do_replace "$SRC" "$DST" ;;
            delete)  do_delete "$DST" "$VERDICT" ;;  # A6: verdict из helper'а
        esac
    done
else
    # Wave 1 markers-based path — без изменений
    ...
fi
```

### 4.3. `scripts/init.sh` (EDIT — A1)

После interactive `init_prompts` loop добавить export'ы:

```bash
for ID in "${PROMPT_IDS[@]}"; do
    eval "VAL=\$INIT_PROMPT_$ID"
    export "INIT_PROMPT_$ID=$VAL"
done

# далее apply-overlay.sh видит env vars
bash scripts/apply-overlay.sh --profile --init "$PROFILE"
```

`_apply_profile.py` читает `os.environ.get(f"INIT_PROMPT_{prompt['id']}")`.

### 4.4. `docs/overlays/profiles/project/manifest.yaml` (EDIT — A1)

Восстановить блок `init_prompts:` (был удалён в W2-T44b с reason «defer to Wave 3»):

```yaml
init_prompts:
  - id: compliance_domain
    prompt: "Проект под compliance-надзором?"
    type: enum
    choices: [none, 152-fz, iso27001, other]
    default: none
    on_value:
      152-fz:
        subagents.compliance: core
      iso27001:
        subagents.compliance: core
      other:
        subagents.compliance: core
```

### 4.5. `.claude/plugins/project/commands/init.md` (EDIT — A1)

Вернуть в команду упоминание init_prompts (после W2-T44b чистки). Раздел про interactive flow.

### 4.6. `scripts/validate-profile.py` (EDIT — A3, A4)

#### A3: M4 visibility warning

Текущий код: если AGENTS.md существует, но `## Каталог ролей` table не парсится — silently пропускает M4. Теперь:

```python
def collect_known_roles() -> set[str] | None:
    agents_md = repo_root / "AGENTS.md"
    if not agents_md.exists():
        return None  # M4 skipped silently

    table = parse_roles_table(agents_md)
    if not table:
        warning(f"{agents_md}: '## Каталог ролей' heading found but role table not parseable; M4 skipped")
        return None
    return table
```

5-line добавление (warning emit) — не меняет M4 контракт.

#### A4: schema_version enum check

```python
def check_schema_version(manifest: dict) -> list[Issue]:
    sv = manifest.get("schema_version")
    if sv not in (1,):
        return [Issue("error", manifest_path, f"unsupported schema_version: {sv} (expected 1)")]
    return []
```

Запускается в `validate_manifest` рядом с M2 (required fields).

### 4.7. `apply-overlay.sh` / `_apply_profile.py` (EDIT — A5, A6)

- **A5:** перед `cp -r` добавить `shopt -s nullglob dotglob` (или эквивалент в Python через `glob.glob` с правильным флагом). Устраняет шум при отсутствии hidden files в source.
- **A6:** `is_safe_to_delete`:
  - Symlinks под target — добавить test «scaffold-only empty subdirs ⇒ safe-to-delete» в `test-validate-profile.sh`. Сейчас symlinks пропускаются (не учитываются в подсчёте); сделать explicit «symlinks count as content» (если не точно baseline `.gitkeep` symlink).
  - 500B threshold — заменить magic number на `BASELINE_CONTENT_MAX_BYTES = 500` (named constant) + comment почему 500B.

### 4.8. `docs/overlays/profiles/kb-team/manifest.yaml` (EDIT — A7)

Добавить в `operations:`:

```yaml
- op: delete
  target: content/00-project/
  reason: "kb-team не использует delivery-структуру 00-project (нет ADR, plans, critical-path)"
```

И обновить `test-template.sh` — после init kb-team assert `[ ! -d content/00-project ]`.

### 4.9. `scripts/check.sh` (NEW — F4)

Single entry-point для всех валидаций.

#### CLI

```
scripts/check.sh [--fast | --full]
```

- `--fast` (default): validate-content + validate-profile (быстрые, ~3 сек total)
- `--full`: + test-validate-content + test-validate-profile + test-template (полный smoke, ~30 сек)

#### Pseudo

```bash
#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---fast}"

echo "▶ validate-content.py"
python3 scripts/validate-content.py

echo "▶ validate-profile.py"
python3 scripts/validate-profile.py

if [[ "$MODE" == "--full" ]]; then
    echo "▶ test-validate-content.sh"
    bash scripts/test-validate-content.sh
    echo "▶ test-validate-profile.sh"
    bash scripts/test-validate-profile.sh
    echo "▶ test-template.sh"
    bash scripts/test-template.sh
fi

echo "✓ check.sh $MODE — passed"
```

Exit code 0 — все зелёные; non-zero — пробрасывается из первого failed validator'а.

### 4.10. `.githooks/pre-commit` + `scripts/install-hooks.sh` (NEW — F3)

#### `.githooks/pre-commit`

```bash
#!/usr/bin/env bash
# Activated via: git config core.hooksPath .githooks
exec bash scripts/check.sh --fast
```

executable bit + commit'ится в репо.

#### `scripts/install-hooks.sh`

```bash
#!/usr/bin/env bash
# Активирует git hooks из .githooks/
git config core.hooksPath .githooks
echo "✓ Pre-commit hook activated. Disable: git config --unset core.hooksPath"
```

Пользователь запускает один раз после clone.

#### Mention в README + init.sh

В `README.md` — секция «Setup pre-commit hooks (опционально)» с одной командой.
В `scripts/init.sh` — после initial commit спросить «Активировать pre-commit hook? [Y/n]» (default Y, но **не обязательное** — hook опциональный).

#### Why git hook (not Claude hook)

- Git hook universal — работает в любом окружении (CLI, CI, IDE), не только в Claude Code.
- Claude hook (PreToolUse) ограничен Claude Code сессией.
- `.githooks/` — стандартная convention; commit'ится в репо.

### 4.11. `docs/architecture-overview.md` (NEW — G1)

High-level overview шаблона. Структура:

1. **Цель шаблона** — кто пользователь, что получает на init.
2. **Профильная система** — 7 профилей, manifest schema, apply-overlay.sh контракт.
3. **Каталог ролей** — 10 ролей (PM main + 9 subagent), pipeline-orchestration model.
4. **Содержимое (`content/`)** — Gramax-каталог, `_index.md`, `.doc-root.yaml`, frontmatter.
5. **Validators** — validate-content (C1-C7), validate-profile (M1-M10).
6. **Workflow** — private/public branches, /pm decompose → /sa design → /dev → /pm-review.
7. **Mermaid диаграмма** — компонентная карта (init.sh → apply-overlay.sh → _apply_profile.py → content/ + .doc-root.yaml + AGENTS.md → validators).

Размер: ~150-250 строк markdown, не дублирует W2 spec, а агрегирует ключевые точки.

### 4.12. `docs/troubleshooting.md` (NEW — G2)

FAQ-стиль. Темы:

| Симптом | Причина | Fix |
|---------|---------|-----|
| `apply-overlay.sh` отказывается удалять `content/<dir>/` | non-empty + `_apply_profile.py` verdict «refuse» | `--force` или ручная проверка: что в директории? |
| `validate-profile.py` exit 1 «manifest.yaml not found» | профиль-папка без manifest | создать manifest по template из `docs/overlays/profiles/project/manifest.yaml` |
| `validate-content.py` exit 1 «orphan content` | подпапка без `_index.md` | создать `_index.md` (без frontmatter properties) |
| `init.sh` падает после прохождения init_prompts | `apply-overlay.sh --init` не находит профиль | проверить что `--profile` указывает на существующий dir |
| Pre-commit hook блокирует commit с «placeholder unfilled» | в файле остался `{{PROJECT_NAME}}` | пройти `/init` Phase 2 до конца ИЛИ заменить вручную |
| `validate-profile.py` warning «AGENTS.md exists but role table not parsed» | M4 visibility (A3) — heading anchor сломан | проверить heading `## Каталог ролей` в AGENTS.md |

~50-100 строк markdown.

### 4.13. `examples/{project,kb-team}-example/` (NEW — G3)

**Минимальный post-init snapshot.** Цель: новый пользователь видит «вот что должно получиться после init project / kb-team» без запуска `init.sh`.

#### Содержимое каждого example

- `README.md` — «Это пример проекта на профиле X. Создан запуском `bash scripts/init.sh --profile X "Example Name" "EX" "..." "owner@x.com"`.»
- `content/` — full scaffold с заполненными `_index.md` (placeholder'ы заменены)
- `.doc-root.yaml`
- `CLAUDE.md`, `AGENTS.md`, `README.md` (project-уровень)

#### НЕ делаем (anti-scope для G3)

- ❌ Полноценные «живые» примеры с реальными требованиями / ADR / реализацией. Только структурный snapshot.
- ❌ Examples для других 5 профилей — они stub в Wave 3.
- ❌ Generation script (auto-update examples при изменениях шаблона). Static snapshot, обновляется руками если что.

## 5. Data flow

### 5.1. on_value мутация end-to-end (A1 + A2)

```
User
  │ bash scripts/init.sh --profile project "MyProj" "MP" "desc" "u@x.com"
  ▼
init.sh (Phase 1)
  ├── parse args + interactive missing (PROFILE=project)
  ├── load manifest: docs/overlays/profiles/project/manifest.yaml
  ├── interactive init_prompts:
  │     ┃ "Проект под compliance-надзором?"
  │     ┃ choices: [none, 152-fz, iso27001, other], default: none
  │     ┃ user: 152-fz
  ├── export INIT_PROMPT_compliance_domain=152-fz
  ├── replace_in_file CLAUDE.md/AGENTS.md/README.md/content (плейсхолдеры)
  ├── bash scripts/apply-overlay.sh --profile --init project
  │     ├── PROFILE_MODE=1, NAME=project, INIT_FLAG=--init
  │     ├── PLAN=$(python3 scripts/_apply_profile.py docs/overlays/profiles/project --init)
  │     │     │
  │     │     ▼
  │     │   _apply_profile.py
  │     │     ├── parse_yaml(manifest.yaml)
  │     │     ├── read os.environ for INIT_PROMPT_*
  │     │     │     INIT_PROMPT_compliance_domain=152-fz
  │     │     ├── apply on_value мутации:
  │     │     │     manifest.subagents.compliance: optional → core
  │     │     ├── compute safety verdicts для each op
  │     │     └── emit JSON plan на stdout
  │     ├── parse JSON plan
  │     ├── shopt -s nullglob dotglob (A5)
  │     ├── for each op: do_add | do_replace | do_delete (с verdict из helper'а)
  │     └── validate-content.py + validate-profile.py
  ├── (опц.) применить stack-overlay'и из compatible_stacks
  ├── wipe .git, init, initial commit
  └── (опц.) setup origin
```

Ключевое: после init AGENTS.md матрица содержит `compliance: core` (вместо optional из base manifest), потому что mutation применилась к manifest in-memory.

> NB: AGENTS.md матрица — это derived представление, которое генерируется (или человек ведёт). В Wave 3 синхронизация derived матрицы — manual contract (как в Wave 2). Если CI-проверка нужна — Wave 4.

### 5.2. Pre-commit hook flow (F3)

```
User
  │ git add . && git commit -m "..."
  ▼
git: triggers .githooks/pre-commit (если активирован через core.hooksPath)
  └── exec bash scripts/check.sh --fast
        ├── python3 scripts/validate-content.py
        │     ├── if any C1-C7 violation → exit 1 → commit blocked
        │     └── ✓ → proceed
        ├── python3 scripts/validate-profile.py
        │     └── ✓ или exit 1 → commit blocked
        └── exit 0 → commit proceeds

Escape hatch: git commit --no-verify (стандартный git)
```

## 6. Error handling

### 6.1. `_apply_profile.py`

| Ошибка | Поведение |
|--------|-----------|
| Manifest YAML malformed | exit 1 + сообщение «manifest.yaml: parse error at line X» |
| `INIT_PROMPT_<id>` value не из enum choices | exit 1 + «expected one of [...], got X» |
| `on_value` ссылается на несуществующий dotted path в manifest | exit 1 + «invalid mutation: subagents.unknown_role does not exist» |
| Operations array не существует или пустой | exit 0 (warning) + emit empty plan |

### 6.2. `apply-overlay.sh`

| Ошибка | Поведение |
|--------|-----------|
| `_apply_profile.py` exit non-zero | bash exit с тем же code, не выполняет операции |
| JSON plan malformed (parse error) | exit 1 + «helper emitted invalid plan» |
| `do_delete` с verdict «refuse» и без `--force` | exit 1 + перечисляет что было бы удалено + suggest `--force` |
| `do_add` source не существует | exit 1 |

### 6.3. `check.sh`

| Ошибка | Поведение |
|--------|-----------|
| validate-content exit 1 | check.sh exit 1, не запускает validate-profile (fast-fail) |
| validate-profile exit 1 | check.sh exit 1 |
| `--full`: test-* exit 1 | check.sh exit 1, печатает какой test упал |

### 6.4. Pre-commit hook (F3)

| Ошибка | Поведение |
|--------|-----------|
| `check.sh --fast` exit non-zero | git commit blocked, hook exit non-zero |
| `core.hooksPath` не установлен | hook не вызывается (default git behavior) |
| Hook script not executable | git error «cannot execute hook» — install-hooks.sh ставит +x |

## 7. Тесты

### 7.1. Unit-уровень — `_apply_profile.py`

Inline doctests или отдельный `scripts/test-_apply-profile.sh` (если будет нужно):

- `apply_mutation` корректно ставит dotted path
- `parse on_value` детектит нарушение manifest schema
- `safety_verdict` для symlink-only target → safe
- `safety_verdict` для baseline `_index.md + .gitkeep` → safe
- `safety_verdict` для non-baseline content → refuse

### 7.2. Validator-уровень — `validate-profile.py`

Расширить `test-validate-profile.sh`:

- A3: AGENTS.md с broken heading (`## Catalog of roles` вместо `## Каталог ролей`) → warning emit
- A4: manifest с `schema_version: 99` → error
- A4: manifest с `schema_version: 1` (текущий valid) → no error
- A6: profile с symlink-only target → safe-to-delete

### 7.3. Integration — `test-template.sh`

Существующие 121 ассерт остаются зелёными (regression-only для A2).

**Новые ассерты:**

- T-W3-A1: `bash scripts/init.sh --profile project --init-prompts compliance_domain=152-fz "..."` (или через env var) → assert финальный manifest in-memory имеет subagents.compliance: core (через generated AGENTS.md или log helper'а)
- T-W3-A7: после init kb-team → `[ ! -d content/00-project ]`
- T-W3-F4-fast: `bash scripts/check.sh --fast` exit 0
- T-W3-F4-full: `bash scripts/check.sh --full` exit 0
- T-W3-F3: install-hooks.sh + создать commit с broken `_index.md` (placeholder unfilled) → commit blocked

### 7.4. Backwards compatibility

- Старый `apply-overlay.sh naumen-smp` (markers-based, без `--profile`) работает идентично Wave 1+2
- `init.sh` без `--profile` → fallback на `project`, как в Wave 2
- Все existing 7 профилей валидируются validate-profile.py (без regress)

## 8. Phase plan + параллельность

### Phase 1: A2 — bash→Python helper (sequential, ~3-5 task)

- T1: `_apply_profile.py` — implement skeleton (parse manifest, emit JSON plan для simple operations без on_value)
- T2: `apply-overlay.sh` — refactor на one-shot helper invocation, JSON consume, do_add/do_replace/do_delete функции
- T3: regression — все existing test-template.sh ассерты зелёные
- T4: A5 (nullglob dotglob) внутри refactor'а
- T5: A6 (symlink edge + named const) внутри refactor'а

### Phase 2: A1 — on_value end-to-end (sequential, ~5 task)

- T6: `_apply_profile.py` — read INIT_PROMPT_* env vars + apply on_value mutations
- T7: `init.sh` — export INIT_PROMPT_<id> перед apply-overlay
- T8: restore `init_prompts:` в `docs/overlays/profiles/project/manifest.yaml`
- T9: restore mention init_prompts в `commands/init.md`
- T10: integration test T-W3-A1 (end-to-end mutation assert)

### Phase 3: A3 + A4 + A7 (2 subagents)

- T11 + T12 (один subagent, sequential — оба меняют `validate-profile.py`):
  - T11: A3 — M4 visibility warning в `validate-profile.py` + assertion
  - T12: A4 — schema_version enum check + assertion
- T13 (parallel subagent): A7 — kb-team manifest op:delete content/00-project/ + assertion в test-template.sh

> A5 и A6 поглощены Phase 1 (внутри A2 рефакторинга).

### Phase 4: F4 — check.sh (sequential, ~2 task)

- T14: `scripts/check.sh` — implement --fast / --full режимы
- T15: integration tests T-W3-F4-fast + T-W3-F4-full

### Phase 5: F3 + G1 + G2 + G3 (parallel, 4 subagents)

- T16 (parallel, F3): `.githooks/pre-commit` + `scripts/install-hooks.sh` + README mention + integration test T-W3-F3
- T17 (parallel, G1): `docs/architecture-overview.md`
- T18 (parallel, G2): `docs/troubleshooting.md`
- T19 (parallel, G3-project): `examples/project-example/`
- T20 (parallel, G3-kb-team): `examples/kb-team-example/`

### Phase 6: integration + lessons + memory

- T21: финальный smoke `bash scripts/check.sh --full` зелёный
- T22: `docs/lessons-learned.md` append «Wave 3 итог» запись
- T23: auto-memory updates (feedback / project / reference); финальный requesting-code-review на ветку

**Total: ~22-23 задачи. ✓ medium budget (20-25).**

### Параллельность граф

```
Phase 1 (T1-T5) ──→ Phase 2 (T6-T10) ──→ Phase 3 ((T11→T12) || T13) ──→ Phase 4 (T14-T15)
                                                                              │
                                                                              ▼
                                                           Phase 5 (T16||T17||T18||T19||T20)
                                                                              │
                                                                              ▼
                                                                       Phase 6 (T21-T23)
```

## 9. Anti-scope

Что Wave 3 **НЕ** делает (вход в Wave 4+):

- ❌ **Group B** — расширение stub-профилей (product, kb-product, methodology, course, custom) до stable
- ❌ **Group C** — profile-specific agent overrides (tech-writer как primary в kb-product/methodology/course; mechanic для override resolution)
- ❌ **Group D** — scrum-agile pipeline impl (остаётся stub в манифестах)
- ❌ **Group E** — migration tooling (`migrate-profile.sh`, `upgrade-template.sh`)
- ❌ **F2** — cascading validators параллельно (мало ценности; validators быстрые)
- ❌ Изменение Wave 2 контрактов (validate-content C1-C7, manifest schema 12 полей, AGENTS.md heading anchor для M4, `.doc-root.yaml` palette, schema `_index.md`, object-нотация frontmatter)
- ❌ Auto-update derived AGENTS.md матрицы из manifest'ов (manual contract остаётся; автоматизация — Wave 4)
- ❌ Generation script для examples/ (static snapshot, обновляется руками)
- ❌ Полноценные «живые» примеры с реальными требованиями/ADR/кодом в examples/ (только структурный post-init snapshot)
- ❌ pytest-стиль тестов для `_apply_profile.py` (продолжаем bash-харнесс из Wave 1+2; inline doctests OK)

## 10. GO-критерии Wave 3

Wave 3 закрыт, когда:

- [ ] **A2:** `scripts/_apply_profile.py` создан, эмиттит валидный JSON ops plan; `apply-overlay.sh` рефакторен на one-shot invoke; все existing 121 ассерт зелёные (regression-only); A5 (nullglob dotglob) и A6 (symlink edge + named constant) внутри
- [ ] **A1:** on_value мутации работают end-to-end (init.sh export INIT_PROMPT_* → helper applies); `init_prompts:` восстановлен в `docs/overlays/profiles/project/manifest.yaml`; mention восстановлен в `commands/init.md`; integration test T-W3-A1 зелёный
- [ ] **A3:** M4 visibility warning emit'ится в `validate-profile.py` при не-парсящемся AGENTS.md; assertion в `test-validate-profile.sh`
- [ ] **A4:** `schema_version` enum check работает; assertion в `test-validate-profile.sh`
- [ ] **A7:** `docs/overlays/profiles/kb-team/manifest.yaml` содержит op:delete content/00-project/; после init kb-team `content/00-project/` отсутствует; assertion в `test-template.sh`
- [ ] **F4:** `scripts/check.sh` поддерживает `--fast` (~3 сек) и `--full` (~30 сек) режимы; integration tests T-W3-F4-fast + T-W3-F4-full зелёные
- [ ] **F3:** `.githooks/pre-commit` + `scripts/install-hooks.sh` существуют; README дополнен секцией «Setup pre-commit hooks»; integration test T-W3-F3 зелёный
- [ ] **G1:** `docs/architecture-overview.md` написан (~150-250 строк, mermaid диаграмма, 7 секций)
- [ ] **G2:** `docs/troubleshooting.md` написан (~50-100 строк, FAQ-стиль)
- [ ] **G3:** `examples/project-example/` + `examples/kb-team-example/` существуют с full scaffold + заполненными `_index.md` + README
- [ ] **Backwards compatibility:** старый `apply-overlay.sh naumen-smp` (markers) работает; `init.sh` без `--profile` → fallback на project; все 7 манифестов валидируются
- [ ] **Финальный smoke:** `bash scripts/check.sh --full` exit 0 на финальной ветке
- [ ] **Lessons:** `docs/lessons-learned.md` дополнен записью «Wave 3 итог»
- [ ] **Auto-memory:** обновлены ключевые feedback / project / reference записи
- [ ] **Code review:** финальный `superpowers:requesting-code-review` пройден перед merge `private` → `public`

## 11. Открытые вопросы (для writing-plans / SDD)

Это вопросы, которые brainstorming не закрыл; SA / writing-plans / implementation проработают:

1. **Точный JSON schema для ops plan** от `_apply_profile.py` — лучше формализовать через jsonschema, или достаточно inline contract? *(Предлагаю inline contract в W3 + добавить formal schema в W4 если потребуется.)*
2. **mutation dotted-path syntax** — поддерживает ли только `manifest.subagents.compliance`, или нужен полный JSONPath? *(Предлагаю simple dotted-path в W3; JSONPath — overkill для текущего use case.)*
3. **install-hooks.sh — спрашивать ли в `init.sh`?** Default Y или N? *(Предлагаю default N — opt-in; пользователь активирует осознанно. Mention в README + post-init message.)*
4. **G3 examples — generate ли их через `init.sh` в CI, или ручной snapshot?** *(Предлагаю manual snapshot в Wave 3; auto-generation — Wave 4 если pain.)*
5. **A6 BASELINE_CONTENT_MAX_BYTES = 500** — закрепить как Python constant в `_apply_profile.py` (а не в bash)? *(Да, в Python helper, после A2 рефакторинга вся логика безопасности живёт там.)*
6. **T11/T12/T13 параллельность** — три параллельных subagent'а трогают разные файлы (validate-profile.py, kb-team manifest), но T11 и T12 оба меняют `validate-profile.py`. **Уточнение:** T11+T12 НЕ параллелим (тот же файл) — последовательно или один subagent делает оба. T13 (kb-team manifest) — параллелим.

Эти вопросы либо проработаются в writing-plans, либо превратятся в Implementation Notes в коде.

## 12. Self-Review

### 12.1. Placeholder scan

✓ Нет TBD/TODO в spec'е (все секции наполнены).
✓ Нет «similar to X» — каждая секция самодостаточна.
✓ Открытые вопросы явно отнесены в §11 на writing-plans / SDD-этап.

### 12.2. Internal consistency

✓ §3.2 (file structure) согласуется с §4 (компоненты) — все упоминаемые файлы в structure описаны в components.
✓ §8 (phase plan) согласуется с §10 (GO-критерии) — все checkbox'ы покрыты задачами в phase plan.
✓ §11.6 уточняет параллельность Phase 3 (T11+T12 sequential, T13 parallel) — fix внутри §8 inline (T11+T12 одним subagent'ом или sequentially).
✓ Anti-scope (§9) согласуется с GO-критериями (§10) — то что не делаем, не упоминается в check'ах.

### 12.3. Scope check

✓ Wave 3 фокусирован на tech-debt closure + DX + docs polish. Один spec → один plan → одна реализация (через SDD итеративно).
✓ ~22-23 задачи в medium budget (20-25). Маржа 2-3 задачи на непредвиденное.

### 12.4. Ambiguity check

Спорных мест:

- ✓ «on_value мутация» — определена точно: «dotted path в manifest in-memory; manifest на диске НЕ меняется» (§4.1).
- ✓ «pre-commit hook git vs Claude» — выбор зафиксирован (git, через `.githooks/`); justification в §4.10.
- ✓ «examples scope» — anti-scope в §4.13 явно: только структурный snapshot, не «живые» проекты.
- ✓ «Phase 3 параллельность» — изначально 5 subagents, скорректировано до T11+T12 sequential + T13 parallel (см. §11.6 + §8).

Ambiguity, если найдена при реализации — фиксим в плане writing-plans или в коде.

---

## 13. Метаданные

- **Зависимости от Wave 2:** все контракты (validate-content C1-C7, manifest schema 12 полей, AGENTS.md `## Каталог ролей` heading anchor, `.doc-root.yaml` schema, `_index.md` everywhere, object-нотация frontmatter, apply-overlay markers-based for stacks) — НЕ трогаем.
- **Зависимости на superpowers:** `writing-plans`, `subagent-driven-development`, `test-driven-development`, `requesting-code-review`, `using-git-worktrees`, `dispatching-parallel-agents`.
- **Эффект на пользователя:** существующий проект продолжит работать (backwards compatible); новые проекты получат рабочий on_value (compliance opt-in реально работает) + опциональный pre-commit gate + диагностика через troubleshooting + примеры.
- **Эффект на CI:** test-template.sh время не растёт значимо (regression-only A2 + 5 новых targeted assertions); `check.sh --full` ~30 сек total.
- **Subagent model:** Opus для implementer'ов и reviewer'ов (per memory `feedback_subagent_opus_authorized.md` — owner авторизовал в Wave 2 для этого репо).

---

**Next steps after этого spec'а:**

1. Owner ревьюит spec → approve / request changes.
2. После approve — `superpowers:writing-plans` создаёт granular plan в `docs/superpowers/plans/2026-05-07-wave-3.md`.
3. После plan approve — `superpowers:subagent-driven-development` (Opus implementer'ы) реализует.
4. После каждой Phase — `superpowers:requesting-code-review` на изменённый scope (Wave 2 lesson: ловить проблемы на фазах, не в финале).
5. Финальный full-branch review перед merge `private` → `public`.
