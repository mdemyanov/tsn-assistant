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
