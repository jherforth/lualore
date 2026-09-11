#!/usr/bin/env python3
"""Quick texture-mapped preview renderer for a glTF mesh (static, T-pose).

Renders several orthographic views to one PNG using a painter's algorithm,
sampling the texture atlas exactly like a blocky model viewer would:
alpha=0 texels are skipped (transparent), everything else is drawn.

Usage:
    python tools/preview_gltf.py models/lit_combined.gltf textures/lit.png out.png

Optional: pass face indices of interest last to tint those faces magenta,
e.g. ... out.png 12 13 40
"""

import base64
import json
import os
import struct
import sys

from PIL import Image

COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2),
        5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
TYPE_N = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def load(path):
    doc = json.load(open(path, encoding="utf-8"))
    uri = doc["buffers"][0]["uri"]
    if uri.startswith("data:"):
        blob = base64.b64decode(uri.split(",", 1)[1])
    else:
        blob = open(os.path.join(os.path.dirname(path), uri), "rb").read()
    return doc, blob


def acc(doc, blob, index):
    a = doc["accessors"][index]
    bv = doc["bufferViews"][a["bufferView"]]
    comp, size = COMP[a["componentType"]]
    n = TYPE_N[a["type"]]
    stride = bv.get("byteStride") or size * n
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return [struct.unpack_from("<" + comp * n, blob, off + k * stride)
            for k in range(a["count"])]


def rot_y(p, deg):
    import math
    r = math.radians(deg)
    c, s = math.cos(r), math.sin(r)
    return (c * p[0] + s * p[2], p[1], -s * p[0] + c * p[2])


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        return 1
    model, tex_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    tint = set(int(v) for v in sys.argv[4:])

    doc, blob = load(model)
    img = Image.open(tex_path).convert("RGBA")
    TW, TH = img.size
    px = img.load()

    # gather triangles from all primitives
    tris = []
    for mesh in doc.get("meshes") or []:
        for prim in mesh.get("primitives") or []:
            at = prim["attributes"]
            pos = acc(doc, blob, at["POSITION"])
            uv = acc(doc, blob, at["TEXCOORD_0"])
            idx = [v[0] for v in acc(doc, blob, prim["indices"])]
            for t in range(0, len(idx), 3):
                tris.append((pos[idx[t]], uv[idx[t]],
                             pos[idx[t + 1]], uv[idx[t + 1]],
                             pos[idx[t + 2]], uv[idx[t + 2]], t // 3))

    ys = [p[1] for tri in tris for p in (tri[0], tri[2], tri[4])]
    ymin, ymax = min(ys), max(ys)
    scale = 11  # pixels per unit
    pad = 8
    height_px = int((ymax - ymin) * scale) + 2 * pad

    views = [("front", 0), ("side", 90), ("back", 180), ("side2", 270)]
    # glTF UVs: (0,0) is the TOP-left of the image; row 1 draws the plain
    # game-look, rows 2+ mark pixels that sample fully transparent texels
    # in MAGENTA so invisible faces are easy to spot.
    flips = [(False, "game look", False), (True, "mark transparent", True)]
    vw = int((ymax - ymin) * scale * 1.2) + 2 * pad
    canvas = Image.new("RGBA", (vw * len(views), height_px * len(flips)),
                       (235, 235, 235, 255))
    cpx = canvas.load()

    for fi, (is_mark, _fname, mark) in enumerate(flips):
        nviews = len(views) if mark else 1
        cy0 = fi * height_px
        for vi in range(nviews):
            name, yaw = views[vi]
            cx0 = vi * vw
            # transform & project
            proj = []
            for (p0, u0, p1, u1, p2, u2, fid) in tris:
                q = [rot_y(p, yaw) for p in (p0, p1, p2)]
                xz = [(q[i][0], q[i][1], q[i][2]) for i in range(3)]
                sx = [cx0 + pad + int((x + 4.5) * scale * 1.2)
                      for x, y, z in xz]
                sy = [cy0 + height_px - pad - int((y - ymin) * scale)
                      for x, y, z in xz]
                depth = sum(z for x, y, z in xz) / 3
                proj.append((depth, sx, sy, (u0, u1, u2), fid))
            proj.sort(key=lambda e: e[0])  # far first

            for depth, sx, sy, uvs, fid in proj:
                x0, x1 = min(sx), max(sx)
                y0, y1 = min(sy), max(sy)
                denom = (sy[1] - sy[2]) * (sx[0] - sx[2]) + \
                        (sx[2] - sx[1]) * (sy[0] - sy[2])
                if denom == 0:
                    continue
                for y in range(max(cy0, y0), min(cy0 + height_px, y1 + 1)):
                    for x in range(max(cx0, x0), min(vw + cx0, x1 + 1)):
                        w0 = ((sy[1] - sy[2]) * (x - sx[2]) +
                              (sx[2] - sx[1]) * (y - sy[2])) / denom
                        w1 = ((sy[2] - sy[0]) * (x - sx[2]) +
                              (sx[0] - sx[2]) * (y - sy[2])) / denom
                        w2 = 1 - w0 - w1
                        if w0 < -0.001 or w1 < -0.001 or w2 < -0.001:
                            continue
                        if fid in tint:
                            cpx[x, y] = (255, 0, 255, 255)
                            continue
                        u = w0 * uvs[0][0] + w1 * uvs[1][0] + w2 * uvs[2][0]
                        v = w0 * uvs[0][1] + w1 * uvs[1][1] + w2 * uvs[2][1]
                        tx = min(TW - 1, max(0, int(u * TW)))
                        ty = min(TH - 1, max(0, int(v * TH)))
                        r, g, b, a = px[tx, ty]
                        if a > 0:
                            cpx[x, y] = (r, g, b, 255)
                        elif mark:
                            cpx[x, y] = (255, 0, 255, 255)

    canvas.save(out_path)
    print("wrote %s (%dx%d), %d triangles, row1=game look(front), "
          "row2=transparent-marked front/side/back/side2"
          % (out_path, canvas.size[0], canvas.size[1], len(tris)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
