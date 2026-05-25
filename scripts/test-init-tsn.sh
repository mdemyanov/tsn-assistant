#!/usr/bin/env bash
# test-init-tsn.sh — smoke-test полного init flow для ТСН.
# Запускает scripts/init.sh с фиктивными параметрами в временной директории,
# проверяет, что все плейсхолдеры заменены, content scaffold заполнен, validate-content.py зелёный.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap "rm -rf $TMPDIR" EXIT

echo "==> Setup: copying template to $TMPDIR"
# Копируем .git, content, scripts, .claude*, AGENTS.md, CLAUDE.md, README.md, .env.example
cp -R "$SCRIPT_DIR/.git" "$SCRIPT_DIR/.claude" "$SCRIPT_DIR/.claude-plugin" "$SCRIPT_DIR/content" "$SCRIPT_DIR/scripts" "$TMPDIR/"
cp "$SCRIPT_DIR/CLAUDE.md" "$SCRIPT_DIR/AGENTS.md" "$SCRIPT_DIR/README.md" "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.gitignore" "$TMPDIR/"

cd "$TMPDIR"

# Fix: убедимся что мы в git-репо (cp -R .git должно достаточно)
git status >/dev/null || { echo "FAIL: not a git repo after copy"; exit 1; }

echo "==> Run init.sh with test parameters"
INIT_SKIP_MCP=1 \
  bash scripts/init.sh \
    "Тест ТСН" \
    "TEST-TSN" \
    "Тестовое товарищество" \
    "Москва, ул. Тестовая д.1" \
    "Тестов Тест Тестович" \
    "test@example.com" \
    ""  # пустой remote — should pass

echo "==> Verify: placeholders replaced"
LEFT=$(grep -RE '{{TSN_NAME}}|{{TSN_CODE}}|{{TSN_DESCRIPTION}}|{{TSN_ADDRESS}}|{{CHAIR_NAME}}|{{EDITOR_EMAIL}}' CLAUDE.md AGENTS.md README.md content/ 2>/dev/null || true)
if [[ -n "$LEFT" ]]; then
  echo "FAIL: placeholders remain:"
  echo "$LEFT"
  exit 1
fi

echo "==> Verify: critical files exist and contain TSN data"
test -f content/_index.md
test -f content/01-property/passport.md
test -f content/03-board/actors.md
test -f content/03-board/manager-state.md
test -f content/03-board/log.md
test -f content/.doc-root.yaml

grep -q "Тест ТСН" content/_index.md || { echo "FAIL: TSN_NAME not in content/_index.md"; exit 1; }
grep -q "TEST-TSN" content/.doc-root.yaml || { echo "FAIL: TSN_CODE not in .doc-root.yaml"; exit 1; }
grep -q "Москва, ул. Тестовая д.1" content/01-property/passport.md || { echo "FAIL: TSN_ADDRESS not in passport.md"; exit 1; }
grep -q "Тестов Тест Тестович" content/03-board/actors.md || { echo "FAIL: CHAIR_NAME not in actors.md"; exit 1; }
grep -q "test@example.com" content/.doc-root.yaml || { echo "FAIL: EDITOR_EMAIL not in .doc-root.yaml"; exit 1; }

echo "==> Verify: git state"
test "$(git rev-parse --abbrev-ref HEAD)" = "main"
git show-ref --verify --quiet refs/heads/private || { echo "FAIL: private branch missing"; exit 1; }
git log --oneline -1 | grep -q "Template:" || { echo "FAIL: traceability missing in initial commit"; exit 1; }

echo "==> Verify: validate-content.py passes"
uv run scripts/validate-content.py >/dev/null 2>&1 || { echo "FAIL: validate-content.py exit non-zero"; exit 1; }

echo "==> PASS: test-init-tsn"
