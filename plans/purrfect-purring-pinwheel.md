# Push preference-sort su Gitea

## Contesto

Il progetto `/data/massimiliano/Vari/preference-sort/` è completamente implementato e deployato, ma non è ancora sotto version control. Va inizializzato come repo git e pushato su Gitea, seguendo il pattern degli altri progetti Go (`jwt-gateway`, `server-api`).

## Stato attuale

- **Directory**: `/data/massimiliano/Vari/preference-sort/`
- **Git**: NON inizializzato (nessun `.git/`, nessun `.gitignore`)
- **File sensibile**: `.env` contiene `PREFSORT_DB_PASSWD` — va escluso
- **Pattern Gitea**: `ssh://git@100.86.46.84:222/sol_root/<repo>.git`

## Piano

### 1. Creare `.gitignore`

```
.env
preference-sort
```

(Esclude il file con credenziali e l'eventuale binario compilato)

### 2. Creare repository su Gitea

```bash
ssh -p 222 git@100.86.46.84 # NON funziona per creare repo
```

Usare l'API Gitea via curl o `tea` CLI. Pattern piu' semplice:

```bash
curl -s -X POST "http://100.86.46.84/git/api/v1/user/repos" \
  -H "Authorization: token <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"name":"preference-sort","description":"Pairwise comparison ranking API (Bradley-Terry)","private":true}'
```

Oppure creare manualmente via UI Gitea, poi push.

**Alternativa piu' semplice**: `git push` a un repo inesistente con Gitea che ha `DEFAULT_ALLOW_CREATE_ON_PUSH=true` (da verificare, potrebbe non essere abilitato — in tal caso creare via API/UI).

### 3. Inizializzare git e push

```bash
cd /data/massimiliano/Vari/preference-sort
git init
git add .gitignore *.go go.mod go.sum Dockerfile docker-compose.yml migrations/
git commit -m "Initial commit: Preference Sort API (Bradley-Terry pairwise ranking)"
git remote add origin ssh://git@100.86.46.84:222/sol_root/preference-sort.git
git push -u origin main
```

**Nota**: `git init` crea branch `main` di default (configurazione globale).

## File coinvolti

- `/data/massimiliano/Vari/preference-sort/.gitignore` — **nuovo**
- `/data/massimiliano/Vari/preference-sort/*` — tutti i file Go + infra (commit)

## Verifica

```bash
# Repo accessibile su Gitea
curl -s http://100.86.46.84/git/sol_root/preference-sort | head -5

# Clone funziona
git clone ssh://git@100.86.46.84:222/sol_root/preference-sort.git /tmp/test-clone && rm -rf /tmp/test-clone
```
