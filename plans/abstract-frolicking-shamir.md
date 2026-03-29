# Piano: Chunked web_fetch + Smart Extractors + Web Ingest

## Context

**Problema 1**: Il tool MCP `web_fetch` ritorna risposte fino a 2MB come singola stringa. Quando la risposta supera ~25k token (es. Semantic Scholar API con citazioni: 168KB), Claude Code salva il risultato su disco ma il tool Read non riesce a rileggerlo (hard limit 25k token). L'agent `academic-researcher` riceve solo 2KB di preview e perde il resto.

**Problema 2**: I contenuti fetchati dal web (paper, blog, documentazione) non vengono archiviati nel knowledge graph. Ogni ricerca è effimera — l'agent non costruisce conoscenza persistente.

**Soluzione**: Tre componenti integrate nello stesso deploy:
1. **Chunked web_fetch** — risposte grandi → chunk su Redis, retrieval on-demand
2. **Smart extractors** — per API note (Semantic Scholar, arXiv, OpenAlex) → JSON compatto senza chunking
3. **Web ingest tool** — qualsiasi contenuto fetchato → nodi AGE + embedding pgvector

---

## Parte 1: Chunked web_fetch

### File da creare

#### 1.1 `WebFetchChunkConfig.java` (nuovo)
**Path**: `Vari/mcp/src/main/java/com/example/mcp/tools/WebFetchChunkConfig.java`

- `@Configuration` + `@ConditionalOnProperty(name = "mcp.redis.enabled")`
- Redis DB 6 (dedicato), `LettuceConnectionFactory` + `ReactiveStringRedisTemplate`
- Costanti: `CHUNK_SIZE = 6KB`, `CHUNK_TTL = 10min`
- Pattern da seguire: `mcp-redis-tools/src/.../RedisConfig.java`

#### 1.2 `ChunkedFetchService.java` (nuovo)
**Path**: `Vari/mcp/src/main/java/com/example/mcp/tools/ChunkedFetchService.java`

- `@Service` + `@ConditionalOnProperty(name = "mcp.redis.enabled")`
- **`storeAndReturnFirst(content, url, contentType)`**: split in chunk, salva su Redis (`fetch:{uuid}:{i}`, TTL 10min), ritorna JSON envelope con primo chunk + metadati
- **`getChunk(fetchId, chunkIndex)`**: recupera chunk specifico, valida indice, gestisce scadenza
- Redis key pattern: `fetch:{uuid}:meta`, `fetch:{uuid}:{index}`

### File da modificare

#### 1.3 `WebSearchTools.java` (modifica)
**Path**: `Vari/mcp/src/main/java/com/example/mcp/tools/WebSearchTools.java`

- Inject `ChunkedFetchService` (opzionale, `@Autowired(required = false)`)
- **`webFetch(url, extract)`**: aggiungere parametro `extract` (opzionale: `"semantic_scholar"`, `"arxiv"`, `"openalex"`, null)
  - Se `extract` specificato → smart extraction (vedi Parte 2), ritorna JSON compatto
  - Se risposta ≤ 6KB → ritorna inline (backward compatible)
  - Se risposta > 6KB + Redis disponibile → `storeAndReturnFirst()`
  - Se risposta > 6KB + Redis non disponibile → tronca con warning
- **`webFetchChunk(fetchId, chunkIndex)`**: nuovo tool `web_fetch_chunk`, delega a `ChunkedFetchService.getChunk()`

### Formato risposta chunked
```json
{
  "fetch_id": "uuid",
  "chunk_index": 0,
  "total_chunks": 28,
  "total_size_bytes": 168432,
  "citations_returned": 500,
  "content_type": "application/json",
  "url": "https://...",
  "ttl_seconds": 600,
  "content": "... primi 6KB ..."
}
```

---

## Parte 2: Smart Extractors

Tre extractors per API note. Ciascuno comprime la risposta API a 3-5KB estraendo solo campi informativi. Se il parse fallisce → fallback al chunking generico.

#### 2.1 `ApiExtractors.java` (nuovo)
**Path**: `Vari/mcp/src/main/java/com/example/mcp/tools/ApiExtractors.java`

Classe utility con metodi statici. Jackson `ObjectMapper` per JSON, regex/SAX per XML.

**`extractSemanticScholar(json)`** → output:
```json
{
  "extracted_from": "semantic_scholar",
  "paperId": "1733eb...",
  "title": "Lost in the Middle...",
  "year": 2023,
  "venue": "TACL",
  "citationCount": 3059,
  "influentialCitationCount": 184,
  "citations_returned": 500,
  "tldr": "Performance degrades when...",
  "authors": ["Nelson F. Liu", "Kevin Lin", ...],
  "citations_top20": [{"title": "...", "year": 2024, "citationCount": 45}],
  "references_top20": [{"title": "...", "year": 2022, "citationCount": 120}]
}
```
Logica: copia campi scalari, `authors[]` → solo `.name`, `citations[]` → ordina per citationCount DESC → top 20 con {title, year, citationCount}. Include `citations_returned` = dimensione array originale.

**`extractArxiv(xml)`** → output:
```json
{
  "extracted_from": "arxiv",
  "arxivId": "2307.03172",
  "title": "...",
  "abstract": "...",
  "authors": ["Nome1", "Nome2"],
  "categories": ["cs.CL", "cs.AI"],
  "published": "2023-07-06",
  "updated": "2024-01-15",
  "pdfUrl": "https://arxiv.org/pdf/2307.03172"
}
```

**`extractOpenAlex(json)`** → output:
```json
{
  "extracted_from": "openalex",
  "openAlexId": "W2741809807",
  "doi": "https://doi.org/10.1162/tacl_a_00638",
  "title": "...",
  "year": 2023,
  "citedByCount": 3059,
  "type": "journal-article",
  "authors": [{"name": "Nelson F. Liu", "orcid": "0000-...", "institution": "Stanford"}],
  "concepts": [{"name": "Language model", "level": 2, "score": 0.95}],
  "venue": {"name": "TACL", "type": "journal", "issn": "2307-387X"},
  "pdfUrl": "https://...",
  "referencedWorksCount": 45,
  "citationsByYear": [{"year": 2024, "count": 1200}]
}
```
OpenAlex API: `https://api.openalex.org/works/<id>` o `?search=<query>`. Nessuna API key necessaria (polite pool con `mailto:` header). Campi chiave: `concepts` (tassonomia gerarchica Wikidata), `authorships[].institutions`, `counts_by_year`.

---

## Parte 3: Web Ingest (AGE + pgvector)

Tool generico per archiviare qualsiasi contenuto web nel knowledge graph e embedding store.

#### 3.1 `WebIngestService.java` (nuovo)
**Path**: `Vari/mcp/src/main/java/com/example/mcp/tools/WebIngestService.java`

`@Service`. Dipendenze: `AgeCypherExecutor` (da mcp-graph-tools, già nel classpath), `VectorStore` (da mcp-vector-tools, Spring AI PgVectorStore), `OllamaEmbeddingClient` (Ollama HTTP).

**Metodo principale: `ingest(WebContent content)`**

Input `WebContent` (record o DTO):
```java
record WebContent(
    String url,           // fonte originale
    String title,         // titolo estratto
    String contentType,   // "paper", "blog", "docs", "generic"
    String body,          // testo completo
    Map<String, Object> metadata  // campi strutturati (autori, anno, venue, concepts...)
)
```

**Flusso a 3 fasi** (pattern da `paper_archive.py`):

**Fase 1 — Nodi AGE** (MERGE idempotente):
- Nodo principale: label basato su `contentType`
  - `"paper"` → `Paper` (archival_id=slug, title, year, doi, abstract, citation_count, source=url)
  - `"blog"` → `BlogPost` (nuovo label, slug, title, author, date, source=url)
  - `"docs"` → `Documentation` (nuovo label, slug, title, source=url)
  - `"generic"` → `WebContent` (nuovo label, slug, title, source=url)
- Nodi correlati: `Author` (MERGE per nome), `Venue`/`Source` (MERGE per nome)
- Tutti con `domain = "personal"`, `last_modified = NOW()`

**Fase 2 — Relazioni AGE**:
- `WRITTEN_BY` (contenuto → Author)
- `PUBLISHED_IN` (paper → Venue) o `FROM_SOURCE` (blog → Source)
- `HAS_CONCEPT` (contenuto → Concept, se disponibili da OpenAlex)

**Fase 3 — Embedding pgvector**:
- Genera mini-doc (pattern da `paper_archive.py` linee 716-747):
  ```
  <Type>: <title>
  Authors: <authors>. Year: <year>.
  <abstract/body excerpt (max 1000 chars)>
  Source: <url>
  Concepts: <concept1>, <concept2>
  ```
- Embedding via Ollama `mxbai-embed-large` (1024 dim)
- Upsert in `vector_store` con metadata: `{type: "docs", label: "<Type>", name: "<slug>", domain: "personal", source: "<url>"}`

#### 3.2 `WebIngestTools.java` (nuovo)
**Path**: `Vari/mcp/src/main/java/com/example/mcp/tools/WebIngestTools.java`

`@ReactiveTool` class. Due tool esposti:

**`web_ingest(url, title, content_type, body, authors, year, venue, concepts)`**
- Parametri obbligatori: `url`, `title`, `body`
- Parametri opzionali: `content_type` (default "generic"), `authors`, `year`, `venue`, `concepts`
- Chiama `WebIngestService.ingest()`
- Ritorna: `{status: "ok", nodes_created: [...], embedding_id: "uuid"}`

**`web_ingest_from_extract(extracted_json)`**
- Prende l'output di un extractor (Semantic Scholar, arXiv, OpenAlex) direttamente
- Mappa automaticamente i campi al formato `WebContent`
- Shortcut: l'agent fa `web_fetch(url, extract="semantic_scholar")` → riceve JSON → lo passa a `web_ingest_from_extract()`

### Pattern esistenti da riutilizzare

| Cosa | Dove | Come |
|------|------|------|
| AGE Cypher execution | `mcp-graph-tools/.../AgeCypherExecutor.java` | `execute(cypher, params)` — stesso connection, `LOAD 'age'`, dollar-quoting |
| MERGE idempotente | `kindle/paper_archive.py` L565-627 | `MERGE (p:Paper {archival_id: 'slug'}) SET p.title = ...` |
| Escape Cypher strings | `kindle/paper_archive.py` L54-58 | `'` → `\'`, `\\` → `\\\\`, newlines stripped |
| Embedding generation | `kindle/paper_archive.py` L839-874 | POST `http://ollama:11434/api/embed` con model `mxbai-embed-large` |
| Embedding upsert SQL | `kindle/paper_archive.py` L849-874 | `INSERT INTO vector_store` con metadata JSONB |
| Mini-doc format | `kindle/paper_archive.py` L716-747 | `Paper: <title>\nAuthors: ...\n<abstract>` |
| Batch size | `mcp-vector-tools/.../ChunkingService.java` | `BATCH_SIZE = 20` |
| @ReactiveTool pattern | `mcp-redis-tools/.../RedisTools.java` | Auto-discovery, no explicit `ToolCallbackProvider` |

---

## Nessuna modifica necessaria a

- `pom.xml` — Jackson, Lettuce, Spring AI già nel classpath (mcp-graph-tools e mcp-vector-tools sono dipendenze)
- `docker-compose.yml` — Redis e Ollama già configurati sulla rete `shared`
- `application.properties` — usa `mcp.redis.url` e connection pool esistenti
- Nessuna nuova env var

---

## Sequenza implementazione

### Blocco 1: Chunking (autonomo)
1. Creare `WebFetchChunkConfig.java` — config Redis DB 6
2. Creare `ChunkedFetchService.java` — logica chunk + retrieval
3. Creare `ApiExtractors.java` — 3 extractors statici (Semantic Scholar, arXiv, OpenAlex)
4. Modificare `WebSearchTools.java` — parametro `extract`, chunking, nuovo tool `web_fetch_chunk`
5. **Test**: build + deploy + verificare chunking e extractors

### Blocco 2: Ingest (dipende da Blocco 1 solo per extractors)
6. Creare `WebIngestService.java` — logica AGE write + embedding
7. Creare `WebIngestTools.java` — 2 tool MCP (`web_ingest`, `web_ingest_from_extract`)
8. **Test**: build + deploy + verificare ingest paper + query graph

### Build & Deploy
```bash
cd /data/massimiliano/Vari/mcp
/opt/maven/bin/mvn clean install -Dgpg.skip=true
sol deploy mcp
```

---

## Verifica

### Chunking
1. `web_fetch("https://api.semanticscholar.org/graph/v1/paper/search?query=attention&fields=title,abstract,authors,citations.title&limit=10")` → chunked (envelope + primo chunk)
2. `web_fetch_chunk(fetch_id, 1)` → secondo chunk
3. URL piccolo (< 6KB) → risposta diretta (backward compatible)
4. `redis-cli -n 6 KEYS "fetch:*"` → verificare presenza e scadenza

### Smart extraction
5. `web_fetch("https://api.semanticscholar.org/graph/v1/paper/1733eb7792f7a43dd21f51f4d1017a1bffd217b5?fields=title,abstract,authors,year,citationCount,citations.title,citations.year,citations.citationCount,tldr", extract="semantic_scholar")` → JSON compatto 3-5KB con `citations_returned`
6. `web_fetch("https://api.openalex.org/works/W2741809807", extract="openalex")` → JSON con concepts, institutions

### Web ingest
7. `web_ingest_from_extract(<output del test 5>)` → nodi Paper+Author+Venue in AGE + embedding
8. `graph_query("MATCH (p:Paper {title: 'Lost in the Middle'}) RETURN p", backend="age")` → nodo presente
9. `embeddings_search_docs("language models long context position")` → hit sull'embedding appena creato

---

## Nota: Parallel cancellation

Il "Cancelled: parallel tool call" è un bug/limitazione lato Claude Code client, non MCP. Non risolvibile da questo piano. Workaround: usare chiamate sequenziali o subagent `Task` per isolare chiamate critiche.
