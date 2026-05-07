#!/usr/bin/env bash
# Unit tests for scripts/_resolve_agents.py merge_delta function.
set -euo pipefail

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

RESULT=$(python3 "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/tech-writer.md")
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

RESULT=$(python3 "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md")
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

RESULT=$(python3 "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md")
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

RESULT=$(python3 "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md")
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

RESULT=$(python3 "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md")
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

RESULT=$(python3 "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md")
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

if python3 "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md" 2>/dev/null; then
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

if python3 "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md" 2>/dev/null; then
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

if python3 "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md" 2>/dev/null; then
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

RESULT=$(python3 "$ROOT/scripts/_resolve_agents.py" --merge-only "$TMPDIR/base.md" "$TMPDIR/r.md")
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

python3 "$ROOT/scripts/_resolve_agents.py" "$PROFILE" --base-dir "$BASE" --target-dir "$TARGET" \
    || { echo "FAIL: T11 main flow should succeed"; exit 1; }

# Disabled role NOT written
[[ -f "$TARGET/inactive-agent.md" ]] && { echo "FAIL: T11 disabled role inactive-agent.md should NOT be in target"; exit 1; }

# Active role written + has GENERATED marker
[[ -f "$TARGET/active-agent.md" ]] || { echo "FAIL: T11 active-agent.md missing in target"; exit 1; }
grep -qF "GENERATED by scripts/_resolve_agents.py" "$TARGET/active-agent.md" \
    || { echo "FAIL: T11 GENERATED marker missing in active-agent.md"; exit 1; }
echo "  ✓"

echo "✓ All tests passed"
