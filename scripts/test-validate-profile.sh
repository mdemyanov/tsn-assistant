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

echo ""
echo "==> Results: $PASS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
echo "✓ test-validate-profile.sh PASSED"
