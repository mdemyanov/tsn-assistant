# SMP Overlay

Готовый набор патчей для быстрого старта проекта на платформе Naumen SMP. После применения шаблон знает про DDD-маппинг к SMP, FQN/HQL-правила, hexagonal architecture, ADR-supersede процедуру и cross-каталожные Gramax-ссылки.

## Применить

```bash
bash scripts/apply-overlay.sh naumen-smp
```

## Откатить

```bash
bash scripts/apply-overlay.sh --remove naumen-smp
```

Идемпотентно: повторный apply даёт пустой diff. Повторный remove — no-op.

## Что меняется

| Файл | Что добавляется |
|------|-----------------|
| `CLAUDE.md` | Блок «Стек Naumen SMP» + DDD-карта + дополнительные red-lines |
| `content/.doc-root.yaml` | Property `Сценарий` (значения A-F — placeholder) |
| `content/10-domain/glossary.md` | Базовые SMP-термины (заявка, обращение, услуга, ОО, SLA, ...) |
| `.claude/plugins/project/agents/ba-agent.md` | JTBD-примеры в SMP-домене |
| `.claude/plugins/project/agents/sa-agent.md` | DDD→SMP-маппинг, hexagonal architecture, ADR-trail check |
| `.claude/plugins/project/agents/dev-agent.md` | Groovy reserved methods, MCP `call()` error handling, CodeNarc |

Все вставки между маркерами `<!-- OVERLAY:naumen-smp:start -->` / `:end -->` (или `# OVERLAY:naumen-smp:start/end` в YAML).

## Дополнительные материалы (не применяются автоматически)

- `references.md` — справочные пути и ссылки на документацию SMP, ITSM365, эталонные репо. Используй как лор при работе с overlay. НЕ копируется и не вставляется в проект — оставлен как маннуал для разработчика.

## Требования

- Глобальный плагин `naumen-smp-scripting` (для Groovy-скриптов SMP)
- (Опционально) Доступ к `Devel/naumen-ecosystem/` для cross-references

## После применения

В CLAUDE.md появятся ссылки на:
- `/Users/mdemyanov/Devel/naumen-ecosystem/naumen-smp` — документация SMP
- `/Users/mdemyanov/Devel/naumen-ecosystem/itsm365` — документация ITSM365

Если у тебя другие пути — вручную поправь блок в CLAUDE.md после apply.
