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
| 4. Planes and things | done except the framedump gate: Chocolate Doom's renderer (`doom.render.*`) draws walls, visplanes, sky, light, sprites and masked middle textures, and the game draws from the playsim's console player. The weapon sprites remain (below) |
| 5. Playsim | in progress, playable: all of p_*.c is in `doom.play.*` (thinkers, map utilities, movement and collision, mobjs, player, weapons, sight, monster AI and attacks, damage and pickups, every sector special). `doom.session` is G_InitNew, G_DoLoadLevel and G_Ticker, and `doom.ticcmd` is G_BuildTiccmd. `-playdemo` and `-timedemo` play v1.9 demos, and `-tichash` writes the sync hash. All three doom1.wad demos play to their end (5026, 3836 and 2134 tics), and the player dies 50–60 tics before each ends, as in the originals: good evidence of sync, but the gate (`scripts/check-demos.sh`) waits on the reference build |
| 6. Playable | done, gate as far as it can run here: `scripts/check-maps.sh` passes on all nine shareware maps, and the three demos still play to their end with demo3's pinned hash unchanged (the comparison with Chocolate Doom waits on the reference build). The status bar (`doom.statusbar`), HUD messages and level title (`doom.hud`), gamestates with G_Ticker's game actions, the intermission (`doom.intermission`, single player), the finale (`doom.finale`, no Doom 2 cast), Chocolate's wipe (`doom.wipe`), the menus (`doom.menu`: main, episode, skill, options, sound volume, help, quit and end-game; load and save say they aren't ported), the attract loop, pause, cheats (`doom.cheats`), the automap (`doom.automap`), `-warp`, `-skill`, `-record`, `-fast`, `-respawn` and `-nomonsters`. Playtest requested below |
| 7. Sound, music, savegames, config | done, gate passing: sound effects (`doom.mixer` over SDL_mixer, with S_StartSound's decisions and M_Random pitches made in the playsim), music (`doom.mus2mid`, matching Chocolate Doom's `mus2mid.c` byte for byte on all 13 shareware songs), the settings file (`doom.config`, EDN with key bindings by name), and savegames (`doom.play.saveg`, a versioned binary format whose readers and writers `defsave` derives from `struct-fields`; the menu's Load and Save, F2/F3/F6/F9, `-loadgame`). Demo3 saved at tic 1000, loaded and played on gives every tic hash of the uninterrupted run, and a loaded save saves the same bytes. A headless run with the dummy (and disk) audio driver plays. Playtest requested below |
| 8. Idiom pass and report | not started |

## Reference frames and tic hashes

`reference/iron-doom.patch` adds `--framedump` to Iron Doom (one fixed tic per
frame through Bevy's `TimeUpdateStrategy::ManualDuration`, so dumps are
deterministic). **Not recorded yet:** auto mode denied building the cloned Iron
Doom from a session. To record them, either approve
`scripts/build-reference.sh` in a session, or add it to the environment's
setup script after `setup-cloud.sh`.

The same build applies `reference/tichash.patch` to Chocolate Doom, which
adds `-tichash FILE`: one line per gametic of `gametic rndindex prndindex
hash nmobjs` and each player's `health/armor/weapon/kills/items/secrets`,
where the hash is FNV-1a over every live mobj's position, angle, momentum,
health, type, state and flags in thinker order. The port writes the same
lines. `scripts/check-demos.sh --record` records the references from it into
`reference/data/tichash/`, and `scripts/check-demos.sh` compares the port.

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
| ISSUE-023 | `d13384a` | `nucleus-patches/0005-*.patch` |
| ISSUE-024 | `e15f668` | `nucleus-patches/0006-*.patch` |
| ISSUE-027 | `40cf7d8` | `nucleus-patches/0007-*.patch` |

Each passed the nucleus gate here (after 0007: 1679 passed, the 4 avr-gcc
failures of the baseline, 6 skipped; `make bootstrap` PASS once converged;
0007 doesn't move the bootstrap).
0003 and 0004 change the compiler's own code generation, so after applying
them `make bootstrap` reports a diff until it is converged (nucleus
`context/build.md`, "After a codegen change"). `make` itself is unaffected.
The converged `boot/*.ll` can't be pushed to `nucleus-boot` from here.
## Playtest request (milestones 6 and 7)

The port is a playable shareware Doom on Chocolate Doom's fixed-point
playsim, with its menus, status bar, automap, intermission, finale, attract
loop, sound, music, settings file and savegames. `-ironrender` keeps phase A
(Iron Doom's float movement and renderer, for the frame comparison).

To build on your machine:

1. Check out this branch, `claude/keen-turing-prxm4z`.
2. In your `nucleus` clone, on `doom-bugfixes`, apply the carried fixes:
   `git am <path>/nuc-iron-doom/nucleus-patches/*.patch` (skip any already
   applied), then `make`. Patches 0003 and 0004 move the bootstrap, so to
   keep `make bootstrap` green run `make update-bootstrap` and `make` again.
3. Here: `NUCLEUS_HOME=<path>/nucleus . scripts/env.sh`, then `nucleus build`
   (it needs the SDL2 and SDL2_mixer development packages).
4. Run `build/nuc-iron-doom` (it searches for `doom1.wad` or `doom.wad` as
   Iron Doom does; `-iwad FILE` names one).

Controls are vanilla's: arrows (or WASD) to move and turn, Shift to run, Alt
or `,`/`.` to strafe, Ctrl to fire, Space (or E) to use, 1–7 for weapons,
Tab for the automap (`-`/`=` zoom, `0` the whole map, `f` follow, `g` grid,
`m`/`c` marks), Pause to pause, `-`/`=` the screen size, F1 help, F2 save,
F3 load, F6 quicksave, F9 quickload, Escape the menu. The keys are rebound
by name in the settings file.

The settings are in `~/.config/nuc-iron-doom/config.edn` (or under
`$XDG_CONFIG_HOME`; `-config FILE` names another), written when the game
quits. Saves go beside it as `doomsav0.nsg` … `doomsav5.nsg`; they're not
vanilla's format, and `-loadgame N` loads one at start.

Please check:

- The title and attract loop (title, demos, credits) until a key brings up
  the menu; New Game → skill → E1M1 with the screen melt.
- Sound: weapons, doors, lifts, monsters' sight, pain and death sounds,
  pickups, all placed left or right and fading with distance; menu clicks;
  the sound volume slider.
- Music: the title tune, each map's, the intermission's, and E1M8's end
  text; the music volume slider and `idmus`; pause stops it.
- Playing through episode 1: doors, lifts, switches, monsters, pickups, the
  status bar (face, ammo, keys, arms), messages, the intermission after each
  exit, and the end text and bunny scroll after E1M8. The end text types
  out at half the speed it did in the milestone 6 build, which ran the
  finale's ticker twice a tic (ISSUE-031); it should now match Chocolate
  Doom.
- Saving and loading: save mid-level from the menu (type a description,
  Enter), play on, load it back from the menu, and check the level, the
  monsters, open doors and moving lifts, your health, weapons and the
  automap are as they were. Quicksave (F6, which asks for a slot the first
  time) and quickload (F9). Saving outside a game says you can't.
- The settings: change the volumes, messages and screen size, quit, start
  again, and check they're kept.
- The automap, with and without `iddt`; cheats (`iddqd`, `idkfa`,
  `idbehold`, `idclev12`, `idspispopd`).
- `build/nuc-iron-doom -playdemo demo1` (and `demo2`, `demo3`): each should
  play exactly as in Chocolate Doom, ending with the player's death.

Known problems: low detail is a menu flag only; mouse and joystick aren't
read; Doom 2's cast call isn't ported, so MAP30's text ends the game; a
screen size change applies at once (vanilla waits for the next frame); the
bunny scroll's pistol sounds aren't played; there's no gamma (F11) or F4/F5
shortcut.

## In flight

- Nothing long-running.

## Next steps

- The gates for milestones 2–5 wait on `scripts/build-reference.sh` (frames
  from Iron Doom and Chocolate Doom, tic hashes from Chocolate Doom).
- Milestone 8: the idiom pass and the final report (line counts, the
  executive summary, the ISSUES ranking).
- Compiler fixes worth trying: ISSUE-030 (the generic memo and mangling
  ignore a nested pointer's kind) and ISSUE-031 (`case` binding its form
  once).
- Gaps: Doom 2's cast call; netgame and deathmatch intermission stats; the
  bunny scroll's drawer-side pistol sounds.
- Known gaps: freed mobjs are reused last-freed first, which only
  approximates the zone allocator for stale `target` pointers; the tichash
  comparison leaves out `rndindex` unless `STRICT=1` (see
  `scripts/check-demos.sh`).
