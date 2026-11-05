#!/usr/bin/env bash
# Records the MUS->MIDI reference: every D_* lump of the IWAD converted by
# Chocolate Doom's own mus2mid.c (reference/mus2mid/harness.c), as one line
# per lump of `NAME length fnv1a64` in reference/data/mus2mid/<iwad>.txt.
# The unit test tests/music.nuc converts the same lumps and compares.
# IWAD defaults to /usr/share/games/doom/doom1.wad.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
IWAD=${IWAD:-/usr/share/games/doom/doom1.wad}
CHOCO="$ROOT/../chocolate-doom/src"
BIN="$ROOT/build/mus2mid-ref"
WORK="$ROOT/build/mus2mid"
OUT="$ROOT/reference/data/mus2mid/$(basename "$IWAD" .wad).txt"

mkdir -p "$ROOT/build" "$WORK" "$(dirname "$OUT")"
gcc -O1 -I "$ROOT/reference/mus2mid" -I "$CHOCO" $(pkg-config --cflags sdl2) \
    "$ROOT/reference/mus2mid/harness.c" "$CHOCO/mus2mid.c" "$CHOCO/memio.c" -o "$BIN"

python3 - "$IWAD" "$WORK" <<'PY'
import struct, sys
wad, work = sys.argv[1], sys.argv[2]
d = open(wad, 'rb').read()
n, off = struct.unpack_from('<ii', d, 4)
for i in range(n):
    pos, size, name = struct.unpack_from('<ii8s', d, off + 16 * i)
    name = name.rstrip(b'\0').decode()
    if name.startswith('D_'):
        open(f'{work}/{name}.mus', 'wb').write(d[pos:pos + size])
PY

: > "$OUT"
for mus in "$WORK"/D_*.mus; do
    name=$(basename "$mus" .mus)
    "$BIN" "$mus" "$WORK/$name.mid"
    python3 - "$name" "$WORK/$name.mid" >> "$OUT" <<'PY'
import sys
data = open(sys.argv[2], 'rb').read()
h = 0xcbf29ce484222325
for b in data:
    h = ((h ^ b) * 0x100000001b3) & 0xffffffffffffffff
print(sys.argv[1], len(data), format(h, '016x'))
PY
done
echo "recorded $(wc -l < "$OUT") lumps in $OUT"
