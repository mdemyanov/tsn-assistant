---
order: 2
title: "Yandex Cloud Foundation Models — выбор модели и стоимость"
properties:
  - Тип контента: Исследование
  - Фаза: PoC
  - Статус: Approved
---

# Yandex Cloud Foundation Models — выбор embedding-модели

Актуализировано после получения live-данных через `yc` CLI и smoke-тестов 2026-05-01.

## Резюме

В Yandex Cloud Foundation Models доступны две асимметричные embedding-модели для русского языка: **`text-search-doc/latest`** (для индексации документов) и **`text-search-query/latest`** (для поисковых запросов). Обе возвращают вектор **размерности 256** (modelVersion `06.12.2023`). Аутентификация — через **API-Key** (`Authorization: Api-Key <key>`) или IAM-token. Ценник YC FM не вытащен через CLI — его нужно сверить руками в `https://yandex.cloud/ru/docs/foundation-models/pricing` (открывается в браузере, CAPTCHA пройдёт).

**Что теперь можно зафиксировать в ADR:** размерность вектора 256 → `vector(256)` в pgvector таблице (ADR-004), асимметричная модель (doc для UC1, query для UC2 при поиске «по тексту»; для UC2 «по объекту» — снова doc), HNSW параметры из RES-004 для размерности ≤512 (`m=16, ef_construction=64`).

## Доступные embedding-модели (live-проверка 2026-05-01)

| modelUri | Назначение | Размерность | numTokens (тест) | modelVersion |
|----------|------------|:-----------:|:----------------:|:------------:|
| `emb://<folder-id>/text-search-doc/latest` | Индексация документов (UC1 vectorization, UC2 «найти похожие на этот объект») | **256** | 14 (на тест-фразу 49 символов) | `06.12.2023` |
| `emb://<folder-id>/text-search-query/latest` | Свободные поисковые запросы (UC2 free-text) | **256** | 14 (та же фраза) | `06.12.2023` |

**Источник:** smoke-curl на `https://llm.api.cloud.yandex.net/foundationModels/v1/textEmbedding` с API-Key, верифицировано 2026-05-01. Запросы выполнены из CLI хоста разработки (вне стенда `llm2`) — для финальной верификации с `llm2` нужен smoke-тест в задаче DEVOPS (network connectivity).

**Асимметрия (важно для архитектуры):**
- При векторизации SMP-объекта в фоновой джобе (UC1) используется `text-search-doc`.
- При similarity-поиске «найти похожие на этот объект» (UC2) исходный объект уже векторизован моделью `text-search-doc` — для запроса используется тот же эмбеддинг **или** новый эмбеддинг через `text-search-doc` (одна модель).
- При similarity-поиске по свободному тексту (UC2 «найти статьи KB по запросу пользователя») — embedding запроса формируется через `text-search-query`, поиск — против векторов, рассчитанных через `text-search-doc`.

Это закрывается отдельным архитектурным решением — см. **ADR-010** (выбор моделей + правила использования).

## API endpoint и контракт

- **URL:** `https://llm.api.cloud.yandex.net/foundationModels/v1/textEmbedding`
- **Method:** POST
- **Auth:** `Authorization: Api-Key <key>` (рекомендация для PoC) или `Authorization: Bearer <iam-token>` (TTL 12h, требует процедуры обновления — для prod).
- **Body:**
  ```json
  {
    "modelUri": "emb://<folder-id>/text-search-doc/latest",
    "text": "..."
  }
  ```
- **Response:**
  ```json
  {
    "embedding": [...256 float...],
    "numTokens": "14",
    "modelVersion": "06.12.2023"
  }
  ```
- **Empty text → error:** `{ "error": "...empty text", "code": 3, "message": "..." }`. UC1 должен фильтровать пустые/слишком короткие тексты до отправки (BR в WhitelistEnforcer / CompositeTextComposer).

## Лимиты

- **Документ:** не вытащено через `yc ai foundation-models embedding list` — команда не реализована в текущей версии CLI (`Unknown command 'ai foundation-models embedding list'`).
- **Эмпирически (требует верификации):** typically YC FM имеет ограничение порядка 8000 токенов на запрос для embedding-моделей; rate limit зависит от квоты folder'а. Уточнить — в консоли (`https://console.yandex.cloud → Foundation Models → quota`).
- **Batch API:** через REST `textEmbedding` обрабатывает один текст за вызов. Для batch-векторизации десятков тысяч объектов — параллельные запросы в N потоков с уважением rate-limit'а (точное N — open question, замеряется на iter 1).

## Цена

**Закрыто RES-003 — см. [yc-pricing.md](yc-pricing.md).**

Краткая выжимка (тариф действует с 2026-05-01):

- **Эмбеддинг текста: 0,0101 ₽ за 1 тыс. юнитов** (плоско на всё семейство `text-search-doc/query`).
- Полная векторизация медианного тенанта (100 тыс. объектов × 200 токенов): **≈ 200 ₽**. Верхняя граница (10 млн × 500 токенов): **≈ 50 500 ₽**.
- Rough estimate из предыдущей версии этой страницы (4–20 тыс. ₽) был на 2 порядка выше — он считался по тарифам генеративных моделей. **Бюджетного риска для PoC нет.**

Калькулятор, расчёт реиндексации при смене модели (ADR-007) и тарифы LLM/Translate/Classification — в `yc-pricing.md`.

## Аутентификация — практическое (верифицировано)

Использован **API-Key** (static, без TTL — требует ручной ротации):

```bash
# Создан 2026-05-01:
SA_ID=aje98ipgmpnhaun6ov6e   # pg-vector-poc service account
KEY_ID=...                   # сохранён в .secrets/yc-api-key.json
ROLE=ai.languageModels.user  # на folder applied-office (b1g249mrsql00khlmvcs)
```

Секреты — в `.secrets/yc-api-key.json` (chmod 600), credentials в `.env` (gitignored). Для production — IAM-token (NFR-005 ротации).

## Open questions (после live-данных — обновлено)

| # | Вопрос | Адресат | Статус |
|---|--------|---------|--------|
| OQ-1 | Точная цена за 1k токенов для `text-search-doc` и `text-search-query` | Демьянов (ручная сверка в браузере) | **закрыт** RES-003 / yc-pricing.md (0,0101 ₽ / 1 тыс. юнитов; вопрос «юнит = токен?» перенесён туда как OQ-9) |
| OQ-2 | Лимит RPS / токенов на запрос для embedding API | DevOps (квота folder'а) | open |
| OQ-3 | Batch API — есть ли альтернатива одному запросу за раз | Демьянов / yc-доки | open |
| OQ-4 | Сетевая связность стенда `llm2` → `llm.api.cloud.yandex.net` | Сахабетдинов | задача OWNER-001 (часть) |
| OQ-5 | Стратегия ротации API-Key в production | DevOps (runbook) | задача DEVOPS |
| OQ-6 | Asymmetric vs symmetric: использовать оба URI или один? | SA → ADR-010 | **закрыт** ADR-010 |
| OQ-7 | Минимальный текст для эмбеддинга (empty text → error) | BA | задача BA — добавить в whitelist/composer контракт |
| OQ-8 | Multi-model совместимость (если параллельно ведём `text-search-doc` и `text-search-query` для разных use case) | SA | покрыто ADR-010 |

## Источники

| URL | Статус | Дата |
|-----|--------|------|
| `https://llm.api.cloud.yandex.net/foundationModels/v1/textEmbedding` | ✅ live (smoke 2026-05-01) | 2026-05-01 |
| `yc iam api-key create` | ✅ работает | 2026-05-01 |
| `yc ai foundation-models embedding list` | ❌ Unknown command (CLI 0.140.x) | 2026-05-01 |
| `https://yandex.cloud/ru/docs/foundation-models/concepts/embeddings` | ❌ редирект на `aistudio.yandex.ru` (CAPTCHA) | 2026-05-01 |
| `https://yandex.cloud/ru/docs/foundation-models/pricing` | ❌ редирект на `aistudio.yandex.ru` (CAPTCHA) | 2026-05-01 |
| `https://yandex.cloud/ru/docs/iam/concepts/authorization/iam-token` | ✅ доступен (другой хост) | 2026-05-01 |

## Refresh procedure

При следующей сверке:
1. Повторить smoke-curl (см. секцию «API endpoint») с тестовой фразой → проверить, что `numTokens` и `embedding_len=256` стабильны.
2. Запустить `yc ai --help` — проверить, не появилась ли команда `embedding list` в новой версии CLI.
3. Если появятся новые модели — обновить таблицу.
4. Цены — ручная сверка через браузер.
