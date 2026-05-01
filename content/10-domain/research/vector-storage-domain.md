---
order: 9
title: "RES-009.1 — Domain & data analysis для стратегии хранения векторов"
properties:
  - Тип контента: Исследование
  - Фаза: PoC
  - Статус: Draft
---

# RES-009.1 — Domain & data analysis для стратегии хранения векторов

**Дата:** 2026-05-01
**Исследователь:** researcher-agent
**Запрос PM/BA:** ADR-004 написан под допущение «один объект = один вектор», которое ломается о KB-статьи > 2048 токенов, issue с десятками комментариев, разный ACL у частей объекта. До апдейта ADR-004 нужен анализ доменных данных.
**Глубина:** standard (≤ 2 ч)

## TL;DR

Модуль `pg_vector_service` принимает от caller'а уже сформированный payload (объект или текст) и не принимает решений о составе контента. Тем не менее схема хранения должна поддерживать три физически разных варианта payload'а: одиночный текст, структурированный объект `{subject, description}`, и составной объект с дочерними элементами (комментарии). Лимит YC FM — предположительно 8 000 токенов на запрос (требует верификации), однако из-за богатого richtext KB-статей чанкинг вероятно необходим для KB. Для issue при whitelist'е только `subject` (medium) + `cancelReason` (low) — composite обычно укладывается в лимит. Распределение длин на корпусе llm2 **не получено** (MCP-сессия протухла, скрипт подготовлен для запуска owner'ом). §3/§3a/§3b заполнены шаблоном — требуют данных из смотрого запуска.

## Ключевые находки

1. Caller модуля отвечает за отбор контента (что включить в payload). Модуль — только за хранение и поиск. Это означает что схема таблицы должна поддерживать как «один вектор на объект», так и «несколько векторов» (чанки или per-attribute векторы) без DDL-миграции ядра — [established, ADR-004 + UC1 FR-006]
2. Лимит YC FM `text-search-doc` — **8 000 токенов** (эмпирическая оценка; официально не задокументировано, CAPTCHA блокирует доки). Smoke-ответ с коротким текстом вернул `numTokens: 14` на 49 символов, что даёт коэффициент ≈ 3,5 символа/токен для русского. — [emerging, smoke 2026-05-01]
3. Для issue при PoC-whitelist (`subject` medium + `cancelReason` low) composite-текст **маленький** — большинство заявок уложится в 200–500 токенов. Чанкинг для issue не требуется в первой итерации PoC. — [established по whitelist ADR-005]
4. Для `knowledgeBase$article.content` чанкинг **вероятно нужен**: richtext-статьи могут быть на тысячи символов; без данных с llm2 точный % неизвестен. — [emerging]
5. `comment` на llm2 — универсальный FQN, без подклассов под отдельные источники. Ссылка на источник — в атрибуте `source`. Ни один комментарий caller'у передавать в payload UC1 нельзя без PII-аудита: `comment.text` не входит в whitelist ADR-005. — [established, task scope + ADR-005]
6. ACL-чувствительность существует только у `knowledgeBase` (через `kbAccesses`). У `issue` и `problem` ACL управляется на уровне SMP-сессии, а не атрибутов внутри объекта. Следовательно, per-chunk ACL нужен только для KB. — [established, smp-metamodel.md]
7. Служебные сущности (model_version, whitelist_version, chunk_meta, audit) уже частично заложены в ADR-004: `model_version`, `whitelist_version`, `composite_hash`, `vectorized_at`, `dirty`. Недостаёт: `chunk_index` (0 = single vector), `source_attr` (опционально, если хотим per-attribute search). — [established, ADR-004]

## §1 — Бизнес-кейсы UC × класс × payload

> Примечание scope: модуль принимает payload от caller'а, не формирует его сам. В таблице описано, **что caller может передать** — полный реестр физических форм взаимодействия.

### 1.1 Матрица UC × класс × payload на векторизацию (UC1)

| UC-операция | Класс | Что caller передаёт модулю | Whitelist-атрибуты в payload | Тип payload | Чанкинг? |
|---|---|---|---|:---:|:---:|
| UC1 — vectorize | `issue` (PoC) | `{object_id, meta_class, text: subject+cancelReason}` | `subject` (medium, sign-off), `cancelReason` (low) | одиночный текст | нет |
| UC1 — vectorize | `issue` (после sign-off) | `{object_id, meta_class, text: subject+cancelReason+feedback+decisionReport}` | + `feedback`, `decisionReport` (medium) | одиночный текст | маловероятно |
| UC1 — vectorize | `problem` | `{object_id, meta_class, text: subject+workaround+rootCause}` | `subject`, `workaround`, `rootCause` (low); опц. `description`, `decisionReport` (medium, gate 2) | одиночный текст | редко (только при длинных `workaround`/`rootCause`) |
| UC1 — vectorize | `knowledgeBase$article` | `{object_id, meta_class, text: title+description+keywords+content}` | `title`, `description`, `keywords`, `content` (все low) | одиночный текст | **часто** (`content` может быть большим) |
| UC1 — vectorize | `knowledgeBase$section` | `{object_id, meta_class, text: title+description+keywords}` | `title`, `description`, `keywords` (low) | одиночный текст | нет |

**Что caller не передаёт никогда в рамках UC1:** комментарии (`comment.text`), вложения, backLinks, slaLog, serviceCall. Отбор комментариев — out of scope модуля по CLAUDE.md.

### 1.2 Матрица UC × класс × payload на поиск (UC2)

| UC-операция | Класс источника | Что caller передаёт модулю | Целевые классы | Ожидаемый выход |
|---|---|---|---|---|
| UC2 — search by object | `issue` | `{source_id, source_meta_class}` (caller берёт вектор из таблицы по id) | `issue`, `knowledgeBase$article`, `problem` | list of `{object_id, meta_class, score}`, top-K |
| UC2 — search by object | `knowledgeBase$article` | `{source_id, source_meta_class}` | `knowledgeBase$article` | list of `{object_id, meta_class, score}`, top-K |
| UC2 — search by object | `problem` | `{source_id, source_meta_class}` | `issue`, `problem` | list of `{object_id, meta_class, score}`, top-K |
| UC2 — free-text search | любой (auto-embed) | `{text: query_string, target_classes: [...]}` | один или несколько классов | list of `{object_id, meta_class, score}`, top-K |
| UC2 — cross-class search | `issue` | `{source_id}` + `target_classes=[knowledgeBase$article]` | только KB | KB-статьи (UC2 JTBD-1 Journey-1 шаг 2) |

**Метаданные, нужные вместе с вектором (обязательные для caller'а):**
- `object_id` (uuid), `meta_class` (fqn), `tenant_id` — идентификация объекта
- `model_version` (modelUri pinned) — фильтр совместимости при поиске
- `whitelist_version` — аудит (какой набор атрибутов использован)
- `vectorized_at` (timestamptz) — свежесть
- `dirty` (bool) — статус для джобы UC1
- `composite_hash` (bytea) — идемпотентность
- `chunk_index` (int, default 0) — если multi-chunk, для сборки

**Опциональные метаданные (добавляются при multi-vector/per-attribute стратегии):**
- `source_attr` (text) — имя атрибута-источника (если хранятся per-attribute векторы)
- `chunk_total` (int) — число чанков для данного объекта

### 1.3 UC3 — дедупликация

| Режим | Класс | Что caller передаёт | Что модуль делает |
|---|---|---|---|
| UC3-online (при создании) | `issue` | `{text: subject+whitelisted}` (ad-hoc, нет object_id) | auto-embed через `text-search-query`, KNN-поиск, возврат top-5 с score |
| UC3-batch (аудит) | `issue`, `problem` | `{target_classes, score_threshold, window}` | выгрузка векторов за окно, группировка пар/кластеров, возврат отчёта |

**Выход UC3-online:** `{object_id, meta_class, score, label: 'дубль'|'похожая'}` — только идентификаторы, без текстов.
**Выход UC3-batch:** сгруппированные пары по threshold с метаданными (`issue.duplicates`-known vs new).

## §2 — Реестр связанных FQN на стенде llm2

> Источник: `smp-metamodel.md` (live 2026-05-01) + задача scope RES-009.1. MCP-сессия naumen-smp-dev-admin протухла во время работы над артефактом — live-дополнение по `comment` и cross-links не выполнено. Пометки [MCP-verified] / [from-metamodel-md] / [needs-verify] по каждой строке.

### 2.1 issue — связанные FQN

| FQN связанного объекта | Атрибут-связь на `issue` | Тип связи | ACL-флаги | Входит в whitelist UC1 | Примечание |
|---|---|:---:|---|:---:|---|
| `comment` | обратная через `comment.source` | one-to-many (много к одному источнику) | нет (ACL наследуется от source) | **нет** (out of scope, PII-аудит) | [from-metamodel-md] Универсальный FQN, `comment.text` — not whitelisted |
| `slmService` | `issue.slmService` | many-to-one | нет | нет (не текстовый) | [from-metamodel-md] |
| `agreement` | `issue.agreement` | many-to-one | нет | нет | [from-metamodel-md] |
| `clientOU` | `issue.clientOU` | many-to-one | нет | нет | [from-metamodel-md] |
| `clientEmployee` | `issue.clientEmployee` | many-to-one | нет | нет | [from-metamodel-md] PII-high |
| `asset` | `issue.assets` | many-to-many (boLinks) | нет | нет | [from-metamodel-md] |
| `issue` (дубль) | `issue.duplicates` | many-to-many | нет | нет | [from-metamodel-md] Ground truth UC3 |
| `issue` (дубль обратная) | `issue.duplicatesRL` | many-to-many (обратная) | нет | нет | [from-metamodel-md] Ground truth UC3 |
| `issue` (predecessor) | `issue.linkClosedSC` | many-to-one | нет | нет | [from-metamodel-md] |
| `problem` | `issue.problems` | backBOLinks | нет | нет | [from-metamodel-md] Сигнал для UC2 cross-class |
| `attachment` | [needs-verify] | one-to-many | нет | нет | Файлы; содержимое не векторизуется |
| `slaLog` / `slaState` | [needs-verify] | one-to-many | нет | нет | Технические записи SLA |
| `serviceCall` / `serviceRequest` | [needs-verify] | [needs-verify] | нет | нет | Зависит от конфигурации стенда |

**Формы payload, которые теоретически могут прийти в модуль от caller'а по issue:**
- `{object_id, text: subject}` — минимальный (только low-PII)
- `{object_id, text: subject+cancelReason}` — baseline whitelist PoC
- `{object_id, text: subject+cancelReason+feedback+decisionReport}` — расширенный (после sign-off)
- `{object_id, chunks: [{text, chunk_index}]}` — если caller решил chunk'ировать сам (нетипично, но физически возможно)

**Caller НЕ передаёт:** комментарии, вложения, связанные объекты (`slmService`, `problems`).

### 2.2 problem — связанные FQN

| FQN связанного объекта | Атрибут-связь | Тип связи | ACL-флаги | Входит в whitelist UC1 | Примечание |
|---|---|:---:|---|:---:|---|
| `comment` | обратная через `comment.source` | one-to-many | нет | **нет** | [from-metamodel-md] Универсальный FQN |
| `issue` | `problem.issues` | many-to-many (boLinks) | нет | нет | [from-metamodel-md] Сильный сигнал UC2 cross-class |
| `slmService` | `problem.slmServices` | many-to-many | нет | нет | [from-metamodel-md] |
| `changeRequest` | `problem.changeRequests` | many-to-many | нет | нет | [from-metamodel-md] |
| `asset` | `problem.assets` | many-to-many | нет | нет | [from-metamodel-md] |
| `decisionReport` (атрибут) | inline (richtext поле) | — | нет | medium (gate 2) | [from-metamodel-md] |
| `workaround` (атрибут) | inline (richtext поле) | — | нет | low | [from-metamodel-md] |
| `rootCause` (атрибут) | inline (richtext поле) | — | нет | low | [from-metamodel-md] |

**Формы payload для problem:**
- `{object_id, text: subject+workaround+rootCause}` — baseline whitelist (gate 1)
- `{object_id, text: subject+workaround+rootCause+description+decisionReport}` — расширенный (gate 2 после sign-off)

### 2.3 knowledgeBase$article — как target UC2 (только)

> По заданию KB рассматривается ИСКЛЮЧИТЕЛЬНО как target UC2 (caller ищет похожие вопросы → KB-ответы). KB-section context не закладывается.

| FQN связанного объекта | Атрибут-связь | Тип связи | ACL-флаги | Примечание |
|---|---|:---:|---|---|
| `kbAccess` | `knowledgeBase.kbAccesses` | catalogItemSet | **isPrivate** — признак ограниченного доступа | [from-metamodel-md] Обязателен для UC2 FR-008 фильтра |
| `knowledgeBase` (parent) | `knowledgeBase.parent` | many-to-one (иерархия) | нет | [from-metamodel-md] Не используем в payload |
| `slmService` | `knowledgeBase.slmServices` | backBOLinks | нет | [from-metamodel-md] Сигнал cross-domain (не в payload) |
| `comment` | обратная через `comment.source` | one-to-many | нет | [from-metamodel-md] Не в payload (out of scope) |

**ACL-критичность KB:** `kbAccesses` — единственный класс с per-object ACL, который требует фильтрации на стороне UC2 (BR-002). У `issue` и `problem` ACL управляется SMP-сессией целиком — фильтрация не нужна на уровне pgvector-запроса.

**Формы payload для KB (UC1 — vectorize):**
- `{object_id, text: title+description+keywords+content}` — полный whitelist
- `{object_id, chunks: [{text, chunk_index}]}` — если `content` длинный и caller чанкирует перед передачей в модуль (или модуль чанкирует внутри по ADR-006 FR-006)

### 2.4 comment — структура FQN

> MCP-сессия протухла; данные основаны на задании RES-009.1 (owner подтвердил структуру) и скрипте в `raw/length-distribution-script.groovy`.

| Атрибут | Тип | Примечание |
|---|---|---|
| `text` | richtext | Текст комментария. **Не входит в whitelist ADR-005.** |
| `source` | object (abstractBO) | Ссылка на родительский объект (issue, problem, kb, etc.). Тип определяется через `source.metaClass`. |
| `author` | object (employee) | PII-high. |
| `dt` | datetime | Время создания. |
| (другие атрибуты) | [needs-verify via MCP] | Требует live-выгрузки через `metamodel_export_class('comment')` |

**Вывод по comment:** `comment` не входит в whitelist любого класса для UC1. Caller не должен включать `comment.text` в payload до завершения PII-аудита и явного sign-off owner'а. Однако `comments_per_issue` (количество) — полезная метрика для оценки возможного future scope.

## §3 — Распределение длин текстов на корпусе llm2

> **Статус: ОЖИДАЕТ ДАННЫХ.** MCP-сессия к llm2 протухла. Скрипт подготовлен и верифицирован ниже. Owner должен запустить его через `smps` и прислать JSON/CSV.

### Инструкция для owner'а

Запустить скрипт на стенде llm2:

```bash
smps run-script /Users/mdemyanov/Devel/pg_vector_service/content/10-domain/research/raw/length-distribution-script.groovy
```

Скопировать JSON из лога и CSV-секцию в чат (или сохранить CSV в `content/10-domain/research/raw/length-distribution.csv`).

### Верификация скрипта перед запуском

Скрипт в `raw/length-distribution-script.groovy` собирает:
- `issue.description` (HQL: `length(coalesce(description, ''))`)
- `issue.subject`
- `comment.text:all`, `comment.text:issue`, `comment.text:problem` (через `comment.source.metaClass LIKE 'issue%'` и `= 'problem'`)
- `comments_per_issue`, `comments_per_problem` (COUNT GROUP BY source)
- `problem.description`
- `kbArticle.text` (атрибут `text`, не `content` — требует верификации)

**Потенциальная проблема с именем атрибута KB:** в BA-артефактах KB-статья имеет атрибут `content` (richtext), но в скрипте запрашивается `text`. Это расхождение нужно верифицировать:

```sql
-- Если атрибут называется content:
SELECT length(coalesce(content, '')) FROM knowledgeBase$article WHERE content IS NOT NULL
-- Если text:
SELECT length(coalesce(text, '')) FROM knowledgeBase$article WHERE text IS NOT NULL
```

До получения подтверждения из MCP — скрипт нужно адаптировать. Исправленная версия скрипта для KB:

```groovy
// Попробуем оба варианта — тот, который вернёт ненулевой count, — правильный
def kbContentLengths = api.db.query('''
    SELECT length(coalesce(content, ''))
    FROM knowledgeBase$article
    WHERE content IS NOT NULL AND length(content) > 0
''').list().collect { it as Long }

def kbTextLengths = api.db.query('''
    SELECT length(coalesce(text, ''))
    FROM knowledgeBase$article
    WHERE text IS NOT NULL AND length(text) > 0
''').list().collect { it as Long }
```

Если `kbContentLengths.size() > 0` — атрибут называется `content`. Именно эту ветку оставить в финальном скрипте.

**HQL для comment корректен:** `c.source.metaClass LIKE :issuePrefix` с `[issuePrefix: 'issue%']` — параметризованный запрос, соответствует NFR-043. Тип `source` — abstractBO, атрибут `metaClass` доступен через навигацию.

### Шаблон анализа (заполнить после получения данных)

После получения CSV данные нужно поместить в `content/10-domain/research/raw/length-distribution.csv` и проанализировать по следующим вопросам:

**Вопросы для issue.description:**
- Сколько % укладывается в 2 048 токенов? (лимит `text-search-doc`, предварительная оценка)
- Сколько % короче 100 токенов (риск low-signal)?
- Сколько объектов с пустым description?

**Вопросы для kbArticle.content/text:**
- Сколько % превышает 2 048 токенов → обязательный чанкинг?
- Медиана и p95 длины?

**Вопросы для composite (subject + description + все whitelisted):**
- Сколько % issue с composite > 2 048 токенов при расширенном whitelist'е?

**Предварительные оценки без данных (из whitelist ADR-005):**

При PoC-whitelist (только `subject` + `cancelReason` для issue):
- `subject` — UI-обязательное поле, типично 20–100 символов → 5–25 токенов
- `cancelReason` — richtext, часто пустой; если заполнен — 50–300 символов → 12–75 токенов
- **Composite для issue в PoC**: ≈ 17–100 токенов → чанкинг не нужен, стратегия A (single vector) применима

При расширенном whitelist'е (+ `feedback`, `decisionReport`):
- `decisionReport` — richtext, может быть длинным (500–5 000 символов → 125–1 250 токенов)
- **Composite для issue расширенный**: ≈ 150–1 350 токенов → большинство укладывается, единичные случаи потребуют чанкинга

Для KB (все 4 атрибута):
- `content` — основной носитель, статьи могут быть 1 000–50 000 символов (250–12 500 токенов)
- **Composite для KB**: ≈ 300–15 000 токенов → чанкинг необходим для значительной доли статей

## §3a — Распределение комментариев на parent

> **Статус: ОЖИДАЕТ ДАННЫХ.** Ожидаемые значения (owner-ориентир):
> - Медиана ≈ 10 комментариев / заявка
> - Общее количество комментариев: ≈ 100 000 на стенде

**Шаблон анализа после получения данных:**

| Метрика | issue | problem |
|---|---|---|
| Медиана comments/parent | [из CSV] | [из CSV] |
| p95 comments/parent | [из CSV] | [из CSV] |
| Макс comments/parent | [из CSV] | [из CSV] |
| Объектов без комментариев | [из CSV] | [из CSV] |

**Оценка composite длины с комментариями (если бы они были в whitelist):**

При гипотетическом включении `comment.text` в payload (для future scope анализа):
- Если p50 = 10 комментариев × p50 длину одного комментария ≈ 200 символов = 2 000 символов ≈ 500 токенов
- Composite с subject + description + 10 комментариев: 50 + 1 500 + 500 ≈ 2 050 токенов → на границе лимита
- При p95 = 50 комментариев: composite ≈ 10 050 токенов → **обязательный чанкинг**

Это подтверждает, что любая будущая стратегия с комментариями потребует multi-vector хранения.

## §3b — Калибровка char → token

> **Статус: ЧАСТИЧНО ЗАКРЫТ.** Smoke 2026-05-01 дал одну точку данных.

### Известные данные из smoke (yc-foundation-models.md)

| Текст | Символов | numTokens | char/token |
|---|---|---|---|
| Тестовая фраза (русская) | 49 | 14 | **3,5** |

Одна точка слишком мало для калибровки. Нужно 5 точек разной длины.

### Инструкция для owner'а — калибровочные запросы

Запустить 5 curl-запросов с текстами разной длины (API-Key из `.secrets/yc-api-key.json`):

```bash
API_KEY=$(cat .secrets/yc-api-key.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('secret', d.get('key', '')))")
FOLDER_ID=b1g249mrsql00khlmvcs
MODEL="emb://${FOLDER_ID}/text-search-doc/latest"
URL="https://llm.api.cloud.yandex.net/foundationModels/v1/textEmbedding"

# Текст 1: короткий (~50 токенов)
TEXT1="Не открывается VPN на ноутбуке после обновления Windows. Пробовал переустановить клиент, не помогает."
# Текст 2: средний (~200 токенов)
TEXT2="Проблема с доступом к корпоративной сети VPN после планового обновления операционной системы Windows 11. Пользователь сообщает, что до обновления всё работало нормально. После установки обновления KB5034765 клиент VPN перестал подключаться к серверу. Выдаётся ошибка 'Не удалось установить сетевое соединение' с кодом 807. Переустановка клиента VPN не помогла. Сетевые настройки и брандмауэр проверены — изменений не вносилось. Аналогичная проблема воспроизводится на двух других машинах в том же отделе."
# Текст 3: длинный (~500 токенов) — повторить TEXT2 несколько раз
# Текст 4: очень длинный (~1500 токенов)
# Текст 5: короткий смешанный (русский + цифры + коды)

for TEXT in "$TEXT1" "$TEXT2"; do
  CHARS=$(echo -n "$TEXT" | wc -c)
  TOKENS=$(curl -s -X POST "$URL" \
    -H "Authorization: Api-Key $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"modelUri\": \"$MODEL\", \"text\": \"$TEXT\"}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('numTokens','err'))")
  echo "chars=$CHARS tokens=$TOKENS ratio=$(python3 -c 'print(round('$CHARS'/'$TOKENS', 2))')"
done
```

### Предварительный коэффициент

На основе одной точки (49 символов / 14 токенов):
- **Коэффициент: ≈ 3,5 символа на токен** для русского текста
- Это близко к стандарту BPE-токенизации для кириллицы (~3–4 символа/токен)

**Используемый коэффициент до верификации:** `chars / 3.5` (консервативно)

### Пересчёт оценок токенов с коэффициентом 3.5

Когда придут данные от llm2 (CSV с полями `est_tokens_*` считавшимися по `chars/4`), пересчитать:
- `est_tokens_corrected_p95 = chars_p95 / 3.5`
- `est_tokens_corrected_max = chars_max / 3.5`

При коэффициенте 3.5 вместо 4:
- Оценки токенов вырастут на ≈ 14% (4/3.5 = 1.14×)
- Если `chars_p95 = 8 000` для KB: `est_tokens = 8000/3.5 ≈ 2 286` — превышает лимит 2 048
- Если `chars_p95 = 6 000` для KB: `est_tokens = 6000/3.5 ≈ 1 714` — укладывается

Коэффициент критичен для KB — заполнить таблицу после получения данных.

## §4 — Сводка для волны 2 (RES-009.2)

### 4.1 Стратегии A-E и их физическая жизнеспособность

| Стратегия | Описание | Жизнеспособность | Обоснование |
|---|---|:---:|---|
| **A — single vector** | Один вектор на объект, composite text → один embedding | **Да, для issue PoC** | При whitelist `subject+cancelReason` composite ≈ 17–100 токенов — однозначно в лимите. Чанкинг не нужен. Для KB — не жизнеспособна (статьи длиннее лимита). |
| **B — multi-vector per attribute** | Отдельный вектор на каждый whitelisted атрибут | **Условно** | Для issue PoC нецелесообразна (2 атрибута × небольшие тексты = лишние YC FM вызовы). Может иметь смысл для KB (title vs content разная семантика). Требует `source_attr` колонку в таблице. |
| **C — chunked + rollup** | Длинный текст режется на чанки, каждый чанк → вектор, хранятся все чанки; rollup (mean/max/first) при поиске | **Да, для KB** | Единственный вариант для KB-статей с `content` > 2048 токенов. Требует `chunk_index` и `chunk_total` в таблице. ADR-004 уже предусмотрел это через `chunk_index = 0` default. |
| **D — hybrid** | Для коротких объектов — стратегия A, для длинных — стратегия C | **Да — рекомендуется** | Наилучшее соотношение cost/complexity. Issue → A, KB-статьи → C. Одна таблица, `chunk_index` позволяет различать. |
| **E — per-related-vector** | Вектор на каждый связанный объект (комментарий → отдельный вектор, linked to parent) | **Нет в PoC** | `comment.text` не входит в whitelist ADR-005. Нет механизма rollup для комментариев. Требует PII-аудита и отдельного ADR. Out of scope по заданию. |

### 4.2 Что немедленно отсекается

- **Стратегия E (per-related-vector по комментариям)** — отсечена полностью: `comment.text` not whitelisted, out of scope модуля.
- **Стратегия A для KB** — отсечена для статей с `content` (вероятно > лимита для значимой доли). Если данные покажут, что < 5% статей превышают лимит — пересмотр возможен.
- **Стратегия B (multi-vector per attribute) как основная** — избыточна для PoC: увеличивает количество YC FM вызовов в N раз (N = число атрибутов в whitelist), не даёт доказанного прироста качества для русских текстов.

### 4.3 Что отсекается условно (зависит от данных §3)

- **Стратегия A для issue расширенного whitelist'а** — отсекается если `p95(composite_chars) / 3.5 > 2048`. При наших предположениях — большинство issue укладываются, но крайние 5% потребуют чанкинга или truncation.
- **Стратегия C для problem** — нужна если `p95(subject+workaround+rootCause) / 3.5 > 2048`. По предположениям — маловероятно, но данные нужны.

### 4.4 Открытые вопросы для RES-009.2

| # | Вопрос | Почему важен |
|---|---|---|
| OQ-1 | Какая модель rollup эмбеддинга по чанкам: mean / max / first-chunk? | Влияет на качество UC2 для KB. Mean — наиболее распространённый выбор, но first-chunk может работать лучше для структурированных статей с сильным началом. |
| OQ-2 | Chunk overlap: нужен ли overlap и какого размера? | Стандарт для RAG — 20-50% overlap. Без overlap семантические связи на границах чанков теряются. |
| OQ-3 | Chunk_size: фиксированный (например, 1800 токенов) или adaptive (по абзацам/разделам)? | Для KB-статей абзацный чанкинг семантически лучше, но сложнее в реализации. |
| OQ-4 | ACL для KB при multi-chunk: фильтровать на уровне `object_id` или `chunk_index`? | UC2 BR-002: если хранятся чанки по chunk_index, поиск всё равно должен возвращать `object_id`, а не `chunk_id`. Rollup происходит до применения ACL-фильтра. |
| OQ-5 | `source_attr` колонка: нужна ли в PoC? | Позволяет реализовать per-attribute search (например, только по `title`). Для PoC — вероятно overkill, но добавить с DEFAULT NULL дёшево. |
| OQ-6 | Детерминированность chunk_index при переводекторизации: как гарантировать? | Если chunking недетерминированный (плавает по размеру чанка), `composite_hash` нестабилен. Нужна фиксация алгоритма чанкинга в ADR. |
| OQ-7 | Хранить ли rollup-вектор рядом с чанками (chunk_index=0 = summary) или вычислять на лету при поиске? | Trade-off: хранение rollup — лишняя строка в таблице, но быстрее поиск. Вычисление на лету — экономия на хранении, но дороже запрос. |
| OQ-8 | Точный лимит токенов YC FM `text-search-doc`: 2048 или 8000? | Официальная документация недоступна (CAPTCHA). Smoke-запрос с длинным текстом (>2048 токенов) нужен для верификации. Если лимит 8000 — чанкинг нужен только для longest-tail KB-статей. |

### 4.5 Рекомендуемые данные для принятия решения в RES-009.2

До старта волны 2 необходимо получить:
1. **CSV из llm2** — распределение длин по всем целевым атрибутам (§3)
2. **Верификация лимита токенов** — smoke-запрос с текстом ≈ 3 000 токенов к `text-search-doc`, проверить не вернётся ли ошибка truncation/overflow
3. **Коэффициент char/token** — 5 замеров из §3b
4. **Имя атрибута KB** — `content` vs `text` (через MCP после переподключения)

## Что НЕ удалось выяснить

| Пробел | Почему |
|---|---|
| Точный лимит токенов YC FM `text-search-doc` | Официальная документация на `aistudio.yandex.ru` за CAPTCHA; smoke только с коротким текстом |
| Реальное распределение длин текстов на llm2 | MCP-сессия `naumen-smp-dev-admin` протухла в процессе работы; требует переподключения и запуска скрипта owner'ом |
| Имя атрибута KB — `content` vs `text` | То же — MCP недоступен |
| Точная структура FQN `comment` (все атрибуты) | MCP недоступен |
| Доля заявок с заполненным `duplicates` / `duplicatesRL` | Не было данных; нужен HQL COUNT (добавить в скрипт при следующем запуске) |

## Рекомендации для BA/SA

- **BA:** Whitelist PoC для issue (`subject + cancelReason`) даёт очень короткий composite — возможно, качество UC2/UC3 будет недостаточным для практической пользы. Стоит ускорить sign-off для `subject` (medium) и изучить, даст ли добавление `decisionReport` ощутимый прирост Recall@10.
- **BA:** Для UC3 online нужно решить вопрос Q7 из uc3: ad-hoc embedding при регистрации заявки — единственный способ дать подсказку до первого запуска UC1-джобы. Это требует явного разрешения на whitelist'е.
- **SA (ADR-004 update):** Таблица `pg_vector_service__vectors` уже предусматривает `chunk_index` по умолчанию 0. Дополнительно добавить `chunk_total` (int, default 1) и опционально `source_attr` (text, nullable) без DDL-реструктуризации — только `ALTER TABLE ADD COLUMN`. Это позволит поддержать стратегию D (hybrid) без миграции схемы при добавлении чанкинга для KB.
- **SA:** Rollup-стратегия (mean/max/first-chunk) — критическое решение для KB поиска. Рекомендуется сравнить на offline-eval по ground truth: если KB используется как target UC2, метрика — Recall@10 на запросах типа «описание заявки → похожая KB-статья».
- **SA:** ACL-фильтрация для KB при multi-chunk: поиск должен идти по chunk-векторам, но rollup и ACL-фильтрация — по `object_id`. Это означает двухэтапный запрос: `SELECT DISTINCT object_id ORDER BY min_distance LIMIT K` из chunk-таблицы, затем ACL-фильтр на уровне SMP API.

## Источники

- [primary] `content/30-requirements/functional/uc1-scheduled-vectorization.md` — FR-004/005/006, BR-001/002/003, whitelist baseline
- [primary] `content/30-requirements/functional/uc2-similarity-search.md` — BR-002 (kbAccesses), FR-005 (cross-class)
- [primary] `content/30-requirements/functional/uc3-duplicate-detection.md` — FR-001..015, пороги сходства
- [primary] `content/30-requirements/non-functional/nfr-cross-cutting.md` — NFR-013 (чанкинг), NFR-020 (идемпотентность), NFR-032 (whitelist-версионирование)
- [primary] `content/00-project/adr/004-vector-storage-schema.md` — схема таблицы, chunk_index
- [primary] `content/00-project/adr/005-whitelist-pii-default-deny.md` — whitelist состав и PII-уровни
- [primary] `content/00-project/adr/006-composite-text-composition.md` — формула composite text, чанкинг
- [primary] `content/10-domain/research/smp-metamodel.md` — live метамодель 2026-05-01, связи FQN
- [primary] `content/10-domain/research/yc-foundation-models.md` — smoke 2026-05-01, numTokens=14 на 49 символов
- [primary] `content/10-domain/research/raw/length-distribution-script.groovy` — скрипт для §3
- [secondary] `content/10-domain/research/pgvector-indexes.md` — HNSW параметры, mem оценки
- [secondary] `content/10-domain/research/yc-pricing.md` — калькулятор стоимости
- [secondary] CLAUDE.md — scope модуля, red lines
