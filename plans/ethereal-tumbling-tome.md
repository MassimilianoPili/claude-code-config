# Piano Verifica e Correzioni — Meta-Analisi Agent Framework

## Context
Sessione di meta-analisi del 15 marzo ha prodotto fix di compilazione, property-based tests, CI/CD e dark bean integration. Serve consolidare: verificare compilazione, correggere un mismatch CI, e push dei commit pending.

---

## Stato Verificato (READ-ONLY)

### 1.1 InsightExtractor — getter fix ✅ VERIFICATO
- `getDependsOn()` e `getContextRetryCount()` usati correttamente (righe 176, 196, 200)
- Nessuna traccia dei vecchi `getDependencies()`/`getRetryCount()`

### 1.2 HedgeAlgorithmPropertyTest — jqwik fix ✅ VERIFICATO
- Usa `@Provide` arbitraries, nessun `@DoubleRange` residuo

### 1.3 Property-Based Tests (3 file, 23 proprietà) ✅ VERIFICATI
- `ShapleyValuePropertyTest.java`, `WassersteinDistancePropertyTest.java`, `HedgeAlgorithmPropertyTest.java` presenti

### 1.4 CI/CD Pipeline ✅ VERIFICATO (con bug)
- `.gitea/workflows/ci.yml` e `release.yml` presenti
- `flyway-maven-plugin` nel POM

### 1.5 jqwik 1.9.2 dependency ✅ VERIFICATO

### 1.6 `.jqwik-database` in .gitignore ✅ VERIFICATO

### 2.1 Template Academic Researcher ✅ VERIFICATO
- Tutti i 9 file in `/data/massimiliano/claude-shared/agents/templates/`

### Docker Compose SOL ✅ VERIFICATO
- `docker/docker-compose.sol.yml` esiste (non in root, ma in `docker/`)

---

## Azioni da Eseguire

### A1. Fix CI migration count (BUG)
**File**: `.gitea/workflows/ci.yml` riga 83
**Problema**: `EXPECTED=36` ma ci sono **38 migrazioni** (V1-V38)
**Fix**: Cambiare `EXPECTED=36` → `EXPECTED=38`

### A2. Compilazione completa
```bash
cd /data/massimiliano/agent-framework
mvn compile -pl control-plane/orchestrator
```
Verifica che InsightExtractor e tutti i nuovi file compilino senza errori.

### A3. Git — Commit staged + fix CI
Attualmente staged:
- `M .gitignore` (aggiunto `.jqwik-database`)
- `A PIANO_CORREZIONI_META_ANALISI.md`

Aggiungere anche il fix CI (A1) e committare tutto.

### A4. Git push
7 commit ahead di `origin/main`. Push a Gitea dopo verifica compilazione.

### A5. KORE — Nodi graph (opzionale, bassa priorità)
Registrare in AGE: CICDPipeline nodes, PropertyTest metadata, InsightExtractor bugfix.

---

## Verifica End-to-End
1. `mvn compile -pl control-plane/orchestrator` → 0 errori
2. `mvn test -pl control-plane/orchestrator -Dtest="ShapleyValuePropertyTest,WassersteinDistancePropertyTest,HedgeAlgorithmPropertyTest"` → 23/23
3. `git push origin main` → 8 commit (7 pending + 1 nuovo)
4. CI Gitea: verificare che il workflow ci.yml passi con EXPECTED=38
