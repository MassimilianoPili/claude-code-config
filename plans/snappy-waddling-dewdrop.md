# Piano Esecuzione: Embedding Roadmap (3 Fronti)

## Context

Tre fronti di embedding indipendenti da portare a regime. Ricerca semantica completa su tutto il knowledge base.

## Stato avanzamento

| Step | Stato | Note |
|------|-------|------|
| Front 3: backfill NULL records | ✅ COMPLETATO | 0 NULL record — nightly reindex li ha già gestiti |
| Front 1: fix bug HTTP 400 | ✅ COMPLETATO | Resilienza errori, empty text guard, consecutive error abort |
| Front 1: refactor doppia OCR | ✅ COMPLETATO | `embed_anki.py` aggiornato: PIPELINE_VERSION=3, VISION_VERSION=2, dual OCR, batch 2000 |
| Pull qwen3-vl:32b su gaia | 📋 IN CODA | Task #11 — ~20GB download |
| Pull vllm/vllm-openai su gaia | 📋 IN CODA | Task #10 — ~8-10GB download |
| Docker Compose PaddleOCR-VL su gaia | ✅ COMPLETATO | `gaia:/data/paddleocr-vl/docker-compose.yml` scritto |
| Refactor embed_anki.py batch 2-fasi | ✅ COMPLETATO | Model name + 2-phase + stop/start helpers |
| KORE sync | ✅ COMPLETATO | DockerService paddleocr-vl + Task nodes + relazione COLOCATED_WITH |
| Test con qwen3.5:27b | 🔜 PROSSIMO | Modello già su gaia — test immediato senza attendere pull |
| Front 1: prima run manuale (produzione) | 📋 IN CODA | Blocca su download completati (qwen3-vl:32b + vLLM) |
| Front 2: Code Embedding tree-sitter | 📋 IN CODA | ~2 giorni di sviluppo |

---

## Setup PaddleOCR-VL 1.5 su gaia (PROSSIMO STEP)

### Problema: registry Baidu irraggiungibile

L'immagine ufficiale PaddlePaddle (`ccr-2vdh3abv-pub.cnc.bj.baidubce.com/...`) fallisce con TLS handshake timeout dall'Italia.
**Soluzione**: usare `vllm/vllm-openai` da Docker Hub + modello HuggingFace `PaddlePaddle/PaddleOCR-VL-1.5`.

### Opzione scelta: vllm/vllm-openai + HuggingFace model

**Image**: `vllm/vllm-openai:latest` (~8-10GB, Docker Hub — nessun problema registry)
**Model**: `PaddlePaddle/PaddleOCR-VL-1.5` (scaricato automaticamente da HF al primo start)
**API**: OpenAI-compatible `/v1/chat/completions`
**VRAM**: ~8-12GB (modello 0.9B + vLLM overhead), `gpu-memory-utilization=0.4` limita al 40% (~9.6GB)
**Porta**: 8000 su gaia (0.0.0.0, raggiungibile da SOL via Tailscale `100.109.3.40:8000`)

### Step 1: Docker Compose su gaia

Riscrivere `/data/paddleocr-vl/docker-compose.yml` su gaia (directory già creata, `chown massimiliano`):

```yaml
services:
  paddleocr-vl:
    image: vllm/vllm-openai:latest
    container_name: paddleocr-vl
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - HF_HOME=/data/huggingface
    ports:
      - "8000:8000"
    volumes:
      - hf-cache:/data/huggingface
    command:
      - --model
      - PaddlePaddle/PaddleOCR-VL-1.5
      - --host
      - "0.0.0.0"
      - --port
      - "8000"
      - --trust-remote-code
      - --max-num-batched-tokens
      - "16384"
      - --dtype
      - bfloat16
      - --gpu-memory-utilization
      - "0.4"
    restart: unless-stopped

volumes:
  hf-cache:
```

Note:
- `--trust-remote-code`: necessario — PaddleOCR-VL usa codice custom nel repo HF
- `--gpu-memory-utilization 0.4`: limita al 40% VRAM → ~9.6GB su 24GB
- `hf-cache` named volume: persiste i model weights tra restart (~2GB al primo download)
- `--dtype bfloat16`: precisione nativa del modello, supportata da RTX 3090

### Step 2: Pull image e start

```bash
SSH_AUTH_SOCK=/run/user/1000/ssh-agent.sock ssh gaia "cd /data/paddleocr-vl && docker compose pull && docker compose up -d"
```

Nota: SSH_AUTH_SOCK necessario perché il socket non è nel default env di Claude Code.

### Step 3: Verificare endpoint

```bash
curl -s http://100.109.3.40:8000/v1/models
```

Atteso: `PaddlePaddle/PaddleOCR-VL-1.5` nella lista modelli.

### Step 4: Test OCR con immagine reale

Usare una immagine Anki dal campione benchmark:
```bash
IMG=$(base64 -w0 /data/massimiliano/anki/media/<sample_image>)
curl -X POST http://100.109.3.40:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"PaddlePaddle/PaddleOCR-VL-1.5\",\"messages\":[{\"role\":\"user\",\"content\":[{\"type\":\"image_url\",\"image_url\":{\"url\":\"data:image/jpeg;base64,$IMG\"}},{\"type\":\"text\",\"text\":\"OCR:\"}]}],\"max_tokens\":2048,\"temperature\":0.1}"
```

### Step 5: Aggiornare embed_anki.py — model name

L'endpoint `http://100.109.3.40:8000/v1/chat/completions` è già configurato.
**PERÒ** il model name nel payload va allineato: vLLM usa il nome HuggingFace completo.

Modificare in `embed_anki.py` (riga ~54):
```python
# PRIMA (Baidu image)
PADDLEOCR_MODEL = "PaddleOCR-VL-1.5-0.9B"
# DOPO (vLLM + HuggingFace)
PADDLEOCR_MODEL = "PaddlePaddle/PaddleOCR-VL-1.5"
```

### Step 6: Gestione VRAM — orchestrazione sequenziale

**Problema**: PaddleOCR-VL (~9.6GB con 0.4 limit) + Qwen3-VL 32B Q4 (~21GB) = ~30GB > 24GB VRAM.
Non possono coesistere. Lo script attuale processa immagine per immagine chiamando entrambi i modelli → crash OOM.

**Soluzione**: refactor `process_vision_batch()` in due fasi separate.

Modificare `embed_anki.py`:

```python
def process_vision_batch(batch_size):
    to_process = [f for f in image_files if needs_processing(f)]
    batch = to_process[:batch_size]

    # FASE 1: PaddleOCR-VL su tutto il batch (container già running)
    if _check_paddleocr():
        log.info("Phase 1: PaddleOCR-VL on %d images", len(batch))
        for f in batch:
            entry = vision_cache.get(f, {})
            entry["secondary"] = _paddleocr_vision(f)
            vision_cache[f] = entry
        # Ferma PaddleOCR per liberare VRAM
        _stop_paddleocr()

    # FASE 2: Qwen3-VL su tutto il batch (Ollama carica il modello)
    log.info("Phase 2: Qwen3-VL on %d images", len(batch))
    for f in batch:
        entry = vision_cache.get(f, {})
        entry["primary"] = _ollama_vision(f)
        entry["text"] = _merge_vision_texts(entry)
        entry["version"] = VISION_VERSION
        vision_cache[f] = entry

    # Riavvia PaddleOCR per il prossimo batch
    _start_paddleocr()
    _save_vision_cache()
```

Funzioni helper (via SSH a gaia):
```python
def _stop_paddleocr():
    """Ferma container PaddleOCR-VL per liberare VRAM"""
    subprocess.run(["ssh", "gaia", "docker", "stop", "paddleocr-vl"],
                   capture_output=True, timeout=30)

def _start_paddleocr():
    """Riavvia container PaddleOCR-VL"""
    subprocess.run(["ssh", "gaia", "docker", "start", "paddleocr-vl"],
                   capture_output=True, timeout=60)
```

### Step 7: Rilancio pull qwen3-vl:32b

```bash
SSH_AUTH_SOCK=/run/user/1000/ssh-agent.sock ssh gaia "docker exec ollama ollama pull qwen3-vl:32b"
```

### File da modificare

| File | Modifiche |
|------|-----------|
| `gaia:/data/paddleocr-vl/docker-compose.yml` | Riscrivere con `vllm/vllm-openai` (via SSH) |
| `/data/massimiliano/anki/embed_anki.py` | 1) Model name → `PaddlePaddle/PaddleOCR-VL-1.5` |
| | 2) Refactor batch in 2 fasi (PaddleOCR → stop → Qwen3-VL → start) |
| | 3) Aggiungere `_stop_paddleocr()` / `_start_paddleocr()` |

### Verifica end-to-end

1. `curl http://100.109.3.40:8000/v1/models` → `PaddlePaddle/PaddleOCR-VL-1.5`
2. Test OCR singola immagine Anki → testo trascritto
3. `python embed_anki.py --vision-batch 5` → 5 immagini processate con doppia OCR
4. Verificare `vision_cache.json`: ogni entry ha `primary` + `secondary` + `text`
5. `ssh gaia "docker ps"` → paddleocr-vl running dopo il batch

---

## Front 2: Code Embedding — tree-sitter (SESSIONE 2)

(Invariato — ~2 giorni di sviluppo, target mcp-vector-tools v0.4.0)
Vedi piano precedente per dettagli Step 2.1-2.5.

### File critici
- `/data/massimiliano/Vari/mcp-vector-tools/pom.xml`
- `.../ingest/MarkdownParser.java` (pattern)
- `.../ingest/ChunkingService.java`
- `.../VectorTools.java`
- `.../VectorToolsAutoConfiguration.java`
