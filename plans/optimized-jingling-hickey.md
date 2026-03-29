# Piano: Refactor MVC — Stato Unificato + Bug Fix

## Context

Dopo i 4 fix precedenti, restano 2 bug e 1 richiesta architetturale:

**Bug residui:**
1. **Timer non recuperato al resume** — mostra 0:00 finché non si fa il primo passo
2. **Flicker alle curve** — il wall fallback in `processDragMove()` può invertire la direzione

**Root cause di entrambi**: il pattern `syncFromEngine()` copia campo-per-campo da `EngineState` a `GameUiState`. Ogni campo dimenticato è un bug. `elapsedSeconds` manca da `syncFromEngine()`.

**Richiesta architetturale**: l'utente vuole:
- **Model** = stato unico, salvabile direttamente, su cui si lavora
- **Controller** = MazeEngine, opera sul Model
- **View** = Compose screens, leggono il Model
- **Determinismo**: dato uno stato (seed + posizione), il gioco è ripristinabile

---

## Fase A: Stato Unificato — `GameState` (Classic mode)

### A1: Nuovo `domain/model/GameState.kt`

Data class pura, **zero dipendenze Android**, contiene SOLO lo stato salvabile:

```kotlin
data class GameState(
    // Identità — determina come generare il labirinto
    val difficulty: DifficultyLevel,
    val mazeSeed: Long,
    val isInfinite: Boolean = false,

    // Posizione
    val playerRow: Int = 0,       // Griglia (finite) o canvas center (infinite)
    val playerCol: Int = 0,
    val worldRow: Int = 0,        // Solo infinite: posizione assoluta
    val worldCol: Int = 0,

    // Statistiche
    val stepCount: Int = 0,
    val elapsedSeconds: Int = 0,
    val peeksUsed: Int = 0,
    val maxPeeks: Int = 3,

    // Trail (coordinate griglia per finite, mondo per infinite)
    val path: List<Pair<Int, Int>> = emptyList(),

    // Camera
    val zoomScale: Float = 1f,

    // Flusso di gioco
    val gameStatus: GameStatus = GameStatus.PLAYING,
)
```

**Proprietà chiave**: tutto ciò che serve per salvare + ripristinare. Il maze grid è **derivato** (seed + dimensioni → generatore deterministico), non salvato.

### A2: Refactor `EngineState` → wrappa `GameState`

In `domain/engine/MazeEngine.kt`:

```kotlin
data class EngineState(
    val game: GameState,
    // Derivati (non salvati, ricostruiti da seed)
    val maze: List<List<MazeCell>> = emptyList(),
    val mazeWidth: Int = -1,
    val mazeHeight: Int = -1,
    val windowHalf: Int = InfiniteMazeManager.WINDOW_HALF,
    val worldOffsetRow: Int = 0,
    val worldOffsetCol: Int = 0,
    // Settings (da SettingsManager, non dal save)
    val soundEnabled: Boolean = true,
    val hapticEnabled: Boolean = true,
    val pinchPeekEnabled: Boolean = true,
    val emotionalPaletteEnabled: Boolean = false,
    val trailEnabled: Boolean = true,
    val winBloomEnabled: Boolean = true,
)
```

Ogni `.copy()` dentro MazeEngine che tocca campi di `GameState` diventa:
```kotlin
// PRIMA: _state = _state.copy(playerRow = x, stepCount = _state.stepCount + 1)
// DOPO:  _state = _state.copy(game = _state.game.copy(playerRow = x, stepCount = _state.game.stepCount + 1))
```

### A3: Refactor `GameUiState` → wrappa `GameState`

```kotlin
data class GameUiState(
    // Core — copiato atomicamente da engine.state.game
    val game: GameState = GameState(),

    // Derivati dal maze (ricostruiti, non salvati)
    val maze: List<List<MazeCell>> = emptyList(),
    val windowHalf: Int = 0,
    val worldOffsetRow: Int = 0,
    val worldOffsetCol: Int = 0,

    // UI-only (non salvati)
    val completionProgress: Float = 0f,
    val emotionalPhase: EmotionalPhase = EmotionalPhase.DORMANT,
    val finalScore: Int = 0,
    val errorMessage: String? = null,

    // Settings (da SettingsManager)
    val soundEnabled: Boolean = true,
    val hapticEnabled: Boolean = true,
    val emotionalPaletteEnabled: Boolean = false,
    val trailEnabled: Boolean = true,
    val winBloomEnabled: Boolean = true,
    val pinchPeekEnabled: Boolean = true,
)
```

**Property accessors** di convenienza (evitano `uiState.game.playerRow` ovunque nella View):
```kotlin
val playerRow get() = game.playerRow
val playerCol get() = game.playerCol
val stepCount get() = game.stepCount
val elapsedSeconds get() = game.elapsedSeconds
val gameStatus get() = game.gameStatus
val difficulty get() = game.difficulty
val isInfinite get() = game.isInfinite
val peeksUsed get() = game.peeksUsed
val maxPeeks get() = game.maxPeeks
val zoomScale get() = game.zoomScale
val mazeSeed get() = game.mazeSeed
val path get() = game.path
```

### A4: `syncFromEngine()` diventa atomico

```kotlin
private fun syncFromEngine() {
    val es = engine.state
    _uiState.value = _uiState.value.copy(
        game = es.game,                          // ← TUTTO lo stato in un colpo
        maze = es.maze,
        windowHalf = es.windowHalf,
        worldOffsetRow = es.worldOffsetRow,
        worldOffsetCol = es.worldOffsetCol,
        soundEnabled = es.soundEnabled,
        hapticEnabled = es.hapticEnabled,
        emotionalPaletteEnabled = es.emotionalPaletteEnabled,
        trailEnabled = es.trailEnabled,
        winBloomEnabled = es.winBloomEnabled,
        pinchPeekEnabled = es.pinchPeekEnabled,
    )
}
```

**Impossibile dimenticare un campo di GameState** — è un blocco unico.

### A5: `GameStateEntity` ↔ `GameState` mappers

In `data/db/entity/GameStateEntity.kt`, aggiungere:

```kotlin
companion object {
    fun fromGameState(state: GameState): GameStateEntity = GameStateEntity(
        difficulty = state.difficulty.name,
        mazeJson = "",  // Finite: serializzato separatamente; Infinite: vuoto
        playerRow = state.playerRow,
        playerCol = state.playerCol,
        stepCount = state.stepCount,
        elapsedSeconds = state.elapsedSeconds,
        peeksUsed = state.peeksUsed,
        pathJson = MazeSerializer.serializeTrail(state.path),
        mazeSeed = state.mazeSeed,
        isInfinite = state.isInfinite,
        worldRow = state.worldRow,
        worldCol = state.worldCol,
        zoomScale = state.zoomScale,
        savedAt = System.currentTimeMillis(),
    )
}

fun toGameState(): GameState = GameState(
    difficulty = DifficultyLevel.valueOf(difficulty),
    mazeSeed = mazeSeed,
    isInfinite = isInfinite,
    playerRow = playerRow,
    playerCol = playerCol,
    worldRow = worldRow,
    worldCol = worldCol,
    stepCount = stepCount,
    elapsedSeconds = elapsedSeconds,
    peeksUsed = peeksUsed,
    maxPeeks = 3,
    path = MazeSerializer.deserializeTrail(pathJson),
    zoomScale = zoomScale,
    gameStatus = GameStatus.PLAYING,
)
```

### A6: `saveCurrentState()` semplificato

```kotlin
private fun saveCurrentState() {
    if (!::engine.isInitialized) return
    val game = engine.state.game
    if (game.gameStatus == GameStatus.WON) return
    if (engine.state.maze.isEmpty()) return
    if (game.difficulty == DifficultyLevel.DAILY) return

    val entity = GameStateEntity.fromGameState(game).let {
        // Finite: serializziamo anche il maze grid (per non rigenerare)
        if (!game.isInfinite) it.copy(mazeJson = MazeSerializer.serializeMaze(engine.state.maze))
        else it
    }
    saveScope.launch { gameRepository.saveGameState(entity) }
}
```

### A7: `loadSavedGame()` usa `toGameState()`

```kotlin
fun loadSavedGame(difficulty: DifficultyLevel) {
    viewModelScope.launch {
        val saved = gameRepository.getSavedGame(difficulty.name) ?: return@launch
        try {
            val gameState = saved.toGameState()

            engine = if (gameState.isInfinite) {
                val mgr = InfiniteMazeManager(gameState.mazeSeed, ...)
                MazeEngine.infinite(scope, mgr, settingsManager,
                    startRow = gameState.worldRow, startCol = gameState.worldCol,
                    initialGameState = gameState)
            } else {
                val maze = MazeSerializer.deserializeMaze(saved.mazeJson) ?: throw ...
                MazeEngine.finiteFromState(scope, settingsManager,
                    maze = maze, initialGameState = gameState)
            }
            // ... setup, sync
        } catch ...
    }
}
```

### A8: `updateZoomScale()` agisce su GameState

```kotlin
fun updateZoomScale(scale: Float) {
    // Aggiorna engine.state.game direttamente
    engine.updateGameState { it.copy(zoomScale = scale) }
    syncFromEngine()
}
```

Nuovo metodo in MazeEngine:
```kotlin
fun updateGameState(transform: (GameState) -> GameState) {
    _state = _state.copy(game = transform(_state.game))
}
```

---

## Fase B: Fix Flicker — Anti-backtrack

### Root cause

Il wall fallback in `processDragMove()` può muovere il giocatore INDIETRO (nella cella da cui è appena arrivato). Alle curve strette, il dito ha una piccola componente nella direzione opposta → fallback inverte → flicker.

### Fix

Aggiungere `lastMoveDir: Pair<Int, Int>?` a `processDragMove()` e a `DragMoveResult`:

```kotlin
data class DragMoveResult(
    val adjustX: Float,
    val adjustY: Float,
    val moveDir: Pair<Int, Int>,  // NUOVO: (dRow, dCol) del move eseguito
)

fun processDragMove(
    dragDx: Float, dragDy: Float,
    dragThreshold: Float, cellSize: Float,
    tryMove: (dRow: Int, dCol: Int) -> Boolean,
    lastMoveDir: Pair<Int, Int>? = null,  // NUOVO: direzione ultimo move
): DragMoveResult? {
    // ... calcolo primario/secondario invariato ...

    // Try primary direction (skip if it would reverse last move)
    val isReversePrimary = lastMoveDir != null && dRow == -lastMoveDir.first && dCol == -lastMoveDir.second
    var moved = if (!isReversePrimary) tryMove(dRow, dCol) else false

    // Wall fallback: skip if it would reverse last move
    if (!moved && secondary > 0f) {
        val (dRow2, dCol2) = ...
        val isReverseFallback = lastMoveDir != null && dRow2 == -lastMoveDir.first && dCol2 == -lastMoveDir.second
        if (!isReverseFallback) {
            moved = tryMove(dRow2, dCol2)
            movedDRow = dRow2; movedDCol = dCol2
        }
    }

    if (!moved) return null
    return DragMoveResult(adjustX, adjustY, movedDRow to movedDCol)
}
```

Nei caller (MazeGameScreen, StoryGameScreen):
```kotlin
var lastMoveDir: Pair<Int, Int>? = null  // dentro awaitEachGesture, resettato per gesture

val result = processDragMove(
    dragDx, dragDy, dragThreshold, currentCellSize,
    tryMove = { dRow, dCol -> viewModel.tryMoveToCell(...) },
    lastMoveDir = lastMoveDir,
)
if (result != null) {
    lastFingerX += result.adjustX
    lastFingerY += result.adjustY
    lastMoveDir = result.moveDir
}
```

---

## Fase C: Story Mode (futura, non in questo piano)

Story mode ha complicazioni aggiuntive (worldTrail, campfire save, StoryEvent). L'unificazione con `GameState` richiede un `StoryState extends GameState` o un approccio diverso. Rinviata.

---

## File da modificare

| File | Modifica |
|------|----------|
| `domain/model/GameState.kt` | **NUOVO** — stato unificato |
| `domain/engine/MazeEngine.kt` | `EngineState` wrappa `GameState`, factory methods accettano `GameState`, nuovo `updateGameState()` |
| `data/db/entity/GameStateEntity.kt` | Aggiungere `fromGameState()` / `toGameState()` |
| `ui/game/GameUiState.kt` | Wrappa `GameState` + property accessors |
| `ui/game/GameViewModel.kt` | `syncFromEngine()` atomico, `saveCurrentState()` via mapper, `loadSavedGame()` via mapper |
| `ui/components/MazeGestureHandler.kt` | Anti-backtrack: `lastMoveDir` param + `moveDir` in result |
| `ui/components/MazeGameScreen.kt` | Traccia `lastMoveDir`, legge da restructured state |
| `ui/story/StoryGameScreen.kt` | Traccia `lastMoveDir` (solo fix flicker, no refactor stato) |

## Ordine implementazione

1. **GameState** — nuovo file, nessuna dipendenza
2. **EngineState refactor** — wrappa GameState, aggiorna tutti i `.copy()` interni
3. **GameUiState refactor** — wrappa GameState + property accessors
4. **GameViewModel refactor** — syncFromEngine atomico, save/load via mapper
5. **GameStateEntity mappers** — fromGameState/toGameState
6. **Anti-backtrack** — MazeGestureHandler + entrambi gli screen
7. **Build + test**

## Verifica

- **Timer al resume**: Classic → gioca 30s → pausa → esci → rientra → "Continua" → timer mostra ~30s subito (senza muoversi)
- **Flicker**: Qualsiasi → trascina lungo un corridoio a U → nessun avanti-indietro
- **Zoom**: Classic finite → zooma → pausa → esci → rientra → zoom preservato
- **Save/restore completo**: Classic → gioca → esci → rientra → TUTTI i campi ripristinati (posizione, passi, tempo, peek, zoom, trail)
- **Determinismo**: dato `mazeSeed` + `difficulty` + `playerRow/Col` → stato ricostruibile
- **DAILY**: nessun dialog resume
- **Build**: `./gradlew assembleDebug` + `./gradlew testDebugUnitTest`
