# Piano — Fase 20d: Measurement & Output (#181 + #183)

## Context

Fasi 20a (Execution Grounding), 20b (Intelligence & Learning), 20c (Lifecycle & Integration) completate.
~58 nuovi file, V34-V41, BUILD SUCCESS. KORE aggiornato.

Fase 20d chiude il ciclo Fase 20 con **osservabilità longitudinale** e **output visuale**:
- Il framework ora sa se sta migliorando nel tempo (benchmark)
- Gli operatori possono visualizzare la struttura dei piani (graph rendering)

## Infrastruttura esistente da riusare

| Componente | File | Ruolo per 20d |
|-----------|------|---------------|
| `task_outcomes` (V8) | GP engine tabella | Data source primaria: embedding, gp_mu, actual_reward, context_quality_score |
| `plan_items` (V1+V4) | reward signals | reviewScore, processScore, aggregatedReward, durate |
| `plan_event` (V3) | event store | Timeline eventi per contare completamenti/fallimenti per bucket temporale |
| `worker_elo_stats` (V4) | ELO tracking | Progressione ELO per worker profile |
| `PlanGraphService` | `graph/PlanGraphService.java` | Mermaid + JSON rendering esistente per singolo plan (da comporre, non modificare) |
| `CriticalPathCalculator` | `graph/CriticalPathCalculator.java` | Topological sort + tropical scheduling, ScheduleView DTO |
| `BocpdService` | `analytics/bocpd/BocpdService.java` | Changepoint detection opzionale per trend analysis |
| `OrchestratorMetrics` | `metrics/OrchestratorMetrics.java` | Pattern Micrometer: Counter/Timer/Gauge con ConcurrentHashMap |
| `PlanArchetypeRegistry` | `analytics/metalearning/` | Semantic plan similarity per grouping nella visualization |

---

## #181 — Longitudinal Effectiveness Benchmark (V42)

### Package: `orchestrator.benchmark`

| File | Responsabilità |
|------|---------------|
| `BenchmarkConfig.java` | @ConfigurationProperties(prefix="benchmark"): snapshot (intervalMinutes=60, retentionDays=90), metrics (tracked list: REWARD_MEAN, COMPLETION_RATE, DURATION_P95, GP_ACCURACY, ELO_PROGRESSION), trend (windowSize=30, regressionMinPoints=5) |
| `EffectivenessSnapshot.java` | Record: id, bucketStart, bucketEnd, metricName, sampleCount, mean, p50, p95, stddev, rawJson JSONB. Immutable, one row per metric per bucket |
| `BenchmarkCollector.java` | @Scheduled collector: queries task_outcomes + plan_items + worker_elo_stats. Aggrega per time bucket configurabile. Calcola: reward mean/p50/p95, completion rate, duration stats, GP prediction accuracy (|actual-predicted|/actual), ELO delta. Salva snapshot |
| `TrendAnalyzer.java` | OLS linear regression su serie di snapshot. Output: slope, r², direction (IMPROVING/DEGRADING/STABLE), confidence interval. Integrazione opzionale con BocpdService per changepoint detection |
| `BenchmarkRepository.java` | JdbcTemplate: saveSnapshot(), findByMetricAndRange(), findLatestByMetric(), deleteOlderThan() (retention) |
| `BenchmarkController.java` | @RestController `/api/v1/benchmark`: GET /snapshots, GET /trends, POST /snapshot (manual trigger) |

### Migration V42

```sql
CREATE TABLE effectiveness_snapshots (
    id              UUID PRIMARY KEY,
    bucket_start    TIMESTAMPTZ NOT NULL,
    bucket_end      TIMESTAMPTZ NOT NULL,
    metric_name     VARCHAR(50) NOT NULL,
    sample_count    INT NOT NULL DEFAULT 0,
    mean            DOUBLE PRECISION,
    p50             DOUBLE PRECISION,
    p95             DOUBLE PRECISION,
    stddev          DOUBLE PRECISION,
    raw_detail      JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_eff_snap_metric_bucket ON effectiveness_snapshots(metric_name, bucket_start DESC);
CREATE INDEX idx_eff_snap_created ON effectiveness_snapshots(created_at);
```

### Dipendenze
- `JdbcTemplate` — query dirette su task_outcomes, plan_items, worker_elo_stats, plan_event
- `BocpdService` via `@Nullable` — changepoint detection opzionale su trend
- `MeterRegistry` via `@Nullable` — metriche `benchmark_*`

### Design decisions
1. **JSONB `raw_detail`** per metriche custom senza schema change — standard time-series-over-relational
2. **OLS regression** per trend analysis — heuristic-first, BOCPD per sophisticazione opzionale
3. **@Scheduled** snapshot collection — stesso pattern di SagaPlanSequencer e BocpdService
4. **GP prediction accuracy**: `|actual_reward - gp_mu| / max(actual_reward, 0.01)` — misura quanto il GP è calibrato
5. **Retention cleanup** via snapshot age — `deleteOlderThan(retentionDays)` chiamato dopo ogni snapshot batch
6. **Controller separato** da PlanController — feature isolata, non modifica file esistenti

### Algoritmo chiave: BenchmarkCollector

```
Per ogni snapshot interval:
  1. Calcola bucket_start = floor(now, intervalMinutes), bucket_end = bucket_start + interval
  2. Per REWARD_MEAN: SELECT avg(aggregated_reward), percentile_cont(0.5/0.95) FROM plan_items WHERE completed_at IN [bucket_start, bucket_end]
  3. Per COMPLETION_RATE: COUNT(status='DONE') / COUNT(*) FROM plan_items WHERE dispatched_at IN bucket
  4. Per DURATION_P95: percentile su (completed_at - dispatched_at) FROM plan_items WHERE completed_at IN bucket
  5. Per GP_ACCURACY: avg(abs(actual_reward - gp_mu) / greatest(actual_reward, 0.01)) FROM task_outcomes WHERE created_at IN bucket
  6. Per ELO_PROGRESSION: delta elo_rating per top-5 profili confronto con bucket precedente
  7. Salva un EffectivenessSnapshot per ogni metrica
```

### Algoritmo chiave: TrendAnalyzer (OLS)

```
Input: List<EffectivenessSnapshot> ordinati per bucket_start
  1. x[i] = i (ordinal index), y[i] = snapshot.mean
  2. slope = (n*Σxy - Σx*Σy) / (n*Σx² - (Σx)²)
  3. intercept = (Σy - slope*Σx) / n
  4. r² = (slope * (Σxy - Σx*Σy/n))² / (Σy² - (Σy)²/n) / (Σx² - (Σx)²/n)
  5. direction: |slope| < threshold → STABLE, slope > 0 → IMPROVING, slope < 0 → DEGRADING
  6. Se BocpdService disponibile: osserva ogni nuovo mean, segnala changepoint
```

---

## #183 — Architectural Visualization Generator

### Package: `orchestrator.visualization`

**Nessuna migration** — dati derivati, cache in-memory con TTL.

| File | Responsabilità |
|------|---------------|
| `VisualizationConfig.java` | @ConfigurationProperties(prefix="visualization"): cache (ttlSeconds=300, maxEntries=100), layout (horizontalSpacing=200, verticalSpacing=100, maxNodes=500), format (defaultFormat="d3json") |
| `PlanGraphModel.java` | Record hierarchy: PlanGraphModel(planId, status, nodes, edges, metadata). GraphNode(id, label, type, status, layer, x, y, metadata). GraphEdge(source, target, type, onCriticalPath). Formato intermedio neutro |
| `GraphModelBuilder.java` | Plan → PlanGraphModel: estrae nodi da PlanItem, edges da dependsOn, calcola metadata (duration, tokens, worker icons). Supporto hierarchy: plan con sub-plans via parentPlanId |
| `GraphLayoutEngine.java` | Sugiyama layered layout: (1) layer assignment via topological sort, (2) crossing minimization via barycenter heuristic, (3) coordinate assignment. Output: nodi con (x,y) |
| `MermaidRenderer.java` | PlanGraphModel → String Mermaid. Subgraph per hierarchy, classDef per status, edge labels. Compone con stile PlanGraphService esistente ma per modello multi-plan |
| `D3JsonRenderer.java` | PlanGraphModel → JSON per D3.js force-directed/layered graph. Format: {nodes:[{id,label,x,y,group,status}], links:[{source,target,type}], meta:{...}} |
| `VisualizationService.java` | Orchestratore: load plan(s) → GraphModelBuilder → GraphLayoutEngine → renderer. ConcurrentHashMap cache con TTL eviction via @Scheduled(60s) |
| `VisualizationController.java` | @RestController `/api/v1/visualization`: GET /plans/{id}?format=, GET /plans/{id}/hierarchy?format=, GET /projects/{projectId}?format= |

### Dipendenze
- `PlanRepository` via `@Nullable` (JpaRepository) — load Plan entities
- `PlanItemRepository` via `@Nullable` — load PlanItems (se non inclusi nel Plan)
- `CriticalPathCalculator` via `@Nullable` — critical path highlighting
- `ProjectRepository` via `@Nullable` (da lifecycle package) — project-level views
- `MeterRegistry` via `@Nullable` — cache hit/miss counters

### Design decisions
1. **Cache in-memory** (ConcurrentHashMap + TTL) — dati derivati, ricomputabili, no bisogno di Redis/DB
2. **Modello intermedio PlanGraphModel** — disaccoppia data extraction da rendering, testabile separatamente
3. **Sugiyama layout** — standard per DAG layered visualization, O(V+E) per layer assignment
4. **Due renderer separati** (Mermaid + D3JSON) — POJO puri, unit testable senza Spring context
5. **Composizione con PlanGraphService** — non lo modifica, il nuovo GraphModelBuilder riusa le stesse info del Plan ma produce un modello diverso (con coordinate)
6. **Project-level view** — aggrega piani di un progetto (#180) in un grafo unico con subgraph per epic

### Algoritmo chiave: Sugiyama Layout

```
Input: PlanGraphModel con nodi e edges (DAG)

1. LAYER ASSIGNMENT (topological sort + longest path):
   - Per ogni nodo senza predecessori: layer = 0
   - Per ogni nodo: layer = max(predecessors.layer) + 1
   - Complessità: O(V+E) con Kahn's algorithm

2. CROSSING MINIMIZATION (barycenter heuristic, 2 pass):
   - Forward pass (layer 0 → max):
     - Per ogni nodo in layer L: barycenter = avg(posizione predecessori in L-1)
     - Ordina nodi in L per barycenter
   - Backward pass (max → 0): stessa cosa con successori

3. COORDINATE ASSIGNMENT:
   - x = layer * horizontalSpacing (default 200px)
   - y = positionInLayer * verticalSpacing (default 100px)
   - Centra verticalmente i layer con meno nodi
```

---

## Sequenza di implementazione

```
Fase 20d-1: LongitudinalBenchmark (#181)
  └─ V42__effectiveness_benchmark.sql
  └─ BenchmarkConfig.java
  └─ EffectivenessSnapshot.java
  └─ BenchmarkRepository.java
  └─ BenchmarkCollector.java
  └─ TrendAnalyzer.java
  └─ BenchmarkController.java

Fase 20d-2: ArchitecturalVisualization (#183)
  └─ VisualizationConfig.java
  └─ PlanGraphModel.java
  └─ GraphModelBuilder.java
  └─ GraphLayoutEngine.java
  └─ MermaidRenderer.java
  └─ D3JsonRenderer.java
  └─ VisualizationService.java
  └─ VisualizationController.java

Commit + mvn clean install -DskipTests
```

## Verifica

1. `mvn clean install -DskipTests` deve passare
2. Tutti i servizi `@ConditionalOnProperty(matchIfMissing = false)`
3. Dipendenze su servizi esistenti via `@Nullable`
4. Nessuna modifica a file esistenti (solo nuovi file + 1 migration)
5. 15 file nuovi + 1 migration = 16 file totali
