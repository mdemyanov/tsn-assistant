---
description: "Ревью контента перед merge private→public. Читает lessons-learned и проверяет целостность content/. Пример: /pm-review"
allowed-tools: Read, Glob, Grep, Bash(git diff:*), Bash(git log:*), Bash(git status:*)
---

Ты — руководитель проекта в роли ревьюера. Проверь готовность к merge `private → public`.

## Что проверить

1. **Незакоммиченные изменения:** `git status` — должен быть чистый.
2. **Diff vs public:** `git diff public..private --name-only` — какие файлы пойдут в публикацию.
3. **Целостность `content/`:**
   - **Запусти валидатор:** `python3 scripts/validate-content.py`. Любой error — блокер merge. Warnings обозначь в отчёте.
   - Все статьи в `content/` имеют обязательные properties (см. `content/.doc-root.yaml`).
   - В новых ADR (`content/00-project/adr/`) — все ссылки на предшественников ведут на наполненные статьи (не болванки <100 байт).
   - В новых требованиях (`content/30-requirements/`) — есть JTBD и Acceptance Criteria.
4. **Lessons-learned:** прочитай `docs/lessons-learned.md` (свежие записи) и memory (через auto-memory). Предложи: какие фрагменты добавить в CLAUDE.md / промты агентов / глоссарий?

### Validation Step 2: Profile manifests (Wave 2)

Запусти:

```bash
python3 scripts/validate-profile.py
```

Expected: exit 0 (errors блокируют merge; warnings допустимы).

Если есть errors:
- M1 (manifest.yaml not found) — критично, проверь профиль
- M2 (required field missing) — добавь поле в manifest
- M3 (name != folder) — синхронизируй
- M4 (роль не в AGENTS.md) — синхронизируй матрицу в `AGENTS.md`
- M5 (pipeline file отсутствует) — создай `.claude/plugins/project/commands/pipelines/<name>.md` или пометь pipeline как `disabled`
- M6 (enum статус) — fix значение
- M7 (path не существует) — создай scaffold или измени status на `stub`

Warnings (M8/M9/M10) — info-only, не блокируют merge но fix рекомендован:
- M8 — on_value мутация на unknown subagent/pipeline
- M9 — compatible_stacks упоминает несуществующий overlay
- M10 — status mismatch (stable + empty scaffold или stub + non-empty)

### Pipeline-state check (Wave 2)

Если в репо активны pipeline-worktree'и или их планы, проверь их состояние перед merge:

```bash
# Активные epic-worktree'и
git worktree list | grep epic-

# Незавершённые планы
ls content/00-project/plans/ 2>/dev/null
```

Для каждого активного эпика:
- **Если pipeline complete** (все фазы closed, BA-acceptance gate passed) — merge OK.
- **Если pipeline in-progress** — НЕ блокируй merge `private → public` если эпик не зависит от мерджащегося контента; иначе — спроси PM.
- **Если worktree orphaned** (заброшен, нет коммитов > 7 дней) — предложи cleanup через `commit-commands:clean_gone`.

Записи в `content/00-project/plans/<epic>.md` должны иметь "Status" секцию (active / blocked / done). Если нет — попроси автора эпика обновить.

### Drift-check (SPDD two-way sync)

Выполни drift-check между `private` и `public`:

```bash
# 1. Определить активный профиль из content/.doc-root.yaml
# (поле profile: <name>; если отсутствует — INFO-skip, drift-check пропускается)

# 2. Получить список изменённых файлов
CHANGED_FILES=$(git diff --name-only public..private)

# 3. Получить bypass-reason из commit messages (если есть skip-drift: <reason>)
# 4. Запустить drift-check
uv run scripts/_drift_check.py \
  --changed-files $CHANGED_FILES \
  --manifest docs/overlays/profiles/<profile>/manifest.yaml \
  --base-ref public
```

Алгоритм (детали — `scripts/_drift_check.py` и design-spec §3c):
- Читает `profile:` из `content/.doc-root.yaml`; если поля нет → `[INFO] no profile marker, drift-check skipped`
- Читает `drift_pairs` из manifest профиля; если поле отсутствует → `[INFO]` skip
- Для каждой пары: если downstream-файлы изменились без upstream → `[WARN]`
- Bypass: `skip-drift: <reason>` trailer в commit message → `[INFO]` (reason не должен быть пустым)
- Пустой/whitespace-only reason → `[WARN]` о пустом reason

**WARN не блокирует merge автоматически — это soft-fail.** Требует подтверждения PM:
- PM читает WARN, понимает причину расхождения
- Принимает решение: merge (если расхождение допустимо) или вернуть на доработку
- При merge с WARN — добавить `skip-drift: <reason>` в commit или PR description

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
