---
description: "Pipeline-orchestrator: декомпозиция эпика и проход через Researcher → BA → SA → QA-author → Dev → QA-runner → BA-acceptance. Пример: /pipelines/project-planning user-sessions"
allowed-tools: Bash, Task, Read, Edit, Write, Grep, Glob
---

# /pipelines/project-planning <epic>

Канонический pipeline для нового эпика. PM-orchestrator проводит эпик через все ролевые фазы в isolated worktree.

**Аргументы:** `$ARGUMENTS` — slug эпика (lowercase-hyphenated). Пример: `user-sessions`, `auth-rate-limit`.

## Алгоритм

### Шаг 1. Создать worktree

Используй `superpowers:using-git-worktrees`:

```bash
git worktree add .worktrees/epic-$ARGUMENTS -b epic-$ARGUMENTS private
cd .worktrees/epic-$ARGUMENTS
```

### Шаг 2. Researcher (опционально)

Если эпик в незнакомом домене или требует обзора литературы / конкурентов:

```
/research <topic для $ARGUMENTS>
```

→ артефакт `content/10-domain/research/<topic>.md`

Если домен знакомый — пропусти.

### Шаг 3. BA — формулировка требования

```
/ba new-requirement $ARGUMENTS
```

→ артефакт `content/30-requirements/$ARGUMENTS.md` с JTBD / FR / NFR / AC

### Шаг 4. SA — архитектура и контракт с QA-author

```
/sa design $ARGUMENTS
```

→ артефакт `content/40-architecture/<file>.md` (с ADR при необходимости + секция «Контракт с QA-author»)

### Шаг 5. QA-author — test design + failing stubs

```
/qa --mode=author $ARGUMENTS
```

→ артефакты `content/30-requirements/$ARGUMENTS/at-design.md` + `tests/<area>/test_$ARGUMENTS.<ext>` (failing)

### Шаг 6. Dev — implementation (TDD)

```
/dev implement $ARGUMENTS
```

→ артефакт `src/<...>` (делает stubs зелёными)

### Шаг 7. QA-runner — full suite

```
/qa --mode=runner $ARGUMENTS
```

→ артефакт `content/60-implementation/test-reports/<NNN>-<date>.md`

### Шаг 8. BA-acceptance gate

```
/pipelines/ba-acceptance $ARGUMENTS
```

→ acceptance log в требовании; вердикт pass / block

- **pass** → переход к шагу 9
- **block** → возврат к шагу 6 (Dev) с action items; pipeline ставится на паузу до фикса

### Шаг 9. PR + merge handoff

```bash
cd ../..  # назад в основной репо
git push origin epic-$ARGUMENTS
# открыть PR `epic-$ARGUMENTS` → `private`
```

После merge `private` → `private` (через PM-review) → `public`.

## Pipeline-state tracking

Создай файл `content/00-project/plans/$ARGUMENTS.md` со структурой:

```markdown
# Plan: $ARGUMENTS

## State
**Status:** active | blocked | done
**Current phase:** Researcher | BA | SA | QA-author | Dev | QA-runner | BA-acceptance | PR
**Started:** YYYY-MM-DD
**Blockers:** (если есть)

## Tasks
- [ ] RES-001: ...
- [ ] BA-001: ...
- [ ] SA-001: ...
- [ ] QA-AUTHOR-001: ...
- [ ] DEV-001: ...
- [ ] QA-RUNNER-001: ...
- [ ] BA-ACC-001: ...
```

Обновляй секцию **State** после каждого шага.

## Параллельные стадии

Если шаг можно распараллелить (несколько Dev-задач, или Researcher + BA одновременно для разных частей эпика) — используй `superpowers:dispatching-parallel-agents` (child worktrees → merge обратно в epic-worktree).

## Anti-scope

- НЕ запускай pipeline без worktree (изоляция критична).
- НЕ пропускай BA-acceptance gate.
- НЕ дописывай код после QA-runner — если runner failed, возвращайся в Dev.
- НЕ merge'и в `public` без `/pm-review`.
