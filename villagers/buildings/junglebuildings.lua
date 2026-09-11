-- junglebuildings.lua
-- Village palette for rainforest biomes (stilt treehouses).
-- The actual placement logic lives in systems/village_placement.lua;
-- this file only describes WHAT can be built here.

lualore = lualore or {}
lualore.village_palettes = lualore.village_palettes or {}

lualore.village_palettes.jungle = {
	name = "jungle",
	biomes = {
		"rainforest", "rainforest_swamp", "bamboo", "everness:bamboo_forest",
		"japaneseforest", "livingjungle:jungle",
	},
	surface = {
		"default:dirt_with_rainforest_litter",     -- rainforest
		"ethereal:bamboo_dirt",                    -- bamboo
		"everness:dirt_with_grass_1",              -- bamboo forest
		"japaneseforest:japanese_dirt_with_grass", -- japanese forest
		"livingjungle:jungleground",               -- living jungle
	},
	offset = 0, -- stilts are part of the schematics
	y_min = 4,
	y_max = 110,
	houses = {
		"junglehouse1.mts",
		"junglehouse2.mts",
		"junglehouse3.mts",
		"junglehouse4.mts",
	},
	church = "junglechurch.mts",
	market = "junglemarket.mts",
	stable = "junglestable.mts",
}


