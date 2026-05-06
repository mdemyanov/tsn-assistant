#!/usr/bin/env bash
# test-validate-content.sh — тесты для scripts/validate-content.py
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$REPO_ROOT/scripts/validate-content.py"

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

setup_tmp_content() {
  TMP="$(mktemp -d)"
  trap "rm -rf $TMP" EXIT
  mkdir -p "$TMP/content"
  cat > "$TMP/content/.doc-root.yaml" <<'YAML'
title: Test
description: Test catalog
syntax: XML
language: ru
properties:
  - name: Тип контента
    type: Enum
    values:
      - ADR
      - Требование
filterProperties: [Тип контента]
YAML
  echo "$TMP"
}

# ===== T0: --help работает =====
echo "==> T0: --help"
assert "validator --help прошёл" "python3 \"$VALIDATOR\" --help >/dev/null 2>&1"

echo ""
echo "==> Results: $PASS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
echo "✓ test-validate-content.sh PASSED"
