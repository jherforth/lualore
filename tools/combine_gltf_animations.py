#!/usr/bin/env python3
"""Combine all animations of a glTF file into one continuous timeline.

Why: Luanti (<= 5.14) supports only a *single* animation for .gltf models and
uses the animation time values (seconds) as animation frame numbers for
`set_animation({x = start, y = end}, 1)`. Blockbench exports one glTF animation
per animation clip, which older Luanti versions cannot select between.

This tool concatenates the chosen clips back to back into a single animation
("combined") whose timeline starts at 0. The result is a drop-in model where
frame ranges select each clip:

    clip 1: 0.000 .. d1
    clip 2: d1    .. d1+d2
    ...

Usage:
    python tools/combine_gltf_animations.py in.gltf out.gltf [name...]

If no names are given, every animation is used in file order. The output keeps
the skinned mesh, materials and buffers of the source and contains exactly one
animation; the original animations are not included.
"""

import base64
import json
import os
import struct
import sys

FLOAT = 5126  # GL_FLOAT


def read_scalar_floats(doc, blob, accessor_index):
    acc = doc["accessors"][accessor_index]
    if acc["componentType"] != FLOAT or acc["type"] != "SCALAR":
        raise SystemExit("only float scalar animation inputs are supported")
    if "sparse" in acc:
        raise SystemExit("sparse accessors are not supported")
    bv = doc["bufferViews"][acc["bufferView"]]
    stride = bv.get("byteStride", 4)
    offset = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    values = []
    for i in range(acc["count"]):
        (value,) = struct.unpack_from("<f", blob, offset + i * stride)
        values.append(value)
    return values


def load_buffer(doc, in_path):
    buf = doc["buffers"][0]
    uri = buf.get("uri")
    if not uri:
        raise SystemExit("buffer 0 has no uri (embedded .glb is not supported)")
    if uri.startswith("data:"):
        return bytearray(base64.b64decode(uri.split(",", 1)[1]))
    with open(os.path.join(os.path.dirname(in_path), uri), "rb") as f:
        return bytearray(f.read())


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    in_path, out_path = sys.argv[1], sys.argv[2]
    wanted = sys.argv[3:]

    with open(in_path, encoding="utf-8") as f:
        doc = json.load(f)

    blob = load_buffer(doc, in_path)
    animations = doc.get("animations") or []
    if wanted:
        by_name = {a.get("name"): a for a in animations}
        chosen = []
        for name in wanted:
            if name not in by_name:
                raise SystemExit(
                    "animation %r not found (available: %s)" % (name, list(by_name))
                )
            chosen.append(by_name[name])
    else:
        chosen = animations
    if not chosen:
        raise SystemExit("no animations to combine")

    new_buffer_views = []
    new_accessors = []
    samplers = []
    channels = []
    time_offset = 0.0
    ranges = []

    for anim in chosen:
        # Duration of this clip = largest input time across its samplers.
        inputs = {s["input"] for s in anim["samplers"]}
        times_by_input = {
            idx: read_scalar_floats(doc, blob, idx) for idx in inputs
        }
        duration = max(max(t) for t in times_by_input.values())

        input_cache = {}
        for ch in anim["channels"]:
            src = anim["samplers"][ch["sampler"]]
            key = src["input"]
            if key not in input_cache:
                times = times_by_input[key]
                shifted = [t + time_offset for t in times]
                data = b"".join(struct.pack("<f", t) for t in shifted)
                # Keep every bufferView 4-byte aligned.
                pad = (4 - (len(blob) % 4)) % 4
                if pad:
                    blob.extend(b"\0" * pad)
                view_index = len(doc["bufferViews"]) + len(new_buffer_views)
                new_buffer_views.append(
                    {
                        "buffer": 0,
                        "byteOffset": len(blob),
                        "byteLength": len(data),
                    }
                )
                blob.extend(data)
                acc_index = len(doc["accessors"]) + len(new_accessors)
                new_accessors.append(
                    {
                        "bufferView": view_index,
                        "componentType": FLOAT,
                        "count": len(shifted),
                        "type": "SCALAR",
                        "min": [min(shifted)],
                        "max": [max(shifted)],
                    }
                )
                input_cache[key] = acc_index
            sampler_index = len(samplers)
            samplers.append(
                {
                    "input": input_cache[key],
                    "interpolation": src.get("interpolation", "LINEAR"),
                    "output": src["output"],
                }
            )
            channels.append({"sampler": sampler_index, "target": ch["target"]})

        ranges.append((anim.get("name"), time_offset, time_offset + duration))
        time_offset += duration

    merged = {
        "name": "animation.combined",
        "samplers": samplers,
        "channels": channels,
    }

    doc["bufferViews"].extend(new_buffer_views)
    doc["accessors"].extend(new_accessors)
    doc["animations"] = [merged]
    doc["buffers"][0]["byteLength"] = len(blob)
    doc["buffers"][0]["uri"] = "data:application/octet-stream;base64," + base64.b64encode(
        blob
    ).decode("ascii")

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(doc, f, separators=(",", ":"))

    print("wrote %s" % out_path)
    for name, start, end in ranges:
        print("  clip %-32s %.3f .. %.3f" % (name, start, end))
    print("  total duration: %.3f" % time_offset)
    return 0


if __name__ == "__main__":
    sys.exit(main())
