-- house_spawning.lua
-- Bed-based villager linking — 1 villager per bed, universal and natural
-- Works with all villages regardless of biome

local S = minetest.get_translator("lualore")

-- Track which beds already have villagers (prevents duplicates)
local beds_with_villagers = {}

-- Friendly villager classes (add/remove as you like)
local friendly_classes = {
    "farmer", "blacksmith", "fisherman", "cleric",
    "bum", "entertainer", "witch", "jeweler", "ranger"
}

-- Map every marker node to its biome (used to determine which villager type to spawn)
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

-- Build the full list of marker nodes for biome detection
local marker_list = {}
for node, _ in pairs(marker_to_biome) do
    table.insert(marker_list, node)
end

-- Save/load system
local storage = minetest.get_mod_storage()

local function load_beds()
    local data = storage:get_string("beds_with_villagers")
    if data and data ~= "" then
        beds_with_villagers = minetest.deserialize(data) or {}
    end
end

local save_timer = 0
minetest.register_globalstep(function(dtime)
    save_timer = save_timer + dtime
    if save_timer >= 60 then
        save_timer = 0
        storage:set_string("beds_with_villagers", minetest.serialize(beds_with_villagers))
    end
end)

load_beds()

-- Main villager spawning on chunk generation
minetest.register_on_generated(function(minp, maxp, blockseed)
    minetest.after(5, function()  -- Let schematics finish placing
        local ymin = math.max(minp.y, -10)
        local ymax = math.min(maxp.y, 80)
        local search_min = {x = minp.x, y = ymin, z = minp.z}
        local search_max = {x = maxp.x, y = ymax, z = maxp.z}

        -- Find all beds in the chunk
        local beds = minetest.find_nodes_in_area(search_min, search_max, "group:bed")
        local processed_beds = {}  -- Temporary table for this chunk
        local bed_pairs = {}  -- Track bed pairs to avoid duplicates

        for _, bed_pos in ipairs(beds) do
            local bed_key = minetest.pos_to_string(bed_pos)

            -- Skip if this bed already has a villager
            if beds_with_villagers[bed_key] or processed_beds[bed_key] then
                goto continue
            end

            -- Check if this is part of a bed pair and mark both halves
            -- Most beds have _top and _bottom or two connected parts
            local bed_node = minetest.get_node(bed_pos)
            local bed_pair_key = nil

            -- Try to find the other half of the bed (usually adjacent)
            for _, offset in ipairs({{x=1,y=0,z=0}, {x=-1,y=0,z=0}, {x=0,y=0,z=1}, {x=0,y=0,z=-1}}) do
                local check_pos = vector.add(bed_pos, offset)
                local check_node = minetest.get_node(check_pos)
                if minetest.get_item_group(check_node.name, "bed") > 0 then
                    -- Found the other half - create a unique pair key
                    local pos1, pos2 = bed_pos, check_pos
                    if pos1.x + pos1.y + pos1.z > pos2.x + pos2.y + pos2.z then
                        pos1, pos2 = pos2, pos1
                    end
                    bed_pair_key = minetest.pos_to_string(pos1) .. "|" .. minetest.pos_to_string(pos2)
                    break
                end
            end

            -- Skip if we've already processed this bed pair
            if bed_pair_key and bed_pairs[bed_pair_key] then
                goto continue
            end
            if bed_pair_key then
                bed_pairs[bed_pair_key] = true
            end

            -- 28% chance the bed is unoccupied (adds realism)
            if math.random() < 0.28 then
                processed_beds[bed_key] = true
                goto continue
            end

            -- Determine biome by looking for nearby markers
            local biome = nil
            local markers_nearby = minetest.find_nodes_in_area(
                {x = bed_pos.x - 30, y = bed_pos.y - 10, z = bed_pos.z - 30},
                {x = bed_pos.x + 30, y = bed_pos.y + 10, z = bed_pos.z + 30},
                marker_list
            )

            if #markers_nearby > 0 then
                local marker_node = minetest.get_node(markers_nearby[1]).name
                biome = marker_to_biome[marker_node]
            end

            -- Default to grassland if no marker found
            if not biome then
                biome = "grassland"
            end

            -- Find spawn position 6 blocks away from the bed (outside the house)
            local spawn_pos = nil

            -- Try to find a good spawn position in a 6-block radius
            for dx = -8, 8 do
                for dy = -1, 3 do
                    for dz = -8, 8 do
                        local dist = math.sqrt(dx*dx + dz*dz)
                        -- Only check positions that are roughly 6 blocks away (between 5 and 7)
                        if dist >= 5 and dist <= 7 then
                            local check = {
                                x = bed_pos.x + dx,
                                y = bed_pos.y + dy,
                                z = bed_pos.z + dz
                            }
                            local node = minetest.get_node(check)
                            local above = minetest.get_node({x=check.x, y=check.y+1, z=check.z})
                            local below = minetest.get_node({x=check.x, y=check.y-1, z=check.z})

                            -- Need air at position and above, and solid ground below
                            if node.name == "air" and above.name == "air" and
                               minetest.get_item_group(below.name, "solid") == 1 then
                                spawn_pos = check
                                goto spawn_found
                            end
                        end
                    end
                end
            end
            ::spawn_found::

            -- Fallback if no suitable outdoor position found
            if not spawn_pos then
                spawn_pos = {x = bed_pos.x + 6, y = bed_pos.y, z = bed_pos.z}
            end

            -- Spawn the villager
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
                minetest.log("action", "[lualore] Villager spawned near bed: " .. mob_name ..
                    " at " .. minetest.pos_to_string(spawn_pos) .. " linked to bed at " .. bed_key)
            end

            ::continue::
        end
    end)
end)

print(S("[MOD] LuaLore - Bed-based villager spawning loaded"))
