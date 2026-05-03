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

if [[ ! "$NAME" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "ERROR: project name must match [A-Za-z0-9._-]+ (got: '$NAME')."
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

# 5. Создать ветку private (если нет)
if ! git show-ref --verify --quiet refs/heads/private; then
  git branch private
  echo "✓ created branch 'private'"
fi

# 6. Скопировать .env.example → .env (если .env нет)
if [[ -f .env.example ]] && [[ ! -f .env ]]; then
  cp .env.example .env
  echo "✓ created .env (заполни секреты)"
fi

# 7. Подсказка
echo ""
echo "Готово. Следующие шаги:"
echo "  1. (Опционально для SMP-проекта) bash scripts/apply-overlay.sh naumen-smp"
echo "  2. Открой репо в Claude Code — плагины подцепятся через .claude/settings.json"
echo "  3. /pm decompose <твоя первая фича>"
