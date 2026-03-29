# Piano Consolidato — AppMaze v3.x
## Sorgenti integrate: ancient-cooking-chipmunk + nested-tinkering-nest + clever-toasting-cosmos

---

## Stato reale del codebase (2026-03-08)

### Già fatto ✅
| File | Stato |
|------|-------|
| `domain/maze/InfiniteMazeManager.kt` | ✅ 305 righe — CHUNK_SIZE=32, SplitMix64+fmix64+Szudzik private, `storyChunkLambda` |
| `domain/theme/EmotionalPalette.kt` | ✅ EmotionalPhase, EmotionalColors, forProgress(), baseForDifficulty() |
| `ui/game/GameUiState.kt` | ✅ `isInfinite`, `worldOffsetRow/Col`, `completionProgress`, `emotionalPhase` |
| `ui/components/MazeCanvas.kt` | ✅ usa `EmotionalColors`, camera system, viewport culling |
| Story mode | ✅ StoryContent, StoryLoader, WorldEventManager (93r), StoryUiState, StoryViewModel (322r), StoryGameScreen (364r), StorySaveEntity, StorySaveDao |
| `ui/navigation/AppNavGraph.kt` | ✅ route STORY |
| `data/db/AppMazeDatabase.kt` | ✅ v2 con StorySaveEntity |

### Da sistemare / completare
| File | Intervento |
|------|-----------|
| `domain/maze/infinite/SplitMix64.kt` | ❌ DA ELIMINARE — duplicato di impl private in InfiniteMazeManager |
| `domain/maze/infinite/ChunkCoord.kt` | ❌ DA ELIMINARE — duplicato |
| `domain/maze/MazeGenerator.kt` | Aggiungere `INFINITE(width=-1, height=-1)` a DifficultyLevel |
| `ui/game/GameViewModel.kt` | Wire `InfiniteMazeManager` per `INFINITE` mode (dichiarato ma non usato) |
| `ui/components/MazeCanvas.kt` | Branch infinite: no exit cell, window-based (usa `InfiniteMazeManager.extractWindow()`) |
| `ui/screens/DifficultySelectionScreen.kt` | Card INFINITE ("∞ — Esplorazione libera") |

---

## FASE 1 — Wire INFINITE mode (immediatamente)

### 1.1 Cleanup
Eliminare `infinite/SplitMix64.kt` e `infinite/ChunkCoord.kt` — `InfiniteMazeManager` ha queste implementazioni come private. La directory `infinite/` va rimossa.

### 1.2 `MazeGenerator.kt` — aggiunge INFINITE
```kotlin
enum class DifficultyLevel(val width: Int, val height: Int, val label: String) {
    EASY(10, 10, "Facile"),
    MEDIUM(20, 20, "Medio"),
    HARD(30, 30, "Difficile"),
    EXPERT(40, 40, "Esperto"),
    EXTREME(100, 100, "Estremo"),
    INFINITE(-1, -1, "∞ Infinito"),
}
```

### 1.3 `GameViewModel.kt` — `startNewGame(INFINITE)`
Condizione su `difficulty == DifficultyLevel.INFINITE`:
```kotlin
if (difficulty == DifficultyLevel.INFINITE) {
    val seed = System.currentTimeMillis()
    infiniteMazeManager = InfiniteMazeManager(seed)
    val window = infiniteMazeManager!!.extractWindow(0, 0)
    _uiState.update {
        GameUiState(
            maze = window,
            isInfinite = true,
            worldOffsetRow = -InfiniteMazeManager.WINDOW_HALF,
            worldOffsetCol = -InfiniteMazeManager.WINDOW_HALF,
            playerRow = InfiniteMazeManager.WINDOW_HALF,
            playerCol = InfiniteMazeManager.WINDOW_HALF,
            difficulty = DifficultyLevel.INFINITE,
            // no exit → completionProgress sempre 0f (o basato su step)
        )
    }
    return
}
```

**Movimento in modalità infinita** (in `tryMoveToCell()`):
```kotlin
if (state.isInfinite && infiniteMazeManager != null) {
    val newWorldRow = state.worldOffsetRow + newRow
    val newWorldCol = state.worldOffsetCol + newCol
    val window = infiniteMazeManager!!.extractWindow(newWorldRow, newWorldCol)
    _uiState.update {
        it.copy(
            maze = window,
            playerRow = InfiniteMazeManager.WINDOW_HALF,
            playerCol = InfiniteMazeManager.WINDOW_HALF,
            worldOffsetRow = newWorldRow - InfiniteMazeManager.WINDOW_HALF,
            worldOffsetCol = newWorldCol - InfiniteMazeManager.WINDOW_HALF,
            stepCount = it.stepCount + 1,
        )
    }
    return
}
```

### 1.4 `MazeCanvas.kt` — branch infinita
Se `isInfinite == true` (passato come param):
- Nessun `drawExitCell`
- Nessuna logica fit-entire (sempre camera mode)
- Stessa logica di rendering esistente (la window è già centrata sul player)

### 1.5 `DifficultySelectionScreen.kt` — card INFINITE
Card speciale con `∞` come icona, subtitle "Esplorazione libera — nessun traguardo", descrizione "Labirinto infinito deterministico. Ogni seed produce lo stesso mondo."

---

## FASE 2 — Gap Story Mode (nested-tinkering-nest)

Dalla verifica del codebase tutti i file story esistono. Verificare che siano funzionali:
- [ ] `HomeScreen.kt` ha bottone "Story Mode"? (piano dice mancante `onStoryClick`)
- [ ] `AppNavGraph.kt` già ha route STORY (confermato ✅)
- [ ] `AppMazeApplication.kt` ha `storySaveDao` lazy?

Se HomeScreen manca `onStoryClick` (da verificare), aggiungere bottone.

---

## FASE 3 — Trasformazione Artistica (clever-toasting-cosmos, priorità)

Implementare da **Phase 0 + Phase 1** del piano clever-toasting-cosmos, in ordine:

### 3A — `GameEvent` sealed class in `GameViewModel.kt`
```kotlin
sealed class GameEvent {
    data class PlayerMoved(val col: Int, val row: Int) : GameEvent()
    data class WallHit(val direction: Direction) : GameEvent()
    object GameWon : GameEvent()
    object HintUsed : GameEvent()
    data class GlyphDiscovered(val glyph: String) : GameEvent()
    data class SecretRoomFound(val col: Int, val row: Int) : GameEvent()
}
private val _events = Channel<GameEvent>(Channel.BUFFERED)
val events: Flow<GameEvent> = _events.receiveAsFlow()
```

### 3B — `ui/animation/PlayerAnimator.kt` (nuovo file)
Squash/stretch: scala il player elliptically in direzione di movimento.
- `animateMove(direction): PlayerVisual` — ritorna (scaleX, scaleY, rotation)
- Base: 1.0×1.0; horizontal move: (1.2, 0.8); vertical: (0.8, 1.2); wall hit: (0.9, 0.9) pulsante

### 3C — Win Bloom animation in `MazeCanvas.kt`
Quando `gameStatus == GameStatus.WON` + `emotionalPhase == BLOOM`:
- Cerchi di bloom che si espandono dall'exit cell
- Color: `emotionalColors.particleColor` con alpha fade out

### 3D — `completionProgress` in `GameViewModel.kt`
Per maze finito: calcolato su Manhattan distance al goal / distanza iniziale.
```kotlin
val progress = 1f - (manhattanToExit.toFloat() / maxManhattan.toFloat())
```
Per INFINITE: basato su step count (es. `min(stepCount / 500f, 1f)`).

### 3E — Fase 2 prospettiva (defer se scope troppo grande)
`IsometricTransform.kt` + `PerspectiveRotation.kt` — solo se Phase 0-1 buildano bene.

---

## Ordine di implementazione

1. **Cleanup**: eliminare `infinite/SplitMix64.kt` + `infinite/ChunkCoord.kt`
2. **Fase 1.2**: `DifficultyLevel.INFINITE` in `MazeGenerator.kt`
3. **Fase 1.3**: `GameViewModel.startNewGame(INFINITE)` + movimento infinito
4. **Fase 1.4**: `MazeCanvas.kt` — branch infinite (no exit)
5. **Fase 1.5**: `DifficultySelectionScreen.kt` — card INFINITE
6. **Fase 2**: verificare HomeScreen + `onStoryClick`
7. **Fase 3A**: `GameEvent` sealed class
8. **Fase 3B**: `PlayerAnimator.kt`
9. **Fase 3C**: Win bloom
10. **Fase 3D**: `completionProgress` wiring
11. **Build**: `./gradlew assembleDebug` — 0 errori, APK funzionante

---

## Verifiche end-to-end

```bash
cd /data/massimiliano/appmaze
./gradlew assembleDebug

# Manuale APK:
# INFINITE: Seleziona ∞ → naviga N/S/E/W oltre 2 chunk (64+ celle) → nessun muro fantasma
# INFINITE: Riavvia app stessa seed → stessa mappa
# STORY: HomeScreen → Story Mode → esplora → trova falò → dialogo appare
# EMOTIONAL: difficoltà EASY → progresso → colori evolvono grigio→teal
# WIN BLOOM: raggiungi exit → animazione bloom
# NO CRASH: rotazione schermo in qualsiasi schermata
```

---

## Note architetturali

**InfiniteMazeManager è autoritativo**: CHUNK_SIZE=32, WINDOW_HALF=24 (window 48×48).
Non creare classi parallele in `infinite/` — tutto punta a questa classe.

**EmotionalPalette è autoritativa**: tutte le classi UI leggono da `EmotionalPalette.forProgress()`.
`GameViewModel` aggiorna `completionProgress` → `GameUiState` → `MazeCanvas` riceve `emotionalColors`.

**Story mode è separato da GameViewModel**: usa `StoryViewModel` proprio, `InfiniteMazeManager` con `storyChunkLambda`, e `StorySaveDao` proprio. Non mescolare le due logiche.
