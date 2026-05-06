# Spec: Multi-Template Support — Profile system + extended subagent catalog

**Дата:** 2026-05-06 (Wave 2 inception)
**Автор:** PM (main, Opus, claude-opus-4-7[1m])
**Статус:** Design — input для writing-plans (превратится в plan, далее SDD-реализация)
**Источник вопросов:** [brief Wave 2](2026-05-06-multi-template-support-brief.md), [interview-results](2026-05-06-wave-2-interview-results.md), [research](../../../content/10-domain/research/multi-template-landscape.md)
**Эталон спецификации:** [Wave 1 design](2026-05-06-gramax-template-alignment-design.md)

---

## 1. Проблема

Текущий шаблон `project_template` поддерживает **один тип проекта** (delivery-проект, hard-coded scaffold `00-project / 30-requirements / 40-architecture / 60-implementation / 70-operations`) и **6 ролей** (PM/Researcher/BA/SA/Dev/DevOps). На стороне реальных пользователей возникли расхождения:

1. **Разные шейпы проектов** — delivery-проект, разработка продукта, KB по продукту, internal team-KB, methodology, training-курс — каждый имеет свою структуру каталога и свой набор ролей.
2. **Недостаточный каталог ролей** — Tester/QA, AT (Automation Test author), Tech Writer, DevSecOps, Secure Compliance не покрыты текущей шестёркой; команда работает с пробелами.
3. **Отсутствие pipeline-механики** — каждая фича декомпозируется руками PM'а; нет канонических pipeline'ов для типовых жизненных циклов (planning, BA-acceptance, critical-path).
4. **Хрупкая стэкабельность overlay'ев** — текущий `apply-overlay.sh` append-only, не умеет add/replace/delete, не различает «профиль» (foundation) и «stack» (доменный плагин).

Каждый новый проект, инициализированный через `/init`, наследует жёсткую структуру `project` и тратит время на ручную адаптацию.

## 2. Цель

Превратить шаблон в **profile-driven систему** с расширенным каталогом ролей и pipeline-механикой:

- **7 профилей** (project, product, kb-product, kb-team, custom, methodology, course) с декларативными manifest'ами; **2 baseline профиля** (project, kb-team) реализованы полностью; остальные — stub-манифесты в задел Wave 3+.
- **10 ролей** в каталоге (6 улучшенных + 5 новых, где AT и Tester объединены в `qa-agent` с двумя физическими реализациями).
- **3 pipeline'а** (project-planning, BA-acceptance, critical-path) как orchestrator-агенты с per-pipeline worktree.
- **Расширенный `apply-overlay.sh`** с операциями add/replace/delete и safety-mechanics (strict delete-non-empty, --force, --dry-run).
- **Profile + stack composability** (profile = exclusive foundation; stacks = stackable, через compatible_stacks).
- **Validators** (validate-profile.py + shared module) для манифестов профилей.

Wave 2 acceptance — в §15 (GO-criteria).

## 3. Архитектура

### 3.1. Высокоуровневая декомпозиция

```
┌─ /init (interactive)
│   ├─ Phase 1 (bash):
│   │   ├─ Спрашивает project_name, project_code, description, editor_email
│   │   ├─ Спрашивает PROFILE (one of 7)
│   │   ├─ Подставляет плейсхолдеры
│   │   ├─ apply-overlay.sh --profile <name>      ◄── NEW (ops add/replace/delete)
│   │   ├─ Спрашивает init_prompts из manifest (например compliance_domain)
│   │   ├─ Применяет on_value мутации к manifest (опц.)
│   │   ├─ Спрашивает «применить stack-overlay'и?»
│   │   ├─ apply-overlay.sh <stack> (текущий marker-based, для каждого выбранного)
│   │   ├─ wipe .git, init, initial commit
│   │   └─ Опц. setup origin
│   └─ Phase 2 (slash /init):
│       └─ Интервью по 6 темам + TODO-маркеры (как в Wave 1)
│
├─ /pm decompose <epic>
│   ├─ Читает brief фичи
│   ├─ Декомпозирует на задачи (Researcher → BA → SA → QA-author → Dev → QA-runner → BA-acceptance)
│   ├─ Soft-suggest opt-in subagents при ключевых словах (DevSecOps, Compliance)
│   └─ Создаёт plan-<epic>.md в content/00-project/plans/
│
├─ /pipelines/project-planning <epic>     ◄── NEW
│   ├─ Создаёт .worktrees/epic-<slug> через using-git-worktrees
│   ├─ Последовательно вызывает: Researcher → BA → SA → QA-author → Dev → QA-runner
│   └─ Передаёт результат в /pipelines/ba-acceptance
│
├─ /pipelines/ba-acceptance <req>          ◄── NEW
│   ├─ BA в режиме --mode=acceptance
│   ├─ Сверяет AC ↔ реализация
│   └─ Gate: pass → merge OK; fail → возврат к Dev
│
├─ /pipelines/critical-path <epic>         ◄── NEW
│   ├─ Анализ зависимостей задач из plan-<epic>.md
│   ├─ Mermaid Gantt
│   └─ content/00-project/critical-path/<epic>.md
│
└─ /pm-review (Wave 1, расширен)
    ├─ git status / git diff
    ├─ python3 scripts/validate-content.py
    ├─ python3 scripts/validate-profile.py    ◄── NEW
    ├─ Проверка pipeline-state и worktree
    └─ Lessons synthesis
```

### 3.2. File structure (creating + editing)

```
docs/overlays/
├── profiles/                           # NEW directory
│   ├── project/                        # baseline profile (Wave 2 implementation)
│   │   ├── manifest.yaml               # 12 полей schema
│   │   ├── content-scaffold/           # копируется в content/ при apply
│   │   │   ├── _index.md
│   │   │   ├── 00-project/
│   │   │   │   ├── _index.md
│   │   │   │   ├── adr/_index.md
│   │   │   │   ├── plans/_index.md     # NEW (для project-planning pipeline)
│   │   │   │   ├── critical-path/_index.md  # NEW
│   │   │   │   ├── security/_index.md  # NEW (для DevSecOps)
│   │   │   │   └── compliance/_index.md # NEW (для Secure Compliance)
│   │   │   ├── 10-domain/_index.md
│   │   │   ├── 30-requirements/_index.md
│   │   │   │   (functional/_index.md, non-functional/_index.md — без изменений)
│   │   │   ├── 40-architecture/_index.md
│   │   │   ├── 60-implementation/
│   │   │   │   ├── _index.md
│   │   │   │   └── test-reports/_index.md  # NEW (для QA-runner)
│   │   │   └── 70-operations/_index.md
│   │   ├── doc-root.yaml               # шаблон .doc-root.yaml для project (расширенный — 7 новых Тип контента values)
│   │   └── agent-overrides/            # пустая в Wave 2
│   ├── kb-team/                        # контрастный baseline (Wave 2 implementation)
│   │   ├── manifest.yaml
│   │   ├── content-scaffold/           # 10-domain, 20-onboarding, 30-runbooks, 40-roles, 50-incidents
│   │   │   ├── _index.md
│   │   │   ├── 10-domain/_index.md
│   │   │   ├── 20-onboarding/_index.md
│   │   │   ├── 30-runbooks/_index.md
│   │   │   ├── 40-roles/_index.md
│   │   │   └── 50-incidents/_index.md
│   │   ├── doc-root.yaml               # kb-team properties: Тип контента (Onboarding/Runbook/Role/Incident), Owner, Эскалация, Статус
│   │   └── agent-overrides/            # пустая
│   ├── product/                        # stub
│   │   └── manifest.yaml               # status: stub
│   ├── kb-product/manifest.yaml        # stub
│   ├── custom/manifest.yaml            # stub
│   ├── methodology/manifest.yaml       # stub
│   └── course/manifest.yaml            # stub
└── naumen-smp/                         # существующий, не трогаем

agents/
├── pm-agent.md          # EDIT: pipelines, decompose с suggest, координация 10 ролей
├── researcher-agent.md  # EDIT: разделение труда с BA/SA, не пишет требования/архитектуру
├── ba-agent.md          # EDIT: + --mode=acceptance подрежим (BA-acceptance pipeline)
├── sa-agent.md          # EDIT: контракт с QA-author (передача AC), не пишет тесты
├── dev-agent.md         # EDIT: TDD по qa-author stubs (не самописные)
├── devops-agent.md      # EDIT: координация с DevSecOps (DevOps деплой/мониторинг; DevSecOps secrets/SAST)
├── qa-author-agent.md   # NEW: AC → at-design.md + failing test stubs
├── qa-runner-agent.md   # NEW: full suite + регрессии + отчёт
├── tech-writer-agent.md # NEW: secondary editor (base); primary author через override (Wave 3 для kb-product/methodology/course)
├── devsecops-agent.md   # NEW: embedded в Dev-фазу — secrets/SAST/supply-chain/policy
└── compliance-agent.md  # NEW: research-агент general-purpose (правила пользователь передаёт в запросе)

scripts/
├── validate-content.py        # EDIT (минимально): import shared from _validate_common
├── _validate_common.py        # NEW: Issue, parse_frontmatter, parse_manifest, PLACEHOLDER_RE
├── validate-profile.py        # NEW: M1-M10 (manifest checks)
├── apply-overlay.sh           # REFACTOR: ops support, --profile, --force, --dry-run, strict delete
├── init.sh                    # REFACTOR: интерактивный выбор профиля + dynamic init_prompts
├── test-validate-content.sh   # EDIT: подтянуть shared module ассерты
├── test-validate-profile.sh   # NEW
└── test-template.sh           # EDIT: matrix по профилям (project + kb-team)

.claude/plugins/project/commands/
├── init.md              # EDIT: profile-выбор в Phase 1
├── pm.md                # EDIT: pipelines, decompose с soft-suggest
├── pm-review.md         # EDIT: validate-profile + pipeline-state
├── ba.md                # EDIT: --mode=author|acceptance
├── pipelines/                          # NEW directory
│   ├── project-planning.md
│   ├── ba-acceptance.md
│   └── critical-path.md
├── qa.md                # NEW: --mode=author|runner → диспетч qa-author/qa-runner
├── tech-writer.md       # NEW
├── devsecops.md         # NEW
└── compliance.md        # NEW

AGENTS.md          # EDIT: реестр 10 ролей + контракт + матрица «роль × профиль» + pipeline-каталог
CLAUDE.md          # EDIT: блок «Профильная система» + ссылки
README.md          # EDIT: упомянуть /init --profile, validate-profile
docs/extending.md  # NEW: гайд «как добавить роль / pipeline / профиль»
docs/lessons-learned.md  # EDIT: append записи Wave 2
```

## 4. Компоненты

### 4.1. Profile manifest schema

Файл `docs/overlays/profiles/<name>/manifest.yaml`. Полная schema — 12 полей (на baseline-профиле; для stub'а 5 обязательных):

```yaml
schema_version: 1                         # required
name: project                             # required, должно совпадать с именем папки
description: Delivery-проект (Researcher → BA → SA → Dev → DevOps цепочка)  # required
audience: PM, команда разработки          # human-readable
status: stable                            # stable | stub | experimental — required

# Subagent-фильтр (см. §4.4 AGENTS.md registry)
# Имена ролей валидируются против AGENTS.md
subagents:                                # required (хотя бы один core)
  pm: core
  researcher: optional
  ba: core
  sa: core
  dev: core
  devops: optional
  qa: core
  tech-writer: optional
  devsecops: optional
  compliance: optional

# Pipelines (имена валидируются против commands/pipelines/)
pipelines:                                # required
  project-planning: enabled
  ba-acceptance: enabled
  critical-path: optional
  scrum-agile: disabled                   # stub в Wave 2

# Содержимое для копирования
content_scaffold: content-scaffold/       # required, относительно папки профиля
doc_root: doc-root.yaml                   # required, шаблон .doc-root.yaml

# Operations для apply-overlay (см. §4.3)
operations:                               # required (хотя бы add для scaffold)
  - op: add
    source: content-scaffold/
    target: content/
    reason: "Базовый scaffold project-профиля"
  - op: replace
    source: doc-root.yaml
    target: content/.doc-root.yaml
    reason: "Профильная схема properties"

# Интерактивные prompts на /init (опционально)
init_prompts:                             # optional, default []
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

# Совместимость со stack-overlay'ами
compatible_stacks: [naumen-smp]           # required (можно "*" или [])

maintainer: project_template              # optional
```

#### Stub-профиль (минимальный)

```yaml
schema_version: 1
name: methodology
description: Методология / playbook / framework
status: stub
subagents: { pm: core, tech-writer: core }
pipelines: {}
content_scaffold: ./   # пусто на Wave 2
doc_root: ./   # будет добавлен в Wave 3
operations: []
compatible_stacks: []
```

`apply-overlay.sh <stub-name>` печатает warning «Это stub-профиль (status: stub). Scaffold не определён, профиль готов к расширению в Wave 3+».

### 4.2. AGENTS.md registry — расширение

AGENTS.md — авторитет для каталога ролей. Структура (после Wave 2):

```markdown
# AGENTS.md — {{PROJECT_NAME}}

## Каталог ролей

| Имя | Описание | Где исполняется | Модель | Промпт-файл | Slash-команды |
|-----|----------|-----------------|--------|-------------|---------------|
| pm | Координатор/orchestrator | main | Opus | (main, не subagent) | `/pm` |
| researcher | Контекст-сборщик | subagent | Sonnet | agents/researcher-agent.md | `/research` |
| ba | Бизнес-аналитик; режимы: author, acceptance | subagent | Sonnet | agents/ba-agent.md | `/ba`, `/ba --mode=acceptance` |
| sa | Архитектор / системный аналитик | subagent | Sonnet | agents/sa-agent.md | `/sa` |
| dev | TDD-разработчик | subagent | Sonnet | agents/dev-agent.md | `/dev` |
| devops | Эксплуатация (опц.) | subagent | Sonnet | agents/devops-agent.md | `/devops` |
| qa | QA с режимами author/runner | subagent | Sonnet | agents/qa-author-agent.md (AT) + agents/qa-runner-agent.md (Tester) | `/qa --mode=author`, `/qa --mode=runner` |
| tech-writer | Документатор (secondary editor / primary author per profile) | subagent | Sonnet | agents/tech-writer-agent.md | `/tech-writer` |
| devsecops | Embedded security в Dev (opt-in) | subagent | Sonnet | agents/devsecops-agent.md | `/devsecops` |
| compliance | Research compliance (opt-in) | subagent | Sonnet | agents/compliance-agent.md | `/compliance` |

## Контракт вызова субагента (универсальный)

При запуске любой роли передавай:
1. **Цель** одной фразой.
2. **Входные файлы** — пути к контексту.
3. **Ожидаемый артефакт** — какой файл должен появиться/измениться.
4. **Критерии приёмки** — как проверить, что задача выполнена.

(Полные prompt'ы — в `agents/*.md`.)

## Матрица «роль × профиль»

| Роль | project | product | kb-product | kb-team | custom | methodology | course |
|------|---------|---------|-----------|---------|--------|-------------|--------|
| pm | core | core | core | core | core | core | core |
| researcher | optional | optional | optional | optional | optional | optional | optional |
| ba | core | core | optional | disabled | optional | disabled | optional |
| sa | core | core | disabled | disabled | optional | disabled | disabled |
| dev | core | core | disabled | disabled | optional | disabled | disabled |
| devops | optional | optional | disabled | core | optional | disabled | disabled |
| qa | core | core | disabled | disabled | optional | disabled | disabled |
| tech-writer | optional | optional | core | core | optional | core | core |
| devsecops | optional | optional | disabled | disabled | optional | disabled | disabled |
| compliance | optional | optional | optional | optional | optional | optional | optional |

(Эта матрица — derived из manifest'ов; ручная синхронизация поддерживается validate-profile.py.)

## Каталог pipelines

| Pipeline | Назначение | Slash-команда | Артефакты | Worktree |
|----------|------------|---------------|-----------|----------|
| project-planning | Декомпозиция эпика на задачи + roadmap | `/pipelines/project-planning <epic>` | content/00-project/plans/<epic>.md | per-pipeline |
| ba-acceptance | Gate проверка AC ↔ реализация | `/pipelines/ba-acceptance <req>` | acceptance log в требовании | inline в epic-worktree |
| critical-path | Анализ зависимостей задач | `/pipelines/critical-path <epic>` | content/00-project/critical-path/<epic>.md | inline |
| scrum-agile | (stub Wave 3+) | (планируется) | (планируется) | per-pipeline |

## Pipeline-orchestration model

- PM создаёт worktree через `superpowers:using-git-worktrees`: `git worktree add .worktrees/epic-<slug> -b epic-<slug> private`
- В пределах одной pipeline: subagent'ы работают последовательно в одной и той же worktree
- Параллельные стадии (несколько Dev-задач, Researcher + BA одновременно): через `superpowers:dispatching-parallel-agents` (child worktrees → merge обратно в epic-worktree)
- После успешного pipeline'а PM делает PR `epic-<slug>` → `private` → (после pm-review) → `public`
```

### 4.3. apply-overlay.sh — рефакторинг

**Текущий контракт (Wave 1):** скрипт принимает имя overlay-папки, патчит файлы между маркерами `<!-- BEGIN_<NAME> --> ... <!-- END_<NAME> -->`. Append-only, идемпотентен.

**Новый контракт (Wave 2):** добавляются операции add/replace/delete + флаги.

#### CLI

```
apply-overlay.sh [--profile] [--force] [--dry-run] <overlay-name>
```

- **`--profile`** — overlay-name трактуется как профиль (`docs/overlays/profiles/<name>/`); читается `manifest.yaml`, выполняются `operations:`. Без флага — текущее поведение (stack-overlay через markers).
- **`--force`** — отключает strict-проверку delete-non-empty.
- **`--dry-run`** — печатает план операций, ничего не выполняет.

#### Алгоритм при `--profile`

```
1. Прочитать docs/overlays/profiles/<name>/manifest.yaml
2. Если status: stub — print warning, выполнить только что есть в operations (обычно пусто)
3. Запустить validate-profile.py docs/overlays/profiles/<name> — exit 1 при ошибках
4. Применить --on_value мутации (если init передал ответы init_prompts) — обновить копию manifest in-memory
5. Для каждой операции в operations[]:
   a) op: add
      - cp -r <profile>/<source> -> <target>
      - конфликт (target exists): warning + propose --force
   b) op: replace
      - cp -f <profile>/<source> -> <target>
      - всегда перезаписывает
   c) op: delete
      - strict mode: проверить что target пустой ИЛИ содержит только baseline-content
        (placeholder _index.md, .gitkeep)
      - non-empty + НЕ --force: refuse + print что было бы удалено + suggest --force/--dry-run
      - empty или --force: rm -rf <target>
6. Прогнать validate-content.py + validate-profile.py
7. Print "Profile <name> applied successfully" + сводка операций
```

#### Алгоритм без `--profile` (Wave 1 совместимый)

Без изменений: ищет markers в файлах, заменяет блок между ними. Stack-overlay'и (naumen-smp) продолжают работать как было.

#### --dry-run output (пример)

```
$ apply-overlay.sh --profile --dry-run kb-team
Profile: kb-team (status: stable)
Operations preview (DRY-RUN, ничего не выполнено):

  [DELETE] content/30-requirements/  (kb-team не использует функциональные требования)
           ✓ safe to delete: только _index.md с placeholder content + 2x .gitkeep
  [DELETE] content/40-architecture/  (kb-team не имеет компонентов архитектуры)
           ✓ safe to delete: только _index.md
  [DELETE] content/60-implementation/  (нет реализации)
           ⚠ WOULD REFUSE: нашёл .md файлы с не-baseline content. Используй --force для подтверждения.
  [ADD]    content-scaffold/ -> content/  (kb-team scaffold — 5 подпапок)
  [REPLACE] doc-root.yaml -> content/.doc-root.yaml  (kb-team properties)

Validate-profile: ✓ passes
Validate-content (post-simulation): predicted ✓ passes

To apply: rerun without --dry-run.
To force-delete non-empty dirs: rerun with --force.
```

### 4.4. init.sh — рефакторинг

**Текущий (Wave 1):** принимает PROJECT_NAME, PROJECT_CODE, PROJECT_DESCRIPTION, EDITOR_EMAIL, опц. ORIGIN_URL → подставляет плейсхолдеры → wipe .git → initial commit.

**Новый (Wave 2):** добавляется интерактивный выбор профиля и dynamic init_prompts.

#### CLI (interactive mode default)

```
init.sh                                              # полностью интерактивно
init.sh "Project Name" "PROJ" "desc" "email@x.com"   # bash-args, профиль спросит интерактивно
init.sh --profile project ...                        # явно указать профиль (skip prompt)
```

#### Алгоритм

```
1. Прочитать args или спросить интерактивно:
   - PROJECT_NAME, PROJECT_CODE, PROJECT_DESCRIPTION, EDITOR_EMAIL, ORIGIN_URL (опц.)
2. Если --profile не задан, спросить:
   "Выбери профиль (project/product/kb-product/kb-team/custom/methodology/course):"
3. Прочитать docs/overlays/profiles/<name>/manifest.yaml
4. Если status: stub — спросить «Это stub-профиль. Continue? [y/N]»
5. Для каждого init_prompts[]:
   - Вывести prompt
   - Принять ответ согласно type (enum/string/bool)
   - Сохранить в env-переменную INIT_PROMPT_<id>
6. Подставить плейсхолдеры в стандартные файлы (Wave 1) +
   в content/_index.md из профильного content-scaffold/
7. apply-overlay.sh --profile <name> --init  ◄── --init флаг говорит «фреш init,
   игнорируй strict delete т.к. шаблон ещё не имеет content/»
8. Применить on_value мутации к manifest in-memory (только для текущего init,
   manifest на диске не меняется — это профильный контракт)
9. Опц. спросить «Применить stack-overlay'и?» из compatible_stacks
   - Если ответ да, для каждого выбранного stack: apply-overlay.sh <stack>
10. Прогнать validate-content.py + validate-profile.py
11. Wipe .git, init, initial commit (Wave 1 поведение)
12. Опц. setup origin
```

### 4.5. validate-profile.py — новый валидатор

Параллельный скрипт `scripts/validate-profile.py`. Проверяет manifest'ы профилей. Использует `_validate_common.py` для shared types.

#### CLI

```
python3 scripts/validate-profile.py [profile_dir]
```

- Без аргумента — валидирует все профили в `docs/overlays/profiles/*/`
- С аргументом — валидирует один: `validate-profile.py docs/overlays/profiles/project`

#### Exit codes

- `0` — clean (warnings допустимы)
- `1` — есть errors
- `2` — pyyaml не установлен или плохой путь

#### Проверки M1-M10

| # | Уровень | Описание |
|---|---------|----------|
| M1 | error | Папка профиля содержит `manifest.yaml` |
| M2 | error | Manifest содержит обязательные поля (`schema_version`, `name`, `description`, `status`, `subagents`, `pipelines`, `content_scaffold`, `doc_root`, `operations`, `compatible_stacks`) |
| M3 | error | `name` совпадает с именем папки |
| M4 | error | Все имена ролей в `subagents:` объявлены в AGENTS.md (registry, грепом ищем в таблице «Каталог ролей») |
| M5 | error | Все имена pipelines в `pipelines:` существуют в `commands/pipelines/<name>.md` или явно помечены `disabled` |
| M6 | error | Значения `subagents.*` ∈ `{core, optional, disabled}`; `pipelines.*` ∈ `{enabled, optional, disabled}` |
| M7 | error | `content_scaffold:` и `doc_root:` пути существуют относительно папки профиля (исключая stub'ы) |
| M8 | warning | `init_prompts[].on_value.<key>` мутирует существующий ключ манифеста (например `subagents.compliance`) |
| M9 | warning | `compatible_stacks` упоминают реальные overlay'и (`docs/overlays/<stack>/` существует), кроме `["*"]` |
| M10 | warning | `status: stub` для профилей с непустым `content_scaffold/`, или `status: stable` для профилей с пустым (mismatch) |

#### Архитектура реализации

```python
# scripts/validate-profile.py
from _validate_common import Issue, parse_yaml, has_placeholder, format_issues

def load_manifest(profile_dir): ...
def collect_known_roles(): ...      # парсит AGENTS.md таблицу
def collect_known_pipelines(): ...  # листинг commands/pipelines/
def check_m1_manifest_present(profile_dir): ...
def check_m2_required_fields(manifest): ...
# ... и т.д.

def main(argv) -> int: ...
```

### 4.6. _validate_common.py — общий модуль

```python
# scripts/_validate_common.py
"""Shared utilities for validate-content.py and validate-profile.py."""
from __future__ import annotations
import re
from dataclasses import dataclass
from pathlib import Path

PLACEHOLDER_RE = re.compile(r"\{\{[A-Z_]+\}\}")

try:
    import yaml
except ImportError:
    yaml = None  # callers handle gracefully

@dataclass
class Issue:
    level: str  # "error" | "warning"
    path: str
    message: str

def parse_frontmatter(file_path: Path) -> dict | None: ...
def parse_yaml_file(path: Path) -> dict | None: ...
def has_placeholder(file_path: Path) -> bool: ...
def format_issues(issues: list[Issue]) -> str: ...
```

`validate-content.py` рефакторится минимально: импортирует из `_validate_common`, убирает локальные дубликаты. Контракт C1-C7 не меняется.

### 4.7. Promtы агентов — 5 новых + 6 улучшенных

#### Новые prompt'ы

##### `agents/qa-author-agent.md`

Контракт:
- **Цель:** написать AC-driven test design + failing test stubs ДО Dev'а.
- **Входы:** требование (`content/30-requirements/<req>.md`) с AC, опц. архитектурный артефакт SA.
- **Артефакты:**
  - `content/30-requirements/<req>/at-design.md` — markdown-таблица: AC ID → assertion outline → test type (unit/integration/e2e)
  - `tests/<area>/test_<req>.py` (или эквивалент по стеку: `*.test.ts`, `*Test.java`, `test_*.sh`) с failing assertions
- **Критерии приёмки:** stubs запускаются и падают (red); AC покрытие 100%; assertion рассчитан на TDD-цикл (Dev сделает зелёным).

##### `agents/qa-runner-agent.md`

Контракт:
- **Цель:** прогнать full test suite (включая регрессии) после Dev'а; сформировать отчёт.
- **Входы:** код в `src/` или `tests/` (если есть), требование с AC.
- **Артефакты:** `content/60-implementation/test-reports/<NNN>-<date>.md` со структурой: passed/failed/skipped, regression analysis, performance snapshot (если применимо), recommendations.
- **Критерии приёмки:** отчёт включает все категории; failed tests разобраны по причине; рекомендация — merge / block / re-run.

##### `agents/tech-writer-agent.md`

Контракт (base = secondary editor):
- **Цель:** превратить технический черновик (от Dev/SA/BA) в customer-facing статью.
- **Входы:** исходник (например `content/40-architecture/<file>.md`).
- **Артефакты:** обновлённая статья с property `Audience: Public` (или новая `<file>.public.md` рядом, если требуется сохранить original).
- **Критерии приёмки:** язык понятен не-инженеру; нет жаргона без определения; cross-ссылки on glossary.
- **Override stub** в `profiles/kb-product/agent-overrides/tech-writer.md`, `profiles/methodology/agent-overrides/tech-writer.md`, `profiles/course/agent-overrides/tech-writer.md` — primary-author mode (переключит контракт на «писать с нуля» в Wave 3).

##### `agents/devsecops-agent.md`

Контракт:
- **Цель:** embedded security review в Dev-фазе — secrets/SAST/supply-chain.
- **Входы:** код, конфигурация, manifests.
- **Артефакты:** `content/00-project/security/audit-<NNN>-<date>.md` — findings + рекомендации; опц. `content/00-project/security/secrets-policy.md` (один раз для проекта).
- **Критерии приёмки:** SAST findings с severity; secrets-management policy зафиксирован; supply-chain risk assessed.

##### `agents/compliance-agent.md`

Контракт (general-purpose research):
- **Цель:** проверить соответствие коду/архитектуре переданному стандарту (152-ФЗ / ISO27001 / internal).
- **Входы:** список требований стандарта (передаёт пользователь в запросе) + артефакты проекта (требования, ADR, код).
- **Артефакты:** `content/00-project/compliance/<standard>-<date>.md` — gap analysis: соответствует/не соответствует/частично + рекомендации.
- **Критерии приёмки:** каждое требование стандарта прокомментировано; gap-priorities выставлены; рекомендации actionable.

#### Улучшенные prompt'ы

Краткие аннотации (полные prompt'ы пишутся implementer-субагентами с opus):

- **`agents/pm-agent.md`** (EDIT): расширяется секцией про pipelines, soft-suggest opt-in subagents в decompose, координацию 10 ролей, ритуал worktree-создания.
- **`agents/researcher-agent.md`** (EDIT): чёткое разделение труда «Researcher собирает контекст; BA пишет требования; SA — архитектуру». Researcher не создаёт требования/AC.
- **`agents/ba-agent.md`** (EDIT): + `--mode=acceptance` секция: BA проверяет AC ↔ реализацию, выносит вердикт pass/block.
- **`agents/sa-agent.md`** (EDIT): передаёт AC qa-author'у явно (новая секция «Контракт с QA-author»), не пишет тесты сам.
- **`agents/dev-agent.md`** (EDIT): TDD по qa-author stubs (а не самописным тестам), приоритет — сделать stubs зелёными.
- **`agents/devops-agent.md`** (EDIT): координация с DevSecOps. DevOps владеет deploy/runbook/monitoring; DevSecOps — secrets/SAST/policy. Не дублируются.

### 4.8. Pipeline orchestrator commands

Каждый pipeline = slash-команда в `commands/pipelines/<name>.md`. Команда — оркестратор: создаёт worktree, последовательно вызывает subagent'ы через Agent tool.

#### `/pipelines/project-planning <epic>`

```markdown
1. Создать worktree:
   git worktree add .worktrees/epic-<slug> -b epic-<slug> private
2. /research <epic context>  → content/10-domain/research/<slug>.md (опц.)
3. /ba new-requirement <slug> → content/30-requirements/<slug>.md
4. /sa design <slug>  → content/40-architecture/<slug>.md
5. /qa --mode=author <slug>   → at-design.md + tests/<...>
6. /dev implement <slug>  → src/<...>
7. /qa --mode=runner <slug>   → test-reports/<NNN>.md
8. /pipelines/ba-acceptance <slug>  → gate
9. PR epic-<slug> → private
```

#### `/pipelines/ba-acceptance <req>`

```markdown
1. /ba --mode=acceptance <req>
   - Читает требование (AC) и реализацию (src/, tests/)
   - Сравнивает построчно
   - Заполняет «Acceptance log» секцию в требовании
   - Возвращает pass | block + список не покрытых AC
2. Если pass — pipeline продолжает; block — возврат к /dev
```

#### `/pipelines/critical-path <epic>`

```markdown
1. Прочитать content/00-project/plans/<epic>.md (от project-planning)
2. Извлечь зависимости задач (RES-XXX, BA-XXX, SA-XXX, DEV-XXX, QA-XXX, OPS-XXX)
3. Построить DAG, найти критический путь
4. Сгенерировать mermaid Gantt
5. Записать в content/00-project/critical-path/<epic>.md
```

### 4.9. test-template.sh — matrix по профилям

Расширение Wave 1 теста. После Wave 2 структура:

```bash
# Для каждого профиля в [project, kb-team]:
for PROFILE in project kb-team; do
  TMP=$(mktemp -d)
  rsync -a --exclude='.git' --exclude='.worktrees' . "$TMP/"
  cd "$TMP"

  # T1-T7 (Wave 1) — sanity, init, validate
  bash scripts/init.sh --profile "$PROFILE" "Test" "TEST" "desc" "test@x.com"

  # T-PROFILE: профиль-специфичные ассерты
  assert "manifest.yaml в overlays" "[ -f docs/overlays/profiles/$PROFILE/manifest.yaml ]"
  assert "validate-profile.py зелёный" "python3 scripts/validate-profile.py >/dev/null 2>&1"

  # T8 (Wave 1) + T-MATRIX
  python3 scripts/validate-content.py
  python3 scripts/validate-profile.py

  cd -
  rm -rf "$TMP"
done

# T-OVERLAY-DRY: --dry-run флаг работает
assert "apply-overlay --profile --dry-run печатает план" \
  "bash scripts/apply-overlay.sh --profile --dry-run kb-team | grep -q 'DRY-RUN'"

# T-OVERLAY-FORCE: --force отключает strict delete
# (создать non-empty dir, попробовать delete без force → должен refuse;
#  попробовать с force → должен пройти)
```

## 5. Data flow

### 5.1. /init flow с профилем

```
User
  │ /init "My Project" "MY" "desc" "user@x.com"
  ▼
init.sh phase 1
  ├── parse args
  ├── interactive: «выбери профиль»  ◄── NEW
  │   user: "kb-team"
  ├── load manifest: docs/overlays/profiles/kb-team/manifest.yaml
  ├── status check: stable
  ├── interactive: init_prompts[]    ◄── NEW (например compliance_domain)
  │   user: "152-fz" → on_value: subagents.compliance: optional → core
  ├── replace_in_file для CLAUDE.md, AGENTS.md, README.md, content/.doc-root.yaml,
  │   content/_index.md, и для всех _index.md в content-scaffold/
  ├── apply-overlay.sh --profile --init kb-team   ◄── NEW
  │   ├── load manifest
  │   ├── apply on_value мутации к копии manifest
  │   ├── for each op in operations[]:
  │   │     delete content/30-requirements/ (safe: empty)
  │   │     delete content/40-architecture/ (safe: empty)
  │   │     delete content/60-implementation/ (safe: empty)
  │   │     delete content/70-operations/ (safe: empty)
  │   │     add content-scaffold/* -> content/
  │   │     replace doc-root.yaml -> content/.doc-root.yaml
  │   └── validate-content.py + validate-profile.py
  ├── interactive: «применить stack-overlay'и?»  ◄── NEW
  │   user: "yes, naumen-smp"
  │   apply-overlay.sh naumen-smp  (текущий, marker-based)
  ├── wipe .git
  ├── git init -b main
  ├── git add . && initial commit
  └── опц. setup origin
  ▼
init.sh phase 2 (slash /init)
  └── interactive интервью по 6 темам (Wave 1)
```

### 5.2. Pipeline flow (project-planning)

```
PM (main)
  │ /pipelines/project-planning user-sessions
  ▼
project-planning.md slash-command
  ├── git worktree add .worktrees/epic-user-sessions -b epic-user-sessions private
  ├── cd .worktrees/epic-user-sessions
  ├── /research user-sessions → content/10-domain/research/user-sessions.md
  ├── /ba new-requirement user-sessions → content/30-requirements/user-sessions.md
  ├── /sa design user-sessions → content/40-architecture/sessions.md
  ├── /qa --mode=author user-sessions
  │     ├── content/30-requirements/user-sessions/at-design.md
  │     └── tests/auth/test_user_session.py (failing)
  ├── /dev implement user-sessions → src/repositories/user_session.py
  │     (TDD: сделать failing test зелёным)
  ├── /qa --mode=runner user-sessions
  │     └── content/60-implementation/test-reports/001-2026-05-15.md
  ├── /pipelines/ba-acceptance user-sessions
  │     ├── /ba --mode=acceptance user-sessions
  │     ├── pass → continue
  │     └── block → возврат к /dev
  ├── git push origin epic-user-sessions
  └── PR epic-user-sessions → private (PM сам решает merge timing)
```

## 6. Error handling

### 6.1. apply-overlay.sh

| Ошибка | Поведение |
|--------|-----------|
| Профиль не существует (`docs/overlays/profiles/<name>/` нет) | exit 1 + печать списка существующих профилей |
| `manifest.yaml` отсутствует | exit 1 + сообщение «manifest.yaml not found» |
| validate-profile fail | exit 1 + сообщения от validator'а |
| `op: delete` с non-empty target и без `--force` | exit 1 + что было бы удалено + suggest `--force`/`--dry-run` |
| `op: add` с конфликтом target (target уже существует) | warning, suggest `--force` для overwrite |
| `op: replace` source не существует | exit 1 |

### 6.2. init.sh

| Ошибка | Поведение |
|--------|-----------|
| Невалидный ответ на init_prompts (тип/choice) | повтор prompt'а до валидного |
| apply-overlay fail во время init | exit 1 + сообщение, init НЕ совершает initial commit |
| Конфликт между профилем и stack (incompatible_stacks) | warning + suggest другой stack |

### 6.3. validate-profile.py

| Ошибка | Уровень | Поведение |
|--------|---------|-----------|
| Незнакомая роль в manifest | M4 error | exit 1 |
| Незнакомый pipeline | M5 error | exit 1 |
| Незакрытый `compatible_stacks: ["smp"]` (нет `docs/overlays/smp/`) | M9 warning | exit 0 |
| Stub-профиль с непустым scaffold | M10 warning | exit 0 |

### 6.4. Pipeline-orchestrator

| Ошибка | Поведение |
|--------|-----------|
| Worktree уже существует | suggest `--reuse` или ручное удаление |
| Subagent fail в pipeline | прерывание pipeline + status в `content/00-project/plans/<epic>.md` |
| Параллельная стадия с конфликтом merge | escalate в PM с предложением resolve вручную |

## 7. Тесты

### 7.1. Unit-уровень — `_validate_common.py`

Тесты в `test-validate-content.sh` (расширение):
- `parse_frontmatter` корректно парсит object-нотацию и валидный YAML
- `has_placeholder` детектит `{{X_Y}}` в frontmatter
- `Issue` dataclass — конструктор и сериализация
- `parse_yaml_file` graceful при невалидном YAML

### 7.2. Validator-уровень — `validate-profile.py`

Тесты в `scripts/test-validate-profile.sh` (NEW):
- M1: профиль без manifest.yaml → error
- M2: manifest без `subagents` → error
- M3: name не совпадает с папкой → error
- M4: subagents содержит «pma» (typo) → error
- M5: pipelines содержит «scrum-agile-stub» (нет в commands/) → error
- M6: subagents.pm: "active" (вне enum) → error
- M7: content_scaffold: «nonexistent/» → error
- M8: on_value мутация subagents.unknown_role → warning
- M9: compatible_stacks: [«unknown-stack»] → warning
- M10: status: stable + empty content_scaffold → warning

### 7.3. Integration — `test-template.sh`

Matrix по профилям (project, kb-team) — см. §4.9. Для каждого:
- T1-T9 Wave 1 — продолжают работать
- T-PROFILE: manifest.yaml существует, validate-profile зелёный
- T-OVERLAY-INIT: после init scaffold соответствует профилю (например для kb-team — нет `30-requirements/`, есть `30-runbooks/`)
- T-DRY-RUN: `apply-overlay --profile --dry-run kb-team` печатает план
- T-DELETE-STRICT: refuse при non-empty + force при `--force`

### 7.4. Backwards compatibility

`test-template.sh` запускает T-LEGACY:
- Прогоняет старый flow без `--profile` (без аргумента → init.sh fallback на профиль `project`)
- Проверяет, что результат идентичен Wave 1 (тот же scaffold, тот же `.doc-root.yaml`)
- Старый stack-overlay (`naumen-smp`) применяется как раньше — `apply-overlay.sh naumen-smp`

## 8. Anti-scope

Что Wave 2 **НЕ** делает (вход в Wave 3+):

- ❌ **L2/L3 customization workflow** — workflow per-profile (Q2=D Hybrid: Wave 2 — только L1).
- ❌ **Declarative merge override'ов** — frontmatter `extends`/`sections: replace/append`. Override = full file replace (I1=A).
- ❌ **Build-time templating qa-agent** — два физических файла, не один источник (I3=B).
- ❌ **Strict layering with state-file** — нет `content/.overlay-state.yaml`, no migration tracking (I6=A).
- ❌ **Compliance domain rules database** — Compliance = general-purpose research (Q10=A).
- ❌ **Scrum-agile pipeline implementation** — только stub в манифестах (Q7=B).
- ❌ **Migration существующих проектов между профилями** — at-init-only, no post-init switch.
- ❌ **pytest-стиль тестов** — продолжаем bash-харнесс (Wave 1 контракт).
- ❌ **profile-specific subagent prompts** — overrides пустые в Wave 2 (полноценные — Wave 3).
- ❌ **Удалять `.gitkeep`** — оставляем где есть, не вычищаем.
- ❌ **`/init --switch-profile`** — нет команды миграции профиля; нужно делать `/init` заново на чистом репо.
- ❌ **5 stub-профилей с реальным content-scaffold/** — у них пустой scaffold; baseline'ы — только project и kb-team.

## 9. GO-критерии Wave 2

Wave 2 закрыта, когда:

- [ ] **Профили:** `docs/overlays/profiles/{project,kb-team}/manifest.yaml` + `content-scaffold/` + `doc-root.yaml` + пустой `agent-overrides/` написаны и зелёные на validate-profile.py
- [ ] **Stub-манифесты:** `docs/overlays/profiles/{product,kb-product,custom,methodology,course}/manifest.yaml` написаны со status: stub, минимальные обязательные поля
- [ ] **Validators:** `scripts/_validate_common.py` создан; `validate-content.py` рефакторен на shared module без изменения контракта; `validate-profile.py` создан, реализует M1-M10
- [ ] **Тесты валидаторов:** `test-validate-content.sh` дополнен, `test-validate-profile.sh` создан, оба зелёные
- [ ] **apply-overlay.sh:** поддерживает `--profile`, `--force`, `--dry-run`, ops add/replace/delete; strict delete-non-empty работает; unit-test'ы для каждой ops в test-template.sh
- [ ] **init.sh:** интерактивный выбор профиля; dynamic init_prompts; on_value мутации работают; backwards compatible (без `--profile` → fallback на project)
- [ ] **AGENTS.md:** реестр 10 ролей с контрактом, матрица «роль × профиль», pipeline-каталог, pipeline-orchestration model
- [ ] **5 новых агент-prompt'ов:** qa-author, qa-runner, tech-writer, devsecops, compliance — полноценные prompt'ы (не stubs)
- [ ] **6 улучшенных prompt'ов:** pm, researcher, ba (+ acceptance mode), sa, dev (TDD по qa-author), devops — обновлены с учётом разделения труда
- [ ] **3 pipeline-команды:** `commands/pipelines/{project-planning,ba-acceptance,critical-path}.md` написаны как orchestrator-агенты
- [ ] **5 новых slash-команд:** `commands/{qa,tech-writer,devsecops,compliance}.md` + `ba.md` обновлён `--mode=acceptance`
- [ ] **CLAUDE.md:** добавлен блок «Профильная система»
- [ ] **README.md:** упомянут `/init --profile`, `validate-profile.py`
- [ ] **`docs/extending.md`:** гайд «как добавить роль / pipeline / профиль» написан
- [ ] **`test-template.sh` matrix:** прогоняет project + kb-team, оба зелёные; T-DRY-RUN, T-DELETE-STRICT, T-LEGACY проходят
- [ ] **lessons-learned:** записаны итоги Wave 2; **auto-memory:** обновлены ключевые reference/feedback memories
- [ ] **Backwards compatibility:** существующий `project_template`-based репозиторий запускается на новом коде как `project` профиль; старый `apply-overlay.sh naumen-smp` (markers-based) работает
- [ ] **`/pm-review`:** запускает оба validator'а, проверяет состояние pipelines/worktree

## 10. Открытые вопросы (для SA на этапе plan'а)

Это вопросы, которые brainstorming не закрыл, но которые SA-этап (writing-plans → SDD-implementation) проработает:

1. **Точный синтаксис worktree-handoff между параллельными стадиями** — например, между двух Dev-задач, работающих на разных частях фичи. Как именно `dispatching-parallel-agents` сольёт child worktree'ы обратно в epic? Нужно ли prefix-имя файлов чтобы избежать конфликтов?
2. **Какое именно подмножество обязательных полей у stub-манифеста** — формальный JSON Schema (или dataclass) для validate-profile.py.
3. **Как именно AGENTS.md «реестр» парсится в validate-profile.py для M4** — regex по таблице, или отдельный machine-readable файл `agents/index.yaml`? *(Предлагаю regex по таблице на Wave 2; на Wave 3 можно добавить index.yaml.)*
4. **Расширение `Тип контента` в `.doc-root.yaml` для профилей** — kb-team имеет свой набор (Onboarding, Runbook, Role, Incident, Эскалация); project расширяется новыми (Test Design, Test Report, Security Audit, Compliance Report, Plan, Critical Path, Secrets Policy). Точные enum-values — на этапе plan'а.
5. **Pipeline-state tracking** — где живёт текущее состояние эпика (active stage, completed stages, blockers). В `content/00-project/plans/<epic>.md` или отдельном `pipeline-state.yaml`? *(Предлагаю in-line в plan-<epic>.md секцией «State».)*
6. **Activation triggers UI flow** — как именно PM «спрашивает» пользователя о soft-suggest opt-in subagent'ах? Inline в decompose output или отдельным interactive prompt?

Эти вопросы проработаются в фазе writing-plans или превратятся в Implementation Notes в коде.

---

## 11. Self-Review

### 11.1. Placeholder scan

✓ Нет TBD/TODO в spec'е (все секции наполнены).
✓ Нет «similar to X» — каждая секция самодостаточна.
✓ Нет вопросов, неотвеченных в дизайне (открытые — явно отнесены в §10 на SA-этап).

### 11.2. Internal consistency

✓ §3.2 (file structure) согласуется с §4 (компоненты) — все упоминаемые файлы в structure'е описаны в components.
✓ Manifest schema (§4.1) согласуется с manifest checks (§4.5 M1-M10).
✓ Pipeline orchestration model (§4.2 AGENTS.md) согласуется с data flow (§5.2).
✓ apply-overlay --force/--dry-run упоминается в CLI (§4.3) и тестируется (§7.3).
✓ Backwards compatibility (§7.4) согласуется с anti-scope «no migration» (§8) — это разные вещи: backwards compatibility = старый шаблон работает на новом коде; migration = переключить уже инициализированный репо в другой профиль.

### 11.3. Scope check

✓ Wave 2 фокусирован: один spec → один plan → одна реализация (через SDD итеративно). Нет необходимости декомпозировать на под-проекты, хотя plan на 30+ задач (это принято на интервью Q5=D «как успеем»).

### 11.4. Ambiguity check

Спорных мест в spec'е (мог двояко прочесть):

- ✓ «Strict delete-non-empty» — определено через «target пустой ИЛИ только baseline content (placeholder _index.md, .gitkeep)» — недвусмысленно.
- ✓ «qa-author + qa-runner — одна логическая роль» — явно сказано в AGENTS.md registry «два физических файла, одна логическая запись».
- ✓ «`compatible_stacks: ["*"]`» — явно описано в §4.1 как «всё разрешено» (отдельно от `[]` = «никакие»).

Если что-то прочитается двояко — фиксим в plan'е (writing-plans) или в коде.

---

## 12. Метаданные

- **Зависимости от Wave 1:** `validate-content.py` C1-C7, `_index.md` everywhere, object-нотация frontmatter, `.doc-root.yaml` schema, `apply-overlay.sh` markers-based — НЕ трогаем (контракт стабилен).
- **Зависимости на superpowers:** `using-git-worktrees`, `dispatching-parallel-agents`, `subagent-driven-development`, `test-driven-development`.
- **Эффект на пользователя:** существующий проект продолжит работать без изменений; новые проекты получат интерактивный выбор профиля и расширенный каталог ролей.
- **Эффект на CI:** test-template.sh matrix-времени растёт ~×2 (project + kb-team в matrix); validate-profile.py добавляет 2-3 секунды.

---

**Next steps after этого spec'а:**
1. Owner ревьюит spec → approve / request changes.
2. После approve — `superpowers:writing-plans` создаёт granular plan в `docs/superpowers/plans/2026-05-06-multi-template-support.md`.
3. После plan approve — `superpowers:subagent-driven-development` (с Opus subagent'ами per Q5 разрешению) реализует.
4. Финальный `superpowers:requesting-code-review` всю ветку перед merge `private` → `public`.
