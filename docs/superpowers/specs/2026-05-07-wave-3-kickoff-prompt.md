# Wave 3 kickoff — оптимизации, profile maturity, deferred items

**Дата создания:** 2026-05-07
**Статус:** черновик kickoff-промта для запуска Wave 3 в новом диалоге
**Зависимости:** Wave 2 завершён (53 коммита, MR `private→public` №1 открыт)

---

## Как использовать этот файл

Скопируй блок «### Промт для нового диалога» ниже целиком в новую сессию Claude Code (запусти из корня репо `project_template`). До этого:

1. Убедись, что MR Wave 2 (`https://doc-hub.gitlab.yandexcloud.net/office-ai/project-template/-/merge_requests/1`) либо смержен в `public`, либо ты сознательно работаешь поверх ещё не смерженной `private`.
2. Сначала пройди фазу **discovery / brainstorming**, а уже потом — spec → plan → SDD-реализация. НЕ запускай implementer-субагентов до approval спека.

---

### Промт для нового диалога

```
Запусти Wave 3 для проекта `project_template` — оптимизации, dev tech-debt cleanup, и dosроение отложенных из Wave 2 фич.

## Контекст

Ты работаешь в Claude Code как PM/координатор (main, Opus, claude-opus-4-7[1m]).
Проект — `/Users/mdemyanov/knowlage/project_template` (GitLab Yandex Cloud, ветка `private`, после Wave 2 уже смерженная или собирающаяся в `public`).

**Wave 2 итог (53 коммита, 8 фаз, T1-T44 + T44a + T44b×4):**
- profile-driven шаблон (7 профилей; project + kb-team baseline; 5 stub'ов)
- 10-ролевой каталог (researcher, ba, sa, dev, devops, qa-author, qa-runner, tech-writer, devsecops, compliance) + AGENTS.md матрица × профиль
- 3 pipeline-orchestrator'а (project-planning, ba-acceptance, critical-path)
- apply-overlay.sh с ops add/replace/delete + strict-non-empty + --force/--dry-run/--profile/--init
- validate-profile.py с M0 (malformed YAML) + M1-M10 + M4 defensive guard

**Артефакты Wave 2 для контекста:**
- Spec: `docs/superpowers/specs/2026-05-06-multi-template-support-design.md` (892 строки)
- Plan: `docs/superpowers/plans/2026-05-06-multi-template-support.md` (3169 строк)
- Final code review (выявил 2 Critical + 9 Important + 7 Minor — Critical устранены, остальное в Wave 3)
- Lessons: `docs/lessons-learned.md` (3 новые записи 2026-05-07)
- Wave 2 kickoff: `docs/superpowers/specs/2026-05-06-wave-2-kickoff-prompt.md`

## Тематические кандидаты Wave 3 (выбираем scope с owner'ом)

### Группа A — Tech debt cleanup из Wave 2 code review

| ID | Issue | Приоритет | Effort |
|----|-------|-----------|--------|
| W3-A1 | **on_value мутации** — actual implementation (был W2 Critical #1, deferred). init.sh передаёт INIT_PROMPT_* в apply-overlay, который применяет on_value мутации к manifest in-memory перед operations | High | M (~2-3 дня) |
| W3-A2 | **apply-overlay.sh refactor: bash → Python helper.** 5 subprocess shells per op (W2 Important #3) → один `_apply_profile.py` (~30 строк), читает manifest, эмиттит JSON-план; bash вызывает один раз. Устраняет также W2 Important #4 (quoting injection в `$profile_dir`). | High | M (~1 день) |
| W3-A3 | **M4 defensive guard visibility** (W2 Important #10). Если AGENTS.md существует, но `## Каталог ролей` не парсится — emit warning «AGENTS.md exists but '## Каталог ролей' table not parsed; M4 skipped». 5-line fix | Low | S (~1 час) |
| W3-A4 | **schema_version validation** (W2 Recommendation #5). Сейчас `schema_version: 1` декларируется но не проверяется. Wave 1-vintage validator примет v2 manifest — добавить enum check сейчас | Low | S |
| W3-A5 | **op_add hidden-file glob hygiene** (W2 Important #6). `cp -r .[!.]*` шумит при отсутствии hidden files. Использовать `shopt -s nullglob dotglob` | Low | S |
| W3-A6 | **is_safe_to_delete edge cases** (W2 Important #7). Symlinks под target пропускаются; добавить тест на «scaffold-only empty subdirs ⇒ safe-to-delete». 500B threshold → именованная константа | Low | S |
| W3-A7 | **kb-team purge `00-project/`** (Wave 2 polish). Сейчас 00-project/ остаётся «мёртвыми» директориями после kb-team init. Добавить op:delete content/00-project/ в kb-team manifest | Low | S |

### Группа B — Stub профили → stable

| ID | Профиль | Что нужно | Effort |
|----|---------|-----------|--------|
| W3-B1 | **product** | content-scaffold (vision/spec/release-notes/...), doc-root.yaml (Тип контента: Vision/Spec/Release Note/Roadmap/Feature/...), полный manifest с operations | L (~3-4 дня) |
| W3-B2 | **kb-product** | content-scaffold (user-guide/api/changelog/faq/...), doc-root.yaml (Audience: Public, Тип контента: User Guide/API Reference/Changelog/FAQ/...), tech-writer override как primary-author (см. W3-C2) | L |
| W3-B3 | **methodology** | scaffold (principles/playbook/glossary/...), doc-root.yaml | M |
| W3-B4 | **course** | scaffold (modules/lessons/assessments/...), doc-root.yaml | M |
| W3-B5 | **custom** | стартер с минимумом (просто шаблон для self-build) | S |

Рекомендация: брать 2-3 на Wave 3 по запросу команды. **product** + **kb-product** — наиболее часто запрашиваемые форматы.

### Группа C — Profile-specific agent overrides (Wave 3 promise)

В Wave 2 каждый профиль имеет пустой `agent-overrides/.gitkeep`. По спеке Wave 3:

| ID | Override | Профиль | Цель |
|----|----------|---------|------|
| W3-C1 | tech-writer как primary-author | kb-product, methodology, course | По умолчанию tech-writer = secondary editor; в этих профилях он — primary author (пишет с нуля) |
| W3-C2 | Mechanic для override resolution | (механика) | Claude Code priority-dir: профильный override `agent-overrides/<role>.md` подменяет base `agents/<role>-agent.md` если присутствует. Нужен validator для override-файлов |
| W3-C3 | (опц.) ba как acceptance-only в kb-team-style профилях | kb-team | На level acceptance, без author mode |

### Группа D — Scrum-agile pipeline (W2 stub → impl)

W2 манифесты декларируют `scrum-agile: disabled` как stub. Wave 3 — реализация:

| ID | Задача |
|----|--------|
| W3-D1 | `commands/pipelines/scrum-agile.md` — orchestrator: backlog → sprint planning → daily → review → retro |
| W3-D2 | Связь с GitHub/GitLab issue tracking (опц.) |
| W3-D3 | Velocity tracking artifacts |

### Группа E — Migration tooling (W2 anti-scope → W3)

| ID | Задача |
|----|--------|
| W3-E1 | `scripts/migrate-profile.sh <from> <to>` — change profile post-init с интерактивным conflict resolution |
| W3-E2 | `scripts/upgrade-template.sh` — pull latest template changes с rebase-style merge user-content и base-template |

### Группа F — Performance / DX optimizations

| ID | Идея |
|----|------|
| W3-F1 | Single Python helper для apply-overlay (см. W3-A2) — устраняет ×5 subprocess overhead |
| W3-F2 | Каскад валидаторов параллельно (validate-content + validate-profile в одном pass с shared manifest cache) |
| W3-F3 | Hook'и в .claude/settings.json для авто-валидации перед commit (precommit gate) |
| W3-F4 | `scripts/check.sh` — single entry-point для всех валидаций (test-* + validate-*), CI-friendly |

### Группа G — Documentation polish (lower priority)

| ID | Задача |
|----|--------|
| W3-G1 | `docs/architecture-overview.md` — high-level diagram системы (профили, overlays, validators, pipelines, agents) |
| W3-G2 | `docs/troubleshooting.md` — частые ошибки (apply-overlay refuse, validator errors, init.sh failures) и решения |
| W3-G3 | Quick-start example проектов: `examples/project-example/`, `examples/kb-team-example/` |

## Discipline (обязательно — те же правила что в Wave 2)

1. **Discovery first.** Перед spec'ом — `superpowers:brainstorming` с owner'ом. Зафиксировать scope (какие группы из A-G в Wave 3 и приоритет).
2. **Spec → Plan → SDD.** После approval спека: `superpowers:writing-plans` → granular plan → `superpowers:subagent-driven-development` (опять с Opus implementer'ами, owner авторизовал в Wave 2 для этого репо — см. memory `feedback_subagent_opus_authorized.md`).
3. **TDD везде где есть тесты.** validators, scripts — failing test → impl → green → commit.
4. **Атомарные коммиты** — один коммит per task. НЕ амендь.
5. **Тесты зелёные перед каждым коммитом:**
   - `bash scripts/test-validate-content.sh` (26 ассертов)
   - `bash scripts/test-validate-profile.sh` (26 ассертов)
   - `bash scripts/test-template.sh` (69 ассертов)
6. **Backwards compatibility:** существующие проекты на основе шаблона должны продолжать работать; init без `--profile` → fallback на `project`.
7. **НЕ destructive операции** (force-push, удаление веток, reset --hard, переписывание истории) без явного подтверждения owner'а.
8. **Wave 2 контракты стабильны** — НЕ ломаем validate-content C1-C7, schema `_index.md`, object-нотация frontmatter, `.doc-root.yaml` palette, profile manifest schema (12 fields), AGENTS.md `## Каталог ролей` heading anchor для M4.
9. **Финальный review:** после каждой фазы — `superpowers:requesting-code-review` на изменённый scope; финальный gate перед merge — full-branch review.
10. **Memory updates:** после Wave 3 обновить auto-memory (типы `feedback`, `project`, `reference`); добавить запись в `docs/lessons-learned.md`.

## Старт

1. **Прочитай:**
   - Этот kickoff целиком (`docs/superpowers/specs/2026-05-07-wave-3-kickoff-prompt.md`)
   - Wave 2 spec для архитектурного контекста: `docs/superpowers/specs/2026-05-06-multi-template-support-design.md` §3-§4
   - Wave 2 lessons (последние 3 записи в `docs/lessons-learned.md`)
   - Текущее состояние ветки: `git log -20 --oneline`

2. **Подтверди готовность одной фразой** («контекст принят, начинаю discovery»).

3. **Запусти `superpowers:brainstorming`** с owner'ом по теме «scope Wave 3»:
   - Какие группы из A-G в фокусе?
   - Какой relative priority внутри выбранных групп?
   - Есть ли deadlines / external dependencies?
   - Любые новые темы, не покрытые в кандидатах A-G?

4. После brainstorming → создать **Wave 3 brief** в `docs/superpowers/specs/2026-05-XX-wave-3-brief.md` (формат как `2026-05-06-multi-template-support-brief.md`).

5. После brief approval → **interview** owner'а по стратегическим вопросам (как Wave 2 — вопросы Q1-Q18 в `2026-05-06-wave-2-interview-results.md`).

6. После interview → `superpowers:writing-plans` → granular Wave 3 plan.

7. После plan approval → `superpowers:subagent-driven-development` → реализация (model: opus для implementer/reviewer).

8. **НЕ запускай implementer-субагентов до этого момента.** Discovery и planning — критичный gate.

## Ссылки на ключевые файлы Wave 2 (для контекста)

- `AGENTS.md` — каталог 10 ролей + матрица × профиль + pipeline-orchestration
- `CLAUDE.md` — блок «Профильная система»
- `docs/extending.md` — гайд «как добавить роль/pipeline/профиль»
- `docs/overlays/profiles/{project,kb-team}/manifest.yaml` — реальные baseline'ы для копирования паттерна
- `docs/overlays/profiles/{product,kb-product,custom,methodology,course}/manifest.yaml` — stubs (заполняются в W3-B*)
- `scripts/{_validate_common,validate-content,validate-profile,apply-overlay,init,test-*}.{py,sh}` — текущая Wave 2 реализация
- `.claude/plugins/project/agents/*.md` — 10 prompt'ов агентов
- `.claude/plugins/project/commands/*.md` + `pipelines/*.md` — slash-команды
- `docs/lessons-learned.md` — append-only журнал; новые записи Wave 3 пиши в конец

Удачи в Wave 3.
```

---

## Заметки для будущего PM

- В Wave 2 наибольшее затраты были на Phase 4 (12 commit'ов на agent prompts) — content-heavy task'и оказались дольше валидаторов. В Wave 3 если будут expansions stub-профилей (W3-B*), бюджетируйте время аналогично.
- Final code review после Wave 2 нашёл 2 Critical и 9 Important, из которых 1 был критическим concept-level gap (on_value не подключён). В Wave 3 запускать code review **после каждой фазы** (не только финал) — на crucial фазах (B-stub-expansion, C-overrides) это поймает аналогичные проблемы раньше.
- macOS bash 3.2 compat (без associative arrays) — гость в репо. Если Wave 3 потребует более сложных структур, рассмотрите переход script'ов на Python (с уже существующим `_validate_common.py` как base'ом).
