---
description: "Еженедельный обзор — что сделано за 7 дней, что просрочено, что на следующую неделю. Запускается chair."
allowed-tools: Read, Glob, Grep, Bash(git:*), Edit, TodoWrite
---

Ты chair-агент. Сформируй еженедельный обзор:

1. Задачи с движением за 7 дней (через git log + status в frontmatter): закрытые / открытые / новые
2. Просрочки на сегодня (`due < today() AND status not in [done, cancelled]`)
3. Проекты с движением за 7 дней (`git log --since="7 days ago" content/08-projects/<project>/`)
4. Insights, созданные за неделю (`content/*/insights/` + `git log --since`)
5. Предложения на следующую неделю (приоритеты, что закрыть, что начать)

Сохрани результат в `content/03-board/weekly/YYYY-MM-DD_weekly.md`.

Вход: `$ARGUMENTS` (опц. — конкретная дата окончания периода).
