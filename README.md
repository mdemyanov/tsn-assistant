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
