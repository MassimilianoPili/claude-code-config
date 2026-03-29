# Research Report: Decompiled Retro Game ROMs (SNES & GBA) -- Puzzle & Memory Games

## Status: COMPLETE RESEARCH -- ready to deliver

---

## 1. THE MASTER LIST: awesome-game-decompilations

**Repo**: `CharlotteCross1998/awesome-game-decompilations`
**URL**: https://github.com/CharlotteCross1998/awesome-game-decompilations
**Stars**: ~694K+ (curated list, actively maintained, last push 2026-03-08)

This is THE canonical curated list. It contains 400+ decompilation projects organized by franchise (Pokemon, Zelda, Mario, Sonic, Animal Crossing) plus a massive "Other" section. I fetched and read the entire README (30KB, 6 chunks).

### SNES entries found in the list:
- **Earthbound** -- `Herringway/ebsrc` (172 stars, Assembly, SNES decompilation)
- **Donkey Kong Country 1** -- `Yoshifanatic1/Donkey-Kong-Country-1-Disassembly`
- **Donkey Kong Country 2** -- `p4plus2/DKC2-disassembly`
- **Donkey Kong Country 3** -- `Yoshifanatic1/Donkey-Kong-Country-3-Disassembly`
- **Soul Blazer** -- `hellow554/RustyBlazer`
- **Chrono Cross** (PS1 but notable) -- `jdperos/chrono-cross-decomp`
- **Harvest Moon: A Wonderful Life** -- `ChrisNonyminus/hmawl`

**Important finding: SNES decompilations are RARE.** The 65816 processor makes C decompilation nearly impossible -- most SNES projects are **disassemblies** (annotated assembly), not decompilations to C. The ecosystem is far less developed than N64/GBA/GC.

### GBA entries found in the list (extensive):
The GBA ecosystem is **massive** because the ARM7TDMI processor used a standard GCC-based compiler (`agbcc`), making matching C decompilation feasible.

**Major GBA decomps from the list:**
- All Pokemon GBA games (pret org)
- Sonic Advance 1, 2, 3 (SAT-R org)
- Kirby & The Amazing Mirror -- `jiangzhengwenjz/katam` (136 stars, C, active)
- Castlevania: Aria of Sorrow -- `testyourmine/cvaos`
- Fire Emblem: The Blazing Blade -- `MokhaLeee/FireEmblem7J`
- Fire Emblem: The Sacred Stones -- `FireEmblemUniverse/fireemblem8u`
- Mario & Luigi: Superstar Saga -- `jellees/mlss`
- Mario Kart: Super Circuit -- `jellees/mksc`
- Metroid: Zero Mission -- `metroidret/mzm`
- Metroid Fusion -- `metroidret/mf`
- Wario Land 4 -- `lilDavid/warioland4` (8 stars, Assembly, "Clean-room decompilation", created 2025-05-27)
- Megaman Zero 3 -- `mmzret/rmz3`
- Mother 1+2 -- `Normmatt/m12`
- Harvest Moon: Friends of Mineral Town -- `StanHash/fomt` (29 stars, Assembly)
- The Sims 2 (GBA) -- `SimsAdvanceRet/S2GBADecomp`
- The Sims: Bustin' Out (GBA) -- `SimsAdvanceRet/BustinOutGBADecomp`
- The Urbz: Sims in the City (GBA) -- `SimsAdvanceRet/UrbzGBADecomp`
- Banjo-Kazooie: Grunty's Revenge (GBA) -- `jellees/bkgr`
- Pokemon Pinball: Ruby & Sapphire -- `pret/pokepinballrs` (120 stars, Assembly/C)
- Advance Wars 2: Black Hole Rising -- `Eebit/aw2bhr`
- Yu-Gi-Oh! Reshef of Destruction -- `shinny456/ygodm8`
- Summon Night: Craft Sword Monogatari -- `jiangzhengwenjz/csm3`

---

## 2. PUZZLE & MEMORY GAMES -- Specific Findings

### FOUND -- Decompiled/Disassembled Puzzle Games:

#### Dr. Mario (NES) -- DISASSEMBLY
- **Repo**: `Nostaljipi/dr-mario-disassembly`
- **URL**: https://github.com/Nostaljipi/dr-mario-disassembly
- **Stars**: 15
- **Language**: Assembly (6502)
- **Platform**: NES (NOT SNES or GBA)
- **Status**: Complete disassembly, last updated 2021-11-27
- **Description**: "Disassembly of Dr. Mario (NES)"

#### Dr. Mario 64 (N64) -- DECOMPILATION (C)
- **Repo**: `AngheloAlf/drmario64`
- **URL**: https://github.com/AngheloAlf/drmario64
- **Stars**: 59
- **Language**: C (matching decomp)
- **Platform**: N64
- **Status**: Active, last push 2026-01-14. Progress tracked on decomp.dev for US, CN (iQue), and Gateway versions
- **Homepage**: https://decomp.dev/AngheloAlf/drmario64
- **License**: MIT (src/ folder CC0)
- **Key detail from README**: Uses DWARF debug info from the GameCube release (Nintendo Puzzle Collection) as reference. **Leak-free** -- contributors who have seen gigaleak materials are excluded.
- **Build requires**: Original ROM + make/clang/binutils-mips-linux-gnu + uv (Python)

#### Dr. Mario 64 (GameCube -- Nintendo Puzzle Collection version) -- DECOMPILATION
- **Repo**: `NewGBAXL/drmario64-gc`
- **URL**: https://github.com/NewGBAXL/drmario64-gc
- **Stars**: 2
- **Language**: C
- **Platform**: GameCube
- **Status**: Created 2025-05-22, uses dtk-template
- **License**: CC0-1.0
- **Description**: "Dr. Mario 64 (Nintendo Puzzle Collection) decomp"

#### Pokemon Puzzle League (N64) -- DECOMPILATION (C)
- **Repo**: `AngheloAlf/puzzleleague64`
- **URL**: https://github.com/AngheloAlf/puzzleleague64
- **Stars**: 24
- **Language**: C (matching decomp)
- **Platform**: N64
- **Status**: Active, last push 2025-09-08. Supports USA, EUR, FRA, GER versions
- **Homepage**: https://decomp.dev/AngheloAlf/puzzleleague64
- **License**: MIT (src/ folder CC0)
- **Key detail from README**: "This repository uses the DWARF debugging information contained in the `PANEPON.plf` binary from the 'Nintendo Puzzle Collection' Gamecube game as a reference for naming symbols and structs. Even if at a first glance Panel de Pon and Puzzle League may seem like different games, they share big chunks of the same codebase."
- **CRITICAL FINDING**: This is the closest thing to a Panel de Pon decompilation -- the N64 Puzzle League game shares substantial code with SNES Panel de Pon.
- **Leak-free** project.

#### The New Tetris (N64) -- DECOMPILATION
- **Repo**: `KiritoDv/tnt`
- **URL**: https://github.com/KiritoDv/tnt
- **Stars**: 5
- **Language**: C
- **Platform**: N64
- **Status**: ARCHIVED (archived: true), last push 2025-01-23
- **License**: MIT

#### Big Brain Academy: Wii Degree -- DECOMPILATION
- **Repo**: `vabold/bba-wd`
- **URL**: https://github.com/vabold/bba-wd
- **Platform**: Wii
- **Description**: Puzzle/brain training game -- relevant to the "brain training" category

#### Space Cadet Pinball -- DECOMPILATION
- **Repo**: `k4zmu2a/SpaceCadetPinball`
- **URL**: https://github.com/k4zmu2a/SpaceCadetPinball
- **Platform**: Windows (but notable as a puzzle game decomp)

### NOT FOUND -- No Known Decompilation/Disassembly:

The following games from your list have **NO known decompilation or disassembly projects** on GitHub:

- **Tetris (SNES version)** -- No decomp found. Only homebrew Tetris clones for GBA exist (e.g., `jduranmaster/GBA-Tetris` -- a homebrew clone, NOT a decompilation of the official game)
- **Tetris (GBA version)** -- No decomp found
- **Panel de Pon (SNES)** -- No direct decomp, but puzzleleague64 shares code (see above)
- **Tetris Attack (SNES)** -- No decomp found
- **Puzzle League (GBA)** -- No decomp found (only the N64 version exists)
- **Dr. Mario (SNES)** -- No decomp found (only NES and N64 versions)
- **Dr. Mario (GBA)** -- No decomp found
- **Puyo Puyo (SNES or GBA)** -- No decomp found. `puyoai/puyoai` (141 stars) is an AI player, not a decomp. `nickworonekin/puyotools` is a tool suite, not a decomp.
- **Columns** -- No decomp found (only an English translation patch for Sakura Wars Columns 2 on Dreamcast)
- **Wario's Woods** -- No decomp found
- **Memory card matching games** -- No decomp found for any SNES/GBA memory games
- **Concentration games** -- No decomp found
- **Puzzle Bobble / Bust-a-Move** -- No decomp found for SNES/GBA versions
- **Kirby's Star Stacker** -- No decomp found
- **Yoshi's Cookie** -- No decomp found
- **Pokemon Puzzle Challenge (GBC)** -- No decomp found

### ADJACENT/RELEVANT -- Not exact matches but puzzle-adjacent GBA decomps:
- **Pokemon Pinball: Ruby & Sapphire** (GBA) -- `pret/pokepinballrs` -- 120 stars, active. A puzzle-adjacent GBA game with full decompilation.
- **Kirby & The Amazing Mirror** (GBA) -- `jiangzhengwenjz/katam` -- 136 stars, puzzle elements within the platformer
- **Fortune Street** (Wii) -- `FortuneStreetModding/boom-street-decomp` -- board game with puzzle elements
- **Advance Wars 2** (GBA) -- `Eebit/aw2bhr` -- strategy puzzle

---

## 3. THE DECOMP ECOSYSTEM

### decomp.me
- **URL**: https://decomp.me
- **Status**: Cloudflare-protected (couldn't fetch content directly), but confirmed active
- **What it is**: A collaborative web platform for decompilation. Users can:
  - Paste assembly snippets from a game
  - Write C code that compiles to matching assembly
  - Share "scratches" (individual function decompilation attempts)
  - Track progress across projects
- **Supported platforms**: N64, GBA, GameCube, Wii, PS1, PS2, NDS, and more
- **How it works**: You select a compiler (e.g., agbcc for GBA, IDO for N64), paste target assembly, and write C that produces byte-identical output
- **Used by**: Nearly all active decomp projects. Both drmario64 and puzzleleague64 link to `decomp.dev` for progress tracking (decomp.dev is the progress dashboard companion site)

### decomp.dev
- **URL**: https://decomp.dev
- **What it is**: Progress tracking dashboard for decompilation projects
- **Examples**:
  - https://decomp.dev/AngheloAlf/drmario64 -- Dr. Mario 64 progress
  - https://decomp.dev/AngheloAlf/puzzleleague64 -- Pokemon Puzzle League progress
- **Tracks**: matched_code_percent per version (US, EU, JP, etc.)

### pret Organization
- **URL**: https://github.com/pret
- **What it is**: The "Pokemon Reverse Engineering Team" -- the largest and most prolific game decompilation organization on GitHub
- **Scale**: 30+ repositories, thousands of stars total
- **Key repos** (sorted by relevance):

| Repo | Game | Platform | Stars | Language | Status |
|------|------|----------|-------|----------|--------|
| `pokeemerald` | Pokemon Emerald | GBA | ~3000+ | C | Complete |
| `pokefirered` | Pokemon FireRed | GBA | ~1500+ | C | Complete |
| `pokeruby` | Pokemon Ruby | GBA | ~800+ | C | Complete |
| `pokecrystal` | Pokemon Crystal | GBC | ~2000+ | Assembly | Complete |
| `pokered` | Pokemon Red | GB | ~3000+ | Assembly | Complete |
| `pokepinballrs` | Pokemon Pinball RS | GBA | 120 | Assembly/C | Active |
| `pokepinball` | Pokemon Pinball | GBC | ~50+ | Assembly | Active |
| `pmd-red` | PMD Red Rescue Team | GBA | ~200+ | C | Active |
| `poketcg` | Pokemon TCG | GBC | ~200+ | Assembly | Complete |
| `agbcc` | C Compiler | Tool | 151 | C | Active |

**pret established the methodology** that all subsequent GBA decomp projects follow: use `agbcc` compiler, produce byte-matching binaries, track progress as percentage of decompiled functions.

### gbdev.io
- **URL**: https://gbdev.io
- **What it is**: Game Boy development community resource hub
- **Includes**: Tutorials, toolchain documentation, hardware reference, links to decomp projects
- **Key resources**:
  - Pan Docs (Game Boy hardware documentation)
  - RGBDS (Rednex Game Boy Development System -- assembler/linker)
  - List of Game Boy/GBC homebrew and decomp projects

### romhacking.net
- **URL**: https://www.romhacking.net (now datacrystal.romhacking.net)
- **What it is**: The oldest ROM hacking community. Database of:
  - ROM maps (memory layouts of games)
  - RAM maps
  - Patches and translations
  - Utilities for specific games
- **Relevance**: Contains partial disassembly documentation for many SNES puzzle games (Tetris, Dr. Mario, etc.) even when full decomp projects don't exist. These are usually text documents with annotated memory addresses, not full source code.

---

## 4. TOOLS

### Core Decompilation Tools

| Tool | URL | Purpose | Used For |
|------|-----|---------|----------|
| **Ghidra** | https://ghidra-sre.org | NSA's reverse engineering framework. Disassembler + decompiler. Free. | All platforms. Primary tool for initial analysis. Has MIPS, ARM, 65816 processors. |
| **agbcc** | https://github.com/pret/agbcc (151 stars, 107 forks) | "C compiler" -- a modified GCC 2.95 that matches the original GBA SDK compiler output | **THE** critical tool for GBA decompilation. Without this, matching decomp would be impossible. Reproduces the exact codegen quirks of the original Nintendo SDK compiler. |
| **radare2 / rizin** | https://rada.re / https://rizin.re | Open-source RE framework, disassembler, debugger | Alternative to Ghidra. Rizin is the actively maintained fork. |
| **mGBA** | https://mgba.io | GBA emulator with debugging features | GBA decomp debugging: breakpoints, memory viewer, register inspection, trace logging |
| **no$gba** | https://problemkaputt.github.io | GBA/NDS emulator with advanced debugger | Historically the gold standard for GBA debugging. Has I/O viewer, hardware register inspection. |
| **splat** | https://github.com/ethteck/splat | Binary splitting tool | Splits ROM into segments (code, data, assets). Used by drmario64, puzzleleague64, and most N64/GBA decomps. |
| **decomp.me** | https://decomp.me | Web-based collaborative decomp platform | Function-by-function matching. Supports multiple compilers. |
| **asm-differ / diff.py** | (varies per project) | Assembly diff tool | Compares decompiled C output against original assembly to verify matching |
| **dtk (Decomp Toolkit)** | https://github.com/encounter/decomp-toolkit | GameCube/Wii decompilation toolkit | Used by GC/Wii decomps like drmario64-gc |
| **RGBDS** | https://rgbds.gbdev.io | Rednex Game Boy Development System | Assembler/linker for GB/GBC disassemblies (pokered, pokecrystal) |
| **IDO 5.3/7.1** | (bundled in decomp projects) | Original SGI MIPS C compiler | N64 decomps use these to match the original compiler output |
| **pigment64** | `cargo install pigment64` | N64 texture conversion tool (Rust) | Used by puzzleleague64 for asset extraction |

### SNES-Specific Tools

| Tool | Purpose |
|------|---------|
| **bsnes-plus** | SNES emulator with enhanced debugging (trace logger, breakpoints, memory viewer) |
| **DiztinGUIsh** | SNES disassembly tool with GUI. Helps annotate 65816 assembly. |
| **no$sns** | SNES emulator/debugger by Martin Korth |
| **Asar** | SNES assembler (65816) |
| **bass** | 65816 assembler by Near/byuu |

### The agbcc Story (Critical for GBA)
`pret/agbcc` (151 stars, 107 forks, last push 2026-01-20) is a reverse-engineered clone of the C compiler that Nintendo used in their official GBA SDK. It's based on GCC 2.95 but modified to reproduce the exact same code generation quirks, register allocation patterns, and optimization decisions as the original proprietary compiler. This is what makes "matching decompilation" possible -- the C code must compile through agbcc to produce byte-identical output to the original ROM. Without agbcc, GBA decompilation would be limited to non-matching reverse engineering.

---

## 5. LEGAL STATUS

### How Decompilation Projects Handle Copyright

#### The "Matching Decompilation" / "Clean Room" Model

**What they do NOT include:**
- No copyrighted game assets (graphics, music, sound effects, level data)
- No original ROM files
- No leaked source code (most projects explicitly ban contributors who have seen leaked materials)

**What they DO include:**
- Reverse-engineered C source code that, when compiled, produces a byte-identical binary to the original ROM
- You must provide your own legally obtained ROM to build

**The legal theory:**
1. **Sega v. Accolade (1992, 9th Circuit)**: Reverse engineering for interoperability purposes is fair use. This is the foundational US case.
2. **Sony v. Connectix (2000, 9th Circuit)**: Intermediate copying during reverse engineering is fair use when the final product doesn't contain copyrighted material.
3. **EU Software Directive (Article 6)**: Decompilation is permitted for interoperability, provided the information isn't used for other purposes.

**How decomp projects frame it:**
- The repositories contain only **original code** written by the decomp contributors
- The code is licensed under permissive licenses (MIT, CC0) -- the decomp team's own work
- Building requires the user to supply their own ROM (a copyrighted work they must legally own)
- The `splat` tool extracts assets from the user's ROM at build time; these are never committed to the repository
- Many projects have explicit statements like (from drmario64 README): "The intention of this project is to understand the inner workings of this game better"
- Most request that the code NOT be used for "porting" to non-original platforms (though this is a community norm, not a legal requirement)

**The "Gigaleak" problem:**
- In 2020, internal Nintendo source code was leaked ("gigaleak")
- This included source for several games that have decomp projects
- Most decomp projects responded by **explicitly banning** anyone who had viewed the leaked code
- From puzzleleague64 README: "This matching decomp effort is being done leak-free. If you have looked/worked with leaked materials (i.e. gigaleak) then it's a shame but you can't contribute to this project."
- This "clean room" approach is legally critical: it ensures the decompiled code is independently derived, not copied from leaked sources

**Legal risks:**
- Nintendo has been notably aggressive about ROMs and emulation but has **never** sent takedown notices to decompilation projects (as of early 2026)
- The SM64 decomp project (github.com/n64decomp/sm64, extremely high profile) has been online since 2019 without legal action
- The SM64 PC **port** (which used the decomp to build a native PC executable) received DMCA takedowns -- but the decomp itself was not targeted
- The key legal distinction: decomp = research/interoperability (protected); porting = creating a competing product (potentially infringing)

**License patterns in decomp repos:**
| License | Used by | Meaning |
|---------|---------|---------|
| MIT | drmario64, puzzleleague64, warioland4 | The decomp team's original contribution is freely usable |
| CC0 | drmario64 src/, puzzleleague64 src/ | The actual C source is public domain -- the decomp team claims no copyright over their reconstruction of the game logic |
| No license | Many pret repos (pokeemerald, etc.) | Ambiguous -- technically "all rights reserved" but the community treats it as open |
| GPL-3.0 | Some decomps | Copyleft applied to the reconstruction effort |

---

## 6. SUMMARY TABLE: Puzzle Game Decomp Status

| Game | Platform | Decomp Exists? | Repo | Stars | Completeness | Language |
|------|----------|----------------|------|-------|--------------|----------|
| Dr. Mario | NES | YES (disasm) | `Nostaljipi/dr-mario-disassembly` | 15 | Complete | ASM |
| Dr. Mario 64 | N64 | YES (decomp) | `AngheloAlf/drmario64` | 59 | Active/WIP | C |
| Dr. Mario 64 (GC) | GC | YES (decomp) | `NewGBAXL/drmario64-gc` | 2 | Early | C |
| Dr. Mario (SNES) | SNES | NO | -- | -- | -- | -- |
| Dr. Mario (GBA) | GBA | NO | -- | -- | -- | -- |
| Pokemon Puzzle League | N64 | YES (decomp) | `AngheloAlf/puzzleleague64` | 24 | Active/WIP | C |
| Panel de Pon (SNES) | SNES | NO (but shares code w/ above) | -- | -- | -- | -- |
| Tetris Attack (SNES) | SNES | NO | -- | -- | -- | -- |
| Puzzle League (GBA) | GBA | NO | -- | -- | -- | -- |
| Pokemon Puzzle Challenge | GBC | NO | -- | -- | -- | -- |
| The New Tetris | N64 | YES (archived) | `KiritoDv/tnt` | 5 | Archived | C |
| Tetris (SNES) | SNES | NO | -- | -- | -- | -- |
| Tetris (GBA) | GBA | NO | -- | -- | -- | -- |
| Puyo Puyo (any) | SNES/GBA | NO | -- | -- | -- | -- |
| Columns (any) | SNES/GBA | NO | -- | -- | -- | -- |
| Wario's Woods | SNES | NO | -- | -- | -- | -- |
| Puzzle Bobble/Bust-a-Move | SNES/GBA | NO | -- | -- | -- | -- |
| Kirby's Star Stacker | GB/SNES | NO | -- | -- | -- | -- |
| Yoshi's Cookie | NES/SNES/GB | NO | -- | -- | -- | -- |
| Big Brain Academy | Wii | YES (decomp) | `vabold/bba-wd` | ? | WIP | C |

---

## 7. KEY OBSERVATIONS

### Why SNES puzzle games have no decomps:

1. **65816 architecture**: The SNES uses a WDC 65C816 processor. Unlike ARM (GBA) or MIPS (N64), no standard C compiler was used for 65816 development. Games were written directly in assembly or used obscure proprietary toolchains. This makes "matching decompilation to C" essentially impossible -- there's no reference compiler to match against.

2. **Community focus**: The decomp community has overwhelmingly focused on platforms where matching C decompilation is feasible: N64 (MIPS/IDO), GBA (ARM/agbcc), GameCube/Wii (PowerPC/CodeWarrior). SNES gets disassemblies (annotated assembly), not decomps.

3. **Puzzle games are niche**: Even within the active GBA decomp community, effort concentrates on RPGs (Pokemon, Fire Emblem), platformers (Kirby, Metroid, Sonic), and action games. Puzzle games have smaller fan communities and fewer people motivated to spend months on reverse engineering.

### Closest things to what you want:

1. **Pokemon Puzzle League (N64)** -- `AngheloAlf/puzzleleague64` -- shares substantial code with SNES Panel de Pon. This is the best entry point for understanding the Panel de Pon/Tetris Attack game engine.

2. **Dr. Mario 64** -- `AngheloAlf/drmario64` -- well-documented matching decomp with progress tracking. Both are by the same author (AngheloAlf), who also created the `splat` ROM splitting tool.

3. **Pokemon Pinball RS** (GBA) -- `pret/pokepinballrs` -- the most complete puzzle-adjacent GBA decomp in the pret ecosystem.

4. For SNES specifically, the Data Crystal / romhacking.net archives may have partial RAM/ROM maps for games like Tetris, Dr. Mario SNES, etc. -- not full decomps but annotated memory maps that document game logic.

---

## 8. ALL URLs REFERENCED

### Curated Lists
- https://github.com/CharlotteCross1998/awesome-game-decompilations

### Puzzle Game Decomps (Direct)
- https://github.com/AngheloAlf/drmario64
- https://github.com/AngheloAlf/puzzleleague64
- https://github.com/Nostaljipi/dr-mario-disassembly
- https://github.com/NewGBAXL/drmario64-gc
- https://github.com/KiritoDv/tnt
- https://github.com/vabold/bba-wd

### Ecosystem / Organizations
- https://github.com/pret (Pokemon Reverse Engineering Team)
- https://decomp.me (collaborative decompilation platform)
- https://decomp.dev (progress tracking dashboard)
- https://gbdev.io (Game Boy development resources)
- https://www.romhacking.net (ROM hacking database)

### Key Tools
- https://github.com/pret/agbcc (GBA C compiler, 151 stars)
- https://ghidra-sre.org (Ghidra RE framework)
- https://mgba.io (mGBA emulator/debugger)
- https://github.com/ethteck/splat (ROM splitter)
- https://github.com/encounter/decomp-toolkit (GC/Wii dtk)
- https://rgbds.gbdev.io (Game Boy assembler)

### Notable GBA Decomps (Reference for methodology)
- https://github.com/pret/pokeemerald
- https://github.com/pret/pokefirered
- https://github.com/pret/pokepinballrs (120 stars, puzzle-adjacent)
- https://github.com/jiangzhengwenjz/katam (Kirby Amazing Mirror, 136 stars)
- https://github.com/SAT-R/sa2 (Sonic Advance 2, 575 stars)
- https://github.com/FireEmblemUniverse/fireemblem8u
- https://github.com/metroidret/mzm (Metroid Zero Mission)
- https://github.com/lilDavid/warioland4 (clean-room GBA decomp)

### SNES Decomps (few that exist)
- https://github.com/Herringway/ebsrc (Earthbound, 172 stars)

### Panel-pop / Clone (NOT decomp but useful reference)
- https://github.com/a544jh/panel-pop (Panel de Pon / Tetris Attack clone in C++, 45 stars, MIT)

### Legal References
- Sega v. Accolade, 977 F.2d 1510 (9th Cir. 1992)
- Sony v. Connectix, 203 F.3d 596 (9th Cir. 2000)
- EU Directive 2009/24/EC, Article 6 (decompilation for interoperability)
