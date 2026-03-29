# Deep Research: Claude Code Skill Activation, Hook-Driven Routing, and Prompt Hooks

**Date:** 2026-03-28
**Epistemic status:** Active community experimentation; no peer-reviewed research on Claude Code specifically. Findings synthesized from official docs, extracted system prompts, GitHub implementations, and community blog posts.
**Confidence:** Medium-High for mechanism descriptions (extracted from source code); Medium for activation rates (community-reported, not independently verified); Speculative for Bradley-Terry routing (novel proposal, no prior art in this exact domain).

---

## 1. Skill Activation Mechanics: How Claude Code Routes to Skills

### The Core Mechanism: Pure LLM Reasoning (No Embeddings)

**Key finding:** Skills employ **pure LLM reasoning** for routing decisions. There is no embedding index, no classifier, no algorithmic pattern matching at the code level. (Source: mellanon Skills Reference gist, corroborated by Piebald-AI system prompt extraction)

The system works through **progressive disclosure** at three levels:

| Level | What Loads | When | Token Budget |
|-------|-----------|------|-------------|
| **L1: Metadata** | name + description | Always at startup | ~100 tokens per skill |
| **L2: SKILL.md body** | Full instructions | When skill is triggered | Under 5k tokens |
| **L3: Referenced files** | docs/, scripts/ | On-demand via Read tool | As needed |

**Critical constraint:** The entire available skills list has a **15,000-character limit**. With 105 skills at ~100 tokens each = ~10,500 tokens, you are close to the budget ceiling. This is likely a major reason for low activation -- the LLM has to parse a long list of skill descriptions and match them against user intent in a single transformer forward pass.

### The Skill Tool System Prompt

From the extracted system prompts (Piebald-AI, v2.1.86):

```
/<skill-name> (e.g., /commit) is shorthand for users to invoke a user-invocable skill.
When executed, the skill gets expanded to a full prompt. Use the ${SKILL_TOOL_NAME} tool
to execute them. IMPORTANT: Only use ${SKILL_TOOL_NAME} for skills listed in its
user-invocable skills section - do not guess or use built-in CLI commands.
```

The Skill tool description contains:
1. A list of all available skills with their names and descriptions
2. Instructions to match user intent to skill descriptions
3. The constraint to only invoke listed skills

### Why 20% Baseline Activation

The 20% figure comes from multiple independent reports:
- Ivan Seleznov (Medium, 650 trials): baseline ~20% (T5 source)
- mellanon Skills Reference (community compilation): ~20% baseline (T5)
- Scott Spence (blog): confirmed ~50% coin-flip even with simple hooks (T5)

**Root causes identified:**
1. **Attention dilution:** 105 skill descriptions competing for attention in a single prompt
2. **No salience signal:** Skills are in the system prompt, but the user's message contains no explicit reference to them
3. **LLM laziness:** The model takes the shortest path -- answering directly is cheaper than evaluating 105 skill descriptions
4. **Keywords are irrelevant:** Ivan Seleznov tested adding keyword matches -- 0 percentage point change. The model does not use keywords for routing decisions.

---

## 2. The Four Hook Handler Types

From the official hooks configuration system prompt (extracted from Claude Code v2.1.77):

### Hook Events (10 total)

| Event | Matcher | Purpose |
|-------|---------|---------|
| `UserPromptSubmit` | - | Fires when user submits a prompt |
| `SessionStart` | - | When session starts |
| `PreToolUse` | Tool name | Before tool execution, can block |
| `PostToolUse` | Tool name | After successful tool execution |
| `PostToolUseFailure` | Tool name | After tool failure |
| `PermissionRequest` | Tool name | Before permission prompt |
| `Stop` | - | When Claude stops |
| `PreCompact` | "manual"/"auto" | Before context compaction |
| `PostCompact` | "manual"/"auto" | After compaction |
| `Notification` | Notification type | On notifications |

### Handler Type 1: Command Hook

```json
{ "type": "command", "command": "prettier --write $FILE", "timeout": 30 }
```

- Runs a shell command
- Receives JSON on stdin: `{ session_id, tool_name, tool_input, tool_response, prompt, ... }`
- Outputs text to stdout -- this text is **injected as a `<system-reminder>` in Claude's context**
- Can output JSON to control behavior: `continue`, `decision`, `stopReason`, `systemMessage`
- Available for ALL hook events
- **Performance:** Fast (shell execution), but adds latency per prompt
- **Limitation:** Cannot access Claude's reasoning, only the raw prompt text

### Handler Type 2: Prompt Hook

```json
{ "type": "prompt", "prompt": "Is this safe? $ARGUMENTS" }
```

- Evaluates a condition using an LLM (a separate, lightweight Claude call)
- Must return JSON: `{"ok": true}` or `{"ok": false, "reason": "..."}`
- **Only available for tool events:** PreToolUse, PostToolUse, PermissionRequest
- NOT available for UserPromptSubmit (this is critical -- you cannot use prompt hooks for skill routing)
- **Performance:** Slower (requires an LLM inference call per evaluation)
- **Use case:** Semantic validation of tool arguments (e.g., "is this SQL query safe?")

### Handler Type 3: Agent Hook

```json
{ "type": "agent", "prompt": "Verify tests pass: $ARGUMENTS" }
```

- Runs a full agent with access to tools (Read, Bash, Glob, Grep, etc.)
- Can inspect the codebase, run commands, verify conditions
- Has access to the conversation transcript via `${TRANSCRIPT_PATH}`
- Returns structured result: `{ok: true/false, reason: ...}`
- **Only available for tool events:** PreToolUse, PostToolUse, PermissionRequest
- NOT available for UserPromptSubmit
- **Performance:** Slowest (full agent execution with multiple tool calls)
- **Use case:** Complex verification (e.g., "verify all tests pass after this edit")

The agent hook system prompt (v2.0.51):
```
You are verifying a stop condition in Claude Code. Your task is to verify
that the agent completed the given plan. The conversation transcript is
available at: ${TRANSCRIPT_PATH}
Use the available tools to inspect the codebase and verify the condition.
Use as few steps as possible - be efficient and direct.
```

### Handler Type 4: (Implicit) Hook JSON Output

Not a separate type, but all command hooks can output JSON to control behavior:

```json
{
  "systemMessage": "Warning shown to user in UI",
  "continue": false,
  "stopReason": "Message shown when blocking",
  "decision": "block",
  "reason": "Explanation",
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Context injected back to model",
    "permissionDecision": "allow|deny|ask",
    "updatedInput": { "modified": "tool input" }
  }
}
```

### Comparison Matrix

| Aspect | Command | Prompt | Agent |
|--------|---------|--------|-------|
| Available events | ALL 10 | PreToolUse, PostToolUse, PermissionRequest | PreToolUse, PostToolUse, PermissionRequest |
| UserPromptSubmit | YES | NO | NO |
| Execution | Shell command | LLM inference | Full agent + tools |
| Latency | ~10-50ms | ~500-2000ms | ~2-30s |
| Can block tools | Via JSON output | Via ok: false | Via ok: false |
| Can inject context | Via stdout text | Via reason field | Via reason field |
| Can modify tool input | Via updatedInput | No | No |
| Token cost | 0 (shell only) | ~100-500 tokens | ~500-5000 tokens |

**Critical implication for skill routing:** Since prompt hooks and agent hooks are NOT available for `UserPromptSubmit`, the only mechanism for injecting skill routing instructions before Claude processes a user message is a **command hook**. This is why all community solutions use command hooks.

---

## 3. Hook-Driven Skill Routing: Implementation Patterns

### Pattern A: Simple Instruction Injection (Scott Spence, ~50% activation)

The simplest approach -- a command hook on UserPromptSubmit that echoes a static instruction:

```bash
#!/bin/bash
echo 'INSTRUCTION: If the prompt matches any available skill keywords, use Skill(skill-name) to activate it.'
```

**Why it's weak:** This is a passive suggestion. Claude can and does ignore it because:
- The instruction is generic and non-committal
- It doesn't force a decision point
- It competes with Claude's default behavior of answering directly

### Pattern B: Forced Evaluation Hook (umputun, ~84% activation)

The breakthrough pattern. Forces Claude through a three-step sequence:

```bash
#!/bin/bash
cat <<'EOF'
INSTRUCTION: MANDATORY SKILL ACTIVATION

Check <available_skills> for relevance before proceeding.

IF any skills are relevant:
  1. State which skills and why (only mention relevant ones)
  2. Activate ALL relevant skills with Skill() tool
  3. Then proceed with implementation

IF no skills are relevant:
  - Proceed directly (no statement needed)

CRITICAL: Activate ALL relevant skills via Skill() tool before implementation.
Multiple skills can and should be activated when applicable.
Mentioning a skill without activating it is worthless.
EOF
```

**Why it works:** The **commitment mechanism**. By requiring Claude to:
1. **Explicitly state** which skills are relevant (forces evaluation)
2. **Call Skill() for each** (forces action, not just mention)
3. **Only then** proceed with implementation

This creates a decision checkpoint that Claude cannot skip. The key insight is the last line: "Mentioning a skill without activating it is worthless." This prevents the failure mode where Claude acknowledges a skill exists but doesn't invoke it.

**Settings configuration:**
```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/skill-forced-eval-hook.sh"
          }
        ]
      }
    ]
  }
}
```

### Pattern C: Rule-Based Routing (diet103/claude-code-infrastructure-showcase)

A more sophisticated approach using a `skill-rules.json` configuration file with keyword matching and regex intent patterns.

**Architecture:**
1. `skill-activation-prompt.sh` (bash wrapper) reads stdin, pipes to TypeScript
2. `skill-activation-prompt.ts` (TypeScript) parses the user prompt, matches against rules
3. `skill-rules.json` defines per-skill triggers with keywords + regex patterns

**The skill-rules.json schema:**
```json
{
  "version": "1.0",
  "skills": {
    "backend-dev-guidelines": {
      "type": "domain",          // or "guardrail"
      "enforcement": "suggest",  // or "block" or "warn"
      "priority": "critical|high|medium|low",
      "promptTriggers": {
        "keywords": ["backend", "express", "API", ...],
        "intentPatterns": ["(create|add).*?(route|endpoint|API)", ...]
      },
      "fileTriggers": {
        "pathPatterns": ["blog-api/src/**/*.ts", ...],
        "contentPatterns": ["router\\.", "export.*Controller", ...]
      }
    }
  }
}
```

**The TypeScript hook logic:**
1. Reads user prompt from stdin JSON (`data.prompt`)
2. Iterates all skills, checks keyword matches (case-insensitive `includes()`)
3. Checks intent patterns (regex matching)
4. Groups matched skills by priority (critical > high > medium > low)
5. Outputs formatted instruction block with `ACTION: Use Skill tool BEFORE responding`

**Key innovation:** The `enforcement: "block"` mode for guardrail skills. The frontend-dev-guidelines skill uses this to literally block edits to `.tsx` files unless the skill has been activated first. This uses the `blockMessage` field with a formatted error.

**Limitations:**
- Requires maintaining a keyword/regex ruleset per skill (manual effort)
- Keywords don't improve LLM routing (per Ivan Seleznov's research) -- they only help the hook decide WHICH skills to suggest
- TypeScript dependency (`npx tsx`) adds startup latency

### Pattern D: Combined Approach (Paddo.dev, January 2026)

Blog analysis of the pattern: define rules in skill-rules.json, hook runs on every prompt, checks context, suggests relevant skills. Conclusion: hooks help but are not a complete solution. The suggestion needs to be forceful enough that Claude acts on it.

### Which Pattern to Use

For 105 skills on SOL, the recommended approach is a **hybrid of Pattern B and C**:
- Use Pattern C's rule-based matching to narrow down from 105 to 2-5 relevant skills
- Use Pattern B's forced evaluation language to ensure Claude actually activates them
- This avoids the failure mode of dumping all 105 skill names into the instruction

---

## 4. agnix Linter: Auditing 105 Skills

### What It Is

agnix is a Rust-based linter for agent configurations. 342 rules across Claude Code, Codex CLI, OpenCode, Cursor, Copilot, Kiro, and more.

**Architecture:** Rust workspace with 6 crates:
- `agnix-rules` -- rule metadata from `knowledge-base/rules.json`
- `agnix-core` -- shared validation engine
- `agnix-cli` -- CLI binary
- `agnix-lsp` -- Language Server Protocol binary (real-time editor diagnostics)
- `agnix-mcp` -- MCP server binary
- `agnix-wasm` -- WebAssembly for browser/playground

### Claude Code Rules (53 CC-* rules + 31 AS-* Agent Skills rules)

| Rule Category | Count | What It Validates |
|--------------|-------|-------------------|
| CC-* | 53 | CLAUDE.md, hooks, agents, plugins |
| AS-* + CC-SK-* | 31 | SKILL.md (name, description, structure) |
| MCP-* | 12 | MCP configuration files (*.mcp.json) |

**Key validations for skills:**
- Name: lowercase letters + hyphens only (max 64 chars)
- Description: non-empty, under 1024 chars, no XML tags, third person
- Generic instructions detection (e.g., "Be helpful and accurate" -- waste of tokens)
- SKILL.md file size (warns if over 500 lines)
- Frontmatter required fields

### Why It's Useful for 105 Skills

```bash
# Install
npm install -g agnix

# Lint all skills
agnix .claude/skills/ --target claude-code

# Auto-fix safe issues
agnix --fix-safe .claude/skills/

# Preview fixes
agnix --dry-run --show-fixes .claude/skills/

# Strict mode (warnings = errors)
agnix --strict .claude/skills/
```

**Specific value for SOL:**
1. **Audit all 105 SKILL.md files** for description quality (the #1 factor in activation)
2. **Detect generic descriptions** that waste the 15K-char budget
3. **Verify naming conventions** across all skills
4. **CI integration** via GitHub Action (`agent-sh/agnix@v0`)
5. **MCP server** (`agnix-mcp`) -- could be added to simoge-mcp for in-conversation linting

### Vercel Research Finding

agnix README cites Vercel's research: skills invoke at **0%** without correct syntax. This is more extreme than the 20% community baseline, suggesting syntax errors (not just poor descriptions) can completely prevent activation.

---

## 5. Preference Sort for Skill Routing: Novel Proposal

### The Idea

Use a Bradley-Terry model (as in the existing Preference Sort service on SOL) to track which skills successfully activate for which prompt categories, and use the learned rankings to improve routing.

### Related Academic Work

**KABB: Knowledge-Aware Bayesian Bandits for Dynamic Expert Coordination** (Zhang et al., 2025, arXiv:2502.07350, ~38 citations S2) (T2)
- Uses Bradley-Terry pairwise comparison for expert scoring in multi-agent systems
- Three-dimensional knowledge distance model for semantic understanding
- Knowledge-aware Thompson Sampling for expert selection
- **Directly relevant:** This is essentially adaptive skill routing for multi-agent systems

**LLM Routing Survey** (Varangot-Reille et al., 2025, arXiv:2502.00409, ~14 citations S2) (T2)
- Formalizes routing as a performance-cost optimization problem
- Reviews: similarity-based, supervised, RL-based, and generative routing methods
- Contextual multi-armed bandit (MAB) model with discrete action space
- Key insight: routing should be adaptive, not static

**Reward Model Routing** (Wu & Lu, 2025, arXiv:2510.02850) (T2)
- Uses Bradley-Terry ranking head with bandit router
- Directly combines BT model with contextual bandits for LLM routing

### Proposed Architecture for SOL

```
                     User Prompt
                          |
                    [UserPromptSubmit hook]
                          |
                    skill-router.sh
                          |
            +-------------+-------------+
            |                           |
   [keyword/regex match]     [BT ranking lookup]
   (narrows to candidates)   (orders by past success)
            |                           |
            +-------------+-------------+
                          |
                   Top 3-5 skills
                          |
              [Forced eval instruction]
                          |
                   Claude processes
                          |
              [PostToolUse hook tracks]
              (did Claude actually invoke Skill?)
                          |
              [Record outcome in BT model]
```

**Implementation using existing SOL infrastructure:**

1. **Preference Sort service** (`:8093`, Bradley-Terry) already exists -- extend it with a `skill-routing` comparison list
2. **Prompt categorization:** Use embeddings (pgvector, `qwen3-embedding:8b`) to classify the prompt into a category
3. **Skill success tracking:** PostToolUse hook on the Skill tool records when a skill is actually invoked
4. **BT update:** Each successful activation = win for that skill in that prompt category
5. **Hook integration:** The UserPromptSubmit hook queries the BT rankings for the detected prompt category, gets top-N skills, and injects a forced eval instruction for just those skills

**Why this is novel:**
- Nobody has applied adaptive ranking to Claude Code skill routing (no prior art found)
- KABB (the closest paper) works at the multi-agent level, not within a single agent's skill system
- The BT model naturally handles the cold-start problem via prior probabilities
- It integrates with the existing Preference Sort infrastructure

**Expected improvement:** From 84% (forced eval) to potentially 90%+ by reducing the evaluation space from 105 to 3-5 pre-ranked skills. The forced eval hook's main remaining failure mode is likely attention dilution when too many skills are suggested.

### Data Model

```sql
-- In preference_sort database
-- A "comparison_list" for skill routing
-- Items are skills, comparisons track prompt-skill-outcome tuples

-- Extended with prompt category embedding for contextual bandits
CREATE TABLE skill_routing_context (
  id SERIAL PRIMARY KEY,
  prompt_embedding vector(4096),  -- qwen3-embedding
  prompt_category TEXT,           -- clustered category
  skill_name TEXT NOT NULL,
  activated BOOLEAN NOT NULL,     -- did Claude invoke it?
  timestamp TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 6. Implementation Plan for SOL

### Phase 0: Audit (1 hour)

1. Install agnix: `npm install -g agnix`
2. Run `agnix .claude/skills/ --target claude-code` on all 105 skills
3. Auto-fix safe issues: `agnix --fix-safe .claude/skills/`
4. Manual review of remaining warnings (especially description quality)

### Phase 1: Forced Eval Hook (30 minutes)

1. Create `~/.claude/hooks/skill-forced-eval-hook.sh` using the umputun pattern
2. Add to `~/.claude/settings.json` under `hooks.UserPromptSubmit`
3. Test with 10 diverse prompts, measure activation rate
4. Expected improvement: 20% -> ~80%

### Phase 2: Rule-Based Narrowing (2-4 hours)

1. Create `.claude/skills/skill-rules.json` with rules for the top 20-30 most-used skills
2. Create a TypeScript hook (diet103 pattern) that:
   - Reads user prompt from stdin
   - Matches against skill-rules.json
   - Outputs a focused forced-eval instruction with only matched skills
3. For the remaining 75 skills not in rules, fall back to generic forced eval
4. Expected improvement: ~80% -> ~85%

### Phase 3: Adaptive BT Routing (1-2 days)

1. Extend Preference Sort with a `skill_routing` comparison list
2. Create a PostToolUse hook on Skill tool that records activations
3. Create a categorization layer using pgvector prompt embeddings
4. Modify the UserPromptSubmit hook to query BT rankings
5. Expected improvement: ~85% -> ~90%+

### Phase 4: Continuous Learning (ongoing)

1. Add `meta_record_outcome` MCP tool calls to track actual utility (not just activation)
2. Periodic reranking based on accumulated data
3. Dashboard in Grafana for skill activation metrics

---

## Serendipitous Connections

### Connection to Ranking Todo project
The Preference Sort service (Bradley-Terry model, `:8093`) is the exact infrastructure needed for adaptive skill routing. This creates a novel feedback loop: the ranking system that helps the user prioritize tasks can also help the AI prioritize which skills to activate.

### Connection to Agent Framework project
The KABB paper (Knowledge-Aware Bayesian Bandits) directly applies to the Agent Framework's multi-agent orchestration. The three-dimensional knowledge distance model could be implemented using the existing pgvector embeddings to improve agent task assignment.

### Connection to SocialMCP project
Adaptive skill routing is essentially a micro-scale version of the autopoietic knowledge network concept -- the system learns which knowledge modules (skills) are relevant to which contexts, and the routing topology evolves based on usage.

### Connection to KORE-GC paper
The skill routing data (prompt -> skill -> outcome triples) creates a bipartite graph that could be stored in AGE. Graph-based analysis of skill co-activation patterns could reveal unexpected skill clusters.

---

## Sources

| Tier | Source | Used For |
|------|--------|----------|
| T2 | KABB (Zhang et al., 2025, arXiv:2502.07350, ~38 cit S2) | Bradley-Terry + bandits for multi-agent routing |
| T2 | LLM Routing Survey (Varangot-Reille et al., 2025, arXiv:2502.00409, ~14 cit S2) | Formal framework for routing optimization |
| T2 | Reward Model Routing (Wu & Lu, 2025, arXiv:2510.02850) | BT + bandit router combination |
| T5 | mellanon Skills Reference (GitHub Gist, Dec 2025) | Comprehensive skill mechanics documentation |
| T5 | Scott Spence (blog, Nov 2025) | Hook approaches, activation testing |
| T5 | Ivan Seleznov (Medium, Feb 2026, 650 trials) | Systematic activation testing |
| T5 | umputun (GitHub Gist) | Forced eval hook pattern (84% activation) |
| T5 | diet103/claude-code-infrastructure-showcase (GitHub) | Rule-based skill routing implementation |
| T5 | Paddo.dev (blog, Jan 2026) | Hook-driven activation analysis |
| T5 | claudefa.st | Skill activation hook guide |
| -- | Piebald-AI/claude-code-system-prompts (GitHub) | Extracted system prompts (v2.1.86) |
| -- | agent-sh/agnix (GitHub) | 342-rule agent config linter |
| T7 | Reddit r/ClaudeCode | Community discussion, activation reports |

**Not found / absence of evidence:**
- No peer-reviewed research specifically on Claude Code skill activation mechanics
- No prior art on Bradley-Terry models for intra-agent skill routing (the KABB paper is closest but operates at the inter-agent level)
- No official Anthropic documentation on the internal routing algorithm (confirmed to be pure LLM reasoning, not a separate classifier)
- Prompt hooks and agent hooks are NOT available for UserPromptSubmit -- confirmed from system prompts, not just community reports
