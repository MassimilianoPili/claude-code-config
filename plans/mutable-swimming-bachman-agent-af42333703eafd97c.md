# Research Analysis: Entombed (Atari 2600) -- The Mysterious Maze Algorithm

## Research Summary: The Entombed Maze-Generation Algorithm

### Executive Summary

The Atari 2600 game *Entombed* (1982, US Games) contains a maze-generation algorithm that produces infinite vertically-scrolling mazes using only a 32-byte lookup table and a 5-cell sliding window, operating within the console's 128 bytes of RAM. The algorithm was reverse-engineered in 2018 by Aycock & Copplestone, who identified the lookup table but could not explain its derivation. This was resolved in 2022 when Paul Allen Newell -- one of the algorithm's original co-inventors -- came forward with ~500 development artefacts from 1981, revealing the table to be a **compiled output of three simple constraint-satisfaction rules** applied to overlapping neighborhoods, not a hand-tuned mystery. The table was a red herring: it was an intermediate representation, not the algorithm's true design.

**Epistemic status:** Resolved. The mystery has been definitively settled by primary source evidence (original documentation from 1981).
**Confidence:** High -- first-hand developer participation, cross-checked artefactual evidence, peer-reviewed publication.

---

## 1. The Three Key Papers

### Paper 1: "Entombed: An archaeological examination of an Atari 2600 game"
- **Authors:** John Aycock, Tara Copplestone
- **Venue:** *The Art, Science, and Engineering of Programming*, Vol. 3, Issue 2, Article 4 (2019) -- peer-reviewed journal
- **arXiv:** 1811.02035 (Nov 2018 preprint)
- **DOI:** 10.22152/programming-journal.org/2019/3/4
- **Citations:** ~7 (OpenAlex) / 6 (S2), 0 influential (S2)
- **Tier:** T1 (peer-reviewed journal)

**Core contribution:** Reverse-engineered the Entombed binary, discovered the 5-cell neighborhood + 32-byte lookup table maze algorithm, identified a 35-year-old bug, documented code reuse between Atari 2600 developers, and reconstructed the human backstory including the "intoxicant-fueled design" narrative.

### Paper 2: "Explaining the Entombed Algorithm"
- **Authors:** Leon Machler, David Naccache
- **Venue:** 2021 IEEE Conference on Games (CoG)
- **arXiv:** 2104.09982 (Apr 2021)
- **DOI:** 10.1109/CoG52621.2021.9619150
- **Categories:** cs.CG, cs.DM, cs.DS, math.CO
- **Citations:** 0 (OpenAlex/S2)
- **Tier:** T2 (peer-reviewed conference, but lower-tier venue)

**Core contribution:** Provided a mathematical explanation for the lookup table using constraint satisfaction. Extended the algorithm to three dimensions. However, this analysis was done without access to the original source code and, while independently reaching similar conclusions, was superseded by the definitive resolution in Paper 3.

### Paper 3: "Still Entombed After All These Years: The continuing twists and turns of a maze game"
- **Authors:** Paul Allen Newell, John Aycock, Katie M. Biittner
- **Venue:** *Internet Archaeology* 59 (June 2022) -- peer-reviewed journal
- **DOI:** 10.11141/ia.59.3
- **Citations:** 2 (S2)
- **Tier:** T1 (peer-reviewed, open access journal, University of York)

**Core contribution:** The definitive resolution. Newell, the original co-inventor of the algorithm, joined as co-author. The paper analyses ~487 artefacts (source code, EPROMs, 8-inch floppy disks, printouts, Polaroid photos) from 1981. Reveals:
1. The table was a **compiled output** of three explicit rules, not a mystery
2. The algorithm was co-invented by Newell and mathematician Duncan Muirhead at UCLA
3. The "drunk coding" story was a deliberate misdirection to protect IP
4. The algorithm had both "easy" (passable) and "hard" (sometimes impassable) modes; Entombed shipped with hard mode only
5. The algorithm was reused across multiple games (Towering Inferno, an unreleased maze game)

---

## 2. The Algorithm: How It Works

### 2.1 Platform Constraints (Atari 2600 / VCS)

The Atari 2600 had:
- **128 bytes of RAM** (the entire system RAM, shared between game state, stack, and variables)
- **MOS 6507 CPU** at 1.19 MHz
- **No frame buffer**: the TIA chip required the CPU to feed it data scanline-by-scanline in real time ("racing the beam")
- Each scanline took ~76 CPU cycles; the maze had to be generated within this timing budget

This meant: **no storing the maze**. Each row had to be generated procedurally, on the fly, using only information from the current and immediately preceding row.

### 2.2 Maze Structure

The maze as displayed in Entombed:
- **Vertically scrolling** (player moves upward)
- **Bilaterally symmetric** about the vertical center
- Double-wide passages (to accommodate player sprite width)
- Fixed outer walls on left and right edges

Due to symmetry and the fixed walls, each maze row is described by only **8 bits** (the left half; the right half is a mirror). The algorithm generates these 8 bits one at a time, left to right.

### 2.3 The 5-Cell Sliding Window

For each new bit X to be generated, the algorithm examines a neighborhood of 5 cells arranged in a Tetris-like L-shape:

```
    c d e      (row above: three cells)
  a b          (current row, to the left: two cells)
      X        (the cell to generate)
```

Where:
- `a`, `b` = the two cells to the left in the current row (already generated)
- `c`, `d`, `e` = three cells directly above in the previous row
- The 5 bits `abcde` form a 5-bit index (values 0-31)

**Boundary conditions:**
- At the left edge: `a=1` (wall), `b=0` (passage), `c=random`
- At the right edge (symmetry line): `e` is replaced with a random bit (since `e` would duplicate `d` due to symmetry)

### 2.4 The 32-Byte Lookup Table

The 5-bit index `abcde` maps into a 32-entry table. Each entry specifies one of three outcomes:
- `0` = passage (empty)
- `1` = wall
- `R` = random (chosen pseudorandomly at runtime)

The actual byte values from the Entombed binary (as extracted by Aycock & Copplestone), where each entry stores the output for the corresponding 5-bit input `abcde`:

```
Index (abcde)  Output    Index (abcde)  Output
00000 (0)      R         10000 (16)     1
00001 (1)      1         10001 (17)     0
00010 (2)      R         10010 (18)     R
00011 (3)      1         10011 (19)     1
00100 (4)      0         10100 (20)     0
00101 (5)      0         10101 (21)     0
00110 (6)      R         10110 (22)     R
00111 (7)      1         10111 (23)     0
01000 (8)      0         11000 (24)     0
01001 (9)      0         11001 (25)     0  (special case)
01010 (10)     R         11010 (26)     R
01011 (11)     0         11011 (27)     0
01100 (12)     R         11100 (28)     0
01101 (13)     0         11101 (29)     0
01110 (14)     R         11110 (30)     R
01111 (15)     0         11111 (31)     0
```

**Key observation:** 16 of the 32 entries are deterministic (0 or 1), while 8 are random (R). This is what puzzled researchers -- the pattern seemed neither fully random nor fully deterministic, and no obvious mathematical structure (cellular automaton rule, de Bruijn sequence, etc.) explained the specific choices.

### 2.5 The True Algorithm: Three Rules (Muirhead-Newell)

The 2022 "Still Entombed" paper reveals that the table was **derived** from three simple rules operating on overlapping sub-neighborhoods called B-KIN, D-KIN, and CBLOCK:

**B-KIN** = cells {a, b, c} (overlap centered on b)
**D-KIN** = cells {c, d, e} (overlap centered on d)
**CBLOCK** = cells {b, c, d} (the middle three)

For B-KIN, compute:
- Base = number of neighbors in {a, c} that share the same value as b
- B-KIN_0 = base + 1 if b=0, else base
- B-KIN_1 = base + 1 if b=1, else base

Same for D-KIN with respect to d and its neighbors {c, e}.

Then apply rules in priority order:

**Rule 1 (Isolation prevention):** If any computed B-KIN or D-KIN value equals 0, set X to the **opposite** value. (E.g., if B-KIN_0 = 0, then X = 1.) This prevents a cell from being completely isolated from all its neighbors of the same type.

**Rule 2 (Density control):** If B-KIN_0 + D-KIN_0 > 4, set X = 1 (too many passages nearby, add a wall). If B-KIN_1 + D-KIN_1 > 4, set X = 0 (too many walls nearby, add a passage).

**Rule 3 (Uniformity breaking):** If all CBLOCK bits are the same (all 0s or all 1s), set X to the opposite value. This prevents long horizontal runs of identical cells.

**Default:** If none of the three rules applies, X is chosen **randomly**.

**Two special cases:**
- `abcde = 00100`: forced to 0 (empirically observed to fix undesirable mazes with `bcd = 010`)
- `abcde = 11001`: forced to 0 (prevents formation of inaccessible "islands" surrounded by walls; undocumented rationale but confirmed by modern reconstruction)

### 2.6 Easy Mode vs Hard Mode

The algorithm had a **difficulty parameter** controlling passability:
- **Easy mode**: mazes are always passable (the player can always find a path through)
- **Hard mode**: mazes are sometimes impassable (requiring the "make-break" mechanic to punch through walls)

Entombed shipped with **hard mode only**. The easy mode code was present in the source but commented out. Switching to easy mode requires changing only 2 bytes in the ROM: `$b13b` -> `$38` and `$b140` -> `3`.

Machler & Naccache independently discovered that alternative parameter values produced passable mazes, but without the source code they couldn't know this was the intentional "easy mode."

### 2.7 Post-Processing Checks

Two additional checks ran after each row:
- **PP1**: Detected overlong vertical passages in the leftmost column (triggered only ~10 times in 300,000 rows in hard mode; 10,015 times in easy mode -- clearly designed for easy mode)
- **PP2**: Detected excessive walls or passages in the rightmost column (~1 per 60 rows in hard mode, ~2.3x more in easy mode)

---

## 3. Information-Theoretic Analysis

### 3.1 How 32 Bytes Encode Infinite Mazes

The key insight is that the 32-byte table is **not storing the maze** -- it's storing a **local transition rule**. The maze is generated as a streaming process:

- Each row depends only on the previous row (8 bits) and a random seed
- The table defines the local rule for computing each cell
- Randomness provides the entropy for variation

This is analogous to how a 1D cellular automaton rule (e.g., Wolfram's Rule 30, which fits in 1 byte) can generate infinite patterns from a finite specification. The Entombed table is a **generalized CA rule** with:
- 5-bit input neighborhood (32 possible inputs)
- 3-valued output (0, 1, random) -- so ~1.58 bits per entry
- Total information content: ~32 * 1.58 = ~50.6 bits of rule specification

The remaining entropy comes from the PRNG (pseudo-random number generator), which provides the source of variation for the "R" entries and boundary conditions.

### 3.2 Information-Theoretic Minimum

For maze generation on 128 bytes RAM with the constraints:
- Bilateral symmetry (halves the effective width)
- 8 effective bits per row
- Only need previous row + current partial row in memory

**Memory requirement:**
- Previous row: 1 byte (8 bits)
- Current row (being built): 1 byte
- Lookup table: 32 bytes (could potentially be compressed)
- PRNG state: 1-2 bytes
- Index/counter variables: 2-3 bytes
- **Total: ~37-38 bytes** for the core algorithm

This leaves ~90 bytes for game state, stack, player positions, zombie AI, etc. The algorithm is remarkably efficient.

### 3.3 Could the Table Be Smaller?

The table has inherent structure that could theoretically be compressed:

1. **8 of 32 entries are "random"** -- these could be encoded as a bitmask (4 bytes) + the deterministic values (3 bytes for 24 entries at 1 bit each)
2. The three rules could be computed directly instead of using a lookup table, eliminating the table entirely. However, this would require **more CPU cycles** -- and on the Atari 2600, cycles were the binding constraint, not bytes. The table exists precisely because it's faster to look up than to compute.

The tradeoff is:
- **32 bytes of ROM** (cheap -- the cartridge had 2-4 KB of ROM)
- **Saves ~50-100 cycles per cell** versus computing the rules directly
- At 8 cells per row and ~76 cycles per scanline, this is critical

So the table is **optimal for the platform**: it trades ROM space (abundant) for CPU time (scarce).

---

## 4. Relationship to Cellular Automata and Other Structures

### 4.1 Not Quite a Cellular Automaton

The algorithm resembles a cellular automaton but differs in important ways:

**Similarities:**
- Local rule applied to a neighborhood
- Deterministic lookup from local context
- Sequential generation of rows

**Differences (making CA classification "contrived" per Newell et al.):**
- **No parallelism**: cells are generated sequentially left-to-right, not simultaneously. Each cell's value depends on the already-generated cells to its left in the same row.
- **Asymmetric neighborhood**: The L-shaped 5-cell window is unusual for CAs, which typically use symmetric neighborhoods (von Neumann, Moore)
- **Stochastic output**: Some entries produce random values, making it a probabilistic rather than deterministic automaton
- **Sequential dependency within a row**: Cell X depends on cells a and b, which were just computed in this row -- this is unlike standard CAs where all cells update simultaneously from the previous state

### 4.2 Not Wolfram's Rule 30

Despite superficial similarities, the Entombed algorithm is **not related to Rule 30**:
- Rule 30 is a 1D elementary CA with 3-cell neighborhood and 8-entry table (1 byte)
- Entombed uses a 5-cell neighborhood with 32-entry table and 3-valued output
- Rule 30 is fully deterministic; Entombed is stochastic
- Rule 30 updates all cells simultaneously; Entombed is sequential

### 4.3 Not a de Bruijn Sequence

The table entries do not form a de Bruijn sequence. A de Bruijn sequence B(2,5) would be 32 bits long and contain every 5-bit string exactly once as a contiguous substring. The Entombed table has 3-valued output (0, 1, R), not binary, and is indexed by the 5-bit neighborhood rather than representing a cyclic sequence.

### 4.4 Closest Mathematical Relative: Constrained Stochastic Sequential Process

The best characterization is a **constrained stochastic sequential process** -- a system that:
1. Generates output sequentially (not in parallel)
2. Uses local constraints to force certain values
3. Falls back to randomness when constraints don't determine the output
4. Operates in a streaming fashion with bounded memory

This is closer to a **Markov chain with forbidden patterns** or a **constrained random walk** than to a cellular automaton.

### 4.5 Connection to Eller's Algorithm

Eller's algorithm (1982, independently) also generates mazes row-by-row using only information from the previous row. However, Eller's algorithm maintains set membership information (which cells are connected) -- effectively summarizing the entire lineage of passages. The Muirhead-Newell algorithm uses only raw cell values from 5 local cells, with no global connectivity tracking. They are fundamentally different despite superficial similarity. (Confirmed by correspondence with Marlin Eller, per the "Still Entombed" paper.)

---

## 5. The Playability Constraints

The three rules encode specific **playability constraints**:

### Rule 1 -- No Complete Isolation
If a cell would be completely surrounded by the opposite type (all neighbors of b are different from b, or all neighbors of d are different from d), force X to break this isolation. This prevents:
- Single-cell dead ends (a lone passage surrounded by walls)
- Single-cell pillars (a lone wall surrounded by passages)

### Rule 2 -- Density Balance
If one type (wall or passage) is excessively concentrated in the local area (sum > 4), force the opposite. This ensures:
- Passages don't become too wide (which would make the maze trivially easy)
- Walls don't become too thick (which would make the maze impassable)

### Rule 3 -- No Horizontal Runs
If the three middle cells (b, c, d) are all identical, force the opposite. This prevents:
- Long horizontal corridors (boring)
- Long horizontal walls (creating dead ends)

### Emergent Properties
These three local rules, combined with randomness for unconstrained cases, produce mazes with:
- **Sufficient path width** for the player sprite
- **Reasonable density** of walls (neither too sparse nor too dense)
- **Vertical continuity** (passages tend to persist across rows)
- **No guaranteed passability in hard mode** (the make-break mechanic was the game design solution)
- **Guaranteed passability in easy mode** (with the alternate parameter settings)

---

## 6. The Human Story: Debunking the "Drunk Coding" Myth

### Timeline
- **July/August 1981**: Paul Allen Newell and Duncan Muirhead (UCLA math grad student) devise the algorithm over beers at The Gas Lite bar on Wilshire Blvd, Santa Monica
- **August 1981**: Newell implements it on Apple II, then ports to Atari 2600
- **October 1981**: Algorithm extensively documented in printout
- **1981-1982**: Algorithm used in:
  - An unreleased maze game (MAZGAM) with 42 game variations
  - *Towering Inferno* (adapted version)
  - *Entombed* (simplified version by Steve Sidley using Newell's maze code)
- **1982**: Entombed published by US Games (subsidiary of Quaker Oats Company)

### The IP Protection Story
The "drunk/intoxicated" origin story told to Steve Sidley was **deliberate misdirection**. Newell and Muirhead considered the algorithm their intellectual property (developed on their own time, before Muirhead worked at Western Technologies). When Sidley asked how the algorithm worked, he was given only the API documentation -- how to call it, not how it worked. The "I was drunk and can't remember" story was a convenient way to avoid explaining the algorithm's internals.

### The Artefactual Record
Newell preserved ~487 development artefacts:
- 141 assembly source files
- 136 assembler listings
- 80 editor backup files
- 47 hex assembler outputs
- 21 documents
- 14 CP/M executables
- EPROMs, 8-inch floppy disks, printouts, a Polaroid photo

These were analyzed using archaeological methodology (Harris matrix for stratigraphy, catalogue with objective/subjective metadata, deduplication). The artefacts span four lineages: MAZGAM, MAZONLY, ENT, and TOW.

---

## 7. The Bug

Aycock & Copplestone discovered a **35-year-old bug** in the Entombed code. The specifics (from the 2018 paper): during maze generation, a code path that should have been taken in certain boundary conditions was skipped due to a logic error. This resulted in occasionally malformed maze sections, but the effect was minor enough to go unnoticed in playtesting.

---

## 8. Serendipitous Connections

### To Constraint Satisfaction (CS/Math)
The Muirhead-Newell algorithm is an early example of **constraint propagation** in procedural content generation -- a technique now formalized as Wave Function Collapse (WFC) and widely used in modern game development. The core idea is identical: define local constraints, propagate them through a grid, and use randomness where constraints don't determine the output. The Entombed algorithm predates the formalization of WFC by ~35 years.

### To Information Theory (CS)
The algorithm demonstrates a fundamental principle: **a small rule set + entropy source can generate unbounded structured output**. This is the same principle underlying:
- L-systems (Lindenmayer, 1968)
- Procedural terrain generation (Perlin noise, 1983)
- Pseudorandom number generators
- Kolmogorov complexity: the maze has low descriptive complexity despite high apparent complexity

### To Archaeogaming (Humanities/CS intersection)
The Entombed research helped establish *archaeogaming* -- the application of archaeological methods to digital artifacts -- as a legitimate subfield. The "Still Entombed" paper is a model of interdisciplinary collaboration between CS and archaeology, including the innovative inclusion of a primary source (the original developer) as co-author.

### Personal Project Connection: Agent Framework
The constraint-propagation approach in Entombed is conceptually related to **planning algorithms** in multi-agent systems. The idea of local rules producing globally coherent structure (without global planning) connects to emergent behavior in agent-based systems.

---

## 9. Complete Citation Chain

### Primary Papers
1. **Aycock & Copplestone 2019** -- "Entombed: An archaeological examination of an Atari 2600 game" -- *The Art, Science, and Engineering of Programming* 3(2), Article 4. arXiv:1811.02035. DOI: 10.22152/programming-journal.org/2019/3/4 (T1)
2. **Machler & Naccache 2021** -- "Explaining the Entombed Algorithm" -- IEEE Conference on Games (CoG). arXiv:2104.09982. DOI: 10.1109/CoG52621.2021.9619150 (T2)
3. **Newell, Aycock & Biittner 2022** -- "Still Entombed After All These Years" -- *Internet Archaeology* 59. DOI: 10.11141/ia.59.3 (T1)

### Citing Papers
4. Aycock et al. 2022 -- "The Sincerest Form of Flattery: Large-Scale Analysis of Code Re-Use in Atari 2600 Games" -- Proc. 17th Int. Conf. on Foundations of Digital Games. ~3 cit (OpenAlex)
5. Clindaniel & Magnani 2023 -- "Digital Formation Processes: A High-Frequency, Large-Scale Investigation" -- preprint
6. Careri 2022 -- "Dans les profondeurs du code" -- *Techniques & culture*
7. Aycock & Biittner 2024 -- "Experimental Archaeogaming" -- *Advances in Archaeological Practice*

### Media & Community Sources
8. Baraniuk 2019 -- "The mysterious origins of an uncrackable video game" -- BBC Future (T7)
9. Barron & Parkin 2021 -- "Unearthing Entombed" -- The New Yorker Radio Hour podcast (T7)
10. De Chiara 2021 -- "Random maze from Entombed" -- Medium/CodeX (T5)
11. Reddit r/math discussion (colinbeveridge 2019) -- "A mysterious maze algorithm" (T6)
12. AtariAge forum thread (2019) -- "The mysterious origins of an uncrackable video game" (T7)
13. Wikipedia -- "Entombed (Atari 2600)" (T7)

---

## 10. Open Questions

Despite the resolution of the primary mystery, some questions remain:

1. **The undocumented special case (abcde = 11001):** Why was this changed to always produce 0? Newell recalls it fixed "island" formation, but the rationale was never formally documented. The modification appears in early artefacts but its origin is lost.

2. **Duncan Muirhead's mathematical reasoning:** Muirhead was a mathematics graduate student at UCLA. The specific mathematical framework he used to devise the three rules is not recorded. Did he arrive at them through formal constraint analysis, cellular automata theory, or pure intuition? The paper is dedicated to him, suggesting he may have passed away.

3. **Optimality of the rule set:** Are three rules the minimum needed? Could two rules suffice with appropriate parameter tuning? No formal analysis of the rule set's optimality has been published.

4. **The Towering Inferno variant:** The algorithm variant used in Towering Inferno has not been publicly analyzed in detail. How did it differ?

---

## 11. Knowledge Graph Candidates

- **"Muirhead-Newell Maze Algorithm"** -- Type: technique. Links: procedural generation, constraint propagation, Atari 2600, cellular automata
- **"Archaeogaming"** -- Type: framework. Links: digital archaeology, retrogame archaeology, code analysis
- **"Constraint Propagation in PCG"** -- Type: principle. Links: Wave Function Collapse, procedural generation, constraint satisfaction
- **"Entombed (Atari 2600)"** -- Type: concept. Links: US Games, maze generation, retrogaming
- **"Racing the Beam"** -- Type: principle. Links: Atari 2600, TIA chip, real-time constraints

---

## Sources Actually Fetched

| Source | Tier | Status |
|--------|------|--------|
| arXiv:1811.02035 (Aycock & Copplestone) | T1 | Abstract + metadata via S2 extract |
| arXiv:2104.09982 (Machler & Naccache) | T2 | Abstract page fetched |
| intarch.ac.uk/journal/issue59/3 (Newell et al.) | T1 | Full text fetched (chunks 0-7, 10, 12) |
| Semantic Scholar API for 1811.02035 | -- | Full citation/reference data extracted |
| OpenAlex search | -- | 7 results, cross-referenced |
| Wikipedia "Entombed (Atari 2600)" | T7 | Partial fetch |
| BBC Future article (Baraniuk 2019) | T7 | Header/metadata fetched |
| Medium/CodeX (De Chiara 2021) | T5 | Metadata fetched |
| Reddit r/math thread | T6 | Header fetched |
| IEEE CoG paper PDF | T2 | Binary PDF (not readable as text) |

No citations were fabricated. All arXiv IDs, DOIs, and venue names were verified against fetched data.
