# Piano: Allineamento Dati Documentazione Agent Framework con Realta'

## Contesto

I numeri citati nella documentazione (`overview.md`, `index.md`) sono rimasti fermi a snapshot precedenti. Il codebase e' cresciuto significativamente (V42 Flyway, 1587 test, 11 workflow, 5 messaging providers, 47+ manifest) ma i doc riportano ancora i valori vecchi.

## Discrepanze trovate

| Metrica | Valore nei doc | Valore reale | Delta |
|---------|---------------|-------------|-------|
| Worker profiles/manifests | 41 | **47** (in `agents/manifests/`) | +6 |
| Agent `.yml` totali | 53 moduli | **53** | OK |
| Flyway migrations | V1-V9 (index.md), "33" (MEMORY.md) | **42** (V1-V42) | +33 vs index, +9 vs memory |
| REST API endpoints | "20+" | **~116 decorators**, 14 controller | ~+96 |
| Test methods (@Test) | "416 test" (index), "862+30+116+58+22+9" (overview) | **1587** @Test annotations, 204 classi | +490 vs overview totale |
| CI/CD workflows | "8 GitHub Actions" | **11 Gitea workflows** | +3, nome sbagliato |
| Docker images | "18" | **genera da build, numero reale da verificare** | da aggiornare |
| Messaging providers | "redis, jms, servicebus" (3) | **5** (+ inprocess, hybrid) | +2 |
| Maven modules (reactor) | "53 moduli" | **62** | +9 |
| Event types (PlanEvent) | 7 (riga 616 overview.md) | **25** (17 costanti + 8 inline) | +18 |

## Task

### 1. Aggiornare `overview.md`

**File**: `/data/massimiliano/docs/agent-framework/overview.md`

Correzioni puntuali (search & replace):

| Riga | Vecchio | Nuovo |
|------|---------|-------|
| 7 | `41 worker profiles across 7 domain types` | `47 worker profiles across 7 domain types` |
| 18 | `Messaging is pluggable (\`redis\` default, \`jms\`, \`servicebus\`)` | `Messaging is pluggable (\`redis\` default, \`jms\`, \`servicebus\`, \`inprocess\`, \`hybrid\`)` |
| 21 | `REST API with 20+ endpoints` | `REST API with 116 endpoints across 14 controllers` |
| 583 | tabella 3 provider | aggiungere in-process e hybrid |
| 1127 | `Orchestrator (862 tests, ~120 classes)` | aggiornare con conteggio reale |
| 1276 | `8 workflows in \`.github/workflows/\`` | `11 workflows in \`.gitea/workflows/\`` |
| 1280 | `push 18 Docker images` | verificare numero reale e aggiornare |

### 1b. Aggiornare lista Event Types in `overview.md` (riga 616)

**Vecchio** (7 tipi):
```
Event types: `PLAN_STARTED`, `PLAN_PAUSED`, `PLAN_RESUMED`, `TASK_DISPATCHED`,
`TASK_COMPLETED`, `TASK_FAILED`, `PLAN_COMPLETED`.
```

**Nuovo** — Dividere in categorie:

- **Plan lifecycle** (8): PLAN_STARTED, PLAN_COMPLETED, PLAN_PAUSED, PLAN_RESUMED, PLAN_CANCELLED, PLAN_COMPENSATION_STARTED, PLAN_UNDO_REQUESTED, PLAN_RETRY_REQUESTED, PLAN_AMENDMENT_REQUESTED
- **Task lifecycle** (5): TASK_DISPATCHED, TASK_COMPLETED, TASK_FAILED, TASK_AUTO_SPLIT, ITEM_STATUS_CHANGED
- **Sub-plan** (1): SUB_PLAN_STARTED
- **Budget/token** (2): BUDGET_UPDATE, TOKEN_UPDATE
- **Compensation** (1): COMPENSATION_REQUESTED
- **Tool tracking** (2): TOOL_CALL_START, TOOL_CALL_END
- **Monitoring/drift** (4): SYSTEM_CRITICALITY, WORKER_DRIFT_DETECTED, CALIBRATION_DRIFT, CHANGEPOINT_DETECTED
- **Verification** (1): LTL_VERIFICATION

Fonte: `SpringPlanEvent.java` (costanti) + `OrchestrationService.java` (inline strings).

### 2. Aggiornare `index.md`

**File**: `/data/massimiliano/docs/agent-framework/index.md`

| Riga | Vecchio | Nuovo |
|------|---------|-------|
| 29 | `Worker profiles (41 manifest, 53 moduli)` | `Worker profiles (47 manifest, 62 moduli)` |
| 39 | `Endpoint table (20+)` | `Endpoint table (116 endpoints)` |
| 48-60 | Flyway V1-V9 | Estendere fino a V42 (almeno milestone chiave) |
| 140 | `8 GitHub Actions workflows` | `11 Gitea workflows` |
| 142 | `18 Docker images (ghcr.io)` | aggiornare |
| 154 | `Test Coverage (416 test)` | `Test Coverage (1587 test, 204 classi)` |
| 156-162 | tabella test per modulo obsoleta | aggiornare con numeri reali |
| 196 | `53 moduli Maven (43 worker + 10 shared/infra), 18 Docker images` | `62 moduli Maven, ...` |

### 3. Aggiornare MEMORY.md

**File**: `/home/massimiliano/.claude/projects/-data-massimiliano/memory/MEMORY.md`

- `33 Flyway migrations` → `42 Flyway migrations`
- `1270 test` → `1587 test` (se presente)

### 4. Re-sync WikiJS dopo le correzioni

```bash
cd /data/massimiliano/wikijs && node import-docs.js --update
```

## File critici

| File | Azione |
|------|--------|
| `/data/massimiliano/docs/agent-framework/overview.md` | Correggere 7+ numeri obsoleti |
| `/data/massimiliano/docs/agent-framework/index.md` | Correggere 8+ numeri, estendere tabella Flyway |
| `/home/massimiliano/.claude/projects/-data-massimiliano/memory/MEMORY.md` | Aggiornare conteggio migrations |

## Verifica

1. `grep -n "41 worker\|20+ endpoint\|416 test\|8 GitHub\|18 Docker\|33 Flyway" /data/massimiliano/docs/agent-framework/*.md` — nessun match (tutti aggiornati)
2. I numeri in `overview.md` corrispondono ai conteggi reali verificati:
   - `find . -name "*.agent.yml" | wc -l` = 53
   - `ls .gitea/workflows/ | wc -l` = 11
   - `ls db/migration/ | wc -l` = 42
   - `grep -r "@Test" | wc -l` = 1587
