# KORE Search — Bug Fixes (Embed Timeout + Progressive Results + Back Arrow)

## Context

KORE Search deployed but has 3 issues:
1. **Ollama embed takes ~18s** on SOL CPU — 8s timeout too short, vector+hybrid always fail
2. **Results are all-or-nothing** — user wants progressive display as each source completes
3. **Back arrow missing from landing page** — only shows on results page

## Fix 1: Embed Timeout (search.go)
- Increase embed timeout: 8s → 30s
- Increase global timeout: 10s → 35s
- Increase vector source timeout: 5s → 30s
- Increase hybrid source timeout: 3s → 30s

## Fix 2: Progressive Results (search.go + static/index.html)

**Backend**: Change `/api/search` from JSON response to **ndjson streaming**.
Each source sends its results as soon as it completes:
```
{"source":"graph","results":[...],"time_ms":37}
{"source":"wikijs","results":[...],"time_ms":1200}
{"source":"web","results":[...],"time_ms":4400}
{"source":"vector","results":[...],"time_ms":18000}
{"done":true,"total_ms":18500}
```

In `search.go`:
- Set `Content-Type: application/x-ndjson`, chunked transfer
- Instead of collecting all results then responding, write each `sourceResult` to the response as it arrives from the channel
- Final line sends `{"done":true}` with merged/sorted results and stats
- RRF scoring happens client-side (simpler) or in a final `done` message with full sorted list

Simpler approach: stream per-source results immediately, then send a final `done` with the RRF-merged order.

**Frontend** (`static/index.html`):
- Use `fetch()` + `ReadableStream` reader (same pattern as summarize)
- As each source's ndjson line arrives: append results to the list, update sidebar counts, update timing
- On `done`: reorder results by RRF score, update status bar

## Fix 3: Back Arrow on Landing (static/index.html)
- Add `← ` arrow link to `/` at the top of the landing page (above the title)
- Style: small, top-left, muted color — same as task-ui pattern

## Files to modify
- `/data/massimiliano/kore-search/search.go` — streaming response, timeout increases
- `/data/massimiliano/kore-search/static/index.html` — ReadableStream reader, back arrow on landing

## Verification
1. Visit `/search/` → back arrow visible on landing page → click → goes to dashboard
2. Search "transformer" → KORE results appear immediately (~100ms), then Wiki (~1s), Web (~4s), Papers (~1.5s), Vector (~18s)
3. Results reorder by RRF score when `done` arrives
4. Timing panel updates progressively

---
PREVIOUS PLAN (completed, reference only):

SOL has ~9 search sources (KORE graph, pgvector, SearXNG, OpenAlex, Anki, code, conversations, WikiJS, Small Web) but no single UI to query them all at once. Each source has its own MCP tool or viewer. The goal is a federated search browser: one query, all sources in parallel, merged results ranked by relevance — with an LLM-powered summary panel (like Kagi's Quick Answer) that synthesizes the top results into a coherent answer.

## Architecture: Hybrid (Option C)

- **Direct DB** for fast local sources: AGE Cypher (graph), pgvector cosine (embeddings), WikiJS PostgreSQL full-text
- **HTTP API** for external/slow sources: SearXNG (`http://searxng:8080`), OpenAlex (`https://api.openalex.org`)
- **Ollama** for query embedding: `http://ollama:11434` (`qwen3-embedding:8b`, 4096 dim)
- **LLM summarization**: Ollama chat (`qwen3:8b`) or Anthropic proxy (`http://proxy-ai:8097`) for result aggregation

Matches the existing pattern of knowledge-graph and embedding-viz (direct DB, not MCP relay).

## Directory: `/data/massimiliano/kore-search/`

```
kore-search/
├── main.go              # HTTP server, routes, embed.FS
├── auth.go              # OIDC dual-URL (copy from knowledge-graph, rename cookie)
├── search.go            # Fan-out orchestrator + RRF merging
├── summarize.go         # LLM summarization (Ollama chat or Anthropic proxy, HTTP Streamable ndjson)
├── source_graph.go      # AGE Cypher text search (Paper, Author, BlogPost, Book, Concept, Topic)
├── source_vector.go     # pgvector cosine similarity (all types)
├── source_web.go        # SearXNG JSON API
├── source_openalex.go   # OpenAlex REST API
├── source_wikijs.go     # WikiJS PG full-text (pages table)
├── ollama.go            # Embedding + chat client (adapted from embedding-viz)
├── Dockerfile           # Multi-stage golang:1.25-alpine → scratch
├── docker-compose.yml   # shared network, 256m, port 8102
├── .env                 # All credentials externalized
├── go.mod
└── static/
    └── index.html       # Single-file vanilla JS UI (Kagi/OpenAlex-inspired)
```

## Key Files to Reuse

| File | Reuse |
|------|-------|
| `knowledge-graph/auth.go` (299 lines) | Copy verbatim, rename cookie `ks_session`, change defaults |
| `knowledge-graph/age.go:59-73` | `NewAGEHandler` + `cypher()` helper pattern |
| `embedding-viz/ollama.go` (68 lines) | Copy verbatim |
| `embedding-viz/vectors.go:53-71` | `NewVectorHandler` DB setup pattern |
| `proxy/nginx.conf` | Add `/search/` route to :80 and :8888 blocks |

## Backend Design

### Unified Result Type

```go
type SearchResult struct {
    ID       string         `json:"id"`
    Source   string         `json:"source"`    // graph, vector, web, openalex, wikijs
    Type     string         `json:"type"`      // paper, author, blogpost, code, conversation, anki, concept, wiki, web
    Title    string         `json:"title"`
    Snippet  string         `json:"snippet"`   // max 300 chars
    URL      string         `json:"url,omitempty"`
    Date     string         `json:"date,omitempty"`
    Score    float64        `json:"score"`     // normalized 0-1 after RRF
    Metadata map[string]any `json:"metadata,omitempty"`
}
```

### Routes

```
GET  /health                 # no auth
GET  /auth/login             # OIDC redirect
GET  /auth/callback          # OIDC callback
GET  /auth/logout            # clear session
GET  /auth/me                # session info JSON
GET  /api/search?q=&sources=&types=&from=&to=&limit=  # main search (JSON)
POST /api/summarize          # LLM summary (HTTP Streamable ndjson, receives query + top results)
GET  /api/stats              # source counts + health
GET  /                       # SPA (static/index.html)
```

### Search Fan-Out (`search.go`)

```
1. Parse query params (q, sources, types, from, to, limit=50)
2. Start Ollama embed(q) in background goroutine
3. Fan out in parallel (per-source goroutines, each with context timeout):
   - graph:    2s timeout → AGE MATCH ... CONTAINS query (6 labels, LIMIT 20 each)
   - web:      3s timeout → GET searxng:8080/search?q=...&format=json
   - openalex: 3s timeout → GET api.openalex.org/works?search=...
   - wikijs:   2s timeout → PG ts_rank full-text on pages table
   - vector:   2s timeout → waits for embed result, then cosine search on vector_store
4. Collect results via channel, global timeout 5s
5. Deduplicate by URL/DOI normalization
6. Merge via weighted RRF: score = SUM(weight_s / (60 + rank_in_s))
7. Sort by score desc, apply type/date filters, return top `limit`
```

Source weights: KORE graph 1.5, pgvector 1.3, WikiJS 1.2, OpenAlex 1.0, Web 0.8.

### Source Queries

**source_graph.go** — 6 label-specific AGE Cypher queries:
```cypher
MATCH (n:Paper) WHERE toLower(n.title) CONTAINS toLower('query') RETURN n LIMIT 20
MATCH (n:Author) WHERE toLower(n.name) CONTAINS toLower('query') RETURN n LIMIT 20
MATCH (n:BlogPost) WHERE toLower(n.title) CONTAINS toLower('query') RETURN n LIMIT 20
-- ... Book, Concept, Topic
```

**source_vector.go** — pgvector cosine similarity:
```sql
SELECT id, content, metadata, 1 - (embedding <=> $1::vector) AS similarity
FROM vector_store
WHERE ($2 = '' OR metadata->>'type' = ANY($3))
ORDER BY embedding <=> $1::vector
LIMIT $4
```

**source_web.go** — SearXNG JSON:
```
GET http://searxng:8080/search?q={query}&format=json&categories=general,science&pageno=1
```

**source_openalex.go** — OpenAlex API:
```
GET https://api.openalex.org/works?search={query}&per_page=20&sort=cited_by_count:desc
```

**source_wikijs.go** — PostgreSQL full-text:
```sql
SELECT id, path, title, description,
       ts_rank(to_tsvector('english', title || ' ' || description), plainto_tsquery('english', $1)) AS rank
FROM pages WHERE to_tsvector('english', title || ' ' || description) @@ plainto_tsquery('english', $1)
ORDER BY rank DESC LIMIT 20
```

## LLM Summarization (`summarize.go`)

**Quick Answer panel** (inspired by Kagi) — streams an LLM-generated summary above the results.

### Flow
1. Frontend calls `POST /api/summarize` with `{query, results}` after search results arrive
2. Backend takes top 10 RRF results, builds a context prompt:
   ```
   Query: {user query}

   Sources:
   [1] {title} ({source}) — {snippet}
   [2] {title} ({source}) — {snippet}
   ...

   Synthesize a concise answer (3-5 sentences) citing sources by number [1][2].
   If sources are insufficient, say so. Be precise and factual.
   ```
3. Streams response via Ollama `/api/chat` (model: `qwen3:8b`) as HTTP Streamable to frontend
4. Frontend reads via `fetch()` + `ReadableStream` reader, renders markdown incrementally

### Ollama Chat Extension
Add `ChatStream()` method to `ollama.go` (alongside existing `Embed()`):
```go
func (o *OllamaClient) ChatStream(ctx context.Context, system, user string, w http.ResponseWriter)
```
Uses Ollama `/api/chat` with `stream: true`. Forwards chunks as newline-delimited JSON (HTTP Streamable):
- Sets `Content-Type: application/x-ndjson`, `Transfer-Encoding: chunked`
- Each chunk: `{"token": "..."}` or `{"done": true}`
- Frontend reads with `response.body.getReader()` + `TextDecoder`, no EventSource needed
- Simpler than SSE (no event/data framing), works through any proxy, cancelable via `AbortController`

### Fallback
If Ollama is unavailable, the summary panel shows "Summary unavailable" gracefully. Search results work independently.

### Future: Anthropic Proxy
Can swap to `proxy-ai:8097` (Claude API) for higher-quality summaries. Env toggle: `SUMMARIZE_PROVIDER=ollama|anthropic`.

## Frontend Design (`static/index.html`)

Single-file vanilla JS + CSS variables (dark mode). **Kagi-inspired**: centered search, clean typography, Quick Answer box. **OpenAlex-inspired**: faceted sidebar, filter chips, citation metadata.

### Layout

```
┌──────────────────────────────────────────────────────────┐
│                        KORE Search                        │
│              [══════════ search bar ══════════]            │
│              source pills: [All] [KORE] [Web] [Papers]   │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─ Quick Answer ──────────────────────────────────────┐ │
│  │ Transformers use self-attention to process sequences │ │
│  │ in parallel [1][3]. The architecture was introduced  │ │
│  │ by Vaswani et al. (2017) [1] and has become...      │ │
│  │                                          ▼ streaming │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ Filters ──┐  ┌─ Results ─────────────────────────┐  │
│  │            │  │                                    │  │
│  │ Sources    │  │  ● Paper: "Attention Is All..."    │  │
│  │ ☑ KORE  12│  │    Vaswani et al. · 2017 · 120K    │  │
│  │ ☑ Sem.  15│  │    citations · NeurIPS              │  │
│  │ ☑ Web   10│  │    [OpenAlex] [DOI]                 │  │
│  │ ☑ Papers 8│  │                                    │  │
│  │ ☑ Wiki   2│  │  ● Doc: "Transformer overview"     │  │
│  │            │  │    docs/ai/transformers.md          │  │
│  │ Types     │  │    similarity: 0.87                 │  │
│  │ ☑ Paper   │  │                                    │  │
│  │ ☑ Blog    │  │  ● Web: "Illustrated Transformer"  │  │
│  │ ☑ Code    │  │    jalammar.github.io · 2018        │  │
│  │ ☑ Anki    │  │                                    │  │
│  │ ☑ Wiki    │  │  47 results · 5 sources · 1.2s     │  │
│  │            │  │                                    │  │
│  │ Year      │  │                                    │  │
│  │ [2020]-[  ]│  │                                    │  │
│  │            │  │                                    │  │
│  │ ⏱ Timing  │  │                                    │  │
│  │ graph 45ms│  │                                    │  │
│  │ vec  180ms│  │                                    │  │
│  │ web  1.2s │  │                                    │  │
│  │ oalex 890ms│ │                                    │  │
│  │ wiki  32ms│  │                                    │  │
│  └────────────┘  └────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

### UI Design Principles (Kagi + OpenAlex hybrid)

**From Kagi:**
- Centered search bar on landing (hero layout, no results yet)
- Quick Answer box above results (LLM summary with source citations)
- Source category pills below search bar (clickable to toggle)
- Clean typography, generous whitespace, no visual clutter
- Purple/indigo accent color scheme on dark background

**From OpenAlex:**
- Faceted sidebar with counts per source/type
- Filter chips showing active filters (removable with ×)
- Result cards with rich metadata (year, citations, venue, authors)
- Year range slider/inputs for temporal filtering

### Key Features
- **Streaming UX**: search results appear progressively (local first ~200ms, web ~1-3s). Quick Answer streams token-by-token via HTTP Streamable (ndjson + ReadableStream)
- **Source badges**: colored dots — KORE=indigo, Semantic=purple, Web=green, Papers=orange, Wiki=teal
- **Result cards**: title (linked), snippet, source badge, metadata row (year, citations, file path, similarity), action links ([DOI] [OpenAlex] [Save to KORE])
- **Quick Answer**: collapsible box with markdown rendering (marked.js), source citations as clickable `[1]` links that scroll to the corresponding result
- **Keyboard**: `/` focus search, `Esc` clear, `j/k` navigate results, `Enter` open link, `s` toggle summary
- **Mobile responsive**: sidebar becomes bottom sheet, Quick Answer collapses to 2-line preview
- **Landing page**: centered search bar with tagline "Search everything you know" + source icons
- **Deep links**: Paper→OpenAlex/DOI, Blog→original URL, Code→file:line, Wiki→WikiJS page, Conversation→session ID

## Deployment

### docker-compose.yml
- Image: build from Dockerfile (multi-stage → scratch)
- Network: `shared` (external)
- Port: `8102` (expose only, nginx proxies)
- Memory: 256m
- Restart: unless-stopped

### .env variables
- `AGE_HOST/PORT/DB/USER/PASSWORD/GRAPH` (PostgreSQL embeddings DB)
- `WIKIJS_HOST/PORT/DB/USER/PASSWORD` (WikiJS DB, same PG server)
- `OLLAMA_URL=http://ollama:11434`, `EMBED_MODEL=qwen3-embedding:8b`, `CHAT_MODEL=qwen3:8b`
- `SEARXNG_URL=http://searxng:8080`
- `OPENALEX_MAILTO=...` (polite pool)
- `KEYCLOAK_*` (OIDC client — new client `kore-search` in realm `sol`)
- `SESSION_KEY`, `BASE_URL`, `PORT=8102`

### Nginx route (add to proxy/nginx.conf)
```nginx
location = /search { return 301 /search/; }
location /search/ {
    set $ks_upstream http://kore-search:8102;
    rewrite ^/search/(.*) /$1 break;
    proxy_pass $ks_upstream;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

### Keycloak
Create confidential OIDC client `kore-search` in realm `sol`:
- Redirect URIs: `https://sol.massimilianopili.com/search/auth/callback`, `http://100.86.46.84/search/auth/callback`
- Standard Flow Enabled

### Dashboard
Add KORE Search card to `/data/massimiliano/proxy/home/index.html`.

## Implementation Phases

### Phase 1: Foundation (Go skeleton + all 5 sources)
1. `mkdir kore-search && cd kore-search && go mod init kore-search`
2. Copy+adapt `auth.go` from knowledge-graph (rename cookie to `ks_session`, change env defaults)
3. Copy+extend `ollama.go` from embedding-viz (add `ChatStream()` method for summarization)
4. Write `main.go`: health, auth routes, static FS, DB connections (embeddings + wikijs)
5. Write all 5 source files:
   - `source_graph.go`: AGE Cypher search (6 labels, CONTAINS, LIMIT 20)
   - `source_vector.go`: pgvector cosine with Ollama embedding
   - `source_web.go`: SearXNG JSON API
   - `source_openalex.go`: OpenAlex REST API
   - `source_wikijs.go`: PG full-text on wikijs DB
6. Write `search.go`: full fan-out orchestrator + weighted RRF merging + deduplication
7. Write `summarize.go`: LLM summary handler (top 10 results → Ollama chat → SSE stream)
8. Create `Dockerfile`, `docker-compose.yml`, `.env`

### Phase 2: Polished UI (Kagi/OpenAlex-inspired)
1. Write `static/index.html`: full single-file UI
   - Landing: centered search bar with tagline + source icons
   - Quick Answer box (SSE streaming, markdown, source citations)
   - Faceted sidebar (source toggles with counts, type filters, year range)
   - Result cards with metadata, source badges, action links
   - Keyboard shortcuts (`/`, `Esc`, `j/k`, `Enter`, `s`)
   - Mobile responsive (sidebar → bottom sheet)
   - Dark mode, Kagi-inspired typography

### Phase 3: Deploy + Integrate
1. Create Keycloak client `kore-search` in realm `sol`
2. Add nginx route `/search/` to proxy/nginx.conf (both :80 and :8888 blocks)
3. `sol deploy kore-search`
4. Add KORE Search card to dashboard home (`proxy/home/index.html`)
5. Register in KORE infrastructure graph (AGE node)

## Verification

1. **Build**: `docker compose build` succeeds (scratch image, ~30MB)
2. **Deploy**: `sol deploy kore-search` starts healthy
3. **Auth**: Visit `https://sol.massimilianopili.com/search/` → Keycloak login → session cookie
4. **Landing**: Centered search bar with tagline, no results yet
5. **Graph search**: Query "transformer" → AGE results with Paper/Concept nodes
6. **Vector search**: Query "attention mechanism" → pgvector semantic results
7. **Web search**: Query "rust async" → SearXNG results appear after ~1s
8. **OpenAlex**: Query "reinforcement learning" → academic papers with citation counts
9. **WikiJS**: Query "nginx" → wiki pages from WikiJS DB
10. **RRF merge**: Results interleaved by score, not grouped by source
11. **Quick Answer**: LLM summary streams above results with [1][2] citations
12. **Filters**: Toggle source off → results from that source disappear
13. **Mobile**: Resize to <768px → sidebar collapses, summary truncates
14. **Keyboard**: Press `/` → search bar focuses, `j/k` navigates results
