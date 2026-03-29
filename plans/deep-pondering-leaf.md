# Upgrade PostgreSQL 16 → 18 + AGE v1.7.0-rc0

## Contesto

AGE v1.6.0-rc0 (PG16) ha un bug `label_id must be 1..65535` su label con ID ≤ 13 (es. Author ID 6). Pre-flight test completato su PG17: **AGE v1.7.0-rc0 fixa il bug**. Target: PG18 (18.3, GA Sep 2025, EOL 2030).

## Approccio: Blue-Green

Build e test dell'immagine PG18 **in parallelo** a PG16 (zero downtime durante la validazione). Lo swap avviene solo dopo conferma funzionale. Downtime limitato alla finestra dump → restore.

## Infrastruttura attuale

- **Dockerfile**: `/data/massimiliano/postgres/Dockerfile` — `pgvector/pgvector:pg16` + AGE `PG16/v1.6.0-rc0`
- **docker-compose**: `/data/massimiliano/postgres/docker-compose.yml` — image `sol/postgres:pg16-age`, bind mount `./data`, 512m, porta 127.0.0.1:5432
- **Init scripts**: `01-databases.sh` (gitea, keycloak), `02-embeddings.sh` (pgvector), `03-age.sh` (AGE extension)
- **Credenziali**: `/data/massimiliano/postgres/.env`
- **5 database**: gitea, keycloak, wikijs, preference_sort, embeddings (pgvector + AGE 3 grafi)
- **6 consumer**: Gitea, Keycloak, WikiJS, Preference Sort, simoge-mcp, pgAdmin — nessuno pinna versione PG

---

## Fase A: Build & Validazione (PG16 resta in esecuzione)

### Step A1: Creare Dockerfile PG18

Creare `/tmp/Dockerfile.pg18` (file temporaneo, non tocca il Dockerfile di produzione):

```dockerfile
# PostgreSQL 18 con pgvector + Apache AGE v1.7.0-rc0
FROM pgvector/pgvector:pg18 AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential flex bison postgresql-server-dev-18 git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch PG18/v1.7.0-rc0 \
    https://github.com/apache/age.git /tmp/age && \
    cd /tmp/age && \
    make PG_CONFIG=/usr/bin/pg_config && \
    make install PG_CONFIG=/usr/bin/pg_config

FROM pgvector/pgvector:pg18

COPY --from=builder /usr/lib/postgresql/18/lib/age.so \
    /usr/lib/postgresql/18/lib/
COPY --from=builder /usr/share/postgresql/18/extension/age.control \
    /usr/share/postgresql/18/extension/
COPY --from=builder /usr/share/postgresql/18/extension/age--1.7.0.sql \
    /usr/share/postgresql/18/extension/

CMD ["postgres", "-c", "shared_preload_libraries=age"]
```

Cambiamenti rispetto a PG16: base `pg16`→`pg18`, dev `16`→`18`, AGE `PG16/v1.6.0-rc0`→`PG18/v1.7.0-rc0`, path `16/`→`18/`, SQL `age--1.6.0.sql`→`age--1.7.0.sql`.

### Step A2: Build immagine PG18

```bash
docker build -f /tmp/Dockerfile.pg18 -t sol/postgres:pg18-age /tmp/
```

Se la compilazione AGE fallisce, il piano si ferma qui. Nessun impatto su PG16.

### Step A3: Avviare container di test PG18

Container isolato: porta diversa (5433), volume temporaneo, nome diverso, stessa rete `shared`.

```bash
docker run -d \
  --name postgres-pg18-test \
  --network shared \
  -p 127.0.0.1:5433:5432 \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=testpg18 \
  sol/postgres:pg18-age

# Attendere startup
docker logs postgres-pg18-test -f
# → "database system is ready to accept connections"
```

### Step A4: Test funzionali su PG18

```bash
# 1. Creare estensioni
docker exec postgres-pg18-test psql -U postgres -c "CREATE DATABASE test_embeddings;"
docker exec postgres-pg18-test psql -U postgres -d test_embeddings -c "
  CREATE EXTENSION IF NOT EXISTS vector;
  CREATE EXTENSION IF NOT EXISTS age;
  ALTER DATABASE test_embeddings SET search_path = ag_catalog, \"\\\$user\", public;"

# 2. Test AGE: creare grafo e testare MERGE su Author (il bug)
docker exec postgres-pg18-test psql -U postgres -d test_embeddings -c "
  LOAD 'age'; SET search_path = ag_catalog;
  SELECT create_graph('test_graph');"

docker exec postgres-pg18-test psql -U postgres -d test_embeddings -c "
  LOAD 'age'; SET search_path = ag_catalog;
  SELECT * FROM cypher('test_graph', \$\$ CREATE (a:Author {name: 'Test Author'}) RETURN a \$\$) AS (r agtype);"

docker exec postgres-pg18-test psql -U postgres -d test_embeddings -c "
  LOAD 'age'; SET search_path = ag_catalog;
  SELECT * FROM cypher('test_graph', \$\$ MERGE (a:Author {name: 'Test Author'}) RETURN a \$\$) AS (r agtype);"

docker exec postgres-pg18-test psql -U postgres -d test_embeddings -c "
  LOAD 'age'; SET search_path = ag_catalog;
  SELECT * FROM cypher('test_graph', \$\$ MERGE (a:Author {name: 'New Author'}) RETURN a \$\$) AS (r agtype);"

# 3. Test pgvector
docker exec postgres-pg18-test psql -U postgres -d test_embeddings -c "
  CREATE TABLE test_vectors (id serial, embedding vector(1024));
  INSERT INTO test_vectors (embedding) VALUES ('[' || array_to_string(array_agg(0.1), ',') || ']')
  FROM generate_series(1,1024);
  SELECT count(*) FROM test_vectors;"

# 4. Versione PostgreSQL
docker exec postgres-pg18-test psql -U postgres -c "SELECT version();"
```

**Criteri di successo**:
- ✅ AGE compila e si carica (`shared_preload_libraries`)
- ✅ `CREATE (a:Author ...)` funziona (bug label_id fixato)
- ✅ `MERGE (a:Author ...)` funziona (idempotente)
- ✅ pgvector extension funziona con 1024 dim

### Step A5: Cleanup container test

```bash
docker rm -f postgres-pg18-test
```

L'immagine `sol/postgres:pg18-age` resta disponibile per lo swap.

---

## Fase B: Migrazione (richiede downtime)

Eseguire solo dopo conferma Fase A. PG16 viene fermato, dati esportati, PG18 avviato, dati importati.

### Step B1: Snapshot pre-upgrade

```bash
# Conteggio righe per verifica post-restore
docker exec postgres psql -U postgres -c "
  SELECT schemaname, relname, n_live_tup
  FROM pg_stat_user_tables
  WHERE n_live_tup > 0
  ORDER BY schemaname, relname;" > /tmp/pg16_row_counts.txt

# Conteggio nodi/relazioni AGE
docker exec postgres psql -U postgres -d embeddings -c "
  LOAD 'age'; SET search_path = ag_catalog;
  SELECT * FROM cypher('knowledge_graph', \$\$ MATCH (n) RETURN labels(n)[0], count(n) \$\$) AS (label agtype, cnt agtype);" > /tmp/pg16_age_counts.txt
```

### Step B2: pg_dumpall (backup logico completo)

```bash
docker exec postgres pg_dumpall -U postgres > /tmp/pg16_full_dump.sql
ls -lh /tmp/pg16_full_dump.sql  # dimensione attesa ~50-200 MB
```

`pg_dumpall` include ruoli, permessi, tutti i 5 database, tabelle AGE (normali tabelle PG in schemi `knowledge_graph`, `code_graph`, `task_graph` + metadata `ag_catalog`).

### Step B3: Stop consumer

```bash
cd /data/massimiliano/gitea && docker compose stop gitea
cd /data/massimiliano/keycloak && docker compose stop keycloak
cd /data/massimiliano/wikijs && docker compose stop wikijs
cd /data/massimiliano/Vari/preference-sort && docker compose stop preference-sort
cd /data/massimiliano/Vari/mcp && docker compose stop simoge-mcp
cd /data/massimiliano/pgadmin && docker compose stop pgadmin
```

### Step B4: Stop PG16 e backup data directory

```bash
cd /data/massimiliano/postgres && docker compose down
mv data data-pg16-backup
```

### Step B5: Aggiornare Dockerfile e docker-compose

**Dockerfile** (`/data/massimiliano/postgres/Dockerfile`) — sovrascrivere con il contenuto di `/tmp/Dockerfile.pg18`.

**docker-compose.yml** — cambiare solo il tag immagine:
```yaml
image: sol/postgres:pg18-age   # era sol/postgres:pg16-age
```

### Step B6: Start PG18 (fresh data dir)

```bash
cd /data/massimiliano/postgres && docker compose up -d --build --force-recreate
docker logs postgres -f  # attendere "database system is ready to accept connections"
```

I 3 init scripts (01, 02, 03) girano automaticamente al primo avvio e creano: utenti, database, estensioni pgvector e AGE, 3 grafi.

### Step B7: Restore dump

```bash
docker cp /tmp/pg16_full_dump.sql postgres:/tmp/

# Restore (errori "already exists" attesi e innocui per ruoli/DB creati dagli init scripts)
docker exec postgres psql -U postgres -f /tmp/pg16_full_dump.sql 2>&1 | tee /tmp/pg18_restore.log

# Controllare errori significativi
grep -i error /tmp/pg18_restore.log | grep -v "already exists"
```

### Step B8: Verifica dati

```bash
# Confronto conteggio righe
docker exec postgres psql -U postgres -c "
  SELECT schemaname, relname, n_live_tup
  FROM pg_stat_user_tables
  WHERE n_live_tup > 0
  ORDER BY schemaname, relname;"
# → confrontare con /tmp/pg16_row_counts.txt

# Test AGE — conteggio nodi per label
docker exec postgres psql -U postgres -d embeddings -c "
  LOAD 'age'; SET search_path = ag_catalog;
  SELECT * FROM cypher('knowledge_graph', \$\$ MATCH (n) RETURN labels(n)[0], count(n) \$\$) AS (label agtype, cnt agtype);"
# → confrontare con /tmp/pg16_age_counts.txt

# Test MERGE su Author (quello che falliva su PG16)
docker exec postgres psql -U postgres -d embeddings -c "
  LOAD 'age'; SET search_path = ag_catalog;
  SELECT * FROM cypher('knowledge_graph', \$\$ MERGE (a:Author {name: 'PG18 Test'}) RETURN a \$\$) AS (r agtype);"

# Test pgvector
docker exec postgres psql -U postgres -d embeddings -c "
  SELECT count(*) FROM vector_store;"
```

### Step B9: Restart consumer (uno alla volta, con verifica)

```bash
cd /data/massimiliano/gitea && docker compose up -d
# → docker logs gitea --tail 5

cd /data/massimiliano/keycloak && docker compose up -d
# → docker logs keycloak --tail 5

cd /data/massimiliano/wikijs && docker compose up -d
cd /data/massimiliano/Vari/preference-sort && docker compose up -d
cd /data/massimiliano/Vari/mcp && docker compose up -d
cd /data/massimiliano/pgadmin && docker compose up -d
```

### Step B10: Cleanup nodo test

```bash
docker exec postgres psql -U postgres -d embeddings -c "
  LOAD 'age'; SET search_path = ag_catalog;
  SELECT * FROM cypher('knowledge_graph', \$\$ MATCH (a:Author {name: 'PG18 Test'}) DELETE a \$\$) AS (r agtype);"
```

---

## Rollback (se qualcosa va storto in Fase B)

```bash
cd /data/massimiliano/postgres && docker compose down
rm -rf data                          # PG18 data (vuoto o corrotto)
mv data-pg16-backup data             # Ripristina PG16 data
git checkout Dockerfile              # Ripristina Dockerfile PG16
# Ripristinare image tag in docker-compose.yml: sol/postgres:pg16-age
docker compose up -d --build         # Rebuild immagine PG16
# Restart tutti i consumer
```

---

## Post-upgrade

- Aggiornare `/data/massimiliano/postgres/CLAUDE.md`: PG16 → PG18, AGE 1.6.0 → 1.7.0
- Aggiornare `/data/massimiliano/docs/vector-db-strategy.md`: tabella "Stato Attuale" PG16 → PG18
- Aggiornare CLAUDE.md root: `sol/postgres:pg16-age` → `sol/postgres:pg18-age`
- Rimuovere workaround raw SQL da `paper_archive.py` (righe ~627-642) e ripristinare Cypher MERGE per Author
- Stesso per `import_kindle.py` (riga ~213) e `import_rationalist.py` (riga ~789)
- Rimuovere immagini test: `docker rmi sol/postgres:pg18-age-test sol/postgres:pg17-age-test` (se esistono)
- Eliminare `/tmp/Dockerfile.pg18`
- Eliminare `data-pg16-backup/` dopo 3-5 giorni di stabilità

## File critici

| File | Azione |
|------|--------|
| `/data/massimiliano/postgres/Dockerfile` | Sovrascrivere con PG18 (Step B5) |
| `/data/massimiliano/postgres/docker-compose.yml` | Cambiare image tag (Step B5) |
| `/data/massimiliano/kindle/paper_archive.py` | Rimuovere workaround raw SQL Author (post-upgrade) |
| `/data/massimiliano/kindle/import_kindle.py` | MERGE Author già presente — funzionerà dopo upgrade |
| `/data/massimiliano/kindle/import_rationalist.py` | MERGE Author già presente — funzionerà dopo upgrade |
| `/data/massimiliano/postgres/CLAUDE.md` | Aggiornare versioni (post-upgrade) |
| `/data/massimiliano/CLAUDE.md` | Aggiornare image tag (post-upgrade) |
| `/data/massimiliano/docs/vector-db-strategy.md` | Aggiornare PG version (post-upgrade) |
