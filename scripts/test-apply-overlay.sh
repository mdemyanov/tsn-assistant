#!/usr/bin/env bash
# Тесты для apply-overlay.sh.
# Запускает на временной копии репо.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

# Подготовка: копируем репо в TMP, исключая .git
echo "==> Setting up test repo at $TMP"
rsync -a --exclude='.git' --exclude='.worktrees' "$REPO_ROOT/" "$TMP/"
cd "$TMP"
GIT_TEST="git -c user.email=test@example.com -c user.name=test"
git init -q -b main
git add -A
$GIT_TEST commit -q -m "test baseline"

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
    echo "    failed condition: $cond"
    FAIL=$((FAIL+1))
  fi
}

# ===== Test 1: apply вставляет маркеры =====
echo ""
echo "==> Test 1: apply inserts markers"
bash scripts/apply-overlay.sh naumen-smp >/dev/null
assert "marker in CLAUDE.md" "grep -q 'OVERLAY:naumen-smp:start' CLAUDE.md"
assert "marker in ba-agent.md" "grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project/agents/ba-agent.md"
assert "marker in sa-agent.md" "grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project/agents/sa-agent.md"
assert "marker in dev-agent.md" "grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project/agents/dev-agent.md"
assert "FQN term in glossary" "grep -q 'FQN' content/10-domain/glossary.md"
assert "Scenario property in doc-root.yaml" "grep -q 'Сценарий' content/.doc-root.yaml"

# ===== Test 2: повторный apply идемпотентен =====
echo ""
echo "==> Test 2: second apply is idempotent (no diff)"
git add -A
$GIT_TEST commit -q -m "after first apply"
bash scripts/apply-overlay.sh naumen-smp >/dev/null
DIFF_LINES="$(git diff --stat | wc -l | tr -d ' ')"
assert "no diff after second apply" "[ \"$DIFF_LINES\" = '0' ]"

# ===== Test 3: remove убирает маркеры =====
echo ""
echo "==> Test 3: --remove deletes markers"
bash scripts/apply-overlay.sh --remove naumen-smp >/dev/null
assert "no marker in CLAUDE.md after remove" "! grep -q 'OVERLAY:naumen-smp:start' CLAUDE.md"
assert "no marker in ba-agent.md after remove" "! grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project/agents/ba-agent.md"
assert "no marker in sa-agent.md after remove" "! grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project/agents/sa-agent.md"
assert "no marker in dev-agent.md after remove" "! grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project/agents/dev-agent.md"
assert "no marker in glossary.md" "! grep -q 'OVERLAY:naumen-smp:start' content/10-domain/glossary.md"
assert "no marker in .doc-root.yaml" "! grep -q 'OVERLAY:naumen-smp:start' content/.doc-root.yaml"

# ===== Test 4: повторный remove не падает =====
echo ""
echo "==> Test 4: --remove twice is no-op"
bash scripts/apply-overlay.sh --remove naumen-smp >/dev/null
echo "  ✓ second remove did not error"
PASS=$((PASS+1))

# ===== Test 5: apply→remove→apply возвращает то же состояние =====
echo ""
echo "==> Test 5: apply→remove→apply round-trip"
bash scripts/apply-overlay.sh naumen-smp >/dev/null
HASH1=$(git diff --stat | shasum | awk '{print $1}')
bash scripts/apply-overlay.sh --remove naumen-smp >/dev/null
bash scripts/apply-overlay.sh naumen-smp >/dev/null
HASH2=$(git diff --stat | shasum | awk '{print $1}')
assert "round-trip produces same diff" "[ \"$HASH1\" = \"$HASH2\" ]"

# ===== Test T-W4b-T10: negative — bad dotted path → exit code 1 =====
echo ""
echo "==> Test T-W4b-T10: negative: apply_dotted_mutation на несуществующий path"
TMP_T10=$(mktemp -d)
mkdir -p "$TMP_T10/docs/overlays/profiles/test-bad-mutation"
cat > "$TMP_T10/docs/overlays/profiles/test-bad-mutation/manifest.yaml" <<EOF
schema_version: 1
name: test-bad-mutation
description: typo'ed mutation path для negative test
audience: tests
status: stub
subagents: {}
pipelines: {}
init_prompts:
  - id: bad
    type: enum
    choices: [yes]
    default: yes
    on_value:
      yes:
        nonexistent.section: core
operations: []
compatible_stacks: []
maintainer: tests
EOF
ln -s "$TMP/scripts" "$TMP_T10/scripts"
OLDPWD_T10="$PWD"
cd "$TMP_T10"
rc=0
INIT_PROMPT_bad=yes python3 scripts/_apply_profile.py docs/overlays/profiles/test-bad-mutation 2>/dev/null || rc=$?
cd "$OLDPWD_T10"
rm -rf "$TMP_T10"
assert "T-W4b-T10: bad mutation → exit code 1" "[ \"$rc\" = '1' ]"

# ===== Test T-W4b-T10b: ProfileError raised, не SystemExit =====
echo ""
echo "==> Test T-W4b-T10b: ProfileError raised, не SystemExit"
TMP_T10B=$(mktemp -d)
mkdir -p "$TMP_T10B/docs/overlays/profiles/test-bad-mutation-2"
cat > "$TMP_T10B/docs/overlays/profiles/test-bad-mutation-2/manifest.yaml" <<EOF
schema_version: 1
name: test-bad-mutation-2
description: typo'ed mutation path
audience: tests
status: stub
subagents: {}
pipelines: {}
init_prompts:
  - id: bad
    type: enum
    choices: [yes]
    default: yes
    on_value:
      yes:
        nonexistent.section: core
operations: []
compatible_stacks: []
maintainer: tests
EOF
ln -s "$TMP/scripts" "$TMP_T10B/scripts"
OLDPWD_T10B="$PWD"
cd "$TMP_T10B"

result=$(INIT_PROMPT_bad=yes python3 -c "
import sys
sys.path.insert(0, 'scripts')
import importlib.util
spec = importlib.util.spec_from_file_location('apply_profile', 'scripts/_apply_profile.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
try:
    manifest = mod.load_manifest(__import__('pathlib').Path('docs/overlays/profiles/test-bad-mutation-2'))
    mod.apply_on_value_mutations(manifest)
    print('NO_EXCEPTION')
except Exception as e:
    if hasattr(mod, 'ProfileError') and isinstance(e, mod.ProfileError):
        print('OK_ProfileError')
    elif isinstance(e, SystemExit):
        print('FAIL_SystemExit')
    else:
        print('UNKNOWN: ' + type(e).__name__)
" 2>&1 | tail -1)
cd "$OLDPWD_T10B"
rm -rf "$TMP_T10B"
assert "T-W4b-T10b: ProfileError exception type (не SystemExit)" "[ \"$result\" = 'OK_ProfileError' ]"

# ===== Test T-W4b-T12: multiline reason stripped in JSON plan =====

echo "[T-W4b-T12] multiline reason → стриплен в TSV"
TMP_T12=$(mktemp -d)
mkdir -p "$TMP_T12/docs/overlays/profiles/test-multiline-reason"
cat > "$TMP_T12/docs/overlays/profiles/test-multiline-reason/manifest.yaml" <<'EOF'
schema_version: 1
name: test-multiline-reason
description: multiline reason tests TSV emission
audience: tests
status: stub
subagents: {}
pipelines: {}
content_scaffold: scaffold/
operations:
  - op: add
    source: scaffold/
    target: content/
    reason: |
      first line
      second line
      third
init_prompts: []
compatible_stacks: []
maintainer: tests
EOF
mkdir -p "$TMP_T12/docs/overlays/profiles/test-multiline-reason/scaffold"
echo "# scaffold" > "$TMP_T12/docs/overlays/profiles/test-multiline-reason/scaffold/_index.md"
ln -s "$TMP/scripts" "$TMP_T12/scripts"
OLDPWD_T12="$PWD"
cd "$TMP_T12"
plan=$(python3 scripts/_apply_profile.py docs/overlays/profiles/test-multiline-reason)
cd "$OLDPWD_T12"
rm -rf "$TMP_T12"

# Reason в JSON не должен содержать \n (multiline стрипнут в одну строку)
reason_field=$(echo "$plan" | python3 -c "import json, sys; p=json.load(sys.stdin); print(p['ops'][0]['reason'])")
assert "T-W4b-T12: multiline reason одной строкой" "[ \"\$(echo \"$reason_field\" | wc -l | tr -d ' ')\" = '1' ]"
assert "T-W4b-T12: multiline reason содержит части" "echo \"$reason_field\" | grep -q 'first line.*second line.*third'"

# ===== Summary =====
echo ""
echo "==> Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
