#!/usr/bin/env bash
# Unit tests for scripts/_resolve_agents.py merge_delta function.
set -euo pipefail

# uv-guard: обязательная зависимость
if ! command -v uv >/dev/null 2>&1; then
  echo "ERROR: 'uv' не найден в PATH. Установите: https://docs.astral.sh/uv/getting-started/installation/" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap "rm -rf $TMPDIR" EXIT

assert_equal() {
    local actual="$1"
    local expected="$2"
    local msg="$3"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: $msg"
        echo "  actual:   $actual"
        echo "  expected: $expected"
        exit 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="$3"
    if ! grep -qF -- "$needle" <<< "$haystack"; then
        echo "FAIL: $msg"
        echo "  haystack: $haystack"
        echo "  needle:   $needle"
        exit 1
    fi
}

# T1: frontmatter scalar replace
echo "▶ T1: frontmatter scalar replace"
cat > "$TMPDIR/base.md" <<'EOF'
---
name: tech-writer
description: Generic writer
model: opus
---

## Роль
Generic.
EOF

cat > "$TMPDIR/tech-writer.md" <<'EOF'
---
extends: tech-writer
description: Customer-facing writer
---

## Роль
Customer-facing.
EOF

RESULT=$(uv run "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/tech-writer.md")
assert_contains "$RESULT" "description: Customer-facing writer" "T1: description should be replaced"
assert_contains "$RESULT" "model: opus" "T1: model should inherit from base"
assert_contains "$RESULT" "name: tech-writer" "T1: name should inherit from base"
assert_contains "$RESULT" "Customer-facing." "T1: section content should be from override"
echo "  ✓"

# T2: section in override replaces base section
echo "▶ T2: section override replace"
cat > "$TMPDIR/base.md" <<'EOF'
---
name: r
---

## Роль
Generic role.

## Constraints
Generic constraints.
EOF

cat > "$TMPDIR/r.md" <<'EOF'
---
extends: r
---

## Роль
Specific role.
EOF

RESULT=$(uv run "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md")
assert_contains "$RESULT" "Specific role." "T2: override section should replace"
assert_contains "$RESULT" "Generic constraints." "T2: untouched section should inherit"
echo "  ✓"

# T3: section in base inherits when override doesn't have it
echo "▶ T3: base section inherits"
# Already covered by T2 (Constraints inherited) — but test minimal override
cat > "$TMPDIR/r.md" <<'EOF'
---
extends: r
description: minimal
---
EOF

RESULT=$(uv run "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md")
assert_contains "$RESULT" "Generic role." "T3: base section inherited when override empty"
assert_contains "$RESULT" "Generic constraints." "T3: all base sections inherited"
echo "  ✓"

# T4: section in override but not in base — appended
echo "▶ T4: section append"
cat > "$TMPDIR/r.md" <<'EOF'
---
extends: r
---

## Domain
Customer-facing only.
EOF

RESULT=$(uv run "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md")
assert_contains "$RESULT" "Generic role." "T4: base sections inherited"
assert_contains "$RESULT" "Customer-facing only." "T4: new section appended"
echo "  ✓"

# T5: empty override body — full inheritance (alias of T3 but checks frontmatter merge too)
echo "▶ T5: empty body inheritance + frontmatter merge"
cat > "$TMPDIR/r.md" <<'EOF'
---
extends: r
description: Specialized
---
EOF

RESULT=$(uv run "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md")
assert_contains "$RESULT" "Generic role." "T5: section inherited when override has no body"
assert_contains "$RESULT" "description: Specialized" "T5: frontmatter merged"
echo "  ✓"

# T6: {{super}} substitution
echo "▶ T6: {{super}} substitution"
cat > "$TMPDIR/base.md" <<'EOF'
---
name: r
---

## Constraints
- Be concise.
- Use markdown.
EOF

cat > "$TMPDIR/r.md" <<'EOF'
---
extends: r
---

## Constraints
{{super}}
- Pin product version in every doc.
EOF

RESULT=$(uv run "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md")
assert_contains "$RESULT" "Be concise." "T6: {{super}} substituted with base content"
assert_contains "$RESULT" "Pin product version" "T6: extending content kept"
echo "  ✓"

# T7: {{super}} in section not in base → error
echo "▶ T7: {{super}} without base section"
cat > "$TMPDIR/r.md" <<'EOF'
---
extends: r
---

## NewSection
{{super}}
- something
EOF

if uv run "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md" 2>/dev/null; then
    echo "FAIL: T7 should have errored on {{super}} without base section"
    exit 1
fi
echo "  ✓"

# T8: missing extends → error
echo "▶ T8: missing extends"
cat > "$TMPDIR/r.md" <<'EOF'
---
description: bad override
---

## Роль
Whatever.
EOF

if uv run "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md" 2>/dev/null; then
    echo "FAIL: T8 should have errored on missing extends"
    exit 1
fi
echo "  ✓"

# T9: extends mismatch → error
echo "▶ T9: extends mismatch"
cat > "$TMPDIR/r.md" <<'EOF'
---
extends: someone-else
---
EOF

if uv run "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md" 2>/dev/null; then
    echo "FAIL: T9 should have errored on extends mismatch (extends 'someone-else' but file is 'r.md')"
    exit 1
fi
echo "  ✓"

# T10: list-field full replace
echo "▶ T10: list field replace"
cat > "$TMPDIR/base.md" <<'EOF'
---
name: r
tools:
  - Read
  - Write
  - Edit
---

## Роль
Generic.
EOF

cat > "$TMPDIR/r.md" <<'EOF'
---
extends: r
tools:
  - Read
---
EOF

RESULT=$(uv run "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md")
assert_contains "$RESULT" "- Read" "T10: list contains override item"
if grep -q "Write" <<< "$RESULT"; then
    echo "FAIL: T10 list should be replaced, not unioned (Write should be absent)"
    exit 1
fi
echo "  ✓"

# T11: main flow — disabled subagent skipped + GENERATED marker present
echo "▶ T11: main flow (disabled skip + marker)"
TARGET="$TMPDIR/target"
PROFILE="$TMPDIR/profile"
BASE="$TMPDIR/base-agents"
mkdir -p "$BASE" "$PROFILE/agent-overrides"

# Manifest with one core role + one disabled
cat > "$PROFILE/manifest.yaml" <<'EOF'
schema_version: 1
name: testprof
subagents:
  active: core
  inactive: disabled
agent_overrides: {}
operations: []
EOF

# Base prompts for both roles
cat > "$BASE/active-agent.md" <<'EOF'
---
name: active
---

## Роль
Active role.
EOF
cat > "$BASE/inactive-agent.md" <<'EOF'
---
name: inactive
---

## Роль
Inactive role.
EOF

uv run "$ROOT/scripts/_resolve_agents.py" "$PROFILE" --base-dir "$BASE" --target-dir "$TARGET" \
    || { echo "FAIL: T11 main flow should succeed"; exit 1; }

# Disabled role NOT written
[[ -f "$TARGET/inactive-agent.md" ]] && { echo "FAIL: T11 disabled role inactive-agent.md should NOT be in target"; exit 1; }

# Active role written + has GENERATED marker
[[ -f "$TARGET/active-agent.md" ]] || { echo "FAIL: T11 active-agent.md missing in target"; exit 1; }
grep -qF "GENERATED by scripts/_resolve_agents.py" "$TARGET/active-agent.md" \
    || { echo "FAIL: T11 GENERATED marker missing in active-agent.md"; exit 1; }
echo "  ✓"

# T12: malformed override YAML → clean error
echo "▶ T12: malformed override YAML"
cat > "$TMPDIR/base.md" <<'EOF'
---
name: r
---

## Роль
Generic.
EOF

cat > "$TMPDIR/r.md" <<'EOF'
---
extends: r
description: [unclosed bracket
---

## Роль
Whatever.
EOF

ERR_OUTPUT=$(uv run "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md" 2>&1 1>/dev/null) || true
assert_contains "$ERR_OUTPUT" "malformed YAML" "T12: should report malformed YAML cleanly"
# Should NOT contain Python traceback frames
if grep -q "Traceback" <<< "$ERR_OUTPUT"; then
    echo "FAIL: T12 should not produce Python traceback"
    exit 1
fi
echo "  ✓"

# T13: malformed manifest YAML → clean error
echo "▶ T13: malformed manifest YAML"
PROFILE="$TMPDIR/badprofile"
mkdir -p "$PROFILE/agent-overrides"
cat > "$PROFILE/manifest.yaml" <<'EOF'
schema_version: 1
name: bad
subagents:
  active: [unclosed bracket
EOF
mkdir -p "$TMPDIR/base-agents-13"
cat > "$TMPDIR/base-agents-13/active-agent.md" <<'EOF'
---
name: active
---

## Роль
Test.
EOF

ERR_OUTPUT=$(uv run "$ROOT/scripts/_resolve_agents.py" "$PROFILE" --base-dir "$TMPDIR/base-agents-13" --target-dir "$TMPDIR/target-13" 2>&1 1>/dev/null) || true
assert_contains "$ERR_OUTPUT" "malformed YAML" "T13: manifest malformed → clean error"
if grep -q "Traceback" <<< "$ERR_OUTPUT"; then
    echo "FAIL: T13 should not produce Python traceback"
    exit 1
fi
echo "  ✓"

# T14: agent_overrides without 'source' field → clean error
echo "▶ T14: missing source field в agent_overrides"
PROFILE="$TMPDIR/missingsource"
mkdir -p "$PROFILE/agent-overrides"
cat > "$PROFILE/manifest.yaml" <<'EOF'
schema_version: 1
name: nosource
subagents:
  active: core
agent_overrides:
  active:
operations: []
EOF
mkdir -p "$TMPDIR/base-agents-14"
cat > "$TMPDIR/base-agents-14/active-agent.md" <<'EOF'
---
name: active
---

## Роль
Test.
EOF

ERR_OUTPUT=$(uv run "$ROOT/scripts/_resolve_agents.py" "$PROFILE" --base-dir "$TMPDIR/base-agents-14" --target-dir "$TMPDIR/target-14" 2>&1 1>/dev/null) || true
assert_contains "$ERR_OUTPUT" "missing 'source'" "T14: missing source field → clean error"
if grep -q "Traceback" <<< "$ERR_OUTPUT"; then
    echo "FAIL: T14 should not produce Python traceback"
    exit 1
fi
echo "  ✓"

# T-RA-QA-SPLIT: qa role special-case — no qa-agent.md → resolve qa-author + qa-runner
echo "▶ T-RA-QA-SPLIT: qa role split (no override)"
TARGET_QA="$TMPDIR/target-qa-split"
PROFILE_QA="$TMPDIR/profile-qa-split"
BASE_QA="$TMPDIR/base-agents-qa"
mkdir -p "$BASE_QA" "$PROFILE_QA/agent-overrides" "$TARGET_QA"

# Manifest with qa: core and a non-qa override (tech-writer absent in base — omit)
cat > "$PROFILE_QA/manifest.yaml" <<'EOF'
schema_version: 1
name: qa-split-test
subagents:
  qa: core
agent_overrides: {}
operations: []
EOF

# Only qa-author and qa-runner base files — NO qa-agent.md
cat > "$BASE_QA/qa-author-agent.md" <<'EOF'
---
name: qa-author
---

## Роль
QA Author role.
EOF

cat > "$BASE_QA/qa-runner-agent.md" <<'EOF'
---
name: qa-runner
---

## Роль
QA Runner role.
EOF

uv run "$ROOT/scripts/_resolve_agents.py" "$PROFILE_QA" --base-dir "$BASE_QA" --target-dir "$TARGET_QA" \
    || { echo "FAIL: T-RA-QA-SPLIT main flow should succeed"; exit 1; }

# Both qa-author-agent.md and qa-runner-agent.md must be in target
[[ -f "$TARGET_QA/qa-author-agent.md" ]] || { echo "FAIL: T-RA-QA-SPLIT qa-author-agent.md missing in target"; exit 1; }
[[ -f "$TARGET_QA/qa-runner-agent.md" ]] || { echo "FAIL: T-RA-QA-SPLIT qa-runner-agent.md missing in target"; exit 1; }

# Both must have GENERATED marker
grep -qF "GENERATED by scripts/_resolve_agents.py" "$TARGET_QA/qa-author-agent.md" \
    || { echo "FAIL: T-RA-QA-SPLIT GENERATED marker missing in qa-author-agent.md"; exit 1; }
grep -qF "GENERATED by scripts/_resolve_agents.py" "$TARGET_QA/qa-runner-agent.md" \
    || { echo "FAIL: T-RA-QA-SPLIT GENERATED marker missing in qa-runner-agent.md"; exit 1; }

# No qa-agent.md must be written (only split variants)
[[ -f "$TARGET_QA/qa-agent.md" ]] && { echo "FAIL: T-RA-QA-SPLIT qa-agent.md should NOT be in target"; exit 1; }
echo "  ✓"

echo "✓ All tests passed"
