---
properties:
  - name: Тип контента
    value: [ADR]
  - name: Статус
    value: [Approved]
---

# ADR-002: uv обязателен для запуска Python-скриптов шаблона

**Статус:** Approved  
**Дата:** 2026-05-14

---

## Context

Шаблон содержит 5 Python-скриптов в `scripts/` (`validate-content.py`, `validate-profile.py`, `_apply_profile.py`, `_resolve_agents.py`, `_validate_common.py`) и ~10 inline `python3 -c "..."` блоков в `init.sh`. Единственная внешняя зависимость — **PyYAML**.

Текущая проблема: все скрипты требуют `pip install pyyaml` глобально на хост-машине. При отсутствии глобального PyYAML скрипты падают с непрозрачными `ImportError` без инструкций по исправлению. Это создаёт неудовлетворительный UX при первом запуске и делает шаблон зависимым от состояния Python-окружения хоста.

Owner-требование (закреплено в `docs/requirements/uv-enforcement.md`): все Python-скрипты запускаются исключительно через `uv run`; прямой вызов `python3 script.py` запрещён; fallback на системный Python не допускается.

Landscape-исследование: `docs/research/uv-enforcement-landscape.md`.

---

## Decision

**`uv` является обязательным инструментом шаблона. Запуск Python-скриптов — только через `uv run`.**

Конкретные решения:

1. Все 5 существующих `.py`-файлов в `scripts/` получают **PEP 723 inline metadata** (`# /// script` блок) с `requires-python = ">=3.11"` и `dependencies = ["pyyaml>=6.0,<7.0"]`.
2. Inline `python3 -c "..."` блоки в `init.sh` мигрируют в `scripts/_init_helpers.py` с PEP 723-заголовком; `init.sh` вызывает `uv run scripts/_init_helpers.py <subcommand>`.
3. `init.sh` содержит функцию `check_prerequisites()` — первой в main-блоке, до любых destructive операций. При отсутствии `uv` в PATH: stderr-сообщение с per-OS install-инструкциями, `exit 1`.
4. `INIT_FORCE=1` не обходит prereq-gate.
5. `check.sh` и `test-*.sh` содержат короткий uv-guard в начале.
6. `uv.lock` не создаётся и не коммитится.
7. Прямые упоминания `python3 script.py` в README, CLAUDE.md, `docs/extending.md`, `docs/troubleshooting.md` заменяются на `uv run scripts/<name>.py`.

---

## Consequences

**Positive:**

- Hermetic Python-окружение: PyYAML изолирован в ephemeral venv uv, глобальный pip не нужен.
- Воспроизводимость: `requires-python = ">=3.11"` + `pyyaml>=6.0,<7.0` фиксируют совместимое окружение без lock-файла.
- Zero pip-pollution: шаблон не модифицирует глобальный Python-state хоста.
- Python managed by uv: если Python 3.11+ не установлен — uv скачивает нужную версию автоматически.
- Ясный UX при отсутствии uv: сообщение с конкретными install-командами per-OS вместо `command not found`.
- Кэш (`~/.cache/uv`) ускоряет повторные запуски до ~0с.

**Negative:**

- Новые пользователи должны установить `uv` до запуска `init.sh`. Это дополнительный шаг по сравнению с «скопировал → запустил».
- Первый `uv run` на cold machine занимает 5–15 с (resolve + download PyYAML).
- Пользователи, установившие uv в нестандартный PATH без перезапуска shell, получат ложно-отрицательный prereq-fail.

**Mitigations:**

- README содержит секцию «Prerequisites» с install-командами — пользователь видит требование до первого запуска.
- `check_prerequisites()` выводит install-hint и указание добавить uv в PATH (при нестандартной установке).
- Latency первого запуска документируется в README callout.

---

## Alternatives Considered

**Option B: `pyproject.toml` + `uv sync` + `uv run python ...`**

Когда оправдан: multi-file проект с несколькими зависимостями, нужен `uv.lock` для воспроизводимых CI-сборок.

Почему отклонён: добавляет `pyproject.toml` и `uv.lock` в шаблон — артефакты, которые downstream-проект получает «по ошибке» и должен удалять. Требует `uv sync` перед первым запуском. Противоречит «single-file self-contained scripts» философии. Единственная dep (PyYAML) не требует lock-файла.

**Option C: hybrid wrapper `_py.sh`**

Идея: bash-обёртка активирует venv перед вызовом python.

Почему отклонён: пользователь может обойти обёртку и вызвать `python3 script.py` напрямую — нет механизма enforcement на уровне инструмента. Добавляет indirection без гарантии. Owner-требование «только uv» не выполняется.

Детальный сравнительный анализ опций: `docs/research/uv-enforcement-landscape.md`, раздел «Альтернативы».

---

## Связанные статьи

- `docs/requirements/uv-enforcement.md` — BRQ с FR/AC/NFR
- `docs/research/uv-enforcement-landscape.md` — RES-001, landscape и Q1-Q5
- `docs/architecture/uv-enforcement-spec.md` — детальная спека реализации
- [PEP 723](https://peps.python.org/pep-0723/) — спецификация inline script metadata
- [uv scripts guide](https://docs.astral.sh/uv/guides/scripts/) — `uv run`, PEP 723, `--with` flag
- [uv installation](https://docs.astral.sh/uv/getting-started/installation/) — per-OS install commands
