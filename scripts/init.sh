#!/usr/bin/env bash
# init.sh — первичная инициализация TSN-assistant из шаблона.
# Подставляет плейсхолдеры, wipe .git, initial commit, ветка private, MCP install.

set -euo pipefail

# ===== Prerequisites =====
check_prerequisites() {
  if ! command -v uv >/dev/null 2>&1; then
    echo "ERROR: 'uv' не найден в PATH." >&2
    echo "" >&2
    echo "Установите uv и перезапустите init.sh:" >&2
    echo "  brew install uv  (macOS)" >&2
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh  (macOS/Linux)" >&2
    echo "  https://docs.astral.sh/uv/getting-started/installation/" >&2
    exit 1
  fi
}

# ===== Helpers =====
replace_in_file() {
  local file="$1" placeholder="$2" value="$3"
  if [[ -f "$file" ]] && grep -q "$placeholder" "$file"; then
    sed -i.bak "s|$placeholder|$value|g" "$file"
    rm -f "$file.bak"
    echo "✓ replaced $placeholder in $file"
  fi
}

# ===== Main =====
check_prerequisites

# 1. Проверка: git-репо
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: not a git repository. Run 'git init' first." >&2
  exit 1
fi

# 2. Проверка: корень проекта
if [[ ! -f CLAUDE.md ]]; then
  echo "ERROR: run from project root (where CLAUDE.md is)." >&2
  exit 1
fi

# 3. Параметры (позиционные или интерактивно)
if [[ $# -ge 1 ]]; then TSN_NAME="$1"; else read -r -p "Название товарищества (TSN_NAME): " TSN_NAME; fi
if [[ -z "$TSN_NAME" ]]; then echo "ERROR: TSN_NAME cannot be empty." >&2; exit 1; fi
if [[ ! "$TSN_NAME" =~ ^[A-Za-zА-Яа-я0-9][A-Za-zА-Яа-я0-9\ \.\,_\-\«\»\"\']*$ ]]; then
  echo "ERROR: invalid TSN_NAME chars (got: '$TSN_NAME')" >&2; exit 1
fi

NAME_UPPER="$(echo "$TSN_NAME" | tr '[:lower:]' '[:upper:]' | tr ' ' '-' | tr -cd 'A-Za-z0-9\-')"
if [[ $# -ge 2 ]]; then TSN_CODE="$2"; else read -r -p "Код Gramax (TSN_CODE, UPPERCASE, например $NAME_UPPER): " TSN_CODE; fi
TSN_CODE="${TSN_CODE:-$NAME_UPPER}"

if [[ $# -ge 3 ]]; then TSN_DESCRIPTION="$3"; else read -r -p "Краткое описание каталога (TSN_DESCRIPTION): " TSN_DESCRIPTION; fi
TSN_DESCRIPTION="${TSN_DESCRIPTION:-База знаний правления $TSN_NAME}"

if [[ $# -ge 4 ]]; then TSN_ADDRESS="$4"; else read -r -p "Полный адрес (TSN_ADDRESS): " TSN_ADDRESS; fi
TSN_ADDRESS="${TSN_ADDRESS:-<!-- TODO(/init): адрес -->}"

if [[ $# -ge 5 ]]; then CHAIR_NAME="$5"; else read -r -p "ФИО председателя/и.о. (CHAIR_NAME): " CHAIR_NAME; fi
CHAIR_NAME="${CHAIR_NAME:-<!-- TODO(/init): председатель -->}"

if [[ $# -ge 6 ]]; then EDITOR_EMAIL="$6"; else read -r -p "Email редактора Gramax (EDITOR_EMAIL): " EDITOR_EMAIL; fi
EDITOR_EMAIL="${EDITOR_EMAIL:-editor@example.com}"

if [[ $# -ge 7 ]]; then GIT_REMOTE_URL="$7"; else read -r -p "URL нового origin (Enter — пропустить): " GIT_REMOTE_URL || GIT_REMOTE_URL=""; fi
GIT_REMOTE_URL="${GIT_REMOTE_URL:-}"

# 4. Защита от случайного push в репо шаблона
if [[ -n "$GIT_REMOTE_URL" ]]; then
  if [[ "$GIT_REMOTE_URL" =~ (tsn[-_]assistant|project[-_]template)(\.git)?/?$ ]]; then
    echo "ERROR: URL ведёт на репозиторий шаблона ('$GIT_REMOTE_URL')." >&2
    echo "  Создай отдельный репозиторий для своего товарищества и повтори init." >&2
    exit 1
  fi
fi

# 5. Capture traceability шаблона
TEMPLATE_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
TEMPLATE_URL="$(git config --get remote.origin.url 2>/dev/null || echo unknown)"

echo ""
echo "=== Подстановка плейсхолдеров ==="
# 6. Подстановка плейсхолдеров в корневые файлы + content/
ROOT_FILES=(CLAUDE.md AGENTS.md README.md)
for f in "${ROOT_FILES[@]}"; do
  replace_in_file "$f" '{{TSN_NAME}}'        "$TSN_NAME"
  replace_in_file "$f" '{{TSN_CODE}}'        "$TSN_CODE"
  replace_in_file "$f" '{{TSN_DESCRIPTION}}' "$TSN_DESCRIPTION"
  replace_in_file "$f" '{{TSN_ADDRESS}}'     "$TSN_ADDRESS"
  replace_in_file "$f" '{{CHAIR_NAME}}'      "$CHAIR_NAME"
  replace_in_file "$f" '{{EDITOR_EMAIL}}'    "$EDITOR_EMAIL"
done

# Для content/ — пройдёмся find'ом по всем .md/.yaml
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  replace_in_file "$f" '{{TSN_NAME}}'        "$TSN_NAME"
  replace_in_file "$f" '{{TSN_CODE}}'        "$TSN_CODE"
  replace_in_file "$f" '{{TSN_DESCRIPTION}}' "$TSN_DESCRIPTION"
  replace_in_file "$f" '{{TSN_ADDRESS}}'     "$TSN_ADDRESS"
  replace_in_file "$f" '{{CHAIR_NAME}}'      "$CHAIR_NAME"
  replace_in_file "$f" '{{EDITOR_EMAIL}}'    "$EDITOR_EMAIL"
done < <(find content -type f \( -name '*.md' -o -name '*.yaml' \) 2>/dev/null)

# 7. Validate
echo ""
echo "=== Валидация ==="
if [[ -f scripts/validate-content.py ]]; then
  uv run scripts/validate-content.py >/dev/null 2>&1 || {
    echo "WARNING: validate-content.py exit non-zero — проверь content/" >&2
  }
fi

# 8. Wipe .git + initial commit (или skip для тестов)
echo ""
echo "=== Git ==="
if [[ "${INIT_SKIP_GIT_RESET:-0}" == "1" ]]; then
  if ! git show-ref --verify --quiet refs/heads/private; then
    git branch private
    echo "✓ created branch 'private' (INIT_SKIP_GIT_RESET=1)"
  fi
else
  GIT_EMAIL="$(git config user.email 2>/dev/null || true)"
  GIT_NAME="$(git config user.name 2>/dev/null || true)"
  if [[ -z "$GIT_EMAIL" || -z "$GIT_NAME" ]]; then
    echo "ERROR: git config user.email и/или user.name не настроены." >&2
    echo "  git config --global user.email 'you@example.com'" >&2
    echo "  git config --global user.name  'Your Name'" >&2
    exit 1
  fi

  rm -rf .git
  git init -b main -q
  git add -A
  git commit -q \
    -m "Initial commit (Template: ${TEMPLATE_URL}@${TEMPLATE_SHA})" \
    -m "Initialized from tsn-assistant template as: ${TSN_NAME} (${TSN_CODE})"
  git branch private
  echo "✓ wiped .git, created initial commit (Template: ${TEMPLATE_URL}@${TEMPLATE_SHA})"
  echo "✓ created branches 'main' and 'private'"
fi

# 9. Origin (опц.)
if [[ -n "$GIT_REMOTE_URL" ]]; then
  if git remote | grep -q '^origin$'; then
    git remote set-url origin "$GIT_REMOTE_URL"
  else
    git remote add origin "$GIT_REMOTE_URL"
  fi
  echo "✓ origin set to $GIT_REMOTE_URL"
else
  echo "WARNING: origin не настроен. До 'git remote add origin <url>' любой push провалится."
fi

# 10. .env
if [[ -f .env.example ]] && [[ ! -f .env ]]; then
  cp .env.example .env
  echo "✓ created .env (заполни секреты при необходимости)"
fi

# 11. MCP install (open-websearch, user-scope)
echo ""
echo "=== MCP ==="
if [[ "${INIT_SKIP_MCP:-0}" == "1" ]]; then
  echo "↷ skipping MCP install (INIT_SKIP_MCP=1)"
elif ! command -v claude >/dev/null 2>&1; then
  echo "WARNING: CLI 'claude' не найден в PATH — пропускаю установку open-websearch."
  echo "  Установи Claude Code и выполни вручную:"
  echo "    claude mcp add -s user -t stdio open-websearch \\"
  echo "      --env MODE=stdio DEFAULT_SEARCH_ENGINE=duckduckgo \\"
  echo "      ALLOWED_SEARCH_ENGINES=duckduckgo,bing,exa \\"
  echo "      -- npx open-websearch@latest"
elif claude mcp list 2>/dev/null | grep -qE '^open-websearch:'; then
  echo "✓ MCP open-websearch уже зарегистрирован (skip)"
else
  if claude mcp add -s user -t stdio open-websearch \
      --env MODE=stdio DEFAULT_SEARCH_ENGINE=duckduckgo ALLOWED_SEARCH_ENGINES=duckduckgo,bing,exa \
      -- npx open-websearch@latest >/dev/null 2>&1; then
    echo "✓ установлен MCP open-websearch (user-scope)"
  else
    echo "WARNING: не удалось зарегистрировать open-websearch — research-агент останется на WebFetch/WebSearch."
  fi
fi

# 12. Подсказка
echo ""
echo "Готово (Phase 1). Следующие шаги:"
echo "  1. Открой репо в Claude Code и выполни /init — Phase 2 (интервью)."
echo "  2. /status — увидеть стартовую картину"
echo "  3. /delegate <первая задача>"
