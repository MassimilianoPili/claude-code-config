# Piano: Riordino Docker + Zero-Downtime Deploy

## Contesto

Sessione precedente ha pubblicato 10 librerie MCP su Maven Central, rimosso workaround host-m2 dal Dockerfile, e preparato il docker-compose.yml per lo scale trick (rimosso `container_name`, aggiunto aliases + healthcheck). Il build pulito da Central compila con successo ma fallisce per disco pieno.

## Stato attuale

| Cosa | Stato | Azione |
|------|-------|--------|
| Maven Central (10 librerie) | OK tutte pubblicate | Nessuna |
| Dockerfile (no host-m2) | OK, build compila da Central | Nessuna |
| docker-compose.yml | OK (aliases, healthcheck, no container_name) | Fix healthcheck endpoint |
| Container MCP | UNHEALTHY (actuator → 503 DOWN) | Fix healthcheck + redeploy |
| Disco | 96% pieno (1.4GB libero, serve ~3GB) | Prune build cache |
| Pulizia automatica cache | Non esiste | Creare timer systemd |
| Gitea repos (8 nuove librerie) | NON CREATI | Creare + push |
| GitHub repos (8 nuove librerie) | NON CREATI | Creare via mirror workflow |
| `sol deploy` command | NON IMPLEMENTATO | Implementare in sol script |

## Ordine esecuzione

### Step 1: Disco — Prune build cache ✅ DONE
Docker build cache prunato (47GB → 8.4GB). Docker root è su HDD (`/data/docker`, 242GB liberi).

### Step 1b: Pulizia root SSD (27GB usati, 1.4GB liberi)
La root SSD (`/dev/mapper/vg_ssd-lv_root`, 30GB) è al 96%. Candidati pulizia:

| Cosa | Dimensione | Azione |
|------|-----------|--------|
| `/opt/android-sdk` | 5.6GB | `sudo rm -rf` (non serve su server) |
| `~/.m2/repository` | 6.3GB | `rm -rf ~/.m2/repository` (cache Maven, rigenerabile) |
| `~/.gradle/caches` | 1.4GB | `rm -rf ~/.gradle/caches` (rigenerabile) |
| `~/.npm/_cacache` + `_npx` | 718MB | `rm -rf ~/.npm/_cacache ~/.npm/_npx` (rigenerabile) |
| `~/.cache/huggingface` | 465MB | `rm -rf` (scaricabile di nuovo) |
| `/opt/az` | 641MB | `sudo rm -rf` (Azure CLI, PAT revocato) |
| `/opt/google` | 389MB | `sudo rm -rf` se non serve |

**Approccio: spostare su `/data` (HDD) + symlink** — nulla viene cancellato.

```bash
# Destinazione su HDD
sudo mkdir -p /data/cache

# 1. Android SDK (5.6GB)
sudo mv /opt/android-sdk /data/cache/android-sdk
sudo ln -s /data/cache/android-sdk /opt/android-sdk

# 2. Maven cache (6.3GB)
mv ~/.m2/repository /data/cache/m2-repository
ln -s /data/cache/m2-repository ~/.m2/repository

# 3. Gradle cache (1.4GB)
mv ~/.gradle/caches /data/cache/gradle-caches
ln -s /data/cache/gradle-caches ~/.gradle/caches

# 4. npm cache (718MB)
mv ~/.npm/_cacache /data/cache/npm-cacache
ln -s /data/cache/npm-cacache ~/.npm/_cacache
mv ~/.npm/_npx /data/cache/npm-npx
ln -s /data/cache/npm-npx ~/.npm/_npx

# 5. Huggingface cache (465MB)
mv ~/.cache/huggingface /data/cache/huggingface
ln -s /data/cache/huggingface ~/.cache/huggingface
```

**Totale liberato su root SSD**: ~15GB (da 96% → ~45%)
Cloud SDK (az, google) mantenuti in root.

### Step 2: Docker cleanup automatico — Timer systemd (giornaliero)
Creare `docker-cleanup.service` + `docker-cleanup.timer` (user-level, giornaliero alle 04:30):
```bash
# ~/.config/systemd/user/docker-cleanup.service
[Unit]
Description=Docker build cache and image cleanup

[Service]
Type=oneshot
ExecStart=/usr/bin/docker builder prune --keep-storage=5GB -f
ExecStart=/usr/bin/docker image prune -f
```
```bash
# ~/.config/systemd/user/docker-cleanup.timer
[Unit]
Description=Daily Docker cleanup

[Timer]
OnCalendar=*-*-* 04:30:00
Persistent=true

[Install]
WantedBy=timers.target
```
Nota: 04:30 per non sovrapporsi con restic backup (03:00) e infra-graph-sync (03:30).

### Step 3: Fix healthcheck MCP server
Problema: `/actuator/health` risponde 503 `{"status":"DOWN"}` — un health indicator downstream segna DOWN.
Fix: usare `/actuator/health/liveness` (Kubernetes liveness probe, ignora downstream) oppure investigare quale componente è DOWN.
File: `/data/massimiliano/Vari/mcp/docker-compose.yml` riga 19 — cambiare endpoint se necessario.

### Step 4: Redeploy MCP server (build pulito da Central)
```bash
cd /data/massimiliano/Vari/mcp
docker compose build        # Build con nuovo spazio
docker compose up -d        # Sostituisce container unhealthy
```

### Step 5: Creare 8 repo Gitea + push
Per ognuna delle 8 librerie (`mcp-code-tools`, `mcp-csv-tools`, `mcp-http-tools`, `mcp-json-tools`, `mcp-keycloak-tools`, `mcp-markdown-tools`, `mcp-pdf-tools`, `mcp-ssh-tools`):
1. Creare repo su Gitea via API (MCP tool `gitea_create_repo` o curl)
2. `git remote add origin ssh://git@gitea-local:222/sol_root/<lib>.git`
3. `git push -u origin main --tags`
I workflow CI/CD (release.yml + mirror.yml) sono già nei repo locali.

### Step 6: Fix mirror.yml — auto-create GitHub repos
Il workflow `mirror.yml` attuale fa `git push` verso repo GitHub che non esistono → fallisce.
Fix: aggiungere uno step che crea il repo via GitHub API se non esiste.

**Prerequisito**: aggiungere secret `GITHUB_TOKEN` a tutti i repo Gitea (via MCP `gitea_set_secret`).
Token: da `~/.config/gh/hosts.yml` (già configurato per `gh` CLI).

**Nuovo mirror.yml** (template per tutte le librerie):
```yaml
name: Mirror to GitHub
on:
  push:
    branches: [main]
    tags: ["v*"]
jobs:
  mirror:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Ensure GitHub repo exists
        run: |
          REPO_NAME="${GITHUB_REPOSITORY##*/}"
          STATUS=$(curl -sf -o /dev/null -w "%{http_code}" \
            -H "Authorization: token ${{ secrets.GITHUB_TOKEN }}" \
            "https://api.github.com/repos/MassimilianoPili/$REPO_NAME")
          if [ "$STATUS" != "200" ]; then
            curl -sf -X POST \
              -H "Authorization: token ${{ secrets.GITHUB_TOKEN }}" \
              -H "Content-Type: application/json" \
              "https://api.github.com/user/repos" \
              -d "{\"name\":\"$REPO_NAME\",\"description\":\"Spring AI MCP tool library\",\"private\":false}"
            echo "Created GitHub repo: $REPO_NAME"
          fi
      - name: Push to GitHub
        run: |
          REPO_NAME="${GITHUB_REPOSITORY##*/}"
          mkdir -p ~/.ssh
          echo "${{ secrets.MIRROR_SSH_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
          GIT_SSH_COMMAND="ssh -i ~/.ssh/deploy_key -o StrictHostKeyChecking=no" \
            git push --force git@github.com:MassimilianoPili/$REPO_NAME.git HEAD:main --tags
          rm -f ~/.ssh/deploy_key
```

**Vantaggi**: (1) usa `$GITHUB_REPOSITORY` → nessun hardcoding del nome, (2) auto-crea il repo, (3) `--force` per sicurezza.

**File da modificare**: 8 file `mirror.yml` nelle nuove librerie + aggiornare le 12 esistenti per consistenza.
**Azione**: `gitea_set_secret` per ogni repo con `GITHUB_TOKEN`.

### Step 7: `sol deploy` command
Aggiungere a `/data/massimiliano/shell-scripts/bin/sol`:

#### 7a. Registro servizi completo
Aggiungere a `SERVICE_DIR`:
```bash
[mcp]="/data/massimiliano/Vari/mcp"
[mcp-proxy]="/data/massimiliano/Vari/mcp-proxy"
[monitoring]="/data/massimiliano/monitoring"
[wikijs]="/data/massimiliano/wikijs"
[mongodb]="/data/massimiliano/mongodb"
[minio]="/data/massimiliano/minio"
[jenkins]="/data/massimiliano/jenkins"
[tor]="/data/massimiliano/tor"
[knowledge-graph]="/data/massimiliano/knowledge-graph"
[embedding-viz]="/data/massimiliano/embedding-viz"
[ollama]="/data/massimiliano/ollama"
[code-server]="/data/massimiliano/code-server"
[artemis]="/data/massimiliano/artemis"
[libsql]="/data/massimiliano/libsql"
[wg-manager]="/data/massimiliano/Vari/wg-manager"
[searxng]="/data/massimiliano/searxng"
[mkdocs]="/data/massimiliano/mkdocs"
[preference-sort]="/data/massimiliano/Vari/preference-sort"
```

#### 7b. Alias, NGINX_DEPS, COMPOSE_SERVICE map
```bash
[simoge]="mcp"  [wiki]="wikijs"  [mongo]="mongodb"
[grafana]="monitoring"  [kg]="knowledge-graph"  [wg]="wg-manager"  [searx]="searxng"
```
NGINX_DEPS: + `mcp-proxy wikijs knowledge-graph embedding-viz minio jenkins code-server mkdocs searxng`
COMPOSE_SERVICE: `[mcp]="simoge-mcp"` (gli altri coincidono)

#### 7c. Scale trick `deploy_service()`

**Completare registro servizi** — aggiungere a `SERVICE_DIR`:
```bash
[mcp]="/data/massimiliano/Vari/mcp"
[mcp-proxy]="/data/massimiliano/Vari/mcp-proxy"
[monitoring]="/data/massimiliano/monitoring"
[wikijs]="/data/massimiliano/wikijs"
[mongodb]="/data/massimiliano/mongodb"
[minio]="/data/massimiliano/minio"
[jenkins]="/data/massimiliano/jenkins"
[tor]="/data/massimiliano/tor"
[knowledge-graph]="/data/massimiliano/knowledge-graph"
[embedding-viz]="/data/massimiliano/embedding-viz"
[ollama]="/data/massimiliano/ollama"
[code-server]="/data/massimiliano/code-server"
[artemis]="/data/massimiliano/artemis"
[libsql]="/data/massimiliano/libsql"
[wg-manager]="/data/massimiliano/Vari/wg-manager"
[searxng]="/data/massimiliano/searxng"
[mkdocs]="/data/massimiliano/mkdocs"
[preference-sort]="/data/massimiliano/Vari/preference-sort"
```

**Alias aggiuntivi**:
```bash
[simoge]="mcp"  [wiki]="wikijs"  [mongo]="mongodb"
[grafana]="monitoring"  [kg]="knowledge-graph"  [wg]="wg-manager"  [searx]="searxng"
```

**NGINX_DEPS aggiuntivi**: `mcp-proxy wikijs knowledge-graph embedding-viz minio jenkins code-server mkdocs searxng`

**Mappa servizio → nome servizio Compose** (necessaria perché senza container_name il nome servizio nel yml è la chiave):
```bash
declare -A COMPOSE_SERVICE=(
  [mcp]="simoge-mcp"
  # altri servizi: il nome sol coincide col nome compose service
)
```

**Nuove funzioni**:

- `has_build_directive()` — grep `build:` nel docker-compose.yml
- `get_compose_service()` — mappa nome sol → nome servizio nel compose file
- `get_image_name()` — estrae `image:` da docker-compose.yml
- `get_image_id()` — `docker images -q <image>` per confronto pre/post pull
- `can_scale()` — verifica assenza `container_name` nel compose (prerequisito scale)
- `tag_for_rollback()` — `docker tag <image>:latest <image>:prev`
- `wait_healthy()` — poll `docker inspect --format='{{.State.Health.Status}}'` per ogni container del servizio, timeout configurabile (default 60s)
- `deploy_service()` — orchestratore principale:

```bash
deploy_service() {
  local svc=$1 dir="${SERVICE_DIR[$svc]}" cs=$(get_compose_service "$svc")

  # 1. Build o Pull
  if has_build_directive "$dir"; then
    echo -ne "  ${CYAN}Building${NC} $svc..."
    docker compose -f "$dir/docker-compose.yml" build "$cs"
  else
    local old_id=$(docker images -q "$(get_image_name "$dir" "$cs")")
    docker compose -f "$dir/docker-compose.yml" pull "$cs"
    local new_id=$(docker images -q "$(get_image_name "$dir" "$cs")")
    if [[ "$old_id" == "$new_id" ]]; then
      echo -e "  ${GREEN}[SKIP]${NC} $svc (immagine invariata)"
      return 0
    fi
  fi

  # 2. Tag rollback
  tag_for_rollback "$dir" "$cs"

  # 3. Scale trick o swap semplice
  if can_scale "$dir" "$cs"; then
    # --- SCALE TRICK (zero-downtime) ---
    local old_cid=$(docker compose -f "$dir/docker-compose.yml" ps -q "$cs")

    # Scale a 2 (nuovo container con nuova immagine)
    docker compose -f "$dir/docker-compose.yml" up -d \
      --scale "$cs=2" --no-recreate "$cs"

    # Aspetta che il NUOVO container sia healthy
    local new_cid=$(docker compose -f "$dir/docker-compose.yml" ps -q "$cs" \
      | grep -v "$old_cid")
    if ! wait_healthy "$new_cid" 60; then
      echo -e "  ${RED}[FAIL]${NC} $svc (nuovo container non healthy, rollback)"
      docker stop "$new_cid" && docker rm "$new_cid"
      return 1
    fi

    # Kill vecchio container
    docker stop "$old_cid" && docker rm "$old_cid"

    # Normalizza scale a 1
    docker compose -f "$dir/docker-compose.yml" up -d \
      --scale "$cs=1" --no-recreate "$cs"

    echo -e "  ${GREEN}[ OK ]${NC} $svc (zero-downtime)"
  else
    # --- SWAP SEMPLICE (breve downtime) ---
    docker compose -f "$dir/docker-compose.yml" up -d --force-recreate "$cs"
    wait_healthy_compose "$dir" "$cs" 60
    echo -e "  ${GREEN}[ OK ]${NC} $svc (swap)"
  fi

  # 4. Nginx refresh se upstream
  is_nginx_dep "$svc" && restart_service proxy

  # 5. Infra graph sync (async)
  python3 /data/massimiliano/kindle/import_infrastructure.py \
    --service "$svc" --quiet 2>/dev/null &
}
```

- `cmd_deploy()` — `sol deploy <servizio|all>`
- `cmd_rollback()` — `sol rollback <servizio>`: verifica `:prev`, re-tag, recreate

**Aggiornare**: `cmd_help()`, `BOOT_ORDER`, case principale per `deploy` e `rollback`

mcp-proxy NON va toccato. `BACKEND_URL=http://simoge-mcp:8099` funziona grazie all'alias DNS.

#### 7d. `cmd_rollback()`
1. `docker image inspect <image>:prev` → verifica esistenza
2. `docker tag <image>:prev <image>:latest`
3. `docker compose up -d --force-recreate`
4. `wait_healthy`

## Verifica end-to-end

1. `df -h /` — disco libero > 5GB dopo prune
2. `systemctl --user status docker-cleanup.timer` — timer attivo
3. `docker inspect <mcp-container> --format='{{.State.Health.Status}}'` → healthy
4. MCP tool call funzionante (e.g. `gitea_list_repos`)
5. 8 repo su Gitea: `curl http://gitea:3000/api/v1/repos/search?q=mcp-`
6. 8 repo su GitHub: `curl https://api.github.com/users/MassimilianoPili/repos`
7. `sol deploy mcp` → scale trick completo, zero dropped requests
8. `sol rollback mcp` → rollback funzionante
