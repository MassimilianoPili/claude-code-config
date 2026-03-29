# MCP Ecosystem Survey -- March 2026

**Epistemic status:** Active, fast-moving ecosystem. Most findings are from T7 sources (blogs, GitHub, vendor docs). Protocol spec details are from official MCP blog (near T1). Confidence varies per section.

**Confidence:** Medium -- ecosystem is real and growing, but hype-to-substance ratio is high. I have verified URLs and cross-referenced multiple sources. No fabricated citations.

---

## 1. MCP Protocol Evolution (since Nov 2025)

### 1.1 Spec Timeline

| Date | Release | Key additions |
|------|---------|---------------|
| 2025-03-26 | Initial spec refresh | Streamable HTTP transport replaces SSE as recommended remote transport |
| 2025-06-18 | June spec | Structured tool outputs, OAuth 2.1 authorization, Elicitation (server-initiated user interaction), security best practices |
| 2025-11-25 | One-year anniversary spec | URL-mode elicitation (server can redirect user to external URL for OAuth/payment), Resource Indicators (RFC 8707) mandatory for token scoping |
| 2025-12-19 | Transport future blog post | Announced next-gen transport work: stateless Streamable HTTP across load balancers, session migration |
| 2026-03-05 | 2026 Roadmap published | Four priority areas (see below) |

Source: `blog.modelcontextprotocol.io` (official MCP blog), `modelcontextprotocol.io/development/roadmap`

### 1.2 The 2026 Roadmap -- Four Priority Areas

1. **Transport Evolution** -- Evolve Streamable HTTP to work statelessly across multiple server instances; correct behavior behind load balancers and proxies; scalable session handling (create, resume, migrate). WebSocket transport is under SEP-1288 discussion but not confirmed.

2. **Agent-to-Agent Communication** -- MCP between agents, not just client-to-server. This overlaps with Google/Linux Foundation A2A protocol.

3. **Governance Maturation** -- SEP (Spec Enhancement Proposal) process bottleneck: currently all proposals require full core maintainer review. Working Groups will get delegated review authority. Working Groups and Interest Groups are the vehicles for contribution.

4. **Enterprise Readiness** -- Compliance frameworks, audit logging, multi-tenancy patterns.

Next spec release: **tentatively June 2026**.

Source: `blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/`, `thenewstack.io/model-context-protocol-roadmap-2026/`

### 1.3 Key Protocol Features You Should Know About

#### Streamable HTTP (replaces SSE)
- Client POSTs JSON-RPC to `/mcp` endpoint
- Server responds with either direct JSON (fast ops) or switches to `Content-Type: text/event-stream` for streaming
- Client can also open GET to same endpoint for async server-initiated events
- `Mcp-Session-Id` header for session tracking
- **SSE transport is now deprecated** -- Atlassian announced SSE deprecation by June 30, 2026

**Relevance to SOL:** Your Go mcp-proxy currently handles SSE. You should plan migration to Streamable HTTP. Spring AI already supports `spring.ai.mcp.server.protocol=STREAMABLE` (see 1.4 below). The proxy would need updating to handle the POST+GET dual-connection model.

**Confidence: HIGH** -- this is from official spec and multiple implementations confirm it.

#### Elicitation
- Server can request user input mid-tool-execution via `elicitations/create`
- Two modes: **inline** (form fields in the MCP client UI) and **URL** (redirect user to external URL)
- URL-mode enables: secure credential collection (keys never transit MCP client), external OAuth flows, payment confirmations
- Spring AI supports it: `@McpElicitation` annotation, Baeldung tutorial available

**Relevance to SOL:** Could enable your MCP tools to request Keycloak authentication mid-flow, or collect API keys without embedding them in tool configs.

**Confidence: HIGH** -- in official spec since June 2025, SDK support confirmed.

#### OAuth 2.1 Authorization
- MCP servers are now formally OAuth Resource Servers
- Resource Indicators (RFC 8707) mandatory to prevent token misuse
- Multiple OAuth flavors in play: OIDC-based, On-Behalf-Of (OBO), Elicitation-triggered OAuth to third parties, token exchange
- WorkOS launched "MCP Auth" as a commercial product for this

**Relevance to SOL:** Your current HMAC API Key auth on mcp-proxy is simpler but non-standard. If you want to expose MCP to third parties or interoperate with other MCP clients, OAuth 2.1 is the direction. Keycloak can serve as the authorization server.

**Confidence: MEDIUM** -- spec is clear, but practical self-hosted implementation guides are sparse.

### 1.4 Spring AI MCP Updates

Spring AI 1.1.x now supports:
- **Streamable HTTP transport**: `spring.ai.mcp.server.protocol=STREAMABLE` (Spring MVC based)
- **Elicitation**: `@McpElicitation` annotation support (Baeldung + AWS Builder Center tutorials)
- **Client annotations**: `@McpSampling` for handling sampling requests
- **Official Java SDK**: `github.com/modelcontextprotocol/java-sdk`

**Relevance to SOL:** Your `simoge-mcp` runs Spring AI 1.1.3 with SSE transport (`WebFluxSseServerTransportProvider`). You can migrate to Streamable HTTP by switching to the Spring MVC starter and setting `protocol=STREAMABLE`. This would simplify your Go proxy (no more SSE connection management).

**Confidence: HIGH** -- official Spring docs confirm.

### 1.5 MCP SDK Versions (March 2026)

| SDK | Version | Notable |
|-----|---------|---------|
| TypeScript | v1.27.1 (Feb 2026) | Auth pre-registration conformance, SEP-1730 Tier 1 features, command injection fix |
| C# | v1.0 (Mar 2026) | First stable release, full Streamable HTTP + elicitation |
| Java | Official SDK exists | Spring AI wraps it |
| Python | `mcp` on PyPI | Full elicitation support including URL mode |

Source: `devblogs.microsoft.com`, `contextstudios.ai`, `pypi.org/project/mcp/`

---

## 2. New MCP Servers -- Relevant to Self-Hosted Infrastructure

### 2.1 PRIORITY 1 -- Highly Relevant to SOL

#### Grafana MCP Server (Official)
- **URL:** `github.com/grafana/mcp-grafana`
- **Docker:** `hub.docker.com/mcp/server/grafana` (Docker MCP Catalog)
- **What:** Query dashboards, fetch datasource info, query Prometheus/Loki/ClickHouse/CloudWatch/Elasticsearch, manage incidents, Grafana OnCall, Sift investigations, alerting rules
- **Transport:** stdio + SSE
- **Relevance:** You run Prometheus+Grafana+Loki. This would let Claude query your monitoring stack directly -- "show me the top 5 containers by CPU in the last hour" or "check if there were any alerts overnight."
- **Confidence: HIGH** -- official Grafana Labs project, well-documented, Docker image available.
- **Priority: INVESTIGATE FIRST**

#### Prometheus MCP Server
- **URL:** `hub.docker.com/mcp/server/prometheus`
- **What:** Direct Prometheus PromQL queries via MCP. 50K+ pulls on Docker Hub.
- **Relevance:** More focused than Grafana MCP -- pure metrics querying. Could complement or replace the Grafana one depending on whether you want dashboard access too.
- **Confidence: HIGH**

#### Official Redis MCP Server
- **URL:** `github.com/redis/mcp-redis`
- **What:** Natural language queries and updates to Redis. Official from Redis Inc.
- **Relevance:** You already have `mcp-redis-tools` (custom). Compare capabilities -- the official one may have features yours doesn't (e.g., Redis Streams, cluster support).
- **Confidence: HIGH** -- official Redis project.

#### Gitea MCP Server (Official)
- **URL:** `gitea.com/gitea/gitea-mcp`
- **What:** Official Gitea MCP integration plugin. Connects Gitea with MCP systems.
- **Relevance:** You already have `mcp-gitea-tools` (17 tools, custom). Compare with official -- official may track Gitea API changes better. Consider contributing your tools upstream or switching if the official one is more complete.
- **Confidence: MEDIUM** -- exists but unclear how complete vs your custom implementation.

#### Docker MCP Server (Official)
- **URL:** Part of Docker MCP Catalog, `hub.docker.com/mcp/server/docker`
- **What:** Advanced unified Docker management via MCP. Container lifecycle, images, networks, volumes.
- **Relevance:** You already have `docker-tools` (34 tools). The official Docker one may have tighter integration with Docker Desktop features. Compare coverage.
- **Confidence: HIGH**

### 2.2 PRIORITY 2 -- Worth Investigating

#### Graphiti (Zep) -- Temporal Knowledge Graphs
- **URL:** `github.com/getzep/graphiti`
- **What:** MCP server that uses temporally-aware knowledge graphs as AI agent memory. Recent Docker deployment improvements.
- **Relevance:** Your KORE system (AGE + pgvector) is similar in concept. Graphiti might have interesting approaches to temporal versioning of knowledge that could inform KORE-GC paper research.
- **Confidence: MEDIUM**

#### OpenLIT -- MCP Observability
- **URL:** Referenced in `grafana.com/blog/ai-observability-MCP-servers/`
- **What:** Monitor MCP server usage and performance. OpenTelemetry-based. Self-hostable via Docker Compose.
- **Relevance:** As you run 290+ MCP tools, observability of tool calls (latency, error rates, usage patterns) would be valuable. Integrates with your existing Grafana.
- **Confidence: MEDIUM** -- Grafana blog reference is solid.

#### Elasticsearch MCP Server
- **URL:** Docker MCP Catalog
- **What:** Full-text search via MCP. From Elastic official.
- **Relevance:** Low direct relevance (you use pgvector), but interesting if you ever add log search beyond Loki.

#### ArgoCD MCP Server
- **URL:** `mcpservers.org` listing
- **What:** Exposes entire ArgoCD API via MCP using auto-generated tools from OpenAPI spec.
- **Relevance:** Pattern is interesting -- auto-generating MCP tools from OpenAPI specs. Could apply this to your own services.
- **Confidence: LOW** -- listing only, not deeply verified.

#### Testkube MCP Server
- **URL:** `hub.docker.com/u/mcp` (Docker Hub)
- **What:** Continuous testing capabilities -- test orchestration and execution via MCP.
- **Relevance:** Could integrate with your Jenkins CI/CD pipeline for test-driven agent workflows.
- **Confidence: LOW**

### 2.3 Docker MCP Catalog -- The New Distribution Channel

Docker launched the **MCP Catalog** at `mcp.docker.com` with 270+ containerized MCP servers. Key features:

- **MCP Profiles:** Named collections of MCP servers with pre-configured settings. Share team configurations.
- **Docker MCP Toolkit:** Handles isolation, credential management, and lifecycle for MCP servers in containers.
- **Hub MCP Server:** Meta-server that searches Docker Hub itself via MCP.

**Relevance:** This is the emerging standard way to distribute MCP servers. Your custom servers could be published here for wider distribution. The Profile system could standardize your SOL MCP configuration across devices.

Source: `docs.docker.com/ai/mcp-catalog-and-toolkit/`, `mcp.docker.com`
**Confidence: HIGH** -- Docker official docs.

### 2.4 MCP Gateways -- Emerging Category

Multiple MCP gateway/proxy products emerged in 2025-2026:
- **ToolHive (Stacklok):** Container runtime for MCP servers with security policies
- **MCP Manager:** Centralized management of multiple MCP servers
- **LiteLLM:** MCP gateway with elicitation and sampling support (GitHub issue #23761)

**Relevance:** Your `mcp-proxy` (Go, session resilience, HMAC auth) is already a gateway. These competitors may have features worth borrowing: security policy enforcement, tool-level access control, audit logging.

---

## 3. Claude Code Plugins Ecosystem

### 3.1 Ecosystem Scale

- **9,000+ plugins** in under 5 months since public beta (October 2025)
- Official Anthropic marketplace + community marketplaces
- Plugin = bundle of: slash commands + subagents + hooks + MCP servers

Source: `aitoolanalysis.com` (T7 -- marketing site, numbers may be inflated)

### 3.2 Notable Plugin Marketplaces / Collections

| Name | URL | Size | Focus |
|------|-----|------|-------|
| awesome-claude-code-plugins | `github.com/ccplugins/awesome-claude-code-plugins` | Curated list | Community best-of |
| awesome-claude-plugins (Composio) | `github.com/ComposioHQ/awesome-claude-plugins` | Curated list | Framework integrations |
| awesome-claude-code (hesreallyhim) | `github.com/hesreallyhim/awesome-claude-code` | Skills, hooks, commands, agents | Comprehensive |
| claude-night-market | `github.com/athola/claude-night-market` | 18 plugins, 142 skills, 109 commands, 47 agents | Git workflows, code review, spec-driven dev |
| claude-code-marketplace (Dev-GOM) | `github.com/Dev-GOM/claude-code-marketplace` | 5 commands + 4 agents + 3 hooks | Pair programming, review |
| awesome-claude-code-subagents (VoltAgent) | `github.com/VoltAgent/awesome-claude-code-subagents` | 100+ subagents | Wide range of dev use cases |
| ClaudePluginHub | `claudepluginhub.com` | Directory | Searchable |

### 3.3 Plugins Worth Investigating for SOL

#### claude-code-builder
- **URL:** `github.com/alexanderop/claude-code-builder` / `claudepluginhub.com/plugins/alexanderop-claude-code-builder`
- **What:** Meta-plugin that creates skills, subagents, hooks, commands, and plugins. Commands: `/create-hook`, `/create-md`, etc.
- **Relevance:** Speeds up creating new Claude Code extensions for your SOL-specific workflows.
- **Confidence: MEDIUM**

#### Night Market -- Git Workflows Plugin
- **What:** 18 production-ready plugins for git workflows, code review, spec-driven development, architecture patterns, resource optimization, multi-LLM delegation
- **Relevance:** The git workflow and code review agents could complement your Gitea setup.
- **Confidence: MEDIUM** -- well-documented GitHub repo.

#### Multi-Agent TDD Orchestration (glebis/claude-skills)
- **URL:** `github.com/glebis/claude-skills`
- **What:** Multi-agent TDD orchestration with architecturally enforced context isolation. AI research workflow.
- **Relevance:** Could inform your Agent Framework project's multi-agent patterns.
- **Confidence: LOW** -- individual project, not widely adopted.

### 3.4 Agent Teams -- The Big Claude Code Feature of 2026

Claude Code now supports **Agent Teams** -- orchestrating multiple Claude Code sessions in parallel:

- A "lead" agent plans and distributes work to "teammate" agents
- Each teammate runs in its own tmux pane with isolated context
- Recommended: 5-6 tasks per teammate
- Uses worktrees for git isolation

**Key insight from multiple sources:** "Single AI coding assistants hit a cognitive wall. One model, no matter how powerful, cannot maintain architectural consistency across a 50,000-line codebase while simultaneously implementing features, writing tests, and securing endpoints."

Source: `code.claude.com/docs/en/agent-teams`, `claudefa.st/blog/guide/agents/agent-teams`, multiple Medium posts

**Relevance:** This is different from your `claude_task_*` MCP tools for inter-Claude messaging. Agent Teams is built-in tmux-based parallelism. Your approach is more flexible (works across devices, persists in Redis), but Agent Teams has tighter integration with Claude Code's context management.

### 3.5 AI Coding Agent Dashboard (marcnuri.com)

- **URL:** `blog.marcnuri.com/ai-coding-agent-dashboard`
- **What:** Dashboard for orchestrating Claude Code across devices. Heartbeat model: each agent session reports state (project, git status, context usage, active MCP servers, current task) to a backend.
- **Relevance:** Very similar to what your `dashboard-api` + `claude-web` + `claude-coord` setup does. Worth reading for architectural ideas.
- **Confidence: MEDIUM**

---

## 4. MCP Security -- Critical Awareness

### 4.1 Known Attack Vectors

A significant body of security research has emerged around MCP in 2025-2026:

| Attack | Description | Severity |
|--------|-------------|----------|
| **Tool Poisoning** | Malicious tool descriptions that inject prompts into the LLM context, causing it to exfiltrate data or execute unintended actions | CRITICAL |
| **Rug Pull** | Server presents benign capabilities during `tools/list`, then switches to malicious tools after initial trust is established | HIGH |
| **Command Injection** | URL handling in MCP clients/SDKs. TypeScript SDK v1.27.1 patched one such vulnerability | HIGH |
| **OAuth token misuse** | Without Resource Indicators (RFC 8707), tokens scoped for one server could be reused on another | MEDIUM |
| **mcp-remote CVE-2025-6514** | OAuth vulnerability in the popular mcp-remote tool | HIGH |

Source: `vulnerablemcp.info`, `blog.doyensec.com/2026/03/05/mcp-nightmare.html`, `christian-schneider.net`, `toxsec.com`

### 4.2 Audit Findings

- **66% of scanned MCP servers had security findings** in a recent audit (per Toolradar)
- Doyensec published "The MCP AuthN/Z Nightmare" (March 2026) detailing fundamental auth design issues
- OWASP included MCP-related attacks in its LLM Top 10 for 2025

### 4.3 Relevance to SOL

Your setup has several mitigations already in place:
- HMAC auth on mcp-proxy (no anonymous access)
- All MCP tools are custom-written (no third-party server trust issues)
- Internal network (Tailscale) reduces exposure
- No public tool marketplace consumption

**Recommendation:** If you ever consume third-party MCP servers, use ToolHive (Stacklok) or Docker MCP Toolkit for container isolation. Pin tool descriptions and verify they don't change between sessions (anti-rug-pull).

---

## 5. Unknown Unknowns -- Creative Uses and Emerging Patterns

### 5.1 MCP Apps (Anthropic, January 2026)

Anthropic launched **MCP Apps** -- a way to package MCP servers as installable applications. This was announced January 26, 2026 per `mcpplaygroundonline.com`. Details are sparse but this suggests a consumer-facing distribution model beyond the developer-focused MCP server.

### 5.2 OpenAPI-to-MCP Auto-Generation

The ArgoCD MCP server pattern -- auto-generating MCP tools from an OpenAPI spec -- is becoming a recognized pattern. This could apply to any REST API you expose (Server API, Preference Sort API, Knowledge Graph API).

**Relevance to SOL:** You could auto-generate MCP tools for any new REST service you build, instead of hand-coding Spring AI `@Tool` annotations.

### 5.3 MCP for Non-Code Workflows

Multiple sources describe MCP being used for:
- **Incident management** via Grafana MCP + OnCall
- **Documentation generation** from code analysis
- **Security audits** as subagent workflows
- **Database administration** via natural language (official Postgres, Redis, MongoDB MCP servers exist)

### 5.4 Everything-Claude-Code Framework

- **URL:** `byteiota.com/everything-claude-code-production-agent-framework/`
- **What:** Production agent framework wrapping Claude Code. Competitors: DeerFlow 2.0 (ByteDance, LangGraph), TradingAgents (financial).
- **Relevance:** Your Agent Framework project occupies a similar space. The trend confirms multi-agent orchestration is a hot area.

### 5.5 Boris Cherny's Workflow (Claude Code Creator)

Boris Cherny (Claude Code creator) shared his personal workflow publicly (January 2026). Key pattern: using Claude Code as infrastructure, not just coding assistant. Multiple sources reference this as influential.

### 5.6 Lessons from Building Claude Code (Thariq Shihipar, Anthropic)

Published March 1, 2026. "A brutally honest" post about agent tool design principles from the Claude Code team. Referenced at `jinlow.medium.com`. Key lesson: tool design matters more than model capability for agent effectiveness.

**Relevance:** Directly applicable to your 290+ MCP tools. Tool naming, description quality, and parameter design are force multipliers.

---

## 6. Priority Ranking -- What to Investigate First

| # | Item | Category | Effort | Impact | Priority |
|---|------|----------|--------|--------|----------|
| 1 | **Migrate simoge-mcp to Streamable HTTP** | Protocol | Medium | High | NOW |
| 2 | **Deploy Grafana MCP Server** | New server | Low | High | THIS WEEK |
| 3 | **Review official Gitea MCP** vs yours | New server | Low | Medium | THIS WEEK |
| 4 | **Read Doyensec MCP security post** | Security | Low | High (awareness) | THIS WEEK |
| 5 | **Deploy Prometheus MCP Server** | New server | Low | Medium | NEXT WEEK |
| 6 | **Explore Agent Teams** feature | Productivity | Medium | High | NEXT WEEK |
| 7 | **Compare official Redis MCP** vs yours | New server | Low | Low | WHEN FREE |
| 8 | **Evaluate OpenLIT** for MCP observability | Monitoring | Medium | Medium | WHEN FREE |
| 9 | **Consider Elicitation** for Keycloak auth flows | Protocol | High | Medium | BACKLOG |
| 10 | **Investigate OpenAPI-to-MCP** generation | Pattern | Medium | Medium | BACKLOG |
| 11 | **Publish MCP servers to Docker MCP Catalog** | Distribution | Medium | Low | BACKLOG |
| 12 | **MCP Profiles** for multi-device config | Distribution | Low | Medium | BACKLOG |

---

## 7. Serendipitous Connections

1. **KORE-GC paper <-> Graphiti (Zep):** Graphiti's temporal knowledge graph approach directly relates to your graph-vector pruning research. Their handling of temporal versioning in a knowledge graph could be a comparison point in the related work section.

2. **Agent Framework <-> Agent Teams:** Claude Code's built-in Agent Teams and your custom Agent Framework solve the same problem differently. Agent Teams = tmux-local, ephemeral. Your framework = distributed, persistent, with HTN planning. The coexistence strategy is using Agent Teams for intra-session parallelism and your framework for cross-session orchestration.

3. **MCP OAuth 2.1 <-> Keycloak:** The MCP spec now mandates OAuth Resource Server semantics. Your Keycloak realm `sol` with 15 clients could serve as the authorization server for standard MCP OAuth, making your tools interoperable with any compliant MCP client.

4. **MCP security research <-> SocialMCP:** The tool poisoning and rug pull attacks are directly relevant to SocialMCP's autopoietic knowledge network -- if agents share tools, trust verification becomes critical. Your HMAC + A2A gateway design already partially addresses this.

---

## Sources Fetched

| Tier | Source | URL |
|------|--------|-----|
| T1-adjacent | MCP Official Blog | `blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/` |
| T1-adjacent | MCP Official Blog | `blog.modelcontextprotocol.io/posts/2025-11-25-first-mcp-anniversary/` |
| T1-adjacent | MCP Official Blog | `blog.modelcontextprotocol.io/posts/2025-12-19-mcp-transport-future/` |
| T1-adjacent | MCP Official Spec | `modelcontextprotocol.io/development/roadmap` |
| T7 | Claude Code Docs | `code.claude.com/docs/en/agent-teams` |
| T7 | Claude Code Docs | `code.claude.com/docs/en/plugins` |
| T7 | Anthropic Blog | `claude.com/blog/claude-code-plugins` |
| T7 | Spring AI Docs | `docs.spring.io/spring-ai/reference/api/mcp/` |
| T7 | Baeldung | `baeldung.com/spring-ai-mcp-elicitations` |
| T7 | Docker Docs | `docs.docker.com/ai/mcp-catalog-and-toolkit/` |
| T7 | WorkOS Blog | `workos.com/blog/everything-your-team-needs-to-know-about-mcp-in-2026` |
| T7 | The New Stack | `thenewstack.io/model-context-protocol-roadmap-2026/` |
| T7 | Doyensec | `blog.doyensec.com/2026/03/05/mcp-nightmare.html` |
| T7 | Grafana Labs | `github.com/grafana/mcp-grafana` |
| T7 | Redis Official | `github.com/redis/mcp-redis` |
| T7 | Gitea Official | `gitea.com/gitea/gitea-mcp` |
| T7 | MCP Java SDK | `github.com/modelcontextprotocol/java-sdk` |
| T7 | Context Studios | `contextstudios.ai/blog/mcp-ecosystem-in-2026-what-the-v127-release-actually-tells-us` |
| T7 | Security Boulevard | `securityboulevard.com/2026/03/is-all-oauth-the-same-for-mcp/` |
| T7 | Toolradar | `toolradar.com/guides/best-mcp-servers` |
| T7 | Multiple GitHub repos | Various awesome-* lists |
