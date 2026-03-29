# Sito CPS v4 via Agent-Framework (con Claude Opus 4.6)

## Contesto

Ripresa dopo esaurimento token API. Il lavoro infrastrutturale e' completo:
**CompactingToolCallingManager** testato con successo (9 compaction, 257 tool call, zero
context overflow). AI-001 ha fallito per esaurimento token API, non per bug del codice.

Tutti i processi sono giu' (orchestrator + 3 worker). AI-001 bloccato in DISPATCHED nel DB.

**Nota**: l'utente ha modificato configurazioni del client (anthropic-api-proxy o simili).
Procedere con reinstallazione worker-sdk e rilancio completo della pipeline.

### Stato completamento

- [x] 6 manifest YAML creati e compilati
- [x] Root pom.xml + orchestrator application.yml aggiornati
- [x] `mvn clean compile` OK (24 moduli)
- [x] Audit CPS v3 completato, `cps4/` creata come copia di `cps3/`
- [x] Fase A: model upgrade a opus (manifest + orchestrator)
- [x] Fase A-bis: planner prompt + PlanItemSchema con 11 profili
- [x] Fase B-fix: rimosso schema conflittuale, rafforzato system prompt
- [x] Fase B: spec composta, piano sottomesso (9 task, plan `60e1e42b`)
- [x] HookPolicyResolver tool allowlists (Claude Code → nomi MCP + fs_grep)
- [x] mcp-filesystem-tools: fs_read chunked (offset/limit), fs_grep aggiunto
- [x] CompactingToolCallingManager implementato e testato (worker-sdk installato)
- [x] SKILL.md ai-task aggiornata per audit (non piu' test generator)
- [x] BeanPostProcessor reso `static` (fix warning Spring)
- [x] Fix mcp-filesystem-tools versione 0.0.1 → 0.1.0 (aggiunto fs_write + fs_grep)
- [x] Fix findOpenAttempt query (non-unique result → ORDER BY DESC LIMIT 1)
- [x] Rilancio pipeline: tutti i 9 task completati con successo!

## RISULTATO FINALE — Piano CPS v4 COMPLETATO

| Task | Stato | Tempo | Tool calls | Risultato |
|------|-------|-------|------------|-----------|
| AI-001 | DONE | 96s | 22 | 6137 chars (audit) |
| FE-001 | DONE | 239s | 46 | 2530 chars (Self-host Fonts) |
| FE-002 | DONE | 312s | ~30 | 3769 chars (SVG icons) |
| FE-003 | DONE | 67s | ~28 | 3527 chars (SVG placeholder) |
| FE-004 | DONE | 283s | ~30 | 3632 chars (contenuto) |
| FE-005 | DONE | 159s | ~20 | 2584 chars (performance) |
| FE-006 | DONE | 207s | ~22 | 2052 chars (responsive) |
| AI-002 | DONE | - | - | 3493 chars (cross-cutting) |
| RV-001 | DONE | - | - | 8775 chars (review finale) |

**Totale**: ~25 min, 220+ tool call, 0 compaction, 0 errori fatali.
Bug non bloccante: QualityGateService 401 (auth mancante verso Anthropic).

## File chiave (nuovi/modificati in questa sessione)

```
execution-plane/worker-sdk/src/main/java/.../claude/CompactingToolCallingManager.java    (NUOVO)
execution-plane/worker-sdk/src/main/java/.../config/CompactingToolCallingManagerPostProcessor.java (NUOVO)
execution-plane/worker-sdk/src/main/java/.../config/WorkerAutoConfiguration.java         (aggiunto bean static)
control-plane/orchestrator/src/main/java/.../hooks/HookPolicyResolver.java               (allowlists MCP)
.claude/agents/ai-task/SKILL.md                                                          (riscritto per audit)
agents/manifests/*.agent.yml (x22)                                                       (aggiunto fs_grep)
```

```
agents/manifests/fe-vanillajs.agent.yml           (manifest da aggiornare: model → opus)
execution-plane/workers/fe-vanillajs-worker/src/main/resources/application.yml  (generato, model)
execution-plane/agent-compiler-maven-plugin/src/main/resources/templates/application.yml.mustache
Vari/anthropic-api-proxy/main.go                  (catalogo modelli, opus = Tier 3)
/data/massimiliano/Vari/MassimilianoPili.github.io/cps4/  (target)
```

---

## Fase A — Upgrade modello a Claude Opus 4.6

### A.1 Aggiornare manifest `fe-vanillajs.agent.yml`

Cambiare `spec.model.name` da `claude-sonnet-4-6` a `claude-opus-4-6`:

```yaml
spec:
  model:
    name: claude-opus-4-6       # era: claude-sonnet-4-6
    maxTokens: 16384
    temperature: 0.2
```

### A.2 Rigenerare il worker

**NOTA**: il plugin risolve `manifestDirectory` relativo al modulo, non al root. Servono path assoluti:

```bash
cd /data/massimiliano/agent-framework
mvn -pl execution-plane/agent-compiler-maven-plugin \
    com.agentframework:agent-compiler-maven-plugin:generate-workers \
    -DagentCompiler.manifestDirectory=/data/massimiliano/agent-framework/agents/manifests \
    -DagentCompiler.outputDirectory=/data/massimiliano/agent-framework/execution-plane/workers
```

Questo rigenera `fe-vanillajs-worker/src/main/resources/application.yml` con
`model: claude-opus-4-6` nel blocco `spring.ai.anthropic.chat.options`.

### A.3 Ricompilare

```bash
mvn -pl execution-plane/workers/fe-vanillajs-worker compile
```

### A.4 Fix modello orchestrator (planner)

L'orchestrator non specificava un modello esplicito → Spring AI usava il default
`claude-3-7-sonnet-latest` (deprecato, causa 404 dal proxy).
Fix: `spring.ai.anthropic.chat.options.model: claude-opus-4-6` in application.yml.

### A.5 Nota architetturale

Attualmente il modello e' **statico** (manifest YAML → codegen → application.yml).
L'orchestrator NON sceglie il modello: `AgentTask` non ha un campo `model`.
In un secondo step (Fase E) pianifichiamo il supporto per model selection dinamica per-task.

---

## Fase A-bis — Aggiornare il planner prompt con i nuovi profili

**Scoperta critica**: il prompt del planner (`plan_tasks.prompt.md`) e lo schema
(`PlanItemSchema.java`) elencano solo 5 profili (be-java, be-go, be-rust, be-node, fe-react).
Senza aggiornarli, Claude defaultera' a `fe-react` per i task FE del CPS.

### A-bis.1 `plan_tasks.prompt.md` (riga 37-43)

Aggiungere alla tabella Worker Profiles:

```
| `be-quarkus` | `BE` | Java / Quarkus |
| `be-laravel` | `BE` | PHP / Laravel |
| `be-cpp` | `BE` | C++ / CMake |
| `fe-vanillajs` | `FE` | Vanilla HTML5, CSS, JavaScript (no frameworks) |
| `fe-angular` | `FE` | Angular / TypeScript |
| `fe-svelte` | `FE` | Svelte / SvelteKit |
```

Aggiornare anche le regole di selezione (riga 46-47).

**Stato**: GIA' MODIFICATO nella sessione corrente.

### A-bis.2 `PlanItemSchema.java` (riga 27-29)

Aggiornare la `@JsonPropertyDescription` del campo `workerProfile`:

```java
@JsonPropertyDescription("Worker profile selecting the concrete technology stack. "
    + "Examples: be-java, be-go, be-rust, be-node, be-quarkus, be-laravel, be-cpp, "
    + "fe-react, fe-vanillajs, fe-angular, fe-svelte. "
    + "Null for non-implementation tasks (AI_TASK, CONTRACT, REVIEW)")
```

### A-bis.3 Ricompilare orchestrator e riavviarlo

```bash
mvn -pl control-plane/orchestrator compile
# Kill orchestrator in esecuzione, poi riavviare
mvn -pl control-plane/orchestrator spring-boot:run &
```

---

## Fase B-fix — Fix structured output planner (CSS instead of JSON)

### Problema

Al primo tentativo di sottomissione, Claude Opus ha restituito **codice CSS** invece di un JSON plan.
`BeanOutputConverter` ha lanciato `JsonParseException: Unrecognized token 'css'`.

### Root cause: conflitto triplo nelle istruzioni di schema

Il planner riceve **tre** istruzioni contraddittorie sull'output format:

| Fonte | Campo array | Ha `ordinal`? | Ha `id`/`status`? |
|-------|-------------|---------------|-------------------|
| `plan_tasks.prompt.md` (righe 96-170) | `items` | Si | Si |
| `BeanOutputConverter<PlanSchema>` | `tasks` | No | No |
| `planner.agent.md` (system prompt) | non specificato | - | - |

La Java record `PlanSchema` ha `summary` + `tasks`, ma il prompt template mostra un esempio
con `id`, `status`, `items`, `createdAt`, `ordinal`. Sono due schemi diversi.

`BeanOutputConverter.getFormat()` viene appendato al user prompt (PlannerService.java:56):
```java
.user(userPrompt + "\n\n" + converter.getFormat())
```
Questo causa un secondo schema in fondo al prompt che contraddice l'esempio sopra.

### Fix B-fix.1 — Rimuovere sezioni conflittuali da `plan_tasks.prompt.md`

**File**: `control-plane/orchestrator/src/main/resources/prompts/plan_tasks.prompt.md`

Rimuovere le righe 95-170 (sezioni "Output Format", "Schema Reference", "Constraints").
Lasciare che `BeanOutputConverter` sia l'unica fonte di verita' per lo schema JSON.

Mantenere invece le righe 1-93 (Input Specification, Worker Types, Worker Profiles, Planning Rules)
che sono istruzioni di dominio, non di formato.

Sostituire le sezioni rimosse con una riga semplice:
```markdown
## Output

Respond with ONLY a JSON object conforming to the schema below. NEVER output code, CSS, HTML, or implementation artifacts.
```

### Fix B-fix.2 — Rafforzare system prompt `planner.agent.md`

**File**: `control-plane/orchestrator/src/main/resources/prompts/planner.agent.md`

Aggiungere guardia esplicita nella sezione Output (riga 23-25):
```markdown
## Output

Respond with **only** valid JSON conforming to the PlanSchema.
- No markdown fences, no explanatory text — just the JSON object.
- NEVER output source code (HTML, CSS, JavaScript, Java, etc.).
- NEVER implement the specification yourself — only decompose it into tasks.
- If unsure about the structure, follow the JSON Schema appended to the user prompt.
```

### Fix B-fix.3 — Ricompilare e riavviare orchestrator

```bash
cd /data/massimiliano/agent-framework
mvn -pl control-plane/orchestrator compile
# Restart orchestrator (kill + rerun)
```

---

## Fase B — Comporre spec e sottomettere all'orchestrator

### B.1 Spec basata sull'audit v3

Problemi identificati dall'audit:
- Nessun `loading="lazy"` sulle immagini (10/11 pagine)
- Nessun `rel="canonical"` (tutte le pagine)
- Nessun `prefers-reduced-motion` (tutte le pagine)
- `sitemap.xml` e `robots.txt` assenti
- Emoji usate come icone invece di SVG (6-17 per pagina)
- Google Fonts non self-hosted
- Directory `img/` vuote
- CSS 81KB e JS 31KB non minificati

### B.2 Craft della spec (alto livello, NON implementation-heavy)

**NOTA IMPORTANTE**: Il centro sportivo CPS Group e' a **San Sperate** (non Sardara).
Verificare che tutte le pagine riportino la localita' corretta.

La spec deve descrivere **cosa** ottenere, non **come** scriverlo in codice.
Evitare di includere snippet CSS/HTML/JS — altrimenti Opus entra in "modalita' implementazione".

Esempio di spec corretta:
```
Redesign the CPS Group sports center website (11 HTML pages, vanilla HTML5/CSS/JS).
Target directory: /data/massimiliano/Vari/MassimilianoPili.github.io/cps4/

Requirements:
1. Performance: Add lazy loading to all images, self-host Google Fonts, ...
2. SEO: Add canonical URLs, sitemap.xml, robots.txt, ...
3. Accessibility: Add prefers-reduced-motion media query support, ...
4. Assets: Replace emoji icons with inline SVG, ...
```

### B.3 Sottomettere il piano

```bash
curl -X POST http://localhost:8080/api/v1/plans \
  -H 'Content-Type: application/json' \
  -d '{
    "spec": "... spec alto livello ..."
  }'
```

L'orchestrator decompone la spec in task con dipendenze DAG. I task FE vengono dispatchati
al `fe-vanillajs-worker` (ora con opus) che opera sulla directory `cps4/`.

---

## Fase C — Esecuzione e monitoraggio

### Avviare il worker

```bash
cd /data/massimiliano/agent-framework
mvn -pl execution-plane/workers/fe-vanillajs-worker spring-boot:run &
```

L'orchestrator e' gia' attivo (verificato: health UP).

### Monitorare

- **SSE**: `GET /api/v1/plans/{planId}/events`
- **Status**: `GET /api/v1/plans/{planId}`
- **Logs**: output worker

---

## Fase D — Verifica finale

1. Lighthouse: Performance > 90, A11y > 95, SEO > 95
2. `lang="it"` su tutte le pagine
3. `sitemap.xml` e `robots.txt` presenti
4. Test mobile (375px)
5. Commit in cps4/

### Checklist rimanente

- [x] Manifest fe-vanillajs aggiornato con `claude-opus-4-6`
- [x] Worker rigenerato e ricompilato
- [x] Planner prompt + PlanItemSchema aggiornati con 11 profili
- [x] Orchestrator model impostato a `claude-opus-4-6`
- [ ] **Fix structured output** (rimuovere schema conflittuale dal prompt)
- [ ] Piano sottomesso all'orchestrator (HTTP 202, JSON valido)
- [ ] Worker esegue almeno un task con successo
- [ ] Lighthouse Performance > 90, A11y > 95, SEO > 95
- [ ] `lang="it"`, `sitemap.xml`, `robots.txt` presenti

---

## Fase C-fix — Bug: WorkerGenerator non genera application-redis.yml

### Problema

I worker generati dal code generator non includono `application-redis.yml` nella directory
`src/main/resources/`. Il template Mustache (`application-redis.yml.mustache`) esiste nel plugin
ma il `WorkerGenerator.java` non lo invoca mai. Solo `application-mcp.yml` viene generato
condizionalmente (riga 77-80).

### Effetto

I worker avviati con `-Dspring-boot.run.profiles=dev,redis` falliscono:
```
Parameter 0 of method workerResultProducer required a bean of type 'MessageSender' that could not be found.
```
Senza il profilo redis, `MessagingAutoConfiguration` non crea il bean `MessageSender`.

### Fix C-fix.1 — Workaround immediato (manuale)

Creare `application-redis.yml` in ogni worker `src/main/resources/`:
```yaml
messaging:
  provider: redis
  redis:
    host: ${REDIS_HOST:redis}
    port: ${REDIS_PORT:6379}
    database: 3
    cache-database: 4
```
**Stato**: gia' creato per `ai-task-worker` e `fe-vanillajs-worker`.

### Fix C-fix.2 — Fix nel code generator (futuro)

**File**: `execution-plane/agent-compiler-maven-plugin/src/main/java/.../generator/WorkerGenerator.java`

Dopo la generazione di `application-mcp.yml` (riga 80), aggiungere:
```java
// Generate application-redis.yml (Redis Streams messaging profile)
writeTemplate("application-redis.yml.mustache", context,
        resourcesDir.resolve("application-redis.yml"));
```

Questo garantisce che ogni worker generato includa il profilo Redis automaticamente.

---

## Fase E — (Futuro) Auto-discovery profili da manifests

Obiettivo: il planner prompt genera la tabella "Worker Profiles" **automaticamente**
scansionando `agents/manifests/*.agent.yml` all'avvio dell'orchestrator.
Cosi' aggiungere un nuovo worker non richiede mai di aggiornare il prompt manualmente.

### Implementazione

1. **ManifestScanner** (nuovo componente in `orchestrator.planner`)
   - All'avvio legge tutti i file `agents/manifests/*.agent.yml`
   - Estrae per ogni manifest: `workerProfile`, `workerType`, `displayName`
   - Produce una tabella Markdown formattata

2. **Prompt template** (`plan_tasks.prompt.md`)
   - Sostituire la tabella statica con un placeholder `{{WORKER_PROFILES}}`
   - `PromptLoader` o `PlannerService` inietta la tabella generata

3. **PlanItemSchema.java**
   - La `@JsonPropertyDescription` puo' restare statica (o generata da reflection)
   - In alternativa: generare la lista esempi dal ManifestScanner

### Vantaggi
- Zero manutenzione al prompt quando si aggiunge un worker
- Single source of truth: il manifest YAML
- Il planner vede sempre tutti i profili disponibili

---

## Fase F — (Futuro) Model selection dinamica lato orchestrator

Obiettivo: l'orchestrator sceglie il modello per ogni task a runtime, non piu' baked nel worker.

### Architettura attuale (statica)

```
manifest.yml (model: claude-sonnet-4-6)
  → codegen (Mustache template)
    → worker application.yml (model: claude-sonnet-4-6)
      → Spring AI ChatModel (fisso all'avvio)
```

### Architettura target (dinamica)

```
orchestrator decide model per-task (budget, complessita', GP regression)
  → AgentTask.model = "claude-opus-4-6"
    → worker legge task.model
      → ChatOptions override a runtime
```

### Modifiche necessarie

1. **AgentTask** (`worker-sdk/.../dto/AgentTask.java`)
   - Aggiungere: `String model  // nullable, override del model di default del worker`

2. **Orchestrator — TaskDispatcher**
   - Popolare `model` nel task basandosi su:
     - Manifest default (da WorkerProfileRegistry o AgentManifest)
     - Override da GP selection (`GpWorkerSelectionService` gia' seleziona profili — estendere a modelli)
     - Override da budget (`TokenBudgetService` — downgrade a sonnet se budget basso)

3. **Worker SDK — AbstractWorker o WorkerChatClientFactory**
   - Se `task.model != null`, creare ChatClient con `ChatOptions.builder().model(task.model).build()`
   - Altrimenti usare il default da application.yml (backward compatible)
   - Spring AI supporta `AnthropicChatOptions` per override per-request

4. **Code Generator**
   - Il template Mustache resta invariato (model di default nel worker YAML)
   - Il model nel manifest diventa il "fallback" quando l'orchestrator non specifica override

5. **Provenance**
   - Catturare il model effettivo usato in `Provenance.model` (attualmente `null`)
   - Utile per analytics e costo tracking

### Vantaggi

- Un singolo worker puo' usare modelli diversi per task diversi
- L'orchestrator puo' fare budget-aware model selection (opus per task complessi, haiku per semplici)
- Il sistema GP puo' apprendere quale modello funziona meglio per tipo di task
- Zero cambi necessari ai worker esistenti (il campo e' nullable, backward compatible)

---

## Fase G — (Futuro) Task retry via DB-based dispatch

Obiettivo: rendere il retry dei task robusto e operabile via semplice UPDATE SQL,
senza dover ricreare piani o manipolare Redis Streams.

### Problema attuale

Il retry attuale (`AutoRetryScheduler`) ri-dispatcha il task su Redis Streams, ma:
- Se il worker crasha, il messaggio puo' andare perso (ACK senza risultato)
- Non c'e' modo di re-dispatchare un task manualmente se non via API
- Lo stato DB e lo stato Redis possono divergere (come successo con il consumer group)

### Architettura target: DB come source of truth per il dispatch

```
1. Orchestrator crea plan_items con status = TO_DISPATCH
2. DispatchPoller (scheduled, ogni 5s) legge TO_DISPATCH dal DB
3. Pubblica su Redis Streams → aggiorna status a DISPATCHED
4. Worker completa → pubblica risultato → orchestrator aggiorna a DONE
5. Per retry: UPDATE plan_items SET status = 'TO_DISPATCH' WHERE task_key = 'FE-001'
```

### Modifiche necessarie

1. **Nuovo status `TO_DISPATCH`** in `PlanItemStatus` enum
   - Stato intermedio tra WAITING e DISPATCHED
   - WAITING → TO_DISPATCH (quando le dipendenze sono soddisfatte)
   - TO_DISPATCH → DISPATCHED (quando il poller pubblica su Redis)

2. **DispatchPoller** (nuovo componente in `orchestrator.orchestration`)
   - `@Scheduled(fixedDelay = 5000)`
   - Query: `SELECT * FROM plan_items WHERE status = 'TO_DISPATCH' ORDER BY ordinal`
   - Per ogni item: dispatch su Redis, update a DISPATCHED, salva `dispatch_attempt_id`
   - Idempotente: se il dispatch fallisce, resta TO_DISPATCH per il prossimo ciclo

3. **OrchestrationService.resolveAndDispatch()**
   - Cambiare da dispatch diretto a: `item.setStatus(TO_DISPATCH)` + save
   - Il DispatchPoller fa il dispatch effettivo

4. **API retry manuale**
   - `POST /api/v1/plans/{planId}/items/{taskKey}/retry`
   - Reset: status → TO_DISPATCH, failure_reason → null, result → null
   - Il poller lo ri-dispatcha automaticamente

5. **CLI/psql retry** (operativo, zero codice)
   ```sql
   UPDATE plan_items SET status = 'TO_DISPATCH', failure_reason = NULL
   WHERE plan_id = '...' AND task_key = 'FE-001';
   ```

### Vantaggi

- **DB come unica source of truth**: niente piu' divergenze DB/Redis
- **Retry triviale**: un UPDATE SQL basta per far ri-eseguire un task
- **Resilienza**: se Redis va giu', i task restano TO_DISPATCH e vengono dispatchati al recovery
- **Osservabilita'**: `SELECT status, count(*) FROM plan_items GROUP BY status` mostra lo stato reale
- **Batch retry**: `UPDATE plan_items SET status = 'TO_DISPATCH' WHERE status = 'FAILED'`

---

## Fase H-fix — (Scoperto in sessione) Consumer group resilience

### Problema

Se i Redis Streams vengono cancellati (pulizia manuale, restart Redis senza persistenza),
i consumer group vengono persi. `RedisStreamListenerContainer` tenta di ricrearli all'avvio
con `XGROUP CREATE`, ma se lo stream non esiste ancora, fallisce silenziosamente.
Quando i worker pubblicano risultati (ricreando lo stream implicitamente), il consumer group
non esiste e il listener muore con:

```
NOGROUP No such key 'agent-results' or consumer group 'orchestrator-group'
```

### Fix H-fix.1 — MKSTREAM al startup

**File**: `messaging-redis/.../RedisStreamListenerContainer.java`

Usare `XGROUP CREATE ... MKSTREAM` che crea sia lo stream che il group atomicamente:
```java
// Invece di:
XGROUP CREATE agent-results orchestrator-group $
// Usare:
XGROUP CREATE agent-results orchestrator-group $ MKSTREAM
```

Se il group esiste gia', `BUSYGROUP` viene catturato e ignorato (gia' implementato).

### Fix H-fix.2 — Auto-recovery del listener

Aggiungere retry con backoff nel `RedisStreamListenerContainer` se `XREADGROUP` fallisce
con `NOGROUP`. Tentare di ricreare il consumer group prima di fare retry:

```java
catch (RedisCommandExecutionException e) {
    if (e.getMessage().contains("NOGROUP")) {
        log.warn("Consumer group lost, recreating...");
        createConsumerGroup(streamKey, groupName);
        // Retry read
    }
}
```

### Impatto

Senza questa fix, ogni volta che si puliscono i Redis Streams bisogna riavviare l'orchestrator.
Con la fix, il sistema si auto-recupera.

---

## Fase I — Rilancio pipeline e completamento piano CPS

### Contesto

La sessione precedente ha:
- Implementato e testato il `CompactingToolCallingManager` (9 compaction, 257 tool call)
- Il compacting ha risolto il context overflow (da 208K token ingestibili a ~45K post-compaction)
- AI-001 ha fallito per **esaurimento token API** (non bug), l'orchestrator era giu' quando
  il worker ha pubblicato il risultato, quindi AI-001 e' rimasto in DISPATCHED
- Tutti i processi sono terminati

### I.1 Compilazione incrementale (se ci sono modifiche non installate)

Il `BeanPostProcessor` e' stato reso `static` dopo l'ultimo `mvn install`. Reinstallare:

```bash
cd /data/massimiliano/agent-framework
mvn -pl execution-plane/worker-sdk install -q
```

### I.2 Reset stato AI-001

AI-001 e' bloccato in DISPATCHED. Resettarlo a FAILED per abilitare il retry:

```bash
docker exec postgres psql -U agentframework -d agentframework -c \
  "UPDATE plan_items SET status='FAILED', failure_reason='Token quota exhausted - retrying' \
   WHERE task_key='AI-001' AND plan_id='60e1e42b-b021-47e7-9e2a-c44b4d38e5a8';"
```

### I.3 Avviare orchestrator

```bash
cd /data/massimiliano/agent-framework
REDIS_HOST=localhost nohup mvn -f pom.xml -pl control-plane/orchestrator \
  spring-boot:run -Dspring-boot.run.profiles=dev,redis > /tmp/orchestrator.log 2>&1 &
```

Attendere ~10s per startup completo (verificare con `curl -s http://localhost:8080/actuator/health`).

### I.4 Avviare 3 worker

Variabili env comuni:
```
REDIS_HOST=localhost
MCP_FS_BASEDIR=/data/massimiliano/Vari/MassimilianoPili.github.io
FS_SKILLS_DIR=/data/massimiliano/agent-framework
ANTHROPIC_API_KEY=claude_client
SPRING_AI_ANTHROPIC_BASE_URL=http://localhost:8090
```

Avviare sequenzialmente con `sleep 4` tra ciascuno:

```bash
cd /data/massimiliano/agent-framework

# Worker 1: ai-task
REDIS_HOST=localhost MCP_FS_BASEDIR=... FS_SKILLS_DIR=... ANTHROPIC_API_KEY=claude_client \
  SPRING_AI_ANTHROPIC_BASE_URL=http://localhost:8090 \
  nohup mvn -f pom.xml -pl execution-plane/workers/ai-task-worker \
  spring-boot:run -Dspring-boot.run.profiles=dev,redis \
  -Dspring-boot.run.arguments="--server.port=0" > /tmp/ai-task-worker.log 2>&1 &

sleep 4

# Worker 2: fe-vanillajs
# (stesse env var)
nohup mvn -f pom.xml -pl execution-plane/workers/fe-vanillajs-worker \
  spring-boot:run ... > /tmp/fe-vanillajs-worker.log 2>&1 &

sleep 4

# Worker 3: review
nohup mvn -f pom.xml -pl execution-plane/workers/review-worker \
  spring-boot:run ... > /tmp/review-worker.log 2>&1 &
```

### I.5 Verificare registrazione CompactingToolCallingManager

```bash
grep 'CompactingToolCallingManager' /tmp/ai-task-worker.log
# Atteso: "Wrapping ToolCallingManager ... with CompactingToolCallingManager (maxTokens=200000, threshold=60%)"
```

### I.6 Retry AI-001

```bash
# Get item UUID
ITEM_ID=$(docker exec postgres psql -U agentframework -d agentframework -t -c \
  "SELECT id FROM plan_items WHERE task_key='AI-001' AND plan_id='60e1e42b-b021-47e7-9e2a-c44b4d38e5a8';")

# Retry
curl -s -X POST http://localhost:8080/api/v1/plans/60e1e42b-b021-47e7-9e2a-c44b4d38e5a8/items/${ITEM_ID}/retry
```

### I.7 Monitorare esecuzione

```bash
# Tool call + compaction live
tail -f /tmp/ai-task-worker.log | grep --line-buffered -E 'compact|tool=|success|RESULT|ERROR'

# Stato piano (poll periodico)
docker exec postgres psql -U agentframework -d agentframework -c \
  "SELECT task_key, status FROM plan_items WHERE plan_id='60e1e42b-b021-47e7-9e2a-c44b4d38e5a8' ORDER BY ordinal;"
```

### I.8 Flusso atteso post-AI-001

Quando AI-001 completa con `success=true`:
1. Orchestrator transiziona AI-001 a DONE, salva il `result` JSON con i findings dell'audit
2. Orchestrator risolve le dipendenze: FE-001..FE-006 dipendono da AI-001
3. FE-001..FE-006 passano a READY e vengono dispatchati al `fe-vanillajs-worker`
4. Il worker FE esegue ogni task (modifica file in cps4/, scrive CSS/HTML/JS)
5. Al completamento di tutti i FE-*, AI-002 diventa READY (task cross-cutting: sitemap, robots.txt)
6. Infine RV-001 (review finale) dipende da tutti i precedenti

### Piano task nel DB

| Task    | Tipo     | Dipendenze | Descrizione |
|---------|----------|------------|-------------|
| AI-001  | AI_TASK  | nessuna    | Audit cps3/ e cps4/, inventario file, documenta stato |
| FE-001  | FE       | AI-001     | Self-host Google Fonts (.woff2, @font-face) |
| FE-002  | FE       | AI-001     | SVG icon library (sostituisce emoji) |
| FE-003  | FE       | AI-001     | SVG placeholder per img/ vuote |
| FE-004  | FE       | AI-001     | Correzioni contenuto (San Sperate, footer, lang) |
| FE-005  | FE       | AI-001     | Performance+a11y (lazy loading, alt, reduced motion) |
| FE-006  | FE       | AI-001     | Refactor app.js (IIFE, JSDoc, security, minify) |
| AI-002  | AI_TASK  | FE-001..FE-006 | sitemap.xml, robots.txt, security headers, minify CSS |
| RV-001  | REVIEW   | tutti      | Review finale cps4/ |

### Verifica finale (Fase D)

Dopo RV-001:
1. Lighthouse: Performance > 90, A11y > 95, SEO > 95
2. `lang="it"` su tutte le pagine
3. `sitemap.xml` e `robots.txt` presenti
4. Test mobile (375px)
5. Nessuna emoji come icona (solo SVG)
6. Google Fonts self-hosted (nessun external request)
7. Commit in cps4/
