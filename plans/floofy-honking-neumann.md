# Piano: OpenAlex Bulk Download + Embedding + Enrichment locale

## Context

Rendere operativa la ricerca accademica locale: scaricare paper da OpenAlex, embeddarli in pgvector,
e arricchire il knowledge graph AGE con Topic/Institution/CITES — tutto da dati locali.

Il modello embedding è già stato aggiornato a `qwen3-embedding:8b` (4096 dim) nel docker-compose MCP.
La GPU gaia è operativa con socat proxy trasparente.

**Ordine scelto**: Step 3 (download) → Step 2 (enrichment da locale) → Step 4 (embedding).
Questo evita chiamate API ridondanti — i JSON scaricati contengono tutto per enrichment + embedding.

## Stato completamento

- [x] **0b**: `get_embedding()` aggiornato con `dimensions` + `EMBED_MODEL=qwen3-embedding:8b`
- [x] **Step 3**: `openalex_download.py` + wrapper `openalex-download` — testato, funzionante
  - Soglie riviste: S1=5000 (~10K paper), S2=1000, S3=500
  - Abstract ricostruiti da `abstract_inverted_index`
  - Dry-run confermato: CS ~3.9K, Economics ~2.6K, Math ~2K, Physics ~1.7K (S1 totale ~10K)
- [ ] **0a**: formattare sdc ext4, montare `/mnt/hdd` (richiede sudo)
- [ ] **Step 2**: enrichment AGE da JSON locali
- [ ] **Step 4**: embedding at scale con `openalex_embed.py`

---

## Prerequisiti

### 0a. Formattare sdc come ext4 e montare
```bash
# RICHIEDE SUDO — comandi esatti da eseguire:
sudo parted /dev/sdc mklabel gpt
sudo parted /dev/sdc mkpart primary ext4 0% 100%
sudo mkfs.ext4 -L openalex /dev/sdc1
sudo mkdir -p /mnt/hdd
sudo mount /dev/sdc1 /mnt/hdd
sudo chown massimiliano:massimiliano /mnt/hdd
# Persistenza in fstab:
echo 'LABEL=openalex /mnt/hdd ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
```

### 0b. Aggiornare get_embedding() per supportare dimensions
**File**: `/data/massimiliano/kindle/paper_archive.py`
**Riga ~895**: aggiungere parametro `dimensions` alla chiamata Ollama API.
**Riga ~39**: cambiare `EMBED_MODEL = "qwen3-embedding:8b"` (era `mxbai-embed-large`).

```python
# Riga ~38-39
EMBED_MODEL = os.environ.get("EMBED_MODEL", "qwen3-embedding:8b")
EMBED_DIMENSIONS = int(os.environ.get("EMBED_DIMENSIONS", "4096"))

# In get_embedding(), aggiungere dimensions al payload:
payload = {"model": EMBED_MODEL, "input": text}
if EMBED_DIMENSIONS:
    payload["dimensions"] = EMBED_DIMENSIONS
```

---

## Step 3 — Bulk Download via pyalex

### File da creare
- `/data/massimiliano/kindle/openalex_download.py` (~200 righe)
- `/data/massimiliano/shell-scripts/bin/openalex-download` (wrapper bash)

### Design

```python
# openalex_download.py
import pyalex, json, os, time, sys
from pathlib import Path

pyalex.config.api_key = os.environ.get("OPENALEX_API_KEY", "")

DOMAINS = {
    "cs": 3, "economics": 2, "math": 1, "physics": 4
}

TIERS = {
    "s1": 500,   # >500 cit, ~10K paper
    "s2": 200,   # >200 cit, ~40K paper
    "s3": 100,   # >100 cit, ~100K paper
}

SELECT_FIELDS = [
    "id", "title", "authorships", "publication_year", "doi",
    "topics", "primary_location", "cited_by_count",
    "abstract_inverted_index", "referenced_works",
    "type", "open_access", "language"
]
```

### Strategia download (dalla ricerca community)
- **pyalex cursor pagination** — usa `.paginate(per_page=200)` per iterare tutti i risultati
- **Rate limit**: 100K req/giorno (free tier con API key), 200/pagina = 20M works teorici/giorno
- **Formato output**: un file JSON per paper, organizzato `{output_dir}/{domain}/{openalex_id}.json`
- **Checkpoint**: file `{output_dir}/.checkpoint.json` con `{domain: last_cursor}` per resume
- **Abstract**: pyalex ricostruisce automaticamente da `abstract_inverted_index` (campo `.abstract`)
- **Filtri**: `cited_by_count > {threshold}`, `topics.domain.id:{domain_id}`, `language:en` (opzionale)
- **Deduplicazione**: skip se file JSON esiste già (idempotente)
- **Progress**: stampa ogni 1000 paper + stima tempo rimanente

### Wrapper bash
```bash
#!/bin/bash
# /data/massimiliano/shell-scripts/bin/openalex-download
export OPENALEX_API_KEY="..."
python3 /data/massimiliano/kindle/openalex_download.py "$@"
```

### Flag argparse
- `--tier {s1,s2,s3}` — soglia citazioni (default: s1)
- `--domains {cs,economics,math,physics,all}` — domini (default: all = cs,economics,math,physics)
- `--output /mnt/hdd/openalex` — directory output
- `--limit N` — max paper (per test)
- `--dry-run` — mostra conteggio senza scaricare
- `--resume` — riprendi da checkpoint
- `--language` — filtra per lingua (non usato — tutte le lingue per scelta)
- `--stats` — mostra statistiche directory esistente

### Spazio disco stimato (soglie riviste)
| Tier | Paper (4 domini) | JSON size | Tempo download |
|------|-------------------|-----------|----------------|
| S1 (>5000 cit) | ~10K | ~1-3 GB | ~5 min |
| S2 (>1000 cit) | ~50-80K | ~10-25 GB | ~30 min |
| S3 (>500 cit) | ~568K | ~50-150 GB | ~3-4h |

### Verifica
```bash
openalex-download --tier s1 --domains cs --limit 10 --dry-run
openalex-download --tier s1 --domains cs --limit 10 --output /mnt/hdd/openalex
ls /mnt/hdd/openalex/cs/ | wc -l  # → 10
```

---

## Step 2 — Import OpenAlex JSON → AGE knowledge graph

### File da creare
- `/data/massimiliano/kindle/openalex_import.py` (~250 righe)
- `/data/massimiliano/shell-scripts/bin/openalex-import` (wrapper bash)

### Perché file separato (non estensione di paper_archive.py)
`paper_archive.py` è orientato a single-paper pipeline (parse → API → WikiJS → AGE → embed).
L'import bulk ha un flusso diverso: legge JSON locali, crea nodi in batch, niente WikiJS.
Riusa le funzioni core via import: `from paper_archive import esc, execute_age, GRAPH_NAME, BATCH_SIZE, TIMESTAMP`.

### Trasformazione OpenAlex JSON → Cypher nodes

**Fase 1 — Collect nodi unici (in-memory scan)**
```python
def collect_entities(json_dir):
    """Scan tutti i JSON, raccoglie paper + entità uniche."""
    papers = []
    topics = {}       # openalex_id → {name, field, subfield, domain_name}
    institutions = {} # openalex_id → {name, country_code, type}
    authors = set()   # nome normalizzato

    for json_path in Path(json_dir).rglob("*.json"):
        with open(json_path) as f:
            w = json.load(f)

        # Paper
        oa_id = w["id"].rsplit("/", 1)[-1]  # W12345
        slug = f"openalex-{oa_id}"           # archival_id per AGE
        papers.append({
            "slug": slug, "openalex_id": oa_id,
            "title": w.get("title", ""),
            "year": w.get("publication_year"),
            "doi": w.get("doi", ""),
            "abstract": (w.get("abstract") or "")[:500],
            "cited_by_count": w.get("cited_by_count", 0),
            "language": w.get("language", ""),
            "topics": w.get("topics", []),
            "authorships": w.get("authorships", []),
            "venue": extract_venue(w),
            "referenced_works": w.get("referenced_works", []),
        })

        # Topics
        for t in w.get("topics", []):
            tid = t.get("id", "")
            if tid and tid not in topics:
                topics[tid] = {
                    "name": t.get("display_name", ""),
                    "field": t.get("field", {}).get("display_name", ""),
                    "subfield": t.get("subfield", {}).get("display_name", ""),
                    "domain_name": t.get("domain", {}).get("display_name", ""),
                }

        # Institutions
        for a in w.get("authorships", []):
            for inst in a.get("institutions", []):
                iid = inst.get("id", "")
                if iid and iid not in institutions:
                    institutions[iid] = {
                        "name": inst.get("display_name", ""),
                        "country_code": inst.get("country_code", ""),
                        "type": inst.get("type", ""),
                    }

            # Authors
            aname = a.get("author", {}).get("display_name", "")
            if aname:
                authors.add(aname)

    return papers, topics, institutions, authors
```

**Fase 2 — Generate Cypher (3 passate: nodi → relazioni → CITES)**

Pass 1 — Nodi (MERGE idempotenti):
```cypher
-- Paper (archival_id = "openalex-W12345")
MERGE (p:Paper {archival_id: 'openalex-W12345'})
SET p.title = '...', p.year = 2020, p.doi = '...', p.abstract = '...',
    p.citation_count = 5000, p.source = 'openalex', p.openalex_id = 'W12345',
    p.language = 'en', p.domain = 'personal', p.last_modified = '{TIMESTAMP}'

-- Topic (nuovo label)
MERGE (t:Topic {openalex_id: 'https://openalex.org/T12345'})
SET t.name = 'Machine Learning', t.field = 'Computer Science',
    t.subfield = 'Artificial Intelligence',
    t.domain_name = 'Physical Sciences', t.domain = 'personal',
    t.last_modified = '{TIMESTAMP}'

-- Institution (nuovo label)
MERGE (i:Institution {openalex_id: 'https://openalex.org/I12345'})
SET i.name = 'MIT', i.country_code = 'US', i.type = 'education',
    i.domain = 'personal', i.last_modified = '{TIMESTAMP}'

-- Author (riusa label esistente, MERGE su nome)
MERGE (a:Author {name: 'John Smith'})
SET a.domain = 'personal', a.last_modified = '{TIMESTAMP}'
```

Pass 2 — Relazioni:
```cypher
MATCH (p:Paper {archival_id: 'openalex-W12345'}), (a:Author {name: 'John Smith'})
MERGE (p)-[:WRITTEN_BY]->(a)

MATCH (p:Paper {archival_id: 'openalex-W12345'}), (v:Venue {name: 'Nature'})
MERGE (p)-[:PUBLISHED_IN]->(v)

MATCH (p:Paper {archival_id: 'openalex-W12345'}), (t:Topic {openalex_id: 'https://openalex.org/T12345'})
MERGE (p)-[:TAGGED_WITH {score: 0.95}]->(t)

MATCH (a:Author {name: 'John Smith'}), (i:Institution {openalex_id: 'https://openalex.org/I12345'})
MERGE (a)-[:AFFILIATED_WITH]->(i)
```

Pass 3 — CITES (solo inter-library, tra paper entrambi nel graph):
```cypher
MATCH (p1:Paper {archival_id: 'openalex-W12345'}), (p2:Paper {archival_id: 'openalex-W67890'})
MERGE (p1)-[:CITES]->(p2)
```

**Fase 3 — Execute via `execute_age()` (batch 20, two-phase)**

### Stima nodi/relazioni (S1, ~10K paper)
| Tipo | Stima | Note |
|------|-------|------|
| Paper | ~10K | Nuovi nodi con `source='openalex'` |
| Author | ~20-30K | MERGE su nome, molti già esistenti |
| Venue | ~2-5K | Estratti da `primary_location.source` |
| Topic | ~500-1K | OpenAlex ha ~4K topic totali, S1 ne copre ~500-1K |
| Institution | ~3-5K | Affiliazioni autori |
| WRITTEN_BY | ~30-50K | ~3 autori/paper media |
| PUBLISHED_IN | ~10K | 1:1 con paper |
| TAGGED_WITH | ~30-50K | ~3-5 topic/paper |
| AFFILIATED_WITH | ~10-20K | |
| CITES | ~50-200K | `referenced_works` filtrate per paper in-graph |

### Flag argparse
- `--input /mnt/hdd/openalex/cs` — directory JSON (o più dir)
- `--dry-run` — mostra conteggio nodi/relazioni senza eseguire
- `--limit N` — max paper da importare
- `--skip-cites` — salta CITES (più lento, può essere fatto in pass separata)
- `--stats` — mostra statistiche import precedente

### Verifica
```bash
openalex-import --input /mnt/hdd/openalex/cs --limit 10 --dry-run
openalex-import --input /mnt/hdd/openalex/cs --limit 10
graph_stats(backend="age")  # Topic, Institution presenti
graph_query("MATCH (t:Topic) RETURN count(t)", "age")
graph_query("MATCH (i:Institution) RETURN count(i)", "age")
```

---

## Step 4 — Embedding at scale

### File da creare
- `/data/massimiliano/kindle/openalex_embed.py` (~150 righe)
- `/data/massimiliano/shell-scripts/bin/openalex-embed` (wrapper bash)

### Design
Riusa `get_embedding()` e `upsert_embedding()` da `paper_archive.py` via import.
Trasforma OpenAlex JSON → mini_doc con pattern simile a `generate_mini_doc()`.

```python
from paper_archive import get_embedding, upsert_embedding, esc, EMBED_MODEL

def openalex_to_mini_doc(w):
    """Trasforma OpenAlex JSON nel formato mini_doc per embedding."""
    title = w.get("title", "Untitled")
    year = w.get("publication_year", "")
    abstract = (w.get("abstract") or "")[:300]
    authors = [a.get("author", {}).get("display_name", "")
               for a in w.get("authorships", [])[:5]]
    venue = ""
    loc = w.get("primary_location", {})
    if loc and loc.get("source"):
        venue = loc["source"].get("display_name", "")
    topics = [t.get("display_name", "") for t in w.get("topics", [])[:3]]

    lines = [f"Paper: {title}"]
    if authors:
        lines.append(f"Authors: {', '.join(a for a in authors if a)}. Year: {year}.")
    if abstract:
        lines.append(abstract)
    if venue:
        lines.append(f"Published in: {venue}")
    if topics:
        lines.append(f"Topics: {', '.join(t for t in topics if t)}")
    # Relazioni strutturate (aiutano la semantic search)
    lines.append("Relationships:")
    for a in authors:
        if a:
            lines.append(f"- WRITTEN_BY -> {a} (Author)")
    if venue:
        lines.append(f"- PUBLISHED_IN -> {venue} (Venue)")
    return "\n".join(lines)

def embed_openalex_dir(json_dir, dry_run=False, limit=None):
    """Embed tutti i JSON OpenAlex nella directory."""
    checkpoint_file = json_dir / ".embed_checkpoint.json"
    done = set()
    if checkpoint_file.exists():
        done = set(json.loads(checkpoint_file.read_text()))

    files = sorted(f for f in json_dir.rglob("*.json")
                   if f.name != ".checkpoint.json" and f.stem not in done)

    embedded, errors = 0, []
    for i, json_path in enumerate(files):
        if limit and embedded >= limit:
            break
        w = json.loads(json_path.read_text())
        oa_id = json_path.stem  # W12345
        slug = f"openalex-{oa_id}"

        doc = openalex_to_mini_doc(w)
        vec = get_embedding(doc)
        if vec is None:
            errors.append(f"{oa_id} — embedding failed")
            continue

        ok, err = upsert_embedding(slug, "Paper", "personal", doc, vec,
                                   source="openalex_bulk")
        if ok:
            embedded += 1
            done.add(oa_id)
        else:
            errors.append(f"{oa_id} — upsert: {err}")

        # Checkpoint ogni 100
        if embedded % 100 == 0 and embedded > 0:
            checkpoint_file.write_text(json.dumps(list(done)))
            pct = (i + 1) / len(files) * 100
            print(f"  {embedded} embedded ({pct:.1f}%) — {len(errors)} errori")

    # Checkpoint finale
    checkpoint_file.write_text(json.dumps(list(done)))
    return embedded, errors
```

### Flag argparse
- `--input /mnt/hdd/openalex/cs` — directory JSON
- `--limit N` — max paper da embeddare
- `--dry-run` — mostra conteggio + sample mini_doc
- `--stats` — mostra quanti già embedded vs totale
- `--reset-checkpoint` — ricomincia da zero

### Tempi GPU (qwen3-embedding:8b Q4_K_M su 3090)
| Tier | Paper | Tempo stimato |
|------|-------|--------------|
| S1 (~10K) | ~10K | ~30 min |
| S2 (~50-80K) | ~50-80K | ~2-4h |
| S3 (~568K) | ~568K | ~24-36h |

### Versioning nei metadata
`upsert_embedding()` accetta `**extra_meta` per campi aggiuntivi nei metadata.
`openalex_embed.py` passa `embed_model`, `embed_dimensions`, `embed_version`:
```python
# In paper_archive.py — upsert_embedding() accetta **extra_meta
def upsert_embedding(name, label, domain, mini_doc, embedding, source="paper_archive", **extra_meta):
    metadata = {"type": "docs", "label": label, "name": name,
                "domain": domain, "embedding_hash": doc_hash, "source": source}
    metadata.update(extra_meta)  # aggiunge embed_model, embed_dimensions, embed_version

# In openalex_embed.py — passa versioning
EMBED_VERSION = 1  # incrementare quando cambia modello/chunking/mini_doc format
upsert_embedding(slug, "Paper", "personal", doc, vec,
                 source="openalex_bulk",
                 embed_model=EMBED_MODEL,
                 embed_dimensions=str(EMBED_DIMENSIONS),
                 embed_version=str(EMBED_VERSION))
```
Questo permette query come:
```sql
SELECT count(*) FROM vector_store
WHERE metadata->>'source' = 'openalex_bulk'
  AND (metadata->>'embed_version')::int < 2;  -- da re-embeddare
```

### Verifica
```bash
openalex-embed --input /mnt/hdd/openalex/cs --limit 10 --dry-run
openalex-embed --input /mnt/hdd/openalex/cs --limit 10
embeddings_stats()
embeddings_search_docs("attention mechanism in transformers")
```

---

## File critici (esistenti, da riusare via import)

| File | Funzioni | Riga |
|------|----------|------|
| `kindle/paper_archive.py` | `esc()`, `sql_esc()` | 65, 72 |
| | `execute_age(statements, label, dry_run)` | 806 |
| | `get_embedding(text)` | 896 |
| | `upsert_embedding(name, label, domain, mini_doc, embedding, source)` | 916 |
| | `generate_mini_doc(paper)` | 862 |
| | `check_ollama_model()` | — |
| | Constants: `GRAPH_NAME`, `BATCH_SIZE`, `TIMESTAMP`, `EMBED_MODEL` | 32-41 |
| `kindle/openalex_download.py` | `openalex_id_short()`, `DOMAINS`, `TIERS` | 43, 22, 29 |
| `shell-scripts/bin/paper-archive` | Wrapper con env vars (pattern da copiare) | — |

**Import pattern**: `sys.path.insert(0, "/data/massimiliano/kindle")` + `from paper_archive import ...`

## Ordine esecuzione

```
Già completati:
  ✓ 0b. get_embedding() + EMBED_MODEL aggiornati
  ✓ 3.  openalex_download.py creato e testato

Da fare (questa sessione):
  1. Creare openalex_import.py + wrapper        (Step 2 — import AGE)
  2. Creare openalex_embed.py + wrapper          (Step 4 — embedding)
  3. Testare entrambi su /tmp/openalex-test/cs/  (15 JSON già scaricati)

Blocco: HDD
  0a. sudo: format sdc, mount /mnt/hdd          (richiede sudo dall'utente)
  3a. openalex-download --tier s1                (~5 min, su /mnt/hdd/openalex)
  2a. openalex-import --input /mnt/hdd/openalex  (~30 min, CPU)
  4a. openalex-embed --input /mnt/hdd/openalex   (~30 min, GPU)

Batch notturno:
  3b. download S2, S3 (unattended)
  2b+4b. import + embed S2, S3
```

## Ottimizzazione: psycopg2 diretto (per S2/S3)

### Motivazione
Il pattern `docker cp + docker exec psql` fa 2 subprocess per batch di 20 statement.
- S1 (217K stmt): ~10.8K docker exec = ~3h
- S3 (12M stmt): ~600K docker exec = impraticabile

### Soluzione: connessione psycopg2 persistente
`paper_archive.py` → nuova funzione `get_pg_connection()` + refactor `execute_age()` e `upsert_embedding()`.

```python
# Connessione lazy singleton
_pg_conn = None

def get_pg_connection():
    global _pg_conn
    if _pg_conn is None or _pg_conn.closed:
        _pg_conn = psycopg2.connect(
            host=os.environ.get("PG_HOST", "172.20.0.9"),
            dbname=PG_DB, user=PG_USER,
            password=os.environ.get("PG_PASSWORD", "")
        )
        _pg_conn.autocommit = True
    return _pg_conn
```

### execute_age() refactored
```python
def execute_age(statements, label="", dry_run=False):
    if dry_run:
        return len(statements), []

    conn = get_pg_connection()
    cur = conn.cursor()
    cur.execute("LOAD 'age'")
    cur.execute('SET search_path = ag_catalog, "$user", public')

    executed, errors = 0, 0
    for i, stmt in enumerate(statements):
        try:
            cypher = stmt.rstrip(";")
            cur.execute(f"SELECT * FROM cypher('{GRAPH_NAME}', $$ {cypher} $$) AS (r agtype)")
            executed += 1
        except Exception as e:
            errors += 1
            conn.rollback()  # reset transaction state

        if (i + 1) % 1000 == 0:
            pct = (i + 1) / len(statements) * 100
            print(f"  {label} {pct:.0f}% ({executed}/{i+1}, {errors} err)", end="\r")

    print()
    return executed, [f"{errors} errori totali"] if errors else []
```

### upsert_embedding() refactored
```python
def upsert_embedding(name, label, domain, mini_doc, embedding, source="paper_archive", **extra_meta):
    conn = get_pg_connection()
    cur = conn.cursor()
    # Parametrizzato — niente SQL injection, niente escape manuale
    cur.execute(
        "SELECT id FROM vector_store WHERE metadata->>'name' = %s AND metadata->>'label' = %s LIMIT 1",
        (name, label)
    )
    row = cur.fetchone()
    meta_dict = {"type": "docs", "label": label, "name": name, "domain": domain,
                 "embedding_hash": doc_hash, "source": source, **extra_meta}
    emb_str = "[" + ",".join(str(x) for x in embedding) + "]"
    if row:
        cur.execute("UPDATE vector_store SET content=%s, metadata=%s, embedding=%s WHERE id=%s",
                    (mini_doc, json.dumps(meta_dict), emb_str, row[0]))
    else:
        cur.execute("INSERT INTO vector_store (content, metadata, embedding) VALUES (%s, %s, %s)",
                    (mini_doc, json.dumps(meta_dict), emb_str))
    return True, None
```

### Vantaggi
- **~100x più veloce**: niente overhead subprocess/docker per ogni operazione
- **Query parametrizzate**: niente escape manuale (`sql_esc`, `replace("'", "''")`), no SQL injection
- **Connessione persistente**: singola connessione TCP, riusata per tutto l'import
- **Backward-compatible**: `PG_HOST` env var, default IP Docker container

### Impatto sui file
- `paper_archive.py`: refactor `execute_age()`, `upsert_embedding()`, add `get_pg_connection()`
- `openalex_import.py`: nessun cambiamento (chiama `execute_age()`)
- `openalex_embed.py`: nessun cambiamento (chiama `upsert_embedding()`)
- `shell-scripts/bin/paper-archive`: aggiungere `PG_PASSWORD` nel wrapper

### Env vars necessarie
```bash
export PG_HOST="172.20.0.9"      # Docker container IP (o hostname se nella rete)
export PG_PASSWORD="..."          # da postgres/.env
```

### Verifica
```bash
# Test connessione
python3 -c "from paper_archive import get_pg_connection; print(get_pg_connection())"
# Test AGE
openalex-import --input /mnt/hdd/openalex/cs --limit 10
# Test embedding
openalex-embed --input /mnt/hdd/openalex/cs --limit 10
```

---

## Step 5 — Re-embed mancanti + tag metadata

### 5a. Tag metadata sui 58K record già embeddati (SQL UPDATE istantaneo)
```sql
-- Tag docs e conversations già embeddati (embedding IS NOT NULL)
UPDATE vector_store
SET metadata = metadata || '{"embed_model": "qwen3-embedding:8b", "embed_version": "1"}'::jsonb
WHERE embedding IS NOT NULL
  AND metadata->>'embed_model' IS NULL;
```
Eseguito via psycopg2 diretto. ~58K righe, istantaneo.

### 5b. Embed i 22.7K mancanti (background notturno, ~12-13h GPU)

| Tipo | Count | Azione |
|------|-------|--------|
| Anki notes | 17,163 | Leggere content, get_embedding(), UPDATE embedding |
| Docs senza embedding | 3,517 | Leggere content, get_embedding(), UPDATE embedding |
| Conversations senza embedding | 2,085 | Leggere content, get_embedding(), UPDATE embedding |

Script: aggiungere flag `--backfill` a `openalex_embed.py` (o script separato `embed_backfill.py`).
Pattern: `SELECT id, content FROM vector_store WHERE embedding IS NULL`, poi per ogni record:
1. `get_embedding(content)` via GPU
2. `UPDATE vector_store SET embedding = %s WHERE id = %s`
3. Checkpoint ogni 100

### Verifica
```bash
# Dopo tag
SELECT count(*) FROM vector_store WHERE metadata->>'embed_model' IS NOT NULL;  -- ~58K+
# Dopo backfill
SELECT count(*) FROM vector_store WHERE embedding IS NULL;  -- 0
```

---

## Bug fix: `$$` in abstract rompe Cypher (critico per S3)

### Root cause
AGE usa `$$` come delimitatore Cypher. Abstract con formule LaTeX (`$$m\ge C$$`) chiudono prematuramente il blocco.
File problematici trovati: `W2611328865.json` (abstract con `$$m\ge...$$`), `W2735806552.json` (formule chimiche `$$Fe$$`).

### Fix
In `paper_archive.py`, funzione `esc()` — aggiungere sanitizzazione di `$$`:
```python
def esc(s):
    if s is None:
        return ""
    return str(s).replace("\\", "\\\\").replace("'", "\\'").replace("\n", " ").replace("\r", "").replace("$$", "$ $")
```
Il replace `$$` → `$ $` (spazio tra i due dollari) rompe il delimitatore senza alterare semanticamente il testo LaTeX per l'utente.

### Impatto
- 1 errore su S1 (10K paper)
- Stima ~50-100 errori su S3 (568K paper) — tutti paper con formule LaTeX negli abstract
- Fix retrocompatibile: i nodi già creati non sono affetti (il MERGE non ritenta)

### Verifica
```bash
# Dopo il fix, re-importare solo il paper mancante
openalex-import --input /mnt/hdd/openalex/cs --limit 10137  # idempotente, ri-esegue solo il fallito
```

---

## Verifica end-to-end

1. `/mnt/hdd/openalex/cs/` contiene ~3.9K file JSON (S1 CS)
2. `graph_stats(backend="age")` → Topic (~500-1K), Institution (~3-5K) presenti
3. `graph_query("MATCH (p:Paper) WHERE p.source = 'openalex' RETURN count(p)", "age")` → ~10K
4. `embeddings_stats()` → conteggio aumentato di ~10K
5. `embeddings_search_docs("portfolio selection Markowitz")` → trova paper OpenAlex
6. `embeddings_search_docs("attention mechanism in transformers")` → trova paper OpenAlex
