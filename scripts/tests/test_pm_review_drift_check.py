# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pytest>=8.0",
#   "pyyaml>=6.0",
# ]
# ///
"""
test_pm_review_drift_check.py — QA-001 / BA-003 AC-001..AC-005, AC-007

Тесты на алгоритм drift-check из design-spec §3c.
SA рекомендует реализовать drift-check как scripts/_drift_check.py —
тесты написаны под этот модуль (unit-тесты на функцию check_drift()).

Если Dev реализует drift-check иначе — тесты нужно адаптировать,
сохранив семантику сценариев.

AC-001: WARN при downstream-changes без upstream-changes (с именами файлов).
AC-002: тишина при парных правках.
AC-003: INFO при bypass с непустым reason.
AC-004: WARN при пустом reason в skip-drift.
AC-005: INFO-skip при отсутствии drift_pairs в manifest.
AC-007: content-only профиль (kb-team) выдаёт WARN при content↔content drift.
"""
import pathlib
import sys
import pytest

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
DRIFT_CHECK_MODULE = REPO_ROOT / "scripts" / "_drift_check.py"

# ---------------------------------------------------------------------------
# Import guard: если модуль ещё не создан — все тесты помечаются как FAIL (RED)
# ---------------------------------------------------------------------------

def import_drift_check():
    """Пытается импортировать scripts/_drift_check.py. Возвращает модуль или None."""
    if not DRIFT_CHECK_MODULE.exists():
        return None
    # Добавляем scripts/ в sys.path для импорта
    scripts_dir = str(REPO_ROOT / "scripts")
    if scripts_dir not in sys.path:
        sys.path.insert(0, scripts_dir)
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location("_drift_check", DRIFT_CHECK_MODULE)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Фикстуры — fake drift_pairs и изменённые файлы
# ---------------------------------------------------------------------------

DRIFT_PAIRS_PROJECT = [
    {"upstream": "content/30-requirements/", "downstream": "src/"},
    {"upstream": "content/40-architecture/", "downstream": "content/70-operations/"},
]

DRIFT_PAIRS_KB_TEAM = [
    {"upstream": "content/40-roles/", "downstream": "content/30-runbooks/"},
    {"upstream": "content/10-domain/", "downstream": "content/40-roles/"},
]


def _call_drift_check(module, changed_files, drift_pairs, bypass_reason=None):
    """
    Обёртка над module.check_drift().
    Ожидаемая сигнатура (SA-рекомендация):
        check_drift(changed_files: list[str], drift_pairs: list[dict], bypass_reason: str | None)
        -> list[dict]  # список событий: [{"level": "WARN"|"INFO", "message": str, ...}]

    Если функция не существует — тест падает с TODO-сообщением.
    """
    assert module is not None, (
        "TODO: scripts/_drift_check.py не найден. "
        "Dev создаёт модуль с функцией check_drift(changed_files, drift_pairs, bypass_reason) "
        "согласно design-spec §3c и рекомендации SA (§6 риски)"
    )
    assert hasattr(module, "check_drift"), (
        "TODO: scripts/_drift_check.py не содержит функцию check_drift(). "
        "Dev реализует функцию согласно алгоритму из design-spec §3c"
    )
    return module.check_drift(changed_files, drift_pairs, bypass_reason)


# ---------------------------------------------------------------------------
# AC-001: WARN при downstream-changes без upstream-changes
# ---------------------------------------------------------------------------

def test_ac001_warn_on_downstream_only_change():
    """AC-001 (BA-003): downstream изменён без upstream → WARN с именами файлов."""
    module = import_drift_check()
    changed = ["src/auth/login.py"]  # downstream-только
    events = _call_drift_check(module, changed, DRIFT_PAIRS_PROJECT)
    warn_events = [e for e in events if e.get("level") == "WARN"]
    assert len(warn_events) >= 1, (
        f"TODO: AC-001 — drift-check должен выдать WARN при изменении downstream (src/) "
        f"без upstream (content/30-requirements/). Получено событий WARN: {warn_events}, "
        f"все события: {events}"
    )
    # Файл должен быть упомянут в WARN
    warn_messages = " ".join(e.get("message", "") for e in warn_events)
    assert "src/auth/login.py" in warn_messages or "src/" in warn_messages, (
        f"TODO: AC-001 — WARN должен содержать имя downstream-файла. "
        f"Получено: {warn_messages!r}. "
        f"NFR-001: не общая фраза, а конкретные пути"
    )


def test_ac001_warn_message_contains_pair_info():
    """AC-001: WARN содержит информацию о паре upstream/downstream."""
    module = import_drift_check()
    changed = ["src/main.py"]
    events = _call_drift_check(module, changed, DRIFT_PAIRS_PROJECT)
    warn_events = [e for e in events if e.get("level") == "WARN"]
    assert len(warn_events) >= 1, (
        "TODO: AC-001 — ожидается WARN при изменении src/ без content/30-requirements/"
    )
    warn_messages = " ".join(e.get("message", "") + str(e) for e in warn_events)
    # Пара должна быть упомянута
    has_upstream = "content/30-requirements" in warn_messages or "upstream" in warn_messages
    has_downstream = "src/" in warn_messages or "downstream" in warn_messages
    assert has_upstream or has_downstream, (
        f"TODO: AC-001 — WARN должен содержать информацию о паре. "
        f"Получено: {warn_messages!r}"
    )


# ---------------------------------------------------------------------------
# AC-002: тишина при парных правках (upstream И downstream изменены)
# ---------------------------------------------------------------------------

def test_ac002_no_warn_when_both_sides_changed():
    """AC-002 (BA-003): upstream и downstream оба изменены → нет WARN."""
    module = import_drift_check()
    changed = ["content/30-requirements/auth.md", "src/auth/login.py"]
    events = _call_drift_check(module, changed, DRIFT_PAIRS_PROJECT)
    warn_events = [e for e in events if e.get("level") == "WARN"]
    assert len(warn_events) == 0, (
        f"TODO: AC-002 — при парных правках (upstream И downstream) не должно быть WARN. "
        f"Получено WARN: {warn_events}"
    )


def test_ac002_no_warn_when_only_upstream_changed():
    """AC-002 boundary: только upstream изменён (без downstream) → нет WARN (FR-004)."""
    module = import_drift_check()
    changed = ["content/30-requirements/new-feature.md"]  # только upstream
    events = _call_drift_check(module, changed, DRIFT_PAIRS_PROJECT)
    warn_events = [e for e in events if e.get("level") == "WARN"]
    assert len(warn_events) == 0, (
        f"TODO: AC-002 (BA-003 FR-004) — обновление только upstream (без downstream) "
        f"не должно порождать WARN. Получено: {warn_events}"
    )


def test_ac002_no_warn_when_no_changes():
    """AC-002 boundary: пустой diff → нет ни WARN, ни INFO (полная тишина)."""
    module = import_drift_check()
    changed = []  # пустой diff
    events = _call_drift_check(module, changed, DRIFT_PAIRS_PROJECT)
    warn_events = [e for e in events if e.get("level") in ("WARN", "INFO")]
    assert len(warn_events) == 0, (
        f"TODO: AC-002 edge-case — пустой diff должен давать полную тишину. "
        f"Получено: {warn_events}"
    )


# ---------------------------------------------------------------------------
# AC-003: INFO при bypass с непустым reason
# ---------------------------------------------------------------------------

def test_ac003_info_bypass_with_nonempty_reason():
    """AC-003 (BA-003): bypass с непустым reason → INFO, нет WARN."""
    module = import_drift_check()
    changed = ["src/auth/login.py"]  # downstream-только — без bypass был бы WARN
    bypass_reason = "refactoring only — no requirements changed"
    events = _call_drift_check(module, changed, DRIFT_PAIRS_PROJECT, bypass_reason=bypass_reason)
    warn_events = [e for e in events if e.get("level") == "WARN"]
    info_events = [e for e in events if e.get("level") == "INFO"]
    assert len(warn_events) == 0, (
        f"TODO: AC-003 — при bypass с непустым reason не должно быть WARN. "
        f"Получено WARN: {warn_events}"
    )
    assert len(info_events) >= 1, (
        f"TODO: AC-003 — при bypass с непустым reason должен быть INFO о bypass. "
        f"Получено INFO: {info_events}, все события: {events}"
    )
    info_messages = " ".join(e.get("message", "") for e in info_events)
    assert "bypass" in info_messages.lower() or "skip-drift" in info_messages.lower(), (
        f"TODO: AC-003 — INFO-сообщение должно упоминать bypass. "
        f"Получено: {info_messages!r}"
    )
    assert bypass_reason in info_messages or "refactoring" in info_messages, (
        f"TODO: AC-003 — INFO должен содержать reason. Получено: {info_messages!r}"
    )


# ---------------------------------------------------------------------------
# AC-004: WARN при пустом reason в skip-drift
# ---------------------------------------------------------------------------

def test_ac004_warn_on_empty_bypass_reason():
    """AC-004 (BA-003): bypass с пустым reason → WARN об отсутствии обоснования."""
    module = import_drift_check()
    changed = ["src/auth/login.py"]
    bypass_reason = ""  # пустая строка
    events = _call_drift_check(module, changed, DRIFT_PAIRS_PROJECT, bypass_reason=bypass_reason)
    warn_events = [e for e in events if e.get("level") == "WARN"]
    assert len(warn_events) >= 1, (
        f"TODO: AC-004 — bypass с пустым reason должен порождать WARN. "
        f"BR-002 (BA-003): пустой reason недопустим. "
        f"Получено событий WARN: {warn_events}, все: {events}"
    )


def test_ac004_warn_on_whitespace_bypass_reason():
    """AC-004 boundary: bypass с reason из пробелов → WARN (эквивалент пустого)."""
    module = import_drift_check()
    changed = ["src/auth/login.py"]
    bypass_reason = "   "  # только пробелы
    events = _call_drift_check(module, changed, DRIFT_PAIRS_PROJECT, bypass_reason=bypass_reason)
    warn_events = [e for e in events if e.get("level") == "WARN"]
    assert len(warn_events) >= 1, (
        f"TODO: AC-004 — bypass с reason из пробелов эквивалентен пустому → WARN. "
        f"Получено: {warn_events}"
    )


# ---------------------------------------------------------------------------
# AC-005: INFO-skip при отсутствии drift_pairs в manifest
# ---------------------------------------------------------------------------

def test_ac005_info_skip_when_no_drift_pairs():
    """AC-005 (BA-003): manifest без поля drift_pairs → INFO-skip, нет WARN/FAIL."""
    module = import_drift_check()
    changed = ["src/auth/login.py"]
    # Передаём None — символизирует «drift_pairs отсутствует в manifest»
    events = _call_drift_check(module, changed, drift_pairs=None)
    warn_events = [e for e in events if e.get("level") == "WARN"]
    assert len(warn_events) == 0, (
        f"TODO: AC-005 — отсутствие drift_pairs не должно порождать WARN. "
        f"BR-003 (BA-003): graceful degradation → INFO-skip. "
        f"Получено WARN: {warn_events}"
    )
    # Должен быть INFO
    info_events = [e for e in events if e.get("level") == "INFO"]
    assert len(info_events) >= 1, (
        f"TODO: AC-005 — отсутствие drift_pairs должно порождать INFO-skip. "
        f"Получено INFO: {info_events}, все события: {events}"
    )
    info_messages = " ".join(e.get("message", "") for e in info_events)
    assert "drift_pairs" in info_messages or "skip" in info_messages.lower(), (
        f"TODO: AC-005 — INFO должен упоминать drift_pairs или skip. "
        f"Получено: {info_messages!r}"
    )


def test_ac005_info_skip_when_empty_drift_pairs():
    """AC-005 boundary: drift_pairs=[] (custom-профиль) → INFO-skip, нет WARN."""
    module = import_drift_check()
    changed = ["some/changed/file.md"]
    events = _call_drift_check(module, changed, drift_pairs=[])
    warn_events = [e for e in events if e.get("level") == "WARN"]
    assert len(warn_events) == 0, (
        f"TODO: AC-005 — пустой drift_pairs=[] не должен порождать WARN. "
        f"custom-профиль: graceful INFO-skip. Получено: {warn_events}"
    )


# ---------------------------------------------------------------------------
# AC-007: content-only профиль (kb-team) выдаёт WARN при content↔content drift
# ---------------------------------------------------------------------------

def test_ac007_content_only_profile_warns_on_drift():
    """AC-007 (BA-003): content-only профиль (kb-team) выдаёт WARN при content↔content drift."""
    module = import_drift_check()
    # Изменён downstream (content/30-runbooks/) без upstream (content/40-roles/)
    changed = ["content/30-runbooks/deploy-runbook.md"]
    events = _call_drift_check(module, changed, DRIFT_PAIRS_KB_TEAM)
    warn_events = [e for e in events if e.get("level") == "WARN"]
    assert len(warn_events) >= 1, (
        f"TODO: AC-007 — content-only профиль (kb-team) должен выдавать WARN при "
        f"изменении downstream (content/30-runbooks/) без upstream (content/40-roles/). "
        f"BA-003 BR-004: content-only профили не являются исключением. "
        f"Получено WARN: {warn_events}, все: {events}"
    )


def test_ac007_content_only_kb_team_no_warn_on_clean():
    """AC-007 boundary: kb-team с парными правками → нет WARN."""
    module = import_drift_check()
    changed = [
        "content/40-roles/dev-role.md",        # upstream
        "content/30-runbooks/deploy-runbook.md",  # downstream
    ]
    events = _call_drift_check(module, changed, DRIFT_PAIRS_KB_TEAM)
    warn_events = [e for e in events if e.get("level") == "WARN"]
    assert len(warn_events) == 0, (
        f"TODO: AC-007 boundary — kb-team с парными правками не должен давать WARN. "
        f"Получено: {warn_events}"
    )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
