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

-- Marker node -> biome, shared with house_spawning.lua.
-- Defined in villagers/blocks/aliases.lua.
local marker_to_biome = lualore.village_markers
local marker_list = lualore.village_marker_list

-- Detect biome based on nearby marker nodes
-- Biome detection and spawn-spot searching used to be duplicated here.
-- Both now live in house_spawning.lua, which /populate_village calls.

minetest.register_chatcommand("populate_village", {
    params = "[radius]",
    description = "Repopulate a village by spawning villagers for its beds. Default radius: 50",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found."
        end

        local pos = player:get_pos()
        local radius = tonumber(param) or 50
        if radius < 10 or radius > 200 then
            return false, "Radius must be between 10 and 200."
        end

        -- This used to be a second, drifting copy of house_spawning's
        -- bed logic. It now calls the same function the village placer
        -- does, so a village repopulated by hand comes out exactly like
        -- one that populated itself: same trade deck, same bed pairing,
        -- same record of which beds are deliberately empty.
        local hs = lualore.house_spawning
        if not (hs and hs.populate) then
            return false, "Villager spawning system is not loaded."
        end

        local ok, spawned = pcall(hs.populate,
            {x = pos.x - radius, y = pos.y - 40, z = pos.z - radius},
            {x = pos.x + radius, y = pos.y + 40, z = pos.z + radius})
        if not ok then
            return false, "Failed: " .. tostring(spawned)
        end
        if (spawned or 0) == 0 then
            return true, "No unclaimed beds within " .. radius ..
                " nodes. Use /reset_village_tracking first if you want to " ..
                "repopulate beds that already had villagers."
        end
        return true, string.format("Spawned %d villagers within %d nodes.",
            spawned, radius)
    end,
})

-- Register a command to remove villagers in an area
minetest.register_chatcommand("clear_villagers", {
    params = "[radius]",
    description = "Remove all villagers in a radius around you. Default radius: 50",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found."
        end

        local player_pos = player:get_pos()
        local radius = tonumber(param) or 50

        if radius < 5 or radius > 200 then
            return false, "Radius must be between 5 and 200."
        end

        local removed_count = 0
        local objects = minetest.get_objects_inside_radius(player_pos, radius)

        for _, obj in ipairs(objects) do
            local ent = obj:get_luaentity()
            if ent and ent.name then
                -- Check if it's a villager (matches biome_class pattern)
                local is_villager = false
                for biome, _ in pairs(marker_to_biome) do
                    for _, class in ipairs(friendly_classes) do
                        local mob_pattern = "lualore:" .. marker_to_biome[biome] .. "_" .. class
                        if ent.name == mob_pattern then
                            is_villager = true
                            break
                        end
                    end
                    if is_villager then break end
                end

                -- Also check for sky folk
                if ent.name == "lualore:sky_folk" then
                    is_villager = true
                end

                if is_villager then
                    obj:remove()
                    removed_count = removed_count + 1
                end
            end
        end

        -- Clear bed tracking for the area
        local beds_with_villagers = {}
        local data = storage:get_string("beds_with_villagers")
        if data and data ~= "" then
            beds_with_villagers = minetest.deserialize(data) or {}
        end

        local search_min = {x = player_pos.x - radius, y = player_pos.y - 30, z = player_pos.z - radius}
        local search_max = {x = player_pos.x + radius, y = player_pos.y + 30, z = player_pos.z + radius}
        local beds = minetest.find_nodes_in_area(search_min, search_max, "group:bed")

        local cleared_beds = 0
        for _, bed_pos in ipairs(beds) do
            local bed_key = minetest.pos_to_string(bed_pos)
            if beds_with_villagers[bed_key] then
                beds_with_villagers[bed_key] = nil
                cleared_beds = cleared_beds + 1
            end
        end

        storage:set_string("beds_with_villagers", minetest.serialize(beds_with_villagers))

        return true, string.format(
            "Removed %d villagers and cleared %d bed tracking entries in %d block radius.",
            removed_count, cleared_beds, radius
        )
    end,
})

print(S("[MOD] Native Villages - Village management commands loaded"))

