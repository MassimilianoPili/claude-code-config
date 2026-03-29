# Piano: Redis messaging + AGE CLAUDE.md

## Contesto
- `simoge-mcp` è già il solo MCP server (SSE, `http://localhost:8099/sse`) ✅
- `mcp-redis-tools` v0.1.0 è **già implementata** (11 tool: 6 KV generico + 5 inter-Claude su DB5)
  ma **non abilitata** nel docker-compose (manca `MCP_REDIS_ENABLED=true`)
- Apache AGE è compilato e funziona, con 3 grafi in `embeddings` DB, ma manca documentazione
  operativa (data model, query patterns, troubleshooting)

---

## Azione 1 — Abilitare Redis nel docker-compose

**File**: `/data/massimiliano/Vari/mcp/docker-compose.yml`

Aggiungere sotto le env esistenti:
```yaml
MCP_REDIS_ENABLED: "true"
MCP_REDIS_URL: redis://redis:6379
```

La lib usa DB 0 per KV generico e DB 5 (hardcoded) per inter-Claude messaging.

---

## Azione 2 — Build e deploy

```bash
cd /data/massimiliano/Vari/mcp
/opt/maven/bin/mvn clean package -DskipTests
docker build -t simoge-mcp:latest .
docker compose up -d --force-recreate
```

Poi commit + push del docker-compose aggiornato.

---

## Azione 3 — CLAUDE.md per Apache AGE

**File da creare**: `/data/massimiliano/postgres/CLAUDE.md`

Struttura:
1. **Setup** — Dockerfile multi-stage (pgvector base → AGE da sorgente), init script `03-age.sh`
2. **Connessione** — JDBC `jdbc:postgresql://postgres:5432/embeddings`, user `postgres`
3. **I tre grafi** — `knowledge_graph`, `code_graph`, `task_graph` (scopo + data model di ciascuno)
4. **Query Cypher via AGE** — sintassi SQL wrapper, pattern MATCH/CREATE/MERGE, limitazioni vs Neo4j
5. **Tool MCP** — `graph_query`, `graph_write`, `graph_schema`, `graph_stats`, `graph_list_backends`
6. **Configurazione simoge-mcp** — env vars `MCP_GRAPH_AGE_*`
7. **Troubleshooting** — errori comuni AGE, `search_path`, `LOAD 'age'`, agtype parsing
8. **Manutenzione** — backup pg_dump, monitoring

---

## Verifica

```bash
# Redis tools attivi?
# Via MCP: claude_list_inboxes() → deve restituire lista (anche vuota)
# Via MCP: claude_send(to="session-B", message="ciao") → deve tornare "sent"

# AGE ok?
# Via MCP: graph_list_backends() → deve mostrare "age" available: true
# Via MCP: graph_schema() → deve mostrare i 3 grafi
```
