# FPGA-street-fighter — contribution assessment

Source: `/home/farsoudi/git/FPGA-street-fighter` (branch `main`, 89 commits total,
Apr 11 – May 1 2025). Two contributors: **Kasra Farsoudi** (git identities
`kfarsoudi <farsoudi@gmail.com>` and `kasra farsoudi <...@users.noreply.github.com>`,
22 commits incl. 2 merges) and **Luke Albert** (`Luke Albert <lukeaalbert@gmail.com>`,
~67 commits). Compiled by reading every diff Kasra authored (not just commit
messages) plus the current state of every source file.

A Verilog game — a Street Fighter clone — built for and synthesized onto a
Nexys A7 FPGA, controlled by two custom breadboard remotes (push buttons +
5-position switch) over Pmod ports, output over VGA. ~1450 lines of Verilog
across 13 modules, plus a handful of Python sprite-conversion scripts and 20+
`.mem` ROM files holding pre-rendered sprite pixel data.

## What Kasra built

### Owned outright (sole author per file headers + full commit history)

- **`game.v`** — the core game/simulation module. This is the piece that
  turns raw button state into game state each clock:
  - Instantiates both `player` submodules and wires up their control signals.
  - AABB collision detection (`collision_x`, `collision_y`), purely
    combinational (`assign`).
  - Attack resolution: decrements the opponent's health when an attack
    request rises (edge-detected via a `_prev` register, not level-triggered
    — avoids draining health every clock while a button is held), gated on
    horizontal overlap, the defender not shielding, the attacker facing the
    defender, and the game not being over.
  - Player-facing-direction tracking (`p1_facing_p2` / `p2_facing_p1`) used
    both for the sprite renderer and to gate attacks so you can't hit someone
    behind you.
  - Movement/positioning logic on a slowed ~125Hz clock (`main_clk_to_slowed_clk`
    instance), with arena boundary and collision-based movement blocking.
  - The win/game-over state machine (`finish` register: bit 0 = game over,
    bit 1 = which player won).
- **`player.v`** — per-player state machine. One-hot 7-bit action register
  (`{direction, one_hot_state}`) covering walking / crouching / shielding /
  jumping / punching / standing, built specifically so the same register
  drives both sprite selection and combat logic downstream without a
  separate decoder. Also owns:
  - Shield drain/regen on its own 2Hz derived clock, fixed later so it only
    drains while the player is actually in the `SHIELDING` state (an early
    version drained shield just from holding the shield button, regardless
    of `action`).
  - Jump timer and punch-cooldown timer integration (see `timers.v`).
  - A combinational direction latch that freezes facing direction once
    `finish` is asserted — added specifically to fix a reported bug where
    players kept flipping left/right after the match ended.
- **`timers.v`** — a general-purpose parameterized fractional-second
  countdown timer (`timer_fraction_second`), written from scratch as the
  very first commit on this project. Takes a `fraction` denominator and
  exposes `running` / `halfway` / `done`; reused unmodified for both the
  jump arc (halfway point flips vertical direction) and the punch cooldown.
- **`finish.v`** — game-over/win-screen module. Reads two dedicated
  `win_p1.mem` / `win_p2.mem` sprite ROMs and muxes between them based on
  which player won, composited into `vga_bitchange` as an overlay region
  once `finish[0]` is set.

### Co-authored (headers list both names; diffs show the actual split)

- **`bars.v`** (health/shield bar rendering): Kasra wrote the initial
  module — interface, color parameters, and a TODO-list comment literally
  addressed to Luke ("feel free to add/remove, this is just an initial
  blueprint... i just think its a good idea to not add too much code to the
  bitchange file") — then Luke implemented the actual bar-region pixel math.
  A clean example of Kasra scaffolding an interface and handing off the
  fiddly geometry work.
- **`player_sprite.v` / `sprite_map.v`** (sprite fetch pipeline): originally
  four separate ~30-line modules (`p1_standing.v`, `p1_walking1.v`,
  `p1_walking2.v`, `p1_crouching.v`) that were near-identical boilerplate
  differing only in which `.mem` file they loaded. Kasra's
  `d5289ab` commit collapsed these into a single parameterized `sprite_map`
  module (`FILENAME` parameter) and added the horizontal pixel-mirroring
  address computation needed for the "facing left" flipped-sprite rendering
  (`(addr + 127) - 2*(addr % 128)`, later widened to `[13:0]` after Kasra
  caught a width bug). Luke had built the original per-frame modules and
  later extended `player_sprite.v` to add attack-animation framing on top of
  Kasra's refactor.

### Tooling

- **`src/png_to_mem_sprite.py`** — Kasra turned Luke's original
  single-hardcoded-path script (`sprites/player2/shield.png` → `p2_shield.mem`)
  into a general CLI tool driven by `sys.argv`, auto-deriving output filename
  and image dimensions from the input.
- **`src/mem_to_png.py`** — new script Kasra wrote going the *other*
  direction (`.mem` → `.png`), purely for debugging: lets you visually check
  what a generated sprite ROM actually contains without loading it onto
  hardware first.

### Bug fixes / integration work

- Fixed a copy-paste bug where every `p2_*_btn` wire read from `p1_inputs`
  instead of `p2_inputs` (player 2 controls were dead until this).
- Fixed a typo'd port connection (`.p2s_action` → `.p2_action`) that broke
  synthesis.
- Fixed active-low reset bugs left over from an early `negedge reset`-based
  design style, converting timer/player reset logic to synchronous `!reset`
  checks inside `posedge clk` blocks (the synthesizable pattern the rest of
  the project settled on).
- Reworked the `finish` bit-order convention twice (`{finish[1],finish[0]}`
  semantics) while wiring the win screen and the red damage-flash overlay in
  `vga_bitchange.v`, to fix which player's sprite flashed red / which win
  screen showed.
- Adjusted arena boundaries and `character_width` (128 → 70 → 80) to track
  the actual visible width of the sprites once real artwork replaced
  placeholder collision boxes.
- Merged his own early `player` branch into `main` and reconciled it with
  Luke's concurrently-developed VGA/controller branch (`f0eed9b`, `4c34aea`),
  then debugged the combined design back to a synthesizable state
  (`3564c5d`, `d25a1fe`, `5afcdd4`) — this is where the standalone
  `src/game/*.v` prototype tree gets deleted in favor of the merged
  `src/street_fighter_game/` tree.
- README: added his headshot to the closing section.

## What Luke Albert owned (for contrast, not itemized in depth)

VGA scan/display pipeline (`vga_bitchange.v`, `street_fighter_top.v`),
controller hardware interface (`controller.v`, `input_debouncer.v`,
Pmod/XDC pin constraints), the sprite artwork itself and most of the
animation-timing polish (walking/attack frame switching, damage flash),
shield-bar visual polish once Kasra's `bars.v` blueprint existed, end-game
screen integration polish, and most of the README narrative/diagrams.
(`display_controller.v` is attributed to "EE 354 Staff" — i.e. course-provided
starter code, not authored by either of them.)

## How the work actually split

Roughly a vertical split by layer, not a horizontal split by feature:

- **Luke = I/O layer** — getting raw electrical signals in from the
  controllers and pixels out to the VGA display.
- **Kasra = simulation/rules layer** — what those signals *mean* each clock:
  player state, collision, combat resolution, health/shield bookkeeping, win
  condition. The "game engine" as distinct from the "renderer."

This is visible directly in the file `Author:` headers, which is unusually
explicit for a two-person student project — both contributors were
disciplined about crediting module ownership in-code, not just via git
blame.

## Technical points worth highlighting on a resume

- Designed the core game state as a single one-hot 7-bit register
  (direction bit + 6-bit one-hot action) shared verbatim between the combat
  logic and the sprite-selection logic, avoiding a second decode stage.
- Combat/health logic is edge-triggered off a request signal transition
  rather than level-triggered, a deliberate choice to avoid multi-cycle
  double-hits from a held button — the kind of bug that's easy to miss in
  RTL and easy to demo going wrong.
- Managed multiple independent clock domains derived from a single 100MHz
  input via a shared parameterized clock-divider module (`main_clk_to_slowed_clk`)
  — separate slow clocks for movement (~125Hz), shield drain (2Hz), and
  sprite animation — instead of relying on an FPGA PLL/MMCM.
- Wrote a reusable parameterized timer module (fraction-of-a-second
  countdown with a `halfway` flag) and reused it for two unrelated game
  mechanics (jump arc, punch cooldown) rather than writing bespoke counters
  for each.
- Refactored duplicated per-sprite ROM-loading modules into one
  parameterized module driven by a string parameter — real code-reuse
  instinct applied to Verilog, which is less common in student HDL
  submissions than in software.
- Iterated the design through several synthesizability bugs (bad
  reset-edge sensitivity, mismatched bus widths, a stray unconnected wire)
  visible directly in the commit history — evidence of an actual
  build/test/debug-on-hardware loop (bitfiles committed under `bits/` at
  each milestone: `v1.bit` … `v7.bit`, `collisionworking.bit`,
  `game_over.bit`, `4-28-25.bit`), not just a single write-once submission.
