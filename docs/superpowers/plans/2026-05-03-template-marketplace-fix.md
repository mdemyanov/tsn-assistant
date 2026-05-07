# Template Marketplace Init Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Починить инициализацию локального marketplace плагинов в `project_template` так, чтобы `project@local` корректно резолвился сразу после клона шаблона, без ручной правки путей.

**Architecture:** Шаблон проекта поставляет три файла плагинной инфраструктуры: (1) `.claude-plugin/marketplace.json` в корне — описание локального marketplace с `directory`-источником; (2) `.claude/settings.json` — регистрация трёх marketplace'ов (`ai-assistants`, `claude-plugins-official`, `local`) и включение трёх плагинов; (3) `.claude/plugins/project/` — сам локальный плагин с агентами/командами/скиллами. Ключ к портируемости — `"path": "."` в `extraKnownMarketplaces.local.source` (поддерживается Claude Code, проверено в `naumen-smp-mcp`).

**Tech Stack:** Claude Code plugin marketplace (directory source), JSON, Markdown.

**Reference implementation:** `/Users/mdemyanov/Devel/pg_vector_service/.claude-plugin/marketplace.json` + `/Users/mdemyanov/Devel/naumen-smp-mcp/.claude/settings.json` (для паттерна `"path": "."`).

---

## Текущее состояние (что сломано)

| Файл | Проблема |
|------|----------|
| `.claude-plugin/marketplace.json` | **Отсутствует** — без него `local` marketplace не может декларировать плагин `project` |
| `.claude/settings.json` | Включает `project@local: true`, но в `extraKnownMarketplaces` НЕ объявлен `local` — плагин не резолвится |
| `.claude/plugins/project-template/` | Папка названа `project-template`, а `plugin.json` внутри говорит `name: "project"` — несогласованность с конвенцией `pg_vector_service` (там папка `project`) |
| `CLAUDE.md` | Не описывает, какие файлы плагинной системы поставляет шаблон и что меняется при клоне |

## Решения по дизайну

1. **Папка плагина — `project`** (не `project-template`). Имя плагина в `plugin.json` уже `project`, и в `enabledPlugins` он значится как `project@local`. Совпадение имени папки с именем плагина — конвенция эталона `pg_vector_service`.

2. **`"path": "."` для `local` marketplace.** Относительный путь резолвится Claude Code от каталога, в котором лежит `settings.json`. Это даёт портируемость: после клона никаких ручных правок путей не требуется. Подтверждено живой конфигурацией `naumen-smp-mcp` (`/Users/mdemyanov/Devel/naumen-smp-mcp/.claude/settings.json`).

3. **`pg_vector_service` НЕ меняем.** Там абсолютный путь работает; рефакторинг — отдельная задача и за scope этого плана.

4. **ITSM-роль НЕ переносим в шаблон.** Это специфика `pg_vector_service` (см. memory `project_itsm_analyst_role`).

## File Structure

| Файл | Что делаем | Ответственность |
|------|-----------|-----------------|
| `/Users/mdemyanov/knowlage/project_template/.claude-plugin/marketplace.json` | **Создать** | Определяет `local` marketplace с одним плагином `project`, source `./.claude/plugins/project` |
| `/Users/mdemyanov/knowlage/project_template/.claude/plugins/project/` | **Переименовать** из `project-template` | Каталог локального плагина (агенты, команды, скиллы) |
| `/Users/mdemyanov/knowlage/project_template/.claude/settings.json` | **Изменить** | Добавить `local` marketplace в `extraKnownMarketplaces` с `"path": "."` |
| `/Users/mdemyanov/knowlage/project_template/CLAUDE.md` | **Изменить** | Добавить секцию «Структура плагинной системы» с описанием файлов |

---

### Task 1: Создать `.claude-plugin/marketplace.json` в корне шаблона

**Files:**
- Create: `/Users/mdemyanov/knowlage/project_template/.claude-plugin/marketplace.json`

- [ ] **Step 1: Проверить, что каталог `.claude-plugin/` отсутствует**

```bash
ls -la /Users/mdemyanov/knowlage/project_template/.claude-plugin/ 2>&1
```
Expected: `No such file or directory` (если каталог есть — остановиться, проверить содержимое).

- [ ] **Step 2: Создать каталог**

```bash
mkdir -p /Users/mdemyanov/knowlage/project_template/.claude-plugin
```

- [ ] **Step 3: Записать `marketplace.json`**

Содержимое файла `/Users/mdemyanov/knowlage/project_template/.claude-plugin/marketplace.json`:

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "local",
  "description": "Локальный marketplace шаблона проекта. После клона имя marketplace остаётся `local`, плагин — `project`.",
  "owner": {
    "name": "mdemyanov"
  },
  "plugins": [
    {
      "name": "project",
      "description": "Универсальные агенты (PM/BA/SA/Dev/DevOps/Researcher), команды и приватные скиллы шаблона внутренних проектов.",
      "source": "./.claude/plugins/project",
      "category": "development"
    }
  ]
}
```

- [ ] **Step 4: Верифицировать JSON-валидность**

```bash
python3 -c "import json; d=json.load(open('/Users/mdemyanov/knowlage/project_template/.claude-plugin/marketplace.json')); assert d['name']=='local'; assert d['plugins'][0]['name']=='project'; assert d['plugins'][0]['source']=='./.claude/plugins/project'; print('OK:', d['name'], '->', d['plugins'][0]['name'])"
```
Expected: `OK: local -> project`

---

### Task 2: Переименовать каталог плагина `project-template` → `project`

**Files:**
- Rename: `/Users/mdemyanov/knowlage/project_template/.claude/plugins/project-template/` → `/Users/mdemyanov/knowlage/project_template/.claude/plugins/project/`

- [ ] **Step 1: Проверить, что исходная папка существует и целевая — нет**

```bash
test -d /Users/mdemyanov/knowlage/project_template/.claude/plugins/project-template && echo "src OK" && test ! -e /Users/mdemyanov/knowlage/project_template/.claude/plugins/project && echo "dst clear"
```
Expected: `src OK` затем `dst clear`. Если что-то не так — остановиться.

- [ ] **Step 2: Переименовать через `git mv` (сохранит историю файлов в репозитории)**

```bash
cd /Users/mdemyanov/knowlage/project_template && git mv .claude/plugins/project-template .claude/plugins/project
```

- [ ] **Step 3: Проверить, что `plugin.json` внутри декларирует `name: "project"` (не должен требовать изменений)**

```bash
python3 -c "import json; d=json.load(open('/Users/mdemyanov/knowlage/project_template/.claude/plugins/project/.claude-plugin/plugin.json')); assert d['name']=='project', f'expected project, got {d[\"name\"]}'; print('OK plugin name:', d['name'])"
```
Expected: `OK plugin name: project`

- [ ] **Step 4: Проверить через `git status`, что переименование зафиксировано как rename (а не delete+add)**

```bash
cd /Users/mdemyanov/knowlage/project_template && git status --short | head -20
```
Expected: Записи вида `R  .claude/plugins/project-template/... -> .claude/plugins/project/...`

---

### Task 3: Починить `.claude/settings.json` — зарегистрировать `local` marketplace

**Files:**
- Modify: `/Users/mdemyanov/knowlage/project_template/.claude/settings.json`

- [ ] **Step 1: Записать новое содержимое `settings.json`**

Полное новое содержимое файла `/Users/mdemyanov/knowlage/project_template/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "ai-assistants": {
      "source": {
        "source": "github",
        "repo": "mdemyanov/ai-assistants"
      }
    },
    "claude-plugins-official": {
      "source": {
        "source": "github",
        "repo": "anthropics/claude-plugins"
      }
    },
    "local": {
      "source": {
        "source": "directory",
        "path": "."
      }
    }
  },
  "enabledPlugins": {
    "gramax@ai-assistants": true,
    "superpowers@claude-plugins-official": true,
    "project@local": true
  }
}
```

- [ ] **Step 2: Верифицировать JSON и кросс-ссылки**

```bash
python3 <<'EOF'
import json
p = '/Users/mdemyanov/knowlage/project_template/.claude/settings.json'
d = json.load(open(p))
mks = d['extraKnownMarketplaces']
plugins = d['enabledPlugins']
for plug in plugins:
    name, mk = plug.split('@')
    assert mk in mks, f"plugin {plug} references missing marketplace {mk}"
assert mks['local']['source']['source'] == 'directory'
assert mks['local']['source']['path'] == '.'
print('OK: все enabledPlugins резолвятся через extraKnownMarketplaces')
print('OK: local marketplace path =', mks['local']['source']['path'])
EOF
```
Expected: 
```
OK: все enabledPlugins резолвятся через extraKnownMarketplaces
OK: local marketplace path = .
```

---

### Task 4: Обновить `CLAUDE.md` — добавить раздел «Структура плагинной системы»

**Files:**
- Modify: `/Users/mdemyanov/knowlage/project_template/CLAUDE.md`

- [ ] **Step 1: Прочитать текущий `CLAUDE.md`, чтобы найти точку вставки**

Раздел `## Подключённые плагины` уже описывает СОСТАВ плагинов. Новый раздел `## Структура плагинной системы` встанет **сразу после** него, чтобы читатель видел: «вот плагины» → «вот как устроена их инициализация».

- [ ] **Step 2: Вставить новый раздел через `Edit`**

Найти в `/Users/mdemyanov/knowlage/project_template/CLAUDE.md` блок:

```
- **project@local** — агенты PM/BA/SA/Dev/DevOps/Researcher + локальные скиллы (`infoinstyle`, `correspondence-2`)

## Поток работы
```

И заменить на:

```
- **project@local** — агенты PM/BA/SA/Dev/DevOps/Researcher + локальные скиллы (`infoinstyle`, `correspondence-2`)

## Структура плагинной системы

Шаблон поставляет три файла, которые делают `project@local` работающим сразу после клона:

| Файл | Назначение |
|------|------------|
| `.claude-plugin/marketplace.json` | Декларирует локальный marketplace `local` и плагин `project` (source — `./.claude/plugins/project`) |
| `.claude/settings.json` | Регистрирует marketplace'ы (`ai-assistants`, `claude-plugins-official`, `local`) и включает три плагина |
| `.claude/plugins/project/` | Сам локальный плагин: агенты `agents/`, команды `commands/`, скиллы `skills/` |

Локальный marketplace использует `"path": "."` — относительный путь от `settings.json`. После клона шаблона **ничего править не нужно**: путь резолвится автоматически.

**Если нужно переименовать плагин под конкретный проект:**

1. Переименуй `.claude/plugins/project/` → `.claude/plugins/<new-name>/`.
2. В `.claude-plugin/marketplace.json` поменяй `plugins[0].name` и `plugins[0].source`.
3. В `.claude/plugins/<new-name>/.claude-plugin/plugin.json` поменяй `name`.
4. В `.claude/settings.json` поменяй ключ в `enabledPlugins`: `project@local` → `<new-name>@local`.

В большинстве проектов имя плагина оставляют `project` — оно нейтральное и не требует правок.

## Поток работы
```

- [ ] **Step 3: Верифицировать вставку**

```bash
grep -n "Структура плагинной системы" /Users/mdemyanov/knowlage/project_template/CLAUDE.md && grep -n "marketplace.json" /Users/mdemyanov/knowlage/project_template/CLAUDE.md
```
Expected: По одной строке для каждого `grep` (заголовок раздела + упоминание `marketplace.json`).

---

### Task 5: End-to-end верификация плагинной системы

- [ ] **Step 1: Кросс-проверить, что все три файла плагинной инфры консистентны**

```bash
python3 <<'EOF'
import json, os
ROOT = '/Users/mdemyanov/knowlage/project_template'

mk = json.load(open(f'{ROOT}/.claude-plugin/marketplace.json'))
st = json.load(open(f'{ROOT}/.claude/settings.json'))
pl = json.load(open(f'{ROOT}/.claude/plugins/project/.claude-plugin/plugin.json'))

assert mk['name'] == 'local', f"marketplace name: {mk['name']}"
assert mk['plugins'][0]['name'] == 'project', f"plugin name in marketplace: {mk['plugins'][0]['name']}"
assert mk['plugins'][0]['source'] == './.claude/plugins/project', f"plugin source: {mk['plugins'][0]['source']}"
assert os.path.isdir(f"{ROOT}/.claude/plugins/project"), "plugin folder missing"
assert pl['name'] == 'project', f"plugin.json name: {pl['name']}"
assert 'project@local' in st['enabledPlugins'], "project@local not enabled"
assert st['extraKnownMarketplaces']['local']['source']['path'] == '.', "local marketplace path != '.'"

print('OK: marketplace.json -> local/project')
print('OK: plugin.json name -> project')
print('OK: plugin folder exists')
print('OK: settings.json enables project@local with local marketplace path "."')
EOF
```
Expected: 4 строки `OK:` без AssertionError.

- [ ] **Step 2: Убедиться, что старая папка `project-template` не осталась**

```bash
test ! -e /Users/mdemyanov/knowlage/project_template/.claude/plugins/project-template && echo "OK: project-template folder removed"
```
Expected: `OK: project-template folder removed`.

- [ ] **Step 3: Проверить, что в шаблоне нет упоминаний `project-template@local` (старое имя плагина)**

```bash
grep -rn "project-template@local" /Users/mdemyanov/knowlage/project_template/ 2>/dev/null && echo "FOUND STALE REFS" || echo "OK: no stale project-template@local refs"
```
Expected: `OK: no stale project-template@local refs`.

---

### Task 6: Commit

- [ ] **Step 1: Посмотреть git status**

```bash
cd /Users/mdemyanov/knowlage/project_template && git status --short
```

Ожидать:
- `??  .claude-plugin/marketplace.json` (новый файл)
- `M   .claude/settings.json`
- `M   CLAUDE.md`
- Серия `R  .claude/plugins/project-template/... -> .claude/plugins/project/...`
- `??  docs/superpowers/plans/2026-05-03-template-marketplace-fix.md` (этот план)

- [ ] **Step 2: Закоммитить**

```bash
cd /Users/mdemyanov/knowlage/project_template && git add .claude-plugin/marketplace.json .claude/settings.json .claude/plugins CLAUDE.md docs/superpowers/plans/2026-05-03-template-marketplace-fix.md && git commit -m "$(cat <<'EOF'
fix(plugins): починить инициализацию локального marketplace

- добавить .claude-plugin/marketplace.json (был отсутствовал — project@local не резолвился)
- зарегистрировать local marketplace в .claude/settings.json (path=".", портируемо)
- переименовать .claude/plugins/project-template → project (синхронизация с plugin.json name)
- описать структуру плагинной системы в CLAUDE.md

После клона шаблона плагин project@local работает без ручных правок путей.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Проверить успешный коммит**

```bash
cd /Users/mdemyanov/knowlage/project_template && git log -1 --stat
```
Expected: коммит с правильным сообщением и списком изменённых файлов (включая R-rename).

---

## Self-Review

**Spec coverage:**
- ✅ Создание `marketplace.json` — Task 1
- ✅ Регистрация `local` в settings.json — Task 3
- ✅ Переименование папки плагина — Task 2
- ✅ Документирование в CLAUDE.md — Task 4
- ✅ End-to-end верификация — Task 5
- ✅ Не трогаем pg_vector_service (per design decision)
- ✅ Не переносим ITSM-роль (project-specific)

**Placeholder scan:** Нет TBD/TODO/«implement later». Все JSON и команды конкретные.

**Type consistency:** Все имена согласованы:
- marketplace name: `local` (всюду)
- plugin name: `project` (в marketplace.json, plugin.json, settings.json как `project@local`)
- folder: `.claude/plugins/project` (в marketplace.json source, в файловой системе после Task 2)
- path в settings: `"."` (один источник)

**Risks / edge cases:**
- Если в репозитории уже есть незакоммиченные изменения в `project-template/` — `git mv` сохранит их, но история rename'а может быть запутанной. Mitigation: Step 4 в Task 2 проверяет, что переименование зафиксировано как `R`.
- Если в `CLAUDE.md` найден маркер «`## Поток работы`» в нескольких местах — `Edit` упадёт. Mitigation: маркер в Task 4 включает блок «`- **project@local**...`», который встречается ровно один раз.
