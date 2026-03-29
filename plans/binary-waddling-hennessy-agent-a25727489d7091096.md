# Experimental Methodology: KORE-GC

**Paper title:** "KORE-GC: Transactional Garbage Collection for Co-located Graph-Vector Knowledge Stores"

**System under test:** Apache AGE (~50K nodes, ~137K relations) + pgvector (~375K chunks, 4096-dim qwen3 embeddings), co-located in PostgreSQL 18. 5 automated import pipelines.

---

## 1. Reference Papers and Their Experimental Sections

### 1.1 Foundational Papers Identified

**P1. Ada-IVF: Incremental IVF Index Maintenance for Streaming Vector Search**
(Mohoney et al., 2024, arXiv:2411.00970, ~8 cit S2)

The closest systems paper to KORE-GC's concerns. Ada-IVF addresses the exact problem that vector indexes degrade under streaming updates unless costly index reconstruction is performed. Their experimental methodology:
- **Metrics:** Recall@10 at fixed query latency budget; update throughput (inserts/sec); index build time; QPS (queries per second)
- **Degradation measurement:** They measure recall decay curves as a function of insertions since last rebuild, showing recall drops from 0.95 to 0.80 after N insertions
- **Cost model:** Wall-clock time for maintenance operations vs. full rebuild; amortized cost per insertion
- **Baselines:** Static FAISS IVF-PQ (periodic full rebuild at intervals); DiskANN (streaming variant); LIRE (another incremental method)
- **Workloads:** Synthetic (uniform, clustered, drifting distributions) + real datasets (SIFT1M, GIST1M, Deep1B subset, MSMarco embeddings)
- **Statistical rigor:** 5 runs per configuration, median reported, error bars for p5/p95

**P2. Recent Increments in Incremental View Maintenance**
(Olteanu, Gems of PODS 2024, arXiv:2404.17679, ~3 cit S2)

Survey of F-IVM (Factorized IVM). The key insight for KORE-GC: IVM theory provides the formal framework for understanding incremental maintenance cost. Their experimental methodology from the underlying papers:
- **Metrics:** Update time (amortized per delta); enumeration delay; space overhead; preprocessing time
- **Cost model:** O(N^w) where w is the fractional hypertree width -- directly comparable to full recomputation cost
- **Key result:** For acyclic queries, IVM is in NC0 (constant time per update) -- this is the theoretical ceiling your paper should aspire to

**P3. RAG vs. GraphRAG: A Systematic Evaluation and Key Insights**
(Han et al., 2025, arXiv:2502.11371)

The most relevant evaluation paper for hybrid graph+vector retrieval. Their methodology:
- **Tasks:** Question answering (HotpotQA, MuSiQue, 2WikiMultiHopQA) + query-based summarization (MultiNews)
- **Metrics:** Accuracy (exact match, F1), Comprehensiveness (LLM-judge 1-5 scale), Diversity (LLM-judge), Empowerment (LLM-judge), faithfulness
- **Key finding:** GraphRAG outperforms vanilla RAG on multi-hop reasoning and summarization, but underperforms on simple factoid retrieval
- **Evaluation protocol:** Unified preprocessing, retrieval configs, generation settings for fair comparison

**P4. GraphRAG-Bench: When to Use Graphs in RAG**
(Xiang et al., 2025, arXiv:2506.05690)

Comprehensive benchmark with tasks of increasing difficulty:
- **Task taxonomy:** Fact retrieval, complex reasoning, contextual summarization, creative generation
- **Pipeline evaluation:** Separately evaluates graph construction quality, knowledge retrieval quality, and final generation quality
- **Metrics per stage:** Graph: node/edge precision-recall vs. gold standard; Retrieval: Hit@k, MRR, nDCG@k; Generation: ROUGE, BERTScore, LLM-judge

**P5. LightRAG: Simple and Fast Retrieval-Augmented Generation**
(Guo et al., 2024, arXiv:2410.05779, HKUDS)

Directly relevant as it uses graph structures with vector representations + incremental update algorithm:
- **Evaluation dimensions:** Comprehensiveness, Diversity, Empowerment, Overall (all 1-5 LLM-judge scale, following Microsoft GraphRAG)
- **Datasets:** Agriculture, CS, Legal, Mixed
- **Baselines:** NaiveRAG, RQ-RAG, HyDE, GraphRAG, RAPTOR
- **Incremental evaluation:** Measures performance after incremental updates vs. full rebuild

**P6. BEIR: Benchmarking IR**
(Thakur et al., 2021, NeurIPS Datasets Track, arXiv:2104.08663, ~1500+ cit S2)

The gold standard IR benchmark. Establishes nDCG@10 as the primary metric for zero-shot retrieval evaluation across 18 datasets. KORE-GC should use nDCG@k as the primary retrieval quality metric for consistency with this community standard.

**P7. LongEval @ CLEF 2025**
(Cancellieri et al., 2025, arXiv:2503.08541)

Directly relevant: evaluates how retrieval model performance degrades as data evolves temporally. Their methodology for measuring temporal degradation is exactly what KORE-GC needs for the "inconsistencies accumulate" claim.

**P8. Graph-Based Vector Search: An Experimental Evaluation (SIGMOD 2025)**
(Azizi et al., arXiv:2509.05750)

Comprehensive evaluation of 12 graph-based vector search methods on 7 real datasets up to 1B vectors. Establishes the recall-vs-QPS tradeoff curve methodology that KORE-GC should adopt.

---

## 2. Metrics Framework

### 2.1 Consistency Metrics (Novel -- paper's main contribution)

These metrics quantify the "health" of the co-located store:

| Metric | Definition | How to measure |
|--------|-----------|----------------|
| **Orphan Embedding Rate (OER)** | Fraction of vectors in pgvector that reference a deleted/modified graph node | `SELECT count(*) FROM embeddings e LEFT JOIN ag_catalog.cypher(...) c ON e.source_id = c.id WHERE c.id IS NULL` / total embeddings |
| **Stale Embedding Rate (SER)** | Fraction of embeddings whose source text has changed since embedding was computed | Compare `e.content_hash` with current node content hash |
| **Dangling Reference Rate (DRR)** | Fraction of graph edges pointing to non-existent nodes | Cypher query for broken relationships |
| **Duplicate Node Rate (DNR)** | Fraction of nodes with near-duplicate content (cosine similarity > 0.98 on embeddings) | pgvector similarity self-join |
| **Schema Violation Rate (SVR)** | Fraction of nodes violating expected property constraints | SQL check constraints on AGE vertex properties |
| **Cross-Store Consistency Score (CSCS)** | Composite: 1 - weighted_avg(OER, SER, DRR, DNR, SVR) | Tunable weights, default equal |

### 2.2 Retrieval Quality Metrics (Standard)

Following BEIR (T1 -- NeurIPS 2021) and GraphRAG-Bench (T2):

| Metric | What it measures | Standard in |
|--------|-----------------|-------------|
| **nDCG@k** (k=5,10,20) | Ranked retrieval quality | BEIR, MTEB, all IR papers |
| **Recall@k** (k=5,10,20) | Coverage at cutoff | Ada-IVF, vector search papers |
| **MRR** | Rank of first relevant result | QA benchmarks |
| **Hit@k** | Binary: is any relevant result in top-k? | GraphRAG-Bench, knowledge graph QA |
| **Comprehensiveness** | LLM-judge 1-5: does the answer cover all aspects? | Microsoft GraphRAG, LightRAG |
| **Faithfulness** | LLM-judge 1-5: is the answer grounded in retrieved context? | RAGAS framework |

### 2.3 Maintenance Cost Metrics (Systems)

Following Ada-IVF and IVM literature:

| Metric | Definition |
|--------|-----------|
| **Wall-clock time** | End-to-end time for each GC algorithm |
| **Embedding API calls** | Number of Ollama inference calls (most expensive operation) |
| **Rows scanned** | Total tuples read from PG |
| **Rows modified** | Total tuples inserted/updated/deleted |
| **I/O bytes** | pg_stat_io bytes read/written during operation |
| **Peak memory** | max_rss of GC process |
| **Query latency during GC** | p50/p95/p99 of concurrent queries while GC runs |
| **Lock contention** | pg_stat_activity waiting events during GC |

---

## 3. Ground Truth Construction

### 3.1 Strategy: Three-Tier Ground Truth

**Tier 1: Hand-Crafted Gold Standard (50 queries)**

Construct 50 queries with manually verified answers across 5 categories:
- **Factoid** (10): "Who wrote [Book X]?" -- answer is a specific Author node
- **Multi-hop** (10): "What topics does [Author] write about?" -- requires graph traversal
- **Semantic** (10): "Find passages about [concept]" -- requires vector similarity
- **Hybrid** (10): "What does [Author] say about [Topic]?" -- requires both graph+vector
- **Aggregation** (10): "How many books discuss [Theme]?" -- requires graph counting

For each query, annotate:
- Relevant nodes/edges (gold graph subgraph)
- Relevant embedding chunks (gold vector results)
- Expected answer text
- Relevance grades: 3-level (highly relevant / relevant / marginally relevant) for nDCG computation

**Tier 2: Synthetic Perturbation Test Set (500 queries)**

Start from a known-good snapshot. For each query:
1. Record the correct answer at t0 (clean state)
2. Inject controlled inconsistencies (see Section 4)
3. Re-run query at t1 (degraded state)
4. The delta in retrieval quality IS the measured effect

This is a paired-sample design (same queries, before/after), which gives much more statistical power than independent samples.

**Tier 3: LLM-as-Judge Evaluation (200 queries)**

For subjective quality dimensions (Comprehensiveness, Faithfulness), use GPT-4 / Claude as judge following the protocol from Microsoft GraphRAG and LightRAG:
- Generate answer from retrieved context
- LLM judges on 1-5 scale with rubric
- Report inter-judge agreement (Cohen's kappa between two LLM judges)
- Validate a random 10% subsample with human judgment

### 3.2 Ground Truth for Consistency Metrics

For consistency metrics, ground truth is computable -- no human annotation needed:
- OER, SER, DRR, DNR, SVR are all defined as database queries
- Take a snapshot at time t, run the queries, get exact numbers
- The question is whether these numbers correlate with retrieval quality degradation (Section 4)

---

## 4. Controlled Degradation Experiment

### 4.1 Experimental Design: Factorial with Repeated Measures

**Independent variable:** Inconsistency level (0%, 5%, 10%, 20%, 30%, 50%)

**Dependent variables:** All metrics from Section 2

**Inconsistency injection protocol:**

For each inconsistency level L%, apply the following perturbations to a clean snapshot:

| Perturbation type | What it simulates | How to inject |
|-------------------|-------------------|---------------|
| **Orphan embeddings** | Deleted graph nodes, embeddings not cleaned up | DELETE L% of nodes from AGE, leave their embeddings in pgvector |
| **Stale embeddings** | Updated content, old embeddings | UPDATE L% of node properties (e.g., change book titles), don't re-embed |
| **Dangling references** | Partially deleted subgraphs | DELETE L% of target nodes from relationships, leave the edges |
| **Duplicate nodes** | Multiple import runs creating duplicates | INSERT copies of L% of nodes with slight property variations |
| **Model drift** | Embedding model changed, old vectors remain | Re-embed L% of chunks with a DIFFERENT model (e.g., mxbai-embed-large instead of qwen3), leave the rest |

**Control conditions:**
- **C0 (Clean):** Fresh import, all consistent, single embedding model
- **C_natural:** Run system for 30 days with all 5 pipelines active, measure naturally accumulated inconsistencies
- **C_rebuild:** Full rebuild from scratch (upper bound on quality, lower bound on cost)

### 4.2 Natural Accumulation Study

Run the real KORE system for 30/60/90 days with normal pipeline activity. At each checkpoint:
1. Snapshot the database (pg_dump)
2. Measure all consistency metrics
3. Run the Tier 1+2 query sets
4. Record: pipeline run counts, total nodes/edges added/modified/deleted

This provides the evidence for Claim 1 ("inconsistencies accumulate") with real data.

### 4.3 Causal Chain Validation

The experiment must establish the causal chain:

```
Time passes + pipeline activity --> Inconsistencies accumulate (Claim 1)
                                         |
                                         v
                          Retrieval quality degrades (Claim 2)
                                         |
                                         v
                          GC algorithms reduce inconsistencies (Claim 3)
                                         |
                                         v
                          Retrieval quality recovers (Claim 2 inverse)
```

**Statistical test for each link:**
- Claim 1: Time-series regression of CSCS on days elapsed (expect negative slope, p < 0.01)
- Claim 2: Pearson/Spearman correlation of CSCS with nDCG@10 across all conditions (expect r > 0.7)
- Claim 3: Paired t-test of CSCS before/after each GC algorithm (expect significant improvement)
- Recovery: Paired t-test of nDCG@10 before/after GC

---

## 5. GC Algorithm Evaluation

### 5.1 Algorithms Under Test

| Algorithm | What it does | Key cost driver |
|-----------|-------------|-----------------|
| **GC-Sweep** | Remove orphan embeddings, fix dangling refs | I/O (scan + delete) |
| **Freshness-Check** | Detect and re-embed stale vectors | Embedding API calls |
| **Lifecycle-Policy** | TTL-based expiry + archival of old nodes | I/O (scan + move) |
| **Model-Migrate** | Re-embed all vectors with new model | Embedding API calls (dominant) |
| **Full-Rebuild** | Drop and reimport everything | All costs (upper bound) |
| **No-Op** | Do nothing (lower bound on cost, upper bound on degradation) | Zero |

### 5.2 Experiment Matrix

Run each algorithm on each degradation level (Section 4.1):

```
For each inconsistency_level in [5%, 10%, 20%, 30%, 50%]:
    For each algorithm in [GC-Sweep, Freshness-Check, Lifecycle-Policy, Model-Migrate, Combo-All]:
        1. Load snapshot at inconsistency_level
        2. Measure pre-GC: consistency metrics + retrieval quality
        3. Run algorithm, measure cost metrics
        4. Measure post-GC: consistency metrics + retrieval quality
        5. Repeat 5 times (for variance estimation)
```

### 5.3 Incremental vs. Full Rebuild (Claim 5)

For each degradation level, compare:
- **Incremental:** Run the appropriate GC algorithm(s)
- **Full rebuild:** pg_dump schema, drop data, reimport from source

Measure:
- Quality delta: (post-GC nDCG@10) - (pre-GC nDCG@10) for both approaches
- Cost delta: wall-clock time, embedding API calls, I/O
- **Break-even analysis:** At what degradation level does full rebuild become cheaper than incremental GC? Plot cost vs. degradation level with crossover point.

---

## 6. ACID Advantage Demonstration (Claim 4)

### 6.1 Co-located vs. Simulated Distributed

The claim is that single-PG co-location enables ACID guarantees impossible in distributed architectures. To test this scientifically:

**Co-located condition (KORE):**
- GC operations run as PostgreSQL transactions
- Consistency: graph and vector updates are atomic
- Isolation: concurrent queries see consistent snapshots (MVCC)

**Simulated distributed condition:**
- Same data, but graph in a separate process (simulated by a separate PG schema with artificial latency)
- Vector store accessed via HTTP API (simulated by wrapping pgvector queries with artificial network delay)
- No cross-store transactions -- updates are eventually consistent

**Injection protocol for distributed simulation:**
1. Add configurable delay (10ms, 50ms, 100ms, 500ms) between graph operation and vector operation
2. During the delay window, inject concurrent queries
3. Measure: fraction of queries that see inconsistent state (graph says X, vector says Y)

**Metrics specific to this experiment:**
- **Anomaly rate:** Fraction of queries returning inconsistent results during GC
- **Convergence time:** Time from GC start until all queries see consistent state
- **Durability gap:** Probability of partial failure (graph updated, vectors not) under simulated crash

### 6.2 Concurrent Workload Stress Test

Run GC algorithms while a realistic query workload is active:
- 10 concurrent query threads, each issuing queries from Tier 2 set at 1 QPS
- Measure query latency distribution (p50, p95, p99) during GC vs. baseline
- For co-located: expect minimal latency impact (MVCC isolation)
- For distributed: expect latency spikes and anomalous results during GC window

---

## 7. Statistical Rigor

### 7.1 What VLDB/SIGMOD Reviewers Expect

Based on analysis of experimental sections in recent VLDB/SIGMOD papers (Ada-IVF, F-IVM, graph-based vector search survey):

1. **Multiple runs:** Minimum 5 runs per configuration, report median + IQR or mean + 95% CI
2. **Warm-up:** Discard first run as warm-up (OS cache, JIT compilation effects)
3. **Controlled environment:** Report hardware specs, OS, PG version, shared_buffers, work_mem, effective_cache_size
4. **Isolation:** No other workloads during measurement (or explicitly describe concurrent load)
5. **Reproducibility:** Docker compose + seed data + query scripts must be published
6. **Effect sizes:** Not just p-values. Report absolute and relative improvements (e.g., "nDCG@10 improved from 0.72 to 0.89, a 23.6% relative improvement")
7. **Ablation:** Test each GC algorithm independently AND in combination
8. **Scalability:** At minimum, test at 2-3 data sizes (current KORE size + 2x + 5x synthetic expansion)

### 7.2 Statistical Tests

| Claim | Test | Required N | Significance |
|-------|------|------------|-------------|
| Inconsistencies degrade retrieval | Spearman rank correlation (CSCS vs nDCG@10) | >= 30 data points (6 levels x 5 runs) | rho > 0.7, p < 0.01 |
| GC improves consistency | Paired Wilcoxon signed-rank (pre vs post GC) | >= 5 runs per condition | p < 0.05 with Bonferroni correction for multiple algorithms |
| GC improves retrieval | Paired t-test on nDCG@10 (pre vs post) | >= 5 runs | p < 0.05, report Cohen's d |
| Incremental cheaper than rebuild | Mann-Whitney U on wall-clock time | >= 5 runs each | p < 0.05, report ratio |
| Co-located beats distributed | Chi-squared on anomaly counts | >= 100 queries per condition | p < 0.001 |
| LLM-judge agreement | Cohen's kappa between two LLM judges | >= 50 judged pairs | kappa > 0.6 (substantial agreement) |

### 7.3 Multiple Comparisons Correction

With 5 algorithms x 5 degradation levels x 6 retrieval metrics = 150 comparisons, apply:
- Bonferroni correction (conservative): alpha = 0.05/150 = 0.00033
- Or Benjamini-Hochberg FDR at q = 0.05 (less conservative, more appropriate for exploratory analysis)

Report both uncorrected and corrected p-values.

---

## 8. Reproducibility Plan

### 8.1 Artifact Package

Publish as a GitHub repository with:

```
kore-gc-experiments/
  docker-compose.yml        # PG18 + pgvector + AGE, single command setup
  Makefile                   # All experiments runnable via make targets
  data/
    synthetic-generator.py   # Generates KORE-like graph+vector data at any scale
    query-sets/
      tier1-gold.json        # 50 hand-crafted queries with gold answers
      tier2-synthetic.json   # 500 perturbation test queries
      tier3-llm-judge.json   # 200 LLM-judge queries with rubrics
    perturbation/
      inject.py              # Injects controlled inconsistencies at specified levels
      snapshot.py             # Creates/restores PG snapshots
  algorithms/
    gc_sweep.sql             # Each algorithm as executable SQL/Python
    freshness_check.py
    lifecycle_policy.py
    model_migrate.py
  measurement/
    consistency_metrics.py   # Computes OER, SER, DRR, DNR, SVR, CSCS
    retrieval_metrics.py     # Runs queries, computes nDCG, Recall, MRR, Hit
    cost_metrics.py          # Instruments PG stats, wall-clock, memory
    llm_judge.py             # LLM-as-judge evaluation with rubrics
  analysis/
    run_all.sh               # Full experiment pipeline
    plot_figures.py           # Generates all paper figures
    statistical_tests.py     # All hypothesis tests with corrections
  results/                   # Raw results (CSV) for transparency
```

### 8.2 Synthetic Dataset Generator

The generator must produce data with the same statistical properties as real KORE:
- **Graph:** Power-law degree distribution (alpha ~2.1), 5 node types, 12 edge types
- **Vectors:** 4096-dim, generated by Ollama qwen3-embedding from synthetic text (not random)
- **Scale parameters:** Node count (50K, 100K, 250K), edge multiplier (2.7x nodes), embedding chunk ratio (7.5x nodes)
- **Temporal metadata:** Each node/edge gets a created_at timestamp, simulating pipeline import patterns

### 8.3 Experiment Runner

Single-command reproducibility:
```bash
make setup          # Docker compose up, load data
make inject L=20    # Inject 20% inconsistencies
make measure-pre    # Pre-GC metrics
make gc ALG=sweep   # Run GC-Sweep
make measure-post   # Post-GC metrics
make analysis       # Statistical tests + figures
```

---

## 9. Experiment Timeline

| Phase | Duration | Activities |
|-------|----------|-----------|
| **Phase 0: Instrumentation** | 1 week | Implement consistency metrics queries; instrument PG stats collection |
| **Phase 1: Ground Truth** | 2 weeks | Hand-craft Tier 1 queries; build synthetic generator; implement perturbation injection |
| **Phase 2: Baseline Measurement** | 1 week | Measure clean-state metrics; establish baseline retrieval quality |
| **Phase 3: Degradation Study** | 2 weeks | Run controlled injection at 6 levels; measure all metrics; natural accumulation starts |
| **Phase 4: Algorithm Implementation** | 2 weeks | Implement 4 GC algorithms; unit test each |
| **Phase 5: Algorithm Evaluation** | 2 weeks | Full experiment matrix (5 algos x 5 levels x 5 runs = 125 runs) |
| **Phase 6: ACID Experiment** | 1 week | Simulated distributed comparison; concurrent workload test |
| **Phase 7: Scalability** | 1 week | Test at 2x and 5x scale |
| **Phase 8: Analysis & Writing** | 2 weeks | Statistical tests; figures; paper sections |
| **Natural accumulation** | Concurrent with Phase 3-7 | 30/60/90 day snapshots (runs in background) |

**Total: ~13 weeks (active) + 90 days (natural accumulation, concurrent)**

---

## 10. Expected Figures

1. **Figure 1 (Motivation):** Time-series plot of CSCS over 90 days of natural pipeline activity. Shows degradation trend.

2. **Figure 2 (Degradation curve):** nDCG@10 vs. inconsistency level (0-50%). One line per perturbation type + combined. Error bars = 95% CI.

3. **Figure 3 (Correlation):** Scatter plot of CSCS vs. nDCG@10 across all conditions. Show Spearman rho.

4. **Figure 4 (Recovery):** Bar chart: nDCG@10 before GC, after each algorithm, after full rebuild. Grouped by degradation level.

5. **Figure 5 (Cost-quality tradeoff):** Pareto front: x-axis = wall-clock time, y-axis = post-GC nDCG@10. One point per algorithm per degradation level. Annotate the Pareto-optimal points.

6. **Figure 6 (Break-even):** Cost (wall-clock) vs. degradation level. Lines for incremental GC and full rebuild. Crossover point highlighted.

7. **Figure 7 (ACID advantage):** Anomaly rate and convergence time: co-located vs. distributed at 4 latency levels. Stacked bar chart.

8. **Figure 8 (Scalability):** Wall-clock time and nDCG@10 at 1x/2x/5x scale. Log-scale x-axis.

9. **Table 1:** Full results matrix: algorithm x degradation level -> (nDCG@10 delta, cost, CSCS improvement).

10. **Table 2:** Statistical test results: all p-values (uncorrected + Bonferroni), effect sizes (Cohen's d), confidence intervals.

---

## 11. Threats to Validity

### Internal
- **Perturbation realism:** Controlled injection may not match real-world inconsistency patterns. Mitigated by the natural accumulation study.
- **LLM judge bias:** LLM judges may favor verbose answers. Mitigated by using two different LLMs and validating against human judgment.
- **Embedding model confound:** Model-Migrate perturbation uses a different model, which may affect quality independently of consistency. Mitigated by including model-switch as an independent baseline.

### External
- **Single system:** Results on KORE (50K nodes, academic knowledge graph) may not generalize to other domains (e.g., e-commerce KG, biomedical KG). Mitigated by synthetic scalability experiments.
- **Single DBMS:** PostgreSQL-specific. The ACID advantage may be smaller on other co-located systems (e.g., DuckDB + vector extension). Acknowledged as future work.

### Construct
- **CSCS weights:** The composite consistency score depends on weight choices. Mitigated by reporting all component metrics individually and performing sensitivity analysis on weights.

---

## 12. Serendipitous Connections

**IVM theory (Olteanu, PODS 2024) as theoretical foundation:** The F-IVM framework provides the complexity-theoretic underpinning for why incremental maintenance should be cheaper than full rebuild. KORE-GC's algorithms are essentially IVM for a "view" defined as "consistent graph-vector state." The paper should explicitly connect to this literature and state the complexity class of each GC algorithm.

**LongEval (CLEF 2025) as temporal evaluation framework:** LongEval's methodology for measuring retrieval quality degradation over time is directly applicable to the natural accumulation experiment (Phase 3). Consider using their temporal lag metrics.

**Connection to the Ranking Todo personal project:** The Bradley-Terry preference learning system in `preference-sort` also lives in the same PostgreSQL instance. If its embedding-based similarity features rely on the same pgvector store, KORE-GC's maintenance directly affects ranking quality -- a concrete application case study.

**Connection to Agent Framework project:** The `task_graph` and `code_graph` in AGE are maintained by the agent framework. KORE-GC would be the maintenance layer ensuring these graphs remain consistent as agents create/modify/delete task nodes.

---

## 13. Key References

| # | Paper | Venue | Year | Cit (S2) | Role in this paper |
|---|-------|-------|------|----------|--------------------|
| 1 | Ada-IVF (Mohoney et al.) | arXiv (submitted) | 2024 | ~8 | Closest methodological precedent for vector index maintenance |
| 2 | Recent Increments in IVM (Olteanu) | PODS 2024 | 2024 | ~3 | Theoretical foundation for incremental maintenance |
| 3 | RAG vs GraphRAG (Han et al.) | arXiv | 2025 | -- | Evaluation protocol for hybrid graph+vector retrieval |
| 4 | GraphRAG-Bench (Xiang et al.) | arXiv | 2025 | -- | Benchmark methodology for GraphRAG pipeline evaluation |
| 5 | LightRAG (Guo et al.) | arXiv (HKUDS) | 2024 | -- | Incremental update + graph-vector evaluation metrics |
| 6 | BEIR (Thakur et al.) | NeurIPS 2021 | 2021 | ~1500+ | Gold standard for IR metrics (nDCG@10) |
| 7 | LongEval (Cancellieri et al.) | ECIR 2025 | 2025 | -- | Temporal degradation evaluation methodology |
| 8 | Graph-Based Vector Search (Azizi et al.) | SIGMOD 2025 | 2025 | -- | Recall-vs-QPS evaluation methodology |
| 9 | MS GraphRAG (Edge et al.) | arXiv | 2024 | -- | LLM-judge evaluation protocol (Comprehensiveness, Diversity, Empowerment) |
| 10 | ActorDB (Kawasaki) | arXiv | 2025 | 0 | Conceptually related: unified DB with IVM + messaging |
| 11 | TREC RAG Track (Pradeep et al.) | arXiv | 2024 | -- | AutoNuggetizer: automatic evaluation methodology for RAG |

---

## 14. Summary of Recommendations

1. **Primary retrieval metric:** nDCG@10 (BEIR standard). Report Recall@10 and MRR as secondary.
2. **Primary consistency metric:** CSCS (novel composite). Report all 5 components individually.
3. **Primary cost metric:** Wall-clock time. Report embedding API calls as the expensive sub-component.
4. **Ground truth:** Three-tier (hand-crafted + synthetic perturbation + LLM-judge). The paired-sample design (Tier 2) gives the most statistical power.
5. **Statistical rigor:** 5 runs minimum, Bonferroni correction, report effect sizes (Cohen's d), 95% CIs.
6. **ACID demonstration:** Simulated distributed with artificial latency is the cleanest experimental design. Avoid comparing against a completely different system (too many confounds).
7. **Reproducibility:** Docker compose + Makefile + published query sets + synthetic generator. Target the VLDB Reproducibility badge.
8. **Break-even analysis:** This is the most novel and practically useful result -- at what degradation level should you rebuild vs. incrementally maintain?
