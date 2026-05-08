# AGENTS.md — Example Product

Матрица ролей, режим исполнения, каталог pipelines и контракт самоулучшения команды AI-агентов проекта.

## Каталог ролей

| Имя | Описание | Где исполняется | Модель | Промпт-файл | Slash-команды |
|-----|----------|-----------------|--------|-------------|---------------|
| pm | Координатор/orchestrator | main | Opus | (main, не subagent) | `/pm` |
| researcher | Контекст-сборщик | subagent | Sonnet | `.claude/plugins/project/agents/researcher-agent.md` | `/research` |
| ba | Бизнес-аналитик; режимы: author, acceptance | subagent | Sonnet | `.claude/plugins/project/agents/ba-agent.md` | `/ba`, `/ba --mode=acceptance` |
| sa | Архитектор / системный аналитик | subagent | Sonnet | `.claude/plugins/project/agents/sa-agent.md` | `/sa` |
| dev | TDD-разработчик | subagent | Sonnet | `.claude/plugins/project/agents/dev-agent.md` | `/dev` |
| devops | Эксплуатация (опц.) | subagent | Sonnet | `.claude/plugins/project/agents/devops-agent.md` | `/devops` |
| qa | QA с режимами author/runner | subagent | Sonnet | `.claude/plugins/project/agents/qa-author-agent.md` (AT) + `.claude/plugins/project/agents/qa-runner-agent.md` (Tester) | `/qa --mode=author`, `/qa --mode=runner` |
| tech-writer | Документатор (secondary editor / primary author per profile) | subagent | Sonnet | `.claude/plugins/project/agents/tech-writer-agent.md` | `/tech-writer` |
| devsecops | Embedded security в Dev (opt-in) | subagent | Sonnet | `.claude/plugins/project/agents/devsecops-agent.md` | `/devsecops` |
| compliance | Research compliance (opt-in) | subagent | Sonnet | `.claude/plugins/project/agents/compliance-agent.md` | `/compliance` |

**Почему так:** PM-координация живёт в main-context, чтобы не раздувать контекст субагентов. Ролевая работа вытесняется в субагенты на более дешёвой модели — экономия LLM-бюджета. DevOps/DevSecOps/Compliance/Tech Writer — opt-in (включаются профилем или явным запросом).

## Контракт вызова субагента (универсальный)

При запуске любой роли (через `/<command>` или Task tool) передавай:

1. **Цель** одной фразой.
2. **Входные файлы** — пути к контексту (требование, ADR, код, источники). Субагент сам прочитает.
3. **Ожидаемый артефакт** — какой файл должен появиться/измениться.
4. **Критерии приёмки** — как проверить, что задача выполнена.

Пример корректного prompt'а для `/dev`:

```
Цель: реализовать UserSessionRepository по архитектурной спецификации.
Входы: content/40-architecture/sessions.md, content/30-requirements/user-sessions.md, tests/auth/test_user_session.py (failing stubs от qa-author)
Артефакт: src/repositories/user_session.py
Критерии: pytest зелёный, типы аннотированы, метод ≤20 строк, AC из требования покрыты тестами от qa-author.
```

Субагент **не ищет контекст «вокруг»** — работает по явно переданному скопу.

(Полные prompt'ы — в `.claude/plugins/project/agents/<role>-agent.md`.)

## Матрица «роль × профиль»

| Роль | project | product | kb-product | kb-team | custom | methodology | course |
|------|---------|---------|-----------|---------|--------|-------------|--------|
| pm | core | core | core | core | core | core | core |
| researcher | optional | optional | optional | optional | optional | optional | optional |
| ba | core | core | optional | disabled | optional | disabled | optional |
| sa | core | core | disabled | disabled | optional | disabled | disabled |
| dev | core | core | disabled | disabled | optional | disabled | disabled |
| devops | optional | optional | disabled | core | optional | disabled | disabled |
| qa | core | core | disabled | disabled | optional | disabled | disabled |
| tech-writer | optional | optional | core | core | optional | core | core |
| devsecops | optional | optional | disabled | disabled | optional | disabled | disabled |
| compliance | optional | optional | optional | optional | optional | optional | optional |

Эта матрица — derived из manifest'ов в `docs/overlays/profiles/<name>/manifest.yaml` (поле `subagents`). Ручная синхронизация поддерживается `validate-profile.py` (M4).

## Каталог pipelines

| Pipeline | Назначение | Slash-команда | Артефакты | Worktree |
|----------|------------|---------------|-----------|----------|
| project-planning | Декомпозиция эпика на задачи + roadmap | `/pipelines/project-planning <epic>` | `content/00-project/plans/<epic>.md` | per-pipeline |
| ba-acceptance | Gate проверка AC ↔ реализация | `/pipelines/ba-acceptance <req>` | acceptance log в требовании | inline в epic-worktree |
| critical-path | Анализ зависимостей задач | `/pipelines/critical-path <epic>` | `content/00-project/critical-path/<epic>.md` | inline |
| scrum-agile | (stub Wave 3+) | (планируется) | (планируется) | per-pipeline |

## Pipeline-orchestration model

- PM создаёт worktree через `superpowers:using-git-worktrees`: `git worktree add .worktrees/epic-<slug> -b epic-<slug> private`
- В пределах одной pipeline: subagent'ы работают последовательно в одной и той же worktree
- Параллельные стадии (несколько Dev-задач, Researcher + BA одновременно): через `superpowers:dispatching-parallel-agents` (child worktrees → merge обратно в epic-worktree)
- После успешного pipeline'а PM делает PR `epic-<slug>` → `private` → (после `/pm-review`) → `public`

## Поток работы (канонический порядок)

Researcher (опц.) → BA → SA → QA-author → Dev → QA-runner → BA-acceptance gate → DevOps (если deploy)

PM координирует на каждом этапе: приоритизирует, разрешает блокеры, запускает `/pm-review` перед merge в `public`.

DevSecOps активируется в Dev-фазе при flag'е (профиль или явный запрос); Compliance — research-mode по запросу.

Ветвление: `private` — рабочая ветка; `public` — публикация в Gramax после ревью PM.

## Self-improvement

- `docs/lessons-learned.md` — append-only журнал
- Субагенты сохраняют находки в auto-memory (типы: `reference`, `project`, `feedback`)
- `/pm-review` читает lessons + memory и предлагает обновления `CLAUDE.md` / промтов агентов

## Красные линии (универсальные)

- НЕ публиковать секреты (`.env`, токены, API-ключи, credentials)
- НЕ включать PII (реальные имена, контакты, персональные данные сотрудников/клиентов)
- НЕ менять `.doc-root.yaml` и `.gramax/` без согласования (через SA + ADR)
- НЕ создавать статьи в `content/` без обязательных properties (см. `.doc-root.yaml`)
- НЕ принимать задачи `/dev` без предшествующего артефакта SA (`content/40-architecture/` или ADR)
- НЕ передавать тесты из Dev в qa-runner до прохождения qa-author stub'ов (TDD-цепочка обязательна)
- Tests/линтеры (если в проекте есть) — зелёные перед commit
