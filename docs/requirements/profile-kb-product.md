---
properties:
  - name: Тип контента
    value: [Требование]
  - name: Статус
    value: [Approved]
---

# Профиль kb-product — функтребования

## Контекст

Профиль `kb-product` предназначен для customer-facing документации продукта (отличается от `kb-team` — internal team KB). После init получаем структуру для onboarding конечных пользователей и администраторов.

## Структурные требования

### content-scaffold/

```
content-scaffold/
├── _index.md
├── getting-started/_index.md
├── guides/_index.md
├── reference/_index.md
└── troubleshooting/_index.md
```

Корневой `_index.md` — без `properties:` блока (правило Gramax). Подразделы — без статей, только index.

### subagents

| Роль | Status | Обоснование |
|------|--------|-------------|
| pm | core | always-on |
| tech-writer | core | primary writer для customer docs |
| researcher | optional | для подготовки release notes/глоссария |
| ba | optional | если нужны user requirements |
| compliance | optional | если продукт под compliance-надзором |
| sa, dev, devops, qa, devsecops | disabled | внутренние роли — не нужны для customer-facing |

### agent_overrides

Один override: `tech-writer.md` — customer-facing focus (см. AC ниже).

### .doc-root.yaml properties

| Property | Required | Values |
|----------|----------|--------|
| Тип контента | yes | Getting Started, Guide, Reference, Troubleshooting, Release Notes |
| Версия продукта | yes | string (e.g., "v1.2.3") |
| Аудитория | no | Конечный пользователь, Администратор, Разработчик-интегратор |

## Override AC: tech-writer для kb-product

**AC-tw-1:** Resolved tech-writer prompt содержит секцию «## Роль» с явным «Customer-facing tech writer».

**AC-tw-2:** Resolved prompt содержит секцию «## Domain» с правилами customer journey, screenshot conventions, version pinning.

**AC-tw-3:** Секции `## Constraints` и `## Tools` наследуются из base без изменений.

## Operations

После init kb-product отсутствуют папки delivery-структуры (00-project, 30-requirements, 40-architecture, 60-implementation, 70-operations). См. spec §4.5.
