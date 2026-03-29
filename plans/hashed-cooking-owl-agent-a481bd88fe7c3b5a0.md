# MCP Ecosystem Research: Tools Worth Adding for a Power User / Self-Hosted Operator

**Date**: 2026-03-22
**Scope**: MCP servers and tools that would ADD VALUE beyond the ~286 tools already in simoge-mcp

---

## Gap Analysis: What You Already Have vs. What Exists

Your simoge-mcp covers: infrastructure management, code navigation/refactoring, web search/fetch, Docker management, database queries, file operations, git (Gitea), AI/LLM, embeddings, Redis, CSV/JSON/YAML, PDF, markdown, Jira, Azure DevOps, Keycloak admin, S3/MinIO, SSH, graph database (AGE), Playwright browser, inter-agent messaging, Anki flashcards, OpenAlex research.

**Identified gaps** below, organized by value tier.

---

## TIER 1 -- High Value, Clear Gap

### 1. Grafana MCP Server (Official)
- **Repo**: [grafana/mcp-grafana](https://github.com/grafana/mcp-grafana)
- **What it does**: Full Grafana API access -- dashboard search/read/create, Prometheus/Loki/Pyroscope datasource queries, alert rule management (list/create/update/delete), incident management, OnCall integration, Sift anomaly detection, **panel rendering to PNG** (base64).
- **Docker image**: `mcp/grafana` on Docker Hub
- **Why it matters for you**: You already run Prometheus + Grafana + Loki. This lets Claude directly query metrics ("show me CPU usage for the last 6 hours"), read logs from Loki ("find ERROR lines in nginx"), check firing alerts, and even render dashboard panels as images. The `--disable-write` flag gives a safe read-only mode. Separate [grafana/loki-mcp](https://github.com/grafana/loki-mcp) exists for Loki-specific deep integration.
- **Effort**: Low. Official Docker image, just needs `GRAFANA_URL` + `GRAFANA_API_KEY` env vars.
- **Integration path**: Could run as standalone container on `shared` network, or adapt key queries into simoge-mcp Java tools wrapping Grafana HTTP API.

### 2. n8n Workflow Automation MCP Server
- **Repo**: [czlonkowski/n8n-mcp](https://github.com/czlonkowski/n8n-mcp) / [leonardsellem/n8n-mcp-server](https://github.com/leonardsellem/n8n-mcp-server)
- **What it does**: Build, validate, deploy n8n workflows via natural language. Access to 1,239 automation nodes (809 core + 430 community). n8n itself can act as both MCP server and MCP client.
- **Why it matters for you**: You do NOT currently have a visual workflow automation engine. n8n is self-hostable, lightweight (~2GB RAM), and could orchestrate cross-service automations that currently require shell scripts: "when a new paper is imported, send a summary to Redis, create an Anki card, update the knowledge graph." It turns Claude into a workflow designer.
- **Effort**: Medium. Requires deploying n8n as a new service (Docker, PostgreSQL backend you already have), then connecting MCP.
- **Integration path**: New Docker stack `n8n/`, connect to existing `shared` network + postgres. MCP server runs alongside.

### 3. Cron/Scheduler MCP Server
- **Repo**: [phildougherty/claudecron](https://github.com/phildougherty/claudecron) (best for Claude Code) / [jolks/mcp-cron](https://github.com/jolks/mcp-cron) (Go, robust)
- **What it does**: Schedule shell commands, AI prompts, and slash commands on cron expressions. claudecron specifically supports Claude Code hooks, file-change triggers, and task chaining with dependencies.
- **Why it matters for you**: You already have systemd timers and `ScheduledJob` nodes in AGE, but no way for Claude to *create* or *manage* scheduled tasks at runtime. This enables "run this backup check every 6 hours" or "trigger a paper archive scan when I say so" directly from conversation.
- **Effort**: Low. Go binary or Node.js, minimal dependencies.
- **Integration path**: Could implement natively in simoge-mcp as `scheduler_*` tools wrapping your existing systemd timer infrastructure, which would be more powerful than external solutions.

### 4. Domain/Network Analysis Tools
- **Repo**: [patrickdappollonio/mcp-domaintools](https://github.com/patrickdappollonio/mcp-domaintools)
- **What it does**: DNS lookups, WHOIS queries, connectivity testing (ping/traceroute), TLS certificate analysis (expiry, chain, SANs), HTTP endpoint monitoring, hostname resolution.
- **Why it matters for you**: You manage Cloudflare Tunnel, WireGuard, Tailscale, multiple DNS entries, and TLS certs. Quick "check if sol.massimilianopili.com cert expires soon" or "DNS resolution for mcp.massimilianopili.com" without leaving the conversation. Complements your existing `net_*` tools which focus on nginx routing, not actual DNS/TLS.
- **Effort**: Low. Single Go binary.
- **Integration path**: Add as Java tools in simoge-mcp using `ProcessBuilder` to shell out to `dig`, `openssl`, `whois`, `curl`, or implement pure Java DNS/TLS checks.

### 5. Linux System Administration MCP
- **Repo**: [rhel-lightspeed/linux-mcp-server](https://github.com/rhel-lightspeed/linux-mcp-server)
- **What it does**: Read-only Linux system diagnostics -- system info, service status (systemd), process listing, journal logs, network interfaces, disk/storage, package info. RHEL/systemd focus.
- **Why it matters for you**: Your `ops_*` tools are graph-based (stored knowledge about commands), not live system queries. This gives Claude direct access to `systemctl status`, `journalctl`, `df -h`, `free -m`, `ss -tlnp`, `ip addr` etc. The read-only constraint is safe.
- **Effort**: Low. Python, well-tested on Ubuntu.
- **Integration path**: Best implemented as native simoge-mcp tools: `system_info`, `system_services`, `system_processes`, `system_logs`, `system_disk`, `system_network`. You already have SSH tools but these would be local, faster, and more structured.

---

## TIER 2 -- Medium Value, Worth Evaluating

### 6. AST-grep MCP Server
- **Repo**: [ast-grep/ast-grep](https://github.com/ast-grep/ast-grep) + MCP wrapper
- **What it does**: Pattern-based code search using abstract syntax trees. Find code patterns across languages (Java, Go, Python, JS). Structural search/replace, not regex.
- **Why it matters for you**: Your `code_*` tools do symbol listing, imports, references -- but AST-grep is specifically designed for "find all functions that call X with argument Y" patterns. Extremely useful for Agent COBOL project (AST analysis of legacy code) and large refactorings.
- **Effort**: Low-medium. Requires ast-grep binary + MCP bridge.
- **Gap vs existing**: Your `code_find_references` and `code_find_definition` partially cover this, but ast-grep does cross-language structural patterns.

### 7. Graph RAG MCP Server (for Obsidian/Knowledge Bases)
- **Repo**: [ferparra/graph-rag-mcp-server](https://github.com/ferparra/graph-rag-mcp-server)
- **What it does**: Combines vector-based semantic search with graph relationship traversal over note vaults (Obsidian format). Multi-layer retrieval: semantic + graph + temporal context.
- **Why it matters for you**: You already have AGE + pgvector + embeddings. The *idea* is interesting (combining graph traversal with vector search in a single query path), but you've essentially built this yourself. Useful more as **architectural inspiration** than as a tool to adopt.
- **Integration path**: Steal the multi-layer retrieval pattern: your `embeddings_search` does vector, your `graph_query` does graph. A combined `knowledge_search` tool that does both and merges results would be the win.

### 8. MCP Gateway / Aggregator
- **Repo**: [TheLunarCompany/lunar (MCPX)](https://github.com/TheLunarCompany/lunar)
- **What it does**: Production-ready gateway to manage MCP servers at scale. Tool discovery, access controls, usage tracking, call prioritization, token budget management.
- **Why it matters for you**: With 286 tools on simoge-mcp, tool discovery overhead is real. A gateway layer could provide: tool-level access control (visitor vs admin), usage analytics (which tools get called most), rate limiting per tool, and lazy loading (your deferred tools pattern, but standardized).
- **Effort**: Medium. Requires architecture change (gateway in front of simoge-mcp).
- **Gap vs existing**: Your mcp-proxy already handles session resilience + HMAC auth. MCPX adds tool-level governance. Worth monitoring but possibly overkill since you're the primary user.

### 9. MCP Security Scanner
- **Repo**: [invariantlabs-ai/mcp-scan (now Snyk Agent Scan)](https://github.com/snyk/agent-scan) / [ModelContextProtocol-Security/mcpserver-audit](https://github.com/ModelContextProtocol-Security/mcpserver-audit)
- **What it does**: Scans MCP servers for vulnerabilities: prompt injection, tool poisoning, confused deputy attacks, data exfiltration, path traversal, command injection. Detects 15+ risk categories.
- **Why it matters for you**: With 286 tools, some accepting free-text input, running a periodic security audit on your own MCP server is good hygiene. Not a permanent tool -- more of a one-time/periodic audit.
- **Effort**: Low. CLI tool, run against your server.

### 10. Smart Diff / Code Review MCP
- **Repo**: [opensensor/smartdiff](https://github.com/opensensor/smartdiff) / [praneybehl/code-review-mcp](https://github.com/praneybehl/code-review-mcp)
- **What it does**: AST-level diff analysis (not line-by-line), semantic understanding with symbol resolution, refactoring pattern detection. Code review integration with multiple LLM backends.
- **Why it matters for you**: Your `code_diff_summary` exists but smartdiff adds AST-level understanding (detects renames, moved functions, extracted methods). Useful for reviewing Gitea PRs with Claude.
- **Effort**: Low-medium.

---

## TIER 3 -- Niche but Interesting

### 11. Desktop Notification MCP
- **What it does**: Send native OS notifications from Claude. Toast/desktop notifications when long tasks complete, or when an alert fires.
- **Why it matters for you**: Minor convenience. Your dashboard SSE already handles this somewhat.

### 12. Email MCP (IMAP/SMTP)
- **What it does**: Read/send emails via IMAP/SMTP. Could integrate with calendar.
- **Why it matters for you**: Only if you want Claude to manage email. Probably not a priority for infrastructure use.

### 13. TLS Certificate Analysis MCP
- **Repo**: Already covered by mcp-domaintools (#4 above)
- **What it does**: Check cert expiry, chain validity, SANs, OCSP status.
- **Why it matters for you**: Relevant for DSS Wrapper project (CAdES, XAdES, PAdES, certificate validation).

### 14. Anyquery (SQL over Everything)
- **Repo**: [julien040/anyquery](https://github.com/julien040/anyquery)
- **What it does**: Query 40+ applications via SQL. Local-first. Supports PostgreSQL wire protocol.
- **Why it matters for you**: Potentially interesting for querying Docker stats, system metrics, or log files via SQL syntax. But you already have direct DB access.

### 15. Kali Security Tools MCP
- **Repo**: [cyproxio/mcp-for-security](https://github.com/cyproxio/mcp-for-security)
- **What it does**: Wraps nmap, sqlmap, ffuf, masscan for AI-assisted penetration testing.
- **Why it matters for you**: Periodic self-assessment of your exposed services. Run nmap against your own infrastructure from Claude. Niche but powerful for security audits.

---

## NOT Worth Adding (Already Covered or Low Value)

| Tool | Why Skip |
|------|----------|
| Filesystem MCP | You have `fs_*` tools |
| Git MCP | You have `gitea_*` tools + Bash git |
| PostgreSQL MCP | You have `db_*` tools |
| Redis MCP | You have `redis_*` tools |
| Docker MCP | You have `docker_*` tools (34) |
| Brave/Tavily Search | You have `web_search` via SearXNG |
| Fetch MCP | You have `web_fetch` with 4-level resilience |
| Memory MCP (knowledge graph) | You have AGE + pgvector (50K+ nodes, far superior) |
| Sequential Thinking | Useful for some, but Claude Code already does this natively |
| Slack/Discord MCP | Not relevant to your setup |
| Google Drive MCP | Not relevant (self-hosted) |
| AWS/Azure/GCP MCP | Not relevant (bare metal self-hosted) |
| Puppeteer/Playwright MCP | Already integrated in simoge-mcp |
| SSH MCP | Already have `ssh_*` tools |
| Obsidian MCP | Not using Obsidian (AGE knowledge graph instead) |
| Context7 MCP | Already migrated into simoge-mcp |
| Notion MCP | Not using Notion |

---

## Recommended Implementation Priority

### Phase 1 -- Quick Wins (1-2 days each)
1. **Grafana MCP** -- Deploy `mcp/grafana` container, connect to existing Grafana. Immediate value for observability.
2. **Domain/Network tools** -- Implement as 5-6 native simoge-mcp tools (`dns_lookup`, `tls_check`, `whois_query`, `connectivity_test`, `http_monitor`).
3. **Linux system tools** -- Implement as 6-8 native simoge-mcp tools (`system_info`, `system_services`, `system_logs`, `system_disk`, `system_network`, `system_processes`).

### Phase 2 -- Medium Effort (3-5 days)
4. **Cron/Scheduler** -- Implement native simoge-mcp tools wrapping systemd timer management (`scheduler_create`, `scheduler_list`, `scheduler_delete`, `scheduler_logs`).
5. **MCP Security Scan** -- Run once, fix findings, schedule periodic re-scans.

### Phase 3 -- Strategic (1-2 weeks)
6. **n8n** -- Deploy as new service, evaluate as workflow engine for cross-service orchestrations.
7. **AST-grep** -- Install binary, wrap in simoge-mcp for Agent COBOL project.
8. **Combined Knowledge Search** -- Build a `knowledge_search` tool that merges graph traversal + vector similarity in a single query.

---

## Serendipitous Connections

- **Grafana MCP + Agent Framework**: The agent-framework's task_graph could emit metrics to Prometheus, then Grafana MCP lets Claude monitor agent performance in real-time. Closes the observability loop on multi-agent orchestration.
- **n8n + Paper Archive**: n8n workflows could automate the full paper ingestion pipeline (arXiv -> Semantic Scholar -> AGE -> pgvector -> Anki), replacing the current script-based approach with a visual, debuggable workflow.
- **Scheduler MCP + Principio di inesorabilita**: A scheduler tool directly aligns with the progressive nightly job philosophy -- Claude could propose and create new convergence jobs from conversation.
- **Domain tools + DSS Wrapper**: TLS certificate analysis tools directly serve the DSS Wrapper project's need for certificate validation (CAdES, XAdES chain verification).
- **AST-grep + Agent COBOL**: Structural code search is exactly what you need for COBOL-to-Java transformation pattern matching.

---

## Sources

- [modelcontextprotocol/servers (Official)](https://github.com/modelcontextprotocol/servers)
- [punkpeye/awesome-mcp-servers](https://github.com/punkpeye/awesome-mcp-servers)
- [grafana/mcp-grafana](https://github.com/grafana/mcp-grafana)
- [grafana/loki-mcp](https://github.com/grafana/loki-mcp)
- [czlonkowski/n8n-mcp](https://github.com/czlonkowski/n8n-mcp)
- [phildougherty/claudecron](https://github.com/phildougherty/claudecron)
- [jolks/mcp-cron](https://github.com/jolks/mcp-cron)
- [patrickdappollonio/mcp-domaintools](https://github.com/patrickdappollonio/mcp-domaintools)
- [rhel-lightspeed/linux-mcp-server](https://github.com/rhel-lightspeed/linux-mcp-server)
- [angrysky56/ast-mcp-server](https://github.com/angrysky56/ast-mcp-server)
- [ferparra/graph-rag-mcp-server](https://github.com/ferparra/graph-rag-mcp-server)
- [TheLunarCompany/lunar (MCPX)](https://github.com/TheLunarCompany/lunar)
- [snyk/agent-scan](https://github.com/snyk/agent-scan)
- [cyproxio/mcp-for-security](https://github.com/cyproxio/mcp-for-security)
- [PhialsBasement/scheduler-mcp](https://github.com/PhialsBasement/scheduler-mcp)
- [Docker Blog: 6 Must-Have MCP Servers](https://www.docker.com/blog/top-mcp-servers-2025/)
- [Desktop Commander: Best MCP Servers](https://desktopcommander.app/blog/2025/11/25/best-mcp-servers/)
- [PulseMCP Server Directory](https://www.pulsemcp.com/servers)
- [MCP Registry](https://registry.modelcontextprotocol.io)
