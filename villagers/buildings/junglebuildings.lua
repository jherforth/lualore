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
	-- Ground dressing (villagers/systems/village_ground.lua): damp litter,
	-- mud and a floor that grows back over everything.
	ground = {
		accents = {
			{"default:dirt_with_grass", 8},
			{"default:dirt_with_coniferous_litter", 4},
			{"default:gravel", 3, bare = true},
		},
		worn = "default:dirt_with_grass",
		path = "default:gravel",
	},
	plants = {
		density = 1.25, -- the rainforest reclaims the village floor
		list = {
			{"default:junglegrass", 9}, {"default:grass_3", 5},
			{"default:grass_4", 5}, {"default:grass_5", 4},
			{"default:fern_2", 3}, {"default:fern_3", 3},
			{"flowers:mushroom_brown", 2}, {"flowers:mushroom_red", 1},
		},
		bush = {stem = "default:bush_stem", leaves = "default:jungleleaves",
			chance = 0.02},
	},
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


