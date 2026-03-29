# Retry qwen3-vl:32b Download on Gaia at 2 Mbit/s

## Context
`qwen3-vl:32b` (~20.9 GB) download on Gaia failed 3+ times due to WiFi instability (connection resets to Cloudflare R2). Previous throttle was 5 Mbit/s — still too aggressive. Now lowered to 2 Mbit/s (already applied: `tc tbf rate 2mbit burst 32kb lat 400ms` on `enp34s0`).

Partial files exist (2.6 GB actual on disk) — Ollama will resume from them.

## Steps

1. ~~Lower tc throttle to 2 Mbit/s~~ ✅ DONE

2. **Retry the pull** in background (survives SSH disconnect):
   ```bash
   ssh gaia "nohup docker exec ollama ollama pull qwen3-vl:32b > /home/massimiliano/pull-qwen3-vl.log 2>&1 &"
   ```
   At 2 Mbit/s (~250 KB/s), ~20.9 GB will take ~23 hours.

3. **Remove throttle** after completion:
   ```bash
   ssh gaia "sudo tc qdisc del dev enp34s0 root"
   ```

## Verification
- Progress: `ssh gaia "tail -f /home/massimiliano/pull-qwen3-vl.log"`
- Partial growth: `ssh gaia "du -sh /data/ollama/data/models/blobs/*partial"`
- Completed: `ssh gaia "docker exec ollama ollama list | grep qwen3-vl"`
