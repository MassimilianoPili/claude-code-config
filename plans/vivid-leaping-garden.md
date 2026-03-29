# Piano: Censimento Agent Framework + Server Snapshot Tool

## Context

L'agent-framework è stato sviluppato in **8 sessioni Claude su 16 giorni** (28 feb → 15 mar 2026), producendo 101 commit, 575 file sorgente Java e 200 file test. È attualmente deployato su SOL come Fase 0 (orchestrator-only) ma verrà spento e riacceso periodicamente. L'utente chiede:

1. **Censimento** completo delle modifiche e dell'implementazione Claude-based
2. **Server Snapshot Tool** — strumento per catturare lo stato completo del server, con prospettiva di visualizzazione timelapse

---

## Parte 1: Censimento Agent Framework

### Timeline di sviluppo

| Data | Sessione | Focus principale | Commit |
|------|----------|-----------------|--------|
| 28 feb | S1 | Initial commit, Fasi 0-10 hardening (208 test), RAG pipeline | 2 |
| 1 mar | S2-S9 | RAG engine, GP engine, DPO, context manager, token budget, Flyway refactor, boot fixes | 9 |
| 7 mar | S10 | 26 nuovi worker, CI GitHub, Fasi 8-12 analytics (spectral graph, causal inference, Shapley) | 16 |
| 8 mar | S11-S14 | Fase 11-12, execution sandbox, GP predictor, monitoring, audit, compensation | 21 |
| 9 mar | — | Token economics, Ed25519 signing, SHA-256 policy hash, context quality scoring | 13 |
| 10 mar | — | Quality audit Fase 9-12, Merkle DAG, commit-reveal, Quadratic Voting | 2 |
| 14 mar | — | Fase 13 (7 analytics), L3 policy, Redis topic splitting, SLI/SLO, sandbox fix | 7 |
| 15 mar | — | Fase 14-15 analytics, **deploy Fase 0 su SOL**, A2 Dark Bean Fase 1 (5 servizi) | 12 |

### Numeri

- **101 commit** totali
- **575 file Java** sorgente + **200 file test**
- **40+ worker** auto-generati da manifest YAML (`agent-compiler-maven-plugin`)
- **63 analytics services** in 10+ domini (game theory, finance, info theory, control theory, formal methods, complex systems, causal inference, etc.)
- **33 Flyway migrations** (V1-V33)
- **6 hook Claude deterministici** + `hooks-config.json` auto-generato
- **1270 test** (dalla memory)

### Architettura implementata su Claude Code

L'agent-framework ha un'integrazione diretta con Claude Code come runtime:

**Worker come Skill Claude** (`.claude/agents/*/SKILL.md`):
- 40+ worker definiti come agent Claude Code con YAML frontmatter
- Ogni SKILL.md specifica: ruolo, tool consentiti, formato output, vincoli
- Il `agent-compiler-maven-plugin` genera sia i moduli Maven che i `SKILL.md` dai manifest `.agent.yml`

**Hook deterministici** (`.claude/settings.json`):
- `enforce-ownership.sh` (PreToolUse Edit/Write) — valida path vs `ownsPaths` per worker type
- `block-destructive.sh` (PreToolUse Bash) — blocca git reset, rm -rf, etc.
- `enforce-mcp-allowlist.sh` (PreToolUse mcp__*) — allowlist MCP per worker
- `enforce-tool-allowlist.sh` (PreToolUse Glob/Grep) — tool allowlist
- `audit-log.sh` (PostToolUse Edit/Write/Bash) — audit trail
- `validate-no-secrets.sh` (Stop) — verifica no secret committati

**Orchestrator Spring Boot** (321 file sorgente):
- `PlannerService` — decomposizione piano via Claude API
- `OrchestrationService` — dispatch, token budgeting, compensation
- `RewardComputationService` — scoring Bayesiano a 4 fonti
- `WorkerSelectionPredictor` — selezione worker via GP (Gaussian Process)
- `CouncilService` — advisory pre-planning (8 membri: 4 manager + 4 specialist)

**Engines condivisi**:
- **RAG Engine** — pgvector + Apache AGE hybrid search + BM25 + RRF + HyDE
- **GP Engine** — Gaussian Process regression (kernel RBF, Cholesky), DPO training

### A2 Dark Bean — stato integrazione

63 analytics services, di cui 17 erano "dark bean" (istanziati ma non collegati al flusso).

- **Fase 1 ✅** (5 integrati): FunctorialSemantics→QualityGate, ByzantineFaultTolerance→TaskCompleted, ChandyLamportSnapshotter→PreDispatch, CSPChannelVerifier→PreDispatch, SpinGlassDispatch→PostAssignment
- **Fase 2** (5 pending): DescriptionLogicMatcher, InformationBottleneck, PACBayes, HInfinityRobust, EdgeOfChaos → GP Pipeline
- **Fase 3** (3 pending): PotentialRewardShaping, ErgodicBudgetAnalyzer, ReflectiveDispatch → Reward/Budget
- **Fase 4** (4 pending): RenormalizationGroup, Superrationality, ViableSystemAuditor, CompressedSensingRetriever → Council/RAG

### Deployment attuale

Container `agentfw-orchestrator` su `:8085` (768MB, ZGC). Usa infra condivisa SOL (postgres, redis, ollama, proxy-ai). Viene spento/riacceso al bisogno — non servizio permanente per ora. 4 fix applicati al primo boot (InProcessWorker conditional, pgcrypto, Alpine Random, RedisTemplate qualifier).

---

## Parte 2: Server Snapshot Tool

### Problema

Lo stato del server è disperso in ~5 fonti non coordinate:
- Docker API (container state, stats)
- `sol status` (lista container colorata, no persistenza)
- AGE knowledge_graph (riferimento statico, sync notturno)
- `server-api` SSE (live status, no storico)
- `compact-context-preserver.sh` (mini-snapshot per Claude, effimero)

*(Prometheus/Grafana in fase di dismissione — non contare su di essi)*

### Soluzione: `sol snapshot` + visualizzazione timelapse

**Fase 1**: script bash `sol-snapshot` per cattura e persistenza.
**Fase 2**: visualizzazione tipo "timelapse edificio" — pagina HTML che mostra evoluzione del server nel tempo.

### Fase 1: `sol snapshot` (CLI)

**File da modificare**:
- `/data/massimiliano/shell-scripts/bin/sol` — aggiungere sotto-comando `snapshot`

**File da creare**:
- `/data/massimiliano/shell-scripts/bin/sol-snapshot` — script dedicato (sourced da `sol`)

**Schema DB** (eseguire direttamente su `embeddings`):

```sql
CREATE TABLE IF NOT EXISTS server_snapshots (
    id SERIAL PRIMARY KEY,
    taken_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    label TEXT,
    snapshot JSONB NOT NULL,
    hash TEXT NOT NULL,
    duration_ms INTEGER
);
CREATE INDEX idx_snapshots_taken_at ON server_snapshots(taken_at DESC);
```

**Struttura JSON snapshot**:

```json
{
  "timestamp": "2026-03-15T13:00:00Z",
  "label": "post-deploy-agentfw",
  "host": {
    "hostname": "sol",
    "uptime": "23 days",
    "kernel": "6.8.0-100-generic",
    "memory": { "total_mb": 15360, "used_mb": 12288, "available_mb": 3072 },
    "disk": { "mount": "/data", "size_gb": 295, "used_gb": 15, "avail_gb": 266, "pct": 6 },
    "load": [0.5, 0.7, 0.8],
    "ssh_agent": true
  },
  "containers": [
    {
      "name": "nginx", "image": "nginx:alpine",
      "status": "running", "health": "healthy",
      "uptime_seconds": 43200,
      "ports": ["80", "8888"],
      "memory_mb": 45, "cpu_pct": 0.1
    }
  ],
  "systemd_services": [
    { "name": "ttyd", "status": "active", "pid": 12345 }
  ],
  "databases": {
    "postgres": { "databases": 6, "total_connections": 42 },
    "redis": { "keys_total": 186, "memory_mb": 12 },
    "neo4j": { "node_count": 783 }
  },
  "network": {
    "tailscale": "running",
    "cloudflare_tunnel": "running",
    "wireguard_peers": 2
  },
  "anomalies": [
    { "container": "preference-sort", "issue": "unhealthy", "duration": "3 days" }
  ]
}
```

**Comandi CLI**:

```
sol snapshot                    # cattura e salva, output compatto
sol snapshot --label "pre-x"   # con etichetta
sol snapshot list              # ultimi 20 snapshot (tabella)
sol snapshot diff [id1] [id2]  # diff tra due (default: ultimi 2)
sol snapshot show <id>         # JSON completo di uno snapshot
```

**Logica raccolta** (parallela, ~3 secondi):
1. Host: `uname -r`, `free -m`, `df -BG /data`, `uptime`, `cat /proc/loadavg`, `ssh-add -l`
2. Docker: `docker ps --format json` + `docker stats --no-stream --format json`
3. Systemd: `systemctl --user list-units --type=service --state=active`
4. DB: `psql -c "SELECT count(*) FROM pg_stat_activity"`, `redis-cli INFO keyspace`, `redis-cli INFO memory`
5. Network: `tailscale status --json 2>/dev/null`, `wg show 2>/dev/null`

**Diff**: usa `jq` per confrontare due snapshot JSONB e mostrare solo i cambi (container aggiunti/rimossi, status cambiati, memoria delta).

### Fase 2: Visualizzazione Timelapse (futura)

Pagina HTML tipo timelapse che mostra l'evoluzione del server nel tempo:
- **Timeline orizzontale** in basso (slider tra snapshot)
- **Grid di container** al centro — ogni container è un "blocco" dell'edificio
- **Colori**: verde (healthy), arancione (running senza healthcheck), rosso (unhealthy/stopped), grigio (rimosso)
- **Animazione**: scorrendo la timeline i blocchi appaiono/scompaiono/cambiano colore
- **Dettagli on-hover**: memoria, CPU, uptime di quel container in quel momento

Potrebbe essere una sezione della dashboard (`/snapshot/`) o standalone. Dati da `server_snapshots` via API REST (nuovo endpoint in `server-api` o query diretta).

### Sequenza di implementazione

1. **Schema SQL** — `CREATE TABLE server_snapshots` su `embeddings`
2. **Script `sol-snapshot`** — raccolta parallela + JSON + INSERT PostgreSQL
3. **Integrazione in `sol`** — sotto-comando `snapshot` con dispatch a `sol-snapshot`
4. **Test** — catturare 2-3 snapshot, verificare diff
5. **(Fase 2)** Timelapse HTML — dopo aver accumulato snapshot sufficienti

### Verifica

```bash
# 1. Schema
psql -h localhost -U massimiliano -d embeddings -c "CREATE TABLE IF NOT EXISTS server_snapshots ..."

# 2. Primo snapshot
sol snapshot --label "baseline"

# 3. Verifica persistenza
psql -h localhost -U massimiliano -d embeddings -c "SELECT id, taken_at, label FROM server_snapshots"

# 4. Cambiare qualcosa (es. stop/start un container), secondo snapshot
sol snapshot --label "after-change"

# 5. Diff
sol snapshot diff
```

### File critici

| File | Azione | Note |
|------|--------|------|
| `/data/massimiliano/shell-scripts/bin/sol` | Modifica | Aggiungere case `snapshot` nel dispatch |
| `/data/massimiliano/shell-scripts/bin/sol-snapshot` | Nuovo | Script dedicato (~200 righe) |
| Tabella `server_snapshots` su `embeddings` | Nuovo | Schema + indice |
