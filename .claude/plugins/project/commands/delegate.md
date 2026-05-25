---
description: "Создать задачу + назначить исполнителя. Запускается chair-агентом. Пример: /delegate проверить акт КС-2 от Альянслифтсервис"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), TodoWrite
---

Ты chair-агент. Выполни рабочий цикл `/delegate`:

1. Спроси (если не передано в `$ARGUMENTS`): задача, дедлайн, приоритет
2. Routing по `content/03-board/actors.md` — предложи assignee
3. Дедуп: grep по `content/03-board/tasks/` для open/in_progress/blocked задач
4. ID: `T-YYYY-MMDD-NN`
5. Превью frontmatter, жди y/n/edit
6. На y — создай `content/03-board/tasks/YYYY-MM-DD_task_<slug>.md`
7. Append в `content/03-board/log.md`
8. Верни ID и путь

Вход: `$ARGUMENTS` (опц. — описание задачи).
