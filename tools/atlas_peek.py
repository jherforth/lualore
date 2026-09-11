#!/usr/bin/env python3
"""Print an ASCII map of the lit.png alpha coverage and probe cells.

Each character covers one column and an 8-row band: '#' = has opaque
texels, '.' = fully transparent. Use probes to dump exact RGBA near a
suspicious region.

Usage:
    python tools/atlas_peek.py textures/lit.png [x0 y0 x1 y1]...
"""

import sys

from PIL import Image

path = sys.argv[1]
img = Image.open(path).convert("RGBA")
W, H = img.size
px = img.load()
print("%s: %dx%d" % (path, W, H))
print("    " + "".join(str((x // 10) % 10) for x in range(W)))
for yb in range(0, min(H, 520), 8):
    row = ""
    for x in range(W):
        opaque = any(px[x, y][3] > 0 for y in range(yb, min(H, yb + 8)))
        row += "#" if opaque else "."
    print("%3d %s" % (yb, row))

vals = [int(v) for v in sys.argv[2:]]
for i in range(0, len(vals), 4):
    x0, y0, x1, y1 = vals[i:i + 4]
    print("probe x %d..%d y %d..%d" % (x0, x1, y0, y1))
    for y in range(y0, y1 + 1):
        line = ""
        for x in range(x0, x1 + 1):
            a = px[x, y][3]
            line += "#" if a > 0 else "."
        print("  y%3d %s" % (y, line))
