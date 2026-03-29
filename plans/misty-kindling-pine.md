# Piano: Importazione documentazione in WikiJS

## Contesto

WikiJS v2 e' attivo (`wikijs:3000`, porta 8889) ma completamente vuoto (0 pagine).
Il server ha ~50 file di documentazione (.md) sparsi in varie directory.
L'obiettivo e' importarli tutti nella wiki con una struttura organizzata, usando
l'API GraphQL di WikiJS per la creazione programmatica delle pagine.

**Problema principale**: le mutazioni GraphQL richiedono autenticazione (API key o JWT).
Non esistono API key e la password admin locale e' sconosciuta. La soluzione e' generare
un API key direttamente nel database, replicando il meccanismo interno di WikiJS.

## Step 1 — Creare lo script di importazione

**File**: `/data/massimiliano/wikijs/import-docs.js` (Node.js, ~250 righe)

Lo script ha 3 fasi:

### Fase A: Generare API Key (una tantum)

WikiJS firma le API key come JWT RS256 con la chiave RSA privata del sito
(tabella `settings`, chiave `certs`), usando come passphrase il `sessionSecret`.

1. Leggere `certs.private` e `sessionSecret` da `settings` via `docker exec postgres psql`
2. Decifrare la chiave RSA con `crypto.createPrivateKey()`, esportare come PKCS#8
3. Firmare un JWT `{ api: <id>, grp: 1 }` (grp 1 = Administrators) con `jose.SignJWT`
4. Inserire il record in tabella `apiKeys`
5. Abilitare l'API: inserire setting `api` = `{"isEnabled": true}`

**Dipendenze**: `jose` (gia' in `/data/massimiliano/dashboard-api/node_modules/jose/`)
e `crypto` (built-in Node.js). Nessuna installazione necessaria.

### Fase B: Restart WikiJS

WikiJS carica le API key in memoria all'avvio. Dopo l'inserimento DB:

```bash
cd /data/massimiliano/wikijs && docker compose restart wikijs
```

Poll su `http://100.86.46.84:8889/graphql` finche' non risponde (healthcheck ~30s).

### Fase C: Importare le pagine via GraphQL

Per ogni file nella mappa:
1. Leggere il contenuto markdown
2. Estrarre titolo (primo `# ...`) e descrizione (primo paragrafo, max 255 char)
3. Verificare se la pagina esiste gia' (`singleByPath` query)
4. Creare o aggiornare via mutazione GraphQL con **variabili** (nessun escaping manuale)
5. Delay 500ms tra le pagine (WikiJS fa `rebuildTree` dopo ogni creazione)

**Approccio chiave**: usare variabili GraphQL (`$content`, `$title`, etc.) invece di
interpolazione stringa. `JSON.stringify` gestisce automaticamente tutti i caratteri
speciali nel markdown (backtick, newline, quote, unicode).

## Step 2 — Struttura wiki (gerarchia path)

```
home                                    # Pagina iniziale con link a tutte le sezioni

infra/overview                          # README.md (Server SOL overview)

docs/indice                             # Indice documentazione operativa
docs/backup                             # Backup e ripristino
docs/dashboard                          # Dashboard web e terminal
docs/monitoraggio                       # Prometheus, Grafana, Loki
docs/mcp-libraries                      # 11 librerie MCP Maven Central
docs/rete-e-routing                     # Rete Docker, nginx, Cloudflare Tunnel
docs/security                           # Keycloak SSO, auth patterns, visitor
docs/servizi-docker                     # Inventario container, hardening
docs/shell-scripts                      # Toolkit CLI (sol, gitall, x-tools)
docs/ssh-e-git                          # SSH agent, Git config
docs/sysctl-tuning                      # Tuning UDP buffer QUIC
docs/preference-vector-theory           # Teoria ranking + embedding
docs/vector-db-strategy                 # Strategia Vector DB e Graph RAG

progetti/azure-cloud                    # Piano Azure DevOps + Portal
progetti/jira-cloud                     # Piano Jira Cloud
progetti/ocp4-sandbox                   # Piano OpenShift 4 Sandbox
progetti/mail-stalwart                  # Piano server mail
progetti/payload-cms                    # Piano Payload CMS

agent-framework/overview                # Agent Framework README
agent-framework/piano                   # Evoluzione architetturale
agent-framework/setup                   # Guida setup

servizi/proxy                           # Nginx reverse proxy
servizi/code-server                     # VS Code browser-based
servizi/monitoring                      # Stack monitoring
servizi/wg-manager                      # WireGuard VPN
servizi/kp-manager                      # KeePass web frontend
servizi/claude-proxy                    # Claude Proxy API
servizi/claude-remote                   # Claude remote control

mcp/server                              # MCP Server (aggregatore)
mcp/spring-ai-reactive-tools            # Base library reactive
mcp/azure-tools                         # Azure resource management
mcp/devops-tools                        # Azure DevOps
mcp/docker-tools                        # Docker management
mcp/filesystem-tools                    # Filesystem operations
mcp/graph-tools                         # Graph DB (Neo4j, AGE)
mcp/jira-tools                          # Jira Cloud API
mcp/mongo-tools                         # MongoDB CRUD
mcp/ocp-tools                           # OpenShift/Kubernetes
mcp/sql-tools                           # SQL database queries
mcp/vector-tools                        # Semantic search pgvector

misc/graph-vector-piano                 # Piano graph + vector (completato)
misc/claude-code-config                 # Claude Code hooks e skills
misc/claude-shared-storage              # Storage condiviso SSHFS
```

**Totale: 47 pagine** (46 da file + 1 home page generata).

## Step 3 — Eseguire lo script

```bash
# Generare API key + abilitare API + restart WikiJS
node /data/massimiliano/wikijs/import-docs.js --setup

# Importare tutte le pagine
node /data/massimiliano/wikijs/import-docs.js --import

# Oppure tutto insieme
node /data/massimiliano/wikijs/import-docs.js --all
```

Flag `--update` per aggiornare pagine esistenti (idempotente).

## Step 4 — Verifica

1. Aprire `http://100.86.46.84:8889/` e verificare che le pagine siano visibili
2. Query GraphQL di conteggio: `{ pages { list { id path title } } }` — deve restituire 47 pagine
3. Navigare la gerarchia (docs/, mcp/, servizi/) nel tree laterale
4. Verificare rendering markdown (tabelle, code blocks, heading)

## File coinvolti

| File | Azione |
|------|--------|
| `/data/massimiliano/wikijs/import-docs.js` | **Creare** — script Node.js di importazione |
| WikiJS container | **Restart** — per ricaricare API key |
| PostgreSQL `wikijs` DB | **Modificare** — insert API key + setting `api` |

## Note tecniche

- **Locale**: `en` (unico installato; il contenuto e' italiano ma il locale e' un concetto di routing in WikiJS)
- **Editor**: `markdown` per tutte le pagine
- **Privacy**: tutte pubbliche (`isPrivate: false`, `isPublished: true`)
- **Tags**: ogni pagina ha 2-4 tag basati sulla categoria (es. `documentazione`, `operativo`, `mcp`, `servizio`)
- **CLAUDE.md escluso**: il file principale CLAUDE.md (~2800 righe) e' un file di istruzioni per Claude Code, non documentazione wiki-friendly. I CLAUDE.md dei singoli progetti sono anch'essi esclusi.
- **Dimensioni stimate**: ~11.000 righe di markdown totali, ~2 minuti di importazione
