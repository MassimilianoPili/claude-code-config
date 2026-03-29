# Claude Web UI — Claude Code nel browser

## Context

I tab chat Claude Code (webview panel dell'estensione VS Code) non sopravvivono al reconnect. Serve un'interfaccia web standalone che replichi l'esperienza smooth dell'estensione, accessibile da qualsiasi browser via URL (`sol.massimilianopili.com/claude-web/`).

Il protocollo è JSONL via stdin/stdout di `claude --print --output-format stream-json --input-format stream-json`. Su SOL gira come servizio host (systemd), con Dockerfile incluso per chi vuole installarselo altrove.

## Architettura

```
Browser ←─ WebSocket (primary) ──→ Go server (:8100) ←─ stdin/stdout ─→ claude CLI (host)
        ←─ HTTP Stream (fallback) ─→
                                          ↕
                                    JWT auth (nginx auth_request)
                                          ↕
                                    nginx (/claude-web/)
```

**Transport duale**: WebSocket come primary (più snappy), HTTP Streamable come fallback automatico (proxy restrittivi, reti aziendali). Il frontend auto-detect: tenta WS upgrade, se fallisce degrada a POST + ReadableStream.

## Piano

### 1. Struttura progetto

Dir: `/data/massimiliano/claude-web/`

```
claude-web/
├── main.go           # HTTP server, route dispatch, embed static
├── auth.go           # JWT validation (opzionale, disabilitabile)
├── claude.go         # Spawn/gestione processi claude CLI, session map
├── transport.go      # WebSocket handler + HTTP Streaming handler
├── static/
│   └── index.html    # UI chat (single page, embedded)
├── Dockerfile        # Multi-stage: Go build + Node.js + claude CLI
├── docker-compose.yml
├── .env              # ANTHROPIC_API_KEY, JWT_SECRET (opzionale)
└── go.mod
```

### 2. Backend Go — `main.go`

- HTTP server su `:8100` (env `PORT`)
- `//go:embed static` per servire l'UI
- Route:
  - `GET /` → UI (index.html)
  - `GET /ws` → WebSocket upgrade + streaming bidirezionale
  - `POST /api/chat` → HTTP Streamable fallback (chunked response)
  - `GET /api/sessions` → lista sessioni disponibili
  - `GET /health` → healthcheck
- Dipendenza esterna: `gorilla/websocket` (unica)

Pattern: `/data/massimiliano/knowledge-graph/main.go`

### 3. Backend Go — `claude.go`

Gestione processi Claude CLI:

```go
cmd := exec.Command(claudeBinary,
    "--print",
    "--output-format", "stream-json",
    "--input-format", "stream-json",
    "--session-id", sessionID,
)
cmd.Stdin = stdinPipe
cmd.Stdout = stdoutPipe
```

- **Session map**: `sync.Map[sessionID → *ClaudeProcess]`
- **ClaudeProcess**: `cmd *exec.Cmd`, `stdin io.WriteCloser`, `stdout *bufio.Scanner`, `mu sync.Mutex`
- **Goroutine reader**: legge stdout riga per riga, dispatcha a tutti i listener (WebSocket o HTTP)
- **Input**: messaggio utente → `{"type":"user","message":{"text":"..."}}\n` → stdin pipe
- **Idle timeout**: kill processo dopo 30min di inattività (configurabile)
- **Max concurrent**: limite sessioni simultanee (env `MAX_SESSIONS`, default 5)
- **Resume**: `--session-id <uuid>` riprende sessioni esistenti dal disco

Pattern: `/data/massimiliano/Vari/mcp-proxy/main.go`

### 4. Backend Go — `transport.go`

Due handler, stessa logica interna:

**WebSocket handler** (`/ws?session=<id>&token=<jwt>`):
- Upgrade con `gorilla/websocket`
- Bidirezionale: client→server (messaggi utente), server→client (JSONL events)
- Ping/pong keepalive ogni 30s
- Su disconnect: sessione resta viva (riattaccabile)

**HTTP Streaming handler** (`POST /api/chat`):
- Body: `{"session_id": "...", "message": "..."}`
- Response: `Transfer-Encoding: chunked`, `Content-Type: text/event-stream`
- Ogni riga JSONL scritta con `flusher.Flush()` per streaming immediato
- Connessione chiusa al `result` event

**Auto-fallback nel frontend**:
```javascript
try {
  ws = new WebSocket(wsUrl);
  ws.onerror = () => { useHttpFallback = true; };
} catch(e) {
  useHttpFallback = true;
}
```

### 5. Backend Go — `auth.go`

JWT opzionale (env `JWT_SECRET`):
- Se `JWT_SECRET` è vuoto → nessuna auth (single-user deployment)
- Se impostato → valida token da header `Authorization: Bearer` o query `?token=`
- Su SOL: auth gestita da nginx `auth_request` verso jwt-gateway, Go non fa auth

Pattern: `/data/massimiliano/Vari/anthropic-api-proxy/main.go`

### 6. Frontend — `static/index.html`

Single-file HTML/CSS/JS (~800-1000 righe, come i viewer esistenti). Componenti:

**Layout**:
- Sidebar sinistra (collassabile): lista sessioni + "New Chat" button
- Area chat centrale: messaggi con rendering Markdown
- Input bottom: textarea auto-resize, Ctrl+Enter o button per inviare

**Rendering pipeline**:
1. Riceve JSONL events (via WS o HTTP stream)
2. Dispatcha su `event.type`:
   - `stream_event` + `content_block_delta` → append `delta.text` al buffer, render incrementale
   - `stream_event` + `content_block_stop` → finalizza blocco
   - `stream_event` + `message_start` → crea nuovo messaggio bubble
   - `assistant` → messaggio completo (redundante, per sicurezza)
   - `result` → mostra costi/token in footer
3. `marked.js` (CDN) per Markdown → HTML
4. `highlight.js` (CDN) per syntax highlighting code blocks
5. Auto-scroll durante streaming (disabilitato se utente ha scrollato su)

**Stile**: dark theme di default, CSS variables per light theme. Responsive (mobile-friendly).

**Session management**:
- `GET /api/sessions` popola sidebar
- Click su sessione → connette WS con `?session=<id>`
- "New Chat" → genera nuovo UUID, connette
- Sessioni persistono su disco (gestite da claude CLI)

**Tab persistence (localStorage)** — risolve il problema originale:
- Ogni tab aperto viene salvato in `localStorage('claude-web-tabs')` come array di `{sessionId, title, openedAt}`
- Al caricamento pagina: legge localStorage → riapre tutti i tab salvati → riconnette ciascuno
- Chiudi/riapri browser → i tab sono ancora lì, con la sessione Claude ripresa
- Tab drag-reorder e close salvano lo stato immediatamente
- Per-browser: ogni device/browser ha il suo layout tab indipendente

### 7. Dockerfile (distribuibile)

```dockerfile
# Stage 1: Build Go binary
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o claude-web .

# Stage 2: Extract claude native binary da npm
FROM node:24-slim AS claude-extract
RUN npm install -g @anthropic-ai/claude-code && \
    cp $(which claude) /claude-binary

# Stage 3: Runtime minimale (glibc per il binary nativo)
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && \
    rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/claude-web /usr/local/bin/claude-web
COPY --from=claude-extract /claude-binary /usr/local/bin/claude
EXPOSE 8100
ENV PORT=8100
ENTRYPOINT ["claude-web"]
```

Note:
- 3 stage: Go build (alpine) → npm install + extract binary (node-slim) → runtime (debian-slim ~80MB + binary ~226MB)
- `debian:bookworm-slim` perché il binary claude è glibc-linked
- `git` necessario perché claude CLI lo usa per context
- Node.js NON presente nel runtime — solo il binary nativo compilato
- **ANTHROPIC_API_KEY** obbligatorio come env var

### 8. Docker Compose (distribuzione)

```yaml
services:
  claude-web:
    build: .
    container_name: claude-web
    restart: unless-stopped
    env_file: .env
    ports:
      - "8100:8100"
    volumes:
      - claude-data:/root/.claude          # sessioni persistenti
      - ${PROJECT_DIR:-.}:/workspace:ro    # codebase da esplorare (opzionale)
    deploy:
      resources:
        limits:
          memory: 512m
    security_opt:
      - no-new-privileges:true
    networks:
      - shared

volumes:
  claude-data:

networks:
  shared:
    external: true
```

### 9. Deploy su SOL — Host process (non Docker)

Su SOL preferiamo host process per accesso diretto a tutto:

File: `~/.config/systemd/user/claude-web.service`

```ini
[Unit]
Description=Claude Web UI
After=network-online.target

[Service]
ExecStart=/data/massimiliano/claude-web/claude-web
WorkingDirectory=/data/massimiliano
Environment=HOME=/home/massimiliano
Environment=PORT=8100
Environment=MAX_SESSIONS=10
Environment=SSH_AUTH_SOCK=/run/user/1000/ssh-agent.sock
Environment=PATH=/data/massimiliano/shell-scripts/bin:/home/massimiliano/.local/bin:/home/massimiliano/.nvm/versions/node/v24.13.1/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EnvironmentFile=/data/massimiliano/claude-web/.env
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

### 10. Nginx route

In `/data/massimiliano/proxy/nginx.conf`, server blocks `:80` e `:8888`:

```nginx
location /claude-web/ {
    set $claude_web http://127.0.0.1:8100;
    rewrite ^/claude-web/(.*) /$1 break;
    proxy_pass $claude_web;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 3600s;
    proxy_buffering off;
    auth_request /check-auth;
}
```

### 11. Sequenza di implementazione

1. `go mod init claude-web` + `go get gorilla/websocket`
2. `claude.go` — spawn, pipe, session management
3. `transport.go` — WebSocket handler + HTTP streaming handler
4. `auth.go` — JWT (opzionale)
5. `main.go` — routes, embed, server
6. `static/index.html` — UI chat completa
7. `go build && ./claude-web` — test locale
8. Systemd service + nginx route
9. Dockerfile — per distribuzione

## File da creare

- `/data/massimiliano/claude-web/main.go`
- `/data/massimiliano/claude-web/auth.go`
- `/data/massimiliano/claude-web/claude.go`
- `/data/massimiliano/claude-web/transport.go`
- `/data/massimiliano/claude-web/static/index.html`
- `/data/massimiliano/claude-web/go.mod`
- `/data/massimiliano/claude-web/.env`
- `/data/massimiliano/claude-web/Dockerfile`
- `/data/massimiliano/claude-web/docker-compose.yml`
- `~/.config/systemd/user/claude-web.service`

## File da modificare

- `/data/massimiliano/proxy/nginx.conf` — aggiungere location `/claude-web/`

## Pattern da riusare

| Pattern | File sorgente |
|---------|---------------|
| Embed static + HTTP server | `/data/massimiliano/knowledge-graph/main.go` |
| JWT auth Go | `/data/massimiliano/Vari/anthropic-api-proxy/main.go` |
| Session management | `/data/massimiliano/Vari/mcp-proxy/main.go` |
| WebSocket + JWT query | `/data/massimiliano/dashboard-api/server.js` |
| Chat UI + Markdown | `/data/massimiliano/proxy/home/index.html` |
| Systemd user service | `~/.config/systemd/user/ttyd.service` |

## Verifica

1. `go build -o claude-web . && PORT=8100 ./claude-web` — compila e parte
2. `curl http://localhost:8100/health` — healthcheck OK
3. Aprire `http://localhost:8100/` — UI si carica
4. Inviare messaggio — streaming response visibile
5. WebSocket: verificare connessione in DevTools Network tab
6. HTTP fallback: bloccare WS upgrade in DevTools → verifica auto-degradazione
7. Chiudere browser, riaprire — sessione nella lista, resume funziona
8. Test nginx: `https://sol.massimilianopili.com/claude-web/`
9. Test mobile: responsive layout
10. `docker build -t claude-web . && docker run -e ANTHROPIC_API_KEY=... -p 8100:8100 claude-web` — verifica distribuzione
