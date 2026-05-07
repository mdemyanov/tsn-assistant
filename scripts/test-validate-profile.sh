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

# ===== M2: required fields =====
echo ""
echo "==> M2: manifest без обязательных полей"
TMP2="$(mktemp -d)"
mkdir -p "$TMP2/docs/overlays/profiles/incomplete"
cat > "$TMP2/docs/overlays/profiles/incomplete/manifest.yaml" <<'YAML'
name: incomplete
description: missing fields
YAML
cd "$TMP2"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/incomplete 2>&1)
RC=$?
set -e
assert "M2 exit 1 без обязательных полей" "[ \"$RC\" = '1' ]"
assert "M2 упоминает schema_version" "echo \"$OUT\" | grep -q 'schema_version'"
assert "M2 упоминает subagents" "echo \"$OUT\" | grep -q 'subagents'"
cd "$REPO_ROOT"
rm -rf "$TMP2"

# ===== M3: name совпадает с dir =====
echo ""
echo "==> M3: name != dir"
TMP3="$(mktemp -d)"
mkdir -p "$TMP3/docs/overlays/profiles/foo"
cat > "$TMP3/docs/overlays/profiles/foo/manifest.yaml" <<'YAML'
schema_version: 1
name: bar
description: name != dir
status: stub
subagents: { pm: core }
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
YAML
cd "$TMP3"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/foo 2>&1)
RC=$?
set -e
assert "M3 exit 1 при name != dir" "[ \"$RC\" = '1' ]"
assert "M3 сообщение про name" "echo \"$OUT\" | grep -qE 'name.*foo|name.*bar|совпада'"
cd "$REPO_ROOT"
rm -rf "$TMP3"

# ===== M4: subagents объявлены в AGENTS.md =====
echo ""
echo "==> M4: subagents с unknown role"
TMP4="$(mktemp -d)"
mkdir -p "$TMP4/docs/overlays/profiles/badrole"
# Минимальный AGENTS.md с реестром
cat > "$TMP4/AGENTS.md" <<'MD'
## Каталог ролей

| Имя | Описание |
|-----|----------|
| pm | PM |
| ba | BA |
MD
cat > "$TMP4/docs/overlays/profiles/badrole/manifest.yaml" <<'YAML'
schema_version: 1
name: badrole
description: ref to non-existent role
status: stub
subagents:
  pm: core
  unknownrole: optional
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
YAML
cd "$TMP4"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/badrole 2>&1)
RC=$?
set -e
assert "M4 exit 1 при unknown role" "[ \"$RC\" = '1' ]"
assert "M4 сообщение содержит unknownrole" "echo \"$OUT\" | grep -q 'unknownrole'"
cd "$REPO_ROOT"
rm -rf "$TMP4"

# ===== M5: pipelines существуют =====
echo ""
echo "==> M5: pipeline без commands/pipelines/<name>.md"
TMP5="$(mktemp -d)"
mkdir -p "$TMP5/docs/overlays/profiles/badpipe"
mkdir -p "$TMP5/.claude/plugins/project/commands/pipelines"
touch "$TMP5/.claude/plugins/project/commands/pipelines/known-pipe.md"
cat > "$TMP5/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP5/docs/overlays/profiles/badpipe/manifest.yaml" <<'YAML'
schema_version: 1
name: badpipe
description: pipeline doesn't exist
status: stub
subagents: { pm: core }
pipelines:
  known-pipe: enabled
  unknown-pipe: enabled
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
YAML
cd "$TMP5"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/badpipe 2>&1)
RC=$?
set -e
assert "M5 exit 1 при unknown pipeline" "[ \"$RC\" = '1' ]"
assert "M5 содержит unknown-pipe" "echo \"$OUT\" | grep -q 'unknown-pipe'"
cd "$REPO_ROOT"
rm -rf "$TMP5"

# ===== M6: enum status =====
echo ""
echo "==> M6: subagents.X не из enum"
TMP6="$(mktemp -d)"
mkdir -p "$TMP6/docs/overlays/profiles/badenum"
cat > "$TMP6/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP6/docs/overlays/profiles/badenum/manifest.yaml" <<'YAML'
schema_version: 1
name: badenum
description: bad enum
status: stub
subagents:
  pm: active
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
YAML
cd "$TMP6"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/badenum 2>&1)
RC=$?
set -e
assert "M6 exit 1 при невалидном enum" "[ \"$RC\" = '1' ]"
assert "M6 содержит 'active'" "echo \"$OUT\" | grep -q 'active'"
cd "$REPO_ROOT"
rm -rf "$TMP6"

# ===== M7: paths существуют =====
echo ""
echo "==> M7: content_scaffold path missing"
TMP7="$(mktemp -d)"
mkdir -p "$TMP7/docs/overlays/profiles/badpath"
cat > "$TMP7/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP7/docs/overlays/profiles/badpath/manifest.yaml" <<'YAML'
schema_version: 1
name: badpath
description: missing scaffold dir
status: stable
subagents: { pm: core }
pipelines: {}
content_scaffold: nonexistent/
doc_root: nonexistent.yaml
operations: []
compatible_stacks: []
YAML
cd "$TMP7"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/badpath 2>&1)
RC=$?
set -e
assert "M7 exit 1 при missing path (status: stable)" "[ \"$RC\" = '1' ]"
assert "M7 содержит content_scaffold" "echo \"$OUT\" | grep -q 'content_scaffold'"
cd "$REPO_ROOT"
rm -rf "$TMP7"

# stub-профиль с missing path — НЕ error (stub'ы могут иметь пустые paths)
echo "==> M7: stub-профиль с пустым path — OK"
TMP7B="$(mktemp -d)"
mkdir -p "$TMP7B/docs/overlays/profiles/stubok"
cat > "$TMP7B/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP7B/docs/overlays/profiles/stubok/manifest.yaml" <<'YAML'
schema_version: 1
name: stubok
description: stub
status: stub
subagents: { pm: core }
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
YAML
cd "$TMP7B"
set +e
python3 "$VALIDATOR" docs/overlays/profiles/stubok >/dev/null 2>&1
RC=$?
set -e
assert "M7 stub: exit 0 даже с placeholder paths" "[ \"$RC\" = '0' ]"
cd "$REPO_ROOT"
rm -rf "$TMP7B"

# ===== M8: on_value мутации валидны =====
echo ""
echo "==> M8: on_value targets unknown subagent"
TMP8="$(mktemp -d)"
mkdir -p "$TMP8/docs/overlays/profiles/m8test"
cat > "$TMP8/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP8/docs/overlays/profiles/m8test/manifest.yaml" <<'YAML'
schema_version: 1
name: m8test
description: bad on_value
status: stub
subagents: { pm: core }
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
init_prompts:
  - id: foo
    prompt: "?"
    type: enum
    choices: [a]
    default: a
    on_value:
      a:
        subagents.unknown_role: core
YAML
cd "$TMP8"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/m8test 2>&1)
RC=$?
set -e
assert "M8 exit 0 (warning, не error)" "[ \"$RC\" = '0' ]"
assert "M8 содержит warning + unknown_role" "echo \"$OUT\" | grep -q 'warning' && echo \"$OUT\" | grep -q 'unknown_role'"
cd "$REPO_ROOT"
rm -rf "$TMP8"

# ===== M9: compatible_stacks несуществующие =====
echo ""
echo "==> M9: compatible_stacks с несуществующим overlay"
TMP9="$(mktemp -d)"
mkdir -p "$TMP9/docs/overlays/profiles/m9test"
mkdir -p "$TMP9/docs/overlays/known-stack"
cat > "$TMP9/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP9/docs/overlays/profiles/m9test/manifest.yaml" <<'YAML'
schema_version: 1
name: m9test
description: unknown stack
status: stub
subagents: { pm: core }
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: [known-stack, unknown-stack]
YAML
cd "$TMP9"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/m9test 2>&1)
RC=$?
set -e
assert "M9 exit 0 (warning)" "[ \"$RC\" = '0' ]"
assert "M9 warning про unknown-stack" "echo \"$OUT\" | grep -q 'warning' && echo \"$OUT\" | grep -q 'unknown-stack'"
cd "$REPO_ROOT"
rm -rf "$TMP9"

# ===== M10: status mismatch =====
echo ""
echo "==> M10: status: stable + пустой scaffold"
TMP10="$(mktemp -d)"
mkdir -p "$TMP10/docs/overlays/profiles/m10test"
mkdir -p "$TMP10/docs/overlays/profiles/m10test/empty-scaffold"
cat > "$TMP10/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
cat > "$TMP10/docs/overlays/profiles/m10test/empty-doc-root.yaml" <<'YAML'
title: t
properties: []
filterProperties: []
YAML
cat > "$TMP10/docs/overlays/profiles/m10test/manifest.yaml" <<'YAML'
schema_version: 1
name: m10test
description: stable but empty
status: stable
subagents: { pm: core }
pipelines: {}
content_scaffold: empty-scaffold/
doc_root: empty-doc-root.yaml
operations: []
compatible_stacks: []
YAML
cd "$TMP10"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/m10test 2>&1)
RC=$?
set -e
assert "M10 exit 0 (warning)" "[ \"$RC\" = '0' ]"
assert "M10 warning про stable + empty" "echo \"$OUT\" | grep -q 'warning' && echo \"$OUT\" | grep -qE 'stable|empty'"
cd "$REPO_ROOT"
rm -rf "$TMP10"

# ===== M0: malformed YAML =====
echo ""
echo "==> M0: невалидный YAML в manifest"
TMP_BAD=$(mktemp -d)
mkdir -p "$TMP_BAD/docs/overlays/profiles/badyaml"
cat > "$TMP_BAD/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| pm | PM |
MD
# Невалидный YAML — unterminated string
cat > "$TMP_BAD/docs/overlays/profiles/badyaml/manifest.yaml" <<'YAML'
schema_version: 1
name: badyaml
description: "unterminated string
status: stub
YAML
cd "$TMP_BAD"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/badyaml 2>&1)
RC=$?
set -e
assert "M0 exit 1 при невалидном YAML" "[ \"$RC\" = '1' ]"
assert "M0 содержит 'not valid YAML'" "echo \"$OUT\" | grep -q 'not valid YAML'"
cd "$REPO_ROOT"
rm -rf "$TMP_BAD"

# ===== T-W3-A4-SCHEMA-VERSION: schema_version вне enum → error =====
echo ""
echo "==> T-W3-A4-SCHEMA-VERSION"
TMP_SV=$(mktemp -d)
mkdir -p "$TMP_SV/docs/overlays/profiles/bad-sv" "$TMP_SV/scripts"
cp "$REPO_ROOT/scripts/_validate_common.py" "$REPO_ROOT/scripts/validate-profile.py" "$TMP_SV/scripts/"
cat > "$TMP_SV/docs/overlays/profiles/bad-sv/manifest.yaml" <<'EOFSV'
schema_version: 99
name: bad-sv
description: bad
status: stub
subagents: { pm: core }
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
EOFSV
cd "$TMP_SV"
set +e
OUT=$(python3 scripts/validate-profile.py docs/overlays/profiles/bad-sv 2>&1)
RC=$?
set -e
assert "T-W3-A4: error при schema_version: 99" "echo \"$OUT\" | grep -q 'schema_version: 99 не поддерживается'"
assert "T-W3-A4: exit 1" "[ \"$RC\" = '1' ]"
cd "$REPO_ROOT"
rm -rf "$TMP_SV"

# ===== T-W3-A3-M4-VISIBILITY: broken AGENTS.md heading → warning =====
echo ""
echo "==> T-W3-A3-M4-VISIBILITY"
TMP_M4V=$(mktemp -d)
rsync -a --exclude='.git' --exclude='.worktrees' "$REPO_ROOT/" "$TMP_M4V/"
cd "$TMP_M4V"
sed -i.bak 's/## Каталог ролей/## Catalog of roles/' AGENTS.md && rm -f AGENTS.md.bak
set +e
OUT=$(python3 scripts/validate-profile.py 2>&1)
RC=$?
set -e
assert "T-W3-A3: warning emit при broken heading" "echo \"$OUT\" | grep -q \"M4 (subagent name validation) skipped\""
assert "T-W3-A3: exit 0 (warning не error)" "[ \"$RC\" = '0' ]"
cd "$REPO_ROOT"
rm -rf "$TMP_M4V"

# ===== M11.1: base prompt missing =====
echo ""
echo "==> M11.1: agent_overrides declared, but base prompt missing"
TMP_M11_1=$(mktemp -d)
mkdir -p "$TMP_M11_1/docs/overlays/profiles/m11-1/agent-overrides"
mkdir -p "$TMP_M11_1/.claude/plugins/project/agents"
# NB: deliberately NOT creating fakerole-agent.md in base
cat > "$TMP_M11_1/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| fakerole | Fake |
MD
cat > "$TMP_M11_1/docs/overlays/profiles/m11-1/manifest.yaml" <<'YAML'
schema_version: 1
name: m11-1
description: base missing
status: stub
subagents:
  fakerole: core
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
agent_overrides:
  fakerole:
    source: agent-overrides/fakerole.md
YAML
cat > "$TMP_M11_1/docs/overlays/profiles/m11-1/agent-overrides/fakerole.md" <<'MD'
---
extends: fakerole
---

## Роль
Fake.
MD
cd "$TMP_M11_1"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/m11-1 2>&1)
RC=$?
set -e
assert "M11.1 exit 1 при missing base" "[ \"$RC\" = '1' ]"
assert "M11.1 содержит 'base file not found'" "echo \"$OUT\" | grep -q 'base file not found'"
cd "$REPO_ROOT"
rm -rf "$TMP_M11_1"

# ===== M11.2: source path missing =====
echo ""
echo "==> M11.2: agent_overrides.source not found"
TMP_M11_2=$(mktemp -d)
mkdir -p "$TMP_M11_2/docs/overlays/profiles/m11-2"
mkdir -p "$TMP_M11_2/.claude/plugins/project/agents"
# Base exists
cat > "$TMP_M11_2/.claude/plugins/project/agents/ba-agent.md" <<'MD'
---
extends: ba
---

## Роль
BA.
MD
cat > "$TMP_M11_2/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| ba | BA |
MD
# manifest references missing source
cat > "$TMP_M11_2/docs/overlays/profiles/m11-2/manifest.yaml" <<'YAML'
schema_version: 1
name: m11-2
description: source missing
status: stub
subagents:
  ba: core
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
agent_overrides:
  ba:
    source: agent-overrides/ba.md
YAML
cd "$TMP_M11_2"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/m11-2 2>&1)
RC=$?
set -e
assert "M11.2 exit 1 при missing source" "[ \"$RC\" = '1' ]"
assert "M11.2 содержит 'source not found'" "echo \"$OUT\" | grep -q 'source not found'"
cd "$REPO_ROOT"
rm -rf "$TMP_M11_2"

# ===== M11.3: extends mismatch =====
echo ""
echo "==> M11.3: extends в frontmatter не совпадает с ролью"
TMP_M11_3=$(mktemp -d)
mkdir -p "$TMP_M11_3/docs/overlays/profiles/m11-3/agent-overrides"
mkdir -p "$TMP_M11_3/.claude/plugins/project/agents"
cat > "$TMP_M11_3/.claude/plugins/project/agents/tech-writer-agent.md" <<'MD'
---
name: tech-writer
---

## Роль
TW.
MD
cat > "$TMP_M11_3/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| tech-writer | TW |
| ba | BA |
MD
cat > "$TMP_M11_3/docs/overlays/profiles/m11-3/manifest.yaml" <<'YAML'
schema_version: 1
name: m11-3
description: extends mismatch
status: stub
subagents:
  tech-writer: core
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
agent_overrides:
  tech-writer:
    source: agent-overrides/tech-writer.md
YAML
# Override: extends: ba (mismatch — should be tech-writer)
cat > "$TMP_M11_3/docs/overlays/profiles/m11-3/agent-overrides/tech-writer.md" <<'MD'
---
extends: ba
---

## Роль
Wrong extends.
MD
cd "$TMP_M11_3"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/m11-3 2>&1)
RC=$?
set -e
assert "M11.3 exit 1 при extends mismatch" "[ \"$RC\" = '1' ]"
assert "M11.3 содержит mismatch info" "echo \"$OUT\" | grep -q 'extends' && echo \"$OUT\" | grep -q 'tech-writer' && echo \"$OUT\" | grep -q 'M11'"
cd "$REPO_ROOT"
rm -rf "$TMP_M11_3"

# ===== M11.4: role disabled, but override declared =====
echo ""
echo "==> M11.4: subagents.role=disabled но agent_overrides.role declared"
TMP_M11_4=$(mktemp -d)
mkdir -p "$TMP_M11_4/docs/overlays/profiles/m11-4/agent-overrides"
mkdir -p "$TMP_M11_4/.claude/plugins/project/agents"
cat > "$TMP_M11_4/.claude/plugins/project/agents/ba-agent.md" <<'MD'
---
name: ba
---

## Роль
BA.
MD
cat > "$TMP_M11_4/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| ba | BA |
MD
cat > "$TMP_M11_4/docs/overlays/profiles/m11-4/manifest.yaml" <<'YAML'
schema_version: 1
name: m11-4
description: role disabled
status: stub
subagents:
  ba: disabled
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
agent_overrides:
  ba:
    source: agent-overrides/ba.md
YAML
cat > "$TMP_M11_4/docs/overlays/profiles/m11-4/agent-overrides/ba.md" <<'MD'
---
extends: ba
---

## Роль
BA override.
MD
cd "$TMP_M11_4"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/m11-4 2>&1)
RC=$?
set -e
assert "M11.4 exit 1 при disabled role с override" "[ \"$RC\" = '1' ]"
assert "M11.4 содержит 'subagents.ba=disabled'" "echo \"$OUT\" | grep -q 'subagents.ba=disabled'"
cd "$REPO_ROOT"
rm -rf "$TMP_M11_4"

# ===== M11.5: {{super}} в секции, отсутствующей в base =====
echo ""
echo "==> M11.5: {{super}} placeholder в секции, отсутствующей в base"
TMP_M11_5=$(mktemp -d)
mkdir -p "$TMP_M11_5/docs/overlays/profiles/m11-5/agent-overrides"
mkdir -p "$TMP_M11_5/.claude/plugins/project/agents"
# Base has only "Роль" section
cat > "$TMP_M11_5/.claude/plugins/project/agents/ba-agent.md" <<'MD'
---
name: ba
---

## Роль
BA base content.
MD
cat > "$TMP_M11_5/AGENTS.md" <<'MD'
## Каталог ролей
| Имя | Описание |
|-----|----------|
| ba | BA |
MD
cat > "$TMP_M11_5/docs/overlays/profiles/m11-5/manifest.yaml" <<'YAML'
schema_version: 1
name: m11-5
description: super in non-existent section
status: stub
subagents:
  ba: core
pipelines: {}
content_scaffold: ./
doc_root: ./
operations: []
compatible_stacks: []
agent_overrides:
  ba:
    source: agent-overrides/ba.md
YAML
# Override has {{super}} in section that does NOT exist in base ("Domain" — base only has "Роль")
cat > "$TMP_M11_5/docs/overlays/profiles/m11-5/agent-overrides/ba.md" <<'MD'
---
extends: ba
---

## Domain
{{super}}

Дополнительный контекст.
MD
cd "$TMP_M11_5"
set +e
OUT=$(python3 "$VALIDATOR" docs/overlays/profiles/m11-5 2>&1)
RC=$?
set -e
assert "M11.5 exit 1 при {{super}} в отсутствующей секции" "[ \"$RC\" = '1' ]"
assert "M11.5 содержит 'Domain' и '{{super}}'" "echo \"$OUT\" | grep -q \"## Domain\" && echo \"$OUT\" | grep -q '{{super}}'"
cd "$REPO_ROOT"
rm -rf "$TMP_M11_5"

echo ""
echo "==> Results: $PASS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
echo "✓ test-validate-profile.sh PASSED"
