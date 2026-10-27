#!/usr/bin/env python3
"""Build a 35-track Disk BASIC (DECB) .DSK image.

usage: mkdsk.py out.dsk NAME.EXT:type:ascii:path ...
  type  0 = BASIC program, 2 = machine language
  ascii A = ASCII file, B = binary
"""
import sys

TRACKS, SECTORS, SECSIZE = 35, 18, 256
DIRTRACK = 17
img = bytearray(b"\xff" * TRACKS * SECTORS * SECSIZE)

def sector(track, sec):          # sec is 1-based
    off = (track * SECTORS + sec - 1) * SECSIZE
    return off

def granule_start(g):            # 68 granules, 2 per track, skip track 17
    track = g // 2
    if track >= DIRTRACK:
        track += 1
    return track, 1 + 9 * (g % 2)

fat = bytearray(b"\xff" * 68)
dirents = []
nextg = 34                       # start next to the directory, like DECB

for spec in sys.argv[2:]:
    name, ftype, mode, path = spec.split(":", 3)
    base, ext = name.split(".")
    data = open(path, "rb").read()
    if mode == "A":
        data = data.replace(b"\r\n", b"\r").replace(b"\n", b"\r")
    nsec = max(1, -(-len(data) // SECSIZE))
    last = len(data) - (nsec - 1) * SECSIZE
    grans = []
    remaining = nsec
    while remaining > 0:
        while fat[nextg] != 0xFF:
            nextg = (nextg + 1) % 68
        grans.append(nextg)
        fat[nextg] = 0               # mark used for now
        remaining -= 9
    for i, g in enumerate(grans):
        chunk = data[i * 9 * SECSIZE:(i + 1) * 9 * SECSIZE]
        t, s = granule_start(g)
        for j in range(0, len(chunk), SECSIZE):
            piece = chunk[j:j + SECSIZE].ljust(SECSIZE, b"\x00")
            off = sector(t, s + j // SECSIZE)
            img[off:off + SECSIZE] = piece
        if i + 1 < len(grans):
            fat[g] = grans[i + 1]
        else:
            used = -(-len(chunk) // SECSIZE)
            fat[g] = 0xC0 + used
    ent = bytearray(32)
    ent[0:8] = base.upper().ljust(8).encode()
    ent[8:11] = ext.upper().ljust(3).encode()
    ent[11] = int(ftype)
    ent[12] = 0xFF if mode == "A" else 0x00
    ent[13] = grans[0]
    ent[14:16] = last.to_bytes(2, "big")
    dirents.append(ent)

# directory track: sector 2 = FAT, sectors 3-11 = directory
off = sector(DIRTRACK, 2)
img[off:off + SECSIZE] = bytes(fat).ljust(SECSIZE, b"\x00")
d = b"".join(dirents)
for k in range(9):
    off = sector(DIRTRACK, 3 + k)
    chunk = d[k * SECSIZE:(k + 1) * SECSIZE].ljust(SECSIZE, b"\xff")
    img[off:off + SECSIZE] = chunk
open(sys.argv[1], "wb").write(img)
print(sys.argv[1], len(img), "bytes,", len(dirents), "files")
