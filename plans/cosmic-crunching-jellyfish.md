# Piano: Swagger UI + MCP config endpoint su mcp-proxy

## Context

`mcp.massimilianopili.com` espone ~290 MCP tool ma chi visita `/` riceve un 404. Non esiste modo per un nuovo utente di scoprire come connettersi. L'agent card A2A esiste (`/.well-known/agent-card.json`) ma è orientata al protocollo A2A, non al client MCP.

Obiettivo: aggiungere **Swagger UI reale** su `/` (OpenAPI 3.0 spec inline, try-it-out con API key) + endpoint JSON `/mcp-config.json` per importazione automatica. Tutto servito dal proxy Go con `go:embed`.

## Endpoint da documentare nella spec OpenAPI

Tutti gli endpoint di mcp-proxy, raggruppati:

**MCP Transport** (auth: HMAC API Key)
- `GET /mcp` — SSE stream per notifiche server-initiated
- `POST /mcp` — JSON-RPC request (tools/call, initialize), risposta JSON o SSE
- `DELETE /mcp` — Chiudi sessione esplicitamente

**Health**
- `GET /health` — Status, stats, backend reachability (pubblico, no auth)

**A2A Gateway** (auth: HMAC o OAuth2 CC)
- `POST /a2a/message:send` — Dispatch tool sincrono
- `POST /a2a/message:stream` — Dispatch con SSE streaming
- `GET /a2a/tasks` — Lista task recenti
- `GET /a2a/tasks/{id}` — Dettaglio task
- `POST /a2a/tasks/{id}:cancel` — Cancella task

**Discovery** (pubblico)
- `GET /.well-known/agent-card.json` — Agent Card A2A v1.0
- `GET /mcp-config.json` — Template config client MCP (nuovo)

**Admin** (auth: Keycloak Bearer, no visitor)
- `GET /generate-key` — Genera HMAC API key (query: ttl, name)
- `POST /revoke-key` — Revoca una key
- `GET /list-keys` — Lista key attive
- `GET /revoked-keys` — Lista key revocate

## File da modificare/creare

| File | Azione |
|------|--------|
| `/data/massimiliano/Vari/mcp-proxy/static/index.html` | **Nuovo** — Swagger UI con spec OpenAPI inline |
| `/data/massimiliano/Vari/mcp-proxy/main.go` | Aggiungere `go:embed`, handler landing + config, 2 route |
| `/data/massimiliano/Vari/mcp-proxy/Dockerfile` | Aggiungere `COPY static/ static/` nel build stage |

## Implementazione

### Step 1: Creare `static/index.html` — Swagger UI

Single-file HTML che carica Swagger UI da CDN (`unpkg.com/swagger-ui-dist`):

```html
<!DOCTYPE html>
<html>
<head>
  <title>SOL MCP Server — API</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
  <script>
    SwaggerUIBundle({
      spec: { /* OpenAPI 3.0 spec inline — vedi sotto */ },
      dom_id: '#swagger-ui',
      deepLinking: true,
      presets: [SwaggerUIBundle.presets.apis, SwaggerUIBundle.SwaggerUIStandalonePreset],
      layout: "StandaloneLayout"
    })
  </script>
</body>
</html>
```

La **spec OpenAPI** è un oggetto JS inline con:
- `info`: titolo "SOL MCP Server", versione "1.0.0", descrizione con link agent card + contatore ~290 tool
- `servers`: `https://mcp.massimilianopili.com`
- `tags`: MCP Transport, A2A Gateway, Discovery, Admin, Health
- `paths`: tutti gli endpoint sopra elencati, con request/response schema
- `components.securitySchemes`:
  - `hmacApiKey`: type apiKey, in header, name X-API-Key
  - `oauth2`: client credentials flow con tokenUrl Keycloak
- Sezione custom in `info.description` (markdown) con il template `.claude.json` copiabile

**Personalizzazioni visual**:
- Dark theme opzionale via CSS override (`.swagger-ui { ... }`) — coerente con dashboard SOL
- Sezione "Quick Start" nell'info description con config JSON Claude Code

### Step 2: Aggiungere `go:embed` + handler in main.go

In cima al file (dopo gli import), aggiungere:

```go
import "embed"

//go:embed static/index.html
var landingHTML []byte
```

Nuovi handler (funzioni standalone, non metodi su Proxy — sono pubblici senza auth):

```go
func handleLanding(w http.ResponseWriter, r *http.Request) {
    if r.URL.Path != "/" {
        http.NotFound(w, r)  // Evita che "/" catch-all serva la landing per path sconosciuti
        return
    }
    w.Header().Set("Content-Type", "text/html; charset=utf-8")
    w.Header().Set("Cache-Control", "public, max-age=3600")
    w.Write(landingHTML)
}

func handleMCPConfig(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    w.Header().Set("Cache-Control", "public, max-age=3600")
    w.Header().Set("Access-Control-Allow-Origin", "*")
    w.Write([]byte(mcpConfigJSON))
}
```

`mcpConfigJSON` — costante stringa:
```go
const mcpConfigJSON = `{
  "mcpServers": {
    "sol-mcp": {
      "type": "http",
      "url": "https://mcp.massimilianopili.com/mcp",
      "timeout": 300,
      "headers": {
        "X-API-Key": "<YOUR_API_KEY>"
      }
    }
  }
}`
```

**Nota importante su `"/"`**: Il `handleLanding` controlla `r.URL.Path != "/"` per restituire 404 sui path non matchati. Senza questo check, Go `ServeMux` ruoterebbe qualsiasi path sconosciuto alla landing page.

### Step 3: Registrare route in main.go (dopo riga 992)

```go
// Public pages — no auth
mux.HandleFunc("/", handleLanding)
mux.HandleFunc("/mcp-config.json", handleMCPConfig)
```

### Step 4: Aggiornare Dockerfile (riga 4)

```dockerfile
FROM golang:1.25-alpine AS builder
WORKDIR /app
COPY go.mod ./
COPY *.go .
COPY static/ static/     # <-- AGGIUNTO: embed richiede i file a build time
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o mcp-proxy .

FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app/mcp-proxy /mcp-proxy
EXPOSE 8098
CMD ["/mcp-proxy"]
```

### Step 5: Deploy

```bash
cd /data/massimiliano/Vari/mcp-proxy
docker compose build --no-cache
sol deploy mcp-proxy
```

## Verifica

1. `curl https://mcp.massimilianopili.com/` → HTML con Swagger UI
2. `curl https://mcp.massimilianopili.com/mcp-config.json` → JSON config template
3. `curl https://mcp.massimilianopili.com/.well-known/agent-card.json` → agent card (invariato)
4. `curl https://mcp.massimilianopili.com/health` → health check (invariato)
5. `curl https://mcp.massimilianopili.com/nonexistent` → 404 (non la landing page)
6. Browser: aprire `https://mcp.massimilianopili.com/` — Swagger UI con try-it-out funzionante
7. Swagger try-it-out: testare `/health` (no auth) e `/mcp` POST (con API key nell'Authorize)
