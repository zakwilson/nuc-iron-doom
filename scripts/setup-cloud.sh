#!/usr/bin/env bash
# Provisions a fresh cloud container for the port. The environment's setup script
# runs it on every new session: `nuc-iron-doom/scripts/setup-cloud.sh`.
# Everything lands beside this repo (../nucleus, ../iron-doom, ../chocolate-doom),
# so no path is hardcoded. Safe to rerun: each step skips work already done.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BASE=$(dirname "$ROOT")
LLVM=20

# The image ships LLVM 18; Nucleus needs 19+. doom-wad-shareware is the 1.9
# shareware IWAD, at /usr/share/games/doom/doom1.wad.
if ! command -v "llvm-config-$LLVM" >/dev/null || ! pkg-config --exists sdl2; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -q
    apt-get install -y -q "llvm-$LLVM-dev" "clang-$LLVM" \
        libsdl2-dev libsdl2-mixer-dev libsdl2-net-dev doom-wad-shareware rsync
fi

clone() {  # clone URL DIR [BRANCH]: shallow, only if DIR is missing
    [ -d "$2/.git" ] && return 0
    git clone -q --depth 50 ${3:+--branch "$3"} "$1" "$2"
}

clone https://github.com/zakwilson/nucleus.git "$BASE/nucleus" doom-bugfixes
clone https://github.com/Henrique194/iron-doom.git "$BASE/iron-doom"
clone https://github.com/chocolate-doom/chocolate-doom.git "$BASE/chocolate-doom" \
    chocolate-doom-3.1.1

# boot/ is gitignored in nucleus. BOOTSTRAP_REV names an older tag than the one
# doom-bugfixes needs, so take the boot repo's doom-bugfixes branch, else main.
if [ ! -f "$BASE/nucleus/boot/nucleusc.ll" ]; then
    branch=main
    if git ls-remote --exit-code --heads https://github.com/zakwilson/nucleus-boot.git \
        doom-bugfixes >/dev/null 2>&1; then
        branch=doom-bugfixes
    fi
    clone https://github.com/zakwilson/nucleus-boot.git "$BASE/nucleus-boot" "$branch"
    mkdir -p "$BASE/nucleus/boot"
    cp "$BASE/nucleus-boot/boot/"*.ll "$BASE/nucleus/boot/"
fi

# The Makefile finds llvm-config on PATH, and /usr/bin/llvm-config is LLVM 18.
PATH="$(llvm-config-$LLVM --bindir):$PATH" make -s -C "$BASE/nucleus" -j"$(nproc)"
