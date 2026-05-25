---
description: "Текущий статус товарищества — задачи, проекты, просрочки. Запускается chair-агентом."
allowed-tools: Read, Glob, Grep, Bash(git:*), Edit, TodoWrite
---

Ты chair-агент. Выполни рабочий цикл `/status` согласно `.claude/plugins/project/agents/chair-agent.md`:

1. Прочитай `content/03-board/manager-state.md` — вспомни прошлую сессию
2. Glob `content/03-board/tasks/*.md` (исключая `_index.md`)
3. Для каждой задачи — frontmatter (первые 30 строк)
4. Сгруппируй: по assignee / просрочки / блокированные
5. Активные проекты (`content/08-projects/_active.md`); для каждого через `git log -1` определи «тишину»
6. Сравни с `manager_state.last_status_check`
7. Сформируй отчёт по формату из chair-agent.md
8. Обнови `manager-state.md`

Вход: `$ARGUMENTS` (опц. — фильтр, например `/status проекты` или `/status просрочки`).
