---
type: spec
title: "TSN-Assistant — адаптация шаблона под ТСН/ТСЖ"
date: 2026-05-25
status: draft
tags: [spec, tsn, template, redesign]
---

# TSN-Assistant — адаптация шаблона под товарищества собственников недвижимости

## 1. Цель

Превратить мульти-профильный шаблон `project_template` в **моно-целевой шаблон для управления товариществом собственников недвижимости (ТСН/ТСЖ/ЖСК/УК)**.

**Картина успеха.** Председатель ТСН клонирует репозиторий → выполняет `/init` (отвечает на ~7 вопросов о товариществе) → получает рабочий Gramax-каталог со структурой по 10 разделам, набор из 8 агентов и ~17 slash-команд, покрывающих весь цикл управления: документооборот, юр.анализ, финансовый анализ, ОСС, коммуникации с жителями, договорная работа.

**Референсы:**
- Реальный vault: `/Users/mdemyanov/Documents/TSN16k2/` (Obsidian, ТСН «Лайф 2», Москва)
- Best practices ТСН/ТСЖ/УК (ЖК РФ, региональные НПА Москвы и других субъектов)

## 2. Ключевые архитектурные решения

### 2.1. Удаляем профильную систему

Текущий шаблон поддерживает 7 профилей (`project`, `kb-team`, `kb-product`, `product`, `methodology`, `course`, `custom`) через `docs/overlays/profiles/*`. Для моно-цели «ТСН» это избыточная сложность.

**Удаляется:**
- `docs/overlays/profiles/` (все 7 профилей)
- `examples/` (все примеры)
- `scripts/apply-overlay.sh`, `_apply_profile.py`, `_resolve_agents.py`, `validate-profile.py`
- Тестовые скрипты: `test-apply-overlay.sh`, `test-validate-profile.sh`, `test-resolve-agents.sh`, `test-spdd-integration.sh`
- Profile-логика в `scripts/init.sh` (меню, init_prompts, overlay-операции, compatible_stacks)
- Документация: `docs/extending.md` (упростить), `docs/upgrading-from-template.md` (удалить)

**Упрощается:**
- `scripts/_init_helpers.py` — выкидываем helpers, относящиеся только к профилям (`list-profiles`, `menu-format`, `profile-summary`, `init-prompts`, `compat-stacks`)

### 2.2. Каталог ролей (8 ролей: 1 main + 7 субагентов)

Имена короткие, по одному слову, прямой маппинг с TSN16k2:

| Имя | Где | Модель | Назначение | Заменяет в TSN16k2 |
|-----|-----|--------|------------|---------------------|
| `chair` | main | Opus | Виртуальный председатель/оркестратор. Реестр задач, делегирование, статусы. Substantive не делает — делегирует. | `virtual_manager` |
| `legal` | subagent | Sonnet | Юр.анализ договоров, претензии, разъяснение НПА (ЖК РФ, ГК РФ, региональные акты) | `legal_analyst` |
| `finance` | subagent | Sonnet | Тарифы, бюджеты, сметы, биллинг РСО, расчёт экономии | `financial_analyst` |
| `docs` | subagent | Sonnet | Создание документов по шаблонам (решения, протоколы, претензии) | `document_creator` |
| `comms` | subagent | Sonnet | Тексты для жителей: объявления, рассылки, ответы на обращения. Использует skill `infoinstyle` | `communications_writer` |
| `research` | subagent | Sonnet | Поиск НПА, региональных норм, КП подрядчиков (MCP `open-websearch`) | `researcher` |
| `archivist` | subagent | Sonnet | Ingest входящих документов (PDF, фото, email) → структурированные `.md` с frontmatter | `ingest_processor` |
| `analyst` | subagent | Sonnet | Стратегические сравнения (УК, подрядчики, тарифные модели), кросс-доменный анализ | `analyst` |

**Удаляются** существующие software-dev агенты: `pm`, `ba`, `sa`, `dev`, `devops`, `qa-author`, `qa-runner`, `tech-writer`, `devsecops`, `compliance`, `researcher` (заменяется на `research`).

**Контракт вызова** субагента — тот же что в существующем `AGENTS.md`:
1. Цель одной фразой
2. Входные файлы (пути)
3. Ожидаемый артефакт
4. Критерии приёмки

### 2.3. Slash-команды (17 команд)

**Команды-агенты** (прямой вызов субагента):
- `/legal` — юр.анализ
- `/finance` — финансовый анализ
- `/docs` — создание документа по шаблону
- `/comms` — текст для жителей
- `/research` — исследование (НПА, КП, региональные нормы)
- `/archivist` — обработать входящий PDF/email
- `/analyst` — стратегический анализ

**Управленческие команды** (оркестрация через `chair`):
- `/init` — инициализация ТСН (Phase 1 bash + Phase 2 интервью)
- `/status` — текущий статус (задачи, проекты, просрочки)
- `/delegate` — создать задачу с назначением исполнителя
- `/weekly` — еженедельный обзор
- `/review` — ревью контента перед merge `private → public` (заменяет `pm-review`)

**Документные команды** (template-driven):
- `/decision` — решение правления
- `/protocol` — протокол ОСС/заседания
- `/claim` — претензия (вызывает `legal` + `docs`)
- `/contract` — анализ договора (вызывает `legal` + `finance` параллельно)
- `/message` — сообщение жителям (вызывает `comms`)
- `/ingest` — загрузить внешний документ (вызывает `archivist`)
- `/insight` — сохранить ключевой substantive-анализ

**Удаляются** существующие команды: `/pm`, `/pm-review`, `/ba`, `/sa`, `/dev`, `/devops`, `/qa`, `/tech-writer`, `/devsecops`, `/compliance`, `/research` (старая dev-версия), `/pipelines/*`.

### 2.4. Структура `content/` (Gramax-каталог)

Адаптация vault TSN16k2 под Gramax. Правила:
- kebab-case имена директорий
- `_index.md` в каждом подкаталоге (Gramax-требование)
- `_index.md` БЕЗ блока `properties` (это не статья, а раздел)
- Содержимое — на русском
- Frontmatter — object-нотация (см. правила Gramax в `CLAUDE.md`)

```
content/
├── _index.md                  # Главная: дашборд + навигация
├── .doc-root.yaml             # Схема Gramax с ТСН-properties
│
├── 01-building/               # Технический паспорт дома
│   ├── _index.md
│   ├── passport.md            # ★ заполняется на /init (адрес, площадь, год)
│   ├── premises/              # помещения
│   │   ├── _index.md
│   │   ├── apartments.md
│   │   └── commercial.md
│   └── equipment/             # инженерное оборудование
│       └── _index.md
│
├── 02-owners/                 # Собственники
│   ├── _index.md
│   ├── registry.md            # реестр собственников
│   ├── tickets/               # обращения жителей
│   │   └── _index.md
│   └── communications/        # история рассылок
│       └── _index.md
│
├── 03-board/                  # Правление
│   ├── _index.md
│   ├── actors.md              # ★ заполняется на /init (состав + routing)
│   ├── manager-state.md       # ★ память chair-агента между сессиями
│   ├── log.md                 # ★ activity log (append-only)
│   ├── decisions/             # решения правления
│   │   └── _index.md
│   ├── meetings/              # протоколы заседаний
│   │   └── _index.md
│   └── tasks/                 # реестр задач (T-YYYY-MMDD-NN)
│       └── _index.md
│
├── 04-general-meeting/        # ОСС
│   ├── _index.md
│   ├── procedures.md          # порядок проведения ОСС
│   └── 2026/                  # материалы по годам
│       └── _index.md
│
├── 05-finance/                # Финансы
│   ├── _index.md
│   ├── tariffs.md             # тарифы (история)
│   ├── budget/                # бюджеты
│   │   └── _index.md
│   ├── reports/               # фин.отчёты
│   │   └── _index.md
│   └── insights/              # сохранённые fin-анализы
│       └── _index.md
│
├── 06-contracts/              # Договоры
│   ├── _index.md
│   ├── registry.md            # реестр договоров
│   ├── uk/                    # управляющие компании
│   │   └── _index.md
│   ├── rso/                   # ресурсоснабжающие организации
│   │   └── _index.md
│   └── service/               # обслуживание (лифты, уборка, IT)
│       └── _index.md
│
├── 07-legal/                  # Юридическое
│   ├── _index.md
│   ├── templates/             # шаблоны (претензии, решения, протоколы, объявления)
│   │   └── _index.md
│   ├── claims/                # отправленные претензии
│   │   └── _index.md
│   └── insights/              # сохранённые юр.анализы
│       └── _index.md
│
├── 08-projects/               # Проекты
│   ├── _index.md
│   └── _active.md             # список активных проектов
│
├── 09-contacts/               # Внешние контакты
│   ├── _index.md
│   └── authorities.md         # органы власти (ГЖИ, прокуратура, мэрия)
│
└── 10-archive/                # Архив
    └── _index.md
```

### 2.5. `.doc-root.yaml` — properties для ТСН

```yaml
code: {{TSN_CODE}}
title: {{TSN_NAME}}
description: {{TSN_DESCRIPTION}}
style: blue-green
language: ru
supportedLanguages: [ru]
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
      - Дом
      - Собственники
      - Правление
      - ОСС
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

### 2.6. `/init` flow

**Фаза 1 (bash, `scripts/init.sh`):**

Параметры:
- `TSN_NAME` — полное название ("ТСН Лайф 2")
- `TSN_CODE` — код Gramax-каталога ("TSN-LIFE-2")
- `TSN_ADDRESS` — полный адрес ("Москва, ул. Чистова д.16 к.2")
- `CHAIR_NAME` — ФИО председателя/и.о.
- `EDITOR_EMAIL` — email редактора Gramax
- `GIT_REMOTE_URL` (опц.)

Действия:
1. Валидация (uv, git, CLAUDE.md present)
2. Защита: GIT_REMOTE_URL не должен указывать на репо шаблона
3. Capture traceability (`TEMPLATE_URL@TEMPLATE_SHA`)
4. Подстановка плейсхолдеров в:
   - `CLAUDE.md` ({{TSN_NAME}}, {{TSN_ADDRESS}}, {{CHAIR_NAME}})
   - `AGENTS.md` ({{TSN_NAME}})
   - `README.md`
   - `content/.doc-root.yaml`
   - `content/_index.md`
   - `content/01-building/passport.md` (адрес)
   - `content/03-board/actors.md` (председатель)
5. Wipe `.git` → `git init -b main` → initial commit с `Template: ${URL}@${SHA}` → ветка `private`
6. `cp .env.example .env`
7. MCP install (`open-websearch`, user-scope, идемпотентно)

**Фаза 2 (интервью, выполняется агентом в Claude Code через `/init`):**

По одному вопросу. На skip — TODO-маркер остаётся в файле.

| # | Тема | Вопрос | Куда пишем |
|---|------|--------|------------|
| 1 | Тип организации | "ТСН / ТСЖ / ЖСК / УК?" | `CLAUDE.md` (роль), `01-building/passport.md` |
| 2 | Регион | "Регион/город (для НПА): Москва / СПб / другой регион" | `CLAUDE.md`, `09-contacts/authorities.md` |
| 3 | Помещения | "Количество квартир и коммерческих помещений" | `01-building/passport.md`, `01-building/premises/` |
| 4 | Площадь | "Общая площадь дома, м²" | `01-building/passport.md` |
| 5 | Год постройки | "Год постройки дома" | `01-building/passport.md` |
| 6 | Состав правления | "Перечисли членов правления (ФИО + роль + контакт). Можно по одному." | `03-board/actors.md` |
| 7 | Подрядчики | "Действующая УК + ключевые обслуживающие организации (опц.)" | `06-contracts/registry.md` |

После всех ответов: commit Phase 2 changes как `feat(init): initial TSN data` в ветке `private` (с user confirmation).

### 2.7. CLAUDE.md правила (адаптация под ТСН)

Перенос ключевых правил из `TSN16k2/CLAUDE.md`:

```markdown
## Режим работы

Практический помощник правления ТСН. Задачи: документооборот, финансовый анализ,
юридическая поддержка, коммуникации с жителями, организация ОСС.

**Приоритет:** решение задач силами правления (0–500 руб.) > привлечение внешних специалистов.

## Протокол работы

1. **Уточни** — что именно нужно, контекст
2. **Сформулируй** — задачу чётко
3. **Предложи варианты** — минимум 2-3 с расчётом стоимости
4. **Рекомендуй** — конкретное решение с обоснованием

## Правила

1. **Язык:** русский. Содержимое файлов — на русском (рабочий язык).
2. **Имена директорий и файлов — английский kebab-case.**
   - Директории: `03-board`, не `03_PRAVLENIE`
   - Файлы: `2026-04-21_decision_intercom.md`, не `2026-04-21_reshenie_domofon.md`
   - Wikilinks/ссылки: всегда английские имена
3. **Frontmatter:** обязателен для всех `.md`. Контракт — `.claude/docs/frontmatter-guide.md`.
4. **ПДн:** не публиковать паспортные данные, ФИО + контакты собственников, пароли, токены, API-ключи. При получении — предупредить.
5. **Экономия:** при рекомендациях показывать вариант «сделать самим» (0-500 руб.) vs внешний подрядчик.
6. **Activity log:** при `/delegate`, `/ingest`, `/decision`, `/insight` — append в `content/03-board/log.md`.
7. **Триггеры insight:** при substantive-анализе >500 слов с выводами/сравнениями — предложить `/insight`.
8. **Критическое мышление:** не соглашаться без анализа, проверять источники, указывать противоречия. **Проверять даты НПА** — сейчас 2026 год.
9. **Границы экспертизы:** уголовные дела → адвокат, налоги → консультант, экспертиза → инженер, трудовые споры → юрист.
10. **Файлы:** не удалять, не перезаписывать, не перемещать без подтверждения.

## Two-way sync (drift_pairs)

| Upstream | Downstream | Причина |
|----------|------------|---------|
| `content/01-building/passport.md` | `content/06-contracts/*` | Договоры зависят от характеристик дома (площадь, помещения) |
| `content/03-board/decisions/*` | `content/08-projects/*` | Исполнение решений правления через проекты |
| `content/06-contracts/*` | `content/07-legal/claims/*` | Претензии должны соответствовать актуальным договорам |
| `content/05-finance/tariffs.md` | `content/05-finance/budget/*` | Бюджет считается от актуальных тарифов |

Исключение для hotfix: trailer `skip-drift: hotfix — <описание>` в commit message.
```

### 2.8. Skills

Сохраняем существующие, оба применимы к ТСН:
- `infoinstyle` — адаптация текстов под инфостиль (для `comms`)
- `correspondence-2` — деловая переписка

Опционально добавить (вне scope этого spec, future iteration):
- `docx` — генерация .docx (из TSN16k2)
- `tg-parser` — парсинг Telegram-чатов жителей

### 2.9. MCP-серверы

Сохраняем `open-websearch` (DuckDuckGo + Bing + Exa) — основной поисковик для `research` агента.

`research` использует MCP для:
- Поиска актуальных НПА (ed.mos.ru, mos.ru, ГИС ЖКХ, КонсультантПлюс)
- Поиска КП подрядчиков
- Поиска практики (судебные решения, опыт других ТСН)

### 2.10. Тесты

- `scripts/test-template.sh` — адаптируется: проверка полного init flow (Phase 1 + Phase 2 в non-interactive mode)
- `scripts/test-validate-content.sh` — остаётся (Gramax content validation)
- Удаляются: `test-apply-overlay.sh`, `test-resolve-agents.sh`, `test-spdd-integration.sh`, `test-validate-profile.sh`
- Новый: `scripts/test-init-tsn.sh` — smoke-test полного init flow с фиктивными ТСН-параметрами:
  - запустить init.sh с заглушками
  - проверить, что все плейсхолдеры заменены
  - проверить, что `content/01-building/passport.md` создан и заполнен
  - проверить, что `content/03-board/actors.md` существует
  - проверить, что `validate-content.py` exit 0

## 3. Что удаляется (полный список)

**Директории:**
- `docs/overlays/` (целиком)
- `examples/` (целиком)

**Файлы:**
- `scripts/apply-overlay.sh`
- `scripts/_apply_profile.py`
- `scripts/_resolve_agents.py`
- `scripts/validate-profile.py`
- `scripts/test-apply-overlay.sh`
- `scripts/test-validate-profile.sh`
- `scripts/test-resolve-agents.sh`
- `scripts/test-spdd-integration.sh`
- `docs/upgrading-from-template.md`

**Агенты:**
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
- `.claude/plugins/project/agents/researcher-agent.md` (заменяется новой версией `research-agent.md`)

**Команды:**
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
- `.claude/plugins/project/commands/research.md` (заменяется)
- `.claude/plugins/project/commands/pipelines/` (целиком)

## 4. Что создаётся

**Агенты (8):**
- `agents/chair-agent.md` — оркестратор (по образцу TSN16k2 `virtual_manager`)
- `agents/legal-agent.md` — юрист
- `agents/finance-agent.md` — финансист
- `agents/docs-agent.md` — документовед
- `agents/comms-agent.md` — коммуникатор
- `agents/research-agent.md` — исследователь
- `agents/archivist-agent.md` — архивариус (ingest)
- `agents/analyst-agent.md` — стратегический аналитик

**Команды (17):**
- `commands/init.md` — переписана под ТСН
- Команды-агенты: `legal.md`, `finance.md`, `docs.md`, `comms.md`, `research.md`, `archivist.md`, `analyst.md`
- Управленческие: `status.md`, `delegate.md`, `weekly.md`, `review.md`
- Документные: `decision.md`, `protocol.md`, `claim.md`, `contract.md`, `message.md`, `ingest.md`, `insight.md`

**Content scaffold (под profile-удалением):**
- `content/_index.md` — главная с дашбордом
- `content/.doc-root.yaml` — переписан с TSN-properties
- `content/01-building/` ... `content/10-archive/` — структура согласно §2.4
- В каждой папке: `_index.md` + начальные шаблоны (passport.md, actors.md, registry.md и т.д.)

**.claude/docs/** (новые справочники):
- `frontmatter-guide.md` — контракт frontmatter по типам документов ТСН
- `templates-guide.md` — шаблоны документов (решение, протокол, претензия)
- `vault-config.md` — TODO-маркеры для адресации, площадей, состава правления (заполняются на /init Phase 2)

## 5. Содержимое CLAUDE.md (структура)

```markdown
# {{TSN_NAME}} — AI-ассистент правления

Работаешь в Claude Code как **chair (председатель/оркестратор)** ...

## Контекст ТСН
- Название: {{TSN_NAME}}
- Адрес: {{TSN_ADDRESS}}
- Председатель: {{CHAIR_NAME}}
- (заполняется на /init Phase 2: тип, регион, площадь, кол-во помещений, состав правления)

## Карта команды
| Команда | Роль | Где |
|---------|------|-----|
| chair   | Координатор    | main (Opus) |
| /legal  | Юрист          | subagent (Sonnet) |
| ...     | ...            | ... |

## Подключённые плагины
- gramax@ai-assistants
- superpowers@claude-plugins-official
- project@local

## Правила (см. §2.7 spec)

## Когда какой скилл звать
| Ситуация | Скилл |
|----------|-------|
| Создание/редактирование статьи Gramax | gramax:writer |
| Чтение комментариев Gramax | gramax:comments-read |
| Многошаговая задача | superpowers:brainstorming → writing-plans → executing-plans |
| Адаптация текста | infoinstyle |

## Красные линии
(см. §2.7)
```

## 6. Содержимое AGENTS.md (новое)

```markdown
# AGENTS.md — {{TSN_NAME}}

## Каталог ролей

| Имя | Где | Модель | Промпт | Команда |
|-----|-----|--------|--------|---------|
| chair | main | Opus | (main) | (orchestrator) |
| legal | subagent | Sonnet | agents/legal-agent.md | /legal |
| finance | subagent | Sonnet | agents/finance-agent.md | /finance |
| docs | subagent | Sonnet | agents/docs-agent.md | /docs |
| comms | subagent | Sonnet | agents/comms-agent.md | /comms |
| research | subagent | Sonnet | agents/research-agent.md | /research |
| archivist | subagent | Sonnet | agents/archivist-agent.md | /archivist |
| analyst | subagent | Sonnet | agents/analyst-agent.md | /analyst |

## Контракт вызова субагента
(стандартный: цель, входы, артефакт, критерии)

## Карта делегирования (для chair)

| Тип задачи | Специалист |
|------------|------------|
| Юр. анализ, претензии, разбор НПА | legal |
| Сметы, бюджеты, тарифы | finance |
| Создание документов по шаблонам | docs |
| Тексты жителям, объявления | comms |
| Поиск в web (НПА, КП) | research |
| Обработка PDF/email | archivist |
| Кросс-доменный анализ, сравнения | analyst |

## Поток работы

(orchestration через chair → делегирование специалистам → возврат результата → save в content/)

## Self-improvement
(auto-memory pattern, lessons-learned)

## Red lines
(см. §2.7 spec)
```

## 7. README.md (новое — короткое)

```markdown
# {{TSN_NAME}} — AI-ассистент правления

База знаний и AI-ассистент для управления товариществом собственников недвижимости.

## Быстрый старт

1. Клонируй: `git clone <url> tsn-assistant`
2. Открой в Claude Code
3. `/init` — инициализация (название ТСН, адрес, состав правления...)
4. `/status` — текущий статус
5. `/delegate <задача>` — делегировать

## Что внутри

- `content/` — Gramax-каталог с 10 разделами (дом, собственники, правление, ОСС, финансы, договоры, юр., проекты, контакты, архив)
- `.claude/plugins/project/agents/` — 8 AI-агентов (chair, legal, finance, docs, comms, research, archivist, analyst)
- `.claude/plugins/project/commands/` — 17 slash-команд

## Документация

- `CLAUDE.md` — инструкции для Claude
- `AGENTS.md` — каталог ролей
- `docs/glossary.md` — глоссарий
```

## 8. План реализации (high-level — детальный план в writing-plans)

1. **Cleanup**: удалить профильную инфраструктуру (overlays, examples, profile-scripts, dev-agents/commands)
2. **Content scaffold**: создать новую `content/` структуру с 10 разделами + `_index.md` в каждой
3. **`.doc-root.yaml`**: переписать с TSN-properties
4. **Агенты**: создать 8 промптов (chair, legal, finance, docs, comms, research, archivist, analyst)
5. **Команды**: создать 17 команд
6. **`scripts/init.sh`**: переписать (убрать профили, добавить TSN-параметры, обновить scaffold-flow)
7. **`commands/init.md`**: переписать (Phase 2 — TSN-интервью)
8. **CLAUDE.md, AGENTS.md, README.md**: переписать под ТСН
9. **`.claude/docs/`**: добавить frontmatter-guide.md, templates-guide.md, vault-config.md
10. **Тесты**: создать `test-init-tsn.sh`, удалить нерелевантные тесты, адаптировать `test-template.sh`
11. **Smoke-test**: запустить `/init` с фиктивными параметрами, верифицировать
12. **Commit + PR**

## 9. Acceptance criteria

- [ ] Профильная система удалена (`docs/overlays/profiles/` отсутствует)
- [ ] `examples/` удалена
- [ ] 8 агентов созданы в `.claude/plugins/project/agents/`, имена короткие (одно слово)
- [ ] 17 команд созданы в `.claude/plugins/project/commands/`, имена короткие
- [ ] `content/` имеет 10 разделов согласно §2.4, в каждой подпапке `_index.md`
- [ ] `content/.doc-root.yaml` содержит ТСН-properties (Тип документа / Категория / Статус)
- [ ] `scripts/init.sh` запускается с TSN-параметрами и проходит без ошибок
- [ ] `/init` Phase 2 заполняет `01-building/passport.md`, `03-board/actors.md` по ответам пользователя
- [ ] `python3 scripts/validate-content.py` — exit 0 на свежеинициализированном каталоге
- [ ] `bash scripts/test-init-tsn.sh` — passes
- [ ] CLAUDE.md содержит правила TSN16k2 (ПДн, экономия, activity log, границы экспертизы)
- [ ] AGENTS.md описывает 8 ролей + контракт вызова + карту делегирования
- [ ] README.md — короткий быстрый старт

## 10. Anti-scope (чего НЕ делаем в этой итерации)

- Не добавляем доп. skills (`docx`, `tg-parser`) — потенциальные next steps
- Не делаем pipelines (`/pipelines/*`) — можно добавить позже под конкретные сценарии (выборы ОСС, годовой отчёт)
- Не делаем UI/desktop приложение
- Не интегрируем с ГИС ЖКХ напрямую (research-агент через web — достаточно для MVP)
- Не пишем content-наполнение (шаблоны претензий/решений) — это next iteration; даём только структуру
- Не мигрируем данные из TSN16k2 vault — шаблон чистый, председатель заполняет сам
