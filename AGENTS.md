# AGENTS.md — pg_vector_service

Матрица ролей, режим исполнения и процесс самоулучшения команды AI-агентов проекта.

## Роли и режим исполнения

| Роль | Где исполняется | Модель | Команда | Артефакты |
|------|-----------------|--------|---------|-----------|
| **PM** | main-context | Opus | `/pm`, `/pm-review` | `content/00-project/roadmap.md`, координация |
| **Researcher** | subagent | Sonnet | `/research` → `researcher-agent` | `content/10-domain/research/` |
| **BA** | subagent | Sonnet | `/ba` → `ba-agent` | `content/30-requirements/` |
| **SA** | subagent | Sonnet | `/sa` → `sa-agent` | `content/00-project/adr/`, `content/40-architecture/` |
| **Dev** | subagent | Sonnet | `/dev` → `dev-agent` | `src/`, `content/60-implementation/` |
| **DevOps** *(optional)* | subagent | Sonnet | `/devops` → `devops-agent` | `content/70-operations/` |
| **ITSM-аналитик** *(optional)* | subagent | Sonnet (Opus по запросу) | `/itsm` → `itsm-analyst-agent` | `content/10-domain/itsm-reviews/` или inline-review |

**Почему так:** PM-координация живёт в main-context, чтобы не раздувать контекст субагентов. Ролевая работа (BA/SA/Dev/DevOps/Researcher) вытесняется в субагенты на более дешёвой модели — экономия LLM-бюджета на типичной сессии.

DevOps помечен как **optional** — для проектов без явной инфра-составляющей не вызывается.

## Поток работы (Researcher → BA → SA → Dev → DevOps)

Канонический порядок для новой фичи (main-PM оркеструет):

1. **Researcher** *(опционально)* — собирает контекст по теме (домен, конкуренты, литература) → `content/10-domain/research/<тема>.md`
2. **BA** формирует требования: JTBD, бизнес-правила, приёмочные критерии → `content/30-requirements/`
3. **SA** проектирует: ADR (если нужно), компоненты/границы, dataflow → `content/00-project/adr/`, `content/40-architecture/`
4. **Dev** реализует по TDD: failing test → реализация → зелёный → commit. Соблюдает архитектуру SA.
5. **DevOps** *(если нужно)* — деплой, runbook, мониторинг → `content/70-operations/`

**PM** координирует на каждом этапе: приоритизирует, разрешает блокеры, запускает `/pm-review` перед merge в `public`.

**Опциональный консультант — ITSM-аналитик** (`/itsm` → `itsm-analyst-agent`) доступен на любом этапе: BA при формулировке JTBD, SA при выборе паттернов, PM при оценке реалистичности UC. Не блокирует и не заменяет основные роли. Вызывается явно по триггерам: появление ITSM-терминов (incident/problem/KB/SLA/RCA), сомнения в реалистичности сценария, выбор AI-сигналов, терминологические споры. Артефакты — Gramax-комментарии или mini-review в `content/10-domain/itsm-reviews/`; **в `content/30-requirements/`, `content/00-project/adr/`, `content/40-architecture/` не пишет**. Спецификация роли: `content/30-requirements/roles/itsm-analyst.md`.

Ветвление: `private` — рабочая ветка; `public` — публикация в Gramax после ревью PM.

## Вызов субагентов — контракт

При запуске `/research`, `/ba`, `/sa`, `/dev`, `/devops` main-PM **обязан** передать субагенту:

1. **Цель** одной фразой.
2. **Входные файлы** (пути к требованиям / ADR / коду / источникам) — субагент сам прочитает.
3. **Ожидаемый артефакт** — какой файл должен появиться или быть изменён.
4. **Критерии приёмки** — как понять, что задача выполнена.

Пример корректного prompt'а для `/dev`:

```
Цель: реализовать UserSessionRepository по архитектурной спецификации.
Входы: content/40-architecture/sessions.md, content/30-requirements/user-sessions.md
Артефакт: src/repositories/user_session.py + tests/test_user_session.py
Критерии: pytest зелёный, типы аннотированы, метод ≤20 строк, AC из требования покрыты тестами.
```

Субагент **не ищет контекст «вокруг»** — работает по явно переданному скопу.

### Особенность вызова `/itsm`

ITSM-аналитик — консультативная роль, артефакт ≠ требование/ADR/архитектура. В prompt'е укажи:

1. **Цель** — что оценить с точки зрения ITSM-методологии (например, «валидировать JTBD UC-S2 на реалистичность single-comment signal»).
2. **Кто потребитель ответа** — BA / SA / PM (влияет на формат рекомендации).
3. **Входные файлы** — конкретный объект ревью (UC / ADR / фрагмент архитектуры) + связанные артефакты, упомянутые явно.
4. **Ожидаемый формат**: inline-ответ / Gramax-комментарий / mini-review (только для сложных кейсов с фиксацией).
5. **НЕ запрашивай**: правок в `content/30-requirements/`, `content/00-project/adr/`, `content/40-architecture/`; web-search / ctx7 (это `/research`).

Пример корректного prompt'а для `/itsm`:

```
Цель: валидировать JTBD UC-S2 «поиск похожих заявок по тексту одного комментария»
       на реалистичность сигнала с точки зрения практики Service Desk.
Потребитель: BA (применит рекомендации в правках UC-S2).
Входы: content/30-requirements/functional/uc-s2-find-similar-by-comments.md,
       content/30-requirements/roles/itsm-analyst.md
Формат: Gramax-комментарий к UC-S2 + краткий inline-ответ в чате.
Критерии: оценка single-comment vs composite signal с references на
          ServiceNow Predictive Intelligence или KCS v6.
```

## Шаблон декомпозиции фичи (для main-PM)

Каждая фича проходит фазы: исследование (опц.) → анализ (BA) → проектирование (SA) → реализация (Dev) → развёртывание (DevOps).

```markdown
## Фича: [Название]

### Контекст
[Зачем нужно, какую проблему решает]

### Затронутые области
[Bounded Contexts / модули / компоненты]

### Фаза roadmap
[PoC / MVP / Pilot / Production]

### Задачи
- [ ] RES-XXX: [исследовать тему] → `content/10-domain/research/<file>.md` — `/research <prompt>`  *(опционально)*
- [ ] BA-XXX: [сформулировать требования] → `content/30-requirements/<file>.md` — `/ba <prompt>`
- [ ] ITSM-XXX: [ITSM-валидация UC / терминологии / AI-сигналов] → inline или `content/10-domain/itsm-reviews/<slug>.md` — `/itsm <prompt>`  *(опционально, рекомендован при появлении ITSM-терминов: incident/problem/KB/SLA/RCA)*
- [ ] SA-XXX: [спроектировать] — зависит от BA-XXX → `content/40-architecture/<file>.md` — `/sa <prompt>`
- [ ] DEV-XXX: [реализовать] — зависит от SA-XXX — `/dev <prompt>`
- [ ] OPS-XXX: [runbook/deploy] — зависит от DEV-XXX — `/devops <prompt>`  *(если нужно)*

### Зависимости
RES → BA → (ITSM, опц.) → SA → (ITSM, опц.) → DEV → OPS

### Риски
[Что может пойти не так]

### GO-критерии milestone
- Tests зелёные (если есть код)
- `/pm-review` без ошибок
- Acceptance Criteria из BA-артефакта пройдены
- Runbook (если есть DevOps-задача) написан
```

**Milestone закрывается** только при зелёных тестах + чистом `/pm-review` + выполненных AC. «Почти готово» = не закрыт.

## Матрица эскалации (для main-PM)

| Ситуация | К кому | Действие |
|----------|--------|----------|
| Неясные требования | BA | `/ba уточнить [вопрос]` |
| Архитектурный trade-off | SA | `/sa оценить [варианты]` |
| Технический блокер | Dev | `/dev исследовать [проблема]` |
| Инфраструктурный вопрос | DevOps | `/devops оценить [задача]` |
| ITSM-методология / реалистичность UC | ITSM-аналитик | `/itsm review [path]` или `/itsm [вопрос]` |
| Бюджет / стейкхолдер-доступ | Спонсор проекта | Эскалация в отчёте |

## Процесс самоулучшения (Retrospective)

После каждой завершённой задачи субагент:

1. Если встретил **неочевидный факт** об инфраструктуре/процессе/инструменте → сохраняет в auto-memory (типы: `reference`, `project`, `feedback`).
2. Если есть **урок для команды** → дописывает строку в `docs/lessons-learned.md`: `| дата | агент | контекст | наблюдение | действие |`.
3. Если ничего значимого — ничего не пишет.

`/pm-review` периодически читает `docs/lessons-learned.md` и memory, предлагает обновления CLAUDE.md / промтов агентов / глоссария.
