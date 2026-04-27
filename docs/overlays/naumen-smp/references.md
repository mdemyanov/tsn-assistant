# Справочные пути и ссылки (Naumen SMP)

## Локальные репозитории

- `/Users/mdemyanov/Devel/naumen-ecosystem/naumen-smp` — основная документация SMP
- `/Users/mdemyanov/Devel/naumen-ecosystem/itsm365` — документация ITSM365
- `/Users/mdemyanov/Devel/naumen-smp-mcp` — эталон MCP-сервера для SMP (Hexagonal Architecture, Groovy + Java 21)
- `/Users/mdemyanov/knowlage/sd-ai-assistant` — эталон AI-ассистента руководителя SD на CrewAI

## Внутренние ресурсы

- Maven mirror: `https://mvn.naumen.ru/repository/naumen-public` (требуется в `~/.m2/settings.xml`)
- CodeNarc-конвенции: проект-зависимые (метод ≤20 строк, класс ≤200 строк — типичный default)

## Платформенные red-lines (SMP)

- Java 21: `JAVA_HOME=/opt/homebrew/opt/openjdk@21`
- Groovy 3.0.21
- HQL — read-only через `api.db.query`
- Reserved Groovy methods (нельзя использовать в SPI): `getMetaClass`, `getProperty`, `setProperty`, `invokeMethod`, `getMetaPropertyValues`

## Глобальный плагин

- `naumen-smp-scripting` — skill для разработки Groovy-скриптов SMP
