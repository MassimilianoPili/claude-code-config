# Piano: Fase 5 — Metrics Visualization (Custom UI, NO Grafana)

## Contesto

Fase 1-4 completate. 5 tabelle PG in `embeddings` DB contengono tutte le metriche dell'Agent Framework:
- `tool_outcomes` (Fase 1-2): success/failure, latency, recovery
- `metacognition_decisions` (Fase 3): GP agent selection, quality scores, embeddings
- `token_ledger` + `token_budgets` (Fase 4): token consumption, cost, budget
- `chat_sessions` (hook): session tracking

Nessuna UI le visualizza. Grafana rifiutato ("pesante per nulla"). **Un'unica UI custom** con KPI summary + analytics approfonditi, servita come pagina statica da nginx + API da dashboard-api.

## Architettura

```
Browser → nginx (:8888/:80)
  ├─ /metrics/        → static HTML (proxy/home/metrics/index.html)
  │                      Chart.js 4 (CDN), Catppuccin theme, 3 tab
  ├─ /api/metrics/*   → dashboard-api (:7681) → PG embeddings
  └─ /                → index.html (+ KPI widget strip)
```

Pattern identico a `/agent/` e `/rank-app/`: SPA statica + API JWT.
Nessun container nuovo. Nessuna dipendenza Docker aggiuntiva.

## A) API Layer — dashboard-api

### A1: `npm install pg`

**File**: `/data/massimiliano/dashboard-api/package.json` — add `"pg": "^8.13.0"`

### A2: PG Pool + 6 endpoint in server.js

**File**: `/data/massimiliano/dashboard-api/server.js`

**In cima** (dopo require ws/jose):
```javascript
const { Pool } = require('pg');
const pgPool = new Pool({
  host: '127.0.0.1', port: 5432, database: 'embeddings',
  user: 'postgres', password: process.env.PG_PASSWORD,
  max: 2, idleTimeoutMillis: 60000,
});
```

**6 route** (tutte GET, JWT-protette, visitor readonly OK):

| Endpoint | Tabelle | Ritorna |
|----------|---------|---------|
| `GET /metrics/summary` | tutte | KPI: today cost, 24h tool health %, top agent quality, budget % |
| `GET /metrics/tools?range=24h` | `tool_outcomes` | success rate/h, top 10 tool, latency p50/p95, ultimi failure, recovery stats |
| `GET /metrics/tokens?range=7d&groupBy=day` | `token_ledger`, `token_budgets` | cost trend, cost by model (pie), cost by agent, token distribution, budget gauge, session ranking |
| `GET /metrics/agents?range=7d` | `metacognition_decisions`, `token_ledger` | quality per agent, quality-per-dollar, GP σ² trend, prediction accuracy, training points |
| `GET /metrics/sessions?limit=20` | `chat_sessions` JOIN `token_ledger` | sessioni recenti con costo totale, durata, tool count |
| `GET /metrics/drilldown?table=tools&id=X` | dipende | dettaglio singolo tool/agent/session |

**Query param `range`**: `1h`, `6h`, `24h`, `7d`, `30d`. Default `24h`. Tradotto in `created_at > NOW() - INTERVAL '...'`.

**Pattern implementativo** (inserire prima del 404 handler, dopo il guard JWT):
```javascript
// Metrics routing
if (url.startsWith('/metrics/')) {
  const sub = url.split('?')[0].replace('/metrics/', '');
  const params = new URL(req.url, 'http://x').searchParams;
  // ... switch su sub → query PG → res JSON
}
```

Ogni endpoint fa 1-4 query parallele con `Promise.all()` e ritorna JSON strutturato.

### A3: PG_PASSWORD in systemd

**File**: `~/.config/systemd/user/dashboard-api.service` — aggiungere `Environment=PG_PASSWORD=...`

### A4: Query SQL chiave

**`/metrics/summary`** (4 query parallele):
```sql
-- today cost
SELECT COALESCE(SUM(cost_usd), 0) as today_cost
FROM token_ledger WHERE created_at >= CURRENT_DATE;

-- 24h tool health
SELECT COUNT(*) FILTER (WHERE success) * 100.0 / NULLIF(COUNT(*), 0) as health_pct
FROM tool_outcomes WHERE created_at > NOW() - INTERVAL '24h';

-- top agent quality (media pesata ultimi 7d)
SELECT AVG(outcome_quality) as avg_quality
FROM metacognition_decisions WHERE outcome_quality IS NOT NULL
AND created_at > NOW() - INTERVAL '7d';

-- budget usage (max ratio across active budgets)
SELECT MAX(used_pct) as max_budget_pct FROM (
  SELECT b.budget_key, b.max_cost_usd,
    COALESCE(SUM(t.cost_usd), 0) / b.max_cost_usd * 100 as used_pct
  FROM token_budgets b
  LEFT JOIN token_ledger t ON (
    CASE b.period
      WHEN 'daily' THEN t.created_at >= CURRENT_DATE
      WHEN 'weekly' THEN t.created_at >= DATE_TRUNC('week', NOW())
      WHEN 'monthly' THEN t.created_at >= DATE_TRUNC('month', NOW())
      WHEN 'session' THEN t.session_id = SPLIT_PART(b.budget_key, ':', 2)
    END
  )
  WHERE b.active = TRUE GROUP BY b.budget_key, b.max_cost_usd
) sub;
```

**`/metrics/tools`** (5 query):
```sql
-- 1. Success rate nel tempo (per chart time series)
SELECT DATE_TRUNC('hour', created_at) as t,
  COUNT(*) FILTER (WHERE success) * 100.0 / COUNT(*) as rate
FROM tool_outcomes WHERE created_at > NOW() - INTERVAL $range
GROUP BY t ORDER BY t;

-- 2. Top 10 tool per invocazioni
SELECT tool_name, COUNT(*) as calls,
  COUNT(*) FILTER (WHERE success) * 100.0 / COUNT(*) as success_pct
FROM tool_outcomes WHERE created_at > NOW() - INTERVAL $range
GROUP BY tool_name ORDER BY calls DESC LIMIT 10;

-- 3. Latency p50/p95 per tool
SELECT tool_name,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY latency_ms) as p50,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY latency_ms) as p95
FROM tool_outcomes WHERE created_at > NOW() - INTERVAL $range AND latency_ms IS NOT NULL
GROUP BY tool_name ORDER BY p95 DESC LIMIT 15;

-- 4. Ultimi 20 failure
SELECT tool_name, error_class, error_message, recovery_tool, created_at
FROM tool_outcomes WHERE success = FALSE
ORDER BY created_at DESC LIMIT 20;

-- 5. Recovery effectiveness
SELECT AVG(recovery_time_ms) as avg_recovery,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY recovery_time_ms) as p95_recovery,
  COUNT(*) FILTER (WHERE recovery_tool IS NOT NULL) as recovered,
  COUNT(*) FILTER (WHERE NOT success) as total_failures
FROM tool_outcomes WHERE created_at > NOW() - INTERVAL $range;
```

**`/metrics/tokens`** (6 query):
```sql
-- 1. Cost trend (time series, groupBy day/hour)
SELECT DATE_TRUNC($groupBy, created_at) as t, SUM(cost_usd) as cost
FROM token_ledger WHERE created_at > NOW() - INTERVAL $range
GROUP BY t ORDER BY t;

-- 2. Cost by model (pie)
SELECT model, SUM(cost_usd) as cost FROM token_ledger
WHERE created_at > NOW() - INTERVAL $range GROUP BY model ORDER BY cost DESC;

-- 3. Cost by agent (bar)
SELECT scope_name, SUM(cost_usd) as cost FROM token_ledger
WHERE scope = 'agent' AND created_at > NOW() - INTERVAL $range
GROUP BY scope_name ORDER BY cost DESC LIMIT 10;

-- 4. Token distribution (stacked bar per giorno)
SELECT DATE_TRUNC('day', created_at) as t,
  SUM(input_tokens) as input, SUM(output_tokens) as output,
  SUM(cache_read_tokens) as cache_read, SUM(cache_write_tokens) as cache_write
FROM token_ledger WHERE created_at > NOW() - INTERVAL $range GROUP BY t ORDER BY t;

-- 5. Budget utilization (gauge)
SELECT b.budget_key, b.max_cost_usd, b.period,
  COALESCE(SUM(t.cost_usd), 0) as used, COALESCE(SUM(t.cost_usd), 0) / b.max_cost_usd * 100 as pct
FROM token_budgets b LEFT JOIN token_ledger t ON (...)
WHERE b.active = TRUE GROUP BY b.budget_key, b.max_cost_usd, b.period;

-- 6. Session cost ranking
SELECT t.session_id, COALESCE(c.title, t.session_id) as label,
  SUM(t.cost_usd) as cost, COUNT(*) as entries
FROM token_ledger t LEFT JOIN chat_sessions c ON t.session_id = c.session_id
WHERE t.created_at > NOW() - INTERVAL $range
GROUP BY t.session_id, c.title ORDER BY cost DESC LIMIT 20;
```

**`/metrics/agents`** (5 query):
```sql
-- 1. Quality per agent (bar)
SELECT actual_agent, AVG(outcome_quality) as avg_q, COUNT(*) as n
FROM metacognition_decisions WHERE outcome_quality IS NOT NULL
AND created_at > NOW() - INTERVAL $range
GROUP BY actual_agent ORDER BY avg_q DESC;

-- 2. Quality-per-dollar (bar, JOIN token_ledger)
SELECT m.actual_agent,
  AVG(m.outcome_quality) as avg_q,
  SUM(t.cost_usd) as total_cost,
  AVG(m.outcome_quality) / NULLIF(SUM(t.cost_usd), 0) as q_per_dollar
FROM metacognition_decisions m
JOIN token_ledger t ON m.session_id = t.session_id AND t.scope = 'agent' AND t.scope_name = m.actual_agent
WHERE m.outcome_quality IS NOT NULL AND m.created_at > NOW() - INTERVAL $range
GROUP BY m.actual_agent;

-- 3. GP uncertainty trend (time series)
SELECT DATE_TRUNC('hour', created_at) as t, AVG(gp_sigma2) as sigma2
FROM metacognition_decisions WHERE gp_sigma2 IS NOT NULL
AND created_at > NOW() - INTERVAL $range GROUP BY t ORDER BY t;

-- 4. Prediction accuracy
SELECT COUNT(*) FILTER (WHERE recommended_agent = actual_agent) * 100.0 / NULLIF(COUNT(*), 0) as accuracy,
  COUNT(*) as total
FROM metacognition_decisions WHERE created_at > NOW() - INTERVAL $range;

-- 5. Training points per agent
SELECT actual_agent, COUNT(*) as points
FROM metacognition_decisions WHERE outcome_quality IS NOT NULL
GROUP BY actual_agent ORDER BY points DESC;
```

## B) UI — Pagina `/metrics/`

### B1: File `proxy/home/metrics/index.html`

**Nuova directory**: `/data/massimiliano/proxy/home/metrics/`

SPA single-file (~500 righe HTML/CSS/JS). Stile Catppuccin Mocha (coerente con dashboard e agent/).

**Struttura pagina**:
```
┌─────────────────────────────────────────────────────┐
│ header: "Agent Metrics" + range selector + auto-refresh │
├─────────────────────────────────────────────────────┤
│ KPI strip: 4 card (cost, health, quality, budget)    │
├──────────┬──────────┬───────────────────────────────┤
│ Tab: 🔧  │ Tab: 💰  │ Tab: 🧠                       │
│ Tools    │ Tokens   │ Agents                        │
├──────────┴──────────┴───────────────────────────────┤
│                                                     │
│  Chart area (cambia per tab attivo):                │
│  - Time series (Chart.js line)                      │
│  - Bar charts / Pie charts                          │
│  - Table (failure log, session ranking)             │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Dipendenze CDN** (zero build step):
```html
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/chart.umd.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns@3/dist/chartjs-adapter-date-fns.bundle.min.js"></script>
```

**3 tab, contenuto per tab**:

#### Tab "Tools" (da `/metrics/tools`):
1. **Success Rate Over Time** — line chart, ore sull'asse X, % sull'asse Y
2. **Top 10 Tools** — horizontal bar chart (calls count, colore = success %)
3. **Latency p50/p95** — tabella ordinabile
4. **Recent Failures** — tabella scrollabile (tool, error_class, message, recovery, tempo)
5. **Recovery Stats** — 3 stat card (avg recovery ms, p95, recovered/total)

#### Tab "Tokens" (da `/metrics/tokens`):
1. **Daily Cost Trend** — line chart con area fill
2. **Cost by Model** — doughnut chart (Opus vs Sonnet vs other)
3. **Cost by Agent** — horizontal bar
4. **Token Distribution** — stacked bar (input/output/cache_read/cache_write per giorno)
5. **Budget Utilization** — gauge-like div (barra con threshold 80%/100%, colore condizionale)
6. **Session Cost Ranking** — tabella (session title, cost, entries)

#### Tab "Agents" (da `/metrics/agents`):
1. **Quality per Agent** — bar chart
2. **Quality-per-Dollar** — bar chart (dual axis: quality + $/call)
3. **GP Uncertainty Trend** — line chart (σ² nel tempo, alta = esplora, bassa = exploit)
4. **Prediction Accuracy** — stat grande (XX% con colore)
5. **Training Points** — bar chart per agent (quanto dati di training ha ciascuno)

**Range selector**: dropdown `1h | 6h | 24h | 7d | 30d`. Cambia `range` param in tutte le fetch.
**Auto-refresh**: toggle, 60s interval. Badge "live" verde quando attivo.
**Auth**: JWT da localStorage (`sol_token`). Se assente, mostra solo messaggio "Login required". Visitor OK.

### B2: Nginx location block

**File**: `/data/massimiliano/proxy/nginx.conf`

Aggiungere dentro server block `:8888` (pubblico) e `:80` (Tailscale), dopo le location `/agent/` esistenti:
```nginx
location /metrics/ {
    alias /usr/share/nginx/home/metrics/;
    index index.html;
}
```

Volume già montato: `./home:/usr/share/nginx/home:ro`.

## C) KPI Widget nella Dashboard Home

### C1: Widget in index.html

**File**: `/data/massimiliano/proxy/home/index.html`

**Inserzione**: dopo la barra access/visitor, prima della chat-section (~riga 710).

Strip orizzontale con 4 mini-card:
- **Today's Cost** (`$X.XX`) — link a `/metrics/#tokens`
- **Tool Health** (`XX%`) — verde ≥95%, giallo ≥80%, rosso <80% — link a `/metrics/#tools`
- **Agent Quality** (`0.XXX`) — link a `/metrics/#agents`
- **Budget** (`XX%`) — verde <80%, giallo <100%, rosso ≥100% — link a `/metrics/#tokens`

JS: `fetch('/api/metrics/summary')` ogni 60s. Widget hidden se non autenticato. ~40 righe CSS + ~30 righe JS.

## File da creare/modificare

| File | Azione |
|------|--------|
| `dashboard-api/package.json` | +dep `pg` |
| `dashboard-api/server.js` | +PG Pool, +6 route `/metrics/*` |
| `~/.config/systemd/user/dashboard-api.service` | +`Environment=PG_PASSWORD=...` |
| `proxy/home/metrics/index.html` | **Nuovo** — SPA completa (~500 righe) |
| `proxy/nginx.conf` | +location `/metrics/` (2 server block) |
| `proxy/home/index.html` | +KPI widget strip (~70 righe HTML/CSS/JS) |

## Implementazione step-by-step

1. `npm install pg` in dashboard-api/
2. Edit `server.js`: PG Pool + 6 endpoint `/metrics/*`
3. Edit systemd unit: `PG_PASSWORD`
4. `systemctl --user daemon-reload && systemctl --user restart dashboard-api`
5. `curl http://localhost:7681/metrics/summary` → verifica JSON
6. Creare `proxy/home/metrics/index.html` (SPA Chart.js)
7. Edit `nginx.conf`: +location `/metrics/` (entrambi i server block)
8. Edit `proxy/home/index.html`: +KPI widget strip
9. `cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate`

## Verifica

1. `curl -H "Authorization: Bearer $TOKEN" http://localhost:7681/metrics/summary` → JSON con 4 KPI
2. `curl -H "..." http://localhost:7681/metrics/tools?range=24h` → JSON tool health
3. `curl -H "..." http://localhost:7681/metrics/tokens?range=7d&groupBy=day` → JSON token data
4. `curl -H "..." http://localhost:7681/metrics/agents?range=7d` → JSON agent quality
5. Browser `/metrics/` → pagina carica, 3 tab funzionanti con Chart.js
6. Tab Tools → time series success rate, top 10 bar, failure table
7. Tab Tokens → cost trend line, model doughnut, budget gauge
8. Tab Agents → quality bar, q-per-dollar, GP σ² trend
9. Range selector → cambia `range`, chart si aggiornano
10. Dashboard home `/` → KPI strip visibile dopo login, 4 valori linkati a `/metrics/`
11. Visitor → tutto visibile read-only
12. No auth → KPI strip e `/metrics/` nascosti
