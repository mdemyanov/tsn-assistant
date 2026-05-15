# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pytest>=8.0",
# ]
# ///
"""
test_two_way_sync_in_claude_md.py — QA-001 / BA-001 AC-001..AC-006

Проверяет наличие ключевых элементов раздела «Правило two-way sync» в CLAUDE.md.

AC-001: CLAUDE.md содержит раздел «Правило two-way sync».
AC-002: Раздел содержит примеры пар для ≥5 профилей (включая ≥2 content-only).
AC-003: Раздел описывает hotfix-исключение и bypass-trailer skip-drift.
AC-004: «Красные линии» содержат строку о блокере /pm-review.
AC-005: README.md содержит pointer на two-way sync.
AC-006: pre-SPDD проект без drift_pairs не получает ошибок (INFO-skip) — тест логики.
AC-007: этот тест-файл проходит зелёным (AC-007 = сам этот файл).
"""
import pathlib
import re
import pytest

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
CLAUDE_MD = REPO_ROOT / "CLAUDE.md"
README_MD = REPO_ROOT / "README.md"

ALL_PROFILES = ["project", "product", "kb-team", "kb-product", "methodology", "course", "custom"]
CONTENT_ONLY_PROFILES = ["kb-team", "kb-product", "methodology", "course"]


def read_file(path: pathlib.Path) -> str:
    assert path.exists(), f"Файл не найден: {path}"
    return path.read_text(encoding="utf-8")


# ---------------------------------------------------------------------------
# AC-001: CLAUDE.md содержит раздел «Правило two-way sync»
# ---------------------------------------------------------------------------

SECTION_MARKER = "## Правило two-way sync"


def test_ac001_claude_md_has_two_way_sync_section():
    """AC-001 (BA-001): CLAUDE.md содержит раздел с заголовком 'Правило two-way sync'."""
    content = read_file(CLAUDE_MD)
    assert SECTION_MARKER in content, (
        f"TODO: AC-001 — CLAUDE.md должен содержать раздел '{SECTION_MARKER}'. "
        f"Dev вставляет готовый блок из design-spec §1 после секции 'Поток работы' "
        f"и перед 'Красные линии'"
    )


def test_ac001_section_contains_upstream_layer_mention():
    """AC-001: раздел упоминает 'вышестоящий слой' (upstream layer)."""
    content = read_file(CLAUDE_MD)
    assert SECTION_MARKER in content, (
        f"TODO: AC-001 — раздел '{SECTION_MARKER}' отсутствует"
    )
    idx = content.index(SECTION_MARKER)
    block = content[idx:]
    next_section = re.search(r"\n## ", block[len(SECTION_MARKER):])
    if next_section:
        block = block[:len(SECTION_MARKER) + next_section.start()]

    has_upstream = (
        "вышестоящий слой" in block or
        "вышестоящего слоя" in block or
        "upstream layer" in block or
        "upstream" in block.lower()
    )
    assert has_upstream, (
        f"TODO: AC-001 — раздел '{SECTION_MARKER}' должен содержать формулировку "
        f"'вышестоящий слой' (upstream layer). "
        f"NFR-002 BA-001: не 'src/', 'спека' — только 'вышестоящий слой' в основном тексте"
    )


# ---------------------------------------------------------------------------
# AC-002: Раздел содержит примеры пар для ≥5 из 7 профилей (включая ≥2 content-only)
# ---------------------------------------------------------------------------

def _get_sync_section(content: str) -> str:
    """Извлекает блок секции two-way sync из CLAUDE.md."""
    if SECTION_MARKER not in content:
        return ""
    idx = content.index(SECTION_MARKER)
    block = content[idx:]
    next_section = re.search(r"\n## ", block[len(SECTION_MARKER):])
    if next_section:
        block = block[:len(SECTION_MARKER) + next_section.start()]
    return block


def test_ac002_section_covers_at_least_5_profiles():
    """AC-002 (BA-001): раздел содержит примеры пар для ≥5 из 7 профилей."""
    content = read_file(CLAUDE_MD)
    block = _get_sync_section(content)
    if not block:
        pytest.fail(f"TODO: AC-001/AC-002 — раздел '{SECTION_MARKER}' отсутствует в CLAUDE.md")

    profiles_found = []
    for profile in ALL_PROFILES:
        # Профиль упомянут в блоке как имя (в таблице или списке)
        if f"`{profile}`" in block or f"«{profile}»" in block or profile in block:
            profiles_found.append(profile)

    assert len(profiles_found) >= 5, (
        f"TODO: AC-002 — раздел должен содержать примеры пар для ≥5 профилей. "
        f"Найдено: {profiles_found} ({len(profiles_found)} из 7). "
        f"Требуются все 7 профилей в таблице пар согласно design-spec §1"
    )


def test_ac002_section_covers_at_least_2_content_only_profiles():
    """AC-002: раздел содержит примеры для ≥2 content-only профилей (kb-team/kb-product/methodology/course)."""
    content = read_file(CLAUDE_MD)
    block = _get_sync_section(content)
    if not block:
        pytest.fail(f"TODO: AC-001 — раздел '{SECTION_MARKER}' отсутствует")

    content_only_found = []
    for profile in CONTENT_ONLY_PROFILES:
        if f"`{profile}`" in block or profile in block:
            content_only_found.append(profile)

    assert len(content_only_found) >= 2, (
        f"TODO: AC-002 — раздел должен содержать примеры для ≥2 content-only профилей. "
        f"Найдено: {content_only_found}. "
        f"Content-only профили: {CONTENT_ONLY_PROFILES}. "
        f"BA-001 FR-002: таблица пар для всех 7 профилей"
    )


def test_ac002_section_mentions_all_7_profiles():
    """AC-002 strict: раздел упоминает все 7 профилей по имени."""
    content = read_file(CLAUDE_MD)
    block = _get_sync_section(content)
    if not block:
        pytest.fail(f"TODO: AC-001 — раздел '{SECTION_MARKER}' отсутствует")

    missing = []
    for profile in ALL_PROFILES:
        if profile not in block:
            missing.append(profile)

    assert not missing, (
        f"TODO: AC-002 strict — раздел должен упоминать все 7 профилей. "
        f"Отсутствуют: {missing}. "
        f"BA-001 FR-002: таблица пар upstream→downstream для всех 7 профилей"
    )


# ---------------------------------------------------------------------------
# AC-003: Раздел описывает hotfix-исключение и bypass-trailer skip-drift
# ---------------------------------------------------------------------------

def test_ac003_section_mentions_hotfix():
    """AC-003 (BA-001): раздел описывает hotfix-исключение."""
    content = read_file(CLAUDE_MD)
    block = _get_sync_section(content)
    if not block:
        pytest.fail(f"TODO: AC-001 — раздел '{SECTION_MARKER}' отсутствует")
    assert "hotfix" in block.lower(), (
        f"TODO: AC-003 — раздел должен описывать hotfix-исключение. "
        f"BA-001 FR-003: hotfix на production — единственное допустимое исключение"
    )


def test_ac003_section_mentions_skip_drift_trailer():
    """AC-003: раздел упоминает bypass-trailer skip-drift."""
    content = read_file(CLAUDE_MD)
    block = _get_sync_section(content)
    if not block:
        pytest.fail(f"TODO: AC-001 — раздел '{SECTION_MARKER}' отсутствует")
    assert "skip-drift" in block, (
        f"TODO: AC-003 — раздел должен упоминать bypass-trailer 'skip-drift'. "
        f"BA-001 AC-003, BR-003: skip-drift: <reason> в commit message"
    )


def test_ac003_section_mentions_postmortem():
    """AC-003: раздел описывает post-mortem обновление upstream после hotfix."""
    content = read_file(CLAUDE_MD)
    block = _get_sync_section(content)
    if not block:
        pytest.fail(f"TODO: AC-001 — раздел '{SECTION_MARKER}' отсутствует")
    has_postmortem = (
        "post-mortem" in block.lower() or
        "postmortem" in block.lower() or
        "после фикса" in block or
        "сразу после" in block
    )
    assert has_postmortem, (
        f"TODO: AC-003 — раздел должен описывать обязательное post-mortem обновление upstream. "
        f"BA-001 FR-003, BR-002: upstream обновляется сразу после hotfix"
    )


# ---------------------------------------------------------------------------
# AC-004: «Красные линии» CLAUDE.md содержат строку о блокере /pm-review
# ---------------------------------------------------------------------------

def test_ac004_red_lines_contain_pm_review_blocker():
    """AC-004 (BA-001): в разделе 'Красные линии' CLAUDE.md есть строка о блокере /pm-review."""
    content = read_file(CLAUDE_MD)

    # Ищем секцию «Красные линии»
    red_lines_marker = re.search(r"## .*[Кк]расные линии|## Red lines", content)
    assert red_lines_marker is not None, (
        "TODO: AC-004 — CLAUDE.md должен содержать раздел 'Красные линии'. "
        "Этот раздел должен существовать для BA-001 FR-004"
    )

    idx = red_lines_marker.start()
    red_block = content[idx:]
    next_section = re.search(r"\n## ", red_block[4:])  # skip ## itself
    if next_section:
        red_block = red_block[:4 + next_section.start()]

    has_blocker = (
        "/pm-review" in red_block and (
            "блокер" in red_block or
            "blocker" in red_block.lower() or
            "расхождение" in red_block
        )
    )
    assert has_blocker, (
        f"TODO: AC-004 — раздел 'Красные линии' должен содержать строку о том, что "
        f"расхождение нижестоящего слоя без обновления вышестоящего — блокер для /pm-review. "
        f"BA-001 FR-004: текст из design-spec §1: "
        f"'Расхождение нижестоящего слоя с вышестоящим без предшествующего обновления "
        f"(или без bypass-trailer) — блокер для /pm-review'"
    )


# ---------------------------------------------------------------------------
# AC-005: README.md содержит pointer на two-way sync
# ---------------------------------------------------------------------------

def test_ac005_readme_contains_two_way_sync_pointer():
    """AC-005 (BA-001): README.md содержит pointer на раздел two-way sync в CLAUDE.md."""
    content = read_file(README_MD)
    has_pointer = (
        "two-way sync" in content.lower() or
        "two-way-sync" in content.lower() or
        "two_way_sync" in content.lower() or
        "двусторонн" in content.lower()
    )
    assert has_pointer, (
        f"TODO: AC-005 — README.md должен содержать pointer на раздел two-way sync. "
        f"BA-001 FR-005: 1-2 предложения с упоминанием CLAUDE.md§two-way-sync. "
        f"Текст из design-spec §1: 'Шаблон следует правилу two-way sync: при расхождении слоёв...'"
    )


def test_ac005_readme_references_claude_md():
    """AC-005: pointer в README.md ссылается на CLAUDE.md."""
    content = read_file(README_MD)
    # Должна быть ссылка или упоминание CLAUDE.md рядом с two-way sync
    has_claude_md_ref = "CLAUDE.md" in content or "claude.md" in content.lower()
    assert has_claude_md_ref, (
        f"TODO: AC-005 — pointer в README.md должен ссылаться на CLAUDE.md. "
        f"BA-001 AC-005: с якорной ссылкой или упоминанием раздела"
    )


# ---------------------------------------------------------------------------
# AC-006: pre-SPDD проект без drift_pairs не получает ошибок — логика graceful skip
# Этот AC проверяется через test_pm_review_drift_check.py::test_ac005_*
# Здесь — проверка CLAUDE.md на формулировку backward-compat
# ---------------------------------------------------------------------------

def test_ac006_claude_md_mentions_info_skip_for_backward_compat():
    """AC-006: CLAUDE.md или его раздел two-way sync упоминает INFO-skip для pre-SPDD проектов."""
    content = read_file(CLAUDE_MD)
    # Проверяем что в CLAUDE.md есть упоминание backward-compat или INFO-skip
    # NFR-003 BA-001: «существующие проекты без drift_pairs не получают ошибок»
    has_compat = (
        "INFO" in content or
        "info-skip" in content.lower() or
        "backward" in content.lower() or
        "INFO-skip" in content
    )
    # Это мягкая проверка — backward-compat может быть задокументирован как-то иначе
    # Главная проверка AC-006 — в test_pm_review_drift_check.py
    if not has_compat:
        pytest.fail(
            "TODO: AC-006 — CLAUDE.md должен отражать backward-compat: проекты без drift_pairs "
            "получают INFO-skip, не ошибку. NFR-003 BA-001. "
            "Может быть упомянуто в разделе two-way sync или в красных линиях"
        )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
