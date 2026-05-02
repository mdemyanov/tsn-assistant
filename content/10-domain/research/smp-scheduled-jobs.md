---
order: 7
title: "Naumen SMP — scheduled jobs для векторизации"
properties:
  - Тип контента: Исследование
  - Фаза: PoC
  - Статус: Draft
---

## Резюме

В SMP запуск джоб по расписанию реализуется через встроенный **Scheduler** (планировщик задач) с поддержкой:
- **api.scheduler API** для программного управления расписанием;
- **Периодического выполнения** (daily/weekly/monthly + кастомные интервалы в ms);
- **Одноразовых запусков** по дате/времени;
- **Groovy-скриптов** в контексте джоб без UI-триггеров.

Для векторизации 100k объектов рекомендуется:
1. Одна scheduled task с пакетной обработкой (setMaxResults);
2. Сохранение state маркера «last_vectorized» для идемпотентности;
3. api.tx.call() для обёртки каждого батча и обработки ошибок;
4. Логирование через api.logging в отдельный компонент.

---

## 1. Механизм SMP scheduledTask

### Определение и объявление

**ScheduledTask** (или `scheduledTask$scheduledTask`) — встроенный бизнес-объект SMP, представляющий задачу в планировщике.

**Метаданные объекта:**
- `title` — название задачи (UI)
- `code` — уникальный код задачи (используется в api.scheduler)
- `description` — описание
- `script` — Groovy-скрипт, выполняемый при срабатывании расписания
- Список правил выполнения (triggers/rules) с расписанием

### Конфигурация через интерфейс администратора

Навигация: **"Настройка системы" → "Планировщик задач"**

1. Нажимают "Добавить задачу"
2. Вводят название (код генерируется автоматически или вручную)
3. В поле "Текст" вставляют **Groovy-скрипт**
4. В блоке "Расписание" добавляют правила выполнения

### API управления расписанием

**api.scheduler** — основной API для работы с задачами планировщика.

Ключевые методы:

```groovy
// Получение статуса расписания
api.scheduler.getStatus(uuid)                          // для задачи
api.scheduler.getStatus(uuid, triggerName)             // для конкретного триггера
api.scheduler.getTriggersInfo(uuid, onlyEnabled)       // все триггеры

// Управление триггерами расписания
api.scheduler.setTriggerPeriod(uuid, triggerName, period, strategy, startingDate)
  // period: 'daily', 'weekly', 'monthly', 'yearly'
  // strategy: 'from_start', 'from_last_execution'

api.scheduler.setTriggerInterval(uuid, triggerName, interval, strategy, startingDate)
  // interval: api.types.newDateTimeInterval(3, 'MINUTE')
  // поддерживает: 'SECOND', 'MINUTE', 'HOUR'

api.scheduler.setTriggerDate(uuid, triggerName, date)
  // Одноразовый запуск в дату

api.scheduler.enableTrigger(triggerName)
api.scheduler.disableTrigger(triggerName)

// Запуск и прерывание
api.scheduler.run(uuid)                                // ручной запуск
api.scheduler.interruptJob(uuid)                       // прерывание (Thread Death)

// Удаление
api.scheduler.deleteTask(uuid)
```

### Контекст исполнения скрипта

**Переменные, доступные в коде задачи:**

- `subject` — объект-задача (scheduledTask)
- `api.*` — полный API SMP
- `utils.*` — утилиты (find, edit, delete и т.д.)
- `logger` — объект логирования Log4j

**Пользователь исполнения:**

В документации **не найдено явного указания**, но по практике:
- Джоба исполняется от системного пользователя (System User) или суперпользователя
- `utils.getCurrentUser()` вероятно вернёт специальный системный account
- **ACTION ITEM**: уточнить у Сахабетдинова / Киселёвой, какой пользователь выполняет scheduled job

**Транзакция:**

Скрипт исполняется в контексте **одной транзакции за весь запуск**. Для обработки батчей нужно использовать **api.tx.call()** для создания отдельных транзакций (см. раздел 6).

---

## 2. Альтернативы внутри SMP

### Вариант A: Action Handler (действие по событию)

**Для чего:** Реагировать на события объектов (создание, изменение, смена статуса).

**Минусы для нашего сценария:**
- Работает **только при изменении объекта** (по событию);
- Не подходит для **периодической массовой переобработки** (например, за ночь);
- Не имеет встроенного механизма батчинга.

**Когда использовать:**
- Векторизовать **инкрементально** при создании/изменении объекта (дополнение к scheduled job).

### Вариант B: BPM Task (бизнес-процесс)

**Для чего:** Оркестрация сложных многошаговых процессов с маршрутами и утверждениями.

**Минусы:**
- Излишняя сложность для простой batch-обработки;
- Ориентирован на процессы с участием пользователей;
- Нет встроенного расписания (только события).

**Когда использовать:**
- Если векторизация требует **согласования** или **многоэтапных проверок**.

### Вариант C: Scheduled Task (рекомендуется)

**Для нашего сценария — оптимален:**
- ✅ Периодическое выполнение по расписанию;
- ✅ Полный контроль через Groovy-скрипт;
- ✅ Подходит для batch-обработки 100k объектов;
- ✅ Встроенное логирование.

---

## 3. Контекст исполнения джоб

### Пользователь и авторизация

**ОТКРЫТЫЙ ВОПРОС**: В документации явно не указано, какой пользователь выполняет scheduled task.

По логике SMP, это может быть:
1. Суперпользователь (Superuser)
2. Системный пользователь (System Account)
3. Пользователь, указанный в настройке задачи

**Рекомендация:** Адресовать Сахабетдинову или Киселёвой.

### Транзакция и обработка ошибок

**Модель исполнения:**
- Весь скрипт задачи работает в **одной транзакции**;
- При **необработанной ошибке** транзакция откатывается **полностью**;
- Для **обработки батчей** нужно оборачивать каждый батч в **api.tx.call()**.

**Пример обработки ошибок батча:**

```groovy
def objs = utils.find('knowledgeBase$article', [:])  // 100k объектов
objs.each { obj ->
  try {
    api.tx.call {
      // Векторизация obj (вызов YC FM, сохранение embeddings)
      utils.edit(obj, ['vectorized': true])
    }
  }
  catch (e) {
    logger.error("Failed to vectorize ${obj.uuid}", e)
    // Батч откатывается, остальные объекты продолжают обрабатываться
  }
}
```

---

## 4. Параллелизм и батчинг для больших выборок

### Проблема

Выборка 100k объектов в памяти одновременно → OutOfMemory.

### Решение: Chunked Processing

**HQL с setMaxResults и setFirstResult:**

```groovy
def batchSize = 1000
def offset = 0
def processed = 0

while (true) {
  api.tx.call {
    def query = api.db.query('from knowledgeBase$article where vectorized != true order by uuid')
    query.setFirstResult(offset)
    query.setMaxResults(batchSize)
    def batch = query.list()
    
    if (batch.isEmpty()) return  // Конец обработки
    
    batch.each { obj ->
      try {
        // Векторизация через YC FM
        def embedding = callYCFM(obj.title)
        utils.edit(obj, ['vectorEmbedding': embedding, 'vectorized': true])
        processed++
      }
      catch (e) {
        logger.error("Vectorize failed: ${obj.uuid}", e)
      }
    }
    
    offset += batchSize
    logger.info("Processed batch: $processed total")
  }
}
```

**Параметры:**
- `setMaxResults(1000)` — ограничить результаты
- `setFirstResult(offset)` — смещение (pagination)
- Если setMaxResults < 0, ограничения снимаются (все записи)

### Параллельность внутри одной джобы

**НЕ рекомендуется** (Groovy/Java threading в SMP не документировано):
- Риск deadlock'ов на уровне БД;
- Сложность отладки;
- Проблемы с транзакциями.

**Вместо этого:**
- Создать **несколько независимых scheduled tasks** с разными фильтрами;
- Каждая задача обрабатывает свой subset объектов (например, по range UUID);
- Синхронизация через атрибут `vectorized` или timestamp.

---

## 5. Идемпотентность и защита от повторных запусков

### Проблема

Если scheduled task запустится дважды (сбой + перезапуск), может быть:
- Двойной вызов YC FM API (дубли embeddings);
- Одноразовая тариф использования YC FM × 2.

### Решение: Маркер состояния

**Добавить атрибут к объекту:**

```
vectorized: Boolean = false (default)
vectorizedAt: DateTime  // когда была последняя успешная векторизация
```

**В скрипте джобы:**

```groovy
api.tx.call {
  def query = api.db.query(
    'from knowledgeBase$article where vectorized != true'
  )
  query.setMaxResults(1000)
  def batch = query.list()
  
  batch.each { obj ->
    try {
      // 1. Проверка идемпотентности
      if (obj.vectorized == true) {
        logger.debug("Already vectorized: ${obj.uuid}, skipping")
        return
      }
      
      // 2. Вызов YC FM
      def embedding = callYCFM(obj.title)
      
      // 3. Атомарное сохранение маркера
      utils.edit(obj, [
        'vectorEmbedding': embedding,
        'vectorized': true,
        'vectorizedAt': new Date()
      ])
      
      logger.info("Vectorized: ${obj.uuid}")
    }
    catch (e) {
      logger.error("Fail: ${obj.uuid}", e)
      // Не устанавливаем vectorized=true → повтор при следующем запуске
    }
  }
}
```

---

## 6. Логирование и мониторинг

### Встроенное логирование SMP

**api.logging** — управление уровнями логирования:

```groovy
api.logging.setLogLevel('myVectorizeModule', 'INFO')
api.logging.setLogLevel('myVectorizeModule', 'DEBUG')  // При отладке
```

**Логирование в скрипте:**

```groovy
logger.info("Started vectorization, batch_size=${batchSize}")
logger.warn("Rate limit approaching, pausing...")
logger.error("API call failed for ${uuid}", exception)
```

### Структурированное логирование

Логи попадают в:
- **log4j2** файлы (обычно `/opt/naumen/deploy/*/logs/`)
- Можно настроить отдельный appender для своего модуля

**ОТКРЫТЫЙ ВОПРОС**: Нет встроенного механизма **progress tracking** в UI.

Рекомендуется:
1. Использовать `utils.edit()` для сохранения состояния в атрибут `processingState`:
   ```groovy
   utils.edit(taskObj, ['processingState': "Processed 5000 of 100000"])
   ```
2. Наблюдать **через логи** (grep по файлам);
3. Создать **отдельный ITSM-объект** (Progress Log) для отслеживания.

### Алертинг при падении

**Способ 1: Action Handler на изменение статуса**
Если добавить статус `failed` к задаче при ошибке → action handler отправляет email.

**Способ 2: В конце скрипта**
```groovy
try {
  // ... обработка ...
} catch (e) {
  api.notification.send('admin@company.ru', "Vectorization job failed: ${e.message}")
  logger.error("Fatal error", e)
}
```

---

## 7. Конкретный пример для pg_vector_service

**Типичный сценарий:**

```groovy
def MODULE_NAME = 'vectorizeArticles'
def BATCH_SIZE = 1000
def YC_ENDPOINT = 'https://llm.yandexcloud.net/foundationModels/v1/textEmbedding'
def API_KEY = 'your-api-key'

logger.info("Job started: vectorizing articles without embeddings")

def totalProcessed = 0
def offset = 0

while (true) {
  api.tx.call {
    def query = api.db.query(
      'from knowledgeBase$article a where a.vectorized != true order by a.uuid'
    )
    query.setFirstResult(offset)
    query.setMaxResults(BATCH_SIZE)
    def batch = query.list()
    
    if (batch.isEmpty()) {
      logger.info("Vectorization complete. Total: $totalProcessed objects")
      return
    }
    
    batch.each { article ->
      try {
        // Double-check idempotence
        if (article.vectorized == true) {
          logger.debug("Skip already vectorized: ${article.uuid}")
          return
        }
        
        // Call YC FM API
        def title = article.title ?: ''
        def embedding = api.http.post(YC_ENDPOINT)
          .header('Authorization', "Bearer $API_KEY")
          .body([texts: [title]])
          .execute()
          .asJson()
          .embeddings[0].embedding
        
        // Save embedding + mark as done
        utils.edit(article, [
          'vectorEmbedding': embedding.toString(),
          'vectorized': true,
          'vectorizedAt': new Date()
        ])
        
        totalProcessed++
        if (totalProcessed % 500 == 0) {
          logger.info("Progress: $totalProcessed vectorized")
        }
        
      } catch (e) {
        logger.error("Failed to vectorize ${article.uuid}: ${e.message}", e)
        // Не отмечаем как готовую → повтор при следующем запуске
      }
    }
    
    offset += BATCH_SIZE
  }
}
```

**Расписание задачи:**
- **Период:** Ежедневно
- **Время:** 02:00 (ночь, минимум нагрузка)
- **Стратегия:** "От момента последнего выполнения"

---

## 8. Open Questions (требуют уточнения)

| Вопрос | Кому | Приоритет |
|--------|------|-----------|
| Какой пользователь выполняет scheduled task (getCurrentUser)? | Сахабетдинов / Киселёва | High |
| Есть ли встроенный UI progress tracking в Scheduler? | Сахабетдинов | Medium |
| Поддерживается ли многопоточность (ThreadPool) в контексте джобы? | Киселёва | Medium |
| Как работает `api.scheduler.interruptJob()` — graceful shutdown или Thread.stop()? | Киселёва | Low |
| Где сохраняются логи по умолчанию (какой файл / компонент)? | SysAdmin | Low |

---

## Источники документации

1. `/Users/mdemyanov/Devel/naumen-ecosystem/naumen-smp/script/api-scheduler-rabota-s-planirovshchikom.md`
2. `/Users/mdemyanov/Devel/naumen-ecosystem/naumen-smp/script/api-tx-rabota-s-tranzaktsiyami.md`
3. `/Users/mdemyanov/Devel/naumen-ecosystem/naumen-smp/script/api-logging-nastroyka-logirovaniya.md`
4. `/Users/mdemyanov/Devel/naumen-ecosystem/naumen-smp/script/api-db-ispolzovanie-zaprosov-k-baze-dannykh.md`
5. `/Users/mdemyanov/Devel/naumen-ecosystem/naumen-smp/setting-sistem/deystviya-po-sobytiyam.md`
6. `/Users/mdemyanov/Devel/naumen-ecosystem/itsm365/tech-light/scheduler-tasks.md`

