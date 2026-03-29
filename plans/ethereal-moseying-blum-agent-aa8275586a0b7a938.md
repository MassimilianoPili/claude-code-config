# Plan: Research #131 Cross-Plan Meta-Learning

## Status: RESEARCH COMPLETE, READY TO WRITE OUTPUT

## Research Summary

All searches completed. Key findings:

### Paper Validations
1. **MAML (Finn et al.)**: CONFIRMED - ICML 2017, 13,957 citations, 2,660 influential. Correct venue/year.
2. **SUPER**: NOT by "Wang et al." -- actually by **Bogin et al. 2024**, EMNLP 2024, 34 citations. It's a benchmark for evaluating agents on setting up/executing tasks from research repos. NOT about task decomposition per se.

### Key New Papers Found
1. **AgentReuse** (Li, Wu, Tan 2024/2025) - arXiv:2512.21309 - Direct hit: plan reuse mechanism for LLM agents using intent classification. 93% reuse rate, 93% latency reduction.
2. **Voyager** (Wang et al. 2023) - NeurIPS 2023 spotlight - Skill library pattern: ever-growing executable code library for embodied agents.
3. **Reflexion** (Shinn et al. 2023) - NeurIPS 2023 - Verbal reinforcement learning from agent failures.
4. **ETO** (Song et al. 2024) - ACL 2024 - Exploration-based Trajectory Optimization using contrastive learning on failure/success trajectory pairs.
5. **STeCa** (Wang et al. 2025) - ACL 2025 Findings - Step-level trajectory calibration.
6. **Plan Library Maintenance** (Gerevini et al. 2023) - JAIR - Formal framework for maintaining plan libraries in case-based planning.
7. **LLM-Planner** (Song et al. 2022) - Few-shot grounded planning for embodied agents using LLMs.
8. **AutoAgent** (Wang et al. 2026) - Evolving cognition with skill library + elastic memory.
9. **SE-Agent** (Guo et al. 2025) - AAAI 2025 - Self-evolution via trajectory optimization, hybrid trajectories from different paths.
10. **Lifelong Robot Library Learning** (Tziafas & Kasaei 2024) - IEEE ICRA 2024 - Experience memory + skill library bootstrapping.
11. **Odyssey** (Liu et al. 2024) - Extends Voyager with open-world skill library + efficient retrieval.
12. **TerminalTraj** (Wu et al. 2026) - Large-scale terminal agentic trajectory generation.
13. **Survey: LLM Agent Trajectory Analysis** (Wang et al. 2025) - 42 papers on trajectory analysis for agents.
14. **Han et al. 2025** - GED-based clustering for dataflow DAG similarity (stream processing, but methodology transferable).
15. **Case-Based Planning survey** (Spalzzi 2001) - Classical survey on CBP.
16. **PlanGenLLMs** (Wei et al. 2025) - ACL 2025 - Comprehensive survey of LLM planning capabilities.

### Key Answers to Research Questions
1. MAML relevance: LIMITED. MAML is gradient-based meta-learning for model adaptation. PlanArchetypeRegistry is retrieval-based (CBR + embedding similarity). More analogous to CBR + few-shot prompting.
2. State-of-the-art: Voyager skill library + AgentReuse plan reuse + ETO trajectory learning.
3. Archetype quality: Need multi-dimensional (success rate + adaptation cost + coverage + IRT difficulty alignment).
4. Graph similarity: GED is NP-hard. Better alternatives: graph kernels (WL kernel), embedding-based (GNN), or hybrid structural+semantic approaches.

## Action: Write to /data/massimiliano/docs/research/meta-learning-131.md
