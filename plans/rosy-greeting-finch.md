# Piano: Setup Server LLM (Dual-Boot Linux/Windows)

## Context

Server dedicato per LLM inference locale, separato da SOL. Scopo: servire modelli Ollama (Qwen3-Embedding-8B, Qwen3-Reranker-4B, Qwen3.5-27B) come backend puro per il piano GPU Coprocessor (`PIANO_GPU_COPROCESSOR.md`).

**Dual-boot**: Linux (default) per LLM serving 24/7, Windows per gaming on-demand.
SOL consuma Ollama via Tailscale — il server GPU non ha servizi propri oltre Ollama.

**Hardware disponibile:**
- CPU: AMD Ryzen 7 3700X (8c/16t, 65W, AM4)
- GPU: EVGA RTX 3090 (24GB GDDR6X, 350W TDP)
- Mobo: MSI B450 (PCIe 3.0 x16 — inference OK, bus non è collo di bottiglia)
- PSU: SilentStorm 750W 80+ Gold (sufficiente: 350W GPU + 65W CPU + ~50W sistema = ~465W nominale)
- RAM: 64GB DDR4
- Storage: da definire (NVMe consigliato per model swap ~3-5s)

**Relazione con GPU Coprocessor**: questo piano copre solo il setup fisico del server. Il piano software (mcp-ollama-tools, code embedding, hybrid retrieval, entity extraction) resta in `PIANO_GPU_COPROCESSOR.md` e nel plan dettagliato precedente.

---

## Architettura

```
[Server GPU (LAN/Tailscale)]          [Server SOL]
  Ubuntu 24.04 LTS                      simoge-mcp (:8099)
  NVIDIA 535+ driver                    pgvector + AGE + Neo4j
  Docker + nvidia-container-toolkit     tree-sitter (CPU, JNI)
  Ollama container + 3090              ScheduledReindex (batch 04:00)
  OLLAMA_HOST=0.0.0.0:11434            nginx (serve tutto)
  Tailscale: gpu-server
            ←── Tailscale VPN ──→
  [Windows 11 — partizione gaming]
```

SOL chiama `http://gpu-server:11434/api/*` — nessun altro servizio esposto dal server GPU.

---

## Fase 1: Partitioning e Dual-Boot

### Schema partizioni (GPT/UEFI)

| # | Size | Tipo | Mount | Uso |
|---|------|------|-------|-----|
| 1 | 512MB | EFI System | `/boot/efi` | Bootloader condiviso (GRUB + Windows Boot Manager) |
| 2 | 200GB | NTFS | — | Windows 11 (gaming) |
| 3 | 1GB | ext4 | `/boot` | Kernel + initramfs Linux |
| 4 | Resto | ext4 | `/` | Ubuntu 24.04 root (include `/var/lib/docker` per modelli Ollama) |

> **Nota storage**: i modelli Ollama occupano ~50-60GB (3 modelli). NVMe fortemente consigliato — model swap ~3-5s vs ~15-20s su SATA SSD.

### Ordine installazione

1. **Windows 11 prima** — installa sulla partizione 2 (200GB). Windows crea la EFI partition automaticamente.
2. **Ubuntu 24.04 LTS dopo** — installa con partitioning manuale. GRUB sovrascrive il bootloader EFI e aggiunge Windows come entry.
3. **GRUB default: Ubuntu** — `GRUB_DEFAULT=0`, `GRUB_TIMEOUT=5` in `/etc/default/grub`. Linux parte automaticamente al boot (server headless di default).

### BIOS/UEFI settings (MSI B450)

- Secure Boot: **disabilitato** (requisito per driver NVIDIA proprietari)
- CSM: **disabilitato** (UEFI puro per GPT)
- Boot order: NVMe/SSD con GRUB primo
- PCIe: Gen 3.0 auto (B450 non supporta Gen 4)
- Wake-on-LAN: **abilitato** (per accensione remota da SOL, opzionale)

---

## Fase 2: Ubuntu 24.04 LTS — Setup base

### Perché Ubuntu 24.04

Dalla ricerca: consenso industriale schiacciante.
- **NVIDIA**: driver e container toolkit ufficialmente testati su Ubuntu 20.04/22.04/24.04
- **Ollama**: immagine Docker basata su Ubuntu, documentazione primaria su Ubuntu
- **GPU cloud** (Lambda Labs, CoreWeave, RunPod, Vast.ai): tutti Ubuntu-based
- **vLLM, TGI**: Docker image Ubuntu, CI/CD testata su Ubuntu
- Kernel 6.8 LTS stabile — kernel bleeding-edge (Fedora) ha causato regressioni driver NVIDIA
- Stessa distro di SOL → pattern identici, familiarità

### Installazione minimale

```bash
# Ubuntu Server 24.04 LTS (no desktop — server headless)
# Opzione: Ubuntu Desktop se si vuole usare occasionalmente con monitor
# Consigliato: Server + ssh, desktop installabile dopo se serve

# Post-install essenziali
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
  openssh-server \
  curl wget git htop tmux \
  build-essential \
  linux-headers-$(uname -r)
```

### Utente e SSH

```bash
# Utente: massimiliano (stesso di SOL per semplicità)
# SSH key: copiare da SOL o generare nuova e aggiungere a authorized_keys
ssh-copy-id massimiliano@gpu-server  # da SOL

# Disabilitare password auth (solo key)
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

---

## Fase 3: NVIDIA Driver + Container Toolkit

### Driver NVIDIA

```bash
# Metodo consigliato: ubuntu-drivers (repository ufficiale Ubuntu)
sudo ubuntu-drivers install

# Oppure versione specifica (535+ per RTX 3090, 550+ consigliato)
sudo apt install -y nvidia-driver-550

# Reboot richiesto
sudo reboot

# Verifica
nvidia-smi
# Atteso: RTX 3090, 24576 MiB, driver 550.x, CUDA 12.x
```

### Docker Engine

```bash
# Docker CE (non snap)
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker massimiliano
newgrp docker

# Verifica
docker run hello-world
```

### nvidia-container-toolkit

```bash
# Repository NVIDIA
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt update
sudo apt install -y nvidia-container-toolkit

# Configurare Docker runtime
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Verifica GPU nel container
docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu24.04 nvidia-smi
```

---

## Fase 4: Tailscale

```bash
# Installazione
curl -fsSL https://tailscale.com/install.sh | sh

# Login (stessa tailnet di SOL)
sudo tailscale up --hostname=gpu-server

# Verifica connettività da SOL
# Da SOL: tailscale ping gpu-server
# Da SOL: curl http://gpu-server:11434/api/tags  (dopo Fase 5)
```

### Tailscale ACL (opzionale, da admin console)

Restringere accesso a Ollama: solo SOL e dispositivi autorizzati possono raggiungere `gpu-server:11434`.

```json
{
  "acls": [
    {"action": "accept", "src": ["sol"], "dst": ["gpu-server:11434"]}
  ]
}
```

---

## Fase 5: Ollama + GPU

### Docker Compose

File: `/home/massimiliano/ollama/docker-compose.yml`

```yaml
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    ports:
      - "11434:11434"
    environment:
      - OLLAMA_HOST=0.0.0.0:11434
      - OLLAMA_MODELS=/root/.ollama/models
      - OLLAMA_MAX_LOADED_MODELS=1
      - OLLAMA_NUM_PARALLEL=4
    volumes:
      - ./data:/root/.ollama
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    mem_limit: 20g
    healthcheck:
      test: ["CMD", "ollama", "list"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### Download modelli

```bash
cd /home/massimiliano/ollama
docker compose up -d

# Modelli in ordine di priorità
docker exec ollama ollama pull qwen3-embedding:8b      # ~16GB VRAM, embedding
docker exec ollama ollama pull qwen3-reranker:4b       # ~8GB VRAM, reranking
docker exec ollama ollama pull qwen3.5:27b-q5_K_M      # ~21GB VRAM, extraction

# Verifica
docker exec ollama ollama list
```

### VRAM Planning

| Modello | VRAM | Uso | Coesistenza |
|---------|------|-----|-------------|
| Qwen3-Embedding-8B FP16 | ~16GB | Embedding batch | Solo |
| Qwen3-Reranker-4B | ~8GB | Reranking query-time | Solo (o con embedding se <24GB totale) |
| Qwen3.5-27B Q5_K_M | ~21GB | Entity extraction | Solo |

Ollama swappa automaticamente (~3-5s su NVMe). La pipeline batch notturna li carica in sequenza.

---

## Fase 6: Avvio automatico e resilienza

### Ollama auto-start al boot

```bash
# Docker + compose auto-start
sudo systemctl enable docker

# Ollama container: restart: unless-stopped (già in compose)
# Al boot Linux → Docker parte → Ollama parte → GPU allocata
```

### Systemd service per auto-compose-up (opzionale)

```ini
# /etc/systemd/system/ollama-compose.service
[Unit]
Description=Ollama Docker Compose
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/massimiliano/ollama
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=massimiliano

[Install]
WantedBy=multi-user.target
```

### Monitoring da SOL

SOL può verificare lo stato del server GPU:
```bash
# Health check periodico (da aggiungere a SOL monitoring)
curl -s http://gpu-server:11434/api/tags | jq '.models | length'
# Ritorna il numero di modelli disponibili
```

---

## Fase 7: Windows 11 (Partizione Gaming)

### Setup minimale

- Installato in Fase 1 (prima di Ubuntu)
- Driver NVIDIA: GeForce Game Ready (dal sito NVIDIA o GeForce Experience)
- GRUB entry automatica: `os-prober` la rileva durante `update-grub`

### Switch Linux → Windows

```bash
# Da SSH su gpu-server (richiede sudo)
sudo grub-reboot "Windows Boot Manager" && sudo reboot

# Oppure: impostare next boot da BIOS (F11 al boot su MSI B450)
```

### Switch Windows → Linux

- Riavvio normale da Windows → GRUB parte → timeout 5s → Linux (default)
- Oppure: selezionare Ubuntu dal menu GRUB

### Nota: Windows e GPU driver

Entrambi gli OS hanno i propri driver NVIDIA. Non interferiscono — ogni OS carica il proprio.
Quando si gioca su Windows, Ollama non è raggiungibile (ovviamente). SOL gestisce il fallback nel piano software (timeout → retry → usa embedding CPU locale come fallback).

---

## Fase 8: Integrazione con SOL

### Config SOL (quando si implementa il piano GPU Coprocessor)

```bash
# In docker-compose.yml di simoge-mcp su SOL:
MCP_OLLAMA_BASE_URL=http://gpu-server:11434
MCP_VECTOR_OLLAMA_BASE_URL=http://gpu-server:11434
```

### Test end-to-end

```bash
# Da SOL:
# 1. Ping Tailscale
tailscale ping gpu-server

# 2. Lista modelli
curl -s http://gpu-server:11434/api/tags | jq '.models[].name'

# 3. Test inference
curl -s http://gpu-server:11434/api/generate -d '{
  "model": "qwen3-embedding:8b",
  "prompt": "Hello world",
  "stream": false
}' | jq '.response'

# 4. Test embedding
curl -s http://gpu-server:11434/api/embed -d '{
  "model": "qwen3-embedding:8b",
  "input": "test embedding"
}' | jq '.embeddings[0][:5]'
```

---

## Nota PSU: SilentStorm 750W e RTX 3090

La 3090 ha transient power spike fino a ~450W (EVGA FTW3 fino a ~500W).
Budget: GPU 350W + CPU 65W + sistema 50W = ~465W nominale, ~550W picco.
750W Gold è sufficiente ma senza margine abbondante.

**Se si verificano crash/riavvii sotto carico GPU pesante:**
1. Sottovoltare la 3090 in Linux: `nvidia-smi -pl 300` (power limit 300W, ~5% perf loss)
2. In Windows: MSI Afterburner per undervolt

---

## Checklist di verifica

- [ ] Windows 11 installato e funzionante sulla partizione dedicata
- [ ] Ubuntu 24.04 LTS installato, GRUB come bootloader default
- [ ] GRUB: Ubuntu default, timeout 5s, Windows rilevato
- [ ] SSH accessibile da SOL (key-based)
- [ ] `nvidia-smi` mostra RTX 3090 con driver 550+
- [ ] Docker installato, `docker run --gpus all nvidia/cuda:... nvidia-smi` funziona
- [ ] Tailscale attivo, `tailscale ping gpu-server` da SOL OK
- [ ] Ollama container running, `ollama list` mostra modelli
- [ ] Da SOL: `curl http://gpu-server:11434/api/tags` ritorna lista modelli
- [ ] Da SOL: test embedding funziona
- [ ] Auto-start: dopo reboot Linux, Ollama riparte automaticamente
- [ ] Switch Windows → Linux → Ollama riparte senza intervento

---

## Effort stimato

| Fase | Tempo |
|------|-------|
| 1. Partitioning + dual-boot | ~1.5h |
| 2. Ubuntu setup base | ~30min |
| 3. NVIDIA driver + container toolkit | ~30min |
| 4. Tailscale | ~10min |
| 5. Ollama + modelli | ~30min (+ tempo download modelli) |
| 6. Auto-start + monitoring | ~15min |
| 7. Windows driver | ~20min |
| 8. Test integrazione SOL | ~15min |
| **Totale** | **~4h** (escluso download modelli ~1h con buona connessione) |

---

## Riferimenti

- **Piano software (GPU Coprocessor)**: `/data/massimiliano/progetti_futuri/PIANO_GPU_COPROCESSOR.md`
- **Piano dettagliato (Fasi 1-6 software)**: conversazione precedente, salvato in memoria progetto
- **Report ricerca distro Linux**: `rosy-greeting-finch-agent-a9286fdaeb76d940c.md`
- **Report ricerca GPU Coprocessor** (3): `rosy-greeting-finch-agent-aa39372b8b4d0c923.md`, `rosy-greeting-finch-agent-a6124fc789b7a59e5.md`, `rosy-greeting-finch-agent-af25c66f1bcb1799b.md`
