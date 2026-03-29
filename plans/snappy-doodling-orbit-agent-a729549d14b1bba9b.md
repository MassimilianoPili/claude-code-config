# Research: Claude Agent SDK -- Capabilities, Architecture, and Use Cases

## Executive Summary

The Claude Agent SDK is Anthropic's official library for embedding the Claude Code agent loop into custom applications. It wraps the Claude Code CLI as a subprocess, communicating via JSON-lines over stdin/stdout. Available in both Python (`claude-agent-sdk` on PyPI) and TypeScript (`@anthropic-ai/claude-agent-sdk` on npm). It provides sub-agents, MCP integration, hooks, sessions, custom tools, and permission management -- but with a critical architectural constraint: **it spawns a Claude Code CLI subprocess**, meaning it is not a pure API library.

**Epistemic status:** Well-documented, officially released product with public docs and GitHub repos.
**Confidence:** High -- based on official Anthropic documentation and GitHub repositories actually fetched.

---

## 1. What IS the Claude Agent SDK?

### Identity
- **Formerly**: Claude Code SDK (renamed to "Claude Agent SDK" to reflect broader use beyond coding)
- **Nature**: A wrapper that gives programmatic access to the same agent loop, tools, and context management that power Claude Code
- **NOT** a direct API wrapper -- that's the Anthropic Client SDK (`anthropic` package)
- **Key distinction**: The Client SDK gives you `client.messages.create()` and you implement the tool loop yourself. The Agent SDK gives you `query()` and Claude handles tool execution autonomously.

### Languages
| Language | Package | Repository |
|----------|---------|------------|
| Python 3.10+ | `claude-agent-sdk` (PyPI) | [anthropics/claude-agent-sdk-python](https://github.com/anthropics/claude-agent-sdk-python) |
| TypeScript (Node 18+) | `@anthropic-ai/claude-agent-sdk` (npm) | [anthropics/claude-agent-sdk-typescript](https://github.com/anthropics/claude-agent-sdk-typescript) |

### Relationship to Claude Code
The Agent SDK **bundles the Claude Code CLI** inside the package. When you call `query()`, it spawns a Claude Code CLI subprocess. Your Python/TypeScript code never calls the Anthropic API directly -- it delegates that to the CLI subprocess. The CLI handles:
- API calls to Claude (Anthropic, Bedrock, Vertex, or Azure)
- Built-in tool execution (Read, Edit, Bash, Glob, Grep, WebSearch, WebFetch)
- External MCP server management
- Context window management and compaction

Your application code handles:
- Control logic (permission callbacks, hooks)
- Custom in-process MCP tools
- Message stream consumption
- Session management

### Authentication
- `ANTHROPIC_API_KEY` (primary)
- Amazon Bedrock: `CLAUDE_CODE_USE_BEDROCK=1` + AWS creds
- Google Vertex AI: `CLAUDE_CODE_USE_VERTEX=1` + GCP creds
- Microsoft Azure: `CLAUDE_CODE_USE_FOUNDRY=1` + Azure creds

---

## 2. Capabilities

### 2.1 Built-in Tools

| Category | Tools | Description |
|----------|-------|-------------|
| File ops | `Read`, `Edit`, `Write` | Read, modify, create files |
| Search | `Glob`, `Grep` | Pattern-match files, regex search |
| Execution | `Bash` | Shell commands, scripts, git |
| Web | `WebSearch`, `WebFetch` | Search and fetch web content |
| Discovery | `ToolSearch` | On-demand tool loading (deferred) |
| Orchestration | `Agent`, `Skill`, `AskUserQuestion`, `TodoWrite` | Subagents, skills, user input, task tracking |

### 2.2 Sub-agents

**Yes, the SDK supports sub-agents.** Key characteristics:

- **Definition**: Programmatic via `AgentDefinition` (description, prompt, tools, model) or filesystem-based (`.claude/agents/*.md`)
- **Context isolation**: Each subagent runs in its own fresh conversation window. Only its final message returns to the parent.
- **Parallel execution**: Multiple subagents CAN run concurrently. The main agent spawns them, and they report back.
- **Nesting depth**: **ONE level only.** Subagents CANNOT spawn their own subagents (`Agent` tool must NOT be in a subagent's tools list).
- **Model override**: Each subagent can use a different model (`sonnet`, `opus`, `haiku`, `inherit`).
- **Tool restrictions**: Each subagent can have a restricted tool set.
- **Resumable**: Subagents can be resumed via their agent ID within the same session.
- **Built-in general-purpose**: Even without custom definitions, Claude can invoke a built-in `general-purpose` subagent when `Agent` is in allowed tools.

**Limitation**: Only one level of nesting. No recursive sub-agent spawning.

### 2.3 MCP Integration

**Full MCP support with three transport types:**

| Transport | Use case | Configuration |
|-----------|----------|---------------|
| **stdio** | Local process MCP servers | `command` + `args` + `env` |
| **HTTP** | Remote MCP servers (non-streaming) | `type: "http"`, `url`, `headers` |
| **SSE** | Remote MCP servers (streaming) | `type: "sse"`, `url`, `headers` |
| **SDK MCP server** | In-process custom tools | `create_sdk_mcp_server()` / `createSdkMcpServer()` |

Key features:
- Tool naming: `mcp__<server-name>__<tool-name>`
- Wildcard permissions: `mcp__github__*`
- **Tool search**: Auto-defers loading when MCP tools exceed 10% of context (configurable)
- OAuth2 support via manual token passing in headers
- `.mcp.json` config file auto-loading
- Error handling via init message server status

**Critical for our use case**: The SDK can connect to our `simoge-mcp` SSE server at `http://localhost:8099/sse` or `https://mcp.massimilianopili.com/sse` with JWT/API Key auth via headers.

### 2.4 Custom In-Process Tools

The SDK supports defining tools that run inside the application process (no separate MCP server):
- Python: `@tool` decorator + `create_sdk_mcp_server()`
- TypeScript: `tool()` function + `createSdkMcpServer()`
- **Performance advantage**: No subprocess overhead, no IPC serialization
- Tools receive control requests from the CLI subprocess and execute Python/TS functions directly

### 2.5 Hooks

Callbacks at key lifecycle points:

| Hook | When | Use case |
|------|------|----------|
| `PreToolUse` | Before tool execution | Validate, block, modify inputs |
| `PostToolUse` | After tool returns | Audit, log, trigger side effects |
| `UserPromptSubmit` | When prompt is sent | Inject context |
| `Stop` | Agent finishes | Validate result, save state |
| `SubagentStart/Stop` | Subagent lifecycle | Track parallel tasks |
| `PreCompact` | Before context compaction | Archive transcript |
| `SessionStart/End` | Session lifecycle | Setup/teardown |

Hooks run in the application process, not in the agent's context window (no context cost).

### 2.6 Sessions

- Session IDs for resuming conversations
- Full context restoration on resume
- Session forking for exploring different approaches
- `ClaudeSDKClient` handles sessions automatically in Python

### 2.7 Permissions

| Mode | Behavior |
|------|----------|
| `default` | Tools not in allow-list trigger callback |
| `acceptEdits` | Auto-approve file edits |
| `plan` | No execution, plan only |
| `dontAsk` (TS only) | Deny anything not pre-approved |
| `bypassPermissions` | All tools run without asking |

Fine-grained: `Bash(npm:*)` to allow only npm commands.

### 2.8 Control Options

| Option | Purpose |
|--------|---------|
| `max_turns` | Cap tool-use round trips |
| `max_budget_usd` | Spend limit |
| `effort` | low / medium / high / max reasoning depth |
| `model` | Pin specific model |
| `system_prompt` | Custom system prompt |
| `setting_sources` | Load CLAUDE.md, skills from project |

### 2.9 Parallel Tool Execution

Within a single turn, the SDK can run tools concurrently:
- **Read-only tools** (`Read`, `Glob`, `Grep`, read-only MCP): concurrent
- **State-modifying tools** (`Edit`, `Write`, `Bash`): sequential
- Custom tools: sequential by default, concurrent if marked `readOnly`

---

## 3. Architecture

### 3.1 Internal Execution Model

```
Your App (Python/TS)
    |
    | spawns subprocess
    v
Claude Code CLI (bundled)
    |
    | JSON-lines over stdin/stdout
    |
    +---> Anthropic API (or Bedrock/Vertex/Azure)
    +---> Built-in tools (file ops, shell, web)
    +---> External MCP servers (stdio/HTTP/SSE subprocesses)
    |
    | control requests (permission, hooks)
    v
Your App (callbacks)
```

**Communication protocol**: JSON-lines over stdin/stdout with request-ID multiplexing for concurrent control requests.

**Two modes**:
1. **Query mode** (`query()`): One-shot. Spawns CLI, sends prompt, streams responses, terminates. Process overhead per call.
2. **Client mode** (`ClaudeSDKClient`): Interactive. Spawns CLI once via `connect()`, sends multiple queries over same process. Better for multi-turn.

### 3.2 Comparison with Other Frameworks

| Feature | Claude Agent SDK | LangChain/LangGraph | CrewAI | AutoGen | OpenAI Agents SDK |
|---------|-----------------|---------------------|--------|---------|-------------------|
| **Nature** | CLI wrapper with built-in tools | Framework + integrations | Multi-agent framework | Conversation framework | API wrapper |
| **Tool execution** | Built-in (file, shell, web) | You implement | You implement | You implement | You implement |
| **Sub-agents** | Yes (1 level) | LangGraph nodes | Role-based crews | Multi-agent chat | Handoffs |
| **MCP support** | Native (3 transports) | Via adapters | Limited | Limited | Limited |
| **Context management** | Auto-compaction | Manual | Manual | Manual | Manual |
| **Model lock-in** | Claude only | Any LLM | Any LLM | Any LLM | OpenAI only |
| **Execution overhead** | Subprocess per session | In-process | In-process | In-process | In-process |
| **Learning curve** | Low (query + stream) | High (chains, graphs) | Medium (crews, roles) | Medium (agents, chat) | Low |
| **Custom orchestration** | Limited (1-level subagents) | Full (LangGraph) | Moderate | Full | Moderate |

**Key insight**: The Agent SDK is NOT a general orchestration framework. It's Claude Code as a library. It excels at autonomous file/code/shell tasks but has limited orchestration primitives compared to LangGraph or AutoGen.

---

## 4. Assessment for Our Use Case

### 4.1 What We Want to Build

A meta-orchestrator that:
1. Calls `meta_predict_agent` (MCP tool) to decide which agent to spawn
2. Spawns multiple agents in parallel
3. Collects results and feeds them to a Council deliberation
4. Tracks outcomes for GP training
5. Applies MCTS-style dispatch, failure recovery, etc.

### 4.2 Can the Agent SDK Do This?

| Requirement | Agent SDK Support | Assessment |
|-------------|-------------------|------------|
| Call MCP tools for dispatch | YES -- full MCP support (SSE, headers) | Works directly |
| Spawn multiple agents in parallel | PARTIALLY -- subagents run in parallel but only 1 level deep | Limitation: no recursive orchestration |
| Collect and aggregate results | YES -- via PostToolUse hooks and SubagentStop | Works but basic |
| Council deliberation (feed results to another agent) | NOT DIRECTLY -- no built-in pattern for multi-step aggregation | Must implement manually |
| GP training / outcome tracking | NO -- no built-in outcome tracking | Must implement externally |
| MCTS dispatch | NO -- no built-in search tree | Must implement externally |
| Dynamic agent selection | PARTIALLY -- dynamic AgentDefinition factories | But limited to predefined agents per query |
| Failure recovery / retry | PARTIALLY -- max_turns, max_budget, hooks | No built-in retry-with-different-strategy |

### 4.3 Architecture Options Assessment

#### Option A: Agent SDK as Orchestrator (Python/TypeScript)

```
Python Orchestrator
    |
    +--- Agent SDK query() --> SubAgent 1 (researcher)
    +--- Agent SDK query() --> SubAgent 2 (analyst)
    +--- Agent SDK query() --> SubAgent 3 (critic)
    |
    +--- Aggregate results
    +--- Agent SDK query() --> Council agent (deliberation)
    +--- Log outcomes to GP training
```

**Pros**:
- Full Claude Code tooling (file ops, shell, web search) in each agent
- Sessions for multi-turn conversations
- Hooks for monitoring and control
- MCP integration for our existing tools
- Built-in context management

**Cons**:
- Subprocess overhead per agent (CLI process per query)
- 1-level subagent nesting -- no nested orchestration
- Claude-only (can't mix models from different providers)
- The orchestrator logic must be in Python/TS, not in the agent loop itself
- Cost: each subagent = separate API call with fresh context
- No Java support (our MCP server is Java/Spring)

**Verdict**: Possible but not ideal. The orchestration must happen OUTSIDE the agent loop.

#### Option B: Pure MCP Tool Library (Java, on simoge-mcp)

```
Claude Code (interactive or SDK)
    |
    +--- MCP call: meta_predict_agent(task) --> agent type
    +--- MCP call: spawn_agent(type, prompt) --> starts background agent
    +--- MCP call: spawn_agent(type, prompt) --> starts background agent
    +--- MCP call: wait_agents([id1, id2]) --> results
    +--- MCP call: council_deliberate(results) --> synthesis
    +--- MCP call: log_outcome(task, result, quality)
```

**Pros**:
- Runs on existing Java MCP infrastructure
- Claude Code (or any MCP client) can drive it
- No subprocess overhead -- tools run in-process on Spring Boot
- Can integrate with AGE graph, pgvector, Redis directly
- Can mix models via proxy-ai
- Full control over orchestration logic
- Language-agnostic clients (any MCP client)

**Cons**:
- Must implement agent loop ourselves (or use Anthropic Client SDK in Java)
- No built-in Claude Code tools (file ops, shell)
- More development effort
- Must handle context management manually

**Verdict**: More flexible but more work. Best if we want model-agnostic orchestration.

#### Option C: Hybrid -- Agent SDK + MCP Orchestration Tools

```
Python Orchestrator (Agent SDK)
    |
    +--- query(prompt, mcp_servers={simoge-mcp})
    |       |
    |       +--- MCP: meta_predict_agent(task)
    |       +--- Spawns subagents based on prediction
    |       +--- MCP: log_outcome(result)
    |
    +--- Outer loop: GP training, MCTS state
```

**Pros**:
- Best of both worlds: Claude Code tools + our MCP infrastructure
- Agent SDK handles individual agent execution
- Python orchestrator handles meta-logic (GP, MCTS, Council)
- MCP tools provide the bridge
- Can use hooks for monitoring

**Cons**:
- Two languages (Python orchestrator + Java MCP server)
- Subprocess overhead still present
- Complexity of two systems

**Verdict**: Most practical path. The Agent SDK handles what it does well (autonomous agent execution), and our MCP infrastructure handles what IT does well (data access, tool orchestration, model routing).

#### Option D: Claude Code Hooks + Plugins + Agent Definitions (No SDK)

```
Claude Code (interactive)
    |
    +--- .claude/agents/*.md (agent definitions)
    +--- .claude/hooks/ (14 existing hooks)
    +--- .claude/plugins/ (41 existing plugins)
    +--- .mcp.json (simoge-mcp connection)
```

**Pros**:
- Zero development: already deployed on SOL
- Agent definitions in markdown
- Hooks already configured
- MCP already connected

**Cons**:
- Interactive only (not programmatic)
- No parallel agent execution
- No meta-orchestration logic
- No GP training loop
- Limited to what Claude decides to do

**Verdict**: Good for daily use, insufficient for the meta-orchestrator vision.

### 4.4 Recommendation

**Option C (Hybrid)** is the most practical path:

1. **Python orchestrator** using the Agent SDK for agent execution
2. **simoge-mcp** for prediction, logging, graph access, embedding search
3. **Custom Python logic** for GP selection, MCTS dispatch, Council aggregation
4. **Redis** (existing) for inter-agent communication and state

### 4.5 Python vs TypeScript

**Python is better for this use case:**
- Scientific computing libraries (numpy, scipy) for GP/MCTS
- Stronger async ecosystem (anyio, asyncio)
- Better ML tooling if we add learned components
- The Agent SDK Python version uses anyio (works with asyncio and trio)
- TypeScript advantage (streaming, async iterators) is equally available in Python

---

## 5. Key Technical Details for Implementation

### 5.1 Connecting to simoge-mcp

```python
from claude_agent_sdk import query, ClaudeAgentOptions

async for message in query(
    prompt="Research topic X using the research tools",
    options=ClaudeAgentOptions(
        mcp_servers={
            "simoge": {
                "type": "sse",
                "url": "http://localhost:8099/sse",
                # Or with auth:
                # "url": "https://mcp.massimilianopili.com/sse",
                # "headers": {"X-API-Key": "<api-key>"}
            }
        },
        allowed_tools=["mcp__simoge__*"],
    ),
):
    ...
```

### 5.2 Parallel Agent Execution Pattern

```python
import asyncio
from claude_agent_sdk import query, ClaudeAgentOptions, AgentDefinition

async def run_research_agent(topic: str) -> str:
    result = None
    async for message in query(
        prompt=f"Research: {topic}",
        options=ClaudeAgentOptions(
            allowed_tools=["Read", "Glob", "Grep", "WebSearch", "WebFetch"],
            max_turns=15,
            max_budget_usd=0.50,
            effort="high",
        ),
    ):
        if hasattr(message, "result") and message.subtype == "success":
            result = message.result
    return result

# Run multiple agents in parallel
results = await asyncio.gather(
    run_research_agent("quantum error correction"),
    run_research_agent("topological insulators"),
    run_research_agent("holographic duality"),
)
```

Note: Each `query()` spawns a separate CLI subprocess. True parallelism at the process level.

### 5.3 Council Deliberation Pattern

```python
async def council_deliberate(findings: list[str]) -> str:
    combined = "\n\n---\n\n".join(
        f"## Agent {i+1} findings:\n{f}" for i, f in enumerate(findings)
    )

    async for message in query(
        prompt=f"""You are a Council deliberation agent. Multiple research agents have
produced findings. Synthesize them, identify agreements and disagreements,
and produce a final assessment.

{combined}""",
        options=ClaudeAgentOptions(
            allowed_tools=[],  # Pure reasoning, no tools
            effort="max",
            model="claude-opus-4-6",
        ),
    ):
        if hasattr(message, "result") and message.subtype == "success":
            return message.result
```

### 5.4 Cost Tracking

Every `ResultMessage` includes:
- `total_cost_usd`: Total cost of the session
- `usage`: Token counts (input, output, cache)
- `num_turns`: Number of tool-use turns

Essential for GP training: track cost vs. quality per agent type.

---

## 6. What the SDK CANNOT Do

1. **No recursive sub-agents** -- only 1 level deep
2. **No cross-agent communication** during execution -- subagents are isolated
3. **No built-in retry with different strategy** -- only max_turns/max_budget limits
4. **No model mixing** -- Claude only (though different Claude models per subagent)
5. **No Java SDK** -- Python and TypeScript only
6. **No in-process API calls** -- always goes through CLI subprocess
7. **No shared memory between agents** -- each has isolated context
8. **No streaming input for query()** -- custom tools with MCP require ClaudeSDKClient or async generators
9. **No built-in orchestration patterns** -- no DAG, no state machine, no workflow engine

---

## 7. Serendipitous Connections

### Agent SDK <-> Preference Sort (Ranking Todo project)
The Council deliberation pattern maps directly to preference aggregation. Multiple agent "opinions" can be treated as pairwise preferences in a Bradley-Terry model. The SDK's cost tracking per agent provides a natural quality signal for the GP fitness function.

### Agent SDK <-> Knowledge Graph (Kindle Graph Enrichment)
Subagents with read-only tools could serve as specialized extractors: one for entities, one for relationships, one for themes. Results aggregate into the Neo4j/AGE knowledge graph. The SDK's MCP support means these agents can directly query the graph via simoge-mcp tools.

### Subprocess Architecture <-> Agent COBOL
The SDK's CLI-subprocess model is structurally similar to how Agent COBOL would need to wrap legacy compilers. The JSON-lines protocol over stdin/stdout is a reusable pattern for wrapping any CLI tool as an agent.

---

## 8. Open Questions for Further Research

1. **What is the subprocess startup latency?** Relevant for MCTS where many short-lived agents are needed.
2. **Can we share sessions across SDK instances?** Would enable agent handoffs without context loss.
3. **What is the maximum number of concurrent `query()` calls?** Process limits? API rate limits?
4. **Does the SDK support structured output validation?** (The result subtypes suggest yes: `error_max_structured_output_retries`)
5. **Can hooks modify the system prompt dynamically between turns?** Would enable GP-driven prompt evolution.
6. **What happens when simoge-mcp SSE connection drops mid-agent?** Recovery behavior.

---

## Sources

### Official Documentation (fetched and read)
- [Agent SDK Overview](https://platform.claude.com/docs/en/agent-sdk/overview) -- Anthropic official docs
- [Agent SDK Quickstart](https://platform.claude.com/docs/en/agent-sdk/quickstart) -- Setup and first agent
- [Agent SDK MCP Integration](https://platform.claude.com/docs/en/agent-sdk/mcp) -- MCP transport types, auth, tool search
- [Agent SDK Subagents](https://platform.claude.com/docs/en/agent-sdk/subagents) -- Subagent architecture, limitations
- [Agent SDK Agent Loop](https://platform.claude.com/docs/en/agent-sdk/agent-loop) -- Internal execution model
- [Agent SDK Custom Tools](https://platform.claude.com/docs/en/agent-sdk/custom-tools) -- In-process MCP tools
- [Building Agents with the Claude Agent SDK](https://claude.com/blog/building-agents-with-the-claude-agent-sdk) -- Anthropic engineering blog

### GitHub Repositories (fetched)
- [claude-agent-sdk-python](https://github.com/anthropics/claude-agent-sdk-python) -- Python SDK, MIT license
- [claude-agent-sdk-typescript](https://github.com/anthropics/claude-agent-sdk-typescript) -- TypeScript SDK
- [claude-agent-sdk-demos](https://github.com/anthropics/claude-agent-sdk-demos) -- Example agents

### Package Registries
- [PyPI: claude-agent-sdk](https://pypi.org/project/claude-agent-sdk/)
- [npm: @anthropic-ai/claude-agent-sdk](https://www.npmjs.com/package/@anthropic-ai/claude-agent-sdk)

### Architecture Analysis (fetched)
- [Inside the Claude Agent SDK: From stdin/stdout Communication to Production](https://buildwithaws.substack.com/p/inside-the-claude-agent-sdk-from) -- Detailed subprocess architecture analysis

### Framework Comparisons (search results)
- [AI Agent Frameworks Compared (2026)](https://arsum.com/blog/posts/ai-agent-frameworks/) -- Multi-framework comparison
- [The Developer's Guide to AI Agent Frameworks 2025](https://dev.to/hani__8725b7a/agentic-ai-frameworks-comparison-2025-mcp-agent-langgraph-ag2-pydanticai-crewai-h40) -- MCP-native vs traditional
