# Nucleus issues found by the Iron Doom port

Format and rules: `PROMPT.md` §7. Probes: `scripts/check-probes.sh`.

## Summary

Ranked by porter pain removed per unit of language work. (Ranking is
provisional until milestone 8.)

| Issue | Claim | Severity | Kind |
|---|---|---|---|
| ISSUE-006 | A struct defined by a macro can't be a field type | major | bug |
| ISSUE-001 | A two-key `invoke` reads but can't be `set!` | minor | missing-feature |
| ISSUE-005 | A finished `Vector` can't be viewed as a `Slice` | minor | missing-feature |
| ISSUE-004 | `dotimes` over a literal binds an `i32` that can't meet a `usize` | minor | design |
| ISSUE-003 | A `:where` after the return type gets an unrelated error | papercut | diagnostics |
| ISSUE-002 | Colon type sugar can't carry an unquote in a template | papercut | design |
| ISSUE-007 | A call named like a field is silently a designated initializer | papercut | diagnostics |

---

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
- **Status:** fixed-in-compiler (nucleus `doom-bugfixes`, gate pending)
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
- **Port sites:** `src/doom/mapdata.nuc` (`read-block-map`)
- **Workaround:** name the function differently from the field.
- **Suggestion:** when a designated `(name v)` fails to type-check and `name`
  is also a function, add a note: "read as a designated initializer for field
  'name'; bind the call first to pass it positionally".

Context: the rule is documented (a field name wins over a function), but naming
a reader after the field it fills is the natural spelling, as in Iron Doom's
`block_map: MapBlockMapParser::parse(...)`. The message pointed at a type
mismatch that the source didn't seem to contain.

## What worked well

- A record macro (`defrecord`) generates a struct, its byte size and its
  reader from one field list, with a `macmap` nested inside the quasiquote and a
  protocol-bounded `read-records` whose type variable appears only in its
  return type. That replaces ten near-identical Rust parser modules.
