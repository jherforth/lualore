-- wizard_wands.lua
-- Wands for the wizards
-- Wand colors align with wizard colors and are dropped on defeat for the player to use.

local S = minetest.get_translator("lualore")

-- Track NPC effects to prevent stacking
local npc_effects = {}

--------------------------------------------------------------------
-- PARTICLE HELPER FUNCTIONS
--------------------------------------------------------------------

local function spawn_spell_projectile(start_pos, target_pos, color)
	minetest.add_particlespawner({
		amount = 100,
		time = 0.5,
		minpos = start_pos,
		maxpos = target_pos,
		minvel = {x = 0, y = 0, z = 0},
		maxvel = {x = 0, y = 0.5, z = 0},
		minacc = {x = 0, y = 0, z = 0},
		maxacc = {x = 0, y = 0, z = 0},
		minexptime = 0.3,
		maxexptime = 0.8,
		minsize = 0.5,
		maxsize = 1.5,
		collisiondetection = false,
		texture = "default_cloud.png^[colorize:" .. color .. ":180",
		glow = 12,
	})
end

--------------------------------------------------------------------
-- HELPER FUNCTION: GET POINTED NPC
--------------------------------------------------------------------

local function get_pointed_npc(user)
	if not user then return nil end

	local player_pos = user:get_pos()
	local look_dir = user:get_look_dir()

	-- Cast a ray to find what the player is looking at
	local ray_end = vector.add(player_pos, vector.multiply(look_dir, 20))

	-- Search for entities in range
	local objects = minetest.get_objects_inside_radius(player_pos, 20)

	local closest_npc = nil
	local closest_distance = 20

	for _, obj in ipairs(objects) do
		if obj ~= user and obj:get_luaentity() then
			local entity = obj:get_luaentity()
			local entity_name = entity.name or ""

			-- Check if this is an NPC (villager, raider, witch, etc.)
			if entity_name:match("lualore:") and
			   not entity_name:match("wizard") and
			   entity.type == "npc" or entity.type == "monster" then

				local obj_pos = obj:get_pos()
				if obj_pos then
					-- Check if entity is in the direction player is looking
					local to_entity = vector.subtract(obj_pos, player_pos)
					local distance = vector.length(to_entity)

					if distance < closest_distance then
						local direction_normalized = vector.normalize(to_entity)
						local dot = vector.dot(look_dir, direction_normalized)

						-- If entity is within a 30 degree cone (dot > 0.85)
						if dot > 0.85 then
							closest_npc = obj
							closest_distance = distance
						end
					end
				end
			end
		end
	end

	return closest_npc
end

--------------------------------------------------------------------
-- GOLD WAND: LEVITATE NPCs
--------------------------------------------------------------------

local function gold_wand_levitate(user, pointed_thing)
	local target = get_pointed_npc(user)

	if not target then
		minetest.chat_send_player(user:get_player_name(), "No NPC in range or line of sight")
		return
	end

	local target_entity = target:get_luaentity()
	if not target_entity then return end

	local entity_id = tostring(target)

	-- Check if NPC already has this effect
	if npc_effects[entity_id] and npc_effects[entity_id].levitate then
		return
	end

	local user_pos = user:get_pos()
	local target_pos = target:get_pos()

	-- Play blue sound
	local blue_sound = math.random(1, 2)
	minetest.sound_play("Blue" .. blue_sound, {
		pos = user_pos,
		gain = 0.15,
		max_hear_distance = 32
	}, true)

	-- Spell projectile
	spawn_spell_projectile(user_pos, target_pos, "blue")

	-- Setup effect
	if not npc_effects[entity_id] then
		npc_effects[entity_id] = {}
	end

	npc_effects[entity_id].levitate = true
	npc_effects[entity_id].levitate_timer = 2.5
	npc_effects[entity_id].levitate_height = 0
	npc_effects[entity_id].target = target

	-- Store original physics and apply negative gravity to float up
	if target_entity.object then
		local old_physics = target_entity.object:get_acceleration()
		npc_effects[entity_id].old_acceleration = old_physics

		-- Set upward acceleration (negative gravity)
		target:set_acceleration({x = 0, y = 10, z = 0})
	end

	-- Visual effect with upward arrow particles
	minetest.add_particlespawner({
		amount = 40,
		time = 6,
		minpos = {x = target_pos.x - 0.8, y = target_pos.y, z = target_pos.z - 0.8},
		maxpos = {x = target_pos.x + 0.8, y = target_pos.y + 0.5, z = target_pos.z + 0.8},
		minvel = {x = -0.2, y = 2, z = -0.2},
		maxvel = {x = 0.2, y = 3.5, z = 0.2},
		minacc = {x = 0, y = 0.5, z = 0},
		maxacc = {x = 0, y = 1, z = 0},
		minexptime = 1,
		maxexptime = 2,
		minsize = 2.5,
		maxsize = 4,
		collisiondetection = false,
		texture = "lualore_particle_arrow_up.png^[colorize:blue:180",
		glow = 12,
	})
end

--------------------------------------------------------------------
-- WHITE WAND: SICK CURSE (Damage over time)
--------------------------------------------------------------------

local function white_wand_sick(user, pointed_thing)
	local target = get_pointed_npc(user)

	if not target then
		minetest.chat_send_player(user:get_player_name(), "No NPC in range or line of sight")
		return
	end

	local target_entity = target:get_luaentity()
	if not target_entity then return end

	local entity_id = tostring(target)

	-- Check if NPC already has this effect
	if npc_effects[entity_id] and npc_effects[entity_id].sick then
		return
	end

	local user_pos = user:get_pos()
	local target_pos = target:get_pos()

	-- Play green sound
	local green_sound = math.random(1, 2)
	minetest.sound_play("Green" .. green_sound, {
		pos = user_pos,
		gain = 0.15,
		max_hear_distance = 32
	}, true)

	-- Spell projectile
	spawn_spell_projectile(user_pos, target_pos, "green")

	-- Setup effect
	if not npc_effects[entity_id] then
		npc_effects[entity_id] = {}
	end

	npc_effects[entity_id].sick = true
	npc_effects[entity_id].sick_timer = 15
	npc_effects[entity_id].sick_damage_timer = 1
	npc_effects[entity_id].target = target

	-- Visual effect with organic blob particles
	minetest.add_particlespawner({
		amount = 40,
		time = 15,
		minpos = {x = target_pos.x - 1, y = target_pos.y, z = target_pos.z - 1},
		maxpos = {x = target_pos.x + 1, y = target_pos.y + 2, z = target_pos.z + 1},
		minvel = {x = -0.8, y = 0.3, z = -0.8},
		maxvel = {x = 0.8, y = 1.2, z = 0.8},
		minacc = {x = 0, y = -0.2, z = 0},
		maxacc = {x = 0, y = 0.1, z = 0},
		minexptime = 1.5,
		maxexptime = 3,
		minsize = 1.5,
		maxsize = 4.5,
		collisiondetection = false,
		texture = "lualore_particle_blob.png^[colorize:green:180",
		glow = 12,
	})

	-- Initial damage (doubled for player use)
	if target_entity.health then
		target_entity.health = target_entity.health - 4
	end
end

--------------------------------------------------------------------
-- RED WAND: TELEPORT NPCs (No damage)
--------------------------------------------------------------------

local function red_wand_teleport(user, pointed_thing)
	local target = get_pointed_npc(user)

	if not target then
		minetest.chat_send_player(user:get_player_name(), "No NPC in range or line of sight")
		return
	end

	local target_entity = target:get_luaentity()
	if not target_entity then return end

	local user_pos = user:get_pos()
	local target_pos = target:get_pos()

	-- Play magic sound
	minetest.sound_play("magic", {
		pos = user_pos,
		gain = 0.05,
		max_hear_distance = 32
	}, true)

	-- Spell projectile
	spawn_spell_projectile(user_pos, target_pos, "purple")

	-- Calculate random teleport direction
	local distance = 15
	local angle = math.random() * math.pi * 2
	local offset_x = math.cos(angle) * distance
	local offset_z = math.sin(angle) * distance

	local new_target_pos = {
		x = target_pos.x + offset_x,
		y = target_pos.y,
		z = target_pos.z + offset_z
	}

	-- Teleport effects at old position
	minetest.add_particlespawner({
		amount = 50,
		time = 1,
		minpos = {x = target_pos.x - 1, y = target_pos.y, z = target_pos.z - 1},
		maxpos = {x = target_pos.x + 1, y = target_pos.y + 2, z = target_pos.z + 1},
		minvel = {x = -1, y = 0.5, z = -1},
		maxvel = {x = 1, y = 2, z = 1},
		minacc = {x = 0, y = 0, z = 0},
		maxacc = {x = 0, y = 0.5, z = 0},
		minexptime = 0.5,
		maxexptime = 2,
		minsize = 1,
		maxsize = 2,
		collisiondetection = false,
		texture = "default_cloud.png^[colorize:purple:200",
		glow = 14,
	})

	-- Teleport the target
	target:set_pos(new_target_pos)

	-- Teleport effects at new position
	minetest.add_particlespawner({
		amount = 50,
		time = 1,
		minpos = {x = new_target_pos.x - 1, y = new_target_pos.y, z = new_target_pos.z - 1},
		maxpos = {x = new_target_pos.x + 1, y = new_target_pos.y + 2, z = new_target_pos.z + 1},
		minvel = {x = -1, y = 0.5, z = -1},
		maxvel = {x = 1, y = 2, z = 1},
		minacc = {x = 0, y = 0, z = 0},
		maxacc = {x = 0, y = 0.5, z = 0},
		minexptime = 0.5,
		maxexptime = 2,
		minsize = 1,
		maxsize = 2,
		collisiondetection = false,
		texture = "default_cloud.png^[colorize:purple:200",
		glow = 14,
	})
end

--------------------------------------------------------------------
-- BLACK WAND: BLIND AND FREEZE NPCs
--------------------------------------------------------------------

local function black_wand_blind(user, pointed_thing)
	local target = get_pointed_npc(user)

	if not target then
		minetest.chat_send_player(user:get_player_name(), "No NPC in range or line of sight")
		return
	end

	local target_entity = target:get_luaentity()
	if not target_entity then return end

	local entity_id = tostring(target)

	-- Check if NPC already has this effect
	if npc_effects[entity_id] and npc_effects[entity_id].blinded then
		return
	end

	local user_pos = user:get_pos()
	local target_pos = target:get_pos()

	-- Play black sound
	local black_sound = math.random(1, 2)
	minetest.sound_play("Black" .. black_sound, {
		pos = user_pos,
		gain = 0.1,
		max_hear_distance = 32
	}, true)

	-- Spell projectile
	spawn_spell_projectile(user_pos, target_pos, "black")

	-- Setup effect
	if not npc_effects[entity_id] then
		npc_effects[entity_id] = {}
	end

	npc_effects[entity_id].blinded = true
	npc_effects[entity_id].blind_timer = 8
	npc_effects[entity_id].target = target
	npc_effects[entity_id].old_velocity = target:get_velocity()

	-- Freeze the NPC
	target:set_velocity({x = 0, y = 0, z = 0})

	-- Store original state
	if target_entity.attack then
		npc_effects[entity_id].old_attack = target_entity.attack
		target_entity.attack = nil
	end

	-- Visual effect with black circle particles
	for i = 1, 3 do
		minetest.add_particlespawner({
			amount = 50,
			time = 8,
			minpos = {x = target_pos.x - 1, y = target_pos.y, z = target_pos.z - 1},
			maxpos = {x = target_pos.x + 1, y = target_pos.y + 2, z = target_pos.z + 1},
			minvel = {x = -1.5, y = -1.5, z = -1.5},
			maxvel = {x = 1.5, y = 1.5, z = 1.5},
			minacc = {x = 0, y = 0, z = 0},
			maxacc = {x = 1, y = 1.5, z = 1},
			minexptime = 0.8,
			maxexptime = 1.2,
			minsize = 5,
			maxsize = 10,
			collisiondetection = false,
			texture = "lualore_particle_circle.png^[colorize:black:255",
			glow = 0,
		})
	end
end

--------------------------------------------------------------------
-- REGISTER WANDS AS TOOLS
--------------------------------------------------------------------

-- Gold wand
minetest.register_tool("lualore:gold_wand", {
	description = S("Gold Wand") .. "\n" .. S("Levitates NPCs"),
	inventory_image = "gold_wand.png",
	groups = {not_in_creative_inventory = 0},
	on_use = function(itemstack, user, pointed_thing)
		gold_wand_levitate(user, pointed_thing)
		return itemstack
	end,
})

-- White wand
minetest.register_tool("lualore:white_wand", {
	description = S("White Wand") .. "\n" .. S("Inflicts sickness on NPCs"),
	inventory_image = "white_wand.png",
	groups = {not_in_creative_inventory = 0},
	on_use = function(itemstack, user, pointed_thing)
		white_wand_sick(user, pointed_thing)
		return itemstack
	end,
})

-- Red wand
minetest.register_tool("lualore:red_wand", {
	description = S("Red Wand") .. "\n" .. S("Teleports NPCs"),
	inventory_image = "red_wand.png",
	groups = {not_in_creative_inventory = 0},
	on_use = function(itemstack, user, pointed_thing)
		red_wand_teleport(user, pointed_thing)
		return itemstack
	end,
})

-- Black wand
minetest.register_tool("lualore:black_wand", {
	description = S("Black Wand") .. "\n" .. S("Blinds and freezes NPCs"),
	inventory_image = "black_wand.png",
	groups = {not_in_creative_inventory = 0},
	on_use = function(itemstack, user, pointed_thing)
		black_wand_blind(user, pointed_thing)
		return itemstack
	end,
})

--------------------------------------------------------------------
-- EFFECT UPDATES (called every globalstep)
--------------------------------------------------------------------

local effect_timer = 0
minetest.register_globalstep(function(dtime)
	effect_timer = effect_timer + dtime

	-- Only update every 0.1 seconds
	if effect_timer < 0.1 then return end
	effect_timer = 0

	for entity_id, effects in pairs(npc_effects) do
		local target = effects.target

		-- Clean up if entity is gone
		if not target or not target:get_pos() then
			npc_effects[entity_id] = nil
			goto continue
		end

		local target_entity = target:get_luaentity()
		if not target_entity then
			npc_effects[entity_id] = nil
			goto continue
		end

		-- Levitate effect
		if effects.levitate then
			effects.levitate_timer = effects.levitate_timer - 0.1

			local pos = target:get_pos()
			if pos then
				-- Track height gained
				if not effects.levitate_start_y then
					effects.levitate_start_y = pos.y
				end

				effects.levitate_height = pos.y - effects.levitate_start_y

				-- Keep applying upward force during levitation phase
				if effects.levitate_timer > 0 and effects.levitate_height < 10 then
					-- Continue pushing upward
					target:set_acceleration({x = 0, y = 10, z = 0})
				else
					-- Levitation ending or max height reached, restore gravity
					target:set_acceleration({x = 0, y = -10, z = 0})
				end
			end

			if effects.levitate_timer <= 0 then
				effects.levitate = nil
				effects.levitate_start_y = nil
				effects.levitate_height = nil

				-- Restore normal gravity
				if effects.old_acceleration then
					target:set_acceleration(effects.old_acceleration)
					effects.old_acceleration = nil
				else
					target:set_acceleration({x = 0, y = -10, z = 0})
				end
			end
		end

		-- Sick effect (damage over time)
		if effects.sick then
			effects.sick_timer = effects.sick_timer - 0.1
			effects.sick_damage_timer = effects.sick_damage_timer - 0.1

			if effects.sick_timer <= 0 then
				effects.sick = nil
			else
				-- Apply damage every second (doubled for player use)
				if effects.sick_damage_timer <= 0 then
					effects.sick_damage_timer = 1

					if target_entity.health then
						target_entity.health = target_entity.health - 2

						-- Play sick sound
						local pos = target:get_pos()
						local sick_sound = math.random(1, 2)
						minetest.sound_play("Sick" .. sick_sound, {
							pos = pos,
							gain = 0.4,
							max_hear_distance = 16
						}, true)

						-- Green particle burst
						minetest.add_particlespawner({
							amount = 30,
							time = 1,
							minpos = {x = pos.x - 0.5, y = pos.y, z = pos.z - 0.5},
							maxpos = {x = pos.x + 0.5, y = pos.y + 2, z = pos.z + 0.5},
							minvel = {x = -0.5, y = 0, z = -0.5},
							maxvel = {x = 0.5, y = 2, z = 0.5},
							minacc = {x = 0, y = -1, z = 0},
							maxacc = {x = 0, y = -1, z = 0},
							minexptime = 0.5,
							maxexptime = 1,
							minsize = 0.5,
							maxsize = 1.5,
							collisiondetection = false,
							texture = "lualore_particle_blob.png^[colorize:green:200",
							glow = 12,
						})
					end
				end
			end
		end

		-- Blind/Freeze effect
		if effects.blinded then
			effects.blind_timer = effects.blind_timer - 0.1

			-- Keep NPC frozen
			target:set_velocity({x = 0, y = 0, z = 0})

			if effects.blind_timer <= 0 then
				effects.blinded = nil

				-- Restore attack if it was stored
				if effects.old_attack and target_entity then
					target_entity.attack = effects.old_attack
					effects.old_attack = nil
				end
			end
		end

		::continue::
	end
end)

print(S("[MOD] Lualore - Wizard wands loaded"))
