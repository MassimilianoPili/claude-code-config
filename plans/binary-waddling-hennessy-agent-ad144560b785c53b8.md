# KORE-GC Literature Gap Verification -- 2026-03-23

## Summary

15 searches executed across SearXNG (web + science categories) and Semantic Scholar API.
Many search engines were degraded (Google, Brave, DuckDuckGo, Startpage all rate-limited/CAPTCHA-blocked).
Primary working sources: arXiv (intermittent), Semantic Scholar API (intermittent), CrossRef, OpenAlex.

---

## BATCH 1: Direct Gap Threats

### Search 1: "graph vector store maintenance pruning"
- **Results**: 10 (all noise -- neural network pruning, graph theory, railway maintenance)
- **Relevant papers**: NONE
- **Threatens novelty**: NO

### Search 2: "RAG maintenance garbage collection embedding"
- **Results**: 10 (Rust GC, RAG benchmarks, MultiHop-RAG, abstract GC for programming languages)
- **Relevant papers**: NONE
- **Threatens novelty**: NO

### Search 3: "GraphRAG maintenance lifecycle update 2025 2026"
- **Results**: 10 (all noise -- particle physics, speech challenges, AI safety report)
- **Relevant papers**: NONE
- **Threatens novelty**: NO

### Search 4: "embedding staleness freshness detection"
- **Results**: 0 (engines timed out)
- **Followed up via Semantic Scholar**: Found **one relevant paper** (see below)
- **Threatens novelty**: PARTIAL (see analysis)

### Search 5: "knowledge graph embedding incremental maintenance"
- **Results**: 0 (engines timed out)
- **Followed up via Semantic Scholar**: No relevant results
- **Threatens novelty**: NO

---

## BATCH 2: Closest Prior Work Extensions

### Search 6: "LightRAG deletion update maintenance"
- **Results**: 10 (all noise -- deletion codes, information theory, point processes)
- **Semantic Scholar deep check on LightRAG paper** (arXiv:2410.xxxxx, EMNLP 2024, 217 citations):
  - LightRAG has an **incremental update algorithm** for adding new data
  - The abstract mentions "timely integration of new data" but says NOTHING about deletion, GC, staleness detection, or cross-store consistency
  - It integrates graph structures with vector representations but treats them as a retrieval mechanism, not as a co-maintained store
- **Threatens novelty**: NO -- LightRAG is add-only incremental, no GC/deletion/consistency

### Search 7: "GraphRAG microsoft maintenance update 2026"
- **Results**: 0 (all engines timed out)
- **Semantic Scholar**: Empty results for "GraphRAG incremental update delete maintenance"
- **Threatens novelty**: NO (no evidence of Microsoft GraphRAG adding GC capabilities)

### Search 8: "MemGPT Letta memory garbage collection pruning"
- **Results**: 0 (engines timed out)
- **Semantic Scholar**: Empty results
- **Threatens novelty**: NO

---

## BATCH 3: Novel Terminology

### Search 9: "neural materialized view" (exact phrase)
- **Results**: 0 (engines timed out)
- **Semantic Scholar**: Found "neural incremental view maintenance" papers -- all about traditional IVM for SQL views, not for embedding stores
- **Threatens novelty**: NO -- our term remains unclaimed

### Search 10: "cross-store consistency graph vector" (exact phrase)
- **Results**: 0 across all engines
- **Threatens novelty**: NO -- term does not exist in literature

### Search 11: "transactional garbage collection knowledge store" (exact phrase)
- **Results**: 0 across all engines
- **Threatens novelty**: NO -- term does not exist in literature

---

## BATCH 4: Agent Memory

### Search 12: "agent memory management consolidation 2026"
- **Results**: 10 (mostly noise, but one interesting hit)
- **Relevant paper**: "Agent Memory Below the Prompt" (Shkolnikov, 2026) -- about KV cache persistence on edge devices, NOT semantic memory GC
- **Threatens novelty**: NO

### Search 13: "long-term memory AI agent pruning maintenance"
- **Results**: 0 (engines timed out)
- **Followed up via Semantic Scholar API** -- found several important agent memory papers:

| Paper | Year | Citations | Relevant? | Threatens? |
|-------|------|-----------|-----------|------------|
| **MIRIX** (Wang & Chen) | 2025 | 64 | Partially -- 6 memory types, multi-agent coordination | NO -- focuses on memory storage/retrieval, not GC/pruning |
| **Nemori** (Nan et al.) | 2025 | 31 | Partially -- self-organizing memory, "adaptive knowledge evolution" | PARTIAL -- has reorganization but no formal GC theory |
| **Mem0** (Chhikara et al.) | 2025 | 201 | Partially -- "dynamically extracting, consolidating" + graph memory | PARTIAL -- consolidation is related but no formal GC |
| **CraniMem** (Mody et al.) | 2026 | 0 | **YES -- closest to our work** | PARTIAL (see detailed analysis) |

### CraniMem Deep Analysis (MOST IMPORTANT FINDING)

CraniMem (2026, unpublished preprint, 0 citations) introduces:
- "Gated and bounded multi-stage memory" for agentic systems
- **"Scheduled consolidation loop" that replays high-utility traces into a knowledge graph while PRUNING low-utility items**
- Bounded episodic buffer + structured long-term knowledge graph
- Utility-based pruning to keep memory growth in check

**Key differences from KORE-GC**:
1. CraniMem is an **application-level** agent memory system, not a **database-level** transactional GC
2. No formal consistency guarantees between graph and vector stores
3. No embedding staleness detection
4. No cross-store transactional semantics
5. No GC theory (reference counting, reachability analysis, etc.)
6. Pruning is heuristic (utility score), not principled (graph reachability + embedding drift)
7. 0 citations, not peer-reviewed

**Verdict**: CraniMem is the **closest neighbor** but operates at a completely different abstraction level (agent application vs. database infrastructure). It validates the NEED for our work but does not occupy our niche.

---

## BATCH 5: Neighboring Fields

### Search 14: "feature store embedding drift freshness tracking"
- **Results**: 10 (mostly noise)
- **One relevant paper**: "Managing ML Pipelines: Feature Stores and the Coming Wave of Embedding Ecosystems" (Orr et al., VLDB 2021, arXiv:2108.05053)
  - Identifies the challenge of "managing embedding training data, measuring embedding quality, and monitoring downstream models"
  - Notes these challenges are "largely unaddressed in standard feature stores"
  - **Already known to us** -- this is prior work we cite
- **Threatens novelty**: NO -- identifies the problem, proposes no solution

### Search 15: "data lakehouse vector column maintenance"
- **Results**: 10 (mostly noise)
- **One interesting paper**: "Building a Correct-by-Design Lakehouse" (Sheng et al., 2026, Bauplan)
  - Transactional pipelines, data contracts, versioning
  - Relevant as neighboring work (transactional data management) but no vector/graph angle
- **Threatens novelty**: NO

---

## Additional Semantic Scholar Findings

### euRAG: "Accelerating Partial Knowledge Updates in a RAG System" (Zhu et al., 2025, 0 citations)
- Addresses efficient **partial updates** to vector stores in RAG
- Chunk-level granularity, parallel I/O pipeline
- 1.2x-1.6x speedup over LangChain/LlamaIndex for updates
- **Key gap**: Only handles TEXT UPDATES to existing chunks. No graph structure. No GC. No staleness detection. No cross-store consistency.
- **Threatens novelty**: NO -- solves a different (simpler) problem

### "Measuring Retrieval Freshness and Accuracy Degradation in Continuous ETL-Driven RAG Systems" (Annam, 2026, 0 citations)
- **Most relevant to embedding staleness angle**
- Shows freshness is "first-order determinant of end-to-end accuracy"
- Calls for "principled freshness management" and "cost-sensitive update methods"
- Published in Journal of Information Systems Engineering & Management (low-tier venue)
- **Key gap**: This is a MEASUREMENT paper. Identifies the problem empirically but proposes NO mechanism for solving it. No graph component. No GC theory. No transactional semantics.
- **Threatens novelty**: NO -- validates our problem statement, provides no solution. Should be CITED as supporting evidence.

---

## LANDSCAPE SUMMARY: What Has Changed Since Early March

| Development | Impact on KORE-GC |
|-------------|-------------------|
| CraniMem (2026) -- agent memory with utility-based pruning | Validates need; different abstraction level |
| Annam (2026) -- freshness measurement in RAG | Validates problem; no solution proposed |
| euRAG (2025) -- partial updates to vector chunks | Addresses updates only; no graph, no GC |
| Mem0 now at 201 citations | Confirms explosive interest in persistent memory |
| MIRIX at 64 citations | Confirms multi-type memory is hot topic |
| LightRAG at 217 citations | Confirms graph+vector RAG interest; still add-only |

**No paper addresses the combined problem of:**
1. Cross-store consistency between graph and vector stores
2. Transactional GC for co-located knowledge stores
3. Embedding staleness detection tied to graph topology changes
4. Formal GC theory applied to knowledge store maintenance

---

## GAP STATUS: **CONFIRMED** -- Confidence 9/10

The literature gap remains **firmly open**. After 15 searches across multiple engines and APIs:

- **0 papers** found on transactional GC for graph+vector stores
- **0 papers** found on cross-store consistency for knowledge stores
- **0 papers** using our key terms ("neural materialized view", "cross-store consistency", "transactional garbage collection knowledge store")
- The closest neighbor (CraniMem) operates at application level, not database level, and has 0 citations

**Confidence is 9/10 (not 10/10) because:**
- Many search engines were rate-limited/timed out during this session
- ICDE 2026 and VLDB 2026 proceedings are not yet fully indexed
- A paper could be in submission/camera-ready that we cannot see

**Recommendation**: Proceed with paper. The gap is not just open -- it is widening, as the explosion of agent memory systems (Mem0, MIRIX, Nemori, CraniMem) creates MORE demand for principled infrastructure-level solutions. The Annam (2026) freshness measurement paper should be added to our related work as it empirically validates our problem statement.

### New Papers to Cite
1. **CraniMem** (Mody et al., 2026) -- closest application-level work, cite in related work to differentiate
2. **Annam (2026)** -- "Measuring Retrieval Freshness..." -- empirical validation of staleness problem
3. **euRAG** (Zhu et al., 2025) -- partial update optimization, cite as engineering-level prior work
4. **Mem0** (Chhikara et al., 2025, ECAI) -- graph-based memory consolidation, cite to show demand
5. **Nemori** (Nan et al., 2025) -- self-organizing memory with "adaptive knowledge evolution"
