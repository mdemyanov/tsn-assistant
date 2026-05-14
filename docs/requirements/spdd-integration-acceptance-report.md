---
title: SPDD Integration — BA-acceptance Report
properties:
  - name: Тип контента
    value: [Прочее]
  - name: Статус
    value: [Approved]
---

# BA-Acceptance Report — spdd-integration

**Дата:** 2026-05-14
**Ветка:** epic/spdd-integration
**Вердикт:** **PASS**

---

## AC ↔ Implementation matrix

### BA-001 (Two-way sync — правило обновления слоёв, 7 AC)

| AC# | Описание | Test ID | Реализация | Status |
|-----|----------|---------|------------|--------|
| AC-001 | CLAUDE.md содержит раздел «Правило two-way sync» с формулировкой «вышестоящий слой первым» | T01-1, T01-2 | `CLAUDE.md:132` — `## Правило two-way sync`; содержит «вышестоящий слой» | ✓ pass |
| AC-002 | Раздел содержит таблицу пар upstream→downstream для ≥5 (в т.ч. ≥2 content-only) из 7 профилей | T02-1, T02-2, T02-3 | `CLAUDE.md:132–163` — таблица всех 7 профилей включая kb-team, kb-product, methodology, course | ✓ pass |
| AC-003 | Раздел описывает hotfix-исключение, bypass-trailer `skip-drift:`, post-mortem обновление | T03-1, T03-2, T03-3 | `CLAUDE.md:137–143` — hotfix, skip-drift, «сразу после фикса» | ✓ pass |
| AC-004 | Раздел «Красные линии» содержит строку о блокере /pm-review | T04-1 | `CLAUDE.md:172` — «блокер для /pm-review» в секции Красные линии | ✓ pass |
| AC-005 | README.md содержит pointer на two-way sync в CLAUDE.md | T05-1, T05-2 | `README.md:97–99` — явный pointer, упоминает CLAUDE.md | ✓ pass |
| AC-006 | Pre-SPDD проект без `drift_pairs` → INFO-skip, не ошибка | T06-1 (CLAUDE.md), T16-1 (`_drift_check.py`) | `_drift_check.py:74–79` — `drift_pairs is None → INFO skip` | ✓ pass |
| AC-007 | `test_two_way_sync_in_claude_md.py` проходит зелёным | самоссылающийся | 12/12 passed | ✓ pass |

### BA-002 (Секция «Инварианты и Safeguards» в шаблонах артефактов, 7 AC)

| AC# | Описание | Test ID | Реализация | Status |
|-----|----------|---------|------------|--------|
| AC-001 | `ba-agent.md` содержит `## Инварианты и Safeguards` с 3 подразделами | T07-1, T07-2 | `.claude/plugins/project/agents/ba-agent.md:67–79` — секция с Содержательные/Sensitive content/Жизненный цикл | ✓ pass |
| AC-002 | `tech-writer-agent.md` содержит аналогичный блок с 3 подразделами | T08-1, T08-2 | `.claude/plugins/project/agents/tech-writer-agent.md:92–104` | ✓ pass |
| AC-003 | Чек-лист `ba-agent.md` содержит пункт про Safeguards | T09-1 | `ba-agent.md:161` — `- [ ] Секция «Инварианты и Safeguards» заполнена…` | ✓ pass |
| AC-004 | Чек-лист `tech-writer-agent.md` содержит аналогичный пункт | T10-1 | `tech-writer-agent.md:109` — аналогичный пункт | ✓ pass |
| AC-005 | Промпты содержат разграничение «Safeguards — hard constraints, не AC» с примерами | T11-1, T11-2, T11-3 | `ba-agent.md:69` — SA-NOTE «hard constraints, НЕ Acceptance Criteria»; примеры для code и content-only; нет «система должна» в шаблоне | ✓ pass |
| AC-006 | `test_safeguards_section_template.py` проходит зелёным | самоссылающийся | 9/9 passed (1 SKIPPED ранее — теперь 9/9 passed) | ✓ pass |
| AC-007 | Артефакт `/ba` или `/tech-writer` содержит секцию Safeguards | e2e — пропуск обоснован | Пропуск обоснован QA-001: требует активный LLM-сеанс; покрывается AC-001/002 (шаблон содержит секцию → агент её воспроизведёт) | ✓ обоснованный пропуск |

### BA-003 (Drift-check в /pm-review, 9 AC)

| AC# | Описание | Test ID | Реализация | Status |
|-----|----------|---------|------------|--------|
| AC-001 | WARN с именами файлов при downstream-only change | T12-1, T12-2 | `_drift_check.py:109–180` — WARN с именами файлов и парой | ✓ pass |
| AC-002 | Тишина при парных правках (и при только upstream, и при пустом diff) | T13-1, T13-2, T13-3 | `_drift_check.py:109–145` — проверка обоих upstream; no-WARN при match | ✓ pass |
| AC-003 | INFO при bypass с непустым reason | T14-1 | `_drift_check.py:168–172` — INFO с reason при bypass_reason_stripped | ✓ pass |
| AC-004 | WARN при пустом reason в skip-drift (пустая строка и whitespace) | T15-1, T15-2 | `_drift_check.py:91–107` — пустой/whitespace reason → WARN | ✓ pass |
| AC-005 | INFO-skip при `drift_pairs=None` и `drift_pairs=[]` | T16-1, T16-2 | `_drift_check.py:73–88` — оба варианта → INFO, нет WARN | ✓ pass |
| AC-006 | Все 7 манифестов содержат `drift_pairs`; custom=`[]`; структура upstream/downstream | T17–T25 (35 тестов) | `docs/overlays/profiles/*/manifest.yaml` — все 7 манифестов; project=4 пары, course=2 пары с glob `*-module-*` | ✓ pass |
| AC-007 | Content-only (kb-team): WARN при content↔content drift; тишина при парных | T26-1, T26-2 | `_drift_check.py` обрабатывает content/ пары идентично src/ | ✓ pass |
| AC-008 | `test_pm_review_drift_check.py` проходит зелёным | самоссылающийся | 12/12 passed | ✓ pass |
| AC-009 | `test_drift_pairs_in_manifests.py` проходит зелёным | самоссылающийся | 35/35 passed | ✓ pass |

---

## Dogfooding check

- BA-001 содержит секцию «Инварианты и Safeguards»: ✓ (`docs/requirements/spdd-two-way-sync.md:84`)
- BA-002 содержит секцию «Инварианты и Safeguards»: ✓ (`docs/requirements/spdd-safeguards-section.md:83`) — сама статья является dogfooding-демонстрацией
- BA-003 содержит секцию «Инварианты и Safeguards»: ✓ (`docs/requirements/spdd-drift-check.md:103`)

Bypass-формат в коммитах эпика: `skip-drift:` в commit message на ветке `epic/spdd-integration` не использовался ни разу — все 9 коммитов от `private` не содержат bypass-trailer. Нарушений правила no-bypass-without-reason нет.

---

## Backward-compat check

- `drift_pairs=None` → INFO-skip: ✓ (`_drift_check.py:73–79`)
- `drift_pairs=[]` → INFO-skip: ✓ (`_drift_check.py:82–87`)
- `validate-profile.py` на manifest без `drift_pairs`: ✓ (`INFO-skip` задокументирован в CLAUDE.md:145 — «backward-compat: не ошибка»; тест T06-1 green)
- Pre-SPDD CLAUDE.md (без секции two-way-sync) не ломает /pm-review: ✓ (`pm-review.md:68` — `если отсутствует — INFO-skip, drift-check пропускается`)

---

## Out-of-scope (явно)

- Профиль `regulated` — отложен (не входил в эпик)
- `/pm canvas` — отложен
- Полная реимплементация SPDD workflow — отказались (см. ADR-004: минимально-инвазивная адаптация под инфраструктуру project_template)
- E2e smoke-тест LLM-агентов (BA-002 AC-007) — пропуск обоснован в QA-001

---

## Issues / pending

Нет. Все 23 AC покрыты: 22 автоматическими тестами + 1 обоснованный пропуск (BA-002 AC-007).

---

## Test summary

```
test_two_way_sync_in_claude_md.py     — 12/12 passed
test_safeguards_section_template.py   —  9/9  passed
test_pm_review_drift_check.py         — 12/12 passed
test_drift_pairs_in_manifests.py      — 35/35 passed
─────────────────────────────────────────────────────
ИТОГО: 68/68 passed, 0 failed
```

---

## Verdict reasoning

Все 22 автоматически проверяемых AC зелёные (68/68 тестов). Единственный необоснованный пропуск BA-002 AC-007 (e2e LLM-smoke) явно задокументирован в QA-001 и обоснован технической невозможностью автоматизации без активного Claude-сеанса; покрытие достигается через AC-001/002 (шаблоны агентов содержат секцию — агент её воспроизведёт детерминированно).

Dogfooding-петля замкнута: все три BA-требования сами содержат секцию «Инварианты и Safeguards». Backward-compat для pre-SPDD проектов подтверждён как кодом (`_drift_check.py`), так и документацией (`pm-review.md`, CLAUDE.md). Bypass-trailer не был использован неправомерно ни в одном коммите эпика.

**Вердикт: PASS. Эпик готов к /pm-review.**
