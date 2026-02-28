---
name: websocket-patterns
description: WebSocket patterns for binary protocol proxying, nginx reverse proxy configuration, JWT authentication via query params, heartbeat/ping-pong, xterm.js terminal integration, and ttyd binary protocol handling.
allowed-tools: Read, Write, Bash, Edit
category: backend
tags: [websocket, ws, binary, proxy, xterm, ttyd, nginx]
version: 1.0.0
---

# WebSocket Patterns — SOL Server

## Overview

WebSocket is used extensively on SOL server for real-time features: terminal (ttyd binary protocol),
Portainer live updates, code-server IDE, and GoAccess stats dashboard. All WebSocket connections
pass through the nginx reverse proxy on the `shared` Docker network.

## When to Use

- Implementing WebSocket connections through nginx reverse proxy
- Building a WebSocket proxy/gateway with authentication
- Working with binary WebSocket protocols (ttyd terminal)
- Adding a new real-time service behind nginx on SOL
- Debugging WebSocket connection failures (upgrade, timeout, binary corruption)
- Integrating xterm.js with a backend terminal service

## WebSocket Services on SOL

| Service | Path | Protocol | Auth | Timeout |
|---------|------|----------|------|---------|
| Dashboard terminal | `/api/ws` | Binary (ttyd) | JWT query param | 3600s |
| Portainer | `/portainer/` | Text (JSON) | OAuth2 Proxy | default |
| code-server | `/ide/` | Mixed | OAuth2 Proxy | 86400s |
| GoAccess stats | `/stats/ws` | Text (JSON) | None | default |

## Key Pattern 1: nginx WebSocket Proxy

```nginx
location /api/ {
    proxy_pass http://host.docker.internal:7681/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_read_timeout 3600s;   # 1 hour
    proxy_send_timeout 3600s;
}
```

**CRITICAL**: Without `proxy_http_version 1.1` and Upgrade/Connection headers, WebSocket handshake fails silently.

### Header purposes

- `proxy_http_version 1.1` -- WebSocket requires HTTP/1.1 (nginx defaults to 1.0 for upstreams)
- `Upgrade $http_upgrade` -- forwards client's `Upgrade: websocket` header
- `Connection "upgrade"` -- tells backend to switch protocols (nginx strips hop-by-hop headers)

### Timeout tuning

| Use case | `proxy_read_timeout` | Rationale |
|----------|---------------------|-----------|
| Terminal (ttyd) | 3600s (1 hour) | User may be idle between commands |
| code-server IDE | 86400s (24 hours) | Developer session lasts a full day |
| Default nginx | 60s | Will close idle WS connections -- always override! |

### Lazy DNS with WebSocket (Docker containers)

```nginx
location /portainer/ {
    set $portainer_upstream http://portainer:9000;
    proxy_pass $portainer_upstream;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
}
```

## Key Pattern 2: JWT Auth via Query Parameter

WebSocket doesn't support custom headers during handshake. Pass JWT as query parameter:

```javascript
// Client (browser)
const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
const ws = new WebSocket(`${protocol}//${location.host}/api/ws?token=${token}`);
```

```javascript
// Server (Node.js with jose)
import { createRemoteJWKSSet, jwtVerify } from 'jose';

const JWKS = createRemoteJWKSSet(
  new URL('http://127.0.0.1/auth/realms/sol/protocol/openid-connect/certs')
);

async function verifyToken(token) {
  try {
    const { payload } = await jwtVerify(token, JWKS, {
      issuer: [
        'http://keycloak:8080/auth/realms/sol',
        'https://sol.massimilianopili.com/auth/realms/sol'
      ]
    });
    return payload;
  } catch (err) {
    return null;
  }
}

wss.on('connection', async (clientWs, req) => {
  const url = new URL(req.url, 'http://localhost');
  const token = url.searchParams.get('token');
  const claims = await verifyToken(token);
  if (!claims) {
    clientWs.close(4401, 'Unauthorized');
    return;
  }
  // Check read-only role
  const roles = claims.resource_access?.['dashboard-chat']?.roles || [];
  if (roles.includes('readonly')) {
    clientWs.close(4403, 'Forbidden');
    return;
  }
});
```

### Custom Close Codes (4000-4999 range)

| Code | Meaning |
|------|---------|
| 4401 | Unauthorized (invalid JWT) |
| 4403 | Forbidden (read-only user) |
| 4429 | Too many sessions |

## Key Pattern 3: Binary WebSocket Proxy (ttyd Protocol)

Architecture: `xterm.js → dashboard-api (JWT gateway, :7681) → ttyd (:7682) → PTY bash`

### ttyd binary protocol

| Direction | Type byte | Payload | Description |
|-----------|-----------|---------|-------------|
| Server -> Client | `0x00` | Terminal output bytes | stdout/stderr from shell |
| Client -> Server | `0x00` | Terminal input bytes | stdin to shell |
| Client -> Server | `0x01` | JSON `{"columns":N,"rows":N}` | Terminal resize event |

### Bidirectional binary passthrough

```javascript
const ttydWs = new WebSocket('ws://127.0.0.1:7682/ws');

// Forward: ttyd -> client (terminal output)
ttydWs.on('message', (data, isBinary) => {
  if (clientWs.readyState === WebSocket.OPEN)
    clientWs.send(data, { binary: isBinary });
});

// Forward: client -> ttyd (terminal input + resize)
clientWs.on('message', (data, isBinary) => {
  if (ttydWs.readyState === WebSocket.OPEN)
    ttydWs.send(data, { binary: isBinary });
});
```

**CRITICAL**: The `{ binary: isBinary }` flag must be preserved. Binary data sent as text frame corrupts the stream.

## Key Pattern 4: Heartbeat / Dead Connection Detection

```javascript
const HEARTBEAT_INTERVAL = 30000; // 30 seconds

const pingInterval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (!ws.isAlive) { ws.terminate(); return; }
    ws.isAlive = false;
    ws.ping();
  });
}, HEARTBEAT_INTERVAL);

// On each new connection:
clientWs.isAlive = true;
clientWs.on('pong', () => { clientWs.isAlive = true; });

// Clean up on server shutdown
wss.on('close', () => clearInterval(pingInterval));
```

Flow: server pings every 30s -> if pong received, mark alive -> if no pong since last ping, terminate.

## Key Pattern 5: Session Limiting

```javascript
let activeSessions = 0;
const MAX_SESSIONS = 5;

wss.on('connection', async (clientWs, req) => {
  if (activeSessions >= MAX_SESSIONS) {
    clientWs.close(4429, 'Too many sessions');
    return;
  }
  activeSessions++;

  const ttydWs = new WebSocket('ws://127.0.0.1:7682/ws');

  let cleaned = false;  // guard against double cleanup
  function cleanup() {
    if (cleaned) return;
    cleaned = true;
    activeSessions--;
    if (ttydWs.readyState === WebSocket.OPEN) ttydWs.close();
    if (clientWs.readyState === WebSocket.OPEN) clientWs.close();
  }

  ttydWs.on('close', cleanup);
  ttydWs.on('error', cleanup);
  clientWs.on('close', cleanup);
  clientWs.on('error', cleanup);
});
```

**IMPORTANT**: The `cleaned` guard prevents double decrement when one side's close triggers the other's close event.

## Key Pattern 6: xterm.js Frontend Integration

```javascript
import { Terminal } from 'xterm';
import { FitAddon } from 'xterm-addon-fit';

const term = new Terminal({ cursorBlink: true, fontSize: 14 });
const fitAddon = new FitAddon();
term.loadAddon(fitAddon);
term.open(document.getElementById('terminal'));
fitAddon.fit();

const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
const ws = new WebSocket(`${protocol}//${location.host}/api/ws?token=${token}`);
ws.binaryType = 'arraybuffer';  // REQUIRED for binary protocol

// Receive terminal output (type byte 0)
ws.onmessage = (event) => {
  const data = new Uint8Array(event.data);
  if (data[0] === 0) term.write(data.slice(1));
};

// Send terminal input (type byte 0)
term.onData((data) => {
  const buf = new Uint8Array(data.length + 1);
  buf[0] = 0;
  for (let i = 0; i < data.length; i++) buf[i + 1] = data.charCodeAt(i);
  ws.send(buf);
});

// Send resize events (type byte 1)
term.onResize(({ cols, rows }) => {
  const msg = JSON.stringify({ columns: cols, rows: rows });
  const buf = new Uint8Array(msg.length + 1);
  buf[0] = 1;
  for (let i = 0; i < msg.length; i++) buf[i + 1] = msg.charCodeAt(i);
  ws.send(buf);
});

window.addEventListener('resize', () => fitAddon.fit());

// Handle close codes
ws.onclose = (event) => {
  if (event.code === 4401) term.write('\r\nSession expired.\r\n');
  else if (event.code === 4403) term.write('\r\nRead-only mode.\r\n');
  else if (event.code === 4429) term.write('\r\nToo many sessions.\r\n');
  else term.write('\r\nConnection closed.\r\n');
};
```

**NOTE**: `ws.binaryType = 'arraybuffer'` is required. Without it, binary messages arrive as Blob
objects requiring async reading, breaking synchronous xterm.js writes.

## Key Pattern 7: GoAccess WebSocket (Origin Normalization)

GoAccess verifies the Origin header. When proxied, the Origin may not match:

```nginx
location /stats/ws {
    set $goaccess_upstream http://goaccess:7890;
    proxy_pass $goaccess_upstream;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Origin "https://sol.massimilianopili.com";
}
```

Without the Origin override, GoAccess rejects the handshake with 403.

## Best Practices

1. Always set `proxy_http_version 1.1` with Upgrade/Connection headers
2. Increase `proxy_read_timeout` for long-lived connections (at least 3600s)
3. Use query params for JWT auth (WebSocket can't send custom headers during handshake)
4. Implement heartbeat ping/pong to detect dead connections
5. Guard against double cleanup with a boolean flag
6. Limit concurrent sessions to prevent resource exhaustion
7. Use `binaryType = 'arraybuffer'` for binary WebSocket protocols
8. Normalize Origin header when proxying to services that verify it (GoAccess)
9. Log close codes server-side for debugging (1006 = abnormal closure)
10. Test with `websocat` CLI for quick debugging without a browser

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Upgrade fails (HTTP 400/426) | Missing `proxy_http_version 1.1` or headers | Add all three directives to nginx location |
| Closes after 60s idle | Default nginx timeout | Increase `proxy_read_timeout` |
| Binary data corrupted | `isBinary` flag not preserved | Pass `{ binary: isBinary }` in both directions |
| GoAccess WS 403 | Origin mismatch | Add `proxy_set_header Origin` |
| Session counter drift | Double cleanup | Add `cleaned` boolean guard |
| Garbled terminal text | Missing `arraybuffer` type | Set `ws.binaryType = 'arraybuffer'` |
| Works Tailscale, fails public | Cloudflare WS timeout | Enable WebSocket in CF dashboard |
| xterm blank after connect | ttyd not running | Check `systemctl --user status ttyd` |

## Related Files on SOL

| File | Role |
|------|------|
| `/data/massimiliano/proxy/nginx.conf` | All WebSocket proxy locations |
| `/data/massimiliano/dashboard-api/server.js` | JWT gateway + ttyd binary proxy |
| `/data/massimiliano/proxy/home/index.html` | xterm.js frontend integration |
| `/data/massimiliano/code-server/docker-compose.yml` | code-server WebSocket service |
| `/data/massimiliano/portainer/docker-compose.yml` | Portainer WebSocket service |
