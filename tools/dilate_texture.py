#!/usr/bin/env python3
"""Grow painted (opaque) texels into adjacent transparent texels.

The Lit's atlas has 1-pixel transparent seams at the edges of painted
patches; faces whose uv rectangles overlap those texels render with
invisible pixels (a "gap"), regardless of any RGB drawn behind them,
because alpha=0 texels are skipped entirely by the renderer.

Dilating the paint by a few passes fills those texels with the average
colour of their painted neighbours, healing every seam. Painted pixels
are never modified.

Usage:
    python tools/dilate_texture.py in.png out.png [passes] [--inplace]
"""

import sys

from PIL import Image

NEIGHBOURS = ((1, 0), (-1, 0), (0, 1), (0, -1),
              (1, 1), (-1, -1), (1, -1), (-1, 1))


def dilate(path_in, path_out, passes):
    img = Image.open(path_in).convert("RGBA")
    W, H = img.size
    filled_total = 0
    for _ in range(passes):
        px = img.load()
        adds = []
        for y in range(H):
            for x in range(W):
                if px[x, y][3] != 0:
                    continue
                r = g = b = n = 0
                for dx, dy in NEIGHBOURS:
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < W and 0 <= yy < H:
                        pr, pg, pb, pa = px[xx, yy]
                        if pa > 0:
                            r += pr
                            g += pg
                            b += pb
                            n += 1
                if n:
                    adds.append((x, y, r // n, g // n, b // n))
        for x, y, r, g, b in adds:
            img.putpixel((x, y), (r, g, b, 255))
        filled_total += len(adds)
    img.save(path_out)
    print("%s -> %s: %d passes, %d texels filled (%dx%d)"
          % (path_in, path_out, passes, filled_total, W, H))


def main():
    args = [a for a in sys.argv[1:] if a != "--inplace"]
    if len(args) < 2:
        print(__doc__)
        return 1
    path_in, path_out = args[0], args[1]
    passes = int(args[2]) if len(args) > 2 else 2
    if "--inplace" in sys.argv:
        path_out = path_in
    dilate(path_in, path_out, passes)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
