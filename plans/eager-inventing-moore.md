# Script `deploy-mirror`: mirror automatico Gitea → GitHub

## Contesto

Solo 1 dei 17 repo con remote `github` ha il workflow di mirror automatico. Gli altri richiedono `git push github` manuale. Serve uno script che deployi il workflow di mirror su tutti i repo, con una sola SSH key per l'auth.

## Componenti

### 1. SSH key unica per GitHub

- Generare una nuova coppia ed25519 (`gitea-mirror`)
- Aggiungere la public key all'account GitHub (Settings → SSH keys) — funziona per tutti i repo
- Rimuovere la deploy key per-repo aggiunta in precedenza su `mcp-server`
- Salvare la private key come secret `MIRROR_SSH_KEY` su ogni repo Gitea (via API)

### 2. Script `deploy-mirror` in `shell-scripts/bin/`

**Input**: nessun argomento (scopre automaticamente), oppure `--only repo1,repo2` / `--exclude repo1`

**Logica**:
1. Scansiona tutte le directory in `/data/massimiliano/Vari/` (e root `/data/massimiliano/`)
2. Per ogni dir con `.git/`, controlla se esiste remote `github`
3. Estrae `owner/repo` dall'URL GitHub (SSH o HTTPS)
4. Genera `.gitea/workflows/mirror.yml` con il target corretto
5. Opzionale: setta il secret `MIRROR_SSH_KEY` via Gitea API (flag `--setup-secrets`)
6. Commit e push su origin

**Template workflow** (inline nello script):
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
      - name: Push to GitHub
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.MIRROR_SSH_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
          GIT_SSH_COMMAND="ssh -i ~/.ssh/deploy_key -o StrictHostKeyChecking=no" \
            git push --force git@github.com:OWNER/REPO.git HEAD:main --tags
          rm -f ~/.ssh/deploy_key
```

`OWNER/REPO` viene sostituito dallo script per ogni repo.

**Flag**:
- `--dry-run`: mostra cosa farebbe senza scrivere
- `--setup-secrets`: crea il secret `MIRROR_SSH_KEY` su ogni repo Gitea (richiede token API e path alla private key)
- `--only repo1,repo2`: solo repo specificati
- `--exclude repo1,repo2`: escludi repo
- `--list`: elenca repo con remote github e stato mirror workflow

### 3. File coinvolti

| File | Azione |
|------|--------|
| `/data/massimiliano/shell-scripts/bin/deploy-mirror` | Nuovo script (modello: `deploy-mcp`) |
| `*/.gitea/workflows/mirror.yml` | Generato dallo script in ogni repo |

### 4. Cleanup

- Rimuovere deploy key `gitea-mirror` dal repo GitHub `MassimilianoPili/mcp-server` (sostituita dalla SSH key account)

## Verifica

1. `deploy-mirror --list` — mostra tutti i repo e lo stato
2. `deploy-mirror --dry-run` — verifica output senza scrivere
3. `deploy-mirror` — deploy effettivo
4. `deploy-mirror --setup-secrets --key /path/to/key --token <gitea-token>` — setta i secret
5. Push di test su un repo → verificare che il workflow parta e GitHub si aggiorni
