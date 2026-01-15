-- wizard_magic.lua
-- Magic system for cave wizards boss fight
-- Four wizards with unique spell attacks
--
-- PARTICLE SHAPES:
-- Each spell uses a unique particle shape to make effects visually distinct:
-- - Red Wizard (Inverted Controls): X-shaped particles (lualore_particle_x.png)
-- - White Wizard (Sick Curse): Organic blob particles (lualore_particle_blob.png)
-- - White Wizard (Hyper Speed): Star particles (lualore_particle_star.png)
-- - Gold Wizard (Levitate): Upward arrow particles (lualore_particle_arrow_up.png)
-- - Gold Wizard (Shrinking): Downward arrow particles (lualore_particle_arrow_down.png)
-- - Black Wizard (Blindness): Circle particles (lualore_particle_circle.png)

local S = minetest.get_translator("lualore")

lualore.wizard_magic = {}

-- Track player spell effects
local player_effects = {}

--------------------------------------------------------------------
-- PARTICLE HELPER FUNCTIONS
--------------------------------------------------------------------

local function spawn_spiral_particles(pos, color, duration, radius)
	local spawner_id = minetest.add_particlespawner({
		amount = 50,
		time = duration,
		minpos = {x = pos.x - radius, y = pos.y, z = pos.z - radius},
		maxpos = {x = pos.x + radius, y = pos.y + 2, z = pos.z + radius},
		minvel = {x = -1, y = 0.5, z = -1},
		maxvel = {x = 1, y = 2, z = 1},
		minacc = {x = 0, y = 0, z = 0},
		maxacc = {x = 0, y = 0.5, z = 0},
		minexptime = 0.5,
		maxexptime = 2,
		minsize = 1,
		maxsize = 2,
		collisiondetection = false,
		texture = "default_cloud.png^[colorize:" .. color .. ":200",
		glow = 14,
	})
	return spawner_id
end

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
-- RED WIZARD SPELLS
--------------------------------------------------------------------

-- Spell 1: Teleport (purple particles, no damage)
function lualore.wizard_magic.red_teleport_attack(self, target)
	if not self or not self.object or not target then return false end

	local caster_pos = self.object:get_pos()
	if not caster_pos then return false end

	local target_pos = target:get_pos()
	if not target_pos then return false end

	-- Play magic sound (teleport uses generic magic sound)
	minetest.sound_play("magic", {
		pos = caster_pos,
		gain = 0.05,
		max_hear_distance = 32
	}, true)

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

	-- Teleport effects
	spawn_spell_projectile(caster_pos, target_pos, "purple")
	spawn_spiral_particles(target_pos, "purple", 1, 1.5)

	-- Teleport the target
	target:set_pos(new_target_pos)
	spawn_spiral_particles(new_target_pos, "purple", 1, 1.5)

	return true
end

-- Spell 2: Inverted Controls (red particles, 5 seconds)
function lualore.wizard_magic.red_invert_controls(self, target)
	if not self or not self.object or not target or not target:is_player() then return false end

	local caster_pos = self.object:get_pos()
	local target_pos = target:get_pos()
	if not caster_pos or not target_pos then return false end

	local player_name = target:get_player_name()

	-- Check if player already has this effect
	if player_effects[player_name] and player_effects[player_name].inverted_controls then
		return false
	end

	-- Play red sound
	local red_sound = math.random(1, 2)
	minetest.sound_play("Red" .. red_sound, {
		pos = caster_pos,
		gain = 0.08,
		max_hear_distance = 32
	}, true)

	-- Spell projectile
	spawn_spell_projectile(caster_pos, target_pos, "red")

	-- Store original physics
	if not player_effects[player_name] then
		player_effects[player_name] = {}
	end

	player_effects[player_name].inverted_controls = true
	player_effects[player_name].inverted_timer = 5

	-- Visual effect with X-shaped particles
	local spawner_id = minetest.add_particlespawner({
		amount = 30,
		time = 5,
		minpos = {x = target_pos.x - 1, y = target_pos.y, z = target_pos.z - 1},
		maxpos = {x = target_pos.x + 1, y = target_pos.y + 2, z = target_pos.z + 1},
		minvel = {x = -0.5, y = 0.5, z = -0.5},
		maxvel = {x = 0.5, y = 1.5, z = 0.5},
		minacc = {x = 0, y = 0, z = 0},
		maxacc = {x = 0, y = 0.3, z = 0},
		minexptime = 1,
		maxexptime = 2,
		minsize = 2,
		maxsize = 4,
		collisiondetection = false,
		texture = "lualore_particle_x.png^[colorize:red:180",  -- X shape for inverted controls
		glow = 12,
	})

	-- Apply inverted movement (make player move backwards when going forward)
	local old_physics = target:get_physics_override()
	player_effects[player_name].old_physics = old_physics

	return true
end

--------------------------------------------------------------------
-- WHITE WIZARD SPELLS
--------------------------------------------------------------------

-- Spell 1: Sick Curse (green particles, freeze randomly, 15 seconds, small damage)
function lualore.wizard_magic.white_sick_curse(self, target)
	if not self or not self.object or not target or not target:is_player() then return false end

	local caster_pos = self.object:get_pos()
	local target_pos = target:get_pos()
	if not caster_pos or not target_pos then return false end

	local player_name = target:get_player_name()

	-- Check if player already has this effect
	if player_effects[player_name] and player_effects[player_name].sick_curse then
		return false
	end

	-- Play green sound
	local green_sound = math.random(1, 2)
	minetest.sound_play("Green" .. green_sound, {
		pos = caster_pos,
		gain = 0.15,
		max_hear_distance = 32
	}, true)

	-- Spell projectile
	spawn_spell_projectile(caster_pos, target_pos, "green")

	-- Setup effect
	if not player_effects[player_name] then
		player_effects[player_name] = {}
	end

	player_effects[player_name].sick_curse = true
	player_effects[player_name].sick_timer = 15
	player_effects[player_name].sick_freeze_timer = 1

	-- Visual effect with organic blob particles
	local spawner_id = minetest.add_particlespawner({
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
		maxsize = 4.5,  -- Varied sizes for organic feel
		collisiondetection = false,
		texture = "lualore_particle_blob.png^[colorize:green:180",  -- Organic blob for sickness
		glow = 12,
	})

	-- Initial damage
	target:set_hp(target:get_hp() - 4)

	return true
end

-- Spell 2: Hyper Curse (white particles, 200% speed and sensitivity)
function lualore.wizard_magic.white_hyper_curse(self, target)
	if not self or not self.object or not target or not target:is_player() then return false end

	local caster_pos = self.object:get_pos()
	local target_pos = target:get_pos()
	if not caster_pos or not target_pos then return false end

	local player_name = target:get_player_name()

	-- Check if player already has this effect
	if player_effects[player_name] and player_effects[player_name].hyper_curse then
		return false
	end

	-- Play white sound
	local white_sound = math.random(1, 2)
	minetest.sound_play("White" .. white_sound, {
		pos = caster_pos,
		gain = 0.15,
		max_hear_distance = 32
	}, true)

	-- Spell projectile
	spawn_spell_projectile(caster_pos, target_pos, "white")

	-- Setup effect
	if not player_effects[player_name] then
		player_effects[player_name] = {}
	end

	local old_physics = target:get_physics_override()
	local old_fov = target:get_fov()

	player_effects[player_name].hyper_curse = true
	player_effects[player_name].hyper_timer = 15
	player_effects[player_name].old_physics = old_physics
	player_effects[player_name].old_fov = old_fov or 0
	player_effects[player_name].hyper_wobble = 0
	player_effects[player_name].hyper_rotation = 0

	-- Apply disorienting effects: moderate speed increase
	target:set_physics_override({
		speed = (old_physics.speed or 1) * 2,
		jump = (old_physics.jump or 1) * 1.5
	})

	-- Zoom out FOV significantly to make mouse movement feel hypersensitive and disorienting
	target:set_fov(140, false, 0.2)

	-- Visual effect with star particles attached to player
	local spawner_id = minetest.add_particlespawner({
		amount = 35,
		time = 15,
		attached = target,
		minpos = {x = -1, y = 0, z = -1},
		maxpos = {x = 1, y = 2, z = 1},
		minvel = {x = -1.5, y = 0.5, z = -1.5},
		maxvel = {x = 1.5, y = 2, z = 1.5},
		minacc = {x = 0, y = 0, z = 0},
		maxacc = {x = 0, y = 0.5, z = 0},
		minexptime = 0.8,
		maxexptime = 1.5,
		minsize = 2,
		maxsize = 4,
		collisiondetection = false,
		texture = "lualore_particle_star.png^[colorize:white:150",  -- Star shape for hyper speed
		glow = 14,
	})

	-- Store spawner ID to clean up when effect ends
	if not player_effects[player_name].hyper_particles then
		player_effects[player_name].hyper_particles = {}
	end
	table.insert(player_effects[player_name].hyper_particles, spawner_id)

	return true
end

--------------------------------------------------------------------
-- GOLD WIZARD SPELLS
--------------------------------------------------------------------

-- Spell 1: Levitate (blue particles, float up 10 nodes then drop for damage)
function lualore.wizard_magic.gold_levitate(self, target)
	if not self or not self.object or not target or not target:is_player() then return false end

	local caster_pos = self.object:get_pos()
	local target_pos = target:get_pos()
	if not caster_pos or not target_pos then return false end

	local player_name = target:get_player_name()

	-- Check if player already has this effect
	if player_effects[player_name] and player_effects[player_name].levitate then
		return false
	end

	-- Play blue sound
	local blue_sound = math.random(1, 2)
	minetest.sound_play("Blue" .. blue_sound, {
		pos = caster_pos,
		gain = 0.15,
		max_hear_distance = 32
	}, true)

	-- Spell projectile
	spawn_spell_projectile(caster_pos, target_pos, "blue")

	-- Setup effect
	if not player_effects[player_name] then
		player_effects[player_name] = {}
	end

	local old_physics = target:get_physics_override()
	player_effects[player_name].levitate = true
	player_effects[player_name].levitate_timer = 2.5
	player_effects[player_name].levitate_height = 0
	player_effects[player_name].old_physics = old_physics

	-- Apply negative gravity to float up
	target:set_physics_override({
		gravity = -0.08
	})

	-- Visual effect with upward arrow particles
	local spawner_id = minetest.add_particlespawner({
		amount = 40,
		time = 6,
		minpos = {x = target_pos.x - 0.8, y = target_pos.y, z = target_pos.z - 0.8},
		maxpos = {x = target_pos.x + 0.8, y = target_pos.y + 0.5, z = target_pos.z + 0.8},
		minvel = {x = -0.2, y = 2, z = -0.2},  -- Mostly upward velocity
		maxvel = {x = 0.2, y = 3.5, z = 0.2},
		minacc = {x = 0, y = 0.5, z = 0},
		maxacc = {x = 0, y = 1, z = 0},
		minexptime = 1,
		maxexptime = 2,
		minsize = 2.5,
		maxsize = 4,
		collisiondetection = false,
		texture = "lualore_particle_arrow_up.png^[colorize:blue:180",  -- Up arrow for levitation
		glow = 12,
	})

	return true
end

-- Spell 2: Disarm Curse (yellow particles, force player to drop wielded items for 5 seconds)
function lualore.wizard_magic.gold_transform(self, target)
	if not self or not self.object or not target or not target:is_player() then return false end

	local caster_pos = self.object:get_pos()
	local target_pos = target:get_pos()
	if not caster_pos or not target_pos then return false end

	local player_name = target:get_player_name()

	-- Check if player already has this effect
	if player_effects[player_name] and player_effects[player_name].disarmed then
		return false
	end

	-- Play yellow sound
	local yellow_sound = math.random(1, 2)
	minetest.sound_play("Yellow" .. yellow_sound, {
		pos = caster_pos,
		gain = 0.15,
		max_hear_distance = 32
	}, true)

	-- Spell projectile
	spawn_spell_projectile(caster_pos, target_pos, "yellow")

	-- Setup effect
	if not player_effects[player_name] then
		player_effects[player_name] = {}
	end

	player_effects[player_name].disarmed = true
	player_effects[player_name].disarm_timer = 5
	player_effects[player_name].last_wield_index = nil

	-- Immediately drop whatever is in hand
	local inv = target:get_inventory()
	if inv then
		local wield_index = target:get_wield_index()
		local wielded_item = target:get_wielded_item()

		if wielded_item and not wielded_item:is_empty() then
			-- Drop the item
			local droppos = vector.add(target_pos, {x=0, y=1.2, z=0})
			local obj = minetest.add_item(droppos, wielded_item)

			if obj then
				-- Give the dropped item some velocity away from player
				local dir = target:get_look_dir()
				obj:set_velocity({
					x = dir.x * 3,
					y = 2,
					z = dir.z * 3
				})
			end

			-- Remove from inventory
			inv:set_stack("main", wield_index, ItemStack(""))
		end
	end

	-- Visual effect with X particles (disarm symbol)
	minetest.add_particlespawner({
		amount = 40,
		time = 2,
		minpos = {x = target_pos.x - 1, y = target_pos.y + 1, z = target_pos.z - 1},
		maxpos = {x = target_pos.x + 1, y = target_pos.y + 2, z = target_pos.z + 1},
		minvel = {x = -1.5, y = -0.5, z = -1.5},
		maxvel = {x = 1.5, y = 0.5, z = 1.5},
		minacc = {x = 0, y = -0.5, z = 0},
		maxacc = {x = 0, y = -1, z = 0},
		minexptime = 1,
		maxexptime = 2,
		minsize = 3,
		maxsize = 5,
		collisiondetection = false,
		texture = "lualore_particle_x.png^[colorize:yellow:180",
		glow = 12,
	})

	return true
end

--------------------------------------------------------------------
-- BLACK WIZARD SPELL
--------------------------------------------------------------------

-- Blindness (thick black particles blocking vision)
function lualore.wizard_magic.black_blindness(self, target)
	if not self or not self.object or not target or not target:is_player() then return false end

	local caster_pos = self.object:get_pos()
	local target_pos = target:get_pos()
	if not caster_pos or not target_pos then return false end

	local player_name = target:get_player_name()

	-- Check if player already has this effect
	if player_effects[player_name] and player_effects[player_name].blinded then
		return false
	end

	-- Play black sound
	local black_sound = math.random(1, 2)
	minetest.sound_play("Black" .. black_sound, {
		pos = caster_pos,
		gain = 0.1,
		max_hear_distance = 32
	}, true)

	-- Spell projectile
	spawn_spell_projectile(caster_pos, target_pos, "black")

	-- Setup effect
	if not player_effects[player_name] then
		player_effects[player_name] = {}
	end

	player_effects[player_name].blinded = true
	player_effects[player_name].blind_timer = 8
	player_effects[player_name].blind_particles = {}

	-- Create swirling black particles that obscure vision without completely blocking it
	-- TWEAK PARAMETERS:
	-- - 'amount' controls particle density (higher = more particles, currently 50 per spawner)
	-- - 'minsize/maxsize' controls particle size (currently 8-18, increase for more coverage)
	-- - 'minvel/maxvel' controls particle movement speed (higher values = faster movement)
	-- - Loop count (currently 3) controls total volume (more loops = more particle layers)

	for i = 1, 3 do  -- Number of particle spawner layers (increase for more density)
		local spawner_id = minetest.add_particlespawner({
			amount = 50,  -- Particles spawned per second (increase for more density)
			time = 0,  -- Infinite spawner (runs until manually deleted)
			minpos = {x = -0.1, y = -0.1, z = 0.05},  -- Spawn area in front of player
			maxpos = {x = 0.3, y = 0.3, z = 0.5},
			minvel = {x = -1.5, y = -1.5, z = -0.5},  -- Particle velocity (makes them swirl)
			maxvel = {x = 1.5, y = 1.5, z = 0.5},
			minacc = {x = 0, y = 0, z = 0},  -- No acceleration
			maxacc = {x = 1, y = 1.5, z = 1},
			minexptime = 0.8,  -- Particle lifetime (how long each particle exists)
			maxexptime = 1.2,
			minsize = 5,  -- Minimum particle size (increase for more coverage)
			maxsize = 10,  -- Maximum particle size (increase for more coverage)
			collisiondetection = false,
			attached = target,  -- Particles follow player
			texture = "lualore_particle_circle.png^[colorize:black:255",  -- Black circle for blindness
			glow = 0,  -- No glow
		})
		table.insert(player_effects[player_name].blind_particles, spawner_id)
	end

	return true
end

--------------------------------------------------------------------
-- CLEAR ALL EFFECTS (used on death/respawn)
--------------------------------------------------------------------

local function clear_all_effects(player)
	if not player or not player:is_player() then return end

	local player_name = player:get_player_name()
	local effects = player_effects[player_name]

	if not effects then return end

	-- Restore physics if any effect had changed them
	if effects.old_physics then
		player:set_physics_override(effects.old_physics)
	end

	-- Remove blindness particles
	if effects.blind_particles then
		for _, spawner_id in ipairs(effects.blind_particles) do
			minetest.delete_particlespawner(spawner_id)
		end
	end

	-- Clear all effects for this player
	player_effects[player_name] = nil
end

-- Clear effects on death
minetest.register_on_dieplayer(function(player)
	clear_all_effects(player)
end)

-- Clear effects on respawn (backup safety check)
minetest.register_on_respawnplayer(function(player)
	clear_all_effects(player)
	return false  -- Don't override default respawn behavior
end)

--------------------------------------------------------------------
-- EFFECT UPDATES (called every globalstep)
--------------------------------------------------------------------

local effect_timer = 0
minetest.register_globalstep(function(dtime)
	effect_timer = effect_timer + dtime

	-- Only update every 0.1 seconds
	if effect_timer < 0.1 then return end
	effect_timer = 0

	for player_name, effects in pairs(player_effects) do
		local player = minetest.get_player_by_name(player_name)
		if not player then
			player_effects[player_name] = nil
			goto continue
		end

		-- Inverted controls
		if effects.inverted_controls then
			effects.inverted_timer = effects.inverted_timer - 0.1

			if effects.inverted_timer <= 0 then
				effects.inverted_controls = nil
				if effects.old_physics then
					player:set_physics_override(effects.old_physics)
					effects.old_physics = nil
				end
			else
				-- Invert movement controls
				local control = player:get_player_control()
				if control.up then
					player:add_velocity({x = 0, y = 0, z = 5})
				end
				if control.down then
					player:add_velocity({x = 0, y = 0, z = -5})
				end
			end
		end

		-- Sick curse (freeze randomly)
		if effects.sick_curse then
			effects.sick_timer = effects.sick_timer - 0.1
			effects.sick_freeze_timer = effects.sick_freeze_timer - 0.1

			if effects.sick_timer <= 0 then
				effects.sick_curse = nil
			else
				-- Random freeze every 3-5 seconds
				if effects.sick_freeze_timer <= 0 then
					effects.sick_freeze_timer = math.random(3, 5)

					-- Freeze for 1 second
					local old_speed = player:get_physics_override().speed or 1
					player:set_physics_override({speed = 0})

					-- Play sick sound
					local pos = player:get_pos()
					local sick_sound = math.random(1, 2)
					minetest.sound_play("Sick" .. sick_sound, {
						pos = pos,
						gain = 0.4,
						max_hear_distance = 16
					}, true)

					-- Green particle burst
					minetest.add_particlespawner({
						amount = 50,
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
						texture = "lualore_particle_blob.png^[colorize:green:200",  -- Green organic blobs for sickness
						glow = 12,
					})

					-- Unfreeze after 1 second
					minetest.after(1, function()
						if player and player:is_player() then
							player:set_physics_override({speed = old_speed})
						end
					end)

					-- Small damage
					player:set_hp(player:get_hp() - 1)
				end
			end
		end

		-- Hyper curse
		if effects.hyper_curse then
			effects.hyper_timer = effects.hyper_timer - 0.1

			-- Add disorienting camera wobble effect
			effects.hyper_wobble = (effects.hyper_wobble or 0) + 0.1
			local wobble_intensity = math.sin(effects.hyper_wobble * 8) * 2

			-- Apply subtle camera rotation to disorient
			local look_dir = player:get_look_dir()
			local pitch = player:get_look_vertical()
			local yaw = player:get_look_horizontal()

			-- Add small wobble to view angle
			player:set_look_horizontal(yaw + wobble_intensity * 0.01)

			if effects.hyper_timer <= 0 then
				effects.hyper_curse = nil
				if effects.old_physics then
					player:set_physics_override(effects.old_physics)
					effects.old_physics = nil
				end
				-- Restore FOV
				if effects.old_fov then
					player:set_fov(effects.old_fov, false, 0.5)
					effects.old_fov = nil
				end
				-- Clean up particles
				if effects.hyper_particles then
					for _, spawner_id in ipairs(effects.hyper_particles) do
						minetest.delete_particlespawner(spawner_id)
					end
					effects.hyper_particles = nil
				end
				effects.hyper_wobble = nil
			end
		end

		-- Levitate
		if effects.levitate then
			effects.levitate_timer = effects.levitate_timer - 0.1
			local pos = player:get_pos()

			if effects.levitate_timer > 0 then
				-- Still rising (gravity is already set to -0.1 from initial cast)
				effects.levitate_height = effects.levitate_height + 0.5
			elseif effects.levitate_timer > -3 then
				-- Drop phase (3 seconds) - ensure we've switched to falling
				if not effects.levitate_falling then
					-- First time entering drop phase - switch to normal gravity
					player:set_physics_override({gravity = 1})
					effects.levitate_falling = true
				end
			else
				-- Effect over - restore original physics
				effects.levitate = nil
				effects.levitate_falling = nil
				if effects.old_physics then
					player:set_physics_override(effects.old_physics)
					effects.old_physics = nil
				end
			end
		end

		-- Disarm effect
		if effects.disarmed then
			effects.disarm_timer = effects.disarm_timer - 0.1

			-- Check if player has switched to a different item or picked up something
			local current_wield_index = player:get_wield_index()
			local wielded_item = player:get_wielded_item()

			if wielded_item and not wielded_item:is_empty() then
				-- Player is holding something, drop it
				local pos = player:get_pos()
				local droppos = vector.add(pos, {x=0, y=1.2, z=0})
				local obj = minetest.add_item(droppos, wielded_item)

				if obj then
					-- Give the dropped item some velocity
					local dir = player:get_look_dir()
					obj:set_velocity({
						x = dir.x * 2,
						y = 1.5,
						z = dir.z * 2
					})
				end

				-- Remove from inventory
				local inv = player:get_inventory()
				if inv then
					inv:set_stack("main", current_wield_index, ItemStack(""))
				end

				-- Small particle burst when dropping
				minetest.add_particlespawner({
					amount = 8,
					time = 0.3,
					minpos = {x = pos.x - 0.3, y = pos.y + 1, z = pos.z - 0.3},
					maxpos = {x = pos.x + 0.3, y = pos.y + 1.5, z = pos.z + 0.3},
					minvel = {x = -1, y = 0, z = -1},
					maxvel = {x = 1, y = 1, z = 1},
					minacc = {x = 0, y = -2, z = 0},
					maxacc = {x = 0, y = -3, z = 0},
					minexptime = 0.5,
					maxexptime = 1,
					minsize = 1.5,
					maxsize = 2.5,
					collisiondetection = false,
					texture = "lualore_particle_x.png^[colorize:yellow:180",
					glow = 10,
				})
			end

			if effects.disarm_timer <= 0 then
				effects.disarmed = nil
				effects.last_wield_index = nil

				-- End particles (freedom from curse)
				local pos = player:get_pos()
				minetest.add_particlespawner({
					amount = 25,
					time = 1,
					minpos = {x = pos.x - 0.8, y = pos.y, z = pos.z - 0.8},
					maxpos = {x = pos.x + 0.8, y = pos.y + 1.5, z = pos.z + 0.8},
					minvel = {x = -0.5, y = 1, z = -0.5},
					maxvel = {x = 0.5, y = 2, z = 0.5},
					minacc = {x = 0, y = 0.5, z = 0},
					maxacc = {x = 0, y = 1, z = 0},
					minexptime = 0.8,
					maxexptime = 1.5,
					minsize = 2,
					maxsize = 3.5,
					collisiondetection = false,
					texture = "lualore_particle_star.png^[colorize:yellow:180",
					glow = 12,
				})
			end
		end

		-- Blindness (countdown and clean up particles)
		if effects.blinded then
			effects.blind_timer = effects.blind_timer - 0.1
			if effects.blind_timer <= 0 then
				effects.blinded = nil
				-- Remove particle spawners
				if effects.blind_particles then
					for _, spawner_id in ipairs(effects.blind_particles) do
						minetest.delete_particlespawner(spawner_id)
					end
					effects.blind_particles = nil
				end
			end
		end

		::continue::
	end
end)

--------------------------------------------------------------------
-- WIZARD DEFENSIVE ABILITIES (Self-Use Powers)
--------------------------------------------------------------------

-- Red Wizard: Self-Teleport (defensive evasion)
function lualore.wizard_magic.red_self_teleport(self)
	if not self or not self.object then return false end

	local pos = self.object:get_pos()
	if not pos then return false end

	-- Find a random position within 5 nodes
	local attempts = 0
	local new_pos = nil

	while attempts < 10 do
		local offset = {
			x = math.random(-5, 5),
			y = math.random(-2, 2),
			z = math.random(-5, 5)
		}

		local test_pos = vector.add(pos, offset)

		-- Check if the position is valid (not in solid node)
		local node = minetest.get_node(test_pos)
		local node_above = minetest.get_node(vector.add(test_pos, {x=0, y=1, z=0}))

		if node and node.name and minetest.registered_nodes[node.name] and
		   node_above and node_above.name and minetest.registered_nodes[node_above.name] then

			local def = minetest.registered_nodes[node.name]
			local def_above = minetest.registered_nodes[node_above.name]

			-- Check if both positions are walkable (for standing) or not solid (for teleporting into)
			if not def.walkable and not def_above.walkable then
				new_pos = test_pos
				break
			end
		end

		attempts = attempts + 1
	end

	if not new_pos then return false end

	-- Purple particle burst at original position
	minetest.add_particlespawner({
		amount = 50,
		time = 0.5,
		minpos = {x = pos.x - 0.5, y = pos.y, z = pos.z - 0.5},
		maxpos = {x = pos.x + 0.5, y = pos.y + 2, z = pos.z + 0.5},
		minvel = {x = -2, y = 0, z = -2},
		maxvel = {x = 2, y = 3, z = 2},
		minacc = {x = 0, y = -1, z = 0},
		maxacc = {x = 0, y = -2, z = 0},
		minexptime = 0.8,
		maxexptime = 1.5,
		minsize = 2,
		maxsize = 4,
		collisiondetection = false,
		texture = "lualore_particle_circle.png^[colorize:purple:200",
		glow = 14,
	})

	-- Teleport
	self.object:set_pos(new_pos)

	-- Purple particle burst at new position
	minetest.add_particlespawner({
		amount = 50,
		time = 0.5,
		minpos = {x = new_pos.x - 0.5, y = new_pos.y, z = new_pos.z - 0.5},
		maxpos = {x = new_pos.x + 0.5, y = new_pos.y + 2, z = new_pos.z + 0.5},
		minvel = {x = -2, y = 0, z = -2},
		maxvel = {x = 2, y = 3, z = 2},
		minacc = {x = 0, y = -1, z = 0},
		maxacc = {x = 0, y = -2, z = 0},
		minexptime = 0.8,
		maxexptime = 1.5,
		minsize = 2,
		maxsize = 4,
		collisiondetection = false,
		texture = "lualore_particle_circle.png^[colorize:purple:200",
		glow = 14,
	})

	return true
end

-- Gold Wizard: Self-Levitate (defensive evasion)
function lualore.wizard_magic.gold_self_levitate(self)
	if not self or not self.object then return false end

	local pos = self.object:get_pos()
	if not pos then return false end

	-- Store the levitation state
	if not self.nv_levitating then
		self.nv_levitating = true
		self.nv_levitate_timer = 0
		self.nv_levitate_start_y = pos.y

		-- Apply upward velocity
		local vel = self.object:get_velocity()
		self.object:set_velocity({x = vel.x, y = 8, z = vel.z})

		-- Golden particle burst
		minetest.add_particlespawner({
			amount = 40,
			time = 0.5,
			minpos = {x = pos.x - 0.5, y = pos.y, z = pos.z - 0.5},
			maxpos = {x = pos.x + 0.5, y = pos.y + 1, z = pos.z + 0.5},
			minvel = {x = -0.5, y = 2, z = -0.5},
			maxvel = {x = 0.5, y = 4, z = 0.5},
			minacc = {x = 0, y = 0.5, z = 0},
			maxacc = {x = 0, y = 1, z = 0},
			minexptime = 1,
			maxexptime = 2,
			minsize = 2,
			maxsize = 4,
			collisiondetection = false,
			texture = "lualore_particle_arrow_up.png^[colorize:yellow:180",
			glow = 14,
		})

		return true
	end

	return false
end

--------------------------------------------------------------------
-- WIZARD ATTACK BEHAVIOR
--------------------------------------------------------------------

function lualore.wizard_magic.wizard_attack(self, dtime, wizard_type)
	if not self.attack then return false end
	if not self.object then return false end

	-- Initialize attack timer
	if not self.nv_wizard_attack_timer then
		self.nv_wizard_attack_timer = 0
		self.nv_wizard_spell_index = 1
	end

	-- Initialize attack cooldown (faster than melee)
	if not self.nv_wizard_attack_cooldown then
		self.nv_wizard_attack_cooldown = 4
	end

	self.nv_wizard_attack_timer = self.nv_wizard_attack_timer + dtime

	-- Check if cooldown has passed
	if self.nv_wizard_attack_timer < self.nv_wizard_attack_cooldown then
		return false
	end

	-- Check distance to target
	local pos = self.object:get_pos()
	if not pos then return false end

	local target_pos = self.attack:get_pos()
	if not target_pos then return false end

	local distance = vector.distance(pos, target_pos)

	-- Wizards prefer medium to long range (4-20 blocks for spells)
	if distance > 20 then return false end
	if distance < 4 then
		-- Too close - try to back away from target
		local direction = vector.direction(target_pos, pos)
		local retreat_pos = vector.add(pos, vector.multiply(direction, 2))
		self.object:set_velocity(vector.multiply(direction, 2))
		return false
	end

	local success = false

	-- Cast spell based on wizard type
	if wizard_type == "red" then
		-- Alternate between teleport and invert controls
		if self.nv_wizard_spell_index == 1 then
			success = lualore.wizard_magic.red_teleport_attack(self, self.attack)
			self.nv_wizard_spell_index = 2
		else
			success = lualore.wizard_magic.red_invert_controls(self, self.attack)
			self.nv_wizard_spell_index = 1
		end
	elseif wizard_type == "white" then
		-- Alternate between sick curse and hyper curse
		if self.nv_wizard_spell_index == 1 then
			success = lualore.wizard_magic.white_sick_curse(self, self.attack)
			self.nv_wizard_spell_index = 2
		else
			success = lualore.wizard_magic.white_hyper_curse(self, self.attack)
			self.nv_wizard_spell_index = 1
		end
	elseif wizard_type == "gold" then
		-- Alternate between levitate and transform
		if self.nv_wizard_spell_index == 1 then
			success = lualore.wizard_magic.gold_levitate(self, self.attack)
			self.nv_wizard_spell_index = 2
		else
			success = lualore.wizard_magic.gold_transform(self, self.attack)
			self.nv_wizard_spell_index = 1
		end
	elseif wizard_type == "black" then
		-- Black wizard only has blindness
		success = lualore.wizard_magic.black_blindness(self, self.attack)
	end

	if success then
		-- Full cooldown on successful spell cast
		self.nv_wizard_attack_timer = 0
		return true
	else
		-- Shorter cooldown on failed spell (player already has effect or other failure)
		-- This prevents rapid-fire spell attempts
		self.nv_wizard_attack_timer = -1.5
		return false
	end
end

--------------------------------------------------------------------
-- WIZARD-SPECIFIC DO_CUSTOM FUNCTIONS
--------------------------------------------------------------------

function lualore.wizard_magic.red_do_custom(self, dtime)
	if self.attack and self.state == "attack" then
		-- Initialize teleport cooldown timer
		if not self.nv_teleport_cooldown then
			self.nv_teleport_cooldown = 0
		end

		-- Update cooldown
		self.nv_teleport_cooldown = self.nv_teleport_cooldown + dtime

		-- Use teleport ability if cooldown is ready (20 seconds)
		if self.nv_teleport_cooldown >= 20 then
			if lualore.wizard_magic.red_self_teleport(self) then
				self.nv_teleport_cooldown = 0
			end
		end

		-- Regular attack behavior
		lualore.wizard_magic.wizard_attack(self, dtime, "red")
	end
end

function lualore.wizard_magic.white_do_custom(self, dtime)
	if self.attack and self.state == "attack" then
		lualore.wizard_magic.wizard_attack(self, dtime, "white")
	end
end

function lualore.wizard_magic.gold_do_custom(self, dtime)
	if self.attack and self.state == "attack" then
		-- Initialize levitate cooldown timer
		if not self.nv_levitate_cooldown then
			self.nv_levitate_cooldown = 30  -- Start ready
		end

		-- Update cooldown
		self.nv_levitate_cooldown = self.nv_levitate_cooldown + dtime

		-- Handle ongoing levitation
		if self.nv_levitating then
			self.nv_levitate_timer = self.nv_levitate_timer + dtime

			local pos = self.object:get_pos()
			if pos then
				-- Check if reached 3 nodes high or 3 seconds passed
				local height_gained = pos.y - self.nv_levitate_start_y

				if height_gained >= 3 or self.nv_levitate_timer >= 3 then
					-- Stop levitating
					self.nv_levitating = false
					self.nv_levitate_timer = 0

					-- Set gentle downward velocity
					local vel = self.object:get_velocity()
					self.object:set_velocity({x = vel.x, y = -2, z = vel.z})

					-- Ending particle effect
					minetest.add_particlespawner({
						amount = 30,
						time = 0.5,
						minpos = {x = pos.x - 0.5, y = pos.y, z = pos.z - 0.5},
						maxpos = {x = pos.x + 0.5, y = pos.y + 1, z = pos.z + 0.5},
						minvel = {x = -1, y = -1, z = -1},
						maxvel = {x = 1, y = 0.5, z = 1},
						minacc = {x = 0, y = -2, z = 0},
						maxacc = {x = 0, y = -3, z = 0},
						minexptime = 0.8,
						maxexptime = 1.5,
						minsize = 1.5,
						maxsize = 3,
						collisiondetection = false,
						texture = "lualore_particle_star.png^[colorize:yellow:180",
						glow = 12,
					})
				else
					-- Continue levitating - maintain upward force
					local vel = self.object:get_velocity()
					if vel.y < 3 then
						self.object:set_velocity({x = vel.x, y = 4, z = vel.z})
					end

					-- Continuous golden particles while levitating
					if math.random() < 0.3 then
						minetest.add_particlespawner({
							amount = 3,
							time = 0.2,
							minpos = {x = pos.x - 0.3, y = pos.y, z = pos.z - 0.3},
							maxpos = {x = pos.x + 0.3, y = pos.y + 0.5, z = pos.z + 0.3},
							minvel = {x = -0.2, y = 0.5, z = -0.2},
							maxvel = {x = 0.2, y = 1, z = 0.2},
							minacc = {x = 0, y = 0.2, z = 0},
							maxacc = {x = 0, y = 0.5, z = 0},
							minexptime = 0.5,
							maxexptime = 1,
							minsize = 1.5,
							maxsize = 2.5,
							collisiondetection = false,
							texture = "lualore_particle_arrow_up.png^[colorize:yellow:180",
							glow = 12,
						})
					end
				end
			end
		else
			-- Use levitate ability if cooldown is ready (30 seconds)
			if self.nv_levitate_cooldown >= 30 then
				if lualore.wizard_magic.gold_self_levitate(self) then
					self.nv_levitate_cooldown = 0
				end
			end
		end

		-- Regular attack behavior
		lualore.wizard_magic.wizard_attack(self, dtime, "gold")
	end
end

function lualore.wizard_magic.black_do_custom(self, dtime)
	if self.attack and self.state == "attack" then
		lualore.wizard_magic.wizard_attack(self, dtime, "black")
	end
end

print(S("[MOD] Lualore - Wizard magic system loaded"))
