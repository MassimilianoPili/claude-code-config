# PIANO — Aggiornamento README.md post-hardening

**Data**: 2026-02-28 | **Scope**: Aggiornare `/data/massimiliano/README.md` per documentare il security hardening e la feature health dots

---

## Contesto

Dopo l'audit e l'implementazione di 5 fasi di security hardening (credenziali, Docker, nginx, efficienza, health dots), il README.md non riflette le modifiche. Serve documentare le misure di sicurezza adottate e la nuova feature di monitoraggio.

Il README e' ~310 righe, con: architettura ASCII, tabelle accesso rapido, visitor access, MCP libraries, SSH agent, storage, hooks. Non ha alcuna sezione sulla sicurezza o sul monitoraggio health.

---

## Modifiche al file

**File**: `/data/massimiliano/README.md`

### 1. Aggiungere sezione "Sicurezza" dopo "Visitor Access" (dopo riga 190)

Nuova sezione con 4 sottosezioni:

**1a. Docker Hardening**
- Immagini critiche pinnate: Keycloak `26.5.4`, OAuth2 Proxy `v7.14.2`, Gitea `1.25.4`
- Memory limits su tutti i 21 container (tabella compatta)
- `security_opt: no-new-privileges:true` su tutti i container
- Docker socket `:ro` su server-api e code-server
- Keycloak in production mode (`build && start --optimized`)

**1b. Nginx Hardening**
- Security headers: X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy, HSTS
- `server_tokens off`
- Rate limiting su `/auth/` (5r/s, burst 20)
- Timeout globali (30s)
- gzip compression
- `client_max_body_size 2g` su `/files/`
- pgAdmin CSRF riabilitato

**1c. Credenziali**
- Tutti i `.env` con permessi 600
- Nessuna password hardcoded nei compose/SQL
- Token sensibili in `.env`, referenziati come `${VAR}`

**1d. Healthcheck e monitoraggio**
- 10 container con healthcheck attivo (tabella: container + tipo check)
- 11 container senza healthcheck (immagini scratch/distroless, monitorati esternamente)
- Dashboard health dots: SSE da server-api con stato `{state, health}`
- Colori: verde (healthy/running), rosso (unhealthy/down), arancione (starting)
- Tooltip su hover con stato dettagliato

### 2. Aggiornare descrizione Dashboard nella sezione architettura (informativo)

Nella intro o subito dopo il diagramma, aggiungere una riga sulla dashboard:
> I dot di stato nella dashboard riflettono in tempo reale lo stato health dei container via SSE (`/server/status/stream`).

### 3. Aggiungere "Server API status format" nella sezione API

Documentare il nuovo formato SSE:
```json
{"nginx": {"state": "running", "health": "healthy"}, ...}
```
Valori health: `healthy`, `unhealthy`, `starting`, `none`

---

## Stile e tono

- Mantenere lo stesso formato del README esistente (tabelle markdown, sezioni concise)
- Lingua italiana (coerente con il resto)
- Niente duplicazione di info gia' in CLAUDE.md — il README e' overview, CLAUDE.md e' il dettaglio operativo

---

## Verifica

- Controllare che il markdown si renderizzi correttamente
- Verificare che le tabelle siano allineate
- Nessun link rotto o riferimento obsoleto
