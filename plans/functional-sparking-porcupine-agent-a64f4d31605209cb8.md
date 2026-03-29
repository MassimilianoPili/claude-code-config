# Research Summary: Semantic Caching for LLM/RAG Systems (2023--2026)

## Executive Summary

Semantic caching for LLM systems is a rapidly maturing technique that stores query-response pairs indexed by embedding vectors, returning cached responses when a new query's cosine similarity to a cached query exceeds a threshold. The literature (8 papers, 2024--2026) converges on several findings: cache hit rates of 60--92% are achievable with well-tuned thresholds, API cost reductions of 68--73% are reported, and latency drops by ~34%. However, **no single universal similarity threshold exists** — the optimal value is domain-dependent, embedding-model-dependent, and must be calibrated empirically. The field's most important recent theoretical result is that optimal offline semantic cache replacement is **NP-hard** (Biton & Friedman, Feb 2026), which means all practical eviction policies are necessarily heuristic. Cache invalidation for RAG specifically remains the **least-studied** aspect — nearly all papers focus on caching direct LLM responses, not RAG pipelines where the underlying corpus changes.

**Epistemic status:** Active research front, rapidly evolving. No peer-reviewed journal publications yet — all evidence is from arXiv preprints (T2) and conference workshops (NLP-OSS 2023 for GPTCache).
**Confidence:** Medium — consistent directional findings across multiple independent groups, but no replication studies, no standardized benchmarks, and effect sizes vary substantially by dataset.

---

## 1. Similarity Threshold: What Value Works?

### The Short Answer

There is **no validated universal threshold**. The literature uses values ranging from 0.85 to 0.95+ cosine similarity, depending on domain, embedding model, and acceptable false-positive rate.

### Evidence

1. **GPT Semantic Cache** (T2 — Regmi & Pun, arXiv:2411.05276, Nov 2024): Achieves >97% "positive hit accuracy" (precision among cache hits) with cache hit rates of 61.6--68.8%. The exact threshold is not stated in the abstract, but the high precision suggests a relatively strict threshold was used.

2. **Ensemble Embedding Approach** (T2 — Ghaffari et al., arXiv:2507.07061, Jul 2025): Reports 92% cache hit ratio for semantically equivalent queries and 85% accuracy rejecting non-equivalent queries. Uses the Quora Question Pairs (QQP) dataset. Key insight: **combining multiple embedding models** improves discrimination at any given threshold, effectively making the threshold choice less fragile.

3. **Domain-Specific Embeddings for Caching** (T2 — Gill et al., Redis + Virginia Tech, arXiv:2504.02268, Apr 2025): Fine-tuned compact embedding models outperform general-purpose SOTA models (both open-source and proprietary) in precision/recall **specifically for the caching use case**. This implies that threshold calibration is inseparable from embedding model choice — a threshold that works for `text-embedding-3-large` will not work for `mxbai-embed-large`.

4. **Practitioner sources** (T7 — Dataquest tutorial, LangChain docs): Dataquest uses cosine similarity 0.90. LangChain's `RedisSemanticCache` uses **cosine distance** (not similarity), with examples showing `distance_threshold=0.01` — which corresponds to cosine similarity ~0.99, extremely strict.

### Threshold Calibration Strategy for Your Stack

For `mxbai-embed-large` (1024 dim), no published calibration data exists. Recommended approach:

1. **Build a calibration set**: Take 50--100 real queries from your system. For each, write 2--3 paraphrases (should hit cache) and 2--3 related-but-different queries (should NOT hit cache).
2. **Compute pairwise cosine similarities** within paraphrase groups and across groups.
3. **Plot the distribution**: You will see two overlapping distributions. The threshold should sit in the gap.
4. **Start conservative** (0.92--0.95) and relax downward based on observed false positives.

The ensemble approach from Ghaffari et al. is worth considering even for a single-user system: run two embedding models (e.g., `mxbai-embed-large` + a smaller model like `all-MiniLM-L6-v2`) and require both to agree. This reduces false positives substantially.

### Key Caveat

Cosine similarity in high-dimensional spaces (1024 dim) behaves differently from intuition built on 2D/3D geometry. Vectors tend to be more uniformly distributed, so the "interesting" range of cosine similarity is compressed. For 1024-dim embeddings, the difference between 0.90 and 0.95 is often more meaningful than it appears.

---

## 2. Cache Invalidation for RAG Systems

### The Gap in the Literature

This is the **least-covered** aspect across all papers surveyed. Nearly all semantic caching papers assume a stateless LLM (no retrieval) — the cache maps query embeddings to LLM responses directly. In a RAG system, the response depends on **both** the query and the retrieved context. When the corpus changes (new documents, updated embeddings), cached responses may become stale even for identical queries.

### What Exists

1. **Krites** (T2 — Singh et al., arXiv:2602.13165, Feb 2026) introduces a **tiered cache architecture** (static + dynamic) with async LLM-judge verification for borderline hits. The static tier contains curated, high-confidence answers — conceptually similar to a "golden" cache that would survive corpus updates. The dynamic tier is populated online and is more volatile. This tiered pattern is the closest thing in the literature to a corpus-aware invalidation strategy.

2. **Generative Caching** (T2 — Chakraborty et al., arXiv:2511.17565, Nov 2025) handles "structurally similar prompts with variation-aware responses" — the cache can generate adapted responses rather than returning exact cached responses. This partially addresses staleness: if the variation is in the retrieved context rather than the query, the cache could adapt.

3. **No paper directly addresses**: "when document X is updated in the corpus, which cache entries depend on X and should be invalidated?"

### Recommended Invalidation Patterns for Your System

Since no academic consensus exists, these are engineering recommendations drawn from practitioner patterns (T7):

**Pattern A — TTL-based (simplest)**
- Set a `max_age` on each cache entry (e.g., 24h for a single-user system).
- Pro: Simple, no corpus tracking needed. Con: Stale data for up to `max_age`; unnecessary cache misses for stable corpus regions.

**Pattern B — Corpus-version tagging**
- Each cache entry stores a `corpus_version` (monotonically increasing counter or timestamp of last embedding sync).
- On cache hit, compare `entry.corpus_version` with `current_corpus_version`.
- If outdated, treat as a miss but keep the entry for potential stale-while-revalidate.
- Pro: Precise. Con: Coarse — a single new document invalidates everything.

**Pattern C — Document-fingerprint tracking (most precise)**
- For each cached response, store the set of document IDs that were retrieved as context.
- Maintain a `modified_documents` set (populated by your embedding sync pipeline).
- On cache hit, check if `entry.context_doc_ids ∩ modified_documents ≠ ∅`.
- If yes: invalidate (or stale-while-revalidate). If no: serve from cache.
- Pro: Minimal unnecessary invalidation. Con: Storage overhead, requires tracking retrieval provenance.

**Pattern D — Stale-while-revalidate (hybrid)**
- Serve the cached response immediately (fast path).
- Asynchronously re-run the RAG pipeline.
- If the new response differs substantially from the cached one (e.g., cosine similarity of response embeddings < 0.85), update the cache and optionally notify the user.
- Pro: Always fast, eventually consistent. Con: User may see stale data; complexity.

**For your single-user system**: Pattern B is the best starting point. Your embedding sync already runs on a timer (`ScheduledReindex` at 04:00). Increment a `corpus_version` counter after each successful reindex. Cache entries older than the current version get a miss on lookup. Simple, effective, low overhead.

---

## 3. Existing Implementations

### GPTCache (Zilliz) — The Reference Implementation

(T2 — Bang et al., NLP-OSS 2023 Workshop, 155+ citations)

**Architecture**: Modular pipeline with 5 pluggable components:
1. **Pre-processor**: Normalizes the query (lowercasing, stop word removal, etc.)
2. **Embedding generator**: Converts query to vector (supports OpenAI, Hugging Face, ONNX, etc.)
3. **Vector store**: Stores embeddings for similarity search (supports FAISS, Milvus, ChromaDB, Qdrant, pgvector)
4. **Similarity evaluator**: Decides cache hit/miss (cosine similarity with configurable threshold)
5. **Cache storage**: Stores the actual responses (supports SQLite, MySQL, PostgreSQL, Redis, etc.)

**Eviction**: Supports LRU, LFU, FIFO.

**Key design insight**: The vector store and the response cache are **separate**. The vector store handles similarity search; the response cache handles storage. This means you can use pgvector for similarity search and Redis for response storage.

- GitHub: `https://github.com/zilliztech/GPTCache`
- License: MIT
- Status: Active maintenance (as of 2025).

### LangChain RedisSemanticCache

(T7 — LangChain documentation + RedisVL library)

- Uses `RedisVL` library under the hood.
- Stores embeddings + responses in Redis using Redis Vector Similarity Search (VSS).
- Parameter: `distance_threshold` — in **cosine distance** units (range [0, 2]), NOT cosine similarity. Lower = stricter. `distance_threshold=0.1` corresponds to cosine similarity ~0.95.
- Supports FLAT and HNSW index types.
- Simple API: drop-in replacement for LangChain's LLM cache.

### Redis LangCache

(T7 — Redis product announcement)

- Dedicated semantic caching product from Redis.
- Built on RedisVL's `SemanticCache` class.
- Supports cosine, L2, and inner product distance metrics.
- Includes TTL support natively.

### Architecture Decision for Your Stack

You already have **pgvector** and **Redis**. Two viable architectures:

**Option 1: pgvector-only**
- Store query embeddings + responses in a new PostgreSQL table.
- Use `pgvector` cosine similarity operator (`<=>`) for cache lookup.
- Pro: Single data store, transactional consistency, easy to add document-fingerprint tracking (Pattern C).
- Con: Slightly slower than Redis for pure KV lookups (~1--5ms vs ~0.1ms), but for a single-user system this is negligible.

```sql
CREATE TABLE semantic_cache (
    id SERIAL PRIMARY KEY,
    query_text TEXT NOT NULL,
    query_embedding vector(1024),
    response_text TEXT NOT NULL,
    corpus_version INTEGER NOT NULL,
    context_doc_ids INTEGER[],  -- for Pattern C invalidation
    created_at TIMESTAMPTZ DEFAULT NOW(),
    hit_count INTEGER DEFAULT 0,
    last_hit_at TIMESTAMPTZ
);

CREATE INDEX ON semantic_cache
    USING ivfflat (query_embedding vector_cosine_ops) WITH (lists = 10);
```

Cache lookup:
```sql
SELECT id, query_text, response_text, corpus_version,
       1 - (query_embedding <=> $1::vector) AS similarity
FROM semantic_cache
WHERE corpus_version >= $2  -- invalidation check
  AND 1 - (query_embedding <=> $1::vector) > $3  -- threshold
ORDER BY query_embedding <=> $1::vector
LIMIT 1;
```

**Option 2: Redis VSS + PostgreSQL metadata**
- Store embeddings in Redis using HNSW index (faster approximate search).
- Store response text + metadata in PostgreSQL.
- Pro: Faster vector search at scale. Con: Two data stores to maintain, eventual consistency risk.

**Recommendation for your system**: Option 1 (pgvector-only). At ~3800 embeddings and single-user load, pgvector with an IVFFlat index will return results in <5ms. The simplicity of a single data store outweighs the marginal latency benefit of Redis VSS. Use Redis only if you later need sub-millisecond lookups or your cache grows past ~100K entries.

---

## 4. Eviction Strategies

### Standard Approaches

**LRU (Least Recently Used)**: Evict the entry that was accessed longest ago. The default in most implementations (GPTCache, Redis). Simple, O(1) with a doubly-linked list + hash map.

**LFU (Least Frequently Used)**: Evict the entry with the fewest accesses. Better for workloads with stable popularity distributions. GPTCache supports this.

**FIFO (First In, First Out)**: Evict the oldest entry. The simplest policy. GPTCache supports this.

### Semantic-Aware Eviction (The Research Frontier)

1. **RAC: Relation-Aware Cache Replacement** (T2 — Wu et al., arXiv:2602.21547, Feb 2026)
   The most sophisticated eviction policy in the literature. Uses two signals:
   - **Topical Prevalence**: Aggregates access evidence at the *topic* level (not individual query level) to capture long-horizon reuse patterns. Topics are clusters of semantically related queries.
   - **Structural Importance**: Within a topic cluster, uses the dependency structure between entries to predict which entries are most likely to be reused.
   - **Result**: Surpasses LRU and LFU by **20--30% in cache hit ratio** across diverse workloads.
   - **Key insight**: LLM workloads have "long reuse distances and sparse local recurrence" — a query may not recur for a long time, but related queries (same topic) do. Standard LRU/LFU miss this.

2. **From Exact Hits to Close Enough** (T2 — Biton & Friedman, arXiv:2603.03301, Feb 2026)
   - **Theoretical result**: Optimal offline semantic cache replacement is **NP-hard**. This means no polynomial-time algorithm can compute the optimal eviction decision. All practical policies are heuristics.
   - **Practical contribution**: Proposes polynomial-time online heuristics combining recency, frequency, and **semantic locality** (entries near many other entries in embedding space are more valuable because they can serve as cache hits for a wider range of queries).
   - **Finding**: Frequency-based policies are strong baselines, but their novel locality-aware variant improves semantic accuracy.
   - **Open source code available**.

3. **Cluster-based LFU** (practitioner pattern, T7):
   - Cluster cached queries by topic (e.g., k-means on embeddings).
   - Apply LFU within each cluster independently.
   - Ensures topical diversity in the cache — prevents a single hot topic from crowding out all other topics.

### Recommendation for Your System

For a single-user system with ~3800 embeddings, cache eviction is unlikely to be a bottleneck. A cache of 500--1000 entries with simple **LRU + TTL** (Pattern B from Section 2) will suffice initially. If you observe that useful entries are being evicted too aggressively:

1. Switch to **LFU** — single-user workloads often have stable topic preferences.
2. Consider the **semantic locality** heuristic from Biton & Friedman: when evicting, prefer entries that are close to other cached entries (redundant coverage) over entries that are isolated in embedding space (unique coverage).

The RAC approach (Wu et al.) is designed for multi-tenant, high-throughput systems and would be over-engineered for your use case.

---

## 5. Practical Results: Concrete Numbers

| Metric | Value | Source | Notes |
|--------|-------|--------|-------|
| **API call reduction** | 68.8% | (T2 — Regmi & Pun, arXiv:2411.05276) | GPT Semantic Cache |
| **Cost reduction** | ~73% | (T7 — VentureBeat report) | Industry aggregate |
| **Cache hit rate** | 61.6--68.8% | (T2 — Regmi & Pun, arXiv:2411.05276) | Varies by threshold strictness |
| **Cache hit rate** | 83% | (T2 — Chakraborty et al., arXiv:2511.17565) | Generative caching approach |
| **Cache hit rate** | 92% | (T2 — Ghaffari et al., arXiv:2507.07061) | Ensemble embeddings, QQP dataset |
| **Positive hit accuracy** | >97% | (T2 — Regmi & Pun, arXiv:2411.05276) | Precision among cache hits |
| **Non-equivalent rejection** | 85% | (T2 — Ghaffari et al., arXiv:2507.07061) | True negative rate |
| **Latency reduction** | ~34% | (T2 — Chakraborty et al., arXiv:2511.17565) | End-to-end response time |
| **Static cache coverage** | 3.9x increase | (T2 — Singh et al., arXiv:2602.13165) | Curated answers via Krites |
| **Hit ratio improvement** | 20--30% over LRU/LFU | (T2 — Wu et al., arXiv:2602.21547) | RAC semantic eviction |

### What These Numbers Mean for Your System

Your system is **single-user** with a **personal knowledge base**. This has two implications:

1. **Higher cache hit rates are likely**: A single user tends to revisit the same topics repeatedly, unlike a multi-user system with diverse queries. You should expect hit rates at the higher end of the reported ranges (70--90%) once the cache warms up.

2. **Latency savings are amplified**: Your RAG pipeline includes embedding generation via Ollama (CPU inference with `mxbai-embed-large`) + pgvector search + LLM API call. The embedding step alone takes 50--200ms on CPU. A cache hit skips all three steps, returning in <5ms from pgvector or <1ms from Redis.

**Expected savings for your setup:**
- Cache hit latency: ~5ms (pgvector lookup)
- Cache miss latency: ~200ms (embedding) + ~20ms (pgvector RAG search) + ~2000--5000ms (LLM API call) = ~2.2--5.2s
- At 70% cache hit rate: average latency drops from ~3.5s to ~1.1s (roughly 3x improvement)
- API cost: reduced by ~70% (proportional to cache hit rate)

---

## Seminal Papers

| Paper | Authors | Year | arXiv | Key Contribution |
|-------|---------|------|-------|-----------------|
| GPTCache: An Open-Source Semantic Cache for LLM Applications | Bang et al. (Zilliz) | 2023 | NLP-OSS Workshop | Reference architecture, 155+ citations |
| GPT Semantic Cache | Regmi & Pun | 2024 | [2411.05276](https://arxiv.org/abs/2411.05276) | First rigorous evaluation: 68.8% API reduction, >97% precision |
| Domain-Specific Embeddings for Caching | Gill et al. (Redis + VT) | 2025 | [2504.02268](https://arxiv.org/abs/2504.02268) | Fine-tuned embeddings beat general-purpose for caching |
| Ensemble Embedding Approach | Ghaffari et al. | 2025 | [2507.07061](https://arxiv.org/abs/2507.07061) | Multi-model ensemble: 92% hit, 85% rejection |
| Generative Caching | Chakraborty et al. | 2025 | [2511.17565](https://arxiv.org/abs/2511.17565) | Variation-aware cached response adaptation, 83% hit, 34% latency drop |
| vCache: Verified Semantic Prompt Caching | (multiple authors) | 2025 | [2502.03771](https://arxiv.org/abs/2502.03771) | Adaptive threshold approach |
| Krites: Async Verified Semantic Caching | Singh et al. | 2026 | [2602.13165](https://arxiv.org/abs/2602.13165) | Tiered static/dynamic cache, LLM-judge verification, 3.9x coverage |
| RAC: Relation-Aware Cache Replacement | Wu et al. | 2026 | [2602.21547](https://arxiv.org/abs/2602.21547) | Semantic eviction: topical prevalence + structural importance, +20--30% hit ratio |
| From Exact Hits to Close Enough | Biton & Friedman | 2026 | [2603.03301](https://arxiv.org/abs/2603.03301) | NP-hardness of optimal policy, locality-aware heuristics, open source |

Also noted: **Security vulnerabilities** in semantic proximity caching (T1 — Nature Scientific Reports, Feb 2026, `nature.com/articles/s41598-026-36721-w`) — adversarial queries can extract cached responses from other users. Relevant for multi-tenant systems, not for your single-user setup.

---

## Open Questions

1. **Threshold calibration methodology**: No paper provides a principled, model-agnostic method for choosing the similarity threshold. Current practice is grid search or manual tuning. An information-theoretic approach (e.g., maximizing mutual information between cache decisions and query equivalence) would be valuable.

2. **RAG-specific cache invalidation**: No academic work addresses the problem of invalidating cached RAG responses when the underlying corpus changes. This is a significant gap given the prevalence of RAG systems.

3. **Embedding model sensitivity**: The threshold that works for one embedding model does not transfer to another (Gill et al., 2025). No systematic comparison across embedding models for the caching use case exists.

4. **Long-term cache drift**: In a continuously-learning RAG system, the embedding model itself may be updated. What happens to cached entries encoded with the old model? No paper addresses embedding version migration for caches.

5. **Optimal cache size**: No paper provides guidance on how large the cache should be relative to the query volume or corpus size. The NP-hardness result (Biton & Friedman) implies this is fundamentally hard to optimize.

---

## Serendipitous Connections

**Bradley-Terry and semantic cache threshold calibration** (Ranking Todo project): The problem of choosing a similarity threshold is structurally similar to choosing a decision boundary in a classification problem. Your Preference Sort system uses Bradley-Terry models for pairwise comparisons. A similar approach could calibrate cache thresholds: present pairs of queries to an LLM judge ("are these semantically equivalent?"), fit a Bradley-Terry-like model to the pairwise judgments, and derive the threshold from the decision boundary of the fitted model. This connects directly to the Krites paper's async LLM-judge verification.

**Knowledge Graph enrichment** (Kindle Graph Enrichment project): Cached RAG responses contain implicit knowledge about which concepts are frequently queried together. Mining cache hit patterns could reveal concept clusters that should be linked in your Neo4j knowledge graph — a form of implicit graph construction from usage data.

**Information gain and cache eviction** (Ranking Todo project): The Biton & Friedman locality heuristic (entries that cover more embedding space are more valuable) is formally related to information gain in decision trees. An entry that, if evicted, would create the largest "coverage gap" has the highest information value — the same principle used in active learning and your Bradley-Terry information gain implementation.

---

## Implementation Roadmap for Your System

### Phase 1 — Minimal Viable Cache (1--2 days)

1. Create `semantic_cache` table in PostgreSQL (see SQL in Section 3).
2. Implement cache lookup in your RAG query path: embed query → pgvector cosine search → if similarity > 0.92, return cached response.
3. On cache miss: run normal RAG pipeline, store result in cache.
4. TTL: add `WHERE created_at > NOW() - INTERVAL '7 days'` to the lookup query.

### Phase 2 — Invalidation (1 day)

1. Add `corpus_version INTEGER` column to cache table.
2. Increment version in your `ScheduledReindex` job after successful reindex.
3. Add `WHERE corpus_version >= current_version` to cache lookup.

### Phase 3 — Threshold Calibration (2--3 hours)

1. Collect 50 real queries from your system logs.
2. Generate paraphrases + negative examples.
3. Compute similarity distributions, find the gap, set threshold.

### Phase 4 — Monitoring (ongoing)

1. Log cache hit/miss ratio daily.
2. Track false positives (user re-asks a question that was served from cache — implies the cached answer was wrong or stale).
3. Adjust threshold based on observed precision.

---

## What to Read Next

1. **Biton & Friedman (arXiv:2603.03301)** — The most theoretically grounded paper. Read this for the NP-hardness proof, the locality heuristic, and the open-source implementation that you can study for policy design patterns.

2. **Gill et al. (arXiv:2504.02268)** — Directly relevant to your embedding model choice. Understand how fine-tuning compact models for the caching task specifically changes the precision/recall landscape. This may inspire fine-tuning `mxbai-embed-large` on your own query pairs.

3. **Singh et al. / Krites (arXiv:2602.13165)** — The tiered architecture is the most practical design for a RAG system. The async LLM-judge verification pattern is directly implementable in your stack.

---

## Sources

All sources actually fetched and read (abstracts or full text):

| Tier | Source | URL |
|------|--------|-----|
| T2 | Regmi & Pun, GPT Semantic Cache (2024) | https://arxiv.org/abs/2411.05276 |
| T2 | vCache: Verified Semantic Prompt Caching (2025) | https://arxiv.org/abs/2502.03771 |
| T2 | Gill et al., Domain-Specific Embeddings (2025) | https://arxiv.org/abs/2504.02268 |
| T2 | Ghaffari et al., Ensemble Embedding (2025) | https://arxiv.org/abs/2507.07061 |
| T2 | Chakraborty et al., Generative Caching (2025) | https://arxiv.org/abs/2511.17565 |
| T2 | Singh et al., Krites (2026) | https://arxiv.org/abs/2602.13165 |
| T2 | Wu et al., RAC (2026) | https://arxiv.org/abs/2602.21547 |
| T2 | Biton & Friedman, From Exact Hits (2026) | https://arxiv.org/abs/2603.03301 |
| T1 | Nature Sci. Rep., Security vulnerabilities (2026) | https://nature.com/articles/s41598-026-36721-w |
| T7 | GPTCache GitHub + NLP-OSS 2023 | https://github.com/zilliztech/GPTCache |
| T7 | LangChain RedisSemanticCache docs | via web search |
| T7 | RedisVL SemanticCache API | via web search |
| T7 | Dataquest semantic caching tutorial | via web search |
| T7 | VentureBeat cost reduction report | via web search |

---

## Knowledge Graph Candidates

- "Semantic Caching" — Type: technique. Links: RAG, pgvector, Embedding, Redis, LLM
- "Cache Invalidation" — Type: principle. Links: Semantic Caching, Corpus Versioning, TTL
- "GPTCache" — Type: framework. Links: Semantic Caching, Zilliz, LangChain
- "Cosine Similarity Threshold" — Type: technique. Links: Semantic Caching, Embedding, Calibration
- "NP-hardness of Semantic Cache Policy" — Type: principle. Links: Semantic Caching, Computational Complexity, Cache Eviction
- "Relation-Aware Cache Replacement" — Type: technique. Links: Semantic Caching, Topical Prevalence, LRU, LFU

---

## Quality Checklist

- [x] At least 2 primary sources (T1 or T2) actually fetched and read — 8 T2 papers + 1 T1
- [x] Epistemic status and confidence label included in the summary
- [x] Source tier labeled for every key claim
- [x] Replication or consensus status addressed (no replications exist; noted)
- [x] Open questions section present
- [x] Serendipitous connections considered (3 connections found)
- [x] No fabricated citations — only URLs actually fetched
- [x] Effect sizes reported (hit rates, cost reduction percentages, latency reduction)
- [x] Personal project connection noted (Ranking Todo / Bradley-Terry, Kindle Graph Enrichment)
- [x] Template A used for survey query
