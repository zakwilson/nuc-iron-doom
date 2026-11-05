#!/usr/bin/env python3
"""ppm2png.py IN.ppm OUT.png [SCALE]: a P6 PPM to PNG, optionally scaled up (stdlib only)."""
import struct, sys, zlib

def read_ppm(path):
    d = open(path, 'rb').read()
    parts = d.split(maxsplit=4)
    w, h = int(parts[1]), int(parts[2])
    return w, h, parts[4][:w * h * 3]

def write_png(path, w, h, rgb, scale=1):
    rows = []
    for y in range(h):
        row = rgb[y * w * 3:(y + 1) * w * 3]
        if scale > 1:
            row = b''.join(row[x * 3:x * 3 + 3] * scale for x in range(w))
        rows.extend([b'\0' + row] * scale)
    def chunk(t, b):
        return struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w * scale, h * scale, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(b''.join(rows))) + chunk(b'IEND', b'')
    open(path, 'wb').write(png)

if __name__ == '__main__':
    w, h, rgb = read_ppm(sys.argv[1])
    write_png(sys.argv[2], w, h, rgb, int(sys.argv[3]) if len(sys.argv) > 3 else 1)
