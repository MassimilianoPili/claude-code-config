# Plan: Feature 1 — Cellular Automata Caves for appMaze

## Context

**Why:** All current mazes use the Growing Tree algorithm (DFS/Prim hybrid), which produces corridor-based mazes. CA caves produce fundamentally different topology — organic caverns with irregular walls, open chambers, and winding passages. This comes from our research into Diablo L3 (CA smoothing), NetHack Mines, and Brogue caves.

**Outcome:** A new "Caves" game mode accessible from HomeScreen, generating organic cave-like mazes as a distinct visual and gameplay experience.

---

## Architecture Decision: CA on MazeCell Grid

**The challenge:** Growing Tree operates by removing walls from an all-walled grid (perfect fit for MazeCell's 4-wall model). CA caves operate on a boolean grid (wall/floor). We need to map CA output onto MazeCell walls.

**Approach:** Work on an intermediate `Boolean` grid (true=floor, false=wall), then convert to MazeCell walls:
- A floor cell removes walls toward adjacent floor cells
- A wall cell keeps all walls (and is never entered by the player)
- This preserves the existing `List<List<MazeCell>>` contract — MazeCanvas, MazeEngine, and all UI code work unchanged

**Why not modify MazeCell?** Adding an `isFloor` boolean would touch MazeSerializer (save/load), MazeCanvas rendering, and movement validation. The wall-based mapping is zero-impact on downstream code.

---

## Implementation Plan

### Step 1: Add `MazeAlgorithm` enum to `DifficultyLevel`

**File:** `domain/maze/MazeGenerator.kt` (lines 7-24)

Add an algorithm selector enum and a new property to `DifficultyLevel`:

```kotlin
enum class MazeAlgorithm { GROWING_TREE, CELLULAR_AUTOMATA }

enum class DifficultyLevel(
    val width: Int,
    val height: Int,
    val newestProbability: Float = 1.0f,
    val braidingPercent: Int = 0,
    val algorithm: MazeAlgorithm = MazeAlgorithm.GROWING_TREE,
) {
    EASY(10, 10),
    MEDIUM(20, 20),
    HARD(30, 30),
    EXPERT(40, 40),
    EXTREME(100, 100),
    INFINITE(-1, -1),
    DAILY(8, 8, newestProbability = 0.30f, braidingPercent = 20),
    // New cave modes
    CAVES_EASY(20, 20, algorithm = MazeAlgorithm.CELLULAR_AUTOMATA),
    CAVES_HARD(30, 30, algorithm = MazeAlgorithm.CELLULAR_AUTOMATA),
}
```

**Why separate CAVES_EASY/CAVES_HARD instead of a toggle?** Each DifficultyLevel maps to a leaderboard category. Mixing algorithms in the same category would make scores incomparable.

### Step 2: Add `cellularAutomata()` to `MazeAlgorithms`

**File:** `domain/maze/MazeAlgorithms.kt` (add after `braidingPass()`, ~line 131)

New function with the same contract: operates in-place on `cells: Array<Array<MazeCell>>`.

**Algorithm (4 phases):**

```
Phase 1 — Random fill:
  For each cell: mark as floor (probability 55%) or wall (45%)
  Force corners: start (0,0) = floor, exit (H-1,W-1) = floor
  Force 1-cell border: all border cells = wall (prevents edge-adjacent open spaces)

Phase 2 — CA smoothing (4-5 iterations):
  For each cell: count 8-neighbors that are walls (out-of-bounds = wall)
  If wallNeighbors >= 5: cell becomes wall
  If wallNeighbors <= 3: cell becomes floor
  Else: unchanged
  (Standard B5678/S45678 variant — produces connected caves)

Phase 3 — Connectivity enforcement:
  Flood-fill from start cell (0,0 or nearest floor)
  If exit not in same component:
    Carve a 1-cell-wide tunnel from nearest reachable cell to exit
  If isolated pockets exist: fill them with walls (optional cleanup)

Phase 4 — Convert boolean grid → MazeCell walls:
  For each floor cell:
    For each direction (top, right, bottom, left):
      If neighbor is also floor → remove wall in that direction
      If neighbor is wall or OOB → keep wall
  Wall cells: keep all 4 walls (player never enters them)
```

**RNG:** Uses existing `SplitMix64` for deterministic seeding (same as Growing Tree).

**Key design choice (user input opportunity):** The wall probability and smoothing iterations control cave density. Higher wall probability (50-55%) = more walls, tighter caves. Lower (40-45%) = more open caverns. The smoothing iteration count controls regularity: 3 = rough, 5 = very smooth.

### Step 3: Update `MazeGenerator.generateMaze()`

**File:** `domain/maze/MazeGenerator.kt` (lines 36-52)

Add algorithm dispatch:

```kotlin
fun generateMaze(
    width: Int, height: Int, seed: Long,
    newestProbability: Float = 1.0f,
    braidingPercent: Int = 0,
    algorithm: MazeAlgorithm = MazeAlgorithm.GROWING_TREE,
): MazeGrid {
    val grid = MazeGrid(width, height)
    val cells = grid.getAllCells()

    when (algorithm) {
        MazeAlgorithm.GROWING_TREE -> {
            MazeAlgorithms.growingTree(cells, seed, newestProbability)
            if (braidingPercent > 0) {
                MazeAlgorithms.braidingPass(cells, seed xor 0xB4A1D0L, braidingPercent)
            }
        }
        MazeAlgorithm.CELLULAR_AUTOMATA -> {
            MazeAlgorithms.cellularAutomata(cells, seed)
        }
    }
    return grid
}
```

Update the `generateMaze(difficulty, seed)` overload to pass `difficulty.algorithm`.

### Step 4: Wire into `MazeEngine.finite()`

**File:** `domain/engine/MazeEngine.kt` (line 109)

Add `algorithm` parameter to `finite()` factory, pass through to `MazeGenerator.generateMaze()`.

### Step 5: Wire into `GameViewModel.startNewGame()`

**File:** `ui/game/GameViewModel.kt` (line 91-99)

Pass `difficulty.algorithm` to `MazeEngine.finite()`. The finite branch already uses `difficulty.newestProbability` and `difficulty.braidingPercent`, so adding `difficulty.algorithm` follows the same pattern.

### Step 6: Add "Caves" buttons to `HomeScreen`

**File:** `ui/screens/HomeScreen.kt`

Add a new section "Caverne" (Caves) with two buttons:
- "Caverna Facile" → navigates to `game/CAVES_EASY`
- "Caverna Difficile" → navigates to `game/CAVES_HARD`

### Step 7: Add cave-specific emotional palette colors

**File:** `domain/theme/EmotionalPalette.kt`

Add color schemes for CAVES_EASY and CAVES_HARD:
- Earth tones: warm browns, deep oranges, stone grays
- Distinct from the corridor maze blues/greens

---

## Files Modified (7 total)

| File | Change |
|------|--------|
| `domain/maze/MazeGenerator.kt` | Add `MazeAlgorithm` enum, `algorithm` property to `DifficultyLevel`, dispatch in `generateMaze()` |
| `domain/maze/MazeAlgorithms.kt` | Add `cellularAutomata()` function (~80 lines) |
| `domain/engine/MazeEngine.kt` | Add `algorithm` param to `finite()` factory |
| `ui/game/GameViewModel.kt` | Pass `difficulty.algorithm` to engine |
| `ui/screens/HomeScreen.kt` | Add "Caverne" section with 2 buttons |
| `domain/theme/EmotionalPalette.kt` | Add cave color palettes |
| `domain/maze/MazeGrid.kt` | No changes needed |

**Files NOT modified:** MazeCanvas.kt, MazeCell.kt, MazeSolver.kt, MazeGameScreen.kt, AppNavGraph.kt, GameUiState.kt — all work unchanged because CA output uses the same `List<List<MazeCell>>` contract.

---

## Verification

1. `./gradlew testDebugUnitTest` — existing tests pass (no regressions)
2. New test in `MazeTest.kt`:
   - Generate CA cave with known seed → verify start-exit path exists (BFS)
   - Verify deterministic output (same seed = same maze)
   - Verify no isolated floor cells (flood-fill from start reaches all floors)
   - Verify border cells are all walls
3. `./gradlew assembleDebug` — build succeeds
4. Manual test: launch app → Home → "Caverna Facile" → verify organic cave layout renders correctly
5. Git commit + push to Gitea

---

## Feature Roadmap (remaining)

After CA Caves, the next features from our research:
2. **Ghost AI Chase** (Pac-Man target-tile system) — ~8h
3. **Algorithm Visualizer** (educational step-by-step) — ~6h
4. **Entombed Row Gen** (32-byte constraint propagation) — ~5h

---

### 2. Diablo-Style Recursive Block Growth (Hybrid Generator)

**Research source:** Diablo L3 `DRLG_L3CreateBlock()` — recursive room-packing with 75% continuation, 3-directional branching, then CA smoothing
**What:** Port Diablo's caves algorithm to Kotlin as a third generation option.

**Implementation:**
- New function in `MazeAlgorithms.kt`: `diabloBlockGrowth(cells, seed)`
- Seed a 2x2 room, recursively attach 3-4 cell blocks in 3 directions (excluding arrival), 75% continuation probability
- Post-process with the CA smoothing functions from Feature 1
- Connectivity check + retry loop

**Why it matters:** Produces layouts that are neither corridor mazes nor pure caves — structured organic spaces with better connectivity than pure CA. No one has implemented this outside Diablo; the app could be the first mobile game to use the actual Diablo algorithm.

**Effort:** ~6h | **Files:** `MazeAlgorithms.kt`, `MazeGenerator.kt`

---

### 3. Ghost AI Chase Mode (Pac-Man Target-Tile System)

**Research source:** Pac-Man ghost AI — 4 distinct O(1) targeting heuristics creating emergent encirclement
**What:** Add AI-controlled "ghosts" (chasers) to maze gameplay using the Pac-Man targeting system.

**Implementation:**
- New file: `domain/game/ChaserAI.kt`
- 4 chaser personalities (from Pac-Man research):
  - **Direct** (Blinky): targets player's current cell
  - **Ambusher** (Pinky): targets 4 cells ahead of player's facing direction
  - **Flanker** (Inky): vector from Direct's position through 2 cells ahead, doubled
  - **Patrol** (Clyde): chases when >8 cells away, retreats to home corner when close
- Movement: at each intersection, pick direction minimizing Euclidean distance to target (O(1), no pathfinding search)
- Scatter/chase mode cycling (configurable timing)
- Integration: new game mode "Chase" or as story mode encounters

**Why it matters:** Transforms appMaze from pure puzzle into action-puzzle. The Pac-Man ghost system is proven to create emergent difficulty from simple rules — 4 simple heuristics produce effective encirclement without explicit coordination.

**Effort:** ~8h | **Files:** new `ChaserAI.kt`, `MazeEngine.kt`, `GameViewModel.kt`, `MazeCanvas.kt` (render chasers)

---

### 4. Entombed-Style Row Generation (Ultra-Lightweight Mode)

**Research source:** Entombed 32-byte lookup table — 5-cell neighborhood constraint propagation generating infinite mazes with minimal memory
**What:** Implement the Muirhead-Newell algorithm as a novel scrolling maze mode.

**Implementation:**
- New file: `domain/maze/EntombedGenerator.kt`
- 5-cell L-shaped neighborhood (2 left + 3 above) → 5-bit index → lookup table
- Three constraint rules: isolation prevention, density control, uniformity breaking
- Random output when no rule applies (SplitMix64)
- Bilateral symmetry (generate left half, mirror right)
- Vertical scrolling mode: generate rows on-the-fly as player moves up
- No chunk system needed — just keep previous row in memory

**Why it matters:** This is the most memory-efficient maze generation algorithm ever devised. Running it on modern Android hardware is a fun historical reference. The vertically-scrolling maze mode would be unique in the app store. Could be framed as a "retro" or "arcade" mode.

**Effort:** ~5h | **Files:** new `EntombedGenerator.kt`, new screen/mode in navigation

---

### 5. Algorithm Visualizer / Educational Mode

**Research source:** All research — the taxonomy of what algorithms actually ship in games
**What:** An interactive visualizer showing maze generation step-by-step.

**Implementation:**
- New screen: `AlgorithmVisualizerScreen.kt`
- Render generation in slow motion (coroutine with delay between steps)
- Support visualizing: DFS backtracking, Growing Tree, CA smoothing, Diablo block growth
- Color-coded: active cell (yellow), visited (green), walls being removed (red flash)
- Speed control (1x → 10x → instant)
- Algorithm info panel with description from our research

**Why it matters:** Educational value — users see HOW maze generation works. Differentiator from other maze apps. Directly uses the research insights about how shipped games generate mazes.

**Effort:** ~6h | **Files:** new `AlgorithmVisualizerScreen.kt`, new `VisualizableAlgorithm` interface in `MazeAlgorithms.kt`

---

### 6. Marching Squares Tile Rendering

**Research source:** Diablo L1/L3/L4 marching squares — 2x2 binary neighborhood → 4-bit index → 16 tile variants
**What:** Replace the current line-based wall rendering with tile-based rendering using the marching squares technique.

**Implementation:**
- 16 tile configurations derived from 2x2 wall/floor neighborhoods
- Each configuration maps to a distinct visual tile (corner, straight wall, T-junction, etc.)
- Draw pre-rendered tile bitmaps instead of `drawLine()` calls
- Much richer visual quality — walls look like actual dungeon/cave walls instead of lines

**Why it matters:** Current `MazeCanvas.kt` draws walls as simple lines. Marching squares (the exact technique Diablo uses) would give the maze a polished, game-quality appearance. The 16-entry lookup table is trivial to implement.

**Effort:** ~5h (including creating 16 tile assets) | **Files:** `MazeCanvas.kt`, new `TileRenderer.kt`, asset PNGs

---

### 7. Constrained Path-First Mode (Spelunky-Style)

**Research source:** Spelunky's guaranteed-solvable path generation
**What:** Generate mazes where a critical path is guaranteed first, then fill around it.

**Implementation:**
- Divide maze into room grid (e.g., 4x4 rooms of 5x5 cells each for a 20x20 maze)
- Generate solution path via biased random walk (40% L, 40% R, 20% down)
- Each room has exit points matching the required path connections
- Fill non-path rooms with optional connections or dead ends
- Result: mazes with a guaranteed "spine" but rich branching structure

**Why it matters:** Current Growing Tree guarantees connectivity but doesn't control path structure. Spelunky-style generation lets you design difficulty curves by controlling the critical path length and branching density.

**Effort:** ~6h | **Files:** new `RoomBasedGenerator.kt` in `domain/maze/`

---

## Priority Ranking

| # | Feature | Effort | Impact | Research Novelty | Recommended |
|---|---------|--------|--------|-----------------|-------------|
| 1 | CA Caves | 4h | High (new gameplay) | Medium | **YES — start here** |
| 3 | Ghost AI Chase | 8h | Very High (new game mode) | High (Pac-Man system) | **YES — highest impact** |
| 5 | Algorithm Visualizer | 6h | High (educational) | Very High | **YES — unique differentiator** |
| 4 | Entombed Row Gen | 5h | Medium (novelty mode) | Very High (first mobile impl) | YES |
| 6 | Marching Squares Tiles | 5h | High (visual quality) | Medium | YES |
| 2 | Diablo Block Growth | 6h | Medium (variant) | Very High | Optional |
| 7 | Spelunky Path-First | 6h | Medium (design control) | Medium | Optional |

## Recommended Implementation Order

1. **CA Caves** (simplest new algorithm, immediate visual impact)
2. **Ghost AI Chase** (transforms gameplay, uses proven Pac-Man research)
3. **Algorithm Visualizer** (educational showcase of all algorithms)
4. **Entombed Row Gen** (unique retro mode)

## Verification

For each feature:
1. `./gradlew testDebugUnitTest` — existing tests still pass
2. New tests for each algorithm (connectivity, solvability, deterministic seeding)
3. Build APK: `./gradlew assembleDebug`
4. Manual testing on device/emulator

## Critical Files

- `/data/massimiliano/appmaze/app/src/main/kotlin/com/massimiliano/appmaze/domain/maze/MazeAlgorithms.kt`
- `/data/massimiliano/appmaze/app/src/main/kotlin/com/massimiliano/appmaze/domain/maze/MazeGenerator.kt`
- `/data/massimiliano/appmaze/app/src/main/kotlin/com/massimiliano/appmaze/domain/maze/InfiniteMazeManager.kt`
- `/data/massimiliano/appmaze/app/src/main/kotlin/com/massimiliano/appmaze/domain/engine/MazeEngine.kt`
- `/data/massimiliano/appmaze/app/src/main/kotlin/com/massimiliano/appmaze/ui/components/MazeCanvas.kt`
- `/data/massimiliano/appmaze/app/src/main/kotlin/com/massimiliano/appmaze/ui/game/GameViewModel.kt`
