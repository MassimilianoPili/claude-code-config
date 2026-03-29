# Piano: Aggiornamento documentazione per WikiJS, MinIO, Jenkins

## Contesto

I tre servizi (WikiJS, MinIO, Jenkins) sono stati installati e sono operativi. Ora serve aggiornare tutta la documentazione dell'infrastruttura per riflettere i nuovi servizi: CLAUDE.md, MEMORY.md, architecture.html, architecture.md, e i docs operativi.

---

## File da aggiornare (7 file)

### 1. `/data/massimiliano/CLAUDE.md` — 4 tabelle + directory layout

**Tabella routing path-based** (~riga 20-39): aggiungere 4 righe
```
| `/wiki/` | WikiJS | SAML Keycloak nativo | wikijs:3000 |
| `/minio/` | MinIO Console | OIDC Keycloak nativo | minio:9001 |
| `/s3/` | MinIO S3 API | Access keys (S3 standard) | minio:9000 |
| `/jenkins/` | Jenkins | SAML Keycloak nativo | jenkins:8080 |
```

**Tabella Tailscale URL** (~riga 46-63): aggiungere
```
| `http://100.86.46.84/wiki/` | WikiJS |
| `http://100.86.46.84/minio/` | MinIO Console |
| `http://100.86.46.84/s3/` | MinIO S3 API |
| `http://100.86.46.84/jenkins/` | Jenkins |
```

**Directory Layout** (~riga 72-175): aggiungere 3 directory
```
├── wikijs/             # WikiJS wiki engine
│   ├── docker-compose.yml
│   └── .env            # WIKIJS_DB_PASSWD
├── minio/              # MinIO S3-compatible object storage
│   ├── docker-compose.yml
│   ├── .env            # MINIO_ROOT_USER, MINIO_ROOT_PASSWORD, MINIO_OIDC_CLIENT_SECRET
│   └── data/           # Object storage files
├── jenkins/            # Jenkins CI/CD server
│   ├── docker-compose.yml
│   └── data/           # Jenkins home (plugins, jobs, config)
```

**Tabella Servizi e Porte** (~riga 179+): aggiungere 3 righe
```
| **WikiJS** | wikijs | ghcr.io/requarks/wiki:2 | via nginx `/wiki/` | 3000 | SAML Keycloak nativo |
| **MinIO** | minio | minio/minio:latest | via nginx `/minio/` (console) + `/s3/` (API) | 9000 (API), 9001 (console) | OIDC Keycloak nativo (console), Access keys (API) |
| **Jenkins** | jenkins | jenkins/jenkins:lts | via nginx `/jenkins/` | 8080 | SAML Keycloak nativo |
```

**Tabella Configurazioni subpath** (~riga 674-694): aggiungere
```
| WikiJS | - | - | Pura webapp, nginx strip prefix (potenziale problema asset) |
| MinIO | `MINIO_BROWSER_REDIRECT_URL` | `https://sol.massimilianopili.com/minio/` | Console redirect per subpath |
| Jenkins | `JENKINS_OPTS` | `--prefix=/jenkins` | Gestisce subpath internamente (Pattern B) |
```

**Sezione PostgreSQL** (~riga 645): aggiungere database `wikijs`
```
- `wikijs` (user: `wikijs`) — dati WikiJS (pagine, utenti, configurazione)
```

### 2. `/home/massimiliano/.claude/projects/-data-massimiliano/memory/MEMORY.md`

Aggiungere breve sezione dopo "Sicurezza e Autenticazione" (~riga 30):

```markdown
## Nuovi Servizi (2026-02-28)

| Servizio | Container | Porta | Path | Auth | Memoria |
|----------|-----------|-------|------|------|---------|
| WikiJS | wikijs | 3000 | `/wiki/` | SAML Keycloak | 256m (uso ~56MB) |
| MinIO | minio | 9000/9001 | `/minio/` + `/s3/` | OIDC Keycloak (console), Access keys (S3) | 256m (uso ~79MB) |
| Jenkins | jenkins | 8080 | `/jenkins/` | SAML Keycloak | 512m (uso ~393MB) |

WikiJS: PostgreSQL backend (database `wikijs`), prefix stripping. MinIO: console 9001 + S3 API 9000. Jenkins: `--prefix=/jenkins` (Pattern B), `-Xmx384m`.
Dir: `/data/massimiliano/{wikijs,minio,jenkins}/`. Keycloak client da creare: `wikijs` (SAML), `minio` (OIDC), `jenkins` (SAML).
```

### 3. `/home/massimiliano/.claude/projects/-data-massimiliano/memory/architecture.md`

Aggiornare il diagramma ASCII e la tabella inventario container.

### 4. `/data/massimiliano/proxy/home/architecture.html`

Nel diagramma Mermaid:
- Subgraph "Web Services": aggiungere `WikiJS["/wiki/ — WikiJS\n:3000"]`
- Subgraph "Web Services" o nuovo "Storage": aggiungere `MinIO["/minio/ — MinIO\n:9000/:9001"]`
- Subgraph "Web Services" o "Infrastructure": aggiungere `Jenkins["/jenkins/ — Jenkins\n:8080"]`
- Click handlers: `click WikiJS "/wiki/"`, `click MinIO "/minio/"`, `click Jenkins "/jenkins/"`
- CSS class: `class WikiJS,Jenkins oauth` (SAML, viola), `class MinIO oidc`
- Relazioni auth: `WikiJS -.->|SAML| KC`, `MinIO -.->|OIDC| KC`, `Jenkins -.->|SAML| KC`
- Relazione dati: `WikiJS --> PG` (PostgreSQL)

### 5. `/data/massimiliano/docs/rete-e-routing.md`

Tabella "Routing Completa" (~riga 33-67): aggiungere 4 righe con format identico alle esistenti.

### 6. `/data/massimiliano/docs/servizi-docker.md`

Tabella "Inventario Container" (~riga 13-72): aggiungere 3 righe con container, immagine, porte, memoria, healthcheck.

### 7. `/data/massimiliano/docs/indice.md`

Nessun nuovo documento da creare — solo verificare che le sezioni referenzino i servizi aggiornati.

---

## Verifica

- Controllare che tutte le tabelle abbiano formattazione markdown corretta
- Le 4 tabelle in CLAUDE.md devono essere allineate con il formato esistente
- Il diagramma Mermaid in architecture.html deve renderizzare correttamente
