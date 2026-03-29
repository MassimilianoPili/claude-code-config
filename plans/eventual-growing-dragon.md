# Preference Sort API (`/rank/`)

## Contesto

Servizio per ordinare liste tramite confronti a coppie (pairwise comparisons), ispirato a:
- **Gwern Resorter** (https://gwern.net/resorter) — modello Bradley-Terry per inferire ranking da confronti rumorosi
- **Taguchi Orthogonal Arrays** — scheduling bilanciato per minimizzare i confronti necessari

**Problema**: ordinare N item per preferenza soggettiva richiede O(N^2) confronti con approccio esaustivo. Il modello Bradley-Terry + selezione adattiva riduce a ~N·log2(N) confronti per ottenere un ranking stabile.

**Uso previsto**: todo list, film da vedere, film visti, libri — qualsiasi lista ordinabile per preferenza personale.

**Prerequisito completato**: JWT Auth Gateway (`jwt-gateway:8094`) gia' deployato e configurato in nginx. Sara' il primo consumer reale del gateway.

---

## Architettura

```
Browser/Client
    │ Bearer JWT
    ▼
  nginx (:80/:8888)
    │
    ├── auth_request /internal/jwt/validate → jwt-gateway:8094
    │     ↓ Keycloak JWKS
    │     200 + X-Auth-User + X-Auth-User-Id + X-Auth-Readonly
    │     (oppure 401/403)
    │
    ├── location /rank/ (strip prefix, proxy_pass)
    │
    ▼
  preference-sort:8093
    │ riceve solo X-Auth-* headers (nessun JWT)
    │
    ▼
  PostgreSQL (database: preference_sort)
```

Il servizio **non** contiene logica JWT — riceve user identity e permessi dagli header X-Auth-* iniettati da nginx dopo la validazione del gateway.

---

## Directory

```
/data/massimiliano/Vari/preference-sort/
├── main.go           # Server setup, routes, middleware, helpers
├── db.go             # PostgreSQL connection pool, migrations, query helpers
├── models.go         # Struct: List, Item, Comparison, ScheduleEntry, RankEntry
├── handlers.go       # HTTP handlers per tutti gli endpoint REST
├── bt.go             # Bradley-Terry MM algorithm + Standard Error
├── scheduler.go      # Pair selection: balanced schedule + adaptive + convergence
├── Dockerfile        # Multi-stage scratch (pattern server-api)
├── docker-compose.yml
└── migrations/
    └── 001_initial.sql
```

---

## Algoritmo Bradley-Terry

### Modello

Ogni item `i` ha un parametro di forza `π_i > 0`. La probabilita' che `i` batta `j`:

```
P(i > j) = π_i / (π_i + π_j)
```

### MM Algorithm (Minorization-Maximization)

Stima iterativa dei parametri:

```
π_i^(new) = W_i / Σ_j [ n_ij / (π_i^(old) + π_j^(old)) ]

dove:
  W_i    = vittorie totali di i (tie = 0.5 per lato)
  n_ij   = confronti totali tra i e j
```

Convergenza quando `max |π_i^(new) - π_i^(old)| < ε` (ε = 1e-6, max 100 iterazioni).

### Standard Error

```
SE(π_i) ≈ π_i / √(I_ii)

dove I_ii = Σ_j [ n_ij / (π_i + π_j)^2 ]  (informazione di Fisher)
```

SE alto → item poco confrontato o risultati incoerenti → candidato per la prossima coppia.

### Selezione coppie (3 fasi)

1. **Schedule bilanciato** (fase iniziale):
   - Round-robin: genera `ceil(N * log2(N))` coppie dove ogni item appare ~uniformemente
   - Ispirato ai Taguchi Orthogonal Arrays: bilanciamento uniforme, non confronti esaustivi
   - `GET /next` restituisce la prossima coppia non completata dallo schedule

2. **Selezione adattiva** (schedule completato):
   - Ricalcola BT dopo ogni confronto
   - Seleziona l'item con SE piu' alto
   - Lo accoppia col vicino piu' incerto nel ranking (alta SE tra gli adiacenti)
   - Ogni 3 query adattive: 1 coppia random (previene fixpoint locali)

3. **Convergenza**:
   - Tutti gli SE < soglia (default 0.3) → `GET /next` restituisce `204 No Content`
   - L'utente puo' continuare a chiedere confronti forzando `?force=true`

### Cold start

Items con `initial_rating` opzionale nel POST. Se fornito:
- `π_i` inizializzato proporzionalmente al rating
- Genera confronti seed: coppie tra item adiacenti nel ranking iniziale (verifica l'ordinamento iniziale)

---

## Endpoints REST

Tutti gli endpoint (tranne `/health`) richiedono JWT via nginx → jwt-gateway.
Il servizio legge `X-Auth-User-Id` (UUID stabile) come owner delle liste.

| Metodo | Path | Descrizione | Readonly |
|--------|------|-------------|----------|
| `GET` | `/health` | Health check (senza auth, location nginx separata) | - |
| `POST` | `/lists` | Crea lista (name, category) | NO |
| `GET` | `/lists` | Liste dell'utente (paginazione ?limit=&offset=) | SI |
| `GET` | `/lists/{id}` | Lista con items e ranking corrente | SI |
| `DELETE` | `/lists/{id}` | Elimina lista + items + comparisons (CASCADE) | NO |
| `POST` | `/lists/{id}/items` | Aggiungi items (batch JSON array) | NO |
| `DELETE` | `/lists/{id}/items/{itemId}` | Rimuovi item (ricalcola ranking) | NO |
| `PATCH` | `/lists/{id}/items/{itemId}` | Aggiorna nome/metadata | NO |
| `GET` | `/lists/{id}/next` | Prossima coppia da confrontare | SI |
| `POST` | `/lists/{id}/comparisons` | Invia risultato confronto | NO |
| `GET` | `/lists/{id}/ranking` | Ranking completo (score, SE, rank) | SI |
| `GET` | `/lists/{id}/stats` | Statistiche (confronti, copertura, fase) | SI |
| `POST` | `/lists/{id}/import` | Import items con rating iniziali | NO |

**Nota readonly**: il gateway blocca POST/PUT/DELETE/PATCH per utenti readonly. Il servizio non ha bisogno di controllare — le mutazioni non arrivano mai.

### Payload esempi

**POST /lists**:
```json
{"name": "Film da vedere", "category": "movies"}
```

**POST /lists/{id}/items** (batch):
```json
{"items": [
  {"name": "The Shawshank Redemption"},
  {"name": "Pulp Fiction", "metadata": {"year": 1994}},
  {"name": "Inception", "initial_rating": 8.5}
]}
```

**POST /lists/{id}/comparisons**:
```json
{"item_a_id": "uuid-a", "item_b_id": "uuid-b", "result": 1, "response_time_ms": 2300}
```
`result`: 1 = A vince, -1 = B vince, 0 = pareggio

**GET /lists/{id}/next** → 200:
```json
{"item_a": {"id": "uuid-a", "name": "Film A"}, "item_b": {"id": "uuid-b", "name": "Film B"}, "phase": "adaptive", "progress": {"completed": 15, "estimated_total": 23}}
```

**GET /lists/{id}/ranking** → 200:
```json
{"items": [
  {"id": "uuid", "name": "Film A", "rank": 1, "score": 2.45, "se": 0.12, "wins": 8, "losses": 2, "ties": 0},
  ...
], "converged": true}
```

---

## Schema PostgreSQL

Database: `preference_sort` (nuovo, da creare sul container postgres esistente)

```sql
-- migrations/001_initial.sql

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT '',
    se_threshold DOUBLE PRECISION NOT NULL DEFAULT 0.3,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_lists_user_id ON lists(user_id);

CREATE TABLE items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    list_id UUID NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}',
    bt_score DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    bt_se DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    rank INTEGER NOT NULL DEFAULT 0,
    wins INTEGER NOT NULL DEFAULT 0,
    losses INTEGER NOT NULL DEFAULT 0,
    ties INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_items_list_id ON items(list_id);

CREATE TABLE comparisons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    list_id UUID NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
    item_a_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    item_b_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    result SMALLINT NOT NULL CHECK (result IN (-1, 0, 1)),
    phase TEXT NOT NULL DEFAULT 'scheduled',
    response_time_ms INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_comparisons_list_id ON comparisons(list_id);

CREATE TABLE schedule (
    id SERIAL PRIMARY KEY,
    list_id UUID NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
    item_a_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    item_b_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    round INTEGER NOT NULL DEFAULT 0,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_schedule_pending ON schedule(list_id) WHERE NOT completed;
```

---

## File Go — Struttura

### main.go (~100 righe)

```go
// Setup:
// 1. Env vars: PORT, DATABASE_URL
// 2. InitDB(databaseURL) — connessione + migrazioni
// 3. Go 1.22 mux con routes
// 4. Middleware: extractAuth (legge X-Auth-* headers)
// 5. Middleware: requireOwner (verifica list.user_id == auth user)

func extractAuth(r *http.Request) (userID, username string) {
    // Legge X-Auth-User-Id e X-Auth-User dagli header
    // Nessuna validazione JWT — gia' fatta dal gateway
}

func requireOwner(listID, userID string) error {
    // Verifica che la lista appartenga all'utente
    // 404 se non trovata, 403 se owner diverso
}
```

### db.go (~80 righe)

```go
// 1. pgxpool.New(ctx, databaseURL) — connection pool
// 2. RunMigrations() — esegue migrations/*.sql in ordine
// 3. Query helpers con context e pool
```

**Dipendenza**: `github.com/jackc/pgx/v5/pgxpool` — driver PostgreSQL nativo Go, connection pooling incluso.

### models.go (~60 righe)

```go
type List struct { ID, UserID, Name, Category, SEThreshold, CreatedAt, UpdatedAt }
type Item struct { ID, ListID, Name, Metadata, BTScore, BTSE, Rank, Wins, Losses, Ties, CreatedAt }
type Comparison struct { ID, ListID, ItemAID, ItemBID, Result, Phase, ResponseTimeMs, CreatedAt }
type ScheduleEntry struct { ID, ListID, ItemAID, ItemBID, Round, Completed }
type NextPair struct { ItemA, ItemB Item; Phase string; Progress struct{ Completed, EstimatedTotal int } }
type RankEntry struct { Item; Rank int; Score, SE float64 }
```

### bt.go (~100 righe)

```go
// 1. RecalculateScores(items []Item, comparisons []Comparison) []Item
//    - MM iteration fino a convergenza (max 100 iter, ε=1e-6)
//    - Tie = 0.5 vittorie per lato
//    - Calcola SE per ogni item
//    - Assegna rank (1 = migliore)
//    - Aggiorna wins/losses/ties
//
// 2. Normalizzazione: dopo MM, scala i π per avere media = 1.0
```

### scheduler.go (~120 righe)

```go
// 1. GenerateSchedule(items []Item) []ScheduleEntry
//    - Round-robin bilanciato: ceil(N * log2(N)) coppie
//    - Ogni item appare ~ugualmente
//    - Shuffle delle coppie per randomizzare l'ordine
//
// 2. NextPair(items []Item, schedule []ScheduleEntry, comparisons []Comparison) *NextPair
//    - Fase 1: prossima coppia non completata dallo schedule
//    - Fase 2: selezione adattiva (SE piu' alto → vicino incerto)
//    - Fase 3: convergenza → nil (caller ritorna 204)
//    - Random injection: ogni 3 adaptive, 1 random
//
// 3. GenerateSeedComparisons(items []Item) []ScheduleEntry
//    - Per items con initial_rating: confronti tra adiacenti nel ranking iniziale
```

### handlers.go (~300 righe)

```go
// Tutti gli handler seguono il pattern:
// 1. extractAuth(r) → userID
// 2. Parse path params / body JSON
// 3. requireOwner() dove necessario
// 4. Query/mutazione DB
// 5. Se mutazione su items/comparisons → RecalculateScores() → update DB
// 6. JSON response

// Handler specifici:
// handleCreateList, handleGetLists, handleGetList, handleDeleteList
// handleAddItems        — batch insert + genera schedule se primo batch
// handleDeleteItem      — delete + ricalcola BT
// handleUpdateItem      — update name/metadata (no ricalcolo)
// handleGetNext         — NextPair() → 200 con coppia o 204 se converged
// handleSubmitComparison — insert + ricalcola BT + marca schedule entry completed
// handleGetRanking      — items ordinati per rank
// handleGetStats        — conteggi + fase corrente + convergenza
// handleImport          — batch insert con initial_rating → seed schedule
```

---

## Infrastruttura

### docker-compose.yml

```yaml
services:
  preference-sort:
    build: .
    container_name: preference-sort
    expose:
      - "8093"
    environment:
      - PORT=8093
      - DATABASE_URL=postgres://preference_sort:${PREFSORT_DB_PASSWD}@postgres:5432/preference_sort?sslmode=disable
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 128m
    security_opt:
      - no-new-privileges:true
    networks:
      - shared

networks:
  shared:
    external: true
```

### Dockerfile

```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
COPY migrations/ ./migrations/
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o preference-sort .

FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app/preference-sort /preference-sort
COPY --from=builder /app/migrations/ /migrations/
EXPOSE 8093
CMD ["/preference-sort"]
```

**Nota**: le migrations vengono copiate nel container come file embedded. In alternativa si possono embeddare con `embed.FS` in Go 1.16+.

### nginx.conf (aggiungere in ENTRAMBI i server blocks :80 e :8888)

```nginx
# Preference Sort health (senza auth, exact match priorita')
location = /rank/health {
    set $prefsort_health http://preference-sort:8093;
    proxy_pass $prefsort_health/health;
}

# Preference Sort API (JWT via gateway)
location /rank/ {
    auth_request /internal/jwt/validate;
    auth_request_set $auth_user $upstream_http_x_auth_user;
    auth_request_set $auth_user_id $upstream_http_x_auth_user_id;
    auth_request_set $auth_readonly $upstream_http_x_auth_readonly;

    set $prefsort_upstream http://preference-sort:8093;
    rewrite ^/rank/(.*) /$1 break;
    proxy_pass $prefsort_upstream;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Auth-User $auth_user;
    proxy_set_header X-Auth-User-Id $auth_user_id;
    proxy_set_header X-Auth-Readonly $auth_readonly;
}
```

### Creazione database PostgreSQL

```bash
docker exec postgres psql -U postgres -c "
    CREATE USER preference_sort WITH PASSWORD '<password>';
    CREATE DATABASE preference_sort OWNER preference_sort;
"
```

La password va in `/data/massimiliano/Vari/preference-sort/.env` come `PREFSORT_DB_PASSWD=<password>`.

---

## Dipendenze Go

```
github.com/jackc/pgx/v5          # PostgreSQL driver + pool
```

Nessuna dipendenza JWT (delegata al gateway). Nessun framework HTTP (stdlib Go 1.22).

---

## Sequenza implementazione

1. **Database**: creare utente e database `preference_sort` su PostgreSQL
2. **Go module**: `go mod init preference-sort`, aggiungere `pgx/v5`
3. **migrations/001_initial.sql**: schema tabelle
4. **models.go**: struct dati
5. **db.go**: connessione, pool, esecuzione migrazioni
6. **bt.go**: algoritmo Bradley-Terry MM + SE
7. **scheduler.go**: generazione schedule + selezione adattiva
8. **handlers.go**: endpoint REST (in ordine: lists CRUD, items CRUD, next, comparisons, ranking, stats, import)
9. **main.go**: server HTTP, routes, middleware auth header
10. **Dockerfile + docker-compose.yml**: build e deploy
11. **nginx.conf**: aggiungere location `/rank/` in entrambi i server blocks
12. **Test end-to-end**: crea lista → aggiungi items → confronti → verifica ranking
13. **Documentazione**: CLAUDE.md, README.md, MEMORY.md

---

## File da modificare (esistenti)

- `/data/massimiliano/proxy/nginx.conf` — aggiungere `location /rank/` e `location = /rank/health` in entrambi i server blocks (:80 e :8888)
- `/data/massimiliano/CLAUDE.md` — aggiornare tabelle routing e servizi
- `/data/massimiliano/README.md` — aggiornare diagramma e tabelle

## File di riferimento

- `/data/massimiliano/Vari/server-api/main.go` — pattern Go 1.22 mux, JSON responses, Docker build
- `/data/massimiliano/Vari/server-api/Dockerfile` — multi-stage scratch
- `/data/massimiliano/Vari/server-api/docker-compose.yml` — deployment pattern
- `/data/massimiliano/Vari/jwt-gateway/main.go` — pattern auth headers (reference per capire cosa arriva)
- `/data/massimiliano/proxy/nginx.conf` — pattern auth_request gia' configurato
- `/data/massimiliano/postgres/init/01-databases.sh` — pattern creazione database

## Verifica

1. `curl http://100.86.46.84/rank/health` → `{"status":"ok","service":"preference-sort"}`
2. `curl -H "Authorization: Bearer <token>" http://100.86.46.84/rank/lists` → `[]` (lista vuota)
3. Creare lista: `curl -X POST -H "Authorization: Bearer <token>" -d '{"name":"test"}' http://100.86.46.84/rank/lists` → `{"id":"uuid",...}`
4. Aggiungere 5 items: `POST /rank/lists/{id}/items` con array
5. `GET /rank/lists/{id}/next` → prima coppia da confrontare (fase scheduled)
6. `POST /rank/lists/{id}/comparisons` × 5-6 confronti
7. `GET /rank/lists/{id}/ranking` → ranking con score BT e SE
8. `GET /rank/lists/{id}/stats` → conteggi e fase corrente
9. Senza token: `curl http://100.86.46.84/rank/lists` → 401 (bloccato da jwt-gateway)
10. Con token visitor: `curl -X POST ...` → 403 (bloccato da jwt-gateway, readonly)

---

## Progetti Futuri

### Migrazione servizi esistenti al JWT Gateway

Dopo che il gateway e' stabile con preference-sort come consumer, migrare:
- `/server/` (server-api) — rimuovere JWT validation interna, leggere header X-Auth-*
- `/claude/` (claude-proxy) — idem
- `/api/` (dashboard-api) — solo endpoint REST `/notes`; WebSocket `/ws` mantiene JWT via query param
