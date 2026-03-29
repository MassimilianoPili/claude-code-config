# Piano: puntare Claude Code locale a mcp-proxy

## Contesto

mcp-proxy e' deployato e funzionante (`:8098`), nginx semplificato, test end-to-end OK.
Ultimo step: aggiornare la config MCP locale di Claude Code per usare il proxy
invece del backend diretto (`localhost:8099`).

## Cosa fare

File: `/home/massimiliano/.claude.json`

Cambiare `mcpServers.simoge-mcp.url`:
- **Prima**: `http://localhost:8099/sse` (backend diretto, sessioni stale dopo restart)
- **Dopo**: `http://localhost:8098/sse` (mcp-proxy, session resilience)

Nessun altro campo da cambiare — `type: "sse"` e `timeout: 300` restano uguali.

## Verifica

1. Verificare che la sessione corrente usi ancora il vecchio URL (8099)
2. Aggiornare il campo url in `.claude.json`
3. Le sessioni successive useranno automaticamente mcp-proxy

## Architettura (riferimento)

### Prima
```
Client --> Cloudflare --> nginx:8095 (auth_request -> jwt-gateway:8094) --> simoge-mcp:8099
```

### Dopo
```
Client --> Cloudflare --> nginx:8095 (proxy_pass, no auth) --> mcp-proxy:8098 (auth + SSE) --> simoge-mcp:8099
                                                                |
Tailscale (100.86.46.84:8095) --> nginx:8095 ───────────────────+
```

nginx:8095 resta come entry point ma viene semplificato: solo proxy_pass a mcp-proxy,
niente auth_request, niente jwt-gateway. Il proxy gestisce auth + session resilience.

## Autenticazione

### HMAC API Key (primaria, zero dipendenze)
Stessa logica di jwt-gateway. Formato key: `base64url(unix_expiry + "." + hex(hmac_sha256(expiry, secret)))`.

Validazione (stdlib pura):
1. Base64url decode
2. Split su primo "."
3. Ricalcola HMAC-SHA256, confronto constant-time
4. Verifica expiry < now

Env var: `API_KEY_SECRET` (stesso valore di jwt-gateway).
Header client: `X-API-Key: <key>`.

### Bearer JWT (supporto opzionale, fase 2)
Non implementato nella prima versione. Se serve, si aggiunge dopo con JWKS fetch da Keycloak.
Per ora HMAC copre tutti i casi d'uso remoto.

### Accesso locale (no auth)
Richieste da `localhost` o dalla rete Docker (simoge-mcp diretto su :8099) non passano dal proxy.
Il proxy puo' opzionalmente bypassare auth per richieste interne (header `X-Forwarded-For` o source IP check).

### Endpoint generazione key
`GET /generate-key?ttl=30d` — genera API key HMAC. Stesso formato di jwt-gateway.
Accesso solo da localhost/Tailscale (no auth richiesta, protetto da rete).

## Session Resilience SSE

### Session remapping
| Lato | SessionId | Chi lo genera |
|------|-----------|---------------|
| Client -> Proxy | `proxySessionId` | Proxy (stabile) |
| Proxy -> Backend | `backendSessionId` | Backend (cambia ad ogni restart) |

Proxy intercetta solo `event: endpoint` per riscrivere sessionId.
Tutti gli `event: message` sono forwarded verbatim.

### Backend restart (flusso core)
1. SSE stream del backend muore (EOF)
2. Proxy rileva, marca backend disconnesso
3. Proxy invia keepalive sintetici ai client (pings ogni 15s)
4. Riconnessione con backoff esponenziale (1s, 2s, 4s, 8s, max 15s)
5. Backend torna up -> nuovo `backendSessionId`, aggiorna mapping
6. Replay richieste in coda, client non si accorge di nulla

## Struttura progetto

```
/data/massimiliano/Vari/mcp-proxy/
├── main.go              # Tutto in un file (~500-600 righe), zero dipendenze esterne
├── go.mod               # module mcp-proxy, go 1.22
├── Dockerfile           # golang:1.22-alpine -> scratch
└── docker-compose.yml   # Container mcp-proxy, shared network, 64m
```

### HTTP routes
- `GET /sse` -> `handleSSE` (auth + sessione + forwarding + keepalive sintetico)
- `POST /mcp/message` -> `handleMessage` (auth + lookup + remap sessionId + forward/queue)
- `GET /health` -> `handleHealth` (stato proxy + backend + sessioni + auth status)
- `GET /generate-key` -> `handleGenerateKey` (genera API key HMAC, solo localhost/Tailscale)

### Parametri configurabili (env vars)
- `PORT` (default: 8098)
- `BACKEND_URL` (default: `http://simoge-mcp:8099`)
- `API_KEY_SECRET` (obbligatorio per auth remoto)
- `KEEPALIVE_INTERVAL` (default: 15s)
- `RECONNECT_MAX_BACKOFF` (default: 15s)
- `QUEUE_MAX_SIZE` (default: 50)
- `QUEUE_MAX_AGE` (default: 60s)
- `RATE_LIMIT` (default: 30, req/s per IP)
- `RATE_BURST` (default: 50)

## Modifiche infrastruttura

### 1. Nginx: semplificare server block :8095
Il server block :8095 resta ma viene ridotto drasticamente.
Rimuovere: auth_request, jwt-gateway, rate limiting (il proxy li gestisce).
Tenere: proxy_pass a mcp-proxy:8098, SSE headers (proxy_buffering off, timeout 3600s).

Prima (~70 righe, 3 location con auth):
```nginx
server { listen 8095;
  location = /sse { auth_request .../jwt/validate; proxy_pass simoge-mcp:8099; }
  location /mcp/message { auth_request .../jwt/validate; proxy_pass simoge-mcp:8099; }
  location = /health { proxy_pass simoge-mcp:8099; }
}
```

Dopo (~20 righe, passthrough puro):
```nginx
server { listen 8095;
  location / {
    set $mcp http://mcp-proxy:8098;
    proxy_pass $mcp;
    proxy_http_version 1.1;
    proxy_set_header Connection '';
    proxy_buffering off;
    proxy_cache off;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
  }
}
```

### 2. Cloudflare tunnel: nessuna modifica
Cloudflare continua a puntare a nginx:8095. nginx fa passthrough a mcp-proxy.

### 3. Tailscale: nessuna modifica
Tailscale continua ad accedere via 100.86.46.84:8095 -> nginx -> mcp-proxy.

## Edge cases

| Scenario | Gestione |
|----------|----------|
| Multi-client | Sessione indipendente per ogni client |
| Backend crash loop | Backoff esponenziale, keepalive sintetici, queue TTL 60s |
| Slow startup (30s) | Keepalive mantiene client, riconnessione tollerante |
| Queue overflow (>50) | POST ritorna 503 |
| Proxy restart | Stateless, start <1s (scratch + Go) |
| API key expired | 401 Unauthorized |
| API key mancante | 401 Unauthorized |
| Rate limit exceeded | 429 Too Many Requests |
| /generate-key da remoto | 403 Forbidden (solo localhost/Tailscale) |

## File di riferimento

| File | Scopo |
|------|-------|
| `/data/massimiliano/Vari/jwt-gateway/main.go` | Logica HMAC: `validateAPIKey`, `generateAPIKey` |
| `/data/massimiliano/Vari/anthropic-api-proxy/main.go` | Pattern Go: stdlib HTTP, zero-dep |
| `/data/massimiliano/Vari/anthropic-api-proxy/Dockerfile` | Pattern Docker: multi-stage -> scratch |
| `/data/massimiliano/proxy/nginx.conf` | Server block :8095 da semplificare (solo proxy_pass) |

## Sequenza implementazione

1. Scaffold progetto (`go.mod`, `Dockerfile`, `docker-compose.yml`)
2. Auth HMAC (`validateAPIKey`, `generateAPIKey`, middleware)
3. SSE parser (line-based, accumula event+data)
4. Backend connection (`connectToBackend()` -> GET /sse, parse endpoint)
5. `handleSSE`: auth + sessione + forwarding + keepalive sintetico
6. `handleMessage`: auth + lookup + remap sessionId + forward/queue
7. Reconnection loop: backoff, queue replay
8. `handleHealth` + `handleGenerateKey`
9. Rate limiter (token bucket per IP, stdlib)
10. Build + deploy container
11. Semplificare server block nginx :8095 (solo proxy_pass), force-recreate nginx
13. Test end-to-end completo

## Verifica

1. `docker compose up -d --build` in mcp-proxy
2. `curl -H "X-API-Key: <key>" http://localhost:8098/health` -> 200
3. `curl http://localhost:8098/health` (senza key) -> 200 (health e' pubblico)
4. `curl http://localhost:8098/generate-key?ttl=1h` -> nuova key
5. `curl -sN -H "X-API-Key: <key>" http://localhost:8098/sse` -> endpoint + keepalive pings
6. Tool call MCP via Claude Code -> deve funzionare
7. `docker restart simoge-mcp` -> aspettare 30s -> tool call -> **deve funzionare senza riavviare sessione**
8. Semplificare nginx :8095, force-recreate
9. Tool call via `mcp.massimilianopili.com` (Cloudflare -> nginx -> proxy) -> deve funzionare
10. Tool call via Tailscale `:8095` (nginx -> proxy) -> deve funzionare
