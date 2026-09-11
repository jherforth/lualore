-- grasslandbuildings.lua
-- Village palette for the grassland biome.
-- The actual placement logic lives in systems/village_placement.lua;
-- this file only describes WHAT can be built here.

lualore = lualore or {}
lualore.village_palettes = lualore.village_palettes or {}

lualore.village_palettes.grassland = {
	name = "grassland",
	biomes = {
		"grassland", "grassytwo", "deciduous_forest", "coniferous_forest",
		"grove", "dorwinion", "naturalbiomes:mediterranean", "naturalbiomes:heath",
	},
	surface = {
		"default:dirt_with_grass",             -- grassland, grassytwo, deciduous
		"default:dirt_with_coniferous_litter", -- coniferous forest
		"ethereal:grove_dirt",                 -- grove
		"dorwinion:dorwinion_grass",           -- dorwinion
		"naturalbiomes:mediterran_litter",     -- mediterranean
		"naturalbiomes:heath_litter",          -- heath
	},
	offset = -6, -- schematic base is sunk 6 nodes into the ground (foundation)
	houses = {
		"grasslandhouse1.mts",
		"grasslandhouse2.mts",
		"grasslandhouse3.mts",
		"grasslandhouse4.mts",
	},
	church = "grasslandchurch.mts",
	market = "grasslandmarket.mts",
	stable = "grasslandstable.mts",
}






