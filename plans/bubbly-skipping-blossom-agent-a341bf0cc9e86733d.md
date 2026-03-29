# Retro Game Decompilation/Disassembly Projects -- Comprehensive Clone List

**Methodology**: Queried GitHub API (orgs: `pret`, `zeldaret`, `decompals`, `sonicretro`, `snesrev`, `n64decomp`, `doldecomp`, `SAT-R`, `pmret`, `mariopartyrd`, `projectPiki`, `primedecomp`, `metroidret`, `bomberhackers`), plus the definitive community list at [awesome-game-decompilations](https://github.com/CharlotteCross1998/awesome-game-decompilations). Cross-referenced with GitHub search API results.

**Filtering criteria**: Only retro platforms (GB/GBC/GBA/NES/SNES/Genesis/N64/DS/PSX/Saturn/GC/Wii). Only substantial projects (not 1-file stubs). Excludes everything already in the user's collection.

**Legend**:
- **Type**: D = Decompilation (C/C++), A = Disassembly (ASM)
- **Status**: BP = Byte-perfect, NP = Near-perfect/playable, WIP = Work in progress (but substantial)
- **Roguelike relevance**: marked with `[RL]` -- dungeon crawlers, roguelikes, RPGs with procedural/dungeon mechanics

---

## Game Boy / Game Boy Color

| Game | Repo | Type | Lang | Status | License | Roguelike? | Clone |
|------|------|------|------|--------|---------|------------|-------|
| Pokemon TCG 2 | `pret/poketcg2` | A | ASM | WIP | none | | `git clone https://github.com/pret/poketcg2` |
| Pokemon Puzzle Challenge | `pret/pokepuzzle` | A | ASM | WIP | none | | `git clone https://github.com/pret/pokepuzzle` |
| Pokemon Gold (SpaceWorld Demo) | `pret/pokegold-spaceworld` | A | ASM | BP | none | | `git clone https://github.com/pret/pokegold-spaceworld` |
| Dragon Warrior Monsters | `NiyaDev/DWM` | D | C | WIP | ? | **[RL]** breeding+dungeon | `git clone https://github.com/NiyaDev/DWM` |
| Star Ocean: Blue Sphere | `animaone/star-ocean-blue-sphere-source-code` | A | ASM | WIP | ? | | `git clone https://github.com/animaone/star-ocean-blue-sphere-source-code` |
| Azure Dreams | `forestbelton/azure` | D | C | WIP | ? | **[RL]** tower roguelike | `git clone https://github.com/forestbelton/azure` |
| Donkey Kong '94 | already have (DKGBDisasm) | -- | -- | -- | -- | -- | -- |

## Game Boy Advance

| Game | Repo | Type | Lang | Status | License | Roguelike? | Clone |
|------|------|------|------|--------|---------|------------|-------|
| Sonic Advance 1 | `SAT-R/sa1` | D | C | WIP | none | | `git clone https://github.com/SAT-R/sa1` |
| Sonic Advance 3 | `SAT-R/sa3` | D | C | WIP | none | | `git clone https://github.com/SAT-R/sa3` |
| Advance Wars 1 | `ketsuban/advancewars` | A | ASM | WIP | ? | | `git clone https://github.com/ketsuban/advancewars` |
| Fire Emblem: The Blazing Blade (FE7) | `MokhaLeee/FireEmblem7J` | D | C | WIP | ? | | `git clone https://github.com/MokhaLeee/FireEmblem7J` |
| Banjo-Kazooie: Grunty's Revenge | `jellees/bkgr` | D | C | WIP | ? | | `git clone https://github.com/jellees/bkgr` |
| Mario & Luigi: Superstar Saga | `jellees/mlss` | D | C | WIP | ? | **[RL]** RPG combat | `git clone https://github.com/jellees/mlss` |
| Harvest Moon: Friends of Mineral Town | `StanHash/fomt` | D | C | WIP | ? | | `git clone https://github.com/StanHash/fomt` |
| Kirby & The Amazing Mirror | already have (katam) | -- | -- | -- | -- | -- | -- |
| Metroid Fusion | already have (mf) | -- | -- | -- | -- | -- | -- |
| Metroid: Zero Mission | already have (mzm) | -- | -- | -- | -- | -- | -- |
| Mega Man Zero 3 | `mmzret/rmz3` | D | C | WIP | ? | | `git clone https://github.com/mmzret/rmz3` |
| Pokemon Emerald (JP) | `pret/pokeemerald-jp` | A | ASM | WIP | none | | `git clone https://github.com/pret/pokeemerald-jp` |
| Castlevania: Order of Ecclesia | `lagolunatic/ooe` | D | C | WIP | ? | **[RL]** dungeon | `git clone https://github.com/lagolunatic/ooe` |
| Mother 1+2 | `Normmatt/m12` | D | C | WIP | ? | **[RL]** RPG | `git clone https://github.com/Normmatt/m12` |
| Summon Night: Craft Sword | `jiangzhengwenjz/csm3` | D | C | WIP | ? | **[RL]** action RPG | `git clone https://github.com/jiangzhengwenjz/csm3` |
| Yu-Gi-Oh! Reshef of Destruction | `shinny456/ygodm8` | D | C | WIP | ? | | `git clone https://github.com/shinny456/ygodm8` |
| Custom Robo GX | `pizdex/robogx` | D | C | WIP | ? | | `git clone https://github.com/pizdex/robogx` |
| Berry Fix (Emerald/FireRed) | `pret/berry-fix` | D | C | BP | none | | `git clone https://github.com/pret/berry-fix` |
| Colosseum GBA Multiboot | `pret/colosseum-mb` | D | C++ | WIP | none | | `git clone https://github.com/pret/colosseum-mb` |
| Fire Emblem: Shadow Dragon (DS) | `Eebit/fe11-us` | D | C | WIP | ? | | `git clone https://github.com/Eebit/fe11-us` |

## NES / Famicom

| Game | Repo | Type | Lang | Status | License | Roguelike? | Clone |
|------|------|------|------|--------|---------|------------|-------|
| Legend of Zelda 1 | `aldonunez/zelda1-disassembly` | A | ASM | BP | ? | **[RL]** dungeon crawl | `git clone https://github.com/aldonunez/zelda1-disassembly` |
| Dragon Warrior | `nmikstas/dragon-warrior-disassembly` | A | ASM | NP | ? | **[RL]** RPG | `git clone https://github.com/nmikstas/dragon-warrior-disassembly` |
| Mike Tyson's Punch-Out!! | `nmikstas/mike-tysons-punch-out-disassembly` | A | ASM | NP | ? | | `git clone https://github.com/nmikstas/mike-tysons-punch-out-disassembly` |
| Mega Man 1 | `lsmmega/mm1` | A | ASM | WIP | ? | | `git clone https://github.com/lsmmega/mm1` |
| Mega Man 2 | `lsmmega/mm2` | A | ASM | WIP | ? | | `git clone https://github.com/lsmmega/mm2` |
| Mega Man 2 (ca65) | `plasticsmoke/megaman2-disassembly-ca65` | A | ASM | WIP | ? | | `git clone https://github.com/plasticsmoke/megaman2-disassembly-ca65` |
| Mega Man 3 | `lsmmega/mm3` | A | ASM | WIP | ? | | `git clone https://github.com/lsmmega/mm3` |
| Mega Man 5 | `lsmmega/mm5` | A | ASM | WIP | ? | | `git clone https://github.com/lsmmega/mm5` |
| Kirby's Adventure | `yay58/Kirby-s-Adventure-Disassembly` | A | ASM | WIP | ? | | `git clone https://github.com/yay58/Kirby-s-Adventure-Disassembly` |
| Super Mario Bros 1 | `pgattic/smb1-disasm` | A | ASM | NP | ? | | `git clone https://github.com/pgattic/smb1-disasm` |
| Donkey Kong | already have | -- | -- | -- | -- | -- | -- |
| Donald Land | `brunovalads/donald-land` | A | ASM | WIP | ? | | `git clone https://github.com/brunovalads/donald-land` |
| Metal Gear (MSX2) | `GuillianSeed/MetalGear` | A | ASM | BP | ? | | `git clone https://github.com/GuillianSeed/MetalGear` |
| Earthbound Beginnings (Mother 1) | `GrasonHumphrey/Earthbound-Zero-Decomp` | D | C | WIP | ? | **[RL]** RPG | `git clone https://github.com/GrasonHumphrey/Earthbound-Zero-Decomp` |
| Battle City | `cyneprepou4uk/NES-Games-Disassembly` (subdir) | A | ASM | NP | ? | | already have (NES-Games-Disassembly) |

## SNES / Super Famicom

| Game | Repo | Type | Lang | Status | License | Roguelike? | Clone |
|------|------|------|------|--------|---------|------------|-------|
| Donkey Kong Country 3 | `Yoshifanatic1/Donkey-Kong-Country-3-Disassembly` | A | ASM | WIP | ? | | `git clone https://github.com/Yoshifanatic1/Donkey-Kong-Country-3-Disassembly` |
| Super Bomberman | `LIJI32/superbomberman` | A | ASM | BP | ? | | `git clone https://github.com/LIJI32/superbomberman` |
| Super Metroid (strager) | `strager/supermetroid` | A | ASM | NP | ? | **[RL]** metroidvania | `git clone https://github.com/strager/supermetroid` |
| Zelda 3 (ALTTP) | already have (snesrev/zelda3) | -- | -- | -- | -- | -- | -- |
| SMW | already have (snesrev/smw) | -- | -- | -- | -- | -- | -- |
| Super Metroid | already have (snesrev/sm) | -- | -- | -- | -- | -- | -- |
| DKC1 | already have | -- | -- | -- | -- | -- | -- |
| DKC2 | already have | -- | -- | -- | -- | -- | -- |
| Earthbound | already have (ebsrc) | -- | -- | -- | -- | -- | -- |
| Yoshi's Island | already have | -- | -- | -- | -- | -- | -- |

**Note on Chrono Trigger / FF4/5/6 SNES**: No public byte-perfect decomp projects found on GitHub. There are ROM hacking communities with partial analysis but no compilable disassembly/decomp repos of substance.

## Genesis / Mega Drive

| Game | Repo | Type | Lang | Status | License | Roguelike? | Clone |
|------|------|------|------|--------|---------|------------|-------|
| Sonic 3D Blast | `sonicretro/s3ddisasm` | A | ASM | NP | none | | `git clone https://github.com/sonicretro/s3ddisasm` |
| Ristar | `sonicretro/ristar` | A | ASM | NP | none | | `git clone https://github.com/sonicretro/ristar` |
| Knuckles' Chaotix (32X) | `sonicretro/chaotix` | A | ASM | NP | none | | `git clone https://github.com/sonicretro/chaotix` |
| Kid Chameleon | `sonicretro/kid-chameleon-disasm` | A | ASM | NP | none | | `git clone https://github.com/sonicretro/kid-chameleon-disasm` |
| Sonic 2 (SMS/GG) | `sonicretro/s2smsdisasm` | A | ASM | NP | none | | `git clone https://github.com/sonicretro/s2smsdisasm` |
| Sonic Spinball | `sonicretro/spindisasm` | A | ASM | NP | none | | `git clone https://github.com/sonicretro/spindisasm` |
| Knuckles in Sonic 2 | `sonicretro/ktes2` | A | ASM | NP | none | | `git clone https://github.com/sonicretro/ktes2` |

**Note on Streets of Rage 2 / Shining Force**: No compilable decomp/disassembly repos found. SoR2 has ROM hacking documentation but no structured project. Shining Force likewise -- only partial analysis exists.

## Nintendo 64

| Game | Repo | Type | Lang | Status | License | Roguelike? | Clone |
|------|------|------|------|--------|---------|------------|-------|
| Perfect Dark | `n64decomp/perfect_dark` | D | C | NP | MIT | | `git clone https://github.com/n64decomp/perfect_dark` |
| Zelda: Majora's Mask | `zeldaret/mm` | D | C | NP (~95%) | none | **[RL]** time-loop dungeon | `git clone https://github.com/zeldaret/mm` |
| Pokemon Stadium 1 | `pret/pokestadium` | D | C | WIP | none | | `git clone https://github.com/pret/pokestadium` |
| Pokemon Stadium 2 | `pret/pokestadiumgs` | D | C | WIP | none | | `git clone https://github.com/pret/pokestadiumgs` |
| Yoshi's Story | `decompals/yoshis-story` | D | C | WIP | none | | `git clone https://github.com/decompals/yoshis-story` |
| Conker's Bad Fur Day | `mkst/conker` | D | C | WIP | ? | | `git clone https://github.com/mkst/conker` |
| Wave Race 64 | `LLONSIT/Wave-Race-64` | A | ASM | WIP | ? | | `git clone https://github.com/LLONSIT/Wave-Race-64` |
| Snowboard Kids 2 | `cdlewis/snowboardkids2-decomp` | D | C | WIP | ? | | `git clone https://github.com/cdlewis/snowboardkids2-decomp` |
| Space Station Silicon Valley | `mkst/sssv` | D | C | WIP | ? | | `git clone https://github.com/mkst/sssv` |
| Mario Party 1 | `mariopartyrd/marioparty` | D | C | WIP | ? | | `git clone https://github.com/mariopartyrd/marioparty` |
| Mario Party 2 | `mariopartyrd/marioparty2` | D | C | WIP | ? | | `git clone https://github.com/mariopartyrd/marioparty2` |
| Mario Party 3 | `mariopartyrd/marioparty3` | D | C | WIP | ? | | `git clone https://github.com/mariopartyrd/marioparty3` |
| Mischief Makers | `Drahsid/mischief-makers` | D | C++ | WIP | ? | | `git clone https://github.com/Drahsid/mischief-makers` |
| Aidyn Chronicles | `blackgamma7/Aidyn` | D | C++ | WIP | ? | **[RL]** RPG dungeon | `git clone https://github.com/blackgamma7/Aidyn` |
| F-Zero X | `BttrDrgn/f-zerox` | D | C | WIP | ? | | `git clone https://github.com/BttrDrgn/f-zerox` |
| Evangelion N64 | `farisawan-2000/evangelion` | D | C | WIP | ? | | `git clone https://github.com/farisawan-2000/evangelion` |
| AeroGauge | `LLONSIT/AeroGauge` | D | C | WIP | ? | | `git clone https://github.com/LLONSIT/AeroGauge` |
| Gauntlet Legends | `Drahsid/gauntlet-legends` | D | C | WIP | ? | **[RL]** dungeon crawler | `git clone https://github.com/Drahsid/gauntlet-legends` |
| Gauntlet Dark Legacy | `sabishii-bit/Gauntlet-Dark-Legacy-Decompilation` | D | C | WIP | ? | **[RL]** dungeon crawler | `git clone https://github.com/sabishii-bit/Gauntlet-Dark-Legacy-Decompilation` |
| Castlevania 64 | `k64ret/cv64` | D | C | WIP | ? | **[RL]** dungeon | `git clone https://github.com/k64ret/cv64` |
| Bomberman 64 | `bomberhackers/bm64` | D | C | WIP | ? | | `git clone https://github.com/bomberhackers/bm64` |
| Bomberman 64: Second Attack | `bomberhackers/tsa` | D | C | WIP | ? | | `git clone https://github.com/bomberhackers/tsa` |
| Bomberman Hero | `bomberhackers/bmhero` | D | C | WIP | ? | | `git clone https://github.com/bomberhackers/bmhero` |
| Dinosaur Planet | `zestydevy/dinosaur-planet` | D | C | WIP | ? | | `git clone https://github.com/zestydevy/dinosaur-planet` |
| Animal Forest | `zeldaret/af` | D | C | WIP | CC0 | | `git clone https://github.com/zeldaret/af` |
| Diddy Kong Racing | `davidsm64/diddy-kong-racing` | D | C | WIP | ? | | `git clone https://github.com/davidsm64/diddy-kong-racing` |
| Quest 64 | `rainchus/quest64-decomp` | D | C | WIP | ? | **[RL]** RPG | `git clone https://github.com/rainchus/quest64-decomp` |
| Super Smash Bros. | `VetriTheRetri/ssb-decomp-re` | D | C | WIP | ? | | `git clone https://github.com/VetriTheRetri/ssb-decomp-re` |
| Blast Corps | `SlaveOfIDO/blastcorps` | D | C | WIP | ? | | `git clone https://github.com/SlaveOfIDO/blastcorps` |
| Ridge Racer 64 | `jvicu2001/rr64-decomp` | D | C | WIP | ? | | `git clone https://github.com/jvicu2001/rr64-decomp` |
| Doom 64 | `Erick194/DOOM64-RE` | D | C | NP | ? | **[RL]** FPS dungeon | `git clone https://github.com/Erick194/DOOM64-RE` |
| Duke Nukem 64 | `nblood/duke64-re` | D | C | WIP | ? | | `git clone https://github.com/nblood/duke64-re` |
| Body Harvest | `deltaniumindustries/bodyharvestdecomp` | D | C | WIP | ? | | `git clone https://github.com/deltaniumindustries/bodyharvestdecomp` |
| Mario Golf 64 | `monde-lointain/mariogolf64` | D | C | WIP | ? | | `git clone https://github.com/monde-lointain/mariogolf64` |
| Mario Tennis 64 | `dellm-79/mariotennisn64` | D | C | WIP | ? | | `git clone https://github.com/dellm-79/mariotennisn64` |
| Snowboard Kids 1 | `sonicdcer/sk` | D | C | WIP | ? | | `git clone https://github.com/sonicdcer/sk` |
| Star Wars: Rogue Squadron | `Tmcg2/rogue_squadron64` | D | C | WIP | ? | | `git clone https://github.com/Tmcg2/rogue_squadron64` |
| Star Wars: Shadows of Empire | `eltalelibrarian/sote` | D | C | WIP | ? | | `git clone https://github.com/eltalelibrarian/sote` |
| Kirby 64: Crystal Shards | `kirby64ret/kirby64` | D | C | WIP | ? | | `git clone https://github.com/kirby64ret/kirby64` |
| Chameleon Twist | `chameleontwistret/chameleontwistv1.0-jp` | D | C | WIP | ? | | `git clone https://github.com/chameleontwistret/chameleontwistv1.0-jp` |
| Chameleon Twist 2 | `chameleontwistret/chameleontwist2v1.0-jp` | D | C | WIP | ? | | `git clone https://github.com/chameleontwistret/chameleontwist2v1.0-jp` |
| Pokemon Battle Revolution (Wii) | `pret/pokerevo` | A | ASM | WIP | none | | `git clone https://github.com/pret/pokerevo` |
| Pokemon Snap | `ethteck/pokemonsnap` | D | C | WIP | ? | | `git clone https://github.com/ethteck/pokemonsnap` |
| Mystical Ninja Starring Goemon | `klorfmorf/mnsg` | D | C | WIP | ? | | `git clone https://github.com/klorfmorf/mnsg` |
| Shadowgate 64 | `rainchus/shadowgate64` | D | C | WIP | ? | **[RL]** dungeon | `git clone https://github.com/rainchus/shadowgate64` |
| Harvest Moon 64 | `harvestwhisperer/hm64-decomp` | D | C | WIP | ? | | `git clone https://github.com/harvestwhisperer/hm64-decomp` |
| Turok 3: Shadow of Oblivion | `Drahsid/turok3` | D | C | WIP | ? | | `git clone https://github.com/Drahsid/turok3` |
| Superman 64 | `farisawan-2000/superman` | D | C | WIP | ? | | `git clone https://github.com/farisawan-2000/superman` |
| Jet Force Gemini | `ryan-myers/jet-force-gemini` | D | C | WIP | ? | | `git clone https://github.com/ryan-myers/jet-force-gemini` |
| Star Wars Ep1: Racer | `tim-tim707/SW_RACER_RE` | D | C | WIP | ? | | `git clone https://github.com/tim-tim707/SW_RACER_RE` |
| Banjo-Tooie | `mr-wiseguy/banjo-tooie` | D | C | WIP | ? | | `git clone https://github.com/mr-wiseguy/banjo-tooie` |
| GoldenEye 007 | `kholdfuzion/goldeneye_src` (GitLab) | D | C | WIP | ? | | `git clone https://gitlab.com/kholdfuzion/goldeneye_src` |
| Gex 64 | `matbourgon/gex64decomp` | D | C | WIP | ? | | `git clone https://github.com/matbourgon/gex64decomp` |
| Glover | `rainchus/glover` | D | C | WIP | ? | | `git clone https://github.com/rainchus/glover` |
| Donkey Kong 64 | `dk64_decomp/dk64` (GitLab) | D | C | WIP | ? | | `git clone https://gitlab.com/dk64_decomp/dk64` |

## Nintendo DS

| Game | Repo | Type | Lang | Status | License | Roguelike? | Clone |
|------|------|------|------|--------|---------|------------|-------|
| Pokemon Diamond/Pearl | `pret/pokediamond` | A | ASM | WIP | none | | `git clone https://github.com/pret/pokediamond` |
| Pokemon Platinum | `pret/pokeplatinum` | D | C | WIP | none | | `git clone https://github.com/pret/pokeplatinum` |
| Pokemon HeartGold/SoulSilver | `pret/pokeheartgold` | A | ASM | WIP | none | | `git clone https://github.com/pret/pokeheartgold` |
| Pokemon Black | `pokemodding/pokeblack` | D | C | WIP | ? | | `git clone https://github.com/pokemodding/pokeblack` |
| Pokemon Mystery Dungeon: Explorers of Sky | `pret/pmd-sky` | A | ASM | WIP | none | **[RL]** roguelike | `git clone https://github.com/pret/pmd-sky` |
| New Super Mario Bros. | `NSMB-Decomp/nsmb` | D | C | WIP | ? | | `git clone https://github.com/NSMB-Decomp/nsmb` |
| Zelda: Phantom Hourglass | `zeldaret/ph` | D | C++ | WIP | CC0 | **[RL]** dungeon | `git clone https://github.com/zeldaret/ph` |
| Zelda: Spirit Tracks | `zeldaret/st` | D | C++ | WIP | CC0 | **[RL]** dungeon | `git clone https://github.com/zeldaret/st` |
| Mario Kart DS | `XorTroll/mkds-re` | D | C | WIP | ? | | `git clone https://github.com/XorTroll/mkds-re` |
| Dragon Quest IX | `DQIX/dqix-decomp` | D | Python | WIP | ? | **[RL]** RPG dungeon | `git clone https://github.com/DQIX/dqix-decomp` |
| Rhythm Heaven (Gold) | `patataofcourse/rhgold` | D | C | WIP | ? | | `git clone https://github.com/patataofcourse/rhgold` |
| The World Ends With You | `Yotona/twewy` | D | C | WIP | ? | **[RL]** action RPG | `git clone https://github.com/Yotona/twewy` |
| Mario Party DS | `mariopartyrd/mariopartyds` | D | C | WIP | ? | | `git clone https://github.com/mariopartyrd/mariopartyds` |
| SM64 DS | `matty45/sm64ds-decomp` | A | ASM | WIP | ? | | `git clone https://github.com/matty45/sm64ds-decomp` |
| Inazuma Eleven 3 | `CacaBueno64/ie3ogres` | D | C | WIP | ? | | `git clone https://github.com/CacaBueno64/ie3ogres` |
| Sonic Rush Adventure | `RushRE/SonicRushAdventure-Decomp` | D | C | WIP | ? | | `git clone https://github.com/RushRE/SonicRushAdventure-Decomp` |

## PlayStation 1 (PSX)

| Game | Repo | Type | Lang | Status | License | Roguelike? | Clone |
|------|------|------|------|--------|---------|------------|-------|
| Castlevania: Symphony of the Night | `Xeeynamo/sotn-decomp` | D | C | NP | AGPL-3.0 | **[RL]** metroidvania | `git clone https://github.com/Xeeynamo/sotn-decomp` |
| Silent Hill | `Vatuu/silent-hill-decomp` | D | C | WIP | ? | **[RL]** survival horror | `git clone https://github.com/Vatuu/silent-hill-decomp` |
| Spyro the Dragon | `TheMobyCollective/spyro-1` | A | ASM | WIP | ? | | `git clone https://github.com/TheMobyCollective/spyro-1` |
| VIB Ribbon | `open-ribbon/open-ribbon` | D | C | NP | none | | `git clone https://github.com/open-ribbon/open-ribbon` |
| MediEvil | `MediEvilDecompilation/medievil-decomp` | D | C | WIP | ? | **[RL]** action dungeon | `git clone https://github.com/MediEvilDecompilation/medievil-decomp` |
| Mega Man Legends | `ChrisNonyminus/mml1` | D | C | WIP | ? | | `git clone https://github.com/ChrisNonyminus/mml1` |
| Mega Man X4 | `sozud/mmx4` | D | C | WIP | ? | | `git clone https://github.com/sozud/mmx4` |
| Doom PSX | `Erick194/PSXDOOM-RE` | D | C | NP | ? | **[RL]** FPS dungeon | `git clone https://github.com/Erick194/PSXDOOM-RE` |
| Kingdom Hearts | `ethteck/kh1` | D | C | WIP | ? | **[RL]** action RPG | `git clone https://github.com/ethteck/kh1` |
| Crash Team Racing | `CTR-tools/CTR-ModSDK` | D | C | WIP | ? | | `git clone https://github.com/CTR-tools/CTR-ModSDK` |
| Fatal Frame 1 | `Mikompilation/Himuro` | D | C | WIP | ? | **[RL]** survival horror | `git clone https://github.com/Mikompilation/Himuro` |
| Resident Evil 2 | `OpenBiohazard2/OpenBiohazard2` | D | C | WIP | ? | **[RL]** survival horror | `git clone https://github.com/OpenBiohazard2/OpenBiohazard2` |
| Frogger (1997) | `HighwayFrogs/frogger-psx` | D | C | WIP | ? | | `git clone https://github.com/HighwayFrogs/frogger-psx` |
| Chrono Cross | `jdperos/chrono-cross-decomp` | D | C | WIP | ? | **[RL]** RPG | `git clone https://github.com/jdperos/chrono-cross-decomp` |
| Vagrant Story | `ser-pounce/rood-reverse` | D | C | WIP | ? | **[RL]** dungeon crawler | `git clone https://github.com/ser-pounce/rood-reverse` |
| Final Fantasy VII | `xeeynamo/ff7-decomp` | D | C | WIP | ? | **[RL]** RPG | `git clone https://github.com/xeeynamo/ff7-decomp` |
| Vandal Hearts | `shao113/vh` | D | C | WIP | ? | **[RL]** tactical RPG | `git clone https://github.com/shao113/vh` |
| Xenogears | `ladysilverberg/xenogears-decomp` | D | C | WIP | ? | **[RL]** RPG | `git clone https://github.com/ladysilverberg/xenogears-decomp` |
| Legend of Dragoon | `Legend-of-Dragoon-Modding/Severed-Chains` | D | C | WIP | ? | **[RL]** RPG | `git clone https://github.com/Legend-of-Dragoon-Modding/Severed-Chains` |
| Panzer Dragoon Saga | `yaz0r/Azel` | D | C | WIP | ? | **[RL]** RPG | `git clone https://github.com/yaz0r/Azel` |
| Tomba! | `hansbonini/psx_tomba` | D | C | WIP | ? | | `git clone https://github.com/hansbonini/psx_tomba` |
| Phoenix Wright: Ace Attorney | `atasro2/pwaa1` | D | C | WIP | ? | | `git clone https://github.com/atasro2/pwaa1` |
| Twisted Metal | `abelbriggs1/tm1_decomp` | D | C | WIP | ? | | `git clone https://github.com/abelbriggs1/tm1_decomp` |
| Metal Gear Solid | `FoxdieTeam/mgs_reversing` | D | C | WIP | ? | | `git clone https://github.com/FoxdieTeam/mgs_reversing` |
| Croc: Legend of the Gobbos | `xeeynamo/croc` | D | C | WIP | ? | | `git clone https://github.com/xeeynamo/croc` |
| Driver 2 | `OpenDriver2/REDRIVER2` | D | C | NP | ? | | `git clone https://github.com/OpenDriver2/REDRIVER2` |
| Pop'N Music | `Erizur/slpm86183` | D | C | WIP | ? | | `git clone https://github.com/Erizur/slpm86183` |
| Legend of Legaia | `dacodechick/legaia-decomp` | D | C | WIP | ? | **[RL]** RPG | `git clone https://github.com/dacodechick/legaia-decomp` |
| LSD: Dream Emulator | `FirecatFG/lsddecomp` | D | C | WIP | ? | | `git clone https://github.com/FirecatFG/lsddecomp` |
| Lunar 2: Eternal Blue | `Zackmon/lunar2-psx-decomp` | D | C | WIP | ? | **[RL]** RPG | `git clone https://github.com/Zackmon/lunar2-psx-decomp` |

## Saturn

| Game | Repo | Type | Lang | Status | License | Roguelike? | Clone |
|------|------|------|------|--------|---------|------------|-------|
| Panzer Dragoon Saga | `yaz0r/Azel` | D | C | WIP | ? | **[RL]** RPG | (listed above under PSX -- actually Saturn) |
| Castlevania: SotN (Saturn ver.) | included in `Xeeynamo/sotn-decomp` | D | C | WIP | AGPL-3.0 | | (same repo) |

**Note**: Saturn decomps are extremely rare. Panzer Dragoon Saga is the most notable.

## GameCube / Wii (bonus -- closely related to N64 era)

| Game | Repo | Type | Lang | Status | License | Roguelike? | Clone |
|------|------|------|------|--------|---------|------------|-------|
| Zelda: Twilight Princess | `zeldaret/tp` | D | C++ | NP | CC0 | **[RL]** dungeon | `git clone https://github.com/zeldaret/tp` |
| Zelda: Wind Waker | `zeldaret/tww` | D | C++ | WIP | CC0 | **[RL]** dungeon | `git clone https://github.com/zeldaret/tww` |
| Zelda: Skyward Sword (Wii) | `zeldaret/ss` | D | C++ | WIP | CC0 | | `git clone https://github.com/zeldaret/ss` |
| Animal Crossing (GC) | `ACreTeam/ac-decomp` | D | C | WIP (90%+) | ? | | `git clone https://github.com/ACreTeam/ac-decomp` |
| Super Smash Bros. Melee | `doldecomp/melee` | D | C | WIP | ? | | `git clone https://github.com/doldecomp/melee` |
| Super Mario Sunshine | `doldecomp/sms` | D | C | WIP | ? | | `git clone https://github.com/doldecomp/sms` |
| Paper Mario: TTYD | `doldecomp/ttyd` | D | C | WIP | ? | **[RL]** RPG | `git clone https://github.com/doldecomp/ttyd` |
| Pikmin 1 | `projectPiki/pikmin` | D | C | WIP | ? | | `git clone https://github.com/projectPiki/pikmin` |
| Pikmin 2 | `projectPiki/pikmin2` | D | C | WIP | ? | **[RL]** dungeon cave | `git clone https://github.com/projectPiki/pikmin2` |
| Metroid Prime | `primedecomp/prime` | D | C | WIP | ? | **[RL]** metroidvania | `git clone https://github.com/primedecomp/prime` |
| Metroid Prime 2 | `primedecomp/echoes` | D | C | WIP | ? | **[RL]** metroidvania | `git clone https://github.com/primedecomp/echoes` |
| Super Paper Mario (Wii) | `SeekyCt/spm-decomp` | D | C | WIP | ? | **[RL]** RPG platformer | `git clone https://github.com/SeekyCt/spm-decomp` |
| Wii Sports | `doldecomp/ogws` | D | C | WIP | ? | | `git clone https://github.com/doldecomp/ogws` |
| Mario Kart: Double Dash | `doldecomp/mkdd` | D | C | WIP | ? | | `git clone https://github.com/doldecomp/mkdd` |
| Kirby Air Ride | `doldecomp/kar` | D | C | WIP | ? | | `git clone https://github.com/doldecomp/kar` |
| Super Mario Galaxy | `SMGCommunity/Petari` | D | C++ | WIP | ? | | `git clone https://github.com/SMGCommunity/Petari` |
| Luigi's Mansion | `sage-of-mirrors/zmansion` | D | C | WIP | ? | **[RL]** exploration | `git clone https://github.com/sage-of-mirrors/zmansion` |
| Sonic Adventure DX | `doldecomp/sadx` | D | C | WIP | ? | | `git clone https://github.com/doldecomp/sadx` |
| Sonic Riders | `doldecomp/sonicriders` | D | C | WIP | ? | | `git clone https://github.com/doldecomp/sonicriders` |
| Sly Cooper (PS2) | `TheOnlyZac/sly1` | D | C++ | WIP | ? | | `git clone https://github.com/TheOnlyZac/sly1` |
| SpongeBob: Battle for Bikini Bottom | `bfbbdecomp/bfbb` | D | C | WIP | ? | | `git clone https://github.com/bfbbdecomp/bfbb` |
| Mario & Luigi: Partners in Time | `rainchus/partnersintime-decomp` | D | C | WIP | ? | **[RL]** RPG | `git clone https://github.com/rainchus/partnersintime-decomp` |
| Fortune Street (Wii) | `FortuneStreetModding/boom-street-decomp` | D | C | WIP | ? | | `git clone https://github.com/FortuneStreetModding/boom-street-decomp` |
| Fatal Frame 2 (PS2) | `Mikompilation/minakami` | D | C | WIP | ? | **[RL]** horror | `git clone https://github.com/Mikompilation/minakami` |
| F-Zero GX/AX | `TheInfiniteLegend/f-0-ax` | D | C | WIP | ? | | `git clone https://github.com/TheInfiniteLegend/f-0-ax` |

---

## ROGUELIKE / DUNGEON CRAWLER HIGHLIGHT LIST

These are the most relevant decomps for building a GB roguelike, sorted by relevance:

### Tier 1 -- Direct roguelike mechanics
| Game | Platform | Repo | Why relevant |
|------|----------|------|-------------|
| **Azure Dreams** | GB/GBC | `forestbelton/azure` | Tower-climbing roguelike with monster breeding. Most directly relevant. |
| **PMD: Red Rescue Team** | GBA | already have (pmd-red) | Pokemon Mystery Dungeon -- pure roguelike on GBA |
| **PMD: Explorers of Sky** | DS | `pret/pmd-sky` | Most complete PMD decomp, extensive dungeon generation code |
| **Gauntlet Legends** | N64 | `Drahsid/gauntlet-legends` | Dungeon crawler, procedural rooms |
| **Gauntlet Dark Legacy** | N64 | `sabishii-bit/Gauntlet-Dark-Legacy-Decompilation` | Expanded dungeon crawler |
| **Dragon Warrior Monsters** | GBC | `NiyaDev/DWM` | Monster breeding + random dungeon generation |

### Tier 2 -- Dungeon/RPG mechanics worth studying
| Game | Platform | Repo | Why relevant |
|------|----------|------|-------------|
| **Dragon Warrior (NES)** | NES | `nmikstas/dragon-warrior-disassembly` | Classic JRPG combat/inventory, tile-based movement |
| **Zelda 1 (NES)** | NES | `aldonunez/zelda1-disassembly` | Dungeon structure, item progression, room transitions |
| **Castlevania: SotN** | PSX | `Xeeynamo/sotn-decomp` | RPG-metroidvania, loot drops, leveling, map |
| **Vagrant Story** | PSX | `ser-pounce/rood-reverse` | Deep dungeon crawler with crafting |
| **Aidyn Chronicles** | N64 | `blackgamma7/Aidyn` | Turn-based RPG with dungeon exploration |
| **Quest 64** | N64 | `rainchus/quest64-decomp` | Simple RPG with dungeon mechanics |
| **Shadowgate 64** | N64 | `rainchus/shadowgate64` | First-person dungeon adventure |
| **Diablo** | PC | `diasurgical/devilution` | THE roguelike reference (not retro console, but essential) |

---

## SPECIFIC GAME STATUS REPORT

Games the user specifically asked about:

| Game | Status | Notes |
|------|--------|-------|
| Mega Man 2 (NES) | **FOUND** | `lsmmega/mm2` + `plasticsmoke/megaman2-disassembly-ca65` |
| Metroid (NES) | **NOT FOUND** | No public compilable disassembly. Only partial analysis exists. |
| Kirby's Adventure (NES) | **FOUND** | `yay58/Kirby-s-Adventure-Disassembly` (WIP) |
| Final Fantasy Adventure / Mystic Quest (GB) | **NOT FOUND** | No public decomp. |
| Pokemon TCG 2 (GBC) | **FOUND** | `pret/poketcg2` |
| Golden Sun (GBA) | **NOT FOUND** | No public decomp of substance. |
| Advance Wars 1 (GBA) | **FOUND** | `ketsuban/advancewars` |
| Mario & Luigi: Superstar Saga (GBA) | **FOUND** | `jellees/mlss` |
| Castlevania: Aria of Sorrow (GBA) | already have (cvaos) | |
| Castlevania: Harmony of Dissonance (GBA) | **NOT FOUND** | No public decomp. |
| Chrono Trigger (SNES) | **NOT FOUND** | No compilable decomp. Only ROM hacking docs. |
| Final Fantasy 4/5/6 (SNES) | **NOT FOUND** | FF4 3D remake has a decomp, but no SNES originals. |
| Streets of Rage 2 (Genesis) | **NOT FOUND** | No structured decomp project. |
| Shining Force (Genesis) | **NOT FOUND** | No structured decomp project. |
| Perfect Dark (N64) | **FOUND** | `n64decomp/perfect_dark` (MIT license, near-complete) |
| Majora's Mask (N64) | **FOUND** | `zeldaret/mm` (~95% complete) |
| Pokemon Stadium (N64) | **FOUND** | `pret/pokestadium` + `pret/pokestadiumgs` |
| DS Pokemon decomps | **FOUND** | Diamond/Pearl, Platinum, HGSS, Black -- see DS section |

---

## BATCH CLONE SCRIPT

To clone all new repos (excluding what you already have), save this as `clone-decomps.sh`:

```bash
#!/bin/bash
# Retro game decompilation/disassembly repos -- clone all
# Generated 2026-03-29

BASE_DIR="${1:-.}"
cd "$BASE_DIR" || exit 1

# --- GB/GBC ---
git clone https://github.com/pret/poketcg2
git clone https://github.com/pret/pokepuzzle
git clone https://github.com/pret/pokegold-spaceworld
git clone https://github.com/NiyaDev/DWM
git clone https://github.com/forestbelton/azure

# --- GBA ---
git clone https://github.com/SAT-R/sa1
git clone https://github.com/SAT-R/sa3
git clone https://github.com/ketsuban/advancewars
git clone https://github.com/MokhaLeee/FireEmblem7J
git clone https://github.com/jellees/bkgr
git clone https://github.com/jellees/mlss
git clone https://github.com/StanHash/fomt
git clone https://github.com/mmzret/rmz3
git clone https://github.com/pret/pokeemerald-jp
git clone https://github.com/lagolunatic/ooe
git clone https://github.com/Normmatt/m12
git clone https://github.com/jiangzhengwenjz/csm3
git clone https://github.com/pret/berry-fix
git clone https://github.com/pret/colosseum-mb

# --- NES ---
git clone https://github.com/aldonunez/zelda1-disassembly
git clone https://github.com/nmikstas/dragon-warrior-disassembly
git clone https://github.com/nmikstas/mike-tysons-punch-out-disassembly
git clone https://github.com/lsmmega/mm1
git clone https://github.com/lsmmega/mm2
git clone https://github.com/lsmmega/mm3
git clone https://github.com/lsmmega/mm5
git clone https://github.com/yay58/Kirby-s-Adventure-Disassembly
git clone https://github.com/pgattic/smb1-disasm
git clone https://github.com/GuillianSeed/MetalGear
git clone https://github.com/GrasonHumphrey/Earthbound-Zero-Decomp

# --- SNES ---
git clone https://github.com/Yoshifanatic1/Donkey-Kong-Country-3-Disassembly
git clone https://github.com/LIJI32/superbomberman
git clone https://github.com/strager/supermetroid

# --- Genesis ---
git clone https://github.com/sonicretro/s3ddisasm
git clone https://github.com/sonicretro/ristar
git clone https://github.com/sonicretro/chaotix
git clone https://github.com/sonicretro/kid-chameleon-disasm
git clone https://github.com/sonicretro/s2smsdisasm
git clone https://github.com/sonicretro/spindisasm
git clone https://github.com/sonicretro/ktes2

# --- N64 ---
git clone https://github.com/n64decomp/perfect_dark
git clone https://github.com/zeldaret/mm
git clone https://github.com/pret/pokestadium
git clone https://github.com/pret/pokestadiumgs
git clone https://github.com/decompals/yoshis-story
git clone https://github.com/mkst/conker
git clone https://github.com/LLONSIT/Wave-Race-64
git clone https://github.com/cdlewis/snowboardkids2-decomp
git clone https://github.com/mkst/sssv
git clone https://github.com/mariopartyrd/marioparty
git clone https://github.com/mariopartyrd/marioparty2
git clone https://github.com/mariopartyrd/marioparty3
git clone https://github.com/Drahsid/mischief-makers
git clone https://github.com/blackgamma7/Aidyn
git clone https://github.com/BttrDrgn/f-zerox
git clone https://github.com/Drahsid/gauntlet-legends
git clone https://github.com/sabishii-bit/Gauntlet-Dark-Legacy-Decompilation
git clone https://github.com/k64ret/cv64
git clone https://github.com/bomberhackers/bm64
git clone https://github.com/bomberhackers/tsa
git clone https://github.com/bomberhackers/bmhero
git clone https://github.com/zestydevy/dinosaur-planet
git clone https://github.com/zeldaret/af
git clone https://github.com/davidsm64/diddy-kong-racing
git clone https://github.com/rainchus/quest64-decomp
git clone https://github.com/VetriTheRetri/ssb-decomp-re
git clone https://github.com/Erick194/DOOM64-RE
git clone https://github.com/nblood/duke64-re
git clone https://github.com/monde-lointain/mariogolf64
git clone https://github.com/sonicdcer/sk
git clone https://github.com/kirby64ret/kirby64
git clone https://github.com/ethteck/pokemonsnap
git clone https://github.com/rainchus/shadowgate64
git clone https://github.com/harvestwhisperer/hm64-decomp
git clone https://github.com/Drahsid/turok3
git clone https://github.com/ryan-myers/jet-force-gemini
git clone https://github.com/tim-tim707/SW_RACER_RE
git clone https://github.com/mr-wiseguy/banjo-tooie
git clone https://github.com/rainchus/glover
git clone https://github.com/klorfmorf/mnsg
git clone https://github.com/SlaveOfIDO/blastcorps
git clone https://github.com/jvicu2001/rr64-decomp
git clone https://github.com/pret/pokerevo
# GitLab repos:
git clone https://gitlab.com/kholdfuzion/goldeneye_src
git clone https://gitlab.com/dk64_decomp/dk64

# --- DS ---
git clone https://github.com/pret/pokediamond
git clone https://github.com/pret/pokeplatinum
git clone https://github.com/pret/pokeheartgold
git clone https://github.com/pokemodding/pokeblack
git clone https://github.com/pret/pmd-sky
git clone https://github.com/NSMB-Decomp/nsmb
git clone https://github.com/zeldaret/ph
git clone https://github.com/zeldaret/st
git clone https://github.com/XorTroll/mkds-re
git clone https://github.com/DQIX/dqix-decomp
git clone https://github.com/patataofcourse/rhgold
git clone https://github.com/Yotona/twewy
git clone https://github.com/mariopartyrd/mariopartyds

# --- PSX ---
git clone https://github.com/Xeeynamo/sotn-decomp
git clone https://github.com/Vatuu/silent-hill-decomp
git clone https://github.com/TheMobyCollective/spyro-1
git clone https://github.com/open-ribbon/open-ribbon
git clone https://github.com/MediEvilDecompilation/medievil-decomp
git clone https://github.com/ChrisNonyminus/mml1
git clone https://github.com/sozud/mmx4
git clone https://github.com/Erick194/PSXDOOM-RE
git clone https://github.com/ethteck/kh1
git clone https://github.com/CTR-tools/CTR-ModSDK
git clone https://github.com/Mikompilation/Himuro
git clone https://github.com/OpenBiohazard2/OpenBiohazard2
git clone https://github.com/jdperos/chrono-cross-decomp
git clone https://github.com/ser-pounce/rood-reverse
git clone https://github.com/xeeynamo/ff7-decomp
git clone https://github.com/shao113/vh
git clone https://github.com/ladysilverberg/xenogears-decomp
git clone https://github.com/Legend-of-Dragoon-Modding/Severed-Chains
git clone https://github.com/yaz0r/Azel
git clone https://github.com/hansbonini/psx_tomba
git clone https://github.com/atasro2/pwaa1
git clone https://github.com/FoxdieTeam/mgs_reversing
git clone https://github.com/OpenDriver2/REDRIVER2
git clone https://github.com/dacodechick/legaia-decomp
git clone https://github.com/abelbriggs1/tm1_decomp
git clone https://github.com/xeeynamo/croc
git clone https://github.com/Zackmon/lunar2-psx-decomp
git clone https://github.com/FirecatFG/lsddecomp

# --- GC/Wii (bonus) ---
git clone https://github.com/zeldaret/tp
git clone https://github.com/zeldaret/tww
git clone https://github.com/zeldaret/ss
git clone https://github.com/ACreTeam/ac-decomp
git clone https://github.com/doldecomp/melee
git clone https://github.com/doldecomp/sms
git clone https://github.com/doldecomp/ttyd
git clone https://github.com/projectPiki/pikmin
git clone https://github.com/projectPiki/pikmin2
git clone https://github.com/primedecomp/prime
git clone https://github.com/primedecomp/echoes
git clone https://github.com/SeekyCt/spm-decomp
git clone https://github.com/doldecomp/ogws
git clone https://github.com/doldecomp/mkdd
git clone https://github.com/doldecomp/kar
git clone https://github.com/SMGCommunity/Petari
git clone https://github.com/sage-of-mirrors/zmansion
git clone https://github.com/rainchus/partnersintime-decomp
```

---

## SUMMARY STATISTICS

- **Total new repos found**: ~130+ (retro platforms only, excluding what user already has)
- **Platforms covered**: GB/GBC (5), GBA (14), NES (11), SNES (3), Genesis (7), N64 (50+), DS (13), PSX (30+), Saturn (2), GC/Wii (18+)
- **Roguelike-relevant**: 25+ projects marked with [RL]
- **Most relevant for GB roguelike development**: Azure Dreams (GBC), Dragon Warrior Monsters (GBC), PMD Sky (DS), Gauntlet Legends (N64), Zelda 1 (NES), Dragon Warrior (NES)
- **Not found (no public decomp)**: Metroid NES, Golden Sun, Chrono Trigger SNES, FF4/5/6 SNES, Streets of Rage 2, Shining Force, Harmony of Dissonance, FFA/Mystic Quest GB

**Source**: Data compiled from GitHub API queries (orgs: pret, zeldaret, decompals, sonicretro, snesrev, n64decomp, doldecomp, SAT-R, mariopartyrd, bomberhackers, etc.) and the community-maintained [awesome-game-decompilations](https://github.com/CharlotteCross1998/awesome-game-decompilations) list (316 stars, actively maintained).
