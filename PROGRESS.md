# Progress

## Architecture decision (milestone 0)

**Plain data, explicit loop; no ECS.** Iron Doom's Bevy structure maps onto
Nucleus as follows:

- **Resources → fields of one `Game` struct** (`doom.game`): the WAD, the
  screen buffer, the RNG, the input state, the current level.
- **States + state-scoped entities → a `defunion` mode** (`Intro`, `Level`,
  `Melt`). Per-mode data lives inside its arm, so leaving a mode drops it,
  which is what `StateScoped` gave Bevy. `match` replaces `run_if(in_*_state)`.
- **Schedules → one explicit tic function** (`game-tic`) that runs the
  subsystems in Bevy's order: input (PreUpdate), the fixed-tic simulation
  (FixedUpdate), transitions (Update), rendering (PostUpdate), present (Last).
  Iron Doom renders every frame and simulates at 35 Hz; the port renders once
  per tic, which is the same picture since nothing moves between tics.
- **Events → return values.** `LoadLevel`, `InitMeltScreen`, `Exit` become
  the result of a tic (`Transition`) that the loop acts on.
- **Entities + `Instance<T>` handles → one `Vector` per kind in a `Level`,
  linked by index** (`doom.level`). A line or segment's Wall/Portal enum
  becomes an optional back sector, and the BSP's `Rc` tree becomes a vector of
  branches whose children are a `BspNode` union (branch index or subsector).
  Indices rather than `&T` because a level is built in stages and the vectors
  grow while it is.
- **`anyhow::Result` + `#[sys_fail]` → `!T` and `try`**, propagated to `main`,
  the only place that prints and exits.
- **`clap` derive → a macro (`defoptions`)** over a written options struct:
  one table row per flag gives the spelling and help, and the field's type picks
  the overloaded `read-option` that parses it. The macro checks each row names a
  field (`struct-fields`).
- **WAD record parsers → `derive-record`**, which generates each map record's
  size and little-endian reader from its written struct, plus a generic
  `read-records` over a `Record` protocol. (The first design generated the
  structs too; ISSUE-011 made a macro-defined type unusable in signatures.)
- **`anyhow` messages → `(Fallible T)`**, a `Result` whose error carries a
  formatted message, with `defcast`s both ways to the stdlib's `!T`, and a
  `fail` macro for `bail!`.

Why not a macro-built ECS: Iron Doom's systems each touch one or two
resources, and the world is a fixed set of level arrays. An ECS would add a
component store, queries and schedules to express what a struct and a
function call already say. Where Bevy's machinery carried real meaning
(state-scoped cleanup, ordered schedules), the union and the tic function keep
it.

## Status

| Milestone | State |
|---|---|
| 0. Setup | done, except the reference frames (see below) |
| 1. Foundations | done: CLI and response files, IWAD search, WAD directory, every lump parser, RNG, 12 unit tests |
| 2. Screens | done except the framedump gate: title (tic 2) and melt run; frames can't be compared until the reference is built |
| 3. Level and walls | done except the framedump gate (blocked like milestone 2's): E1M1 renders; movement matches an independent f32 model of Iron Doom's bit for bit over 80 tics; playtest requested below |
| 4–8 (phase B) | not started |

## Reference frames

`reference/iron-doom.patch` adds `--framedump` to Iron Doom (one fixed tic per
frame through Bevy's `TimeUpdateStrategy::ManualDuration`, so dumps are
deterministic). **Not recorded yet:** auto mode denied building the cloned Iron
Doom from a session. To record them, either approve
`scripts/build-reference.sh` in a session, or add it to the environment's
setup script after `setup-cloud.sh`.

## Compiler fixes

Fixes the port made to Nucleus. The session can't push to `zakwilson/nucleus`,
so each is committed in `../nucleus` (branch `doom-bugfixes`) and carried here
as a patch in `nucleus-patches/`, which `setup-cloud.sh` applies.

| Issue | Nucleus commit | Patch |
|---|---|---|
| ISSUE-006 | `06230b5` | `nucleus-patches/0001-*.patch` |
| ISSUE-009 | `ac05293` | `nucleus-patches/0002-*.patch` |
| ISSUE-013 | `36c13e3` | `nucleus-patches/0003-*.patch` |
| ISSUE-016 | `7bb5257` | `nucleus-patches/0004-*.patch` |

Each passed the nucleus gate here (after 0004: 1677 passed, the 4 avr-gcc
failures of the baseline, 6 skipped; `make bootstrap` PASS once converged).
0003 and 0004 change the compiler's own code generation, so after applying
them `make bootstrap` reports a diff until it is converged (nucleus
`context/build.md`, "After a codegen change"). `make` itself is unaffected.
The converged `boot/*.ll` can't be pushed to `nucleus-boot` from here.
## Playtest request (milestone 3)

The port now reaches E1M1 and can be walked around, as far as Iron Doom goes:
walls and their textures, no floors, ceilings, sprites or collision.

To build on your machine:

1. Check out this branch, `claude/keen-turing-prxm4z`.
2. In your `nucleus` clone, on `doom-bugfixes`, apply the carried fixes:
   `git am <path>/nuc-iron-doom/nucleus-patches/*.patch` (skip any already
   applied), then `make`. Patches 0003 and 0004 move the bootstrap, so to
   keep `make bootstrap` green run `make update-bootstrap` and `make` again.
3. Here: `NUCLEUS_HOME=<path>/nucleus . scripts/env.sh`, then `nucleus build`.
4. Run `build/nuc-iron-doom` (it searches for `doom1.wad` or `doom.wad` as
   Iron Doom does; `-iwad FILE` names one).

Controls, as Iron Doom binds them: arrows or WASD to move and turn, Shift to
run or turn fast, A/D or `,`/`.` (or Alt+arrows) to strafe, Escape or closing
the window to quit.

Please check:

- The title, then the melt into E1M1 after about 1.7 s.
- Walls in the start room and beyond: textures aligned, steps and the
  computer wall where you'd expect them, nothing flickering as you turn.
- Turning starts slow for about a sixth of a second, then speeds up.
- Movement glides to a stop, with no collision (you can walk through walls).

Known problems, all Iron Doom's own: no floors or ceilings (black), no
sprites, no collision, and the view height never follows the floor. The
frames haven't been compared with Iron Doom's yet (the reference build is
blocked here), so a misplaced texture is worth reporting.

## In flight

- Nothing long-running.

## Next steps

- Milestone 4 (planes and things): fixed-point math and the trig tables
  (embedded: `reference/tools/gen-tables.py`, since no rounding of sin, tan
  or atan reproduces them), then Chocolate Doom's renderer.
