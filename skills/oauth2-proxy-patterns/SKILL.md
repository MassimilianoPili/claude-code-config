---
name: oauth2-proxy-patterns
description: OAuth2 Proxy patterns for dual-instance deployment, nginx auth_request integration, Keycloak OIDC provider configuration, cookie management, PKCE S256, and visitor access control in self-hosted reverse proxy setups.
allowed-tools: Read, Write, Bash, Edit
category: infrastructure
tags: [oauth2-proxy, authentication, keycloak, nginx, oidc, sso]
version: 1.0.0
---

# OAuth2 Proxy Patterns — Server SOL

## Overview

Two OAuth2 Proxy instances run on the SOL server, both using Keycloak (realm `sol`) as OIDC provider:

- **Tailscale instance** (`oauth2-proxy`, port 4180) — HTTP, for internal access via `100.86.46.84`
- **Public instance** (`oauth2-proxy-public`, port 4181) — HTTPS, for Cloudflare Tunnel via `sol.massimilianopili.com`

They protect services that lack native OIDC integration: pgAdmin, Portainer, mongo-express, libSQL console, code-server, Artemis console, and KP Manager. Services with native OIDC (Gitea, File Manager) and JWT-authenticated APIs (Claude Proxy, Server API, Dashboard API) do NOT use OAuth2 Proxy.

Both instances share the same Keycloak client (`oauth2-proxy`) but have separate cookie secrets, separate redirect URLs, and different cookie security settings matching their protocol.

## When to Use

- Adding a new service behind OAuth2 Proxy (no native auth)
- Debugging login failures, redirect loops, or 500 errors from OAuth2 Proxy
- Understanding the dual-instance pattern (Tailscale HTTP vs. Cloudflare HTTPS)
- Adding visitor-level blocking at the nginx layer
- Registering new redirect URIs in Keycloak for OAuth2 Proxy callbacks

## Docker Compose Configuration

File: `/data/massimiliano/proxy/docker-compose.yml`

### Tailscale Instance (oauth2-proxy, port 4180)

```yaml
oauth2-proxy:
    image: quay.io/oauth2-proxy/oauth2-proxy:latest
    container_name: oauth2-proxy
    restart: unless-stopped
    environment:
      OAUTH2_PROXY_PROVIDER: keycloak-oidc
      OAUTH2_PROXY_OIDC_ISSUER_URL: http://keycloak:8080/auth/realms/sol
      OAUTH2_PROXY_CLIENT_ID: oauth2-proxy
      OAUTH2_PROXY_CLIENT_SECRET: ${OAUTH2_PROXY_CLIENT_SECRET}
      OAUTH2_PROXY_COOKIE_SECRET: ${OAUTH2_PROXY_COOKIE_SECRET}
      OAUTH2_PROXY_HTTP_ADDRESS: 0.0.0.0:4180
      OAUTH2_PROXY_EMAIL_DOMAINS: "*"
      OAUTH2_PROXY_COOKIE_SECURE: "false"
      OAUTH2_PROXY_REDIRECT_URL: http://100.86.46.84:8081/oauth2/callback
      OAUTH2_PROXY_UPSTREAMS: http://pgadmin:5050/
      OAUTH2_PROXY_CODE_CHALLENGE_METHOD: S256
      OAUTH2_PROXY_SKIP_PROVIDER_BUTTON: "true"
      OAUTH2_PROXY_INSECURE_OIDC_SKIP_ISSUER_VERIFICATION: "true"
      OAUTH2_PROXY_INSECURE_OIDC_ALLOW_UNVERIFIED_EMAIL: "true"
      OAUTH2_PROXY_WHITELIST_DOMAINS: "100.86.46.84:*"
      OAUTH2_PROXY_SET_XAUTHREQUEST: "true"
    networks:
      - shared
```

### Public Instance (oauth2-proxy-public, port 4181)

```yaml
oauth2-proxy-public:
    image: quay.io/oauth2-proxy/oauth2-proxy:latest
    container_name: oauth2-proxy-public
    restart: unless-stopped
    environment:
      OAUTH2_PROXY_PROVIDER: keycloak-oidc
      OAUTH2_PROXY_OIDC_ISSUER_URL: http://keycloak:8080/auth/realms/sol
      OAUTH2_PROXY_CLIENT_ID: oauth2-proxy
      OAUTH2_PROXY_CLIENT_SECRET: ${OAUTH2_PROXY_CLIENT_SECRET}
      OAUTH2_PROXY_COOKIE_SECRET: ${OAUTH2_PROXY_PUBLIC_COOKIE_SECRET}
      OAUTH2_PROXY_HTTP_ADDRESS: 0.0.0.0:4181
      OAUTH2_PROXY_EMAIL_DOMAINS: "*"
      OAUTH2_PROXY_COOKIE_SECURE: "true"
      OAUTH2_PROXY_COOKIE_DOMAINS: ".massimilianopili.com"
      OAUTH2_PROXY_REDIRECT_URL: https://sol.massimilianopili.com/oauth2/callback
      OAUTH2_PROXY_WHITELIST_DOMAINS: ".massimilianopili.com"
      OAUTH2_PROXY_CODE_CHALLENGE_METHOD: S256
      OAUTH2_PROXY_SKIP_PROVIDER_BUTTON: "true"
      OAUTH2_PROXY_INSECURE_OIDC_SKIP_ISSUER_VERIFICATION: "true"
      OAUTH2_PROXY_INSECURE_OIDC_ALLOW_UNVERIFIED_EMAIL: "true"
      OAUTH2_PROXY_SET_XAUTHREQUEST: "true"
    networks:
      - shared
```

### Key Differences Between Instances

| Setting | Tailscale (4180) | Public (4181) |
|---------|------------------|---------------|
| `COOKIE_SECURE` | `false` (HTTP) | `true` (HTTPS via Cloudflare) |
| `COOKIE_DOMAINS` | (default, single host) | `.massimilianopili.com` |
| `COOKIE_SECRET` | `${OAUTH2_PROXY_COOKIE_SECRET}` | `${OAUTH2_PROXY_PUBLIC_COOKIE_SECRET}` |
| `REDIRECT_URL` | `http://100.86.46.84:8081/oauth2/callback` | `https://sol.massimilianopili.com/oauth2/callback` |
| `WHITELIST_DOMAINS` | `100.86.46.84:*` | `.massimilianopili.com` |

Secrets are in `/data/massimiliano/proxy/.env`.

## nginx auth_request Pattern

File: `/data/massimiliano/proxy/nginx.conf`

nginx delegates authentication to OAuth2 Proxy using `auth_request`. The `/oauth2/` location must exist on the same server block as the protected service.

### Standard Pattern (mongo-express example, Tailscale :80)

```nginx
# OAuth2 Proxy endpoint (Tailscale instance)
location /oauth2/ {
    set $oauth2_upstream http://oauth2-proxy:4180;
    proxy_pass $oauth2_upstream;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_buffer_size 128k;
    proxy_buffers 4 256k;
    proxy_busy_buffers_size 256k;
}

# Protected service
location /mongo/ {
    auth_request /oauth2/auth;
    error_page 401 =302 /oauth2/start?rd=$request_uri;

    auth_request_set $user $upstream_http_x_auth_request_user;
    auth_request_set $email $upstream_http_x_auth_request_email;
    proxy_set_header X-Forwarded-User $user;
    proxy_set_header X-Forwarded-Email $email;

    set $mongo_upstream http://mongo-express:8081;
    proxy_pass $mongo_upstream;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

### Public Server Block (:8888) — Uses Public Instance

On the public server block (:8888), the `/oauth2/` location points to `oauth2-proxy-public:4181` instead of `oauth2-proxy:4180`, and sets `X-Forwarded-Proto https` (Cloudflare terminates TLS). Same buffer configuration applies.

### Cross-Port Redirect (Portainer on :8082)

Portainer lives on Tailscale port 8082 but the OAuth2 Proxy callback is on port 8081. The `rd=` parameter must use an absolute URL so the browser redirects back to the correct port after login:

```nginx
# Server block :8082
location /portainer/ {
    auth_request /oauth2/auth;
    error_page 401 =302 /oauth2/start?rd=http://100.86.46.84:8082$request_uri;
    # ...
}
```

Without the absolute URL, the redirect would go back to `:8081` (where the callback lives) instead of `:8082` (where Portainer is).

### WebSocket Support (Portainer, code-server)

Services requiring WebSocket add these directives inside the protected location:

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_read_timeout 86400s;  # 24h for long-lived connections (code-server)
```

### Multi-User Routing (code-server)

code-server uses a `map` at the `http {}` level to route by authenticated username:

```nginx
map $ide_auth_user $ide_backend {
    "sol_root"   code-server-massimiliano:8080;
    default      "";
}

location /ide/ {
    auth_request /oauth2/auth;
    error_page 401 =302 /oauth2/start?rd=$request_uri;

    auth_request_set $ide_auth_user $upstream_http_x_auth_request_preferred_username;
    # ...
    rewrite ^/ide/(.*) /$1 break;
    proxy_pass http://$ide_backend;
}
```

## Visitor Blocking at nginx Level

For services where the `visitor` user must be completely blocked (e.g., KP Manager contains passwords), use `auth_request_set` to extract the username and block with `if`:

```nginx
location /kp/ {
    auth_request /oauth2/auth;
    error_page 401 =302 /oauth2/start?rd=$request_uri;

    auth_request_set $user $upstream_http_x_auth_request_user;
    auth_request_set $email $upstream_http_x_auth_request_email;
    auth_request_set $auth_user $upstream_http_x_auth_request_preferred_username;
    proxy_set_header X-Forwarded-User $user;
    proxy_set_header X-Forwarded-Email $email;

    if ($auth_user = "visitor") {
        return 403;
    }

    set $kp_upstream http://kp-manager:8095;
    rewrite ^/kp/(.*) /$1 break;
    proxy_pass $kp_upstream;
    # ...
}
```

This pattern is applied on both the Tailscale (:80) and public (:8888) server blocks.

## Keycloak Client Configuration

Client `oauth2-proxy` in Keycloak realm `sol`:

- **Client ID**: `oauth2-proxy`
- **Client authentication**: On (confidential)
- **Code Challenge Method**: S256 (PKCE)
- **Redirect URIs**:
  - `http://100.86.46.84:8081/oauth2/callback` (Tailscale pgAdmin)
  - `http://100.86.46.84:8082/oauth2/callback` (Tailscale Portainer)
  - `https://sol.massimilianopili.com/oauth2/callback` (public)

### Adding a New Redirect URI (via DB)

When adding a new service on a new Tailscale port that needs OAuth2 Proxy:

```bash
docker exec postgres psql -U keycloak -d keycloak -c "
INSERT INTO redirect_uris (client_id, value)
SELECT c.id, 'http://100.86.46.84:NEW_PORT/oauth2/callback'
FROM client c
WHERE c.client_id = 'oauth2-proxy'
  AND c.realm_id = (SELECT id FROM realm WHERE name = 'sol');"
docker restart keycloak
```

After restarting Keycloak, also restart both OAuth2 Proxy instances (they cache OIDC discovery):

```bash
cd /data/massimiliano/proxy && docker compose up -d oauth2-proxy oauth2-proxy-public --force-recreate
```

## Environment Variables Reference

- `PROVIDER: keycloak-oidc` -- Keycloak-specific OIDC provider (handles realm URL structure)
- `OIDC_ISSUER_URL` -- backchannel issuer (`http://keycloak:8080/auth/realms/sol`, Docker-internal)
- `SKIP_PROVIDER_BUTTON: "true"` -- skip OAuth2 Proxy login page, redirect directly to Keycloak
- `INSECURE_OIDC_SKIP_ISSUER_VERIFICATION` -- discovery uses internal URL but token issuer may be external
- `INSECURE_OIDC_ALLOW_UNVERIFIED_EMAIL` -- Keycloak does not enforce email verification by default
- `SET_XAUTHREQUEST: "true"` -- pass user info via `X-Auth-Request-*` headers (consumed by `auth_request_set`)
- `CODE_CHALLENGE_METHOD: S256` -- enable PKCE for authorization code flow
- `COOKIE_SECRET` -- 32-byte random base64 (must be different per instance): `python3 -c "import secrets; print(secrets.token_urlsafe(32))"`
- `EMAIL_DOMAINS: "*"` -- accept any email domain (Keycloak handles access control)

## Services Protected by OAuth2 Proxy

| Service | nginx Location | Proxy Pattern | WebSocket | Notes |
|---------|---------------|---------------|-----------|-------|
| pgAdmin | `/pgadmin/` | Pattern B (keep prefix, SCRIPT_NAME handles it) | No | Dedicated server block :8081 (Tailscale) |
| Portainer | `/portainer/` | Pattern B (keep prefix, `--base-url` handles it) | Yes | Dedicated server block :8082 (Tailscale), cross-port `rd=` |
| mongo-express | `/mongo/` | Pattern B (keep prefix, `ME_CONFIG_SITE_BASEURL`) | No | On :80 and :8888 |
| libSQL console | `/libsql/` | Pattern A (strip prefix) | No | Tailscale only (:80) |
| code-server | `/ide/` | Pattern A (strip prefix) + multi-user map | Yes | On :80 and :8888, `proxy_read_timeout 86400s` |
| Artemis console | `/mq/` | Special (`proxy_pass $upstream$request_uri`) | No | Tailscale only (:80) |
| KP Manager | `/kp/` | Pattern A (strip prefix) + visitor block | No | On :80 and :8888 |

**Pattern A** = nginx strips the prefix with `rewrite ^/path/(.*) /$1 break;` before forwarding.
**Pattern B** = nginx forwards the full URI; the service handles the subpath internally.

## Proxy Buffer Configuration

OAuth2 Proxy responses include large headers (tokens, cookies). Without adequate buffers, nginx returns 502. Always include in `/oauth2/` locations:

```nginx
proxy_buffer_size 128k;
proxy_buffers 4 256k;
proxy_busy_buffers_size 256k;
```

## Best Practices

1. **Separate cookie secrets** for each instance — prevents cookie conflicts between HTTP and HTTPS.
2. **Always set `SET_XAUTHREQUEST: "true"`** to pass user identity to upstream services via headers.
3. **Use `SKIP_PROVIDER_BUTTON`** to skip the OAuth2 Proxy landing page and redirect straight to Keycloak.
4. **Match `COOKIE_SECURE` to protocol** — `false` for HTTP (Tailscale), `true` for HTTPS (Cloudflare).
5. **Restart OAuth2 Proxy after Keycloak changes** — OIDC discovery is cached at startup.
6. **Use `proxy_buffer_size 128k`** in nginx for all `/oauth2/` locations to handle large auth headers.
7. **Use lazy DNS** (`set $var` + `proxy_pass $var`) with `resolver 127.0.0.11 valid=10s` so nginx does not crash if OAuth2 Proxy containers are temporarily down.
8. **Restart with `--force-recreate`** (never `nginx -s reload`) due to bind-mount inode issues.

## Troubleshooting

### 500 Error from OAuth2 Proxy

```bash
docker logs oauth2-proxy --tail 20
docker logs oauth2-proxy-public --tail 20
```

Common causes:
- Unverified email (fix: `INSECURE_OIDC_ALLOW_UNVERIFIED_EMAIL: "true"`)
- Token exchange failure (check Keycloak client secret in `.env`)
- OIDC discovery failure (check that Keycloak container is running on the `shared` network)

### Infinite Redirect Loop

Verify that the `/oauth2/` location block exists on the **same server block** as the protected service. If the protected service is on `:8082` and `/oauth2/` is only on `:8081`, the auth subrequest will fail.

### Cookie Not Being Set

- **HTTP**: Verify `COOKIE_SECURE: "false"` (browsers reject Secure cookies over HTTP)
- **Cross-subdomain**: Verify `COOKIE_DOMAINS: ".massimilianopili.com"` for public instance
- **Same-site**: The callback URL domain must match `WHITELIST_DOMAINS`

### Callback URL Mismatch (Keycloak Error)

Keycloak rejects the authorization request if the redirect URI is not registered. Verify registered URIs:

```bash
docker exec postgres psql -U keycloak -d keycloak -c "
SELECT ru.value FROM redirect_uris ru
JOIN client c ON ru.client_id = c.id
WHERE c.client_id = 'oauth2-proxy'
  AND c.realm_id = (SELECT id FROM realm WHERE name = 'sol');"
```

### 502 After Container Restart

The nginx lazy DNS resolver caches the container IP for 10 seconds (`valid=10s`). After recreating an OAuth2 Proxy container (new IP), wait 10 seconds or force-recreate nginx:

```bash
cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate
```
