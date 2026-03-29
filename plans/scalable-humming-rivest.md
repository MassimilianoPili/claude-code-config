# Piano: Visitor → Read-Only Universale + Chat Abilitata

## Contesto

Il token `visitor` dalla home dashboard oggi porta `readonly` su 3 client Keycloak (go-filemanager, dashboard-chat, server-api) ma la chat è disabilitata e molti servizi OAuth2-proxy (pgAdmin, code-server, Neo4j, ecc.) sono accessibili senza restrizioni. L'obiettivo è rendere il visitor un utente **"tutto in lettura"** con **chat AI abilitata**, bloccando i servizi sensibili/admin.

**Finding chiave**: la chat (`/proxy/ai/claude/`) NON passa per `auth_request /internal/jwt/validate` in nginx — proxy-ai fa auth propria e non controlla readonly. Il blocco chat è **solo frontend** (righe 1160-1172 di index.html).

## Modifiche

### 1. Abilitare chat per visitor — `proxy/home/index.html`

**Righe 1160-1164**: rimuovere `|| readOnly` dai controlli chat (mantenere solo `!loggedIn`):
```js
// PRIMA
document.getElementById('model-select').classList.toggle('hidden', !loggedIn || readOnly);
document.getElementById('btn-new-chat').classList.toggle('hidden', !loggedIn || readOnly);
document.getElementById('history-dropdown').classList.toggle('hidden', !loggedIn || readOnly);
document.getElementById('chat-input').disabled = !loggedIn || readOnly;
document.getElementById('btn-send').disabled = !loggedIn || readOnly;

// DOPO
document.getElementById('model-select').classList.toggle('hidden', !loggedIn);
document.getElementById('btn-new-chat').classList.toggle('hidden', !loggedIn);
document.getElementById('history-dropdown').classList.toggle('hidden', !loggedIn);
document.getElementById('chat-input').disabled = !loggedIn;
document.getElementById('btn-send').disabled = !loggedIn;
```

**Righe 1169-1178**: il blocco `if (readOnly)` non deve più nascondere la chat, solo avvisare che il terminale è disabilitato. Rimuovere il placeholder "Chat non disponibile" e caricare i modelli anche per readonly:
```js
if (readOnly) {
  // Chat abilitata anche per readonly — solo terminal bloccato
  await loadModels();
} else {
  document.getElementById('chat-input').placeholder = 'Type a message...';
  var ph = document.querySelector('.chat-placeholder');
  if (ph) ph.textContent = 'Start a conversation with Claude';
  await loadModels();
}
```

### 2. Blocco pgAdmin per visitor — `proxy/nginx.conf`

**Pattern**: stesso di KP Manager (riga 368-374). Aggiungere `auth_request_set $auth_user` + `if ($auth_user = "visitor")` a:

| Location | Riga | Server block |
|----------|------|-------------|
| `/pgadmin/` | 618 | :8081 (Tailscale) |
| `/pgadmin/` | ~949 | :8888 (Pubblica) — da verificare se esiste |

Aggiungere dopo le righe `auth_request_set` esistenti:
```nginx
auth_request_set $auth_user $upstream_http_x_auth_request_preferred_username;
if ($auth_user = "visitor") {
    return 403;
}
```

### 3. Blocco altri servizi admin per visitor — `proxy/nginx.conf`

Stessa modifica (aggiunta `$auth_user` + blocco 403) su queste location:

| Servizio | Motivo blocco | Tailscale (riga) | Pubblica (riga) |
|----------|--------------|-------------------|-----------------|
| code-server `/ide/` | Terminale completo, accesso filesystem | 423 | 1234 |
| Neo4j Browser `/neo4j/` | Query Cypher read+write | 465 | 1304 |
| Artemis `/mq/` | Console broker, crea/elimina code | 447 | — (non esposto) |
| mongo-express `/mongo/` | CRUD documenti MongoDB | 386 | 1216 |
| libSQL `/libsql/` | Console SQL read+write | 404 | — (non esposto) |
| Portainer `/portainer/` | Gestione container start/stop/delete | 841 | 1155 |

**Servizi che restano accessibili** (read-only per natura o con RBAC nativo):
- Gitea (`/git/`) — RBAC nativo, da marcare visitor come "Restricted" nell'admin UI
- Grafana (`/grafana/`) — OIDC nativo, impostare Viewer role via env
- WikiJS — già pubblico lettura, SAML solo per scrittura
- Knowledge Graph — solo visualizzazione D3.js, nessuna mutazione
- File Manager — già readonly enforcement
- Server API — già readonly enforcement (GET only)
- Preference Sort — jwt-gateway blocca mutazioni

### 4. Gitea: marcare visitor come Restricted (UI operation)

Accedere a Gitea admin → Users → `visitor` → abilitare **"Restricted"**. Limita la visibilità ai soli repo pubblici. Nessuna modifica codice.

### 5. Grafana: Viewer role (opzionale)

In `monitoring/docker-compose.yml`, aggiungere env:
```
GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(resource_access.grafana.roles[*], 'admin') && 'Admin' || 'Viewer'
```
Questo mappa tutti gli utenti non-admin a Viewer. Opzionale perché Grafana di default mostra dashboard in lettura.

### 6. Aggiornamento knowledge graph — `kindle/import_keycloak.py`

Aggiornare la descrizione del client `dashboard-chat` per riflettere che la chat è ora abilitata per visitor. Aggiornare la descrizione dell'utente `visitor` per riflettere il nuovo scope "tutto in lettura".

## File da modificare

1. `/data/massimiliano/proxy/home/index.html` — frontend chat/readonly (Step 1)
2. `/data/massimiliano/proxy/nginx.conf` — blocchi visitor su ~10 location (Steps 2-3)
3. `kindle/import_keycloak.py` — descrizioni aggiornate (Step 6)

## Deploy

```bash
# Dopo steps 1-3: redeploy nginx (include home via bind mount)
cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate

# Dopo step 6: sync knowledge graph
cd /data/massimiliano/kindle && python3 import_keycloak.py --quiet
```

Nessun restart necessario per dashboard-api, proxy-ai, jwt-gateway (nessuna modifica server-side).

## Verifica

1. Login visitor dalla home → chat funzionante, terminale bloccato, notes read-only
2. Navigare a `/pgadmin/`, `/ide/`, `/neo4j/`, `/mq/`, `/mongo/`, `/libsql/`, `/portainer/` → 403
3. Navigare a `/git/`, `/grafana/`, `/rank/`, `/fm/` → accessibili in lettura
4. `/kp/` → 403 (invariato)
5. Verificare che `sol_root` acceda normalmente a tutti i servizi
