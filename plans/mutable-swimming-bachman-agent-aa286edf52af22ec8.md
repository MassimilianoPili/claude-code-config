# Deep Dive: Rally-X, Untouched Arcade Maze Games, and Reverse Engineering Toolkit

Research compiled from MAME source code, Computer Archeology, awesome-game-decompilations, and web sources.

---

## 1. Rally-X Hardware Deep Dive

**Source**: `src/mame/namco/rallyx.cpp` + `rallyx_v.cpp` (MAME, BSD-3-Clause, by Nicola Salmoria)

### 1.1 Overview

Rally-X (1980) and New Rally-X (1981) by Namco. Single Z80 CPU at 18.432 MHz master clock. Namco sound hardware (no slave CPU for sound -- unlike the Konami clones which use a slave Z80 + 2x AY-3-8910).

**Konami copied Rally-X's video hardware** for Jungler (1981), Tactician (1981), Loco-Motion (1982), and Commando (1983 Sega). The boards are physically different but logically equivalent.

Two Namco customs:
- **NVC285** (DIP28): Z-80 sync bus controller. Replaceable by TTL daughter board A082-91383-B000.
- **NVC293** (DIP18): Video shifter. Replaceable by TTL daughter board A082-91388-A000.

### 1.2 Complete Memory Map (Rally-X)

From schematics (modified to match program behavior):

```
Address          Dir  Name      Description
---------------- ---  --------- -----------------------
0x0000-0x3FFF    R    ROM 1B-1L Program ROMs (8x 2716 or 4x 2732)
0x8000-0x8FFF    R/W  RAM 6x    Video RAM (tilemaps + sprites)
  0x8000-0x83FF         RAM      Radar tilemap + sprite registers (FG)
  0x8400-0x87FF         RAM      Playfield tilemap (BG - tile codes)
  0x8800-0x8BFF         RAM      Radar tilemap + sprite registers (FG attrs)
  0x8C00-0x8FFF         RAM      Playfield tilemap (BG - tile attrs)
0x9800-0x9FFF    R/W  RAM 6E-6N Work RAM
0xA000           R    P1        Player 1 inputs (joy 4-way, button, start, coin)
0xA080           R    P2        Player 2 inputs
0xA100           R    DSW       Dip switches
0xA000-0xA00F    W    SODWR     Bullets shape and X pos MSB ("Small Objects")
0xA080           W              Watchdog reset
0xA100-0xA11F    W    RAM 2N/2P Sound control registers (Namco WSG)
0xA130           W    POSIX     Playfield X scroll
0xA140           W    POSIY     Playfield Y scroll
0xA170           W    WR3       Unknown (written every frame, heavily)
0xA180-0xA187    W    LS259     Latch outputs:
  bit 0: BANG    - Explosion sound trigger
  bit 1: INT ON  - Interrupt enable
  bit 2: SOUND ON - Sound enable (broken in New Rally X)
  bit 3: FLIP    - Flip screen
  bit 4:         - 1P start lamp
  bit 5:         - 2P start lamp
  bit 6:         - Coin lockout
  bit 7:         - Coin counter

I/O port 0x00: W - Sets interrupt vector/instruction (game uses both IM 2 and IM 0)
```

### 1.3 Dual Tilemap Architecture

Rally-X uses **two tilemaps** that share the same 4KB video RAM region (`0x8000-0x8FFF`):

1. **Background tilemap (BG)**: 32x32 tiles, 8x8 pixels each. This is the scrolling playfield -- the maze. Stored at RAM offset `0x400` (tile codes) and `0xC00` (attributes). Hardware scrollable via registers at `0xA130` (X) and `0xA140` (Y).

2. **Foreground tilemap (FG)**: Only **8x32 tiles** (a narrow radar/score strip). Stored at RAM offset `0x000`. This is the radar minimap + score display on the right side of the screen. NOT scrollable -- it stays fixed.

**Rendering order** (from `screen_update_rallyx`):
```
1. BG tilemap (low priority tiles)        -> bg_clip region (left 28*8 pixels)
2. FG tilemap (low priority tiles)        -> fg_clip region (right 8*8 = 32 pixels)
3. BG tilemap (high priority tiles, cat=1) -> with priority bit set
4. FG tilemap (high priority tiles, cat=1) -> with priority bit set
5. Bullets (first pass - transpen mode)
6. Sprites (with pdrawgfx priority)
7. Bullets (second pass - transtable mode, for palette bank switching)
```

The BG/FG split is enforced by **clipping rectangles**: BG renders to x=[0..223], FG to x=[224..255].

**Tile format**: Each tile = 2 bytes (code + attribute).
- Attribute byte: bits 0-5 = color, bit 5 = priority category, bits 6-7 = flip X/Y.

### 1.4 Hardware Scroll Registers

```c
// From rallyx.cpp address map:
map(0xa130, 0xa130).w(FUNC(rallyx_state::scrollx_w));  // POSIX
map(0xa140, 0xa140).w(FUNC(rallyx_state::scrolly_w));  // POSIY

// From rallyx_v.cpp:
void rallyx_state::scrollx_w(uint8_t data) {
    m_bg_tilemap->set_scrollx(0, data);
}
void rallyx_state::scrolly_w(uint8_t data) {
    m_bg_tilemap->set_scrolly(0, data);
}
```

Both are single 8-bit registers. The BG tilemap wraps around (32*8 = 256 pixels fits exactly in 8 bits). Only the BG tilemap scrolls; the FG (radar) is fixed.

**Quirk**: The scrolling tilemap is slightly misplaced by 3 pixels:
```c
m_bg_tilemap->set_scrolldx(3, 3);  // "the scrolling tilemap is slightly misplaced in Rally X"
```

The Konami clones (Jungler, Tactician) kept the scroll registers but always write 0 to them. Locomotion and Commando removed them entirely.

### 1.5 Smoke Screen Mechanic Implementation

The smoke screen in Rally-X is implemented through the **bullet/small object** system, which is also used for the collectible flags and smoke puffs.

**Bullet hardware** (from `rallyx_draw_bullets`):
```
Location        Purpose
m_radarx[offs]  X position (8-bit)
m_radary[offs]  Y position (8-bit, subtracted from 253)
m_radarattr[]   Attributes: bit 0 = X MSB (9th bit), bits 1-3 = shape (XORed with 0x07)
```

Up to 12 bullets/objects are rendered (offsets 0x14 to 0x1F, 2 bytes each).

**Video mixer peculiarity** (key to smoke rendering):
The hardware has **two 16-color palette banks**:
- Bank 1: characters and sprites
- Bank 2: bullets (smoke, flags)

When a bullet is on screen, the hardware:
1. Selects the second palette bank
2. Replaces the **bottom 2 bits** of the tile's palette entry with the bullet's own bits
3. Leaves the **top 2 bits** untouched

This means a bullet could theoretically show 4 different colors depending on the background underneath. None of the games exploit this -- the bullet palette repeats the same colors 4 times.

**When a bullet overlaps a sprite**: The palette bank changes but the palette entry number does NOT change. The sprite pixels under the bullet just switch banks, creating the visual "smoke overlay" effect. This is emulated with a two-pass rendering:
1. Draw bullets normally (transpen mode)
2. Draw sprites (with pdrawgfx)
3. Draw bullets again (transtable mode) -- bullets not covered by sprites remain unchanged, while those over sprites alter the sprite color

### 1.6 Color Hardware

32-entry palette PROM (8 bits each):
```
bit 7 -- 220 ohm -- BLUE
      -- 470 ohm -- BLUE
      -- 220 ohm -- GREEN
      -- 470 ohm -- GREEN
      -- 1k ohm  -- GREEN
      -- 220 ohm -- RED
      -- 470 ohm -- RED
bit 0 -- 1k ohm  -- RED
```

Rally-X has a 1k pull-down on Blue only. Locomotion has it on all three RGB.

256-entry color lookup table PROM maps tile/sprite indices to the 32-entry palette.

### 1.7 Easter Egg

Enter service mode, hold B1, enter: 2xU 7xD 1xR 6xL. Displays "(c) NAMCO LTD. 1980".

---

## 2. Dig Dug Architecture

**Source**: `src/mame/namco/digdug.cpp`, `digdug.h`, `galaga.cpp`, `galaga.h` (MAME)

### 2.1 The Galaga Hardware Family Tree

All four games use the same **3x Z80 + shared memory** CPU design:

```
Bosconian (1981) --+
Galaga (1981)    --+-- Same CPU board (minor differences)
Xevious (1982)   --+-- Physically different, logically identical
Dig Dug (1982)   --+-- Slightly different (dip switches via custom chip)
```

**Shared CPU architecture**:
- CPU 1 ("maincpu"): Main game logic
- CPU 2 ("sub"): Motion/AI CPU
- CPU 3 ("sub2"): Sound CPU

**Video boards are completely different** for each game -- that's why they have separate source files.

### 2.2 Triple-Z80 Communication Mechanism

From `galaga.h`:
```cpp
required_device<cpu_device> m_maincpu;   // "maincpu"
required_device<cpu_device> m_subcpu;    // "sub"
required_device<cpu_device> m_subcpu2;   // "sub2"
```

**Shared memory** (from galaga.cpp common memory map):

All three CPUs share a single address space from `0x6800` onwards:
```
0x6800-0x681F   Sound registers (Namco WSG)
0x6820-0x6827   LS259 latch (control bits):
  bit 0: IRQ1   - main CPU irq enable/acknowledge
  bit 1: IRQ2   - motion CPU irq enable/acknowledge
  bit 2: NMION  - sound CPU NMI enable
  bit 3: RESET  - reset sub and sound CPUs + custom chips
  bit 4-7: various game-specific
0x6830          Watchdog reset
0x7000-0x70FF   Custom 06XX (I/O interface to 5xXX chips)
0x7100          Custom 06XX control
0x7800-0x7FFF   Work RAM (NOT present in Galaga -- missing one RAM chip)
0x8000-0x87FF   Tilemap RAM (tile codes)
0x8800-0x8FFF   Tilemap RAM (tile attributes)
0x9000-0x90FF   Custom 06XX #2 (Bosconian only)
0x9800-0x980F   Bullet shape/position
0x9820          Playfield X scroll
0x9840          Playfield Y scroll
```

**Synchronization protocol**:
1. Main CPU writes to IRQ1/IRQ2/NMION latches to enable/disable interrupts on each CPU
2. RESET bit (bit 3) resets sub and sound CPUs AND all custom 5xXX chips on the CPU board
3. VBlank triggers interrupt to main CPU, which then decides whether to signal the others
4. Custom 08XX bus controllers (x3) arbitrate shared memory access

```cpp
void galaga_state::irq1_clear_w(int state) {
    // Main CPU IRQ enable/acknowledge
}
void galaga_state::irq2_clear_w(int state) {
    // Sub CPU IRQ enable/acknowledge
}
void galaga_state::nmion_w(int state) {
    // Sound CPU NMI enable
}
```

**Custom ICs per game**:

| Chip | Bosconian | Galaga | Xevious | Dig Dug |
|------|-----------|--------|---------|---------|
| 06XX | Interface to 5xXX | same | same | same |
| 07XX | Clock divider | same | same | same |
| 08XX x3 | Bus controller | same | same | same |
| 50XX | Score/protection | - | Score/protection | - |
| 51XX | I/O | I/O | I/O | I/O |
| 53XX | - | - | - | I/O (extra) |
| 54XX | Explosion sound | Explosion sound | Explosion sound | - |

### 2.3 How Tunneling Modifies VRAM (Dig Dug Specifics)

Dig Dug inherits from `galaga_state`:
```cpp
class digdug_state : public galaga_state { ... }
```

Dig Dug has a unique **background system** for the ground/tunnels:

**Background is NOT stored as regular tiles**. Instead:
- Background tile codes come from a **GFX ROM** (region "gfx4"), indexed by `m_bg_select` (2-bit selector for 4 background "pictures")
- The formula: `code = rom[tile_index | (m_bg_select << 10)]`
- Color: `color = m_bg_disable ? 0xf : (code >> 4)` -- when "disabled", color 0xF makes all pixels black
- Additional color bank: `m_bg_color_bank` (bits 4-5 of the bg_select register)

**Tunneling mechanics**:
When the player digs, the game writes to the **foreground (text) tilemap** via `digdug_videoram_w()`:
```cpp
void digdug_state::digdug_videoram_w(offs_t offset, uint8_t data) {
    m_videoram[offset] = data;
    m_fg_tilemap->mark_tile_dirty(offset & 0x3ff);
}
```

The foreground tilemap is transparent (pen 0 = transparent), drawn ON TOP of the background. Tunnel tiles are foreground tiles with specific codes that show "dug out" ground. The background continues to show the solid earth underneath. So the "digging" is done by placing transparent foreground tiles that reveal the background differently, or by placing specific tile codes that look like tunnels.

**Background select register** (`bg_select_w`):
```cpp
void digdug_state::bg_select_w(uint8_t data) {
    m_bg_select = data & 0x03;      // Select 1 of 4 background patterns
    m_bg_color_bank = data & 0x30;  // Color bank bits
    m_bg_tilemap->mark_all_dirty(); // Redraw everything
}
```

**Rendering order** (from `screen_update_digdug`):
```
1. Background tilemap (earth patterns from GFX ROM)
2. Foreground tilemap (text layer, tunnels -- transparent pen 0)
3. Sprites (Dig Dug character, Pookas, Fygars)
```

**Sprite system**: Uses 3 separate RAM regions:
- `m_digdug_objram`: Sprite code + color (at offset +0x380)
- `m_digdug_posram`: X/Y positions (at offset +0x380)
- `m_digdug_flpram`: Flip flags + size bit (at offset +0x380)

Sprites can be 16x16 (normal) or 32x32 (size bit set, using 4 sprite tiles arranged in a 2x2 grid).

**EAROM**: Dig Dug uniquely uses an ER2055 EAROM (electrically alterable ROM) for persistent high score storage.

### 2.4 Dig Dug Palette

32-entry palette PROM, same resistor network as Rally-X:
```
bit 7 -- 220 ohm -- BLUE
      -- 470 ohm -- BLUE
      -- 220 ohm -- GREEN
      -- 470 ohm -- GREEN
      -- 1k ohm  -- GREEN
      -- 220 ohm -- RED
      -- 470 ohm -- RED
bit 0 -- 1k ohm  -- RED
```

Two 256x4 color lookup table PROMs: one for characters, one for sprites.
A separate 256-entry PROM maps bg_select tiles to colors.

---

## 3. Tower of Druaga

### 3.1 Hardware: Mappy/Super Pac-Man Family

Tower of Druaga (1984) runs on the **Mappy hardware** (MAME: `src/mame/namco/mappy.cpp`). The CPU is a **Motorola 6809** (NOT Z80), which is a significant departure from earlier Namco hardware.

Key hardware specs:
- CPU: MC6809 main + MC6809 sub (sound)
- Sound: Namco WSG (8-voice wavetable)
- Video: 36x28 tile display (288x224 pixels), 8x8 tiles, hardware sprite support
- Custom ICs: similar to Pac-Man/Galaga family but evolved

Other games on same hardware: Mappy (1983), Super Pac-Man (1982), Pac & Pal (1983), Grobda (1984), Motos (1985).

### 3.2 Cultural Significance -- Druaga as Proto-Action-RPG

Tower of Druaga is widely cited as one of the most influential games in Japanese gaming history, particularly for its impact on the Action RPG and Action Adventure genres.

**Direct influence chain** (T7 -- Wikipedia, multiple blog sources):
- **Hydlide** (1984, T&E Soft): Creator Tokihiro Naito explicitly cited Druaga as inspiration. Hydlide combined Druaga's item-finding with overworld exploration.
- **Dragon Slayer** (1984, Nihon Falcom): Yoshio Kiya acknowledged Druaga. Dragon Slayer's dungeon-crawling maze format directly descends from it.
- **The Legend of Zelda** (1986, Nintendo): Shigeru Miyamoto admitted the initial Zelda prototype was "dungeon-only" -- very Druaga-like. The overworld was added later. Druaga's influence on Zelda is particularly visible in: hidden items requiring specific actions, dungeon floor progression, item-based progression.
- **Ys** (1987, Nihon Falcom): The bump-combat system was influenced by Druaga's simplified combat.
- **Dragon Quest** (1986, Enix): While more directly descended from Wizardry and Ultima, DQ's creators acknowledged the Japanese RPG lineage that Druaga helped establish.

**Key design innovation**: Druaga was arguably the first "RPG for the arcades" -- it introduced RPG mechanics (item collection, equipment progression, hidden secrets) into an arcade maze game format that demanded memorization and community knowledge-sharing.

**Academic references**:
- Rachael Hutchinson, *Japanese Culture Through Videogames* (Routledge, 2019) -- discusses Druaga in the context of Japanese game design evolution
- Heidelberg University publication (hasp.ub.uni-heidelberg.de) -- "Japan's Contemporary Media Culture" explicitly names "the arcade game The Tower of Druaga (Namco 1984; designed by [Masanobu Endo])" as influential
- Cambridge Companion to Video Game Music -- notes Druaga's soundtrack was included in the second game music album ever produced (by Haruomi Hosono of YMO)
- Wada, T. (2017) "History of Japanese Role-Playing Games" in *Annals of Business Administrative Science* 16(3) -- places Druaga in the JRPG origin lineage
- Game Developer article (2025): "Namco's 'role playing game for the arcades'" describing Druaga's world design influence

### 3.3 Hidden Items System

Tower of Druaga has **60 floors**, each containing one hidden treasure chest. The conditions to reveal each chest are **completely obscure** -- this was intentional design by Masanobu Endo, meant to foster arcade community collaboration in Japan.

**Item revelation conditions** (representative examples from StrategyWiki/GameFAQs):

| Floor | Item | Condition |
|-------|------|-----------|
| 1 | Copper Pickaxe | Kill all 3 Slimes |
| 2 | Jet Boots | Touch every wall in the maze |
| 3 | Silver Pickaxe | Kill 1 Slime while walking through a wall broken by the Copper Pickaxe |
| 5 | White Sword | Block 3 mage spells with shield while walking |
| 8 | Candle | Stand still for a few seconds after killing the Key Keeper |
| 13 | Silver Armor | Kill a Will O' Wisp |
| 18 | Book of Light | Open the exit door |
| 19 | Dragon Slayer | Complex multi-step sequence |
| 45 | Hyper Armor | Requires "Power" item from earlier floor |
| 58 | Blue Crystal Rod | Touch 3 invisible triggers in sequence |
| 59 | Special dragon (dies in one hit with Ruby Mace) | |
| 60 | Final boss Druaga | |

**Critical path items**: Some items are REQUIRED to reach the true ending. Missing certain floors' treasures makes the game unwinnable. The Blue Crystal Rod (floor 58) requires the most complex trigger sequence.

**Design philosophy**: The hidden item system was revolutionary but extremely hostile to solo players. In Japan, this created a collaborative arcade culture where players shared knowledge. Internationally, it was received with confusion. This design directly influenced later "guide dang it" game design and the concept of community-sourced game guides.

### 3.4 Sources for Druaga

- Full play guide: https://towerofdruaga.fandom.com/wiki/The_Tower_of_Druaga_Play_Guide
- Floor-by-floor walkthrough: https://strategywiki.org/wiki/The_Tower_of_Druaga/Walkthrough
- Item guide: https://gamefaqs.gamespot.com/arcade/584193-the-tower-of-druaga/faqs/36829
- Sylvie's illustrated guide: https://sylvie.website/Druaga.pdf
- Data Driven Gamer analysis: https://datadrivengamer.blogspot.com/2022/05/game-314-tower-of-druaga.html
- CRPG Addict coverage (2025): http://crpgaddict.blogspot.com/2025/06/brief-tower-of-druaga-1984.html
- RetroXP Substack analysis of Zelda lineage: https://retroxp.substack.com/p/past-meets-present-the-tower-of-druaga

---

## 4. Computer Archeology Project

**URL**: https://computerarcheology.com/Arcade/

### 4.1 Arcade Games Analyzed

The site has **full or partial disassemblies** of the following arcade games:

| Game | Completion | CPU | Maze-related? |
|------|-----------|-----|---------------|
| **Space Invaders** | Full | 8080 | No |
| **Asteroids** | 80% | 6502 | No |
| **Defender** | 75% | 6809 | No |
| **Moon Patrol** | 75% | Z80+6803 | No |
| **Phoenix** | 70% | 8085 | No |
| **Frogger** | Sound only + partial main | Z80 | Maze-adjacent (grid navigation) |
| **Galaga** | 5% | Z80x3 | No |
| **Crazy Climber** | 1% | Z80 | No |
| **Omega Race** | 10% | Z80 | No |
| **Time Pilot** | Sound + partial main | Z80 | No |
| **Sea Wolf** | 1% | 8080 | No |
| **Scramble** | 1% (sound only) | Z80 | No |

**Verdict**: NO dedicated maze game has a full disassembly on Computer Archeology. Frogger is the closest to maze-like gameplay but it's only partially done. Galaga at 5% is barely started. **Pac-Man, Rally-X, Dig Dug, and Tower of Druaga are all absent.**

The site also covers:
- **Atari 2600**: Asteroids, Battle Zone, Chess, Combat, Entombed, ET, BurgerTime, Missile Command, Space Invaders
- **CoCo**, **TRS-80**, **NES**, **Game Boy**, and more home systems

Notable: **Entombed** (Atari 2600) -- a maze generation game with a famously mysterious procedural algorithm that researchers have studied academically.

---

## 5. Awesome-Game-Decompilations List

**Source**: https://github.com/CharlotteCross1998/awesome-game-decompilations

### 5.1 Total Project Count

After scanning all 6 chunks of the README, I count approximately **500+ decompilation projects** total across all categories.

### 5.2 Categories

- **Pokemon**: ~30 projects (Red, Yellow, Gold, Crystal, Ruby, FireRed, Emerald, Diamond, Platinum, HeartGold, Black, Stadium 1&2, Mystery Dungeon, Pinball, TCG, Snap, XD, etc.)
- **Zelda**: ~12 (OOT, MM, WW, TMC, TP, PH, ST, SS, OOT3D, BotW, LA Switch)
- **Animal Crossing**: 3
- **Mario**: ~40+ (SM64, Sunshine, Galaxy 1&2, Odyssey, Paper Mario series, Mario Kart series, Mario Party 1-9, NSMB series, etc.)
- **Sonic**: ~15
- **Other**: ~400+ (alphabetical, everything from Advance Wars to Zuma Deluxe)

### 5.3 Maze-Related Games Found

Scanning the entire list for maze/dungeon-related titles:

| Game | URL | Relevance |
|------|-----|-----------|
| **Battle City** | NES disassembly | Tank maze game (maze-adjacent) |
| **Bomberman 64** | N64 decomp | Maze/grid-based gameplay |
| **Bomberman 64: Second Attack** | N64 decomp | Same |
| **Bomberman Hero** | N64 decomp | Same |
| **BurgerTime** | Atari 2600 | Platform/maze hybrid |
| **Castlevania: SotN** | PS1 | Metroidvania (maze-like maps) |
| **Cave Story** | Decompilation | Platform/maze exploration |
| **Diablo** | `diasurgical/devilution` | Dungeon/maze generation |
| **Frogger (1997)** | PS1 | Grid navigation |
| **Pac-Man** | **NOT PRESENT** | -- |
| **Rally-X** | **NOT PRESENT** | -- |
| **Dig Dug** | **NOT PRESENT** | -- |
| **Tower of Druaga** | **NOT PRESENT** | -- |
| **Ms. Pac-Man** | **NOT PRESENT** | -- |
| **Gauntlet Dark Legacy** | Decomp | Dungeon maze |
| **Gauntlet Legends** | Decomp | Dungeon maze |
| **MediEvil** | PS1 | Dungeon exploration |
| **Quest 64** | N64 | RPG dungeon |
| **ShortLine** | `konovalov-aleks/reSL` | -- |
| **SkiFree** | Decomp | -- |
| **Space Cadet Pinball** | Decomp | -- |
| **Contra** | NES disassembly | -- |

**Critical finding**: None of the classic arcade maze games (Pac-Man, Ms. Pac-Man, Rally-X, Dig Dug, Tower of Druaga, Pengo, Mr. Do!, Lode Runner) appear in the awesome-game-decompilations list. This represents a **major gap** -- these 1980-1984 arcade titles are completely unrepresented.

The list is heavily weighted toward Nintendo console games (N64, GC, Wii, GBA, DS) and modern indie games. Classic arcade Z80 games are essentially absent.

---

## 6. Modern Reverse Engineering Toolkit for Arcade ROMs

### 6.1 Disassemblers with Z80 Support

| Tool | Type | Z80? | Notes |
|------|------|------|-------|
| **Ghidra** | NSA open-source RE framework | YES | Full Z80 processor module. Free, cross-platform, extensible. Best option for 2024-2026. |
| **IDA Pro / IDA Free** | Commercial (free tier available) | YES | Industry standard. Free tier now includes decompiler. |
| **radare2 / rizin + Cutter** | Open-source | YES | CLI + GUI (Cutter). Scriptable. |
| **DeZog** | VS Code extension | YES | Specifically designed for Z80/ZX Spectrum/MAME. **Best tool for arcade Z80 specifically.** https://github.com/maziac/DeZog |
| **Spectrum Analyser** | Web-based emulator+debugger | YES | ZX Spectrum specific but useful for Z80 understanding. https://colourclash.co.uk/spectrum-analyser/ |
| **JC64dis** | Interactive disassembler | YES (via Glass assembler) | Designed for retro platforms |
| **z80dasm** | CLI Z80 disassembler | YES | Simple, lightweight |

### 6.2 MAME Debugger

MAME has a **built-in debugger** that is the single most powerful tool for arcade ROM reverse engineering. Start MAME with `-debug` flag.

Key features:
- Step-through execution, breakpoints, watchpoints
- Memory view, disassembly view
- **Lua scripting** for automation (since MAME 0.148+)
- Trace execution to file
- Cheat engine integration

**Tutorials found**:
- **"Use MAME's debugger to reverse engineer and extend old games"** (dorkbotpdx.org, 2013): https://dorkbotpdx.org/blog/skinny/use_mames_debugger_to_reverse_engineer_and_extend_old_games/
- **"Rom Hacking with MAME"** (YouTube, 2019): https://www.youtube.com/watch?v=0_SHeboSuWs
- **"Mame Debugger Tutorial"** (YouTube, 2019): https://www.youtube.com/watch?v=torId4RvFGY
- **"Neo Geo ROM Hacking Guide"** (mattgreer.dev, 2024): https://www.mattgreer.dev/blog/neo-geo-rom-hacking-guide-part-1/ -- particularly praises MAME's Lua scripting
- **MAME official docs**: https://docs.mamedev.org/_files/MAME.pdf (chapter 8: Debugger)

### 6.3 Recommended Modern Workflow for Arcade RE

1. **Start in MAME debugger**: Run the game with `-debug`, set breakpoints on known I/O addresses (from MAME driver source), trace execution paths.

2. **Export traces**: Use MAME's trace command to dump execution flow to files.

3. **Static analysis in Ghidra**: Load the ROM binary, select Z80 processor, define the memory map from MAME source comments (which are extremely well-documented as we've seen).

4. **Cross-reference with MAME source**: The MAME driver IS the Rosetta Stone. Files like `rallyx.cpp` contain complete memory maps, I/O register definitions, and hardware behavior -- all painstakingly reverse-engineered over decades.

5. **DeZog for interactive debugging**: If targeting a specific Z80 game, DeZog in VS Code provides a modern IDE experience with MAME backend support.

6. **Document with Computer Archeology format**: HTML pages with annotated disassembly, RAM maps, graphics breakdowns.

### 6.4 Key Insight

**The MAME source code IS the primary reverse engineering artifact for arcade games.** The ~20 years of MAME development has produced the most comprehensive arcade hardware documentation ever assembled. For any game with a MAME driver, the driver source provides:
- Complete memory maps
- I/O register descriptions
- Custom chip behavior
- Timing and interrupt details
- Color PROM formats
- Sprite/tilemap specifications

The remaining gap is from hardware documentation to **game logic disassembly** -- understanding not just what the hardware does, but what the game code running on it does.

---

## 7. Spelunky Level Generation

### 7.1 Darius Kazemi's Interactive Generator

**URL**: https://tinysubversions.com/spelunkyGen/ (Part 1) + https://tinysubversions.com/spelunkyGen2 (Part 2)

This is a **working, modded copy of Spelunky Classic** (GameMaker HTML5 export) that visualizes the level generation algorithm step by step.

### 7.2 The Algorithm (Step by Step)

**Phase 1: Solution Path Generation** (Part 1)

The level is a **4x4 grid of rooms** (16 rooms total). Each room is one of these types:

| Type | Guaranteed exits |
|------|------------------|
| 0 | None (side room, NOT on solution path) |
| 1 | Left + Right |
| 2 | Left + Right + Bottom (+ Top if above another type 2) |
| 3 | Left + Right + Top |

**Algorithm**:

```
1. Place a START room in a random column of the top row (row 0).
   It is initially type 1 or 2 (special case).

2. Every placed room starts as type 1 (left/right exits).

3. Pick random direction:
   - Random 1-5:
     - 1 or 2 -> move LEFT
     - 3 or 4 -> move RIGHT
     - 5      -> move DOWN

4. If moving LEFT or RIGHT:
   - Room stays type 1 (already has L/R exits).
   - If hitting screen edge: DROP DOWN instead, reverse L/R direction.

5. If moving DOWN:
   - Override current room to type 2 (must have bottom exit).
   - Move to room below.

6. After moving to new room:
   - If previous room was type 2 (we came from above):
     - New room MUST be type 2 (continue dropping) or type 3 (upside-down T).
     - Both have L/R exits, so we can resume the algorithm.

7. If on bottom row and trying to drop:
   - Place EXIT room instead of dropping.

8. All grid spaces NOT on the solution path:
   - Fill with random type 0 rooms (no guaranteed exits -- may be walled off).

9. Snake pit check:
   - If 3-4 type 0 rooms form a vertical line:
     - Chance to become a snake pit.
     - Uses room types 7, 8, 9 (or 7, 8, 8, 9 for depth 4).
     - Snakes and jewels are placed manually as part of landscape.
```

**Phase 2: Room Interior Layout** (Part 2)

Each room type has multiple possible room templates. The template selection adds:
- Spike placements
- Ladder/pit formations
- Platforms
- Arrow traps
- Enemies (random placement within constraints)
- Treasure (random placement)

**Key design insight**: The solution path guarantees reachability WITHOUT special items. The player can always reach the exit. Side rooms (type 0) may require bombs or ropes to access, providing optional exploration.

### 7.3 PCMag Summary (2020)

> "The algorithm constructs a path between the entrance and the exit, and then starts adding detail to the individual rooms along the way. Each 'room' in the game is really a 10-by-8-tile space."

### 7.4 Academic/Community References

- Derek Yu's book *Spelunky* (Boss Fight Books, 2016) -- the definitive source, written by the game's creator
- Darius Kazemi's interactive visualization (2008): http://tinysubversions.com/spelunkyGen/
- GDC 2015 talk by David Pittman on Eldritch: references Spelunky generator as benchmark
- Academic paper (ACM, 2025): "Towards a Celeste AI Framework" cites Kazemi's work

---

## Summary of Gaps and Opportunities

### Arcade Maze Games with NO Existing Decompilation/Disassembly

| Game | Year | CPU | MAME Driver | Computer Archeology | awesome-decomps |
|------|------|-----|-------------|--------------------:|:---------------:|
| **Pac-Man** | 1980 | Z80 | YES (pacman.cpp) | NO | NO |
| **Rally-X** | 1980 | Z80 | YES (rallyx.cpp) | NO | NO |
| **New Rally-X** | 1981 | Z80 | YES (rallyx.cpp) | NO | NO |
| **Dig Dug** | 1982 | Z80x3 | YES (galaga.cpp+digdug.cpp) | NO | NO |
| **Pengo** | 1982 | Z80 | YES (pengo.cpp) | NO | NO |
| **Mr. Do!** | 1982 | Z80 | YES (mrdo.cpp) | NO | NO |
| **Lode Runner** | 1983 | Z80 | YES | NO | NO |
| **Tower of Druaga** | 1984 | 6809 | YES (mappy.cpp) | NO | NO |
| **Gauntlet** | 1985 | 68010 | YES | NO | NO |
| **Solomon's Key** | 1986 | Z80 | YES | NO | NO |

### Most Feasible Decompilation Targets

Ranked by complexity (easiest first):

1. **Pac-Man** -- Single Z80, tiny ROM (16KB), extremely well-documented hardware, multiple partial disassemblies exist online (though not in any curated list). Best first target.

2. **Rally-X** -- Single Z80, similar complexity to Pac-Man, fully documented memory map in MAME. The dual-tilemap architecture is interesting but not complex.

3. **Pengo** -- Single Z80, based on Pac-Man/Sega hardware. Very manageable.

4. **Mr. Do!** -- Single Z80, simple video hardware.

5. **Tower of Druaga** -- 6809 (not Z80), more complex game logic (60 floors, items, enemies, AI). Medium difficulty.

6. **Dig Dug** -- Triple Z80 architecture makes this significantly harder. Need to trace communication between 3 CPUs. Hard but not impossible.

7. **Gauntlet** -- 68010 + 6502, tilemap hardware, much larger ROMs. Serious project.
