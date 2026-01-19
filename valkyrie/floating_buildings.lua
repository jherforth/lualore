local S = minetest.get_translator("lualore")

lualore.floating_buildings = {}

local sky_fortress_noise = {
	offset = 0,
	scale = 0.0017,
	spread = {x = 600, y = 600, z = 600},
	seed = 98534,
	octaves = 3,
	persist = 0.6
}

local sky_house_noise = {
	offset = 0,
	scale = 0.0025,
	spread = {x = 720, y = 720, z = 720},
	seed = 73829,
	octaves = 3,
	persist = 0.5
}

local function register_sky_fortress(params)
	minetest.register_decoration({
		name = "lualore:" .. params.name,
		deco_type = "schematic",
		place_on = {"everness:dirt_with_crystal_grass"},
		sidelen = 100,
		noise_params = sky_fortress_noise,
		biomes = {"everness_crystal_forest"},
		y_min = 500,
		y_max = 31000,

		place_offset_y = -5,
		flags = "place_center_x, place_center_z, force_placement, all_floors",

		height = 0,
		height_max = 0,

		schematic = minetest.get_modpath("lualore") .. "/schematics/" .. params.file,
		rotation = "random",
	})
end

local function register_sky_house(params)
	minetest.register_decoration({
		name = "lualore:" .. params.name,
		deco_type = "schematic",
		place_on = {"everness:dirt_with_crystal_grass"},
		sidelen = 120,
		noise_params = sky_house_noise,
		biomes = {"everness_crystal_forest"},
		y_min = 500,
		y_max = 31000,

		place_offset_y = -5,
		flags = "place_center_x, place_center_z, force_placement, all_floors",

		height = 0,
		height_max = 0,

		schematic = minetest.get_modpath("lualore") .. "/schematics/" .. params.file,
		rotation = "random",
	})
end

register_sky_fortress({name = "skycastle", file = "skycastle.mts"})

register_sky_house({name = "skyhouse1", file = "skyhouse1.mts"})
register_sky_house({name = "skyhouse2", file = "skyhouse2.mts"})
register_sky_house({name = "skyhouse3", file = "skyhouse3.mts"})

-- Command to spawn valkyries at nearest fortress
minetest.register_chatcommand("spawn_fortress_valkyries", {
	params = "",
	description = S("Spawn valkyries at the nearest sky fortress"),
	privs = {give = true},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, S("Player not found")
		end

		local pos = player:get_pos()

		local valkyrie_types_list = {"blue", "violet", "gold", "green"}
		local num_valkyries = math.random(2, 5)
		local spawned = 0

		for i = 1, num_valkyries do
			local random_offset = {
				x = math.random(-15, 15),
				y = math.random(5, 15),
				z = math.random(-15, 15)
			}
			local spawn_pos = vector.add(pos, random_offset)
			local chosen_type = valkyrie_types_list[math.random(1, #valkyrie_types_list)]
			local mob_name = "lualore:" .. chosen_type .. "_valkyrie"

			local obj = minetest.add_entity(spawn_pos, mob_name)
			if obj then
				spawned = spawned + 1
			end
		end

		return true, S("Spawned @1 Valkyries near your position", spawned)
	end
})

minetest.register_on_generated(function(minp, maxp, blockseed)
	if minp.y < 500 then
		return
	end

	local spawn_chance = math.random(1, 100)
	if spawn_chance > 15 then
		return
	end

	local check_pos = {
		x = math.random(minp.x, maxp.x),
		y = math.random(minp.y, maxp.y),
		z = math.random(minp.z, maxp.z)
	}

	local area_min = vector.subtract(check_pos, {x=25, y=10, z=25})
	local area_max = vector.add(check_pos, {x=25, y=10, z=25})

	local crystal_grass_count = 0
	local crystal_grass_positions = {}

	for x = area_min.x, area_max.x do
		for y = area_min.y, area_max.y do
			for z = area_min.z, area_max.z do
				local pos = {x=x, y=y, z=z}
				local node = minetest.get_node_or_nil(pos)

				if node and (node.name == "everness:dirt_with_crystal_grass" or
				             node.name == "lualore:crystal_glass" or
				             node.name == "lualore:skystone") then
					crystal_grass_count = crystal_grass_count + 1
					table.insert(crystal_grass_positions, pos)
				end
			end
		end
	end

	if crystal_grass_count >= 50 and #crystal_grass_positions > 0 then
		local fortress_pos = crystal_grass_positions[1]
		local fortress_hash = minetest.hash_node_position(fortress_pos)

		minetest.log("action", "[lualore] Found fortress location at " .. minetest.pos_to_string(fortress_pos) ..
			" with " .. crystal_grass_count .. " crystal grass blocks")

		minetest.after(3, function()
			if lualore.sky_villages and lualore.sky_villages.spawn_sky_folk then
				local success = lualore.sky_villages.spawn_sky_folk(fortress_pos, fortress_hash)
				if success then
					minetest.log("action", "[lualore] Successfully spawned Sky Folk at fortress")
				else
					minetest.log("warning", "[lualore] Sky Folk already spawned or failed at fortress " .. fortress_hash)
				end
			end

			if lualore.sky_valkyries then
				local valkyrie_types_list = {"blue", "violet", "gold", "green"}
				local num_valkyries = math.random(2, 5)

				minetest.log("action", "[lualore] Spawning " .. num_valkyries .. " Valkyries at fortress")

				for i = 1, num_valkyries do
					local random_offset = {
						x = math.random(-15, 15),
						y = math.random(5, 15),
						z = math.random(-15, 15)
					}
					local spawn_pos = vector.add(fortress_pos, random_offset)
					local chosen_type = valkyrie_types_list[math.random(1, #valkyrie_types_list)]
					local mob_name = "lualore:" .. chosen_type .. "_valkyrie"

					local obj = minetest.add_entity(spawn_pos, mob_name)
					if obj then
						minetest.log("action", "[lualore] Spawned " .. chosen_type .. " Valkyrie at " ..
							minetest.pos_to_string(spawn_pos))
					else
						minetest.log("error", "[lualore] Failed to spawn " .. chosen_type .. " Valkyrie at " ..
							minetest.pos_to_string(spawn_pos))
					end
				end
			end
		end)
	end
end)

minetest.log("action", "[lualore] Floating buildings system loaded")
