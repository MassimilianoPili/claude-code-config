# Research Results: snesrev Repos & Assembly Parsing Tools

## Task 1: snesrev Repos -- NOT DMCA'd, All Still Live

**Key finding: The premise was incorrect.** All three snesrev repos are still publicly accessible on GitHub as of 2026-03-20. None have been DMCA'd. They are live, cloneable, and forkable.

### Original Repos (ALL LIVE)

| Repo | URL | Stars | Forks | Language | Last Push | Status |
|------|-----|-------|-------|----------|-----------|--------|
| **zelda3** | https://github.com/snesrev/zelda3 | 4,565 | 405 | C | 2023-12-27 | LIVE, public |
| **smw** | https://github.com/snesrev/smw | 572 | 64 | C | 2024-01-22 | LIVE, public |
| **sm** | https://github.com/snesrev/sm | 523 | 45 | C | 2023-08-21 | LIVE, public |

Additional snesrev repo:
- **smw_hacks** -- https://github.com/snesrev/smw_hacks (13 stars, SMW hack support)

Discord community: https://discord.gg/AJJbJAzNNJ

### Notable Forks (sorted by stars)

#### zelda3 forks (405 total)
| Fork | Stars | Description |
|------|-------|-------------|
| [xander-haj/zelda3](https://github.com/xander-haj/zelda3) | 257 | Explicit mirror "forked from snesrev's repo", 23 sub-forks |
| [Waterdish/zelda3-android](https://github.com/Waterdish/zelda3-android) | 147 | Android port (NOT a fork -- standalone project using snesrev code) |
| [marian-m12l/game-and-watch-zelda3](https://github.com/marian-m12l/game-and-watch-zelda3) | -- | Game & Watch hardware port |
| [flathub/io.github.snesrev.Zelda3](https://github.com/flathub/io.github.snesrev.Zelda3) | 1 | Flatpak packaging |

#### smw forks (64 total)
| Fork | Stars | Description |
|------|-------|-------------|
| [Rinnegatamante/smw](https://github.com/Rinnegatamante/smw) | 11 | PS Vita port (Rinnegatamante is a known Vita homebrew dev) |
| [marian-m12l/smw](https://github.com/marian-m12l/smw) | -- | Game & Watch port |

#### sm forks (45 total)
| Fork | Stars | Description |
|------|-------|-------------|
| [testyourmine/sm-redux](https://github.com/testyourmine/sm-redux) | 18 | "sm-redux" -- enhanced/continued version, 3 sub-forks |
| [panzone91/sm-vita](https://github.com/panzone91/sm-vita) | -- | PS Vita port |

### Other Platforms
- **Codeberg**: Blocked by anti-scraping measures (returns garbage to automated fetchers). Manual check recommended but unlikely to have mirrors given originals are live.
- **GitLab**: No results found via API.
- **Archive.org**: Not searched (not needed since originals are live).

---

## Task 2: Tools for Parsing Retro Game Assembly into Structured AST

### A. Tree-Sitter Grammars for Assembly Languages

| Grammar | URL | Stars | ISA Coverage | Maturity | Notes |
|---------|-----|-------|-------------|----------|-------|
| **tree-sitter-asm** | https://github.com/RubixDev/tree-sitter-asm | 48 | Generic (any ISA) | Mature | MIT license, 20 forks. **Best starting point** -- parses labels, instructions, operands, comments generically. Used in Neovim/Helix. Handles NASM/GAS/MASM-like syntax. |
| **tree-sitter-x86asm** | https://github.com/bearcove/tree-sitter-x86asm | 31 | x86 (Intel syntax) | Stable | Apache-2.0. Specifically for Intel x86 -- not useful for retro, but shows the pattern for ISA-specific grammars. |
| **tree-sitter-m68k** | https://github.com/grahambates/tree-sitter-m68k | 16 | Motorola 68000 | Mature | MIT. **Directly useful for Genesis/Mega Drive** disassemblies. Same author as m68k-lsp. |
| **tree-sitter-asm6502** | https://github.com/stoneman1/tree-sitter-asm6502 | 3 | 6502 | Early | MIT. **Directly useful for NES**. Created Nov 2024, still early but functional. |
| **tree-sitter-uxntal** | https://github.com/Jummit/tree-sitter-uxntal | 5 | Uxntal (Varvara VM) | Stable | MIT. Niche -- for the Uxn virtual machine, not retro consoles. |
| **DieracDelta/asm-lsp** | https://github.com/DieracDelta/asm-lsp | 3 | RISC-V | WIP | LSP + tree-sitter grammar for RISC-V. Not retro, but shows the LSP approach. |

**NOT FOUND (gaps):**
- **tree-sitter-z80 / tree-sitter-gbz80** -- Does NOT exist. No grammar for Z80/Game Boy assembly. This is a significant gap.
- **tree-sitter-65816** -- Does NOT exist. No grammar for the 65816 (SNES CPU). Another gap.
- **tree-sitter-rgbds** -- Does NOT exist. No grammar specifically for RGBDS syntax.
- **tree-sitter-arm** -- There may be one for ARM (GBA), but it did not surface in the search. The generic tree-sitter-asm might partially handle ARM assembly.

### B. LSP Servers for Assembly Languages (include tree-sitter parsers)

| Tool | URL | Stars | ISA | Capabilities |
|------|-----|-------|-----|-------------|
| **m68k-lsp** | https://github.com/grahambates/m68k-lsp | 32 | 68000 | Full LSP: go-to-definition, hover, diagnostics, rename, completion. **Uses tree-sitter-m68k** internally. TypeScript. **Best-in-class for retro assembly**. |
| **asm-lsp (bergercookie)** | https://github.com/bergercookie/asm-lsp | ~450 (from memory) | x86/x86_64, ARM, RISC-V, z80(!) | Rust. Provides hover/completion with instruction docs. **Claims z80 support** -- worth checking. |

### C. Binary Analysis / Disassembly Frameworks (for call graph extraction from ROMs)

| Tool | URL | Stars | Capabilities | Retro ISAs |
|------|-----|-------|-------------|-----------|
| **Ghidra** | https://github.com/NationalSecurityAgency/ghidra | 65,967 | Full RE suite: disassembly, decompilation, call graphs, data flow. | Has 6502 (via Slaspec), 65816 (partial), Z80, 68000, ARM -- all retro CPUs. **Most complete option for call graph extraction from ROMs.** |
| **ghidra-snes-loader** | https://github.com/achan1989/ghidra-snes-loader | 43 | SNES ROM loader plugin for Ghidra. Handles LoROM/HiROM mapping. | 65816 (via Ghidra's built-in processor). Archived but functional. |
| **spedi** | https://github.com/abenkhadra/spedi | 108 | Speculative disassembly, CFG recovery, call-graph recovery from stripped binaries. | C++. Academic tool. ARM focus but architecture-agnostic approach. |
| **radare2/rizin** | (well-known) | ~20K+ | Scriptable RE framework with call graph analysis (`afl`, `agCd` commands). | Has 6502, z80, 68000, ARM processors. Python/JS scripting for graph export. |

### D. Universal-ctags Support for Assembly

Universal-ctags has a built-in **Asm** parser that handles common assembly patterns:
- Recognizes labels (symbols followed by `:`)
- Recognizes `.macro`, `.equ`, `.define` directives
- Recognizes SECTION directives

However, it is **architecture-agnostic and very basic** -- it will not understand RGBDS-specific directives like `SECTION "name", ROM0[$addr]`, or ca65 `.proc`/`.endproc` blocks.

**Status:** Works for basic label extraction from any assembly. Not sufficient for structured AST or call graph.

### E. Game-Specific Disassembly/Analysis Projects

These projects don't directly provide tools, but they represent the **input format** you would be parsing:

| Project | Platform | URL | Notes |
|---------|----------|-----|-------|
| **pokered** | Game Boy (Z80/RGBDS) | github.com/pret/pokered | Fully disassembled Pokemon Red. RGBDS format. The canonical example of your target input. |
| **pokeyellow, pokecrystal, pokegold** | Game Boy | github.com/pret/* | Same format, more games. |
| **sm64** | N64 (MIPS + C) | github.com/n64decomp/sm64 | Mostly C, some MIPS asm. |
| **Various GBA decomps** | GBA (ARM + C) | github.com/pret/pokeemerald etc. | Mostly C with some ARM/Thumb asm. |

### F. Recommended Approach for Your Use Case

Given that you want to parse **disassembled source code** (not binaries) into a graph of functions/labels/calls/data-refs, here is a tiered strategy:

#### Tier 1: Already solved (use existing tools)
- **C source (GBA, N64 decomps):** tree-sitter-c -- fully mature, extract functions/calls trivially
- **68000 assembly (Genesis):** tree-sitter-m68k + m68k-lsp -- the best retro assembly tooling available
- **6502 assembly (NES):** tree-sitter-asm6502 -- basic but functional, or tree-sitter-asm (generic)

#### Tier 2: Workable with generic grammar + custom queries
- **65816 assembly (SNES):** tree-sitter-asm (generic) can parse labels/instructions but won't understand 65816-specific addressing modes. Add tree-sitter query patterns for `JSR`, `JSL`, `RTS`, `RTL` to extract call graph.
- **ARM assembly (GBA):** tree-sitter-asm (generic) handles ARM syntax reasonably. Filter for `BL`/`BX` instructions for call graph.

#### Tier 3: Needs custom grammar (biggest gap)
- **Z80/GBZ80 assembly (Game Boy via RGBDS):** No tree-sitter grammar exists. Options:
  1. **Write tree-sitter-rgbds** -- 2-3 days of work modeling RGBDS syntax (SECTION, labels, instructions, INCLUDE, macros, REPT/ENDR, CHARMAP, etc.)
  2. **Use regex/custom Python parser** -- RGBDS syntax is relatively simple (one instruction per line, labels on column 0 or with colon). A Python parser for `CALL`, `JP`, `JR` + label definitions can build a call graph in ~200 lines.
  3. **Use Ghidra on the ROM** -- Load the ROM directly, get call graph from binary analysis (bypasses source parsing entirely)

#### Tier 4: Alternative approach -- Ghidra scripting
For **all** platforms, you can skip source parsing and use Ghidra:
1. Load ROM into Ghidra (with appropriate loader plugin)
2. Run auto-analysis (Ghidra handles 6502, Z80, 65816, 68000, ARM)
3. Export call graph via Ghidra Python script: `currentProgram.getFunctionManager().getFunctions(True)` + `getReferencesFrom()`
4. Output to JSON/GraphML for import into your graph DB

This is the **most reliable** approach for binary ROMs but does not work for source-level analysis of decomp projects.

---

## Summary Table: Coverage per Platform

| Platform | CPU | Existing tree-sitter | LSP | Ghidra | Best approach |
|----------|-----|---------------------|-----|--------|---------------|
| Game Boy | Z80/GBZ80 | **NONE** | bergercookie/asm-lsp (z80?) | Yes (SM83/GBZ80) | Custom tree-sitter-rgbds OR regex parser |
| NES | 6502 | tree-sitter-asm6502 | No | Yes (6502) | tree-sitter-asm6502 + custom queries |
| SNES | 65816 | tree-sitter-asm (generic) | No | Yes (65816 via ghidra-snes-loader) | Generic grammar + JSR/JSL pattern matching |
| GBA | ARM/Thumb + C | tree-sitter-c (for C), tree-sitter-asm (for asm) | No | Yes (ARM) | tree-sitter-c for C files, generic asm for .s files |
| Genesis | 68000 | **tree-sitter-m68k** | **m68k-lsp** | Yes (68000) | tree-sitter-m68k -- best retro asm coverage |
| N64 | MIPS + C | tree-sitter-c | No | Yes (MIPS) | tree-sitter-c for decomps |
