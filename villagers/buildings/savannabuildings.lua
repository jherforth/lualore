-- savannabuildings.lua
-- Village palette for savanna biomes.
-- The actual placement logic lives in systems/village_placement.lua;
-- this file only describes WHAT can be built here.

lualore = lualore or {}
lualore.village_palettes = lualore.village_palettes or {}

lualore.village_palettes.savanna = {
	name = "savanna",
	biomes = {
		"savanna", "prarie", "prairie", "plains",
		"naturalbiomes:outback", "naturalbiomes:bushland",
	},
	surface = {
		"default:dry_dirt_with_dry_grass",        -- plains
		"prairie:prairie_dirt_with_grass",        -- prairie
		"naturalbiomes:savannalitter",            -- savanna
		"naturalbiomes:outback_litter",           -- outback
		"naturalbiomes:bushland_bushlandlitter",  -- bushland
	},
	offset = -6, -- schematic base is sunk 6 nodes into the ground (foundation)
	houses = {
		"savannahouse1.mts",
		"savannahouse2.mts",
		"savannahouse3.mts",
		"savannahouse4.mts",
	},
	church = "savannachurch.mts",
	market = "savannamarket.mts",
	stable = "savannastable.mts",
}




