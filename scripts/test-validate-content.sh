#!/usr/bin/env bash
# test-validate-content.sh — тесты для scripts/validate-content.py
set -euo pipefail

# uv-guard: обязательная зависимость
if ! command -v uv >/dev/null 2>&1; then
  echo "ERROR: 'uv' не найден в PATH. Установите: https://docs.astral.sh/uv/getting-started/installation/" >&2
  exit 1
fi

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
assert "validator --help прошёл" "uv run \"$VALIDATOR\" --help >/dev/null 2>&1"

# ===== C1: missing _index.md =====
echo ""
echo "==> C1: подпапка без _index.md детектится"
TMP1="$(mktemp -d)"
mkdir -p "$TMP1/content/sub"
cat > "$TMP1/content/.doc-root.yaml" <<'YAML'
title: Test
properties: []
filterProperties: []
YAML
echo '---' > "$TMP1/content/sub/article.md"
echo 'order: 1' >> "$TMP1/content/sub/article.md"
echo 'title: A' >> "$TMP1/content/sub/article.md"
echo '---' >> "$TMP1/content/sub/article.md"

set +e
OUT=$(uv run "$VALIDATOR" "$TMP1/content" 2>&1)
RC=$?
set -e
assert "exit 1 при missing _index.md" "[ \"$RC\" = '1' ]"
assert "сообщение содержит missing _index.md" "echo \"$OUT\" | grep -q 'missing _index.md'"
assert "указан путь sub" "echo \"$OUT\" | grep -q 'sub'"
rm -rf "$TMP1"

echo ""
echo "==> C1: корневой _index.md обязателен"
TMP2="$(mktemp -d)"
mkdir -p "$TMP2/content"
cat > "$TMP2/content/.doc-root.yaml" <<'YAML'
title: Test
properties: []
filterProperties: []
YAML
echo '---' > "$TMP2/content/article.md"
echo 'order: 1' >> "$TMP2/content/article.md"
echo 'title: A' >> "$TMP2/content/article.md"
echo '---' >> "$TMP2/content/article.md"

set +e
OUT=$(uv run "$VALIDATOR" "$TMP2/content" 2>&1)
RC=$?
set -e
assert "exit 1 при отсутствии корневого _index.md" "[ \"$RC\" = '1' ]"
assert "ошибка про корневой _index.md" "echo \"$OUT\" | grep -q 'missing _index.md'"
rm -rf "$TMP2"

echo ""
echo "==> C1: каталог с _index.md проходит"
TMP3="$(mktemp -d)"
mkdir -p "$TMP3/content/sub"
cat > "$TMP3/content/.doc-root.yaml" <<'YAML'
title: Test
properties: []
filterProperties: []
YAML
echo '---' > "$TMP3/content/_index.md"
echo 'order: 0' >> "$TMP3/content/_index.md"
echo 'title: Root' >> "$TMP3/content/_index.md"
echo '---' >> "$TMP3/content/_index.md"
echo '---' > "$TMP3/content/sub/_index.md"
echo 'order: 1' >> "$TMP3/content/sub/_index.md"
echo 'title: Sub' >> "$TMP3/content/sub/_index.md"
echo '---' >> "$TMP3/content/sub/_index.md"

set +e
uv run "$VALIDATOR" "$TMP3/content" >/dev/null 2>&1
RC=$?
set -e
assert "exit 0 для каталога с _index.md везде" "[ \"$RC\" = '0' ]"
rm -rf "$TMP3"

# ===== C2: _index.md не должен иметь properties: =====
echo ""
echo "==> C2: _index.md с properties: даёт error"
TMP_C2="$(mktemp -d)"
mkdir -p "$TMP_C2/content"
cat > "$TMP_C2/content/.doc-root.yaml" <<'YAML'
title: Test
properties: []
filterProperties: []
YAML
cat > "$TMP_C2/content/_index.md" <<'MD'
---
order: 0
title: Root
properties:
  - name: Тип контента
    value: [ADR]
---
MD

set +e
OUT=$(uv run "$VALIDATOR" "$TMP_C2/content" 2>&1)
RC=$?
set -e
assert "C2 exit 1 при properties в _index.md" "[ \"$RC\" = '1' ]"
assert "C2 сообщение про properties в _index.md" "echo \"$OUT\" | grep -q '_index.md не должен иметь properties'"
rm -rf "$TMP_C2"

# ===== C3: object-нотация в frontmatter статьи =====
echo ""
echo "==> C3: плоская нотация даёт error"
TMP_C3="$(mktemp -d)"
mkdir -p "$TMP_C3/content"
cat > "$TMP_C3/content/.doc-root.yaml" <<'YAML'
title: Test
properties:
  - name: Тип
    type: Enum
    values: [A, B]
filterProperties: []
YAML
cat > "$TMP_C3/content/_index.md" <<'MD'
---
order: 0
title: Root
---
MD
cat > "$TMP_C3/content/article.md" <<'MD'
---
order: 1
title: Article
properties:
  - Тип: A
---
MD

set +e
OUT=$(uv run "$VALIDATOR" "$TMP_C3/content" 2>&1)
RC=$?
set -e
assert "C3 exit 1 при плоской нотации" "[ \"$RC\" = '1' ]"
assert "C3 сообщение про плоскую нотацию" "echo \"$OUT\" | grep -qi 'плоск'"
rm -rf "$TMP_C3"

echo ""
echo "==> C3: object-нотация принимается"
TMP_C3B="$(mktemp -d)"
mkdir -p "$TMP_C3B/content"
cat > "$TMP_C3B/content/.doc-root.yaml" <<'YAML'
title: Test
properties:
  - name: Тип
    type: Enum
    values: [A, B]
filterProperties: []
YAML
cat > "$TMP_C3B/content/_index.md" <<'MD'
---
order: 0
title: Root
---
MD
cat > "$TMP_C3B/content/article.md" <<'MD'
---
order: 1
title: Article
properties:
  - name: Тип
    value: [A]
---
MD

set +e
uv run "$VALIDATOR" "$TMP_C3B/content" >/dev/null 2>&1
RC=$?
set -e
assert "C3 object-нотация exit 0" "[ \"$RC\" = '0' ]"
rm -rf "$TMP_C3B"

# ===== C4: property из frontmatter объявлен в .doc-root.yaml =====
echo ""
echo "==> C4: незнакомый property даёт error"
TMP_C4="$(mktemp -d)"
mkdir -p "$TMP_C4/content"
cat > "$TMP_C4/content/.doc-root.yaml" <<'YAML'
title: Test
properties:
  - name: Тип
    type: Enum
    values: [A]
filterProperties: []
YAML
cat > "$TMP_C4/content/_index.md" <<'MD'
---
order: 0
title: Root
---
MD
cat > "$TMP_C4/content/article.md" <<'MD'
---
order: 1
title: A
properties:
  - name: Неизвестный
    value: [X]
---
MD

set +e
OUT=$(uv run "$VALIDATOR" "$TMP_C4/content" 2>&1)
RC=$?
set -e
assert "C4 exit 1 для незнакомого property" "[ \"$RC\" = '1' ]"
assert "C4 в сообщении упомянут \"Неизвестный\"" "echo \"$OUT\" | grep -q 'Неизвестный'"
rm -rf "$TMP_C4"

# ===== C5: значение property входит в enum =====
echo ""
echo "==> C5: значение вне enum даёт error"
TMP_C5="$(mktemp -d)"
mkdir -p "$TMP_C5/content"
cat > "$TMP_C5/content/.doc-root.yaml" <<'YAML'
title: Test
properties:
  - name: Тип
    type: Enum
    values: [A, B]
filterProperties: []
YAML
cat > "$TMP_C5/content/_index.md" <<'MD'
---
order: 0
title: Root
---
MD
cat > "$TMP_C5/content/article.md" <<'MD'
---
order: 1
title: X
properties:
  - name: Тип
    value: [WRONG]
---
MD

set +e
OUT=$(uv run "$VALIDATOR" "$TMP_C5/content" 2>&1)
RC=$?
set -e
assert "C5 exit 1 значение вне enum" "[ \"$RC\" = '1' ]"
assert "C5 сообщение содержит WRONG" "echo \"$OUT\" | grep -q 'WRONG'"
rm -rf "$TMP_C5"

# ===== C6: filterProperties покрытие (warning) =====
echo ""
echo "==> C6: статья без filter-property — warning"
TMP_C6="$(mktemp -d)"
mkdir -p "$TMP_C6/content"
cat > "$TMP_C6/content/.doc-root.yaml" <<'YAML'
title: Test
properties:
  - name: Тип
    type: Enum
    values: [A]
  - name: Статус
    type: Enum
    values: [Draft]
filterProperties: [Тип]
YAML
cat > "$TMP_C6/content/_index.md" <<'MD'
---
order: 0
title: Root
---
MD
cat > "$TMP_C6/content/article.md" <<'MD'
---
order: 1
title: X
properties:
  - name: Статус
    value: [Draft]
---
MD

set +e
OUT=$(uv run "$VALIDATOR" "$TMP_C6/content" 2>&1)
RC=$?
set -e
assert "C6 warning не валит exit code" "[ \"$RC\" = '0' ]"
assert "C6 сообщение содержит warning + filterProperties" "echo \"$OUT\" | grep -q 'warning' && echo \"$OUT\" | grep -qi 'filter'"
rm -rf "$TMP_C6"

# ===== C7: плейсхолдеры {{...}} в frontmatter — warning, не error =====
echo ""
echo "==> C7: {{PROJECT_NAME}} в _index.md — только warning"
TMP_C7="$(mktemp -d)"
mkdir -p "$TMP_C7/content"
cat > "$TMP_C7/content/.doc-root.yaml" <<'YAML'
title: Test
properties:
  - name: Тип
    type: Enum
    values: [A]
filterProperties: []
YAML
cat > "$TMP_C7/content/_index.md" <<'MD'
---
order: 0
title: {{PROJECT_NAME}}
---
MD

set +e
OUT=$(uv run "$VALIDATOR" "$TMP_C7/content" 2>&1)
RC=$?
set -e
assert "C7 exit 0 при плейсхолдере" "[ \"$RC\" = '0' ]"
assert "C7 warning про плейсхолдер" "echo \"$OUT\" | grep -q 'warning' && echo \"$OUT\" | grep -q '{{'"
rm -rf "$TMP_C7"

echo ""
echo "==> C7: статья с плейсхолдером — C4/C5 не срабатывают"
TMP_C7B="$(mktemp -d)"
mkdir -p "$TMP_C7B/content"
cat > "$TMP_C7B/content/.doc-root.yaml" <<'YAML'
title: Test
properties:
  - name: Тип
    type: Enum
    values: [A]
filterProperties: []
YAML
cat > "$TMP_C7B/content/_index.md" <<'MD'
---
order: 0
title: Root
---
MD
cat > "$TMP_C7B/content/article.md" <<'MD'
---
order: 1
title: {{TITLE}}
properties:
  - name: Тип
    value: [A]
---
MD

set +e
uv run "$VALIDATOR" "$TMP_C7B/content" >/dev/null 2>&1
RC=$?
set -e
assert "C7 статья с {{TITLE}} — exit 0" "[ \"$RC\" = '0' ]"
rm -rf "$TMP_C7B"

# ===== C7-doc-root: плейсхолдеры в .doc-root.yaml =====
echo ""
echo "==> C7-doc-root: {{X}} в .doc-root.yaml — warning, не error"
TMP_DR="$(mktemp -d)"
mkdir -p "$TMP_DR/content"
cat > "$TMP_DR/content/.doc-root.yaml" <<'YAML'
title: {{PROJECT_NAME}}
code: {{PROJECT_CODE}}
properties:
  - name: Тип
    type: Enum
    values: [A]
filterProperties: []
editors:
  - {{EDITOR_EMAIL}}
YAML
cat > "$TMP_DR/content/_index.md" <<'MD'
---
order: 0
title: Root
---
MD
cat > "$TMP_DR/content/article.md" <<'MD'
---
order: 1
title: A
properties:
  - name: Тип
    value: [A]
---
MD

set +e
OUT=$(uv run "$VALIDATOR" "$TMP_DR/content" 2>&1)
RC=$?
set -e
assert "C7-doc-root exit 0" "[ \"$RC\" = '0' ]"
assert "C7-doc-root warning про плейсхолдер" "echo \"$OUT\" | grep -q 'warning' && echo \"$OUT\" | grep -q 'doc-root'"
assert "C7-doc-root C4 не срабатывает на корректное property" "! echo \"$OUT\" | grep -q 'не объявлен'"
rm -rf "$TMP_DR"

# ===== Shared module sanity =====
echo ""
echo "==> SHARED: _validate_common.py importable"
assert "import _validate_common works" "uv run --no-project --with 'pyyaml>=6.0,<7.0' python -c 'import sys; sys.path.insert(0, \"$REPO_ROOT/scripts\"); import _validate_common; print(_validate_common.PLACEHOLDER_RE.pattern)' >/dev/null 2>&1"
assert "Issue dataclass exposed" "uv run --no-project --with 'pyyaml>=6.0,<7.0' python -c 'import sys; sys.path.insert(0, \"$REPO_ROOT/scripts\"); from _validate_common import Issue; i = Issue(\"error\", \"x\", \"y\"); print(i.level)' | grep -q '^error$'"

echo ""
echo "==> Results: $PASS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
echo "✓ test-validate-content.sh PASSED"
