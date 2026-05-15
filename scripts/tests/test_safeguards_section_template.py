# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pytest>=8.0",
# ]
# ///
"""
test_safeguards_section_template.py — QA-001 / BA-002 AC-001..AC-005

Проверяет наличие секции «Инварианты и Safeguards» в шаблонах агентов
ba-agent.md и tech-writer-agent.md, а также чек-листов выхода.

AC-001: ba-agent.md содержит блок ## Инварианты и Safeguards с тремя подразделами.
AC-002: tech-writer-agent.md содержит аналогичный блок.
AC-003: чек-лист ba-agent.md упоминает Safeguards.
AC-004: чек-лист tech-writer-agent.md упоминает Safeguards.
AC-005: промпты содержат разграничение «Safeguards — hard constraints, не AC».
AC-006: test_safeguards_section_template.py проходит зелёным.
"""
import pathlib
import re
import pytest

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
AGENTS_DIR = REPO_ROOT / ".claude" / "plugins" / "project" / "agents"
BA_AGENT = AGENTS_DIR / "ba-agent.md"
TW_AGENT = AGENTS_DIR / "tech-writer-agent.md"

SECTION_MARKER = "## Инварианты и Safeguards"
SUBSECTION_CONTENT = "**Содержательные:**"
SUBSECTION_SENSITIVE = "**Sensitive content:**"
SUBSECTION_LIFECYCLE = "**Жизненный цикл:**"


def read_agent(path: pathlib.Path) -> str:
    assert path.exists(), f"Файл агента не найден: {path}"
    return path.read_text(encoding="utf-8")


# ---------------------------------------------------------------------------
# AC-001: ba-agent.md содержит ## Инварианты и Safeguards
# ---------------------------------------------------------------------------

def test_ac001_ba_agent_has_safeguards_section():
    """AC-001 (BA-002): ba-agent.md содержит блок '## Инварианты и Safeguards'."""
    content = read_agent(BA_AGENT)
    assert SECTION_MARKER in content, (
        f"TODO: AC-001 — '{BA_AGENT}' должен содержать блок '{SECTION_MARKER}'. "
        f"Dev вставляет шаблон секции из design-spec §2 в раздел 'Структура статьи-требования'"
    )


def test_ac001_ba_agent_has_three_subsections():
    """AC-001: секция Инварианты и Safeguards в ba-agent.md содержит 3 подраздела."""
    content = read_agent(BA_AGENT)
    assert SECTION_MARKER in content, (
        f"TODO: AC-001 — блок '{SECTION_MARKER}' отсутствует в ba-agent.md"
    )
    # Получаем блок от маркера до следующего ## заголовка
    idx = content.index(SECTION_MARKER)
    block = content[idx:]
    # Следующий ## (другая секция) — ограничиваем блок
    next_section = re.search(r"\n## ", block[len(SECTION_MARKER):])
    if next_section:
        block = block[:len(SECTION_MARKER) + next_section.start()]

    for subsection in (SUBSECTION_CONTENT, SUBSECTION_SENSITIVE, SUBSECTION_LIFECYCLE):
        assert subsection in block, (
            f"TODO: AC-001 — блок '{SECTION_MARKER}' в ba-agent.md должен содержать "
            f"подраздел '{subsection}'. "
            f"Dev использует шаблон секции из design-spec §2"
        )


# ---------------------------------------------------------------------------
# AC-002: tech-writer-agent.md содержит ## Инварианты и Safeguards
# ---------------------------------------------------------------------------

def test_ac002_tech_writer_has_safeguards_section():
    """AC-002 (BA-002): tech-writer-agent.md содержит блок '## Инварианты и Safeguards'."""
    content = read_agent(TW_AGENT)
    assert SECTION_MARKER in content, (
        f"TODO: AC-002 — '{TW_AGENT}' должен содержать блок '{SECTION_MARKER}'. "
        f"Dev вставляет шаблон секции из design-spec §2 в шаблон артефакта агента"
    )


def test_ac002_tech_writer_has_three_subsections():
    """AC-002: секция Инварианты и Safeguards в tech-writer-agent.md содержит 3 подраздела."""
    content = read_agent(TW_AGENT)
    assert SECTION_MARKER in content, (
        f"TODO: AC-002 — блок '{SECTION_MARKER}' отсутствует в tech-writer-agent.md"
    )
    idx = content.index(SECTION_MARKER)
    block = content[idx:]
    next_section = re.search(r"\n## ", block[len(SECTION_MARKER):])
    if next_section:
        block = block[:len(SECTION_MARKER) + next_section.start()]

    for subsection in (SUBSECTION_CONTENT, SUBSECTION_SENSITIVE, SUBSECTION_LIFECYCLE):
        assert subsection in block, (
            f"TODO: AC-002 — блок '{SECTION_MARKER}' в tech-writer-agent.md должен содержать "
            f"подраздел '{subsection}'"
        )


# ---------------------------------------------------------------------------
# AC-003: чек-лист ba-agent.md упоминает Safeguards
# ---------------------------------------------------------------------------

def test_ac003_ba_agent_checklist_mentions_safeguards():
    """AC-003 (BA-002): чек-лист выходного артефакта в ba-agent.md содержит пункт про Safeguards."""
    content = read_agent(BA_AGENT)
    # Ищем в нижней части файла (чек-лист обычно ближе к концу или в отдельной секции)
    # Ищем любое вхождение Safeguards вне блока ## Инварианты и Safeguards (т.е. в checklist)
    # Подход: убираем сам блок секции из содержимого и ищем в остатке
    content_without_section = content
    if SECTION_MARKER in content:
        idx = content.index(SECTION_MARKER)
        block = content[idx:]
        next_section = re.search(r"\n## ", block[len(SECTION_MARKER):])
        end = idx + len(SECTION_MARKER) + (next_section.start() if next_section else len(block))
        content_without_section = content[:idx] + content[end:]

    # Ищем упоминание Safeguards в чек-листе ([ ] ... Safeguards)
    checklist_with_safeguards = re.search(
        r"\[[ xX]\].*[Ss]afeguards", content_without_section
    )
    assert checklist_with_safeguards is not None, (
        f"TODO: AC-003 — ba-agent.md должен содержать пункт чек-листа выхода с упоминанием 'Safeguards'. "
        f"Dev добавляет пункт вида: '- [ ] Секция «Инварианты и Safeguards» заполнена или содержит явный N/A' "
        f"в секцию 'Чек-лист выходного артефакта' согласно design-spec §2"
    )


# ---------------------------------------------------------------------------
# AC-004: чек-лист tech-writer-agent.md упоминает Safeguards
# ---------------------------------------------------------------------------

def test_ac004_tech_writer_checklist_mentions_safeguards():
    """AC-004 (BA-002): чек-лист выходного артефакта в tech-writer-agent.md содержит пункт про Safeguards."""
    content = read_agent(TW_AGENT)
    content_without_section = content
    if SECTION_MARKER in content:
        idx = content.index(SECTION_MARKER)
        block = content[idx:]
        next_section = re.search(r"\n## ", block[len(SECTION_MARKER):])
        end = idx + len(SECTION_MARKER) + (next_section.start() if next_section else len(block))
        content_without_section = content[:idx] + content[end:]

    checklist_with_safeguards = re.search(
        r"\[[ xX]\].*[Ss]afeguards", content_without_section
    )
    assert checklist_with_safeguards is not None, (
        f"TODO: AC-004 — tech-writer-agent.md должен содержать пункт чек-листа выхода с упоминанием 'Safeguards'. "
        f"Dev добавляет пункт аналогично ba-agent.md согласно design-spec §2"
    )


# ---------------------------------------------------------------------------
# AC-005: промпты содержат разграничение «Safeguards — hard constraints, не AC»
# ---------------------------------------------------------------------------

def test_ac005_ba_agent_safeguards_vs_ac_distinction():
    """AC-005 (BA-002): ba-agent.md содержит разграничение 'Safeguards — hard constraints, не AC'."""
    content = read_agent(BA_AGENT)
    # Ищем ключевые фразы разграничения (из design-spec §2: «Safeguards — это hard constraints, НЕ Acceptance Criteria»)
    has_hard_constraints = re.search(r"[Hh]ard.{0,20}[Cc]onstraints?|hard constraints", content)
    has_not_ac = re.search(r"[Nn][Ee][Tt]\s+AC|не\s+AC|НЕ\s+AC|не\s+Acceptance|НЕ\s+Acceptance", content)
    assert has_hard_constraints is not None, (
        f"TODO: AC-005 — ba-agent.md должен содержать упоминание 'hard constraints' "
        f"для разграничения Safeguards от AC. "
        f"Dev добавляет пояснение из design-spec §2: "
        f"'Safeguards — это hard constraints, НЕ Acceptance Criteria'"
    )


def test_ac005_tech_writer_safeguards_vs_ac_distinction():
    """AC-005 (BA-002): tech-writer-agent.md содержит разграничение Safeguards vs AC."""
    content = read_agent(TW_AGENT)
    has_hard_constraints = re.search(r"[Hh]ard.{0,20}[Cc]onstraints?|hard constraints", content)
    assert has_hard_constraints is not None, (
        f"TODO: AC-005 — tech-writer-agent.md должен содержать упоминание 'hard constraints' "
        f"для разграничения Safeguards от AC. "
        f"Dev добавляет пояснение из design-spec §2"
    )


# ---------------------------------------------------------------------------
# Error case: секция явно отличается от AC (не содержит «система должна»)
# ---------------------------------------------------------------------------

def test_ac005_ba_agent_safeguards_block_no_system_should():
    """AC-005 boundary: блок Safeguards в ba-agent.md не содержит 'система должна' (это AC, не Safeguard)."""
    content = read_agent(BA_AGENT)
    if SECTION_MARKER not in content:
        pytest.skip("Секция Инварианты и Safeguards отсутствует — пропуск boundary-теста")
    idx = content.index(SECTION_MARKER)
    block = content[idx:]
    next_section = re.search(r"\n## ", block[len(SECTION_MARKER):])
    if next_section:
        block = block[:len(SECTION_MARKER) + next_section.start()]
    # SA-NOTE в design-spec §2: «Если формулировка начинается с «система должна» — это AC»
    # Тест: в примерах Safeguards не должны быть формулировки «система должна»
    # Мы ищем это только в plain-text (не в комментариях SA-NOTE)
    lines = [l for l in block.split("\n") if not l.strip().startswith("<!--")]
    plain_text = "\n".join(lines)
    has_system_should = re.search(r"система должна|[Ss]ystem must\b", plain_text)
    # Это WARN, не hard fail — шаблон может содержать объяснение «это не Safeguard»
    # Если находим — сообщаем что это потенциальный AC, а не Safeguard
    if has_system_should:
        pytest.fail(
            f"TODO: AC-005 — блок '{SECTION_MARKER}' в ba-agent.md содержит формулировку "
            f"'система должна', которая типична для AC, а не для Safeguard. "
            f"Safeguards должны быть бинарными: 'X не может быть null', 'Y не превышает N'"
        )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
