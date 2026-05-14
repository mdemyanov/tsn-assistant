---
title: SPDD Integration — Test Plan
properties:
  - name: Тип контента
    value: [Прочее]
  - name: Статус
    value: [Draft]
---

# SPDD Integration — Test Plan (QA-001)

**Эпик:** spdd-integration
**Дата:** 2026-05-14
**QA-author:** QA-agent (Sonnet)
**Входы:** BA-001, BA-002, BA-003, ADR-004, design-spec SA-001

---

## BA-001 — Two-way sync (7 AC)

| AC ID | Формулировка AC | Test ID | Тест-кейс | Тип | Dev hint |
|-------|----------------|---------|-----------|-----|----------|
| BA001-AC-001 | CLAUDE.md содержит раздел «Правило two-way sync» | T01-1 | `test_ac001_claude_md_has_two_way_sync_section` — проверяет наличие маркера `## Правило two-way sync` | unit (file-check) | Dev вставляет готовый блок из design-spec §1 после «Поток работы» |
| BA001-AC-001 | Раздел содержит «вышестоящий слой» | T01-2 | `test_ac001_section_contains_upstream_layer_mention` — grep «вышестоящий слой»/«upstream layer» | unit | NFR-002: не «src/», «спека» |
| BA001-AC-002 | Пары для ≥5 из 7 профилей (включая ≥2 content-only) | T02-1 | `test_ac002_section_covers_at_least_5_profiles` — считает профили в блоке | unit | Таблица из design-spec §1: 7 строк |
| BA001-AC-002 | ≥2 content-only профиля | T02-2 | `test_ac002_section_covers_at_least_2_content_only_profiles` — grep kb-team/kb-product/methodology/course | unit | Content-only: kb-team, kb-product, methodology, course |
| BA001-AC-002 | Все 7 профилей упомянуты | T02-3 | `test_ac002_section_mentions_all_7_profiles` — strict: нет пропусков | unit | boundary |
| BA001-AC-003 | Описывает hotfix-исключение | T03-1 | `test_ac003_section_mentions_hotfix` — grep «hotfix» | unit | BA-001 FR-003 |
| BA001-AC-003 | Упоминает skip-drift trailer | T03-2 | `test_ac003_section_mentions_skip_drift_trailer` — grep «skip-drift» | unit | BA-001 BR-003 |
| BA001-AC-003 | Упоминает post-mortem обновление | T03-3 | `test_ac003_section_mentions_postmortem` — grep «post-mortem»/«после фикса» | unit | BA-001 BR-002 |
| BA001-AC-004 | «Красные линии» содержат строку о блокере /pm-review | T04-1 | `test_ac004_red_lines_contain_pm_review_blocker` — grep в разделе «Красные линии» | unit | BA-001 FR-004: exact text из design-spec §1 |
| BA001-AC-005 | README.md содержит pointer на two-way sync | T05-1 | `test_ac005_readme_contains_two_way_sync_pointer` — grep two-way в README.md | unit | BA-001 FR-005 |
| BA001-AC-005 | README.md ссылается на CLAUDE.md | T05-2 | `test_ac005_readme_references_claude_md` — grep «CLAUDE.md» | unit | boundary |
| BA001-AC-006 | pre-SPDD проект не получает ошибок (INFO-skip) | T06-1 | `test_ac006_claude_md_mentions_info_skip_for_backward_compat` — grep INFO/backward-compat | unit | NFR-003; полная проверка — в test_pm_review_drift_check.py::test_ac005_* |
| BA001-AC-007 | test_two_way_sync_in_claude_md.py проходит зелёным | — | Этот тест-файл является AC-007 | — | AC самоссылающийся |

**Файл стаба:** `scripts/tests/test_two_way_sync_in_claude_md.py`
**Текущий статус:** 11 FAILED, 1 PASSED (RED)

---

## BA-002 — Инварианты и Safeguards (7 AC)

| AC ID | Формулировка AC | Test ID | Тест-кейс | Тип | Dev hint |
|-------|----------------|---------|-----------|-----|----------|
| BA002-AC-001 | ba-agent.md содержит `## Инварианты и Safeguards` | T07-1 | `test_ac001_ba_agent_has_safeguards_section` — grep маркера | unit (file-check) | Вставить шаблон из design-spec §2 в «Структура статьи-требования» |
| BA002-AC-001 | Секция содержит 3 подраздела | T07-2 | `test_ac001_ba_agent_has_three_subsections` — grep Содержательные/Sensitive content/Жизненный цикл | unit | design-spec §2: три подраздела обязательны |
| BA002-AC-002 | tech-writer-agent.md содержит аналогичный блок | T08-1 | `test_ac002_tech_writer_has_safeguards_section` — grep маркера | unit | design-spec §2 |
| BA002-AC-002 | Секция содержит 3 подраздела | T08-2 | `test_ac002_tech_writer_has_three_subsections` | unit | аналогично T07-2 |
| BA002-AC-003 | Чек-лист ba-agent.md упоминает Safeguards | T09-1 | `test_ac003_ba_agent_checklist_mentions_safeguards` — regex `[[ ]].*Safeguards` вне блока секции | unit | design-spec §2: пункт «- [ ] Секция Safeguards заполнена или N/A» |
| BA002-AC-004 | Чек-лист tech-writer-agent.md упоминает Safeguards | T10-1 | `test_ac004_tech_writer_checklist_mentions_safeguards` — аналогично T09-1 | unit | design-spec §2 |
| BA002-AC-005 | Промпты содержат разграничение Safeguards vs AC | T11-1 | `test_ac005_ba_agent_safeguards_vs_ac_distinction` — grep «hard constraints» | unit | design-spec §2: SA-NOTE в шаблоне |
| BA002-AC-005 | tech-writer-agent.md содержит разграничение | T11-2 | `test_ac005_tech_writer_safeguards_vs_ac_distinction` | unit | аналогично T11-1 |
| BA002-AC-005 | Safeguards-блок не содержит «система должна» | T11-3 | `test_ac005_ba_agent_safeguards_block_no_system_should` — проверяет что в шаблоне нет AC-паттернов | unit (boundary) | NFR-001: Safeguards бинарны, не «система должна X» |
| BA002-AC-006 | test_safeguards_section_template.py проходит зелёным | — | Этот тест-файл является AC-006 | — | AC самоссылающийся |
| BA002-AC-007 | Артефакт /ba или /tech-writer содержит секцию | — | **Не покрыто автоматически** (smoke-тест создания) | e2e | Пропуск обоснован ниже |

**Файл стаба:** `scripts/tests/test_safeguards_section_template.py`
**Текущий статус:** 8 FAILED, 1 SKIPPED (RED)

---

## BA-003 — Drift-check в /pm-review (9 AC)

| AC ID | Формулировка AC | Test ID | Тест-кейс | Тип | Dev hint |
|-------|----------------|---------|-----------|-----|----------|
| BA003-AC-001 | WARN с именами файлов при downstream-only change | T12-1 | `test_ac001_warn_on_downstream_only_change` — `changed=["src/auth/login.py"]`, expect WARN | unit | `check_drift()` в `scripts/_drift_check.py` |
| BA003-AC-001 | WARN содержит информацию о паре | T12-2 | `test_ac001_warn_message_contains_pair_info` — grep upstream/downstream в WARN | unit | NFR-001: конкретные пути, не «есть расхождение» |
| BA003-AC-002 | Нет WARN при парных правках | T13-1 | `test_ac002_no_warn_when_both_sides_changed` — both changed, expect 0 WARN | unit | design-spec §3c шаг 5d |
| BA003-AC-002 | Нет WARN при только upstream изменении | T13-2 | `test_ac002_no_warn_when_only_upstream_changed` — FR-004 | unit | boundary |
| BA003-AC-002 | Нет WARN при пустом diff | T13-3 | `test_ac002_no_warn_when_no_changes` — empty changed list | unit | edge-case из design-spec §4 |
| BA003-AC-003 | INFO bypass с непустым reason | T14-1 | `test_ac003_info_bypass_with_nonempty_reason` — bypass_reason непустой, 0 WARN, ≥1 INFO | unit | design-spec §3f |
| BA003-AC-004 | WARN при пустом reason в skip-drift | T15-1 | `test_ac004_warn_on_empty_bypass_reason` — bypass_reason="", expect WARN | unit | design-spec §3f: reason EMPTY → WARN |
| BA003-AC-004 | WARN при reason из пробелов | T15-2 | `test_ac004_warn_on_whitespace_bypass_reason` — bypass_reason="   " | unit (boundary) | edge-case |
| BA003-AC-005 | INFO-skip при отсутствии drift_pairs (None) | T16-1 | `test_ac005_info_skip_when_no_drift_pairs` — drift_pairs=None, expect INFO | unit | design-spec §3c шаг 2, §3g |
| BA003-AC-005 | INFO-skip при drift_pairs=[] (custom) | T16-2 | `test_ac005_info_skip_when_empty_drift_pairs` — drift_pairs=[], 0 WARN | unit (boundary) | custom-профиль |
| BA003-AC-006 | Все 7 манифестов содержат drift_pairs | T17-* | `test_ac006_drift_pairs_key_present[<profile>]` — parametrized по 7 профилям | unit (YAML parse) | Dev добавляет в каждый manifest.yaml |
| BA003-AC-006 | drift_pairs непустой для 6 профилей | T18-* | `test_ac006_drift_pairs_non_empty[<profile>]` | unit | project=4, product=4, kb-team=4, kb-product=3, methodology=3, course=2 |
| BA003-AC-006 | custom drift_pairs=[] | T19-1 | `test_ac006_custom_drift_pairs_empty_list` | unit | custom open-ended |
| BA003-AC-006 | Структура каждого элемента: upstream+downstream | T20-* | `test_ac006_drift_pairs_items_have_upstream_downstream[<profile>]` | unit | minLength≥1 |
| BA003-AC-006 | Нет лишних ключей в элементах | T21-* | `test_ac006_drift_pairs_no_extra_keys[<profile>]` | unit (boundary) | только upstream/downstream/note |
| BA003-AC-006 | Glob-паттерны parseable через pathlib | T22-* | `test_ac006_drift_pairs_glob_patterns_parseable[<profile>]` | unit | design-spec §3b |
| BA003-AC-006 | project ровно 4 пары | T23-1 | `test_ac006_project_has_four_drift_pairs` | unit (boundary) | design-spec §3e |
| BA003-AC-006 | course ровно 2 пары | T24-1 | `test_ac006_course_has_two_drift_pairs` | unit (boundary) | glob *-module-* |
| BA003-AC-006 | course glob покрывает оба модульных каталога | T25-1 | `test_ac006_course_glob_covers_both_module_dirs` | unit (boundary) | 10-module-01 И 20-module-02 |
| BA003-AC-007 | kb-team content-only WARN при content↔content drift | T26-1 | `test_ac007_content_only_profile_warns_on_drift` — DRIFT_PAIRS_KB_TEAM, downstream изменён | unit | BR-004: content-only не исключение |
| BA003-AC-007 | kb-team без WARN при парных правках | T26-2 | `test_ac007_content_only_kb_team_no_warn_on_clean` | unit (boundary) | |
| BA003-AC-008 | test_pm_review_drift_check.py проходит зелёным | — | Этот тест-файл является AC-008 | — | AC самоссылающийся |
| BA003-AC-009 | test_drift_pairs_in_manifests.py проходит зелёным | — | Этот тест-файл является AC-009 | — | AC самоссылающийся |

**Файлы стабов:**
- `scripts/tests/test_pm_review_drift_check.py` — 12 FAILED (RED)
- `scripts/tests/test_drift_pairs_in_manifests.py` — 17 FAILED, 18 PASSED (RED: структурные тесты зеленые, содержательные падают)

---

## Coverage summary

| Требование | Всего AC | Покрыто тестами | Не покрыто | Обоснование пропусков |
|-----------|---------|----------------|-----------|----------------------|
| BA-001 | 7 | 7 (AC-001..AC-007) | 0 | AC-007 самоссылающийся |
| BA-002 | 7 | 6 (AC-001..AC-006) | 1 (AC-007) | см. ниже |
| BA-003 | 9 | 9 (AC-001..AC-009) | 0 | AC-008, AC-009 самоссылающиеся |
| **Итого** | **23** | **22** | **1** | |

### Пропуск BA-002 AC-007

**AC-007 (BA-002):** smoke-тест: создание артефакта через `/ba` или `/tech-writer` порождает секцию Safeguards.

**Обоснование пропуска:** AC-007 требует запуска LLM-агента (`/ba`, `/tech-writer`) и проверки его вывода. Это e2e-тест, который:
1. Требует активный Claude Code сеанс (нельзя автоматизировать в `uv run`).
2. Проверяет поведение промпта, а не структуру файла — нестабилен при обновлениях модели.
3. Дублирует AC-001 и AC-002: если шаблон агента содержит секцию Safeguards (что проверяется T07-T08), агент её воспроизведёт.

**Решение для Dev:** после реализации BA-002 провести ручную проверку: вызвать `/ba new-requirement test-safeguards-demo` и убедиться, что секция `## Инварианты и Safeguards` появилась в артефакте.

---

## Boundary cases

- **BA-001:** `test_ac002_section_mentions_all_7_profiles` — strict: все 7, не «≥5»
- **BA-003:** пустой bypass reason vs whitespace-only — оба → WARN (не INFO)
- **BA-003:** пустой diff `[]` → полная тишина (нет WARN, нет INFO)
- **BA-003:** только upstream изменён → тишина (FR-004: нормальный сценарий)
- **BA-003:** drift_pairs=None (поле отсутствует) vs `[]` (пустой список) — оба → INFO-skip, нет WARN
- **BA-003 course:** glob `*-module-*` покрывает `10-module-01-introduction` И `20-module-02-example`
- **BA-002:** блок Safeguards не должен содержать «система должна» (AC-паттерн, не Safeguard)

## Error cases

- **BA-003:** _drift_check.py отсутствует → все тесты `test_pm_review_drift_check.py` падают с `AssertionError: TODO: ...` (не ImportError/компиляционная ошибка)
- **BA-003:** manifest.yaml отсутствует → `test_drift_pairs_in_manifests.py` падает на `FileNotFoundError` в `load_manifest()` с явным сообщением о пути
- **BA-002:** checklist-пункт ищется вне самой секции `## Инварианты и Safeguards` — исключает ложные срабатывания на саму секцию

## Не покрываем (вне scope QA-001)

- Тестирование `scripts/validate-profile.py` на поле `drift_pairs` — это задача QA-runner (QA-002) или расширение test-validate-profile.sh
- Автоматизированный e2e smoke-тест LLM-агентов (BA-002 AC-007) — вне возможностей `uv run`
- Тестирование `/pm-review` как CLI-команды end-to-end — это QA-runner (QA-002)
- Backward-compat upgrade playbook `docs/upgrading-from-template.md` — вне scope Dev-фазы

---

## Red/Green ratio после прогона стабов

```
test_drift_pairs_in_manifests.py    — 17 FAILED, 18 PASSED  (35 тестов)
test_safeguards_section_template.py —  8 FAILED,  1 SKIPPED  ( 9 тестов)
test_pm_review_drift_check.py       — 12 FAILED              (12 тестов)
test_two_way_sync_in_claude_md.py   — 11 FAILED,  1 PASSED  (12 тестов)
─────────────────────────────────────────────────────────────
ИТОГО: 48 FAILED, 19 PASSED/SKIPPED (67 тестов)
```

Все 48 FAILED — это тесты на реализацию, которой ещё нет. 19 PASSED/SKIPPED — структурные тесты (load_manifest, file exists, parseable path) и skipped boundary-тест (секция ещё не добавлена → skip корректен).

**Ожидаемый результат после Dev-фазы: 67/0 PASSED.**

---

## Что важно для Dev

1. **Главный артефакт Dev-фазы для BA-003** — `scripts/_drift_check.py` с функцией `check_drift(changed_files, drift_pairs, bypass_reason) -> list[dict]`. Тесты ожидают именно этот модуль.
2. **Сигнатура событий:** каждый dict должен содержать минимум `{"level": "WARN"|"INFO", "message": str}`. Дополнительные поля допустимы.
3. **drift_pairs=None vs []:** оба → INFO-skip (разные пути в алгоритме §3c шаг 2).
4. **bypass_reason:** пустая строка и строка из пробелов — оба эквивалентны «пустому reason» → WARN.
5. **Glob-паттерны:** `content/*-module-*/` — POSIX, через `pathlib.Path.glob()`. Тест проверяет `*` в строке.
6. **ba-agent.md и tech-writer-agent.md:** секция вставляется в раздел «Структура статьи-требования», чек-лист — в «После задачи» или отдельный «Чек-лист выходного артефакта».
7. **CLAUDE.md:** раздел вставляется после «Поток работы», строка в «Красные линии» — дополнение к существующим.
8. **18 PASSED в test_drift_pairs_in_manifests:** тесты на структуру dict/string-валидацию проходят, т.к. они проверяют элементы пустого списка — assert'ы на циклах по `[]` не срабатывают. После добавления drift_pairs эти тесты тоже должны быть зелёными.
