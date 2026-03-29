# Piano: SearXNG + Web Search MCP Tools

## Context

Claude Code ha due tool built-in per la ricerca web (`WebSearch`, `WebFetch`) che soffrono di un problema architetturale: le parallel tool calls sono trattate come gruppo atomico — se una fallisce, tutte vengono cancellate. Deployando SearXNG come meta-motore self-hosted e aggiungendo tool MCP equivalenti (`web_search`, `web_fetch`), le chiamate passano per il canale SSE di simoge-mcp e i failure sono isolati per singola chiamata.

## Step 1: Deploy SearXNG Docker

**Creare** `/data/massimiliano/searxng/`:

### `.env`
```
SEARXNG_SECRET=<openssl rand -hex 32>
```

### `settings.yml`
- `use_default_settings: true` (merge con defaults)
- `server.limiter: false` (uso interno, no rate limit)
- `search.formats: [html, json]` (abilita API JSON — critico, disabilitato di default)
- Categorie attive: general, science, it, news
- Disabilita engine pesanti (flickr, youtube, reddit, etc.)
- Redis DB 3 per caching: `redis://redis:6379/3`

### `docker-compose.yml`
- Image: `searxng/searxng:latest`
- Solo `expose: "8080"` (interno Docker, no nginx, no accesso pubblico)
- Network: `shared`
- Memory: 256m
- Healthcheck: `wget --spider -q http://localhost:8080/`
- `settings.yml` montato `:ro`

## Step 2: Creare WebSearchTools.java

**File**: `/data/massimiliano/Vari/mcp/src/main/java/com/example/mcp/tools/WebSearchTools.java`

Pattern: identico a `Context7Tools.java` — `@Service` + `@ReactiveTool` + WebClient inline + `Mono<String>` + `.onErrorResume()`.

### Tool `web_search`
- Chiama `http://searxng:8080/search?q=...&format=json&categories=...&language=...`
- Parametri: `query` (required), `maxResults` (default 10, max 30), `categories` (default "general"), `language` (default "auto")
- Restituisce JSON grezzo di SearXNG (array `results` con title/url/content per risultato)
- Claude lo interpreta nativamente

### Tool `web_fetch`
- WebClient separato (senza baseUrl, URL dinamici)
- `maxInMemorySize: 2MB` per pagine grandi
- Timeout: 15s
- Restituisce body raw (HTML/text)
- Equivalente resiliente di WebFetch built-in

Nessun `@ConditionalOnProperty` — come Context7Tools, sempre attivo. Se SearXNG è giù, `.onErrorResume()` restituisce messaggio d'errore.

## Step 3: Aggiungere env var a simoge-mcp

**File**: `/data/massimiliano/Vari/mcp/docker-compose.yml`

Aggiungere `MCP_WEBSEARCH_URL: http://searxng:8080` nell'environment (per rendere configurabile l'URL).

## Step 4: Build e deploy

```bash
# 1. Start SearXNG
cd /data/massimiliano/searxng && docker compose up -d

# 2. Verificare SearXNG
docker logs searxng --tail 20
docker exec searxng wget -qO- "http://localhost:8080/search?q=test&format=json" | head -c 500

# 3. Build simoge-mcp
cd /data/massimiliano/Vari/mcp
/opt/maven/bin/mvn clean package -DskipTests

# 4. Deploy simoge-mcp
docker compose up -d --build --force-recreate

# 5. Verificare tool registrati
docker logs simoge-mcp 2>&1 | grep -i "web_search\|web_fetch"
```

## Step 5: Aggiornare MEMORY.md

Aggiungere SearXNG in "Services & Databases" e i nuovi tool MCP in sezione prominente.

## Verifica end-to-end

1. Usare `web_search` da Claude Code: `web_search(query="spring boot 3.5", maxResults=5)`
2. Usare `web_fetch` da Claude Code: `web_fetch(url="https://example.com")`
3. Verificare che fallimenti isolati non cancellino altre chiamate parallele

## File coinvolti

| File | Azione |
|------|--------|
| `/data/massimiliano/searxng/.env` | Creare |
| `/data/massimiliano/searxng/settings.yml` | Creare |
| `/data/massimiliano/searxng/docker-compose.yml` | Creare |
| `/data/massimiliano/Vari/mcp/src/main/java/com/example/mcp/tools/WebSearchTools.java` | Creare |
| `/data/massimiliano/Vari/mcp/docker-compose.yml` | Modificare (aggiungere env var) |
| `/home/massimiliano/.claude/projects/-data-massimiliano/memory/MEMORY.md` | Modificare |

## Pattern riutilizzati

- `Context7Tools.java` — pattern `@Service` + `@ReactiveTool` + WebClient inline
- Docker compose standard SOL — shared network, expose, security_opt, healthcheck
- Redis DB partitioning — DB 3 libero (0-2 Gitea, 4 Preference Sort)
