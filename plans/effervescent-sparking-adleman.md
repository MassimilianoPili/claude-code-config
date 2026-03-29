# Piano: MCP Remoto — API Key con Scadenza (HMAC Stateless)

## Context

L'MCP server (`simoge-mcp`, ~234 tool) è esposto su nginx `:8095` con JWT auth via jwt-gateway.
L'utente vuole che il client remoto mandi **solo un secret** in `~/.claude.json` — il server
gestisce il token exchange con Keycloak trasparentemente. Il secret deve avere una **scadenza**
per limitare il danno in caso di compromissione.

**Vincoli**: nginx:alpine non ha njs/Lua. Tutta la logica va nel jwt-gateway (Go).
Esposizione pubblica su Cloudflare Tunnel senza restrizioni aggiuntive.

## Design

### API Key HMAC auto-validanti

Le API key hanno scadenza codificata al loro interno. Nessun database, nessuno stato.

**Formato key**: `base64url( expiry_unix + "." + hex(HMAC-SHA256(expiry_unix, SERVER_SECRET)) )`

Validazione: decodifica → split su `.` → verifica HMAC → controlla scadenza. Zero storage.

### Flusso target

```
Generazione (sul server, una tantum o quando scade):
  curl http://localhost:8094/generate-key?ttl=30d
  → { "key": "MTc1...", "expires": "2026-04-13T15:30:00Z" }

Client (~/.claude.json):
  { "headers": { "X-API-Key": "MTc1..." } }

Richiesta:
  Client → X-API-Key → nginx :8095 → auth_request → jwt-gateway /validate
    → verifica HMAC + scadenza
    → Client Credentials exchange con Keycloak (cachato ~29 min)
    → set X-Auth-* headers → 200
    → nginx proxies to simoge-mcp:8099
```

### Cosa cambia in jwt-gateway (`main.go`)

**Nuove funzioni** (~80 righe):

1. **`handleGenerateKey(serverSecret string)`** — endpoint `GET /generate-key?ttl=30d`
   - Parametro `ttl`: formato Go duration esteso (`30d`=30*24h, `7d`, `24h`, `1h`)
   - Default: `7d`. Max: `90d`
   - Genera: `expiry_unix.HMAC-SHA256(expiry_unix, SERVER_SECRET)` → base64url
   - Ritorna JSON: `{"key":"...","expires":"2026-04-13T15:30:00Z","ttl":"720h0m0s"}`

2. **`validateAPIKey(apiKey, serverSecret string) bool`**
   - Decodifica base64url → split su `.` → `expiryStr` + `hmacHex`
   - Ricalcola HMAC con `serverSecret`, confronto constant-time (`hmac.Equal`)
   - Controlla `expiry > time.Now().Unix()`
   - Ritorna `true` se valido, `false` se scaduto o manomesso

3. **`cachedExchange(clientID, clientSecret, tokenURL string) (string, error)`**
   - `sync.Mutex` + struct `{token string, expiresAt time.Time}`
   - Se cache valida (expiresAt > now + 60s margine) → ritorna token cachato
   - Altrimenti → POST a Keycloak Client Credentials, cache risultato
   - Log: solo al primo exchange e al rinnovo

4. **Modifica `handleValidate()`** — fallback da Bearer a X-API-Key:
   ```go
   func handleValidate(w http.ResponseWriter, r *http.Request) {
       bearer := r.Header.Get("Authorization")

       if !strings.HasPrefix(bearer, "Bearer ") {
           apiKey := r.Header.Get("X-API-Key")
           if apiKey == "" {
               w.WriteHeader(http.StatusUnauthorized)
               return
           }
           if !validateAPIKey(apiKey, serverSecret) {
               log.Printf("API key validation failed (expired or invalid)")
               w.WriteHeader(http.StatusUnauthorized)
               return
           }
           // API key valida → exchange con Keycloak (cachato)
           token, err := cachedExchange(mcpClientID, mcpClientSecret, tokenURL)
           if err != nil {
               log.Printf("Keycloak exchange failed: %v", err)
               w.WriteHeader(http.StatusBadGateway)
               return
           }
           bearer = "Bearer " + token
       }

       tokenStr := strings.TrimPrefix(bearer, "Bearer ")
       // ... resto invariato (validateAndSetHeaders + readonly check)
   }
   ```

5. **`main()`** — nuove env var + endpoint:
   ```go
   serverSecret := os.Getenv("API_KEY_SECRET")    // HMAC secret
   mcpClientID := os.Getenv("MCP_CLIENT_ID")       // "mcp-client"
   mcpClientSecret := os.Getenv("MCP_CLIENT_SECRET")
   // ...
   mux.HandleFunc("GET /generate-key", handleGenerateKey(serverSecret))
   ```

### Cosa cambia in nginx

**Nulla.** La `auth_request` subrequest inoltra automaticamente tutti gli header
(incluso `X-API-Key`). Header HTTP case-insensitive (RFC 7230).

### Variabili d'ambiente jwt-gateway

In `docker-compose.yml` aggiungere:
```yaml
environment:
  - API_KEY_SECRET=${API_KEY_SECRET}
  - MCP_CLIENT_ID=mcp-client
  - MCP_CLIENT_SECRET=${MCP_CLIENT_SECRET}
```

In `.env` aggiungere:
```
API_KEY_SECRET=<openssl rand -hex 32>
MCP_CLIENT_SECRET=<il secret del client mcp-client in Keycloak>
```

### Sicurezza

- **Scadenza**: key HMAC con TTL integrato, non prorogabile, non modificabile
- **Stateless**: nessun database di key. Rigenerando `API_KEY_SECRET` si invalidano TUTTE le key
- **Revoca globale**: cambiare `API_KEY_SECRET` → rebuild → tutte le key precedenti invalide
- **`/generate-key` protetto**: accessibile solo dalla rete Docker (porta 8094 non esposta)
- **Separazione**: il client conosce solo la API key. `MCP_CLIENT_SECRET` di Keycloak resta interno
- **Constant-time comparison**: `hmac.Equal()` previene timing attack

## File da modificare

| File | Modifica |
|------|----------|
| `/data/massimiliano/Vari/jwt-gateway/main.go` | +`handleGenerateKey`, +`validateAPIKey`, +`cachedExchange`, mod `handleValidate`, mod `main` |
| `/data/massimiliano/Vari/jwt-gateway/docker-compose.yml` | +3 env var (`API_KEY_SECRET`, `MCP_CLIENT_ID`, `MCP_CLIENT_SECRET`) |
| `/data/massimiliano/Vari/jwt-gateway/.env` | +`API_KEY_SECRET`, +`MCP_CLIENT_SECRET` |

## Cosa NON cambia

- Bearer JWT continua a funzionare (prima priorità in `handleValidate`)
- `mcp-token` script resta funzionante
- Accesso locale (`localhost:8099/sse`) non toccato
- Backend simoge-mcp non toccato
- Altri servizi (`/server/`, `/rank/`, etc.) non impattati (non mandano `X-API-Key`)
- nginx non richiede modifiche né recreate

## Stato implementazione

✅ **Completata** (2026-03-14): codice, docker-compose, .env, AGE graph, MEMORY.md tutti aggiornati.

## Fase corrente: allineamento documentazione statica

Il KORE (AGE + pgvector) è aggiornato. Mancano aggiornamenti ai file statici (fallback/bootstrap):

### 1. CLAUDE.md — sezione "MCP Server remoto" (righe 200-207)

Riscrivere la sottosezione per documentare entrambi i metodi auth:

```markdown
### MCP Server remoto (`:8095`)
`simoge-mcp` esposto su nginx `:8095` con auth via `jwt-gateway`. Accesso multi-device:
- **Tailscale**: `http://100.86.46.84:8095/sse`
- **Pubblico**: `https://mcp.massimilianopili.com/sse` (Cloudflare Tunnel)
- **Locale**: `localhost:8099/sse` (diretto, senza auth)

Due metodi auth (jwt-gateway li gestisce trasparentemente):
1. **API Key HMAC** (consigliato): key stateless con scadenza integrata (HMAC-SHA256).
   Generazione: `docker exec jwt-gateway /wget -qO- "http://localhost:8094/generate-key?ttl=30d"`.
   Config client: `{"headers":{"X-API-Key":"<key>"}}`.
   Revoca globale: rigenerare `API_KEY_SECRET` → rebuild jwt-gateway.
2. **Bearer JWT**: `mcp-token` script (Client Credentials, token 30min, rinnovo manuale).

Client Keycloak `mcp-client` (Client Credentials, token 30 min).
Rate limit: 30r/s burst 50. SSE timeout 1h.
Piano completo: `/data/massimiliano/docs/progetti/mcp-remoto.md`.
```

### 2. docs/progetti/mcp-remoto.md — aggiungere Fase 3

Appendere sezione "Fase 3: API Key HMAC stateless" dopo il contenuto esistente:
- Formato key HMAC
- Endpoint `/generate-key?ttl=...`
- Flusso: X-API-Key → jwt-gateway → HMAC verify → cached Client Credentials → JWT → headers
- Sicurezza (scadenza, revoca globale, constant-time, `/generate-key` non esposto)
- Esempio config `~/.claude.json`

### 3. docs/sicurezza.md — aggiornare riga MCP

Nella tabella routing/auth, aggiornare la riga MCP Server da "JWT Bearer" a "JWT Bearer o API Key HMAC (dual-auth)".

### 4. jwt-gateway/README.md — sezione API Key

Aggiungere sezione con:
- Endpoint `/generate-key?ttl=Xd` (default 7d, max 90d)
- Header `X-API-Key` in `/validate`
- Cached Client Credentials exchange (~29 min)
- Revoca: rotazione `API_KEY_SECRET`

## Verifica

1. Rebuild jwt-gateway (già fatto):
   ```bash
   cd /data/massimiliano/Vari/jwt-gateway && docker compose up -d --build --force-recreate
   ```
2. Generare una key (dal server):
   ```bash
   docker exec jwt-gateway /wget -qO- "http://localhost:8094/generate-key?ttl=30d"
   ```
3. Test API key via Tailscale:
   ```bash
   KEY=$(docker exec jwt-gateway /wget -qO- "http://localhost:8094/generate-key?ttl=1h" | jq -r .key)
   curl -s -N -H "X-API-Key: $KEY" http://100.86.46.84:8095/sse
   ```
4. Test key scaduta (TTL cortissimo):
   ```bash
   KEY=$(docker exec jwt-gateway /wget -qO- "http://localhost:8094/generate-key?ttl=5s" | jq -r .key)
   sleep 6
   curl -s -H "X-API-Key: $KEY" http://100.86.46.84:8095/sse  # → 401
   ```
5. Test Bearer JWT (regressione):
   ```bash
   TOKEN=$(mcp-token --show)
   curl -s -N -H "Authorization: Bearer $TOKEN" http://100.86.46.84:8095/sse
   ```
6. Test da macchina remota con `~/.claude.json` + key da 30d
7. Verifica docs: grep "API Key HMAC" in CLAUDE.md, mcp-remoto.md, sicurezza.md, README.md
