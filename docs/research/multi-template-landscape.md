---
properties:
  - name: Тип контента
    value: [Исследование]
  - name: Статус
    value: [Draft]
---

# Multi-template support — research landscape

**Дата:** 2026-05-06
**Исследователь:** researcher-agent
**Запрос PM/BA:** Собрать паттерны из трёх областей — profile-templating инструменты, multi-agent frameworks, KB-эталоны — как input для дизайна Wave 2 (multi-template support + расширенный subagent-каталог).
**Глубина:** standard (≤2ч)

## Резюме (TL;DR)

1. **Copier** — наиболее близкий аналог по механике: `copier.yml` с `when`-условиями на каждый вопрос + `_migrations` для versioned updates. Его паттерн «декларативный манифест с условными вопросами + lifecycle hooks» напрямую применим к нашему `/init --profile`.
2. **Cookiecutter** проще, но не поддерживает update-цикл и merge: подходит для one-shot init, не подходит для «поменяли шаблон — накатить diff на существующий репо».
3. **dbt-init** показывает паттерн `profile_template.yml` — отдельный файл подсказок/дефолтов под конкретный профиль (warehouse). Этот паттерн: «профиль = отдельный манифест с фиксированными константами + вопросами» — прямо применим к нашим `profiles/<name>/manifest.yaml`.
4. **CrewAI** — наиболее структурированная декларация агентного каталога: `agents.yaml` (роль/цель/backstory/model/tools) + `tasks.yaml` + `process: sequential|hierarchical`. Паттерн отделения конфигурации от кода — хороший образец для нашего AGENTS.md + manifest-фильтра.
5. **LangGraph supervisor** — паттерн orchestrator + handoff-инструменты между специализированными агентами. Применим к нашей pipeline-механике: pipeline = специальный режим PM-агента, который явно передаёт задачи другим субагентам через handoff.
6. **KB-эталон business-requirements** показывает зрелую схему: цепочка Стейкхолдер→JTBD→Цель→BRQ→Epic с трассируемостью, богатый `.doc-root.yaml` (10+ properties), `<view>`-дашборды на `_index.md` для фильтрации по статусу/продукту/домену.
7. **Claude Code subagent-формат** (наш базис): Markdown + YAML frontmatter (`name`, `description`, `tools`, `model`, `skills`, `isolation`, `memory`). Registry = `.claude/agents/` или plugin's `agents/`. Приоритет: managed > CLI > project > user > plugin — эта иерархия применима к нашему profile-override механизму.

---

## Блок 1 — Profile-templating инструменты

### Cookiecutter

**Источник:** [primary] [Cookiecutter docs](https://cookiecutter.readthedocs.io/) + [GitHub](https://github.com/cookiecutter/cookiecutter) — оригинальная документация.

**Как работает.** Шаблон = git-репозиторий или директория. Центральный файл — `cookiecutter.json` (JSON, не YAML): словарь переменных с дефолтами. Jinja2-templating в именах файлов и содержимом. При запуске `cookiecutter <url>` инструмент задаёт вопросы по ключам, подставляет ответы.

**Ключевые паттерны:**

1. **Переменные с дефолтами и choice-листами.** В `cookiecutter.json`:
   ```json
   {"project_type": ["project", "kb-team", "product"], "use_devops": true}
   ```
   Первый элемент списка — дефолт; пользователь выбирает. Это прямой аналог нашего «выбрать профиль при `/init`».

2. **Условные файлы через имена директорий с Jinja.** Директории и файлы вида `{% if use_devops %}70-operations{% endif %}/` рендерятся только при выполнении условия. Механика применима к нашему `profiles/<name>/manifest.yaml`, который декларирует, какие поддиректории создавать.

3. **Hooks (pre/post-generate).** Скрипты `hooks/pre_gen_project.py` и `hooks/post_gen_project.py` запускаются до/после генерации. `post_gen_project.py` может удалять ненужные файлы на основе переменных. Аналог нашего `apply-overlay.sh` с операцией `delete`.

4. **Нет встроенного механизма update/migration.** Cookiecutter — one-shot. Если шаблон изменился, пересоздать репо нельзя «по diff». Для накатки изменений на существующий проект нужен сторонний инструмент (например, Copier).

**Что НЕ умеет:** override-merge (profile-on-base), update-цикл, зависимые вопросы (когда ответ B зависит от ответа A — нужен скрипт), нативная декларация «профилей» как отдельного уровня.

---

### Copier

**Источник:** [primary] [Copier docs](https://copier.readthedocs.io/en/stable/configuring/) + [GitHub copier-org/copier](https://github.com/copier-org/copier) — оригинальная документация.

**Как работает.** `copier.yml` в корне шаблона — YAML с двумя типами ключей: `_settings` (префикс `_`: minimum version, subdirectory, tasks, migrations) и `answers` (вопросы пользователю). Jinja2 во всём.

**Ключевые паттерны:**

1. **`when`-условия на вопросы.** Вопрос отображается только если `when: "{{ use_ci }}"` истинно. Зависимые вопросы — нативно. Пример для профилей:
   ```yaml
   profile:
     type: str
     choices: [project, kb-team, product, custom]
     default: project
   use_devops:
     when: "{{ profile in ['project', 'product'] }}"
     type: bool
     default: true
   ```
   Это прямой аналог нашего интерактивного `/init`, где вопросы об агентах показываются только если выбран `project`-профиль.

2. **Conditional files через Jinja в именах.** Файл `{% if profile == 'project' %}30-requirements{% endif %}/_index.md.jinja` создаётся только для `project`. `.jinja`-суффикс — обязательный маркер рендеримого файла.

3. **Update-цикл (главное преимущество перед Cookiecutter).** `copier update` сравнивает три состояния: «шаблон до», «шаблон после», «проект». Применяет three-way merge. Конфликты — `*.rej`-файлы или inline-маркеры. Это аналог нашей задачи «накатить wave 3 поверх wave 2».

4. **`_migrations`.** Блок задач с version-gating:
   ```yaml
   _migrations:
     - version: "2.0.0"
       before:
         - rm -f old-file.md
       after:
         - cp new-template.md content/
   ```
   `before`/`after` — lifecycle phases. Применимо к нашей эволюции профиля между волнами.

5. **`!include` для разбивки конфига.** Большой `copier.yml` делится на файлы через `!include questions/devops.yml`. Применимо к нашему разбиению manifest'а профиля на модули.

6. **`ContextHook`-extension.** Через Jinja2-расширение можно модифицировать context в фазах `prompt`/`render`/`tasks`. Для нас это аналог логики «если выбран compliance-профиль, добавить флаг в manifest».

**Главный gap для нашего случая:** Copier управляет файловым содержимым, но не декларирует «роли агентов» — это другой уровень абстракции.

---

### dbt-init

**Источник:** [primary] [dbt-labs/dbt-init GitHub](https://github.com/dbt-labs/dbt-init) + [dbt docs: dbt init](https://docs.getdbt.com/reference/commands/init) + [profiles.yml](https://docs.getdbt.com/docs/core/connect-data-platform/profiles.yml) — оригинальная документация.

**Как работает.** `dbt init` — CLI-команда, которая запрашивает тип warehouse (bigquery, snowflake, postgres…) и генерирует `profiles.yml`. Каждый адаптер декларирует `profile_template.yml` — YAML с фиксированными значениями и подсказками для своего типа.

**Ключевые паттерны:**

1. **`profile_template.yml` как профиль-специфичный манифест.** Файл лежит рядом с проектом и содержит:
   ```yaml
   fixed:
     type: bigquery
     method: oauth
   prompts:
     project:
       hint: "GCP project ID"
       type: string
     dataset:
       hint: "Default dataset"
       default: dbt_dev
   ```
   `fixed` — константы профиля (не спрашиваются). `prompts` — что спрашивается с подсказками. Это точный аналог нашего `profiles/<name>/manifest.yaml`: фиксированные scaffold/subagent-set + вопросы для customization.

2. **Профиль = адаптер (warehouse type), не тип проекта.** В dbt «профиль» — это источник данных. Но механика декларации (fixed + prompts) применима к нашему случаю: `project`-профиль фиксирует scaffold и subagent-set, а остальное спрашивает у пользователя.

3. **`dbt_project.yml` — реестр конфигурации проекта.** Декларирует `name`, `version`, `profile`, `models`, `seeds`, `sources`. Применимо к нашему AGENTS.md как реестру ролей + manifest как фильтру.

**Применимо к Wave 2:** паттерн `fixed + prompts` в manifest'е профиля — прямое решение для `profiles/<name>/manifest.yaml`.

---

### Rails generators

**Источник:** [primary] [Rails Guides: Creating and Customizing Generators](https://guides.rubyonrails.org/generators.html) — оригинальная документация.

**Как работает.** `rails generate scaffold Post title:string` — вызов generator'а. Генераторы живут в `lib/generators/` или `app/generators/`. Наследование: можно переопределить `Rails::Generators::ScaffoldGenerator` через класс в `lib/generators/rails/scaffold/`.

**Ключевые паттерны:**

1. **Шаблоны в `lib/templates/<generator_name>/`.** Чтобы кастомизировать шаблон, кладёшь файл в `lib/templates/rails/scaffold_controller/controller.rb.tt` — Rails найдёт его раньше дефолтного. Это паттерн «local override beats default» — прямой аналог нашего `profiles/<name>/agent-overrides/<role>.md`, который переопределяет `agents/<role>-agent.md`.

2. **`hook_for :test_framework`.** Генератор объявляет хук:
   ```ruby
   hook_for :test_framework, as: :helper
   ```
   Это позволяет подключить другой генератор (RSpec вместо TestUnit) без изменения основного. Аналог нашего «профиль подключает другой набор агентов через manifest».

3. **Наследование генераторов.** Генератор может `invoke 'other_generator'` — цепочка вызовов. Аналог pipeline: один slash-command вызывает несколько субагентов последовательно.

4. **`class_option` для профилей.** Опции объявляются декларативно:
   ```ruby
   class_option :api, type: :boolean, default: false
   ```
   При `--api` генератор создаёт другой набор файлов. Это аналог `--profile=kb-team` в нашем `/init`.

**Отличие от нашего случая:** Rails generators — code-gen (Ruby), у нас — docs/config gen. Но принцип «declare options → conditionally invoke sub-generators → local overrides beat defaults» полностью применим.

---

### GitHub template-repos

**Источник:** [primary] [GitHub Docs: Creating a template repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-template-repository) — оригинальная документация.

**Как работает.** Репозиторий помечается как template в Settings. При создании нового репо пользователь выбирает «Use this template». GitHub копирует файлы из дефолтной ветки (опционально — всех веток). Никакой генерации, подстановки переменных, условий — просто копирование.

**Ключевые паттерны:**

1. **Simplest possible baseline.** Template-repo — это буквально «скопировать директорию». Без Jinja, без вопросов, без hooks. Для нашего `project_template` это уже сделано — мы идём дальше.

2. **Нет update-механизма.** После клонирования репо никак не связано с шаблоном. Изменения в шаблоне не накатываются на уже созданные проекты. Это baseline «Option A» (несколько отдельных template-repo) из нашего брифа — с известными минусами (drift).

3. **Branches не наследуются в PR.** «Branches created from a template have unrelated histories» — нельзя сделать PR из ветки шаблона. Для нас это означает: если хотим «профили как ветки» — не работает.

4. **Интеграция с Copier как надстройкой.** Паттерн `epics-containers`: template-repo содержит `copier.yml` → пользователь клонирует шаблон → запускает `copier update` для получения обновлений шаблона. Гибрид template-repo + Copier решает отсутствие update-цикла.

**Применимо к Wave 2:** наш `project_template` уже является GitHub template-repo. Добавление Copier-манифеста поверх — опциональное улучшение для update-цикла (Wave 3+).

---

### Сравнительная матрица

| Критерий | Cookiecutter | Copier | dbt-init | Rails generators | GitHub template-repo |
|---|---|---|---|---|---|
| **Декларация профиля** | `cookiecutter.json` (JSON) | `copier.yml` (YAML, 2-tier) | `profile_template.yml` (fixed+prompts) | `class_option` (Ruby DSL) | нет |
| **Templating-язык** | Jinja2 | Jinja2 | нет | ERB (.tt files) | нет |
| **Условные файлы** | Jinja в именах | Jinja в именах + `when` | нет | `if`-логика в generators | нет |
| **Зависимые вопросы** | через хук-скрипт | нативный `when` | нет | через опции | нет |
| **Override-merge** | нет | `_migrations` + three-way merge | нет | local template overrides | нет |
| **Update-цикл** | нет | да (`copier update`) | нет | нет | нет |
| **Lifecycle hooks** | pre/post-gen скрипты | `_migrations` с before/after | нет | `hook_for` цепочки | нет |
| **Тест-инфраструктура** | `pytest-cookies` | `copier-pytest` | нет | RSpec генераторы | нет |
| **Применимо к Wave 2** | частично | да | паттерн manifest | паттерн override | baseline |

---

### Применимо к Wave 2

1. **Из Copier:** паттерн `when`-условий на вопросы `/init` — профиль спрашивается первым, остальные вопросы показываются условно. Паттерн `_migrations` с `before`/`after` фазами — для эволюции профиля между волнами. Паттерн `!include` — для разбивки большого manifest.yaml профиля на модули.

2. **Из dbt-init:** структура `fixed + prompts` в `profiles/<name>/manifest.yaml` — фиксированные scaffold/subagent-set декларированы явно, вариабельные части спрашиваются при init. Это решает вопрос Q11 (AGENTS.md = реестр, manifest = фильтр).

3. **Из Rails generators:** паттерн local override beats default (`lib/templates/` > дефолт) — наши `profiles/<name>/agent-overrides/<role>.md` переопределяют `agents/<role>-agent.md`. Паттерн `hook_for` — профиль объявляет зависимые генераторы (pipeline-режимы PM).

---

## Блок 2 — Multi-agent frameworks

### Microsoft AutoGen / Microsoft Agent Framework

**Источник:** [primary] [AutoGen GitHub](https://github.com/microsoft/autogen) + [Microsoft Agent Framework docs](https://learn.microsoft.com/en-us/agent-framework/overview/) — оригинальная документация. [secondary] [MAF Overview blogpost](https://devblogs.microsoft.com/agent-framework/microsoft-agent-framework-version-1-0/) — пересказ.

**Контекст 2025:** AutoGen 0.4 (jan 2025) переработал архитектуру. В октябре 2025 AutoGen слился с Semantic Kernel в **Microsoft Agent Framework** (MAF, public preview). AutoGen теперь в maintenance mode.

**Как декларируются агенты.** В AutoGen AgentChat — programmatic-only:
```python
AssistantAgent("researcher", model_client=OpenAIChatCompletionClient(model="gpt-4o"))
```
Нет YAML-реестра ролей. Агенты — Python-объекты, каталог — код. MAF добавляет `SessionAgent`, `MiddlewarePipeline`, но по-прежнему code-first.

**Ключевые паттерны:**

1. **Orchestration patterns (5 видов в MAF):** sequential, concurrent, handoff, group chat, Magentic-One. Для нас релевантны: handoff (PM → BA → SA цепочка) и concurrent (параллельные subagents через `superpowers:dispatching-parallel-agents`).

2. **Middleware pipeline.** MAF вводит `middleware: [ContentSafetyFilter, AuditLogger, CompliancePolicy]` — intercept/transform/extend без изменения промптов. Аналог нашего профиля как middleware: профиль определяет, какие «фильтры» (роли) активны.

3. **Dynamic agent discovery via MCP registry.** Microsoft в мае 2025 присоединился к MCP Steering Committee, добавив registry service: агенты публикуют свои инструменты, другие агенты их открывают. Для нас: AGENTS.md = статический registry (без dynamic discovery — намеренно).

4. **Каталог ролей в AutoGen: scattered.** Нет единого реестра. Агенты создаются where-needed в коде. Для масштабируемого проекта это проблема — именно поэтому MAF добавил типизированные `SessionAgent`.

**Что применимо к Wave 2:** паттерн middleware pipeline для profile-as-filter (профиль = набор active middlewares над base PM). Паттерн 5 orchestration modes как основа для 3 наших pipelines.

---

### CrewAI

**Источник:** [primary] [CrewAI docs: Agents](https://docs.crewai.com/en/concepts/agents) + [GitHub crewAIInc/crewAI](https://github.com/crewaiinc/crewai) — оригинальная документация. [secondary] [DeepWiki: Crew Configuration](https://deepwiki.com/crewAIInc/crewAI/2.1-crew-configuration-and-orchestration) — архитектурный разбор.

**Как декларируется каталог ролей.** CrewAI предлагает **YAML-based configuration как рекомендованный путь**:

`agents.yaml`:
```yaml
researcher:
  role: "{topic} Senior Data Researcher"
  goal: "Uncover cutting-edge developments in {topic}"
  backstory: "You're a seasoned researcher..."
  model: gpt-4o
  tools: [WebSearchTool, ScrapeWebsiteTool]

reporting_analyst:
  role: "{topic} Reporting Analyst"
  goal: "Create detailed reports based on {topic} data analysis"
  backstory: "You're a meticulous analyst..."
```

`tasks.yaml`:
```yaml
research_task:
  description: "Conduct a thorough research about {topic}"
  expected_output: "A list with 10 bullet points..."
  agent: researcher

reporting_task:
  description: "Review the context and expand each topic..."
  expected_output: "A fully fledged report..."
  agent: reporting_analyst
  output_file: report.md
```

**Ключевые паттерны:**

1. **Разделение agents/tasks/crew.** Три уровня: агент (кто) → задача (что делать) → crew (как организовать). Для нас: agent = роль в AGENTS.md, task = конкретный слэш-вызов, crew = pipeline.

2. **`process: sequential | hierarchical`.** В crew-конфигурации:
   ```yaml
   process: hierarchical
   manager_llm: gpt-4o
   ```
   Hierarchical = менеджер (PM) делегирует задачи worker-агентам. Это точный аналог нашего PM-orchestrator → subagents.

3. **`core params` vs `optional params`.** В `agents.yaml` — три обязательных поля (`role`, `goal`, `backstory`) + optional (tools, max_iter, timeout, memory). Применимо к нашему AGENTS.md: обязательные поля контракта + опциональные.

4. **Variables через `{topic}` в YAML.** Input-переменные подставляются через `crew.kickoff(inputs={'topic': 'AI'})`. Для нас: variables в agent-overrides подставляются из manifest профиля.

5. **`@CrewBase` decorator + `@agent`/`@task` методы.** Programmatic альтернатива YAML для динамических агентов. Аналог нашего «PM in decompose может add opt-in subagent в задачи».

**Что применимо к Wave 2:** структура `agents.yaml` (role/goal/backstory/model/tools) как образец для нашего AGENTS.md. Паттерн `process: hierarchical` + `manager_llm` — основа для pipeline-orchestrator = PM-агент.

---

### LangGraph (multi-agent режим)

**Источник:** [primary] [LangGraph GitHub](https://github.com/langchain-ai/langgraph) + [langgraph-supervisor-py](https://github.com/langchain-ai/langgraph-supervisor-py) — оригинальная документация. [secondary] [Latenode: LangGraph 2025 guide](https://latenode.com/blog/ai-frameworks-technical-infrastructure/langgraph-multi-agent-orchestration/) — архитектурный анализ.

**Как декларируется каталог ролей.** LangGraph — code-first, нет YAML-реестра. Агенты = Python-объекты, переданные в `create_supervisor()`:
```python
workflow = create_supervisor(
    [research_agent, math_agent, writer_agent],
    model=model,
    prompt="You are a team supervisor managing specialized agents..."
)
app = workflow.compile()
```

**Ключевые паттерны:**

1. **DAG как модель pipeline.** `StateGraph` + nodes (агенты/функции) + edges (условные переходы). Compile + invoke. Это самая мощная модель для conditional pipelines (не только sequential).

2. **Supervisor pattern = tool-based handoff.** Supervisor получает каждое сообщение, классифицирует, вызывает нужный агент через `delegate_to_research_expert(task="...")`. Handoff — это tool-call. Агенты не знают о существовании друг друга — только supervisor знает о всех. Применимо к нашему PM-orchestrator: PM вызывает `/ba`, `/sa`, `/dev` как tool-calls (slash-commands).

3. **Multi-level hierarchy.** Supervisor агентов может быть агентом в parent-supervisor'е. Для нас: pipeline (`project-planning`) = специальный режим PM, внутри которого PM вызывает цепочку BA→SA→Dev.

4. **Нет нативного YAML-реестра.** Каталог ролей = scattered по коду. В крупных проектах это создаёт сложность discovery. LangGraph Studio (UI) частично решает visualisation, но не декларативный registry.

5. **`StateGraph` compile = static pipeline declaration.** После compile граф фиксирован. Для dynamic add/remove агентов нужно пересобирать граф. Для нас: профиль = pre-compiled граф из manifest'а.

**Что применимо к Wave 2:** паттерн supervisor → handoff-to-specialist с task-description — для pipeline-orchestrator как PM-mode. Идея conditional edges в DAG — для critical-path pipeline (зависимости задач).

---

### AgentScope

**Источник:** [primary] [AgentScope docs: Pipeline](https://doc.agentscope.io/tutorial/task_pipeline.html) + [GitHub agentscope-ai/agentscope](https://github.com/agentscope-ai/agentscope) — оригинальная документация. [secondary] [Analytics Vidhya guide](https://www.analyticsvidhya.com/blog/2026/01/agentscope-ai/) — обзор.

**Как декларируется каталог.** Code-first, нет YAML-реестра агентов на уровне фреймворка. Агенты регистрируются передачей в pipeline:
```python
SequentialPipeline(agents=[researcher, analyst, writer])
FanoutPipeline(agents=[agent1, agent2, agent3], enable_gather=True)
```

**Ключевые паттерны:**

1. **Три типа pipeline:** Sequential (вывод A → вход B), Fanout (одно сообщение → несколько агентов параллельно), MsgHub (broadcast + async). Для наших 3 pipelines: project-planning = Sequential; BA-acceptance = Sequential с gate; critical-path = может быть Fanout для параллельной оценки зависимостей.

2. **SKILL.md для agent-skills.** AgentScope вводит файл `SKILL.md` с YAML-frontmatter (`name`, `description`) + инструкции в теле. Регистрация: `toolkit.register_agent_skill(skill_path)`. Это очень похоже на нашу структуру `agents/<role>-agent.md` с frontmatter.

3. **`MsgHub` как broadcast-механизм.** Контекстный менеджер, который routing'ует сообщения между несколькими агентами без явного message-passing. Аналог нашего «все агенты пишут в shared content/ директорию» — файловая система как broadcast channel.

4. **Нет декларативного registry ролей.** Как LangGraph и AutoGen — scattered. AgentScope Runtime v1.0 (ноябрь 2025) добавил "Agent as API" — агенты как HTTP-сервисы с discovery. Для нас это избыточно.

**Что применимо к Wave 2:** паттерн `SKILL.md` (YAML frontmatter + markdown body = agent definition) — прямой аналог нашего `agents/<role>-agent.md`. Типизация pipeline (Sequential/Fanout/MsgHub) как основа для декларации наших 3 pipelines в manifest профиля.

---

### Anthropic Claude Code agents (наш базис)

**Источник:** [primary] [Claude Code docs: Sub-agents](https://code.claude.com/docs/en/sub-agents) — оригинальная документация.

**Формат субагента.** Markdown-файл с YAML frontmatter:
```markdown
---
name: researcher
description: Collects domain context. Use for research tasks before BA.
tools: Read, Grep, Glob, WebSearch, WebFetch
model: sonnet
skills: [infoinstyle]
memory: project
isolation: worktree
---

You are a domain researcher...
```

**Обязательные поля:** `name`, `description`. Остальные — опциональные.

**Ключевые наблюдения:**

1. **Registry = директория `.claude/agents/`.** Нет единого manifest-файла с перечнем всех агентов. Discovery = сканирование директории. Приоритет: managed > CLI > project > user > plugin. **Это означает:** наш AGENTS.md — это человекочитаемый registry поверх физического registry в `.claude/plugins/project/agents/`.

2. **Priority-based override.** Plugin-агент может быть переопределён project-агентом с тем же именем. Это точный механизм для нашего `profiles/<name>/agent-overrides/<role>.md` — override living at higher priority path.

3. **`isolation: worktree`.** Субагент получает изолированный git worktree. Применимо к нашим pipeline'ам: каждый pipeline-шаг работает в своём worktree, не загрязняя основной контекст.

4. **`skills: [list]` в frontmatter.** Скиллы инжектируются в контекст субагента при старте. Это декларативный способ добавить профиль-специфичные инструкции без изменения base-prompt.

5. **Subagents не могут создавать других subagents.** «Subagents cannot spawn other subagents» — важное ограничение для дизайна pipeline-orchestrator. Pipeline = режим PM-агента (main context), не вложенный субагент.

---

### Сравнительная матрица каталога ролей и pipeline-механики

| Критерий | AutoGen/MAF | CrewAI | LangGraph | AgentScope | Claude Code |
|---|---|---|---|---|---|
| **Декларация каталога** | Programmatic (Python) | `agents.yaml` + `tasks.yaml` | Programmatic (Python) | Programmatic (Python) | `.claude/agents/*.md` (MD+YAML) |
| **Registry** | Scattered | YAML files (полу-декларативный) | Scattered | Scattered | Dir-based (`.claude/agents/`) |
| **Pipeline-типы** | Sequential, Concurrent, Handoff, GroupChat, Magentic-One | Sequential, Hierarchical | DAG (StateGraph) | Sequential, Fanout, MsgHub | Sequential (implicit через slash) |
| **Orchestrator-паттерн** | Group chat / Magentic-One | Hierarchical + manager_llm | Supervisor + handoff tools | SequentialPipeline | PM в main context |
| **Override-механизм** | Нет (code replace) | Нет (new agent) | Нет (new node) | Нет | Priority-dir override |
| **Роль-фильтрация по профилю** | Нет | `process` + `manager_agent` | Conditional edges | FanoutPipeline selector | Manifest `subagents: {role: core/optional}` (Wave 2 design) |
| **YAML-based config** | Нет | Да (рекомендован) | Нет | Нет | Да (frontmatter) |

---

### Применимо к Wave 2

1. **Из CrewAI:** структура `agents.yaml` (role/goal/backstory/model/tools) — образец для обогащения AGENTS.md. Паттерн `process: hierarchical` + manager_llm — архитектурное подтверждение нашего «PM = orchestrator в main context». Отделение `agents.yaml` от `tasks.yaml` — разделение «кто» и «что делать» применимо к разделению AGENTS.md (кто) и commands/*.md (что делать).

2. **Из LangGraph:** паттерн supervisor + tool-based handoff как механика pipeline: PM вызывает следующий этап через slash-команду (= tool-call), передаёт task-description. Multi-level hierarchy — pipeline может включать sub-pipelines (BA-acceptance внутри project-planning).

3. **Из AgentScope:** типизация pipelines (Sequential/Fanout/MsgHub) применима к декларации в manifest профиля:
   ```yaml
   pipelines:
     project-planning:
       type: sequential
       stages: [researcher?, ba, sa, dev, devops?]
     ba-acceptance:
       type: sequential
       stages: [ba-acceptance-check]
     critical-path:
       type: fanout
       parallel: [task-duration-estimate, dependency-graph]
   ```

4. **Из Claude Code (наш базис):** `isolation: worktree` в frontmatter pipeline-агента — изоляция эпика. `skills: [list]` — декларативная инъекция профиль-специфичного контекста без изменения base-prompt. Priority-dir override как механика profile-override для agent-prompts.

---

## Блок 3 — KB-эталоны Gramax/wiki

### naumen-ecosystem/business-requirements/ (бизнес-каталог)

**Источник:** [primary] Локальный репозиторий `/Users/mdemyanov/Devel/naumen-ecosystem/business-requirements/` — прямое чтение файлов.

**Структура каталога:**
```
business-requirements/
  .doc-root.yaml          ← rich schema: 15+ properties
  _index.md               ← дашборд с <view> по 3 разным фильтрам
  methodology/            ← процессная методология (workflow, roles, rituals, traceability)
  stakeholders/           ← per-стейкхолдер статьи
  jtbd/                   ← JTBD по субдоменам
  goals/                  ← OKR-цели
  requirements/           ← BRQ по субдоменам (service-desk/, cmdb/, ...)
  processes/              ← бизнес-процессы
  glossary/               ← термины
```

**Наблюдение 1 — Богатый `.doc-root.yaml` с многоуровневой таксономией.** Схема содержит 15+ properties: ID, Тип сущности (Enum: Стейкхолдер/JTBD/Цель/BRQ/Процесс/Глоссарий), Продукты (Enum: SIM/Project Ruler/ITAM/…), Домен, Sub домен, Стейкхолдер (Enum с 20+ ролями), Приоритет (P0/P1/P2), Статус (Идея→Реализовано), Тип работы (Functional/Emotional/Social). Каждое property имеет `style` (цвет) и `icon`. Для Wave 2: `kb-team`-профиль должен иметь аналогично богатый `.doc-root.yaml` (Owner, Тип контента, Статус, Аудитория), а не минимальный как сейчас в шаблоне.

**Наблюдение 2 — `_index.md` как дашборд с `<view>` фильтрами.** Главная страница содержит три блока `<view>` с разными `defs`:
```
<view defs="Тип сущности=Стейкхолдер&JTBD&Цель&Процесс&none" groupby="Статус" display="List"/>
<view defs="...,Приоритет=P1&P2&none" groupby="Sub домен" display="List"/>
<view defs="..." groupby="Продукты" display="List"/>
```
Это Gramax-специфичный паттерн навигации: один `_index.md` как точка входа с множественными фильтрованными представлениями. Применимо к нашему `project`-профилю: `content/_index.md` должен содержать `<view>` для каждого Тип контента.

**Наблюдение 3 — Цепочка трассируемости как структурный принцип.** `Стейкхолдер → JTBD → Цель → BRQ → Epic → Feature → Story → Task` задаёт cross-document трассируемость через поля `Источник JTBD`, `Связанная цель`, `Процесс`. Properties в `.doc-root.yaml` используются как typed links между каталогами. Для Wave 2: при дизайне `kb-team`-профиля можно заложить цепочку `Role → Runbook → Incident` с аналогичными cross-link properties.

**Наблюдение 4 — `methodology/` как отдельный раздел.** Процессная методология хранится в собственном разделе (`workflow.md`, `roles.md`, `rituals.md`, `traceability.md`), а не смешана со статьями требований. Применимо к нашему шаблону: `content/00-project/` аналогично содержит процессные артефакты (ADR, roadmap, plans), отдельно от доменных.

---

### naumen-smp/ (тех-каталог)

**Источник:** [primary] Локальный репозиторий `/Users/mdemyanov/Devel/naumen-ecosystem/naumen-smp/` — прямое чтение файлов.

**Структура каталога.** Технический каталог документации платформы Naumen SMP. Организован по функциональным блокам платформы: `action/`, `admin/`, `attr/`, `catalog/`, `class/`, `dap/`, `db/`, и десятки других. Это flat-functional разбивка по capabilities платформы, не по artifact-типам.

**`.doc-root.yaml`:**
```yaml
title: Naumen SMP
syntax: xml
properties:
  - name: Admin
    style: red
  - name: User
    style: blue
  - name: API
    style: green
```

**Наблюдение 1 — Минимальная schema, audience-oriented properties.** Вместо типа контента или статуса — аудитория (Admin/User/API). Это KB-паттерн для технической документации: primary filter = кому предназначено, не что это. Применимо к `kb-product`-профилю: property `Аудитория` (Внешний/Внутренний/Разработчик) важнее чем `Фаза`.

**Наблюдение 2 — Functional decomposition vs artifact decomposition.** Структура `naumen-smp/` организована по features (что делает система), а не по типам артефактов (требование/ADR/runbook). Это противоположность `business-requirements/`, который организован по artifact-types. Для Wave 2: `kb-team`-профиль, вероятно, должен идти по function-decomposition (roles/, runbooks/, incidents/), а не по artifact-types.

**Наблюдение 3 — No `_index.md` files observed.** В наблюдаемом фрагменте структуры `_index.md` в субдиректориях не обнаружены — это либо особенность этого каталога, либо упущение. Для нашего шаблона это критично: C1-правило валидатора требует `_index.md` в каждой папке.

---

### GitLab Handbook — public KB-эталон

**Источник:** [primary] [handbook.gitlab.com/handbook/support/knowledge-base/kb-style-guide/](https://handbook.gitlab.com/handbook/support/knowledge-base/kb-style-guide/) — оригинальная документация. [secondary] [GitLab Docs style guide](https://docs.gitlab.com/development/documentation/styleguide/) — пересказ.

**Как организован.** GitLab Handbook — статический сайт (Hugo + GitLab Pages), тысячи markdown-файлов. Структура: по отделам/функциям (Engineering, Customer Success, Finance, Security...), внутри — по процессам/гайдам/ролям.

**Ключевые паттерны:**

1. **Topic-based grouping, не artifact-type grouping.** Статьи группируются по теме/домену, не по типу (все гайды вместе, все процессы вместе). Для нашего `kb-product`-профиля это означает: `20-howto/` и `30-faq/` организованы по теме продукта, не по типу контента.

2. **Frontmatter-минимализм.** GitLab Handbook использует `title` и `description` в frontmatter, иногда `weight` для порядка. Нет сложных property-схем как в `business-requirements/`. Для `custom`-профиля: минимальный `.doc-root.yaml` с только `Тип контента` и `Статус`.

3. **Style Guide как самостоятельный артефакт.** KB Style Guide — отдельная страница, описывающая структуру статьи: заголовок, теги, категория, краткое описание, шаги. Для нашего `kb-team`-профиля: `methodology/style-guide.md` как шаблон-инструкция для новых страниц.

4. **Cross-linking через относительные ссылки.** Internal links — `[text](/handbook/engineering/...)`. Нет сложных property-based cross-links как в Gramax. Для нас: в рамках одного каталога Gramax — относительные ссылки; cross-каталожные — inline code (`` `other-catalog/path.md` ``).

5. **Navigation = файловая структура.** Нет отдельного navigation.yaml — навигация = директории и файлы. Hugo генерирует sidebar автоматически. Аналог нашего Gramax: `_index.md` в каждой папке + порядок через `order:` в frontmatter.

---

### Принципы навигации, структуры, кросс-ссылок, properties

Сводные наблюдения по всем трём KB-эталонам:

**Навигация:**
- `_index.md` в каждой папке — обязательное правило (наш C1-check). Без него раздел невидим.
- `order:` (integer) в frontmatter `_index.md` — контроль порядка в sidebar. В `business-requirements/` все `_index.md` имеют `order: N`.
- `<view defs="..." groupby="..." display="List"/>` — Gramax-специфичный дашборд на `_index.md`. Мощный инструмент: одна страница = несколько отфильтрованных views.

**Структура:**
- Бизнес-каталог: artifact-type decomposition (requirements/, jtbd/, goals/…)
- Тех-каталог: functional decomposition (action/, catalog/, dap/…)
- Team-KB (GitLab): topic/department decomposition
- Правило: выбор decomposition-стратегии = первое решение при дизайне нового профиля.

**Кросс-ссылки:**
- Внутри каталога: Gramax relative links `[text](../path/file.md)`
- Между каталогами: inline code `` `other-catalog/path.md` `` — Gramax рендерит как кликабельную ссылку
- Properties как typed links: `Источник JTBD: JTBD-SD-01-001` — не гиперссылка, но семантическая связь через поиск

**Properties-схема:**
- Минимум для всех профилей: `Тип контента` (Enum) + `Статус` (Enum)
- `project`-профиль добавляет: `Фаза` (PoC/MVP/Pilot/Production)
- `kb-team`-профиль добавляет: `Owner` (роль), `Аудитория`, `Тип документа` (Runbook/Role/Incident/Onboarding)
- `kb-product`-профиль добавляет: `Аудитория` (Internal/External), `Продукт`, `Версия`
- `business-requirements`-эталон показывает: богатая schema (15+ props) позволяет делать мощные дашборды, но требует дисциплины заполнения

---

## Открытые вопросы для SA (что Research не закрыл)

1. **Merge-семантика операции `delete` в `apply-overlay.sh`.** Если профиль удаляет подпапку (например, `kb-team` удаляет `30-requirements/`), но в папке уже есть файлы — как вести себя? Silent skip или error? Copier создаёт `*.rej`, но у нас bash-скрипт. SA нужно определить семантику.

2. **Profile + stack-overlay composability.** Как применять `apply-overlay.sh project` + `apply-overlay.sh naumen-smp` одновременно? Порядок применения влияет на результат (если оба патчат одно). Нужна explicit composition-semantics. Research показал, что все рассмотренные tools (Copier, dbt) не решают этот вопрос нативно.

3. **AGENTS.md как человекочитаемый реестр vs `.claude/plugins/project/agents/` как физический registry.** Как обеспечить синхронизацию? `validate-profile.py` должен проверять, что все роли в manifest'е существуют физически в `agents/`. Но кто canonical source — AGENTS.md или файловая система? SA нужно зафиксировать в ADR.

4. **Agent-override frontmatter `extends`/`sections: replace|append`.** Из interview-results Q12 — override через declarative-merge. Research показал аналог в Copier (`!include`) и Rails (template override). Но формат нашего `agent-overrides/<role>.md` не специфицирован. SA нужно определить: `extends:`, `sections:` в frontmatter — это Gramax-native или custom preprocessing?

5. **Pipeline-declaration в manifest профиля.** Research предложил типизацию (Sequential/Fanout), но не специфицировал schema. Пример из AgentScope:
   ```yaml
   pipelines:
     project-planning:
       type: sequential
       stages: [researcher?, ba, sa, dev, devops?]
   ```
   SA нужно решить: `stages` — это просто список ролей или явные slash-команды? И как `?` (optional) декларируется формально.

6. **Как работает `isolation: worktree` для pipeline-этапов.** Claude Code subagent поддерживает `isolation: worktree` — изолированный git worktree на субагент. Для pipeline это означает: каждый этап работает в своём worktree и merge'ит результат. SA нужно решить: pipeline-orchestrator создаёт один worktree на весь pipeline или per-stage?

7. **`kb-team`-профиль: functional vs artifact decomposition.** Research показал два паттерна. `business-requirements/` — artifact-type; `naumen-smp/` — functional; GitLab Handbook — topic/department. Какой выбрать для `kb-team`? BA должен подтвердить JTBD, SA — декларировать scaffold.

---

## Источники

- [primary] [Cookiecutter documentation](https://cookiecutter.readthedocs.io/) — основная дока, конфиг cookiecutter.json, hooks, advanced features
- [primary] [Copier documentation: Configuring](https://copier.readthedocs.io/en/stable/configuring/) — конфиг copier.yml, when-условия, migrations, !include
- [primary] [Copier documentation: Updating](https://copier.readthedocs.io/en/stable/updating/) — update-цикл, merge, conflict handling
- [primary] [dbt-labs/dbt-init GitHub](https://github.com/dbt-labs/dbt-init) — profile_template.yml паттерн
- [primary] [dbt docs: dbt init command](https://docs.getdbt.com/reference/commands/init) — описание profile_template.yml
- [primary] [Rails Guides: Generators](https://guides.rubyonrails.org/generators.html) — template overrides, hook_for, class_option
- [primary] [GitHub Docs: Creating a template repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-template-repository) — ограничения GitHub template-repo
- [primary] [Microsoft AutoGen GitHub](https://github.com/microsoft/autogen) — архитектура AutoGen 0.4
- [primary] [Microsoft Agent Framework overview](https://learn.microsoft.com/en-us/agent-framework/overview/) — MAF, orchestration patterns, middleware pipeline
- [primary] [CrewAI docs: Agents](https://docs.crewai.com/en/concepts/agents) — agents.yaml schema, role/goal/backstory
- [primary] [LangGraph GitHub](https://github.com/langchain-ai/langgraph) — StateGraph, DAG pipeline
- [primary] [langgraph-supervisor-py](https://github.com/langchain-ai/langgraph-supervisor-py) — supervisor pattern, handoff tools
- [primary] [AgentScope docs: Pipeline](https://doc.agentscope.io/tutorial/task_pipeline.html) — SequentialPipeline, FanoutPipeline, MsgHub
- [primary] [Claude Code docs: Sub-agents](https://code.claude.com/docs/en/sub-agents) — frontmatter schema, priority dirs, isolation
- [primary] `/Users/mdemyanov/Devel/naumen-ecosystem/business-requirements/` — локальный эталонный бизнес-каталог
- [primary] `/Users/mdemyanov/Devel/naumen-ecosystem/naumen-smp/` — локальный технический каталог
- [primary] [GitLab Handbook: KB Style Guide](https://handbook.gitlab.com/handbook/support/knowledge-base/kb-style-guide/) — public KB-эталон, article structure
- [secondary] [DeepWiki: CrewAI Configuration](https://deepwiki.com/crewAIInc/crewAI/2.1-crew-configuration-and-orchestration) — архитектурный разбор CrewAI
- [secondary] [Latenode: LangGraph 2025](https://latenode.com/blog/ai-frameworks-technical-infrastructure/langgraph-multi-agent-orchestration/) — сводный анализ LangGraph
- [secondary] [MAF Version 1.0 blog](https://devblogs.microsoft.com/agent-framework/microsoft-agent-framework-version-1-0/) — анонс MAF
