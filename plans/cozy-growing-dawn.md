# Chiusura B10 + B11 — Già risolti, aggiornare PIANO.md

## Contesto

Durante l'implementazione è emerso che **B10** e **B11** sono già presenti in HEAD.
Il commit `ab7a893` ("execution sandbox + GP predictor + model routing #44 Fase 3-4") li ha
inclusi come parte dell'implementazione del GP predictor, senza aggiornare lo stato in PIANO.md.

Verifica in `OrchestrationService.java` (HEAD attuale):
- **B10** — riga 481: `// Compensation path` + riga 488: `"PLAN_COMPENSATION_STARTED"` ✅
- **B11** — riga 908: `// Fast-path budget pre-check` ✅

PIANO.md mostra ancora entrambi come aperti (senza ✅). Il totale risolti è 13/18 in PIANO.md
ma dovrebbe essere 15/18.

## Operazioni da eseguire

### 1. `git stash pop`
Ripristinare le modifiche unstaged della sessione parallela (analytics + sandbox worker files).
Lo stash non contiene modifiche mie — B10/B11 erano già in HEAD.

### 2. Aggiornare PIANO.md
**File**: `/data/massimiliano/agent-framework/PIANO.md`

Marcare B10 e B11 come risolti aggiungendo `✅` alle righe corrispondenti:
- `| B10 |` → `| B10 ✅ |`
- `| B11 |` → `| B11 ✅ |`

Aggiornare il contatore dei bug risolti da 13/18 a 15/18 (se presente nell'intestazione).

### 3. Commit solo PIANO.md
```bash
cd /data/massimiliano/agent-framework
git add PIANO.md
git commit -m "docs: mark B10 and B11 as resolved in bug backlog

Both fixes confirmed present in HEAD (commit ab7a893):
- B10: compensation path with PLAN_COMPENSATION_STARTED event (OrchestrationService:481)
- B11: fast-path budget pre-check before GP inference (OrchestrationService:908)"
```

## Verifica

```bash
cd /data/massimiliano/agent-framework

# Confermare fix in codice
grep -n "PLAN_COMPENSATION_STARTED\|Fast-path budget pre-check" \
  control-plane/orchestrator/src/main/java/com/agentframework/orchestrator/orchestration/OrchestrationService.java

# Confermare PIANO.md aggiornato
grep "B10\|B11" PIANO.md
```
