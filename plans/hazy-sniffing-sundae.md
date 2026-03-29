# Piano: RBAC Multi-Livello — Unificazione Accesso e Preparazione Multi-Utente

## Contesto

Il visitor access attuale usa **3 meccanismi indipendenti** con criteri diversi:
1. **Codice custom** (Go/Node.js) → controlla `resource_access.{client}.roles` per `readonly`
2. **nginx** → controlla `$auth_user = "visitor"` (hardcoded su identità, non ruolo)
3. **Dashboard UI** → controlla JWT client-side per `resource_access['dashboard-chat'].roles`

L'identità (chi sei) è mescolata con l'autorizzazione (cosa puoi fare). Quando aggiungeremo nuovi utenti con visibilità diversa, dovremmo toccare nginx + codice per ogni utente. Serve convergere su **un'unica fonte di verità: Keycloak Groups + Realm Roles**, con il proxy come enforcement layer principale.

## Livelli di Accesso (4 livelli)

| Livello | Gruppo Keycloak | Ruolo Realm | Descrizione | Esempio utente |
|---------|-----------------|-------------|-------------|----------------|
| **visitor** | `/visitors` | `visitor` | Auto-login pubblico, accesso base, rate-limited | visitor (auto-login dashboard) |
| **readonly** | `/readers` | `readonly` | Autenticato, lettura ampia, no mutazioni | amico/demo, utenti esterni |
| **standard** | `/collaborators` | `standard` | Lettura + scrittura limitata (Gitea push, note, chat) | collaboratori |
| **admin** | `/admins` | `admin` | Accesso completo a tutto | sol_root |

**Onboarding nuovo utente**: metterlo nel gruppo appropriato → eredita il ruolo → tutti i servizi si adattano. Zero modifiche a nginx o codice.

## Architettura: Groups + Realm Roles + Proxy Enforcement

### Perché Groups E Roles (non uno o l'altro)

**Groups** = a chi appartieni (contenitore organizzativo). Servono per:
- Gestire utenti: assegnare/rimuovere da un gruppo è un'operazione singola
- OAuth2 Proxy li legge nativamente (claim `groups` è standard OIDC)
- Gitea li usa per mappare team/permission

**Realm Roles** = cosa puoi fare (permesso). Servono per:
- I servizi controllano i ruoli per decidere accesso (application layer)
- jwt-gateway li estrae e li passa come header a nginx
- Claim `realm_access.roles` è standard Keycloak, sempre nel JWT

**Collegamento**: il gruppo `/readers` ha il ruolo `readonly` associato. Metti l'utente nel gruppo → eredita il ruolo automaticamente.

**Token JWT risultante:**
```json
{
  "groups": ["/readers"],
  "realm_access": {
    "roles": ["readonly", "default-roles-sol"]
  },
  "resource_access": {
    "dashboard-chat": { "roles": ["readonly"] }  // mantenuti per retrocompatibilità
  }
}
```

### Layer di enforcement

```
┌─────────────────────────────────────────────────────────┐
│  1. nginx (proxy layer) — GATEKEEPER UNIVERSALE         │
│     Controlla ruolo via header. Blocca/permette per      │
│     path + livello. Fallback per servizi senza RBAC.     │
├─────────────────────────────────────────────────────────┤
│  2. OAuth2 Proxy: legge `groups` → passa header          │
│     jwt-gateway: legge `realm_access.roles` → header     │
├─────────────────────────────────────────────────────────┤
│  3. Servizio nativo (defense-in-depth)                   │
│     Gitea, Grafana, MinIO hanno RBAC nativo →            │
│     granularità fine dentro il servizio                   │
└─────────────────────────────────────────────────────────┘
```

## Stato Attuale

### 7 punti di controllo ruoli nel codice (tutti `resource_access` only)

| Servizio | File | Controlla |
|----------|------|-----------|
| Dashboard JS | `proxy/home/index.html:1039` | `resource_access['dashboard-chat'].roles` |
| dashboard-api | `dashboard-api/server.js:145` | `resource_access['dashboard-chat'].roles` |
| server-api | `Vari/server-api/main.go:81` | `resource_access['server-api'\|'dashboard-chat'].roles` |
| jwt-gateway | `Vari/jwt-gateway/main.go:49` | `resource_access[*].roles` (any client) |
| go-filemanager | `Vari/go-filemanager/internal/auth/oidc.go` | `resource_access[clientID].roles` |
| knowledge-graph | `knowledge-graph/auth.go:188` | `resource_access[clientID].roles` |
| embedding-viz | `embedding-viz/auth.go:184` | `resource_access[clientID].roles` |

**Nessuno controlla `realm_access.roles`** — tutti vanno aggiornati.

### 12 nginx location hardcoded su `$auth_user = "visitor"`

`:8081` — `/kp/`, `/mongo/`, `/libsql/`, `/pgadmin/`
`:8082` — `/portainer/`
`:8888` — `/kp/`, `/mongo/`, `/portainer/`, `/file/`, `/code/`
`:8090` — `/code/`, `/chat/`

### jwt-gateway: produce `X-Auth-Roles` ma nginx non lo cattura

Header prodotti: `X-Auth-User`, `X-Auth-User-Id`, `X-Auth-Readonly`, `X-Auth-Roles`.
Manca in nginx: `auth_request_set $auth_roles $upstream_http_x_auth_roles;`

### OAuth2 Proxy: non passa ruoli/gruppi

`SET_XAUTHREQUEST: true` → passa username, email.
Serve: `OAUTH2_PROXY_OIDC_GROUPS_CLAIM` per passare il claim `groups`.

### RBAC nativo per servizio

| Servizio | RBAC | Strategia |
|----------|------|-----------|
| **Gitea** | ✅ Completo | Groups Keycloak → Gitea teams. Visitor: read repos |
| **Grafana** | ✅ Completo | Role mapping già attivo. Fallback = Viewer |
| **Knowledge Graph** | D (read-only) | No write endpoints. `Session.ReadOnly` esiste |
| **Embedding Viz** | D (read-only) | Identico a KG |
| **MinIO** | ⚠️ IAM policies | Policy read-only mappabile a claim OIDC |
| **Portainer** | ⚠️ CE limitato | Viewer role manuale. No OIDC in CE |
| **Jenkins, pgAdmin, code-server, KP, mongo-express, libSQL, Artemis** | ❌ | Blocco proxy (admin only) |

## Matrice Accesso Servizio × Ruolo

| Servizio | visitor | readonly | standard | admin |
|----------|---------|----------|----------|-------|
| Dashboard (chat) | ✅ r/o (chat AI, no terminal, no notes write) | ✅ r/o | ✅ Full | ✅ Full |
| File Manager | ✅ r/o (browse, download) | ✅ r/o | ✅ r/w | ✅ Full |
| Server API | ✅ r/o (list, logs, stats) | ✅ r/o | ✅ r/o | ✅ Full |
| Knowledge Graph | ✅ View | ✅ View | ✅ View | ✅ View |
| Embedding Viz | ✅ View | ✅ View | ✅ View | ✅ View |
| **Gitea** | ✅ Read repos | ✅ Read repos | ✅ Read/Write/Push | ✅ Admin |
| Grafana | ❌ | ✅ Viewer | ✅ Editor | ✅ Admin |
| MinIO | ❌ | ✅ r/o buckets | ✅ r/w buckets | ✅ Full |
| Portainer | ❌ | ✅ Viewer (se CE ok) | ❌ | ✅ Full |
| proxy-ai | ❌ | ❌ | ✅ rate-limited | ✅ Full |
| Preference Sort | ❌ | ✅ r/o rankings | ✅ Full | ✅ Full |
| Anki API | ❌ | ✅ r/o decks | ✅ Full | ✅ Full |
| WikiJS | ✅ Public read | ✅ Read | ✅ Read | ✅ r/w (SAML) |
| MkDocs | ✅ View | ✅ View | ✅ View | ✅ View |
| Jenkins, pgAdmin, code-server, KP, mongo-express, libSQL, Artemis | ❌ | ❌ | ❌ | ✅ Full |

## Piano di Implementazione (5 fasi)

### Fase 0: Fondamenta Keycloak

1. Creare 4 **realm roles**: `visitor`, `readonly`, `standard`, `admin`
2. Creare 4 **groups**: `/visitors`, `/readers`, `/collaborators`, `/admins`
3. Associare ruoli ai gruppi: `/visitors` → `visitor`, `/readers` → `readonly`, ecc.
4. Assegnare utenti: `visitor` → `/visitors`, `sol_root` → `/admins`
5. Aggiungere **Group Membership Mapper** (claim `groups`) come "Client Scope" default → vale per tutti i client
6. Verificare token: `realm_access.roles` contiene il ruolo, `groups` contiene il gruppo

### Fase 1: Proxy Layer — nginx come gatekeeper universale

**1a. jwt-gateway** (`Vari/jwt-gateway/main.go`):
- Estendere `isReadOnly()` per controllare anche `realm_access.roles`
- Aggiungere nuovo header `X-Auth-Realm-Role` (singolo valore: visitor/readonly/standard/admin)
- Funzione `getRealmRole(claims)` → estrae il ruolo dal livello più alto in `realm_access.roles`

**1b. OAuth2 Proxy** (`proxy/docker-compose.yml`):
- Aggiungere a entrambe le istanze:
  ```yaml
  OAUTH2_PROXY_OIDC_GROUPS_CLAIM: "groups"
  ```
- OAuth2 Proxy passerà `X-Auth-Request-Groups: /readers` (o il gruppo dell'utente)

**1c. nginx** (`proxy/nginx.conf`):
```nginx
# Catturare ruolo da jwt-gateway
auth_request_set $auth_realm_role $upstream_http_x_auth_realm_role;

# Catturare gruppo da OAuth2 Proxy
auth_request_set $auth_groups $upstream_http_x_auth_request_groups;

# Map unificato: gruppo → livello numerico
map $auth_groups $access_level_oauth2 {
    "~*/admins"        4;
    "~*/collaborators" 3;
    "~*/readers"       2;
    "~*/visitors"      1;
    default            0;
}

# Map: realm role → livello numerico (per JWT routes)
map $auth_realm_role $access_level_jwt {
    "admin"     4;
    "standard"  3;
    "readonly"  2;
    "visitor"   1;
    default     0;
}

# Sostituire TUTTI i 12 blocchi username-based:
# PRIMA:  if ($auth_user = "visitor") { return 403; }
# DOPO:   if ($access_level_oauth2 < 4) { return 403; }  # solo admin
```

### Fase 2: Servizi Codice Custom — dual check

Aggiornare i 7 punti per controllare **sia** `realm_access.roles` **sia** `resource_access` (retrocompatibilità):

**Pattern Go** (jwt-gateway, server-api, go-filemanager, knowledge-graph, embedding-viz):
```go
func getAccessLevel(claims) int {
    // 1. realm_access.roles (fonte primaria)
    if ra, ok := claims["realm_access"]; ok {
        roles := ra["roles"]
        if contains(roles, "admin") { return 4 }
        if contains(roles, "standard") { return 3 }
        if contains(roles, "readonly") || contains(roles, "visitor") { return 2 }
    }
    // 2. resource_access (retrocompatibilità)
    if hasClientRole(claims, "readonly") { return 2 }
    return 3 // default: utente autenticato senza ruolo esplicito = standard
}
```

**Pattern Node.js** (dashboard-api):
```javascript
function getAccessLevel(claims) {
    const realmRoles = claims?.realm_access?.roles || [];
    if (realmRoles.includes('admin')) return 4;
    if (realmRoles.includes('standard')) return 3;
    if (realmRoles.includes('readonly') || realmRoles.includes('visitor')) return 2;
    // fallback client roles
    const clientRoles = claims?.resource_access?.['dashboard-chat']?.roles || [];
    if (clientRoles.includes('readonly')) return 2;
    return 3;
}
```

**Pattern JavaScript** (dashboard frontend):
```javascript
getAccessLevel() {
    const payload = JSON.parse(atob(token.split('.')[1]));
    const realmRoles = payload.realm_access?.roles || [];
    if (realmRoles.includes('admin')) return 4;
    // ... stessa logica
}
```

**File da modificare:**
- `Vari/jwt-gateway/main.go` — `getRealmRole()` + header `X-Auth-Realm-Role`
- `Vari/server-api/main.go:81-105` — `isReadOnly()` → `getAccessLevel()`
- `dashboard-api/server.js:145-148` — idem
- `Vari/go-filemanager/internal/auth/oidc.go` — idem
- `knowledge-graph/auth.go:188-210` — idem (enforcement se servono write in futuro)
- `embedding-viz/auth.go:184-206` — idem
- `proxy/home/index.html:1039-1047` — idem

### Fase 3: Servizi con RBAC Nativo

**3a. Gitea** (visitor + readonly = read repos):
- Creare organizzazione "public" con team "readers" (permission Read)
- Mappare gruppo Keycloak `/readers` + `/visitors` → Gitea team "readers" via claim `groups`
- Sbloccare visitor su Gitea nel proxy (rimuovere blocco nginx)

**3b. Grafana** (readonly = Viewer):
- Aggiungere ruoli Keycloak: `grafana_viewer`, `grafana_editor`
- Assegnare `grafana_viewer` ai gruppi `/readers`
- Il mapping `GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH` già funziona

**3c. MinIO** (readonly = read-only buckets):
- Creare IAM policy `readonlyBuckets`
- `MINIO_IDENTITY_OPENID_CLAIM_NAME` → mappare claim a policy

**3d. Portainer** (readonly = Viewer):
- Creare utente Portainer con team "Viewers" (manuale o via API)

### Fase 4: Rate Limiting per Ruolo

```nginx
map $auth_realm_role $ai_rate_limit_key {
    "admin"     "";                        # no limit
    "standard"  "standard:$auth_user";     # 10r/s
    "readonly"  "";                        # bloccato (non arriva qui)
    "visitor"   "";                        # bloccato (non arriva qui)
    default     "blocked";
}
```

### Fase 5: Dashboard Multi-Utente

- Visitor auto-login: invariato (Direct Access Grant)
- `isReadOnly()` → `getAccessLevel()` nel frontend
- UI mostra/nasconde sezioni basate su livello (non solo "readonly" boolean)

## Stato Implementazione

| Fase | Stato | Note |
|------|-------|------|
| 0 | DONE | 4 realm roles, 4 groups, mappings, utenti assegnati |
| 1a | DONE | jwt-gateway: X-Auth-Realm-Role header |
| 1b | DONE | OAuth2 Proxy: OIDC_GROUPS_CLAIM groups |
| 1c | DONE | nginx: map non_admin_block, 14 blocchi migrati |
| 2 | DONE | 7 checkpoint codice: dual-check realm_access + resource_access |
| 3a | DONE | Grafana: JMESPath con realm roles (realm_access.roles prioritario) |
| 3b | DONE | Gitea: REQUIRE_SIGNIN_VIEW=false (repo pubblici leggibili) |
| 3c | DONE | MinIO: OIDC client+mapper+4 IAM policies (admin/standard/readonly/visitor) |
| 3d | SKIP | Portainer: admin-only, nessun cambio |
| 4 | DONE | Rate limiting proxy-AI: 2 zone (std 5r/s, vis 1r/s), 26 location + JWT auth_request |
| 5 | DONE | Dashboard UI: getAccessLevel() 4 livelli, terminal/notes/tokens/metrics per-level |

---

## Fase 3: Servizi con RBAC Nativo

### 3a. Grafana - JMESPath con realm roles (quick win)

Stato: OIDC funzionante, JMESPath usa solo client roles. Visitor gia Viewer.

Modifica: estendere JMESPath per realm_access.roles come fonte primaria.

File: `monitoring/docker-compose.yml` - linea 53

```yaml
# PRIMA:
GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH: "contains(roles[*], 'grafana_admin') && 'Admin' || contains(roles[*], 'grafana_editor') && 'Editor' || 'Viewer'"

# DOPO:
GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH: "contains(realm_access.roles, 'admin') && 'Admin' || contains(realm_access.roles, 'standard') && 'Editor' || contains(roles[*], 'grafana_admin') && 'Admin' || contains(roles[*], 'grafana_editor') && 'Editor' || 'Viewer'"
```

Prerequisito: verificare che realm_access sia nel userinfo endpoint (default Keycloak).

Deploy: `cd monitoring && docker compose up -d grafana --force-recreate`

Verifica: sol_root -> Admin, visitor -> Viewer, futuro /collaborators -> Editor.

### 3b. Gitea - Accesso pubblico lettura (quick win)

Modifica: una riga. Repo pubblici leggibili senza login, privati protetti.

File: `gitea/docker-compose.yml` - linea 19

```yaml
# PRIMA: GITEA__service__REQUIRE_SIGNIN_VIEW=true
# DOPO:  GITEA__service__REQUIRE_SIGNIN_VIEW=false
```

Post-deploy: audit repo visibility (nessun repo sensibile deve essere Public).

Deploy: `cd gitea && docker compose up -d gitea --force-recreate`

### 3c. MinIO - Completare OIDC + policy mapping (media complessita)

Step 1: ottenere client secret reale dal client `minio` in Keycloak, aggiornare `minio/.env`

Step 2: aggiungere in `minio/docker-compose.yml`:
```yaml
MINIO_IDENTITY_OPENID_CLAIM_NAME_PRIMARY_IAM: "minio_policy"
```
Creare in Keycloak un mapper "User Realm Role" sul client minio (claim: minio_policy, add to ID+access+userinfo).

Step 3: creare MinIO policies via mc admin policy:
- admin -> consoleAdmin
- standard -> readwrite
- readonly -> list + get objects
- visitor -> list + get su bucket pubblici

Step 4 (opzionale): aggiungere non_admin_block alla location /minio/ nel server :8888.

Files: `minio/.env`, `minio/docker-compose.yml`, `proxy/nginx.conf` (server :8888 /minio/)

### 3d. Portainer - Nessun cambio

Gia admin-only via non_admin_block. Mantenere.

---

## Fase 4: Rate Limiting Proxy-AI per Ruolo

Contesto: le location proxy-AI non hanno auth_request nginx ne rate limiting. Auth gestita dal Go service proxy-ai internamente. Per differenziare il rate limit serve auth_realm_role, che richiede auth_request.

Step 1 - Maps e zone in `proxy/nginx.conf` dopo linea 68:

```nginx
# Rate limiting proxy-AI: standard users (5r/s per utente)
map $auth_realm_role $ai_std_key {
    "standard"  $auth_user;
    default     "";
}
limit_req_zone $ai_std_key zone=ai_std_limit:10m rate=5r/s;

# Rate limiting proxy-AI: visitor/readonly (1r/s per utente)
map $auth_realm_role $ai_vis_key {
    "visitor"   $auth_user;
    "readonly"  $auth_user;
    default     "";
}
limit_req_zone $ai_vis_key zone=ai_vis_limit:10m rate=1r/s;
```

Admin -> entrambe chiavi vuote -> nessun limite. Standard -> 5r/s. Visitor/readonly -> 1r/s.

Step 2 - Aggiungere auth_request + rate limit a ~14 location blocks proxy-AI (7 Tailscale + 7 pubblico):

```nginx
auth_request /internal/jwt/validate;
auth_request_set $auth_user $upstream_http_x_auth_user;
auth_request_set $auth_realm_role $upstream_http_x_auth_realm_role;
limit_req zone=ai_std_limit burst=10 nodelay;
limit_req zone=ai_vis_limit burst=2 nodelay;
```

Nota: proxy-ai Go continua a validare JWT internamente (defense-in-depth).

Files: `proxy/nginx.conf` - maps + ~14 location blocks

Deploy: `cd proxy && docker compose up -d nginx --force-recreate`

---

## Fase 5: Dashboard UI Multi-Livello

Matrice accesso UI:

| Feature | visitor(1) | readonly(2) | standard(3) | admin(4) |
|---------|:---:|:---:|:---:|:---:|
| Chat AI | Y | Y | Y | Y |
| History/New chat | Y | Y | Y | Y |
| Model select | N | N | Y | Y |
| Terminal | N | N | Y | Y |
| Notes read | Y | Y | Y | Y |
| Notes write | N | N | Y | Y |
| MCP Tokens | N | N | N | Y |
| Metrics strip | N | N | N | Y |

Step 1: aggiungere getRealmRole() e getAccessLevel() all'oggetto auth (~linea 1115)

Step 2: aggiornare updateUI() con access level (~linea 1326):
- level>=3 -> model select, terminal, notes write
- level>=4 -> MCP tokens, metrics strip
- mostrare ruolo nel user info

Step 3: terminal init (~linea 1803): bloccare se level<3 con messaggio ruolo

Step 4: notes (~linea 1917): readOnly se level<3

Step 5: early sync check (~linea 808): allineare con stessa logica

Files: `proxy/home/index.html` - linee 808-825, 1102-1120, 1326-1360, 1803, 1917, 1945

Deploy: file bind-mounted -> hard-refresh browser

---

## Ordine di Esecuzione

3a (Grafana) -> 3b (Gitea) -> 5 (Dashboard UI) -> 3c (MinIO) -> 4 (Rate limiting)

Rationale: 3a e 3b sono quick wins. Fase 5 e UI-only. 3c richiede Keycloak config. Fase 4 e la piu impattante su nginx.

## Rischi e Mitigazioni

| Rischio | Mitigazione |
|---------|-------------|
| realm_access non in Grafana userinfo | Default Keycloak; verificare con token introspection |
| Gitea repo sensibili con REQUIRE_SIGNIN_VIEW=false | Audit repo visibility prima del deploy |
| MinIO policies con realm roles multipli | MinIO fa union -> ruolo piu alto vince (OK) |
| Rate limiting proxy-AI rompe dashboard chat | Dashboard manda ~1 req/messaggio, sotto 1r/s |
| Double JWT validation su proxy-AI | Overhead trascurabile, defense-in-depth |

## Verifica End-to-End

1. Token: curl keycloak/token -> realm_access + groups presenti
2. Grafana: sol_root Admin, visitor Viewer, /collaborators Editor
3. Gitea: repo pubblici visibili senza login, privati richiedono auth
4. MinIO: OIDC login funziona, policy applicate
5. Rate limiting: admin no limit, standard 5r/s, visitor 1r/s
6. Dashboard: 4 livelli UI (admin/standard/readonly/visitor)
7. Test onboarding: creare test-reader in /readers -> tutto funziona senza toccare nginx/codice
8. Regressione: visitor dashboard auto-login invariato
