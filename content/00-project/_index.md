---
order: 10
title: Проект и ADR
---

# Проектные артефакты

Цели проекта, ADR (Architecture Decision Records), roadmap, stakeholders.

## Структура

- `adr/` — Architecture Decision Records (нумерация: `ADR-NNN-<slug>.md`)
- `roadmap.md` — фазы и milestone'ы (создаётся PM)
- `stakeholders.md` — карта стейкхолдеров (создаётся PM)

## Правила

- Новый ADR создаёт SA через `/sa adr <решение>`.
- Принятые ADR не редактируются. При смене решения — новый ADR со ссылкой на superseded.
