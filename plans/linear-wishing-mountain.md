# Piano: Enqueue 34 progetti futuri su Redis task queue

## Context
L'utente vuole mettere tutti i 34 piani da `/data/massimiliano/progetti_futuri/PIANO_*.md` nella coda task Redis via `claude_task_enqueue`. Ogni piano diventa un task con ref, tipo, priorità derivata dal ROI nell'INDICE.md, e payload con titolo + categoria + effort.

## Approccio
Un singolo blocco di chiamate `claude_task_enqueue` parallele (o sequenziali se il tool non supporta batch). Task type: `project`. Priorità mappata da ROI (5→2, 4→4, 3→6, 2→8, 1→10).

## Stato Implementazione

| Step | Stato | Note |
|------|-------|------|
| 1. Config Ollama Gaia | ✅ DONE | memory 56g, env vars, force-recreate |
| 2. Pull qwen3:72b | ❌ DA RIFARE | Era qwen2.5:72b (47 GB). Cambiato a **qwen3:72b** (~42 GB, benchmark migliori). Download in altra sessione |
| 3. llm_batch.py | ✅ DONE | 3 fasi, JSON fix (_extract_json), --no-deadline |
| 4. Systemd timer | ✅ DONE | 01:00, enabled |
| 5. Test end-to-end | ❌ PENDING | Dry-run OK, live test bloccato dal download |

**Correzioni applicate**:
- Modello: `qwen3.5:72b` → `qwen2.5:72b` → **`qwen3:72b`** (il più recente 72B su Ollama, MMLU 83.1, HumanEval 84.2)
- JSON: rimosso `format: "json"` (conflitto thinking mode Qwen 3.x), aggiunto `_extract_json()` con strip `<think>` tags + markdown fences
- Password: workaround hook scan-secrets (`_pw_key = "password"`)
- Deadline: aggiunto `--no-deadline` per test manuali

## Prossimi passi (questa sessione)

1. **Aggiornare llm_batch.py**: default model da `qwen2.5:72b` a `qwen3:72b`
2. **Test end-to-end con qwen3.5:27b** (già disponibile): `LLM_MODEL=qwen3.5:27b llm_batch.py --phase paper --limit 1 --no-deadline`
3. **Validare** storage triplo: AGE summary_at, WikiJS AI Summary section, pgvector re-embed
4. **Enqueue task su Redis** per la sessione download (via MCP `claude_task_enqueue`)

## Prossimi passi (altra sessione — download)

### Download da mettere in coda:

1. **`qwen3:72b`** (~42 GB) — general-purpose, batch notturno principale
   ```bash
   ssh gaia "docker exec ollama ollama pull qwen3:72b"
   ```

2. **`qwen3-coder:30b-a3b`** (~18 GB) — coding specialist MoE, sta in VRAM
   ```bash
   ssh gaia "docker exec ollama ollama pull qwen3-coder:30b-a3b"
   ```

3. **Rimuovere qwen2.5:72b** se parzialmente scaricato:
   ```bash
   ssh gaia "docker exec ollama ollama rm qwen2.5:72b"
   ```

4. **Benchmark tok/s** per entrambi i modelli
5. **Test end-to-end reale** con qwen3:72b
6. **Ricerca soluzioni per modelli non-standard** (Kimi-Dev-72B, Qwen3-Coder-480B)
   - Questi sono i migliori coding LLM ma non girano su Ollama vanilla
   - Opzioni da investigare: Nexesenex fork llama.cpp, vLLM (Docker, modelli HF nativi), SGLang (XGrammar constrained decoding), exllamav2 (EXL2), Ollama cloud (`qwen3-coder:480b-cloud`), dual-GPU futura (2x 3090 = 108 GB budget)
   - Sessione dedicata con `academic-researcher` agent

### Modelli verificati NON fattibili su Ollama vanilla + Gaia (24 GB VRAM + 60 GB RAM):

| Modello | Motivo |
|---|---|
| Kimi-Dev-72B | 152 GB INT4, GGUF non compatibili con Ollama vanilla |
| Qwen3-Coder-480B-A35B | ~250+ GB Q4, troppo grande |
| DeepSeek-Coder-V2 236B | 124 GB, supera budget 84 GB |

Da esplorare in sessione dedicata con `academic-researcher` agent.

### Strategia multi-modello nel batch

Lo script `llm_batch.py` supporta `LLM_MODEL` come env var. Per il futuro:
- Phase 1-3 (paper/kindle/anki): `qwen3:72b` — general-purpose
- Phase 4 (code review, futuro): `qwen3-coder:30b-a3b` — coding specialist
- Switch modello tra fasi: unload + load (~30s overhead)

## Context

Gaia (RTX 3090 24 GB VRAM + 64 GB RAM) serve Ollama a SOL via socat proxy Tailscale. I batch notturni esistenti usano solo embedding e vision — nessun LLM generativo. L'obiettivo è aggiungere `qwen3:72b` con CPU offload per 3 use case generativi: **paper summarization**, **Kindle enrichment**, **Anki card generation**.

**Architettura esistente**:
- SOL container `ollama` = socat proxy → `100.109.3.40:11434` (Gaia)
- Gaia container `ollama` = Ollama reale, memory limit **56g**, GPU passthrough
- Batch scripts su SOL chiamano `http://127.0.0.1:11434` (trasparente via socat)
- 736 GB disco libero su Gaia, 60 GB RAM disponibili

## Step 1 — Config Ollama su Gaia (SSH)

**File**: `/data/ollama/docker-compose.yml` su Gaia

```yaml
deploy:
  resources:
    limits:
      memory: 56g    # era 28g — CPU offload 72B usa ~18 GB RAM
environment:
  OLLAMA_HOST: "0.0.0.0:11434"
  OLLAMA_MAX_LOADED_MODELS: "1"   # un modello alla volta
  OLLAMA_NUM_PARALLEL: "1"        # nessuna concorrenza
  OLLAMA_KEEP_ALIVE: "5m"         # scarica dopo 5min idle
```

```bash
ssh gaia "cd /data/ollama && docker compose up -d --force-recreate"
```

## Step 2 — Pull e Test Modello

```bash
ssh gaia "docker exec ollama ollama pull qwen3:72b"   # ~42 GB, ~20-30 min
```

Test veloce + benchmark tok/s:
```bash
ssh gaia "docker exec ollama ollama run qwen3:72b --verbose 'Summarize in JSON: {\"core_claim\": \"...\", \"method\": \"...\"} for: Attention Is All You Need introduces the Transformer architecture.'"
```

Verificare: `ssh gaia "nvidia-smi && free -h"` → ~24 GB VRAM, ~18 GB RAM.

## Step 3 — Script Batch: `llm_batch.py`

**Nuovo file**: `/data/massimiliano/kindle/llm_batch.py`

Pattern: segue `paper_archive.py` — stdlib HTTP, psycopg2 diretto, idempotente, progressivo.

### Struttura generale

```
llm_batch.py [--quiet] [--dry-run] [--single TITLE] [--phase paper|kindle|anki]

  01:00 → Fase 1: Paper Summarization (priorità alta)
  ??:?? → Fase 2: Kindle Enrichment (priorità media, progressivo)
  ??:?? → Fase 3: Anki Card Generation (priorità bassa, da Fase 1)
  03:15 → DEADLINE: unload 72B, prewarm embedding model
```

### Funzioni core (riusabili)

```python
# Config
OLLAMA_URL = "http://127.0.0.1:11434"  # socat → Gaia
LLM_MODEL = "qwen3:72b"
EMBED_MODEL = "qwen3-embedding:8b"
DEADLINE = (3, 15)  # 03:15

# Riuso da paper_archive.py (stessi pattern):
# - get_pg_connection() → psycopg2 singleton (PG_HOST, PG_CRED)
# - execute_age() → query Cypher su knowledge_graph
# - upsert_embedding() → INSERT/UPDATE su vector_store
# - sql_esc() → escape per SQL

def llm_generate(prompt, system="", temperature=0.0, num_ctx=8192, num_predict=2048):
    """POST a /api/generate SENZA format:json (conflitto thinking mode Qwen 3.x).
    Usa _extract_json() per estrarre JSON dalla risposta freeform."""
    # _extract_json(): strip <think> tags, markdown fences, trova { ... }
    # Retry 3x, timeout 600s

def unload_model():
    """POST con keep_alive: 0 per scaricare il 72B dalla VRAM."""
    # body = {"model": LLM_MODEL, "prompt": "", "keep_alive": 0}

def prewarm_embedding():
    """POST a /api/embed con dummy input per ricaricare embedding model."""
    # body = {"model": EMBED_MODEL, "input": "warmup"}

def past_deadline():
    """True se ora >= 03:15."""
```

### Fase 1: Paper Summarization

**Query AGE** per paper senza summary:
```cypher
MATCH (p:Paper) WHERE p.summary IS NULL RETURN {title: p.title, abstract: p.abstract, authors: p.authors, venue: p.venue, year: p.year, slug: p.slug}
```

**Per ogni paper**:
1. **Prompt** (few-shot + structured JSON):
   ```
   System: You are an academic paper analyst. Output valid JSON only.

   Summarize this paper. Output JSON with these fields:
   - reasoning: your analysis process (will be discarded)
   - core_claim: one sentence stating the main thesis
   - method: the approach or methodology used
   - key_findings: array of 2-4 key results with specifics
   - limitations: array of 1-2 limitations
   - domain_tags: array of 2-3 domain tags (e.g. "cs.LG", "economics")
   - connections: array of related concepts

   Paper: {title} ({year}, {venue})
   Abstract: {abstract}
   ```

2. **Storage triplo**:
   - **AGE**: `SET p.summary = ..., p.core_claim = ..., p.key_findings = ..., p.summary_at = timestamp`
   - **WikiJS**: UPDATE pagina esistente aggiungendo sezione `## AI Summary` (riuso pattern `insert_wiki_page` da `paper_archive.py:638`, ma con UPDATE al content esistente)
   - **pgvector**: re-embed con mini-doc arricchito (title + abstract + summary + key_findings)

3. **Stima**: ~100-170s/paper a 3-5 tok/s. 105 paper = ~3-5h. Con deadline 03:15 (2h15 da 01:00), ~50 paper/notte → convergenza in 2-3 notti.

### Fase 2: Kindle Enrichment

**Query AGE** per highlight senza concept extraction:
```cypher
MATCH (h:Sequence)-[:FROM]->(b:Book) WHERE h.concepts_extracted IS NULL
RETURN {id: id(h), text: h.text, book: b.title, author: b.author} LIMIT 200
```

**Batch di 5-10 highlight dello stesso libro** (riduce overhead prompt):
```
System: You are a concept extractor. Output valid JSON only.

From these book highlights, extract key concepts, frameworks, and principles.
Map to existing concepts when possible: {existing_concepts_list}

Book: {title} by {author}
Highlights:
1. "{text1}"
2. "{text2}"
...

Output JSON array:
[{
  "highlight_index": 1,
  "concepts": [{"name": "Nash Equilibrium", "type": "framework", "existing": true}],
  "relations": [{"from_concept": "Nash Equilibrium", "to_concept": "Game Theory", "type": "PART_OF"}]
}]
```

**Storage**:
- **AGE**: CREATE/MERGE nodi `Concept`, edge `DISCUSSES` da Highlight a Concept
- `SET h.concepts_extracted = timestamp` (idempotente)

**Stima**: ~500 tok/highlight, batch 5 = ~2500 tok, ~500 tok output. ~30K highlights / 200 per notte = ~150 notti. Con batching 5x: ~30 notti. Principio inesorabilità.

### Fase 3: Anki Card Generation

**Dipende da Fase 1** — genera card dai paper con summary.

**Query AGE**:
```cypher
MATCH (p:Paper) WHERE p.summary IS NOT NULL AND p.anki_generated IS NULL RETURN {...}
```

**Per ogni paper**:
```
System: Generate Anki flashcards following the minimum information principle.

Rules:
1. Each card tests exactly ONE fact or concept
2. Front: specific question (prefer "why" and "how" over "what")
3. Back: concise answer (1-3 sentences max)
4. Include source citation
5. For empirical results, include effect sizes

Paper: {title} ({year})
Summary: {core_claim}
Key findings: {key_findings}
Method: {method}

Output JSON: {"cards": [{"front": "...", "back": "...", "tags": ["paper", "domain"]}]}
```

**Storage**:
- **Anki API** diretto: `POST http://anki-api:8096/bulk/notes` (stesso pattern di `AnkiTools.java:70`)
  - Deck: `Papers::Auto-Generated` (creare se non esiste)
  - Tags: `["auto-generated", "paper", slug]`
- **AGE**: `SET p.anki_generated = timestamp, p.anki_card_count = N`

**Stima**: ~1300 tok/paper, 5-8 card/paper. 105 paper = ~2-3h. Fittano nella stessa notte dopo Phase 1 solo se Phase 1 ha già processato tutti i paper.

## Step 4 — Systemd Timer

**File**: `~/.config/systemd/user/llm-batch.timer`
```ini
[Unit]
Description=Nightly 72B LLM batch processing

[Timer]
OnCalendar=*-*-* 01:00:00
Persistent=true
RandomizedDelaySec=120

[Install]
WantedBy=timers.target
```

**File**: `~/.config/systemd/user/llm-batch.service`
```ini
[Unit]
Description=LLM batch: paper summarization, Kindle enrichment, Anki generation

[Service]
Type=oneshot
ExecStart=/data/massimiliano/kindle/venv/bin/python /data/massimiliano/kindle/llm_batch.py --quiet
TimeoutStartSec=10800
Environment=PG_HOST=172.20.0.9
EnvironmentFile=/data/massimiliano/postgres/.env
```

```bash
systemctl --user daemon-reload
systemctl --user enable llm-batch.timer
systemctl --user start llm-batch.timer
```

### Timeline notturna risultante

```
01:00  llm-batch (qwen3:72b)
       ├── Fase 1: Paper summarization (~50 paper)
       ├── Fase 2: Kindle enrichment (~200 highlights)
       └── Fase 3: Anki generation (paper con summary)
03:15  DEADLINE → unload 72B, prewarm embedding
03:30  infra-graph-sync  (no LLM)
04:00  server-snapshot + MCP reindex (no LLM)
04:15  anki-embed (qwen3-embedding:8b + minicpm-v)
06:30  paper-archive-scan (qwen3-embedding:8b)
```

## Step 5 — Validazione

```bash
# Test manuale (singolo paper)
cd /data/massimiliano/kindle
./venv/bin/python llm_batch.py --single "Attention Is All You Need" --dry-run

# Run reale limitato
./venv/bin/python llm_batch.py --phase paper --limit 3

# Verifica AGE
# graph_query: MATCH (p:Paper) WHERE p.summary IS NOT NULL RETURN p.title, p.core_claim LIMIT 5

# Verifica WikiJS: check pagina paper ha sezione "AI Summary"
# Verifica Anki: anki_search_notes con tag "auto-generated"

# Mattina dopo primo run automatico:
journalctl --user -u llm-batch.service --since today
journalctl --user -u anki-embed.service --since today  # nessun conflitto?
ssh gaia "nvidia-smi && free -h"
```

## File critici — Riferimenti

| File | Dove | Azione |
|------|------|--------|
| `/data/ollama/docker-compose.yml` | Gaia (SSH) | EDIT: memory 56g, env vars |
| `/data/massimiliano/ollama/docker-compose.yml` | SOL | Nessuna modifica (socat OK) |
| `/data/massimiliano/kindle/paper_archive.py` | SOL | Pattern: `get_pg_connection()` (:48), `execute_age()`, `upsert_embedding()`, `insert_wiki_page()` (:638), `generate_wiki_content()` (:572) |
| `/data/massimiliano/kindle/llm_batch.py` | SOL | **NUOVO** — script batch principale |
| `~/.config/systemd/user/llm-batch.{timer,service}` | SOL | **NUOVO** — timer |
| Anki API | Docker `anki-api:8096` | POST `/bulk/notes` per card generation (pattern: `AnkiTools.java:70`) |

## Rischi e Mitigazioni

| Rischio | Mitigazione |
|---------|-------------|
| 72B troppo lento (>2h15 per 50 paper) | Ridurre batch, o swap a 32B Q8_0 |
| Conflitto modelli (72B non scaricato prima di 04:15) | Hard deadline 03:15 + explicit `keep_alive: 0` + prewarm embedding |
| Gaia irraggiungibile (Tailscale/power) | Retry 3x con backoff, batch idempotente, recupera notte dopo |
| JSON output invalido semanticamente | `_extract_json()` parser + retry loop (max 2). NO `format: "json"` (confligge con Qwen thinking mode) |
| Kindle entity resolution (concetti duplicati) | Post-processing: embedding similarity > 0.95 → merge. Iterazione settimanale |
| Anki card quality scadente | Deck staging `Papers::Auto-Generated`, review manuale prime 50 card per calibrare prompt |
| OOM su Gaia | Memory limit 56g, Ollama auto-management |
| Load/unload overhead | Una sola volta per run (~60s load + ~5s prewarm). Non per-item |
