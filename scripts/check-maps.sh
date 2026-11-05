#!/usr/bin/env bash
# Milestone 6's smoke gate: start each map with -warp, run TICS tics headless
# (no input), and fail on a crash or an error. IWAD defaults to doom1.wad,
# MAPS to "1 1" … "1 9" (episode and map), TICS to 2000.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
IWAD=${IWAD:-/usr/share/games/doom/doom1.wad}
TICS=${TICS:-2000}
OUT="$ROOT/build/maps"
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
mkdir -p "$OUT"

fail=0
run() {
    local tag=$1; shift
    # The framedump's last tic ends the run; -k because SIGTERM only closes the window.
    if timeout -k 5 300 "$ROOT/build/nuc-iron-doom" -iwad "$IWAD" -warp "$@" -skill 4 \
        -tichash "$OUT/$tag.tic" -framedump "$TICS" "$OUT" >/dev/null 2>"$OUT/$tag.err"; then
        echo "PASS $tag: $(tail -1 "$OUT/$tag.tic" | cut -d' ' -f1,5-)"
    else
        fail=1
        echo "FAIL $tag (exit $?): $(head -c 300 "$OUT/$tag.err")"
    fi
}

if [ -n "${MAPS:-}" ]; then
    for m in $MAPS; do run "map-$m" $m; done
else
    for m in 1 2 3 4 5 6 7 8 9; do run "E1M$m" 1 $m; done
fi
exit $fail
