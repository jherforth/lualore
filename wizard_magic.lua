-- wizard_magic.lua
-- Magic system for cave wizards boss fight
-- Four wizards with unique spell attacks

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

	-- Play magic sound
	minetest.sound_play("magic", {
		pos = caster_pos,
		gain = 0.3,
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

	-- Play magic sound
	minetest.sound_play("magic", {
		pos = caster_pos,
		gain = 0.3,
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

	-- Visual effect
	spawn_spiral_particles(target_pos, "red", 5, 1)

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

	-- Play magic sound
	minetest.sound_play("magic", {
		pos = caster_pos,
		gain = 0.3,
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
	player_effects[player_name].sick_freeze_timer = 0

	-- Visual effect
	spawn_spiral_particles(target_pos, "green", 15, 1)

	-- Initial damage
	target:set_hp(target:get_hp() - 2)

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

	-- Play magic sound
	minetest.sound_play("magic", {
		pos = caster_pos,
		gain = 0.3,
		max_hear_distance = 32
	}, true)

	-- Spell projectile
	spawn_spell_projectile(caster_pos, target_pos, "white")

	-- Setup effect
	if not player_effects[player_name] then
		player_effects[player_name] = {}
	end

	local old_physics = target:get_physics_override()
	player_effects[player_name].hyper_curse = true
	player_effects[player_name].hyper_timer = 15
	player_effects[player_name].old_physics = old_physics

	-- Apply hyper speed
	target:set_physics_override({
		speed = (old_physics.speed or 1) * 3,
		jump = (old_physics.jump or 1) * 2
	})

	-- Visual effect
	spawn_spiral_particles(target_pos, "white", 15, 1)

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

	-- Play magic sound
	minetest.sound_play("magic", {
		pos = caster_pos,
		gain = 0.3,
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
	player_effects[player_name].levitate_timer = 3
	player_effects[player_name].levitate_height = 0
	player_effects[player_name].old_physics = old_physics

	-- Apply negative gravity to float up
	target:set_physics_override({
		gravity = -0.1
	})

	-- Visual effect
	spawn_spiral_particles(target_pos, "blue", 6, 1)

	return true
end

-- Spell 2: Shrinking Curse (yellow particles, shrink player for 15 seconds)
function lualore.wizard_magic.gold_transform(self, target)
	if not self or not self.object or not target or not target:is_player() then return false end

	local caster_pos = self.object:get_pos()
	local target_pos = target:get_pos()
	if not caster_pos or not target_pos then return false end

	local player_name = target:get_player_name()

	-- Check if player already has this effect
	if player_effects[player_name] and player_effects[player_name].shrunken then
		return false
	end

	-- Play magic sound
	minetest.sound_play("magic", {
		pos = caster_pos,
		gain = 0.3,
		max_hear_distance = 32
	}, true)

	-- Spell projectile
	spawn_spell_projectile(caster_pos, target_pos, "yellow")

	-- Setup effect
	if not player_effects[player_name] then
		player_effects[player_name] = {}
	end

	-- Store old values
	local old_physics = target:get_physics_override()
	local old_visual_size = target:get_properties().visual_size
	local old_fov = target:get_fov()

	player_effects[player_name].shrunken = true
	player_effects[player_name].shrink_timer = 10
	player_effects[player_name].old_shrink_physics = old_physics
	player_effects[player_name].old_visual_size = old_visual_size
	player_effects[player_name].old_fov = old_fov

	-- Shrink player model to half size
	target:set_properties({
		visual_size = {x = old_visual_size.x * 0.5, y = old_visual_size.y * 0.5}
	})

	-- Slow player down
	target:set_physics_override({
		speed = 0.5,
		jump = 0.7
	})

	-- Shrink field of view
	target:set_fov(0.8, false, 0.8)

	-- Visual effect
	spawn_spiral_particles(target_pos, "yellow", 2, 1.5)

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

	-- Play magic sound
	minetest.sound_play("magic", {
		pos = caster_pos,
		gain = 0.3,
		max_hear_distance = 32
	}, true)

	-- Spell projectile
	spawn_spell_projectile(caster_pos, target_pos, "black")

	-- Setup effect
	if not player_effects[player_name] then
		player_effects[player_name] = {}
	end

	player_effects[player_name].blinded = true
	player_effects[player_name].blind_timer = 10
	player_effects[player_name].blind_particles = {}

	-- Create a dense cloud of large black particles that stays attached to player view
	-- We'll create multiple particle spawners for full coverage
	for i = 1, 5 do
		local spawner_id = minetest.add_particlespawner({
			amount = 100,
			time = 0,  -- Infinite spawner
			minpos = {x = -0.1, y = -0.1, z = 0.1},
			maxpos = {x = 0.1, y = 0.1, z = 0.3},
			minvel = {x = 0, y = 0, z = 0},
			maxvel = {x = 0, y = 0, z = 0},
			minacc = {x = 0, y = 0, z = 0},
			maxacc = {x = 0, y = 0, z = 0},
			minexptime = 0.5,
			maxexptime = 1.0,
			minsize = 20,
			maxsize = 30,
			collisiondetection = false,
			attached = target,
			texture = "default_cloud.png^[colorize:black:255",
			glow = 0,
		})
		table.insert(player_effects[player_name].blind_particles, spawner_id)
	end

	return true
end

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

					-- Green particle burst
					local pos = player:get_pos()
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
						texture = "default_cloud.png^[colorize:green:200",
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

			if effects.hyper_timer <= 0 then
				effects.hyper_curse = nil
				if effects.old_physics then
					player:set_physics_override(effects.old_physics)
					effects.old_physics = nil
				end
			end
		end

		-- Levitate
		if effects.levitate then
			effects.levitate_timer = effects.levitate_timer - 0.1
			local pos = player:get_pos()

			if effects.levitate_timer > 0 then
				-- Still rising
				effects.levitate_height = effects.levitate_height + 0.5
			elseif effects.levitate_timer > -3 then
				-- Drop phase (3 seconds)
				if effects.levitate_timer == 0 or (effects.levitate_timer < 0 and effects.levitate_timer > -0.1) then
					-- Switch to normal gravity to fall
					player:set_physics_override({gravity = 1})
				end
			else
				-- Effect over
				effects.levitate = nil
				if effects.old_physics then
					player:set_physics_override(effects.old_physics)
					effects.old_physics = nil
				end
			end
		end

		-- Shrinking
		if effects.shrunken then
			effects.shrink_timer = effects.shrink_timer - 0.1

			if effects.shrink_timer <= 0 then
				effects.shrunken = nil

				-- Restore original visual size
				if effects.old_visual_size then
					player:set_properties({
						visual_size = effects.old_visual_size
					})
					effects.old_visual_size = nil
				end

				-- Restore original physics
				if effects.old_shrink_physics then
					player:set_physics_override(effects.old_shrink_physics)
					effects.old_shrink_physics = nil
				end

				-- Restore original FOV
				if effects.old_fov then
					player:set_fov(effects.old_fov, false, 0.5)
					effects.old_fov = nil
				end

				-- Shrink end particles
				local pos = player:get_pos()
				spawn_spiral_particles(pos, "yellow", 1, 1.5)
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
		self.nv_wizard_attack_cooldown = 2.5
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
		self.nv_wizard_attack_timer = 0
		return true
	end

	return false
end

--------------------------------------------------------------------
-- WIZARD-SPECIFIC DO_CUSTOM FUNCTIONS
--------------------------------------------------------------------

function lualore.wizard_magic.red_do_custom(self, dtime)
	if self.attack and self.state == "attack" then
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
		lualore.wizard_magic.wizard_attack(self, dtime, "gold")
	end
end

function lualore.wizard_magic.black_do_custom(self, dtime)
	if self.attack and self.state == "attack" then
		lualore.wizard_magic.wizard_attack(self, dtime, "black")
	end
end

print(S("[MOD] Lualore - Wizard magic system loaded"))
