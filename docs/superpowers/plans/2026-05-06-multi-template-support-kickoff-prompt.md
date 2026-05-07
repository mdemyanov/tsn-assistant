# Wave 2 Implementation — Kickoff Prompt (для запуска в новом диалоге)

> Скопируй содержимое блока ниже целиком в новый чат с Claude Code в этом проекте. Промт самодостаточен: содержит контекст, ссылки на spec/plan, дисциплину работы и порядок исполнения.

---

```
Запусти реализацию Wave 2 — multi-template support + расширенный subagent-каталог проекта `project_template`.

## Контекст

**Spec и Plan уже написаны и одобрены** — твоя задача только реализовать. НЕ переписывай дизайн, НЕ задавай вопросы, ответы на которые уже зафиксированы в spec.

- **Spec:** `docs/superpowers/specs/2026-05-06-multi-template-support-design.md` (892 строки) — архитектура, компоненты, data flow, GO-критерии.
- **Plan:** `docs/superpowers/plans/2026-05-06-multi-template-support.md` (3169 строк, 44 задачи в 8 фазах) — gранулярные шаги (2-5 минут каждый), точный код, точные команды.
- **Interview-results:** `docs/superpowers/specs/2026-05-06-wave-2-interview-results.md` — 18 ответов owner'а на стратегические вопросы (если plan покажется неясным — сверься с этим).
- **Research:** `content/10-domain/research/multi-template-landscape.md` — landscape (Cookiecutter, copier, AutoGen, CrewAI, эталоны KB).

## Окружение

- **Working directory:** `/Users/mdemyanov/knowlage/project_template`
- **Ветка:** `private` (рабочая по конвенции). НЕ пушь в `main` без явного одобрения.
- **Последние коммиты Wave 2:**
  - `32e786b docs(wave2): implementation plan — 44 задачи в 8 фазах`
  - `9c915b4 docs(wave2): design spec`
  - `96292ea research(wave2): multi-template landscape`
  - `37af4b3 docs(wave2): итоги интервью`
- **Wave 1 контракт стабилен** — НЕ ломаем `validate-content.py` C1-C7, схему `_index.md`, object-нотацию frontmatter, `.doc-root.yaml` palette.

## Discipline (обязательно)

1. **Используй `superpowers:subagent-driven-development`** — каждая задача = свежий implementer-subagent → spec-reviewer → quality-reviewer.
2. **Opus-модель для subagent'ов разрешена** в этом репо (owner авторизовал, см. memory `feedback_subagent_opus_authorized.md`). Используй `model: opus` для implementer/reviewer.
3. **TDD везде, где есть тесты** (validators, apply-overlay) — failing test → implementation → green → commit. Plan расписывает шаги.
4. **Атомарные коммиты** — один коммит per task (как в Wave 1, 22 коммита). НЕ амендь.
5. **Тесты зелёные перед каждым коммитом:**
   - `bash scripts/test-validate-content.sh`
   - `bash scripts/test-validate-profile.sh` (после T2)
   - `bash scripts/test-template.sh`
6. **Валидаторы зелёные:**
   - `python3 scripts/validate-content.py` — exit 0 (warnings допустимы)
   - `python3 scripts/validate-profile.py` — exit 0 (после T22 AGENTS.md)
7. **Auto mode:** работай автономно, спрашивай только при реальном блокере (не routine decisions).
8. **Backwards compatibility:** старые проекты на основе шаблона должны продолжать работать; init без `--profile` → fallback на `project`.
9. **НЕ destructive операции** (`git reset --hard`, удаление веток, force-push) без явного подтверждения owner'а.

## Порядок исполнения

Иди по plan'у фазами. После каждой фазы — короткий status update owner'у (1-2 строки). Если 2+ задач упали подряд — стоп, спроси.

**Фазы:**
1. **Phase 1 — Validators (T1-T10):** _validate_common.py + validate-profile.py M1-M10. TDD strict.
2. **Phase 2 — apply-overlay.sh ops (T11-T15):** --dry-run, --profile, ops add/replace/delete + strict-non-empty + --force. TDD.
3. **Phase 3 — Profile manifests (T16-T18):** project + kb-team baseline + 5 stub'ов. После этого validate-profile должен дать только M4 errors про роли — это нормально до T22.
4. **Phase 4 — Agent prompts (T19-T30):** 5 новых полноценных + AGENTS.md registry (T22 — здесь резолвятся M4) + 6 улучшенных. Используй Opus implementer'ов.
5. **Phase 5 — Slash-команды (T31-T39):** 5 новых + 4 обновления + 3 pipeline-orchestrator команды.
6. **Phase 6 — init.sh refactor (T40):** интерактивный профиль + dynamic init_prompts + on_value мутации + опц. stack-overlay'и.
7. **Phase 7 — Documentation (T41-T43):** CLAUDE.md, README.md, docs/extending.md.
8. **Phase 8 — Final verification (T44):** smoke + lessons + опц. tag.

## Финальный review

После Phase 8 — **`superpowers:requesting-code-review`** на всю Wave 2 (от ветки от 37af4b3) перед предложением merge `private` → `public`. Это обязательный gate.

## Старт

1. Прочитай spec (§1-§3 для контекста, §4 для деталей по компонентам).
2. Прочитай plan (Phase 1 целиком, остальные beforeg выполнения).
3. Подтверди готовность одной фразой («контекст принят, начинаю с Task 1»).
4. Запусти Phase 1 через `superpowers:subagent-driven-development`.
```

---

## Метаданные для PM

- **Файл:** `docs/superpowers/plans/2026-05-06-multi-template-support-kickoff-prompt.md`
- **Когда использовать:** запустить новый чат Claude Code в `/Users/mdemyanov/knowlage/project_template`, скопировать блок выше (между ``` ``` ```)
- **Что произойдёт:** Claude прочитает spec и Phase 1 plan'а, подтвердит готовность, запустит SDD-цикл с Opus subagent'ами по 44 задачам в 8 фазах. По окончании — final review.
- **Длительность ориентировочно:** Wave 1 (22 commits + fix-up) выполнен за один прогон; Wave 2 в 2 раза больше — реалистично 1-2 длинные сессии.
