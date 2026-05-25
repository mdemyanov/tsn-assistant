---
description: "Сохранить ключевой substantive-анализ (>500 слов с выводами). Куда — определяется по теме."
allowed-tools: Read, Write, Edit, Glob, Grep
---

Сохрани substantive-анализ из текущего разговора:

**Пользовательский запрос:** `$ARGUMENTS` (опц. — заголовок инсайта; если не передан — спроси)

1. **Определи категорию** (по теме разговора):
   - Юридический → `content/07-legal/insights/`
   - Финансовый → `content/05-finance/insights/`
   - Проектный → `content/08-projects/<project>/insights/` (если в контексте проекта; уточни если неоднозначно)
2. **Имя файла:** `YYYY-MM-DD_insight_<slug>.md`
3. **Структура:**

```markdown
---
properties:
  - name: Тип документа
    value: [Insight]
  - name: Категория
    value: [<категория>]
  - name: Статус
    value: [Действует]
date: YYYY-MM-DD
tags: [...]
---

# <Заголовок>

## Контекст
[Что обсуждали, почему вопрос важен]

## Ключевые выводы
- Вывод 1
- Вывод 2

## Источники
- ...

## Рекомендации
- ...
```

4. Append в `content/03-board/log.md`: `- YYYY-MM-DD HH:MM — /insight — <заголовок> → <путь>`
5. Верни путь созданного файла
