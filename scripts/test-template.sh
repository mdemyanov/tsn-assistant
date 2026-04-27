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
git init -q -b main
git add -A
git commit -q -m "test baseline"

# ===== T1: JSON validity =====
echo ""
echo "==> T1: JSON files valid"
assert "settings.json valid" "python3 -c 'import json; json.load(open(\".claude/settings.json\"))'"
assert "plugin.json valid" "python3 -c 'import json; json.load(open(\".claude/plugins/project-template/.claude-plugin/plugin.json\"))'"

# ===== T2: agent frontmatter =====
echo ""
echo "==> T2: agent frontmatter complete"
for agent in pm ba sa dev devops researcher; do
  file=".claude/plugins/project-template/agents/${agent}-agent.md"
  count=$(head -10 "$file" | grep -cE '^(name|description|model):' || true)
  assert "$agent-agent.md has 3 frontmatter fields" "[ \"$count\" -eq 3 ]"
done

# ===== T3: command frontmatter =====
echo ""
echo "==> T3: command files have description"
for cmd in pm pm-review ba sa dev devops research; do
  file=".claude/plugins/project-template/commands/${cmd}.md"
  assert "$cmd.md exists" "[ -f \"$file\" ]"
  assert "$cmd.md has description" "head -5 \"$file\" | grep -q '^description:'"
done

# ===== T4: content scaffold =====
echo ""
echo "==> T4: content scaffold present"
assert ".doc-root.yaml exists" "[ -f content/.doc-root.yaml ]"
assert "00-project README" "[ -f content/00-project/README.md ]"
assert "30-requirements README" "[ -f content/30-requirements/README.md ]"
assert "40-architecture README" "[ -f content/40-architecture/README.md ]"
assert "60-implementation README" "[ -f content/60-implementation/README.md ]"
assert "70-operations README" "[ -f content/70-operations/README.md ]"
assert "glossary.md exists" "[ -f content/10-domain/glossary.md ]"

# ===== T5: init.sh works =====
echo ""
echo "==> T5: init.sh substitutes PROJECT_NAME and creates branch"
# README.md может отсутствовать (Task 22 создаст top-level README) — создадим заглушку
# с {{PROJECT_NAME}} для совместимости теста с любым состоянием шаблона.
if [[ ! -f README.md ]]; then
  echo "# {{PROJECT_NAME}}" > README.md
  git add README.md
  git commit -q -m "stub README for test"
fi
bash scripts/init.sh "test-project" >/dev/null
assert "PROJECT_NAME replaced in CLAUDE.md" "! grep -q '{{PROJECT_NAME}}' CLAUDE.md"
assert "PROJECT_NAME replaced in AGENTS.md" "! grep -q '{{PROJECT_NAME}}' AGENTS.md"
assert "test-project name appears" "grep -q 'test-project' CLAUDE.md"
assert "private branch created" "git show-ref --verify --quiet refs/heads/private"
assert ".env created" "[ -f .env ]"

# ===== T6: apply-overlay.sh works =====
echo ""
echo "==> T6: apply-overlay.sh idempotent"
git add -A
git commit -q -m "after init"
bash scripts/apply-overlay.sh naumen-smp >/dev/null
assert "marker in CLAUDE.md after apply" "grep -q 'OVERLAY:naumen-smp:start' CLAUDE.md"
git add -A
git commit -q -m "after apply"
bash scripts/apply-overlay.sh naumen-smp >/dev/null
DIFF_LINES="$(git diff --stat | wc -l | tr -d ' ')"
assert "second apply produces no diff" "[ \"$DIFF_LINES\" = '0' ]"
bash scripts/apply-overlay.sh --remove naumen-smp >/dev/null
assert "marker removed from CLAUDE.md" "! grep -q 'OVERLAY:naumen-smp:start' CLAUDE.md"

# ===== Summary =====
echo ""
echo "==> Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
echo "✓ Template smoke test PASSED"
