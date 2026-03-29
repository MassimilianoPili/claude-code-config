# KORE-GC Gap Re-Verification Plan (March 2026)

## Objective
Re-verify the literature gap for "Transactional GC for Co-located Graph-Vector Knowledge Stores" paper, focusing on Jan-Mar 2026 publications that might close the gap identified in the original verification (which found ZERO papers on combined graph+vector maintenance).

## Prior State
- Original gap verification: ~30 queries, 0 relevant papers found
- Closest work: LightRAG (append-only incremental), Drift-Adapter (vector-only model migration), IP-DiskANN (vector-only in-place updates)
- Gap confidence: 9/10

## Search Strategy: 5 Phases, 40+ Queries

### Phase 1: Direct Gap Threats (highest priority)
Searches specifically targeting papers that could close our gap.

**1A. arXiv searches (web_fetch with extract=arxiv)**
1. `graph vector maintenance 2026` — arxiv search
2. `knowledge graph embedding maintenance 2026` — arxiv search
3. `RAG maintenance OR RAG pruning OR RAG garbage collection` — arxiv search
4. `vector index maintenance knowledge graph` — arxiv search
5. `GraphRAG maintenance OR GraphRAG update OR GraphRAG lifecycle` — arxiv search
6. `embedding staleness OR embedding freshness OR stale embedding` — arxiv search
7. `incremental view maintenance embedding` — arxiv search

**1B. Semantic Scholar API (web_fetch with extract=semantic_scholar)**
8. Same 7 queries via S2 API, filtered to 2025-2026
9. Check citation growth on LightRAG, GraphRAG, Drift-Adapter (new citing papers)

**1C. SearXNG science category**
10. Backup queries for anything missed by arXiv/S2

### Phase 2: Deep Dive on Closest Prior Work
For each paper, fetch the actual paper/abstract and verify they DON'T cover our territory.

**2A. LightRAG (Guo et al., EMNLP 2024)**
- Fetch the paper, check Section on "incremental update"
- Check if any follow-up papers from HKUDS lab extend to deletions/GC
- Search S2 for papers citing LightRAG that add maintenance

**2B. GraphRAG (Edge et al., 2024)**
- Check GitHub issues/discussions for maintenance features
- Search for Microsoft Research follow-ups on GraphRAG maintenance

**2C. CAGED (Zhang et al., 2022)**
- Verify it's about contrastive error detection, not consistency metrics

**2D. Drift-Adapter (Vejendla, EMNLP 2025)**
- Confirm it's purely vector-side, no graph awareness

**2E. IP-DiskANN (Xu et al., 2025)**
- Confirm it's ANN graph (not knowledge graph) maintenance

### Phase 3: Novel Terminology Search
Search for the specific concepts we formalize.

11. `"neural materialized view" OR "neural IVM"` — S2 + arXiv
12. `"cross-store consistency" graph vector` — S2 + web
13. `"transactional garbage collection" knowledge` — S2 + web
14. `"generational garbage collection" data OR knowledge` (not PL runtime) — S2

### Phase 4: Agent Memory Literature (fast-moving)
15. MemGPT/Letta — check for GC/maintenance mechanisms in latest versions
16. Hippocampus (Li et al., 2026) — deeper dive on memory consolidation
17. `"agent memory management" 2026` — arXiv + S2
18. `"long-term memory" "AI agent" maintenance OR pruning` — S2
19. Search for any "memory garbage collection" in agent context

### Phase 5: Neighboring Fields
20. `"feature store" embedding freshness` — S2 + web
21. `Delta Lake OR Iceberg embedding column maintenance` — web
22. `lakehouse vector maintenance` — web
23. `Feast OR Tecton embedding drift` — web

## Execution Order
Run Phase 1A and 1B in parallel (14 queries).
Then Phase 2 deep dives (5 papers).
Then Phases 3-5 in parallel (13 queries).
Total: ~32 distinct searches + 5 deep dives.

## Output
Write results to `/data/massimiliano/docs/papers/kore-gc/research/07-gap-reverification-march-2026.md` using Template F (Design Validation) adapted for gap verification.

For each paper found:
- Title, authors, venue, year, citations (S2)
- Relevance to KORE-GC (1-10)
- Whether it threatens our novelty claim (YES/NO/PARTIAL)
- How to position against it in Related Work
- Source tier label

## Risk Assessment
The gap is most likely to have been closed by:
1. **Microsoft GraphRAG team** — they have the scale and motivation (check MSR publications)
2. **HKUDS lab (LightRAG authors)** — they have the closest existing system (check HKU DS lab page)
3. **Vector DB vendors** (Weaviate, Qdrant) — they're adding graph features (check engineering blogs)
4. **Agent memory papers at AAAI/ICLR 2026** — the agent memory field is the most aware of the problem

Lowest risk: someone independently formulating "neural IVM" or "transactional GC for knowledge stores" — these are our novel theoretical framings.
