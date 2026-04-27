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

# 4. Подстановка {{PROJECT_NAME}} в CLAUDE.md, AGENTS.md, README.md
# Используем portable sed (работает на macOS и Linux): sed -i.bak ... && rm *.bak
for f in CLAUDE.md AGENTS.md README.md; do
  if [[ -f "$f" ]] && grep -q '{{PROJECT_NAME}}' "$f"; then
    sed -i.bak "s/{{PROJECT_NAME}}/$NAME/g" "$f"
    rm -f "$f.bak"
    echo "✓ replaced {{PROJECT_NAME}} in $f"
  fi
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
