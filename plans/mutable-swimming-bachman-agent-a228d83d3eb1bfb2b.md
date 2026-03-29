# Research: Untapped Decompilation Potential in Classic Arcade Maze Games

**Epistemic status:** Empirically grounded -- based on MAME source code (primary hardware documentation), the awesome-game-decompilations catalog, and Computer Archeology project analysis.
**Confidence:** High for hardware architecture (MAME source is definitive); Medium for existing RE efforts (community work is scattered and poorly indexed); Low for complexity estimates (inherently speculative).

**Sources actually fetched:**
- MAME `digdug.cpp` + `digdug.h` + `galaga.h` (T7 -- open-source emulator, hardware-accurate)
- MAME `pengo.cpp` (T7)
- MAME `rallyx.cpp` (T7)
- MAME `mrdo.cpp` (T7)
- MAME `mappy.cpp` -- covers Tower of Druaga, Dig Dug II, Motos (T7)
- awesome-game-decompilations README.md -- full list, all 6 chunks (T7 -- GitHub community catalog)
- Computer Archeology arcade index page (T7)

---

## 1. Dig Dug (Namco, 1982)

### Hardware Architecture

From MAME `digdug.h` and `digdug.cpp`, Dig Dug inherits from `galaga_state`, confirming it runs on the **Namco Galaga hardware platform**:

- **CPU**: 3x Z80 (main + 2 sub CPUs) -- same triple-CPU architecture as Galaga
- **ROM**: ~24KB program ROM across the three CPUs
- **Sound**: Namco custom WSG (Waveform Sound Generator) -- same `namco_device` as Galaga
- **Custom ICs**: Namco 06XX (bus controller), 07XX (clock divider), 51XX/53XX (I/O), plus ER2055 EAROM for high scores
- **Video**: Background tilemap (selectable from 4 stored in ROM via `bg_select`), foreground text tilemap, hardware sprites
- **Resolution**: 36x28 tiles (288x224 pixels), with a non-trivial coordinate remapping (`tilemap_scan` converts 32x32 logical to 36x28 physical)

### The Tunneling Mechanic

The tunneling system is **NOT maze data in ROM** -- it is player-created modification of the background tilemap. Key evidence from MAME:

1. **`bg_select` register** (4 background images stored in GFX ROM `gfx4`): `code = rom[tile_index | (m_bg_select << 10)]` -- each background is 1024 tiles
2. **`bg_disable` flag**: When set, background renders with color code 0xF (all black) -- used during transitions
3. **`bg_color_bank`**: Additional color bank selection for background variety
4. The foreground tilemap (`tx_get_tile_info`) overlays the background with character tiles -- the tunnel paths are drawn here by modifying `m_videoram`

**Architectural insight**: The digging mechanic works by writing specific tile codes into the foreground tilemap VRAM (address range managed by the text layer). The "soil" is the background image; the "tunnels" are transparent foreground tiles that reveal the background beneath (or rather, foreground tiles that show "empty space"). This is elegant -- the entire tunneling state is captured in the 1KB foreground tilemap RAM.

### Enemy AI (Pooka and Fygar)

The AI logic is in the Z80 ROM, not in MAME (which only emulates hardware). From general knowledge:

- **Pooka**: Round ghost-like enemies that navigate existing tunnels. When the player is nearby, they can enter a "ghost mode" where they pass through solid ground (rendered as a flattened sprite squeezing through dirt). Their pathfinding alternates between chasing the player and wandering.
- **Fygar**: Dragon-like enemies that can breathe fire horizontally. Fire-breathing is worth double points when killed from the side. They follow similar chase/wander patterns to Pooka but prefer horizontal movement (to maximize fire-breathing effectiveness).
- **Inflation mechanic**: The player's pump weapon progressively inflates enemies through 4 sprite animation stages before they pop. If pumping stops, the enemy slowly deflates and recovers.

### Existing Disassembly Efforts

- **awesome-game-decompilations list**: Dig Dug is **NOT listed**. No known public decompilation project.
- **Computer Archeology**: The site does NOT have a Dig Dug section (verified from the arcade index).
- **MAME source**: Provides complete hardware emulation but NOT game logic disassembly.
- **Scott Lawrence** did extensive work on the Namco Galaga hardware family, but focused on Galaga itself, not Dig Dug.

### What Makes Dig Dug Unique for Maze Research

Dig Dug is arguably the most interesting game on this list because it is a **player-generated maze game**. Unlike Pac-Man where the maze is fixed, in Dig Dug the player literally creates the maze topology through digging. This makes it:

1. A study in **emergent level design** -- the maze is procedurally created by player action
2. An early example of **destructible terrain** in games
3. The enemy AI must navigate a maze that didn't exist at level start -- requiring real-time pathfinding on a dynamically changing graph
4. The game's difficulty comes from the ABSENCE of a pre-designed optimal path

---

## 2. Pengo (Sega, 1982)

### Hardware Architecture

From MAME `pengo.cpp`, Pengo runs on a **modified Pac-Man hardware platform** (inherits from `pacman_state`):

- **CPU**: Single Z80 @ 3.072 MHz (XTAL 18.432 MHz / 6)
- **ROM**: 32KB address space (0x0000-0x7FFF), though much may be empty
- **Video RAM**: 0x8000-0x83FF (tile codes), 0x8400-0x87FF (tile colors) -- same Pac-Man layout
- **Sprites**: 6 sprite pairs at 0x8FF0-0x8FFF and 0x9020-0x902F
- **Sound**: Namco WSG (3 voices, same as Pac-Man): waveform, frequency, volume registers at 0x9000-0x901F
- **Memory-mapped I/O**: DSW at 0x9000/0x9040, inputs at 0x9080/0x90C0
- **Special registers at 0x9040-0x9047** (via LS259 latch):
  - 0x9042: palette bank selector
  - 0x9043: flip screen
  - 0x9046: color lookup table bank selector
  - 0x9047: **character/sprite bank selector** -- allows switching between two complete tile/sprite sets

### Encryption

Pengo uses **Sega encryption** (`segacrpt_device`) -- the ROM opcodes are encrypted. MAME includes the decryption logic. This is historically interesting: Sega encrypted their Z80 games to prevent bootlegging. The `pengoe` and `pengou` variants handle different encryption schemes. There is also `init_pengo6()` with a custom `decode_pengo6()` function.

### Block-Pushing Physics

The maze in Pengo is a grid of ice blocks. The player can push blocks, which slide until they hit a wall or another block, crushing Sno-Bees (enemies) in their path. This mechanic is essentially **Sokoban on ice** with enemies -- blocks don't stop until collision.

The implementation likely uses:
- The tilemap RAM to represent block positions (each block = a specific tile code)
- Block pushing: on player input adjacent to a block, scan in the push direction for the first obstacle, animate the block sliding, update tile codes
- Crushing detection: check if a Sno-Bee sprite overlaps the block's path during the slide animation

### Sno-Bee AI

Sno-Bees (penguin enemies) hatch from eggs embedded in specific ice blocks. When their block is destroyed, they emerge and chase the player. Their AI involves:
- Navigation through the maze of remaining ice blocks
- Ability to break blocks (after a delay)
- Increasing aggression as the level progresses

### Diamond Blocks

The maze borders contain special "diamond blocks" (flashing blocks at the edges). If all 3 diamond blocks on one wall are aligned, the player earns a large bonus. The Sno-Bees are stunned when a wall is pushed (hitting the wall button causes all Sno-Bees to temporarily freeze and become vulnerable).

### Existing RE Work

- **awesome-game-decompilations list**: Pengo is **NOT listed**.
- Computer Archeology: NOT covered.
- MAME provides complete hardware emulation. The Pac-Man heritage means the video system is extremely well-documented.
- The Sega encryption has been fully broken (by the MAME team) and is available in `segacrpt_device`.

---

## 3. Rally-X (Namco, 1980)

### Hardware Architecture

From MAME `rallyx.cpp`, Rally-X has the most detailed hardware documentation of any game on this list:

- **CPU**: Single Z80
- **ROM**: 16KB (0x0000-0x3FFF) -- 8 x 2KB ROMs (or 4 x 4KB)
- **Video RAM**: 0x8000-0x8FFF -- combined tilemap RAM for radar + playfield + sprites
  - First half: radar tilemap + sprite registers
  - Second half: scrolling playfield tilemap
- **Work RAM**: 0x9800-0x9FFF
- **Sound**: Namco WSG custom
- **Custom ICs**: NVC285 (Z80 bus controller, DIP28) and NVC293 (video shifter, DIP18) -- both documented as simple logic replaceable by TTL daughter boards
- **Scrolling**: Hardware scroll registers at 0xA130 (X) and 0xA140 (Y) -- `POSIX` and `POSIY`
- **Interrupt**: Configurable via I/O port 0 (supports both IM 0 and IM 2)

### The Scrolling Implementation (1980!)

Rally-X is historically significant as **one of the first arcade games with a scrolling playfield**. The MAME memory map reveals how this works on 1980 hardware:

1. **Two separate tilemaps**: The hardware maintains TWO tile layers:
   - A **scrolling playfield** (the maze) controlled by X/Y scroll registers
   - A **fixed radar/minimap** overlay (like a HUD)
2. **Hardware scroll registers**: Single-byte values at 0xA130 and 0xA140 control pixel-level scrolling of the playfield tilemap. The hardware handles the rendering -- no software tile-copying needed.
3. **Sprite layer**: Separate from both tilemaps, rendered on top.
4. **"Bullets"** (smoke screen): Handled specially via `SODWR` register at 0xA000 -- 4-bit values for shape and X position MSB.

The MAME source notes that the Konami games (Jungler, Tactician, Loco-Motion, Commando) **copied Rally-X's video hardware** almost identically, with minor differences:
- Konami added an optional starfield generator (from Scramble hardware)
- Konami used a different sound system (slave Z80 + 2x AY-3-8910 vs Namco's single Z80 + WSG)
- The scroll registers exist in Jungler/Tactician but are always 0 (unused)

### Radar/Minimap Implementation

The radar is the second tilemap layer. In Rally-X's memory map:
- RAM 6A/6C and 6J/6K: "radar tilemap RAM + sprites" (first half of video RAM at 0x8000-0x83FF and 0x8800-0x8BFF)
- The radar shows a scaled-down view of the full maze with dots for player, enemies, and flags
- This is likely rendered by writing directly to the radar tilemap tiles based on entity positions

### Enemy AI Chase Patterns

Rally-X enemies are cars that chase the player through the scrolling maze. The player's defense is a smoke screen (limited supply) that temporarily stuns pursuing enemies. The AI likely uses:
- Simple target-seeking on the maze graph (similar to Pac-Man ghost AI but in a scrolling context)
- Different aggression levels as the game progresses

### Existing RE Work

- **awesome-game-decompilations list**: Rally-X is **NOT listed**.
- Computer Archeology: NOT covered.
- The MAME source for Rally-X is exceptionally detailed -- the memory map comment block is one of the most thorough in the entire MAME codebase, derived from actual schematics ("from the schematics").

---

## 4. Mr. Do! (Universal, 1982)

### Hardware Architecture

From MAME `mrdo.cpp`:

- **CPU**: Single Z80
- **ROM**: 32KB (0x0000-0x7FFF)
- **Main Clock**: XTAL 8.2 MHz, Video clock: XTAL 19.6 MHz
- **Video**: Two tilemap layers:
  - Background: 0x8000-0x87FF (`bgvideoram`)
  - Foreground: 0x8800-0x8FFF (`fgvideoram`)
  - Sprites: 0x9000-0x90FF
- **Sound**: 2x SN76489 (labeled "U8106" to hide identity -- same as Lady Bug, PCB S/N 8106)
- **Scrolling**: Separate X (0xF000-0xF7FF) and Y (0xF800-0xFFFF) scroll registers
- **Flip/Priority**: 0x9800 controls screen flip AND playfield layer priority
- **Work RAM**: 0xE000-0xEFFF (4KB)
- **Protection**: PAL16R6 at U001 -- equations fully extracted from JEDEC dump in MAME source

### The Protection PAL

MAME includes the **complete Boolean equations** for the copy protection PAL, extracted via `jedutil`:
```
t1 = i2 & !i3 & i4 & !i5 & !i6 & !i8 & i9
t2 = !i2 & !i3 & i4 & i5 & !i6 & i8 & !i9
t3 = i2 & i3 & !i4 & !i5 & i6 & !i8 & i9
t4 = !i2 & i3 & i4 & !i5 & i6 & i8 & i9
```
The Taito bootleg version (`mrdot_state`) has a simplified protection, while the original Universal version (`mrdo_state`) has a more complex PAL where outputs are fed back to inputs. MAME currently uses a hack for the original: `return ROM[m_maincpu->state_int(Z80_HL)]`.

### Hybrid Digging + Maze Design

Mr. Do! combines:
1. **Fixed maze paths** (pre-drawn corridors in the tilemap)
2. **Diggable earth** (like Dig Dug -- the player can tunnel through soft areas)
3. **Dot collection** (like Pac-Man -- cherries/dots scattered through corridors)
4. **Ball weapon** (a bouncing ball the player can throw to kill enemies)
5. **Apple mechanic** (similar to rocks in Dig Dug -- apples fall when undermined, crushing enemies below)

The two-layer tilemap architecture (BG + FG) enables this: one layer holds the fixed maze structure, the other handles the destructible terrain overlay.

### Cherry Chain Mechanic

When the player collects all cherries in a level, an EXTRA letter appears. Collecting all 5 letters (E-X-T-R-A) across multiple levels awards an extra life. This creates a risk/reward dynamic between clearing levels quickly and hunting for all cherries.

### Existing RE Work

- **awesome-game-decompilations list**: Mr. Do! is **NOT listed**.
- Computer Archeology: NOT covered.
- The MAME driver is quite complete, with full PAL equations documented.

---

## 5. Tower of Druaga (Namco, 1984)

### Hardware Architecture

From MAME `mappy.cpp` (Tower of Druaga shares the Mappy hardware platform):

- **CPU**: 2x MC6809 (NOT Z80! -- the Mappy family uses 6809)
  - Main CPU @ 1.536 MHz
  - Sound CPU @ 1.536 MHz
- **ROM**: ~32KB program ROM (2x 128K ROMs mapped at 0x8000-0xFFFF, larger than Mappy's 3x 64K)
- **Video**: Scrolling tilemap (17XX custom -- upgraded from Super Pac-Man's 00XX)
  - Tilemap RAM: 0x0000-0x0FFF (tile number) + 0x1000-0x1FFF (tile color) -- 8KB total
  - Work RAM: 0x2000-0x4FFF
  - Sprites: Embedded in work RAM areas
- **Sound**: Namco 15XX WSG + 99XX DAC
- **Custom ICs**: 07XX (clock), 15XX (sound), 16XX (I/O control), 17XX (scrolling tilemap), 04XX (sprite address), 11XX (gfx shifter/mixer), 12XX (sprite generator)
- **Tilemap scroll**: Hardware register at 0x3800 area (`POSIV`), data encoded in address bits A3-A10
- **Special**: Tower of Druaga has **4x the sprite color combinations** compared to Mappy, Dig Dug II, and Motos -- making it the most graphically complex game on this platform

### 60 Floors of Mazes

Each of the 60 floors is a distinct maze. The maze data is likely stored in ROM as tilemap data loaded per floor. The scrolling tilemap hardware handles the display.

### Item Revelation Mechanic

This is Tower of Druaga's most famous (and most obscure) feature. On each floor, there is a hidden treasure that can only be revealed by performing a specific action:
- Floor 1: Kill all slimes
- Floor 2: Kill a specific enemy with a specific timing
- Floor 3: Touch specific walls in a specific order
- etc.

The actions are completely arbitrary and unknowable without a guide. This was intentional -- Namco designed the game for communal discovery in Japanese arcades, where players would share secrets. The item revelation conditions are encoded as specific game-state checks in the ROM logic.

### Influence on Game History

Tower of Druaga was enormously influential in Japan (far less known in the West):
- **Dragon Quest** (1986): Yuji Horii cited Druaga as a key influence on the RPG genre
- **The Legend of Zelda** (1986): Shigeru Miyamoto acknowledged Druaga's influence on action-adventure design
- **Rogue-like tradition in Japan**: The concept of floor-based dungeon exploration with hidden items connects to the entire Japanese dungeon-crawling tradition

### Existing RE Work

- **awesome-game-decompilations list**: Tower of Druaga is **NOT listed**.
- Computer Archeology: NOT covered.
- The MAME driver provides excellent hardware documentation, and the 6809 architecture is well-tooled for disassembly.

---

## 6. Awesome-Game-Decompilations List Analysis

### Coverage Statistics

The full list contains approximately **450+ decompilation/disassembly projects** across categories:
- **Pokemon**: ~30 projects (most mature decompilation community)
- **Zelda**: ~12 projects (including OoT, MM, BotW)
- **Animal Crossing**: 3 projects
- **Mario**: ~50+ projects (SM64 is the gold standard)
- **Sonic**: ~15 projects
- **Other**: ~340+ projects

### Are Any of Our Target Games Listed?

**None of the five target games appear on the list:**
- Dig Dug: NOT listed
- Pengo: NOT listed
- Rally-X: NOT listed
- Mr. Do!: NOT listed
- Tower of Druaga: NOT listed

### Maze Games That DO Appear

Scanning the full list for maze-adjacent games:
- **Battle City** (NES disassembly) -- tank maze game
- **Pac-Man** -- NOT listed (surprisingly, though there are many ports/clones)
- **Gauntlet Dark Legacy** and **Gauntlet Legends** -- action maze games (N64 decompilations)
- **Space Cadet Pinball** -- not maze but notable
- **Bomberman 64**, **Bomberman Hero**, **Bomberman 64: The Second Attack** -- destructible maze games

### Notable Gaps

The list is heavily biased toward:
1. Nintendo console games (N64, GBA, GCN, Wii dominate)
2. Games with large modding communities (Pokemon, Zelda, Mario)
3. Games where decompilation enables ports to modern hardware

Classic arcade games are almost entirely absent. This represents a significant gap.

---

## 7. MAME as a Decompilation Resource

### Hardware Documentation Quality

MAME provides three levels of documentation for these games:

| Game | Memory Map | Custom IC Docs | Schematic-Derived | Video System | Sound System |
|------|-----------|----------------|-------------------|-------------|-------------|
| Dig Dug | Complete | Partial (shared w/ Galaga) | No | Full tilemap + sprite rendering | Namco WSG |
| Pengo | Complete | Via Pac-Man heritage | No | Full (Pac-Man compatible) | Namco WSG 3-voice |
| Rally-X | **Exceptional** | Full (NVC285, NVC293 documented as TTL-replaceable) | **Yes** (schematics referenced) | Full dual-tilemap + scroll | Namco WSG + discrete explosion |
| Mr. Do! | Complete | Protection PAL fully decoded | Partial (XTAL values from manual) | Full dual-layer + sprites | 2x SN76489 |
| Tower of Druaga | Complete (via Mappy) | Good (17XX, 04XX, 12XX customs documented) | No | Full scrolling tilemap + 4x sprite colors | Namco 15XX + 99XX DAC |

### MAME's CPU Debugger for Dynamic Analysis

MAME includes a built-in debugger that is invaluable for reverse engineering:

1. **Breakpoints**: Set breakpoints on any Z80/6809 address
2. **Watchpoints**: Monitor memory reads/writes (crucial for understanding how the game modifies tilemap RAM during digging)
3. **Trace logging**: Log all executed instructions to a file
4. **Memory viewer**: Real-time inspection of RAM, VRAM, sprite registers
5. **State save/load**: Capture and restore exact machine state
6. **Disassembler**: Built-in disassembly view with labels
7. **Cheat engine**: Modify memory values to test hypotheses about data structures

**Practical workflow for decompiling these games:**
1. Start MAME with `-debug` flag
2. Set watchpoints on VRAM writes to understand rendering
3. Set breakpoints on input reading to trace game logic
4. Use trace logging during specific game events (digging, enemy spawning, level transitions)
5. Correlate traced addresses with the memory maps documented in the MAME source

### What MAME Does NOT Provide

- **Game logic analysis**: MAME emulates the hardware, not the game software. The AI algorithms, level data structures, and game rules are in the ROM, not in MAME's source.
- **Commented disassembly**: MAME doesn't include disassembled game code.
- **Data structure documentation**: The format of level data, enemy behavior tables, sprite animation sequences -- these must be reverse-engineered from the ROM.

---

## 8. Feasibility Assessment

### Comparative Table

| Game | ROM Size | CPU | CPUs | Estimated C LOC | Existing Docs | Difficulty | Priority |
|------|----------|-----|------|-----------------|---------------|------------|----------|
| Rally-X | 16KB | Z80 | 1 | ~3,000-4,000 | Excellent (schematics) | **Easy** | HIGH |
| Pengo | ~24KB | Z80 | 1 | ~4,000-6,000 | Good (Pac-Man heritage) | **Easy-Medium** | HIGH |
| Mr. Do! | 32KB | Z80 | 1 | ~5,000-7,000 | Good (PAL decoded) | **Medium** | MEDIUM |
| Dig Dug | ~24KB | Z80 | 3 | ~6,000-9,000 | Good (Galaga heritage) | **Medium-Hard** | HIGH |
| Tower of Druaga | ~32KB | 6809 | 2 | ~6,000-8,000 | Good (Mappy heritage) | **Medium** | HIGH |

### Detailed Difficulty Analysis

**Rally-X (EASIEST)**
- Single Z80, smallest ROM (16KB)
- Exceptionally documented memory map (derived from schematics)
- Simple game mechanics (drive, collect flags, deploy smoke)
- Custom ICs are documented as TTL-replaceable (simple logic)
- The scrolling implementation is historically important and worth documenting alone
- **Main challenge**: Understanding the dual-tilemap (playfield + radar) rendering pipeline

**Pengo (EASY-MEDIUM)**
- Single Z80, well-understood Pac-Man hardware base
- Sega encryption adds a wrinkle, but it's fully broken in MAME
- Block-pushing physics are deterministic and relatively simple
- **Main challenge**: The encryption means you need to decrypt the ROM first (trivial with MAME's code); the Sno-Bee AI and block interaction logic may be moderately complex

**Mr. Do! (MEDIUM)**
- Single Z80, but larger ROM (32KB)
- Protection PAL adds complexity, but equations are fully extracted
- The hybrid digging + dot-collection + ball-throwing + apple-physics creates more interacting systems than the simpler games
- Two sound chips (vs one WSG) means more sound driver code
- **Main challenge**: The feedback-loop protection PAL on the original (non-Taito) version; the multiple overlapping game mechanics

**Dig Dug (MEDIUM-HARD)**
- **Three Z80 CPUs** -- this is the main difficulty multiplier
  - CPU 1: Main game logic
  - CPU 2: Enemy AI and movement
  - CPU 3: Sound generation
- Inter-CPU communication via shared RAM adds synchronization complexity
- The dynamic maze generation (digging) requires understanding the tilemap modification logic
- Enemy AI with ghost-mode (passing through walls) is non-trivial
- **Main challenge**: Coordinating the disassembly of three CPUs that communicate via shared memory; understanding the inflation/deflation state machine

**Tower of Druaga (MEDIUM)**
- 6809 instead of Z80 -- different toolchain needed, but 6809 is well-supported (os9 ecosystem, various disassemblers)
- Two CPUs (main + sound) -- simpler than Dig Dug's three
- 60 floors of maze data and 60 unique item-revelation conditions represent significant data to catalog
- The 4x sprite color space suggests more complex rendering logic
- **Main challenge**: Documenting the 60 floor-specific triggers for hidden items; the sheer volume of game content relative to ROM size

### Recommended Decompilation Order

1. **Rally-X** -- smallest, best documented, historically significant (first scrolling maze + minimap). Perfect "starter project" for arcade decompilation.
2. **Pengo** -- clean single-CPU design, well-understood hardware, interesting block-physics mechanics.
3. **Tower of Druaga** -- culturally significant (influenced Dragon Quest and Zelda), 6809 architecture provides variety, the hidden-item catalog alone would be a valuable contribution.
4. **Dig Dug** -- the most architecturally interesting (dynamic maze creation), but the triple-CPU design demands more effort.
5. **Mr. Do!** -- solid game but less unique than the others; the protection PAL is interesting but the gameplay mechanics overlap with Dig Dug.

---

## Serendipitous Connections

### Dynamic Maze Generation and Graph Theory
Dig Dug's player-created tunneling is essentially **online graph construction** -- each dig action adds edges to a planar graph. The enemy AI must then solve reachability queries on this dynamically changing graph. This connects to:
- **CS**: Online graph algorithms, dynamic shortest paths (Demetrescu-Italiano, 2004)
- **Math**: Planar graph theory, maze generation algorithms (Wilson's algorithm, randomized DFS)
- **Connection to Agent Framework project**: The enemy AI in Dig Dug is an early example of multi-agent pathfinding on a dynamic graph -- relevant to multi-agent orchestration

### Rally-X's Minimap as Information Design
Rally-X's 1980 radar display is one of the earliest examples of a **minimap** in games -- a UI pattern now universal in gaming. From an information design perspective, it's a spatial data compression problem: how to render a useful summary of a larger space in a small viewport. This connects to:
- **Economics**: Information asymmetry reduction -- the minimap converts a game of incomplete information into one of (nearly) complete information
- **CS**: Level-of-detail rendering, spatial indexing (quadtrees)

### Tower of Druaga and Mechanism Design
The hidden-item mechanic is a remarkable example of **mechanism design for information markets**. Namco deliberately made the items undiscoverable by a single player, forcing communal knowledge-sharing in arcades. This is:
- **Economics**: A designed information externality -- the value of playing increases with the size of the player community
- **Game theory**: Cooperative games with private information
- **Connection to Preference Sort project**: The ranking of "which floors are hardest" or "which items are most valuable" is a natural preference-learning problem

---

## What Was NOT Found

1. **No existing full disassemblies** for any of the five target games. Partial documentation may exist on obscure forums (AtariAge, various retro-computing wikis) but nothing surfaced in systematic search.
2. **No academic papers** on the AI or game design of these specific titles (game studies literature tends to focus on Pac-Man, Space Invaders, and later titles).
3. **Computer Archeology** does NOT cover any of these five games. Their arcade section covers: Asteroids, Crazy Climber, Defender, Frogger, Moon Patrol, Pac-Man, and Space Invaders (among others).
4. **SearXNG search engines** were largely rate-limited during this research session (Google, Brave, DuckDuckGo, Startpage all CAPTCHA'd/suspended), limiting web search to MAME source and GitHub direct fetches.

---

## Sources

| Tier | Source | Used For |
|------|--------|----------|
| T7 | MAME `digdug.cpp`, `digdug.h`, `galaga.h` | Dig Dug hardware architecture, video system |
| T7 | MAME `pengo.cpp` | Pengo hardware, memory map, encryption |
| T7 | MAME `rallyx.cpp` | Rally-X hardware, scrolling, memory map (schematic-derived) |
| T7 | MAME `mrdo.cpp` | Mr. Do! hardware, protection PAL equations |
| T7 | MAME `mappy.cpp` | Tower of Druaga hardware (Mappy family), custom ICs |
| T7 | awesome-game-decompilations (GitHub) | Catalog of existing decompilation projects |
| T7 | Computer Archeology arcade index | Verification of existing disassembly coverage |
| -- | Author knowledge (pre-training) | Game mechanics, historical context, AI descriptions |
