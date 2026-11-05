#!/usr/bin/env python3
"""Independent reading of Iron Doom's WAD graphics code, for unit-test expectations.

Usage: wadref.py WAD TEXTURE...   prints width, height and an FNV-1a hash of
each composed texture's row-major pixels.
"""
import struct, sys

def lumps(d):
    n, off = struct.unpack('<ii', d[4:12])
    out = []
    for i in range(n):
        p, s, nm = struct.unpack('<ii8s', d[off+16*i:off+16*i+16])
        out.append((nm.split(b'\0')[0].upper().decode(), d[p:p+s]))
    return out

def find(ls, name):
    for n, b in ls:
        if n == name.upper():
            return b
    return None

def patch(b):
    w, h, lo, to = struct.unpack('<hhhh', b[:8])
    cols = []
    for i in range(w):
        o = struct.unpack('<i', b[8+4*i:12+4*i])[0]
        posts = []
        while b[o] != 255:
            n = b[o+1]
            posts.append((b[o], b[o+3:o+3+n]))
            o += n + 4
        cols.append(posts)
    return w, h, cols

def texture(ls, tname):
    pn = find(ls, 'PNAMES')
    names = [pn[4+8*i:12+8*i].split(b'\0')[0].decode() for i in range((len(pn)-4)//8)]
    t1 = find(ls, 'TEXTURE1')
    n = struct.unpack('<i', t1[:4])[0]
    for i in range(n):
        o = struct.unpack('<i', t1[4+4*i:8+4*i])[0]
        tb = t1[o:]
        nm = tb[:8].split(b'\0')[0].decode().upper()
        if nm != tname.upper():
            continue
        w, h, np_ = struct.unpack('<hh', tb[12:16]) + struct.unpack('<h', tb[20:22])
        descs = [struct.unpack('<hhh', tb[22+10*k:28+10*k]) for k in range(np_)]
        pix = [251] * (w * h)
        cover = [[] for _ in range(w)]
        for d in descs:
            pw = patch(find(ls, names[d[2]]))[0]
            for x in range(max(d[0], 0), min(w, d[0] + pw)):
                cover[x].append(d)
        for x in range(w):
            for d in cover[x]:
                oy = d[1] if len(cover[x]) > 1 else 0
                posts = patch(find(ls, names[d[2]]))[2][x - d[0]]
                for top, data in posts:
                    cnt = len(data); pos = top + oy
                    if pos < 0:
                        cnt = max(0, cnt + pos); pos = 0
                    if pos >= h:
                        break
                    cnt = min(cnt, h - pos)
                    for r in range(cnt):
                        pix[x + (pos + r) * w] = data[r]
        return w, h, pix

def fnv(bs):
    h = 0xcbf29ce484222325
    for c in bs:
        h = ((h ^ c) * 0x100000001b3) & 0xffffffffffffffff
    return h

if __name__ == '__main__':
    ls = lumps(open(sys.argv[1], 'rb').read())
    for t in sys.argv[2:]:
        w, h, pix = texture(ls, t)
        print(t, w, h, hex(fnv(pix)))
