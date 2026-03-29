# Research Summary: Query-Adaptive Source Selection and Routing for Multi-Source RAG Systems

## Executive Summary

Query routing in multi-source RAG is a rapidly maturing subfield (2024-2026) with strong academic activity. The core finding: **query-adaptive source selection consistently outperforms static "search everything" approaches**, but the optimal routing method depends heavily on system scale and latency constraints. For a small heterogeneous system like yours (3 source types, ~2600 documents), a lightweight heuristic + RRF fusion approach is likely superior to ML-based routing, which targets systems with 5+ heterogeneous backends.

**Epistemic status:** Active research front with early empirical results; no established consensus yet on best practices for small-scale multi-source RAG.
**Confidence:** Medium -- strong preprints (T2), framework implementations, but limited replicated benchmarks for the specific docs/conversations/papers trifecta.

---

## Key Findings

### 1. Query Classification for Source Routing

**Finding: Query routing is now a well-defined subfield with multiple competing approaches, from rule-based to learned routers.** (T2 -- multiple arXiv 2025 papers)

The literature identifies three tiers of routing complexity:

**a) Keyword/Heuristic Routing (no ML model needed)**

This is the most practical approach for small systems. The pattern:
- Define a set of signal words or query patterns per source type
- Use regex or simple token matching to classify
- Fall back to "query all" if no strong signal

For your system specifically:
- `docs` queries: mentions of service names, config terms, file paths, "how to", "where is", operational vocabulary
- `conversations` queries: "did I", "we discussed", "last time", "previous conversation", temporal references, first-person plural
- `papers` queries: author names, paper titles, "research on", "literature", technical/academic vocabulary, arXiv IDs

**b) Embedding-Based Classification (lightweight ML)**

Compute the query embedding and compare cosine similarity to **prototype embeddings** for each source type. Prototype = mean embedding of all documents in that source. The source with highest similarity gets priority. This is essentially a nearest-centroid classifier with zero training.

**c) Learned Routers (heavier ML)**

- **"Learning to Route"** (Bai et al., arXiv:2510.02388, T2): A rule-driven agent framework for hybrid-source RAG. Formalizes routing as: given query q, select an action from {structured_KB, unstructured_docs, web_search}. Uses rule-based agent with LLM as backbone. Key insight: **routing rules can be extracted from a small set of labeled examples and then applied at scale without LLM in the loop**.

- **"Unsupervised Query Routing for RAG"** (Mu et al., arXiv:2501.07793, T2): Constructs "upper-bound" responses (by querying all engines) to evaluate which engine produces the best response per query. Trains a lightweight classifier on this synthetic data. **No manual annotation needed.** Tested on 5 datasets, shows significant improvement in scalability and generalization.

- **"RAGRouter"** (Zhang et al., arXiv:2505.23052, T2): Routes queries to the most suitable LLM (not source), but the technique generalizes. Uses contrastive learning on document embeddings + "RAG capability embeddings" to capture how retrieved documents shift knowledge representation. Code: https://github.com/OwwO99/RAGRouter

- **"Dynamic Query Routing with Aleatoric and Epistemic Uncertainty"** (Giri et al., 2025, T3 -- ResearchGate): Explicitly models aleatoric (data) and epistemic (model) uncertainty in routing decisions. Routes high-uncertainty queries to broader search, low-uncertainty to targeted sources.

### 2. Source Weighting and Score Normalization

**Finding: Reciprocal Rank Fusion (RRF) is the dominant practical approach for merging results from heterogeneous sources, consistently outperforming weighted linear combination for systems without extensive tuning data.** (T1 -- Cormack et al., SIGIR 2009; extensive subsequent validation)

**Reciprocal Rank Fusion (Cormack, Clarke & Buettcher, 2009)**

The seminal formula: `RRF_score(d) = SUM(1 / (k + rank_i(d)))` for each ranker i, where k = 60 (default constant).

Key properties for your use case:
- **Score-distribution agnostic**: Does not require normalizing cosine similarities across different pgvector indexes. This is critical because your docs, conversations, and papers likely have very different score distributions (different document lengths, different embedding density)
- **No tuning required**: The k=60 default works well across most scenarios
- **Trivially parallelizable**: Query all sources, merge by RRF

**Weighted linear combination** requires:
- Score normalization (min-max or z-score per source), which is fragile when source distributions shift over time
- Weight tuning, which requires labeled relevance data

**"Know When to Fuse" (Louis et al., COLING 2025, T1)**: Found that hybrid combinations do NOT always improve over individual systems. The paper reports that normalized score fusion with tuned weights can underperform a single good retriever. **Recommendation: always keep a "best single source" baseline and measure whether fusion actually helps.**

**"MoR: Mixture of Sparse, Dense, and Reranking"** (arXiv:2506.15862, T2): Proposes a mixture-of-retrievers approach where different retrieval methods (BM25, dense, reranker) are dynamically combined based on query characteristics. Directly references LangChain's EnsembleRetriever as a baseline.

### 3. Multi-Index RAG Systems

**Finding: Multi-source RAG systems that query multiple indices and merge results show 15-80% improvement over single-index baselines in enterprise settings, but gains depend heavily on source heterogeneity.** (T2 -- multiple 2025 papers; range reflects different benchmarks)

- **"MultiRAG"** (Wu et al., arXiv:2508.03553, ICDE 2025, T1-equivalent): Addresses hallucination from multi-source conflicts. Uses multi-source line graphs to aggregate logical relationships and a multi-level confidence calculation (graph-level + node-level) to filter unreliable nodes. Tested on 4 multi-domain QA datasets and 2 multi-hop QA datasets. Code: https://github.com/wuwenlong123/MultiRAG

- **"DeepSieve"** (Guo et al., arXiv:2507.22050, EACL Findings 2026, T1): LLM-as-a-knowledge-router. Decomposes complex queries into sub-questions and recursively routes each to the most suitable source. Multi-stage distillation filters irrelevant information. Code: https://github.com/MinghoKwok/DeepSieve

- **Enterprise Hybrid Retrieval** (Rao et al., arXiv:2510.10942, T2): Framework for heterogeneous enterprise sources (Jira, Git, Confluence, wikis -- very analogous to your docs/conversations/papers). Reports 80% improvement in answer relevance over standalone GPT-based retrieval. Key design: query analysis dynamically determines optimal retrieval strategy.

- **KDD Cup 2024 CRAG benchmark**: Multi-source knowledge pruning task that established a reference benchmark for RAG with multiple sources. Query routing to map queries to appropriate APIs/sources is a core component.

### 4. Information Foraging Diet Model

**Finding: The Information Foraging Theory Diet Model has NOT been directly implemented in any RAG system I could find. However, the theoretical framework maps elegantly onto source selection and provides a principled decision criterion.** (T1 -- Pirolli & Card 1999; T2 -- Azzopardi & Roegiest 2026)

The Diet Model (Pirolli & Card, 1999) from Information Foraging Theory:
- An information forager should include a source type in their "diet" if: `profitability(source) = relevance_gain / processing_cost > threshold`
- Sources are ranked by profitability and included greedily until the marginal profitability drops below the cost of including the next source

**Application to your 3-source system:**

| Source | Relevance for operational queries | Processing cost (latency) | Profitability |
|--------|-----------------------------------|---------------------------|--------------|
| docs | High | ~pgvector query time | High |
| conversations | Medium (contextual) | ~pgvector query time | Medium |
| papers | Low (academic) | ~pgvector query time | Low |

Since all three share the same pgvector backend, processing cost is roughly equal, so the Diet Model reduces to **rank by expected relevance**. This is precisely the query classification problem from Section 1.

**"Information Farming: From Berry Picking to Berry Growing"** (Azzopardi & Roegiest, arXiv:2601.12544, 2026, T2): Recent paper that updates Berry Picking and Information Foraging Theory for the RAG era. Argues that RAG systems should move from passive retrieval to active "information farming" -- curating and growing knowledge sources.

**Practical Diet Model heuristic for your system:**
```
For each query q:
  1. Classify q into {operational, conversational, academic, mixed}
  2. If operational: search docs only (profitability threshold met by docs alone)
  3. If conversational: search conversations, then docs as fallback
  4. If academic: search papers, then docs as fallback
  5. If mixed/unclear: search all three, merge with RRF
```

### 5. Practical Framework Patterns

**LlamaIndex RouterQueryEngine / RouterRetriever**

(T7 -- framework documentation, https://developers.llamaindex.ai)

The LlamaIndex pattern works as follows:
1. Define multiple query engines or retrievers (one per source type)
2. Attach a natural-language description to each ("this index contains documentation about server infrastructure", "this index contains conversation transcripts", etc.)
3. A `Selector` (LLM-based or rule-based) reads the query + descriptions and selects which engine(s) to invoke
4. `select_multi=True` allows selecting multiple engines and merging results

Two selector types:
- `LLMSingleSelector` / `LLMMultiSelector`: Uses an LLM call to pick the right engine(s). Adds latency (1 LLM call) but handles ambiguous queries well.
- `PydanticSingleSelector` / `PydanticMultiSelector`: Uses structured output from an LLM to select. More reliable parsing.

**Key limitation**: Every routing decision costs one LLM call. For high-throughput or low-latency systems, this is prohibitive.

**LangChain EnsembleRetriever**

(T7 -- framework documentation)

Simpler pattern:
1. Define multiple retrievers
2. Assign weights to each: `EnsembleRetriever(retrievers=[r1, r2, r3], weights=[0.5, 0.3, 0.2])`
3. All retrievers are queried in parallel
4. Results are merged using **Reciprocal Rank Fusion (RRF)**
5. Weights modulate the RRF contribution of each retriever

**Key insight**: LangChain's EnsembleRetriever always queries ALL retrievers. It does not route -- it fuses. This is the "query everything, merge smartly" approach rather than the "route to the right source" approach. For 3 sources on the same pgvector instance, this may be perfectly adequate.

---

## Recommendation for Your System

Given: 3 source types (docs ~2100, conversations ~437, papers ~105), all in pgvector with mxbai-embed-large, accessed via MCP tools.

### Option A: Unified Search with Heuristic Pre-filtering + RRF (Recommended)

1. **Create a single `embeddings_search(query, source_types, weights)` tool** that:
   - Accepts optional `source_types` filter (default: all)
   - Queries pgvector with a `WHERE label IN (...)` clause
   - Returns results with source label attached

2. **Add lightweight query classification** (no ML):
   ```
   if query mentions service/config/path/operation terms -> weight docs 0.6, conv 0.2, papers 0.2
   if query mentions "we discussed"/"last time"/"previous" -> weight conv 0.6, docs 0.3, papers 0.1
   if query mentions academic/research/paper terms -> weight papers 0.5, docs 0.3, conv 0.2
   else -> equal weights 0.34, 0.33, 0.33
   ```

3. **Apply RRF** across source types within pgvector results (trivial: just rank by `1/(60+rank)` per source type and sum)

**Estimated effort**: Small -- modify the existing MCP search tool to accept source type weights.
**Expected gain**: Moderate -- better precision for clearly typed queries, no degradation for ambiguous ones.

### Option B: Embedding Prototype Router (Medium effort, if Option A underperforms)

1. Pre-compute mean embedding for each source type (docs, conv, papers)
2. For each query, compute cosine similarity to each prototype
3. Use similarity ratios as weights for RRF

This is the unsupervised nearest-centroid approach. No training data needed. The prototypes can be recomputed nightly alongside the reindex job.

### Option C: LLM-Based Router (Highest quality, highest latency)

Only if queries are complex and ambiguous enough to justify an LLM call per query. The LlamaIndex RouterQueryEngine pattern is a good reference implementation.

---

## Open Questions

- **Score distribution calibration**: How different are cosine similarity distributions across your 3 source types? If papers have systematically higher/lower scores than docs (due to different document lengths or content density), raw score merging will be biased. RRF avoids this.

- **Temporal routing signals**: Conversations have timestamps. Should recent conversations be boosted? The Diet Model doesn't account for recency, but it could be added as a profitability modifier.

- **Cross-source deduplication**: If a concept appears in both docs and papers, how to avoid near-duplicate results? RRF naturally handles this if the same document appears in multiple result sets (it gets boosted).

- **Evaluation**: No standard benchmark exists for "which source type should this query go to?" in a personal knowledge base. You'd need to create a small evaluation set (50-100 queries with expected source type labels) to compare Option A vs B.

## Serendipitous Connections

**Information Foraging Theory and Bradley-Terry (Ranking Todo project)**: The Diet Model's profitability ranking is structurally analogous to the Bradley-Terry model used in your preference-sort system. Both solve: "given a set of items with latent quality, how to rank them optimally." The Diet Model adds a cost term (processing time) that Bradley-Terry lacks. You could potentially use preference-sort to calibrate source weights: present pairs of search results (one from docs, one from papers) and let user preference implicitly learn which source is more valuable for which query type.

**Knowledge Graph enrichment (Kindle Graph project)**: The multi-source routing problem maps onto your Neo4j knowledge graph. Source types could become node properties or edge labels in AGE, enabling graph-based query routing: "find concepts that span multiple source types" as a signal for multi-source queries.

**Optimal foraging in ecology and economics**: The Diet Model is literally imported from behavioral ecology (optimal foraging theory). The same math appears in labor economics (job search theory -- reservation wage = threshold profitability). The structural analogy: a forager deciding which food patches to visit = a RAG system deciding which indices to query = a job seeker deciding which offers to consider.

---

## Seminal Papers

| Paper | Authors | Year | Venue | Contribution |
|-------|---------|------|-------|-------------|
| [RRF](https://dl.acm.org/doi/10.1145/1571941.1572114) | Cormack, Clarke, Buettcher | 2009 | SIGIR | Reciprocal Rank Fusion -- dominant fusion method |
| [Learning to Route](https://arxiv.org/abs/2510.02388) | Bai et al. | 2025 | arXiv | Rule-driven agent for hybrid-source RAG routing |
| [Unsupervised Query Routing](https://arxiv.org/abs/2501.07793) | Mu et al. | 2025 | arXiv | Unsupervised method via upper-bound response evaluation |
| [RAGRouter](https://arxiv.org/abs/2505.23052) | Zhang et al. | 2025 | arXiv | Contrastive learning for RAG-aware routing |
| [MultiRAG](https://arxiv.org/abs/2508.03553) | Wu et al. | 2025 | ICDE | Multi-source hallucination mitigation via line graphs |
| [DeepSieve](https://arxiv.org/abs/2507.22050) | Guo et al. | 2025 | EACL | LLM-as-knowledge-router with recursive sub-question routing |
| [Know When to Fuse](https://aclanthology.org/2025.coling-main.290/) | Louis et al. | 2025 | COLING | Evidence that fusion doesn't always help |
| [Info Foraging](https://doi.org/10.1207/s15516709cog2306_2) | Pirolli & Card | 1999 | Cognitive Science | Diet Model for information source selection |
| [Info Farming](https://arxiv.org/abs/2601.12544) | Azzopardi & Roegiest | 2026 | arXiv | Foraging theory updated for RAG era |

## What to Read Next

1. **Mu et al., "Unsupervised Query Routing for RAG" (arXiv:2501.07793)** -- Most directly applicable to your setup. Shows how to create training data for a router without manual annotation. If Option A (heuristics) proves insufficient, this paper gives you the upgrade path.

2. **Louis et al., "Know When to Fuse" (COLING 2025)** -- Important cautionary evidence that hybrid/multi-source doesn't always win. Read before investing heavily in multi-source fusion.

3. **LlamaIndex Router Retriever documentation** (https://developers.llamaindex.ai/python/framework/integrations/retrievers/router_retriever/) -- Best reference implementation of the composable routing pattern, even if you implement in Java/Spring rather than Python.

## Sources

- (T2) arXiv:2510.02388 -- Learning to Route, Bai et al. 2025 [fetched]
- (T2) arXiv:2501.07793 -- Unsupervised Query Routing, Mu et al. 2025 [fetched]
- (T2) arXiv:2505.23052 -- RAGRouter, Zhang et al. 2025 [fetched]
- (T2) arXiv:2508.03553 -- MultiRAG, Wu et al. 2025 [fetched]
- (T2) arXiv:2507.22050 -- DeepSieve, Guo et al. 2025/2026 [fetched]
- (T2) arXiv:2510.10942 -- Enterprise Hybrid Retrieval, Rao et al. 2025 [fetched]
- (T2) arXiv:2601.12544 -- Information Farming, Azzopardi & Roegiest 2026 [found via search]
- (T1) Cormack, Clarke & Buettcher, "Reciprocal Rank Fusion", SIGIR 2009 [referenced by multiple fetched papers]
- (T1) Louis et al., "Know When to Fuse", COLING 2025 [found via search]
- (T1) Pirolli & Card, "Information Foraging", Cognitive Science 1999 [classic, known]
- (T3) Giri et al., "Dynamic Query Routing with Uncertainty", 2025 [found via search, ResearchGate only]
- (T7) LlamaIndex documentation -- RouterQueryEngine, RouterRetriever [fetched]
- (T7) LangChain documentation -- EnsembleRetriever [found via search]
- (T2) arXiv:2506.15862 -- MoR: Mixture of Retrievers, 2025 [found via search]

## Knowledge Graph Candidates

- "Reciprocal Rank Fusion" -- Type: technique. Possible links: Information Retrieval, pgvector, Score Normalization
- "Query Routing (RAG)" -- Type: technique. Possible links: Retrieval Augmented Generation, Multi-Source Search
- "Information Foraging Theory" -- Type: framework. Possible links: Decision Theory, Optimal Stopping, Bradley-Terry
- "Diet Model (Pirolli)" -- Type: framework. Possible links: Information Foraging Theory, Source Selection, Marginal Analysis
- "DeepSieve" -- Type: technique. Possible links: Query Decomposition, Agentic RAG, Knowledge Router

## Personal Project Connection

**Ranking Todo (Preference Sort)**: The source weighting problem is a preference learning problem. If you track which search results users actually click/use from each source type, you can learn source weights via the same Bradley-Terry model used in preference-sort. This would be an empirical alternative to hand-tuned heuristic weights.
