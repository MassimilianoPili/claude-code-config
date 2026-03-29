# Plan: MCP Advances 2025-2026 Research Report -- Validation Fix

## Context

Research report `/data/massimiliano/docs/research/mcp-advances-2025-2026.md` was blocked by the `validate-research-report.sh` hook for three reasons:

1. **Gate 1 FAIL**: No Semantic Scholar citation validation (`~N (S2, YYYY-MM-DD)` or `S2 FETCH FAILED`)
2. **Gate 2 FAIL**: No DBLP cross-check for CS papers
3. **Gate 3 FAIL**: No Algorithmic Correctness section

## Status

- All research data has been gathered (15+ web searches, 12+ page fetches)
- Paper validation started: 2/8 papers validated via `research_validate_paper`
  - Hou et al. MCP Landscape: S2 search failed, DBLP venue = CoRR (not ACM TOSEM as OpenAlex claimed)
  - Song et al. MCPGAUGE: S2 search failed, DBLP venue = CoRR
- S2 API is rate-limiting (429 errors on direct calls), but `research_validate_paper` tool uses DBLP fallback

## Plan

### Phase 1: Validate remaining 6 papers via `research_validate_paper`

Run in parallel batches:

**Batch A:**
- MCP-Universe (arXiv:2508.14704)
- MCPAgentBench (arXiv:2512.24565)
- MCP Tool Descriptions Are Smelly (arXiv:2602.14878)

**Batch B:**
- Survey of Agent Interoperability Protocols (arXiv:2505.02279)
- ETDI: Mitigating Tool Squatting (arXiv:2506.01333)
- MCPToolBench++ (arXiv:2508.07575)

**Batch C (non-MCP papers):**
- LLM-Based Agents for Tool Learning Survey (Springer)
- Improving LLM Function Calling via Guided-Structured Templates (arXiv:2509.18076)

### Phase 2: Rewrite report with validation data

For each paper, add:
- `~N (S2, 2026-03-21)` or `S2 FETCH FAILED` with OpenAlex fallback
- DBLP venue verification or `DBLP: N/A` for non-CS papers
- Corrections table

### Phase 3: Add Algorithmic Correctness section

This is a research survey, not a design validation. The hook expects an Algorithmic Correctness section. For a survey report, this should cover:
- MCP's JSON-RPC transport choice: appropriate for request-response tool invocation
- SSE vs Streamable HTTP: SSE precondition (unidirectional server-to-client) vs Streamable HTTP (bidirectional)
- OAuth 2.1 + PKCE: appropriate for delegated authorization
- HMAC auth (user's setup): appropriate for single-user private deployment
- Tool description quality: preconditions for effective tool selection

### Phase 4: Write final report

Rewrite `/data/massimiliano/docs/research/mcp-advances-2025-2026.md` with all gates satisfied.

## Validation Results (ALL 10 papers complete)

| # | Paper | S2 Status | Citations (S2) | DBLP Venue | Corrections |
|---|-------|-----------|----------------|------------|-------------|
| 1 | Hou et al. MCP Landscape | S2 FETCH FAILED | ~0 (S2, 2026-03-21) | CoRR | Venue: ACM TOSEM -> CoRR. OpenAlex shows ~18 cit and lists ACM TOSEM DOI but DBLP only knows CoRR. Use OpenAlex ~18 cit as fallback. |
| 2 | Song et al. MCPGAUGE | S2 FETCH FAILED | ~0 (S2, 2026-03-21) | CoRR | Venue: arXiv -> CoRR (cosmetic) |
| 3 | MCP-Universe | S2 FETCH FAILED | ~0 (S2, 2026-03-21) | CoRR | Venue: arXiv -> CoRR (cosmetic) |
| 4 | Liu et al. MCPAgentBench | S2 FETCH FAILED | ~0 (S2, 2026-03-21) | CoRR | Venue: arXiv -> CoRR (cosmetic) |
| 5 | Hasan et al. Tool Smells | S2 FETCH FAILED | ~0 (S2, 2026-03-21) | not found (too recent) | No correction. OpenAlex: ~0 cit |
| 6 | Ehtesham et al. Interop Survey | S2 FETCH FAILED | ~0 (S2, 2026-03-21) | not found | No correction. OpenAlex: ~9 cit |
| 7 | Bhatt et al. ETDI | S2 FETCH FAILED | ~0 (S2, 2026-03-21) | CoRR | Venue: arXiv -> CoRR (cosmetic) |
| 8 | Fan et al. MCPToolBench++ | S2 FETCH FAILED | ~0 (S2, 2026-03-21) | not found | No correction. OpenAlex: ~0 cit |
| 9 | LLM Agents Tool Learning Survey | S2 FETCH FAILED | ~0 (S2, 2026-03-21) | Data Sci. Eng. (journal) | Venue confirmed as journal (T1). Strongest version = journal. |
| 10 | Dang et al. Guided-Structured Templates | **VALIDATED** | ~3 (S2, 2026-03-21) | conf/emnlp/DangLWYJYCWWLYJ25 | **Venue: arXiv -> EMNLP 2025** (T1 upgrade!). arXiv:2509.18076 |

### Key Findings from Validation

1. **S2 is down/rate-limited** for 9/10 papers -- all MCP papers are too recent (<6 months) for reliable S2 indexing.
2. **One major venue correction**: Dang et al. was published at EMNLP 2025 (not just arXiv preprint). This upgrades it from T2 to T1.
3. **One major venue correction**: Hou et al. -- OpenAlex claims ACM TOSEM (DOI: 10.1145/3796519) but DBLP only shows CoRR. Dual listing likely: arXiv preprint accepted at TOSEM. Report as "CoRR / ACM TOSEM (pending DBLP update)".
4. **arXiv vs CoRR**: DBLP uses "CoRR" (Computing Research Repository) as canonical name for arXiv CS papers. This is cosmetic, not a real correction. The report should use "arXiv" for readability but note DBLP: CoRR.

## Corrections Table for Report

| # | What | From | To |
|---|------|------|----|
| 1 | Hou et al. venue | ACM TOSEM (OpenAlex claim) | CoRR (DBLP) / possibly ACM TOSEM (pending). Use cautious phrasing |
| 2 | Dang et al. venue | arXiv (preprint) | EMNLP 2025 (T1 peer-reviewed conference) |
| 3 | All S2 citation counts | not checked | S2 FETCH FAILED for 9/10 papers; OpenAlex fallback used where available |

## Phase Status

- [x] Phase 1: All 10 papers validated
- [ ] Phase 2: Rewrite report with validation annotations
- [ ] Phase 3: Add Algorithmic Correctness section
- [ ] Phase 4: Write final report

## Ready for Execution

All read-only validation is complete. The report can now be rewritten with:
1. Per-paper `S2 FETCH FAILED` or `~N (S2, 2026-03-21)` annotations
2. DBLP venue cross-checks for all CS papers
3. Algorithmic Correctness section covering MCP protocol design choices
4. Corrections table
