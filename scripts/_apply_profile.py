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


def emit_plan(manifest: dict, profile_dir: Path, init: bool) -> dict:
    """Формирует ops plan структуру для последующего вывода JSON."""
    ops = manifest.get("operations") or []
    plan_ops = []
    for op_decl in ops:
        if not isinstance(op_decl, dict):
            continue
        op_type = op_decl.get("op")
        plan_ops.append({
            "op": op_type,
            "source": op_decl.get("source", ""),
            "target": op_decl.get("target", ""),
            "reason": op_decl.get("reason", ""),
            "verdict": "pending",  # placeholder; T2 заполнит
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
