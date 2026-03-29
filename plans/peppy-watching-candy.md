# Ricerca 360° — Nuovi MCP tools, plugin, hooks, patterns

## Context

Dopo il refactor MCP (378 tool, server thin launcher), serve una survey completa per:
1. Identificare gap nei tool MCP per i servizi SOL non coperti
2. Scoprire nuovi MCP server/plugin/pattern dall'ecosistema
3. Unknown unknowns — cose che non sappiamo di non sapere

Ricerche in corso: 3 agenti paralleli (gap analysis ✓, MCP ecosystem ⏳, hooks/skills patterns ⏳).

---

## Gap Analysis — Tool MCP mancanti per SOL (completata)

### HIGH PRIORITY (nuove librerie da creare)

| Libreria | Servizio | Gap | Tool suggeriti |
|----------|----------|-----|----------------|
| `mcp-monitoring-tools` | Prometheus + Grafana + Loki | 0% coverage | 7: prometheus_query, prometheus_get_targets, grafana_list_dashboards, grafana_get_dashboard, loki_query, loki_label_values, metrics_export |
| `mcp-wikijs-tools` | WikiJS | 0% coverage | 7: wikijs_create_page, wikijs_list_pages, wikijs_delete_page, wikijs_get_page, wikijs_bulk_import, wikijs_embargo_apply, wikijs_git_sync_status |
| `mcp-wireguard-tools` | WireGuard VPN | 0% coverage (TUI esiste) | 6: wg_list_peers, wg_create_peer, wg_revoke_peer, wg_rotate_keys, wg_peer_status, wg_network_stats |

### MEDIUM PRIORITY

| Libreria | Servizio | Tool suggeriti |
|----------|----------|----------------|
| `mcp-tor-tools` | Tor relay + hidden service | 5: tor_relay_status, tor_hidden_service_info, tor_socks_test, tor_network_stats, tor_relay_logs |
| `mcp-jenkins-tools` | Jenkins CI/CD | 6: jenkins_list_jobs, jenkins_trigger_job, jenkins_get_build, jenkins_get_logs, jenkins_list_artifacts, jenkins_health |
| `mcp-opencloud-tools` | OpenCloud/WebDAV | 6: opencloud_list_files, opencloud_upload, opencloud_download, opencloud_share, opencloud_search, opencloud_get_quota |
| `mcp-batch-tools` | ANANKE batch orchestration | 4: batch_schedule_job, batch_run, batch_stats, batch_alert |

### LOW PRIORITY

| Area | Note |
|------|------|
| MkDocs | 4 tool — POC, non ancora primario |
| Artemis | 4 tool — uso incerto |
| LibSQL | 4 tool — uso marginale |
| Nginx admin | 5 tool — convention is `docker compose up --force-recreate` |
| PG admin avanzato | 6 tool — pgAdmin UI esiste |

---

## Ricerca MCP Ecosystem (completata)

Report completo: `/home/massimiliano/.claude/plans/peppy-watching-candy-agent-adc483528438e7f29.md`

### Azioni immediate (NOW)

1. **Migrare SSE → Streamable HTTP** — SSE deprecato, Atlassian lo droppa giugno 2026. Spring AI 1.1.x supporta `spring.ai.mcp.server.protocol=STREAMABLE`. Il Go proxy va aggiornato per POST+GET dual-connection.
2. **Deployare Grafana MCP Server** (`github.com/grafana/mcp-grafana`) — ufficiale, Docker image pronta, copre Prometheus+Loki+Grafana. Potrebbe SOSTITUIRE la necessità di creare mcp-monitoring-tools custom.
3. **Leggere Doyensec MCP security post** — 66% MCP server hanno vulnerabilità. Il setup HMAC è già buono ma awareness importa.

### Azioni questa settimana

4. **Confrontare Gitea MCP ufficiale** (`gitea.com/gitea/gitea-mcp`) vs i tuoi 17 tool `mcp-gitea-tools`
5. **Deployare Prometheus MCP Server** (Docker Hub, 50K+ pulls) — complementare a Grafana MCP

### Azioni prossima settimana

6. **Esplorare Agent Teams** — parallelismo tmux nativo, complementare a claude_task_*
7. **Confrontare Redis MCP ufficiale** (`github.com/redis/mcp-redis`) vs mcp-redis-tools

### Backlog

8. **Elicitation** — server può chiedere input utente mid-tool (Keycloak auth flow possibile)
9. **OpenAPI-to-MCP auto-generation** — pattern ArgoCD per generare tool da OpenAPI spec
10. **Docker MCP Catalog** — pubblicare i tuoi server su `mcp.docker.com`
11. **Graphiti (Zep)** — temporal knowledge graph, rilevante per KORE-GC paper

### Sicurezza

- Tool poisoning, rug pull, OAuth token misuse sono attacchi reali
- Il tuo setup (HMAC, custom tools, Tailscale, nessun marketplace esterno) è già buono
- Se mai consumi MCP server terzi → ToolHive (Stacklok) per container isolation

---

## Ricerca Hooks/Skills/Agent Patterns (completata)

Report completo: `/home/massimiliano/.claude/plans/peppy-watching-candy-agent-a6065118706e98420.md`

### Scoperte chiave

1. **Skill activation ~20% senza ottimizzazione** → 84% con forced evaluation hook. Le 105 skill hanno probabilmente tasso di attivazione molto basso
2. **4 tipi di hook handler**: command (usi questo), HTTP, **prompt** (inietta testo nel context), **agent**. Prompt hooks sono il gap più grande
3. **Hook-driven skill routing**: UserPromptSubmit prompt hook che analizza l'input e inietta il contesto della skill giusta — pattern emergente per skill collection grandi
4. **Agent Teams** (Feb 2026): parallelismo nativo peer-to-peer, complementare al tuo claude_task_*

### Azioni HIGH PRIORITY

1. **Audit 105 skill descriptions** con pattern Two-Part (WHAT + WHEN + 5 trigger keywords) — da ~20% a ~50% activation
2. **Forced evaluation hook** per top 15 skill critiche — a ~84% activation
3. **Prompt hooks per skill routing** su UserPromptSubmit
4. **Run agnix linter** (`agent-sh/agnix`) su tutti skill/hook/CLAUDE.md
5. **Valutare parry** (prompt injection scanner) per 378 tool MCP

### Azioni MEDIUM PRIORITY

6. HTTP hooks per audit logging → POST diretto a AGE graph (vs shell script)
7. Code Review Agent (pattern AgentSys: parallel multi-aspect review)
8. Dippy-style auto-approval per bash commands safe
9. On-demand hooks (`/careful`, `/freeze`) via skill

### Pattern da studiare

- **Ralph Wiggum** → pattern ANANKE (loop autonomo fino a convergenza)
- **Agent Compiler** → embed skill critiche in CLAUDE.md per 100% activation
- **Preference Sort per skill routing** → BT model su quali skill attivano per quali prompt (connessione originale)

---

## Consolidamento — Task da creare

Dalla ricerca emergono queste azioni concrete, ordinate per impatto:

### Immediato (questa settimana)

| Task | Tipo | Note |
|------|------|------|
| Migrare SSE → Streamable HTTP | protocol | SSE deprecato. Spring AI supporta `protocol=STREAMABLE`. Go proxy va aggiornato |
| Deployare Grafana MCP Server | deploy | `github.com/grafana/mcp-grafana` — Docker image pronta, copre monitoring gap |
| Skill description audit (105 skill) | ops | Two-Part pattern, 5 trigger keywords, target 50% activation |

### Prossima settimana

| Task | Tipo | Note |
|------|------|------|
| Forced evaluation hook per top 15 skill | code | UserPromptSubmit prompt hook, target 84% |
| Confrontare Gitea MCP ufficiale vs mcp-gitea-tools | research | `gitea.com/gitea/gitea-mcp` |
| Agent Teams exploration | research | Parallelismo nativo, complementare a claude_task_* |
| Doyensec MCP security review | security | 66% server hanno vulnerabilità |

### Backlog (nuove librerie)

| Task | Tipo | Note |
|------|------|------|
| mcp-wikijs-tools v0.1.0 | code | 7 tool: page CRUD, embargo, sync |
| mcp-wireguard-tools v0.1.0 | code | 6 tool: peer mgmt, provisioning |
| mcp-jenkins-tools v0.1.0 | code | 6 tool: job trigger, build tracking |
| mcp-tor-tools v0.1.0 | code | 5 tool: relay/onion monitoring |

### Report completi

- MCP Ecosystem: `peppy-watching-candy-agent-adc483528438e7f29.md`
- Hooks/Skills: `peppy-watching-candy-agent-a6065118706e98420.md`

---

## Deep Research — Risultati (6 report)

Report salvati in `/home/massimiliano/.claude/plans/`:
- `peppy-watching-candy-agent-adc483528438e7f29.md` — MCP Ecosystem Survey
- `peppy-watching-candy-agent-a6065118706e98420.md` — Hooks/Skills/Agent Patterns
- `peppy-watching-candy-agent-a950a1492ddf069d1.md` — Skill Routing + Hooks Deep
- `peppy-watching-candy-agent-aa4e7b877404d6911.md` — Agent Framework Patterns

### Scoperte chiave dalla ricerca deep

**Skill Routing**:
- Routing è **pure LLM reasoning** (no embeddings, no classifiers) — 15K char limit per la lista skill
- **Prompt hooks NON funzionano su UserPromptSubmit** — solo command hooks
- Pattern diet103: TypeScript skill-activation-prompt + skill-rules.json (keywords + regex)
- Forced eval (84%): "commitment mechanism" — Claude deve esplicitamente nominare e chiamare le skill
- **agnix**: Rust linter, 342 rules, VS Code/JetBrains/CLI/MCP server, valida SKILL.md qualità

**Idea originale: Bradley-Terry per skill routing**:
- Nessun prior art per intra-agent routing con BT
- 3 paper rilevanti: KABB (Bayesian bandits + BT), LLM Routing Survey, Reward Model Routing
- Architettura proposta: Preference Sort su SOL + pgvector per prompt categorization + PostToolUse hook per training signal

**Agent Patterns**:
- Agent Teams: task list + claim + mailbox (mappa a HTN del tuo Agent Framework)
- AgentSys: 19 plugin, 47 agent, "Code does code work, AI does AI work" (77% meno token)
- RIPER: phase-enforced (Research→Innovate→Plan→Execute→Review)
- Ralph Wiggum: loop autonomo fino a convergenza (= ANANKE)

**Security/Protocol**:
- SSE deprecato → Streamable HTTP (Spring AI supporta `protocol=STREAMABLE`)
- Elicitation: server chiede input mid-tool (@McpElicitation)
- parry: prompt injection scanner (PreToolUse hook)

---

## Piano di azione — Task da creare nella coda

### Categoria: MCP Tools (nuove librerie)

| Ref | Tipo | Prio | Descrizione |
|-----|------|------|-------------|
| mcp-monitoring-tools | code | 3 | 7 tool: Prometheus PromQL, Grafana dashboards, Loki LogQL |
| mcp-wikijs-tools | code | 3 | 7 tool: page CRUD, embargo, git sync |
| mcp-wireguard-tools | code | 3 | 6 tool: peer mgmt, provisioning, rotation |
| mcp-tor-tools | code | 4 | 5 tool: relay/onion monitoring |
| mcp-jenkins-tools | code | 4 | 6 tool: job trigger, build tracking |
| mcp-mkdocs-tools | code | 5 | 4 tool: build, validate, pages |
| mcp-artemis-tools | code | 5 | 4 tool: queue mgmt |
| mcp-libsql-tools | code | 5 | 4 tool: query, backup |
| mcp-pg-admin-tools | code | 5 | 6 tool: backup, vacuum, stats |

### Categoria: Protocol/Infrastructure

| Ref | Tipo | Prio | Descrizione |
|-----|------|------|-------------|
| mcp-streamable-http | code | 2 | Migrare simoge-mcp da SSE a Streamable HTTP + aggiornare Go proxy |
| gitea-mcp-official-compare | research | 3 | Confrontare gitea.com/gitea/gitea-mcp vs mcp-gitea-tools:0.1.2 |
| openapi-to-mcp-generator | research | 3 | Auto-generare MCP tools da OpenAPI spec — potenziale progetto open source |

### Categoria: Skill Optimization

| Ref | Tipo | Prio | Descrizione |
|-----|------|------|-------------|
| skill-description-audit | ops | 2 | Audit 105 skill con Two-Part pattern (WHAT+WHEN+5 keywords) — target 50% activation |
| skill-forced-eval-hook | code | 2 | UserPromptSubmit command hook per top 15 skill — target 84% activation |
| skill-bt-routing | research | 3 | BT model (Preference Sort) per adaptive skill routing — paper originale |
| agnix-audit | ops | 3 | Run agnix linter (342 rules) su tutti skill/hook/CLAUDE.md |

### Categoria: Security

| Ref | Tipo | Prio | Descrizione |
|-----|------|------|-------------|
| parry-injection-scanner | research | 3 | Valutare parry prompt injection scanner per 378 MCP tools |
| doyensec-mcp-security | research | 3 | Review Doyensec MCP AuthN/Z Nightmare post |
| mcp-elicitation-keycloak | research | 4 | @McpElicitation per Keycloak auth flow mid-tool |

### Categoria: Agent Patterns

| Ref | Tipo | Prio | Descrizione |
|-----|------|------|-------------|
| agent-teams-exploration | research | 3 | Esplorare Agent Teams nativi per parallel workflows |
| agentsys-patterns | research | 4 | Studiare AgentSys certainty grading + "code does code work" pattern |
| ralph-wiggum-ananke | research | 4 | Ralph Wiggum pattern per ANANKE convergence loops |
| wave-execution-htn | code | 3 | Wave-based execution (GSD): topological sort del DAG task → fresh context per wave. Mappa a linearizzazione piani HTN in Agent Framework |
| compound-learning | code | 3 | Compound learning: estrazione post-task di lezioni apprese per routing optimization. Pattern EveryInc retrospective → feedback loop nel task orchestrator |
| risk-tiered-escalation | code | 3 | Risk-tiered escalation (Night Market): GREEN/YELLOW/RED/CRITICAL gating per task. Human escalation per high-risk ops. Integrare nel claude_task_enqueue come campo risk_level |

### Categoria: Hooks & Automation

| Ref | Tipo | Prio | Descrizione |
|-----|------|------|-------------|
| http-hooks-audit-log | code | 3 | Convertire audit logging da command hook (shell) a HTTP hook → POST diretto a AGE graph |
| dippy-auto-approval | research | 4 | AST-based bash auto-approval (ldayton/dippy). Riduci permission fatigue senza --dangerously-skip |
| on-demand-hooks | code | 4 | Hook context-dependent via skill: /careful (blocca destructive), /freeze (blocca edit fuori dir) |
| agent-compiler-skills | research | 4 | Embed top skill in CLAUDE.md per 100% activation (trade-off: token cost vs reliability) |
| diet103-skill-routing | code | 3 | Adattare diet103/claude-code-infrastructure-showcase: TypeScript skill-activation-prompt + skill-rules.json |

### Categoria: Agent Framework Advanced

| Ref | Tipo | Prio | Descrizione |
|-----|------|------|-------------|
| code-review-agent | code | 3 | Multi-aspect parallel code review agent (pattern AgentSys: security+perf+style) |
| claude-squad-eval | research | 4 | Valutare Claude Squad (smtg-ai): terminal app multi-Claude instances |
| riper-workflow | research | 4 | RIPER phase-enforced dev (Research→Innovate→Plan→Execute→Review) |
| night-market-audit | research | 4 | Audit 151 skill di Night Market (athola) per pattern riusabili |

### Categoria: Protocol/Research Extra

| Ref | Tipo | Prio | Descrizione |
|-----|------|------|-------------|
| mcp-oauth21-keycloak | research | 4 | OAuth 2.1 Resource Server standard per MCP interop con Keycloak come auth server |
| graphiti-temporal-kg | research | 4 | Graphiti (Zep) temporal KG approach — rilevante per KORE-GC paper related work |
| boris-thariq-workflow | research | 5 | Follow-up: Boris Cherny workflow + Thariq Shihipar "Lessons from Building Claude Code" |

## Verifica

- `claude_task_list("PENDING")` dopo creazione task
- Report completi nei 4 file .md sotto plans/
