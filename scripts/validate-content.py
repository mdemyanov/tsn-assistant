#!/usr/bin/env python3
"""validate-content.py — валидатор структуры Gramax-каталога.

Проверяет content/ на соответствие правилам Gramax (см. CLAUDE.md / spec).
Exit codes: 0 — clean; 1 — есть errors; 2 — pyyaml не установлен или плохой путь.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    import yaml  # PyYAML
except ImportError:
    print("ERROR: PyYAML не установлен. Установи: pip install pyyaml", file=sys.stderr)
    sys.exit(2)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Validate Gramax content/ structure")
    parser.add_argument("content_dir", nargs="?", default="content",
                        help="Path to content directory (default: content)")
    args = parser.parse_args(argv)

    content_dir = Path(args.content_dir)
    if not content_dir.is_dir():
        print(f"ERROR: not a directory: {content_dir}", file=sys.stderr)
        return 2

    print(f"{content_dir}/: OK (skeleton, no checks yet)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
