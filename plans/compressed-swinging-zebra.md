# Fix B19 — DispatchAttempt orfani (non-unique result)

## Contesto

Bug di at-least-once delivery: ogni retry crea un nuovo `DispatchAttempt` senza chiudere
i precedenti. La query `findOpenAttempt` con `Optional<T>` esplode con
`IncorrectResultSizeDataAccessException` quando ci sono 2+ attempt aperti.

**Fix immediato già applicato**: `ORDER BY a.attemptNumber DESC LIMIT 1` nella query
(riga 18-19 di `DispatchAttemptRepository.java`). La query ora restituisce solo il più recente.

## Modifiche al PIANO.md

1. **Tabella bug**: aggiungere B19 dopo B17 (riga 479) con:
   - Descrizione del bug (non-unique result su findOpenAttempt)
   - File coinvolti (DispatchAttemptRepository, OrchestrationService)
   - Fix applicato (LIMIT 1) + fix strutturale futuro (cleanup orfani in retryFailedItem)

2. **Tabella priorità**: aggiungere B19 dopo B18 (riga 442) con:
   - Sforzo: 0.5g (fix query: ✅ fatto, cleanup orfani: futuro)
   - Impatto: Alto (senza fix, il piano si blocca — cascata B1→B3)
   - Fix query LIMIT 1 già applicato

## File da modificare

| File | Modifica |
|------|----------|
| `PIANO.md` | Aggiungere B19 in tabella bug (dopo B17, riga 479) + tabella priorità (dopo B18, riga 442) |
