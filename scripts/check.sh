#!/usr/bin/env bash
# check.sh — single entry-point для всех валидаций.
#
# Usage:
#   bash scripts/check.sh [--fast | --full]
#
# --fast (default): validate-content + validate-profile (~3 сек total)
# --full: + test-validate-content + test-validate-profile + test-template (~30 сек)

set -euo pipefail

MODE="${1:---fast}"

case "$MODE" in
  --fast|--full|-h|--help) ;;
  *)
    echo "Usage: $0 [--fast | --full]" >&2
    exit 2
    ;;
esac

if [[ "$MODE" == "-h" ]] || [[ "$MODE" == "--help" ]]; then
  cat <<EOF
Usage: $0 [--fast | --full]

Modes:
  --fast (default)  Run validators only (validate-content.py + validate-profile.py).
                    Quick gate (~3 sec). Suitable for pre-commit hook.
  --full            Run validators + full test suite (test-validate-content,
                    test-validate-profile, test-template). Comprehensive
                    smoke (~30 sec). Suitable for CI / pre-merge gate.

Exit codes:
  0  All checks passed
  1  Validator or test failed
  2  Invalid usage
EOF
  exit 0
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

failed=0
run_check() {
  local name="$1" cmd="$2"
  echo "▶ $name"
  if eval "$cmd"; then
    echo "  ✓ $name"
  else
    echo "  ✗ $name FAILED" >&2
    failed=1
  fi
}

run_check "validate-content.py" "python3 scripts/validate-content.py"
run_check "validate-profile.py" "python3 scripts/validate-profile.py"

if [[ "$MODE" == "--full" ]]; then
  run_check "test-validate-content.sh" "bash scripts/test-validate-content.sh"
  run_check "test-validate-profile.sh" "bash scripts/test-validate-profile.sh"
  run_check "test-resolve-agents.sh" "bash scripts/test-resolve-agents.sh"
  run_check "test-template.sh" "bash scripts/test-template.sh"
fi

if [[ "$failed" -ne 0 ]]; then
  echo "" >&2
  echo "✗ check.sh $MODE — FAILED" >&2
  exit 1
fi

echo ""
echo "✓ check.sh $MODE — passed"
