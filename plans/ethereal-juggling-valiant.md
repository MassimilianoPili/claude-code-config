# Piano: Sync Preference Sort dopo completamento task

## Context

Tutti i 9 task (#1-#9) sono COMPLETED in PostgreSQL, ma i loro item restano nella lista Preference Sort "Task Queue" perché `rank-sync` non è stato rieseguito dopo i completamenti. La sync rimuove gli item per task non più PENDING.

## Azione

```bash
claude-coord rank-sync
```

Questo rimuoverà tutti gli 8 item (erano 8 PENDING, ora 0) dalla lista PS. Output atteso: `+0 aggiunti, 0 invariati, 8 rimossi`.

## Task da implementare

| id | ref | tipo | prio | descrizione |
|----|-----|------|------|-------------|
| 2 | entropy-secret-scan | hook | 3 | Entropy check su scan-secrets-in-content.sh |
| 3 | complexity-gate | hook | 5 | Cognitive complexity su file modificati |
| 4 | behavior-verify | hook | 5 | Suggerimento test dopo edit significativo |
| 5 | context-drift-detector | hook | 5 | Contatore tool calls, reminder dopo N senza progress |
| 6 | compile-test-fix-skill | skill | 5 | Loop automatico compile→test→fix |
| 7 | progress-persist-tool | mcp-tool | 7 | Salva progress in claude_tasks |
| 8 | auto-memory-corrections | hook | 7 | Cattura correzioni utente → feedback memory |
| 9 | wiki-piano-update | docs | 8 | Aggiorna piano wiki con conteggi aggiornati |

## File critici

- Hook da modificare: `/data/massimiliano/.claude/hooks/scan-secrets-in-content.sh`
- Hook da creare: `/data/massimiliano/.claude/hooks/complexity-gate.sh`, `behavior-verify.sh`, `context-drift-detector.sh`
- Skill da creare: `/data/massimiliano/claude-shared/skills/compile-test-fix/SKILL.md`
- MCP tool: `/data/massimiliano/Vari/mcp/src/main/java/com/example/mcp/tools/ClaudeTaskQueueTools.java`
- Settings: `/data/massimiliano/claude-code-config/settings.json` (registrare nuovi hook)

## Approccio

Per ogni task: claim → implementa → test → complete → prossimo.
Usare `claude-coord claim <id> chat-69` prima, `claude-coord complete <id> success` dopo.

## Analisi novità (da ricerca S30)

### Cosa esiste (precedenti parziali)
- **RLHF**: BT reward model per ranking output LLM — strutturalmente identico ma per output, non task scheduling
- **Crowdsourced triage (MDPI 2020)**: BT per prioritizzare pazienti via AMT — più vicino ma dominio medico, non agenti
- **Defresne et al. (2025)**: BT + active learning per ottimizzazione combinatoria — scheduling-like ma one-shot, non queue persistente
- **Active Preference Optimization (2024, ~50 cit)**: contextual preference bandit — teorico, non implementato come sistema

### Cosa NON esiste (gap)
- Nessun sistema che combina: **durable task queue + BT model + IG pair selection + human-in-the-loop + AI agent execution**
- Nessun paper su "preference-aware scheduling" in contesto multi-agente/agentico
- Nessun sistema che usa SE (Standard Error) BT come confidence per scheduling decisions

### Contributi originali potenziali
1. **Architettura**: dual-write task queue (PG+Redis) con sync bidirezionale verso BT ranking engine
2. **Exponential prior washout**: transizione smooth priority numerica → BT (`decay = exp(-comps/tau)`)
3. **SE-based scheduling confidence**: schedule quando `SE(top) < 0.5 * gap_to_second` (UCB-like)
4. **Cold-start per task agentici**: binary-search seeding (confronta vs 25°/50°/75° percentile)
5. **Integration pattern**: RLHF-like pipeline applicato a task management (non LLM output)

## Valutazione pubblicabilità

### Tier assessment (in attesa conferma da agent verifica)

| Tier | Requisiti | Probabilità |
|------|-----------|-------------|
| **Workshop paper** (4-6 pp) | Sistema + evaluation su 30-50 task, 2-3 utenti | Alta |
| **Demo/systems paper** (2-4 pp) | Sistema funzionante + architettura + uso reale | Molto alta |
| **Full paper** (10-12 pp) | Studio utente formale, confronto con baseline, analisi convergenza | Media |

### Venue candidate

| Venue | Tipo | Deadline | Fit |
|-------|------|----------|-----|
| CHI Late-Breaking Work | HCI workshop | Gen/Feb | Alto — human-agent collaboration |
| NeurIPS FMDM Workshop | AI agents | Set | Alto — preference-based scheduling |
| CSCW | HCI/collaboration | Apr/Giu | Medio — cooperative work |
| ICSE NIER/Demo | SE demo | Ott | Medio — developer tools |
| UIST | HCI systems | Apr | Alto — interactive system |

### Lavoro minimo per paper

**Demo paper (2-4 pp, ~2 settimane)**:
1. Screenshot/video del sistema funzionante (già operativo)
2. Architettura diagram (già nel piano)
3. Caso d'uso reale: 8 task gestiti con BT ranking (già fatto)
4. Formalizzazione della decision rule SE-based
5. Breve related work section

**Workshop paper (4-6 pp, ~4 settimane)**:
1. Tutto il demo +
2. Evaluation su ~50 task reali gestiti nel corso di 2-4 settimane
3. Metriche: convergenza BT (quanti confronti per ranking stabile), concordanza ranking-esecuzione
4. Confronto con baseline (priority numerica statica, FIFO, round-robin)
5. User study minimo (N=1-3, self-report + task completion metrics)

**Full paper (10-12 pp, ~3 mesi)**:
1. Tutto il workshop +
2. Studio utente formale (N=10+, within-subjects design)
3. Analisi formale convergenza BT in small-data regime
4. Ablation: con/senza IG, con/senza SE-confidence, con/senza prior washout
5. Contributo teorico: formalizzazione "preference-aware scheduling" come framework

## Piano per progetti_futuri/

**Target: FULL PAPER** — "sbagliamo per imparare". Se in corso d'opera il full paper non regge, downgrade a workshop.

Creare `PIANO_PAPER_PREFERENCE_SCHEDULING.md` con:
- Titolo working: "PrefSched: Preference-Aware Task Scheduling for Human-Agent Collaboration via Active Pairwise Elicitation"
- Target primario: **CHI 2027** (deadline settembre 2026) o **CSCW 2027** (deadline gennaio 2027)
- Target secondario (fallback): NeurIPS FMDM Workshop 2026 o UIST 2027
- Effort: ~120h (3 mesi part-time)
- Costo: gratis (sistema già operativo)

### Struttura paper (10-12 pp)

1. **Introduction** (1.5 pp)
   - Problema: task queue per agenti AI con prioritizzazione statica
   - Gap: nessun sistema combina BT + IG + durable queue + agent execution
   - Contributo: PrefSched framework + 4 design insights

2. **Related Work** (2 pp)
   - BT models (Bradley & Terry 1952, Caron & Doucet 2012)
   - RLHF come preference scheduling (Azar et al. 2024)
   - Active preference elicitation (Defresne 2025, Bergstrom 2024)
   - Human-agent collaboration (TheAgentCompany, SWE-bench)
   - Task prioritization in SE (stack ranking, MoSCoW)

3. **System Design** (2 pp)
   - Architettura dual-write (PG + Redis)
   - Sync protocol task queue ↔ Preference Sort
   - Exponential prior washout formula
   - SE-based scheduling confidence (UCB-like)
   - Cold-start handling (binary-search seeding)

4. **User Study** (3 pp)
   - **Design**: within-subjects, 3 condizioni (FIFO, priority numerica, PrefSched)
   - **Partecipanti**: N=10-15 (sviluppatori che usano AI coding assistants)
   - **Task**: gestire 20-30 task generati da agenti AI per 2 settimane per condizione
   - **Metriche**:
     - Task completion rate (quanti task completati per sessione)
     - Subjective satisfaction (NASA-TLX, SUS)
     - Ranking concordance (Kendall tau tra ranking scelto e ranking post-hoc "ideale")
     - Convergenza BT (confronti necessari per ranking stabile)
     - Decision time (quanto tempo per scegliere il prossimo task)
   - **IRB**: necessario se N>1 esterno. Self-study (N=1) non richiede IRB formale

5. **Results & Analysis** (2 pp)
   - Confronto 3 condizioni su tutte le metriche
   - Ablation: con/senza IG, con/senza SE-confidence, con/senza prior washout
   - Convergenza analysis: quanti confronti servono per N task

6. **Discussion & Limitations** (1 pp)
   - Single-user vs multi-user
   - Scalabilità (O(n²) confronti)
   - Generalizzabilità oltre Claude Code

### Timeline (target CHI 2027, deadline ~settembre 2026)

| Mese | Attività |
|------|----------|
| Aprile 2026 | Raccolta dati N=1 (self-study, 4 settimane uso quotidiano) |
| Maggio 2026 | Reclutamento partecipanti (colleghi sviluppatori) + setup studio |
| Giugno 2026 | User study (2 settimane per condizione × 3) |
| Luglio 2026 | Analisi dati + scrittura |
| Agosto 2026 | Revisione + submission |

### Prerequisiti

- [x] Sistema task queue operativo (claude_tasks + Redis)
- [x] Preference Sort API con BT + IG (:8093)
- [x] Sync bidirezionale (claude-coord rank-sync)
- [x] CLI ranked view (claude-coord rank)
- [x] MCP tool RANKED filter (claude_task_list)
- [ ] 4 settimane di uso reale per dati pilota (Aprile)
- [ ] Implementare exponential prior washout nel ranking
- [ ] Implementare SE-based confidence indicator
- [ ] Logging dettagliato per metriche studio (decision time, confronti, task completion)
- [ ] Setup studio utente (consent form, task set, randomizzazione condizioni)
- [ ] Reclutamento N=10-15 partecipanti

### Rischi e mitigazioni

| Rischio | Probabilità | Mitigazione |
|---------|-------------|-------------|
| N insufficiente per significatività statistica | Media | Target N=15, accettabile N=10. Fallback: qualitative study |
| Effetto apprendimento tra condizioni | Media | Counterbalancing (Latin square), washout period |
| CHI reject per studio troppo piccolo | Alta | Fallback a CSCW (più tollerante) o workshop (NeurIPS FMDM) |
| Sistema non stabile per 6 settimane | Bassa | Già in produzione, dual-write resiliente |
| Nessun effetto significativo | Media | Contributo architetturale resta valido → systems paper |

## Architettura

```
┌──────────────────┐                    ┌──────────────────┐
│  claude_tasks    │  sync PENDING      │ Preference Sort  │
│  (PostgreSQL)    │ ──────────────────►│ API (:8093)      │
│                  │                    │                  │
│ #2 entropy-scan  │                    │ Lista: task-queue│
│ #3 complexity    │  ◄──── BT rank ───│ Item BT scores   │
│ #4 behavior      │                    │ Convergenza IG   │
│ ...              │                    └──────────────────┘
└──────────────────┘                            ▲
        │                                       │
        │ claude-coord queue --ranked           │ pairwise vote
        ▼                                       │
┌──────────────────┐                    ┌──────────────────┐
│  Claude session  │                    │  rank-tui        │
│  (chat-XX)       │                    │  (terminale)     │
│  "controlla coda"│                    │  utente vota     │
│  → ordine BT     │                    │  A vs B          │
└──────────────────┘                    └──────────────────┘
```

**Flusso**:
1. `claude-coord rank-sync` → sincronizza task PENDING con lista Preference Sort (crea/aggiorna)
2. Utente apre `rank-tui` → vota confronti a coppie tra task
3. `claude-coord queue --ranked` → ordina per BT score invece di priority numerica
4. Claude session → `claude_task_list("RANKED")` → ordine BT dalla lista PS

## Componenti da implementare

### 1. `claude-coord rank-sync` (nuovo subcomando CLI)

**File**: `/data/massimiliano/shell-scripts/bin/claude-coord` (estendere case)

```bash
claude-coord rank-sync   # Sync task PENDING → lista Preference Sort "task-queue"
```

Logica:
1. Query `claude_tasks` WHERE status='PENDING' → lista task
2. Cerca lista PS con category `task-queue` per l'utente (GET /lists)
3. Se non esiste → POST /lists `{name: "Task Queue", category: "task-queue"}`
4. Confronta item PS esistenti con task PENDING:
   - Nuovi task → POST /lists/{uuid}/items (name = `#{id} {ref} [{type}]`)
   - Task completati/cancellati → DELETE /lists/{uuid}/items/{itemUuid}
5. Output: stato sync (aggiunti/rimossi/invariati)

**Auth**: header `X-Auth-User-Id: f7294891-b031-432d-8382-8592d3e6b1aa` (hardcoded come in rank-tui)
**API base**: `http://127.0.0.1:8093` (localhost, dietro nginx su /rank/)

### 2. `claude-coord queue --ranked` (flag al subcomando esistente)

**File**: `/data/massimiliano/shell-scripts/bin/claude-coord` (estendere case `queue`)

Quando `--ranked`:
1. GET /lists → trova lista con category=task-queue
2. GET /lists/{uuid}/ranking → ottieni items ordinati per BT score
3. Mappa item name → task_id (pattern: `#<id> ...`)
4. JOIN con PostgreSQL per mostrare la tabella task ordinata per BT rank

Output:
```
=== Task PENDING (ordinati per preferenza) ===
 rank | id | ref               | tipo  | BT score | SE   | creato
 1    |  2 | entropy-secret    | hook  |    2.31  | 0.42 | 03-17
 2    |  5 | context-drift     | hook  |    1.87  | 0.55 | 03-17
 ...
```

### 3. MCP tool `claude_task_list` — nuovo filtro "RANKED"

**File**: `/data/massimiliano/Vari/mcp/src/main/java/com/example/mcp/tools/ClaudeTaskQueueTools.java`

Aggiungere al `switch(filter)`:
- `"RANKED"` → chiama API Preference Sort (HTTP client), ottieni ranking, JOIN con claude_tasks

Questo permette a Claude di dire `claude_task_list("RANKED")` e vedere l'ordine basato sulle preferenze dell'utente.

### 4. Mapping bidirezionale task_id ↔ item_uuid

**Schema naming**: item name in Preference Sort = `#<task_id> <ref> [<task_type>]`
Es: `#2 entropy-secret-scan [hook]`, `#6 compile-test-fix-skill [skill]`

Per il reverse mapping (BT score → task_id): parse del prefisso `#<id>` dal name.

**Colonne aggiuntive in `claude_tasks`**:
```sql
ALTER TABLE claude_tasks ADD COLUMN rank_item_uuid VARCHAR(100);   -- UUID item in Preference Sort
ALTER TABLE claude_tasks ADD COLUMN wiki_page_path VARCHAR(200);   -- Path pagina wiki collegata (es. 'agent-framework/architecture/claude-code-patterns')
```

- `rank_item_uuid`: mapping diretto al Preference Sort item (evita parsing del name)
- `wiki_page_path`: link alla pagina WikiJS con documentazione/contesto del task. Utile per:
  - La UI rank mostra il link wiki accanto al task per dare contesto durante il voto
  - Claude può leggere la pagina wiki per capire meglio il task prima di eseguirlo
  - `claude-coord queue` mostra la colonna wiki come link cliccabile

### 5. Campo wiki_page_path

Ogni task può avere un link opzionale a una pagina WikiJS che ne documenta il contesto. Esempi:
- Task `#2 entropy-secret-scan` → `wiki_page_path: 'agent-framework/architecture/claude-code-patterns'`
- Task `#6 compile-test-fix-skill` → `wiki_page_path: 'agent-framework/piano-fase-19'`

Uso:
- `claude-coord queue` mostra la colonna wiki come URL cliccabile
- `rank-tui` mostra `[wiki]` accanto ai task con pagina, per dare contesto durante il voto
- Claude può leggere la pagina wiki prima di eseguire il task
- `claude-coord enqueue` accetta un parametro opzionale `--wiki <path>`

### 5. Convergenza e lifecycle

- **Nuovi task**: `rank-sync` li aggiunge con `initial_rating: 1.0` (BT default). IG li selezionerà per confronti prioritari (alta SE → alta IG)
- **Task completati**: `rank-sync` li rimuove dalla lista PS. BT ricalcola automaticamente
- **Convergenza**: quando `converged: true` nella stats, il ranking è stabile. `claude-coord rank-sync` mostra `[CONVERGED]`
- **Cold start**: se 0 confronti fatti, `queue --ranked` fallback a priority numerica

## File da modificare

| File | Azione |
|------|--------|
| `/data/massimiliano/shell-scripts/bin/claude-coord` | Aggiungere `rank-sync` e flag `--ranked` a `queue` |
| `ClaudeTaskQueueTools.java` | Aggiungere filtro `RANKED` a `claude_task_list` |
| `claude_tasks` DDL | ALTER: `rank_item_uuid` + `wiki_page_path` |

## Verifica

1. `claude-coord rank-sync` → crea lista "Task Queue" con 8 item
2. `rank-tui` → selezionare lista "Task Queue" → votare 3-4 coppie
3. `claude-coord queue --ranked` → ordine diverso dalla priority numerica
4. Aggiungere un task → `claude-coord rank-sync` → nuovo item appare con alta SE
5. Completare un task → `claude-coord rank-sync` → item rimosso
6. `claude_task_list("RANKED")` via MCP → ordine BT

## Stima sforzo

| Componente | Sforzo |
|-----------|--------|
| `rank-sync` subcomando | 0.5g |
| `queue --ranked` flag | 0.5g |
| MCP tool filtro RANKED | 0.5g |
| Test E2E | 0.5g |
| **Totale** | **2g** |

---

## (Archivio) Piano precedente: Implementazioni Claude Code Mancanti

### A. Gap residui da Fasi 1-15 (10 item, ~13.5g)

| # | Nome | Stato | Cosa manca | Sforzo |
|---|------|-------|-----------|--------|
| 5 | SSE + TrackerSyncService | ❌ | `SseEmitterRegistry`, `TrackerSyncService`, `SpringPlanEvent` | 1g |
| 7 | Context Cache (TASK_MANAGER) | 🔧 | TASK_MANAGER worker (bloccato da tracker-mcp) | 1g |
| 8 | DAG + Mermaid UI | 🔧 | Miglioramenti frontend | 1g |
| 9 | Hierarchical Plans (SUB_PLAN) | 🔧 | Estensioni future | 3g |
| 10 | HookPolicy Extensions | ❌ | Record esteso, AWAITING_APPROVAL stato | 2g |
| 21 | Redis topic-per-workerType | ❌ | Nessuna implementazione | 1g |
| 33 | Token Economics Dashboard | 🔧 | Dashboard Grafana | 1g |
| 36 | Worker Pool Sizing Dashboard | 🔧 | Dashboard Grafana | 1.5g |
| 40 | Shapley Value Dashboard | 🔧 | Dashboard Grafana | 1g |
| 44 | Execution Sandbox | ❌ | Nessun codice (design completo in docs) | 3g |
| TM | TASK_MANAGER worker type | ❌ | Nuovo worker, intero modulo | 2g |

## B. Fasi 16-20 — NOT STARTED (50 item, ~117g)

Ricerca accademica completata (S25-S29), design pronti. Zero codice.

### Fase 16 — Operational Maturity (#137-#146) — 25g
| # | Titolo | Service | Sforzo |
|---|--------|---------|--------|
| 137 | Output Secret Scanner | `SecretScannerService` | 2g |
| 138 | Tenant Context Isolation | `TenantIsolationService` | 3g |
| 139 | Integration Test Framework | `PlanIntegrityTestFramework` | 2.5g |
| 140 | Human Correction Learning | `HumanCorrectionLearnerService` | 2.5g |
| 141 | Predictive Cost & Failure Forecaster | `PredictiveForecasterService` | 2.5g |
| 142 | Distributed Tracing Correlator | `DistributedTracingService` | 2g |
| 143 | Failure Pattern Predictor | `FailurePatternPredictorService` | 2.5g |
| 144 | Multi-Instance Plan Router | `PlanRoutingService` | 3g |
| 145 | Hierarchical Sub-Plan | `SubPlanOrchestrationService` | 2.5g |
| 146 | Plan Integrity Verifier | `PlanIntegrityVerifierService` | 2g |

### Fase 17 — Worker Autonomy (#147-#156) — 24g
| # | Titolo | Service | Sforzo |
|---|--------|---------|--------|
| 147 | Phased Worker Execution | `WorkerPhaseOrchestrator` | 2.5g |
| 148 | Worker Workspace Isolation | `WorkerWorkspaceManager` | 3g |
| 149 | Parallel Tool Orchestration | `ParallelToolCallingManager` | 2.5g |
| 150 | Mid-Execution Human Interaction | `HumanInteractionGateway` | 2.5g |
| 151 | Persistent Worker Memory | `WorkerEpisodicMemory` | 2.5g |
| 152 | Project Constraint Injection | `ProjectConstraintManager` | 2g |
| 153 | Information Flow Guard | `InformationFlowGuard` | 2.5g |
| 154 | Automated Validation Pipeline | `ValidationPipelineService` | 2.5g |
| 155 | Worker Progress Estimation | `WorkerProgressTracker` | 2g |
| 156 | Dynamic Tool Discovery | `DynamicToolRegistry` | 2g |

### Fase 18 — Production Intelligence (#157-#166) — 24g
| # | Titolo | Service | Sforzo |
|---|--------|---------|--------|
| 157 | Shared Workspace Blackboard | `SharedBlackboardService` | 2.5g |
| 158 | Worker Negotiation Protocol | `WorkerNegotiationService` | 3g |
| 159 | Production Feedback Collector | `ProductionFeedbackService` | 2.5g |
| 160 | Cost Accounting & Budget | `PlanCostAccountingService` | 2g |
| 161 | Adaptive Pipeline Configurator | `PipelineConfiguratorService` | 2.5g |
| 162 | Worker Self-Assessment | `WorkerSelfAssessmentService` | 2g |
| 163 | Conflict Resolution Arbiter | `ConflictResolutionArbiterService` | 2.5g |
| 164 | Canary Execution Strategy | `CanaryExecutionService` | 2.5g |
| 165 | Collaborative Code Understanding | `SharedCodeModelService` | 2.5g |
| 166 | Pipeline Degradation Manager | `DegradationManagerService` | 2g |

### Fase 19 — Code Quality Intelligence (#167-#176) — 23g
| # | Titolo | Service | Sforzo |
|---|--------|---------|--------|
| 167 | Output Secret Scanner | `SecretScannerService` | 2g |
| 168 | Reversibility Guard | `ReversibilityGuardService` | 2.5g |
| 169 | Project Instructions Injector | `ProjectInstructionsService` | 2g |
| 170 | Context Reminder Enricher | `ContextReminderEnricher` | 2g |
| 171 | Structured Progress Tracker | `StructuredProgressTracker` | 2.5g |
| 172 | Code Simplification Worker | `CodeSimplificationService` | 3g |
| 173 | Comment & Documentation Analyzer | `CommentAnalyzerService` | 2g |
| 174 | Technical Debt Estimator | `TechDebtEstimatorService` | 2.5g |
| 175 | Structural Complexity Gate | `ComplexityGateService` | 2g |
| 176 | Deferred Tool Loading Manager | `DeferredToolLoaderService` | 2.5g |

### Fase 20 — Execution Grounding (#177-#186) — 27g
| # | Titolo | Service | Sforzo |
|---|--------|---------|--------|
| 177 | Execution Runtime Orchestrator | `ExecutionRuntimeOrchestrator` | 3g |
| 178 | Cross-Plan Knowledge Transfer | `CrossPlanKnowledgeEngine` | 3g |
| 179 | Conversational Requirements Elicitor | `RequirementsElicitorService` | 2.5g |
| 180 | Multi-Plan Project Lifecycle | `ProjectLifecycleManager` | 3.5g |
| 181 | Longitudinal Effectiveness Benchmark | `EffectivenessBenchmarkService` | 2.5g |
| 182 | Self-Improving Prompt Optimizer | `SelfImprovingOptimizerService` | 3g |
| 183 | Architectural Visualization | `VisualizationGeneratorService` | 2g |
| 184 | External System Integration Hub | `ExternalIntegrationHubService` | 3g |
| 185 | Git Safety Protocol Enforcer | `GitSafetyProtocolService` | 2g |
| 186 | Compile-Test-Fix Loop | `CompileTestFixLoopService` | 2.5g |

## C. Correzioni critiche dalla ricerca

- **#167**: 2 livelli (regex+entropy → LLM validation), non solo regex
- **#172**: 19-35% refactoring LLM altera semantica → behavior preservation obbligatoria
- **#173**: DeBERTa NLI fuori distribuzione su codice → preprocessare code→NL
- **#157, #163**: NLI cross-encoder per contradiction, non cosine distance
- **#161**: BOHB/SMAC > GP-UCB per 20 dim
- **#162**: Temperature scaling (Guo 2017) > Platt scaling

## D. Mappatura Framework → Claude Code (implementabili direttamente)

Dall'audit dei 60 item mancanti, questi sono implementabili come **hooks, MCP tools, o script** senza toccare il framework Java:

### Tier 0 — Sicurezza & Quality (alta priorità, impatto immediato)

| # | Framework Item | Implementazione Claude Code | Tipo | Sforzo CC |
|---|---------------|---------------------------|------|-----------|
| 137/167 | Output Secret Scanner | **Hook PostToolUse**: regex+entropy su output Edit/Write. Layer 2: validate sospetti via LLM | hook | 0.5g |
| 168 | Reversibility Guard | **Hook PreToolUse**: classifica azioni per reversibilità (rm, git reset, DROP → block o confirm) | hook | 0.5g |
| 175 | Structural Complexity Gate | **Hook PostToolUse**: run `tree-sitter` + calcolo cognitive complexity su file modificati | hook | 1g |
| 172 | Code Simplification Worker | **Plugin già attivo** (`code-simplifier@claude-plugins-official`). Manca: behavior preservation check | hook | 0.5g |
| 173 | Comment & Doc Analyzer | **Plugin già attivo** (`pr-review-toolkit:comment-analyzer`). Manca: NLI code→NL preprocessing | tool | 0.5g |

### Tier 1 — Context & Intelligence

| # | Framework Item | Implementazione Claude Code | Tipo | Sforzo CC |
|---|---------------|---------------------------|------|-----------|
| 169 | Project Instructions Injector | **Già implementato**: CLAUDE.md + `session-context-loader.sh`. Manca: gerarchia directory-level | hook | 0.5g |
| 170 | Context Reminder Enricher | **Hook PostToolUse event-driven**: inietta system-reminder dopo N tool calls o su topic drift | hook | 0.5g |
| 151 | Persistent Worker Memory | **Già implementato**: MEMORY.md auto-memory system. Manca: memory per subagent | script | 0.5g |
| 176 | Deferred Tool Loading | **Già implementato**: `ToolSearch` built-in. Manca: EASYTOOL compression per tool descriptions | tool | 1g |
| 174 | Technical Debt Estimator | **MCP tool**: analizza file modificati, calcola debt score ibrido (structural+behavioral) | tool | 1.5g |

### Tier 2 — Execution & Automation

| # | Framework Item | Implementazione Claude Code | Tipo | Sforzo CC |
|---|---------------|---------------------------|------|-----------|
| 185 | Git Safety Protocol | **Già implementato**: `git-push-guard.sh` + `block-dangerous-commands.sh` + memory `feedback_no_destructive_git.md`. Completo ✅ | — | 0 |
| 186 | Compile-Test-Fix Loop | **Script/skill**: `compile-test-fix` loop automatico post-edit (mvn/npm/go) | skill | 1g |
| 171 | Structured Progress Tracker | **Già implementato**: `TodoWrite` tool. Manca: progress persistente cross-sessione via `claude_tasks` | tool | 0.5g |
| 155 | Worker Progress Estimation | **MCP tool**: stima % completamento basata su task decomposti + tempo trascorso | tool | 0.5g |
| 177 | Execution Runtime | **Già implementato**: Bash tool + mcp-bash-tool. Manca: sandbox isolation | script | 1g |

### Tier 3 — Collaborazione & Monitoring

| # | Framework Item | Implementazione Claude Code | Tipo | Sforzo CC |
|---|---------------|---------------------------|------|-----------|
| 140 | Human Correction Learning | **Hook**: cattura correzioni utente → salva in MEMORY.md feedback automaticamente | hook | 0.5g |
| 143 | Failure Pattern Predictor | **MCP tool già esistente**: `recovery_classify_failure`, `recovery_suggest_alternative`. Completo ✅ | — | 0 |
| 157 | Shared Workspace Blackboard | **Già implementato**: Redis `claude:inbox:*` messaging system. Completo ✅ | — | 0 |
| 159 | Production Feedback Collector | **MCP tool**: `meta_record_outcome`, `meta_surprise`. Completo ✅ | — | 0 |
| 162 | Worker Self-Assessment | **Già implementato**: `selfAssessment` pattern in explanatory output style. Manca: salvataggio strutturato | tool | 0.5g |

### Non applicabili a Claude Code (restano solo nel framework)

| # | Motivo |
|---|--------|
| 138 (Tenant Isolation) | Multi-tenant — Claude Code è single-user |
| 144 (Multi-Instance Router) | Orchestrazione distribuita |
| 148 (Worker Workspace) | JVM isolation |
| 153 (Information Flow Guard) | Enforced at framework level |
| 158 (Worker Negotiation) | Multi-worker protocol |
| 160 (Cost Accounting) | Budget enforcement Java |
| 161 (Pipeline Configurator) | BOHB/SMAC tuning |
| 163 (Conflict Resolution) | Multi-worker arbiter |
| 164 (Canary Execution) | Staged rollout |
| 178 (Knowledge Transfer) | Cross-plan DB queries |
| 180 (Project Lifecycle) | Multi-plan management |
| 181 (Effectiveness Benchmark) | Longitudinal metrics DB |
| 182 (Self-Improving Optimizer) | Prompt optimization pipeline |

## E. Piano di implementazione Claude Code

### Fase A — Sicurezza (1.5g)
1. **Hook `reversibility-guard.sh`** (PreToolUse Bash): classifica comandi per rischio, blocca irreversibili senza conferma
2. **Potenziare `scan-secrets-in-content.sh`**: aggiungere entropy check (layer 1 regex+entropy → layer 2 LLM se sospetto)

### Fase B — Quality Gates (2g)
3. **Hook `complexity-gate.sh`** (PostToolUse Edit/Write): tree-sitter + cognitive complexity su file .java/.go/.py/.ts modificati, warn se > soglia
4. **Hook `behavior-verify.sh`** (PostToolUse Edit): per refactoring, verifica che test esistenti passino ancora

### Fase C — Context Intelligence (1.5g)
5. **Gerarchia CLAUDE.md**: supportare `CLAUDE.md` a livello directory (già supportato da Claude Code, documentare pattern)
6. **Hook `context-drift-detector.sh`** (PostToolUse): contatore tool calls, inietta reminder se > N senza progress

### Fase D — Automation & Persistence (2g)
7. **Skill `compile-test-fix`**: loop automatico post-edit (detect language → compile → test → fix)
8. **MCP tool `claude_progress_persist`**: salva progress TodoWrite in `claude_tasks` per continuità cross-sessione
9. **Potenziare auto-memory**: cattura automatica correzioni utente ("no, non così" → feedback memory)

### Fase E — Documentation (0.5g)
10. **Aggiornare wiki** `claude-code-patterns`: P1-P28 → tutti ✅, aggiungere sezione 7 (P29-P34), aggiornare tabella priorità

## F. Riepilogo sforzo

| Fase | Item | Sforzo | Tipo |
|------|------|--------|------|
| A — Sicurezza | 2 hook | 1.5g | hook bash |
| B — Quality | 2 hook | 2g | hook bash + tree-sitter |
| C — Context | 2 item | 1.5g | hook + doc |
| D — Automation | 3 item | 2g | skill + MCP tool + hook |
| E — Documentation | 1 wiki page | 0.5g | PostgreSQL UPDATE |
| **Totale** | **10 item** | **7.5g** | |

## G. Verifica

- `shellcheck` su tutti i nuovi hook
- `claude-coord queue` → nessun task rotto
- Hook reversibility-guard: testare con `rm -rf` → deve bloccare
- Hook complexity-gate: testare con file > soglia CC → deve warn
- Wiki page: `curl` → contenuto aggiornato con sezione 7

**Obiettivo**: usare questa infrastruttura per:
1. Coordinare sessioni Claude e dirigere lavoro verso subagent tramite inbox Redis (`chat-<id>`)
2. **Accodare task per agenti futuri** non ancora determinati — la coda persiste e viene scodata dalla prossima sessione che si attiva
3. Duplicare ogni task su PostgreSQL per durabilità, audit trail e query — **pattern identico al framework** (Redis per dispatch, DB per stato)

---

## Architettura

```
┌──────────────────┐     claude_send        ┌──────────────────┐
│  MAIN SESSION    │ ──────────────────────► │  Redis DB 5      │
│  (chat-31)       │     pre-seed task       │  claude:inbox:    │
│                  │                         │   sub-31-research │
│  1. send task    │                         │   sub-31-test     │
│  2. launch Agent │                         │   chat-31         │
│  3. read results │ ◄────────────────────── │   __broadcast__   │
└──────────────────┘     claude_read         │   claude:registry │
        │                                    └──────────────────┘
        │ Agent tool                                 ▲
        ▼                                            │
┌──────────────────┐     claude_send(chat-31)       │
│  SUBAGENT        │ ───────────────────────────────┘
│  (general-purpose)│     result message
│                  │
│  1. claude_read  │
│  2. execute task │
│  3. claude_send  │
└──────────────────┘
```

**Pattern principale**: pre-seed inbox → launch subagent → subagent reads inbox → executes → writes result → main reads result.

### Coda Durabile (Task per agenti futuri)

```
┌──────────────┐  claude_task_enqueue   ┌───────────┐   INSERT    ┌──────────────┐
│  ANY SESSION │ ─────────────────────► │ Redis DB5 │ ──────────► │ PostgreSQL   │
│  o CLI       │                        │ claude:   │             │ claude_tasks │
│              │                        │  taskq    │             │ (durabile)   │
└──────────────┘                        └───────────┘             └──────────────┘
                                              │                          │
                                    BRPOP / scan                  SELECT pending
                                              │                          │
                                              ▼                          ▼
                                   ┌──────────────┐            UPDATE status
                                   │ FUTURE       │ ──────────► claimed_by,
                                   │ SESSION      │             completed_at
                                   │ (chat-42)    │
                                   └──────────────┘
```

**Dual-write**: ogni task va sia in Redis (dispatch veloce) che in PostgreSQL (persistenza + audit).
**Nessun auto-claim**: la sessione futura NON scoda automaticamente. L'utente chiede esplicitamente "controlla la coda", vede la lista con spiegazioni, e sceglie quali task scodare.
**Durabilità**: se Redis perde il messaggio (restart), `claude_task_list` legge direttamente da PostgreSQL (source of truth), non da Redis.

---

## Fase 0: Tabella `claude_tasks` su PostgreSQL [20 min]

### 0.1 Migrazione Flyway

**File**: Non serve Flyway (non è nel framework orchestrator). Eseguiamo DDL diretto su `embeddings` DB, come per `chat_sessions`.

```sql
CREATE TABLE IF NOT EXISTS claude_tasks (
    task_id         BIGSERIAL PRIMARY KEY,
    ref             VARCHAR(100) NOT NULL,          -- correlation slug (es. "research-gp")
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING',  -- PENDING, CLAIMED, COMPLETED, FAILED, CANCELLED
    priority        SMALLINT NOT NULL DEFAULT 5,    -- 1 (urgente) → 10 (bassa)

    -- Envelope (duplicato da Redis per durabilità)
    task_type       VARCHAR(50) NOT NULL,           -- es. "research", "code-review", "deploy"
    payload_json    JSONB NOT NULL,                 -- {task, context, constraints}

    -- Targeting
    target_label    VARCHAR(100),                   -- NULL = qualsiasi sessione, "chat-31" = specifica
    required_role   VARCHAR(50),                    -- NULL = nessun requisito, "researcher" = solo sessioni con quel ruolo

    -- Redis tracking
    redis_key       VARCHAR(200),                   -- chiave Redis dove è stato pushato (es. "claude:taskq" o "claude:inbox:sub-31-x")
    dispatched_at   TIMESTAMPTZ,                    -- quando pushato in Redis (NULL = solo su DB, non dispatched)

    -- Tracking
    created_by      VARCHAR(100) NOT NULL,          -- "chat-31" o "cli" o "framework"
    claimed_by      VARCHAR(100),                   -- "chat-42" quando scodato
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    claimed_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,

    -- Risultato
    result_json     JSONB,                          -- payload del result message
    error_message   TEXT,

    CONSTRAINT valid_status CHECK (status IN ('PENDING','CLAIMED','COMPLETED','FAILED','CANCELLED'))
);

CREATE INDEX idx_claude_tasks_pending ON claude_tasks (priority, created_at) WHERE status = 'PENDING';
CREATE INDEX idx_claude_tasks_claimed ON claude_tasks (claimed_by, claimed_at) WHERE status = 'CLAIMED';
CREATE INDEX idx_claude_tasks_dispatched ON claude_tasks (dispatched_at) WHERE dispatched_at IS NOT NULL AND status NOT IN ('COMPLETED', 'FAILED', 'CANCELLED');
CREATE INDEX idx_claude_tasks_ref ON claude_tasks (ref);
```

### 0.2 Redis key per la coda

- **Key**: `claude:taskq` (Redis LIST, come inbox ma dedicata)
- **Formato**: JSON con `task_id` di PostgreSQL per correlazione: `{"task_id": 42, "ref": "research-gp", "priority": 5, "payload": {...}}`
- **TTL**: nessuno (la coda persiste finché non scodata; PostgreSQL è il backup se Redis perde dati)

---

## Fase 1: Session Registry Hook [30 min]

### 1.1 Nuovo hook: `session-registry.sh`
**File**: `/data/massimiliano/.claude/hooks/session-registry.sh`

Al SessionStart: query PostgreSQL per `chat_id`, scrive entry in Redis HASH `claude:registry`. Al Stop: rimuove entry.

```bash
#!/bin/bash
# Hook: session-registry.sh — registra/deregistra sessione in Redis HASH
MODE="${1:-startup}"
INPUT=$(cat 2>/dev/null || true)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$SESSION_ID" ] && exit 0

PSQL="docker exec postgres psql -U postgres -d embeddings -tAq"
REDIS="docker exec redis redis-cli -n 5"

case "$MODE" in
  startup|resume)
    CHAT_ID=$($PSQL -c "SELECT chat_id FROM chat_sessions WHERE session_id = '${SESSION_ID}';" 2>/dev/null)
    [ -z "$CHAT_ID" ] && exit 0
    PROJECT=$(echo "$INPUT" | jq -r '.cwd // "/data/massimiliano"' 2>/dev/null)
    LABEL="chat-${CHAT_ID}"
    NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    REG_JSON=$(jq -nc --argjson cid "$CHAT_ID" --arg sid "$SESSION_ID" \
      --arg proj "$PROJECT" --arg now "$NOW" \
      '{chatId:$cid, sessionId:$sid, project:$proj, role:"main", startedAt:$now}')
    $REDIS HSET claude:registry "$LABEL" "$REG_JSON" >/dev/null 2>&1
    ;;
  stop)
    CHAT_ID=$($PSQL -c "SELECT chat_id FROM chat_sessions WHERE session_id = '${SESSION_ID}';" 2>/dev/null)
    [ -z "$CHAT_ID" ] && exit 0
    $REDIS HDEL claude:registry "chat-${CHAT_ID}" >/dev/null 2>&1
    ;;
esac
exit 0
```

### 1.2 Modifica `settings.json` hooks

Aggiungere `session-registry.sh` DOPO `chat-tracker.sh` (dipende dal chat_id già inserito):

**SessionStart startup**: aggiungere `session-registry.sh startup` dopo chat-tracker
**SessionStart resume**: aggiungere `session-registry.sh resume` dopo chat-tracker
**Stop**: aggiungere `session-registry.sh stop` (async, prima di stop-reminder)

File: `/home/massimiliano/.claude/settings.json` — sezione `hooks`

---

## Fase 2: Protocollo Messaggi [20 min]

### 2.1 Envelope JSON

Tutti i messaggi sono JSON:

```json
{
  "v": 1,
  "type": "task|result|progress|signal",
  "from": "chat-31",
  "ts": "2026-03-15T18:30:00Z",
  "ref": "research-gp",
  "payload": { ... }
}
```

### 2.2 Tipi di messaggio

| Tipo | Direzione | Payload |
|------|-----------|---------|
| `task` | main → subagent | `{task, context, constraints, replyTo}` |
| `result` | subagent → main | `{task, status, summary, artifacts, errors}` |
| `progress` | subagent → main | `{task, pct, note}` |
| `signal` | any → any | `{signal: "cancel\|ping\|ack", data}` |

### 2.3 Schema indirizzamento

- **Main session**: `chat-<chat_id>` (es. `chat-31`)
- **Subagent inbox**: `sub-<chat_id>-<task>` (es. `sub-31-research`)
- **Broadcast**: `__broadcast__` (esistente, TTL 1h)
- **Registry**: Redis HASH `claude:registry` (field = label, value = JSON)

---

## Fase 3: Template Subagent Protocol [20 min]

### 3.1 Nuovo file: `subagent-protocol.md`
**File**: `/data/massimiliano/claude-shared/agents/templates/subagent-protocol.md`

Template da includere nel prompt dei subagent coordinati:

```markdown
## Protocollo Coordinamento

Sei un subagent coordinato. La tua label è `{{LABEL}}`.

### All'avvio
1. Chiama `claude_read("{{LABEL}}")` per ricevere l'assegnazione
2. Parsa il JSON envelope, estrai `payload.task` e `payload.context`
3. `payload.replyTo` indica dove inviare i risultati

### Al completamento
Prima di restituire la risposta, chiama `claude_send("{{REPLY_TO}}", result)` con:
{"v":1, "type":"result", "from":"{{LABEL}}", "ref":"{{REF}}",
 "payload":{"task":"...", "status":"success|partial|failed", "summary":"...", "artifacts":[], "errors":[]}}
```

### 3.2 Pattern di uso nel main

```python
# 1. Pre-seed inbox
claude_send("sub-31-research", json.dumps({
  "v": 1, "type": "task", "from": "chat-31",
  "ref": "gp-literature",
  "payload": {
    "task": "Survey GP worker selection literature",
    "context": "...",
    "replyTo": "chat-31"
  }
}))

# 2. Launch subagent con protocollo nel prompt
Agent(prompt="... Segui il protocollo in subagent-protocol.md. La tua label è sub-31-research. ...",
      subagent_type="general-purpose", run_in_background=True)

# 3. Dopo completamento, leggi risultati
claude_read("chat-31")
```

---

## Fase 4: CLI `claude-coord` [30 min]

**File**: `/data/massimiliano/shell-scripts/bin/claude-coord`

Pattern dal CLI `chat` esistente. Subcomandi:

```bash
# Registry & messaging
claude-coord status          # HGETALL claude:registry → tabella sessioni attive
claude-coord send <id> <msg> # LPUSH claude:inbox:chat-<id>
claude-coord peek <id>       # LRANGE (non distruttivo) inbox chat-<id>
claude-coord inboxes         # KEYS claude:inbox:* con dimensioni
claude-coord cleanup         # Rimuove entry registry > 24h

# Task queue (dual: Redis + PostgreSQL)
claude-coord enqueue <ref> <type> <payload>  # INSERT + LPUSH
claude-coord queue                            # SELECT PENDING tasks
claude-coord claim <task-id> <chat-id>          # UPDATE CLAIMED (per task scelto)
claude-coord complete <task-id> <result>      # UPDATE COMPLETED
claude-coord history [N]                      # Ultimi N task completati
```

---

## Fase 5: Tool Java — Registry + Task Queue [45 min]

**File**: `/data/massimiliano/Vari/mcp-redis-tools/src/main/java/.../RedisTools.java`

### 5.1 Tool registry (come prima)

```java
@ReactiveTool(name = "claude_who",
    description = "Elenca le sessioni Claude attive registrate nel registry.")
public Mono<Map<String, String>> claudeWho() {
    return msg.opsForHash().entries("claude:registry")
        .collectMap(e -> e.getKey().toString(), e -> e.getValue().toString());
}

@ReactiveTool(name = "claude_register",
    description = "Registra la sessione corrente nel registry con ruolo e capacità.")
public Mono<String> claudeRegister(String label, String role, String capabilities) {
    // HSET claude:registry <label> <json>
}
```

### 5.2 Tool task queue (NUOVI — dual-write Redis + PostgreSQL)

```java
@ReactiveTool(name = "claude_task_enqueue",
    description = "Accoda un task per un agente futuro. Dual-write: Redis (dispatch) + PostgreSQL (durabilità). "
        + "Se targetLabel è null, qualsiasi sessione futura può scodarlo.")
public Mono<String> claudeTaskEnqueue(
    @ToolParam(description = "Slug di correlazione (es. 'research-gp')") String ref,
    @ToolParam(description = "Tipo di task (es. 'research', 'code-review')") String taskType,
    @ToolParam(description = "Payload JSON del task") String payloadJson,
    @ToolParam(description = "Label sessione creante (es. 'chat-31')") String createdBy,
    @ToolParam(description = "Label destinatario specifico (null = chiunque)", required = false) String targetLabel,
    @ToolParam(description = "Priorità 1-10 (default 5)", required = false) Integer priority) {
    // 1. INSERT in PostgreSQL (redis_key=NULL, dispatched_at=NULL) → ottieni task_id
    // 2. LPUSH in claude:taskq con task_id per correlazione
    // 3. UPDATE claude_tasks SET redis_key='claude:taskq', dispatched_at=now() WHERE task_id=?
    // 4. Return "Task #<task_id> enqueued (DB + Redis)"
    //
    // Se Redis fallisce: task resta in PostgreSQL con dispatched_at=NULL → scodabile via DB query
}

@ReactiveTool(name = "claude_task_claim",
    description = "Prende in carico un task specifico (scelto dall'utente dopo aver visto la lista). "
        + "Aggiorna PostgreSQL: status=CLAIMED, claimed_by, claimed_at.")
public Mono<String> claudeTaskClaim(
    @ToolParam(description = "ID del task da prendere in carico") Long taskId,
    @ToolParam(description = "Label della sessione (es. 'chat-42')") String claimedBy) {
    // UPDATE claude_tasks SET status='CLAIMED', claimed_by=?, claimed_at=now() WHERE task_id=? AND status='PENDING'
    // Return task payload JSON
}

@ReactiveTool(name = "claude_task_complete",
    description = "Marca un task come completato con il risultato.")
public Mono<String> claudeTaskComplete(
    @ToolParam(description = "ID del task") Long taskId,
    @ToolParam(description = "Status: success, partial, failed") String status,
    @ToolParam(description = "Risultato JSON") String resultJson) {
    // UPDATE claude_tasks SET status=?, result_json=?, completed_at=now()
}

@ReactiveTool(name = "claude_task_list",
    description = "Lista task per status (default PENDING). Mostra coda lavoro disponibile. "
        + "Status speciale 'DISPATCHED' = in Redis ma non completati (dispatched_at NOT NULL, status != COMPLETED).")
public Mono<List<String>> claudeTaskList(
    @ToolParam(description = "Filtro: PENDING, CLAIMED, COMPLETED, DISPATCHED, ALL", required = false) String status) {
    // DISPATCHED → SELECT WHERE dispatched_at IS NOT NULL AND status NOT IN ('COMPLETED','FAILED','CANCELLED')
    // PENDING → SELECT WHERE status = 'PENDING'
    // ALL → no filter
    // ORDER BY priority, created_at
}
```

### 5.3 `claude_task_list` legge da PostgreSQL (source of truth)

`claude_task_list` non dipende da Redis — interroga direttamente PostgreSQL. Questo rende il sistema resistente a restart Redis. Redis `claude:taskq` è solo un canale di notifica opzionale, non la fonte autoritativa.

L'utente chiede esplicitamente "controlla la coda" → Claude chiama `claude_task_list("PENDING")` → mostra lista con spiegazioni → l'utente sceglie → Claude chiama `claude_task_claim(taskId, "chat-X")` per i task scelti.

**Nessun auto-claim, nessuna notifica automatica al SessionStart.** L'iniziativa è sempre dell'utente.

Richiede `deploy-mcp` dopo modifica.

---

## Fase 6: Test End-to-End [20 min]

Test manuale:

1. Verificare che `claude:registry` ha un entry per la sessione corrente (via `claude_who` o `claude-coord status`)
2. Pre-seed: `claude_send("sub-TEST-ping", '{"v":1,"type":"task","from":"chat-X","ref":"ping","payload":{"task":"Read your inbox and reply","replyTo":"chat-X"}}')`
3. Launch subagent `general-purpose` con prompt che include il protocollo
4. Verificare che `claude_read("chat-X")` ritorna il result message

---

## Coordination Patterns

### Pattern A: Main → Subagent (caso principale)
Pre-seed → launch → subagent reads → executes → writes result → main reads

### Pattern B: Fan-out parallelo
Main pre-seeds N inbox → launches N background subagents → reads N results

### Pattern C: Multi-sessione
Due terminali con `chat-29` e `chat-31` si scambiano messaggi direttamente via `claude_send`/`claude_read`

### Pattern D: Pipeline
Subagent A scrive nella inbox di subagent B come ultima azione → main lancia B

### Pattern E: Task Queue per agenti futuri (NUOVO)
Qualsiasi sessione accoda task con `claude_task_enqueue` → PostgreSQL (+ opzionale Redis notifica).
I task restano in PostgreSQL indefinitamente finché l'utente non chiede di controllarli.
**L'iniziativa è sempre dell'utente** — nessun auto-claim.

```
Sessione chat-31 (oggi):
  claude_task_enqueue("deploy-check", "ops", '{"task":"Verify orchestrator health"}', "chat-31")
  claude_task_enqueue("test-council", "test", '{"task":"Run council on sample spec"}', "chat-31")
  → Sessione termina

Sessione chat-42 (domani):
  Utente: "controlla se ci sono task in coda"
  Claude: claude_task_list("PENDING") → mostra:
    #1 deploy-check  [ops]     prio:5  da chat-31  "Verify orchestrator health"
    #2 test-council  [test]    prio:5  da chat-31  "Run council on sample spec"
  Utente: "fai il primo"
  Claude: claude_task_claim(1, "chat-42")  → status=CLAIMED
  → Esegue il task
  Claude: claude_task_complete(1, "success", '{"summary":"Health UP, 36 migrations OK"}')
```

---

## File da creare/modificare

| File | Azione | Fase |
|------|--------|------|
| DDL `claude_tasks` su `embeddings` DB | ESEGUIRE | 0 |
| `/data/massimiliano/.claude/hooks/session-registry.sh` | CREARE | 1 |
| `/home/massimiliano/.claude/settings.json` (hooks) | MODIFICARE | 1 |
| `/data/massimiliano/claude-shared/agents/templates/subagent-protocol.md` | CREARE | 3 |
| `/data/massimiliano/shell-scripts/bin/claude-coord` | CREARE | 4 |
| `/data/massimiliano/Vari/mcp-redis-tools/.../RedisTools.java` | MODIFICARE (6 nuovi tool) | 5 |

## File esistenti da riusare

| File | Ruolo |
|------|-------|
| `/data/massimiliano/.claude/hooks/chat-tracker.sh` | Fonte del chat_id, pattern hook |
| `/data/massimiliano/shell-scripts/bin/chat` | Pattern CLI (psql/redis queries) |
| `/data/massimiliano/Vari/mcp-redis-tools/.../RedisTools.java` | 5 tool esistenti, template `msg` per DB 5 |
| `/data/massimiliano/Vari/mcp-redis-tools/.../RedisConfig.java` | `mcpRedisMessagingTemplate` (DB 5) |

## Verifica

- `docker exec redis redis-cli -n 5 HGETALL claude:registry` → mostra sessione corrente
- `claude_list_inboxes()` → mostra inbox non vuote dopo pre-seed
- Subagent completa e scrive result → `claude_read("chat-X")` ritorna JSON
- `claude-coord status` → tabella formattata sessioni attive
- `claude_task_enqueue(...)` → INSERT in PostgreSQL + LPUSH in Redis
- `claude-coord queue` → mostra task PENDING
- `claude_task_claim(taskId, "chat-X")` → UPDATE CLAIMED (task scelto dall'utente)
- `claude_task_complete(id, "success", result)` → UPDATE COMPLETED
- `claude_task_list("DISPATCHED")` → mostra task in Redis ma non completati (per scodare selettivamente)
- Restart Redis → `claude_task_list("PENDING")` legge da PostgreSQL → nessun task perso (redis_key/dispatched_at traccia stato dispatch)
