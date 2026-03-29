# Piano: Temperature e Stats sulla Home di SOL

## Context

La dashboard home (`sol.massimilianopili.com`) mostra lo stato dei container via SSE ma non ha metriche host (temperatura CPU, load, RAM, disco, uptime). I dati sono disponibili sull'host via `/sys/class/thermal/` e `/proc/` ma il container server-api (scratch) non vi ha accesso. Prometheus non è attivo — serve una soluzione autocontenuta.

## Approccio: Estendere server-api con bind mount + SSE named event

### 1. `docker-compose.yml` — Aggiungere volumi read-only

**File**: `/data/massimiliano/Vari/server-api/docker-compose.yml`

Aggiungere sotto `volumes`:
```yaml
- /sys/class/thermal:/host/sys/class/thermal:ro
- /proc/loadavg:/host/proc/loadavg:ro
- /proc/meminfo:/host/proc/meminfo:ro
- /proc/uptime:/host/proc/uptime:ro
- /data:/host/data:ro
```

### 2. `main.go` — Aggiungere funzioni per host stats

**File**: `/data/massimiliano/Vari/server-api/main.go`

- Aggiungere `"syscall"` agli import
- Struct `HostStats` (cpu_temp, load_1/5/15, mem_total_mb, mem_used_mb, mem_pct, disk_total_gb, disk_used_gb, disk_pct, uptime_sec)
- Funzione `fetchHostStats()`: legge thermal_zone2 (x86_pkg_temp, fallback zone0), /proc/loadavg, /proc/meminfo (MemTotal - MemAvailable), syscall.Statfs su /host/data, /proc/uptime
- Funzione `fetchHostStatsJSON(ctx, rdb)`: cache Redis key `host_stats` TTL 10s
- Endpoint `GET /host` (pubblico, no auth) — one-shot JSON
- Modificare la closure `send()` nel handler SSE `/status/stream`: dopo il `data:` esistente, emettere `event: host\ndata: {...}\n\n`

### 3. `index.html` — Barra stats sotto il titolo

**File**: `/data/massimiliano/proxy/home/index.html`

**CSS** (dopo `.m-val.mm`, ~riga 54):
- `.sys-bar`: flex row, sfondo `var(--surface)`, bordo rounded, font mono 12px, margine sotto 24px, max-width 1400px
- `.sys-item`, `.sys-icon`, `.sys-label`, `.sys-val` + color classes `.warm` (giallo ≥50°C), `.hot` (rosso ≥70°C), `.ok` (verde)

**HTML** (tra subtitle e `<div class="main-layout">`):
- Barra con 5 item: 🌡 CPU temp, ⚡ Load, 💻 RAM, 💾 Disk, ⏰ Uptime
- Tutti con id `sys-temp`, `sys-load`, `sys-ram`, `sys-disk`, `sys-uptime`

**JS** (dentro il blocco SSE, dopo `evtSource.onerror`):
- `evtSource.addEventListener('host', function(e) {...})`
- Parsa JSON, aggiorna valori, applica classi colore per soglie temp/ram/disk
- Uptime formattato come "Xd Yh Zm"

### 4. Build e Deploy

```bash
cd /data/massimiliano/Vari/server-api && docker compose build && docker compose up -d
cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate
```

### 5. Verifica

- Aprire dashboard → la barra stats appare sotto il titolo con valori live
- `curl http://localhost:8092/host` → JSON con temperatura, load, RAM, disco, uptime
- Verificare aggiornamento ogni 10s via SSE
- Testare su accesso pubblico (Cloudflare) e Tailscale

## File da modificare

| File | Modifica |
|------|----------|
| `Vari/server-api/docker-compose.yml` | +5 volumi ro |
| `Vari/server-api/main.go` | +HostStats struct, +fetchHostStats(), +fetchHostStatsJSON(), +endpoint /host, modifica SSE send() |
| `proxy/home/index.html` | +CSS sys-bar, +HTML barra stats, +JS addEventListener('host') |

## Note

- **Nessuna dipendenza nuova**: syscall è stdlib Go. Nessun modulo esterno.
- **Backward compatible**: SSE named event ignorato da client vecchi. Endpoint /host è additivo.
- **Route nginx**: `/server/host` già coperta dalla location `/server/` esistente → proxy_pass a server-api.
