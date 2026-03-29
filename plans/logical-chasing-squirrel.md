# Piano: Deck Anki Custom via SOL

## Context

L'infrastruttura Anki su SOL è completa e funzionante:
- **anki-sync** (Rust v25.09.2) + **anki-api** (FastAPI) — entrambi healthy
- **22,430 card** in 90+ deck, 643 MB dati (collection + media)
- **11 MCP tools** operativi (CRUD + review + bulk + export)
- **Embedding notturno** (`anki-embed.timer`, 04:15, pipeline v3, dual OCR) — **VERIFICATO OK**:
  - Timer enabled, active. Last run 2026-03-23 04:15→05:00 (45min, exit 0)
  - **17,175 embeddings** in pgvector (4096 dim, qwen3-embedding:8b), su 22,430 card (76.6% — gap atteso: card vuote/sospese)
  - Pipeline v3: 17,163 / v1 legacy: 12
  - Vision cache: 204 immagini (dual OCR qwen3-vl + PaddleOCR-VL su gaia)
  - Audio cache: 600 audio (faster-whisper)
  - Ricerca semantica `embeddings_search("anki flashcard")` → funziona
- **pgvector**: metadata `source=anki`, label `AnkiNote`, ricerca semantica attiva
- **AGE**: DockerService + ScheduledJob + NginxRoute + Concept (FSRS-6) presenti

**Manca**: creare deck custom sfruttando KORE come fonte di conoscenza.

## Task (in coda)

### 1. Pipeline automatico: KORE → Anki deck

**Obiettivo**: generare card dai ~50K nodi KORE (Paper, Book/Kindle, Concept) usando LLM.

**Cosa esiste già**:
- `/data/massimiliano/kindle/llm_batch.py` — fase `anki` (01:00-03:15 UTC) che genera card dai Paper
- Query: `MATCH (p:Paper) WHERE p.summary_at IS NOT NULL AND p.anki_generated IS NULL`
- **Blocco attuale**: 0 Paper hanno `summary_at` → il pipeline non genera nulla

**Azioni**:
1. Attivare la fase `summarize` di `llm_batch.py` (o popolare `summary_at` in altro modo) per i Paper con abstract
2. Verificare che il deck `Papers::Auto-Generated` venga creato e popolato
3. Estendere il pipeline per coprire anche Book/Kindle (highlight → card)
4. Aggiungere deck auto per Concept con relazioni (es. "Cos'è X? → definizione + relazioni dal grafo")

**File critici**:
- `/data/massimiliano/kindle/llm_batch.py` — pipeline principale
- `/data/massimiliano/kindle/embed_anki.py` — embedding card
- `/data/massimiliano/anki/api/main.py` — API endpoints

### 2. Workflow manuale: deck curati via Claude

**Obiettivo**: creare deck tematici su misura (es. "Spring Boot Patterns", "Cypher Queries", "Infra SOL") con Claude come assistente.

**Cosa esiste già**:
- MCP tools `anki_create_deck`, `anki_add_note`, `anki_bulk_add_notes`
- Ricerca semantica KORE (`embeddings_search`, `graph_query`)

**Azioni**:
1. Nessun codice nuovo necessario — i tool MCP bastano
2. Workflow: query KORE per topic → genera card con Claude → `anki_bulk_add_notes`
3. Opzionale: creare una skill Claude Code `/anki-deck` per standardizzare il workflow

## Verifica

- `anki_list_decks` — verificare nuovi deck creati
- `anki_search_notes(query="deck:Papers::Auto-Generated", deckId=0)` — verificare card auto-generate
- `embeddings_search(query="<topic>")` → confermare che le nuove card vengono embeddate al ciclo successivo
- Logs: `journalctl --user -u anki-embed.service --since today`

## Issue trovate durante verifica

### A. Media embedding gap (PRIORITA' ALTA — fare subito)

17,175/17,194 note embeddate (99.9%), MA la maggior parte dei media NON è ancora processata:
- **Vision**: 204/3,551 immagini in cache (5.7%) → **3,545 da processare**
- **Audio**: 600/6,375 audio in cache (9.4%) → **~5,775 da processare**
- **qwen3-vl:32b**: NON scaricato su gaia (mancante dalla `ollama list`)
- **PaddleOCR-VL**: NON disponibile su gaia (nessun container vLLM)

Le note con media sono embeddate, ma con placeholder vuoti al posto del testo OCR/transcript.
Effetto: le 934 note media-only hanno embedding basato solo su "Deck: X | Type: Y" senza contenuto reale.

#### A1. Upgrade modello Vision — `qwen2.5vl:32b` (Ollama, 21GB)

**Scelta**: `qwen2.5vl:32b` su Ollama — **miglior modello OCR open-source** (benchmarks marzo 2025: ~75% JSON extraction accuracy, #1 su OCRBench v2 tra modelli <72B). Disponibile anche `qwen3-vl:32b` (21GB, stesso VRAM) ma è generazione più recente e meno testata specificamente per OCR.

**Confronto modelli disponibili su Ollama per 3090 (24GB VRAM)**:
| Modello | Size | OCRBench | Note |
|---------|------|----------|------|
| `qwen2.5vl:32b` | 21GB | ~850+ (stimato) | **Campione OCR provato**, RL-enhanced |
| `qwen3-vl:32b` | 21GB | N/D (nuovo) | Generazione più nuova, meno benchmark OCR |
| `qwen2.5vl:7b` | 6GB | buono | Troppo piccolo per OCR di qualità su formule/diagrammi |
| `minicpm-v` | 5.5GB | medio | Legacy, già su gaia, molto inferiore |

**Raccomandazione**: scaricare `qwen2.5vl:32b` (provato) come primary. Se dopo test non soddisfa, provare `qwen3-vl:32b`.

**Semplificazione architettura**: eliminare dual OCR (PaddleOCR-VL + Qwen3-VL). Un singolo modello forte è più affidabile del pattern stop/start vLLM/Ollama per VRAM juggling.

**Azioni su gaia**:
```bash
ssh gaia "docker exec ollama ollama pull qwen2.5vl:32b"
# Rimuovere modelli inutilizzati per spazio disco:
ssh gaia "docker exec ollama ollama rm minicpm-v"
ssh gaia "docker exec ollama ollama rm nomic-embed-text"
```

**Modifiche a `embed_anki.py`** (`/data/massimiliano/anki/embed_anki.py`):
- Linea 52: `VISION_PRIMARY = "qwen2.5vl:32b"` (era `qwen3-vl:32b`)
- Rimuovere tutta la logica dual-model PaddleOCR (phase 1/2/3, `_paddleocr_vision`, `_stop_paddleocr`, `_start_paddleocr`, `_check_paddleocr`)
- Semplificare `process_vision_batch` a single-pass: solo Ollama vision
- `DEFAULT_VISION_BATCH = 2000` → OK (converge in 2 notti)

#### A2. Upgrade modello Audio — faster-whisper `large-v3`

**Scelta**: `large-v3` (3GB model, ~6GB RAM) — significativamente migliore del `small` (245MB) per lingue europee (tedesco, francese, italiano). Su CPU è ~10x più lento ma la velocità non ci interessa.

**Confronto**:
| Modello | Size | WER multilingual | Note |
|---------|------|-----------------|------|
| `small` (attuale) | 245MB | ~23% | Veloce, accuratezza limitata |
| `medium` | 1.5GB | ~17% | Buon compromesso |
| `large-v3` | 3GB | ~10% | **Migliore accuratezza**, specialmente EU langs |

**Modifiche a `embed_anki.py`**:
- Linea 434: `WhisperModel("large-v3", ...)` (era `"small"`)
- `DEFAULT_AUDIO_BATCH`: da `200` a `500` (large-v3 è più lento, ma batch più grande per convergere prima)
- Bump `AUDIO_VERSION` da `1` a `2` → invalida cache, ri-trascrive tutto con modello migliore
- Bump `PIPELINE_VERSION` da `3` a `4` → ri-embedda tutto con OCR+transcript migliori

#### A3. Run manuale per accelerare convergenza

Dopo le modifiche, un run manuale:
```bash
nohup /data/massimiliano/anki/venv/bin/python /data/massimiliano/anki/embed_anki.py > /tmp/anki-embed-manual.log 2>&1 &
```

### B. Pipeline Paper→Anki dormiente (BASSA PRIORITA' — in coda)
0 Paper con `summary_at` → il batch in llm_batch.py non genera card.
Da attivare quando si lavora sul pipeline LLM.

## Verifica post-implementazione

1. `ssh gaia "docker exec ollama ollama list"` → confermare `qwen2.5vl:32b` scaricato
2. `python embed_anki.py --dry-run` → confermare che vede 3,545 immagini + 6,375 audio da processare
3. Dopo primo run reale: `vision_cache.json` deve crescere da 204 a ~2204 entries
4. `journalctl --user -u anki-embed.service --since today` → no errori
5. Query pgvector: `SELECT count(*) FROM vector_store WHERE metadata->>'source' = 'anki' AND metadata->>'pipeline_version' = '4'`

## Stato

**Issue A**: da implementare subito (3 step: download modello, edit script, run manuale).
**Task 1-2 + Issue B**: in coda.
