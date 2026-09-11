#!/usr/bin/env python3
"""Audit a (Blockbench-style) glTF mesh for skin defects.

Checks performed on every mesh primitive:

  * triangle / vertex / quad counts per primitive + material name
  * non-manifold and boundary edges; boundary edges are grouped into
    connected loops and printed with their coordinates -> these are holes
    in the mesh (a face is missing)
  * degenerate faces (zero area)
  * UV rectangles: flagged when degenerate (zero width/height), and when
    out of the [0,1] texture range
  * texture sampling: every face's UV rectangle is tested against the
    PNG (alpha channel). Faces that only sample fully transparent texels
    are listed - these are invisible in game no matter the background
    color, because PNG alpha overrides RGB.
  * geometry comparison between two files (source vs combined) when both
    are given: vertex/index/UV data must be byte-identical.

Usage:
    python tools/lit_skin_audit.py models/lit_combined.gltf [models/lit.gltf] [-t textures/lit.png]
"""

import base64
import json
import os
import struct
import sys

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
    out = []
    for k in range(a["count"]):
        out.append(struct.unpack_from("<" + comp * n, blob, off + k * stride))
    return out


def cross(o, a, b):
    ux, uy, uz = a[0] - o[0], a[1] - o[1], a[2] - o[2]
    vx, vy, vz = b[0] - o[0], b[1] - o[1], b[2] - o[2]
    return (uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx)


def dot3(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def sub3(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def sample_texels(img, us, vs):
    """Return list of RGBA pixels sampled like the rasterizer (int trunc)."""
    W, H = img.size
    out = []
    for u, v in zip(us, vs):
        x = min(W - 1, max(0, int(u * W)))
        y = min(H - 1, max(0, int(v * H)))
        out.append(img.getpixel((x, y)))
    return out


def audit(path, tex_path, compare_path=None):
    print("=== %s ===" % path)
    doc, blob = load(path)
    meshes = doc.get("meshes") or []
    mats = doc.get("materials") or []

    img = None
    if tex_path and os.path.exists(tex_path):
        try:
            from PIL import Image
            img = Image.open(tex_path).convert("RGBA")
            pixels = list(img.getdata())
            trans = sum(1 for p in pixels if p[3] == 0)
            semi = sum(1 for p in pixels if 0 < p[3] < 255)
            print("texture %s: %dx%d, fully transparent texels: %d, "
                  "semi-transparent: %d" % (tex_path, img.size[0],
                  img.size[1], trans, semi))
        except Exception as exc:  # noqa: BLE001
            print("texture check skipped: %r" % exc)

    geo_sig = {}
    for mi, mesh in enumerate(meshes):
        for pi, prim in enumerate(mesh.get("primitives") or []):
            at = prim["attributes"]
            pos = acc(doc, blob, at["POSITION"])
            uv = acc(doc, blob, at["TEXCOORD_0"]) if "TEXCOORD_0" in at else None
            idx = [v[0] for v in acc(doc, blob, prim["indices"])]
            mat = mats[prim.get("material", 0)].get("name", "?") if mats else "?"
            print("-- mesh %d prim %d (material %s): %d vertices, %d triangles"
                  % (mi, pi, mat, len(pos), len(idx) // 3))

            geo_sig.setdefault("pos", []).append(pos)
            geo_sig.setdefault("uv", []).append(uv)

            # Blockbench-style meshes split vertices per face, so weld by
            # position first or every quad looks like a hole.
            weld_map = {}
            remap = []
            wpos = []
            for p in pos:
                k = (round(p[0], 3), round(p[1], 3), round(p[2], 3))
                if k not in weld_map:
                    weld_map[k] = len(wpos)
                    wpos.append(k)
                remap.append(weld_map[k])

            edges = {}
            face_key = {}
            tris = []
            coincident = 0
            for t in range(0, len(idx), 3):
                i0, i1, i2 = idx[t], idx[t + 1], idx[t + 2]
                tris.append((i0, i1, i2))
                w0, w1, w2 = remap[i0], remap[i1], remap[i2]
                # an exact (position-set) duplicate face is a double quad
                fk = tuple(sorted((w0, w1, w2)))
                if fk in face_key:
                    coincident += 1
                else:
                    face_key[fk] = (i0, i1, i2)
                for a, b in ((w0, w1), (w1, w2), (w2, w0)):
                    key = (min(a, b), max(a, b))
                    edges[key] = edges.get(key, 0) + 1

            boundary = [e for e, n in edges.items() if n == 1]
            nonman = [e for e, n in edges.items() if n > 2]
            print("   coincident (stacked) faces: %d" % coincident)
            print("   boundary edges (hole outlines): %d, non-manifold: %d"
                  % (len(boundary), len(nonman)))

            # group boundary edges into loops
            adj = {}
            for a, b in boundary:
                adj.setdefault(a, []).append(b)
                adj.setdefault(b, []).append(a)
            seen = set()
            loops = []
            for start in adj:
                if start in seen:
                    continue
                stack, loop = [start], []
                while stack:
                    v = stack.pop()
                    if v in seen:
                        continue
                    seen.add(v)
                    loop.append(v)
                    stack.extend(adj.get(v, []))
                loops.append(loop)
            loops.sort(key=len, reverse=True)
            for loop in loops[:8]:
                pts = [wpos[v] for v in loop]
                xs = [p[0] for p in pts]
                ys = [p[1] for p in pts]
                zs = [p[2] for p in pts]
                # classify the loop's plane
                axis = "xyz"[0 if max(xs) - min(xs) < 0.01 else
                             1 if max(ys) - min(ys) < 0.01 else 2]
                print("   HOLE loop of %d verts on plane %s=%.2f, span x %.2f..%.2f "
                      "y %.2f..%.2f z %.2f..%.2f"
                      % (len(loop), axis, pts[0]["xyz".index(axis)],
                         min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))

            # face checks
            degen = 0
            uv_bad = 0
            invisible = []
            for (i0, i1, i2) in tris:
                area_n = cross(pos[i0], pos[i1], pos[i2])
                if dot3(area_n, area_n) < 1e-12:
                    degen += 1
                    continue
                if uv is None:
                    continue
                quad_uv = [uv[i0], uv[i1], uv[i2]]
                us = [q[0] for q in quad_uv]
                vs = [q[1] for q in quad_uv]
                dur = max(us) - min(us)
                dvr = max(vs) - min(vs)
                if dur < 1e-6 and dvr < 1e-6:
                    uv_bad += 1
                    continue
                out_of_range = any(u < -0.001 or u > 1.001 or
                                   v < -0.001 or v > 1.001
                                   for u, v in quad_uv)
                if out_of_range:
                    uv_bad += 1
                    print("   UV out of range on face at %s uv %s"
                          % (pos[i0], quad_uv))
                if img is not None:
                    # sample a 5x5 grid at pixel centers inside the uv rect,
                    # using truncation exactly like a rasterizer would
                    cu_min, cu_max = min(us), max(us)
                    cv_min, cv_max = min(vs), max(vs)
                    su, sv = [], []
                    for gi in range(5):
                        for gj in range(5):
                            su.append(cu_min + (cu_max - cu_min) * (gi + 0.5) / 5)
                            sv.append(cv_min + (cv_max - cv_min) * (gj + 0.5) / 5)
                    samples = sample_texels(img, su, sv)
                    trans_n = sum(1 for p in samples if p[3] == 0)
                    if trans_n:
                        mid = pos[i0]
                        normal = area_n
                        nl = dot3(normal, normal) ** 0.5
                        parts = ["face at (%.2f, %.2f, %.2f)"
                                 % (mid[0], mid[1], mid[2]),
                                 "n=(%.1f, %.1f, %.1f)"
                                 % (normal[0] / nl, normal[1] / nl,
                                    normal[2] / nl),
                                 "uv rect u %.4f..%.4f v %.4f..%.4f"
                                 % (cu_min, cu_max, cv_min, cv_max),
                                 "transparent samples %d/25" % trans_n]
                        invisible.append((trans_n, " ".join(parts)))
            print("   degenerate faces: %d, degenerate/out-of-range UVs: %d"
                  % (degen, uv_bad))
            if invisible:
                invisible.sort(reverse=True)
                print("   faces sampling transparent texels: %d" % len(invisible))
                for trans_n, line in invisible[:16]:
                    print("      " + line)

    if compare_path:
        doc2, blob2 = load(compare_path)
        print("=== compare with %s ===" % compare_path)
        sig2 = {}
        for mesh in doc2.get("meshes") or []:
            for prim in mesh.get("primitives") or []:
                at = prim["attributes"]
                sig2.setdefault("pos", []).append(acc(doc2, blob2, at["POSITION"]))
                sig2.setdefault("uv", []).append(acc(doc2, blob2, at["TEXCOORD_0"]))
        same = geo_sig.get("pos") == sig2.get("pos") and \
            geo_sig.get("uv") == sig2.get("uv")
        print("geometry identical: %s" % same)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    tex = "textures/lit.png"
    if "-t" in sys.argv:
        tex = sys.argv[sys.argv.index("-t") + 1]
        args = [a for a in args if a != tex]
    if not args:
        print(__doc__)
        return 1
    audit(args[0], tex, args[1] if len(args) > 1 else None)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
