# Piano: Fix empty state UI nella Compare view di Rank App

## Context
Dopo il fix per l'errore "need at least 2 items", la Compare view mostra uno stato vuoto quando la lista ha meno di 2 item. Il bottone "Add Items" si stretcha verticalmente occupando tutto lo spazio disponibile perche `.action-btn` ha `flex:1` (pensato per righe orizzontali in `.list-actions`) ma dentro `.empty-state` (flex column) diventa un'espansione verticale.

Screenshot: bottone blu alto circa 400px, aspetto rotto.

## Causa root
- `.empty-state` ha `flex:1` + `flex-direction:column` — occupa tutto lo spazio verticale
- `.action-btn` ha `flex:1` — dentro un flex column, cresce in altezza
- Lo stile inline `padding:12px 24px` non basta a contenere il `flex:1`

## Fix

### File: `proxy/home/rank-app/index.html`

1. **CSS** (riga ~213) — aggiungere regola per impedire stretch verticale dei bottoni dentro empty-state:
   `.empty-state .action-btn { flex:none }`
   Anche `.empty-state .add-btn { flex:none }` per sicurezza.

2. **JS** (riga ~615, `loadNextPair` catch block) — usare `.converged-box` invece di `.empty-state` per coerenza visiva con lo stato "Ranking Converged". Questo risolve il layout perche `.converged-box` ha stili propri (background, bordo, padding, text-align center) ed e progettata per contenuti centrati nella Compare view senza flex-grow.

   Struttura target: converged-box con icona (clipboard emoji), titolo "Not enough items", testo descrittivo, bottone "+ Add Items".

## Verifica
- Navigare a `/rank-app/`, aprire una lista con 0-1 item
- Il messaggio deve essere centrato, con bottone di dimensione normale (non stretchato)
- Testare su mobile (viewport 375px) — layout centrato e leggibile
- Confrontare visivamente con lo stato "Ranking Converged" (stessa box)
