# Plan: Research Document for Recovery Router #130

## Status: RESEARCH COMPLETE — Ready to write output file

## Summary of Findings

All research has been conducted. The key findings are:

### 1. Bholani "Self-Healing Router" — VALIDATED (REAL)
- **arXiv:2603.01548** — "Graph-Based Self-Healing Tool Routing for Cost-Efficient LLM Agents"
- Author: Neeraj Bholani (John Deere, MIT background)
- Published: March 2, 2026 (12 days ago)
- Categories: cs.AI, cs.SE
- Working paper, 27 references, GitHub repo exists
- Semantic Scholar: 0 citations (brand new)
- Key claim: -93% LLM recovery calls validated in abstract
- Uses Dijkstra on cost-weighted tool graph
- References ControlLLM, ToolNet, NaviAgent as prior art
- References SHIELDA as related work

### 2. MAST (Cemri et al.) — RE-CONFIRMED
- **arXiv:2503.13657** — "Why Do Multi-Agent LLM Systems Fail?"
- NeurIPS 2025 Datasets & Benchmarks (poster confirmed at neurips.cc/virtual/2025/poster/121528)
- 238 citations, 38 influential (very high impact)
- 14 failure modes, 3 categories, 1600+ annotated traces
- Inter-annotator agreement kappa=0.88
- Authors from Berkeley (Stoica, Gonzalez, Klein, etc.)

### 3. Additional Papers Found

**Directly relevant to Recovery Router:**

a) **SHIELDA** (Zhou et al., 2025) — arXiv:2508.07935
   - "Structured Handling of Exceptions in LLM-Driven Agentic Workflows"
   - Runtime exception handling framework for agentic workflows

b) **CHIEF** (Wang et al., 2026) — arXiv:2602.23701
   - "From Flat Logs to Causal Graphs: Hierarchical Failure Attribution for LLM-based Multi-Agent Systems"
   - Transforms execution logs into hierarchical causal graph
   - Counterfactual attribution via progressive causal screening
   - Directly relevant: causal graph approach to failure diagnosis

c) **Who&When** (Zhang et al., 2025) — arXiv:2505.00212
   - "Which Agent Causes Task Failures and When?"
   - 127 LLM multi-agent systems, fine-grained failure annotations
   - Best method: 53.5% agent-level, only 14.2% step-level accuracy
   - Shows how hard automated failure attribution is

d) **Causal inference for MAS** (Ma et al., 2025) — arXiv:2509.08682
   - Causal inference + Shapley values for agent-level blame
   - CDC-MAS algorithm for non-stationary interaction data
   - 36.2% step-level accuracy, +22.4% task success rate improvement

e) **ADAS** (Hu, Lu, Clune, 2024) — arXiv:2408.08435
   - "Automated Design of Agentic Systems"
   - Meta Agent Search: meta-agent programs better agents
   - 144 citations, 28 influential. Published at ICLR.
   - Relevant: dynamic agent composition as alternative to static graphs

f) **Sherlock** (Ro et al., 2025) — arXiv:2511.00330
   - "Reliable and Efficient Agentic Workflow Execution"
   - Adapts to workflow structure for reliable execution

g) **ControlLLM** — Referenced by Bholani as prior art (tool selection via graph search)
h) **ToolNet** — Referenced by Bholani (transferable graphs connecting tools)
i) **NaviAgent** — Referenced by Bholani (bilevel planning on tool navigation graph)

**Circuit breaker / resilience patterns:**
- Medium article by Hannecke (2026): "Resilience Circuit Breakers for Agentic AI"
- SitePoint guide on Claude API circuit breaker pattern
- These are engineering patterns, not academic papers

**Saga pattern:**
- Microsoft Azure Architecture Center documentation
- No academic papers applying saga patterns specifically to LLM agent orchestration
- This is an engineering analogy, not established in ML literature

### 4. Key Answers to Research Questions

**Q1: Does Bholani exist?**
YES. arXiv:2603.01548, published March 2, 2026. Real paper, real author, real GitHub repo.
The initial suspicion about "2026" was because today IS 2026-03-14.

**Q2: Dijkstra vs probabilistic?**
Bholani explicitly argues FOR Dijkstra because:
- Deterministic = predictable, debuggable, binary observability
- Sub-millisecond rerouting (no LLM invocation needed)
- Only escalates to LLM when NO feasible path exists
- The stochastic shortest path (SSP) literature exists but adds complexity
  without clear benefit for tool routing (edge failure is binary, not probabilistic)

However, for our RecoveryRouterService which weights by success rate:
- Dijkstra is appropriate IF edge weights = inverse success rate (deterministic weights from historical data)
- Stochastic shortest path (MDP formulation) would be better IF:
  - Success rates change rapidly during execution
  - There's significant uncertainty in the success rate estimates
  - You need risk-averse routing (CVaR optimization)
- Recommendation: Start with Dijkstra (as Bholani does), add Bayesian weight updates

**Q3: How do real frameworks handle cascading failures?**
Based on survey of CrewAI, MetaGPT, AutoGPT, and academic literature:
- Most frameworks: **simple retry + human escalation** (no graph routing)
- MAST finding: most failures are SILENT — agents don't detect them
- Bholani's key insight: make failures BINARY (reroute or escalate, never silent skip)
- SHIELDA: structured exception handling (try-catch analog for agents)
- No framework currently does graph-based rerouting in production

**Q4: Is MAST taxonomy sufficient for routing decisions?**
- MAST has 3 categories, 14 modes — confirmed and well-validated (kappa=0.88)
- The 3 categories map well to recovery strategies:
  - FM-1.x (Specification/Design) → prompt revision / task decomposition
  - FM-2.x (Inter-Agent) → reassignment / communication fix
  - FM-3.x (Verification) → add verification step
- BUT: MAST was designed for DIAGNOSIS, not routing
- For routing, you need: which CAPABILITY is missing, not which FAILURE occurred
- Recommendation: use MAST for failure classification, but route based on
  required capabilities (graph nodes = capabilities, not failure modes)

### 5. Serendipitous Connections

- **Bholani's approach ↔ RecoveryRouterService**: Nearly identical architecture.
  The "parallel health monitors + Dijkstra on tool graph" IS our design.
  Key difference: Bholani uses tool-level routing; we route at worker-type level.

- **CHIEF causal graphs ↔ AGE knowledge_graph**: The hierarchical causal graph
  from CHIEF could be stored in our AGE graph database for post-mortem analysis.

- **ADAS Meta Agent Search ↔ dynamic worker composition**: Instead of static
  graph routing, ADAS suggests the meta-agent could INVENT new recovery workflows.
  This is a future evolution beyond Dijkstra routing.

- **Preference Sort (Bradley-Terry) ↔ edge weight learning**: The success rate
  weights on our graph edges are essentially a preference learning problem.
  Could use Bradley-Terry model to learn relative worker quality from pairwise outcomes.

## Execution Plan

When user exits plan mode, write the complete research document to:
`/data/massimiliano/docs/research/recovery-router-130.md`

Using Template A (Survey/Literature Review) format.
