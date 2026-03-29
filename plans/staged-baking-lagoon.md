# Piano: Pull modelli AI su Gaia (diretto)

## Context

Gaia è tornata online (up 1 min). Ha **736 GB liberi** su `/data` (NVMe 1.8T, LVM).
Ollama salva su `/data/ollama/data` → spazio più che sufficiente.
**Non serve staging su SOL** — pull diretto su Gaia via SSH.

## Stato attuale Gaia

- Modelli presenti: qwen3.5:27b (17G), qwen3:4b (2.5G), qwen3-embedding:8b (4.7G), minicpm-v (5.5G), nomic-embed-text (274M)
- Docker: solo container `ollama` attivo
- GPU: RTX 3090 (24GB VRAM), 64GB RAM

## Cosa scaricare

| # | Modello | Tipo | Size stimata |
|---|---------|------|-------------|
| #46 | `qwen3:72b` | Ollama pull | ~42 GB |
| #11 | `qwen3-vl:32b` | Ollama pull | ~20 GB |
| #10 | `vllm/vllm-openai:latest` | Docker pull | ~15 GB |

**Totale**: ~77 GB → `/data` avrà ancora ~660 GB liberi.

## Step 1 — Pull modelli Ollama (in background via SSH)

```bash
# #46 — qwen3:72b (~42 GB, il più grosso → primo)
ssh gaia "nohup docker exec ollama ollama pull qwen3:72b > /tmp/pull-qwen3-72b.log 2>&1 &"

# #11 — qwen3-vl:32b (~20 GB, dopo il primo)
ssh gaia "nohup docker exec ollama ollama pull qwen3-vl:32b > /tmp/pull-qwen3-vl.log 2>&1 &"
```

I pull possono andare in parallelo (banda diversa da registry).

## Step 2 — Pull Docker image vllm

```bash
ssh gaia "nohup docker pull vllm/vllm-openai:latest > /tmp/pull-vllm.log 2>&1 &"
```

## Step 3 — Verifica

```bash
ssh gaia "docker exec ollama ollama list"
ssh gaia "docker images | grep vllm"
ssh gaia "df -h /data"
```

## Step 4 — Aggiornare task queue

Task #46, #10, #11 → COMPLETED via `claude_task_complete`.

## Rischi

- Gaia appena riavviata — se Tailscale cade di nuovo, i pull con `nohup` continueranno comunque (girano dentro Docker, non dipendono dalla sessione SSH).
- `qwen3:72b` (72B params, ~42GB) non sta tutto in VRAM (24GB). Servirà CPU offload (~3-5 tok/s). Questo è atteso — benchmark nel task #48.
