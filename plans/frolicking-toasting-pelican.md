# Piano: B.1 OpenAlex API Cascade + B.2 MCP Tools OpenAlex

## Context

OpenAlex è la più grande base dati accademica aperta (~250M works). L'integrazione in due punti:
1. **paper_archive.py** — aggiungere OpenAlex nella cascade di risoluzione citazioni (tra Semantic Scholar e CrossRef)
2. **simoge-mcp** — due nuovi tool MCP per query dirette da Claude Code

Il codebase ha già supporto parziale OpenAlex: `ApiExtractors.extractOpenAlex()`, `reconstructAbstract()`, `ResearchValidationTools.fetchOpenAlex()`. Riusiamo tutto.

---

## B.1 — OpenAlex nella API cascade di paper_archive.py

### File da modificare
- `/data/massimiliano/kindle/paper_archive.py`
- `/data/massimiliano/shell-scripts/bin/paper-archive` (env var)

### Prerequisito
```bash
pip install --user pyalex
```

### Implementazione

#### 1. Import e config (dopo riga ~42)
```python
import pyalex
pyalex.config.api_key = os.environ.get("OPENALEX_API_KEY", "")
pyalex.config.email = "massimiliano@example.com"  # polite pool
```

#### 2. Nuova funzione `resolve_via_openalex()` (~50 righe, dopo `resolve_via_crossref()` riga 363)
- Query: `Works().search(title).filter(publication_year=year)` se anno disponibile
- Select fields: `id, title, authorships, publication_year, doi, topics, primary_location, cited_by_count, abstract_inverted_index, referenced_works`
- Match best: confronto titolo case-insensitive
- Estrae: title, abstract (ricostruito da pyalex automaticamente), authors, year, doi, venue, citation_count, openalex_id, topics (top 5, score > 0.3), institutions, referenced_works
- Return dict compatibile con formato esistente + campi extra (topics, institutions, openalex_id)

#### 3. Inserire nella cascade `resolve_citation()` (tra riga 394 e 396)
```python
# 2.5 OpenAlex
time.sleep(API_DELAY)
oa_data = resolve_via_openalex(ref["title"], ref.get("year"))
if oa_data and oa_data.get("abstract"):
    resolved.update({k: v for k, v in oa_data.items() if v})
    return resolved
```

#### 4. Aggiornare `generate_wiki_content()` (riga ~411)
- Aggiungere riga "Topics" nella tabella metadata se disponibili
- Aggiungere "OpenAlex ID" se presente

#### 5. Wrapper `paper-archive`
```bash
export OPENALEX_API_KEY="${OPENALEX_API_KEY:-}"
```

### Funzioni esistenti da riusare
- `api_request()` (riga 197) — NON usata per OpenAlex (pyalex gestisce HTTP)
- `time.sleep(API_DELAY)` — delay tra chiamate
- Pattern return dict da `resolve_via_semantic_scholar()` (riga 257)

---

## B.2 — OpenAlexTools.java per MCP

### File da creare
- `/data/massimiliano/Vari/mcp/src/main/java/com/example/mcp/tools/OpenAlexTools.java`

### File da modificare
- `/data/massimiliano/Vari/mcp/docker-compose.yml` — aggiungere `OPENALEX_API_KEY` (opzionale, API pubblica)

### Implementazione

#### Classe `OpenAlexTools.java` — 2 tool

**Pattern**: copiare da `Context7Tools.java` (classe semplice, WebClient, @ReactiveTool)

```java
@Service
public class OpenAlexTools {
    private final WebClient openAlexClient = WebClient.builder()
        .baseUrl("https://api.openalex.org")
        .defaultHeader("Accept", "application/json")
        .defaultHeader("User-Agent", "mailto:massimiliano@example.com")
        .codecs(c -> c.defaultCodecs().maxInMemorySize(2 * 1024 * 1024))
        .build();

    @ReactiveTool(name = "openalex_search", description = "...")
    public Mono<String> openalexSearch(
        @ToolParam(description = "Query di ricerca") String query,
        @ToolParam(description = "Filtri OpenAlex, es: publication_year:>2020,cited_by_count:>100") String filters,
        @ToolParam(description = "Numero massimo risultati (default 5, max 25)") int maxResults
    ) {
        // GET /works?search={query}&filter={filters}&per_page={maxResults}&select=...
        // Parsing con ApiExtractors.extractOpenAlex()
        // Timeout 15s, onErrorResume
    }

    @ReactiveTool(name = "openalex_neighborhood", description = "...")
    public Mono<String> openalexNeighborhood(
        @ToolParam(description = "OpenAlex ID del paper, es: W2741809807") String paperId,
        @ToolParam(description = "Direzione: cites, cited_by, related") String direction,
        @ToolParam(description = "Numero massimo risultati (default 10, max 25)") int maxResults
    ) {
        // cites: GET /works?filter=cites:{paperId}&per_page={maxResults}
        // cited_by: GET /works?filter=cited_by:{paperId}&per_page={maxResults}
        // related: GET /works?filter=related_to:{paperId}&per_page={maxResults}
        // Parsing con ApiExtractors.extractOpenAlex()
    }
}
```

### Funzioni esistenti da riusare
- `ApiExtractors.extractOpenAlex(String json)` (riga 176, ApiExtractors.java) — normalizzazione output
- `ApiExtractors.reconstructAbstract(JsonNode)` (riga 358) — chiamato internamente da extractOpenAlex
- Pattern WebClient da `Context7Tools.java` (riga 1-53)
- Pattern retry/timeout da `WebSearchTools.java` (riga 120-125)

### Docker compose
```yaml
OPENALEX_API_KEY: "${OPENALEX_API_KEY:-}"  # opzionale, API pubblica 100 req/sec
```

---

## Ordine di implementazione

1. `pip install --user pyalex` su SOL
2. `resolve_via_openalex()` in paper_archive.py
3. Inserimento nella cascade
4. `generate_wiki_content()` aggiornamento
5. Test: `paper-archive --dry-run --single "Portfolio Selection"`
6. Test: `paper-archive --single "Portfolio Selection"`
7. `OpenAlexTools.java` (può essere fatto in parallelo a 2-6)
8. `sol deploy mcp`
9. Test MCP: `openalex_search("attention mechanism", "cited_by_count:>100", 5)`

---

## Verifica

### B.1
```bash
paper-archive --dry-run --single "Portfolio Selection"   # verifica cascade
paper-archive --single "Portfolio Selection"              # test reale
```

### B.2
```bash
sol deploy mcp
# Da Claude Code:
openalex_search("attention mechanism", "publication_year:>2020,cited_by_count:>100", 5)
openalex_neighborhood("W2741809807", "cited_by", 5)
```

---

## File critici (riferimenti esplorazione)

| File | Righe chiave |
|------|-------------|
| `kindle/paper_archive.py` | `resolve_citation()` 366-406, `resolve_via_semantic_scholar()` 257-301, `resolve_via_crossref()` 304-363, `generate_wiki_content()` 411-466, `generate_mini_doc()` 716-747 |
| `Vari/mcp/.../ApiExtractors.java` | `extractOpenAlex()` 176-275, `reconstructAbstract()` 358-389 |
| `Vari/mcp/.../Context7Tools.java` | Pattern @ReactiveTool + WebClient 1-53 |
| `Vari/mcp/.../WebSearchTools.java` | Retry/timeout pattern 120-125 |
| `Vari/mcp/.../ResearchValidationTools.java` | `fetchOpenAlex()` 168-188 (referenza) |
| `shell-scripts/bin/paper-archive` | Wrapper, aggiungere OPENALEX_API_KEY |
