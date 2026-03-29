# Report: OpenAlex API -- Stato attuale, rate limits, e integrazione SOL

**Data**: 2026-03-18
**Fonti consultate**: OpenAlex docs (GitHub raw MD), pyalex README, LLM API guide, rate-limits-and-authentication.md, snapshot-data-format.md, download-to-your-machine.md, codice `paper_archive.py`, codice `OpenAlexTools.java` + `ApiExtractors.java`

---

## 1. Rate Limits: sistema a crediti (cambiamento rispetto al vecchio modello)

Il vecchio modello (email nel User-Agent / `mailto=` per "polite pool" a 10 req/s) e' stato **sostituito** da un sistema a crediti.

| Parametro | Valore |
|-----------|--------|
| Crediti giornalieri (free) | 100,000 |
| Crediti giornalieri (premium) | negoziabili (contattare support@openalex.org; gratis per accademici) |
| Max req/sec | 100 (indipendente dai crediti) |
| Costo: singleton (`/works/W123`) | 1 credito |
| Costo: list (`/works?filter=...`) | 10 crediti |
| Costo: content (PDF, futuro) | 100 crediti |
| Costo: vector search (futuro) | 1,000 crediti |
| Costo: text/aboutness (`/text/topics`) | 1,000 crediti |

**Headers di risposta utili**:
- `X-RateLimit-Limit` -- limite giornaliero totale
- `X-RateLimit-Remaining` -- crediti residui
- `X-RateLimit-Credits-Used` -- crediti consumati dalla richiesta corrente
- `X-RateLimit-Reset` -- secondi al reset (mezzanotte UTC)

**Endpoint di verifica**: `GET https://api.openalex.org/rate-limit?api_key=YOUR_KEY`

**Implicazione per SOL**: con 100k crediti/giorno e 10 crediti/list request, si possono fare al massimo **10,000 ricerche list** al giorno, oppure **100,000 singleton lookups**. Il timer `paper-archive-scan.timer` (6h) con ~105 paper non e' un problema (massimo ~400 crediti/run). Ma un eventuale bulk enrichment di migliaia di paper richiederebbe pianificazione.

### Polite pool: ancora attivo ma secondario

Il meccanismo `mailto=` esiste ancora per identificarsi, ma il rate limit reale e' governato dai crediti. API key non obbligatoria per l'accesso base (contrariamente a quanto diceva pyalex README di feb 2026 -- la doc ufficiale attuale NON lo richiede come mandatory).

**Discrepanza pyalex vs docs**: pyalex README (aggiornato feb 2026) dice "API key required from Feb 13, 2026". La doc ufficiale OpenAlex dice "You don't need an API key to use OpenAlex". Probabilmente pyalex ha anticipato un cambiamento poi non attuato, oppure la doc ufficiale non e' aggiornata. **Raccomandazione**: ottenere comunque una API key gratuita (serve per `from_updated_date` filter e rate-limit monitoring).

---

## 2. Autenticazione: API Key

- **Gratuita**: registrarsi su openalex.org, settings > API
- **Utilizzo**: query param `?api_key=YOUR_KEY`
- **Premium**: limiti crediti superiori, filtro `from_updated_date`, supporto
- **Accademici**: possono ottenere premium gratuito contattando support@openalex.org

### Stato attuale su SOL

| Componente | Stato API Key | Stato mailto |
|------------|--------------|--------------|
| `paper_archive.py` | `OPENALEX_API_KEY` env var (pyalex config) | email in `pyalex.config.email` |
| `OpenAlexTools.java` | **MANCANTE** | email nel User-Agent header |

---

## 3. Confronto OpenAlex vs Semantic Scholar per paper_archive

| Dimensione | OpenAlex | Semantic Scholar |
|------------|----------|-----------------|
| **Coverage** | ~250M works, tutte le discipline | ~220M, bias verso STEM |
| **Dati unici OA** | Topics (3 livelli), institutions, funding, OA status, `referenced_works` lista completa | TLDR, influentialCitationCount, embedding vectors |
| **Abstract** | Inverted index (ricostruibile) | Testo diretto (quando disponibile) |
| **Venue/Source** | Ricchissimo: source ID, type, ISSN, host org | Campo `venue` stringa semplice |
| **Rate limit** | 100k crediti/giorno, 100 req/s | 5,000 req/5min senza API key, 1 req/s |
| **Stabilita' API** | Alta (nessun cambio breaking noto) | Media (429 frequenti, downtime occasionale) |
| **Licenza dati** | CC0 | Mixed (dipende dal publisher) |
| **Bulk download** | Si, S3 gratuito (~330GB gz) | Si, dataset release periodici |

**Verdetto per paper_archive.py**: la cascata attuale (S2 -> OpenAlex -> CrossRef) e' corretta. OpenAlex e' il miglior fallback quando S2 da' 429. I dati extra di OpenAlex (topics, institutions, referenced_works) giustificano una promozione a "always call" piuttosto che solo fallback.

---

## 4. Endpoint piu' utili per i nostri use case

### 4a. Per `paper_archive.py` (risoluzione citazioni)

| Endpoint | Uso | Costo |
|----------|-----|-------|
| `GET /works?search=<title>` | Ricerca per titolo | 10 crediti |
| `GET /works?filter=title.search:<title>` | Ricerca piu' precisa | 10 crediti |
| `GET /works?filter=doi:<doi>` | Lookup per DOI (batch fino a 50 con pipe) | 10 crediti |
| `GET /works/<W_ID>` | Singleton per ID | 1 credito |
| `GET /works?filter=doi:<doi1>\|<doi2>\|...\|<doi50>&per_page=50` | **Batch lookup** fino a 50 DOI in una chiamata | 10 crediti |

**Ottimizzazione chiave**: il batch DOI lookup con pipe operator. Se `paper_archive.py` ha 100 paper con DOI noto, servono 2 chiamate invece di 100 (risparmio: 980 crediti).

### 4b. Per `OpenAlexTools.java` (ricerca interattiva MCP)

| Endpoint | Uso | Priorita' |
|----------|-----|-----------|
| `GET /works?search=<query>&filter=<f>&sort=cited_by_count:desc` | Ricerca con filtri | Gia' implementato |
| `GET /works?filter=cites:<W_ID>` | Paper citati da X | Gia' implementato (neighborhood) |
| `GET /works?filter=cited_by:<W_ID>` | Paper che citano X | Gia' implementato |
| `GET /works?filter=related_to:<W_ID>` | Paper correlati | Gia' implementato |
| `GET /works?group_by=topics.id&filter=...` | Aggregazione per topic | **Da aggiungere** |
| `GET /authors?search=<name>` | Ricerca autore -> ID | **Da aggiungere** |
| `GET /works?filter=authorships.author.id:<A_ID>` | Works di un autore | **Da aggiungere** |
| `GET /text?title=<text>` | Topic tagging di testo arbitrario | **Da aggiungere** (1000 crediti!) |
| `GET /autocomplete/works?q=<prefix>` | Autocomplete (200ms) | Opzionale |

### 4c. Endpoint `select` per ridurre payload

Aggiungere sempre `select=id,title,authorships,publication_year,doi,topics,primary_location,cited_by_count,abstract_inverted_index` (gia' fatto in OpenAlexTools, ma manca `open_access` e `type`).

---

## 5. Filtri e parametri avanzati

### Filtri piu' utili per ricerca accademica

| Filtro | Esempio | Note |
|--------|---------|------|
| `publication_year` | `>2020`, `2018-2023` | Range supportato |
| `cited_by_count` | `>100` | Paper ad alto impatto |
| `is_oa` | `true` | Solo open access |
| `open_access.oa_status` | `gold`, `green`, `bronze` | Tipo OA |
| `type` | `journal-article`, `book`, `dataset` | Tipo pubblicazione |
| `topics.id` | `T10001` | Per topic OpenAlex |
| `has_doi` | `true` | Solo con DOI |
| `has_fulltext` | `true` | Solo con fulltext |
| `authorships.author.id` | `A5023888391` | Per autore |
| `authorships.institutions.id` | `I136199984` | Per istituzione |
| `primary_location.source.id` | `S137773608` | Per journal/source |
| `from_updated_date` | `2026-01-01` | **Solo premium** -- incrementale |

### Combinazione filtri

- AND: virgola (`,`) tra filtri diversi
- OR: pipe (`|`) dentro lo stesso filtro, max 50 valori
- Negazione: `!` prefisso (`type:!book`)
- **Limitazione**: non si puo' fare OR tra filtri diversi; servono query separate

### Parametri di query

| Param | Default | Max | Note |
|-------|---------|-----|------|
| `per_page` | 25 | 200 | Usare 200 per bulk |
| `page` | 1 | -- | Paginazione semplice |
| `sort` | relevance | -- | `cited_by_count:desc`, `publication_year:desc` |
| `sample` | -- | ~10000 | Campione casuale |
| `seed` | -- | -- | Per riproducibilita' del sample |
| `select` | tutti | -- | Riduce payload drasticamente |
| `group_by` | -- | 1 per query | Aggregazione (solo 1 dimensione per query) |

---

## 6. Bulk Download (Snapshot S3)

### Specifiche

| Parametro | Valore |
|-----------|--------|
| Location | `s3://openalex` (AWS, no account richiesto) |
| Formato | JSON Lines (.gz), un file per entity type |
| Dimensione compressa | ~330 GB |
| Dimensione decompressa | ~1.6 TB |
| Aggiornamento | Mensile circa |
| Partitioning | Per `updated_date` (incrementale) |
| Entity types | works, authors, sources, institutions, topics, fields, subfields, domains, publishers, funders, concepts |
| Merged entities | Cartella separata `merged_ids/` |
| Licenza | CC0 |
| Costo trasferimento | Gratuito (AWS Open Data program) |

### Comandi download

```bash
# Download completo (~330GB, serve spazio)
aws s3 sync "s3://openalex" "openalex-snapshot" --no-sign-request

# Solo works (il piu' grande)
aws s3 sync "s3://openalex/data/works" "openalex-snapshot/works" --no-sign-request

# Solo aggiornamenti dopo una data
aws s3 sync "s3://openalex/data/works/updated_date=2026-03-01/" "openalex-snapshot/works/2026-03-01/" --no-sign-request

# Verificare dimensione prima del download
aws s3 ls --summarize --human-readable --no-sign-request --recursive "s3://openalex/"
```

### Rilevanza per SOL

Il bulk download **non ha senso** per l'uso attuale (105 paper, crescita lenta). Avrebbe senso solo se:
- Si volesse costruire un indice locale completo per ricerca semantica
- Si volesse pre-popolare il knowledge graph con tutti i paper di certi autori/topic
- Si volesse un motore di ricerca accademica self-hosted (alternativa a S2/OpenAlex API)

**Su Gaia (64GB RAM, 1.8TB NVMe)**: potrebbe ospitare un sottoinsieme del dump (es. solo CS papers degli ultimi 10 anni) importato in PostgreSQL. Stima: ~20M works CS, ~40GB compressi, ~200GB decompressi. Fattibile ma non prioritario.

---

## 7. Confronto con alternative (S2, CrossRef, PubMed)

| Dimensione | OpenAlex | Semantic Scholar | CrossRef | PubMed |
|------------|----------|-----------------|----------|--------|
| Works | ~250M | ~220M | ~150M | ~36M |
| Copertura | Tutte le discipline | STEM-heavy | Con DOI | Biomedico |
| Abstract | Inverted index | Testo | JATS XML (parziale) | Testo |
| Citation graph | `referenced_works` + `cited_by` API | Si, con influentialCitations | No | No |
| Topics/Concepts | Si (3 livelli, ML-assigned) | No nativamente | No | MeSH terms |
| Institutions | Si (ROR-linked) | Parziale | No | Affiliations testo |
| OA status | Si (dettagliato) | Si (basico) | No | PubMed Central |
| Rate limit | 100k crediti/giorno | 5k req/5min | 50 req/s (polite) | 10 req/s |
| Bulk download | S3 gratuito, 330GB | Dataset periodici | Torrent/dump | FTP |
| Licenza | CC0 | Varia | Metadata CC0 | Public domain |
| API stability | Alta | Media (429 frequenti) | Alta | Alta |
| TLDR | No | Si | No | No |
| Embedding vectors | No | Si (SPECTER) | No | No |

**Conclusione**: OpenAlex e' il miglior "first call" per metadata (venue, topics, institutions, OA status). S2 resta superiore per TLDR, influentialCitationCount, e embeddings. CrossRef e' il fallback piu' robusto per DOI resolution. PubMed solo per biomedico.

---

## Azioni concrete

### A. `paper_archive.py` -- 4 modifiche

1. **Promuovere OpenAlex a seconda fonte (dopo arXiv, prima di CrossRef)**
   - Attuale cascata: arXiv (se ID) -> S2 -> OpenAlex -> CrossRef
   - Nuova cascata: arXiv (se ID) -> S2 -> OpenAlex -> CrossRef (invariata, ma cambiare la logica: chiamare **sempre** OpenAlex per arricchimento anche quando S2 ha gia' risolto, analogamente a come gia' si chiama S2 dopo arXiv per DOI+citations)
   - Motivazione: topics, institutions, referenced_works_count sono dati che solo OpenAlex fornisce

2. **Aggiungere batch DOI lookup**
   - Nel mode `--scan`, raccogliere tutti i DOI noti e fare lookup batch con pipe operator (50 DOI per chiamata)
   - Risparmio: da N chiamate a ceil(N/50) chiamate
   - Aggiungere `resolve_batch_via_openalex(dois: list[str])` che usa `?filter=doi:<d1>|<d2>|...&per_page=50&select=...`

3. **Salvare e usare la API key**
   - Gia' configurato via `OPENALEX_API_KEY` env var in pyalex
   - Aggiungere la stessa key anche nelle chiamate dirette `urllib` (param `api_key`)
   - Registrare una key su openalex.org/settings/api

4. **Monitorare i crediti**
   - Dopo ogni batch, loggare `X-RateLimit-Remaining` dall'header di risposta
   - Aggiungere `--check-credits` flag che chiama `/rate-limit?api_key=...`

### B. `OpenAlexTools.java` -- 3 modifiche

1. **Aggiungere API key support**
   - Leggere `OPENALEX_API_KEY` da env/config
   - Aggiungerla come query param `api_key` a tutte le richieste
   - Aggiungere `mailto=` per il polite pool come fallback

2. **Aggiungere tool `openalex_author_works`**
   - Two-step pattern: cerca autore per nome -> ottieni ID -> filtra works per autore
   - Oppure tool singolo che accetta `authorId` (OpenAlex ID o ORCID)

3. **Aggiungere tool `openalex_group_by`**
   - Permette aggregazioni: `group_by=topics.id`, `group_by=publication_year`, etc.
   - Utile per analisi bibliometriche rapide

4. **(Opzionale) Aggiungere `openalex_text_tag`**
   - Chiama `POST /text?title=...` per topic tagging
   - Attenzione: 1000 crediti per chiamata, usare con parsimonia

### C. Bulk download -- decisione rimandata

- **Non prioritario** per l'uso attuale (105 paper)
- **Prerequisito**: Gaia operativo con Docker + PostgreSQL
- **Se si volesse procedere**:
  - Scaricare solo `works` filtrati per topic CS (~40GB gz)
  - Importare in PostgreSQL su Gaia con schema normalizzato
  - Creare indice pgvector sugli abstract per ricerca semantica locale
  - Sync incrementale mensile via partizioni `updated_date`

### D. Aggiornamento `CLAUDE.md` system prompt

Aggiornare la sezione OpenAlex nel system prompt del research agent:
- Endpoint base resta `https://api.openalex.org`
- Aggiungere nota sul sistema a crediti (10 per list, 1 per singleton)
- Aggiungere nota sul batch DOI lookup con pipe
- Aggiungere parametro `select=` come best practice
- Aggiungere `from_updated_date` per premium users
