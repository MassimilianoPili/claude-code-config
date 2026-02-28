---
name: keycloak-oidc
description: Keycloak OIDC identity provider patterns for SSO, realm configuration, client setup, role mapping, backchannel authentication, and integration with OAuth2 Proxy, Go OIDC, and JavaScript PKCE flows in self-hosted infrastructure.
allowed-tools: Read, Write, Bash, Edit
category: infrastructure
tags: [keycloak, oidc, sso, oauth2, authentication, jwt]
version: 1.0.0
---

# Keycloak OIDC Identity Provider — Server SOL

## Overview

Keycloak is the central Identity Provider for ~20 services on the SOL server. All authentication
flows (browser login, API access, visitor read-only mode) go through a single Keycloak instance
running in the `sol` realm.

**Key characteristics:**
- **Realm**: `sol`
- **Mode**: `start-dev` (development — no TLS certificates required, HTTP only)
- **Database**: PostgreSQL 16 (shared instance, database `keycloak`)
- **Network**: Docker `shared` network, container name `keycloak`
- **External URL**: `https://sol.massimilianopili.com/auth`
- **Internal URL**: `http://keycloak:8080/auth`

Three integration patterns are used across all services:

| Pattern | Technique | Services |
|---------|-----------|----------|
| **OIDC Native** | App handles OIDC directly | Gitea, File Manager |
| **OAuth2 Proxy** | Reverse proxy with auth_request | pgAdmin, Portainer, mongo-express, libSQL, code-server, Artemis |
| **JWT Bearer** | API validates JWT signature | Claude Proxy, Server API, Dashboard API |

## When to Use

- Configuring a new OIDC client or adding redirect URIs
- Debugging SSO login failures, redirect loops, or token/issuer mismatches
- Setting up role-based access control (read-only visitor, admin promotion)
- Understanding the dual-URL pattern (internal Docker vs external public)
- Integrating OAuth2 Proxy with Keycloak for new services

## Docker Compose Configuration

File: `/data/massimiliano/keycloak/docker-compose.yml`

```yaml
services:
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: keycloak
    command: start-dev
    restart: unless-stopped
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: ${KC_DB_PASSWORD}
      KC_BOOTSTRAP_ADMIN_USERNAME: ${KC_BOOTSTRAP_ADMIN_USERNAME}
      KC_BOOTSTRAP_ADMIN_PASSWORD: ${KC_BOOTSTRAP_ADMIN_PASSWORD}
      KC_PROXY_HEADERS: xforwarded
      KC_HTTP_ENABLED: "true"
      KC_HOSTNAME: https://sol.massimilianopili.com/auth
      KC_HTTP_RELATIVE_PATH: /auth
      KC_HOSTNAME_BACKCHANNEL_DYNAMIC: "true"
    networks:
      - shared

networks:
  shared:
    external: true
```

### Key Environment Variables Explained

- **`KC_HOSTNAME`**: Full external URL with `/auth` path -- used for all browser redirects and discovery
- **`KC_HTTP_RELATIVE_PATH: /auth`**: Must match the path in `KC_HOSTNAME`. Endpoints become `/auth/realms/sol/...`
- **`KC_HOSTNAME_BACKCHANNEL_DYNAMIC: "true"`**: Backchannel uses request host header (`keycloak:8080`), keeping token exchange on Docker network
- **`KC_PROXY_HEADERS: xforwarded`**: Trusts `X-Forwarded-*` headers from nginx
- **`start-dev`**: Dev mode, no TLS needed (terminates at Cloudflare/nginx)

## Realm: sol

### OIDC Discovery Endpoints

The same realm is accessible via three different URLs depending on the caller:

| Caller | Discovery URL |
|--------|---------------|
| Browser (public) | `https://sol.massimilianopili.com/auth/realms/sol/.well-known/openid-configuration` |
| Docker container (backchannel) | `http://keycloak:8080/auth/realms/sol/.well-known/openid-configuration` |
| Host localhost (via nginx) | `http://127.0.0.1/auth/realms/sol/.well-known/openid-configuration` |

The dual-URL pattern is critical: browsers use the external URL for redirects, but server-to-server
token exchange and JWKS fetching use the internal Docker URL.

### Principal User and JWKS

- **User**: `sol_root` (email verified: Off, OAuth2 Proxy uses `INSECURE_OIDC_ALLOW_UNVERIFIED_EMAIL=true`)
- **JWKS**: Same three URL patterns as discovery, path: `.../protocol/openid-connect/certs`

## OIDC Clients

### Client: `gitea` (OIDC Native)

- **Auth flow**: Authorization Code
- **Discovery URL** (configured in Gitea): `http://keycloak:8080/auth/realms/sol/.well-known/openid-configuration`
- **Redirect URIs**: `http://100.86.46.84/*`, `https://sol.massimilianopili.com/git/*`
- **Web Origins**: `http://100.86.46.84`, `https://sol.massimilianopili.com`
- **Group claim**: `groups` (from dedicated scope with Group Membership mapper)
- **Admin mapping**: group `/gitea_admin` in token claim `groups` -> Gitea `is_admin=true`
- **Auto-registration**: enabled (`ALLOW_ONLY_EXTERNAL_REGISTRATION=true`)

**IMPORTANT**: The `/` prefix on `/gitea_admin` comes from Keycloak Group Membership mapper --
it adds the group path prefix automatically. In Gitea auth source config, `AdminGroup` must be
set to `/gitea_admin` (with the slash).

### Client: `go-filemanager` (OIDC Native)

- **Auth flow**: Authorization Code
- **Client role**: `readonly` (used for visitor access control)
- **Role location in token**: `resource_access.go-filemanager.roles` array
- **No custom mapper needed**: The `resource_access` claim is included by Keycloak's built-in
  "client roles" protocol mapper.

### Client: `oauth2-proxy` (OAuth2 Proxy -- 2 instances)

- **Auth flow**: Authorization Code + PKCE (S256)
- **Redirect URIs**:
  - `http://100.86.46.84:8081/oauth2/callback` (Tailscale instance -- pgAdmin)
  - `http://100.86.46.84:8082/oauth2/callback` (Tailscale instance -- Portainer)
  - `https://sol.massimilianopili.com/oauth2/callback` (public instance)
- **Protects**: pgAdmin, Portainer, mongo-express, libSQL console, code-server, Artemis console

Two OAuth2 Proxy instances share the same Keycloak client but differ in cookie/redirect config:

| Instance | Port | Cookie | Domain |
|----------|------|--------|--------|
| Tailscale | 4180 | HTTP, not secure | `100.86.46.84` |
| Public | 4181 | HTTPS, secure | `.massimilianopili.com` |

Both instances use:
- `INSECURE_OIDC_ALLOW_UNVERIFIED_EMAIL=true`
- `INSECURE_OIDC_SKIP_ISSUER_VERIFICATION=true`
- `CODE_CHALLENGE_METHOD=S256`

### Client: `dashboard-chat` (PKCE + JWT Bearer)

- **Auth flow**: Authorization Code + PKCE (browser-side), JWT Bearer (API validation)
- **Client role**: `readonly` (for visitor access control)
- **Role location in token**: `resource_access.dashboard-chat.roles` array
- **Used by**: Dashboard (chat, terminal, notes), Claude Proxy API, Server API, Dashboard API

## Integration Pattern 1: Go OIDC (go-oidc + oauth2)

File: `/data/massimiliano/Vari/go-filemanager/internal/auth/oidc.go` -- handles the dual-URL
problem (internal for discovery/token, external for browser redirects):

```go
// Dual-URL: internal for discovery/token, external for browser redirects
issuerURL := cfg.KeycloakInternalURL + "/realms/" + cfg.KeycloakRealm

// InsecureIssuerURLContext: the discovery URL (internal) differs from the
// token issuer (external). Token signature verification still applies --
// only the issuer URL string check is skipped.
ctx := oidc.InsecureIssuerURLContext(context.Background(), issuerURL)
provider, err := oidc.NewProvider(ctx, issuerURL)

// External auth URL for browser redirects
externalAuthURL := cfg.KeycloakExternalURL + "/realms/" + cfg.KeycloakRealm +
    "/protocol/openid-connect/auth"

oauth2Config := &oauth2.Config{
    ClientID:     cfg.KeycloakClientID,
    ClientSecret: cfg.KeycloakClientSecret,
    RedirectURL:  cfg.BaseURL + "/auth/callback",
    Scopes:       []string{oidc.ScopeOpenID, "profile", "email"},
    Endpoint: oauth2.Endpoint{
        AuthURL:  externalAuthURL,              // browser goes here
        TokenURL: provider.Endpoint().TokenURL, // server-to-server (internal)
    },
}

// Verifier: SkipIssuerCheck because token issuer (external) differs from
// the discovery URL (internal)
verifier := provider.Verifier(&oidc.Config{
    ClientID:        cfg.KeycloakClientID,
    SkipIssuerCheck: true,
})
```

### Reading resource_access for read-only mode

```go
var claims struct {
    ResourceAccess map[string]struct {
        Roles []string `json:"roles"`
    } `json:"resource_access"`
}
idToken.Claims(&claims)

if client, ok := claims.ResourceAccess[clientID]; ok {
    for _, role := range client.Roles {
        if role == "readonly" {
            isReadOnly = true
        }
    }
}
```

### Visitor login_hint support

```go
opts := []oauth2.AuthCodeOption{oidc.Nonce(nonce)}
if hint := r.URL.Query().Get("login_hint"); hint != "" {
    opts = append(opts, oauth2.SetAuthURLParam("login_hint", hint))
    opts = append(opts, oauth2.SetAuthURLParam("prompt", "login"))
}
url := h.oauth2Config.AuthCodeURL(state, opts...)
```

The `prompt=login` parameter forces Keycloak to show the login page even if the user has an
active session. Combined with `login_hint=visitor`, it pre-fills the username field.

## Integration Pattern 2: Node.js JWT Verification (jose)

File: `/data/massimiliano/dashboard-api/server.js` -- API-only JWT Bearer validation:

```javascript
const { createRemoteJWKSet, jwtVerify } = require('jose');

const JWKS_URL = 'http://127.0.0.1/auth/realms/sol/protocol/openid-connect/certs';
const JWKS = createRemoteJWKSet(new URL(JWKS_URL), {
    cooldownDuration: 300000, // cache JWKS for 5 minutes
});

async function verifyToken(token) {
    const { payload } = await jwtVerify(token, JWKS, {
        issuer: [
            'http://127.0.0.1/auth/realms/sol',
            'http://keycloak:8080/auth/realms/sol',
            'https://sol.massimilianopili.com/auth/realms/sol',
        ],
    });
    return payload;
}

// Read-only check via resource_access
function isReadOnly(claims) {
    const roles = claims?.resource_access?.['dashboard-chat']?.roles;
    return Array.isArray(roles) && roles.includes('readonly');
}
```

**Multiple issuers**: The token's `iss` claim varies depending on how the user logged in
(Tailscale via localhost nginx, Docker internal, or public domain). All three must be accepted.

## Integration Pattern 3: Go JWT Verification (golang-jwt + keyfunc)

File: `/data/massimiliano/Vari/server-api/main.go`

```go
import (
    "github.com/MicahParks/keyfunc/v3"
    "github.com/golang-jwt/jwt/v5"
)

// JWKS auto-refresh (background goroutine fetches keys periodically)
jwksURL := "http://keycloak:8080/auth/realms/sol/protocol/openid-connect/certs"
k, _ := keyfunc.NewDefaultCtx(ctx, []string{jwksURL})

// Parse, validate signature + expiration
token, err := jwt.Parse(tokenStr, k.Keyfunc, jwt.WithExpirationRequired())
claims := token.Claims.(jwt.MapClaims)

// Read-only: checks resource_access for multiple client IDs
func isReadOnly(claims jwt.MapClaims) bool {
    ra, _ := claims["resource_access"].(map[string]interface{})
    for _, clientID := range []string{"dashboard-chat", "server-api"} {
        if client, ok := ra[clientID].(map[string]interface{}); ok {
            if roles, ok := client["roles"].([]interface{}); ok {
                for _, r := range roles {
                    if r == "readonly" { return true }
                }
            }
        }
    }
    return false
}
```

## Integration Pattern 4: JavaScript PKCE (Browser)

File: `/data/massimiliano/proxy/home/index.html`

The dashboard uses a pure JavaScript PKCE flow (no backend, no client secret):

```javascript
// 1. Generate PKCE code verifier + challenge
const codeVerifier = randomString(64);  // crypto.getRandomValues
const codeChallenge = base64URLEncode(await sha256(codeVerifier));

// 2. Build authorization URL
const authURL = `${issuer}/protocol/openid-connect/auth?` +
    `client_id=dashboard-chat&response_type=code&` +
    `redirect_uri=${encodeURIComponent(redirectURI)}&scope=openid profile email&` +
    `code_challenge=${codeChallenge}&code_challenge_method=S256&` +
    `state=${state}&nonce=${nonce}`;

// Visitor mode: force login page with pre-filled username
if (mode === 'visitor') authURL += `&login_hint=visitor&prompt=login`;

sessionStorage.setItem('pkce_code_verifier', codeVerifier);
window.location.href = authURL;

// 3. After redirect — exchange code for tokens (public client, no secret)
const tokenResponse = await fetch(`${issuer}/protocol/openid-connect/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
        grant_type: 'authorization_code', client_id: 'dashboard-chat',
        code: authCode, redirect_uri: redirectURI,
        code_verifier: sessionStorage.getItem('pkce_code_verifier'),
    }),
});
```

## Visitor (Read-Only) Access Pattern

Three-level strategy for enforcing read-only access:

| Level | Technique | Services |
|-------|-----------|----------|
| **1. Custom code** | Check `resource_access.{client}.roles` in JWT | File Manager, Dashboard API, Server API |
| **2. Native RBAC** | Configure roles in the application | Gitea (collaborator Read), Portainer (Viewer) |
| **3. Nginx block** | `if ($auth_user = "visitor") { return 403; }` | KP Manager |

### Keycloak Setup for Visitor

1. **Clients** -> `go-filemanager` -> **Roles** -> Create role `readonly`
2. **Clients** -> `dashboard-chat` -> **Roles** -> Create role `readonly`
3. **Users** -> Create user `visitor` (or select existing)
4. **Users** -> `visitor` -> **Role mapping** -> Assign `readonly` on both clients
5. The `resource_access` claim is included by default (Keycloak built-in "client roles" mapper)
   -- no additional mapper configuration needed.

### Token Structure (resource_access)

```json
{
  "resource_access": {
    "go-filemanager": {
      "roles": ["readonly"]
    },
    "dashboard-chat": {
      "roles": ["readonly"]
    }
  }
}
```

## Nginx Proxy Configuration for Keycloak

File: `/data/massimiliano/proxy/nginx.conf`

Keycloak block on port 8443 (Tailscale) uses `$http_host` (not `$host`) to preserve the port,
includes `X-Forwarded-Host`/`X-Forwarded-Port`, and large proxy buffers (128k/256k) for
Keycloak's large token headers.

**Critical**: NO `proxy_redirect` in Keycloak blocks. With `KC_HOSTNAME`, Keycloak generates
correct redirects. A `proxy_redirect` rewrites ALL Location headers including OAuth2 callbacks
to other services, breaking SSO flows.

### OAuth2 Proxy auth_request pattern

```nginx
location /pgadmin/ {
    auth_request /oauth2/auth;
    error_page 401 =302 /oauth2/start?rd=$request_uri;
    auth_request_set $auth_user $upstream_http_x_auth_request_preferred_username;
    set $pgadmin_upstream http://pgadmin:5050;
    proxy_pass $pgadmin_upstream;
}

location /oauth2/ {
    set $oauth2_upstream http://oauth2-proxy:4180;
    proxy_pass $oauth2_upstream;
}
```

## Admin Operations

### Access admin console

- **Tailscale**: `http://100.86.46.84:8443/auth/admin/master/console/`
- **Public**: `https://sol.massimilianopili.com/auth/admin/master/console/`

### Add redirect URI via DB (emergency, when UI is not accessible)

```bash
docker exec postgres psql -U keycloak -d keycloak -c "
INSERT INTO redirect_uris (client_id, value)
SELECT c.id, 'https://new-domain.com/callback'
FROM client c
WHERE c.client_id = 'oauth2-proxy'
  AND c.realm_id = (SELECT id FROM realm WHERE name = 'sol');"
docker restart keycloak
```

### Evaluate tokens (debugging)

Keycloak Admin -> Clients -> {client} -> Client scopes -> Evaluate -> select user -> Generated ID token

### Restart after changes

```bash
cd /data/massimiliano/keycloak && docker compose up -d --force-recreate
cd /data/massimiliano/proxy && docker compose up -d --force-recreate oauth2-proxy oauth2-proxy-public
```

## Best Practices

1. **`KC_HOSTNAME_BACKCHANNEL_DYNAMIC: "true"`** -- keeps server-to-server traffic on Docker network
2. **`SkipIssuerCheck`** / `INSECURE_OIDC_SKIP_ISSUER_VERIFICATION` -- when discovery URL differs from token issuer (signature verification still applies)
3. **Accept multiple issuers** in JWT verification (localhost, Docker, public) -- `iss` depends on login path
4. **Use `resource_access`** (built-in mapper) instead of custom mappers for client roles
5. **`prompt=login` + `login_hint`** -- forces re-authentication for visitor mode
6. **Never use `proxy_redirect`** in nginx Keycloak blocks -- breaks OAuth2 callbacks
7. **Restart OAuth2 Proxy** after Keycloak config changes (they cache OIDC discovery)
8. **Large proxy buffers** (128k/256k) in nginx for Keycloak's large token headers

## Troubleshooting

- **SSO redirect loop**: Check redirect URIs in Keycloak include ALL callback URLs (Tailscale + public)
- **Token issuer mismatch**: Enable `SkipIssuerCheck` (Go), `INSECURE_OIDC_SKIP_ISSUER_VERIFICATION` (OAuth2 Proxy), or accept multiple issuers (Node.js)
- **OAuth2 Proxy 500**: `docker logs oauth2-proxy --tail 20` -- usually email verification (`INSECURE_OIDC_ALLOW_UNVERIFIED_EMAIL`), redirect whitelist, or client secret mismatch
- **Groups claim missing `/` prefix**: Keycloak Group Membership mapper adds path prefix automatically -- configure `AdminGroup: "/gitea_admin"` with the slash
- **Admin locked out**: Add redirect URIs via DB query (see Admin Operations), then `docker restart keycloak`
- **Discovery returns wrong URLs**: Verify `KC_HOSTNAME` includes `/auth` path; restart Keycloak AND OAuth2 Proxy instances after changes
- **502 on /auth/ after restart**: Nginx DNS cache (10s TTL) -- wait or force-recreate nginx

## Related Files

| File | Purpose |
|------|---------|
| `/data/massimiliano/keycloak/docker-compose.yml` | Keycloak container definition |
| `/data/massimiliano/keycloak/.env` | DB password, admin credentials |
| `/data/massimiliano/proxy/nginx.conf` | Reverse proxy with auth_request patterns |
| `/data/massimiliano/proxy/docker-compose.yml` | OAuth2 Proxy instances (both Tailscale and public) |
| `/data/massimiliano/proxy/.env` | OAuth2 Proxy client secret, cookie secrets |
| `/data/massimiliano/Vari/go-filemanager/internal/auth/oidc.go` | Go OIDC integration |
| `/data/massimiliano/Vari/go-filemanager/internal/auth/session.go` | ReadOnly session field |
| `/data/massimiliano/dashboard-api/server.js` | Node.js JWT verification (jose) |
| `/data/massimiliano/Vari/server-api/main.go` | Go JWT verification (golang-jwt + keyfunc) |
| `/data/massimiliano/proxy/home/index.html` | JavaScript PKCE flow, visitor mode |
