#!/usr/bin/env bash
# apply-overlay.sh — применяет (или откатывает) overlay из docs/overlays/<name>/
# Идемпотентный: повторное применение даёт пустой diff.
#
# Usage:
#   bash scripts/apply-overlay.sh <overlay-name>
#   bash scripts/apply-overlay.sh --remove <overlay-name>

set -euo pipefail

ACTION="apply"
OVERLAY_NAME=""

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 [--remove] <overlay-name>"
  exit 2
fi

if [[ "$1" == "--remove" ]]; then
  ACTION="remove"
  shift
  if [[ $# -eq 0 ]]; then
    echo "Usage: $0 --remove <overlay-name>"
    exit 2
  fi
fi

OVERLAY_NAME="$1"
shift

if [[ $# -gt 0 ]]; then
  echo "ERROR: unexpected arguments: $*"
  exit 2
fi

OVERLAY_DIR="docs/overlays/$OVERLAY_NAME"

if [[ ! -d "$OVERLAY_DIR" ]]; then
  echo "ERROR: overlay not found: $OVERLAY_DIR"
  exit 1
fi

# Markers (markdown style for .md, hash for .yaml — обрабатывается отдельно)
MARK_START_MD="<!-- OVERLAY:$OVERLAY_NAME:start -->"
MARK_END_MD="<!-- OVERLAY:$OVERLAY_NAME:end -->"
MARK_START_YAML="# OVERLAY:$OVERLAY_NAME:start"
MARK_END_YAML="# OVERLAY:$OVERLAY_NAME:end"

# Helper: strip block between markers (universal, works for any comment style).
# Also trims trailing blank lines — критично для идемпотентности повторного apply.
strip_block() {
  local file="$1"
  local start="$2"
  local end="$3"
  if [[ ! -f "$file" ]]; then
    return 0
  fi
  awk -v s="$start" -v e="$end" '
    BEGIN { skip=0 }
    index($0, s) > 0 { skip=1; next }
    index($0, e) > 0 { skip=0; next }
    !skip { print }
  ' "$file" > "$file.tmp"
  # Trim trailing blank lines: store all lines, find last non-blank, print up to it.
  awk '
    { a[NR]=$0 }
    END {
      last=0
      for (i=NR; i>0; i--) if (a[i] != "") { last=i; break }
      for (i=1; i<=last; i++) print a[i]
    }
  ' "$file.tmp" > "$file.tmp2"
  mv "$file.tmp2" "$file"
  rm -f "$file.tmp"
}

# Helper: append block with markers
append_block_md() {
  local file="$1"
  local content_file="$2"
  if [[ ! -f "$file" ]] || [[ ! -f "$content_file" ]]; then
    return 0
  fi
  {
    echo ""
    echo "$MARK_START_MD"
    cat "$content_file"
    echo "$MARK_END_MD"
  } >> "$file"
}

append_block_yaml() {
  local file="$1"
  local content_file="$2"
  if [[ ! -f "$file" ]] || [[ ! -f "$content_file" ]]; then
    return 0
  fi
  {
    echo ""
    echo "$MARK_START_YAML"
    cat "$content_file"
    echo "$MARK_END_YAML"
  } >> "$file"
}

# Process markdown target (CLAUDE.md, agent files, glossary)
process_md_target() {
  local target="$1"
  local patch="$2"
  strip_block "$target" "$MARK_START_MD" "$MARK_END_MD"
  if [[ "$ACTION" == "apply" ]]; then
    append_block_md "$target" "$patch"
  fi
}

# Process YAML target (.doc-root.yaml)
process_yaml_target() {
  local target="$1"
  local patch="$2"
  strip_block "$target" "$MARK_START_YAML" "$MARK_END_YAML"
  if [[ "$ACTION" == "apply" ]]; then
    append_block_yaml "$target" "$patch"
  fi
}

# === CLAUDE.md ===
[[ -f "$OVERLAY_DIR/claude-md-patch.md" ]] && process_md_target "CLAUDE.md" "$OVERLAY_DIR/claude-md-patch.md"

# === Agent patches ===
for role in ba sa dev; do
  patch="$OVERLAY_DIR/agent-patches/$role-smp-extension.md"
  agent=".claude/plugins/project-template/agents/$role-agent.md"
  [[ -f "$patch" ]] && [[ -f "$agent" ]] && process_md_target "$agent" "$patch"
done

# === .doc-root.yaml ===
yaml_patch="$OVERLAY_DIR/doc-root-properties-smp.yaml"
yaml_target="content/.doc-root.yaml"
[[ -f "$yaml_patch" ]] && [[ -f "$yaml_target" ]] && process_yaml_target "$yaml_target" "$yaml_patch"

# === glossary.md ===
glossary_patch="$OVERLAY_DIR/glossary-skeleton.md"
glossary_target="content/10-domain/glossary.md"
[[ -f "$glossary_patch" ]] && [[ -f "$glossary_target" ]] && process_md_target "$glossary_target" "$glossary_patch"

echo "✓ Overlay '$OVERLAY_NAME': $ACTION"
