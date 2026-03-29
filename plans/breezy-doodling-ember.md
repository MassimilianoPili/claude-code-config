# Piano: OpenAPI specs per 5 servizi + registrazione Swagger UI

## Context

SOL ha 5 servizi HTTP custom senza documentazione OpenAPI. La Swagger UI a `/docs/` serve già 4 spec (Proxy AI, Codex, Copilot, Preference Sort). Obiettivo: creare spec OpenAPI 3.0.3 per i 5 servizi mancanti e registrarli nel dropdown Swagger UI. Zero impatto runtime — sono file YAML statici.

---

## Spec da creare

### 1. `a2a-gateway.yml` — A2A Gateway (6 endpoint)

| Method | Path | Auth | Descrizione |
|--------|------|------|-------------|
| GET | `/.well-known/agent-card.json` | Nessuna | Agent Card discovery |
| POST | `/a2a/message:send` | HMAC/OAuth2 | Invio messaggio sincrono |
| POST | `/a2a/message:stream` | HMAC/OAuth2 | Invio messaggio SSE streaming |
| GET | `/a2a/tasks` | HMAC/OAuth2 | Lista task |
| GET | `/a2a/tasks/{id}` | HMAC/OAuth2 | Stato task |
| POST | `/a2a/tasks/{id}:cancel` | HMAC/OAuth2 | Cancella task |

Schemas: A2ATask, A2AMessage, A2APart, A2AArtifact, ToolDispatch.
Servers: `https://sol.massimilianopili.com`, `http://100.86.46.84`.

### 2. `mcp-proxy.yml` — MCP Proxy Admin (6 endpoint)

| Method | Path | Auth | Descrizione |
|--------|------|------|-------------|
| POST/GET/DELETE | `/mcp` | HMAC | MCP Streamable HTTP (JSON-RPC) |
| GET | `/health` | Nessuna | Health check + stats |
| GET | `/generate-key` | Keycloak | Genera API key HMAC |
| POST | `/revoke-key` | Keycloak | Revoca API key |
| GET | `/list-keys` | Keycloak | Lista token attivi |
| GET | `/revoked-keys` | Keycloak | Lista token revocati |

### 3. `server-api.yml` — Server API (10 endpoint)

| Method | Path | Auth | Descrizione |
|--------|------|------|-------------|
| GET | `/health` | Nessuna | Liveness |
| GET | `/status` | Nessuna | Container status snapshot |
| GET | `/status/stream` | Nessuna | SSE status push (10s) |
| GET | `/containers` | JWT | Lista container Docker |
| GET | `/containers/{id}/logs` | JWT | Log container (query: `lines`) |
| GET | `/stats` | JWT | CPU/RAM/net per container |
| POST | `/containers/{id}/start` | JWT (no readonly) | Start container |
| POST | `/containers/{id}/stop` | JWT (no readonly) | Stop container |
| POST | `/containers/{id}/restart` | JWT (no readonly) | Restart container |
| DELETE | `/containers/{id}` | JWT (no readonly) | Remove container |

Schemas: ContainerStatus, ContainerStats, LogResponse.

### 4. `anki-api.yml` — Anki API (15 endpoint)

| Method | Path | Auth | Descrizione |
|--------|------|------|-------------|
| GET | `/health` | — | Health + collection status |
| GET | `/decks` | JWT | Lista deck con conteggi |
| POST | `/decks` | JWT | Crea deck |
| DELETE | `/decks/{deck_id}` | JWT | Elimina deck |
| GET | `/notes` | JWT | Lista note (query: deck, query, limit) |
| POST | `/notes` | JWT | Crea nota |
| GET | `/notes/{note_id}` | JWT | Dettaglio nota |
| PUT | `/notes/{note_id}` | JWT | Modifica nota |
| DELETE | `/notes/{note_id}` | JWT | Elimina nota |
| POST | `/bulk/notes` | JWT | Bulk create note |
| POST | `/bulk/import` | JWT | Import .apkg (multipart) |
| GET | `/bulk/export` | JWT | Export .apkg (binary) |
| GET | `/review/next` | JWT | Prossima card da ripassare |
| POST | `/review/{card_id}` | JWT | Submit review (rating 1-4) |
| GET | `/review/stats` | JWT | Statistiche review |

Schemas: Deck, Note, ReviewCard, ReviewStats, BulkNotesRequest.

### 5. `kp-manager.yml` — KP Manager (8 endpoint)

| Method | Path | Auth | Descrizione |
|--------|------|------|-------------|
| GET | `/health` | Nessuna | Liveness |
| GET | `/api/entries` | OAuth2 Proxy | Tree struttura gruppi/entry |
| GET | `/api/entries/{path}` | OAuth2 Proxy | Dettaglio entry con password |
| POST | `/api/entries/{path}` | OAuth2 Proxy | Crea entry |
| PUT | `/api/entries/{path}` | OAuth2 Proxy | Modifica entry |
| DELETE | `/api/entries/{path}` | OAuth2 Proxy | Elimina entry |
| POST | `/api/groups/{path}` | OAuth2 Proxy | Crea gruppo |
| POST | `/api/generate` | OAuth2 Proxy | Genera password random |

Schemas: EntryTree, EntryDetail, GenerateRequest.

---

## File da creare/modificare

| File | Azione |
|------|--------|
| `/data/massimiliano/proxy/home/docs/a2a-gateway.yml` | Nuovo |
| `/data/massimiliano/proxy/home/docs/mcp-proxy.yml` | Nuovo |
| `/data/massimiliano/proxy/home/docs/server-api.yml` | Nuovo |
| `/data/massimiliano/proxy/home/docs/anki-api.yml` | Nuovo |
| `/data/massimiliano/proxy/home/docs/kp-manager.yml` | Nuovo |
| `/data/massimiliano/proxy/home/docs/index.html` | Aggiungere 5 entry nell'array `urls` |

**Nessuna modifica nginx** — `/docs/` già serve tutto dalla directory come alias statico.

---

## Registrazione Swagger UI

In `index.html`, aggiungere all'array `urls` (righe 148-153):

```javascript
{ url: './a2a-gateway.yml', name: 'A2A Gateway' },
{ url: './mcp-proxy.yml', name: 'MCP Proxy' },
{ url: './server-api.yml', name: 'Server API' },
{ url: './anki-api.yml', name: 'Anki API' },
{ url: './kp-manager.yml', name: 'KP Manager' }
```

Tech link "A2A Gateway" nella home → cambiare da `/a2a/tasks` a `/docs/?urls.primaryName=A2A+Gateway`.

---

## Verifica

1. `curl https://sol.massimilianopili.com/docs/a2a-gateway.yml` → 200 YAML valido
2. Aprire `/docs/` → dropdown mostra 9 spec (4 esistenti + 5 nuove)
3. Ogni spec renderizzata correttamente con endpoint, schemas, auth
4. Deploy nginx con force-recreate
