# SPDD Integration — Kickoff Prompt для PM

**Дата:** 2026-05-14
**Назначение:** передать PM шаблона project_template как вход для `/pm decompose`
**Контекст:** интеграция ключевых идей SPDD (Structured-Prompt-Driven Development, Thoughtworks) в шаблон с поддержкой всех 7 профилей, включая content-only.

---

## Промпт (передать PM как есть)

```
/pm decompose: интегрировать ключевые идеи SPDD в шаблон project_template
(с поддержкой всех 7 профилей, включая content-only)

## Контекст и мотивация

В апреле 2026 Thoughtworks опубликовал методологию SPDD (Structured-Prompt-
Driven Development). Мы провели сравнение SDD/SPDD/SuperPowers и зафиксировали:
шаблон project_template уже на ~70% реализует то, что предлагает SPDD, но как
процесс, а не как явные правила и артефакты. Нужно довести оставшиеся 30%
точечно, без слома существующего workflow.

Источники для контекста (прочитать перед декомпозицией):
- Сравнительный insight:
  /Users/mdemyanov/Documents/naumen-cto/50_KNOWLEDGE/insights/2026/2026-05-14_sdd-spdd-superpowers-comparison.md
- Перевод статьи SPDD:
  /Users/mdemyanov/Documents/naumen-cto/55_SOURCES/articles/2026/2026-05-14_article_structured-prompt-driven-development.md
- Текущая структура шаблона: README.md, CLAUDE.md, AGENTS.md

## Ключевое ограничение: 7 профилей, 4 из них content-only

Шаблон поддерживает 7 профилей: project, product, kb-product, kb-team,
methodology, course, custom. Из них 4 — content-only (kb-team, kb-product,
methodology, course) — не используют src/ и роли SA/Dev (см. матрицу
в AGENTS.md).

ВСЕ формулировки изменений должны работать и для code-проектов, и для
content-only. Не пиши в терминах «код vs спека» — пиши в терминах
«вышестоящий слой vs нижестоящий слой». src/ — это частный случай
нижестоящего слоя для code-профилей.

## Scope: три изменения

### Изменение 1: правило two-way sync между слоями (CLAUDE.md)

**Зачем:** SPDD-принцип «когда реальность расходится — сначала исправь
вышестоящий слой, потом нижестоящий». У нас сейчас поток односторонний,
расхождения чинятся вручную или не чинятся.

**Что сделать:**
- В шаблонном CLAUDE.md добавить отдельный раздел «Правило two-way sync»
  с универсальной формулировкой:

  «При расхождении любого слоя content/ с вышестоящим — сначала обнови
  вышестоящий слой, затем нижестоящий. Расхождение без обновления
  вышестоящего слоя — блокер для /pm-review.

  Примеры пар "upstream → downstream":
  - для project/product: content/30-requirements/ → src/
  - для project/product: content/40-architecture/ → src/
  - для kb-team: content/30-requirements/ → content/60-implementation/
    (runbook)
  - для kb-product: content/40-architecture/ → content/60-howto/
  - для methodology: content/50-principles/ → content/60-playbooks/
  - для course: content/30-lessons/ → content/60-assessments/

  Конкретные пары для профиля — в manifest профиля, поле drift_pairs.»

**Критерий приёмки:** правило явно сформулировано, упоминает универсальный
принцип + примеры для разных профилей, и /pm-review знает про него
(см. изменение 3).

### Изменение 2: секция «Инварианты и Safeguards» в шаблонах артефактов

**Зачем:** в SPDD есть отдельное поле "Safeguards" — неоспоримые инварианты
конкретной фичи. У нас сейчас они размазаны или отсутствуют. Особенно
больно для regulated-клиентов И для контентных проектов с sensitivity-
требованиями.

**Что сделать:**
- В .claude/plugins/project/agents/ba-agent.md в «Структуру статьи-
  требования» добавить обязательную секцию (универсальная формулировка):

  ```markdown
  ## Инварианты и Safeguards

  **Содержательные:** [условия, которые артефакт никогда не нарушает.
    Примеры для кода: «modelId обязателен», «timeout < 5s».
    Примеры для регламента: «все исключения явно описаны»,
    «у каждой роли указан backup-owner».
    Примеры для курса: «каждая лекция имеет assessment»,
    «каждое утверждение подкреплено источником».]

  **Sensitive content:** [что НЕ должно попасть в public ветку:
    PII, NDA, коммерческая тайна, токены, secrets, реальные имена
    клиентов без согласования]

  **Жизненный цикл:** [для контентных артефактов: дата следующей
    ревизии, owner; для кода: deprecation policy, breaking changes]
  ```

- ТАКЖЕ добавить аналогичную секцию в .claude/plugins/project/agents/
  tech-writer-agent.md (в KB-only профилях tech-writer — primary author,
  и без BA Safeguards не появятся).

- Обновить describe-промпт обоих агентов: упомянуть Safeguards
  в чек-листе выходного артефакта. Если секция не применима —
  явно ставить N/A с обоснованием.

- Если есть e2e-тест шаблона (scripts/test-template.sh) — убедиться,
  что он не ломается и проверяет наличие секции в шаблоне.

**Критерий приёмки:**
- При создании нового требования через /ba — секция «Инварианты
  и Safeguards» появляется в шаблоне.
- При создании контентной статьи через /tech-writer (в kb-team,
  methodology, course, kb-product) — секция тоже появляется.
- Допустимо явное N/A с обоснованием — но секция не пропускается
  молча.

### Изменение 3: drift-check в /pm-review (параметризованный по профилю)

**Зачем:** правило из изменения 1 нужно реально проверять. /pm-review
должен ловить ситуацию, когда нижестоящий слой правится без правок
в вышестоящем.

**Что сделать:**
- В manifest каждого профиля (docs/overlays/profiles/<name>/manifest.yaml)
  добавить новое поле:

  ```yaml
  drift_pairs:
    - upstream: content/30-requirements/
      downstream: src/
    - upstream: content/40-architecture/
      downstream: src/
  ```

  Для каждого из 7 профилей — свой набор пар. Defaults:
  - project, product: [requirements/→src/, architecture/→src/]
  - kb-team: [requirements/→implementation/, architecture/→implementation/]
  - kb-product: [requirements/→howto/, architecture/→howto/]
  - methodology: [principles/→practices/, practices/→playbooks/]
  - course: [lessons/→assessments/]
  - custom: [] (open-ended, заполняется при /init)

  ПОДТВЕРДИТЬ конкретные пути с пользователем перед коммитом — там могут
  быть расхождения с фактической структурой scaffold'ов.

- В логике /pm-review (.claude/plugins/project/commands/pm-review.md
  или где живёт) добавить шаг:
  1. Прочитать drift_pairs из активного профиля.
  2. Сравнить изменения между private и public ветками.
  3. Для каждой пары: если нижестоящий слой имеет правки, а вышестоящий —
     нет, выдать WARN (не FAIL).
  4. WARN указывает конкретные файлы downstream без парных правок upstream.

- Документировать bypass: явный флаг в commit-message или PR-описании
  (например, "skip-drift: refactoring only" или "skip-drift: hotfix"),
  чтобы не блокировать legitimate-рефакторы.

**Критерий приёмки:**
- Запуск /pm-review на PR с правкой downstream без upstream выдаёт
  понятное предупреждение с конкретными путями.
- На PR с парными правками — тишина.
- На PR с bypass-flag — тишина с упоминанием bypass в отчёте.
- В content-only профилях drift-check работает на парах content/↔content/
  (не молчит).

## Что вне scope (НЕ делать в этой задаче)

- НЕ создавать новую slash-команду /pm canvas — это отдельный wave.
- НЕ создавать профиль regulated — отдельный wave, когда появится
  compliance-кейс (банковский клиент, ФСТЭК).
- НЕ переписывать workflow PM → BA → SA → Dev. Существующий процесс
  работает, дублировать SPDD-команды (/spdd-generate, /spdd-sync)
  не нужно.
- НЕ менять матрицу ролей и pipelines.
- НЕ менять контракт вызова субагентов.

## Артефакты, которые ты создашь

1. Spec в docs/superpowers/specs/<YYYY-MM-DD>-spdd-integration-design.md
   — формулировка, обоснование, дизайн каждого из 3 изменений, влияние
   на 7 профилей, альтернативы.
2. Plan в docs/superpowers/plans/<YYYY-MM-DD>-spdd-integration.md
   — пошаговый план, какие субагенты на каких шагах, последовательность
   правок, smoke-test, обновление lessons-learned.
3. PR в private → /pm-review → public с тремя изменениями.
4. Запись в docs/lessons-learned.md с выводами.

## Делегирование (рекомендую такой порядок)

- /research (опц., 10 мин) — освежить контекст SPDD по двум источникам
  выше, выписать ключевые принципы как заметку в content/10-domain/.
- /ba — оформить изменения 1–3 как требования с AC. Это и есть
  dogfooding новой секции Safeguards.
- /sa — оформить ADR "Two-way sync rule + Safeguards section + drift-
  check" в content/00-project/adr/. Архитектурное решение, меняет
  шаблонный контракт и process-rules для всех 7 профилей.
- /dev — внести правки в CLAUDE.md, ba-agent.md, tech-writer-agent.md,
  pm-review.md, и в manifest.yaml для каждого из 7 профилей.
- /qa --mode=author — добавить тест на drift-check + проверку
  наличия Safeguards-секции в шаблонах артефактов BA и tech-writer.
- /devops — обновить scripts/test-template.sh, чтобы smoke-тест
  проходил для каждого из 7 профилей (init → проверка наличия
  правил и секций).

## Acceptance criteria (общие для эпика)

1. CLAUDE.md содержит универсальное правило two-way sync с примерами
   пар для всех 7 профилей.
2. ba-agent.md и tech-writer-agent.md содержат секцию «Инварианты
   и Safeguards» в шаблонах артефактов + упоминание в чек-листе выхода.
3. Каждый из 7 manifest.yaml содержит поле drift_pairs (для custom —
   пустой массив с комментарием).
4. /pm-review при наличии downstream-правок без upstream выдаёт
   читаемое предупреждение, поддерживает bypass-flag.
5. scripts/test-template.sh проходит зелёным для всех 7 профилей.
6. Существующие проекты, инициализированные старой версией шаблона,
   не ломаются — изменения backward-compatible. Если для миграции
   старых проектов нужны шаги — описать в
   docs/upgrading-from-template.md.
7. ADR и spec написаны, lessons-learned обновлён.

## Открытые вопросы (если возникнут — спроси меня перед декомпозицией)

- Пары upstream/downstream для kb-team, kb-product, methodology,
  course — я предложил defaults на основе общего знания о профилях.
  Проверь по фактической структуре content-scaffold каждого
  профиля (docs/overlays/profiles/<name>/content-scaffold/) и
  предложи коррекции, если нужно.
- Где документировать новые правила для людей, не читающих CLAUDE.md
  — в README.md шаблона тоже добавить упоминание?
- Bypass-flag drift-check: предложи синтаксис (skip-drift в commit-
  message? отдельное поле в PR? отметка в самом /pm-review запросе?).
- Считать ли это breaking change и нужен ли upgrade-playbook
  для существующих проектов?
```
