# SPDD Integration — Implementation Plan

**Дата:** 2026-05-14
**Эпик:** `spdd-integration`
**Фаза roadmap:** MVP (backward-compatible)
**Worktree:** `.worktrees/epic-spdd-integration` (создаётся перед Dev-фазой)
**Базовая ветка:** `private` → merge через `/pm-review` в `public`

## Контекст

Интеграция трёх ключевых идей SPDD (Thoughtworks, апрель 2026) в шаблон `project_template`. Источник декомпозиции: [docs/superpowers/specs/2026-05-14-spdd-integration-kickoff-prompt.md](specs/2026-05-14-spdd-integration-kickoff-prompt.md). Шаблон уже на ~70 % реализует идеи SPDD как процесс — нужно докрутить оставшиеся 30 % точечно, без слома workflow и с поддержкой всех 7 профилей (4 из них content-only).

## Scope: три изменения

1. **Two-way sync rule** в `CLAUDE.md` — при расхождении нижестоящего слоя с вышестоящим: сначала чиним вышестоящий, потом нижестоящий.
2. **Секция «Инварианты и Safeguards»** в шаблонах артефактов `ba-agent.md` + `tech-writer-agent.md`.
3. **Drift-check** в `/pm-review`, параметризованный полем `drift_pairs` в каждом из 7 manifest-ов профиля.

## PM-defaults (резолв открытых вопросов спеки)

| Q | Решение |
|---|---------|
| Q1 | drift_pairs для kb-team/kb-product/course — PM-correction по факт. scaffold (см. таблицу ниже) |
| Q2 | README.md — короткий pointer на CLAUDE.md§two-way-sync; деталь в CLAUDE.md |
| Q3 | Bypass: `skip-drift: <reason>` trailer в commit message (как `Co-Authored-By`); fallback — `Drift: skip — <reason>` в PR body |
| Q4 | Не breaking change: отсутствие `drift_pairs` → INFO-skip без FAIL. Опциональный `docs/upgrading-from-template.md` |

## drift_pairs — PM-предложение

| Профиль | Pairs (upstream → downstream) |
|---------|-------------------------------|
| `project` | `content/30-requirements/→src/`; `content/40-architecture/→src/`; `content/30-requirements/→content/60-implementation/`; `content/40-architecture/→content/70-operations/` |
| `product` | `content/10-vision/→content/30-specs/`; `content/30-specs/→content/40-architecture/`; `content/40-architecture/→src/`; `content/30-specs/→content/50-releases/` |
| `kb-team` | `content/40-roles/→content/30-runbooks/`; `content/30-runbooks/→content/20-onboarding/`; `content/10-domain/→content/40-roles/`; `content/50-incidents/→content/30-runbooks/` |
| `kb-product` | `content/reference/→content/guides/`; `content/guides/→content/troubleshooting/`; `content/reference/→content/getting-started/` |
| `methodology` | `content/10-principles/→content/20-practices/`; `content/20-practices/→content/30-playbooks/`; `content/30-playbooks/→content/40-templates/` |
| `course` | `content/10-module-*/→content/90-assessments/`; `content/20-module-*/→content/90-assessments/`; `content/00-overview/→content/10-module-*/` |
| `custom` | `[]` (open-ended, заполняется на `/init`) |

## Граф задач

```
RES-001 ──→ BA-001 ──→ SA-001 ──→ QA-001 ──→ DEV-001..005 ──→ QA-002 ──→ OPS-001 ──→ BA-acceptance ──→ /pm-review ──→ merge
              BA-002 ────┘
              BA-003 ────┘
```

## Задачи по фазам

### Phase 1 — Researcher (RES-001, опц., ~10 мин)
- **Input:** статья SPDD + comparison-insight в `/Users/mdemyanov/Documents/naumen-cto/`
- **Output:** `content/10-domain/spdd-key-principles.md` (≤300 слов, цитаты с якорями)
- **GO:** заметка существует, три ключевые идеи зафиксированы

### Phase 2 — BA (BA-001..003)
- **BA-001** «Two-way sync rule» → `content/30-requirements/spdd-two-way-sync.md`
- **BA-002** «Invariants & Safeguards» → `content/30-requirements/spdd-safeguards-section.md`
- **BA-003** «Drift-check в /pm-review» → `content/30-requirements/spdd-drift-check.md`
- **Dogfooding:** каждая из трёх статей включает секцию «Инварианты и Safeguards» (она же — предмет BA-002)
- **GO:** AC сформулированы; статьи валидны `validate-content.py`

### Phase 3 — SA (SA-001)
- `content/00-project/adr/ADR-004-spdd-integration.md` (status: accepted)
- `docs/superpowers/specs/2026-05-14-spdd-integration-design.md` (дизайн по всем 7 профилям, схема расширения manifest.yaml, контракт drift-check)
- **GO:** ADR принят; spec покрывает 7 профилей; схема manifest зафиксирована

### Phase 4 — QA-author (QA-001)
- Test plan: `content/30-requirements/spdd-integration-test-plan.md`
- Failing stubs:
  - `scripts/tests/test_drift_pairs_in_manifests.py`
  - `scripts/tests/test_safeguards_section_template.py`
  - `scripts/tests/test_pm_review_drift_check.py`
  - `scripts/tests/test_two_way_sync_in_claude_md.py`
- **GO:** stubs red, ratio 100 % failed

### Phase 5 — Dev (DEV-001..005, в worktree)
- **Worktree:** `git worktree add .worktrees/epic-spdd-integration -b epic/spdd-integration private`
- **DEV-001:** `CLAUDE.md` — раздел «Правило two-way sync» + красная линия для /pm-review
- **DEV-002:** `.claude/plugins/project/agents/ba-agent.md` — секция Safeguards + чек-лист
- **DEV-003:** `.claude/plugins/project/agents/tech-writer-agent.md` — то же
- **DEV-004:** `docs/overlays/profiles/*/manifest.yaml` (7 файлов) — поле `drift_pairs`
- **DEV-005:** `.claude/plugins/project/commands/pm-review.md` — drift-check + bypass
- Также: `README.md` pointer, `AGENTS.md` bullet, опц. `docs/upgrading-from-template.md`
- **GO:** все stubs зелёные; `scripts/check.sh` зелёный

### Phase 6 — QA-runner (QA-002)
- Прогон всех тестов + smoke (`test-template.sh`, `test-apply-overlay.sh`, `test-validate-profile.sh`)
- **GO:** ratio 0/N failed

### Phase 7 — DevOps (OPS-001)
- Расширить `scripts/test-template.sh`: для каждого из 7 профилей проверить наличие two-way-sync, Safeguards, drift_pairs
- **GO:** smoke зелёный по 7 профилям

### Phase 8 — Gate
- `/pipelines/ba-acceptance spdd-integration` → verdict `pass`
- `/pm-review` → merge `private → public`

## GO-критерии эпика

1. Все задачи RES-001..OPS-001 закрыты, BA-acceptance: `pass`
2. AC всех трёх BA-требований покрыты тестами и реализованы
3. `scripts/test-template.sh` зелёный для всех 7 профилей
4. `uv run scripts/validate-content.py` + `validate-profile.py` зелёные
5. /pm-review drift-check на самом эпике чистый
6. Backward-compat: pre-SPDD проект не ломается (INFO-skip без FAIL)
7. `docs/lessons-learned.md` дополнен

## Риски и mitigations

| Риск | Mitigation |
|------|-----------|
| drift_pairs дефолты не сходятся со scaffold для content-only профилей | SA сверяет с фактической структурой `docs/overlays/profiles/*/content-scaffold/` перед коммитом |
| Конфликт изменений CLAUDE.md с Wave-4-C (agent overrides) | DEV-001 сначала; W4-C мерджится после с rebase |
| Bypass-flag путается с уже принятыми trailer'ами (`Co-Authored-By`) | Парсер `/pm-review` строго по префиксу `skip-drift:`; документация явная |
| Существующие проекты теряют валидность | Graceful degradation: отсутствие `drift_pairs` → INFO без FAIL; opt-in upgrade-playbook |

## Rollback

- Все правки в одном epic-branch → rollback = revert merge-commit private←epic
- Manifest-правки изолированы по файлам → можно откатить отдельные профили
- CLAUDE.md / agent.md правки additive → revert не ломает обратную совместимость

## Артефакты

| # | Файл | Создатель |
|---|------|-----------|
| 1 | `content/10-domain/spdd-key-principles.md` | RES-001 |
| 2 | `content/30-requirements/spdd-{two-way-sync,safeguards-section,drift-check}.md` | BA-001..003 |
| 3 | `content/30-requirements/spdd-integration-test-plan.md` | QA-001 |
| 4 | `content/00-project/adr/ADR-004-spdd-integration.md` | SA-001 |
| 5 | `docs/superpowers/specs/2026-05-14-spdd-integration-design.md` | SA-001 |
| 6 | `docs/superpowers/plans/2026-05-14-spdd-integration.md` | PM (этот файл) |
| 7 | `scripts/tests/test_*.py` (4 файла) | QA-001 |
| 8 | Правки: `CLAUDE.md`, `ba-agent.md`, `tech-writer-agent.md`, `pm-review.md`, 7×`manifest.yaml`, опц. `README.md`/`AGENTS.md`/`docs/upgrading-from-template.md` | DEV-001..005 |
| 9 | `scripts/test-template.sh` (правки) | OPS-001 |
| 10 | `docs/lessons-learned.md` (append) | PM на `/pm-review` |
