# Plan: Write Research Document for #133 AUDIT_MANAGER Dual-Mode

## Task
Write comprehensive research findings to `/data/massimiliano/docs/research/audit-dual-mode-133.md`

## Research Complete — Summary of Findings

### Paper Validations
1. **AutoCodeRover (Zhang et al.)** — VALIDATED with correction: venue is **ISSTA 2024** (International Symposium on Software Testing and Analysis), NOT ICSE 2025 as claimed. arXiv:2404.05427. 185 citations, 22 influential.
2. **SWE-Agent (Yang et al.)** — VALIDATED: **NeurIPS 2024**. arXiv:2405.15793. 792 citations, 101 influential. Massive impact.

### New Papers Found
1. **Agentless** (Xia et al., 2024) — arXiv:2407.01489. 289 citations, 57 influential. Three-phase: localization → repair → validation. No agent autonomy. Achieved 32% on SWE-bench Lite at $0.70.
2. **CodexGraph** (Liu et al., 2024) — NAACL 2025. arXiv:2408.03910. 63 citations. Graph database interfaces for LLM agents. Directly relevant to our code graph construction.
3. **LocAgent** (Chen et al., 2025) — ACL 2025. 44 citations. Graph-guided agents for code localization. Lightweight graph representation of code structures + dependencies.
4. **CGM (Code Graph Model)** (Tao et al., 2025) — NeurIPS 2025. arXiv:2505.16901. 19 citations. Integrates code graph structures into LLM attention. 43% on SWE-bench Lite with open-source model.
5. **CodePlan** (Bairi et al., 2023) — FSE/ESEC 2024. 178 citations. Repository-level coding as a planning problem. Incremental dependency analysis + change may-impact analysis.
6. **Prometheus** (Pan et al., 2025) — 9 citations. Memory-centric agent with unified knowledge graph for codebase navigation. Working memory for context continuity.
7. **METR SWE-bench analysis** (2026-03-10) — ~50% of test-passing SWE-bench PRs would NOT be merged by maintainers. Critical caveat for benchmark interpretation.
8. **Aider RepoMap** — Tree-sitter based repo map: classes, methods, function signatures. PageRank-like ranking for context selection.

### Key Design Insights for AUDIT_MANAGER Dual-Mode
- **Graph-based representation is the winning approach** (CodexGraph, CGM, LocAgent, Prometheus all confirm)
- **Hierarchical summarization** matters: file → class → method signatures (Aider, STALL+, CGM)
- **Agentless localization phase** directly validates the pre-planning concept
- **CodePlan's dependency analysis** is the closest academic analog to the proposed RepositoryContext
- **Diminishing returns**: CGM shows performance positively correlates with graph quality, but METR shows benchmark scores overestimate real-world utility by ~50%

## Execution Plan
1. Create directory if needed: `/data/massimiliano/docs/research/`
2. Write the full research document using Template A (Survey/Literature Review) format
3. Document contains: paper validations, new findings, design recommendations, all with tier labels
