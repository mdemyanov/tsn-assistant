---
order: 3
title: "BA-003 Drift-check в /pm-review"
properties:
  - name: Тип контента
    value: [Требование]
  - name: Фаза
    value: [MVP]
  - name: Статус
    value: [Draft]
---

# BA-003 Drift-check в /pm-review

## JTBD

Когда PM запускает `/pm-review` перед merge `private → public`, я (PM шаблона project_template) хочу автоматически получать предупреждение о расхождениях между слоями проекта, чтобы правило two-way sync не зависело только от дисциплины команды, а было подкреплено механической проверкой.

## Контекст и мотивация

Правило two-way sync (BA-001) фиксирует принцип: нижестоящий слой не должен обновляться без обновления вышестоящего. Само по себе это текстовое правило — без автоматической проверки оно игнорируется под давлением сроков.

Drift-check — механизм реализации этого правила в `/pm-review`. Он читает поле `drift_pairs` из манифеста активного профиля и сравнивает diff между ветками `private` и `public`. Если нижестоящий слой имеет правки, а вышестоящий — нет, выдаётся WARN с конкретными путями.

**Важно для SA:** `drift_pairs` в manifest — это целенаправленное расширение SPDD под инфраструктуру project_template, а не прямой аналог из оригинальной методологии Thoughtworks. В SPDD логика проверки расхождений реализована в отдельном tooling (`openspdd`), а автоматизированная верификация активов описана как future direction. SA не должен искать прямой SPDD-аналог для этого механизма — это наша параметризация.

В content-only профилях (kb-team, kb-product, methodology, course) drift-check работает на парах `content/↔content/` — он не молчит только потому, что нет `src/`.

Backward-compat: проекты, инициализированные до появления `drift_pairs` в манифестах, не должны получать ошибок при запуске `/pm-review`.

Источник принципа: [SPDD — ключевые принципы](../10-domain/spdd-key-principles) (RES-001), раздел «(в) Drift-check».

## Функциональные требования

- **FR-001:** В `/pm-review` добавить шаг «drift-check»: читать поле `drift_pairs` из manifest активного профиля, сравнивать diff `private` vs `public`, для каждой пары проверять наличие правок в upstream и downstream.
- **FR-002:** Если downstream имеет правки, а upstream — нет: выдавать **WARN** (не FAIL) с перечнем конкретных файлов downstream, не имеющих парных правок upstream. Имена файлов — обязательны в сообщении.
- **FR-003:** Если обе стороны пары имеют правки — тишина (drift-check чистый).
- **FR-004:** Если только upstream имеет правки (без downstream) — тишина (это нормально: обновляют спеку/архитектуру без немедленной реализации).
- **FR-005:** Поддержать bypass-trailer: если commit message или PR body содержат `skip-drift: <reason>`, drift-check выдаёт INFO-сообщение о bypass с указанным reason — без WARN.
- **FR-006:** Отсутствие поля `drift_pairs` в manifest активного профиля → INFO-skip («drift_pairs не настроен для профиля X — пропуск»). Не FAIL, не WARN.
- **FR-007:** Каждый из 7 манифестов (`docs/overlays/profiles/*/manifest.yaml`) должен содержать поле `drift_pairs` с соответствующими парами. Для профиля `custom` — пустой массив `[]` с комментарием о заполнении на `/init`.

## Нефункциональные требования

- **NFR-001:** WARN-сообщение содержит: имя профиля, пару upstream/downstream, список файлов downstream с правками без парных upstream-правок. Не общая фраза «есть расхождение» — конкретные пути.
- **NFR-002:** Drift-check не добавляет значимой задержки к `/pm-review` — операция сводится к git diff и парсингу manifest (секунды, не минуты).
- **NFR-003:** Bypass `skip-drift:` парсится строго по префиксу — не конфликтует с другими trailer'ами (`Co-Authored-By`, `Signed-off-by`).
- **NFR-004:** Для content-only профилей (kb-team, kb-product, methodology, course) поведение идентично — drift_pairs содержит только `content/↔content/` пары, логика не меняется.

## User Journey

**PM запускает /pm-review — drift обнаружен:**
1. PM запускает `/pm-review`.
2. /pm-review читает `drift_pairs` из manifest активного профиля.
3. Сравнивает diff `private` vs `public` по каждой паре.
4. Обнаружено: `content/60-implementation/` изменился, `content/30-requirements/` — нет.
5. /pm-review выдаёт: `⚠ WARN [drift-check]: downstream изменён без upstream. Файлы: content/60-implementation/auth-flow.md. Пара: content/30-requirements/ → content/60-implementation/. Обновите upstream или добавьте skip-drift: <reason> в commit message.`
6. PM возвращает задачу автору для обновления вышестоящего слоя.

**PM запускает /pm-review — drift чистый:**
1. /pm-review проверяет `drift_pairs`.
2. Обе стороны каждой пары либо изменены, либо не изменены.
3. Drift-check завершается без предупреждений.

**Bypass-сценарий:**
1. Автор сделал рефакторинг только в `src/` без изменения требований.
2. В commit message: `refactor: clean up auth module\n\nskip-drift: refactoring only — no requirements changed`.
3. /pm-review видит trailer: `ℹ INFO [drift-check]: bypass активен — "refactoring only — no requirements changed". Проверка пропущена.`

**Pre-SPDD проект (backward-compat):**
1. Проект инициализирован без `drift_pairs` в manifest.
2. /pm-review запускается.
3. Drift-check: `ℹ INFO [drift-check]: drift_pairs не настроен для профиля "project" — пропуск`.
4. /pm-review продолжает работу без ошибок.

## Бизнес-правила

- **BR-001:** Drift-check выдаёт WARN, не FAIL. Финальное решение о merge остаётся за PM — механизм информирует, не блокирует автоматически.
- **BR-002:** Bypass `skip-drift: <reason>` обязателен для hotfix-сценария (см. BR-002 в BA-001). Пустой reason (`skip-drift:`) недопустим — /pm-review должен выдать WARN об отсутствии обоснования.
- **BR-003:** Отсутствие `drift_pairs` в manifest — graceful degradation (INFO-skip), не поломка. Это поведение для проектов до SPDD-апгрейда.
- **BR-004:** В content-only профилях `drift_pairs` содержит только `content/↔content/` пары. Отсутствие `src/` — не повод для молчания drift-check.

## Доменные события

- `/pm-review` запущен → drift-check читает `drift_pairs` активного профиля
- Drift обнаружен → WARN с именами файлов выдан в отчёт /pm-review
- Bypass-trailer найден → INFO о bypass, проверка пропущена
- `drift_pairs` отсутствует → INFO-skip, /pm-review продолжает без ошибки
- Drift-check чистый → тишина, /pm-review продолжает

## Acceptance Criteria

- [ ] **AC-001:** /pm-review на PR с правками только в downstream (без upstream) выдаёт WARN-сообщение, содержащее имена изменённых downstream-файлов и имя пары upstream/downstream.
- [ ] **AC-002:** /pm-review на PR с парными правками (upstream и downstream оба изменены) не выдаёт WARN.
- [ ] **AC-003:** /pm-review на PR с `skip-drift: <reason>` в commit message (непустой reason) выдаёт INFO о bypass без WARN.
- [ ] **AC-004:** /pm-review с `skip-drift:` (пустой reason) выдаёт WARN об отсутствии обоснования bypass.
- [ ] **AC-005:** /pm-review на проекте без `drift_pairs` в manifest выдаёт INFO-skip и не завершается с ошибкой.
- [ ] **AC-006:** Каждый из 7 манифестов (`docs/overlays/profiles/*/manifest.yaml`) содержит поле `drift_pairs`. Для `custom` — пустой массив `[]`.
- [ ] **AC-007:** В content-only профиле (например, `kb-team`) drift-check работает на парах `content/↔content/` и выдаёт WARN при расхождении.
- [ ] **AC-008:** Тест `scripts/tests/test_pm_review_drift_check.py` проходит зелёным, покрывая сценарии AC-001..005.
- [ ] **AC-009:** Тест `scripts/tests/test_drift_pairs_in_manifests.py` проверяет наличие поля `drift_pairs` во всех 7 манифестах и проходит зелёным.

## Инварианты и Safeguards

**Содержательные:**
- drift_pairs в manifest — целенаправленное расширение SPDD под инфраструктуру шаблона. SA не должен искать прямой аналог в оригинальном SPDD tooling.
- WARN — не FAIL. Механизм информирует PM, не блокирует автоматически. Финальное решение о merge — за PM.
- Отсутствие `drift_pairs` (pre-SPDD проект) всегда graceful INFO-skip. Ни при каком условии не FAIL.
- Content-only профили не являются исключением: drift_pairs для них обязателен с `content/↔content/` парами.

**Sensitive content:**
- WARN-сообщение содержит пути файлов, но не содержимое файлов — не раскрывает чувствительный контент в логах.
- Bypass-reason не логируется в публичный отчёт детально — только факт bypass и краткий reason.

**Жизненный цикл:**
- Owner данного требования: BA (автор) → SA (ADR-004, схема manifest) → Dev (реализация в pm-review.md + 7 манифестов).
- Дата ревизии: после QA-002 (полный прогон тестов).
- При добавлении нового профиля в шаблон — его manifest обязан содержать `drift_pairs`.

## Влияние на 7 профилей

| Профиль | drift_pairs (upstream → downstream) | Тип пар |
|---------|-------------------------------------|---------|
| `project` | `content/30-requirements/ → src/`; `content/40-architecture/ → src/`; `content/30-requirements/ → content/60-implementation/`; `content/40-architecture/ → content/70-operations/` | mixed: content→code и content→content |
| `product` | `content/10-vision/ → content/30-specs/`; `content/30-specs/ → content/40-architecture/`; `content/40-architecture/ → src/`; `content/30-specs/ → content/50-releases/` | mixed |
| `kb-team` | `content/40-roles/ → content/30-runbooks/`; `content/30-runbooks/ → content/20-onboarding/`; `content/10-domain/ → content/40-roles/`; `content/50-incidents/ → content/30-runbooks/` | content→content |
| `kb-product` | `content/reference/ → content/guides/`; `content/guides/ → content/troubleshooting/`; `content/reference/ → content/getting-started/` | content→content |
| `methodology` | `content/10-principles/ → content/20-practices/`; `content/20-practices/ → content/30-playbooks/`; `content/30-playbooks/ → content/40-templates/` | content→content |
| `course` | `content/10-module-*/ → content/90-assessments/`; `content/00-overview/ → content/10-module-*/` | content→content |
| `custom` | `[]` (пустой; заполняется на `/init`) | open-ended |

## Открытые вопросы

- **OQ-001 (для SA):** Как /pm-review определяет активный профиль? Через `manifest.yaml` в корне? Через отдельный config-файл? Это решение влияет на дизайн шага drift-check.
- **OQ-002 (для SA):** Пути в `drift_pairs` — относительно корня репозитория или относительно `content/`? Нужна однозначная конвенция в схеме manifest.
- **OQ-003 (для SA):** Glob-паттерны в путях (`content/10-module-*/`) — поддерживаются ли в логике drift-check, или нужны конкретные пути?

## Ссылки

- PM-план эпика: `docs/superpowers/plans/2026-05-14-spdd-integration.md`
- Kickoff-спека: `docs/superpowers/specs/2026-05-14-spdd-integration-kickoff-prompt.md`
- Research-note (RES-001): [SPDD — ключевые принципы](../10-domain/spdd-key-principles)
- Смежные требования: [BA-001 Two-way sync](./spdd-two-way-sync), [BA-002 Секция Инварианты и Safeguards](./spdd-safeguards-section)
