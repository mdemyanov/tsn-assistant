# Wave 4b — Design

**Дата:** 2026-05-07
**Статус:** approved (awaiting plan)
**Предшественники:** Wave 4a (override mechanic + kb-product pilot, see `2026-05-07-wave-4a-design.md`)
**Скоуп:** Content baseline minimization + W4a Medium cleanup (унифицированный error-handling, dead-field/param drop)

## 1. Контекст и мотивация

После W4a baseline `content/` дублирует часть `docs/overlays/profiles/project/content-scaffold/`. Из-за этого профили `kb-team` и `kb-product` вынуждены делать 5–6 `op:delete`, чтобы вычистить delivery-структуру до своего scaffold'а. Это:

- увеличивает размер per-profile манифестов;
- ломает симметрию профилей (часть «получает baseline и удаляет лишнее», часть «удаляет всё и докладывает свой»);
- блокирует чистый custom-профиль (он унаследует delivery-папки, которых не должен иметь);
- усложняет любую новую профильную работу.

**Цель W4b:** сделать baseline минимальным (`content/_index.md` и всё), а каждый профиль — полным declarative scaffold через `op:add content-scaffold/`. Параллельно закрыть Medium follow-up'ы W4a, тематически связанные с тем же кодом (`_apply_profile.py`, `apply-overlay.sh`, manifest schema).

## 2. Целевое состояние

### 2.1 Baseline `content/`

После W4b в репозитории остаётся ровно один файл из `content/`:

```
content/
└── _index.md
```

Все остальные `_index.md` (00-project/, 10-domain/, 30-requirements/, 40-architecture/, 60-implementation/, 70-operations/) удаляются из baseline и появляются в репозитории через профильные `content-scaffold/`.

### 2.2 Профильные манифесты

- `project`: без изменений в declarative секции (уже использует `op:add content-scaffold/`). Только удостовериться, что content-scaffold содержит **все** уникальные папки baseline (например, `10-domain/research/_index.md`, отсутствующий в текущем scaffold).
- `kb-team`: снять 5 `op:delete` (00-project, 30-requirements, 40-architecture, 60-implementation, 70-operations). `op:add content-scaffold/` остаётся — он всё так же даёт kb-team-specific структуру (10-domain, 20-onboarding, 30-runbooks, 40-roles, 50-incidents).
- `kb-product`: снять 6 `op:delete` (00-project, 10-domain, 30-requirements, 40-architecture, 60-implementation, 70-operations). `op:add content-scaffold/` остаётся.
- 4 stub-профиля (`product`, `methodology`, `course`, `custom`): не трогаем в W4b. Они уйдут в W4c.

### 2.3 W4a cleanup

- `_apply_profile.py`: единый error-handling — `apply_on_value_mutations`, `apply_dotted_mutation`, `load_manifest` поднимают `ProfileError` (вместо `sys.exit(1)`); top-level `main` ловит и выходит с нужным exit-code.
- `apply-overlay.sh`: `ops_count` вычисляется внутри `_apply_profile.py` и возвращается через JSON plan; убран лишний `python3` invocation.
- `_apply_profile.py`: при сериализации `reason` в TSV strip-ить `\n` (защита от `\x1f`-format breakage при multiline reason).
- Manifest schema: drop `role_status: core` field из `agent_overrides.<role>` записей в kb-team и kb-product манифестах. Validator (`validate-profile.py`) перестаёт упоминать field.
- `_apply_profile.py.compute_verdict`: убрать неиспользуемый параметр `profile_dir` и его передачу в callers.

### 2.4 Examples

3 example-каталога (`examples/{project,kb-team,kb-product}-example/`) полностью регенерируются от обновлённого state. Diff content vs предыдущей версии должен показывать только эффект baseline minimization (никаких unrelated changes).

## 3. Затронутые файлы

| Категория | Путь |
|-----------|------|
| Baseline | `content/{00-project,10-domain,30-requirements,40-architecture,60-implementation,70-operations}/` (delete) |
| Project scaffold | `docs/overlays/profiles/project/content-scaffold/10-domain/research/_index.md` (add, если отсутствует) |
| Manifests | `docs/overlays/profiles/{kb-team,kb-product}/manifest.yaml` |
| Scripts | `scripts/_apply_profile.py`, `scripts/apply-overlay.sh`, `scripts/validate-profile.py`, `scripts/validate-content.py` |
| Tests | `tests/test-template.sh`, `tests/test-validate-profile.sh` (если задевает M11), `tests/test-validate-content.sh` |
| Examples | `examples/{project,kb-team,kb-product}-example/` (regenerate) |
| Docs | `docs/lessons-learned.md`, `docs/architecture-overview.md` (если упоминает `role_status`) |

## 4. Декомпозиция (16 atomic tasks)

### Phase P1 — Baseline migration (sequential)

- **T1.** Diff-check всех baseline `_index.md` против project content-scaffold копий. Если расходятся — мигрировать актуальную версию в `content-scaffold/`. Минимум добавить `docs/overlays/profiles/project/content-scaffold/10-domain/research/_index.md` (отсутствует сейчас).
- **T2.** Удалить из репозитория `content/{00-project,10-domain,30-requirements,40-architecture,60-implementation,70-operations}/` (recursive). Оставить только `content/_index.md`.
- **T3.** `docs/overlays/profiles/kb-team/manifest.yaml` — убрать 5 `op:delete` записей. `op:add` и `op:replace` сохранить.
- **T4.** `docs/overlays/profiles/kb-product/manifest.yaml` — убрать 6 `op:delete` записей. `op:add` и `op:replace` сохранить.

### Phase P2 — Examples regeneration + tests update (parallel где возможно)

- **T5.** Перегенерировать `examples/project-example/` через `bash scripts/apply-overlay.sh --profile project --target examples/project-example` (или эквивалентный flag).
- **T6.** Перегенерировать `examples/kb-team-example/`.
- **T7.** Перегенерировать `examples/kb-product-example/`.
- **T8.** `tests/test-template.sh` — обновить per-profile assertions: после init у каждого профиля ожидаемая структура совпадает с `examples/<profile>-example/`. Добавить ассерт «git ls-files content/ == 1 файл (`_index.md`)» для baseline (pre-init).
- **T9.** `scripts/validate-content.py` — grep на наличие захардкоженных проверок baseline-папок (например, `00-project`, `30-requirements` как required). Ожидание: validator проверяет только Gramax convention (`_index.md` в каждой подпапке с `.md` файлами); baseline-имена не должны фигурировать. Если найдены — удалить эти проверки. Если не найдены — задача no-op, фиксируется отдельным коммитом «verified».

### Phase P3 — W4a Medium cleanup (parallel-independent от P1/P2)

P3 трогает скрипты и manifest schema; не зависит от content/. Запускается одновременно со стартом P1.

- **T10.** `scripts/_apply_profile.py`:
  - `apply_on_value_mutations`: `sys.exit(1)` → `raise ProfileError(...)` с осмысленным message.
  - `apply_dotted_mutation`: то же.
  - `load_manifest`: то же.
  - Top-level `main` ловит `ProfileError`, печатает в stderr, exit code 1.
  - Добавить класс `ProfileError(Exception)` если ещё нет.
- **T11.** `scripts/apply-overlay.sh`:
  - Убрать отдельный `python3 -c '...len(plan["operations"])...'` для подсчёта `ops_count`.
  - Передать поле `ops_count` (или `len(operations)`) в JSON plan, который возвращает `_apply_profile.py`.
  - Bash читает значение из plan output один раз.
- **T12.** `scripts/_apply_profile.py`: при сериализации `reason` в TSV-формат добавить `.replace("\n", " ").replace("\r", " ")` (или эквивалент). Добавить unit-test с multiline reason.
- **T13.** Drop `role_status` field:
  - Из `docs/overlays/profiles/kb-team/manifest.yaml` (`agent_overrides.tech-writer.role_status`).
  - Из `docs/overlays/profiles/kb-product/manifest.yaml` (там же).
  - Из `scripts/validate-profile.py` — если M11 упоминает / валидирует field, убрать ссылки.
  - Из `docs/architecture-overview.md` — если описано в overrides-разделе, убрать.
- **T14.** `scripts/_apply_profile.py.compute_verdict`: убрать параметр `profile_dir` из сигнатуры и из всех вызовов.

**P3 dispatch уточнение:** `T10`, `T12`, `T14` все трогают `_apply_profile.py`. Чтобы избежать merge-конфликтов в subagent-driven параллели, эти три задачи дispatch'аются **sequentially одним потоком** (T10 → T12 → T14). `T11` (apply-overlay.sh) и `T13` (validate-profile.py + два манифеста) реально параллельны. Итог: P3 = 3 потока вместо 5.

### Phase P4 — Final smoke + lessons (sequential)

- **T15.** `bash scripts/check.sh --full` — все ассерты зелёные. Зафиксировать новое количество ассертов в lessons-learned.
- **T16.** Запись в `docs/lessons-learned.md` об итерации W4b: scope, метрики, неожиданности, follow-up'ы.

## 5. Граф зависимостей и параллелизация

```
Wave dispatch 1 (старт W4b — 4 параллельных subagent'а):
  ├─ T1 (P1.1, аудит scaffold completeness)
  ├─ T10→T12→T14 (P3 поток A: _apply_profile.py modifications)
  ├─ T11 (P3 поток B: apply-overlay.sh ops_count)
  └─ T13 (P3 поток C: role_status field drop)

Wave dispatch 2 (после T1):
  └─ T2 (delete baseline content folders)

Wave dispatch 3 (после T2, 2 параллельных):
  ├─ T3 (kb-team manifest)
  └─ T4 (kb-product manifest)

Wave dispatch 4 (после T3+T4, 3 параллельных):
  ├─ T5 (project-example regen)
  ├─ T6 (kb-team-example regen)
  └─ T7 (kb-product-example regen)

Wave dispatch 5 (после T5+T6+T7):
  └─ T8 (test-template.sh assertions)

Wave dispatch 6 (после T8):
  └─ T9 (validate-content.py)

Wave dispatch 7 (после P1+P2+P3 завершены):
  └─ T15 (full smoke)

Wave dispatch 8:
  └─ T16 (lessons-learned)
```

Critical path: T1 → T2 → T3/T4 → T5/T6/T7 → T8 → T9 → T15 → T16 (8 шагов).
P3 (T10/T11/T12/T13/T14) укладывается параллельно P1+P2 — wall-clock saving ≈ 30%.

## 6. Risks / edge cases

1. **`op_add` overwrite поведение.** Если baseline удалится, а scaffold-копия `_index.md` отличается текстом, после миграции пользователь получит scaffold-версию. **Mitigation:** T1 делает diff и явно мигрирует актуальную версию (если расхождения).
2. **`test-template.sh` ожидания baseline-папок.** Существующие ассерты могут жёстко требовать «после init есть `content/00-project/_index.md`». После миграции файл всё ещё будет (через `op:add`), но ассерт на pre-init состояние сломается. **Mitigation:** T8 чётко разделяет pre-init и post-init проверки.
3. **Backwards compat для уже init-нутых проектов.** Пользователи на старой версии шаблона имеют `content/{00-project,...}` локально. Pull новой версии не удалит их файлы (они отредактированы). **Mitigation:** пометить W4b как **breaking minor** в lessons-learned. Migration tooling — out of scope, идёт в W4c+.
4. **`role_status: core` field references.** Если M11 валидирует field — drop сломает existing manifests. **Mitigation:** pre-T13 grep `role_status` в `scripts/validate-profile.py` и зависимых тестах.
5. **Subagent file conflicts в P3.** T10/T12/T14 все трогают `_apply_profile.py`. **Mitigation:** sequential поток A (см. §4 Phase P3 dispatch уточнение).
6. **Examples drift.** Регенерация может затронуть детали (timestamps, ordering), не связанные с baseline minimization. **Mitigation:** diff проверка после T5/T6/T7 — допустимы только изменения, объяснимые удалением baseline-папок и связанным `op:delete` removal.

## 7. Testing strategy

### 7.1 TDD discipline (`superpowers:test-driven-development`)

Каждая задача с code-effect (T10–T14, T8, T9) — failing test первым.

### 7.2 Per-task unit-tests

- **T2:** `git ls-files content/` после T2 ⇒ ровно `content/_index.md`.
- **T10:** broken manifest → exception типа `ProfileError`, не `SystemExit` (новый negative test).
- **T11:** `apply-overlay.sh --profile project --dry-run` печатает `ops_count` без второго `python3` invocation (можно ассертить через `set -x` / counting).
- **T12:** unit-test `_apply_profile.py` с manifest, где `reason` содержит `\n` — TSV emission корректный, парсинг не ломается.
- **T13:** validate-profile с manifest без `role_status` ⇒ зелёное; с `role_status` ⇒ либо игнор (preferred), либо warning (acceptable).
- **T14:** `compute_verdict` вызывается без `profile_dir` параметра.

### 7.3 Integration

- **T15:** `bash scripts/check.sh --full` зелёный.

### 7.4 Acceptance

- Новый ассерт в `tests/test-template.sh`: `[[ $(git ls-files content/ | wc -l) == "1" ]]` (только `_index.md`).
- 3 example каталога регенерированы и diff vs прошлой версии показывает **только** эффект baseline minimization.

## 8. Out of scope (defer на W4c+)

- 4 stub профиля → stable: `product`, `methodology`, `course`, `custom`.
- Init UX customization (interactive prompts для override toggles).
- Migration tooling (`migrate-profile.sh`, `upgrade-template.sh`) для пользователей со старой версией baseline.
- Hardcoded `--base-dir ".claude/plugins/project/agents/"` в `op_resolve_agents` — фичу plugin-rename отложили.
- Naming `_resolve_agents.py` (decision: keep underscore convention).
- Spec/plan move в `content/00-project/specs/` — breaks superpowers tooling assumptions.
- Mixed-language strings (stylistic).
- `set -u` empty-array hint в lessons-learned (W4a cleanup minor).

## 9. Метрики успеха

- ✅ `content/` содержит ровно 1 файл (`_index.md`).
- ✅ kb-team манифест: 0 `op:delete`. kb-product манифест: 0 `op:delete`.
- ✅ `_apply_profile.py` не вызывает `sys.exit(1)` (только raise) — grep-проверка.
- ✅ Manifest schema: 0 упоминаний `role_status` в kb-team/kb-product manifests.
- ✅ `bash scripts/check.sh --full` — зелёный. Число ассертов ожидается в диапазоне 170–195 (W4a baseline = 176; после T8 часть ассертов test-template.sh обновляется, +1 новый ассерт «git ls-files content/ == 1», +1–2 новых ассерта в P3 cleanup тестах). Финальное число фиксируется в lessons-learned.
- ✅ 3 example каталога регенерированы.
- ✅ `docs/lessons-learned.md` дополнен записью W4b.

## 10. Estimate

- 16 atomic tasks + ожидаемые 3–6 fix-commits после two-stage review (W4a-метрика: ~25% atomic'ов получают fix).
- Total: 20–25 коммитов.
- Wall-clock: с учётом P3 параллели и subagent-driven-development — короче чем линейная W4a (которая дала ~30 коммитов).
