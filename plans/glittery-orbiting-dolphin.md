# Piano: PostgreSQL 18 con block size 32KB + indice HNSW 4096 dim

## Context

Le ricerche semantiche MCP (`embeddings_search_docs`) vanno in timeout (502) perché `vector_store` (82K righe, 1.5GB, embedding 4096 dim) non ha indice vettoriale. pgvector HNSW richiede che la tupla indice stia in una pagina PostgreSQL — con 4096 float32 = 16KB, supera il page size standard di 8KB. Ricompilare PG con `--with-blocksize=32` (32KB page) risolve definitivamente il vincolo.

## Stato attuale

- PG 18.3, pgvector 0.8.2, AGE 1.7.0-rc0 — tutti già all'ultima versione
- 8 database, ~2GB totali (embeddings 1.6GB, wikijs 328MB, resto piccolo)
- Block size attuale: 8KB
- 3 indici invalidi già droppati dall'utente
- Dockerfile già patchato con `HNSW_MAX_DIM=4096`

## Approccio

Ricompilare PostgreSQL 18 da sorgente con `--with-blocksize=32`, mantenendo pgvector e AGE compilati contro lo stesso binario.

### Step 1: pg_dumpall (backup logico completo)

```bash
docker exec postgres pg_dumpall -U postgres > /data/massimiliano/postgres/full_dump.sql
```

Il dump logico è indipendente dal block size — funziona con qualsiasi configurazione.
Include: ruoli, database, estensioni, dati, grafi AGE (tabelle in `ag_catalog`).

### Step 2: Riscrivere Dockerfile

File: `/data/massimiliano/postgres/Dockerfile`

Il Dockerfile attuale usa `pgvector/pgvector:pg18` come base (PG precompilato con blocksize 8KB).
Serve compilare PG 18 da sorgente con `--with-blocksize=32`, poi pgvector e AGE contro quel binario.

Strategia: usare `debian:bookworm-slim` come base, compilare tutto in un unico builder stage.

```dockerfile
# PostgreSQL 18 compilato da sorgente con block size 32KB
# + pgvector 0.8.2 (HNSW_MAX_DIM=4096) + Apache AGE 1.7.0-rc0

# ---- Stage 1: compilazione PG + pgvector + AGE ----
FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential flex bison pkg-config git ca-certificates \
    libreadline-dev zlib1g-dev libssl-dev libxml2-dev libxslt1-dev \
    libicu-dev liblz4-dev libzstd-dev uuid-dev python3 \
    && rm -rf /var/lib/apt/lists/*

# PostgreSQL 18 da sorgente con blocksize 32KB
RUN git clone --depth 1 --branch REL_18_3 \
    https://github.com/postgres/postgres.git /tmp/postgres && \
    cd /tmp/postgres && \
    ./configure \
        --prefix=/usr/local/pgsql \
        --with-blocksize=32 \
        --with-openssl \
        --with-libxml \
        --with-libxslt \
        --with-icu \
        --with-lz4 \
        --with-zstd \
        --with-uuid=e2fs \
        --with-python \
    && make -j$(nproc) && make install && \
    cd /tmp/postgres/contrib && make -j$(nproc) && make install

# pgvector da sorgente (HNSW_MAX_DIM=4096)
RUN git clone --depth 1 --branch v0.8.2 \
    https://github.com/pgvector/pgvector.git /tmp/pgvector && \
    cd /tmp/pgvector && \
    sed -i 's/#define HNSW_MAX_DIM 2000/#define HNSW_MAX_DIM 4096/' src/hnsw.h && \
    sed -i 's/#define IVFFLAT_MAX_DIM 2000/#define IVFFLAT_MAX_DIM 4096/' src/ivfflat.h && \
    make PG_CONFIG=/usr/local/pgsql/bin/pg_config && \
    make install PG_CONFIG=/usr/local/pgsql/bin/pg_config

# AGE da sorgente
RUN git clone --depth 1 --branch PG18/v1.7.0-rc0 \
    https://github.com/apache/age.git /tmp/age && \
    cd /tmp/age && \
    make PG_CONFIG=/usr/local/pgsql/bin/pg_config && \
    make install PG_CONFIG=/usr/local/pgsql/bin/pg_config

# ---- Stage 2: immagine runtime minimale ----
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libreadline8 zlib1g libssl3 libxml2 libxslt1.1 \
    libicu72 liblz4-1 libzstd1 libuuid1 locales gosu curl \
    && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 en_US.UTF-8

ENV LANG=en_US.UTF-8 \
    PGDATA=/var/lib/postgresql/data \
    PATH=/usr/local/pgsql/bin:$PATH

# Copiare PG + estensioni compilate
COPY --from=builder /usr/local/pgsql /usr/local/pgsql

# Creare utente postgres
RUN groupadd -r postgres && useradd -r -g postgres -d /var/lib/postgresql -s /bin/bash postgres \
    && mkdir -p /var/lib/postgresql /var/run/postgresql /docker-entrypoint-initdb.d \
    && chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql

# Entrypoint script (compatibile con l'immagine ufficiale)
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 5432
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres", "-c", "shared_preload_libraries=age"]
```

### Step 3: Creare docker-entrypoint.sh

File: `/data/massimiliano/postgres/docker-entrypoint.sh`

Script compatibile con le convenzioni dell'immagine ufficiale: gestisce initdb, esecuzione init scripts, avvio server. Necessario perché non usiamo più l'immagine ufficiale come base.

### Step 4: Fermare PG, svuotare data dir, rebuild e avvio

```bash
cd /data/massimiliano/postgres

# Fermare
docker compose down

# Svuotare data dir (il dump è il backup)
sudo rm -rf ./data/*

# Rebuild e avvio
docker compose up -d --build --force-recreate
```

Al primo avvio: initdb crea il data directory con blocksize 32KB, esegue gli init scripts (crea ruoli, database, estensioni).

### Step 5: Restore dal dump

```bash
docker exec -i postgres psql -U postgres < /data/massimiliano/postgres/full_dump.sql
```

Oppure, se ci sono conflitti (ruoli/DB già creati dagli init scripts):
```bash
docker exec -i postgres psql -U postgres -f /tmp/full_dump.sql --set ON_ERROR_STOP=off
```

### Step 6: Verificare e creare indice HNSW

```bash
# Verificare block size
docker exec postgres psql -U postgres -c "SHOW block_size;"
# Deve essere: 32768

# Verificare estensioni
docker exec postgres psql -U postgres -d embeddings -c "SELECT extname, extversion FROM pg_extension;"

# Verificare dati
docker exec postgres psql -U postgres -d embeddings -c "SELECT count(*) FROM vector_store;"
# Deve essere: 82634

# Creare indice HNSW (ora possibile con 32KB page)
docker exec postgres psql -U postgres -d embeddings -c \
  "CREATE INDEX CONCURRENTLY vector_store_hnsw_cosine_idx ON vector_store USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);"
```

### Step 7: Riavviare servizi dipendenti

```bash
cd /data/massimiliano/Vari/mcp && docker compose up -d simoge-mcp --force-recreate
```

WikiJS, Keycloak, Gitea riconnettono automaticamente (connection retry built-in).

## File da creare/modificare

- `/data/massimiliano/postgres/Dockerfile` — riscrittura completa (compilazione PG da sorgente)
- `/data/massimiliano/postgres/docker-entrypoint.sh` — nuovo file (entrypoint script)
- `/data/massimiliano/postgres/docker-compose.yml` — aggiornare `PGDATA` path se necessario

## Nota: docker-compose.yml

Attualmente monta `./data:/var/lib/postgresql`. L'immagine ufficiale usa `/var/lib/postgresql/data` come PGDATA. Verificare che il volume mount sia coerente con il nuovo entrypoint.

## Verifica finale

1. `SHOW block_size;` → `32768`
2. `SELECT count(*) FROM vector_store;` → 82634
3. Indice HNSW valido: `SELECT indisvalid FROM pg_index WHERE indexrelid = 'vector_store_hnsw_cosine_idx'::regclass;` → `t`
4. `embeddings_search_docs("test")` → risposta in <1s
5. `docker ps` — tutti i container healthy
6. WikiJS, Gitea, Keycloak accessibili

## Rischi e mitigazione

- **Downtime**: tutti i servizi PG-dipendenti down durante dump/rebuild/restore (~5-10 min)
- **Backup**: il dump SQL è il safety net. Se qualcosa va storto, ricostruire con l'immagine originale e reimportare
- **docker-entrypoint.sh**: deve gestire correttamente initdb + init scripts + signal handling. Useremo una versione semplificata rispetto all'entrypoint ufficiale
- **Memory**: 32KB block size usa più shared_buffers. Con 512MB limit dovrebbe andare bene (il default `shared_buffers` scala automaticamente)
