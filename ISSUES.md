# Nucleus issues found by the Iron Doom port

Format and rules: `PROMPT.md` §7. Probes: `scripts/check-probes.sh`.
This file is also the final report (milestone 8).

## Executive summary

The port is complete as far as `PROMPT.md` goes. Phase A reproduces Iron
Doom (title, melt, E1M1 with walls and sky, float movement). Phase B is a
playable shareware Doom on Chocolate Doom's fixed-point playsim, with its
renderer, status bar, HUD, menus, automap, intermission, finale, attract
loop, sound, music, settings file and savegames. All three `doom1.wad` demos
run to their recorded length with the player's death where the originals
have it. Demo3 saved and loaded mid-way gives every tic hash of the
uninterrupted run. The comparison against Chocolate Doom's own frames and
tic hashes waits on `scripts/build-reference.sh`, which this environment
wouldn't run. It is about 16,300 lines of Nucleus for what is 54,700 lines of
C (2,500 for Iron Doom's 6,600 lines of Rust), plus 950 lines of tests.

The language carried a port of this size. No finding blocked it: each has a
workaround, and seven bugs were fixed in the compiler along the way
(`nucleus-patches/0001`–`0007`). What cost the most was not missing power
but **silent wrong behaviour**: a reference that was a copy (ISSUE-021), a
union copy that lost bytes (ISSUE-016), a `case` that ran its form twice
(ISSUE-031), a generic instance shared across pointer kinds (ISSUE-030), and a
diagnostic that steered every narrowing to the unchecked cast (ISSUE-032).
Each was found late and by accident. The five changes that would help most:

1. **`case` evaluates its form once** (ISSUE-031). A gensym in one stdlib
   macro. The documented `cond` expansion surprises everyone who has used
   `switch`, `match` or Clojure's `case`. It hid a real bug in the port (the
   finale ticked twice a tic) for two milestones.
2. **`as` names `as-checked` when it refuses a narrowing** (ISSUE-032). One
   message. The port wrote 198 unchecked `unsafe/cast` conversions of indices
   and counts because the refusal names only that, and the checked form was
   there all along. Every future program inherits the choice the message
   makes.
3. **Make the pointer kind part of type identity where it changes meaning**
   (ISSUE-021, ISSUE-030, ISSUE-029). A `let` typed `&T` binding a copy, a
   generic stamped for `&Q` reused for `?&Q` (an internal error), and
   overloads that can't tell `?&T` from `&T` are three faces of `type-eq`
   ignoring pointer kinds. Nucleus's pointer kinds are its main safety
   feature over C; where identity drops them, the safety goes quietly.
4. **Finish `Vector`**: a slice view, `pop`, and one protocol for `count`
   (ISSUE-005, ISSUE-014, ISSUE-010). The port's own `view` is called 110
   times; a template can't say `count` once two collections or `nucleus.node`
   are loaded. Small stdlib work with the widest reach after the two above.
5. **Derived ownership for structs** (ISSUE-025, with ISSUE-028 as the
   warning). `World` is freed by a hand-written list of 33 `drop`s that
   nothing checks, and `derive-edn`'s nested keep-absent decode releases a
   field twice. A derived drop for a struct of `Drop` fields, used by derived
   code too, removes both kinds of mistake.

Next after those: ISSUE-011 (a macro-defined struct can't appear in other
signatures), which forced every deriving macro in the port to work from a
hand-written struct instead of generating it.

What beat Rust and C (details at the end): deriving code from `struct-fields`
(savegames, settings, WAD records, the command line), compile-time
generation of tables, and `defunion` + `match` for the thinker kinds.

## Summary

Ranked by porter pain removed per unit of language work: cheap fixes to
problems that recur or fail silently first. The issues already fixed by the
carried patches come last.

| Rank | Issue | Claim | Severity | Kind | Status |
|---:|---|---|---|---|---|
| 1 | ISSUE-031 | `case` evaluates its form once per value it tries | major | design | worked around |
| 2 | ISSUE-032 | `as` refuses a narrowing and points only at `unsafe/cast`, not `as-checked` | major | diagnostics | worked around |
| 3 | ISSUE-005 | A finished `Vector` can't be viewed as a `Slice` | minor | missing-feature | worked around |
| 4 | ISSUE-021 | A `let` typed `&T` silently binds a copy of a `T` value | major | bug | worked around |
| 5 | ISSUE-030 | A generic stamped for `&Q` and then `?&Q` reuses the first instance's inner calls | major | bug | worked around |
| 6 | ISSUE-028 | A keep-absent struct inside a keep-absent struct is released twice | major | bug | worked around |
| 7 | ISSUE-014 | `Vector` has no `pop` | papercut | missing-feature | worked around |
| 8 | ISSUE-017 | `str` and `println` can't format a `ui32`, `i16` or `ui8` | papercut | missing-feature | worked around |
| 9 | ISSUE-010 | A macro template can't call `count` where two collection namespaces (or `nucleus.node`) are loaded | minor | design | worked around |
| 10 | ISSUE-025 | A struct of owning fields gets no drop; freeing one lists every field by hand | minor | missing-feature | worked around |
| 11 | ISSUE-011 | A macro-defined struct can't appear in any other function's signature | major | design | worked around |
| 12 | ISSUE-029 | Overloads can't differ only in a pointer's nullability | minor | design | worked around |
| 13 | ISSUE-022 | `none` passed to a generic method isn't typed from its other arguments | minor | bug | worked around |
| 14 | ISSUE-019 | A struct literal passed to a generic binds `T` to `&S` | minor | bug | worked around |
| 15 | ISSUE-026 | A sum constructor in an `if` arm isn't target-typed at a call argument | minor | design | worked around |
| 16 | ISSUE-004 | `dotimes` over a literal binds an `i32` that can't meet a `usize` | minor | design | worked around |
| 17 | ISSUE-015 | A float constant doesn't adapt to an overload's `f32` parameter | minor | design | worked around |
| 18 | ISSUE-001 | A two-key `invoke` reads but can't be `set!` | minor | missing-feature | worked around |
| 19 | ISSUE-007 | A call named like a field is silently a designated initializer | papercut | diagnostics | worked around |
| 20 | ISSUE-003 | A `:where` after the return type gets an unrelated error | papercut | diagnostics | open |
| 21 | ISSUE-018 | `deftype` refuses the documented fn-pointer spelling | papercut | diagnostics | worked around |
| 22 | ISSUE-020 | `(new T a v)` with `v:T` reads `v` as the first field | papercut | missing-feature | worked around |
| 23 | ISSUE-008 | A `defconst`'s value is not macro-expanded | papercut | design | worked around |
| 24 | ISSUE-012 | `->`, `+` and other symbol punctuation can't be in a function name | papercut | design | worked around |
| 25 | ISSUE-002 | Colon type sugar can't carry an unquote in a template | papercut | design | worked around |
| — | ISSUE-016 | A union copy dropped the bytes in its repr member's padding | major | bug | fixed (patch 0004) |
| — | ISSUE-023 | A program was capped at 128 unions (every `Maybe` counts) and 128 enums | major | bug | fixed (patch 0005) |
| — | ISSUE-006 | A struct defined by a macro couldn't be a field type | major | bug | fixed (patch 0001) |
| — | ISSUE-027 | An untyped `let` binding could consume the want its body tail needs | minor | bug | fixed (patch 0007) |
| — | ISSUE-024 | A `match` over a pointer `Maybe` didn't target-type a bare `none` arm | minor | bug | fixed (patch 0006) |
| — | ISSUE-009 | `(some v)`/`none` weren't target-typed through a `deref` or `aref` place | minor | bug | fixed (patch 0002) |
| — | ISSUE-013 | Float `!=` was ordered, so NaN != NaN was false | minor | bug | fixed (patch 0003) |

## Size against the originals

Lines are physical lines. Code lines leave out blank and comment-only lines,
and code characters leave out whitespace and comments, which is the fairer
measure: rustfmt spreads Rust over many short lines, and a Lisp packs more on
each. Counted by a script over `src/`, Iron Doom's crates and Chocolate
Doom's `src/`.

Phase A, against Iron Doom (Rust):

| Subsystem | Rust lines | Nucleus lines | Code lines, Nucleus/Rust | Code characters, Nucleus/Rust |
|---|---:|---:|---:|---:|
| Command line | 178 | 258 | 199/126 = 1.58 | 2.41 |
| WAD and lumps | 2371 | 736 | 557/1882 = 0.30 | 0.44 |
| Window, input, video | 881 | 411 | 317/750 = 0.42 | 0.51 |
| Screen melt | 269 | 65 | 47/198 = 0.24 | 0.29 |
| Level, player, movement | 1558 | 533 | 396/1337 = 0.30 | 0.48 |
| World view (walls, sky) | 903 | 332 | 266/744 = 0.36 | 0.53 |
| RNG | 84 | 57 | 29/56 = 0.52 | 0.51 |
| App, states, title, exit, common, errors | 386 | 86 | 49/318 = 0.15 | 0.19 |
| **Total** | 6630 | 2478 | 1860/5411 = 0.34 | 0.50 |

Phase B, against Chocolate Doom (C):

| Subsystem | C lines | Nucleus lines | Code lines, Nucleus/C | Code characters, Nucleus/C |
|---|---:|---:|---:|---:|
| Playsim (`p_*.c` but `p_saveg.c`) | 17133 | 5877 | 4776/10493 = 0.46 | 0.95 |
| Renderer (`r_*.c`) | 6779 | 1545 | 1245/3830 = 0.33 | 0.68 |
| Tables (`info.c`, `tables.c`, `sounds.c`, `d_items.c`) | 8900 | 3677 | 3574/8447 = 0.42 | 0.70 |
| Game loop (`g_game.c`, `d_main.c`) | 4494 | 1477 | 1187/2906 = 0.41 | 0.77 |
| Status bar and cheats (`st_*.c`) | 1928 | 454 | 363/1208 = 0.30 | 0.62 |
| HUD (`hu_*.c`) | 1304 | 211 | 164/905 = 0.18 | 0.32 |
| Menus (`m_menu.c`) | 2190 | 629 | 515/1546 = 0.33 | 0.80 |
| Intermission (`wi_stuff.c`) | 1881 | 451 | 371/1233 = 0.30 | 0.68 |
| Finale and wipe (`f_*.c`) | 1120 | 221 | 162/786 = 0.21 | 0.64 |
| Automap (`am_map.c`) | 1423 | 569 | 483/1001 = 0.48 | 0.99 |
| Sound (`s_sound.c`, `i_sdlsound.c`) | 1959 | 280 | 215/1170 = 0.18 | 0.37 |
| MUS to MIDI (`mus2mid.c`) | 765 | 184 | 149/510 = 0.29 | 0.58 |
| Settings (`m_config.c`) | 2854 | 152 | 117/821 = 0.14 | 0.19 |
| Savegames (`p_saveg.c`) | 1953 | 554 | 460/996 = 0.46 | 0.76 |
| **Total** | 54683 | 16281 | 13781/35852 = 0.38 | 0.75 |

Reading them:

- **The C counts include what the port leaves out**: netgames, DeHackEd
  string hooks, Chocolate's compatibility options and its hundreds of
  config variables (most of `m_config.c`), Doom 2's cast call, and the
  sound back ends Chocolate supports besides SDL_mixer. Where the C and the
  port do the same work, the playsim and the automap, the size is about the
  same (0.95 and 0.99 by characters). Nucleus doesn't make Doom's logic
  shorter. The savings are where a macro derives what C writes out: the
  settings (0.19), savegames (0.76, while saving more state than vanilla),
  the HUD and sound.
- **Against Rust** the port is half the size by characters. Iron Doom's
  Bevy plumbing (plugins, system parameters, state scoping) is what
  disappears: "App, states, title, exit" is 0.19. The one subsystem that
  grew is the **command line** (2.4×): `clap`'s derive does in one
  attribute per field what `defoptions` does with a hand-written table and
  per-type `read-option` overloads, and the Nucleus side also parses the
  thirteen flags Iron Doom doesn't have (`-framedump`, `-ironrender` and
  phase B's).
- The tests (946 lines, 31 tests) have no counterpart in Iron Doom.


## ISSUE-001: a two-key `invoke` reads, but the same place can't be `set!`

- **Severity:** minor
- **Kind:** missing-feature
- **Status:** worked-around
- **Probe:** `probes/issue-001.nuc` — expected `(set! (g 1 2) 7)` to call
  `(set g 1 2 7)`; actual `set!: not an assignable place -- write a name,
  (deref p), (aref a i), or a member access (r 'field)`
- **Port sites:** `src/doom/buffer.nuc` (the 2D array type)
- **Workaround:** call `(set g x y v)` directly, so reads and writes of the
  same cell look different.
- **Suggestion:** treat a computed member place with N keys as `(set m k… v)`,
  as the one-key form already is.

Context: Iron Doom's `Array2d` implements `Index<(usize, usize)>` and
`IndexMut<(usize, usize)>`, so `screen[(x, y)] = c` and `let c = screen[(x, y)]`
are the same expression. In Nucleus `(screen x y)` reads through a two-argument
`invoke`, but writing needs `(set screen x y c)`.

## ISSUE-002: colon type sugar can't carry an unquote in a template

- **Severity:** papercut
- **Kind:** design
- **Status:** worked-around
- **Probe:** `probes/issue-002.nuc` — expected `p:&~name` in a quasiquote to
  name the macro's argument type; actual `unknown type: ~name`
- **Port sites:** `src/doom/record.nuc`
- **Workaround:** spell such parameters in list form, `(p (ref ~name))`.

Context: the reader splits `p:&~name` as one atom before quasiquote sees it, so
the house style (colon sugar everywhere) breaks exactly inside the macros that
generate definitions.

## ISSUE-003: a `:where` written after the return type gets an unrelated error

- **Severity:** papercut
- **Kind:** diagnostics
- **Status:** open
- **Probe:** `probes/issue-003.nuc` — expected a message saying `:where` belongs
  in the parameter list; actual `unknown type: T`, or `in generic body: unknown
  function 'P'` when `T` appears only in the return type
- **Port sites:** none (found while prototyping `read-records`)
- **Workaround:** none needed once you know.

Context: `(defn f (x:&T):i32 :where (Show T) …)` reads naturally (it is where
Rust puts `where`), and the compiler takes `:where` as a body form. The second
message names the protocol as if it were a function the body calls.

## ISSUE-004: `dotimes` over a literal binds an `i32` that can't meet a `usize`

- **Severity:** minor
- **Kind:** design
- **Status:** worked-around
- **Probe:** `probes/issue-004.nuc` — expected `(+ base i)` to compile with
  `base:usize` and `i` from `(dotimes (i 8) …)`; actual `_+: mixed
  signed/unsigned operands — use explicit cast`
- **Port sites:** counted in the ISSUE-004 tags
- **Workaround:** annotate the index, `(dotimes (i:usize 8) …)`.

Context: the literal `8` would adapt to `usize` anywhere, but once it seeds the
loop variable it fixes the type at `i32`. Rust infers `usize` from the use.

## ISSUE-005: a finished `Vector` can't be viewed as a `Slice`

- **Severity:** minor
- **Kind:** missing-feature
- **Status:** worked-around
- **Probe:** `probes/issue-005.nuc` — expected some `(as-slice &v)`; actual
  `unknown: as-slice`, and nothing else in `nucleus.vector` or `nucleus.slice`
  converts
- **Port sites:** `src/doom/util.nuc` (`view`)
- **Workaround:** a generic `view` that casts the vector's `data` field.
- **Suggestion:** `(as-slice v)` in `nucleus.slice`, documented as valid until
  the next growth.

Context: the WAD directory, the map arrays and the texture list are built by
appending and then never grow again, and the port needs `&T` into them, as Rust
uses `&v[i]`. `Vector`'s `invoke` returns by value (correctly, since elements
move on growth), and `Slice` is the type that hands out references
(nuc-doom ISSUE-021's ruling), but nothing connects the two. The cast needs
`unsafe/cast` from the vector's type-erased `?&ui8`.

## ISSUE-006: a struct defined by a macro can't be a field type

- **Severity:** major
- **Kind:** bug
- **Status:** fixed-in-compiler (nucleus `06230b5`, carried as
  `nucleus-patches/0001-*.patch` until it can be pushed)
- **Probe:** `probes/issue-006.nuc` — expected `(defstruct Outer (p Inner))` to
  compile after `(defpoint Inner)` expands to a `defstruct`; actual `unknown
  type: Inner — not defined anywhere in this compilation unit`, in the same
  file or from an imported one
- **Port sites:** `src/doom/mapdata.nuc` (`Map` holds a `Vector` of each
  `defrecord` type)
- **Workaround:** none short of not generating structs with macros.

Context: the layout prescan (Stage 15 W9 item 40) resolves every `defstruct`'s
field types before any macro has been expanded, and dies on a name only a
macro defines. A `let` in a body accepted the same type, because bodies are
emitted after the macro has run. This blocks any macro that defines a struct
(`defrecord`, a component-store macro) from being composed with ordinary
structs. Fix: the prescan now defers that struct's layout to emission, as it
already did for an array length that won't fold yet; a misspelt type is still
diagnosed at emission.

## ISSUE-007: a call named like a field is silently a designated initializer

- **Severity:** papercut
- **Kind:** diagnostics
- **Status:** worked-around
- **Probe:** `probes/issue-007.nuc` — expected `(Outer 1 (inner 2))` to fail
  with a message naming the designated reading; actual `struct literal: type
  mismatch for field 'inner'`
- **Port sites:** `src/doom/mapdata.nuc` (`read-block-map`),
  `src/doom/play/world.nuc` (`stop-sound`: a field read `(origin 'x)` on a
  parameter named like the field, which fails as "field 'origin' specified
  twice")
- **Workaround:** name the function or variable differently from the field.
- **Suggestion:** when a designated `(name v)` fails to type-check and `name`
  is also a function, add a note: "read as a designated initializer for field
  'name'; bind the call first to pass it positionally".

Context: the rule is documented (a field name wins over a function), but naming
a reader after the field it fills is the natural spelling, as in Iron Doom's
`block_map: MapBlockMapParser::parse(...)`. The message pointed at a type
mismatch that the source didn't seem to contain.

## ISSUE-008: a `defconst`'s value is not macro-expanded

- **Severity:** papercut
- **Kind:** design
- **Status:** worked-around
- **Probe:** `probes/issue-008.nuc` — expected `(defconst TABLE (squares))` to
  take the `(array i32 …)` literal the macro expands to; actual `defconst:
  'TABLE' needs a run-time initializer`
- **Port sites:** `src/doom/rand.nuc` (`def-lcg-table`)
- **Workaround:** the macro emits the whole `(defconst NAME …)`.
- **Suggestion:** expand a macro call in a `defconst` value position before
  classifying it, as a top-level macro call already is.

Context: the RNG table is the output of a known LCG, so the port computes it in
a macro instead of pasting 256 numbers, and checks it against Iron Doom's
literal in a test. A macro that returns the value is the natural shape (it can
then feed a `defvar` or a local too). Having it return a definition makes the
table's name an argument of the generator, and the definition no longer reads
as a `defconst` at the site.

## ISSUE-009: `(some v)` and `none` aren't target-typed through a `deref` or `aref` place

- **Severity:** minor
- **Kind:** bug
- **Status:** fixed-in-compiler (nucleus `ac05293`, carried as
  `nucleus-patches/0002-*.patch`)
- **Probe:** `probes/issue-009.nuc` — expected `(set! @p (some 4))` with
  `p:&?i32` to store a `some`; actual `some: value must be non-null (ref ...)`,
  and `(set! @p none)` gives `set!: (deref p) place: value type mismatch`
- **Port sites:** `src/doom/cli.nuc` (`read-option`, which fills an option
  through `dst:&?StrView`)
- **Workaround:** before the fix, `((Maybe StrView) some v)` spelled out.

Context: a field place `(set! (s 'f) (some 4))` and a named local both build
the arm against the place's type, so the deref place looked like an oversight,
and it is: the field and binding `set!` paths call `union-target-rewrite` and
arm the want channel, and the `deref` and `aref` paths didn't. Writing through
an out-parameter is how the option parser fills each field, as Rust's
`*dst = Some(v)` does. The fix is one shared helper for the two paths.

## ISSUE-010: a macro template can't call `count` where two collection namespaces are imported

- **Severity:** minor
- **Kind:** design
- **Status:** worked-around
- **Probe:** `probes/issue-010.nuc` — expected `` `(count ~s) `` in a template
  to compile in a file importing `nucleus.vector` and `nucleus.slice`; actual
  `macro 'total' names 'count', whose methods here come from namespaces
  'nucleus.vector', 'nucleus.slice', and a full name reaches one`
- **Second probe:** `probes/issue-010b.nuc` (with a module in
  `probes/issue-010b/`) — the same refusal in a file importing only
  `nucleus.vector`, because another file of the program has
  `(import-ct nucleus.node)`
- **Port sites:** `src/doom/cli.nuc` (`defoptions`),
  `src/doom/play/saveg.nuc` (`put-vec`, `get-vec`, `get-vec-sized`),
  `src/tests/saveg.nuc` (`sizes-match`)
- **Workaround:** write the full name of the one namespace you mean,
  `nucleus.slice/count`, in the template, or `~'count` for the caller's
  own name.
- **Suggestion:** a protocol that every collection's `count` conforms to (a
  `Counted` protocol, or `Coll` covering `Slice`) gives hygiene a single full
  name. At the least, say "write one of these full names in the template:
  nucleus.vector/count, nucleus.slice/count", and list each namespace once.

Context: template hygiene (stage 23, ruling D2) rewrites a free name to one
namespace's full name, and refuses an overload whose methods no single
namespace or protocol covers. `count` is defined separately by `Vector`,
`Slice`, `HashMap`, `Node` and others, so any file that imports two of them
can't use `count` in a template, though the same file calls it freely. In
`src/doom/cli.nuc` the message listed `'nucleus.vector'` thirteen times among
twenty-one entries, and "a full name reaches one" reads as a statement rather
than the fix.

It came back in milestone 7 without a second collection in sight. Any macro
that builds code with `node-push` needs `nucleus.node` at compile time, and
`nucleus.node` defines `count`, `conj`, `iter` and `empty?` for `Node`. So the
savegame's `defsave` (in `doom.play.saveg`) stopped every other file's
templates from saying `count`, including a test file's helper macro that
imports nothing of the kind. The fix there was `~'count`.

## ISSUE-011: a macro-defined struct can't appear in any other function's signature

- **Severity:** major
- **Kind:** design
- **Status:** worked-around
- **Probe:** `probes/issue-011.nuc` — expected `(defn origin ():!Point …)`
  below `(defpoint Point)` to compile; actual `unknown type: Point — not
  defined anywhere in this compilation unit`. Inside a template argument it's
  worse: `(defn command-line-from …):(Fallible CommandLine)` silently became a
  generic over a type variable named `CommandLine`, and the error was `in
  generic body: unknown function 'ok'`.
- **Port sites:** `src/doom/record.nuc` (`derive-record`), `src/doom/cli.nuc`
  (`defoptions`), `src/doom/mapdata.nuc`
- **Workaround:** write the struct by hand and have the macro derive its code
  from `struct-fields`, so the type exists before any prescan runs.
- **Suggestion:** treat a name that a top-level macro call in the unit might
  define as "pending" rather than unknown or a type variable, and settle the
  signature when its `defn` is reached. Separately, an implicit type variable
  that is also spelled like a concrete type (capitalized, multi-letter, not
  declared anywhere) deserves at least a warning.

Context: both signature prescans (types, then `defn` signatures) run before
any macro has expanded, and an unresolvable name in a template-argument
position is, by rule, a fresh type variable. So a struct a macro defines is a
second-class type: usable in bodies and (after ISSUE-006's fix) as a field
type, but in no signature outside the macro's own expansion, in any file,
because the whole-graph prescan reads every file's signatures first. The
port's first designs, `defrecord` generating each map struct and
`defoptions` generating the options struct (the clap-derive analogue), both
hit this, and the workaround changes the design: the struct is now written
twice in spirit, once as a `defstruct` and once as the macro's row list for
`defoptions`. The `derive-record` form is arguably the better idiom (it's how
serde derives), but the language pushed the port there rather than letting it
choose.

## ISSUE-012: `->`, `+` and other symbol punctuation can't be in a function name

- **Severity:** papercut
- **Kind:** design
- **Status:** worked-around
- **Probe:** `probes/issue-012.nuc` — expected `(defn f32->i32 …)` to
  compile; actual `illegal character '>' in generated symbol for 'f32->i32'
  (ir-name '@doom.vec2__f32->i32') — LLVM identifiers allow only
  [A-Za-z0-9$._-]`
- **Port sites:** `src/doom/vec2.nuc` (`f32-to-i32`, `f32-to-usize`),
  `src/doom/fixed.nuc` (`wrap-add`, `wrap-sub`, first written `wrap+`)
- **Workaround:** spell it out: `f32-to-i32`, `wrap-add`.
- **Suggestion:** map `>` and `<` (and the other reader-legal punctuation) to
  mnemonics, as `?` and `!` already are.

Context: the reader accepts `->` in a symbol, and `a->b` is the Lisp name for
a conversion. The compiler maps `?` to `_QMARK` and `!` to `_BANG` in every
emitted name (`docs/generics.md`, "`?`/`!` in names") and stops there, so the
name is accepted by the reader and refused at emission. The diagnostic is
clear and points at the definition, so this costs a rename.

## ISSUE-013: float `!=` was ordered, so NaN != NaN was false

- **Severity:** minor
- **Kind:** bug
- **Status:** fixed-in-compiler (nucleus `36c13e3`, carried as
  `nucleus-patches/0003-*.patch`)
- **Probe:** `probes/issue-013.nuc` — expected `(!= n n)` to be true for a
  NaN `n`, as in C and Rust; actual false
- **Port sites:** `src/doom/vec2.nuc` (`f32-to-i32`, which takes NaN to 0 as
  Rust's `as` does)
- **Workaround:** none needed after the fix; before it, `(not (= n n))`.

Context: every float comparison was emitted as an ordered `fcmp`, including
`!=` as `fcmp one`, which is false when either side is NaN. C's `!=`, Rust's
`!=` and IEEE 754's "not equal" are all unordered (`fcmp une`), and
`docs/types.md` promises float arithmetic bit-exact with C. The port found it
writing Rust's saturating float-to-int cast, where `(!= f f)` is the NaN test.
The fix is the one table entry. The compiler's own source has a float `!=`,
so the fix moves the bootstrap.

## ISSUE-014: `Vector` has no `pop`

- **Severity:** papercut
- **Kind:** missing-feature
- **Status:** worked-around
- **Probe:** `probes/issue-014.nuc` — expected `(pop &v)` to remove and
  return the last element; actual `unknown: pop`
- **Port sites:** `src/doom/util.nuc` (`pop-last`), used by the BSP walk in
  `src/doom/level.nuc`
- **Workaround:** `(let (x (v (- n 1))) (truncate! v (- n 1)) x)`, in a
  helper.
- **Suggestion:** `pop` returning `?T` (and `peek` or `last`), since
  `Vector` is the stdlib's only growable sequence and so its only stack.

Context: Iron Doom walks the BSP tree with an explicit stack
(`Vec::push`/`Vec::pop`), the standard way to avoid recursion. `Vector` has
`conj`, `insert`, `remove-at`, `truncate!` and `clear!`, but nothing that
hands back the element it removes, and `String` has `string-pop-char`.

## ISSUE-015: a float constant doesn't adapt to an overload's `f32` parameter

- **Severity:** minor
- **Kind:** design
- **Status:** worked-around
- **Probe:** `probes/issue-015.nuc` — with `(defn _* (v:V k:f32):V …)` and
  `(defconst K 0.5)`, expected `(* v K)` to dispatch like `(* v 0.5)`;
  actual `_*: mixed float and non-float operands — use explicit cast`
- **Port sites:** `src/doom/player.nuc` (`friction`)
- **Workaround:** bind the constant to a typed local first:
  `(let (k:f32 FRICTION) (* v k))`.
- **Suggestion:** let a name for a literal adapt wherever the literal does,
  dispatch included; and when no user method matches, name the overloads
  that were tried instead of falling through to the built-in's message.

Context: `docs/types.md` says a named constant types like the literal it
names, and in a built-in binop it does: `(* a:f32 K)` is `f32`. The
compiler's `operand-is-int-literal` comment says the dispatch path was left
out on purpose ("Extending them is a separate, deliberate change"), so this
is a known gap rather than a slip, but it is one a port meets as soon as it
overloads an operator for a vector type and names its constants, which Iron
Doom's `constants.rs` does for every movement number. The second half is
the diagnostic: `V` has an `_*`, so "mixed float and non-float operands"
describes the fallback the compiler tried last, not the mismatch.

## ISSUE-016: a union copy dropped the bytes in its repr member's padding

- **Severity:** major
- **Kind:** bug
- **Status:** fixed-in-compiler (nucleus `7bb5257`, carried as
  `nucleus-patches/0004-*.patch`)
- **Probe:** `probes/issue-016.nuc` — expected `(ok (V 1.0 -2.0))` from a
  function returning `(Result V E)`, with `V` two `f32`s and `E` an `i32` and
  an `i64`, to come back with `y` = -2; actual `y` was whatever the
  destination held (1.77e-41 in the port)
- **Port sites:** none left; it struck `src/doom/level.nuc`, whose
  `vertex-at` returns `(Fallible Vec2)`
- **Workaround:** none needed after the fix. Before it, nothing short of
  avoiding a small float struct as an `ok` payload.

Context: LLVM has no union type, so a union's IR type was its largest-aligned
member plus an `i8` tail, as clang does it. But clang copies a union with
`memcpy`, and Nucleus copies values as first-class aggregates (`load`/`store`
of the whole type), which carry the fields and not the padding. `Failure` is
`{i32, String}`, padded at bytes 4 to 8, which is exactly where an `ok`
payload of `Vec2` keeps `y`. So every `(Fallible Vec2)` lost `y` on its way
out of the function, silently: no diagnostic, no crash, and the first frame
of E1M1 drew every wall as a sliver on the horizon. Any payload whose bytes
overlap the padding of the union's widest member is hit, which makes it the
most dangerous finding so far. The fix gives a union an IR type with no
padding: integers as wide as its alignment, enough to cover its size.

## ISSUE-017: `str` and `println` can't format a `ui32`, `i16` or `ui8`

- **Severity:** papercut
- **Kind:** missing-feature
- **Status:** worked-around
- **Probe:** `probes/issue-017.nuc` — expected `(str a " " b " " c)` with
  `a:ui32`, `b:i16`, `c:ui8` to format all three; actual `ambiguous overload
  for 'to-str' under argument widening`
- **Port sites:** debugging output only so far, and every check that prints a
  WAD field (WAD records are `i16`) or a binary angle (`ui32`)
- **Workaround:** `(as i32 x)` or `(as i64 x)` at each argument.
- **Suggestion:** a `to-str` for every integer width, or a widening rule that
  prefers the same signedness and the smallest wider type, so `ui32` picks
  `ui64` and `i16` picks `i32`.

Context: `nucleus.fmt` defines `to-str` for `i32`, `i64`, `usize` and `ui64`.
A `ui32` widens to `i64`, `usize` and `ui64` equally, and an `i16` to `i32`
and `i64`, so the call is ambiguous and the message doesn't say which
candidates tied. Doom's data is mostly `i16` (WAD records), `ui8` (pixels)
and `ui32` (binary angles), so every debug print in the port needs a cast.

## ISSUE-018: `deftype` refuses the documented fn-pointer spelling

- **Severity:** papercut
- **Kind:** diagnostics
- **Status:** worked-around
- **Probe:** `probes/issue-018.nuc` — expected `(deftype Op (fn i32)(i32 i32))`
  to alias the type `f:(fn i32)(i32 i32)` spells; actual `deftype: expects a
  name and one type — (deftype Name Type)`
- **Port sites:** none now. `src/doom/render/bsp.nuc` named its sprite-pass
  callback this way until the BSP walk called the sprite pass directly.
- **Workaround:** the canonical form, `(deftype Op ((fn i32) (i32 i32)))`.
- **Suggestion:** let `deftype` take the two adjacent groups as the colon-paren
  sugar does, or name the canonical form in the error.

Context: `docs/types.md` teaches `(fn ret)(params)` as *the* function-pointer
type and mentions `((fn ret) (params))` only in passing as the desugared
form. The sugar is a reader fuse that exists only after `name:`, so in a
`deftype` it is two forms. The error says "one type" but doesn't say that the
spelling the docs use everywhere isn't one, so the natural conclusion is that
fn types can't be aliased at all, which is what I first wrote down.

## ISSUE-019: a struct literal passed to a generic binds `T` to `&S`

- **Severity:** minor
- **Kind:** bug
- **Status:** worked-around
- **Probe:** `probes/issue-019.nuc` — expected `(vec-of 3 (P 0 0))`, with
  `vec-of (n:i32 v:T):(Vector T)`, to be a `(Vector P)`; actual `let: init
  type mismatch for 'v': value is (Vector &P), slot is (Vector P)`
- **Port sites:** `src/doom/render/state.nuc` (`renderer-new`, the
  `solid-segs` vector)
- **Workaround:** bind the literal to a typed local first
  (`no-range:ClipRange (ClipRange 0 0)`) and pass that.
- **Suggestion:** apply nucleus ISSUE-025's rule (a struct literal in an
  untyped binding is the value `S`) to template argument inference too.

Context: a compound literal `(S …)` is an `&S` to a temporary, and nucleus
ISSUE-025 (`design/doom-port-fixes/struct-literals.md`) made an untyped `let`
of one bind the value. Inference of a template's type variable from an
argument didn't get the same rule. Where I hit it, the vector went straight
into a struct literal, and the error was `struct literal: type mismatch for
field 'solid-segs' (positional initializer)`, which says nothing about the
generic. Bound to an untyped `let`, the result is silently a `(Vector &P)`
whose every element points at the same temporary.

## ISSUE-020: `(new T a v)` with `v:T` reads `v` as the first field

- **Severity:** papercut
- **Kind:** missing-feature
- **Status:** worked-around
- **Probe:** `probes/issue-020.nuc` — expected `(new P heap v)` with `v:P` to
  allocate a copy of `v`; actual `struct literal: type mismatch for field 'x'
  (positional initializer)`
- **Port sites:** `src/doom/play/world.nuc` (`blank-mobj`)
- **Workaround:** `(new T a)`, then `(set! @p v)`.
- **Suggestion:** when `new`'s one value has type `T` and `T` has no `init`
  for it, copy it in. Failing that, name `new` in the error.

Context: the playsim keeps mobjs in a per-level arena so a `&Mobj` survives
spawning more (vanilla's pointers do). A freed mobj is reused and a new one
allocated, and both paths want to start from the same zeroed `Mobj` value.
`new` reads one argument as the struct's first positional field, and the
error describes a struct literal the source never wrote.

## ISSUE-021: a `let` typed `&T` silently binds a copy of a `T` value

- **Severity:** major
- **Kind:** bug
- **Status:** worked-around
- **Probe:** `probes/issue-021.nuc` — expected `(let (p:&P (&v 0)) …)`, with
  `v` a `(Vector P)`, to be refused as `&(v 0)` is; actual it compiles and
  binds the address of a copy, so `(set! (p 'x) 5)` is lost
- **Port sites:** `src/doom/render/sprites.nuc` (`install`)
- **Workaround:** index a `Slice` view instead; its `invoke` returns `&T`.
- **Suggestion:** refuse a value where a `let` slot is typed `&T`, with the
  same note `ref` gives: bind the value first, or take a view.

Context: `Vector`'s `invoke` returns `T` and `Slice`'s returns `&T`, so `(s i)`
reads the same in both but means different things. The docs refuse
`&(v 0)` explicitly because it would point at a copy. A typed `let` performs
the same conversion with no diagnostic, and a call result does too:
`(let (p:&P (get-p)) …)` compiles. I hit it filling in sprite frames.
Every rotation written through `f` was lost, and the only symptom would have
been "No patches found" at startup. I found it only because I went to check
whether `(v i)` returned a reference.

## ISSUE-022: `none` passed to a generic method isn't typed from its other arguments

- **Severity:** minor
- **Kind:** bug
- **Status:** worked-around
- **Probe:** `probes/issue-022.nuc` — expected `(conj &v none)` with `v` a
  `(Vector ?&P)` to append an empty slot; actual `no matching method for
  overloaded 'conj' ... argument 2: ?ptr is not ?&P`
- **Port sites:** `src/doom/play/world.nuc` (`world-new`, the
  active-ceiling and active-plat slots)
- **Workaround:** bind `none` to a typed local (`nc:?&Ceiling none`) and
  pass that.
- **Suggestion:** once `self` fixes `T`, type a bare `none` (and `(some x)`)
  argument from the parameter `?T`, as a non-generic call already does.

Context: the note gives the instantiated signature, `(conj self:&(Vector
?&P) elem:?&P)`. So the compiler has already found `T` from the first
argument, but it still matches `none` as an untyped `?ptr`. A non-generic
function taking `?&P` accepts the same `none`. Related to ISSUE-009, fixed for
`deref` and `aref` places, but this is the argument path. Vanilla's fixed
tables of nullable pointers (activeceilings, activeplats, blocklinks) all
start out filled with null.

## ISSUE-023: a program is capped at 128 unions and 128 enums

- **Severity:** major
- **Kind:** bug
- **Status:** fixed-in-compiler (nucleus `d13384a`, carried as
  `nucleus-patches/0005-*.patch`)
- **Probe:** `probes/issue-023.nuc` — expected 140 `defunion`s and 140
  `defenum`s to compile, with the last enum's members usable as `match`
  patterns; actual `error: too many defunions`, and with the unions removed,
  `'E139-A' is not a defenum member`
- **Port sites:** none left. It stopped the whole game build when the playsim
  modules came in.
- **Workaround:** none possible from the port. The fix raises `MAX-UNIONS` and
  `MAX-ENUMS` to 8192.
- **Suggestion:** (done) treat both as runaway guards on a `Vector`, as
  `MAX-STRUCTS` already is.

Context: every `Maybe`, `Result` and `Fallible` instantiation stamps a union.
A port that returns `(Fallible T)` for many `T` and keeps `?&T` links for
every kind of object reaches 128 without writing many `defunion`s itself.
`MAX-STRUCTS` was raised from 1024 to 16384 for GTK for the same reason
(nucleus `design/progress.md`). The enum cap failed worse: past it, the
`defenum` still compiled, but its members silently dropped out of the table
`match` checks, so the error named the pattern, not the cap.

## ISSUE-024: a `match` over a pointer `Maybe` doesn't target-type its arms

- **Severity:** minor
- **Kind:** bug
- **Status:** fixed-in-compiler (nucleus `e15f668`, carried as
  `nucleus-patches/0006-*.patch`)
- **Probe:** `probes/issue-024.nuc` — expected `(let (sp:?usize (match src
  ((some s) (s 'player)) ((none) none))) …)`, with `src` a `?&M`, to bind
  `sp`; actual `let: init type mismatch for 'sp': value is void, slot is
  ?usize`
- **Port sites:** none left; it struck `src/doom/play/inter.nuc`
  (`kill-mobj`, the source's player).
- **Workaround:** an `if` with `some?` in place of the match, which
  target-types its arms.
- **Suggestion:** (done) the pointer-`Maybe` and ERR_PTR arm emitter now
  re-arms the want for each arm's tail, as the tagged-union one does.

Context: `docs/structs-unions.md` says a typed binding's want "carries into
the value tails of `if`/`cond`/`do`/`let`/`with`/`match`". It did for a
match over a tagged union, which `emit-match-clauses` emits. A match over a
`?&T` or a niche `Result` goes through `emit-niche-match-arm` instead, which
emitted the arm bodies without the tail rewrite, so `none` stayed an untyped
null and the arms joined to `void`. An untyped `let` of the same match (or
of an `if` with a bare `none` arm) is also `void`, but that one is the
documented rule: the join doesn't infer `none`'s type from its sibling.

## ISSUE-025: a struct of owning fields gets no drop, so freeing one lists every field

- **Severity:** minor
- **Kind:** missing-feature
- **Status:** worked-around
- **Probe:** none (not a bug): `Drop` is documented as opt-in per type.
- **Port sites:** `src/doom/play/world.nuc` (`world-free`); called from
  `src/doom/session.nuc` (`load-level`, `session-init-new`)
- **Workaround:** a hand-written `world-free` that drops 33 fields of `World`,
  `Level` and `MapScratch` one by one, then gives the `World`'s bytes back to
  the heap. A field added later and left out of it leaks without a word.
- **Suggestion:** a derived drop for a struct whose fields conform to `Drop`
  (the compiler already synthesizes a field-wise one for `vfn`/`mfn`
  closures), or a `(derive-drop T :except (f …))` macro in the stdlib. Pairing
  `new` with a `delete` that runs it would cover the heap case.

Context: each level's world is about 30 `Vector`s, an `Arena` of mobjs and
thinkers, and the map's own vectors. Rust frees all of it when the `World`
goes out of scope. Here, until `world-free` existed, each level change leaked
the previous level's memory. Writing it exposed the harder part: a struct
copy is shallow, so the session's `players` and `pics` share buffers with
the world's copies. The drop has to know which fields are *not* its own,
and nothing in the types says so. Rust's move semantics would have refused
the aliasing copy in the first place.

## ISSUE-026: a sum constructor in an `if` arm isn't target-typed at a call argument

- **Severity:** minor
- **Kind:** design
- **Status:** worked-around
- **Probe:** `probes/issue-026.nuc` — expected `(show (if c (some (title
  false)) none))`, with `show` taking a `?CStr` and `title` returning a
  `CStr`, to pass a `some`; actual `some: value must be non-null (ref ...)`
- **Port sites:** `src/doom/game.nuc` (`draw-session-level`, the automap's
  level title for `hud-drawer`)
- **Workaround:** bind the `if` in a typed `let` first, whose want reaches
  the arms.
- **Suggestion:** `arg-target-rewrite` already has the parameter's type when
  it rewrites a bare constructor, so it could descend into the tails of
  `if`/`cond`/`do`/`let`/`match` as a binding's want does. The overload is
  already chosen by then, so the doc's reason for not making an argument a
  want position doesn't apply to the arms.

Context: `nucleus/src/union-emit.nuc` says a call argument "is not a want
position (its type may pick the overload), so only the built-in sum
constructors are target-typed there". A bare `(some (title true))` argument
works, and so does the same `if` as a `let` init or a `return` value, so the
`if` form is the only thing that changes the outcome. A `?CStr` is a tagged
`Maybe`, not a nullable pointer, so an untyped `some` of a function's `CStr`
result falls to the pointer `Maybe` and is refused, while a string literal
passes. The message points at `as-ref`, which is the wrong fix here.

## ISSUE-027: an untyped `let` binding can consume the want its body tail needs

- **Severity:** minor
- **Kind:** bug
- **Status:** fixed-in-compiler (nucleus `40cf7d8`, carried as
  `nucleus-patches/0007-*.patch`)
- **Probe:** `probes/issue-027.nuc` (with modules in `probes/issue-027/`) —
  expected `(let (pos:?Point (match s ((some k) (let (bx (box-at k)) (some
  (Point …)))) ((none) none))) …)` to bind `pos`; actual `value is either
  ?&Point or ?Point`, but only while another loaded namespace also defines
  `box-at`
- **Port sites:** none left; it struck `src/doom/mixer.nuc`
  (`mixer-update`, a channel's position from its sector), where the other
  `sector-at` is phase A's in `doom.level`.
- **Workaround:** before the fix, a type on the binding (`sec:&Sector`).
- **Suggestion:** (done) `emit-let` and `emit-with` capture the want on entry
  and re-arm the body tail with it, as their comment already said they did.

Context: the mixer compiled on its own and failed only inside the game,
which made it look like a namespace leak. Dispatch was right; what changed
was that a call to a name with methods in two loaded namespaces goes through
generic resolution, which uses up the want, and an untyped binding's init
sees the `let`'s outer want (documented, for closures). The `let` then read
the want *after* its bindings to re-arm its tail, found nothing, and the
`(some (Point …))` tail became a pointer `Maybe`. A program's meaning
changing with what else is loaded is the costly part: the error points at a
line that is correct.

## ISSUE-028: a keep-absent struct inside a keep-absent struct is released twice

- **Severity:** major
- **Kind:** bug
- **Status:** worked-around
- **Probe:** `probes/issue-028.nuc` — expected reading `#user/Outer {:inner
  #user/Inner {:names ["b"]}}` over a valid `Outer` to succeed; actual a
  segmentation fault in `free`
- **Port sites:** `src/doom/config.nuc` (the `derive-edn` of `Keys` and
  `Config`)
- **Workaround:** the inner struct is strict, with `:edn-default` giving
  each field's default, so its decode builds fresh values and only the outer
  one releases the old.
- **Suggestion:** a keep-absent decode could leave the releases to its
  caller when it's reading a field of another keep-absent decode: pass the
  commit up, or make the protocol say whether a type decodes in place, so
  the outer commit skips fields whose decode already released what it
  replaced. The failure path has the same problem: the outer undo releases
  the nested field's mixture of new and kept values and then restores a
  snapshot whose replaced parts are gone.

Context: the settings file has a `:keys` map nested in the top-level one, and
both should read leniently so an older file still loads. The docs describe
each option for one struct and say "a nested struct field reads by its own
type's rules", which reads as if nesting composes. It doesn't: the inner
commit runs `(edn-release (ref saved 'names))` and then the outer commit runs
`(edn-release (ref saved 'inner))` on a shallow snapshot holding the same
vector. A crash in `free` from a config read is a costly way to find that.

## ISSUE-029: overloads can't differ only in a pointer's nullability

- **Severity:** minor
- **Kind:** design
- **Status:** worked-around
- **Probe:** `probes/issue-029.nuc` — expected `(defn f (x:?&Q) …)` beside
  `(defn f (x:&Q) …)` to be two overloads; actual `duplicate definition of
  'f' — the same parameter types are already defined`
- **Port sites:** `src/doom/play/saveg.nuc` (`save-put`/`save-get` for
  `&?&Mobj` and `&?&Thinker`, `get-mobj-vec`, and the free-thinker check in
  `fill`)
- **Workaround:** one overload, the nullable one, serves both. A writer
  handles `&Mobj` fine that way, but a reader can store none in a non-null
  slot, so the loader reads the non-null vectors through `mobj-of` (which
  refuses -1) or checks them for null afterwards.
- **Suggestion:** let nullability take part in overload identity when the
  two signatures differ only there, as it already does for template instance
  names since nuc-doom ISSUE-013 (`stamp-arg-token`). Failing that, say in
  the error that `?&T` and `&T` are one type to the overload table, which
  `docs/generics.md` states only for conformances.

Context: `defsave` writes a field by calling `save-put` on its address, so
the field's type picks the code, as `docs/macros.md` recommends ("overloading
picks the code for it"). That breaks down exactly where a savegame needs it
most: a `?&Mobj` field may be none, and a `&Mobj` element may not.

## ISSUE-030: a generic stamped for `&Q` and then `?&Q` reuses the first instance's inner calls

- **Severity:** major
- **Kind:** bug
- **Status:** worked-around
- **Probe:** `probes/issue-030.nuc` — expected `view` (a `(Vector T)` →
  `(Slice T)` helper over `slice-of`) called on a `(Vector &Q)` and on a
  `(Vector ?&Q)` to compile; actual `view.pnuc_Vector.qQ: internal: aggregate
  return of a (Slice &Q) where the declared return type is %nuc_Slice.qQ`
- **Port sites:** `src/doom/play/saveg.nuc` (`put-mobj-vec` and
  `get-mobj-vec` for `free-mobjs` and `brain-targets`, which index the
  vector instead of viewing it)
- **Workaround:** don't `view` a `(Vector &Mobj)` in a program that also
  views a `(Vector ?&Mobj)` (the automap does): index it with `(v i)`.
- **Suggestion:** `view`'s two instances get distinct names, since nuc-doom
  ISSUE-013 made template arguments keep their pointer kind. The inner
  `slice-of (p:(ptr T) n)` call doesn't: its argument types `(ptr &Q)` and
  `(ptr ?&Q)` are equal to `generic-find-method-exact` (type-eq ignores the
  pointer kind) and mangle the same through `type-mangle-token`, so the
  second request gets the first instance, which returns `(Slice &Q)`. The
  memo and `mangle-fn-name` need the pointee's kind wherever a pointer is
  nested inside a parameter type, as `stamp-arg-token` already does for
  template arguments.

Context: an internal error in the stdlib's own pattern (a generic over a
generic), triggered by two unrelated files of the port: the automap walks
`sector-things`, a `(Vector ?&Mobj)`, and the savegame writer walks
`free-mobjs`, a `(Vector &Mobj)`. Each compiled alone. The error names
`util.nuc:12`, the generic, not either caller, and only the `note:` line
says which call asked for the instance.

## ISSUE-031: `case` evaluates its form once per value it tries

- **Severity:** major
- **Kind:** design
- **Status:** worked-around
- **Probe:** `probes/issue-031.nuc` — expected `(case (next) 5 50 6 60 0)`
  to call `next` once; actual twice (`calls 2`), once for each value before
  the default
- **Port sites:** `src/doom/session.nuc` (the finale's ticker result) and
  `src/doom/play/saveg.nuc` (`fill`, each body's kind tag)
- **Workaround:** bind the form in a `let` and `case` on the variable.
- **Suggestion:** have `case` bind its form to a gensym once, as C's
  `switch`, Clojure's `case` and Rust's `match` all evaluate their scrutinee
  once. The documented expansion, `(cond (= form v1) r1 (= form v2) r2 …)`,
  is accurate, but nobody reads a `case` as a `cond` that repeats its form.

Context: this was a live bug in the port for two milestones. G_Ticker's
finale branch was `(case (finale-ticker …) 1 … 2 … 0)`, so every finale tic
that returned 0 ran F_Ticker a second time: the text typed out and the art
screen's timer ran at double speed. It surfaced only when the savegame
loader's `(case (get-word l) 0 … 1 …)` read a second word whenever a body
wasn't a thinker, and the file seemed corrupt.

## ISSUE-032: `as` refuses a narrowing and points only at `unsafe/cast`, not `as-checked`

- **Severity:** major
- **Kind:** diagnostics
- **Status:** worked-around (the port now uses `as-checked`)
- **Probe:** `probes/issue-032.nuc` — expected the refusal of `(as usize x)`
  with `x:i32` to mention `as-checked`; actual `as: lossy conversion from i32
  to usize -- use unsafe/cast`
- **Port sites:** none left as workarounds. The idiom pass turned 198
  integer conversions from `unsafe/cast` into `as-checked` (144 to `usize`,
  54 to `i32`) across 39 files; 158 `unsafe/cast`s remain, each a deliberate
  reinterpretation (fixed-point and angle wraparound, sign extension through
  `i16`, pointers, floats)
- **Workaround:** none needed once you know `as-checked` exists; the cost was
  two milestones of unchecked conversions.
- **Suggestion:** name both in the message: "use as-checked to check the
  value fits, or unsafe/cast to reinterpret its bits". `docs/types.md` says
  the same thing in prose ("a narrowing or a reinterpretation is refused
  and routed to `unsafe/cast`"), and `as-checked` appears only in the
  special-forms table.

Context: indexing a `Vector` with an `i32` sector or state number is the
commonest conversion in a Doom port, and every one of them hit this refusal.
The message names one fix, so the port wrote `(unsafe/cast usize secnum)` 156
times, which asserts instead of checks: a negative index from a bad map
would have read out of bounds silently. Switched to `as-checked`, the three
demos and nine maps run unchanged, and the one negative value the checks
found (a texture column below zero, which C's `col & mask` wraps on
purpose) shows that the distinction is real: that site keeps `unsafe/cast`,
now with a comment saying why.

## What worked well

- Computing the 256-byte RNG table from its LCG in a macro body (ordinary
  Nucleus code run at compile time, building the literal with `node-push`)
  took ten lines, and the result matched Iron Doom's pasted table on the first
  run.

- A record macro (`defrecord`) generates a struct, its byte size and its
  reader from one field list, with a `macmap` nested inside the quasiquote and a
  protocol-bounded `read-records` whose type variable appears only in its
  return type. That replaces ten near-identical Rust parser modules.

- **Savegames derived from `struct-fields`.** `defsave` (a 22-line macro)
  gives each of 24 structs a writer and a reader, field by field, with array
  fields as loops and a skip list. Pointers go through two overloads that
  number thinkers and mobjs as they're met. The format saves everything the
  playsim reads, the RNG and free lists included. A game saved and loaded
  mid-demo stays in sync, and a loaded save saves the same bytes. Chocolate
  Doom's `p_saveg.c` writes each field by hand in 1,950 lines and still
  can't keep a demo in sync. Adding a field to a struct needs no change
  here, only a version bump.

- **The settings file through `derive-edn`.** Two structs and one
  `derive-edn` line give a readable EDN file with key bindings by name and
  defaults for missing keys: 152 lines against `m_config.c`'s 2,850 (which
  also handles far more variables). The one problem was ISSUE-028.

- **`defunion` + `match` for thinkers.** Vanilla's `thinker_t` holds a
  function pointer and marks removal with `-1`; here a `Think` union names
  each kind and its data. `match` refused to compile every dispatch that
  missed a kind as specials were added. That is the Rust guarantee
  `PROMPT.md` worried about losing, and it held. `_` covers the matches
  that care about one kind.

- **Errors through the playsim.** `(Fallible T)` and `try` carry vanilla's
  `I_Error` cases (a missing texture, a bad sidedef) up to `main` with a
  message. The blockmap iterators' callbacks return a plain bool as
  vanilla's do, with the error parked in the world and raised once the
  iteration ends.

- **A level's objects in one arena.** Every mobj, thinker and special of a
  level comes from the world's arena, so a level change frees them with one
  `drop` and the free lists keep vanilla's reuse order.

- **SDL2 and SDL_mixer straight from their headers.** `(import-use
  "SDL2/SDL.h")` gave the event union, the key enums and the mixer's
  channel API with no bindings written, once `build.edn` mapped the
  headers to pkg-config.

- **Fixed point without surprises.** `FixedMul` and `FixedDiv` with 64-bit
  intermediates, wrapping angle arithmetic and the overflow clamp were each
  a line or two, and they kept the playsim deterministic: the three demos
  played to their recorded ends.
