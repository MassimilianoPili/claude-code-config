# Plan: Add AngheloAlf (Anghelo Carvajal) to KORE

## Context

The user wants to add information about **Anghelo Carvajal** (GitHub: `AngheloAlf`) and his game decompilation tools to the KORE knowledge graph. AngheloAlf is a key figure in the N64 game decompilation community, creating tools under the **Decompollaborate** organization and leading matching decompilations of N64 games.

## Data to Ingest

### Author Node
- **Name**: Anghelo Carvajal
- **Alias**: AngheloAlf
- **GitHub**: https://github.com/AngheloAlf
- **Domain**: personal
- **Role**: Game decompilation tooling developer, N64 reverse engineering

### Concept Nodes
- `Game Decompilation` — reverse engineering compiled game binaries back to source code
- `MIPS Disassembly` — disassembly of MIPS architecture binaries (N64 CPU)
- `N64 Reverse Engineering` — Nintendo 64 ROM analysis and matching decomp
- `Decompollaborate` — collaborative game decompilation organization

### Source Nodes (Key Projects)

1. **rabbitizer** — MIPS instruction decoder (177 stars, MIT, Assembly/C)
   - URL: https://github.com/Decompollaborate/rabbitizer
   - Org: Decompollaborate
   - Topics: disassembler, mips-assembly, python

2. **spimdisasm** — MIPS disassembler (68 stars, MIT, Python)
   - URL: https://github.com/Decompollaborate/spimdisasm
   - PyPI: https://pypi.org/project/spimdisasm/

3. **mapfile_parser** — Map file parser for decompilation projects (Rust)
   - URL: https://github.com/Decompollaborate/mapfile_parser

4. **drmario64** — Dr. Mario 64 matching decompilation (59 stars, MIT, C)
   - URL: https://github.com/AngheloAlf/drmario64
   - Homepage: https://decomp.dev/AngheloAlf/drmario64

5. **puzzleleague64** — Pokémon Puzzle League matching decompilation (24 stars, MIT, C)
   - URL: https://github.com/AngheloAlf/puzzleleague64

6. **drmario64_recomp** — Dr. Mario 64 static recompilation (18 stars, C++)
   - URL: https://github.com/AngheloAlf/drmario64_recomp

### Relationships
- Author `Anghelo Carvajal` --CREATED--> each Source
- Each Source --HAS_CONCEPT--> relevant Concepts
- Concept `Decompollaborate` --RELATED_TO--> `Game Decompilation`

## Implementation

Use `graph_write` with AGE Cypher. Split into separate calls per KORE conventions (no complex multi-MERGE queries):

1. **MERGE Author node** — `Anghelo Carvajal` with properties (github, alias, domain)
2. **MERGE Concept nodes** (4x) — Game Decompilation, MIPS Disassembly, N64 Reverse Engineering, Decompollaborate
3. **MERGE Source nodes** (6x) — each tool/project with url, stars, language, license
4. **CREATE relationships** — CREATED, HAS_CONCEPT, RELATED_TO

Total: ~12 graph_write calls.

## Status: COMPLETED

Author + 6 Source + 3 Concept nodes + 17 relationships created in KORE.
Missing from original plan: `drmario64`, `puzzleleague64`, `drmario64_recomp` (AngheloAlf's own decomps, not just tools).

---

# Phase 2: N64 Decompilation Landscape — What Can Be Decompiled

## Context

The Decompollaborate toolkit (splat → rabbitizer → spimdisasm → mapfile_parser → ipl3checksum) is the standard pipeline for N64 matching decompilation. This analysis maps the landscape of what has been decompiled, what's in progress, and what significant titles remain.

## The Pipeline

```
ROM.z64
  → splat          (split binary into segments: code, data, textures, audio)
    → spimdisasm   (disassemble MIPS code segments using rabbitizer)
      → human      (write C code that compiles to byte-identical binary)
        → mapfile_parser  (track % of functions matched)
          → ipl3checksum  (verify final ROM CRC matches original)
            → *_recomp    (optional: static recompilation to native x86_64)
```

## COMPLETED Decompilations (100% matched)

| Game | Repo | Stars | Significance |
|------|------|-------|-------------|
| **Super Mario 64** | `n64decomp/sm64` | 12K+ | First complete N64 decomp (2020). Spawned PC port movement |
| **Ocarina of Time** | `zeldaret/oot` | 8K+ | ~700K LOC. Gold standard for decomp methodology |
| **Majora's Mask** | `zeldaret/mm` | 3K+ | Completed ~2024. Built on OoT foundation |
| **Paper Mario** | `pmret/papermario` | 1.5K+ | Complete. Rich scripting/battle system documented |
| **Perfect Dark** | `kanowins/perfect_dark` | 2K+ | Rare's engine, completed |
| **Banjo-Kazooie** | `n64decomp/banjo-kazooie` | 800+ | Rare engine |
| **Dr. Mario 64** | `AngheloAlf/drmario64` | 59 | **AngheloAlf's own decomp** — fully matched |
| **Quest 64** | community | — | Smaller RPG, fully matched |
| **Dinosaur Planet** | community | — | Unreleased Rare game (leaked ROM) |

## IN PROGRESS (active, using Decompollaborate tools)

| Game | Repo/Community | Progress | Why It Matters |
|------|---------------|----------|---------------|
| **GoldenEye 007** | `n64decomp/goldeneye` | ~60-70% | Iconic FPS, complex AI state machines, historically significant |
| **Pokémon Puzzle League** | `AngheloAlf/puzzleleague64` | Active | **AngheloAlf's** — NST engine |
| **Star Fox 64** | `sonicdcer/sf64` | Active | Custom RSP microcode — hardware-level 3D pipeline |
| **Diddy Kong Racing** | community | ~50%+ | Rare engine variant |
| **Kirby 64** | community | Active | HAL Laboratory engine |
| **Mario Party 1/2/3** | various | Active | Mini-game architectures |
| **Pokémon Snap** | community | Active | HAL-related engine |
| **Wave Race 64** | community | Early | Unique water physics system |
| **F-Zero X** | community | Early | Extreme optimization for 60fps |
| **Bomberman 64** | community | Active | Hudson Soft engine |

## IMPORTANT TITLES NOT YET STARTED (or very early)

### Tier 1 — High significance, technically feasible

| Game | Why Important | Difficulty |
|------|-------------|-----------|
| **Super Smash Bros.** | Fighting game engine, HAL Laboratory, first of the franchise | Medium — HAL engine known from Kirby |
| **Mario Kart 64** | Iconic racer, EAD engine, texture/track format | Medium |
| **Donkey Kong 64** | Massive Rare title, last major undecomped Rare game | High — very large ROM |
| **Conker's Bad Fur Day** | Rare engine peak, technical showcase | High — late-gen, heavily optimized |
| **Turok: Dinosaur Hunter** | Acclaim engine, early FPS | Medium |
| **1080° Snowboarding** | Unique physics engine | Medium |
| **Pilotwings 64** | EAD launch title, flight physics | Medium-Low |

### Tier 2 — Technically interesting

| Game | Why Interesting |
|------|----------------|
| **Blast Corps** | Rare engine early version, physics-based destruction |
| **Jet Force Gemini** | Rare engine, different genre |
| **Body Harvest** | DMA Design (pre-Rockstar), proto-GTA open world |
| **Sin & Punishment** | Treasure's engine, rail shooter |
| **Mischief Makers** | Treasure's 2D engine on 3D hardware |
| **Doom 64** | Midway's unique Doom engine (not id Tech) |
| **Resident Evil 2** | Remarkable N64 port of a PS1 game, extreme compression |

### Beyond N64 — splat/spimdisasm also support

| Platform | ISA | Tool Support | Notable Projects |
|----------|-----|-------------|-----------------|
| **PS1/PSX** | MIPS R3000A | Full (splat has PSX overlay support) | Crash Bandicoot, Spyro, FF7 |
| **PS2** | MIPS R5900 | Partial (rabbitizer supports R5900) | Kingdom Hearts, FFX, GTA SA |
| **iQue Player** | Same N64 ISA | Full | Chinese N64 variant, same toolchain |

## What Makes a Decomp "Important"

1. **Engine reuse**: Decomping one Rare game informs all others (shared engine)
2. **Preservation**: Source code is future-proof; emulators break
3. **Static recompilation**: Once decomped, games can be natively recompiled to PC/Switch (like SM64 PC port, OoT Ship of Harkinian)
4. **Historical significance**: Understanding how teams optimized for 93.75 MHz MIPS with 4MB RAM
5. **Mod scene**: Source code enables total conversion mods

## AngheloAlf's `*_recomp` Pattern

AngheloAlf pioneered `drmario64_recomp` — **static recompilation** of a matched decomp to native x86_64. This is the step after decompilation: instead of running in an emulator, the game runs natively at full speed. The Zelda64Recomp project (Ship of Harkinian) follows the same pattern for OoT/MM.

## Phase 3: Populate KORE with Decompilation Ecosystem

### New Concept Nodes (2)
1. `Static Recompilation` — recompiling matched decomp C source to native x86_64/ARM, eliminating emulator
2. `Decompollaborate` — collaborative game decompilation organization founded by AngheloAlf

### New Source Nodes (11) — Major Decomp Projects

**Completed (7):**
1. `sm64` — Super Mario 64 decomp (n64decomp/sm64, 12K+ stars, C)
2. `oot` — Ocarina of Time decomp (zeldaret/oot, 8K+ stars, C)
3. `mm` — Majora's Mask decomp (zeldaret/mm, 3K+ stars, C)
4. `papermario` — Paper Mario decomp (pmret/papermario, 1.5K+ stars, C)
5. `perfect_dark` — Perfect Dark decomp (kanowins/perfect_dark, 2K+ stars, C)
6. `banjo-kazooie` — Banjo-Kazooie decomp (n64decomp/banjo-kazooie, 800+ stars, C)
7. `drmario64` — Dr. Mario 64 decomp (AngheloAlf/drmario64, 59 stars, C) — already in plan but not created

**In Progress (2):**
8. `goldeneye` — GoldenEye 007 decomp (n64decomp/goldeneye, active, ~60-70%)
9. `sf64` — Star Fox 64 decomp (sonicdcer/sf64, active, RSP microcode)

**Recompilation (2):**
10. `drmario64_recomp` — Dr. Mario 64 static recompilation (AngheloAlf/drmario64_recomp, 18 stars, C++)
11. `Zelda64Recomp` — Zelda 64 static recompilation (community, OoT/MM native port)

### Relationships (~30)
- Each completed decomp Source → RELATED_TO → `N64 Game Decompilation`
- Each completed decomp Source → RELATED_TO → `Matching Decompilation`
- Each decomp Source → USES_TOOL → `splat`, `spimdisasm` (where applicable)
- `drmario64` → Author `Anghelo Carvajal` (CREATED)
- `drmario64_recomp` → Author `Anghelo Carvajal` (CREATED)
- `drmario64_recomp` → RELATED_TO → `Static Recompilation`
- `Zelda64Recomp` → RELATED_TO → `Static Recompilation`
- `Decompollaborate` → Author `Anghelo Carvajal` (FOUNDED_BY)

### Implementation
~25 `graph_write` calls via MCP (split per AGE conventions). Batch:
1. MERGE 2 Concept nodes
2. MERGE 11 Source nodes (parallel-safe, independent)
3. CREATE relationships (~15 calls, each matching 2 nodes)

### Verification
```cypher
MATCH (s:Source)-[:RELATED_TO]->(c:Concept {name: 'N64 Game Decompilation'})
RETURN {game: s.name, stars: s.stars, status: s.status}
ORDER BY s.stars DESC
```
Expected: 10+ Source nodes linked to the concept.
