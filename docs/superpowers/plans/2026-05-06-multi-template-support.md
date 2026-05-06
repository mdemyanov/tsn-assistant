# Multi-Template Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Owner авторизовал Opus-модель для implementer/reviewer subagent'ов в этом репозитории — используй её.

**Goal:** Превратить `project_template` в profile-driven систему с расширенным каталогом 10 ролей, 3 pipeline'ами и расширенным `apply-overlay.sh` (ops add/replace/delete) — реализовать `project` + `kb-team` baseline'ы, остальные 5 профилей оставить stub'ами.

**Architecture:** B+C гибрид (интерактивный `/init` под капотом дёргает `apply-overlay.sh --profile <name>` с операциями из `manifest.yaml`). Profile = exclusive foundation (`docs/overlays/profiles/<name>/`); stacks (naumen-smp и др.) стэкабельны поверх. Override agent-prompt'ов через Claude Code priority-dir (полная замена). qa-agent — два физических файла (qa-author + qa-runner) под одной логической ролью с диспетчем через `/qa --mode=author|runner`.

**Tech Stack:** Python 3.8+ (PyYAML), Bash 4+ (jq не нужен — использовать python для YAML-парсинга), git, Claude Code agents/commands.

**Спецификация:** [docs/superpowers/specs/2026-05-06-multi-template-support-design.md](../specs/2026-05-06-multi-template-support-design.md)

**Эталон формата плана:** [docs/superpowers/plans/2026-05-06-gramax-template-alignment.md](2026-05-06-gramax-template-alignment.md) (Wave 1)

**Контекст для implementer'ов:** перед началом каждой задачи читай контракт из spec'а §4 (Components) — там подробности для каждого компонента.

---

## File Structure

### Создаваемые файлы

| Путь | Назначение |
|------|------------|
| `scripts/_validate_common.py` | Shared utility module: Issue dataclass, parse_frontmatter, parse_yaml_file, has_placeholder, PLACEHOLDER_RE |
| `scripts/validate-profile.py` | Валидатор manifest'ов профилей (M1-M10) |
| `scripts/test-validate-profile.sh` | Тест-харнесс для validate-profile.py |
| `docs/overlays/profiles/project/manifest.yaml` | Манифест baseline-профиля `project` |
| `docs/overlays/profiles/project/doc-root.yaml` | Шаблон `.doc-root.yaml` для `project` (расширен новыми Тип контента) |
| `docs/overlays/profiles/project/content-scaffold/...` | Полный scaffold project-профиля (включая новые `plans/`, `critical-path/`, `security/`, `compliance/`, `test-reports/`) |
| `docs/overlays/profiles/project/agent-overrides/` | Пустая папка с `.gitkeep` (готовность к Wave 3) |
| `docs/overlays/profiles/kb-team/manifest.yaml` | Манифест контрастного baseline'а `kb-team` |
| `docs/overlays/profiles/kb-team/doc-root.yaml` | Шаблон `.doc-root.yaml` для `kb-team` (Onboarding/Runbook/Role/Incident) |
| `docs/overlays/profiles/kb-team/content-scaffold/...` | scaffold kb-team (10-domain, 20-onboarding, 30-runbooks, 40-roles, 50-incidents) |
| `docs/overlays/profiles/kb-team/agent-overrides/` | Пустая |
| `docs/overlays/profiles/{product,kb-product,custom,methodology,course}/manifest.yaml` | 5 stub-манифестов |
| `agents/qa-author-agent.md` | NEW: AC → at-design.md + failing test stubs |
| `agents/qa-runner-agent.md` | NEW: full suite + регрессии + отчёт |
| `agents/tech-writer-agent.md` | NEW: secondary editor (base) |
| `agents/devsecops-agent.md` | NEW: secrets/SAST/supply-chain |
| `agents/compliance-agent.md` | NEW: research-агент general-purpose |
| `.claude/plugins/project/commands/qa.md` | NEW: `/qa --mode=author|runner` диспетч |
| `.claude/plugins/project/commands/tech-writer.md` | NEW |
| `.claude/plugins/project/commands/devsecops.md` | NEW |
| `.claude/plugins/project/commands/compliance.md` | NEW |
| `.claude/plugins/project/commands/pipelines/project-planning.md` | NEW: orchestrator |
| `.claude/plugins/project/commands/pipelines/ba-acceptance.md` | NEW: gate |
| `.claude/plugins/project/commands/pipelines/critical-path.md` | NEW: DAG-анализ |
| `docs/extending.md` | NEW: гайд «как добавить роль / pipeline / профиль» |

### Модифицируемые файлы

| Путь | Что меняем |
|------|------------|
| `scripts/validate-content.py` | Минимально: убрать локальные дубликаты Issue/parse_frontmatter, импортировать из `_validate_common`. Контракт C1-C7 не меняется. |
| `scripts/test-validate-content.sh` | Добавить тесты для shared module (parse_frontmatter, has_placeholder работают одинаково после рефакторинга). |
| `scripts/apply-overlay.sh` | Расширение: `--profile`, `--force`, `--dry-run`, ops add/replace/delete; existing markers-flow продолжает работать. |
| `scripts/init.sh` | Интерактивный выбор профиля; dynamic init_prompts из manifest; on_value мутации; опц. stack-overlay'и после профиля. |
| `scripts/test-template.sh` | Matrix: project + kb-team; T-DRY-RUN, T-DELETE-STRICT, T-LEGACY. |
| `AGENTS.md` | Реестр 10 ролей с контрактом, матрица «роль × профиль», pipeline-каталог, orchestration model. |
| `agents/pm-agent.md` | Pipelines, decompose с soft-suggest, координация 10 ролей. |
| `agents/researcher-agent.md` | Чёткое разделение труда: Researcher собирает контекст, не пишет требования. |
| `agents/ba-agent.md` | + `--mode=acceptance` секция. |
| `agents/sa-agent.md` | Контракт с QA-author (передача AC). |
| `agents/dev-agent.md` | TDD по qa-author stubs. |
| `agents/devops-agent.md` | Координация с DevSecOps. |
| `.claude/plugins/project/commands/init.md` | Profile-выбор в Phase 1. |
| `.claude/plugins/project/commands/pm.md` | Pipelines, decompose с suggest. |
| `.claude/plugins/project/commands/pm-review.md` | + validate-profile, + pipeline-state checks. |
| `.claude/plugins/project/commands/ba.md` | `/ba --mode=acceptance`. |
| `CLAUDE.md` | Блок «Профильная система» (~30 строк шпаргалки). |
| `README.md` | Упомянуть `/init --profile`, validate-profile.py. |
| `docs/lessons-learned.md` | Append записи Wave 2. |

### Удаляемые файлы

Никаких удалений в этом плане. Wave 1 артефакты (`validate-content.py` C1-C7, `_index.md` структура, существующий `apply-overlay.sh` markers-flow) сохраняются.

---

## Phase 1 — Validators refactor + validate-profile.py (TDD)

### Task 1: Extract `_validate_common.py` (рефакторинг Wave 1, контракт стабилен)

**Files:**
- Create: `scripts/_validate_common.py`
- Modify: `scripts/validate-content.py`
- Modify: `scripts/test-validate-content.sh`

- [ ] **Step 1: Создать `scripts/_validate_common.py` с shared utilities**

```python
#!/usr/bin/env python3
"""Shared utilities for validate-content.py and validate-profile.py."""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

PLACEHOLDER_RE = re.compile(r"\{\{[A-Z_]+\}\}")

try:
    import yaml  # PyYAML
except ImportError:
    yaml = None


def require_yaml() -> None:
    """Exit code 2 если PyYAML не установлен."""
    if yaml is None:
        print("ERROR: PyYAML не установлен. Установи: pip install pyyaml", file=sys.stderr)
        sys.exit(2)


@dataclass
class Issue:
    level: str  # "error" | "warning"
    path: str
    message: str


def parse_frontmatter(file_path: Path) -> dict | None:
    """Извлекает YAML-frontmatter между --- из markdown-файла. None если нет/невалиден."""
    require_yaml()
    text = file_path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return None
    parts = text.split("---", 2)
    if len(parts) < 3:
        return None
    try:
        return yaml.safe_load(parts[1]) or {}
    except yaml.YAMLError:
        return None


def parse_yaml_file(path: Path) -> dict | None:
    """Читает YAML-файл. Возвращает {} если файла нет; None если невалиден."""
    require_yaml()
    if not path.exists():
        return {}
    try:
        text = path.read_text(encoding="utf-8")
        # Подменяем плейсхолдеры на безопасные строки (для шаблонов до init.sh)
        substituted = PLACEHOLDER_RE.sub(lambda m: f'"PLACEHOLDER_{m.group(0)[2:-2]}"', text)
        return yaml.safe_load(substituted) or {}
    except yaml.YAMLError:
        return None


def has_placeholder(file_path: Path) -> bool:
    """True если frontmatter содержит литерал {{...}}."""
    text = file_path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return False
    parts = text.split("---", 2)
    if len(parts) < 3:
        return False
    return bool(PLACEHOLDER_RE.search(parts[1]))


def format_issues(issues: list[Issue]) -> str:
    """Форматирует список Issue для печати."""
    return "\n".join(
        f"{i.path}: {i.message}  [{i.level}]"
        for i in sorted(issues, key=lambda x: (x.path, x.level))
    )
```

- [ ] **Step 2: Рефакторить `validate-content.py` — импортировать из `_validate_common.py`**

В `scripts/validate-content.py` удалить локальные определения `Issue`, `parse_frontmatter`, `has_placeholder`, `PLACEHOLDER_RE`, `load_doc_root` (последняя превращается в `parse_yaml_file(content_dir / ".doc-root.yaml")`). Заменить на импорт:

```python
from _validate_common import Issue, parse_frontmatter, parse_yaml_file, has_placeholder, PLACEHOLDER_RE, require_yaml
```

Заменить вызов `load_doc_root(content_dir)` на `parse_yaml_file(content_dir / ".doc-root.yaml") or {}`.

Контракт C1-C7 не меняется; sortировка/печать issues — без изменений.

- [ ] **Step 3: Прогнать `test-validate-content.sh` — должен пройти полностью**

```bash
bash scripts/test-validate-content.sh
```

Expected: PASS (все 24/24 ассерта).

Если что-то сломалось — фикс в `_validate_common.py` или `validate-content.py`. НЕ менять `test-validate-content.sh`, кроме шага 4.

- [ ] **Step 4: Добавить sanity-тесты для shared module**

В конец `test-validate-content.sh` (перед `==> Results`) добавить:

```bash
# ===== Shared module sanity =====
echo ""
echo "==> SHARED: _validate_common.py importable"
assert "import _validate_common works" "python3 -c 'import sys; sys.path.insert(0, \"$REPO_ROOT/scripts\"); import _validate_common; print(_validate_common.PLACEHOLDER_RE.pattern)' >/dev/null 2>&1"
assert "Issue dataclass exposed" "python3 -c 'import sys; sys.path.insert(0, \"$REPO_ROOT/scripts\"); from _validate_common import Issue; i = Issue(\"error\", \"x\", \"y\"); print(i.level)' | grep -q '^error$'"
```

- [ ] **Step 5: Прогнать `test-validate-content.sh` повторно**

```bash
bash scripts/test-validate-content.sh
```

Expected: PASS, новые SHARED-ассерты зелёные.

- [ ] **Step 6: Прогнать `validate-content.py` на текущем шаблоне**

```bash
python3 scripts/validate-content.py
```

Expected: Errors: 0 | Warnings: 2 (плейсхолдеры в `_index.md` и `.doc-root.yaml`) — поведение Wave 1.

- [ ] **Step 7: Commit**

```bash
git add scripts/_validate_common.py scripts/validate-content.py scripts/test-validate-content.sh
git commit -m "refactor(validate): extract _validate_common module, validate-content контракт стабилен [W2-T1]"
```

---

### Task 2: Скелет `validate-profile.py` + тест-харнесс

**Files:**
- Create: `scripts/validate-profile.py`
- Create: `scripts/test-validate-profile.sh`

- [ ] **Step 1: Создать `scripts/test-validate-profile.sh`**

```bash
#!/usr/bin/env bash
# test-validate-profile.sh — тесты для scripts/validate-profile.py
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$REPO_ROOT/scripts/validate-profile.py"

PASS=0
FAIL=0

assert() {
  local desc="$1"
  local cond="$2"
  if eval "$cond"; then
    echo "  ✓ $desc"
    PASS=$((PASS+1))
  else
    echo "  ✗ $desc"
    echo "    failed: $cond"
    FAIL=$((FAIL+1))
  fi
}

# ===== T0: --help работает =====
echo "==> T0: --help"
assert "validator --help прошёл" "python3 \"$VALIDATOR\" --help >/dev/null 2>&1"

echo ""
echo "==> Results: $PASS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
echo "✓ test-validate-profile.sh PASSED"
```

Сделать исполняемым: `chmod +x scripts/test-validate-profile.sh`

- [ ] **Step 2: Запустить тест — упадёт**

```bash
bash scripts/test-validate-profile.sh
```

Expected: FAIL (validate-profile.py не существует).

- [ ] **Step 3: Создать минимальный `scripts/validate-profile.py`**

```python
#!/usr/bin/env python3
"""validate-profile.py — валидатор manifest'ов профилей.

Проверяет docs/overlays/profiles/*/manifest.yaml на соответствие schema (M1-M10).
Exit codes: 0 — clean; 1 — есть errors; 2 — pyyaml не установлен.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Добавляем scripts/ в path для импорта _validate_common
sys.path.insert(0, str(Path(__file__).parent))

from _validate_common import (  # noqa: E402
    Issue,
    parse_yaml_file,
    require_yaml,
    format_issues,
)

PROFILES_ROOT_DEFAULT = Path("docs/overlays/profiles")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Validate profile manifests")
    parser.add_argument(
        "profile_dir",
        nargs="?",
        default=None,
        help="Path to single profile dir, or omit to validate all in docs/overlays/profiles/",
    )
    args = parser.parse_args(argv)

    require_yaml()

    if args.profile_dir:
        profile_dirs = [Path(args.profile_dir)]
    else:
        if not PROFILES_ROOT_DEFAULT.is_dir():
            print(f"ERROR: {PROFILES_ROOT_DEFAULT} не существует", file=sys.stderr)
            return 2
        profile_dirs = sorted(p for p in PROFILES_ROOT_DEFAULT.iterdir() if p.is_dir())

    if not profile_dirs:
        print(f"{PROFILES_ROOT_DEFAULT}/: OK (профилей нет — нечего валидировать)")
        return 0

    issues: list[Issue] = []
    # M1-M10 будут добавлены в следующих задачах

    if issues:
        print(format_issues(issues))
        errors = [i for i in issues if i.level == "error"]
        warnings = [i for i in issues if i.level == "warning"]
        print(f"\nErrors: {len(errors)} | Warnings: {len(warnings)}")
        return 1 if errors else 0

    print(f"Profiles: OK ({len(profile_dirs)} проверено)")
    print("\nErrors: 0 | Warnings: 0")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

Сделать исполняемым: `chmod +x scripts/validate-profile.py`

- [ ] **Step 4: Запустить тест — должен пройти**

```bash
bash scripts/test-validate-profile.sh
```

Expected: PASS — `--help` работает.

- [ ] **Step 5: Запустить validator на пустом profiles dir (профилей ещё нет)**

```bash
mkdir -p docs/overlays/profiles
python3 scripts/validate-profile.py
```

Expected: `Profiles: OK (профилей нет — нечего валидировать)`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add scripts/validate-profile.py scripts/test-validate-profile.sh docs/overlays/profiles/.gitkeep 2>/dev/null
[ ! -f docs/overlays/profiles/.gitkeep ] && touch docs/overlays/profiles/.gitkeep && git add docs/overlays/profiles/.gitkeep
git commit -m "feat(validate-profile): скелет + тест-харнесс [W2-T2]"
```

---

### Task 3: M1 — manifest.yaml присутствует

**Files:**
- Modify: `scripts/validate-profile.py`
- Modify: `scripts/test-validate-profile.sh`

- [ ] **Step 1: Failing-тест M1**

В `test-validate-profile.sh` перед `==> Results`:

```bash
# ===== M1: manifest.yaml present =====
echo ""
echo "==> M1: профиль без manifest.yaml даёт error"
TMP1="$(mktemp -d)"
mkdir -p "$TMP1/docs/overlays/profiles/no-manifest"
cd "$TMP1"

set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/no-manifest 2>&1)
RC=$?
set -e
assert "M1 exit 1 без manifest.yaml" "[ \"$RC\" = '1' ]"
assert "M1 сообщение про manifest.yaml" "echo \"$OUT\" | grep -q 'manifest.yaml not found\\|missing manifest.yaml'"
cd "$REPO_ROOT"
rm -rf "$TMP1"

echo ""
echo "==> M1: профиль с manifest.yaml проходит"
TMP1B="$(mktemp -d)"
mkdir -p "$TMP1B/docs/overlays/profiles/has-manifest"
cat > "$TMP1B/docs/overlays/profiles/has-manifest/manifest.yaml" <<'YAML'
schema_version: 1
name: has-manifest
description: Test
status: stub
subagents: { pm: core }
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
YAML
cd "$TMP1B"
set +e
python3 "$VALIDATOR" docs/overlays/profiles/has-manifest >/dev/null 2>&1
RC=$?
set -e
assert "M1 exit 0 с manifest.yaml" "[ \"$RC\" = '0' ]"
cd "$REPO_ROOT"
rm -rf "$TMP1B"
```

- [ ] **Step 2: Запустить — упадёт**

```bash
bash scripts/test-validate-profile.sh
```

Expected: FAIL на M1.

- [ ] **Step 3: Реализовать M1 в `validate-profile.py`**

Добавить функцию перед `def main`:

```python
def check_m1_manifest_present(profile_dir: Path) -> list[Issue]:
    """M1: профиль содержит manifest.yaml."""
    manifest_path = profile_dir / "manifest.yaml"
    if not manifest_path.exists():
        return [Issue(
            level="error",
            path=str(profile_dir) + "/",
            message="manifest.yaml not found",
        )]
    return []
```

В `main()` после `profile_dirs = ...`:

```python
    issues: list[Issue] = []
    for pd in profile_dirs:
        issues.extend(check_m1_manifest_present(pd))
```

- [ ] **Step 4: Запустить — должны пройти**

```bash
bash scripts/test-validate-profile.sh
```

Expected: PASS на M1.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-profile.py scripts/test-validate-profile.sh
git commit -m "feat(validate-profile): M1 — manifest.yaml present [W2-T3]"
```

---

### Task 4: M2 — обязательные поля manifest

**Files:**
- Modify: `scripts/validate-profile.py`
- Modify: `scripts/test-validate-profile.sh`

- [ ] **Step 1: Failing-тест M2**

```bash
# ===== M2: required fields =====
echo ""
echo "==> M2: manifest без обязательных полей"
TMP2="$(mktemp -d)"
mkdir -p "$TMP2/docs/overlays/profiles/incomplete"
cat > "$TMP2/docs/overlays/profiles/incomplete/manifest.yaml" <<'YAML'
name: incomplete
description: missing fields
YAML
cd "$TMP2"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/incomplete 2>&1)
RC=$?
set -e
assert "M2 exit 1 без обязательных полей" "[ \"$RC\" = '1' ]"
assert "M2 упоминает schema_version" "echo \"$OUT\" | grep -q 'schema_version'"
assert "M2 упоминает subagents" "echo \"$OUT\" | grep -q 'subagents'"
cd "$REPO_ROOT"
rm -rf "$TMP2"
```

- [ ] **Step 2: Запустить — упадёт**

```bash
bash scripts/test-validate-profile.sh
```

- [ ] **Step 3: Реализовать M2**

Добавить функции:

```python
REQUIRED_FIELDS = [
    "schema_version",
    "name",
    "description",
    "status",
    "subagents",
    "pipelines",
    "content_scaffold",
    "doc_root",
    "operations",
    "compatible_stacks",
]


def load_manifest(profile_dir: Path) -> dict | None:
    """Возвращает распарсенный manifest или None."""
    manifest_path = profile_dir / "manifest.yaml"
    if not manifest_path.exists():
        return None
    return parse_yaml_file(manifest_path)


def check_m2_required_fields(profile_dir: Path, manifest: dict | None) -> list[Issue]:
    """M2: обязательные поля присутствуют."""
    if manifest is None:
        return []  # M1 уже сообщил
    issues = []
    manifest_path = profile_dir / "manifest.yaml"
    for field in REQUIRED_FIELDS:
        if field not in manifest:
            issues.append(Issue(
                level="error",
                path=str(manifest_path),
                message=f"required field missing: {field}",
            ))
    return issues
```

В `main()` обновить цикл:

```python
    issues: list[Issue] = []
    for pd in profile_dirs:
        m1 = check_m1_manifest_present(pd)
        issues.extend(m1)
        if m1:
            continue  # без manifest нечего проверять
        manifest = load_manifest(pd)
        issues.extend(check_m2_required_fields(pd, manifest))
```

- [ ] **Step 4: Запустить тест — pass**

```bash
bash scripts/test-validate-profile.sh
```

Expected: PASS на M1 и M2.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-profile.py scripts/test-validate-profile.sh
git commit -m "feat(validate-profile): M2 — обязательные поля manifest [W2-T4]"
```

---

### Task 5: M3 — name совпадает с папкой

**Files:**
- Modify: `scripts/validate-profile.py`
- Modify: `scripts/test-validate-profile.sh`

- [ ] **Step 1: Failing-тест M3**

```bash
# ===== M3: name совпадает с dir =====
echo ""
echo "==> M3: name != dir"
TMP3="$(mktemp -d)"
mkdir -p "$TMP3/docs/overlays/profiles/foo"
cat > "$TMP3/docs/overlays/profiles/foo/manifest.yaml" <<'YAML'
schema_version: 1
name: bar
description: name != dir
status: stub
subagents: { pm: core }
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
YAML
cd "$TMP3"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/foo 2>&1)
RC=$?
set -e
assert "M3 exit 1 при name != dir" "[ \"$RC\" = '1' ]"
assert "M3 сообщение про name" "echo \"$OUT\" | grep -qE 'name.*foo|name.*bar|совпада'"
cd "$REPO_ROOT"
rm -rf "$TMP3"
```

- [ ] **Step 2: Запустить — упадёт**

```bash
bash scripts/test-validate-profile.sh
```

- [ ] **Step 3: Реализовать M3**

```python
def check_m3_name_matches_dir(profile_dir: Path, manifest: dict) -> list[Issue]:
    """M3: name в manifest совпадает с именем папки."""
    name = manifest.get("name")
    if name is None:
        return []  # M2 уже сообщил
    if name != profile_dir.name:
        return [Issue(
            level="error",
            path=str(profile_dir / "manifest.yaml"),
            message=f"name '{name}' не совпадает с именем папки '{profile_dir.name}'",
        )]
    return []
```

В `main()` после M2:

```python
        if manifest is not None:
            issues.extend(check_m3_name_matches_dir(pd, manifest))
```

- [ ] **Step 4: Запустить — pass**

```bash
bash scripts/test-validate-profile.sh
```

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-profile.py scripts/test-validate-profile.sh
git commit -m "feat(validate-profile): M3 — name совпадает с папкой [W2-T5]"
```

---

### Task 6: M4 — роли в AGENTS.md registry

**Files:**
- Modify: `scripts/validate-profile.py`
- Modify: `scripts/test-validate-profile.sh`

**Контекст:** AGENTS.md содержит таблицу «Каталог ролей»; имена парсятся regex'ом по строкам типа `| pm | ... |` или `| qa | ... |`. M4 проверяет, что все имена из `manifest.subagents:` объявлены в этой таблице.

- [ ] **Step 1: Failing-тест M4**

```bash
# ===== M4: subagents объявлены в AGENTS.md =====
echo ""
echo "==> M4: subagents с unknown role"
TMP4="$(mktemp -d)"
mkdir -p "$TMP4/docs/overlays/profiles/badrole"
# Минимальный AGENTS.md с реестром
cat > "$TMP4/AGENTS.md" <<'MD'
## Каталог ролей

| Имя | Описание |
|-----|----------|
| pm | PM |
| ba | BA |
MD
cat > "$TMP4/docs/overlays/profiles/badrole/manifest.yaml" <<'YAML'
schema_version: 1
name: badrole
description: ref to non-existent role
status: stub
subagents:
  pm: core
  unknownrole: optional
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
YAML
cd "$TMP4"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/badrole 2>&1)
RC=$?
set -e
assert "M4 exit 1 при unknown role" "[ \"$RC\" = '1' ]"
assert "M4 сообщение содержит unknownrole" "echo \"$OUT\" | grep -q 'unknownrole'"
cd "$REPO_ROOT"
rm -rf "$TMP4"
```

- [ ] **Step 2: Запустить — упадёт**

```bash
bash scripts/test-validate-profile.sh
```

- [ ] **Step 3: Реализовать M4**

```python
import re as _re


def collect_known_roles(repo_root: Path) -> set[str]:
    """Парсит AGENTS.md таблицу 'Каталог ролей', возвращает множество role names."""
    agents_md = repo_root / "AGENTS.md"
    if not agents_md.exists():
        return set()
    text = agents_md.read_text(encoding="utf-8")
    # Найти секцию '## Каталог ролей' и таблицу под ней
    match = _re.search(r"##\s*Каталог ролей\s*\n(.*?)(?=\n##|\Z)", text, _re.DOTALL)
    if not match:
        return set()
    table = match.group(1)
    roles = set()
    for line in table.splitlines():
        line = line.strip()
        if not line.startswith("|") or "---" in line or not line.endswith("|"):
            continue
        cells = [c.strip() for c in line.split("|")[1:-1]]
        if not cells or cells[0].lower() in ("имя", "name"):
            continue
        roles.add(cells[0])
    return roles


def check_m4_subagent_names(profile_dir: Path, manifest: dict, known_roles: set[str]) -> list[Issue]:
    """M4: имена ролей в subagents объявлены в AGENTS.md."""
    subagents = manifest.get("subagents") or {}
    if not isinstance(subagents, dict):
        return []
    issues = []
    for role in subagents:
        if role not in known_roles:
            issues.append(Issue(
                level="error",
                path=str(profile_dir / "manifest.yaml"),
                message=f"роль '{role}' не объявлена в AGENTS.md (Каталог ролей)",
            ))
    return issues
```

В `main()` после load_manifest:

```python
    repo_root = Path.cwd()  # запуск из корня репо
    known_roles = collect_known_roles(repo_root)
    # ... в цикле:
    if manifest is not None:
        issues.extend(check_m3_name_matches_dir(pd, manifest))
        issues.extend(check_m4_subagent_names(pd, manifest, known_roles))
```

- [ ] **Step 4: Запустить — pass**

```bash
bash scripts/test-validate-profile.sh
```

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-profile.py scripts/test-validate-profile.sh
git commit -m "feat(validate-profile): M4 — роли объявлены в AGENTS.md [W2-T6]"
```

---

### Task 7: M5 — pipelines существуют в commands/pipelines/

**Files:**
- Modify: `scripts/validate-profile.py`
- Modify: `scripts/test-validate-profile.sh`

- [ ] **Step 1: Failing-тест M5**

```bash
# ===== M5: pipelines существуют =====
echo ""
echo "==> M5: pipeline без commands/pipelines/<name>.md"
TMP5="$(mktemp -d)"
mkdir -p "$TMP5/docs/overlays/profiles/badpipe"
mkdir -p "$TMP5/.claude/plugins/project/commands/pipelines"
touch "$TMP5/.claude/plugins/project/commands/pipelines/known-pipe.md"
cat > "$TMP5/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP5/docs/overlays/profiles/badpipe/manifest.yaml" <<'YAML'
schema_version: 1
name: badpipe
description: pipeline doesn't exist
status: stub
subagents: { pm: core }
pipelines:
  known-pipe: enabled
  unknown-pipe: enabled
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
YAML
cd "$TMP5"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/badpipe 2>&1)
RC=$?
set -e
assert "M5 exit 1 при unknown pipeline" "[ \"$RC\" = '1' ]"
assert "M5 содержит unknown-pipe" "echo \"$OUT\" | grep -q 'unknown-pipe'"
cd "$REPO_ROOT"
rm -rf "$TMP5"
```

- [ ] **Step 2: Запустить — упадёт**

- [ ] **Step 3: Реализовать M5**

```python
def collect_known_pipelines(repo_root: Path) -> set[str]:
    """Возвращает множество pipeline names из commands/pipelines/*.md."""
    pipelines_dir = repo_root / ".claude" / "plugins" / "project" / "commands" / "pipelines"
    if not pipelines_dir.is_dir():
        return set()
    return {p.stem for p in pipelines_dir.glob("*.md")}


def check_m5_pipeline_names(profile_dir: Path, manifest: dict, known_pipelines: set[str]) -> list[Issue]:
    """M5: pipelines существуют в commands/pipelines/ или явно disabled."""
    pipelines = manifest.get("pipelines") or {}
    if not isinstance(pipelines, dict):
        return []
    issues = []
    for pipe, status in pipelines.items():
        if status == "disabled":
            continue  # disabled = stub, OK без файла
        if pipe not in known_pipelines:
            issues.append(Issue(
                level="error",
                path=str(profile_dir / "manifest.yaml"),
                message=f"pipeline '{pipe}' не существует (нет commands/pipelines/{pipe}.md)",
            ))
    return issues
```

В `main()`:

```python
    known_pipelines = collect_known_pipelines(repo_root)
    # ... в цикле:
        issues.extend(check_m5_pipeline_names(pd, manifest, known_pipelines))
```

- [ ] **Step 4: Запустить — pass**

```bash
bash scripts/test-validate-profile.sh
```

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-profile.py scripts/test-validate-profile.sh
git commit -m "feat(validate-profile): M5 — pipelines существуют [W2-T7]"
```

---

### Task 8: M6 — enum-значения subagents/pipelines

**Files:**
- Modify: `scripts/validate-profile.py`
- Modify: `scripts/test-validate-profile.sh`

- [ ] **Step 1: Failing-тест M6**

```bash
# ===== M6: enum status =====
echo ""
echo "==> M6: subagents.X не из enum"
TMP6="$(mktemp -d)"
mkdir -p "$TMP6/docs/overlays/profiles/badenum"
cat > "$TMP6/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP6/docs/overlays/profiles/badenum/manifest.yaml" <<'YAML'
schema_version: 1
name: badenum
description: bad enum
status: stub
subagents:
  pm: active
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
YAML
cd "$TMP6"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/badenum 2>&1)
RC=$?
set -e
assert "M6 exit 1 при невалидном enum" "[ \"$RC\" = '1' ]"
assert "M6 содержит 'active'" "echo \"$OUT\" | grep -q 'active'"
cd "$REPO_ROOT"
rm -rf "$TMP6"
```

- [ ] **Step 2: Запустить — упадёт**

- [ ] **Step 3: Реализовать M6**

```python
SUBAGENT_STATUSES = {"core", "optional", "disabled"}
PIPELINE_STATUSES = {"enabled", "optional", "disabled"}


def check_m6_status_enums(profile_dir: Path, manifest: dict) -> list[Issue]:
    """M6: статусы subagents и pipelines — из enum'а."""
    issues = []
    manifest_path = str(profile_dir / "manifest.yaml")
    subagents = manifest.get("subagents") or {}
    if isinstance(subagents, dict):
        for role, status in subagents.items():
            if status not in SUBAGENT_STATUSES:
                issues.append(Issue(
                    level="error",
                    path=manifest_path,
                    message=f"subagents.{role} = '{status}' (ожидается одно из {sorted(SUBAGENT_STATUSES)})",
                ))
    pipelines = manifest.get("pipelines") or {}
    if isinstance(pipelines, dict):
        for pipe, status in pipelines.items():
            if status not in PIPELINE_STATUSES:
                issues.append(Issue(
                    level="error",
                    path=manifest_path,
                    message=f"pipelines.{pipe} = '{status}' (ожидается одно из {sorted(PIPELINE_STATUSES)})",
                ))
    return issues
```

В `main()`:

```python
        issues.extend(check_m6_status_enums(pd, manifest))
```

- [ ] **Step 4: Pass**

```bash
bash scripts/test-validate-profile.sh
```

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-profile.py scripts/test-validate-profile.sh
git commit -m "feat(validate-profile): M6 — enum статусы [W2-T8]"
```

---

### Task 9: M7 — paths существуют (content_scaffold, doc_root)

**Files:**
- Modify: `scripts/validate-profile.py`
- Modify: `scripts/test-validate-profile.sh`

- [ ] **Step 1: Failing-тест M7**

```bash
# ===== M7: paths существуют =====
echo ""
echo "==> M7: content_scaffold path missing"
TMP7="$(mktemp -d)"
mkdir -p "$TMP7/docs/overlays/profiles/badpath"
cat > "$TMP7/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP7/docs/overlays/profiles/badpath/manifest.yaml" <<'YAML'
schema_version: 1
name: badpath
description: missing scaffold dir
status: stable
subagents: { pm: core }
pipelines: {}
content_scaffold: nonexistent/
doc_root: nonexistent.yaml
operations: []
compatible_stacks: []
YAML
cd "$TMP7"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/badpath 2>&1)
RC=$?
set -e
assert "M7 exit 1 при missing path (status: stable)" "[ \"$RC\" = '1' ]"
assert "M7 содержит content_scaffold" "echo \"$OUT\" | grep -q 'content_scaffold'"
cd "$REPO_ROOT"
rm -rf "$TMP7"

# stub-профиль с missing path — НЕ error (stub'ы могут иметь пустые paths)
echo "==> M7: stub-профиль с пустым path — OK"
TMP7B="$(mktemp -d)"
mkdir -p "$TMP7B/docs/overlays/profiles/stubok"
cat > "$TMP7B/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP7B/docs/overlays/profiles/stubok/manifest.yaml" <<'YAML'
schema_version: 1
name: stubok
description: stub
status: stub
subagents: { pm: core }
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
YAML
cd "$TMP7B"
set +e
python3 "$VALIDATOR" docs/overlays/profiles/stubok >/dev/null 2>&1
RC=$?
set -e
assert "M7 stub: exit 0 даже с placeholder paths" "[ \"$RC\" = '0' ]"
cd "$REPO_ROOT"
rm -rf "$TMP7B"
```

- [ ] **Step 2: Запустить — упадёт**

- [ ] **Step 3: Реализовать M7**

```python
def check_m7_paths_exist(profile_dir: Path, manifest: dict) -> list[Issue]:
    """M7: content_scaffold и doc_root paths существуют (для status != stub)."""
    if manifest.get("status") == "stub":
        return []  # для stub'ов не проверяем
    issues = []
    manifest_path = str(profile_dir / "manifest.yaml")
    for field in ["content_scaffold", "doc_root"]:
        path_str = manifest.get(field)
        if not path_str or path_str == "./":
            continue  # ./ — допустимый плейсхолдер для stub'ов
        target = profile_dir / path_str
        if not target.exists():
            issues.append(Issue(
                level="error",
                path=manifest_path,
                message=f"{field} '{path_str}' не существует (искал: {target})",
            ))
    return issues
```

В `main()`:

```python
        issues.extend(check_m7_paths_exist(pd, manifest))
```

- [ ] **Step 4: Pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-profile.py scripts/test-validate-profile.sh
git commit -m "feat(validate-profile): M7 — content_scaffold и doc_root существуют [W2-T9]"
```

---

### Task 10: M8/M9/M10 — warnings (on_value targets, compatible_stacks, status mismatch)

**Files:**
- Modify: `scripts/validate-profile.py`
- Modify: `scripts/test-validate-profile.sh`

- [ ] **Step 1: Failing-тесты для M8, M9, M10**

```bash
# ===== M8: on_value мутации валидны =====
echo ""
echo "==> M8: on_value targets unknown subagent"
TMP8="$(mktemp -d)"
mkdir -p "$TMP8/docs/overlays/profiles/m8test"
cat > "$TMP8/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP8/docs/overlays/profiles/m8test/manifest.yaml" <<'YAML'
schema_version: 1
name: m8test
description: bad on_value
status: stub
subagents: { pm: core }
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
init_prompts:
  - id: foo
    prompt: "?"
    type: enum
    choices: [a]
    default: a
    on_value:
      a:
        subagents.unknown_role: core
YAML
cd "$TMP8"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/m8test 2>&1)
RC=$?
set -e
assert "M8 exit 0 (warning, не error)" "[ \"$RC\" = '0' ]"
assert "M8 содержит warning + unknown_role" "echo \"$OUT\" | grep -q 'warning' && echo \"$OUT\" | grep -q 'unknown_role'"
cd "$REPO_ROOT"
rm -rf "$TMP8"

# ===== M9: compatible_stacks несуществующие =====
echo ""
echo "==> M9: compatible_stacks с несуществующим overlay"
TMP9="$(mktemp -d)"
mkdir -p "$TMP9/docs/overlays/profiles/m9test"
mkdir -p "$TMP9/docs/overlays/known-stack"
cat > "$TMP9/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP9/docs/overlays/profiles/m9test/manifest.yaml" <<'YAML'
schema_version: 1
name: m9test
description: unknown stack
status: stub
subagents: { pm: core }
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: [known-stack, unknown-stack]
YAML
cd "$TMP9"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/m9test 2>&1)
RC=$?
set -e
assert "M9 exit 0 (warning)" "[ \"$RC\" = '0' ]"
assert "M9 warning про unknown-stack" "echo \"$OUT\" | grep -q 'warning' && echo \"$OUT\" | grep -q 'unknown-stack'"
cd "$REPO_ROOT"
rm -rf "$TMP9"

# ===== M10: status mismatch =====
echo ""
echo "==> M10: status: stable + пустой scaffold"
TMP10="$(mktemp -d)"
mkdir -p "$TMP10/docs/overlays/profiles/m10test"
mkdir -p "$TMP10/docs/overlays/profiles/m10test/empty-scaffold"
cat > "$TMP10/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP10/docs/overlays/profiles/m10test/empty-doc-root.yaml" <<'YAML'
title: t
properties: []
filterProperties: []
YAML
cat > "$TMP10/docs/overlays/profiles/m10test/manifest.yaml" <<'YAML'
schema_version: 1
name: m10test
description: stable but empty
status: stable
subagents: { pm: core }
pipelines: {}
content_scaffold: empty-scaffold/
doc_root: empty-doc-root.yaml
operations: []
compatible_stacks: []
YAML
cd "$TMP10"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/m10test 2>&1)
RC=$?
set -e
assert "M10 exit 0 (warning)" "[ \"$RC\" = '0' ]"
assert "M10 warning про stable + empty" "echo \"$OUT\" | grep -q 'warning' && echo \"$OUT\" | grep -qE 'stable|empty'"
cd "$REPO_ROOT"
rm -rf "$TMP10"
```

- [ ] **Step 2: Запустить — должны упасть**

- [ ] **Step 3: Реализовать M8/M9/M10**

```python
def check_m8_on_value_targets(profile_dir: Path, manifest: dict) -> list[Issue]:
    """M8 (warning): on_value мутации указывают на существующие ключи манифеста."""
    issues = []
    manifest_path = str(profile_dir / "manifest.yaml")
    subagents = manifest.get("subagents") or {}
    pipelines = manifest.get("pipelines") or {}
    init_prompts = manifest.get("init_prompts") or []
    if not isinstance(init_prompts, list):
        return []
    for p in init_prompts:
        if not isinstance(p, dict):
            continue
        on_value = p.get("on_value") or {}
        if not isinstance(on_value, dict):
            continue
        for choice, mutations in on_value.items():
            if not isinstance(mutations, dict):
                continue
            for key in mutations:
                if "." not in key:
                    continue
                section, name = key.split(".", 1)
                if section == "subagents" and name not in subagents:
                    issues.append(Issue(
                        level="warning",
                        path=manifest_path,
                        message=f"init_prompts.{p.get('id', '?')}.on_value.{choice}: '{key}' мутирует unknown subagent '{name}'",
                    ))
                elif section == "pipelines" and name not in pipelines:
                    issues.append(Issue(
                        level="warning",
                        path=manifest_path,
                        message=f"init_prompts.{p.get('id', '?')}.on_value.{choice}: '{key}' мутирует unknown pipeline '{name}'",
                    ))
    return issues


def check_m9_compatible_stacks(profile_dir: Path, manifest: dict, repo_root: Path) -> list[Issue]:
    """M9 (warning): compatible_stacks упоминают существующие overlay'и."""
    stacks = manifest.get("compatible_stacks") or []
    if not isinstance(stacks, list):
        return []
    issues = []
    overlays_root = repo_root / "docs" / "overlays"
    manifest_path = str(profile_dir / "manifest.yaml")
    for s in stacks:
        if s == "*":
            continue
        if not (overlays_root / s).is_dir():
            issues.append(Issue(
                level="warning",
                path=manifest_path,
                message=f"compatible_stacks: '{s}' не существует ({overlays_root}/{s} не найдена)",
            ))
    return issues


def check_m10_status_mismatch(profile_dir: Path, manifest: dict) -> list[Issue]:
    """M10 (warning): status: stable + пустой content_scaffold ИЛИ status: stub + непустой."""
    status = manifest.get("status")
    scaffold = manifest.get("content_scaffold")
    if not scaffold or scaffold == "./":
        scaffold_empty = True
    else:
        target = profile_dir / scaffold
        scaffold_empty = not target.is_dir() or not any(target.iterdir())
    manifest_path = str(profile_dir / "manifest.yaml")
    if status == "stable" and scaffold_empty:
        return [Issue(
            level="warning",
            path=manifest_path,
            message=f"status: stable, но content_scaffold пустой — несоответствие",
        )]
    if status == "stub" and not scaffold_empty:
        return [Issue(
            level="warning",
            path=manifest_path,
            message=f"status: stub, но content_scaffold непустой — возможно status должен быть stable",
        )]
    return []
```

В `main()`:

```python
        issues.extend(check_m8_on_value_targets(pd, manifest))
        issues.extend(check_m9_compatible_stacks(pd, manifest, repo_root))
        issues.extend(check_m10_status_mismatch(pd, manifest))
```

- [ ] **Step 4: Pass**

```bash
bash scripts/test-validate-profile.sh
```

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-profile.py scripts/test-validate-profile.sh
git commit -m "feat(validate-profile): M8/M9/M10 — warnings про on_value, compatible_stacks, status mismatch [W2-T10]"
```

---

## Phase 2 — apply-overlay.sh refactor (TDD)

### Task 11: --dry-run флаг для текущего marker-flow

**Files:**
- Modify: `scripts/apply-overlay.sh`
- Modify: `scripts/test-template.sh`

- [ ] **Step 1: Прочитать текущий `apply-overlay.sh` и понять структуру**

```bash
cat scripts/apply-overlay.sh
```

(Убедиться, что markers-логика осталась как была.)

- [ ] **Step 2: Добавить парсинг флагов `--dry-run`, `--profile`, `--force`**

В начало `apply-overlay.sh` (после `set -euo pipefail`):

```bash
DRY_RUN=0
PROFILE_MODE=0
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --profile) PROFILE_MODE=1; shift ;;
    --force)   FORCE=1; shift ;;
    --init)    INIT_MODE=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: apply-overlay.sh [--profile] [--force] [--dry-run] [--init] <overlay-name>

  --profile     Apply profile-overlay from docs/overlays/profiles/<name>/
                (uses manifest.yaml operations: add/replace/delete)
  --force       Disable strict delete-non-empty check
  --dry-run     Print plan without executing
  --init        Skip strict checks (called from init.sh on fresh template)
EOF
      exit 0
      ;;
    -*) echo "Unknown flag: $1" >&2; exit 1 ;;
    *) OVERLAY_NAME="$1"; shift ;;
  esac
done

[[ -z "${OVERLAY_NAME:-}" ]] && { echo "ERROR: overlay name required" >&2; exit 1; }
```

- [ ] **Step 3: Добавить test-template.sh ассерт для --dry-run (markers-flow)**

В `test-template.sh` добавить отдельный блок:

```bash
echo "==> T-DRYRUN: --dry-run для markers-flow"
TMP_DRY=$(mktemp -d)
rsync -a --exclude='.git' --exclude='.worktrees' . "$TMP_DRY/"
cd "$TMP_DRY"
set +e
OUT=$(bash scripts/apply-overlay.sh --dry-run naumen-smp 2>&1)
RC=$?
set -e
assert "T-DRYRUN: exit 0" "[ \"$RC\" = '0' ]"
assert "T-DRYRUN: prints DRY-RUN" "echo \"$OUT\" | grep -q 'DRY-RUN'"
cd "$REPO_ROOT"
rm -rf "$TMP_DRY"
```

- [ ] **Step 4: В существующих markers-функциях добавить guards под --dry-run**

В функциях, которые модифицируют файлы (`replace_in_file`, `append_to_file`, и т.д.) добавить:

```bash
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[DRY-RUN] would modify: $target_file"
  return 0
fi
# ... existing logic
```

В начало основного flow:

```bash
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN MODE — no changes will be made"
fi
```

- [ ] **Step 5: Прогнать `test-template.sh`**

```bash
bash scripts/test-template.sh
```

Expected: T-DRYRUN зелёный; T1-T9 (Wave 1) продолжают работать.

- [ ] **Step 6: Commit**

```bash
git add scripts/apply-overlay.sh scripts/test-template.sh
git commit -m "feat(apply-overlay): --dry-run для markers-flow [W2-T11]"
```

---

### Task 12: --profile флаг — load manifest, validate (no ops yet)

**Files:**
- Modify: `scripts/apply-overlay.sh`

- [ ] **Step 1: Добавить функцию `apply_profile_overlay`**

В `apply-overlay.sh`:

```bash
PROFILES_ROOT="docs/overlays/profiles"

apply_profile_overlay() {
  local name="$1"
  local profile_dir="$PROFILES_ROOT/$name"

  [[ ! -d "$profile_dir" ]] && {
    echo "ERROR: profile '$name' не существует. Доступные:" >&2
    ls "$PROFILES_ROOT/" 2>/dev/null >&2 || echo "(нет профилей)" >&2
    exit 1
  }

  [[ ! -f "$profile_dir/manifest.yaml" ]] && {
    echo "ERROR: $profile_dir/manifest.yaml не найден" >&2
    exit 1
  }

  echo "Profile: $name"

  # validate-profile перед применением
  if [[ "${INIT_MODE:-0}" -ne 1 ]]; then
    python3 scripts/validate-profile.py "$profile_dir" >/dev/null 2>&1 || {
      echo "ERROR: validate-profile.py упал на $name" >&2
      python3 scripts/validate-profile.py "$profile_dir" >&2
      exit 1
    }
  fi

  # Прочитать status
  local status
  status=$(python3 -c "import yaml; m=yaml.safe_load(open('$profile_dir/manifest.yaml')); print(m.get('status', 'unknown'))")
  echo "Status: $status"

  if [[ "$status" == "stub" ]]; then
    echo "⚠ stub-профиль: scaffold не определён, профиль готов к расширению в Wave 3+"
  fi

  # Operations будут добавлены в T13-T15
  echo "(operations execution TBD — see W2-T13/T14/T15)"
}
```

В основной flow:

```bash
if [[ "$PROFILE_MODE" -eq 1 ]]; then
  apply_profile_overlay "$OVERLAY_NAME"
  exit 0
fi
# ... existing markers-flow
```

- [ ] **Step 2: Sanity тест (вручную, до создания профилей)**

```bash
# Должен сказать "no profiles"
bash scripts/apply-overlay.sh --profile project 2>&1 | head -5
```

Expected: ERROR profile 'project' не существует — т.к. профилей ещё нет.

- [ ] **Step 3: Commit**

```bash
git add scripts/apply-overlay.sh
git commit -m "feat(apply-overlay): --profile flag, load manifest, validate-profile gate [W2-T12]"
```

---

### Task 13: op: add (с unit-test)

**Files:**
- Modify: `scripts/apply-overlay.sh`
- Modify: `scripts/test-template.sh`

- [ ] **Step 1: Добавить op-execution loop в `apply_profile_overlay`**

```bash
apply_profile_overlay() {
  # ... (T12 код выше) ...

  # Прочитать operations
  local ops_count
  ops_count=$(python3 -c "import yaml; m=yaml.safe_load(open('$profile_dir/manifest.yaml')); print(len(m.get('operations') or []))")

  if [[ "$ops_count" -eq 0 ]]; then
    echo "No operations defined — done."
    return 0
  fi

  echo "Operations to execute: $ops_count"

  for i in $(seq 0 $((ops_count - 1))); do
    local op source target reason
    op=$(python3 -c "import yaml; m=yaml.safe_load(open('$profile_dir/manifest.yaml')); print(m['operations'][$i].get('op', ''))")
    source=$(python3 -c "import yaml; m=yaml.safe_load(open('$profile_dir/manifest.yaml')); print(m['operations'][$i].get('source', ''))")
    target=$(python3 -c "import yaml; m=yaml.safe_load(open('$profile_dir/manifest.yaml')); print(m['operations'][$i].get('target', ''))")
    reason=$(python3 -c "import yaml; m=yaml.safe_load(open('$profile_dir/manifest.yaml')); print(m['operations'][$i].get('reason', ''))")

    case "$op" in
      add)     op_add "$profile_dir" "$source" "$target" "$reason" ;;
      replace) op_replace "$profile_dir" "$source" "$target" "$reason" ;;
      delete)  op_delete "$target" "$reason" ;;
      *)       echo "ERROR: unknown op '$op'" >&2; exit 1 ;;
    esac
  done
}

op_add() {
  local profile_dir="$1" source="$2" target="$3" reason="$4"
  local source_path="$profile_dir/$source"

  echo "[ADD] $source → $target  ($reason)"

  if [[ ! -e "$source_path" ]]; then
    echo "ERROR: source '$source_path' не существует" >&2
    exit 1
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [DRY-RUN] would copy"
    return 0
  fi

  mkdir -p "$target"
  if [[ -d "$source_path" ]]; then
    cp -r "$source_path"/* "$target"/ 2>/dev/null || true
    cp -r "$source_path"/.[!.]* "$target"/ 2>/dev/null || true  # hidden files
  else
    cp "$source_path" "$target"
  fi
  echo "  ✓ added"
}
```

- [ ] **Step 2: T-OP-ADD ассерт в test-template.sh**

```bash
echo "==> T-OP-ADD: op: add копирует файлы"
TMP_ADD=$(mktemp -d)
mkdir -p "$TMP_ADD/docs/overlays/profiles/test-add/scaffold"
echo "test content" > "$TMP_ADD/docs/overlays/profiles/test-add/scaffold/article.md"
mkdir -p "$TMP_ADD/.claude/plugins/project/commands/pipelines"
mkdir -p "$TMP_ADD/scripts"
cp scripts/_validate_common.py scripts/validate-profile.py scripts/apply-overlay.sh "$TMP_ADD/scripts/"
chmod +x "$TMP_ADD/scripts/apply-overlay.sh" "$TMP_ADD/scripts/validate-profile.py"
cat > "$TMP_ADD/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP_ADD/docs/overlays/profiles/test-add/manifest.yaml" <<'YAML'
schema_version: 1
name: test-add
description: T-OP-ADD test
status: stable
subagents: { pm: core }
pipelines: {}
content_scaffold: scaffold/
doc_root: ./
operations:
  - op: add
    source: scaffold/
    target: content/
    reason: "T-OP-ADD"
compatible_stacks: []
YAML
mkdir -p "$TMP_ADD/content"
cd "$TMP_ADD"
set +e
bash scripts/apply-overlay.sh --profile --init test-add >/dev/null 2>&1
RC=$?
set -e
assert "T-OP-ADD: exit 0" "[ \"$RC\" = '0' ]"
assert "T-OP-ADD: file copied" "[ -f content/article.md ]"
cd "$REPO_ROOT"
rm -rf "$TMP_ADD"
```

- [ ] **Step 3: Запустить test-template.sh**

```bash
bash scripts/test-template.sh
```

Expected: T-OP-ADD зелёный.

- [ ] **Step 4: Commit**

```bash
git add scripts/apply-overlay.sh scripts/test-template.sh
git commit -m "feat(apply-overlay): op: add для profile-mode [W2-T13]"
```

---

### Task 14: op: replace (с unit-test)

**Files:**
- Modify: `scripts/apply-overlay.sh`
- Modify: `scripts/test-template.sh`

- [ ] **Step 1: Реализовать `op_replace`**

```bash
op_replace() {
  local profile_dir="$1" source="$2" target="$3" reason="$4"
  local source_path="$profile_dir/$source"

  echo "[REPLACE] $source → $target  ($reason)"

  [[ ! -f "$source_path" ]] && { echo "ERROR: source '$source_path' не существует" >&2; exit 1; }

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [DRY-RUN] would overwrite"
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  cp -f "$source_path" "$target"
  echo "  ✓ replaced"
}
```

- [ ] **Step 2: T-OP-REPLACE ассерт**

```bash
echo "==> T-OP-REPLACE: op: replace перезаписывает"
TMP_REP=$(mktemp -d)
mkdir -p "$TMP_REP/docs/overlays/profiles/test-rep"
mkdir -p "$TMP_REP/.claude/plugins/project/commands/pipelines"
mkdir -p "$TMP_REP/scripts" "$TMP_REP/content"
cp scripts/_validate_common.py scripts/validate-profile.py scripts/apply-overlay.sh "$TMP_REP/scripts/"
chmod +x "$TMP_REP/scripts/apply-overlay.sh" "$TMP_REP/scripts/validate-profile.py"
echo "old" > "$TMP_REP/content/file.txt"
echo "new" > "$TMP_REP/docs/overlays/profiles/test-rep/file.txt"
cat > "$TMP_REP/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP_REP/docs/overlays/profiles/test-rep/manifest.yaml" <<'YAML'
schema_version: 1
name: test-rep
description: replace test
status: stable
subagents: { pm: core }
pipelines: {}
content_scaffold: ./
doc_root: file.txt
operations:
  - op: replace
    source: file.txt
    target: content/file.txt
    reason: "T-OP-REPLACE"
compatible_stacks: []
YAML
cd "$TMP_REP"
bash scripts/apply-overlay.sh --profile --init test-rep >/dev/null 2>&1
RC=$?
assert "T-OP-REPLACE: file replaced" "grep -q 'new' content/file.txt"
cd "$REPO_ROOT"
rm -rf "$TMP_REP"
```

- [ ] **Step 3: Запустить test-template.sh — pass**

- [ ] **Step 4: Commit**

```bash
git add scripts/apply-overlay.sh scripts/test-template.sh
git commit -m "feat(apply-overlay): op: replace [W2-T14]"
```

---

### Task 15: op: delete + strict-non-empty + --force

**Files:**
- Modify: `scripts/apply-overlay.sh`
- Modify: `scripts/test-template.sh`

- [ ] **Step 1: Реализовать `op_delete` со strict-логикой**

```bash
# Проверяет, что target можно удалить безопасно (только baseline content)
is_safe_to_delete() {
  local target="$1"
  [[ ! -e "$target" ]] && return 0  # уже нет — OK

  if [[ -f "$target" ]]; then
    # Файл: безопасно если плейсхолдер или пустой
    [[ ! -s "$target" ]] && return 0  # empty file
    grep -q '{{' "$target" && return 0  # placeholder
    return 1
  fi

  if [[ -d "$target" ]]; then
    # Папка: безопасно если содержит только _index.md (с placeholder/baseline) и .gitkeep
    local f
    while IFS= read -r f; do
      local base
      base=$(basename "$f")
      [[ "$base" == ".gitkeep" ]] && continue
      [[ "$base" == "_index.md" ]] && {
        # _index.md baseline — без content вне frontmatter
        # heuristic: если файл < 500 байт ИЛИ содержит {{ — baseline
        [[ ! -s "$f" || $(stat -f%z "$f" 2>/dev/null || stat -c%s "$f") -lt 500 ]] && continue
        grep -q '{{' "$f" && continue
        return 1  # _index.md содержательный
      }
      return 1  # любой другой файл = non-baseline
    done < <(find "$target" -type f)
    return 0
  fi

  return 1
}

op_delete() {
  local target="$1" reason="$2"

  echo "[DELETE] $target  ($reason)"

  [[ ! -e "$target" ]] && {
    echo "  ✓ already absent"
    return 0
  }

  if [[ "$FORCE" -eq 1 ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [DRY-RUN] would force-delete (force=1)"
      return 0
    fi
    rm -rf "$target"
    echo "  ✓ force-deleted"
    return 0
  fi

  if is_safe_to_delete "$target"; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [DRY-RUN] safe to delete"
      return 0
    fi
    rm -rf "$target"
    echo "  ✓ deleted (was baseline/empty)"
  else
    echo "  ⚠ REFUSED: $target содержит non-baseline content"
    echo "    Use --force to override; use --dry-run to preview"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [DRY-RUN] WOULD REFUSE"
      return 0
    fi
    exit 1
  fi
}
```

- [ ] **Step 2: T-OP-DELETE ассерты**

```bash
echo "==> T-OP-DELETE: пустая папка удаляется"
TMP_DEL=$(mktemp -d)
mkdir -p "$TMP_DEL/docs/overlays/profiles/test-del" "$TMP_DEL/content/empty-dir" "$TMP_DEL/.claude/plugins/project/commands/pipelines" "$TMP_DEL/scripts"
cp scripts/_validate_common.py scripts/validate-profile.py scripts/apply-overlay.sh "$TMP_DEL/scripts/"
chmod +x "$TMP_DEL/scripts/apply-overlay.sh" "$TMP_DEL/scripts/validate-profile.py"
cat > "$TMP_DEL/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP_DEL/docs/overlays/profiles/test-del/manifest.yaml" <<'YAML'
schema_version: 1
name: test-del
description: delete test
status: stable
subagents: { pm: core }
pipelines: {}
content_scaffold: ./
doc_root: ./
operations:
  - op: delete
    target: content/empty-dir/
    reason: "T-OP-DELETE empty"
compatible_stacks: []
YAML
cd "$TMP_DEL"
bash scripts/apply-overlay.sh --profile --init test-del >/dev/null 2>&1
RC=$?
assert "T-OP-DELETE: empty dir удалена" "[ ! -d content/empty-dir ]"
cd "$REPO_ROOT"
rm -rf "$TMP_DEL"

echo "==> T-OP-DELETE-STRICT: non-empty refuse без --force"
TMP_DELS=$(mktemp -d)
mkdir -p "$TMP_DELS/docs/overlays/profiles/test-dels" "$TMP_DELS/content/full-dir" "$TMP_DELS/.claude/plugins/project/commands/pipelines" "$TMP_DELS/scripts"
cp scripts/_validate_common.py scripts/validate-profile.py scripts/apply-overlay.sh "$TMP_DELS/scripts/"
chmod +x "$TMP_DELS/scripts/apply-overlay.sh" "$TMP_DELS/scripts/validate-profile.py"
echo "real content here, much longer than 500 bytes — long article body that simulates a real piece of content the user has written and would not want to lose without confirmation. This text needs to be at least 500 characters long to bypass the size heuristic in is_safe_to_delete. Padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding." > "$TMP_DELS/content/full-dir/_index.md"
echo "more real content" > "$TMP_DELS/content/full-dir/article.md"
cat > "$TMP_DELS/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP_DELS/docs/overlays/profiles/test-dels/manifest.yaml" <<'YAML'
schema_version: 1
name: test-dels
description: delete strict
status: stable
subagents: { pm: core }
pipelines: {}
content_scaffold: ./
doc_root: ./
operations:
  - op: delete
    target: content/full-dir/
    reason: "T-OP-DELETE-STRICT"
compatible_stacks: []
YAML
cd "$TMP_DELS"
set +e
bash scripts/apply-overlay.sh --profile test-dels >/dev/null 2>&1
RC=$?
set -e
assert "T-OP-DELETE-STRICT: refuses без --force" "[ \"$RC\" != '0' ]"
assert "T-OP-DELETE-STRICT: full-dir всё ещё там" "[ -d content/full-dir ]"

# С --force
bash scripts/apply-overlay.sh --profile --force test-dels >/dev/null 2>&1
RC=$?
assert "T-OP-DELETE-STRICT: --force удаляет" "[ ! -d content/full-dir ]"
cd "$REPO_ROOT"
rm -rf "$TMP_DELS"
```

- [ ] **Step 3: Запустить test-template.sh — pass**

```bash
bash scripts/test-template.sh
```

- [ ] **Step 4: Commit**

```bash
git add scripts/apply-overlay.sh scripts/test-template.sh
git commit -m "feat(apply-overlay): op: delete + strict-non-empty + --force [W2-T15]"
```

---

## Phase 3 — Profile manifests (project + kb-team baseline; 5 stubs)

### Task 16: Создать `project` profile manifest + scaffold

**Files:**
- Create: `docs/overlays/profiles/project/manifest.yaml`
- Create: `docs/overlays/profiles/project/doc-root.yaml`
- Create: `docs/overlays/profiles/project/content-scaffold/...` (полный scaffold)
- Create: `docs/overlays/profiles/project/agent-overrides/.gitkeep`

- [ ] **Step 1: Создать manifest.yaml для `project`**

```yaml
# docs/overlays/profiles/project/manifest.yaml
schema_version: 1
name: project
description: Delivery-проект (Researcher → BA → SA → Dev → DevOps цепочка)
audience: PM, команда разработки
status: stable

subagents:
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

pipelines:
  project-planning: enabled
  ba-acceptance: enabled
  critical-path: optional
  scrum-agile: disabled

content_scaffold: content-scaffold/
doc_root: doc-root.yaml

operations:
  - op: add
    source: content-scaffold/
    target: content/
    reason: "Базовый scaffold project-профиля"
  - op: replace
    source: doc-root.yaml
    target: content/.doc-root.yaml
    reason: "Профильная схема properties"

init_prompts:
  - id: compliance_domain
    prompt: "Проект под compliance-надзором?"
    type: enum
    choices: [none, 152-fz, iso27001, other]
    default: none
    on_value:
      152-fz: { subagents.compliance: core }
      iso27001: { subagents.compliance: core }
      other: { subagents.compliance: core }

compatible_stacks: [naumen-smp]
maintainer: project_template
```

- [ ] **Step 2: Создать `doc-root.yaml` для `project`**

Скопировать текущий `content/.doc-root.yaml` и расширить enum «Тип контента»:

```yaml
# docs/overlays/profiles/project/doc-root.yaml
title: {{PROJECT_NAME}} — База знаний
description: {{PROJECT_DESCRIPTION}}
syntax: XML
language: ru
editors:
  - {{EDITOR_EMAIL}}

properties:
  - name: Тип контента
    type: Enum
    style: blue
    icon: file-text
    values:
      - Требование
      - Архитектура
      - ADR
      - Runbook
      - Исследование
      - Глоссарий
      - Test Design
      - Test Report
      - Security Audit
      - Secrets Policy
      - Compliance Report
      - Plan
      - Critical Path
      - Прочее

  - name: Фаза
    type: Enum
    style: yellow
    icon: clock
    values: [PoC, MVP, Pilot, Production]

  - name: Статус
    type: Enum
    style: green
    icon: check
    values: [Draft, Review, Approved, Archived]

filterProperties: [Тип контента, Фаза, Статус]
```

- [ ] **Step 3: Создать content-scaffold/ (полный scaffold для project)**

Структура: скопировать текущий `content/` (после Wave 1) и добавить новые подпапки.

```bash
mkdir -p docs/overlays/profiles/project/content-scaffold/{00-project/{adr,plans,critical-path,security,compliance},10-domain,30-requirements/{functional,non-functional},40-architecture,60-implementation/test-reports,70-operations}

# Скопировать существующие _index.md
for d in 00-project 00-project/adr 10-domain 30-requirements 30-requirements/functional 30-requirements/non-functional 40-architecture 60-implementation 70-operations; do
  cp content/$d/_index.md docs/overlays/profiles/project/content-scaffold/$d/_index.md
done
cp content/_index.md docs/overlays/profiles/project/content-scaffold/_index.md
cp content/10-domain/glossary.md docs/overlays/profiles/project/content-scaffold/10-domain/glossary.md
```

- [ ] **Step 4: Создать `_index.md` для НОВЫХ подпапок**

```bash
cat > docs/overlays/profiles/project/content-scaffold/00-project/plans/_index.md <<'EOF'
---
order: 5
title: Планы реализации
---

# Планы реализации

Декомпозиция эпиков на задачи (создаются `/pipelines/project-planning <epic>`).

(пусто — планы добавляются по мере декомпозиции эпиков)
EOF

cat > docs/overlays/profiles/project/content-scaffold/00-project/critical-path/_index.md <<'EOF'
---
order: 6
title: Критические пути
---

# Критические пути

Анализ зависимостей задач и критический путь для эпиков (создаются `/pipelines/critical-path <epic>`).

(пусто — добавляются по мере необходимости)
EOF

cat > docs/overlays/profiles/project/content-scaffold/00-project/security/_index.md <<'EOF'
---
order: 7
title: Безопасность
---

# Безопасность

Security audits, secrets policy (создаются `/devsecops`).

(пусто — добавляется по мере security-проверок)
EOF

cat > docs/overlays/profiles/project/content-scaffold/00-project/compliance/_index.md <<'EOF'
---
order: 8
title: Соответствие
---

# Соответствие требованиям ИБ

Compliance reports (создаются `/compliance`).

(пусто — добавляются по запросу аудита)
EOF

cat > docs/overlays/profiles/project/content-scaffold/60-implementation/test-reports/_index.md <<'EOF'
---
order: 1
title: Test reports
---

# Test reports

Отчёты QA-runner'а (`/qa --mode=runner`).

(пусто — добавляются по мере прогонов тестов)
EOF
```

- [ ] **Step 5: Создать `agent-overrides/.gitkeep`**

```bash
mkdir -p docs/overlays/profiles/project/agent-overrides
touch docs/overlays/profiles/project/agent-overrides/.gitkeep
```

- [ ] **Step 6: Прогнать validate-profile**

```bash
python3 scripts/validate-profile.py docs/overlays/profiles/project
```

Expected: exit 0, либо warnings про compatible_stacks: [naumen-smp] (если AGENTS.md ещё не обновлён — будет M4 error, временно. Исправится после T22).

Если M4 error — это НОРМАЛЬНО на этом шаге (AGENTS.md ещё не описывает 10 ролей). Продолжаем; финальная зелёная пройдёт после T22.

- [ ] **Step 7: Commit**

```bash
git add docs/overlays/profiles/project/
git commit -m "feat(profile): project baseline — manifest, scaffold, doc-root [W2-T16]"
```

---

### Task 17: Создать `kb-team` profile manifest + scaffold

**Files:**
- Create: `docs/overlays/profiles/kb-team/manifest.yaml`
- Create: `docs/overlays/profiles/kb-team/doc-root.yaml`
- Create: `docs/overlays/profiles/kb-team/content-scaffold/...`

- [ ] **Step 1: manifest.yaml для kb-team**

```yaml
# docs/overlays/profiles/kb-team/manifest.yaml
schema_version: 1
name: kb-team
description: Внутренняя командная KB (onboarding/runbook/role/incident)
audience: Команда разработки, DevOps, on-call
status: stable

subagents:
  pm: core
  researcher: optional
  ba: disabled
  sa: disabled
  dev: disabled
  devops: core
  qa: disabled
  tech-writer: core
  devsecops: optional
  compliance: optional

pipelines:
  project-planning: optional
  ba-acceptance: disabled
  critical-path: disabled
  scrum-agile: disabled

content_scaffold: content-scaffold/
doc_root: doc-root.yaml

operations:
  - op: delete
    target: content/30-requirements/
    reason: "kb-team не использует функциональные требования"
  - op: delete
    target: content/40-architecture/
    reason: "kb-team не имеет компонентов архитектуры"
  - op: delete
    target: content/60-implementation/
    reason: "нет реализации"
  - op: delete
    target: content/70-operations/
    reason: "переносится в 30-runbooks/"
  - op: add
    source: content-scaffold/
    target: content/
    reason: "kb-team scaffold (10-domain, 20-onboarding, 30-runbooks, 40-roles, 50-incidents)"
  - op: replace
    source: doc-root.yaml
    target: content/.doc-root.yaml
    reason: "kb-team properties (Owner, Эскалация)"

init_prompts: []

compatible_stacks: []
maintainer: project_template
```

- [ ] **Step 2: doc-root.yaml для kb-team**

```yaml
# docs/overlays/profiles/kb-team/doc-root.yaml
title: {{PROJECT_NAME}} — KB команды
description: {{PROJECT_DESCRIPTION}}
syntax: XML
language: ru
editors:
  - {{EDITOR_EMAIL}}

properties:
  - name: Тип контента
    type: Enum
    style: blue
    icon: file-text
    values:
      - Onboarding
      - Runbook
      - Role
      - Incident
      - Эскалация
      - Глоссарий
      - Прочее

  - name: Owner
    type: String
    style: yellow
    icon: user

  - name: Статус
    type: Enum
    style: green
    icon: check
    values: [Draft, Review, Approved, Archived]

filterProperties: [Тип контента, Owner, Статус]
```

- [ ] **Step 3: content-scaffold/ для kb-team**

```bash
mkdir -p docs/overlays/profiles/kb-team/content-scaffold/{10-domain,20-onboarding,30-runbooks,40-roles,50-incidents}

cat > docs/overlays/profiles/kb-team/content-scaffold/_index.md <<'EOF'
---
order: 0
title: {{PROJECT_NAME}} — KB команды
---

{{PROJECT_DESCRIPTION}}

## Навигация

- [Доменная модель](10-domain/)
- [Onboarding](20-onboarding/)
- [Runbooks](30-runbooks/)
- [Роли](40-roles/)
- [Инциденты](50-incidents/)

## Дашборд

<view defs="Тип контента=Onboarding&Runbook&Role&Incident&Эскалация" groupby="Статус" display="List"/>
EOF

cat > docs/overlays/profiles/kb-team/content-scaffold/10-domain/_index.md <<'EOF'
---
order: 10
title: Доменная модель
---

# Доменная модель

Глоссарий и доменные термины команды.

(пусто — термины добавляются Tech Writer'ом)
EOF

cat > docs/overlays/profiles/kb-team/content-scaffold/20-onboarding/_index.md <<'EOF'
---
order: 20
title: Onboarding
---

# Onboarding новых членов команды

Гайды для нового сотрудника: как настроить окружение, кого спрашивать, что прочитать.
EOF

cat > docs/overlays/profiles/kb-team/content-scaffold/30-runbooks/_index.md <<'EOF'
---
order: 30
title: Runbooks
---

# Runbooks

Операционные процедуры (deploy, rollback, on-call).
EOF

cat > docs/overlays/profiles/kb-team/content-scaffold/40-roles/_index.md <<'EOF'
---
order: 40
title: Роли
---

# Роли в команде

Описание ролей, обязанностей, RACI.
EOF

cat > docs/overlays/profiles/kb-team/content-scaffold/50-incidents/_index.md <<'EOF'
---
order: 50
title: Инциденты
---

# Инциденты и postmortem'ы

Хроника инцидентов, retrospectives.
EOF

mkdir -p docs/overlays/profiles/kb-team/agent-overrides
touch docs/overlays/profiles/kb-team/agent-overrides/.gitkeep
```

- [ ] **Step 4: validate-profile**

```bash
python3 scripts/validate-profile.py docs/overlays/profiles/kb-team
```

Expected: exit 0 (или M4 errors про роли в AGENTS.md — нормально до T22).

- [ ] **Step 5: Commit**

```bash
git add docs/overlays/profiles/kb-team/
git commit -m "feat(profile): kb-team baseline — manifest, scaffold, doc-root [W2-T17]"
```

---

### Task 18: 5 stub-манифестов (product, kb-product, custom, methodology, course)

**Files:**
- Create: `docs/overlays/profiles/product/manifest.yaml`
- Create: `docs/overlays/profiles/kb-product/manifest.yaml`
- Create: `docs/overlays/profiles/custom/manifest.yaml`
- Create: `docs/overlays/profiles/methodology/manifest.yaml`
- Create: `docs/overlays/profiles/course/manifest.yaml`

- [ ] **Step 1: Каждый stub — минимальный manifest со status: stub**

```bash
for prof in product kb-product custom methodology course; do
  mkdir -p docs/overlays/profiles/$prof/agent-overrides
  touch docs/overlays/profiles/$prof/agent-overrides/.gitkeep
done
```

```yaml
# docs/overlays/profiles/product/manifest.yaml
schema_version: 1
name: product
description: Разработка продукта/модуля (vision → spec → ADR → реализация → release)
status: stub
subagents:
  pm: core
  ba: core
  sa: core
  dev: core
  qa: core
  tech-writer: core
  researcher: optional
  devops: optional
  devsecops: optional
  compliance: optional
pipelines:
  project-planning: optional
  ba-acceptance: optional
  critical-path: disabled
  scrum-agile: disabled
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: ["*"]
maintainer: project_template
```

```yaml
# docs/overlays/profiles/kb-product/manifest.yaml
schema_version: 1
name: kb-product
description: Документация продукта/процесса для внешних читателей
status: stub
subagents:
  pm: core
  tech-writer: core
  researcher: optional
  ba: optional
  compliance: optional
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: ["*"]
maintainer: project_template
```

```yaml
# docs/overlays/profiles/custom/manifest.yaml
schema_version: 1
name: custom
description: Open-ended (research-каталог, личный wiki, методология) — собирай руками
status: stub
subagents:
  pm: core
  researcher: optional
  ba: optional
  sa: optional
  dev: optional
  devops: optional
  qa: optional
  tech-writer: optional
  devsecops: optional
  compliance: optional
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: ["*"]
maintainer: project_template
```

```yaml
# docs/overlays/profiles/methodology/manifest.yaml
schema_version: 1
name: methodology
description: Методология / playbook / framework
status: stub
subagents:
  pm: core
  tech-writer: core
  researcher: optional
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
maintainer: project_template
```

```yaml
# docs/overlays/profiles/course/manifest.yaml
schema_version: 1
name: course
description: Обучающий курс (модули → lessons → assessments)
status: stub
subagents:
  pm: core
  tech-writer: core
  ba: optional
  researcher: optional
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
maintainer: project_template
```

- [ ] **Step 2: validate-profile (без AGENTS.md ещё warnings, OK)**

```bash
python3 scripts/validate-profile.py
```

Expected: exit 0 (errors будут устранены после T22 AGENTS.md).

- [ ] **Step 3: Commit**

```bash
git add docs/overlays/profiles/{product,kb-product,custom,methodology,course}/
git commit -m "feat(profile): 5 stub-манифестов — product/kb-product/custom/methodology/course [W2-T18]"
```

---

## Phase 4 — Agent prompts (5 новых + 6 улучшенных)

> **Implementer'ам:** prompt'ы агентов написаны в SDD-режиме. Для каждой задачи в этой фазе используй Opus-subagent (owner авторизовал). Контракт каждого prompt'а — в `docs/superpowers/specs/2026-05-06-multi-template-support-design.md` §4.7. Файлы агентов — markdown с YAML frontmatter (`name`, `description`, `tools`, `model`, опц. `skills`).

### Task 19: NEW `agents/qa-author-agent.md`

**Files:**
- Create: `agents/qa-author-agent.md`

- [ ] **Step 1: Написать prompt по контракту**

Контракт (из spec'а §4.7):
- **Цель:** написать AC-driven test design + failing test stubs до Dev'а
- **Входы:** требование с AC, опц. SA-артефакт
- **Артефакты:** `content/30-requirements/<req>/at-design.md` + `tests/<area>/test_<req>.<ext>` (failing)
- **Критерии приёмки:** stubs запускаются и падают; AC покрытие 100%; assertion рассчитан на TDD

Шапка файла:

```markdown
---
name: qa-author-agent
description: Пишет AC-driven test design + failing test stubs до Dev'а (часть QA-роли, режим author)
tools: Read, Write, Edit, Bash, Grep, Glob
model: sonnet
---

# QA Author — TDD-партнёр для Dev

Ты — QA-author. Пишешь тесты ДО Dev'а на основе Acceptance Criteria из требований BA.

## Цель
[...полный prompt в стиле существующих agents/ba-agent.md, agents/sa-agent.md...]
```

Implementer-subagent заполнит полный prompt (300-500 строк) по образцу существующих promt'ов.

- [ ] **Step 2: Verify файл валидный markdown с frontmatter**

```bash
python3 -c "
import re
text = open('agents/qa-author-agent.md').read()
assert text.startswith('---'), 'no frontmatter'
import yaml
parts = text.split('---', 2)
fm = yaml.safe_load(parts[1])
assert fm['name'] == 'qa-author-agent'
print('OK')
"
```

- [ ] **Step 3: Commit**

```bash
git add agents/qa-author-agent.md
git commit -m "feat(agents): qa-author-agent — AC → test design + failing stubs [W2-T19]"
```

---

### Task 20: NEW `agents/qa-runner-agent.md`

**Files:**
- Create: `agents/qa-runner-agent.md`

- [ ] **Step 1: Frontmatter + prompt по контракту**

Контракт (spec §4.7):
- **Цель:** прогнать full test suite + регрессии после Dev'а
- **Входы:** код в src/, tests/, требование с AC
- **Артефакт:** `content/60-implementation/test-reports/<NNN>-<date>.md`
- **Критерии:** отчёт passed/failed/skipped + regression analysis + рекомендация (merge/block/rerun)

```markdown
---
name: qa-runner-agent
description: Прогоняет full test suite, регрессии, формирует отчёт (часть QA-роли, режим runner)
tools: Read, Bash, Grep, Glob, Write
model: sonnet
---

# QA Runner — прогон + регрессии

[...полный prompt...]
```

- [ ] **Step 2: Commit**

```bash
git add agents/qa-runner-agent.md
git commit -m "feat(agents): qa-runner-agent — full suite + регрессии + отчёт [W2-T20]"
```

---

### Task 21: NEW `agents/tech-writer-agent.md`

**Files:**
- Create: `agents/tech-writer-agent.md`

- [ ] **Step 1: Frontmatter + prompt по контракту (base = secondary editor)**

```markdown
---
name: tech-writer-agent
description: Преобразует технический черновик в customer-facing статью (secondary editor mode)
tools: Read, Write, Edit
model: sonnet
---

# Tech Writer — secondary editor

Ты — Tech Writer. В этом профиле работаешь как secondary editor: берёшь технический черновик
и переписываешь на язык, понятный целевой аудитории.

[...полный prompt...]
```

- [ ] **Step 2: Commit**

```bash
git add agents/tech-writer-agent.md
git commit -m "feat(agents): tech-writer-agent — secondary editor base [W2-T21]"
```

---

### Task 22: AGENTS.md — реестр 10 ролей + контракт + матрица + pipelines

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Полностью переписать AGENTS.md по структуре spec §4.2**

Структура (см. spec §4.2):
1. Каталог ролей (таблица, 10 строк)
2. Контракт вызова субагента (универсальный, 4 пункта)
3. Матрица «роль × профиль» (таблица 10×7)
4. Каталог pipelines (таблица 4 строки)
5. Pipeline-orchestration model (worktree per-pipeline; параллельность через dispatching-parallel-agents)

Полный текст — в spec §4.2. Implementer копирует и адаптирует.

- [ ] **Step 2: validate-profile должен пройти**

```bash
python3 scripts/validate-profile.py
```

Expected: 0 errors (M4 теперь резолвится — все имена ролей в AGENTS.md), warnings про compatible_stacks допустимы.

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "docs(agents): полный реестр 10 ролей + контракт + матрица × профиль + pipelines [W2-T22]"
```

---

### Task 23-27: NEW devsecops, compliance + улучшение pm, researcher, ba, sa, dev, devops

**Каждая задача аналогична T19-T21 — implementer пишет prompt по контракту из spec §4.7. Поэтому объединено в одну агрегированную фазу:**

- [ ] **Task 23**: `agents/devsecops-agent.md` — embedded security review.
  Commit: `feat(agents): devsecops-agent — secrets/SAST/supply-chain [W2-T23]`

- [ ] **Task 24**: `agents/compliance-agent.md` — research-агент general-purpose.
  Commit: `feat(agents): compliance-agent — research-based compliance check [W2-T24]`

- [ ] **Task 25**: EDIT `agents/pm-agent.md` — добавить секции про pipelines, soft-suggest, координацию 10 ролей. Сохранить существующие секции про PM-orchestration.
  Commit: `refactor(agents): pm-agent — pipelines, soft-suggest opt-in subagents [W2-T25]`

- [ ] **Task 26**: EDIT `agents/researcher-agent.md` — чёткое разделение труда (не пишет требования/архитектуру).
  Commit: `refactor(agents): researcher-agent — чёткое разделение труда с BA/SA [W2-T26]`

- [ ] **Task 27**: EDIT `agents/ba-agent.md` — добавить `--mode=acceptance` секцию (Gate AC ↔ реализация).
  Commit: `refactor(agents): ba-agent — режим acceptance для BA-acceptance pipeline [W2-T27]`

- [ ] **Task 28**: EDIT `agents/sa-agent.md` — секция «Контракт с QA-author» (передача AC, не пишет тесты).
  Commit: `refactor(agents): sa-agent — контракт с QA-author [W2-T28]`

- [ ] **Task 29**: EDIT `agents/dev-agent.md` — TDD по qa-author stubs (приоритет — сделать stubs зелёными).
  Commit: `refactor(agents): dev-agent — TDD по qa-author stubs [W2-T29]`

- [ ] **Task 30**: EDIT `agents/devops-agent.md` — секция «Координация с DevSecOps» (DevOps владеет deploy; DevSecOps — secrets/SAST).
  Commit: `refactor(agents): devops-agent — координация с DevSecOps [W2-T30]`

После каждого commit'а в Phase 4 — sanity: `python3 scripts/validate-profile.py` зелёный.

---

## Phase 5 — Slash-команды (5 новых + 4 обновления)

### Task 31: NEW `commands/qa.md` (`--mode=author|runner`)

**Files:**
- Create: `.claude/plugins/project/commands/qa.md`

- [ ] **Step 1: Создать slash с диспетчем**

```markdown
---
description: QA с режимами author (тесты до Dev) и runner (прогон + регрессии)
allowed-tools: Task
---

# /qa — QA-агент с двумя режимами

Аргументы: `--mode=author <req>` или `--mode=runner <module>`.

## Логика

1. Распарси `--mode` из args:
   - `author` → диспетч `qa-author-agent` через Task tool
   - `runner` → диспетч `qa-runner-agent`
2. Передай остальные args как task description в субагент
3. Верни результат

## Пример

`/qa --mode=author user-sessions` → запускает qa-author-agent с задачей «написать AC-driven test design + failing stubs для user-sessions».
```

- [ ] **Step 2: Commit**

```bash
git add .claude/plugins/project/commands/qa.md
git commit -m "feat(commands): /qa --mode=author|runner диспетч [W2-T31]"
```

---

### Task 32-35: NEW commands/{tech-writer,devsecops,compliance}.md + EDIT commands/ba.md

- [ ] **Task 32**: `commands/tech-writer.md` — slash для tech-writer-agent.
  Commit: `feat(commands): /tech-writer [W2-T32]`

- [ ] **Task 33**: `commands/devsecops.md` — slash для devsecops-agent.
  Commit: `feat(commands): /devsecops [W2-T33]`

- [ ] **Task 34**: `commands/compliance.md` — slash для compliance-agent.
  Commit: `feat(commands): /compliance [W2-T34]`

- [ ] **Task 35**: EDIT `commands/ba.md` — добавить блок `--mode=acceptance`.
  Commit: `refactor(commands): /ba --mode=acceptance для BA-acceptance pipeline [W2-T35]`

---

### Task 36-39: EDIT commands/{init,pm,pm-review}.md + NEW commands/pipelines/*

- [ ] **Task 36**: EDIT `commands/init.md` — добавить Phase 1 шаг «выбор профиля» (читать manifest'ы из `docs/overlays/profiles/`, спрашивать у пользователя; ditto для init_prompts; on_value мутации; compatible_stacks для опц. stack-overlay'ов).
  Commit: `refactor(commands): /init с интерактивным выбором профиля [W2-T36]`

- [ ] **Task 37**: EDIT `commands/pm.md` — секция про pipelines, soft-suggest opt-in subagents в decompose, ритуал worktree через `using-git-worktrees`.
  Commit: `refactor(commands): /pm pipelines + soft-suggest [W2-T37]`

- [ ] **Task 38**: EDIT `commands/pm-review.md` — добавить шаг «запусти validate-profile.py»; проверка pipeline-state и worktree.
  Commit: `refactor(commands): /pm-review + validate-profile + pipeline-state [W2-T38]`

- [ ] **Task 39**: NEW `commands/pipelines/{project-planning,ba-acceptance,critical-path}.md` — orchestrator-команды (см. spec §4.8).
  Commit: `feat(commands): pipelines/{project-planning,ba-acceptance,critical-path} [W2-T39]`

---

## Phase 6 — init.sh refactor (interactive profile + dynamic prompts)

### Task 40: Расширить init.sh — интерактивный выбор профиля + on_value мутации

**Files:**
- Modify: `scripts/init.sh`
- Modify: `scripts/test-template.sh`

- [ ] **Step 1: Добавить парсинг `--profile`**

В начало `init.sh` (после существующих arg-парсингов):

```bash
PROFILE=""

# Парсинг флагов BEFORE positional args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --profile=*) PROFILE="${1#*=}"; shift ;;
    *) break ;;
  esac
done
```

- [ ] **Step 2: Если PROFILE не задан — interactive prompt**

После парсинга PROJECT_NAME / PROJECT_CODE / etc., перед replace_in_file:

```bash
if [[ -z "$PROFILE" ]]; then
  echo "Выбери профиль:"
  ls docs/overlays/profiles/ | sed 's/^/  - /'
  read -p "Профиль (default: project): " PROFILE
  PROFILE="${PROFILE:-project}"
fi

[[ ! -d "docs/overlays/profiles/$PROFILE" ]] && {
  echo "ERROR: профиль '$PROFILE' не существует" >&2
  exit 1
}

echo "Profile: $PROFILE"
```

- [ ] **Step 3: Прочитать init_prompts из manifest и опросить**

```bash
# Динамические prompts
PROMPTS_COUNT=$(python3 -c "import yaml; m=yaml.safe_load(open('docs/overlays/profiles/$PROFILE/manifest.yaml')); print(len(m.get('init_prompts') or []))")

# Сохраняем ответы в env-переменные
declare -A PROMPT_ANSWERS
for i in $(seq 0 $((PROMPTS_COUNT - 1))); do
  PROMPT_ID=$(python3 -c "import yaml; m=yaml.safe_load(open('docs/overlays/profiles/$PROFILE/manifest.yaml')); print(m['init_prompts'][$i]['id'])")
  PROMPT_TEXT=$(python3 -c "import yaml; m=yaml.safe_load(open('docs/overlays/profiles/$PROFILE/manifest.yaml')); print(m['init_prompts'][$i]['prompt'])")
  CHOICES=$(python3 -c "import yaml; m=yaml.safe_load(open('docs/overlays/profiles/$PROFILE/manifest.yaml')); print(','.join(m['init_prompts'][$i].get('choices') or []))")
  DEFAULT=$(python3 -c "import yaml; m=yaml.safe_load(open('docs/overlays/profiles/$PROFILE/manifest.yaml')); print(m['init_prompts'][$i].get('default', ''))")

  echo "$PROMPT_TEXT"
  [[ -n "$CHOICES" ]] && echo "Варианты: $CHOICES"
  read -p "Ответ (default: $DEFAULT): " ANSWER
  ANSWER="${ANSWER:-$DEFAULT}"
  PROMPT_ANSWERS[$PROMPT_ID]="$ANSWER"
done
```

- [ ] **Step 4: Вызвать apply-overlay.sh --profile --init**

После replace_in_file (где подставляются плейсхолдеры в стандартные файлы):

```bash
echo "Applying profile overlay..."
bash scripts/apply-overlay.sh --profile --init "$PROFILE" || {
  echo "ERROR: apply-overlay.sh failed" >&2
  exit 1
}

# Note: on_value мутации применяются apply-overlay'ем in-memory; manifest на диске не меняется
```

- [ ] **Step 5: Опц. stack-overlay'и**

```bash
COMPAT_STACKS=$(python3 -c "import yaml; m=yaml.safe_load(open('docs/overlays/profiles/$PROFILE/manifest.yaml')); s=m.get('compatible_stacks') or []; print(','.join(s) if s and s != ['*'] else '')")

if [[ -n "$COMPAT_STACKS" ]]; then
  echo "Совместимые stack-overlay'и: $COMPAT_STACKS"
  read -p "Применить какие-то? (через запятую, или пусто чтобы пропустить): " STACKS_TO_APPLY
  if [[ -n "$STACKS_TO_APPLY" ]]; then
    IFS=',' read -ra STACKS <<< "$STACKS_TO_APPLY"
    for s in "${STACKS[@]}"; do
      bash scripts/apply-overlay.sh "$s"
    done
  fi
fi
```

- [ ] **Step 6: Прогон validate-content + validate-profile**

```bash
python3 scripts/validate-content.py
python3 scripts/validate-profile.py
```

- [ ] **Step 7: T-INIT-PROFILE ассерт в test-template.sh**

```bash
echo "==> T-INIT-PROFILE: init с --profile project"
TMP_INIT=$(mktemp -d)
rsync -a --exclude='.git' --exclude='.worktrees' . "$TMP_INIT/"
cd "$TMP_INIT"
git init -q -b main
git -c user.email=t@x -c user.name=t commit --allow-empty -q -m baseline
echo | bash scripts/init.sh --profile project "Test" "TST" "desc" "test@x.com" >/dev/null 2>&1
RC=$?
assert "T-INIT-PROFILE: exit 0" "[ \"$RC\" = '0' ]"
assert "T-INIT-PROFILE: scaffold project применён" "[ -d content/00-project/plans ]"
cd "$REPO_ROOT"
rm -rf "$TMP_INIT"

echo "==> T-INIT-PROFILE-KB: init с --profile kb-team"
TMP_INIT_KB=$(mktemp -d)
rsync -a --exclude='.git' --exclude='.worktrees' . "$TMP_INIT_KB/"
cd "$TMP_INIT_KB"
git init -q -b main
git -c user.email=t@x -c user.name=t commit --allow-empty -q -m baseline
bash scripts/init.sh --profile kb-team "Test" "TST" "desc" "test@x.com" >/dev/null 2>&1
RC=$?
assert "T-INIT-PROFILE-KB: exit 0" "[ \"$RC\" = '0' ]"
assert "T-INIT-PROFILE-KB: 30-runbooks существует" "[ -d content/30-runbooks ]"
assert "T-INIT-PROFILE-KB: 30-requirements удалена" "[ ! -d content/30-requirements ]"
cd "$REPO_ROOT"
rm -rf "$TMP_INIT_KB"

echo "==> T-LEGACY: init без --profile fallback на project"
TMP_LEG=$(mktemp -d)
rsync -a --exclude='.git' --exclude='.worktrees' . "$TMP_LEG/"
cd "$TMP_LEG"
git init -q -b main
git -c user.email=t@x -c user.name=t commit --allow-empty -q -m baseline
echo | bash scripts/init.sh "Test" "TST" "desc" "test@x.com" >/dev/null 2>&1
RC=$?
assert "T-LEGACY: exit 0" "[ \"$RC\" = '0' ]"
assert "T-LEGACY: project scaffold применён" "[ -d content/00-project/plans ]"
cd "$REPO_ROOT"
rm -rf "$TMP_LEG"
```

- [ ] **Step 8: Прогнать test-template.sh**

```bash
bash scripts/test-template.sh
```

Expected: T-INIT-PROFILE, T-INIT-PROFILE-KB, T-LEGACY зелёные.

- [ ] **Step 9: Commit**

```bash
git add scripts/init.sh scripts/test-template.sh
git commit -m "feat(init): интерактивный выбор профиля + dynamic init_prompts + stack-overlay'и [W2-T40]"
```

---

## Phase 7 — Documentation

### Task 41: CLAUDE.md — блок «Профильная система»

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Добавить блок после «Структура плагинной системы»**

```markdown
## Профильная система (Wave 2)

Шаблон поддерживает 7 **профилей** (тип проекта). Профиль выбирается на `/init` и определяет:

- структуру `content/` (scaffold)
- набор properties в `.doc-root.yaml`
- активные subagents (core / optional / disabled)
- активные pipelines

| Профиль | Назначение | Статус |
|---------|------------|--------|
| `project` | Delivery-проект (default) | stable |
| `kb-team` | Internal team KB (onboarding/runbook/role/incident) | stable |
| `product` | Разработка продукта | stub (Wave 3+) |
| `kb-product` | Документация продукта для клиентов | stub |
| `methodology` | Methodology / playbook | stub |
| `course` | Обучающий курс | stub |
| `custom` | Open-ended | stub |

### Команды

- `/init --profile <name>` — выбрать профиль на init (по умолчанию интерактивный fallback)
- `bash scripts/apply-overlay.sh --profile --dry-run <name>` — preview операций
- `python3 scripts/validate-profile.py` — валидация manifest'ов

### Файлы

- `docs/overlays/profiles/<name>/manifest.yaml` — декларация профиля
- `docs/overlays/profiles/<name>/content-scaffold/` — content scaffold
- `docs/overlays/profiles/<name>/doc-root.yaml` — шаблон `.doc-root.yaml`
- `agents/<role>-agent.md` — base prompts; per-profile overrides в `profiles/<name>/agent-overrides/<role>.md` (Wave 3)

См. AGENTS.md (реестр 10 ролей) и `docs/extending.md` (как добавить роль/pipeline/профиль).
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude): блок «Профильная система» [W2-T41]"
```

---

### Task 42: README.md — упомянуть profile и validate-profile

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Добавить упоминание в Quick Start / Полезные команды**

```markdown
- `bash scripts/init.sh --profile project "Project Name" "PROJ" "desc" "user@x.com"` — init с явным профилем
- `python3 scripts/validate-profile.py` — валидация manifest'ов профилей
- `bash scripts/apply-overlay.sh --profile --dry-run kb-team` — preview профильных операций
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs(readme): упомянуть --profile и validate-profile.py [W2-T42]"
```

---

### Task 43: NEW `docs/extending.md` — как добавить роль / pipeline / профиль

**Files:**
- Create: `docs/extending.md`

- [ ] **Step 1: Создать гайд**

Структура гайда (сам implementer заполнит детали):

```markdown
# Расширение шаблона

## Как добавить новую роль (subagent)

1. Создать `agents/<role>-agent.md` с frontmatter (name, description, tools, model)
2. Описать роль в AGENTS.md «Каталог ролей» (новая строка таблицы)
3. Добавить роль в matrix «роль × профиль»
4. Создать slash-команду `.claude/plugins/project/commands/<role>.md`
5. Если роль будет в каком-то профиле — добавить в `subagents:` в manifest.yaml
6. Прогнать `python3 scripts/validate-profile.py`

## Как добавить новый pipeline

1. Создать `.claude/plugins/project/commands/pipelines/<name>.md` с orchestration-логикой
2. Описать в AGENTS.md «Каталог pipelines»
3. Добавить в profile manifest'ы где relevant
4. Прогнать validate-profile.py

## Как добавить новый профиль

1. Создать папку `docs/overlays/profiles/<name>/`
2. Написать `manifest.yaml` (минимум: schema_version, name, description, status, subagents, pipelines, content_scaffold, doc_root, operations, compatible_stacks)
3. (Если status: stable) — наполнить `content-scaffold/` + `doc-root.yaml`
4. (Опц.) добавить в `init_prompts:` если профиль требует пользовательский ввод
5. Прогнать `python3 scripts/validate-profile.py docs/overlays/profiles/<name>`
6. Тест: `bash scripts/apply-overlay.sh --profile --dry-run <name>`
7. Добавить в матрицу в AGENTS.md
```

- [ ] **Step 2: Commit**

```bash
git add docs/extending.md
git commit -m "docs: extending guide — как добавить роль/pipeline/профиль [W2-T43]"
```

---

## Phase 8 — Final verification + lessons-learned

### Task 44: Полный smoke + tag + lessons

**Files:**
- Modify: `docs/lessons-learned.md`

- [ ] **Step 1: Прогнать всё**

```bash
bash scripts/test-validate-content.sh
bash scripts/test-validate-profile.sh
bash scripts/test-template.sh
python3 scripts/validate-content.py
python3 scripts/validate-profile.py
```

Expected: всё зелёное (warnings про шаблонные плейсхолдеры допустимы).

- [ ] **Step 2: Smoke — запустить init на временной копии**

```bash
TMP="$(mktemp -d)"
rsync -a --exclude='.git' --exclude='.worktrees' . "$TMP/"
cd "$TMP"
git init -q -b main
git -c user.email=t@x -c user.name=t commit --allow-empty -q -m baseline
echo | bash scripts/init.sh --profile kb-team "Smoke" "SMOKE" "Smoke catalog" "smoke@example.com"
python3 scripts/validate-content.py
python3 scripts/validate-profile.py
ls content/
[ -d content/30-runbooks ] && echo "✓ kb-team scaffold OK"
[ ! -d content/30-requirements ] && echo "✓ project-specific deleted"
cd -
rm -rf "$TMP"
```

Expected: все ✓; validators зелёные; scaffold соответствует kb-team.

- [ ] **Step 3: Append lessons**

```markdown
| 2026-05-XX | PM | Wave 2 / multi-template | Шаблон поддерживал один тип проекта; пользователи имели разные шейпы (delivery, KB, methodology, course) и не могли использовать общий шаблон | Profile-driven система с 7 профилями (project + kb-team baseline; 5 stub'ов в задел Wave 3+); расширенный subagent-каталог (10 ролей; AT+Tester объединены через --mode); 3 pipeline'а (project-planning, BA-acceptance, critical-path); apply-overlay.sh с ops add/replace/delete и strict delete-non-empty. |
```

- [ ] **Step 4: Опц. tag**

```bash
git tag wave2-multi-template-2026-05-XX
```

(Спросить owner'а нужен ли tag.)

- [ ] **Step 5: Commit lessons**

```bash
git add docs/lessons-learned.md
git commit -m "docs(lessons): запись об итерации Wave 2 multi-template [W2-T44]"
```

---

## Self-Review

### Spec coverage

| Раздел spec'а | Tasks |
|---------------|-------|
| §1 Проблема, §2 Цель | (контекст, не code) |
| §3 Архитектура (file structure) | T16-T18 (профили), T22 (AGENTS.md), T36-T39 (commands), T44 (smoke) |
| §4.1 Manifest schema | T16 (project), T17 (kb-team), T18 (5 stubs) |
| §4.2 AGENTS.md registry | T22 |
| §4.3 apply-overlay.sh refactor | T11-T15 |
| §4.4 init.sh refactor | T40 |
| §4.5 validate-profile.py M1-M10 | T2-T10 |
| §4.6 _validate_common.py | T1 |
| §4.7 Agent prompts (5 new + 6 edit) | T19-T21, T23-T30 |
| §4.8 Pipeline orchestrator commands | T39 |
| §4.9 test-template.sh matrix | T13-T15, T40 (T-OP-ADD, T-OP-REPLACE, T-OP-DELETE, T-INIT-PROFILE×2, T-LEGACY) |
| §5 Data flow | (covered by tasks) |
| §6 Error handling | T11-T15 (apply-overlay errors), T2-T10 (validators) |
| §7 Тесты | T1-T15, T40, T44 |
| §8 Anti-scope | (явно соблюдён в плане — нет L2/L3 customization, нет declarative merge, нет build-templating) |
| §9 GO-критерии (14 чекбоксов) | T44 (final smoke verifies all) |
| §10 Открытые вопросы для SA | (отложены — SA проработает в коде) |

Все требования spec'а покрыты.

### Placeholder scan

Прошёлся по всему плану — все код-блоки полные, все commands конкретные, все assert'ы явные. Нет TBD/TODO/«similar to». В фазах 4 (agents) и 5 (commands) prompt-content делегирован implementer-subagent'у — это намеренно (prompts — 200-500 строк каждый, в плане держать имеет смысл только контракты).

### Type / signature consistency

- `Issue(level, path, message)` — везде идентично (T1-T10).
- `parse_yaml_file(path) -> dict | None` — введена в T1, используется в T1-T10.
- `parse_frontmatter(file_path) -> dict | None` — Wave 1 + T1 (рефакторинг).
- `has_placeholder(file_path) -> bool` — Wave 1 + T1.
- `apply_profile_overlay(name)` — введена в T12, используется в T13-T15.
- `op_add / op_replace / op_delete` — bash-функции, единый паттерн `(profile_dir, source, target, reason)` для add/replace; `(target, reason)` для delete.

Все консистентно.

### Сценарий отката

Каждая задача атомарна (один коммит). При проблеме можно откатить по коммиту. Если на T22 (AGENTS.md) или T40 (init.sh) что-то сломается — fix-up в новом коммите (как в Wave 1 T13.1).
