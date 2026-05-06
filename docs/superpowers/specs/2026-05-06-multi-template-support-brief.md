# Brief: Multi-Template Support — Preliminary Analysis & Task Setup

**Дата:** 2026-05-06
**Автор:** PM (main, Opus)
**Статус:** Brief — input для волны 2 (Researcher → BA → SA → Dev → DevOps).

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
