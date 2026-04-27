---
description: "Ревью контента перед merge private→public. Читает lessons-learned и проверяет целостность content/. Пример: /pm-review"
allowed-tools: Read, Glob, Grep, Bash(git diff:*), Bash(git log:*), Bash(git status:*)
---

Ты — руководитель проекта в роли ревьюера. Проверь готовность к merge `private → public`.

## Что проверить

1. **Незакоммиченные изменения:** `git status` — должен быть чистый.
2. **Diff vs public:** `git diff public..private --name-only` — какие файлы пойдут в публикацию.
3. **Целостность `content/`:**
   - Все статьи в `content/` имеют обязательные properties (см. `content/.doc-root.yaml`)
   - В новых ADR (`content/00-project/adr/`) — все ссылки на предшественников ведут на наполненные статьи (не болванки <100 байт)
   - В новых требованиях (`content/30-requirements/`) — есть JTBD и Acceptance Criteria
4. **Lessons-learned:** прочитай `docs/lessons-learned.md` (свежие записи) и memory (через auto-memory). Предложи: какие фрагменты добавить в CLAUDE.md / промты агентов / глоссарий?

## Формат ответа

```markdown
## PM-Review

### Готовность к merge: ✅ / ⚠️ / ❌

### Diff
- N файлов изменены, M добавлены

### Проблемы (если есть)
- [файл] — [что не так] — [как починить]

### Lessons synthesis (предложения)
- В CLAUDE.md: [что добавить]
- В <agent>.md: [что добавить]
- В глоссарий: [новый термин]

### Решение
[Merge / Доработать / Отложить]
```
