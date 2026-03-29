# KORE-GC Paper Structure Analysis and Optimal Outline

## Part 1: Structural Analysis of Reference Papers

---

### Paper 1: LightRAG (Guo et al., 2024) -- EMNLP, ~217 cit (S2)

**Closest topic match**: graph + vector RAG system.

**Section structure** (fetched from arXiv HTML TOC):

| # | Section | Subsections | Est. pages |
|---|---------|-------------|------------|
| 1 | Introduction | -- | 1.5 |
| 2 | Retrieval-Augmented Generation | (background/prelim) | 1 |
| 3 | The LightRAG Architecture | 3.1 Graph-based Text Indexing, 3.2 Dual-level Retrieval Paradigm, 3.3 Retrieval-Augmented Answer Generation, 3.4 Complexity Analysis | 3.5 |
| 4 | Evaluation | 4.1 Experimental Settings, 4.2 Comparison (RQ1), 4.3 Ablation (RQ2), 4.4 Case Study (RQ3), 4.5 Cost/Adaptability (RQ4) | 3.5 |
| 5 | Related Work | 5.1 RAG Frameworks, 5.2 Graph-based approaches | 1 |
| 6 | Conclusion | -- | 0.5 |

**Key observations:**
- **Related work is LATE** (Section 5, after experiments). This is the NLP/ML convention.
- **Architecture section is the longest** (~3.5 pages). Theory is minimal -- one complexity analysis subsection.
- **RQ-driven experiments**: evaluation organized by research questions (RQ1-RQ4).
- **No formal definitions or theorems**. Algorithms described procedurally.
- **Balance**: ~35% system, ~35% experiments, ~15% background+related, ~15% intro+conclusion.
- **Figures**: ~6 figures (architecture diagram, retrieval flow, experimental results).
- **Tables**: ~5 tables (main comparison, ablation, cost analysis).

---

### Paper 2: GraphRAG (Edge et al., 2024) -- arXiv/NAACL, ~1207 cit (S2)

**Foundational GraphRAG paper**: Microsoft Research, graph-based RAG.

**Section structure** (fetched from arXiv HTML TOC):

| # | Section | Subsections | Est. pages |
|---|---------|-------------|------------|
| 1 | Introduction | -- | 1.5 |
| 2 | Background | 2.1 RAG Approaches, 2.2 KGs with LLMs and RAG, 2.3 Adaptive benchmarking, 2.4 RAG evaluation criteria | 2.5 |
| 3 | Methods | 3.1 GraphRAG Workflow (6 sub-sub-sections: Docs->Chunks->Entities->KG->Communities->Summaries->Answers), 3.2 Global Sensemaking Question Generation, 3.3 Criteria for Evaluation | 4 |
| 4 | Analysis | 4.1 Experiment 1 (Datasets, Conditions, Configuration), 4.2 Experiment 2 | 2 |
| 5 | Results | 5.1 Experiment 1, 5.2 Experiment 2 | 2 |
| 6 | Discussion | 6.1 Limitations, 6.2 Future work | 1 |
| 7 | Conclusion | -- | 0.5 |
| App | A-F | Prompts, examples, evaluation details | 5+ |

**Key observations:**
- **Background is EARLY and LONG** (Section 2, ~2.5 pages). Acts as combined related work + preliminaries.
- **No separate Related Work section** -- absorbed into Background.
- **Deep workflow decomposition**: Section 3.1 has 6 sub-sub-sections, each a pipeline stage.
- **Analysis/Results split**: unusual choice to separate experimental setup from results.
- **Heavy appendix** (6 appendices, A-F) -- prompts, examples, evaluation details.
- **No formal theory**. No definitions, theorems, or algorithms in pseudocode.
- **Balance**: ~20% background, ~30% methods, ~30% experiments/results, ~10% discussion, ~10% intro+conclusion.
- **Figures**: ~8 figures. **Tables**: ~6 tables.
- **Total**: ~15 pages main + 5+ appendix = ~20 pages.

---

### Paper 3: DBSP (Budiu et al., VLDB 2023) -- ~56 cit (S2)

**IVM theory paper with practical system**. Most structurally relevant for KORE-GC's theory component.

**Section structure** (from training knowledge -- the VLDB 2023 publication):

| # | Section | Subsections | Est. pages |
|---|---------|-------------|------------|
| 1 | Introduction | -- | 1.5 |
| 2 | Background: Streams and Computations | Z-sets, streams, operators, lifting | 2 |
| 3 | The DBSP Language | Syntax, semantics, stream operators, integration/differentiation, delay | 2.5 |
| 4 | Incremental Computation | The D and I operators, chain rule, incrementalizing programs | 2 |
| 5 | Recursive Queries | Stratified recursion, semi-naive evaluation | 1.5 |
| 6 | Modeling Query Languages | Relational algebra, aggregation, Datalog, streaming | 2 |
| 7 | Implementation | Feldera system | 1 |
| 8 | Experimental Evaluation | TPC-H, Nexmark benchmarks | 1.5 |
| 9 | Related Work | -- | 1 |
| 10 | Conclusion | -- | 0.5 |

**Key observations:**
- **Theory-heavy front-loading**: Sections 2-5 (~8 pages) are pure mathematical framework before any system description.
- **Definitions and theorems throughout**: formal definitions of Z-sets, streams, operators. Key theorems: incrementalization theorem, chain rule for IVM.
- **Related work is LATE** (Section 9).
- **Implementation section is SHORT** (~1 page). The paper's contribution is primarily theoretical.
- **Experiments are SHORT** (~1.5 pages). Just enough to validate the system works.
- **Balance**: ~55% theory, ~15% modeling/applications, ~10% implementation, ~10% experiments, ~10% related+intro+conclusion.
- **Figures**: ~5 (operator diagrams, circuit diagrams). **Tables**: ~3 (benchmark results).
- **Total**: ~14 pages (VLDB format).

**THIS IS THE CLOSEST STRUCTURAL MODEL for KORE-GC's theory-heavy approach.**

---

### Paper 4: Drift-Adapter (Vejendla, EMNLP 2025) -- arXiv:2509.23471

**Embedding model migration** -- directly relevant to KORE-GC's vector space migration problem.

**Section structure** (fetched from arXiv HTML TOC):

| # | Section | Subsections | Est. pages |
|---|---------|-------------|------------|
| 1 | Introduction | -- | 1.5 |
| 2 | Related Work | 2.1 Embedding Space Alignment, 2.2 Adaptive/Incremental ANN Indices, 2.3 Operational Strategies, 2.4 Training-Time Alignment | 2 |
| 3 | Drift-Adapter: Method | (problem formulation + 3 adapter types) | 2 |
| 4 | Experimental Setup | -- | 1.5 |
| 5 | Results and Analysis | 5.1 Main Performance, 5.2 vs Alternative Strategies, 5.3 Robustness to Drift, 5.4 Training Data Size, 5.5 Scalability, 5.6 Continuous Online Adaptation | 3 |
| 6 | Discussion | -- | 0.5 |
| 7 | Acknowledgements | -- | -- |
| 8 | Conclusion | -- | 0.5 |
| App A | Appendix | A.1 Memory/Latency, A.2 Training Details, A.3 Failure Analysis, A.4 Heterogeneous Drift, A.5 Additional Figures | 3 |

**Key observations:**
- **Related work is EARLY** (Section 2). Establishes the landscape before the method.
- **Method section is compact** (~2 pages). Problem formulation + three adapter parameterizations.
- **Results section is the largest** with 6 subsections covering different analysis angles.
- **Clean practical framing**: problem -> method -> thorough evaluation -> discussion.
- **Some math** (Procrustes formulation, affine transformation) but no formal theorems.
- **Balance**: ~15% related work, ~20% method, ~40% experiments/analysis, ~15% intro+conclusion, ~10% discussion.
- **Figures**: 6 (per arXiv metadata). **Tables**: ~4-5.
- **Total**: ~12 pages main + 3 appendix.

---

### Paper 5: Bacon et al. "A Unified Theory of Garbage Collection" (OOPSLA 2004) -- 56 cit (S2)

**Theory unification paper** -- the structural archetype for KORE-GC's "unification" framing.

**Section structure** (from training knowledge):

| # | Section | Subsections | Est. pages |
|---|---------|-------------|------------|
| 1 | Introduction | -- | 1.5 |
| 2 | Tracing and Reference Counting | Overview of both families | 1.5 |
| 3 | A Unified Framework | Abstract GC framework, fix-point formulation | 3 |
| 4 | Tracing as a Special Case | -- | 1.5 |
| 5 | Reference Counting as a Special Case | -- | 1.5 |
| 6 | Hybrids and Generalizations | Trial deletion, partial tracing, deferred RC | 2 |
| 7 | Cycle Collection | -- | 1 |
| 8 | Related Work | -- | 1 |
| 9 | Conclusions | -- | 0.5 |

**Key observations:**
- **The "unification" narrative arc**: present two things as distinct (Sec 2) -> show they're the same (Sec 3) -> re-derive each as special case (Sec 4-5) -> show hybrids naturally emerge (Sec 6).
- **Theory-centered but NOT formally heavy**. The unification is conceptual (fix-point formulation) rather than theorem-proof style.
- **Related work is LATE** (Section 8).
- **No experiments at all**. This is a pure theory/conceptual paper.
- **The key insight is structural, not computational**: the contribution is a new way of seeing, not new algorithms.
- **Balance**: ~15% intro, ~15% background, ~40% unified framework + special cases, ~20% extensions/hybrids, ~10% related+conclusion.
- **Figures**: ~4 (framework diagrams, lattice diagrams). **Tables**: ~2.
- **Total**: ~14 pages (OOPSLA format).

**THIS IS THE CLOSEST NARRATIVE MODEL for KORE-GC's "unification" framing.**

---

## Part 2: Cross-Paper Structural Patterns

### Where Related Work Goes

| Paper | Related Work Position | Pages | Rationale |
|-------|-----------------------|-------|-----------|
| LightRAG | Late (Sec 5, after experiments) | 1 | ML/NLP convention: let results speak first |
| GraphRAG | Early (Sec 2, as "Background") | 2.5 | Needs to establish terminology for pipeline |
| DBSP | Late (Sec 9, near end) | 1 | Theory paper: framework must come first |
| Drift-Adapter | Early (Sec 2, before method) | 2 | Needs to position against operational alternatives |
| Bacon GC | Late (Sec 8) | 1 | Unification paper: must build framework first |

**Decision for KORE-GC**: **LATE related work** (after theory, before experiments). The paper needs to build the Neural IVM framework before the reader can appreciate how it relates to prior work. This follows DBSP and Bacon.

### Theory vs System vs Experiments Balance

| Paper | Theory | System/Method | Experiments | Other |
|-------|--------|---------------|-------------|-------|
| LightRAG | 5% | 35% | 35% | 25% |
| GraphRAG | 0% | 30% | 30% | 40% |
| DBSP | **55%** | 10% | 10% | 25% |
| Drift-Adapter | 10% | 20% | 40% | 30% |
| Bacon GC | **60%** | 0% | 0% | 40% |

**Decision for KORE-GC**: Hybrid between DBSP and Drift-Adapter. Target: **35% theory, 20% system/algorithms, 30% experiments, 15% other**. This is more balanced than DBSP (which undersells implementation) while being more rigorous than the RAG papers.

### Definitions, Theorems, Algorithms

| Paper | Formal Defs | Theorems | Algorithms | Pseudocode |
|-------|-------------|----------|------------|------------|
| LightRAG | 0 | 0 | 0 | 0 |
| GraphRAG | 0 | 0 | 0 | 0 |
| DBSP | ~10 | ~5 | ~3 | Yes |
| Drift-Adapter | ~2 | 0 | 0 | No |
| Bacon GC | ~5 | ~2 | ~3 | Yes (abstract) |

**Decision for KORE-GC**: Follow DBSP. Target: **6-8 definitions, 3-4 theorems, 2-3 algorithms in pseudocode**. This is what makes the paper publishable at VLDB rather than just a workshop paper.

### Figures and Tables

| Paper | Figures | Tables | Total visual elements |
|-------|---------|--------|----------------------|
| LightRAG | ~6 | ~5 | ~11 |
| GraphRAG | ~8 | ~6 | ~14 |
| DBSP | ~5 | ~3 | ~8 |
| Drift-Adapter | 6 | ~5 | ~11 |
| Bacon GC | ~4 | ~2 | ~6 |

**Decision for KORE-GC**: Target **7-8 figures, 4-5 tables** (~12 total). Key figures: architecture diagram, degradation curves, GC parallel diagram, algorithm flow, experimental results.

---

## Part 3: The KORE-GC Optimal Outline

### The Story Arc

The narrative carries the reader through five acts:

1. **ACT I -- The Problem Is Real** (Intro): Knowledge stores co-locate graphs and vectors. They degrade over time. Nobody has a principled framework for maintaining them.

2. **ACT II -- Two Fields, One Problem** (Background + Neural IVM Theory): Garbage collection (memory management) and incremental view maintenance (databases) both solve the same problem: detecting and reclaiming stale state. We unify them into "Neural IVM" for graph-vector stores. (This is the Bacon "unified theory" move.)

3. **ACT III -- The Algorithms** (System): From the theory, we derive concrete GC algorithms for graph-vector stores: staleness detection, incremental re-embedding, transactional consistency.

4. **ACT IV -- It Works** (Experiments): On real-world knowledge graphs (KORE), we show degradation is measurable, GC recovers quality, and ACID guarantees matter.

5. **ACT V -- Where This Goes** (Discussion + Conclusion): This framework generalizes. It applies to any co-located graph-vector store.

### Detailed Outline

---

#### 1. Introduction (1.5 pages)

**Content**: The proliferation of graph-vector knowledge stores (GraphRAG, LightRAG, knowledge graphs with embeddings). The maintenance problem: knowledge evolves, embeddings drift, graph structure changes -- but nobody maintains consistency. The cost of not maintaining: silent quality degradation.

**What goes here**:
- Motivating example: a knowledge graph where entities change but embeddings are stale
- The "silent failure" problem -- unlike crashes, degradation is invisible
- Contribution bullet list (3-4 items)
- Paper roadmap paragraph

**Figures**: Fig 1 -- Degradation curve (a compelling "before/after" showing retrieval quality dropping over time without GC)

---

#### 2. Background and Preliminaries (2 pages)

**Content**: Establish the three pillars the paper unifies.

**2.1 Graph-Vector Knowledge Stores** (~0.5 page)
- Definition of a co-located store (graph G + vector index V + mapping phi)
- Examples: GraphRAG, LightRAG, KORE, hybrid stores in production
- The consistency invariant: what it means for G and V to be "in sync"

**2.2 Incremental View Maintenance** (~0.5 page)
- IVM in databases (brief): views as derived data, delta propagation
- DBSP as the state of the art; the key insight of differentiation/integration operators

**2.3 Garbage Collection in Memory Management** (~0.5 page)
- Tracing vs reference counting (brief)
- Bacon's unified framework: both as fix-point computations over reachability
- The key parallel: "liveness" in GC ~ "freshness" in knowledge stores

**2.4 Embedding Model Drift** (~0.5 page)
- The Drift-Adapter problem: model upgrades invalidate embeddings
- Operational strategies (re-index, dual-index, adapter layers)
- Connection to GC: model migration as a special case of "generational" collection

**What goes here**:
- Definition 1: Graph-Vector Knowledge Store (G, V, phi, C)
- Definition 2: Consistency Invariant
- Definition 3: Staleness function

**Tables**: Table 1 -- Comparison of maintenance approaches (GC, IVM, ad-hoc) across dimensions

---

#### 3. Neural IVM: A Unified Theoretical Framework (3 pages)

**Content**: The core theoretical contribution. Unify GC and IVM concepts for graph-vector stores.

**3.1 The Neural IVM Framework** (~1.5 pages)
- Define the state space: a knowledge store as a stream of versioned snapshots
- The staleness operator S: maps a store snapshot to a "staleness map" over nodes/edges/embeddings
- The refresh operator R: maps a staleness map to a set of re-computation tasks
- The key theorem: S and R form a Galois connection (or adjunction), analogous to D and I in DBSP

**3.2 Staleness as Reachability** (~0.75 page)
- Graph staleness propagation: when a node changes, staleness propagates along edges (like tracing GC)
- Vector staleness: when an embedding model changes, all vectors are stale (like generational GC)
- Hybrid staleness: graph changes that invalidate vector semantics (the novel case)

**3.3 Correctness Properties** (~0.75 page)
- Theorem: ACID-compliant GC preserves query consistency
- Theorem: The staleness operator is monotone (more changes -> more staleness, never less)
- Theorem: Convergence -- iterated GC reaches a fixed point

**What goes here**:
- Definition 4: Staleness operator S
- Definition 5: Refresh operator R
- Definition 6: GC cycle (one round of S followed by R)
- Theorem 1: S-R adjunction (the unifying result)
- Theorem 2: ACID consistency preservation
- Theorem 3: Fixed-point convergence
- Corollary 1: Tracing GC and IVM delta-propagation are special cases

**Figures**: Fig 2 -- The S-R framework diagram (showing the parallel to DBSP's D-I and Bacon's tracing-RC duality). This is THE figure of the paper.

---

#### 4. Algorithms (2.5 pages)

**Content**: Derive practical algorithms from the theoretical framework.

**4.1 Staleness Detection** (~0.75 page)
- Algorithm 1: Graph-propagated staleness detection (BFS/DFS from changed nodes)
- Complexity analysis: O(|delta| * avg_degree) per change batch
- Integration with PostgreSQL's WAL for change capture

**4.2 Incremental Re-embedding** (~0.75 page)
- Algorithm 2: Priority-based incremental re-embedding
- Prioritization by: staleness score * query frequency * centrality
- Batch processing with transactional guarantees

**4.3 Transactional GC** (~1 page)
- Algorithm 3: ACID-compliant GC cycle
- The key challenge: maintaining read consistency while GC is running
- MVCC integration: GC operates on a snapshot, results applied atomically
- Comparison with stop-the-world vs concurrent GC (the memory management parallel)

**What goes here**:
- Algorithm 1: DETECT-STALENESS(G, V, delta)
- Algorithm 2: PRIORITIZED-REFRESH(stale_set, budget)
- Algorithm 3: TRANSACTIONAL-GC-CYCLE(store, snapshot_id)
- Complexity analysis for each algorithm

**Figures**: Fig 3 -- Algorithm flow diagram showing the GC cycle pipeline

---

#### 5. Implementation (1.5 pages)

**Content**: How KORE-GC is implemented on PostgreSQL + Apache AGE + pgvector.

**5.1 System Architecture** (~0.75 page)
- PostgreSQL as the unified substrate: AGE for graph, pgvector for vectors
- WAL-based change detection (no polling)
- The GC scheduler: timer-based with adaptive frequency

**5.2 Integration with Existing Pipelines** (~0.75 page)
- Integration with Ollama for re-embedding
- Integration with the KORE knowledge graph (the running system)
- Operational considerations: resource budgeting, backpressure

**What goes here**:
- Fig 4: System architecture diagram (PostgreSQL + AGE + pgvector + GC daemon)
- Table 2: System parameters and their defaults

---

#### 6. Experimental Evaluation (3 pages)

**Content**: Three experiment groups, each testing a different aspect.

**6.1 Experimental Setup** (~0.5 page)
- KORE dataset description: ~50K nodes, 5 domains, real knowledge graph
- Metrics: retrieval recall@k, MRR, staleness ratio, GC throughput
- Baselines: no-GC, full-reindex, periodic-batch, KORE-GC

**6.2 Degradation Measurement** (~0.75 page)
- Experiment 1: Measure retrieval quality degradation over time without GC
- Show the "silent failure" curve
- Quantify: how many graph changes before retrieval quality drops by X%?

**6.3 GC Effectiveness** (~1 page)
- Experiment 2: KORE-GC vs baselines on quality recovery
- Experiment 3: Incremental vs full re-embedding cost
- Show: KORE-GC recovers 95%+ quality at 10-100x less compute than full reindex

**6.4 ACID Advantage** (~0.75 page)
- Experiment 4: Query consistency during GC (with vs without transactions)
- Show: non-transactional GC causes query result inconsistencies
- Measure: fraction of queries returning mixed old/new results

**What goes here**:
- Table 3: Dataset statistics
- Table 4: Main results (quality metrics across baselines)
- Table 5: Cost comparison (compute time, embeddings recomputed)
- Fig 5: Degradation curves over time (the key empirical result)
- Fig 6: Recovery curves (quality vs GC iterations)
- Fig 7: ACID consistency comparison (scatter plot of query result consistency)

---

#### 7. Related Work (1.5 pages)

**Content**: Position against three communities.

**7.1 Knowledge Graph Maintenance** (~0.5 page)
- GraphRAG, LightRAG, and other graph-vector systems
- Their update mechanisms (if any) and limitations

**7.2 Incremental View Maintenance** (~0.5 page)
- DBSP, differential dataflow, materialized view maintenance
- How Neural IVM extends IVM to non-relational, vector-augmented stores

**7.3 Garbage Collection** (~0.5 page)
- Bacon's unified theory and its descendants
- Real-time GC, concurrent GC
- The analogy to knowledge store maintenance (our contribution)

---

#### 8. Discussion and Future Work (0.5 page)

- Limitations: single-node, specific to PostgreSQL ecosystem, embedding model assumptions
- Generalization to distributed stores
- Connection to embedding model versioning (Drift-Adapter as a complementary technique)
- The broader vision: self-maintaining knowledge stores

---

#### 9. Conclusion (0.5 page)

- Restate the unified framework contribution
- Key empirical findings (3 bullet points)
- The takeaway: knowledge stores need GC, and ACID matters

---

### Page Budget Summary

| Section | Pages | % of 13 |
|---------|-------|---------|
| 1. Introduction | 1.5 | 12% |
| 2. Background | 2.0 | 15% |
| 3. Neural IVM Theory | 3.0 | 23% |
| 4. Algorithms | 2.5 | 19% |
| 5. Implementation | 1.5 | 12% |
| 6. Experiments | 3.0 | 23% |
| 7. Related Work | 1.5 | 12% |
| 8. Discussion | 0.5 | 4% |
| 9. Conclusion | 0.5 | 4% |
| **References** | ~1.0 | -- |
| **TOTAL** | **~14** | -- |

This fits the 12-14 page arXiv target. For VLDB expansion to 14+, extend Sections 3 (add proofs) and 6 (add more experiments).

### Visual Elements Summary

| Element | Count | Location |
|---------|-------|----------|
| Definitions | 6 | Sections 2-3 |
| Theorems | 3 + 1 corollary | Section 3 |
| Algorithms | 3 (pseudocode) | Section 4 |
| Figures | 7-8 | Sections 1,3,4,5,6 |
| Tables | 5 | Sections 2,5,6 |

### The Narrative Thread (One-Sentence Per Section)

1. **Intro**: Knowledge stores silently degrade, and nobody has a principled framework for maintaining them.
2. **Background**: Three fields -- IVM, GC, and embedding drift -- each solve pieces of this problem in isolation.
3. **Theory**: We unify them: staleness detection IS tracing, re-embedding IS view refresh, and they form a Galois connection.
4. **Algorithms**: From the theory, we derive three concrete algorithms: detect, prioritize, refresh -- all transactional.
5. **Implementation**: We built it on PostgreSQL + AGE + pgvector, the same stack as KORE.
6. **Experiments**: Degradation is real and measurable; KORE-GC recovers quality at 100x less cost; ACID prevents query inconsistency.
7. **Related Work**: No prior system combines graph-aware staleness propagation, incremental re-embedding, and transactional guarantees.
8. **Discussion**: This generalizes beyond KORE to any co-located graph-vector store.
9. **Conclusion**: Knowledge stores need garbage collection. Here is the theory, the system, and the evidence.

---

## Part 4: Key Structural Decisions and Rationale

### Why Late Related Work (not Early)

The paper's core move is a unification. If Related Work comes first, the reader sees a literature review. If it comes after the theory, the reader sees "oh, these three separate fields are all instances of what we just defined." Bacon (OOPSLA 2004) and DBSP (VLDB 2023) both use this structure. It maximizes the "aha" moment.

### Why Separate Theory and Algorithms (not Merged)

DBSP merges theory and algorithms. But KORE-GC has a cleaner story with them separated:
- Section 3 answers "what is the right abstraction?"
- Section 4 answers "what do you actually compute?"

This separation also lets the theory section be self-contained (a standalone contribution) while the algorithms section is practically grounded. A reviewer who cares about theory reads Section 3; a reviewer who cares about systems reads Section 4.

### Why a Short Implementation Section

Following DBSP's model: the implementation is not the contribution. The contribution is the framework + algorithms + evidence. The implementation section exists to show it is buildable, not to describe engineering details.

### Why 3 Pages of Experiments (not 1.5 like DBSP)

DBSP can get away with light experiments because its theory is extremely strong (VLDB best paper). KORE-GC's theory is novel but not yet established -- it needs empirical validation to be convincing. The "degradation is real" experiment is especially important because it establishes the problem exists, not just that the solution works.

### Target Venue Consideration

- **arXiv first** at 13-14 pages.
- **VLDB submission**: expand theory proofs and add more experimental baselines to reach 14+ pages. VLDB allows extended appendices.
- **Alternative**: SIGMOD (similar format), ICDE, or a top NLP venue (EMNLP) if the graph-vector angle is emphasized over the DB theory angle.
