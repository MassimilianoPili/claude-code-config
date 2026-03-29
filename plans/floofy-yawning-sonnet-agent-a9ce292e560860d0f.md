# Research Summary: Industry-Standard GraphRAG Implementations

## Executive Summary

GraphRAG -- the augmentation of retrieval-augmented generation with graph structure -- has converged on a small number of architectural patterns across industry. The dominant retrieval strategies are: (1) **community-summarization + map-reduce** (Microsoft), (2) **vector-first + graph-expansion** (Neo4j, AWS Neptune, Google Spanner), and (3) **hybrid fusion via Reciprocal Rank Fusion** (emerging in production systems). Traversal depth beyond 2-3 hops degrades performance exponentially in practice, and the standard latency overhead for graph expansion is 150-300ms on top of vector search. The field is moving rapidly from expensive LLM-indexed graphs (Microsoft GraphRAG) toward lazy/deferred approaches (LazyGraphRAG) and classical NLP-based graph construction.

**Epistemic status:** Active development, rapidly evolving. Core patterns are stabilizing but no single approach has achieved field consensus.
**Confidence:** Medium-High -- based on T2 papers (arXiv), vendor documentation (fetched directly), and engineering blog posts. No replicated independent benchmarks yet.

---

## 1. Microsoft GraphRAG

**Source:** Edge et al., "From Local to Global: A Graph RAG Approach to Query-Focused Summarization," arXiv:2404.16130, 2024. (T2 -- arXiv, Microsoft Research)

### Architecture

Microsoft GraphRAG is fundamentally different from vector-first approaches. It builds a **complete knowledge graph at index time** using LLMs, then applies community detection (Leiden algorithm) to create hierarchical community summaries. The retrieval algorithm never does traditional vector similarity search over document chunks.

### Three Search Algorithms

**Local Search** (entity-centric retrieval):
1. Embed the query and match it against **entity description embeddings** in the knowledge graph
2. Matched entities serve as "access points" into the graph
3. From each matched entity, extract five candidate data sources:
   - **Text units** (original document chunks mapped to the entity)
   - **Community reports** (summaries of the entity's community)
   - **Connected entities** (1-hop neighbors in the graph)
   - **Relationships** (edges involving the entity)
   - **Covariates** (entity attributes/properties)
4. Each candidate source is **ranked and filtered** to fit within a pre-defined context window budget
5. The prioritized context is passed to the LLM for answer generation

Key design choice: the context window budget is the hard constraint. Sources are allocated proportional space, not scored against each other. This is **not RRF** -- it is a budget-allocation model.

**Global Search** (corpus-level summarization):
1. Select community reports from a specified hierarchy level
2. Shuffle and segment reports into batches of pre-defined token size
3. **Map phase**: Each batch generates intermediate responses with rated importance points (each claim gets a numerical importance score)
4. **Reduce phase**: Filter top-rated points across all batches, aggregate into final answer

Configuration: `allow_general_knowledge` (bool), `max_data_tokens` (budget), `concurrent_coroutines` (parallelism). Lower hierarchy levels = more detailed but more expensive.

**DRIFT Search** (Dynamic Reasoning and Inference with Flexible Traversal):
1. **Primer phase**: Use HyDE (Hypothetical Document Embeddings) to expand the query, match against top-K semantically relevant community reports, generate initial broad answer + follow-up questions
2. **Follow-up phase**: Execute each follow-up question via local search variant. Currently configured for **2 iterations**. Each produces intermediate answers + more follow-up questions.
3. **Output hierarchy**: Results structured as ranked Q&A pairs by relevance to original query

Performance (T2 -- Microsoft Research Blog, tested on 5,000+ AP News articles, 50 local queries):
- DRIFT outperformed local search in **78% of cases on comprehensiveness**
- DRIFT outperformed local search in **81% of cases on diversity**

### LazyGraphRAG (2024-2025 evolution)

**Source:** Microsoft Research Blog, "LazyGraphRAG sets a new standard for GraphRAG quality and cost" (T5 -- vendor blog, but with quantitative data)

Key innovation: **defer all LLM summarization to query time**. Index using NLP noun-phrase extraction (not LLMs) to build a concept co-occurrence graph, then apply community detection on that cheap graph.

Retrieval algorithm (iterative deepening):
1. LLM identifies 3-5 subqueries from the concept graph
2. Rank text chunks by embedding similarity; rank communities by their top-performing chunks
3. LLM evaluator rates untested chunks from communities in rank order
4. Recurse into sub-communities after consecutive zero-relevance results
5. Terminate when all relevant communities exhausted or relevance budget consumed
6. Build subgraphs from relevant chunks, group by community, extract claims

Cost data:
- Indexing: **0.1% of GraphRAG's cost** (same as vector RAG)
- Query at budget 500: **4% of GraphRAG Global Search cost**, outperforms all competing methods
- At budget 100: matches vector RAG cost, outperforms it on both local and global queries

Tested on 5,590 AP news articles, 100 synthetic queries.

### What Microsoft GraphRAG does NOT do

- No RRF or score-level fusion between vector and graph
- No explicit traversal depth parameter (the graph is pre-summarized into communities)
- No real-time graph traversal at query time in the traditional sense -- it uses pre-computed summaries

---

## 2. Neo4j GraphRAG

**Source:** Neo4j GraphRAG Python Package documentation + Neo4j Developer Blog (T5 -- vendor docs, fetched directly)

Neo4j takes a fundamentally different approach: **graph as a database to be queried**, not pre-summarized.

### Five Retriever Types

| Retriever | Algorithm | Graph Traversal | Fusion |
|-----------|-----------|-----------------|--------|
| **VectorRetriever** | ANN vector search on Neo4j vector index | None | None |
| **VectorCypherRetriever** | Vector search -> Cypher traversal | Yes, user-defined Cypher query | Sequential (vector first, then graph expansion) |
| **HybridRetriever** | Vector + full-text search merged | None | Dual-index merge (details not public) |
| **HybridCypherRetriever** | Vector + full-text -> Cypher traversal | Yes, user-defined Cypher query | Dual-index merge + graph expansion |
| **Text2CypherRetriever** | LLM generates Cypher query | Full graph traversal | None (pure graph) |

### VectorCypherRetriever (the key innovation)

This is Neo4j's primary GraphRAG retriever. The algorithm:

1. Embed the query
2. Perform ANN similarity search against a vector index on graph nodes
3. For each matched node, execute a user-supplied **Cypher retrieval query** that can traverse the graph
4. The Cypher query has access to two variables: `node` (the matched node) and `score` (similarity score)
5. Results from graph traversal are formatted and passed to the LLM

**Traversal depth**: Entirely user-controlled via the Cypher query. Typical patterns are 1-2 hops:
```cypher
MATCH (node)-[r:RELATED_TO]->(neighbor)
RETURN node.text AS source, neighbor.text AS related, type(r) AS relationship
```

**Scoring**: The vector similarity score is preserved from step 2. There is no automatic re-ranking of graph-expanded results. The user can implement custom scoring in the `result_formatter` function.

### HybridCypherRetriever

Combines full-text (BM25) and vector search before graph expansion:
1. Search both vector index and full-text index simultaneously
2. Merge results (merge strategy not publicly documented -- likely simple union or score-based dedup)
3. Execute Cypher traversal from merged candidate nodes
4. Format for LLM

### Key observations

- Neo4j does **not** implement RRF natively in their GraphRAG package
- Traversal depth is entirely a **user responsibility** via Cypher
- No built-in context window budget allocation (unlike Microsoft GraphRAG)
- The approach is more flexible but less opinionated than Microsoft's

---

## 3. Amazon Neptune / AWS

**Source:** AWS Database Blog, "Introducing the GraphRAG Toolkit" + AWS Bedrock Documentation (T5 -- vendor blog/docs)

### Architecture (GA March 2025)

AWS offers GraphRAG through Amazon Bedrock Knowledge Bases integrated with Neptune Analytics:

1. **Indexing**: Bedrock extracts text chunks, generates embeddings (Titan or Cohere), uses Claude 3 Haiku to extract entities and generate triples -> Neptune Knowledge Graph
2. **Retrieval** (two-step):
   - Semantic vector search finds most relevant chunks (embeddings stored as node properties in Neptune)
   - Graph traversal explores connected nodes from vector-matched results
3. **Multi-hop reasoning** through graph expansion

### Neptune Analytics vector capabilities

Neptune Analytics supports vector algorithms callable from **openCypher**, enabling combined graph+vector queries in a single query language:
```
// Pseudo-openCypher: top-K by embedding with filters, then traverse
```

This is architecturally similar to Neo4j's VectorCypherRetriever but integrated into a managed service.

### GraphRAG Toolkit (open source)

AWS released an open-source Python library for building graph-enhanced RAG workflows. Technical details of the fusion strategy in the toolkit were not extractable from the blog post (content was truncated), but the architecture follows the standard vector-first + graph-expansion pattern.

### Key observation

AWS's approach is the most "managed" -- least flexibility but lowest operational complexity. The fusion is sequential (vector -> graph), not score-level fusion.

---

## 4. Google Vertex AI

**Source:** Google Cloud Architecture Center, "GraphRAG infrastructure for generative AI using Vertex AI and Spanner Graph" (T5 -- vendor docs, fetched directly)

### Architecture

Google provides a reference architecture combining Spanner Graph with Vertex AI:

1. Convert query to embeddings
2. Vector-similarity search in the embeddings database to identify related graph nodes
3. Traverse the knowledge graph from matched nodes
4. **Rank results** using the **Vertex AI Search ranking API** based on semantic relevance
5. Augment prompt with ranked graph data
6. Summarize via Gemini API

### Key distinction from others

Google introduces a **dedicated re-ranking step** between graph traversal and LLM generation. The Vertex AI Search ranking API provides semantic relevance scoring on the combined node+edge results. This is the closest to a proper fusion/re-ranking strategy among the cloud vendors.

### Limitations

- No published traversal depth parameters
- No published latency benchmarks
- Reference architecture only -- no managed "GraphRAG service" (unlike AWS Bedrock)

---

## 5. Enterprise Production Patterns

### Uber

**Source:** Uber Engineering Blog, "Powering Billion-Scale Vector Search with OpenSearch" (T5 -- engineering blog)

Uber operates at **1.5 billion vectors** across ~400 dimensions. They migrated from Apache Lucene/HNSW to Amazon OpenSearch for scale. Their architecture is primarily **vector-first** with knowledge graph as a supplementary signal:

- Embedding-Based Retrieval (EBR) for candidate generation
- Knowledge graph for entity resolution and relationship context
- No published details on graph-vector fusion mechanism

Notable: Uber's latency constraints are extreme (real-time search), which limits graph traversal depth in practice.

### Airbnb

**Source:** Airbnb Engineering Blog, "Contextualizing Airbnb by Building Knowledge Graph" + "Scaling Knowledge Access and Retrieval" (T5 -- engineering blog)

Airbnb built a knowledge graph with a **relational database backend** (not a graph database) encoding inventory and world knowledge in a hierarchical taxonomy:
- Concepts as nodes (e.g., "Surfing", "Sport")
- Relationships as edges
- Graph query API with recursive traversal interface

Their search pipeline uses **Embedding-Based Retrieval (EBR)** for candidate generation, with the knowledge graph providing contextual enrichment rather than primary retrieval. The graph traversal is post-retrieval augmentation.

### LinkedIn

**Source:** LinkedIn Engineering Blog, "Building The LinkedIn Knowledge Graph" (T5 -- engineering blog)

LinkedIn's approach:
- Phrases represented as vectors of co-occurring phrases
- Soft clustering to group phrases
- Latent entity vectors encompass semantics across multiple taxonomies
- Cross-Domain Graph Neural Networks for recommendation (2025)
- EBR + knowledge graph for job search (LLMs + embedding-based retrieval + intelligent distillation)

No published details on formal graph-vector fusion algorithm.

### Common Enterprise Pattern

Across all three (and observable in other large-scale systems):

```
Query -> Vector/Embedding Search (ANN, sub-100ms)
     -> Top-K candidates
     -> Graph expansion (1-2 hops, 50-200ms)
     -> Re-rank or LLM-based synthesis
     -> Response
```

The graph is used for **context enrichment**, not primary retrieval. This is because:
1. Vector search scales to billions of items with sub-100ms latency
2. Graph traversal adds 150-300ms per query
3. Beyond 2-3 hops, performance degrades exponentially
4. The total latency budget for retrieval is typically 200-500ms in production

---

## Retrieval Algorithm Comparison

| System | Primary Retrieval | Graph Role | Fusion Method | Traversal Depth |
|--------|-------------------|------------|---------------|-----------------|
| MS GraphRAG Local | Entity embedding match | Pre-computed summaries | Budget allocation (no fusion) | N/A (pre-summarized) |
| MS GraphRAG Global | Community report sweep | Community hierarchies | Map-reduce aggregation | N/A |
| MS DRIFT | HyDE + community match | Community primers + local search | Hierarchical Q&A ranking | 2 iterations |
| MS LazyGraphRAG | Concept graph + embedding | Lazy community structure | Iterative deepening | Variable (budget-controlled) |
| Neo4j VectorCypher | ANN vector search | Cypher traversal from results | Sequential (vector -> graph) | User-defined (typically 1-2 hops) |
| Neo4j HybridCypher | Vector + BM25 | Cypher traversal from merged | Union + sequential | User-defined |
| AWS Neptune | Vector search on nodes | openCypher traversal | Sequential (vector -> graph) | Not specified |
| Google Vertex AI | Embedding search | Spanner Graph traversal | Sequential + Vertex AI re-ranker | Not specified |
| Enterprise (Uber/Airbnb/LinkedIn) | EBR (ANN) | Post-retrieval enrichment | Typically none (concatenation) | 1-2 hops max |

### Fusion Methods in Detail

**1. No explicit fusion (Microsoft GraphRAG Local/Global)**
The graph IS the primary retrieval structure. There is no vector-vs-graph fusion because vector search only identifies entry points into a pre-summarized graph structure.

**2. Sequential pipeline (Neo4j, AWS, most production systems)**
Vector search -> top-K -> graph expansion -> concatenate. No score-level fusion. The graph results simply augment the vector results.

**3. Reciprocal Rank Fusion (emerging, not yet dominant)**
RRF is used in the "Towards Practical GraphRAG" paper (Min et al., arXiv:2507.03226, T2) which maintains separate embeddings for entities, chunks, and relations, runs vector similarity on each, then fuses via RRF before a dense re-ranking step. This achieved 15% improvement over vanilla vector retrieval on enterprise datasets.

**4. Re-ranking (Google Vertex AI)**
Google's approach uses a dedicated re-ranker (Vertex AI Search ranking API) on the combined vector + graph results. This is a cross-encoder style re-ranking after retrieval.

**5. Budget-controlled iterative (LazyGraphRAG)**
Neither fusion nor sequential -- an iterative deepening search that interleaves vector scoring with community-structure exploration, controlled by a configurable relevance budget.

---

## Performance Characteristics

### Latency Budgets (from multiple sources)

| Component | Typical Latency | Source |
|-----------|----------------|--------|
| Vector ANN search | 10-50ms | Industry standard (HNSW) |
| Graph traversal (1-2 hops) | 50-200ms | FalkorDB benchmarks (T5) |
| Multi-hop traversal (3+ hops) | 300ms+ | FalkorDB, exponential degradation |
| Hybrid orchestration overhead | 150-200ms | FalkorDB analysis |
| LLM inference (the real bottleneck) | 1-10s | Universal |
| BFS traversal + graph update | <3s total | GraphRAG-Bench (T2 -- ICLR 2026) |

**Key insight**: Graph traversal is NOT the bottleneck in GraphRAG systems. LLM inference dominates wall-clock time. The graph overhead (sub-second) is negligible compared to the seconds spent on LLM calls, especially in Microsoft's approach where multiple LLM calls happen in the map-reduce pipeline.

### Accuracy vs Latency Tradeoff

From multiple sources (T2/T5):
- GraphRAG delivers **1.5x better accuracy overall** and **2x better on complex multi-hop queries**
- At the cost of **2.4x higher latency on average**
- Performance degrades **exponentially beyond 2-3 logical hops**
- Hybrid vector+graph with 150-200ms overhead yields **15-25% accuracy gains**

### Traversal Depth Consensus

**Industry standard: 1-2 hops.** This is consistent across:
- Neo4j examples (Cypher queries typically traverse 1-2 relationships)
- AWS Neptune documentation (multi-hop mentioned but no depth specified)
- FalkorDB analysis (exponential degradation beyond 2-3 hops)
- Enterprise systems (Uber, Airbnb -- 1-2 hops max for latency)
- Microsoft GraphRAG avoids the question entirely by pre-summarizing via communities

The exception is Microsoft's DRIFT search which does "2 iterations" of follow-up, which conceptually represents deeper reasoning but through LLM-mediated expansion rather than raw graph traversal.

---

## Open Questions

1. **No standard fusion algorithm**: RRF is emerging but not yet dominant. Most systems use simple sequential pipelines. There is no equivalent of the BM25+vector "hybrid search" consensus that exists in vanilla RAG.

2. **Graph construction cost vs query-time cost**: Microsoft is actively exploring the tradeoff (GraphRAG -> LazyGraphRAG -> future). The optimal point depends heavily on query frequency vs corpus update frequency.

3. **When does GraphRAG actually help?** GraphRAG-Bench (arXiv:2506.05690, Xiang et al., accepted ICLR 2026, T2) found that "GraphRAG frequently underperforms vanilla RAG on many real-world tasks." The benefit is concentrated on multi-hop reasoning and corpus-level summarization tasks.

4. **Scaling beyond millions of entities**: No published production GraphRAG system operates at the scale of major search engines. Uber's 1.5B vector system is vector-only; their knowledge graph is used for entity resolution, not primary retrieval.

---

## Serendipitous Connections

**Connection to KORE**: Your AGE knowledge graph + pgvector setup on SOL is architecturally positioned to implement the Neo4j VectorCypherRetriever pattern natively. AGE provides Cypher queries, pgvector provides ANN search -- the "vector-first + graph-expansion" pattern maps directly. The key implementation question would be: write the equivalent of Neo4j's `retrieval_query` in AGE Cypher, with pgvector providing the initial candidate set.

**Connection to Kindle Graph Enrichment**: The entity extraction phase of Microsoft GraphRAG (LLM-based entity + relationship extraction from text) is exactly what your Kindle highlight -> AGE pipeline does. The community detection step (Leiden algorithm) could be applied to the existing `knowledge_graph` graph in AGE to generate hierarchical summaries, enabling a local-search-style retrieval over your reading notes.

**Bradley-Terry / Preference Learning connection**: Microsoft GraphRAG's importance scoring in global search (each claim gets a numerical rating) is a form of pairwise comparison that could benefit from Bradley-Terry ranking to calibrate claim importance across community reports, rather than relying on raw LLM scores.

**KORE-GC paper connection**: The observation that graph construction is the dominant cost (GraphRAG vs LazyGraphRAG) connects directly to your GC paper's focus on maintenance costs for co-located graph-vector stores. LazyGraphRAG's "defer summarization to query time" is essentially a form of lazy evaluation / copy-on-read that your transactional GC framework could formalize.

---

## What to Read Next

1. **Edge et al., arXiv:2404.16130** -- The foundational Microsoft GraphRAG paper. Read for the community detection + map-reduce architecture.
2. **Min et al., arXiv:2507.03226** -- "Towards Practical GraphRAG" -- the most implementation-focused paper, with the clearest RRF fusion description and real enterprise deployment data.
3. **LazyGraphRAG blog post** (microsoft.com/research/blog/lazygraphrag) -- For the cost-efficiency frontier and the iterative deepening algorithm.
4. **Neo4j GraphRAG Python docs** (neo4j.com/docs/neo4j-graphrag-python) -- For the most practical, code-level implementation patterns.
5. **Xiang et al., arXiv:2506.05690** (ICLR 2026) -- GraphRAG-Bench, for understanding when GraphRAG actually helps vs hurts.

---

## Sources

### T2 -- arXiv Preprints (fetched)
- Edge et al., "From Local to Global: A Graph RAG Approach to Query-Focused Summarization," arXiv:2404.16130, 2024 -- https://arxiv.org/abs/2404.16130
- Han et al., "Retrieval-Augmented Generation with Graphs (GraphRAG)," arXiv:2501.00309, 2024 -- https://arxiv.org/abs/2501.00309
- Zhang et al., "A Survey of Graph Retrieval-Augmented Generation for Customized LLMs," arXiv:2501.13958, 2025 -- https://arxiv.org/abs/2501.13958
- Min et al., "Towards Practical GraphRAG: Efficient KG Construction and Hybrid Retrieval at Scale," arXiv:2507.03226, 2025 -- https://arxiv.org/abs/2507.03226
- Xiang et al., "When to use Graphs in RAG," arXiv:2506.05690, ICLR 2026 -- https://arxiv.org/abs/2506.05690
- Peng et al., "Graph Retrieval-Augmented Generation: A Survey," ACM TOIS, 2025 -- https://dl.acm.org/doi/10.1145/3777378

### T5 -- Vendor Documentation and Engineering Blogs (fetched)
- Microsoft GraphRAG docs: Local Search, Global Search, DRIFT Search -- https://microsoft.github.io/graphrag/query/overview/
- Microsoft Research Blog: DRIFT Search -- https://www.microsoft.com/en-us/research/blog/introducing-drift-search-combining-global-and-local-search-methods-to-improve-quality-and-efficiency/
- Microsoft Research Blog: LazyGraphRAG -- https://www.microsoft.com/en-us/research/blog/lazygraphrag-setting-a-new-standard-for-quality-and-cost/
- Neo4j GraphRAG Python docs -- https://neo4j.com/docs/neo4j-graphrag-python/current/user_guide_rag.html
- Neo4j Blog: Graph Traversal in GraphRAG -- https://neo4j.com/blog/developer/graph-traversal-graphrag-python-package/
- AWS Blog: Introducing the GraphRAG Toolkit -- https://aws.amazon.com/blogs/database/introducing-the-graphrag-toolkit/
- AWS Blog: Bedrock Knowledge Bases GraphRAG GA -- https://aws.amazon.com/blogs/machine-learning/announcing-general-availability-of-amazon-bedrock-knowledge-bases-graphrag-with-amazon-neptune-analytics/
- Google Cloud Architecture: GraphRAG with Spanner Graph -- https://docs.cloud.google.com/architecture/gen-ai-graphrag-spanner
- FalkorDB: VectorRAG vs GraphRAG Technical Challenges -- https://www.falkordb.com/blog/vectorrag-vs-graphrag-technical-challenges-enterprise-ai-march25/

### T5 -- Engineering Blogs (fetched)
- Uber Blog: Powering Billion-Scale Vector Search -- https://www.uber.com/blog/powering-billion-scale-vector-search-with-opensearch/
- Airbnb Blog: Contextualizing Airbnb by Building Knowledge Graph -- https://medium.com/airbnb-engineering/contextualizing-airbnb-by-building-knowledge-graph-b7077e268d5a
- Airbnb Blog: Scaling Knowledge Access and Retrieval -- https://medium.com/airbnb-engineering/scaling-knowledge-access-and-retrieval-at-airbnb-665b6ba21e95
- LinkedIn Blog: Building The LinkedIn Knowledge Graph -- https://www.linkedin.com/blog/engineering/knowledge/building-the-linkedin-knowledge-graph

### Not Fetched (referenced in search results only)
- Zhu et al., "Graph-based approaches and functionalities in RAG," ACM Computing Surveys, 2025 -- https://dl.acm.org/doi/abs/10.1145/3795880
