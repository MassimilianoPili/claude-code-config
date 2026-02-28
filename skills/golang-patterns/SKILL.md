---
name: golang-patterns
description: Go backend patterns for HTTP APIs, JWT/OIDC Keycloak authentication, Docker socket API, Redis caching, Server-Sent Events, WebSocket proxying, embed directives, and containerized deployment with Docker Compose.
allowed-tools: Read, Write, Bash, Edit
category: backend
tags: [golang, go, jwt, oidc, docker-api, redis, sse, http]
version: 1.0.0
---

# Go Backend Patterns — Server SOL

## Overview

Three Go services on the SOL server, each with a different authentication pattern:

- **server-api** (`/data/massimiliano/Vari/server-api/main.go`): Docker container management API, SSE status streaming, Redis caching, JWT Bearer auth. Single file `main.go` (~475 lines).
- **go-filemanager** (`/data/massimiliano/Vari/go-filemanager/`): file browser with native OIDC Keycloak, visitor read-only support, subpath routing. Multi-package structure (`internal/auth`, `internal/config`, `internal/fileops`, `web`).
- **claude-proxy** (`/data/massimiliano/Vari/claude-proxy/main.go`): AI proxy for Claude CLI with JWT auth, SSE streaming, conversation persistence. Single file `main.go` (~706 lines).

All three use Go 1.22+ with `net/http` ServeMux (method+pattern routing), no web frameworks.
`server-api` and `go-filemanager` run in Docker on the `shared` network, reached via nginx reverse proxy by path.
`claude-proxy` runs on the host as a systemd user-level service (`~/.config/systemd/user/claude-proxy.service`), reached by nginx via `host.docker.internal:8090`.

## When to Use

- Creating a new Go HTTP service for the SOL server
- Implementing JWT or OIDC authentication with Keycloak
- Communicating with Docker Engine API via Unix socket
- Implementing SSE streaming or Redis caching
- Containerizing a Go service with Docker Compose on the `shared` network

## Key Pattern 1: Go 1.22+ HTTP Routing (net/http ServeMux)

Nessun framework necessario. Go 1.22 ServeMux supporta metodo+pattern:

```go
mux := http.NewServeMux()
mux.HandleFunc("GET /health", healthHandler)
mux.HandleFunc("POST /containers/{id}/stop", stopHandler)   // path parameter
mux.HandleFunc("GET /api/files/{path...}", fileHandler.List) // wildcard (anche vuoto)
mux.Handle("/", web.StaticHandler(cfg.BasePath))             // catch-all

// Estrarre path parameter nel handler
id := r.PathValue("id")
```

Esempio reale da `go-filemanager/main.go`:
```go
mux.HandleFunc("GET /auth/login", authHandler.Login)
mux.HandleFunc("GET /auth/callback", authHandler.Callback)
mux.HandleFunc("GET /api/files/{path...}", authHandler.RequireAuth(fileHandler.List))
mux.HandleFunc("POST /api/files/{path...}", authHandler.RequireReadWrite(fileHandler.Upload))
mux.HandleFunc("DELETE /api/files/{path...}", authHandler.RequireReadWrite(fileHandler.Delete))
```

**Nota**: `server-api` e `go-filemanager` usano `http.NewServeMux()` (mux dedicato).
`claude-proxy` usa `http.HandleFunc()` (DefaultServeMux) — entrambi gli approcci funzionano.

## Key Pattern 2: JWT Authentication (golang-jwt + keyfunc)

Pattern condiviso da `server-api` e `claude-proxy`. Usa `keyfunc` per auto-refresh JWKS.

```go
import (
    "github.com/MicahParks/keyfunc/v3"
    "github.com/golang-jwt/jwt/v5"
)

var jwtKeyfunc jwt.Keyfunc

// Inizializzazione JWKS con retry (Keycloak potrebbe non essere pronto)
jwksURL := keycloakURL + "/realms/" + realm + "/protocol/openid-connect/certs"
var k keyfunc.Keyfunc
for i := 0; i < 30; i++ {
    k, err = keyfunc.NewDefault([]string{jwksURL})
    if err == nil { break }
    time.Sleep(2 * time.Second)
}
jwtKeyfunc = k.Keyfunc
```

Validazione JWT — da `server-api/main.go` (ritorna `jwt.MapClaims` per leggere resource_access):
```go
func authenticate(r *http.Request, authMode, authToken string) jwt.MapClaims {
    bearer := r.Header.Get("Authorization")
    if !strings.HasPrefix(bearer, "Bearer ") {
        if authMode == "static" && authToken == "" { return jwt.MapClaims{} }
        return nil
    }
    tokenStr := strings.TrimPrefix(bearer, "Bearer ")
    switch authMode {
    case "keycloak":
        token, err := jwt.Parse(tokenStr, jwtKeyfunc, jwt.WithExpirationRequired())
        if err != nil || !token.Valid { return nil }
        if claims, ok := token.Claims.(jwt.MapClaims); ok { return claims }
        return jwt.MapClaims{}
    default:
        if authToken == "" || tokenStr == authToken { return jwt.MapClaims{} }
        return nil
    }
}
```

**Differenza**: `claude-proxy` ritorna `bool` (non serve resource_access), `server-api` ritorna `jwt.MapClaims` per il check read-only.

## Key Pattern 3: Read-Only via resource_access

Da `server-api/main.go` — controlla il ruolo `readonly` nel claim Keycloak:

```go
func isReadOnly(claims jwt.MapClaims) bool {
    ra, ok := claims["resource_access"].(map[string]interface{})
    if !ok { return false }
    for _, clientID := range []string{"server-api", "dashboard-chat"} {
        client, ok := ra[clientID].(map[string]interface{})
        if !ok { continue }
        roles, ok := client["roles"].([]interface{})
        if !ok { continue }
        for _, role := range roles {
            if role == "readonly" { return true }
        }
    }
    return false
}

// Uso: protezione operazioni mutanti
claims := authenticate(r, authMode, authToken)
if claims == nil { jsonError(w, "unauthorized", 401); return }
if isReadOnly(claims) { jsonError(w, "forbidden: read-only user", 403); return }
```

**go-filemanager** usa un approccio diverso: il check avviene nel callback OIDC e viene salvato nella sessione cookie (`Session.ReadOnly`), non controllato ad ogni richiesta dal JWT.

## Key Pattern 4: OIDC Native Auth (go-oidc + oauth2)

Da `go-filemanager/internal/auth/oidc.go` — dual-URL per ambienti Docker:

```go
import (
    "github.com/coreos/go-oidc/v3/oidc"
    "golang.org/x/oauth2"
)

// Interno per discovery/token exchange, esterno per browser redirect
issuerURL := cfg.KeycloakInternalURL + "/realms/" + cfg.KeycloakRealm
ctx := oidc.InsecureIssuerURLContext(context.Background(), issuerURL)
provider, _ := oidc.NewProvider(ctx, issuerURL)

externalAuthURL := cfg.KeycloakExternalURL + "/realms/" + cfg.KeycloakRealm +
    "/protocol/openid-connect/auth"

oauth2Config := &oauth2.Config{
    ClientID: cfg.KeycloakClientID, ClientSecret: cfg.KeycloakClientSecret,
    RedirectURL: cfg.BaseURL + "/auth/callback",
    Scopes:      []string{oidc.ScopeOpenID, "profile", "email"},
    Endpoint: oauth2.Endpoint{
        AuthURL:  externalAuthURL,              // browser
        TokenURL: provider.Endpoint().TokenURL, // server-to-server (Docker interno)
    },
}

verifier := provider.Verifier(&oidc.Config{
    ClientID: cfg.KeycloakClientID, SkipIssuerCheck: true,
})
```

Middleware RequireAuth e RequireReadWrite:
```go
func (h *Handler) RequireReadWrite(next http.HandlerFunc) http.HandlerFunc {
    return requireAuth(h.sessions, func(w http.ResponseWriter, r *http.Request) {
        session := r.Context().Value(sessionContextKey).(*Session)
        if session.ReadOnly {
            http.Error(w, `{"error":"forbidden: read-only user"}`, http.StatusForbidden)
            return
        }
        next.ServeHTTP(w, r)
    })
}
```

CSRF check nel middleware base (da `internal/auth/middleware.go`):
```go
if r.Method != http.MethodGet && r.Method != http.MethodHead {
    if r.Header.Get("Origin") == "" && r.Header.Get("X-Requested-With") == "" {
        http.Error(w, `{"error":"csrf_check_failed"}`, http.StatusForbidden)
        return
    }
}
```

## Key Pattern 5: Docker Engine API via Unix Socket

Da `server-api/main.go`:

```go
var dockerClient = &http.Client{
    Transport: &http.Transport{
        DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
            return (&net.Dialer{}).DialContext(ctx, "unix", "/var/run/docker.sock")
        },
    },
}

func dockerDo(method, path string) (*http.Response, error) {
    req, _ := http.NewRequest(method, "http://localhost"+path, nil)
    return dockerClient.Do(req)
}

// Esempi: dockerDo("GET", "/containers/json?all=1")
//         dockerDo("POST", "/containers/"+id+"/stop")
//         dockerDo("DELETE", "/containers/"+id+"?force=1")
```

Docker log demultiplexing (container non-TTY usano header 8 byte per frame):
```go
func demuxLogs(r io.Reader) []string {
    var lines []string
    hdr := make([]byte, 8)
    for {
        if _, err := io.ReadFull(r, hdr); err != nil { break }
        size := binary.BigEndian.Uint32(hdr[4:8])
        if size == 0 { continue }
        payload := make([]byte, size)
        if _, err := io.ReadFull(r, payload); err != nil { break }
        if line := strings.TrimRight(string(payload), "\n\r"); line != "" {
            lines = append(lines, line)
        }
    }
    return lines
}
```

## Key Pattern 6: Redis Caching (go-redis)

Da `server-api/main.go` — DB 3 (DB 0-2 riservati da Gitea):

```go
rdb := redis.NewClient(&redis.Options{Addr: "redis:6379", DB: 3})

func fetchStatus(ctx context.Context, rdb *redis.Client) ([]byte, error) {
    const cacheKey = "service_status"
    if cached, err := rdb.Get(ctx, cacheKey).Bytes(); err == nil {
        return cached, nil // cache hit
    }
    resp, err := dockerDo("GET", "/containers/json?all=1")
    // ... parsing containers -> status map ...
    out, _ := json.Marshal(status)
    rdb.Set(ctx, cacheKey, out, 10*time.Second)
    return out, nil
}

// Invalidazione dopo operazione mutante
rdb.Del(r.Context(), "service_status")
```

## Key Pattern 7: Server-Sent Events (SSE)

Da `server-api/main.go`:

```go
mux.HandleFunc("GET /status/stream", func(w http.ResponseWriter, r *http.Request) {
    flusher, ok := w.(http.Flusher)
    if !ok { jsonError(w, "streaming not supported", 500); return }

    w.Header().Set("Content-Type", "text/event-stream")
    w.Header().Set("Cache-Control", "no-cache")
    w.Header().Set("Connection", "keep-alive")
    w.Header().Set("X-Accel-Buffering", "no") // disabilita buffering nginx

    ctx := r.Context()
    tick := time.NewTicker(10 * time.Second)
    defer tick.Stop()

    send := func() {
        out, _ := fetchStatus(ctx, rdb)
        fmt.Fprintf(w, "data: %s\n\n", out)
        flusher.Flush()
    }
    send() // primo evento immediato
    for {
        select {
        case <-ctx.Done(): return
        case <-tick.C: send()
        }
    }
})
```

SSE helper riusabile (da `claude-proxy/main.go`):
```go
func sseWrite(w http.ResponseWriter, data string) {
    fmt.Fprintf(w, "data: %s\n\n", data)
    if f, ok := w.(http.Flusher); ok { f.Flush() }
}
```

## Key Pattern 8: Embed Static Files

Singolo file (`server-api`):
```go
//go:embed static/index.html
var indexHTML []byte
```

Directory intera con SPA fallback e subpath injection (`go-filemanager/web/embed.go`):
```go
//go:embed static/*
var staticFiles embed.FS

func StaticHandler(basePath string) http.Handler {
    sub, _ := fs.Sub(staticFiles, "static")
    staticFileServer := http.StripPrefix("/static/", http.FileServer(http.FS(sub)))
    html := string(indexHTML)
    if basePath != "" {
        html = strings.ReplaceAll(html, `href="/static/`, `href="`+basePath+`/static/`)
        html = strings.ReplaceAll(html, `src="/static/`, `src="`+basePath+`/static/`)
        html = strings.Replace(html, "</head>",
            `<meta name="base-path" content="`+basePath+`">`+"\n</head>", 1)
    }
    indexBytes := []byte(html)
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        if strings.HasPrefix(r.URL.Path, "/static/") {
            staticFileServer.ServeHTTP(w, r); return
        }
        w.Header().Set("Content-Type", "text/html; charset=utf-8")
        w.Write(indexBytes) // SPA fallback
    })
}
```

## Key Pattern 9: Docker Compose + Multi-Stage Dockerfile

Compose — servizio interno (solo `expose`, no `ports`), rete `shared` esterna:
```yaml
services:
  server-api:
    build: .
    container_name: server-api
    expose: ["8092"]
    volumes: ["/var/run/docker.sock:/var/run/docker.sock"]
    environment:
      - AUTH_MODE=keycloak
      - KEYCLOAK_URL=http://keycloak:8080/auth
      - KEYCLOAK_REALM=${KEYCLOAK_REALM:-sol}
    restart: unless-stopped
    networks: [shared]
networks:
  shared: { external: true }
```

Dockerfile **scratch** (server-api, claude-proxy — API pure senza filesystem):
```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum main.go ./
COPY static/ static/
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o server-api .

FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app/server-api /server-api
CMD ["/server-api"]
```

Dockerfile **alpine** (go-filemanager — user non-root, volumi dati):
```dockerfile
FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o filemanager .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata && adduser -D -u 1000 appuser
COPY --from=builder /app/filemanager /usr/local/bin/filemanager
USER appuser
ENTRYPOINT ["filemanager"]
```

## Key Pattern 10: Config + Helpers

Configurazione via env vars con fallback + validazione secrets (`go-filemanager/internal/config/config.go`):
```go
func env(key, fallback string) string {
    if v := os.Getenv(key); v != "" { return v }
    return fallback
}
// Fallback per porte/URL, errore per secrets obbligatori
cfg.Port = env("PORT", "9090")
if os.Getenv("KEYCLOAK_CLIENT_SECRET") == "" {
    return nil, fmt.Errorf("KEYCLOAK_CLIENT_SECRET is required")
}
```

JSON error helper e forward Docker response (`server-api/main.go`):
```go
func jsonError(w http.ResponseWriter, msg string, code int) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(code)
    fmt.Fprintf(w, `{"error":%q}`, msg)
}

func forwardOrOK(w http.ResponseWriter, resp *http.Response, id string, successCodes ...int) {
    defer resp.Body.Close()
    for _, code := range successCodes {
        if resp.StatusCode == code {
            fmt.Fprintf(w, `{"ok":true,"id":%q}`, id); return
        }
    }
    w.WriteHeader(resp.StatusCode)
    io.Copy(w, resp.Body)
}
```

Graceful shutdown (`go-filemanager/main.go`): `signal.Notify` + `srv.Shutdown(ctx)` con timeout 10s.

## Dependencies

| Servizio | Go | Dipendenze dirette |
|----------|----|--------------------|
| server-api | 1.22 | `keyfunc/v3`, `golang-jwt/v5`, `go-redis/v9` |
| go-filemanager | 1.23 | `go-oidc/v3`, `oauth2`, `gorilla/securecookie` |
| claude-proxy | 1.22 | `keyfunc/v3`, `golang-jwt/v5` |

## Best Practices

1. **Go 1.22+ ServeMux** con method routing — niente gorilla/mux o chi necessario
2. **Retry JWKS** con backoff (Keycloak parte lentamente in Docker)
3. **`SkipIssuerCheck: true`** quando discovery URL (Docker interna) != token issuer (esterna)
4. **Dual-URL** per OIDC: `KeycloakInternalURL` (token exchange) + `KeycloakExternalURL` (browser)
5. **Redis DB partitioning**: DB 0-2 Gitea, DB 3+ per nuovi servizi
6. **`X-Accel-Buffering: no`** per SSE attraverso nginx
7. **`expose`** (non `ports`) per servizi interni — nginx fa da reverse proxy
8. **Multi-stage build**: builder (golang:alpine) + runtime (scratch o alpine)
9. **`CGO_ENABLED=0 -ldflags="-s -w"`** per binari statici minimali
10. **Invalidare la cache Redis** dopo ogni mutazione (non affidarsi solo al TTL)

## Troubleshooting

- **JWT fails dopo restart Keycloak**: `keyfunc` cacha JWKS. Riavviare il servizio Go.
- **Docker socket permission denied**: montare socket in compose + verificare user container.
- **SSE non streaming via nginx**: servono `proxy_buffering off` nel location block, oppure header `X-Accel-Buffering: no`.
- **Redis connection refused**: verificare che entrambi i container siano sulla rete `shared`.
- **OIDC discovery fallisce**: verificare `KEYCLOAK_INTERNAL_URL` raggiungibile da Docker. Il retry loop gestisce startup lento.
- **Cookie non funziona dietro proxy**: `Secure: true` per HTTPS, `SameSite: Lax`, path `/`.
- **Embed non trova file**: `//go:embed` e' relativa al package, non al modulo.
