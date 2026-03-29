# Architecture Diagram v2 — Agent Framework

## Context
Il diagramma architetturale attuale (page ID 99) riflette lo stato S4-S5 del framework. Da allora il codebase è cresciuto enormemente:
- **42 Flyway migrations** (documentate solo V1-V9)
- **63 servizi analytics** (game theory, finance, control, formal methods, complex systems)
- **21 WorkerType** (erano ~12)
- **GP Engine** con UCB selection + DPO GP residual
- **Council System** con submodular selection + taste profile
- **Token Ledger** double-entry + PID adaptive budget
- **Leader Election** Redis-based
- **Context Quality Scoring** (4a fonte reward)
- **A2 Dark Bean Integration** (5/17 servizi integrati)
- Features avanzate: MCTS dispatch, Handoff Router, Factorised Beliefs, Logical Induction

Il v1 va sostituito con un v2 che rifletta l'architettura corrente (42 migrations, 63 analytics, 21 worker types).

## Vincoli Mermaid 8.8.2
WikiJS 2.x include Mermaid 8.8.2. Vincoli syntax:
- `graph` (mai `flowchart`)
- NO `&` chaining, NO `<-->`, NO subgraph-to-subgraph edges
- Quotare `<`, `>=`, `>` in nodi con `"..."`
- NO Unicode (`→`, `×`, `±`, `²`) — usare ASCII
- Edge solo tra nodi, mai tra subgraph ID

## Struttura del v2 — 10 diagrammi

### 1. Overview architetturale (graph TD)
I 4 piani + infrastruttura. Mostra i flussi principali tra nodi interni (no subgraph-to-subgraph).
- **Control Plane**: PlanController, CouncilService, PlannerService, OrchestrationService, RewardComputationService, LeaderElectionService
- **Execution Plane**: 21 WorkerType (raggruppati per categoria), AbstractWorker + PolicyEnforcingToolCallback
- **Service Bus**: Redis Streams (5 topic: agent-tasks, agent-reviews, agent-results, agent-events, agent-advisory)
- **MCP Layer**: 5 MCP servers (git, repo-fs, openapi, test, azure) + Allowlist + Redaction + Audit
- **Infrastructure**: PostgreSQL 18 (pgvector + AGE), Redis (Streams DB3, Cache DB5), Ollama

### 2. Dispatch Loop v2 (graph LR)
Aggiornato con:
- GP Worker Selection (UCB) prima del dispatch
- PID Adaptive Budget (non solo checkBudget statico)
- MCTS dispatch (opt-in)
- Global Assignment (Hungarian Algorithm, opt-in)
- LeaderElection guard

### 3. Worker Ecosystem (graph TD)
21 WorkerType organizzati in 4 categorie:
- **Domain** (7 tipi, 32 profili): BE x12, FE x6, DBA x10, MOBILE x2, AI_TASK, CONTRACT
- **Infrastructure** (9 tipi): CONTEXT_MANAGER, SCHEMA_MANAGER, HOOK_MANAGER, TASK_MANAGER, COMPENSATOR_MANAGER, RAG_MANAGER, AUDIT_MANAGER, EVENT_MANAGER, REVIEW
- **Advisory** (3 tipi): COUNCIL_MANAGER, MANAGER, SPECIALIST
- **Meta** (2): SUB_PLAN, RESEARCH_MANAGER

### 4. Reward Pipeline v2 (graph TD)
4 fonti di reward (era 3):
- Review Score (REVIEW worker)
- Process Score (deterministico)
- Quality Gate Score (post-completamento)
- **Context Quality Score** (information-theoretic, NUOVO)
- Bayesian aggregation -> ELO + DPO (3 strategie: cross-profile, retry, gp_residual_surprise)
- Token Ledger double-entry

### 5. Council System (graph LR)
- Submodular selection (CELF greedy) o LLM selection
- 4 manager fissi + 4 specialist dinamici
- Parallel advisory su agent-advisory topic
- CouncilReport synthesis -> PlannerService
- Taste Profile (GP per decomposition quality)
- Quadratic Voting (opt-in)

### 6. GP Engine + DPO (graph TD)
- Task embedding (1024 dim) -> GP prediction per profilo
- UCB selection (mu + C * sigma)
- Cold-start (<50 task -> uniform prior)
- Post-task: DPO pair generation con GP residual surprise
- Semantic Cache (embedding-based, Redis DB5)
- Ralph-Loop: sigma alta -> REVIEW pre-dispatch

### 7. RAG Engine (graph LR)
- Ingestion: chunking 512 + embedding 1024 -> pgvector + AGE (3 grafi)
- Retrieval: cosine + BM25 + graph traversal -> RRF (k=60) -> cascade reranker
- RAG_MANAGER worker (programmatic, no LLM)

### 8. Analytics Services (graph TD)
63 servizi raggruppati in 6 domini:
- Game Theory (7): Shapley, VCG, Contract Theory, Byzantine FT, Social Choice, Reputation Staking, Quadratic Voting
- Finance (6): Real Options, Prospect Theory, Kelly, Portfolio, Market Making, Token Economics
- Information Theory (6): Fisher, MDL, Information Bottleneck, BOCPD, Entropy Rate, Active Inference
- Control (5): MPC, PID, H-Infinity, Adaptive Budget, Curriculum
- Formal Methods (5): LTL, Petri Nets, CSP, Compressed Sensing, PAC-Bayes
- Complex Systems (5): Spin Glass, Stigmergy, Replicator, Sandpile, Edge of Chaos

### 9. Event Sourcing + SSE (graph LR)
Invariato dal v1, ma con:
- LeaderElection per event write safety
- TrackerSyncService update

### 10. State Machine (graph TD)
Plan states + Item states aggiornati:
- PlanStatus: PENDING, STARTED, COMPLETED, FAILED, PAUSED
- ItemStatus: WAITING, DISPATCHED, RUNNING, DONE, FAILED, AWAITING_APPROVAL, TO_DISPATCH

## File da creare/modificare
- **Nuovo**: `/wiki/data/repo/agent-framework/architecture/architecture-diagram-v2.md` (nuova pagina WikiJS)
- **Vecchio**: architecture-diagram.md resta come "v1 storico" con nota di redirect

## Approccio implementativo
1. Scrivere il file markdown completo con tutti i 10 diagrammi Mermaid 8.8.2-compatibili in `/tmp/architecture-diagram-v2.md`
2. `docker cp` nel container WikiJS
3. `git add + commit + push` nel repo Gitea
4. Creare la pagina WikiJS via GraphQL mutation `pages.create`
5. Aggiungere nota redirect nel v1

## Verifica
- Tutti e 10 i diagrammi si renderizzano senza errori
- Nessun "Syntax error in graph"
- Contenuto riflette l'architettura corrente (42 migrations, 63 analytics, 21 worker types)
- Persistente dopo restart WikiJS
