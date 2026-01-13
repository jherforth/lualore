local S = minetest.get_translator("lualore")

-- ===================================================================
-- CAVE CASTLE SPAWNING - Simple decoration-based system
-- ===================================================================
-- Uses the same pattern as village buildings but for underground caves

lualore = lualore or {}

-- Ultra-rare noise for cave castles (much rarer than village central buildings)
-- This ensures only one castle spawns per large underground area
lualore.cave_castle_noise = {
    offset = 0.0,
    scale = 0.00001,          -- Extremely rare (10x rarer than central buildings)
    spread = {x = 500, y = 500, z = 500},  -- Large spread for max rarity
    seed = 192837465,         -- Unique seed for cave castles
    octaves = 3,
    persistence = 0.6,
    lacunarity = 2.0,
    flags = "defaults",
}

-- Register cave castle as a decoration
minetest.register_decoration({
    name = "lualore:cavecastle",
    deco_type = "schematic",

    -- Place on any solid node typically found in caves
    place_on = {
        "default:stone",
        "default:desert_stone",
        "default:desert_sand",
        "default:sandstone",
        "default:cobble",
        "default:mossycobble",
        "default:desert_cobble",
        "caverealms:stone_with_moss",
        "caverealms:stone_with_lichen",
        "everness:crystal_case_dirt_with_moss",
        "everness:crystal_cave_dirt_with_moss",
        "everness:dirt_with_crystal_grass",
        "everness:dirt_with_cursed_grass",
        "everness:soul_sandstone_veined",
        "everness:moss_block",
        "everness:mineral_lava_stone_with_moss",
        "default:dry_dirt",
        "default:dry_dirt_with_dry_grass",
        "default:clay",
    },

    sidelen = 80,
    noise_params = lualore.cave_castle_noise,

    -- No biome restriction - can spawn anywhere underground
    -- biomes parameter omitted = all biomes

    -- Deep underground only
    y_min = -8000,
    y_max = -100,

    place_offset_y = -8,
    flags = "place_center_x, place_center_z, force_placement, all_floors",

    -- Allow placement on varied terrain
    height = 0,
    height_max = 0,

    schematic = minetest.get_modpath("lualore") .. "/schematics/cavecastle.mts",
    rotation = "random",
})

-- ===================================================================
-- CAVE WIZARDS - Spawn at dm_statue markers
-- ===================================================================
-- When a castle spawns, it contains a caverealms:dm_statue
-- We'll spawn wizards near these statues

local wizard_colors = {"red", "white", "black", "golden"}
local spawned_statues = {}
local storage = minetest.get_mod_storage()

-- Load tracked statues
local function load_statues()
    local data = storage:get_string("spawned_cave_statues")
    if data and data ~= "" then
        spawned_statues = minetest.deserialize(data) or {}
        minetest.log("action", "[Lualore] Loaded " .. #spawned_statues .. " cave statue positions")
    end
end

local function save_statues()
    storage:set_string("spawned_cave_statues", minetest.serialize(spawned_statues))
end

load_statues()

-- Check for new statues and spawn wizards
minetest.register_on_generated(function(minp, maxp, blockseed)
    minetest.after(8, function()  -- Wait for decorations to place
        -- Only check underground
        if minp.y > -100 then
            return
        end

        -- Look for dm_statue nodes
        local statues = minetest.find_nodes_in_area(
            minp,
            maxp,
            {"caverealms:dm_statue"}
        )

        for _, statue_pos in ipairs(statues) do
            local statue_key = minetest.pos_to_string(statue_pos)

            -- Skip if we already spawned wizards here
            if spawned_statues[statue_key] then
                goto continue
            end

            minetest.log("action", "[Lualore] Found new cave castle at " .. statue_key)

            -- Spawn 4 wizards (one of each color)
            local spawn_attempts = 0
            local wizards_spawned = 0

            while wizards_spawned < 4 and spawn_attempts < 50 do
                spawn_attempts = spawn_attempts + 1

                -- Random position near the statue
                local offset = {
                    x = math.random(-15, 15),
                    y = math.random(-5, 5),
                    z = math.random(-15, 15)
                }

                local spawn_pos = vector.add(statue_pos, offset)
                local node_below = minetest.get_node({x = spawn_pos.x, y = spawn_pos.y - 1, z = spawn_pos.z})
                local node_at = minetest.get_node(spawn_pos)

                -- Check if it's a valid spawn spot (solid below, air at position)
                if node_below.name ~= "air" and node_at.name == "air" then
                    local color = wizard_colors[wizards_spawned + 1]

                    local wizard = minetest.add_entity(spawn_pos, "lualore:" .. color .. "wizard")
                    if wizard then
                        wizards_spawned = wizards_spawned + 1
                        minetest.log("action", "[Lualore] Spawned " .. color .. " wizard at cave castle")
                    end
                end
            end

            if wizards_spawned > 0 then
                spawned_statues[statue_key] = true
                save_statues()
                minetest.log("action", "[Lualore] Cave castle complete: " .. wizards_spawned .. "/4 wizards spawned")
            end

            ::continue::
        end
    end)
end)

-- ===================================================================
-- DEBUG COMMANDS
-- ===================================================================

-- Manual spawn command
minetest.register_chatcommand("spawn_cavecastle", {
    params = "",
    description = "Spawn a cave castle at your current position",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        local pos = player:get_pos()
        pos.y = math.floor(pos.y)

        local schematic_path = minetest.get_modpath("lualore") .. "/schematics/cavecastle.mts"

        local success = minetest.place_schematic(
            {x=pos.x, y=pos.y-8, z=pos.z},
            schematic_path,
            "random",
            nil,
            true,
            "place_center_x, place_center_z"
        )

        if success then
            return true, "Cave castle spawned at " .. minetest.pos_to_string(pos)
        else
            return false, "Failed to spawn cave castle"
        end
    end,
})

-- Find nearest statue
minetest.register_chatcommand("find_castle", {
    params = "<radius>",
    description = "Find nearest cave castle within radius (default 100)",
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

            return true, "Found " .. #statues .. " castles. Nearest at " ..
                        minetest.pos_to_string(nearest) ..
                        " (distance: " .. math.floor(min_dist) .. " nodes)"
        else
            return false, "No castles found within " .. radius .. " nodes"
        end
    end,
})

-- Clear statue records (allows respawning wizards for testing)
minetest.register_chatcommand("clear_castle_records", {
    params = "",
    description = "Clear castle records (allows wizard respawn)",
    privs = {server = true},
    func = function(name, param)
        local count = 0
        for _ in pairs(spawned_statues) do
            count = count + 1
        end
        spawned_statues = {}
        save_statues()
        return true, "Cleared " .. count .. " castle records"
    end,
})

print(S("[MOD] Lualore - Cave castles loaded (decoration-based spawning)"))
