# Gramax Template Alignment — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Привести `project_template` к состоянию, когда сразу после `/init` каталог `content/` рендерится в Gramax корректно: `_index.md` в каждой подпапке (без `properties:`), object-нотация frontmatter в статьях, валидатор `validate-content.py` ловит регрессии, шпаргалка в CLAUDE.md фиксирует правила.

**Architecture:** Три фазы. (1) Валидатор `scripts/validate-content.py` — Python+pyyaml, 7 проверок (C1–C7), TDD через `scripts/test-validate-content.sh` с временными каталогами. (2) Миграция `content/`: 6 `README.md` → `_index.md`, корневой и 3 пустых `_index.md`, frontmatter `glossary.md` в object-нотацию, чистка `.doc-root.yaml`. (3) Интеграции: `init.sh`, `test-template.sh`, `CLAUDE.md`, `README.md`, `init.md`, `pm-review.md`, `lessons-learned.md`.

**Tech Stack:** Python 3.8+, PyYAML, Bash 4+, git. Тесты — bash-харнесс с `mktemp -d`.

**Спецификация:** [docs/superpowers/specs/2026-05-06-gramax-template-alignment-design.md](../specs/2026-05-06-gramax-template-alignment-design.md)

**Эталон production-каталога (для свериться):** `/Users/mdemyanov/Devel/naumen-ecosystem/business-requirements/`

---

## File Structure

### Создаваемые файлы

| Путь | Назначение |
|------|------------|
| `scripts/validate-content.py` | Валидатор структуры `content/`. Один Python-файл, ~250 строк. |
| `scripts/test-validate-content.sh` | Тест-харнесс для валидатора. Создаёт временные каталоги, проверяет exit code и вывод. |
| `content/_index.md` | Корневая страница Gramax-каталога с навигацией и `<view>`-дашбордом. |
| `content/00-project/_index.md` | (RENAME из README.md) |
| `content/00-project/adr/_index.md` | NEW (сейчас только `.gitkeep`) |
| `content/10-domain/_index.md` | (RENAME) |
| `content/30-requirements/_index.md` | (RENAME) |
| `content/30-requirements/functional/_index.md` | NEW |
| `content/30-requirements/non-functional/_index.md` | NEW |
| `content/40-architecture/_index.md` | (RENAME) |
| `content/60-implementation/_index.md` | (RENAME) |
| `content/70-operations/_index.md` | (RENAME) |

### Модифицируемые файлы

| Путь | Что меняем |
|------|------------|
| `content/.doc-root.yaml` | Удалить `required: true` (3 места). |
| `content/10-domain/glossary.md` | Frontmatter в object-нотацию. |
| `scripts/init.sh` | Добавить `content/_index.md` в список файлов с подстановкой плейсхолдеров. |
| `scripts/test-template.sh` | T4 — README→_index; T5 — добавить ассерт; T6 — добавить ассерт по validate; T8 — новый раздел. |
| `CLAUDE.md` | Вставить блок «Правила Gramax-каталога». |
| `README.md` | Упомянуть `validate-content.py` в полезных командах / быстром старте. |
| `.claude/plugins/project/commands/init.md` | Заменить ссылку на легаси-референс; дополнить anti-scope; добавить шаг верификации. |
| `.claude/plugins/project/commands/pm-review.md` | Добавить шаг «запусти валидатор» в проверке целостности. |
| `docs/lessons-learned.md` | Добавить запись (одна строка таблицы). |

### Удаляемые файлы

| Путь | Замена |
|------|--------|
| `content/00-project/README.md` | → `content/00-project/_index.md` |
| `content/10-domain/README.md` | → `content/10-domain/_index.md` |
| `content/30-requirements/README.md` | → `content/30-requirements/_index.md` |
| `content/40-architecture/README.md` | → `content/40-architecture/_index.md` |
| `content/60-implementation/README.md` | → `content/60-implementation/_index.md` |
| `content/70-operations/README.md` | → `content/70-operations/_index.md` |

---

## Phase 1 — Validator (TDD)

### Task 1: Скелет валидатора + тест-харнесс

**Files:**
- Create: `scripts/validate-content.py`
- Create: `scripts/test-validate-content.sh`

- [ ] **Step 1: Создать `scripts/test-validate-content.sh` с первым failing-тестом**

```bash
#!/usr/bin/env bash
# test-validate-content.sh — тесты для scripts/validate-content.py
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$REPO_ROOT/scripts/validate-content.py"

PASS=0
FAIL=0

assert() {
  local desc="$1"
  local cond="$2"
  if eval "$cond"; then
    echo "  ✓ $desc"
    PASS=$((PASS+1))
  else
    echo "  ✗ $desc"
    echo "    failed: $cond"
    FAIL=$((FAIL+1))
  fi
}

setup_tmp_content() {
  TMP="$(mktemp -d)"
  trap "rm -rf $TMP" EXIT
  mkdir -p "$TMP/content"
  cat > "$TMP/content/.doc-root.yaml" <<'YAML'
title: Test
description: Test catalog
syntax: XML
language: ru
properties:
  - name: Тип контента
    type: Enum
    values:
      - ADR
      - Требование
filterProperties: [Тип контента]
YAML
  echo "$TMP"
}

# ===== T0: --help работает =====
echo "==> T0: --help"
assert "validator --help прошёл" "python3 \"$VALIDATOR\" --help >/dev/null 2>&1"

echo ""
echo "==> Results: $PASS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
echo "✓ test-validate-content.sh PASSED"
```

Сделать исполняемым: `chmod +x scripts/test-validate-content.sh`

- [ ] **Step 2: Запустить тест — должен упасть**

```bash
bash scripts/test-validate-content.sh
```

Expected: FAIL — `scripts/validate-content.py` не существует.

- [ ] **Step 3: Создать минимальный `scripts/validate-content.py`**

```python
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
```

Сделать исполняемым: `chmod +x scripts/validate-content.py`

- [ ] **Step 4: Запустить тест — должен пройти**

```bash
bash scripts/test-validate-content.sh
```

Expected: PASS — `--help` работает.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-content.py scripts/test-validate-content.sh
git commit -m "feat(validate): скелет validate-content.py + тест-харнесс [T1]"
```

---

### Task 2: C1 — каждая подпапка имеет `_index.md`

**Files:**
- Modify: `scripts/validate-content.py`
- Modify: `scripts/test-validate-content.sh`

- [ ] **Step 1: Дописать failing-тесты для C1 в `test-validate-content.sh`**

Добавить перед строкой `==> Results`:

```bash
# ===== C1: missing _index.md =====
echo ""
echo "==> C1: подпапка без _index.md детектится"
TMP1="$(mktemp -d)"
mkdir -p "$TMP1/content/sub"
cat > "$TMP1/content/.doc-root.yaml" <<'YAML'
title: Test
properties: []
filterProperties: []
YAML
echo '---' > "$TMP1/content/sub/article.md"
echo 'order: 1' >> "$TMP1/content/sub/article.md"
echo 'title: A' >> "$TMP1/content/sub/article.md"
echo '---' >> "$TMP1/content/sub/article.md"

set +e
OUT=$(python3 "$VALIDATOR" "$TMP1/content" 2>&1)
RC=$?
set -e
assert "exit 1 при missing _index.md" "[ \"$RC\" = '1' ]"
assert "сообщение содержит missing _index.md" "echo \"$OUT\" | grep -q 'missing _index.md'"
assert "указан путь sub" "echo \"$OUT\" | grep -q 'sub'"
rm -rf "$TMP1"

echo ""
echo "==> C1: корневой _index.md обязателен"
TMP2="$(mktemp -d)"
mkdir -p "$TMP2/content"
cat > "$TMP2/content/.doc-root.yaml" <<'YAML'
title: Test
properties: []
filterProperties: []
YAML
echo '---' > "$TMP2/content/article.md"
echo 'order: 1' >> "$TMP2/content/article.md"
echo 'title: A' >> "$TMP2/content/article.md"
echo '---' >> "$TMP2/content/article.md"

set +e
OUT=$(python3 "$VALIDATOR" "$TMP2/content" 2>&1)
RC=$?
set -e
assert "exit 1 при отсутствии корневого _index.md" "[ \"$RC\" = '1' ]"
assert "ошибка про корневой _index.md" "echo \"$OUT\" | grep -q 'missing _index.md'"
rm -rf "$TMP2"

echo ""
echo "==> C1: каталог с _index.md проходит"
TMP3="$(mktemp -d)"
mkdir -p "$TMP3/content/sub"
cat > "$TMP3/content/.doc-root.yaml" <<'YAML'
title: Test
properties: []
filterProperties: []
YAML
echo '---' > "$TMP3/content/_index.md"
echo 'order: 0' >> "$TMP3/content/_index.md"
echo 'title: Root' >> "$TMP3/content/_index.md"
echo '---' >> "$TMP3/content/_index.md"
echo '---' > "$TMP3/content/sub/_index.md"
echo 'order: 1' >> "$TMP3/content/sub/_index.md"
echo 'title: Sub' >> "$TMP3/content/sub/_index.md"
echo '---' >> "$TMP3/content/sub/_index.md"

set +e
python3 "$VALIDATOR" "$TMP3/content" >/dev/null 2>&1
RC=$?
set -e
assert "exit 0 для каталога с _index.md везде" "[ \"$RC\" = '0' ]"
rm -rf "$TMP3"
```

- [ ] **Step 2: Запустить тесты — должны упасть**

```bash
bash scripts/test-validate-content.sh
```

Expected: FAIL — C1 не реализована.

- [ ] **Step 3: Реализовать C1 в `validate-content.py`**

Заменить тело `main()` (от `print(f"{content_dir}...` до `return 0`) на:

```python
    issues = []
    issues.extend(check_indexes(content_dir))

    errors = [i for i in issues if i.level == "error"]
    warnings = [i for i in issues if i.level == "warning"]

    for issue in issues:
        print(f"{issue.path}: {issue.message}  [{issue.level}]")

    print(f"\nErrors: {len(errors)} | Warnings: {len(warnings)}")
    return 1 if errors else 0
```

И добавить выше `def main`:

```python
from dataclasses import dataclass


@dataclass
class Issue:
    level: str  # "error" | "warning"
    path: str
    message: str


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
```

- [ ] **Step 4: Запустить тесты — должны пройти**

```bash
bash scripts/test-validate-content.sh
```

Expected: PASS, все ассерты C1 зелёные.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-content.py scripts/test-validate-content.sh
git commit -m "feat(validate): C1 — подпапка обязана иметь _index.md [T2]"
```

---

### Task 3: C2 — `_index.md` без блока `properties:`

**Files:**
- Modify: `scripts/validate-content.py`
- Modify: `scripts/test-validate-content.sh`

- [ ] **Step 1: Дописать failing-тест C2 в `test-validate-content.sh`**

Добавить перед `==> Results`:

```bash
# ===== C2: _index.md не должен иметь properties: =====
echo ""
echo "==> C2: _index.md с properties: даёт error"
TMP_C2="$(mktemp -d)"
mkdir -p "$TMP_C2/content"
cat > "$TMP_C2/content/.doc-root.yaml" <<'YAML'
title: Test
properties: []
filterProperties: []
YAML
cat > "$TMP_C2/content/_index.md" <<'MD'
---
order: 0
title: Root
properties:
  - name: Тип контента
    value: [ADR]
---
MD

set +e
OUT=$(python3 "$VALIDATOR" "$TMP_C2/content" 2>&1)
RC=$?
set -e
assert "C2 exit 1 при properties в _index.md" "[ \"$RC\" = '1' ]"
assert "C2 сообщение про properties в _index.md" "echo \"$OUT\" | grep -q '_index.md не должен иметь properties'"
rm -rf "$TMP_C2"
```

- [ ] **Step 2: Запустить тесты — C2-ассерты упадут**

```bash
bash scripts/test-validate-content.sh
```

Expected: FAIL на C2.

- [ ] **Step 3: Реализовать C2 в `validate-content.py`**

Добавить функцию `parse_frontmatter` и `check_index_no_properties`. Перед `def check_indexes`:

```python
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
```

В `main()` добавить вызов после `check_indexes`:

```python
    issues.extend(check_index_no_properties(content_dir))
```

- [ ] **Step 4: Запустить тесты — все зелёные**

```bash
bash scripts/test-validate-content.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-content.py scripts/test-validate-content.sh
git commit -m "feat(validate): C2 — _index.md без properties [T3]"
```

---

### Task 4: C3 — object-нотация frontmatter

**Files:**
- Modify: `scripts/validate-content.py`
- Modify: `scripts/test-validate-content.sh`

- [ ] **Step 1: Failing-тест C3**

```bash
# ===== C3: object-нотация в frontmatter статьи =====
echo ""
echo "==> C3: плоская нотация даёт error"
TMP_C3="$(mktemp -d)"
mkdir -p "$TMP_C3/content"
cat > "$TMP_C3/content/.doc-root.yaml" <<'YAML'
title: Test
properties:
  - name: Тип
    type: Enum
    values: [A, B]
filterProperties: []
YAML
cat > "$TMP_C3/content/_index.md" <<'MD'
---
order: 0
title: Root
---
MD
cat > "$TMP_C3/content/article.md" <<'MD'
---
order: 1
title: Article
properties:
  - Тип: A
---
MD

set +e
OUT=$(python3 "$VALIDATOR" "$TMP_C3/content" 2>&1)
RC=$?
set -e
assert "C3 exit 1 при плоской нотации" "[ \"$RC\" = '1' ]"
assert "C3 сообщение про плоскую нотацию" "echo \"$OUT\" | grep -qi 'плоск'"
rm -rf "$TMP_C3"

echo ""
echo "==> C3: object-нотация принимается"
TMP_C3B="$(mktemp -d)"
mkdir -p "$TMP_C3B/content"
cat > "$TMP_C3B/content/.doc-root.yaml" <<'YAML'
title: Test
properties:
  - name: Тип
    type: Enum
    values: [A, B]
filterProperties: []
YAML
cat > "$TMP_C3B/content/_index.md" <<'MD'
---
order: 0
title: Root
---
MD
cat > "$TMP_C3B/content/article.md" <<'MD'
---
order: 1
title: Article
properties:
  - name: Тип
    value: [A]
---
MD

set +e
python3 "$VALIDATOR" "$TMP_C3B/content" >/dev/null 2>&1
RC=$?
set -e
assert "C3 object-нотация exit 0" "[ \"$RC\" = '0' ]"
rm -rf "$TMP_C3B"
```

- [ ] **Step 2: Запустить — упадёт**

```bash
bash scripts/test-validate-content.sh
```

Expected: FAIL на C3.

- [ ] **Step 3: Реализовать C3**

Добавить функцию:

```python
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
```

В `main()` добавить:

```python
    issues.extend(check_object_notation(content_dir))
```

- [ ] **Step 4: Запустить — все зелёные**

```bash
bash scripts/test-validate-content.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-content.py scripts/test-validate-content.sh
git commit -m "feat(validate): C3 — object-нотация frontmatter обязательна [T4]"
```

---

### Task 5: C4 — имя property объявлено в `.doc-root.yaml`

**Files:**
- Modify: `scripts/validate-content.py`
- Modify: `scripts/test-validate-content.sh`

- [ ] **Step 1: Failing-тест C4**

```bash
# ===== C4: property из frontmatter объявлен в .doc-root.yaml =====
echo ""
echo "==> C4: незнакомый property даёт error"
TMP_C4="$(mktemp -d)"
mkdir -p "$TMP_C4/content"
cat > "$TMP_C4/content/.doc-root.yaml" <<'YAML'
title: Test
properties:
  - name: Тип
    type: Enum
    values: [A]
filterProperties: []
YAML
cat > "$TMP_C4/content/_index.md" <<'MD'
---
order: 0
title: Root
---
MD
cat > "$TMP_C4/content/article.md" <<'MD'
---
order: 1
title: A
properties:
  - name: Неизвестный
    value: [X]
---
MD

set +e
OUT=$(python3 "$VALIDATOR" "$TMP_C4/content" 2>&1)
RC=$?
set -e
assert "C4 exit 1 для незнакомого property" "[ \"$RC\" = '1' ]"
assert "C4 в сообщении упомянут \"Неизвестный\"" "echo \"$OUT\" | grep -q 'Неизвестный'"
rm -rf "$TMP_C4"
```

- [ ] **Step 2: Запустить — упадёт**

```bash
bash scripts/test-validate-content.sh
```

- [ ] **Step 3: Реализовать C4**

Добавить функцию-загрузчик `.doc-root.yaml`:

```python
def load_doc_root(content_dir: Path) -> dict:
    """Читает content/.doc-root.yaml. Возвращает {} если нет/невалиден."""
    path = content_dir / ".doc-root.yaml"
    if not path.exists():
        return {}
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError:
        return {}


def check_property_names(content_dir: Path, doc_root: dict) -> list[Issue]:
    """C4: имена property в frontmatter объявлены в .doc-root.yaml."""
    declared = {p["name"] for p in doc_root.get("properties", []) if isinstance(p, dict) and "name" in p}
    issues = []
    for md_path in content_dir.rglob("*.md"):
        if md_path.name == "_index.md":
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
```

В `main()` добавить (после `check_object_notation`):

```python
    doc_root = load_doc_root(content_dir)
    issues.extend(check_property_names(content_dir, doc_root))
```

- [ ] **Step 4: Запустить — зелёный**

```bash
bash scripts/test-validate-content.sh
```

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-content.py scripts/test-validate-content.sh
git commit -m "feat(validate): C4 — property objявлен в .doc-root.yaml [T5]"
```

---

### Task 6: C5 — значение property входит в `values:` (Enum)

**Files:**
- Modify: `scripts/validate-content.py`
- Modify: `scripts/test-validate-content.sh`

- [ ] **Step 1: Failing-тест C5**

```bash
# ===== C5: значение property входит в enum =====
echo ""
echo "==> C5: значение вне enum даёт error"
TMP_C5="$(mktemp -d)"
mkdir -p "$TMP_C5/content"
cat > "$TMP_C5/content/.doc-root.yaml" <<'YAML'
title: Test
properties:
  - name: Тип
    type: Enum
    values: [A, B]
filterProperties: []
YAML
cat > "$TMP_C5/content/_index.md" <<'MD'
---
order: 0
title: Root
---
MD
cat > "$TMP_C5/content/article.md" <<'MD'
---
order: 1
title: X
properties:
  - name: Тип
    value: [WRONG]
---
MD

set +e
OUT=$(python3 "$VALIDATOR" "$TMP_C5/content" 2>&1)
RC=$?
set -e
assert "C5 exit 1 значение вне enum" "[ \"$RC\" = '1' ]"
assert "C5 сообщение содержит WRONG" "echo \"$OUT\" | grep -q 'WRONG'"
rm -rf "$TMP_C5"
```

- [ ] **Step 2: Запустить — упадёт**

```bash
bash scripts/test-validate-content.sh
```

- [ ] **Step 3: Реализовать C5**

Добавить функцию:

```python
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
```

В `main()` добавить:

```python
    issues.extend(check_property_values(content_dir, doc_root))
```

- [ ] **Step 4: Запустить — зелёный**

```bash
bash scripts/test-validate-content.sh
```

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-content.py scripts/test-validate-content.sh
git commit -m "feat(validate): C5 — значение property входит в enum [T6]"
```

---

### Task 7: C6 — статья объявляет хотя бы один filter-property (warning)

**Files:**
- Modify: `scripts/validate-content.py`
- Modify: `scripts/test-validate-content.sh`

- [ ] **Step 1: Failing-тест C6**

```bash
# ===== C6: filterProperties покрытие (warning) =====
echo ""
echo "==> C6: статья без filter-property — warning"
TMP_C6="$(mktemp -d)"
mkdir -p "$TMP_C6/content"
cat > "$TMP_C6/content/.doc-root.yaml" <<'YAML'
title: Test
properties:
  - name: Тип
    type: Enum
    values: [A]
  - name: Статус
    type: Enum
    values: [Draft]
filterProperties: [Тип]
YAML
cat > "$TMP_C6/content/_index.md" <<'MD'
---
order: 0
title: Root
---
MD
cat > "$TMP_C6/content/article.md" <<'MD'
---
order: 1
title: X
properties:
  - name: Статус
    value: [Draft]
---
MD

set +e
OUT=$(python3 "$VALIDATOR" "$TMP_C6/content" 2>&1)
RC=$?
set -e
assert "C6 warning не валит exit code" "[ \"$RC\" = '0' ]"
assert "C6 сообщение содержит warning + filterProperties" "echo \"$OUT\" | grep -q 'warning' && echo \"$OUT\" | grep -qi 'filter'"
rm -rf "$TMP_C6"
```

- [ ] **Step 2: Запустить — упадёт**

```bash
bash scripts/test-validate-content.sh
```

- [ ] **Step 3: Реализовать C6**

Добавить функцию:

```python
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
```

В `main()` добавить:

```python
    issues.extend(check_filter_coverage(content_dir, doc_root))
```

- [ ] **Step 4: Запустить — зелёный**

```bash
bash scripts/test-validate-content.sh
```

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-content.py scripts/test-validate-content.sh
git commit -m "feat(validate): C6 — filterProperties coverage warning [T7]"
```

---

### Task 8: C7 — placeholder skip

**Files:**
- Modify: `scripts/validate-content.py`
- Modify: `scripts/test-validate-content.sh`

- [ ] **Step 1: Failing-тест C7**

```bash
# ===== C7: плейсхолдеры {{...}} в frontmatter — warning, не error =====
echo ""
echo "==> C7: {{PROJECT_NAME}} в _index.md — только warning"
TMP_C7="$(mktemp -d)"
mkdir -p "$TMP_C7/content"
cat > "$TMP_C7/content/.doc-root.yaml" <<'YAML'
title: Test
properties:
  - name: Тип
    type: Enum
    values: [A]
filterProperties: []
YAML
cat > "$TMP_C7/content/_index.md" <<'MD'
---
order: 0
title: {{PROJECT_NAME}}
---
MD

set +e
OUT=$(python3 "$VALIDATOR" "$TMP_C7/content" 2>&1)
RC=$?
set -e
assert "C7 exit 0 при плейсхолдере" "[ \"$RC\" = '0' ]"
assert "C7 warning про плейсхолдер" "echo \"$OUT\" | grep -q 'warning' && echo \"$OUT\" | grep -q '{{'"
rm -rf "$TMP_C7"

echo ""
echo "==> C7: статья с плейсхолдером — C4/C5 не срабатывают"
TMP_C7B="$(mktemp -d)"
mkdir -p "$TMP_C7B/content"
cat > "$TMP_C7B/content/.doc-root.yaml" <<'YAML'
title: Test
properties:
  - name: Тип
    type: Enum
    values: [A]
filterProperties: []
YAML
cat > "$TMP_C7B/content/_index.md" <<'MD'
---
order: 0
title: Root
---
MD
cat > "$TMP_C7B/content/article.md" <<'MD'
---
order: 1
title: {{TITLE}}
properties:
  - name: Тип
    value: [A]
---
MD

set +e
python3 "$VALIDATOR" "$TMP_C7B/content" >/dev/null 2>&1
RC=$?
set -e
assert "C7 статья с {{TITLE}} — exit 0" "[ \"$RC\" = '0' ]"
rm -rf "$TMP_C7B"
```

- [ ] **Step 2: Запустить — упадёт**

```bash
bash scripts/test-validate-content.sh
```

- [ ] **Step 3: Реализовать C7**

Добавить функцию-детектор и обновить C4/C5 чтобы пропускать файлы-плейсхолдеры.

В начало файла, после импортов, добавить:

```python
import re

PLACEHOLDER_RE = re.compile(r"\{\{[A-Z_]+\}\}")
```

Добавить функцию:

```python
def has_placeholder(file_path: Path) -> bool:
    """Возвращает True если frontmatter содержит литерал {{...}}."""
    text = file_path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return False
    parts = text.split("---", 2)
    if len(parts) < 3:
        return False
    return bool(PLACEHOLDER_RE.search(parts[1]))


def check_placeholders(content_dir: Path) -> list[Issue]:
    """C7: warning про плейсхолдеры в frontmatter."""
    issues = []
    for md_path in content_dir.rglob("*.md"):
        if has_placeholder(md_path):
            issues.append(Issue("warning", str(md_path),
                "frontmatter содержит плейсхолдер {{...}}; ожидается замена через init.sh"))
    return issues
```

Обновить `check_property_names` и `check_property_values` — добавить skip для плейсхолдер-файлов в начале цикла:

```python
        if has_placeholder(md_path):
            continue
```

В `main()` добавить:

```python
    issues.extend(check_placeholders(content_dir))
```

- [ ] **Step 4: Запустить — все 6 проверок зелёные**

```bash
bash scripts/test-validate-content.sh
```

Expected: PASS на всех C1-C7.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-content.py scripts/test-validate-content.sh
git commit -m "feat(validate): C7 — пропуск файлов с плейсхолдерами [T8]"
```

---

### Task 9: Sanity-вывод и финальная полировка

**Files:**
- Modify: `scripts/validate-content.py`

- [ ] **Step 1: Доработать вывод**

В `main()` заменить блок печати issues на следующий — чтобы при отсутствии issues была явная "OK" строка:

```python
    for issue in sorted(issues, key=lambda i: (i.path, i.level)):
        print(f"{issue.path}: {issue.message}  [{issue.level}]")

    md_count = sum(1 for _ in content_dir.rglob("*.md"))
    if not issues:
        print(f"{content_dir}/: OK ({md_count} файлов проверены)")

    print(f"\nErrors: {len(errors)} | Warnings: {len(warnings)}")
    return 1 if errors else 0
```

- [ ] **Step 2: Запустить тесты — зелёный**

```bash
bash scripts/test-validate-content.sh
```

- [ ] **Step 3: Прогнать валидатор на текущем шаблоне (sanity, должны быть errors — content/ ещё на README)**

```bash
python3 scripts/validate-content.py
```

Expected: exit 1, errors про missing _index.md в подпапках. Это ожидаемо до Phase 2 — фиксируем как baseline.

- [ ] **Step 4: Commit**

```bash
git add scripts/validate-content.py
git commit -m "feat(validate): финальная полировка вывода [T9]"
```

---

## Phase 2 — Content migration

### Task 10: Переименовать 6 README.md → _index.md (с обновлённым frontmatter)

**Files:**
- Delete: `content/00-project/README.md`, `content/10-domain/README.md`, `content/30-requirements/README.md`, `content/40-architecture/README.md`, `content/60-implementation/README.md`, `content/70-operations/README.md`
- Create: соответствующие `_index.md` (6 шт.)

- [ ] **Step 1: Создать новые `_index.md` с frontmatter (`order` + `title`, БЕЗ properties)**

```bash
git mv content/00-project/README.md content/00-project/_index.md
git mv content/10-domain/README.md content/10-domain/_index.md
git mv content/30-requirements/README.md content/30-requirements/_index.md
git mv content/40-architecture/README.md content/40-architecture/_index.md
git mv content/60-implementation/README.md content/60-implementation/_index.md
git mv content/70-operations/README.md content/70-operations/_index.md
```

- [ ] **Step 2: Обновить frontmatter в каждом `_index.md`**

В `content/00-project/_index.md` заменить `# 00-project — Проектные артефакты` на:

```markdown
---
order: 10
title: Проект и ADR
---

# Проектные артефакты

Цели проекта, ADR (Architecture Decision Records), roadmap, stakeholders.

## Структура

- `adr/` — Architecture Decision Records (нумерация: `001-<slug>.md`, `002-<slug>.md`, ...)
- `roadmap.md` — фазы и milestone'ы (создаётся PM)
- `stakeholders.md` — карта стейкхолдеров (создаётся PM)
- `risks.md` — реестр рисков (создаётся PM, опционально)

## Правила

- Новый ADR создаёт SA через `/sa adr <решение>`.
- Принятые ADR не редактируются. При смене решения — новый ADR со ссылкой на superseded.
```

В `content/10-domain/_index.md`:

```markdown
---
order: 20
title: Доменная модель
---

# Доменная модель

Ubiquitous Language проекта и материалы по домену: глоссарий, исследования, контекст-карта.

## Структура

- `glossary.md` — Ubiquitous Language (термины, используемые в требованиях, архитектуре и коде)
- `research/` — выжимки Researcher'а (создаётся при первом запуске `/research`)
- `context-map.md` — контекст-карта BC (опционально, при необходимости)
- `domain-events.md` — каталог доменных событий (опционально)

## Правила

- Новый термин — через BA при формировании требования (`/ba glossary-add <term>`).
- Research-выжимки — через `/research`, артефакты в `research/<slug>.md`.
- Контекст-карта и domain-events — создаются SA при стратегическом DDD.
```

В `content/30-requirements/_index.md`:

```markdown
---
order: 30
title: Требования
---

# Требования

Функциональные и нефункциональные требования с JTBD и Acceptance Criteria.

- [Функциональные](functional/)
- [Нефункциональные](non-functional/)

## Правила

- Создаёт BA через `/ba new-requirement <slug>`.
- Каждое требование содержит JTBD и Acceptance Criteria.
- Properties статей: `Тип контента=Требование`, `Фаза`, `Статус` (см. `.doc-root.yaml`).
```

В `content/40-architecture/_index.md`:

```markdown
---
order: 40
title: Архитектура
---

# Архитектура

Дизайн компонентов, модели данных, интеграционные точки, dataflow.

## Правила

- Создаёт SA через `/sa design <фича>`.
- Значимые архитектурные решения — оформляются как ADR в `content/00-project/adr/` (через `/sa adr`).
- Mermaid-диаграммы — в отдельных `.mermaid` файлах.
```

В `content/60-implementation/_index.md`:

```markdown
---
order: 60
title: Реализация
---

# Заметки реализации

Особенности реализации, edge case'ы, нетривиальные технические решения.

## Правила

- Создаёт Dev через `/dev implement` (по необходимости — не каждая задача требует записи).
- Цель: зафиксировать то, что не очевидно из кода и не покрывается архитектурными артефактами.
```

В `content/70-operations/_index.md`:

```markdown
---
order: 70
title: Эксплуатация
---

# Эксплуатация

Runbook'и, схемы инфры, процедуры мониторинга и rollback'а.

## Правила

- Создаёт DevOps через `/devops runbook <процедура>`.
- Каждый runbook содержит шаги, проверку здоровья, шаг rollback, мониторинг.
- Properties статей: `Тип контента=Runbook`, `Фаза`, `Статус`.
```

- [ ] **Step 3: Запустить валидатор — должен пройти C1, C2 (для существующих _index.md)**

```bash
python3 scripts/validate-content.py
```

Expected: errors остаются (про `30-requirements/functional/`, `30-requirements/non-functional/`, `00-project/adr/` — их `_index.md` ещё не создан, и про корневой `_index.md`).

- [ ] **Step 4: Commit**

```bash
git add content/
git commit -m "refactor(content): README.md → _index.md в 6 подпапках, frontmatter без properties [T10]"
```

---

### Task 11: Создать `_index.md` в 3 пустых подпапках

**Files:**
- Create: `content/00-project/adr/_index.md`
- Create: `content/30-requirements/functional/_index.md`
- Create: `content/30-requirements/non-functional/_index.md`

- [ ] **Step 1: Написать каждый `_index.md`**

`content/00-project/adr/_index.md`:

```markdown
---
order: 1
title: Architecture Decision Records
---

# Architecture Decision Records

Запись принятых архитектурных решений: контекст, варианты, выбранный вариант, последствия.

## Структура

- `001-<slug>.md`, `002-<slug>.md`, ... — порядковая нумерация.
- Принятые ADR не редактируются. При смене решения — новый ADR со ссылкой на superseded.

(пусто — ADR добавляются по мере роста проекта)
```

`content/30-requirements/functional/_index.md`:

```markdown
---
order: 1
title: Функциональные требования
---

# Функциональные требования

Что система должна делать. JTBD + Acceptance Criteria.

(пусто — требования добавляются BA через `/ba new-requirement <slug>`)
```

`content/30-requirements/non-functional/_index.md`:

```markdown
---
order: 2
title: Нефункциональные требования
---

# Нефункциональные требования

Производительность, безопасность, доступность, scalability.

(пусто — требования добавляются BA через `/ba new-requirement <slug>`)
```

- [ ] **Step 2: Запустить валидатор**

```bash
python3 scripts/validate-content.py
```

Expected: error остался только про корневой `content/_index.md`.

- [ ] **Step 3: Commit**

```bash
git add content/00-project/adr/_index.md content/30-requirements/functional/_index.md content/30-requirements/non-functional/_index.md
git commit -m "feat(content): _index.md в 3 пустых подпапках (adr, functional, non-functional) [T11]"
```

---

### Task 12: Создать корневой `content/_index.md`

**Files:**
- Create: `content/_index.md`

- [ ] **Step 1: Создать корневой `_index.md`**

`content/_index.md`:

```markdown
---
order: 0
title: {{PROJECT_NAME}} — База знаний
---

{{PROJECT_DESCRIPTION}}

## Навигация

- [Проект и ADR](00-project/)
- [Доменная модель](10-domain/)
- [Требования](30-requirements/)
- [Архитектура](40-architecture/)
- [Реализация](60-implementation/)
- [Эксплуатация](70-operations/)

## Дашборд

<view defs="Тип контента=Требование&Архитектура&ADR&Runbook&Исследование&Глоссарий&Прочее" groupby="Статус" display="List"/>
```

- [ ] **Step 2: Запустить валидатор**

```bash
python3 scripts/validate-content.py
```

Expected: errors про `glossary.md` (плоская нотация — C3) + warnings про плейсхолдеры в `_index.md` и frontmatter glossary, но не error на missing `_index.md`.

- [ ] **Step 3: Commit**

```bash
git add content/_index.md
git commit -m "feat(content): корневой _index.md с навигацией и view-дашбордом [T12]"
```

---

### Task 13: Перевести `glossary.md` в object-нотацию

**Files:**
- Modify: `content/10-domain/glossary.md`

- [ ] **Step 1: Заменить frontmatter в `glossary.md`**

Текущий блок:

```yaml
---
title: Глоссарий
properties:
  Тип контента: Глоссарий
  Фаза: MVP
  Статус: Draft
---
```

Заменить на:

```yaml
---
order: 1
title: Глоссарий
properties:
  - name: Тип контента
    value: [Глоссарий]
  - name: Фаза
    value: [MVP]
  - name: Статус
    value: [Draft]
---
```

- [ ] **Step 2: Запустить валидатор**

```bash
python3 scripts/validate-content.py
```

Expected: ноль errors. Warnings ожидаются только про плейсхолдеры в корневом `_index.md`.

- [ ] **Step 3: Commit**

```bash
git add content/10-domain/glossary.md
git commit -m "fix(glossary): frontmatter в object-нотацию [T13]"
```

---

### Task 14: Удалить `required: true` из `.doc-root.yaml`

**Files:**
- Modify: `content/.doc-root.yaml`

- [ ] **Step 1: Удалить три строки `required: true`**

В `content/.doc-root.yaml` удалить строки 15, 29, 40 (`    required: true`). Все остальное оставить как есть.

После правки property-определения должны выглядеть так (пример — «Тип контента»):

```yaml
  - name: Тип контента
    type: Enum
    style: blue
    icon: file-text
    values:
      - Требование
      - Архитектура
      ...
```

(без `required: true`)

- [ ] **Step 2: Запустить валидатор**

```bash
python3 scripts/validate-content.py
```

Expected: всё ещё 0 errors.

- [ ] **Step 3: Commit**

```bash
git add content/.doc-root.yaml
git commit -m "refactor(.doc-root): убрать required:true из property-определений [T14]"
```

---

## Phase 3 — Integrations

### Task 15: `init.sh` — подставлять плейсхолдеры в `content/_index.md`

**Files:**
- Modify: `scripts/init.sh`

- [ ] **Step 1: Добавить `content/_index.md` в цикл подстановки**

В `scripts/init.sh` строка 93 — заменить:

```bash
for f in CLAUDE.md AGENTS.md README.md content/.doc-root.yaml; do
```

на:

```bash
for f in CLAUDE.md AGENTS.md README.md content/.doc-root.yaml content/_index.md; do
```

- [ ] **Step 2: Прогнать `test-template.sh`**

```bash
bash scripts/test-template.sh
```

Expected: T5 пройдёт; **T4 упадёт** (всё ещё ищет README.md). Это ожидаемо — в Task 16 переключим.

- [ ] **Step 3: Commit**

```bash
git add scripts/init.sh
git commit -m "feat(init): подставлять плейсхолдеры в content/_index.md [T15]"
```

---

### Task 16: `test-template.sh` — T4 mod, T5/T6 ассерты, T8 новый

**Files:**
- Modify: `scripts/test-template.sh`

- [ ] **Step 1: Заменить блок T4 (строки 64-73)**

Заменить:

```bash
# ===== T4: content scaffold =====
echo ""
echo "==> T4: content scaffold present"
assert ".doc-root.yaml exists" "[ -f content/.doc-root.yaml ]"
assert "00-project README" "[ -f content/00-project/README.md ]"
assert "10-domain README" "[ -f content/10-domain/README.md ]"
assert "30-requirements README" "[ -f content/30-requirements/README.md ]"
assert "40-architecture README" "[ -f content/40-architecture/README.md ]"
assert "60-implementation README" "[ -f content/60-implementation/README.md ]"
assert "70-operations README" "[ -f content/70-operations/README.md ]"
assert "glossary.md exists" "[ -f content/10-domain/glossary.md ]"
```

на:

```bash
# ===== T4: content scaffold =====
echo ""
echo "==> T4: content scaffold present (_index.md везде)"
assert ".doc-root.yaml exists" "[ -f content/.doc-root.yaml ]"
assert "root _index.md" "[ -f content/_index.md ]"
assert "00-project _index.md" "[ -f content/00-project/_index.md ]"
assert "00-project/adr _index.md" "[ -f content/00-project/adr/_index.md ]"
assert "10-domain _index.md" "[ -f content/10-domain/_index.md ]"
assert "30-requirements _index.md" "[ -f content/30-requirements/_index.md ]"
assert "30-requirements/functional _index.md" "[ -f content/30-requirements/functional/_index.md ]"
assert "30-requirements/non-functional _index.md" "[ -f content/30-requirements/non-functional/_index.md ]"
assert "40-architecture _index.md" "[ -f content/40-architecture/_index.md ]"
assert "60-implementation _index.md" "[ -f content/60-implementation/_index.md ]"
assert "70-operations _index.md" "[ -f content/70-operations/_index.md ]"
assert "glossary.md exists" "[ -f content/10-domain/glossary.md ]"
assert "no README.md left in content/" "! find content -name README.md | grep -q ."
```

- [ ] **Step 2: Дополнить блок T5 — ассерт по `content/_index.md`**

После строки `assert "PROJECT_NAME replaced in CLAUDE.md" ...`, добавить:

```bash
assert "PROJECT_NAME replaced in content/_index.md" "! grep -q '{{PROJECT_NAME}}' content/_index.md"
```

- [ ] **Step 3: Дополнить блок T6 — ассерт после apply-overlay**

После строки `bash scripts/apply-overlay.sh naumen-smp >/dev/null` (первого вызова), добавить:

```bash
assert "validate-content.py зелёный после overlay apply" "python3 scripts/validate-content.py >/dev/null 2>&1"
```

- [ ] **Step 4: Добавить блок T8 — запуск валидатора на инициализированном шаблоне**

Перед `# ===== T7: full init ...` добавить:

```bash
# ===== T8: validate-content.py зелёный после init =====
echo ""
echo "==> T8: validate-content.py PASSes after init"
assert "validate-content.py exit 0 after init" "python3 scripts/validate-content.py >/dev/null 2>&1"
```

- [ ] **Step 5: Прогнать `test-template.sh`**

```bash
bash scripts/test-template.sh
```

Expected: **все T1-T8 зелёные**.

- [ ] **Step 6: Commit**

```bash
git add scripts/test-template.sh
git commit -m "test(template): T4 на _index.md; T5/T6/T8 ассерты валидатора [T16]"
```

---

### Task 17: CLAUDE.md — блок «Правила Gramax-каталога»

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Вставить блок после секции «Структура плагинной системы»**

Вставить новый раздел сразу после секции `## Структура плагинной системы` (перед `## Поток работы`). Содержание:

```markdown
## Правила Gramax-каталога (`content/`)

- **`_index.md` в каждой подпапке** (где есть `.md` файлы или вложенные подкаталоги). Без него Gramax не показывает раздел в навигации.
- **`_index.md` НЕ содержит блок `properties:`** — раздел не имеет своего типа/статуса; properties живут на статьях.
- **Корневой `content/_index.md`** разрешён и используется как главная страница каталога (навигация + дашборд `<view>`).
- **Frontmatter статьи — object-нотация:**
  ```yaml
  properties:
    - name: Тип контента
      value: [ADR]
  ```
  Плоская нотация (`- Тип контента: ADR`) — устарела, рендерится непредсказуемо.
- **Cross-каталожные ссылки** (между разными `.doc-root.yaml`) — только inline code (`` `other-catalog/path.md` ``), не markdown link.
- **Эталон production-каталога:** `/Users/mdemyanov/Devel/naumen-ecosystem/business-requirements/`.
- **Валидация:** `python3 scripts/validate-content.py` — обязательно зелёный перед merge `private→public`.
```

- [ ] **Step 2: Verify — `grep` находит ключевые фразы**

```bash
grep -q "Правила Gramax-каталога" CLAUDE.md && echo OK
grep -q "validate-content.py" CLAUDE.md && echo OK
```

Expected: два OK.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude): добавить блок «Правила Gramax-каталога» [T17]"
```

---

### Task 18: README.md — упомянуть валидатор

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Прочитать текущую структуру README**

```bash
grep -n '^##' README.md
```

- [ ] **Step 2: Найти раздел «Быстрый старт» / «Полезные команды» и добавить пункт**

В подходящий раздел (вероятно `## Быстрый старт` или `## Команды`) добавить пункт списка:

```markdown
- `python3 scripts/validate-content.py` — валидация структуры `content/` под Gramax (запускается также `pm-review` и `test-template.sh`)
```

Если подходящего раздела нет — добавить в конец README:

```markdown
## Валидация

Структуру каталога `content/` проверяет валидатор:

```bash
python3 scripts/validate-content.py
```

Требует `pyyaml` (`pip install pyyaml`). Запускается автоматически в `bash scripts/test-template.sh` и в slash-команде `/pm-review`.
```

- [ ] **Step 3: Verify**

```bash
grep -q "validate-content.py" README.md && echo OK
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs(readme): упомянуть scripts/validate-content.py [T18]"
```

---

### Task 19: `init.md` — заменить легаси-референс, дополнить anti-scope/верификацию

**Files:**
- Modify: `.claude/plugins/project/commands/init.md`

- [ ] **Step 1: Заменить ссылку на легаси-референс (строка ~91)**

Старая строка:

```markdown
Референс по адаптации: `/Users/mdemyanov/knowlage/sd-ai-assistant/content/.doc-root.yaml`.
```

Заменить на:

```markdown
Референс по адаптации (production-эталон): `/Users/mdemyanov/Devel/naumen-ecosystem/business-requirements/.doc-root.yaml`. Старый каталог `sd-ai-assistant` — НЕ использовать как референс схемы (легаси, плоская frontmatter-нотация).
```

- [ ] **Step 2: Дополнить раздел «Anti-scope»**

В список Anti-scope добавить:

```markdown
- НЕ создавать `README.md` в `content/` — Gramax индексирует только `_index.md`.
```

- [ ] **Step 3: Дополнить «Фаза 1, шаг 3 (Верификация)»**

В блоке `3. **Верифицируй:**` добавить пункт:

```markdown
   - `python3 scripts/validate-content.py` — exit 0 (warnings допустимы; errors — блокер).
```

- [ ] **Step 4: Verify**

```bash
grep -q "naumen-ecosystem/business-requirements" .claude/plugins/project/commands/init.md && echo OK1
grep -q "validate-content.py" .claude/plugins/project/commands/init.md && echo OK2
grep -q "Gramax индексирует только" .claude/plugins/project/commands/init.md && echo OK3
```

Expected: три OK.

- [ ] **Step 5: Commit**

```bash
git add .claude/plugins/project/commands/init.md
git commit -m "docs(init-cmd): референс на naumen-ecosystem; anti-scope про _index.md; верификация валидатором [T19]"
```

---

### Task 20: `pm-review.md` — добавить шаг запуска валидатора

**Files:**
- Modify: `.claude/plugins/project/commands/pm-review.md`

- [ ] **Step 1: Дополнить пункт 3 «Целостность `content/`»**

Текущий блок:

```markdown
3. **Целостность `content/`:**
   - Все статьи в `content/` имеют обязательные properties (см. `content/.doc-root.yaml`)
   - В новых ADR (`content/00-project/adr/`) — все ссылки на предшественников ведут на наполненные статьи (не болванки <100 байт)
   - В новых требованиях (`content/30-requirements/`) — есть JTBD и Acceptance Criteria
```

Заменить на:

```markdown
3. **Целостность `content/`:**
   - **Запусти валидатор:** `python3 scripts/validate-content.py`. Любой error — блокер merge. Warnings обозначь в отчёте.
   - Все статьи в `content/` имеют обязательные properties (см. `content/.doc-root.yaml`).
   - В новых ADR (`content/00-project/adr/`) — все ссылки на предшественников ведут на наполненные статьи (не болванки <100 байт).
   - В новых требованиях (`content/30-requirements/`) — есть JTBD и Acceptance Criteria.
```

- [ ] **Step 2: Verify**

```bash
grep -q "validate-content.py" .claude/plugins/project/commands/pm-review.md && echo OK
```

- [ ] **Step 3: Commit**

```bash
git add .claude/plugins/project/commands/pm-review.md
git commit -m "docs(pm-review): добавить шаг запуска валидатора [T20]"
```

---

### Task 21: `lessons-learned.md` — запись об итерации

**Files:**
- Modify: `docs/lessons-learned.md`

- [ ] **Step 1: Прочитать текущий формат**

```bash
cat docs/lessons-learned.md
```

- [ ] **Step 2: Добавить строку**

В конец файла (или в нужную секцию таблицы) дописать:

```markdown
| 2026-05-06 | PM | Шаблон / Gramax-структура | `README.md` в подпапках `content/` Gramax не индексирует (раздел невидим в навигации); плоская frontmatter-нотация рендерится непредсказуемо | Перевели всё на `_index.md` (без `properties:`), добавили `scripts/validate-content.py` (7 проверок) и шпаргалку в CLAUDE.md. Источник — `pg_vector_service/docs/gramax-skills-update.md`. |
```

Если в файле нет таблицы — создать в формате spec'а с заголовками `| Дата | Агент | Контекст | Наблюдение | Действие |`.

- [ ] **Step 3: Commit**

```bash
git add docs/lessons-learned.md
git commit -m "docs(lessons): запись об итерации gramax-template-alignment [T21]"
```

---

## Phase 4 — Final verification

### Task 22: Полный smoke-прогон + финальный коммит

**Files:**
- (no edits expected)

- [ ] **Step 1: Прогнать оба теста**

```bash
bash scripts/test-validate-content.sh
bash scripts/test-template.sh
```

Expected: оба зелёные.

- [ ] **Step 2: Прогнать валидатор на текущем шаблоне**

```bash
python3 scripts/validate-content.py
```

Expected: exit 0; warnings про плейсхолдеры в `content/_index.md` (нормально — это шаблон); errors нет.

- [ ] **Step 3: Запустить `init.sh` на временной копии и убедиться, что после init валидатор зелёный без warning'ов**

```bash
TMP="$(mktemp -d)"
rsync -a --exclude='.git' --exclude='.worktrees' . "$TMP/"
cd "$TMP"
git init -q -b main
git -c user.email=t@x -c user.name=t commit --allow-empty -q -m baseline
bash scripts/init.sh "Smoke" "SMOKE" "Smoke catalog" "smoke@example.com"
python3 scripts/validate-content.py
cd -
rm -rf "$TMP"
```

Expected: `Errors: 0 | Warnings: 0` и `OK (... файлов проверены)`.

- [ ] **Step 4: Если все зелёные — финальный коммит-тэг (опционально)**

Никакие правки не нужны — все коммиты атомарные. Можно поставить тэг:

```bash
git tag gramax-alignment-2026-05-06
```

(тэг опционален, спросить пользователя надо ли)

---

## Self-Review

### Spec coverage

| Раздел spec'а | Tasks |
|---------------|-------|
| 1. _index.md файлы (1.1, 1.2, 1.3) | T10, T11, T12 |
| 2. glossary.md frontmatter | T13 |
| 3. .doc-root.yaml — убрать required | T14 |
| 4. Валидатор (CLI, exit codes, формат, проверки C1-C7) | T1-T9 |
| 5. init.sh | T15 |
| 6. test-template.sh (T4 mod, T5/T6/T8) | T16 |
| 7. CLAUDE.md cheatsheet | T17 |
| 8. README.md | T18 |
| 9. init.md (легаси-референс, anti-scope, верификация) | T19 |
| 10. pm-review.md | T20 |
| 11. lessons-learned.md | T21 |
| GO-критерии (12 чекбоксов) | T22 (smoke) |

Все требования покрыты, gap нет.

### Placeholder scan

Прошёлся по всему плану — нет TBD, TODO, «add appropriate error handling», «similar to Task N». Все код-блоки содержат полный код. Все `assert`-ы и `grep`-ы — конкретные.

### Type / signature consistency

- `Issue(level, path, message)` — везде используется одинаково (T2-T9).
- `parse_frontmatter(file_path) -> dict | None` — введена в T3, используется в T3-T8.
- `load_doc_root(content_dir) -> dict` — введена в T5, используется в T5-T7.
- `has_placeholder(file_path) -> bool` — введена в T8, используется в T8.
- `check_*` функции — единый паттерн `(content_dir, [doc_root]) -> list[Issue]`.

Всё консистентно.

### Сценарий отката

Если на этапе T16 (полный test-template.sh) что-то ломается — откатить можно по коммитам (каждый коммит атомарный). Поскольку plan коммитит после каждой задачи, никаких больших rollback'ов не требуется.
