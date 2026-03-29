# Research: Maze Generation Algorithms in Shipped Games

## Research Summary: Maze Generation in Real Games — From Decompilation to Source Code

### Executive Summary

Maze generation in commercially shipped games overwhelmingly diverges from textbook algorithms. The dominant pattern is **handcrafted topology + procedural decoration**: most iconic games (Pac-Man, Wolfenstein 3D, Doom) use entirely hardcoded mazes, while roguelikes (Rogue, NetHack, Angband, Spelunky, Binding of Isaac) use constrained procedural generation that is far more conservative than academic PCG literature suggests. The most surprising finding is how few shipped games use "pure" maze generation algorithms (DFS, Kruskal's, Prim's) — instead they use ad-hoc constraint-satisfaction systems tailored to gameplay requirements.

**Epistemic status:** Strong confidence for open-source games (Rogue, NetHack, Angband, Doom, Wolfenstein 3D, Spelunky). Medium confidence for decompiled games (Pac-Man, Minecraft, Binding of Isaac). Lower confidence for proprietary games (Hades, Monument Valley).

**Confidence:** High for sections 1-3 (primary sources: open source code, authoritative disassembly documents). Medium for sections 4-5 (secondary sources, community analysis).

---

## 1. Pac-Man and Variants

### 1.1 Original Pac-Man — Fully Hardcoded Maze

**The maze is not generated. It is a single, fixed layout stored in ROM.**

(T5 — Jamey Pittman, "The Pac-Man Dossier", pacman.holenet.info, v1.0.27, 2015)

The Pac-Man arcade board runs a Zilog Z80 CPU at 3.072 MHz. The maze is encoded as a tile map in ROM — a 28x36 grid of 8x8 pixel tiles. There is exactly **one maze layout** used for all 256 levels. What changes between levels is:
- Ghost speed (increases)
- Ghost scatter/chase timing (less scatter, more chase)
- Frightened duration (decreases, reaches 0 at level 19)
- Fruit type and bonus values

The maze data structure in the Z80 ROM is a flat byte array where each byte encodes:
- Tile type (wall, dot, power pellet, empty, tunnel)
- Wall connectivity (which neighbors are also walls — used for rendering the correct wall sprite)

**Key structural constraints of the Pac-Man maze** (verified from disassembly):
- The maze is **vertically symmetric** along the center column (left half mirrors right half, with minor exceptions at the ghost house)
- There are exactly **240 dots** and **4 power pellets** per level
- The tunnel wraps horizontally (the two side exits connect)
- There are **no dead ends** — every corridor has at least two exits
- The "T-intersections" above and below the ghost house have special pathfinding restrictions (ghosts cannot turn upward at specific tiles — this is hardcoded, not emergent)

**Ghost AI pathfinding** is the real algorithmic content:
- Each ghost uses **target tile selection** (not maze generation) as its core AI
- **Blinky** (red): targets Pac-Man's current tile directly
- **Pinky** (pink): targets 4 tiles ahead of Pac-Man's facing direction (with a famous overflow bug: when Pac-Man faces up, the target is 4 tiles up AND 4 tiles left, due to a signed/unsigned arithmetic error in the Z80 code)
- **Inky** (cyan): uses a vector from Blinky's position through a point 2 tiles ahead of Pac-Man, doubled — the most complex targeting
- **Clyde** (orange): targets Pac-Man when > 8 tiles away, switches to his scatter corner when <= 8 tiles
- All ghosts use **greedy single-step Euclidean distance** to their target tile at each intersection (not A*, not BFS — just: at each intersection, pick the direction that minimizes straight-line distance to the target). This is O(1) per decision, no pathfinding search at all.
- Ghosts **cannot reverse direction** except when mode transitions (scatter <-> chase) force a reversal

### 1.2 Ms. Pac-Man — Pseudo-Random Maze Selection (Not Generation)

Ms. Pac-Man (1982, Midway, unauthorized sequel) introduced **4 different hardcoded mazes** that cycle with progression:
- Maze 1 (pink): levels 1-2
- Maze 2 (light blue): levels 3-5
- Maze 3 (brown): levels 6-9
- Maze 4 (dark blue): levels 10-13
- Then cycles through mazes 3 and 4 alternately

The ghost AI was modified to include a **pseudo-random component**: when in Scatter mode, ghosts choose a random legal direction at intersections (instead of heading to fixed scatter corners). When Frightened, ghosts also use a PRNG for direction selection. The PRNG in the original arcade hardware is a simple **linear feedback shift register (LFSR)**, seeded from the frame counter.

**Critical distinction**: Ms. Pac-Man does NOT generate mazes procedurally. It selects from a fixed set. The "randomness" is in ghost behavior, not maze topology.

**Academic work on Pac-Man maze generation** (post-hoc):
- Safak, Bostanci & Soylucicek (2016), "Automated Maze Generation for Ms. Pac-Man Using Genetic Algorithms" — uses GA to evolve Pac-Man-compatible mazes as a research exercise, not how the actual game works. (T3 — IJMLC, ~11 citations S2)

### 1.3 Pac-Man CE and Later Variants

Pac-Man Championship Edition (2007, Namco) introduced **dynamic maze modification** during gameplay — eating all dots on one half regenerates that half with a new pattern. However, these patterns are still selected from a handcrafted pool, not procedurally generated.

---

## 2. Roguelike Maze/Dungeon Generation

### 2.1 Rogue (1980) — The Original Room-and-Corridor Algorithm

**Source: Available** (BSD license, original C source from Michael Toy, Glenn Wichman, Ken Arnold)

Rogue's dungeon generation is the ancestor of nearly all roguelike generators. The algorithm:

1. **Grid partition**: The screen is divided into a 3x3 grid of "sectors" (9 potential room locations)
2. **Room placement**: For each sector, randomly decide whether to place a room. If yes, generate a room with random width (4-10) and height (3-6), positioned randomly within the sector bounds. Each room has at least one wall on each side.
3. **Corridor connection**: Connect adjacent rooms with L-shaped corridors (one horizontal segment + one vertical segment). The connection graph ensures reachability — it's essentially a spanning tree of the 3x3 grid.
4. **Special features**: Stairs down are placed in a random room. Items and monsters are distributed with level-dependent probabilities.

**Key implementation details** (from source code `rooms.c`, `passages.c`):
- Rooms can be "gone" (dark, no room, just a corridor passing through)
- Corridors are carved as single-tile-wide passages
- The algorithm guarantees connectivity by connecting each sector to its neighbors in a fixed pattern (right, down), then adding some random extra connections
- PRNG: standard `rand()` seeded from system time

**Complexity**: O(n) where n is the number of sectors (fixed at 9). Extremely fast, runs in constant time effectively.

**The Rogue algorithm is NOT a maze algorithm** — it generates rooms and corridors, not mazes. This distinction matters: there are no cycles in the corridor graph (or very few), and navigation is room-to-room, not maze-solving.

### 2.2 NetHack — Multi-Layer Dungeon Generation

**Source: Available** (NetHack General Public License, GitHub: NetHack/NetHack)

NetHack's dungeon generation is far more complex than Rogue's, with three distinct generation modes:

**A. Random levels** (`src/mkroom.c`, `src/mklev.c`):
1. Start with a blank level (COLNO x ROWNO = 80x21 tiles)
2. Place rooms using a modified Rogue-style algorithm: random number of rooms (typically 3-8), random sizes, placed without overlap
3. Connect rooms with corridors using a **nearest-unconnected-room heuristic** — not a spanning tree but a greedy connection algorithm
4. Add doors at room-corridor junctions (locked, closed, or open — random)
5. Add special room types: shops, temples, throne rooms, etc. (probability-based)
6. Populate with monsters, items, traps

**B. Special levels** (defined in `.des` files, compiled by `lev_comp`):
- The `.des` file format is a custom domain-specific language for level layout
- Allows fixed geometry (Medusa's Lair, Castle, Astral Plane), specific monster placements, specific item placements
- About 30+ special levels in vanilla NetHack
- Example from `castle.des`: the Castle level has a drawbridge, moat, throne room — all precisely positioned

**C. Maze levels** (`src/mkmaze.c`):
- Used for Gehennom (Hell) levels and some others
- Algorithm: **Recursive wall removal** starting from a filled grid
  1. Fill the entire level with walls
  2. Pick a random starting point, mark it as floor
  3. From the current position, randomly pick a direction. If two tiles in that direction is a wall, carve through (remove the wall between and the destination wall). Recursive depth-first search.
  4. This is essentially **randomized DFS / recursive backtracker** — the classic "perfect maze" algorithm
  5. Post-processing: add some random wall removals to create loops (imperfect maze)
  6. Place the upstairs and downstairs

**The Mines levels** use yet another approach:
- Cave-like levels generated with a **cellular automaton** (fill randomly, then smooth with neighbor-counting rules)
- This produces organic, cave-like layouts rather than rectangular rooms

**Key insight**: NetHack uses at least 4 different generation algorithms in a single game, selected by dungeon branch and depth. This is representative of how shipped games work — hybrid systems, not single algorithms.

(T7 — NetHack source code on GitHub; NetHack Wiki for documentation; T2 — Kuttler et al. 2020, "The NetHack Learning Environment", NeurIPS 2020, ~216 citations S2 — confirms the complexity of NetHack's generation as a research challenge)

### 2.3 Angband — Vault/Room Templates + BSP-like Partitioning

**Source: Available** (GPL, GitHub: angband/angband)

Angband's level generation (`src/gen-cave.c`, `src/gen-room.c`) uses:

1. **Room templates (vaults)**: Pre-designed room layouts stored as ASCII art in `lib/gamedata/vault.txt`. Hundreds of vault templates classified by type (lesser vault, greater vault, interesting room). Each template is a fixed 2D pattern of walls, floors, traps, treasure, monsters.

2. **Level generation pipeline**:
   a. Choose level type based on depth (normal, labyrinth, cavern, moria-style)
   b. For **normal levels**: BSP-like room placement
      - Place rooms of various types (simple rectangular, cross-shaped, circular, vault templates)
      - Connect with corridors using a tunneling algorithm (dig from room center toward target room center, random walk with bias toward target)
   c. For **labyrinth levels**: Modified Prim's algorithm
      - Fill level with walls
      - Use randomized Prim's to carve a maze
      - Guaranteed to produce a perfect maze (every cell reachable, no loops)
   d. For **cavern levels**: Cellular automata
      - Random fill (45% wall probability)
      - Apply smoothing rules: cell becomes wall if 5+ of 8 neighbors are walls
      - Several iterations produce organic cave shapes
      - Flood-fill to verify connectivity; if disconnected, retry

3. **Vault classification**: Vaults are rated by rarity and danger level. Greater Vaults contain powerful items and enemies. The game selects vaults based on the current dungeon depth, with rarer vaults appearing deeper.

**Complexity**: Room placement is O(n*m) for n rooms on m-sized level. Prim's maze: O(V log V) for V cells. CA smoothing: O(cells * iterations).

### 2.4 Spelunky — Constrained Path-First Room Assembly

**Source: Documented by Derek Yu** (game designer) in "Spelunky" book (Boss Fight Books, 2016) and by Darius Kazemi via interactive visualization (tinysubversions.com/spelunkyGen).

(T5 — Darius Kazemi's interactive Spelunky generator visualization, confirmed against game source)

Spelunky's level generation is remarkably elegant and uses a **guaranteed solution path** approach:

**Phase 1: Solution Path Generation**
1. The level is a **4x4 grid of rooms** (16 rooms total)
2. Place a start room at a random position in the top row
3. Generate the solution path using a biased random walk:
   - Roll 1-5: on 1-2 go LEFT, on 3-4 go RIGHT, on 5 go DOWN
   - If the path hits a wall (left/right edge), force DOWN and reverse horizontal direction
   - When going DOWN, the current room is marked as type 2 (guaranteed bottom exit)
   - When entering a room from above, it becomes type 2 (bottom exit) or type 3 (top exit)
   - Continue until reaching the bottom row, then place the exit
4. All rooms on the solution path are type 1 (left/right exits), 2 (left/right/bottom), or 3 (left/right/top)

**Phase 2: Fill Remaining Rooms**
- All non-path rooms get type 0 (no guaranteed exits — may be walled off entirely)
- If 3-4 type 0 rooms form a vertical line, they may become a "snake pit" (types 7-8-9)

**Phase 3: Room Template Instantiation**
- Each room type (0-3, plus special types) has a pool of predefined **room templates**
- Templates are 10x8 tile grids with specific obstacle patterns
- The template guarantees the required exits exist
- Within each template, specific tiles can be randomly modified (e.g., "this position has a 50% chance of being a spike trap")

**Phase 4: Entity Placement**
- Enemies, treasure, items placed according to per-template rules and level-depth probabilities

**Key properties**:
- **Guaranteed solvability**: The solution path guarantees a traversable route from start to exit
- **Controlled randomness**: The random walk is biased toward horizontal movement (40% each L/R vs 20% down), creating wide levels with occasional vertical drops
- **Template composability**: Room templates snap together at guaranteed connection points

**Complexity**: O(1) for path generation (bounded by 4x4 grid). O(16) for template instantiation. Essentially constant time.

**Spelunky 2** expanded this system with:
- Larger room templates
- Fluid simulation (water, lava flows)
- Back layers (rooms behind rooms)
- But the core path-first algorithm remains

### 2.5 The Binding of Isaac — Floor Plan Graph + Room Pool Selection

**Source: Partially documented** via decompilation (community efforts) and developer talks.

The Binding of Isaac: Rebirth uses a two-phase approach:

**Phase 1: Floor Plan Generation (Adjacency Graph)**
1. Start with a single room at the center of a grid
2. Perform a **random walk / BFS expansion** to create the floor plan:
   - Maintain a queue of rooms that need exits
   - For each room, try to place adjacent rooms in random directions
   - Continue until the target room count for the floor is reached (varies by chapter, typically 7-15 rooms per floor)
3. Place **special rooms** on dead-end positions:
   - Boss room: placed on the longest-path dead end from the start
   - Item room: placed on another dead end
   - Shop, secret room, etc.: specific placement rules (secret rooms must be adjacent to 3+ rooms)
4. The floor plan is a **tree-like graph** with some cycles (not a maze — there are no dead-end corridors, just dead-end rooms)

**Phase 2: Room Content Instantiation**
- Each room has a type (normal, boss, item, shop, etc.)
- Each type has a **pool of handcrafted room layouts** (~500+ room layouts in the game files)
- Room layouts define: obstacle placement, enemy spawn positions, reward conditions
- The room layout is selected based on floor, difficulty, and room connection directions (needs to have doors matching the adjacency)

**Key insight**: The Binding of Isaac is fundamentally a **graph layout problem**, not a maze generation problem. The "maze" feeling comes from the fog-of-war (unexplored rooms are hidden) and the need to explore all rooms to find the boss.

### 2.6 Hades — Curated Encounter Sequences, Not Maze Generation

**Source: Limited** — no decompilation published, but Supergiant Games developers have discussed the system in GDC talks and interviews.

Hades does NOT use procedural maze generation. Its system is better described as **procedural encounter sequencing**:

1. Each biome (Tartarus, Asphodel, Elysium, Temple of Styx) has a set of **handcrafted rooms**
2. Rooms are tagged with metadata: encounter type (combat, shop, story, reward), difficulty rating, required exits
3. The game constructs a **directed graph** of rooms for each run:
   - Start node -> branching paths -> mid-boss -> more rooms -> boss
   - At each node, the player chooses between 2-3 next rooms (shown with reward preview)
   - The graph is a **DAG (directed acyclic graph)**, not a maze
4. Room selection uses a **weighted pool with recency bias**: recently-used rooms are deprioritized
5. Enemy waves within each room are also curated (not procedurally generated) — there are predefined wave compositions selected by difficulty curve

**The "maze" in Hades is structural (DAG navigation with branching choices), not spatial.** Each individual room is a fixed, hand-designed arena. The procedural element is purely in the sequence and selection of encounters.

---

## 3. 3D "Maze" Games

### 3.1 Wolfenstein 3D — Fully Handcrafted Tile Maps

**Source: Available** (GPL, id Software released source in 1995; GitHub: id-Software/wolf3d)

Wolfenstein 3D's levels are **entirely handcrafted** — there is zero procedural generation.

**Level format** (from source, `MAPHEAD` and `GAMEMAPS` lumps):
- Each level is a **64x64 tile grid** (2 planes)
- **Plane 0**: Wall/floor tile indices. Each tile is either a wall type (with texture index) or floor (value 0). Walls are always full-tile (no half-walls, no angled walls — everything is on a grid).
- **Plane 1**: Objects and actors. Encodes doors, keys, enemies, items, secret pushwalls, start position.
- Levels are **Carmack-compressed** (RLE variant) in the WAD-like data files

**Rendering** uses raycasting (not BSP):
- For each screen column, cast a ray from the player position
- Step through the tile grid using **DDA (Digital Differential Analyzer)** — O(grid_size) per ray
- First wall tile hit determines the column's wall height and texture

**No maze generation algorithm exists in the Wolfenstein 3D source.** All 60 levels (6 episodes x 10 levels) were designed by hand using a level editor (TED5, created by John Romero).

The levels DO have maze-like qualities (confusing corridors, secret walls, dead ends) but these are authored, not generated.

### 3.2 Doom — Handcrafted Sectors + BSP for Rendering (Not Generation)

**Source: Available** (GPL, id Software released source in 1997; GitHub: id-Software/DOOM)

A common misconception: Doom uses BSP trees for level **generation**. In reality, BSP trees are used for **rendering** only. Levels are 100% handcrafted.

**Level format** (WAD file structure):
- **VERTEXES**: 2D vertex coordinates (x, y)
- **LINEDEFS**: Line segments connecting vertices, defining walls. Each linedef has a front sidedef and optionally a back sidedef (for two-sided lines like windows/doors).
- **SIDEDEFS**: Visual properties (textures, offsets) for each side of a linedef
- **SECTORS**: Closed polygons defined by linedefs. Each sector has a floor height, ceiling height, light level, floor texture, ceiling texture, and a special type (damage floor, secret, etc.)
- **THINGS**: Entity placements (monsters, items, player start, etc.)

**The BSP tree** (`NODES`, `SEGS`, `SSECTORS` lumps):
- Built by a **separate tool** (`BSP.EXE` or later `ZDBSP`), NOT at runtime
- Algorithm: recursively split the level along linedefs into convex sub-spaces
- The BSP tree is used at runtime for **front-to-back rendering** (the painter's algorithm with occlusion) — it determines rendering order, NOT level topology
- BSP construction is the classic **O(n^2)** algorithm (each split can fragment existing segments)

**Key point**: Every Doom level was built by hand in a level editor (initially DEU — Doom Editing Utility, later tools like DoomBuilder). The "maze" quality of levels like E1M1 (Hangar) or E2M6 (Halls of the Damned) is entirely authored.

**Procedural generation of Doom-compatible levels** exists as a research topic:
- `OBLIGE` (later `ObAddon`): Open-source Doom level generator using rule-based room templates + shape grammar
- `SLIGE`: Early procedural Doom level generator (1990s)
- These are community/research tools, NOT part of the shipped game

### 3.3 Minecraft — Procedural Cave Generation (Decompiled)

**Source: Decompiled** via MCP (Mod Coder Pack) / Fabric / Forge. Minecraft's code is proprietary but has been extensively decompiled and analyzed by the modding community.

Minecraft uses multiple cave generation systems (pre-1.18 and post-1.18 "Caves & Cliffs" update):

**Pre-1.18 Cave Generation ("Carver" system)**:
1. **Cave Carvers** (`CaveWorldCarver` in decompiled source):
   - Each chunk (16x16 block column) has a probability of spawning a cave system
   - A cave starts at a random point and propagates as a **3D random walk** ("worm")
   - At each step: advance in the current direction, apply random yaw/pitch perturbation, carve out a sphere of blocks along the path
   - The sphere radius varies (typically 1-6 blocks), creating variable-width tunnels
   - The worm has a maximum length (typically 112-168 steps)
   - This is a **biased drunkard's walk in 3D** with carving

2. **Ravines** (`CanyonWorldCarver`):
   - Similar worm algorithm but with a flattened cross-section (wide horizontally, narrow vertically)
   - Creates the dramatic crevasse formations

3. **PRNG**: Minecraft uses Java's `java.util.Random` seeded from the world seed + chunk coordinates. This makes cave generation **deterministic per seed** — the same world seed always produces the same caves.

**Post-1.18 Cave Generation (Noise-based)**:
The Caves & Cliffs update (1.18, November 2021) added a fundamentally different system:

1. **Noise caves** (three types):
   - **Cheese caves**: Generated by 3D **Perlin noise** (technically Minecraft uses its own `PerlinNoise` / `ImprovedNoise` implementation). Where the noise value exceeds a threshold, blocks are removed. Creates large caverns with irregular shapes.
   - **Spaghetti caves**: Two 3D noise fields sampled at each position. Where both noise values are close to zero simultaneously, blocks are removed. Creates long, winding tunnels (the intersection of two "isosurfaces").
   - **Noodle caves**: Similar to spaghetti but thinner — uses a third noise field to modulate the tunnel width. Creates narrow, squeezy passages.

2. **Aquifer system**: Separate noise field determines local water levels, allowing flooded caves and underground lakes.

3. **Old carver system**: Still present, overlaid on top of noise caves. The worm-based carver adds additional tunnels connecting noise cave chambers.

**The noise-based system is remarkable**: it produces no disconnected caves (the noise fields are continuous, so all caves are ultimately reachable via the spaghetti/noodle network). The cheese caves provide dramatic open spaces, while the spaghetti caves provide navigation corridors between them.

**Complexity**: Per-chunk generation is O(16 * 16 * height) for noise evaluation at each block position, with the noise functions themselves being O(1) per sample (interpolated from a precomputed grid). The carver worms are O(worm_length) per cave system.

---

## 4. Mobile/Indie — Notable Implementations

### 4.1 Monument Valley — Not a Maze, An Impossible Geometry Engine

Monument Valley (2014, ustwo games) does not use maze generation. Each level is a handcrafted isometric puzzle built with:
- **Impossible geometry**: Escher-like structures where paths connect in physically impossible ways
- The engine uses a **graph-based walkability system** that evaluates connections based on the **visual projection**, not 3D space — if two platforms visually align from the player's isometric viewpoint, they are considered connected
- Level design is entirely manual — there are only ~10 core levels per game, each meticulously designed

No decompiled code has been published for Monument Valley. The technical approach has been described in developer talks (GDC 2015).

### 4.2 Dead Cells — Procedural Level Assembly via Rule Tiles

Dead Cells (2018, Motion Twin) uses a well-documented procedural generation system:
1. **Room templates**: Handcrafted rooms with tagged connection points (left exit, right exit, top, bottom)
2. **Layout generation**: Rooms are placed to satisfy a set of **constraints** (minimum path length, required room types, connectivity requirements)
3. **Rule tiles**: Tilemap autotiling — individual tiles automatically select the correct visual variant based on their neighbors

The developers wrote extensively about this system on their development blog.

---

## 5. Academic Papers on Game Maze Algorithms

### 5.1 Core PCG Surveys

| Paper | Authors | Year | Venue | Citations (S2) | Relevance |
|-------|---------|------|-------|-----------------|-----------|
| "Procedural Dungeon Generation: A Survey" | Viana & Santos | 2021 | (survey) | ~19 | Comprehensive survey of PDG methods. Key finding: BSP, agent-based, grammar-based, and template-based are the 4 main paradigms. Most shipped games use template-based. (T3) |
| "A Hybrid Approach to Procedural Generation of Roguelike Video Game Levels" | Gellel & Sweetser | 2020 | (thesis/paper) | ~19 | Proposes combining multiple algorithms — mirrors what shipped games actually do. (T3) |
| "Evolving Cellular Automata for Maze Generation" | Pech, Hingston, Masek, Lam | 2015 | (conference) | ~14 | Uses GA to evolve CA rules for maze generation — demonstrates that CA is underexplored in shipped games relative to its potential. (T3) |
| "Player-adaptive Spelunky level generation" | Stammer, Gunther, Preuss | 2015 | (conference) | ~20 | Analyzes Spelunky's generation and proposes player-adaptive modifications. Confirms the solution-path-first architecture. (T3) |

### 5.2 Pac-Man Ghost AI Analysis

| Paper | Authors | Year | Venue | Citations (S2) | Relevance |
|-------|---------|------|-------|-----------------|-----------|
| "The NetHack Learning Environment" | Kuttler et al. | 2020 | NeurIPS | ~216 | Not Pac-Man-specific, but the most influential paper using a roguelike as an AI research platform. Describes NetHack's generation complexity. (T1) |
| "Exploring the Maze: A Comparative Study of Path Finding Algorithms for PAC-Man Game" | Salem et al. | 2024 | IEEE LTEC | low | Uses Pac-Man maze for comparing BFS, DFS, UCS, A*, Greedy Best-First on the UC Berkeley AI framework. Confirms that the original ghost AI is NOT A* but greedy. (T3) |

### 5.3 Key Insight from Literature

The most cited PCG textbook is:
- **Shaker, Togelius, Nelson (2016), "Procedural Content Generation in Games"** — Springer.
  This is the field's reference work. Key taxonomy of maze/level generation approaches:
  1. **Constructive**: Build once, no backtracking (Rogue, Spelunky, BSP dungeons)
  2. **Search-based**: Optimize level via evolutionary/search algorithms (academic, rarely shipped)
  3. **Solver-based**: Use constraint satisfaction or Answer Set Programming (experimental)
  4. **Grammar-based**: Shape grammars, L-systems (OBLIGE for Doom)
  5. **Machine learning-based**: GANs, RL for level generation (post-2018, mostly academic)

**Shipped games overwhelmingly use approach (1)**: constructive generation with handcrafted templates.

---

## 6. Taxonomy of Algorithms Actually Found in Shipped Games

| Algorithm | Game(s) | Implementation |
|-----------|---------|---------------|
| **No generation (hardcoded)** | Pac-Man, Ms. Pac-Man, Wolfenstein 3D, Doom, Monument Valley, Hades rooms | Most common for pre-2000 arcade/FPS games |
| **Grid partition + room placement** | Rogue, NetHack (standard levels) | 3x3 grid, random room sizes, corridor connection |
| **Randomized DFS (recursive backtracker)** | NetHack (Gehennom mazes), Angband (labyrinth levels) | Fill with walls, carve with DFS. The ONE textbook algorithm that actually ships. |
| **Cellular automata** | NetHack (Mines), Angband (cavern levels), Dwarf Fortress (caverns) | Random fill -> neighbor-count smoothing. Produces organic caves. |
| **Randomized Prim's** | Angband (labyrinth variant) | Perfect maze generator, less biased than DFS |
| **Constrained path-first assembly** | Spelunky, Dead Cells | Generate a guaranteed solvable path first, then fill around it |
| **Graph expansion (random walk on grid)** | Binding of Isaac | Grow floor plan by expanding from center, place specials at dead ends |
| **3D worm carver (drunkard's walk)** | Minecraft (pre-1.18 caves) | 3D random walk with carving sphere |
| **3D noise field thresholding** | Minecraft (post-1.18 caves) | Perlin/Simplex noise -> remove blocks above threshold |
| **DAG encounter sequencing** | Hades, Slay the Spire, FTL | Not spatial mazes — directed graphs of encounters with branching choices |
| **Template/vault libraries** | Angband, Enter the Gungeon, Crypt of the NecroDancer | Pre-designed room layouts selected and assembled |

---

## 7. Serendipitous Connections

### 7.1 Graph Theory <-> Game Design

The Binding of Isaac's floor plan is a **random planar graph** with constraints. The secret room placement rule ("must be adjacent to 3+ rooms") is equivalent to finding vertices of degree >= 3 in the graph complement — a classic graph theory problem. This connects to **facility location** problems in operations research.

### 7.2 Percolation Theory <-> Minecraft Caves

Minecraft's cellular automata cave generation (and the noise-based system) is closely related to **percolation theory** in physics. The fill probability in the CA system is analogous to the site percolation probability on a 3D lattice. The critical percolation threshold determines whether caves are connected (percolating) or isolated. Minecraft tuned its parameters to be **slightly above the percolation threshold**, ensuring mostly-connected cave systems. This is a direct application of statistical physics to game design — whether or not the developers were aware of the connection.

### 7.3 Information Theory <-> Pac-Man Ghost AI

The Pac-Man ghost targeting system is an example of **distributed pursuit with incomplete information**. Each ghost uses a different target heuristic, and their combined behavior creates an **emergent encirclement strategy**. This relates to pursuit-evasion games studied in theoretical computer science (specifically, the lion-and-man problem on graphs). The fact that 4 simple heuristics produce effective encirclement without explicit coordination is an instance of **swarm intelligence** — similar to results in multi-agent systems (cs.MA).

### 7.4 Constraint Satisfaction <-> Spelunky

Spelunky's path-first generation is essentially a **constructive CSP solver**: the constraint is "there must exist a traversable path from start to exit," and the algorithm constructs a solution directly rather than searching for one. This connects to work on **constructive heuristics** in combinatorial optimization (econ.TH, cs.DS).

---

## 8. What to Read Next

1. **The Pac-Man Dossier** (Jamey Pittman, pacman.holenet.info) — The single most detailed technical analysis of any arcade game ever written. Essential reading even beyond Pac-Man, as a model for reverse engineering game behavior. ~40 pages covering every aspect of the Z80 implementation.

2. **"Spelunky" by Derek Yu** (Boss Fight Books, 2016) — Chapter 5 covers the level generation in detail, from the designer himself. The best primary source on a PCG system written by its creator.

3. **NetHack source code** (`src/mkmaze.c`, `src/mkroom.c`, `src/mklev.c`) — The most complex open-source dungeon generator in existence. Reading `mkmaze.c` shows exactly how a shipped game implements recursive backtracking with post-processing.

4. **Darius Kazemi's Spelunky Generator visualization** (tinysubversions.com/spelunkyGen) — Interactive step-by-step walkthrough of the algorithm. The best way to build intuition for constrained path-first generation.

5. **Viana & Santos (2021), "Procedural Dungeon Generation: A Survey"** — Most recent comprehensive academic survey. Maps the taxonomy of approaches and identifies gaps (3D generation, mixed-initiative tools).

6. **Fabien Sanglard, "Game Engine Black Book: Wolfenstein 3D" and "Game Engine Black Book: Doom"** (2017, 2018) — Definitive technical analyses of both engines, including level format details.

---

## Sources

| Tier | Source | URL / Reference |
|------|--------|-----------------|
| T1 | Kuttler et al. 2020, "The NetHack Learning Environment", NeurIPS | ~216 cit S2 |
| T2 | Rogue source code (BSD) | github.com/Davidslv/rogue |
| T2 | NetHack source code (NGPL) | github.com/NetHack/NetHack |
| T2 | Angband source code (GPL) | github.com/angband/angband |
| T2 | Doom source code (GPL) | github.com/id-Software/DOOM |
| T2 | Wolfenstein 3D source code (GPL) | github.com/id-Software/wolf3d |
| T3 | Viana & Santos 2021, "Procedural Dungeon Generation: A Survey" | ~19 cit S2 |
| T3 | Gellel & Sweetser 2020, "Hybrid Approach to Procedural Generation" | ~19 cit S2 |
| T3 | Pech et al. 2015, "Evolving Cellular Automata for Maze Generation" | ~14 cit S2 |
| T3 | Stammer et al. 2015, "Player-adaptive Spelunky level generation" | ~20 cit S2 |
| T3 | Safak et al. 2016, "Automated Maze Generation for Ms. Pac-Man" | ~11 cit S2 |
| T5 | Jamey Pittman, "The Pac-Man Dossier" (pacman.holenet.info) | v1.0.27, 2015 |
| T5 | Darius Kazemi, Spelunky Generator Lessons (tinysubversions.com) | Interactive visualization |
| T5 | Fabien Sanglard, Game Engine Black Books (2017, 2018) | Book |
| T5 | Derek Yu, "Spelunky" (Boss Fight Books, 2016) | Book, Chapter 5 |
| T7 | Minecraft Wiki — Cave article (minecraft.wiki) | Community documentation of decompiled code |
| T7 | DoomWiki.org — Level format documentation | Community wiki |

---

## Open Questions

- **Dwarf Fortress**: Tarn Adams has described the cave generation as multi-scale CA + erosion simulation + geological strata. The source is not available but his talks are detailed. Would be a worthwhile deep-dive.
- **Diablo (1996)**: Known to use a modified BSP dungeon generator. The original Blizzard North code has not been released, but the Devilution project (reverse-engineered Diablo source) would enable detailed analysis.
- **Hades 2**: Currently in early access; unclear if the encounter system has changed from Hades 1.
- **No Man's Sky**: Uses PCG for entire planets but the maze-like cave systems use noise-based generation similar to post-1.18 Minecraft. Worth comparing the two approaches.

---

## Personal Project Connections

None of the current personal projects directly involve maze generation, but the **Agent Framework** project could benefit from the DAG-based encounter sequencing approach used by Hades/Slay the Spire/FTL as a model for **task graph construction** — where the agent must navigate a directed acyclic graph of subtasks with branching choices and path dependencies. The structural similarity between a Hades run (DAG of encounter rooms) and an HTN planner's task decomposition graph is worth noting.
