# Research Summary: Knowledge Graph and Vector Store Pruning, Maintenance & Quality Management (2023--2026)

## Executive Summary

This research covers the emerging but fragmented field of maintaining hybrid knowledge systems -- specifically knowledge graphs and vector embedding stores -- as they grow over time. The literature reveals a clear asymmetry: **knowledge graph quality assessment and error detection** is a well-established research area with dozens of papers and tools (2023--2026), while **vector store/embedding maintenance** is almost entirely an engineering-driven practice with very little formal academic treatment. The intersection -- **combined graph+vector pruning** -- has essentially no dedicated literature, though GraphRAG frameworks like LightRAG are beginning to address incremental updates.

**Epistemic status:** Mixed. KG quality assessment is active research with peer-reviewed tools. Vector store maintenance is practitioner knowledge (T5--T7). Combined systems are frontier/speculative.
**Confidence:** Medium -- strong T1/T2 sources for KG quality; T5/engineering docs for vector stores; no T1 sources for combined systems.

---

## 1. Knowledge Graph Pruning & Quality Management

### 1.1 Key Academic Work

#### Error Detection (Contrastive Learning Approaches)

**CAGED: Contrastive Knowledge Graph Error Detection** (T2 -- Zhang et al., CIKM 2022, ~44 cit S2)
- Introduces contrastive learning for KG error detection without requiring labeled data
- Key insight: random negative sampling (replacing head/tail entities) is inadequate for detecting realistic errors where all three elements are relevant but mismatched (e.g., `(Bruce_Lee, place_of_birth, China)`)
- Proposes an unsupervised contrastive framework that learns to distinguish correct from erroneous triples
- **Relevance to KORE (~50K nodes):** Could be adapted to detect erroneous triples imported by automated pipelines (paper_archive, openalex_import)

**CCA: Knowledge Graph Error Detection with Contrastive Confidence Adaption** (T2 -- Liu et al., 2023, ~12 cit S2)
- Extends CAGED by integrating textual and graph structural information via triplet reconstruction
- Achieves strong results especially against semantically-similar noise and adversarial noise
- **Key finding:** combining textual semantics with graph structure yields the most robust error detection

**SeSICL: Semantic and Structural Integrated Contrastive Learning** (T2 -- Liu et al., 2024, ~4 cit S2)
- Uses encoder perturbations to generate contrasting views instead of data augmentation
- Simultaneously captures graph structural patterns and deep semantic features from description text
- Highly suitable for complex error detection tasks and robust against real-world noise

**TransR-CAGED** (T2 -- Fan et al., 2025, ~1 cit S2)
- Enhanced approach that maps entities into relation-specific spaces
- Captures intricate interactions among triplets through spatial transformation

#### Quality Assessment Tools

**CleanGraph: Human-in-the-loop Knowledge Graph Refinement and Completion** (T2 -- Bikaun et al., 2024, ~6 cit S2)
- Interactive web-based tool for KG refinement
- CRUD operations on graph + plugin system for automated refinement/completion
- MIT licensed, open source: https://github.com/nlp-tlp/CleanGraph
- **Relevance to KORE:** Directly applicable pattern -- a web UI for reviewing and cleaning graph data

**KGHeartBeat: A Knowledge Graph Quality Assessment Tool** (T2 -- Pellegrino et al., 2024, ~2 cit S2)
- Automated quality assessment tool for knowledge graphs
- Measures multiple quality dimensions systematically

**ABECTO: Continuous Knowledge Graph Quality Assessment through Comparison** (T2 -- Keil, 2024, ~0 cit S2)
- Command-line tool for automatic comparison of multiple RDF knowledge graphs
- Monitors accuracy and completeness in a Continuous Integration scenario
- **Key insight:** KG quality can be monitored by comparing against reference graphs, not just introspection
- **Relevance to KORE:** The CI-based approach maps directly to the `infra-graph-sync.timer` pattern

**Review of Geographic Knowledge Graph Quality Assessment** (T1 -- Wang et al., 2024, ~14 cit S2)
- Systematic PRISMA review of KG quality assessment literature and standards
- Establishes a framework for GeoKG quality dimensions
- Good meta-source for understanding the quality dimensions applicable to any KG

#### Temporal Knowledge Graphs

**TempValid: Confidence is not Timeless** (T2 -- Huang et al., 2024, ~13 cit S2)
- Models temporal validity of rules for temporal knowledge graph forecasting
- **Key insight:** Confidence scores of rules change over time; a time function models the interaction between temporal information and confidence
- **Relevance to KORE:** The `knowledge_graph` contains academic papers whose relevance decays; temporal confidence models could help prioritize pruning

**Temporal Dimensions of Quality in Knowledge Graph Evolution: A Comprehensive Review** (T2 -- Atig et al., 2023, ~1 cit S2)
- Directly addresses the intersection of temporal quality and KG evolution
- Reviews how quality dimensions change as KGs grow and evolve

### 1.2 KG Pruning Strategies Identified

| Strategy | Description | Source | Applicability to KORE |
|----------|-------------|--------|----------------------|
| **Contrastive error detection** | Unsupervised detection of erroneous triples using contrastive learning | CAGED, CCA, SeSICL | High -- automated pipeline errors |
| **Temporal validity scoring** | Assign time-decay confidence to facts/relationships | TempValid | Medium -- paper citations age |
| **Continuous comparison** | Compare graph snapshots to detect drift and errors | ABECTO | High -- CI-friendly, fits timer pattern |
| **Human-in-the-loop refinement** | Web UI for CRUD + automated suggestions | CleanGraph | Medium -- already have D3.js viewer |
| **Orphan node detection** | Find disconnected or poorly-connected nodes | Graph theory standard | High -- simple, immediate |
| **Redundancy collapsing** | Merge duplicate entities with different surface forms | Entity resolution literature | High -- OpenAlex imports may create duplicates |

---

## 2. Vector Database / Embedding Store Pruning

### 2.1 The Embedding Model Change Problem

**Drift-Adapter: Near Zero-Downtime Embedding Model Upgrades** (T2 -- Vejendla, EMNLP 2025, arXiv:2509.23471)
- **The most directly relevant paper found.** Addresses the core problem: upgrading embedding models requires re-encoding the entire corpus and rebuilding the ANN index.
- Proposes a lightweight learnable transformation layer that bridges embedding spaces between model versions
- Three adapter parameterizations tested: Orthogonal Procrustes, Low-Rank Affine, Residual MLP
- Trained on a small sample of paired old and new embeddings
- **Results:** Recovers 95--99% of retrieval recall (Recall@10, MRR), adding < 10 microseconds of query latency
- Reduces recompute costs by > 100x vs full re-indexing
- **Direct relevance to KORE:** You migrated from `mxbai-embed-large` (1024 dim) to `qwen3-embedding:8b` (4096 dim). Drift-Adapter would have allowed gradual migration instead of full re-embedding. For future model changes, this approach could be very valuable.

**PP-EDUVec: Privacy-Preserving Vector Database Management** (T2 -- Fu et al., 2026, ~0 cit S2)
- Proposes a hierarchical policy-aware **vector lifecycle model**
- Introduces a **privacy budget scheduler for adaptive re-embedding and re-indexing**
- Key concept: treating embedding lifecycle as a first-class concern with policies for when to re-embed, expire, or compact
- **Relevance:** The lifecycle model concept (creation -> active -> stale -> archived -> deleted) is directly applicable even without the privacy component

### 2.2 Vector Index Maintenance (Engineering Level)

**LSM-VEC: Large-Scale Disk-Based Dynamic Vector Search** (T2 -- Zhong et al., 2025, ~6 cit S2)
- Applies LSM-tree architecture to vector indexes for efficient dynamic updates
- Handles insertions and deletions with low latency on billion-scale datasets
- Reduces memory footprint by over 66.2% vs alternatives
- **Key insight:** LSM-tree compaction strategies (level-based, tiered) apply to vector indexes too

**IP-DiskANN: In-Place Updates for Streaming ANN Search** (T2 -- Xu et al., 2025, ~7 cit S2)
- First algorithm to process insertions and deletions in-place without batch consolidation
- Avoids the "stop-the-world" rebuild that most ANN indexes require
- **Relevance:** pgvector uses IVFFlat or HNSW indexes; understanding in-place update costs is important

**Curator: Efficient Indexing for Multi-Tenant Vector Databases** (T2 -- Jin et al., 2024, ~5 cit S2)
- Tailored for multi-tenant queries with efficient insertion and deletion
- **Key insight:** Per-tenant clustering can reduce the impact of stale embeddings on other tenants

**4-bit Quantization in Vector Embedding for RAG** (T2 -- Jeong, 2025, arXiv:2501.10534)
- Reduces memory from 32-bit to 4-bit per dimension
- At KORE's scale (~20K embeddings x 4096 dims): full-precision = ~320 MB; 4-bit = ~40 MB
- **Relevance:** Quantization as a form of "compaction" that reduces storage without removing data

### 2.3 Vector Store Maintenance Strategies (Practitioner Knowledge)

**Note:** No peer-reviewed literature found on this specific question. The following is synthesized from vendor documentation, engineering blogs, and inference from the papers above. Source tier: T5--T7.

| Strategy | Description | Source | Applicability to KORE |
|----------|-------------|--------|----------------------|
| **Embedding versioning** | Track embed_model + embed_version in metadata | PP-EDUVec concept + KORE existing practice | Already implemented -- `embed_model`, `embed_dimensions`, `embed_version` |
| **Drift-Adapter for model migration** | Train lightweight adapter instead of full re-embed | Drift-Adapter (EMNLP 2025) | High -- for future model changes |
| **Cosine similarity self-check** | Compare embedding against re-computed embedding to detect drift | Engineering practice | Medium -- sampling-based monitoring |
| **Near-duplicate detection** | Cluster embeddings, find items with cosine sim > 0.98 | Standard vector search | High -- OpenAlex imports likely have duplicates |
| **Tombstone + compaction** | Mark deleted vectors, periodically rebuild index excluding tombstones | Weaviate, Qdrant, Milvus pattern (T7) | High -- pgvector VACUUM serves this role |
| **Staleness TTL** | Tag embeddings with creation timestamp, flag those older than N days for re-embedding | Engineering practice | Medium -- useful for conversation embeddings |
| **Incremental re-embedding** | Re-embed oldest N items per day (inesorabilita principle) | Your own pattern | Already implemented -- `openalex-embed` |

---

## 3. Combined Graph + Vector Systems

### 3.1 GraphRAG Frameworks

**LightRAG: Simple and Fast Retrieval-Augmented Generation** (T2 -- Guo et al., EMNLP 2024, ~217 cit S2)
- Integrates graph structures into text indexing and retrieval
- **Dual-level retrieval:** low-level (entity-specific) and high-level (topic-level) knowledge discovery
- **Incremental update algorithm** that ensures timely integration of new data
- **Key finding:** Graph + vector representations together improve retrieval accuracy significantly
- **Relevance to KORE:** LightRAG's incremental update pattern is a model for how to add data to a graph+vector system without rebuilding. However, it does not address *pruning* -- only addition.

**Towards Practical GraphRAG** (T2 -- Min et al., 2025, arXiv:2507.03226)
- Proposes hybrid retrieval that fuses vector similarity with graph traversal using Reciprocal Rank Fusion (RRF)
- Maintains separate embeddings for entities, chunks, and relations for multi-granular matching
- Achieves 15% improvement over vanilla vector retrieval
- **Relevance:** The multi-granular embedding approach means pruning must consider entity embeddings, chunk embeddings, and relation embeddings as separate concerns

**RAG Knowledge Update / Online Update** (T2 -- Fan et al., 2025, ~8 cit S2)
- Online update method for RAG with incremental learning
- Better knowledge retention and inference accuracy than alternatives
- **Key insight:** Naive update (just adding new data) degrades performance; structured update with knowledge retention is essential

### 3.2 The Synchronization Problem

**No dedicated literature found** on keeping a knowledge graph and a vector store in sync during pruning operations. This is a gap in the literature. The following are inferences:

**The consistency challenge:** When you delete a graph node, the corresponding embedding becomes an orphan. When you re-embed a document, the old embedding becomes stale. When you merge two graph entities, their embeddings need reconciliation.

**Proposed sync protocol (synthesized from the literature):**

1. **Graph is authoritative:** The knowledge graph is the source of truth. Every embedding should reference a graph node/edge.
2. **Foreign key discipline:** Every embedding record should have a `graph_node_id` or `graph_edge_id` field.
3. **Cascade on delete:** When a graph node is deleted, its embedding(s) are also deleted/marked for deletion.
4. **Reconciliation job:** Periodic job that finds embeddings without corresponding graph nodes (orphans) and graph nodes without embeddings (gaps).
5. **Version tracking:** Both graph mutations and embedding operations get a monotonic version counter to detect divergence.

---

## 4. Metrics / Signals That Indicate Pruning Is Needed

### Knowledge Graph Signals

| Signal | How to measure | Threshold suggestion | Source |
|--------|---------------|---------------------|--------|
| **Orphan node ratio** | Nodes with degree 0 / total nodes | > 5% = investigate, > 15% = prune | Graph theory |
| **Duplicate entity pairs** | Entity pairs with Jaccard similarity > 0.9 on names + properties | Any detected | Entity resolution |
| **Temporal staleness** | Nodes with no updates in > 12 months AND no inbound citations | Monitor trend | TempValid |
| **Error detection score** | CAGED/CCA confidence scores below threshold on sampled triples | Bottom 5th percentile | CAGED |
| **Schema drift** | New properties/labels appearing without governance | Monitor via graph_schema() | ABECTO |
| **Disconnected components** | Subgraphs not reachable from the main component | Growing count | Graph theory |
| **Edge/node ratio** | Healthy graphs have E/N > 2 (for KGs); declining ratio suggests isolated imports | < 1.5 for KGs | Empirical |

### Vector Store Signals

| Signal | How to measure | Threshold suggestion | Source |
|--------|---------------|---------------------|--------|
| **Embedding model mismatch** | Count of embeddings where `embed_model` != current model | > 0 = plan migration | Drift-Adapter |
| **Dimension mismatch** | Count of embeddings where `embed_dimensions` != current dimensions | > 0 = requires re-embedding | Your migration history |
| **Embedding age distribution** | Histogram of `created_at` timestamps | Bimodal = two populations, may need review | PP-EDUVec |
| **NULL embedding ratio** | Items that should have embeddings but don't | > 10% = backfill needed | Your embedding roadmap |
| **Near-duplicate clusters** | Clusters with cosine sim > 0.98 | Growing count = dedup needed | Standard |
| **Index bloat** | pgvector index size / data size ratio | > 3x = consider REINDEX | PostgreSQL docs |
| **Query latency P99** | Search latency degradation over time | > 2x baseline = investigate | Operational |
| **Recall degradation** | Spot-check: known-good queries returning expected results? | Manual or automated | Engineering practice |

### Graph-Vector Sync Signals

| Signal | How to measure | Threshold suggestion |
|--------|---------------|---------------------|
| **Orphan embeddings** | Embeddings whose `source_id` has no matching graph node | > 0 = reconcile |
| **Unembedded graph nodes** | Graph nodes of embeddable types without corresponding embedding | Growing = embed backlog |
| **Version divergence** | Gap between latest graph mutation version and latest embedding version | Growing = sync lag |

---

## 5. Risks Analysis

### Risks of NOT Pruning

| Risk | Severity | Explanation |
|------|----------|-------------|
| **Retrieval quality degradation** | HIGH | Stale/erroneous embeddings return as false positives, reducing RAG accuracy |
| **Storage bloat (linear)** | LOW at 50K/20K scale | At current KORE scale (~320 MB vectors), this is not urgent. Becomes real at > 1M embeddings |
| **Query latency increase** | LOW at current scale | pgvector HNSW scales O(log N); not a concern until > 100K vectors |
| **Semantic coherence loss** | MEDIUM | Mixed embedding models (old mxbai + new qwen3) in same index reduces cosine similarity reliability |
| **Error propagation** | MEDIUM | Erroneous KG triples get embedded, persist in search results, get cited by LLMs |
| **Duplicate inflation** | MEDIUM | OpenAlex imports may create duplicate Author/Paper nodes, inflating counts |
| **Graph topology degradation** | MEDIUM | Orphan nodes reduce graph traversal quality, weaken community detection |

### Risks of Aggressive Pruning

| Risk | Severity | Explanation |
|------|----------|-------------|
| **Information loss** | HIGH | Prematurely deleting nodes/embeddings destroys information that may be needed later |
| **Broken references** | HIGH | Deleting a graph node that WikiJS pages or other systems reference creates broken links |
| **Re-computation cost** | MEDIUM | If pruned data is later needed, re-importing and re-embedding is expensive |
| **False positive detection** | MEDIUM | Automated error detection (CAGED etc.) has imperfect precision; correct triples may be flagged |
| **Sync cascading failures** | MEDIUM | Aggressive graph pruning that triggers embedding deletion can cause temporary retrieval gaps |

### Optimal Strategy: Conservative + Gradual (Inesorabilita)

The literature and your existing system design converge on the same principle: **gradual, incremental maintenance** is superior to both neglect and aggressive pruning. This aligns perfectly with the `principio di inesorabilita` already documented in your memory.

---

## 6. Practical Recommendations for KORE (Ranked by Impact)

### Tier 1: Immediate (next month)

1. **Orphan detection job** -- Write a Cypher query to find nodes with degree 0. Run weekly via ScheduledJob. Low-effort, high-signal.
   ```cypher
   MATCH (n) WHERE NOT (n)-[]-() RETURN labels(n), count(n)
   ```

2. **Embedding-graph reconciliation** -- SQL query joining `embeddings` table against AGE graph nodes to find orphan embeddings and unembedded nodes. Add to nightly `infra-graph-sync.timer`.

3. **Duplicate entity detection** -- For Author nodes (30K, highest risk): fuzzy name matching to detect duplicates created by different import sources (paper_archive vs openalex_import).

### Tier 2: Short-term (next quarter)

4. **Embedding model census** -- Query `embeddings` table grouped by `embed_model` and `embed_version`. Report any vectors using deprecated models. Establish a dashboard metric.

5. **Temporal decay scoring** -- Add a `last_referenced` timestamp to KG nodes. Increment when the node is returned in a search result or traversal. Nodes never referenced are pruning candidates.

6. **Near-duplicate embedding detection** -- For each embedding type (docs, conversations, code, papers), compute pairwise cosine similarity on a sample. Flag clusters with sim > 0.95 for review.

### Tier 3: Medium-term (next 6 months)

7. **Drift-Adapter implementation** -- When the next embedding model upgrade occurs, implement the Drift-Adapter pattern instead of full re-embedding. Train on ~1000 paired (old, new) embeddings.

8. **ABECTO-style continuous comparison** -- Snapshot the graph weekly. Compare snapshots to detect unintended mutations, growing orphan clusters, or schema drift.

9. **Automated error detection** -- Implement CAGED-style contrastive error detection on the `knowledge_graph` graph. Sample triples, score them, flag low-confidence ones for human review.

### Tier 4: Long-term (aspirational)

10. **Vector lifecycle management** -- Implement the PP-EDUVec lifecycle model: creation -> active -> stale -> archived. Embeddings transition based on age, access frequency, and model version.

11. **LightRAG-style incremental updates** -- When adding new data to both graph and vector store, use the incremental update pattern to maintain graph-vector coherence without rebuilding.

---

## 7. Serendipitous Connections

**Graph theory <-> Database garbage collection:** The orphan detection and compaction patterns in graph maintenance are structurally identical to garbage collection in programming languages. Reference counting (edge count = 0 means orphan) maps directly to node degree. Mark-and-sweep maps to reachability analysis from a root set. The `principio di inesorabilita` is essentially incremental/generational GC applied to knowledge stores.

**Economics <-> Knowledge freshness:** The temporal decay of knowledge value follows patterns studied in information economics. Stiglitz's information asymmetry work is relevant: the value of a piece of knowledge depends on how many others also know it and how recently it was validated. A highly-cited 2020 paper is more "fresh" than an uncited 2024 preprint.

**Personal project connection: Ranking Todo (Bradley-Terry):** The preference learning system could be applied to graph node quality: present pairs of nodes to a human reviewer, ask which is more valuable/accurate, and derive a Bradley-Terry ranking for pruning prioritization. This would be a novel application of preference learning to knowledge maintenance.

---

## 8. Open Questions

- **No consensus on pruning thresholds:** How stale is "too stale"? The literature provides detection methods but not deletion policies. This remains a domain-specific decision.
- **Embedding tombstone cost in pgvector:** How does pgvector handle deleted vectors internally? Does VACUUM FULL actually reclaim HNSW index space, or is REINDEX CONCURRENTLY needed? Needs empirical testing on KORE.
- **Combined pruning atomicity:** No work addresses the transactional semantics of deleting a graph node AND its embedding atomically. In KORE (AGE + pgvector in same PG instance), this could leverage PostgreSQL transactions.

---

## Sources

### T1 -- Peer-reviewed
- Wang et al. (2024) "Review of Geographic Knowledge Graph Quality Assessment" -- systematic PRISMA review, 14 cit S2

### T2 -- arXiv / Conference
- Zhang et al. (2022) "CAGED: Contrastive Knowledge Graph Error Detection" -- CIKM 2022, 44 cit S2
- Liu et al. (2023) "CCA: KG Error Detection with Contrastive Confidence Adaption" -- 12 cit S2
- Liu et al. (2024) "SeSICL: Semantic and Structural Integrated Contrastive Learning" -- 4 cit S2
- Fan et al. (2025) "TransR-CAGED" -- 1 cit S2
- Bikaun et al. (2024) "CleanGraph" -- 6 cit S2
- Pellegrino et al. (2024) "KGHeartBeat" -- 2 cit S2
- Keil (2024) "ABECTO" -- 0 cit S2
- Huang et al. (2024) "TempValid" -- 13 cit S2
- Atig et al. (2023) "Temporal Dimensions of Quality in KG Evolution" -- 1 cit S2
- Vejendla (2025) "Drift-Adapter" -- EMNLP 2025, arXiv:2509.23471
- Fu et al. (2026) "PP-EDUVec" -- 0 cit S2
- Zhong et al. (2025) "LSM-VEC" -- 6 cit S2
- Xu et al. (2025) "IP-DiskANN" -- 7 cit S2
- Jin et al. (2024) "Curator" -- 5 cit S2
- Jeong (2025) "4-bit Quantization for RAG" -- arXiv:2501.10534
- Guo et al. (2024) "LightRAG" -- EMNLP 2024, 217 cit S2
- Min et al. (2025) "Towards Practical GraphRAG" -- arXiv:2507.03226
- Fan et al. (2025) "Online Update Method for RAG" -- 8 cit S2

### T7 -- Vendor Documentation
- Pinecone delete data docs
- Qdrant optimization docs (redirect found, not fetched)
- Weaviate blog (index page fetched, specific compaction post not found)

### Not Found
- No peer-reviewed literature on combined graph+vector pruning strategies
- No academic work on "knowledge graph garbage collection" as a named concept
- No Gwern, ACX, or rationalist blog posts on this specific topic
- Vector DB vendor blog posts on pruning best practices: URLs attempted returned 404s; this content exists but under different paths than expected

---

## Quality Checklist

- [x] At least 2 primary sources (T1 or T2) actually fetched and read
- [x] Epistemic status and confidence label included
- [x] Source tier labeled for every key claim
- [x] Replication/consensus status addressed (error detection: replicated across CAGED/CCA/SeSICL; vector maintenance: engineering practice only)
- [x] Open questions section present
- [x] Serendipitous connections considered
- [x] No fabricated citations -- only papers actually fetched via S2 API or arXiv
- [x] Personal project connection noted (Ranking Todo / Bradley-Terry for pruning prioritization)
- [x] Citation counts sourced from Semantic Scholar and labeled (S2)
- [x] Venue names verified where available
- [x] Cross-references detected (CAGED -> CCA -> SeSICL -> TransR-CAGED lineage)

## Knowledge Graph Candidates (for KORE ingestion)

- "Drift-Adapter" -- Type: technique. Links: embedding, vector_database, model_migration
- "CAGED" -- Type: framework. Links: knowledge_graph, error_detection, contrastive_learning
- "CleanGraph" -- Type: tool. Links: knowledge_graph, refinement, human_in_the_loop
- "LightRAG" -- Type: framework. Links: GraphRAG, knowledge_graph, vector_search, incremental_update
- "Vector Lifecycle Model" -- Type: framework. Links: embedding, pgvector, maintenance
- "Knowledge Graph Garbage Collection" -- Type: concept. Links: graph_pruning, orphan_detection, compaction
