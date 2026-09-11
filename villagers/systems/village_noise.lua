-- village_noise.lua
-- LEGACY: village placement no longer uses noise-based decorations
-- (see systems/village_placement.lua). These tables are kept only for
-- compatibility with anything that still references lualore.global_*.
-- Original purpose: "ONE global village noise - makes villages truly rare
-- worldwide".

lualore = lualore or {}

-- This is the ONE AND ONLY village noise used by EVERY biome
-- Optimized for compact villages limited to 1-2 mapchunks (80-160 nodes)
-- A mapchunk is 80x80x80 nodes
lualore.global_village_noise = {
    offset = 0.0,
    scale = 0.001,            -- Controls building spawn rate
    spread = {x = 100, y = 100, z = 100},   -- REDUCED from 300 - creates tighter clusters
    seed = 987654321,
    octaves = 2,              -- Reduced octaves = smoother, more predictable areas
    persistence = 0.5,        -- REDUCED from 0.6 - less variation at smaller scales
    lacunarity = 2.0,
    flags = "defaults",
}

-- Rarer central buildings (church/market/stable)
lualore.global_central_noise = table.copy(lualore.global_village_noise)
lualore.global_central_noise.scale = 0.0001   -- appear in ~1 out of 10 villages
lualore.global_central_noise.spread = {x = 120, y = 120, z = 120}  -- REDUCED from 400

-- Path noise - slightly different seed for variation but similar scale
lualore.global_path_noise = {
    offset = 0,
    scale = 0.001,
    spread = {x = 100, y = 100, z = 100},  -- REDUCED from 300 to match village size
    seed = 987654322,        -- Different seed for slight offset
    octaves = 2,
    persistence = 0.5,       -- REDUCED from 0.6 to match village noise
    lacunarity = 2.0,
    flags = "defaults",
}

--[[
VILLAGE SIZE CONFIGURATION:
- Spread parameter controls village compactness
- Current spread (100, 100, 100) creates villages ~100-160 nodes across
- This fits in 1-2 mapchunks (80x80x80 nodes each)
- Reduce spread further (e.g., 80, 80, 80) for single mapchunk villages
- Increase spread (e.g., 150, 150, 150) for larger villages

BUILDING DENSITY:
- Scale parameter (0.001) controls spawn rate
- Lower scale = fewer buildings, more rare villages
- Higher scale = more buildings, denser villages
]]
