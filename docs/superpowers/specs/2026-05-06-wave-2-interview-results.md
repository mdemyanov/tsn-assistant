# Wave 2 — Interview Results

**Дата:** 2026-05-06
**PM:** main (Opus, claude-opus-4-7[1m])
**Источник вопросов:** `docs/superpowers/specs/2026-05-06-multi-template-support-brief.md` (§9, §10.4, §10.8) + `docs/superpowers/specs/2026-05-06-wave-2-kickoff-prompt.md`

> Это краткий лог Q→A. Содержательные обоснования — в design-doc (`2026-05-06-multi-template-support-design.md`, ещё не написан) и в Plan'е реализации.

---

## Карта профилей и архитектура

### Q1 (§9.1) — Полный список профилей

**A:** **7 профилей.**

| Профиль | Аудитория | Wave 2 |
|---------|-----------|--------|
| `project` | Delivery-проект (текущий дефолт) | **baseline (реализация)** |
| `kb-team` | Внутренняя командная KB (onboarding/runbook/role/incident) | **контрастный baseline (реализация)** |
| `product` | Разработка продукта/модуля | stub-манифест |
| `kb-product` | Документация продукта/процесса для внешних читателей | stub-манифест |
| `custom` / `minimal` | Open-ended | stub-манифест |
| `methodology` | *(добавлен в интервью)* — методология / playbook / framework | stub-манифест |
| `course` / `training` | *(добавлен в интервью)* — обучающий курс | stub-манифест |

В Wave 2 — framework + 2 рабочих профиля; остальные 5 — декларативные stub-манифесты в задел Wave 3+.

### Q2 (§9.2) — Глубина различий профилей

**A:** **Hybrid.**

- L1 (декларация: scaffold + properties + subagent-set + pipeline-set) — для `project`, `product`, `kb-product`, `kb-team`, `custom`.
- L2/L3 (workflow + acceptance customization) — потенциально для `methodology` и `course` (в Wave 2 не реализуется, фиксируется как направление в Wave 3+).
- В Wave 2 implementation: только L1 на всех профилях.

### Q3 (§9.3) — Архитектурное направление

**A:** **B+C гибрид.**

- `/init` интерактивно спрашивает профиль (UX из Option B).
- Под капотом дёргает расширенный `apply-overlay.sh <profile>` (механика из Option C).
- Stack-overlay (`naumen-smp` и др.) применяется отдельно — стэкабельно с профилем.
- Профиль = overlay-манифест в `docs/overlays/profiles/<name>/` (отдельная папка от stack-overlay'ов).
- `apply-overlay.sh` расширяется тремя операциями: **add** (текущее), **replace**, **delete**.

### Q4 (§9.4) — Wave 2.1 Research

**A:** **Полный Research.** Все три блока:

1. Profile-templating tools (Cookiecutter, copier, dbt-init, Rails generators, GitHub template-repos).
2. Multi-agent frameworks (AutoGen, CrewAI, LangGraph, AgentScope) — особенно для дизайна 5 новых ролей и 3 pipelines.
3. Эталоны KB-каталогов (`naumen-ecosystem/business-requirements/`, `naumen-smp-mcp/`).

Артефакт: `content/10-domain/research/multi-template-landscape.md`.

### Q5 (§9.5) — Срок Wave 2

**A:** **Без deadline. Разработка через `superpowers:subagent-driven-development`. Opus-модель для subagent'ов разрешена** (явное согласие owner'а; зафиксировано в auto-memory `feedback_subagent_opus_authorized.md`).

---

## Subagents и pipelines

### Q6 (§10.8.6) — Subagents в Wave 2

**A:** **Все 5 новых subagents как полноценные prompt'ы.**

После Q15 (см. ниже) AT и Tester объединены в **единого `qa-agent` с `--mode=author|runner`**. Итого новые роли в каталоге:
- **qa-agent** (objединяет AT+Tester) — `--mode=author` пишет тесты по AC до Dev; `--mode=runner` прогоняет suite после Dev.
- **tech-writer-agent** — документирование, customer-facing docs.
- **devsecops-agent** — embedded в Dev-фазу, secrets/SAST/supply-chain.
- **secure-compliance-agent** — отдельный аудит-трек на запрос (152-ФЗ, ISO27001, internal compliance — general-purpose research, см. Q10).

**Дополнительно:** owner попросил **улучшить и все 6 текущих агентов** (PM, Researcher, BA, SA, Dev, DevOps) с учётом новых ролей и нового разделения труда.

**Итого после Wave 2:** **10 ролей** в каталоге (4 новых + 6 обновлённых).

### Q7 (§10.8.7) — Pipelines в Wave 2

**A:** **3 pipeline.**

- **project-planning** — декомпозиция эпика, оценка, roadmap.
- **BA-acceptance** — формальный gate приёмки реализации Dev'а аналитиком (BA проверяет AC).
- **critical-path** — анализ зависимостей, blocking chain, длительности (mermaid Gantt).

**В задел Wave 3+:** scrum-agile (sprint planning, daily, retro).

### Q8 (§10.8.8) — Активация opt-in subagents

**A:** **Оба пути активации:**

- **User-slash:** `/devsecops audit ...`, `/compliance check 152-fz ...` — пользователь явно вызывает.
- **PM-decompose:** PM в `/pm decompose <epic>` может включить opt-in subagent в задачи декомпозиции.

(См. Q13 — auto-trigger от профиля + soft-suggest от PM.)

### Q9 (§10.8.9) — AT-формат тестов

**A:** **Гибрид .md-design + failing test stubs.**

- AT-design: `content/30-requirements/<req>/at-design.md` — таблица AC → assertion outline (читабельно для BA, источник для BA-acceptance pipeline).
- Failing test stubs: `tests/...` (язык-нативные, по стеку проекта) — input для Dev'а, делает зелёным в TDD-цикле.

### Q10 (§10.8.10) — Compliance scope

**A:** **General-purpose research.** Compliance — research-агент с уклоном в ИБ. Правила пользователь передаёт в запросе (152-ФЗ, ISO27001, internal — что нужно, то и проверяет). Никакой доменной базы правил в шаблоне — переход к pluggable-overlay только при появлении первого реального compliance-проекта.

### Q11 (§10.4) — Где живёт каталог ролей *(open-ended)*

**A:** **Вариант 3 — AGENTS.md как реестр + manifest как фильтр.**

- **AGENTS.md** содержит реестр ролей (все 10 ролей с описанием, prompt-файлом, model'ю, контрактом вызова) — единый источник правды для людей.
- **`profiles/<name>/manifest.yaml`** — фильтр: `subagents: { pm: core, ba: core, tech-writer: optional, devsecops: optional, compliance: disabled }`. Манифест короткий, ссылается на AGENTS.md по имени роли.
- Нужен `validate-profile.py` (либо расширение `validate-content.py`) для проверки ссылок манифеста на реальные роли.

### Q12 (§10.4) — Организация subagent-prompts

**A:** **Вариант 3 — base + per-profile overrides.**

- Base prompt: `agents/<role>-agent.md` — используется по умолчанию во всех профилях.
- Override: `profiles/<name>/agent-overrides/<role>.md` — declarative-merge через frontmatter (`extends`, `sections: replace/append`).
- В Wave 2 overrides пустые на всех профилях; infra готова к Wave 3 (methodology/course).

### Q13 (§10.4) — Авто-триггеры активации opt-in

**A:** **Вариант C — profile flag at init + PM heuristic suggest.**

- На `/init` интерактивный вопрос: «Проект под compliance-надзором (152-ФЗ / ISO27001 / нет)?» → если да, manifest получает флаг → Compliance из `optional` поднимается в `core` для этого проекта.
- PM в `decompose` делает **мягкий suggest** при ключевых словах в brief'е («Я заметил «персданные» — включить DevSecOps в эту фичу?»). Без императивного включения — owner всегда явно подтверждает.

### Q14 (§10.4) *(closed pre-answer)* — Pipeline = orchestrator + worktree

**A (от owner):** **Pipeline = оркестратор-агент + поддержка распределённой команды через worktree branch-per-epic.**

- Pipelines = специальные режимы PM-агента (или отдельный orchestrator-agent), который сам вызывает других subagents.
- PM создаёт worktree под эпик, назначает команду subagents, принимает результат, merge'ит.
- Используем существующий `superpowers:using-git-worktrees` или project-специфичную обёртку (решит SA на этапе дизайна).

### Q15 (§10.4) — AT vs Tester *(open-ended)*

**A:** **Вариант 3 — единый qa-agent с --mode флагом.**

- Один файл `agents/qa-agent.md` с двумя секциями: `## Mode: author` и `## Mode: runner`.
- Slash-команда `/qa --mode=author <req>` или `/qa --mode=runner <module>`.
- Templating перед запуском подставляет в промпт только релевантную секцию (узкий контекст).
- Каталог ролей сокращается с 11 до **10**.

### Q16 (§10.4) — Tech Writer — primary author или secondary editor

**A:** **Вариант B — base prompt = secondary editor + per-profile overrides.**

- Base `agents/tech-writer-agent.md` — secondary editor (берёт черновик от Dev/SA, переписывает на «понятный язык»).
- Per-profile overrides:
  - `profiles/kb-product/agent-overrides/tech-writer.md` — primary author.
  - `profiles/methodology/agent-overrides/tech-writer.md` — primary author (principles/practices/examples).
  - `profiles/course/agent-overrides/tech-writer.md` — primary author (modules/lessons).
- В Wave 2 overrides пустые (профили — stub'ы); base prompt работает в `project` и `kb-team`.

### Q17 (§10.4) *(closed pre-answer)* — DevSecOps vs Secure Compliance

**A (от owner):**

- **DevSecOps — embedded.** Решает задачи безопасности в рамках основного pipeline разработки. Активируется внутри Dev-фазы (по запросу или PM-suggest, см. Q8/Q13).
- **Secure Compliance — аудит на запрос, отдельный трек.** Не часть основного pipeline. Активируется через `/compliance ...` slash или PM-decompose.

### Q18 (§10.4) — Storage артефактов новых ролей *(переформулирован в kickoff)*

**A:** **Вариант C — гибрид.**

| Артефакт | Расположение | Подход |
|---------|--------------|--------|
| AT-design (test design до Dev) | `content/30-requirements/<req>/at-design.md` | Integrated рядом с требованием |
| QA-runner test report | `content/60-implementation/test-reports/<NNN>-<date>.md` | Integrated в реализационную зону |
| Tech Writer public docs | Внутри существующих с property `Audience=Public` (или новый профиль `kb-product` в Wave 3) | Integrated через property |
| DevSecOps audit findings | `content/00-project/security/audit-<NNN>-<date>.md` | Отдельная подпапка (параллельный трек) |
| DevSecOps secrets policy | `content/00-project/security/secrets-policy.md` | Та же подпапка |
| Compliance report | `content/00-project/compliance/<standard>-<date>.md` | Отдельная подпапка (параллельный трек) |
| Pipeline план эпика | `content/00-project/plans/<epic>.md` | Отдельная подпапка |
| Critical-path | `content/00-project/critical-path/<epic>.md` | Отдельная подпапка |

**Принцип:**
- Артефакты life-cycle конкретной фичи → integrated рядом с feature-артефактами.
- Артефакты параллельных треков (security/compliance/pipeline-orchestration) → отдельные подпапки.

**Новые подпапки в `project` baseline:**
- `content/00-project/security/`
- `content/00-project/compliance/`
- `content/00-project/plans/`
- `content/00-project/critical-path/`
- `content/60-implementation/test-reports/`

**Новые `Тип контента` values в `.doc-root.yaml` (для `project` профиля):**
- `Test Design`, `Test Report`, `Security Audit`, `Secrets Policy`, `Compliance Report`, `Plan`, `Critical Path`.

(Для `kb-team` профиля — другой `.doc-root.yaml` со своим набором; см. design-doc.)

---

## Метаданные и сигналы

- **Auto mode active** на этой сессии — minimize interruptions, prefer action.
- **Opus subagents authorized** для SDD-разработки в этом репо (одна из формулировок ответа Q5). Сохранено в auto-memory.
- **Owner попросил улучшить и существующие 6 ролей** (PM/Researcher/BA/SA/Dev/DevOps) с учётом разделения труда с новыми. Это отдельный поток работы внутри Wave 2.

## Next steps (после approve этого файла)

1. `/research <блок 1+2+3>` — в новом subagent'е (Wave 2.1). Артефакт: `content/10-domain/research/multi-template-landscape.md`.
2. `superpowers:brainstorming` — уточнить sporных моментов design'а (manifest schema, override-merge mechanics, pipeline-orchestrator-API).
3. **Spec** в `docs/superpowers/specs/2026-05-06-multi-template-support-design.md`.
4. После approve — **plan** в `docs/superpowers/plans/2026-05-06-multi-template-support.md`.
5. Реализация через `superpowers:subagent-driven-development`.
