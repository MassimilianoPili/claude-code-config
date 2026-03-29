# Piano: Rinomina grafo AGE da `rationalist_graph` a `knowledge_graph`

## Contesto

Il grafo Apache AGE che raccoglie concetti, fonti e autori razionalisti si chiama `rationalist_graph`
nel database `embeddings` (container `postgres` condiviso). L'utente vuole rinominarlo in `knowledge`
per ampliarne il perimetro semantico a contenuto più generico.

Si usa `knowledge_graph` (con suffisso `_graph`) per coerenza con la naming convention del sistema
(`code_graph`, `task_graph` nell'agent-framework). Il nome UI sarà semplicemente "Knowledge".

**Nessun conflitto** con l'agent-framework: il suo `knowledge_graph` vive in un'istanza PostgreSQL
separata (`agentfw-postgres`, database `agentframework`).

## File coinvolti

| File | Tipo modifica |
|------|---------------|
| `knowledge-graph/.env` | `AGE_GRAPH=rationalist_graph` → `knowledge_graph` |
| `knowledge-graph/main.go` | default hardcoded `"rationalist_graph"` → `"knowledge_graph"` |
| `knowledge-graph/static/index.html` | label UI `"Rationalist"` → `"Knowledge"` |
| `knowledge-graph/age.go` | commenti "rationalist" → "knowledge" |
| `knowledge-graph/README.md` | docs aggiornate |

Tutti in `/data/massimiliano/knowledge-graph/`.

## Step 1 — Rinomina il grafo in PostgreSQL AGE

```bash
docker exec -i postgres psql -U postgres -d embeddings <<'SQL'
LOAD 'age';
SET search_path = ag_catalog, "$user", public;

-- 1. Rinomina lo schema PostgreSQL del grafo (OID resta lo stesso)
ALTER SCHEMA "rationalist_graph" RENAME TO "knowledge_graph";

-- 2. Aggiorna il catalog AGE (solo il campo name, namespace è OID invariato)
UPDATE ag_catalog.ag_graph
   SET name = 'knowledge_graph'
 WHERE name = 'rationalist_graph';

-- Verifica
SELECT name, namespace FROM ag_catalog.ag_graph;
SQL
```

## Step 2 — Aggiornare `.env`

`AGE_GRAPH=rationalist_graph` → `AGE_GRAPH=knowledge_graph`

## Step 3 — Aggiornare `main.go` (default fallback)

Riga ~53: `ageGraph = "rationalist_graph"` → `ageGraph = "knowledge_graph"`

## Step 4 — Aggiornare `static/index.html` (label UI)

- `name==='neo4j'?'Kindle':'Rationalist'` → `name==='neo4j'?'Kindle':'Knowledge'`
- Qualsiasi altra occorrenza testuale "Rationalist" nella UI

## Step 5 — Aggiornare commenti in `age.go` e `README.md`

Commenti descrittivi: "rationalist knowledge graph" → "knowledge graph".

## Step 6 — Rebuild e restart container

```bash
cd /data/massimiliano/knowledge-graph
docker compose build
docker compose up -d --force-recreate
```

## Verifica

```bash
# 1. Grafo rinominato nel DB
docker exec postgres psql -U postgres -d embeddings \
  -c "LOAD 'age'; SET search_path=ag_catalog; SELECT name FROM ag_graph;"

# 2. Container up e healthy
docker logs knowledge-graph --tail 20

# 3. API risponde con dati dal grafo
curl -s http://100.86.46.84:8891/api/age/stats  # (con JWT header in produzione)
```
