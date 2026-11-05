# Port Iron Doom to Nucleus — a language stress test

## 1. Mission

Port Iron Doom (https://github.com/Henrique194/iron-doom/), a Rust Doom built
on the Chocolate Doom codebase, to the Nucleus programming language
(https://github.com/zakwilson/nucleus/). Then extend the port into a playable
game (§5).

**Producing a port is the secondary goal. The primary goal is to stress-test the
language: find missing or poorly designed features, and record them in `ISSUES.md`.**
A finished port with a thin `ISSUES.md` is a failed run. A partial port with a
precise, well-evidenced `ISSUES.md` is a useful one. When the two goals compete
for your time, the report wins.

Use Nucleus features to make the code shorter, easier to understand, or more
reliable than the Rust, including but not limited to:

* Macros, including `macrolet` and `macmap`
* Generics (multimethods, bounded generic `defn`, parametric structs)
* Protocols (including `(dyn P)` where runtime dispatch is genuinely needed)
* Compile-time evaluation
* Non-nullable refs (`&T`) and narrowed nullables (`?&T`)
* Error handling (`!T`, `deferror`, `try`, `match`)
* `Const` data literals (`[…]`, `{…}`, `#{…}`)
* The Nucleus standard library (collections, `String`/`StrView`, allocators, `fmt`, EDN, file I/O, test framework)

Replicating Iron Doom exactly is not a goal, and neither is improving its
performance or gameplay. The goal is **a playable Doom in idiomatic Nucleus,
plus a report on the language issues that made it hard to write**.

This is not a transliteration exercise. A previous Nucleus Doom port
(`zakwilson/nuc-doom`) was a close, bit-exact transliteration of Chocolate
Doom's C, and its findings are already reported, and most of them fixed.
Starting from Rust changes the question: Iron Doom already uses modern
structure (enums with data, traits, `Result`, iterators, an ECS). This port
asks how Nucleus compares with a modern language on the same program, and
what goes wrong when someone writes Nucleus *the way the language intends*. If
a module ends up reading like Rust with parentheses, that is either a finding
(the idiomatic version was impossible or worse; say why) or a defect in the
port.

## 2. The source

Iron Doom (`../iron-doom`, about 6,600 lines of Rust) is a Cargo workspace.
`src/main.rs` builds a Bevy `App` from one plugin per crate:

| Crate | What it does |
|---|---|
| `cli` | `clap`-derived command line (`--iwad`), `@file`/`--response` response files |
| `wad` | IWAD discovery (XDG and Doom dirs, the Windows registry), header and directory, lumps, `PLAYPAL`, patches, flats, `PNAMES`/`TEXTURE1` wall textures, and the map lumps (things, lines, sides, vertexes, segs, subsectors, nodes, sectors, blockmap) |
| `window` | The SDL2 window, the 320×200 `ScreenBuffer`, palette and gamma table, keyboard input, the window-close exit |
| `game-state` | The Bevy `States`: `Setup`, `Playing` {`Intro`, `Level`, `ScreenMelt`}, `Paused`, `Exiting`, plus state-scoped entities |
| `title-screen` | Draws `TITLEPIC`, then loads E1M1 after a 1.71 s (60-tic) wall-clock timer |
| `screen-melt` | The wipe between screens, driven by the Doom RNG table |
| `level` | Turns map lumps into ECS entities, the player's controls, `f32` movement and friction (no collision), the camera |
| `world-view` | Front-to-back BSP walk, depth clipping, and textured walls and sky. No floors, ceilings or sprites |
| `rand` | The Doom random table behind the `rand` crate's `RngCore` |
| `exit`, `macros/sys-fail` | Error-to-exit plumbing: the `#[sys_fail]` attribute turns a system's `Result` into an orderly exit |
| `common` | `Array2d` |

Iron Doom is GPLv3 and doesn't keep demo sync. Anything it lacks is ported
from Chocolate Doom 3.1.1 (`../chocolate-doom`), the C it was built from.

## 3. Ground rules

1. **Never modify `../iron-doom` or `../chocolate-doom`.** To instrument a
   reference engine, work in a copy (§6).
2. **You may fix bugs in Nucleus** (§7, "Fixing the compiler"). Everything
   else, including missing features and design problems, is recorded and worked
   around, not changed.
3. **Never discard work with git** (`git restore`, `git checkout <file>`,
   `git reset --hard`, `git clean`), in any repo. If the build breaks, fix the
   source.
4. **License.** The port is a derivative of GPLv3 code (Iron Doom), and the
   parts taken from Chocolate Doom are GPLv2-or-later, which combines with
   GPLv3. Ship `COPYING` (a copy of Iron Doom's `LICENSE`). Give each ported
   file a short header naming its sources: Iron Doom (Henrique194), and for
   Chocolate Doom code, the copyright lines from the C file.
5. **Commit and push** at each milestone whose gates are green, with a message
   that names the milestone and the new ISSUE ids. Commit smaller steps in
   between as well: the container is ephemeral, and anything unpushed is lost.
   Work on the branch the session names.
6. **No subagents and no workflows.** Do all the work in the main thread. The
   harness resumes the main thread automatically when it hits a session limit,
   but a subagent that hits the limit is lost.
7. **The port must also build on the user's machine.** Nothing in `build.edn`
   or the scripts may hardcode container paths. Every script gets its compiler
   from `scripts/env.sh`, and finds sibling checkouts relative to the repo.

## 4. Required reading before writing port code

Read these Nucleus docs in full: `index.md`, `types.md`, `toplevel.md`,
`special-forms.md`, `structs-unions.md`, `generics.md`, `macros.md`,
`errors.md`, `collections.md`, `allocators.md`, `strings.md`, `iterators.md`,
`build.md` (Commands, `build.edn`, Choosing C packages), and `testing.md`.
Skim `builtins.md`, `stdlib.md`, `io.md`, `edn.md` and `compiler.md`, and come
back to them as needed. Then read `examples/` for idiom: the examples are the
closest thing to a style guide.

Then read all of Iron Doom. It's small enough to read in one pass, and the
architecture decision in §8 has to be made before the first module is written.

Before you report a limitation, check whether it is already known. Look for
"Sharp edge", "Limits" and "not supported" in `docs/`, in `design/deferred/`
and `design/future/`, and in the old port's `ISSUES.md` (`zakwilson/nuc-doom`).
A known limitation that still hurts the port **is still a finding**: record it
with `Kind: known-limitation` and say what it cost, but never present it as a
newly discovered bug. A finding from the old port that recurs here in a
different shape is worth recording. Cite the old ISSUE id.

## 5. Scope

### Phase A: Iron Doom parity (core)

Everything Iron Doom does, as listed in §2: the command line and response
files, IWAD discovery (Linux and macOS paths only), the WAD reader and every
lump type Iron Doom parses, the SDL2 window with palette, gamma and keyboard
input, the game-state machine, the title screen, the screen melt, level
loading, player controls and movement, the camera, and the wall-and-sky BSP
renderer. Free movement without collision is fine in this phase, as it is in
Iron Doom.

### Phase B: a playable game (after phase A is green)

Extend the port, using Chocolate Doom as the reference, in the same
architecture. Do the items in this order, since each one is useful on its own:

1. Floors and ceilings (visplanes) and the full colormap lighting.
2. Things and sprites, `info` (states, mobjinfo, sprites, sounds), and the
   fixed-point math and trig tables.
3. The playsim: collision and the blockmap, `P_Random`, thinkers, monsters,
   weapons, specials and sector movers, `ticcmd`, and demo playback and
   recording. From here the fidelity contract (§6.1) applies, and Iron Doom's
   `f32` movement gets replaced.
4. The status bar, HUD messages, menus, automap, intermission, finale,
   cheats, the attract loop, and the new-game flow.
5. Optional: sound effects and music (port `mus2mid.c`, play through
   SDL2_mixer, no OPL emulator), savegames and an EDN config. Neither format
   has to be vanilla-compatible.

Game modes beyond shareware should have code paths, but the 1.9 shareware
`doom1.wad` is the test IWAD.

**Out of scope:** Heretic, Hexen and Strife; networking (keep `ticcmd` and a
single-player tic loop); the setup tool and textscreen; DeHackEd/BEX; OPL, PC
speaker and GUS; the joystick; ENDOOM; Windows specifics (Iron Doom's registry
lookup, `winresource`); vanilla limit and overflow emulation, unless a test demo
needs one to stay in sync.

## 6. Verification

There is no display in this environment, so every check must run headless
(`SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy`). The user playtests on their
own machine.

### 6.1 Fidelity contract

- **Phase A** matches Iron Doom's behaviour, not its bits. Floats are allowed,
  as in Iron Doom. The title screen, the melt (driven by the RNG table) and the
  E1M1 start view should match Iron Doom's framebuffer. Explain any difference
  that remains in `PROGRESS.md`.
- **Phase B's playsim must be deterministic and stay in demo sync with Chocolate
  Doom.** That means the same `P_Random`/`M_Random` table and indices, the same
  fixed-point semantics (`FixedMul`/`FixedDiv` with 64-bit intermediates and
  FixedDiv's overflow clamp), the same trig tables, 32-bit wrapping angle
  arithmetic, the same thinker iteration order and the same blockmap traversal
  order. Write all of that in idiomatic Nucleus, but don't change the
  arithmetic. Floats are **forbidden** in `doom.play.*`. If this contract
  fights the phase-A architecture or forces unidiomatic code, record that in
  `ISSUES.md` and keep the contract.
- **Generated tables must equal the originals.** If you compute `finesine`,
  `finetangent`, `tantoangle`, `gammatable` and the like at compile time (which is
  encouraged), add a test proving element-wise equality with `tables.c`. If they
  can't be made equal, embed them and record why.
- **Outside the playsim** (the renderer, menus, HUD, platform layer, sound) you may
  modernize freely, floats included. Frame-exact output is a diagnostic tool, not a
  requirement.

### 6.2 The reference harness

Build the engines from copies in `reference/build/` (gitignored), with patches
kept in `reference/`, through `scripts/build-reference.sh`. Commit the recorded
output in `reference/data/`, since it's small. The port takes single-dash
flags, as Chocolate Doom does (`-iwad`, `-framedump`).

1. **Phase A (milestone 0):** `reference/iron-doom.patch` adds
   `--framedump <tic,tic,…> <dir>` to Iron Doom: at the end of the listed
   `FixedUpdate` tics, write the 320×200 indexed `ScreenBuffer` plus the
   palette as a PPM. Bevy's fixed clock runs on wall time, so make the dump
   key on the tic count, and check that two runs give identical files. The
   port implements the same flag with byte-identical output, and
   `scripts/check-frames.sh` diffs the two.
2. **Phase B (before the playsim):** `reference/tichash.patch` adds
   `-tichash <file>` and `-framedump` to Chocolate Doom (start from the old
   port's patch). After each gametic, `-tichash` writes one line containing the
   gametic number, `rndindex`, `prndindex`, and a hash over every mobj's `x y z
   angle momx momy momz health type state-index flags` (in thinker order), plus
   each player's `health armorpoints readyweapon` and the counts of kills, items
   and secrets. Record `demo1`, `demo2` and `demo3` from the v1.9 `doom1.wad`.
   The old port's recorded data came from a different WAD and doesn't apply.
   Note each demo's gametic count under `-timedemo` in `CLAUDE.md`. That count
   is necessary but **not** sufficient, since a desynced demo still runs to its
   end. `scripts/check-demos.sh` runs the port on all three demos, reports the
   **first** divergent tic and the fields that differ, and exits non-zero on
   any mismatch. It is the main regression gate from the playsim on.

### 6.3 Tests

Use the Nucleus test framework (`nucleus.test`, `docs/testing.md`) for unit
tests: WAD directory and lump parsing, texture composition, the melt's column
offsets, fixed-point math, table equality, the MUS→MIDI converter, config
round-tripping and similar. Keep them in a test program built alongside the
game. Iron Doom has no tests of its own, so these are new.

## 7. Recording findings — `ISSUES.md`

### What counts

Any place where the language, its standard library, its tooling, its diagnostics
or its docs made the port harder, longer, less clear or less safe than it should
be. Concretely:

- compiler bugs: crashes, miscompiles, wrong or misleading diagnostics, rejected
  valid code, accepted invalid code;
- missing features, where you had to fall back to a less idiomatic or more
  verbose form;
- design problems: features that exist but compose badly, surprise you, or push
  you toward C idioms;
- stdlib gaps (anything you had to write that belongs in `nucleus.*`, and
  anything a Rust crate gave Iron Doom for free: `IndexMap`, `clap`,
  `derive_more`);
- C interop friction (SDL2 headers, macros, varargs, unions, callbacks);
- build-tool and workflow friction, slow compiles, and poor error locality in a
  large program;
- docs that are wrong, missing, or contradicted by the compiler.

**Notice friction actively.** After finishing each module, compare it with the
Rust (or, in phase B, the C) and ask: where is the Nucleus version longer,
harder to read, or less safe, and why? Where did you reach for `ptr`, a cast or
a manual loop because the idiomatic tool didn't fit? Which Rust guarantee
(exhaustive `match`, borrow checking, `?`, trait bounds, iterator adaptors)
had no Nucleus counterpart, and what did losing it cost? Each answer is a
candidate finding.

### Format

`ISSUES.md` starts with a summary table ranked by **porter pain removed per unit
of language work**. Below the table, each issue looks like this:

```markdown
## ISSUE-007: <one-line claim, not a topic>

- **Severity:** blocker | major | minor | papercut
- **Kind:** bug | missing-feature | design | diagnostics | stdlib | interop | tooling | docs | known-limitation
- **Status:** open | worked-around | fixed in nucleus `<sha>`
- **Probe:** `probes/issue-007.nuc` — expected …, actual … (exact compiler output)
- **Port sites:** `src/play/map.nuc:212`, … (N sites in total)
- **Workaround:** what the port does instead, and what it costs
- **Suggestion:** what the language could do (optional, brief)
- **Prior art:** old port's ISSUE-NNN (optional)

Context: one or two short paragraphs, with the idiomatic code you wanted to write
next to the code you had to write, and the Rust it came from when that helps.
```

Severity: **blocker** means no workaround was possible, so a feature was dropped
or a module couldn't be written. **Major** means the workaround costs
significant code, safety or clarity, or recurs widely. **Minor** is a local
annoyance. A **papercut** is cosmetic or a diagnostics wording issue.

Rules:
- **Every bug-kind issue needs a minimal standalone probe** in `probes/` that
  compiles (or fails to) with `$NUCLEUS_HOME/build/nucleusc` alone, with a header comment
  giving the issue id and the expected behaviour. `scripts/check-probes.sh`
  reruns every probe and reports which issues still reproduce, so the language
  maintainers can rerun it after fixing the compiler.
- **Tag every workaround site** in the port with `; ISSUE-007` so that it can be
  removed once the issue is fixed.
- **Log a finding when you hit it**, not at the end. A module isn't done until
  its findings are in `ISSUES.md`.
- Merge duplicates, and update a finding's site count and severity as evidence
  accumulates.
- Keep a short **"What worked well"** section at the end, listing features that
  clearly beat the Rust or the C. That is signal too.

### Fixing the compiler

You may fix **bugs**: crashes, miscompiles, rejected valid code, accepted invalid
code, wrong diagnostics, and docs that contradict the compiler. Missing features,
design problems and stdlib gaps are recorded only, because they are the
language designer's decisions. A bug whose fix needs a design decision counts as
a design problem.

- **When to fix.** Fix a bug when it blocks the port, or when its workaround is
  costly or recurs widely. Otherwise record it, work around it, and move on.
  Don't let compiler work crowd out the port. The port is how findings are made.
- **Where.** Work in `../nucleus` on the branch `doom-bugfixes`, which the setup
  script checks out. Never commit to `main` there. Before your first change,
  read that repo's `CLAUDE.md` and `context/conventions.md`, and follow its
  rules (tests, bootstrap, docs, `design/progress.md`, context files, comment
  budget). Its subagent guidance and `context/local.md` don't apply here.
- **How.** The order is probe first, then the fix, then the gates:
  1. Write the probe (§7 rules) and record the issue.
  2. Make the fix in `../nucleus`.
  3. With `scripts/env.sh` sourced, run `make -C ../nucleus`, then
     `make -C ../nucleus -k test bootstrap`. The suite takes several minutes,
     so run it in the background. Compare against the container baseline in
     `CLAUDE.md`, not against zero.
  4. Add a regression test in the Nucleus suite.
  5. Make one commit per fix on `doom-bugfixes`, naming the ISSUE id. Get
     push access with `add_repo` and push it. If the fix changes the
     compiler's own codegen, follow `CLAUDE.md` for refreshing
     `nucleus-boot`.
- **Afterwards.** Set the issue's status to `fixed in nucleus <sha>` (the finding
  stays in `ISSUES.md`), confirm that `check-probes.sh` reports the probe as
  fixed, and remove the port's `; ISSUE-NNN` workarounds.

## 8. Design guidance — translate these

These are suggestions, not mandates. If one turns out worse in Nucleus than in
Rust, that is a finding.

**The architecture decision.** Iron Doom's shape comes from Bevy: plugins
register systems in schedules, systems pull `Res`/`Query` parameters by
type, entities carry components, and state transitions spawn and despawn
state-scoped entities. Nucleus has no Bevy, and porting one isn't the job.
Decide in milestone 0, and write the decision and its reasons at the top of
`PROGRESS.md`:

- **Default:** plain data. A `Game` struct owns the WAD, the level and the
  screen. A `defunion` holds the game state. The 35 Hz loop calls each
  subsystem's tick and draw functions in an explicit order. Level geometry
  sits in arrays with typed indices, not entities.
- **Allowed where it earns its place:** a small macro-built mechanism, such as
  a component store that macros generate per type, or a schedule table. Use
  one only where it removes real repetition. That's the stronger stress test
  of macros and generics, so record what it cost.

Whichever you choose, compare it with Iron Doom's module by module: where the
Rust's structure was better, and why Nucleus couldn't follow it, is the core of
this report.

| Iron Doom (Rust) | Nucleus direction |
|---|---|
| Bevy `App`, `Plugin`, systems with `Res`/`ResMut`/`Query` parameters, `Commands`, `EventReader`/`EventWriter` | Explicit subsystem functions over a `Game` struct, or a macro-built equivalent (above). Events become return values or a queue |
| `States`/`SubStates`, `StateScoped`, `run_if(in_level_state())` | A `defunion` game state with `match`. Per-state data lives inside its variant, so leaving the state drops it |
| `enum` with data (`BspNode::Leaf`, lump kinds), exhaustive `match` | `defunion` + `match`. Record any lost exhaustiveness check |
| Traits and `impl` blocks on components | Multimethods and protocols. Use `(dyn P)` only for genuine runtime dispatch |
| `anyhow::Result`, `?`, `#[sys_fail]` turning errors into an exit | `!T`, `deferror`, `try`, propagated to `main`. Fatal errors happen only at the top |
| `clap` derive, response files | A `Const` table of flags (or a macro that generates the parser), and response files read into the argv list |
| `IndexMap<String, Lump>` (name lookup that keeps WAD order) | A `Vec` of lumps plus a name→index `HashMap` with `StrView` keys. Lump reads return `!T` |
| `derive_more` `Deref`/`Index`/`IntoIterator` newtypes | Parametric structs and generic `aref`/iteration, or a macro |
| `common::Array2d`, the `ScreenBuffer` | A parametric 2D array type over one allocation |
| `Option<&T>`, `Option<Entity>` | `?&T`, narrowed through `match` |
| Iterators and closures (`bsp_tree.iter(pos)`, adaptor chains) | Nucleus iterators and lambdas |
| `glam` `Vec2`/`Rot2`, `f32` movement (phase A) | A small vector type with multimethod operators. In phase B, replaced by a distinct fixed-point type whose operators are multimethods, so a fixed can't be mixed with an int by accident |
| The `rand` crate's `RngCore` over `RAND_TABLE` | The table as `Const` data and an index. Keep `P_Random`/`M_Random` exact |
| The `sdl2` crate (bundled SDL2) | SDL2's C headers through Nucleus C interop. Record the interop friction |
| `cfg_if` and the Windows registry lookup | Out of scope. Linux and macOS search paths only |
| Phase B: `info.c` tables, `enum` lists kept in lockstep | `Const` literals generated from one `macmap` row set |
| Phase B: `tables.c` trig tables | Compile-time evaluation, checked for equality (§6.1) |
| Phase B: `thinker_t` with function pointers and the `-1` removal sentinel | `defunion`+`match`, protocols, or `dyn`. Keep the iteration order and the deferred-removal semantics exact |
| Phase B: menus, cheats, `m_config.c` | `Const` tables of structs holding functions, and EDN config through `nucleus.edn` with key bindings by name |
| Phase B: `p_saveg.c` raw struct images | A versioned savegame format driven by `struct-fields` macros |

Organize the code by subsystem under Nucleus namespaces (for example `doom.wad`,
`doom.math`, `doom.info`, `doom.render.*`, `doom.play.*`, `doom.game`,
`doom.ui.*`, `doom.sound`, `doom.sys`) rather than mirroring the crates one to
one. Use the build tool (`build.edn`), not hand-written compiler command
lines. Use Nucleus naming (kebab-case functions, CamelCase types). Follow the
Nucleus repo's comment style: comments say *why*, in one or two lines.

## 9. Milestones

Do these in order. Each one ends with green gates, any new findings logged, an
update to `PROGRESS.md`, and a pushed commit.

0. **Setup.** Confirm `scripts/setup-cloud.sh` ran (or run it), and record the
   container's Nucleus test baseline in `CLAUDE.md`. Read the required docs
   and all of Iron Doom (§4), and make the architecture decision (§8). Write
   `build.edn`, `COPYING`, the `ISSUES.md` skeleton, `probes/`,
   `scripts/check-probes.sh` and a "hello SDL" window that runs headless. Build
   Iron Doom with the framedump patch, and record its title-screen, melt and
   E1M1 frames (§6.2).
1. **Foundations.** The command line and response files, IWAD discovery, the
   WAD reader and every lump parser Iron Doom has, the RNG table and the game
   state type. *Gate:* unit tests.
2. **Screens.** The SDL presentation layer (palette, gamma, 320×200 scaled with
   4:3 aspect correction), patch drawing, the title screen, the screen melt,
   keyboard input and an orderly exit, plus `-framedump`. *Gate:* the title
   and melt framedumps match Iron Doom's.
3. **Level and walls.** Level loading, player controls, movement and camera,
   and the BSP wall and sky renderer. *Gate:* the E1M1 start-view framedump
   matches Iron Doom's, or any difference is explained. Phase A is then
   complete: post a **playtest request** (see below).
4. **Planes and things** (phase B, items 1–2). *Gate:* the reference
   framedumps from Chocolate Doom at the E1M1 start match, or any difference
   is explained.
5. **Playsim and demos** (phase B, item 3). Build the Chocolate Doom harness
   first. *Gate:* `check-demos.sh` passes for all three demos with no desync.
6. **Playable** (phase B, item 4). *Gate:* demos still in sync, and scripted
   headless runs of `-warp 1 N` through every shareware map (start the map, run
   a fixed number of tics, end) finish with no crash. Then post a playtest
   request.
7. **Sound, music, savegames and config** (phase B, item 5, optional).
   *Gate:* the MUS→MIDI unit tests pass against `mus2mid.c` output; a headless
   run with the dummy audio driver doesn't crash; and saving and loading
   mid-demo continues the tic hashes unchanged. Then post a playtest request.
8. **Idiom pass and final report.** Revisit the modules written early with the
   experience gained since, and tighten them. Finalize the `ISSUES.md` ranking,
   and add a per-subsystem table comparing Rust (and, for phase B, C) line
   counts with Nucleus line counts. Write a short executive summary at the top:
   the five changes that would help most, and why.

**Playtest requests.** The user playtests on their own machine. A request is a
section in `PROGRESS.md` that gives:
- the exact commands to build and run the game there: check out the branch,
  build Nucleus at the pushed `doom-bugfixes` commit (`make`, plus `make
  update-bootstrap` and a second `make` if a fix moved the bootstrap), point
  `NUCLEUS_HOME` at it, and run `nucleus build`;
- what to try;
- known problems.

Mention the request in your reply too. **Don't block on it.** Continue with the
next milestone, and work any feedback that comes back in as soon as it arrives.

## 10. Working practices

- **Progress tracking.** Keep `PROGRESS.md` current: the milestone status, what's
  in progress, the next steps and any open questions. Assume your context will be
  compacted and that another session, in a fresh container, may pick the work
  up from `PROGRESS.md` and `CLAUDE.md` alone.
- **Ephemeral containers.** Work in small increments that build, commit and
  push cleanly, so that a session limit, a compaction or a reclaimed container
  never strands work. Before each long-running step (a compiler test run, a
  reference-engine build, a full demo check), make sure the pushed
  `PROGRESS.md` says what is in flight.
- **Probing.** When the compiler surprises you, stop and write the probe *before*
  working around the problem; this keeps the workaround from hiding it. Use
  `nucleusc --run` or the REPL for quick experiments (see the Nucleus
  `docs/compiler.md` and `context/repl.md`).
- **Self-improving context.** When you learn something non-obvious about the
  environment, the toolchain or a workflow, add it to `CLAUDE.md`. Language
  findings go to `ISSUES.md`, not `CLAUDE.md`.

## 11. Definition of done

- Phase A and every phase-B milestone in scope are complete, with their gates
  green, and the work is committed and pushed.
- `ISSUES.md` is ranked and evidenced: every bug has a probe, every workaround
  is tagged in the code, and the executive summary and line-count table are
  written.
- `scripts/check-probes.sh`, `scripts/check-frames.sh`,
  `scripts/check-demos.sh` and the unit tests all run in a fresh cloud
  session after `scripts/setup-cloud.sh`, following only the instructions in
  `CLAUDE.md`, and on the user's machine with `NUCLEUS_HOME` set.
- Every compiler fix is committed and pushed on `doom-bugfixes` with a passing
  Nucleus test suite and bootstrap, and the `ISSUES.md` entry for each one
  names its commit.
