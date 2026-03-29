# Touch-Based Movement in Mobile Maze Games: Industry Patterns and Implementation

## Research Summary

**Epistemic status:** Practitioner consensus from game dev forums, shipping games, and industry articles. No peer-reviewed literature on this specific topic -- this draws on game developer community knowledge (equivalent to T5-T7 sources).

**Confidence:** High for the taxonomy of control schemes (observable from shipped games). Medium for implementation details (reconstructed from forums, tutorials, and reverse-engineering observations).

---

## 1. The Four Control Paradigms

Mobile maze games use one of four fundamental touch control schemes. The choice depends on the game's pacing, grid granularity, and target audience.

### 1A. Swipe-Per-Step (Discrete Swipe)

**How it works:** Each swipe gesture = one cell move in that direction. The player lifts their finger and swipes again for the next move.

**Games that use it:**
- **Maze Swipe** (by spcomes) -- explicitly "simple swipe" per their Play Store description
- Many puzzle-maze hybrids (Sokoban-style)
- **2048** and its derivatives (swipe = one board shift)

**When to use:** Turn-based or puzzle mazes where each move is deliberate. Good when the maze is small and you want the player to think about every step.

**Feel:** Precise but slow. Players report frustration in larger mazes because the gesture count becomes exhausting. Works well when the maze fits on one screen and has < 30 moves to solve.

**Implementation:**
```
onTouchEnd:
  delta = touchEnd - touchStart
  if |delta| > SWIPE_THRESHOLD (typically 30-50px):
    direction = dominant axis of delta (|dx| > |dy| ? horizontal : vertical)
    move player one cell in that direction (if not blocked by wall)
```

### 1B. Continuous Drag ("Drag to Slide")

**How it works:** The player puts their finger down and drags continuously. As the finger moves, the player character moves through the maze in real-time. The character follows the finger's general direction but is constrained to the grid corridors.

**Games that use it:**
- **AMAZE!!!** (by CrazyLabs) -- "Swipe your finger to move the ball" per App Store. The ball slides continuously until hitting a wall, painting cells as it goes. Each swipe sends the ball in a direction until it hits an obstacle (ice-puzzle mechanic).
- **Maze: Puzzle and Relaxing Game** (Critical Hit) -- offers both "manual dragging" and "automatic" modes per App Store reviews. The manual mode is continuous drag.
- Many "color maze" and "fill maze" games

**When to use:** Action mazes, real-time mazes, or mazes where speed/flow matters. The dominant pattern for casual mobile maze games.

**Feel:** Fluid and intuitive -- the finger-follows-character mapping is natural. The key challenge is converting continuous pixel movement into discrete grid steps (see Section 3).

### 1C. Tap-to-Move (Pathfinding)

**How it works:** The player taps a destination cell (or a point on a walkable path), and the character automatically pathfinds to that location, walking the shortest route.

**Games that use it:**
- **Monument Valley** (ustwo games) -- the canonical example. "Tap the path to move Ida" is the game's first instruction (MacStories review, 2014). You tap where you want Ida to go, and she walks there via A* or similar pathfinding. The interaction focus is on manipulating the environment (rotating cranks, sliding platforms), not on navigating Ida directly.
- Point-and-click adventure games adapted to mobile

**When to use:** When the puzzle is about the ENVIRONMENT, not the navigation. Monument Valley's brilliance is that movement is trivial (tap where you want to go) so the player's mental energy goes to the impossible geometry puzzles. Also good when the maze is 3D/isometric and direct swipe mapping would be ambiguous.

**Feel:** Elegant and stress-free. Zero precision required from the player. But removes the "skill" of navigation -- you can't make the player feel clever for navigating if the pathfinding does it for them. Bad choice for mazes where navigating IS the challenge.

**Monument Valley specifics:**
- Orthographic 3D projection -- the character moves on a 2D path network overlaid on the 3D geometry
- Pathfinding respects the current "visual" connectivity (impossible geometry: if two platforms LOOK connected from the current camera angle, they ARE connected for pathfinding purposes)
- Movement is animated as smooth walking along edges, not cell-to-cell snapping
- Source: Polygon 2014, Creative Bloq 2014, Gamasutra/Game Developer 2014 (Ken Wong interview)

### 1D. Virtual Joystick / D-Pad

**How it works:** An on-screen joystick or directional pad appears (either fixed-position or floating at the touch-down point). The player holds and tilts to move continuously.

**Games that use it:**
- **PAC-MAN** (mobile, Bandai Namco) -- offers both swipe controls AND an in-game joystick (per official support page). The joystick queues the next direction for when Pac-Man reaches an intersection.
- **Amaze** (the first-person maze simulator by Common Sense Media) -- "two-handed touchscreen controls"
- Many retro-style maze games ported to mobile

**When to use:** When continuous analog control is needed, or for ports of controller-based games. Generally considered the WORST option for mobile-native design (Tim Rogers, Game Developer Magazine, 2013: virtual joysticks are "a lie" -- they lack the tactile feedback that makes physical joysticks work). Community consensus on r/gamedev is strongly anti-virtual-joystick for new mobile games.

**Feel:** Familiar to gamers but widely disliked. The finger occludes the joystick area. No tactile center-point. Floating joysticks (appear at touch-down position) are better than fixed ones.

### 1E. Tilt / Accelerometer (Bonus: not touch-based)

**Games:** **Labyrinth** (Illusion Labs) -- the classic marble-in-a-maze game using device tilt. Not touch-based but worth mentioning as a distinct mobile maze paradigm.

**Feel:** Very physical and satisfying for marble/ball mazes. Terrible for precision grid navigation. Limited to physics-based mazes.

---

## 2. The "Corridor Following" Pattern (Auto-Corridor / Rail Movement)

This is the most interesting and underappreciated pattern. It appears in continuous-drag maze games and hybrid swipe-drag games.

### How it works

The player drags in a general direction. The character moves in that direction along the corridor. When the character reaches a corner or junction:

1. **If there is only ONE viable continuation** (a forced turn, e.g., corridor turns 90 degrees): the character turns automatically. The player does not need to change their drag direction.
2. **If there is a junction** (T-intersection, crossroads): the character stops OR continues in the direction most aligned with the current drag vector.

### The Pac-Man precedent

This is exactly how Pac-Man works on mobile (and originally in the arcade):
- Pac-Man moves continuously in the current direction
- The player's input is a "queued next direction" -- when Pac-Man reaches the next intersection where that turn is legal, he takes it
- If no input is queued, Pac-Man continues straight (or stops at a dead end)
- **PAC-MAN 256** (Apple Arcade) review: "You can swipe at anytime before the turning point, so you don't have to time it exactly right"

This is the **input buffering** or **pre-turn** technique: the game remembers the last directional input and applies it at the next opportunity.

### Implementation pattern

```
// State
currentDirection: Direction  // where the player is currently moving
queuedDirection: Direction   // where the player WANTS to go next
position: Vector2            // current pixel position
gridPosition: Cell           // current grid cell

// Each frame:
function update(dt):
    // Try the queued direction first
    if queuedDirection != null:
        nextCell = gridPosition + queuedDirection.offset
        if maze.isWalkable(nextCell):
            currentDirection = queuedDirection
            queuedDirection = null

    // Move in current direction
    if currentDirection != null:
        nextCell = gridPosition + currentDirection.offset
        if maze.isWalkable(nextCell):
            // Smoothly interpolate position toward next cell center
            position += currentDirection.vector * speed * dt
            if reachedCellCenter(position, nextCell):
                gridPosition = nextCell
                // Auto-corridor: if only one exit (besides where we came from),
                // auto-turn
                exits = maze.getExits(gridPosition) - oppositeOf(currentDirection)
                if exits.length == 1:
                    currentDirection = exits[0]
                elif exits.length == 0:
                    currentDirection = null  // dead end, stop
                // else: multiple exits, keep going straight if possible
        else:
            currentDirection = null  // wall ahead, stop

// On drag input:
function onDrag(delta):
    queuedDirection = dominantDirection(delta)
```

### The "auto-corridor" variant

Some games go further: when at a junction, if the player's drag vector is clearly pointing toward one of the exits (within a tolerance cone, e.g., +/- 45 degrees), the character takes that exit automatically. The player never needs to make a precise orthogonal swipe -- a rough diagonal drag that is "mostly right" will work.

This is the key to making continuous drag feel good in a maze: **the game is generous in interpreting the player's intent**.

### Games known to use corridor following:
- PAC-MAN mobile (all versions)
- Most "color fill" maze games (AMAZE!!!, etc.)
- Runner-style maze games
- The GDevelop forum thread (2023) shows a developer specifically asking for "colour maze game" movement where "colliding with walls and stopping" -- this is the corridor-following pattern

---

## 3. Vector-Based Movement: Converting Drag to Grid Steps

This is the most implementation-heavy section. When using continuous drag input on a grid-based maze, you need to solve several sub-problems.

### 3A. Drag Distance Accumulation ("Residual Credit")

**The problem:** A finger drag of 73 pixels should produce more movement than a drag of 12 pixels, but the character moves in discrete cell steps (e.g., 40px per cell).

**The solution -- accumulator pattern:**

```
// State
dragAccumulator: Vector2 = (0, 0)
CELL_SIZE: float = 40  // pixels per cell

function onDragUpdate(dragDelta: Vector2):
    dragAccumulator += dragDelta

    // Determine dominant axis
    if |dragAccumulator.x| >= |dragAccumulator.y|:
        axis = X
    else:
        axis = Y

    // Convert accumulated distance to cell steps
    while |dragAccumulator[axis]| >= CELL_SIZE:
        direction = sign(dragAccumulator[axis]) along axis
        if maze.canMove(playerCell, direction):
            playerCell += direction.offset
            dragAccumulator[axis] -= sign(dragAccumulator[axis]) * CELL_SIZE
        else:
            // Wall hit -- consume the accumulator (don't let it build up)
            dragAccumulator[axis] = 0
            break

    // CRITICAL: do NOT zero out the cross-axis accumulator
    // It carries over for potential direction changes
```

**Key insight -- the "residual credit" technique:**
After moving one cell (consuming CELL_SIZE pixels from the accumulator), the REMAINDER stays in the accumulator. So if the player drags 73px in one frame:
- First cell move at 40px: remainder = 33px
- 33px < 40px, so no second move yet
- Next drag frame adds more: 33 + next_delta might cross 40px threshold

This is what makes movement feel fluid rather than jerky. Without residual credit, small fast drags get "eaten" and the player feels like the game is dropping inputs.

### 3B. Diagonal Drag in a 4-Directional Grid

**The problem:** The player drags diagonally (e.g., down-right at 45 degrees). The maze only allows 4-directional movement.

**Standard solution -- dominant axis with wall fallback:**

```
function resolveDirection(dragDelta: Vector2) -> Direction:
    // Primary: dominant axis
    if |dragDelta.x| >= |dragDelta.y|:
        primary = dragDelta.x > 0 ? RIGHT : LEFT
        secondary = dragDelta.y > 0 ? DOWN : UP
    else:
        primary = dragDelta.y > 0 ? DOWN : UP
        secondary = dragDelta.x > 0 ? RIGHT : LEFT

    // Try primary direction first
    if maze.canMove(playerCell, primary):
        return primary

    // Wall fallback: try secondary direction
    // This is what makes diagonal drags feel forgiving
    if maze.canMove(playerCell, secondary):
        return secondary

    return null  // stuck
```

**Wall fallback is CRITICAL for feel.** If the player drags diagonally at a T-intersection, the game should try the closest match first, then fall back to the other axis. Without this, players constantly get stuck when they drag at even slightly off-axis angles.

**Refinement -- angular dead zones:**
Some implementations add a small dead zone around the 45-degree diagonals (e.g., if the angle is within 10 degrees of 45/135/225/315, suppress input entirely until the player commits to a direction). This prevents flickering between axes. The Pac-Man Construct 2 tutorial uses a simpler variant: "Compare which is greater, the absolute value of X or Y, and move in the corresponding direction."

### 3C. Making Movement Feel Fluid

The accumulated wisdom from game dev forums and the Game Developer articles (Tim Rogers 2013, Louis-Nicolas Dozois/Suzy Cube 2017) on what makes touch movement feel good:

1. **Zero startup delay.** Movement must begin on the SAME FRAME as the touch input. Any delay (even 1-2 frames) feels "laggy" on a touchscreen because the finger is physically on the screen -- the expectation of direct manipulation is stronger than with a controller.

2. **Smooth interpolation between cells.** Never "teleport" the character from cell center to cell center. Always lerp/tween the position. A typical approach:
   - The logical position (grid cell) updates immediately when a move is committed
   - The visual position smoothly catches up over 50-150ms
   - If the player inputs a new move before the animation finishes, the animation SPEEDS UP or SNAPS to complete, then begins the new move

3. **Input buffering / pre-turn.** Allow the player to input the next direction BEFORE reaching the turning point. The game stores it and executes at the first opportunity. This is universally used in Pac-Man clones and corridor-following games. Buffer window: typically 100-300ms or "until the next intersection" -- whichever is larger.

4. **Generous hitboxes for turns.** When the player is 2-3 pixels past an intersection, still allow the turn. This is the "cornering tolerance" -- the player's grid position snaps back to the intersection center before executing the turn. The GameDev StackExchange thread on "cornering in a 2D maze game" specifically addresses this: round the player's position to the nearest valid turning point.

5. **Do not accumulate drag while blocked.** If the character is against a wall, drain the accumulator in that direction to zero. Otherwise, when the wall ends, the character will "jump" forward by the accumulated distance, which feels horrible.

6. **Haptic feedback on wall collisions.** A subtle vibration (10-20ms) when hitting a wall tells the player they need to change direction without requiring them to look at their character.

7. **The finger offset problem.** The player's finger covers the character. Solutions:
   - Use a relative-drag model (movement = drag DELTA, not absolute finger position) -- the character moves RELATIVE to where you started, not under your finger
   - Or offset the character slightly above the finger position
   - The mobilefreetoplay.com article (Adam Telfer, 2014) specifically recommends: "keep the controlled object slightly offset from the finger so it remains visible"

8. **Speed scaling with drag distance.** Some games make the character move faster when the finger is dragged further from the touch-down point (like a virtual joystick radius). This gives the player analog speed control while maintaining grid movement.

### 3D. Reset the Accumulator on Direction Change

When the player changes drag direction (e.g., was dragging right, now dragging down), you should:
- Zero the OLD axis accumulator (don't carry over horizontal drag into vertical movement)
- Keep the new axis accumulator starting from zero
- This prevents "phantom" moves in the old direction

```
function onDragUpdate(dragDelta):
    dragAccumulator += dragDelta
    newDominantAxis = dominantAxis(dragDelta)

    if newDominantAxis != currentMovementAxis:
        // Direction change: zero the old axis
        dragAccumulator[currentMovementAxis] = 0
        currentMovementAxis = newDominantAxis
```

---

## 4. Game-Specific Reference Analysis

### Monument Valley (ustwo, 2014)
- **Control:** Tap-to-move (pathfinding). Not swipe or drag.
- **Why:** The puzzle is the geometry, not the navigation. Tap is the simplest possible movement input, letting the player focus on rotating platforms and optical illusions.
- **Technical:** A* pathfinding on a walkable-edge graph. The graph is dynamically updated when the player rotates/slides level elements. Orthographic 3D camera makes 2D pathfinding work on a 3D scene.
- **Lesson:** Match the control scheme to where the CHALLENGE lives.

### AMAZE!!! (CrazyLabs, 2019)
- **Control:** Swipe-to-slide. One swipe sends the ball in a direction until it hits a wall (ice-puzzle mechanic). Not continuous drag -- each swipe is a commitment.
- **Mechanic:** The ball paints every cell it passes through. Goal: fill all cells.
- **Why:** The ice-slide mechanic creates a planning puzzle (where do I swipe from to cover all cells?) while keeping input dead simple.
- **Lesson:** "Swipe and slide until wall" is a distinct third pattern between "swipe per step" and "continuous drag." Extremely common in casual puzzle games.

### PAC-MAN (Bandai Namco, mobile)
- **Control:** Swipe anywhere on screen OR virtual joystick (player's choice). The swipe sets the queued direction.
- **Implementation:** Classic corridor-following with input buffering. "You can swipe at anytime before the turning point" (App Store review of PAC-MAN 256).
- **Ms. Pac-Man (2008)** TouchArcade review: "Simply swiping your finger up, down, left or right anywhere on the screen provides a precise way for you to direct your Pac-Man. There is no 'center' that needs to be remembered or visualized."
- **Lesson:** Swipe-anywhere (no fixed joystick position) is strongly preferred for directional input.

### Labyrinth (Illusion Labs)
- **Control:** Tilt/accelerometer. Not touch.
- **Mechanic:** Physical marble simulation with realistic physics.
- **Lesson:** Tilt is excellent for physics-ball-in-maze games and terrible for everything else.

### Mazes & More (Mobirix)
- **Control:** Offers BOTH tap and swipe as options. Per App Store: "In-game navigation: allows you to customize with tap or swipe on-screen controls."
- **Lesson:** Offering choice is good, but pick a default that matches your game's pacing.

### Maze Swipe (spcomes)
- **Control:** Pure swipe-per-step. 400 stages. Tiny maze per level.
- **Lesson:** Swipe-per-step works when mazes are small (fits on screen, < 20 moves).

---

## 5. Decision Framework: Which Pattern to Choose

| Factor | Swipe-per-step | Continuous drag | Tap-to-move | Virtual joystick |
|--------|---------------|----------------|-------------|-----------------|
| **Pacing** | Puzzle/turn-based | Action/real-time | Exploratory | Action |
| **Maze size** | Small (< 15x15) | Any | Any | Any |
| **Challenge is...** | Each move matters | Speed/reaction | Environment manipulation | Dexterity |
| **Casual friendliness** | High | High | Very high | Low |
| **Precision** | Very high | Medium | N/A (pathfinding) | Low |
| **Fatigue (long sessions)** | High (many swipes) | Low | Very low | Medium |
| **Implementation complexity** | Low | High (accumulator, wall fallback) | High (pathfinding) | Medium |

**The swipe-and-slide-to-wall variant** (AMAZE!!!) is a special case that combines the simplicity of swipe-per-step with the satisfaction of continuous movement. It is arguably the most popular pattern in casual mobile maze games today.

---

## 6. Practical Recommendations for Implementation

If you are building a mobile maze game, here is the recommended approach based on the patterns above:

### For a casual puzzle maze (small grids, thinking game):
Use **swipe-and-slide-to-wall** (AMAZE-style). One swipe = ball slides until wall. Simple, satisfying, no accumulator needed.

### For a real-time/action maze (Pac-Man style):
Use **continuous drag with corridor following**:
1. Implement the drag accumulator with residual credit
2. Add wall fallback for diagonal drags
3. Add input buffering (queue the next direction)
4. Add cornering tolerance (snap to intersection center)
5. Auto-turn at forced corners (only one exit)
6. Add a light haptic on wall hits

### For a puzzle game where the maze is the decoration, not the challenge:
Use **tap-to-move with pathfinding** (Monument Valley style). A* on the walkable graph. Let the player focus on whatever the REAL puzzle is.

### Avoid:
- Virtual joysticks for maze games (community consensus is overwhelmingly negative)
- Swipe-per-step for large mazes (too many gestures, player fatigue)
- Tilt controls for anything except physics marble games

---

## Sources

- **Game Developer (ex-Gamasutra):** Tim Rogers, "Let's Talk About Touching: Making Great Touchscreen Controls" (2013) -- Game Developer Magazine reprint
- **Game Developer:** Louis-Nicolas Dozois, "Lessons from Suzy Cube: Mobile Controls That Feel Great" (2017)
- **Game Developer:** "Designing better controls for the touchscreen experience" (2013)
- **mobilefreetoplay.com:** Adam Telfer, "Designing A Touch Mechanic" (2014/2018)
- **TouchArcade:** Namco's Ms. Pac-Man Game Controls review (2008)
- **Bandai Namco Support:** PAC-MAN mobile control documentation
- **Apple App Store:** AMAZE!!!, Mazes & More, Maze Swipe, PAC-MAN 256 -- user reviews and descriptions
- **Construct.net:** "Cloning the Classics: PacMan -- Grid-based movement" tutorial (2012)
- **Unity Discussions:** "Swipe Movement On A Grid" thread (2021) -- developer asking about accumulating drag for grid movement
- **GDevelop Forum:** "Swiping Movement Game" (2023) -- developer building color-maze with wall collision
- **GameDev StackExchange:** "Best way to handle cornering in a 2D maze game" (Q&A)
- **UX StackExchange:** "Best practices for direction control in 2d game on mobile" (2014)
- **Multiple r/gamedev threads:** virtual joystick vs touch input discussions (2016-2024)
- **Monument Valley sources:** Polygon (2014), Creative Bloq (2014), MacStories (2014), steveparis.net interview (2014), Game Developer/Gamasutra Ken Wong interview

## Serendipitous Connections

**Preference learning (Ranking Todo project):** The question "which control scheme feels best" is inherently a preference learning problem. If you were to A/B test control schemes, the Bradley-Terry model from the Preference Sort project could rank them. Each player session is an implicit "comparison" -- retention rate and session length as the outcome variable.

**No unexpected cross-domain academic connections found** for this primarily practitioner-knowledge topic.
