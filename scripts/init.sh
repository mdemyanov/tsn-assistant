#!/usr/bin/env bash
# init.sh — first-run инициализация шаблона.
# Заменяет {{PROJECT_NAME}}, создаёт ветку private, копирует .env.

set -euo pipefail

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

for f in CLAUDE.md AGENTS.md README.md content/.doc-root.yaml; do
  replace_in_file "$f" '{{PROJECT_NAME}}'        "$NAME"
  replace_in_file "$f" '{{PROJECT_CODE}}'        "$CODE"
  replace_in_file "$f" '{{PROJECT_DESCRIPTION}}' "$DESCRIPTION"
  replace_in_file "$f" '{{EDITOR_EMAIL}}'        "$EDITOR_EMAIL"
done

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
