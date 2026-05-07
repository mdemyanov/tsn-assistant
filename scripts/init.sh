#!/usr/bin/env bash
# init.sh — first-run инициализация шаблона.
# Заменяет {{PROJECT_NAME}}, создаёт ветку private, копирует .env.

set -euo pipefail

# ===== Helper functions =====

print_profile_menu() {
  # Собрать список профилей через python3 (YAML parse + sort)
  local PROFILES_JSON
  PROFILES_JSON=$(python3 -c "
import yaml, json, os, glob
profiles = []
for mf in glob.glob('docs/overlays/profiles/*/manifest.yaml'):
    try:
        m = yaml.safe_load(open(mf))
        profiles.append({
            'name':        m.get('name', os.path.basename(os.path.dirname(mf))),
            'description': m.get('description', ''),
            'audience':    m.get('audience') or '',
            'status':      m.get('status', 'stable'),
        })
    except Exception:
        pass  # битый manifest — пропустить без crash
# sort: project first, stable alphabetically, остальные в конце
def sort_key(p):
    if p['name'] == 'project': return (0, '')
    if p['status'] == 'stable': return (1, p['name'])
    return (2, p['name'])
profiles.sort(key=sort_key)
print(json.dumps(profiles))
" 2>/dev/null || echo "[]")

  if [[ -z "$PROFILES_JSON" ]] || [[ "$PROFILES_JSON" == "[]" ]]; then
    # Fallback на legacy-вывод
    echo "Доступные профили:"
    for p in docs/overlays/profiles/*/; do
      [[ ! -d "$p" ]] && continue
      pname=$(basename "$p")
      [[ "$pname" == ".gitkeep" ]] && continue
      [[ -f "$p/manifest.yaml" ]] && echo "  - $pname"
    done
    return
  fi

  echo "Available profiles:"
  local MAX_LEN
  MAX_LEN=$(echo "$PROFILES_JSON" | python3 -c "
import json, sys
ps = json.load(sys.stdin)
print(max(len(p['name']) for p in ps) if ps else 7)
" 2>/dev/null || echo "7")

  echo "$PROFILES_JSON" | python3 -c "
import json, sys
ps = json.load(sys.stdin)
max_len = $MAX_LEN
for p in ps:
    line = '  {:<{w}} — {}'.format(p['name'], p['description'], w=max_len)
    if p.get('audience'):
        line += ' [для: {}]'.format(p['audience'])
    print(line)
" 2>/dev/null
}

print_profile_summary() {
  local profile="$1"
  local mf="docs/overlays/profiles/${profile}/manifest.yaml"

  if [[ ! -f "$mf" ]]; then
    echo "Warning: cannot read manifest for profile '${profile}'"
    return 0
  fi

  python3 -c "
import yaml, sys
profile = '$profile'
mf = 'docs/overlays/profiles/' + profile + '/manifest.yaml'
try:
    m = yaml.safe_load(open(mf))
except Exception as e:
    print('Warning: cannot read manifest for profile ' + repr(profile) + ': ' + str(e))
    sys.exit(0)

desc      = m.get('description', '')
audience  = m.get('audience') or ''
ops       = m.get('operations') or []
overrides = m.get('agent_overrides') or {}
subagents = m.get('subagents') or {}
prompts   = m.get('init_prompts') or []

op_add     = sum(1 for o in ops if o.get('op') == 'add')
op_replace = sum(1 for o in ops if o.get('op') == 'replace')
op_resolve = sum(1 for o in ops if o.get('op') == 'resolve_agents')
op_total   = len(ops)

override_names = list(overrides.keys())

core_count     = sum(1 for v in subagents.values() if v == 'core')
optional_count = sum(1 for v in subagents.values() if v == 'optional')
disabled_count = sum(1 for v in subagents.values() if v == 'disabled')

print('Profile: ' + profile + ' — ' + desc)
print('  Description : ' + desc)
if audience:
    print('  Audience    : ' + audience)
ops_detail = 'add: {}, replace: {}'.format(op_add, op_replace)
if op_resolve:
    ops_detail += ', resolve_agents: {}'.format(op_resolve)
print('  Operations  : {} ({})'.format(op_total, ops_detail))
if override_names:
    print('  Overrides   : {} ({})'.format(len(override_names), ', '.join(override_names)))
else:
    print('  Overrides   : 0')
print('  Subagents   : {} core, {} optional, {} disabled'.format(
    core_count, optional_count, disabled_count))
print('  Init prompts: {}'.format(len(prompts)))
" 2>/dev/null || echo "Warning: cannot read manifest for profile '${profile}'"
}

confirm_apply() {
  local profile="$1"

  # Bypass: INIT_FORCE=1
  if [[ "${INIT_FORCE:-0}" == "1" ]]; then
    return 0
  fi

  # Bypass: non-interactive (no TTY on stdin)
  if [[ ! -t 0 ]]; then
    return 0
  fi

  # Интерактивный confirm
  read -r -p "Apply profile '${profile}'? (Y/n): " CONFIRM_ANSWER
  CONFIRM_ANSWER="${CONFIRM_ANSWER:-Y}"

  case "$CONFIRM_ANSWER" in
    n|N|no|NO)
      echo "Init cancelled by user. Re-run when ready."
      exit 0
      ;;
    *)
      return 0
      ;;
  esac
}

# ===== End helper functions =====

# T40: parse --profile flag BEFORE positional args
PROFILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --profile=*) PROFILE="${1#*=}"; shift ;;
    *) break ;;
  esac
done

# 1. Проверка, что мы в git-репо
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: not a git repository. Run 'git init' first."
  exit 1
fi

# 2. Проверка, что мы в корне проекта (есть CLAUDE.md)
if [[ ! -f CLAUDE.md ]]; then
  echo "ERROR: run from project root (where CLAUDE.md is)."
  exit 1
fi

# 3. Имя проекта — из аргумента или интерактивно
if [[ $# -ge 1 ]]; then
  NAME="$1"
else
  read -r -p "Имя проекта (PROJECT_NAME): " NAME
fi

if [[ -z "$NAME" ]]; then
  echo "ERROR: project name cannot be empty."
  exit 1
fi

if [[ ! "$NAME" =~ ^[A-Za-z0-9][A-Za-z0-9\ ._-]*$ ]]; then
  echo "ERROR: project name must start with [A-Za-z0-9] and contain only [A-Za-z0-9 ._-] (got: '$NAME')."
  exit 1
fi

# 3.1. Дополнительные параметры для content/.doc-root.yaml
NAME_UPPER="$(echo "$NAME" | tr '[:lower:]' '[:upper:]')"
if [[ $# -ge 2 ]]; then
  CODE="$2"
else
  read -r -p "Код каталога Gramax (PROJECT_CODE, например $NAME_UPPER): " CODE
fi
CODE="${CODE:-$NAME_UPPER}"

if [[ $# -ge 3 ]]; then
  DESCRIPTION="$3"
else
  read -r -p "Краткое описание каталога (PROJECT_DESCRIPTION): " DESCRIPTION
fi
DESCRIPTION="${DESCRIPTION:-Knowledge base for $NAME}"

if [[ $# -ge 4 ]]; then
  EDITOR_EMAIL="$4"
else
  read -r -p "Email редактора Gramax (EDITOR_EMAIL): " EDITOR_EMAIL
fi
EDITOR_EMAIL="${EDITOR_EMAIL:-editor@example.com}"

# 3.2. URL нового origin (опционально)
if [[ $# -ge 5 ]]; then
  GIT_REMOTE_URL="$5"
else
  read -r -p "URL нового origin (Enter — пропустить, добавить позже): " GIT_REMOTE_URL || GIT_REMOTE_URL=""
fi
GIT_REMOTE_URL="${GIT_REMOTE_URL:-}"

# 3.X — T40: Профиль (если не указан --profile, спросить интерактивно)
if [[ -z "$PROFILE" ]]; then
  if [[ ! -d "docs/overlays/profiles" ]]; then
    PROFILE="project"  # legacy fallback
    echo "WARNING: docs/overlays/profiles/ не найдена — fallback на профиль 'project'"
  elif [[ ! -t 0 ]]; then
    PROFILE="project"  # non-interactive default (e.g. echo | bash init.sh)
  else
    print_profile_menu                                             # <-- NEW
    echo ""
    read -r -p "Enter profile name (default: project): " PROFILE  # <-- UPDATED prompt
    PROFILE="${PROFILE:-project}"
  fi
fi

# Проверить что профиль существует
if [[ ! -d "docs/overlays/profiles/$PROFILE" ]]; then
  # Backwards-compat: если профилей нет в репо (старый шаблон), пропускаем профильный flow
  if [[ ! -d "docs/overlays/profiles" ]] || [[ -z "$(ls -A docs/overlays/profiles 2>/dev/null | grep -v '^\.gitkeep$')" ]]; then
    echo "WARNING: профильная система недоступна, init работает в legacy режиме (Wave 1)"
    PROFILE=""  # отключаем профильный flow
  else
    echo "ERROR: профиль '$PROFILE' не существует в docs/overlays/profiles/"
    exit 1
  fi
fi

if [[ -n "$PROFILE" ]]; then
  echo "Profile: $PROFILE"
  print_profile_summary "$PROFILE"  # <-- NEW
  confirm_apply "$PROFILE"          # <-- NEW
fi

# 3.3. Защита от случайного push в репозиторий шаблона
if [[ -n "$GIT_REMOTE_URL" ]]; then
  if [[ "$GIT_REMOTE_URL" =~ (project[-_]template)(\.git)?/?$ ]]; then
    echo "ERROR: URL ведёт на репозиторий шаблона ('$GIT_REMOTE_URL')."
    echo "  Это запрещено защитой от случайного push."
    echo "  Создай отдельный репозиторий для своего проекта и повтори init."
    exit 1
  fi
fi

# 3.4. Capture traceability шаблона до wipe
TEMPLATE_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
TEMPLATE_URL="$(git config --get remote.origin.url 2>/dev/null || echo unknown)"

# 4. Подстановка плейсхолдеров в CLAUDE.md, AGENTS.md, README.md, content/.doc-root.yaml
# Используем portable sed (работает на macOS и Linux): sed -i.bak ... && rm *.bak
replace_in_file() {
  local file="$1" placeholder="$2" value="$3"
  # экранируем разделитель | для безопасной подстановки email и описаний
  if [[ -f "$file" ]] && grep -q "$placeholder" "$file"; then
    sed -i.bak "s|$placeholder|$value|g" "$file"
    rm -f "$file.bak"
    echo "✓ replaced $placeholder in $file"
  fi
}

for f in CLAUDE.md AGENTS.md README.md content/.doc-root.yaml content/_index.md; do
  replace_in_file "$f" '{{PROJECT_NAME}}'        "$NAME"
  replace_in_file "$f" '{{PROJECT_CODE}}'        "$CODE"
  replace_in_file "$f" '{{PROJECT_DESCRIPTION}}' "$DESCRIPTION"
  replace_in_file "$f" '{{EDITOR_EMAIL}}'        "$EDITOR_EMAIL"
done

# 4.5 — T40: Применить профильный overlay (operations: add/replace/delete)
if [[ -n "$PROFILE" ]]; then
  echo "Applying profile overlay '$PROFILE'..."

  # T7 (W3-A1): Собрать ответы init_prompts из manifest + export как INIT_PROMPT_<id>
  if command -v python3 >/dev/null 2>&1; then
    PROMPTS_JSON=$(python3 -c "
import yaml, json
m = yaml.safe_load(open('docs/overlays/profiles/$PROFILE/manifest.yaml'))
print(json.dumps(m.get('init_prompts') or []))
" 2>/dev/null)

    if [[ -n "$PROMPTS_JSON" ]] && [[ "$PROMPTS_JSON" != "[]" ]]; then
      # Получить количество prompts
      PROMPTS_COUNT=$(echo "$PROMPTS_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")

      for i in $(seq 0 $((PROMPTS_COUNT - 1))); do
        PROMPT_ID=$(echo "$PROMPTS_JSON" | python3 -c "import json,sys; p=json.load(sys.stdin)[$i]; print(p.get('id', ''))")
        PROMPT_TEXT=$(echo "$PROMPTS_JSON" | python3 -c "import json,sys; p=json.load(sys.stdin)[$i]; print(p.get('prompt', ''))")
        PROMPT_TYPE=$(echo "$PROMPTS_JSON" | python3 -c "import json,sys; p=json.load(sys.stdin)[$i]; print(p.get('type', 'string'))")
        PROMPT_DEFAULT=$(echo "$PROMPTS_JSON" | python3 -c "import json,sys; p=json.load(sys.stdin)[$i]; print(p.get('default', ''))")
        PROMPT_CHOICES=$(echo "$PROMPTS_JSON" | python3 -c "import json,sys; p=json.load(sys.stdin)[$i]; c=p.get('choices') or []; print('|'.join(c))")

        if [[ -z "$PROMPT_ID" ]]; then continue; fi

        # T6 advisory I1: validate prompt id is valid bash identifier
        if ! [[ "$PROMPT_ID" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
          echo "ERROR: init_prompts id '$PROMPT_ID' содержит недопустимые символы (используй [A-Za-z0-9_] only)" >&2
          exit 1
        fi

        # Если non-interactive (нет TTY) или INIT_SKIP_PROMPTS — использовать default
        if [[ ! -t 0 ]] || [[ "${INIT_SKIP_PROMPTS:-0}" == "1" ]]; then
          ANSWER="$PROMPT_DEFAULT"
        else
          # Показать prompt + choices (если enum)
          if [[ "$PROMPT_TYPE" == "enum" ]] && [[ -n "$PROMPT_CHOICES" ]]; then
            echo "$PROMPT_TEXT (one of: $(echo "$PROMPT_CHOICES" | tr '|' ' '), default: $PROMPT_DEFAULT)"
          else
            echo "$PROMPT_TEXT (default: $PROMPT_DEFAULT)"
          fi
          read -r -p "  → " ANSWER
          ANSWER="${ANSWER:-$PROMPT_DEFAULT}"
        fi

        # Validate enum choice
        if [[ "$PROMPT_TYPE" == "enum" ]] && [[ -n "$PROMPT_CHOICES" ]]; then
          if ! echo "|$PROMPT_CHOICES|" | grep -qF "|$ANSWER|"; then
            echo "ERROR: '$ANSWER' не в choices [$PROMPT_CHOICES] для prompt '$PROMPT_ID'" >&2
            exit 1
          fi
        fi

        # Export
        export "INIT_PROMPT_$PROMPT_ID=$ANSWER"
        echo "  ✓ INIT_PROMPT_$PROMPT_ID=$ANSWER"
      done
    fi
  fi

  # --force нужен потому что Wave 1 scaffold (30-requirements/, 40-architecture/...)
  # содержит реальный baseline-контент, который kb-team / другие профили удаляют.
  # На init это безопасно: пользователь только что клонировал шаблон.
  if ! bash scripts/apply-overlay.sh --profile --init --force "$PROFILE"; then
    echo "ERROR: apply-overlay.sh упал на профиле '$PROFILE'" >&2
    exit 1
  fi

  # Post-overlay: scaffold may have brought in fresh files with placeholders — substitute in content/ only
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    replace_in_file "$f" '{{PROJECT_NAME}}'        "$NAME"
    replace_in_file "$f" '{{PROJECT_CODE}}'        "$CODE"
    replace_in_file "$f" '{{PROJECT_DESCRIPTION}}' "$DESCRIPTION"
    replace_in_file "$f" '{{EDITOR_EMAIL}}'        "$EDITOR_EMAIL"
  done < <(find content -name '*.md' -o -name '*.yaml' 2>/dev/null)

  # Опц. stack-overlay'и из compatible_stacks
  COMPAT_STACKS=$(python3 -c "
import yaml
m = yaml.safe_load(open('docs/overlays/profiles/$PROFILE/manifest.yaml'))
s = m.get('compatible_stacks') or []
print(','.join(s) if s and s != ['*'] else '')
" 2>/dev/null)

  if [[ -n "$COMPAT_STACKS" ]] && [[ "${INIT_SKIP_GIT_RESET:-0}" != "1" ]] && [[ -t 0 ]]; then
    echo "Совместимые stack-overlay'и для профиля '$PROFILE': $COMPAT_STACKS"
    read -r -p "Применить какие-то? (через запятую, или пусто чтобы пропустить): " STACKS_TO_APPLY
    if [[ -n "$STACKS_TO_APPLY" ]]; then
      IFS=',' read -ra STACKS <<< "$STACKS_TO_APPLY"
      for s in "${STACKS[@]}"; do
        s=$(echo "$s" | xargs)  # trim whitespace
        echo "  Applying stack '$s'..."
        bash scripts/apply-overlay.sh "$s"
      done
    fi
  fi
fi

# 4.6 — T40: Валидация
if command -v python3 >/dev/null 2>&1; then
  if [[ -f scripts/validate-content.py ]]; then
    python3 scripts/validate-content.py >/dev/null || {
      echo "WARNING: validate-content.py exit non-zero — проверь content/" >&2
    }
  fi
  if [[ -n "$PROFILE" ]] && [[ -f scripts/validate-profile.py ]]; then
    python3 scripts/validate-profile.py >/dev/null || {
      echo "WARNING: validate-profile.py exit non-zero" >&2
    }
  fi
fi

# 5. Wipe .git и initial commit (или skip для тестов)
if [[ "${INIT_SKIP_GIT_RESET:-0}" == "1" ]]; then
  # Тестовый режим: не трогаем .git, только создаём ветку private (если нет)
  if ! git show-ref --verify --quiet refs/heads/private; then
    git branch private
    echo "✓ created branch 'private' (INIT_SKIP_GIT_RESET=1)"
  fi
else
  # Проверка: для git commit нужны user.email и user.name (любого scope)
  GIT_EMAIL="$(git config user.email 2>/dev/null || true)"
  GIT_NAME="$(git config user.name 2>/dev/null || true)"
  if [[ -z "$GIT_EMAIL" || -z "$GIT_NAME" ]]; then
    echo "ERROR: git config user.email и/или user.name не настроены."
    echo "  Выполни:"
    echo "    git config --global user.email 'you@example.com'"
    echo "    git config --global user.name  'Your Name'"
    echo "  и повтори init."
    exit 1
  fi

  rm -rf .git
  git init -b main -q
  git add -A
  git commit -q \
    -m "Initial commit from project_template" \
    -m "Template: ${TEMPLATE_URL}@${TEMPLATE_SHA}" \
    -m "Initialized as: ${NAME} (${CODE})"
  git branch private
  echo "✓ wiped .git, created initial commit (Template: ${TEMPLATE_URL}@${TEMPLATE_SHA})"
  echo "✓ created branches 'main' and 'private'"
fi

# 5.1. Установить origin (если URL передан)
if [[ -n "$GIT_REMOTE_URL" ]]; then
  if git remote | grep -q '^origin$'; then
    git remote set-url origin "$GIT_REMOTE_URL"
  else
    git remote add origin "$GIT_REMOTE_URL"
  fi
  echo "✓ origin set to $GIT_REMOTE_URL"
else
  echo "WARNING: origin не настроен. До 'git remote add origin <url>' любой push провалится — это by design."
fi

# 6. Скопировать .env.example → .env (если .env нет)
if [[ -f .env.example ]] && [[ ! -f .env ]]; then
  cp .env.example .env
  echo "✓ created .env (заполни секреты)"
fi

# 7. Подсказка
echo ""
echo "Готово (фаза 1). Следующие шаги:"
echo "  1. Открой репо в Claude Code и выполни /init — фаза 2 (интервью по стеку, red-lines)."
echo "  2. (Опционально для SMP-проекта) bash scripts/apply-overlay.sh naumen-smp"
echo "  3. /pm decompose <твоя первая фича>"
