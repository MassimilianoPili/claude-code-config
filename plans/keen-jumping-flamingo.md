# Piano: Integrazione OpenAlex — Revisione Completa

## Context

Integrare OpenAlex nel sistema paper_archive per creare un motore di ricerca accademico personale.
Il piano originale (`PIANO_OPENALEX.md`) va rivisto sulla base di:
- **API key obbligatoria** dal Feb 2025 (mailto polite pool deprecato)
- **Concepts deprecati** → sostituiti da Topics (4 livelli: Domain > Field > Subfield > Topic)
- **S3 data = JSONL.gz** non Parquet nativo → ma reso irrilevante dalla CLI ufficiale
- **Due pacchetti Python ufficiali**: `pyalex` (API wrapper) + `openalex-official` (bulk download CLI)
- **Embedding: restare su 1024 dim** con mxbai-embed-large (e5-mistral-7b impraticabile senza GPU)

Email per API key: `carloaugiass+openalex@gmail.com`

---

## Step 1 — API Cascade con pyalex

**Obiettivo**: Aggiungere OpenAlex come terza fonte nella cascade (arXiv → S2 → **OpenAlex** → CrossRef).

**File da modificare**: `/data/massimiliano/kindle/paper_archive.py`

### Dipendenze
```bash
pip install --user pyalex  # 15KB, unica dipendenza: requests (già presente)
```

### Funzioni da aggiungere (~50 righe)

```python
# Configurazione (top-level, vicino a riga 32)
import pyalex
pyalex.config.api_key = os.environ.get("OPENALEX_API_KEY", "")

# Nuova funzione
def resolve_via_openalex(title, year=None):
    """Query OpenAlex Works API. Ritorna dict compatibile con cascade o None."""
    from pyalex import Works
    filters = {}
    if year:
        filters["publication_year"] = year
    results = Works().search(title).filter(**filters).select([
        "id", "title", "authorships", "publication_year", "doi",
        "topics", "primary_location", "cited_by_count",
        "abstract_inverted_index", "referenced_works"
    ]).get()

    if not results:
        return None
    # Title match (case-insensitive) o primo risultato
    best = next((r for r in results if r["title"].lower() == title.lower()), results[0])

    abstract = best.get("abstract")  # pyalex ricostruisce automaticamente!
    authors = [a["author"]["display_name"] for a in best.get("authorships", [])]
    venue = (best.get("primary_location", {}) or {}).get("source", {})
    venue_name = venue.get("display_name", "") if venue else ""
    topics = [{"name": t["display_name"], "score": t["score"],
               "field": t.get("subfield", {}).get("field", {}).get("display_name", ""),
               "domain": t.get("domain", {}).get("display_name", "")}
              for t in best.get("topics", [])[:5] if t.get("score", 0) > 0.3]
    institutions = list({inst["display_name"]
                        for a in best.get("authorships", [])
                        for inst in a.get("institutions", []) if inst.get("display_name")})

    return {
        "title": best["title"],
        "abstract": abstract,
        "authors_resolved": authors,
        "year": best.get("publication_year"),
        "doi": (best.get("doi") or "").replace("https://doi.org/", ""),
        "venue": venue_name,
        "citation_count": best.get("cited_by_count"),
        "openalex_id": best.get("id"),
        "topics": topics,
        "institutions": institutions,
        "referenced_works": best.get("referenced_works", []),
        "source": "openalex",
    }
```

### Cascade update (`resolve_citation()`, riga ~389)
Inserire tra Semantic Scholar e CrossRef:
```python
# 2.5 OpenAlex
time.sleep(API_DELAY)
oa_data = resolve_via_openalex(ref["title"], ref.get("year"))
if oa_data and oa_data.get("abstract"):
    resolved.update({k: v for k, v in oa_data.items() if v})
    return resolved
```

### Wiki content update (`generate_wiki_content()`)
- Aggiungere riga "Topics" nella tabella se `paper.get("topics")`
- Aggiungere riga "OpenAlex" con link se `paper.get("openalex_id")`

### API key
- Env var: `OPENALEX_API_KEY`
- Wrapper `/data/massimiliano/shell-scripts/bin/paper-archive`: aggiungere `export OPENALEX_API_KEY="..."`
- Graceful degradation: se vuoto, skip OpenAlex (log warning)

### Verifica
```bash
paper-archive --dry-run --single "Portfolio Selection"
paper-archive --single "Portfolio Selection"  # test reale su 1 paper
```

**Effort**: 2-3 ore | **Dipendenze**: nessuna

---

## Step 2 — Enrichment (flag --enrich)

**Obiettivo**: Per ogni Paper esistente in AGE, query OpenAlex e creare nodi Topic, Institution + relazioni.

**File da modificare**: `/data/massimiliano/kindle/paper_archive.py`

### Nuovi nodi AGE

| Label | Properties | Stima |
|-------|-----------|-------|
| `Topic` | `openalex_id, name, field, subfield, domain_name, level` | ~150-300 |
| `Institution` | `openalex_id, name, country_code, type` | ~100-250 |

### Nuove relazioni AGE

| Tipo | Pattern | Stima |
|------|---------|-------|
| `TAGGED_WITH` | `(Paper)-[:TAGGED_WITH {score}]->(Topic)` | ~300-600 |
| `AFFILIATED_WITH` | `(Author)-[:AFFILIATED_WITH]->(Institution)` | ~150-400 |
| `CITES` | `(Paper)-[:CITES]->(Paper)` | ~30-100 (solo inter-library) |

### Implementazione (~120 righe)
- Nuovo flag argparse `--enrich` (mutually exclusive con `--scan`)
- `enrich_papers()`: query AGE per tutti i Paper → per ciascuno `resolve_via_openalex()` → collect topics, institutions, referenced_works
- `generate_enrichment_node_statements()`: MERGE Topic e Institution
- `generate_enrichment_relationship_statements()`: MERGE TAGGED_WITH, AFFILIATED_WITH, CITES
- Esecuzione via `execute_age()` esistente (two-phase: nodi → relazioni)
- SET `p.openalex_id` su Paper esistenti per lookup futuri

### Topic hierarchy
Proprietà flat sul nodo Topic (non gerarchia separata). Ragione: 105 paper, la gerarchia FORD è fissa e queryabile come proprietà.

### CITES logic
`referenced_works` da OpenAlex → match per DOI o openalex_id con Paper già nel graph → solo edge interni.

### Verifica
```bash
paper-archive --enrich --dry-run                          # mostra piano
paper-archive --enrich --single "Portfolio Selection"      # test su 1
paper-archive --enrich                                     # tutti i 105
```

**Effort**: 4-5 ore | **Dipendenze**: Step 1

---

## Step 3 — Bulk Download

**Obiettivo**: Download massivo di metadati per paper ad alte citazioni nei domini core.

### Approccio: due opzioni (da validare all'inizio dello step)

**Opzione A — `pyalex` cursor pagination** (approach sicuro, nessuna dipendenza extra):
```python
from pyalex import Works
import pyalex
pyalex.config.api_key = os.environ["OPENALEX_API_KEY"]

# Cursor pagination: scarica tutti i risultati filtrati
for page in Works().filter(cited_by_count={">500"}, topics={"domain": {"id": "3"}}).paginate(per_page=200):
    for work in page:
        save_json(work, output_dir)
```
`pyalex` (già installato per Step 1) supporta cursor pagination nativa. Rate limit: ~100K req/day free tier, con 200 risultati/pagina → 50K paper in 250 richieste.

**Opzione B — `openalex-official` CLI** (da verificare):
```bash
pip install --user openalex-official
openalex download --filter "cited_by_count:>500,..." --output /mnt/hdd/openalex/
```
⚠️ Non verificato: SearXNG era down, non confermata l'esistenza di questo pacchetto. Verificare `pip install --user openalex-official` prima di procedere. Se non esiste, usare Opzione A.

**Opzione C — S3 snapshot JSONL.gz + DuckDB** (piano originale, massimo volume):
Per >100K paper conviene il dump completo S3 (~350-500GB). Conversione JSONL→Parquet con DuckDB. Solo se servono volumi > ciò che l'API free tier consente.

### File da creare
- `/data/massimiliano/kindle/openalex_download.py` — download filtrato (pyalex o CLI)
- `/data/massimiliano/shell-scripts/bin/openalex-download` — wrapper con scaglioni predefiniti
- `/data/massimiliano/kindle/openalex_index.py` — indicizza i JSON scaricati in SQLite locale per query rapide

### Scaglioni e spazio disco

| Scaglione | Soglia | Paper | JSON size | Richieste API |
|-----------|--------|-------|-----------|---------------|
| S1 | > 500 cit | ~10K | ~2-5 GB | ~50 |
| S2 | > 200 cit | ~40K | ~10-20 GB | ~200 |
| S3 | > 100 cit | ~100K | ~25-50 GB | ~500 |

4TB HDD: ampiamente sufficiente per tutti gli scaglioni.

### Domini OpenAlex (Topics taxonomy)

| Dominio | Domain ID |
|---------|-----------|
| Computer Science | 3 |
| Economics | 2 |
| Mathematics | 1 |
| Physics | 4 |
| Philosophy | 5 |
| Political Science | (da identificare) |

### Verifica
```bash
# Test minimo: 10 paper CS con >1000 citazioni
python3 openalex_download.py --filter "cited_by_count:>1000" --domain 3 --limit 10 --output /tmp/test-oa
ls /tmp/test-oa/*.json | wc -l  # dovrebbe essere 10
```

**Effort**: 4-5 ore (script) + ore/giorni (download) | **Dipendenze**: HDD montato, API key, pyalex

---

## Step 4 — Embedding a Scala

**Obiettivo**: Embeddare 10K-100K paper da bulk download in pgvector.

**Nessuna migrazione dimensionale**: restare su mxbai-embed-large (1024 dim).

### File da creare
- `/data/massimiliano/kindle/openalex_embed.py` — pipeline embedding batch
- `/data/massimiliano/shell-scripts/bin/openalex-embed` — wrapper

### Scaglioni (rivisti per 1024 dim)

| Scaglione | Paper | Tempo CPU (mxbai) | RAM pgvector |
|-----------|-------|-------------------|-------------|
| S1 (~10K) | ~10K | ~3-4 ore | ~80 MB |
| S2 (~40K) | ~40K | ~12-16 ore | ~320 MB |
| S3 (~100K) | ~100K | ~30-40 ore | ~800 MB |

Tutti gli scaglioni stanno comodamente nei 16 GB RAM.

### Pipeline per paper
1. Leggi JSON da directory bulk download
2. Genera mini-doc (pattern da `generate_mini_doc()` esistente, riga 716 di paper_archive.py)
3. `get_embedding()` via Ollama (riuso funzione esistente)
4. `upsert_embedding()` con `metadata.source = "openalex_embed"` (riuso funzione esistente)
5. Checkpoint ogni N paper (file di stato per resume)

### Modalità "pausa servizi" (solo per S3)
```bash
openalex-embed --tier 3 --pause-services  # stop container non essenziali, libera ~4-5 GB RAM
```

### Pipeline separata (non integrata in ChunkingService.java)
Ragioni: sorgente dati diversa (JSON files, non .md), pattern identico a paper_archive.py (Python + raw SQL), metadata format specifico (`source=openalex_embed`). La ricerca semantica funziona trasparentemente (stesso modello, stessa tabella, stesso spazio vettoriale).

### Upgrade modello (futuro, opzionale)
Se si volesse passare a `snowflake-arctic-embed-l-v2.0` (1024 dim, qualità superiore):
- Cambiare `EMBED_MODEL` in paper_archive.py + `MCP_VECTOR_OLLAMA_MODEL` in docker-compose
- `embeddings_reindex(all)` + ri-eseguire openalex_embed.py
- Nessuna migrazione schema (stessa dimensionalità)

### Verifica
```bash
openalex-embed --tier 1 --batch-size 10 --dry-run
openalex-embed --tier 1 --batch-size 10  # primi 10 paper
embeddings_stats()                        # verifica conteggio
embeddings_search_docs("attention mechanism in transformers")  # test ricerca
```

**Effort**: 5-6 ore (codice) + 1-7 giorni (esecuzione S1-S3) | **Dipendenze**: Step 3

---

## Step 5 — MCP Tools

**Obiettivo**: Due tool MCP per query OpenAlex interattive da Claude Code.

**File da creare**: `/data/massimiliano/Vari/mcp/src/main/java/com/example/mcp/tools/OpenAlexTools.java`

### Tool 1: `openalex_search(query, filters, maxResults)`
- Pattern: `@ReactiveTool` + WebClient (come `WebSearchTools.java` e `Context7Tools.java`)
- URL: `https://api.openalex.org/works?search={query}&filter={filters}&per_page={max}&api_key={key}&select=...`
- Formattazione: riusa `ApiExtractors.extractOpenAlex()` (già esistente, riga 176)
- API key: `@Value("${openalex.api-key:}")`

### Tool 2: `openalex_neighborhood(paperId, direction, maxResults)`
- `cites`: `GET /works?filter=cites:{paperId}`
- `cited_by`: `GET /works?filter=cited_by:{paperId}`
- `both`: entrambe le query

### Configurazione
- `OPENALEX_API_KEY` in `/data/massimiliano/Vari/mcp/docker-compose.yml` environment
- Auto-discovery via `@ReactiveTool` (pattern `mcp-redis-tools`)

### Verifica
```bash
sol deploy mcp
# Da Claude Code:
openalex_search("attention mechanism", "publication_year:>2020,cited_by_count:>100", 5)
openalex_neighborhood("W2741809807", "both", 5)
```

**Effort**: 3-4 ore | **Dipendenze**: nessuna (parallelo a tutto)

---

## Ordine di implementazione

```
Step 1 (API cascade)  ──┐
                        ├──> Step 2 (enrichment) ──> Step 4 (embed at scale)
Step 5 (MCP tools)   ──┘                              ↑
                                                       │
Step 3 (bulk download) ───────────────────────────────┘
```

**Sequenza raccomandata**: 1 → 5 → 2 → 3 → 4
- Step 1 e 5 piccoli e immediatamente utili
- Step 3 download corre unattended overnight
- Step 4 corre unattended per giorni

## File critici (esistenti, da riusare)

| File | Funzioni da riusare |
|------|-------------------|
| `kindle/paper_archive.py` | `api_request()`, `esc()`, `sql_esc()`, `execute_age()`, `get_embedding()`, `upsert_embedding()`, `generate_mini_doc()` |
| `Vari/mcp/.../ApiExtractors.java` | `extractOpenAlex()`, `reconstructAbstract()`, `extractOpenAlexSearchResults()` |
| `Vari/mcp/.../WebSearchTools.java` | Pattern `@ReactiveTool` + WebClient |
| `shell-scripts/bin/paper-archive` | Wrapper da aggiornare con `OPENALEX_API_KEY` |

## Verifica end-to-end

Dopo ogni step, eseguire nell'ordine:
1. **Step 1**: `paper-archive --dry-run --single "Portfolio Selection"` → verifica che OpenAlex sia nella cascade. Poi senza `--dry-run` per test reale.
2. **Step 5**: `sol deploy mcp` → `openalex_search("attention mechanism", "publication_year:>2020", 5)` da Claude Code
3. **Step 2**: `paper-archive --enrich --dry-run` → conta nodi/relazioni pianificati. Poi `--enrich --single "Portfolio Selection"`. Poi `graph_stats(backend="age")` per verificare Topic/Institution.
4. **Step 3**: `ls /mnt/hdd/openalex/cs-500/*.json | wc -l` → contare file scaricati
5. **Step 4**: `openalex-embed --tier 1 --batch-size 10` → `embeddings_stats()` → `embeddings_search_docs("attention transformer neural network")`

## Pre-requisiti

1. [ ] Registrare API key su openalex.org con `carloaugiass+openalex@gmail.com`
2. [ ] Montare HDD 4TB su `/mnt/hdd/` (Step 3-4)
3. [ ] `pip install --user pyalex` (Step 1)
4. [ ] Verificare esistenza `openalex-official` su PyPI (Step 3, opzionale)
