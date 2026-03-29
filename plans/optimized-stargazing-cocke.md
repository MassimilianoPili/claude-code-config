# Piano: Knowledge Graph Razionalista (LessWrong + OPML → AGE/PostgreSQL)

## Contesto

Costruire un knowledge graph isolato che connetta concetti razionalisti (da LessWrong), autori/blog (da OPML Feedly), e fonti accademiche. Scopo: esplorazione, ricerca su topic (decision theory, AI alignment, epistemologia), knowledge base strutturata.

**Scelta: Apache AGE** su PostgreSQL (database `embeddings`, dove AGE è già installato) con grafo dedicato `rationalist_graph`. Zero RAM extra, isolamento per nome grafo, portabilità a Neo4j garantita (Cypher identico). La Knowledge Graph UI sarà adattata per supportare anche AGE.

### Separazione dai sistemi esistenti

- **Agent-Framework** usa AGE nel database `agentframework` (grafi `knowledge_graph`, `code_graph`) — database **diverso**, zero conflitto
- **Neo4j** resta disponibile per il Kindle import e futuri usi — non viene toccato
- Il nuovo `rationalist_graph` vive nel database `embeddings` dove AGE è già abilitato

## Schema del grafo `rationalist_graph`

### Nodi

| Label | Proprietà | Note |
|-------|-----------|------|
| `Concept` | `name`, `category`, `description`, `url` | Tag/topic LessWrong + concetti trasversali |
| `Author` | `name`, `url`, `bio` | Autori blog, ricercatori, pensatori |
| `Source` | `name`, `url`, `type`, `tier`, `feed_url`, `opml_category` | Blog/feed dall'OPML |
| `Sequence` | `title`, `url`, `description`, `post_count` | Sequenze LessWrong |
| `Book` | `title`, `author_name`, `year` | Libri citati/raccomandati |

### Relazioni

| Relazione | Da → A | Proprietà | Note |
|-----------|--------|-----------|------|
| `WRITES_FOR` | Author → Source | | Autore pubblica su un blog |
| `COVERS` | Source → Concept | `depth` | Il blog tratta questo topic |
| `RELATED_TO` | Concept → Concept | `strength`, `rel_type` | prerequisite, contrast, extension, application |
| `PART_OF` | Concept → Concept | | Sotto-concetto (tassonomia LessWrong) |
| `AUTHORED` | Author → Sequence | | Autore della sequenza |
| `DISCUSSES` | Sequence → Concept | | Sequenza tratta un concetto |
| `WROTE` | Author → Book | | Autore di un libro |

### Categorie Concept

`ai_alignment`, `rationality`, `world_modeling`, `decision_theory`, `epistemology`, `practical`, `world_optimization`, `economics`, `science`, `philosophy`

### Tier Source

`tier_1` (rigore accademico), `tier_2` (alta qualità), `tier_3` (opinione/cultura), `journal` (peer-reviewed)

## Implementazione — 4 Fasi

### Fase 1: Script di import (Python)

**File**: `/data/massimiliano/kindle/import_rationalist.py`

1. Crea il grafo `rationalist_graph` in AGE (se non esiste)
2. Definisce tassonomia LessWrong come dizionario Python (~50-70 concetti chiave, ~10 categorie)
3. Parsa il file OPML dell'utente (XML) per estrarre ~40 feed con tier e category
4. Mappa ~25 autori → fonti → concetti (mapping manuale curato)
5. Include ~10 sequenze principali (Rationality A-Z, Codex, CDT=EDT, etc.)
6. Genera Cypher puro in file intermedio `.cypher` (portabile a Neo4j)
7. Esegue contro AGE via `psql` con wrapper SQL

**Pattern di esecuzione AGE**:
```python
def execute_cypher(cursor, graph, cypher):
    cursor.execute(f"""
        SELECT * FROM cypher('{graph}', $$
            {cypher}
        $$) AS (result agtype)
    """)
```

**Dati hardcoded** (non serve API LessWrong): la tassonomia è stabile, l'OPML è one-shot, il mapping autore→concetto richiede giudizio umano.

**Deduplicazione**: MERGE su proprietà chiave (name per Concept/Author, url per Source/Sequence). AGE non ha constraint UNIQUE nativi → check applicativo pre-MERGE con MATCH + conteggio.

### Fase 2: Adattamento Knowledge Graph UI per AGE

**File da modificare**:

| File | Modifica |
|------|----------|
| `knowledge-graph/graph.go` | Aggiungere funzioni query AGE via `database/sql` + driver `pgx`. Supporto duale: Neo4j (Bolt) per grafi Kindle, AGE (SQL) per grafo razionalista. Query parameter `?backend=age&graph=rationalist_graph` |
| `knowledge-graph/main.go` | Nuove route: `GET /api/age/graph`, `GET /api/age/sources`, `GET /api/age/concepts`, `GET /api/age/search` |
| `knowledge-graph/static/index.html` | Selettore backend (Neo4j / AGE) nel pannello laterale. Colori per nuovi tipi nodo: Source = verde, Sequence = viola |
| `knowledge-graph/go.mod` | Aggiungere dipendenza `github.com/jackc/pgx/v5` (driver PostgreSQL) |
| `knowledge-graph/docker-compose.yml` | Env var per connessione PostgreSQL (`AGE_DSN`) |

**Architettura endpoint**:
- `/api/graph` — rimane Neo4j (compatibilità Kindle)
- `/api/age/graph?graph=rationalist_graph` — nuovo, query AGE
- `/api/age/search?q=decision+theory` — full-text search via `tsvector` su proprietà nodi
- `/api/age/sources` — lista fonti con count concetti
- `/api/age/concepts` — lista concetti con count relazioni

### Fase 3: Full-text search (PostgreSQL tsvector)

**Opzionale ma utile**: creare una tabella ausiliaria PostgreSQL che indicizza le proprietà dei nodi AGE per full-text search:

```sql
CREATE TABLE rationalist_search (
    node_id agtype,
    label text,
    name text,
    description text,
    search_vector tsvector GENERATED ALWAYS AS (
        to_tsvector('english', coalesce(name,'') || ' ' || coalesce(description,''))
    ) STORED
);
CREATE INDEX idx_rationalist_search ON rationalist_search USING GIN (search_vector);
```

Popolata dallo script di import. Query: `SELECT * FROM rationalist_search WHERE search_vector @@ to_tsquery('decision & theory')`.

### Fase 4: Arricchimento (futuro, non in questo piano)

- RSS scraper periodico: aggiunge nodi `Post` con link a Source e Concept
- Concept extraction via Claude Haiku sui post
- Embedding in pgvector per ricerca semantica cross-graph (JOIN relazionale + vettoriale + grafo)
- Graph algorithms (PageRank, centrality) via NetworkX o SQL ricorsivo

## File coinvolti

| File | Azione | Note |
|------|--------|------|
| `/data/massimiliano/kindle/import_rationalist.py` | **Nuovo** | Script import principale (~350 righe) |
| `/data/massimiliano/knowledge-graph/graph.go` | **Modifica** | +funzioni AGE, endpoint `/api/age/*` |
| `/data/massimiliano/knowledge-graph/age.go` | **Nuovo** | Modulo query AGE separato (~200 righe) |
| `/data/massimiliano/knowledge-graph/main.go` | **Modifica** | Route per endpoint AGE, config PostgreSQL |
| `/data/massimiliano/knowledge-graph/static/index.html` | **Modifica** | Selettore backend, colori nuovi nodi |
| `/data/massimiliano/knowledge-graph/go.mod` | **Modifica** | +dipendenza pgx/v5 |
| `/data/massimiliano/knowledge-graph/docker-compose.yml` | **Modifica** | +env AGE_DSN |

## Portabilità a Neo4j

Lo script genera Cypher puro come file intermedio (`rationalist_graph.cypher`). Per migrare a Neo4j:
1. Creare container Neo4j dedicato
2. Eseguire `cypher-shell -f rationalist_graph.cypher`
3. Aggiornare UI per puntare al nuovo Neo4j

Zero riscrittura delle query — solo cambio del target di esecuzione.

## Verifica

1. **Grafo AGE**: `docker exec postgres psql -U embeddings -d embeddings -c "SELECT * FROM ag_catalog.ag_graph;"`
2. **Import**: `python3 /data/massimiliano/kindle/import_rationalist.py` — output stats
3. **Query test**:
   ```sql
   SELECT * FROM cypher('rationalist_graph', $$
       MATCH (a:Author)-[:WRITES_FOR]->(s:Source)-[:COVERS]->(c:Concept)
       RETURN a.name, s.name, c.name LIMIT 20
   $$) AS (author agtype, source agtype, concept agtype);
   ```
4. **Full-text**: `SELECT * FROM rationalist_search WHERE search_vector @@ to_tsquery('bayesian & reasoning')`
5. **UI**: `https://notes.massimilianopili.com` → selettore AGE → verificare grafo visualizzato
6. **Rebuild**: `cd /data/massimiliano/knowledge-graph && docker compose up -d --build`
