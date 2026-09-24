-- house_spawning.lua
-- Bed-based villager linking — 1 villager per bed, universal and natural
-- Works with all villages regardless of biome

local S = minetest.get_translator("lualore")

-- Track which beds already have villagers (prevents duplicates)
local beds_with_villagers = {}

-- Which trades a village fills, and in what order.
--
-- Picking uniformly at random per bed left a six-house village with a
-- better than even chance of having no blacksmith, and nothing stopped
-- it rolling four farmers. A plain shuffled deck barely helped: with
-- twelve cards and six houses you still miss half the trades.
--
-- So the deck is dealt in tiers. The core trades come out first and are
-- shuffled among themselves, then the specialists, then filler. A
-- three-house hamlet therefore always has a farmer, a smith and a
-- cleric; a twelve-house village has one of everything; past that the
-- deck reshuffles and the common trades come round again.
local class_tiers = {
    {"farmer", "blacksmith", "cleric"},                  -- every village
    {"fisherman", "jeweler", "entertainer", "ranger"},   -- if there is room
    {"farmer", "bum", "farmer", "bum", "witch"},         -- filler
}

-- One deck per village, keyed by the village the bed belongs to.
local village_decks = {}

local function deck_key(bed_pos)
    if lualore.villages and lualore.villages.find_near then
        local _, key = lualore.villages.find_near(bed_pos, 90)
        if key then
            return key
        end
    end
    -- No village record (hand-built house, or an older world): group beds
    -- into 64-node cells so a cluster still shares one deck.
    return math.floor(bed_pos.x / 64) .. "," .. math.floor(bed_pos.z / 64)
end

local function build_deck()
    local deck = {}
    -- Build it back to front, because drawing takes from the end.
    for tier = #class_tiers, 1, -1 do
        local cards = {}
        for i, class in ipairs(class_tiers[tier]) do
            cards[i] = class
        end
        -- Fisher-Yates within the tier, so the order a village fills up
        -- is not the order the tier is written in.
        for i = #cards, 2, -1 do
            local j = math.random(i)
            cards[i], cards[j] = cards[j], cards[i]
        end
        for _, class in ipairs(cards) do
            deck[#deck + 1] = class
        end
    end
    return deck
end

-- Published so village_commands.lua's /populate_village fills a village
-- from the same deck rather than rolling its own uniform pick.
local function draw_class(bed_pos)
    local key = deck_key(bed_pos)
    local deck = village_decks[key]
    if not deck or #deck == 0 then
        deck = build_deck()
        village_decks[key] = deck
    end
    return table.remove(deck)
end

lualore.villager_deck = {draw = draw_class, tiers = class_tiers}

-- Marker node -> biome. Defined once in villagers/blocks/aliases.lua,
-- which also maps the legacy nativevillages: names the schematics store.
-- The copy that used to live here named three nodes that do not exist,
-- so biome detection always failed and every village spawned grassland
-- villagers.
local marker_to_biome = lualore.village_markers
local marker_list = lualore.village_marker_list

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
    minetest.after(8, function()  -- let village placement finish first (it can retry for a few seconds)
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

            -- Check for crystal forest biome - spawn sky folk instead of regular villagers
            local biome_data = minetest.get_biome_data(bed_pos)
            local is_crystal_forest = false
            if biome_data then
                local biome_name = minetest.get_biome_name(biome_data.biome)
                if biome_name and biome_name:match("crystal_forest") then
                    is_crystal_forest = true
                end
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

            -- For crystal forest biomes, spawn sky folk
            if is_crystal_forest then
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
                                    goto sky_folk_spawn_found
                                end
                            end
                        end
                    end
                end
                ::sky_folk_spawn_found::

                -- Fallback if no suitable outdoor position found
                if not spawn_pos then
                    spawn_pos = {x = bed_pos.x + 6, y = bed_pos.y, z = bed_pos.z}
                end

                -- Spawn the sky folk
                local obj = minetest.add_entity(spawn_pos, "lualore:sky_folk")
                if obj then
                    local luaent = obj:get_luaentity()
                    if luaent then
                        luaent.nv_house_pos = vector.new(bed_pos)
                        luaent.nv_home_radius = 20
                        -- Set spawn position for Sky Folk
                        luaent.nv_spawn_pos = vector.new(spawn_pos.x, spawn_pos.y, spawn_pos.z)
                    end
                    beds_with_villagers[bed_key] = true
                    processed_beds[bed_key] = true
                    minetest.log("action", "[lualore] Sky Folk spawned near bed at " ..
                        minetest.pos_to_string(spawn_pos) .. " linked to bed at " .. bed_key)
                end
                goto continue
            end

            -- Determine biome by looking for nearby markers (for regular villagers)
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
            local class = draw_class(bed_pos)
            local mob_name = "lualore:" .. biome .. "_" .. class

            local obj = minetest.add_entity(spawn_pos, mob_name)
            if obj then
                local luaent = obj:get_luaentity()
                if luaent then
                    luaent.nv_house_pos = vector.new(bed_pos)
                    luaent.nv_home_radius = 20
                    -- Set spawn position (separate from house/bed position)
                    luaent.nv_spawn_pos = vector.new(spawn_pos.x, spawn_pos.y, spawn_pos.z)
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
