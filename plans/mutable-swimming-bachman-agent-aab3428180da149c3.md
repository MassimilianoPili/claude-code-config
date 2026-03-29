# Deep Dive: Diablo 1 Dungeon Generation (Devilution Source) vs NetHack

## Research Summary

**Epistemic status:** High confidence -- based on direct reading of decompiled/reverse-engineered source code (Devilution project) and the official NetHack 3.7 source. No academic papers specifically analyze Diablo 1's dungeon generation algorithm at the source-code level; the closest is BorisTheBrave's blog post (T5, boristhebrave.com, 2019) which was found but could not be fetched due to a 502 error. The academic PCG literature (T1 -- Shaker, Togelius & Nelson 2016, ~463 citations on OpenAlex) discusses general dungeon generation taxonomies but does not reverse-engineer Diablo specifically.

**Source:** `diasurgical/devilution` repository on GitHub -- a byte-accurate decompilation of the original Diablo 1.09b executable. The code is C++ with original Blizzard North function and variable names recovered.

---

## 1. DRLG_L3 -- The Caves Generator (Levels 9-12)

### 1.1 High-Level Pipeline

From the `DRLG_L3(int entry)` function (chunk 7-8 of source), the full pipeline is:

```
do {
  do {
    do {
      1. InitL3Dungeon()           -- zero out 40x40 grid
      2. Seed: place a 2x2 room at random position (10-30, 10-30)
      3. DRLG_L3CreateBlock() x4   -- recursive room growth in all 4 directions
      4. [If Anvil quest: carve a 12x12 floor area]
      5. DRLG_L3FillDiags()        -- CA smoothing pass 1
      6. DRLG_L3FillSingles()      -- CA smoothing pass 2
      7. DRLG_L3FillStraights()    -- CA smoothing pass 3
      8. DRLG_L3FillDiags()        -- CA smoothing pass 4 (repeat)
      9. DRLG_L3Edges()            -- clear boundary row/column
     10. Check: floor area >= 600? If yes, run DRLG_L3Lockout()
    } while (!connected);          -- retry until single connected component
    11. DRLG_L3MakeMegas()         -- marching squares: binary -> tile IDs
    12. Place stairs (minisets L3UP, L3DOWN, L3HOLDWARP)
    13. [If Anvil quest: place L3ANVIL 11x11 miniset]
  } while (placement_failed);
  14. DRLG_L3Pool()                -- find enclosed voids, fill with lava (25% chance)
} while (!lavapool);               -- retry until at least one lava pool exists

15. DRLG_L3PoolFix()              -- clean up lava edges
16. FixL3Warp()                   -- fix warp tile rendering
17. PlaceRndSet(L3ISLE1..5)       -- replace small wall artifacts with floor/lava
18. FixL3HallofHeroes()           -- quest-specific fixup
19. DRLG_L3River()                -- generate lava rivers
20. DRLG_PlaceThemeRooms(5,10,7)  -- theme rooms
21. DRLG_L3Wood()                 -- wooden fence features (Hellfire: fences in caves)
22. PlaceRndSet(L3TITE1..13)      -- stalactite/stalagmite decorations (10-30% each)
23. PlaceRndSet(L3CREV1..11)      -- wall crack decorations (30% each)
24. PlaceRndSet(L3XTRA1..5)       -- random floor/wall tile variation (25% each)
```

### 1.2 DRLG_L3CreateBlock() -- Recursive Room Growth

This is the core structure generator. It is **not** BSP, **not** cellular automata alone, and **not** a random walk. It is a **recursive room-packing algorithm with stochastic continuation**.

```c
static void DRLG_L3CreateBlock(int x, int y, int obs, int dir)
{
    int blksizex, blksizey, x1, y1, x2, y2;
    int contflag;

    // Random room size: 3-4 in each dimension
    blksizex = random_(0, 2) + 3;   // [3, 4]
    blksizey = random_(0, 2) + 3;   // [3, 4]

    // Position the new room adjacent to the calling edge,
    // with random lateral offset based on overlap (obs)
    // dir: 0=north, 1=east, 2=south, 3=west
    if (dir == 0) {
        y2 = y - 1;
        y1 = y2 - blksizey;
        // lateral positioning depends on obs vs blksizex
        if (blksizex < obs)  x1 = random_(0, blksizex) + x;
        if (blksizex == obs) x1 = x;
        if (blksizex > obs)  x1 = x - random_(0, blksizex);
        x2 = blksizex + x1;
    }
    // ... similar for dir 1, 2, 3 ...

    // Try to place the room (checks bounds and non-overlap)
    if (DRLG_L3FillRoom(x1, y1, x2, y2) == TRUE) {
        // 75% chance to continue growing (contflag != 0 when random_(0,4) != 0)
        contflag = random_(0, 4);
        // Recurse in all 3 directions EXCEPT the one we came from
        if (contflag != 0 && dir != 2)  // don't go south if we came from south
            DRLG_L3CreateBlock(x1, y1, blksizey, 0);  // grow north
        if (contflag != 0 && dir != 3)
            DRLG_L3CreateBlock(x2, y1, blksizex, 1);  // grow east
        if (contflag != 0 && dir != 0)
            DRLG_L3CreateBlock(x1, y2, blksizey, 2);  // grow south
        if (contflag != 0 && dir != 1)
            DRLG_L3CreateBlock(x1, y1, blksizex, 3);  // grow west
    }
}
```

**Key parameters:**
- `x, y`: anchor point on the edge of the parent room
- `obs`: "overlap size" -- the dimension of the parent along the shared edge
- `dir`: direction of growth (0=N, 1=E, 2=S, 3=W)
- Room size: always 3x3 to 4x4 (inner floor is 1x1 to 2x2 due to border)
- **Continuation probability: 75%** (contflag = random_(0,4); continue if != 0)
- **Branching factor: up to 3** (all directions except origin)
- **Termination:** room placement fails (overlap or out-of-bounds), OR 25% chance to stop

**DRLG_L3FillRoom** validates placement:
- Bounds check: x1 > 1, x2 < 34, y1 > 1, y2 < 38 (the dungeon map is 40x40 but reserves a border)
- Non-overlap: sum of all cells in target area must be 0
- Interior cells set to 1 (floor)
- Border cells: each edge cell has a **50% chance** of being set to 1 (creating the ragged cave edges)

### 1.3 CA Smoothing Functions

After the recursive room-packing produces a binary grid (0=wall, 1=floor), four smoothing passes run:

#### DRLG_L3FillDiags() -- Diagonal connectivity fix

Examines every 2x2 subgrid. Encodes the 4 cells as a 4-bit value:
```
v = cell[i+1][j+1] + 2*cell[i][j+1] + 4*cell[i+1][j] + 8*cell[i][j]
```

Only acts on two specific diagonal patterns:
- **v == 6** (0110 binary): top-right and bottom-left are floor, others wall. A "diagonal bridge." Randomly fills either top-left OR bottom-right with floor (50/50).
- **v == 9** (1001 binary): top-left and bottom-right are floor, others wall. The other diagonal. Randomly fills either top-right OR bottom-left.

This prevents thin diagonal-only connections that would look wrong when tiled.

#### DRLG_L3FillSingles() -- Fill enclosed single voids

For each wall cell (0) completely surrounded by floor (all 8 neighbors are 1), convert it to floor. This eliminates single-cell pillars inside rooms.

The check is split into three tests:
```c
if (dungeon[i][j] == 0
    && dungeon[i][j-1] + dungeon[i-1][j-1] + dungeon[i+1][j-1] == 3  // top row all floor
    && dungeon[i+1][j] + dungeon[i-1][j] == 2                         // sides all floor
    && dungeon[i][j+1] + dungeon[i-1][j+1] + dungeon[i+1][j+1] == 3)  // bottom row all floor
```

#### DRLG_L3FillStraights() -- Roughen straight edges

Finds long straight wall-floor boundaries (runs > 3 cells) and randomly fills in some of the wall cells along them. This is the key function that makes caves look *organic* rather than rectangular.

Four passes: horizontal edges (floor-above-wall), horizontal edges (wall-above-floor), vertical edges (floor-left-of-wall), vertical edges (wall-left-of-floor).

For each run of length > 3:
- 50% chance to act at all
- For each cell in the run: 50% chance to fill it (set to 1) or leave it (set to 0)

This creates the characteristic jagged cave edges.

### 1.4 L3ConvTbl[16] -- The Marching Squares Table

```c
const BYTE L3ConvTbl[16] = { 8, 11, 3, 10, 1, 9, 12, 12, 6, 13, 4, 13, 2, 14, 5, 7 };
```

This maps 2x2 binary patterns to tile IDs. The encoding is:
```
Index = cell[i+1][j+1] + 2*cell[i][j+1] + 4*cell[i+1][j] + 8*cell[i][j]
```

| Index | Binary (TL,TR,BL,BR) | Pattern | Tile ID | Meaning |
|-------|----------------------|---------|---------|---------|
| 0     | 0000                 | All wall | **8**  | Solid wall |
| 1     | 0001                 | Only BR  | **11** | SW corner (inner) |
| 2     | 0010                 | Only BL  | **3**  | SE corner (inner) |
| 3     | 0011                 | Bottom   | **10** | Horizontal wall (south edge) |
| 4     | 0100                 | Only TR  | **1**  | NW corner (inner) |
| 5     | 0101                 | Right col| **9**  | Vertical wall (east edge) |
| 6     | 0110                 | Diagonal!| **12** or **5** (random) | Ambiguous diagonal |
| 7     | 0111                 | Missing TL| **12** | SW outer corner |
| 8     | 1000                 | Only TL  | **6**  | NE corner (inner) |
| 9     | 1001                 | Diagonal!| **13** or **14** (random) | Ambiguous diagonal |
| 10    | 1010                 | Left col | **4**  | Vertical wall (west edge) |
| 11    | 1011                 | Missing TR| **13** | SE outer corner |
| 12    | 1100                 | Top row  | **2**  | Horizontal wall (north edge) |
| 13    | 1101                 | Missing BL| **14** | NE outer corner |
| 14    | 1110                 | Missing BR| **5**  | NW outer corner |
| 15    | 1111                 | All floor| **7**  | Open floor |

Note: indices 6 and 9 (the two diagonal patterns) are **resolved randomly** in `DRLG_L3MakeMegas()` before the table lookup, choosing between two possible corner orientations.

### 1.5 DRLG_L3River() -- Lava River Generation

This is a **constrained random walk** that generates lava rivers through the caves:

1. **Start point:** Find a wall tile with value 25-28 (specific corner types indicating a wall-to-floor transition at the cave boundary). Up to 200 attempts.
2. **Direction selection:** Initial direction determined by wall orientation:
   - Tile 25 -> go west (dir=3)
   - Tile 26 -> go north (dir=0)
   - Tile 27 -> go south (dir=1)
   - Tile 28 -> go east (dir=2)
3. **Walk:** Random walk through floor tiles (value 7), up to 100 segments. At each step:
   - Try a random direction first, then rotate through alternatives
   - Cannot reverse direction (nodir) or repeat the last forbidden direction (nodir2)
   - If the cell is floor (7), place a river tile (15-18 for horizontal/vertical segments, 19-22 for corners depending on turn direction)
   - Track corners: when direction changes, retroactively replace the previous tile with the correct bend tile
4. **Termination:** The walk must reach another wall boundary (specific wall tile adjacent to the current cell). If the river is too short (< 7 segments), reject and retry.
5. **Bridge placement:** After a valid river, find a random straight segment and replace it with a bridge tile (44 or 45), ensuring the bridge has floor on both sides perpendicular to the river.
6. **River count:** Up to 4 rivers per level, with 200 total attempts.

**Tile assignments for river:**
- 15, 16: horizontal river segments (east-west flow)
- 17, 18: vertical river segments (north-south flow)
- 19-22: corner/bend tiles (4 orientations)
- 23, 24, 38-43: end caps at wall boundaries
- 44: bridge (horizontal crossing)
- 45: bridge (vertical crossing)

**Known bugs** (documented in source comments):
- `pdir` is uninitialized on first iteration
- Several boundary checks missing (can read out-of-bounds array indices)

### 1.6 DRLG_L3Lockout() -- Connectivity Check

Simple flood-fill connectivity verification:

```c
BOOL DRLG_L3Lockout()
{
    int i, j, t, fx, fy;
    t = 0;
    // Count all non-zero cells, record last one found as seed
    for (j = 0; j < DMAXY; j++)
        for (i = 0; i < DMAXX; i++)
            if (dungeon[i][j] != 0) {
                lockout[i][j] = TRUE;
                fx = i; fy = j;
                t++;
            } else {
                lockout[i][j] = FALSE;
            }

    lockoutcnt = 0;
    DRLG_L3LockRec(fx, fy);  // recursive flood fill from last non-zero cell

    return t == lockoutcnt;   // connected iff all non-zero cells were reached
}
```

`DRLG_L3LockRec` is a simple 4-directional recursive flood fill that clears visited cells from `lockout[][]` and increments `lockoutcnt`. If the total equals the count of non-zero cells, the level is fully connected.

**Note:** This is a generate-and-test approach -- the entire level is regenerated from scratch if it fails the connectivity check OR if the floor area is < 600 cells. Given the 40x40 grid = 1600 total cells, the minimum fill ratio is ~37.5%.

### 1.7 The Miniset System -- Quest Room Splicing

Minisets are small pattern-match-and-replace templates. Each miniset is a byte array:

```
[width, height, search_pattern..., replace_pattern...]
```

The system scans the dungeon for a matching `width x height` region where every non-zero cell in the search pattern matches the dungeon tile. If found, the replace pattern is stamped down (non-zero cells only).

Two placement modes:
- **DRLG_L3PlaceMiniSet():** Find a single placement (up to 200 random attempts). Used for stairs and quest features.
- **DRLG_L3PlaceRndSet():** Scan the entire map, place at every matching location with probability `rndper`%. Used for decorative elements.

**L3ANVIL** (Anvil of Fury quest): An 11x11 miniset that requires an 11x11 area of pure floor (all tile 7). It stamps down a lava-ringed island with the anvil in the center. The search pattern is all 7s (floor); the replacement includes lava border tiles (25-37) forming a diamond pattern.

**Protection system:** After placing a quest miniset, those cells are marked with `DLRG_PROTECTED` flag in `dflags[][]`, preventing subsequent minisets from overwriting them.

### 1.8 DRLG_L3Pool() -- Lava Pool Generation

Finds enclosed wall regions using a sophisticated spawn/flood-fill system:

1. Scan for wall tiles (value 8 = solid wall)
2. Flood fill from each wall tile using `DRLG_L3Spawn()` / `DRLG_L3SpawnEdge()`
3. If the flood fill finds a region of at most 40 tiles that does NOT touch the map edge, mark it as a candidate
4. With 25% probability (`poolchance < 25`), convert all tiles in the region to their lava equivalents using `poolsub[]`:
   ```c
   static BYTE poolsub[15] = { 0, 35, 26, 36, 25, 29, 34, 7, 33, 28, 27, 37, 32, 31, 30 };
   ```
5. Set `lavapool = TRUE`

The outer loop of `DRLG_L3()` requires at least one lava pool to exist (`while (!lavapool)`), meaning the entire level generation retries if no suitable enclosed region is found.

---

## 2. NetHack's Maze Generation (mkmaze.c)

### 2.1 The Algorithm: Recursive Backtracking

NetHack uses a **classic recursive backtracking maze algorithm** (also known as randomized depth-first search). From the source:

```c
// Non-MICRO (recursive) version:
void walkfrom(coordxy x, coordxy y, schar typ)
{
    int q, a, dir;
    int dirs[4];

    if (!typ) {
        if (svl.level.flags.corrmaze)
            typ = CORR;
        else
            typ = ROOM;
    }

    if (!IS_DOOR(levl[x][y].typ)) {
        levl[x][y].typ = typ;
        levl[x][y].flags = 0;
    }

    while (1) {
        q = 0;
        for (a = 0; a < 4; a++)
            if (okay(x, y, a))
                dirs[q++] = a;
        if (!q)
            return;                    // dead end: backtrack
        dir = dirs[rn2(q)];           // random unvisited neighbor
        mz_move(x, y, dir);          // step 1 (carve wall)
        levl[x][y].typ = typ;
        mz_move(x, y, dir);          // step 2 (reach next cell)
        walkfrom(x, y, typ);          // recurse
    }
}
```

**The `okay()` function** checks if a cell 2 steps away in direction `dir` is still STONE (unvisited):

```c
staticfn boolean okay(coordxy x, coordxy y, coordxy dir)
{
    mz_move(x, y, dir);
    mz_move(x, y, dir);
    if (x < 3 || y < 3 || x > x_maze_max || y > y_maze_max
        || levl[x][y].typ != STONE)
        return FALSE;
    return TRUE;
}
```

**Grid structure:** Cells are on odd coordinates (3, 5, 7, ...). Even coordinates are walls. Each "step" moves 2 units -- one to carve the wall between cells, one to reach the next cell. This produces a **perfect maze** (exactly one path between any two points, no loops).

**MICRO variant:** For memory-constrained platforms, an iterative version using an explicit stack array (`mazex[]`, `mazey[]`, max size CELLS = ROWNO*COLNO/4) is provided. Functionally identical.

### 2.2 create_maze() -- Variable-Width Corridors

NetHack 3.7 adds a `create_maze(corrwid, wallthick, rmdeadends)` wrapper:

1. Compute scale = corrwid + wallthick (1-10)
2. Generate the maze at reduced resolution (rdx * 2, rdy * 2)
3. Run `walkfrom()` on the reduced grid
4. Optionally remove dead ends (`maze_remove_deadends`)
5. Scale up: expand each corridor cell to `corrwid` width, each wall to `wallthick`
6. Apply `wallification()` (wall type assignment based on spine analysis)

Corridor width can be 1-5, wall thickness 1-5. This allows wide-corridor mazes not possible in earlier versions.

### 2.3 maze_remove_deadends() -- Optional Loop Creation

After generation, this scans for cells with only one open neighbor (dead ends) and opens a wall to connect them to an adjacent corridor, breaking the perfect maze property and creating loops. This is controlled by `rmdeadends` parameter (50% chance for random mazes).

### 2.4 Starting Point

```c
staticfn void maze0xy(coord *cc)
{
    cc->x = 3 + 2 * rn2((x_maze_max >> 1) - 1);
    cc->y = 3 + 2 * rn2((y_maze_max >> 1) - 1);
}
```

Random odd coordinate within the maze bounds. The maze is always connected by construction (DFS guarantees spanning tree).

---

## 3. Comparison Table: Diablo Caves vs NetHack Mazes

| Aspect | Diablo L3 (Caves) | NetHack (mkmaze.c) |
|--------|-------------------|---------------------|
| **Algorithm class** | Recursive room-packing + CA smoothing + generate-and-test | Recursive backtracking (randomized DFS) |
| **Grid size** | 40x40 (DMAXX x DMAXY) | ~79x21 (COLNO x ROWNO), scaled |
| **Topology guarantee** | None -- generate-and-test with flood fill | Guaranteed connected by construction (spanning tree) |
| **Perfect maze?** | No -- has open areas, multiple paths | Yes by default; optionally broken by dead-end removal |
| **Room vs corridor** | Open cave areas (organic shapes) | Corridors only (no rooms in pure maze) |
| **Wall representation** | Binary grid -> marching squares tiling | Cells on odd coords, walls on even coords |
| **Connectivity check** | Post-hoc flood fill (DRLG_L3Lockout) | Unnecessary -- DFS guarantees it |
| **Minimum area** | >= 600 floor cells (~37.5% of grid) | N/A (fills ~50% naturally) |
| **Feature injection** | Miniset pattern-match-replace system | Special levels (Lua scripts), object placement |
| **Natural features** | Lava rivers (random walk), lava pools (flood fill) | Moats, pools (hard-coded in special levels) |
| **Retry mechanism** | Triple-nested do-while (connectivity, stair placement, lava pools) | No retry needed |
| **Visual style** | Organic, cave-like (ragged edges from CA) | Geometric, grid-aligned corridors |
| **Branching** | Up to 3 children per room, 75% continuation | 1-4 children per cell (all unvisited neighbors) |
| **Quest integration** | Miniset stamps (Anvil of Fury 11x11 island) | Special level files override generation |
| **Dead-end handling** | None explicit (rooms are open) | Optional removal pass |
| **Decoration** | 30+ miniset patterns (stalactites, cracks, etc.) | Traps, objects, monsters placed after |
| **Code complexity** | ~1800 lines (drlg_l3.cpp) | ~1800 lines (mkmaze.c, but includes much non-maze code) |
| **Known bugs** | 8+ documented buffer overruns, uninitialized vars | Mature, well-tested (30+ years of patches) |

---

## 4. Architectural Differences -- Deeper Analysis

### 4.1 Generate-and-Test vs Correct-by-Construction

The most fundamental difference is epistemological:

**Diablo:** "Generate something plausible, then check if it's acceptable." The triple-nested retry loop means the generator can fail many times. The expected number of iterations is not bounded, though in practice the 600-cell minimum and connectivity requirements are met quickly because the recursive room-packer tends to produce well-connected layouts. The outermost loop (lava pool requirement) is the most likely to cause retries, since finding enclosed voids is topologically dependent on the specific room configuration.

**NetHack:** "Generate something that is correct by construction." The DFS spanning tree guarantees connectivity. The only quality control is the choice of starting point and corridor dimensions. This is computationally more efficient but produces less organic layouts.

### 4.2 Tile Assignment: Marching Squares vs Spine Analysis

Both games solve the same problem -- converting an abstract connectivity graph into renderable tile types -- but use different algorithms:

**Diablo** uses a classic 2x2 marching squares lookup (16 entries, L3ConvTbl). Each 2x2 subgrid of the binary floor/wall map produces a 4-bit index that maps directly to a tile ID. The two ambiguous diagonal cases (indices 6 and 9) are resolved randomly.

**NetHack** uses a more sophisticated `fix_wall_spines()` system that examines a 3x3 neighborhood around each wall cell, computing a 4-bit NSEW connectivity mask and looking up the appropriate wall type (VWALL, HWALL, TRCORNER, etc.) from `spine_array[16]`. The `extend_spine()` function adds intelligence by suppressing spine extensions when the wall is part of a corridor (surrounded by walls in the perpendicular direction).

### 4.3 The CA Smoothing -- Diablo's Key Innovation

Diablo's cave generator is notable for applying **domain-specific cellular automata rules** that are NOT the classic Game-of-Life-style CA used in later roguelikes (e.g., Johnson et al.'s 4-5 rule). Instead, Diablo uses three targeted passes:

1. **FillDiags:** Only acts on exact diagonal-bridge patterns. Much more conservative than a general CA rule.
2. **FillSingles:** Only fills isolated wall cells completely surrounded by floor. A minimal cleanup.
3. **FillStraights:** The most impactful -- randomly roughens straight wall-floor boundaries. This is what makes the caves look *natural* rather than rectangular.

The combination produces caves that retain their room-based connectivity structure (from CreateBlock) while gaining organic-looking boundaries. This is architecturally more interesting than pure CA cave generation because it preserves the large-scale room connectivity while only modifying local geometry.

---

## 5. GDC Talk: David Brevik "Classic Game Postmortem: Diablo"

The talk was given at **GDC 2016** (not 2017 as initially searched). Found listed on gdcvault.com under the GDC 2016 free content section. Brevik was affiliated with Gazillion Entertainment at the time.

Key points from publicly available summaries:
- Brevik described the "terrible grind" of development
- The game was originally turn-based, inspired by XCOM and Rogue
- The real-time pivot happened after a pitch meeting
- Brevik cited Rogue, Moria, and Angband as inspirations for the procedural generation
- The dungeon generator was designed to be "infinitely replayable"

**No publicly available transcript** of the full talk was found. The GDC Vault has the video behind a paywall. BorisTheBrave's blog post "Dungeon Generation in Diablo 1" (2019) appears to be the most detailed public analysis based on the Devilution source, but the site returned a 502 error during this research session.

---

## 6. Academic Context

The PCG literature does not specifically analyze Diablo's source code, but provides taxonomic context:

- **Shaker, Togelius & Nelson (2016)** -- "Procedural Content Generation in Games" (T1, ~463 citations, OpenAlex). The definitive textbook. Categorizes dungeon generation approaches: agent-based, space partitioning, cellular automata, grammar-based, constraint-based. Diablo's L3 generator would be classified as a **hybrid room-packing + CA** approach.

- **Hilliard, Salis & El-Aaragh (2017)** -- "Algorithms for procedural dungeon generation" (T1, Journal of Computing Sciences in Colleges, 8 citations). Surveys BSP, random walk, and cellular automata approaches for dungeon generation. Does not reference Diablo specifically.

- **Pereira et al. (2021)** -- "Procedural generation of dungeons' maps and locked-door missions through an evolutionary algorithm" (T1, Expert Systems with Applications, 19 citations). Uses evolutionary algorithms to optimize dungeon connectivity with lock-and-key puzzles -- a different paradigm from Diablo's generate-and-test.

- **Putra, Tarigan & Zamzami (2023)** -- "Procedural 2D Dungeon Generation Using BSP Algorithm and L-Systems" (6 citations). Combines BSP space partitioning with L-systems for corridor generation. BSP is the algorithm used by Diablo's **cathedral** generator (drlg_l1.cpp), not the caves.

---

## 7. Serendipitous Connections

### 7.1 Marching Squares and Computational Topology
Diablo's `L3ConvTbl[16]` is a direct application of the **marching squares** algorithm from computational geometry (Lorensen & Cline, 1987 -- originally for 3D as "marching cubes"). The same lookup table structure appears in isosurface extraction, geographic information systems, and medical imaging. The 16-entry table with 2 ambiguous cases (indices 6, 9) is the classic formulation.

### 7.2 Phase Transitions in Random Graphs
The connectivity check (`DRLG_L3Lockout`) combined with the minimum area requirement (>=600) acts as a **percolation threshold** filter. The recursive room-packing produces a random graph of overlapping rooms, and the flood-fill connectivity check determines whether this graph percolates (i.e., forms a giant connected component). The 37.5% fill ratio threshold is in the neighborhood of the site percolation threshold for a square lattice (~59.3% for standard percolation, but Diablo's rooms create correlated structures that shift the effective threshold).

### 7.3 Connection to Agent Framework Project
The miniset pattern-match-replace system is structurally similar to **production rules in grammar-based generation** and could inform the agent-framework's task graph construction. The search-pattern + replace-pattern format is essentially a rewriting rule applied to a 2D grid -- analogous to graph rewriting rules in the `task_graph` AGE graph.

---

## Quality Checklist

- [x] Primary sources fetched: Devilution drlg_l3.cpp (11 chunks, ~62KB), NetHack mkmaze.c (chunks 0-7)
- [x] Epistemic status labeled (High -- direct source code reading)
- [x] Source tiers: code is T1-equivalent (primary source), blog references are T5
- [x] Serendipitous connections section included
- [x] No fabricated citations -- all code snippets from actual fetched source
- [x] OpenAlex search performed for academic context
- [x] GDC talk attribution corrected (2016 not 2017)
- [x] Agent framework project connection noted
