#!/usr/bin/env bash
# Rebuilds every probes/issue-NNN.nuc with the bare compiler and says, per
# issue, whether it still reproduces. A probe states its own pass condition:
#   ; fixed-when: compiles | runs | compile-fails | output-contains TEXT
# and may add `; flags: ARGS` for nucleusc ($ROOT is the repo root).
# Usage: scripts/check-probes.sh [issue-NNN ...]
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/scripts/env.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [ $# -eq 0 ]; then
    set -- "$ROOT"/probes/issue-*.nuc
else
    set -- "${@/#/$ROOT/probes/}"
    set -- "${@/%.nuc/}"
    set -- "${@/%/.nuc}"
fi

still=0 gone=0
for probe in "$@"; do
    id=$(basename "$probe" .nuc)
    rule=$(sed -n 's/^; fixed-when: *//p' "$probe" | head -1)
    flags=$(sed -n 's/^; flags: *//p' "$probe" | head -1)
    log="$WORK/$id.log"
    # shellcheck disable=SC2086
    (cd "$ROOT" && nucleusc ${flags//\$ROOT/$ROOT} "$probe" -o "$WORK/$id") >"$log" 2>&1
    compiled=$?
    ran=1
    if [ $compiled -eq 0 ]; then
        (cd "$ROOT" && timeout -k 5 20 "$WORK/$id") >>"$log" 2>&1
        ran=$?
    fi
    case "$rule" in
        compiles)          fixed=$(( compiled == 0 )) ;;
        runs)              fixed=$(( compiled == 0 && ran == 0 )) ;;
        compile-fails)     fixed=$(( compiled != 0 )) ;;
        output-contains*)  grep -qF -- "${rule#output-contains }" "$log" && fixed=1 || fixed=0 ;;
        *) echo "$id: missing '; fixed-when:' line"; still=$((still + 1)); continue ;;
    esac
    if [ "$fixed" -eq 1 ]; then
        echo "$id: FIXED"; gone=$((gone + 1))
    else
        echo "$id: reproduces -- $(head -1 "$log")"; still=$((still + 1))
    fi
done
echo "$still reproduce, $gone fixed"
