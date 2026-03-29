# Aggiungere metriche Claude Code alla dashboard metrics

## Context
La pagina `/metrics/#tokens` interroga tabelle (`token_ledger`, `chat_sessions`, `tool_outcomes`) che non esistono nel DB `embeddings` — sono nel DB dell'Agent Framework. Risultato: tutti i grafici mostrano `--`. I dati di token usage di Claude Code esistono nei file JSONL in `/data/massimiliano/claude-shared/projects/-data-massimiliano/*.jsonl` — ogni messaggio assistant contiene un oggetto `usage` con `input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`, `model`.

## Approccio
Aggiungere un endpoint `/metrics/claude` nel `server.js` che legge i JSONL e aggrega i dati. Aggiornare la pagina metrics per mostrarli nel tab "Tokens" (o un tab dedicato "Claude").

### Dati disponibili nei JSONL
```json
{
  "message": {
    "model": "claude-opus-4-6",
    "usage": {
      "input_tokens": 3,
      "cache_creation_input_tokens": 17772,
      "cache_read_input_tokens": 28305,
      "output_tokens": 9
    }
  },
  "sessionId": "...",
  "timestamp": "2026-03-17T..."
}
```

### Pricing (per 1M tokens, Opus)
- Input (no cache): $15
- Output: $75
- Cache read: $1.5
- Cache write: $18.75

### Step 1: Nuovo endpoint `GET /metrics/claude` nel server.js
Parametri: `range` (1h, 6h, 24h, 7d, 30d)

Scansiona i JSONL, filtra per range, ritorna:
```json
{
  "cost_trend": { "labels": ["2026-03-14", ...], "data": [1313.65, ...] },
  "cost_by_model": [{ "model": "claude-opus-4-6", "cost": 3887.20 }],
  "token_distribution": [{ "t": "2026-03-14", "input": ..., "output": ..., "cache_read": ..., "cache_write": ... }],
  "session_ranking": [{ "session_id": "...", "label": "...", "cost": ..., "messages": ... }],
  "summary": { "total_cost": 3887.20, "total_input": ..., "total_output": ..., "sessions": 42, "messages": 15645 }
}
```

**Caching**: i JSONL sono ~509 file. Scandirli tutti ad ogni request è costoso. Usare una cache in-memoria con TTL 60s.

### Step 2: Aggiornare pagina metrics
- Rinominare tab "Tokens" → "Claude Tokens" (dato che token_ledger è vuoto)
- `renderTokens()` chiama `/metrics/claude` invece di `/metrics/tokens`
- Riusare i grafici esistenti (Cost Trend, Cost by Model, Token Distribution, Session Cost Ranking)
- Rimuovere Budget Gauges (non ci sono budget per Claude Code) e Cost by Agent (non rilevante)

### Step 3: Aggiornare KPI strip nella home
- `summary.today_cost` → dai dati Claude
- Endpoint `/metrics/summary` → fallback su dati Claude se token_ledger è vuoto

### File da modificare
1. `/data/massimiliano/dashboard-api/server.js` — nuovo endpoint `/metrics/claude`
2. `/data/massimiliano/proxy/home/metrics/index.html` — tab Tokens usa dati Claude
3. `/data/massimiliano/proxy/home/index.html` — KPI strip (summary)

### Verifica
- `curl http://localhost:7681/metrics/claude?range=7d` → dati aggregati
- Dashboard home → Today Cost mostra valore reale
- `/metrics/#tokens` → grafici con dati Claude Code
