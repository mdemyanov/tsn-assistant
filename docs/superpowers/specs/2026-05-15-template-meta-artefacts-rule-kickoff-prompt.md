# Template Meta-Artefacts Rule — Kickoff Prompt для PM

**Дата:** 2026-05-15
**Назначение:** передать PM шаблона project_template как вход для `/pm decompose`
**Контекст:** микро-эпик ~10 минут. Формализовать урок, который уже зафиксирован в lessons-learned **4 раза** (W2, W4b, uv-enforce, spdd-integration), но всё ещё повторяется в каждом новом эпике.

---

## Промпт (передать PM как есть)

```
/pm decompose: формализовать правило «артефакты эпика про сам шаблон
→ docs/, не content/» в CLAUDE.md и base-промтах BA/SA

## Контекст и мотивация

Шаблон project_template развивает САМ СЕБЯ через эпики (Wave 1..5).
Каждый эпик производит артефакты: research, требования, ADR, design-spec,
test plan, acceptance report. У этих артефактов два возможных места:

- `content/` — Gramax-каталог шаблона (baseline scaffold + примеры)
- `docs/` — internal-документация шаблона (не публикуется как Gramax-knowlage)

Правильное место для **эпик-артефактов про сам шаблон** — `docs/`. Если
положить их в `content/`, baseline шаблона нарушается:
- `T-W4b-BASELINE` ловит это (ожидает `content/` = {`_index.md`, `.doc-root.yaml`})
- `T-INIT-PROFILE-KB` и `T-W4a-P4-noise` ломаются (overlay при apply
  не должен бороться с self-made разделами)

Урок зафиксирован в `docs/lessons-learned.md` **четыре раза:**
- 2026-05-07 Wave 2 (multi-template-landscape.md → docs/research/)
- 2026-05-07 Wave 4b (T2-fix перенос W4a framework docs в docs/)
- 2026-05-14 uv-enforce (PM-INTEG-1 relocate content/→docs/)
- 2026-05-14 spdd-integration (DEV-008 relocate, 4-й раз)

Каждый раз: BA/SA по умолчанию кладут в `content/{30-requirements,
40-architecture,00-project/adr}/` (потому что это формально правильно
для project-профиля), но это конкретный проект — НЕ шаблон.

Источники для контекста:
- `docs/lessons-learned.md` — все 4 записи (grep 'артефакты эпика'
  или 'docs/' в lessons-learned)
- `CLAUDE.md` — текущая структура, секции «Поток работы»,
  «Self-improvement», красные линии
- `.claude/plugins/project/agents/ba-agent.md` — base-промт BA
- `.claude/plugins/project/agents/sa-agent.md` — base-промт SA

## Scope: три точечные правки

### Изменение 1: новая секция в CLAUDE.md

**Где:** между секциями «Поток работы» и «Правило two-way sync»
(или в подходящем месте — на усмотрение Dev'а).

**Что:** новая короткая секция, формулировка примерно такая:

```markdown
## Правила работы над самим шаблоном

Шаблон project_template развивает сам себя через эпики. Артефакты этих
эпиков (research, требования, ADR, design-spec, test plan) живут в
`docs/`, **не** в `content/`.

| Артефакт эпика | Где живёт |
|----------------|-----------|
| Research-заметки | `docs/research/` |
| Требования (BRQ) | `docs/requirements/` |
| ADR | `docs/adr/` |
| Design-spec, plan, kickoff | `docs/superpowers/{specs,plans}/` |
| Test plan, acceptance report | `docs/requirements/` (рядом с BRQ) |
| Implementation notes | `docs/implementation/` |

**Почему:** `content/` — Gramax-каталог шаблона, его baseline должен
быть минимальным (`_index.md` + `.doc-root.yaml`). Эпик-артефакты в
`content/` ломают тесты T-W4b-BASELINE и T-INIT-PROFILE-*. `content/`
оставляем только под baseline scaffold + примеры, применимые ко всем
профилям.

**Когда правило НЕ применяется:** если ты работаешь не над шаблоном,
а над пользовательским проектом (инициализированным через `/init`) —
то `content/30-requirements/`, `content/40-architecture/`,
`content/00-project/adr/` — корректные места для требований / ADR
этого проекта.
```

### Изменение 2: bullet в ba-agent.md

**Где:** в раздел про создание артефакта (структура статьи /
обязательные шаги).

**Что:** добавить:

```markdown
- **Если работаешь над шаблоном project_template (репозиторий с
  `docs/overlays/profiles/` и `scripts/init.sh`) — артефакт BA живёт в
  `docs/requirements/`, не в `content/30-requirements/`.** См. CLAUDE.md
  § «Правила работы над самим шаблоном». В пользовательских проектах,
  инициализированных через /init — `content/30-requirements/` остаётся
  корректным местом.
```

### Изменение 3: bullet в sa-agent.md

Аналогично BA, но про ADR и design-spec:

```markdown
- **Если работаешь над шаблоном project_template — ADR в `docs/adr/`,
  design-spec в `docs/superpowers/specs/`, НЕ в `content/00-project/adr/`
  и `content/40-architecture/`.** См. CLAUDE.md § «Правила работы над
  самим шаблоном». Для пользовательских проектов — content/ остаётся.
```

## Acceptance criteria

1. CLAUDE.md содержит секцию «Правила работы над самим шаблоном» с
   таблицей и обоснованием.
2. ba-agent.md содержит bullet про docs/ vs content/ для шаблонной работы.
3. sa-agent.md содержит аналогичный bullet.
4. `bash scripts/test-template.sh` остаётся 206/206 green (правила
   документационные, не должны ломать тесты).
5. `uv run scripts/validate-content.py` — 0 errors.
6. `docs/lessons-learned.md` дополнен записью: «правило формализовано,
   урок закрыт; в новых эпиках BA/SA должны явно следовать правилу
   без напоминания».

## Что вне scope (НЕ делать)

- НЕ создавать новый тест-assert на анти-паттерн (это документационное
  правило, тесты T-W4b-BASELINE уже косвенно ловят нарушение).
- НЕ переписывать существующие entries в lessons-learned — только
  append новой записи.
- НЕ менять матрицу ролей и существующие промты глобально — точечные
  bullet'ы.
- НЕ создавать ADR (это не архитектурное решение, а documentation
  rule; формализация урока через CLAUDE.md достаточна).

## Делегирование (PM)

Это микро-эпик. Полный SDD pipeline не нужен. Рекомендую:

- /research — skip (контекст в lessons-learned)
- /ba — skip (AC уже сформулированы в этом промте)
- /sa — skip (не архитектурное решение)
- /dev — основная работа: 3 правки в 3 файлах (CLAUDE.md, ba-agent.md,
  sa-agent.md) + lessons-learned append. Можно одним коммитом или
  тремя — Dev решает.
- /qa --mode=runner — после Dev: прогон `test-template.sh` + validators
  для подтверждения, что documentation-правки ничего не сломали.

## Артефакты, которые ты создашь

1. Микро-план в `docs/superpowers/plans/2026-05-15-template-meta-
   artefacts-rule.md` (короткий, ≤80 строк).
2. PR в private → /pm-review → public с тремя точечными правками.
3. Запись в `docs/lessons-learned.md`.

## GO-критерии эпика

1. Все три правки сделаны (CLAUDE.md + 2 agent.md).
2. `test-template.sh` 206/206 green.
3. validate-content.py 0 errors.
4. lessons-learned дополнен.
5. merge private → public.

## Открытые вопросы (если возникнут — спроси меня перед декомпозицией)

- Где именно в CLAUDE.md разместить новую секцию (текущая структура
  CLAUDE.md имеет «Поток работы», «Правило two-way sync», «Когда какой
  скилл звать», «Красные линии», «Self-improvement»). Между какими
  секциями? Рекомендую: ПОСЛЕ «Self-improvement» как новую секцию
  «Правила работы над самим шаблоном», но Dev может предложить
  лучшее место.
- Считать ли правило hard-rule (красная линия) или soft-rule
  (правило в основном тексте)? Рекомендую soft — формулировка
  даёт исключение для пользовательских проектов, что для красной
  линии слишком много нюансов.
- Pointer в README.md — нужен? Не думаю, README — пользовательское
  лицо шаблона, а правило про разработчиков шаблона.
```

---

## Как использовать

В новой сессии Claude Code:

```
/project:pm @docs/superpowers/specs/2026-05-15-template-meta-artefacts-rule-kickoff-prompt.md
```

PM прочитает промпт, сделает декомпозицию (вероятно сократит до Dev-only),
запустит /dev. Ожидаемое время — 10–15 минут от старта до merge в public.
