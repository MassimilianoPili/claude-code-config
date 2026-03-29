# Task #270 — ANANKE Fase 2: Integrare sol-lib-log nei job rimanenti

## Context

ANANKE Fase 1 (completata 2026-03-28) ha deployato `sol-lib-log.sh` e integrato 6 job che ora loggano in `batch-summary.jsonl`. Il pannello dashboard (#280, completato) mostra 25 job totali ma 19 sono "unknown" — non producono ancora log. Task #270 colma questo gap.

**Dall'esplorazione risulta che la situazione reale è diversa dai 19 "unknown":**

### Stato attuale dei job

**Categoria A — GIA' INTEGRATI, solo non ancora eseguiti in questa sessione (6):**
I wrapper esistono e sourcano `sol-lib-log.sh`, ma il timer non è ancora scattato oggi. **Nessun lavoro necessario** — al prossimo run loggeranno automaticamente.

| Job | Timer | Wrapper |
|-----|-------|---------|
| `anki-embed` | 04:15 daily | `shell-scripts/bin/anki-embed` |
| `docker-cleanup` | 04:30 daily | `shell-scripts/bin/docker-cleanup` |
| `infra-graph-sync` | 03:30 daily | `shell-scripts/bin/infra-graph-sync` |
| `llm-batch` | Sun 01:01 | `shell-scripts/bin/llm-batch` |
| `server-snapshot` | 04:01 daily | `shell-scripts/bin/sol-snapshot` |
| `smallweb-enrich` | 02:30 daily | `smallweb-crawl --enrich` |

**Categoria B — PARZIALMENTE INTEGRATI, serve fix (2):**

| Job | Problema |
|-----|----------|
| `kore-health` | ExecStartPost (`kore_accumulation_log.py`) bypassa sol-lib-log |
| `paper-archive-scan` | Usa `paper-archive --scan --quiet` ma il wrapper potrebbe non loggare il sotto-job scan |

**Categoria C — SYSTEM-LEVEL, serve wrapper (1):**

| Job | Problema |
|-----|----------|
| `tailscale-watchdog` | Script system-level `/usr/local/bin/tailscale-watchdog.sh`, no sol-lib-log |

**Categoria D — SOLO NODI AGE, nessun script/timer esiste (9):**
Job registrati nel knowledge graph come `ScheduledJob` ma mai implementati:
`gitea-cleanup-packages`, `gitea-maven-publish`, `nginx-logrotate`, `pg-nginx-cleanup`, `restic-backup`, `scheduled-reindex`, `session-eviction`, `ingest-drain`, `kore-accumulation-log`

---

## Approccio

### Step 1 — Verificare Categoria A (read-only, 5 min)
Confermare che i 6 wrapper Cat A effettivamente sourcano `sol-lib-log.sh` e che `BATCH_JOB_NAME` sia corretto. Nessuna modifica necessaria se confermato.

### Step 2 — Fix Categoria B: `kore-health` (10 min)
**File**: `~/.config/systemd/user/kore-health.service`

Il service ha `ExecStart` (kore-health, già integrato) + `ExecStartPost` (kore_accumulation_log.py, non integrato).

**Fix**: creare wrapper `shell-scripts/bin/kore-accumulation-log` che sourca `sol-lib-log.sh` e chiama `batch_run python3 /data/massimiliano/docs/papers/kore-gc/scripts/kore_accumulation_log.py`. Aggiornare ExecStartPost per usare il wrapper.

### Step 3 — Fix Categoria B: `paper-archive-scan` (5 min)
**File**: `~/.config/systemd/user/paper-archive-scan.service`

Verificare che `paper-archive --scan --quiet` usi sol-lib-log con job name `paper-archive-scan` (non `paper-archive`). Se necessario, settare `BATCH_JOB_NAME=paper-archive-scan` nel service.

### Step 4 — Fix Categoria C: `tailscale-watchdog` (10 min)
**File**: `/usr/local/bin/tailscale-watchdog.sh` (system-level)

Opzione A: aggiungere `source sol-lib-log.sh` direttamente (ma è system-level, no user PATH).
Opzione B: creare timer user-level che wrappa lo script system con sol-lib-log.
**Raccomandazione**: Opzione B — creare `shell-scripts/bin/tailscale-watchdog-log` wrapper, ma lasciare il timer system inalterato. Il wrapper viene invocato come cron/timer user separato per il solo logging, oppure modifichiamo lo script system per appendere al JSONL direttamente.

**Alternativa pragmatica**: aggiungere solo l'append al JSONL in fondo a `tailscale-watchdog.sh` (3 righe bash), senza dipendere da sol-lib-log.

### Step 5 — Categoria D: creare i 9 job mancanti (bulk)
Questi 9 job sono tutti operazioni di manutenzione standard. Per ciascuno:

1. **`restic-backup`** — Backup notturno restic (già documentato in CLAUDE.md).
   Script: `pg_dump` pre-hook + `restic backup` + `restic forget --keep-daily 7 --keep-weekly 4`.
   Timer: 01:00 daily.

2. **`scheduled-reindex`** — Reindex embeddings pgvector.
   Script: chiama MCP tool `embeddings_reindex` via curl o script Python diretto.
   Timer: 04:00 daily.

3. **`nginx-logrotate`** — Rotazione log nginx.
   Script: `docker exec nginx nginx -s reopen` dopo logrotate.
   Timer: 00:00 daily.

4. **`pg-nginx-cleanup`** — Cleanup log PostgreSQL + nginx.
   Script: `VACUUM` + cleanup vecchi log.
   Timer: 03:00 daily.

5. **`gitea-cleanup-packages`** — Pulizia pacchetti obsoleti dal registry Gitea.
   Script: API Gitea per eliminare versioni vecchie.
   Timer: Sun 02:00 weekly.

6. **`gitea-maven-publish`** — Publish nightly di snapshot Maven.
   Script: `mvn deploy` per librerie in sviluppo.
   Timer: 02:00 daily (opzionale, solo se ci sono SNAPSHOT).

7. **`session-eviction`** — Pulizia sessioni Keycloak scadute.
   Script: Keycloak admin API o direct SQL.
   Timer: 03:30 daily.

8. **`ingest-drain`** — Drain coda ingestione (Redis/Artemis).
   Script: processa item in coda, embedda e persisti.
   Timer: ogni 5 min o on-demand.

9. **`kore-accumulation-log`** — Già coperto dal fix Step 2 (ExecStartPost di kore-health).

**Pattern per ogni job**: wrapper in `shell-scripts/bin/`, service + timer in `~/.config/systemd/user/`, `systemctl --user daemon-reload && systemctl --user enable --now {timer}`.

---

## File coinvolti

| File | Azione |
|------|--------|
| `shell-scripts/bin/kore-accumulation-log` | Nuovo wrapper (Step 2) |
| `~/.config/systemd/user/kore-health.service` | Fix ExecStartPost (Step 2) |
| `~/.config/systemd/user/paper-archive-scan.service` | Aggiungere `Environment=BATCH_JOB_NAME=paper-archive-scan` (Step 3) |
| `/usr/local/bin/tailscale-watchdog.sh` | Append JSONL in coda (Step 4) |
| `shell-scripts/bin/restic-backup` | Nuovo wrapper (Step 5) |
| `shell-scripts/bin/scheduled-reindex` | Nuovo wrapper (Step 5) |
| `shell-scripts/bin/nginx-logrotate` | Nuovo wrapper (Step 5) |
| `shell-scripts/bin/pg-nginx-cleanup` | Nuovo wrapper (Step 5) |
| `shell-scripts/bin/gitea-cleanup-packages` | Nuovo wrapper (Step 5) |
| `shell-scripts/bin/gitea-maven-publish` | Nuovo wrapper (Step 5) |
| `shell-scripts/bin/session-eviction` | Nuovo wrapper (Step 5) |
| `shell-scripts/bin/ingest-drain` | Nuovo wrapper (Step 5) |
| `~/.config/systemd/user/*.service` + `*.timer` | 8 nuove coppie (Step 5) |

## Sequenza esecuzione

1. Verificare Cat A (read-only)
2. Fix `kore-accumulation-log` wrapper + service
3. Fix `paper-archive-scan` service env
4. Fix `tailscale-watchdog` logging
5. Creare i 9 nuovi wrapper + timer (batch)
6. `systemctl --user daemon-reload && systemctl --user enable --now` per tutti i nuovi timer
7. Verificare: aspettare un ciclo o trigger manuale, poi controllare `batch-summary.jsonl`

## Verifica

1. `systemctl --user list-timers --all` — tutti i timer attivi
2. Per ogni nuovo job: `systemctl --user start {service}` → verifica riga in `batch-summary.jsonl`
3. Dashboard ANANKE: refresh → tutti i 25 job con pallino verde/giallo (nessun grigio "unknown")
4. `curl ... localhost:7681/metrics/jobs | jq '.summary'` → `unknown: 0`
