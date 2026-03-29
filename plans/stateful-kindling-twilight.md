# Switch embedding model: mxbai-embed-large → qwen3-embedding:8b (4096 dim)

## Context

Con la GPU 3090 su gaia operativa, si passa al modello `qwen3-embedding:8b` (7.6B params, 4096 dim native) e si rimuovono `mxbai-embed-large` e `qwen3-embedding:0.6b`. Il reindex in corso va fermato, gli embedding esistenti (1024 dim) sono incompatibili e vanno cancellati.

**Nessun troncamento MRL** — si usano le 4096 dimensioni native. Serve solo aggiornare la configurazione e ricreare la tabella pgvector.

## Passi

### 1. Fermare il reindex in corso
```bash
cd /data/massimiliano/Vari/mcp && docker compose restart simoge-mcp
```

### 2. Rimuovere modelli da gaia
```bash
curl -X DELETE http://100.109.3.40:11434/api/delete -d '{"model":"mxbai-embed-large"}'
curl -X DELETE http://100.109.3.40:11434/api/delete -d '{"model":"qwen3-embedding:0.6b"}'
```

### 3. Svuotare embedding e sync (dimensioni incompatibili 1024→4096)

Collegarsi a postgres e:
```sql
-- Ricreare tabella con nuove dimensioni (PgVectorStore.initializeSchema farà il resto)
DROP TABLE IF EXISTS vector_store;
-- Reset sync tracker
UPDATE embeddings_sync SET last_indexed = NULL, chunk_version = 0;
```

### 4. Aggiornare docker-compose.yml

**File**: `/data/massimiliano/Vari/mcp/docker-compose.yml`

Cambiare:
```yaml
MCP_VECTOR_OLLAMA_MODEL: qwen3-embedding:8b      # era: mxbai-embed-large
MCP_VECTOR_DIMENSIONS: "4096"                     # era: "1024"
```

### 5. Build e deploy

```bash
cd /data/massimiliano/Vari/mcp && /opt/maven/bin/mvn clean install -Dgpg.skip=true
docker compose up -d --build
```
PgVectorStore con `initializeSchema(true)` ricreerà la tabella `vector_store` a 4096 dim + indice HNSW.

### 6. Reindex completo
```bash
curl -X POST http://localhost:8099/admin/reindex/all
```

## File coinvolti

| File | Azione |
|------|--------|
| `Vari/mcp/docker-compose.yml` | Cambiare modello + dimensioni |
| Database `embeddings` | DROP vector_store + reset sync |

Nessuna modifica al codice Java — solo configurazione.

## Verifica

1. Log startup: `Embedding provider: Ollama, model: qwen3-embedding:8b` + `PgVectorStore: 4096 dim`
2. `curl http://100.109.3.40:11434/api/tags` — non mostra più mxbai-embed-large né qwen3-embedding:0.6b
3. `embeddings_stats()` — reindex in corso, chunk count crescente
4. `embeddings_search_docs("test")` — restituisce risultati con i nuovi embedding

## Note

- Il reindex completo di ~2000 file con qwen3-embedding:8b su GPU sarà più lento di mxbai-embed-large (7.6B vs 334M), ma la GPU 3090 dovrebbe gestirlo
- Il context length di 40960 token (vs 512 di mxbai) dovrebbe risolvere gli errori "input length exceeds context length" sui file JSONL grossi
- Lo spazio su pgvector cresce 4x (4096 vs 1024 float per vettore), ma con ~15000 chunk è trascurabile (~230MB vs ~58MB)
