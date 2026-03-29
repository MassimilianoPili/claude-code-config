# Riorganizzazione logica sezioni griglia dashboard

## Contesto

Le card dei servizi nella dashboard sono raggruppate in sezioni tematiche, ma alcuni servizi sono nella sezione sbagliata. L'utente ha chiesto di riordinarli logicamente, con esempi specifici:
- **pgAdmin** e' un tool database → va in "Data & Messaging" (non Administration)
- **Docker Manager** e **Access Logs** sono tool di gestione → vanno in "Administration" (non APIs & Monitoring)

## Stato attuale (parzialmente modificato)

Due edit sono gia' stati applicati al file:
1. pgAdmin rimosso da Administration (OK)
2. Docker Manager e Access Logs aggiunti in Administration (OK, ma **duplicati** — restano anche in "APIs & Monitoring")

## File coinvolto

`/data/massimiliano/proxy/home/index.html`

## Modifiche rimanenti

### 1. Rimuovere duplicati da "APIs & Monitoring"

Eliminare le card `link-server` (Docker Manager) e `link-stats` (Access Logs) dalla sezione "APIs & Monitoring" (righe ~405-421). Ora sono solo duplicate.

### 2. Aggiungere pgAdmin in "Data & Messaging"

Inserire la card pgAdmin prima di mongo-express nella sezione "Data & Messaging".

### 3. Rimuovere/rinominare sezione "APIs & Monitoring"

Dopo gli spostamenti, "APIs & Monitoring" contiene solo **Claude Proxy**. Due opzioni:
- **Opzione A**: Rinominare in "APIs" (solo Claude Proxy)
- **Opzione B**: Spostare Claude Proxy in "Code & Development" (e' un tool per sviluppatori) e eliminare la sezione

→ Scelta: **Opzione A** — rinominare in "APIs" per mantenerla separata.

### 4. Layout finale sezioni

| Sezione | Card |
|---------|------|
| **External** | Dev Tools, Portfolio, GitHub |
| **Code & Development** | Gitea, VS Code, File Manager |
| **Administration** | Keycloak, Portainer, KP Manager, Docker Manager, Access Logs |
| **Data & Messaging** | pgAdmin, mongo-express, libSQL Console, Artemis Console |
| **APIs** | Claude Proxy |
| **Infrastructure** | MongoDB, PostgreSQL, Redis, Cloudflare Tunnel, Gitea Runner |

## Verifica

```bash
cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate
```

Aprire la dashboard e verificare che le sezioni siano ordinate come in tabella.
