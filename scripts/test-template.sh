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

# ===== T4: content scaffold =====
echo ""
echo "==> T4: content scaffold present (_index.md везде)"
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

# ===== T5: init.sh works =====
echo ""
echo "==> T5: init.sh substitutes PROJECT_NAME and creates branch"
INIT_SKIP_GIT_RESET=1 bash scripts/init.sh "test-project" "TEST-PROJECT" "Test description" "test@example.com" >/dev/null
assert "PROJECT_NAME replaced in CLAUDE.md" "! grep -q '{{PROJECT_NAME}}' CLAUDE.md"
assert "PROJECT_NAME replaced in content/_index.md" "! grep -q '{{PROJECT_NAME}}' content/_index.md"
assert "PROJECT_NAME replaced in AGENTS.md" "! grep -q '{{PROJECT_NAME}}' AGENTS.md"
assert "test-project name appears" "grep -q 'test-project' CLAUDE.md"
assert "private branch created" "git show-ref --verify --quiet refs/heads/private"
assert ".env created" "[ -f .env ]"

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

# ===== Summary =====
echo ""
echo "==> Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
echo "✓ Template smoke test PASSED"
