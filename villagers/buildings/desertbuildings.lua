-- desertbuildings.lua
-- Village palette for desert-like biomes.
-- The actual placement logic lives in systems/village_placement.lua;
-- this file only describes WHAT can be built here.

lualore = lualore or {}
lualore.village_palettes = lualore.village_palettes or {}

lualore.village_palettes.desert = {
	name = "desert",
	biomes = {"desert", "mesa", "sandstone_desert", "badland", "everness:forsaken_desert"},
	surface = {
		"default:desert_sand", "default:sand",
		"default:dirt_with_dry_grass",        -- mesa
		"badland:badland_grass",             -- badland
		"everness:forsaken_desert_sand",     -- forsaken desert
	},
	offset = -6, -- schematic base is sunk 6 nodes into the ground (foundation)
	-- Ground dressing (villagers/systems/village_ground.lua): sand drifts
	-- and gravel flats instead of greenery.
	ground = {
		accents = {
			{"default:sand", 9},
			{"default:gravel", 4, bare = true},
			{"default:desert_sandstone", 2, bare = true},
		},
		worn = "default:sand",
		path = "default:desert_sandstone", -- a flagged track through the dunes
	},
	plants = {
		density = 0.35, -- a desert village is meant to look dry
		list = {
			{"default:dry_shrub", 10},
			{"default:cactus", 1},
		},
	},
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




