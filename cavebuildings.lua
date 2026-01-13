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

-- Check if a position is a valid cave floor
local function is_valid_cave_floor(pos)
    -- Check for solid ground below
    local below = minetest.get_node({x=pos.x, y=pos.y-1, z=pos.z})
    local floor_nodes = {
        ["default:stone"] = true,
        ["default:desert_stone"] = true,
        ["default:sandstone"] = true,
        ["default:cobble"] = true,
        ["default:mossycobble"] = true,
    }

    if not floor_nodes[below.name] then
        return false
    end

    -- Check for air above (need space for castle)
    for y_offset = 0, 15 do  -- Castle needs ~15 blocks of height
        local above = minetest.get_node({x=pos.x, y=pos.y+y_offset, z=pos.z})
        if above.name ~= "air" then
            return false
        end
    end

    -- Check for enough floor space around (castle is ~20x20)
    for x_offset = -10, 10, 5 do
        for z_offset = -10, 10, 5 do
            local check_pos = {x=pos.x+x_offset, y=pos.y-1, z=pos.z+z_offset}
            local node = minetest.get_node(check_pos)
            if not floor_nodes[node.name] then
                return false
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

    -- Very rare chance per chunk
    local pr = PcgRandom(blockseed + 8492)
    if pr:next(1, 5000) ~= 1 then  -- 1 in 5000 chance per chunk
        return
    end

    -- Try to find a valid position in this chunk
    local attempts = 0
    while attempts < 5 do
        attempts = attempts + 1

        local test_pos = {
            x = pr:next(minp.x + 20, maxp.x - 20),
            y = pr:next(minp.y + 20, maxp.y - 20),
            z = pr:next(minp.z + 20, maxp.z - 20),
        }

        -- Check if position is valid
        if is_valid_cave_floor(test_pos) and is_far_from_castles(test_pos) then
            -- Place the castle
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
            end
            return
        end
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

print(S("[MOD] Lualore - Cave castles loaded (manual spawning with proper floor detection)"))
