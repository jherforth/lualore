local S = minetest.get_translator("lualore")

lualore.floating_buildings = {}

local sky_fortress_noise = {
	offset = 0,
	scale = 0.0005,
	spread = {x = 600, y = 600, z = 600},
	seed = 98534,
	octaves = 3,
	persist = 0.6
}

local sky_house_noise = {
	offset = 0,
	scale = 0.0018,
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
		flags = "place_center_x, place_center_z, force_placement",

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
		flags = "place_center_x, place_center_z, force_placement",

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

-- Command to place valkyrie chests at nearest fortress
minetest.register_chatcommand("place_fortress_chests", {
	params = "",
	description = S("Place valkyrie chests at the nearest sky fortress"),
	privs = {give = true},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, S("Player not found")
		end

		local pos = player:get_pos()
		local search_min = vector.subtract(pos, {x=50, y=25, z=50})
		local search_max = vector.add(pos, {x=50, y=25, z=50})

		local torch_positions = minetest.find_nodes_in_area(
			search_min,
			search_max,
			{"everness:mineral_torch"}
		)

		if #torch_positions == 0 then
			return false, S("No fortress torches found nearby. Stand closer to a sky fortress.")
		end

		local chests_placed = 0

		for i, torch_pos in ipairs(torch_positions) do
			if chests_placed >= 4 then
				break
			end

			local chest_pos = {x = torch_pos.x, y = torch_pos.y, z = torch_pos.z}
			local node_at_pos = minetest.get_node(chest_pos)

			if node_at_pos.name == "everness:mineral_torch" then
				local below_node = minetest.get_node({x = chest_pos.x, y = chest_pos.y - 1, z = chest_pos.z})

				if below_node.name ~= "air" then
					minetest.set_node(chest_pos, {
						name = "lualore:valkyrie_chest",
						param2 = math.random(0, 3)
					})
					chests_placed = chests_placed + 1
				end
			end
		end

		return true, S("Placed @1 Valkyrie chests at fortress", chests_placed)
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
				local search_min = vector.subtract(fortress_pos, {x=40, y=20, z=40})
				local search_max = vector.add(fortress_pos, {x=40, y=20, z=40})

				local torch_positions = minetest.find_nodes_in_area(
					search_min,
					search_max,
					{"everness:mineral_torch"}
				)

				if #torch_positions > 0 then
					local chests_placed = 0

					minetest.log("action", "[lualore] Found " .. #torch_positions .. " torch positions for chest placement")

					for i, torch_pos in ipairs(torch_positions) do
						if chests_placed >= 4 then
							break
						end

						local chest_pos = {x = torch_pos.x, y = torch_pos.y, z = torch_pos.z}
						local node_at_pos = minetest.get_node(chest_pos)

						if node_at_pos.name == "everness:mineral_torch" then
							local below_node = minetest.get_node({x = chest_pos.x, y = chest_pos.y - 1, z = chest_pos.z})

							if below_node.name ~= "air" then
								minetest.set_node(chest_pos, {
									name = "lualore:valkyrie_chest",
									param2 = math.random(0, 3)
								})
								chests_placed = chests_placed + 1
								minetest.log("action", "[lualore] Placed Valkyrie chest at " ..
									minetest.pos_to_string(chest_pos))
							end
						end
					end

					minetest.log("action", "[lualore] Placed " .. chests_placed .. " Valkyrie chests at fortress")
				else
					minetest.log("warning", "[lualore] No torch positions found at fortress " ..
						minetest.pos_to_string(fortress_pos))
				end
			end
		end)
	end
end)

minetest.log("action", "[lualore] Floating buildings system loaded")
