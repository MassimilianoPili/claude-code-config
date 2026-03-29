# Piano: Rilancio download qwen3-vl:32b su Gaia con throttling

## Context

Il download di `qwen3-vl:32b` (~20 GB) su Gaia è fallito più volte.
Causa: connection reset verso Cloudflare R2 + DNS Docker (`127.0.0.11` → `server misbehaving`) sotto carico a full speed.
Il modello `qwen3:72b` non è più a catalogo Ollama → lo scartiamo.

Rete: gaia (`10.0.0.2`, `enp34s0`) → SOL (`10.0.0.1`, `enp2s0`, gateway/NAT) → internet.
I file partial (~902 MB) **NON vanno cancellati** — ollama li usa per il resume.

## Cosa fare

### Step 1 — Applicare throttle a 5 Mbit/s su `enp34s0` di Gaia
```bash
ssh gaia 'sudo tc qdisc add dev enp34s0 root tbf rate 5mbit burst 32kbit latency 400ms'
```
Nota: mettere tc su SOL (`enp2s0`) è più complesso perché ha root qdisc `mq`.
Su gaia è semplice perché ha solo ollama come traffico significativo.

### Step 2 — Lanciare il pull in nohup
```bash
ssh gaia 'nohup sudo docker exec ollama ollama pull qwen3-vl:32b > /home/massimiliano/pull-qwen3-vl.log 2>&1 &'
```
A 5 Mbit/s, ~20 GB impiegherà circa 9 ore. Ollama riprenderà dai partial esistenti.

### Step 3 — Rimuovere throttle dopo completamento
```bash
ssh gaia 'sudo tc qdisc del dev enp34s0 root'
```

## Verifica
- Progresso: `ssh gaia 'tail -f /home/massimiliano/pull-qwen3-vl.log'`
- Modello scaricato: `ssh gaia 'sudo docker exec ollama ollama list'`
- Spazio disco: `ssh gaia 'df -h /data'`
