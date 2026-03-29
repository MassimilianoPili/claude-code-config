# Piano: Allinea agent-framework da Gitea a GitHub

## Contesto

Il repo `agent-framework` (`/data/massimiliano/agent-framework`) ha solo il remote `origin` (Gitea: `git@gitea-local:sol_root/agent-framework.git`). Serve aggiungere il remote `github` e pushare tutto, come fanno le librerie MCP (pattern: `git@github.com:MassimilianoPili/<repo>.git`).

**Stato attuale**:
- Branch `main`, 2 commit ahead di `origin/main`
- 116 file con modifiche (staged + unstaged + untracked)
- SSH agent **senza chiavi** — serve `ssh-ensure` prima del push

## Passi

### 1. Caricare la chiave SSH
```bash
ssh-ensure
```
Chiederà la passphrase se non è già in cache.

### 2. Pushare su Gitea (allineare origin)
Il branch locale è 2 commit ahead di `origin/main`. Prima di mirrorare su GitHub, allineare Gitea:
```bash
cd /data/massimiliano/agent-framework
git push origin main
```
**Nota**: i 116 file modificati NON vengono committati — si pusha solo ciò che è già committato (2 commit ahead).

### 3. Verificare/creare il repo su GitHub
Controllare se esiste `MassimilianoPili/agent-framework` su GitHub:
```bash
git ls-remote --heads git@github.com:MassimilianoPili/agent-framework.git
```
Se non esiste, crearlo:
```bash
gh repo create MassimilianoPili/agent-framework --private --source=. --remote=github
```
(oppure `--public` se il repo deve essere pubblico)

### 4. Aggiungere remote `github`
```bash
git remote add github git@github.com:MassimilianoPili/agent-framework.git
```

### 5. Push su GitHub
```bash
git push github main
```

### 6. (Opzionale) Push di tutti i tag
```bash
git push github --tags
```

## Verifica

```bash
git remote -v                    # Deve mostrare origin (Gitea) + github (GitHub)
git log --oneline -3             # Stessi commit su entrambi
git ls-remote github             # Verificare che main sia allineato
```

## File coinvolti

- `/data/massimiliano/agent-framework/.git/config` — aggiunta remote `github`
- Nessun file sorgente modificato
