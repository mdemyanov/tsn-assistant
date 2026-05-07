# Research: User shapes для 4 stub профилей (W4c-A)

**Дата:** 2026-05-07
**Researcher:** subagent (Sonnet)
**Задача:** RES-W4c-A-01
**Цель:** Input для BA (BRQ) и SA (spec) фаз промоции 4 stub профилей в stable.

## Метод

Источники: (1) внутренние эталоны — `docs/overlays/profiles/{kb-team,kb-product,project}/` как парагон pattern; текущие stub manifest.yaml для понимания declared intent. (2) Внешние бенчмарки — GitHub spec-kit, GitLab Handbook, Atlassian Team Playbook, Coursera/UCalgary course structure, Obsidian vault templates, SAFe/LeSS structure. Фильтрация: брал только sources с явной каталожной структурой, не просто описания. Уровень достоверности: [established] — паттерн воспроизводится в 3+ независимых примерах; [emerging] — 1-2 примера; [contested] — расхождение между источниками.

---

## Профиль 1: `product`

### User shapes (примеры реальных команд)

- **GitHub spec-kit** ([github/spec-kit](https://github.com/github/spec-kit)) — spec-driven workflow: `.specify/specs/<FEATURE-ID>/` с `spec.md`, `plan.md`, `research.md`, `data-model.md`, `tasks.md`; плюс `constitution.md` как принципы проекта. Структура feature-centric, не раздел-centric.
- **Open source roadmap repos** (github/roadmap) — `CHANGELOG.md` в корне + папка `releases/` с per-version notes; roadmap через GitHub Projects, не как файлы.
- **Крупные продукты (Kubernetes, React)** — `docs/` с `concepts/`, `reference/`, `guides/` и отдельный `CHANGELOG` / `releases/`; ADR в `docs/decisions/` или `docs/adr/`.
- **ADR canonical** ([adr.github.io](https://adr.github.io/), [madr](https://github.com/adr/madr)) — `docs/decisions/NNNN-title.md`; шаблон: title + status + context + decision + consequences. [established]
- **Embedded Artistry pattern** — ADR в корне repo как `docs/architecture-decisions/`; release notes как `CHANGELOG.md` + `docs/releases/`. [established]

### Бенчмарки

- [github/spec-kit](https://github.com/github/spec-kit) — feature spec + plan + tasks workflow для AI-assisted dev [primary]
- [adr.github.io](https://adr.github.io/) — canonical ADR format и нумерация [primary]
- [adr/madr](https://github.com/adr/madr) — Markdown Architectural Decision Records, minimal/full templates [primary]
- [OpenProject Roadmap](https://www.openproject.org/roadmap/) — transparent roadmap pattern (public, version-tagged) [secondary]
- [LaunchNotes: Release Notes vs Changelog](https://www.launchnotes.com/blog/release-notes-vs-changelog-understanding-the-key-differences-and-when-to-use-each) — разница: changelog = technical diff for devs; release notes = narrative for users [secondary]

### Минимальные требования к scaffold

- `10-vision/` — product vision, goals, scope, non-goals
- `20-discovery/` — research, competitive analysis, user personas (опционально)
- `30-specs/` — feature specs, user stories (может быть flat или per-feature subfolders)
- `40-architecture/` — ADR, архитектурные решения, data model
- `50-releases/` — release notes / changelog per version

### Опциональные блоки

- `60-roadmap/` — если roadmap хранится как docs, а не в tracker
- `70-metrics/` — success metrics, OKR
- `00-project/` (из `project` профиля) — если нужен delivery tracking + compliance

### Кандидаты на agent-override

- `tech-writer` — release notes специфичны: audience = пользователь/разработчик-интегратор, не команда; нужен override на стиль user-facing
- `sa` — ADR workflow в `product` может отличаться от delivery: product ADR фокусируется на product decisions (buy vs build, feature scope), а не только на архитектуре

### Properties кандидаты

- **Тип контента**: Vision, Discovery, Spec, ADR, Release Notes, Roadmap
- **Версия**: semver-строка (v1.2.3) — как в kb-product
- **Статус**: Draft / Review / Approved / Shipped / Deprecated
- **Аудитория**: Internal / External (для release notes дифференциация важна) [emerging]

---

## Профиль 2: `methodology`

### User shapes (примеры реальных команд)

- **GitLab Handbook** ([handbook.gitlab.com](https://handbook.gitlab.com/)) — 8+ top-level разделов (Values, About, Engineering, Customer Experience и т.д.); каждый раздел = принципы + практики + playbooks + примеры. Handbook = living document, maintained как код в GitLab. [established]
- **Atlassian Team Playbook** ([atlassian.com/team-playbook](https://www.atlassian.com/team-playbook)) — Plays как атомарные практики: название + цель + роли + шаги + адаптации + примеры. Организованы по проблемным областям (DevOps, project management, etc.). [established]
- **SAFe 6.0** ([scaledagileframework.com](https://scaledagileframework.com/)) — иерархия: Principles → Mindset → Practices → Roles → Artifacts → Events; 4-уровневая структура (Portfolio/Large Solution/Program/Team). [established]
- **LeSS** — flat structure: Principles → Rules → Guides → Experiments; минимализм как ключевой принцип фреймворка. [established]
- **ThoughtWorks Tech Radar** — радиально: Techniques / Tools / Platforms / Languages; 4 кольца (Adopt/Trial/Assess/Hold). Не иерархия, а matrix.

### Бенчмарки

- [GitLab Handbook](https://handbook.gitlab.com/) — образец "handbook-as-code", структура по доменам [primary]
- [Atlassian Team Playbook](https://www.atlassian.com/team-playbook) — атомарные Plays с четкой структурой полей [primary]
- [SAFe 6.0](https://scaledagileframework.com/) — иерархия артефактов крупного фреймворка [primary]
- [Atlassian playbook examples](https://www.atlassian.com/team-playbook/examples) — конкретные playbook-примеры по доменам [secondary]

### Минимальные требования к scaffold

- `10-principles/` — ценности, принципы, mantra
- `20-practices/` — описание практик (каждая практика = атомарный файл)
- `30-playbooks/` — сборники практик по контексту/задаче (ситуация → набор Plays)
- `40-templates/` — шаблоны артефактов для пользователей методологии
- `50-cases/` — примеры применения, case studies

### Опциональные блоки

- `00-overview/` — введение, онбординг в методологию, scope
- `60-roles/` — если методология включает ролевую модель
- `70-glossary/` — термины фреймворка (может быть единственным файлом `glossary.md`)

### Кандидаты на agent-override

- `tech-writer` — методологический текст имеет специфический стиль: нормативный ("должен") vs описательный ("команды обычно"); нужен override на prescriptive writing
- `researcher` — при создании методологии часто нужен prior-art сбор; override на domain-specific search

### Properties кандидаты

- **Тип контента**: Принцип, Практика, Playbook, Шаблон, Case Study
- **Уровень**: Strategic / Tactical / Operational [emerging]
- **Область применения**: свободный текст или enum (Engineering, Design, Operations, All) [emerging]
- **Статус**: Draft / Review / Approved / Archived — как в kb-team

---

## Профиль 3: `course`

### User shapes (примеры реальных команд)

- **Coursera structure** — Course > Module (weekly) > Lesson/Activity; в каждом Module: видео + reading + quiz + peer review + assignment; итоговый assessment. [established]
- **MDN Web Docs Learning Area** — Course > Module > Article; каждая статья: objectives + prerequisites + content + test-yourself. Плоские markdown-файлы, организованные в папки по модулям. [established]
- **Vanderbilt CDR pattern** — Module содержит: overview + learning outcomes + intake (reading/video) + processing activities + assessment. Рекурсивная структура (module > sub-module). [established]
- **FastAPI tutorial** — линейная прогрессия: intro → basics → intermediate → advanced; каждый шаг standalone, но с explicit prerequisites. Никаких assessment — pure learning path. [emerging]
- **Software bootcamp** — Cohort > Week > Day > Exercise; каждый day: warmup + concept + exercise + review. [emerging]

### Бенчмарки

- [Coursera course structure](https://www.coursera.support/s/topic/0TO1U000000PmS0WAK/modules-lessons) — официальный Coursera taxonomy [primary]
- [Vanderbilt CDR: online course module structure](https://www.vanderbilt.edu/cdr/module1/online-course-module-structure/) — academic best practices для module design [primary]
- [University of Calgary: example course structures](https://taylorinstitute.ucalgary.ca/resources/module/developing-online-courses/example-course-structures) — 6 вариантов организации (по теме, по неделям, с sub-modules) [primary]

### Минимальные требования к scaffold

- `00-overview/` — введение в курс, цели, prerequisites, целевая аудитория
- `10-module-01/` ... `N0-module-N/` — нумерованные модули (каждый = подпапка)
  - внутри модуля: `_index.md` (обзор модуля, learning outcomes) + статьи уроков
- `90-assessments/` — итоговые задания, тесты, проекты
- `99-resources/` — дополнительные материалы, ссылки, глоссарий

### Опциональные блоки

- `05-prerequisites/` — если prerequisite knowledge объемная (например, setup guide)
- Внутри модуля: `exercises/` подпапка — отделение упражнений от теории [emerging]
- `certificates/` или `milestones/` — для трекинга прогресса [emerging]

### Кандидаты на agent-override

- `tech-writer` — обучающий текст требует особого стиля: instructional tone, learning objective per section, "you will learn", explicit outcomes
- `ba` — при разработке курса BA роль ближе к instructional designer: нужна переориентация с бизнес-требований на learning objectives + assessment design

### Properties кандидаты

- **Тип контента**: Overview, Lesson, Exercise, Assessment, Resource
- **Уровень сложности**: Beginner / Intermediate / Advanced [established]
- **Длительность**: строка (например, "15 мин", "2 часа") [established]
- **Статус**: Draft / Review / Approved / Published
- **Prerequisites**: ссылка или текст [emerging]

---

## Профиль 4: `custom`

### User shapes (примеры реальных команд)

- **Obsidian vault (voidashi template)** ([github.com/voidashi/obsidian-vault-template](https://github.com/voidashi/obsidian-vault-template)) — folders: `inbox/`, `notes/`, `projects/`, `archive/`; минимально, без opinion. [established]
- **Karpathy LLM Wiki pattern** ([gist](https://gist.github.com/kennyg/6c45cace2e1c4e424a28fcd51dd6c25b)) — каждая запись: title + summary + tags + content; `wiki/` + `_templates/` + `inbox/`. Ключевой принцип: consistent note structure > folder structure. [emerging]
- **Magic-wei obsidian_wiki_template** ([github](https://github.com/Magic-wei/obsidian_wiki_template)) — `wiki/`, `projects/`, `research/`, `reference/`, `meetings/`, `inbox/`; шаблоны для разных типов заметок. [emerging]
- **TiddlyWiki / Logseq** — flat или граф-структура без иерархии; организация через теги и ссылки, а не папки. Принципиально иной подход, несовместимый с Gramax directory-first navigation. [contested]

### Бенчмарки

- [voidashi/obsidian-vault-template](https://github.com/voidashi/obsidian-vault-template) — минималистичный vault: inbox + notes + projects + archive [primary]
- [Karpathy LLM Wiki setup](https://gist.github.com/kennyg/6c45cace2e1c4e424a28fcd51dd6c25b) — AI-queryable personal KB [secondary]
- [Magic-wei obsidian_wiki_template](https://github.com/Magic-wei/obsidian_wiki_template) — wiki-ориентированный vault с templates [secondary]
- [Obsidian Starter Kit by S.Dubois](https://www.dsebastien.net/obsidian-starter-kit-system-llm-wiki-system/) — систематизация personal KB [secondary]

### Минимальные требования к scaffold

`custom` — это catch-all с намеренным минимализмом. Baseline должен содержать ровно столько, чтобы Gramax видел каталог и чтобы пользователь имел "blank slate" с примерами:

- `_index.md` в корне (обязательно для Gramax)
- `templates/` — папка с примерами разных типов статей (чтобы пользователь не стартовал с нуля)
  - `templates/article-example.md` — шаблон обычной статьи
  - `templates/decision-example.md` — шаблон решения/ADR-лайт
  - `templates/reference-example.md` — шаблон справочной статьи
- `inbox/` — место для "необработанных" материалов [emerging, но логично]

### Опциональные блоки

Всё остальное — опционально и создаётся пользователем вручную. Профиль explicit anti-opinion.

### Кандидаты на agent-override

- Никаких core overrides — custom не должен навязывать workflow.
- `researcher` как optional — единственная роль, которая уместна без контекста (исследование всегда полезно).

### Properties кандидаты

- Минимальный doc-root: только **Тип контента** (free string или минимальный enum) + **Статус**
- Явно НЕ добавлять специфичные для других профилей поля (версия, уровень сложности и т.д.)
- SA/BA решают — нужен ли properties block вообще, или полностью опустить

---

## Cross-cutting findings

1. **`_index.md` в каждой подпапке — universal rule** [established]. Все 3 stable профиля используют это. Все 4 stub профиля при промоции должны следовать тому же правилу.

2. **Нумерованные папки (10-, 20-, 30-) используются в kb-team и project**, но не в kb-product (flat names: `getting-started/`, `guides/`). Паттерн выбора: нумерация уместна когда порядок прохождения важен (onboarding, курс); flat names — когда пользователь навигирует произвольно (docs, методология). [established]

3. **Тип контента + Статус — минимальный общий знаменатель** для doc-root.yaml во всех профилях. Остальные fields (Версия, Аудитория, Уровень сложности, Область применения) — профиль-специфичные. [established]

4. **tech-writer override нужен во всех 4 профилях**, но с разным фокусом: product — user-facing release notes; methodology — prescriptive style; course — instructional tone; custom — нет override. Это согласуется с паттерном kb-product (tech-writer override уже реализован как образец).

5. **release notes / changelog — специфичная проблема product профиля**: разница между changelog (technical, для разработчиков) и release notes (narrative, для пользователей) требует явного разделения в scaffold или хотя бы в doc-root properties (Аудитория).

6. **custom профиль — anti-pattern для нумерации**: минимальный scaffold без числовых префиксов; пользователь строит структуру сам.

---

## Open questions для BA/SA

1. **product: один каталог или два?** Product profile на практике часто разделяется: внутренняя документация (specs, ADR, discovery) и внешняя (release notes, user docs). Граница между `product` и `kb-product` размыта — BA должен определить, предполагает ли `product` только internal docs, или он охватывает и external, дублируя kb-product.

2. **methodology: глубина иерархии.** GitLab Handbook плоский (раздел > статья), SAFe — многоуровневый (Principle > Practice > Artifact). SA должен решить: поддерживать ли sub-module уровень в scaffold или ограничиться двумя уровнями (раздел > статья).

3. **course: нумерация модулей vs slug-имена.** Нумерованные папки (`10-module-01/`) поддерживают произвольный порядок без переименования; slug-имена (`introduction/`, `advanced-topics/`) — человекочитаемы, но требуют числового prefix для сортировки. BA/SA должны зафиксировать convention для scaffold, так как оба подхода встречаются в бенчмарках.

---

## Источники

- [primary] [github/spec-kit](https://github.com/github/spec-kit) — spec-driven development workflow, directory structure
- [primary] [adr.github.io](https://adr.github.io/) — canonical ADR format
- [primary] [adr/madr](https://github.com/adr/madr) — Markdown ADR templates
- [primary] [GitLab Handbook](https://handbook.gitlab.com/) — handbook-as-code структура
- [primary] [Atlassian Team Playbook](https://www.atlassian.com/team-playbook) — атомарные Plays структура
- [primary] [SAFe 6.0](https://scaledagileframework.com/) — методологический фреймворк, иерархия артефактов
- [primary] [Coursera modules & lessons](https://www.coursera.support/s/topic/0TO1U000000PmS0WAK/modules-lessons) — course taxonomy
- [primary] [Vanderbilt CDR: module structure](https://www.vanderbilt.edu/cdr/module1/online-course-module-structure/) — academic module design
- [primary] [voidashi/obsidian-vault-template](https://github.com/voidashi/obsidian-vault-template) — минималистичный vault scaffold
- [secondary] [UCalgary: example course structures](https://taylorinstitute.ucalgary.ca/resources/module/developing-online-courses/example-course-structures) — 6 вариантов организации курса
- [secondary] [LaunchNotes: Release Notes vs Changelog](https://www.launchnotes.com/blog/release-notes-vs-changelog-understanding-the-key-differences-and-when-to-use-each) — разграничение типов release docs
- [secondary] [Magic-wei/obsidian_wiki_template](https://github.com/Magic-wei/obsidian_wiki_template) — wiki-ориентированный vault
- [secondary] [Karpathy LLM Wiki pattern](https://gist.github.com/kennyg/6c45cace2e1c4e424a28fcd51dd6c25b) — AI-queryable personal KB
