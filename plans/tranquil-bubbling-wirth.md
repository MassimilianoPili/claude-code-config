# Piano: Agent Framework — S25: Ricerca Accademica Fase 15

## Context

**Fase 15 progettata in S24**: 10 item (#127-#136), tema "Reflective Intelligence & Decision Transparency", documentati in `research-domains-ext.md` (§66-§75) e `PIANO.md`. Ogni item cita 2-3 paper fondativi ma non sono ancora stati validati. Stesso pattern di S24 per Fase 14: lanciare academic-researcher agents per validare paper, trovare insight, e correggere il design.

**Obiettivo**: validare i ~20 paper citati, trovarne di nuovi, identificare correzioni al design.

---

## Paper da validare per item

| # | Item | Paper citati | Query chiave |
|---|------|-------------|-------------|
| 127 | Process Reward Model | MAgICoRe (EMNLP 2025), DDI (Sci.Reports 2025), Huang (ICLR 2024) | process reward models, outcome vs process supervision, LLM self-correction verification |
| 128 | Explainable Decision Trace | SHAP (NeurIPS 2017), LIME (KDD 2016) | explainability for multi-component AI decisions, decision trace aggregation |
| 129 | Sycophancy Detection | CONSENSAGENT (ACL 2025), Vennemeyer 2025, NeurIPS 2024 collusion | sycophancy detection multi-agent, groupthink mitigation, LLM consensus pathology |
| 130 | Recovery Router | Bholani "Self-Healing Router" (2026), MAST (NeurIPS 2025) | self-healing multi-agent, graph-based failure recovery, tool routing |
| 131 | Meta-Learning | MAML (ICML 2017), SUPER (2023) | meta-learning task decomposition, plan archetype reuse, few-shot planning |
| 132 | Pareto Optimizer | Sener & Koltun (NeurIPS 2018), Ehrgott (2005) | multi-objective LLM dispatch, quality-cost Pareto, token budget optimization |
| 133 | AUDIT Dual-Mode | AutoCodeRover (ICSE 2025), SWE-Agent (2024) | pre-planning context analysis, repository understanding for code generation |
| 134 | IDS | Russo & Van Roy (NeurIPS 2014 / OR 2018) | information-directed sampling, GP bandit exploration, IDS vs Thompson Sampling |
| 135 | Sandbox | SWE-bench (ICLR 2024), gVisor/Firecracker | execution-based evaluation, sandboxed code execution, container security isolation |
| 136 | Bayesian Surprise | Itti & Baldi (2009), Schmidhuber (2010) | Bayesian surprise anomaly detection, KL divergence monitoring, novelty vs anomaly |

## Batch di ricerca (3 round, 3-4 agents ciascuno)

### Batch A (4 agents paralleli): #127, #128, #129, #130
- **#127 PRM**: validare MAgICoRe, DDI, Huang. Cercare: ORM vs PRM (Lightman 2023), Math-Shepherd, GenRM. Focus: come usare PRM senza training dedicato (GP posterior come proxy).
- **#128 Decision Trace**: SHAP/LIME sono classici. Cercare: explainability per sistemi multi-componente (non solo singolo modello), chain-of-thought attribution, decision provenance in multi-agent.
- **#129 Sycophancy**: validare CONSENSAGENT, Vennemeyer. Cercare: sycophancy in multi-agent deliberation (non solo human-LLM), entropy-based detection, devil's advocate injection efficacy.
- **#130 Recovery Router**: validare Bholani (2026 — potrebbe non esistere). Cercare: self-healing agent systems, graph-based routing failure recovery, MAST failure taxonomy application.

### Batch B (3 agents paralleli): #131, #132, #133
- **#131 Meta-Learning**: MAML è classico. Cercare: meta-learning per task decomposition (non solo model adaptation), plan reuse in software engineering, case-based reasoning for planning.
- **#132 Pareto**: Sener & Koltun è classico. Cercare: multi-objective optimization in LLM systems, quality-cost tradeoff, token-aware routing, FrugalGPT-like approaches.
- **#133 AUDIT Dual-Mode**: validare AutoCodeRover, SWE-Agent. Cercare: repository-level understanding before code generation, pre-planning analysis, Agentless (Xia 2024).

### Batch C (3 agents paralleli): #134, #135, #136
- **#134 IDS**: Russo & Van Roy è foundational. Cercare: IDS in practice, IDS vs TS vs UCB empirical comparison, IDS con GP posterior, finite-time regret bounds.
- **#135 Sandbox**: SWE-bench è classico. Cercare: sandboxed execution for LLM-generated code, security isolation patterns (gVisor vs Firecracker vs seccomp), execution-based evaluation beyond SWE-bench.
- **#136 Bayesian Surprise**: Itti & Baldi è classico. Cercare: Bayesian surprise in online learning, KL monitoring for concept drift, surprise + reward classification (novelty vs anomaly).

## Post-ricerca

1. Consolidare findings per item (come S24)
2. Identificare correzioni al design
3. Scrivere sintesi in PIANO.md
4. (Opzionale) Aggiornare §66-§75 in research-domains-ext.md con nuovi riferimenti

## File critici

- `PIANO.md` — destinazione sintesi ricerca Fase 15
- `docs/agent-framework/research-domains-ext.md` — §66-§75, eventuali aggiornamenti

## Verifica

- 10 item ricercati con paper validati
- Correzioni al design identificate e documentate
- Connessioni trasversali aggiornate
