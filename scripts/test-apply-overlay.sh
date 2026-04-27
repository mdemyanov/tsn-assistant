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
assert "marker in ba-agent.md" "grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project-template/agents/ba-agent.md"
assert "marker in sa-agent.md" "grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project-template/agents/sa-agent.md"
assert "marker in dev-agent.md" "grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project-template/agents/dev-agent.md"
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
assert "no marker in ba-agent.md after remove" "! grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project-template/agents/ba-agent.md"
assert "no marker in sa-agent.md after remove" "! grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project-template/agents/sa-agent.md"
assert "no marker in dev-agent.md after remove" "! grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project-template/agents/dev-agent.md"
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

# ===== Summary =====
echo ""
echo "==> Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
