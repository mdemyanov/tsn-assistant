#!/usr/bin/env bash
# test-spdd-integration.sh — QA-001: запускает все 4 failing stubs эпика spdd-integration
#
# Usage:
#   bash scripts/test-spdd-integration.sh
#
# Ожидаемый результат до Dev-фазы: все 4 теста RED (failed).
# После Dev-фазы: все 4 теста GREEN (passed).
#
# Тесты покрывают:
#   BA-001 Two-way sync — test_two_way_sync_in_claude_md.py
#   BA-002 Safeguards section — test_safeguards_section_template.py
#   BA-003 Drift-check — test_pm_review_drift_check.py
#   BA-003 Manifest drift_pairs — test_drift_pairs_in_manifests.py

set -uo pipefail

# uv-guard: обязательная зависимость
if ! command -v uv >/dev/null 2>&1; then
  echo "ERROR: 'uv' не найден в PATH." >&2
  echo "Установите: https://docs.astral.sh/uv/getting-started/installation/" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

TESTS=(
  "$REPO_ROOT/scripts/tests/test_drift_pairs_in_manifests.py"
  "$REPO_ROOT/scripts/tests/test_safeguards_section_template.py"
  "$REPO_ROOT/scripts/tests/test_pm_review_drift_check.py"
  "$REPO_ROOT/scripts/tests/test_two_way_sync_in_claude_md.py"
)

PASS=0
FAIL=0

for t in "${TESTS[@]}"; do
  echo ""
  echo "=== $(basename "$t") ==="
  set +e
  uv run "$t" -v
  RC=$?
  set -e
  if [ "$RC" -eq 0 ]; then
    PASS=$((PASS + 1))
    echo "  -> PASSED"
  else
    FAIL=$((FAIL + 1))
    echo "  -> FAILED (expected RED before Dev-phase)"
  fi
done

echo ""
echo "============================================"
echo "Results: $PASS passed, $FAIL failed"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
  echo "RED phase: $FAIL test file(s) failing — expected before Dev implementation."
  # Не выходим с кодом 1 в RED-фазе чтобы CI-runner мог увидеть полный вывод
  # Раскомментируй 'exit 1' когда переходишь в GREEN-phase gate
  # exit 1
fi

echo ""
echo "QA-001 stub run complete."
