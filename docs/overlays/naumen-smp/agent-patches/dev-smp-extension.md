## SMP-расширение

### Стек

- **Groovy 3.0.21 + Java 21** (`JAVA_HOME=/opt/homebrew/opt/openjdk@21`)
- **Maven** (требуется mirror `https://mvn.naumen.ru/repository/naumen-public` в `~/.m2/settings.xml`)
- **JUnit 5 + Mockito** для тестов
- **CodeNarc** для линтинга (приоритет 1/2 = 0)

### Команды сборки и проверки

```bash
JAVA_HOME=/opt/homebrew/opt/openjdk@21 mvn clean compile      # Компиляция
JAVA_HOME=/opt/homebrew/opt/openjdk@21 mvn test               # Тесты
JAVA_HOME=/opt/homebrew/opt/openjdk@21 mvn verify             # Полная проверка: тесты + CodeNarc
JAVA_HOME=/opt/homebrew/opt/openjdk@21 mvn dependency-check:check  # OWASP (долго при первом запуске)
```

### Groovy reserved methods (НЕ использовать в SPI)

Эти имена зарезервированы `groovy.lang.GroovyObject` — конфликт ломает имплементацию интерфейса:

- `getMetaClass()` → используй `getPrimaryMetaClass()`
- `getProperty()` → используй `getDomainProperty()`
- `setProperty()` → переименуй
- `invokeMethod()` → переименуй
- `getMetaPropertyValues()` → переименуй

### MCP tool handler — обязательный паттерн

В методе `call()` MCP-инструмента **всегда**:

```groovy
@Override
Map call(Map args) {
  try {
    // ... основная логика ...
    return result
  } catch (Throwable e) {
    logger.error("tool ${toolName} failed: ${e.message}", e)
    throw e
  }
}
```

**Почему:** SMP не логирует uncaught exceptions автоматически. Без этого паттерна диагностика будет слепой (только `-32603` в JSON-RPC ответе).

### Hexagonal boundary check

Если проект использует Hexagonal Architecture:
- `core/` — НЕ импортирует `ru.naumen.*` (кроме `core.*`/`ports.*`)
- `@InjectApi` — только в `adapters/smp/`
- Нарушение boundary — ловится `CoreBoundarySpec` (или аналогом). Запускай при каждом mvn test.

### CodeNarc лимиты

- Метод ≤20 строк
- Класс ≤200 строк

Превышение — рефактори до commit. Не отключай правило, не используй `@SuppressWarnings`.

### HQL — только параметризованный

```groovy
// ❌ ПЛОХО — SQL-инъекция, broken по интерполяции спецсимволов
def q = "SELECT t FROM serviceCall t WHERE t.subject = '${userInput}'"

// ✅ ХОРОШО
def q = "SELECT t FROM serviceCall t WHERE t.subject = :subject"
api.db.query(q).setParameter('subject', userInput).list()
```

### Error responses наружу

- НИКОГДА stack traces в ответе клиенту (даже HTTP 500)
- Stack → в лог с `correlationId`
- Клиенту — `{ "error": "<неинформативное_сообщение>", "correlationId": "<id>" }`
