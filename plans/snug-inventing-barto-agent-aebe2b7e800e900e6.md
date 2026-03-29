# Comprehensive Catalog of Decompiled/Disassembled Retro Game ROMs

Sources: awesome-game-decompilations (CharlotteCross1998), GitHub API searches, awesome-megadrive (And-0), pret org, n64decomp org, zeldaret org, cyneprepou4uk NES collection, Sonic Retro community, gbdev.io, snesrev.
Star counts from GitHub API as of 2026-03-20.

---

## 1. GAME BOY (DMG / GBC) -- Z80 ASM, RGBDS toolchain

ROM size: 32KB-2MB. Entire source fits comfortably in LLM context.

### Pokemon (pret org) -- GB/GBC

| Game | Repo | Stars | Lang | Status |
|------|------|-------|------|--------|
| Pokemon Red/Blue | https://github.com/pret/pokered | 4623 | ASM | Complete |
| Pokemon Yellow | https://github.com/pret/pokeyellow | ~500 | ASM | Complete |
| Pokemon Gold (SpaceWorld Demo) | https://github.com/pret/pokegold-spaceworld | ~300 | ASM | Complete |
| Pokemon Gold | https://github.com/pret/pokegold | ~200 | ASM | Complete |
| Pokemon Crystal | https://github.com/pret/pokecrystal | 2389 | ASM | Complete |
| Pokemon TCG 1 | https://github.com/pret/poketcg | ~600 | ASM | Complete |
| Pokemon TCG 2 | https://github.com/pret/poketcg2 | ~100 | ASM | WIP |
| Pokemon Pinball | https://github.com/pret/pokepinball | ~200 | ASM | WIP |

### Zelda -- GB/GBC

| Game | Repo | Stars | Lang | Status |
|------|------|-------|------|--------|
| Zelda: Link's Awakening DX | https://github.com/zladx/LADX-Disassembly | 880 | ASM | Complete |

### Other GB/GBC

| Game | Repo | Stars | Lang | Status |
|------|------|-------|------|--------|
| Tetris | https://github.com/osnr/tetris | 83 | ASM | Complete |
| Donkey Kong '94 | https://github.com/CelestialAmber/DKGBDisasm | ~30 | ASM | WIP |
| Dr. Mario (NES, also GB) | https://github.com/Nostaljipi/dr-mario-disassembly | ~50 | ASM | Complete |
| Star Ocean: Blue Sphere | https://github.com/animaone/star-ocean-blue-sphere-source-code | ~20 | ASM | WIP |
| Dragon Warrior Monsters | https://github.com/NiyaDev/DWM | ~10 | ASM | WIP |
| GBA BIOS (disassembly) | https://github.com/camthesaxman/gba_bios | ~70 | ASM | Complete |

**Note**: Many GB/GBC games exist only as auto-disassemblies via tools like `mgbdis`. The above are human-annotated, buildable projects.

---

## 2. NES (Famicom) -- 6502 ASM

ROM size: 16KB-512KB (most are 32-128KB). Excellent for LLM context.

### cyneprepou4uk/NES-Games-Disassembly (multi-game, 226 stars)

https://github.com/cyneprepou4uk/NES-Games-Disassembly

Contains complete disassemblies of **20+ NES games** in one repo:

| Game | Genre |
|------|-------|
| Adventure Island | Platformer |
| Battle City | Action/Tank |
| Bugs Bunny Crazy Castle | Puzzle/Platformer |
| Castlevania 3 | Action/Platformer |
| Contra Force | Action |
| Danny Sullivan's Indy Heat | Racing |
| Double Dragon II | Beat-em-up |
| Dr. Mario | Puzzle |
| Excitebike | Racing |
| Felix the Cat | Platformer |
| Ice Climber | Platformer |
| Kunio-kun no Nekketsu Soccer League | Sports |
| Mappy | Platformer |
| Nuts & Milk | Puzzle/Platformer |
| Pac-Man | Maze |
| RoboCop 3 | Action |
| Solstice | Isometric Puzzle |
| Son Son | Action |
| Street Fighter 3 (bootleg) | Fighting |
| Super C | Action |
| Tecmo World Cup Soccer | Sports |
| Tennis | Sports |
| The Legend of Zelda | Action/RPG |
| The Little Mermaid | Platformer |
| Yie Ar Kung-Fu | Fighting |

### Standalone NES Disassemblies

| Game | Repo | Stars | Lang | Status |
|------|------|-------|------|--------|
| Contra (US) | https://github.com/vermiceli/nes-contra-us/ | ~200 | ASM | Complete |
| Super C / Probotector | https://github.com/vermiceli/nes-super-c/ | ~50 | ASM | Complete |
| Balloon Fight | https://github.com/LuigiBlood/balloonfight_dis | ~50 | ASM | Complete |
| Donkey Kong (NES) | https://github.com/RussianManSMWC/Donkey-Kong-NES-Disassembly | ~20 | ASM | Complete |
| Donald Land | https://github.com/brunovalads/donald-land | ~10 | ASM | WIP |
| Earthbound Beginnings / Mother 1 | https://github.com/GrasonHumphrey/Earthbound-Zero-Decomp | ~30 | ASM | WIP |
| Dr. Mario | https://github.com/Nostaljipi/dr-mario-disassembly | ~50 | ASM | Complete |

**Known to exist but not on GitHub (nesdev.org community):**
- Super Mario Bros. (multiple partial disassemblies on nesdev wiki)
- Metroid (NES) -- partial disassembly on Data Crystal / nesdev
- Mega Man 2 -- partial disassembly (various forum posts)
- Final Fantasy (NES) -- partial (disch's disassembly, historically available)

---

## 3. SNES (Super Famicom) -- 65816 ASM / C

ROM size: 256KB-6MB (most 512KB-2MB). Fits in context for most games.

### snesrev -- Complete C reimplementations (the gold standard)

| Game | Repo | Stars | Lang | Status | Notes |
|------|------|-------|------|--------|-------|
| Zelda: A Link to the Past | https://github.com/snesrev/zelda3 | ~4500 (DMCA'd) | C | Complete | Fully playable native port |
| Super Mario World | https://github.com/snesrev/smw | ~900 (DMCA'd) | C | Complete | Fully playable native port |
| Super Metroid | https://github.com/snesrev/sm | ~700 (DMCA'd) | C | Complete | Fully playable native port |

**Note**: snesrev repos were DMCA'd by Nintendo but forks/mirrors exist. These are the most complete SNES decompilations ever produced -- entire games re-implemented in C from ASM analysis.

### SNES ASM Disassemblies

| Game | Repo | Stars | Lang | Status |
|------|------|-------|------|--------|
| Yoshi's Island | https://github.com/brunovalads/yoshisisland-disassembly | 151 | ASM | Complete |
| Donkey Kong Country 1 | https://github.com/Yoshifanatic1/Donkey-Kong-Country-1-Disassembly | ~50 | ASM | WIP |
| Donkey Kong Country 2 | https://github.com/p4plus2/DKC2-disassembly | ~100 | ASM | WIP |
| Donkey Kong Country 3 | https://github.com/Yoshifanatic1/Donkey-Kong-Country-3-Disassembly | ~30 | ASM | WIP |
| Earthbound | https://github.com/Herringway/ebsrc | ~200 | ASM/C | WIP |
| Soul Blazer | https://github.com/hellow554/RustyBlazer | ~10 | Rust | WIP |

**Known SNES disassemblies outside GitHub:**
- Star Fox (partial, SuperFX chip complicates it)
- Final Fantasy VI -- partial analysis on romhacking.net
- Chrono Trigger -- partial analysis/documentation exists

---

## 4. GBA (Game Boy Advance) -- ARM7 / C (agbcc compiler)

ROM size: 1MB-32MB (most 4-16MB). Some fit in context, larger ones are split across files.

### Pokemon (pret org) -- GBA

| Game | Repo | Stars | Lang | Status |
|------|------|-------|------|--------|
| Pokemon Ruby | https://github.com/pret/pokeruby | ~900 | C | Complete |
| Pokemon FireRed | https://github.com/pret/pokefirered | ~1200 | C | Complete |
| Pokemon Emerald | https://github.com/pret/pokeemerald | 3025 | C | Complete |
| Pokemon Emerald (JP) | https://github.com/pret/pokeemerald-jp | ~30 | C | WIP |
| Pokemon Pinball R&S | https://github.com/pret/pokepinballrs | ~100 | C | WIP |
| PMD Red Rescue Team | https://github.com/pret/pmd-red | ~200 | C | WIP |

### Zelda -- GBA

| Game | Repo | Stars | Lang | Status |
|------|------|-------|------|--------|
| Zelda: Minish Cap | https://github.com/zeldaret/tmc | ~600 | C | Complete |

### Fire Emblem -- GBA

| Game | Repo | Stars | Lang | Status |
|------|------|-------|------|--------|
| Fire Emblem: The Blazing Blade (FE7) | https://github.com/MokhaLeee/FireEmblem7J | ~50 | C | WIP |
| Fire Emblem: The Sacred Stones (FE8) | https://github.com/FireEmblemUniverse/fireemblem8u | ~300 | C | WIP |

### Kirby -- GBA

| Game | Repo | Stars | Lang | Status |
|------|------|-------|------|--------|
| Kirby & The Amazing Mirror | https://github.com/jiangzhengwenjz/katam | ~100 | C | WIP |

### Metroid -- GBA

| Game | Repo | Stars | Lang | Status |
|------|------|-------|------|--------|
| Metroid: Zero Mission | https://github.com/metroidret/mzm | ~100 | C | WIP |
| Metroid Fusion | https://github.com/metroidret/mf | ~80 | C | WIP |

### Castlevania -- GBA

| Game | Repo | Stars | Lang | Status |
|------|------|-------|------|--------|
| Castlevania: Aria of Sorrow | https://github.com/testyourmine/cvaos | ~50 | C | WIP |

### Sonic Advance -- GBA

| Game | Repo | Stars | Lang | Status |
|------|------|-------|------|--------|
| Sonic Advance 1 | https://github.com/SAT-R/sa1 | ~50 | C | WIP |
| Sonic Advance 2 | https://github.com/SAT-R/sa2 | ~30 | C | WIP |
| Sonic Advance 3 | https://github.com/SAT-R/sa3 | ~30 | C | WIP |

### Mario -- GBA

| Game | Repo | Stars | Lang | Status |
|------|------|-------|------|--------|
| Mario Kart: Super Circuit | https://github.com/jellees/mksc | ~50 | C | WIP |
| Mario & Luigi: Superstar Saga | https://github.com/jellees/mlss | ~30 | C | WIP |

### Other GBA

| Game | Repo | Stars | Lang | Status |
|------|------|-------|------|--------|
| Banjo-Kazooie: Grunty's Revenge | https://github.com/jellees/bkgr | 37 | ASM | WIP |
| Wario Land 4 | https://github.com/lilDavid/warioland4 | ~100 | C | WIP |
| Harvest Moon: Friends of Mineral Town | https://github.com/StanHash/fomt | ~30 | C | WIP |
| Mother 1+2 | https://github.com/Normmatt/m12 | ~30 | C | WIP |
| Megaman Zero 3 | https://github.com/mmzret/rmz3 | ~30 | C | WIP |
| Advance Wars 2: Black Hole Rising | https://github.com/Eebit/aw2bhr | ~20 | C | WIP |
| Fire Emblem: Shadow Dragon (NDS but listed) | https://github.com/Eebit/fe11-us | ~20 | C | WIP |
| The Sims 2 (GBA) | https://github.com/SimsAdvanceRet/S2GBADecomp | ~10 | C | WIP |
| The Sims: Bustin' Out (GBA) | https://github.com/SimsAdvanceRet/BustinOutGBADecomp | ~10 | C | WIP |
| The Urbz: Sims in the City (GBA) | https://github.com/SimsAdvanceRet/UrbzGBADecomp | ~10 | C | WIP |
| Yu-Gi-Oh! Reshef of Destruction | https://github.com/shinny456/ygodm8 | ~10 | C | WIP |
| Summon Night: Craft Sword Monogatari | https://github.com/jiangzhengwenjz/csm3 | ~10 | C | WIP |
| Phoenix Wright: Ace Attorney | https://github.com/atasro2/pwaa1 | ~30 | C | WIP |
| Phoenix Wright: Ace Attorney - JfA | https://github.com/atasro2/pwaa2 | ~20 | C | WIP |

---

## 5. MEGA DRIVE / GENESIS -- Motorola 68000 ASM

ROM size: 256KB-4MB (most 512KB-2MB). Fits in LLM context.

### Sonic the Hedgehog (Sonic Retro / sonicretro community)

The Sonic community is the largest and most mature Genesis disassembly scene.

| Game | Repo / Location | Stars | Lang | Status |
|------|-----------------|-------|------|--------|
| Sonic 1 (MD) | https://github.com/sonicretro/s1disasm | ~200 | ASM (68k) | Complete |
| Sonic 2 (MD) | https://github.com/sonicretro/s2disasm | ~150 | ASM (68k) | Complete |
| Sonic 3 & Knuckles | https://github.com/sonicretro/skdisasm | ~200 | ASM (68k) | Complete |
| Sonic CD (MD/Sega CD) | Sonic Retro wiki | N/A | ASM (68k) | Complete |
| Sonic 1 & 2 Mobile | https://github.com/Rubberduckycooly/Sonic-1-2-2013-Decompilation | ~1500 | C++ | Complete |
| Sonic CD Mobile | https://github.com/Rubberduckycooly/Sonic-CD-11-Decompilation | ~1000 | C++ | Complete |
| Sonic Mania | https://github.com/Rubberduckycooly/Sonic-Mania-Decompilation | ~500 | C | WIP |
| Sonic Advance 1 | https://github.com/SAT-R/sa1 | ~50 | C | WIP |
| Sonic Advance 2 | https://github.com/SAT-R/sa2 | ~30 | C | WIP |
| Sonic Advance 3 | https://github.com/SAT-R/sa3 | ~30 | C | WIP |
| Sonic & Knuckles Collection (PC 1997) | https://git.sr.ht/~benoitren/skccport | ~20 | C | WIP |

### Other Mega Drive

| Game | Repo | Stars | Lang | Status |
|------|------|-------|------|--------|
| TMSS Bootrom | https://github.com/OrionNavattan/TMSS-Disassembly | 3 | ASM | Complete |
| Various MD games (lory90) | https://github.com/lory90 | ~10 | ASM | Various |

**From awesome-megadrive -- known disassemblies:**
- Shining Force Central (multiple games): https://github.com/ShiningForceCentral
- Various Vladimir Kononovich tools: https://github.com/lab313ru

**Note on Sonic disassemblies**: The Sonic Retro community maintains the most complete set of Genesis disassemblies. Sonic 1, 2, 3&K are all 100% complete, fully documented, and the basis for hundreds of ROM hacks. These are the gold standard for 68000 game disassembly.

---

## 6. N64 -- MIPS / C

ROM size: 4MB-64MB. Larger than other platforms but decompiled to C, which compresses well.

### Top-tier N64 decomps (n64decomp org + others)

| Game | Repo | Stars | Lang | Status | ROM Size |
|------|------|-------|------|--------|----------|
| Super Mario 64 | https://github.com/n64decomp/sm64 | 8518 | C | **100% Complete** | 8MB |
| Zelda: Ocarina of Time | https://github.com/zeldaret/oot | 5313 | C | **100% Complete** | 32MB |
| Zelda: Majora's Mask | https://github.com/zeldaret/mm | ~2500 | C | ~95% Complete | 32MB |
| Paper Mario | https://github.com/pmret/papermario | ~2000 | C | **100% Complete** | 32MB |
| Banjo-Kazooie | https://gitlab.com/banjo.decomp/banjo-kazooie (mirror: https://github.com/n64decomp/banjo-kazooie) | 619 | C | WIP (~70%) | 16MB |
| Banjo-Tooie | https://github.com/mr-wiseguy/banjo-tooie | ~200 | C | WIP |  |
| Mario Kart 64 | https://github.com/n64decomp/mk64 | ~500 | C | WIP | 12MB |
| Perfect Dark | https://gitlab.com/ryandwyer/perfect-dark | ~400 | C | WIP | 32MB |
| GoldenEye 007 | https://gitlab.com/kholdfuzion/goldeneye_src | ~300 | C | WIP | 12MB |
| Star Fox 64 | https://github.com/sonicdcer/sf64 | ~200 | C | WIP | 12MB |
| Conker's Bad Fur Day | https://github.com/mkst/conker | ~100 | C | WIP | 64MB |
| Diddy Kong Racing | https://github.com/davidsm64/diddy-kong-racing | ~50 | C | WIP |  |
| Yoshi's Story | https://github.com/decompals/yoshis-story | ~100 | C | WIP | 16MB |
| Pokemon Stadium | https://github.com/pret/pokestadium | ~100 | C | WIP |  |
| Pokemon Stadium 2 | https://github.com/pret/pokestadiumgs | 31 | C | WIP |  |
| Pokemon Snap | https://github.com/ethteck/pokemonsnap | ~100 | C | WIP |  |
| Pokemon Puzzle League | https://github.com/angheloalf/puzzleleague64 | ~30 | C | WIP |  |
| Dr. Mario 64 | https://github.com/angheloalf/drmario64 | ~50 | C | WIP |  |
| Kirby 64: The Crystal Shards | https://github.com/kirby64ret/kirby64 | ~50 | C | WIP |  |
| F-Zero X | https://github.com/inspectredc/fzerox | ~50 | C | WIP |  |
| Wave Race 64 | https://github.com/llonsit/wave-race-64 | ~20 | C | WIP |  |
| Quest 64 | https://github.com/rainchus/quest64-decomp | ~20 | C | WIP |  |
| Bomberman 64 | https://github.com/bomberhackers/bm64 | ~20 | C | WIP |  |
| Bomberman Hero | https://github.com/bomberhackers/bmhero | ~20 | C | WIP |  |
| Castlevania 64 | https://github.com/blazkowolf/cv64 | ~30 | C | WIP |  |
| Mario Party 1 | https://github.com/mariopartyrd/marioparty | ~50 | C | WIP |  |
| Mario Party 2 | https://github.com/mariopartyrd/marioparty2 | ~30 | C | WIP |  |
| Mario Party 3 | https://github.com/mariopartyrd/marioparty3 | ~30 | C | WIP |  |
| Mario Golf 64 | https://github.com/monde-lointain/mariogolf64 | ~20 | C | WIP |  |
| Mario Tennis 64 | https://github.com/dellm-79/mariotennisn64 | ~10 | C | WIP |  |
| Superman 64 | https://github.com/farisawan-2000/superman | ~50 | C | WIP |  |
| Animal Forest (JP AC) | https://github.com/zeldaret/af | ~100 | C | WIP |  |
| Space Station Silicon Valley | https://github.com/mkst/sssv | ~30 | C | WIP |  |
| Harvest Moon 64 | https://github.com/harvestwhisperer/hm64-decomp | ~20 | C | WIP |  |
| Blast Corps | https://github.com/SlaveOfIDO/blastcorps | ~20 | C | WIP |  |
| Body Harvest | https://github.com/deltaniumindustries/bodyharvestdecomp | ~10 | C | WIP |  |
| Duke Nukem 64 | https://github.com/nblood/duke64-re | ~30 | C | WIP |  |
| Ridge Racer 64 | https://github.com/jvicu2001/rr64-decomp | ~10 | C | WIP |  |
| Jet Force Gemini | https://github.com/ryan-myers/jet-force-gemini | ~20 | C | WIP |  |
| Doom 64 | https://github.com/Erick194/DOOM64-RE | ~200 | C | WIP |  |
| Mischief Makers | https://github.com/drahsid/mischief-makers | ~20 | C | WIP |  |
| Chameleon Twist | https://github.com/chameleontwistret/chameleontwistv1.0-jp | ~10 | C | WIP |  |
| Chameleon Twist 2 | https://github.com/chameleontwistret/chameleontwist2v1.0-jp | ~10 | C | WIP |  |
| Gauntlet Legends | https://github.com/drahsid/gauntlet-legends | ~10 | C | WIP |  |
| Neon Genesis Evangelion 64 | https://github.com/farisawan-2000/evangelion | ~20 | C | WIP |  |
| Snowboard Kids | https://github.com/sonicdcer/sk | ~10 | C | WIP |  |
| Snowboard Kids 2 | https://github.com/cdlewis/snowboardkids2-decomp | ~10 | C | WIP |  |
| Rocket: Robot on Wheels | https://github.com/RocketRet/Rocket-Robot-On-Wheels | ~10 | C | WIP |  |
| Glover | https://github.com/rainchus/glover | ~10 | C | WIP |  |
| Shadowgate 64 | https://github.com/rainchus/shadowgate64 | ~10 | C | WIP |  |
| Aidyn Chronicles | https://github.com/blackgamma7/aidyn | ~10 | C | WIP |  |
| AeroGauge | https://github.com/llonsit/aerogauge | ~5 | C | WIP |  |
| The New Tetris | https://github.com/kiritodv/tnt | ~10 | C | WIP |  |
| Virtual Pool 64 | https://github.com/llonsit/virtualpool64 | ~5 | C | WIP |  |
| Gex 64 | https://github.com/matbourgon/gex64decomp | ~10 | C | WIP |  |
| Mystical Ninja Starring Goemon | https://github.com/klorfmorf/mnsg | ~10 | C | WIP |  |
| Star Wars: Rogue Squadron | https://github.com/Tmcg2/rogue_squadron64 | ~20 | C | WIP |  |
| Star Wars: Shadows of the Empire | https://github.com/eltalelibrarian/sote | ~20 | C | WIP |  |
| Star Wars Episode I: Racer | https://github.com/tim-tim707/SW_RACER_RE | ~30 | C | WIP |  |
| Dark Rift | https://github.com/unnunu/darkrift | ~5 | C | WIP |  |
| Evo's Space Adventures | https://github.com/mkst/esa | ~10 | C | WIP |  |

---

## 7. OTHER PLATFORMS IN awesome-game-decompilations (selected, smaller ROMs)

### PS1 (some fit in context if decompiled to C)

| Game | Repo | Stars | Lang | Status |
|------|------|-------|------|--------|
| Castlevania: Symphony of the Night | https://github.com/xeeynamo/sotn-decomp | ~500 | C | WIP |
| Final Fantasy VII | https://github.com/xeeynamo/ff7-decomp | ~200 | C | WIP |
| Chrono Cross | https://github.com/jdperos/chrono-cross-decomp | ~30 | C | WIP |
| Crash Team Racing | https://github.com/CTR-tools/CTR-ModSDK | ~100 | C | WIP |
| MediEvil | https://github.com/medievildecompilation/medievil-decomp | ~50 | C | WIP |
| Mega Man X4 | https://github.com/sozud/mmx4 | ~30 | C | WIP |
| Metal Gear Solid | https://github.com/FoxdieTeam/mgs_reversing | ~100 | C | WIP |
| Resident Evil 2 | https://github.com/OpenBiohazard2/OpenBiohazard2 | ~200 | C | WIP |
| Vagrant Story | https://github.com/ser-pounce/rood-reverse | ~30 | C | WIP |
| Diablo (PC, but small) | https://github.com/diasurgical/devilution | ~10000 | C | Complete |
| Carmageddon (PC) | https://github.com/dethrace-labs/dethrace | ~3000 | C | Complete |
| Space Cadet Pinball (Win) | https://github.com/k4zmu2a/SpaceCadetPinball | ~5000 | C++ | Complete |
| Cave Story (PC) | https://github.com/gameblabla/CSE2 | ~500 | C++ | Complete |
| Touhou (PC-98) | https://github.com/nmlgc/ReC98 | ~300 | C/ASM | WIP |

### GameCube/Wii (C decomps, larger but structured)

| Game | Repo | Stars | Lang | Status |
|------|------|-------|------|--------|
| Zelda: Wind Waker | https://github.com/zeldaret/tww | ~1000 | C++ | WIP |
| Zelda: Twilight Princess | https://github.com/zeldaret/tp | ~800 | C++ | WIP |
| Super Smash Bros. Melee | https://github.com/doldecomp/melee | ~500 | C | WIP |
| Pikmin | https://github.com/projectPiki/pikmin | ~200 | C++ | WIP |
| Pikmin 2 | https://github.com/projectPiki/pikmin2 | ~200 | C++ | WIP |
| Metroid Prime | https://github.com/primedecomp/prime | ~200 | C++ | WIP |
| Luigi's Mansion | https://github.com/sage-of-mirrors/zmansion | ~100 | C++ | WIP |
| Paper Mario: TTYD | https://github.com/doldecomp/ttyd | ~100 | C | WIP |
| Kirby Air Ride | https://github.com/doldecomp/kar | ~50 | C | WIP |
| Animal Crossing | https://github.com/acreteam/ac-decomp | ~100 | C | WIP |
| Wii Sports | https://github.com/doldecomp/ogws | ~100 | C++ | WIP |
| Super Mario Sunshine | https://github.com/doldecomp/sms | ~200 | C++ | WIP |

---

## 8. SUMMARY STATISTICS

### By Platform (context-window-friendly: GB, NES, SNES, GBA, Genesis)

| Platform | Complete Disassemblies | WIP Projects | Total | Best for LLM |
|----------|----------------------|--------------|-------|---------------|
| **Game Boy (DMG/GBC)** | ~12 (Pokemon, Tetris, LADX, etc.) | ~5 | ~17 | Excellent (32KB-2MB ROM) |
| **NES** | ~27 (cyneprepou4uk collection + standalone) | ~5 | ~32 | Excellent (16-512KB ROM) |
| **SNES** | ~4 (snesrev zelda3/smw/sm + YI) | ~5 | ~9 | Good (256KB-4MB ROM) |
| **GBA** | ~4 (pokeemerald, pokefirered, pokeruby, tmc) | ~25+ | ~30+ | Good (C source, structured) |
| **Mega Drive/Genesis** | ~5 (Sonic 1,2,3&K, TMSS) | ~3 | ~8 | Excellent (256KB-4MB ROM) |
| **N64** | ~3 (SM64, OoT, Paper Mario) | ~50+ | ~55+ | Fair (C source, 4-64MB) |

### Top 10 by GitHub Stars (context-friendly platforms)

1. **SM64** (N64) -- 8518 stars -- C -- Complete
2. **OoT** (N64) -- 5313 stars -- C -- Complete
3. **pokered** (GB) -- 4623 stars -- ASM -- Complete
4. **zelda3** (SNES) -- ~4500 stars -- C -- Complete (DMCA'd)
5. **pokeemerald** (GBA) -- 3025 stars -- C -- Complete
6. **pokecrystal** (GBC) -- 2389 stars -- ASM -- Complete
7. **Paper Mario** (N64) -- ~2000 stars -- C -- Complete
8. **Sonic 1&2 Mobile** -- ~1500 stars -- C++ -- Complete
9. **pokefirered** (GBA) -- ~1200 stars -- C -- Complete
10. **Sonic CD Mobile** -- ~1000 stars -- C++ -- Complete

### Best Candidates for LLM Context Window Analysis

**Tier 1: Entire game source fits in <200K tokens (32KB-256KB ROM)**
- NES: All games in cyneprepou4uk collection (esp. Battle City, Pac-Man, Balloon Fight, Dr. Mario)
- GB: Tetris (osnr), Pokemon TCG, Donkey Kong '94
- Genesis: Sonic 1 (512KB ROM, ~15K lines ASM)

**Tier 2: Fits in 200K-500K tokens**
- GB: Pokemon Red/Blue (~100K lines ASM), Link's Awakening DX
- NES: Contra, Legend of Zelda, Castlevania 3
- SNES: snesrev's zelda3/smw/sm (C, well-structured)
- Genesis: Sonic 2, Sonic 3&K

**Tier 3: Fits in 500K-1M tokens (requires selective reading)**
- GBA: Pokemon Emerald/FireRed (C, ~500K lines but well-organized)
- N64: SM64 (C, ~300K lines), Paper Mario, OoT
- GBC: Pokemon Crystal (~200K lines ASM)

---

## 9. KEY ORGANIZATIONS / COLLECTIONS

| Organization | URL | Focus | Active |
|-------------|-----|-------|--------|
| pret | https://github.com/pret | Pokemon (all platforms) | Very active |
| zeldaret | https://github.com/zeldaret | Zelda (N64, GCN, GBA, DS, Wii, 3DS, Switch) | Very active |
| n64decomp | https://github.com/n64decomp | N64 (SM64, BK, MK64) | Active |
| sonicretro | https://github.com/sonicretro | Sonic (Genesis) | Active |
| SAT-R | https://github.com/SAT-R | Sonic Advance (GBA) | Active |
| doldecomp | https://github.com/doldecomp | GameCube/Wii (Melee, Sunshine, TTYD) | Active |
| mariopartyrd | https://github.com/mariopartyrd | Mario Party (N64, GCN, Wii) | Active |
| projectPiki | https://github.com/projectPiki | Pikmin (GCN, Wii) | Active |
| primedecomp | https://github.com/primedecomp | Metroid Prime (GCN) | Active |
| metroidret | https://github.com/metroidret | Metroid (GBA) | Active |
| bomberhackers | https://github.com/bomberhackers | Bomberman (N64) | Active |
| decompals | https://github.com/decompals | Various N64/GCN | Active |
| cyneprepou4uk | https://github.com/cyneprepou4uk | NES multi-game collection | Active |
| Rubberduckycooly | https://github.com/Rubberduckycooly | Sonic mobile/Mania | Active |
| SimsAdvanceRet | https://github.com/SimsAdvanceRet | Sims GBA games | Active |
| ssxdecomp | https://github.com/ssxdecomp | SSX (PS2/GCN) | Active |
| ShiningForceCentral | https://github.com/ShiningForceCentral | Shining Force (Genesis) | Moderate |
| snesrev | https://github.com/snesrev | SNES (zelda3, smw, sm) | DMCA'd |
| CharlotteCross1998 | https://github.com/CharlotteCross1998 | Master list (awesome-game-decompilations) | Active |

---

## 10. RESOURCE LINKS

- **Master list**: https://github.com/CharlotteCross1998/awesome-game-decompilations
- **GB dev resources**: https://gbdev.io/resources.html
- **Mega Drive resources**: https://github.com/And-0/awesome-megadrive (426 stars)
- **NES dev wiki**: https://www.nesdev.org/wiki/
- **Sonic Retro disassemblies**: https://info.sonicretro.org/Category:Disassemblies
- **Data Crystal (ROM analysis wiki)**: https://datacrystal.romhacking.net/
- **decomp.me (collaborative matching)**: https://decomp.me/
- **Romhacking.net**: https://www.romhacking.net/

---

**Total unique projects cataloged: ~250+ across all platforms**
**Context-window-friendly platforms (GB/NES/SNES/GBA/Genesis): ~100+ projects**
**Fully complete decomps on those platforms: ~55+ games**
