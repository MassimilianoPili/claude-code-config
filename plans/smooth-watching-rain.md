# Plan: Auto-sync task → Preference Sort

## Context

`claude_task_enqueue` scrive in PostgreSQL + Redis ma **non registra** il task in Preference Sort.
Serve `claude-coord rank-sync` manuale. L'utente vuole che sia automatico: enqueue → appare nel ranker, complete → sparisce dal ranker.

## Approccio

Aggiungere la logica Preference Sort direttamente in `ClaudeTaskQueueTools.java`, in due punti:

### 1. Auto-register on enqueue (`claudeTaskEnqueue`)

Dopo il dual-write PostgreSQL+Redis, aggiungere:

1. **Find or create** la lista `task-queue` in Preference Sort (`GET /lists?limit=100`, filtra `category=task-queue`, se manca `POST /lists`)
2. **Add item** con nome `#<taskId> <ref> [<type>]` (`POST /lists/<uuid>/items`)
3. **Salvare** `rank_item_uuid` nel DB (`UPDATE claude_tasks SET rank_item_uuid = ? WHERE task_id = ?`)

Best-effort (come Redis): se Preference Sort è down, il task resta in DB senza ranking. Log warn.

### 2. Auto-remove on complete (`claudeTaskComplete`)

Dopo l'UPDATE status, aggiungere:

1. **Leggere** `rank_item_uuid` dal DB per il task completato
2. Se presente, **DELETE** l'item da Preference Sort (`DELETE /lists/<uuid>/items/<item_uuid>`)
3. **Nullificare** `rank_item_uuid` nel DB

Best-effort: se fallisce, `rank-sync` cleanup lo pulirà dopo.

### 3. Helper method privato

Estrarre la logica comune in metodi privati:
- `findOrCreateTaskQueueList()` → restituisce list UUID (riusa la logica già in `claudeTaskListRanked`)
- `addItemToRanking(listUuid, taskId, ref, taskType)` → POST item, salva UUID
- `removeItemFromRanking(taskId)` → leggi UUID dal DB, DELETE, nullifica

### Costanti/config

- `RANK_API = "http://preference-sort:8093"` (Docker DNS, già usato in `claudeTaskListRanked` linea 221)
- `RANK_USER = "f7294891-b031-432d-8382-8592d3e6b1aa"` (già hardcodato linea 222)
- `HttpClient` — riusare istanza (o crearne una a livello di classe)

## File da modificare

- `/data/massimiliano/Vari/mcp/src/main/java/com/example/mcp/tools/ClaudeTaskQueueTools.java` — unico file

## Verifica

1. `sol deploy mcp`
2. `claude_task_enqueue(ref="test-auto", taskType="test", payloadJson='{"task":"test auto-sync"}', createdBy="chat-143")`
3. Verificare: `rank-tui` o `curl -s -H "X-Auth-User-Id: f7294891..." http://127.0.0.1:8093/lists?limit=100` → task visibile
4. `claude_task_claim` + `claude_task_complete` → verificare che sparisce dal ranker
5. `claude_task_list("RANKED")` → deve mostrare i task registrati
