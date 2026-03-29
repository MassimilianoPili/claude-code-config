# Piano: #24L2 — TOOL_MANAGER Worker (Tool Policy Dinamica per Task)

## Contesto

**#24L1 (toolHints)** è completato: il planner specifica strumenti via `toolHints` nel piano → propagati in `AgentTask` → enforced da `PolicyEnforcingToolCallback`. Ma toolHints sono specificati **senza contesto codebase** e sono statici.

**#24L2** aggiunge un worker LLM leggero iniettato come dipendenza di ogni domain worker, che riceve il risultato di CONTEXT_MANAGER + RAG_MANAGER e genera una `HookPolicy` precisa per **quel singolo task**, con la lista minima di tool MCP necessari.

**Il modello è sempre configurabile dall'orchestratore** via `AgentTask.modelId` (campo già presente nel record, attualmente ignorato). L'orchestratore imposta `modelId = "claude-haiku-4-5-20251001"` (o altro) quando inietta i task TM. Questo richiede di wirare `AgentTask.modelId` → `WorkerChatClientFactory` (implementazione parziale di #20, scoped al TOOL_MANAGER).

**Gap da colmare:**
- ❌ `WorkerType.TOOL_MANAGER` non esiste
- ❌ `tool-manager-worker` module non esiste
- ❌ `EnrichmentInjectorService` non inietta TM (inietta solo CM + RM)
- ❌ `HookManagerService` non ha handler per risultato TOOL_MANAGER
- ❌ `tool-manager.agent.yml` mancante

**Infrastruttura già pronta (non toccare):**
- ✅ `HookManagerService` — `ConcurrentHashMap<UUID planId, Map<String taskKey, HookPolicy>>`
- ✅ `PolicyEnforcingToolCallback.TASK_POLICY` ThreadLocal — già usato da Tier-0 check
- ✅ `AbstractWorker` — già chiama `hookManagerService.resolvePolicy(planId, taskKey)` prima di execute
- ✅ `EnrichmentInjectorService` — struttura inject CM/RM già wired in `OrchestrationService`
- ✅ `ToolNames` registry, `HookPolicy` record, `HookPolicyResolver` fallback

---

## Architettura post-implementazione

```
Piano pianificato:
  BE-001 → CM-001 (CONTEXT_MANAGER)
         → RM-001 (RAG_MANAGER)
         → TM-001 (TOOL_MANAGER) ← NEW
                  TM-001.dependsOn = [RM-001]
  BE-001.dependsOn = [..., TM-001]

Flusso runtime:
  CM-001 completa → RM-001 completa → TM-001 riceve context
  TM-001 (LLM, modello = task.modelId = "claude-haiku-4-5-20251001"):
    input:  task_key, task_description, relevant_files, semantic_chunks
    output: {"target_task_key":"BE-001","allowedTools":[...],"ownedPaths":[...]}
  OrchestrationService.onTaskCompleted(TM-001)
    → hookManagerService.storeToolManagerResult(planId, resultJson)
    → sovrascrive/arricchisce la HookPolicy per BE-001
  BE-001 esegue → TASK_POLICY.get() → tool allowlist precisa
```

**Priorità policy (highest to lowest):**
1. TOOL_MANAGER result (per-task, con contesto codebase) ← NEW
2. HOOK_MANAGER result (per-task da analisi piano)
3. `toolHints` planner-specified
4. Static manifest allowlist
5. WorkerType defaults (HookPolicyResolver)

---

## Fase 0 — Wire AgentTask.modelId → WorkerChatClientFactory (#20 parziale)

**Il campo `modelId` in `AgentTask` è già definito ma ignorato.** Il worker usa sempre il modello di default da `application.yml`.

**MOD** `execution-plane/worker-sdk/src/main/java/com/agentframework/worker/claude/WorkerChatClientFactory.java`

Quando si costruisce il `ChatClient`, leggere `task.modelId()` e applicarlo se non null:
```java
public ChatClient build(AgentTask task, ToolCallback[] callbacks, ToolAllowlist allowlist) {
    // Usa modelId dal task se specificato, altrimenti default da application.yml
    String modelId = task.modelId() != null ? task.modelId() : defaultModel;
    AnthropicChatOptions options = AnthropicChatOptions.builder()
        .model(modelId)
        .maxTokens(maxTokens)
        .build();
    // ... resto della costruzione
}
```

**Default**: se `task.modelId() == null`, il comportamento attuale (modello da application.yml) è preservato. Backward compatible.

Questa è l'implementazione **parziale di #20** sufficiente per TOOL_MANAGER: l'orchestratore controlla quale modello usa ogni task semplicemente impostando `modelId` nell'AgentTask.

---

## Fase 1 — WorkerType enum

**MOD** `control-plane/orchestrator/src/main/java/com/agentframework/orchestrator/domain/WorkerType.java`

Aggiungere:
```java
TOOL_MANAGER("TM"),
```

**MOD** `HookPolicyResolver.java` — aggiungere TOOL_MANAGER tra i readonly worker:
```java
WorkerType.TOOL_MANAGER, ToolNames.READONLY_FS_TOOLS,
```

---

## Fase 2 — HookManagerService

**MOD** `control-plane/orchestrator/src/main/java/com/agentframework/orchestrator/hooks/HookManagerService.java`

Aggiungere metodo `storeToolManagerResult(UUID planId, String resultJson)`:
```java
public void storeToolManagerResult(UUID planId, String resultJson) {
    // Parse JSON: {"target_task_key":"BE-001","allowedTools":[...],"ownedPaths":[...],"allowedMcpServers":[...]}
    // Crea HookPolicy per target_task_key
    // Chiama storePolicies(planId, Map.of(targetTaskKey, policy)) — OVERWRITE
    // Log: "Tool Manager policy stored for task {} (plan {}): {} tools, {} paths"
}
```

Il metodo riusa `storePolicies()` esistente che già fa `policies.computeIfAbsent(planId, ...).put(taskKey, policy)`.

---

## Fase 3 — OrchestrationService

**MOD** `control-plane/orchestrator/src/main/java/com/agentframework/orchestrator/orchestration/OrchestrationService.java`

In `onTaskCompleted()`, sezione switch su `workerType`, aggiungere il case TOOL_MANAGER (vicino a HOOK_MANAGER):
```java
case TOOL_MANAGER -> {
    if (result.resultJson() != null) {
        hookManagerService.storeToolManagerResult(planId, result.resultJson());
    }
}
```

---

## Fase 4 — EnrichmentInjectorService

**MOD** `control-plane/orchestrator/src/main/java/com/agentframework/orchestrator/orchestration/EnrichmentInjectorService.java`

La logica attuale inietta 1 CM + 1 RM condivisi per piano. Aggiungere:
- Per ogni domain worker (BE, FE, DBA, MOBILE, AI_TASK, CONTRACT, REVIEW):
  - Iniettare 1 TM-{n} dedicato (key: `TM-{sequentialN}`)
  - `TM-{n}.dependsOn = [rmTaskKey]` (se RM presente) o `[cmTaskKey]`
  - `TM-{n}.spec = task.taskKey + "\n" + task.description`
  - `TM-{n}.modelId = enrichmentProperties.getToolManagerModel()` — **configurabile**
  - `domainWorker.dependsOn.add(TM-{n}.taskKey)`
- `TM-{n}` NON viene iniettato per: CM, RM, SM, HM, TM stesso (evitare ricorsione)

**Configurazione `EnrichmentProperties`** — aggiungere campo:
```java
/** Model used for TOOL_MANAGER tasks (configurable from orchestrator properties). */
private String toolManagerModel = "claude-haiku-4-5-20251001";
```

In `application.yml`:
```yaml
agent:
  enrichment:
    tool-manager-model: claude-haiku-4-5-20251001   # override con modello desiderato
```

In `docker-compose.sol.yml` (orchestrator service):
```yaml
environment:
  AGENT_ENRICHMENT_TOOL_MANAGER_MODEL: claude-haiku-4-5-20251001
```

Questo permette di cambiare il modello del TOOL_MANAGER senza rebuild: è sufficiente aggiornare la variabile d'ambiente dell'orchestratore.

Metodo da aggiungere:
```java
private void injectToolManagers(Plan plan, List<PlanItem> domainItems,
                                 String rmOrCmTaskKey) {
    int seq = 1;
    for (PlanItem item : domainItems) {
        String tmKey = "TM-" + String.format("%03d", seq++);
        PlanItem tm = buildToolManagerItem(plan, tmKey, item, rmOrCmTaskKey);
        plan.addItem(tm);
        item.addDependency(tmKey);
    }
}
```

**Guard idempotenza:** skip se `plan.items` contiene già un item con `workerType == TOOL_MANAGER` che dipende dallo stesso domain worker.

---

## Fase 5 — tool-manager-worker module

**NEW** `execution-plane/workers/tool-manager-worker/`

Struttura identica agli altri worker (clone di `context-manager-worker` come template):

```
tool-manager-worker/
├── pom.xml
├── Dockerfile
└── src/main/java/com/agentframework/worker/toolmanager/
    └── ToolManagerWorker.java
```

**`ToolManagerWorker.java`:**
```java
@Component
public class ToolManagerWorker extends AbstractWorker {

    @Override
    public WorkerType workerType() { return WorkerType.TOOL_MANAGER; }

    @Override
    protected String systemPrompt() {
        return skillLoader.loadSkill("tool-manager.agent.md");
    }
}
```

**System prompt** `tool-manager.agent.md` (in `src/main/resources/prompts/`):
```markdown
You are a tool policy analyst for AI coding agents.

Given a task description and codebase context (relevant files, semantic chunks),
determine the MINIMUM set of MCP tools this task actually needs.

## Task Context
The task spec contains: target_task_key, task description, relevant files from CONTEXT_MANAGER.

## Available MCP Tools
- fs_read — read existing files
- fs_write — create/overwrite files
- fs_list — list directories
- fs_search / fs_grep — find files
- bash_execute — run shell commands
- python_execute — run Python scripts

## Rules
- BE/FE/DBA/MOBILE tasks that GENERATE code: need fs_write + fs_read + fs_list
- REVIEW tasks: fs_read + fs_grep ONLY (never fs_write)
- CONTRACT/doc tasks: often text-only (empty allowedTools = use defaults)
- ownedPaths: list paths this task will write to (used for path ownership enforcement)
- If unsure, prefer fs_read + fs_write (safe defaults)

## Output Format (JSON, no markdown):
{
  "target_task_key": "<taskKey from spec>",
  "allowedTools": ["fs_read", "fs_write", ...],
  "ownedPaths": ["/workspace/..."],
  "allowedMcpServers": ["repo-fs"],
  "rationale": "brief explanation"
}
```

---

## Fase 6 — Manifest + Config

**NEW** `agents/manifests/tool-manager.agent.yml`:
```yaml
apiVersion: agent-framework/v1
kind: AgentManifest
metadata:
  name: tool-manager-worker
  displayName: "Tool Manager Worker"
  description: >
    Lightweight (Haiku) per-task tool policy analyst. Auto-injected as dependency of every
    domain worker. Analyzes task + CM/RM context and produces a precise MCP tool allowlist.
spec:
  workerType: TOOL_MANAGER
  topic: agent-tasks
  subscription: tool-manager-worker-sub
  model:
    name: claude-haiku-4-5-20251001   # default — overridable via AgentTask.modelId dall'orchestratore
    maxTokens: 512
    temperature: 0.0
  prompts:
    systemPromptFile: execution-plane/workers/tool-manager-worker/src/main/resources/prompts/tool-manager.agent.md
    instructions: >
      Analyze the task spec and produce a precise tool policy JSON.
    resultSchema: |
      {
        "target_task_key": "BE-001",
        "allowedTools": ["fs_read", "fs_write"],
        "ownedPaths": ["/workspace/plan/src/"],
        "allowedMcpServers": ["repo-fs"],
        "rationale": "..."
      }
  tools:
    allowlist:
      - fs_read
      - fs_list
      - fs_grep
```

**MOD** `docker/docker-compose.sol.yml` — aggiungere servizio `tool-manager-worker` (dopo schema-manager-worker):
```yaml
tool-manager-worker:
  build:
    context: ../execution-plane/workers/tool-manager-worker
    dockerfile: Dockerfile
  container_name: agentfw-tool-manager-worker
  networks: [shared]
  environment:
    SPRING_PROFILES_ACTIVE: redis
    REDIS_HOST: redis
    REDIS_PORT: 6379
    ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
    SPRING_AI_ANTHROPIC_BASE_URL: http://proxy-ai:8097
    FS_SKILLS_DIR: /skills
  volumes: *skills-volumes
  restart: unless-stopped
```

---

## Fase 7 — plan_tasks.prompt.md

**MOD** `control-plane/orchestrator/src/main/resources/prompts/plan_tasks.prompt.md`

Nella tabella enrichment types (già presente), aggiungere TOOL_MANAGER:

```markdown
| `TOOL_MANAGER` | `TM-` | Lightweight (Haiku) per-task tool policy — auto-injected per ogni domain worker | JSON: allowedTools, ownedPaths, allowedMcpServers |
```

Nota: "Auto-injected — non includere manualmente nel piano."

---

## Fase 8 — Test

**NEW** `HookManagerServiceTest.java` (aggiungere test):
- `storeToolManagerResult_parsesAndStoresPolicy()` — result JSON valido → policy memorizzata
- `storeToolManagerResult_overridesHookManagerPolicy()` — TM result sovrascrive HM result per stesso taskKey
- `storeToolManagerResult_handlesInvalidJson()` — JSON malformato → log warning, nessun crash

**NEW** `EnrichmentInjectorServiceTest.java` (aggiungere test):
- `inject_addsTmForEachDomainWorker()` — piano con BE-001 + FE-001 → TM-001 + TM-002 iniettati
- `inject_tmDependsOnRm()` — TM-001.dependsOn include RM-001
- `inject_domainWorkerDependsOnTm()` — BE-001.dependsOn include TM-001
- `inject_skipsToolManagerForManagerWorkers()` — CM/RM/SM/TM non ricevono TM iniettato
- `inject_isIdempotent_forToolManager()` — secondo inject non duplica TM

**NEW** `ToolManagerWorkerTest.java` (nel modulo tool-manager-worker):
- `process_returnsValidHookPolicy()` — mock LLM, verifica output JSON schema

---

## File critici

| File | Modifica |
|------|----------|
| `worker-sdk/.../claude/WorkerChatClientFactory.java` | MOD — usa task.modelId() se non null (Fase 0) |
| `orchestrator/.../domain/WorkerType.java` | ADD TOOL_MANAGER("TM") |
| `orchestrator/.../hooks/HookManagerService.java` | ADD storeToolManagerResult() |
| `orchestrator/.../hooks/HookPolicyResolver.java` | ADD TOOL_MANAGER → READONLY_FS_TOOLS |
| `orchestrator/.../orchestration/OrchestrationService.java` | ADD case TOOL_MANAGER in onTaskCompleted() |
| `orchestrator/.../orchestration/EnrichmentInjectorService.java` | ADD injectToolManagers() + modelId per task |
| `orchestrator/.../config/EnrichmentProperties.java` | ADD toolManagerModel field |
| `orchestrator/src/main/resources/application.yml` | ADD agent.enrichment.tool-manager-model |
| `agents/manifests/tool-manager.agent.yml` | NEW |
| `execution-plane/workers/tool-manager-worker/` | NEW module |
| `docker/docker-compose.sol.yml` | ADD tool-manager-worker + AGENT_ENRICHMENT_TOOL_MANAGER_MODEL in orchestrator env |
| `plan_tasks.prompt.md` | ADD TOOL_MANAGER nella tabella enrichment types |

---

## Verifica

```bash
# 1. Compile
mvn compile -pl control-plane/orchestrator,execution-plane/worker-sdk,execution-plane/workers/tool-manager-worker

# 2. Test
mvn test -pl control-plane/orchestrator -Dtest="HookManagerServiceTest,EnrichmentInjectorServiceTest"
mvn test -pl execution-plane/workers/tool-manager-worker

# 3. Integration check
# Creare piano → verificare che TM-001...TM-N appaiano nel DAG dopo CM-001/RM-001
# e prima dei rispettivi domain worker
```

## Effort

~1.5g (worker leggero + wiring modelId + scan configurabilità)

---

## Fase Post-Implementazione — Scan Configurabilità Framework

Dopo l'implementazione di TOOL_MANAGER, eseguire un **audit sistematico** del framework per trovare valori hardcodati importanti che dovrebbero essere configurabili dall'orchestratore.

**Aree da ispezionare:**

| Area | Cosa cercare | File principali |
|------|-------------|-----------------|
| **Timeout LLM** | Timeout chiamate Anthropic hardcodati | `WorkerChatClientFactory`, `application.yml` |
| **Token budget** | Budget per WorkerType hardcodati o solo in yml | `TokenBudgetService`, `application.yml` |
| **Retry policy** | `maxRetries`, `baseDelay`, `maxDelay` configurabili via API? | `AutoRetryScheduler`, `PlanItem` |
| **Council size** | Numero membri council fisso o configurabile per piano? | `CouncilService` |
| **Leader election TTL** | 30s hardcodato (solo parzialmente in yml) | `LeaderElectionService` |
| **Ralph-Loop thresholds** | Soglie quality gate hardcodate? | `OrchestrationService` |
| **Enrichment flags** | `includeRag`, `includeCm` solo globali o per-piano? | `EnrichmentProperties` |
| **WorkerType routing** | Stream Redis unico — potrebbe avere coda priority per tipo | `AgentTaskProducer` |
| **Task lock TTL** | 5 min hardcodato in `RedisTaskLockService` | `messaging-redis` |
| **Reward weights** | Pesi Bayesian score fissi o configurabili? | `RewardSystem` |

**Output atteso:** lista di `(componente, valore attuale, proposta configurabilità, effort)` per decidere quali rendere property dinamiche senza over-engineering.

---

# Piano: #44 Execution Sandbox + #48 Content-Addressable Storage

## Contesto

I worker generano file di codice nei filesystem dei container Docker effimeri.
Quando il container viene riciclato, i file sono persi. Il review-worker riceve solo
i risultati JSON via `contextJson` — non può leggere i file sorgente generati.
Non esiste un build step: i worker generano codice ma non compilano né testano.

**Requisito utente**: "La review deve essere sempre fatta sul prodotto finito."

## Architettura della soluzione

```
                    ┌─────────────────────────┐
                    │     Orchestrator         │
                    │  ┌───────────────────┐   │
                    │  │  WorkspaceManager │   │    /data/.../data/workspaces/{planId-short}/
                    │  │  (mkdir/rm)       │───┼──► bind-mount condiviso fra tutti i worker
                    │  └───────────────────┘   │
                    │  ┌───────────────────┐   │
                    │  │  ArtifactStore    │   │    artifact_store table (CAS, SHA-256)
                    │  │  (save/get)       │───┼──► result_hash in plan_items
                    │  └───────────────────┘   │
                    └──────────┬───────────────┘
                               │ AgentTask + workspacePath
                               ▼
              ┌────────────────────────────────┐
              │        Domain Worker           │
              │  1. LLM genera codice          │
              │  2. fs_write → /workspace/...  │◄── bind-mount RW
              │  3. SandboxBuildInterceptor    │
              │     └─ docker run sandbox      │
              │        ├─ /code:ro (workspace) │
              │        └─ /out:rw  (output)    │
              │  4. Risultato + build output   │
              └────────────────────────────────┘
                               │ AgentResult
                               ▼
              ┌────────────────────────────────┐
              │        Review Worker           │
              │  fs_read → /workspace/...      │◄── bind-mount RO
              │  contextJson contiene build    │
              │  result dall'interceptor        │
              │  Review sul codice REALE       │
              └────────────────────────────────┘
```

---

## Fase 1 — Content-Addressable Storage (#48) · ~1.5g

### 1.1 Promuovere HashUtil → agent-common

- **NEW** `agent-common/src/main/java/com/agentframework/common/util/HashUtil.java`
  - Copia identica da `worker-sdk/.../util/HashUtil.java`
- **MOD** `worker-sdk/.../util/HashUtil.java` → deprecare, delegare a `common.util.HashUtil`

### 1.2 Flyway V15 — artifact_store + result_hash

**NEW** `control-plane/orchestrator/src/main/resources/db/migration/V15__artifact_store.sql`

```sql
CREATE TABLE artifact_store (
    content_hash  VARCHAR(64)  PRIMARY KEY,
    content       TEXT         NOT NULL,
    size_bytes    BIGINT       NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    access_count  BIGINT       NOT NULL DEFAULT 1
);

ALTER TABLE plan_items
    ADD COLUMN result_hash VARCHAR(64) REFERENCES artifact_store(content_hash);

-- Backfill risultati esistenti
INSERT INTO artifact_store (content_hash, content, size_bytes, created_at, access_count)
SELECT DISTINCT ON (encode(sha256(result::bytea), 'hex'))
    encode(sha256(result::bytea), 'hex'), result, octet_length(result), NOW(),
    COUNT(*) OVER (PARTITION BY encode(sha256(result::bytea), 'hex'))
FROM plan_items WHERE result IS NOT NULL
ON CONFLICT (content_hash) DO NOTHING;

UPDATE plan_items
SET result_hash = encode(sha256(result::bytea), 'hex')
WHERE result IS NOT NULL;
```

### 1.3 Entity + Repository + Service

**NEW** sotto `control-plane/orchestrator/src/main/java/.../orchestrator/artifact/`:

| File | Descrizione |
|------|-------------|
| `ArtifactBlob.java` | JPA entity: contentHash (PK), content, sizeBytes, createdAt, accessCount |
| `ArtifactRepository.java` | JpaRepository + `incrementAccessCount(@Param hash)` |
| `ArtifactCorruptedException.java` | RuntimeException per hash mismatch |
| `ArtifactStore.java` | @Service: `save(content)→hash`, `get(hash)→content` con verifica integrità |
| `ArtifactController.java` | GET `/api/v1/analytics/artifact-dedup` → stats deduplicazione |

### 1.4 Integrazione OrchestrationService

**MOD** `OrchestrationService.java` — in `onTaskCompleted()`, dopo `item.setResult(...)`:

```java
if (result.resultJson() != null && !result.resultJson().isBlank()) {
    try {
        String hash = artifactStore.save(result.resultJson());
        item.setResultHash(hash);
    } catch (Exception e) {
        log.warn("Failed to store artifact for {}: {}", result.taskKey(), e.getMessage());
    }
}
```

Non-bloccante: `result` inline resta per backward compatibility.

### 1.5 PlanItem entity

**MOD** `PlanItem.java` — aggiungere:
```java
@Column(name = "result_hash", length = 64)
private String resultHash;
```

### 1.6 Test

- `ArtifactStoreTest.java` — 6 test: save/get, dedup, integrity check, access_count
- `HashUtilTest.java` in agent-common — 4 test: null, empty, deterministico, formato hex
- `OrchestrationServiceTest` — mock ArtifactStore, verificare save + setResultHash

---

## Fase 2 — Workspace Condiviso per Piano · ~1g

### 2.1 Plan entity + Flyway V16

**MOD** `Plan.java` — aggiungere:
```java
@Column(name = "workspace_volume", length = 100)
private String workspaceVolume;
```

**NEW** `V16__workspace_volume.sql`:
```sql
ALTER TABLE plans ADD COLUMN workspace_volume VARCHAR(100);
```

### 2.2 WorkspaceManager

**NEW** `control-plane/orchestrator/src/main/java/.../orchestrator/workspace/WorkspaceManager.java`

Approccio **bind-mount** (non Docker volume): crea/distrugge subdirectory sotto un path host condiviso.

```java
@Service
public class WorkspaceManager {
    @Value("${agent.workspace.base-path:/workspace}")
    private String basePath;  // path dentro il container → corrisponde a bind-mount host

    public String createWorkspace(UUID planId) {
        String name = planId.toString().substring(0, 8);
        Path dir = Path.of(basePath, name);
        Files.createDirectories(dir);
        return name;
    }

    public void destroyWorkspace(String name) {
        // rm -rf basePath/name (con guard: solo sotto basePath)
    }
}
```

**Perché bind-mount e non Docker volume**: i worker container non possono montare volumi Docker dinamici (i mount sono dichiarati nel compose). Un bind-mount host condiviso (`/data/.../data/workspaces/`) è montato da tutti i worker al deploy time.

### 2.3 Lifecycle: creazione e cleanup

**MOD** `OrchestrationService.java`:
- In `createAndStart()`: `workspaceManager.createWorkspace(planId)` → `plan.setWorkspaceVolume(name)`
- Piano completato/fallito: schedula cleanup

**NEW** `workspace/WorkspaceCleanupScheduler.java`:
- `@Scheduled(fixedDelay = 300_000)` — ogni 5 min
- Trova piani completati/falliti da > 1h con workspaceVolume non null
- Chiama `destroyWorkspace()`, setta `workspaceVolume = null`

### 2.4 AgentTask + workspacePath

**MOD** entrambi i record AgentTask (orchestrator + worker-sdk):
```java
String workspacePath  // nullable, "/workspace/{planId-short}", null = no workspace
```

**MOD** `OrchestrationService.dispatchReadyItems()` e `redispatchItem()`:
```java
String workspacePath = plan.getWorkspaceVolume() != null
    ? "/workspace/" + plan.getWorkspaceVolume()
    : null;
```

Jackson deserializza campi mancanti come null → backward compatible con messaggi Redis vecchi.

### 2.5 AgentContext + prompt injection

**MOD** `AgentContext.java` — aggiungere `String workspacePath`
**MOD** `AgentContextBuilder.java` — popolare da `task.workspacePath()`
**MOD** `AbstractWorker.buildStandardUserPrompt()`:
```java
if (context.workspacePath() != null) {
    prompt.add("## Workspace\nWrite all generated files under: " + context.workspacePath());
}
```

Il worker scrive al workspace via MCP `fs_write` con path assoluto.
Il review-worker legge dal workspace via MCP `fs_read`.

### 2.6 Docker compose

**MOD** `docker/docker-compose.sol.yml`:

```yaml
x-workspace-volume: &workspace-volume
  /data/massimiliano/agent-framework/data/workspaces:/workspace:rw

# Worker di dominio (RW)
be-java-worker:
  volumes:
    - *skills-volumes
    - /data/massimiliano/agent-framework/data/workspaces:/workspace:rw

# Review worker (RO)
review-worker:
  volumes:
    - *skills-volumes
    - /data/massimiliano/agent-framework/data/workspaces:/workspace:ro

# Orchestrator (RW — per WorkspaceManager mkdir/rm)
orchestrator:
  volumes:
    - /data/massimiliano/agent-framework/data/workspaces:/workspace:rw
```

### 2.7 Test

- `WorkspaceManagerTest.java` — 3 test: create, destroy, guard path traversal
- `OrchestrationServiceTest` — verify workspace creation + workspacePath nel dispatch

---

## Fase 3 — SandboxExecutor · ~1.5g

### 3.1 DTO in agent-common

**NEW** sotto `agent-common/src/main/java/.../common/sandbox/`:

| File | Descrizione |
|------|-------------|
| `SandboxRequest.java` | Record: sandboxImage, command (List), workspacePath, outputPath, memoryLimitMb (512), cpuLimit (1.0), timeoutSeconds (120), networkDisabled (true) |
| `SandboxResult.java` | Record: exitCode, stdout, stderr, durationMs, timedOut |

### 3.2 SandboxExecutor

**NEW** `worker-sdk/src/main/java/.../worker/sandbox/SandboxExecutor.java`

- `@Component @ConditionalOnProperty(name = "agent.worker.sandbox.enabled", havingValue = "true")`
- Usa `ProcessBuilder` per chiamare `docker run` (nessuna dipendenza docker-java)
- Flag sicurezza: `--network none`, `--read-only`, `--user 1000:1000`, `--memory`, `--cpus`
- Volume mount: `workspacePath:/code:ro`, `outputPath:/out:rw`
- `--tmpfs /tmp:rw,noexec,nosuid,size=64m`
- Timeout via `process.waitFor(timeout, SECONDS)` + `destroyForcibly()`
- Trunca stdout/stderr a 50KB

### 3.3 SandboxProperties

**NEW** `worker-sdk/src/main/java/.../worker/sandbox/SandboxProperties.java`

```java
@ConfigurationProperties(prefix = "agent.worker.sandbox")
public class SandboxProperties {
    boolean enabled = false;
    int defaultTimeoutSeconds = 120;
    int defaultMemoryMb = 512;
    Map<String, String> imagesByProfile = Map.of(
        "be-java", "agent-sandbox-java:21",
        "be-go", "agent-sandbox-go:1.22",
        "be-python", "agent-sandbox-python:3.12",
        "be-node", "agent-sandbox-node:22",
        "fe-react", "agent-sandbox-node:22",
        "be-rust", "agent-sandbox-rust:latest"
    );
}
```

### 3.4 AbstractWorker — sandbox opzionale

**MOD** `AbstractWorker.java`:
- Aggiungere campo `Optional<SandboxExecutor> sandboxExecutor` (injected)
- Metodo `protected SandboxResult executeSandbox(SandboxRequest)` + `isSandboxAvailable()`
- Nuovo costruttore 5-arg, mantenere 3 e 4-arg per backward compatibility

### 3.5 SandboxBuildInterceptor

**NEW** `worker-sdk/src/main/java/.../worker/interceptor/SandboxBuildInterceptor.java`

`WorkerInterceptor.afterExecute()`: dopo che il worker genera il codice, esegue compilazione nel sandbox.

```java
@Override
public String afterExecute(AgentContext ctx, String result, AgentTask task) {
    if (ctx.workspacePath() == null || !isDomainWorker(task.workerType())) return result;
    String image = properties.getImagesByProfile().get(task.workerProfile());
    if (image == null) return result;

    SandboxResult build = sandboxExecutor.execute(new SandboxRequest(
        image, buildCommandFor(task.workerProfile()),
        ctx.workspacePath(), ctx.workspacePath() + "/out", ...));

    return enrichResultWithBuildOutput(result, build);
}
```

Arricchisce il `resultJson` con `build_exit_code`, `build_stdout`, `build_stderr`.
Il review-worker vede l'output di compilazione/test nei dependency results.

### 3.6 Dockerfile sandbox

**NEW** `docker/sandbox/`:

| File | Base | Toolchain |
|------|------|-----------|
| `Dockerfile.java21` | eclipse-temurin:21-jdk-alpine | Maven 3.9 |
| `Dockerfile.go122` | golang:1.22-alpine | go |
| `Dockerfile.node22` | node:22-alpine | npm, pnpm |
| `Dockerfile.python312` | python:3.12-slim | pip, pytest |
| `build-sandbox-images.sh` | — | Script build tutte le immagini |

### 3.7 Docker compose — sandbox

**MOD** `docker/docker-compose.sol.yml` — worker con sandbox:
```yaml
be-java-worker:
  volumes:
    - *skills-volumes
    - /data/massimiliano/agent-framework/data/workspaces:/workspace:rw
    - /var/run/docker.sock:/var/run/docker.sock:ro   # sandbox
  environment:
    AGENT_WORKER_SANDBOX_ENABLED: "true"
```

### 3.8 Test

- `SandboxExecutorTest.java` — 5 test: command build, timeout, truncation, exit code, network disabled
- `SandboxBuildInterceptorTest.java` — 4 test: skip non-domain, enrich result, handle failure

---

## Fase 4 — Wire Review su Workspace · ~0.5g

### 4.1 Review-worker legge dal workspace

Il review-worker riceve `workspacePath` in `AgentContext` tramite la modifica della Fase 2.5.
Il prompt `buildStandardUserPrompt()` include la sezione `## Workspace`.
Tool allowlist (`fs_list`, `fs_read`, `fs_search`, `fs_grep`) già supporta lettura.
Bind-mount RO nel compose (Fase 2.6) dà accesso alla directory.

### 4.2 Aggiornare skill review

**MOD** `skills/review.agent.md` (o `.claude/agents/review/SKILL.md`):
- Step 1: "Se `workspacePath` è disponibile, usa i tool filesystem per leggere i file sorgente generati"
- Step 8: "Verifica i risultati del build (build_exit_code, build_stdout) nei dependency results"

### 4.3 Test manuale end-to-end

1. Piano con be-java-worker → scrive codice a `/workspace/{plan}/`
2. SandboxBuildInterceptor → compila, risultato arricchito
3. Review-worker → legge file da workspace + vede build output
4. Piano completa → WorkspaceCleanupScheduler pulisce dopo 1h

---

## Ordine delle dipendenze

```
Fase 1 (CAS) ─────────────────────────── indipendente
Fase 2 (Workspace) ───────────────────── indipendente
Fase 3 (Sandbox) ─────────────────────── dipende da Fase 2 (workspacePath)
Fase 4 (Wire Review) ─────────────────── dipende da Fase 2 + 3
```

Fase 1 e 2 parallelizzabili. Fase 3 dopo Fase 2. Fase 4 ultima.

## File critici

| File | Modifica |
|------|----------|
| `agent-common/.../util/HashUtil.java` | NEW — promozione da worker-sdk |
| `orchestrator/.../artifact/ArtifactStore.java` | NEW — CAS service |
| `orchestrator/.../artifact/ArtifactBlob.java` | NEW — JPA entity |
| `orchestrator/.../workspace/WorkspaceManager.java` | NEW — create/destroy workspace |
| `orchestrator/.../workspace/WorkspaceCleanupScheduler.java` | NEW — cleanup schedulato |
| `orchestrator/.../orchestration/OrchestrationService.java` | MOD — CAS save, workspace create, workspacePath dispatch |
| `orchestrator/.../domain/Plan.java` | MOD — +workspaceVolume |
| `orchestrator/.../domain/PlanItem.java` | MOD — +resultHash |
| `orchestrator/messaging/dto/AgentTask.java` | MOD — +workspacePath |
| `worker-sdk/.../dto/AgentTask.java` | MOD — +workspacePath |
| `worker-sdk/.../AbstractWorker.java` | MOD — sandbox, workspace prompt |
| `worker-sdk/.../context/AgentContext.java` | MOD — +workspacePath |
| `worker-sdk/.../context/AgentContextBuilder.java` | MOD — popolare workspacePath |
| `worker-sdk/.../sandbox/SandboxExecutor.java` | NEW — ProcessBuilder → docker run |
| `worker-sdk/.../sandbox/SandboxProperties.java` | NEW — config images/limiti |
| `worker-sdk/.../interceptor/SandboxBuildInterceptor.java` | NEW — post-execute build |
| `docker/docker-compose.sol.yml` | MOD — workspace bind-mount, Docker socket |
| `docker/sandbox/Dockerfile.*` | NEW — 4 immagini sandbox |
| Flyway V15, V16 | NEW — artifact_store, workspace_volume |

## Verifica

1. `mvn compile -pl agent-common,control-plane/orchestrator,execution-plane/worker-sdk`
2. `mvn test -pl agent-common,control-plane/orchestrator,execution-plane/worker-sdk`
3. Build sandbox images: `cd docker/sandbox && ./build-sandbox-images.sh`
4. Test E2E manuale: piano con be-java → skip/dispatch → review su workspace

## Effort totale

| Fase | Effort | Descrizione |
|------|--------|-------------|
| Fase 1 | ~1.5g | CAS: HashUtil, migration, entity, service, integration |
| Fase 2 | ~1g | Workspace: Plan entity, WorkspaceManager, AgentTask, compose |
| Fase 3 | ~1.5g | Sandbox: executor, interceptor, Dockerfiles, config |
| Fase 4 | ~0.5g | Wire: review skill, prompt, test E2E |
| **Totale** | **~4.5g** | |

---

## Stato finale #44/#48 — COMPLETATO ✅

**686 test verdi**: agent-common 9, worker-sdk 39, orchestrator 638.

---

# Piano: #23 Enrichment Pipeline Activation

## Contesto

La pipeline di enrichment (CONTEXT_MANAGER → RAG_MANAGER → vectorDB/graphDB) è **parzialmente collegata**:

**Già esistente:**
- ✅ `EnrichmentInjectorService.inject(plan)` chiamato da `OrchestrationService` (Level 2 auto-injection)
- ✅ `EnrichmentProperties` con `autoInject: true` in `application.yml`
- ✅ `context-manager.agent.yml` e `schema-manager.agent.yml` manifesti
- ✅ `RagManagerWorker.java` programmatico (no LLM) — chiama pgvector + Apache AGE

**Gap reali:**
- ❌ `rag-manager.agent.yml` mancante — ManifestLoader lo richiede per la build, ma RAG Manager è programmatico (no LLM, no MCP tools → `allowlist: []` farebbe fallire la validazione)
- ❌ `plan_tasks.prompt.md` non menziona CONTEXT_MANAGER/RAG_MANAGER/SCHEMA_MANAGER → Level 1 (planner proattivo) mancante
- ❌ `rag-manager-worker` assente da `docker-compose.sol.yml`

## Architettura post-fix

```
Planner (Level 1) ─────────────────────► genera CM/RM/SM opzionalmente
                                              ↓
EnrichmentInjectorService (Level 2) ──► inietta CM-001, RM-001 (idempotente)
                                              ↓
Redis Stream ─────────────────────────► CONTEXT_MANAGER worker (LLM)
                                              ↓
                  ┌───────────────────────────┘
                  ↓
         RAG_MANAGER worker (programmatico: pgvector + AGE)
                  ↓
         contextJson disponibile per domain workers (BE/FE/AI_TASK)
```

## Fase 1 — Supporto `programmatic: true` nel ManifestLoader

**Il problema:** `ManifestLoader.java` richiede `tools.allowlist` non-empty. Il RAG Manager è programmatico → `allowlist: []` fallirebbe la validazione.

**MOD** `execution-plane/agent-compiler-maven-plugin/src/main/java/com/agentframework/compiler/manifest/AgentManifest.java`
- Nella classe `Spec`, aggiungere `private boolean programmatic = false;`

**MOD** `execution-plane/agent-compiler-maven-plugin/src/main/java/com/agentframework/compiler/manifest/ManifestLoader.java`
- Skip del check `allowlist non-empty` se `spec.isProgrammatic() == true`
- (Opzionalmente) skip validazione prompt/model per worker programmatici

## Fase 2 — Creare `rag-manager.agent.yml`

**NEW** `agents/manifests/rag-manager.agent.yml`:
```yaml
apiVersion: agent-framework/v1
kind: AgentManifest
metadata:
  name: rag-manager-worker
  displayName: "RAG Manager Worker"
  description: >
    Programmatic worker (no LLM) — hybrid search su pgvector + Apache AGE.
    Dipende da CONTEXT_MANAGER. Risultati nel contextJson dei domain worker downstream.
spec:
  workerType: RAG_MANAGER
  topic: agent-tasks
  subscription: rag-manager-worker-sub
  programmatic: true
  model:
    name: claude-sonnet-4-6   # non usato a runtime
    maxTokens: 1024
    temperature: 0.0
  prompts:
    systemPromptFile: execution-plane/workers/rag-manager-worker/src/main/resources/prompts/rag-manager.agent.md
    instructions: "Esecuzione programmatica — vedi RagManagerWorker.java"
    resultSchema: |
      {
        "semantic_chunks": [{"content":"...","score":0.95,"source":"..."}],
        "graph_insights":  [{"entity":"...","relation":"...","target":"..."}],
        "related_files":   ["path/to/file.java"],
        "search_metadata": {"query":"...","chunks_found":10,"duration_ms":150}
      }
  tools:
    allowlist: []   # programmatic: true bypassa validazione
  concurrency:
    maxConcurrentCalls: 3
  retry:
    maxAttempts: 2
    backoffMs: 3000
```

## Fase 3 — Aggiornare `plan_tasks.prompt.md` (Level 1)

**MOD** `control-plane/orchestrator/src/main/resources/prompts/plan_tasks.prompt.md`

Aggiungere dopo la tabella dei worker types principali:

```markdown
## Manager di Enrichment (auto-iniettati dall'orchestratore)

| Type | Prefisso | Scopo |
|------|----------|-------|
| CONTEXT_MANAGER | CM | Esplora codebase, identifica file rilevanti |
| RAG_MANAGER | RM | Ricerca semantica su vectorDB + graphDB |
| SCHEMA_MANAGER | SM | Estrae API, DTO, contratti esistenti |

Questi manager vengono iniettati automaticamente come dipendenze dei domain worker.
Includili esplicitamente solo per aggiungere description custom o controllare ordine.
```

## Fase 4 — Docker Compose

**MOD** `docker/docker-compose.sol.yml` — aggiungere (fare MERGE con le modifiche utente esistenti):
```yaml
rag-manager-worker:
  build:
    context: ..
    dockerfile: execution-plane/workers/rag-manager-worker/Dockerfile
  container_name: rag-manager-worker
  restart: unless-stopped
  networks: [shared]
  mem_limit: 512m
  depends_on: [redis, postgres, ollama]
  environment:
    SPRING_PROFILES_ACTIVE: redis
    SPRING_REDIS_HOST: redis
    SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/embeddings
    SPRING_DATASOURCE_USERNAME: embeddings
    SPRING_DATASOURCE_PASSWORD: ${EMBEDDINGS_DB_PASSWORD}
    OLLAMA_BASE_URL: http://ollama:11434
```

## Fase 5 — Test

Verificare se `EnrichmentInjectorServiceTest` esiste. Se no, creare:
**NEW** `control-plane/orchestrator/src/test/java/.../orchestration/EnrichmentInjectorServiceTest.java`
- `inject_addsCmAndRm_whenNoDomainWorkerHasEnrichment()` — piano con BE-001 → CM-001 e RM-001 iniettati
- `inject_isIdempotent_whenCmAlreadyPresent()` — CM già presente → non duplica
- `inject_wiresDependencies_toDomainWorkers()` — BE-001.dependsOn include RM-001
- `inject_skipsRm_whenIncludeRagFalse()` — `includeRag: false` → solo CM-001
- `inject_skipsAll_whenAutoInjectFalse()` — `autoInject: false` → piano invariato

**Aggiornare** ManifestLoader test (se esiste):
- `load_acceptsProgrammaticWorker_withEmptyAllowlist()`
- `load_rejectsNonProgrammatic_withEmptyAllowlist()`

## File critici

| File | Modifica |
|------|----------|
| `agents/manifests/rag-manager.agent.yml` | NEW |
| `agent-compiler-maven-plugin/.../AgentManifest.java` | MOD — campo `programmatic` in Spec |
| `agent-compiler-maven-plugin/.../ManifestLoader.java` | MOD — skip allowlist check per programmatic |
| `orchestrator/.../prompts/plan_tasks.prompt.md` | MOD — sezione enrichment managers |
| `docker/docker-compose.sol.yml` | MOD — servizio rag-manager-worker (merge) |
| `EnrichmentInjectorServiceTest.java` | NEW se assente |

## Verifica

```bash
mvn compile -pl execution-plane/agent-compiler-maven-plugin,control-plane/orchestrator
mvn test   -pl execution-plane/agent-compiler-maven-plugin,control-plane/orchestrator
# E2E: creare piano → verificare che CM-001 e RM-001 appaiano nel DAG
```

## Effort

~1g (inferiore al piano originale: Level 2 auto-injection già esistente)

## Working directory utente (non toccare)
- `PlanEventStore`, `PlanEventRepository`, `SseEmitterRegistry` — SSE resume via `Last-Event-ID`
- `V18__compensation_mode.sql` — eliminato
- `docker/docker-compose.sol.yml` — modifiche sandbox esistenti (fare merge, non replace)
