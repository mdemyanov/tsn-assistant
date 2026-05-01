#!/usr/bin/env python3
"""
Генератор шаблонов деловой переписки.
Создаёт базовую структуру письма/сообщения на основе параметров.

Использование:
    python generate_template.py --type email --goal inform --tone formal
    python generate_template.py --type messenger --goal request --tone casual
    python generate_template.py --interactive
"""

import argparse
import json
from datetime import datetime

# Шаблоны для email
EMAIL_TEMPLATES = {
    "inform": {
        "formal": """**Тема:** {subject}

Добрый день, {recipient}!

Сообщаю {what}.

{details}

{action}

С уважением,
{sender}
{position}
{contacts}""",
        
        "neutral": """**Тема:** {subject}

Добрый день!

Информирую о {what}.

{details}

{action}

С уважением,
{sender}""",
        
        "casual": """**Тема:** {subject}

Привет, {recipient}!

Кратко: {what}.

{details}

{action}

{sender}"""
    },
    
    "persuade": {
        "formal": """**Тема:** {subject}

Уважаемый {recipient}!

Предлагаю {what}. Это позволит {benefit}.

Обоснование:
{details}

{action}

С уважением,
{sender}
{position}
{contacts}""",
        
        "neutral": """**Тема:** {subject}

Добрый день, {recipient}!

Предлагаю {what} — это даст {benefit}.

Детали:
{details}

{action}

С уважением,
{sender}""",
        
        "casual": """**Тема:** {subject}

Привет!

Есть идея: {what}. Плюс в том, что {benefit}.

{details}

{action}

{sender}"""
    },
    
    "request": {
        "formal": """**Тема:** {subject}

Уважаемый {recipient}!

Прошу {what}.

{details}

Срок: {deadline}.

С уважением,
{sender}
{position}
{contacts}""",
        
        "neutral": """**Тема:** {subject}

Добрый день!

Прошу {what}.

{details}

Буду благодарен за ответ до {deadline}.

С уважением,
{sender}""",
        
        "casual": """**Тема:** {subject}

Привет!

Нужна помощь: {what}.

{details}

Если возможно — до {deadline}.

Спасибо!
{sender}"""
    },
    
    "problem": {
        "formal": """**Тема:** {subject}

Уважаемый {recipient}!

Информирую о возникшей ситуации: {what}.

Причина: {reason}

План действий:
{details}

{action}

С уважением,
{sender}
{position}
{contacts}""",
        
        "neutral": """**Тема:** {subject}

Добрый день!

Возникла ситуация: {what}.

Причина: {reason}

Решение:
{details}

{action}

С уважением,
{sender}""",
        
        "casual": """**Тема:** {subject}

Привет!

Есть проблема: {what}. Причина — {reason}.

Что делаем:
{details}

{action}

{sender}"""
    }
}

# Шаблоны для мессенджеров
MESSENGER_TEMPLATES = {
    "inform": {
        "formal": """Добрый день! {what}. {details} {action}""",
        "neutral": """Привет! Инфо: {what}. {details}""",
        "casual": """Привет! {what}. {details}"""
    },
    
    "persuade": {
        "formal": """Добрый день! Предлагаю {what} — это позволит {benefit}. {details} Как смотрите?""",
        "neutral": """Привет! Идея: {what}. Плюс — {benefit}. {details} Что думаешь?""",
        "casual": """Есть мысль: {what}. {benefit} {details} Как тебе?"""
    },
    
    "request": {
        "formal": """Добрый день! Прошу {what}. {details} Срок: {deadline}.""",
        "neutral": """Привет! Нужно {what}. {details} Можешь до {deadline}?""",
        "casual": """Можешь {what}? {details} Надо бы до {deadline}"""
    },
    
    "problem": {
        "formal": """Добрый день! Возникла ситуация: {what}. Причина: {reason}. Решение: {details}""",
        "neutral": """Привет! Проблема: {what}. {reason}. Делаем: {details}""",
        "casual": """🔴 {what}. {reason}. Решаем: {details}"""
    }
}

# Подсказки для заполнения
FIELD_HINTS = {
    "subject": "Тема письма (5-7 слов, конкретика)",
    "recipient": "Имя получателя",
    "sender": "Ваше имя",
    "position": "Должность (опционально)",
    "contacts": "Контакты (опционально)",
    "what": "Суть сообщения (1-2 предложения)",
    "details": "Детали, факты, список пунктов",
    "action": "Призыв к действию",
    "benefit": "Выгода/польза для получателя",
    "reason": "Причина (для проблемных писем)",
    "deadline": "Срок (конкретная дата или время)"
}

def get_template(msg_type: str, goal: str, tone: str) -> str:
    """Возвращает шаблон по параметрам."""
    templates = EMAIL_TEMPLATES if msg_type == "email" else MESSENGER_TEMPLATES
    
    if goal not in templates:
        raise ValueError(f"Unknown goal: {goal}. Available: {list(templates.keys())}")
    
    if tone not in templates[goal]:
        raise ValueError(f"Unknown tone: {tone}. Available: {list(templates[goal].keys())}")
    
    return templates[goal][tone]

def get_required_fields(template: str) -> list:
    """Извлекает список полей из шаблона."""
    import re
    return list(set(re.findall(r'\{(\w+)\}', template)))

def interactive_mode():
    """Интерактивный режим генерации."""
    print("\n📧 Генератор шаблонов деловой переписки\n")
    print("=" * 50)
    
    # Выбор типа
    print("\nТип сообщения:")
    print("  1. Email (письмо)")
    print("  2. Messenger (чат/мессенджер)")
    msg_type = "email" if input("\nВыбор [1/2]: ").strip() == "1" else "messenger"
    
    # Выбор цели
    print("\nЦель:")
    print("  1. inform — информировать")
    print("  2. persuade — убедить/предложить")
    print("  3. request — запросить")
    print("  4. problem — сообщить о проблеме")
    goal_map = {"1": "inform", "2": "persuade", "3": "request", "4": "problem"}
    goal = goal_map.get(input("\nВыбор [1-4]: ").strip(), "inform")
    
    # Выбор тона
    print("\nТон:")
    print("  1. formal — формальный")
    print("  2. neutral — нейтральный")
    print("  3. casual — неформальный")
    tone_map = {"1": "formal", "2": "neutral", "3": "casual"}
    tone = tone_map.get(input("\nВыбор [1-3]: ").strip(), "neutral")
    
    # Получение шаблона
    template = get_template(msg_type, goal, tone)
    fields = get_required_fields(template)
    
    print("\n" + "=" * 50)
    print("Заполните поля (Enter — пропустить):\n")
    
    values = {}
    for field in fields:
        hint = FIELD_HINTS.get(field, "")
        value = input(f"  {field} ({hint}): ").strip()
        values[field] = value if value else f"[{field}]"
    
    # Генерация
    result = template.format(**values)
    
    print("\n" + "=" * 50)
    print("📝 РЕЗУЛЬТАТ:\n")
    print(result)
    print("\n" + "=" * 50)
    
    # Сохранение
    save = input("\nСохранить в файл? [y/N]: ").strip().lower()
    if save == "y":
        filename = f"letter_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
        with open(filename, "w", encoding="utf-8") as f:
            f.write(result)
        print(f"✅ Сохранено: {filename}")

def main():
    parser = argparse.ArgumentParser(
        description="Генератор шаблонов деловой переписки",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Примеры:
  %(prog)s --type email --goal inform --tone formal
  %(prog)s --type messenger --goal request --tone casual
  %(prog)s --interactive
  %(prog)s --list-templates
        """
    )
    
    parser.add_argument(
        "--type", "-t",
        choices=["email", "messenger"],
        help="Тип сообщения"
    )
    parser.add_argument(
        "--goal", "-g",
        choices=["inform", "persuade", "request", "problem"],
        help="Цель: inform, persuade, request, problem"
    )
    parser.add_argument(
        "--tone", "-n",
        choices=["formal", "neutral", "casual"],
        default="neutral",
        help="Тон: formal, neutral, casual (default: neutral)"
    )
    parser.add_argument(
        "--interactive", "-i",
        action="store_true",
        help="Интерактивный режим"
    )
    parser.add_argument(
        "--list-templates", "-l",
        action="store_true",
        help="Показать все доступные шаблоны"
    )
    parser.add_argument(
        "--json", "-j",
        action="store_true",
        help="Вывести шаблон в JSON"
    )
    
    args = parser.parse_args()
    
    if args.interactive:
        interactive_mode()
        return
    
    if args.list_templates:
        print("\n📋 Доступные шаблоны:\n")
        for msg_type, templates in [("EMAIL", EMAIL_TEMPLATES), ("MESSENGER", MESSENGER_TEMPLATES)]:
            print(f"\n{msg_type}:")
            for goal in templates:
                tones = ", ".join(templates[goal].keys())
                print(f"  • {goal}: {tones}")
        return
    
    if not args.type or not args.goal:
        parser.print_help()
        return
    
    template = get_template(args.type, args.goal, args.tone)
    fields = get_required_fields(template)
    
    if args.json:
        output = {
            "type": args.type,
            "goal": args.goal,
            "tone": args.tone,
            "template": template,
            "fields": {f: FIELD_HINTS.get(f, "") for f in fields}
        }
        print(json.dumps(output, ensure_ascii=False, indent=2))
    else:
        print(f"\n📝 Шаблон: {args.type} / {args.goal} / {args.tone}\n")
        print("-" * 50)
        print(template)
        print("-" * 50)
        print(f"\nПоля для заполнения: {', '.join(fields)}")

if __name__ == "__main__":
    main()
