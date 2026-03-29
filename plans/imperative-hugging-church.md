# Ottimizzazione dashboard metrics: pre-aggregazione in PostgreSQL

## Context

Il tab Claude della dashboard (`/metrics/#claude`) scansiona **372 file JSONL sincroni** (~82K messaggi) ad ogni richiesta — troppo lento, specialmente con range 30d. I dati dei giorni passati sono immutabili, quindi vanno pre-aggregati in PostgreSQL e scansionati da JSONL solo per il giorno corrente.

## Piano

### 1. Creare tabella `claude_daily_stats` su PostgreSQL

```sql
CREATE TABLE IF NOT EXISTS claude_daily_stats (
    day DATE NOT NULL,
    model TEXT NOT NULL,
    input_tokens BIGINT DEFAULT 0,
    output_tokens BIGINT DEFAULT 0,
    cache_read_tokens BIGINT DEFAULT 0,
    cache_write_tokens BIGINT DEFAULT 0,
    cost_usd NUMERIC(12,6) DEFAULT 0,
    messages INTEGER DEFAULT 0,
    PRIMARY KEY (day, model)
);

CREATE TABLE IF NOT EXISTS claude_session_stats (
    day DATE NOT NULL,
    session_id TEXT NOT NULL,
    slug TEXT,
    model TEXT,
    cost_usd NUMERIC(12,6) DEFAULT 0,
    messages INTEGER DEFAULT 0,
    PRIMARY KEY (day, session_id)
);
```

Aggiungere anche queste tabelle a `04-monitoring.sh`.

### 2. Script di backfill: aggregare i JSONL storici → PostgreSQL

Script one-shot Python o Node che:
1. Scansiona tutti i .jsonl nella dir projects
2. Aggrega per (day, model) e per (day, session_id)
3. Inserisce in `claude_daily_stats` e `claude_session_stats` con `ON CONFLICT DO NOTHING` (idempotente)
4. Salta il giorno corrente (quello viene calcolato live)

### 3. Modificare `scanClaudeJsonl()` in server.js

Nuova logica (asincrona):
1. **Giorni passati**: `SELECT * FROM claude_daily_stats WHERE day >= $cutoff AND day < CURRENT_DATE`
2. **Giorno corrente**: scansione JSONL solo dei file modificati oggi (`fs.statSync(fp).mtimeMs > todayStart`)
3. Merge dei risultati
4. Cache 5min come prima

Questo riduce la scansione da 372 file a ~10-20 file (quelli toccati oggi).

### 4. Cron/timer per aggregazione giornaliera

Aggiungere alla fine di `backup-sol.sh` (o timer separato alle 00:05) uno script che:
- Aggrega il giorno precedente da JSONL → `claude_daily_stats` + `claude_session_stats`
- Idempotente con `ON CONFLICT UPDATE`

### 5. Verifica

```bash
# Tabella popolata
docker exec postgres psql -U postgres -d embeddings -c "SELECT day, sum(cost_usd), sum(messages) FROM claude_daily_stats GROUP BY day ORDER BY day;"

# Dashboard veloce
curl -s -w '\nTempo: %{time_total}s\n' http://localhost:7681/metrics/claude?range=30d -H "Authorization: Bearer $TOKEN"
```

## File coinvolti

- `/data/massimiliano/dashboard-api/server.js` — refactor `scanClaudeJsonl()` → hybrid DB+JSONL
- `/data/massimiliano/postgres/init/04-monitoring.sh` — aggiungere `claude_daily_stats` + `claude_session_stats`
- Script backfill one-shot (inline in server.js o script separato)
