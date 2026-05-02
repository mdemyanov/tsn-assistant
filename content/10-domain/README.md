# 10-domain — Доменная модель

Ubiquitous Language проекта и материалы по домену: глоссарий, исследования, контекст-карта.

## Структура

- `glossary.md` — Ubiquitous Language (термины, используемые в требованиях, архитектуре и коде)
- `itsm-knowledge.md` — расширенный glossary для ITSM-аналитика (ITIL/KCS/vendor practice)
- `research/` — выжимки Researcher'а (создаётся при первом запуске `/research`)
- `itsm-reviews/` — mini-обзоры ITSM-аналитика для сложных кейсов (создаётся при первом `/itsm mini-review`)
- `context-map.md` — контекст-карта BC (опционально, при необходимости)
- `domain-events.md` — каталог доменных событий (опционально)

## Правила

- Новый термин — через BA при формировании требования (`/ba glossary-add <term>`).
- Research-выжимки — через `/research`, артефакты в `research/<slug>.md`.
- ITSM-обзоры — через `/itsm`, артефакты в `itsm-reviews/<slug>.md` (только для сложных кейсов; обычные ревью — Gramax-комментарием или inline).
- Контекст-карта и domain-events — создаются SA при стратегическом DDD.
