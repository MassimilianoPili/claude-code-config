# Piano: Kindle Pipeline (RSS → Kindle + Graph Enrichment)

## Context

Due progetti Kindle complementari nel ciclo della conoscenza personale:
- **RSS → Kindle**: alimenta il Kindle con contenuti quotidiani dai feed RSS
- **Kindle Graph Enrichment**: estrae concetti dagli highlight e li inserisce nel knowledge graph

Il flusso completo: RSS → Kindle → lettura → highlight → AGE graph → concetti → embedding → GraphRAG.

**Stato attuale**:
- `import_kindle.py` esiste ma punta a Neo4j (offline). Va migrato su AGE.
- `carlo_feeds.opml` con 104 feed RSS disponibile in `/data/massimiliano/kindle/`
- Root disk al 94% (1.8GB liberi) → niente calibre, approccio Python puro
- Nessun SMTP configurato, nessun My Clippings.txt presente
- Pattern AGE consolidato: `paper_archive.py` con `esc()`, `execute_age()`, `get_embedding()`, `upsert_embedding()`

---

## Progetto 1: RSS → Kindle

### Decisioni architetturali

| Dimensione | Scelta | Motivo |
|-----------|--------|--------|
| Calibre vs Python | **Python** (`feedparser` + `ebooklib` + `readability-lxml`) | Root disk al 94%, pip installa su `/data` via `--user` |
| Docker vs host | **Systemd timer** (user-level) | Job periodico breve, pattern già usato (paper-archive, docs-sync) |
| cron vs systemd | **Systemd timer** | `Persistent=true`, journalctl, coerente con gli altri |
| SMTP | **Python smtplib** (stdlib) + Gmail App Password | Zero dipendenze, il più veloce da attivare |
| Feed source | **Parse OPML** → genera `feeds.yml` curabile | 104 feed disponibili, curazione manuale dopo il parsing |

### Struttura file

```
/data/massimiliano/kindle/rss/
├── rss_to_kindle.py      # Script principale
├── feeds.yml             # Feed curati (generati da OPML, editabili)
├── .env                  # SMTP_USER, SMTP_PASS, KINDLE_EMAIL
├── state.json            # GUID articoli già inviati (dedup cross-run)
└── output/               # EPUB generati (auto-cleanup 7gg)

/data/massimiliano/shell-scripts/bin/
└── rss-kindle            # Wrapper (come paper-archive)

~/.config/systemd/user/
├── rss-kindle.service    # Oneshot
└── rss-kindle.timer      # Ogni giorno alle 06:00
```

### Fasi implementazione

#### Fase 1: Dipendenze Python (~5 min)
```bash
pip3 install --user feedparser ebooklib beautifulsoup4 lxml readability-lxml pyyaml
```
~8MB totali, su `/data` (non root). `readability-lxml` = equivalente di `auto_cleanup` di Calibre.

#### Fase 2: Configurazione feed (`feeds.yml`) (~15 min)
- Parsare `carlo_feeds.opml` per generare YAML iniziale
- Curare: ~25-30 feed dopo dedup e rimozione feed morti/kill-the-newsletter
- Categorie: rationalist, tech, economics (da OPML)
- Aggiungere feed tech mancanti (Anthropic, Julia Evans, ByteByteGo)

```yaml
oldest_article_hours: 24
max_articles_per_feed: 5
feeds:
  - name: "Astral Codex Ten"
    url: "https://astralcodexten.substack.com/feed/"
    category: rationalist
  # ...
```

#### Fase 3: Script principale `rss_to_kindle.py` (~45 min)

1. Carica config (`feeds.yml` + `.env`)
2. Fetch feed in parallelo (`ThreadPoolExecutor`, max 5 worker)
3. Filtra articoli per età (`oldest_article_hours`)
4. Dedup tramite `state.json` (GUID → timestamp, prune >14gg)
5. Per ogni articolo: estrai HTML pulito via `readability-lxml`, fallback su RSS `content:encoded`
6. Costruisci EPUB con `ebooklib`:
   - Cover con data + conteggio
   - TOC raggruppato per categoria
   - Un capitolo per articolo (titolo + autore + fonte + HTML pulito)
   - Immagini inline (cap 200KB/img, max 20/articolo)
7. Invia via SMTP Gmail (TLS 587, App Password)
8. Aggiorna `state.json`
9. Cleanup EPUB >7gg
10. Exit code: 0=ok, 1=parziale, 2=fallimento totale

CLI:
- `rss-kindle` — esecuzione normale
- `rss-kindle --dry-run` — genera EPUB senza inviare
- `rss-kindle --list` — mostra feed e date ultimo articolo
- `rss-kindle --test` — invia un EPUB di test (1 articolo)

#### Fase 4: Email (.env + Amazon) (~10 min)
```
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=<gmail>
SMTP_PASS=<App Password>
KINDLE_EMAIL=<kindle email>
```
→ L'utente deve configurare Amazon "Approved Personal Document E-mail List".

#### Fase 5: Wrapper + systemd timer (~10 min)
Timer alle 06:00, non collide con backup (03:00), embeddings reindex (04:00), paper-archive (06:30).

#### Fase 6: Test e verifica (~15 min)
1. `rss-kindle --dry-run` → EPUB generato, contenuto OK
2. `rss-kindle --test` → email SMTP OK
3. Kindle sync → documento visibile e leggibile
4. `systemctl --user enable --now rss-kindle.timer`

### Prerequisiti dall'utente
- [ ] Gmail App Password (2FA + password app specifica)
- [ ] Indirizzo Kindle Send-to-Kindle email
- [ ] Aggiunta email mittente in Amazon Approved list

---

## Progetto 2: Kindle Graph Enrichment

### Decisione architettuale chiave: migrazione a AGE

**Neo4j → AGE**. Motivi:
1. Neo4j è offline, AGE è il database primario con 783 nodi
2. 6/7 script di import puntano già ad AGE `knowledge_graph`
3. Author nodes condivisi con paper_archive.py (211 Author, MERGE automatico)
4. Un solo database da mantenere, backup, monitorare

Questo richiede **due script**: prima migrare `import_kindle.py` su AGE, poi il nuovo enrichment.

### Struttura file

```
/data/massimiliano/kindle/
├── import_kindle.py          # ESISTENTE (Neo4j, mantenuto come riferimento)
├── import_kindle_age.py      # NUOVO — import My Clippings su AGE
├── enrich_kindle.py          # NUOVO — concept extraction via Claude API
├── enrich_state.json         # Stato enrichment (libri processati, resume)
└── My Clippings.txt          # Da caricare (prerequisito)
```

### Fase 1: `import_kindle_age.py` — Import su AGE (~1.5h)

**Riuso** dal vecchio `import_kindle.py`:
- `parse_metadata()` (righe 38-86) — parser metadata EN/IT robusto
- `parse_clippings()` (righe 89-163) — parser My Clippings.txt
- `deduplicate()` (righe 166-179) — dedup per estensione highlight

**Riuso** da `paper_archive.py`:
- `esc()` (riga 54) — escape AGE
- `execute_age()` (riga 660) — esecuzione batch Cypher via `docker exec postgres psql`
- `get_embedding()` (riga 750) + `upsert_embedding()` (riga 767)

**Modello nodi in AGE `knowledge_graph`**:
```
(:Author {name, domain:'personal'})
  ^
  [:WRITTEN_BY]
(:Book {title, author, highlight_count, domain:'personal'})
  ^
  [:FROM]
(:Highlight {book_title, location_start, text, location_end, page, date_added, type, domain:'personal'})
```

**Note AGE-specifiche**:
- Niente `CREATE CONSTRAINT` (AGE non lo supporta, unicità via MERGE)
- `toLower(trim())` fatto in Python prima del Cypher (AGE ha funzioni limitate)
- Ogni `cypher()` con `RETURN` o `RETURN 0` e `AS (result agtype)`

**Embedding**: solo Book (mini-doc: titolo+autore+N highlight). Highlight individuali: no embedding in Fase 1, lo avranno dopo enrichment.

**CLI**: `python3 import_kindle_age.py [path] [--dry-run] [--embed|--no-embed] [--quiet]`

### Fase 2: `enrich_kindle.py` — Concept Extraction (~2h)

**LLM**: Claude Haiku via `proxy-ai` (localhost:8090, Anthropic API compatibile). ~$0.25 per 50 libri.
Chiamata con `urllib.request` (zero dipendenze, come paper_archive.py).

**Flusso**:
1. Query AGE: tutti gli highlight raggruppati per libro
2. Batch 15-20 highlight/libro → prompt strutturato a Claude
3. Parse JSON response → genera MERGE Cypher
4. Nodi `Concept {name, category, description, domain:'personal'}` con MERGE su `{name: lower_trimmed}`
5. Relazioni `(Highlight)-[:MENTIONS {relevance}]->(Concept)`
6. Traccia progresso in `enrich_state.json` (resume su interruzione)

**Prompt**: come nel piano originale. Concetti generici e riusabili, non specifici al libro.
Normalizzazione nomi: lowercase, singolare, inglese — fatta in Python pre-Cypher.

**CLI**:
- `enrich_kindle.py --extract` — estrazione concetti (Fase 2)
- `enrich_kindle.py --link` — cross-book concept linking (Fase 3)
- `enrich_kindle.py --embed` — embedding concetti e highlight arricchiti (Fase 4)
- `enrich_kindle.py --dry-run` — simula senza scrivere
- `enrich_kindle.py --book "Titolo"` — processa un solo libro

### Fase 3: Cross-Book Concept Linking (~30 min impl)

Parte di `enrich_kindle.py --link`:
1. Query concetti che appaiono in 2+ libri (già collegati via MERGE)
2. Per concetti isolati: batch a Claude Sonnet (richiede ragionamento)
3. `MERGE (c1)-[:RELATED_TO {strength, reason}]->(c2)`

### Fase 4: Embedding (~30 min impl)

`enrich_kindle.py --embed`:
- Concept: mini-doc = "Concept: {name}. Category: {category}. {description}. Books: {list}"
- Highlight arricchiti: mini-doc = "{text}. From: {book} by {author}. Concepts: {list}"
- Pattern identico a paper_archive.py: `get_embedding()` + `upsert_embedding()`

### Integrazione con graph esistente

- **Author dedup automatica**: MERGE su `{name}` → gli Author di paper_archive (211) si fondono con quelli Kindle
- **Concept separati**: i ~50 Concept di `rationalist_graph` restano in un grafo diverso. Il prompt di enrichment include la tassonomia razionalista come "preferred names" per favorire convergenza.
- **Domain tag**: tutti i nodi `domain:'personal'` per il filtraggio nel viewer D3.js

### Query patterns abilitati (verifica)

```cypher
-- Top concetti
MATCH (c:Concept)<-[:MENTIONS]-(h) RETURN c.name, count(h) ORDER BY count(h) DESC LIMIT 20

-- Concetti cross-book
MATCH (c:Concept)<-[:MENTIONS]-(h)-[:FROM]->(b:Book)
WITH c, collect(DISTINCT b.title) AS books WHERE size(books) > 1
RETURN c.name, books

-- Mappa concettuale autore
MATCH (a:Author)<-[:WRITTEN_BY]-(b)<-[:FROM]-(h)-[:MENTIONS]->(c)
WHERE a.name = 'Nome'
RETURN b.title, collect(DISTINCT c.name)

-- Highlight su concetto
MATCH (c:Concept {name: 'leadership'})<-[:MENTIONS]-(h)-[:FROM]->(b)
RETURN b.title, h.text
```

---

## Prerequisiti globali

| Prerequisito | Per | Azione utente |
|-------------|-----|---------------|
| `My Clippings.txt` | Progetto 2 | Upload su `/data/massimiliano/kindle/` |
| Gmail App Password | Progetto 1 | 2FA + genera App Password |
| Kindle email | Progetto 1 | Trovare in Amazon settings |
| Amazon approved sender | Progetto 1 | Aggiungere email Gmail |

## Sequenza implementazione

```
Progetto 1 (RSS → Kindle)          Progetto 2 (Graph Enrichment)
─────────────────────────           ─────────────────────────────
1. pip install deps                 1. import_kindle_age.py
2. Parse OPML → feeds.yml              (rewrite Neo4j → AGE)
3. rss_to_kindle.py                 2. enrich_kindle.py --extract
4. .env + Amazon config                (Claude Haiku, ~$0.25)
5. wrapper + systemd timer          3. enrich_kindle.py --link
6. test end-to-end                     (Claude Sonnet, ~$1)
                                    4. enrich_kindle.py --embed

I due progetti sono indipendenti e possono procedere in parallelo.
Progetto 2 richiede My Clippings.txt.
```

## File critici (riferimento)

| File | Ruolo |
|------|-------|
| `/data/massimiliano/kindle/import_kindle.py` | Sorgente parsing (parse_clippings, parse_metadata, deduplicate) |
| `/data/massimiliano/kindle/paper_archive.py` | Pattern AGE (esc, execute_age, get_embedding, upsert_embedding) |
| `/data/massimiliano/kindle/import_rationalist.py` | Modello Concept nodes (name, category, description) |
| `/data/massimiliano/kindle/carlo_feeds.opml` | 104 feed RSS da curare |
| `/data/massimiliano/kindle/import_infrastructure.py` | Pattern two-phase node/relationship |

## Verifica end-to-end

**Progetto 1:**
- `rss-kindle --dry-run` → EPUB generato con contenuto
- `rss-kindle --test` → email ricevuta su Kindle
- `journalctl --user -u rss-kindle` → nessun errore dopo prima esecuzione timer

**Progetto 2:**
- `python3 import_kindle_age.py --dry-run` → Cypher generato, conteggi corretti
- `python3 import_kindle_age.py` → nodi Book/Author/Highlight in AGE
- `graph_query("MATCH (b:Book) RETURN count(b)", backend="age")` → N libri
- `python3 enrich_kindle.py --extract --book "UnLibro"` → Concept nodes creati
- `graph_query("MATCH (c:Concept) RETURN count(c)", backend="age")` → N concetti
- `embeddings_search_docs("leadership")` → risultati da highlight Kindle
