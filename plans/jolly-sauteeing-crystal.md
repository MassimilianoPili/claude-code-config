# Fix code-server Session Persistence

## Context

code-server (VS Code browser) loses ALL UI state (open tabs, theme, folder selection, extensions visibility) every time the user closes and reopens the browser tab. Server-side data IS correctly persisted (settings.json, extensions, workspaceStorage exist on host volumes), but VS Code Web's session restoration depends on browser-side IndexedDB keyed by workspace URL. The redirect chain (`/ide/` → code-server 302 → `/ide/?folder=...`) causes VS Code to briefly load without a workspace, breaking the session key matching.

## Plan: Incremental Fixes (stop when it works)

### Step 1: Nginx auto-redirect with `?folder=` (eliminates 302 hop)

**File**: `/data/massimiliano/proxy/nginx.conf`
**Lines**: Both `/ide/` locations (~666 and ~1835)

Add an exact-match location BEFORE the existing `/ide/` that redirects bare `/ide/` to include the folder parameter:

```nginx
# Auto-redirect bare /ide/ to include workspace folder
location = /ide/ {
    if ($arg_folder = "") {
        return 302 $scheme://$host/ide/?folder=/data/massimiliano;
    }
    # Fall through to the regex location below
}
```

This ensures VS Code always loads with the workspace URL directly — no intermediate blank load.

Also update the dashboard link in `/data/massimiliano/proxy/home/index.html` to point to `/ide/?folder=/data/massimiliano`.

### Step 2: code-server flags for proxy awareness

**File**: `/data/massimiliano/code-server/docker-compose.yml`

Change command to:
```yaml
command: >-
  --auth none
  --bind-addr 0.0.0.0:8080
  --abs-proxy-base-path /ide/
  --app-name "SOL IDE"
  --trusted-origins https://sol.massimilianopili.com
  --disable-getting-started-override
  /data/massimiliano
```

- `--abs-proxy-base-path /ide/` — tells code-server its real URL prefix
- `--app-name "SOL IDE"` — stable PWA identity
- `--trusted-origins` — prevents WebSocket origin check failures through proxy

### Step 3: Add `proxy_cookie_path` in nginx

**File**: `/data/massimiliano/proxy/nginx.conf`
**Both `/ide/` locations**

Add inside the location block:
```nginx
proxy_cookie_path / /ide/;
```

This rewrites any `Set-Cookie Path=/` from code-server to `Path=/ide/`, ensuring cookies are correctly scoped to the subpath.

### Step 4 (if Steps 1-3 insufficient): Dedicated subdomain

Create `ide.massimilianopili.com` to avoid all path-rewriting issues:

1. **Cloudflare DNS**: CNAME `ide.massimilianopili.com` → tunnel
2. **`/data/massimiliano/cloudflared/config.yml`**: Add ingress `ide.massimilianopili.com` → `nginx:8894`
3. **nginx**: New server block on `:8894` with OAuth2 Proxy auth, direct proxy to code-server (no path rewriting)
4. **Keycloak**: Add `https://ide.massimilianopili.com/oauth2/callback` to oauth2-proxy client redirect URIs
5. **code-server command**: Remove `--abs-proxy-base-path` (no longer needed at root)

## Critical Files

| File | Action |
|------|--------|
| `/data/massimiliano/proxy/nginx.conf` | Add folder redirect + proxy_cookie_path |
| `/data/massimiliano/code-server/docker-compose.yml` | Add proxy-aware flags |
| `/data/massimiliano/proxy/home/index.html` | Update dashboard IDE link |
| `/data/massimiliano/cloudflared/config.yml` | Only if Step 4 needed |

## Verification

1. `docker compose -f /data/massimiliano/code-server/docker-compose.yml up -d --build`
2. `docker compose -f /data/massimiliano/proxy/docker-compose.yml up -d nginx --force-recreate`
3. Open `https://sol.massimilianopili.com/ide/` in browser
4. Verify auto-redirect to `?folder=/data/massimiliano`
5. Open some files, change theme, install extension
6. Close tab completely
7. Reopen `https://sol.massimilianopili.com/ide/` — verify state restored
