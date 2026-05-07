#!/usr/bin/env python3
"""_apply_profile.py — читает profile manifest.yaml, эмиттит JSON ops plan на stdout.

Используется apply-overlay.sh в --profile режиме как one-shot helper
(вместо ×5 subprocess shells per operation в Wave 2).

CLI:
    python3 scripts/_apply_profile.py <profile-dir> [--init]

Output (stdout): JSON {"profile": str, "init": bool, "ops": [{"op": ..., ...}]}
Exit codes: 0 — clean; 1 — error (manifest invalid, mutation failure); 2 — pyyaml missing.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _validate_common import parse_yaml_file, require_yaml  # noqa: E402

# A6: named constant вместо magic 500
BASELINE_CONTENT_MAX_BYTES = 500


def load_manifest(profile_dir: Path) -> dict:
    """Читает manifest.yaml; exit 1 если parse failed или manifest отсутствует."""
    manifest_path = profile_dir / "manifest.yaml"
    if not manifest_path.exists():
        print(f"ERROR: {manifest_path} не найден", file=sys.stderr)
        sys.exit(1)
    manifest = parse_yaml_file(manifest_path)
    if manifest is None:
        print(f"ERROR: {manifest_path}: invalid YAML", file=sys.stderr)
        sys.exit(1)
    return manifest


def is_baseline_file(path: Path) -> bool:
    """Файл считается baseline если: пустой, имеет placeholder, или _index.md < BASELINE_CONTENT_MAX_BYTES.

    A6: symlinks count as content (не baseline) если не _index.md/.gitkeep.
    """
    if not path.exists():
        return True
    if path.is_symlink():
        # A6: symlink — non-baseline (избегаем follow-чужих-указателей)
        return path.name in (".gitkeep",)  # symlink на .gitkeep допустим
    if path.is_file():
        try:
            size = path.stat().st_size
        except OSError:
            return False
        if size == 0:
            return True
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            return False
        if "{{" in text:
            return True
        if path.name == "_index.md" and size < BASELINE_CONTENT_MAX_BYTES:
            return True
        return False
    return False


def is_safe_to_delete(target: Path) -> bool:
    """Папка safe to delete если содержит только baseline content (_index.md + .gitkeep)."""
    if not target.exists():
        return True  # уже нет — OK
    if target.is_file():
        return is_baseline_file(target)
    if not target.is_dir():
        return False
    for entry in target.rglob("*"):
        if entry.is_dir():
            continue
        name = entry.name
        if name == ".gitkeep":
            continue
        if name == "_index.md" and is_baseline_file(entry):
            continue
        return False
    return True


def compute_verdict(op: dict, init: bool, profile_dir: Path) -> str:
    """Возвращает verdict: 'safe', 'refuse', 'force-required', или 'add'/'replace'."""
    op_type = op.get("op")
    if op_type in ("add", "replace"):
        return op_type  # просто маркер, без safety check
    if op_type == "delete":
        target = Path(op.get("target", ""))
        if init:
            return "safe"  # init mode skip strict check (передаст --force в op_delete)
        if is_safe_to_delete(target):
            return "safe"
        return "refuse"
    return "unknown"


def emit_plan(manifest: dict, profile_dir: Path, init: bool) -> dict:
    """Формирует ops plan структуру для последующего вывода JSON."""
    ops = manifest.get("operations") or []
    plan_ops = []
    for op_decl in ops:
        if not isinstance(op_decl, dict):
            continue
        op_type = op_decl.get("op")
        if not op_type:
            # Skip malformed op entry; warn to stderr
            print(f"WARNING: skipping op without 'op' field: {op_decl}", file=sys.stderr)
            continue
        plan_ops.append({
            "op": op_type,
            "source": op_decl.get("source", ""),
            "target": op_decl.get("target", ""),
            "reason": op_decl.get("reason", ""),
            "verdict": compute_verdict(op_decl, init, profile_dir),
        })
    return {
        "profile": manifest.get("name", ""),
        "init": init,
        "ops": plan_ops,
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Profile apply helper — emits JSON ops plan")
    parser.add_argument("profile_dir", help="Path to docs/overlays/profiles/<name>/")
    parser.add_argument("--init", action="store_true", help="Fresh init mode (relax strict delete check)")
    args = parser.parse_args(argv)

    require_yaml()

    profile_dir = Path(args.profile_dir)
    if not profile_dir.is_dir():
        print(f"ERROR: profile dir не существует: {profile_dir}", file=sys.stderr)
        return 1

    manifest = load_manifest(profile_dir)
    plan = emit_plan(manifest, profile_dir, args.init)

    print(json.dumps(plan, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
