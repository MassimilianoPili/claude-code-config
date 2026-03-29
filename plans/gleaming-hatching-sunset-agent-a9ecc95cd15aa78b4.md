# Analisi directory infrastruttura /data/massimiliano/ — stato Git

## Riepilogo

Nessuna delle 15 directory esaminate e' un repository Git.
Solo `shell-scripts/` ha un file `.gitignore` esistente (ma nessun `.git`).
`Vari/server-api/` non e' contenuto in nessun repo Git parent.

---

## Dettaglio per directory

### 1. /data/massimiliano/proxy/
- **Git**: NO .git, NO .gitignore
- **File da tracciare**: `docker-compose.yml`, `nginx.conf`, `logrotate.conf`, `vector.toml`, `README.md`, `home/index.html`
- **File da ignorare**: `.env` (secrets OAuth2), `logs/` (log nginx), `goaccess/data/` (dati GoAccess), `goaccess/report/` (report generati), `vector-data/` (dati Vector/telemetria)
- **Volumi dati**: `logs/`, `goaccess/data/`, `goaccess/report/`, `vector-data/nginx_access/`
- **Note**: Directory ricca di configurazione. L'index.html e' ~53KB (dashboard completa).

### 2. /data/massimiliano/dashboard-api/
- **Git**: NO .git, NO .gitignore
- **File da tracciare**: `server.js`, `package.json`, `package-lock.json`
- **File da ignorare**: `node_modules/`, `notes.txt` (dati utente persistenti), `ttyd` (binary statico 1.3MB)
- **Volumi dati**: nessuno (ma `notes.txt` e' dati runtime)
- **Note**: Codice sorgente custom Node.js. Il binary `ttyd` e' scaricabile, non va committato.

### 3. /data/massimiliano/shell-scripts/
- **Git**: NO .git, HAS .gitignore (ignora `lib/repoList.sh` e `lib/repoListGitlab.sh` — contengono credenziali)
- **File da tracciare**: `bin/*` (16 script), `lib/funzioni.sh`, `lib/xrepos.sh`, `lib/*.example`, `archive/*`, `.gitignore`
- **File da ignorare**: `lib/repoList.sh`, `lib/repoListGitlab.sh` (gia' nel .gitignore)
- **Volumi dati**: nessuno
- **Note**: Gia' predisposto per Git (ha .gitignore). Script toolkit con file example per i file con credenziali.

### 4. /data/massimiliano/code-server/
- **Git**: NO .git, NO .gitignore
- **File da tracciare**: `docker-compose.yml`, `Dockerfile`, `README.md`
- **File da ignorare**: `config/` (configurazione code-server runtime, preferenze utente), `local/` (estensioni VS Code, cache)
- **Volumi dati**: `config/`, `local/` (persistenza container)
- **Note**: Il Dockerfile e' custom (rename utente). Config e local sono volumi persistenti del container.

### 5. /data/massimiliano/gitea/
- **Git**: NO .git, NO .gitignore
- **File da tracciare**: `docker-compose.yml`, `config/release-template.yml`
- **File da ignorare**: `.env` (GITEA_DB_PASSWD), `gitea-data/` (~265MB, dati Gitea + repo), `runner-data/` (dati act_runner)
- **Volumi dati**: `gitea-data/` (265MB, owner root), `runner-data/` (12K, owner root)
- **Note**: I dati Gitea sono grossi e contengono i repository Git stessi. Il template CI/CD in config/ e' importante.

### 6. /data/massimiliano/keycloak/
- **Git**: NO .git, NO .gitignore
- **File da tracciare**: `docker-compose.yml`
- **File da ignorare**: `.env` (KC_DB_PASSWORD, KC_BOOTSTRAP_ADMIN_PASSWORD)
- **Volumi dati**: nessuno (dati in PostgreSQL)
- **Note**: Directory molto semplice — solo compose + env.

### 7. /data/massimiliano/postgres/
- **Git**: NO .git, NO .gitignore
- **File da tracciare**: `docker-compose.yml`, `init/01-gitea.sql`
- **File da ignorare**: `.env` (password DB), `data/` (dati PostgreSQL, owner root/UID 70)
- **Volumi dati**: `data/` (dati DB, permessi restrittivi)
- **Note**: Lo script init e' essenziale per il bootstrap. I dati DB non vanno mai committati.

### 8. /data/massimiliano/redis/
- **Git**: NO .git, NO .gitignore
- **File da tracciare**: `docker-compose.yml`
- **File da ignorare**: `data/` (dump Redis, 8K, owner dnsmasq/root)
- **Volumi dati**: `data/` (persistenza Redis)
- **Note**: Directory minimale — solo compose + dati.

### 9. /data/massimiliano/cloudflared/
- **Git**: NO .git, NO .gitignore
- **File da tracciare**: `docker-compose.yml`, `config.yml`
- **File da ignorare**: `cert.pem` (certificato tunnel, SENSIBILE), `6e7eafe0-*.json` (credenziali tunnel, SENSIBILE)
- **Volumi dati**: nessuno
- **Note**: ATTENZIONE SICUREZZA — cert.pem e il file JSON sono credenziali del tunnel Cloudflare. Owner UID 65532 (nonroot). Non vanno mai committati.

### 10. /data/massimiliano/mongodb/
- **Git**: NO .git, NO .gitignore
- **File da tracciare**: `docker-compose.yml`
- **File da ignorare**: `.env` (MONGO_ROOT_USER, MONGO_ROOT_PASSWORD), `data/` (~396K, dati MongoDB)
- **Volumi dati**: `data/` (owner dnsmasq/root)
- **Note**: Compose + env + dati. Struttura standard.

### 11. /data/massimiliano/libsql/
- **Git**: NO .git, NO .gitignore
- **File da tracciare**: `docker-compose.yml`
- **File da ignorare**: `data/` (~140K, database SQLite)
- **Volumi dati**: `data/` (owner UID 666)
- **Note**: Directory minimale — solo compose + dati. Nessun .env.

### 12. /data/massimiliano/artemis/
- **Git**: NO .git, NO .gitignore
- **File da tracciare**: `docker-compose.yml`
- **File da ignorare**: `.env` (ARTEMIS_USER, ARTEMIS_PASSWORD), `data/` (~23MB, broker instance + journal)
- **Volumi dati**: `data/` (23MB, owner UID 1001)
- **Note**: Il data/ di Artemis e' piu' grande degli altri perche' contiene il journal del broker.

### 13. /data/massimiliano/pgadmin/
- **Git**: NO .git, NO .gitignore
- **File da tracciare**: `docker-compose.yml`
- **File da ignorare**: `.env` (credenziali pgAdmin), `data/` (~208K, configurazione pgAdmin runtime)
- **Volumi dati**: `data/` (owner UID 5050)
- **Note**: Il data/ contiene le connessioni salvate dell'utente pgAdmin. Non e' codice.

### 14. /data/massimiliano/portainer/
- **Git**: NO .git, NO .gitignore
- **File da tracciare**: `docker-compose.yml`
- **File da ignorare**: `data/` (~440K, dati Portainer — utenti, endpoint, stack)
- **Volumi dati**: `data/` (owner root)
- **Note**: Nessun .env. Directory minimale.

### 15. /data/massimiliano/Vari/server-api/
- **Git**: NO .git, NO .gitignore
- **Parent Git**: NESSUNO — non e' contenuto in nessun repository Git (verificato fino al mount point /)
- **File da tracciare**: `main.go`, `go.mod`, `go.sum`, `Dockerfile`, `docker-compose.yml`, `static/index.html`
- **File da ignorare**: nessun file dati presente
- **Volumi dati**: nessuno
- **Note**: Codice sorgente Go completo (~14.5KB main.go). Tutto e' tracciabile. Nessun file sensibile o dati persistenti visibili.

---

## Classificazione per complessita'

### Directory con codice sorgente custom (alta priorita' per Git)
1. **proxy/** — nginx.conf complesso (24KB), dashboard HTML (53KB), compose, vector, logrotate
2. **dashboard-api/** — server Node.js custom, package.json
3. **shell-scripts/** — 16 script bash, gia' con .gitignore
4. **Vari/server-api/** — applicazione Go completa
5. **code-server/** — Dockerfile custom

### Directory solo configurazione (media priorita')
6. **gitea/** — compose + template CI/CD
7. **keycloak/** — solo compose
8. **postgres/** — compose + init SQL
9. **cloudflared/** — compose + config tunnel
10. **mongodb/** — solo compose
11. **artemis/** — solo compose

### Directory minimali (bassa priorita')
12. **redis/** — solo compose
13. **libsql/** — solo compose
14. **pgadmin/** — solo compose
15. **portainer/** — solo compose
