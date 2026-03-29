# #19 — Retry manuale TO_DISPATCH

## Contesto

Attualmente il retry di task falliti avviene in due modi:
1. **AutoRetryScheduler**: automatico con backoff esponenziale (`FAILED → WAITING → dispatch`)
2. **`POST .../retry`**: endpoint manuale che fa `FAILED → WAITING → dispatchReadyItems()`

Entrambi passano per `WAITING` e quindi per la **dependency resolution** (`findDispatchableItems`).
Il task #19 aggiunge un nuovo stato `TO_DISPATCH` che permette re-dispatch **diretto**, senza
riattraversare la dependency resolution. Questo abilita:
- **Operator override**: l'operatore decide che il task va ri-eseguito, indipendentemente dallo stato dei dep
- **Re-run di task DONE**: non solo FAILED, anche task completati possono essere ri-lanciati
- **DB-level retry**: un DBA può fare `UPDATE plan_items SET status = 'TO_DISPATCH'` direttamente

## Differenza architetturale vs retry esistente

| | Retry esistente (`/retry`) | Redispatch nuovo (`/redispatch`) |
|---|---|---|
| Stato sorgente | Solo FAILED | FAILED o DONE |
| Transizione | FAILED → WAITING | FAILED/DONE → TO_DISPATCH → DISPATCHED |
| Dependency check | Si (via `findDispatchableItems`) | No (dispatch diretto) |
| Use case | Transient failure, auto-retry | Operator override, re-run dopo fix |

## Implementazione

### 1. `ItemStatus.java` — aggiungere `TO_DISPATCH`

```java
TO_DISPATCH {
    @Override public Set<ItemStatus> allowedTransitions() {
        return Set.of(DISPATCHED);
    }
},
```

Aggiornare anche le transizioni dei stati sorgente:
- `FAILED`: aggiungere `TO_DISPATCH` → `Set.of(WAITING, TO_DISPATCH)`
- `DONE`: aggiungere `TO_DISPATCH` → `Set.of(WAITING, TO_DISPATCH)`

Aggiornare il Javadoc del grafo di transizione in cima all'enum.

### 2. `OrchestrationService.java` — metodo `redispatchItem(UUID itemId)`

Nuovo metodo `@Transactional` che:
1. Carica item con plan (`findByIdWithPlan`)
2. Valida stato: deve essere `FAILED`, `DONE`, o già `TO_DISPATCH`
3. Se non è TO_DISPATCH, transisce a `TO_DISPATCH`
4. Pulisce: `failureReason=null`, `completedAt=null`
5. Riapre il plan se necessario (COMPLETED/FAILED/PAUSED → RUNNING)
6. **Dispatch diretto** (bypass dependency resolution):
   - Crea `DispatchAttempt` (attemptNum = max + 1)
   - Costruisce `AgentTask` (riusa `buildContextJson`, `buildDynamicOwnsPaths`)
   - Invia via `taskProducer.dispatch(task)`
   - Transisce `TO_DISPATCH → DISPATCHED`, setta `dispatchedAt`
   - Pubblica evento `TASK_DISPATCHED`
7. Salva attempt + item

Nota: la parte di dispatch riutilizza le stesse helper private già in `dispatchReadyItems` (righe 698-735).
Si salta: risk gate, Bayesian admission, market making (sono per dispatch automatico, non operator override).
Si include: ralph-loop feedback nel description, context JSON, dynamic ownsPaths, toolHints.

### 3. `PlanController.java` — endpoint `POST /{id}/items/{itemId}/redispatch`

```java
@PostMapping("/{id}/items/{itemId}/redispatch")
public ResponseEntity<?> redispatchItem(@PathVariable UUID id, @PathVariable UUID itemId) {
    // Calls orchestrationService.redispatchItem(itemId)
    // Returns 202 Accepted con status, itemId, planId, previousStatus
    // Catch IllegalStateTransitionException → 400
    // Catch IllegalStateException (not found) → 404
}
```

### 4. `PlanItemRepository.java` — query `findByStatusWithPlan`

```java
@Query("SELECT i FROM PlanItem i JOIN FETCH i.plan WHERE i.status = :status")
List<PlanItem> findByStatusWithPlan(@Param("status") ItemStatus status);
```

### 5. `RedispatchPollerService.java` (NUOVO) — safety net

Modellato su `AutoRetryScheduler`. Polls ogni 10s per item in `TO_DISPATCH` (rimasti bloccati,
e.g. da update DB manuale o crash mid-endpoint).

```java
@Component
public class RedispatchPollerService {
    @Scheduled(fixedDelayString = "${redispatch.poller-interval-ms:10000}")
    public void pollToDispatch() {
        List<PlanItem> items = planItemRepository.findByStatusWithPlan(ItemStatus.TO_DISPATCH);
        for (PlanItem item : items) {
            redispatchTransactionService.redispatchItem(item.getId());
        }
    }
}
```

### 6. `RedispatchTransactionService.java` (NUOVO) — tx isolation

Come `RetryTransactionService`, esegue ogni redispatch in una transazione indipendente (REQUIRES_NEW)
per evitare che un fallimento in un item faccia rollback degli altri.

```java
@Service
public class RedispatchTransactionService {
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void redispatchItem(UUID itemId) {
        orchestrationService.redispatchItem(itemId);
    }
}
```

## Test

### `ItemStatusTest.java` (NUOVO)
- `TO_DISPATCH` → `DISPATCHED` (allowed)
- `FAILED` → `TO_DISPATCH` (allowed)
- `DONE` → `TO_DISPATCH` (allowed)
- `WAITING` → `TO_DISPATCH` (NOT allowed)
- `TO_DISPATCH` → `FAILED` (NOT allowed)
- `TO_DISPATCH` → `WAITING` (NOT allowed)

### `RedispatchPollerServiceTest.java` (NUOVO)
- Polls TO_DISPATCH items and dispatches them
- Empty list → no-op
- Exception in one item doesn't block others

### `OrchestrationServiceTest.java` (MODIFICA)
- `redispatchItem_failedItem_dispatchesDirectly`
- `redispatchItem_doneItem_dispatchesDirectly`
- `redispatchItem_reopensCompletedPlan`
- `redispatchItem_unknownItem_throws`
- `redispatchItem_waitingItem_throwsIllegalTransition`

## Ordine di implementazione

1. `ItemStatus.java` — enum + transizioni
2. `PlanItemRepository.java` — query `findByStatusWithPlan`
3. `OrchestrationService.java` — metodo `redispatchItem`
4. `PlanController.java` — endpoint REST
5. `RedispatchTransactionService.java` — tx isolation (NUOVO)
6. `RedispatchPollerService.java` — poller (NUOVO)
7. Test: `ItemStatusTest`, `RedispatchPollerServiceTest`, `OrchestrationServiceTest`
8. Compile + full test suite + PIANO.md + commit

## File coinvolti

| File | Azione |
|------|--------|
| `domain/ItemStatus.java` | MODIFICA: +TO_DISPATCH enum, update FAILED/DONE transitions |
| `orchestration/OrchestrationService.java` | MODIFICA: +redispatchItem() method |
| `api/PlanController.java` | MODIFICA: +/redispatch endpoint |
| `repository/PlanItemRepository.java` | MODIFICA: +findByStatusWithPlan query |
| `orchestration/RedispatchPollerService.java` | NUOVO |
| `orchestration/RedispatchTransactionService.java` | NUOVO |
| `test/.../domain/ItemStatusTest.java` | NUOVO |
| `test/.../orchestration/RedispatchPollerServiceTest.java` | NUOVO |
| `test/.../orchestration/OrchestrationServiceTest.java` | MODIFICA: +redispatch tests |
| `PIANO.md` | MODIFICA: aggiornare stato #19 |

## Verifica

1. `mvn compile -pl control-plane/orchestrator`
2. `mvn test -pl control-plane/orchestrator -Dtest=ItemStatusTest,RedispatchPollerServiceTest,OrchestrationServiceTest`
3. `mvn test -pl control-plane/orchestrator` — full suite (511+ test)
4. Grep: `grep "TO_DISPATCH" .../ItemStatus.java` → match
5. Grep: `grep "redispatch" .../PlanController.java` → match
