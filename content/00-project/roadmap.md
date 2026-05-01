---
order: 5
title: "Roadmap проекта pg_vector_service"
properties:
  - Тип контента: Прочее
  - Фаза: PoC
  - Статус: Draft
---

# Roadmap проекта pg_vector_service

## 1. Контекст

`pg_vector_service` — JAR-модуль для Naumen SMP, добавляющий векторизацию SMP-объектов (`knowledgeBase$article`, `problem`, `issue`), семантический поиск похожих и обнаружение дублей. Стек, целевые объёмы и red lines зафиксированы в [CLAUDE.md](../../CLAUDE.md). Текущая фаза — **PoC**. Owner / Sponsor — Демьянов (см. [stakeholders](stakeholders.md)). Команда — AI-агенты под управлением PM (Claude Opus): Researcher, BA, SA, Dev, DevOps; матрица ролей — [AGENTS.md](../../AGENTS.md).

Артефакты, на которых построен этот roadmap:
- BA — [UC1](../30-requirements/functional/uc1-scheduled-vectorization.md), [UC2](../30-requirements/functional/uc2-similarity-search.md), [UC3](../30-requirements/functional/uc3-duplicate-detection.md), [NFR](../30-requirements/non-functional/nfr-cross-cutting.md).
- SA — [принципиальная архитектура](../40-architecture/principal-architecture.md) + 9 ADR в [content/00-project/adr/](adr/) (001 hexagonal, 002 SMP-only, 003 job-based, 004 vector-schema, 005 whitelist, 006 composite-text, 007 model-versioning, 008 near-duplicate, 009 embedding-model-decision-frame).
- Research — 8 файлов в [content/10-domain/research/](../10-domain/research/) (статус: 6 done, RES-002 partial, RES-003 deferred).

Backlog задач этого roadmap'а — [backlog.md](backlog.md).

## 2. Фазы и milestone'ы

| Фаза | Цель | Длительность | GO-критерии («что значит закрыто») | Артефакты |
|------|------|--------------|--------------------------------------|-----------|
| **Phase 0 (pre-flight)** | Снять блокеры до первого `/dev`-таска: подтверждение pgvector + сетевого доступа, рабочий `yc` CLI, метамодель целевых классов | 1-2 недели (на стороне owner'а) | 0.4 (Сахабетдинов) ✓; 0.5 (`yc` CLI + сервисный аккаунт) ✓; RES-001 ✓ (есть); RES-002 closeout (modelUri + dim + лимиты + цены) | [research/sources.md](../10-domain/research/sources.md), [research/yc-foundation-models.md](../10-domain/research/yc-foundation-models.md), `.env` |
| **PoC iter 1 — KB-only baseline (UC1 + UC2 на `knowledgeBase$article`)** | Первый рабочий JAR на стенде `llm2`: PII-нейтральный класс KB, scheduled-векторизация + similarity-поиск. Проверка hexagonal-каркаса, выбранной модели YC FM, индекса pgvector | ~2 недели Dev (после Phase 0) | UC1 AC-004/006/008/011/013 (идемпотентность, версия модели, PII-инвариант, атомарность, нет JDBC); UC2 AC-1..AC-9 на 1000 KB-статьях; **Recall@10 ≥ 0.70** на ground truth `kb-section`-ассоциаций (минимально жизнеспособный, цель ≥ 0.80 после tuning); **p95 ≤ 500 ms** end-to-end на 1k объектов; smoke-report на `llm2` зелёный | `src/`, [smoke-reports/](../70-operations/), отчёт offline-eval iter 1 |
| **PoC iter 2 — добавить `problem`** | Расширить UC1/UC2 на класс `problem` (включая medium-PII атрибуты `description`/`decisionReport` после второго whitelist-гейта). Проверить cross-class similarity (`problem ↔ kb-article`) | ~1 неделя | UC1 AC-002 (новый класс через конфиг без перекомпиляции); UC2 AC-5 (cross-class) на смешанной выдаче; smoke на `llm2`; whitelist `problem` v2 sign-off owner'а | smoke-report iter 2, `whitelist-config v2` |
| **PoC iter 3 — `issue` (low-PII whitelist) + UC3 online** | Включить `issue` с whitelist'ом `subject + cancelReason` (без `description`/`lastComment`); активировать UC3-A online cosine-threshold подсказку | ~1.5 недели | UC1 AC-008 (PII-инвариант на `issue.description` — не уходит в YC FM); UC3 AC-001 **precision дублей ≥ 0.80** на ground truth `issue.duplicates` / `duplicatesRL`; UC3 AC-003 latency online p95 ≤ 2 с; UC3 AC-005 (только `subject` в выдаче, нет `description`) | smoke-report iter 3, отчёт offline-eval iter 3 |
| **PoC iter 4 — UC3 batch + audit-log** | Запустить еженедельную джобу `duplicate-audit`, сформировать первый отчёт «N кандидатов на слияние», подключить аудит-лог YC FM (NFR-003) | ~1 неделя | UC3 AC-006 (отчёт сформирован за окно ≤ 4 ч на корпусе iter 3); AC-007 (группы покрытые `issue.duplicates` помечены); AC-009 (нет автомёрджа); AC-010 (`embedding_model_id` + thresholds в журнале); audit-log пишется по NFR-003 (имена атрибутов, не значения) | smoke-report iter 4, первый `DuplicateAuditReport` |
| **PoC closeout** | Tuning порогов, валидация всех AC и сквозных NFR, decision GO / NO-GO для перехода в MVP | ~1 неделя | Сводный отчёт по всем UC1/UC2/UC3 AC + NFR-001..062; финальные пороги `Дубль`/`Похожая` зафиксированы в обновлении ADR-008; финальные пороги Recall/MRR/p95 — в обновлении ADR-009 (после offline-eval); решение owner'а GO/NO-GO зафиксировано в `poc-closeout-report.md` | [content/70-operations/poc-closeout-report.md](../70-operations/) |
| **MVP** | Полная векторизация боевого тенанта стенда, расширение whitelist `issue` до medium-PII (`description`/`decisionReport`/`feedback`) с owner sign-off, latency-tuning, расширение SPI для других модулей SMP | TBD после PoC closeout | Все объекты целевых классов одного тенанта векторизованы в пределах согласованного бюджета YC FM; recall/precision не хуже PoC; SPI задокументирован и stable (см. ADR-013 эталона `naumen-smp-mcp`); первый внешний consumer SPI на `llm2` | `content/40-architecture/spi-contract.md` (новый), новые ADR при изменении модели/индекса |
| **Pilot** | Подключение первого внешнего клиента / отдельного стенда (не `llm2`); ввод multi-tenant (если требуется по результатам OQ-UC1-1 / OA-3); on-call процедуры | TBD | Pilot-стенд развёрнут (gate Сазонова); миграционный runbook апробирован; runbook on-call написан и проиграны учения | `content/70-operations/runbooks/`, новый ADR multi-tenancy |
| **Production** | Промышленный rollout, мониторинг, on-call, SLA на основе фактических замеров PoC + Pilot | TBD | uptime ≥ 99.5%; алерт по дневному бюджету YC FM (NFR-061) проигран; runbook миграции при смене embedding-модели опробован вживую (NFR-030, ADR-007); 4-eyes review на правки whitelist | оперэксплуатационный пакет |

**Лимит итераций PoC:** 4 итерации × 1-2 недели + closeout = **6-9 недель Dev** после закрытия Phase 0. Это первая оценка; уточняется после первого smoke на `llm2`.

## 3. Critical path

Зависимости от старта проекта до конца PoC. Жирным — задачи на критическом пути (если они опаздывают, опаздывает всё).

```mermaid
flowchart LR
    P04[**Phase 0.4**<br/>Сахабетдинов:<br/>pgvector + DDL + сеть] --> ADR3[ADR-003<br/>pgvector-index]
    P05[**Phase 0.5**<br/>yc CLI + SA + ключ] --> RES2[RES-002 closeout<br/>modelUri + dim + цены]
    RES2 --> ADRX[**ADR-XXX (новый)**<br/>concrete embedding model]
    RES2 --> RES3[RES-003<br/>budget-estimate]
    ADR9[ADR-009 frame] --> ADRX
    ADRX --> DEV1[**DEV-001..006**<br/>core + ports]
    P04 --> DDL[**DEVOPS-001**<br/>DDL вектор-таблицы]
    DDL --> DEV2[**DEV-007**<br/>VectorStoreSmpAdapter]
    DEV1 --> ITER1[**PoC iter 1**<br/>UC1+UC2 на KB]
    DEV2 --> ITER1
    ITER1 --> ITER2[PoC iter 2<br/>+ problem]
    ITER2 --> ITER3[PoC iter 3<br/>+ issue + UC3 online]
    ITER3 --> ITER4[PoC iter 4<br/>UC3 batch]
    ITER4 --> CLOSE[PoC closeout]
```

Главные блокеры: **Phase 0.4** (без подтверждения от Сахабетдинова — нет DDL → нет вектор-таблицы → нет адаптера) и **Phase 0.5** (без `yc` CLI — нельзя верифицировать modelUri / dim / цены → нельзя закрыть ADR-009 → нельзя выбрать конкретную модель). До закрытия 0.5 разрешено двигать DEV-001..006 (core / ports) на mock `EmbeddingProvider` — это решение принято в [ADR-009](adr/009-embedding-model-decision-frame.md).

## 4. Известные блокеры (Phase 0 pre-flight)

| ID | Что | Ответственный | Блокирует | Срок |
|----|-----|---------------|-----------|------|
| **0.4** | Подтверждение Сахабетдинова: установлена ли pgvector ≥ 0.8.x на БД стенда `llm2`; согласование DDL вектор-таблицы (схема/tablespace, `maintenance_work_mem`); сетевой доступ `llm2 → *.api.cloud.yandex.net:443` | Демьянов (пинг + запись в issue/wiki); Сахабетдинов (подтверждение) | ADR-002 OQ; ADR-003 (выбор индекса); ADR-004 (DDL); DEVOPS-001 (миграция); вся фаза `/dev` | до старта PoC iter 1 |
| **0.5** | Настроить `yc` CLI: создать сервисный аккаунт `pg-vector-service-poc`, выпустить ключ Foundation Models, проверить вызов embedding-модели; положить `sa-key.json` в SMP secret store на `llm2` | Демьянов (CLI + ключ); Сахабетдинов (secret store на стенде) | ADR-009 → ADR-XXX (concrete model); RES-002 closeout; RES-003 (budget); DEV-005 (`EmbeddingClient` integration test) | до старта PoC iter 1 |
| **0.6** | Live-выгрузка метамодели `issue` / `knowledgeBase` / `problem` со стенда `llm2` через MCP `naumen-smp-dev-admin` | Researcher (`/research`) | BA (whitelist атрибутов) — **закрыто** ([smp-metamodel.md](../10-domain/research/smp-metamodel.md), RES-001 done) | ✅ done |

Не блокеры, но желательно до `/dev iter 1`:
- **RES-002 closeout** — пункты «modelUri / dim / лимиты / цены» в [yc-foundation-models.md](../10-domain/research/yc-foundation-models.md). Сейчас public-docs за CAPTCHA; верифицировать через `yc ai foundation-models list` после Phase 0.5.
- **RES-003** — `budget-estimate.md` (расчёт стоимости full-rescan на медиане 100k–300k объектов). Без неё нельзя зафиксировать NFR-061 (дневной лимит) и порог `NFR-UC1-002`.
- **OQ-UC1-1 / OA-3** — single vs multi-tenant на `llm2`. Влияет на схему вектор-таблицы (ADR-004): отдельная таблица на тенант или discriminator-колонка.

Полный реестр open questions — в [принципиальной архитектуре §11](../40-architecture/principal-architecture.md) (16 OA-вопросов) + per-UC OQ в BA-артефактах. Все они переведены в backlog как `OWNER-*` / `RES-*` / `BA-*` задачи в [backlog.md](backlog.md).

## 5. Ритмика и контрольные точки

- **После каждой Dev-итерации** — smoke на стенде `llm2` через `smps`. Формат отчёта — по образцу эталона `Devel/naumen-smp-mcp/content/70-operations/smoke-reports/2026-04-23-llm2-m33.md`. Артефакт пишет DevOps в `content/70-operations/smoke-reports/<YYYY-MM-DD>-llm2-iter<N>.md` сразу по итогам smoke.
- **`/pm-review` всех содержательных артефактов** перед merge `private → public`: проверка обязательных properties, согласованности JTBD/AC/NFR, отсутствия секретов / PII в текстах. См. [AGENTS.md](../../AGENTS.md).
- **Еженедельный roadmap-snapshot** (PM): обновление колонки «Статус» в этом файле + апдейт backlog'а. Цель — иметь один источник правды о состоянии проекта.
- **PoC closeout** — единый отчёт `content/70-operations/poc-closeout-report.md` с итоговыми метриками (Recall@10, MRR@10, precision@T для UC3, p95 поиска, расход YC FM, AC-чеклист по UC1/UC2/UC3 + NFR). На его основе owner принимает решение GO / NO-GO в MVP.
- **PII-gate'ы** — отдельные контрольные точки перед каждым подключением нового класса в whitelist: PoC iter 2 (medium-PII атрибуты `problem`), PoC iter 3 (`issue` с low-PII), MVP-вход (`issue` с medium-PII). Sign-off owner'а фиксируется в whitelist-конфиге (см. [ADR-005](adr/005-whitelist-pii-default-deny.md)).
- **Ритм ADR-сессий** — открытые ADR (007/010/011/012/013/014 по нумерации в [принципиальной архитектуре §10](../40-architecture/principal-architecture.md)) пишутся в параллели с Dev-итерациями, не блокируют первый прототип. Критический путь — ADR-002/003/004/005/006/009 (закрыты или закрываются на этапе Phase 0/iter 1).

## 6. Open questions

> Ниже — вопросы, которые ещё не закреплены в ADR/требованиях и могут изменить план фаз. Полный реестр — в backlog'е и в `§11` принципиальной архитектуры.

| Фаза | OQ | Заметка |
|------|----|---------|
| Phase 0 / iter 1 | OQ-UC1-1 / OA-3 — single или multi-tenant на `llm2`? | Влияет на схему вектор-таблицы и на UC2 NFR-003. Если multi-tenant — нужен новый ADR на изоляцию. |
| Phase 0 / iter 1 | OA-7 — IAM-токен через JWT vs статический Api-Key | Решает Демьянов; пока используется shortcut Api-Key, под IAM-token нужен ADR-006 (yc-auth). |
| iter 1 | OA-13 — фильтрация `kbAccesses` (pre-filter в HQL vs post-filter с oversample) | Решается на первом замере latency UC2 — фиксируется в ADR-014 (uc-api-contract). |
| iter 2 | OA-11 — формат и канал доставки отчёта batch-аудита (KB-статья / шара / письмо) | Решается с аналитиком качества (когда появится) и на стороне owner'а. |
| iter 3 | OA-12 — UC3-online: ad-hoc embedding или lazy от UC1 | Решается ADR-010 после первого smoke iter 3 (когда есть фактический latency YC FM). |
| iter 3-4 | OA-15 — cap на время работы UC1 (минут / часов) | Решается owner'ом — по итогам наблюдения за длительностью на iter 1-2. |
| MVP-вход | OQ-UC1-8 — sign-off whitelist'а `issue` medium-PII (`description` / `lastComment`) | Условие: PII-аудит + согласие юр-департамента (если будет). |
| MVP-вход | OA-10 — стек метрик на `llm2` (SMP-родной / Prometheus / лог-парсинг) | Решается DevOps; PoC живёт на лог-парсинге, MVP — на полноценном стеке (ADR-012). |
| Pilot | OQ-UC1-2 — расписание UC1 по умолчанию | Решается owner'ом по факту наблюдений PoC. |
| Pilot | NFR-UC1-003 — метрика «не деградировать стенд» (что измеряем, какой порог) | Решается owner / DevOps; нужна для валидации NFR. |

## 7. Связанные артефакты

- [Стейкхолдеры](stakeholders.md)
- [Backlog](backlog.md)
- [BA — UC1 (scheduled vectorization)](../30-requirements/functional/uc1-scheduled-vectorization.md)
- [BA — UC2 (similarity search)](../30-requirements/functional/uc2-similarity-search.md)
- [BA — UC3 (duplicate detection)](../30-requirements/functional/uc3-duplicate-detection.md)
- [NFR cross-cutting](../30-requirements/non-functional/nfr-cross-cutting.md)
- [Принципиальная архитектура](../40-architecture/principal-architecture.md)
- [ADR-001 hexagonal](adr/001-hexagonal-architecture.md), [ADR-002 SMP-only](adr/002-smp-only-data-access.md), [ADR-003 job-based](adr/003-job-based-vectorization.md), [ADR-004 vector-schema](adr/004-vector-storage-schema.md), [ADR-005 whitelist](adr/005-whitelist-pii-default-deny.md), [ADR-006 composite-text](adr/006-composite-text-composition.md), [ADR-007 model-versioning](adr/007-model-versioning-migration.md), [ADR-008 near-duplicate](adr/008-near-duplicate-algorithm.md), [ADR-009 embedding-model-frame](adr/009-embedding-model-decision-frame.md)
- [Research: sources](../10-domain/research/sources.md), [SMP metamodel](../10-domain/research/smp-metamodel.md), [YC Foundation Models](../10-domain/research/yc-foundation-models.md), [pgvector indexes](../10-domain/research/pgvector-indexes.md), [similarity evaluation](../10-domain/research/similarity-eval.md), [clustering algos](../10-domain/research/clustering-algos.md), [SMP scheduled jobs](../10-domain/research/smp-scheduled-jobs.md), [reference project notes](../10-domain/research/reference-project-notes.md)

Внешние ссылки (вне Gramax-каталога): эталонный проект `/Users/mdemyanov/Devel/naumen-smp-mcp` (паттерн hexagonal + smoke-report формат); pgvector https://github.com/pgvector/pgvector.
