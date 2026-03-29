# Research: Decompiled / Decompilable Maze Games

## Research Summary

**Epistemic status:** Well-documented field with extensive community activity
**Confidence:** High for the projects verified via GitHub API; Medium for older resources known from domain knowledge but not all individually fetched.

### Executive Summary

The decompilation/reverse-engineering of maze games spans four main categories: (1) annotated disassemblies of original arcade ROMs, (2) community-driven full decompilation projects producing compilable C source, (3) officially released source code, and (4) clean-room reimplementations. The classic Pac-Man arcade game has been thoroughly reverse-engineered at the disassembly level but does **not** appear on any major decompilation list as a full C decompilation project -- its Z80 architecture has been documented exhaustively in annotated assembly instead. The broader game decompilation community is enormous: the curated list at `CharlotteCross1998/awesome-game-decompilations` catalogs 400+ projects.

---

## 1. PAC-MAN AND VARIANTS

### 1.1 Pac-Man (Arcade, 1980) -- Z80

**Platform:** Namco arcade hardware (Z80 CPU @ 3.072 MHz, Namco WSG 3-voice sound)
**Decompilation status:** Fully disassembled and annotated, NOT decompiled to C
**Key resources:**

| Resource | URL | Description |
|----------|-----|-------------|
| **The Pac-Man Dossier** | `https://pacman.holenet.info/` | Jamey Pittman's exhaustive technical analysis (v1.0.27, 2015). Covers ghost AI, pathfinding, scatter/chase modes, timing. Based on disassembly analysis. (T5 -- community technical reference) |
| **Lomont Pac-Man Emulation Doc** | `https://www.lomont.org/software/games/pacman/PacmanEmulation.pdf` | Chris Lomont's 27-page technical document on emulating the Pac-Man hardware. Complete memory map, I/O ports, interrupt system. (T5 -- community reference) |
| **C64 Pac-Man Disassembly** | `https://github.com/sajattack/c64-pacman-disassembly` | Disassembly of the Commodore 64 port (7 stars, 2018). 6502 assembly. |
| **MAME driver** | `https://github.com/mamedev/mame` (src/mame/pacman/) | MAME (10,005 stars) contains the most authoritative hardware emulation of Pac-Man. The `pacman.cpp` driver is a de facto reference for the arcade hardware. |

**Technical insights:**
- Pac-Man's Z80 ROM is only 16KB (4x 4KB ROMs). This small size makes complete annotation tractable.
- Ghost AI uses a target-tile system with different targeting per ghost: Blinky chases Pac-Man directly, Pinky targets 4 tiles ahead, Inky uses Blinky's position as a pivot, Clyde switches between chase and scatter based on distance.
- The famous "kill screen" at level 256 is caused by a fruit-drawing routine that overflows the 8-bit level counter.
- The maze layout is hardcoded in ROM -- no procedural generation.

**Why no full C decompilation?** Pac-Man's Z80 assembly is already small (~4K instructions of actual game logic) and well-annotated. The retro community treats annotated disassembly as the canonical form for arcade games of this era. A C decompilation would add little value since the code maps almost 1:1 to assembly constructs.

### 1.2 Ms. Pac-Man (Arcade, 1982)

**Platform:** Same Namco/Midway hardware as Pac-Man (Z80)
**Decompilation status:** Partially documented through MAME
**Key insight:** Ms. Pac-Man was originally a hack ("Crazy Otto") by General Computer Corporation. It uses an auxiliary board that patches the original Pac-Man ROMs. The MAME driver documents this patching mechanism. The multiple maze layouts (4 mazes vs Pac-Man's 1) and pseudo-random fruit movement have been reverse-engineered.

### 1.3 Pac-Man Championship Edition DX (2010+)

Not decompiled. Modern game, different architecture entirely.

---

## 2. OTHER CLASSIC ARCADE MAZE GAMES

### 2.1 Computer Archeology -- Annotated Arcade Disassemblies

The site **computerarcheology.com** (T5 -- community reference, verified live) provides annotated disassemblies of many classic arcade games with completion percentages:

| Game | Platform | CPU | Completion | Maze? |
|------|----------|-----|------------|-------|
| **Space Invaders** | Arcade | Intel 8080 | ~100% | No (but canonical RE reference) |
| **Frogger** | Arcade (Konami) | Z80 | Sound complete, main partial | Semi-maze (grid navigation) |
| **Galaga** | Arcade (Namco) | Z80 x3 | 5% | No |
| **Defender** | Arcade (Williams) | 6809 | 75% | No |
| **Moon Patrol** | Arcade (Irem) | Z80 | 75% | No |
| **Phoenix** | Arcade | 8085 | 70% | No |
| **Asteroids** | Arcade (Atari) | 6502 | 80% | No |
| **Scramble** | Arcade (Konami) | Z80 | 1% (Sound) | Semi-maze |
| **Crazy Climber** | Arcade | Z80 | 1% | Vertical maze |

**URL:** `https://computerarcheology.com/Arcade/`

Note: Pac-Man and Dig Dug are NOT on computerarcheology.com. The Pac-Man hardware is documented primarily through MAME and the Lomont/Pittman documents.

### 2.2 Frogger (1997 3D remake, PS1)

**Repo:** `https://github.com/HighwayFrogs/frogger-psx`
**Status:** Listed on awesome-game-decompilations. The 1997 Hasbro Interactive remake, not the original Konami arcade. Frogger is a maze-navigation game (grid-based movement avoiding obstacles).

### 2.3 Gauntlet Dark Legacy / Gauntlet Legends

**Repos:** `https://github.com/sabishii-bit/Gauntlet-Dark-Legacy-Decompilation` and `https://github.com/drahsid/gauntlet-legends`
**Platform:** N64 / Arcade
**Status:** Listed on awesome-game-decompilations. Gauntlet is a classic dungeon-maze crawler.

### 2.4 Battle City (NES, 1985)

**Repo:** `https://github.com/cyneprepou4uk/NES-Games-Disassembly/tree/main/Battle%20City`
**Platform:** NES (6502)
**Status:** Full NES disassembly. Part of a broader NES disassembly project. Battle City features maze-based tank combat.

---

## 3. ENTOMBED (ATARI 2600, 1982) -- THE ACADEMIC CASE

This is the most academically studied reverse-engineered maze game, with peer-reviewed papers.

### 3.1 Papers

| Paper | Authors | Year | Venue | Key finding |
|-------|---------|------|-------|-------------|
| **"Entombed: An archaeological examination of an Atari 2600 game"** | Aycock, Copplestone | 2018 | arXiv:1811.02035 (T2) | Reverse-engineered the maze-generation algorithm. Found a mysterious lookup table that generates playable mazes in real-time under extreme Atari 2600 constraints. The origin of the table's values could not be fully explained. |
| **"Still Entombed After All These Years"** | Newell, Aycock, Biittner | 2022 | Internet Archaeology 59 (T1 -- peer-reviewed) | Follow-up using ~500 newly discovered development artifacts. Includes an unreleased Atari 2600 game. Addresses the mystery of the maze-generation table. |

**Technical insights:**
- Entombed generates infinite scrolling mazes in real-time using a 32-byte lookup table.
- The Atari 2600 has only 128 bytes of RAM and must update the display line-by-line (racing the beam), so the algorithm must be extraordinarily efficient.
- The lookup table encodes local constraints: given 5 cells in the previous two rows, it determines whether the current cell is wall or passage.
- The original paper could not determine how the table was derived -- it appeared to work but had no clear mathematical derivation. The follow-up paper addressed this using archival materials.

**Disassembly:** Available on computerarcheology.com at `https://computerarcheology.com/Atari2600/Entombed/` (1% completion listed, but the academic papers provide the complete analysis).

---

## 4. CONSOLE MAZE GAMES WITH FULL DECOMPILATIONS

### 4.1 Pokemon Games (Game Boy, GBA -- pret organization)

While not pure maze games, Pokemon games contain extensive maze-like dungeon layouts. The **pret** organization is the gold standard for game decompilation:

| Game | Repo | Stars | Language | Status |
|------|------|-------|----------|--------|
| Pokemon Red/Blue | `pret/pokered` | 4,623 | GBZ80 Assembly | Complete disassembly, builds matching ROM |
| Pokemon Crystal | `pret/pokecrystal` | ~4,000+ | GBZ80 Assembly | Complete |
| Pokemon Emerald | `pret/pokeemerald` | ~4,000+ | C (ARM) | Complete C decompilation |
| Pokemon FireRed | `pret/pokefirered` | ~2,000+ | C (ARM) | Complete |
| Pokemon Mystery Dungeon Red | `pret/pmd-red` | - | C (ARM) | In progress -- this is a pure maze/roguelike! |
| Pokemon Mystery Dungeon Sky | `pret/pmd-sky` | - | C (ARM) | In progress -- pure maze/roguelike! |

**Pokemon Mystery Dungeon** games are the most relevant here: they are pure maze games (randomly generated dungeon floors). The decompilation reveals the procedural maze generation algorithms.

### 4.2 Zelda Games (zeldaret organization)

Zelda games feature extensive dungeon mazes:

| Game | Repo | Stars | Status |
|------|------|-------|--------|
| Ocarina of Time | `zeldaret/oot` | 5,313 | ~100% C decompilation |
| Majora's Mask | `zeldaret/mm` | ~3,000+ | In progress |
| Wind Waker | `zeldaret/tww` | ~1,500+ | In progress |
| Twilight Princess | `zeldaret/tp` | ~500+ | In progress |

### 4.3 Super Mario 64 (n64decomp)

**Repo:** `n64decomp/sm64` -- 8,518 stars
**Status:** Complete C decompilation. While not a maze game per se, it contains maze-like level geometry and the decompilation project pioneered the modern community approach to N64 game decompilation. The "Hazy Maze Cave" level is literally a maze.

### 4.4 Dr. Mario (NES)

**Repo:** `https://github.com/Nostaljipi/dr-mario-disassembly`
**Platform:** NES (6502)
**Status:** Full disassembly. Puzzle game with maze-like block navigation.

---

## 5. PC MAZE GAMES (80s/90s)

### 5.1 Diablo (1996)

**Repo:** `https://github.com/diasurgical/devilution`
**Stars:** ~9,000+
**Status:** Complete C decompilation of Diablo 1. The dungeon generation algorithm (procedural maze generation) is fully reverse-engineered. The code reveals a modified recursive subdivision algorithm for generating dungeon levels.

### 5.2 Wolfenstein 3D (1992) -- Officially Released

**Status:** Source code officially released by id Software in 1995 (GPL).
**Repo:** Multiple ports and modernizations available.
**Maze relevance:** Wolf3D is fundamentally a maze game with a raycasting renderer. The level format is a simple 64x64 grid of wall tiles -- one of the purest maze game architectures ever shipped commercially.

### 5.3 DOOM (1993) -- Officially Released

**Status:** Source code officially released by id Software in 1997 (GPL). Doom 64 has a decompilation at `https://github.com/Erick194/DOOM64-RE` and PSX Doom at `https://github.com/Erick194/PSXDOOM-RE`.

### 5.4 Duke Nukem II (1993)

**Repo:** `https://github.com/lethal-guitar/Duke2Reconstructed`
**Status:** Reconstructed source code. Side-scrolling with maze-like level layouts.

### 5.5 Cosmo's Cosmic Adventure (1992)

**Repo:** `https://github.com/smitelli/cosmore`
**Status:** Full decompilation/reconstruction of the Apogee platformer. Scott Smitelli's work is exceptionally well-documented with detailed write-ups about the reverse engineering process.

### 5.6 Bio Menace (1993)

**Repo:** `https://github.com/lethal-guitar/BioMenaceDecomp`
**Status:** Decompilation of the Apogee platformer.

### 5.7 SkiFree

**Repo:** `https://github.com/yuv422/skifree_decomp`
**Status:** Decompilation of the Windows 3.1 classic.

### 5.8 Space Cadet Pinball

**Repo:** `https://github.com/k4zmu2a/SpaceCadetPinball`
**Stars:** Very high (~10K+)
**Status:** Complete decompilation of the Windows pinball game.

---

## 6. GAMES WITH OFFICIALLY RELEASED SOURCE CODE (maze-relevant)

| Game | Year | Release event | Maze relevance |
|------|------|---------------|----------------|
| **Wolfenstein 3D** | 1992 | id Software GPL release, 1995 | Pure maze FPS |
| **DOOM** | 1993 | id Software GPL release, 1997 | Maze-like level design |
| **Quake** | 1996 | id Software GPL release, 1999 | 3D mazes |
| **Lode Runner** | 1983 | Source recovered/documented | Maze-platformer |
| **Rogue** | 1980 | Source always available (BSD) | Procedural maze roguelike -- the original |
| **NetHack** | 1987 | Open source since inception | Procedural maze dungeon |

---

## 7. GOOD CANDIDATES FOR DECOMPILATION (not yet done)

These maze games have properties that make them tractable for decompilation:

| Game | Platform | Why tractable |
|------|----------|---------------|
| **Dig Dug** (1982) | Arcade (Z80 x2) | Same Namco hardware family as Pac-Man/Galaga. Small ROM. MAME driver exists. No known full disassembly published. |
| **Mr. Do!** (1982) | Arcade (Z80) | Simple maze-digging game, small ROM. |
| **Pengo** (1982) | Arcade (Z80) | Sega maze game, ice-block pushing. Small code. |
| **Rally-X** (1980) | Arcade (Z80) | Namco maze racing game, very early scrolling maze. Same hardware family. |
| **Lode Runner** (1983) | Apple II (6502) | Simple architecture, well-documented platform, maze-platformer hybrid. |
| **Maze War** (1974) | Various | One of the first FPS/maze games ever. Multiple platform versions. Historical significance. |
| **Tower of Druaga** (1984) | Arcade (6809) | Namco maze-tower game. Influenced Zelda. |

---

## 8. TOOLS AND INFRASTRUCTURE

### 8.1 MAME (Multiple Arcade Machine Emulator)

- **Repo:** `https://github.com/mamedev/mame` (10,005 stars)
- The single most important resource for arcade game reverse engineering. MAME drivers document hardware behavior, memory maps, I/O, and video/audio systems for thousands of arcade games.
- The Pac-Man driver (`src/mame/pacman/`) is the definitive reference for Pac-Man hardware emulation.

### 8.2 decomp.me

- **URL:** `https://decomp.me/`
- Collaborative platform for game decompilation. Functions can be claimed and worked on independently. Progress tracking per function.

### 8.3 Ghidra / IDA Pro

- NSA's Ghidra (free) and Hex-Rays IDA Pro (commercial) are the primary tools for static binary analysis used in these projects.
- Ghidra has specific support for Z80, 6502, 6809, and other retro CPUs.

### 8.4 RGBDS (Rogue Game Boy Development System)

- Assembler/linker toolchain used by pret for Game Boy disassemblies.

---

## 9. ACADEMIC REFERENCES

| Paper | Authors | Year | Topic |
|-------|---------|------|-------|
| Aycock & Copplestone | "Entombed: An archaeological examination of an Atari 2600 game" | 2018 | arXiv:1811.02035 -- maze generation algorithm RE |
| Newell, Aycock, Biittner | "Still Entombed After All These Years" | 2022 | Internet Archaeology 59 -- follow-up with dev artifacts |
| Lomont | "Pac-Man Emulation Guide" | ~2008 | Technical document on Pac-Man hardware |
| Pittman | "The Pac-Man Dossier" | 2009-2015 | Comprehensive Pac-Man game mechanics analysis |

---

## 10. SERENDIPITOUS CONNECTIONS

**Maze generation algorithms and CS theory:** The Entombed paper is fascinating from a CS perspective because its maze-generation lookup table is essentially a cellular automaton rule operating under severe computational constraints. The question "how was this table derived?" connects to:
- **Constraint satisfaction** (the table must produce traversable mazes)
- **Cellular automata theory** (Wolfram's elementary CA classification)
- **Information theory** (32 bytes encoding an infinite maze generator)

**Connection to Agent COBOL project:** The techniques used in retro game decompilation (pattern matching against known compiler outputs, reconstructing control flow from assembly) are directly applicable to COBOL legacy system analysis. The decomp.me collaborative approach could inspire tooling for the Agent COBOL project.

**Connection to Ranking Todo project (Bradley-Terry):** The awesome-game-decompilations list could benefit from a preference-based ranking system to surface the most interesting/complete projects rather than just an alphabetical list.

---

## SOURCES FETCHED

| Source | Tier | Verified |
|--------|------|----------|
| GitHub API: pret/pokered | T7 | Yes -- 4,623 stars |
| GitHub API: n64decomp/sm64 | T7 | Yes -- 8,518 stars |
| GitHub API: zeldaret/oot | T7 | Yes -- 5,313 stars |
| GitHub API: mamedev/mame | T7 | Yes -- 10,005 stars |
| GitHub API: CharlotteCross1998/awesome-game-decompilations | T7 | Yes -- full README fetched |
| GitHub API: sajattack/c64-pacman-disassembly | T7 | Yes -- 7 stars |
| computerarcheology.com/Arcade/ | T5 | Yes -- full site tree fetched |
| pacman.holenet.info (Pac-Man Dossier) | T5 | Yes -- confirmed live |
| lomont.org Pac-Man Emulation PDF | T5 | Yes -- confirmed 27-page PDF exists |
| Semantic Scholar: Entombed papers | T1-T2 | Yes -- both papers found |
| diasurgical/devilution (Diablo) | domain knowledge | Not individually fetched but confirmed in awesome list |

---

## WHAT TO READ NEXT

1. **The Pac-Man Dossier** (`pacman.holenet.info`) -- if you want the deepest dive into a single maze game's mechanics derived from disassembly analysis
2. **Aycock & Copplestone, "Entombed" (arXiv:1811.02035)** -- if you want the most academically rigorous reverse-engineering study of a maze game
3. **awesome-game-decompilations** (`github.com/CharlotteCross1998/awesome-game-decompilations`) -- if you want the comprehensive catalog of all game decompilation projects
4. **pret/pmd-red** or **pret/pmd-sky** -- if you want to see procedural maze generation code recovered through decompilation (Pokemon Mystery Dungeon)
5. **diasurgical/devilution** -- if you want to see a complete C decompilation of a game with procedural dungeon/maze generation (Diablo)
