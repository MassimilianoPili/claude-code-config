# Research Report: Advanced Claude Code Hooks, Skills, and Agent Patterns (March 2026)

**Epistemic status:** Active, fast-moving community practice -- most sources are T5-T7 (blogs, GitHub repos, community guides). No peer-reviewed literature exists on Claude Code patterns. Confidence varies by section.
**Sources fetched:** awesome-claude-code (GitHub), claude-code-ultimate-guide (GitHub), Claude Code Skills Reference gist (mellanon), official Claude Code docs (code.claude.com), multiple search result pages, community blog posts.
**Date:** 2026-03-28

---

## Executive Summary

The Claude Code ecosystem has matured significantly since mid-2025. The community has converged on several key patterns, and Anthropic has expanded the hook system to 12+ lifecycle events with 4 handler types (command, HTTP, prompt, agent). The most important developments for your setup are:

1. **Skill activation is unreliable by default (~20%)** but can reach 84% with forced evaluation hooks
2. **Agent Teams** (shipped Feb 2026 with Opus 4.6) are the new primitive for parallel multi-agent work
3. **Prompt hooks** and **HTTP hooks** are new handler types you may not be using yet
4. **The Ralph Wiggum pattern** (autonomous loop until spec fulfilled) has become a major community pattern
5. **Hook-driven skill routing** is the emerging best practice for large skill collections

---

## 1. Advanced Hook Patterns

**Confidence: High** -- based on official docs + extensive community adoption

### 1.1 Hook System Evolution (12 Lifecycle Events, 4 Handler Types)

The hook system now supports **12 lifecycle events** (up from the 7 you listed):

| Event | Phase | Your status |
|-------|-------|-------------|
| PreToolUse | Before tool execution | HAVE |
| PostToolUse | After tool execution | HAVE |
| SessionStart | Session initialization | HAVE |
| Stop | Session end / task complete | HAVE |
| PreCompact | Before context compaction | HAVE |
| ConfigChange | Settings modified | HAVE |
| UserPromptSubmit | Before user input processed | HAVE |
| **Notification** | When Claude needs input | NEW? |
| **PreApiRequest** | Before API call to Claude | NEW? |
| **PostApiResponse** | After API response | NEW? |
| **SubagentStart** | Before subagent spawns | NEW? |
| **SubagentEnd** | After subagent completes | NEW? |

**4 Handler Types** (critical -- you may only be using command hooks):

| Type | How it works | Use case |
|------|-------------|----------|
| **Command** | Runs shell script, reads stdout JSON | Local validation, formatting, git ops |
| **HTTP** | POSTs to URL endpoint | External service integration, logging to remote DB, Slack/webhook notifications |
| **Prompt** | Injects text into Claude's context | Behavior modification, skill routing, context priming |
| **Agent** | Spawns a subagent to evaluate | Complex decisions, multi-step validation |

**Priority recommendation:** Prompt hooks and HTTP hooks are likely the biggest gap in your setup. HTTP hooks would integrate well with your existing infra (dashboard-api, MCP server, AGE graph).

### 1.2 NEW Hook Patterns from the Community

**A. Hook-Driven Skill Routing** (HIGH PRIORITY)
Source: claude-code-infrastructure-showcase by diet103 (GitHub, T7)

With 105 skills, your biggest problem is likely misfiring. The community solution:
- A `UserPromptSubmit` prompt hook that analyzes the user's input and injects the correct skill context
- Matches keywords against a rules file and loads the right skill BEFORE Claude starts working
- This is essentially a classifier running as a hook

**Pattern:**
```json
{
  "event": "UserPromptSubmit",
  "type": "prompt",
  "script": "analyze-intent-and-inject-skill-context"
}
```

**B. Forced Skill Evaluation Hook** (HIGH PRIORITY)
Source: Skills Reference gist (mellanon, T7 -- community research, Dec 2025)

Activation statistics from 200+ prompt tests:

| Approach | Success Rate |
|----------|-------------|
| No optimization | ~20% |
| Simple description | 20% |
| Optimized description | 50% |
| LLM pre-eval hook | 80% |
| **Forced eval hook** | **84%** |

The forced evaluation hook requires Claude to explicitly reason about which skills apply before proceeding. This is a prompt hook that injects: "Before responding, evaluate all available skills and state which ones apply and why."

**C. TDD Guard Hook**
Source: TDD Guard by nizos (GitHub, T7)

A PostToolUse hook that monitors file operations in real-time and **blocks changes that violate TDD principles**. If you write implementation before tests, the hook rejects the edit.

**D. Prompt Injection Scanner Hook**
Source: parry by vaporif (GitHub, T7 -- early development)

A PreToolUse hook that scans tool inputs and outputs for injection attacks, secrets, and data exfiltration attempts. Relevant for your MCP-heavy setup where tool outputs could contain injected instructions.

**E. Inter-Agent Communication via Hooks**
Source: Claude Hook Comms (HCOM) by aannoo (GitHub, T7 -- unstable)

Uses hooks for real-time communication between Claude Code subagents. Enables @-mention targeting between agents and a live dashboard. Creative but immature.

**F. Auto-Approval Hook (Permission Fatigue Solution)**
Source: Dippy by ldayton (GitHub, T7)

AST-based parsing of bash commands to auto-approve safe commands while prompting for destructive operations. Solves the "approve every command" fatigue without `--dangerously-skip-permissions`.

**G. British English Conversion Hook**
Source: Britfix by Talieisin (GitHub, T7)

Context-aware: converts American to British English in file writes, but only in comments and docstrings, never identifiers or string literals. Niche but demonstrates sophisticated PostToolUse text processing.

**H. Quality Check Hook with SHA256 Caching**
Source: TypeScript Quality Hooks by bartolli (GitHub, T7)

PostToolUse hook for TypeScript projects: ESLint auto-fix + Prettier + tsc compilation check. Uses SHA256 config caching for <5ms validation -- important pattern for keeping hooks fast.

### 1.3 Patterns You Already Have But Could Improve

Based on your listed hooks (secret scanning, dangerous command blocking, auto-formatting, failure advising, context drift detection, audit logging, phase tracking):

- **Audit logging**: Consider upgrading to HTTP hooks that POST to your AGE graph or dashboard-api directly, rather than shell scripts
- **Context drift detection**: The community pattern of `/clear` between unrelated tasks is now considered essential (builder.io "50 tips" post)
- **Phase tracking**: Could benefit from agent-type hooks that spawn a subagent to evaluate whether the current phase is complete

---

## 2. Skill Engineering

**Confidence: Medium-High** -- based on extensive community testing (200+ prompts) but no Anthropic-published benchmarks

### 2.1 The Core Problem: Skill Routing is Pure LLM Reasoning

Critical insight from the Skills Reference gist: **Skills use pure LLM reasoning for routing, NOT embeddings or keyword matching.** All available skill names + descriptions are formatted as text in the Skill tool's prompt. Claude's transformer forward pass decides which skill to activate.

Implications for your 105 skills:
- You are competing for attention in a ~15,000 character token budget
- Every skill description must earn its tokens
- Vague descriptions ("Helps with Docker") are invisible at ~20% activation

### 2.2 The Three-Tier Activation Strategy

| Level | Effort | Success Rate | Description |
|-------|--------|-------------|-------------|
| 1: Description optimization | Low | 50% | Specific "Use when" language + keywords |
| 2: CLAUDE.md references | Medium | 60-70% | Document skill usage in project CLAUDE.md |
| 3: Custom hooks | High | 84% | Forced evaluation hooks |

**Recommendation for your 105 skills:**
1. Audit all descriptions for the "Two-Part Structure": WHAT + WHEN
2. Add "USE WHEN" patterns with exact trigger phrases from your actual workflow
3. For the top 10-15 most critical skills, implement forced eval hooks
4. For the remaining 90, optimize descriptions to Level 1

### 2.3 Skill Description Best Practices

**The Golden Rules:**

1. **Third person only** -- "Processes Excel files" not "I can help you process Excel files"
2. **Two-part structure**: capability statement + trigger conditions
3. **Include 5+ specific trigger keywords** from actual user requests
4. **Under 1024 characters** (hard limit)
5. **Mention file types, formats, domains** explicitly

**Template:**
```yaml
name: [verb]-[noun]
description: [Core capability]. [Secondary capabilities]. Use when [trigger 1], [trigger 2], or when user mentions "[keyword1]", "[keyword2]", "[keyword3]".
```

**Anti-patterns to avoid:**
- Vague: "Helps with documents" (20% activation)
- Too many options: "You can use pypdf, or pdfplumber, or PyMuPDF..."
- Deeply nested references: SKILL.md -> advanced.md -> details.md
- Time-sensitive info: "If before August 2025, use old API"

### 2.4 Progressive Disclosure (Three-Level Loading)

| Level | What Loads | When | Token Budget |
|-------|-----------|------|-------------|
| Level 1 | name + description | Always at startup | ~100 tokens |
| Level 2 | SKILL.md body | When triggered | Under 5K tokens |
| Level 3 | Referenced files | On-demand via Read | As needed |

**Key insight:** Keep SKILL.md under 500 lines. Use `docs/` subdirectories for detailed documentation.

### 2.5 The "Five Fixes" for Failing Skills

From analysis of 40+ skill failures:

1. **Write specific activation triggers** -- exact keywords from your workflow
2. **Show real examples, not descriptions** -- examples should be LONGER than rules section
3. **Progressive disclosure** -- SKILL.md as menu, details in subdirectories
4. **Set explicit boundaries** -- define what the skill does NOT do
5. **Test with real work** -- evaluation-driven development (baseline -> measure -> iterate)

### 2.6 Skills vs Agents vs Hooks vs Plugins: Decision Framework

From the Ultimate Guide (FlorianBruniaux):

| Mechanism | Use when | Determinism | Context cost |
|-----------|----------|-------------|-------------|
| **Hook** | Must happen 100% of the time | Deterministic | Zero (runs outside Claude) |
| **Skill** | Claude should decide when relevant | Probabilistic (~50-84%) | Low (loaded on demand) |
| **Agent** | Complex task needing isolation | Deterministic (if invoked) | High (separate context) |
| **Plugin** | Reusable bundle of skills+hooks+commands | Mixed | Mixed |
| **CLAUDE.md** | Always-on context | Always loaded | Medium (always in context) |

**builder.io insight (50 tips):** "Claude follows CLAUDE.md about 80% of the time. Hooks are deterministic, 100%. If something must happen every time without exception (formatting, linting, security checks), make it a hook."

---

## 3. Agent Architecture

**Confidence: Medium** -- fast-evolving area, Agent Teams shipped only Feb 2026

### 3.1 Agent Teams (NEW -- February 2026)

The biggest architectural change since your setup. Agent Teams shipped alongside Opus 4.6 and enable **multiple agents working in parallel and communicating with each other**.

Key differences from subagents:

| Feature | Subagent | Agent Team |
|---------|----------|-----------|
| Execution | Sequential, one at a time | Parallel |
| Communication | Parent-child only | Peer-to-peer |
| Use case | Specialized subtask | War room / parallel workstreams |
| Context | Isolated from parent | Shared context possible |

Source: Medium, "Sub-agent vs. Agent Team" (T7, March 2026)

**Relevance to your setup:** Your `claude_send/read/broadcast` MCP tools already implement a form of inter-agent messaging. Agent Teams may provide a native alternative for some use cases, but your MCP-based approach is more flexible (works across sessions, persists in Redis).

### 3.2 Community Agent Patterns

**A. Multi-Agent Code Review (AgentSys)**
Source: agentsys by avifenesh (GitHub, T7)

Multiple auditor agents run in parallel, each checking different aspects (security, performance, style). Includes micro-checkpoint protocols and "prevents AI going rogue" safety mechanisms.

**B. Ralph Wiggum Loop (Autonomous Agent Loop)**
Source: Multiple repos (ralph-claude-code, ralph-orchestrator, ralph-playbook -- all T7)

Major community pattern: runs Claude Code in an automated loop until a specification file is marked complete or resource limits are reached. Features:
- Intelligent exit detection
- Rate limiting + circuit breaker patterns
- Safety guardrails against infinite loops
- tmux integration for live monitoring

**This pattern is directly relevant to your ANANKE inesorabilita approach** -- both share the philosophy of "run until convergence."

**C. RIPER Workflow (Phase-Enforced Development)**
Source: claude-code-riper-5 by Tony Narlock (GitHub, T7)

Enforces separation between Research, Innovate, Plan, Execute, and Review phases. Uses branch-aware memory bank and strict mode enforcement. Similar to your phase tracking hooks but more structured.

**D. Orchestrator Platforms**
- **Claude Squad** (smtg-ai): Terminal app managing multiple Claude Code instances in separate workspaces
- **Claude Swarm** (parruda): Launch connected swarm of Claude Code agents
- **Ruflo** (ruvnet): Self-learning autonomous multi-agent swarms with vector-based multi-layered memory
- **TSK** (dtormoen): Rust CLI delegating tasks to AI agents in sandboxed Docker environments

**E. GSD Workflow System**
Source: codecentric.de blog (T7, March 2026)

Orchestrates Claude Code using markdown files: slash commands, agents, hooks, and persistent state. The `/gsd:new-project` command bootstraps entire project structures.

### 3.3 Agents You Are Missing

Based on community patterns, consider adding:

| Agent | What it does | Priority |
|-------|-------------|----------|
| **Code Review Agent** | Multi-aspect parallel review (security, perf, style) | HIGH |
| **Deployment Agent** | Pre-deploy checks, rollback planning, health verification | MEDIUM (you have `sol deploy`) |
| **Documentation Agent** | Auto-generate/update docs when code changes | MEDIUM |
| **Dependency Audit Agent** | Check for vulnerabilities, outdated deps | LOW (hooks better) |
| **Session Restore Agent** | Recover context from previous sessions via git + session files | MEDIUM |

---

## 4. Plugin Development Patterns

**Confidence: Medium** -- plugin architecture is relatively new (late 2025)

### 4.1 Plugin Architecture

From the Ultimate Guide and community sources:

A plugin is a **bundled package** containing:
- `plugin.json` -- metadata, dependencies
- `skills/` -- one or more SKILL.md directories
- `commands/` -- slash commands
- `hooks/` -- hook configurations
- `agents/` -- subagent definitions

**Key architectural decisions:**

| Pattern | When to use | Example |
|---------|-------------|---------|
| **Skill-only plugin** | Reusable knowledge/capability | Your Spring Boot skills |
| **Hook-only plugin** | Deterministic enforcement | Secret scanning, formatting |
| **Full-stack plugin** | Complete workflow | SDLC management (AgentSys) |
| **Meta-plugin** | Tools for building other plugins | hookify, agnix (linter) |

### 4.2 Notable Plugin Patterns

**A. agnix (Agent File Linter)**
Source: agent-sh/agnix (GitHub, T7)

Validates CLAUDE.md, AGENTS.md, SKILL.md, hooks, MCP config. Plugin for all major IDEs with auto-fixes. **You should run this against your 105 skills.**

**B. Compound Engineering Plugin**
Source: EveryInc (GitHub, T7)

Turns past mistakes and errors into lessons for future improvement. Skills, agents, and commands built around a "retrospective learning" discipline. Relevant to your failure-advising hooks.

**C. Context Engineering Kit**
Source: NeoLabHQ (GitHub, T7)

Advanced context engineering techniques with minimal token footprint. Focused on improving agent result quality. Worth studying for your 28KB academic-researcher agent.

**D. On-Demand Hooks in Skills**
Source: shanraisshan/claude-code-best-practice (GitHub, T7)

Pattern: skills that activate hooks only when the skill is active:
- `/careful` -- blocks destructive commands
- `/freeze` -- blocks edits outside a specified directory

This is interesting for your use case: rather than always-on hooks, make hooks context-dependent.

### 4.3 Plugin vs Skill vs Hook Decision Matrix

| Need | Best mechanism | Why |
|------|---------------|-----|
| Must happen every time | Hook | Deterministic |
| Claude should decide contextually | Skill | LLM routing |
| User explicitly invokes | Slash command | Direct control |
| Reusable across projects | Plugin | Portable package |
| Always-on context | CLAUDE.md rule | Always loaded |
| Complex isolated task | Subagent/Agent | Separate context window |

---

## 5. Unknown Unknowns

**Confidence: Low-Medium** -- creative/experimental community work

### 5.1 Non-Coding Uses of Claude Code

Source: Reddit r/ClaudeAI thread (T7, Feb 2026)

People are using Claude Code for:
- **Mountain route research** (claude-mountaineering-skills): aggregates data from 10+ mountaineering sources, generates route beta reports with weather and avalanche conditions
- **Nonfiction book publishing pipeline** (Book Factory): replicates traditional publishing infrastructure
- **Game character AI** (Network Chronicles): AI-driven game characters with LLM integration
- **Market research + copywriting** (Ralph Wiggum Marketer): autonomous marketing agent
- **Gene Ontology annotation** in graph databases (torchcell)
- **Educational course generation** from codebases (Codebase to Course)
- **Guitar software development guide** (soramimi/Guitar)
- **Personal knowledge management** with Obsidian vault integration

### 5.2 Creative Hook Applications

- **Sound effects** (Claudio by ctoth): OS-native sounds on Claude Code events. "Sparks joy."
- **Speech-to-text input** (stt-mcp-server-linux): push-to-talk transcription piped to Claude in tmux
- **Desktop notifications** (CC Notify): alerts for input needs + task completion with VS Code jump
- **British English enforcement** (Britfix): context-aware spelling conversion
- **Session analytics** (Vibe-Log): analyzes prompts, produces HTML strategy reports

### 5.3 Security Patterns (IMPORTANT)

Source: claude-code-ultimate-guide (T7, extensively documented)

The Ultimate Guide maintains a **threat database of 24 CVEs and 655 malicious skills**. Key threats:

- **Prompt injection via tool outputs**: MCP tool results containing malicious instructions
- **Skill supply chain attacks**: malicious skills in community marketplaces
- **Data exfiltration via hooks**: hooks that phone home with codebase contents
- **Permission escalation**: hooks that gradually normalize dangerous operations

**Relevant to your setup:** With 378 MCP tools and 105 skills, your attack surface is significantly larger than average. The `parry` prompt injection scanner hook is worth evaluating.

### 5.4 The "Agent Compiler" Pattern

Source: KORE cached knowledge (T7)

A CLI tool that compiles Claude Code skills INTO CLAUDE.md and AGENTS.md directly, bypassing the probabilistic skill routing entirely. Instead of relying on LLM routing (~50%), it embeds skill knowledge directly into always-loaded context.

Trade-off: higher token cost but 100% reliability. For your most critical skills, this may be worth it.

---

## 6. Priority-Ranked Recommendations

### Tier 1: HIGH PRIORITY (implement within 1-2 weeks)

| # | Action | Expected Impact |
|---|--------|----------------|
| 1 | **Audit all 105 skill descriptions** using the Two-Part Structure (WHAT + WHEN) pattern with 5+ trigger keywords each | Activation rate from ~20% to ~50% |
| 2 | **Implement forced evaluation hook** for top 15 critical skills | Activation rate to ~84% for critical skills |
| 3 | **Add prompt hooks** for skill routing on UserPromptSubmit | Intelligent context injection before Claude processes |
| 4 | **Run agnix linter** against all skills, hooks, and CLAUDE.md files | Find structural issues in 105 skills |
| 5 | **Evaluate parry** (prompt injection scanner) for your MCP-heavy setup | Security hardening for 378 tools |

### Tier 2: MEDIUM PRIORITY (implement within 1 month)

| # | Action | Expected Impact |
|---|--------|----------------|
| 6 | **Upgrade audit logging hooks to HTTP type** posting to AGE graph | Better integration with KORE, queryable audit trail |
| 7 | **Add a Code Review Agent** based on AgentSys patterns | Multi-aspect parallel code review |
| 8 | **Implement Dippy-style auto-approval** for safe bash commands | Reduce permission fatigue |
| 9 | **Explore Agent Teams** for parallel research/coding workflows | Native parallel agent execution |
| 10 | **Add on-demand hooks pattern** (/careful, /freeze) via skills | Context-dependent safety |

### Tier 3: LOW PRIORITY (explore when time permits)

| # | Action | Expected Impact |
|---|--------|----------------|
| 11 | Study Ralph Wiggum pattern for ANANKE integration | Autonomous convergence with safety guardrails |
| 12 | Evaluate Agent Compiler for critical skills | 100% activation at cost of tokens |
| 13 | Add session restore agent | Better cross-session continuity |
| 14 | Try sound/notification hooks | Quality of life |

---

## 7. Key Repositories to Study

| Repository | Stars | Focus | URL |
|-----------|-------|-------|-----|
| awesome-claude-code | High | Curated ecosystem index | github.com/hesreallyhim/awesome-claude-code |
| claude-code-ultimate-guide | High | Deep educational guide, 23K+ lines, security DB | github.com/FlorianBruniaux/claude-code-ultimate-guide |
| AgentSys | Medium | Production workflow automation, multi-agent review | github.com/avifenesh/agentsys |
| Claude Scientific Skills | Medium | Research/science/engineering skills | github.com/K-Dense-AI/claude-scientific-skills |
| Trail of Bits Security Skills | Medium | Security auditing, CodeQL, Semgrep | github.com/trailofbits/skills |
| claude-code-infrastructure-showcase | Medium | Hook-driven skill routing | github.com/diet103/claude-code-infrastructure-showcase |
| Superpowers | Medium | Core SDLC competencies | github.com/obra/superpowers |
| cc-tools | Medium | High-perf Go hooks + utilities | github.com/Veraticus/cc-tools |
| TDD Guard | Low | TDD enforcement via hooks | github.com/nizos/tdd-guard |
| parry | Low | Prompt injection scanner | github.com/vaporif/parry |

---

## 8. Serendipitous Connections

### Connection to KORE-GC Paper
The "Agent Compiler" pattern (embedding skills into CLAUDE.md) is structurally analogous to **materialized views in databases**. Your KORE-GC paper's neural IVM (incremental view maintenance) concept maps directly: skills are "views" over knowledge, and the question of when to materialize (embed in CLAUDE.md) vs compute on demand (LLM routing) is exactly the view maintenance trade-off.

### Connection to Agent Framework
The Agent Teams feature (parallel agents with peer communication) maps to your `agent-framework` multi-agent orchestration. The community patterns for inter-agent hooks (HCOM) and your existing `claude_send/read/broadcast` Redis-based messaging are solving the same problem at different layers.

### Connection to Preference Sort
The skill activation problem (routing to the right skill) is essentially a **preference learning** problem. Your Bradley-Terry model from preference-sort could be applied: track which skills successfully activate for which prompts, build a preference model, and use it to improve routing. This would be a novel contribution.

---

## Sources Fetched

| Source | Tier | What I extracted |
|--------|------|-----------------|
| github.com/hesreallyhim/awesome-claude-code (full README) | T7 | Complete ecosystem index, 200+ resources |
| gist.github.com/mellanon/... (Skills Reference) | T7 | Skill activation statistics, best practices |
| github.com/FlorianBruniaux/claude-code-ultimate-guide (README) | T7 | Architecture, security DB, decision frameworks |
| code.claude.com/docs/en/hooks-guide | T7 (official) | Hook lifecycle events, handler types |
| code.claude.com/docs/en/hooks | T7 (official) | Hook reference |
| builder.io/blog/claude-code-tips-best-practices | T7 | 50 tips, hooks vs CLAUDE.md determinism |
| Multiple search result snippets | T7 | Agent Teams, Ralph Wiggum, community patterns |
| claude.com/blog/how-to-configure-hooks | T7 (official) | Official hook configuration guide |
| Medium "Sub-agent vs Agent Team" article | T7 | Agent Teams architecture (Feb 2026) |

**Limitations:** No T1-T2 (peer-reviewed) sources exist for this topic. All findings are from community practice and official documentation. The skill activation statistics (20%->84%) come from a single community researcher's testing of 200+ prompts -- not independently replicated. Treat specific numbers as directional, not precise.
