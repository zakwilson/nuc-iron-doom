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
- **Entities + `Instance<T>` handles → arrays in a level arena with `&T`
  links.** Sectors, sides, lines, segments and subsectors are `(Slice T)` views
  over one `Arena` per level; links between them are non-null `&T` (or `?&T`
  for a back sector). Dropping the arena unloads the level.
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
| 2. Screens | not started |
| 3. Level and walls | not started |
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
| ISSUE-009 | not yet committed (gate running) | — |

## In flight

- ISSUE-009's compiler gate (`make -k test bootstrap` in `../nucleus`). The
  fix is in `../nucleus`'s working tree, and the port's `cli.nuc` needs it.

## Next steps

- Commit ISSUE-009 in `../nucleus` and add its patch.
- Milestone 2: SDL video (palette, gamma, 320×200 into a 4:3 window), patch
  drawing, title screen, melt, input, exit, `-framedump`.
