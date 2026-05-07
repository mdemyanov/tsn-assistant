# Wave 2 — Kickoff Prompt (для запуска в новом диалоге)

> Скопируй содержимое блока ниже целиком в новый чат с Claude Code в этом проекте. Всё необходимое для старта Wave 2 встроено в промт; интервью с owner'ом проводится в начале сессии перед любой реализацией.

---

```
Запусти Wave 2 — multi-template support + расширенный subagent-каталог проекта `project_template`.

## 0. Контекст одной фразой

Шаблон поддерживает только один тип проекта (delivery-проект) и шесть subagents. Нужно сделать профильную систему (project / kb-team / kb-product / product / custom) и добавить ещё пять ролей (Tester, AT, DevSecOps, Secure Compliance, Tech Writer) + четыре workflow-pipeline (project-planning, scrum-agile, critical-path, BA-acceptance).

## 1. Окружение

- **Working directory:** `/Users/mdemyanov/knowlage/project_template`
- **Ветка:** `private` (рабочая по конвенции CLAUDE.md; правки делать здесь, не в `main`)
- **Последний коммит:** `58a5828` (brief v1.1)
- **Wave 1 (только что закрыта):** 22 commits + T13.1 fix-up. Test suites зелёные:
  - `bash scripts/test-validate-content.sh` → 24/24
  - `bash scripts/test-template.sh` → 53/53
  - `python3 scripts/validate-content.py` → 0 errors / 2 warnings (placeholders) / exit 0

## 2. Артефакты к прочтению (обязательно)

В этом порядке:

1. **Brief Wave 2 (главное):** `docs/superpowers/specs/2026-05-06-multi-template-support-brief.md` — секции §1–§10 целиком. Здесь зафиксированы: проблема, текущее состояние, гипотеза по 5 профилям, 4 архитектурных опции (A/B/C/D) с trade-offs, 18 открытых вопросов, sequence Wave 2.0–2.5, риски, acceptance.
2. **Spec Wave 1 (контекст:** что только что было сделано): `docs/superpowers/specs/2026-05-06-gramax-template-alignment-design.md`
3. **Plan Wave 1 (как мы работаем):** `docs/superpowers/plans/2026-05-06-gramax-template-alignment.md`
4. **CLAUDE.md, AGENTS.md** — текущие правила работы команды и контракт вызова субагентов
5. **`scripts/validate-content.py`** — каков сейчас validator, что делает; критично для понимания того, как профильная система должна расширить его поведение

После прочтения — кратко (3-5 строк) подтверди в чате, что прочитал и понял задачу. Не суммируй детали — просто маркер «контекст принят».

## 3. Pre-answered questions от owner (НЕ переспрашивай)

Owner уже ответил на часть вопросов. Учти эти ответы в дизайне, **не задавай повторно**, но при необходимости попроси уточнения:

### Q11 (из §10.4) — Где живёт каталог ролей: AGENTS.md vs profile manifest?
**Owner:** Предложи варианты и объясни разницу.
→ В интервью представь 2-3 варианта (например: «всё в AGENTS.md» / «только в манифесте» / «AGENTS.md как реестр + манифест как профильный фильтр»), trade-offs, твоя рекомендация. Затем дождись выбора.

### Q15 — AT vs Tester: одна роль в двух режимах или две роли?
**Owner:** Предложи варианты для упрощения работы и диверсификации.
→ В интервью представь варианты («один агент с режимами `--mode=author|runner`» / «две раздельные роли с разной моделью») с trade-offs (cognitive load на пользователя, качество output, prompt-engineering complexity). Затем дождись выбора.

### Q17 — DevSecOps vs Secure Compliance: разделение?
**Owner:** **DevSecOps — embedded** (решает задачи безопасности в рамках основного pipeline разработки). **Secure Compliance — аудит + формирование требований** (по запросу, на отдельном треке, не часть основного pipeline).
→ Это закрытый ответ. Зафиксируй в дизайне как разделение по характеру вовлечённости: DevSecOps активируется внутри Dev-фазы, Secure Compliance — независимый workflow-режим.

### Q14 — Pipeline = последовательность slash-команд или оркестратор-агент?
**Owner:** **Оркестратор-агент + поддержка распределённой команды.** Пример: ПМ создаёт отдельную ветку под эпик и назначает команду subagents на её реализацию.
→ Это значимый архитектурный inputs. Имплицирует:
  - Pipelines = специальные режимы PM-агента (или отдельный orchestrator-agent), который сам вызывает других subagents
  - Поддержка git worktree / branch-per-epic
  - Возможно coordination через manifest — какая команда (subagent-set) назначена на эпик
  - На SA-этапе явно проработать механику «PM создаёт worktree → запускает subagents → принимает результат → merge». Как это сейчас делает `superpowers:using-git-worktrees` — переиспользовать или нужна project-специфичная обёртка.

### Q18 (storage артефактов новых ролей) — owner не понял вопрос
**Прояснение:** имелось в виду: куда в файловой структуре `content/...` складывать выходные артефакты новых subagents. Например:
  - Tester прогнал тесты → отчёт → куда? (`content/60-implementation/test-reports/<date>.md`?)
  - AT написал test design до Dev → куда? (`content/40-architecture/test-design.md`? `content/30-requirements/<req>/at.md`?)
  - Tech Writer выкатил статью для пользователей → отдельная подпапка (`content/80-public-docs/`?) или интегрировано в существующие?
  - DevSecOps audit findings → `content/00-project/security-audit-<date>.md`?
  - Compliance report → `content/00-project/compliance/<standard>-<date>.md`?
→ Спроси owner'а: предпочитает интеграцию в существующие папки (новые типы статей с новыми properties) или отдельные подпапки на каждый тип артефакта. Покажи примеры.

## 4. Pending questions — обязательно проинтервьюировать (по очереди)

Пройдись по этим вопросам **по одному**, multiple-choice предпочтительнее. Каждый ответ owner'а сразу фиксируй в TodoWrite или в локальной заметке (для последующего использования в spec/plan).

### Из §9 (приоритеты Wave 2 как такового)
1. **Полный список профилей.** Достаточно ли 5 (project / product / kb-product / kb-team / custom)? Или нужно больше / меньше?
2. **Глубина различий профилей.** Только разный scaffold/properties? Или ещё разный workflow (другой порядок ролей, другие критерии приёмки)?
3. **Архитектурное направление** — Option A (variant-репы) / B (profile-driven /init) / C (расширенные overlay) / D (cherry-pick модули). Моя рекомендация в брифу — **C** или **гибрид B+C**. Подтверди или укажи альтернативу.
4. **Wave 2.1 Research** — запускать `/research` (сравнить cookiecutter / copier / multi-agent фреймворки), или owner ответит сам и Research пропускаем?
5. **Срок Wave 2** — есть deadline или нет?

### Из §10.8 (приоритеты по новым subagents/pipelines)
6. **Из 5 новых subagents** какие в **Wave 2** (минимум 2-3), какие в Wave 3 как stubs? Моя рекомендация: Tester + Tech Writer обязательно, AT желательно, DevSecOps + Secure Compliance в задел.
7. **Из 4 pipelines** какие в Wave 2? Моя рекомендация: project-planning + BA-acceptance.
8. **Активация opt-in subagents** — PM в декомпозиции (через `/pm decompose --enable=devsecops`)? User слешем (`/devsecops audit`)? Оба?
9. **AT-формат тестов** — BDD/gherkin? plain pytest? Что-то другое? Или решает SA?
10. **Compliance scope** — общий research-агент или нужна база доменных правил (152-ФЗ, ISO27001, internal compliance)?

### Дополнительно (из расширенного scope)
11. **Q12 (subagent-prompts)** — общая база с профильными overrides (например, `agents/pm-agent.md` базовый + `profiles/kb-team/agent-overrides/pm.md`), или отдельный prompt-файл на каждое сочетание?
12. **Q13 (activation триггеры optional)** — кроме owner-ответа на Q8: должны ли быть автоматические триггеры (например, project в compliance-домене → Secure Compliance активируется автоматически)?
13. **Q16 (Tech Writer vs Gramax)** — Tech Writer = primary author для kb-product/kb-team или secondary editor после Dev/SA?

## 5. Workflow исполнения

После того как все вопросы закрыты, действуй так:

1. **Запиши итоги интервью** в новый файл `docs/superpowers/specs/2026-05-06-wave-2-interview-results.md` — короткий список «Q → A». Закоммить отдельно (`docs(wave2): interview results`).
2. **`superpowers:brainstorming`** — на основе ответов уточни design (только спорные/открытые вопросы, ответы owner'а не пере-обсуждай). Brainstorming → spec.
3. **Spec пиши в `docs/superpowers/specs/2026-05-06-multi-template-support-design.md`** (полноценный design-doc по конвенции Wave 1: проблема, архитектура, компоненты, data flow, error handling, тесты, anti-scope, GO-критерии).
4. **После approve пользователем** — `superpowers:writing-plans`, plan в `docs/superpowers/plans/2026-05-06-multi-template-support.md`. Гранулярность задач — 2-5 минут на step (как в Wave 1).
5. **Исполнение** — `superpowers:subagent-driven-development`. По каждой задаче: implementer → spec-reviewer → quality-reviewer. Если задача мутирует context'а валидатора (как T13.1 в Wave 1) — добавь fix-up коммит, не откладывай.
6. **Финальный review** — `superpowers:requesting-code-review` на всю ветку перед предложением merge.

## 6. Constraints (важно)

- **Не пушь в `main` без явного одобрения owner'а.** Все правки на `private`.
- **Не амендь коммиты.** Любая правка — новый атомарный коммит.
- **Не запускай destructive операции** (`git reset --hard`, удаление веток) без подтверждения.
- **Тесты должны быть зелёные** перед каждым коммитом implementer'а: `bash scripts/test-validate-content.sh && bash scripts/test-template.sh`. Если падает — fix-up в той же задаче, не пытайся пройти broken state.
- **Validator должен оставаться обратно совместимым** — старые проекты (single-profile) должны работать без изменений или иметь явный migration path.
- **Не ломай Wave 1 контракты:** _index.md везде, object-нотация frontmatter, шпаргалка в CLAUDE.md, validator в `pm-review`.
- **Auto mode:** работай автономно, спрашивай только когда **на самом деле** заблокирован (неоднозначность с архитектурными последствиями) или предстоит destructive action.

## 7. Quality bar

- Все 5 новых subagent-prompt'ов созданы (минимум как stubs с контрактом, как в `agents/researcher-agent.md`).
- Минимум 2 рабочих профиля (рекомендую `project` как baseline + `kb-team` как контрастный — final выбор после Q1/Q6).
- Manifest schema задокументирована и валидируется (новый раздел в validate-content.py или отдельный `validate-profile.py`).
- `/init` поддерживает выбор профиля (Phase 1: bash + slash интерактивно).
- `test-template.sh` гоняет матрицу профилей.
- Документация: «как добавить роль», «как добавить pipeline», «как добавить профиль» (можно в одном гайде `docs/extending.md`).
- Обратная совместимость: существующий шаблон без явного профиля = `project` профиль.
- Lessons-learned + ADR: значимые решения зафиксированы.

## 8. Старт

Прочитай артефакты §2 → подтверди контекст одним сообщением → начни интервью с Q1.
```

---

## Метаданные для тебя (PM)

- **Файл:** `docs/superpowers/specs/2026-05-06-wave-2-kickoff-prompt.md`
- **Когда использовать:** запустить новый чат Claude Code в `/Users/mdemyanov/knowlage/project_template`, скопировать блок выше (всё что между ``` ``` ```)
- **Что произойдёт:** Claude прочитает контекст, подтвердит, проинтервьюирует (~13 вопросов с pre-answers по 4 из них уже учтены), напишет spec, попросит approve, напишет plan, попросит approve, и автономно прогонит реализацию через subagent-driven-development.
- **Pre-answers зафиксированные:** Q11 (предложить варианты — open-ended), Q15 (предложить варианты — open-ended), Q17 (DevSecOps embedded, Compliance — аудит на запрос), Q14 (Pipeline = orchestrator + поддержка распределённой команды через ветки/worktrees), Q18 (мной переформулирован).
