#!/usr/bin/env python3
"""Validate the deterministic grid math shared by villages, ruins and
cave castles: candidate density and chunk-scan coverage.

This mirrors the exact hash/candidate math from the Lua sources and, for
several synthetic world salts, checks that:

  * candidates lie in the middle half of their grid cell,
  * the chunk containing a candidate is guaranteed to include that cell
    in its on_generated scan window (both the village-style window with
    the 3/4 and 1/4 shifts, and the cave-castle-style floor window),
  * the candidate density matches chance / spacing^2.

Run from the mod root:  python tools/simulate_grid.py
"""

import math

M = 2147483647
CHUNK = 80  # 5x5x5 mapblocks


def hash_mix(n, value):
    return (n * 48271 + (value % M)) % M


def cell_hash(salt, cx, cz, extra):
    h = hash_mix(salt, cx)
    h = hash_mix(h, cz)
    h = hash_mix(h, extra)
    return h


def candidate(salt, cx, cz, spacing, chance, extra):
    h = cell_hash(salt, cx, cz, extra)
    if h > chance * M:
        return None
    margin = spacing // 4
    span = max(1, spacing - 2 * margin)
    jx = margin + hash_mix(h, 137) % span
    jz = margin + hash_mix(h, 269) % span
    return cx * spacing + jx, cz * spacing + jz


def check(name, salt, spacing, chance, extra, window):
    cells = 0
    candidates = 0
    for cx in range(-12, 13):
        for cz in range(-12, 13):
            cells += 1
            c = candidate(salt, cx, cz, spacing, chance, extra)
            if not c:
                continue
            candidates += 1
            x, z = c
            margin = spacing // 4
            assert cx * spacing + margin <= x < cx * spacing + spacing - margin, \
                "%s: candidate outside middle half" % name

            # Chunk that contains the candidate.
            minx = math.floor(x / CHUNK) * CHUNK
            minz = math.floor(z / CHUNK) * CHUNK
            maxx, maxz = minx + CHUNK - 1, minz + CHUNK - 1

            if window == "village":
                c0x = math.floor((minx - spacing * 3 / 4) / spacing)
                c1x = math.floor((maxx - spacing / 4) / spacing)
                c0z = math.floor((minz - spacing * 3 / 4) / spacing)
                c1z = math.floor((maxz - spacing / 4) / spacing)
            else:  # cave castle style floor window
                c0x = math.floor(minx / spacing)
                c1x = math.floor(maxx / spacing)
                c0z = math.floor(minz / spacing)
                c1z = math.floor(maxz / spacing)

            assert c0x <= cx <= c1x and c0z <= cz <= c1z, \
                ("%s: cell %d,%d candidate %d,%d not in chunk window "
                 "(%d..%d, %d..%d)") % (name, cx, cz, x, z, c0x, c1x, c0z, c1z)

    expected = 25 * 25 * chance
    assert abs(candidates - expected) <= expected * 0.25, \
        "%s: candidate count %d far from expected %.0f" % (name, candidates, expected)
    print("%-8s salt=%-10d cells=%d candidates=%d (expected ~%.0f)"
          % (name, salt, cells, candidates, expected))


for salt in (1073741823, 42, 987654321, 3, 2147483646, 55):
    check("village", salt, 400, 0.8, 23, "village")
    check("castle", salt, 400, 1.0, 0, "castle")
    check("ruins", salt, 450, 0.75, 41, "village")
    check("doors", salt, 450, 0.7, 57, "village")

print("grid math OK: every candidate lands in a chunk that scans its cell")
