# Brief: Multi-Template Support — Preliminary Analysis & Task Setup

**Дата:** 2026-05-06
**Автор:** PM (main, Opus)
**Статус:** Brief v1.1 — input для волны 2 (Researcher → BA → SA → Dev → DevOps).

**Изменения v1.1 (2026-05-06):** добавлен скоуп §10 — расширенный каталог subagents (Tester / AT / DevSecOps / Secure Compliance / Tech Writer) и workflow-pipelines (project planning / scrum-agile / критический путь / приёмка аналитика). Эти элементы — часть профильного контракта и входят в Wave 2.

> Этот документ — НЕ финальный design. Он формулирует задачу, фиксирует первичный анализ и предлагает последовательность работы. Финальные решения принимаются на этапах Researcher / BA / SA с явными ADR.

---

## 1. Проблема

К шаблону `project_template` пришли пользователи с разными сценариями:

1. **Проект** — целевая разработка (BA→SA→Dev→Ops цепочка). *Текущий дефолт.*
2. **Разработка продукта/модуля** — продуктовая работа (spec → ADR → реализация → релиз).
3. **База знаний по продукту/процессу** — документирование внешнее, для стейкхолдеров/клиентов.
4. **База знаний команды** — onboarding, роли, runbooks, эскалация.
5. **«Другие похожие кейсы»** — open-ended (research-каталог, личный wiki, методология, ...).

Текущий шаблон даёт **один фиксированный scaffold** (`00-project/adr/`, `10-domain/`, `30-requirements/{functional,non-functional}/`, `40-architecture/`, `60-implementation/`, `70-operations/`). Для KB-сценариев это избыточно (нет требований/архитектуры в классическом виде); для продуктовой разработки — частично подходит, но названия секций не соответствуют.

Пользователь хочет, чтобы шаблон **умел подстраиваться под выбранный сценарий** при `/init`, сохраняя общее ядро.

---

## 2. Текущее состояние (что уже есть)

| Слой | Описание | Универсально / Variable |
|------|----------|--------------------------|
| `content/` директория | Корневая папка под Gramax-каталог | **Универсально** (всегда есть) |
| `content/.doc-root.yaml` | Конфиг каталога: properties, filterProperties, editors | **Универсально** (всегда есть) — но содержимое properties/values **variable** |
| `content/_index.md` | Главная страница каталога с навигацией и `<view>`-дашбордом | Универсально каркас, **variable** содержимое |
| Поддиректории content/ (00-project, 10-domain, 30-…) | Жёсткий scaffold | **Variable** — для KB-кейсов лишнее |
| `CLAUDE.md`, `AGENTS.md`, `README.md` | Главные доки | Универсально каркас, **variable** содержимое |
| `/init` (`scripts/init.sh` + `init.md`) | Двухфазный init (плейсхолдеры + интервью) | Универсально каркас, **variable** интервью |
| Subagents (`pm`, `ba`, `sa`, `dev`, `devops`, `research`) | Команда из 6 ролей | **Variable** — KB-команде не нужны Dev/DevOps |
| `scripts/apply-overlay.sh` + `docs/overlays/<name>/` | Аддитивные overlay'ы (есть `naumen-smp`) | **Универсально** механика — расширяема |
| `scripts/validate-content.py` | Validator C1-C7 | **Универсально** (только что добавлено в волне 1) |
| `private`/`public` ветки | Workflow | **Универсально** |
| `docs/lessons-learned.md` + auto-memory | Self-improvement | **Универсально** |

**Ключевые наблюдения:**

- Универсального ядра много (~60% кода и docs). Variable-частей — content/ scaffold, properties/values, subagent set, init-интервью.
- Уже есть overlay-механизм (`apply-overlay.sh`), но **только аддитивный** (заменяет блок между маркерами), не умеет:
  - удалять секции;
  - подменять `content/` scaffold;
  - выключать subagents.
- `/init` Phase 2 интервью — фиксированное (6 тем), не привязано к типу проекта.

---

## 3. Гипотеза по карте «профилей»

Первичная карта (требует валидации в Researcher/BA wave):

| Профиль | Аудитория | Целевой scaffold | Необходимые subagents | Properties в .doc-root.yaml |
|---------|-----------|------------------|------------------------|------------------------------|
| `project` | PM/команда delivery-проекта | Текущий (`00-project`, `30-requirements`, `40-architecture`, `60-implementation`, `70-operations`) | All (PM, Researcher, BA, SA, Dev, DevOps) | Тип контента, Фаза, Статус |
| `product` | Product owner / engineer-разработчик продукта | `00-project` (vision, ADR, roadmap), `30-spec` (product spec), `40-design`, `60-changelog`, `70-runbook` | PM, Researcher, BA (как Spec), SA, Dev, DevOps | Тип контента (Vision, Spec, ADR, Design, Changelog, Runbook), Статус, Релиз |
| `kb-product` | Документация продукта / процесса для внешних читателей | `10-domain` (термины), `20-howto` (гайды), `30-faq`, `40-process` (если процесс) | PM (минимум), Researcher (опц.), BA как редактор | Тип контента (Гайд, FAQ, Термин, Процесс), Целевая аудитория |
| `kb-team` | Внутренняя командная KB | `10-domain` (термины), `20-onboarding`, `30-runbooks`, `40-roles`, `50-incidents` | PM, Researcher (опц.), DevOps как owner runbook'ов | Тип контента (Onboarding, Runbook, Role, Incident, Эскалация), Owner (роль), Статус |
| `custom` / `minimal` | Open-ended | Только `content/_index.md` + `.doc-root.yaml` шаблон | Только PM | Минимум: Тип контента, Статус |

(Это **первая итерация**. На стадии BA уточнить — спрашивать пользователя, какие сценарии в реальности нужны.)

---

## 4. Подходы (architectural options)

### Option A — Несколько variant-репозиториев

**Что:** 4-5 отдельных шаблонов (`project_template`, `product_template`, `kb_product_template`, `kb_team_template`).

| Плюсы | Минусы |
|-------|--------|
| Простота — каждый template независим | Дублирование общего ядра (60%+) |
| Изменения локализованы | Drift — фиксы валидатора надо тиражировать N раз |
| Легко начать (просто форкнуть) | Сложно поддерживать инвариант «общее ядро ровное» |

### Option B — Один template + profile-driven `/init`

**Что:** Один репо. `/init` спрашивает профиль; `init.sh` + `/init` интервью генерируют scaffold под профиль.

| Плюсы | Минусы |
|-------|--------|
| Общее ядро — одно место правок | `/init` сложнее (logic per profile) |
| Просто добавить новый профиль (новая ветка `case`) | Надо хранить «исходники» каждого профиля внутри репо |
| Можно переключаться при init | Плохо подходит, если профили сильно расходятся (KB не нуждается в /dev) |

### Option C — Base + named overlays (расширение существующего механизма)

**Что:** Базовый «минимальный» `content/` + `apply-overlay.sh <profile>` накатывает структуру профиля. Расширение overlay-механизма: уметь добавлять файлы (новые `_index.md`, новые subdirs), удалять/выключать (skip ненужных subagents), а не только append-патчить.

| Плюсы | Минусы |
|-------|--------|
| Использует существующую инфраструктуру overlay | apply-overlay сейчас append-only, надо расширять |
| Аддитивный + декларативный (overlay = манифест) | Семантика «удалить директорию из шаблона» неудобна |
| Профиль = overlay; стек (SMP) = другой overlay; стэкабельно | Может конфликтовать (профиль и стэк патчат одно) |

### Option D — Base «minimal» + cherry-pick модули

**Что:** Базовый minimal-scaffold + библиотека модулей (`requirements/`, `runbooks/`, `glossary/`, `adr/`). `/init` спрашивает «какие модули включить» → копирует выбранные.

| Плюсы | Минусы |
|-------|--------|
| Гибкость: пользователь выбирает | Слишком много комбинаций; пользователь не всегда знает |
| Минимальный default | Зависимости между модулями (runbooks нужны DevOps-агента) |
| Хорошо для «custom» сценариев | Сложнее тестировать (N×M комбинаций) |

### Предварительная рекомендация

**Option C с расширениями** (overlay-based с поддержкой add/replace/delete операций) — потому что:

1. Расширяет существующий `apply-overlay.sh` (минимум новой инфраструктуры).
2. Декларативный (профиль = манифест в `docs/overlays/<profile>/`).
3. Стэкабельно с stack-overlay'ами (`naumen-smp`, `web`, ...).
4. Тестируется через расширение `test-apply-overlay.sh`.

**Альтернатива для рассмотрения:** гибрид B+C — `/init --profile <name>` под капотом вызывает `apply-overlay.sh <profile>` + интервью. Профиль ≈ overlay, но обёрнут в UX `/init`.

---

## 5. Открытые вопросы (для Researcher / BA)

1. **Полный список профилей.** Достаточно ли 4 (project/product/kb-product/kb-team) или нужно больше? «Другие кейсы» — какие именно?
2. **Глубина различий.** Профили — это **только разный scaffold**, или ещё **разный workflow** (другой порядок ролей, другие критерии приёмки)?
3. **Стэкабельность с overlay.** Как профиль (структура) сочетается со stack-overlay (`naumen-smp`)? Можно ли применять оба?
4. **Свитчинг профиля.** Можно ли менять профиль после init (мигрировать `kb-product` → `kb-product+team`), или это one-shot?
5. **Subagent-set.** Профиль определяет, какие subagents активны? Или все 6 всегда есть, но в KB-профиле они «спят»?
6. **Properties palette.** Для каждого профиля свой набор `properties` в `.doc-root.yaml`? Или есть общий минимум (Тип, Статус) + профильные расширения?
7. **Validator-поведение.** Должен ли validator-config зависеть от профиля? (Например, в `kb-product` нет «Фаза» — C5 её не должна требовать?)
8. **Naming.** Сейчас `00-project`/`30-requirements` — domain-specific. В KB-профиле логичнее `20-howto`/`30-faq`. Сколько свободы давать?
9. **`/init` UX.** Где спрашивать профиль — bash-скриптом (`init.sh --profile`) или slash-командой (`/init` интерактивно)? Рекомендуется второе — фразово ближе к JTBD.
10. **Existing repo migration.** Как мигрировать уже инициализированный `project_template`-based репозиторий в другой профиль? (Возможно, никак — profile = at-init только.)

---

## 6. Предлагаемая последовательность работы (Wave 2)

### Wave 2.0 — Подтверждение брифа (PM, синхронно с пользователем)
- Owner ревьюит этот документ.
- Выбирает приоритеты профилей (например: project + kb-team в Wave 2; остальные — Wave 3).
- Подтверждает направление (Option C / B+C / другое).

### Wave 2.1 — Research (`/research` → researcher-agent)
**Цель:** доменная экспертиза перед BA.
- Аудит аналогов: Cookiecutter, copier, dbt-init, Rails generators, GitHub template-repos.
- Изучить эталоны KB: бизнес-каталог `naumen-ecosystem/business-requirements/`, тех-каталог `naumen-smp-mcp/`, прочие проекты пользователя.
- Открытые вопросы из секции 5 — дать рекомендации (особенно 1, 2, 8).
- **Артефакт:** `content/10-domain/research/multi-template-landscape.md`.

### Wave 2.2 — BA (`/ba new-requirement multi-template`)
**Цель:** требования на основе research + JTBD.
- Per-profile JTBD: что хочет user, какие шаги, какие критерии успеха.
- Acceptance Criteria для `/init <profile>`.
- Профильные манифесты — что они декларируют (scaffold, properties, subagent set).
- Cross-функциональные требования: совместимость с overlay'ями, обратная совместимость с текущим `project_template`.
- **Артефакт:** `content/30-requirements/multi-template-support.md`.

### Wave 2.3 — SA (`/sa design multi-template` + ADR)
**Цель:** архитектурное решение (Option A/B/C/D).
- ADR: выбор подхода с обоснованием.
- Profile manifest format (YAML schema).
- Расширение `apply-overlay.sh`: операции add/replace/delete.
- Изменение `/init` workflow.
- **Артефакты:** `content/00-project/adr/00X-multi-template-architecture.md`, `content/40-architecture/multi-template-design.md`.

### Wave 2.4 — Plan + Dev (`writing-plans` → `subagent-driven-development`)
**Цель:** реализация согласно SA-design.
- TDD по фазам: profile manifest schema → loader → init integration → 2 эталонных профиля (project + kb-team) → migration.
- **Артефакт:** `docs/superpowers/plans/2026-XX-XX-multi-template.md`.

### Wave 2.5 — DevOps + verification
**Цель:** test coverage, документация.
- Расширить `test-template.sh`: matrix по профилям.
- Документация «как добавить новый профиль» в `README.md` / отдельный гайд.
- Lessons-learned + memory-saves.

---

## 7. Риски и рекомендации по scope

| Риск | Митигация |
|------|-----------|
| **Scope creep** — 4-5 профилей за одну волну = долго и хрупко | Wave 2 = только framework + 2 профиля (project как baseline + kb-team как proof-of-different-shape). Остальные — Wave 3. |
| **Преждевременная абстракция** — не зная реальной формы профилей, легко сделать слишком гибкий profile-system | Сначала «руками» сделать 2 профиля (хардкод), потом извлечь общий механизм. Не наоборот. |
| **Конфликт с overlay (naumen-smp)** | На SA-этапе явно проработать сценарий «профиль X + stack overlay Y». Возможно нужна композиция. |
| **Регрессия текущего `project_template`** | Текущий scaffold = профиль `project`. Migration = сделать существующее scaffold-content профильной шаблонкой. Сохранить полную обратную совместимость для уже инициализированных репо. |
| **Неоднозначность «другие кейсы»** | Не пытаться угадать. На Research-этапе спросить пользователя «какие ещё видел/нужны?». |

---

## 8. Acceptance для Wave 2 (черновик)

При завершении Wave 2 должно быть:

- [ ] ADR с выбором архитектурного подхода (Option A/B/C/D).
- [ ] Profile manifest schema задокументирована и валидируется.
- [ ] Минимум 2 рабочих профиля (`project`, `kb-team` — как контрастные).
- [ ] `/init` поддерживает выбор профиля в Phase 1 (slash-команда + bash-скрипт).
- [ ] Все профили проходят `validate-content.py` после init.
- [ ] `test-template.sh` тестирует каждый профиль (matrix).
- [ ] Документация: «как добавить новый профиль».
- [ ] Существующие репо, инициализированные на текущем шаблоне, не сломались (migration path или явное «не migrate-able, переиниt'ься»).
- [ ] Lessons-learned обновлены, ADR-ссылки везде.

---

## 9. Что просить у пользователя для запуска Wave 2

1. **Подтверждение приоритета профилей.** Какие 2 профиля идут в Wave 2 (рекомендуется `project` + `kb-team`)? Какие 2 — в Wave 3?
2. **Уточнение «других кейсов»** (вопрос 1 из секции 5). Назвать 1-3 примера, которые они уже видели.
3. **Подтверждение архитектурного направления** (Option A/B/C/D или гибрид).
4. **Стоит ли запускать Wave 2.1 Research** автономно, или owner хочет сам ответить на часть вопросов сразу (тогда Research пропускаем)?
5. **Срок** Wave 2 — нет жёсткого, или есть deadline?

---

**Next step:** owner ревьюит этот brief, отвечает на вопросы из §9, после чего PM запускает Wave 2.0 (sync) → Wave 2.1 (`/research`).

---

## 10. Scope extension — расширенный subagent-set + workflow-pipelines

**Контекст:** при ревью v1 owner указал, что шаблон проекта зависит ещё и от:
- расширенного списка subagents (есть роли вне текущей шестёрки PM/Researcher/BA/SA/Dev/DevOps);
- workflow-pipelines (методики работы — agile-планирование, критический путь, приёмка), которые не сводятся к ролям.

Эти артефакты — **профильно-зависимые**: разные профили активируют разные subagent-наборы и разные pipelines. Поэтому они входят в Wave 2 как часть профильного контракта.

### 10.1. Расширенный каталог subagents (предложение для каталога ролей)

| Роль | Назначение | Триггер активации | Где исполняется (пред.) | Когда нужен |
|------|-----------|-------------------|--------------------------|-------------|
| **PM** | Координация, декомпозиция, ревью | Всегда | main (Opus) | Все профили |
| **Researcher** | Сбор контекста, аналитика | Опц. перед BA | subagent (Sonnet) | Все профили (опц.) |
| **BA** | Требования, JTBD, AC | Перед SA | subagent (Sonnet) | project, product, kb-product |
| **SA** | Архитектура, ADR, API | Перед Dev | subagent (Sonnet) | project, product |
| **Dev** | TDD-реализация по SA | После SA | subagent (Sonnet) | project, product |
| **DevOps** | Deploy, runbook, monitor | После Dev (опц.) | subagent (Sonnet) | project, product, kb-team |
| **🆕 Tester (QA-runner)** | Прогон тестов, регрессии, проверка прохождения после Dev | После Dev | subagent (Sonnet) | project, product |
| **🆕 AT (Automation Test author)** | Написание автотестов **до** старта разработки (TDD-партнёр для Dev: пишет AC-driven test suite) | После BA/SA, перед Dev | subagent (Sonnet) | project, product (если автотесты есть) |
| **🆕 DevSecOps** | Безопасная разработка: SAST/DAST guardrails, secrets-policy, supply-chain | Опц., по запросу user/PM | subagent (Sonnet) | project, product (опц.) |
| **🆕 Secure Compliance** | Исследование и проверка соответствия требованиям ИБ (152-ФЗ, ISO27001, internal compliance) | Опц., по запросу user/PM | subagent (Sonnet) | project, product, kb-product (опц.) |
| **🆕 Technical Writer** | Документирование на «понятный язык» (для внешних читателей, customer-facing docs, gramax-публикации) | После SA/Dev (если нужна внешняя дока) | subagent (Sonnet) | kb-product, project (опц.), product |

**Принципы:**

- **Core vs opt-in:** в манифесте профиля каждый subagent помечен как `enabled: true` (всегда вызывается в pipeline) / `enabled: optional` (вызывается только если явный триггер от user/PM). DevSecOps и Secure Compliance в дефолте — `optional`.
- **Профиль декларирует subagent-set,** но user/PM может ad-hoc включить дополнительный (например, для project включить Secure Compliance, если проект под compliance-надзором).
- **Контракт вызова субагента (из AGENTS.md)** одинаковый для всех ролей: цель + входные файлы + ожидаемый артефакт + критерии приёмки.

### 10.2. Каталог workflow-pipelines (методик работы)

В отличие от subagents (роли), pipelines — это **способ организации работы**: сценарии последовательностей вызовов и связанных артефактов.

| Pipeline | Назначение | Артефакты | Где живёт | Профильность |
|----------|-----------|-----------|-----------|--------------|
| **🆕 Планирование реализации проекта** | Декомпозиция эпика на задачи + оценка + приоритеты + roadmap | `content/00-project/roadmap.md`, `content/00-project/plan-<epic>.md` | PM / `/pm decompose` | project, product |
| **🆕 Scrum / Agile-планирование** | Спринт-планирование, daily, retro; backlog grooming | `content/00-project/sprints/<NNN>-sprint.md`, retros | PM (новый раздел), opt-in | project (опц.), product (опц.) |
| **🆕 Подсчёт критического пути** | Анализ зависимостей задач, выявление blocking chain, оценка длительности | `content/00-project/critical-path.md` (опц. mermaid Gantt) | PM / `/pm critical-path` | project (опц., для крупных) |
| **🆕 Приёмка реализации задачи аналитиком** | BA проверяет, что реализованная Dev-фича соответствует AC из требования; формальный gate перед merge | `content/30-requirements/<req>.md` секция «Acceptance log», или отдельный `content/30-requirements/acceptance/<req>.md` | `/ba accept <req>` (новый под-режим BA) | project, product |

**Принципы:**

- Pipelines — **орт-к subagents**: один pipeline может вовлекать несколько subagents (например, scrum-планирование = PM + BA + SA + Dev в координированной последовательности).
- Pipelines описаны в **AGENTS.md / CLAUDE.md** как «когда какой запускать», и в slash-командах (`/pm critical-path`, `/ba accept`).
- Профильная активация — какие pipelines в профиле дефолтные / опциональные / отсутствуют.
- Pipelines могут быть **stack-ориентированными** (scrum/kanban — выбор стиля), и попадают в overlay-механизм аналогично stack-overlay'ам.

### 10.3. Влияние на §3 (карта профилей) — обновлённая гипотеза

| Профиль | Subagents (core / optional) | Pipelines (default / opt-in) |
|---------|------------------------------|------------------------------|
| `project` | core: PM, BA, SA, Dev, DevOps, Tester, AT, Tech Writer; opt: Researcher, DevSecOps, Secure Compliance | default: project-planning, BA-acceptance; opt-in: scrum-agile, critical-path |
| `product` | core: PM, BA, SA, Dev, DevOps, Tester, Tech Writer; opt: Researcher, AT, DevSecOps, Secure Compliance | default: project-planning, BA-acceptance; opt-in: scrum-agile |
| `kb-product` | core: PM, Tech Writer; opt: Researcher, BA (как редактор), Secure Compliance | default: review-cycle (PM-review); opt-in: — |
| `kb-team` | core: PM, DevOps, Tech Writer; opt: Researcher | default: runbook-cycle, onboarding-flow; opt-in: — |
| `custom` / `minimal` | core: PM; opt: всё остальное | default: — (всё opt-in); opt-in: — |

(Это **расширение гипотезы из §3**, а не замена. Финал на BA-этапе.)

### 10.4. Новые открытые вопросы (расширяют §5)

11. **Кто авторитет subagent-каталога?** Список ролей живёт в одном месте (например, `AGENTS.md` базового шаблона) или в манифесте профиля? Куда добавлять 6-ю/7-ю роль, если кто-то её введёт?
12. **Subagent-prompt'ы:** общая база с профильными overrides, или отдельный prompt-файл на каждое сочетание (профиль × роль)? Сейчас prompts в `agents/<role>-agent.md` — расширять/дублировать?
13. **Activation-триггер.** «Optional» subagent активируется командой пользователя (`/secsompliance ...`) или PM решает в декомпозиции? Если PM — нужны критерии (например, project под compliance-флагом → Secure Compliance активен).
14. **Pipeline ↔ Subagent.** Pipeline = последовательность slash-команд, или у pipeline свой «оркестратор-агент» (типа `/pm scrum-plan` который сам вызывает других)? Рекомендуется второе — pipeline = специальный режим PM-агента.
15. **AT vs Tester.** Как разделить ответственность? AT пишет тесты по AC ДО Dev (red-test for TDD); Tester прогоняет полный suite и регрессии ПОСЛЕ Dev. Должны быть разными ролями или это один subagent в двух режимах?
16. **Tech Writer и Gramax.** Tech Writer = вторичный редактор после Dev/SA, или primary author для kb-product/kb-team профилей? В каких профилях он core, в каких — optional?
17. **DevSecOps vs Secure Compliance.** DevSecOps = эмбеддед в pipeline (постоянно гонят SAST), а Secure Compliance = разовая проверка / аудит на конкретные требования ИБ. Это две разные роли (как сейчас) или одна с двумя режимами?
18. **Storage:** где жить артефактам новых ролей? Tester → `content/60-implementation/test-reports/<...>.md`? AT → `content/40-architecture/test-design.md`? Tech Writer → отдельная подпапка или интегрирован в существующие? Pipelines → `content/00-project/<pipeline>/...`?

### 10.5. Расширение последовательности §6 — Wave 2 теперь покрывает и subagents+pipelines

- **Wave 2.1 Research** — добавляется аудит того, как другие AI-команды организуют расширенные subagent-наборы (`agentscope`, `crewAI`, `Microsoft AutoGen`, `LangGraph multi-agent`). Какие роли каноничны, какие redundant?
- **Wave 2.2 BA** — для **каждого** из 11 subagents и **каждого** из 4+ pipelines: JTBD, входы, выходы, критерии приёмки артефакта. Это существенно больше работы, чем казалось в v1.
- **Wave 2.3 SA** — нужна **сетка** «профиль × роль × pipeline» в декларативном формате (manifest schema). Возможно: ADR «архитектура манифеста профиля» включает разделы:
  - `subagents:` map (role → enabled/optional)
  - `pipelines:` map (pipeline → enabled/optional)
  - `content_scaffold:` (что copy-pastа в content/)
  - `properties:` (для .doc-root.yaml)
- **Wave 2.4 Plan + Dev** — масштаб расширяется. Минимальный Wave 2: 2 профиля × 11 subagents × 4 pipelines = 88 матричных ячеек, из которых половина «not applicable». Реалистично за один wave: framework + базовый набор (5-6 subagents + 2 pipelines), остальное — wave 3-4.
- **Wave 2.5 DevOps** — `test-template.sh` теперь должен матрицу и subagent-prompts (не сломали ли при override).

### 10.6. Расширение §8 acceptance

Добавляется к acceptance Wave 2:

- [ ] Манифест профиля декларирует не только scaffold + properties, но и subagent-set + pipeline-set.
- [ ] Минимум 5 новых subagent-prompt'ов в `agents/`: `tester-agent.md`, `at-agent.md`, `tech-writer-agent.md`, плюс `devsecops-agent.md` и `secure-compliance-agent.md` (последние два — в режиме «opt-in stub»).
- [ ] Минимум 2 новых pipeline-режимов в `commands/pm.md` или новых slash-commands: `/pm plan-implementation`, `/ba accept`. Остальные (scrum, critical-path) — в backlog Wave 3.
- [ ] AGENTS.md обновлён: каталог ролей расширен, контракт вызова единый, матрица «роль × профиль» отражает реальность.
- [ ] Документация: «как добавить новую роль / pipeline» в гайд по созданию профиля.

### 10.7. Дополнительные риски (расширяют §7)

- **Раздувание каталога** — 11 ролей сложнее в поддержке, чем 6. Митигация: **в Wave 2 поставить 5 новых ролей в виде prompt-stubs** (минимальный prompt по контракту), полировать в боевом использовании.
- **Конфликт оркестрации** — больше ролей = больше комбинаций вызова. Митигация: PM по-прежнему orchestrator; novelty в pipelines = explicit slash-команды (`/pm scrum-plan`), а не неявные хуки.
- **Drift с реальной практикой пользователя** — если owner де-факто не использует AT (а только Tester), вторая роль будет мёртвой. Митигация: на Wave 2.0 (sync) явно подтвердить, какие из 5 новых ролей **реально нужны прямо сейчас**, какие в задел.

### 10.8. Дополнительные вопросы для §9 (owner-input для Wave 2.0)

6. **Из 5 новых subagents, какие точно нужны в Wave 2** (минимум 2-3), какие — в Wave 3? Рекомендация: Tester + Tech Writer (универсальные); остальные — wave 3 как stubs.
7. **Из 4 новых pipelines, какие в Wave 2**? Рекомендация: project-planning + BA-acceptance (базовые); scrum/critical-path — в задел.
8. **Активация opt-in subagents** — как ты ожидаешь их вызывать? Пример: «PM в декомпозиции включает DevSecOps» vs «User говорит /devsecops audit». Или оба варианта?
9. **AT-prompts** — у тебя есть наработки/предпочтения по тому, как AT должен описывать тесты (BDD-сценарии? gherkin? plain pytest?), или это open для решения SA?
10. **Compliance scope** — Secure Compliance нужен под конкретные требования (152-ФЗ, ISO27001, корпоративные) или общий? От ответа зависит, нужна ли база доменных правил или general-purpose research-агент.
