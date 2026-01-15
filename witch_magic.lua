-- witch_magic.lua
-- Magic system for witch monsters, inspired by witches mod
-- Uses greeting particles instead of texture-based particles

local S = minetest.get_translator("lualore")

lualore.witch_magic = {}

--------------------------------------------------------------------
-- PARTICLE EFFECTS (using greeting particles style)
--------------------------------------------------------------------

-- Helper function to convert position to volume bounds
local function pos_to_vol(pos, vol)
	local pv1 = vector.subtract(pos, vector.divide(vol, 2))
	local pv2 = vector.add(pv1, vol)
	return {pv1, pv2}
end

-- Area effect using greeting-style particles
function lualore.witch_magic.effect_area(pos1, pos2, density, color)
	density = density or 100
	color = color or "purple"

	minetest.add_particlespawner({
		amount = density,
		time = 0.1,
		minpos = pos1,
		maxpos = pos2,
		minvel = {x = 0, y = 0, z = 0},
		maxvel = {x = 0, y = 1, z = 0},
		minacc = {x = 0, y = 0, z = 0},
		maxacc = {x = 0, y = 1, z = 0},
		minexptime = 0.01,
		maxexptime = 0.5,
		minsize = 0.3,
		maxsize = 0.6,
		collisiondetection = false,
		texture = "default_cloud.png^[colorize:" .. color .. ":150",
		glow = 10,
	})
end

-- Line effect using greeting-style particles
function lualore.witch_magic.effect_line(pos1, pos2, density, color)
	pos1 = vector.round(pos1)
	pos2 = vector.round(pos2)
	density = density or 10
	color = color or "purple"

	local dv = vector.direction(pos1, pos2)
	local vd = math.floor(vector.distance(pos1, pos2))
	local v_pos1 = pos1
	local v_pos2 = pos1

	for i = 1, vd do
		v_pos2 = vector.add(v_pos1, dv)

		minetest.add_particlespawner({
			amount = density,
			time = 0.1,
			minpos = v_pos1,
			maxpos = v_pos2,
			minvel = {x = 0, y = 0, z = 0},
			maxvel = {x = 0, y = 1, z = 0},
			minacc = {x = 0, y = 0, z = 0},
			maxacc = {x = 0, y = 1, z = 0},
			minexptime = 0.01,
			maxexptime = 0.5,
			minsize = 0.3,
			maxsize = 0.6,
			collisiondetection = false,
			texture = "default_cloud.png^[colorize:" .. color .. ":150",
			glow = 10,
		})
		v_pos1 = v_pos2
	end
end

--------------------------------------------------------------------
-- TELEPORT ATTACK (Main witch attack)
--------------------------------------------------------------------
function lualore.witch_magic.teleport_attack(self, target, distance)
	if not self or not self.object then return false end
	if not target then return false end

	local caster_pos = self.object:get_pos()
	if not caster_pos then return false end

	-- Play magic sound (quieter)
	minetest.sound_play("magic", {
		pos = caster_pos,
		gain = 0.1,
		max_hear_distance = 16
	}, true)

	distance = distance or 10

	local target_pos = nil

	-- Get target position
	if target:is_player() then
		target_pos = target:get_pos()
	elseif target:get_luaentity() then
		target_pos = target:get_pos()
	else
		return false
	end

	if not target_pos then return false end

	-- Calculate random direction for teleport (10 blocks away)
	local angle = math.random() * math.pi * 2  -- Random angle 0 to 2π
	local offset_x = math.cos(angle) * distance
	local offset_z = math.sin(angle) * distance

	local new_target_pos = {
		x = target_pos.x + offset_x,
		y = target_pos.y,  -- Keep same Y level
		z = target_pos.z + offset_z
	}

	-- Teleport the target
	target:set_pos(new_target_pos)

	-- Visual effects using greeting-style particles
	lualore.witch_magic.effect_line(caster_pos, new_target_pos, 50, "purple")

	local vol = pos_to_vol(caster_pos, vector.new(2, 2, 2))
	lualore.witch_magic.effect_area(vol[1], vol[2], 100, "purple")

	-- NO DAMAGE - teleport only!
	-- Melee punch (dogfight) attack handles damage separately

	return true
end

--------------------------------------------------------------------
-- CUSTOM ATTACK BEHAVIOR
--------------------------------------------------------------------
function lualore.witch_magic.custom_attack(self, dtime)
	-- Only attack if we have a target
	if not self.attack then return false end
	if not self.object then return false end

	-- Initialize attack timer
	if not self.nv_magic_attack_timer then
		self.nv_magic_attack_timer = 0
	end

	-- Initialize attack cooldown
	if not self.nv_magic_attack_cooldown then
		self.nv_magic_attack_cooldown = 2  -- 2 seconds between magic attacks (more frequent than melee)
	end

	self.nv_magic_attack_timer = self.nv_magic_attack_timer + dtime

	-- Check if cooldown has passed
	if self.nv_magic_attack_timer < self.nv_magic_attack_cooldown then
		return false
	end

	-- Check distance to target
	local pos = self.object:get_pos()
	if not pos then return false end

	local target_pos = self.attack:get_pos()
	if not target_pos then return false end

	local distance = vector.distance(pos, target_pos)

	-- Only attack if within magic range (1-5 blocks)
	if distance > 5 then return false end
	if distance < 1 then return false end  -- Too close (within 1 block), use melee instead

	-- Perform teleport attack (10 blocks in random direction)
	local success = lualore.witch_magic.teleport_attack(self, self.attack, 10)

	if success then
		-- Reset timer
		self.nv_magic_attack_timer = 0
		return true
	end

	return false
end

--------------------------------------------------------------------
-- WITCH-SPECIFIC DO_CUSTOM FUNCTION
--------------------------------------------------------------------
function lualore.witch_magic.do_custom(self, dtime)
	-- Handle magic attacks
	if self.attack and self.state == "attack" then
		lualore.witch_magic.custom_attack(self, dtime)
	end

	-- Continue with normal behavior updates
	local success, err = pcall(function()
		-- Update mood system
		if lualore.mood then
			lualore.mood.update_mood(self, dtime)
		end

		-- Update enhanced behaviors (including door waiting for all entity types)
		if lualore.behaviors then
			-- Only call handle_door_waiting for monsters, skip other behaviors
			if self.type == "monster" then
				lualore.behaviors.handle_door_waiting(self)
			else
				lualore.behaviors.update(self, dtime)
			end
		end
	end)

	if not success then
		minetest.log("warning", "[lualore] witch do_custom error: " .. tostring(err))
	end
end

print(S("[MOD] LuaLore - Witch magic system loaded"))
