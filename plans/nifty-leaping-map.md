# Fix OOM: MCP singleton SSE + memory limits

## Context

Il server SOL ha subito 3 crash OOM in sequenza (13:04, 13:26, ~14:13 del 2026-03-08).
Root cause: ogni sessione Claude Code spawna un processo JVM via stdio transport per il MCP server.
Con 10 finestre VS Code Remote SSH aperte → 10 JVM × 512m = fino a 5GB solo per il MCP, su 7.6GB totali.

Soluzione: passare da stdio (un processo JVM per sessione) a SSE/HTTP (un singolo container Docker condiviso).

---

## Stato Attuale — Molto è Già Fatto ✅

L'esplorazione del codebase rivela che quasi tutta l'infrastruttura è già in posizione:

| Componente | Stato | Dettaglio |
|---|---|---|
| `application-sse.properties` | ✅ ESISTE | `web-application-type=reactive`, `server.port=8099` |
| `Vari/mcp/Dockerfile` | ✅ ESISTE | `eclipse-temurin:21-jre-alpine`, `-Xmx512m`, EXPOSE 8099 |
| `Vari/mcp/docker-compose.yml` | ✅ ESISTE | `mem_limit: 512m`, porta `127.0.0.1:8099`, `SPRING_PROFILES_ACTIVE=sse` |
| Container `simoge-mcp` | ✅ RUNNING | `Up 3 minutes, 127.0.0.1:8099->8099/tcp` |
| Optional workers (45) in agentfw compose | ✅ GIÀ PRESENTI | `profiles: [optional]`, pattern A–E con mem_limit corretti |
| `docker.service.d/memory.conf` | ✅ APPLICATO | `MemoryMax=6G`, `MemorySwapMax=6G` |
| `~/.claude.json` → `simoge-mcp` | ❌ ANCORA STDIO | `"type": "stdio"` — **unico cambiamento necessario** |

---

## Piano di Esecuzione

### Step 1 — Verifica SSE endpoint (read-only)

Prima di aggiornare la config, verificare che il container risponda:

```bash
# Verifica health
curl -s http://localhost:8099/sse --max-time 3 -o /dev/null -w "%{http_code}\n"
# Atteso: 200 con stream SSE aperto (o verificare log)
docker logs simoge-mcp --tail 20
```

### Step 2 — Aggiornare `~/.claude.json`

**File**: `/home/massimiliano/.claude.json`

Sostituire il blocco `simoge-mcp`:

```json
// DA (stdio - un JVM per sessione):
"simoge-mcp": {
  "type": "stdio",
  "command": "/opt/java21/bin/java",
  "args": ["-Xmx512m", "-jar", "...mcp-server-0.0.1-SNAPSHOT.jar"],
  "env": { ... }
}

// A (SSE - singleton condiviso):
"simoge-mcp": {
  "type": "sse",
  "url": "http://localhost:8099/sse"
}
```

> Il blocco `env` viene rimosso: le variabili sono già nel docker-compose.yml del container.

### Step 3 — Terminare sessioni Claude attive

```bash
# Verifica processi JVM stdio MCP ancora in esecuzione
ps aux | grep mcp-server | grep -v grep

# Se presenti, terminare (graceful):
pkill -f mcp-server-0.0.1-SNAPSHOT.jar
```

### Step 4 — Riavviare Claude Code

Tutte le nuove sessioni useranno il transport SSE e si connetteranno al container singleton.
**Nessun downtime per il container** `simoge-mcp` (già running, restart: unless-stopped).

---

## Trade-off da Documentare

### Playwright disabilitato in Docker
- **Stdio (prima)**: `MCP_PLAYWRIGHT_ENABLED=true` (browser sulla macchina host)
- **SSE/Docker (dopo)**: `MCP_PLAYWRIGHT_ENABLED=false` (no display nel container)
- **Impatto**: i tool Playwright MCP (`browser_navigate`, `browser_screenshot`, ecc.) non saranno disponibili
- **Alternativa**: usare il plugin Playwright MCP nativo di Claude Code (già installato), che gira sull'host

### Embeddings e DevOps tools
- Rimangono funzionanti: il volume `/data/massimiliano` è montato RW nel container
- PostgreSQL embeddings: connessione via `postgres:5432` (rete Docker `shared`) anziché `127.0.0.1:5432`
- Azure DevOps PAT: già configurato nel docker-compose.yml

---

## File Critici

| File | Azione |
|---|---|
| `/home/massimiliano/.claude.json` | **MODIFICARE**: da stdio a sse |
| `/data/massimiliano/Vari/mcp/docker-compose.yml` | Read-only (già corretto) |
| `/data/massimiliano/Vari/mcp/src/main/resources/application-sse.properties` | Read-only (già corretto) |
| `/data/massimiliano/agent-framework/docker/docker-compose.sol.yml` | Read-only (già corretto) |
| `/etc/systemd/system/docker.service.d/memory.conf` | Read-only (già applicato) |

---

## Verifica Finale

```bash
# 1. Nessun processo JVM mcp-server sull'host
ps aux | grep mcp-server | grep -v grep
# Atteso: nessuna riga

# 2. Container running con memoria stabile
docker stats simoge-mcp --no-stream
# Atteso: MEM USAGE ~200-400m / LIMIT 512m

# 3. RAM host liberata
free -m
# Atteso: available > 1.5GB (prima del fix era < 200MB prima del crash)

# 4. Limite Docker daemon attivo
systemctl show docker --property MemoryMax
# Atteso: MemoryMax=6442450944 (6GB in byte)

# 5. SSE endpoint risponde
curl -s http://localhost:8099/sse -N --max-time 5
# Atteso: stream SSE aperto (non 404/502)
```

---

## Note Architetturali

**Perché SSE è meglio di stdio per questo caso d'uso:**
- stdio: il client MCP (Claude Code) spawna un processo figlio e comunica via pipe — ogni sessione crea una propria istanza
- SSE: il client MCP si connette via HTTP al server già in ascolto — tutte le sessioni condividono la stessa istanza
- Con SSE, l'overhead di memoria passa da O(n_sessioni) a O(1)

**Dipendenze Spring AI per SSE:**
- `mcp-spring-webflux:0.10.0` — già nel pom.xml ✅
- `spring-boot-starter-webflux` — già nel pom.xml ✅
- Endpoint SSE di default: `/sse` (Spring AI MCP WebFlux auto-configuration)
