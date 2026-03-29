# Piano: Migrazione Embedding → qwen3-embedding:8b (4096 dim)

## Context

Migrazione del modello di embedding da `mxbai-embed-large` (1024 dim) a `qwen3-embedding:8b` (4096 dim).
GPU esterna Gaia (RTX 3090) via proxy socat trasparente.

**Stato attuale** (parzialmente eseguito):
- ✅ DDL: indice HNSW droppato, colonna `vector_store.embedding` → `vector(4096)`, tutti i vettori NULL
- ✅ `embed_anki.py` → `PIPELINE_VERSION=2`, `EMBED_MODEL="qwen3-embedding:8b"`, spostato in `/data/massimiliano/anki/`
- ✅ `anki-embed.service` → venv `/data/massimiliano/anki/venv/`, `TimeoutStartSec=7200`
- ✅ `Vari/mcp/docker-compose.yml` → `qwen3-embedding:8b`, `4096`
- ✅ `TextSplitter.java` → `CHUNK_VERSION=2`
- ✅ Build Maven: mcp-vector-tools + simoge-mcp compilati

**Bloccante**: HNSW max 2000 dim su pgvector 0.8.2 (immagine Docker `pgvector/pgvector:pg18` ha shared objects con limite vecchio). Serve ricompilare pgvector da sorgente nel Dockerfile.

## Fase rimanente: Ricompilare pgvector nel Dockerfile

### Problema

`pgvector/pgvector:pg18` include pgvector precompilato con HNSW max 2000 dim. pgvector 0.8.2 da sorgente supporta 4000 dim.

### Soluzione

Modificare `/data/massimiliano/postgres/Dockerfile`: aggiungere build pgvector da sorgente (tag `v0.8.2`) nello stage builder, sovrascrivendo la versione preinstallata.

File: `/data/massimiliano/postgres/Dockerfile`

```dockerfile
# PostgreSQL 18 con pgvector (da sorgente) + Apache AGE v1.7.0-rc0
# pgvector: compilato da sorgente (v0.8.2) per sbloccare HNSW 4000 dim
# AGE: compilato da sorgente (PG18/v1.7.0-rc0)

# ---- Stage 1: compilazione pgvector + AGE ----
FROM pgvector/pgvector:pg18 AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential flex bison postgresql-server-dev-18 git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# pgvector da sorgente (sblocca HNSW 4000 dim)
RUN git clone --depth 1 --branch v0.8.2 \
    https://github.com/pgvector/pgvector.git /tmp/pgvector && \
    cd /tmp/pgvector && \
    make PG_CONFIG=/usr/bin/pg_config && \
    make install PG_CONFIG=/usr/bin/pg_config

# AGE da sorgente
RUN git clone --depth 1 --branch PG18/v1.7.0-rc0 \
    https://github.com/apache/age.git /tmp/age && \
    cd /tmp/age && \
    make PG_CONFIG=/usr/bin/pg_config && \
    make install PG_CONFIG=/usr/bin/pg_config

# ---- Stage 2: immagine finale ----
FROM pgvector/pgvector:pg18

# Sovrascrivere pgvector preinstallato con versione compilata
COPY --from=builder /usr/lib/postgresql/18/lib/vector.so \
    /usr/lib/postgresql/18/lib/
COPY --from=builder /usr/share/postgresql/18/extension/vector* \
    /usr/share/postgresql/18/extension/

# AGE
COPY --from=builder /usr/lib/postgresql/18/lib/age.so \
    /usr/lib/postgresql/18/lib/
COPY --from=builder /usr/share/postgresql/18/extension/age.control \
    /usr/share/postgresql/18/extension/
COPY --from=builder /usr/share/postgresql/18/extension/age--1.7.0.sql \
    /usr/share/postgresql/18/extension/

CMD ["postgres", "-c", "shared_preload_libraries=age"]
```

### Dopo il rebuild

```bash
cd /data/massimiliano/postgres && docker compose up -d --build --force-recreate
```

**Nota**: il rebuild del container postgres NON cancella i dati (volume persistente). Lo schema e i dati restano intatti. La nuova versione di pgvector (shared objects) viene caricata al restart.

Dopo il restart, verificare:
```bash
docker exec postgres psql -U postgres -d embeddings -c "
CREATE TEMP TABLE test_hnsw (id serial, emb vector(4096));
CREATE INDEX ON test_hnsw USING hnsw (emb vector_cosine_ops);
DROP TABLE test_hnsw;
"
```

### Poi: deploy MCP + reindex

1. `sol deploy mcp` — Spring AI ricrea `spring_ai_vector_index` HNSW su `vector(4096)`
2. `embeddings_reindex("all")` — rigenera ~15K vettori docs/conversations
3. Timer notturno rigenera ~17K vettori Anki (convergenza 3-4 notti)

## File da modificare

| File | Modifica | Stato |
|------|----------|-------|
| `postgres/Dockerfile` | Aggiungere build pgvector da sorgente | ❌ DA FARE |
| `anki/embed_anki.py` | `PIPELINE_VERSION=2`, `EMBED_MODEL` | ✅ FATTO |
| `anki-embed.service` | venv `anki/`, TimeoutStartSec | ✅ FATTO |
| `Vari/mcp/docker-compose.yml` | model + dimensions | ✅ FATTO |
| `Vari/mcp-vector-tools/.../TextSplitter.java` | `CHUNK_VERSION=2` | ✅ FATTO |
| `postgres/init/02-embeddings.sh` | `vector(4096)` | ❌ DA FARE |

## Pulizia post-migrazione

1. `rm /data/massimiliano/kindle/embed_anki.py` + `rm -rf /data/massimiliano/kindle/venv/` (manuale)
2. `paper_archive.py` — verificare se usa embedding, cambio modello
3. Memory `project_embeddings.md` — aggiornare modello e dimensioni
4. CLAUDE.md mcp-vector-tools — già aggiornato

## Verifica finale

1. `CREATE INDEX ... USING hnsw ... vector(4096)` → successo (conferma pgvector ricompilato)
2. `embeddings_search("test query")` → risultati con vettori 4096
3. `python3 anki/embed_anki.py --dry-run` → tutte le note marcate per re-embed
4. Dopo 1 notte: `SELECT count(*) FROM vector_store WHERE metadata->>'pipeline_version'='2';`
5. `embeddings_stats` → conteggi e stato reindex
