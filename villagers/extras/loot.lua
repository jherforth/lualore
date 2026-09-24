-- loot.lua
-- Random loot for village chests (schematic-placed only)

local modpath = minetest.get_modpath("lualore")

-- ===================================================================
-- LOOT TABLES
-- ===================================================================

local loot_tables = {
    grassland = {
        {name = "farming:bread",          chance = 0.8, min = 1, max = 4},
        {name = "default:paper",          chance = 0.6, min = 1, max = 3},
        {name = "default:apple",          chance = 0.5, min = 1, max = 2},
        {name = "default:torch",          chance = 0.9, min = 3, max = 10},
        {name = "default:coal_lump",      chance = 0.4, min = 1, max = 3},
        {name = "x_farming:seed_beetroot",chance = 0.3, min = 1, max = 3},
    },
    desert = {
        {name = "default:gold_lump",      chance = 0.3, min = 1, max = 2},
        {name = "default:desert_stone",   chance = 0.7, min = 5, max = 15},
        {name = "default:cactus",         chance = 0.6, min = 1, max = 3},
        {name = "default:glass",          chance = 0.4, min = 1, max = 3},
        {name = "ethereal:bucket_cactus", chance = 0.2, min = 1, max = 1},
    },
    ice = {
        {name = "default:ice",            chance = 0.9, min = 3, max = 12},
        {name = "default:snowball",       chance = 0.8, min = 5, max = 16},
        {name = "default:coal_lump",      chance = 0.5, min = 1, max = 4},
        {name = "default:steel_ingot",    chance = 0.2, min = 1, max = 2},
        {name = "default:steel_axe",      chance = 0.2, min = 1, max = 1},
        {name = "default:flint",          chance = 0.4, min = 1, max = 2},
    },
    savanna = {
        {name = "default:acacia_wood",    chance = 0.7, min = 4, max = 10},
        {name = "default:dry_shrub",      chance = 0.6, min = 2, max = 6},
        {name = "default:bronze_ingot",   chance = 0.3, min = 1, max = 2},
        {name = "bonemeal:bone",          chance = 0.3, min = 1, max = 2},
        {name = "bonemeal:bonemeal",      chance = 0.3, min = 1, max = 10},
        {name = "x_farming:seed_pumpkin", chance = 0.6, min = 2, max = 6}
    },
    lake = {
        {name = "default:clay_lump",      chance = 0.8, min = 3, max = 8},
        {name = "default:papyrus",        chance = 0.7, min = 2, max = 7},
        {name = "farming:string",         chance = 0.5, min = 1, max = 3},
        {name = "everness:lotus_leaf_3",  chance = 0.5, min = 1, max = 3},
        {name = "x_farming:seed_carrot",  chance = 0.3, min = 1, max = 6},
    },
    jungle = {
        {name = "default:junglewood",     chance = 0.8, min = 5, max = 12},
        {name = "default:vine",           chance = 0.6, min = 2, max = 6},
        {name = "default:emerald",        chance = 0.15, min = 1, max = 1},
        {name = "default:obsidian",       chance = 0.1, min = 1, max = 2},
        {name = "default:steel_sword",    chance = 0.2, min = 1, max = 1},
    },
}

-- ===================================================================
-- Helper function to determine loot table from biome
-- ===================================================================

local function get_loot_table_for_biome(pos)
    local biome_data = minetest.get_biome_data(pos)
    if not biome_data then return nil end

    local biome_name = minetest.get_biome_name(biome_data.biome)
    if not biome_name then return nil end

    -- Substring matching so renamed/namespaced biomes still map (the full
    -- game biome list lives in the asuna_core biomes table).
    if biome_name:find("grass") or biome_name:find("deciduous")
            or biome_name:find("coniferous") or biome_name:find("grove")
            or biome_name:find("dorwinion") or biome_name:find("mediterran")
            or biome_name:find("heath") then
        return loot_tables.grassland
    elseif biome_name:find("desert") or biome_name:find("mesa")
            or biome_name:find("badland") then
        return loot_tables.desert
    elseif biome_name:find("icesheet") or biome_name:find("tundra")
            or biome_name:find("glacier") or biome_name:find("frost")
            or biome_name:find("permafrost") then
        return loot_tables.ice
    elseif biome_name:find("savanna") or biome_name:find("outback")
            or biome_name:find("prairie") or biome_name:find("prarie")
            or biome_name:find("plains") or biome_name:find("bushland") then
        return loot_tables.savanna
    elseif biome_name:find("rainforest") or biome_name:find("jungle")
            or biome_name:find("bamboo") or biome_name:find("japanese") then
        return loot_tables.jungle
    elseif biome_name:find("lake") or biome_name:find("shore")
            or biome_name:find("swamp") or biome_name:find("marsh")
            or biome_name:find("ocean") then
        return loot_tables.lake
    end

    return nil
end

-- ===================================================================
-- Helper function to fill a chest with loot
-- ===================================================================

local function fill_chest_with_loot(pos, loot_table)
    local meta = minetest.get_meta(pos)
    if not meta then return end

    local inv = meta:get_inventory()
    if not inv then return end

    local num_items = math.random(3, 7)
    local items_added = 0

    for i = 1, num_items do
        local item = loot_table[math.random(#loot_table)]
        if math.random() < item.chance then
            local count = item.min and math.random(item.min, item.max) or 1
            local stack = ItemStack(item.name .. " " .. count)

            local leftover = inv:add_item("main", stack)

            if leftover:is_empty() then
                items_added = items_added + 1
            else
                break
            end
        end
    end

    if items_added > 0 then
        minetest.log("action", "[lualore] Added " .. items_added .. " items to chest at " .. minetest.pos_to_string(pos))
    end
end

-- ===================================================================
-- LBM to initialize and fill schematic-placed chests
-- ===================================================================

minetest.register_lbm({
    name = "lualore:initialize_village_chests",
    nodenames = {"default:chest", "default:chest_locked"},
    run_at_every_load = false,
    action = function(pos, node)
        local chest_def = minetest.registered_nodes[node.name]
        if not chest_def then return end

        if chest_def.on_construct then
            chest_def.on_construct(pos)
        end

        local meta = minetest.get_meta(pos)
        if meta:get_string("lualore_loot_filled") == "true" then
            return
        end

        meta:set_string("lualore_loot_filled", "true")

        local loot_table = get_loot_table_for_biome(pos)
        if loot_table then
            minetest.after(0.1, function()
                fill_chest_with_loot(pos, loot_table)
            end)
        end
    end
})

-- ===================================================================
-- Fallback: Initialize chest on first interaction if LBM missed it
-- ===================================================================

local original_on_rightclick = {}

local function wrap_chest_rightclick(chest_name)
    local chest_def = minetest.registered_nodes[chest_name]
    if not chest_def then return end

    original_on_rightclick[chest_name] = chest_def.on_rightclick

    minetest.override_item(chest_name, {
        on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
            local meta = minetest.get_meta(pos)

            if not meta:get_string("formspec") or meta:get_string("formspec") == "" then
                if chest_def.on_construct then
                    chest_def.on_construct(pos)
                end

                if meta:get_string("lualore_loot_filled") ~= "true" then
                    meta:set_string("lualore_loot_filled", "true")

                    local loot_table = get_loot_table_for_biome(pos)
                    if loot_table then
                        fill_chest_with_loot(pos, loot_table)
                    end
                end
            end

            if original_on_rightclick[chest_name] then
                return original_on_rightclick[chest_name](pos, node, clicker, itemstack, pointed_thing)
            end
        end
    })
end

wrap_chest_rightclick("default:chest")
wrap_chest_rightclick("default:chest_locked")

-- ===================================================================
-- PUBLIC API
-- ===================================================================
-- Everything above was file-local, so nothing else could reward a
-- player with biome-appropriate treasure. The villager jobs - the
-- jeweler's appraisals in particular - want exactly these tables, so
-- they are published here rather than copied.
--
-- `roll` returns a list of {name, count} without touching an inventory,
-- which is what a reward panel needs; `fill_chest` is the existing
-- chest filler, unchanged.
lualore.loot = {
	tables = loot_tables,

	for_pos = function(pos)
		return get_loot_table_for_biome(pos)
	end,

	fill_chest = function(pos, loot_table)
		return fill_chest_with_loot(pos,
			loot_table or get_loot_table_for_biome(pos))
	end,

	roll = function(loot_table, picks)
		local out = {}
		if not loot_table or #loot_table == 0 then
			return out
		end
		for _ = 1, (picks or 1) do
			local entry = loot_table[math.random(#loot_table)]
			if entry and math.random() < (entry.chance or 1)
					and minetest.registered_items[entry.name] then
				local count = math.random(entry.min or 1, entry.max or 1)
				if count > 0 then
					out[#out + 1] = {name = entry.name, count = count}
				end
			end
		end
		return out
	end,
}

minetest.log("action", "[lualore] Loot system loaded - schematic chests will have treasure")
