---
description: "DevSecOps (subagent, Sonnet). Embedded security review (secrets/SAST/supply-chain). Пример: /devsecops audit src/, /devsecops secrets-policy"
allowed-tools: Task
---

Запусти subagent `devsecops-agent` через Task tool. **Opt-in роль** — не активируй автоматически без явного запроса или при отсутствии триггеров (secrets/SAST/vulnerability/supply-chain).

**Входы пользователя:** `$ARGUMENTS`

## Что передать subagent'у

Сформируй prompt по контракту:

1. **Цель** одной фразой (security audit для модуля X / написать secrets-policy / dependency audit)
2. **Входные файлы** — код (`src/`), конфигурация (`.env.example`, `infra/`), manifest'ы (`pyproject.toml`/`package.json`/`pom.xml`), архитектура (`content/40-architecture/`)
3. **Ожидаемый артефакт**:
   - `content/00-project/security/audit-<NNN>-<date>.md` (audit report)
   - опц. `content/00-project/security/secrets-policy.md` (один на проект)
4. **Критерии приёмки** — SAST findings с severity, secrets-management policy зафиксирован, supply-chain risk assessed

## Режимы (распарсь $ARGUMENTS)

- `audit <area>` — security audit для области (код / конфиг / dependencies)
- `secrets-policy` — создать или обновить `content/00-project/security/secrets-policy.md`
- `dependency-audit` — supply-chain CVE check
- `pre-deploy-gate <env>` — написать gate-policy для DevOps
- (свободный текст) — обсудить запрос

## Координация с DevOps

DevOps владеет deploy/runbook/monitoring/IAM-implementation. DevSecOps — secrets-policy/SAST/supply-chain/IAM-policy. См. секцию «Координация с DevSecOps» в `agents/devops-agent.md`.
