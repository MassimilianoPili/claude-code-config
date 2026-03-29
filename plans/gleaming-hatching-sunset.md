# Piano: Aggiornare README, MEMORY e .gitignore globale

## Contesto

Dopo aver creato 14 nuovi repo Gitea per tutti i progetti infrastrutturali (31 repo totali), serve aggiornare la documentazione e configurare un gitignore globale per centralizzare i pattern comuni ed evitare duplicazioni nei `.gitignore` per-repo.

---

## 1. README.md — Aggiungere sezione "Repository Gitea"

**File**: `/data/massimiliano/README.md`

Aggiungere una sezione prima di "Storage" (fine file) che elenca tutti i 31 repo su Gitea, divisi per owner:

**`sol_root`** (23 repo):

| Repo | Directory | Descrizione |
|------|-----------|-------------|
| proxy | proxy/ | Nginx reverse proxy + OAuth2 Proxy + dashboard |
| dashboard-api | dashboard-api/ | Backend Node.js: terminal WebSocket + note |
| shell-scripts | shell-scripts/ | Toolkit operativo: sol, gitall, deploy-mcp, x* helpers |
| server-api | Vari/server-api/ | API Go per gestione container Docker |
| code-server | code-server/ | VS Code browser-based (Dockerfile custom) |
| gitea-config | gitea/ | Gitea + act_runner compose e CI/CD template |
| postgres-config | postgres/ | PostgreSQL 16 compose + init scripts |
| keycloak-config | keycloak/ | Keycloak IdP compose |
| mongodb-config | mongodb/ | MongoDB 8 + mongo-express compose |
| redis-config | redis/ | Redis 7 compose |
| libsql-config | libsql/ | libSQL server compose |
| artemis-config | artemis/ | ActiveMQ Artemis compose |
| pgadmin-config | pgadmin/ | pgAdmin 4 compose |
| portainer-config | portainer/ | Portainer CE compose |
| claude-proxy | Vari/claude-proxy/ | Claude API proxy (JWT auth) |
| claude-remote | Vari/claude-remote/ | Claude remote connector |
| ClaudeRSS | Vari/ClaudeRSS/ | RSS feed per Claude |
| go-filemanager | Vari/go-filemanager/ | File Manager con OIDC |
| Luna | Vari/Luna/ | Progetto Luna |
| MassimilianoPili.github.io | Vari/MassimilianoPili.github.io/ | Sito personale GitHub Pages |
| mcp | Vari/mcp/ | MCP Server Spring Boot |
| places-helper | Vari/places-helper/ | Helper Google Places |
| tools.MassimilianoPili | Vari/tools.MassimilianoPili/ | Tool vari |

**`maven-libs`** (8 repo): spring-ai-reactive-tools, mcp-azure-tools, mcp-devops-tools, mcp-ocp-tools, mcp-docker-tools, mcp-filesystem-tools, mcp-mongo-tools, mcp-sql-tools

---

## 2. MEMORY.md — Aggiungere sezione "Repository Git"

**File**: `/home/massimiliano/.claude/projects/-data-massimiliano/memory/MEMORY.md`

Aggiungere sezione compatta:
- 31 repo totali su Gitea: 23 `sol_root` + 8 `maven-libs`
- I 14 nuovi repo infrastrutturali con mappa directory → repo name
- cloudflared escluso (permessi UID 65532)
- Token API `cli-migration` disponibile per automazioni
- Convenzione: ogni directory in `/data/massimiliano/` è un repo git separato

---

## 3. .gitignore globale — Creare e configurare

**Stato attuale**: non esiste nessun gitignore globale, né `core.excludesFile` configurato.

**File da creare**: `~/.config/git/ignore`
**Configurazione**: `git config --global core.excludesFile ~/.config/git/ignore`

**Pattern da centralizzare** (presenti in quasi tutti i `.gitignore` per-repo):
```
.env
data/
node_modules/
*.log
.DS_Store
```

**Dopo la configurazione**, semplificare i `.gitignore` dei singoli repo rimuovendo `.env` e `data/` (ora nel globale). I pattern specifici restano nei `.gitignore` per-repo:
- `proxy/`: `logs/`, `goaccess/data/`, `goaccess/report/`, `vector-data/`
- `dashboard-api/`: `notes.txt`, `ttyd`
- `shell-scripts/`: `lib/repoList.sh`, `lib/repoListGitlab.sh` (invariato)
- `code-server/`: `config/`, `local/`
- `gitea/`: `gitea-data/`, `runner-data/`
- `cloudflared/`: `cert.pem`, `*.json` + `!docker-compose.yml` (invariato, non è repo git)

I `.gitignore` di keycloak, mongodb, artemis, pgadmin che hanno SOLO `.env` + `data/` diventeranno vuoti e potranno essere rimossi (il globale copre tutto). Quelli di redis, libsql, portainer che hanno SOLO `data/` idem.

**Nota**: per `server-api/` il `.gitignore` ha solo `.env` → diventa coperto dal globale, file rimovibile.

---

## File da modificare

| File | Azione |
|------|--------|
| `/data/massimiliano/README.md` | Aggiungere sezione "Repository Gitea" |
| `~/.claude/projects/-data-massimiliano/memory/MEMORY.md` | Aggiungere sezione "Repository Git" |
| `~/.config/git/ignore` | **Creare** con pattern comuni |
| `~/.gitconfig` | Aggiungere `core.excludesFile` |
| `.gitignore` di 11 repo | Rimuovere `.env` e/o `data/` (ora nel globale) |

## Verifica

- `git config --global core.excludesFile` → `~/.config/git/ignore`
- `cat ~/.config/git/ignore` → contiene `.env`, `data/`, `node_modules/`, `*.log`, `.DS_Store`
- Per ogni repo: `git -C <dir> status` → nessun file sensibile appare come untracked
- `cat /data/massimiliano/README.md` → sezione repo presente con 31 entries
