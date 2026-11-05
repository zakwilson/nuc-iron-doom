#!/usr/bin/env bash
# Phase B's demo-sync gate: plays each IWAD demo in the port with -tichash
# and compares it line by line with Chocolate Doom's (reference/data/tichash/).
#   scripts/check-demos.sh            compare (needs build/nuc-iron-doom)
#   scripts/check-demos.sh --record   rewrite the references with the patched
#                                     Chocolate Doom from scripts/build-reference.sh
# IWAD defaults to /usr/share/games/doom/doom1.wad; DEMOS to "demo1 demo2 demo3".
# Column 2, M_Random's index, is left out unless STRICT=1. The port now draws
# it where Chocolate Doom does (the screen wipe, S_StartSound's pitch for
# sounds in earshot, the status bar's face), but none of that touches the
# playsim, so a mismatch there isn't a desync. Make STRICT the default once a
# reference run agrees.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
IWAD=${IWAD:-/usr/share/games/doom/doom1.wad}
DEMOS=${DEMOS:-demo1 demo2 demo3}
REF="$ROOT/reference/data/tichash"
OUT="$ROOT/build/tichash"
CHOCO="$ROOT/reference/build/chocolate-doom/build/src/chocolate-doom"
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
mkdir -p "$OUT"
tag=$(basename "$IWAD" .wad)

if [ "${1:-}" = --record ]; then
    [ -x "$CHOCO" ] || { echo "no $CHOCO: run scripts/build-reference.sh chocolate-doom" >&2; exit 2; }
    mkdir -p "$REF"
    for d in $DEMOS; do
        # SIGTERM only closes the window, so -k.
        timeout -k 5 600 "$CHOCO" -iwad "$IWAD" -nosound -nogui -timedemo "$d" \
            -tichash "$REF/$tag-$d.tic" >/dev/null 2>&1
        echo "recorded $tag-$d: $(wc -l < "$REF/$tag-$d.tic") tics"
    done
    exit 0
fi

fail=0
skipped=0
for d in $DEMOS; do
    ref="$REF/$tag-$d.tic"
    got="$OUT/$tag-$d.tic"
    if [ ! -f "$ref" ]; then
        echo "SKIP $tag-$d: no reference (scripts/check-demos.sh --record)"
        skipped=1
        continue
    fi
    timeout -k 5 600 "$ROOT/build/nuc-iron-doom" -iwad "$IWAD" -timedemo "$d" -tichash "$got" >/dev/null
    if [ "${STRICT:-0}" = 1 ]; then
        cp "$ref" "$OUT/$tag-$d.ref"; cp "$got" "$OUT/$tag-$d.got"
    else
        cut -d' ' -f1,3- "$ref" > "$OUT/$tag-$d.ref"
        cut -d' ' -f1,3- "$got" > "$OUT/$tag-$d.got"
    fi
    if cmp -s "$OUT/$tag-$d.ref" "$OUT/$tag-$d.got"; then
        echo "PASS $tag-$d ($(wc -l < "$ref") tics)"
    else
        fail=1
        # The first tic out of sync, with Chocolate Doom's line first.
        first=$(diff "$OUT/$tag-$d.ref" "$OUT/$tag-$d.got" | grep -m1 -E '^[0-9]+' | sed 's/[acd,].*//')
        echo "FAIL $tag-$d: first difference at line $first"
        sed -n "${first}p" "$ref" | sed 's/^/  chocolate: /'
        sed -n "${first}p" "$got" | sed 's/^/  port:      /'
    fi
done
# 2 when a demo had nothing to compare against: not a pass.
[ $fail = 0 ] && [ $skipped = 1 ] && exit 2
exit $fail
