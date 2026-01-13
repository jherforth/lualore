local S = minetest.get_translator("lualore")

-- ===================================================================
-- DM STATUE (prize for defeating wizards)
-- ===================================================================
-- The caverealms:dm_statue is from the caverealms mod (dependency)
-- It's spawned in cave castles as the prize for defeating the wizards

-- ===================================================================
-- CAVE CASTLE SPAWNING - Manual placement with proper checks
-- ===================================================================

-- Storage for tracking castle positions to prevent clustering
local castle_positions = {}
local MIN_CASTLE_DISTANCE = 1000  -- Minimum distance between castles
local storage = minetest.get_mod_storage()

-- Load castle positions from storage
local function load_castle_positions()
    local serialized = storage:get_string("castle_positions")
    if serialized and serialized ~= "" then
        castle_positions = minetest.deserialize(serialized) or {}
        minetest.log("action", "[Lualore] Loaded " .. #castle_positions .. " castle positions")
    end
end

-- Save castle positions to storage
local function save_castle_positions()
    storage:set_string("castle_positions", minetest.serialize(castle_positions))
end

-- Load positions on startup
load_castle_positions()

-- Check if a position is far enough from existing castles
local function is_far_from_castles(pos)
    for _, castle_pos in ipairs(castle_positions) do
        local dist = vector.distance(pos, castle_pos)
        if dist < MIN_CASTLE_DISTANCE then
            return false
        end
    end
    return true
end

-- Cache content IDs for performance (only cache common ones that are guaranteed to exist)
local c_air = minetest.get_content_id("air")
local c_stone = minetest.get_content_id("default:stone")
local c_desert_stone = minetest.get_content_id("default:desert_stone")
local c_sandstone = minetest.get_content_id("default:sandstone")
local c_cobble = minetest.get_content_id("default:cobble")
local c_mossycobble = minetest.get_content_id("default:mossycobble")

-- Cache optional content IDs (may not exist in all games)
local c_floor_nodes = {c_stone, c_desert_stone, c_sandstone, c_cobble, c_mossycobble}

-- Try to add optional mod nodes
local optional_floors = {
    "caverealms:stone_with_moss",
    "caverealms:stone_with_lichen",
    "everness:crystal_case_dirt_with_moss",
    "everness:crystal_cave_dirt_with_moss",
    "everness:dirt_with_crystal_grass",
    "everness:dirt_with_cursed_grass",
    "everness:soul_sandstone_veined",
    "everness:moss_block",
    "everness:mineral_lava_stone_with_moss",
    "default:desert_cobble",
    "default:dry_dirt",
    "default:dry_dirt_with_dry_grass",
    "default:clay",
}

for _, nodename in ipairs(optional_floors) do
    if minetest.registered_nodes[nodename] then
        table.insert(c_floor_nodes, minetest.get_content_id(nodename))
    end
end

-- Check if a content ID is a valid floor node
local function is_floor_node(cid)
    for _, floor_cid in ipairs(c_floor_nodes) do
        if cid == floor_cid then
            return true
        end
    end
    return false
end

-- Check if a position is a valid cave floor using VoxelManip data
local function is_valid_cave_floor(pos, data, area)
    local floor_y = pos.y - 1
    local castle_width = 20
    local castle_height = 15

    -- Check for solid floor below (sample multiple points)
    for x = pos.x - castle_width/2, pos.x + castle_width/2, 3 do
        for z = pos.z - castle_width/2, pos.z + castle_width/2, 3 do
            local idx = area:index(x, floor_y, z)
            if not is_floor_node(data[idx]) then
                return false
            end
        end
    end

    -- Check for air above (castle needs vertical space)
    for y = pos.y, pos.y + castle_height do
        for x = pos.x - 8, pos.x + 8, 3 do
            for z = pos.z - 8, pos.z + 8, 3 do
                local idx = area:index(x, y, z)
                if data[idx] ~= c_air then
                    return false
                end
            end
        end
    end

    return true
end

-- Mapgen callback for castle spawning
minetest.register_on_generated(function(minp, maxp, blockseed)
    -- Only check deep underground
    if minp.y > -100 or maxp.y < -8000 then
        return
    end

    -- Rare chance per chunk
    local pr = PcgRandom(blockseed + 8492)
    if pr:next(1, 500) ~= 1 then  -- 1 in 500 chance per chunk (for testing)
        return
    end

    minetest.log("action", "[Lualore] Attempting castle spawn in chunk " ..
        minetest.pos_to_string(minp) .. " to " .. minetest.pos_to_string(maxp))

    -- Read the voxel data
    local vm = minetest.get_voxelmanip()
    local emin, emax = vm:read_from_map(minp, maxp)
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()

    -- Try to find a valid position in this chunk
    local attempts = 0
    while attempts < 10 do
        attempts = attempts + 1

        local test_pos = {
            x = pr:next(minp.x + 25, maxp.x - 25),
            y = pr:next(minp.y + 20, maxp.y - 20),
            z = pr:next(minp.z + 25, maxp.z - 25),
        }

        -- Check if position has valid floor
        if is_valid_cave_floor(test_pos, data, area) then
            -- Check if far enough from other castles
            if is_far_from_castles(test_pos) then
                -- Schedule castle placement (must be done after mapgen completes)
                minetest.after(0.1, function()
                    local schematic_path = minetest.get_modpath("lualore") .. "/schematics/cavecastle.mts"
                    local success = minetest.place_schematic(
                        {x=test_pos.x, y=test_pos.y-8, z=test_pos.z},
                        schematic_path,
                        "random",
                        nil,
                        true,
                        "place_center_x, place_center_z"
                    )

                    if success then
                        table.insert(castle_positions, test_pos)
                        save_castle_positions()
                        minetest.log("action", "[Lualore] Cave castle spawned at " ..
                            minetest.pos_to_string(test_pos))
                    else
                        minetest.log("warning", "[Lualore] Failed to place castle schematic at " ..
                            minetest.pos_to_string(test_pos))
                    end
                end)
                return
            else
                minetest.log("action", "[Lualore] Valid floor found but too close to existing castle at " ..
                    minetest.pos_to_string(test_pos))
            end
        end
    end

    minetest.log("action", "[Lualore] No valid castle location found after " .. attempts .. " attempts")
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

        -- Check distance from other castles
        if not is_far_from_castles(pos) then
            return false, "Too close to another castle (min distance: " .. MIN_CASTLE_DISTANCE .. " nodes)"
        end

        local schematic_path = minetest.get_modpath("lualore") .. "/schematics/cavecastle.mts"

        -- Check if file exists
        local file = io.open(schematic_path, "r")
        if not file then
            return false, "Schematic file not found at: " .. schematic_path
        end
        file:close()

        -- Place the schematic
        local success = minetest.place_schematic(
            {x=pos.x, y=pos.y-8, z=pos.z},
            schematic_path,
            "random",
            nil,
            true,
            "place_center_x, place_center_z"
        )

        if success then
            table.insert(castle_positions, pos)
            save_castle_positions()
            return true, "Cave castle spawned at " .. minetest.pos_to_string(pos)
        else
            return false, "Failed to spawn cave castle"
        end
    end,
})

-- Command to list all castle positions
minetest.register_chatcommand("list_castles", {
    params = "",
    description = "List all spawned cave castle positions",
    privs = {server = true},
    func = function(name, param)
        if #castle_positions == 0 then
            return true, "No castles have been spawned yet"
        end

        local output = "Cave castles (" .. #castle_positions .. " total):\n"
        for i, pos in ipairs(castle_positions) do
            output = output .. i .. ". " .. minetest.pos_to_string(pos) .. "\n"
        end
        return true, output
    end,
})

-- Command to clear all castle position records
minetest.register_chatcommand("clear_castle_records", {
    params = "",
    description = "Clear all castle position records (allows new spawns)",
    privs = {server = true},
    func = function(name, param)
        local count = #castle_positions
        castle_positions = {}
        save_castle_positions()
        return true, "Cleared " .. count .. " castle position records"
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

print(S("[MOD] Lualore - Cave castles loaded (VoxelManip-based spawning with proper floor detection)"))
