# Embedding Visualizer — Piano di implementazione

## Contesto

Il Knowledge Graph viewer (`notes.massimilianopili.com`) mostra il grafo AGE/Neo4j come un force-directed graph D3.js. L'utente vuole una visualizzazione analoga ma diversa per gli embeddings pgvector (~2.690 vettori 1024-dim in `vector_store`), mostrando lo spazio vettoriale come scatter plot 2D interattivo.

## Architettura

**App Go separata** (`embedding-viz`), stesso pattern del KG viewer:
- Go stdlib + pgx/v5 + go-oidc + securecookie
- Multi-stage Docker → scratch (~10 MB)
- Rete `shared`, porta interna 8098
- Keycloak OIDC (client `embedding-viz`)
- Nginx subpath `/embeddings/` su `:8888` + porta dedicata `:8892` (Tailscale)

### Scelte architetturali

| Decisione | Scelta | Motivazione |
|---|---|---|
| Riduzione dimensionale | PCA server-side in Go (power iteration) | Zero dipendenze, deterministico, <1s per 2.7K×1024. UMAP opzionale in Phase 2 |
| Backend | Go | Pattern provato (KG viewer), scratch image, ~10MB |
| Query vettori | SQL diretto su pgvector via pgx | Self-contained, nessuna dipendenza su MCP server |
| Ricerca semantica | Ollama API → pgvector cosine | Stessa pipeline del MCP ma in Go |
| Frontend | D3.js scatter plot, single-file SPA | Stesso pattern KG viewer |

### Data flow

```
PostgreSQL vector_store (2.7K × 1024-dim)
  → Go: PCA power iteration → 2D coords [-1,1]
  → Cache in-memory (TTL 5 min)
  → JSON API (~500 KB: id, x, y, type, label, source, metadata)
  → Browser: D3.js scatter plot con zoom/pan/filter
```

## Struttura file

```
/data/massimiliano/embedding-viz/
├── docker-compose.yml
├── Dockerfile           # golang:1.24-alpine → scratch
├── .env                 # PG, Ollama, Keycloak, SESSION_KEY
├── go.mod
├── main.go              # HTTP server, routes, embed static
├── auth.go              # OIDC Keycloak (adattato da KG viewer)
├── vectors.go           # Query PostgreSQL vector_store
├── projection.go        # PCA via power iteration
├── ollama.go            # Client POST /api/embed
├── solsec/              # Copia da knowledge-graph/solsec/
└── static/
    └── index.html       # SPA D3.js scatter plot
```

## API endpoints

| Metodo | Path | Auth | Descrizione |
|---|---|---|---|
| GET | `/health` | No | Health check |
| GET | `/auth/login` | No | OIDC redirect |
| GET | `/auth/callback` | No | OIDC callback |
| GET | `/auth/logout` | No | Logout |
| GET | `/auth/me` | Sì | Info utente |
| GET | `/api/vectors[?type=&source=]` | Sì | Tutti i punti 2D con filtri |
| GET | `/api/search?q=text&k=10` | Sì | Ricerca semantica: embed query + nearest neighbors |
| GET | `/api/stats` | Sì | Statistiche per tipo |
| GET | `/api/sources` | Sì | Lista source_file distinti |
| GET | `/api/clusters?n=8` | Sì | K-means cluster labels su proiezioni 2D |

### Shape punto JSON

```json
{"id":"uuid", "x":0.43, "y":-0.19, "type":"docs", "label":"...", "source_file":"...", "metadata":{}}
```

## Frontend (scatter plot D3.js)

```
┌─────────────────────────────────────────────────────┐
│ Topbar: "Embedding Space"  [search]    user  logout │
├──────────┬────────────────────────────┬─────────────┤
│ Sidebar  │  Scatter plot (D3.js)      │ Detail      │
│ ──────── │    · ·  ·                  │ ──────────  │
│ Tipi     │  ·   ··  ·                │ Titolo      │
│  ☑ docs  │    · ★(query) ·           │ Tipo: docs  │
│  ☑ conv  │  ·  · ·   ·              │ Source: ... │
│  ☑ paper │     ·  ·                  │ Contenuto   │
│ ──────── │                            │ Neighbors   │
│ Sources  │  [+][-][Reset][Clusters]   │  - item 94% │
│ Stats    │  ● docs ● conv ● paper    │  - item 91% │
└──────────┴────────────────────────────┴─────────────┘
```

- **Colori**: conversation=#58a6ff, docs=#3fb950, paper=#d29922
- **Interazione**: hover=tooltip, click=detail panel, zoom/pan, doppio-click=ego neighbors
- **Ricerca**: debounce 500ms → embed → star marker + linee ai K nearest
- **Cluster**: toggle convex hull con label

## Deploy

1. **Keycloak**: nuovo client `embedding-viz` (confidential, realm `sol`)
2. **Docker**: container `embedding-viz` su `shared`, 192m, porta 8098
3. **Nginx**: subpath `/embeddings/` su `:8888` + server block `:8892` (Tailscale)
4. **Infra graph**: `import_infrastructure.py --service embedding-viz`

## Sequenza implementazione

### Phase 1: Backend core
1. Creare dir `/data/massimiliano/embedding-viz/`
2. Copiare/adattare `auth.go` da KG viewer (cookie `ev_session`)
3. Copiare `solsec/`
4. `vectors.go`: connessione PG, fetch vettori, stats, sources
5. `projection.go`: PCA power iteration (2 eigenvector)
6. `ollama.go`: client HTTP per embedding query
7. `main.go`: routing, embed FS, graceful shutdown

### Phase 2: Frontend scatter plot
8. `static/index.html`: D3.js scatter plot, sidebar, detail panel
9. Filtri per tipo e source
10. Hover tooltips, click detail

### Phase 3: Ricerca semantica
11. Endpoint `/api/search`: Ollama embed + pgvector cosine + proiezione PCA
12. Frontend: search input, star marker, linee ai neighbors

### Phase 4: Docker + deploy
13. Dockerfile, docker-compose.yml, .env
14. Client Keycloak `embedding-viz`
15. Nginx routes (`:8888` + `:8892`)
16. Test auth end-to-end

### Phase 5: Cluster + polish
17. `/api/clusters`: K-means su proiezioni 2D
18. Frontend: convex hull, label cluster
19. Infra graph update

### Phase 6 (opzionale): UMAP pre-calcolato
20. Script Python `compute_umap.py` → tabella `vector_projections`
21. Backend: usa UMAP se disponibile, fallback PCA

## File critici da riutilizzare

- `/data/massimiliano/knowledge-graph/auth.go` — OIDC dual-URL pattern
- `/data/massimiliano/knowledge-graph/main.go` — HTTP server pattern
- `/data/massimiliano/knowledge-graph/age.go` — pgx/v5 connection pattern per PostgreSQL
- `/data/massimiliano/knowledge-graph/static/index.html` — D3.js UI patterns (dark theme, sidebar, detail panel)
- `/data/massimiliano/knowledge-graph/Dockerfile` — multi-stage Go → scratch
- `/data/massimiliano/knowledge-graph/docker-compose.yml` — deploy pattern

## Stato attuale — Bug fix in corso

L'implementazione è completa e deployata. Bug trovato: **tutti i path nel frontend e nei redirect Go usavano path assoluti** (`/auth/login`, `/api/vectors`, etc.) che nginx instradava a Keycloak o alla root del dominio invece che attraverso il subpath `/embeddings/`.

### Fix applicati (sessione precedente)
1. `static/index.html`: login button `'/auth/login'` → `'auth/login'` (relativo)
2. `auth.go` Callback: redirect `"/"` → `a.baseURL` (URL completo)
3. `auth.go` Logout: redirect `"/"` → `a.baseURL`
4. `static/index.html`: `fetch('/auth/me')` → `fetch('auth/me')`
5. `static/index.html`: `fetch('/api/clusters?n=8')` → `fetch('api/clusters?n=8')`
6. `nginx.conf`: aggiunto `location = /embeddings { return 301 /embeddings/; }` su :8888
7. Container ricostruito e nginx ricreato

### Ancora da verificare
- `fetch('/api/vectors')`, `fetch('/api/stats')`, `fetch('/api/sources')` — possibile che servano ancora fix
- `href="/auth/logout"` — potrebbe ancora essere assoluto
- Test end-to-end del flusso OIDC completo
- Verifica card dashboard funzionante

## Verifica

1. `docker compose up -d` → container healthy
2. `curl http://embedding-viz:8098/health` → `{"status":"ok"}`
3. Browser: `https://sol.massimilianopili.com/embeddings/` → login Keycloak → scatter plot visibile
4. Ricerca: digitare query → star marker + neighbors evidenziati
5. Filtri tipo/source funzionanti
6. Cluster toggle mostra convex hull
