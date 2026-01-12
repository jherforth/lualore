local S = minetest.get_translator("lualore")

-- Load utils once (init.lua already does this — you can delete this line if you want)
-- dofile(minetest.get_modpath("lualore") .. "/utils.lua")

local central_noise = lualore.global_central_noise

-- ===================================================================
-- Central / big buildings (church, market, etc.)
-- ===================================================================
local function register_cave_central(params)
    minetest.register_decoration({
        name = "lualore:" .. params.name,
        deco_type = "schematic",
        place_on = {"everness:crystal_case_dirt_with_moss","default:stone","default:dry_dirt_with_dry_grass","default:dry_dirt"},
        sidelen = 58,                          -- bigger grid for rare buildings
        noise_params = central_noise,
        biomes = {"cave","everness:forsaken_cave"},
        y_min = -8000,
        y_max = 0,

        place_offset_y = -8,
        flags = "place_center_x, place_center_z, force_placement, all_floors",
        height = 0,
        height_max = 0,

        schematic = minetest.get_modpath("lualore") .. "/schematics/" .. params.file,
        rotation = "random",
    })
end

-- ===================================================================
-- REGISTER EVERYTHING
-- ===================================================================

register_cave_central({name = "cavecastle",  file = "cavecastle.mts"})

print(S("[MOD] Lualore - Cave buildings loaded"))
