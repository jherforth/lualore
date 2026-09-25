-- workstations.lua
-- ===================================================================
-- WORKSTATIONS - the three job sites no schematic provides
-- ===================================================================
-- Most classes work at something a village already contains: the
-- fisherman at his trap, the jeweler at a shelf, the entertainer at the
-- biome prop, the cleric at a bookshelf. Three have nothing to work at,
-- because no building schematic in this mod holds an anvil, an altar or
-- a scrap of farmland - not one of the 53 contains a single tilled
-- block. Those three nodes are defined here and placed into villages by
-- villagers/systems/village_workstations.lua.
--
-- They are all craftable too, so a player can set up a workstation
-- wherever they like and a villager whose bed is within twenty nodes
-- will adopt it.
-- ===================================================================

local S = minetest.get_translator("lualore")

-- ------------------------------------------------------------------
-- The blacksmith's anvil
-- ------------------------------------------------------------------
minetest.register_node("lualore:anvil", {
	description = S("Anvil"),
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	tiles = {
		"default_steel_block.png",
		"default_steel_block.png",
		"default_steel_block.png^[colorize:#000000:40",
	},
	groups = {cracky = 2, level = 2, lualore_workstation = 1},
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults and default.node_sound_metal_defaults()
		or default.node_sound_stone_defaults(),
	node_box = {
		type = "fixed",
		fixed = {
			{-0.4375, -0.5,     -0.3125, 0.4375, -0.3125, 0.3125}, -- base
			{-0.3125, -0.3125,  -0.1875, 0.3125, -0.1875, 0.1875}, -- step
			{-0.1875, -0.1875,  -0.125,  0.1875,  0.125,  0.125},  -- waist
			{-0.5,     0.125,   -0.25,   0.5,     0.375,  0.25},   -- face
		},
	},
	selection_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.3125, 0.5, 0.375, 0.3125},
	},
})

minetest.register_craft({
	output = "lualore:anvil",
	recipe = {
		{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
		{"",                    "default:steel_ingot", ""},
		{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
	},
})

-- ------------------------------------------------------------------
-- The cleric's altar
-- ------------------------------------------------------------------
minetest.register_node("lualore:village_altar", {
	description = S("Village Altar"),
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	tiles = {
		"default_stone_brick.png",
		"default_stone_brick.png",
		"default_stone_brick.png",
	},
	groups = {cracky = 2, lualore_workstation = 1},
	is_ground_content = false,
	light_source = 5,
	sounds = default.node_sound_stone_defaults(),
	node_box = {
		type = "fixed",
		fixed = {
			{-0.4375, -0.5,    -0.4375, 0.4375, -0.375, 0.4375}, -- footing
			{-0.3125, -0.375,  -0.3125, 0.3125,  0.1875, 0.3125}, -- plinth
			{-0.5,     0.1875, -0.5,    0.5,     0.375,  0.5},    -- table
		},
	},
	selection_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, 0.375, 0.5},
	},
})

minetest.register_craft({
	output = "lualore:village_altar",
	recipe = {
		{"default:stone_brick", "default:mese_crystal", "default:stone_brick"},
		{"default:stone_brick", "default:stone_brick",  "default:stone_brick"},
		{"default:stone_brick", "default:stone_brick",  "default:stone_brick"},
	},
})

-- ------------------------------------------------------------------
-- The farmer's field stake
-- ------------------------------------------------------------------
-- Marks a plot and remembers its bounds. The farmer works the area the
-- stake describes rather than guessing from its own position, so a plot
-- can be any size and the villager still knows where to stop. The
-- bounds live in node metadata as plot_minx / plot_minz / plot_maxx /
-- plot_maxz / plot_y, written by whoever lays the plot out.
--
-- A hand-placed stake describes nothing until it is given bounds, so it
-- defaults to the 5x5 centred on itself - which is what a player who
-- crafts one and plants a field around it would expect.
minetest.register_node("lualore:field_stake", {
	description = S("Field Stake"),
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	walkable = false,
	tiles = {"default_wood.png"},
	inventory_image = "default_stick.png^default_wood.png^[resize:16x16",
	groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2,
		lualore_workstation = 1},
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
	node_box = {
		type = "fixed",
		fixed = {
			{-0.0625, -0.5,   -0.0625, 0.0625, 0.5,    0.0625}, -- post
			{-0.3125,  0.1875, -0.0312, 0.3125, 0.3125, 0.0312}, -- crossbar
		},
	},
	selection_box = {
		type = "fixed",
		fixed = {-0.3125, -0.5, -0.125, 0.3125, 0.5, 0.125},
	},

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		if meta:get_int("plot_maxx") ~= 0 or meta:get_int("plot_minx") ~= 0 then
			return
		end
		meta:set_int("plot_minx", pos.x - 2)
		meta:set_int("plot_maxx", pos.x + 2)
		meta:set_int("plot_minz", pos.z - 2)
		meta:set_int("plot_maxz", pos.z + 2)
		meta:set_int("plot_y", pos.y - 1)
		if minetest.registered_nodes["farming:wheat_1"] then
			meta:set_string("plot_crop", "farming:wheat")
		end
		meta:set_string("infotext", S("Field"))
	end,
})

minetest.register_craft({
	output = "lualore:field_stake",
	recipe = {
		{"", "group:stick", ""},
		{"", "group:wood",  ""},
		{"", "group:stick", ""},
	},
})

-- Bounds helper, used by the farmer and the plot layout code.
lualore.field_plot = {}

function lualore.field_plot.bounds(pos)
	local meta = minetest.get_meta(pos)
	local minx = meta:get_int("plot_minx")
	local maxx = meta:get_int("plot_maxx")
	if minx == 0 and maxx == 0 then
		return nil
	end
	local crop = meta:get_string("plot_crop")
	return {
		minx = minx, maxx = maxx,
		minz = meta:get_int("plot_minz"), maxz = meta:get_int("plot_maxz"),
		y = meta:get_int("plot_y"),
		-- The crop this field is sown with, so the farmer knows what to
		-- put back after a harvest (his own or the player's).
		crop = (crop ~= "" and crop) or nil,
	}
end

function lualore.field_plot.set_bounds(pos, minx, minz, maxx, maxz, y, crop)
	local meta = minetest.get_meta(pos)
	meta:set_int("plot_minx", minx)
	meta:set_int("plot_maxx", maxx)
	meta:set_int("plot_minz", minz)
	meta:set_int("plot_maxz", maxz)
	meta:set_int("plot_y", y)
	if crop then
		meta:set_string("plot_crop", crop)
	end
	meta:set_string("infotext", S("Field"))
end
