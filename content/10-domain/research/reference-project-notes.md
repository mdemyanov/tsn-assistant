---
order: 8
title: Эталонный проект naumen-smp-mcp — заметки
properties:
  - Тип контента: Исследование
  - Фаза: PoC
  - Статус: Draft
---

## Резюме

Эталонный проект `naumen-smp-mcp` — production-grade MCP-сервер (Groovy 3.0.21, Java 21, Maven). Копируем **целиком**: `pom.xml`-структуру (Groovy/Java/Maven/plugins), раскладку `src/` (hexagonal: `adapters/`, `core/`, `ports/`, `spi/`), CodeNarc-пороги (метод ≤20, класс ≤200, P1=0), тесты (JUnit 5 + Mockito), структуру `content/` (00-project, ADR). Адаптируем для вектор-домена: специализируем `adapters/smp` (вместо SMP API-маршалинга — работа с pgvector), ядро `core/` (вместо MCP JSON-RPC dispatch — API для хранения/поиска эмбеддингов), `spi/` (публичный контракт для tool-pack'ов). **Исключаем**: MCP-специфичное (JSON-RPC transport, session management, handshake, protocol version) — эти части переходят в отдельный транспортный адаптер за границами ядра.

---

## 1. Структура pom.xml

**Группа**: `ru.naumen.modules`  
**Версия**: SemVer (`X.Y.Z-SNAPSHOT`); API версия SMP `4.19.0.25`  
**Целевые версии**: Groovy 3.0.21, Java 21, Maven 3.11.0

### Ключевые плагины (в `<build><plugins>`):

```xml
<!-- Groovy compilation via maven-antrun-plugin -->
<plugin>
  <artifactId>maven-antrun-plugin</artifactId>
  <version>3.1.0</version>
  <executions>
    <execution id="compile">
      <phase>compile</phase>
      <!-- groovyc taskdef, srcdir=src/main/groovy/ru/naumen/modules -->
      <!-- targetBytecode=21, indy=true (invokedynamic) -->
    </execution>
    <execution id="test-compile">
      <!-- аналогично для src/test/groovy -->
    </execution>
```

- **jar-secrets-scan** (phase: verify) — сканирует JAR на patterns, вызывает `codenarc/jar-secrets-scan.groovy`
- **CodeNarc** (phase: verify) — линтинг ruleset'а из `codenarc/ruleset.groovy`; maxP1=0, maxP2=0 (или параметр `codenarc.maxP2`)
- **maven-surefire-plugin** (v3.0.0-M7) — JUnit 5 тесты; паттерны `**/*Spec.class`, `**/*Test.class`; argLine с `--illegal-access=permit`

```xml
<packaging>jar</packaging>
<!-- target/mcp-X.Y.Z.jar или target/mcp-X.Y.Z-SNAPSHOT.jar -->
```

Зависимости: SMP API (script-api-context, sdng — scope provided), Groovy, JUnit 5 (test), Mockito (test), Jackson (provided, >= 4.18.0), OWASP dependency-check.

### Свойства:
- `<maven.compiler.source>21</maven.compiler.source>`
- `<maven.compiler.target>21</maven.compiler.target>`
- `<groovy.version>3.0.21</groovy.version>`
- `<codenarc.version>3.7.0</codenarc.version>`
- `<codenarc.maxP2>0</codenarc.maxP2>`

**Для pg_vector_service**: адаптировать зависимости (добавить pgvector JDBC-драйвер, Yandex Foundation Models SDK), остальное копировать 1:1.

---

## 2. Раскладка src/

```
src/main/groovy/ru/naumen/modules/mcp/
├── adapters/
│   ├── json/         # JSON codec (Jackson; не MCP-зависимый)
│   ├── smp/          # ACL: SMP Object → Domain DTO (mappers, @InjectApi)
│   └── transport/    # HTTP/REST (McpRestHandler, SessionResolver, CORS)
├── core/             # Доменное ядро (без зависимостей от SMP, MCP)
│   ├── boundary/     # SmpApiWhitelist — белый лист вызовов в SMP API
│   ├── dispatch/     # Method dispatch (MethodDispatcher, handlers)
│   ├── formatting/   # Преобразования (converters)
│   ├── protocol/     # JSON-RPC парсинг, error codes, version
│   ├── registry/     # Tool registry
│   ├── session/      # Session management
│   └── validation/   # Валидация запросов
├── config/           # Bootstrap, DI container
├── facade/           # Фасад для ядра (Facade pattern)
├── ports/            # Интерфейсы (порты) для адаптеров
│   ├── AuthenticationPort
│   ├── SessionStoragePort
│   ├── TransactionRunner
│   └── ...
├── spi/              # Публичный контракт (tool-pack'ов)
│   ├── ToolHandler (интерфейс)
│   ├── ResourceHandler (интерфейс)
│   └── formatting/
└── tools/            # Реализации tool-pack'ов (itsm/sdaiassistant/...)

src/test/groovy/    # Зеркалирует main структуру + integration/, testsupport/, architecture/
```

**Конвенция именования**:
- Classes: PascalCase (`McpRestHandler`, `SessionResolver`)
- Methods: camelCase
- Test files: `*Spec.groovy` (Spock) или `*Test.groovy` (JUnit 5)
- Interfaces: `*Port` или `*Handler` (в domain)

**Для pg_vector_service**:
- `adapters/pgvector/` — вместо `adapters/smp`: Postgres JDBC, pgvector[] типы
- `adapters/yandex-ai/` — API клиент для Yandex Foundation Models
- `core/vectorization/` — ядро (embedding, storage, search logic)
- `spi/` — контракт для tool-pack'ов (что-то типа `VectorProvider`, `EmbeddingStore`)

---

## 3. Hexagonal layout в SMP-проекте

**Правило**: только в `adapters/` и `config/` лежит `@InjectApi` (SMP API), в остальном коде — ноль зависимостей от SMP.

- **`adapters/smp/`** — маппер-слой: SMP Object (JSON) → Domain DTO. Если есть `SmpApiFacade` (SDN API), она инжектируется сюда, НЕ в core.
- **`core/`** — бизнес-логика (dispatch, registry, validation). Тесты не требуют SMP runtime.
- **`ports/`** — интерфейсы (`interface SessionStoragePort`); реализации в `adapters/`.
- **`spi/`** — стабильный контракт для плагинов (не зависит от версии SMP).
- **`config/`** — `McpModuleBootstrap` (точка входа), инициализация DI.

**ACL (Anti-Corruption Layer)**: в `adapters/smp/` размещены классы-трансформеры (например, `SmpObjectToToolDto`), преобразующие SMP JSON в Domain DTO. Domain код оперирует только DTO, не знает о сыром JSON.

**Для pg_vector_service**: аналогичная архитектура, но вместо SMP-маппинга — маппинг из Postgres результатов в Domain эмбеддинги.

---

## 4. Раскладка content/

```
content/
├── 00-project/          # Мета: goals, roadmap, tech-debt, ADR (001..029)
├── 10-domain/           # Domain-driven content (requirements, scenarios, decision logs)
├── 20-scenarios/        # Use cases
├── 30-requirements/     # Functional & non-functional requirements
├── 40-architecture/     # Architecture decisions, SPI reference
├── 50-integrations/     # Integrator guide, tool-pack docs
├── 60-implementation/   # Feature branches, implementation notes
├── 70-operations/       # Runbooks, deployment, smoke-reports, monitoring
├── 80-testing/          # Test plans, test data
└── 90-knowledge-base/   # FAQ, troubleshooting
```

**ADR нумерация**: 001-029 (примеры: 001-hexagonal-architecture, 013-platform-versioning). Первое число фиксирует тему (001-010 = архитектура, 011-020 = интеграция, 021-029 = операции).

**`.doc-root.yaml`**: Gramax-каталог; определяет порядок и метаданные.

**Для pg_vector_service**: скопировать структуру, добавить в 00-project/adr свои ADR (например, 001-vectorization-strategy, 002-pgvector-storage-model).

---

## 5. CodeNarc пороги

**File**: `codenarc/ruleset.groovy`

```groovy
ruleset('rulesets/size.xml') {
  'ClassSize' { maxLines = 200 }      # Класс не больше 200 строк
  'MethodSize' { maxLines = 20 }      # Метод не больше 20 строк
  'ParameterCount' { maxParameters = 5 }  # Макс 5 параметров
}
```

**Other rules**: Basic, Braces, Convention (кроме `NoDef`, `CompileStatic`), Design, Exceptions, Formatting, Imports, Naming (исключён `FactoryMethodName`), Size, Unused.

**Violations limits** (в pom.xml):
```xml
<maxPriority1Violations>0</maxPriority1Violations>
<maxPriority2Violations>0</maxPriority2Violations>  <!-- или ${codenarc.maxP2} -->
```

**Для pg_vector_service**: копировать целиком.

---

## 6. SPI versioning (ADR-013)

**Три поверхности**:

1. **JAR SemVer** (`mcp-X.Y.Z.jar`):
   - **MAJOR** — breaking change в публичном SPI или MCP-протоколе
   - **MINOR** — back-compat additions (новые методы, новые implementations)
   - **PATCH** — bug fixes, security, no contract change
   - Pre-release: `-SNAPSHOT`, `-rc.N`

2. **Публичный SPI** (пакет `ru.naumen.modules.mcp.spi.*`):
   - Стабилен в рамках одного MAJOR
   - Добавление метода в interface — **всегда MAJOR** (кроме `@DefaultImpl` / default methods)
   - Удаление, переименование, изменение сигнатуры — **MAJOR**
   - Deprecation flow: `@Deprecated(since = "X.Y")` → оставить одну MINOR → удалить в MAJOR

3. **MIN_SMP_VERSION contract**:
   - JAR декларирует `McpConfig.MIN_SMP_VERSION` (М25 = `4.18.0`)
   - SMP < MIN_SMP_VERSION → bootstrap fails
   - MAJOR-bump может повысить MIN_SMP_VERSION
   - MINOR/PATCH — только понизить или оставить

**Для pg_vector_service**: адаптировать под свой SPI (например, `EmbeddingStore` вместо `ToolHandler`); принцип SemVer сохраняется.

---

## 7. Smoke-report формат

**Location**: `content/70-operations/smoke-reports/`

**Файл**: `YYYY-MM-DD-<envname>-<brief>.md` (YAML фронт, Markdown)

```yaml
---
order: 30
title: Smoke-report 2026-04-23 llm2 (M33 hotfix)
properties:
  - name: Слой
    value: [Общее]
  - name: ТипКонтента
    value: [Операции]
  - name: Фаза
    value: [Stabilization]
  - name: Статус
    value: [Черновик]
---
```

**Содержание**:
- Стенд, JAR версия, Branch, Оператор, Дата прогона
- Таблица pre-deploy проверок (cleanup, tests, CodeNarc, jar-secrets-scan, deployment)
- Таблица результатов (S1..S20 сценариев): PASS/FAIL с кратким комментом
- Известные issues/TD (Temporary Defects), ссылка на runbook

**Примеры**: `/Users/mdemyanov/Devel/naumen-smp-mcp/content/70-operations/smoke-reports/2026-04-23-llm2-m33.md`, `2026-04-25-llm2-m38.md`.

**Для pg_vector_service**: использовать тот же формат для smoke-testing vectorization на разных backend'ах (PG 14+, YandexGPT3.5/4).

---

## 8. Out of scope для pg_vector_service

**НЕ копируем**:
- **MCP JSON-RPC transport** (`adapters/transport/McpRestHandler`, `McpHttpRequest/Response`, `RequestAuthenticator`) — это специфично для MCP protocol
- **MCP-специфичные handlers** (`core/dispatch/InitializeHandler`, `ToolsListHandler`, `ResourcesReadHandler`) — MCP-команды
- **Session management** (`core/session/SessionStorage`, `SessionResolver`) — MCP концепция
- **Protocol version** (`core/protocol/ProtocolVersion`) — MCP 2024-11-05 specific
- **Tool registry as MCP concept** (`core/registry/ToolRegistry`) — переструктурировать для embedding registry
- **MCP-специфичные SPI** (`spi/ToolHandler`, `ResourceHandler`) — заменить на `VectorProvider`, `EmbeddingStore`

**Копируем**:
- pom.xml структура + плагины
- src/ layout (adapters/, core/, ports/, spi/, config/)
- CodeNarc-конфиг
- Тестовую инфраструктуру (JUnit 5 + Mockito)
- content/ структура (00-project, 10-domain, 70-operations, ADR)
- Smoke-report формат
- Hexagonal architecture principles
- SemVer versioning + ADR mechanism

---

**Ссылки в эталоне**:
- ADR-013: `/Users/mdemyanov/Devel/naumen-smp-mcp/content/00-project/adr/013-platform-versioning.md`
- ADR-001 (hexagonal): `/Users/mdemyanov/Devel/naumen-smp-mcp/content/00-project/adr/001-hexagonal-architecture.md`
- Smoke-report пример: `content/70-operations/smoke-reports/2026-04-23-llm2-m33.md`
- CodeNarc ruleset: `/Users/mdemyanov/Devel/naumen-smp-mcp/codenarc/ruleset.groovy`
- pom.xml: `/Users/mdemyanov/Devel/naumen-smp-mcp/pom.xml` (l.1-272)
