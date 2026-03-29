# Task Queue → Plan File Pointers

## Context
Ogni task nella coda (`claude_tasks`) deve avere un puntatore opzionale a un plan file, così che:
1. Si può enqueue un task con un piano strutturato allegato
2. Chi claims il task trova subito il piano da seguire
3. Si possono cercare task per contenuto del piano (via embeddings già esistenti)
4. Il workflow è asincrono: enqueue + plan → qualcuno lo raccoglie dopo

**Stato attuale**: La tabella ha `wiki_page_path` come precedente per riferimenti esterni, ma nessun campo per plan files. I plan files vivono in `/home/massimiliano/.claude/plans/`.

---

## Fase 1: Schema DB (1 ALTER TABLE)

**File**: migration in `task-ui/tasks.go` (funzione `RunMigrations`, ~riga 789)

```sql
ALTER TABLE ag_catalog.claude_tasks
  ADD COLUMN IF NOT EXISTS plan_file_path VARCHAR(500);

CREATE INDEX IF NOT EXISTS idx_claude_tasks_plan
  ON ag_catalog.claude_tasks (plan_file_path)
  WHERE plan_file_path IS NOT NULL;
```

Idempotente, eseguito al boot di task-ui.

---

## Fase 2: MCP Tool — `claude_task_enqueue`

**File**: `/data/massimiliano/Vari/mcp-claude-queue-tools/src/main/java/io/github/massimilianopili/mcp/queue/ClaudeTaskQueueTools.java`

1. Aggiungere parametro opzionale `planFile` a `claudeTaskEnqueue`
2. Includere `plan_file_path` nell'INSERT SQL
3. In `claudeTaskClaim`: includere `plan_file_path` nel RETURNING → l'agente che claims vede subito il path
4. In `claudeTaskList`: mostrare indicatore `[plan]` nei task che hanno un piano

---

## Fase 3: Task UI Backend

**File**: `/data/massimiliano/task-ui/tasks.go`

1. Aggiungere `PlanFilePath *string` al struct `Task`
2. Aggiornare SELECT/Scan in `ListTasks`, `GetTask`
3. Aggiungere `PlanFilePath` a `CreateTaskReq` + INSERT
4. Nuovo endpoint `GET /api/tasks/{id}/plan`:
   - Legge il file dal disco, ritorna `text/markdown`
   - Path traversal guard: solo paths sotto `.claude/plans/`
   - 404 se file non esiste, 204 se task senza plan

**File**: `/data/massimiliano/task-ui/main.go` — registrare la nuova route

---

## Fase 4: Task UI Frontend

**File**: `/data/massimiliano/task-ui/static/index.html`

1. Sezione "Plan" nel detail panel (dopo Payload, prima di Dependencies)
   - Mostra path del file
   - Toggle "Show/Hide" che fetcha il contenuto on-demand
2. Nel form "New Task": campo opzionale per plan file path
3. Nel DAG: indicatore visivo (dot/icona) sui nodi con plan

---

## Fase 5: Ricerca

Nessuna infrastruttura nuova. Pipeline esistente:
1. `embeddings_search_docs("keywords")` → trova plan file path
2. `db_query("SELECT task_id, ref FROM ag_catalog.claude_tasks WHERE plan_file_path LIKE '%filename%'")` → collega al task

L'indice parziale (Fase 1) rende la query veloce.

---

## File da modificare

| File | Modifica | Effort |
|------|----------|--------|
| `task-ui/tasks.go` | Campo, query, migration, endpoint | Medio |
| `task-ui/main.go` | Registrazione route | Triviale |
| `task-ui/static/index.html` | Sezione plan, toggle, campo new task | Piccolo |
| `mcp-claude-queue-tools/.../ClaudeTaskQueueTools.java` | Parametro, INSERT/SELECT | Piccolo |

~100 righe nuove, ~20 modificate. Nessuna nuova dipendenza. Nessun container nuovo.

---

## Stato implementazione

| Fase | Stato | Note |
|------|-------|------|
| 1. Schema DB | DONE | Colonna + indice live, verificati via query |
| 2. MCP Tool | DONE (codice) | Lib 0.1.1 pubblicata su Gitea registry |
| 3. Task UI Backend | DONE | Container ricostruito e in esecuzione |
| 4. Task UI Frontend | DONE | Plan section, toggle, DAG indicator, new task field |
| 5. Deploy simoge-mcp | BLOCCATO | Vedi sotto |

---

## ERRORE TDT: Maven cache poisoning

**Cosa è successo**: `docker compose build --no-cache simoge-mcp` ha eseguito `mvn dependency:resolve` senza la cache M2 che conteneva `mcp-vector-tools:0.5.0` e `mcp-search-tools:0.2.0`. Questi artifact non sono mai stati pubblicati su Gitea registry (sono dalla refactoring recente, Fase 6 pending). Maven ha quindi scritto **failure markers** nella cache mount persistente (`mcp-server-m2`). Ora anche i build normali (con cache) falliscono perché Maven rifiuta di riprovare.

**Impatto**: Il container MCP corrente è ancora attivo (vecchia versione). Il servizio funziona. Ma non si può ricostruire il container finché non si ripara la cache.

### Fix: Ripristinare la build MCP

**Risultato indagine**: La cache mount `mcp-server-m2` e' stata completamente svuotata dal `--no-cache` (non solo poisoned — azzerata a 4KB). Gli artifact custom esistono solo nella `.m2` dell'host.

**Approccio corretto (TDT)**: Pubblicare le lib mancanti su Gitea registry.

Il build dipendeva da stato locale (.m2 dell'host) — se tutti costruissero così, nessun CI/CD funzionerebbe. La fix corretta è rendere il build autosufficiente: tutte le dipendenze devono essere nel registry.

### Lib da pubblicare

1. `mcp-vector-tools:0.5.0` — dir: `/data/massimiliano/Vari/mcp-vector-tools/`
2. `mcp-search-tools:0.2.0` — dir: `/data/massimiliano/Vari/mcp-search-tools/`

Per ciascuna:
1. Verificare che il repo Gitea esista e abbia CI (`deploy-gitea.yml` con tag `g*`)
2. Se non esiste, fare deploy manuale via Maven al Gitea registry (usando l'URL via nginx/Tailscale)
3. Verificare con `gitea_check_registry`

### Sequenza corretta (TDT: non comporre errori)

La pubblicazione delle lib mancanti e' un **task separato**, non un fix emergenziale durante il deploy di plan_file_path.

1. **Ora**: Creare un task nella coda per pubblicare le lib mancanti
2. **Ora**: Cleanup `/tmp/m2-seed/`
3. **Prossima sessione**: Pubblicare `mcp-vector-tools:0.5.0` + `mcp-search-tools:0.2.0` su Gitea
4. **Dopo la pubblicazione**: `docker compose build simoge-mcp` + deploy → include queue-tools 0.1.1

Il servizio MCP corrente funziona. Non ha il parametro `planFile`, ma il task-ui e' gia' operativo e la colonna DB e' pronta. Il parametro MCP sara' attivo al prossimo deploy.

---

## Verifica end-to-end (dopo deploy MCP)

1. `db_query(...)` → colonna `plan_file_path` ✓ (già verificata)
2. `claude_task_enqueue(ref="test-plan", taskType="test", payloadJson="{}", createdBy="test", planFile="/home/massimiliano/.claude/plans/stateful-exploring-pudding.md")` → task con plan
3. `claude_task_list(status="PENDING")` → `[plan]` indicator
4. Task UI: click sul task → sezione Plan visibile → toggle mostra contenuto
5. `claude_task_claim(taskId=<id>, claimedBy="test")` → output include plan path
