# Small Web Crawler — 4.900 feed RSS → KORE

## Context

SearXNG aggrega risultati da motori commerciali (Google, Bing, DDG) che hanno un bias strutturale verso contenuti SEO-ottimizzati. Blog personali, forum indipendenti, siti non-commerciali — il "piccolo web" — vengono sotto-rappresentati.

Kagi mantiene una lista open source curata di **~4.900 feed RSS** di blog personali (`kagisearch/smallweb` su GitHub). Criteri: no AI-generated, no ads, no multi-author, contenuti genuini. La lista è un file di testo piatto con un feed URL per riga.

**Obiettivo**: crawlare tutti i 4.900 feed, ingerire i contenuti in KORE (AGE + pgvector), renderli ricercabili via `embeddings_search_docs` e automaticamente via KORE prepend in `web_search`.

**Approccio**: principio di inesorabilità — **1 feed al minuto**, timer systemd ogni minuto. ~82 ore per il primo pass completo. Poi ciclo continuo: skip feed già processati, ingest nuovi post.

---

## Architettura

```
smallweb.txt (4.900 feed URL)
    ↓ download da GitHub (una volta, poi aggiornamento settimanale)

smallweb-crawl (timer: ogni minuto)
    ↓ prende il prossimo feed dal checkpoint
    ↓ feedparser: parse RSS/Atom
    ↓ per ogni post recente (< 30 giorni):
    │   ├── AGE: MERGE (b:BlogPost {url, title, author, ...})
    │   ├── AGE: MERGE (a:Author {name}) + WRITTEN_BY
    │   └── pgvector: embedding title+content (tag: smallweb)
    ↓ checkpoint: segna feed come processato
    ↓ log: nuovi/skip/errori

smallweb-enrich (timer: ogni notte 02:30)
    ↓ query AGE: BlogPost con content_status='summary'
    ↓ fetch full content (20/run, 1/min)
    ↓ aggiorna embedding con testo completo (tag: smallweb-full)
```

---

## File da creare

| File | Descrizione |
|------|-------------|
| `kindle/feeds/` | **Cartella** — file .txt con feed URL, uno per riga (formato di lavoro) |
| `kindle/feeds/kagi-smallweb.txt` | Lista Kagi (scaricata da GitHub, ~4.900 feed) |
| `kindle/feeds/personal.txt` | Feed aggiunti manualmente dall'utente |
| `kindle/feeds/opml/` | **Archivio** — OPML originali importati da reader/servizi (preservati) |
| `kindle/smallweb_crawl.py` | Script Python principale (~300 righe) |
| `shell-scripts/bin/smallweb-crawl` | Wrapper bash |
| `~/.config/systemd/user/smallweb-crawl.service` | Unit systemd |
| `~/.config/systemd/user/smallweb-crawl.timer` | Timer ogni minuto |
| `~/.config/systemd/user/smallweb-enrich.service` | Unit systemd (full content) |
| `~/.config/systemd/user/smallweb-enrich.timer` | Timer notturno 02:30 |

---

## Implementazione dettagliata

### `kindle/smallweb_crawl.py`

**Dipendenze**: `feedparser`, `psycopg2` (già installati — usati da `rss_to_kindle.py` e `paper_archive.py`)

**Pattern da riusare**:
- `paper_archive.py`: `get_pg_connection()`, `execute_age()`, `upsert_embedding()` — importare direttamente
- `rss_to_kindle.py`: pattern feedparser + timeout + error handling per singolo feed
- `openalex_embed.py`: checkpoint JSON + atomic writes

**Struttura**:

```python
# kindle/smallweb_crawl.py

FEEDS_DIR = Path("/data/massimiliano/kindle/feeds/")   # cartella con .txt di feed URL
FEEDS_URL = "https://raw.githubusercontent.com/kagisearch/smallweb/main/smallweb.txt"
CHECKPOINT_FILE = Path("/data/massimiliano/kindle/.smallweb_checkpoint.json")
STATE_FILE = Path("/data/massimiliano/kindle/.smallweb_state.json")

MAX_AGE_DAYS = 30          # ignora post > 30 giorni
FETCH_TIMEOUT = 15         # timeout per feed (secondi)
FEEDS_PER_RUN = 1          # 1 feed per run (inesorabilità)

# feeds/ contiene file .txt con un feed URL per riga:
#   feeds/kagi-smallweb.txt    (scaricato da GitHub, ~4.900 feed)
#   feeds/personal.txt         (feed aggiunti manualmente)
#   feeds/tech.txt             (feed tech curati)
#   feeds/*.txt                (qualsiasi file → merge in un unico elenco)
```

**Modalità**:

1. `--update-feeds`: scarica `smallweb.txt` da GitHub → `feeds/kagi-smallweb.txt`
2. `--crawl` (default): legge tutti i `feeds/*.txt`, merge + dedup, processa il prossimo feed dal checkpoint
3. `--enrich`: fetch full content per post con `content_status='summary'`
4. `--stats`: mostra statistiche (feed processati, post totali, errori, per-file breakdown)
5. `--reset`: resetta checkpoint (ricomincia da capo)

**Aggiungere feed**: basta creare/modificare un file `.txt` in `kindle/feeds/`. Lo script li merge tutti automaticamente al prossimo run. Esempio: `echo "https://myblog.com/feed.xml" >> kindle/feeds/personal.txt`

**Importare OPML**: `--import-opml file.opml` → salva originale in `feeds/opml/`, estrae gli `xmlUrl` e li scrive in `feeds/<nome>.txt`. L'OPML originale viene conservato come archivio.

**Checkpoint** (`smallweb_checkpoint.json`):
```json
{
  "next_index": 1234,
  "total_feeds": 4900,
  "processed": {"feed_url_hash": {"ts": "...", "posts": 5, "errors": 0}},
  "cycle": 1
}
```
- `next_index`: indice nel file feeds.txt del prossimo feed da processare
- Quando raggiunge la fine, `cycle += 1` e `next_index = 0` (ricomincia)
- Ogni feed processato: salva timestamp, conteggio post, errori

**State** (`smallweb_state.json`): deduplicazione post
```json
{
  "seen": {"url_hash_16": {"ts": "...", "title": "..."}}
}
```
- Pruning automatico: rimuovi entry > 90 giorni

**AGE schema**:
```cypher
MERGE (b:BlogPost {url: $url})
SET b.title = $title, b.author = $author, b.published = $published,
    b.summary = $summary, b.source = 'kagi-smallweb',
    b.domain = 'personal', b.content_status = 'summary',
    b.feed_url = $feed_url, b.crawled_at = $now

MERGE (a:Author {name: $author})
MERGE (b)-[:WRITTEN_BY]->(a)
```

**Embedding**:
```python
doc = f"Blog: {title}\nAuthor: {author}\n\n{summary_or_content}"
upsert_embedding(slug, "BlogPost", "personal", doc, vec,
                 source="kagi-smallweb",
                 embed_model=EMBED_MODEL,
                 embed_dimensions=str(EMBED_DIMENSIONS))
```
- Tag: `smallweb` per summary, `smallweb-full` per full content
- Embedding model: `qwen3-embedding:8b` (4096 dim) via Ollama su gaia

**Enrich mode** (`--enrich`):
- Query AGE per BlogPost con `content_status = 'summary'`
- Fetch URL con `urllib` + strip HTML (o readability se disponibile)
- Batch: 20 post/run, sleep 60s tra fetch (1/min, inesorabile)
- Aggiorna: `content_status = 'full'`, re-embed con testo completo

### `shell-scripts/bin/smallweb-crawl`

```bash
#!/bin/bash
# smallweb-crawl — Kagi Small Web RSS crawler → KORE
# 1 feed/min, inesorabile
export PG_CRED="${PG_CRED:-$(grep '^POSTGRES' /data/massimiliano/postgres/.env 2>/dev/null | cut -d= -f2)}"
exec python3 /data/massimiliano/kindle/smallweb_crawl.py "$@"
```

### Systemd units

**Timer** (`smallweb-crawl.timer`):
```ini
[Unit]
Description=Small Web crawler — 1 feed/min

[Timer]
OnCalendar=*:*:00
Persistent=true

[Install]
WantedBy=timers.target
```

**Service** (`smallweb-crawl.service`):
```ini
[Unit]
Description=Small Web crawler

[Service]
Type=oneshot
ExecStart=/data/massimiliano/shell-scripts/bin/smallweb-crawl --crawl
Environment=PATH=/data/massimiliano/shell-scripts/bin:/usr/local/bin:/usr/bin
TimeoutStartSec=120
```

**Enrich timer** (`smallweb-enrich.timer`):
```ini
[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true
```

**Enrich service**: `ExecStart=... --enrich`

---

## Pattern riusati dal codebase

| Pattern | Fonte | Uso |
|---------|-------|-----|
| psycopg2 singleton + autocommit | `paper_archive.py:get_pg_connection()` | Connessione DB |
| AGE Cypher via psycopg2 diretto | `paper_archive.py:execute_age()` | MERGE nodi/relazioni |
| Embedding upsert con versioning | `paper_archive.py:upsert_embedding()` | pgvector |
| Checkpoint JSON + atomic write | `openalex_embed.py` | Resume da failure |
| State file deduplicazione + pruning | `rss_to_kindle.py` | Skip post già visti |
| feedparser + timeout | `rss_to_kindle.py` | Parse RSS/Atom |
| Wrapper bash con PG_CRED auto | `shell-scripts/bin/openalex-import` | Environment setup |
| Timer systemd user-level | `paper-archive-scan.timer` | Scheduling |

---

## Verifica

1. **Download feeds**: `smallweb-crawl --update-feeds` → verifica `kindle/feeds/kagi-smallweb.txt` (~4.900 righe)
2. **Run singolo**: `smallweb-crawl --crawl` → verifica log (1 feed processato, N post ingeriti)
3. **Nodi AGE**: `graph_query("MATCH (b:BlogPost) WHERE b.source = 'kagi-smallweb' RETURN count(b)", backend="age")`
4. **Ricerca semantica**: `embeddings_search_docs("self-hosted blog independent")` → verificare risultati smallweb
5. **Stats**: `smallweb-crawl --stats` → feed processati, post totali, prossimo feed
6. **Timer**: `systemctl --user status smallweb-crawl.timer` → verificare attivazione ogni minuto
7. **Enrich**: dopo qualche giorno, `smallweb-crawl --enrich` → verifica `content_status='full'`

---

## Numeri attesi

| Metrica | Stima |
|---------|-------|
| Feed totali | ~4.900 |
| Primo pass completo | ~82 ore (~3.4 giorni) |
| Post per feed (media) | ~5-10 recenti (<30gg) |
| Post totali primo pass | ~25.000-50.000 |
| Embedding time (Ollama) | ~1-2s/post |
| Spazio pgvector | ~200-400 MB |
| Nodi AGE | ~50.000 BlogPost + ~4.000 Author |

Dopo il primo pass, i cicli successivi saranno molto più veloci (skip feed senza nuovi post).
