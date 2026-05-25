#!/usr/bin/env bash
# test-template.sh — meta-test шаблона: запускает все основные тесты.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "==> Test: validate-content"
bash scripts/test-validate-content.sh

echo "==> Test: init flow (TSN smoke)"
bash scripts/test-init-tsn.sh

echo "==> Test: agents и commands counts"
AGENTS_COUNT=$(ls .claude/plugins/project/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
COMMANDS_COUNT=$(ls .claude/plugins/project/commands/*.md 2>/dev/null | wc -l | tr -d ' ')
[[ "$AGENTS_COUNT" -eq 8 ]] || { echo "FAIL: expected 8 agents, got $AGENTS_COUNT"; exit 1; }
[[ "$COMMANDS_COUNT" -eq 19 ]] || { echo "FAIL: expected 19 commands (init + 7 agent-invokes + 4 management + 7 document), got $COMMANDS_COUNT"; exit 1; }

echo "==> PASS: test-template"
