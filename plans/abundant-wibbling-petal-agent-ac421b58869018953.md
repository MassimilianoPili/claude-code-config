# MCP Ecosystem Research: State of the Art (March 2026)

## Research Summary

**Epistemic status:** Active, rapidly evolving ecosystem. Strong consensus on core protocol; significant experimentation on patterns and best practices.
**Confidence:** High for ecosystem landscape (multiple primary sources fetched). Medium for specific tool recommendations (based on GitHub repos, not production validation).
**Sources fetched:** 15+ web pages including official MCP spec, awesome-lists, blog posts, GitHub repos.

---

## 1. Ecosystem Landscape: What Exists

The MCP ecosystem has exploded from ~50 reference servers (Nov 2024) to **7,260+ catalogued servers** (TensorBlock count, May 2025) and likely 10K+ by now. Key awesome-lists:

- [punkpeye/awesome-mcp-servers](https://github.com/punkpeye/awesome-mcp-servers) -- most curated
- [TensorBlock/awesome-mcp-servers](https://github.com/TensorBlock/awesome-mcp-servers) -- largest (7,260+)
- [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) -- official reference
- [mcp-awesome.com](https://mcp-awesome.com) -- 1,200+ quality-verified

### Categories That Exist in the Wild

| Category | Examples | Your Coverage |
|----------|----------|---------------|
| File Systems | filesystem, S3, FTP | COVERED (fs_*, s3_*) |
| Databases | PostgreSQL, MongoDB, Redis, SQLite | COVERED (db_*, redis_*, graph_*) |
| Git/Version Control | git operations, GitHub, GitLab, Gitea | COVERED (gitea_*) |
| Web Search/Fetch | Brave, SearXNG, fetch | COVERED (web_*) |
| Docker/Containers | Docker management, K8s | COVERED (docker_*, ocp_*) |
| Code Navigation | LSP, AST, refactoring | COVERED (code_*) |
| AI/LLM | Ollama, OpenAI, local models | COVERED (llm_*) |
| Embeddings/Vectors | pgvector, similarity search | COVERED (embeddings_*) |
| Browser Automation | Playwright, Puppeteer | COVERED (playwright_*) |
| Knowledge Graphs | Neo4j, AGE, memory | COVERED (graph_*) |
| Academic Research | Semantic Scholar, arXiv, OpenAlex | COVERED (openalex_*, research_*) |
| PDF Processing | Extract, search, split | COVERED (pdf_*) |
| CSV/JSON/YAML | Parse, transform, query | COVERED (csv_*, json_*, yaml_*) |
| Markdown | TOC, links, stats | COVERED (markdown_*) |
| Jira/Project Management | Issue tracking | COVERED (jira_*) |
| Azure DevOps | Pipelines, work items | COVERED (devops_*) |
| Keycloak/Auth | User, client, realm mgmt | COVERED (keycloak_*) |
| SSH | Remote execution | COVERED (ssh_*) |
| Inter-Agent Messaging | Redis pub/sub, coordination | COVERED (claude_*) |
| Metacognition | Token budget, prediction | COVERED (meta_*) |
| Anki/Flashcards | Spaced repetition | COVERED (anki_*) |
| **Calendar/Scheduling** | Google Calendar, Outlook, iCal | **GAP** |
| **Workflow Automation** | n8n, Temporal, cron-based | **PARTIAL** (CronCreate exists) |
| **Email/Communication** | Gmail, SMTP, Slack | **GAP** |
| **Security Scanning** | Vulnerability audit, SBOM | **GAP** |
| **Diagram/Visualization** | Excalidraw, Mermaid, D3 | **GAP** |
| **Data Visualization** | Charts, dashboards | **GAP** |
| **Home Automation** | Home Assistant, MQTT | **GAP** (not relevant) |
| **Finance/Crypto** | Trading, portfolio | **GAP** (low priority) |
| **Monitoring/Observability** | Prometheus queries, Grafana | **PARTIAL** (Grafana via browser) |
| **DNS/Networking** | Cloudflare, DNS, certs | **GAP** |
| **Backup/Recovery** | Restic, Borg status | **GAP** |
| **CI/CD Pipeline** | Jenkins, GitHub Actions | **PARTIAL** (devops pipelines, gitea workflows) |
| **Zotero/Reference Mgmt** | Paper library management | **GAP** |
| **MCP Aggregation/Gateway** | MetaMCP, proxy routing | **PARTIAL** (mcp-proxy exists) |
| **Time Series/Analytics** | InfluxDB, TimescaleDB | **GAP** |

---

## 2. What's Hot in the Ecosystem (2025-2026)

### 2.1 MCP Spec Evolution (November 2025 Release)

The MCP spec has matured significantly. Key additions your setup should consider:

**Tasks Primitive (Experimental):** Async "call-now, fetch-later" for long-running operations. States: working, input_required, completed, failed, cancelled. This is directly relevant to your agent-framework.

**Sampling with Tools:** Servers can now initiate LLM sampling with tool definitions -- enabling server-side agent loops. This enables two-way agentic orchestration without custom frameworks.

**URL Mode Elicitation:** Servers send URLs for users to complete sensitive flows (OAuth, payments) in browsers. Useful for Keycloak integration flows.

**OAuth 2.1 with CIMD:** Client ID Metadata Documents replace Dynamic Client Registration. Decentralized trust model anchored in DNS/HTTPS. Relevant to your Keycloak SSO.

**M2M Client Credentials (SEP-1046):** Machine-to-machine authentication for headless agents. Critical for inter-agent communication in your agent-framework.

**MCP Bundles (.mcpb):** ZIP archives with manifest.json for portable server distribution. Could simplify your library distribution.

**MCP Apps Extension:** Standardizes interactive UIs beyond chat -- relevant for your dashboard.

### 2.2 Tool Scaling Solutions (Critical for 286 Tools)

Your 286-tool setup puts you in the "scaling challenge" zone. Key findings:

| Approach | Initial Tokens | At 400 Tools |
|----------|---------------|--------------|
| Static (all tools) | 405,100 | Exceeds context |
| Progressive Discovery | 2,500 | $0.078/query |
| Semantic Search | 1,300 | $0.069/query |

**Claude Code's Solution:** When tool descriptions exceed 10K tokens, Claude gets a `ToolSearch` meta-tool instead of all definitions. 3-5 relevant tools loaded per query = 85% token reduction. **You already have this** -- Claude Code's deferred tools mechanism is exactly this pattern.

**Progressive Discovery Pattern:** Expose 3 meta-tools: `list_tools` (prefix-based), `describe_tools` (schema), `execute_tool`. Token usage stays flat regardless of toolset size.

**Semantic Search Pattern:** Embed tool descriptions, `find_tools` returns relevant matches by natural language query. Even more token-efficient.

**Your current approach is actually good:** Claude Code's deferred tool loading handles this well. But for MCP clients other than Claude Code (e.g., n8n, other agents), consider implementing progressive discovery in simoge-mcp itself.

### 2.3 MCP Gateway/Aggregation Pattern

Multiple servers are being consolidated through gateways:

- **MetaMCP:** Aggregates MCP servers into namespaces, emits unified endpoint. Docker-based.
- **Microsoft MCP Gateway:** K8s-native, session-aware routing, lifecycle management.
- **LiteLLM:** Namespaces tools by prefixing with server name.
- **MCP Gateway Registry:** Enterprise OAuth + Keycloak/Entra integration, dynamic tool discovery.

Your mcp-proxy already handles session resilience + HMAC auth. The gateway pattern would matter if you split simoge-mcp into multiple specialized servers.

### 2.4 Security Concerns

**Alarming statistics:** 1 in 3 MCP servers scanned have critical vulnerabilities (Enkrypt AI). Common issues:
- Prompt injection via tool descriptions
- Command injection, path traversal
- Credential leaks in tool manifests
- Tool poisoning (malicious tool replacing trusted one)

**Security tools emerging:**
- `mcpserver-audit` (Cloud Security Alliance project)
- Snyk `agent-scan` -- scans for prompt injections and vulnerabilities
- Enkrypt AI MCP Scan

Your setup is safer than most because simoge-mcp is self-hosted, self-written code behind HMAC auth. But adding audit tooling for your own tools could be valuable.

---

## 3. Gap Analysis: What Would Add New Value

### Tier 1 -- High Value, Low Effort

**3.1 Restic Backup Status Tools**
You run nightly restic backups but have no MCP visibility. Tools:
- `backup_status` -- last backup time, size, duration
- `backup_list_snapshots` -- list snapshots with tags
- `backup_check` -- repository integrity check
- `backup_diff` -- diff between snapshots
Value: operational awareness without SSH. Can alert via claude_send if backup failed.

**3.2 Prometheus/Grafana Query Tools**
You have Prometheus + Grafana running. Official Grafana MCP server exists. Tools:
- `metrics_query` -- PromQL queries directly
- `metrics_alert_status` -- current firing alerts
- `dashboard_search` -- find Grafana dashboards
- `logs_query` -- Loki LogQL queries
Value: "Is anything broken right now?" without opening Grafana. Root cause analysis during incidents.

**3.3 Systemd Service Management Tools**
You have ~8 systemd user services. Tools:
- `systemd_status(service)` -- current status
- `systemd_journal(service, lines)` -- recent logs
- `systemd_restart(service)` -- restart service
Value: manage dashboard-api, ttyd, claude-web without remembering systemctl commands.

**3.4 Cloudflare Tunnel/DNS Tools**
You use Cloudflare Tunnel + DNS. Tools:
- `cf_tunnel_status` -- tunnel health, connections
- `cf_dns_list` -- DNS records for zone
- `cf_tunnel_routes` -- ingress rules
Value: "Is the tunnel healthy?" without cloudflared CLI.

### Tier 2 -- High Value, Medium Effort

**3.5 n8n Workflow Integration**
n8n has native MCP support (both client and server). Two directions:
- **n8n as MCP client:** n8n agents call your simoge-mcp tools
- **n8n as MCP server:** Claude triggers n8n workflows as tools
Value: bridge Claude intelligence to 400+ n8n integrations. Scheduled workflows with AI decision-making.

**3.6 Zotero MCP Server (Academic Research)**
Given your paper-archive system and academic research workflow:
- `zotero_search` -- search library by topic
- `zotero_add_paper(doi)` -- add paper to collection
- `zotero_get_annotations(paper_id)` -- get highlights/notes
- `zotero_export_bib(collection)` -- export bibliography
Value: unified research workflow. Your paper_archive.py + Zotero + AGE knowledge graph.
Note: Multiple open-source implementations exist on GitHub.

**3.7 MCP Resources Implementation**
You have 286 tools but likely 0 MCP Resources. Resources are underused across the ecosystem but powerful:
- `infra://services/{name}` -- service config as structured data
- `graph://schema` -- AGE graph schema
- `docs://research/{topic}` -- research reports
- `config://nginx/routes` -- nginx route table
Resources are read-only, application-controlled context. They let the client pre-load relevant context without tool calls, reducing latency and token usage.

**3.8 MCP Prompts Implementation**
Similarly underused. Prompts are user-invocable templates:
- `/research {topic}` -- full academic research workflow prompt
- `/deploy {service}` -- deployment checklist prompt
- `/troubleshoot {service}` -- diagnostic workflow prompt
- `/validate-paper {arxiv_id}` -- paper validation prompt
Value: standardize complex multi-step workflows. Currently these live in your system prompt; MCP Prompts make them portable and versionable.

### Tier 3 -- Medium Value, Specific Use Cases

**3.9 Diagram Generation Tools**
- `diagram_mermaid(code)` -- render Mermaid to SVG/PNG
- `diagram_excalidraw(description)` -- generate architecture diagrams
Value: generate diagrams for WikiJS/docs without leaving Claude.

**3.10 Email/Notification Tools**
- `email_send(to, subject, body)` -- send email via SMTP
- `notify_pushover(message)` -- push notification
Value: alerting and communication from Claude sessions.

**3.11 Certificate/TLS Management Tools**
- `cert_check(domain)` -- TLS cert expiry, chain validation
- `cert_list` -- all managed certificates and their status
Value: proactive cert monitoring.

**3.12 Jenkins Pipeline Tools**
You have Jenkins running but no MCP integration:
- `jenkins_list_jobs` -- list jobs and status
- `jenkins_trigger(job, params)` -- trigger build
- `jenkins_get_log(job, build)` -- get build log
Value: CI/CD visibility and control.

**3.13 WikiJS Enhanced Tools**
Beyond current web_fetch of WikiJS pages:
- `wiki_search(query)` -- full-text search across wiki
- `wiki_create_page(path, content)` -- create new page
- `wiki_update_page(path, content)` -- update existing page
- `wiki_list_pages(folder)` -- list pages in folder
Value: direct wiki management without browser.

---

## 4. Anti-Patterns and Best Practices

### What Anthropic and the Community Recommend

**Anti-Pattern 1: Tool Description Bloat**
Problem: Each tool ~400-500 tokens. 286 tools = ~130K tokens in context.
Solution: You already benefit from Claude Code's deferred loading. For non-Claude clients, implement progressive discovery.

**Anti-Pattern 2: Kitchen-Sink Servers**
Problem: One server with 286 tools makes everything tightly coupled.
Solution: Domain-bounded servers (infra, code, research, ops) behind a gateway. Your simoge-mcp is actually well-organized by library (mcp-docker-tools, mcp-sql-tools, etc.) which is the right pattern even if the endpoint is unified.

**Anti-Pattern 3: Credential Sprawl**
Problem: Embedding credentials in tool manifests or descriptions.
Solution: Your approach (env_file + HMAC auth) is already best practice.

**Anti-Pattern 4: Missing Idempotency**
Problem: Tools that aren't safe to retry cause state corruption.
Solution: Mark tools with annotations (readOnlyHint, destructiveHint, idempotentHint). The 2025 spec formalizes these.

**Anti-Pattern 5: Synchronous-Only Design**
Problem: Long-running operations block connections.
Solution: Implement the new Tasks primitive for operations >30s. Relevant for your deployment, backup, and build operations.

**Best Practice: Tool Annotations**
The 2025 spec adds formal annotations:
```json
{
  "annotations": {
    "readOnlyHint": true,
    "destructiveHint": false,
    "idempotentHint": true,
    "openWorldHint": false
  }
}
```
This helps clients present appropriate UIs and safety warnings.

**Best Practice: Use All Three Primitives**
Tools (model-controlled) + Resources (app-controlled) + Prompts (user-controlled) together create richer experiences than tools alone. Most servers (including yours) only use tools.

---

## 5. MCP Resources and Prompts: The Underused Features

### Resources

Resources are the **most underused** MCP feature. They provide structured, read-only data via URI templates:

```
resource://infra/services/{name}     -> service details
resource://graph/schema              -> AGE schema
resource://metrics/summary           -> system health snapshot
resource://config/nginx              -> route table
resource://research/papers/recent    -> recent paper imports
```

**Why they matter for you:**
- Resources are pre-loaded by the client, no tool call needed
- Reduce latency for frequently-accessed context
- Client can cache and refresh on subscription
- Resource templates with parameters enable dynamic access

**Resource subscriptions:** Clients can subscribe to resource changes (e.g., alert status changes).

### Prompts

Prompts are **user-invokable templates** that combine instructions, resources, and tool references:

```
Prompt: "research"
  Arguments: {topic: string, depth: "quick"|"deep"}
  Template: [system message with research methodology]
           [embedded resource: recent papers]
           [instructions to use web_search, openalex_search, etc.]
```

Currently Claude Code exposes MCP prompts as slash commands. Your complex research methodology (currently in the system prompt) could be a formal MCP Prompt.

### Practical Recommendation

Implementing even 5-10 Resources and 3-5 Prompts in simoge-mcp would put you ahead of 95%+ of the ecosystem in terms of using MCP's full potential.

---

## 6. Scaling 286 Tools: How Others Handle It

### Claude Code's Approach (What You Use)
- **Deferred tool loading:** Tools listed by name only; schemas fetched on-demand via `ToolSearch`
- **10K token threshold:** Below this, all tools load normally; above, only ToolSearch is provided
- **3-5 tools per query:** Typical usage after search

### Industry Patterns

**Progressive Discovery (Speakeasy):**
Three meta-tools: `list_tools`, `describe_tools`, `execute_tool`. 67x token reduction vs static.

**Semantic Search (Speakeasy):**
Two meta-tools: `find_tools` (embedding-based), `execute_tool`. 1,300 tokens flat.

**Namespace Prefixing (LiteLLM, MetaMCP):**
Tool names prefixed: `docker_list_containers`, `jira_create_issue`. Enables routing to correct backend.

**Gateway Pattern (Microsoft, MetaMCP):**
Central proxy aggregates multiple servers. Session-aware routing. You already have this with mcp-proxy.

### Your Specific Situation

Your 286 tools at ~400 tokens each = ~114K tokens if all loaded. Claude Code's deferred loading handles this well. The real question is: **do non-Claude-Code clients need access?** If yes (n8n, other agents, the agent-framework), implement progressive discovery in simoge-mcp itself.

**Concrete suggestion:** Add a `tool_search(query, category)` meta-tool to simoge-mcp that returns matching tool names + descriptions, with an `tool_execute(name, params)` companion. This enables any MCP client (not just Claude Code) to handle your 286 tools efficiently.

---

## 7. Concrete Recommendations Ranked by Value

### Priority 1 -- Implement Soon (High ROI, aligns with existing infrastructure)

| # | Tool/Feature | Effort | Value | Why |
|---|-------------|--------|-------|-----|
| 1 | **MCP Resources** (5-10 resources) | Medium | Very High | Use MCP's full potential; reduce tool calls for static data |
| 2 | **Prometheus/Grafana query tools** | Low | High | Official Grafana MCP server exists; direct PromQL/LogQL |
| 3 | **Restic backup status tools** | Low | High | Operational visibility for nightly backups |
| 4 | **MCP Prompts** (3-5 prompts) | Low | High | Formalize research/deploy/troubleshoot workflows |
| 5 | **Tool annotations** | Low | Medium | readOnly/destructive/idempotent hints on all 286 tools |

### Priority 2 -- Build When Needed

| # | Tool/Feature | Effort | Value | Why |
|---|-------------|--------|-------|-----|
| 6 | **Systemd service management** | Low | Medium | Manage host services from Claude |
| 7 | **Cloudflare tunnel/DNS tools** | Medium | Medium | Network visibility |
| 8 | **Progressive discovery meta-tools** | Medium | Medium | For non-Claude-Code clients |
| 9 | **Tasks primitive** | Medium | Medium | Async for long-running ops (deploy, build) |
| 10 | **Jenkins pipeline tools** | Low | Medium | CI/CD visibility |

### Priority 3 -- Consider for Specific Projects

| # | Tool/Feature | Effort | Value | Why |
|---|-------------|--------|-------|-----|
| 11 | **Zotero integration** | Medium | Medium | If you use Zotero for paper management |
| 12 | **n8n workflow integration** | High | High | Major capability expansion via 400+ integrations |
| 13 | **WikiJS direct API tools** | Medium | Medium | Programmatic wiki management |
| 14 | **Diagram generation** | Medium | Low | Mermaid/Excalidraw rendering |
| 15 | **Email/notification tools** | Low | Low | Alerting from sessions |

---

## 8. Serendipitous Connections

**MCP Tasks + Agent Framework:** The new Tasks primitive maps directly to your agent-framework's task lifecycle (HTN planning, SHOP2). Implementing Tasks in simoge-mcp would create a protocol-level bridge between MCP clients and your multi-agent orchestration.

**MCP Sampling with Tools + Preference Sort:** Server-side sampling with tools could enable your Preference Sort (Bradley-Terry) to request LLM-generated comparisons autonomously -- the MCP server asks the client's LLM to compare items, then records the preference. A self-improving ranking loop.

**Progressive Discovery + AGE Knowledge Graph:** Instead of embedding tool descriptions in a static index, store them in AGE as nodes with relationship edges (tool -> uses -> database, tool -> category -> monitoring). Then `tool_search` becomes a graph traversal query, returning not just matching tools but related tools via graph proximity. This is more powerful than pure semantic search because it captures structural relationships.

**MCP Resources + Kindle Graph Enrichment:** Expose your knowledge graph as MCP Resources (`resource://graph/concepts/{name}`, `resource://graph/books/{title}/highlights`). Any MCP client could then browse your personal knowledge graph as structured context, not just via tool calls. This turns KORE into a portable knowledge substrate.

---

## 9. Governance Note

In December 2025, Anthropic donated MCP to the **Agentic AI Foundation** under the Linux Foundation, co-founded with Block and OpenAI, backed by Google, Microsoft, AWS, and Cloudflare. This makes MCP an industry standard with neutral governance -- your investment in MCP tooling is well-placed.

---

## Sources

- [MCP Specification 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25)
- [punkpeye/awesome-mcp-servers](https://github.com/punkpeye/awesome-mcp-servers)
- [TensorBlock/awesome-mcp-servers](https://github.com/TensorBlock/awesome-mcp-servers)
- [MCP Features Guide (WorkOS)](https://workos.com/blog/mcp-features-guide)
- [MCP 2025-11-25 Spec Update (WorkOS)](https://workos.com/blog/mcp-2025-11-25-spec-update)
- [100x Token Reduction Dynamic Toolsets (Speakeasy)](https://www.speakeasy.com/blog/100x-token-reduction-dynamic-toolsets)
- [The MCP Tool Trap (Jentic)](https://jentic.com/blog/the-mcp-tool-trap)
- [Grafana MCP Server](https://github.com/grafana/mcp-grafana)
- [MetaMCP Gateway](https://github.com/metatool-ai/metamcp)
- [Microsoft MCP Gateway](https://github.com/microsoft/mcp-gateway)
- [MCP Gateway Registry (Keycloak/Entra)](https://github.com/agentic-community/mcp-gateway-registry)
- [Zotero MCP](https://github.com/54yyyu/zotero-mcp)
- [n8n MCP Integration](https://www.n8n-mcp.com/)
- [MCP Security Checklist (SlowMist)](https://github.com/slowmist/MCP-Security-Checklist)
- [mcpserver-audit (CSA)](https://github.com/ModelContextProtocol-Security/mcpserver-audit)
- [Snyk agent-scan](https://github.com/snyk/agent-scan)
- [MCP Blog: Prompts for Automation](http://blog.modelcontextprotocol.io/posts/2025-07-29-prompts-for-automation/)
- [MCP Blog: MCP Apps Extension](https://blog.modelcontextprotocol.io/posts/2025-11-21-mcp-apps/)
- [One Year of MCP Anniversary Post](http://blog.modelcontextprotocol.io/posts/2025-11-25-first-mcp-anniversary/)
- [Enkrypt AI: 1/3 MCP Servers Have Critical Vulnerabilities](https://www.enkryptai.com/blog/we-scanned-1-000-mcp-servers-33-had-critical-vulnerabilities)
- [MCP Best Practices (MikesBlog)](https://oshea00.github.io/posts/mcp-practices/)
- [Anthropic: Code Execution with MCP](https://www.anthropic.com/engineering/code-execution-with-mcp)
