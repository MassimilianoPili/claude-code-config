# Piano: Creare PIANO_MCP_REMOTO.md in /progetti_futuri/

## Contesto

Il server MCP (`simoge-mcp`, ~234 tool) gira su Docker porta `127.0.0.1:8099`, accessibile solo localmente. L'obiettivo e' pianificare come permettere a istanze Claude Code su macchine esterne (via Tailscale) di connettersi al MCP in sicurezza, usando un client Keycloak dedicato con Client Credentials grant.

L'infrastruttura auth esiste gia': Keycloak + jwt-gateway + nginx `auth_request`. Serve solo collegarli per il caso MCP.

## Deliverable

Creare `/data/massimiliano/progetti_futuri/PIANO_MCP_REMOTO.md` seguendo il formato degli altri piani (obiettivo, prerequisiti, architettura, step implementativi, verifica). Aggiungere la riga corrispondente in `INDICE.md`.

## Approccio tecnico: Porta dedicata nginx :8095 + JWT auth

**Perche' porta dedicata e non subpath `/mcp/`**: Il protocollo MCP SSE restituisce `/message?sessionId=xxx` come endpoint nel SSE stream. Se usassimo `/mcp/sse`, il client farebbe POST a `/message` (senza prefisso `/mcp/`), causando un mismatch. Una porta dedicata evita il problema.

**Flusso**:
```
Macchina esterna (Tailscale)
  → GET http://100.86.46.84:8095/sse  [Authorization: Bearer <JWT>]
  → nginx :8095 → auth_request → jwt-gateway:8094/validate
  → proxy_pass → simoge-mcp:8099/sse
  → SSE stream + POST /message (stesso flusso auth)
```

**Accesso locale invariato**: Claude Code su SOL continua a usare `localhost:8099/sse` direttamente, senza auth.

## Step 1 — Creare client Keycloak `mcp-client`

In Keycloak Admin (`http://100.86.46.84:8443`), realm `sol`:

- **Client ID**: `mcp-client`
- **Client authentication**: ON (confidential)
- **Authentication flow**: solo "Service accounts roles" (Client Credentials)
- **Access Token Lifespan**: 30 minuti (override del default realm)
  - Motivo: le sessioni MCP sono lunghe, e Claude Code non fa auto-refresh del token
  - nginx valida solo al momento della connessione SSE; il POST `/message` richiede token valido ad ogni chiamata
- **NON assegnare** ruolo `readonly` (accesso pieno ai tool MCP)
- Copiare il **Client Secret** generato

## Step 2 — Aggiungere rate limit zone in nginx.conf

File: `/data/massimiliano/proxy/nginx.conf`

Nel blocco `http {}` (vicino alle altre `limit_req_zone`), aggiungere:

```nginx
limit_req_zone $binary_remote_addr zone=mcp_limit:10m rate=30r/s;
```

30 req/s perche' le burst di tool call MCP generano molti POST `/message` in rapida successione.

## Step 3 — Aggiungere server block :8095 in nginx.conf

Dopo l'ultimo server block esistente, aggiungere:

```nginx
# :8095 — MCP SSE Server (JWT auth, Tailscale only)
server {
    listen 8095;

    limit_req zone=mcp_limit burst=50 nodelay;

    # JWT validation (subrequest interna)
    location = /internal/jwt/validate {
        internal;
        set $jwt_gw_mcp http://jwt-gateway:8094;
        proxy_pass $jwt_gw_mcp/validate;
        proxy_pass_request_body off;
        proxy_set_header Content-Length "";
        proxy_set_header X-Original-URI $request_uri;
        proxy_set_header X-Original-Method $request_method;
        proxy_set_header Authorization $http_authorization;
    }

    # SSE endpoint (GET /sse — stream long-lived)
    location = /sse {
        auth_request /internal/jwt/validate;
        auth_request_set $auth_user $upstream_http_x_auth_user;

        set $mcp http://simoge-mcp:8099;
        proxy_pass $mcp/sse;

        proxy_http_version 1.1;
        proxy_set_header Connection '';
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        chunked_transfer_encoding on;

        proxy_set_header Host $host;
        proxy_set_header X-Auth-User $auth_user;
    }

    # Message endpoint (POST /message?sessionId=xxx — JSON-RPC)
    location = /message {
        auth_request /internal/jwt/validate;
        auth_request_set $auth_user $upstream_http_x_auth_user;

        set $mcp http://simoge-mcp:8099;
        proxy_pass $mcp/message$is_args$args;

        proxy_set_header Host $host;
        proxy_set_header X-Auth-User $auth_user;
        proxy_set_header Content-Type $http_content_type;
        client_max_body_size 10m;
    }

    # Health (no auth)
    location = /health {
        set $mcp http://simoge-mcp:8099;
        proxy_pass $mcp/health;
    }

    location / {
        return 404;
    }
}
```

Note SSE critiche:
- `proxy_buffering off` + `proxy_cache off`: nginx non deve bufferizzare gli eventi SSE
- `proxy_read_timeout 3600s`: connessioni SSE durano ore; 1h = riconnessione periodica
- `Connection ''`: previene che nginx chiuda la connessione
- `proxy_http_version 1.1`: richiesto per SSE/chunked transfer
- Lazy DNS (`set $mcp`): se simoge-mcp e' spento, 502 solo su questa porta senza impattare altri servizi

## Step 4 — Esporre porta 8095 nel docker-compose

File: `/data/massimiliano/proxy/docker-compose.yml`

Aggiungere alla sezione `ports` di nginx:

```yaml
- "8095:8095"    # MCP SSE (JWT auth)
```

## Step 5 — Redeploy nginx

```bash
cd /data/massimiliano/proxy
docker compose up -d nginx --force-recreate
```

## Step 6 — Test

```bash
# 1. Ottenere token (via Keycloak diretto)
TOKEN=$(curl -s -X POST http://keycloak:8080/auth/realms/sol/protocol/openid-connect/token \
  -d "grant_type=client_credentials" \
  -d "client_id=mcp-client" \
  -d "client_secret=<SECRET>" | jq -r .access_token)

# 2. Oppure via jwt-gateway /exchange
TOKEN=$(curl -s -X POST http://100.86.46.84/auth/exchange \
  -d "client_id=mcp-client" \
  -d "client_secret=<SECRET>" | jq -r .access_token)

# 3. Test SSE con token (deve ricevere event stream)
curl -N -H "Authorization: Bearer $TOKEN" http://100.86.46.84:8095/sse

# 4. Test senza token (deve dare 401)
curl -v http://100.86.46.84:8095/sse

# 5. Test health (no auth)
curl http://100.86.46.84:8095/health
```

## Step 7 — Configurare Claude Code sulla macchina esterna

Nel `~/.claude.json` della macchina esterna:

```json
{
  "mcpServers": {
    "simoge-mcp": {
      "type": "sse",
      "url": "http://100.86.46.84:8095/sse",
      "headers": {
        "Authorization": "Bearer <JWT_TOKEN>"
      },
      "timeout": 300
    }
  }
}
```

### Script helper per refresh token

```bash
#!/bin/bash
# mcp-token.sh — ottiene JWT fresh e aggiorna .claude.json
TOKEN=$(curl -s -X POST http://100.86.46.84:8095/health > /dev/null && \
  curl -s -X POST http://100.86.46.84/auth/exchange \
    -d "client_id=mcp-client" \
    -d "client_secret=$MCP_CLIENT_SECRET" | jq -r .access_token)

jq --arg token "$TOKEN" \
  '.mcpServers["simoge-mcp"].headers.Authorization = "Bearer " + $token' \
  ~/.claude.json > /tmp/claude.json.tmp && mv /tmp/claude.json.tmp ~/.claude.json

echo "Token refreshed (valido 30 min)"
```

Da eseguire prima di avviare Claude Code, o quando si riceve 401.

## File da creare/modificare

| File | Azione |
|------|--------|
| `/data/massimiliano/progetti_futuri/PIANO_MCP_REMOTO.md` | **Creare** — piano completo con tutto il contenuto tecnico sopra |
| `/data/massimiliano/progetti_futuri/INDICE.md` | **Aggiornare** — aggiungere riga #26 nella tabella |

Categoria: **Infra / Docker**. Effort stimato: **~3h**. Costo: Gratis. ROI: 4. Impatto: Alto — abilita multi-device Claude Code, riusa infra auth esistente.

## Contenuto del PIANO

Il file `PIANO_MCP_REMOTO.md` conterra' tutto il dettaglio tecnico di questo plan file:
- Obiettivo, prerequisiti (Keycloak client, nginx, jwt-gateway gia' operativi)
- Architettura (porta :8095, auth_request, SSE proxy settings)
- 7 step implementativi (Keycloak client → rate limit → server block → porta docker-compose → deploy → test → config esterna)
- Script helper `mcp-token.sh` per refresh token
- Fase 2 opzionale (Cloudflare pubblico)
- Verifica end-to-end
