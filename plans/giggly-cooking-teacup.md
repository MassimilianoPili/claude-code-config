# Piano: Fix landing page Gitea

## Contesto

Visitando `https://sol.massimilianopili.com/git/` la pagina dà 404.
L'utente vuole che la landing page mostri **tutti i repository** (pagina explore).

Attualmente `LANDING_PAGE` non è configurato in `app.ini` — Gitea usa il default `home` (dashboard personale). Serve impostarlo a `explore` per mostrare la lista repo.

## Modifiche

### 1. Diagnostica 404 (verifica)
- Curl diretto a `gitea:3000` dal container nginx per capire se il 404 viene da Gitea o da nginx
- Controllare i log di Gitea per errori recenti

### 2. Aggiungere LANDING_PAGE nel docker-compose.yml
**File**: `/data/massimiliano/gitea/docker-compose.yml`

Aggiungere:
```
GITEA__server__LANDING_PAGE=explore
```

Questo fa sì che `/` reindirizzi a `/-/explore/repos` (lista completa dei repository).

### 3. Riavviare Gitea
```bash
cd /data/massimiliano/gitea && docker compose up -d --force-recreate gitea
```

### 4. Verifica
- Curl `https://sol.massimilianopili.com/git/` e verificare che rediriga alla pagina explore
- Verificare che dopo login SSO la pagina mostri i repository
