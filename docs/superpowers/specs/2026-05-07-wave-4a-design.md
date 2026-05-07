# Spec: Wave 4a — Override mechanic core + kb-product pilot

**Дата:** 2026-05-07
**Автор:** PM (main, Opus, claude-opus-4-7[1m])
**Статус:** Design — input для writing-plans
**Зависимости от Wave 3:** все контракты стабильны (validate-content C1-C7, manifest schema_version=1, AGENTS.md heading anchor, `_apply_profile.py` JSON ops contract, on_value via `INIT_PROMPT_*` env vars, `check.sh --fast/--full`)
**Pacing:** B (W4a + W4b split — см. §9 anti-scope про W4b)

---

## 1. Проблема

После Wave 3 шаблон имеет 7 профилей, но только **2 stable** (project, kb-team). Остальные 5 (product, kb-product, methodology, course, custom) — stub-ы со skeleton manifest и пустыми `agent-overrides/.gitkeep`. Без override-механики все профили получают одни и те же base-агенты (`.claude/plugins/project/agents/<role>.md`), что нарушает per-profile контекст:

- В `kb-product` (customer-facing docs) роль `tech-writer` должна быть primary, с фокусом на структуру customer journey, screenshot conventions, version pinning. Сейчас tech-writer — generic.
- В `methodology` (playbook) роль `ba` должна работать с принципами и шаблонами, не с user stories.
- В `course` обучающий контент требует другого тона у `tech-writer` (lesson plans, exercises).

Базовая проблема: **нет механизма per-profile customization агент-промтов**. Профили могут только включать/выключать роли (`subagents.X: core/optional/disabled`), но не менять их поведение.

Дополнительно: 5 minor tech-debt items из Wave 3 (memory `project_wave_state.md` §"Известные follow-up'ы") — низкая поштучная ценность, но накапливаются.

## 2. Цель

Реализовать override-механику base + delta merge end-to-end + поднять **один пилотный профиль** (`kb-product`) до stable как реальный consumer механики.

- **Group P0** (W3-minors): закрыть 5 follow-up'ов из Wave 3 памяти.
- **Group P1-P3** (overrides core): research + BRQ + ADR + `_resolve_agents.py` + integration в `apply-overlay.sh`/`_apply_profile.py` + validator M11.
- **Group P4** (kb-product pilot): полный stable-комплект для kb-product (manifest enrichment + content-scaffold + agent-overrides/tech-writer + example).
- **Group P6** (docs + smoke): обновление architecture-overview + troubleshooting + lessons + final review.

**Anti-scope (отнесено в W4b):**
- 4 оставшихся stub-профиля (product, methodology, course, custom) → stable
- Interactive override customization в `init.sh` (Phase 5 в исходной декомпозиции)
- Расширение init UX (меню профилей с описаниями) — пока остаётся текущий flow

W4a acceptance — в §10.

## 3. Архитектура

### 3.1. Высокоуровневая декомпозиция

```
┌─ Phase 0 (parallel × 2-3): W3-minors
│   └── DEV-401..403 — load_manifest exception, ops_count optimize, multiline reason guard
│
├─ Phase 1 (sequential RES → BA): research + requirements
│   ├── RES-410 — override mechanics in Claude Code plugins / Cursor / Cline
│   ├── BA-411 — BRQ override mechanic (формат frontmatter, что override'ится, edge cases)
│   └── BA-412 — BRQ + content scaffold для kb-product (короткий, ~30 строк)
│
├─ Phase 2 (sequential SA): архитектура и спеки
│   ├── SA-420 — ADR override resolution (base + delta merge, schema_version=2 migration)
│   ├── SA-421 — Spec scripts/_resolve_agents.py (CLI, JSON contract с _apply_profile.py)
│   └── SA-422 — Spec kb-product (manifest extension + scaffold tree + override list)
│
├─ Phase 3 (sequential DEV — общая инфраструктура): override resolver + integration
│   ├── DEV-430 — scripts/_resolve_agents.py skeleton + base + delta merge logic
│   ├── DEV-431 — _apply_profile.py emits resolved-agents step в JSON plan
│   ├── DEV-432 — apply-overlay.sh integration: copy resolved prompts → .claude/plugins/project/agents/
│   ├── DEV-433 — validate-profile.py M11: override sanity (base exists, frontmatter valid)
│   └── DEV-434 — test-validate-profile.sh + test-template.sh ассерты + demo override tech-writer для kb-team (минимальный реальный case)
│
├─ Phase 4 (sequential DEV — kb-product pilot): профиль end-to-end
│   ├── DEV-440 — kb-product manifest enrichment + .doc-root.yaml + content-scaffold/
│   ├── DEV-441 — agent-overrides/tech-writer.md (delta для customer-facing docs)
│   └── DEV-442 — examples/kb-product-example/ + ассерты в test-template.sh
│
└─ Phase 6 (parallel × 2 + sequential): docs + lessons + smoke
    ├── DEV-460 — docs/architecture-overview.md: раздел overrides + диаграмма resolution
    ├── DEV-461 — docs/troubleshooting.md: override edge-cases (FAQ-стиль)
    ├── DEV-462 — docs/lessons-learned.md: Wave 4a итог
    └── DEV-463 — final code review (requesting-code-review) + auto-memory updates + smoke check.sh --full
```

### 3.2. File structure

```
scripts/
├── _resolve_agents.py              # NEW (P3): resolver — base + delta merge → resolved prompts
├── _apply_profile.py               # EDIT (P0+P3): exception вместо sys.exit; emit resolved-agents step;
│                                   #   strip newlines guard на reason
├── apply-overlay.sh                # EDIT (P0+P3): убрать лишний python3 invocation для ops_count;
│                                   #   quote init_flag (SC2086); copy resolved prompts step
└── validate-profile.py             # EDIT (P3): M11 — override sanity (base exists, frontmatter valid)

docs/overlays/profiles/
├── kb-team/                        # EDIT (P3-T434): добавить demo override tech-writer.md
│   └── agent-overrides/
│       └── tech-writer.md          # NEW (минимальный override как proof of concept)
└── kb-product/                     # P4: enrichment до stable
    ├── manifest.yaml               # EDIT — добавить content_scaffold path, operations, agent_overrides
    ├── doc-root.yaml               # NEW — properties для customer docs (Тип контента, Версия продукта, Аудитория)
    ├── content-scaffold/           # NEW — getting-started/, guides/, reference/, troubleshooting/
    │   ├── _index.md
    │   ├── getting-started/_index.md
    │   ├── guides/_index.md
    │   ├── reference/_index.md
    │   └── troubleshooting/_index.md
    └── agent-overrides/
        └── tech-writer.md          # NEW (P4-T441): customer-facing docs delta

examples/
└── kb-product-example/             # NEW (P4-T442): post-init snapshot
    ├── README.md
    ├── content/{getting-started,guides,reference,troubleshooting}/
    ├── .doc-root.yaml
    ├── CLAUDE.md, AGENTS.md, README.md
    └── .claude/plugins/project/agents/tech-writer-agent.md  # resolved version

docs/
├── architecture-overview.md        # EDIT — добавить раздел "Agent overrides + resolution"
├── troubleshooting.md              # EDIT — append override edge-cases
└── lessons-learned.md              # APPEND — Wave 4a запись

content/00-project/adr/
└── ADR-XXX-agent-overrides.md      # NEW (SA-420): зафиксировать выбор base + delta merge

scripts/test-*.sh
├── test-validate-profile.sh        # EDIT — M11 ассерты (override sanity)
└── test-template.sh                # EDIT — kb-product init flow + override applied ассерты
```

## 4. Компоненты

### 4.1. `scripts/_resolve_agents.py` (NEW — P3)

Python helper, читает base prompts + per-profile overrides, эмиттит resolved prompts в target dir.

#### CLI
```
python3 scripts/_resolve_agents.py <profile-dir> --base-dir <base-agents-dir> --target-dir <out-dir>
```

- `<profile-dir>` — `docs/overlays/profiles/<name>/` (читает `manifest.yaml` для списка агентов и `agent-overrides/` для delta-файлов)
- `--base-dir` — `.claude/plugins/project/agents/` (источник base prompts)
- `--target-dir` — где разместить resolved prompts (обычно тот же `.claude/plugins/project/agents/` в working tree после init)

#### Алгоритм
```python
def main(profile_dir, base_dir, target_dir):
    manifest = parse_yaml(profile_dir / "manifest.yaml")
    overrides = manifest.get("agent_overrides", {})

    for role, status in manifest["subagents"].items():
        if status == "disabled":
            continue
        base_path = base_dir / f"{role}-agent.md"
        if not base_path.exists():
            error(f"base prompt not found for role: {role}")
            return 1

        if role in overrides:
            override_path = profile_dir / overrides[role]["source"]
            resolved = merge_delta(base_path, override_path)
        else:
            resolved = base_path.read_text()

        (target_dir / f"{role}-agent.md").write_text(resolved)

    return 0
```

#### Merge semantics (base + delta)

**Frontmatter:**
- Override содержит `extends: <role-name>` (обязательное поле — связь с base; mismatch → error)
- Прочие frontmatter поля override'а **полностью замещают** одноимённые в base
- Поля, отсутствующие в override, **наследуются** из base

**Body (markdown секции):**
- Секция = `## Heading` до следующего `## Heading` или EOF
- **Heading match — exact** (case + whitespace + punctuation чувствительны). `## Красные линии` ≠ `## Красные Линии` ≠ `## Красные  линии`. Документировать в troubleshooting (§4.13)
- Если override содержит `## X` — она **полностью заменяет** одноимённую секцию в base (delta = «секция полностью переопределена»)
- Секции в base, отсутствующие в override, **наследуются** дословно
- Секции в override, отсутствующие в base, **добавляются** (после всех base-секций)
- **`{{super}}` placeholder** (Jinja2-аналог): если секция override содержит `{{super}}` — resolver подставляет на это место содержимое одноимённой секции base. Позволяет extending («добавить параграф к Constraints») без копирования всей base-секции. Whitespace вокруг `{{super}}` сохраняется. Если `{{super}}` встречается в секции, отсутствующей в base — error (M11.5)

**Frontmatter merge — list-поля:**
- Scalar-поля (`description`, `model`, `name`): override-значение **полностью заменяет** base
- List-поля (`tools`, `disallowedTools`, `skills`): override-список **полностью заменяет** base (по образцу Helm для arrays — предсказуемо, без скрытого union)
- Если нужен «base + добавить ещё» для list — пользователь явно перечисляет всё в override

**Resolved file marker:**
Resolver добавляет в начало resolved файла комментарий-маркер:
```markdown
<!-- GENERATED by scripts/_resolve_agents.py — do not edit.
     Source: base + docs/overlays/profiles/<profile>/agent-overrides/<role>.md
     Regenerate: bash scripts/apply-overlay.sh --profile <profile> -->
```
Предотвращает случайное ручное редактирование (которое будет затёрто следующим init/apply-overlay).

**Optional `description` в override frontmatter:**
Override может содержать `description: "..."` — кратко что меняет и зачем. Опционально, не валидируется на содержание; используется для аудита через `git log`.

**Example:**

`base: tech-writer-agent.md`:
```markdown
---
name: tech-writer
description: Технический писатель
---

## Роль
Generic tech writer.

## Constraints
- Markdown only.

## Tools
All.
```

`override: kb-product/agent-overrides/tech-writer.md`:
```markdown
---
extends: tech-writer
description: Технический писатель — customer-facing docs
---

## Роль
Customer-facing docs writer. Фокус: getting-started, guides, reference.

## Domain
- Customer journey ≠ internal flow
- Screenshot conventions: один экран — одна задача
- Version pinning: каждая статья указывает версию продукта
```

`resolved`:
```markdown
---
name: tech-writer
description: Технический писатель — customer-facing docs
---

## Роль
Customer-facing docs writer. Фокус: getting-started, guides, reference.

## Constraints
- Markdown only.

## Tools
All.

## Domain
- Customer journey ≠ internal flow
- Screenshot conventions: один экран — одна задача
- Version pinning: каждая статья указывает версию продукта
```

`name` наследуется (override не указал), `description` заменён, секция `## Роль` заменена, `## Constraints` и `## Tools` унаследованы, `## Domain` добавлена.

#### Why Python (vs bash)
- Markdown секции легко парсить regex'ом в Python (`re.split(r'^## ', flags=re.M)`)
- Frontmatter merge через `yaml.safe_load` + dict.update
- Тестируется как module: `from _resolve_agents import merge_delta`

### 4.2. `_apply_profile.py` (EDIT — P0 + P3)

**P0 fixes:**
- `load_manifest` — `raise ManifestError(...)` вместо `sys.exit(1)` (unit-testable)
- `compute_verdict` — strip `\n` из `reason` перед TSV emit (`\x1f` field separator safety)
- Убрать unused `profile_dir` параметр

**P3 integration:**
- В JSON ops plan добавить step `{"op": "resolve_agents", "source": "agent-overrides/", "target": ".claude/plugins/project/agents/"}` (если manifest содержит `agent_overrides`)
- `apply-overlay.sh` распознаёт этот step → вызывает `_resolve_agents.py`

### 4.3. `apply-overlay.sh` (EDIT — P0 + P3)

**P0 fixes:**
- Убрать дублирующий `python3 -c '...len(plan["ops"])...'` (compute ops_count в `_apply_profile.py` и emit как top-level field в JSON)
- Quote `$init_flag` через array `init_args=()` (shellcheck SC2086 + correctness)

**P3 integration:**
```bash
case "$OP" in
    add)            do_add "$SRC" "$DST" ;;
    replace)        do_replace "$SRC" "$DST" ;;
    delete)         do_delete "$DST" "$VERDICT" ;;
    resolve_agents) do_resolve_agents "$SRC" "$DST" ;;  # NEW
esac

do_resolve_agents() {
    local src_overrides_dir="$1"
    local target_agents_dir="$2"
    python3 scripts/_resolve_agents.py \
        "$PROFILE_DIR" \
        --base-dir ".claude/plugins/project/agents/" \
        --target-dir "$target_agents_dir"
}
```

NB: `do_resolve_agents` запускается **после** `do_add` (чтобы `.claude/plugins/project/agents/` уже существовал).

### 4.4. `validate-profile.py` (EDIT — P3)

#### M11: override sanity

Для каждого профиля с `agent_overrides:` в manifest:

```python
def check_overrides(profile_dir, manifest):
    issues = []
    overrides = manifest.get("agent_overrides", {})
    base_dir = repo_root / ".claude/plugins/project/agents"

    for role, override_spec in overrides.items():
        # M11.1: base exists
        base_path = base_dir / f"{role}-agent.md"
        if not base_path.exists():
            issues.append(Issue("error", manifest_path,
                f"M11: agent_overrides.{role} declared, but base {base_path} missing"))
            continue

        # M11.2: source path exists
        source_path = profile_dir / override_spec["source"]
        if not source_path.exists():
            issues.append(Issue("error", manifest_path,
                f"M11: agent_overrides.{role}.source not found: {source_path}"))
            continue

        # M11.3: frontmatter валидный + extends matches role
        fm = parse_frontmatter(source_path)
        if fm.get("extends") != role:
            issues.append(Issue("error", source_path,
                f"M11: extends '{fm.get('extends')}' must match role '{role}'"))

        # M11.4: role declared in subagents и не disabled
        if manifest["subagents"].get(role) == "disabled":
            issues.append(Issue("error", manifest_path,
                f"M11: agent_overrides.{role} declared, but subagents.{role}=disabled. "
                f"Either remove override or set subagents.{role} to core/optional."))

        # M11.5: {{super}} placeholder в секции, отсутствующей в base
        for section_name in extract_super_sections(source_path):
            if not section_exists_in_base(base_path, section_name):
                issues.append(Issue("error", source_path,
                    f"M11: section '## {section_name}' uses {{{{super}}}} but base has no such section. "
                    f"Either remove {{{{super}}}} or rename heading to match base."))

    return issues
```

**Human-readable error messages (M11)** — все error-строки следуют шаблону «что не так + где + как починить»:

| Проблема | Сообщение |
|----------|-----------|
| Base agent file отсутствует | `M11: agent_overrides.{role} declared, but base file not found at {path}. Check role name in extends, or create base prompt.` |
| Source path override не существует | `M11: agent_overrides.{role}.source not found: {path}. Did you forget to commit the override file?` |
| `extends:` mismatch | `M11: override at {path} declares 'extends: {X}', but role is '{Y}'. Set extends to '{Y}' or move file under agent-overrides/{X}.md.` |
| Role disabled | `M11: agent_overrides.{role} declared, but subagents.{role}=disabled. Either remove override or set subagents.{role} to core/optional.` |
| `{{super}}` без base section | `M11: section '## {name}' uses {{super}} but base has no such section. Either remove {{super}} or rename heading to match base.` |

### 4.5. `docs/overlays/profiles/kb-product/manifest.yaml` (EDIT — P4)

```yaml
schema_version: 1   # без bump в W4a; agent_overrides — additive поле
name: kb-product
description: Документация продукта/процесса для внешних читателей
audience: Customer success, технические писатели, продуктовые менеджеры
status: stable

subagents:
  pm: core
  tech-writer: core
  researcher: optional
  ba: optional
  compliance: optional
  sa: disabled
  dev: disabled
  devops: disabled
  qa: disabled
  devsecops: disabled

pipelines: {}

content_scaffold: content-scaffold/
doc_root: doc-root.yaml

operations:
  - op: delete
    target: content/00-project/
    reason: "kb-product не использует delivery-структуру"
  - op: delete
    target: content/30-requirements/
    reason: "customer docs не имеют функциональных требований"
  - op: delete
    target: content/40-architecture/
    reason: "архитектура продукта не публикуется наружу"
  - op: delete
    target: content/60-implementation/
    reason: "нет реализации"
  - op: delete
    target: content/70-operations/
    reason: "operations не для внешнего читателя"
  - op: add
    source: content-scaffold/
    target: content/
    reason: "kb-product scaffold (getting-started, guides, reference, troubleshooting)"
  - op: replace
    source: doc-root.yaml
    target: content/.doc-root.yaml
    reason: "kb-product properties (Тип контента, Версия продукта, Аудитория)"

agent_overrides:
  tech-writer:
    source: agent-overrides/tech-writer.md
    role_status: core   # уже core в subagents — для consistency

init_prompts: []

compatible_stacks: []
maintainer: project_template
```

### 4.6. `docs/overlays/profiles/kb-product/content-scaffold/` (NEW — P4)

Минимальный scaffold с `_index.md` в каждой папке (по правилам Gramax из CLAUDE.md):

```
content-scaffold/
├── _index.md                   # Корневой index с дашбордом
├── getting-started/
│   ├── _index.md
│   └── README.md (placeholder для первой статьи)
├── guides/_index.md
├── reference/_index.md
└── troubleshooting/_index.md
```

`_index.md` — без `properties:` блока (правило Gramax).

### 4.7. `docs/overlays/profiles/kb-product/doc-root.yaml` (NEW — P4)

```yaml
title: "{{PROJECT_NAME}} — Документация"
properties:
  - name: Тип контента
    type: enum
    values: [Getting Started, Guide, Reference, Troubleshooting, Release Notes]
    required: true
  - name: Версия продукта
    type: string
    placeholder: "v1.2.3"
    required: true
  - name: Аудитория
    type: enum
    values: [Конечный пользователь, Администратор, Разработчик-интегратор]
    required: false
```

### 4.8. `docs/overlays/profiles/kb-product/agent-overrides/tech-writer.md` (NEW — P4)

```markdown
---
extends: tech-writer
description: Технический писатель — документация продукта для внешних читателей
---

## Роль

Customer-facing tech writer. Пишешь документацию **для конечных пользователей и администраторов продукта**, не для команды разработки.

Ключевая разница с internal docs:
- Не используешь жаргон команды (sprints, tickets, PRs)
- Версионируешь каждую статью под версию продукта
- Каждый guide начинается с «Что вы получите в итоге»

## Domain

- **Customer journey ≠ internal flow.** Структура от задачи пользователя, не от структуры кода.
- **Screenshot conventions:** один скриншот = одна задача; обводка важной кнопки красным; pixel-perfect версия UI.
- **Version pinning:** каждая статья указывает «применимо к версии vX.Y.Z+».
- **Reference material:** API spec / CLI reference генерится автоматически — не пиши руками.
- **Tone:** дружелюбный, но не фамильярный; "вы" а не "ты".
```

NB: остальные секции (Constraints, Tools, etc.) наследуются из base.

### 4.9. `docs/overlays/profiles/kb-team/agent-overrides/tech-writer.md` (NEW — P3-T434, demo override)

Минимальный override для kb-team как proof-of-concept (используется тестами M11 и demonstrates механика на stable профиле). Аналогично kb-product, но с фокусом на internal team docs:

```markdown
---
extends: tech-writer
description: Технический писатель — внутренняя командная KB
---

## Роль

Internal team tech writer. Пишешь runbook'и, onboarding, role descriptions для членов команды.

Принципы:
- Краткость > полнота. Команда читает в спешке (инцидент, новый коллега в первый день)
- Один runbook = одна задача (не группируй несколько процедур в один документ)
- Заголовок отвечает на вопрос «что я ищу?»
```

### 4.10. `examples/kb-product-example/` (NEW — P4-T442)

Post-init snapshot по образцу W3 G3 (`project-example`, `kb-team-example`):
- README.md — «Это пример проекта на профиле kb-product. Создан запуском `bash scripts/init.sh --profile kb-product ...`»
- content/{getting-started,guides,reference,troubleshooting}/ — full scaffold с заполненными `_index.md`
- .doc-root.yaml, CLAUDE.md, AGENTS.md, README.md (project-уровень)
- .claude/plugins/project/agents/tech-writer-agent.md — **resolved version** (с применённым override) — это ключевое отличие от других examples, демонстрирует override mechanic в действии

### 4.11. `content/00-project/adr/ADR-XXX-agent-overrides.md` (NEW — SA-420)

ADR фиксирует:
- **Контекст:** профили требуют per-context customization базовых ролей
- **Решение:** base + delta merge через `extends: <role-name>` frontmatter + полное замещение секций по `## Heading`
- **Альтернативы:** (a) full replace (теряем общую часть), (b) string-level merge (overkill, конфликты), (c) inheritance с super calls (Python-style — слишком сложно для markdown)
- **Последствия:** новый файл `_resolve_agents.py`, validator M11, schema_version=1 остаётся (additive поле `agent_overrides`)

### 4.12. `docs/architecture-overview.md` (EDIT — P6)

Добавить новый раздел после «Каталог ролей»:

> ### Agent overrides
>
> Профили могут переопределять промты базовых ролей через `agent_overrides:` в `manifest.yaml` и delta-файлы в `agent-overrides/<role>.md`. Resolution: `_resolve_agents.py` мерджит base + delta (frontmatter merge, секции `## Heading` замещаются полностью), эмиттит resolved prompts в `.claude/plugins/project/agents/` working tree.
>
> Mermaid:
> ```mermaid
> graph LR
>   A[base/tech-writer-agent.md] --> M[merge_delta]
>   B[profiles/kb-product/<br>agent-overrides/tech-writer.md] --> M
>   M --> R[resolved/tech-writer-agent.md]
> ```

### 4.13. `docs/troubleshooting.md` (EDIT — P6)

Append:

| Симптом | Причина | Fix |
|---------|---------|-----|
| `validate-profile.py` M11 error: «extends 'X' must match role 'Y'» | Frontmatter override содержит неверный `extends:` | Исправить `extends:` на имя роли как в `subagents` |
| `_resolve_agents.py`: «base prompt not found for role: X» | `subagents.X != disabled`, но base `.claude/plugins/project/agents/X-agent.md` отсутствует | Создать base prompt или поставить `subagents.X: disabled` |
| После init промт агента не содержит override-секций | Override применился, но IDE кэширует старую версию | Restart Claude Code session |

## 5. Data flow

### 5.1. Override resolution end-to-end

```
User
  │ bash scripts/init.sh --profile kb-product "MyProduct" "MP" "..." "u@x.com"
  ▼
init.sh
  ├── parse args (PROFILE=kb-product)
  ├── replace_in_file CLAUDE.md/AGENTS.md/README.md/content (placeholders)
  ├── bash scripts/apply-overlay.sh --profile --init kb-product
  │     ├── PLAN=$(python3 scripts/_apply_profile.py docs/overlays/profiles/kb-product --init)
  │     │     │
  │     │     ▼
  │     │   _apply_profile.py
  │     │     ├── parse manifest.yaml
  │     │     ├── apply on_value мутации (если есть init_prompts)
  │     │     ├── compute safety verdicts для each op
  │     │     ├── if manifest has agent_overrides:
  │     │     │     append step {"op": "resolve_agents", "source": "agent-overrides/", "target": ".claude/plugins/project/agents/"}
  │     │     └── emit JSON plan на stdout
  │     ├── for each op:
  │     │     - delete content/00-project/, content/30-requirements/, ...
  │     │     - add content-scaffold/ → content/
  │     │     - replace doc-root.yaml → content/.doc-root.yaml
  │     │     - resolve_agents:                    ← NEW в W4a
  │     │       └── python3 scripts/_resolve_agents.py docs/overlays/profiles/kb-product \
  │     │             --base-dir .claude/plugins/project/agents/ \
  │     │             --target-dir .claude/plugins/project/agents/
  │     │           ├── читает manifest.subagents → активные роли
  │     │           ├── для каждой active роли:
  │     │           │     если есть в agent_overrides → merge_delta(base, override)
  │     │           │     иначе → copy base as-is
  │     │           └── пишет resolved → target-dir
  │     └── validate-content.py + validate-profile.py (включая M11)
  ├── (опц.) stack-overlay'и
  ├── wipe .git, init, initial commit
  └── (опц.) setup origin
```

После init: working tree содержит resolved tech-writer prompt (с customer-facing-секцией), Claude Code подхватывает его при следующем запуске.

## 6. Error handling

### 6.1. `_resolve_agents.py`

| Ошибка | Поведение |
|--------|-----------|
| Manifest YAML malformed | exit 1 + сообщение (наследует из shared parser) |
| Override frontmatter без `extends:` | exit 1 + «override <path>: missing required 'extends' field» |
| Override `extends: X` не совпадает с role в manifest | exit 1 + «override <path>: extends '<X>' but role is '<Y>'» |
| Base prompt отсутствует для активной роли | exit 1 + «base prompt not found: <path>; either create base or set subagents.<role>: disabled» |
| Target dir не существует | exit 1 + «target dir does not exist: <path>» (apply-overlay должен был создать через do_add) |

### 6.2. `apply-overlay.sh` (P3 integration)

| Ошибка | Поведение |
|--------|-----------|
| `_resolve_agents.py` exit non-zero | bash exit с тем же code; abort init |
| Resolve_agents step без agent_overrides в manifest | step не emit'ится `_apply_profile.py`'м (no-op) |

### 6.3. `validate-profile.py` M11

Все M11 ошибки — error severity (не warning). Override system должен быть консистентен или отсутствовать.

## 7. Тесты

### 7.1. Unit-уровень — `_resolve_agents.py`

Inline doctests или `scripts/test-_resolve-agents.sh`:

- `merge_delta(base, override)` корректно мерджит frontmatter (базовые поля + override-replacements)
- `merge_delta`: секция `## X` в override заменяет одноимённую в base
- `merge_delta`: секция в base без override наследуется
- `merge_delta`: секция в override без base добавляется в конец
- `merge_delta`: пустой override (только frontmatter) → body наследуется полностью
- `extends:` mismatch → raise

### 7.2. Validator-уровень — `validate-profile.py`

Расширить `test-validate-profile.sh`:

- M11.1: profile с `agent_overrides.foo` где base `foo-agent.md` отсутствует → error
- M11.2: profile с `agent_overrides.tech-writer.source: missing.md` → error
- M11.3: override с `extends: ba` для роли `tech-writer` → error
- M11.4: profile с `subagents.foo: disabled` + `agent_overrides.foo` → error
- M11 happy path: kb-product / kb-team с правильным override → no errors

### 7.3. Integration — `test-template.sh`

Существующие 79 ассерта остаются зелёными (regression-only для P0).

**Новые ассерты:**

- T-W4a-P3-demo: после init kb-team, файл `.claude/plugins/project/agents/tech-writer-agent.md` содержит секцию из demo override («Internal team tech writer»)
- T-W4a-P4-init: `bash scripts/init.sh --profile kb-product "TestProduct" "TP" "desc" "test@x.com"` exit 0
- T-W4a-P4-scaffold: после init kb-product, существуют `content/{getting-started,guides,reference,troubleshooting}/_index.md`
- T-W4a-P4-override: после init kb-product, `.claude/plugins/project/agents/tech-writer-agent.md` содержит «Customer-facing tech writer»
- T-W4a-P4-noise: `content/00-project/`, `content/30-requirements/`, etc. отсутствуют (op:delete сработали)

### 7.4. Backwards compatibility

- Старые профили без `agent_overrides:` в manifest → no-op (resolve_agents step не emit'ится)
- `init.sh --profile project` / `--profile kb-team` (без demo override до P3) → existing behavior
- `apply-overlay.sh naumen-smp` (markers, без `--profile`) → existing behavior
- validate-profile.py зелёный на всех 7 профилях

## 8. Phase plan + параллельность

### Phase 0: W3-minors (~3 задачи, 2 субагента parallel + 1 sequential)

- T1 (parallel A): DEV-401 — `_apply_profile.py` `load_manifest` exception вместо sys.exit + tests
- T2 (parallel B): DEV-402 — `apply-overlay.sh` ops_count optimization + quote init_flag
- T3 (sequential after T1): DEV-403 — `_apply_profile.py` strip newlines guard + remove unused profile_dir param

### Phase 1: Research + BA (~3 задачи)

- T4 (sequential): RES-410 — `/research как реализуется per-profile prompt customization в Claude Code plugins / Cursor / Cline`
- T5 (sequential after T4): BA-411 — `/ba new-requirement override-mechanic` (BRQ + AC: формат frontmatter, что override'ится, edge cases)
- T6 (parallel after T4): BA-412 — `/ba new-requirement kb-product-profile` (короткий BRQ: какие папки, какие core/optional роли)

### Phase 2: SA (~3 задачи, mostly sequential)

- T7 (sequential after T5): SA-420 — `/sa adr agent-overrides` (base + delta merge формализация)
- T8 (sequential after T7): SA-421 — `/sa design _resolve_agents.py spec` (CLI, JSON contract, merge algorithm)
- T9 (parallel after T6+T8): SA-422 — `/sa design kb-product-profile` (manifest enrichment + scaffold tree + override list)

### Phase 3: DEV core overrides (~5 задач, sequential)

- T10: DEV-430 — `scripts/_resolve_agents.py` skeleton + base + delta merge logic
- T11: DEV-431 — `_apply_profile.py` emit resolved-agents step + tests
- T12: DEV-432 — `apply-overlay.sh` integration: do_resolve_agents + tests
- T13: DEV-433 — `validate-profile.py` M11 checks + test-validate-profile.sh ассерты
- T14: DEV-434 — demo override tech-writer для kb-team + integration ассерт T-W4a-P3-demo

### Phase 4: DEV kb-product pilot (~3 задачи, sequential)

- T15: DEV-440 — `kb-product/manifest.yaml` enrichment + `doc-root.yaml` + `content-scaffold/`
- T16: DEV-441 — `kb-product/agent-overrides/tech-writer.md`
- T17: DEV-442 — `examples/kb-product-example/` + ассерты T-W4a-P4-*

### Phase 6: docs + lessons + smoke (~4 задачи, parallel × 2 + sequential)

- T18 (parallel A): DEV-460 — `docs/architecture-overview.md` раздел overrides + mermaid
- T19 (parallel B): DEV-461 — `docs/troubleshooting.md` append override edge-cases
- T20 (sequential after T18+T19): DEV-462 — `docs/lessons-learned.md` Wave 4a запись
- T21 (sequential after T20): DEV-463 — `bash scripts/check.sh --full` + final code review + auto-memory updates

**Total: 21 атомарная задача, 6 фаз (Phase 5 пропущен — init UX в W4b). ✓ medium budget.**

### Параллельность граф

```
Phase 0:  T1 || T2 ──→ T3
            │
            ▼
Phase 1:  T4 ──→ T5 || T6
                   │
                   ▼
Phase 2:        T7 ──→ T8 ──→ (T9 после T6 и T8)
                                │
                                ▼
Phase 3:                    T10 → T11 → T12 → T13 → T14
                                                       │
                                                       ▼
Phase 4:                                          T15 → T16 → T17
                                                              │
                                                              ▼
Phase 6:                                              T18 || T19 ──→ T20 ──→ T21
```

## 9. Anti-scope

Что W4a **НЕ** делает (отнесено в W4b или отложено дальше):

**W4b:**
- ❌ 4 оставшихся stub-профиля (`product`, `methodology`, `course`, `custom`) → stable
- ❌ Init UX customization: интерактивные prompts для override toggles (через `init_prompts` с `agent_overrides.X` mutations)
- ❌ Меню профилей с описаниями в `init.sh` (сейчас CLI flag --profile)

**Wave 5+:**
- ❌ Group D (scrum-agile pipeline impl)
- ❌ Group E (migration tooling: `migrate-profile.sh`, `upgrade-template.sh`)
- ❌ Auto-update derived AGENTS.md матрицы из manifest'ов
- ❌ Generation script для examples/

**Архитектурные ограничения W4a:**
- ❌ schema_version bump (остаётся 1; `agent_overrides` — additive поле)
- ❌ Изменение Wave 1-3 контрактов (validate-content C1-C7, manifest schema, on_value mechanic, JSON ops plan format)
- ❌ Inheritance с super calls (Python-style merge) — выбран простой full-section replace
- ❌ Multiple inheritance (`extends: [a, b]`) — overkill, не нужно сейчас
- ❌ Override без base (override как стандалонный prompt) — нет use case; если нужна новая роль — добавляется в base

## 10. GO-критерии Wave 4a

W4a закрыт, когда:

- [ ] **P0:** `_apply_profile.py.load_manifest` raise вместо sys.exit; `apply-overlay.sh` ops_count оптимизирован, init_flag quoted; multiline reason guard; profile_dir param removed
- [ ] **RES-410** артефакт: `docs/research/2026-05-XX-override-mechanics.md`
- [ ] **BA-411** артефакт: `content/30-requirements/functional/req-override-mechanic.md` + AC
- [ ] **BA-412** артефакт: `content/30-requirements/profile-kb-product.md` (короткий)
- [ ] **SA-420 ADR** в `content/00-project/adr/` фиксирует base + delta merge выбор
- [ ] **SA-421 spec** в `content/40-architecture/` для `_resolve_agents.py`
- [ ] **SA-422 spec** в `content/40-architecture/` для kb-product profile
- [ ] **P3 (overrides core):**
  - [ ] `scripts/_resolve_agents.py` существует, делает base + delta merge корректно
  - [ ] `_apply_profile.py` emit'ит resolve_agents step при наличии `agent_overrides:` в manifest
  - [ ] `apply-overlay.sh` обрабатывает resolve_agents step
  - [ ] `validate-profile.py` M11 (4 sub-checks) работает
  - [ ] Demo override tech-writer для kb-team applied end-to-end (integration test зелёный)
- [ ] **P4 (kb-product pilot):**
  - [ ] `kb-product/manifest.yaml` enriched (operations, agent_overrides, status: stable)
  - [ ] `kb-product/doc-root.yaml` + `content-scaffold/` (4 раздела с `_index.md`)
  - [ ] `kb-product/agent-overrides/tech-writer.md` (delta для customer docs)
  - [ ] `examples/kb-product-example/` создан с resolved tech-writer prompt
  - [ ] T-W4a-P4-* integration ассерты зелёные
- [ ] **P6 (docs):**
  - [ ] `docs/architecture-overview.md` — раздел overrides + mermaid
  - [ ] `docs/troubleshooting.md` — override edge-cases appended
  - [ ] `docs/lessons-learned.md` — Wave 4a запись
- [ ] **Backwards compatibility:** старые профили без `agent_overrides` работают; init.sh для project/kb-team не ломается
- [ ] **Финальный smoke:** `bash scripts/check.sh --full` exit 0
- [ ] **Auto-memory:** обновлены ключевые feedback / project / reference записи
- [ ] **Code review:** финальный `superpowers:requesting-code-review` пройден

## 11. Открытые вопросы (для writing-plans / SDD)

1. **Frontmatter merge — какие поля наследуются автоматически, какие requires explicit override?** *Предлагаю: base поля наследуются, override поля заменяют; никаких "required в override" кроме `extends:`. SA-420 ADR финализирует.*
2. **Resolved prompts location — куда писать?** Working tree `.claude/plugins/project/agents/` (overwrites base в working copy). NB: base prompts в `.claude/plugins/project/agents/` — это сам шаблон; после `init.sh wipe .git` мы remountuем working tree как новый проект, поэтому overwrites — это «настройка проекта», не загрязнение шаблона. *Подтвердить в SA-421.*
3. **`_resolve_agents.py` standalone vs встроен в `_apply_profile.py`?** *Предлагаю standalone — separation of concerns; `_apply_profile.py` дёргает как subprocess (в стиле W3 helper invocation pattern).*
4. **Demo override для kb-team — обязательная часть P3?** Вопрос: оставить demo как «proof of concept на stable профиле» или удалить после успешных тестов W4a? *Предлагаю оставить — kb-team получает реальный value (internal team docs writer), не просто test fixture.*

## 12. Self-Review

### 12.1. Placeholder scan
✓ Нет TBD/TODO; все секции наполнены.
✓ ADR номер «ADR-XXX» — placeholder, финализируется в SA-420 (по последовательности существующих ADR в `content/00-project/adr/`).

### 12.2. Internal consistency
✓ §3.2 (file structure) согласуется с §4 (компоненты).
✓ §8 (phase plan) согласуется с §10 (GO-критерии).
✓ §9 (anti-scope) явно разделяет W4a / W4b / Wave 5+.

### 12.3. Scope check
✓ 21 задача в medium-budget (20-25). Маржа 2-4 задачи.
✓ Один пилотный профиль (kb-product) — единственный stable target в W4a (5 stub'ов после W4a будут 4: product, methodology, course, custom).
✓ Demo override для kb-team — добавляет real value (не fixture), включён в P3 как proof.

### 12.4. Ambiguity check
- ✓ «Base + delta merge» определён точно (§4.1: frontmatter merge, секции `## H` replace, секции в override без base — append).
- ✓ «extends:» — обязательное поле override frontmatter, mismatch — error.
- ✓ Resolved prompts target — working tree `.claude/plugins/project/agents/` (overwrites base в working copy после init).

---

## 13. Метаданные

- **Зависимости от Wave 3:** все контракты стабильны.
- **Зависимости от superpowers:** `writing-plans`, `subagent-driven-development`, `test-driven-development`, `requesting-code-review`, `using-git-worktrees`, `dispatching-parallel-agents`.
- **Эффект на пользователя:** новые проекты на профиле kb-product получают customer-facing tech-writer; старые (project, kb-team) не ломаются (kb-team получает enhanced tech-writer); validator M11 ловит broken overrides до commit.
- **Эффект на CI:** `test-validate-profile.sh` +5 ассертов; `test-template.sh` +5 ассертов; `check.sh --full` остаётся ~30 сек.
- **Subagent model:** Opus для implementer'ов и reviewer'ов (per memory `feedback_subagent_opus_authorized.md`).

### W4b preview (для контекста)

После W4a следует W4b:
- Phase 4': 4 параллельных профиля → stable (product, methodology, course, custom) — каждый по образцу kb-product (manifest + scaffold + 1-2 overrides + example), 4 параллельных subagent'а
- Phase 5': init UX (interactive override toggles, profile menu с описаниями)
- Phase 6': финальный smoke + lessons + memory

W4b будет ~20-25 задач при условии что W4a стабилен (overrides core работает).

---

**Next steps after этого spec'а:**

1. Owner ревьюит spec → approve / request changes.
2. После approve — `superpowers:writing-plans` создаёт granular plan в `docs/superpowers/plans/2026-05-07-wave-4a.md`.
3. После plan approve — `superpowers:subagent-driven-development` (Opus implementer'ы) реализует.
4. После каждой Phase — `superpowers:requesting-code-review` на изменённый scope.
5. Финальный full-branch review перед merge `private` → `public`.

---

## 14. Refinements after RES-410 (override mechanics research)

Research-артефакт `docs/research/2026-05-07-override-mechanics.md` (7 систем + 3 inheritance pattern из соседних областей) подтвердил направление «base + delta merge с full-section replace» как partially best practice. Внесённые уточнения:

### 14.1. `{{super}}` placeholder (NEW — добавлено в §4.1)

**Источник:** Jinja2 `{{ super() }}` — самый зрелый аналог нашему дизайну.
**Проблема:** Без него override, который хочет добавить пункт в `## Constraints`, обязан скопировать всю base-секцию. Это создаёт drift при изменении base и раздувает override-файлы.
**Решение:** В секции override `{{super}}` подставляется содержимым одноимённой секции base.
**Стоимость impl:** ~10 строк в `_resolve_agents.py` (regex split + substitute).
**Тест:** unit-тест в §7.1 «`{{super}}` корректно подставляет base-секцию», edge-case «`{{super}}` в секции отсутствующей в base → M11.5 error».

### 14.2. List-поля frontmatter — full replace (clarified в §4.1)

**Источник:** Helm values inheritance pattern.
**Проблема:** Изначальный spec был неоднозначен: «поля override'а заменяют base» — что с list-полями (например `tools: [a, b]`)? Union или replace?
**Решение:** **Full replace** для list-полей. Если нужен «append» — пользователь перечисляет всё в override явно. Прозрачно и предсказуемо.
**Тест:** unit-тест «list-поле override полностью замещает base list», без union.

### 14.3. Section heading match — exact (clarified в §4.1)

**Решение:** Heading match чувствителен к case + whitespace + punctuation. `## Красные линии` ≠ `## Красные  линии` (двойной пробел). Альтернатива (нормализация) добавляет magic, который сложно объяснить.
**Mitigation:** Документировать в `troubleshooting.md` (§4.13 spec) через FAQ entry «секция override не override'ится — проверь heading на whitespace/encoding».

### 14.4. Resolved file marker (NEW — добавлено в §4.1)

**Источник:** OpenHands и Helm генерируют файлы с явным маркером «GENERATED».
**Решение:** Resolver добавляет HTML comment в начало resolved файла с источниками + командой для regenerate.
**Эффект:** Пользователь, открывший resolved файл в IDE, видит что не должен править здесь — править нужно override.
**Стоимость impl:** ~3 строки в `_resolve_agents.py`.

### 14.5. Optional `description` в override frontmatter (NEW — добавлено в §4.1)

**Решение:** Override может содержать `description: "..."` — кратко что меняет и зачем.
**Эффект:** При git log изменений override легче понять intent без раскрытия diff.
**Стоимость impl:** ноль (просто документировано).

### 14.6. Human-readable M11 error messages (clarified в §4.4)

**Источник:** Cline urok — fail-open и неинформативные сообщения создают невидимые ошибки в проде.
**Решение:** Каждое M11 error следует шаблону «что не так + где + как починить» (table в §4.4).
**Эффект:** Пользователь, увидевший M11 error при `check.sh --fast`, чинит за 30 секунд, не за 30 минут гадания.

### 14.7. Что **не** добавили (явно отвергнуто)

| Идея из research | Почему не добавили |
|------------------|--------------------|
| Section reordering (`before:` / `after:`) — Kustomize JSON6902-style | Overkill для текущих use cases; добавит сложность resolver и validator |
| Multiple inheritance (`extends: [a, b]`) | Нет use case в W4a; one-step extends покрывает все профили |
| Heading normalization (case-insensitive strip) | Magic без явного контракта; exact match предсказуемее |
| Circular extends detection | Невозможно без multiple inheritance; single linear extends → no cycle |

### 14.8. Эффект на phase plan и GO-критерии

- **§8 Phase plan:** без изменений (количество задач прежнее, refinements укладываются в DEV-430 + DEV-433)
- **§10 GO-критерии:** добавляется неявно — М11 теперь имеет 5 sub-checks вместо 4 (M11.5 super-без-base); тесты `_resolve_agents.py` имеют пункт `{{super}}` (унит) и list-replace (унит)
- **Бюджет:** ~1-2 строк кода в _resolve_agents.py, ~5 строк в validate-profile.py (M11.5), ~2 ассерта в test-validate-profile.sh — внутри margin задач Phase 3

### 14.9. Метаданные refinements

- **Источник:** RES-410 → `docs/research/2026-05-07-override-mechanics.md`
- **Применено в:** §4.1 (merge semantics + `{{super}}` + list-replace + marker + description), §4.4 (M11.5 + error messages table)
- **Не требует:** дополнительного research, brainstorming, или архитектурного пересмотра. Refinements — clarifications + 2 additive features (`{{super}}`, marker), не break существующий design
