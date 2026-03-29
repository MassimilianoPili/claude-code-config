# Research: Agent Orchestration Frameworks and Multi-Agent Patterns for Claude Code

## Research Summary

**Epistemic status:** Active, fast-moving ecosystem (< 6 months old for most frameworks)
**Confidence:** Medium -- based on primary source READMEs and official docs actually fetched. Community projects, limited peer review.
**Sources fetched:** 12 GitHub READMEs, 1 blog article (byteiota), Anthropic official docs via Context7, awesome-claude-code curated list.

---

## 1. Agent Teams (Anthropic Official, Feb 2026)

**Source:** code.claude.com/docs/en/agent-teams (T7 -- official documentation, fetched via Context7)

### Architecture
- **Team lead**: the main Claude Code session that creates and coordinates the team
- **Teammates**: separate Claude Code instances, each with its own context window
- **Shared task list**: work items that teammates claim and complete; system auto-manages dependencies
- **Mailbox**: messaging system for inter-agent communication (`message` for point-to-point, `broadcast` for all)
- **Isolation**: each teammate loads the same project context (CLAUDE.md, MCP servers, skills) but does NOT receive the lead's conversation history

### Communication
- Automatic message delivery between agents
- Idle notifications when teammates finish
- Shared task list visible to all agents (status + claims)
- No shared memory beyond the task list and mailbox

### When to use (vs subagents)
- **Subagents**: focused tasks, independent work, report results back to main. More token-efficient.
- **Agent teams**: when teammates need to share findings, challenge each other, coordinate independently. Research with competing hypotheses, parallel code review, new feature dev with separate ownership.
- **Transition point**: when parallel subagents hit context limits or need to communicate.

### Worktree isolation
- Subagents can use `isolation: worktree` in frontmatter for dedicated git worktrees
- Worktrees auto-cleanup when no changes are made
- Agent teams use this for parallel codebase operations without conflicts

### Limitations
- Significant token overhead (each teammate has full context window)
- Best for independent parallel work; poor for sequential tasks or same-file edits
- No persistent state between team sessions (task lists stored locally, ephemeral)
- Requires Claude Code 2.1.32+

### Maturity: **HIGH** -- first-party Anthropic feature, production-ready

### Relevance to Agent Framework (Java/HTN)
**HIGH**. The task list + claim model maps directly to HTN task decomposition. Key patterns to adopt:
- Shared task list with dependency management (already in Agent Framework via task_graph)
- Mailbox pattern for agent-to-agent messaging (already have `claude_send`/`claude_read` in Redis)
- Worktree-equivalent isolation (could map to separate working directories or Docker containers)
- The "lead creates team, delegates, monitors" pattern is exactly HTN orchestration

---

## 2. AgentSys (avifenesh / agent-sh org)

**Source:** github.com/avifenesh/agentsys README (fetched directly)

### Architecture
- **19 plugins, 47 agents, 40 skills** across the agent-sh GitHub org
- AgentSys itself is the **marketplace and installer** -- plugins are standalone repos
- Each agent has: single responsibility, specific model assignment, defined inputs/outputs
- **Pipelines enforce phase gates** -- agents cannot skip steps
- **State persists across sessions** -- work survives interruptions

### Core Philosophy: "Code does code work. AI does AI work."
- **Detection** (regex, AST, static analysis): fast, deterministic, no tokens wasted
- **Judgment** (LLM calls): synthesis, planning, review -- where reasoning matters
- **Result**: 77% fewer tokens than pure multi-agent approaches

### Certainty Grading
| Level | Meaning | Action |
|-------|---------|--------|
| HIGH | Definitely a problem | Safe to auto-fix |
| MEDIUM | Probably a problem | Needs context |
| LOW | Might be a problem | Needs human judgment |

### Key Commands
- `/next-task`: full task-to-production (discovery -> worktree -> implementation -> review -> PR -> merge)
- `/audit-project`: multi-agent iterative code review
- `/drift-detect`: compare plan vs implementation
- `/deslop`: clean AI slop patterns
- `/repo-intel`: unified static analysis (git history, AST symbols, project metadata)

### Benchmarks (March 2026)
- Sonnet + AgentSys produced more output with higher specificity than raw Opus at **40% lower cost**
- "With agentsys, model tier matters less" -- the pipeline captures most gains

### Maturity: **HIGH** -- 30k lines of lib code, 3,583 tests, 5 platforms, npm-distributed

### Relevance to Agent Framework
**HIGH**. Several directly transferable patterns:
- **Certainty-graded findings** -- adopt for Agent Framework task validation outputs
- **Phase-gated pipelines** -- maps to HTN method preconditions
- **Deterministic detection + LLM judgment** -- the hybrid approach is ideal for the 378 MCP tools (use deterministic checks where possible, LLM only for judgment)
- **`/drift-detect` pattern** -- plan-vs-implementation drift detection applicable to HTN plan monitoring
- **`/repo-intel` pattern** -- pre-compute project metadata to enrich agent context (already have code_stats, code_list_symbols tools)

---

## 3. Claude Squad (smtg-ai)

**Source:** github.com/smtg-ai/claude-squad README (fetched directly)

### Architecture
- **Go terminal TUI** managing multiple Claude Code (or Codex, Gemini, Aider) instances
- Uses **tmux** for isolated terminal sessions per agent
- Uses **git worktrees** for codebase isolation per session
- Simple keyboard-driven interface: create sessions, navigate, review diffs, push branches

### Key Features
- `--autoyes` mode: auto-accept all prompts (YOLO mode)
- Background task execution: agents work while you review others
- Profile system: configure multiple AI assistants (claude, codex, aider)
- Diff view: review changes before applying
- PR integration via `gh` CLI

### How It Works
1. tmux creates isolated terminal sessions
2. git worktrees isolate codebases (each session = own branch)
3. TUI provides navigation and management

### Maturity: **MEDIUM-HIGH** -- actively maintained, Homebrew-installable, AGPL-3.0

### Relevance to Agent Framework
**MEDIUM**. The tmux + worktree pattern is a practical implementation detail, not an architectural pattern. However:
- The **session-per-task isolation** principle is important for the Agent Framework when spawning multiple agents
- The **profile system** (switching between AI backends) could inspire a provider-agnostic agent interface
- The **review-before-merge** pattern is relevant to Agent Framework's quality gates

---

## 4. Ruflo / Claude Flow (ruvnet)

**Source:** github.com/ruvnet/ruflo README (fetched directly, v3.5)

### Architecture
```
User -> Ruflo (CLI/MCP) -> Router -> Swarm -> Agents -> Memory -> LLM Providers
                        ^                          |
                        +---- Learning Loop <------+
```

- **100+ specialized agents** (coder, tester, reviewer, architect, security, etc.)
- **Q-Learning Router** + **MoE (8 Experts)** for intelligent task routing
- **130+ skills, 27 hooks**
- **Swarm Coordination**: 4 topologies (mesh, hierarchical, ring, star)
- **Consensus protocols**: Raft, BFT, Gossip, CRDT
- **Claims**: human-agent coordination

### RuVector Intelligence Layer
- SONA: Self-Optimizing Neural Architecture (routing optimization)
- EWC++: Elastic Weight Consolidation (prevents catastrophic forgetting)
- Flash Attention: 2.49-7.47x speedup
- HNSW: 150x-12,500x faster vector search
- 9 RL algorithms: Q-Learning, SARSA, PPO, DQN, etc.
- LoRA/Micro: 128x compression

### Self-Learning Loop
RETRIEVE -> JUDGE -> DISTILL -> CONSOLIDATE -> ROUTE (loops back to router)

### Maturity: **MEDIUM** -- ambitious scope, 6,000+ commits, WASM kernels in Rust, but "YMMV" per awesome-claude-code

### Relevance to Agent Framework
**MEDIUM-HIGH**. Several sophisticated patterns worth studying:
- **Q-Learning Router** -- adaptive task routing based on past performance; could enhance Agent Framework's task assignment
- **Swarm topologies** (mesh/hierarchical/ring/star) -- the Agent Framework currently assumes hierarchical; other topologies may be useful for specific task types
- **Consensus protocols** -- Raft/BFT for multi-agent agreement; relevant to Agent Framework if agents need to agree on shared state
- **Self-learning loop** -- the RETRIEVE->JUDGE->DISTILL->CONSOLIDATE->ROUTE cycle is a concrete implementation of retrospective learning; highly relevant to Agent Framework's `meta_record_outcome` / `meta_predict_agent` tools
- **CAUTION**: The scope is very broad. Risk of over-engineering. The Agent Framework should cherry-pick specific patterns rather than adopt the full architecture.

---

## 5. RIPER Workflow (tony / claude-code-riper-5)

**Source:** github.com/tony/claude-code-riper-5 README (fetched directly)

### Architecture
5 phases with strict capability restrictions:

| Mode | Read | Write | Execute | Plan | Validate |
|------|------|-------|---------|------|----------|
| RESEARCH | Yes | No | No | No | No |
| INNOVATE | Yes | No | No | No | No |
| PLAN | Yes | Memory only | No | Yes | No |
| EXECUTE | Yes | Yes | Yes | No | No |
| REVIEW | Yes | Memory only | Tests only | No | Yes |

### Key Design Decisions
- **3 consolidated agents** (not 5): research-innovate, plan-execute, review
- **Branch-aware memory bank**: separate memory per git branch
- **Mode enforcement**: prevents premature implementation before understanding
- Originated from anonymous "robotlovehuman" on Cursor Forums

### Memory Bank Structure
```
.claude/memory-bank/
+-- main/           # Main branch memories
|   +-- plans/      # Technical specifications
|   +-- reviews/    # Code review reports
|   +-- sessions/   # Session contexts
+-- [feature-branch]/  # Per-branch memories
```

### Maturity: **MEDIUM** -- 73 stars, clean design, MIT licensed, community-originated

### Relevance to Agent Framework
**HIGH**. The phase-restriction model maps perfectly to HTN planning:
- **Mode capabilities matrix** -- directly implementable as HTN operator preconditions (e.g., EXECUTE operator requires PLAN phase completed)
- **Branch-aware memory** -- the Agent Framework could namespace agent memory by task context (already have per-task state in task_graph)
- **Forced research-before-implementation** -- this is exactly the kind of discipline that HTN planning enforces via method ordering
- **Memory bank pattern** -- lightweight persistent state across sessions; simpler than full KORE but complementary to it

---

## 6. GSD -- Get Shit Done (glittercowboy / gsd-build)

**Source:** github.com/glittercowboy/get-shit-done README (fetched directly)

### Architecture
- **Spec-driven development system** solving "context rot" (quality degradation as context window fills)
- Works on Claude Code, OpenCode, Gemini CLI, Codex, Copilot, Cursor, Windsurf, Antigravity

### Workflow
```
/gsd:new-project -> /gsd:discuss-phase N -> /gsd:plan-phase N -> /gsd:execute-phase N
```

1. **Initialize**: Questions until full understanding -> Research (parallel agents) -> Requirements -> Roadmap
2. **Discuss**: Captures user preferences for gray areas before research/planning (CONTEXT.md)
3. **Plan**: Research -> Create 2-3 atomic task plans with XML structure -> Verify against requirements
4. **Execute**: Run plans in **waves** (parallel within wave, sequential between waves) -> Fresh context per plan -> Atomic commits per task -> Verify against goals

### Key Innovation: Wave Execution
Plans grouped into waves based on dependencies. Within each wave, plans run in parallel. This prevents context rot because each plan gets a fresh 200k-token context window.

### Anti-context-rot Design
- Each plan is "small enough to execute in a fresh context window"
- "No degradation, no 'I'll be more concise now'"
- The complexity is in the system, not in the workflow

### Artifacts Created
- `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`
- Per-phase: `{N}-CONTEXT.md`, `{N}-RESEARCH.md`, `{N}-{M}-PLAN.md`

### Maturity: **HIGH** -- referenced as "30K stars original" by fork, multi-platform, npm-distributed

### Relevance to Agent Framework
**VERY HIGH**. Multiple directly applicable patterns:
- **Wave execution with dependency analysis** -- this is essentially HTN decomposition with parallel sibling tasks. The Agent Framework should implement wave-based execution for task_graph
- **Fresh context per plan** -- critical insight for long-running agent sessions. The Agent Framework should track context usage and spawn fresh agents when context degrades
- **Spec-driven development artifacts** (PROJECT.md, REQUIREMENTS.md, etc.) -- the Agent Framework could generate equivalent structured artifacts during HTN planning
- **Discuss phase** (capturing preferences before planning) -- relevant to Agent Framework's user interaction model
- **Context rot mitigation** -- a fundamental problem the Agent Framework must solve for long-running multi-step tasks

---

## 7. Everything-Claude-Code (affaan-m)

**Source:** byteiota.com article (fetched directly, March 2026)

### Architecture
5 architectural layers:
1. **Agents** (28 specialists): code-reviewer, security-scanner, test-generator, etc.
2. **Skills** (116 reusable workflows): Django, Next.js, Go, Rust patterns
3. **Commands** (59 slash tools): /tdd, /security-scan, etc.
4. **Hooks** (automated triggers): memory persistence, context optimization
5. **Memory** (JSON-based): preferences, writing styles, learned patterns with confidence scores

### Key Claims (from article)
- Built at February 2026 Anthropic/Cerebral Valley Hackathon
- 3,735 GitHub stars in a single day (March 22, 2026)
- Doctolib: 40% faster feature shipping after full team adoption
- AgentShield: 102 security rules via /security-scan
- Zero security incidents across 10+ months production use
- 1,282 tests, 98% coverage, 747 commits, 30+ contributors

### Production Lessons
- **Keep agent teams to 3-4 specialists maximum** -- more agents create coordination overhead that eats productivity gains
- **CLAUDE.md under 2000 tokens** or Claude ignores half the rules
- **Business-goal prompts > technical specifications**

### Maturity: **HIGH** -- hackathon origin but extensive production use, strong test coverage

### Relevance to Agent Framework
**HIGH**. Key takeaways:
- **3-4 agent sweet spot** -- empirical finding that bounds the Agent Framework's team size
- **Memory with confidence scores** -- the Agent Framework's meta_predict_agent/meta_record_outcome tools should track confidence
- **Security scanning as first-class concern** -- Agent Framework should integrate security gates into HTN task execution
- **5-layer architecture** (agents/skills/commands/hooks/memory) is a clean separation of concerns that the Agent Framework partially mirrors

---

## 8. Compound Engineering Plugin (EveryInc)

**Source:** github.com/EveryInc/compound-engineering-plugin README (fetched directly)

### Philosophy
"Each unit of engineering work should make subsequent units easier -- not harder."
- Traditional dev accumulates tech debt; compound engineering inverts this
- **80% planning and review, 20% execution**

### Workflow
```
Brainstorm -> Plan -> Work -> Review -> Compound -> Repeat
               ^
             Ideate (optional)
```

| Command | Purpose |
|---------|---------|
| /ce:ideate | Discover improvements through divergent ideation + adversarial filtering |
| /ce:brainstorm | Explore requirements and approaches |
| /ce:plan | Turn ideas into implementation plans |
| /ce:work | Execute with worktrees and task tracking |
| /ce:review | Multi-agent code review |
| /ce:compound | Document learnings for future work |

### Key Innovation: The Compound Step
After review, explicitly **document what was learned** so that future cycles benefit. "Each cycle compounds: brainstorms sharpen plans, plans inform future plans, reviews catch more issues, patterns get documented."

### Cross-platform
Converter CLI supports: Claude Code, OpenCode, Codex, Factory Droid, Pi, Gemini CLI, Copilot, Kiro, Windsurf, OpenClaw, Qwen Code

### Maturity: **MEDIUM-HIGH** -- npm-distributed, CI pipeline, cross-platform support, backed by Every.to (media company)

### Relevance to Agent Framework
**HIGH**. The **compound step is the most important pattern here**:
- The Agent Framework should have an explicit "learning extraction" phase after each task completion
- `meta_record_outcome` already exists but isn't wired into a formal compound cycle
- The 80/20 planning/execution ratio aligns with HTN's emphasis on plan quality
- **Adversarial ideation** (`/ce:ideate`) -- running agents with deliberately opposing views to stress-test ideas, applicable to Agent Framework's multi-agent debate pattern

---

## 9. Night Market (athola/claude-night-market)

**Source:** github.com/athola/claude-night-market README (fetched directly, v1.7.2)

### Architecture
**19 plugins in 4 layers:**

| Layer | Purpose | Plugins |
|-------|---------|---------|
| **Meta** | Skill authoring, evaluation, governance | abstract |
| **Foundation** | Auth, git, TDD, error patterns | leyline, sanctum, imbue |
| **Utility** | Context optimization, LLM delegation, hooks, agent orchestration | conserve, conjure, hookify, egregore |
| **Domain** | Specialized tasks | pensive, attune, parseltongue, memory-palace, spec-kit, minister, archetypes, phantom, scribe, scry, tome |

Total: **151 skills, 138 slash commands, 48 agents**

### Most Interesting Patterns

1. **`egregore` (Autonomous Agent Orchestrator)**: parallel worktree execution, agent specialization, cross-item learning, crash recovery via watchdog monitoring
2. **`conjure` (Multi-LLM Delegation)**: routes tasks to cheapest-capable external LLM (Gemini, Qwen) -- model cost optimization
3. **`leyline:risk-classification`**: 4-tier task gating (GREEN/YELLOW/RED/CRITICAL) with war-room escalation for RED/CRITICAL
4. **`imbue` (TDD Enforcement)**: PreToolUse hook verifying test files exist before allowing implementation writes
5. **`conserve` (Context Optimization)**: bloat detection, CPU/GPU monitoring, token conservation
6. **`tome` (Multi-source Research)**: code archaeology, community discourse, academic literature, TRIZ analysis
7. **Cross-session state** via `CLAUDE_CODE_TASK_LIST_ID` + GitHub Discussions as persistence layer

### Governance Model
"Stewardship" philosophy: steward (not own), multiply (not merely preserve), think seven iterations ahead. `/stewardship-health` monitors per-plugin health.

### Maturity: **MEDIUM-HIGH** -- well-architected, comprehensive docs, requires Claude Code 2.1.16+

### Relevance to Agent Framework
**HIGH**. Several unique patterns:
- **4-tier risk classification** with escalation -- directly applicable to Agent Framework task routing. Map to HTN task criticality levels.
- **`egregore` autonomous orchestration with crash recovery** -- the Agent Framework needs watchdog monitoring for long-running agents; this is a concrete implementation
- **`conjure` cheapest-capable routing** -- cost optimization by routing to the cheapest model that can handle the task; integrate with Agent Framework's model selection
- **TDD enforcement via hooks** -- quality gates that physically prevent writing implementation without tests; applicable as HTN preconditions
- **Cross-session state via external persistence** -- the Agent Framework already has Redis + AGE for this, but the pattern of using GitHub Discussions as a secondary persistence layer is interesting for human-readable audit trails

---

## 10. Boris Cherny's Workflow (Claude Code creator)

**Source:** Not directly fetchable (search engines throttled, YouTube not parseable). Based on training data and community references.

### Known Information
- Boris Cherny is a senior engineer at Anthropic who worked on Claude Code
- His public talks emphasize **tool design principles** for agentic coding
- Key principles (from community reports):
  - Tools should be "read-mostly" -- most operations should be non-destructive
  - Tools should have clear, predictable boundaries
  - Preference for composable, small tools over monolithic ones
  - Importance of **checkpointing** for agent error recovery
  - The agent should be able to "undo" its last action

### Maturity: **N/A** -- personal workflow, not a framework

### Relevance to Agent Framework
**MEDIUM**. Tool design principles are relevant:
- The 378 MCP tools in Agent Framework should follow read-mostly patterns where possible
- Checkpointing and rollback capabilities should be first-class features
- **NOTE**: Could not verify details from primary source. Treat as T6-level confidence.

---

## 11. Thariq Shihipar's "Lessons from Building Claude Code"

**Source:** Not directly fetchable. Referenced in community as Medium post.

### Known Information (from training data)
- Thariq Shihipar is an engineer at Anthropic who worked on Claude Code
- Key lessons on tool design:
  - **Give the model escape hatches** -- when a tool fails, the model needs alternatives
  - **Prefer structured output over free-text parsing**
  - **Make tool errors informative** -- not just "failed" but "failed because X, try Y instead"
  - **Limit tool count per conversation** -- too many tools confuse model selection
  - **Tool descriptions matter more than tool names** -- invest in description quality
  - **Batch operations over individual ones** -- reduce round-trips

### Maturity: **N/A** -- design principles, not a framework

### Relevance to Agent Framework
**HIGH**. Directly applicable to 378 MCP tools:
- **Informative errors**: every MCP tool should return actionable failure messages
- **Escape hatches**: Agent Framework should detect tool failures and suggest alternatives (already have `recovery_suggest_alternative`)
- **Tool count management**: with 378 tools, the Agent Framework must implement intelligent tool filtering per task context (already have `tool_search`/`tool_info`)
- **Description quality**: tool descriptions are the primary signal for model-based tool selection
- **NOTE**: Could not verify all details from primary source. Treat as T6-level confidence.

---

## Cross-Cutting Patterns (Synthesis)

### Pattern 1: Phase-Gated Execution
Found in: RIPER (#5), GSD (#6), Compound Engineering (#8), AgentSys (#2)

**Pattern**: Enforce strict phase progression (Research -> Plan -> Execute -> Review). Agents cannot skip phases. Each phase has capability restrictions.

**Agent Framework mapping**: HTN method preconditions naturally enforce this. Define HTN methods where EXECUTE-type operators require PLAN-completed as precondition.

### Pattern 2: Fresh Context Per Task
Found in: GSD (#6), Agent Teams (#1), Claude Squad (#3)

**Pattern**: Spawn a new agent/session per atomic task to avoid context rot. Critical for long-running workflows.

**Agent Framework mapping**: The Agent Framework should track token usage per agent and auto-spawn fresh agents when approaching context limits. Wave-based execution (GSD) provides the dependency model.

### Pattern 3: Retrospective Learning
Found in: Compound Engineering (#8), Ruflo (#4), Everything-Claude-Code (#7)

**Pattern**: After task completion, explicitly extract and persist learnings. Confidence-scored memory. Self-optimizing routing based on past performance.

**Agent Framework mapping**: Wire `meta_record_outcome` into a formal post-task "compound" phase. Build a feedback loop from outcomes to `meta_predict_agent` routing.

### Pattern 4: Deterministic + LLM Hybrid
Found in: AgentSys (#2), Night Market (#9)

**Pattern**: Use deterministic tools (regex, AST, static analysis) for detection/validation. Reserve LLM calls for judgment/synthesis. 77% token savings.

**Agent Framework mapping**: The 378 MCP tools include many deterministic ones (code_list_symbols, code_find_definition, fs_grep). HTN planning should prefer deterministic tools and use LLM-based tools only when deterministic ones are insufficient.

### Pattern 5: Risk-Tiered Escalation
Found in: Night Market (#9), Everything-Claude-Code (#7)

**Pattern**: Classify tasks by risk (GREEN/YELLOW/RED/CRITICAL). Auto-execute safe tasks. Escalate risky tasks to human review or war-room deliberation.

**Agent Framework mapping**: Assign risk tiers to HTN tasks based on tool types used (file writes = YELLOW, docker operations = RED, etc.). Route high-risk tasks through approval gates.

### Pattern 6: Cost-Optimized Model Routing
Found in: Night Market conjure (#9), Ruflo Q-Learning (#4), AgentSys benchmarks (#2)

**Pattern**: Route tasks to the cheapest model that can handle them. Sonnet + structured pipeline matches Opus quality at 40% lower cost.

**Agent Framework mapping**: The Agent Framework currently uses a fixed model. Implement per-task model selection based on task complexity and budget. Use `meta_predict_agent` to learn which models work for which task types.

---

## Recommendations for Agent Framework Integration

### Priority 1 (Implement Soon)
1. **Wave-based execution** (from GSD): Decompose HTN plans into dependency waves. Execute parallel tasks in each wave with fresh agent contexts.
2. **Compound/learning step** (from Compound Engineering): Add a post-task "extract learnings" phase that feeds into `meta_record_outcome`.
3. **Risk classification** (from Night Market): Add risk tiers to HTN operators based on tool types.

### Priority 2 (Design Phase)
4. **Phase-gated capability matrix** (from RIPER): Enforce read-only during research, plan-only during planning, full access during execution.
5. **Certainty-graded outputs** (from AgentSys): All agent outputs should carry HIGH/MEDIUM/LOW certainty labels.
6. **Cost-optimized routing** (from Night Market/Ruflo): Per-task model selection.

### Priority 3 (Longer Term)
7. **Deterministic-first tool selection** (from AgentSys): HTN planner should prefer deterministic MCP tools over LLM-based ones.
8. **Crash recovery watchdog** (from Night Market egregore): Monitor long-running agents, auto-restart on failure.
9. **Cross-session persistence** (from RIPER/GSD): Persist plan artifacts to KORE for cross-session continuity.

---

## Serendipitous Connections

### HTN Planning <-> Wave Execution (GSD)
GSD's wave execution is essentially a **topological sort** of a task dependency DAG -- the same algorithm used in HTN plan linearization. The Agent Framework's HTN planner already produces task dependencies; wave execution is just the runtime scheduler for those dependencies.

### Bradley-Terry Model (Ranking Todo) <-> Model Routing
The model routing problem (which LLM is best for which task) is structurally identical to the ranking problem in Ranking Todo. Use Bradley-Terry pairwise comparisons of model performance to build a ranking, then route tasks to the highest-ranked affordable model.

### KORE GC Paper <-> Context Rot
GSD's "context rot" problem is an instance of **information staleness** in co-located stores -- the same theme as the KORE-GC paper. As an agent's context fills with old information, new information gets drowned out. The GC approach of pruning stale context is directly applicable.

### Agent Framework A2A <-> Agent Teams Mailbox
Anthropic's Agent Teams mailbox pattern (point-to-point + broadcast) is architecturally identical to the A2A Gateway already implemented in `mcp-proxy`. The Agent Framework could expose its inter-agent communication via A2A protocol, making it interoperable with external agent teams.

---

## Sources Fetched

| # | Source | Tier | URL |
|---|--------|------|-----|
| 1 | Anthropic Agent Teams Docs | T7 | code.claude.com/docs/en/agent-teams (via Context7) |
| 2 | AgentSys README | T7 | github.com/avifenesh/agentsys |
| 3 | Claude Squad README | T7 | github.com/smtg-ai/claude-squad |
| 4 | Ruflo README | T7 | github.com/ruvnet/ruflo |
| 5 | RIPER-5 README | T7 | github.com/tony/claude-code-riper-5 |
| 6 | GSD README | T7 | github.com/glittercowboy/get-shit-done (via gsd-build) |
| 7 | Everything-Claude-Code article | T5 | byteiota.com |
| 8 | Compound Engineering README | T7 | github.com/EveryInc/compound-engineering-plugin |
| 9 | Night Market README | T7 | github.com/athola/claude-night-market |
| 10 | awesome-claude-code README | T7 | github.com/hesreallyhim/awesome-claude-code |
| 11 | Boris Cherny | T6 | Not directly fetched (search engines throttled) |
| 12 | Thariq Shihipar | T6 | Not directly fetched (search engines throttled) |

## What I Did NOT Find
- **Boris Cherny's personal workflow** and **Thariq Shihipar's Medium post**: search engines were rate-limited during this research session. Information from training data only. Should be re-fetched when search engines recover.
- **GSD codecentric.de blog post**: the URL was incorrect (404). GSD appears to originate from `glittercowboy`, not codecentric. The codecentric connection may be a separate blog post about GSD, not the framework itself.
- **Academic papers on multi-agent orchestration patterns**: search engines were throttled. The Semantic Scholar / arXiv search for formal treatment of these patterns should be done in a follow-up session.
