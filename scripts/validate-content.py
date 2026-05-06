#!/usr/bin/env python3
"""validate-content.py — валидатор структуры Gramax-каталога.

Проверяет content/ на соответствие правилам Gramax (см. CLAUDE.md / spec).
Exit codes: 0 — clean; 1 — есть errors; 2 — pyyaml не установлен или плохой путь.
"""
from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path

try:
    import yaml  # PyYAML
except ImportError:
    print("ERROR: PyYAML не установлен. Установи: pip install pyyaml", file=sys.stderr)
    sys.exit(2)


@dataclass
class Issue:
    level: str  # "error" | "warning"
    path: str
    message: str


def parse_frontmatter(file_path: Path) -> dict | None:
    """Извлекает YAML-frontmatter между --- из markdown-файла. Возвращает None если нет."""
    text = file_path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return None
    parts = text.split("---", 2)
    if len(parts) < 3:
        return None
    try:
        return yaml.safe_load(parts[1]) or {}
    except yaml.YAMLError:
        return None


def check_index_no_properties(content_dir: Path) -> list[Issue]:
    """C2: _index.md не должен содержать properties:."""
    issues = []
    for index_path in content_dir.rglob("_index.md"):
        fm = parse_frontmatter(index_path)
        if fm and "properties" in fm:
            issues.append(Issue(
                level="error",
                path=str(index_path),
                message="_index.md не должен иметь properties (раздел не имеет своего типа/статуса)",
            ))
    return issues


def check_indexes(content_dir: Path) -> list[Issue]:
    """C1: каждая подпапка с .md или вложенными .md содержит _index.md."""
    issues = []
    for d in [content_dir, *sorted(p for p in content_dir.rglob("*") if p.is_dir())]:
        # Пропускаем подпапки без .md (рекурсивно)
        has_md = any(d.rglob("*.md"))
        if not has_md:
            continue
        index_path = d / "_index.md"
        if not index_path.exists():
            issues.append(Issue(
                level="error",
                path=f"{d}/",
                message="missing _index.md (Gramax не покажет раздел в навигации)",
            ))
    return issues


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Validate Gramax content/ structure")
    parser.add_argument("content_dir", nargs="?", default="content",
                        help="Path to content directory (default: content)")
    args = parser.parse_args(argv)

    content_dir = Path(args.content_dir)
    if not content_dir.is_dir():
        print(f"ERROR: not a directory: {content_dir}", file=sys.stderr)
        return 2

    issues = []
    issues.extend(check_indexes(content_dir))
    issues.extend(check_index_no_properties(content_dir))

    errors = [i for i in issues if i.level == "error"]
    warnings = [i for i in issues if i.level == "warning"]

    for issue in issues:
        print(f"{issue.path}: {issue.message}  [{issue.level}]")

    print(f"\nErrors: {len(errors)} | Warnings: {len(warnings)}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
