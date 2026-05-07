---
properties:
  - name: Тип контента
    value: [Архитектура]
  - name: Статус
    value: [Approved]
---

# Spec: профиль kb-product (stable)

## Manifest

`docs/overlays/profiles/kb-product/manifest.yaml`:

```yaml
schema_version: 1
name: kb-product
description: Документация продукта/процесса для внешних читателей
audience: Customer success, технические писатели, продуктовые менеджеры
status: stable

subagents:
  pm: core
  tech-writer: core
  researcher: optional
  ba: optional
  compliance: optional
  sa: disabled
  dev: disabled
  devops: disabled
  qa: disabled
  devsecops: disabled

pipelines: {}

content_scaffold: content-scaffold/
doc_root: doc-root.yaml

operations:
  - op: delete
    target: content/00-project/
    reason: "kb-product не использует delivery-структуру"
  - op: delete
    target: content/30-requirements/
    reason: "customer docs не имеют функциональных требований"
  - op: delete
    target: content/40-architecture/
    reason: "архитектура продукта не публикуется наружу"
  - op: delete
    target: content/60-implementation/
    reason: "нет реализации"
  - op: delete
    target: content/70-operations/
    reason: "operations не для внешнего читателя"
  - op: add
    source: content-scaffold/
    target: content/
    reason: "kb-product scaffold (getting-started, guides, reference, troubleshooting)"
  - op: replace
    source: doc-root.yaml
    target: content/.doc-root.yaml
    reason: "kb-product properties (Тип контента, Версия продукта, Аудитория)"

agent_overrides:
  tech-writer:
    source: agent-overrides/tech-writer.md

init_prompts: []

compatible_stacks: []
maintainer: project_template
```

## Content scaffold tree

```
docs/overlays/profiles/kb-product/content-scaffold/
├── _index.md                       # корневой index с дашбордом
├── getting-started/
│   └── _index.md
├── guides/
│   └── _index.md
├── reference/
│   └── _index.md
└── troubleshooting/
    └── _index.md
```

Все `_index.md` — без `properties:` блока (правило Gramax).

## doc-root.yaml

```yaml
title: "{{PROJECT_NAME}} — Документация"
properties:
  - name: Тип контента
    type: enum
    values: [Getting Started, Guide, Reference, Troubleshooting, Release Notes]
    required: true
  - name: Версия продукта
    type: string
    placeholder: "v1.2.3"
    required: true
  - name: Аудитория
    type: enum
    values: [Конечный пользователь, Администратор, Разработчик-интегратор]
    required: false
```

## Override: tech-writer

`docs/overlays/profiles/kb-product/agent-overrides/tech-writer.md`:

```markdown
---
extends: tech-writer
description: Технический писатель — документация продукта для внешних читателей
---

## Роль

Customer-facing tech writer. Пишешь документацию **для конечных пользователей и администраторов продукта**, не для команды разработки.

Принципы:
- Не используешь жаргон команды (sprints, tickets, PRs)
- Версионируешь каждую статью под версию продукта
- Каждый guide начинается с «Что вы получите в итоге»

## Domain

- **Customer journey ≠ internal flow.** Структура от задачи пользователя, не от структуры кода.
- **Screenshot conventions:** один скриншот = одна задача; обводка важной кнопки красным; pixel-perfect версия UI.
- **Version pinning:** каждая статья указывает «применимо к версии vX.Y.Z+».
- **Reference material:** API spec / CLI reference генерится автоматически — не пиши руками.
- **Tone:** дружелюбный, но не фамильярный; "вы" а не "ты".
```

NB: остальные секции (Constraints, Tools) наследуются из base.

## Example tree

`examples/kb-product-example/`:

```
README.md                                   # «Это пример проекта на профиле kb-product»
.doc-root.yaml
CLAUDE.md
AGENTS.md
README.md                                   # project-уровень
content/
├── _index.md
├── getting-started/_index.md
├── guides/_index.md
├── reference/_index.md
└── troubleshooting/_index.md
.claude/plugins/project/agents/
└── tech-writer-agent.md                    # resolved version с override applied
```

## AC integration tests

- `T-W4a-P4-init`: `bash scripts/init.sh --profile kb-product "TestProduct" "TP" "desc" "test@x.com"` exit 0
- `T-W4a-P4-scaffold`: `[ -f content/getting-started/_index.md ]` && (для всех 4 разделов)
- `T-W4a-P4-override`: `grep "Customer-facing" .claude/plugins/project/agents/tech-writer-agent.md`
- `T-W4a-P4-noise`: `[ ! -d content/00-project ]` && `[ ! -d content/30-requirements ]` && (для всех 5 удалённых)
