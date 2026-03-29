# PIANO.md
# AppMaze — Trasformazione Visiva e Gameplay
## Ispirato a: Gris · Celeste · Fez · Monument Valley
## + Hollow Knight · Ori · Baba Is You · Journey · Inside · Undertale · The Witness · Obra Dinn · Hades

> **Destinazione finale**: `/data/massimiliano/agent-framework/output/appmaze/PIANO.md`
> **Stato attuale del progetto**: Core gameplay completo (DFS maze, BFS pathfinding, swipe, canvas, scoring, audio, haptics)
> **Stack**: Kotlin 1.9.22 · Jetpack Compose · Material 3 · Room · Coroutines · Android SDK 26+

---

## Visione

AppMaze parte come un gioco funzionante ma visivamente neutro.
L'obiettivo è trasformarlo in un'esperienza emotivamente risonante, ispirata a:

### Riferimenti originali (Fasi 1–5)

| Gioco | Cosa prendiamo |
|-------|----------------|
| **Gris** | Colore = narrativa, no fail state, world che reagisce al giocatore |
| **Celeste** | Game feel (squash/stretch, coyote time, wall bounce), failure = crescita, assist mode etico |
| **Fez** | 2D/3D duality, rotazione 90° rivela percorsi nascosti, linguaggio segreto |
| **Monument Valley** | Geometrie impossibili (Escher), companion silenzioso, gesture minimali |

### Riferimenti estesi (Fase 6 + retrofit nelle fasi precedenti)

| Gioco | Principio chiave | Applicazione ad AppMaze |
|-------|-----------------|------------------------|
| **Hollow Knight** | Fog-of-war progressivo + mappa diegetica | Labirinto non mostrato intero — si rivela solo camminandolo, si salva solo ai checkpoint |
| **Ori and the Blind Forest** | Luce = personaggio + trail di particelle + temperatura colore come stato | Avatar luminoso illumina raggio; trail che sbiadisce = storia del percorso |
| **Baba Is You** | Regole come oggetti manipolabili + undo infinito senza penalità | Tasselli-regola ai bivi che il giocatore può spingere per riscrivere il labirinto |
| **Journey** | Avanzamento visivo diegetico (sciarpa = barra abilità) + arco cromatico | "Coda" del personaggio cresce con i frammenti raccolti; nessun numero visibile |
| **Inside / Limbo** | Silhouette player + ambiente dettagliato + morte = informazione | Avatar è forma scura pura; ogni morte insegna senza testo; respawn istantaneo |
| **Undertale** | Memoria inter-run + due percorsi sulla stessa mappa + leitmotif accumulativi | Il labirinto ricorda le sessioni; modalità paziente vs. aggressiva; temi musicali per zona |
| **The Witness** | Un solo verbo (swipe) con semantica espandibile + nessun tutorial testuale | Ogni nuovo mondo aggiunge significato allo swipe; 3 livelli di onboarding senza popup |
| **Obra Dinn** | Vincolo estetico come identità + mappa = oggetto di gioco | Palette 2-bit per modalità speciale; mappa di livello sempre visibile come oggetto fisico |
| **Hades** | Schermata home come archivio narrativo + run modifier auto-esplicativi | Home screen accumula artefatti raccolti; token-sfida opzionali senza bloccare progressione |

Il progresso è diviso in **6 Fasi** implementabili sequenzialmente.
Ogni fase è autonoma: Fase 1 non richiede Fase 2, ecc.

---

## Principi Universali di Design

Cinque principi convergenti estratti dalla ricerca sui 9 giochi di riferimento.
Ogni decisione di implementazione dovrebbe essere valutata contro questi principi.

| # | Principio | Fonte | Applicazione concreta |
|---|-----------|-------|-----------------------|
| **P1** | **Single Verb, Deep Semantics** — una sola interazione con significato espandibile | The Witness, Undertale | Lo swipe non cambia mai; cambia cosa fa nelle diverse zone |
| **P2** | **Discovery > Navigation** — non mostrare mai la mappa completa | Hollow Knight, Ori | La nebbia di guerra si alza camminando; nessun minimap in HUD |
| **P3** | **Color is Language** — la temperatura cromatica comunica lo stato di gioco | Ori, Gris, Journey | Warm = sicuro / Cold = pressione / Bloom = vittoria — senza icone |
| **P4** | **Feedback Respects Effort** — il sistema riconosce e conserva il lavoro del giocatore | Baba Is You, Celeste | Undo illimitato; floor 25% sullo score; no fail state hard |
| **P5** | **The World Remembers You** — il gioco accumula evidenza visibile delle sessioni | Hades, Undertale | Home screen cambia; entità commentano le run precedenti; file8-style persistence |

---

## FASE 0 — Fondamenta Architetturali

> Prima di toccare lo stile, preparare le basi condivise da tutte le fasi.

### `ui/game/GameUiState.kt` — estensione completa

```kotlin
data class GameUiState(
    // ── Esistenti ──────────────────────────────────────────────────────
    val maze: MazeGrid? = null,
    val playerCol: Int = 0,
    val playerRow: Int = 0,
    val hintPath: List<MazeCell> = emptyList(),
    val elapsedSeconds: Int = 0,
    val score: Int = 0,
    val gameStatus: GameStatus = GameStatus.PLAYING,
    val difficulty: DifficultyLevel = DifficultyLevel.EASY,
    val hintsUsed: Int = 0,
    val hintsRemaining: Int = 3,
    val soundEnabled: Boolean = true,
    val hapticEnabled: Boolean = true,
    val errorMessage: String? = null,

    // ── Fase 1: Stile emotivo ──────────────────────────────────────────
    val completionProgress: Float = 0f,             // 0f–1f
    val emotionalPhase: EmotionalPhase = EmotionalPhase.DORMANT,
    val visitedCells: Set<Pair<Int, Int>> = emptySet(),
    val cellSizePixels: Float = 0f,
    val mazeOffsetX: Float = 0f,
    val mazeOffsetY: Float = 0f,
    val isWinAnimating: Boolean = false,
    val moveCount: Int = 0,

    // ── Fase 2: Prospettiva ────────────────────────────────────────────
    val viewMode: ViewMode = ViewMode.TOP_DOWN,
    val worldRotation: Int = 0,
    val rotationAngle: Float = 0f,
    val hiddenPassagesActive: Set<Pair<Int, Int>> = emptySet(),

    // ── Fase 3: Narrativa + Segreti ────────────────────────────────────
    val companionPosition: Pair<Int, Int>? = null,
    val discoveredGlyphs: Set<String> = emptySet(),
    val secretRoomsFound: Int = 0,
    val assistModeEnabled: Boolean = false,
    val deathCount: Int = 0,
    val strawberriesCollected: Set<String> = emptySet()
)

enum class ViewMode { TOP_DOWN, ISOMETRIC }
```

### Event system nel `GameViewModel.kt`

```kotlin
sealed class GameEvent {
    data class PlayerMoved(val col: Int, val row: Int) : GameEvent()
    data class WallHit(val direction: Direction) : GameEvent()
    object GameWon : GameEvent()
    object HintUsed : GameEvent()
    data class GlyphDiscovered(val glyph: String) : GameEvent()
    data class SecretRoomFound(val col: Int, val row: Int) : GameEvent()
    object WorldRotated : GameEvent()
}

private val _events = Channel<GameEvent>(Channel.BUFFERED)
val events: Flow<GameEvent> = _events.receiveAsFlow()
```

---

## FASE 1 — Stile Emotivo (Gris + Celeste)

### Nuovo file: `ui/theme/EmotionalPalette.kt`

```kotlin
enum class EmotionalPhase(val label: String) {
    DORMANT("Dormiente"),    // 0–20%: grigio freddo
    AWAKENING("Risveglio"),  // 20–45%: prime tracce di colore
    FLOWING("Flusso"),       // 45–70%: verde caldo, amber
    BLOOM("Fioritura")       // 70–100%: teal brillante, oro, bianco
}

data class EmotionalColors(
    val wallColor: Color, val pathBackground: Color,
    val playerColor: Color, val playerGlow: Color,
    val exitColor: Color, val hintColor: Color,
    val particleColor: Color, val vignetteColor: Color,
    val trailColor: Color, val companionColor: Color
)

object EmotionalPalette {
    private val dormant = EmotionalColors(
        wallColor=Color(0xFF3A3D4A), pathBackground=Color(0xFF12141C),
        playerColor=Color(0xFF8A8FA0), playerGlow=Color(0x448A8FA0),
        exitColor=Color(0xFF5A5D6A), hintColor=Color(0x665A6070),
        particleColor=Color(0x332A2D3A), vignetteColor=Color(0xCC0A0C14),
        trailColor=Color(0x1A8A8FA0), companionColor=Color(0x88B0B8C8)
    )
    private val awakening = EmotionalColors(
        wallColor=Color(0xFF2E4A6E), pathBackground=Color(0xFF0E1828),
        playerColor=Color(0xFF4A90D9), playerGlow=Color(0x664A90D9),
        exitColor=Color(0xFF6AABF0), hintColor=Color(0x663A70B0),
        particleColor=Color(0x443A6090), vignetteColor=Color(0xCC08101E),
        trailColor=Color(0x224A90D9), companionColor=Color(0xAA7AB8E8)
    )
    private val flowing = EmotionalColors(
        wallColor=Color(0xFF3A7A50), pathBackground=Color(0xFF0C1E14),
        playerColor=Color(0xFF50C878), playerGlow=Color(0x6650C878),
        exitColor=Color(0xFFF0C040), hintColor=Color(0x6640A060),
        particleColor=Color(0x5540C870), vignetteColor=Color(0xCC080E0C),
        trailColor=Color(0x3350C878), companionColor=Color(0xAAA0E8B0)
    )
    private val bloom = EmotionalColors(
        wallColor=Color(0xFF00D084), pathBackground=Color(0xFF0A1A14),
        playerColor=Color(0xFF00FFB0), playerGlow=Color(0x8800FFB0),
        exitColor=Color(0xFFFFD700), hintColor=Color(0x7700C880),
        particleColor=Color(0xAA00E890), vignetteColor=Color(0xAA040E0A),
        trailColor=Color(0x5500FFB0), companionColor=Color(0xFFFFE080)
    )

    // Tema base per difficoltà: ogni difficoltà ha identità cromatica propria
    fun baseForDifficulty(difficulty: DifficultyLevel): EmotionalColors = when (difficulty) {
        DifficultyLevel.EASY   -> awakening           // Primavera
        DifficultyLevel.MEDIUM -> flowing             // Estate
        DifficultyLevel.HARD   -> /* autunno arancio */ flowing.copy(
            wallColor=Color(0xFF7A4A1E), playerColor=Color(0xFFD07830))
        DifficultyLevel.EXPERT -> /* inverno ghiaccio */ awakening.copy(
            wallColor=Color(0xFF2A4A7A), playerColor=Color(0xFF80C8FF))
    }

    fun forProgress(progress: Float, difficulty: DifficultyLevel): EmotionalColors {
        val base = baseForDifficulty(difficulty)
        return when {
            progress < 0.20f -> base
            progress < 0.45f -> lerp(base, awakening, (progress - 0.20f) / 0.25f)
            progress < 0.70f -> lerp(awakening, flowing, (progress - 0.45f) / 0.25f)
            else             -> lerp(flowing, bloom, ((progress - 0.70f) / 0.30f).coerceIn(0f, 1f))
        }
    }

    fun phaseForProgress(p: Float): EmotionalPhase = when {
        p < 0.20f -> EmotionalPhase.DORMANT;  p < 0.45f -> EmotionalPhase.AWAKENING
        p < 0.70f -> EmotionalPhase.FLOWING;  else -> EmotionalPhase.BLOOM
    }

    private fun lerp(from: EmotionalColors, to: EmotionalColors, t: Float) = EmotionalColors(
        lerp(from.wallColor,to.wallColor,t), lerp(from.pathBackground,to.pathBackground,t),
        lerp(from.playerColor,to.playerColor,t), lerp(from.playerGlow,to.playerGlow,t),
        lerp(from.exitColor,to.exitColor,t), lerp(from.hintColor,to.hintColor,t),
        lerp(from.particleColor,to.particleColor,t), lerp(from.vignetteColor,to.vignetteColor,t),
        lerp(from.trailColor,to.trailColor,t), lerp(from.companionColor,to.companionColor,t)
    )
}
```

### Nuovo file: `ui/animation/PlayerAnimator.kt`

```kotlin
class PlayerAnimator {
    val animX = Animatable(0f);  val animY = Animatable(0f)
    val shakeX = Animatable(0f); val shakeY = Animatable(0f)
    val scale  = Animatable(1f)  // squash & stretch (Celeste)

    // Movimento fluido: 120ms, FastOutSlowIn (Celeste standard)
    suspend fun moveTo(col: Int, row: Int, cellSize: Float, offsetX: Float, offsetY: Float) {
        val tx = offsetX + col * cellSize + cellSize / 2f
        val ty = offsetY + row * cellSize + cellSize / 2f
        val isH = kotlin.math.abs(tx - animX.value) > 1f
        coroutineScope {
            launch { scale.animateTo(if (isH) 0.82f else 1.15f, tween(40)) }
            launch { animX.animateTo(tx, tween(120, easing = FastOutSlowInEasing)) }
            launch { animY.animateTo(ty, tween(120, easing = FastOutSlowInEasing)) }
        }
        scale.animateTo(1f, spring(Spring.DampingRatioMediumBouncy, Spring.StiffnessHigh))
    }

    // Wall bounce: spring con oscillazione (Celeste: feedback visivo sulla collisione)
    suspend fun wallBounce(direction: Direction) {
        val bump = 8f
        val (dx, dy) = when (direction) {
            Direction.UP->0f to -bump; Direction.DOWN->0f to bump
            Direction.LEFT->-bump to 0f; Direction.RIGHT->bump to 0f
        }
        coroutineScope {
            launch { shakeX.animateTo(dx, tween(50)); shakeX.animateTo(0f, spring()) }
            launch { shakeY.animateTo(dy, tween(50)); shakeY.animateTo(0f, spring()) }
            launch { scale.animateTo(1.2f, tween(50)); scale.animateTo(1f, spring()) }
        }
    }

    // Spawn: il giocatore "cade" nell'arena all'inizio del livello
    suspend fun spawnAt(col: Int, row: Int, cellSize: Float, offsetX: Float, offsetY: Float) {
        val tx = offsetX + col * cellSize + cellSize / 2f
        val ty = offsetY + row * cellSize + cellSize / 2f
        animX.snapTo(tx); animY.snapTo(ty - cellSize * 3f); scale.snapTo(0.1f)
        coroutineScope {
            launch { animY.animateTo(ty, spring(Spring.DampingRatioLowBouncy, Spring.StiffnessMedium)) }
            launch { scale.animateTo(1f, spring(Spring.DampingRatioMediumBouncy)) }
        }
    }

    // Win: esplosione di scala → dissolve
    suspend fun winPop() {
        scale.animateTo(1.8f, tween(200, easing = FastOutSlowInEasing))
        scale.animateTo(0f, tween(300))
    }
}
```

### Calcolo progresso in `GameViewModel.kt`

```kotlin
// Cache path length per evitare BFS ripetuti a ogni mossa
private var totalPathLength: Int = -1

private fun computeProgress(newCol: Int, newRow: Int): Float {
    val maze = _uiState.value.maze ?: return 0f
    if (totalPathLength < 0) {
        val s = maze.getCell(0, 0) ?: return 0f
        val e = maze.getCell(maze.width - 1, maze.height - 1) ?: return 0f
        totalPathLength = mazeSolver.findShortestPath(maze, s, e).size
    }
    val start   = maze.getCell(0, 0) ?: return 0f
    val current = maze.getCell(newCol, newRow) ?: return 0f
    return (mazeSolver.findShortestPath(maze, start, current).size.toFloat() / totalPathLength)
        .coerceIn(0f, 1f)
}

// In processSwipe(), dopo ogni mossa valida:
val progress = computeProgress(newCol, newRow)
_uiState.update { it.copy(
    completionProgress = progress,
    emotionalPhase = EmotionalPalette.phaseForProgress(progress),
    visitedCells = it.visitedCells + (newCol to newRow),
    moveCount = it.moveCount + 1
)}
soundManager.setAmbientProgress(progress)
```

### `ui/components/MazeCanvas.kt` — 8 layer di rendering

```
Layer 0: Background radiale (palette.pathBackground → Black)
Layer 1: Trail celle visitate (trailColor, rettangolo tenue)
Layer 2: Celle speciali (Escher connector, glyph marker, secret room indicator)
Layer 3: Pareti organiche (StrokeCap.Round, StrokeJoin.Round, wallColor)
Layer 4: Hint path (dashes animati "marching ants" + cerchio sonar sull'ultimo hint)
Layer 5: Exit cell (3 anelli concentrici pulsanti: alpha 0.15/0.30/0.90)
Layer 6: Companion orb (Fase 3 — aura + core + coda trail)
Layer 7: Player (glow radiale 3.5x + core con squash&stretch)
Layer 8: Vignette overlay (radialGradient Transparent→vignetteColor, 0.52x)
```

### Win Bloom in `ui/components/MazeGameScreen.kt`

```kotlin
var bloomVisible by remember { mutableStateOf(false) }
val bloomRadius by animateFloatAsState(
    targetValue = if (bloomVisible) 1f else 0f,
    animationSpec = tween(700, easing = FastOutSlowInEasing),
    finishedListener = { if (bloomVisible) onGameOver(score, time, difficulty) }
)
LaunchedEffect(uiState.gameStatus) {
    if (uiState.gameStatus == GameStatus.WON) {
        playerAnimator.winPop(); delay(200); bloomVisible = true
    }
}
// Overlay sopra il canvas: radialGradient playerColor+exitColor+White con bloomRadius
```

### Reframe Scoring in `domain/game/ScoringEngine.kt`

```kotlin
// PRIMA: base - timePenalty (semantica punitiva)
// DOPO:  base + swiftBonus + explorerBonus (semantica celebrativa)

fun calculateScore(difficulty: DifficultyLevel, elapsedSeconds: Int,
                   hintsUsed: Int, moveCount: Int): Int {
    val base = getBaseScore(difficulty)
    val targetTime = mapOf(EASY->60, MEDIUM->150, HARD->300, EXPERT->600)[difficulty]!!
    val swiftBonus = if (elapsedSeconds < targetTime)
        (base * 0.6f * (1f - elapsedSeconds.toFloat()/targetTime)).toInt() else 0
    val optimalMoves = mapOf(EASY->20, MEDIUM->60, HARD->120, EXPERT->250)[difficulty]!!
    val explorerBonus = if (moveCount < optimalMoves * 1.5f)
        (base * 0.2f * (1f - (moveCount-optimalMoves).toFloat()/(optimalMoves*0.5f))
            .coerceIn(0f,1f)).toInt() else 0
    return maxOf(base / 4, base + swiftBonus + explorerBonus - hintsUsed * 80)
    // Floor al 25%: il giocatore non viene mai "punito" eccessivamente
}
```

### Assist Mode — `ui/screens/AssistModeScreen.kt`

```kotlin
// Celeste: "non togliere la soddisfazione, rendere il gioco accessibile"
// Toggle: Hint illimitati | Timer slow motion (50%) | Mostra percorso completo
// NO terminologia peggiorativa ("facile", "imbroglio")
data class AssistSettings(
    val infiniteHints: Boolean = false,
    val timerSpeedMultiplier: Float = 1.0f,
    val alwaysShowPath: Boolean = false
)
```

---

## FASE 2 — Elementi Prospettici (Fez + Monument Valley)

### Nuovo file: `ui/rendering/IsometricTransform.kt`

```kotlin
// Proiezione ortografica isometrica a 30° (come Monument Valley)
object IsometricTransform {
    fun cellCenter(col: Int, row: Int, cellW: Float, ox: Float, oy: Float): Offset {
        return Offset(ox + (col - row) * cellW / 2f, oy + (col + row) * cellW / 4f)
    }

    fun diamond(col: Int, row: Int, cellW: Float, ox: Float, oy: Float): Array<Offset> {
        val cx = ox + (col-row)*cellW/2f; val cy = oy + (col+row)*cellW/4f
        val hw = cellW/2f; val hh = cellW/4f
        return arrayOf(Offset(cx,cy), Offset(cx+hw,cy+hh), Offset(cx,cy+hh*2), Offset(cx-hw,cy+hh))
    }

    // Faccia sinistra e destra dei blocchi muro 3D
    fun leftFace(col: Int, row: Int, cellW: Float, h: Float, ox: Float, oy: Float): Array<Offset>
    fun rightFace(col: Int, row: Int, cellW: Float, h: Float, ox: Float, oy: Float): Array<Offset>

    // Painter's algorithm: dal basso-destra verso alto-sinistra
    fun drawOrder(cols: Int, rows: Int): List<Pair<Int,Int>> = buildList {
        for (sum in (cols+rows-2) downTo 0)
            for (c in 0 until cols) { val r = sum-c; if (r in 0 until rows) add(c to r) }
    }
}
```

### Nuovo file: `ui/rendering/PerspectiveRotation.kt`

```kotlin
// Rotazione del mondo à la Fez: 4 viste ortografiche, pareti diverse per ogni vista
class PerspectiveRotation {
    var currentRotation: Int = 0; private set
    val visualAngle = Animatable(0f)

    // 400ms, easing quintico (come Fez)
    suspend fun rotateCW() {
        visualAngle.animateTo(visualAngle.value + 90f,
            tween(400, easing = CubicBezierEasing(0.77f, 0f, 0.175f, 1f)))
        currentRotation = (currentRotation + 1) % 4
    }
    suspend fun rotateCCW() { /* specchio di rotateCW */ }

    // Pareti visibili cambiano con la rotazione: rot0=originale, rot1=+90°, ecc.
    fun hasWall(cell: MazeCell, direction: Int): Boolean =
        cell.hasWall((direction + currentRotation) % 4)

    fun getPassableNeighbors(grid: MazeGrid, col: Int, row: Int): List<Pair<Int,Int>>
}
```

### Modifiche a `domain/maze/MazeCell.kt`

```kotlin
enum class CellType {
    NORMAL, ESCHER_CONNECTOR, GRAVITY_FLIP,
    GLYPH_CELL, SECRET_CHAMBER_ENTRY
}
data class EscherLink(val targetCol: Int, val targetRow: Int, val visibleAtRotation: Int = 0)

// Aggiunta a MazeCell:
val cellType: CellType = CellType.NORMAL
val escherLink: EscherLink? = null
val glyphId: String? = null
```

### Modifiche a `domain/maze/MazeSolver.kt`

```kotlin
// BFS con supporto Escher + rotazione:
fun reachableNeighbors(grid: MazeGrid, cell: MazeCell,
                       rotation: PerspectiveRotation? = null): List<MazeCell> {
    // Vicini standard (rispettando la rotazione)
    val standard = buildList { /* top/right/bottom/left con rotation.hasWall() */ }
    // Arco Escher (solo alla rotazione corretta)
    val escher = cell.escherLink
        ?.takeIf { rotation == null || it.visibleAtRotation == rotation.currentRotation }
        ?.let { grid.getCell(it.targetCol, it.targetRow) }
    return if (escher != null) standard + escher else standard
}
```

---

## FASE 3 — Narrativa, Companion, Segreti

### Nuovo file: `ui/animation/CompanionAnimator.kt`

```kotlin
// Orb compagno silenzioso (come Totem di Monument Valley)
// Segue il giocatore con spring slow → "lag emotivo" che crea attaccamento
class CompanionAnimator {
    val animX = Animatable(0f); val animY = Animatable(0f)
    val scale = Animatable(0.8f)

    suspend fun followPlayer(targetX: Float, targetY: Float) {
        coroutineScope {
            launch { animX.animateTo(targetX, spring(0.6f, Spring.StiffnessLow)) }
            launch { animY.animateTo(targetY - 25f, spring(0.6f, Spring.StiffnessLow)) }
        }
    }

    // Si ingrandisce avvicinandosi all'exit (entusiasmo crescente)
    suspend fun reactToProximity(distanceToExit: Float, maxDistance: Float) {
        val excitement = 1f - (distanceToExit / maxDistance).coerceIn(0f, 1f)
        scale.animateTo(0.8f + excitement * 0.4f, tween(300))
    }

    // Celebrazione win: orbita 3 giri → dissolve
    suspend fun celebrateWin() { /* orbita rapida poi scale→0 */ }
}
```

### Nuovo file: `domain/glyph/GlyphSystem.kt`

```kotlin
// 12 glifi nascosti nei labirinti HARD/EXPERT (come il linguaggio Zu di Fez)
// Raccoglierli tutti decodifica un messaggio emotivo
object GlyphSystem {
    val GLYPHS = listOf("◇","△","○","□","⬡","✦","⊕","⊗","◈","⬟","◉","⬢")
    val MESSAGES = mapOf(
        "EASY"   to "Ogni passo è un passo",
        "MEDIUM" to "Perdersi è trovare",
        "HARD"   to "Il muro è un'opinione",
        "EXPERT" to "Il labirinto ti cambia mentre lo percorri"
    )
    fun isComplete(discovered: Set<String>, difficulty: DifficultyLevel): Boolean
    fun decodeMessage(discovered: Set<String>, difficulty: DifficultyLevel): String?
}
```

### Nuovo file: `domain/collectibles/Strawberry.kt`

```kotlin
// Come le fragoline di Celeste: opzionali, fuori dal percorso ottimale
// Non bloccano la progressione. La soddisfazione è tutta nella raccolta.
data class Strawberry(
    val id: String, val col: Int, val row: Int,
    val requiresDetour: Boolean = true
)
```

### Nuovo file: `ui/screens/ChapterTransitionScreen.kt`

```kotlin
// Transizione poetica tra difficoltà (come Gris: nessun testo esplicativo, solo emozione)
// Dissolve da palette corrente a quella del prossimo capitolo
// Frase poetica: "Il labirinto diventa più profondo" ecc.
// Durata: 2500ms, poi chiama onComplete()
```

---

## FASE 4 — Sound Design

### Struttura `res/raw/`

```
Ambient (MediaPlayer, loop)
├── ambient_layer_1.ogg  Piano sparse, BPM 60, 120s loop          → sempre attivo
├── ambient_layer_2.ogg  Archi sottili, re minore                 → attivo dal 25%
├── ambient_layer_3.ogg  Synth pad caldo, do maggiore             → attivo dal 50%
├── ambient_layer_4.ogg  Percussioni leggere                      → attivo dal 75%
└── win_sting.ogg        Accordo maggiore, 3-4s                   → al completamento

SFX (SoundPool, latenza <20ms)
├── move_soft.ogg           Passo organico (legno, 40ms)
├── wall_thud.ogg           Colpo smorzato (non metallico, 60ms)
├── hint_chime.ogg          Carillon singolo (300ms, fade out)
├── glyph_discover.ogg      Tono cristallino ascendente (500ms)
├── strawberry_collect.ogg  Bolla + shimmer (200ms)
├── rotation_whoosh.ogg     Sweep 400ms (sync con animazione)
├── companion_hum.ogg       Loop breve 2s, sottilissimo
├── secret_room.ogg         Accordo sospeso, riverbero lungo (2s)
└── chapter_transition.ogg  Accordo dissolto, filtro passa-basso (3s)
```

### 6 regole di sound design (da Celeste + Gris)

1. **La musica non si ferma mai** al reset — continuità emotiva
2. **Silenzio come strumento** — prima di eventi importanti, -20% volume per 2s
3. **SFX organici** — nessun beep, preferire materiali fisici (legno, vetro, corda)
4. **Layer entrano in fade** — mai cut improvviso (fadeInLayer: 2s per layer)
5. **Companion ha suono proprio** — loop sottile udibile in prossimità
6. **Rotazione suona come gesto fisico** — whoosh sincronizzato ai 400ms animazione

### Pitch variante per PLAYER_MOVE (Celeste: ogni passo è leggermente diverso)

```kotlin
private val movePitches = floatArrayOf(0.95f, 1.0f, 1.05f, 0.98f, 1.02f)
private var pitchIndex = 0
fun playMove() { soundPool?.play(soundId, 0.6f, 0.6f, 1, 0, movePitches[pitchIndex++ % 5]) }
```

### `SoundEffect` enum esteso

```kotlin
enum class SoundEffect {
    PLAYER_MOVE, WALL_BUMP, HINT_REVEAL, GAME_COMPLETE, BUTTON_CLICK,
    GLYPH_DISCOVERED, STRAWBERRY_COLLECT, WORLD_ROTATED,
    SECRET_ROOM_FOUND, COMPANION_PULSE
}
```

---

## FASE 5 — Architettura Dati

### Nuove entità Room

```kotlin
@Entity("glyph_progress")
data class GlyphProgressEntity(
    @PrimaryKey val glyphId: String,
    val difficulty: String,
    val discoveredAt: Long,
    val mazeWidth: Int, val mazeHeight: Int
)

@Entity("strawberry_collection")
data class StrawberryEntity(
    @PrimaryKey val strawberryId: String,
    val sessionId: String, val difficulty: String,
    val col: Int, val row: Int, val collectedAt: Long
)

@Entity("secret_rooms")
data class SecretRoomEntity(
    @PrimaryKey(autoGenerate=true) val id: Long = 0,
    val sessionId: String, val rotationAngle: Int,
    val roomCol: Int, val roomRow: Int, val foundAt: Long
)

@Entity("player_stats")
data class PlayerStatsEntity(
    @PrimaryKey val id: Int = 1,
    val totalMoves: Long = 0, val totalResets: Long = 0,
    val totalGlyphsFound: Int = 0, val totalStrawberries: Int = 0,
    val totalSecretRooms: Int = 0, val totalPlaytimeSeconds: Long = 0,
    val lastPlayedAt: Long = 0
)
```

### DAOs

```kotlin
@Dao interface GlyphProgressDao {
    @Insert(onConflict=OnConflictStrategy.IGNORE) suspend fun markDiscovered(g: GlyphProgressEntity)
    @Query("SELECT glyphId FROM glyph_progress WHERE difficulty=:diff") suspend fun getDiscovered(diff: String): List<String>
    @Query("SELECT COUNT(*) FROM glyph_progress WHERE difficulty=:diff") fun countFlow(diff: String): Flow<Int>
}

@Dao interface PlayerStatsDao {
    @Query("SELECT * FROM player_stats WHERE id=1") fun getStats(): Flow<PlayerStatsEntity?>
    @Upsert suspend fun update(s: PlayerStatsEntity)
    @Query("UPDATE player_stats SET totalMoves=totalMoves+:d WHERE id=1") suspend fun addMoves(d: Long)
    @Query("UPDATE player_stats SET totalResets=totalResets+1 WHERE id=1") suspend fun incrementResets()
}
```

### Migration Room 1→2

```kotlin
val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("CREATE TABLE IF NOT EXISTS glyph_progress (glyphId TEXT PRIMARY KEY NOT NULL, difficulty TEXT NOT NULL, discoveredAt INTEGER NOT NULL, mazeWidth INTEGER NOT NULL, mazeHeight INTEGER NOT NULL)")
        db.execSQL("CREATE TABLE IF NOT EXISTS player_stats (id INTEGER PRIMARY KEY NOT NULL, totalMoves INTEGER NOT NULL DEFAULT 0, totalResets INTEGER NOT NULL DEFAULT 0, totalGlyphsFound INTEGER NOT NULL DEFAULT 0, totalStrawberries INTEGER NOT NULL DEFAULT 0, totalSecretRooms INTEGER NOT NULL DEFAULT 0, totalPlaytimeSeconds INTEGER NOT NULL DEFAULT 0, lastPlayedAt INTEGER NOT NULL DEFAULT 0)")
        db.execSQL("INSERT INTO player_stats (id) VALUES (1)")
    }
}
```

### `ui/screens/StatsScreen.kt`

```kotlin
// Statistiche aggregate — stile Celeste: celebrativo, mai punitivo
// "X mosse totali · Y glifi trovati · Z fragoline · W ore di gioco"
// Se tutti i glifi trovati: mostrare il messaggio decodificato
```

---

## File Coinvolti — Riepilogo

| # | File | Tipo | Fase |
|---|------|------|------|
| 1 | `ui/theme/EmotionalPalette.kt` | Nuovo | 0+1 |
| 2 | `ui/game/GameUiState.kt` | Modifica totale | 0 |
| 3 | `ui/game/GameViewModel.kt` | Modifica estesa | 0+1+2+3 |
| 4 | `ui/animation/PlayerAnimator.kt` | Nuovo | 1 |
| 5 | `ui/animation/CompanionAnimator.kt` | Nuovo | 3 |
| 6 | `ui/effects/AmbientParticles.kt` | Nuovo | 1 |
| 7 | `ui/components/MazeCanvas.kt` | Riscrittura | 1+2+3 |
| 8 | `domain/game/ScoringEngine.kt` | Modifica | 1 |
| 9 | `util/SoundManager.kt` | Modifica | 1+4 |
| 10 | `ui/components/MazeGameScreen.kt` | Modifica estesa | 1+2 |
| 11 | `ui/screens/HomeScreen.kt` | Modifica | 1 |
| 12 | `ui/screens/GameOverScreen.kt` | Modifica | 1+3 |
| 13 | `ui/screens/AssistModeScreen.kt` | Nuovo | 1 |
| 14 | `ui/screens/ChapterTransitionScreen.kt` | Nuovo | 3 |
| 15 | `ui/screens/StatsScreen.kt` | Nuovo | 5 |
| 16 | `ui/rendering/IsometricTransform.kt` | Nuovo | 2 |
| 17 | `ui/rendering/PerspectiveRotation.kt` | Nuovo | 2 |
| 18 | `domain/maze/MazeCell.kt` | Modifica | 2+3 |
| 19 | `domain/maze/MazeGenerator.kt` | Modifica | 2+3 |
| 20 | `domain/maze/MazeSolver.kt` | Modifica | 2 |
| 21 | `domain/maze/SecretRoom.kt` | Nuovo | 3 |
| 22 | `domain/glyph/GlyphSystem.kt` | Nuovo | 3 |
| 23 | `domain/collectibles/Strawberry.kt` | Nuovo | 3 |
| 24 | `data/entity/GlyphProgressEntity.kt` | Nuovo | 5 |
| 25 | `data/entity/StrawberryEntity.kt` | Nuovo | 5 |
| 26 | `data/entity/SecretRoomEntity.kt` | Nuovo | 5 |
| 27 | `data/entity/PlayerStatsEntity.kt` | Nuovo | 5 |
| 28 | `data/db/GlyphProgressDao.kt` | Nuovo | 5 |
| 29 | `data/db/PlayerStatsDao.kt` | Nuovo | 5 |
| 30 | `data/db/AppMazeDatabase.kt` | Modifica | 5 |
| 31 | `data/repository/GameRepository.kt` | Modifica | 5 |

---

## Ordine di Implementazione

```
── Fase 0 ─────────────────────────────────────
  1. GameUiState.kt — tutti i campi
  2. GameViewModel.kt — event channel + progress calc

── Fase 1 ─────────────────────────────────────
  3. EmotionalPalette.kt
  4. PlayerAnimator.kt
  5. AmbientParticles.kt
  6. MazeCanvas.kt — layer 0-5 (senza companion)
  7. ScoringEngine.kt
  8. SoundManager.kt — ambient layers + SFX estesi
  9. MazeGameScreen.kt — win bloom
 10. HomeScreen.kt — atmosferica + particelle
 11. GameOverScreen.kt — death counter
 12. AssistModeScreen.kt

── Fase 2 ─────────────────────────────────────
 13. IsometricTransform.kt
 14. PerspectiveRotation.kt
 15. MazeCell.kt + MazeGenerator.kt
 16. MazeSolver.kt
 17. MazeCanvas.kt — aggiungere drawIsometric()
 18. MazeGameScreen.kt — rotation buttons

── Fase 3 ─────────────────────────────────────
 19. CompanionAnimator.kt
 20. MazeCanvas.kt — layer companion
 21. GlyphSystem.kt
 22. SecretRoom.kt + Strawberry.kt
 23. ChapterTransitionScreen.kt

── Fase 4 ─────────────────────────────────────
 24. File audio res/raw/ (placeholder .ogg)
 25. SoundManager.kt — pitch variant + nuovi SFX

── Fase 5 ─────────────────────────────────────
 26. Entità + DAOs Room
 27. AppMazeDatabase.kt — migration
 28. GameRepository.kt
 29. StatsScreen.kt

── Fase 6 ─────────────────────────────────────
 30. ChallengeToken.kt           (6D — enum + multiplier)
 31. CellMemoryEntity.kt         (6C — Room entity)
 32. CellMemoryDao.kt            (6C — Room DAO)
 33. GameViewModel.kt            (6E — moveHistory + undoLastMove)
 34. GameUiState.kt              (6A — revealedCells, committedCells, activeTokens)
 35. MazeCanvas.kt               (6A + 6C — fog layer + memory overlay)
 36. RewindSlider.kt             (6E — UI undo slider)
 37. ChallengeSelectScreen.kt    (6D — selezione token pre-run)
 38. HomeScreen.kt               (6B — artefatti narrativi condizionali)
 39. SoundManager.kt             (6G — leitmotif per zona + crossfade vittoria)
 40. EmotionalPalette.kt         (6H — ObsidianMode 2-bit)
```

---

## FASE 6 — Metagame, Profondità Sistemica & Identità Visiva

> Questa fase trasforma AppMaze da gioco in **esperienza con memoria**.
> Non richiede le fasi precedenti, ma si amplifica con esse.
> Ogni sezione è indipendente e implementabile in isolamento.

---

### 6A — Fog of War Progressivo *(Hollow Knight)*

Il labirinto non è mai mostrato per intero. Le celle vengono rivelate solo quando il giocatore le attraversa. L'esplorazione viene salvata solo ai **checkpoint** (exit di ogni piano), non in tempo reale — come in Hollow Knight dove la mappa si aggiorna solo alla panchina.

**Effetto**: ogni swipe è un atto di authorship. La nebbia che si alza è la tua storia.

```kotlin
// In GameUiState.kt — aggiungere a Fase 0:
val revealedCells: Set<Pair<Int, Int>> = emptySet(),   // celle esplorate (volatile)
val committedCells: Set<Pair<Int, Int>> = emptySet(),  // celle salvate a checkpoint
val activeTokens: Set<ChallengeToken> = emptySet(),    // token-sfida attivi (Fase 6D)

// In GameViewModel.kt — aggiornare processSwipe():
_uiState.update { state ->
    val newRevealed = state.revealedCells + (newCol to newRow)
    state.copy(
        playerRow = newRow, playerCol = newCol,
        revealedCells = newRevealed,
        // se token TOTAL_FOG attivo, revealedCells NON cresce
    )
}

// commitToCheckpoint() — chiamata all'exit di ogni piano:
fun commitToCheckpoint() {
    _uiState.update { it.copy(committedCells = it.committedCells + it.revealedCells) }
    viewModelScope.launch { gameRepository.saveRevealedCells(_uiState.value.committedCells) }
}

// In MazeCanvas: layer nebbia (dopo gli altri layer)
// fog alpha = 0.88 per celle non-revealed
// fog alpha = 0.35 per celle revealed-ma-non-committed (memoria volatile, meno opaca)
// fog alpha = 0.0 per celle committed (pienamente visibili)
for (row in maze.indices) {
    for (col in maze[row].indices) {
        val cellCoord = col to row
        val fogAlpha = when {
            cellCoord in committedCells -> 0.0f
            cellCoord in revealedCells  -> 0.35f
            else                        -> 0.88f
        }
        if (fogAlpha > 0f) drawRect(
            color = Color.Black.copy(alpha = fogAlpha),
            topLeft = Offset(x, y),
            size = cellSize,
        )
    }
}
```

**File coinvolti**: `GameUiState.kt` (+3 campi), `GameViewModel.kt` (+`commitToCheckpoint`), `MazeCanvas.kt` (fog layer), `data/db/` (persistenza committedCells).

---

### 6B — Home Screen come Archivio Narrativo *(Hades)*

La home screen accumula artefatti visibili delle sessioni passate. Non testo, non statistiche — oggetti fisici nell'environment che cambiano.

| Milestone | Cambiamento visivo |
|-----------|-------------------|
| Prima partita completata | Una candela accesa nell'angolo |
| 10 run completate | Una mappa arrotolata sul tavolo |
| Tutti i glifi trovati | Un libro aperto con i glifi |
| Assist Mode usato | Un'armatura appoggiata al muro |
| 50 run | Le pareti mostrano segni di usura |

```kotlin
// Nuovo: data/db/entity/PlayerStatsEntity.kt (già nel piano Fase 5)
// HomeScreen.kt legge totalRuns, glyphsFound, assistModeUsed
// e mostra/nasconde Composable decorativi in base ai valori
```

---

### 6C — Memoria Inter-Run e Soft Persistence *(Undertale)*

Il labirinto ricorda ciò che hai fatto nelle run precedenti. Effetti sottili, non invasivi:

- **Una porta che si è già aperta** rimane leggermente diversa (colore bordo)
- **Un corridoio percorso 5+ volte** ha tracce di passi sul pavimento
- **Un muro sbattuto spesso** mostra una crepa visibile
- **Dopo una run Genocide-equivalent** (tutti i collezionabili ignorati): le entità del labirinto sembrano evitarti

Nessun testo. Nessuna notifica. Il mondo parla senza parole.

```kotlin
// Nuovo: data/db/entity/CellMemoryEntity.kt
@Entity data class CellMemoryEntity(
    @PrimaryKey val cellKey: String,          // "$difficulty-$col-$row"
    val visitCount: Int = 0,
    val wallHitCount: Int = 0,
    val firstVisited: Long = 0L,
    val lastVisited: Long = 0L,
)
// MazeCanvas legge cellMemory e applica overlay sottili in base a visitCount
```

---

### 6D — Challenge Token System *(Hades — Pact of Punishment)*

Dopo aver completato ogni mondo, sblocchi token-sfida opzionali applicabili a qualsiasi replay.
**Nessun contenuto narrativo è bloccato dai token** — solo score multiplier e gloria.

| Token | Effetto | Moltiplicatore |
|-------|---------|----------------|
| 🌫️ Nebbia Totale | Fog-of-war mai si alza | ×1.5 |
| ⏱️ Clessidra | Timer visibile, penalità veloce | ×1.3 |
| 🔇 Silenzio | Nessun audio direzionale | ×1.2 |
| 🔄 Inversione | LEFT/RIGHT invertiti | ×1.4 |
| 🚫 Niente Undo | Undo disabilitato | ×2.0 |
| 👻 Fantasma | Nessun hint disponibile | ×1.8 |

```kotlin
// Nuovo: domain/challenge/ChallengeToken.kt
enum class ChallengeToken(val multiplier: Float, val label: String) {
    TOTAL_FOG(1.5f, "Nebbia Totale"),
    HOURGLASS(1.3f, "Clessidra"),
    SILENCE(1.2f, "Silenzio"),
    INVERSION(1.4f, "Inversione"),
    NO_UNDO(2.0f, "Niente Undo"),
    GHOST(1.8f, "Fantasma"),
}
// GameUiState.activeTokens: Set<ChallengeToken>
// ScoringEngine considera il prodotto dei multiplier
```

---

### 6E — Undo Illimitato con Zero Frizione *(Baba Is You)*

> *"The undo mechanic is the game telling the player that it values the exploration and work they have put into the puzzle so far."*

Long-press ovunque sullo schermo → slider di rewind. Nessun costo. Nessun contatore.
L'undo è un diritto del giocatore, non una risorsa.

```kotlin
// In GameViewModel.kt:
private val moveHistory = ArrayDeque<Pair<Int,Int>>()   // (col, row) per ogni mossa

fun undoLastMove() {
    if (moveHistory.size < 2) return
    moveHistory.removeLast()
    val (col, row) = moveHistory.last()
    _uiState.update { it.copy(playerCol = col, playerRow = row) }
    recomputeProgress(col, row)
}

// UI: long-press su MazeCanvas → mostra RewindSlider composable
// RewindSlider scrubba l'history visivamente (preview dei passi)
```

---

### 6F — Tutorial Senza Testo: Il Pattern 3-Step *(Inside / Limbo / The Witness)*

Ogni nuova meccanica è introdotta in esattamente **3 livelli consecutivi**, senza popup:

1. **Introduzione sicura**: la meccanica esiste, l'unico percorso la usa, impossibile fallire
2. **Comprensione**: due percorsi, uno usa la meccanica, uno no; la meccanica è l'opzione migliore
3. **Sintesi**: la meccanica è necessaria ma non telegrafata; il giocatore la applica da solo

```
Esempio: meccanica "piastra di pressione"
Livello A: un solo percorso con una piastra → porta si apre → giocatore capisce
Livello B: due percorsi → piastra + porta corta vs. percorso lungo senza piastra
Livello C: puzzle vero che richiede piastra; non c'è indicatore — la ricorda
```

**Principio di verifica**: se il livello 3 si risolve premendo a caso, il design dei livelli 1-2 ha fallito.

---

### 6G — Leitmotif Accumulativi *(Undertale)*

Ogni zona del labirinto ha una cellula melodica di 4–8 battute. Avvicinandosi all'uscita finale, le cellule di tutte le zone si fondono gradualmente. Il giocatore *sente* dove è stato.

| Zona | Strumento dominante | Cellula melodica |
|------|---------------------|-----------------|
| EASY | Carillon / glockenspiel | Tema A (sol-la-si) |
| MEDIUM | Chitarra fingerpicking | Tema B (mi-fa-sol) |
| HARD | Violoncello pizzicato | Tema C (re-mi-fa) |
| EXPERT | Pianoforte + pad | Tema A+B+C insieme |
| Vittoria finale | Tutti gli strumenti | A+B+C in armonia |

```kotlin
// In SoundManager.kt: 4 MediaPlayer per le zone
// Alla vittoria: crossfade simultaneo verso traccia "finale" che contiene tutti i temi
// Implementazione: ExoPlayer con gapless playback per le transizioni di zona
```

---

### 6H — Palette 2-Bit come Modalità Identitaria *(Obra Dinn)*

Una modalità opzionale (sbloccabile dopo il completamento di EXPERT) trasforma AppMaze in un'estetica **1-bit dithered** in stile Obra Dinn. Bianco/nero + retino ordinato.

Non è nostalgia: è un frame che forza la massima leggibilità, rimuove ogni distrazione cromatica e rivela la pura architettura del labirinto.

```kotlin
// In EmotionalPalette.kt: nuova enum ObsidianMode
// Se abilitata, override di tutti i colori a Black/White con dither overlay
// MazeCanvas applica un BitmapShader con pattern di retino fisso (Bayer matrix 4×4)
// Toggle in SettingsScreen dopo aver completato EXPERT
```

---

### File nuovi — Fase 6

| File | Tipo | Scopo |
|------|------|-------|
| `domain/challenge/ChallengeToken.kt` | enum | 6 token-sfida con multiplier |
| `data/db/entity/CellMemoryEntity.kt` | Room entity | Memoria per cella (visite, urti) |
| `data/db/dao/CellMemoryDao.kt` | Room DAO | Query cellMemory per MazeCanvas |
| `ui/screens/ChallengeSelectScreen.kt` | Composable | Selezione token prima del replay |
| `ui/components/RewindSlider.kt` | Composable | Slider undo visuale su long-press |

---

### Checklist Fase 6
- [ ] Fog of War: nebbia si alza camminando, si salva solo all'exit
- [ ] Celle revealed vs. committed hanno rendering distinto
- [ ] Home screen ha almeno 3 artefatti condizionali visibili
- [ ] CellMemoryEntity: visitCount e wallHitCount tracciati per cella
- [ ] Corridoi ad alto visitCount mostrano tracce visive sottili
- [ ] 6 ChallengeToken implementati con multiplier ScoringEngine
- [ ] Undo illimitato via long-press: moveHistory + RewindSlider
- [ ] Tutorial 3-step verificato: livello 3 non risolvibile a caso
- [ ] Leitmotif: ogni zona ha cellula melodica distinta
- [ ] Vittoria finale: blend di tutti i temi
- [ ] Modalità 2-bit sbloccabile dopo EXPERT

---

## Verifica

```bash
cd /data/massimiliano/agent-framework/output/appmaze
./gradlew assembleDebug
./gradlew test
./gradlew connectedAndroidTest
```

### Checklist Fase 1
- [ ] Palette evolve da tono-base-difficoltà a bloom avanzando
- [ ] 4 difficoltà hanno identità cromatica distinta (primavera/estate/autunno/inverno)
- [ ] Movimento 120ms con squash & stretch (orizzontale vs verticale)
- [ ] Wall bounce spring con oscillazione
- [ ] Spawn animation all'inizio livello
- [ ] Trail celle visitate (trailColor crescente)
- [ ] Pareti StrokeCap.Round + StrokeJoin.Round
- [ ] Glow radiale 3.5x + core player con scala animata
- [ ] Exit: 3 anelli concentrici pulsanti (alpha 0.15/0.30/0.90)
- [ ] Hint: dashes animati + cerchio sonar
- [ ] Vignette pesante ai bordi (0.52x)
- [ ] Particelle ambient in HomeScreen
- [ ] Win bloom animation + winPop() del player
- [ ] 4 layer audio progressivi (0/25/50/75%)
- [ ] Pitch variante su ogni passo (array di 5 valori)
- [ ] Scoring: swift bonus + explorer bonus, floor 25%
- [ ] Death counter neutro nel GameOverScreen
- [ ] Assist Mode accessibile dalle impostazioni

### Checklist Fase 2
- [ ] Toggle TOP_DOWN/ISOMETRIC nel HUD
- [ ] Vista isometrica: rombi + blocchi 3D, painter's algorithm
- [ ] Rotazione 90° animata (400ms, quintic easing)
- [ ] Indicatore 4-punti rotazione corrente
- [ ] Pareti cambiano a rotazione diversa (percorsi nuovi)
- [ ] Escher connector: BFS naviga attraverso (solo a rotazione specifica)

### Checklist Fase 3
- [ ] Companion appare dopo 30% di progresso
- [ ] Companion segue con lag emotivo (spring StiffnessLow)
- [ ] Companion scala in prossimità dell'exit
- [ ] Companion celebra il win (orbita + dissolve)
- [ ] Glifi visibili nei labirinti HARD/EXPERT
- [ ] Raccoglierli tutti → messaggio decodificato nel GameOverScreen
- [ ] Fragoline raccoglibili fuori dal percorso ottimale
- [ ] Transizione poetica tra livelli di difficoltà

### Checklist Fase 5
- [ ] Migration Room da v1 a v2 senza perdita dati
- [ ] Glifi persistono tra sessioni
- [ ] StatsScreen mostra totali in modo celebrativo
- [ ] Se glifi completi: messaggio visibile nelle stats
