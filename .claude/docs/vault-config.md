# Vault config — {{TSN_NAME}}

Параметры товарищества для использования агентами и командами. Заполняется на `/init` Phase 2.

## Базовые

- **Название:** {{TSN_NAME}}
- **Код Gramax:** {{TSN_CODE}}
- **Адрес:** {{TSN_ADDRESS}}
- **Председатель/и.о.:** {{CHAIR_NAME}}
- **Email редактора:** {{EDITOR_EMAIL}}

## Тип и характеристики

- **Тип организации:** <!-- TODO(/init): МКД (ТСЖ/ЖСК) / СНТ / ОНТ -->
- **Регион:** <!-- TODO(/init) -->
- **Год создания/постройки:** <!-- TODO(/init) -->
- **Общая площадь:** <!-- TODO(/init): м² (МКД) или га (СНТ) -->
- **Количество объектов:**
  - Квартир: <!-- TODO(/init): для МКД -->
  - Коммерческих: <!-- TODO(/init): для МКД -->
  - Участков: <!-- TODO(/init): для СНТ -->

## Каталоги (paths)

| Параметр | Значение |
|----------|----------|
| `property_dir` | `content/01-property` |
| `owners_dir` | `content/02-owners` |
| `board_dir` | `content/03-board` |
| `general_meeting_dir` | `content/04-general-meeting` |
| `finance_dir` | `content/05-finance` |
| `contracts_dir` | `content/06-contracts` |
| `legal_dir` | `content/07-legal` |
| `projects_dir` | `content/08-projects` |
| `contacts_dir` | `content/09-contacts` |
| `archive_dir` | `content/10-archive` |
| `templates_dir` | `content/07-legal/templates` |
| `actors_path` | `content/03-board/actors.md` |
| `manager_state_path` | `content/03-board/manager-state.md` |
| `log_path` | `content/03-board/log.md` |
