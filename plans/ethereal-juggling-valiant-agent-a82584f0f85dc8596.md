# Novelty Check: Preference-Aware Task Scheduling for Human-Agent Collaboration using Bradley-Terry Models with Active Elicitation

**Date**: 2026-03-18
**Epistemic status**: Thorough search completed across Semantic Scholar, arXiv, Google Scholar, PubMed. No exact prior art found. Assessment is high-confidence for the "no subsumption" claim.
**Confidence**: High -- multiple orthogonal searches converged on the same gap.

---

## A) "Bradley-Terry + Task Queue Scheduling" -- Does any paper combine BT with task queue scheduling?

### Finding: ONE paper exists, but it is NOT a threat.

**Jabeen & Shanavas (2025)** -- "Bradley Terry Brownboost and Lemke flower pollinated resource efficient task scheduling in cloud computing" (T1 -- *The Scientific Temper*, 0 cit S2)

This paper uses Bradley-Terry as a **classifier** to categorize cloud tasks into high/low priority bins, then applies a swarm intelligence optimizer (Lemke flower pollination) for VM assignment. It is:
- Cloud computing resource scheduling, not human task prioritization
- BT used for binary classification, not iterative ranking from human pairwise comparisons
- No active elicitation, no human-in-the-loop, no persistent queue
- Published in a low-impact journal (The Scientific Temper), 0 citations
- **Verdict: Not a novelty threat.** The combination is superficially similar (BT + scheduling) but the mechanism and purpose are entirely different.

**All other BT papers** found are about: sports ranking, journal ranking, image quality assessment, education assessment, or RLHF for LLM alignment. None apply BT to a durable task queue with human-driven pairwise comparisons determining execution order for AI agents.

### Sub-verdict A: **Novel combination. No prior work combines BT with a persistent human-facing task queue.**

---

## B) "Human-in-the-loop + Pairwise Preferences + Agent Task Ordering" -- Does any agentic system use pairwise human preferences for task ordering?

### Finding: No.

The closest results:
1. **He & Lim (2026)** -- "From Control to Foresight: Simulation as a New Paradigm for Human-Agent Collaboration" (CHI 2026 Workshop, arXiv:2603.11677). Proposes simulation-in-the-loop for human-agent collaboration. The human explores trajectories but does NOT rank tasks via pairwise comparisons. It is a perspective paper, not a system.

2. **Khan (2025)** -- "Leveraging AI for Agile Backlog Management Using LLMs" (NCI Ireland thesis). Uses LLMs for backlog refinement and prioritization but via direct LLM scoring, not pairwise human comparison. No BT model. Master's thesis, not peer-reviewed.

3. **Tanveer (undated)** -- "DualPhase-SchedNet: Cooperative Metaheuristic Scheduling via Multi-Agent Adaptive Phases." Mentions "interactive preference learning" as future work only. No implementation.

4. **Chun et al. (2003)** -- "Optimizing agent-based meeting scheduling through preference estimation" (T1 -- *Engineering Applications of AI*). Uses agent-based meeting scheduling with average preference levels, but NOT pairwise comparison, NOT BT, and it is about meeting time slots, not task prioritization.

### Sub-verdict B: **Novel. No agentic system uses pairwise human preferences (BT or otherwise) for task execution ordering.**

---

## C) "Active Preference Elicitation + Scheduling" -- Defresne et al. 2025

### Finding: Defresne is the CLOSEST prior work, but does NOT subsume the contribution.

**Defresne, Mandi & Guns (2025)** -- "Preference Elicitation for Multi-objective Combinatorial Optimization with Active Learning and Maximum Likelihood Estimation" (T1 -- IJCAI 2025, 0 cit S2)

What they do:
- MLE of a Bradley-Terry preference model for multi-objective combinatorial optimization
- Active pair selection via ensemble-based acquisition function
- Applied to PC configuration and multi-instance routing problems

What they do NOT do:
- No persistent task queue or durable state
- No scheduling component -- they solve a STATIC optimization problem (find the best configuration)
- No human-agent collaboration loop -- users compare but agents don't execute tasks
- No prior washout mechanism (they don't handle transitioning from numeric priorities)
- No SE-based scheduling confidence

**Critical difference**: Defresne solves a one-shot optimization problem ("find the best solution to a combinatorial problem by eliciting preference weights"). Your system solves a DYNAMIC scheduling problem ("continuously rank and re-rank a changing set of tasks, deciding WHEN to schedule based on confidence, while agents execute and tasks arrive/complete").

### Other relevant active elicitation papers:

- **Vayanos et al. (2020)** -- "Robust Active Preference Elicitation" (arXiv:2003.01899, math.OC). Pairwise queries for resource allocation (kidney transplants, housing). Uses robust optimization, NOT BT. One-shot recommendation, no persistent queue, no agent execution.

- **Maystre & Grossglauser (2015)** -- "Just Sort It!" (T1 -- ICML 2015, 55 cit S2). Active preference learning via sorting algorithms + BT. Theoretical contribution on sample complexity. No scheduling, no persistence, no agent integration.

- **Li et al. (2018)** -- "Hybrid-MST" (T1 -- NeurIPS 2018). BT + Expected Information Gain for pair selection in subjective quality assessment. Your information-gain pair selection is well-established in THIS domain (image/video quality) but novel when applied to task scheduling.

### Sub-verdict C: **Defresne is the closest methodological ancestor but addresses a fundamentally different problem (static combinatorial optimization vs. dynamic task scheduling). You MUST cite Defresne but your contribution is NOT subsumed.**

---

## D) "RLHF Applied to Task Scheduling" (not LLM output ranking)

### Finding: No. RLHF has NOT been applied to task scheduling.

Every single RLHF paper found (>20 results) is about:
- Aligning LLM text output with human preferences
- Reward model training for language generation
- Policy optimization for response quality

**Zero papers** apply the RLHF framework (human pairwise comparisons -> BT reward model -> policy optimization) to the problem of deciding which task to execute next. The DRL-for-scheduling literature (e.g., "Hybrid Task Scheduling in Cloud Manufacturing with Sparse-Reward DRL") uses reinforcement learning but with engineered reward functions, not human preference feedback.

This is a genuine conceptual gap. The RLHF community has built sophisticated preference learning machinery but has never turned it "outward" to schedule real-world tasks rather than "inward" to rank model outputs.

### Sub-verdict D: **Novel application domain for preference-based learning. This is a strong framing angle for the paper: "RLHF-style preference learning, but for task scheduling instead of LLM alignment."**

---

## E) Best Venue Analysis

### Audience fit matrix:

| Venue tier | Venue | Fit | Why |
|------------|-------|-----|-----|
| **Top pick** | **CHI 2027** (or CHI LBW) | HIGH | Human-agent collaboration + preference elicitation + system design. CHI audience cares about HOW humans interact with AI agents. The pairwise comparison UI, cognitive load, prior washout are HCI contributions. |
| Strong | **CSCW 2027** | HIGH | Computer-Supported Cooperative Work: human + AI agent collaboration on shared task queues. |
| Strong | **IUI 2027** | HIGH | Intelligent User Interfaces: the adaptive elicitation interface IS the contribution from this angle. |
| Good | **NeurIPS FMDM Workshop** | MEDIUM | Foundation Models + Decision Making. Methodologically relevant but workshop paper only. |
| Good | **AAAI HCOMP** | MEDIUM-HIGH | Human Computation: humans providing preference labels for a computational pipeline. Strong fit. |
| Possible | **ICSE/FSE/ASE** | LOW-MEDIUM | SE venues care about developer tools but the BT/active-learning contribution is too mathematical for SE reviewers. Would need heavy systems evaluation (user study with developers). |
| Possible | **AAMAS** | MEDIUM | Autonomous Agents: the agent scheduling component fits. But the human preference loop is the novel part, not the agent side. |
| Long shot | **IJCAI/AAAI** (main) | LOW | Too systems-oriented for a pure AI venue. Would need stronger theoretical contribution (regret bounds, convergence guarantees). |

### Recommendation:
**Primary target: CHI 2027** (full paper or case study). Secondary: CSCW or IUI. Workshop: NeurIPS FMDM or AAAI HCOMP.

The reason is simple: the novelty is in the INTERACTION DESIGN (humans doing pairwise comparisons to steer agent task execution), not in the algorithm (BT + information gain are established). CHI/CSCW/IUI reviewers will value the system design and the human factors; ML venues will ask "where are your regret bounds?" and you would need substantial theoretical work to satisfy them.

---

## F) Honest Assessment: Full Paper vs. Workshop vs. Demo

### Full paper (CHI / CSCW / IUI)

**What you have:**
- Novel system combining BT, active elicitation, persistent queue, agent integration
- Working implementation (Preference Sort on SOL)
- Dual-write persistence, prior washout, SE-based scheduling confidence

**What you need for a full paper:**
1. **User study** (MANDATORY for CHI/CSCW). At minimum N=12-15 participants doing pairwise comparisons on a real task backlog, compared against baseline (manual ordering, numeric priority). Measure: task completion rate, satisfaction, cognitive load (NASA-TLX), time-to-first-useful-schedule.
2. **Comparison against baselines**: at minimum (a) FIFO, (b) numeric priority, (c) random pair selection (to show information gain helps), (d) full enumeration (to show active elicitation reduces queries).
3. **Analysis of prior washout convergence**: how many comparisons until BT ranking dominates over the numeric prior? Empirical + possibly analytic bounds.
4. **Scale analysis**: how does the system behave with 10 tasks? 50? 200? Where does O(n^2) pair space become impractical?

**Effort estimate**: 3-5 months additional work (user study design, IRB if academic, data collection, analysis, writing).

### Workshop paper (NeurIPS FMDM, AAAI HCOMP, CHI Workshop)

**What you need:**
1. Compelling system description (you already have this)
2. Simulation study showing BT + information gain converges faster than random pair selection
3. One or two case studies of real usage (your own usage of the system counts)
4. Clear positioning against Defresne et al. and the RLHF literature

**Effort estimate**: 3-6 weeks. This is the REALISTIC near-term target.

### Systems demo (CHI Interactivity, UIST Demo, CSCW Demo)

**What you need:**
1. Polished working demo (you have the system running)
2. 2-4 page paper describing the interaction design
3. Video showing the pairwise comparison flow and agent execution

**Effort estimate**: 2-3 weeks. Lowest bar, but also lowest impact.

---

## Summary Novelty Assessment

| Claim | Novel? | Confidence | Nearest prior work |
|-------|--------|------------|-------------------|
| BT for task queue scheduling | YES | High | Jabeen 2025 (superficial overlap only) |
| Pairwise human preferences for agent task ordering | YES | High | Nothing found |
| Active elicitation (info gain) for scheduling | YES (in this domain) | High | Defresne IJCAI 2025 (static optimization, not scheduling) |
| Prior washout (numeric -> BT transition) | YES | High | No prior art found |
| SE-based scheduling confidence | YES | High | No prior art found |
| RLHF-style preference learning for task scheduling | YES (framing) | High | All RLHF is for LLM alignment |

**Overall verdict: The combination is genuinely novel.** No single paper subsumes the contribution. The individual components (BT, information gain, active elicitation) are well-established, but their application to persistent human-agent task scheduling with a durable queue is new.

**Strongest novelty angle**: "We bring RLHF-style preference learning out of the LLM alignment setting and into real-world task scheduling for human-agent collaboration."

**Weakest point**: The algorithmic contribution is modest (applying known techniques to a new domain). This is why HCI venues (CHI, CSCW, IUI) are better fits than ML venues -- they value the system and interaction design, not novel algorithms.

---

## Recommended Next Steps

1. **Write the workshop paper first** (NeurIPS FMDM or AAAI HCOMP deadline). This forces you to crystallize the positioning.
2. Run a **simulation study**: synthetic task arrivals, BT convergence analysis, comparison of pair selection strategies (information gain vs. random vs. uncertainty sampling).
3. If workshop is accepted, **design the user study** for a CHI 2027 full paper submission (September 2026 deadline).
4. **Must-cite papers**: Defresne et al. IJCAI 2025, Maystre & Grossglauser ICML 2015, Li et al. NeurIPS 2018 (Hybrid-MST), Vayanos et al. 2020, Das et al. ECML 2024 (Active Preference Optimization).

---

## Sources Fetched

| Source | Tier | Role |
|--------|------|------|
| Jabeen & Shanavas 2025, *The Scientific Temper* | T3 (low-tier journal) | Only BT+scheduling paper found |
| Defresne, Mandi & Guns 2025, IJCAI | T1 | Closest methodological ancestor |
| Maystre & Grossglauser 2015, ICML | T1 | Active BT learning foundations |
| Li et al. 2018, NeurIPS | T1 | BT + EIG pair selection |
| Vayanos et al. 2020, arXiv:2003.01899 | T2 | Robust active preference elicitation |
| Das et al. 2024, ECML/PKDD | T1 | Active Preference Optimization (RLHF) |
| He & Lim 2026, CHI Workshop | T2 | Human-agent collaboration paradigm |
| Fageot et al. 2023, arXiv:2308.08644 | T2 | Generalized BT models (MAP properties) |
| Li & Zhao 2025, IEEE Trans. Info. Theory | T1 | Globally-optimal greedy active sequential estimation for BT |
| Gray et al. 2025, SSRN | T3 | Bayesian active learning for comparative judgment |
| Khan 2025, NCI Ireland thesis | T7 | LLM backlog management (not peer-reviewed) |
