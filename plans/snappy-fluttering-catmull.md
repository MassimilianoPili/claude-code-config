# Piano: Agent Framework — Fase 12 (#97–#106)

## Context

Fase 11 (10 servizi, #87–#96) è completamente implementata e pushata.
Fase 12 introduce 10 servizi di "formal methods + reward theory + coordination" (#97–#106).
Suddivisa in due subphase: **12a** (6 servizi core) + **12b** (4 servizi avanzati).

**Stato codebase**:
- Analytics dir: `control-plane/orchestrator/src/main/java/com/agentframework/orchestrator/analytics/`
- 53 servizi esistenti (Fase 10–11). Nessun servizio Fase 12 ancora presente.
- `application.yml` già contiene blocchi `bayesian-surprise`, `potential-shaping`, `functional-analysis`, `process-mining` (pre-aggiunti). Mancano: `actor-model`, `chandy-lamport`, `ltl-verifier`, `description-logic`, `information-foraging`, `stigmergy`.
- Nessuna migration DB necessaria (tutti in-memory analytics su `task_outcomes`).

---

## Fase 12a — 6 servizi core

### #97 — BayesianSurpriseService (2.0g)

**File**: `analytics/BayesianSurpriseService.java`
**ConditionalOnProperty**: `bayesian-surprise.enabled`
**Dipendenze**: `TaskOutcomeRepository.findRewardsByWorkerType()`

**Algoritmo**:
- Modello Gaussiano: prior N(μ₀=0.5, σ₀²=1.0) (stesso di ThompsonSamplingSelector)
- Posterior update: μ_post, σ²_post via Bayesian update (precision weighting)
- KL divergence: KL(N(μ₁,σ₁²) ∥ N(μ₀,σ₀²)) = log(σ₀/σ₁) + (σ₁² + (μ₁−μ₀)²)/(2σ₀²) − 0.5
- z-score: (μ_post − μ₀) / σ₀
- Categoria: EXPECTED (|z| < 1.0), POSITIVE_SURPRISE (z ≥ 1.0), NEGATIVE_SURPRISE (z ≤ −1.0)

**Output**: `BayesianSurpriseReport(workerType, priorMean, priorVariance, posteriorMean, posteriorVariance, observations, klDivergence, zScore, surpriseCategory)`

---

### #99 — PotentialRewardShapingService (2.0g)

**File**: `analytics/PotentialRewardShapingService.java`
**ConditionalOnProperty**: `potential-shaping.enabled`
**Dipendenze**: `TaskOutcomeRepository.findRewardTimeseriesByWorkerType()`

**Algoritmo** (Ng, Harada, Russell 1999 — policy-invariant shaping):
- Potential Φ(i) = cumulative mean reward up to step i (progress signal)
- Shaped reward: F(s→s') = γ·Φ(s') − Φ(s) (intrinsic bonus, preserva optimal policy)
- Total reward: r_shaped = r_extrinsic + F
- Improvement ratio: Σ(r_shaped) / Σ(r_extrinsic)
- γ configurabile (default 0.99); conservatism: F ≥ 0 sempre (no negative shaping)

**Output**: `ShapedRewardReport(workerType, gamma, originalRewards, potentials, shapedRewards, totalExtrinsic, totalIntrinsicBonus, improvementRatio)`

---

### #100 — ActorModelSupervisor (2.5g)

**File**: `analytics/ActorModelSupervisor.java`
**ConditionalOnProperty**: `actor-model.enabled`
**Dipendenze**: `TaskOutcomeRepository.findRewardsByWorkerType()`, `TaskOutcomeRepository.findCompletionTimestampsByWorkerType()`

**Algoritmo** (Hewitt–Agha Actor Model):
- Ogni worker type = attore con mailbox = Redis Stream consumer group
- Mailbox depth proxy: task in RUNNING / in-flight stimato da completion rate
- Supervisor strategy: ONE_FOR_ONE (default), ONE_FOR_ALL, REST_FOR_ONE
- Anomaly detection: task con reward = 0 in sequenza → actor "crashed"
- Crash rate: % rewards = 0 per actor; backpressure: backlog > soglia (default 10)
- Raccomandata restart strategy in base a crash rate e correlazione inter-actor

**Output**: `ActorSystemReport(actors Map<String,ActorStatus>, supervisorStrategy, backpressureDetected, crashedActors, recommendations)`
**Inner record**: `ActorStatus(workerType, messagesProcessed, crashRate, avgReward, backpressured)`

---

### #101 — ChandyLamportSnapshotter (2.0g)

**File**: `analytics/ChandyLamportSnapshotter.java`
**ConditionalOnProperty**: `chandy-lamport.enabled`
**Dipendenze**: `TaskOutcomeRepository.findOutcomesByPlanId()`, `PlanEventRepository.findByPlanIdOrderBySequenceNumberAsc(UUID)`
**Import**: `com.agentframework.orchestrator.eventsourcing.PlanEventRepository`

**Algoritmo** (Chandy-Lamport 1985):
- Local state: task outcomes già registrati per il piano (completed/failed)
- Channel state: eventi TASK_DISPATCHED senza corrispondente TASK_COMPLETED in outcomes
  → task "in volo" al momento dello snapshot
- Consistent cut: un taglio è consistente se ogni msg ricevuto ha il send corrispondente catturato
- Orphaned tasks: in channel ma senza nessun outcome né evento di completamento
- snapshotId = UUID.randomUUID(), capturedAt = Instant.now()

**Output**: `SnapshotReport(snapshotId, planId, capturedAt, completedTaskKeys, inFlightTaskKeys, orphanedTaskKeys, isConsistent)`

---

### #102 — FixedPointAnalyzer (2.0g)

**File**: `analytics/FixedPointAnalyzer.java`
**ConditionalOnProperty**: `functional-analysis.enabled`
**Dipendenze**: `TaskOutcomeRepository.findRewardTimeseriesByWorkerType()`

**Algoritmo** (Banach Contraction Mapping + Tarski Fixed-Point Theorem):
- Operatore T: x_{n+1} = (α·x_n + μ_data) / (1 + α) dove α = prior weight (0.1)
- Contraction ratio L = sup |T(x)−T(y)| / |x−y| = α/(1+α) < 1 (garantito convergenza)
- Fixed point: x* = lim_{n→∞} T^n(x_0) = media pesata tra prior e sample mean
- Convergence curve: [iteration, |x_n − x*|] ogni 5 step
- Brouwer condition: Φ: [0,1] → [0,1] continua → fixed point garantito (reward in [0,1])
- converged: |x_n − x*| < ε (configurabile, default 0.001)

**Output**: `FixedPointReport(workerType, converged, fixedPointValue, contractionRatio, iterations, brouwerConditionMet, convergenceCurve List<double[]>)`

---

### #105 — LTLPolicyVerifier (2.0g)

**File**: `analytics/LTLPolicyVerifier.java`
**ConditionalOnProperty**: `ltl-verifier.enabled`
**Dipendenze**: `PlanEventRepository.findByPlanIdOrderBySequenceNumberAsc(UUID)`
**Import**: `com.agentframework.orchestrator.eventsourcing.PlanEventRepository`

**Algoritmo** (Linear Temporal Logic — finite trace semantics):
- Alfabeto eventi: TASK_DISPATCHED, TASK_STARTED, TASK_COMPLETED, TASK_FAILED, CONTEXT_REQUESTED
- LTL formule hard-coded (safety + liveness):
  1. **Safety S1**: ogni DISPATCHED → eventually (COMPLETED ∨ FAILED) per lo stesso task_key
  2. **Safety S2**: nessun COMPLETED prima di STARTED (no out-of-order)
  3. **Liveness L1**: ogni piano ha almeno un COMPLETED
  4. **Liveness L2**: no CONTEXT_REQUESTED infinito (al massimo 3 per task_key)
- Verifica per-plan su trace di eventi; counterexample = primo task_key violante
- Adherence score: fraction di formule soddisfatte

**Output**: `LTLVerificationReport(planId, traceLength, formulaResults Map<String,Boolean>, violations List<String>, counterexamples Map<String,String>, overallAdherence)`

---

## Fase 12b — 4 servizi avanzati

### #98 — ProcessMiningService (2.5g)

**File**: `analytics/ProcessMiningService.java`
**ConditionalOnProperty**: `process-mining.enabled`
**Dipendenze**: `TaskOutcomeRepository.findRewardsByWorkerType()` + `PlanEventRepository`

**Algoritmo** (van der Aalst — Alpha Algorithm semplificato):
- Event log: sequenze di worker_type per ogni piano (da `findPlanWorkerRewardSummary()`)
- Direct-follows relation: A >_L B se esiste traccia con A immediatamente prima di B
- Causality: A → B se A >_L B e not (B >_L A)
- Parallel: A ∥ B se A >_L B e B >_L A
- Choice: A # B se not (A >_L B) e not (B >_L A)
- Fitness: fraction di tracce replayabili sul modello scoperto
- Loop detection: cicli nel grafo causale

**Output**: `ProcessModelReport(directFollows Map<String,Set<String>>, causalRelations, parallelActivities Set<String[]>, choicePoints, fitness, loopDetected, discoveredSequences)`

---

### #103 — DescriptionLogicMatcher (2.0g)

**File**: `analytics/DescriptionLogicMatcher.java`
**ConditionalOnProperty**: `description-logic.enabled`
**Dipendenze**: nessuna repository (pura math, input dal CouncilService)

**Algoritmo** (ALC Description Logic — tableau semplificato):
- TBox (terminologia): gerarchia worker types (BE ⊑ BACKEND, FE ⊑ FRONTEND, DBA ⊑ DATA)
- ABox (asserzioni): worker capabilities per tipo (hasCapability assertions)
- Subsumption: C ⊑ D se ogni individuo di C appartiene anche a D
- Concept satisfiability: un concetto è soddisfacibile se esiste almeno un'istanza
- Task matching: dato TaskRequirement (concept expression), trova tutti i workerType soddisfacenti
- Explanation: catena di subsumption che giustifica il match

**Input**: `String requiredCapability`, `Map<String,Set<String>> workerCapabilities`
**Output**: `DLMatchReport(requiredCapability, matchedWorkers List<String>, subsumptionPaths Map<String,List<String>>, satisfiable boolean, explanation)`

---

### #104 — InformationForagingService (2.5g)

**File**: `analytics/InformationForagingService.java`
**ConditionalOnProperty**: `information-foraging.enabled`
**Dipendenze**: nessuna repository (pura math, ottimizzazione RAG chunk retrieval)

**Algoritmo** (Pirolli & Card 1999 — Patch Foraging Model):
- Information patch = documento con relevance score e costo di retrieval
- Information Rate = relevance_gain / retrieval_cost
- Marginal Value Theorem: continua in una patch finché IR_patch > IR_ambiente (media globale)
- Optimal patch residence: calcola quanti chunk estrarre da ogni patch
- Scent trail: pesi dei termini di query che "attraggono" verso le patch più ricche
- Stopping criterion: IR < IR_threshold (configurabile, default = media − σ)

**Input**: `List<ForagingPatch>` (id, relevanceScore, retrievalCost, chunkCount)
**Output**: `ForagingReport(patches con optimalChunks, globalInformationRate, stopThreshold, totalExpectedGain, patchRankings List<String>)`
**Inner record**: `ForagingPatch(patchId, relevanceScore, retrievalCost, chunkCount)` — input DTO

---

### #106 — StigmergyCoordinator (2.0g)

**File**: `analytics/StigmergyCoordinator.java`
**ConditionalOnProperty**: `stigmergy.enabled`
**Dipendenze**: `TaskOutcomeRepository.findRewardsByWorkerType()`, `TaskOutcomeRepository.findPlanWorkerRewardSummary()`

**Algoritmo** (Grassé 1959 + Dorigo ACO — Ant Colony Optimization):
- Pheromone matrix τ[taskType][workerType]: forza del percorso task→worker
- Deposit: τ[t][w] += Q·reward quando worker w completa task di tipo t con reward > 0
- Evaporation: τ[t][w] *= (1 − ρ) ogni update cycle (ρ = 0.1, configurabile)
- Selection probability: P(w|t) = τ[t][w]^α / Σ τ[t][w']^α (α = 1.0)
- Convergence: max_variance(τ) < ε (pheromone si stabilizza)
- Task type derivato da worker_type prefix (be-*, fe-*, dba-*, ...)

**Output**: `StigmergyReport(pheromoneMatrix Map<String,Map<String,Double>>, recommendedRoutes Map<String,String>, evaporationRate, convergenceDetected, topRoutes List<String>)`

---

## application.yml — blocchi da aggiungere (6 mancanti)

```yaml
actor-model:
  enabled: true
  backpressure-threshold: 10
  crash-rate-threshold: 0.3

chandy-lamport:
  enabled: true

ltl-verifier:
  enabled: true
  max-context-requests: 3

description-logic:
  enabled: true

information-foraging:
  enabled: true
  stop-threshold-sigma: 1.0

stigmergy:
  enabled: true
  evaporation-rate: 0.1
  pheromone-alpha: 1.0
  deposit-q: 1.0
```

*(I blocchi `bayesian-surprise`, `potential-shaping`, `functional-analysis`, `process-mining` sono già presenti.)*

---

## File da creare/modificare

| File | Azione |
|------|--------|
| `analytics/BayesianSurpriseService.java` | CREATE |
| `analytics/PotentialRewardShapingService.java` | CREATE |
| `analytics/ActorModelSupervisor.java` | CREATE |
| `analytics/ChandyLamportSnapshotter.java` | CREATE |
| `analytics/FixedPointAnalyzer.java` | CREATE |
| `analytics/LTLPolicyVerifier.java` | CREATE |
| `analytics/ProcessMiningService.java` | CREATE |
| `analytics/DescriptionLogicMatcher.java` | CREATE |
| `analytics/InformationForagingService.java` | CREATE |
| `analytics/StigmergyCoordinator.java` | CREATE |
| `src/main/resources/application.yml` | ADD 6 config blocks |

---

## Test (10 classi, ~80 test totali)

Struttura identica ai test Fase 11. Ogni classe copre: edge case (input vuoto/null), caso normale, caso limite, comportamento matematico atteso.

| Classe | Test chiave |
|--------|-------------|
| `BayesianSurpriseServiceTest` | prior-only, positive surprise, negative surprise, KL formula |
| `PotentialRewardShapingServiceTest` | reward shaping non-negative, gamma=1.0, improvement ratio |
| `ActorModelSupervisorTest` | crash detection, backpressure, ONE_FOR_ONE strategy |
| `ChandyLamportSnapshotterTest` | snapshot coerente, orphaned tasks, empty plan |
| `FixedPointAnalyzerTest` | convergenza garantita, contraction ratio < 1, Brouwer |
| `LTLPolicyVerifierTest` | safety S1/S2 violata, liveness, trace corretta |
| `ProcessMiningServiceTest` | sequential process, parallel activities, loop detected |
| `DescriptionLogicMatcherTest` | subsumption hierarchy, no match, satisfiability |
| `InformationForagingServiceTest` | optimal patch, stopping criterion, single patch |
| `StigmergyCoordinatorTest` | deposit + evaporation, convergence, recommended routes |

**Comando build**: `mvn clean install -pl control-plane/orchestrator -am`

---

## Dipendenze critiche

- **ChandyLamportSnapshotter (#101)** e **LTLPolicyVerifier (#105)** usano `PlanEventRepository`
  - Package: `com.agentframework.orchestrator.eventsourcing.PlanEventRepository`
  - Metodo: `findByPlanIdOrderBySequenceNumberAsc(UUID planId)`
- **ProcessMiningService (#98)**: usa `findPlanWorkerRewardSummary()` (già in TaskOutcomeRepository)
- **Tutti i servizi** usano `@ConditionalOnProperty` con `matchIfMissing = true`
