# Piano: Aggiornare descrizioni tool MCP graph_query e graph_write

## Context

Il tool MCP wrappa automaticamente il Cypher in `SELECT * FROM cypher('knowledge_graph', $$ ... $$)`. Claude duplicava il wrapper causando errori. Inoltre AGE non supporta commenti `//` nel Cypher e le query multi-statement vanno spezzate. Le descrizioni dei tool devono chiarire queste regole.

## File da modificare

`/data/massimiliano/Vari/mcp-graph-tools/src/main/java/io/github/massimilianopili/mcp/graph/GraphTools.java`

## Modifiche

### 1. `graph_query` (riga 29-32) — aggiornare description

Da:
```
"Esegui query Cypher in sola lettura sul graph database. "
+ "Usa per MATCH, RETURN, COUNT, path traversal. "
+ "Supporta backend neo4j e age (Apache AGE su PostgreSQL)."
```

A:
```
"Esegui query Cypher in sola lettura sul graph database. "
+ "Usa per MATCH, RETURN, COUNT, path traversal. "
+ "Supporta backend neo4j e age (Apache AGE su PostgreSQL). "
+ "IMPORTANTE: passare solo Cypher puro (es. MATCH (n) RETURN n) — il wrapper SQL viene aggiunto automaticamente. "
+ "Non usare commenti // nel Cypher. Per AGE usare RETURN {k: v} map syntax."
```

### 2. `graph_write` (riga 58-61) — aggiornare description

Da:
```
"Esegui mutazione Cypher sul graph database. "
+ "Usa per CREATE, MERGE, SET, DELETE, DETACH DELETE. "
+ "ATTENZIONE: questa operazione modifica i dati."
```

A:
```
"Esegui mutazione Cypher sul graph database. "
+ "Usa per CREATE, MERGE, SET, DELETE, DETACH DELETE. "
+ "ATTENZIONE: questa operazione modifica i dati. "
+ "IMPORTANTE: passare solo Cypher puro — il wrapper SQL viene aggiunto automaticamente. "
+ "Non usare commenti //. Query complesse con MERGE+MATCH multipli vanno spezzate in chiamate separate."
```

## Verifica

1. Build: `cd /data/massimiliano/Vari/mcp-graph-tools && mvn clean install -DskipTests`
2. Redeploy MCP: `deploy-mcp`
3. Verificare descrizione aggiornata: chiamare `graph_query` e controllare la description nel tool schema
