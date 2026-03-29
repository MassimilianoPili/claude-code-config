# Rename simoge-mcp → hermes

## Context

Il server MCP si chiama `simoge-mcp` ovunque: container Docker, image tag, chiave MCP in `.claude.json`, prefisso tool (`mcp__simoge-mcp__*`), allowlist settings, agent definitions, docs, memory, KORE. Va rinominato in `hermes`.

**Perimetro**: codebase, KORE knowledge graph, settings varie. Esclusi: plans vecchi, logs, conversation JSONL, file-history.

## Fase 1 — Docker Infrastructure (edit files, NO restart)

| File | Cosa cambia |
|------|-------------|
| `/data/massimiliano/Vari/mcp/docker-compose.yml` | service: `simoge-mcp` → `hermes`, image: `hermes:latest`, container_name: `hermes` |
| `/data/massimiliano/Vari/mcp-proxy/docker-compose.yml` | `BACKEND_URL=http://simoge-mcp:8099` → `http://hermes:8099` |
| `/data/massimiliano/Vari/mcp-proxy/main.go:43` | default `"http://simoge-mcp:8099"` → `"http://hermes:8099"` |

**Nota**: nginx NON referenzia simoge-mcp (punta a `mcp-proxy:8098`). Nessuna modifica nginx.

## Fase 2 — Java Source (tool name)

| File | Cosa cambia |
|------|-------------|
| `/data/massimiliano/Vari/mcp/src/main/java/com/example/mcp/tools/ApiProxyTools.java:50` | `Generale_SIMOGE` → `Generale_HERMES` |

## Fase 3 — Claude Code Settings

| File | Cosa cambia | Count |
|------|-------------|-------|
| `/home/massimiliano/.claude.json:323` | chiave `"simoge-mcp"` → `"hermes"` in `mcpServers` | 1 |
| `/data/massimiliano/.claude/settings.json` | `mcp__simoge-mcp__` → `mcp__hermes__` | ~8 entries |
| `/data/massimiliano/claude-code-config/settings.json` | `mcp__simoge-mcp__` → `mcp__hermes__` + `Generale_SIMOGE` → `Generale_HERMES` | ~32 entries |

## Fase 4 — Hooks & Scripts

| File | Cosa cambia |
|------|-------------|
| `/data/massimiliano/claude-code-config/hooks/tool-outcome-tracker.sh` | `simoge-mcp` → `hermes` |
| `/data/massimiliano/shell-scripts/bin/mcp-token:75` | `.mcpServers["simoge-mcp"]` → `.mcpServers["hermes"]` |

## Fase 5 — Agent & Skill Definitions

| File | Cosa cambia |
|------|-------------|
| `/data/massimiliano/claude-shared/agents/academic-researcher.md` | `mcp__simoge-mcp__` → `mcp__hermes__` (lines 12, 41, 42) |
| `/data/massimiliano/claude-shared/agents/versioned/academic-researcher.v1.md` | idem (lines 12, 37) |
| `/data/massimiliano/claude-shared/skills/kubernetes-openshift-patterns/SKILL.md:26` | `simoge-mcp` → `hermes` |

## Fase 6 — Documentation (CLAUDE.md, README, docs/)

| File |
|------|
| `/data/massimiliano/CLAUDE.md` |
| `/data/massimiliano/README.md` |
| `/data/massimiliano/Vari/mcp/CLAUDE.md` |
| `/data/massimiliano/postgres/CLAUDE.md` |
| `/data/massimiliano/docs/mcp/spring-ai-reactive-tools.md` |
| `/data/massimiliano/docs/mcp-libraries.md` |
| `/data/massimiliano/docs/docs/mcp-libraries.md` |
| `/data/massimiliano/docs/docs/infra-overview.md` |
| `/data/massimiliano/docs/docs/servizi-docker.md` |
| `/data/massimiliano/docs/docs/indice.md` |
| `/data/massimiliano/docs/docs/rete-e-routing.md` |
| `/data/massimiliano/docs/infra-overview.md` |
| `/data/massimiliano/docs/servizi-docker.md` |
| `/data/massimiliano/docs/indice.md` |
| `/data/massimiliano/docs/rete-e-routing.md` |
| `/data/massimiliano/docs/progetti/gpu-coprocessor.md` |
| `/data/massimiliano/docs/progetti/mcp-remoto.md` |
| `/data/massimiliano/docs/progetti/llm-server.md` |

In tutti: `simoge-mcp` → `hermes`, `SIMOGE-MCP` → `HERMES`, `SimogeMCP` → `Hermes`.

## Fase 7 — Dashboard & Frontend

| File | Cosa cambia |
|------|-------------|
| `/data/massimiliano/proxy/home/timeline/index.html` | `'simoge-mcp': 'mcp'` → `'hermes': 'mcp'` |

## Fase 8 — Memory Files

| File |
|------|
| `/home/massimiliano/.claude/projects/-data-massimiliano/memory/MEMORY.md` |
| `/home/massimiliano/.claude/projects/-data-massimiliano/memory/project_mcp_proxy.md` |
| `/home/massimiliano/.claude/projects/-data-massimiliano/memory/feedback_mcp_sse_restart.md` |
| `/home/massimiliano/.claude/projects/-data-massimiliano/memory/reference_research.md` |
| `/home/massimiliano/.claude/projects/-data-massimiliano/memory/project_gpu_coprocessor.md` |

In tutti: `simoge-mcp` → `hermes`, `mcp__simoge-mcp__` → `mcp__hermes__`.

## Fase 9 — Future Projects

| File |
|------|
| `/data/massimiliano/progetti_futuri/PIANO_MCP_REMOTO.md` |
| `/data/massimiliano/progetti_futuri/PIANO_LLM_SERVER.md` |
| `/data/massimiliano/progetti_futuri/PIANO_GPU_COPROCESSOR.md` |

## Fase 10 — KORE Knowledge Graph (AGE)

Query Cypher per aggiornare nodi con proprietà `simoge-mcp`:
1. `MATCH (n) WHERE n.name = 'simoge-mcp' SET n.name = 'hermes'`
2. `MATCH (n) WHERE n.container_name = 'simoge-mcp' SET n.container_name = 'hermes'`
3. Update description/notes che contengono `simoge-mcp`

Via tool MCP: `graph_query` per trovare, `graph_write` per aggiornare.

## Deployment Sequence

1. **Edit tutti i file** (Fasi 1-9) — nessun restart
2. **Build image**: `cd /data/massimiliano/Vari/mcp && docker build -t hermes:latest .`
3. **Rebuild mcp-proxy**: `cd /data/massimiliano/Vari/mcp-proxy && docker build -t mcp-proxy:latest .`
4. **Restart MCP server**: `cd /data/massimiliano/Vari/mcp && docker compose up -d`
5. **Restart mcp-proxy**: `cd /data/massimiliano/Vari/mcp-proxy && docker compose up -d --force-recreate`
6. **Cleanup**: `docker rm -f simoge-mcp 2>/dev/null` (se ancora presente)
7. **Restart sessione Claude Code** — la nuova chiave `hermes` viene letta da `.claude.json`
8. **Update KORE** (Fase 10) — nella nuova sessione con i tool funzionanti

## Verifica

- `docker ps | grep hermes` → container running
- Chiamata `mcp__hermes__Generale_HERMES` → risposta OK
- `graph_query` per verificare nodi aggiornati nel KORE
