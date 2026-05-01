# Скрипты для Correspondence 2.0

## generate_template.py

Python-скрипт для генерации шаблонов деловой переписки.

### Требования

- Python 3.7+
- Без внешних зависимостей

### Установка

```bash
chmod +x generate_template.py
```

### Использование

#### Интерактивный режим (рекомендуется)

```bash
python generate_template.py --interactive
# или
python generate_template.py -i
```

Пошаговый мастер:
1. Выбор типа (email / messenger)
2. Выбор цели (информировать / убедить / запросить / проблема)
3. Выбор тона (формальный / нейтральный / неформальный)
4. Заполнение полей
5. Готовый текст + опция сохранения

#### Командная строка

```bash
# Формальное информационное email
python generate_template.py --type email --goal inform --tone formal

# Неформальный запрос в мессенджер
python generate_template.py -t messenger -g request -n casual

# JSON-вывод (для интеграций)
python generate_template.py -t email -g persuade -n neutral --json
```

#### Просмотр всех шаблонов

```bash
python generate_template.py --list-templates
```

### Параметры

| Параметр | Сокращение | Значения | Описание |
|----------|------------|----------|----------|
| `--type` | `-t` | email, messenger | Тип сообщения |
| `--goal` | `-g` | inform, persuade, request, problem | Цель |
| `--tone` | `-n` | formal, neutral, casual | Тон (default: neutral) |
| `--interactive` | `-i` | — | Интерактивный режим |
| `--list-templates` | `-l` | — | Список шаблонов |
| `--json` | `-j` | — | JSON-вывод |

### Примеры вывода

#### Email / Inform / Formal

```
**Тема:** {subject}

Добрый день, {recipient}!

Сообщаю {what}.

{details}

{action}

С уважением,
{sender}
{position}
{contacts}
```

#### Messenger / Request / Casual

```
Можешь {what}? {details} Надо бы до {deadline}
```

### Интеграция с другими инструментами

JSON-вывод можно использовать для интеграции:

```bash
python generate_template.py -t email -g problem -n neutral --json | jq '.template'
```

### Расширение

Для добавления новых шаблонов отредактируйте словари `EMAIL_TEMPLATES` и `MESSENGER_TEMPLATES` в скрипте.
