#!/usr/bin/env python3
"""validate-content.py — валидатор структуры Gramax-каталога.

Проверяет content/ на соответствие правилам Gramax (см. CLAUDE.md / spec).
Exit codes: 0 — clean; 1 — есть errors; 2 — pyyaml не установлен или плохой путь.
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

PLACEHOLDER_RE = re.compile(r"\{\{[A-Z_]+\}\}")

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


def has_placeholder(file_path: Path) -> bool:
    """Возвращает True если frontmatter содержит литерал {{...}}."""
    text = file_path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return False
    parts = text.split("---", 2)
    if len(parts) < 3:
        return False
    return bool(PLACEHOLDER_RE.search(parts[1]))


def load_doc_root(content_dir: Path) -> dict:
    """Читает content/.doc-root.yaml. Возвращает {} если нет/невалиден.

    Если файл содержит плейсхолдеры {{...}} (актуально для свежего шаблона
    до запуска init.sh), они подменяются на безопасные строковые значения
    перед YAML-парсингом, чтобы C4/C5/C6 могли корректно работать.
    """
    path = content_dir / ".doc-root.yaml"
    if not path.exists():
        return {}
    try:
        text = path.read_text(encoding="utf-8")
        # Подставляем плейсхолдеры — иначе YAML-парсер падает на {...} как flow mapping.
        substituted = PLACEHOLDER_RE.sub(lambda m: f'"PLACEHOLDER_{m.group(0)[2:-2]}"', text)
        return yaml.safe_load(substituted) or {}
    except yaml.YAMLError:
        return {}


def check_property_names(content_dir: Path, doc_root: dict) -> list[Issue]:
    """C4: имена property в frontmatter объявлены в .doc-root.yaml."""
    declared = {p["name"] for p in doc_root.get("properties", []) if isinstance(p, dict) and "name" in p}
    issues = []
    for md_path in content_dir.rglob("*.md"):
        if md_path.name == "_index.md":
            continue
        if has_placeholder(md_path):
            continue
        fm = parse_frontmatter(md_path)
        if not fm or "properties" not in fm or not isinstance(fm["properties"], list):
            continue
        for p in fm["properties"]:
            if not isinstance(p, dict) or "name" not in p:
                continue
            name = p["name"]
            if name not in declared:
                issues.append(Issue("error", str(md_path),
                    f"property \"{name}\" не объявлен в .doc-root.yaml"))
    return issues


def check_property_values(content_dir: Path, doc_root: dict) -> list[Issue]:
    """C5: значения property из frontmatter входят в values: (для type: Enum)."""
    enums = {
        p["name"]: set(p.get("values") or [])
        for p in doc_root.get("properties", [])
        if isinstance(p, dict) and p.get("type") == "Enum" and "name" in p
    }
    issues = []
    for md_path in content_dir.rglob("*.md"):
        if md_path.name == "_index.md":
            continue
        if has_placeholder(md_path):
            continue
        fm = parse_frontmatter(md_path)
        if not fm or "properties" not in fm or not isinstance(fm["properties"], list):
            continue
        for p in fm["properties"]:
            if not isinstance(p, dict) or "name" not in p or "value" not in p:
                continue
            name = p["name"]
            if name not in enums:
                continue
            values = p["value"] if isinstance(p["value"], list) else [p["value"]]
            for v in values:
                if v not in enums[name]:
                    allowed = sorted(enums[name])
                    issues.append(Issue("error", str(md_path),
                        f"property \"{name}\" имеет значение \"{v}\", не входящее в enum {allowed}"))
    return issues


def check_filter_coverage(content_dir: Path, doc_root: dict) -> list[Issue]:
    """C6: статья объявляет хотя бы один property из filterProperties (warning)."""
    filter_names = set(doc_root.get("filterProperties") or [])
    if not filter_names:
        return []
    issues = []
    for md_path in content_dir.rglob("*.md"):
        if md_path.name == "_index.md":
            continue
        fm = parse_frontmatter(md_path)
        if not fm:
            continue
        props = fm.get("properties") or []
        if not isinstance(props, list):
            continue
        declared = {p["name"] for p in props if isinstance(p, dict) and "name" in p}
        if not (declared & filter_names):
            issues.append(Issue("warning", str(md_path),
                f"не объявляет ни одного property из filterProperties {sorted(filter_names)} — фильтр в Gramax не сработает"))
    return issues


def check_placeholders(content_dir: Path) -> list[Issue]:
    """C7: warning про плейсхолдеры в frontmatter."""
    issues = []
    for md_path in content_dir.rglob("*.md"):
        if has_placeholder(md_path):
            issues.append(Issue("warning", str(md_path),
                "frontmatter содержит плейсхолдер {{...}}; ожидается замена через init.sh"))
    return issues


def check_doc_root_placeholders(content_dir: Path) -> list[Issue]:
    """C7-doc-root: warning, если .doc-root.yaml содержит плейсхолдеры {{...}}."""
    path = content_dir / ".doc-root.yaml"
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8")
    if PLACEHOLDER_RE.search(text):
        return [Issue("warning", str(path),
            "содержит плейсхолдер {{...}}; ожидается замена через init.sh")]
    return []


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


def check_object_notation(content_dir: Path) -> list[Issue]:
    """C3: properties в статьях — список dict-ов с ключами name+value."""
    issues = []
    for md_path in content_dir.rglob("*.md"):
        if md_path.name == "_index.md":
            continue
        fm = parse_frontmatter(md_path)
        if not fm or "properties" not in fm:
            continue
        props = fm["properties"]
        if not isinstance(props, list):
            issues.append(Issue("error", str(md_path),
                "properties должен быть списком (получено: " + type(props).__name__ + ")"))
            continue
        for p in props:
            if not isinstance(p, dict):
                issues.append(Issue("error", str(md_path),
                    "элемент properties должен быть dict-ом (получено: " + type(p).__name__ + ")"))
                continue
            keys = set(p.keys())
            if keys != {"name", "value"}:
                # Если ровно один ключ — это плоская нотация.
                if len(keys) == 1:
                    issues.append(Issue("error", str(md_path),
                        f"использует плоскую frontmatter-нотацию ({list(keys)[0]}: ...); требуется object-нотация (- name: X / value: [Y])"))
                else:
                    issues.append(Issue("error", str(md_path),
                        f"элемент properties должен иметь ровно ключи name+value (получено: {sorted(keys)})"))
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
    issues.extend(check_object_notation(content_dir))
    doc_root = load_doc_root(content_dir)
    issues.extend(check_property_names(content_dir, doc_root))
    issues.extend(check_property_values(content_dir, doc_root))
    issues.extend(check_filter_coverage(content_dir, doc_root))
    issues.extend(check_placeholders(content_dir))
    issues.extend(check_doc_root_placeholders(content_dir))

    errors = [i for i in issues if i.level == "error"]
    warnings = [i for i in issues if i.level == "warning"]

    for issue in sorted(issues, key=lambda i: (i.path, i.level)):
        print(f"{issue.path}: {issue.message}  [{issue.level}]")

    md_count = sum(1 for _ in content_dir.rglob("*.md"))
    if not issues:
        print(f"{content_dir}/: OK ({md_count} файлов проверены)")

    print(f"\nErrors: {len(errors)} | Warnings: {len(warnings)}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
