# Plan: Sycophancy Detection in Council Deliberation — Research Report #129

## Status: RESEARCH COMPLETE — Ready to write final report

## Output file
`/data/massimiliano/docs/research/sycophancy-detection-129.md`

## Research completed (all searches done, sources validated)

### Paper Validation Results

1. **Pitre et al. "CONSENSAGENT"** — VALIDATED
   - Venue: ACL 2025 Findings (NOT main conference)
   - DOI: 10.18653/v1/2025.findings-acl.1141
   - Authors: Priya Pitre, Naren Ramakrishnan, Xuan Wang (Virginia Tech)
   - 11 citations. Claims SOTA on 6 benchmark reasoning datasets across 3 models.
   - First work to systematically study sycophancy in multi-agent LLM systems.
   - Dynamic prompt refinement based on agent interactions.

2. **Vennemeyer et al. "Sycophancy Is Not One Thing"** — VALIDATED
   - arXiv: 2509.21305, published Sept 2025
   - Venue: EMNLP 2025 (main conference, confirmed on accepted papers list)
   - Authors: Daniel Vennemeyer, Phan Anh Duong, Tiffany Zhan, Tianyu Jiang (Cincinnati NLP Group)
   - 3 citations. Key finding: sycophantic agreement and sycophantic praise are distinct in latent space, independently steerable.
   - NOT "3 types" — 2 sycophantic behaviors + genuine agreement = 3 behaviors total.

3. **NeurIPS 2024 collusion paper** — FOUND
   - "Secret Collusion among AI Agents: Multi-Agent Deception via Steganography"
   - Motwani, Baranchuk, Strohmeier, Bolina, Torr, Hammond, Schroeder de Witt
   - NeurIPS 2024, 63-73 citations, 4 influential
   - About steganographic collusion, not groupthink per se. Tangentially relevant.

### New Papers Found

4. **"Inducing Disagreement in Multi-Agent LLM Executive Teams: Only the Devil's Advocate Works"**
   - TMLR 2026 (Feb 2026)
   - KEY FINDING: Devil's Advocate achieves 99.2% disagreement vs 48.3% baseline.
   - "Soft" techniques (role framing, dissent instructions) statistically indistinguishable from baseline.
   - Devil's Advocate produces "inauthentic dissent" — 4.9% of agents recommend options they privately rate lower.
   - 480 team decisions, 1920 individual responses, 20 business scenarios, 4-agent teams.

5. **"Peacemaker or Troublemaker: How Sycophancy Shapes Multi-Agent Debate"**
   - arXiv: 2509.23055, Sept 2025
   - First formal definition of sycophancy specific to multi-agent debate settings (MADS).
   - New metrics for agent sycophancy level and impact on information exchange.
   - Investigates centralized vs decentralized debate frameworks.
   - Yao, Shang, Du, He, Lian, Zhang, Su, Swamy, Qi

6. **"Encouraging Divergent Thinking in LLMs through Multi-Agent Debate" (MAD)**
   - Liang et al., EMNLP 2024, 1002 citations (seminal)
   - Identifies "Degeneration-of-Thought" (DoT) problem.
   - MAD framework with judge managing debate process.
   - Finding: LLMs may not be a fair judge if different LLMs are used.

7. **"MAEBE: Multi-Agent Emergent Behavior Framework"**
   - Erisken et al., arXiv 2506.03053, ICML 2025 workshop submission
   - Ensembles exhibit peer pressure influencing convergence even with supervisor.
   - Moral reasoning of ensembles NOT predictable from isolated agent behavior.

8. **Chiang et al. "Enhancing AI-Assisted Group Decision Making through LLM-Powered Devil's Advocate"**
   - IUI 2024, 138 citations
   - LLM devil's advocate in human group deliberation improves decision accuracy.

9. **Lee et al. "AI-Mediated Devil's Advocate System for Inclusive Group Decision-Making"**
   - CHI 2025, 16 citations

10. **"How RLHF Amplifies Sycophancy"** — Benade, arXiv 2602.01002, Jan 2026

11. **LLM-as-Judge bias literature**:
    - Position bias, self-enhancement bias, verbosity bias (12 bias types in CALM framework)
    - Shi et al. "A Systematic Study of Position Bias in LLM-as-a-Judge" (2025, 156 citations)

12. **"Voting or Consensus? Decision-Making in Multi-Agent Debate"** — arXiv 2502.19130

13. **"Multi-Agent Risks from Advanced AI"** — Hammond et al., 127 citations
    - Taxonomy: miscoordination, conflict, collusion

14. **"Deliberative Dynamics and Value Alignment in LLM Debates"** — arXiv 2510.10002

15. **"Multi-LLM Debate: Framework, Principals, and Interventions"** — NeurIPS 2024

16. **SycEval** — Fanous et al., AIES 2025
    - Sycophancy in 58.19% of cases. Persistence: 78.5%.

17. **"From Yes-Men to Truth-Tellers" (Pinpoint Tuning)** — Chen et al., ICML 2024
    - SPT tunes <5% of modules to mitigate sycophancy.

## Implementation plan

When exiting plan mode:
1. Write complete report to `/data/massimiliano/docs/research/sycophancy-detection-129.md`
2. Use Template A (Survey) structure
3. Include all validated/found papers with tier labels
4. Answer all 4 key questions with evidence
5. Provide assessment of the 3 detection signals + missing signals
6. Include serendipitous connections section
