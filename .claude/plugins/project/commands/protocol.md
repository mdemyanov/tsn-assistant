---
description: "Создать протокол общего собрания (ОСС для МКД / ОС для СНТ) или заседания правления. Делегирует docs."
allowed-tools: Agent
---

Создай протокол через `docs`-агент:

**Пользовательский запрос:** `$ARGUMENTS` (формат: `--type=general-meeting|board <дата> <повестка>`)

Передай:
- **Цель:** протокол общего собрания или заседания правления
- **Входы:**
  - `content/07-legal/templates/protocol-<type>.md` (если есть)
  - `content/01-property/passport.md` (тип организации)
  - `content/02-owners/registry.md` (для кворума ОСС/ОС)
  - `content/04-general-meeting/procedures.md` (порядок проведения по типу)
- **Артефакт:**
  - Для общего собрания: `content/04-general-meeting/YYYY/YYYY-MM-DD_protocol.md`
  - Для заседания правления: `content/03-board/meetings/YYYY-MM-DD_meeting.md`
- **Критерии:** правовая база соответствует типу (ЖК РФ ст.44-48 для МКД ОСС / ФЗ-217 ст.17-21 для СНТ ОС), кворум посчитан, бюллетени учтены (если заочное)
