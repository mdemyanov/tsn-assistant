#!/usr/bin/env python3
"""validate-profile.py — валидатор manifest'ов профилей.

Проверяет docs/overlays/profiles/*/manifest.yaml на соответствие schema (M1-M10).
Exit codes: 0 — clean; 1 — есть errors; 2 — pyyaml не установлен.
"""
from __future__ import annotations

import argparse
import re as _re
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

SUBAGENT_STATUSES = {"core", "optional", "disabled"}
PIPELINE_STATUSES = {"enabled", "optional", "disabled"}


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


def check_m3_name_matches_dir(profile_dir: Path, manifest: dict) -> list[Issue]:
    """M3: name в manifest совпадает с именем папки."""
    name = manifest.get("name")
    if name is None:
        return []  # M2 уже сообщил
    if name != profile_dir.name:
        return [Issue(
            level="error",
            path=str(profile_dir / "manifest.yaml"),
            message=f"name '{name}' не совпадает с именем папки '{profile_dir.name}'",
        )]
    return []


def collect_known_roles(repo_root: Path) -> set[str]:
    """Парсит AGENTS.md таблицу 'Каталог ролей', возвращает множество role names."""
    agents_md = repo_root / "AGENTS.md"
    if not agents_md.exists():
        return set()
    text = agents_md.read_text(encoding="utf-8")
    # Найти секцию '## Каталог ролей' и таблицу под ней
    match = _re.search(r"##\s*Каталог ролей\s*\n(.*?)(?=\n##|\Z)", text, _re.DOTALL)
    if not match:
        return set()
    table = match.group(1)
    roles = set()
    for line in table.splitlines():
        line = line.strip()
        if not line.startswith("|") or "---" in line or not line.endswith("|"):
            continue
        cells = [c.strip() for c in line.split("|")[1:-1]]
        if not cells or cells[0].lower() in ("имя", "name"):
            continue
        roles.add(cells[0])
    return roles


def check_m4_subagent_names(profile_dir: Path, manifest: dict, known_roles: set[str]) -> list[Issue]:
    """M4: имена ролей в subagents объявлены в AGENTS.md."""
    if not known_roles:
        return []  # AGENTS.md отсутствует или без таблицы — M4 пропускаем
    subagents = manifest.get("subagents") or {}
    if not isinstance(subagents, dict):
        return []
    issues = []
    for role in subagents:
        if role not in known_roles:
            issues.append(Issue(
                level="error",
                path=str(profile_dir / "manifest.yaml"),
                message=f"роль '{role}' не объявлена в AGENTS.md (Каталог ролей)",
            ))
    return issues


def collect_known_pipelines(repo_root: Path) -> set[str]:
    """Возвращает множество pipeline names из commands/pipelines/*.md."""
    pipelines_dir = repo_root / ".claude" / "plugins" / "project" / "commands" / "pipelines"
    if not pipelines_dir.is_dir():
        return set()
    return {p.stem for p in pipelines_dir.glob("*.md")}


def check_m5_pipeline_names(profile_dir: Path, manifest: dict, known_pipelines: set[str]) -> list[Issue]:
    """M5: pipelines существуют в commands/pipelines/ или явно disabled."""
    pipelines = manifest.get("pipelines") or {}
    if not isinstance(pipelines, dict):
        return []
    issues = []
    for pipe, status in pipelines.items():
        if status == "disabled":
            continue  # disabled = stub, OK без файла
        if pipe not in known_pipelines:
            issues.append(Issue(
                level="error",
                path=str(profile_dir / "manifest.yaml"),
                message=f"pipeline '{pipe}' не существует (нет commands/pipelines/{pipe}.md)",
            ))
    return issues


def check_m6_status_enums(profile_dir: Path, manifest: dict) -> list[Issue]:
    """M6: статусы subagents и pipelines — из enum'а."""
    issues = []
    manifest_path = str(profile_dir / "manifest.yaml")
    subagents = manifest.get("subagents") or {}
    if isinstance(subagents, dict):
        for role, status in subagents.items():
            if status not in SUBAGENT_STATUSES:
                issues.append(Issue(
                    level="error",
                    path=manifest_path,
                    message=f"subagents.{role} = '{status}' (ожидается одно из {sorted(SUBAGENT_STATUSES)})",
                ))
    pipelines = manifest.get("pipelines") or {}
    if isinstance(pipelines, dict):
        for pipe, status in pipelines.items():
            if status not in PIPELINE_STATUSES:
                issues.append(Issue(
                    level="error",
                    path=manifest_path,
                    message=f"pipelines.{pipe} = '{status}' (ожидается одно из {sorted(PIPELINE_STATUSES)})",
                ))
    return issues


def check_m7_paths_exist(profile_dir: Path, manifest: dict) -> list[Issue]:
    """M7: content_scaffold и doc_root paths существуют (для status != stub)."""
    if manifest.get("status") == "stub":
        return []  # для stub'ов не проверяем
    issues = []
    manifest_path = str(profile_dir / "manifest.yaml")
    for field in ["content_scaffold", "doc_root"]:
        path_str = manifest.get(field)
        if not path_str or path_str == "./":
            continue  # ./ — допустимый плейсхолдер для stub'ов
        target = profile_dir / path_str
        if not target.exists():
            issues.append(Issue(
                level="error",
                path=manifest_path,
                message=f"{field} '{path_str}' не существует (искал: {target})",
            ))
    return issues


def check_m8_on_value_targets(profile_dir: Path, manifest: dict) -> list[Issue]:
    """M8 (warning): on_value мутации указывают на существующие ключи манифеста."""
    issues = []
    manifest_path = str(profile_dir / "manifest.yaml")
    subagents = manifest.get("subagents") or {}
    pipelines = manifest.get("pipelines") or {}
    init_prompts = manifest.get("init_prompts") or []
    if not isinstance(init_prompts, list):
        return []
    for p in init_prompts:
        if not isinstance(p, dict):
            continue
        on_value = p.get("on_value") or {}
        if not isinstance(on_value, dict):
            continue
        for choice, mutations in on_value.items():
            if not isinstance(mutations, dict):
                continue
            for key in mutations:
                if "." not in key:
                    continue
                section, name = key.split(".", 1)
                if section == "subagents" and name not in subagents:
                    issues.append(Issue(
                        level="warning",
                        path=manifest_path,
                        message=f"init_prompts.{p.get('id', '?')}.on_value.{choice}: '{key}' мутирует unknown subagent '{name}'",
                    ))
                elif section == "pipelines" and name not in pipelines:
                    issues.append(Issue(
                        level="warning",
                        path=manifest_path,
                        message=f"init_prompts.{p.get('id', '?')}.on_value.{choice}: '{key}' мутирует unknown pipeline '{name}'",
                    ))
    return issues


def check_m9_compatible_stacks(profile_dir: Path, manifest: dict, repo_root: Path) -> list[Issue]:
    """M9 (warning): compatible_stacks упоминают существующие overlay'и."""
    stacks = manifest.get("compatible_stacks") or []
    if not isinstance(stacks, list):
        return []
    issues = []
    overlays_root = repo_root / "docs" / "overlays"
    manifest_path = str(profile_dir / "manifest.yaml")
    for s in stacks:
        if s == "*":
            continue
        if not (overlays_root / s).is_dir():
            issues.append(Issue(
                level="warning",
                path=manifest_path,
                message=f"compatible_stacks: '{s}' не существует ({overlays_root}/{s} не найдена)",
            ))
    return issues


def check_m10_status_mismatch(profile_dir: Path, manifest: dict) -> list[Issue]:
    """M10 (warning): status: stable + пустой content_scaffold ИЛИ status: stub + непустой."""
    status = manifest.get("status")
    scaffold = manifest.get("content_scaffold")
    if not scaffold or scaffold == "./":
        scaffold_empty = True
    else:
        target = profile_dir / scaffold
        scaffold_empty = not target.is_dir() or not any(target.iterdir())
    manifest_path = str(profile_dir / "manifest.yaml")
    if status == "stable" and scaffold_empty:
        return [Issue(
            level="warning",
            path=manifest_path,
            message=f"status: stable, но content_scaffold пустой — несоответствие",
        )]
    if status == "stub" and not scaffold_empty:
        return [Issue(
            level="warning",
            path=manifest_path,
            message=f"status: stub, но content_scaffold непустой — возможно status должен быть stable",
        )]
    return []


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

    repo_root = Path.cwd()  # запуск из корня репо
    known_roles = collect_known_roles(repo_root)
    known_pipelines = collect_known_pipelines(repo_root)

    issues: list[Issue] = []
    for pd in profile_dirs:
        m1 = check_m1_manifest_present(pd)
        issues.extend(m1)
        if m1:
            continue  # без manifest нечего проверять
        manifest = load_manifest(pd)
        issues.extend(check_m2_required_fields(pd, manifest))
        if manifest is not None:
            issues.extend(check_m3_name_matches_dir(pd, manifest))
            issues.extend(check_m4_subagent_names(pd, manifest, known_roles))
            issues.extend(check_m5_pipeline_names(pd, manifest, known_pipelines))
            issues.extend(check_m6_status_enums(pd, manifest))
            issues.extend(check_m7_paths_exist(pd, manifest))
            issues.extend(check_m8_on_value_targets(pd, manifest))
            issues.extend(check_m9_compatible_stacks(pd, manifest, repo_root))
            issues.extend(check_m10_status_mismatch(pd, manifest))

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
