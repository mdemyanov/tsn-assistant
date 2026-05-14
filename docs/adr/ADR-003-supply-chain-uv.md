---
properties:
  - name: Тип контента
    value: [ADR]
  - name: Статус
    value: [Approved]
---

# ADR-003: Supply-chain stance для uv-enforce шаблона

**Статус:** Approved
**Дата:** 2026-05-14
**Связано:** ADR-002 (uv обязателен), эпик `uv-enforce` (SEC-040)

---

## Context

ADR-002 закрепил решение: 6 Python-скриптов шаблона (`scripts/_apply_profile.py`, `_init_helpers.py`, `_resolve_agents.py`, `_validate_common.py`, `validate-content.py`, `validate-profile.py`) используют PEP 723 inline metadata с единственной зависимостью `pyyaml>=6.0,<7.0`. Тот же range повторяется в шести inline `uv run --with 'pyyaml>=6.0,<7.0'` вызовах внутри bash-скриптов (`apply-overlay.sh`, `test-template.sh`, `test-validate-content.sh`, `test-apply-overlay.sh`) — суммарно 18 вхождений, все идентичны.

Owner-decision (см. memory `reference_uv_enforcement.md`, Q2): `uv.lock` НЕ коммитится. Шаблон — заготовка для downstream-проектов; lock-файл «протёк» бы в чужие репозитории и потребовал maintenance, не давая воспроизводимости в downstream-окружении.

SEC-040 — embedded supply-chain audit ДО merge `epic-uv-enforce → private`. Скоуп: только supply-chain (secrets-sweep чистый, см. Consequences; SAST не применим — Python-скрипты шаблона имеют `validate-*` семантику без сетевых вызовов и user-input parsing вне YAML/JSON).

Артефакты для review:
- `scripts/*.py` (6 файлов) — все с PEP 723 заголовком, единый pin.
- `scripts/*.sh` — uv-guard в начале, inline `--with` pins consistent.
- `.gitignore` — `.env`, `*.pem`, `*.key`, `__pycache__/`, `.worktrees/` присутствуют.
- `README.md` — секция Prerequisites (uv install commands per-OS).

---

## Decision

### Q1: uv.lock — НЕ коммитим (подтверждено)

**Verdict:** Owner-decision подтверждён для текущего scope шаблона.

**Rationale:**
- Один direct dep (`pyyaml>=6.0,<7.0`). Transitive deps PyYAML 6.x — нулевые (PyYAML — pure-Python + опциональная C-обёртка libyaml через `pip install` extras, которые мы НЕ запрашиваем).
- PEP 723 заголовок с `requires-python = ">=3.11"` + строгим range фиксирует совместимое окружение для шаблонного use-case (запуск 5–30 раз за время жизни шаблона: init → пара validate-прогонов → конец).
- `uv.lock` в шаблоне создал бы negative UX: downstream-проект клонирует, удаляет lock, восстанавливает свой → лишний шаг. Lock полезен в production-сервисе, не в self-contained scripts.
- При cold cache `uv` сам резолвит latest compatible patch (например, 6.0.2) — это даёт автоматический pickup security patches PyYAML 6.x БЕЗ ручного bump.

**Принимаемые риски:**
- **R1 (Low):** non-deterministic resolution — два запуска с разницей в неделю могут выбрать разные patch-версии PyYAML. Для validation-скриптов (idempotent YAML parse) — приемлемо: API PyYAML 6.x стабилен, breaking changes между patch'ами не зафиксированы за всю историю 6.x.
- **R2 (Low):** silent pickup malicious patch — если PyPI скомпрометирован и в pyyaml 6.x появится malicious patch, `uv run` его подхватит автоматически. Mitigation: PyYAML — high-trust пакет (1.2B+ downloads/мес, поддерживается основным author'ом 15+ лет, репо `yaml/pyyaml` с CI signing); вероятность mass-compromise сравнима с компрометацией PyPI как такового.
- **R3 (Medium):** transitive supply chain через uv-resolver — если botched uv release начнёт резолвить yanked версии. Mitigation: uv требуется явно (ADR-002), пользователь контролирует версию uv через свой install метод.

**Триггеры пересмотра (когда вернуться к решению):**
1. Появилась вторая direct dependency помимо PyYAML — single-dep аргумент перестаёт работать.
2. Шаблон обзавёлся long-running daemon / CLI-tool (не одноразовые scripts) — детерминизм окружения становится важнее.
3. Регуляторное требование SBOM/SLSA от downstream-консьюмера (gov / financial sector adoption).
4. Появился ecosystem из 5+ Python-скриптов с независимыми deps — uv project-mode (`pyproject.toml + uv.lock`) даёт лучший DX.
5. Зафиксирован incident: yanked/malicious release PyYAML 6.x попал в production downstream-проект через шаблон.

### Q2: Pin range `pyyaml>=6.0,<7.0` — оставляем как есть

**Verdict:** Range адекватен для шаблонного use-case. Exact pin (`==6.0.2`) НЕ рекомендуется.

**Rationale:**
- PyYAML 6.0 release (2021-10) ввёл несовместимое с 5.x API (`yaml.load()` без Loader → error). 7.x (когда выйдет) ожидаемо повторит цикл — `<7.0` страхует от этого.
- Range pin даёт автоматический pickup security patches (6.0.1, 6.0.2, …) БЕЗ необходимости bump'а каждого из 18 references.
- Exact pin (`==6.0.2`) дал бы определённость, но создал maintenance burden: при выходе 6.0.3 с CVE fix нужно вручную обновить 18 мест. Для шаблона, который downstream-проекты клонируют и забывают, это плохой trade-off.

**Threat model снимка PyPI (проверено 2026-05-14):**
- Typosquatting: PyPI имеет наблюдаемое имя `pyyaml`, опечатки (`pyyamll`, `pyyam`) либо не зарегистрированы, либо blocked PyPI команда. uv не делает fuzzy-match — typo в pin = explicit error.
- Yanked versions: PyYAML 5.4 был yanked (CVE-2020-14343 в 5.x ветке). Все 6.x релизы — не yanked. uv по умолчанию пропускает yanked версии.
- Malicious uploads: PyYAML находится под контролем `yaml/pyyaml` org с двумя core maintainers (Ingy döt Net + Matt Davis); 2FA enforced PyPI'ем для top-1000 пакетов. Вероятность compromise низкая, но не нулевая.

**Pros range vs exact:**

| Критерий | `>=6.0,<7.0` (current) | `==6.0.2` (exact) |
|----------|------------------------|-------------------|
| Auto-pickup security patches | Да | Нет, ручной bump |
| Защита от breaking 7.x | Да | Да |
| Детерминизм run-to-run | Слабый (latest patch) | Сильный |
| Maintenance burden 18 references | Нулевой | Высокий при каждом patch |
| Защита от malicious patch внутри 6.x | Нет | Слабая (только если уже на безопасной версии) |

**Триггеры пересмотра pin'а:**
1. Зафиксирован CVE в PyYAML 6.x с upstream fix → bump lower bound (`>=6.0.X,<7.0`).
2. PyYAML 7.0 выйдет → audit changelog, расширить range или мигрировать.
3. Появится политика Repro-Builds в downstream-проектах → переход на exact pin + lock-файл.

### Q3: SBOM/audit — рекомендации, не реализация

**Verdict:** Для текущего scope шаблона CI-генерация SBOM не нужна. Рекомендации даём как opt-in для downstream-проектов с compliance-требованиями.

**Rationale:**
- Шаблон — заготовка, не production-сервис. SBOM имеет смысл там, где артефакт деплоится; init.sh — генератор файловой структуры, не deploy-таргет.
- Один dep + range pin делают «SBOM шаблона» тривиальным: `pyyaml` + uv-resolved patch. Полноценный CycloneDX/SPDX overhead для одной строки — over-engineering.
- Downstream-проекты, унаследовавшие шаблон, могут быть в compliance-периметре (SOC2, ISO 27001, регулируемая отрасль). Им стоит дать конкретные рецепты, чтобы они не изобретали.

**Рекомендации (для downstream-проектов, opt-in):**

1. **`pip-audit` / `osv-scanner` интеграция (опционально):**
   - Локально: `uv tool run pip-audit --strict -r <(echo 'pyyaml>=6.0,<7.0')` — покажет CVE в текущем resolved окружении.
   - CI (GitHub Actions): step `osv-scanner -L pyproject.toml` для проектов на pyproject; для PEP 723 шаблонов — извлечь deps из `# /// script` блоков скриптом и фидить в osv-scanner.
   - Cadence: weekly cron-job + on-PR-touching-deps. Не на каждый push (noisy).

2. **SBOM генерация (только если требует customer/auditor):**
   - `uv pip compile --generate-hashes` НЕ применим к шаблону (нет pyproject/requirements.txt). Применим у downstream'а, который перейдёт на uv project-mode.
   - Альтернатива для PEP 723 скриптов: `syft scan dir:scripts/ -o cyclonedx-json` — скан AST с распознаванием PEP 723 headers (syft 0.95+).
   - Хранение: `docs/sbom/<date>.cdx.json`, регенерация при изменении pin'ов.

3. **Где документировать supply-chain stance:**
   - Шаблон: оставляем в этом ADR-003 (`docs/adr/`) — контекст «почему так». README не загромождаем.
   - Downstream-проект на основе шаблона: рекомендуется создать `SECURITY.md` в корне с (а) policy disclosure, (б) supply-chain stance (наследуют ли решения шаблона), (в) контакт security-owner.
   - НЕ создавать `SECURITY.md` в самом шаблоне — это `{{PROJECT_NAME}}`-специфичная информация, у шаблона нет owner'а в смысле security disclosure.

**Пример CI gate для downstream'а** (не реализуем в шаблоне): GitHub Actions workflow с `astral-sh/setup-uv@v4` + `uv tool run pip-audit --strict` на `pull_request` и weekly cron. Скрипт-адаптер извлекает deps из PEP 723 заголовков в `requirements`-формат.

---

## Consequences

**Positive:**
- Supply-chain решения шаблона задокументированы — downstream-проекты знают, что наследуют, и что им докрутить под свой compliance.
- Pin policy + триггеры пересмотра дают чёткий decision-rule: когда current scheme «ломается».
- Secrets-sweep чистый (проверено: grep `(SECRET|API_KEY|PASSWORD|TOKEN|PRIVATE_KEY|AWS_)` по `scripts/`, `docs/`, `README.md`, `CLAUDE.md`, `AGENTS.md`, `.claude/`, `.gramax/` — единственные match'и в плановых TODO-комментариях `OPENAI_API_KEY=` (placeholder без значения) и self-referential pattern в `devsecops-agent.md`). `.gitignore` корректен.

**Negative:**
- Принимаем R1 (non-deterministic patch resolution) и R2 (auto-pickup compromised patch). Для шаблонного scope это осознанный trade-off, а не просмотр.
- Range pin `>=6.0,<7.0` зависит от disciplines'ы maintainer'ов PyYAML — компрометация upstream автоматически перейдёт в downstream-проекты.
- Шаблон не предоставляет out-of-box SBOM/CI-pipeline. Compliance-проекты должны дотачивать.

**Neutral:**
- Пока шаблон остаётся single-dep, ревизия supply-chain раз в год достаточна. При изменении dep-surface (триггеры выше) — пересматриваем немедленно.

---

## References

- `docs/adr/ADR-002-uv-required.md` — base decision on uv enforcement
- `docs/research/uv-enforcement-landscape.md` — RES-001, Q1-Q5 resolution
- `docs/architecture/uv-enforcement-spec.md` — детальная спека PEP 723 placement
- [PEP 723](https://peps.python.org/pep-0723/) — inline script metadata
- [PyYAML CVE history (NVD)](https://nvd.nist.gov/vuln/search/results?query=pyyaml) — для триггера R1/R2 review
- [pip-audit](https://github.com/pypa/pip-audit) — рекомендация для downstream
- [osv-scanner](https://github.com/google/osv-scanner) — рекомендация для downstream
- [syft](https://github.com/anchore/syft) — SBOM generation (PEP 723 support since 0.95)
