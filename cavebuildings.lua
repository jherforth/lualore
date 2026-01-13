local S = minetest.get_translator("lualore")

-- ===================================================================
-- CAVE CASTLE SPAWNING (dungeons-style frequency, handles uneven terrain)
-- ===================================================================

local cave_nodes = {
    "everness:crystal_case_dirt_with_moss",
    "caverealms:stone_with_moss",
    "caverealms:stone_with_lichen",
    "everness:crystal_cave_dirt_with_moss",
    "everness:dirt_with_crystal_grass",
    "everness:dirt_with_cursed_grass",
    "everness:soul_sandstone_veined",
    "default:desert_cobble",
    "default:dry_dirt",
    "default:dry_dirt_with_dry_grass",
    "everness:moss_block",
    "default:clay",
    "everness:mineral_lava_stone_with_moss",
    "default:stone",
    "default:desert_stone",
}

-- Track spawned castles to avoid duplicates
local spawned_castles = {}
local last_spawned_pos = nil
local storage = minetest.get_mod_storage()

local function load_spawned_castles()
    local data = storage:get_string("spawned_castles")
    if data and data ~= "" then
        spawned_castles = minetest.deserialize(data) or {}
    end
end

local function save_spawned_castles()
    storage:set_string("spawned_castles", minetest.serialize(spawned_castles))
end

load_spawned_castles()

-- Check if position has enough cave space (air/liquid)
local function is_cave_area(pos, radius)
    local air_count = 0
    local total_checks = 0

    -- Sample points in a sphere
    for dx = -radius, radius, 4 do
        for dy = -radius, radius, 4 do
            for dz = -radius, radius, 4 do
                local check_pos = {x = pos.x + dx, y = pos.y + dy, z = pos.z + dz}
                local node = minetest.get_node(check_pos)
                total_checks = total_checks + 1

                if node.name == "air" or
                   minetest.get_item_group(node.name, "liquid") > 0 then
                    air_count = air_count + 1
                end
            end
        end
    end

    -- At least 20% air means it's a cavern (reduced from 30%)
    local percentage = air_count / total_checks
    return percentage > 0.2
end

-- Find a relatively flat spot in the area for castle placement
local function find_flat_spot(center_pos, search_radius)
    local best_pos = nil
    local best_flatness = 0

    for attempt = 1, 30 do
        local test_x = center_pos.x + math.random(-search_radius, search_radius)
        local test_z = center_pos.z + math.random(-search_radius, search_radius)

        -- Find floor (search wider range)
        local floor_y = nil
        for y = center_pos.y + 20, center_pos.y - 30, -1 do
            local node = minetest.get_node({x = test_x, y = y, z = test_z})
            local above = minetest.get_node({x = test_x, y = y + 1, z = test_z})

            if node.name ~= "air" and above.name == "air" then
                floor_y = y + 1
                break
            end
        end

        if floor_y then
            -- Check flatness in a 5x5 area (reduced from 7x7)
            local flatness_score = 0

            for dx = -2, 2 do
                for dz = -2, 2 do
                    local check = {x = test_x + dx, y = floor_y, z = test_z + dz}
                    local below = {x = test_x + dx, y = floor_y - 1, z = test_z + dz}
                    local above = {x = test_x + dx, y = floor_y + 1, z = test_z + dz}

                    local node_check = minetest.get_node(check)
                    local node_below = minetest.get_node(below)
                    local node_above = minetest.get_node(above)

                    -- Need solid ground below, air above
                    if node_check.name == "air" and
                       node_above.name == "air" and
                       node_below.name ~= "air" and
                       minetest.get_item_group(node_below.name, "liquid") == 0 then
                        flatness_score = flatness_score + 1
                    end
                end
            end

            -- Accept if at least 60% flat (15 out of 25 blocks)
            if flatness_score >= 15 and flatness_score > best_flatness then
                best_flatness = flatness_score
                best_pos = {x = test_x, y = floor_y, z = test_z}

                -- If we found a very flat spot, use it immediately
                if flatness_score >= 23 then
                    break
                end
            end
        end
    end

    return best_pos, best_flatness
end

-- Spawn a cave castle at the given position
local function spawn_cave_castle(pos)
    local schematic_path = minetest.get_modpath("lualore") .. "/schematics/cavecastle.mts"

    -- Random rotation
    local rotations = {"0", "90", "180", "270"}
    local rotation = rotations[math.random(#rotations)]

    minetest.log("action", "[lualore] Attempting to place cave castle at " ..
                 minetest.pos_to_string(pos) .. " with rotation " .. rotation)

    -- Place schematic with force_placement in flags
    local success = minetest.place_schematic(
        pos,
        schematic_path,
        rotation,
        nil,
        true,
        "place_center_x,place_center_z,force_placement"
    )

    if success then
        last_spawned_pos = table.copy(pos)
        minetest.log("action", "[lualore] Cave castle placement SUCCESS at " .. minetest.pos_to_string(pos))
    else
        minetest.log("warning", "[lualore] Cave castle placement FAILED at " .. minetest.pos_to_string(pos))
    end

    return success
end

-- Mapgen callback - checks each chunk for cave castle spawn
minetest.register_on_generated(function(minp, maxp, blockseed)
    -- Only check underground
    if minp.y > 0 then return end
    if maxp.y < -8000 then return end

    -- Check this chunk key to avoid duplicates
    local chunk_key = minetest.pos_to_string(minp)
    if spawned_castles[chunk_key] then return end

    -- Much higher spawn rate - 1 in 3 chunks instead of 1 in 8
    local pr = PseudoRandom(blockseed)
    if pr:next(1, 3) ~= 1 then
        spawned_castles[chunk_key] = false
        return
    end

    -- Center of chunk
    local center = {
        x = minp.x + (maxp.x - minp.x) / 2,
        y = minp.y + (maxp.y - minp.y) / 2,
        z = minp.z + (maxp.z - minp.z) / 2,
    }

    -- Check if this is a cave area
    if not is_cave_area(center, 15) then
        spawned_castles[chunk_key] = false
        return
    end

    -- Find suitable flat spot
    local spawn_pos, flatness = find_flat_spot(center, 30)

    if spawn_pos then
        local success = spawn_cave_castle(spawn_pos)
        if success then
            spawned_castles[chunk_key] = true
            save_spawned_castles()
            minetest.log("action", "[lualore] Cave castle CONFIRMED at " ..
                         minetest.pos_to_string(spawn_pos) ..
                         " (flatness: " .. flatness .. "/25)")
        else
            spawned_castles[chunk_key] = false
        end
    else
        spawned_castles[chunk_key] = false
    end
end)

-- Save periodically
local save_timer = 0
minetest.register_globalstep(function(dtime)
    save_timer = save_timer + dtime
    if save_timer >= 120 then
        save_timer = 0
        save_spawned_castles()
    end
end)

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

        spawn_cave_castle(pos)

        return true, "Cave castle spawned at " .. minetest.pos_to_string(pos) .. " (check debug.txt for errors)"
    end,
})

-- Debug command to test schematic info
minetest.register_chatcommand("test_cavecastle", {
    params = "",
    description = "Test cave castle schematic loading",
    privs = {server = true},
    func = function(name, param)
        local schematic_path = minetest.get_modpath("lualore") .. "/schematics/cavecastle.mts"

        local schematic = minetest.read_schematic(schematic_path, {})
        if not schematic then
            return false, "Failed to read schematic!"
        end

        return true, "Schematic loaded successfully! Size: " ..
                     schematic.size.x .. "x" .. schematic.size.y .. "x" .. schematic.size.z
    end,
})

-- Teleport to last spawned cave castle
minetest.register_chatcommand("goto_cavecastle", {
    params = "",
    description = "Teleport to the last spawned cave castle",
    privs = {server = true},
    func = function(name, param)
        if not last_spawned_pos then
            return false, "No cave castle has been spawned yet!"
        end

        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        player:set_pos(last_spawned_pos)
        return true, "Teleported to cave castle at " .. minetest.pos_to_string(last_spawned_pos)
    end,
})

print(S("[MOD] Lualore - Cave castles loaded (dungeon-style spawning)"))
