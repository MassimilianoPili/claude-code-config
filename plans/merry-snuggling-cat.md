# Piano: Installazione Apache AGE (Graph DB) su PostgreSQL 16

## Contesto

Il server usa PostgreSQL 16 (`pgvector/pgvector:pg16`) con pgvector per ricerca vettoriale (2,690 vettori nel database `embeddings`). La strategia in `docs/vector-db-strategy.md` prevede Apache AGE come estensione grafo per hybrid Vector + Graph RAG, scelto su Neo4j per zero infrastruttura aggiuntiva. Attualmente AGE non è installato e non esiste un Dockerfile custom.

**Obiettivo**: Aggiungere Apache AGE 1.6.0 (PG16) al container PostgreSQL esistente, mantenendo pgvector e tutti i dati intatti.

---

## Step 1 — Creare `/data/massimiliano/postgres/Dockerfile`

Multi-stage build: compila AGE da sorgente nella stage 1, copia solo i 3 artefatti nella stage 2.

```dockerfile
# Immagine PostgreSQL 16 con pgvector + Apache AGE
# pgvector: gia' incluso nell'immagine base
# AGE: compilato da sorgente (PG16/v1.6.0-rc0)

FROM pgvector/pgvector:pg16 AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential flex bison postgresql-server-dev-16 git && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch PG16/v1.6.0-rc0 \
    https://github.com/apache/age.git /tmp/age && \
    cd /tmp/age && \
    make PG_CONFIG=/usr/bin/pg_config && \
    make install PG_CONFIG=/usr/bin/pg_config

FROM pgvector/pgvector:pg16

COPY --from=builder /usr/lib/postgresql/16/lib/age.so \
    /usr/lib/postgresql/16/lib/
COPY --from=builder /usr/share/postgresql/16/extension/age.control \
    /usr/share/postgresql/16/extension/
COPY --from=builder /usr/share/postgresql/16/extension/age--1.6.0.sql \
    /usr/share/postgresql/16/extension/

CMD ["postgres", "-c", "shared_preload_libraries=age"]
```

## Step 2 — Modificare `docker-compose.yml`

Sostituire `image: pgvector/pgvector:pg16` con `build: .` + tag locale:

```yaml
services:
  postgres:
    build: .
    image: sol/postgres:pg16-age
    # ... resto invariato
```

## Step 3 — Creare `/data/massimiliano/postgres/init/03-age.sh`

Per installazioni future (non esegue ora — data volume esiste già):

```bash
#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    \c embeddings
    CREATE EXTENSION IF NOT EXISTS age;
    ALTER DATABASE embeddings SET search_path = ag_catalog, "\$user", public;
EOSQL
```

## Step 4 — Build e deploy

```bash
cd /data/massimiliano/postgres
docker compose build                     # ~2-5 min, container corrente continua
docker compose up -d --force-recreate    # downtime ~5-10 sec
```

## Step 5 — Abilitare AGE nel database esistente

```bash
docker exec postgres psql -U postgres -d embeddings -c "CREATE EXTENSION IF NOT EXISTS age;"
docker exec postgres psql -U postgres -d embeddings -c "ALTER DATABASE embeddings SET search_path = ag_catalog, \"\\\$user\", public;"
```

## Step 6 — Creare i tre grafi pianificati

```bash
docker exec postgres psql -U postgres -d embeddings <<'EOSQL'
SELECT create_graph('knowledge_graph');
SELECT create_graph('code_graph');
SELECT create_graph('task_graph');
EOSQL
```

## Verifica

```bash
# shared_preload_libraries include 'age'
docker exec postgres psql -U postgres -c "SHOW shared_preload_libraries;"

# Estensioni: age 1.6.0 + vector 0.8.2
docker exec postgres psql -U postgres -d embeddings -c "SELECT extname, extversion FROM pg_extension ORDER BY extname;"

# pgvector intatto (2690 vettori)
docker exec postgres psql -U postgres -d embeddings -c "SELECT count(*) FROM vector_store;"

# Grafi AGE creati
docker exec postgres psql -U postgres -d embeddings -c "SELECT * FROM ag_catalog.ag_graph;"

# Test openCypher
docker exec postgres psql -U postgres -d embeddings -c "SELECT * FROM cypher('knowledge_graph', \$\$CREATE (n:Test {name: 'hello'}) RETURN n\$\$) AS (n agtype);"
docker exec postgres psql -U postgres -d embeddings -c "SELECT * FROM cypher('knowledge_graph', \$\$MATCH (n:Test) DELETE n\$\$) AS (n agtype);"

# Servizi dipendenti OK
docker logs gitea --tail 3
docker logs keycloak --tail 3

# Memoria sotto controllo (~45-55 MiB su 512 MiB)
docker stats postgres --no-stream --format "table {{.MemUsage}}\t{{.MemPerc}}"
```

## Rollback

Se il container non parte: ripristinare `image: pgvector/pgvector:pg16` in docker-compose.yml, rimuovere `build:` e la riga `image: sol/postgres:pg16-age`, poi `docker compose up -d --force-recreate`. I dati su `./data` non vengono toccati.

## File coinvolti

| File | Azione |
|------|--------|
| `postgres/Dockerfile` | **Nuovo** — multi-stage build pgvector + AGE |
| `postgres/docker-compose.yml` | **Modifica** — `build: .` + tag immagine |
| `postgres/init/03-age.sh` | **Nuovo** — init script per installazioni future |
