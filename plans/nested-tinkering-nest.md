# A Maze Story — v3.0 aMazeStory

## Contesto
- **v2.2 EmotionalPalette**: COMPLETATA (commit `ac82d41`) + rename "A Maze Story" (`f5f7eb2`)
- **Codebase**: `/data/massimiliano/appmaze/`
- **v3.0 — aMazeStory**: modalità narrativa su `InfiniteMazeManager` (già scritto). Player esplora
  labirinto infinito, trova falò/NPC piazzati deterministicamente. Narrativa da JSON in assets.
  Persistenza Room. EmotionalPalette con progress = eventsVisited / totalEvents.

---

## Stato attuale del codebase (esplorazione 2026-03-08)

### Già pronti
| File | Stato |
|------|-------|
| `domain/maze/InfiniteMazeManager.kt` | ✅ completo (277 righe). SplitMix64 + fmix64 + Szudzik **private** inner class/methods |
| `domain/theme/EmotionalPalette.kt` | ✅ completo (v2.2) |
| `data/db/AppMazeDatabase.kt` | ✅ v1, 2 entity, `fallbackToDestructiveMigration()` già attivo |
| `data/db/entity/` | ✅ `GameScoreEntity`, `GameStateEntity` |
| Room deps in `build.gradle.kts` | ✅ già presenti (`room.runtime`, `room.ktx`, `room.compiler` via KSP) |
| `AppMazeApplication.kt` | ✅ lazy: `database`, `gameRepository`, `settingsManager` |
| `ui/navigation/AppNavGraph.kt` | ✅ 5 route (HOME, DIFFICULTY, GAME, GAME_OVER, LEADERBOARD) |
| `ui/screens/HomeScreen.kt` | ✅ ha `onContinueClick`/`hasSavedGame` ma manca `onStoryClick` |

### Da creare (8 nuovi file)
| File | Fase |
|------|------|
| `domain/story/StoryContent.kt` | A |
| `domain/story/WorldEventManager.kt` | A |
| `domain/story/StoryLoader.kt` | A |
| `app/src/main/assets/story.json` | A |
| `ui/story/StoryUiState.kt` | B |
| `ui/story/StoryViewModel.kt` | B |
| `ui/story/StoryGameScreen.kt` | B |
| `data/db/entity/StorySaveEntity.kt` | C |
| `data/db/dao/StorySaveDao.kt` | C |

### Da modificare (5 file)
| File | Modifica |
|------|----------|
| `domain/maze/InfiniteMazeManager.kt` | Aggiungere `storyChunkLambda` + open room post-pass |
| `ui/screens/HomeScreen.kt` | Aggiungere bottone "Story Mode" (`onStoryClick`) |
| `ui/navigation/AppNavGraph.kt` | Route `"story"` + wiring `onStoryClick` in HomeScreen |
| `data/db/AppMazeDatabase.kt` | version 1→2, aggiungere `StorySaveEntity` + `StorySaveDao` |
| `AppMazeApplication.kt` | Aggiungere `storyRepository` lazy |

---

## Fase A — Foundation (solo logica, nessuna UI)

### 1. `domain/story/StoryContent.kt`
```kotlin
package com.massimiliano.appmaze.domain.story

import org.json.JSONArray
import org.json.JSONObject

data class DialogueLine(val speaker: String, val text: String)

data class StoryEvent(
    val id: Int,
    val type: String,          // "campfire" | "npc"
    val title: String,
    val lines: List<String> = emptyList(),
    val dialogue: List<DialogueLine> = emptyList(),
    val requires: List<Int> = emptyList(),
)

data class StoryManifest(val version: Int, val events: List<StoryEvent>)
```
Parsing via `org.json` (Android built-in, zero nuove dipendenze).

### 2. `app/src/main/assets/story.json` (MVP: 5 eventi)
```json
{
  "version": 1,
  "events": [
    {
      "id": 1, "type": "campfire", "title": "Frammento I — L'inizio",
      "lines": [
        "Il labirinto si estende oltre ciò che l'occhio può vedere.",
        "Qualcuno ti ha lasciato qui. O forse ci sei entrato da solo."
      ], "requires": []
    },
    {
      "id": 2, "type": "npc", "title": "Il Guardiano",
      "dialogue": [
        {"speaker": "Guardiano", "text": "Sei ancora qui."},
        {"speaker": "Guardiano", "text": "Il labirinto cambia, ma il centro rimane."}
      ], "requires": [1]
    },
    {
      "id": 3, "type": "campfire", "title": "Frammento II — La mappa",
      "lines": [
        "Non esiste una mappa. Il labirinto è la mappa.",
        "Ogni passo cancella il precedente."
      ], "requires": []
    },
    {
      "id": 4, "type": "npc", "title": "La Voce",
      "dialogue": [
        {"speaker": "Voce", "text": "Hai trovato questo posto da solo?"},
        {"speaker": "Voce", "text": "Pochi ci riescono. Meno ancora tornano."}
      ], "requires": [3]
    },
    {
      "id": 5, "type": "campfire", "title": "Frammento III — L'eco",
      "lines": [
        "Il silenzio qui ha una texture.",
        "Come se le pareti ricordassero chi le ha percorse."
      ], "requires": []
    }
  ]
}
```

### 3. `domain/story/StoryLoader.kt`
```kotlin
object StoryLoader {
    fun load(context: Context): StoryManifest {
        val json = context.assets.open("story.json").bufferedReader().readText()
        return parseManifest(JSONObject(json))
    }

    private fun parseManifest(obj: JSONObject): StoryManifest {
        val events = obj.getJSONArray("events").let { arr ->
            List(arr.length()) { parseEvent(arr.getJSONObject(it)) }
        }
        return StoryManifest(version = obj.getInt("version"), events = events)
    }

    private fun parseEvent(obj: JSONObject): StoryEvent { /* org.json parsing */ }
}
```

### 4. `domain/story/WorldEventManager.kt`
**Algoritmo POI placement** — super-celle N×N chunk, un story chunk per super-cella.
`supercellSize` è configurabile: più alto = falò più rari. Default 100 = ~3200 celle = ~213 viewport
a 15 celle. Questo obbliga il giocatore a usare il dezoom per orientarsi — il pinch-peek diventa
uno strumento narrativo, non solo tattico.

Relazione tra parametri (con CHUNK_SIZE=32, viewport=15):
| supercellSize | celle tra falò | viewport widths |
|---|---|---|
| 6 | 192 | ~13 |
| 8 | 256 | ~17 |
| 20 | 640 | ~43 |
| **100** | **3200** | **~213** (default) |

```kotlin
class WorldEventManager(
    private val worldSeed: Long,
    val events: List<StoryEvent>,
    val supercellSize: Int = 100,  // ← raro per design: falò come vera scoperta
) {
    companion object {
        private const val MAGIC_STORY = 0xC0FFEE42DEADL
    }

    /**
     * Determina se il chunk (cx,cy) è uno "story chunk".
     * Ogni super-cella [supercellSize×supercellSize] ha esattamente un story chunk.
     * Garantisce: max distanza tra falò ~supercellSize chunk, min ≥ 1 chunk.
     */
    fun isStoryChunk(cx: Int, cy: Int): Boolean {
        val sc = supercellSize
        val scx = Math.floorDiv(cx, sc)
        val scy = Math.floorDiv(cy, sc)
        val h = fmix64(worldSeed xor szudzikPair(scx, scy) xor MAGIC_STORY)
        val localCx = ((h.toInt() and 0x7FFFFFFF) % sc)
        val localCy = ((h.ushr(32).toInt() and 0x7FFFFFFF) % sc)
        return cx == scx * sc + localCx && cy == scy * sc + localCy
    }

    /**
     * Ritorna l'evento associato a questo story chunk.
     * Ordine: Manhattan distance dell'origine super-cella, ciclico su events.
     */
    fun getEventForChunk(cx: Int, cy: Int): StoryEvent {
        val sc = supercellSize
        val scx = Math.floorDiv(cx, sc)
        val scy = Math.floorDiv(cy, sc)
        val dist = Math.abs(scx) + Math.abs(scy)
        return events[dist % events.size]
    }

    // fmix64 + szudzikPair: copie locali (InfiniteMazeManager le ha private)
    private fun fmix64(h: Long): Long { /* ... MurmurHash3 finalizer ... */ }
    private fun szudzikPair(x: Int, y: Int): Long { /* ... Szudzik pairing ... */ }
}
```

### 5. Modifica `domain/maze/InfiniteMazeManager.kt`
Aggiungere `storyChunkLambda` al costruttore e open-room post-pass in `generateChunk()`:
```kotlin
class InfiniteMazeManager(
    val seed: Long,
    private val storyChunkLambda: ((cx: Int, cy: Int) -> Boolean)? = null,
)

// In generateChunk(), DOPO la fase DFS:
if (storyChunkLambda?.invoke(cx, cy) == true) {
    val c = n / 2  // centro del chunk (16 per CHUNK_SIZE=32)
    for (r in c - 2..c + 2) {
        for (col in c - 2..c + 2) {
            if (col < c + 2) {
                cells[r][col].rightWall = false
                cells[r][col + 1].leftWall = false
            }
            if (r < c + 2) {
                cells[r][col].bottomWall = false
                cells[r + 1][col].topWall = false
            }
        }
    }
}
```
**Nota**: rimuovere muri su uno spanning tree aggiunge solo loop (non rompe la connettività).
Il centro del chunk (16,16) è raggiungibile dal DFS per costruzione.

---

## Fase B — Gameplay Screen

### 6. `ui/story/StoryUiState.kt`
```kotlin
enum class StoryStatus { PLAYING, EVENT_ACTIVE, PAUSED }

data class StoryUiState(
    val maze: List<List<MazeCell>> = emptyList(),
    val playerCanvasRow: Int = InfiniteMazeManager.WINDOW_HALF,
    val playerCanvasCol: Int = InfiniteMazeManager.WINDOW_HALF,
    val worldRow: Int = 0,
    val worldCol: Int = 0,
    val worldOffsetRow: Int = 0,
    val worldOffsetCol: Int = 0,
    val stepCount: Int = 0,
    val elapsedSeconds: Int = 0,
    val status: StoryStatus = StoryStatus.PLAYING,
    val activeEvent: StoryEvent? = null,
    val dialogueIndex: Int = 0,
    val visitedEventIds: Set<Int> = emptySet(),
    val emotionalColors: EmotionalColors = EmotionalPalette.forProgress(0f, DifficultyLevel.EASY),
    val errorMessage: String? = null,
)
```

### 7. `ui/story/StoryViewModel.kt`
**Responsabilità**:
- `init`: load manifest → init `WorldEventManager(seed, events, supercellSize=100)` → init `InfiniteMazeManager(seed, wem::isStoryChunk)` → load saved state o start fresh → extract window → start timer
- `tryMove(dRow, dCol)`: world coordinate move → validate muri via `infiniteMaze.getCell()` → update state → `afterMove()`
- `afterMove()`: `ensureChunksAround()` → check se in story chunk → se sì, activate event
- `isInStoryChunk()`: chunk corrente = `floorDiv(worldRow, CHUNK_SIZE)` — controlla `wem.isStoryChunk(cx, cy)` E player nella stanza (localRow/Col in `c-2..c+2`)
- `advanceDialogue()` / `dismissEvent()`: avanza dialogo o chiude evento, aggiorna `visitedEventIds`, aggiorna progress EmotionalPalette, auto-save
- `autoSave()`: scrive `StorySaveEntity` su Room (ogni 50 passi + ad ogni evento)
- **Progress EmotionalPalette**: `visitedEventIds.size.toFloat() / manifest.events.size`
  → `EmotionalPalette.forProgress(progress, DifficultyLevel.EASY)` (story mode usa sempre base EASY)

**Wiring InfiniteMazeManager**:
```kotlin
private val infiniteMaze = InfiniteMazeManager(seed, worldEventManager::isStoryChunk)
```

**Estrazione window + camera**:
```kotlin
val window = infiniteMaze.extractWindow(worldRow, worldCol)
val windowHalf = InfiniteMazeManager.WINDOW_HALF
// playerCanvasRow/Col = sempre WINDOW_HALF (centro fisso nel canvas)
// worldOffsetRow = worldRow - windowHalf
// worldOffsetCol = worldCol - windowHalf
```

**MazeCanvas params per story mode** (camera fissa sul centro del canvas):
```kotlin
MazeCanvas(
    maze = uiState.maze,
    playerRow = uiState.playerCanvasRow,
    playerCol = uiState.playerCanvasCol,
    emotionalColors = uiState.emotionalColors,
    fitEntireMaze = false,
    cameraOffsetX = windowHalf * cellSize + cellSize / 2f,  // centro canvas
    cameraOffsetY = windowHalf * cellSize + cellSize / 2f,
    cameraScale = 1f,
)
```
In realtà la camera è centrata sul player che è sempre al centro del canvas → `cameraOffsetX/Y` puntano al centro della window. MazeCanvas calcola `originX = size.width/2f - cameraOffsetX * scale` → player centrato.

### 8. `ui/story/StoryGameScreen.kt`
- `MazeCanvas` con `fitEntireMaze=false`, swipe/drag come in `MazeGameScreen`
- Overlay event dialog: `AlertDialog` con titolo, testo/dialogo, pulsante avanza/chiudi
- Stats bar: step count, timer, eventi visitati (es. "2/5 🔥")
- Pausa: pulsante back → salva stato

---

## Fase C — Navigazione + Persistenza

### 9. `data/db/entity/StorySaveEntity.kt`
```kotlin
@Entity(tableName = "story_saves")
data class StorySaveEntity(
    @PrimaryKey val id: Int = 0,   // slot singolo
    val worldSeed: Long,
    val worldRow: Int,
    val worldCol: Int,
    val stepCount: Int,
    val elapsedSeconds: Int,
    val visitedEventIds: String,   // JSON: "[1,3]"
    val savedAt: Long,
)
```

### 10. `data/db/dao/StorySaveDao.kt`
```kotlin
@Dao
interface StorySaveDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun save(state: StorySaveEntity)

    @Query("SELECT * FROM story_saves WHERE id = 0")
    suspend fun load(): StorySaveEntity?

    @Query("DELETE FROM story_saves WHERE id = 0")
    suspend fun delete()

    @Query("SELECT COUNT(*) > 0 FROM story_saves WHERE id = 0")
    suspend fun hasSave(): Boolean
}
```

### 11. `data/db/AppMazeDatabase.kt` — version 1→2
```kotlin
@Database(
    entities = [GameScoreEntity::class, GameStateEntity::class, StorySaveEntity::class],
    version = 2,  // ← bump
    exportSchema = false
)
abstract class AppMazeDatabase : RoomDatabase() {
    abstract fun gameScoreDao(): GameScoreDao
    abstract fun gameStateDao(): GameStateDao
    abstract fun storySaveDao(): StorySaveDao
    // ... singleton invariato (fallbackToDestructiveMigration già attivo)
}
```
**fallbackToDestructiveMigration() già presente** → nessuna migration manuale necessaria.

### 12. `AppMazeApplication.kt`
```kotlin
val storySaveDao by lazy { database.storySaveDao() }
```
(il ViewModel crea il proprio StoryRepository localmente — è semplice, non serve una classe separata)

### 13. `ui/screens/HomeScreen.kt` — aggiungere bottone Story Mode
```kotlin
fun HomeScreen(
    onPlayClick: () -> Unit,
    onLeaderboardClick: () -> Unit,
    onStoryClick: () -> Unit,        // ← NUOVO
    onContinueClick: (() -> Unit)? = null,
    hasSavedGame: Boolean = false
)
// Aggiungere bottone "Story Mode" (OutlinedButton o Button di colore secondario)
// tra "New Game" e "Leaderboard"
```

### 14. `ui/navigation/AppNavGraph.kt` — route story
```kotlin
object AppMazeRoutes {
    const val STORY = "story"   // ← aggiunto
}

// In HomeScreen composable:
HomeScreen(
    onPlayClick = { ... },
    onStoryClick = { navController.navigate(AppMazeRoutes.STORY) { launchSingleTop = true } },
    onLeaderboardClick = { ... }
)

// Nuovo composable:
composable(AppMazeRoutes.STORY) {
    StoryGameScreen(
        onBackClick = { navController.popBackStack() }
    )
}
```

---

## Fase D — Build e commit

```bash
cd /data/massimiliano/appmaze
./gradlew clean assembleDebug
cp app/build/outputs/apk/debug/app-debug.apk apks/AMazeStory-v3.0.apk
git add app/src/main/kotlin/ app/src/main/assets/ apks/
git commit -m "feat: v3.0 aMazeStory — infinite world narrative mode"
git push origin main
```

---

## Sequenza implementazione

1. `StoryContent.kt` — data classes (usa `org.json`, zero nuove dipendenze)
2. `story.json` — 5 eventi in assets
3. `StoryLoader.kt` — parsing assets
4. `WorldEventManager.kt` — isStoryChunk + getEventForChunk (include copie locali fmix64/szudzik)
5. `InfiniteMazeManager.kt` — aggiungere `storyChunkLambda` + open-room post-pass
6. `StorySaveEntity.kt` + `StorySaveDao.kt`
7. `AppMazeDatabase.kt` — version 2 + StorySaveEntity
8. `AppMazeApplication.kt` — `storySaveDao` lazy
9. `StoryUiState.kt`
10. `StoryViewModel.kt` — logica completa
11. `StoryGameScreen.kt` — canvas + event dialog + stats bar
12. `HomeScreen.kt` — aggiungere `onStoryClick` + bottone
13. `AppNavGraph.kt` — route STORY
14. Build + APK + commit + push

---

## Verifica

- [ ] Story chunk visibile nel mondo (stanza aperta 5×5 nelle celle locali 14..18, 14..18)
- [ ] Evento attivato quando player entra nella stanza del chunk
- [ ] Dialog campfire mostra testo, NPC alterna speaker a ogni "Avanti"
- [ ] Auto-save: uscire e rientrare → player nella stessa posizione world
- [ ] Stesso seed → stessi story chunk nelle stesse posizioni
- [ ] HomeScreen: bottone "Story Mode" navigates a StoryGameScreen
- [ ] EmotionalPalette in story mode evolve con eventsVisited/totalEvents
- [ ] Nessuna crash su rotazione schermo (ViewModel sopravvive)
- [ ] Build senza errori: `./gradlew clean assembleDebug`
