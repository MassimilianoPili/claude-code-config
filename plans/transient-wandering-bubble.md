# Piano: Chiusura task #231 + KORE + task cleanup disco

## Context

Task #231 (verify-deploy-pipeline) completato. Risultati da documentare in KORE e task da accodare per prevenire il problema disco.

## Step

### 1. Completare task #231 con risultato
`claude_task_complete` con report sintetico dei 6 componenti verificati.

### 2. KORE: aggiornare nodi
- Aggiornare `sol_deploy_improvements_v2` con: MCP in NOSCALE, smoke test IP-targeted, diskSpace come root cause
- Creare nodo `github_mirror_ssh_key_rotation` (chiave rigenerata 2026-03-23)
- Creare nodo `docker_disk_full_incident_2026_03_23` (30GB build cache, /var 100%)

### 3. Accodare task cleanup disco periodico
`claude_task_enqueue`: timer/cron systemd per cleanup Docker completo:
- `docker builder prune -f` (build cache)
- `docker image prune -f` (immagini dangling)
- `docker container prune -f` (container stopped)
- `docker volume prune -f --filter "label!=keep"` (volumi orfani)
Soglia: eseguire quando `/var` supera 80%. Oppure periodico (settimanale).

### 4. Rimuovere MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS=always dal .env
Era per debug — va tolto (espone dettagli interni).
