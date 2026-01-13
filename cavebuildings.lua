local S = minetest.get_translator("lualore")

-- ===================================================================
-- DM STATUE (prize for defeating wizards)
-- ===================================================================
-- The caverealms:dm_statue is from the caverealms mod (dependency)
-- It's spawned in cave castles as the prize for defeating the wizards

-- ===================================================================
-- CAVE CASTLE SPAWNING - Simple decoration approach like villages
-- ===================================================================

-- Noise parameters for extremely rare spawning (3000+ node spacing)
local cave_castle_noise = {
    offset = -0.5,  -- Negative offset makes it even rarer
    scale = 1,
    spread = {x = 3000, y = 3000, z = 3000},  -- 3000 node spacing minimum
    seed = 8492,
    octaves = 2,  -- Fewer octaves = less variation = rarer
    persist = 0.3,  -- Lower persistence = rarer
    lacunarity = 2.0,
}

-- Register cave castle as a decoration
minetest.register_decoration({
    name = "lualore:cavecastle",
    deco_type = "schematic",
    place_on = {
        "default:stone",
        "default:desert_stone",
        "default:sandstone",
        "default:silver_sandstone",
        "default:desert_sandstone",
        "default:cobble",
        "default:mossycobble",
    },
    sidelen = 80,
    fill_ratio = 0.000001,  -- Extremely rare
    noise_params = cave_castle_noise,
    y_min = -8000,
    y_max = -100,  -- Only spawn deeper underground
    place_offset_y = -8,
    flags = "place_center_x, place_center_z, force_placement",  -- Removed all_floors to prevent multi-level spawning
    schematic = minetest.get_modpath("lualore") .. "/schematics/cavecastle.mts",
    rotation = "random",
})

-- Debug command to manually spawn a cave castle
minetest.register_chatcommand("spawn_cavecastle", {
    params = "",
    description = "Spawn a cave castle at your current position (for testing)",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        local pos = player:get_pos()
        pos.y = math.floor(pos.y)

        local schematic_path = minetest.get_modpath("lualore") .. "/schematics/cavecastle.mts"

        -- Check if file exists
        local file = io.open(schematic_path, "r")
        if not file then
            return false, "Schematic file not found at: " .. schematic_path
        end
        file:close()

        -- Place the schematic directly with same flags as decoration
        local success = minetest.place_schematic(
            pos,
            schematic_path,
            "random",
            nil,
            true,
            "place_center_x, place_center_z, force_placement, all_floors"
        )

        if success then
            return true, "Cave castle spawned at " .. minetest.pos_to_string(pos)
        else
            return false, "Failed to spawn cave castle"
        end
    end,
})

-- Debug command to find nearest statue
minetest.register_chatcommand("find_statue", {
    params = "<radius>",
    description = "Find nearest dm_statue within radius (default 100)",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        local pos = player:get_pos()
        local radius = tonumber(param) or 100

        local statues = minetest.find_nodes_in_area(
            {x = pos.x - radius, y = pos.y - radius, z = pos.z - radius},
            {x = pos.x + radius, y = pos.y + radius, z = pos.z + radius},
            {"caverealms:dm_statue"}
        )

        if #statues > 0 then
            local nearest = statues[1]
            local min_dist = vector.distance(pos, nearest)

            for _, statue_pos in ipairs(statues) do
                local dist = vector.distance(pos, statue_pos)
                if dist < min_dist then
                    min_dist = dist
                    nearest = statue_pos
                end
            end

            return true, "Found " .. #statues .. " statues. Nearest at " ..
                        minetest.pos_to_string(nearest) ..
                        " (distance: " .. math.floor(min_dist) .. " nodes)"
        else
            return false, "No statues found within " .. radius .. " nodes"
        end
    end,
})

print(S("[MOD] Lualore - Cave castles loaded (decoration spawning)"))
