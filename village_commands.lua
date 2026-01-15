-- village_commands.lua
-- Chat commands for managing villages and villagers

local S = minetest.get_translator("lualore")

-- Access the storage system used by house_spawning.lua
local storage = minetest.get_mod_storage()

-- Friendly villager classes matching house_spawning.lua
local friendly_classes = {
    "farmer", "blacksmith", "fisherman", "cleric",
    "bum", "entertainer", "witch", "jeweler", "ranger"
}

-- Marker nodes that identify biome types
local marker_to_biome = {
    -- Grassland
    ["lualore:grasslandbarrel"] = "grassland",
    ["lualore:grasslandaltar"] = "grassland",
    -- Desert
    ["lualore:hookah"] = "desert",
    ["lualore:desertcarpet"] = "desert",
    -- Ice
    ["lualore:sledge"] = "ice",
    -- Lake
    ["lualore:fishtrap"] = "lake",
    ["lualore:hangingfish"] = "lake",
    -- Savanna
    ["lualore:savannashrine"] = "savanna",
    -- Jungle
    ["lualore:jungleshrine"] = "jungle",
}

-- Build marker list for detection
local marker_list = {}
for node, _ in pairs(marker_to_biome) do
    table.insert(marker_list, node)
end

-- Detect biome based on nearby marker nodes
local function detect_biome(center_pos, radius)
    local markers = minetest.find_nodes_in_area(
        {x = center_pos.x - radius, y = center_pos.y - 10, z = center_pos.z - radius},
        {x = center_pos.x + radius, y = center_pos.y + 10, z = center_pos.z + radius},
        marker_list
    )

    if #markers > 0 then
        local marker_node = minetest.get_node(markers[1]).name
        return marker_to_biome[marker_node] or "grassland"
    end

    return "grassland" -- Default
end

-- Find a suitable spawn position near a bed
local function find_spawn_position(bed_pos)
    -- Try to find outdoor position 6-10 blocks away
    for distance = 6, 10 do
        for dx = -distance, distance do
            for dz = -distance, distance do
                if math.abs(dx) + math.abs(dz) >= distance then
                    for dy = -2, 2 do
                        local check = {
                            x = bed_pos.x + dx,
                            y = bed_pos.y + dy,
                            z = bed_pos.z + dz
                        }

                        local node = minetest.get_node(check)
                        local above = minetest.get_node({x=check.x, y=check.y+1, z=check.z})
                        local below = minetest.get_node({x=check.x, y=check.y-1, z=check.z})

                        -- Need air at position and above, solid ground below
                        if node.name == "air" and above.name == "air" and
                           minetest.get_item_group(below.name, "solid") == 1 then
                            return check
                        end
                    end
                end
            end
        end
    end

    -- Fallback position
    return {x = bed_pos.x + 6, y = bed_pos.y, z = bed_pos.z}
end

-- Register the populate_village command
minetest.register_chatcommand("populate_village", {
    params = "[radius]",
    description = "Repopulate village by spawning villagers for beds. Default radius: 50",
    privs = {server = true}, -- Requires server privileges to prevent abuse
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found."
        end

        local player_pos = player:get_pos()
        local radius = tonumber(param) or 50

        if radius < 10 or radius > 200 then
            return false, "Radius must be between 10 and 200."
        end

        minetest.chat_send_player(name, "Scanning for beds in " .. radius .. " block radius...")

        -- Find all beds in the area
        local search_min = {x = player_pos.x - radius, y = player_pos.y - 30, z = player_pos.z - radius}
        local search_max = {x = player_pos.x + radius, y = player_pos.y + 30, z = player_pos.z + radius}
        local beds = minetest.find_nodes_in_area(search_min, search_max, "group:bed")

        if #beds == 0 then
            return false, "No beds found in the area."
        end

        -- Load existing bed-villager tracking
        local beds_with_villagers = {}
        local data = storage:get_string("beds_with_villagers")
        if data and data ~= "" then
            beds_with_villagers = minetest.deserialize(data) or {}
        end

        -- Detect biome for this village
        local biome = detect_biome(player_pos, radius)

        local processed_beds = {}
        local bed_pairs = {}
        local spawned_count = 0
        local skipped_count = 0

        for _, bed_pos in ipairs(beds) do
            local bed_key = minetest.pos_to_string(bed_pos)

            -- Skip if already processed in this scan or already has villager
            if beds_with_villagers[bed_key] or processed_beds[bed_key] then
                skipped_count = skipped_count + 1
                goto continue
            end

            -- Handle bed pairs (avoid spawning 2 villagers for 1 double bed)
            local bed_pair_key = nil
            for _, offset in ipairs({{x=1,y=0,z=0}, {x=-1,y=0,z=0}, {x=0,y=0,z=1}, {x=0,y=0,z=-1}}) do
                local check_pos = vector.add(bed_pos, offset)
                local check_node = minetest.get_node(check_pos)
                if minetest.get_item_group(check_node.name, "bed") > 0 then
                    local pos1, pos2 = bed_pos, check_pos
                    if pos1.x > pos2.x or pos1.z > pos2.z then
                        pos1, pos2 = pos2, pos1
                    end
                    bed_pair_key = minetest.pos_to_string(pos1) .. "|" .. minetest.pos_to_string(pos2)
                    break
                end
            end

            if bed_pair_key and bed_pairs[bed_pair_key] then
                goto continue
            end
            if bed_pair_key then
                bed_pairs[bed_pair_key] = true
            end

            -- Find spawn position
            local spawn_pos = find_spawn_position(bed_pos)

            -- Spawn random friendly villager of this biome
            local class = friendly_classes[math.random(#friendly_classes)]
            local mob_name = "lualore:" .. biome .. "_" .. class

            local obj = minetest.add_entity(spawn_pos, mob_name)
            if obj then
                local luaent = obj:get_luaentity()
                if luaent then
                    luaent.nv_house_pos = vector.new(bed_pos)
                    luaent.nv_home_radius = 20
                end
                beds_with_villagers[bed_key] = true
                processed_beds[bed_key] = true
                spawned_count = spawned_count + 1
            end

            ::continue::
        end

        -- Save updated tracking
        storage:set_string("beds_with_villagers", minetest.serialize(beds_with_villagers))

        local message = string.format(
            "Village population complete!\nBiome: %s\nBeds found: %d\nVillagers spawned: %d\nSkipped (already populated): %d",
            biome, #beds, spawned_count, skipped_count
        )

        return true, message
    end,
})

-- Register a command to clear bed-villager tracking (for testing/debugging)
minetest.register_chatcommand("reset_village_tracking", {
    params = "",
    description = "Clear all bed-villager tracking data. Use before repopulating villages.",
    privs = {server = true},
    func = function(name, param)
        storage:set_string("beds_with_villagers", minetest.serialize({}))
        return true, "Village tracking data cleared. You can now use /populate_village to respawn villagers."
    end,
})

print(S("[MOD] Native Villages - Village management commands loaded"))

