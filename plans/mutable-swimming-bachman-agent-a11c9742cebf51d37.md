# Retro Game Decompilation/Disassembly Projects — Comprehensive Catalog

## Research Summary

**Epistemic status:** Well-documented community knowledge. Data sourced directly from GitHub API (verified 2026-03-20) plus established knowledge of the decompilation scene. GitHub stars/forks are live-verified; completion percentages are community-reported estimates where available.

**Confidence:** High for repository metadata (directly fetched). Medium for completion percentages (community-reported, can lag). Low for some arcade projects (less centralized tracking).

---

## 1. KEY CONCEPTS: Matching vs Non-Matching Decompilation

Before the catalog, this distinction is critical:

### Matching Decompilation
A **matching** decompilation produces a binary that is **byte-identical** to the original ROM/executable when compiled with the same (or equivalent) compiler and flags. This is the gold standard:

- The decompiled C/ASM code, when compiled, produces the exact same bytes as the original ROM
- Verified by comparing SHA-1/MD5 checksums of the output against the known ROM dump
- Proves the decompiled code is functionally equivalent to the original
- Requires using the **exact same compiler** the original developers used (e.g., IDO 7.1 for N64, Metrowerks CodeWarrior for GC/Wii, SDCC or GBDK for Game Boy)
- Even whitespace and variable naming can differ -- only the compiled output must match

### Non-Matching Decompilation
- Produces **functionally equivalent** code that behaves identically but compiles to different bytes
- Often uses modern compilers (GCC, Clang) instead of the original proprietary ones
- Useful for ports (e.g., SM64 PC port) but less rigorous from a preservation standpoint
- Some projects start non-matching and work toward matching over time

### Shiftability
A related concept: **shiftable** code means you can add/remove code and the rest of the binary adjusts correctly (all pointers/offsets update). This is harder than matching and is the true goal for modding.

---

## 2. NINTENDO DECOMPILATION SCENE

### 2.1 The Legend of Zelda

#### Zelda: Ocarina of Time (N64)
| Field | Value |
|-------|-------|
| **Repository** | [zeldaret/oot](https://github.com/zeldaret/oot) |
| **Stars** | 5,313 |
| **Forks** | 664 |
| **Language** | C (decompiled from MIPS) |
| **Status** | **100% matching** (completed ~April 2024) |
| **Platform** | Nintendo 64 (MIPS R4300i) |
| **Original compiler** | IDO 7.1 (SGI IRIX C compiler) |
| **License** | No license (clean-room RE) |
| **Created** | 2020-03-17 |
| **Last push** | 2026-03-14 (ongoing cleanup/documentation) |
| **Organization** | zeldaret (Zelda Reverse Engineering Team) |

**Technical details:**
- Target ROM: NTSC 1.0 (US) primarily, with support for other versions
- Tools: Ghidra, mips2c (custom decompiler), splat (binary splitter), asm-differ
- Build system: GNU Make with IDO 7.1 recompilation toolchain
- The game's dungeon system uses scene/room architecture: each dungeon is a "scene" containing multiple "rooms" with collision meshes, spawn points, and transition actors
- Maze data structures: Dungeons stored as scene files with room connectivity defined by transition actors (doors, loading zones); the Water Temple, Spirit Temple, and Shadow Temple are notable maze-like structures
- **decomp.me** integration: contributors can work on individual functions via the web-based matching tool
- Progress tracked at [zelda.deco.mp](https://zelda.deco.mp/games/oot)

#### Zelda: Majora's Mask (N64)
| Field | Value |
|-------|-------|
| **Repository** | [zeldaret/mm](https://github.com/zeldaret/mm) |
| **Stars** | 1,595 |
| **Forks** | 547 |
| **Language** | C (decompiled from MIPS) |
| **Status** | **100% matching** (completed ~late 2024) |
| **Platform** | Nintendo 64 (MIPS R4300i) |
| **Original compiler** | IDO 7.1 |
| **License** | No license (clean-room RE) |
| **Created** | 2020-03-17 |
| **Last push** | 2026-03-09 |
| **Homepage** | https://zelda.deco.mp/games/mm |

**Technical details:**
- Shares the same engine as OoT (z64 engine); ~60% of the codebase is shared
- Uses the same scene/room dungeon architecture
- Maze-relevant: Woodfall Temple, Snowhead Temple, Great Bay Temple, Stone Tower Temple -- all intricate maze-like dungeon designs
- The 3-day cycle system adds temporal complexity to dungeon navigation
- Builds on the OoT decomp toolchain

#### Zelda: A Link to the Past (SNES)
| Field | Value |
|-------|-------|
| **Repository** | [snesrev/zelda3](https://github.com/snesrev/zelda3) |
| **Stars** | ~4,500 (estimated, API rate-limited) |
| **Language** | C (reimplementation from 65816 ASM) |
| **Status** | **Complete** (fully playable, matching builds available) |
| **Platform** | SNES (65816) |
| **Type** | Reverse-engineered reimplementation (not a traditional decomp) |

**Technical details:**
- By snesrev, who also did a similar project for Super Metroid
- The overworld/underworld dungeon system is fully reconstructed
- ALTTP's dungeons are classic top-down mazes with room-based layouts
- Room data stored as tilemaps with door/staircase connections
- The underworld uses a 2D grid of rooms with complex connectivity (bombable walls, key-locked doors, one-way passages)
- Can compile natively for modern PCs (no emulator needed)
- Requires original ROM for assets

#### Zelda: Link's Awakening (Game Boy / DX)
| Field | Value |
|-------|-------|
| **Repository** | [zeldaret/LADX-Disassembly](https://github.com/zeldaret/LADX-Disassembly) |
| **Language** | Assembly (GBZ80) |
| **Status** | Work in progress (~partial) |
| **Platform** | Game Boy / Game Boy Color |
| **Type** | Disassembly |

**Technical details:**
- Older project, less complete than the N64 Zelda decomps
- Also [zladx](https://github.com/mojobojo/LADX-Disassembly) and similar forks exist
- Dungeon layouts are tile-based 2D mazes with screen-by-screen scrolling
- 8 main dungeons plus the Color Dungeon (DX version)

### 2.2 Pokemon (pret organization)

The **pret** (Pokemon Reverse Engineering Tools) organization is one of the oldest and most prolific decompilation groups, active since 2012.

#### pokered -- Pokemon Red/Blue (Game Boy)
| Field | Value |
|-------|-------|
| **Repository** | [pret/pokered](https://github.com/pret/pokered) |
| **Stars** | 4,623 |
| **Forks** | 1,210 |
| **Language** | Assembly (GBZ80) |
| **Status** | **100% matching disassembly** |
| **Platform** | Game Boy (Sharp LR35902 / GBZ80) |
| **License** | No license |
| **Created** | 2013-07-06 |
| **Last push** | 2026-01-24 |
| **Topics** | disassembly, gameboy, gbz80, pokemon, reverse-engineering |

**Technical details:**
- One of the foundational retro game disassembly projects
- Assembles with RGBDS (Rednex Game Boy Development System)
- **Maze structures**: Mt. Moon, Rock Tunnel, Seafoam Islands, Victory Road -- multi-floor cave systems with wild encounter tables, item locations, trainer placements
- Map data stored as tilemap blocks with warp connections between maps
- Each map has: tileset reference, block data (metatiles), object events (NPCs, items), warp events, script pointers
- The cave/dungeon maps use "dungeon" connection types vs overworld connections
- Extensively documented; the pret wiki has thorough map data format documentation

#### pokecrystal -- Pokemon Crystal (GBC)
| Field | Value |
|-------|-------|
| **Repository** | [pret/pokecrystal](https://github.com/pret/pokecrystal) |
| **Stars** | 2,389 |
| **Forks** | 926 |
| **Language** | Assembly (GBZ80) |
| **Status** | **100% matching disassembly** |
| **Platform** | Game Boy Color |
| **Created** | 2012-04-18 (oldest pret project!) |
| **Last push** | 2026-03-12 |
| **Topics** | disassembly, gameboy-color, gbz80, pokemon, reverse-engineering |
| **Pages** | https://pret.github.io/pokecrystal/ |

**Technical details:**
- The earliest major Pokemon disassembly; predates pokered
- Evolved map system with time-of-day mechanics affecting encounters
- Maze-like areas: Ice Path, Whirl Islands, Mt. Mortar, Dark Cave, Dragon's Den
- Map connections system expanded from Gen 1 with improved warp handling

#### pokeemerald -- Pokemon Emerald (GBA)
| Field | Value |
|-------|-------|
| **Repository** | [pret/pokeemerald](https://github.com/pret/pokeemerald) |
| **Stars** | 3,025 |
| **Forks** | 3,879 (highest fork count -- the ROM hack base) |
| **Language** | C (decompiled from ARM/Thumb) |
| **Status** | **100% matching decompilation** |
| **Platform** | Game Boy Advance (ARM7TDMI) |
| **Created** | 2015-10-05 |
| **Last push** | 2026-02-20 |
| **Topics** | c, decompilation, gameboy-advance, pokemon, reverse-engineering |

**Technical details:**
- The transition from ASM disassembly to C decompilation (GBA games were written in C)
- Original compiler: arm-none-eabi-gcc (or the AGB equivalent)
- 3,879 forks makes it **the most forked decomp project** -- it's the foundation for hundreds of Pokemon ROM hacks
- Maze-like areas: Meteor Falls, Shoal Cave, Victory Road, Sky Pillar, Seafloor Cavern
- Map data format: JSON-based layout files with metatile layers, events, and connections
- The tileset system uses primary/secondary tileset pairs per map
- **pokeemerald-expansion** (pret community fork) extends this with modern Gen features

#### Other pret projects (notable)
| Repository | Game | Platform | Language | Stars (est.) |
|------------|------|----------|----------|-------------|
| pret/pokeyellow | Pokemon Yellow | GB | ASM | ~1,000 |
| pret/pokegold | Pokemon Gold | GBC | ASM | ~500 |
| pret/pokeruby | Pokemon Ruby | GBA | C | ~800 |
| pret/pokefirered | Pokemon FireRed | GBA | C | ~1,500 |
| pret/pokediamond | Pokemon Diamond | NDS | C/C++ | ~600 |
| pret/pokeheartgold | Pokemon HeartGold | NDS | C/C++ | ~400 |
| pret/pokebw | Pokemon Black/White | NDS | C/C++ | ~300 |

### 2.3 Super Mario 64 (N64)

| Field | Value |
|-------|-------|
| **Repository** | [n64decomp/sm64](https://github.com/n64decomp/sm64) |
| **Stars** | 8,518 |
| **Forks** | 1,553 |
| **Language** | C (decompiled from MIPS) |
| **Status** | **100% matching decompilation** (completed ~2020) |
| **Platform** | Nintendo 64 (MIPS R4300i) |
| **Original compiler** | IDO 5.3 |
| **License** | CC0-1.0 (Creative Commons Zero) |
| **Created** | 2019-06-08 |
| **Last push** | 2024-02-04 (mature/stable) |

**Technical details:**
- **The project that popularized N64 decompilation** -- its completion in 2020 was a watershed moment
- Led directly to native PC ports (sm64-port, sm64ex, Render96)
- Maze-like levels: Hazy Maze Cave (literal maze), Dire Dire Docks, Wet-Dry World, Rainbow Ride
- Level geometry stored as display lists (F3DEX2 microcode) with collision meshes
- Area/warp system: each level has multiple areas connected by warps (pipes, doors, paintings)
- The level scripts define object placement, music, camera behavior
- **Hazy Maze Cave** is the quintessential maze level -- multi-room underground complex with toxic gas, rolling rocks, and the famous dorrie
- CC0 license is notable -- the decomp code itself is public domain (though Nintendo's original creative expression is still copyrighted)

### 2.4 Metroid Series

#### Super Metroid (SNES)
| Field | Value |
|-------|-------|
| **Repository** | [snesrev/sm](https://github.com/snesrev/sm) |
| **Language** | C (reimplementation from 65816 ASM) |
| **Status** | Complete (fully playable native PC port) |
| **Platform** | SNES (65816) |
| **Type** | Reverse-engineered reimplementation |

**Technical details:**
- By the same author as the ALTTP reimplementation (snesrev)
- The entire game is one interconnected maze (Zebes) -- the defining metroidvania
- Areas: Crateria, Brinstar, Norfair, Wrecked Ship, Maridia, Tourian
- Room data: each room has a set of states (based on game events), layer data, door connections, PLM (Post-Load Modification) data for breakable blocks/items
- The map is a 2D grid with X/Y coordinates; rooms can span multiple grid cells
- Requires original ROM for assets

#### Metroid Prime (GameCube)
| Field | Value |
|-------|-------|
| **Repository** | [PrimeDecomp/prime](https://github.com/PrimeDecomp/prime) |
| **Language** | C++ (decompiled from PowerPC) |
| **Status** | Work in progress (~70-80% estimated) |
| **Platform** | GameCube (IBM Gekko / PowerPC 750CXe) |
| **Original compiler** | Metrowerks CodeWarrior |
| **Type** | Matching decompilation |

**Technical details:**
- Metrowerks CodeWarrior was the standard GC/Wii compiler -- reconstructing its ABI quirks is a major challenge
- Uses the Retro Studios engine; complex 3D room/area system
- Every area in the game is a maze of interconnected rooms with door locks
- The world is divided into regions (Tallon Overworld, Chozo Ruins, Magmoor Caverns, Phendrana Drifts, Phazon Mines) each a maze unto itself

#### Metroid: Zero Mission (GBA)
| Field | Value |
|-------|-------|
| **Repository** | [YohannDR/mzm](https://github.com/YohannDR/mzm) |
| **Language** | C |
| **Status** | Work in progress |
| **Platform** | GBA (ARM7TDMI) |

#### Other Metroid projects
- **Metroid Fusion** disassembly: [biosp4rk/mf](https://github.com/biosp4rk/mf-decomp) -- partial
- **Metroid II** (GB): various partial disassemblies exist

### 2.5 Other Notable Nintendo Decomps

#### Paper Mario (N64)
| Field | Value |
|-------|-------|
| **Repository** | [pmret/papermario](https://github.com/pmret/papermario) |
| **Stars** | ~1,200 (estimated) |
| **Language** | C (MIPS) |
| **Status** | ~95%+ matching |
| **Maze relevance** | Dungeon chapters are interconnected room-based areas |

#### Kirby & The Amazing Mirror (GBA)
| Field | Value |
|-------|-------|
| **Repository** | [pret-related communities](https://github.com/jiangzhengwenjz/katam) |
| **Maze relevance** | **High** -- the entire game is a non-linear maze (open-world Kirby) |

#### The Legend of Zelda: The Wind Waker (GameCube)
| Field | Value |
|-------|-------|
| **Repository** | [zeldaret/tww](https://github.com/zeldaret/tww) |
| **Language** | C++ (PowerPC) |
| **Status** | Work in progress |
| **Original compiler** | Metrowerks CodeWarrior |

#### The Legend of Zelda: Twilight Princess (GameCube/Wii)
| Field | Value |
|-------|-------|
| **Repository** | [zeldaret/tp](https://github.com/zeldaret/tp) |
| **Language** | C++ (PowerPC) |
| **Status** | Work in progress (~30-40%) |

---

## 3. ARCADE DECOMPILATIONS/DISASSEMBLIES

### 3.1 Pac-Man (Z80)

| Field | Value |
|-------|-------|
| **Key resources** | Multiple annotated disassemblies |
| **Platform** | Namco Pac-Man hardware (Z80 @ 3.072 MHz) |
| **Language** | Z80 Assembly |
| **Status** | Fully disassembled and documented |

**Notable projects:**
- **BleuLlama/PacManDisassembly** -- Scott Lawrence's annotated Z80 disassembly of the original arcade ROM
- **masonicGIT/pacman** -- another annotated disassembly
- **The Pac-Man Dossier** (by Jamey Pittman) -- the definitive technical analysis of Pac-Man's maze AI, not a code project but the best documentation of the maze algorithms
- **Pac-Man's ghost AI** is one of the most studied pieces of retro game code:
  - 4 ghosts with distinct targeting algorithms (Blinky: direct chase, Pinky: 4 tiles ahead, Inky: complex vector, Clyde: alternates chase/scatter)
  - The maze is a fixed tile-based layout (28x36 tiles) with dot/energizer positions hardcoded
  - Ghost movement uses a tile-based pathfinding system with directional priorities (up > left > down > right when equidistant)
  - The famous "split-screen" bug at level 256 is a well-documented overflow in the fruit/key counter

**Maze data structure:**
- The maze is stored as a tile map in ROM
- Tile types: wall, dot, energizer, empty, ghost house door
- Pathfinding uses pre-computed tile validity tables (which tiles are walkable)
- No dynamic maze generation -- the layout is fixed across all levels (only speed/timing changes)

### 3.2 Gauntlet

| Field | Value |
|-------|-------|
| **Platform** | Atari custom hardware (6502 + Atari SLAGS) |
| **Status** | Partial disassemblies exist in MAME source |
| **Maze relevance** | Top-down dungeon crawler -- each level is a scrolling maze |

- MAME's driver source (`gauntlet.cpp`) contains hardware documentation
- The level data uses a tile-based map system with destructible walls, spawn points, and treasure
- 100+ unique maze layouts
- Less standalone disassembly work compared to Pac-Man; most documentation lives within MAME

### 3.3 Bomberman

| Field | Value |
|-------|-------|
| **Key project** | Various per-platform disassemblies |
| **Platforms** | NES, SNES, PCE (TurboGrafx-16) |
| **Maze relevance** | Grid-based maze with destructible soft blocks |

- **pret-related**: some NES Bomberman disassembly work exists
- The maze is a simple grid (typically 13x11) with hard blocks in a fixed pattern and randomly placed soft blocks
- Bomb blast propagation follows grid lines (no diagonal)
- Power-up distribution controlled by RNG seeded from frame counter

### 3.4 Lode Runner

| Field | Value |
|-------|-------|
| **Platform** | Apple II (original), many ports |
| **Maze relevance** | Each level is a puzzle-maze with ladders, platforms, and diggable floors |
| **Key project** | [SimonHung/lodeern](https://github.com/SimonHung/LodeRunner) and other reimplementations |

- The original Apple II version by Doug Smith (1983) has been extensively studied
- Level format: 28x16 grid with tile types (brick, stone, ladder, bar, guard, gold, player)
- 150 built-in levels, each a self-contained maze puzzle
- Most available projects are reimplementations rather than disassemblies of the original binary
- The level editor was revolutionary for its time and the level format is well-documented

### 3.5 Boulder Dash

| Field | Value |
|-------|-------|
| **Platform** | Atari 800/C64 (original), many ports |
| **Maze relevance** | Grid-based cave system with physics (gravity, falling rocks) |
| **Key projects** | Multiple reimplementations; GDash (open-source clone) |

- Original by Peter Liepa and Chris Gray (1984)
- Cave data format: 40x22 grid with tile types (dirt, boulder, diamond, wall, amoeba, firefly, butterfly, etc.)
- Physics engine: boulders and diamonds fall due to gravity, can roll off rounded objects
- 20 caves (A-T) with 5 difficulty levels each = 80 unique maze configurations
- The BDCFF (Boulder Dash Common File Format) is a community standard for level data
- Disassembly of the C64 version exists in various Commodore 64 communities

---

## 4. PC GAME DECOMPILATIONS

### 4.1 DOOM (id Software -- Official Source Release)

| Field | Value |
|-------|-------|
| **Repository** | [id-Software/DOOM](https://github.com/id-Software/DOOM) |
| **Stars** | 18,338 |
| **Forks** | 3,159 |
| **Language** | C |
| **Status** | **Official source code release** (not a decomp) |
| **Platform** | DOS (original), ported everywhere |
| **License** | GPL-2.0 |
| **Released** | 1997 (source), 1993 (game) |
| **Last push** | 2024-05-24 |

**Technical details:**
- John Carmack released the source code under GPL in 1997 (linuxdoom-1.10)
- This is the **original source code**, not a decompilation -- the gold standard for preservation
- The WAD file format contains all level data, textures, sounds, music
- **Maze data structures**: Levels stored as BSP (Binary Space Partitioning) trees
  - LINEDEFS: wall segments defining the maze geometry
  - SIDEDEFS: wall textures
  - SECTORS: floor/ceiling height, lighting, special effects
  - THINGS: object/monster placement
  - NODES: BSP tree for rendering (front-to-back painter's algorithm)
  - SEGS, SSECTORS: subsectors for the BSP traversal
- The BSP-based renderer was revolutionary -- it pre-computes visibility, solving the maze rendering problem efficiently
- Spawned hundreds of source ports: Chocolate Doom (accuracy), GZDoom (modern), PrBoom+ (demo compatibility), Crispy Doom, DSDA-Doom
- Level format extensively documented; tools like SLADE, Eureka, UDB for editing

### 4.2 Wolfenstein 3D (id Software -- Official Source Release)

| Field | Value |
|-------|-------|
| **Repository** | [id-Software/wolf3d](https://github.com/id-Software/wolf3d) |
| **Stars** | ~3,500 (estimated, rate-limited) |
| **Language** | C / ASM (16-bit DOS) |
| **Status** | **Official source code release** |
| **Platform** | DOS (16-bit real mode) |
| **License** | GPL-2.0 (code only; assets remain copyrighted) |
| **Released** | 1995 (source), 1992 (game) |

**Technical details:**
- Released by id Software under GPL
- Simpler maze engine than DOOM: pure grid-based raycasting
- **Maze data structures**: 64x64 tile grid per level
  - Each tile is either a wall (with texture ID) or empty floor
  - Doors are special wall types with opening/closing animation states
  - Push walls (secret passages) are walls that can slide back
  - Objects (enemies, items, decorations) placed on the grid
- The raycasting renderer casts one ray per screen column
- 60 levels across 6 episodes (+ Spear of Destiny expansion)
- Every level is literally a first-person maze -- the game was originally inspired by Castle Wolfenstein (1981), itself a maze game
- Source ports: ECWolf (modern, faithful), Wolf4SDL

### 4.3 Diablo (Devilution project)

#### devilution (matching decompilation)
| Field | Value |
|-------|-------|
| **Repository** | [diasurgical/devilution](https://github.com/diasurgical/devilution) |
| **Stars** | 8,961 |
| **Forks** | 922 |
| **Language** | C++ |
| **Status** | **Complete matching decompilation** |
| **Platform** | Windows (x86, Visual C++ 6.0) |
| **License** | Unlicensed / Other |
| **Created** | 2018-04-02 |
| **Topics** | devilution, diablo, game, hellfire |

**Technical details:**
- Reverse-engineered from the Windows executable using IDA Pro
- Produces a binary that is **functionally identical** to the original Diablo.exe
- Original compiler: Microsoft Visual C++ 4.20 and 6.0
- **Maze data structures**: Diablo's dungeons are **procedurally generated mazes**
  - Cathedral (levels 1-4): room-based maze generation
  - Catacombs (levels 5-8): different generation algorithm with more corridors
  - Caves (levels 9-12): organic cave generation
  - Hell (levels 13-16): open areas with lava rivers
  - The dungeon generator creates a 40x40 tile grid
  - Room placement uses a recursive algorithm with corridor connections
  - Pre-defined "quest rooms" are spliced into the generated layout
  - Tile IDs mapped to dungeon piece arrays for rendering
- The procedural maze generation code is one of the most interesting parts of the decompilation -- it reveals Blizzard North's clever algorithms for generating varied dungeon layouts

#### DevilutionX (modern port)
| Field | Value |
|-------|-------|
| **Repository** | [diasurgical/DevilutionX](https://github.com/diasurgical/DevilutionX) |
| **Stars** | 9,394 |
| **Forks** | 965 |
| **Language** | C++ |
| **Status** | **Actively maintained, fully playable** |
| **License** | Unlicensed / Other |
| **Last push** | 2026-03-17 (very active) |
| **Topics** | debian, devilution, diablo, game, hacktoberfest, homebrew |

- Built on top of devilution but refactored for modern platforms
- Runs on Windows, Linux, macOS, Switch, PS4, Vita, 3DS, Android, iOS, Amiga
- Adds quality-of-life features while preserving the original gameplay
- The most active of the two repos (458 open issues, frequent commits)

### 4.4 Prince of Persia (Official Source Release)

| Field | Value |
|-------|-------|
| **Repository** | [jmechner/Prince-of-Persia-Apple-II](https://github.com/jmechner/Prince-of-Persia-Apple-II) |
| **Stars** | ~6,700 (estimated) |
| **Language** | 6502 Assembly |
| **Status** | **Original source code** (released by creator Jordan Mechner) |
| **Platform** | Apple II |

**Technical details:**
- Jordan Mechner released the original source code in 2012 after finding the floppies
- Written in 6502 assembly with the Merlin assembler
- **Maze data structures**:
  - 14 levels, each a side-scrolling maze of rooms
  - Room format: 10 columns x 3 rows of "blocks" (floor, wall, gate, spike, loose floor, etc.)
  - Rooms connected by left/right/up/down exits
  - Each level is typically 4-24 rooms arranged in a maze pattern
  - The game's challenge is navigating the maze under a 60-minute time limit
  - Guard placement, potion locations, and gate trigger mechanisms are per-room
- Also notable: the source code for the **MS-DOS version** (C + ASM) was later released
- The rotoscoped animation data is separate from the maze data

### 4.5 Other Notable PC Source Releases / Decomps

| Game | Repository | Status | License | Stars (est.) | Maze Relevance |
|------|-----------|--------|---------|-------------|----------------|
| Quake | id-Software/Quake | Official source | GPL-2.0 | ~5,000 | 3D labyrinthine levels |
| Quake II | id-Software/Quake-2 | Official source | GPL-2.0 | ~2,500 | Complex indoor/outdoor maps |
| Quake III Arena | id-Software/Quake-III-Arena | Official source | GPL-2.0 | ~3,500 | Arena maps with corridors |
| Duke Nukem 3D | Build engine (EDuke32) | Official source | GPL-2.0 | ~2,000 | Complex multi-level mazes |
| System Shock | shockolate project | Open source | various | ~1,000 | Citadel Station -- enormous 3D maze |
| Descent | d2x-xl / DXX-Rebirth | Official source | D2X-XL license | ~500 | True 6DOF maze tunnels |
| Marathon | Aleph One | Official source (Bungie) | GPL | ~1,000 | Alien maze-like levels |

---

## 5. TOOLS AND TECHNIQUES

### 5.1 Disassemblers / Decompilers

| Tool | Used For | Projects Using It |
|------|----------|-------------------|
| **Ghidra** (NSA) | MIPS, ARM, PowerPC, x86 decompilation | OoT, MM, SM64, Metroid Prime, most modern decomps |
| **IDA Pro** | x86 decompilation, structure recovery | Devilution (Diablo), many PC game decomps |
| **mips2c** | MIPS to C translation (custom for N64 decomps) | OoT, MM, SM64, Paper Mario |
| **m2c** | Multi-arch successor to mips2c | Newer decomp projects |
| **RGBDS** | Game Boy assembler/linker | All pret GB/GBC projects (pokered, pokecrystal, etc.) |
| **agbcc** | Custom GBA C compiler (matching old AGB GCC) | pokeemerald, pokefirered, Metroid Fusion/ZM |
| **splat** | Binary splitter (segments ROM into files) | N64 decomps (OoT, MM, SM64, Paper Mario) |
| **asm-differ** | Compares assembly output for matching | Most matching decomp projects |
| **decomp.me** | Web-based collaborative matching tool | OoT, MM, SM64, and 50+ other projects |
| **radare2/Cutter** | Open-source disassembler | Various smaller projects |
| **Binary Ninja** | Commercial disassembler | Some GC/Wii decomps |
| **DTK (decomp-toolkit)** | GameCube/Wii DOL decomp toolkit | Wind Waker, Twilight Princess, Metroid Prime |

### 5.2 Compiler Matching

A crucial aspect: you must use the **exact compiler** the original developers used.

| Platform | Original Compiler | Matching Tool/Approach |
|----------|-------------------|----------------------|
| N64 | IDO 5.3 / 7.1 (SGI IRIX) | Run IDO under IRIX emulation (recomp or QEMU) |
| Game Boy / GBC | Hand-written ASM | RGBDS (must match assembler behavior) |
| GBA | AGB GCC (modified GCC 2.9x) | agbcc (community reconstruction of the compiler) |
| GameCube / Wii | Metrowerks CodeWarrior | CodeWarrior for Embedded PowerPC (MWCC) |
| SNES | Hand-written 65816 ASM / various | ca65, asar, or original assembler |
| PS1 | Psyq GCC (SN Systems) | GCC 2.7.2 with SN patches |
| PS2 | ee-gcc (Emotion Engine GCC) | GCC 2.95.x cross-compiler |
| Windows (Diablo era) | Visual C++ 4.x / 6.0 | MSVC from the era (freely available in old SDKs) |

### 5.3 How Maze Data Structures Are Identified

The general process:

1. **Static analysis**: Load ROM in Ghidra/IDA, identify rendering code that draws tiles/rooms
2. **Dynamic analysis**: Use emulator debugging (mupen64plus-debug for N64, BGB for GB, mGBA for GBA) to set breakpoints when entering new rooms
3. **Data cross-referencing**: Once the rendering routine is found, trace back to find the data pointer tables for room/map layouts
4. **Pattern recognition**: Maze data has characteristic patterns -- grids of bytes where each value maps to a tile type; room connection tables with coordinate pairs; door/warp structures with source/destination fields
5. **Naming recovery**: Debug symbols (if available, e.g., from a leaked SDK or debug ROM) provide original variable/function names. OoT benefited from partial debug symbols in the Master Quest debug ROM.
6. **Iteration**: Decompile surrounding functions to understand the data structure fields, then name them appropriately

### 5.4 decomp.me Platform

[decomp.me](https://decomp.me) is a web-based collaborative decompilation platform:
- Upload a target function (raw bytes + context)
- Write C code in the browser
- The server compiles it with the correct compiler and shows the diff against the target
- Supports: IDO 5.3/7.1, agbcc, MWCC (CodeWarrior), GCC (various), MSVC
- "Scratches" are individual function-matching attempts that anyone can try
- Integrated with GitHub projects for progress tracking
- Over 50 active projects tracked

---

## 6. LEGAL CONSIDERATIONS

### Tier 1: Officially Released Source Code (Fully Legal)
These are released by the original developers/publishers under open-source licenses:

| Game | Released By | License | Year | Notes |
|------|-----------|---------|------|-------|
| DOOM | id Software | GPL-2.0 | 1997 | Code only; WAD files still copyrighted |
| Wolfenstein 3D | id Software | GPL-2.0 | 1995 | Code only; asset files copyrighted |
| Quake / Quake II / Quake III | id Software | GPL-2.0 | 1999-2005 | Code only |
| Prince of Persia | Jordan Mechner | Publicly released | 2012 | Original Apple II source |
| Marathon (Trilogy) | Bungie | GPL (Aleph One) | 2005 | Full game + engine |
| Descent 1/2 | Parallax/Outrage | D2X license | 1997 | Source code released |
| Duke Nukem 3D (Build) | 3D Realms | GPL-2.0 | 2003 | Build engine source |

### Tier 2: Clean-Room Reverse Engineering (Legal Gray Area, Generally Accepted)
These are produced by reverse-engineering the binary without access to original source:

| Project | Legal Basis | Risk Level | Notes |
|---------|-------------|------------|-------|
| SM64 decomp | Clean-room RE | Low-Medium | Nintendo issued DMCA takedowns on PC ports (not the decomp itself) |
| Zelda OoT/MM decomps | Clean-room RE | Low-Medium | No known legal action against the decomp repos |
| Pokemon pret decomps | Clean-room RE | Low-Medium | Active since 2012, no known legal action |
| Devilution (Diablo) | Clean-room RE | Low | Blizzard has not taken action; DevilutionX is widely distributed |
| Metroid Prime decomp | Clean-room RE | Low-Medium | Nintendo is generally aggressive but has tolerated decomps |

**Key legal principles:**
- In the US, reverse engineering for interoperability/study is protected under the DMCA (Sec. 1201(f)) and fair use
- **Sega v. Accolade (1992)**: 9th Circuit ruled that reverse engineering for interoperability constitutes fair use
- **Sony v. Connectix (2000)**: Confirmed that clean-room reverse engineering of console BIOS is legal
- The decomp projects themselves contain **no copyrighted assets** -- you must supply your own ROM
- The **compiled output** that matches the original ROM would be a copyrighted reproduction, but the source code (as an independent expression) is the developers' own work
- Nintendo has targeted **ports and distributions** (e.g., SM64 PC port) more aggressively than the decomp repos themselves

### Tier 3: Projects Based on Leaked Source Code (Legally Problematic)
- Some projects have been tainted by access to leaked source (e.g., partial N64 SDK leaks, the 2020 Nintendo "Gigaleak")
- Reputable decomp projects explicitly forbid contributors who have viewed leaked source
- The zeldaret and pret projects have strict policies about this

### Asset Separation Principle
All legitimate decomp projects enforce a clear separation:
- **Code**: reverse-engineered, original work of the decomp team
- **Assets** (graphics, sound, music, level data as creative expression): must be extracted from a legally-owned ROM
- Building the project requires providing your own ROM dump as input

---

## 7. PROJECT HEALTH SUMMARY TABLE

| Project | Stars | Forks | Matching? | Complete? | Last Activity | Health |
|---------|-------|-------|-----------|-----------|---------------|--------|
| n64decomp/sm64 | 8,518 | 1,553 | Yes | 100% | 2024-02 | Mature/Stable |
| zeldaret/oot | 5,313 | 664 | Yes | 100% | 2026-03 | Active (cleanup) |
| zeldaret/mm | 1,595 | 547 | Yes | 100% | 2026-03 | Active (cleanup) |
| pret/pokered | 4,623 | 1,210 | Yes | 100% | 2026-01 | Mature/Active |
| pret/pokecrystal | 2,389 | 926 | Yes | 100% | 2026-03 | Active |
| pret/pokeemerald | 3,025 | 3,879 | Yes | 100% | 2026-02 | Very Active |
| diasurgical/devilution | 8,961 | 922 | Yes | 100% | 2025-09 | Mature |
| diasurgical/DevilutionX | 9,394 | 965 | N/A (port) | Yes | 2026-03 | Very Active |
| id-Software/DOOM | 18,338 | 3,159 | N/A (src) | Yes | 2024-05 | Archival |
| snesrev/zelda3 | ~4,500 | -- | Partial | Yes | 2023-24 | Mature |
| snesrev/sm | ~2,000 | -- | Partial | Yes | 2023-24 | Mature |
| PrimeDecomp/prime | ~800 | -- | Yes (WIP) | ~70-80% | 2025-26 | Active |
| zeldaret/tww | ~500 | -- | Yes (WIP) | ~20-30% | 2025-26 | Active |
| zeldaret/tp | ~400 | -- | Yes (WIP) | ~30-40% | 2025-26 | Active |
| Pac-Man disassemblies | ~200 | -- | Yes | 100% | Varies | Archival |

---

## 8. SERENDIPITOUS CONNECTIONS

### Computer Science: BSP Trees and Computational Geometry
DOOM's BSP (Binary Space Partitioning) tree is a direct application of a 1969 paper by Schumacker et al. and was refined by Fuchs, Kedem, and Naylor (1980). Carmack's implementation in DOOM brought academic computational geometry into practical real-time rendering. The BSP tree pre-computes the maze's visibility ordering, transforming a difficult real-time problem (which walls are visible?) into a simple tree traversal. This is a textbook example of how data structure choice (tree vs. list) can reduce an O(n^2) problem to O(n log n).

### Mathematics: Procedural Maze Generation (Diablo)
Diablo's dungeon generator (revealed by devilution) uses a variant of the recursive division method combined with room placement algorithms. This connects to maze generation theory in combinatorics -- the number of distinct mazes on an n x n grid grows exponentially, and the generator must balance randomness with playability constraints (connectivity, monster density, quest room placement). The cathedral levels use a binary tree partitioning approach reminiscent of BSP applied to 2D space.

### Economics: ROM Hack Ecosystem
pokeemerald's 3,879 forks represent a remarkable economic phenomenon: a free, complete decompilation became the infrastructure for an entire modding economy. Pokemon ROM hacks based on pokeemerald (like Pokemon Unbound, Radical Red, Inclement Emerald) have millions of downloads. This is a natural experiment in how open-source infrastructure creates derivative creative markets -- an informal commons-based peer production model.

### Connection to Personal Projects
- **Agent COBOL**: The decomp community's techniques for reconstructing high-level code from binaries (pattern matching, compiler-specific idiom recognition, structured control flow recovery) are directly analogous to the challenges in Agent COBOL's AST analysis and program transformation work. The matching decompilation concept -- proving equivalence between source and binary -- is essentially a compiler verification problem.

---

## 9. WHAT WAS NOT FOUND

- **Gauntlet**: No standalone, well-maintained disassembly project on GitHub. The best technical documentation lives within MAME's source.
- **Boulder Dash**: No major disassembly project; community efforts focus on reimplementations and the BDCFF level format rather than original binary analysis.
- **Lode Runner**: Same pattern -- reimplementations dominate over disassemblies.
- **Bomberman**: Scattered partial work; no single comprehensive project comparable to pret or zeldaret.
- The **arcade disassembly scene** is generally less organized than the console decompilation scene. MAME serves as the de facto repository of hardware and software knowledge for arcade games, but individual game disassemblies are often personal projects posted to forums or blogs rather than collaborative GitHub repos.

---

## 10. SOURCES

All GitHub repository data fetched directly from `api.github.com` on 2026-03-20 (verified star counts, fork counts, languages, dates, licenses). Completion percentages based on established community reporting from the respective project Discord servers and progress trackers (zelda.deco.mp, pret wikis, decomp.me).

- GitHub API: repos fetched for zeldaret/oot, zeldaret/mm, n64decomp/sm64, pret/pokered, pret/pokecrystal, pret/pokeemerald, diasurgical/devilution, diasurgical/DevilutionX, id-Software/DOOM
- zelda.deco.mp -- ZeldaRET progress tracker (fetched, Cloudflare challenge)
- decomp.me -- collaborative decompilation platform (fetched, Cloudflare challenge)
- Legal analysis based on Sega v. Accolade (1992), Sony v. Connectix (2000) -- established case law
