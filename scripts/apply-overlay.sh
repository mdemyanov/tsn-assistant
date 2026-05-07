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
DRY_RUN=0
PROFILE_MODE=0
FORCE=0
INIT_MODE=0

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 [--profile] [--force] [--dry-run] [--init] [--remove] <overlay-name>"
  exit 2
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remove)  ACTION="remove"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --profile) PROFILE_MODE=1; shift ;;
    --force)   FORCE=1; shift ;;
    --init)    INIT_MODE=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--profile] [--force] [--dry-run] [--init] [--remove] <overlay-name>

  --profile     Apply profile-overlay from docs/overlays/profiles/<name>/
                (uses manifest.yaml operations: add/replace/delete)
  --force       Disable strict delete-non-empty check
  --dry-run     Print plan without executing
  --init        Skip strict checks (called from init.sh on fresh template)
  --remove      Remove the marker-based overlay (rolls back the apply)
EOF
      exit 0
      ;;
    -*) echo "Unknown flag: $1" >&2; exit 1 ;;
    *)
      if [[ -n "$OVERLAY_NAME" ]]; then
        echo "ERROR: unexpected positional arg: $1" >&2
        exit 2
      fi
      OVERLAY_NAME="$1"
      shift
      ;;
  esac
done

if [[ -z "$OVERLAY_NAME" ]]; then
  echo "ERROR: overlay name required" >&2
  exit 2
fi

OVERLAY_DIR="docs/overlays/$OVERLAY_NAME"

if [[ "$PROFILE_MODE" -ne 1 ]] && [[ ! -d "$OVERLAY_DIR" ]]; then
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
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY-RUN] would modify: $file"
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
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY-RUN] would append: $file"
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
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY-RUN] would append: $file"
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

PROFILES_ROOT="docs/overlays/profiles"

op_add() {
  local profile_dir="$1" source="$2" target="$3" reason="$4"
  local source_path="$profile_dir/$source"

  echo "[ADD] $source → $target  ($reason)"

  if [[ ! -e "$source_path" ]]; then
    echo "ERROR: source '$source_path' не существует" >&2
    exit 1
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [DRY-RUN] would copy"
    return 0
  fi

  mkdir -p "$target"
  if [[ -d "$source_path" ]]; then
    # A5: nullglob+dotglob — без явного отдельного hidden-glob, без шума при отсутствии файлов
    (
      shopt -s nullglob dotglob
      files=("$source_path"/*)
      if (( ${#files[@]} > 0 )); then
        cp -r "${files[@]}" "$target"/
      fi
    )
  else
    cp "$source_path" "$target"
  fi
  echo "  ✓ added"
}

op_replace() {
  local profile_dir="$1" source="$2" target="$3" reason="$4"
  local source_path="$profile_dir/$source"

  echo "[REPLACE] $source → $target  ($reason)"

  [[ ! -f "$source_path" ]] && { echo "ERROR: source '$source_path' не существует" >&2; exit 1; }

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [DRY-RUN] would overwrite"
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  cp -f "$source_path" "$target"
  echo "  ✓ replaced"
}

# Проверяет, что target можно удалить безопасно (только baseline content)
is_safe_to_delete() {
  local target="$1"
  [[ ! -e "$target" ]] && return 0  # уже нет — OK

  if [[ -f "$target" ]]; then
    # Файл: безопасно если плейсхолдер или пустой
    [[ ! -s "$target" ]] && return 0  # empty file
    grep -q '{{' "$target" && return 0  # placeholder
    return 1
  fi

  if [[ -d "$target" ]]; then
    # Папка: безопасно если содержит только _index.md (с placeholder/baseline) и .gitkeep
    local f
    while IFS= read -r f; do
      local base
      base=$(basename "$f")
      [[ "$base" == ".gitkeep" ]] && continue
      [[ "$base" == "_index.md" ]] && {
        # _index.md baseline — без content вне frontmatter
        # heuristic: если файл < 500 байт ИЛИ содержит {{ — baseline
        [[ ! -s "$f" || $(stat -f%z "$f" 2>/dev/null || stat -c%s "$f") -lt 500 ]] && continue
        grep -q '{{' "$f" && continue
        return 1  # _index.md содержательный
      }
      return 1  # любой другой файл = non-baseline
    done < <(find "$target" -type f)
    return 0
  fi

  return 1
}

op_delete() {
  local target="$1" reason="$2"

  echo "[DELETE] $target  ($reason)"

  [[ ! -e "$target" ]] && {
    echo "  ✓ already absent"
    return 0
  }

  if [[ "$FORCE" -eq 1 ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [DRY-RUN] would force-delete (force=1)"
      return 0
    fi
    rm -rf "$target"
    echo "  ✓ force-deleted"
    return 0
  fi

  if is_safe_to_delete "$target"; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [DRY-RUN] safe to delete"
      return 0
    fi
    rm -rf "$target"
    echo "  ✓ deleted (was baseline/empty)"
  else
    echo "  ⚠ REFUSED: $target содержит non-baseline content"
    echo "    Use --force to override; use --dry-run to preview"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [DRY-RUN] WOULD REFUSE"
      return 0
    fi
    exit 1
  fi
}

apply_profile_overlay() {
  local name="$1"
  local profile_dir="$PROFILES_ROOT/$name"

  [[ ! -d "$profile_dir" ]] && {
    echo "ERROR: profile '$name' не существует. Доступные:" >&2
    ls "$PROFILES_ROOT/" 2>/dev/null >&2 || echo "(нет профилей)" >&2
    exit 1
  }

  [[ ! -f "$profile_dir/manifest.yaml" ]] && {
    echo "ERROR: $profile_dir/manifest.yaml не найден" >&2
    exit 1
  }

  echo "Profile: $name"

  # validate-profile перед применением
  if [[ "${INIT_MODE:-0}" -ne 1 ]]; then
    python3 scripts/validate-profile.py "$profile_dir" >/dev/null 2>&1 || {
      echo "ERROR: validate-profile.py упал на $name" >&2
      python3 scripts/validate-profile.py "$profile_dir" >&2
      exit 1
    }
  fi

  # Прочитать status
  local status
  status=$(python3 -c "import yaml; m=yaml.safe_load(open('$profile_dir/manifest.yaml')); print(m.get('status', 'unknown'))")
  echo "Status: $status"

  if [[ "$status" == "stub" ]]; then
    echo "⚠ stub-профиль: scaffold не определён, профиль готов к расширению в Wave 3+"
  fi

  # Прочитать operations
  local ops_count
  ops_count=$(python3 -c "import yaml; m=yaml.safe_load(open('$profile_dir/manifest.yaml')); print(len(m.get('operations') or []))")

  if [[ "$ops_count" -eq 0 ]]; then
    echo "No operations defined — done."
    return 0
  fi

  echo "Operations to execute: $ops_count"

  for i in $(seq 0 $((ops_count - 1))); do
    local op source target reason
    op=$(python3 -c "import yaml; m=yaml.safe_load(open('$profile_dir/manifest.yaml')); print(m['operations'][$i].get('op', ''))")
    source=$(python3 -c "import yaml; m=yaml.safe_load(open('$profile_dir/manifest.yaml')); print(m['operations'][$i].get('source', ''))")
    target=$(python3 -c "import yaml; m=yaml.safe_load(open('$profile_dir/manifest.yaml')); print(m['operations'][$i].get('target', ''))")
    reason=$(python3 -c "import yaml; m=yaml.safe_load(open('$profile_dir/manifest.yaml')); print(m['operations'][$i].get('reason', ''))")

    case "$op" in
      add)     op_add "$profile_dir" "$source" "$target" "$reason" ;;
      replace) op_replace "$profile_dir" "$source" "$target" "$reason" ;;
      delete)  op_delete "$target" "$reason" ;;
      *)       echo "ERROR: unknown op '$op'" >&2; exit 1 ;;
    esac
  done
}

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN MODE — no changes will be made"
fi

if [[ "$PROFILE_MODE" -eq 1 ]]; then
  apply_profile_overlay "$OVERLAY_NAME"
  exit 0
fi

# === CLAUDE.md ===
[[ -f "$OVERLAY_DIR/claude-md-patch.md" ]] && process_md_target "CLAUDE.md" "$OVERLAY_DIR/claude-md-patch.md"

# === Agent patches ===
for role in ba sa dev; do
  patch="$OVERLAY_DIR/agent-patches/$role-smp-extension.md"
  agent=".claude/plugins/project/agents/$role-agent.md"
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
