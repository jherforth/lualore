-- lakebuildings.lua
-- Village palette for lake shores (stilt houses over the water).
-- The actual placement logic lives in systems/village_placement.lua;
-- this file only describes WHAT can be built here.

lualore = lualore or {}
lualore.village_palettes = lualore.village_palettes or {}

lualore.village_palettes.lake = {
	name = "lake",
	biomes = {
		"deciduous_forest_shore",
		"coniferous_forest_shore",
		"coniferous_forest_ocean",
		"deciduous_forest_ocean",
		"swamp_shore",
	},
	surface = {"default:dirt", "default:sand", "default:clay"},
	offset = 0,      -- stilts are part of the schematics
	water_ok = true, -- houses may stand in shallow water
	y_min = -2,
	y_max = 4,
	houses = {
		"lakehouse1.mts",
		"lakehouse2.mts",
		"lakehouse3.mts",
		"lakehouse4.mts",
	},
	church = "lakechurch.mts",
	market = "lakemarket.mts",
	stable = "lakestable.mts",
}



