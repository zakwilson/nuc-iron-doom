#!/usr/bin/env bash
# Builds the reference engines into reference/build/ from the sibling clones
# (../iron-doom, ../chocolate-doom), each from a clean export of its checked-out
# commit with this repo's patch applied.
#   reference/iron-doom.patch     -> reference/build/iron-doom/target/release/iron-doom
#   reference/chocolate-doom.patch -> reference/build/chocolate-doom/build/src/chocolate-doom
# Usage: scripts/build-reference.sh [iron-doom] [chocolate-doom]   (default: both)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SIBLINGS=$(cd "$ROOT/.." && pwd)
OUT="$ROOT/reference/build"
mkdir -p "$OUT"

# A fresh copy each time, so a patch never lands twice.
export_clean() {
    local name=$1
    rm -rf "${OUT:?}/$name"
    mkdir -p "$OUT/$name"
    git -C "$SIBLINGS/$name" archive HEAD | tar -x -C "$OUT/$name"
    if [ -f "$ROOT/reference/$name.patch" ]; then
        (cd "$OUT/$name" && patch -p1 --quiet < "$ROOT/reference/$name.patch")
    fi
}

build_iron_doom() {
    export_clean iron-doom
    # sdl2's `bundled` feature builds SDL2 from source with cmake: slow the first time.
    (cd "$OUT/iron-doom" && cargo build --release)
    echo "built $OUT/iron-doom/target/release/iron-doom"
}

build_chocolate_doom() {
    export_clean chocolate-doom
    (cd "$OUT/chocolate-doom" &&
        cmake -S . -B build -DCMAKE_BUILD_TYPE=Release >/dev/null &&
        cmake --build build -j"$(nproc)" --target chocolate-doom)
    echo "built $OUT/chocolate-doom/build/src/chocolate-doom"
}

[ $# -eq 0 ] && set -- iron-doom chocolate-doom
for engine in "$@"; do
    case "$engine" in
        iron-doom)      build_iron_doom ;;
        chocolate-doom) build_chocolate_doom ;;
        *) echo "unknown engine: $engine" >&2; exit 2 ;;
    esac
done
