# Plan: AI Coding Agents Research Report (2025-2026)

## Status: COMPLETE. Report written to `/data/massimiliano/docs/research/ai-coding-agents-2025-2026.md`.

## DBLP Cross-Check Results (Gate 2 -- COMPLETE)

| # | Paper | arXiv | Venue (claimed) | DBLP Result |
|---|-------|-------|-----------------|-------------|
| 1 | SWE-bench Goes Live! | 2505.23419 | CoRR (preprint) | DBLP: CONFIRMED `journals/corr/abs-2505-23419` |
| 2 | SWE-ABS | 2603.00520 | arXiv preprint | DBLP: N/A (2026-02, too recent for indexing) |
| 3 | UTBoost | 2506.09289 | ACL 2025 | DBLP: CONFIRMED `conf/acl/YuZHK25` -- ACL pp.3762-3774 |
| 4 | SWE-rebench | 2505.20411 | NeurIPS 2025 | DBLP: CoRR only `journals/corr/abs-2505-20411`. Venue correction: paper claims NeurIPS 2025 but DBLP shows CoRR only. |
| 5 | SWE-Gym | 2412.21139 | ICML 2025 | DBLP: CONFIRMED `conf/icml/Pan0NJ0S025` -- ICML 2025 |
| 6 | Saving SWE-Bench | 2510.08996 | CAIN 2026 | DBLP: CoRR only `journals/corr/abs-2510-08996`. Paper states "Accepted at CAIN 2026" -- camera-ready version. DBLP may not yet index CAIN 2026. |
| 7 | ToolRet | 2503.01763 | ACL 2025 | DBLP: CONFIRMED `conf/acl/ShiWYRWYR25` -- ACL Findings pp.24497-24524 |
| 8 | PROV-AGENT | 2508.02866 | IEEE e-Science 2025 | DBLP: CONFIRMED `conf/eScience/0001GDRGRBS25` -- eScience pp.467-473 |
| 9 | POLARIS | 2601.11816 | AAAI 2026 Workshop | DBLP: N/A (workshop paper, unlikely indexed) |
| 10 | TRAIL | 2505.08638 | arXiv preprint | DBLP: CoRR only `journals/corr/abs-2505-08638` |
| 11 | Architectures for Agentic AI | 2512.09458 | Springer chapter | DBLP: CoRR only `journals/corr/abs-2512-09458`. Book chapter may not yet be indexed. |
| 12 | Memory-as-a-Tool | 2601.05960 | ICLR 2026 Workshop | DBLP: N/A (workshop paper) |
| 13 | MIRA | 2602.17930 | ICLR 2026 | DBLP: N/A (not yet indexed, Feb 2026 preprint) |
| 14 | Agentless | 2407.01489 | 2024 preprint | DBLP: CONFIRMED `journals/corr/abs-2407-01489`. Note: CoRR only, no peer-reviewed venue on DBLP yet. |
| 15 | OrcaLoca | 2502.00350 | ICML 2025 | DBLP: CONFIRMED `conf/icml/YuZZHYDZ25` -- ICML 2025 |
| 16 | Live-SWE-agent | 2511.13646 | 2025 preprint | DBLP: CoRR only `journals/corr/abs-2511-13646` |
| 17 | Int'l AI Safety Report 2026 | 2602.21012 | Report | DBLP: N/A (multi-stakeholder report, not CS venue) |
| 18 | 2025 AI Agent Index | 2602.17753 | MIT report | DBLP: N/A (technical report) |
| 19 | Understanding Multi-Agent Frameworks | 2602.03128 | arXiv preprint | DBLP: N/A (preprint, Feb 2026) |
| 20 | Qwen3-coder-next | 2603.00729 | tech report | DBLP: N/A (industry tech report) |
| 21 | OmniCode | 2602.02262 | arXiv preprint | DBLP: N/A (preprint, Feb 2026) |
| 22 | CodeWatcher | 2510.11536 | ICSME 2025 | DBLP: CONFIRMED `conf/icsm/BashaRJSR25` -- ICSME pp.935-939 |
| 23 | LangGraph+CrewAI | 2411.18241 | arXiv preprint | DBLP: N/A (preprint) |
| 24 | AgentForge | 2601.13383 | arXiv preprint | DBLP: N/A (preprint, Jan 2026) |
| 25 | Agentic AI Survey | -- | Artif. Intell. Rev. | DBLP: CONFIRMED `journals/air/AliDC26` -- Artif. Intell. Rev. 59(1):11, 2026 |
| 26 | MAEBE | 2506.03053 | ICML 2025 Workshop | DBLP: N/A (workshop paper) |
| 27 | SWE-Pruner | 2601.16746 | arXiv preprint | DBLP: N/A (preprint, Jan 2026) |
| 28 | Security/Privacy Agentic AI | 2603.18914 | Symposium 2026 | DBLP: N/A (symposium, Mar 2026) |
| 29 | Trustworthy Agentic Lakehouse | 2511.16402 | AAAI 2026 Workshop | DBLP: N/A (workshop) |
| 30 | CVE-Bench | -- | NAACL 2025 | DBLP: CONFIRMED `conf/naacl/WangLX25a` -- NAACL pp.4207-4224. **Venue correction**: S2 did not specify venue; DBLP confirms NAACL 2025 |
| 31 | Agent Data Protocol | 2510.24702 | 2025 preprint | DBLP: CoRR only `journals/corr/abs-2510-24702` |

### DBLP Summary
- **CONFIRMED at peer-reviewed venue**: 9 papers (#1,#3,#5,#7,#8,#15,#22,#25,#30)
- **CoRR only (preprint)**: 7 papers (#4,#6,#10,#11,#14,#16,#31)
- **N/A (too recent / workshop / report)**: 15 papers (#2,#9,#12,#13,#17-21,#23,#24,#26-29)
- **Venue corrections needed**: #4 (NeurIPS claim -- DBLP shows CoRR only), #30 (NAACL confirmed)

## Algorithmic Correctness Section (Gate 3 -- COMPLETE)

This is a survey/landscape report (Template A), not a design validation (Template F). The following algorithmic claims in cited papers were checked for precondition correctness:

| Algorithm/Method | Paper | Used For | Preconditions | Assessment |
|-----------------|-------|----------|---------------|------------|
| Program slicing + mutation testing | SWE-ABS (#2) | Adversarial test augmentation | Executable test suites, Python source | Appropriate -- SWE-Bench Verified is Python with executable tests |
| Neural skimmer (0.6B params) | SWE-Pruner (#27) | Context compression for coding agents | Task-aware pruning of code context | Appropriate -- trained on code, evaluated on SWE-Bench |
| BM25 + dense retrieval | ToolRet (#7) | Tool retrieval from 43K tool corpus | Standard IR assumptions (bag-of-words / embedding similarity) | Finding: precondition VIOLATED -- tool descriptions have different structural properties than documents. Paper correctly identifies this as a fundamental limitation |
| DQN with utility-based advantage shaping | MIRA (#13) | Memory-guided RL agent | Sparse reward MDP, utility term decay | Appropriate -- coding tasks have sparse rewards (pass/fail tests) |
| Git worktree isolation | Claude Code / Codex | Parallel agent work on same repo | Git repository, clean working state | Appropriate -- standard assumption for software projects |
| DAG-based typed plan synthesis | POLARIS (#9) | Enterprise back-office automation | Well-typed tool schemas, validator availability | Appropriate -- enterprise tools have typed APIs |
| W3C PROV extension | PROV-AGENT (#8) | Agent provenance tracking | MCP-compatible tool calls, structured agent actions | Appropriate -- MCP provides structured tool call records |

**No algorithmic mismatches found.** ToolRet identifies an important negative result (IR models fail at tool retrieval) but this is a research finding, not a misapplication.

## Execution Plan

### Step 1: Write final report
Write `/data/massimiliano/docs/research/ai-coding-agents-2025-2026.md` with:
- Full 11-section survey content (already drafted, blocked by validation)
- DBLP verification column in every paper table
- Algorithmic Correctness section (content above)
- Venue corrections inline (#4 NeurIPS claim flagged, #30 NAACL confirmed)

The report will include:
1. Claude Code advances (2025-2026) -- timeline, features, revenue data
2. Anthropic Agent SDK -- patterns, MCP, sub-agent spawning
3. Competing AI coding agents -- Claude Code vs Codex vs Cursor market comparison
4. Academic papers on coding agents -- SWE-bench family, new benchmarks
5. Multi-agent orchestration -- LangGraph vs CrewAI vs AutoGen with academic benchmark
6. Tool use in LLMs -- ToolRet (ACL 2025), ADP
7. Code generation evaluation -- benchmark inflation (SWE-ABS), saturation
8. Self-improving agents -- Memory-as-Tool, MIRA, Live-SWE-agent
9. Claude model family -- Opus/Sonnet 4.6, 1M context, competitive position
10. Agentic IDE patterns -- terminal-first vs IDE-integrated vs hybrid
11. Safety in agentic coding -- PROV-AGENT, POLARIS, AI Agent Index, audit trails

Plus: Serendipitous Connections, What to Read Next, Knowledge Graph Candidates, Sources

### Step 2: Verify hook passes
The report must satisfy:
- Gate 2: DBLP cross-check present (done -- every paper has DBLP status)
- Gate 3: Algorithmic Correctness section present (done -- table above)

### Estimated size: ~500 lines markdown
