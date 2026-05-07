# Troubleshooting — project_template

FAQ-стиль guide частых проблем и решений.

## apply-overlay.sh

### `apply-overlay.sh` отказывается удалять `content/<dir>/`

**Симптом:**
```
[DELETE] content/30-requirements/  (...)
  ⚠ REFUSED: content/30-requirements/ содержит non-baseline content
    Use --force to override; use --dry-run to preview
```

**Причина:** target содержит файлы с реальным контентом (не плейсхолдеры/baseline `.gitkeep`).

**Решение:**
1. **Preview:** `bash scripts/apply-overlay.sh --profile --dry-run <name>` — посмотреть что было бы удалено.
2. **Принудительно:** `bash scripts/apply-overlay.sh --profile --force <name>` — удалит non-baseline content.
3. **Аккуратно:** просмотри `content/<dir>/`, перенеси что-то нужное в безопасное место, повтори без `--force`.

### `_apply_profile.py` упал — JSON plan не парсится

**Симптом:** `apply-overlay.sh` exit с ошибкой «_apply_profile.py упал».

**Причина:** invalid YAML в manifest, несуществующий on_value path, или invalid INIT_PROMPT value.

**Решение:**
1. Запусти helper напрямую: `python3 scripts/_apply_profile.py docs/overlays/profiles/<name> 2>&1`.
2. Прочитай stderr — там точная причина (какой ключ, какое значение).

## init.sh

### `init.sh` падает после init_prompts с «'X' не в choices [...]»

**Причина:** Ответ на enum-prompt не из `choices` манифеста (например ввели «yes» когда choices=[none, 152-fz, iso27001, other]).

**Решение:** ввести one-of валидное значение, или `INIT_PROMPT_<id>=<value>` через env var.

### `init.sh` отказывается потому что URL ведёт на репозиторий шаблона

**Симптом:** `ERROR: URL ведёт на репозиторий шаблона ('...')`.

**Причина:** Защита от случайного push в шаблон.

**Решение:** Создать новый repo (на GitHub/GitLab) и указать его URL.

## validate-profile.py

### `validate-profile.py` exit 1 «manifest.yaml not found»

**Причина:** Папка профиля без manifest'а.

**Решение:** Скопировать `docs/overlays/profiles/project/manifest.yaml` как template и настроить.

### `validate-profile.py` warning «AGENTS.md exists, но '## Каталог ролей' heading не найден»

**Причина (W3-A3):** `AGENTS.md` существует, но heading «## Каталог ролей» сломан (например переведено в «## Catalog of roles»). Validator ходит к этой секции для M4 — поэтому role validation skipped.

**Решение:** Восстановить точный heading: `## Каталог ролей` (русский, level 2).

### `validate-profile.py` exit 1 «schema_version: X не поддерживается»

**Причина (W3-A4):** Manifest имеет `schema_version` вне поддерживаемого enum (текущий: `{1}`).

**Решение:** Установить `schema_version: 1`. Если используешь новую версию schema — это значит W4+ ещё не релизнут; вернись на v1.

## validate-content.py

### `validate-content.py` exit 1 «orphan content (no _index.md)»

**Причина:** Папка содержит `.md` файлы или поддиректории, но нет `_index.md` — Gramax не покажет раздел в навигации.

**Решение:** Создать `_index.md` в этой папке. Без `properties:`, минимальное содержимое.

### `validate-content.py` exit 1 «{{PLACEHOLDER}} unfilled»

**Причина:** В файле остался template-placeholder типа `{{PROJECT_NAME}}` после init.

**Решение:** Запустить полный init: `bash scripts/init.sh --profile <name> "Name" "CODE" "desc" "email"`. Или заменить placeholder руками.

## Pre-commit hook

### Pre-commit hook блокирует commit

**Симптом:** `git commit` exit non-zero, в выводе validator errors.

**Причина:** `scripts/check.sh --fast` exit non-zero (validate-content или validate-profile failed).

**Решение:**
1. Прочитать ошибку, исправить.
2. **Bypass (если уверен):** `git commit --no-verify`.
3. **Полностью отключить:** `git config --unset core.hooksPath`.

### Pre-commit hook не срабатывает

**Причина:** `core.hooksPath` не установлен.

**Решение:** `bash scripts/install-hooks.sh`.

## Тесты

### `bash scripts/test-template.sh` падает на macOS bash 3.2

**Причина:** Используется bash-функция, требующая 4.x (associative arrays).

**Решение:** Использовать `/usr/bin/env bash` (как в скриптах). Если функция реально 4+ — открыть issue (это W2 контракт — bash 3.2 compat).

## Не нашёл свой случай?

1. Посмотри `docs/lessons-learned.md` — может, было раньше.
2. Запусти `bash scripts/check.sh --full` — full smoke даст направление.
3. Прочитай spec в `docs/superpowers/specs/` — там детали архитектуры.
