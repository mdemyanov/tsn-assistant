#!/usr/bin/env bash
# test-template.sh — smoke-тест шаблона на временной копии.
# Запускать перед PR в шаблон.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

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

echo "==> Setting up test repo at $TMP"
rsync -a --exclude='.git' --exclude='.worktrees' "$REPO_ROOT/" "$TMP/"
cd "$TMP"
GIT_TEST="git -c user.email=test@example.com -c user.name=test"
git init -q -b main
git add -A
$GIT_TEST commit -q -m "test baseline"

# ===== T1: JSON validity =====
echo ""
echo "==> T1: JSON files valid"
assert "settings.json valid" "python3 -c 'import json; json.load(open(\".claude/settings.json\"))'"
assert "plugin.json valid" "python3 -c 'import json; json.load(open(\".claude/plugins/project/.claude-plugin/plugin.json\"))'"

# ===== T2: agent frontmatter =====
echo ""
echo "==> T2: agent frontmatter complete"
for agent in pm ba sa dev devops researcher; do
  file=".claude/plugins/project/agents/${agent}-agent.md"
  count=$(head -10 "$file" | grep -cE '^(name|description|model):' || true)
  assert "$agent-agent.md has 3 frontmatter fields" "[ \"$count\" -eq 3 ]"
done

# ===== T3: command frontmatter =====
echo ""
echo "==> T3: command files have description"
for cmd in pm pm-review ba sa dev devops research; do
  file=".claude/plugins/project/commands/${cmd}.md"
  assert "$cmd.md exists" "[ -f \"$file\" ]"
  assert "$cmd.md has description" "head -5 \"$file\" | grep -q '^description:'"
done

# ===== T-W4b-BASELINE: baseline content/ minimization check (pre-init) =====
echo ""
echo "==> T-W4b-BASELINE: baseline content/ size check"
BASELINE_FILES="$(git ls-files content/ | wc -l | tr -d ' ')"
assert "T-W4b-BASELINE: baseline content/ = 2 файла" "[ \"$BASELINE_FILES\" = '2' ]"
assert "T-W4b-BASELINE: baseline files именно _index.md + .doc-root.yaml" \
       "[ \"\$(git ls-files content/ | sort | tr '\\n' ' ')\" = 'content/.doc-root.yaml content/_index.md ' ]"

# ===== T4: content scaffold =====
# ===== T5: init.sh works =====
# T5 must run before T4 — после W4b baseline content/ минимизирован,
# полный scaffold создаётся init.sh через apply-overlay --profile project.
echo ""
echo "==> T5: init.sh substitutes PROJECT_NAME and creates branch"
INIT_SKIP_GIT_RESET=1 bash scripts/init.sh "test-project" "TEST-PROJECT" "Test description" "test@example.com" >/dev/null
assert "PROJECT_NAME replaced in CLAUDE.md" "! grep -q '{{PROJECT_NAME}}' CLAUDE.md"
assert "PROJECT_NAME replaced in content/_index.md" "! grep -q '{{PROJECT_NAME}}' content/_index.md"
assert "PROJECT_NAME replaced in AGENTS.md" "! grep -q '{{PROJECT_NAME}}' AGENTS.md"
assert "test-project name appears" "grep -q 'test-project' CLAUDE.md"
assert "private branch created" "git show-ref --verify --quiet refs/heads/private"
assert ".env created" "[ -f .env ]"

# ===== T4: post-init content scaffold present (_index.md везде) =====
# W4b: baseline content/ минимизирован — полный scaffold создаётся init.sh.
echo ""
echo "==> T4 (post-init): content scaffold present (_index.md везде)"
assert ".doc-root.yaml exists" "[ -f content/.doc-root.yaml ]"
assert "root _index.md" "[ -f content/_index.md ]"
assert "00-project _index.md" "[ -f content/00-project/_index.md ]"
assert "00-project/adr _index.md" "[ -f content/00-project/adr/_index.md ]"
assert "10-domain _index.md" "[ -f content/10-domain/_index.md ]"
assert "30-requirements _index.md" "[ -f content/30-requirements/_index.md ]"
assert "30-requirements/functional _index.md" "[ -f content/30-requirements/functional/_index.md ]"
assert "30-requirements/non-functional _index.md" "[ -f content/30-requirements/non-functional/_index.md ]"
assert "40-architecture _index.md" "[ -f content/40-architecture/_index.md ]"
assert "60-implementation _index.md" "[ -f content/60-implementation/_index.md ]"
assert "70-operations _index.md" "[ -f content/70-operations/_index.md ]"
assert "glossary.md exists" "[ -f content/10-domain/glossary.md ]"
assert "no README.md left in content/" "! find content -name README.md | grep -q ."

# ===== T6: apply-overlay.sh works =====
echo ""
echo "==> T6: apply-overlay.sh idempotent"
git add -A
$GIT_TEST commit -q -m "after init"
bash scripts/apply-overlay.sh naumen-smp >/dev/null
assert "validate-content.py зелёный после overlay apply" "python3 scripts/validate-content.py >/dev/null 2>&1"
assert "marker in CLAUDE.md after apply" "grep -q 'OVERLAY:naumen-smp:start' CLAUDE.md"
git add -A
$GIT_TEST commit -q -m "after apply"
bash scripts/apply-overlay.sh naumen-smp >/dev/null
DIFF_LINES="$(git diff --stat | wc -l | tr -d ' ')"
assert "second apply produces no diff" "[ \"$DIFF_LINES\" = '0' ]"
bash scripts/apply-overlay.sh --remove naumen-smp >/dev/null
assert "marker removed from CLAUDE.md" "! grep -q 'OVERLAY:naumen-smp:start' CLAUDE.md"

# ===== T8: validate-content.py зелёный после init =====
echo ""
echo "==> T8: validate-content.py PASSes after init"
assert "validate-content.py exit 0 after init" "python3 scripts/validate-content.py >/dev/null 2>&1"

# ===== T7: full init (wipe .git + initial commit) =====
echo ""
echo "==> T7: full init wipes .git and creates traceable initial commit"
TMP2="$(mktemp -d)"
rsync -a --exclude='.git' --exclude='.worktrees' "$REPO_ROOT/" "$TMP2/"
cd "$TMP2"
git init -q -b main
git -c user.email=tpl@example.com -c user.name=tpl commit --allow-empty -q -m "tpl baseline"
# Запуск init.sh БЕЗ INIT_SKIP_GIT_RESET — должен сделать wipe + initial commit
bash scripts/init.sh "smoke" "SMOKE" "Smoke test" "smoke@example.com" >/dev/null
COMMITS="$(git log --all --oneline | wc -l | tr -d ' ')"
assert "exactly 1 commit after init" "[ \"$COMMITS\" = '1' ]"
assert "commit message contains Template:" "git log -1 --format=%B | grep -q '^Template: '"
assert "main branch exists" "git show-ref --verify --quiet refs/heads/main"
assert "private branch exists" "git show-ref --verify --quiet refs/heads/private"
assert "no origin remote (no URL passed)" "[ -z \"$(git remote)\" ]"
assert "PROJECT_NAME replaced in CLAUDE.md (T7)" "! grep -q '{{PROJECT_NAME}}' CLAUDE.md"

# T7.b: URL-валидация — URL шаблона должен быть отвергнут
TMP3="$(mktemp -d)"
rsync -a --exclude='.git' --exclude='.worktrees' "$REPO_ROOT/" "$TMP3/"
cd "$TMP3"
git init -q -b main
git -c user.email=tpl@example.com -c user.name=tpl commit --allow-empty -q -m "tpl baseline"
set +e
bash scripts/init.sh "evil" "EVIL" "x" "x@y.z" "https://gitlab.example.com/foo/project-template.git" >/dev/null 2>&1
TPL_REJECT_RC=$?
set -e
assert "init rejects template URL (project-template.git)" "[ \"$TPL_REJECT_RC\" != '0' ]"

# Cleanup T7 dirs (TMP cleanup ловит EXIT trap, но TMP2/TMP3 — отдельные)
cd "$TMP"
rm -rf "$TMP2" "$TMP3"

# ===== T-DRYRUN: --dry-run для markers-flow =====
echo ""
echo "==> T-DRYRUN: --dry-run для markers-flow"
TMP_DRY=$(mktemp -d)
rsync -a --exclude='.git' --exclude='.worktrees' "$REPO_ROOT/" "$TMP_DRY/"
cd "$TMP_DRY"
set +e
OUT=$(bash scripts/apply-overlay.sh --dry-run naumen-smp 2>&1)
RC=$?
set -e
assert "T-DRYRUN: exit 0" "[ \"$RC\" = '0' ]"
assert "T-DRYRUN: prints DRY-RUN" "echo \"$OUT\" | grep -q 'DRY-RUN'"
cd "$REPO_ROOT"
rm -rf "$TMP_DRY"

# ===== T-OP-ADD: op: add копирует файлы =====
echo ""
echo "==> T-OP-ADD: op: add копирует файлы"
TMP_ADD=$(mktemp -d)
mkdir -p "$TMP_ADD/docs/overlays/profiles/test-add/scaffold"
echo "test content" > "$TMP_ADD/docs/overlays/profiles/test-add/scaffold/article.md"
mkdir -p "$TMP_ADD/.claude/plugins/project/commands/pipelines"
mkdir -p "$TMP_ADD/scripts"
cp scripts/_validate_common.py scripts/validate-profile.py scripts/_apply_profile.py scripts/apply-overlay.sh "$TMP_ADD/scripts/"
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

# ===== T-OP-REPLACE: op: replace перезаписывает =====
echo ""
echo "==> T-OP-REPLACE: op: replace перезаписывает"
TMP_REP=$(mktemp -d)
mkdir -p "$TMP_REP/docs/overlays/profiles/test-rep"
mkdir -p "$TMP_REP/.claude/plugins/project/commands/pipelines"
mkdir -p "$TMP_REP/scripts" "$TMP_REP/content"
cp scripts/_validate_common.py scripts/validate-profile.py scripts/_apply_profile.py scripts/apply-overlay.sh "$TMP_REP/scripts/"
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
assert "T-OP-REPLACE: file replaced" "grep -q 'new' content/file.txt"
cd "$REPO_ROOT"
rm -rf "$TMP_REP"

# ===== T-OP-DELETE: пустая папка удаляется =====
echo ""
echo "==> T-OP-DELETE: пустая папка удаляется"
TMP_DEL=$(mktemp -d)
mkdir -p "$TMP_DEL/docs/overlays/profiles/test-del" "$TMP_DEL/content/empty-dir" "$TMP_DEL/.claude/plugins/project/commands/pipelines" "$TMP_DEL/scripts"
cp scripts/_validate_common.py scripts/validate-profile.py scripts/_apply_profile.py scripts/apply-overlay.sh "$TMP_DEL/scripts/"
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
assert "T-OP-DELETE: empty dir удалена" "[ ! -d content/empty-dir ]"
cd "$REPO_ROOT"
rm -rf "$TMP_DEL"

# ===== T-OP-DELETE-STRICT: non-empty refuse без --force =====
echo "==> T-OP-DELETE-STRICT: non-empty refuse без --force"
TMP_DELS=$(mktemp -d)
mkdir -p "$TMP_DELS/docs/overlays/profiles/test-dels" "$TMP_DELS/content/full-dir" "$TMP_DELS/.claude/plugins/project/commands/pipelines" "$TMP_DELS/scripts"
cp scripts/_validate_common.py scripts/validate-profile.py scripts/_apply_profile.py scripts/apply-overlay.sh "$TMP_DELS/scripts/"
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

# ===== T-INIT-PROFILE: init с --profile project =====
echo ""
echo "==> T-INIT-PROFILE: init с --profile project"
TMP_INIT=$(mktemp -d)
rsync -a --exclude='.git' --exclude='.worktrees' "$REPO_ROOT/" "$TMP_INIT/"
cd "$TMP_INIT"
git init -q -b main
git -c user.email=t@x -c user.name=t commit --allow-empty -q -m baseline
# Pass empty answer to compliance_domain prompt (default = none, no compliance opt-in)
echo | bash scripts/init.sh --profile project "Test" "TST" "desc" "test@x.com" >/dev/null 2>&1
RC=$?
assert "T-INIT-PROFILE: exit 0" "[ \"$RC\" = '0' ]"
assert "T-INIT-PROFILE: scaffold project применён" "[ -d content/00-project/plans ]"
cd "$REPO_ROOT"
rm -rf "$TMP_INIT"

# ===== T-INIT-PROFILE-KB: init с --profile kb-team =====
echo ""
echo "==> T-INIT-PROFILE-KB: init с --profile kb-team"
TMP_INIT_KB=$(mktemp -d)
rsync -a --exclude='.git' --exclude='.worktrees' "$REPO_ROOT/" "$TMP_INIT_KB/"
cd "$TMP_INIT_KB"
git init -q -b main
git -c user.email=t@x -c user.name=t commit --allow-empty -q -m baseline
bash scripts/init.sh --profile kb-team "Test" "TST" "desc" "test@x.com" >/dev/null 2>&1
RC=$?
assert "T-INIT-PROFILE-KB: exit 0" "[ \"$RC\" = '0' ]"
assert "T-INIT-PROFILE-KB: 30-runbooks существует" "[ -d content/30-runbooks ]"
assert "T-INIT-PROFILE-KB: 30-requirements удалена" "[ ! -d content/30-requirements ]"
assert "T-W3-A7: 00-project удалена для kb-team" "[ ! -d content/00-project ]"

# T-W4a-P3-demo: kb-team override applied end-to-end
TW_PATH="$TMP_INIT_KB/.claude/plugins/project/agents/tech-writer-agent.md"
assert "T-W4a-P3-demo: tech-writer-agent.md существует после init kb-team" "[ -f \"$TW_PATH\" ]"
assert "T-W4a-P3-demo: GENERATED marker в resolved файле" "grep -qF 'GENERATED by scripts/_resolve_agents.py' \"$TW_PATH\""
assert "T-W4a-P3-demo: override-секция (Internal team tech writer) применена" "grep -qF 'Internal team tech writer' \"$TW_PATH\""

cd "$REPO_ROOT"
rm -rf "$TMP_INIT_KB"

# ===== T-W4a-P4: kb-product profile end-to-end =====
echo ""
echo "==> T-W4a-P4: kb-product profile end-to-end"
TMP_INIT_KP=$(mktemp -d)
rsync -a --exclude='.git' --exclude='.worktrees' "$REPO_ROOT/" "$TMP_INIT_KP/"
cd "$TMP_INIT_KP"
git init -q -b main
git -c user.email=t@x -c user.name=t commit --allow-empty -q -m baseline

# T-W4a-P4-init: init.sh exit 0
bash scripts/init.sh --profile kb-product "TestProduct" "TP" "test description" "test@x.com" >/dev/null 2>&1
RC=$?
assert "T-W4a-P4-init: exit 0" "[ \"$RC\" = '0' ]"

# T-W4a-P4-scaffold: 4 раздела созданы (getting-started, guides, reference, troubleshooting)
assert "T-W4a-P4-scaffold: getting-started/_index.md" "[ -f content/getting-started/_index.md ]"
assert "T-W4a-P4-scaffold: guides/_index.md" "[ -f content/guides/_index.md ]"
assert "T-W4a-P4-scaffold: reference/_index.md" "[ -f content/reference/_index.md ]"
assert "T-W4a-P4-scaffold: troubleshooting/_index.md" "[ -f content/troubleshooting/_index.md ]"

# T-W4a-P4-override: tech-writer override applied (Customer-facing + GENERATED marker)
TW_KP_PATH="$TMP_INIT_KP/.claude/plugins/project/agents/tech-writer-agent.md"
assert "T-W4a-P4-override: tech-writer-agent.md существует" "[ -f \"$TW_KP_PATH\" ]"
assert "T-W4a-P4-override: Customer-facing секция применена" "grep -qF 'Customer-facing tech writer' \"$TW_KP_PATH\""
assert "T-W4a-P4-override: GENERATED marker в resolved файле" "grep -qF 'GENERATED by scripts/_resolve_agents.py' \"$TW_KP_PATH\""

# T-W4a-P4-noise: internal-only разделы удалены (op: delete)
assert "T-W4a-P4-noise: 00-project удалена" "[ ! -d content/00-project ]"
assert "T-W4a-P4-noise: 10-domain удалена" "[ ! -d content/10-domain ]"
assert "T-W4a-P4-noise: 30-requirements удалена" "[ ! -d content/30-requirements ]"
assert "T-W4a-P4-noise: 40-architecture удалена" "[ ! -d content/40-architecture ]"
assert "T-W4a-P4-noise: 60-implementation удалена" "[ ! -d content/60-implementation ]"
assert "T-W4a-P4-noise: 70-operations удалена" "[ ! -d content/70-operations ]"

cd "$REPO_ROOT"
rm -rf "$TMP_INIT_KP"

# ===== T-LEGACY: init без --profile fallback на project =====
echo ""
echo "==> T-LEGACY: init без --profile fallback на project"
TMP_LEG=$(mktemp -d)
rsync -a --exclude='.git' --exclude='.worktrees' "$REPO_ROOT/" "$TMP_LEG/"
cd "$TMP_LEG"
git init -q -b main
git -c user.email=t@x -c user.name=t commit --allow-empty -q -m baseline
echo | bash scripts/init.sh "Test" "TST" "desc" "test@x.com" >/dev/null 2>&1
RC=$?
assert "T-LEGACY: exit 0" "[ \"$RC\" = '0' ]"
assert "T-LEGACY: project scaffold применён" "[ -d content/00-project/plans ]"
cd "$REPO_ROOT"
rm -rf "$TMP_LEG"

# ===== T-W3-F3: pre-commit hook setup =====
echo ""
echo "==> T-W3-F3: pre-commit hook"
TMP_F3=$(mktemp -d)
rsync -a --exclude='.git' --exclude='.worktrees' "$REPO_ROOT/" "$TMP_F3/"
cd "$TMP_F3"
git init -q -b main && git add -A && git -c user.email=t@x -c user.name=t commit -q -m baseline

# Активировать hooks
bash scripts/install-hooks.sh >/dev/null 2>&1
HP=$(git config --get core.hooksPath)
assert "T-W3-F3: install-hooks устанавливает core.hooksPath" "[ \"$HP\" = '.githooks' ]"
assert "T-W3-F3: .githooks/pre-commit executable" "[ -x .githooks/pre-commit ]"

# Test bypass: --no-verify обходит hook
echo "test" > test_bypass.txt
git add test_bypass.txt
git -c user.email=t@x -c user.name=t commit -m "bypass" --no-verify >/dev/null 2>&1
RC=$?
assert "T-W3-F3: --no-verify обходит hook" "[ \"$RC\" = '0' ]"

cd "$REPO_ROOT"
rm -rf "$TMP_F3"

# ===== T-W3-F4: scripts/check.sh =====
echo ""
echo "==> T-W3-F4: scripts/check.sh"
TMP_F4=$(mktemp -d)
rsync -a --exclude='.git' --exclude='.worktrees' "$REPO_ROOT/" "$TMP_F4/"
cd "$TMP_F4"
git init -q -b main && git add -A && git -c user.email=t@x -c user.name=t commit -q -m baseline

# T-W3-F4-fast: --fast exit 0
bash scripts/check.sh --fast >/dev/null 2>&1
RC=$?
assert "T-W3-F4-fast: --fast exit 0" "[ \"$RC\" = '0' ]"

# T-W3-F4-help: --help exit 0
bash scripts/check.sh --help >/dev/null 2>&1
RC=$?
assert "T-W3-F4-help: --help exit 0" "[ \"$RC\" = '0' ]"

# T-W3-F4-invalid: --invalid exit 2
set +e
bash scripts/check.sh --invalid >/dev/null 2>&1
RC=$?
set -e
assert "T-W3-F4-invalid: --invalid exit 2" "[ \"$RC\" = '2' ]"

# Note: --full запускает test-template.sh recursively; не запускаем здесь
# чтобы избежать infinite loop. Smoke --full делает Phase 6 / T21.

cd "$REPO_ROOT"
rm -rf "$TMP_F4"

# ===== T-W3-A1: on_value mutation end-to-end =====
echo ""
echo "==> T-W3-A1: on_value mutation (compliance_domain=152-fz → subagents.compliance: core)"
TMP_W3A1=$(mktemp -d)
rsync -a --exclude='.git' --exclude='.worktrees' "$REPO_ROOT/" "$TMP_W3A1/"
cd "$TMP_W3A1"
git init -q -b main
git -c user.email=t@x -c user.name=t commit --allow-empty -q -m baseline

# Выполняем helper напрямую с INIT_PROMPT — проверяем mutation в manifest in-memory
RESULT=$(INIT_PROMPT_compliance_domain=152-fz python3 -c "
import sys
sys.path.insert(0, 'scripts')
from _apply_profile import load_manifest, apply_on_value_mutations
from pathlib import Path
m = load_manifest(Path('docs/overlays/profiles/project'))
apply_on_value_mutations(m)
print(m['subagents']['compliance'])
" 2>&1)
assert "T-W3-A1: with 152-fz, compliance → core" "[ \"$RESULT\" = 'core' ]"

# Без INIT_PROMPT — compliance остаётся optional (default = none, none не имеет on_value mapping)
RESULT_NO=$(python3 -c "
import sys
sys.path.insert(0, 'scripts')
from _apply_profile import load_manifest, apply_on_value_mutations
from pathlib import Path
m = load_manifest(Path('docs/overlays/profiles/project'))
apply_on_value_mutations(m)
print(m['subagents']['compliance'])
" 2>&1)
assert "T-W3-A1: без env, compliance → optional (default=none)" "[ \"$RESULT_NO\" = 'optional' ]"

# Проверяем end-to-end через init.sh (non-interactive с INIT_SKIP_PROMPTS=1 default)
INIT_PROMPT_compliance_domain=152-fz INIT_SKIP_PROMPTS=1 bash scripts/init.sh --profile project "TestE2E" "TE" "desc" "t@x.com" >/dev/null 2>&1
RC=$?
assert "T-W3-A1: init.sh с INIT_PROMPT_compliance_domain=152-fz exit 0" "[ \"$RC\" = '0' ]"
cd "$REPO_ROOT"
rm -rf "$TMP_W3A1"

# ===== Summary =====
echo ""
echo "==> Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
echo "✓ Template smoke test PASSED"
