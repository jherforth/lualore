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
	-- Ground dressing (villagers/systems/village_ground.lua)
	ground = {
		accents = {
			{"default:dirt_with_dry_grass", 7},
			{"default:sand", 4, bare = true},
			{"default:gravel", 3, bare = true},
		},
		worn = "default:sand",     -- dusty yards
		path = "default:gravel",
	},
	plants = {
		density = 0.8,
		list = {
			{"default:dry_grass_2", 8}, {"default:dry_grass_3", 7},
			{"default:dry_grass_4", 5}, {"default:dry_grass_5", 4},
			{"default:dry_grass_1", 3}, {"default:dry_shrub", 3},
			{"flowers:dandelion_yellow", 1},
		},
	},
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




