local S = minetest.get_translator("lualore")

lualore.valkyrie_strikes = {}

local player_effects = {}

local function add_effect(player_name, effect_type, duration, data)
	if not player_effects[player_name] then
		player_effects[player_name] = {}
	end

	player_effects[player_name][effect_type] = {
		duration = duration,
		timer = 0,
		data = data or {}
	}
end

local function remove_effect(player_name, effect_type)
	if player_effects[player_name] then
		player_effects[player_name][effect_type] = nil
	end
end

local function has_effect(player_name, effect_type)
	return player_effects[player_name] and player_effects[player_name][effect_type]
end

local strike_1_wind_dash = function(self, player)
	if not player or not player:is_player() then return end

	local player_name = player:get_player_name()
	local player_pos = player:get_pos()
	local self_pos = self.object:get_pos()

	local dir = vector.direction(self_pos, player_pos)
	local knockback = vector.multiply(dir, 15)
	knockback.y = knockback.y + 3

	player:add_velocity(knockback)
	player:set_hp(player:get_hp() - math.random(4, 8))

	minetest.add_particlespawner({
		amount = 50,
		time = 1,
		minpos = vector.subtract(player_pos, {x=0.5, y=0.5, z=0.5}),
		maxpos = vector.add(player_pos, {x=0.5, y=0.5, z=0.5}),
		minvel = {x=-2, y=-2, z=-2},
		maxvel = {x=2, y=2, z=2},
		minacc = {x=0, y=0, z=0},
		maxacc = {x=0, y=0, z=0},
		minexptime = 0.5,
		maxexptime = 1.5,
		minsize = 1,
		maxsize = 3,
		texture = "lualore_particle_circle.png^[colorize:#9000FF:200",
		glow = 8
	})

	minetest.sound_play("magic", {
		pos = player_pos,
		gain = 0.5,
		max_hear_distance = 16
	})
end

local strike_2_tempest_spin = function(self, player)
	if not player or not player:is_player() then return end

	local player_name = player:get_player_name()
	local player_pos = player:get_pos()

	add_effect(player_name, "tempest_spin", 5, {})

	minetest.add_particlespawner({
		amount = 100,
		time = 5,
		minpos = vector.subtract(player_pos, {x=1, y=0, z=1}),
		maxpos = vector.add(player_pos, {x=1, y=2, z=1}),
		minvel = {x=-3, y=0.5, z=-3},
		maxvel = {x=3, y=1.5, z=3},
		minacc = {x=0, y=0, z=0},
		maxacc = {x=0, y=0, z=0},
		minexptime = 0.5,
		maxexptime = 1.5,
		minsize = 2,
		maxsize = 4,
		texture = "lualore_particle_star.png^[colorize:#FF0000:200",
		glow = 10
	})

	minetest.sound_play("magic", {
		pos = player_pos,
		gain = 0.5,
		max_hear_distance = 16
	})
end

local strike_3_frost_bind = function(self, player)
	if not player or not player:is_player() then return end

	local player_name = player:get_player_name()
	local player_pos = player:get_pos()

	add_effect(player_name, "frost_bind", 15, {
		next_freeze = 3,
		freeze_timer = 0
	})

	minetest.add_particlespawner({
		amount = 50,
		time = 15,
		minpos = vector.subtract(player_pos, {x=0.5, y=0, z=0.5}),
		maxpos = vector.add(player_pos, {x=0.5, y=1.5, z=0.5}),
		minvel = {x=-1, y=0, z=-1},
		maxvel = {x=1, y=2, z=1},
		minacc = {x=0, y=-0.5, z=0},
		maxacc = {x=0, y=-0.5, z=0},
		minexptime = 1,
		maxexptime = 2,
		minsize = 1.5,
		maxsize = 3,
		texture = "lualore_particle_star.png^[colorize:#00FF00:200",
		glow = 8
	})

	minetest.sound_play("magic", {
		pos = player_pos,
		gain = 0.5,
		max_hear_distance = 16
	})
end

local strike_4_sky_surge = function(self, player)
	if not player or not player:is_player() then return end

	local player_name = player:get_player_name()
	local player_pos = player:get_pos()

	add_effect(player_name, "sky_surge", 15, {})

	minetest.add_particlespawner({
		amount = 100,
		time = 15,
		minpos = vector.subtract(player_pos, {x=0.5, y=0, z=0.5}),
		maxpos = vector.add(player_pos, {x=0.5, y=0.5, z=0.5}),
		minvel = {x=-2, y=-1, z=-2},
		maxvel = {x=2, y=0, z=2},
		minacc = {x=0, y=0, z=0},
		maxacc = {x=0, y=0, z=0},
		minexptime = 0.3,
		maxexptime = 0.8,
		minsize = 1,
		maxsize = 2,
		texture = "lualore_particle_circle.png^[colorize:#FFFFFF:180",
		glow = 12
	})

	minetest.sound_play("magic", {
		pos = player_pos,
		gain = 0.5,
		max_hear_distance = 16
	})
end

local strike_5_thunder_lift = function(self, player)
	if not player or not player:is_player() then return end

	local player_name = player:get_player_name()
	local player_pos = player:get_pos()

	add_effect(player_name, "thunder_lift", 3, {})

	player:add_velocity({x=0, y=15, z=0})

	minetest.add_particlespawner({
		amount = 80,
		time = 3,
		minpos = vector.subtract(player_pos, {x=0.5, y=0, z=0.5}),
		maxpos = vector.add(player_pos, {x=0.5, y=3, z=0.5}),
		minvel = {x=-0.5, y=2, z=-0.5},
		maxvel = {x=0.5, y=5, z=0.5},
		minacc = {x=0, y=1, z=0},
		maxacc = {x=0, y=2, z=0},
		minexptime = 0.5,
		maxexptime = 1.5,
		minsize = 2,
		maxsize = 4,
		texture = "lualore_particle_arrow_up.png^[colorize:#00FFFF:200",
		glow = 14
	})

	minetest.sound_play("magic", {
		pos = player_pos,
		gain = 0.5,
		max_hear_distance = 16
	})
end

local strike_6_storm_compress = function(self, player)
	if not player or not player:is_player() then return end

	local player_name = player:get_player_name()
	local player_pos = player:get_pos()

	add_effect(player_name, "storm_compress", 15, {})

	minetest.add_particlespawner({
		amount = 120,
		time = 15,
		minpos = vector.subtract(player_pos, {x=1, y=0, z=1}),
		maxpos = vector.add(player_pos, {x=1, y=2, z=1}),
		minvel = {x=-1, y=0, z=-1},
		maxvel = {x=1, y=1, z=1},
		minacc = {x=0, y=0, z=0},
		maxacc = {x=0, y=0, z=0},
		minexptime = 1,
		maxexptime = 2,
		minsize = 2,
		maxsize = 4,
		texture = "lualore_particle_blob.png^[colorize:#FFFF00:200",
		glow = 10
	})

	minetest.sound_play("magic", {
		pos = player_pos,
		gain = 0.5,
		max_hear_distance = 16
	})
end

local strike_7_shadow_veil = function(self, player)
	if not player or not player:is_player() then return end

	local player_name = player:get_player_name()
	local player_pos = player:get_pos()

	add_effect(player_name, "shadow_veil", 10, {})

	minetest.add_particlespawner({
		amount = 200,
		time = 10,
		minpos = vector.subtract(player_pos, {x=2, y=1, z=2}),
		maxpos = vector.add(player_pos, {x=2, y=2, z=2}),
		minvel = {x=-2, y=-1, z=-2},
		maxvel = {x=2, y=1, z=2},
		minacc = {x=0, y=0, z=0},
		maxacc = {x=0, y=0, z=0},
		minexptime = 1,
		maxexptime = 2.5,
		minsize = 3,
		maxsize = 6,
		texture = "lualore_particle_blob.png^[colorize:#000000:240",
		glow = 0
	})

	minetest.sound_play("magic", {
		pos = player_pos,
		gain = 0.5,
		max_hear_distance = 16
	})
end

lualore.valkyrie_strikes.all_strikes = {
	strike_1_wind_dash,
	strike_2_tempest_spin,
	strike_3_frost_bind,
	strike_4_sky_surge,
	strike_5_thunder_lift,
	strike_6_storm_compress,
	strike_7_shadow_veil
}

function lualore.valkyrie_strikes.assign_random_strikes()
	local strikes = {}
	local available = {1, 2, 3, 4, 5, 6, 7}
	local selected_indices = {}

	for i = 1, 2 do
		local idx = math.random(1, #available)
		local strike_num = available[idx]
		table.insert(selected_indices, strike_num)
		table.insert(strikes, lualore.valkyrie_strikes.all_strikes[strike_num])
		table.remove(available, idx)
	end

	minetest.log("action", "[lualore] Assigned strikes: " .. selected_indices[1] .. " and " .. selected_indices[2])

	for i, strike in ipairs(strikes) do
		if type(strike) ~= "function" then
			minetest.log("error", "[lualore] Strike " .. i .. " is not a function! Type: " .. type(strike))
		end
	end

	return strikes
end

function lualore.valkyrie_strikes.use_strike(self, strike_func, player)
	if not self.strike_cooldown then
		self.strike_cooldown = {}
	end

	local current_time = minetest.get_us_time() / 1000000
	local last_strike = self.strike_cooldown[strike_func] or 0

	if current_time - last_strike >= 2.5 then
		strike_func(self, player)
		self.strike_cooldown[strike_func] = current_time
		return true
	end

	return false
end

local update_timer = 0
minetest.register_globalstep(function(dtime)
	update_timer = update_timer + dtime

	if update_timer < 0.1 then
		return
	end

	update_timer = 0

	for player_name, effects in pairs(player_effects) do
		local player = minetest.get_player_by_name(player_name)

		if not player then
			player_effects[player_name] = nil
		else
			local player_pos = player:get_pos()

			for effect_type, effect_data in pairs(effects) do
				effect_data.timer = effect_data.timer + 0.1

				if effect_data.timer >= effect_data.duration then
					if effect_type == "tempest_spin" then
						local physics = player:get_physics_override()
						physics.speed = 1.0
						player:set_physics_override(physics)
					elseif effect_type == "frost_bind" then
						local physics = player:get_physics_override()
						physics.speed = 1.0
						player:set_physics_override(physics)
					elseif effect_type == "sky_surge" then
						local physics = player:get_physics_override()
						physics.speed = 1.0
						physics.jump = 1.0
						player:set_physics_override(physics)
					elseif effect_type == "storm_compress" then
						local physics = player:get_physics_override()
						physics.speed = 1.0
						physics.jump = 1.0
						player:set_physics_override(physics)
						player:set_properties({
							visual_size = {x=1, y=1}
						})
						player:override_day_night_ratio(nil)

						minetest.add_particlespawner({
							amount = 30,
							time = 0.5,
							minpos = vector.subtract(player_pos, {x=0.5, y=0, z=0.5}),
							maxpos = vector.add(player_pos, {x=0.5, y=2, z=0.5}),
							minvel = {x=-1, y=0, z=-1},
							maxvel = {x=1, y=2, z=1},
							minacc = {x=0, y=0, z=0},
							maxacc = {x=0, y=0, z=0},
							minexptime = 0.3,
							maxexptime = 0.8,
							minsize = 1,
							maxsize = 2,
							texture = "lualore_particle_star.png^[colorize:#FFD700:200",
							glow = 12
						})
					elseif effect_type == "shadow_veil" then
						player:override_day_night_ratio(nil)
					end

					remove_effect(player_name, effect_type)
				else
					if effect_type == "tempest_spin" then
						local controls = player:get_player_control()
						local physics = player:get_physics_override()

						if math.floor(effect_data.timer * 10) % 2 == 0 then
							physics.speed = -1.5
						else
							physics.speed = 1.0
						end
						player:set_physics_override(physics)

					elseif effect_type == "frost_bind" then
						effect_data.data.freeze_timer = effect_data.data.freeze_timer + 0.1

						if effect_data.data.freeze_timer >= effect_data.data.next_freeze then
							local physics = player:get_physics_override()
							physics.speed = 0
							player:set_physics_override(physics)

							player:set_hp(player:get_hp() - 0.5)

							minetest.add_particlespawner({
								amount = 20,
								time = 0.5,
								minpos = vector.subtract(player_pos, {x=0.3, y=0, z=0.3}),
								maxpos = vector.add(player_pos, {x=0.3, y=1.5, z=0.3}),
								minvel = {x=-0.5, y=0, z=-0.5},
								maxvel = {x=0.5, y=1, z=0.5},
								minacc = {x=0, y=-0.5, z=0},
								maxacc = {x=0, y=-0.5, z=0},
								minexptime = 0.5,
								maxexptime = 1,
								minsize = 2,
								maxsize = 3,
								texture = "lualore_particle_star.png^[colorize:#00FF00:220",
								glow = 10
							})

							minetest.after(1, function()
								if player and player:is_player() then
									local physics = player:get_physics_override()
									physics.speed = 1.0
									player:set_physics_override(physics)
								end
							end)

							effect_data.data.freeze_timer = 0
							effect_data.data.next_freeze = math.random(3, 5)
						end

					elseif effect_type == "sky_surge" then
						local physics = player:get_physics_override()
						physics.speed = 3.0
						physics.jump = 1.5
						player:set_physics_override(physics)

					elseif effect_type == "storm_compress" then
						local physics = player:get_physics_override()
						physics.speed = 0.5
						physics.jump = 0.7
						player:set_physics_override(physics)

						player:set_properties({
							visual_size = {x=0.5, y=0.5}
						})

						player:override_day_night_ratio(0.5)

					elseif effect_type == "shadow_veil" then
						player:override_day_night_ratio(0.15)
					end
				end
			end
		end
	end
end)

minetest.log("action", "[lualore] Valkyrie strike system loaded")
