# Piano: Documentazione Flusso Agent Framework

## Context

L'Agent Framework è un orchestratore multi-agente sofisticato per generazione di codice AI-driven da specifiche in linguaggio naturale. È già attivo in produzione (container `agentfw-*`) ma manca di documentazione pubblica del flusso architetturale.

L'obiettivo è creare un documento dettagliato da pubblicare su WikiJS (`wiki.massimilianopili.com`) che spieghi **ogni passaggio del flusso**, il **perché** ogni componente esiste e il **come** comunicano tra loro — utile sia come reference tecnica che per onboarding.

---

## File da creare

**`/data/massimiliano/docs/agent-framework-flow.md`**

Il file viene automaticamente sincronizzato su WikiJS ogni 30 minuti tramite `docs-sync`.

---

## Struttura del documento

### 1. Panoramica (con diagramma Mermaid top-level)
- Architettura a 3 piani: Control Plane → Execution Plane → MCP Layer
- Diagramma a blocchi con tutti i componenti e frecce di comunicazione
- Stack tecnologico (Java 21, Spring AI, Redis Streams, pgvector + AGE)

### 2. Il flusso completo — step-by-step numerato
Sequenza end-to-end da `POST /api/v1/plans` fino al `COMPLETED`:

```
Step 1  → Ricezione specifica (PlanController)
Step 2  → Creazione piano e workspace
Step 3  → Council pre-planning (8 membri, advisory parallelo)
Step 4  → Decomposizione AI (Planner → Claude → tasks)
Step 5  → Dispatch Wave 1 (task senza dipendenze)
Step 6  → CONTEXT_MANAGER (esplorazione codebase, world state)
Step 7  → SCHEMA_MANAGER (estrazione contratti OpenAPI)
Step 8  → HOOK_MANAGER (policy per-task, deny-all + allowlist)
Step 9  → Worker domain (BE/FE/DBA/MOBILE) — implementazione
Step 10 → Raccolta risultati + state machine
Step 11 → Dispatch Wave successiva (dipendenze sbloccate)
Step 12 → REVIEW worker (quality gate)
Step 13 → Reward aggregation (Bayesian: ELO + Process + Quality Gate)
Step 14 → Completamento piano
```

Per ogni step: cosa fa, perché esiste, cosa entra/esce (JSON message schema), chi lo esegue.

### 3. Diagrammi Mermaid dettagliati
- **Sequence diagram**: dal client al worker e ritorno (con messaggi Redis Streams)
- **State machine**: Plan (PENDING→RUNNING→COMPLETED) e PlanItem (WAITING→DONE)
- **Flowchart**: pipeline CONTEXT → SCHEMA → HOOK → DOMAIN → REVIEW

### 4. Council Pre-Planning — perché e come
- Problema: rischio errori architetturali costosi scoperti tardi
- Soluzione: advisory panel di 8 worker (4 manager + 4 specialist) prima del dispatch
- Output: CouncilReport con raccomandazioni prioritizzate e risk assessment

### 5. Middle Layer — i 3 worker di preparazione
Per ciascuno (CONTEXT_MANAGER, SCHEMA_MANAGER, HOOK_MANAGER):
- Motivazione (perché esiste)
- Input/output schema
- Come trasforma i dati per i worker successivi
- PathOwnershipEnforcer: deny-by-default su file non autorizzati

### 6. MCP Layer e Access Control
- Modello deny-all + allowlist per worker type
- Generazione dinamica HookPolicy dal HOOK_MANAGER
- Audit log di ogni tool call
- Tool disponibili per categoria (fs_*, bash_*, db_*, graph_*, embeddings_*)

### 7. Messaging: Redis Streams
- Perché async (deaccoppiamento, retry, back-pressure)
- Topics `agent-tasks` e `agent-results`
- Consumer groups per worker type
- Schema JSON completo dei messaggi TaskMessage e TaskResult
- Alternativa Azure Service Bus (e quando usarla)

### 8. Gaussian Process per Worker Selection
- Problema: quale profilo worker è migliore per questo task?
- Soluzione: GP con kernel RBF su embedding del task (1024 dim)
- Strategia UCB (esplorazione vs. sfruttamento)
- Cold-start graceful con prior uniforme
- Ralph-Loop: se sigma² > soglia → REVIEW prima del dispatch

### 9. RAG Pipeline
- Perché (workers hanno contesto limitato; knowledge esterna utile)
- Ingestion: chunking → embedding (Ollama mxbai-embed-large) → pgvector
- Tre grafi Apache AGE: knowledge_graph, code_graph, task_graph
- Hybrid search: cosine + BM25 + graph traversal → RRF → cross-encoder reranking

### 10. Reward System e ELO
- 3 fonti: Review Score + Process Score + Quality Gate Score
- Formula aggregazione Bayesiana
- ELO rating per profilo worker (leaderboard)
- DPO training data generata per continuous improvement

### 11. Error Handling e Compensation (Saga Pattern)
- State machine con retry automatico (max 3 tentativi)
- Human-in-the-loop: `AWAITING_APPROVAL` per task ad alto rischio
- Compensation: git revert + rollback file → riapertura piano con nuovi item
- Event sourcing per audit trail immutabile

### 12. Event Sourcing e SSE
- Perché (recovery, late-join, replay)
- PlanEvent come append-only log (12 event types)
- SSE stream: `GET /api/v1/plans/{id}/events` con `Last-Event-ID` per late-join

---

## File da leggere prima di scrivere

- `/data/massimiliano/agent-framework/control-plane/orchestrator/` — sorgenti Orchestrator
- `/data/massimiliano/agent-framework/execution-plane/` — worker SDK e worker
- `/data/massimiliano/agent-framework/agents/manifests/` — manifest YAML worker
- `/data/massimiliano/agent-framework/patterns/` — pattern architetturali esistenti
- `/data/massimiliano/agent-framework/prompts/` — template prompt Claude AI
- `/data/massimiliano/agent-framework/docker/` — compose file produzione

---

## Sezione 13: Roadmap e Sviluppo Futuro

Da includere nel documento come sezione finale — dà contesto su dove sta andando il progetto.

### Feature completate (14, sessioni S1-S11)
Elenco sintetico delle feature già implementate con sessione e breve descrizione
(Event Sourcing, Missing-Context Feedback, GP Worker Selection, DPO, Ralph-Loop, Council, RAG, Active Token Budget…)

### Prossime feature pianificate (roadmap)

La roadmap è divisa in due blocchi principali:

**Blocco A — Feature operative (prossime 6 sessioni, ~#19–#29)**:
1. Resilienza consumer + ToolNames Registry centralizzato
2. Enrichment Pipeline activation (#23) → sblocca RAG e HOOK_MANAGER
3. toolHints configurabili per task (#24L1), retry manuale, worker lifecycle
4. TASK_MANAGER, context cache cross-plan, hierarchical plans (#9)
5. HookPolicy extensions, model per task, auto-split task costosi
6. Monitoring Dashboard UI real-time (SSE + Prometheus)

**Blocco B — Evoluzioni architetturali avanzate (#30–#106, ~175 giorni totali)**:

| Categoria | Items | Fondamento teorico |
|-----------|-------|-------------------|
| **Blockchain-inspired** (#30–#34) | Hash chain tamper-proof, verifiable compute, policy-as-code immutabile, token ledger double-entry, federazione multi-server | Crittografia, CRDT, mTLS |
| **Mathematical foundations** (#35–#43) | Context quality scoring, worker pool sizing (Little's Law), stochastic decomposition, EVSI, policy lattice, Shapley attribution, zero-trust isolation, entropy maximization, TDA | Teoria dell'informazione, queueing theory, teoria dei giochi, topologia |
| **Advanced mechanisms** (#44–#49) | Execution sandbox containerizzato, Merkle tree DAG, verifiable council (commit-reveal), reputation staking, CAS, quadratic voting | Crittografia, mechanism design (Vitalik Buterin 2019) |
| **Research Fase 8** (#50–#61) | Portfolio theory (Markowitz), market making, Black-Scholes Greeks, causal inference (Pearl), replicator dynamics, sandpile model, swarm ACO, spectral graph, tropical semiring, diffusion DAG, persistent homology | Finance, sistemi complessi, matematica avanzata |
| **Research Fase 9** (#62–#76) | VCG mechanism, MPC, Prospect Theory, Hedge, Real Options, Fisher Information, Kelly Criterion, Contract Theory, Optimal Stopping, TDT/FDT, EVSI, Goodhart's Law, Calibration, Superrationality | Decision theory, economia, epistemologia |
| **Research Fase 10** (#77–#86) | Active Inference, Information Bottleneck, MDL/Kolmogorov, Renormalization Group, Spin Glass, H-infinity Control, Byzantine FT, Edge of Chaos, Persistent Homology, Functorial Semantics | Neuroscienze comp., fisica statistica, controllo robusto |
| **Research Fase 11** (#87–#96) | Petri Nets, CSP, PAC-Bayes, Social Choice, Diversity Prediction, VSM, Thompson Sampling, Compressed Sensing, Ergodic Economics, M/G/1 | Formal methods, social choice, cybernetics, learning theory |
| **Research Fase 12** (#97–#106) | Meta-Reasoning, Process Mining, Bounded Rationality, Actor Model, Plan Snapshots, Evidence Accumulation, Computational Complexity, Information Foraging, Policy Abstraction, Stigmergy | Reasoning, program synthesis, agent coordination |

**Sforzo complessivo**:
```
Blocco A (#19-#29):         ~6 sessioni
Blocco B core (#30-#49):    ~52 giorni
Research Fase 8 (#50-#61):  22.5 giorni
Research Fase 9 (#62-#76):  33.0 giorni
Research Fase 10 (#77-#86): 24.0 giorni
Research Fase 11 (#87-#96): 22.5 giorni
Research Fase 12 (#97-#106):21.5 giorni
Execution Sandbox (#44+):    3.0 giorni
Pattern Claude Code:         7.0 giorni (priorità CRITICA+ALTA)
Observability gaps:          5.0 giorni
─────────────────────────────────────────
TOTALE roadmap completa:    ~191 giorni
```

**Sezioni aggiuntive da includere nel documento**:

4. **Execution Sandbox (#44)**: architettura a 2 livelli (framework containerizzato + sandbox effimeri Docker per compilazione/test). 7 immagini pre-built (Java 21, Go, Python, Node.js, Rust, C++, .NET). 8 livelli di sicurezza.

5. **Pattern Claude Code → Agent Framework**: mappatura di 28 pattern (auto-compacting, project instructions, persistent memory, progress tracking, phased execution, parallel tool calls, ecc.). Stato: ✅ implementato, 🔧 parziale, ❌ non ancora.

6. **Observability gap**: 6 gap critici (conversation history, decision reasoning, file modification tracking, Prometheus metrics, persistent audit, MCP server audit logging). ~5 giorni totali.

---

## Verifica

1. Controllare che `/data/massimiliano/docs/agent-framework-flow.md` sia creato e ben formattato
2. Verificare che i diagrammi Mermaid siano sintatticamente validi (nessun carattere che rompe il parser WikiJS)
3. Eseguire `docs-sync` manualmente o attendere il timer da 30 min
4. Verificare che la pagina appaia su WikiJS sotto `wiki.massimilianopili.com`
5. Controllare rendering Mermaid nel browser (WikiJS 2 supporta Mermaid nativo)
