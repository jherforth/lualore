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
	-- Ground dressing (villagers/systems/village_ground.lua): `accents` are
	-- noise patches over the levelled floor, weights are percent of the site.
	-- Plain default:dirt is avoided on purpose - minetest_game's grass ABM
	-- would green it over within minutes; see village_ground.lua.
	ground = {
		accents = {
			{"default:dirt_with_dry_grass", 9},
			{"default:gravel", 3, bare = true},
			{"default:dry_dirt_with_dry_grass", 3},
		},
		worn = "default:dirt_with_dry_grass", -- trampled turf along the walls
		path = "default:gravel",              -- trails to the village centre
	},
	plants = {
		density = 1.0,
		list = {
			{"default:grass_2", 7}, {"default:grass_3", 7},
			{"default:grass_4", 5}, {"default:grass_5", 4},
			{"default:grass_1", 3}, {"default:fern_1", 2},
			{"flowers:dandelion_yellow", 2}, {"flowers:dandelion_white", 1},
			{"flowers:geranium", 1}, {"flowers:rose", 1},
			{"flowers:tulip", 1}, {"flowers:viola", 1},
			{"flowers:mushroom_brown", 1},
		},
		bush = {stem = "default:bush_stem", leaves = "default:bush_leaves",
			chance = 0.014},
	},
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






