# Fix residuo: compose PostgreSQL + WikiJS render cache

## Contesto

PostgreSQL era in restart loop perché il compose puntava a `pg16-age` ma i dati sono PG18. Il container è stato ripristinato (gira con `pg18-age`, healthy), ma il compose file su disco è ancora sbagliato. WikiJS ha 22 pagine con render cache stale (frontmatter visibile nell'HTML).

## Stato attuale (verificato)

- **PostgreSQL**: UP, healthy, `sol/postgres:pg18-age`, tutti gli 8 DB presenti
- **WikiJS**: UP, healthy, patch `page-helper-patch.js` attiva
- **Content DB**: 0 pagine con frontmatter nel content (pulito)
- **Render cache**: 22 pagine con frontmatter nell'HTML renderizzato (da svuotare)
- **Compose file**: `/data/massimiliano/postgres/docker-compose.yml` dice `pg16-age` (SBAGLIATO)

## Piano (2 step)

### Step 1: Fix compose PostgreSQL

File: `/data/massimiliano/postgres/docker-compose.yml`
Cambiare `image: sol/postgres:pg16-age` → `image: sol/postgres:pg18-age`

Questo allinea il compose al container in esecuzione. Senza fix, un futuro `docker compose up -d` tirerebbe su l'immagine pg16 rompendo tutto.

### Step 2: Svuotare render cache WikiJS

```sql
UPDATE pages SET render = '' WHERE render LIKE '%title:%' OR render LIKE '%description:%';
```

WikiJS ri-renderizza automaticamente le pagine con `render` vuoto alla prossima visita. Non serve restart.

### Verifica

1. `docker compose config` in `/data/massimiliano/postgres/` → mostra `pg18-age`
2. Visitare `wiki.massimilianopili.com/en/agent-framework/research-domains-ext` → nessun frontmatter visibile
3. `SELECT count(*) FROM pages WHERE render LIKE '%title:%';` → 0 dopo le visite

## File coinvolti

- `/data/massimiliano/postgres/docker-compose.yml` (fix immagine)
- DB `wikijs.pages` colonna `render` (clear cache)
