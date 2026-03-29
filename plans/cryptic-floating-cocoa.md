# Piano: Aggiungere Logging a Tutti i Batch Notturni

## Context

I batch job girano come timer systemd user-level sull'host. Tutti scrivono su stdout/stderr → journalctl, ma:
1. Da code-server (container) non si accede a journalctl
2. Non esiste una directory centralizzata per i log batch
3. Quando un job fallisce, l'unico modo per verificare è SSH sull'host + journalctl

L'obiettivo è avere **log persistenti su filesystem** in `/data/massimiliano/logs/batch/` (visibili da qualsiasi contesto: host, container, MCP).

## Approccio: Wrapper con tee + logrotate

Modificare i **wrapper script** in `/data/massimiliano/shell-scripts/bin/` per aggiungere logging a file tramite `tee`, mantenendo anche l'output su stdout (per journalctl). Aggiungere un logrotate automatico.

### Job da coprire (15 batch)

| Wrapper script | Log file | Frequenza |
|---------------|----------|-----------|
| `smallweb-crawl` | `smallweb-crawl.log` | ogni minuto |
| `paper-archive` | `paper-archive.log` | ogni 6h |
| `docs-sync` | `docs-sync.log` | ogni 30min |
| `wiki-embargo` | `wiki-embargo.log` | ogni 15min |
| `wiki-obsidian` | `wiki-obsidian.log` | ogni 5min |
| `claude-cleanup` | `claude-cleanup.log` | ogni 30min |
| `sol-snapshot` | `sol-snapshot.log` | 04:00 daily |
| `kore-health` | `kore-health.log` | Sun 04:00 |
| `openalex-download` | `openalex-download.log` | manuale |
| `openalex-import` | `openalex-import.log` | manuale |
| `openalex-embed` | `openalex-embed.log` | manuale |
| `deploy-mcp` | `deploy-mcp.log` | manuale/CI |

Job non-wrapper (gestiti diversamente):
- `infra-graph-sync` → ExecStart diretto a python3, va aggiunto redirect nel .service
- `anki-embed` → ExecStart diretto, idem
- `llm-batch` → ExecStart diretto, idem
- `docker-cleanup` → shell inline, idem
- `smallweb-enrich` → usa `smallweb-crawl --enrich`, coperto dal wrapper
- `ingest-drain` → verificare ExecStart
- `scheduled-reindex` → Spring @Scheduled interno al MCP, log in mcp-server.log (già coperto)

### Implementazione

#### 1. Creare directory log

```bash
mkdir -p /data/massimiliano/logs/batch
```

#### 2. Creare `sol-lib-log.sh` — funzione di logging riusabile

File: `/data/massimiliano/shell-scripts/bin/sol-lib-log.sh` (sourced dai wrapper)

```bash
# sol-lib-log.sh — Batch logging helper
# Usage: source sol-lib-log.sh; batch_log_init "job-name"
BATCH_LOG_DIR="/data/massimiliano/logs/batch"

batch_log_init() {
    local name="$1"
    local logfile="$BATCH_LOG_DIR/${name}.log"
    local max_size="${2:-5242880}"  # 5MB default

    # Rotate if too large
    if [[ -f "$logfile" ]] && [[ $(stat -c%s "$logfile" 2>/dev/null || echo 0) -gt $max_size ]]; then
        mv "$logfile" "$logfile.1"
        gzip -f "$logfile.1" 2>/dev/null &
    fi

    # Redirect stdout+stderr through tee (append)
    exec > >(tee -a "$logfile") 2>&1
    echo "--- $(date -Iseconds) --- $name START ---"
}

batch_log_end() {
    echo "--- $(date -Iseconds) --- ${1:-batch} END (exit=$?) ---"
}
```

#### 3. Modificare ogni wrapper script

Pattern (esempio `smallweb-crawl`):

```bash
#!/bin/bash
# smallweb-crawl — ...
source "$(dirname "$0")/sol-lib-log.sh"
batch_log_init "smallweb-crawl"
# ... resto invariato ...
exec /data/massimiliano/smallweb/.venv/bin/python3 ...
```

**Nota**: con `exec` alla fine, il processo sostituisce la shell, quindi `tee` cattura tutto. Per i job ad alta frequenza (smallweb-crawl ogni minuto), il log ruoterà automaticamente a 5MB.

Per `smallweb-crawl` specificamente: dato che gira ogni minuto, usare un max_size di 2MB e log compatto (no timestamp ripetuti nel wrapper, li aggiunge già lo script Python).

#### 4. Service unit per job senza wrapper

Per `infra-graph-sync`, `anki-embed`, `llm-batch`: modificare i `.service` aggiungendo:
```ini
StandardOutput=append:/data/massimiliano/logs/batch/<name>.log
StandardError=append:/data/massimiliano/logs/batch/<name>.log
```
Questo richiede accesso SSH sull'host (systemd unit files in `~/.config/systemd/user/`).

#### 5. Logrotate timer (opzionale ma consigliato)

Aggiungere un timer `batch-logrotate` o incorporare nel `docker-cleanup` esistente:
```bash
# Ruota log > 10MB, mantieni 3 rotazioni compresse
find /data/massimiliano/logs/batch/ -name "*.log" -size +10M -exec bash -c '
    mv "$1" "$1.1" && gzip -f "$1.1"
' _ {} \;
# Elimina rotazioni > 7 giorni
find /data/massimiliano/logs/batch/ -name "*.log.*.gz" -mtime +7 -delete
```

### File da creare/modificare

| File | Azione |
|------|--------|
| `/data/massimiliano/logs/batch/` | Creare directory |
| `/data/massimiliano/shell-scripts/bin/sol-lib-log.sh` | Creare (funzione logging) |
| `/data/massimiliano/shell-scripts/bin/smallweb-crawl` | Aggiungere `source` + `batch_log_init` |
| `/data/massimiliano/shell-scripts/bin/paper-archive` | Idem |
| `/data/massimiliano/shell-scripts/bin/docs-sync` | Idem |
| `/data/massimiliano/shell-scripts/bin/wiki-embargo` | Idem |
| `/data/massimiliano/shell-scripts/bin/wiki-obsidian` | Idem |
| `/data/massimiliano/shell-scripts/bin/claude-cleanup` | Idem |
| `/data/massimiliano/shell-scripts/bin/sol-snapshot` | Idem |
| `/data/massimiliano/shell-scripts/bin/kore-health` | Idem |
| `/data/massimiliano/shell-scripts/bin/openalex-download` | Idem |
| `/data/massimiliano/shell-scripts/bin/openalex-import` | Idem |
| `/data/massimiliano/shell-scripts/bin/openalex-embed` | Idem |
| `/data/massimiliano/shell-scripts/bin/deploy-mcp` | Idem |
| `~/.config/systemd/user/infra-graph-sync.service` | Aggiungere StandardOutput/Error (via SSH) |
| `~/.config/systemd/user/anki-embed.service` | Idem |
| `~/.config/systemd/user/llm-batch.service` | Idem |

### Verifica

1. `ls -la /data/massimiliano/logs/batch/` — file presenti e in crescita
2. `tail /data/massimiliano/logs/batch/smallweb-crawl.log` — log recente (aggiornato ogni minuto)
3. `tail /data/massimiliano/logs/batch/wiki-embargo.log` — log recente (ogni 15min)
4. Dopo 1 giorno: verificare che la rotation funzioni (nessun file > 10MB)
5. Verificare che journalctl continui a ricevere l'output (tee manda a entrambi)

### Note

- **SSH agent**: va riavviato prima di modificare i .service (`systemctl --user start ssh-agent`)
- I service unit sull'host non sono accessibili dal container — le modifiche ai .service vanno fatte via SSH o direttamente sull'host
- Il `scheduled-reindex` è un @Scheduled Spring → log già in `mcp-server.log`, non serve file separato

---

## Fase 2: Metriche + UI Dashboard per Job Inesorabili

### Context

23 ScheduledJob registrati in AGE, ma nessuna visibilità centralizzata. La dashboard home (`index.html`) ha già:
- SSE service cards (20+ servizi con status dot verde/rosso)
- Metriche KPI strip (costo, tool health, agent quality, budget)
- Endpoint `/metrics/*` nel dashboard-api (`server.js`, porta 7681)

Serve un **pannello "Batch Jobs"** che mostri tutti i job, ultimo run, stato, e trend di crescita KORE.

### Approccio: Nuovo endpoint + pannello dashboard

#### 1. Nuovo endpoint `/metrics/jobs` in dashboard-api

File: `/data/massimiliano/dashboard-api/server.js`

Dati da aggregare:
- **Smallweb crawl**: leggere `/data/massimiliano/smallweb/.smallweb_checkpoint.json` (next_index, total_posts, cycle, ultimo timestamp)
- **Embeddings**: query MCP `embeddings_stats` o query diretta PG `SELECT count(*), max(updated_at) FROM embeddings GROUP BY type`
- **AGE node count**: `SELECT * FROM cypher('knowledge_graph', $$ MATCH (n) RETURN count(n) $$)`
- **AGE BlogPost oggi**: `MATCH (b:BlogPost) WHERE b.crawled_at > '<today>' RETURN count(b)`
- **Log files**: `stat` su ogni file in `/data/massimiliano/logs/batch/` → ultimo modified, dimensione
- **ScheduledJob list**: query AGE per tutti i nodi ScheduledJob

Formato risposta:
```json
{
  "jobs": [
    {
      "name": "smallweb-crawl",
      "schedule": "every minute",
      "last_run": "2026-03-25T06:29:03Z",
      "status": "ok",
      "metrics": { "feeds_processed": 1333, "posts_today": 3885, "total_posts": 29090 }
    },
    ...
  ],
  "kore": {
    "total_nodes": 81567,
    "blogposts_today": 3885,
    "embeddings_total": 475612,
    "embeddings_indexing": true
  }
}
```

#### 2. Pannello nella dashboard home

File: `/data/massimiliano/proxy/home/index.html`

Posizione: **nuovo section nella left panel**, sotto i service cards, prima del footer. Oppure come tab aggiuntivo nel right panel.

Layout compatto:
```
┌─ Batch Jobs ────────────────────────────┐
│ ● smallweb-crawl    06:29  +3885 posts  │
│ ● embeddings-reindex  ⟳    475K chunks  │
│ ● infra-graph-sync  03:30  81K nodes    │
│ ● paper-archive     00:30  105 papers   │
│ ○ anki-embed        04:15  17K notes    │
│ ○ wiki-obsidian     06:25  411 files    │
│ ...                                      │
│ KORE: 81.5K nodes │ 475K embeddings     │
└─────────────────────────────────────────┘
```

- `●` verde = ultimo run < 2× schedule interval (healthy)
- `○` grigio = non ancora eseguito oggi / prossimo schedulato
- `●` rosso = ultimo run > 3× schedule interval (stale/fallito)
- Refresh: ogni 30 secondi via fetch

#### 3. Alternativa leggera: Solo log tail + checkpoint read

Se il dashboard-api è troppo da estendere, approccio minimale:
- Aggiungere un **endpoint statico** che serve i file `.log` e `.checkpoint.json` via nginx
- Il frontend legge direttamente i JSON e fa il rendering client-side
- Nessun backend nuovo, solo nginx location + JS

### File da creare/modificare (Fase 2)

| File | Azione |
|------|--------|
| `/data/massimiliano/dashboard-api/server.js` | Aggiungere endpoint `/metrics/jobs` |
| `/data/massimiliano/proxy/home/index.html` | Aggiungere pannello Batch Jobs |
| `/data/massimiliano/proxy/nginx.conf` | (opzionale) location per log files statici |

### Verifica (Fase 2)

1. `curl http://localhost:7681/metrics/jobs` — JSON con tutti i job e metriche
2. Dashboard `https://sol.massimilianopili.com/` — pannello Batch Jobs visibile con dati live
3. Dopo 1h: verificare che i timestamp si aggiornino e i colori riflettano lo stato reale
