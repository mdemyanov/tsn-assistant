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
