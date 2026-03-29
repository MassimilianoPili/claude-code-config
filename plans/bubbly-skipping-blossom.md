# Plan: Retro Game #77 — "Crypt of Echoes" Game Boy ROM

## Context

Task #77. Build a Game Boy roguelike ROM in SM83 assembly using RGBDS v1.0.1. 32KB no-mapper. Procedural dungeons, bump-to-attack combat, 4 enemy types, items, permadeath. The entire program fits in an LLM context window — a thesis with **no peer-reviewed precedent** (literature gap confirmed by research).

Full design doc: `/data/massimiliano/progetti_futuri/PIANO_RETRO_GAME.md`
Full research: `/home/massimiliano/.claude/plans/bubbly-skipping-blossom-agent-a82661150d0985aa2.md`

## Local Reference Material: `/data/massimiliano/retro-decomps/` (3.3GB)

**Direct references for Crypt of Echoes:**
- `gb/tetris/` — Same platform, same toolchain (RGBDS), 32KB ROM. Minimal reference.
- `gb/pokered/` — RGBDS assembly, VBlank/OAM DMA/joypad patterns directly reusable.
- `gb/LADX-Disassembly/` — Zelda Link's Awakening: dungeon maps, room transitions, combat.
- `gba/pmd-red/` — **Pokémon Mystery Dungeon**: roguelike dungeon gen, turn-based combat, enemy AI. Most relevant game mechanically (GBA, not GB, but logic is transferable).

**To clone (roguelike-critical, not yet on disk):**
- `forestbelton/azure` — Azure Dreams GBC: tower roguelike, procedural floors. **Most relevant.**
- `NiyaDev/DWM` — Dragon Warrior Monsters GBC: random dungeon gen + monster breeding
- `pret/pmd-sky` — PMD Explorers of Sky DS: extensive dungeon gen code
- `pret/poketcg2` — Pokemon TCG 2 GBC (sequel to existing poketcg)
- `aldonunez/zelda1-disassembly` — Zelda 1 NES: dungeon structure, item progression
- `nmikstas/dragon-warrior-disassembly` — Dragon Warrior NES: tile-based JRPG mechanics

Full clone list (~130 repos): `/home/massimiliano/.claude/plans/bubbly-skipping-blossom-agent-a341bf0cc9e86733d.md`

**Study before coding:**
1. `gb/pokered/` — OAM DMA routine, VBlank handler, joypad code, tilemap loading
2. `gb/tetris/` — Minimal 32KB ROM structure, RNG, game loop
3. `gba/pmd-red/` — Dungeon generation algorithm, turn system, enemy AI patterns
4. `azure` (once cloned) — Tower roguelike floor gen, combat, items on same platform

## Research-Informed Changes from Original Plan

1. **RGBDS v1.0.1** (not apt) — install pre-built binary from GitHub releases. Apt has stale 0.9.3.
2. **Use `rgbgfx`** (built into RGBDS) — replaces custom `png2gb.py` for asset conversion.
3. **Emulicious** as primary emulator — has VS Code extension for source-level symbolic debugging with `.sym` files. BGB as secondary (Wine).
4. **Tunneling algorithm** for dungeons (not BSP) — room placement + L-corridors, ~500 bytes, <1 frame gen time. Simpler than BSP, no recursion stack needed.
5. **32x32 map** in WRAM (1KB) — packed byte: bits 0-3 tile type, bits 4-5 visibility, bit 6 has_item, bit 7 has_entity.
6. **Use `ldh` not `ldio`** — `ldio` removed in RGBDS v1.0.0.
7. **OAM shadow buffer must be 256-byte aligned** at $C000.
8. **Reference repos**: Porklike GB (binji), Tobu Tobu Girl (RGBDS patterns), Cave Noire (commercial GB roguelike).
9. **ROM budget**: ~19KB estimated, ~13KB headroom. Comfortable.
10. **Tilemap Studio** (Rangi42) for visual map editing if needed.

## Implementation Steps

### Step 0: Clone ~130 new decomp repos
- Extract clone script from research file into `/data/massimiliano/retro-decomps/clone-decomps.sh`
- Run batch clone, organized by platform subdirs (gb/, gba/, nes/, snes/, genesis/, n64/, ds/, psx/, gc/)
- Source: `/home/massimiliano/.claude/plans/bubbly-skipping-blossom-agent-a341bf0cc9e86733d.md` (lines 318-488)
- Priority clones for roguelike reference: azure (GBC), DWM (GBC), pmd-sky (DS), zelda1 (NES)

### Step 1: Toolchain setup
- Download RGBDS v1.0.1 pre-built Linux binary → `/usr/local/bin/`
- Install Emulicious (Java) or confirm SameBoy available
- Create `/data/massimiliano/retro-game-gb/` project dir
- Create `Makefile`: `rgbasm` → `rgblink` (with `-m game.map -n game.sym`) → `rgbfix`
- Build minimal "hello world" ROM (blank screen, valid header)
- Init Gitea repo `retro-game-gb`

### Step 2: Hardware foundation
- `src/hardware.inc` — SM83 register constants from Pan Docs
- `src/header.asm` — Nintendo logo, title "CRYPTECHOES", MBC type $00 (no mapper), ROM size 32KB
- `src/main.asm` — entry point at $0150, LCD off, copy OAM DMA to HRAM, init WRAM, enable VBlank interrupt, main loop with `halt`

### Step 3: Rendering + input engine
- OAM DMA routine in HRAM ($FF80), shadow OAM at $C000 (page-aligned)
- VBlank handler: call OAM DMA, read joypad (double-read for stability), set vblank flag
- Tileset: create minimal 2bpp tiles (wall, floor, door, stairs, player) — use `rgbgfx` to convert
- Background tilemap loading from WRAM map buffer
- Sprite rendering for player (OAM entry 0)
- D-pad → grid-based movement with wall collision

### Step 4: Dungeon generation
- `src/dungeon.asm` — tunneling algorithm:
  1. Fill map with walls
  2. Place 3-6 random rooms (4×4 to 8×6)
  3. Connect rooms with L-shaped corridors
  4. Place stairs in last room
  5. Place player in first room
- `src/utils.asm` — 16-bit Galois LFSR (polynomial $B400), seeded from rDIV
- WRAM: 32×32 map at $C100 (1KB)
- Floor transition: regenerate map on stairs

### Step 5: Combat + enemies
- `src/enemies.asm` — entity array in WRAM (max 8, 8 bytes each at $C500)
  - 4 types: Rat (random), Bat (erratic), Skeleton (chase), Ghost (wall-pass)
- `src/combat.asm` — bump-to-attack: `max(1, ATK - DEF) + rng(0,2)`
- Player stats in WRAM: HP, ATK, DEF, floor, pos_x, pos_y
- HUD: HP bar + floor number on window layer or top row
- Game over screen on HP ≤ 0, restart on START

### Step 6: Items
- Potion (+5 HP), Key (opens doors), Sword (+1 ATK), Shield (+1 DEF)
- Pickup on walk-over, inventory = counters in HUD

### Step 7: Audio (stretch)
- Minimal SFX: hit (noise channel), pickup (pulse ch1), stairs (pulse ch2)
- Title screen jingle (stretch)

## Key Files

| File | Purpose |
|------|---------|
| `/data/massimiliano/retro-game-gb/Makefile` | RGBDS build: asm → link → fix |
| `src/hardware.inc` | SM83 hardware register constants |
| `src/header.asm` | ROM header (logo, title, MBC $00) |
| `src/main.asm` | Entry, VBlank, game loop state machine |
| `src/render.asm` | Tilemap load, OAM DMA, HUD |
| `src/player.asm` | Input, movement, collision |
| `src/dungeon.asm` | Tunneling procedural gen |
| `src/enemies.asm` | Entity table, AI, spawn |
| `src/combat.asm` | Bump-to-attack, damage calc |
| `src/items.asm` | Items, pickup, inventory |
| `src/utils.asm` | LFSR RNG, math helpers |
| `res/tiles.png` | Tileset source (→ rgbgfx → .2bpp) |
| `res/sprites.png` | Sprite sheet (→ rgbgfx → .2bpp) |

## WRAM Map ($C000-$DFFF)

```
$C000-$C09F  Shadow OAM (160 bytes, page-aligned)
$C0A0-$C0AF  Joypad state (held, new), frame counter, game state
$C0B0-$C0BF  Player stats (HP, ATK, DEF, pos_x, pos_y, floor, keys)
$C0C0-$C0FF  Reserved
$C100-$C4FF  Dungeon map 32×32 (1024 bytes, packed)
$C500-$C53F  Enemy table (8 enemies × 8 bytes)
$C540-$C55F  Item table (8 items × 4 bytes)
$C560-$C5FF  Room table (6 rooms × 6 bytes + scratch)
$C600-$CDFF  General scratch
$CE00-$CFFF  Stack (512 bytes, grows down from $CFFF)
```

## ROM Size Budget (32KB = 32,768 bytes)

| Component | Est. bytes |
|-----------|-----------|
| Header + vectors | 336 |
| Core engine (VBlank, OAM, input, render) | 2,048 |
| Dungeon generator | 512 |
| Game logic (player, combat, AI, items) | 4,096 |
| HUD + menus + text | 3,072 |
| Tile data (2bpp, ~128 tiles) | 2,048 |
| Sprite data (2bpp, ~32 sprites) | 512 |
| Font (96 chars) | 1,536 |
| Data tables (enemies, items, strings) | 1,024 |
| Audio driver + SFX | 1,024 |
| **Total** | **~16KB** |
| **Headroom** | **~16KB** |

## Documentation Updates (post-build)
- Update MEMORY.md: add retro-game-gb project entry + retro-decomps collection (~170 repos)
- Update KORE (graph_write): add retro-game-gb as DockerService or Project node
- RGBDS v1.0.1 installed in `shell-scripts/bin/` (rgbasm, rgblink, rgbfix, rgbgfx)
- retro-decomps/clone-decomps.sh: batch clone script for ~130 repos

## Verification

- `make` produces `crypt_of_echoes.gb` without errors
- `rgbfix -v` confirms valid header and checksum
- ROM ≤ 32KB, MBC type $00
- Boots on Emulicious/SameBoy: title → dungeon rendered
- `.sym` file loads in Emulicious for symbolic debugging
- D-pad moves player on grid, walls block
- Dungeons regenerate differently each floor (LFSR seed)
- Bump-to-attack kills enemies, enemies damage player
- HP=0 → game over → START restarts
- Gitea repo created with CI (optional: build on tag)
