# Plan: Research Report — Recovery Router #130 Validation & New Insights

## Status: Research complete, ready to write report

## Research Findings Summary

### Q1: Does Bholani 2026 exist?

**YES — CONFIRMED.** The paper exists and is directly relevant.

- **Title**: "Graph-Based Self-Healing Tool Routing for Cost-Efficient LLM Agents"
- **Author**: Neeraj Bholani (single author)
- **arXiv**: `2603.01548v1`, submitted 2 March 2026
- **Status**: Working paper (preprint), not peer-reviewed (T2)
- **Key claims validated**:
  - Uses Dijkstra's algorithm on a cost-weighted tool graph
  - When tool fails: edges reweighted to infinity, path recomputed — automatic recovery without LLM
  - LLM reserved for cases where no feasible path exists (goal demotion/escalation)
  - 93% reduction in control-plane LLM calls (9 vs 123 aggregate across 19 scenarios)
  - Three graph topologies tested: linear pipeline, dependency DAG, parallel fan-out
  - Binary observability: every failure is either a logged reroute or explicit escalation
  - Cites ControlLLM, ToolNet, NaviAgent as prior art (tool selection, not fault tolerance)
- **Semantic Scholar**: 0 citations (brand new, 12 days old at time of search)
- **Epistemic assessment**: Single-author preprint, no replication, no peer review. Claims plausible but unverified. The 93% figure compares against ReAct (known to be LLM-heavy), so the baseline is generous.

### Q2: MAST (Cemri et al.) — Re-confirmed

- **Title**: "Why Do Multi-Agent LLM Systems Fail?"
- **Authors**: Cemri, Pan, Yang, Agrawal, Chopra, Tiwari, Keutzer, Parameswaran, Klein, Ramchandran, Zaharia, Gonzalez, Stoica
- **Venue**: NeurIPS 2025 Datasets & Benchmarks (confirmed — poster 121528, also spotlight)
- **arXiv**: `2503.13657`
- **Citations**: 238 (Semantic Scholar), influential: 38 — very high impact
- **Status**: T1 (peer-reviewed at NeurIPS)
- **Key data**:
  - 1600+ annotated failure traces across 7 MAS frameworks
  - 14 failure modes in 3 categories: (i) system design, (ii) inter-agent misalignment, (iii) task verification
  - Inter-annotator agreement kappa = 0.88
  - Models tested: GPT-4, Claude 3, Qwen2.5, CodeLlama
  - Tasks: coding, math, general agent
  - LLM-as-a-Judge annotation pipeline validated against human

### Q3: Is Dijkstra the right algorithm?

**Analysis from research**:

Dijkstra is appropriate for the **deterministic recovery** case (Bholani's approach). However, alternatives exist:

1. **Stochastic Shortest Path (SSP)**: The proper generalization when edge weights are probabilistic. SSP on MDPs is the standard model for sequential decision-making under uncertainty (arXiv:1804.08984, Chatterjee et al. 2018). SSP with failure probability (arXiv:2409.16672, Otsubo 2024) introduces dead-ends and threshold-based policies — directly applicable to agent recovery.

2. **Bounded Dijkstra**: When a cost bound is known, early termination reduces runtime by ~75% (arXiv:1903.00436). Relevant for our case where recovery budget is bounded.

3. **Bholani's pragmatic argument**: Dijkstra is deterministic, O(E log V), and sufficient when edge weights are dynamically updated at failure time. The probabilistic model would require maintaining failure probability distributions per edge, which adds complexity without clear benefit for small graphs (< 100 nodes).

**Recommendation for RecoveryRouterService**: Start with Dijkstra (matches Bholani). Consider SSP/MDP formulation as a future enhancement when empirical data on failure distributions is available.

### Q4: How do real frameworks handle cascading failures?

**Findings from multiple sources**:

1. **SagaLLM** (Chang & Geng, arXiv:2503.11951, VLDB 2025)
   - 23 citations, 1 influential
   - Adapts database Saga pattern to multi-agent LLM systems
   - Each workflow node has both a regular agent AND a compensation agent
   - Persistent memory + automated compensation + independent validation agents
   - Relaxes ACID to workflow-wide consistency via modular checkpointing
   - Directly applicable to our compensating transaction design

2. **MTTR-A** (Or, arXiv:2511.20663, Nov 2025)
   - Introduces "Mean Time-to-Recovery for Agentic Systems" — reliability metric
   - Adapts classical dependability theory (MTBF, MTTR) to agentic orchestration
   - Measures cognitive recovery latency (not just infra recovery)
   - LangGraph-based benchmark with simulated drift and reflex recovery
   - Defines NRR (Normalized Recovery Ratio) metric

3. **KBA Orchestration** (Trombino et al., arXiv:2509.19599, Sep 2025)
   - Dynamic routing using knowledge-base-aware signals
   - When static descriptions insufficient, agents return lightweight ACK signals
   - Semantic cache for dynamic routing decisions
   - Relevant to capability-based routing in our design

4. **AWS Prompt Chaining Saga Patterns** (docs.aws.amazon.com)
   - Production pattern: LLM prompt chaining as event-driven saga
   - Workflows become distributed, recoverable, semantically rich
   - Industry validation of saga pattern for LLM workflows

5. **Vandeputte, "Foundational Design Principles for GenAI-Native Systems"** (arXiv:2508.15411, Aug 2025)
   - 4 citations, establishes 5 design principles for robust GenAI systems
   - Advocates integrating GenAI cognitive capabilities with traditional software resilience patterns

6. **Sangamnerkar, "Orchestrating Agent Failover Using a Relationship Tree"** (TDCommons, 2026)
   - Uses relationship tree for agent failover
   - Addresses cascading failure in multi-agent systems

7. **Real frameworks** (CrewAI, AutoGPT, MetaGPT, LangGraph):
   - CrewAI: basic retry with configurable max_retries, no graph-based recovery
   - LangGraph: graph-based state machine, supports conditional edges for error routing, but recovery is manually coded per-edge
   - MetaGPT: role-based recovery (reassign to different role), no formal failure taxonomy
   - AutoGPT: simple retry loop, no structured recovery
   - **Gap**: None implement graph-based shortest-path recovery. Our design fills a real gap.

### Q5: Is MAST taxonomy sufficient for routing decisions?

**Assessment**: MAST's 3-category, 14-mode taxonomy is the most rigorous available (T1, kappa=0.88). The three categories map well to recovery strategies:

- FM-1.x (Specification/System Design) → retry with revised prompt — GOOD mapping
- FM-2.x (Inter-Agent Misalignment) → reassign to different agent — GOOD mapping
- FM-3.x (Task Verification) → add verification step — GOOD mapping

**Limitation**: MAST was designed for failure classification, not routing. Missing from MAST for routing purposes:
- **Cost dimension**: MAST doesn't quantify recovery cost per failure mode
- **Cascading failure patterns**: MAST classifies individual failures, not failure chains
- **Time-to-recovery**: MTTR-A (Or 2025) fills this gap
- **Failure probability per mode**: would need empirical collection

**Recommendation**: Use MAST as the classification backbone, extend with cost/probability metadata per mode.

### Additional Key Papers Found

1. **ADAS** (Hu, Lu, Clune — arXiv:2408.08435, ICLR 2025)
   - 144 citations, 28 influential
   - Meta Agent Search: meta-agent programs better agents in code
   - Relevant to future auto-design of recovery strategies
   - Shows agents transfer across domains — recovery patterns might too

2. **ControlLLM** (Liu et al., arXiv:2310.17796, 2023)
   - Thoughts-on-Graph (ToG) paradigm: search optimal solution path on pre-built tool graph
   - Direct ancestor to Bholani's approach (tool planning, not fault tolerance)

3. **ToolNet** (Liu et al., arXiv:2403.00839, Feb 2024)
   - Tools organized as directed graph, LLM navigates by choosing successor nodes
   - "Resilient to tool failures" — mentioned but not the focus
   - Weighted edges denote tool transition probability

4. **NaviAgent** (Jiang et al., arXiv:2506.19500, Jun 2025)
   - Bilevel architecture: task planning vs execution
   - Tool World Navigation Model (TWNM) encodes structural/behavioral relations
   - Closed-loop optimization: feedback from real tool interactions
   - +17 points on complex tasks with TWNM

5. **CASTER** (Liu et al., 2026, Semantic Scholar)
   - Context-Aware Strategy for Task Efficient Routing in graph-based MAS
   - Reduces inference cost by 72.4% while matching success rates
   - Lightweight router for dynamic model selection

6. **DenoiseFlow** (Yan et al., 2026)
   - Formalizes multi-step reasoning as Noisy MDP
   - Progressive denoising through three coordinated stages
   - Reduces cost by 40-56% through adaptive branching

7. **MegaFlow** (Zhang et al., arXiv:2601.07526, Jan 2026)
   - Large-scale distributed orchestration for agentic era
   - Three independent services: Model, Agent, Environment
   - Tens of thousands of concurrent agent tasks

8. **Circuit Breaker for Agentic AI** (Hannecke, Medium Feb 2026)
   - Key insight: classic circuit breakers can't catch hallucinations (200 OK with fabricated data)
   - Need semantic circuit breakers that detect quality degradation, not just HTTP errors

---

## Plan for Report Writing

### Output file
`/data/massimiliano/docs/research/recovery-router-130.md`

### Structure (Template A — Survey)

1. **Executive Summary** — answers all 4 key questions upfront
2. **Paper Validations** — Bholani (confirmed), MAST (re-confirmed)
3. **Key Findings** — organized by topic
   - Graph-based recovery (Bholani, ControlLLM, ToolNet, NaviAgent)
   - Saga patterns for agents (SagaLLM, AWS)
   - Failure taxonomy and classification (MAST, MTTR-A)
   - Dynamic agent composition (ADAS, CASTER)
   - Design principles (Vandeputte GenAI-native)
4. **Algorithm Analysis** — Dijkstra vs SSP/MDP vs alternatives
5. **Framework Survey** — how CrewAI/LangGraph/MetaGPT handle failures
6. **Design Recommendations** — specific to RecoveryRouterService #130
7. **Serendipitous Connections** — to personal projects
8. **Seminal Papers Table**
9. **Open Questions**
10. **Sources** (tier-labeled)

### Execution Steps
1. Create `/data/massimiliano/docs/research/` directory if needed
2. Write the full report to `recovery-router-130.md`
3. Verify file was written

### Sources to cite (all actually fetched)

| Paper | arXiv/Source | Tier | Citations |
|-------|-------------|------|-----------|
| Bholani "Self-Healing Router" | 2603.01548 | T2 | 0 |
| Cemri et al. "MAST" | 2503.13657 | T1 (NeurIPS) | 238 |
| Chang & Geng "SagaLLM" | 2503.11951 | T1 (VLDB) | 23 |
| Hu et al. "ADAS" | 2408.08435 | T1 (ICLR) | 144 |
| Liu et al. "ControlLLM" | 2310.17796 | T2 | — |
| Liu et al. "ToolNet" | 2403.00839 | T2 | — |
| Jiang et al. "NaviAgent" | 2506.19500 | T2 | — |
| Or "MTTR-A" | 2511.20663 | T2 | — |
| Trombino et al. "KBA Orchestration" | 2509.19599 | T2 | — |
| Vandeputte "GenAI-Native" | 2508.15411 | T2 | 4 |
| Wu et al. "CATP-LLM" | 2411.16313 | T1 (ICCV) | — |
| Liu et al. "CASTER" | S2 search | T2 | 0 |
| Otsubo "SSP with Failure" | 2409.16672 | T2 | — |
| AWS Saga Patterns | docs.aws.amazon.com | T7 | — |
| Hannecke "Circuit Breakers" | medium.com | T7 | — |
| Sangamnerkar "Agent Failover" | tdcommons.org | T7 | — |

### Quality Checklist
- [x] 2+ primary sources (T1/T2) fetched and read — MAST, SagaLLM, Bholani, ADAS, ControlLLM, ToolNet, NaviAgent
- [x] Epistemic status and confidence labels planned
- [x] Source tiers identified for all claims
- [x] Replication status addressed (MAST replicated via 7 frameworks; Bholani not replicated)
- [x] Open questions section planned
- [x] Serendipitous connections identified (Preference Sort / Bradley-Terry for recovery path ranking)
- [x] No fabricated citations — all URLs actually fetched
- [x] Effect sizes noted (93% LLM call reduction, 72.4% cost reduction, kappa=0.88)
- [x] Personal project connection: RecoveryRouter directly IS the project
