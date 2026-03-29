# Piano: Risorse consumate per container nella Server API UI

## Contesto

La UI di gestione Docker (`/server/ui/`) mostra attualmente solo metadati statici per ogni container: nome, immagine, stato, uptime. Manca qualsiasi indicazione sulle risorse consumate (CPU, memoria, rete). L'obiettivo e' aggiungere tre nuove colonne — **CPU%**, **Memory** (con barra visuale), **Net I/O** — usando la Docker Stats API (`/containers/{id}/stats?stream=false`).

## File da modificare

| File | Modifica |
|------|----------|
| `/data/massimiliano/Vari/server-api/main.go` | Nuovo endpoint `GET /stats`, funzioni helper, struct |
| `/data/massimiliano/Vari/server-api/static/index.html` | 3 nuove colonne, fetch parallelo, formattazione |

Nessuna modifica a Dockerfile, docker-compose.yml, go.mod, nginx.conf.

---

## 1. Backend — `main.go`

### 1.1 Aggiungere `"math"` agli import

### 1.2 Nuovo tipo `ContainerStats`

```go
type ContainerStats struct {
    CPUPercent float64 `json:"cpu_percent"`
    MemUsage   uint64  `json:"mem_usage"`
    MemLimit   uint64  `json:"mem_limit"`
    MemPercent float64 `json:"mem_percent"`
    NetRx      uint64  `json:"net_rx"`
    NetTx      uint64  `json:"net_tx"`
}
```

### 1.3 Nuovo helper `dockerDoCtx` (con context per timeout)

L'esistente `dockerDo` non accetta context. Serve una variante context-aware per imporre timeout per-container (3s).

### 1.4 Funzione `computeStats(raw json.RawMessage) ContainerStats`

Parsa il JSON raw di Docker stats e calcola:
- **CPU%**: `(cpu_delta / system_delta) * online_cpus * 100`
- **Memory**: `usage - cache` (se `cache` disponibile), percentuale su `limit`
- **Network**: somma `rx_bytes`/`tx_bytes` di tutte le interfacce

### 1.5 Funzione `fetchAllStats(ctx, rdb) ([]byte, error)`

- Check cache Redis (chiave `container_stats`, TTL 5s)
- Lista container running (`/containers/json` senza `?all=1`)
- Fan-out: 1 goroutine per container, timeout 3s ciascuna (`/containers/{id}/stats?stream=false`)
- Fan-in: raccolta risultati in `map[string]ContainerStats`
- Cache in Redis e return

Container stoppati non vengono interrogati (assenti dalla lista running).

### 1.6 Nuovo endpoint `GET /stats`

- Auth JWT (stesso pattern di `GET /containers`)
- Read-only consentito (stats sono lettura)
- Chiama `fetchAllStats`, ritorna JSON

### 1.7 Invalidazione cache (opzionale)

Aggiungere `rdb.Del(ctx, "container_stats")` negli handler stop/start/restart/remove, accanto all'esistente `rdb.Del(ctx, "service_status")`.

---

## 2. Frontend — `static/index.html`

### 2.1 Nuovi stili CSS

- `.cpu` — testo mono 11px
- `.mem` — testo 11px con barra progressiva inline (50px, 8px altezza)
  - Barra blu (< 70%), gialla (70-90%), rossa (> 90%)
- `.net` — testo mono muted 11px
- `.res-na` — placeholder "-" per container stoppati

### 2.2 Nuove colonne nella tabella

Header: `Name | Image | Status | Uptime | CPU | Memory | Net I/O | Actions`

### 2.3 Nuova variabile di stato

```js
var containerStats = {};
```

### 2.4 `loadContainers()` modificata

Fetch parallelo con `Promise.all`:
```js
var [cResp, sResp] = await Promise.all([
    apiFetch('containers'),
    apiFetch('stats')
]);
```
Se stats fallisce, `containerStats = {}` (graceful degradation — tabella mostra "-").

### 2.5 Helper di formattazione

- `fmtBytes(bytes)` — B / KB / MB / GB
- `memBar(pct)` — HTML barra progressiva con soglie colore

### 2.6 `renderTable()` modificata

Per ogni riga, lookup `containerStats[name]`:
- Container running con stats: mostra CPU%, barra memoria + testo, net I/O
- Container stoppato o stats mancanti: mostra "-"

---

## Performance

| Aspetto | Dettaglio |
|---------|-----------|
| Docker Stats API | ~1-2s per container (one-shot `stream=false`) |
| Parallelismo | Goroutine concorrenti, wall-clock ~2-3s per ~26 container |
| Cache Redis | 5s TTL — prima richiesta lenta, successive istantanee |
| Frontend | `Promise.all` — stats e containers in parallelo |
| Memoria Go | Goroutine short-lived, JSON ~3KB — nessun impatto su limite 128m |

## Casi limite

| Scenario | Comportamento |
|----------|---------------|
| Container stoppato | Assente dalla stats map, frontend mostra "-" |
| Timeout stats singolo container | Zero-value ContainerStats (0% CPU, 0 mem) |
| Container host network (no `networks`) | Somma di mappa vuota = 0 |
| Redis down | Cache miss non fatale, cache write ignorato |
| CPU delta negativo (reset container) | Guard `>= 0` previene percentuali negative |

## Verifica

1. Build e deploy: `cd /data/massimiliano/Vari/server-api && docker compose up -d --build --force-recreate`
2. Testare endpoint: `curl -H "Authorization: Bearer $TOKEN" http://100.86.46.84/server/stats`
3. Verificare UI: `https://sol.massimilianopili.com/server/ui/` — le 3 nuove colonne devono apparire
4. Verificare container stoppato mostra "-"
5. Verificare auto-refresh aggiorna stats ogni 5s
