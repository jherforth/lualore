-- icebuildings.lua
-- Village palette for ice sheet biomes.
-- The actual placement logic lives in systems/village_placement.lua;
-- this file only describes WHAT can be built here.

lualore = lualore or {}
lualore.village_palettes = lualore.village_palettes or {}

lualore.village_palettes.ice = {
	name = "ice",
	biomes = {"icesheet", "icesheet_ocean"},
	surface = {"default:snowblock", "default:ice"},
	offset = -6, -- schematic base is sunk 6 nodes into the ground (foundation)
	y_min = -1,
	y_max = 40,
	houses = {
		"icehouse1.mts",
		"icehouse2.mts",
		"icehouse3.mts",
		"icehouse4.mts",
	},
	church = "icechurch.mts",
	market = "icemarket.mts",
	stable = "icestable.mts",
}









