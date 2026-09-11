#!/usr/bin/env python3
"""Print the vertex bounding box of a .b3d or .gltf model.

Usage:
    python tools/model_extents.py models/Toad.b3d models/lit_combined.gltf

For .gltf files the POSITION accessor min/max values are used; for .b3d
files the VRTS chunk is scanned directly. Values are in raw model units.
"""

import json
import struct
import sys


def b3d_extents(path):
    data = open(path, "rb").read()
    if data[:4] != b"BB3D":
        raise SystemExit("not a b3d file: " + path)

    found = []
    seen_tags = []

    def walk(pos, end):
        while pos + 8 <= end:
            tag = data[pos:pos + 4]
            length = struct.unpack_from("<I", data, pos + 4)[0]
            payload = pos + 8
            chunk_end = payload + length
            seen_tags.append(tag.decode("latin1"))
            if tag == b"VRTS":
                flags, tc_sets, tc_size = struct.unpack_from("<III", data, payload)
                stride = 12
                if flags & 1:
                    stride += 12
                if flags & 2:
                    stride += 4
                if flags & 4:
                    stride += 4 * tc_sets * tc_size
                count = (length - 12) // stride
                xs, ys, zs = [], [], []
                off = payload + 12
                for _ in range(count):
                    x, y, z = struct.unpack_from("<fff", data, off)
                    xs.append(x)
                    ys.append(y)
                    zs.append(z)
                    off += stride
                found.append((xs, ys, zs))
            elif tag == b"NODE":
                name_end = data.index(b"\0", payload)
                # name + translation (3f) + scale (3f) + quaternion (4f)
                walk(name_end + 1 + 40, chunk_end)
            elif tag == b"MESH":
                # brush id (u32) followed by VRTS/TRIS child chunks
                walk(payload + 4, chunk_end)
            pos = chunk_end
        return pos

    walk(12, len(data))
    if not found:
        raise SystemExit("no VRTS chunk in %s; chunks seen: %s" % (path, seen_tags))
    xs = [v for f in found for v in f[0]]
    ys = [v for f in found for v in f[1]]
    zs = [v for f in found for v in f[2]]
    return min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)


def gltf_extents(path):
    doc = json.load(open(path, encoding="utf-8"))
    mn = [None] * 3
    mx = [None] * 3
    for mesh in doc.get("meshes", []):
        for prim in mesh.get("primitives", []):
            acc = doc["accessors"][prim["attributes"]["POSITION"]]
            for axis in range(3):
                lo = acc["min"][axis]
                hi = acc["max"][axis]
                mn[axis] = lo if mn[axis] is None else min(mn[axis], lo)
                mx[axis] = hi if mx[axis] is None else max(mx[axis], hi)
    return mn[0], mx[0], mn[1], mx[1], mn[2], mx[2]


for path in sys.argv[1:]:
    if path.endswith(".b3d"):
        x0, x1, y0, y1, z0, z1 = b3d_extents(path)
    else:
        x0, x1, y0, y1, z0, z1 = gltf_extents(path)
    print("%s:" % path)
    print("  x: %8.3f .. %8.3f  (size %.3f)" % (x0, x1, x1 - x0))
    print("  y: %8.3f .. %8.3f  (size %.3f)" % (y0, y1, y1 - y0))
    print("  z: %8.3f .. %8.3f  (size %.3f)" % (z0, z1, z1 - z0))
