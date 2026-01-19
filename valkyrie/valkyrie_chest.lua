local S = minetest.get_translator("lualore")

minetest.register_node("lualore:valkyrie_chest", {
	description = S("Valkyrie Chest"),
	tiles = {
		"lualore_chest_top.png",
		"lualore_chest_top.png",
		"lualore_chest_side.png",
		"lualore_chest_side.png",
		"lualore_chest_side.png",
		"lualore_chest_front.png"
	},
	paramtype2 = "facedir",
	groups = {cracky = 2, oddly_breakable_by_hand = 2},
	is_ground_content = false,
	sounds = minetest.global_exists("default") and default.node_sound_wood_defaults(),
	light_source = 5,

	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		if not clicker or not clicker:is_player() then
			return itemstack
		end

		local meta = minetest.get_meta(pos)
		local opened = meta:get_int("opened")

		if opened == 1 then
			minetest.chat_send_player(clicker:get_player_name(), S("This chest has already been opened."))
			return itemstack
		end

		meta:set_int("opened", 1)

		minetest.swap_node(pos, {
			name = "lualore:valkyrie_chest_opened",
			param2 = node.param2
		})

		local valkyrie_types = {"blue", "violet", "gold", "green"}
		local spawn_offsets = {
			{x = 2, y = 1, z = 0},
			{x = -2, y = 1, z = 0},
			{x = 0, y = 1, z = 2},
			{x = 0, y = 1, z = -2}
		}

		for i = 1, 4 do
			minetest.after(i * 0.3, function()
				local spawn_pos = vector.add(pos, spawn_offsets[i])
				local node_at_spawn = minetest.get_node(spawn_pos)

				if node_at_spawn.name == "air" or minetest.get_item_group(node_at_spawn.name, "liquid") > 0 then
					local chosen_type = valkyrie_types[i]
					local mob_name = "lualore:" .. chosen_type .. "_valkyrie"

					local obj = minetest.add_entity(spawn_pos, mob_name)
					if obj then
						minetest.add_particlespawner({
							amount = 30,
							time = 1,
							minpos = vector.subtract(spawn_pos, {x=0.5, y=0.5, z=0.5}),
							maxpos = vector.add(spawn_pos, {x=0.5, y=0.5, z=0.5}),
							minvel = {x=-1, y=0, z=-1},
							maxvel = {x=1, y=2, z=1},
							minacc = {x=0, y=-2, z=0},
							maxacc = {x=0, y=-2, z=0},
							minexptime = 0.5,
							maxexptime = 1.5,
							minsize = 1,
							maxsize = 3,
							texture = "lualore_particle_star.png",
							glow = 14,
						})

						minetest.log("action", "[lualore] Valkyrie chest spawned " .. chosen_type .. " valkyrie at " ..
							minetest.pos_to_string(spawn_pos))
					end
				end
			end)
		end

		minetest.after(1.5, function()
			if clicker and clicker:is_player() then
				minetest.chat_send_player(clicker:get_player_name(),
					S("The Valkyrie Chest has been opened!"))
			end
		end)

		minetest.sound_play("magic", {
			pos = pos,
			gain = 1.0,
			max_hear_distance = 32,
		}, true)

		return itemstack
	end,
})

minetest.register_node("lualore:valkyrie_chest_opened", {
	description = S("Opened Valkyrie Chest"),
	tiles = {
		"lualore_chest_inside.png",
		"lualore_chest_top.png",
		"lualore_chest_side.png",
		"lualore_chest_side.png",
		"lualore_chest_side.png",
		"lualore_chest_front.png"
	},
	paramtype2 = "facedir",
	groups = {cracky = 2, oddly_breakable_by_hand = 2, not_in_creative_inventory = 1},
	is_ground_content = false,
	sounds = minetest.global_exists("default") and default.node_sound_wood_defaults(),
	drop = "",
	light_source = 3,

	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		if clicker and clicker:is_player() then
			minetest.chat_send_player(clicker:get_player_name(), S("This chest has already been opened."))
		end
		return itemstack
	end,
})

minetest.log("action", "[lualore] Valkyrie chest system loaded")
