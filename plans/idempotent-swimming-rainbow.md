# Knowledge Graph — Personal Knowledge Management

## Contesto

L'utente vuole un'alternativa self-hosted a Obsidian con **graph view interattivo**, **accesso web da browser**, e **integrazione con il ciclo di lettura RSS → Kindle → Neo4j**. Invece di usare un'app off-the-shelf (SiYuan, Trilium), costruiamo una **soluzione custom** che visualizza il knowledge graph Neo4j già esistente (Book, Author, Highlight) e lo arricchisce con concetti estratti automaticamente via Claude.

**Ciclo completo**: RSS → EPUB → Kindle → highlight → import Neo4j → concept extraction → **Graph UI web**

## Architettura

```
                    ┌────────────────────────────────────────────┐
                    │  notes.massimilianopili.com                │
                    │                                            │
  Cloudflare ──→ nginx:8891 ──→ knowledge-graph:8096 (Go)       │
                    │                ├── D3.js force graph (embed)│
                    │                ├── Neo4j Bolt driver        │
                    │                ├── OIDC Keycloak            │
                    │                └── Claude API (enrichment) │
                    │                                            │
  Tailscale ──→ http://100.86.46.84:8891/                       │
                    └────────────────────────────────────────────┘

  rss-to-kindle (Python sidecar, cron 6:00) ──→ EPUB ──→ Kindle email
       ↕ shared/ volume (feeds.json, status.json)
```

## Stack tecnologico

| Componente | Tecnologia | Motivazione |
|------------|-----------|-------------|
| **Backend** | Go 1.22, stdlib `net/http` | Coerente con server-api, preference-sort, jwt-gateway |
| **Frontend** | Vanilla JS + D3.js `d3-force` | Coerente con dashboard, embed in Go (`//go:embed`) |
| **Graph DB** | Neo4j 5 (già attivo) | Book/Author/Highlight già presenti |
| **Auth** | OIDC Keycloak nativo | Pattern `go-filemanager` (dual-URL, session, resource_access) |
| **RSS pipeline** | Python 3 (feedparser + ebooklib) | Container sidecar, cron-based |
| **Enrichment** | Claude Haiku API (HTTP diretto) | Estrazione concetti dagli highlight |
| **Note storage** | Neo4j (nodi `Note` linkati al grafo) | Dati nativamente nel grafo |

## Directory layout

```
/data/massimiliano/knowledge-graph/
├── docker-compose.yml
├── .env                    # NEO4J_PASSWORD, KEYCLOAK_CLIENT_SECRET, SMTP creds, CLAUDE_API_KEY
├── Dockerfile              # Go multi-stage → scratch
├── Dockerfile.rss          # Python 3.12-slim + feedparser + ebooklib
├── go.mod / go.sum
├── main.go                 # Server HTTP, routes, Neo4j init
├── auth.go                 # OIDC Keycloak (da go-filemanager/internal/auth/oidc.go)
├── graph.go                # Query Cypher (full graph, ego graph, search)
├── notes.go                # CRUD note
├── rss.go                  # Gestione feed + lettura status
├── enrich.go               # Enrichment via Claude API (async goroutine)
├── static/
│   └── index.html          # UI: 3 pannelli (sidebar + graph D3 + detail)
├── rss/
│   ├── rss_to_kindle.py    # Pipeline: fetch RSS → EPUB → email Kindle
│   ├── scheduler.py        # Loop cron (sleep fino alle 6:00)
│   └── requirements.txt    # feedparser, ebooklib
└── shared/                 # Volume condiviso Go ↔ Python
    ├── feeds.json           # Lista feed (scritto da Go, letto da Python)
    └── status.json          # Stato pipeline (scritto da Python, letto da Go)
```

## File infrastruttura da modificare

| File | Modifica |
|------|----------|
| `/data/massimiliano/proxy/docker-compose.yml` | Aggiungere porta `8891:8891` a nginx |
| `/data/massimiliano/proxy/nginx.conf` | Nuovo server block `:8891` (proxy → knowledge-graph:8096) |
| `/data/massimiliano/cloudflared/config.yml` | Ingress `notes.massimilianopili.com` → `nginx:8891` |
| Cloudflare DNS (web UI) | CNAME `notes` → tunnel ID `.cfargotunnel.com` |
| Keycloak (web UI) | Nuovo client `knowledge-graph` (OIDC, confidential) |
| `/data/massimiliano/proxy/home/index.html` | Card "Knowledge Graph" nella dashboard |

## File esistenti da riusare (pattern)

| File | Cosa riusare |
|------|-------------|
| `/data/massimiliano/Vari/go-filemanager/internal/auth/oidc.go` | Pattern OIDC Keycloak (dual-URL, session, resource_access) |
| `/data/massimiliano/Vari/preference-sort/main.go` | Pattern Go HTTP server (stdlib mux, healthcheck, CORS) |
| `/data/massimiliano/kindle/import_kindle.py` | Schema grafo Neo4j (Book, Author, Highlight, relazioni) |
| `/data/massimiliano/progetti_futuri/PIANO_RSS_TO_KINDLE.md` | Architettura pipeline RSS (recipe Calibre, SMTP, feed list) |
| `/data/massimiliano/progetti_futuri/PIANO_KINDLE_GRAPH_ENRICHMENT.md` | Prompt extraction, schema Concept+MENTIONS+RELATED_TO |

## API endpoints

```
GET  /health                  # Healthcheck (no auth)
GET  /auth/login              # Redirect Keycloak
GET  /auth/callback           # OIDC callback
GET  /auth/logout             # Logout
GET  /auth/me                 # User info JSON

GET  /api/graph               # Grafo completo (nodes + edges, cap 500 nodi)
GET  /api/graph?center=<id>   # Ego graph (profondità 2, centrato su un nodo)
GET  /api/books               # Lista libri
GET  /api/books/{id}          # Dettaglio libro (highlight, concetti)
GET  /api/concepts            # Lista concetti (con conteggi)
GET  /api/search?q=<query>    # Ricerca full-text (tutti i tipi)

GET    /api/notes             # Lista note utente
POST   /api/notes             # Crea nota (linkabile a nodo)
PUT    /api/notes/{id}        # Modifica nota
DELETE /api/notes/{id}        # Elimina nota

GET    /api/feeds             # Lista feed configurati + stato
POST   /api/feeds             # Aggiungi feed
DELETE /api/feeds/{id}        # Rimuovi feed
GET    /api/feeds/status      # Stato ultima esecuzione pipeline

POST   /api/enrich            # Avvia estrazione concetti (async)
GET    /api/enrich/status     # Progresso enrichment
```

## UI — Layout a 3 pannelli

```
┌─────────────────────────────────────────────────────────────┐
│  Knowledge Graph              [Search...] [User] [Logout]   │
├──────────────┬────────────────────────┬─────────────────────┤
│  Sidebar     │  Graph Canvas (D3.js)  │  Detail Panel       │
│              │                        │                     │
│  [Books]     │   ○──○──○              │  Titolo: ...        │
│   - Book A   │    \  / \              │  Tipo: Book         │
│   - Book B   │     ○    ○             │  Connessioni: 12    │
│  [Authors]   │    /      \            │                     │
│  [Concepts]  │   ○────○───○           │  Highlights:        │
│  [Notes]     │                        │   - "testo..."      │
│  [RSS Feeds] │  zoom / pan / drag     │                     │
│   - status   │                        │  [+ Add Note]       │
└──────────────┴────────────────────────┴─────────────────────┘
```

**Nodi**: Book (blu), Author (verde), Concept (arancione), Highlight (grigio), Note (viola)
**Dimensione**: proporzionale al numero di connessioni (degree)
**Interazioni**: click (seleziona), double-click (centra), hover (evidenzia edges), drag (sposta)

## Modello grafo Neo4j (esteso)

```
(:Author {name}) ←[:WRITTEN_BY]─ (:Book {title, author})
                                      ↑
                                  [:FROM]
                                      |
                                 (:Highlight {text, page, location_start, ...})
                                      |
                                  [:MENTIONS]     ← enrichment Claude
                                      ↓
                                 (:Concept {name, category, description})
                                      |
                                  [:RELATED_TO {strength, reason}]
                                      ↓
                                 (:Concept)

(:Note {id, title, content, created_at, user_id})
    |
  [:ABOUT]  →  (:Book | :Author | :Concept | :Highlight)
```

## Budget risorse

| Container | Memoria limite | Uso atteso |
|-----------|---------------|------------|
| knowledge-graph (Go) | 192m | ~6-12 MB |
| rss-to-kindle (Python) | 256m | ~40-80 MB (solo durante cron) |
| **Totale** | **448m** | **~50-90 MB** |

Neo4j attuale: 386 MB / 768 MB. Concept nodes e Note nodes aggiungeranno carico trascurabile.

## Piano implementazione a fasi

### Fase 1 — MVP: Graph Viewer (4-5h)

Visualizzare il grafo esistente (Book, Author, Highlight) in un graph D3.js interattivo.

1. Creare directory `/data/massimiliano/knowledge-graph/`
2. Go backend: `main.go` (server + routes), `auth.go` (OIDC), `graph.go` (query Cypher read-only)
3. Frontend: `static/index.html` con D3.js force-directed, 3 pannelli, search, zoom/pan
4. Docker: `Dockerfile` (multi-stage scratch), `docker-compose.yml`
5. Infrastruttura:
   - Cloudflare: CNAME `notes` → tunnel
   - `cloudflared/config.yml`: ingress `notes.massimilianopili.com` → `nginx:8891`
   - `proxy/docker-compose.yml`: porta `8891:8891`
   - `proxy/nginx.conf`: server block `:8891` → `knowledge-graph:8096`
   - Keycloak: client `knowledge-graph` (redirect URI Tailscale + pubblica)
6. Deploy e test

### Fase 2 — Note (2-3h)

Aggiungere note personali linkate ai nodi del grafo.

1. Schema Neo4j: constraint `Note.id` unique, indice full-text
2. `notes.go`: CRUD handlers
3. Frontend: editor nel panel destro, bottone "+ Add Note", note come nodi viola nel grafo

### Fase 3 — Concept Extraction (2-3h)

Arricchire il grafo con concetti estratti dagli highlight via Claude API.

1. `enrich.go`: goroutine async, batch per libro, Claude Haiku API
2. Prompt strutturato da `PIANO_KINDLE_GRAPH_ENRICHMENT.md`
3. Cypher MERGE per Concept + MENTIONS + RELATED_TO
4. Frontend: bottone "Enrich", progress bar, nuovi nodi arancione nel grafo

### Fase 4 — RSS Pipeline (2-3h)

Pipeline automatica RSS → EPUB → Kindle.

1. `Dockerfile.rss`: Python sidecar
2. `rss/rss_to_kindle.py`: fetch feed, build EPUB, send email
3. `rss/scheduler.py`: loop cron (6:00 daily)
4. `rss.go`: gestione feed via API (CRUD `shared/feeds.json`, lettura `shared/status.json`)
5. Frontend: sezione "RSS Feeds" in sidebar (aggiungi/rimuovi, stato pipeline)
6. Configurare SMTP + email Kindle

### Fase 5 — Polish (1-2h)

1. Supporto visitor read-only (`resource_access.knowledge-graph.roles: readonly`)
2. Performance: lazy loading per grafi grandi, ego graph come default
3. Card nella dashboard SOL (`proxy/home/index.html`)
4. Aggiornamento CLAUDE.md e docs

## Verifica end-to-end

1. `docker ps | grep knowledge-graph` → healthy
2. `https://notes.massimilianopili.com/` → redirect Keycloak → graph view
3. `http://100.86.46.84:8891/` → stessa esperienza via Tailscale
4. Click su un nodo Book → detail panel con highlight
5. Cerca un autore → nodi filtrati nel grafo
6. Crea nota linkata a un libro → nodo viola appare nel grafo
7. "Enrich" → concetti estratti, nodi arancione nel grafo
8. Aggiungi feed RSS → esecuzione pipeline → EPUB su Kindle
