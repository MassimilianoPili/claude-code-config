# Piano: Random cold start per convergenza veloce

## Contesto

Con 25 item, dopo 48 confronti il grafo e' ancora disconnesso (`graph_connected: false`,
`pairs_compared: 13/300`). L'IG-based selection tende a concentrarsi sulle stesse coppie
ad alta incertezza, lasciando molti item isolati. Risultato: convergenza lenta.

**Idea dell'utente**: fare un subset random iniziale per connettere il grafo velocemente,
poi passare all'IG per raffinare.

## Cosa fare

File: `preference-sort/scheduler.go` — modifica a `SelectNextPair()`

### Logica

Estendere il cold start: attualmente random solo per `len(comparisons) == 0`.
Nuovo comportamento: random per i primi N confronti, dove N = `len(items) - 1`.

Con N-1 confronti random tra coppie non ancora coperte, il grafo ha alta probabilita'
di essere connesso (spanning tree). Dopo di che, IG prende il controllo.

### Implementazione

Sostituire il blocco cold start (righe 31-47) con:

```go
// Cold start: per i primi N-1 confronti, seleziona coppie random
// tra quelle non ancora confrontate per connettere il grafo velocemente.
if len(comparisons) < n-1 {
    // Coppie non ancora confrontate
    seen := make(map[[2]int64]bool)
    for _, c := range comparisons {
        seen[orderedKey(c.ItemAID, c.ItemBID)] = true
    }
    var unseen [][2]int64
    for i := 0; i < n; i++ {
        for j := i + 1; j < n; j++ {
            key := orderedKey(items[i].ID, items[j].ID)
            if !seen[key] {
                unseen = append(unseen, [2]int64{items[i].ID, items[j].ID})
            }
        }
    }
    if len(unseen) > 0 {
        pick := unseen[rand.Intn(len(unseen))]
        // ... trova itemA, itemB, costruisci response
    }
}
```

Dopo il cold start, il flusso normale (IG + anti-ripetizione) prende il controllo.

---

## File da modificare

| File | Azione |
|------|--------|
| `preference-sort/scheduler.go` | Estendere cold start: random per primi N-1 confronti |

## Verifica

1. Rebuild container: `docker compose build && docker compose up -d --force-recreate`
2. Con lista nuova: primi 24 confronti sono random (coppie diverse)
3. Dal confronto 25 in poi: IG-based selection
4. Convergenza piu' rapida (grafo connesso entro ~24 confronti)
