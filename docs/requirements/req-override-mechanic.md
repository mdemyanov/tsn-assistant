---
properties:
  - name: Тип контента
    value: [Требование]
  - name: Статус
    value: [Approved]
---

# REQ: Override mechanic для агент-промтов

## Контекст

Профили project_template имеют разные ролевые контексты (kb-product — customer-facing docs, methodology — playbook, course — обучение). Базовые промты в `.claude/plugins/project/agents/<role>-agent.md` generic. Без override-механики либо all promts generic (плохо), либо профиль вынужден копировать base в override (drift).

## Функциональные требования

### FR-1: Override через extends

Профиль может объявить override базовой роли через файл `agent-overrides/<role>.md` с YAML frontmatter `extends: <role-name>`.

**AC-1.1:** Если override содержит frontmatter `extends: tech-writer`, resolver распознаёт связь с base `.claude/plugins/project/agents/tech-writer-agent.md`.

**AC-1.2:** Если `extends:` не совпадает с именем роли (или роли не существует) — validator M11 даёт error до commit'а.

### FR-2: Section-level merge

Секция `## Heading` в override **полностью замещает** одноимённую секцию base. Секции base без override наследуются. Секции override без base добавляются в конец.

**AC-2.1:** Heading match — exact (case + whitespace + punctuation чувствительны).

**AC-2.2:** `{{super}}` placeholder в секции override — resolver подставляет содержимое одноимённой секции base.

**AC-2.3:** `{{super}}` в секции, отсутствующей в base — validator M11.5 даёт error.

### FR-3: Frontmatter merge

Scalar-поля override (`description`, `model`) **заменяют** base. List-поля (`tools`, `disallowedTools`, `skills`) — **полностью заменяют** (по образцу Helm для arrays).

**AC-3.1:** Поля без переопределения наследуются из base.

**AC-3.2:** Override может содержать `description: "..."` — кратко что меняет, опционально.

### FR-4: Resolved file marker

Resolved файл начинается с HTML-комментария `<!-- GENERATED ... -->` указывающего источник + команду для regenerate.

**AC-4.1:** Маркер виден в IDE при открытии resolved файла.

**AC-4.2:** Маркер не нарушает Claude Code subagent loading (frontmatter после маркера парсится корректно).

### FR-5: Validation (M11)

`validate-profile.py` M11 проверяет 5 sub-cases:

- M11.1: base prompt существует
- M11.2: override source path существует
- M11.3: `extends:` совпадает с именем роли
- M11.4: роль не disabled в `subagents`
- M11.5: `{{super}}` только в секциях, существующих в base

**AC-5.1:** Каждое M11 error содержит путь к проблемному файлу + предложение fix'а.

## Anti-scope

- ❌ Multiple inheritance (`extends: [a, b]`)
- ❌ Section reordering (`before:` / `after:`)
- ❌ Heading normalization (case-insensitive)
- ❌ Override без base (override как стандалонный prompt)
