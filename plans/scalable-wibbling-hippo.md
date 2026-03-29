# Task DAG UI — Fix Auth Loop

## Context

Il servizio task-ui è deployato e funzionante ma ha un loop OIDC. Causa: il frontend chiama `fetch('api/me')` ma la route Go è `GET /auth/me`. Il SPA fallback serve `index.html` con status 200 → JS interpreta come successo ma il body è HTML → `catch` → `location.href = 'auth/login'` → loop.

## Fix

1. **Frontend** (`/data/massimiliano/task-ui/static/index.html`): cambiare `fetch('api/me')` → `fetch('auth/me')`
2. **Rebuild**: `docker compose up -d --build`

## Verifica

1. Accedere a `https://sol.massimilianopili.com/tasks/` → deve redirectare a Keycloak login
2. Dopo login → deve tornare a `/tasks/` con il DAG visibile
3. No loop — una sola richiesta `auth/me` che ritorna 200 JSON

---

## Context originale

I task Claude (`ag_catalog.claude_tasks` + `claude_task_deps`) hanno un sistema completo (triple-write PG/Redis/PreferenceSort, dipendenze DAG, priority 1-10, status lifecycle) ma nessuna UI visuale. Serve una web app che mostri i task come grafo diretto (DAG) con dipendenze, priorità multi-dimensionali e scadenze, permettendo di riordinare, collegare e modificare task interattivamente tramite drag & drop.

**Incorpora task #273** (task-priority-multidim): evolve `priority` singolo in 4 dimensioni (value, urgency, rank, due_date) con scoring composito.
**Separato da ANANKE**: questa UI gestisce solo la coda `claude_tasks`, non i batch job notturni.

## Modello priorità multi-dimensionale (task #273)

4 dimensioni ortogonali:
- **value** (SMALLINT 1-10, default 5): beneficio/utilità a lungo termine, assegnato da AI
- **urgency** (SMALLINT 1-10, default 5): time-sensitivity, il vecchio `priority` mappa qui
- **rank** (INTEGER nullable): posizione relativa Preference Sort (dall'utente)
- **due_date** (TIMESTAMPTZ nullable): deadline hard

**Scoring composito** (calcolato lato server, colonna generata o view):
```
score = w1*value + w2*rank_normalized + w3*urgency + deadline_boost
```
- `w1=0.3, w2=0.3, w3=0.4` (default, configurabili via env)
- `rank_normalized` = se rank null → 0.5, altrimenti `1 - (rank / max_rank)` (normalizzato 0-1)
- `deadline_boost` = se due_date null → 0, altrimenti `max(0, 10 * e^(-days_remaining/3))` (esponenziale, +10 quando scade oggi)

**Retrocompatibilità**: il campo `priority` esistente viene mappato a `urgency` nella migration. I MCP tool `claude_task_enqueue/list` accettano i nuovi parametri come opzionali.

## Architettura

Nuovo servizio `task-ui`: Go + D3.js + dagre, pattern identico a `knowledge-graph/` e `embedding-viz/`.

```
/data/massimiliano/task-ui/
├── main.go              # HTTP server, routes, //go:embed static, SSE hub, PG LISTEN
├── auth.go              # Copia da knowledge-graph/auth.go (cookie: tu_session)
├── tasks.go             # CRUD SQL su ag_catalog.claude_tasks + claude_task_deps + scoring
├── static/
│   └── index.html       # SPA: D3.js + dagre DAG, dark theme, 3 pannelli
├── Dockerfile           # Multi-stage golang:1.25-alpine → scratch
├── docker-compose.yml   # shared network, env_file, 128m
├── .env                 # PG + Keycloak + SESSION_KEY + PORT=8101 + SCORE_WEIGHTS
└── go.mod
```

**Porta**: 8101 (8097 occupata da proxy-ai)
**Nginx**: `/tasks/` su server blocks :80 e :8888 (prefix-stripping, OIDC nativa)

## Step 1 — Database migration

Eseguiti dal Go binary allo startup (tutti idempotenti):

```sql
-- Nuove colonne multi-dimensionali
ALTER TABLE ag_catalog.claude_tasks ADD COLUMN IF NOT EXISTS value SMALLINT DEFAULT 5;
ALTER TABLE ag_catalog.claude_tasks ADD COLUMN IF NOT EXISTS urgency SMALLINT DEFAULT 5;
ALTER TABLE ag_catalog.claude_tasks ADD COLUMN IF NOT EXISTS due_date TIMESTAMPTZ;

-- Migrazione dati: priority → urgency (solo la prima volta)
UPDATE ag_catalog.claude_tasks SET urgency = priority WHERE urgency = 5 AND priority != 5;

-- Trigger LISTEN/NOTIFY per SSE realtime
CREATE OR REPLACE FUNCTION ag_catalog.notify_task_change() RETURNS trigger AS $$
BEGIN
    PERFORM pg_notify('task_changes', json_build_object(
        'action', TG_OP, 'task_id', COALESCE(NEW.task_id, OLD.task_id))::text);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS task_change_trigger ON ag_catalog.claude_tasks;
CREATE TRIGGER task_change_trigger
AFTER INSERT OR UPDATE OR DELETE ON ag_catalog.claude_tasks
FOR EACH ROW EXECUTE FUNCTION ag_catalog.notify_task_change();
```

**Nota**: `rank` non è una colonna — viene dal `rank_item_uuid` già esistente, letto da Preference Sort API (:8093) a runtime.

## Step 2 — Keycloak client

Creare client `task-ui` nel realm `sol`:
- Protocol: openid-connect, Access Type: confidential
- Redirect URIs: `https://sol.massimilianopili.com/tasks/auth/callback`, `http://100.86.46.84/tasks/auth/callback`
- Web Origins: `https://sol.massimilianopili.com`, `http://100.86.46.84`

## Step 3 — Go backend

### `auth.go`
Copia da `/data/massimiliano/knowledge-graph/auth.go`, cambiare:
- Cookie names: `tu_session`, `tu_state`, `tu_nonce`
- Client ID default: `task-ui`
- BASE_URL default: `https://sol.massimilianopili.com/tasks`

### `main.go`
Pattern da knowledge-graph: embed static, SPA fallback, security headers, graceful shutdown.

**Route**:
| Method | Path | Auth | Scopo |
|--------|------|------|-------|
| GET | `/health` | No | Health check |
| GET | `/auth/login,callback,logout` | No | OIDC flow |
| GET | `/auth/me` | Sì | User info |
| GET | `/api/tasks` | Sì | Lista task con score calcolato (filtri: status, type, minScore) |
| GET | `/api/tasks/{id}` | Sì | Task singolo + deps + dependents + rank da PreferenceSort |
| POST | `/api/tasks` | Sì | Crea task (value, urgency, due_date, ref, type, payload) |
| PATCH | `/api/tasks/{id}` | Sì | Aggiorna (value, urgency, due_date, status, payload) |
| DELETE | `/api/tasks/{id}` | Sì | Elimina (cascade deps) |
| POST | `/api/deps` | Sì | Crea arco dipendenza |
| DELETE | `/api/deps` | Sì | Rimuovi arco |
| GET | `/api/stats` | Sì | Conteggi per status + score distribution |
| GET | `/api/events` | Sì | SSE stream (PG LISTEN/NOTIFY) |

### `tasks.go`

**Scoring engine** (Go-side, non SQL view — per flessibilità pesi):
```go
type ScoredTask struct {
    Task
    Score       float64   // composito calcolato
    RankNorm    float64   // da Preference Sort API
    DeadBost    float64   // deadline boost
}

func (h *TaskHandler) computeScore(t *Task, rankNorm float64) float64 {
    deadlineBoost := 0.0
    if t.DueDate != nil {
        days := time.Until(*t.DueDate).Hours() / 24
        if days < 30 { deadlineBoost = math.Max(0, 10*math.Exp(-days/3)) }
    }
    return h.w1*float64(t.Value) + h.w2*rankNorm + h.w3*float64(t.Urgency) + deadlineBoost
}
```

**Preference Sort integration**: `GET http://preference-sort:8093/lists/{uuid}/ranking` per ottenere rank BT. Cached 60s in-memory. Fallback: rank_normalized = 0.5 se PreferenceSort down.

**Altre responsabilità**:
- SQL plain su `ag_catalog.claude_tasks` e `claude_task_deps` (NO Cypher)
- **Cycle detection**: CTE ricorsivo prima di creare archi → 409 Conflict
- **SSE Hub**: goroutine background con `pgx` LISTEN `task_changes`, fan-out via channel
- **ReadOnly enforcement**: visitor/readonly → solo GET

### `go.mod`
```
require (
    github.com/coreos/go-oidc/v3
    github.com/gorilla/securecookie
    github.com/jackc/pgx/v5       # per LISTEN/NOTIFY nativo
    golang.org/x/oauth2
)
```

## Step 4 — Frontend (`static/index.html`)

### Layout 3 pannelli
```
┌──────────────────────────────────────────────────────────────────┐
│ Topbar: "Task DAG" │ [Pointer|Urgency|Connect] │ Search │ User  │
├──────────────┬───────────────────────┬───────────────────────────┤
│ Left (260px) │ Center (flex)         │ Right (340px)             │
│              │                       │                           │
│ Filtri:      │   DAG dagre layout    │ Task #273                 │
│  □ PENDING   │   top-to-bottom       │ ref: task-priority-multi  │
│  □ CLAIMED   │                       │ type: code                │
│  □ COMPLETED │   Nodi = task         │ status: [PENDING ▼]       │
│  □ FAILED    │   Archi = dipendenze  │                           │
│  □ BLOCKED   │                       │ ── Priorità ──            │
│              │   Y-position = score  │ Value:   [====----] 6/10  │
│ Sort by:     │   Colore = status     │ Urgency: [========] 9/10  │
│  ○ Score     │   Bordo = urgency     │ Score:   8.7 (calcolato)  │
│  ○ Due date  │   Spessore = value    │                           │
│  ○ Created   │                       │ Due date: [2026-04-05]    │
│              │   [zoom/fit/reset]    │ ⏰ 8 giorni rimanenti     │
│ Task list    │                       │                           │
│ (per score)  │                       │ ── Payload ──             │
│              │                       │ {json editor}             │
│ [+ Nuovo]    │                       │                           │
│              │                       │ Deps: #238, #54           │
│              │                       │ Blocked by: #238          │
│              │                       │                           │
│              │                       │ [Save] [Delete]           │
└──────────────┴───────────────────────┴───────────────────────────┘
```

### CDN (zero build process)
- D3.js v7
- dagre 1.1.4 (~15KB, layout algorithm — NO dagre-d3)

### DAG rendering
- dagre computa posizioni (x,y) con `rankdir: 'TB'`, nodi ordinati per score decrescente
- D3 renderizza: `<rect>` rounded per nodi, `<path>` cubic bezier con frecce per archi
- **Colore fill** = status (`--pending: #6c8cff`, `--claimed: #ffd43b`, `--completed: #51cf66`, `--failed: #ff6b6b`, `--blocked: #cc5de8`)
- **Bordo sinistro 4px** = urgency color (gradiente rosso P1 → viola P10)
- **Spessore bordo** = value (1px per value=1, 3px per value=10)
- **Opacity 0.4** per COMPLETED/CANCELLED (de-emphasize)
- **Bordo tratteggiato** per BLOCKED
- **Pulse animation** per due_date scaduta
- **Badge score** in alto a destra nel nodo (es. "8.7")

### Contenuto nodo DAG
Ogni nodo mostra:
```
┌─[urgency color bar]─────────────────┐
│ 📋 task-priority-multidim    [8.7]  │
│ code · PENDING        ⏰ 8d        │
└─────────────────────────────────────┘
```
- Riga 1: ref (troncato 25 char) + badge score
- Riga 2: type + status + deadline indicator (se presente)

### 3 modalità interazione (toggle toolbar)
1. **Pointer** (default): click nodo → detail panel, pan/zoom canvas
2. **Urgency**: drag verticale → cambia urgency (zone Y con strisce 1-10), drop → PATCH urgency
3. **Connect**: drag da handle inferiore nodo A → nodo B → crea arco (POST /api/deps). Click arco → elimina

### Detail panel — Priorità multi-dimensionale
- **Value** slider 1-10 con label "Beneficio lungo termine"
- **Urgency** slider 1-10 con label "Time-sensitivity"
- **Score** read-only, calcolato (evidenziato con colore: verde >7, giallo 4-7, rosso <4)
- **Rank** read-only, da Preference Sort (con link a `rank-tui` per votare)
- **Due date** date picker (nullable, bottone "×" per rimuovere)

### Deadline indicators (nel nodo e nel detail)
- Nessuna: nessun indicatore
- \>7 giorni: `⏰` grigio
- 3-7 giorni: `⏰` giallo
- 1-3 giorni: `⏰` arancione con pulse leggero
- <24h: `⏰` rosso con pulse
- Scaduta: `🔴` rosso con glow sul nodo

### Radar chart on hover (mini)

Quando il mouse resta su un nodo DAG per >300ms, appare un **tooltip radar chart** SVG (120×120px) sovrapposto al canvas.

**Radar 1 — Profilo Riassuntivo** (dimensioni attuali, sempre visibile):
- 4 assi: Value, Urgency, Score (normalizzato 0-10), Deadline proximity (0=nessuna, 10=scade oggi)
- Poligono filled con colore status (opacity 0.3) + stroke
- Ogni asse ha label abbreviata (V, U, S, D)
- L'area del poligono dà il colpo d'occhio sulla "pressione" del task

```
        U(9)
       / \
      /   \
 V(6)·     ·S(8.7)
      \   /
       \ /
        D(3)
```

**Radar 2 — Punti di Forza** (futuro, predisposto ma non attivo al lancio):
- Assi: da definire quando emergeranno pattern ricorrenti (es. complexity, impact, effort, risk, learning)
- Dati salvati in `payload_json` campo `"dimensions"` (JSON object arbitrario)
- La UI rileva automaticamente le chiavi presenti in `dimensions` e genera il radar
- Se `dimensions` è assente o vuoto → Radar 2 non compare

**Implementazione D3.js** (~60 righe):
- Funzione `drawRadar(container, axes, values, opts)` riutilizzabile
- `axes`: array di `{key, label, max}`
- `values`: oggetto `{key: number}`
- SVG con `<polygon>` per griglia + `<polygon>` per dati + `<text>` per label
- Posizionato come tooltip floating (follow mouse, offset 15px)

**Evoluzione futura**: quando si aggiungono dimensioni, basta:
1. Aggiungere campo/i al DB o al `payload_json.dimensions`
2. Aggiungere l'asse alla configurazione del radar (frontend)
3. Il rendering è automatico (N assi qualsiasi)

### Form "Nuovo Task"
Modal o inline nel sidebar:
- ref (text, required)
- type (dropdown: ops, code, project, research, security, bug, feature)
- value (slider 1-10, default 5)
- urgency (slider 1-10, default 5)
- due_date (date picker, nullable)
- payload (JSON textarea)
- depends_on (multi-select da task esistenti)

### Realtime (SSE)
- `EventSource('/api/events')` — su ogni evento, fetch del task aggiornato, D3 transition 300ms

### CSS
Stesse variabili del dashboard (`--bg: #0f1117`, `--surface`, `--accent`, etc.) + variabili status e priority.

## Step 5 — Docker

### Dockerfile
Multi-stage `golang:1.25-alpine` → `scratch` (pattern knowledge-graph). CGO_ENABLED=0, ca-certificates.

### docker-compose.yml
```yaml
services:
  task-ui:
    build: .
    restart: unless-stopped
    env_file: .env
    expose: ["8101"]
    deploy:
      resources:
        limits:
          memory: 128m
    security_opt: [no-new-privileges:true]
    networks:
      shared:
        aliases: [task-ui]
networks:
  shared:
    external: true
```

### .env
```
PG_HOST=postgres
PG_PORT=5432
PG_DB=embeddings
PG_USER=postgres
PG_PASSWORD=<da postgres/.env>
KEYCLOAK_INTERNAL_URL=http://keycloak:8080/auth
KEYCLOAK_EXTERNAL_URL=https://sol.massimilianopili.com/auth
KEYCLOAK_REALM=sol
KEYCLOAK_CLIENT_ID=task-ui
KEYCLOAK_CLIENT_CREDENTIAL=<generare in Keycloak>
SESSION_KEY=<openssl rand -hex 32>
BASE_URL=https://sol.massimilianopili.com/tasks
PORT=8101
PREFSORT_URL=http://preference-sort:8093
PREFSORT_LIST_CATEGORY=task-queue
SCORE_W1=0.3
SCORE_W2=0.3
SCORE_W3=0.4
```

## Step 6 — Nginx

Aggiungere a server blocks `:80` e `:8888` in `/data/massimiliano/proxy/nginx.conf`:

```nginx
# SSE (prima del generico, timeout esteso)
location /tasks/api/events {
    set $taskui http://task-ui:8101;
    rewrite ^/tasks/(.*) /$1 break;
    proxy_pass $taskui;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 3600s;
    proxy_buffering off;
    proxy_cache off;
}
# Task UI (OIDC nativa, prefix-stripping)
location = /tasks { return 301 /tasks/; }
location /tasks/ {
    set $taskui http://task-ui:8101;
    rewrite ^/tasks/(.*) /$1 break;
    proxy_pass $taskui;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

## Step 7 — Registrazione sol

Aggiornare `/data/massimiliano/shell-scripts/bin/sol-lib.sh`:
- `SERVICE_DIR[task-ui]="/data/massimiliano/task-ui"`
- BOOT_ORDER: dopo `knowledge-graph`
- NGINX_DEPS: aggiungere `task-ui`

## Step 8 — Dashboard link

Aggiungere card "Task DAG" al dashboard (`/data/massimiliano/proxy/home/index.html`) nella sezione servizi.

## Step 9 — MCP tool update

Aggiornare `claude_task_enqueue` in `/data/massimiliano/Vari/mcp/src/main/java/com/example/mcp/tools/ClaudeTaskQueueTools.java`:
- Nuovi parametri opzionali: `value` (int 1-10), `urgency` (int 1-10), `dueDate` (string ISO)
- `priority` param esistente mappa a `urgency` per retrocompatibilità
- INSERT include nuove colonne

Aggiornare `claude_task_list`:
- Mostrare score calcolato nella lista
- Nuovo status filter `OVERDUE` (due_date < now AND status IN (PENDING, CLAIMED))

## Ordine di implementazione

1. **DB migration** (ALTER TABLE + trigger) — Step 1
2. **Keycloak client** `task-ui` — Step 2
3. **Go backend** (auth.go → main.go → tasks.go con scoring) — Step 3
4. **Frontend** (static/index.html con DAG + multi-dim priority) — Step 4
5. **Docker** (Dockerfile + docker-compose.yml + .env) — Step 5
6. **Nginx** (route /tasks/) — Step 6
7. **sol registration** (sol-lib.sh) — Step 7
8. **Dashboard link** — Step 8
9. **MCP tool update** (claude_task_enqueue/list con value/urgency/dueDate) — Step 9
10. **Deploy**: `sol deploy task-ui` + `sol deploy mcp` + `sol restart proxy`
11. **Chiudere task #273** via `claude_task_complete`

## File critici da leggere/copiare

- `/data/massimiliano/knowledge-graph/auth.go` — template auth OIDC (copia + adatta)
- `/data/massimiliano/knowledge-graph/main.go` — pattern server Go
- `/data/massimiliano/knowledge-graph/static/index.html` — pattern D3.js SPA
- `/data/massimiliano/knowledge-graph/Dockerfile` — pattern multi-stage
- `/data/massimiliano/knowledge-graph/docker-compose.yml` — pattern compose
- `/data/massimiliano/proxy/nginx.conf` — dove aggiungere route
- `/data/massimiliano/shell-scripts/bin/sol-lib.sh` — registrazione servizio
- `/data/massimiliano/Vari/mcp/src/main/java/com/example/mcp/tools/ClaudeTaskQueueTools.java` — MCP tool da aggiornare
- `/data/massimiliano/Vari/mcp/src/main/java/com/example/mcp/tools/ClaudeTaskQueueConfig.java` — config datasource

## Verifica

1. `docker compose up -d` in `/data/massimiliano/task-ui/`
2. Health: `curl http://task-ui:8101/health`
3. Tailscale: `http://100.86.46.84/tasks/` → OIDC login → DAG
4. Pubblico: `https://sol.massimilianopili.com/tasks/`
5. Creare task dalla UI con value=8, urgency=3, due_date=+5d → verificare score calcolato
6. Drag urgency → verificare PATCH + score ricalcolato + riposizionamento nodo
7. Creare dipendenza con drag → verificare arco + cycle detection (409 per cicli)
8. SSE: aprire 2 tab, modificare in tab 1 → update animato in tab 2
9. MCP: `claude_task_enqueue` con `urgency=9, value=7, dueDate="2026-04-01"` → appare in UI live
10. Retrocompatibilità: `claude_task_enqueue` con solo `priority=3` → urgency=3, value=5 default
