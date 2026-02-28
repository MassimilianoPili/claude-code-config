---
name: nodejs-backend
description: Node.js backend patterns for JWT authentication with jose, WebSocket proxying, HTTP API servers, atomic file operations, and systemd service deployment for self-hosted infrastructure.
allowed-tools: Read, Write, Bash, Edit
category: backend
tags: [nodejs, javascript, websocket, jwt, jose, http, systemd]
version: 1.0.0
---

# Node.js Backend Patterns (SOL Server)

## Overview

Node.js backend on the SOL server. The primary service is `dashboard-api`, which runs as a
**systemd user-level service** on the host (NOT in Docker). It provides:

- **JWT-authenticated WebSocket proxy** to the ttyd terminal emulator
- **Notes API** (GET/PUT with atomic file writes)
- **Health check endpoint** (unauthenticated)

Dependencies: `ws` (WebSocket) and `jose` (JWT/JWKS). No frameworks -- raw `http.createServer`.

### Service topology

```text
browser xterm.js --> /api/ws?token=JWT --> [dashboard-api :7681] --> ttyd :7682/ws --> PTY bash
browser textarea --> /api/notes         --> [dashboard-api :7681] --> notes.txt (atomic write)
```

- **dashboard-api** listens on `0.0.0.0:7681` (reachable by nginx via `host.docker.internal`)
- **ttyd** listens on `127.0.0.1:7682` (localhost only, no auth of its own)
- nginx strips the `/api/` prefix before proxying to dashboard-api

### Key files

| File | Purpose |
|------|---------|
| `/data/massimiliano/dashboard-api/server.js` | Main server (~213 lines) |
| `/data/massimiliano/dashboard-api/package.json` | Dependencies: ws ^8.18.0, jose ^6.0.11 |
| `/data/massimiliano/dashboard-api/notes.txt` | Persistent notes storage |
| `/data/massimiliano/dashboard-api/ttyd` | Static ttyd 1.7.7 binary |
| `~/.config/systemd/user/dashboard-api.service` | systemd unit for the API |
| `~/.config/systemd/user/ttyd.service` | systemd unit for ttyd |

## When to Use

- Building a new Node.js API service with Keycloak JWT authentication
- Implementing a WebSocket proxy or gateway with auth
- Working on or extending the dashboard-api service
- Deploying a Node.js process as a systemd user-level service (not Docker)
- Implementing atomic file operations for concurrent-safe writes
- Adding read-only / role-based access using Keycloak `resource_access` claims

## Key Pattern 1: JWT Verification with jose (JWKS)

The `jose` library handles JWKS fetching, caching, key rotation, and RS256 signature verification.
The `createRemoteJWKSet` function fetches the JWKS endpoint and caches keys for 5 minutes
(`cooldownDuration`). This is the recommended approach over the older `jsonwebtoken` library.

```javascript
const { createRemoteJWKSet, jwtVerify } = require('jose');

const KEYCLOAK_ISSUER = 'http://127.0.0.1/auth/realms/sol';
const JWKS_URL = KEYCLOAK_ISSUER + '/protocol/openid-connect/certs';
const JWKS = createRemoteJWKSet(new URL(JWKS_URL), {
  cooldownDuration: 300000, // cache JWKS for 5 minutes
});

async function verifyToken(token) {
  if (!token) return null;
  try {
    const { payload } = await jwtVerify(token, JWKS, {
      issuer: [
        'http://127.0.0.1/auth/realms/sol',
        'http://keycloak:8080/auth/realms/sol',
        'https://sol.massimilianopili.com/auth/realms/sol',
      ],
    });
    return payload;
  } catch (e) {
    console.error('JWT verification failed:', e.code || e.message);
    return null;
  }
}
```

**Multiple issuers**: the `iss` claim in the token varies depending on how the user logged in
(Tailscale direct, Docker internal, or public Cloudflare Tunnel). All three must be accepted.

**JWKS URL**: uses `127.0.0.1` (nginx on the host) rather than `keycloak:8080` because
dashboard-api runs on the host, not inside Docker, and cannot resolve Docker DNS names.

## Key Pattern 2: Read-Only Check via resource_access

Keycloak embeds client-specific roles in the `resource_access` claim of the JWT. The `readonly`
role on the `dashboard-chat` client controls read-only access for the `visitor` user.

```javascript
function isReadOnly(claims) {
  const roles = claims?.resource_access?.['dashboard-chat']?.roles;
  return Array.isArray(roles) && roles.includes('readonly');
}
```

This pattern is shared across all custom services on SOL (File Manager checks `go-filemanager`
client, Server API checks both `dashboard-chat` and `server-api` clients).

## Key Pattern 3: Raw HTTP Server (no Express)

For simple APIs with few routes, raw `http.createServer` avoids framework overhead.
The routing pattern: set `Content-Type: application/json` globally, match `url.pathname` +
`req.method`, extract JWT via `extractBearerToken()`, verify with `verifyToken()`.

```javascript
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${HOST}:${PORT}`);
  res.setHeader('Content-Type', 'application/json');

  if (url.pathname === '/health') {                      // no auth
    res.writeHead(200);
    res.end(JSON.stringify({ status: 'ok', sessions: activeSessions }));
    return;
  }

  const token = extractBearerToken(req);                 // JWT required below
  const claims = await verifyToken(token);
  if (!claims) { res.writeHead(401); res.end(JSON.stringify({ error: 'unauthorized' })); return; }

  if (url.pathname === '/notes' && req.method === 'GET') { /* read notes.txt */ }
  if (url.pathname === '/notes' && req.method === 'PUT') {
    if (isReadOnly(claims)) { res.writeHead(403); /* ... */ return; }
    // parse body, atomic write (see Pattern 4)
  }

  res.writeHead(404);
  res.end(JSON.stringify({ error: 'not found' }));
});
```

See `/data/massimiliano/dashboard-api/server.js` for the full implementation (~213 lines).

## Key Pattern 4: Atomic File Write

The `.tmp` + `rename` pattern prevents partial reads during concurrent access:

```javascript
const tmp = NOTES_FILE + '.tmp';
fs.writeFileSync(tmp, content || '', 'utf-8');
fs.renameSync(tmp, NOTES_FILE);
```

`fs.renameSync` is atomic on Linux (same filesystem). The reader either sees the old file
or the new file, never a partially-written file. This is critical because the dashboard
frontend auto-saves notes with a 1-second debounce, creating frequent concurrent writes.

## Key Pattern 5: WebSocket Proxy Gateway

The core architecture: dashboard-api acts as an authenticated gateway between the browser
and the raw ttyd WebSocket. JWT is passed as a query parameter because the WebSocket API
does not support custom HTTP headers.

```javascript
const WebSocket = require('ws');
const wss = new WebSocket.Server({ server, path: '/ws', verifyClient: () => true });

wss.on('connection', async (clientWs, req) => {
  // JWT from query param (WebSocket cannot send Authorization headers)
  const url = new URL(req.url, `http://${HOST}:${PORT}`);
  const token = url.searchParams.get('token');
  const claims = await verifyToken(token);

  if (!claims) { clientWs.close(4401, 'Unauthorized'); return; }
  if (isReadOnly(claims)) { clientWs.close(4403, 'Forbidden: read-only user'); return; }
  if (activeSessions >= MAX_SESSIONS) { clientWs.close(4429, 'Too many sessions'); return; }

  activeSessions++;
  let cleaned = false;
  const user = claims.preferred_username || claims.sub;

  console.log(`[terminal] Session started: user=${user}, active=${activeSessions}`);

  function cleanup() {
    if (cleaned) return;
    cleaned = true;
    activeSessions--;
    try { ttydWs.close(); } catch (e) {}
    try { clientWs.close(); } catch (e) {}
    console.log(`[terminal] Session ended: user=${user}, active=${activeSessions}`);
  }

  // Connect to ttyd backend (localhost only)
  const ttydWs = new WebSocket(TTYD_WS);

  // Bidirectional binary passthrough (ttyd protocol is transparent)
  ttydWs.on('message', (data, isBinary) => {
    if (clientWs.readyState === WebSocket.OPEN)
      clientWs.send(data, { binary: isBinary });
  });
  clientWs.on('message', (data, isBinary) => {
    if (ttydWs.readyState === WebSocket.OPEN)
      ttydWs.send(data, { binary: isBinary });
  });

  ttydWs.on('close', cleanup);
  ttydWs.on('error', cleanup);
  clientWs.on('close', cleanup);
  clientWs.on('error', cleanup);

  // Heartbeat tracking for this connection
  clientWs.isAlive = true;
  clientWs.on('pong', () => { clientWs.isAlive = true; });
});
```

### WebSocket custom close codes

| Code | Meaning | Trigger |
|------|---------|---------|
| 4401 | Unauthorized | Invalid or missing JWT |
| 4403 | Forbidden | Read-only user (visitor) |
| 4429 | Too many sessions | MAX_SESSIONS (5) exceeded |

### Cleanup guard

The `cleaned` boolean prevents double-decrement of `activeSessions` when both sides close
simultaneously (network drop triggers both `clientWs.on('close')` and `ttydWs.on('error')`).

### ttyd binary protocol

The ttyd WebSocket protocol uses a type byte prefix: `0x00` = I/O data, `0x01` = resize JSON.
Dashboard-api does not parse this — it passes all messages through as opaque binary.

## Key Pattern 6: Heartbeat / Ping-Pong

Detects dead WebSocket connections (client navigated away, network dropped, browser tab killed).
Without heartbeat, dead connections would accumulate and consume session slots.

```javascript
const pingInterval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (!ws.isAlive) {
      ws.terminate();  // hard kill, triggers cleanup
      return;
    }
    ws.isAlive = false;
    ws.ping();
  });
}, 30000);  // every 30 seconds

wss.on('close', () => clearInterval(pingInterval));
```

On each connection, the client WebSocket gets `isAlive = true` and a `pong` handler that
resets it. If a client does not respond to ping within 30 seconds, it is terminated.

## Key Pattern 7: Bearer Token Extraction

Standard HTTP Authorization header parsing for REST endpoints. WebSocket uses query params
instead (see Pattern 5).

```javascript
function extractBearerToken(req) {
  const auth = req.headers['authorization'];
  if (auth && auth.startsWith('Bearer ')) return auth.slice(7);
  return null;
}
```

## systemd User-Level Service Deployment

Dashboard-api and ttyd run as **systemd user services** (not system-wide), managed by the
`massimiliano` user. This means they start with `lingering` enabled and survive SSH logout.

### dashboard-api.service

```ini
[Unit]
Description=Dashboard API (JWT gateway + notes)
After=network.target ttyd.service

[Service]
ExecStart=/home/massimiliano/.nvm/versions/node/v24.13.1/bin/node server.js
WorkingDirectory=/data/massimiliano/dashboard-api
Environment=HOME=/home/massimiliano
Environment=PATH=/home/massimiliano/.nvm/versions/node/v24.13.1/bin:/data/massimiliano/shell-scripts/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

### ttyd.service

```ini
[Unit]
Description=ttyd terminal (PTY backend for dashboard)
After=network.target

[Service]
ExecStart=/data/massimiliano/dashboard-api/ttyd -p 7682 -i 127.0.0.1 -W bash -l
WorkingDirectory=/data/massimiliano
Environment=HOME=/home/massimiliano
Environment=TERM=xterm-256color
Environment=PATH=/data/massimiliano/shell-scripts/bin:/home/massimiliano/.nvm/versions/node/v24.13.1/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

### Operations

```bash
systemctl --user status dashboard-api    # check status
systemctl --user restart dashboard-api   # restart after code changes
journalctl --user -u dashboard-api -f    # follow logs
systemctl --user daemon-reload           # after editing .service files
```

### Caveats

- **NVM PATH**: systemd does not source `.bashrc`/`.nvm/nvm.sh`, so the full absolute path to the
  NVM node binary must be in `ExecStart` and `PATH`. Update both services when upgrading Node.js.
- **Ordering**: `dashboard-api` declares `After=ttyd.service` but handles ttyd being unavailable
  gracefully (WebSocket connection fails, client retries).

## Best Practices

1. **Use `jose`** (not `jsonwebtoken`) for JWT — supports JWKS auto-refresh and key rotation
2. **Accept multiple issuers** for Keycloak dual-URL pattern (localhost, Docker, public)
3. **Query param `?token=JWT`** for WebSocket auth (no Authorization header in browser WS API)
4. **Atomic file writes** (`.tmp` + `rename`) prevent corruption from concurrent access
5. **Limit concurrent sessions** (`MAX_SESSIONS`) to prevent resource exhaustion
6. **Heartbeat every 30s** to detect dead WebSocket connections and free session slots
7. **Bind `0.0.0.0`** so nginx (via `host.docker.internal`) can reach host services
8. **Custom close codes (4xxx)** for application-level WebSocket errors (RFC 6455 reserved range)
9. **Guard cleanup** with a boolean to prevent double-decrement on simultaneous close/error events

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| JWT verification fails | JWKS URL unreachable | Ensure nginx is running on the host (port 80). The JWKS URL goes through localhost nginx, not directly to Keycloak. |
| WebSocket connection refused | ttyd not running | `systemctl --user status ttyd` — restart if needed |
| Service won't start | NVM path outdated | Check that the node version in the .service file matches `node --version` |
| Notes not saving | File permissions | Check write access to `/data/massimiliano/dashboard-api/` and that the `.tmp` file can be created |
| 502 on `/api/` | dashboard-api down | `systemctl --user status dashboard-api` — check logs with `journalctl --user -u dashboard-api` |
| Sessions stuck at MAX | Dead connections not cleaned | The 30s heartbeat should handle this; if not, restart the service |
| Visitor can use terminal | Missing `readonly` role | Verify the `visitor` user has `readonly` role on the `dashboard-chat` client in Keycloak |
