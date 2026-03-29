# Piano: Analisi Funzionale — App Maze

## Contesto

Il progetto App Maze (`PIANO_APP_MAZE.md`) e' un gioco Android nativo (Kotlin + Jetpack Compose) di labirinti
generati proceduralmente. Il PIANO descrive architettura, algoritmi e fasi di lavoro (~25h, 7 fasi), ma ha
un livello di dettaglio "piano di sviluppo" — non la granularita' necessaria affinche' l'agent-framework
possa decomporlo in PlanItem concreti.

L'utente chiede di creare un documento **Analisi Funzionale** che funga da `spec` per l'agent-framework:
un input strutturato che il Planner (Claude) possa decomporre in task per i worker `mobile-kotlin`, con
dati sufficienti per CONTEXT_MANAGER e SCHEMA_MANAGER.

## Cosa cambia rispetto al PIANO

| PIANO | Analisi Funzionale |
|-------|-------------------|
| Vision e roadmap | Requisiti funzionali atomici (RF-001, RF-002...) |
| Snippet di esempio | Data model completo con relazioni e vincoli |
| "Fase 1-7" generiche | Use case con precondizioni, postcondizioni, flussi alternativi |
| Design hints | Specifiche di interfaccia (screen layout, navigation graph) |
| Checklist QA | Criteri di accettazione testabili per ogni requisito |

## File da creare

### `AF_APP_MAZE.md` (NUOVO)

Location: `/data/massimiliano/progetti_futuri/AF_APP_MAZE.md`

Naming convention: `AF_` prefix (Analisi Funzionale) parallelo al `PIANO_` prefix gia' usato.

### Struttura del documento

```markdown
# Analisi Funzionale — App Maze

## 1. Scope e Obiettivo
Descrizione progetto, target platform, vincoli.

## 2. Glossario
Termini di dominio (Cell, Maze, Seed, Wall Hit, Hint, Streak, etc.)

## 3. Architettura di Riferimento
Diagramma a layer (UI → ViewModel → Engine → Repository → Room DB)
Mappa ai worker types dell'agent-framework (MOBILE mobile-kotlin)

## 4. Requisiti Funzionali
Tabella RF-001..RF-N con: ID, titolo, descrizione, priorita', fase PIANO.
Raggruppati per area:
- RF-GEN: Generazione labirinto
- RF-RND: Rendering e visualizzazione
- RF-INP: Input e navigazione
- RF-GAM: Game logic (timer, punteggio, stelle)
- RF-PER: Persistenza (Room DB, statistiche, achievement)
- RF-AUD: Audio e haptic feedback
- RF-NAV: Navigazione tra schermate
- RF-SET: Impostazioni

## 5. Requisiti Non Funzionali
RNF-001..RNF-N: performance (generazione <150ms), compatibilita' (API 34),
framerate (60fps), offline-only, dimensione APK, accessibilita'.

## 6. Data Model
Entity-Relationship completo:
- Cell, Maze (runtime, non persistite)
- GameResult (Room @Entity)
- PlayerStats (Room @Entity, singleton)
- Achievement (enum + logica unlock)
- Difficulty (enum con parametri)
- UserSettings (DataStore preferences)

Con tipi Kotlin, annotazioni Room, vincoli, relazioni.

## 7. Use Case
UC-001..UC-N: formato strutturato
- Attore, Precondizione, Flusso principale, Flussi alternativi, Postcondizione
Use case principali:
- UC-001: Nuova partita
- UC-002: Movimento nel labirinto
- UC-003: Uso hint
- UC-004: Vittoria / timeout
- UC-005: Visualizza statistiche
- UC-006: Sblocco achievement
- UC-007: Modifica impostazioni
- UC-008: Daily challenge (backlog V2, opzionale)

## 8. Screen Specification
Per ogni screen (5 screen principali):
- Wireframe ASCII
- Composable di riferimento
- Stato osservato (StateFlow)
- Azioni utente
- Navigation route

## 9. Navigation Graph
Diagramma testuale del flusso tra screen con Compose Navigation.

## 10. Algoritmi
Pseudocodice formale per:
- Recursive Backtracking DFS (generazione)
- BFS shortest path (solver/hint)
- Formula punteggio
- Criterio stelle (3/2/1)
- Achievement unlock logic

## 11. Matrice Tracciabilita'
RF → UC → Screen → File sorgente atteso
Permette al Planner di mappare requisiti → task → worker.

## 12. Criteri di Accettazione
CA-001..CA-N: derivati dai requisiti, testabili.
Ogni CA mappa a 1+ RF e specifica condizioni pass/fail.

## 13. Vincoli e Dipendenze
SDK, librerie, asset, permessi Android.

## 14. Mapping Agent-Framework
Suggerimento esplicito di decomposizione per il Planner:
- Task MOBILE (mobile-kotlin): generazione, rendering, game logic, UI, persistenza, audio
- Task DBA (dba-sqlite): schema Room, migration
- Task REVIEW: quality gate
Ordine dipendenze tra task.
```

## File da modificare

### `INDICE.md` — nessuna modifica

L'INDICE traccia i PIANO, non le AF. L'AF e' un documento derivato che affianca il PIANO
nella stessa directory. Nessun impatto su altri file.

## Ordine di lavoro

1. Creare `AF_APP_MAZE.md` con tutte le 14 sezioni
2. Verificare coerenza con `PIANO_APP_MAZE.md` (nessuna contraddizione)
3. Verificare che ogni RF abbia almeno un CA associato
4. Verificare che la matrice tracciabilita' sia completa

## Dimensioni attese

~400-600 righe, ~20-30KB. Documento autocontenuto (non richiede lettura del PIANO per essere compreso).

## Verifica

- Il documento e' leggibile standalone (senza PIANO_APP_MAZE.md)
- Ogni requisito funzionale ha un ID univoco e un criterio di accettazione
- Il data model e' completo e coerente con gli snippet Kotlin del PIANO
- Gli use case coprono tutti i flussi utente descritti nella "Visione" del PIANO
- La sezione "Mapping Agent-Framework" suggerisce una decomposizione plausibile per worker `mobile-kotlin`
- Il Navigation Graph e' coerente con le screen elencate
- Nessuna informazione mancante che impedirebbe al Planner di generare PlanItem concreti
