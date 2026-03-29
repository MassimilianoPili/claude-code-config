# Allineamento Documentazione — Server SOL

## Contesto

L'audit security ha evidenziato che la documentazione (CLAUDE.md, MEMORY.md, docs/) non riflette lo stato attuale dell'infrastruttura. Ci sono servizi nuovi non documentati, porte cambiate, e la sezione SSH Agent obsoleta.

---

## Discrepanze trovate

### CLAUDE.md — Tabella routing (righe 20-39)

**Mancano 5 path** presenti in nginx.conf e con container attivi:

| Path | Servizio | Auth | Backend |
|------|----------|------|---------|
| `/stats/` | GoAccess (analytics) | Nessuna | file statici + goaccess:7890 (WS) |
| `/wiki/` | Wiki.js | SAML Keycloak nativo | wikijs:3000 |
| `/minio/` | MinIO Console | OIDC Keycloak nativo | minio:9001 |
| `/s3/` | MinIO S3 API | Access key auth | minio:9000 |
| `/jenkins/` | Jenkins | SAML Keycloak nativo | jenkins:8080 |
| `/kp/` | KP Manager | OAuth2 Proxy + blocco visitor | kp-manager:8095 |

### CLAUDE.md — Tabella Tailscale (righe 52-70)

Mancano gli URL Tailscale per i 5 servizi sopra. Inoltre la riga File Manager (riga 70) dice `:9090` ma ora e' `127.0.0.1:9090` (non raggiungibile direttamente da remoto).

### CLAUDE.md — Tabella Servizi e Porte (righe 179-212)

**Mancano 6 container** dalla tabella:

| Servizio | Container | Porta interna | Auth |
|----------|-----------|---------------|------|
| **GoAccess** | goaccess | 7890 | Nessuna |
| **Vector** | vector | - (pipeline log) | Solo rete Docker |
| **Wiki.js** | wikijs | 3000 | SAML Keycloak nativo |
| **MinIO** | minio | 9000 (API), 9001 (console) | OIDC Keycloak (console), access key (API) |
| **Jenkins** | jenkins | 8080 (http), 50000 (agent) | SAML Keycloak nativo |
| **KP Manager** | kp-manager | 8095 | OAuth2 Proxy → Keycloak |

**Errori nelle righe esistenti:**
- Riga 190: Claude Proxy porta interna dice `8090` ma il processo ascolta su `8091` (8090 e' nginx)
- Riga 192: File Manager dice `:9090` nelle porte esterne, ora e' `127.0.0.1:9090`

### CLAUDE.md — Directory Layout (righe 72-175)

**Mancano** le directory:
- `jenkins/` — Jenkins CI
- `minio/` — MinIO object storage
- `wikijs/` — Wiki.js

### CLAUDE.md — Sezione SSH Agent (righe 436-478)

**Completamente obsoleta**: descrive gpg-agent con SSH emulation, ma il server usa `ssh-agent.service` (systemd user-level) dal 2026-02-28. Il socket e' `/run/user/1000/ssh-agent.sock`, non `/run/user/1000/gnupg/S.gpg-agent.ssh`.

La MEMORY.md ha gia' l'info corretta (riga 125).

### CLAUDE.md — Configurazioni subpath (tabella ~riga 532)

Mancano le righe per Wiki.js, MinIO, Jenkins, KP Manager, GoAccess.

### MEMORY.md — Sezione Architettura (riga 25)

Dice `~33 container` — attualmente sono **26** container attivi. Lista auth incompleta: manca menzione di SAML (Wiki.js, Jenkins) e OIDC MinIO.

### MEMORY.md — Sezione Sicurezza (riga 32)

Dice "5 client" Keycloak — vanno aggiunti i client per Wiki.js (SAML), MinIO (OIDC), Jenkins (SAML).

### docs/ — Stato

- `servizi-docker.md` — ha GoAccess e Vector, **manca** Jenkins, MinIO, Wiki.js
- `rete-e-routing.md` — ha GoAccess, **manca** Jenkins, MinIO, Wiki.js, KP Manager
- `security.md` — **manca** auth Jenkins (SAML), MinIO (OIDC), Wiki.js (SAML)

---

## Piano di fix

### 1. CLAUDE.md — Tabella routing (righe 20-39)
Aggiungere 6 righe (stats, wiki, minio, s3, jenkins, kp).

### 2. CLAUDE.md — Tabella Tailscale (righe 52-70)
Aggiungere URL per wiki, minio, jenkins, kp, stats. Rimuovere riga File Manager diretto (non piu' accessibile da remoto).

### 3. CLAUDE.md — Tabella Servizi e Porte (righe 179-212)
Aggiungere 6 righe (GoAccess, Vector, Wiki.js, MinIO, Jenkins, KP Manager). Correggere porta Claude Proxy (8090→8091). Correggere porta File Manager (aggiungere 127.0.0.1).

### 4. CLAUDE.md — Directory Layout (righe 72-175)
Aggiungere `jenkins/`, `minio/`, `wikijs/` nel tree.

### 5. CLAUDE.md — Sezione SSH Agent (righe 436-478)
Riscrivere completamente: ssh-agent.service, socket `/run/user/1000/ssh-agent.sock`, rimuovere riferimenti a gpg-agent SSH emulation.

### 6. CLAUDE.md — Tabella subpath (~riga 532)
Aggiungere righe per Wiki.js (SAML), MinIO (OIDC, strip prefix), Jenkins (SAML, Pattern B), KP Manager, GoAccess.

### 7. MEMORY.md — Sezione Architettura (riga 25)
Aggiornare conteggio container (26) e lista pattern auth (aggiungere SAML).

### 8. MEMORY.md — Sezione Sicurezza (riga 32)
Aggiornare numero client Keycloak e aggiungere menzione SAML.

### 9. docs/servizi-docker.md
Aggiungere Jenkins, MinIO, Wiki.js alla tabella container.

### 10. docs/rete-e-routing.md
Aggiungere routing per Jenkins, MinIO, Wiki.js, KP Manager.

### 11. docs/security.md
Aggiungere auth SAML (Jenkins, Wiki.js) e OIDC MinIO alla documentazione.

---

## File da modificare

| File | Tipo modifica |
|------|--------------|
| `/data/massimiliano/CLAUDE.md` | 6 sezioni da aggiornare |
| `/home/massimiliano/.claude/projects/-data-massimiliano/memory/MEMORY.md` | 2 sezioni |
| `/data/massimiliano/docs/servizi-docker.md` | Aggiunta 3 servizi |
| `/data/massimiliano/docs/rete-e-routing.md` | Aggiunta 4 path |
| `/data/massimiliano/docs/security.md` | Aggiunta 3 auth |

## Verifica

Dopo le modifiche:
1. Contare i servizi in CLAUDE.md e confrontare con `docker ps --format '{{.Names}}' | wc -l`
2. Confrontare ogni riga della tabella routing con `grep 'location' nginx.conf`
3. Verificare che i path nella tabella subpath corrispondano alla config nginx
