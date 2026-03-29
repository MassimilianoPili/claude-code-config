# KORE-GC Gap Re-Verification Plan

## Objective
Re-verify the literature gap for "KORE-GC: Transactional Garbage Collection for Co-located Graph-Vector Knowledge Stores" — originally confirmed March 2026 (confidence 9/10). Check for new threats from the fast-moving GraphRAG/agent memory fields.

## Baseline (from 02-gap-verification.md)
- **30+ targeted queries, ZERO papers** on combined graph+vector maintenance
- Closest prior work: LightRAG (append-only incremental), Drift-Adapter (vector-only), IP-DiskANN (ANN graph, not KG)
- Gap exists at intersection of 3 siloed communities: KG maintenance (ISWC), vector index (VLDB), GraphRAG (EMNLP)

## Execution Plan

### Phase 1: Direct gap threats (2025-2026) — 7 parallel searches
All via `web_search` (SearXNG science+general) + `web_fetch` for Semantic Scholar API + arXiv.

| # | Query | Source | Purpose |
|---|-------|--------|---------|
| 1.1 | "graph vector maintenance" 2025 2026 | SearXNG science | Direct match |
| 1.2 | "knowledge graph embedding maintenance" 2025 2026 | SearXNG science | Broader KG+embedding |
| 1.3 | "RAG maintenance" OR "RAG pruning" OR "RAG garbage collection" | SearXNG science | RAG lifecycle |
| 1.4 | "GraphRAG maintenance" OR "GraphRAG update" OR "GraphRAG lifecycle" | SearXNG science+general | Microsoft GraphRAG evolution |
| 1.5 | "embedding staleness" OR "embedding freshness" OR "stale embedding" | SearXNG science | Drift/staleness literature |
| 1.6 | "incremental view maintenance" embedding | SearXNG science | Neural IVM overlap |
| 1.7 | "vector index maintenance" "knowledge graph" | SearXNG science | Direct intersection |

Additionally, Semantic Scholar API queries:
| 1.8 | S2: "graph vector store maintenance garbage collection" | S2 API | Direct API search |
| 1.9 | S2: "GraphRAG incremental update deletion pruning" | S2 API | LightRAG follow-ups |
| 1.10 | arXiv: "graph vector maintenance" | arXiv search | Direct arXiv |

### Phase 2: Deep dive closest prior work — 5 targeted fetches
For each paper, verify they still DON'T cover combined maintenance.

| # | Paper | Check | Method |
|---|-------|-------|--------|
| 2.1 | LightRAG (Guo et al.) | New versions? Deletion support? Follow-up papers? | S2 citations API + GitHub repo |
| 2.2 | GraphRAG (Edge et al.) | Maintenance discussion? New versions? | S2 citations API + GitHub issues |
| 2.3 | CAGED (Zhang et al., 2022) | Consistency metrics scope | S2 fetch |
| 2.4 | Drift-Adapter (Vejendla, EMNLP 2025) | Graph-aware extensions? | S2 fetch |
| 2.5 | IP-DiskANN (2025) | KG integration? | S2 fetch |

### Phase 3: Novel terminology — 4 searches
Check if anyone else coined our terms.

| # | Query | Source |
|---|-------|--------|
| 3.1 | "neural materialized view" OR "neural IVM" | SearXNG science + general |
| 3.2 | "cross-store consistency" graph vector | SearXNG science |
| 3.3 | "transactional garbage collection" knowledge | SearXNG science + general |
| 3.4 | "generational garbage collection" data NOT runtime NOT programming | SearXNG science |

### Phase 4: Agent memory (fast-moving) — 4 searches
| # | Query | Source |
|---|-------|--------|
| 4.1 | MemGPT Letta garbage collection memory management | SearXNG science + general |
| 4.2 | "agent memory management" 2026 | SearXNG science |
| 4.3 | "long-term memory" "AI agent" maintenance pruning | SearXNG science |
| 4.4 | Hippocampus Li 2026 memory agent (updated citations?) | S2 API |

### Phase 5: Neighboring fields — 3 searches
| # | Query | Source |
|---|-------|--------|
| 5.1 | "feature store" embedding freshness drift | SearXNG science |
| 5.2 | "Delta Lake" OR "Iceberg" embedding column maintenance | SearXNG general |
| 5.3 | "lakehouse" vector maintenance | SearXNG science + general |

## Execution Strategy

**Batch 1** (parallel, ~10 calls): Phase 1 searches (1.1-1.7) + S2 API (1.8-1.10)
**Batch 2** (parallel, ~5 calls): Phase 2 deep dives (2.1-2.5) — depends on IDs from batch 1 for updated citation counts
**Batch 3** (parallel, ~8 calls): Phase 3 (3.1-3.4) + Phase 4 (4.1-4.4)
**Batch 4** (parallel, ~3 calls): Phase 5 (5.1-5.3)
**Batch 5** (sequential): Follow up on any hits from batches 1-4

Total: ~26 primary search calls + follow-up fetches for any hits.

## Output
Write results to `/data/massimiliano/docs/papers/kore-gc/research/07-gap-reverification-2026-03.md` using Template A (Survey) structure.

For each paper found:
- Title, authors, venue, year, estimated citations
- Relevance to KORE-GC (1-10)
- Threat to novelty: YES / NO / PARTIAL
- Positioning advice

End with: **GAP STATUS**: CONFIRMED / THREATENED / CLOSED (with confidence level and delta from original 9/10).

## Risk Assessment
Main risks since original verification:
1. **LightRAG v2** — HKUDS lab very active, could have added deletion support
2. **Microsoft GraphRAG** — large team, could have published maintenance whitepaper
3. **Agent memory papers** — fastest-moving subfield, several new papers expected
4. **VLDB/SIGMOD 2026 proceedings** — not yet fully indexed, could contain surprises
5. **Industry whitepapers** — Pinecone, Weaviate, Qdrant blog posts on graph+vector

## Status
- [x] Plan written
- [ ] Phase 1 executed
- [ ] Phase 2 executed
- [ ] Phase 3 executed
- [ ] Phase 4 executed
- [ ] Phase 5 executed
- [ ] Synthesis and report written
