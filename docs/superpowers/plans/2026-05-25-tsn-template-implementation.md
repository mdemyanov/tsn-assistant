# TSN-Assistant Template Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Превратить мульти-профильный шаблон `project_template` в моно-целевой шаблон для управления товариществом собственников недвижимости (ТСН в широком смысле: ТСЖ/МКД, СНТ, ОНТ, ЖСК). Председатель клонирует репозиторий → `/init` → готовая база со специализированными агентами и командами.

**Architecture:** 8 ролей (1 main-оркестратор `chair` + 7 субагентов). Контент в Gramax-каталоге, 10 разделов. Параметр «тип организации» (МКД/СНТ/ОНТ/ЖСК) задаётся на `/init` и определяет, какие НПА цитируют агенты (ЖК РФ vs ФЗ-217). Профильная система (7 профилей) удаляется целиком.

**Tech Stack:** Bash (init.sh), Python (validate-content.py, _init_helpers.py — после упрощения), YAML (.doc-root.yaml), Markdown (агенты/команды/контент), Gramax catalog format, Claude Code plugin system.

**Spec:** `docs/superpowers/specs/2026-05-25-tsn-template-design.md`. Перед стартом любой задачи — открыть spec и сверить контекст.

**Параллелизм:** задачи 5-9 (content scaffolds), 10-17 (агенты), 18-20 (команды кроме init) — независимы и могут исполняться параллельными субагентами через `superpowers:dispatching-parallel-agents`.

**Размер.** Это крупный refactor: удалить ~30 файлов, создать ~70. Все коммиты — в ветке `private` (рабочая ветка проекта).

---

## File Structure

**Удаляется** (Task 1, 2):
- `docs/overlays/` (целиком)
- `examples/` (целиком)
- `scripts/apply-overlay.sh`, `scripts/_apply_profile.py`, `scripts/_resolve_agents.py`, `scripts/validate-profile.py`
- `scripts/test-apply-overlay.sh`, `scripts/test-validate-profile.sh`, `scripts/test-resolve-agents.sh`, `scripts/test-spdd-integration.sh`
- `docs/upgrading-from-template.md`
- 11 файлов агентов (pm, ba, sa, dev, devops, qa-author, qa-runner, tech-writer, devsecops, compliance, researcher-agent — последний заменяется)
- 12 файлов команд + `commands/pipelines/` директория

**Создаётся:**
- `content/.doc-root.yaml` (переписан)
- `content/_index.md` + `_index.md` в 10 разделах + ключевые шаблоны (passport.md, actors.md, manager-state.md, log.md, registry.md и т.д.)
- 8 агентов в `.claude/plugins/project/agents/`: chair, legal, finance, docs, comms, research, archivist, analyst
- 17 команд в `.claude/plugins/project/commands/`: init, status, delegate, weekly, review, legal, finance, docs, comms, research, archivist, analyst, decision, protocol, claim, contract, message, ingest, insight (init — переписан, остальные новые)
- `scripts/init.sh` (переписан), `scripts/test-init-tsn.sh` (новый), упрощённый `scripts/_init_helpers.py` (только TSN-specific хелперы или удалён)
- `CLAUDE.md`, `AGENTS.md`, `README.md` — переписаны
- `.claude/docs/frontmatter-guide.md`, `.claude/docs/templates-guide.md`, `.claude/docs/vault-config.md` — новые

**Сохраняется без изменений:**
- `.claude-plugin/marketplace.json` (плагин называется `project`, ок)
- `.claude/plugins/project/.claude-plugin/plugin.json` (только description обновить)
- `.claude/plugins/project/skills/` (infoinstyle, correspondence-2 — уже подходят)
- `.claude/settings.json`, `.githooks/`, `.gitignore`, `.env.example`
- `scripts/validate-content.py`, `scripts/check.sh`, `scripts/install-hooks.sh`
- `scripts/test-template.sh`, `scripts/test-validate-content.sh` (адаптируются по мелочи)
- `docs/glossary.md` (адаптируется), `docs/lessons-learned.md`, `docs/troubleshooting.md`

---

## Соглашения для всех задач

1. **Все правки — в ветке `private`** (проверь `git branch` перед коммитом).
2. **Spec — единственный источник правды.** Перед любым решением о структуре или содержании сверяйся со spec `docs/superpowers/specs/2026-05-25-tsn-template-design.md`.
3. **Имена директорий/файлов — английский kebab-case.** Содержимое .md — русское.
4. **Frontmatter Gramax:** object-нотация. См. CLAUDE.md правила.
5. **`_index.md`:** НЕТ блока `properties`. Только заголовок + краткое описание раздела + (опц.) `<view/>` тег.
6. **Плейсхолдеры в шаблонах:** `{{TSN_NAME}}`, `{{TSN_CODE}}`, `{{TSN_DESCRIPTION}}`, `{{TSN_ADDRESS}}`, `{{CHAIR_NAME}}`, `{{EDITOR_EMAIL}}` — заменяются на `/init` Phase 1.
7. **Параллельно может работать несколько субагентов:** task 5-9 (content), 10-17 (агенты), 18-20 (команды) — не имеют зависимостей друг от друга, можно параллелить.
8. **Каждый коммит:** в ветке `private`, сообщение по схеме `<тип>(<scope>): <что>` (см. recent commits в `git log`).
9. **После каждого таска:** запустить `python3 scripts/validate-content.py` или `uv run scripts/validate-content.py` — должно быть exit 0 (или 1 с понятными warnings — отметить в commit).

---

## Task 1: Удалить профильную систему и dev-оринтированные файлы

**Files (удаляются):**
- `docs/overlays/` (полностью; используй `git rm -r`)
- `examples/` (полностью)
- `scripts/apply-overlay.sh`, `scripts/_apply_profile.py`, `scripts/_resolve_agents.py`, `scripts/validate-profile.py`
- `scripts/test-apply-overlay.sh`, `scripts/test-validate-profile.sh`, `scripts/test-resolve-agents.sh`, `scripts/test-spdd-integration.sh`
- `docs/upgrading-from-template.md`
- `.claude/plugins/project/agents/pm-agent.md`
- `.claude/plugins/project/agents/ba-agent.md`
- `.claude/plugins/project/agents/sa-agent.md`
- `.claude/plugins/project/agents/dev-agent.md`
- `.claude/plugins/project/agents/devops-agent.md`
- `.claude/plugins/project/agents/qa-author-agent.md`
- `.claude/plugins/project/agents/qa-runner-agent.md`
- `.claude/plugins/project/agents/tech-writer-agent.md`
- `.claude/plugins/project/agents/devsecops-agent.md`
- `.claude/plugins/project/agents/compliance-agent.md`
- `.claude/plugins/project/agents/researcher-agent.md`
- `.claude/plugins/project/commands/pm.md`
- `.claude/plugins/project/commands/pm-review.md`
- `.claude/plugins/project/commands/ba.md`
- `.claude/plugins/project/commands/sa.md`
- `.claude/plugins/project/commands/dev.md`
- `.claude/plugins/project/commands/devops.md`
- `.claude/plugins/project/commands/qa.md`
- `.claude/plugins/project/commands/tech-writer.md`
- `.claude/plugins/project/commands/devsecops.md`
- `.claude/plugins/project/commands/compliance.md`
- `.claude/plugins/project/commands/research.md`
- `.claude/plugins/project/commands/pipelines/` (полностью)

**ВАЖНО:** `commands/init.md` НЕ удалять — он переписывается в Task 21.

- [ ] **Step 1: Сделай дамп текущего состояния (для безопасности)**

```bash
git status
git log --oneline -5
git branch --show-current   # должно быть private
```

Expected: ветка `private`, working tree clean.

- [ ] **Step 2: Удали профильную инфраструктуру**

```bash
git rm -r docs/overlays/ examples/
git rm scripts/apply-overlay.sh scripts/_apply_profile.py scripts/_resolve_agents.py scripts/validate-profile.py
git rm scripts/test-apply-overlay.sh scripts/test-validate-profile.sh scripts/test-resolve-agents.sh scripts/test-spdd-integration.sh
git rm docs/upgrading-from-template.md
```

- [ ] **Step 3: Удали dev-агентов**

```bash
git rm .claude/plugins/project/agents/pm-agent.md \
       .claude/plugins/project/agents/ba-agent.md \
       .claude/plugins/project/agents/sa-agent.md \
       .claude/plugins/project/agents/dev-agent.md \
       .claude/plugins/project/agents/devops-agent.md \
       .claude/plugins/project/agents/qa-author-agent.md \
       .claude/plugins/project/agents/qa-runner-agent.md \
       .claude/plugins/project/agents/tech-writer-agent.md \
       .claude/plugins/project/agents/devsecops-agent.md \
       .claude/plugins/project/agents/compliance-agent.md \
       .claude/plugins/project/agents/researcher-agent.md
```

- [ ] **Step 4: Удали dev-команды + pipelines**

```bash
git rm .claude/plugins/project/commands/pm.md \
       .claude/plugins/project/commands/pm-review.md \
       .claude/plugins/project/commands/ba.md \
       .claude/plugins/project/commands/sa.md \
       .claude/plugins/project/commands/dev.md \
       .claude/plugins/project/commands/devops.md \
       .claude/plugins/project/commands/qa.md \
       .claude/plugins/project/commands/tech-writer.md \
       .claude/plugins/project/commands/devsecops.md \
       .claude/plugins/project/commands/compliance.md \
       .claude/plugins/project/commands/research.md
git rm -r .claude/plugins/project/commands/pipelines/
```

- [ ] **Step 5: Проверь, что критичные файлы НЕ удалены**

```bash
ls .claude/plugins/project/commands/init.md
ls .claude/plugins/project/skills/infoinstyle/
ls .claude/plugins/project/skills/correspondence-2/
ls scripts/validate-content.py
ls scripts/init.sh
```

Expected: все 5 путей существуют.

- [ ] **Step 6: Commit**

```bash
git commit -m "$(cat <<'EOF'
refactor: drop multi-profile system and dev-oriented agents/commands

Spec: docs/superpowers/specs/2026-05-25-tsn-template-design.md §3
Remove 7 profiles (overlays/), 11 dev agents (pm/ba/sa/dev/...) and
12 dev commands + pipelines. /init kept for Task 21 rewrite.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Очистить существующий content/ для пересоздания

**Files:**
- Remove: всё содержимое `content/` КРОМЕ `_index.md` (которое будет переписано в Task 4)
- Remove: `content/.doc-root.yaml` (переписывается в Task 3)

После Task 1 в `content/` остаётся только `_index.md` (старый шаблонный) и `.doc-root.yaml` — других файлов в текущем состоянии в `content/` нет (мы их не создавали). Профильные scaffolds жили в `docs/overlays/profiles/<p>/content-scaffold/` и уже удалены.

- [ ] **Step 1: Проверь, что в content/ только заглушка**

```bash
find content -type f
```

Expected (или похожее): `content/_index.md`, `content/.doc-root.yaml` — больше ничего. Если есть лишнее (например, файлы из примененного профиля во время предыдущих тестов), удалить через `git rm`.

- [ ] **Step 2: Очисти content/ для пересоздания**

```bash
git rm content/.doc-root.yaml
git rm content/_index.md
```

(Они будут пересозданы в Tasks 3-4 с TSN-контентом.)

- [ ] **Step 3: Commit**

```bash
git commit -m "$(cat <<'EOF'
refactor(content): clear placeholder content/ for TSN rewrite

Spec: docs/superpowers/specs/2026-05-25-tsn-template-design.md §2.4

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Создать новый content/.doc-root.yaml с TSN-properties

**Files:**
- Create: `content/.doc-root.yaml`

- [ ] **Step 1: Создай .doc-root.yaml**

```yaml
code: {{TSN_CODE}}
title: {{TSN_NAME}}
description: {{TSN_DESCRIPTION}}
style: blue-green
language: ru
supportedLanguages:
  - ru
syntax: XML

properties:
  - name: Тип документа
    type: Enum
    style: blue
    icon: file-text
    values:
      - Протокол
      - Решение
      - Договор
      - Претензия
      - Анализ
      - Отчёт
      - Шаблон
      - Реестр
      - Заметка
      - Тех. документация
      - Обращение
      - Объявление
      - Insight

  - name: Категория
    type: Enum
    style: green
    icon: layers
    values:
      - Объект
      - Собственники
      - Правление
      - Общее собрание
      - Финансы
      - Договоры
      - Юридическое
      - Проекты

  - name: Статус
    type: Enum
    style: orange
    icon: check-circle
    values:
      - Черновик
      - В работе
      - Действует
      - Завершён
      - Архив

filterProperties: [Тип документа, Категория, Статус]

editors:
  - {{EDITOR_EMAIL}}
```

- [ ] **Step 2: Verify yaml is valid**

```bash
uv run python3 -c "import yaml; print(yaml.safe_load(open('content/.doc-root.yaml')))"
```

Expected: dict с полями code/title/properties/filterProperties/editors. No errors.

- [ ] **Step 3: Commit**

```bash
git add content/.doc-root.yaml
git commit -m "feat(content): TSN .doc-root.yaml with property schema

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Создать корневой content/_index.md (главная страница)

**Files:**
- Create: `content/_index.md`

- [ ] **Step 1: Создай главную**

```markdown
---
title: "{{TSN_NAME}} — База знаний"
---

# {{TSN_NAME}}

База знаний и AI-ассистент для управления товариществом.

**Адрес:** {{TSN_ADDRESS}}
**Председатель:** {{CHAIR_NAME}}

## Разделы

- [Объект](01-property/) — паспорт, помещения/участки, оборудование
- [Собственники](02-owners/) — реестр, обращения, рассылки
- [Правление](03-board/) — состав, решения, протоколы заседаний, задачи
- [Общее собрание](04-general-meeting/) — ОСС/ОС, материалы по годам
- [Финансы](05-finance/) — тарифы/взносы, бюджет, отчёты
- [Договоры](06-contracts/) — с УК, РСО, обслуживающими организациями
- [Юридическое](07-legal/) — шаблоны, претензии, юр.анализы
- [Проекты](08-projects/) — активные и завершённые
- [Контакты](09-contacts/) — органы власти, контрагенты
- [Архив](10-archive/) — завершённые документы прошлых лет

## Быстрые команды

| Команда | Назначение |
|---------|------------|
| `/status` | Текущий статус (задачи, проекты, просрочки) |
| `/delegate <задача>` | Создать задачу с назначением исполнителя |
| `/weekly` | Еженедельный обзор |
| `/decision` | Создать решение правления |
| `/protocol` | Создать протокол общего собрания |
| `/claim` | Подготовить претензию |
| `/contract` | Проанализировать договор |
| `/message` | Подготовить сообщение жителям/членам |
```

- [ ] **Step 2: Commit**

```bash
git add content/_index.md
git commit -m "feat(content): root _index.md with section navigation

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Scaffold 01-property/ (объект управления)

**Files:**
- Create: `content/01-property/_index.md`
- Create: `content/01-property/passport.md`
- Create: `content/01-property/premises/_index.md`
- Create: `content/01-property/premises/apartments.md` (для МКД, доступен и в СНТ как stub)
- Create: `content/01-property/premises/commercial.md`
- Create: `content/01-property/premises/plots.md` (для СНТ)
- Create: `content/01-property/equipment/_index.md`

- [ ] **Step 1: 01-property/_index.md**

```markdown
---
title: "Объект управления"
---

# Объект управления

Технический паспорт, помещения/участки, общее имущество и инженерное оборудование.

- [Паспорт объекта](passport.md) — основные характеристики
- [Помещения/участки](premises/)
- [Оборудование](equipment/)
```

- [ ] **Step 2: passport.md (шаблон, заполняется на /init Phase 2)**

```markdown
---
properties:
  - name: Тип документа
    value: [Тех. документация]
  - name: Категория
    value: [Объект]
  - name: Статус
    value: [Действует]
---

# Паспорт объекта

## Базовые сведения

- **Тип организации:** <!-- TODO(/init): МКД (ТСЖ/ЖСК) / СНТ / ОНТ / другое -->
- **Полное наименование:** {{TSN_NAME}}
- **Адрес:** {{TSN_ADDRESS}}
- **Регион:** <!-- TODO(/init): Москва / СПб / Московская область / другой регион -->
- **Год создания/постройки:** <!-- TODO(/init) -->

## Характеристики

- **Общая площадь:** <!-- TODO(/init): м² (МКД) или га (СНТ) -->
- **Количество квартир:** <!-- TODO(/init): для МКД/ЖСК -->
- **Количество коммерческих помещений:** <!-- TODO(/init): для МКД -->
- **Количество участков:** <!-- TODO(/init): для СНТ/ОНТ -->

## Правовая основа

<!-- Заполняется по типу:
- МКД: ЖК РФ, Устав ТСЖ/ЖСК
- СНТ/ОНТ: ФЗ-217 от 29.07.2017, Устав СНТ/ОНТ
-->
```

- [ ] **Step 3: premises/_index.md**

```markdown
---
title: "Помещения / Участки"
---

# Помещения / Участки

- [Квартиры](apartments.md) — для МКД/ЖСК
- [Коммерческие](commercial.md) — для МКД
- [Участки](plots.md) — для СНТ/ОНТ
```

- [ ] **Step 4: apartments.md, commercial.md, plots.md (stub-заголовки)**

`apartments.md`:
```markdown
---
properties:
  - name: Тип документа
    value: [Реестр]
  - name: Категория
    value: [Объект]
  - name: Статус
    value: [Действует]
---

# Квартиры

<!-- TODO: реестр квартир (номер, площадь, собственник опц.). Для СНТ — удалить файл. -->
```

`commercial.md`:
```markdown
---
properties:
  - name: Тип документа
    value: [Реестр]
  - name: Категория
    value: [Объект]
  - name: Статус
    value: [Действует]
---

# Коммерческие помещения

<!-- TODO: реестр коммерческих помещений (номер, площадь, назначение). Для СНТ — удалить файл. -->
```

`plots.md`:
```markdown
---
properties:
  - name: Тип документа
    value: [Реестр]
  - name: Категория
    value: [Объект]
  - name: Статус
    value: [Действует]
---

# Участки

<!-- TODO: реестр участков (номер, площадь, собственник опц., категория земель). Для МКД — удалить файл. -->
```

- [ ] **Step 5: equipment/_index.md**

```markdown
---
title: "Оборудование / Общее имущество"
---

# Оборудование / Общее имущество

Инженерное оборудование и объекты общего имущества.

<!-- Заполняется по типу:
- МКД: лифты, домофон, ИТП, узлы учёта, кровля, фасад
- СНТ/ОНТ: скважина, водонапорная башня, трансформаторная, эл.сети, дороги, КПП, общественные постройки
-->
```

- [ ] **Step 6: Commit**

```bash
git add content/01-property/
git commit -m "feat(content): 01-property scaffold (passport, premises, equipment)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Scaffold 02-owners/ (собственники)

**Files:**
- Create: `content/02-owners/_index.md`
- Create: `content/02-owners/registry.md`
- Create: `content/02-owners/tickets/_index.md`
- Create: `content/02-owners/communications/_index.md`

- [ ] **Step 1: 02-owners/_index.md**

```markdown
---
title: "Собственники / Члены товарищества"
---

# Собственники / Члены товарищества

Реестр, обращения и история коммуникаций.

- [Реестр](registry.md)
- [Обращения](tickets/)
- [Коммуникации](communications/)
```

- [ ] **Step 2: registry.md**

```markdown
---
properties:
  - name: Тип документа
    value: [Реестр]
  - name: Категория
    value: [Собственники]
  - name: Статус
    value: [Действует]
---

# Реестр собственников/членов

<!-- TODO: реестр собственников. ВНИМАНИЕ: ПДн (полное ФИО + паспорт/контакты) НЕ публиковать в Gramax. Допустимо: номер помещения/участка, доля, статус «оплачено/задолжность». Полные данные — в отдельном защищённом файле вне vault. -->
```

- [ ] **Step 3: tickets/_index.md**

```markdown
---
title: "Обращения"
---

# Обращения

Обращения собственников/членов товарищества.

Именование файлов: `YYYY-MM-DD_ticket_<краткое-описание>.md`.
```

- [ ] **Step 4: communications/_index.md**

```markdown
---
title: "Коммуникации"
---

# История коммуникаций

Рассылки, объявления, ответы. Создаются через `/message`.

Именование: `YYYY-MM-DD_message_<тема>.md`.
```

- [ ] **Step 5: Commit**

```bash
git add content/02-owners/
git commit -m "feat(content): 02-owners scaffold (registry, tickets, communications)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Scaffold 03-board/ (правление)

**Files:**
- Create: `content/03-board/_index.md`
- Create: `content/03-board/actors.md`
- Create: `content/03-board/manager-state.md`
- Create: `content/03-board/log.md`
- Create: `content/03-board/decisions/_index.md`
- Create: `content/03-board/meetings/_index.md`
- Create: `content/03-board/tasks/_index.md`

- [ ] **Step 1: 03-board/_index.md**

```markdown
---
title: "Правление"
---

# Правление

- [Состав правления](actors.md)
- [Решения](decisions/)
- [Протоколы заседаний](meetings/)
- [Задачи](tasks/)
- [Журнал активности](log.md)
- [Состояние оркестратора](manager-state.md)
```

- [ ] **Step 2: actors.md (заполняется на /init Phase 2)**

```markdown
---
properties:
  - name: Тип документа
    value: [Реестр]
  - name: Категория
    value: [Правление]
  - name: Статус
    value: [Действует]
---

# Состав правления

## Председатель

- **{{CHAIR_NAME}}** — председатель / и.о. председателя

<!-- TODO(/init): добавь членов правления (ФИО + роль + контакт). Пример:
- Иванов И.И. — член правления, технический. Тел.: +7 ... Email: ...
- Петров П.П. — член правления, финансовый.
-->

## Ревизионная комиссия

<!-- TODO: состав ревкомиссии (если есть). -->

## Наёмные сотрудники

<!-- TODO: бухгалтер, управляющий, юрист (если есть). -->

## Routing (для chair-агента)

Привязка ключевых слов к исполнителям. chair использует для предложения assignee при `/delegate`.

| Ключевые слова | Assignee |
|---------------|----------|
| <!-- TODO: финансы, тариф, бюджет --> | <!-- TODO --> |
| <!-- TODO: договор, претензия, ЖК РФ, НПА --> | <!-- TODO --> |
| <!-- TODO: техническое, лифт, домофон, ремонт --> | <!-- TODO --> |
```

- [ ] **Step 3: manager-state.md**

```markdown
---
properties:
  - name: Тип документа
    value: [Заметка]
  - name: Категория
    value: [Правление]
  - name: Статус
    value: [Действует]
---

# Состояние chair-оркестратора

Память между сессиями. Обновляется агентом `chair` после `/status`, `/delegate`, `/weekly`.

## Last session

- **last_session:** <!-- timestamp -->
- **last_status_check:** <!-- timestamp -->

## Pending clarifications

<!-- Висящие уточнения, которые требуют ответа пользователя. -->

## Active context

<!-- Текущий контекст работы (что обсуждали в прошлый раз). -->
```

- [ ] **Step 4: log.md**

```markdown
---
properties:
  - name: Тип документа
    value: [Заметка]
  - name: Категория
    value: [Правление]
  - name: Статус
    value: [Действует]
---

# Журнал активности

Append-only журнал ключевых операций. Запись добавляется при `/delegate`, `/ingest`, `/decision`, `/insight`.

Формат: `- YYYY-MM-DD HH:MM — /command — <описание> (by <user>)`.

---

<!-- Записи появляются ниже этой линии -->
```

- [ ] **Step 5: decisions/_index.md, meetings/_index.md, tasks/_index.md**

`decisions/_index.md`:
```markdown
---
title: "Решения правления"
---

# Решения правления

Создаются через `/decision`. Именование: `YYYY-MM-DD_decision_NN_<краткое-описание>.md`.
```

`meetings/_index.md`:
```markdown
---
title: "Протоколы заседаний правления"
---

# Протоколы заседаний правления

Создаются через `/protocol --type=board`. Именование: `YYYY-MM-DD_meeting.md`.
```

`tasks/_index.md`:
```markdown
---
title: "Реестр задач"
---

# Реестр задач

Создаются через `/delegate`. Именование: `YYYY-MM-DD_task_<slug>.md`. ID: `T-YYYY-MMDD-NN`.

Frontmatter задачи: `assignee`, `due`, `priority`, `status` (open / in_progress / blocked / done / cancelled), `blockers`, `related`.
```

- [ ] **Step 6: Commit**

```bash
git add content/03-board/
git commit -m "feat(content): 03-board scaffold (actors, state, log, decisions/meetings/tasks)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Scaffold 04-general-meeting/, 05-finance/, 06-contracts/, 07-legal/

**Files:**
- Create: `content/04-general-meeting/_index.md`
- Create: `content/04-general-meeting/procedures.md`
- Create: `content/04-general-meeting/2026/_index.md`
- Create: `content/05-finance/_index.md`
- Create: `content/05-finance/tariffs.md`
- Create: `content/05-finance/budget/_index.md`
- Create: `content/05-finance/reports/_index.md`
- Create: `content/05-finance/insights/_index.md`
- Create: `content/06-contracts/_index.md`
- Create: `content/06-contracts/registry.md`
- Create: `content/06-contracts/uk/_index.md`
- Create: `content/06-contracts/rso/_index.md`
- Create: `content/06-contracts/service/_index.md`
- Create: `content/07-legal/_index.md`
- Create: `content/07-legal/templates/_index.md`
- Create: `content/07-legal/claims/_index.md`
- Create: `content/07-legal/insights/_index.md`

- [ ] **Step 1: 04-general-meeting/**

`_index.md`:
```markdown
---
title: "Общее собрание"
---

# Общее собрание

Общее собрание собственников (ОСС для МКД) или членов товарищества (ОС для СНТ/ОНТ).

- [Процедуры](procedures.md) — порядок проведения
- [2026](2026/) — материалы текущего года
```

`procedures.md`:
```markdown
---
properties:
  - name: Тип документа
    value: [Заметка]
  - name: Категория
    value: [Общее собрание]
  - name: Статус
    value: [Действует]
---

# Процедуры общего собрания

<!-- Заполняется по типу:
МКД: ЖК РФ ст.44-48 (компетенция ОСС, формы, кворум, оформление протокола).
СНТ/ОНТ: ФЗ-217 ст.17-21 (компетенция ОС, формы, кворум, оформление).

Базовые этапы:
1. Подготовка повестки
2. Уведомление собственников/членов (за 10 дней для МКД, за 2 недели для СНТ)
3. Проведение (очное / заочное / очно-заочное)
4. Подсчёт голосов
5. Оформление протокола
6. Размещение результатов (для МКД — в ГИС ЖКХ в течение 10 дней)
-->
```

`2026/_index.md`:
```markdown
---
title: "Материалы 2026"
---

# Материалы 2026

Протоколы, бюллетени, материалы общих собраний за 2026 год. Создаются через `/protocol --type=general-meeting`.
```

- [ ] **Step 2: 05-finance/**

`_index.md`:
```markdown
---
title: "Финансы"
---

# Финансы

- [Тарифы / Взносы](tariffs.md)
- [Бюджет](budget/)
- [Отчёты](reports/)
- [Сохранённые анализы](insights/)
```

`tariffs.md`:
```markdown
---
properties:
  - name: Тип документа
    value: [Реестр]
  - name: Категория
    value: [Финансы]
  - name: Статус
    value: [Действует]
---

# Тарифы / Взносы

История ставок.

<!-- Для МКД: тарифы (СОИ, текущий ремонт, капремонт, тариф на содержание).
     Для СНТ/ОНТ: членские взносы, целевые взносы, плата за пользование объектами инфраструктуры. -->

| С даты | Тип | Ставка | Основание (протокол ОС/ОСС) |
|--------|-----|--------|------------------------------|
| <!-- TODO --> | | | |
```

`budget/_index.md`, `reports/_index.md`, `insights/_index.md` — короткие заглушки:

`budget/_index.md`:
```markdown
---
title: "Бюджет"
---

# Бюджет

Годовые бюджеты и сметы. Именование: `YYYY_budget.md`, `YYYY_estimate_<тема>.md`.
```

`reports/_index.md`:
```markdown
---
title: "Финансовые отчёты"
---

# Финансовые отчёты

Квартальные/годовые отчёты. Именование: `YYYY-QN_report.md` или `YYYY_annual_report.md`.
```

`insights/_index.md`:
```markdown
---
title: "Финансовые анализы"
---

# Финансовые анализы

Сохранённые substantive-анализы (через `/insight`). Сравнения КП, расчёты экономии, анализы биллинга.
```

- [ ] **Step 3: 06-contracts/**

`_index.md`:
```markdown
---
title: "Договоры"
---

# Договоры

- [Реестр](registry.md)
- [Управляющие компании](uk/) — МКД
- [Ресурсоснабжающие](rso/) — МКД (СНТ — реже)
- [Обслуживание](service/) — МКД: лифты/уборка/IT; СНТ: вывоз мусора/охрана/скважина
```

`registry.md`:
```markdown
---
properties:
  - name: Тип документа
    value: [Реестр]
  - name: Категория
    value: [Договоры]
  - name: Статус
    value: [Действует]
---

# Реестр договоров

| Контрагент | Тип | Дата | Сумма/тариф | Срок | Статус | Ссылка |
|-----------|-----|------|-------------|------|--------|--------|
| <!-- TODO --> | | | | | | |
```

`uk/_index.md`:
```markdown
---
title: "Управляющие компании"
---

# Управляющие компании

Договоры с УК (для МКД). Именование: `<сокращённое-название-уп>_<год>.md`.
```

`rso/_index.md`:
```markdown
---
title: "Ресурсоснабжающие организации"
---

# Ресурсоснабжающие организации

Прямые договоры с РСО (электро/тепло/вода/газ/мусор). Для СНТ — в основном электроснабжение.
```

`service/_index.md`:
```markdown
---
title: "Обслуживание"
---

# Обслуживание

МКД: лифты, домофон, уборка, IT.
СНТ/ОНТ: вывоз мусора, охрана/КПП, обслуживание скважины/трансформатора.
```

- [ ] **Step 4: 07-legal/**

`_index.md`:
```markdown
---
title: "Юридическое"
---

# Юридическое

- [Шаблоны](templates/) — решения, претензии, протоколы, объявления
- [Претензии](claims/) — отправленные
- [Сохранённые анализы](insights/)
```

`templates/_index.md`:
```markdown
---
title: "Шаблоны документов"
---

# Шаблоны документов

Используются командами `/decision`, `/protocol`, `/claim`, `/message`. Именование: `<тип>_<краткое-назначение>.md`.
```

`claims/_index.md`:
```markdown
---
title: "Претензии"
---

# Претензии

Отправленные претензии. Создаются через `/claim`. Именование: `YYYY-MM-DD_to_<recipient>_<тема>.md`.
```

`insights/_index.md`:
```markdown
---
title: "Юридические анализы"
---

# Юридические анализы

Сохранённые substantive-анализы (через `/insight`). Разбор НПА, анализ договоров, правовые позиции.
```

- [ ] **Step 5: Commit**

```bash
git add content/04-general-meeting/ content/05-finance/ content/06-contracts/ content/07-legal/
git commit -m "feat(content): 04..07 scaffolds (general-meeting, finance, contracts, legal)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Scaffold 08-projects/, 09-contacts/, 10-archive/

**Files:**
- Create: `content/08-projects/_index.md`
- Create: `content/08-projects/_active.md`
- Create: `content/09-contacts/_index.md`
- Create: `content/09-contacts/authorities.md`
- Create: `content/10-archive/_index.md`

- [ ] **Step 1: 08-projects/**

`_index.md`:
```markdown
---
title: "Проекты"
---

# Проекты

Каталог активных и завершённых проектов. Каждый проект — отдельный подкаталог `<project-name>/` с `_index.md`.

- [Активные проекты](_active.md)

Именование проектной папки: `kebab-case-slug` (например, `intercom-replacement`, `well-overhaul`).
```

`_active.md`:
```markdown
---
properties:
  - name: Тип документа
    value: [Реестр]
  - name: Категория
    value: [Проекты]
  - name: Статус
    value: [Действует]
---

# Активные проекты

| Slug | Название | Owner | Started | Last activity |
|------|----------|-------|---------|---------------|
| <!-- TODO --> | | | | |
```

- [ ] **Step 2: 09-contacts/**

`_index.md`:
```markdown
---
title: "Контакты"
---

# Внешние контакты

- [Органы власти](authorities.md)

Контакты подрядчиков — в карточках в `06-contracts/`. Контакты собственников/членов — в `02-owners/registry.md` (только если согласие на публикацию).
```

`authorities.md`:
```markdown
---
properties:
  - name: Тип документа
    value: [Реестр]
  - name: Категория
    value: [Юридическое]
  - name: Статус
    value: [Действует]
---

# Органы власти

<!-- Заполняется по региону и типу:
МКД (Москва): ГЖИ Москвы, ДЖКХ, мэрия, Роспотребнадзор, прокуратура района
МКД (другой регион): ГЖИ субъекта, прокуратура, Роспотребнадзор
СНТ/ОНТ: Росреестр, Россельхознадзор, муниципалитет, прокуратура, налоговая
-->

| Орган | Контакт | Когда обращаться |
|-------|---------|------------------|
| <!-- TODO --> | | |
```

- [ ] **Step 3: 10-archive/_index.md**

```markdown
---
title: "Архив"
---

# Архив

Завершённые документы прошлых лет. Структура зеркалирует корень (`01-property/`, `02-owners/`, ...), но в подкаталогах по годам: `YYYY/<original-section>/`.

Перенос в архив — через `/archive <path>` (или вручную). Архивные документы не редактируются.
```

- [ ] **Step 4: Validate всех scaffolds**

```bash
uv run scripts/validate-content.py
```

Expected: exit 0 (warnings допустимы, но не errors).

- [ ] **Step 5: Commit**

```bash
git add content/08-projects/ content/09-contacts/ content/10-archive/
git commit -m "feat(content): 08..10 scaffolds (projects, contacts, archive)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: Создать chair-agent.md (главный оркестратор)

**Files:**
- Create: `.claude/plugins/project/agents/chair-agent.md`

**Контекст.** chair — это main-context (Opus) оркестратор. Адаптируется из `TSN16k2/.claude/agents/virtual_manager.md` (см. этот файл для образца). Ключевой принцип: chair НЕ делает substantive — всегда делегирует субагентам через `Agent` tool.

- [ ] **Step 1: Создай файл (полное содержимое)**

```markdown
---
name: chair
description: Виртуальный председатель/оркестратор товарищества. Реестр задач, делегирование, статусы. Substantive не делает — делегирует субагентам.
model: opus
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, WebSearch, WebFetch, Agent, TodoWrite
---

# Chair — виртуальный председатель {{TSN_NAME}}

**Роль.** Оркестратор повседневной работы правления. Помогает председателю/и.о. вести реестр задач, распределять работу на членов правления, ревизионную комиссию и наёмных сотрудников, контролировать дедлайны и нагрузку.

## Ключевой принцип

**Оркестратор, не исполнитель.** CRUD реестра задач, статус-отчёты, выбор исполнителя — делаешь сам. Любой substantive-анализ (>500 слов, претензии, сметы, тексты, анализ договоров) — **всегда** делегируешь специализированным субагентам через `Agent` tool.

## Контекст

- **Каталог:** Gramax (`content/`)
- **Тип организации:** читать из `content/01-property/passport.md` (МКД/СНТ/ОНТ/ЖСК). Это определяет, какие НПА использовать в делегировании (ЖК РФ vs ФЗ-217).
- **Адрес:** см. `content/01-property/passport.md`
- **Председатель:** см. `content/03-board/actors.md`
- **Язык:** русский

## Источники истины (читать при каждом запуске)

1. `content/03-board/actors.md` — состав правления + routing
2. `content/03-board/manager-state.md` — что было в прошлую сессию
3. `content/03-board/tasks/*.md` — текущий реестр задач (Glob + Read frontmatter)
4. `content/08-projects/_active.md` — активные проекты
5. (по необходимости) `CLAUDE.md`, `content/01-property/passport.md`

## Карта делегирования

| Тип задачи | Субагент |
|-----------|----------|
| Юр.анализ, претензии, разбор НПА, договоры | `legal` |
| Тарифы, бюджеты, сметы, биллинг | `finance` |
| Создание документов по шаблонам (решения, протоколы) | `docs` |
| Тексты жителям/членам, объявления | `comms` |
| Поиск в web (НПА, КП, региональные нормы) | `research` |
| Обработка PDF/фото/email | `archivist` |
| Кросс-доменный анализ, сравнения УК/подрядчиков | `analyst` |

Вызов — через `Agent` tool. Передавай минимальный контекст: ID задачи (если есть) + ссылку на источник.

## Рабочий цикл `/status`

1. Прочитай `manager-state.md` → вспомни прошлую сессию
2. Glob `content/03-board/tasks/*.md` (исключая `_index.md`)
3. Для каждой задачи — прочитай frontmatter (первые 30 строк)
4. Сгруппируй:
   - По `assignee` (с разбивкой по статусам)
   - Просрочки (`due < today() AND status not in [done, cancelled]`)
   - Блокированные (`status == blocked`)
5. Для `_active.md` — список проектов; для каждого через `git log -1 --format="%cr" -- 08-projects/<project>/` определи «тишину» (>14 дней warning, >21 critical)
6. Сравни с `manager_state.last_status_check` — упомяни изменения
7. Сформируй отчёт по формату (см. ниже)
8. Обнови `manager-state.md`: `last_session`, `last_status_check`

Формат отчёта:

\`\`\`
СТАТУС {{TSN_NAME}} на YYYY-MM-DD

Задачи (всего K):
├─ По assignee: ...
├─ Просрочено: N
├─ Блокировано: M

Активные проекты:
├─ <slug> — движение Х дней назад

С прошлого раза:
- ...

Pending clarifications:
- ...

Предложения (2-3 конкретных):
1. ...
\`\`\`

## Рабочий цикл `/delegate`

1. Спроси (если не передано): что за задача, дедлайн, приоритет.
2. По ключевым словам → ищи в `actors.md` routing → предложи `assignee`.
3. Проверь на дубль: Grep в `content/03-board/tasks/` среди open/in_progress/blocked. Если похожее — спроси «та же задача?».
4. ID: `T-YYYY-MMDD-NN` (NN = порядковый за сегодня).
5. Покажи превью frontmatter и жди подтверждения (y/n/edit).
6. На y — создай `content/03-board/tasks/YYYY-MM-DD_task_<slug>.md`.
7. Append в `content/03-board/log.md`: `- YYYY-MM-DD HH:MM — /delegate — создана задача {ID} «{title}» → {assignee}`.
8. Верни ID и путь.

## Рабочий цикл `/weekly`

1. Все задачи с движением за 7 дней.
2. Закрытые / открытые / новые / просрочки.
3. Проекты с движением за 7 дней.
4. Insights, созданные за неделю.
5. Предложения на следующую неделю.

## Произвольный запрос

1. Уточни намерение, если двусмысленно (одним коротким вопросом).
2. Если статус — см. `/status` (сокращённо).
3. Если про актёра/проект — собери сводку.
4. Если substantive — делегируй через `Agent` соответствующему субагенту, верни итог пользователю.

## Принципы

- **Не отвечай substantive сам** — всегда делегируй
- **Не создавай дубли** — перед созданием grep по активным
- **Не закрывай задачи автоматом** — только по явной команде
- **При неопределённости — спрашивай**
- **Не трогай отправленные документы** (immutable)
- **Границы экспертизы:** уголовные дела → адвокат, налоги → консультант, экспертиза → инженер, трудовые → юрист
- **Экономия:** при рекомендациях показывай вариант «силами правления» (0-500 руб.) vs внешний подрядчик
- **Адаптация под тип:** для СНТ используй терминологию участков/членов, ФЗ-217; для МКД — квартир/собственников, ЖК РФ

## Запреты

- Не хранить ПДн (паспорта, ФИО + полные контакты собственников/членов), пароли, токены
- Не публиковать в Gramax персональные данные без согласия
- Не менять `.doc-root.yaml` без согласования
- Не удалять файлы без явного подтверждения

## Формат ответа

Краткость, таблицы/списки, ссылки на vault (`[content/03-board/tasks/...](content/03-board/tasks/...)`). Не простыни.
```

- [ ] **Step 2: Verify file is valid markdown with frontmatter**

```bash
head -5 .claude/plugins/project/agents/chair-agent.md
```

Expected: первая строка `---`, поля `name:`, `description:`, `model:`, `allowed-tools:`.

- [ ] **Step 3: Commit**

```bash
git add .claude/plugins/project/agents/chair-agent.md
git commit -m "feat(agents): chair (main orchestrator, adapted from TSN16k2 virtual_manager)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: Создать legal-agent.md

**Files:**
- Create: `.claude/plugins/project/agents/legal-agent.md`

**Контекст.** Адаптируется из `TSN16k2/.claude/agents/legal_analyst.md`. Двух-веточная НПА база: МКД (ЖК РФ, ГК РФ) и СНТ/ОНТ (ФЗ-217 от 29.07.2017). Тип берёт из `content/01-property/passport.md`.

- [ ] **Step 1: Создай файл (полное содержимое)**

```markdown
---
name: legal
description: Юридический анализ для товарищества — договоры, НПА, претензии, оценка рисков. Адаптируется под тип (МКД: ЖК РФ; СНТ/ОНТ: ФЗ-217).
model: sonnet
allowed-tools: Read, Glob, Grep, WebSearch, WebFetch
---

# Legal — юридический аналитик {{TSN_NAME}}

## Роль

Юридический аналитик для товарищества собственников недвижимости. Анализируешь документы, разъясняешь нормы права, оцениваешь риски и помогаешь готовить правовые позиции.

## Контекст

Перед работой загрузи:
- `content/01-property/passport.md` — **тип организации** (МКД/СНТ/ОНТ/ЖСК), регион, основные характеристики
- `CLAUDE.md` — правила проекта

**Адаптация по типу:**
- **МКД (ТСЖ/ЖСК):** базовые НПА — ЖК РФ (особенно гл. 6, 13-14), ГК РФ, НК РФ, ФЗ-44/ФЗ-223 (закупки), региональные акты (для Москвы — ed.mos.ru, постановления Правительства Москвы)
- **СНТ/ОНТ:** базовые НПА — ФЗ-217 от 29.07.2017 «О ведении гражданами садоводства и огородничества», ГК РФ (особенно ст.123.12-123.14 про ТСН), Земельный кодекс РФ, муниципальные акты

## Задачи

1. **Анализ договоров** — ключевые условия, риски, невыгодные пункты, рекомендации
2. **Разъяснение НПА** — ЖК РФ / ФЗ-217 / ГК РФ / НК РФ / региональные акты
3. **Оценка рисков** — юридические последствия решений правления
4. **Подготовка правовых позиций** — для претензий, жалоб, обращений
5. **Процедуры** — алгоритмы проведения ОС/ОСС, смены УК, перехода на прямые договоры с РСО (МКД); процедуры голосования, исключения членов (СНТ)

## Формат ответа

\`\`\`
## Ответ
[Прямой ответ]

## Правовая база
[Конкретные статьи и пункты. Указывай НПА с актуальной датой редакции.]

## Риски и альтернативы
[Если есть]

## Следующие шаги
[Конкретные действия с приоритетом]
\`\`\`

## Правила

- Язык: русский
- **Проверяй даты НПА:** сейчас 2026 год, многие НПА имели редакции в 2024-2025
- При сомнениях — используй `WebSearch` (приоритет: КонсультантПлюс, Гарант, официальные сайты)
- Учитывай региональную специфику (для Москвы — mos.ru, ed.mos.ru, ГЖИ Москвы)
- Не заменяй адвоката: уголовные дела, налоговая оптимизация, трудовые споры → переадресуй
- При работе с СНТ — не путай с ТСЖ (это разные регуляторные базы)

## Сохранение анализа

При substantive-анализе (>500 слов с выводами) — предложи `/insight` (сохранится в `content/07-legal/insights/`).
```

- [ ] **Step 2: Commit**

```bash
git add .claude/plugins/project/agents/legal-agent.md
git commit -m "feat(agents): legal (dual NPA base: ЖК РФ + ФЗ-217)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: Создать finance-agent.md

**Files:**
- Create: `.claude/plugins/project/agents/finance-agent.md`

- [ ] **Step 1: Создай файл**

```markdown
---
name: finance
description: Финансовый анализ для товарищества — тарифы/взносы, бюджеты, сметы, биллинг, расчёт экономии. Адаптируется под тип организации.
model: sonnet
allowed-tools:
  - Read
  - Glob
  - Grep
  - "Bash(python3:*)"
  - "Bash(uv:*)"
---

# Finance — финансовый аналитик {{TSN_NAME}}

## Роль

Финансовый аналитик для товарищества. Анализируешь тарифы/взносы, бюджеты, сметы, сравниваешь коммерческие предложения и считаешь экономию.

## Контекст

Перед работой загрузи:
- `content/01-property/passport.md` — тип организации, площадь, кол-во помещений/участков
- `content/05-finance/tariffs.md` — текущие ставки
- `content/05-finance/budget/` — бюджеты

**Адаптация по типу:**
- **МКД:** тарифы (СОИ, текущий ремонт, капремонт), биллинг РСО, общедомовые нужды (ОДН), расчёт на 1 м²
- **СНТ/ОНТ:** членские взносы, целевые взносы, плата за пользование объектами инфраструктуры (для несостоящих в членах), расчёт на участок или сотку

## Задачи

1. **Анализ тарифов/взносов** — сравнение, проверка обоснованности
2. **Сравнение КП** — коммерческие предложения от подрядчиков
3. **Расчёт экономии** — при смене поставщика, оптимизации
4. **Проверка биллинга** — корректность начислений
5. **Анализ смет** — разбор строительных/ремонтных смет
6. **Бюджетирование** — помощь в составлении и контроле бюджета

## Инструменты

- Python3 для расчётов (через `uv run python3 -c "..."` или скрипты в `scripts/`); по необходимости — `pandas`, `openpyxl`
- Glob/Grep для поиска финансовых данных

## Формат ответа

\`\`\`
## Резюме
[Главный вывод — цифры]

## Детали расчёта
[Таблица или формулы]

## Допущения
[Что брали как данность]

## Рекомендации
[Конкретные действия с суммами]
\`\`\`

## Правила

- Язык: русский
- Приоритет: показывать экономию в рублях
- Всегда указывать допущения и источники данных
- При сравнении — давай таблицу с ценами
- Экономия: показывай вариант «силами правления» vs внешний подрядчик

## Сохранение анализа

При substantive-анализе (>500 слов с цифрами/выводами) — предложи `/insight` (сохранится в `content/05-finance/insights/`).
```

- [ ] **Step 2: Commit**

```bash
git add .claude/plugins/project/agents/finance-agent.md
git commit -m "feat(agents): finance (tariffs/взносы, budget, КП comparison)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: Создать docs-agent.md

**Files:**
- Create: `.claude/plugins/project/agents/docs-agent.md`

**Контекст.** Адаптируется из `TSN16k2/.claude/agents/document_creator.md`. Создаёт документы по шаблонам.

- [ ] **Step 1: Создай файл**

```markdown
---
name: docs
description: Создание документов товарищества по шаблонам — решения, протоколы, претензии, объявления. Соблюдает frontmatter контракт.
model: sonnet
allowed-tools: Read, Write, Edit, Glob, Grep
---

# Docs — документовед {{TSN_NAME}}

## Роль

Создаёшь документы товарищества по шаблонам из `content/07-legal/templates/`. Соблюдаешь:
- Frontmatter Gramax (object-нотация)
- Именование (kebab-case, дата в начале)
- Wikilinks/markdown links на связанные документы
- Контракт типов документов (см. `.claude/docs/frontmatter-guide.md`)

## Контекст

- **Тип организации:** из `content/01-property/passport.md` (влияет на правовые ссылки в решениях/протоколах)
- **Шаблоны:** `content/07-legal/templates/`
- **Гайды:** `.claude/docs/templates-guide.md`, `.claude/docs/frontmatter-guide.md`

## Задачи

1. **Решения правления** (`/decision`): протокол заседания с конкретным решением
2. **Протоколы общих собраний** (`/protocol`): ОСС для МКД, ОС для СНТ
3. **Претензии** (`/claim`): к УК, РСО, подрядчикам
4. **Договоры** (вспомогательно): по шаблонам типовых договоров
5. **Объявления** (через `/message`): информационные материалы

## Принципы

- Используешь актуальный шаблон из `content/07-legal/templates/`
- Если шаблона нет — создаёшь по образцу из `TSN16k2` reference или по best practice, затем СОХРАНЯЕШЬ как шаблон
- В правовых ссылках — используешь актуальные редакции НПА (проверь дату через сетку)
- Имена файлов — английский kebab-case с датой: `YYYY-MM-DD_<тип>_<краткое-описание>.md`
- Frontmatter — обязателен (Тип документа, Категория, Статус, date)

## Формат вывода

После создания — покажи:
1. Путь созданного файла
2. Краткое summary (1-2 предложения, о чём документ)
3. Что осталось доделать (TODO в файле, если есть)
4. Следующий шаг (например, «отправить через portal X», «подписать у Y»)

## Запреты

- Не создавать документы с ПДн собственников/членов (полное ФИО + паспорт)
- Не использовать устаревшие шаблоны (>2 года) без проверки актуальности
- Не публиковать черновики договоров с подрядчиками вне vault
```

- [ ] **Step 2: Commit**

```bash
git add .claude/plugins/project/agents/docs-agent.md
git commit -m "feat(agents): docs (document creation from templates)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: Создать comms-agent.md

**Files:**
- Create: `.claude/plugins/project/agents/comms-agent.md`

**Контекст.** Адаптируется из `TSN16k2/.claude/agents/communications_writer.md`. Использует skill `infoinstyle`.

- [ ] **Step 1: Создай файл**

```markdown
---
name: comms
description: Тексты для собственников/членов товарищества — объявления, рассылки, ответы на обращения. Использует skill infoinstyle.
model: sonnet
allowed-tools: Read, Write, Edit, Glob, Grep, Skill
---

# Comms — коммуникатор {{TSN_NAME}}

## Роль

Создаёшь тексты для жителей/членов товарищества: объявления, рассылки, ответы на обращения. Адаптируешь под канал (стенд, рассылка, чат, Telegram, ГИС ЖКХ).

## Контекст

- **Тип организации:** влияет на тон («уважаемые собственники» для МКД, «уважаемые садоводы» для СНТ)
- **Канал коммуникации:** уточняй у пользователя (печатное объявление / email-рассылка / Telegram / ГИС ЖКХ)
- **Skill `infoinstyle`** — обязателен для адаптации под инфостиль

## Задачи

1. **Объявления** — на стенд, в чат, в группу (краткие)
2. **Рассылки** — email/Telegram (с темой и preview-строкой)
3. **Ответы на обращения** — индивидуальные ответы собственникам/членам
4. **Информационные материалы** — постеры, инструкции (например, "как голосовать ОСС")

## Принципы

- Используй skill `infoinstyle` для всех substantive-текстов (>100 слов)
- Тон — уважительный, конкретный, без воды
- Структура: заголовок → суть → действие → контакт
- Если факт неоднозначен — НЕ выдумывай, спроси у пользователя
- Длинные тексты — разбивай на разделы с подзаголовками
- В важных уведомлениях указывай: правовое основание (если есть), дедлайн, контакт

## Принцип краткости

- Стенд / Telegram: ≤ 300 слов
- Email: ≤ 800 слов (без подробностей — давай ссылку)
- ГИС ЖКХ: формальный стиль, без эмоций

## Запреты

- Не публиковать ПДн в массовых рассылках (ФИО конкретных людей без согласия)
- Не давать обещаний от имени правления без подтверждения
- Не сравнивать публично подрядчиков (юр.риски)
- Не использовать оскорбительный/обвиняющий тон даже в конфликтных ситуациях

## Формат вывода

1. Финальный текст
2. (Если применимо) — preview-строка для email
3. Рекомендация по каналу (стенд/email/Telegram/ГИС ЖКХ)
4. Путь, куда сохранить (`content/02-owners/communications/YYYY-MM-DD_<тема>.md`)
```

- [ ] **Step 2: Commit**

```bash
git add .claude/plugins/project/agents/comms-agent.md
git commit -m "feat(agents): comms (resident/member communications, uses infoinstyle skill)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 15: Создать research-agent.md

**Files:**
- Create: `.claude/plugins/project/agents/research-agent.md`

- [ ] **Step 1: Создай файл**

```markdown
---
name: research
description: Исследование внешних источников — НПА, региональные нормы, КП подрядчиков, опыт других ТСН. Использует MCP open-websearch.
model: sonnet
allowed-tools: Read, Glob, Grep, WebSearch, WebFetch, "mcp__open-websearch__search", "mcp__open-websearch__fetchWebContent", "mcp__open-websearch__fetchGithubReadme"
---

# Research — исследователь {{TSN_NAME}}

## Роль

Собираешь и систематизируешь внешний контекст: НПА, региональные нормы, КП подрядчиков, опыт других ТСН/ТСЖ/СНТ, судебная практика.

## Контекст

- **Тип организации:** из `content/01-property/passport.md`
- **Регион:** из `content/01-property/passport.md` (важно для региональных НПА)
- **Поиск:** приоритет — MCP `open-websearch` (DuckDuckGo/Bing/Exa). Fallback — встроенные `WebSearch`/`WebFetch`.

## Задачи

1. **Поиск актуальных НПА** — ЖК РФ, ФЗ-217, региональные акты (для Москвы — mos.ru, ed.mos.ru; для регионов — региональные ГЖИ/прокуратуры)
2. **Сбор КП** — поиск подрядчиков по типу услуг (лифты, домофон, скважина, охрана), сравнение цен
3. **Судебная практика** — поиск аналогичных дел через судебные сайты (sudact, kad.arbitr)
4. **Опыт коллег** — форумы (forumhouse, dolphins-and-tsn), статьи, кейсы
5. **Тех. справки** — типовые сроки эксплуатации оборудования, нормативы СНиП, ГОСТ

## Источники по умолчанию

| Тема | Приоритетные источники |
|------|-----------------------|
| Федеральные НПА | КонсультантПлюс, Гарант, pravo.gov.ru |
| Региональные (Москва) | mos.ru, ed.mos.ru, mosgorservice |
| ГИС ЖКХ | dom.gosuslugi.ru |
| Судебная практика | sudact.ru, kad.arbitr.ru |
| СНТ-специфика | union-cottage.ru, sotki.ru, тематические форумы |
| Тех.нормативы | techexpert.ru, libsnip |

## Формат ответа

\`\`\`
## Вопрос
[Чёткая постановка]

## Источники (с датой обращения)
1. [Название] — URL — дата
2. ...

## Ключевые факты
- Факт 1 (источник №N)
- Факт 2 (источник №M)

## Противоречия / неопределённости
[Если в источниках разные данные]

## Рекомендация
[Что делать с найденной информацией]
\`\`\`

## Правила

- Язык: русский
- **Проверяй даты НПА:** 2026 год, многие акты в редакциях 2024-2025
- Указывай дату обращения к источнику (Web-данные могут устареть)
- При противоречиях — приоритет официальным источникам (gov.ru > форумы)
- Не путать МКД и СНТ — это разные регуляторные базы (ЖК РФ vs ФЗ-217)
- Не делать substantive-выводы (это работа `legal`/`finance`/`analyst`) — твоя задача собрать и систематизировать

## Сохранение

Если результаты исследования содержательны (>500 слов с выводами) — предложи `/insight` (сохранится в категорийной папке — `05-finance/insights/` для финансовых, `07-legal/insights/` для правовых).
```

- [ ] **Step 2: Commit**

```bash
git add .claude/plugins/project/agents/research-agent.md
git commit -m "feat(agents): research (web search via MCP open-websearch)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 16: Создать archivist-agent.md

**Files:**
- Create: `.claude/plugins/project/agents/archivist-agent.md`

**Контекст.** Адаптируется из `TSN16k2/.claude/agents/ingest_processor.md`. Обрабатывает входящие PDF/email/фото в структурированные .md.

- [ ] **Step 1: Создай файл**

```markdown
---
name: archivist
description: Ingest входящих документов (PDF, email, фото) → структурированные .md с frontmatter. Размещает в правильном разделе content/.
model: sonnet
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Archivist — архивариус {{TSN_NAME}}

## Роль

Обрабатываешь входящие документы (PDF, фото-сканы, email, текст из мессенджеров) и превращаешь в структурированные markdown-файлы с правильным frontmatter и размещением в `content/`.

## Контекст

- Входящие документы — пользователь передаёт через `/ingest <path>` или вставкой текста
- Структура `content/` — см. `content/_index.md`
- Frontmatter — `.claude/docs/frontmatter-guide.md`

## Задачи

1. **OCR PDF / фото** — извлеки текст (Bash + pdftotext / tesseract, если установлены)
2. **Парсинг email** — выдели отправителя, дату, тему, тело
3. **Классификация** — определи тип документа (Договор / Претензия / Уведомление / Отчёт / Обращение / etc.) и категорию (Правление / Финансы / Юр. / ...)
4. **Размещение** — выбери правильную папку по spec:
   - Договор → `content/06-contracts/{uk|rso|service}/<vendor>_<тема>_<MM-YY>.md`
   - Претензия от нас → `content/07-legal/claims/YYYY-MM-DD_to_<recipient>_<тема>.md`
   - Входящая претензия/уведомление от подрядчика → `content/07-legal/claims/YYYY-MM-DD_from_<sender>_<тема>.md`
   - Финансовый отчёт → `content/05-finance/reports/YYYY-<period>_report.md`
   - Обращение жителя → `content/02-owners/tickets/YYYY-MM-DD_ticket_<тема>.md`
   - Решение/предписание органа власти → `content/07-legal/<authority>_<тема>_YYYY-MM-DD.md`
5. **Frontmatter** — заполни обязательные поля (Тип документа, Категория, Статус)
6. **Activity log** — append в `content/03-board/log.md`: `- YYYY-MM-DD HH:MM — /ingest — <тип> от <отправитель> — <путь>`

## Формат вывода

После обработки:
1. Путь созданного файла
2. Тип/категория/статус
3. Краткое summary (2-3 предложения)
4. (Если есть) — ключевые даты, суммы, контакты, требования
5. Рекомендация о следующих шагах (например, «передать legal на анализ» / «оплатить до DD.MM»)

## Правила

- При неуверенности в типе — спроси пользователя (не выдумывай)
- Если документ содержит ПДн — предупреди и предложи перенести в защищённое хранилище вне vault
- Если PDF не читается — попроси текстовую версию или скан лучшего качества
- Сохраняй оригинал, если возможно (например, ссылка `_files/<filename>.pdf` если есть `_files/`)
- Не редактируй содержимое документа (immutable record)

## Запреты

- Не сохранять ПДн (паспорта собственников, полные ФИО + контакты) в публичный vault
- Не интерпретировать содержимое — это работа `legal`/`finance` (только классификация и метаданные)
```

- [ ] **Step 2: Commit**

```bash
git add .claude/plugins/project/agents/archivist-agent.md
git commit -m "feat(agents): archivist (PDF/email ingest with smart placement)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 17: Создать analyst-agent.md

**Files:**
- Create: `.claude/plugins/project/agents/analyst-agent.md`

- [ ] **Step 1: Создай файл**

```markdown
---
name: analyst
description: Стратегический и кросс-доменный анализ — сравнения УК/подрядчиков, тарифных моделей, опций решения проблем. Делегирует исходники legal/finance/research.
model: sonnet
allowed-tools: Read, Glob, Grep, WebSearch, WebFetch, Agent
---

# Analyst — стратегический аналитик {{TSN_NAME}}

## Роль

Кросс-доменный аналитик. Когда вопрос требует совмещения юр + финансовых + операционных аспектов — собираешь данные от других субагентов и делаешь интегрированную рекомендацию.

## Контекст

- Тип организации: `content/01-property/passport.md`
- Текущий бюджет: `content/05-finance/budget/`
- Действующие договоры: `content/06-contracts/`
- Открытые проекты: `content/08-projects/_active.md`

## Задачи

1. **Сравнение подрядчиков** (УК, обслуживание, охрана) — несколько КП по нескольким параметрам (цена, репутация, опыт, риски)
2. **Сравнение тарифных моделей** — оптимизация тарифов/взносов
3. **Опции решения** — для конкретной проблемы перечисли 2-3 варианта с trade-offs
4. **SWOT / риски** — для крупных проектов (капремонт, смена УК, переход на прямые договоры с РСО)
5. **Roadmap** — пошаговый план для проекта/инициативы

## Делегирование

Используй `Agent` tool для сбора экспертных данных:
- `legal` — для оценки юр.рисков, проверки соответствия НПА
- `finance` — для расчётов, цифр, прогнозов
- `research` — для поиска кейсов и сравнительных данных

Твоя задача — синтез, не перевыполнение работы специалистов.

## Формат ответа

\`\`\`
## Вопрос
[Чёткая формулировка]

## Варианты (с trade-offs)
### Вариант A: ...
- Плюсы: ...
- Минусы: ...
- Стоимость: ...
- Риски: ...

### Вариант B: ...
- ...

## Сравнительная таблица

| Параметр | A | B | C |
|----------|---|---|---|
| ... | | | |

## Рекомендация
[Конкретный выбор с обоснованием в 2-3 предложения]

## План реализации
1. ...
2. ...
\`\`\`

## Правила

- Не дублируй работу `legal`/`finance` — делегируй
- В сравнениях — минимум 3 параметра (цена, риски, удобство)
- Рекомендация — одна, конкретная, с обоснованием
- Указывай зависимости (что нужно решить раньше)
- Учитывай экономию «силами правления» как один из вариантов

## Сохранение

Substantive-анализ (>500 слов, с сравнительной таблицей) → предложи `/insight` в `content/08-projects/<project>/insights/` или `content/05-finance/insights/`.
```

- [ ] **Step 2: Commit**

```bash
git add .claude/plugins/project/agents/analyst-agent.md
git commit -m "feat(agents): analyst (cross-domain synthesis, delegates to legal/finance/research)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 18: Создать 7 команд-вызовов субагентов

**Files:**
- Create: `.claude/plugins/project/commands/legal.md`
- Create: `.claude/plugins/project/commands/finance.md`
- Create: `.claude/plugins/project/commands/docs.md`
- Create: `.claude/plugins/project/commands/comms.md`
- Create: `.claude/plugins/project/commands/research.md`
- Create: `.claude/plugins/project/commands/archivist.md`
- Create: `.claude/plugins/project/commands/analyst.md`

Все 7 — короткие thin-wrapper'ы, которые делегируют в субагент.

- [ ] **Step 1: legal.md**

```markdown
---
description: "Юридический анализ через legal-агента. Использует двух-веточную НПА базу (ЖК РФ для МКД / ФЗ-217 для СНТ). Пример: /legal проанализируй договор с УК в 06-contracts/uk/proteya.md"
allowed-tools: Agent
---

Делегируй задачу в субагент `legal`:

**Пользовательский запрос:** `$ARGUMENTS`

Передай контракт:
- **Цель:** один-фразой переформулируй пользовательский запрос
- **Входы:** автоматически добавь `content/01-property/passport.md` (для определения типа организации) + любые файлы, которые пользователь упомянул
- **Артефакт:** в зависимости от запроса (анализ — текстовый ответ в чате; если substantive — предложи `/insight` для сохранения)
- **Критерии:** ответ структурирован по шаблону (Ответ / Правовая база / Риски / Следующие шаги)

После ответа `legal` — если анализ >500 слов с выводами, предложи пользователю сохранить через `/insight`.
```

- [ ] **Step 2: finance.md**

```markdown
---
description: "Финансовый анализ через finance-агента — тарифы, бюджеты, КП, биллинг. Пример: /finance сравни три КП на обслуживание лифтов"
allowed-tools: Agent
---

Делегируй в субагент `finance`:

**Пользовательский запрос:** `$ARGUMENTS`

Передай:
- **Цель:** переформулируй запрос
- **Входы:** `content/01-property/passport.md`, `content/05-finance/tariffs.md`, `content/05-finance/budget/` (по применимости) + файлы, упомянутые пользователем
- **Артефакт:** анализ в чате; если расчёт >500 слов — предложи `/insight`
- **Критерии:** структурированный ответ (Резюме / Детали / Допущения / Рекомендации)

После ответа — при substantive-анализе предложи `/insight`.
```

- [ ] **Step 3: docs.md**

```markdown
---
description: "Создание документов через docs-агента — решения, протоколы, претензии. Пример: /docs создай решение правления о повышении тарифа"
allowed-tools: Agent
---

Делегируй в субагент `docs`:

**Пользовательский запрос:** `$ARGUMENTS`

Передай:
- **Цель:** какой документ создаём
- **Входы:** `content/07-legal/templates/` (для шаблона), `content/01-property/passport.md` (для типа организации), `content/03-board/actors.md` (для подписей)
- **Артефакт:** новый .md файл в правильной папке (см. spec §2.4)
- **Критерии:** frontmatter заполнен, именование корректное, ссылки на источники

После создания — покажи путь и summary.
```

- [ ] **Step 4: comms.md**

```markdown
---
description: "Текст для жителей/членов через comms-агента (использует skill infoinstyle). Пример: /comms напиши объявление об отключении воды"
allowed-tools: Agent, Skill
---

Делегируй в субагент `comms`:

**Пользовательский запрос:** `$ARGUMENTS`

Передай:
- **Цель:** какой текст создаём, для какого канала
- **Входы:** `content/01-property/passport.md` (тип организации — влияет на тон), `content/02-owners/communications/` (примеры предыдущих)
- **Артефакт:** новый .md в `content/02-owners/communications/YYYY-MM-DD_<тема>.md`
- **Критерии:** прошёл через skill `infoinstyle`, длина в рамках канала (стенд ≤300, email ≤800), есть заголовок/действие/контакт

После — покажи финальный текст и рекомендацию по каналу.
```

- [ ] **Step 5: research.md**

```markdown
---
description: "Поиск НПА, КП, кейсов через research-агента (MCP open-websearch). Пример: /research найди судебную практику по ст.158 ЖК РФ"
allowed-tools: Agent, "mcp__open-websearch__search", "mcp__open-websearch__fetchWebContent"
---

Делегируй в субагент `research`:

**Пользовательский запрос:** `$ARGUMENTS`

Передай:
- **Цель:** что искать
- **Входы:** `content/01-property/passport.md` (тип организации, регион)
- **Артефакт:** структурированный ответ с источниками и датой обращения
- **Критерии:** минимум 2 источника, указана дата обращения, выделены ключевые факты и противоречия

После — при substantive-материале предложи `/insight`.
```

- [ ] **Step 6: archivist.md**

```markdown
---
description: "Загрузить входящий документ (PDF/email/фото) через archivist-агента — создаст структурированный .md в правильной папке. Пример: /archivist обработай документ /path/to/scan.pdf"
allowed-tools: Agent
---

Делегируй в субагент `archivist`:

**Пользовательский запрос:** `$ARGUMENTS`

Передай:
- **Цель:** обработать документ, определить тип, разместить
- **Входы:** путь к документу (из `$ARGUMENTS`)
- **Артефакт:** новый .md в правильной папке content/, append в `content/03-board/log.md`
- **Критерии:** frontmatter заполнен, файл размещён по правилам из spec §2.4

После — путь, тип, summary, рекомендация по следующим шагам.
```

- [ ] **Step 7: analyst.md**

```markdown
---
description: "Кросс-доменный анализ через analyst-агента — сравнения, опции, SWOT. Пример: /analyst сравни 3 варианта замены лифтов"
allowed-tools: Agent
---

Делегируй в субагент `analyst`:

**Пользовательский запрос:** `$ARGUMENTS`

Передай:
- **Цель:** какой выбор/сравнение нужно
- **Входы:** `content/01-property/passport.md`, текущие договоры (`content/06-contracts/`), бюджет (`content/05-finance/budget/`)
- **Артефакт:** анализ со сравнительной таблицей и рекомендацией
- **Критерии:** ≥2 варианта, ≥3 параметра сравнения, одна конкретная рекомендация с обоснованием

После — при substantive-анализе предложи `/insight`.
```

- [ ] **Step 8: Commit**

```bash
git add .claude/plugins/project/commands/legal.md \
        .claude/plugins/project/commands/finance.md \
        .claude/plugins/project/commands/docs.md \
        .claude/plugins/project/commands/comms.md \
        .claude/plugins/project/commands/research.md \
        .claude/plugins/project/commands/archivist.md \
        .claude/plugins/project/commands/analyst.md
git commit -m "feat(commands): 7 agent-invoke commands (legal/finance/docs/comms/research/archivist/analyst)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 19: Создать 4 управленческих команды (status, delegate, weekly, review)

**Files:**
- Create: `.claude/plugins/project/commands/status.md`
- Create: `.claude/plugins/project/commands/delegate.md`
- Create: `.claude/plugins/project/commands/weekly.md`
- Create: `.claude/plugins/project/commands/review.md`

Эти команды исполняются в main-context через `chair`-агента (он Opus, в main).

- [ ] **Step 1: status.md**

```markdown
---
description: "Текущий статус товарищества — задачи, проекты, просрочки. Запускается chair-агентом."
allowed-tools: Read, Glob, Grep, Bash(git:*), Edit, TodoWrite
---

Ты chair-агент. Выполни рабочий цикл `/status` согласно `.claude/plugins/project/agents/chair-agent.md`:

1. Прочитай `content/03-board/manager-state.md` — вспомни прошлую сессию
2. Glob `content/03-board/tasks/*.md` (исключая `_index.md`)
3. Для каждой задачи — frontmatter (первые 30 строк)
4. Сгруппируй: по assignee / просрочки / блокированные
5. Активные проекты (`content/08-projects/_active.md`); для каждого через `git log -1` определи «тишину»
6. Сравни с `manager_state.last_status_check`
7. Сформируй отчёт по формату из chair-agent.md
8. Обнови `manager-state.md`

Вход: `$ARGUMENTS` (опц. — фильтр, например `/status проекты` или `/status просрочки`).
```

- [ ] **Step 2: delegate.md**

```markdown
---
description: "Создать задачу + назначить исполнителя. Запускается chair-агентом. Пример: /delegate проверить акт КС-2 от Альянслифтсервис"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), TodoWrite
---

Ты chair-агент. Выполни рабочий цикл `/delegate`:

1. Спроси (если не передано в `$ARGUMENTS`): задача, дедлайн, приоритет
2. Routing по `content/03-board/actors.md` — предложи assignee
3. Дедуп: grep по `content/03-board/tasks/` для open/in_progress/blocked задач
4. ID: `T-YYYY-MMDD-NN`
5. Превью frontmatter, жди y/n/edit
6. На y — создай `content/03-board/tasks/YYYY-MM-DD_task_<slug>.md`
7. Append в `content/03-board/log.md`
8. Верни ID и путь

Вход: `$ARGUMENTS` (опц. — описание задачи).
```

- [ ] **Step 3: weekly.md**

```markdown
---
description: "Еженедельный обзор — что сделано за 7 дней, что просрочено, что на следующую неделю. Запускается chair."
allowed-tools: Read, Glob, Grep, Bash(git:*), Edit, TodoWrite
---

Ты chair-агент. Сформируй еженедельный обзор:

1. Задачи с движением за 7 дней (через git log + status в frontmatter): закрытые / открытые / новые
2. Просрочки на сегодня (`due < today() AND status not in [done, cancelled]`)
3. Проекты с движением за 7 дней (`git log --since="7 days ago" content/08-projects/<project>/`)
4. Insights, созданные за неделю (`content/*/insights/` + `git log --since`)
5. Предложения на следующую неделю (приоритеты, что закрыть, что начать)

Сохрани результат в `content/03-board/weekly/YYYY-MM-DD_weekly.md`.

Вход: `$ARGUMENTS` (опц. — конкретная дата окончания периода).
```

- [ ] **Step 4: review.md**

```markdown
---
description: "Ревью контента перед merge private→public. Проверяет валидность Gramax, ПДн, актуальность."
allowed-tools: Read, Glob, Grep, Bash, Edit
---

Ты chair-агент. Выполни ревью контента перед публикацией:

1. **Валидация Gramax:** `uv run scripts/validate-content.py` — должно быть exit 0
2. **Проверка ПДн:** grep по `content/` на потенциальные ПДн (паспортные данные, полные ФИО + контакты, СНИЛС). Список ниже:
   - `\d{4}\s*\d{6}` — серия+номер паспорта
   - `\+7[\d\-\(\)\s]{10,}` — номера телефонов (только в публичных каналах — это ОК для контактов правления, но не для собственников без согласия)
   - `[\w.-]+@[\w.-]+\.\w+` — email-ы (то же, что и телефоны)
3. **Свежесть НПА:** grep на упоминания НПА в `content/07-legal/`. Если ссылка на редакцию >2 лет — флаг.
4. **Drift-check:** при изменении `content/01-property/passport.md` — проверь, что зависимые downstream (`06-contracts/`, `04-general-meeting/procedures.md`) актуализированы. См. правила в `CLAUDE.md` (Two-way sync).
5. **Отчёт:** список найденных проблем, что блокирует merge, что warning.

После — рекомендуй: можно ли merge, или какие исправления нужны.

Вход: `$ARGUMENTS` (опц. — путь конкретного файла/папки для проверки).
```

- [ ] **Step 5: Commit**

```bash
git add .claude/plugins/project/commands/status.md \
        .claude/plugins/project/commands/delegate.md \
        .claude/plugins/project/commands/weekly.md \
        .claude/plugins/project/commands/review.md
git commit -m "feat(commands): 4 management commands (status/delegate/weekly/review)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 20: Создать 7 документных команд

**Files:**
- Create: `.claude/plugins/project/commands/decision.md`
- Create: `.claude/plugins/project/commands/protocol.md`
- Create: `.claude/plugins/project/commands/claim.md`
- Create: `.claude/plugins/project/commands/contract.md`
- Create: `.claude/plugins/project/commands/message.md`
- Create: `.claude/plugins/project/commands/ingest.md`
- Create: `.claude/plugins/project/commands/insight.md`

- [ ] **Step 1: decision.md**

```markdown
---
description: "Создать решение правления. Делегирует docs-агенту с контекстом из правления и тип-специфики."
allowed-tools: Agent
---

Создай решение правления через `docs`-агент:

**Пользовательский запрос:** `$ARGUMENTS`

Передай:
- **Цель:** решение правления по вопросу `$ARGUMENTS`
- **Входы:**
  - `content/07-legal/templates/decision.md` (если есть; если нет — docs создаст с нуля)
  - `content/03-board/actors.md` (для подписей)
  - `content/01-property/passport.md` (для типа организации — правовое основание разное)
- **Артефакт:** `content/03-board/decisions/YYYY-MM-DD_decision_NN_<краткое-описание>.md`
- **Критерии:** frontmatter (Тип документа: Решение, Категория: Правление, Статус: Действует), правовое основание соответствует типу (ЖК РФ для МКД / ФЗ-217 для СНТ), указаны участники и единогласие/большинство

После создания — append в `content/03-board/log.md`.
```

- [ ] **Step 2: protocol.md**

```markdown
---
description: "Создать протокол общего собрания (ОСС для МКД / ОС для СНТ) или заседания правления. Делегирует docs."
allowed-tools: Agent
---

Создай протокол через `docs`-агент:

**Пользовательский запрос:** `$ARGUMENTS` (формат: `--type=general-meeting|board <дата> <повестка>`)

Передай:
- **Цель:** протокол общего собрания или заседания правления
- **Входы:**
  - `content/07-legal/templates/protocol-<type>.md` (если есть)
  - `content/01-property/passport.md` (тип организации)
  - `content/02-owners/registry.md` (для кворума ОСС/ОС)
  - `content/04-general-meeting/procedures.md` (порядок проведения по типу)
- **Артефакт:**
  - Для общего собрания: `content/04-general-meeting/YYYY/YYYY-MM-DD_protocol.md`
  - Для заседания правления: `content/03-board/meetings/YYYY-MM-DD_meeting.md`
- **Критерии:** правовая база соответствует типу (ЖК РФ ст.44-48 для МКД ОСС / ФЗ-217 ст.17-21 для СНТ ОС), кворум посчитан, бюллетени учтены (если заочное)
```

- [ ] **Step 3: claim.md**

```markdown
---
description: "Подготовить претензию (к УК, РСО, подрядчику, органу). Делегирует legal + docs параллельно."
allowed-tools: Agent
---

Подготовь претензию через цепочку `legal` → `docs`:

**Пользовательский запрос:** `$ARGUMENTS`

Шаг 1: Делегируй `legal` для правовой позиции:
- **Цель:** правовая позиция для претензии по `$ARGUMENTS`
- **Входы:** соответствующий договор (если есть, найди в `content/06-contracts/`), `content/01-property/passport.md`
- **Артефакт:** текстовый ответ с правовой базой и требованиями
- **Критерии:** конкретные нарушенные пункты договора/НПА, конкретные требования

Шаг 2: Передай результат `legal` → `docs` для оформления:
- **Цель:** оформить претензию в шаблон
- **Входы:** правовая позиция от `legal`, шаблон из `content/07-legal/templates/claim.md` (если есть)
- **Артефакт:** `content/07-legal/claims/YYYY-MM-DD_to_<recipient>_<тема>.md`
- **Критерии:** реквизиты сторон, чёткие требования, срок ответа (10 дней по умолчанию, или из договора), правовое основание

После — append в `content/03-board/log.md`.
```

- [ ] **Step 4: contract.md**

```markdown
---
description: "Проанализировать договор (юр.условия + финансовые). Параллельно legal + finance."
allowed-tools: Agent
---

Проанализируй договор через параллельный вызов `legal` + `finance`:

**Пользовательский запрос:** `$ARGUMENTS` (путь к договору или название контрагента)

1. Найди договор: если в `$ARGUMENTS` путь — используй; иначе Grep по `content/06-contracts/` + по `_files/` (если есть)
2. Параллельно через `dispatching-parallel-agents` запусти:
   - **legal:** "Проанализируй договор `<path>` на юр.риски, невыгодные пункты, соответствие ЖК РФ/ФЗ-217 (выясни тип из `content/01-property/passport.md`)"
   - **finance:** "Проанализируй договор `<path>` на финансовые параметры — тариф, индексация, штрафы, скрытые расходы; сравни со среднерыночным"
3. Объедини результаты, сформируй итоговый отчёт (Юр.часть / Финансовая часть / Общий вывод / Рекомендации)
4. Сохрани при substantive-результате через `/insight` → `content/07-legal/insights/` или `content/06-contracts/<vendor>/analysis_YYYY-MM-DD.md`
```

- [ ] **Step 5: message.md**

```markdown
---
description: "Подготовить сообщение жителям/членам товарищества. Делегирует comms (использует skill infoinstyle)."
allowed-tools: Agent
---

Подготовь сообщение через `comms`-агент:

**Пользовательский запрос:** `$ARGUMENTS` (повод + канал, например: `отключение воды 15 мая, канал: чат+стенд`)

Передай:
- **Цель:** текст для жителей/членов
- **Входы:** `content/01-property/passport.md` (тип — влияет на тон), `content/02-owners/communications/` (примеры)
- **Артефакт:** `content/02-owners/communications/YYYY-MM-DD_<тема>.md` (+ если канал «email» — preview-строка)
- **Критерии:** прошёл skill `infoinstyle`, длина по каналу, заголовок-суть-действие-контакт
```

- [ ] **Step 6: ingest.md**

```markdown
---
description: "Загрузить входящий документ (PDF, email, фото) в vault. Делегирует archivist."
allowed-tools: Agent
---

Загрузи документ через `archivist`-агент:

**Пользовательский запрос:** `$ARGUMENTS` (путь к PDF/email или вставленный текст)

Передай:
- **Цель:** ingest документа, классификация, размещение
- **Входы:** документ из `$ARGUMENTS`
- **Артефакт:** новый .md в правильной папке content/ + append в `content/03-board/log.md`
- **Критерии:** frontmatter заполнен (Тип документа/Категория/Статус), путь по правилам спецификации §2.4

После — путь, тип, summary, рекомендация (например: «передать `/legal` на анализ»).
```

- [ ] **Step 7: insight.md**

```markdown
---
description: "Сохранить ключевой substantive-анализ (>500 слов с выводами). Куда — определяется по теме."
allowed-tools: Read, Write, Edit, Glob, Grep
---

Сохрани substantive-анализ из текущего разговора:

**Пользовательский запрос:** `$ARGUMENTS` (опц. — заголовок инсайта; если не передан — спроси)

1. **Определи категорию** (по теме разговора):
   - Юридический → `content/07-legal/insights/`
   - Финансовый → `content/05-finance/insights/`
   - Проектный → `content/08-projects/<project>/insights/` (если в контексте проекта; уточни если неоднозначно)
2. **Имя файла:** `YYYY-MM-DD_insight_<slug>.md`
3. **Структура:**

```markdown
---
properties:
  - name: Тип документа
    value: [Insight]
  - name: Категория
    value: [<категория>]
  - name: Статус
    value: [Действует]
date: YYYY-MM-DD
tags: [...]
---

# <Заголовок>

## Контекст
[Что обсуждали, почему вопрос важен]

## Ключевые выводы
- Вывод 1
- Вывод 2

## Источники
- ...

## Рекомендации
- ...
```

4. Append в `content/03-board/log.md`: `- YYYY-MM-DD HH:MM — /insight — <заголовок> → <путь>`
5. Верни путь созданного файла
```

- [ ] **Step 8: Commit**

```bash
git add .claude/plugins/project/commands/decision.md \
        .claude/plugins/project/commands/protocol.md \
        .claude/plugins/project/commands/claim.md \
        .claude/plugins/project/commands/contract.md \
        .claude/plugins/project/commands/message.md \
        .claude/plugins/project/commands/ingest.md \
        .claude/plugins/project/commands/insight.md
git commit -m "feat(commands): 7 document commands (decision/protocol/claim/contract/message/ingest/insight)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 21: Переписать /init команду под ТСН

**Files:**
- Modify: `.claude/plugins/project/commands/init.md`

- [ ] **Step 1: Прочитай текущий init.md (для понимания структуры)**

```bash
cat .claude/plugins/project/commands/init.md | head -40
```

- [ ] **Step 2: Полная замена содержимого init.md**

```markdown
---
description: "Инициализация ТСН (МКД/СНТ/ОНТ/ЖСК) из шаблона. Phase 1 — bash (плейсхолдеры, wipe .git, MCP install). Phase 2 — интервью по 8 темам с TODO-маркерами на пропусках. Пример: /init Лайф-2"
allowed-tools: Read, Edit, Write, Bash(git:*), Bash(bash scripts/init.sh:*), Bash(ls:*), Bash(grep:*)
---

Ты выполняешь первичную инициализацию ТСН из шаблона `tsn-assistant`. Работа делится на две фазы.

## Задача

Пользователь передал: `$ARGUMENTS`

Цель — превратить шаблон в работающий vault конкретного товарищества:
1. Заполнить плейсхолдеры (`{{TSN_NAME}}`, `{{TSN_CODE}}`, `{{TSN_DESCRIPTION}}`, `{{TSN_ADDRESS}}`, `{{CHAIR_NAME}}`, `{{EDITOR_EMAIL}}`)
2. Wipe `.git`, initial commit с трассировкой
3. Опционально установить новый origin
4. Заполнить или явно отметить TODO-маркерами project-specific данные

## Алгоритм

### Шаг 0. Идемпотентность

Прочитай `CLAUDE.md`. Если нет ни `{{TSN_NAME}}`, ни `TODO(/init)` — проект полностью инициализирован, сообщи и выйди.

Если есть `{{TSN_NAME}}` → Фаза 1. Если плейсхолдеры заменены, но есть `<!-- TODO(/init): ... -->` → Фаза 2.

### Шаг 0.5. Подтверждение wipe

Покажи историю:

```bash
git log --oneline -10
```

Спроси:
> «Это история шаблона. После init она будет удалена (wipe `.git` + initial commit с трассировкой). Продолжить? (yes/no)»

На отрицательный — остановись, предложи backup.

### Фаза 1. Bash-механика

1. **Собери параметры** (если не переданы в `$ARGUMENTS`, спроси по очереди):
   - `TSN_NAME` — название ("ТСН Лайф 2", "СНТ Заря")
   - `TSN_CODE` — код Gramax (UPPERCASE, без пробелов; например "TSN-LIFE-2", "SNT-ZARYA")
   - `TSN_DESCRIPTION` — короткое описание для шапки Gramax
   - `TSN_ADDRESS` — полный адрес ("Москва, ул. Чистова д.16 к.2", "Московская обл., Раменский р-н, СНТ Заря")
   - `CHAIR_NAME` — ФИО председателя/и.о. ("Иванов Иван Иванович")
   - `EDITOR_EMAIL` — email редактора Gramax
   - `GIT_REMOTE_URL` — URL нового origin. **Не должен** содержать `tsn-assistant`/`project-template`. Если нет URL — пусто.

2. **Запусти `scripts/init.sh`:**

```bash
bash scripts/init.sh "$TSN_NAME" "$TSN_CODE" "$TSN_DESCRIPTION" "$TSN_ADDRESS" "$CHAIR_NAME" "$EDITOR_EMAIL" "$GIT_REMOTE_URL"
```

Скрипт:
- Подставит плейсхолдеры в `CLAUDE.md`, `AGENTS.md`, `README.md`, `content/.doc-root.yaml`, `content/_index.md`, `content/01-property/passport.md`, `content/03-board/actors.md`
- Wipe `.git`, `git init -b main`, initial commit с `Template: <url>@<sha>`, ветка `private`
- Скопирует `.env.example` → `.env`
- Зарегистрирует MCP-сервер `open-websearch` (user-scope, идемпотентно)

3. **Верифицируй (после init.sh):**
   - `grep -RE '{{TSN_(NAME|CODE|DESCRIPTION|ADDRESS)}}|{{CHAIR_NAME}}|{{EDITOR_EMAIL}}' CLAUDE.md AGENTS.md README.md content/` — пусто
   - `git log --oneline -1` — initial commit с `Template:`
   - `git branch -a` — `main` + `private`
   - `uv run scripts/validate-content.py` — exit 0
   - `claude mcp list 2>/dev/null | grep -q '^open-websearch:'` — true (или warning)

### Фаза 2. Интервью

По одному вопросу. На каждый ответ — `Edit` соответствующего блока/файла. На skip — TODO-маркер остаётся.

| # | Тема | Вопрос | Куда пишем |
|---|------|--------|------------|
| 1 | Тип организации | "Тип товарищества: [a] МКД (ТСЖ/ЖСК) [b] СНТ [c] ОНТ [d] другое" | `CLAUDE.md` (контекст), `content/01-property/passport.md` |
| 2 | Регион | "Регион/субъект РФ (важно для НПА): Москва / СПб / Московская обл. / другой" | `CLAUDE.md`, `content/09-contacts/authorities.md` |
| 3 | Объект | "Сколько объектов: МКД — кол-во квартир + коммерческих; СНТ — кол-во участков" | `content/01-property/passport.md`, `content/01-property/premises/` |
| 4 | Площадь | "Общая площадь (м² для МКД; га для СНТ)" | `content/01-property/passport.md` |
| 5 | Год создания | "Год постройки дома / год образования товарищества" | `content/01-property/passport.md` |
| 6 | Состав правления | "Перечисли членов правления (ФИО + роль + контакт). Можно по одному." | `content/03-board/actors.md` |
| 7 | Подрядчики | "Ключевые обслуживающие организации (МКД: УК, РСО; СНТ: вывоз мусора, охрана, эл.сети). Опц." | `content/06-contracts/registry.md` |
| 8 | Особенности | "Кратко: специфика товарищества (споры, крупные проекты, особенности). Опц." | `CLAUDE.md` (Project-specific) |

После всех ответов — спроси, нужен ли commit правок Phase 2 (по умолчанию — нет, пользователь решит сам).

### Шаг финал. Отчёт

1. **Что сделано:** перечисли изменённые файлы, git-state
2. **Что осталось:** `grep -rn 'TODO(/init)' CLAUDE.md content/` — если пусто, поздравь
3. **Следующий шаг:** `/status` (увидеть стартовую картину) или `/delegate <первая задача>`

## Anti-scope

- НЕ вызывай `/legal`/`/finance`/`/docs` — нет input-артефактов
- НЕ делай commit Phase 2 без подтверждения
- НЕ создавай удалённый репозиторий
- НЕ создавать `README.md` в `content/` — Gramax индексирует только `_index.md`

## Контракт `.doc-root.yaml` (для верификации)

| Поле | Источник | Пример |
|------|----------|--------|
| `code` | `TSN_CODE` | `TSN-LIFE-2` |
| `title` | `TSN_NAME` | `ТСН Лайф 2` |
| `description` | `TSN_DESCRIPTION` | `База знаний правления ТСН Лайф 2` |
| `editors` | `EDITOR_EMAIL` | `chair@tsn-life-2.ru` |
```

- [ ] **Step 3: Commit**

```bash
git add .claude/plugins/project/commands/init.md
git commit -m "feat(commands): rewrite /init for ТСН (8-question Phase 2, drop profile system)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 22: Написать test-init-tsn.sh (failing test)

**Files:**
- Create: `scripts/test-init-tsn.sh`

- [ ] **Step 1: Создай тест**

```bash
#!/usr/bin/env bash
# test-init-tsn.sh — smoke-test полного init flow для ТСН.
# Запускает scripts/init.sh с фиктивными параметрами в временной директории,
# проверяет, что все плейсхолдеры заменены, content scaffold заполнен, validate-content.py зелёный.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap "rm -rf $TMPDIR" EXIT

echo "==> Setup: copying template to $TMPDIR"
# Копируем .git, content, scripts, .claude*, AGENTS.md, CLAUDE.md, README.md, .env.example
cp -R "$SCRIPT_DIR/.git" "$SCRIPT_DIR/.claude" "$SCRIPT_DIR/.claude-plugin" "$SCRIPT_DIR/content" "$SCRIPT_DIR/scripts" "$TMPDIR/"
cp "$SCRIPT_DIR/CLAUDE.md" "$SCRIPT_DIR/AGENTS.md" "$SCRIPT_DIR/README.md" "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.gitignore" "$TMPDIR/"

cd "$TMPDIR"

# Fix: убедимся что мы в git-репо (cp -R .git должно достаточно)
git status >/dev/null || { echo "FAIL: not a git repo after copy"; exit 1; }

echo "==> Run init.sh with test parameters"
INIT_SKIP_MCP=1 INIT_FORCE=1 INIT_SKIP_PROMPTS=1 \
  bash scripts/init.sh \
    "Тест ТСН" \
    "TEST-TSN" \
    "Тестовое товарищество" \
    "Москва, ул. Тестовая д.1" \
    "Тестов Тест Тестович" \
    "test@example.com" \
    ""  # пустой remote — should pass

echo "==> Verify: placeholders replaced"
LEFT=$(grep -RE '{{TSN_NAME}}|{{TSN_CODE}}|{{TSN_DESCRIPTION}}|{{TSN_ADDRESS}}|{{CHAIR_NAME}}|{{EDITOR_EMAIL}}' CLAUDE.md AGENTS.md README.md content/ 2>/dev/null || true)
if [[ -n "$LEFT" ]]; then
  echo "FAIL: placeholders remain:"
  echo "$LEFT"
  exit 1
fi

echo "==> Verify: critical files exist and contain TSN data"
test -f content/_index.md
test -f content/01-property/passport.md
test -f content/03-board/actors.md
test -f content/03-board/manager-state.md
test -f content/03-board/log.md
test -f content/.doc-root.yaml

grep -q "Тест ТСН" content/_index.md || { echo "FAIL: TSN_NAME not in content/_index.md"; exit 1; }
grep -q "TEST-TSN" content/.doc-root.yaml || { echo "FAIL: TSN_CODE not in .doc-root.yaml"; exit 1; }
grep -q "Москва, ул. Тестовая д.1" content/01-property/passport.md || { echo "FAIL: TSN_ADDRESS not in passport.md"; exit 1; }
grep -q "Тестов Тест Тестович" content/03-board/actors.md || { echo "FAIL: CHAIR_NAME not in actors.md"; exit 1; }
grep -q "test@example.com" content/.doc-root.yaml || { echo "FAIL: EDITOR_EMAIL not in .doc-root.yaml"; exit 1; }

echo "==> Verify: git state"
test "$(git rev-parse --abbrev-ref HEAD)" = "main"
git show-ref --verify --quiet refs/heads/private || { echo "FAIL: private branch missing"; exit 1; }
git log --oneline -1 | grep -q "Template:" || { echo "FAIL: traceability missing in initial commit"; exit 1; }

echo "==> Verify: validate-content.py passes"
uv run scripts/validate-content.py >/dev/null 2>&1 || { echo "FAIL: validate-content.py exit non-zero"; exit 1; }

echo "==> PASS: test-init-tsn"
```

- [ ] **Step 2: Сделай исполняемым**

```bash
chmod +x scripts/test-init-tsn.sh
```

- [ ] **Step 3: Запусти — должен УПАСТЬ (init.sh ещё под старую схему)**

```bash
bash scripts/test-init-tsn.sh
```

Expected: FAIL (потому что init.sh не знает про TSN_ADDRESS, CHAIR_NAME — пока не переписан). Зафиксируй какой именно step упал — это будет проверка после Task 23.

- [ ] **Step 4: Commit (failing test, по TDD)**

```bash
git add scripts/test-init-tsn.sh
git commit -m "test(init): add failing smoke test for TSN init flow (TDD)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 23: Переписать scripts/init.sh под ТСН

**Files:**
- Modify: `scripts/init.sh` (полная замена)

- [ ] **Step 1: Полная замена init.sh**

```bash
#!/usr/bin/env bash
# init.sh — первичная инициализация TSN-assistant из шаблона.
# Подставляет плейсхолдеры, wipe .git, initial commit, ветка private, MCP install.

set -euo pipefail

# ===== Prerequisites =====
check_prerequisites() {
  if ! command -v uv >/dev/null 2>&1; then
    echo "ERROR: 'uv' не найден в PATH." >&2
    echo "" >&2
    echo "Установите uv и перезапустите init.sh:" >&2
    echo "  brew install uv  (macOS)" >&2
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh  (macOS/Linux)" >&2
    echo "  https://docs.astral.sh/uv/getting-started/installation/" >&2
    exit 1
  fi
}

# ===== Helpers =====
replace_in_file() {
  local file="$1" placeholder="$2" value="$3"
  if [[ -f "$file" ]] && grep -q "$placeholder" "$file"; then
    sed -i.bak "s|$placeholder|$value|g" "$file"
    rm -f "$file.bak"
    echo "✓ replaced $placeholder in $file"
  fi
}

# ===== Main =====
check_prerequisites

# 1. Проверка: git-репо
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: not a git repository. Run 'git init' first." >&2
  exit 1
fi

# 2. Проверка: корень проекта
if [[ ! -f CLAUDE.md ]]; then
  echo "ERROR: run from project root (where CLAUDE.md is)." >&2
  exit 1
fi

# 3. Параметры (позиционные или интерактивно)
if [[ $# -ge 1 ]]; then TSN_NAME="$1"; else read -r -p "Название товарищества (TSN_NAME): " TSN_NAME; fi
if [[ -z "$TSN_NAME" ]]; then echo "ERROR: TSN_NAME cannot be empty." >&2; exit 1; fi
if [[ ! "$TSN_NAME" =~ ^[A-Za-zА-Яа-я0-9][A-Za-zА-Яа-я0-9\ \.\,_\-\«\»\"\']*$ ]]; then
  echo "ERROR: invalid TSN_NAME chars (got: '$TSN_NAME')" >&2; exit 1
fi

NAME_UPPER="$(echo "$TSN_NAME" | tr '[:lower:]' '[:upper:]' | tr ' ' '-' | tr -cd 'A-Za-z0-9\-')"
if [[ $# -ge 2 ]]; then TSN_CODE="$2"; else read -r -p "Код Gramax (TSN_CODE, UPPERCASE, например $NAME_UPPER): " TSN_CODE; fi
TSN_CODE="${TSN_CODE:-$NAME_UPPER}"

if [[ $# -ge 3 ]]; then TSN_DESCRIPTION="$3"; else read -r -p "Краткое описание каталога (TSN_DESCRIPTION): " TSN_DESCRIPTION; fi
TSN_DESCRIPTION="${TSN_DESCRIPTION:-База знаний правления $TSN_NAME}"

if [[ $# -ge 4 ]]; then TSN_ADDRESS="$4"; else read -r -p "Полный адрес (TSN_ADDRESS): " TSN_ADDRESS; fi
TSN_ADDRESS="${TSN_ADDRESS:-<!-- TODO(/init): адрес -->}"

if [[ $# -ge 5 ]]; then CHAIR_NAME="$5"; else read -r -p "ФИО председателя/и.о. (CHAIR_NAME): " CHAIR_NAME; fi
CHAIR_NAME="${CHAIR_NAME:-<!-- TODO(/init): председатель -->}"

if [[ $# -ge 6 ]]; then EDITOR_EMAIL="$6"; else read -r -p "Email редактора Gramax (EDITOR_EMAIL): " EDITOR_EMAIL; fi
EDITOR_EMAIL="${EDITOR_EMAIL:-editor@example.com}"

if [[ $# -ge 7 ]]; then GIT_REMOTE_URL="$7"; else read -r -p "URL нового origin (Enter — пропустить): " GIT_REMOTE_URL || GIT_REMOTE_URL=""; fi
GIT_REMOTE_URL="${GIT_REMOTE_URL:-}"

# 4. Защита от случайного push в репо шаблона
if [[ -n "$GIT_REMOTE_URL" ]]; then
  if [[ "$GIT_REMOTE_URL" =~ (tsn[-_]assistant|project[-_]template)(\.git)?/?$ ]]; then
    echo "ERROR: URL ведёт на репозиторий шаблона ('$GIT_REMOTE_URL')." >&2
    echo "  Создай отдельный репозиторий для своего товарищества и повтори init." >&2
    exit 1
  fi
fi

# 5. Capture traceability шаблона
TEMPLATE_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
TEMPLATE_URL="$(git config --get remote.origin.url 2>/dev/null || echo unknown)"

echo ""
echo "=== Подстановка плейсхолдеров ==="
# 6. Подстановка плейсхолдеров в корневые файлы + content/
ROOT_FILES=(CLAUDE.md AGENTS.md README.md)
for f in "${ROOT_FILES[@]}"; do
  replace_in_file "$f" '{{TSN_NAME}}'        "$TSN_NAME"
  replace_in_file "$f" '{{TSN_CODE}}'        "$TSN_CODE"
  replace_in_file "$f" '{{TSN_DESCRIPTION}}' "$TSN_DESCRIPTION"
  replace_in_file "$f" '{{TSN_ADDRESS}}'     "$TSN_ADDRESS"
  replace_in_file "$f" '{{CHAIR_NAME}}'      "$CHAIR_NAME"
  replace_in_file "$f" '{{EDITOR_EMAIL}}'    "$EDITOR_EMAIL"
done

# Для content/ — пройдёмся find'ом по всем .md/.yaml
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  replace_in_file "$f" '{{TSN_NAME}}'        "$TSN_NAME"
  replace_in_file "$f" '{{TSN_CODE}}'        "$TSN_CODE"
  replace_in_file "$f" '{{TSN_DESCRIPTION}}' "$TSN_DESCRIPTION"
  replace_in_file "$f" '{{TSN_ADDRESS}}'     "$TSN_ADDRESS"
  replace_in_file "$f" '{{CHAIR_NAME}}'      "$CHAIR_NAME"
  replace_in_file "$f" '{{EDITOR_EMAIL}}'    "$EDITOR_EMAIL"
done < <(find content -type f \( -name '*.md' -o -name '*.yaml' \) 2>/dev/null)

# 7. Validate
echo ""
echo "=== Валидация ==="
if [[ -f scripts/validate-content.py ]]; then
  uv run scripts/validate-content.py >/dev/null 2>&1 || {
    echo "WARNING: validate-content.py exit non-zero — проверь content/" >&2
  }
fi

# 8. Wipe .git + initial commit (или skip для тестов)
echo ""
echo "=== Git ==="
if [[ "${INIT_SKIP_GIT_RESET:-0}" == "1" ]]; then
  if ! git show-ref --verify --quiet refs/heads/private; then
    git branch private
    echo "✓ created branch 'private' (INIT_SKIP_GIT_RESET=1)"
  fi
else
  GIT_EMAIL="$(git config user.email 2>/dev/null || true)"
  GIT_NAME="$(git config user.name 2>/dev/null || true)"
  if [[ -z "$GIT_EMAIL" || -z "$GIT_NAME" ]]; then
    echo "ERROR: git config user.email и/или user.name не настроены." >&2
    echo "  git config --global user.email 'you@example.com'" >&2
    echo "  git config --global user.name  'Your Name'" >&2
    exit 1
  fi

  rm -rf .git
  git init -b main -q
  git add -A
  git commit -q \
    -m "Initial commit from tsn-assistant template" \
    -m "Template: ${TEMPLATE_URL}@${TEMPLATE_SHA}" \
    -m "Initialized as: ${TSN_NAME} (${TSN_CODE})"
  git branch private
  echo "✓ wiped .git, created initial commit (Template: ${TEMPLATE_URL}@${TEMPLATE_SHA})"
  echo "✓ created branches 'main' and 'private'"
fi

# 9. Origin (опц.)
if [[ -n "$GIT_REMOTE_URL" ]]; then
  if git remote | grep -q '^origin$'; then
    git remote set-url origin "$GIT_REMOTE_URL"
  else
    git remote add origin "$GIT_REMOTE_URL"
  fi
  echo "✓ origin set to $GIT_REMOTE_URL"
else
  echo "WARNING: origin не настроен. До 'git remote add origin <url>' любой push провалится."
fi

# 10. .env
if [[ -f .env.example ]] && [[ ! -f .env ]]; then
  cp .env.example .env
  echo "✓ created .env (заполни секреты при необходимости)"
fi

# 11. MCP install (open-websearch, user-scope)
echo ""
echo "=== MCP ==="
if [[ "${INIT_SKIP_MCP:-0}" == "1" ]]; then
  echo "↷ skipping MCP install (INIT_SKIP_MCP=1)"
elif ! command -v claude >/dev/null 2>&1; then
  echo "WARNING: CLI 'claude' не найден в PATH — пропускаю установку open-websearch."
  echo "  Установи Claude Code и выполни вручную:"
  echo "    claude mcp add -s user -t stdio open-websearch \\"
  echo "      --env MODE=stdio DEFAULT_SEARCH_ENGINE=duckduckgo \\"
  echo "      ALLOWED_SEARCH_ENGINES=duckduckgo,bing,exa \\"
  echo "      -- npx open-websearch@latest"
elif claude mcp list 2>/dev/null | grep -qE '^open-websearch:'; then
  echo "✓ MCP open-websearch уже зарегистрирован (skip)"
else
  if claude mcp add -s user -t stdio open-websearch \
      --env MODE=stdio DEFAULT_SEARCH_ENGINE=duckduckgo ALLOWED_SEARCH_ENGINES=duckduckgo,bing,exa \
      -- npx open-websearch@latest >/dev/null 2>&1; then
    echo "✓ установлен MCP open-websearch (user-scope)"
  else
    echo "WARNING: не удалось зарегистрировать open-websearch — research-агент останется на WebFetch/WebSearch."
  fi
fi

# 12. Подсказка
echo ""
echo "Готово (Phase 1). Следующие шаги:"
echo "  1. Открой репо в Claude Code и выполни /init — Phase 2 (интервью)."
echo "  2. /status — увидеть стартовую картину"
echo "  3. /delegate <первая задача>"
```

- [ ] **Step 2: Сделай исполняемым**

```bash
chmod +x scripts/init.sh
```

- [ ] **Step 3: Запусти тест — должен ПРОЙТИ**

```bash
bash scripts/test-init-tsn.sh
```

Expected: `==> PASS: test-init-tsn`.

Если падает — диагностируй:
- Какой step упал?
- Если "placeholders remain" — проверь, что в файле использован правильный плейсхолдер
- Если "validate-content.py" — посмотри его вывод, скорее всего отсутствует _index.md в каком-то разделе

- [ ] **Step 4: Commit**

```bash
git add scripts/init.sh
git commit -m "feat(init): rewrite init.sh for TSN (drop profile system, add ADDRESS/CHAIR params)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 24: Удалить или упростить scripts/_init_helpers.py

**Files:**
- Remove or simplify: `scripts/_init_helpers.py`

`_init_helpers.py` целиком зависел от profile-системы. После её удаления — ничего не используется. Удаляем целиком.

- [ ] **Step 1: Проверь, что никто его не использует**

```bash
grep -rn "_init_helpers" scripts/ .claude/ docs/ CLAUDE.md AGENTS.md README.md 2>/dev/null
```

Expected: пусто (после Task 23 переписан init.sh, теперь не вызывает _init_helpers).

- [ ] **Step 2: Удали**

```bash
git rm scripts/_init_helpers.py
```

- [ ] **Step 3: Commit**

```bash
git commit -m "refactor(scripts): drop _init_helpers.py (profile-only logic)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 25: Адаптировать test-template.sh, удалить нерелевантные тесты

**Files:**
- Modify: `scripts/test-template.sh`
- Inspect: `scripts/tests/` — что осталось после Task 1

- [ ] **Step 1: Прочитай текущий test-template.sh**

```bash
cat scripts/test-template.sh
```

- [ ] **Step 2: Адаптируй**

Замени любые проверки профильной системы (`docs/overlays/profiles`, `apply-overlay.sh`, `_resolve_agents`) на:
- Запуск `bash scripts/test-init-tsn.sh` (smoke test)
- Запуск `uv run scripts/validate-content.py`
- (опц.) проверка наличия 8 агентов и 17 команд

Минимальная версия:

```bash
#!/usr/bin/env bash
# test-template.sh — meta-test шаблона: запускает все основные тесты.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "==> Test: validate-content"
bash scripts/test-validate-content.sh

echo "==> Test: init flow (TSN smoke)"
bash scripts/test-init-tsn.sh

echo "==> Test: agents и commands counts"
AGENTS_COUNT=$(ls .claude/plugins/project/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
COMMANDS_COUNT=$(ls .claude/plugins/project/commands/*.md 2>/dev/null | wc -l | tr -d ' ')
[[ "$AGENTS_COUNT" -eq 8 ]] || { echo "FAIL: expected 8 agents, got $AGENTS_COUNT"; exit 1; }
[[ "$COMMANDS_COUNT" -eq 19 ]] || { echo "FAIL: expected 19 commands (init + 18 others), got $COMMANDS_COUNT"; exit 1; }

# Note: 19 commands = init + 7 agent-invokes + 4 management + 7 document
# = 1 + 7 + 4 + 7 = 19

echo "==> PASS: test-template"
```

- [ ] **Step 3: Проверь scripts/tests/ — удали нерелевантное**

```bash
ls scripts/tests/ 2>/dev/null
```

Если есть тесты профильной системы (например, `test_apply_overlay.py`) — удали через `git rm`.

- [ ] **Step 4: Запусти test-template.sh**

```bash
bash scripts/test-template.sh
```

Expected: `==> PASS: test-template`.

- [ ] **Step 5: Commit**

```bash
git add scripts/test-template.sh
[[ -n "$(git status --porcelain scripts/tests/)" ]] && git add scripts/tests/
git commit -m "test: adapt test-template.sh for TSN (drop profile checks, add init smoke)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 26: Переписать CLAUDE.md под ТСН

**Files:**
- Modify: `CLAUDE.md` (полная замена)

- [ ] **Step 1: Полная замена CLAUDE.md**

```markdown
# {{TSN_NAME}} — AI-ассистент правления

Работаешь в Claude Code как **chair (виртуальный председатель/оркестратор)**, main-context, Opus. Substantive-работа делегируется специализированным субагентам через slash-команды.

## Контекст товарищества

- **Название:** {{TSN_NAME}}
- **Адрес:** {{TSN_ADDRESS}}
- **Председатель/и.о.:** {{CHAIR_NAME}}
- **Тип организации:** <!-- TODO(/init): МКД (ТСЖ/ЖСК) / СНТ / ОНТ / другое -->
- **Регион:** <!-- TODO(/init): для НПА -->

Полные характеристики — в `content/01-property/passport.md`.

## Карта команды

| Команда | Роль | Где исполняется |
|---------|------|----------------|
| `chair` | Координатор/оркестратор (виртуальный председатель) | main (Opus) |
| `/legal` | Юрист (ЖК РФ для МКД / ФЗ-217 для СНТ) | subagent (Sonnet) |
| `/finance` | Финансист (тарифы/взносы, бюджет, биллинг) | subagent (Sonnet) |
| `/docs` | Документовед (решения, протоколы, претензии) | subagent (Sonnet) |
| `/comms` | Коммуникатор (тексты жителям/членам) | subagent (Sonnet) |
| `/research` | Исследователь (НПА, КП, кейсы) | subagent (Sonnet) |
| `/archivist` | Архивариус (ingest PDF/email) | subagent (Sonnet) |
| `/analyst` | Стратегический аналитик (сравнения, опции) | subagent (Sonnet) |

Полная матрица + контракт вызова — в **AGENTS.md**.

## Каталог содержимого

`content/` — Gramax-каталог, 10 разделов:

1. `01-property/` — паспорт объекта, помещения/участки, оборудование
2. `02-owners/` — реестр, обращения, рассылки
3. `03-board/` — правление: состав, решения, протоколы, задачи, журнал
4. `04-general-meeting/` — общее собрание (ОСС для МКД / ОС для СНТ)
5. `05-finance/` — тарифы/взносы, бюджет, отчёты, фин.анализы
6. `06-contracts/` — договоры (УК, РСО, обслуживание)
7. `07-legal/` — шаблоны, претензии, юр.анализы
8. `08-projects/` — проекты, бэклог
9. `09-contacts/` — органы власти
10. `10-archive/` — архив

## Подключённые плагины

- **gramax@ai-assistants** — `gramax:writer`, `gramax:comments-read`, `gramax:comments-write`
- **superpowers@claude-plugins-official** — `brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development`, `verification-before-completion` и др.
- **project@local** — 8 агентов (chair/legal/finance/docs/comms/research/archivist/analyst), 19 команд, скиллы `infoinstyle`, `correspondence-2`

### MCP-серверы

- **`open-websearch`** — поисковик по умолчанию для `research`-агента (DuckDuckGo + Bing + Exa). Регистрируется на `/init`, user-scope.

## Поток работы

1. Запрос → `chair` оркестрирует, делегирует субагенту через `Agent` tool
2. Substantive-результат от субагента → `chair` возвращает пользователю с резюме
3. Документы создаются через `/decision`, `/protocol`, `/claim`, `/contract`, `/message`, `/ingest`, `/insight`
4. Задачи трекаются в `content/03-board/tasks/`
5. Регулярно: `/status` (текущий день), `/weekly` (неделя), `/review` (перед публикацией)

Ветвление: `private` — рабочая ветка, все правки. `main` — стабильная (для возможной публикации).

## Режим работы

Практический помощник правления товарищества. Задачи: документооборот, финансовый анализ, юридическая поддержка, коммуникации с жителями/членами, организация общего собрания, договорная работа.

**Приоритет:** решение силами правления (0–500 руб.) > внешний подрядчик. При рекомендациях всегда показывай оба варианта.

## Протокол работы

1. **Уточни** — что именно нужно, контекст
2. **Сформулируй** — задачу чётко
3. **Предложи варианты** — минимум 2-3 с расчётом стоимости
4. **Рекомендуй** — конкретное решение с обоснованием

### Самопроверка перед ответом

- Не выдаю предположения за факты?
- Учёл контекст товарищества (тип, регион, актуальные НПА на 2026)?
- Указал риски и альтернативы?
- Есть конкретные следующие шаги?

## Правила

1. **Язык:** русский. Содержимое .md — на русском (рабочий язык).
2. **Имена директорий и файлов — английский kebab-case.**
   - Директории: `03-board`, не `03_PRAVLENIE`
   - Файлы: `2026-04-21_decision_intercom.md`, не `2026-04-21_reshenie_domofon.md`
   - Wikilinks/markdown links — английские имена
   - Исключение: имена контрагентов (`alyansliftservice`, `proteya`) — оставлять как есть
3. **Frontmatter:** обязателен для всех `.md` в `content/`. Object-нотация:
   ```yaml
   properties:
     - name: Тип документа
       value: [Решение]
   ```
   Плоская нотация — устарела. Контракт типов — `.claude/docs/frontmatter-guide.md`.
4. **`_index.md`:** в каждой подпапке `content/`. **НЕТ** блока `properties` (это не статья, а раздел).
5. **ПДн:** не публиковать паспорта, ФИО + контакты собственников/членов без согласия, СНИЛС, пароли, токены. При получении — предупреждай.
6. **Экономия:** в каждой рекомендации показывай вариант «силами правления» (0-500 руб.) vs внешний подрядчик.
7. **Activity log:** при `/delegate`, `/ingest`, `/decision`, `/insight` — append в `content/03-board/log.md`.
8. **Триггеры insight:** при substantive-анализе (>500 слов с выводами/сравнениями) — предлагай `/insight`.
9. **Критическое мышление:** не соглашайся без анализа. Проверяй источники. Указывай противоречия.
10. **Проверяй даты НПА:** сейчас 2026 год; ЖК РФ и ФЗ-217 имели редакции в 2024-2025.
11. **Границы экспертизы:** уголовные дела → адвокат, налоги → консультант, экспертиза оборудования → инженер, трудовые споры → юрист.
12. **Файлы:** не удалять/перезаписывать/перемещать без подтверждения.
13. **Тип организации определяет терминологию:** для СНТ — "члены", "участки", "взносы", ФЗ-217; для МКД — "собственники", "квартиры", "тарифы", ЖК РФ. Читай тип из `content/01-property/passport.md`.

## Two-way sync (drift_pairs)

При расхождении нижестоящего слоя с вышестоящим — сначала обновляется вышестоящий слой.

| Upstream | Downstream | Причина |
|----------|------------|---------|
| `content/01-property/passport.md` | `content/06-contracts/*` | Договоры зависят от характеристик объекта (площадь, помещения/участки, тип организации) |
| `content/01-property/passport.md` | `content/04-general-meeting/procedures.md` | Процедуры ОС зависят от типа (ЖК РФ vs ФЗ-217) |
| `content/03-board/decisions/*` | `content/08-projects/*` | Исполнение решений через проекты |
| `content/06-contracts/*` | `content/07-legal/claims/*` | Претензии должны соответствовать актуальным договорам |
| `content/05-finance/tariffs.md` | `content/05-finance/budget/*` | Бюджет считается от актуальных тарифов/взносов |

Bypass для hotfix: trailer `skip-drift: hotfix — <описание>` в commit message.

## Когда какой скилл звать

| Ситуация | Скилл |
|----------|-------|
| Создание/редактирование статьи Gramax | `gramax:writer` |
| Чтение/ответ на комментарии Gramax | `gramax:comments-read`, `gramax:comments-write` |
| Многошаговая задача (фича, рефакторинг проекта) | `superpowers:brainstorming` → `writing-plans` → `executing-plans` или `subagent-driven-development` |
| Любой баг/непонятное поведение | `superpowers:systematic-debugging` |
| Адаптация текста под инфостиль | `infoinstyle` |
| Деловая переписка | `correspondence-2` |
| Перед claim'ом «готово» | `superpowers:verification-before-completion` |

## Красные линии

- Расхождение нижестоящего слоя с вышестоящим без обновления upstream (или без `skip-drift:` trailer) — блокер для `/review`
- НЕ публиковать секреты (`.env`, токены, API-ключи, credentials)
- НЕ публиковать ПДн (паспорта, контакты собственников/членов без согласия)
- НЕ менять `.doc-root.yaml` и `.gramax/` без согласования
- НЕ создавать статьи в `content/` без обязательных properties (см. `.doc-root.yaml`)
- Tests/линтеры (если в проекте есть) — зелёные перед commit

### Project-specific

<!-- TODO(/init): особенности данного товарищества (споры, проекты, специфика) -->

## Справочные пути

- TSN16k2 vault (production reference, Москва, МКД): `/Users/mdemyanov/Documents/TSN16k2/` (если есть на машине)
- Документация платформы Gramax: <!-- TODO(/init): URL -->

## Self-improvement

- `docs/lessons-learned.md` — append-only журнал
- Субагенты сохраняют находки в auto-memory (`reference`, `project`, `feedback`)
- `/review` читает lessons + memory и предлагает обновления CLAUDE.md / промтов агентов
```

- [ ] **Step 2: Verify validate-content проходит**

```bash
uv run scripts/validate-content.py
```

Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "feat(docs): rewrite CLAUDE.md for TSN context

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 27: Переписать AGENTS.md под ТСН

**Files:**
- Modify: `AGENTS.md` (полная замена)

- [ ] **Step 1: Полная замена**

```markdown
# AGENTS.md — {{TSN_NAME}}

Каталог ролей, контракт вызова субагентов и self-improvement для AI-команды товарищества.

## Каталог ролей

| Имя | Описание | Где исполняется | Модель | Промпт | Slash-команды |
|-----|----------|-----------------|--------|--------|---------------|
| `chair` | Виртуальный председатель / оркестратор | main | Opus | (main, не subagent) | (orchestrator) |
| `legal` | Юр.анализ (ЖК РФ / ФЗ-217 / ГК РФ) | subagent | Sonnet | `.claude/plugins/project/agents/legal-agent.md` | `/legal` |
| `finance` | Тарифы/взносы, бюджет, биллинг, КП | subagent | Sonnet | `.claude/plugins/project/agents/finance-agent.md` | `/finance` |
| `docs` | Создание документов по шаблонам | subagent | Sonnet | `.claude/plugins/project/agents/docs-agent.md` | `/docs`, `/decision`, `/protocol`, `/claim` |
| `comms` | Тексты жителям/членам (skill infoinstyle) | subagent | Sonnet | `.claude/plugins/project/agents/comms-agent.md` | `/comms`, `/message` |
| `research` | Web-исследование (MCP open-websearch) | subagent | Sonnet | `.claude/plugins/project/agents/research-agent.md` | `/research` |
| `archivist` | Ingest PDF/email/фото | subagent | Sonnet | `.claude/plugins/project/agents/archivist-agent.md` | `/archivist`, `/ingest` |
| `analyst` | Кросс-доменный анализ, сравнения | subagent | Sonnet | `.claude/plugins/project/agents/analyst-agent.md` | `/analyst`, `/contract` |

**Почему так:** chair-координация в main-context (не раздувает контекст субагентов). Substantive-работа — в субагентах на Sonnet (экономия LLM-бюджета).

## Контракт вызова субагента

При запуске любой роли (через `/<command>` или `Agent` tool) передавай:

1. **Цель** — одной фразой
2. **Входы** — пути к контексту (passport, договор, ADR). Субагент сам прочитает.
3. **Артефакт** — какой файл должен появиться/измениться
4. **Критерии приёмки** — как проверить, что задача выполнена

Пример корректного prompt'а для `/legal`:

```
Цель: проанализировать договор с УК «Протея» на юр.риски и соответствие ЖК РФ.
Входы: content/06-contracts/uk/proteya_2024.md, content/01-property/passport.md
Артефакт: текстовый ответ в чате (Ответ / Правовая база / Риски / Следующие шаги). Если substantive — предложить /insight.
Критерии: указаны конкретные статьи ЖК РФ, выделены ≥3 риска, даны рекомендации по переговорам.
```

Субагент **не ищет контекст «вокруг»** — работает по явно переданному скопу.

(Полные промпты — в `.claude/plugins/project/agents/<role>-agent.md`.)

## Карта делегирования (для chair)

При запросе пользователя `chair` определяет тип задачи по ключевым словам и делегирует:

| Тип задачи | Субагент |
|-----------|----------|
| Договор, НПА, ЖК РФ, ФЗ-217, претензия, риски, законность | `legal` |
| Тариф, бюджет, смета, биллинг, экономия, КП, расчёт | `finance` |
| Создать решение / протокол / претензию / шаблон | `docs` |
| Текст жителям / объявление / рассылка / уведомление | `comms` |
| Найти НПА / актуальную редакцию / опыт других ТСН / КП | `research` |
| Загрузить PDF / письмо / фото / отсканированный документ | `archivist` |
| Сравнить варианты / выбрать УК / план проекта / SWOT | `analyst` |

## Поток работы

1. Пользователь → запрос → `chair`
2. `chair` определяет тип, выбирает субагент
3. `chair` передаёт контракт (цель, входы, артефакт, критерии)
4. Субагент работает, возвращает результат
5. `chair` представляет пользователю + предложение следующего шага
6. (опц.) Append в `content/03-board/log.md`

Параллельные стадии (например, `/contract` = `legal` + `finance` одновременно): через `superpowers:dispatching-parallel-agents`.

### Two-way sync

При расхождении нижестоящего слоя с вышестоящим — сначала обновляется вышестоящий. Детали и drift_pairs — в `CLAUDE.md` раздел «Two-way sync».

## Self-improvement

- `docs/lessons-learned.md` — append-only журнал
- Субагенты сохраняют находки в auto-memory (`reference`, `project`, `feedback`)
- `/review` читает lessons + memory и предлагает обновления `CLAUDE.md` / промтов агентов

## Красные линии (универсальные)

- НЕ публиковать секреты (`.env`, токены, API-ключи)
- НЕ публиковать ПДн (паспорта, ФИО + контакты собственников/членов без согласия)
- НЕ менять `.doc-root.yaml` и `.gramax/` без согласования
- НЕ создавать статьи в `content/` без обязательных properties
- НЕ принимать substantive-анализы от `legal`/`finance` без проверки актуальной редакции НПА (2026 год)
- НЕ путать МКД и СНТ — разные регуляторные базы (ЖК РФ vs ФЗ-217)
```

- [ ] **Step 2: Commit**

```bash
git add AGENTS.md
git commit -m "feat(docs): rewrite AGENTS.md (8 agents, TSN delegation map)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 28: Переписать README.md

**Files:**
- Modify: `README.md` (полная замена)

- [ ] **Step 1: Полная замена**

```markdown
# {{TSN_NAME}} — AI-ассистент правления

База знаний и AI-ассистент для управления товариществом собственников недвижимости (ТСЖ/МКД, СНТ, ОНТ, ЖСК).

## Prerequisites

Шаблон требует **[uv](https://docs.astral.sh/uv/)** — менеджер Python-окружений.

**macOS (Homebrew):**
```bash
brew install uv
```

**macOS / Linux (curl):**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Windows (WinGet):**
```powershell
winget install --id=astral-sh.uv -e
```

> Первый запуск `uv run` на новой машине занимает 5-15 сек (скачивает PyYAML).

## Быстрый старт

1. Клонируй: `git clone <url> tsn-assistant && cd tsn-assistant`
2. Открой в Claude Code: `claude`
3. `/init` — инициализация (название товарищества, адрес, состав правления...)
4. `/status` — увидеть стартовую картину
5. `/delegate <первая задача>` — делегировать

## Структура

| Путь | Назначение |
|------|------------|
| `content/` | Gramax-каталог: 10 разделов (объект, собственники, правление, ОС, финансы, договоры, юр., проекты, контакты, архив) |
| `.claude/plugins/project/agents/` | 8 AI-агентов (chair, legal, finance, docs, comms, research, archivist, analyst) |
| `.claude/plugins/project/commands/` | 19 slash-команд |
| `.claude/plugins/project/skills/` | Локальные скиллы (infoinstyle, correspondence-2) |
| `scripts/` | init, валидация, тесты |
| `docs/` | Документация шаблона |

## Команды (краткий список)

**Управленческие:**
- `/init` — инициализация
- `/status` — текущий статус
- `/delegate` — создать задачу
- `/weekly` — еженедельный обзор
- `/review` — ревью контента перед публикацией

**Документные:**
- `/decision` — решение правления
- `/protocol` — протокол общего собрания / заседания
- `/claim` — претензия
- `/contract` — анализ договора (legal + finance параллельно)
- `/message` — сообщение жителям/членам
- `/ingest` — загрузить PDF/email
- `/insight` — сохранить ключевой анализ

**Прямой вызов агента:**
- `/legal`, `/finance`, `/docs`, `/comms`, `/research`, `/archivist`, `/analyst`

## Документация

- `CLAUDE.md` — инструкции для Claude (роль, правила, протокол работы)
- `AGENTS.md` — каталог ролей и контракт вызова
- `docs/superpowers/specs/` — design-спецификации
- `docs/superpowers/plans/` — implementation-планы
- `docs/glossary.md` — глоссарий
- `docs/lessons-learned.md` — журнал уроков

## Тесты

```bash
bash scripts/test-template.sh   # запустит все
bash scripts/test-init-tsn.sh   # smoke-test init flow
bash scripts/test-validate-content.sh  # Gramax content
```

## Поддержка

Issue tracker: <!-- TODO: URL после публикации репо -->
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "feat(docs): rewrite README.md for TSN (quick start, structure, commands)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 29: Обновить plugin.json

**Files:**
- Modify: `.claude/plugins/project/.claude-plugin/plugin.json`

- [ ] **Step 1: Прочитай текущий**

```bash
cat .claude/plugins/project/.claude-plugin/plugin.json
```

- [ ] **Step 2: Обнови description**

Создай файл с новым содержимым:

```json
{
  "name": "project",
  "version": "0.2.0",
  "description": "AI-агенты (chair/legal/finance/docs/comms/research/archivist/analyst) и команды управления товариществом (ТСН/ТСЖ/СНТ/ЖСК).",
  "author": {
    "name": "mdemyanov",
    "email": "qutask@gmail.com"
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add .claude/plugins/project/.claude-plugin/plugin.json
git commit -m "chore(plugin): bump to 0.2.0 with TSN-specific description

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 30: Создать .claude/docs/ справочники

**Files:**
- Create: `.claude/docs/frontmatter-guide.md`
- Create: `.claude/docs/templates-guide.md`
- Create: `.claude/docs/vault-config.md`

- [ ] **Step 1: frontmatter-guide.md**

```markdown
# Контракт frontmatter

Обязательный frontmatter для всех `.md` в `content/` (кроме `_index.md`).

## Object-нотация (правильная)

```yaml
---
properties:
  - name: Тип документа
    value: [Решение]
  - name: Категория
    value: [Правление]
  - name: Статус
    value: [Действует]
date: 2026-05-25
tags: [тег1, тег2]
related:
  - "[03-board/actors.md](../03-board/actors.md)"
---
```

## Поля по типам документов

| Тип документа | Категория | Обязательные доп. поля |
|---------------|-----------|------------------------|
| Решение | Правление | date, related (на ОСС/ОС если есть основание) |
| Протокол | Общее собрание / Правление | date, кворум, повестка (в теле) |
| Договор | Договоры | date, контрагент, сумма, срок |
| Претензия | Юридическое | date, recipient, requirement, deadline |
| Анализ | (по теме) | date, sources |
| Отчёт | (по теме) | date, period |
| Insight | (по теме) | date, sources, tags |
| Заметка | (любая) | date, tags |
| Реестр | (по теме) | (часто без date — реестр живёт) |
| Тех. документация | Объект | date, version |

## Статусы

- `Черновик` — work in progress, не для публикации
- `В работе` — активно дорабатывается
- `Действует` — финальная версия, имеет правовую силу
- `Завершён` — закрыт, без актуальности
- `Архив` — перенесён в `10-archive/`

## `_index.md` — НЕТ properties

`_index.md` в каждой подпапке — это раздел, не статья. Не включай блок `properties:`. Минимум:

```markdown
---
title: "Название раздела"
---

# Название раздела

Краткое описание.

- [Подраздел 1](path/)
- [Подраздел 2](path/)
```

## Плоская нотация — устарела

❌ НЕ так:
```yaml
- Тип контента: ADR
- Статус: Approved
```

✓ Только object-нотация (см. выше).
```

- [ ] **Step 2: templates-guide.md**

```markdown
# Шаблоны документов

Шаблоны живут в `content/07-legal/templates/`. Используются командами `/decision`, `/protocol`, `/claim`, `/message`. При отсутствии шаблона `docs`-агент создаёт документ с нуля + СОХРАНЯЕТ как шаблон для следующего раза.

## Структура шаблона

```markdown
---
properties:
  - name: Тип документа
    value: [Шаблон]
  - name: Категория
    value: [Юридическое]
  - name: Статус
    value: [Действует]
template_for: decision    # тип документа, под который шаблон
applicability: МКД        # МКД / СНТ / любой
---

# Шаблон: <название>

## Параметры (заполняются при инстанциировании)

- `{{DATE}}` — дата документа
- `{{TITLE}}` — название
- `{{PARTICIPANTS}}` — участники
- ...

## Тело

[Текст шаблона с плейсхолдерами]

## Применимое право

[Для МКД: ст. ... ЖК РФ. Для СНТ: ст. ... ФЗ-217]
```

## Базовый набор (создаётся по мере необходимости)

| Имя | Тип | Применимость |
|-----|-----|--------------|
| `decision.md` | Решение правления | любой |
| `protocol-general-meeting.md` | Протокол ОСС/ОС | МКД vs СНТ — разные подшаблоны |
| `protocol-board.md` | Протокол заседания правления | любой |
| `claim-to-uk.md` | Претензия к УК | МКД |
| `claim-to-rso.md` | Претензия к РСО | МКД (СНТ — реже) |
| `claim-to-service.md` | Претензия к обслуживающей организации | любой |
| `message-announcement.md` | Объявление | любой |
| `message-elective.md` | Уведомление о ОСС/ОС | МКД vs СНТ |

## Принципы

- Шаблоны — не догма. `docs`-агент адаптирует под конкретный случай.
- При смене типа организации (например, шаблон под МКД, а товарищество СНТ) — `docs`-агент создаёт адаптированную версию и СОХРАНЯЕТ под `claim-to-service-snt.md`.
- Все шаблоны проходят ревизию раз в 6-12 месяцев (на актуальность НПА).
```

- [ ] **Step 3: vault-config.md**

```markdown
# Vault config — {{TSN_NAME}}

Параметры товарищества для использования агентами и командами. Заполняется на `/init` Phase 2.

## Базовые

- **Название:** {{TSN_NAME}}
- **Код Gramax:** {{TSN_CODE}}
- **Адрес:** {{TSN_ADDRESS}}
- **Председатель/и.о.:** {{CHAIR_NAME}}
- **Email редактора:** {{EDITOR_EMAIL}}

## Тип и характеристики

- **Тип организации:** <!-- TODO(/init): МКД (ТСЖ/ЖСК) / СНТ / ОНТ -->
- **Регион:** <!-- TODO(/init) -->
- **Год создания/постройки:** <!-- TODO(/init) -->
- **Общая площадь:** <!-- TODO(/init): м² (МКД) или га (СНТ) -->
- **Количество объектов:**
  - Квартир: <!-- TODO(/init): для МКД -->
  - Коммерческих: <!-- TODO(/init): для МКД -->
  - Участков: <!-- TODO(/init): для СНТ -->

## Каталоги (paths)

| Параметр | Значение |
|----------|----------|
| `property_dir` | `content/01-property` |
| `owners_dir` | `content/02-owners` |
| `board_dir` | `content/03-board` |
| `general_meeting_dir` | `content/04-general-meeting` |
| `finance_dir` | `content/05-finance` |
| `contracts_dir` | `content/06-contracts` |
| `legal_dir` | `content/07-legal` |
| `projects_dir` | `content/08-projects` |
| `contacts_dir` | `content/09-contacts` |
| `archive_dir` | `content/10-archive` |
| `templates_dir` | `content/07-legal/templates` |
| `actors_path` | `content/03-board/actors.md` |
| `manager_state_path` | `content/03-board/manager-state.md` |
| `log_path` | `content/03-board/log.md` |
```

- [ ] **Step 4: Commit**

```bash
mkdir -p .claude/docs
git add .claude/docs/frontmatter-guide.md \
        .claude/docs/templates-guide.md \
        .claude/docs/vault-config.md
git commit -m "feat(docs): add .claude/docs guides (frontmatter, templates, vault-config)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 31: Финальная верификация и итоговый коммит

- [ ] **Step 1: Полный smoke-test**

```bash
bash scripts/test-template.sh
```

Expected: `==> PASS: test-template` (со всеми вложенными тестами).

- [ ] **Step 2: Подсчёт артефактов**

```bash
echo "Agents: $(ls .claude/plugins/project/agents/*.md | wc -l)"
echo "Commands: $(ls .claude/plugins/project/commands/*.md | wc -l)"
echo "Content sections: $(ls -d content/[0-9][0-9]-*/ | wc -l)"
echo "Has _index in every dir: $(find content -type d ! -path content -exec test -f {}/_index.md \; -print | wc -l)"
```

Expected:
- Agents: 8
- Commands: 19 (= 1 init + 7 agent-invoke + 4 management + 7 document)
- Content sections: 10
- Has _index: 22-25 (зависит от nested subdirs; должно быть равно числу директорий)

- [ ] **Step 3: Validate-content на пустом state и на initialized state**

```bash
# На текущем state (с плейсхолдерами):
uv run scripts/validate-content.py
```

Expected: exit 0.

- [ ] **Step 4: Grep на остаточные плейсхолдеры (должны быть только {{...}} — НЕ TODO профиля)**

```bash
grep -rn 'PROJECT_NAME\|PROJECT_CODE\|PROJECT_DESCRIPTION' CLAUDE.md AGENTS.md README.md content/ 2>/dev/null
grep -rn 'TODO(/init)' CLAUDE.md content/ 2>/dev/null | head -10
```

Expected:
- Первый grep: пусто (все PROJECT_* заменены на TSN_*)
- Второй grep: несколько TODO маркеров в местах, где нужны данные конкретного товарищества — это ОК.

- [ ] **Step 5: git status — проверь чистоту**

```bash
git status
git log --oneline -20
```

Expected: clean working tree, ~15-20 коммитов с понятными сообщениями.

- [ ] **Step 6: Финальный коммит (если нужен) с roadmap**

Если в процессе появились мелкие правки — закоммитить их финальным коммитом:

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore: finalize TSN template adaptation

Template ready for use:
- 8 agents (chair/legal/finance/docs/comms/research/archivist/analyst)
- 19 commands (init, 4 management, 7 document, 7 agent-invoke)
- 10-section content scaffold (Gramax)
- /init flow with ТСН-specific parameters (МКД + СНТ/ОНТ)

Spec: docs/superpowers/specs/2026-05-25-tsn-template-design.md
Plan: docs/superpowers/plans/2026-05-25-tsn-template-implementation.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Если working tree clean — пропусти Step 6.

- [ ] **Step 7: Append в docs/lessons-learned.md**

Добавь запись о завершении эпика. Пример:

```markdown
## 2026-05-25 — TSN template adaptation

**Эпик:** превращение мульти-профильного `project_template` в моно-целевой `tsn-assistant`.

**Артефакты:**
- Spec: `docs/superpowers/specs/2026-05-25-tsn-template-design.md`
- Plan: `docs/superpowers/plans/2026-05-25-tsn-template-implementation.md`

**Уроки:**
- Удаление профильной системы (7 профилей) дало 2x редукцию сложности — для моно-целевых шаблонов это правильный выбор
- ТСН в широком смысле (МКД + СНТ) требует двух-веточной НПА базы у legal-агента (ЖК РФ + ФЗ-217). Терминология (квартиры/участки, тарифы/взносы) определяется типом из passport.md
- Имена ролей одним словом (chair/legal/finance) удобнее multi-word (project-manager, business-analyst) для повседневного использования
```

```bash
git add docs/lessons-learned.md
git commit -m "docs(lessons): TSN template adaptation эпик — 3 lesson learned

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

### Spec coverage

Проверка покрытия §-ов spec задачами:

- §2.1 (удалить профильную систему) → Task 1 ✓
- §2.2 (8 ролей) → Tasks 10-17 ✓ (chair, legal, finance, docs, comms, research, archivist, analyst)
- §2.3 (17 команд + init = 19 файлов) → Tasks 18-21 ✓ (init + 7 agent-invoke + 4 management + 7 document)
- §2.4 (content/ 10 разделов) → Tasks 4-9 ✓
- §2.5 (.doc-root.yaml) → Task 3 ✓
- §2.6 (/init flow: Phase 1 + Phase 2 с 8 вопросами) → Tasks 21, 23 ✓
- §2.7 (CLAUDE.md правила) → Task 26 ✓
- §2.8 (skills) → сохранены без изменений, в Task 1 step 5 проверка
- §2.9 (MCP) → Task 23 step 1 (install) ✓
- §2.10 (тесты) → Tasks 22, 25 ✓
- §3 (удаляется) → Task 1 ✓
- §4 (создаётся) → Tasks 3-30 ✓
- §5 (CLAUDE.md content) → Task 26 ✓
- §6 (AGENTS.md content) → Task 27 ✓
- §7 (README content) → Task 28 ✓
- §9 (acceptance criteria) → проверяются в Task 31

Memory note: ТСН в широком смысле (МКД + СНТ) — учтено в §1, §2.2 (legal двухветочный), §2.6 (вопрос #1 — тип), §2.7 (правило #13: терминология по типу).

### Placeholder scan

- ❌ "TBD" — нет
- ❌ "implement later" — нет
- ❌ "TODO without context" — TODO-маркеры в content/ файлах намеренны (это плейсхолдеры для /init Phase 2)
- ❌ "Similar to Task N" — нет
- ❌ Шаги без кода для code-операций — нет
- ❌ Ссылки на функции/типы, не определённые в задачах — нет

### Type consistency

- `TSN_NAME`, `TSN_CODE`, `TSN_DESCRIPTION`, `TSN_ADDRESS`, `CHAIR_NAME`, `EDITOR_EMAIL` — везде согласованно (init.sh, init.md, CLAUDE.md, AGENTS.md, README.md, content/.doc-root.yaml, passport.md, actors.md)
- Имена агентов: `chair`, `legal`, `finance`, `docs`, `comms`, `research`, `archivist`, `analyst` — согласованы во всех задачах
- Имена команд: согласованы (init/status/delegate/weekly/review/decision/protocol/claim/contract/message/ingest/insight + 7 agent-invoke)
- Пути content/: `01-property` (не `01-building`), kebab-case — согласовано
- Frontmatter: object-нотация со values `[...]` (массивы) — согласовано

### Готово к execution

19 коммитов разбиты по логическим частям. Параллельные субагенты могут работать на Tasks 5-9 (content scaffolds), 10-17 (agents), 18-20 (commands) — нет cross-dependencies между ними. Task 22 (test) → Task 23 (init.sh) — последовательно (TDD цикл).

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-25-tsn-template-implementation.md`.

**Execution mode:** subagent-driven-development (выбран пользователем заранее).

Каждая задача — fresh subagent, two-stage review между задачами. Параллельные группы (5-9 content, 10-17 agents, 18-20 commands) — через `superpowers:dispatching-parallel-agents` для ускорения.
