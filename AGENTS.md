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
