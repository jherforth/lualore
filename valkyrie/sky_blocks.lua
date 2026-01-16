local S = minetest.get_translator("lualore")

lualore.sky_wings = {}

local active_wings = {}

local wing_types = {
	green = {
		description = "Green Valkyrie Wings",
		texture = "green_valkyrie_wings.png",
		flight_time = 30,
		speed_mult = 1.1,
		color = "#00FF00",
		lift_power = 0.8
	},
	blue = {
		description = "Blue Valkyrie Wings",
		texture = "blue_valkyrie_wings.png",
		flight_time = 45,
		speed_mult = 1.2,
		color = "#00FFFF",
		lift_power = 1.0
	},
	violet = {
		description = "Violet Valkyrie Wings",
		texture = "violet_valkyrie_wings.png",
		flight_time = 45,
		speed_mult = 1.35,
		color = "#9000FF",
		lift_power = 1.2
	},
	gold = {
		description = "Gold Valkyrie Wings",
		texture = "gold_valkyrie_wings.png",
		flight_time = 60,
		speed_mult = 1.5,
		color = "#FFD700",
		lift_power = 1.5
	}
}

local function attach_wings(player, wing_type)
	if not player or not player:is_player() then return end

	local player_name = player:get_player_name()
	local wing_data = wing_types[wing_type]
	if not wing_data then return end

	local pos = player:get_pos()
	local wing_entity = minetest.add_entity(pos, "lualore:wing_visual")

	if wing_entity then
		wing_entity:set_attach(
			player,
			"",
			{x=0, y=5, z=-2},
			{x=0, y=0, z=0}
		)

		wing_entity:get_luaentity().wing_type = wing_type
		wing_entity:set_properties({
			textures = {wing_data.texture}
		})

		return wing_entity
	end
end

local function remove_wings(player)
	if not player or not player:is_player() then return end

	local pos = player:get_pos()
	local objects = minetest.get_objects_inside_radius(pos, 2)

	for _, obj in ipairs(objects) do
		local ent = obj:get_luaentity()
		if ent and ent.name == "lualore:wing_visual" then
			obj:remove()
		end
	end
end

local function activate_wings(player, wing_type)
	if not player or not player:is_player() then return end

	local player_name = player:get_player_name()
	local wing_data = wing_types[wing_type]

	if not wing_data then return end

	if active_wings[player_name] then
		minetest.chat_send_player(player_name, S("Wings already active!"))
		return
	end

	local wing_entity = attach_wings(player, wing_type)

	active_wings[player_name] = {
		wing_type = wing_type,
		timer = 0,
		flight_time = wing_data.flight_time,
		wing_entity = wing_entity,
		was_flying = false
	}

	minetest.chat_send_player(player_name, S("Wings equipped! Use jump to fly up, sneak to descend. Duration: @1s", wing_data.flight_time))
end

local function deactivate_wings(player, player_name)
	if not active_wings[player_name] then return end

	if player and player:is_player() then
		remove_wings(player)

		player:set_bone_position("Body", {x=0, y=6.3, z=0}, {x=0, y=0, z=0})
		player:set_bone_position("Head", {x=0, y=6.3, z=0}, {x=0, y=0, z=0})
	end

	active_wings[player_name] = nil

	if player and player:is_player() then
		minetest.chat_send_player(player_name, S("Wings have expired!"))
	end
end

for wing_type, wing_data in pairs(wing_types) do
	minetest.register_craftitem("lualore:" .. wing_type .. "_wings", {
		description = S(wing_data.description),
		inventory_image = wing_data.texture,
		stack_max = 1,
		on_use = function(itemstack, user, pointed_thing)
			if not user or not user:is_player() then return end

			activate_wings(user, wing_type)
			itemstack:take_item()
			return itemstack
		end
	})
end

minetest.register_entity("lualore:wing_visual", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		visual = "mesh",
		mesh = "character.b3d",
		textures = {"green_valkyrie_wings.png"},
		visual_size = {x=1, y=1},
		static_save = false,
	},

	wing_type = "green",

	on_activate = function(self, staticdata)
		self.object:set_armor_groups({immortal = 1})
	end,

	on_step = function(self, dtime)
		local parent = self.object:get_attach()
		if not parent then
			self.object:remove()
			return
		end
	end,
})

minetest.register_globalstep(function(dtime)
	for player_name, wing_data in pairs(active_wings) do
		local player = minetest.get_player_by_name(player_name)

		if not player then
			active_wings[player_name] = nil
		else
			wing_data.timer = wing_data.timer + dtime

			if wing_data.timer >= wing_data.flight_time then
				deactivate_wings(player, player_name)
			else
				local remaining = wing_data.flight_time - wing_data.timer

				if math.floor(remaining) == 10 and math.floor(remaining * 10) % 10 == 0 then
					minetest.chat_send_player(player_name, S("Wings expire in @1 seconds!", math.floor(remaining)))
				end

				local wing_info = wing_types[wing_data.wing_type]
				local vel = player:get_velocity()
				local ctrl = player:get_player_control()
				local player_pos = player:get_pos()

				local is_moving = vel and (math.abs(vel.x) > 0.3 or math.abs(vel.z) > 0.3 or math.abs(vel.y) > 0.5)

				if is_moving then
					if not wing_data.was_flying then
						wing_data.was_flying = true
					end

					player:set_bone_position("Body", {x=0, y=6.3, z=0}, {x=90, y=0, z=0})
					player:set_bone_position("Head", {x=0, y=6.3, z=0}, {x=-90, y=0, z=0})

					if ctrl.jump then
						player:add_velocity({x=0, y=wing_info.lift_power, z=0})
					elseif ctrl.sneak then
						if vel.y > -5 then
							player:add_velocity({x=0, y=-0.5, z=0})
						end
					else
						if vel.y < -1 then
							local drag = vector.multiply(vel, {x=0, y=0.3, z=0})
							player:add_velocity(drag)
						end
					end

					local look_dir = player:get_look_dir()
					if ctrl.up or ctrl.down or ctrl.left or ctrl.right then
						local move_dir = vector.multiply(look_dir, wing_info.speed_mult * 0.5)
						move_dir.y = 0
						player:add_velocity(move_dir)
					end

					minetest.add_particlespawner({
						amount = 3,
						time = 0.1,
						minpos = vector.subtract(player_pos, {x=0.5, y=0, z=0.5}),
						maxpos = vector.add(player_pos, {x=0.5, y=0.5, z=0.5}),
						minvel = {x=-1, y=-1, z=-1},
						maxvel = {x=1, y=0, z=1},
						minacc = {x=0, y=-0.3, z=0},
						maxacc = {x=0, y=-0.3, z=0},
						minexptime = 0.3,
						maxexptime = 0.8,
						minsize = 1.5,
						maxsize = 2.5,
						texture = "lualore_particle_star.png^[colorize:" .. wing_info.color .. ":200",
						glow = 10
					})
				else
					if wing_data.was_flying then
						player:set_bone_position("Body", {x=0, y=6.3, z=0}, {x=0, y=0, z=0})
						player:set_bone_position("Head", {x=0, y=6.3, z=0}, {x=0, y=0, z=0})
						wing_data.was_flying = false
					end
				end
			end
		end
	end
end)

minetest.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
	deactivate_wings(player, player_name)
end)

minetest.register_on_dieplayer(function(player)
	local player_name = player:get_player_name()
	deactivate_wings(player, player_name)
end)

minetest.log("action", "[lualore] Sky wings system loaded")
