# nuc-iron-doom

A port of Iron Doom (a Rust Doom built on Chocolate Doom) to the Nucleus
language. Its **primary purpose is to stress-test Nucleus** and record language
problems in `ISSUES.md`; the playable port is secondary. The full brief is in
`PROMPT.md`, and current status is in `PROGRESS.md`.

## Locations

The work runs in an ephemeral cloud container. `scripts/setup-cloud.sh` (run by
the environment's setup script) clones everything beside this repo, so all of
these are siblings of the repo root (`..`). Scripts find them relative to the
repo and never by absolute path.

- `../iron-doom`: the Rust original (`Henrique194/iron-doom`, `main`).
  **Read-only.** It's about 6,600 lines in a Cargo workspace: `src/main.rs`
  builds a Bevy `App` from the plugin in each `crates/*` (`cli`, `wad`,
  `window`, `game-state`, `title-screen`, `screen-melt`, `level`,
  `world-view`, `rand`, `exit`, `common`) plus the `macros/sys-fail` proc
  macro. It covers title screen → melt → E1M1 with textured walls, sky and
  free movement only: no floors or ceilings, no sprites, no collision, no
  playsim. Movement and the renderer use `f32`, and its README says it does
  not keep demo sync. It is **GPLv3**.
- `../chocolate-doom`: Chocolate Doom 3.1.1, the C that Iron Doom was built from.
  **Read-only.** It's the reference for everything Iron Doom doesn't cover
  (`PROMPT.md` §5, phase B). The game is in `src/doom/`, and shared code is
  in `src/*.c`.
- `../nucleus`: the language, on branch `doom-bugfixes`. You may fix compiler
  **bugs** there (`PROMPT.md` §7, "Fixing the compiler"), following that repo's
  own `CLAUDE.md` (skip its subagent and `context/local.md` guidance). Docs are
  in `docs/`, idiom examples in `examples/`, the stdlib in `lib/nucleus/`, and
  design history and known gaps in `design/`.
- `../nucleus-boot`: the bootstrap IR (`boot/*.ll`), which is gitignored in
  `nucleus`. The setup script copies it into `../nucleus/boot/`.
- The previous Nucleus Doom port (a Chocolate Doom transliteration) is **not
  available**; don't look for it. Its findings and the rulings on them are
  recorded in nucleus `design/doom-port-fixes/` and in the nucleus commit log
  (messages cite `nuc-doom ISSUE-NNN`). Check those before calling a finding
  new.
- IWADs: `/usr/share/games/doom/doom1.wad` is shareware **v1.9** (md5
  `f0cefca49926d00903cf57551d901abe`). Its demos use the v1.9 format. Iron Doom's IWAD search already looks in `/usr/share/games/doom`.
  `freedoom1.wad` and `freedoom2.wad` may sit beside it, but they're not in
  the setup's package list.

## Environment

- **Setup.** In the environment settings, the setup script should be just
  `nuc-iron-doom/scripts/setup-cloud.sh`, which runs one directory above the
  repo. It installs LLVM 20, the SDL2 dev packages and the shareware WAD,
  clones the siblings, and builds the compiler with `make` in `../nucleus`.
  If a session starts without `../nucleus/build/nucleusc`, run the script by
  hand.
  - Run by hand on 2026-11-05 it took about 5 minutes. The `make` step is
    allowed from a session when it runs through this script.
  - **`nucleus-boot` `main` is older than `doom-bugfixes`.** Its IR predates
    the `_get` → `field` rename (nucleus `cac7bac`), so its compiler can't
    build `doom-bugfixes` directly. When `make` fails, the script chains
    through `dc5a321` → `cac7bac` → `1b3e18f` (about 70 s each). Pushing a
    fresh `boot/` to a `nucleus-boot` `doom-bugfixes` branch would remove the
    chain. The setup script already prefers that branch, but a session was
    denied `add_repo` push access to `nucleus-boot`.
  - The setup script itself runs with no permission prompt.
- **Toolchain.** The image ships LLVM/clang 18 as the default `llvm-config` and
  `clang`; Nucleus needs 19+. `. scripts/env.sh` puts LLVM 20's `bin/` and
  `$NUCLEUS_HOME/build` first on `PATH` and sets `NUCLEUS_HOME` (default
  `../nucleus`). Source it in every shell that builds. On the host, set
  `NUCLEUS_HOME` first.
- **Compiler changes.** `make` in `../nucleus` is fine here. It's the
  container's own clone, built against the container's LLVM, so there's no
  host binary to protect.
  - Gates: `make -k test bootstrap` (`-k` so a test failure still runs the
    bootstrap). Baseline 2026-11-05 (LLVM 20, nucleus `cb17330`): 1672
    passed, 4 failed, 6 skipped, bootstrap PASS. The four failures are
    `mt1`/`mt2`/`mt5`/`mt6` in `suite-build`, which need `avr-gcc`. Compare
    against the baseline, not against zero. The suite takes about 25 minutes.
  - **A fix that changes the compiler's own codegen moves the bootstrap.** See
    nucleus `context/build.md`, "After a codegen change". Converge with
    `make update-bootstrap`, then commit the new `boot/*.ll` to
    `nucleus-boot` on a branch `doom-bugfixes`. Never commit them to
    `main`. The setup script prefers that branch, so later sessions boot from
    it.
- **Pushing to the Nucleus repos.** The session's GitHub scope starts as this
  repo only. Before pushing a compiler fix, call `add_repo`
  (`zakwilson/nucleus`, and `zakwilson/nucleus-boot` if needed) with
  `access: "push"`. Push only to `doom-bugfixes`.
- **The container is reclaimed when idle.** Uncommitted or unpushed work is
  lost, and so are the compiler build and `reference/build/`. Push after every
  commit. Before any long step, make sure `PROGRESS.md` says what's in flight.
- **Building the reference engines.** Iron Doom builds with `cargo` (Rust 1.97
  is preinstalled; the crate needs edition 2024). Its `sdl2` dependency uses
  the `bundled` feature, which builds SDL2 from source with `cmake`, so the
  first build is slow. Chocolate Doom builds with autotools. Both go into
  `reference/build/` (gitignored) through `scripts/build-reference.sh`, with
  patches kept in `reference/`. **Auto mode denied `cargo build` of Iron Doom
  from a session** (2026-11-05). Recording the reference frames needs the user
  to approve `scripts/build-reference.sh`, or to run it from the environment's
  setup script.
- **No display.** Run everything with
  `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy`. The user playtests on their
  own machine.
- **SDL2 needs an explicit package mapping.** `SDL2/SDL.h` resolves through
  clang's default include path, so the build tool never consults pkg-config,
  and the link fails with undefined `SDL_*` symbols (nuc-doom ISSUE-001). Put
  `:pkg-config {"SDL2/SDL.h" ["sdl2"] "SDL2/SDL_mixer.h" ["SDL2_mixer"]}` in
  `build.edn`.
- **Installed by setup:** SDL2 2.30, SDL2_mixer 2.8, SDL2_net 2.2, LLVM and
  clang 20 (clang is the link driver) and `rsync`. The image already has
  `cmake`, `python3`, `cargo`, `make` and `gcc`.
- **SIGTERM doesn't stop an SDL game.** SDL turns it into a window-close event.
  Use `timeout -k 5 N`, never a bare `timeout`.
- **Audio can be checked headless.** `SDL_AUDIODRIVER=disk
  SDL_DISKAUDIOFILE=<file>` writes the mixer's output as raw S16LE stereo at
  44.1kHz. There's no MIDI soundfont, so music can't play here; check the MIDI
  bytes in a unit test instead.
- **Probes** state their own pass condition on a `; fixed-when:` header line
  (see `scripts/check-probes.sh`).
- **`nucleus build` scans imports first** (`nucleusc --list-imports`). If an
  error names a line that looks fine, compile the entry with `nucleusc -I src`
  to find the right file.
- **Commits** use the container's configured git identity. End each message
  with the session's attribution trailer. Work on the branch the session names,
  and push to that branch with `git push -u origin <branch>`.
- **Keep Bash calls small.** A big compound command (edits plus `rm` of a
  wildcard plus runs) gets denied by the permission policy. Use Edit for
  source changes and run steps separately.

## Commands

```
. scripts/env.sh
nucleus build               # → build/nuc-iron-doom
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy build/nuc-iron-doom -iwad /usr/share/games/doom/doom1.wad
scripts/run-tests.sh        # unit tests (nucleus test: :tests in build.edn)
scripts/check-probes.sh     # which ISSUES.md probes still reproduce
scripts/check-frames.sh     # framedumps against reference/data/frames/
scripts/check-demos.sh      # phase B: tic hashes against reference/data/
make -C ../nucleus -j4 && make -C ../nucleus -k test bootstrap   # after a Nucleus fix (env.sh sourced)
```

Only `env.sh` and `setup-cloud.sh` exist so far. Milestone 0 writes the rest
(`PROMPT.md` §9). Update this list as scripts are added or renamed.

## Layout

- `src/` holds the Nucleus sources, organized by subsystem namespace
  (`doom.wad`, `doom.render.*`, `doom.play.*`, …), not one file per Rust
  crate.
- `probes/` holds minimal standalone repros, one per bug-kind issue
  (`issue-NNN.nuc`).
- `reference/` holds the patches for the reference engines and the recorded
  framedumps and tic hashes. `reference/build/` holds the patched copies
  (gitignored).
- `scripts/` holds the setup, environment, gate and probe scripts.

## Rules

- **No subagents and no workflows.** The harness auto-resumes the main thread
  after a session limit, but not a subagent.
- **Language problems go to `ISSUES.md`** when you hit them, in the format
  `PROMPT.md` §7 defines. Each bug needs a probe, and each workaround site is
  tagged `; ISSUE-NNN`. Before calling something new, check `nucleus/docs`,
  `nucleus/design` (especially `design/doom-port-fixes/`) for whether it's
  already known.
- **Port the design, not Bevy.** Iron Doom's ECS, plugins, schedules and states
  are Rust idioms. Rebuild what they accomplish in idiomatic Nucleus
  (`PROMPT.md` §8). Record a finding wherever Nucleus can't express the
  structure cleanly.
- **Phase B's playsim is fixed-point and must stay in demo sync** with Chocolate
  Doom (`PROMPT.md` §6.1). No floats in `doom.play.*` from then on. Keep the
  RNG, thinker order and blockmap order exact. Iron Doom's float movement gets
  replaced, not extended.
- **Nothing may hardcode container paths.** The port must also build on the
  user's machine.
- **Never discard work with git** in any repo (`restore`, `checkout <file>`,
  `reset --hard`, `clean`). Fix the source instead.
- **License.** The code is GPLv3 (Iron Doom), and Chocolate Doom's GPLv2+ code
  is compatible with it. Keep `COPYING` (Iron Doom's `LICENSE`) and the
  copyright header on each ported file.
- Comments say *why*, in one or two lines. Never restate what the code does.
- When you discover a non-obvious environment or workflow fact, add it here.
  Language findings go to `ISSUES.md`, not here.
