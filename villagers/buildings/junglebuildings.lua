-- junglebuildings.lua
-- Village palette for rainforest biomes (stilt treehouses).
-- The actual placement logic lives in systems/village_placement.lua;
-- this file only describes WHAT can be built here.

lualore = lualore or {}
lualore.village_palettes = lualore.village_palettes or {}

lualore.village_palettes.jungle = {
	name = "jungle",
	biomes = {"rainforest", "rainforest_swamp"},
	surface = {"default:dirt_with_rainforest_litter"},
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


