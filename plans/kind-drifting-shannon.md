# Fix healthcheck: self-check nativo per Go scratch containers

## Context

5 servizi Go (scratch) usano `/wget` per healthcheck. 2 sono unhealthy (`proxy-ai`, `preference-sort`) perche' il wget binary manca. Fix: self-healthcheck nativo (shallow — stesso comportamento di prima, senza wget).

## Implementazione (3 modifiche per servizio)

### 1. main.go — aggiungere self-healthcheck flag (5 file)

All'inizio di `main()`, prima di qualsiasi init:

```go
if len(os.Args) > 1 && os.Args[1] == "-health" {
    resp, err := http.Get("http://localhost:PORT/health")
    if err != nil || resp.StatusCode != 200 {
        os.Exit(1)
    }
    os.Exit(0)
}
```

File e porte:
- `/data/massimiliano/Vari/anthropic-api-proxy/main.go` → 8097
- `/data/massimiliano/Vari/preference-sort/main.go` → 8093
- `/data/massimiliano/Vari/jwt-gateway/main.go` → 8094
- `/data/massimiliano/Vari/server-api/main.go` → 8092
- `/data/massimiliano/Vari/mcp-proxy/main.go` → 8098

### 2. docker-compose.yml — cambiare healthcheck (5 file)

`["CMD", "/wget", "-qO-", "http://localhost:PORT/health"]` → `["CMD", "/binary-name", "-health"]`

### 3. Dockerfile — rimuovere busybox stage (5 file)

Rimuovere `FROM busybox:1.36.1-musl AS tools` e `COPY --from=tools /bin/wget /wget`.

### 4. Build + deploy

`sol deploy <svc>` per ciascuno.

## Verifica

1. Tutti e 5 container → `healthy`
2. `sol deploy proxy-ai` → scale trick OK
3. `sol deploy preference-sort` → scale trick OK
