#!/usr/bin/env python3
"""validate-profile.py — валидатор manifest'ов профилей.

Проверяет docs/overlays/profiles/*/manifest.yaml на соответствие schema (M1-M10).
Exit codes: 0 — clean; 1 — есть errors; 2 — pyyaml не установлен.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Добавляем scripts/ в path для импорта _validate_common
sys.path.insert(0, str(Path(__file__).parent))

from _validate_common import (  # noqa: E402
    Issue,
    parse_yaml_file,
    require_yaml,
    format_issues,
)

PROFILES_ROOT_DEFAULT = Path("docs/overlays/profiles")


def check_m1_manifest_present(profile_dir: Path) -> list[Issue]:
    """M1: профиль содержит manifest.yaml."""
    manifest_path = profile_dir / "manifest.yaml"
    if not manifest_path.exists():
        return [Issue(
            level="error",
            path=str(profile_dir) + "/",
            message="manifest.yaml not found",
        )]
    return []


REQUIRED_FIELDS = [
    "schema_version",
    "name",
    "description",
    "status",
    "subagents",
    "pipelines",
    "content_scaffold",
    "doc_root",
    "operations",
    "compatible_stacks",
]


def load_manifest(profile_dir: Path) -> dict | None:
    """Возвращает распарсенный manifest или None."""
    manifest_path = profile_dir / "manifest.yaml"
    if not manifest_path.exists():
        return None
    return parse_yaml_file(manifest_path)


def check_m2_required_fields(profile_dir: Path, manifest: dict | None) -> list[Issue]:
    """M2: обязательные поля присутствуют."""
    if manifest is None:
        return []  # M1 уже сообщил
    issues = []
    manifest_path = profile_dir / "manifest.yaml"
    for field in REQUIRED_FIELDS:
        if field not in manifest:
            issues.append(Issue(
                level="error",
                path=str(manifest_path),
                message=f"required field missing: {field}",
            ))
    return issues


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Validate profile manifests")
    parser.add_argument(
        "profile_dir",
        nargs="?",
        default=None,
        help="Path to single profile dir, or omit to validate all in docs/overlays/profiles/",
    )
    args = parser.parse_args(argv)

    require_yaml()

    if args.profile_dir:
        profile_dirs = [Path(args.profile_dir)]
    else:
        if not PROFILES_ROOT_DEFAULT.is_dir():
            print(f"ERROR: {PROFILES_ROOT_DEFAULT} не существует", file=sys.stderr)
            return 2
        profile_dirs = sorted(p for p in PROFILES_ROOT_DEFAULT.iterdir() if p.is_dir())

    if not profile_dirs:
        print(f"{PROFILES_ROOT_DEFAULT}/: OK (профилей нет — нечего валидировать)")
        return 0

    issues: list[Issue] = []
    for pd in profile_dirs:
        m1 = check_m1_manifest_present(pd)
        issues.extend(m1)
        if m1:
            continue  # без manifest нечего проверять
        manifest = load_manifest(pd)
        issues.extend(check_m2_required_fields(pd, manifest))

    if issues:
        print(format_issues(issues))
        errors = [i for i in issues if i.level == "error"]
        warnings = [i for i in issues if i.level == "warning"]
        print(f"\nErrors: {len(errors)} | Warnings: {len(warnings)}")
        return 1 if errors else 0

    print(f"Profiles: OK ({len(profile_dirs)} проверено)")
    print("\nErrors: 0 | Warnings: 0")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
