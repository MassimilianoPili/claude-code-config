# Piano: Migliorare academic-researcher — stop rate limits & HTML parsing

## Context

L'agente `academic-researcher` spreca tempo e token lottando con rate limits S2 (429) e parsing HTML da DBLP/arXiv. Non produce verdetti strutturati perche' esaurisce il budget prima di sintetizzare.

**Causa radice**: il prompt dell'agente istruisce il fetching manuale di URL raw (S2 API, DBLP HTML, arXiv search), ma il server MCP ha gia' tool server-side che fanno tutto questo internamente senza esporre l'agente ai rate limits:
- `research_validate_paper(title, claimedVenue, claimedYear, claimedCitations, claimedFirstAuthor)` — S2+DBLP+OpenAlex in un singolo call
- `web_fetch(url, extract="semantic_scholar"|"arxiv"|"openalex")` — smart extractors che comprimono 168KB → 3-5KB JSON
- `web_fetch_chunk(fetchId, chunkIndex)` — retrieval chunked per risposte grandi

## Approccio

Due livelli di intervento:

### A. Prompt agente (priorita' alta — impatto immediato)
Riscrivere sezioni critiche di `agents/academic-researcher.md` + `agents/templates/search-endpoints.md`.

### B. Fetch-through cache + async ingest (codice MCP)

Architettura: `web_fetch` diventa un **read-through cache con write-behind ingest**.

```
web_fetch(url, extract="semantic_scholar")
  ├── 1. Redis cache lookup (URL-keyed, DB 8, TTL 24h) → hit? return cached
  ├── 2. HTTP fetch → extract → return to caller
  ├── 3. Write to Redis cache (fire-and-forget, TTL 24h)
  └── 4. INSERT INTO ingest_queue (PostgreSQL, persistent, for nightly job)

web_search(query)
  ├── 1. KORE/pgvector semantic lookup (score > 0.85) → hit? prepend results
  ├── 2. SearXNG search (existing flow)
  └── 3. Return merged results (KORE hits first, then SearXNG)

Nightly drain (03:30):
  ├── SELECT pending items FROM ingest_queue (max 50)
  ├── WebIngestService.ingestFromExtract() → AGE nodes + pgvector embedding
  └── UPDATE status = 'done' / 'error'
```

Il job notturno (nuovo @Scheduled, 03:30) drain la coda:
- SELECT items da `ingest_queue` WHERE status='pending' ORDER BY created_at LIMIT 50
- Per ciascuno: `WebIngestService.ingestFromExtract(json)` → AGE nodes + pgvector embedding
- UPDATE status='done' (o 'error' con messaggio)
- Principio di inesorabilita': max 50 per run, errori non bloccanti, convergenza graduale

**Cache**: Redis DB 8. Key pattern: `cache:fetch:{sha256(url)}` → extracted JSON, TTL 24h.

**Ingest queue**: PostgreSQL (database `embeddings`). Tabella `ingest_queue`:
```sql
CREATE TABLE IF NOT EXISTS ingest_queue (
    id SERIAL PRIMARY KEY,
    url TEXT NOT NULL,
    extracted_json JSONB NOT NULL,
    extract_type VARCHAR(50),  -- 'semantic_scholar', 'arxiv', 'openalex'
    status VARCHAR(20) DEFAULT 'pending',  -- pending, done, error
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_ingest_queue_status ON ingest_queue(status) WHERE status = 'pending';
```
Persistent, transactional, survives restarts. Il nightly drain marca `done`/`error`, non cancella (audit trail).

## Parte B: Modifiche codice MCP

### File da creare

#### B1. `FetchCacheConfig.java` (nuovo)
**Path**: `Vari/mcp/src/main/java/com/example/mcp/tools/FetchCacheConfig.java`

- `@Configuration` + `@ConditionalOnProperty(name = "mcp.redis.enabled")`
- Redis DB 8 (dedicato), `LettuceConnectionFactory` + `ReactiveStringRedisTemplate`
- Costanti: `CACHE_DB = 8`, `CACHE_TTL = Duration.ofHours(24)`, `INGEST_QUEUE = "ingest:pending"`, `INGEST_BATCH_SIZE = 50`
- Pattern: copiare da `WebFetchChunkConfig.java` (stessa struttura)

#### B2. `FetchCacheService.java` (nuovo)
**Path**: `Vari/mcp/src/main/java/com/example/mcp/tools/FetchCacheService.java`

- `@Service` + `@ConditionalOnProperty(name = "mcp.redis.enabled")`
- Inject `@Qualifier("fetchCacheRedisTemplate") ReactiveStringRedisTemplate`
- **`getCached(url)`**: `GET cache:fetch:{sha256(url)}` → Mono<String> (null se miss)
- **`putCache(url, extractedJson)`**: `SET cache:fetch:{sha256(url)} extractedJson EX 86400` (fire-and-forget)

#### B2b. `IngestQueueRepository.java` (nuovo)
**Path**: `Vari/mcp/src/main/java/com/example/mcp/tools/IngestQueueRepository.java`

- `@Repository`
- Inject `JdbcTemplate` (database `embeddings`, gia' configurato per pgvector)
- **`enqueue(url, extractedJson, extractType)`**: `INSERT INTO ingest_queue(url, extracted_json, extract_type) VALUES(?, ?::jsonb, ?)`
- **`drainPending(maxItems)`**: `SELECT id, extracted_json FROM ingest_queue WHERE status='pending' ORDER BY created_at LIMIT ?` + `UPDATE status='processing'`
- **`markDone(id)`**: `UPDATE ingest_queue SET status='done', processed_at=NOW() WHERE id=?`
- **`markError(id, message)`**: `UPDATE ingest_queue SET status='error', error_message=?, processed_at=NOW() WHERE id=?`
- Init: eseguire `CREATE TABLE IF NOT EXISTS` al bootstrap (pattern `@PostConstruct` o Flyway migration)

#### B3. `KoreLookupService.java` (nuovo)
**Path**: `Vari/mcp/src/main/java/com/example/mcp/tools/KoreLookupService.java`

- `@Service`
- Inject `VectorStore` (pgvector)
- **`searchSemantic(query, limit)`**: `vectorStore.similaritySearch(query, limit)` → risultati con score > 0.85
- Formatta risultati come JSON array compatto: `[{title, source, type, score, snippet}]`
- Usato SOLO da `webSearch()` per arricchire i risultati, NON da `webFetch()`

#### B4. Modificare `WebSearchTools.java`
**Path**: `Vari/mcp/src/main/java/com/example/mcp/tools/WebSearchTools.java`

Inject (opzionali):
```java
@Autowired(required = false) private FetchCacheService fetchCache;
@Autowired(required = false) private KoreLookupService koreLookup;
```

**Modificare `webFetch()`** — aggiungere Redis cache prima dell'HTTP:
```java
// Prima di httpClient.get():
if (extract != null && !extract.isBlank() && fetchCache != null) {
    String cached = fetchCache.getCached(url).block(); // Redis locale ~1ms
    if (cached != null) {
        log.info("web_fetch cache hit per '{}'", url);
        return Mono.just(cached);
    }
}
// HTTP fetch (codice esistente)
```

**Modificare `processResponse()`** — dopo extraction, cache + queue (fire-and-forget):
```java
if (extracted != null) {
    if (fetchCache != null) {
        fetchCache.putCache(url, extracted).subscribe(); // Redis cache
    }
    if (ingestQueue != null) {
        ingestQueue.enqueue(url, extracted, extract); // PG queue (persistent)
    }
    return Mono.just(extracted);
}
```

Inject aggiuntivo in `WebSearchTools`:
```java
@Autowired(required = false) private IngestQueueRepository ingestQueue;
```

**Modificare `webSearch()`** — prepend KORE results:
```java
// All'inizio di webSearch(), prima di SearXNG:
if (koreLookup != null) {
    String koreResults = koreLookup.searchSemantic(query, 3);
    if (koreResults != null && !koreResults.equals("[]")) {
        // Prepend KORE results, poi SearXNG sotto
        // Format: "--- From KORE ---\n{results}\n--- Web results ---\n{searxng}"
    }
}
```

#### B5. `ScheduledIngestDrain.java` (nuovo)
**Path**: `Vari/mcp/src/main/java/com/example/mcp/ScheduledIngestDrain.java`

- `@Component`
- Inject `IngestQueueRepository` + `WebIngestService`
- `@Scheduled(cron = "0 30 3 * * *")` — 03:30, prima del reindex delle 04:00
- Drain: `ingestQueue.drainPending(50)` → per ciascuno:
  - `webIngestService.ingestFromExtract(json)` → se OK: `markDone(id)`, se errore: `markError(id, msg)`
- Log: `"Ingest drain: processed N items, M success, K errors"`
- Principio inesorabilita': max 50 per run, errori loggati ma non bloccanti, retry al prossimo ciclo

#### B6. Modificare `ResearchValidationTools.java` — aggiungere cache + auto-ingest
**Path**: `Vari/mcp/src/main/java/com/example/mcp/tools/ResearchValidationTools.java`

Attualmente `research_validate_paper` chiama S2+DBLP+OpenAlex direttamente OGNI volta — stessi rate limits di prima, solo spostati server-side. 10 paper = 30 API calls = S2 429 dopo ~5.

Inject:
```java
@Autowired(required = false) private FetchCacheService fetchCache;
@Autowired(required = false) private IngestQueueRepository ingestQueue;
```

**Cache**: prima di fetchare S2, controllare Redis:
- Key: `cache:validate:{sha256(title_normalized)}`
- TTL: 24h
- Se hit: return cached validation result
- Se miss: fetch come ora → cache result + queue per ingest

**Auto-ingest**: dopo validation success (status != ERROR):
- `ingestQueue.enqueue(url, validationToExtract(result), "validation")`
- `validationToExtract()`: converte il validation JSON nel formato extract (titolo, autori, anno, venue, citazioni) che `WebIngestService.ingestFromExtract` sa processare

Questo è il miglioramento più impattante — `research_validate_paper` è il tool più chiamato dall'agente, e la cache elimina i rate limits per paper già validati.

### Nessuna nuova env var necessaria
- Redis gia' configurato (`mcp.redis.url`, `mcp.redis.enabled`)
- VectorStore gia' configurato
- AGE gia' configurato
- DB 8 non richiede configurazione speciale (Lettuce lo seleziona)

---

## Parte A: Modifiche prompt agente

## Modifiche al file `agents/academic-researcher.md`

### 1. Sezione TOOL NAMES — aggiungere i tool mancanti

Aggiungere sotto la lista attuale:
```
- Smart fetch: `mcp__simoge-mcp__web_fetch` con parametro `extract` ("semantic_scholar", "arxiv", "openalex")
- Chunked retrieval: `mcp__simoge-mcp__web_fetch_chunk` per risposte > 6KB
- Paper validation (ALL-IN-ONE): `mcp__simoge-mcp__research_validate_paper` — S2+DBLP+OpenAlex server-side
```

### 2. Nuova sezione — FETCHING RULES (prima di PAPER VALIDATION PROTOCOL)

```markdown
## FETCHING RULES — MANDATORY

### Rule 1: Never fetch raw HTML
DBLP, arXiv search, PubMed search results are HTML pages. Do NOT `web_fetch` them.
- Paper validation → `research_validate_paper` (server-side, no rate limits)
- Paper search → `web_search("site:arxiv.org <query>")` or `web_search("site:semanticscholar.org <query>")`
- Paper metadata → `web_fetch(S2_API_URL, extract="semantic_scholar")` or `web_fetch(OpenAlex_URL, extract="openalex")`

### Rule 2: Always use extract parameter for APIs
- Semantic Scholar API → `web_fetch(url, extract="semantic_scholar")` → 3-5KB JSON
- OpenAlex API → `web_fetch(url, extract="openalex")` → 3-5KB JSON
- arXiv API → `web_fetch(url, extract="arxiv")` → compact JSON
- Raw `web_fetch(url)` without extract → ONLY for blog posts, news, generic pages

### Rule 3: One 429 = switch source immediately
If any API returns HTTP 429 or timeout:
- S2 → switch to OpenAlex API immediately (no retry)
- OpenAlex → switch to `web_search` (no retry)
- Never retry the same endpoint twice in one session

### Rule 4: Skeleton first, data second
Before ANY fetching, write the output skeleton (headings, tables, sections) to the output file.
Fill in data as you get it. This guarantees structured output even if fetches fail partially.
Mark unfetched fields as `[PENDING]` → fill → or mark `[FETCH FAILED — not reported]`.
```

### 3. Riscrivere PAPER VALIDATION PROTOCOL — "tool-first"

Il manuale workflow attuale (fetch S2 API → cross-check DBLP HTML → ...) diventa fallback di emergenza.

```markdown
## PAPER VALIDATION PROTOCOL

### Primary workflow (USE THIS)
For every paper to validate, call:
```
research_validate_paper(title="...", claimedVenue="...", claimedYear=2023, claimedCitations=1000, claimedFirstAuthor="Smith")
```
This single call performs S2 + DBLP + OpenAlex validation server-side and returns structured corrections.
No rate limits, no HTML parsing, no token waste.

### Enrichment (optional, after primary)
If you need deeper metadata (citations list, concepts, co-authors):
```
web_fetch("https://api.openalex.org/works?search=<title>&per_page=3", extract="openalex")
```
OpenAlex has no rate limits (polite pool with mailto header).

### Emergency fallback (only if research_validate_paper is unavailable)
[keep existing manual workflow but clearly marked as emergency-only]
```

### 4. Riscrivere SEARCH FAILURE RECOVERY

Semplificare drasticamente:
```markdown
## SEARCH FAILURE RECOVERY

1. `research_validate_paper` fails → `web_fetch(OpenAlex_URL, extract="openalex")`
2. OpenAlex fails → `web_search("site:semanticscholar.org <title>")`
3. S2 returns 429 → switch to OpenAlex immediately (NO retry)
4. All APIs fail → state in output: "Validation failed — [FETCH FAILED]" and move on
5. NEVER spend more than 2 attempts per paper. Move on and note the gap.
```

### 5. Rimuovere dalla sezione search-endpoints.md i raw HTML URL

In `agents/templates/search-endpoints.md`:
- Rimuovere o commentare le URL di DBLP HTML search (`https://dblp.org/search?q=...`)
- Rimuovere arXiv HTML search (`https://arxiv.org/search/?query=...`)
- Mantenere solo le API JSON endpoints (S2 Graph API, OpenAlex API, arXiv API XML)
- Aggiungere nota: "Per validation usare research_validate_paper, non fetch manuali"

### 6. Aggiungere TIME BUDGET nella sezione RESEARCH WORKFLOW

Dopo Step 1 (Classify), aggiungere:
```markdown
### Time Budget
- 30% classifying + reading templates + planning searches
- 40% fetching + validation (use research_validate_paper, not manual)
- 30% synthesis + writing structured output
If fetching consumes >50% and you haven't started writing, STOP fetching and synthesize with what you have.
```

### 7. Aggiornare KNOWLEDGE GRAPH INTEGRATION

Cambiare "Neo4j" → "AGE" (gia' migrato). Aggiungere menzione di `web_ingest_from_extract` per persistenza.

### 8. Nuova sezione — PARALLEL VALIDATION (dentro PAPER VALIDATION PROTOCOL)

```markdown
### Parallel Validation
When validating multiple papers (e.g., Template F with 5+ references):
- Call `research_validate_paper` for ALL papers in PARALLEL (multiple tool calls in one message)
- Do NOT validate sequentially — this wastes time and increases rate limit risk
- Results are cached server-side (24h), so repeated validation of the same paper is free
- After receiving all results, write the validation table in one pass
```

### 9. Nuova sezione — PERSISTENCE PROTOCOL (dopo KNOWLEDGE GRAPH INTEGRATION)

```markdown
## PERSISTENCE PROTOCOL — KORE Integration

After validating or discovering a paper, persist it to KORE for future sessions:

### When to persist
- Every paper validated with `research_validate_paper` → persist if validation succeeded
- Every paper found via `web_fetch(extract=...)` → persist the extract
- Blog posts and docs that were useful → `web_ingest(url, title, contentType="blog", body=...)`

### How to persist
1. After `web_fetch(url, extract="semantic_scholar")` returns JSON → call `web_ingest_from_extract(result)`
2. After `research_validate_paper` returns structured data → call `web_ingest(url, title, contentType="paper", body=abstract, ...)`
3. This creates AGE nodes (Paper/Author/Venue) + pgvector embedding. Future searches find these via `embeddings_search_docs`.

### Budget: max 1 ingest call per paper validated. Don't ingest duplicates or failed fetches.
```

## Riepilogo file

| File | Tipo | Modifica |
|------|------|----------|
| `Vari/mcp/.../FetchCacheConfig.java` | Nuovo | Redis DB 8 config |
| `Vari/mcp/.../FetchCacheService.java` | Nuovo | Cache get/put |
| `Vari/mcp/.../IngestQueueRepository.java` | Nuovo | PG queue CRUD |
| `Vari/mcp/.../KoreLookupService.java` | Nuovo | pgvector semantic search per web_search |
| `Vari/mcp/.../WebSearchTools.java` | Modifica | Cache in webFetch, KORE in webSearch, auto-queue |
| `Vari/mcp/.../ResearchValidationTools.java` | Modifica | Cache + auto-ingest |
| `Vari/mcp/.../ScheduledIngestDrain.java` | Nuovo | Nightly drain 03:30 |
| `agents/academic-researcher.md` | Modifica | Sezioni 1-4, 6-9 prompt |
| `agents/templates/search-endpoints.md` | Modifica | Sezione 5 — rimuovere HTML URLs |

## Sequenza implementazione

1. **Parte B** (codice MCP): B1→B2→B3→B4→B5 → build → deploy
2. **Parte A** (prompt): sezioni 1-8 nell'agente + search-endpoints.md
3. **Test end-to-end**

## Verifica

### Parte B — Cache + KORE search + ingest
1. `web_fetch("https://api.semanticscholar.org/graph/v1/paper/search?query=attention+is+all+you+need&fields=title,year,citationCount&limit=3", extract="semantic_scholar")` → primo call: HTTP fetch, return JSON compatto
2. Stesso call di nuovo → deve tornare da Redis cache (log "cache hit")
3. `redis-cli -n 8 KEYS "cache:fetch:*"` → verifica key presente con TTL ~24h
4. `db_query("SELECT count(*) FROM ingest_queue WHERE status='pending'", database="embeddings")` → verifica item in coda PG
5. Trigger manuale drain o attendere 03:30 → verificare AGE nodes creati + status='done'
6. `graph_query("MATCH (p:Paper) WHERE p.title CONTAINS 'Attention' RETURN p.title, p.year", backend="age")` → nodo presente
7. `web_search("attention mechanism transformers")` → i risultati devono includere sezione "From KORE" con il paper appena ingestato

### Parte A — Prompt agente
7. Lanciare un research agent con Template F su 3-4 paper → deve usare `research_validate_paper` e NON fetchare DBLP HTML
8. Verificare output strutturato anche se qualche fetch fallisce (skeleton-first)
9. Seconda call sugli stessi paper → KORE/cache hit, zero rate limits
