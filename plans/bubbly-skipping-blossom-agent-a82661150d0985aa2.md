# Research: Game Boy Homebrew Roguelike — "Crypt of Echoes"

## Research Summary

### Executive Summary

Building a 32KB no-mapper Game Boy roguelike in Z80 (SM83) assembly using RGBDS is a well-supported path in 2026. RGBDS just reached its **v1.0.0 milestone** (2025-11-01), the toolchain is the undisputed standard, documentation (Pan Docs) is excellent, and a thriving homebrew competition scene (gbcompo25) keeps producing reference implementations. Procedural dungeon generation on GB is rare but feasible within 8KB WRAM — drunkard's walk and cellular automata are the recommended algorithms. The 32KB ROM constraint is tight but historically proven (the original Tetris, Dr. Mario, and many early GB titles fit in 32KB). The LLM-assisted development thesis is original and compelling: the entire ROM fits in context, enabling global reasoning impossible with larger codebases.

**Epistemic status:** Strong consensus on tooling and patterns. Limited evidence on GB-specific roguelike dungeon gen (niche intersection). AI-assisted retro assembly is bleeding-edge with only anecdotal reports.

**Confidence:** High for tooling/practices (T7 -- gbdev.io, verified GitHub API). Medium for dungeon gen algorithms (community knowledge, no papers). Low for AI-assisted assembly (T5 -- blog posts, no systematic evaluation).

---

## 1. RGBDS Toolchain State (2025-2026)

### Current Version: v1.0.1 (2026-01-01)

**Verified via GitHub API** (`api.github.com/repos/gbdev/rgbds/releases/latest`):

- **v1.0.0** released 2025-11-01 -- the first stable release with semantic versioning commitment
- **v1.0.1** released 2026-01-01 -- bugfix only (no breaking changes)
- Repository: 1,584 stars, 181 forks, actively maintained (last push: 2026-03-28)
- License: MIT
- Written in C++, topics: `assembly-sm83`, `game-boy`, `gbdev`
- Homepage: https://rgbds.gbdev.io

### Components

| Tool | Purpose |
|------|---------|
| `rgbasm` | Assembler (SM83 assembly to object files) |
| `rgblink` | Linker (object files to ROM) |
| `rgbfix` | Checksum/header fixer |
| `rgbgfx` | PNG-to-Game Boy 2bpp graphics converter |

### Breaking Changes in v1.0.0

The v1.0.0 release removed several long-deprecated features:

- **Removed:** `ldio [c], a` / `ldio a, [c]` -- use `ldh [c], a` / `ldh a, [c]`
- **Removed:** `ldh [$xx], a` -- must use full `ldh [$FFxx], a`
- **Removed:** Multi-character string-as-number without explicit `CHARVAL`
- **Removed:** `SECTION UNION` for ROM sections
- **Deprecated (still works):** 1-indexed string functions (`STRIN`, `STRRIN`, `STRSUB`, `CHARSUB`) -- use 0-indexed replacements
- **Added:** Colorful terminal output, `===`/`!==` string comparison, `::` for joining directives, at-file support (`@args.flags`)
- **Semver commitment:** Future breaking changes require major version bump

### Installation on Ubuntu 24.04

Three options, ranked by preference:

**Option A -- Pre-built binary (recommended):**
```bash
# Download from GitHub releases
wget https://github.com/gbdev/rgbds/releases/download/v1.0.1/rgbds-linux-x86_64.tar.xz
tar xf rgbds-linux-x86_64.tar.xz
sudo cp rgbasm rgblink rgbfix rgbgfx /usr/local/bin/
```

**Option B -- Debian package:**
The Debian ITP (#984927) shows RGBDS was packaged as version 0.9.3 for Debian unstable. Ubuntu 24.04 may have an older version via `apt install rgbds`. **Warning:** This will be significantly behind the 1.0.x release. Not recommended.

**Option C -- Build from source:**
```bash
sudo apt install build-essential cmake libpng-dev
wget https://github.com/gbdev/rgbds/releases/download/v1.0.1/rgbds-source.tar.gz
tar xf rgbds-source.tar.gz && cd rgbds-1.0.1
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
sudo cmake --install build
```

### Is RGBDS Still the Recommended Toolchain?

**Yes, unequivocally.** No competitor has emerged. The alternatives are:

| Toolchain | Status | Use case |
|-----------|--------|----------|
| **RGBDS** | v1.0.1, actively maintained | Assembly development (recommended) |
| **GBDK-2020** | Active, Dec 2025 docs | C development (uses SDCC backend, links with RGBDS) |
| **GB Studio** | Active | Visual/no-code game maker (not for custom assembly) |
| **WLA-DX** | Maintained | Alternative assembler (less community support) |

For a pure assembly roguelike, RGBDS is the only serious choice. GBDK-2020 uses SDCC for C compilation but can interoperate with RGBDS-assembled modules. For "Crypt of Echoes" in pure assembly, RGBDS is correct.

### Key Reference: "Game Boy Coding Adventure" (No Starch Press)

A new book by Maximilien Dagois: *Game Boy Coding Adventure: Learn Assembly and Master the Original 8-Bit Handheld*. Uses RGBDS and BGB throughout. Published recently (found in search results from No Starch, Penguin Random House, Barnes & Noble). This is likely the most current printed reference for RGBDS assembly development.

---

## 2. Game Boy Homebrew Best Practices (2024-2026)

### VBlank-Safe Rendering

The PPU (Pixel Processing Unit) restricts VRAM access. The standard pattern:

```asm
; Wait for VBlank interrupt
WaitVBlank:
    halt        ; Low-power wait for any interrupt
    nop         ; Safety NOP after HALT (hardware errata on DMG)
    ld a, [rIF]
    and IEF_VBLANK
    jr z, WaitVBlank
    ; Now safe to write to VRAM for ~1140 M-cycles (~4560 dots)
```

**Best practice (Pan Docs consensus):**
- Use VBlank interrupt handler to copy shadow OAM and update tiles
- Buffer all VRAM writes in WRAM, copy during VBlank
- Keep VBlank handler under ~1140 M-cycles (mode 1 lasts ~4560 T-cycles)
- For large VRAM updates, use LCD STAT interrupt to also write during HBlank (mode 0)
- Never busy-wait on `rLY == 144` -- use `halt` + interrupt flag check

### OAM DMA Setup

OAM DMA transfers 160 bytes from a source address to OAM ($FE00-$FE9F) in 160 M-cycles. The DMA routine must run from HRAM because the bus is locked during transfer:

```asm
SECTION "OAM DMA Routine", ROM0
InitOAMDMA:
    ld hl, OAMDMA         ; HRAM destination
    ld bc, OAMDMAEnd - OAMDMA
    ld de, .routine
.copy:
    ld a, [de]
    ld [hl+], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .copy
    ret

.routine:
    ld a, HIGH(wShadowOAM)  ; Source address high byte ($C0 if shadow OAM at $C000)
    ldh [rDMA], a            ; Start DMA
    ld a, 40                 ; Wait 160 M-cycles (40 iterations x 4 cycles)
.wait:
    dec a
    jr nz, .wait
    ret
OAMDMAEnd:

SECTION "Shadow OAM", WRAM0, ALIGN[8]
wShadowOAM: ds 160          ; Must be page-aligned ($XX00)
```

**Key constraints:**
- Shadow OAM buffer must be 256-byte aligned in WRAM
- DMA routine must reside in HRAM ($FF80+)
- Copy the DMA routine to HRAM once during init, call via `call OAMDMA` in VBlank

### Joypad Input Handling

```asm
; Read joypad, returning both held and newly-pressed buttons
ReadJoypad:
    ; Read D-pad
    ld a, P1F_GET_DPAD
    ldh [rP1], a
    ldh a, [rP1]    ; Read twice for signal stability
    ldh a, [rP1]
    cpl              ; Buttons are active-low
    and $0F
    swap a
    ld b, a

    ; Read buttons
    ld a, P1F_GET_BTN
    ldh [rP1], a
    ldh a, [rP1]
    ldh a, [rP1]
    ldh a, [rP1]    ; Extra reads for stability on DMG
    ldh a, [rP1]
    cpl
    and $0F
    or b
    ld b, a          ; B = currently held buttons

    ; Detect new presses (transition from 0 to 1)
    ld a, [wJoypadState]
    xor b            ; Changed bits
    and b            ; Only newly pressed
    ld [wJoypadNew], a
    ld a, b
    ld [wJoypadState], a

    ; Reset joypad
    ld a, P1F_GET_NONE
    ldh [rP1], a
    ret
```

**Best practice:** Read joypad once per frame in VBlank handler. Store both held state and new-press state. The double/quadruple read of `rP1` is necessary for electrical stability.

### Memory Layout Conventions (32KB No-Mapper)

```
ROM Layout (32KB = $0000-$7FFF):
  $0000-$00FF  RST vectors + Interrupt vectors
  $0100-$014F  Header (logo, title, checksums)
  $0150-$3FFF  ROM Bank 0 (fixed, ~16KB usable)
  $4000-$7FFF  ROM Bank 1 (fixed, no mapper = always bank 1)

WRAM Layout ($C000-$DFFF, 8KB):
  $C000-$C09F  Shadow OAM (160 bytes, page-aligned)
  $C0A0-$C0FF  Joypad state, frame counter, misc globals
  $C100-$C4FF  Dungeon map buffer (e.g., 32x32 = 1024 bytes)
  $C500-$C8FF  Entity table (monsters, items)
  $C900-$CBFF  RNG state, pathfinding scratch, FOV buffer
  $CC00-$CDFF  General scratch / stack overflow area
  $CE00-$CFFF  Stack (growing downward from $CFFF)
  $D000-$DFFF  Second WRAM bank (additional 4KB on CGB, mirrorable on DMG)

HRAM Layout ($FF80-$FFFE, 127 bytes):
  $FF80-$FF8F  OAM DMA routine (~10 bytes)
  $FF90-$FF9F  Frequently-accessed variables (frame counter, etc.)
  $FFA0-$FFFE  Additional fast-access variables
```

**32KB no-mapper constraints:**
- Total usable ROM after header: ~32,430 bytes
- No bank switching -- all code and data must fit in $0150-$7FFF
- WRAM is the bottleneck: 8KB total for everything (map, entities, stack, shadow OAM)
- HRAM is precious: 127 bytes, but fastest access (`ldh` = 2 M-cycles vs `ld` = 4)
- For a roguelike, the map buffer dominates WRAM usage

### ROM Banking vs No-Mapper

For 32KB, no mapper is required -- the ROM maps directly to $0000-$7FFF as two fixed 16KB banks. This simplifies everything:
- No `SECTION "Name", ROMX, BANK[n]` directives needed
- All code/data accessible at all times (no bank switching overhead)
- Linker configuration is simpler
- The trade-off: everything must fit in ~32KB, requiring aggressive code size optimization

**Recommendation for Crypt of Echoes:** Start with no-mapper (MBC type = $00 in header). If you run out of space, MBC1 with 64KB (4 banks) is the simplest upgrade path, adding only a few bytes of bank-switching code.

---

## 3. Procedural Dungeon Generation on Game Boy

### The Constraint

- 8KB WRAM total
- Dungeon map buffer: if each tile is 1 byte, a 32x32 map = 1KB, 20x18 (one screen) = 360 bytes
- CPU: ~1M instructions/second (4.19 MHz / ~4 cycles average)
- No floating point, no division instruction (must implement in software)
- 8-bit ALU, 16-bit address operations only

### Algorithms Ranked by GB Feasibility

**1. Drunkard's Walk / Random Walk (RECOMMENDED)**
- Complexity: O(n) where n = number of steps
- Memory: Map buffer only (1KB for 32x32)
- Implementation: Trivially simple in assembly -- pick random direction, carve floor tile, repeat
- Tuning: Number of steps controls map density. Multiple walkers for variety.
- **GB suitability: Excellent.** Under 100 bytes of code, runs in <1 frame

**2. Cellular Automata (cave generation)**
- Complexity: O(w*h*iterations), typically 4-5 iterations
- Memory: Needs two buffers (current + next state) = 2KB for 32x32
- Implementation: For each cell, count 8 neighbors, apply birth/death rules
- **GB suitability: Good.** ~200 bytes of code. 2 frames for a 32x32 map with 4 iterations.
- Produces organic cave-like levels, good for a crypt theme

**3. BSP (Binary Space Partitioning)**
- Complexity: O(n log n) splits + room placement
- Memory: Needs a tree structure (~8 bytes per node, ~30 nodes = 240 bytes) + map buffer
- Implementation: Recursive splitting is natural but stack-heavy on GB (limited stack)
- **GB suitability: Moderate.** Convert recursion to iteration using explicit stack in WRAM. ~400 bytes of code.
- Produces classic rectangular rooms connected by corridors

**4. Tunneling Algorithm (room placement + corridors)**
- Place N random non-overlapping rooms, connect sequentially with L-shaped corridors
- Memory: Room list (~6 bytes each * 8 rooms = 48 bytes) + map buffer
- **GB suitability: Good.** Simpler than BSP, similar results.

**5. Wave Function Collapse / constraint-based**
- **GB suitability: Poor.** Too memory-intensive and computationally expensive.

### LFSR-Based RNG for Game Boy

A 16-bit Linear Feedback Shift Register is the standard GB PRNG:

```asm
; 16-bit Galois LFSR (period 65535)
; Uses taps at bits 16, 14, 13, 11 (polynomial $B400)
Random:
    ld a, [wRNGState]
    ld l, a
    ld a, [wRNGState+1]
    ld h, a
    ; Shift right
    srl h
    rr l
    jr nc, .noTap
    ; XOR with polynomial
    ld a, h
    xor $B4
    ld h, a
.noTap:
    ld a, l
    ld [wRNGState], a
    ld a, h
    ld [wRNGState+1], a
    ret     ; Random byte in A (low byte of state)
```

Seed from `rDIV` (hardware timer) at title screen input.

### Existing GB Roguelike Dungeon Generation Implementations

**Found (limited evidence):**

1. **Reddit r/roguelikedev thread (2018)**: A developer reported experimenting with a Game Boy Color roguelike using procedural generation. The community recommended drunkard's walk and cellular automata as the most GB-feasible approaches. (T7 -- Reddit community discussion)

2. **Porklike GB** (binji, itch.io): A port of the PICO-8 roguelike "Porklike" to Game Boy using GBDK. Open source. This is the closest reference implementation found. Uses simple room-based generation. **URL:** https://binji.itch.io/porklikegb (T7 -- itch.io)

3. **GBISAAC** (JOSHUA ROBERTSON, itch.io): A Game Boy demake of The Binding of Isaac, built for GBJam8. Includes procedural room layouts. **URL:** https://jrob774.itch.io/the-binding-of-isaac-gbjam8-edition (T7 -- itch.io)

### Recommended Approach for Crypt of Echoes

Given the 32KB ROM / 8KB WRAM constraint, I recommend a **hybrid approach**:

1. **Map representation:** 32x32 grid, 1 byte per tile = 1KB WRAM
   - Bit 0-3: tile type (wall, floor, door, stairs, water, etc. -- 16 types)
   - Bit 4-5: visibility state (unseen, seen, visible)
   - Bit 6: has item
   - Bit 7: has entity

2. **Generation algorithm:** Tunneling (room placement + corridors)
   - Place 3-6 rooms (random size 4x4 to 8x6)
   - Connect with L-shaped corridors
   - Scatter items and enemies
   - Total code: ~500 bytes
   - Generation time: <1 frame

3. **FOV (Field of View):** Simplified shadowcasting or just 4-directional line-of-sight
   - Full Bresenham shadowcasting is expensive but doable (~300 bytes)
   - Simpler: diamond-shaped visibility radius (Manhattan distance check)

---

## 4. Notable GB Homebrew Roguelikes

### Direct References

| Title | Platform | Type | Source | Notes |
|-------|----------|------|--------|-------|
| **Porklike GB** | GB (DMG) | Roguelike port | GBDK, open source | Port of PICO-8 Porklike. Best reference for GB roguelike patterns. https://binji.itch.io/porklikegb |
| **GBISAAC** | GB (DMG) | Isaac demake | GBJam8 entry | Procedural room layouts. https://jrob774.itch.io/the-binding-of-isaac-gbjam8-edition |
| **Tobu Tobu Girl** | GB (DMG) | Arcade (not roguelike) | RGBDS assembly, open source | Excellent reference for RGBDS assembly patterns, VBlank handling, OAM DMA. https://github.com/SimonLarworthy/tobutobugirl |
| **Dangan** | GB (DMG) | Shmup | RGBDS assembly, open source | Reference for input handling, sprite management. https://github.com/ISSOtm/dangan-gb |
| **Deadeus** | GB (DMG) | Horror adventure | GB Studio | Commercial quality homebrew. Not assembly, but demonstrates GB narrative game design. |
| **Knight Owls** | GBA | Roguelike strategy | Homebrew | GBA not GB, but relevant roguelike patterns. https://blaise-rascal.itch.io/knight-owls |

### Commercial GB Roguelikes (Original Era)

- **Rolan's Curse** (1990, Sammy) -- Action RPG with randomized elements
- **Cave Noire** (1991, Konami) -- **The closest commercial precedent.** A proper roguelike for Game Boy with procedurally generated dungeons, turn-based combat, permadeath. Japan-only but well-documented. Study this ROM carefully.
- **Chalvo 55** (1997) -- Puzzle/roguelike hybrid

**Cave Noire** is the single most important reference for Crypt of Echoes. It proved that a full roguelike with procedural generation, inventory, and turn-based combat fits on Game Boy hardware.

### GB Competition 2025

gbdev.io ran the **Game Boy Competition 2025** (gbcompo25), with entries on itch.io. This is the latest batch of high-quality GB homebrew. Worth scanning the entries for roguelike-adjacent games and modern assembly patterns. **URL:** https://gbdev.io/gbcompo25.html and https://itch.io/jam/gbcompo25

### Key Repos to Study

1. **gbdev/rgbds** -- Toolchain itself, includes example code: https://github.com/gbdev/rgbds
2. **ISSOtm/gb-asm-tutorial** -- Assembly tutorial by RGBDS maintainer: https://github.com/ISSOtm (maintained as part of gbdev/gb-asm-tutorial)
3. **ISSOtm/dangan-gb** -- Clean RGBDS assembly game
4. **binji/porklike-gb** -- Roguelike reference (GBDK/C, but logic is transferable)
5. **pret/pokered** -- Pokemon Red disassembly (RGBDS). Enormous reference for tilemap handling, OAM management, menu systems: https://github.com/pret/pokered

---

## 5. GB Emulator Recommendations for Development

### Tier 1: Development Debuggers

| Emulator | Platform | Debugger | Best For | URL |
|----------|----------|----------|----------|-----|
| **Emulicious** | Java (cross-platform) | Full symbolic debugger, VS Code extension, breakpoints, memory viewer, VRAM viewer, profiler | **Primary recommendation for assembly development.** Symbolic debugging with RGBDS .sym files. The VS Code extension enables source-level debugging. | https://emulicious.net |
| **BGB** | Windows (Wine on Linux) | Powerful disassembler, breakpoints, memory viewer, hardware register viewer | **Best accuracy + debugger combo.** Supports RGBDS, no$gmb, WLA syntax. Cycle-accurate. Map viewer, tile viewer. | http://bgb.bircd.org |
| **SameBoy** | macOS, Linux, Windows | Built-in debugger, usage profiler | **Best for macOS.** High accuracy. Has a `usage` command showing CPU time outside halt. Actively maintained (see changelog at sameboy.github.io). | https://sameboy.github.io |

### Tier 2: Accuracy / Testing

| Emulator | Notes |
|----------|-------|
| **Mesen2** | Multi-system emulator (NES, SNES, GB, GBA, PCE, SMS). Good debugger. https://github.com/SourMesen/Mesen2 |
| **Gambatte** | High accuracy, used in TAS. Minimal debugger. |

### Recommendation for Crypt of Echoes

**Primary:** Use **Emulicious** as the daily driver. The VS Code extension with symbolic debugging (reading RGBDS .sym/.map files) is the closest thing to a modern IDE experience for GB assembly. Set breakpoints on labels, inspect WRAM variables by name, view tile data live.

**Secondary:** Use **BGB** for cycle-accurate testing and its superior memory/VRAM viewer. BGB runs well under Wine on Ubuntu 24.04.

**Testing:** Run the ROM through **SameBoy** and **Mesen2** periodically to catch emulator-specific bugs. Test on real hardware via a flash cart (EverDrive GB, or the cheaper insideGadgets carts) once you have a playable prototype.

### Debugger Workflow

```
rgbasm -o main.o main.asm
rgblink -o game.gb -m game.map -n game.sym main.o
rgbfix -v -p 0xFF game.gb

# Load game.gb in Emulicious -- it auto-loads game.sym for symbolic debugging
# Or: open in VS Code with Emulicious extension for source-level debugging
```

---

## 6. Pan Docs and gbdev.io Resources

### Pan Docs (The Primary Reference)

**URL:** https://gbdev.io/pandocs/

Pan Docs is described as "The single, most comprehensive technical reference to Game Boy available to the public." Built with mdBook, actively maintained by the gbdev community.

**Key sections for Crypt of Echoes:**
- **CPU** -- SM83 instruction set reference
- **PPU** -- Tile/sprite/background rendering, VRAM access timing
- **OAM DMA** -- Transfer mechanics
- **Joypad** -- Input register ($FF00)
- **Timer** -- DIV, TIMA, TMA, TAC registers (useful for RNG seeding)
- **Memory Map** -- Complete address space layout
- **MBC** -- Mapper documentation (confirms MBC type $00 for 32KB no-mapper)

### gbdev.io Ecosystem

| Resource | URL | Description |
|----------|-----|-------------|
| Pan Docs | https://gbdev.io/pandocs/ | Technical reference |
| Choosing Tools | https://gbdev.io/guides/tools.html | Toolchain comparison guide |
| awesome-gbdev | https://gbdev.io/resources.html | Curated resource list |
| GB ASM Tutorial | https://gbdev.io/gb-asm-tutorial/ | Step-by-step RGBDS assembly tutorial |
| RGBDS Docs | https://rgbds.gbdev.io/docs | Official RGBDS documentation |
| RGBDS Install | https://rgbds.gbdev.io/install | Installation guide |
| RGBDS Online | https://gbdev.io/rgbds-live/ | Browser-based RGBDS (try code without installing) |
| GB Compo 2025 | https://gbdev.io/gbcompo25.html | Competition with reference entries |
| CPU Opcode Tables | https://gbdev.io/gb-opcodes/ | Visual SM83 opcode reference |
| r/gbdev | https://reddit.com/r/gbdev | Active community subreddit |
| gbdev Discord | Via gbdev.io | Most active community channel |

### Specific Guides Relevant to Roguelikes

- **Dead C Scroll** (https://gbdev.io/guides/deadcscroll.html) -- Advanced scrolling technique guide
- **DMA Hijacking** (https://gbdev.io/guides/dma_hijacking.html) -- Advanced DMA techniques
- **LYC Timing** (https://gbdev.io/guides/lyc_timing.html) -- LCD interrupt timing
- **Assembly Style Guide** (https://gbdev.io/guides/asmstyle.html) -- RGBDS coding conventions

### Book Reference

**"Game Boy Coding Adventure"** by Maximilien Dagois (No Starch Press). Covers RGBDS toolchain, tiles, sprites, backgrounds, windows, color palettes, sound, with BGB as the emulator. The most current book-length reference.

---

## 7. AI-Assisted Retro Game Development

### The Core Thesis

A 32KB Game Boy ROM (~32,000 bytes of machine code, or ~8,000-15,000 lines of assembly) fits entirely within a modern LLM's context window (128K-1M tokens). This enables:

1. **Global reasoning** -- The LLM can see the entire program at once, understanding all interactions between modules
2. **No abstraction leakage** -- No libraries, no OS, no runtime -- what you see is what executes
3. **Deterministic hardware** -- The SM83 CPU has no caches, no branch prediction, no out-of-order execution. Cycle counts are exact and predictable.
4. **Complete specification** -- Pan Docs + RGBDS documentation fully specify the target

This is fundamentally different from asking an LLM to write modern software, where the context window captures only a fraction of the codebase and the runtime behavior depends on layers of abstraction.

### Existing Work Found

**1. Hackaday: "Using AI To Help With Assembly" (2024-11-07)** (T5 -- Hackaday)
- URL: https://hackaday.com/2024/11/07/using-ai-to-help-with-assembly/
- [Ricardo] used AI to convert code to 6502 assembly for a virtual Commodore. Successfully generated sprite-moving code.
- Demonstrates that LLMs can produce working retro assembly for well-documented platforms.

**2. Game Decompilation Using AI (macabeus, Medium, 2025)** (T5 -- blog)
- URL: https://macabeus.medium.com/game-decompilation-using-ai-4d47b65f8852
- Uses AI (Code Copilot) to decompile functions from retro games. Built a VS Code extension for matching decompilation with AI agent mode.
- Demonstrates LLM understanding of retro assembly semantics (reverse direction).

**3. GLM5 Reads Hardware Docs, Builds Working Game Boy Emulator (TikTok, 2026-02-25)**
- An open-source LLM reportedly read Game Boy hardware documentation and produced a working emulator.
- If verified, this demonstrates LLM capacity for GB hardware comprehension.

**4. NES Game Development with Custom GPT (Facebook NESmakers, 2024-06)**
- A developer created a custom GPT to assist with NES game creation using NESMaker.
- Experimental, not systematic.

**5. Reddit r/asm Discussion (2025-03-03)**
- Community discussion on LLM-generated assembly optimization.
- Consensus: LLMs can produce syntactically correct assembly but struggle with optimal register allocation and tight loop optimization. Better used as a code generator with human review.

### Assessment

**No peer-reviewed papers found on LLM-assisted retro game assembly.** This is a genuine gap in the literature. The closest academic work is on LLM-based code generation for modern languages (T2 -- numerous arXiv papers on code LLMs) and LLM-based decompilation.

The thesis that a 32KB ROM fits in context enabling global program reasoning is, to my knowledge, **original and unpublished**. It connects to:
- Program synthesis literature (constraint-based code generation)
- The "small world" hypothesis in software engineering (small programs have fewer interaction patterns)
- Formal verification of embedded systems (where the entire program is small enough to verify)

**Recommendation:** This angle is strong enough for a blog post or even a short paper. Document the development process of Crypt of Echoes as an empirical case study of LLM-assisted retro assembly programming.

### Practical Tips for LLM-Assisted GB Assembly

1. **Feed Pan Docs sections as context** -- The hardware specification is the ground truth
2. **Use RGBDS syntax examples** -- LLMs trained on GitHub have seen RGBDS code (pokered disassembly alone is >100K lines)
3. **Request one function at a time** -- e.g., "Write an RGBDS assembly function that performs OAM DMA from $C000"
4. **Verify cycle counts** -- LLMs can count cycles if you ask, but verify manually
5. **Use the .sym file for validation** -- Compare LLM output labels against the symbol map
6. **The entire ROM as context is the superpower** -- When debugging, paste the entire .asm file and ask "why does this render incorrectly on scanline 144?"

---

## 8. Asset Pipeline

### RGBGFX (Built into RGBDS)

The official tool. Converts PNG images to Game Boy 2bpp tile format.

```bash
# Convert a PNG tileset to .2bpp + .tilemap
rgbgfx -o tiles.2bpp -t tiles.tilemap -u tileset.png

# Flags:
# -o: output tile data (.2bpp)
# -t: output tilemap
# -a: output attribute map (CGB palettes)
# -p: output palette
# -u: unique tiles only (deduplication)
# -c: color spec (e.g., -c '#ffffff,#aaaaaa,#555555,#000000')
# -C: color curve (for accurate DMG LCD simulation)
```

**RGBGFX is the recommended pipeline.** It's maintained alongside RGBDS, has the best integration, and handles all edge cases (tile deduplication, palette assignment, CGB attributes).

### Tile/Sprite Editors

| Tool | Platform | Description | URL |
|------|----------|-------------|-----|
| **Aseprite** | All | Best pixel art editor overall. Export to PNG, pipe through RGBGFX. Supports 4-color palette constraints, animation frames, tilesheet export. | https://www.aseprite.org ($20, or build from source) |
| **GBTD/GBMB** | Windows | Game Boy Tile Designer / Map Builder. Classic tools, output .c/.asm directly. Dated but still functional. | https://github.com/gbdev/tilemap-studio (modern replacement) |
| **Tilemap Studio** | All | Modern replacement for GBMB. Visual tilemap editor, exports to RGBDS format. | https://github.com/Rangi42/tilemap-studio |
| **Game Boy Tile Data Generator** | Web | Online PNG-to-2bpp converter. Quick testing. | https://chrisantonellis.github.io/gbtdg/ |
| **Piskel** | Web | Free online sprite editor with animation support. Export PNG. | https://www.piskelapp.com |
| **GraphicsGale** | Windows | Free pixel art editor, good for animation. | |
| **Krita / GIMP** | All | Set canvas to indexed 4-color mode for constraint-correct editing. | |

### Recommended Pipeline for Crypt of Echoes

```
Aseprite (4-color indexed palette)
    |
    v
Export as PNG (8x8 grid, 4 shades of gray)
    |
    v
rgbgfx -o dungeon_tiles.2bpp -t dungeon.tilemap -u dungeon_tileset.png
rgbgfx -o sprites.2bpp -u sprite_sheet.png
    |
    v
INCBIN "dungeon_tiles.2bpp"  ; in RGBDS assembly
INCBIN "dungeon.tilemap"
INCBIN "sprites.2bpp"
```

**Tile budget for 32KB ROM:**
- Background tiles: 256 tiles max (in VRAM $8000-$8FFF or $8800-$97FF)
- Sprite tiles: 256 tiles max (in VRAM $8000-$8FFF)
- Each tile = 16 bytes (2bpp, 8x8). 256 tiles = 4KB.
- With a shared tileset, you can fit ~512 unique tiles total = 8KB
- Leaves ~24KB for code, maps, and other data in a 32KB ROM

### Palette Constraints

- DMG (original Game Boy): 1 background palette (4 shades) + 2 sprite palettes (3 shades each, color 0 = transparent)
- For CGB: 8 background palettes x 4 colors + 8 sprite palettes x 4 colors
- **Recommendation:** Design for DMG first (4 shades of gray), then add CGB color as an enhancement

---

## Serendipitous Connections

### Connection to Agent COBOL Project
The "entire program fits in context" thesis mirrors the Agent COBOL challenge -- legacy COBOL programs are often self-contained, fitting within LLM context windows, making them amenable to whole-program reasoning for modernization. The Game Boy ROM is an even more extreme case: not just the source, but the *compiled binary* fits in context.

### Connection to Bradley-Terry / Ranking Todo
The roguelike's difficulty tuning could use the Bradley-Terry preference model: present the player with pairs of item/enemy configurations and infer a difficulty ranking. This is overkill for a Game Boy game but theoretically interesting.

### Information Theory Angle
A 32KB ROM has a maximum entropy of 256 Kbits. The actual entropy of a well-structured assembly program is much lower (maybe 2-4 bits/byte due to instruction patterns). An LLM's compression of this structure is what enables it to "understand" the entire program -- it's exploiting the low Kolmogorov complexity of structured code.

### Procedural Generation as Compression
On a 32KB ROM, procedural generation is literally a form of compression: instead of storing 100 hand-designed dungeon maps (100 KB+), you store a 500-byte generator that produces unlimited variety. This connects to algorithmic information theory and the minimum description length principle.

---

## Actionable Recommendations for Crypt of Echoes

### Phase 1: Toolchain Setup
1. Install RGBDS v1.0.1 from GitHub releases (pre-built Linux binary)
2. Install Emulicious + VS Code extension
3. Install BGB under Wine as secondary debugger
4. Install Aseprite for tile art
5. Clone `gb-asm-tutorial` repo and build the hello-world example

### Phase 2: Scaffold
1. Create project structure: `src/`, `res/`, `build/`, `Makefile`
2. Implement minimal ROM: header, VBlank handler, OAM DMA, joypad input
3. Display a static tilemap (one room)
4. Get sprite rendering working (player character)

### Phase 3: Core Roguelike
1. Implement dungeon generator (tunneling algorithm, ~500 bytes)
2. Implement turn-based movement (player moves, enemies move)
3. Implement FOV (Manhattan distance or simplified raycasting)
4. Implement camera scrolling (if maps > 20x18)

### Phase 4: Game Systems
1. Combat (HP, attack, defense -- keep it simple)
2. Items (potions, scrolls, weapons -- 4-8 types)
3. Stairs/level progression
4. Death/permadeath

### Phase 5: Polish
1. Title screen, game over screen
2. Sound effects (minimal -- noise channel for hits, square wave for pickups)
3. CGB color enhancement (optional)
4. Test on real hardware

### ROM Size Budget (32KB)

| Component | Estimated Size |
|-----------|---------------|
| Header + interrupt vectors | 336 bytes |
| Core engine (VBlank, OAM DMA, input, rendering) | 2 KB |
| Dungeon generator | 500 bytes |
| Game logic (movement, combat, AI, items) | 4 KB |
| UI (HUD, menus, text) | 3 KB |
| Tile data (background + sprites) | 6 KB |
| Tilemaps (title screen, UI frames) | 1 KB |
| Text strings | 1 KB |
| Entity/item tables | 1 KB |
| Sound data | 500 bytes |
| **Total estimated** | **~19 KB** |
| **Remaining** | **~13 KB** |

13KB of headroom is comfortable. This leaves room for additional content, more tile variety, or more complex game logic.

---

## Sources

| Tier | Source | URL | What I Used It For |
|------|--------|-----|--------------------|
| T7 | GitHub API (RGBDS releases) | https://api.github.com/repos/gbdev/rgbds/releases/latest | Verified v1.0.1 release date, changelog, download counts |
| T7 | RGBDS Install Page | https://rgbds.gbdev.io/install | Confirmed version history (v0.5.1 through v1.0.1) |
| T7 | Pan Docs | https://gbdev.io/pandocs/ | Primary technical reference |
| T7 | gbdev.io tools guide | https://gbdev.io/guides/tools.html | Toolchain comparison |
| T7 | gbdev.io resources | https://gbdev.io/resources.html | Curated resource list |
| T7 | GB Compo 2025 | https://gbdev.io/gbcompo25.html | Competition scene, resource links |
| T7 | itch.io (Porklike GB) | https://binji.itch.io/porklikegb | GB roguelike reference |
| T7 | itch.io (GBISAAC) | https://jrob774.itch.io/the-binding-of-isaac-gbjam8-edition | GB roguelike-adjacent reference |
| T7 | SameBoy changelog | https://sameboy.github.io/changelog/ | Emulator feature tracking |
| T7 | Emulation General Wiki | https://emulation.gametechwiki.com/index.php/Game_Boy_(Color)_emulators | Emulator comparison |
| T7 | Debian Bug #984927 | https://bugs.debian.org/984927 | RGBDS Debian packaging status (0.9.3) |
| T5 | Hackaday | https://hackaday.com/2024/11/07/using-ai-to-help-with-assembly/ | AI-assisted assembly development |
| T5 | macabeus (Medium) | https://macabeus.medium.com/game-decompilation-using-ai-4d47b65f8852 | AI game decompilation |
| T7 | FOSDEM 2026 slides | https://fosdem.org/2026/events/attachments/W3UFSK-rust-game-boy/slides/ | Rust GB dev talk (toolchain landscape) |
| T7 | No Starch Press | https://nostarch.com/game-boy-coding-adventure | "Game Boy Coding Adventure" book |
| T7 | Reddit r/roguelikedev | https://www.reddit.com/r/roguelikedev/comments/7oi92s/ | Procedural gen on retro hardware discussion |
| T7 | GBDK-2020 Gallery | https://gbdk-2020.github.io/gbdk-2020-gallery/ | Homebrew examples catalog |

**No peer-reviewed papers were found specifically on Game Boy roguelike development or LLM-assisted retro assembly programming.** This is expected -- the intersection is too niche for academic attention. The sources are primarily community documentation (T7) and blog posts (T5).
