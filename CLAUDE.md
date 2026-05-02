# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Что это за проект

**pg_vector_service** — JAR-модуль для Naumen SMP, который добавляет в платформу возможности работы с векторными представлениями объектов: векторизация атрибутов по объектной модели SMP, поиск по сходству, кластерный анализ (поиск и объединение похожих объектов).

**Целевые сценарии (PoC включает все три, приоритеты внутри PoC уточняет BA):**
- Векторизация выбранных атрибутов SMP-объекта **джобой по расписанию** (sync-векторизация по событиям SMP — out of scope PoC).
- Семантический поиск: «найди похожие на этот объект». SLA анализируем по итогам PoC, не предзадаём.
- Кластерный анализ: автоматическое выявление и слияние дублей / однотипных объектов.

**Целевые SMP-классы (входы для BA/SA):**
- `issue` (заявки, инциденты, запросы — большое семейство подклассов, см. метамодель)
- `knowledgeBase` (статьи и разделы KB)
- `problem`
- Расширение по итогам RES-001 (live-выгрузка метамодели через MCP `naumen-smp-dev-admin`).

**Целевые объёмы:** медиана — сотни тысяч объектов на тенант, диапазон от десятков тысяч до миллионов. Влияет на выбор индекса pgvector (HNSW vs IVFFlat) — решение в ADR.

**Бюджет Yandex Cloud Foundation Models:** считаем после RES-002 (доступные модели + цена) и RES-001 (средний размер текста на объект). Pre-flight gate перед `/dev`.

**Стейкхолдеры:** [content/00-project/stakeholders.md](content/00-project/stakeholders.md) — owner Демьянов; операционный блок (Сазонова, Киселёва, Сахабетдинов) переиспользован из проекта SD AI Assistant.

**Текущая фаза:** инициализация (PoC). Кода в `src/` ещё нет — стартуем с research → BA → SA → Dev. См. `content/10-domain/research/sources.md` (бэклог research) и `content/00-project/roadmap.md` (создаст PM на этапе 3 после Phase 0 research).

## Технологический стек (фиксированный)

| Слой | Технология |
|------|------------|
| Платформа | Naumen SMP (script-module, JAR) |
| Прикладной продукт-потребитель | ITSM 365 Support |
| СУБД | PostgreSQL + расширение [pgvector](https://github.com/pgvector/pgvector) — доступ из JAR через **Hibernate `SessionFactory`** (Spring `beanFactory.getBean('sessionFactory')`); прямой JDBC и `org.postgresql.*` зависимости в JAR запрещены |
| Языки | Groovy 3.0.21, Java 21 |
| Embeddings / LLM | Yandex Cloud Foundation Models (модели для эмбеддингов и генеративные) |
| Сборка | Maven (mirror `https://mvn.naumen.ru/repository/naumen-public`) |
| Деплой | SMPS-утилита → JAR в SMP-инстанс (стенд `llm2`) |
| IDE | VS Code + Claude Code |
| VCS | GitLab |

JAVA_HOME для сборки: `/opt/homebrew/opt/openjdk@21` (см. эталонный проект ниже).

## Доступ к окружению

- **PostgreSQL/pgvector:** из JAR-модуля доступ через **Hibernate `SessionFactory`** — `beanFactory.getBean('sessionFactory').getCurrentSession()`. Паттерн `script-as-binding-carrier`: SMP script-module (`public/*.groovy`) держит binding (`api`, `beanFactory`, `modules`) и передаёт в JAR через конструктор класса-обёртки `HibernateSessionProvider` в `adapters/db/` (по образцу `SmpSuperUserRunner` из эталонного `naumen-smp-mcp`). DDL — через `session.doWork { Connection -> ... }`, native pgvector-операторы (`<=>`) — через `session.createNativeQuery(...)`. **Запрещено:** прямые JDBC-зависимости (`org.postgresql.*`) в `pom.xml` JAR-а; `@InjectApi` в JAR-классах (компилируется, но runtime-поля null — известное ограничение). DB-user на стенде `llm2` = `llm2`; single-tenant.
- **Naumen SMP — метамодель и данные:** MCP-инструмент **`naumen-smp-dev-admin`** (доступен в этой сессии). Используется для получения структуры классов/атрибутов SMP, поиска объектов, работы с заявками/обращениями/услугами/KB, экспорта метамодели (`metamodel_export_class`, `metamodel_export_tree`).
- **Деплой и тесты на стенде:** утилита **`smps`** → стенд **`llm2`** (LLM-инстанс SMP). Точные команды smps уточняются на этапе `/devops`.
- **Yandex Cloud:** работа через CLI **`yc`** — для создания сервисных аккаунтов, API-ключей, доступа к Foundation Models (embedding и generative). До первого `/dev`-таска нужен настроенный профиль `yc` и сервисный аккаунт с ролью на Foundation Models.

## Источники документации (context7 / ctx7)

Подключаются по требованию через `npx`. При первом обращении к теме — `/research` сначала тянет соответствующий skill:

```bash
npx ctx7 skills search "Yandex Cloud"   # эмбеддинги, generative API, IAM, yc CLI
npx ctx7 skills search "Pgvector"        # типы индексов (HNSW/IVFFlat), операторы, тюнинг
```

Дополнительно подключать по мере появления тем (LangChain-обвязки, evaluation, и т. д.) — список расширяется в `content/10-domain/research/sources.md`.

## Эталонный проект

`/Users/mdemyanov/Devel/naumen-smp-mcp` — production SMP-модуль (MCP-сервер) на том же стеке. Используется как референс по:
- Hexagonal Architecture (Ports & Adapters) + DDD
- Структура `pom.xml`, конфигурация `target/<name>-X.Y.Z.jar`
- CodeNarc + jar-secrets-scan + `mvn verify`
- Раскладка `content/` (ADR, требования, архитектура, runbooks)
- Контракт SPI, версионирование (см. `content/00-project/adr/013-platform-versioning.md` в эталоне)

Смотреть **до** проектирования аналогичных подсистем здесь, чтобы не изобретать паттерны заново.

## Команда AI-агентов

Работаешь в Claude Code как **PM/координатор** (main-context, Opus). Содержательная ролевая работа делегируется субагентам через slash-команды.

| Команда | Роль | Где исполняется | Артефакты |
|---------|------|----------------|-----------|
| `/pm`   | PM (orchestrator) | main (Opus) | Декомпозиция, координация, roadmap |
| `/pm-review` | PM | main (Opus) | Валидация `content/` перед merge |
| `/research` | Researcher | subagent (Sonnet) | `content/10-domain/research/` |
| `/ba`   | BA  | subagent (Sonnet) | `content/30-requirements/` |
| `/sa`   | SA  | subagent (Sonnet) | `content/00-project/adr/`, `content/40-architecture/` |
| `/dev`  | Dev | subagent (Sonnet) | `src/`, `content/60-implementation/` |
| `/devops` | DevOps | subagent (Sonnet) | `content/70-operations/` |
| `/itsm` | ITSM-аналитик (консультант) | subagent (Sonnet) | `content/10-domain/itsm-reviews/` или inline-review (НЕ пишет в `30-requirements/` / `40-architecture/` / ADR) |

Полная матрица ролей и контракт вызова субагентов — в [AGENTS.md](AGENTS.md). Канонический поток: **Researcher (опц.) → BA → SA → Dev → DevOps**. ITSM-аналитик — опциональный консультант, вызывается на любом этапе по триггерам ITSM-терминологии.

## Подключённые плагины

- **gramax@ai-assistants** — `gramax:writer`, `gramax:comments-read`, `gramax:comments-write`
- **superpowers@claude-plugins-official** — `brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development`, `test-driven-development`, `systematic-debugging`, `verification-before-completion`, и др.
- **project@local** — агенты PM/BA/SA/Dev/DevOps/Researcher + локальные скиллы

Дополнительно используется глобальный плагин **`naumen-smp-scripting`** для Groovy-скриптов SMP.

## Когда какой скилл звать

| Ситуация | Скилл |
|----------|-------|
| Создание/редактирование статьи Gramax | `gramax:writer` |
| Чтение/ответ на комментарии Gramax | `gramax:comments-read`, `gramax:comments-write` |
| Любая многошаговая задача (фича, рефакторинг) | `superpowers:brainstorming` → `writing-plans` → `executing-plans` |
| Любой баг/непонятное поведение | `superpowers:systematic-debugging` |
| Реализация фичи или фикса | `superpowers:test-driven-development` |
| Перед claim'ом «готово» | `superpowers:verification-before-completion` |
| Groovy-скрипт SMP (utils/api/HQL) | `naumen-smp-scripting` |
| Адаптация текста под инфостиль | `infoinstyle` |
| ITSM-вопрос: incident/problem/KB/SLA/RCA, выбор AI-сигналов оператора | `/itsm` (консультант, не заменяет BA/SA) |

## Ветвление

- `private` — рабочая ветка, все правки.
- `public` — публикация в Gramax, мерж только после `/pm-review`.

## Команды сборки и проверки (актуализировать после первого `/dev`)

Когда появится `pom.xml`, использовать паттерн эталона:

```bash
# Компиляция
JAVA_HOME=/opt/homebrew/opt/openjdk@21 mvn clean compile

# Тесты
JAVA_HOME=/opt/homebrew/opt/openjdk@21 mvn test

# Полная сборка + CodeNarc + jar-secrets-scan
JAVA_HOME=/opt/homebrew/opt/openjdk@21 mvn verify
```

Деплой в SMP — через **SMPS-утилиту** (DevOps-инструмент). Подробности (путь, профили, окружения) уточняются у пользователя на этапе `/devops`.

## Стек Naumen SMP

- Платформа: Naumen SMP — FQN-объекты; из script-модулей доступ через `api.db.query` (HQL read-only) и REST `/find`/`/get`/`/edit`/`/create`; из JAR-модулей — через Hibernate `SessionFactory` (Spring `beanFactory.getBean('sessionFactory')`).
- Документация локально: `/Users/mdemyanov/Devel/naumen-ecosystem/naumen-smp`, `/Users/mdemyanov/Devel/naumen-ecosystem/itsm365`
- Эталонный проект: `/Users/mdemyanov/Devel/naumen-smp-mcp`

### DDD-карта (SMP)

| DDD | Реализация в SMP |
|---|---|
| Bounded Context | Сценарий / модуль |
| Aggregate | SMP-объект (FQN) |
| Repository | HQL-запрос или REST `/find` |
| Anti-Corruption Layer | Mapper SMP JSON → DTO |
| Domain Event | Событие SMP (action / status change) |

## Красные линии

**Универсальные:**
- НЕ публиковать секреты (`.env`, токены, API-ключи Yandex Cloud, credentials БД)
- НЕ включать PII клиентов и заявителей (реальные ФИО, тексты обращений, контакты, данные из реальных заявок). Внутренние контакты команды Naumen (email `*@naumen.ru`, Telegram-handles) в `content/00-project/stakeholders.md` и `owner-questions/` — **допустимы** для PoC: Gramax-public живёт внутри корпоративного периметра, наружу не уходит. При выходе на Pilot/Production — пересмотреть.
- НЕ менять `.doc-root.yaml` и `.gramax/` без согласования (через SA + ADR)
- НЕ создавать статьи в `content/` без обязательных properties (см. `content/.doc-root.yaml`)
- НЕ принимать задачи `/dev` без предшествующего артефакта SA (`content/40-architecture/` или ADR)
- Tests / CodeNarc / jar-secrets-scan — зелёные перед commit

**SMP-специфичные:**
- HQL и native SQL — **только параметризованные** (`setParameter`); интерполяция строк запрещена. Vector-аргумент — через `setParameter('vec', '[…]')` + `CAST(:vec AS vector(N))`.
- `@InjectApi` — только в SMP script-модулях (`public/*.groovy`). **В JAR-классах не работает** (компилируется, но runtime null) — используем паттерн `script-as-binding-carrier`: script передаёт `api`+`beanFactory` в JAR через конструктор Runner-класса (см. `naumen-smp-mcp/SmpSuperUserRunner` как эталон).
- Error responses наружу — **без stack traces**; stack → в лог с `correlationId`
- Cross-каталожные Gramax-ссылки — **только inline code** `` `path/to/file.md` ``, не markdown `[text](path)` (Gramax не резолвит cross-каталожные ссылки)
- ADR supersede — **НЕ** менять статус старого ADR без sign-off PM
- В tool/handler-методах SMP — обязательно `try/catch (Throwable) + logger.error(msg, e) + throw e` (SMP не логирует uncaught exceptions автоматически)

**Проектные (vectorization):**
- Векторы и сырые тексты, отправляемые в Yandex Cloud, проходят через явный список разрешённых атрибутов — никакой автоматической отправки всего объекта целиком (риск утечки PII).
- Размерность вектора и название модели эмбеддингов — фиксируются в ADR; при смене модели — миграция векторной таблицы (новый ADR со ссылкой на superseded).
- **Доступ к БД — через Hibernate `SessionFactory`** (`beanFactory.getBean('sessionFactory')`). Прямые JDBC-зависимости (`org.postgresql.*`) в `pom.xml` или коде JAR — запрещены архитектурно ([ADR-002](content/00-project/adr/002-smp-only-data-access.md), DEV-004 `JdbcImportBanSpec`). Integration-тесты адаптера БД — через **testcontainers с pgvector** (in-memory H2 не подходит).

## Справочные пути

- Внешний marketplace плагинов: `mdemyanov/ai-assistants`
- Maven mirror Naumen: `https://mvn.naumen.ru/repository/naumen-public` (требуется в `~/.m2/settings.xml`)
- pgvector: https://github.com/pgvector/pgvector
- Yandex Cloud Foundation Models: docs тянутся через `npx ctx7 skills search "Yandex Cloud"`
- pgvector best-practices: `npx ctx7 skills search "Pgvector"`
- MCP инструмент SMP: `naumen-smp-dev-admin` (метамодель, объекты, KB)
- Стенд для smoke-тестов: `llm2` (через `smps`)

## Self-improvement

- `docs/lessons-learned.md` — append-only журнал
- Субагенты сохраняют находки в auto-memory (типы: `reference`, `project`, `feedback`)
- `/pm-review` читает lessons + memory и предлагает обновления CLAUDE.md / промтов агентов

## План запуска

| Phase | Что | Артефакт | Кто |
|-------|-----|----------|-----|
| 0.1 ✅ | Init шаблона + SMP overlay + CLAUDE.md | этот файл | PM |
| 0.2 ✅ | Стейкхолдеры | `content/00-project/stakeholders.md` | PM |
| 0.3 ✅ | Бэклог research | `content/10-domain/research/sources.md` (RES-001…RES-008) | PM |
| 0.4 | Подтвердить с Сахабетдиновым: ✅ pgvector **0.8.1** на `llm2` подтверждён 2026-05-01; согласование схемы под векторы (ADR-004) и исходящий доступ к `*.api.cloud.yandex.net` — в работе | пинг в Telegram + запись в issue/wiki | Демьянов |
| 0.5 ✅ | Настроить `yc` CLI: сервисный аккаунт `pg-vector-poc` + API-Key + профиль (folder `applied-office`) | `.env`, `.secrets/yc-api-key.json` (chmod 600, gitignored), `yc config list` | Демьянов + auto |
| 0.6 ✅ | RES-001: live-выгрузка метамодели `issue`, `knowledgeBase`, `problem` через MCP | `content/10-domain/research/smp-metamodel.md` | `/research` |
| 0.7 ✅ | RES-002 закрыт live-проверкой 2026-05-01 (text-search-doc/query, dim=256). RES-003 закрыт 2026-05-01 ручной выгрузкой прайса с `aistudio.yandex.ru`: эмбеддинг 0,0101 ₽ / 1 тыс. юнитов, медиана PoC ≈ 200 ₽/тенант. | `yc-foundation-models.md`, `yc-pricing.md`, `ADR-010` | `/research` + main |
| 0.8 ✅ | RES-004…008 (pgvector, eval, кластеризация, scheduled jobs, эталон) | все файлы в `content/10-domain/research/` | `/research` |
| 1 | BA — JTBD, AC, NFR на 3 use case'а; whitelist векторизуемых атрибутов с PII-аудитом | `content/30-requirements/` | `/ba` |
| 2 | SA — принципиальная архитектура, ADR (модель эмбеддинга, индекс pgvector, sync vs job, версионирование, схема таблицы), контракт SPI | `content/40-architecture/`, `content/00-project/adr/` | `/sa` |
| 3 | PM — roadmap (PoC→MVP→Pilot→Prod) + backlog | `content/00-project/roadmap.md`, `content/00-project/backlog.md` | `/pm` |
| 4+ | Dev итерации с smoke на `llm2` после каждой | `src/`, `content/60-implementation/`, smoke-reports в `content/70-operations/` | `/dev` + `/devops` |

### Phase 0 — pre-flight

**Блокеры**, без которых не запускаем `/ba`:
- 0.4 — подтверждение Сахабетдинова про pgvector + сетевой доступ (отвечено owner'ом, требует письменного следа от DevOps)
- 0.5 — рабочий `yc` CLI с доступом к Foundation Models
- 0.6 — выгруженная метамодель целевых классов (без неё BA не сможет назначить whitelist атрибутов)

**Не блокеры, но желательно до `/ba`:** 0.7 (бюджет — даёт raison d'être PoC) и 0.8 (исследования — закрывают «открытые вопросы» SA, чтобы не возвращаться).

### Этапы из ТЗ → mapping

| ТЗ-этап | Где живёт |
|---------|-----------|
| 1. Цели и задачи | Phase 1 BA (`content/30-requirements/`) — на основе уже зафиксированных в этом файле сценариев |
| 2. Предварительная BA + SA + принципиальная архитектура | Phases 1-2 |
| 3. Roadmap и backlog | Phase 3 |
| 4. Последовательная реализация с проверкой на каждом шаге | Phase 4+ — каждая Dev-итерация заканчивается smoke на `llm2`, фиксируется в `content/70-operations/smoke-reports/` |

## Следующий шаг

Закрыть Phase 0.4 и 0.5 (на стороне owner'а), параллельно запустить Phase 0.6 (RES-001) — у меня есть прямой доступ к MCP `naumen-smp-dev-admin`, могу начать выгрузку сразу. Команда:

```
/research RES-001: выгрузить метамодель классов issue (с подклассами), knowledgeBase, problem 
со стенда llm2 через MCP naumen-smp-dev-admin. Артефакт: 
content/10-domain/research/smp-metamodel.md в формате эталона 
/Users/mdemyanov/knowlage/sd-ai-assistant/content/50-integrations/smp-mcp/pirelli-metamodel.md.
```

Скажи «погнали» — запущу `/research` на RES-001 прямо сейчас. Параллельно — 0.4 (Сахабетдинов) и 0.5 (yc CLI) на твоей стороне.
