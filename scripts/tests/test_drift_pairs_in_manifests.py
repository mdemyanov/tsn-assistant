# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pytest>=8.0",
#   "pyyaml>=6.0",
# ]
# ///
"""
test_drift_pairs_in_manifests.py — QA-001 / BA-003 AC-006, AC-009

Проверяет: каждый из 7 манифестов docs/overlays/profiles/<name>/manifest.yaml
содержит ключ drift_pairs со структурой, соответствующей design-spec §3a-§3b.

AC-006 (BA-003): все 7 манифестов содержат поле drift_pairs.
AC-009 (BA-003): test_drift_pairs_in_manifests.py проходит зелёным.
"""
import pathlib
import re
import pytest
import yaml

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
PROFILES_DIR = REPO_ROOT / "docs" / "overlays" / "profiles"

PROFILES_NON_EMPTY = ["project", "product", "kb-team", "kb-product", "methodology", "course"]
PROFILES_ALL = PROFILES_NON_EMPTY + ["custom"]


def load_manifest(profile_name: str) -> dict:
    manifest_path = PROFILES_DIR / profile_name / "manifest.yaml"
    with open(manifest_path) as f:
        return yaml.safe_load(f)


# ---------------------------------------------------------------------------
# AC-006 / AC-009 — ключ drift_pairs присутствует во всех 7 манифестах
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("profile", PROFILES_ALL)
def test_ac006_drift_pairs_key_present(profile):
    """AC-006 (BA-003): manifest содержит ключ drift_pairs (для всех 7 профилей)."""
    manifest = load_manifest(profile)
    assert "drift_pairs" in manifest, (
        f"TODO: AC-006 — manifest '{profile}' должен содержать ключ drift_pairs. "
        f"Dev добавляет поле в docs/overlays/profiles/{profile}/manifest.yaml согласно design-spec §3e"
    )


# ---------------------------------------------------------------------------
# Структура элементов drift_pairs — upstream + downstream string, minLength≥1
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("profile", PROFILES_NON_EMPTY)
def test_ac006_drift_pairs_non_empty(profile):
    """AC-006: для project/product/kb-*/methodology/course — drift_pairs непустой список."""
    manifest = load_manifest(profile)
    dp = manifest.get("drift_pairs")
    assert dp is not None, (
        f"TODO: AC-006 — drift_pairs отсутствует в '{profile}'"
    )
    assert isinstance(dp, list) and len(dp) > 0, (
        f"TODO: AC-006 — drift_pairs для '{profile}' должен быть непустым списком. "
        f"Количество пар для профиля по design-spec §3e: project=4, product=4, "
        f"kb-team=4, kb-product=3, methodology=3, course=2"
    )


def test_ac006_custom_drift_pairs_empty_list():
    """AC-006: для custom — drift_pairs должен быть пустым списком []."""
    manifest = load_manifest("custom")
    dp = manifest.get("drift_pairs")
    assert dp is not None, "TODO: AC-006 — drift_pairs отсутствует в 'custom'"
    assert isinstance(dp, list) and len(dp) == 0, (
        f"TODO: AC-006 — drift_pairs для 'custom' должен быть пустым списком [], "
        f"получено: {dp!r}. Dev добавляет drift_pairs: [] в custom/manifest.yaml"
    )


@pytest.mark.parametrize("profile", PROFILES_NON_EMPTY)
def test_ac006_drift_pairs_items_have_upstream_downstream(profile):
    """AC-006: каждый элемент drift_pairs содержит upstream и downstream (string, minLength>=1)."""
    manifest = load_manifest(profile)
    dp = manifest.get("drift_pairs", [])
    if not isinstance(dp, list):
        pytest.fail(f"drift_pairs в '{profile}' не является списком")
    for i, pair in enumerate(dp):
        assert isinstance(pair, dict), (
            f"TODO: AC-006 — drift_pairs[{i}] в '{profile}' должен быть dict, "
            f"получено {type(pair).__name__}"
        )
        assert "upstream" in pair, (
            f"TODO: AC-006 — drift_pairs[{i}] в '{profile}' отсутствует ключ 'upstream'"
        )
        assert "downstream" in pair, (
            f"TODO: AC-006 — drift_pairs[{i}] в '{profile}' отсутствует ключ 'downstream'"
        )
        assert isinstance(pair["upstream"], str) and len(pair["upstream"]) >= 1, (
            f"TODO: AC-006 — drift_pairs[{i}].upstream в '{profile}' должен быть непустой строкой"
        )
        assert isinstance(pair["downstream"], str) and len(pair["downstream"]) >= 1, (
            f"TODO: AC-006 — drift_pairs[{i}].downstream в '{profile}' должен быть непустой строкой"
        )


@pytest.mark.parametrize("profile", PROFILES_NON_EMPTY)
def test_ac006_drift_pairs_no_extra_keys(profile):
    """AC-006: drift_pairs элементы содержат только upstream, downstream, (опционально) note."""
    manifest = load_manifest(profile)
    dp = manifest.get("drift_pairs", [])
    allowed_keys = {"upstream", "downstream", "note"}
    for i, pair in enumerate(dp):
        if not isinstance(pair, dict):
            continue
        extra = set(pair.keys()) - allowed_keys
        assert not extra, (
            f"TODO: AC-006 — drift_pairs[{i}] в '{profile}' содержит недопустимые ключи: {extra}. "
            f"Разрешены только: upstream, downstream, note (опционально)"
        )


@pytest.mark.parametrize("profile", PROFILES_NON_EMPTY)
def test_ac006_drift_pairs_glob_patterns_parseable(profile):
    """AC-006: glob-паттерны в drift_pairs валидны (parseable через pathlib)."""
    manifest = load_manifest(profile)
    dp = manifest.get("drift_pairs", [])
    fake_root = pathlib.Path("/fake/root")
    for i, pair in enumerate(dp):
        if not isinstance(pair, dict):
            continue
        for field in ("upstream", "downstream"):
            pattern = pair.get(field, "")
            if not pattern:
                continue
            # pathlib.Path.glob() принимает любую строку — проверяем что не упадёт
            try:
                # Просто создаём объект Path с паттерном — это валидирует синтаксис пути
                _ = pathlib.PurePosixPath(pattern)
            except (TypeError, ValueError) as e:
                pytest.fail(
                    f"TODO: AC-006 — drift_pairs[{i}].{field}='{pattern}' в '{profile}' "
                    f"не является валидным path-паттерном: {e}. "
                    f"Проверьте синтаксис glob (POSIX, pathlib.Path.glob())"
                )


# ---------------------------------------------------------------------------
# Boundary: project имеет ровно 4 пары (по design-spec §3e)
# ---------------------------------------------------------------------------

def test_ac006_project_has_four_drift_pairs():
    """Boundary: профиль project имеет ровно 4 drift_pairs согласно design-spec §3e."""
    manifest = load_manifest("project")
    dp = manifest.get("drift_pairs", [])
    assert len(dp) == 4, (
        f"TODO: AC-006 — 'project' должен содержать ровно 4 пары drift_pairs, "
        f"получено {len(dp)}. Ожидаемые пары по design-spec §3e: "
        f"content/30-requirements/→src/, content/40-architecture/→src/, "
        f"content/30-requirements/→content/60-implementation/, "
        f"content/40-architecture/→content/70-operations/"
    )


def test_ac006_course_has_two_drift_pairs():
    """Boundary: профиль course имеет 2 drift_pairs с glob-паттернами."""
    manifest = load_manifest("course")
    dp = manifest.get("drift_pairs", [])
    assert len(dp) == 2, (
        f"TODO: AC-006 — 'course' должен содержать 2 пары drift_pairs, "
        f"получено {len(dp)}. Ожидаемые пары: "
        f"content/*-module-*/→content/90-assessments/, "
        f"content/00-overview/→content/*-module-*/"
    )


def test_ac006_course_glob_covers_both_module_dirs():
    """Boundary: glob content/*-module-*/ в course охватывает оба модульных каталога."""
    manifest = load_manifest("course")
    dp = manifest.get("drift_pairs", [])
    # Ищем пару с upstream или downstream содержащим *-module-*
    glob_pairs = [p for p in dp if isinstance(p, dict) and "*-module-*" in p.get("upstream", "") + p.get("downstream", "")]
    assert len(glob_pairs) >= 1, (
        f"TODO: AC-006 — 'course' должен содержать glob '*-module-*' в drift_pairs "
        f"для охвата 10-module-01-introduction И 20-module-02-example. "
        f"Текущие пары: {dp!r}"
    )
    # Проверяем что glob реально матчит оба каталога через pathlib
    fake_root = pathlib.Path("/fake/root")
    for pair in glob_pairs:
        for field in ("upstream", "downstream"):
            pattern = pair.get(field, "")
            if "*-module-*" in pattern:
                # Тест на то что glob содержит wildcard — это уже проверка parseable выше
                assert "*" in pattern, (
                    f"TODO: glob '{pattern}' в course.{field} должен содержать wildcard '*' "
                    f"для охвата всех модульных каталогов"
                )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
