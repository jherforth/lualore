-- desertbuildings.lua
-- Village palette for desert-like biomes.
-- The actual placement logic lives in systems/village_placement.lua;
-- this file only describes WHAT can be built here.

lualore = lualore or {}
lualore.village_palettes = lualore.village_palettes or {}

lualore.village_palettes.desert = {
	name = "desert",
	biomes = {"desert", "mesa", "everness:forsaken_desert"},
	surface = {"default:desert_sand", "default:sand"},
	offset = -6, -- schematic base is sunk 6 nodes into the ground (foundation)
	houses = {
		"deserthouse1.mts",
		"deserthouse2.mts",
		"deserthouse3.mts",
		"deserthouse4.mts",
	},
	church = "desertchurch.mts",
	market = "desertmarket.mts",
	stable = "desertstable.mts",
}




