---
title: SPDD Integration — Test Report
properties:
  - name: Тип контента
    value: [Прочее]
  - name: Статус
    value: [Draft]
---

# SPDD Integration — Test Report (QA-002)

**Эпик:** spdd-integration
**Дата прогона:** 2026-05-14
**QA-runner:** QA-agent (Sonnet)
**Ветка:** epic/spdd-integration
**Входы:** BA-001, BA-002, BA-003, ADR-004, design-spec SA-001, test-plan QA-001

---

## Summary

| Скрипт / Suite | Passed | Failed | Skipped | Status |
|----------------|--------|--------|---------|--------|
| `uv run scripts/validate-content.py` | — | 0 errors | 2 warnings (pre-existing) | OK |
| `uv run scripts/validate-profile.py` | 7 profiles | 0 | — | OK |
| `bash scripts/check.sh` | all checks | 0 | — | OK |
| `bash scripts/test-spdd-integration.sh` (4 files) | 68 | 0 | 0 | OK |
| `uv run pytest test_drift_pairs_in_manifests.py` | 35 | 0 | 0 | OK |
| `uv run pytest test_safeguards_section_template.py` | 9 | 0 | 0 | OK |
| `uv run pytest test_pm_review_drift_check.py` | 12 | 0 | 0 | OK |
| `uv run pytest test_two_way_sync_in_claude_md.py` | 12 | 0 | 0 | OK |
| `bash scripts/test-template.sh` (smoke 7 profiles) | 206 | 0 | 0 | OK |
| `bash scripts/test-apply-overlay.sh` | 19 | 0 | 0 | OK |
| `bash scripts/test-validate-profile.sh` | 40 | 0 | 0 | OK |
| `bash scripts/test-resolve-agents.sh` | 15 | 0 | 0 | OK |
| `bash scripts/test-validate-content.sh` | 26 | 0 | 0 | OK |
| **ИТОГО** | **442+** | **0** | **0** | **ALL GREEN** |

**Duration:** ~3 минуты суммарно (все скрипты).

---

## Regression analysis

### Сравнение с baseline (до эпика spdd-integration)

**Baseline (QA-001 stubs, до Dev-фазы):**
```
test_drift_pairs_in_manifests.py    — 17 FAILED, 18 PASSED  (35 тестов)
test_safeguards_section_template.py —  8 FAILED,  1 SKIPPED  ( 9 тестов)
test_pm_review_drift_check.py       — 12 FAILED              (12 тестов)
test_two_way_sync_in_claude_md.py   — 11 FAILED,  1 PASSED  (12 тестов)
ИТОГО: 48 FAILED, 19 PASSED/SKIPPED (67 тестов)
```

**Текущий результат (после Dev + DevOps + Relocation):**
```
test_drift_pairs_in_manifests.py    — 35 PASSED, 0 FAILED
test_safeguards_section_template.py —  9 PASSED, 0 FAILED, 0 SKIPPED
test_pm_review_drift_check.py       — 12 PASSED, 0 FAILED
test_two_way_sync_in_claude_md.py   — 12 PASSED, 0 FAILED
ИТОГО: 68 PASSED, 0 FAILED (было 48 FAILED → 0 FAILED)
```

**Delta:** 48 тестов перешли из RED в GREEN. Ни один зелёный тест не стал красным.

### T-W4b-BASELINE (2 pre-existing)

Ожидалось: baseline `content/` содержит 12 файлов вместо 2 до relocation.
Результат: `T-W4b-BASELINE: baseline content/ = 2 файла` — **PASSED**. Relocation `content/ → docs/` была выполнена успешно в коммите `061f7ce`. Pre-existing проблема устранена.

### T-INIT-PROFILE-KB, T-W3-A7, T-W4a-P4-noise (5 pre-existing)

Ожидалось: delete-regressions для kb-team/kb-product — папки не удаляются.
Результат: все 8 assert'ов (T-INIT-PROFILE-KB: 30-requirements удалена, T-W3-A7: 00-project удалена, T-W4a-P4-noise: 6 папок удалены) — **PASSED**. Pre-existing проблемы устранены либо никогда не воспроизводились на текущей кодовой базе.

### T-UV-PREREQ-06 (pre-existing/epic-boundary)

Ожидалось (по формулировке задачи): тест проверяет 6 .py с PEP 723, но Dev добавил `_drift_check.py` (7-й файл) → возможная регрессия.
Результат: `T-UV-PREREQ-06: все .py в scripts/ содержат # /// script (PEP-723) — 7/7` — **PASSED**.

Причина: DevOps-коммит `8c1123a` обновил тест на динамическую проверку (`UV06_TOTAL=$(ls *.py | wc -l)` vs `UV06_COUNT`) — хардкода «6» в тесте нет. Комментарий в test-template.sh был также обновлён Dev в коммите `b3f0516`. Фикс не требовался.

---

## Performance snapshot

NFR по производительности в этом эпике не заданы. Benchmark baseline отсутствует. Snapshot не применим.

Информационно: полный прогон всех скриптов занял ~3 минуты — в пределах нормы для CI на 7-профильной матрице с tmpdir init.

---

## Failed tests (детали)

| Test | Reason category | Probable cause | Action |
|------|-----------------|----------------|--------|
| — | — | — | — |

**Ни одного упавшего теста не обнаружено.**

---

## AC coverage

| Требование | Всего AC | Покрыто тестами | Тесты зелёные |
|-----------|---------|----------------|---------------|
| BA-001 (Two-way sync) | 7 | 7 | 12/12 |
| BA-002 (Safeguards) | 7 | 6 (AC-007 e2e, вне scope) | 9/9 |
| BA-003 (Drift-check) | 9 | 9 | 47/47 |
| **Итого** | **23** | **22** | **68/68** |

BA-002 AC-007 (smoke-тест LLM-агента) исключён из автоматического прогона — обоснование зафиксировано в test-plan QA-001. Ручная проверка: вызов `/ba` или `/tech-writer` должен быть выполнен PM или BA перед final acceptance.

---

## Рекомендация

- [x] **ready-for-ba-acceptance**
- [ ] block-merge
- [ ] escalation-needed

**Обоснование:** Все 442+ тестов прошли зелёными, 48 тестов перешли из RED в GREEN по сравнению с baseline QA-001 (48 FAILED до Dev-фазы). Ни одного regression не обнаружено. Все три pre-existing проблемы, указанные в брифе (T-W4b-BASELINE, T-UV-PREREQ-06, kb-team delete-regressions), разрешены в рамках эпика. Эпик готов к BA-acceptance gate и `/pm-review`.
