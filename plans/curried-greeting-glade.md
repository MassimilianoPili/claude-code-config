# Fix claude_task_list LIMIT 50

## Context
Il tool MCP `claude_task_list` ha un `LIMIT 50` hardcoded nella query SQL (riga 259 di ClaudeTaskQueueTools.java). Questo tronca silenziosamente i risultati — l'utente ha ~200 task e non riesce a vederli tutti.

## Modifica

**File**: `/data/massimiliano/Vari/mcp/src/main/java/com/example/mcp/tools/ClaudeTaskQueueTools.java`

1. **Aggiungere parametro `limit`** al metodo `claudeTaskList`:
   ```java
   @ToolParam(description = "Max results (default 200)", required = false) Integer limit
   ```

2. **Usare il parametro nella query** (default 200, cap massimo 500):
   ```java
   int maxRows = (limit != null && limit > 0) ? Math.min(limit, 500) : 200;
   ```
   Sostituire `LIMIT 50` con `LIMIT " + maxRows`.

3. **Aggiungere conteggio totale** nel header per sapere se ci sono altri risultati:
   - Query COUNT prima della query principale: `SELECT count(*) FROM claude_tasks WHERE ...`
   - Header: `=== 47 di 194 task PENDING ===` (o `=== 194 task ALL ===` se non troncato)

## Verifica
- `sol deploy mcp`
- Chiamare `claude_task_list(status="ALL")` e verificare che mostri >50 task
- Chiamare `claude_task_list(status="ALL", limit=10)` e verificare che mostri 10 con conteggio totale
