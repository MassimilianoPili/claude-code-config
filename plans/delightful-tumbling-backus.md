# Piano S13 — Model Auditability (#20 completion) + Task Kill Control (#29 Fase 1)

## Context

S12 ha completato Leader Election (#22) e Monitoring Dashboard (#28). 734 test orchestratore, 0 fallimenti.

S13 si concentra su due temi ortogonali ma coerenti sotto il cappello **"Operational Control"**:

- **#20 completion** — Il routing modello (haiku/sonnet/opus per task) è già 80% implementato:
  il planner assegna `modelId`, il dispatch lo propaga via `AgentTask`, e `WorkerChatClientFactory`
  lo usa per creare il `ChatClient`. L'unico gap: `Provenance.model` è sempre `null` (campo reserved
  mai wired), e non è verificato se `CostEstimationService` riceve il `modelId` corretto.
  Anche `PlanItemResponse` non espone `modelId` → il monitoring dashboard non può mostrarlo.

- **#29 Fase 1** — `StaleTaskDetectorScheduler` già gestisce task bloccati dopo timeout globale
  (30 min default). Mancano: (a) kill immediato operator-initiated (endpoint + logica), e
  (b) timeout configurabile per workerType invece di solo globale.

B17 (context overflow) è già completamente implementato: `maxTokens` via mustache build-time,
`CompactingToolCallingManager` per L2, `fs_read` con `limit/offset` per L3. Non serve toccare.

---

## Architettura esistente da rispettare

**Provenance.java** (`execution-plane/worker-sdk/.../dto/Provenance.java`)
Record con campo `model: String` — sempre passato come `null` in `AbstractWorker.process()` (righe 292, 339).
Template method pattern: success path e failure path creano Provenance separatamente.

**AbstractWorker.java** (`execution-plane/worker-sdk/.../AbstractWorker.java`)
- `ChatClient chatClient = chatClientFactory.create(workerType(), resolveToolAllowlist(task), task.modelId());` — line ~272
- Provenance creata con `null, // model: reserved for future use` — line ~292

**CostEstimationService.java** (`control-plane/orchestrator/.../budget/CostEstimationService.java`)
- `estimate(Long inputTokens, Long outputTokens, String model)` — price table per modello, fallback default
- Chiamata in `OrchestrationService` al completamento task — verificare se passa `item.getModelId()`

**PlanItemResponse.java** (`control-plane/orchestrator/.../api/dto/PlanItemResponse.java`)
- DTO corrente: non espone `modelId`; va aggiunto.

**StaleTaskDetectorScheduler.java** (`control-plane/orchestrator/.../orchestration/StaleTaskDetectorScheduler.java`)
- `@Value("${stale.timeout-minutes:30}")` — timeout globale
- `@Scheduled(fixedDelayString = "${stale.detector-interval-ms:60000}")` — ogni 60s
- Logica: `planItemRepository.findStaleDispatched(cutoff)` → FAILED("stale_timeout") + retry flow

**OrchestrationService** — ha già `killItem`-like logic nel failure handling; estendere.

**PlanController** — 26 endpoint; aggiungere `POST /{id}/items/{itemId}/kill`.

---

## Fase A — #20 completion: Model Auditability

### A1 — Wire `Provenance.model` in AbstractWorker

**File**: `execution-plane/worker-sdk/src/main/java/com/agentframework/worker/AbstractWorker.java`

Sostituire i due `null, // model: reserved` (success path riga ~292, failure path riga ~339)
con il model ID effettivamente usato:

```java
// Resolver: task.modelId() se non-null/blank, altrimenti legge default da @Value
private final String defaultModelId;  // iniettato: @Value("${spring.ai.anthropic.chat.options.model:claude-sonnet-4-6}")

String resolvedModel = (task.modelId() != null && !task.modelId().isBlank())
    ? task.modelId()
    : defaultModelId;

// In entrambi i path success + failure:
resolvedModel,   // model: actual LLM model used
```

Pattern scelto: `@Value` in `AbstractWorker` per il default, override da `task.modelId()`.
Non richieide Redis/DB lookup — il worker conosce già il suo default model dal proprio application.yml.

### A2 — Verifica/fix CostEstimationService call in OrchestrationService

**File**: `control-plane/orchestrator/src/main/java/com/agentframework/orchestrator/orchestration/OrchestrationService.java`

Cercare la chiamata a `costEstimationService.estimate(...)` nel metodo `onTaskCompleted()` o simile.
Verificare che sia chiamata con `item.getModelId()`. Se passa `null`, aggiungere:

```java
String modelForCost = item.getModelId() != null ? item.getModelId() : "claude-sonnet-4-6";
BigDecimal cost = costEstimationService.estimate(inputTokens, outputTokens, modelForCost);
```

### A3 — PlanItemResponse: esporre `modelId`

**File**: `control-plane/orchestrator/src/main/java/com/agentframework/orchestrator/api/dto/PlanItemResponse.java`

Aggiungere campo `String modelId` al record e mapparlo da `PlanItem.getModelId()` nel factory method `from(PlanItem item)`.

### A4 — Test A

**File**: `execution-plane/worker-sdk/src/test/java/com/agentframework/worker/ProvenanceModelTest.java`
- `provenance_withModelOverride_recordsActualModelId` — task con modelId="claude-haiku-4-5-20251001" → Provenance.model="claude-haiku-4-5-20251001"
- `provenance_withNullModelId_recordsDefaultModel` — task con modelId=null → Provenance.model=defaultModelId

**File**: `control-plane/orchestrator/src/test/java/com/agentframework/orchestrator/budget/CostEstimationModelTest.java`
- `estimate_withHaikuModel_appliesHaikuPricing` — prezzi haiku diversi da sonnet
- `estimate_withUnknownModel_fallsBackToDefaultPricing`

---

## Fase B — #29 Fase 1: Task Kill + Per-WorkerType Timeout

### B1 — `OrchestrationService.killItem(UUID itemId)`

**File**: `control-plane/orchestrator/src/main/java/com/agentframework/orchestrator/orchestration/OrchestrationService.java`

```java
@Transactional
public void killItem(UUID itemId) {
    PlanItem item = planItemRepository.findById(itemId)
        .orElseThrow(() -> new IllegalStateException("Unknown item: " + itemId));
    if (item.getStatus() != ItemStatus.DISPATCHED && item.getStatus() != ItemStatus.WAITING) {
        throw new IllegalStateTransitionException(
            "Cannot kill item in status " + item.getStatus() + " (only DISPATCHED or WAITING)");
    }
    item.transitionTo(ItemStatus.FAILED);
    item.setFailureReason("killed_by_operator");
    item.setCompletedAt(Instant.now());
    planItemRepository.save(item);
    eventPublisher.publishEvent(SpringPlanEvent.forItemStatus(
        item.getPlan().getId(), item.getId(), item.getTaskKey(),
        item.getWorkerProfile(), "FAILED"));
    log.info("Item {} killed by operator (plan={})", itemId, item.getPlan().getId());
    checkPlanCompletion(item.getPlan().getId());
}
```

Note: item rimane FAILED — il retry flow normale si applica (auto-retry se tentativi rimangono,
altrimenti piano va in PAUSED/FAILED). L'operatore può poi usare `/retry` o `/skip`.
I worker in esecuzione continuano fino al completamento naturale — la risposta viene ignorata
dall'idempotency guard (item già in stato terminale).

### B2 — `POST /api/v1/plans/{id}/items/{itemId}/kill` in PlanController

**File**: `control-plane/orchestrator/src/main/java/com/agentframework/orchestrator/api/PlanController.java`

```java
/**
 * POST /api/v1/plans/{id}/items/{itemId}/kill
 * Immediately kills a DISPATCHED or WAITING task by transitioning it to FAILED.
 * The running worker (if any) continues until natural completion but its result is ignored.
 * Returns 202 Accepted on success, 400 if item is not in a killable state.
 */
@PostMapping("/{id}/items/{itemId}/kill")
public ResponseEntity<?> killItem(@PathVariable UUID id, @PathVariable UUID itemId) {
    try {
        orchestrationService.killItem(itemId);
        return ResponseEntity.accepted().body(Map.of(
            "status", "killed",
            "itemId", itemId.toString(),
            "planId", id.toString()));
    } catch (IllegalStateTransitionException e) {
        return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
    } catch (IllegalStateException e) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", e.getMessage()));
    }
}
```

### B3 — Per-workerType timeout configuration

**File**: `control-plane/orchestrator/src/main/java/com/agentframework/orchestrator/config/StaleDetectorProperties.java` (NEW)

```java
@ConfigurationProperties(prefix = "orchestrator.stale-detection")
public record StaleDetectorProperties(
    int defaultTimeoutMinutes,       // default 30
    Map<String, Integer> workerTimeouts  // es. "AI_TASK" → 120, "CONTEXT_MANAGER" → 10
) {
    public StaleDetectorProperties {
        if (defaultTimeoutMinutes <= 0) defaultTimeoutMinutes = 30;
        if (workerTimeouts == null) workerTimeouts = Map.of();
    }
    public int timeoutFor(String workerType) {
        return workerTimeouts.getOrDefault(workerType, defaultTimeoutMinutes);
    }
}
```

**File**: `control-plane/orchestrator/src/main/resources/application.yml` — aggiungere:

```yaml
orchestrator:
  stale-detection:
    default-timeout-minutes: 30
    worker-timeouts:
      AI_TASK: 120          # task complessi
      ADVISORY: 90          # council
      CONTEXT_MANAGER: 15   # veloci, file I/O
      HOOK_MANAGER: 10
      SCHEMA_MANAGER: 15
```

### B4 — StaleTaskDetectorScheduler: usa per-workerType timeout

**File**: `control-plane/orchestrator/src/main/java/com/agentframework/orchestrator/orchestration/StaleTaskDetectorScheduler.java`

Sostituire il single `@Value("${stale.timeout-minutes:30}")` con `StaleDetectorProperties`.
Iniettare `StaleDetectorProperties staleProps`.

Logica aggiornata: per ogni item stale, usare `staleProps.timeoutFor(item.getWorkerType().name())`
per calcolare il cutoff individuale invece di un cutoff globale.

**Nota implementativa**: la query `findStaleDispatched(cutoff)` usa un singolo cutoff —
con timeout per-workerType bisogna fare il check in-memory dopo aver caricato gli item DISPATCHED,
oppure aggiungere una query per ogni workerType. L'approccio più semplice: caricare tutti i
DISPATCHED degli ultimi `max(workerTimeouts)` minuti, poi filtrare in Java per workerType.

### B5 — Test B

**File**: `control-plane/orchestrator/src/test/java/com/agentframework/orchestrator/orchestration/KillItemTest.java`
- `killItem_dispatchedItem_becomesFailedWithReason` — item DISPATCHED → FAILED("killed_by_operator")
- `killItem_completedItem_throwsIllegalTransition` — item DONE → IllegalStateTransitionException
- `killItem_waitingItem_becomesFailedWithReason` — item WAITING → FAILED

**File**: `control-plane/orchestrator/src/test/java/com/agentframework/orchestrator/config/StaleDetectorPropertiesTest.java`
- `timeoutFor_knownWorkerType_returnsSpecificTimeout` — AI_TASK → 120
- `timeoutFor_unknownWorkerType_returnsDefault` — REVIEW → 30 (default)

---

## Ordine di implementazione

```
A1 — AbstractWorker: wire Provenance.model (+ @Value defaultModelId)
A2 — OrchestrationService: verifica/fix CostEstimationService con modelId
A3 — PlanItemResponse: aggiungi modelId field
A4 — ProvenanceModelTest (2 test) + CostEstimationModelTest (2 test)

B1 — OrchestrationService: killItem() @Transactional
B2 — PlanController: POST /{id}/items/{itemId}/kill
B3 — StaleDetectorProperties.java (NEW ConfigurationProperties)
B4 — StaleTaskDetectorScheduler: per-workerType timeout con StaleDetectorProperties
B5 — application.yml: orchestrator.stale-detection block
B6 — KillItemTest (3 test) + StaleDetectorPropertiesTest (2 test)

FINALE — mvn test -pl execution-plane/worker-sdk,control-plane/orchestrator
       — PIANO_HISTORY.md session log S13
```

---

## File da creare/modificare

| Azione | File | Note |
|--------|------|------|
| MOD | `execution-plane/worker-sdk/.../AbstractWorker.java` | +@Value defaultModelId, wire Provenance.model (2 path) |
| MOD | `control-plane/orchestrator/.../OrchestrationService.java` | +killItem(), verifica CostEstimation |
| MOD | `control-plane/orchestrator/.../api/dto/PlanItemResponse.java` | +modelId field |
| MOD | `control-plane/orchestrator/.../api/PlanController.java` | +POST /{id}/items/{itemId}/kill |
| NEW | `control-plane/orchestrator/.../config/StaleDetectorProperties.java` | @ConfigurationProperties |
| MOD | `control-plane/orchestrator/.../orchestration/StaleTaskDetectorScheduler.java` | per-workerType timeout |
| MOD | `control-plane/orchestrator/src/main/resources/application.yml` | stale-detection config block |
| NEW | `execution-plane/worker-sdk/src/test/.../ProvenanceModelTest.java` | 2 test |
| NEW | `control-plane/orchestrator/src/test/.../budget/CostEstimationModelTest.java` | 2 test |
| NEW | `control-plane/orchestrator/src/test/.../orchestration/KillItemTest.java` | 3 test |
| NEW | `control-plane/orchestrator/src/test/.../config/StaleDetectorPropertiesTest.java` | 2 test |

**Totale**: 4 nuovi file + 7 file modificati. **~9 nuovi test**.

---

## Verifica end-to-end

```bash
# 1. Build orchestratore + worker-sdk
mvn test -pl execution-plane/worker-sdk,control-plane/orchestrator --offline
# Atteso: tutti i test verdi inclusi i 9 nuovi S13

# 2. Test specifici S13
mvn test -pl control-plane/orchestrator --offline \
  -Dtest="KillItemTest,StaleDetectorPropertiesTest,CostEstimationModelTest"
mvn test -pl execution-plane/worker-sdk --offline \
  -Dtest="ProvenanceModelTest"

# 3. Verifica endpoint kill (runtime)
curl -X POST http://localhost:8080/api/v1/plans/{id}/items/{itemId}/kill
# Atteso: 202 Accepted {"status":"killed","itemId":"...","planId":"..."}

# 4. Verifica PlanItemResponse.modelId nel monitoring dashboard
# GET /api/v1/plans/{id} → items[].modelId dovrebbe mostrare "claude-haiku-4-5-20251001" / null

# 5. Verifica Provenance.model nel risultato del task
# (visibile nel log del worker o via event store)
```
