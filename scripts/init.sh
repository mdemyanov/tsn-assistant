#!/usr/bin/env bash
# init.sh — first-run инициализация шаблона.
# Заменяет {{PROJECT_NAME}}, создаёт ветку private, копирует .env.

set -euo pipefail

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
    echo "Доступные профили:"
    for p in docs/overlays/profiles/*/; do
      [[ ! -d "$p" ]] && continue
      pname=$(basename "$p")
      [[ "$pname" == ".gitkeep" ]] && continue
      [[ -f "$p/manifest.yaml" ]] && echo "  - $pname"
    done
    read -r -p "Профиль (default: project): " PROFILE
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
  # --force нужен потому что Wave 1 scaffold (30-requirements/, 40-architecture/...)
  # содержит реальный baseline-контент, который kb-team / другие профили удаляют.
  # На init это безопасно: пользователь только что клонировал шаблон.
  if ! bash scripts/apply-overlay.sh --profile --init --force "$PROFILE"; then
    echo "ERROR: apply-overlay.sh упал на профиле '$PROFILE'" >&2
    exit 1
  fi

  # После применения профиля — заново подставить плейсхолдеры в новых файлах из scaffold
  for f in CLAUDE.md AGENTS.md README.md content/.doc-root.yaml content/_index.md $(find content -name '_index.md' 2>/dev/null); do
    replace_in_file "$f" '{{PROJECT_NAME}}'        "$NAME"
    replace_in_file "$f" '{{PROJECT_CODE}}'        "$CODE"
    replace_in_file "$f" '{{PROJECT_DESCRIPTION}}' "$DESCRIPTION"
    replace_in_file "$f" '{{EDITOR_EMAIL}}'        "$EDITOR_EMAIL"
  done

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
