#!/usr/bin/env python3
"""Shared utilities for validate-content.py and validate-profile.py."""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

PLACEHOLDER_RE = re.compile(r"\{\{[A-Z_]+\}\}")

try:
    import yaml  # PyYAML
except ImportError:
    yaml = None


def require_yaml() -> None:
    """Exit code 2 если PyYAML не установлен."""
    if yaml is None:
        print("ERROR: PyYAML не установлен. Установи: pip install pyyaml", file=sys.stderr)
        sys.exit(2)


@dataclass
class Issue:
    level: str  # "error" | "warning"
    path: str
    message: str


def parse_frontmatter(file_path: Path) -> dict | None:
    """Извлекает YAML-frontmatter между --- из markdown-файла. None если нет/невалиден."""
    require_yaml()
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


def parse_yaml_file(path: Path) -> dict | None:
    """Читает YAML-файл. Возвращает {} если файла нет; None если невалиден."""
    require_yaml()
    if not path.exists():
        return {}
    try:
        text = path.read_text(encoding="utf-8")
        # Подменяем плейсхолдеры на безопасные строки (для шаблонов до init.sh)
        substituted = PLACEHOLDER_RE.sub(lambda m: f'"PLACEHOLDER_{m.group(0)[2:-2]}"', text)
        return yaml.safe_load(substituted) or {}
    except yaml.YAMLError:
        return None


def has_placeholder(file_path: Path) -> bool:
    """True если frontmatter содержит литерал {{...}}."""
    text = file_path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return False
    parts = text.split("---", 2)
    if len(parts) < 3:
        return False
    return bool(PLACEHOLDER_RE.search(parts[1]))


def format_issues(issues: list[Issue]) -> str:
    """Форматирует список Issue для печати."""
    return "\n".join(
        f"{i.path}: {i.message}  [{i.level}]"
        for i in sorted(issues, key=lambda x: (x.path, x.level))
    )
