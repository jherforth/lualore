-- villager_behaviors.lua
-- Enhanced villager AI: sleep, daily routines, social interactions, food sharing, door usage

local S = minetest.get_translator("lualore")

lualore.behaviors = {}

--------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------
lualore.behaviors.config = {
	home_radius = 5,  -- Night time radius (close to bed)
	daytime_home_radius = 30,  -- Day time radius (larger roaming area)
	sleep_radius = 3,
	-- How close to the bed counts as "home". Three nodes was enough to
	-- stop a villager dead in its own doorway, blocking the door it had
	-- just opened; two puts it properly in the room.
	bed_arrival = 2,
	social_detection_radius = 5,
	food_share_detection_radius = 8,
	social_interaction_cooldown = 300,  -- 5 minutes between socializations with same villager
	food_share_cooldown = 60,
	stuck_teleport_threshold = 300,
	npc_seek_radius = 25,
	-- State-based behavior durations (in seconds)
	state_wander_duration = 90,   -- Longer wander to give distance after socializing
	state_social_duration = 20,   -- Short socializing burst, then wander away
	state_rest_duration = 25,
	state_work_duration = 120,  -- a shift at the workstation
	-- Distance limits
	spawn_wander_radius = 30,
	max_distance_from_spawn = 50,
	-- Food drop visual system
	food_drop_duration = 2,       -- Seconds the food item sits on the ground
}

--------------------------------------------------------------------
-- TIME OF DAY HELPERS
--------------------------------------------------------------------
function lualore.behaviors.get_time_of_day()
	return minetest.get_timeofday()
end

function lualore.behaviors.get_time_period()
	local tod = lualore.behaviors.get_time_of_day()

	if tod >= 0.0 and tod < 0.25 then
		return "night"
	elseif tod >= 0.25 and tod < 0.35 then
		return "morning"
	elseif tod >= 0.35 and tod < 0.65 then
		return "afternoon"
	elseif tod >= 0.65 and tod < 0.75 then
		return "evening"
	else
		return "night"
	end
end

function lualore.behaviors.is_night_time()
	local tod = lualore.behaviors.get_time_of_day()
	-- 10PM = 0.9167, 6AM = 0.25
	-- Night time is from 10PM (0.9167) to 6AM (0.25)
	return (tod >= 0.9167 or tod < 0.25)
end

function lualore.behaviors.is_day_time()
	return not lualore.behaviors.is_night_time()
end

-- Villagers set off home at dusk rather than at the stroke of night, so
-- they are indoors around the time the doors shut (smart_doors closes
-- them at 10PM and opens them again at 6AM).
function lualore.behaviors.is_home_time()
	local tod = lualore.behaviors.get_time_of_day()
	return tod >= 0.79 or tod < 0.25
end

--------------------------------------------------------------------
-- STATE MACHINE DEFINITIONS
--------------------------------------------------------------------
lualore.behaviors.states = {
	WANDERING = "wandering",
	SOCIALIZING = "socializing",
	RESTING = "resting",
	WORKING = "working",
}

--------------------------------------------------------------------
-- HOUSE POSITION MANAGEMENT
--------------------------------------------------------------------
function lualore.behaviors.init_house(self)
	if not self.nv_house_pos then
		self.nv_house_pos = nil
		self.nv_home_radius = lualore.behaviors.config.home_radius
		self.nv_sleeping = false
		self.nv_stuck_timer = 0
	end

	-- Initialize state machine fields
	if not self.nv_behavior_state then
		self.nv_behavior_state = lualore.behaviors.states.SOCIALIZING  -- Start in socializing mode
		self.nv_state_timer = 0
		self.nv_state_target_reached = false
	end

	-- Initialize spawn position (separate from bed/house)
	if not self.nv_spawn_pos and self.object then
		local pos = self.object:get_pos()
		if pos then
			self.nv_spawn_pos = vector.new(pos.x, pos.y, pos.z)
		end
	end
end

function lualore.behaviors.get_house_position(self)
	return self.nv_house_pos
end

function lualore.behaviors.has_house(self)
	return self.nv_house_pos ~= nil
end

--------------------------------------------------------------------
-- DOOR INTERACTION SYSTEM
--------------------------------------------------------------------
-- Villagers open the door they are about to walk through and close it
-- again once they are clear of it.
--
-- What was here before could not work, for three reasons, all of them in
-- the "is this door closed?" test:
--
--   * It only counted `_b` doors as closed. Which hinge a door uses is
--     whatever the schematic stored, and `_a` is just as closed - of the
--     nine closed door variants actually present in this mod's
--     schematics it recognised two.
--   * It counted `doors:hidden` as a closed door. That node is the
--     invisible upper half of EVERY door, open or shut, so a villager
--     within a few nodes of any doorway went into a "wait for the door"
--     state, stood still for eight seconds and then threw its
--     destination away. That is why they never made it home.
--   * It only matched `doors:door_*`, so the Everness doors used by
--     several house schematics were invisible to it.
--
-- The classification now lives in one place, smart_doors.lua, which the
-- scheduled 6AM/10PM sweep uses as well.
--------------------------------------------------------------------
local DOOR_REACH         = 2     -- how far a villager reaches for a door
local DOOR_SCAN_INTERVAL = 0.4   -- seconds between door scans
local DOOR_CLEAR         = 1.8   -- far enough past a door to shut it
local DOOR_FORGET        = 6     -- far enough away to stop minding it

-- Point the villager at where it should walk NEXT, which is not always
-- where it wants to end up: villager_path.lua routes round corners and
-- through doorways. With that module absent this is the old behaviour,
-- a straight line at the goal.
--
-- Returns the point being steered at, so callers can use it as the
-- nav target for door opening.
function lualore.behaviors.steer(self, goal, dtime)
	if not self.object or not goal then
		return goal
	end
	local pos = self.object:get_pos()
	if not pos then
		return goal
	end
	local step = goal
	if lualore.path and lualore.path.next_step then
		step = lualore.path.next_step(self, goal, dtime or 0) or goal
	end
	self.object:set_yaw(minetest.dir_to_yaw(vector.direction(pos, step)))
	return step
end

-- Is anybody else standing in the doorway? Never shut a door on them.
function lualore.behaviors.doorway_busy(door_pos, me)
	local myself = me and me.object
	for _, obj in ipairs(minetest.get_objects_inside_radius(door_pos, 1.6)) do
		if obj ~= myself then
			if obj:is_player() then
				return true
			end
			local ent = obj:get_luaentity()
			if ent and ent.name and ent.name:find("lualore:", 1, true) == 1 then
				return true
			end
		end
	end
	return false
end

function lualore.behaviors.handle_doors(self, dtime, nav_target)
	local doors_api = lualore.smart_doors
	if not (doors_api and doors_api.find_closed_near) then return end
	if not self.object then return end
	local pos = self.object:get_pos()
	if not pos then return end

	self.nv_door_timer = (self.nv_door_timer or 0) + (dtime or 0)
	if self.nv_door_timer < DOOR_SCAN_INTERVAL then return end
	self.nv_door_timer = 0

	-- ---------------------------------------------------------------
	-- Shutting the one we opened
	-- ---------------------------------------------------------------
	-- Only ever once, and only after the crossing is finished. The first
	-- version also shut a door on a timeout, which is what made them
	-- clatter: a villager that opened a door and then did not get
	-- through would have it shut again ten seconds later, walk back up to
	-- it, open it again, and so on for as long as it kept failing.
	local mine = self.nv_door_opened
	if mine then
		local dist = vector.distance(pos, mine)
		local crossing = lualore.path and lualore.path.crossing
			and lualore.path.crossing(self)
		local still_using = crossing
			and vector.distance(crossing, mine) < 1.5

		if not still_using and dist > DOOR_CLEAR then
			if not lualore.behaviors.doorway_busy(mine, self) then
				doors_api.set(mine, false)
			end
			self.nv_door_opened = nil
			self.nv_door_from = nil
		elseif not still_using and dist > DOOR_FORGET then
			-- Wandered off without crossing. Leave it open rather than
			-- reaching across the village to shut it; the village sweep
			-- closes everything at ten anyway.
			self.nv_door_opened = nil
			self.nv_door_from = nil
		end
	end

	-- ---------------------------------------------------------------
	-- Opening the one in front of us
	-- ---------------------------------------------------------------
	-- A journey knows exactly which door it means to use, so use that
	-- when there is one and fall back to "whatever is in front of me"
	-- otherwise.
	local target_door = lualore.path and lualore.path.crossing
		and lualore.path.crossing(self)

	local door_pos
	if target_door and doors_api.is_closed
			and doors_api.is_closed(minetest.get_node(target_door).name) then
		-- Only from close enough to be at it, or a villager would open
		-- doors from across the village.
		if vector.distance(pos, target_door) <= DOOR_REACH + 1 then
			door_pos = target_door
		end
	else
		door_pos = doors_api.find_closed_near(pos, DOOR_REACH)
		-- Without a journey, only open a door we are squarely heading
		-- into. A plain "is it vaguely that way" test was too generous:
		-- a villager that had just left its house and was walking round
		-- the outside kept passing its own front door at an angle the
		-- test accepted, opening and shutting it each time.
		if door_pos and nav_target then
			local to_door = vector.direction(pos, door_pos)
			local to_goal = vector.direction(pos, nav_target)
			if (to_door.x * to_goal.x + to_door.z * to_goal.z) < 0.6 then
				door_pos = nil
			end
		end
		-- And only while actually going somewhere.
		if door_pos and self.state ~= "walk" then
			door_pos = nil
		end
	end
	if not door_pos then return end

	-- Already holding one open? Don't start on another.
	if self.nv_door_opened then return end

	if doors_api.set(door_pos, true) then
		self.nv_door_opened = vector.new(door_pos)
		self.nv_door_from = vector.new(pos)
		self.nv_door_opened_at = minetest.get_gametime()
	end
end

--------------------------------------------------------------------
-- NIGHT-TIME BED PATHFINDING (Simplified - no sleeping animation)
--------------------------------------------------------------------
function lualore.behaviors.should_go_to_bed(self)
	return lualore.behaviors.is_home_time() and lualore.behaviors.has_house(self)
end

function lualore.behaviors.is_at_house(self)
	if not lualore.behaviors.has_house(self) then return false end
	if not self.object then return false end

	local pos = self.object:get_pos()
	if not pos then return false end

	local house_pos = lualore.behaviors.get_house_position(self)
	local dist = vector.distance(pos, house_pos)

	if dist > lualore.behaviors.config.bed_arrival then
		return false
	end
	-- Being close to the bed is not the same as being in the room with
	-- it: a bed against an outside wall would otherwise let a villager
	-- "arrive" while still standing in the street. Right next to it we
	-- take it on trust, since furniture can break the sight line.
	if dist <= 1.5 then
		return true
	end
	local eye = {x = pos.x, y = pos.y + 1, z = pos.z}
	local bed = {x = house_pos.x, y = house_pos.y + 0.5, z = house_pos.z}
	return minetest.line_of_sight(eye, bed) == true
end


--------------------------------------------------------------------
-- DAILY ROUTINE & MOVEMENT
--------------------------------------------------------------------
function lualore.behaviors.get_activity_radius(self)
	local period = lualore.behaviors.get_time_period()

	-- Use different base radius for day vs night
	local base_radius
	if period == "night" then
		base_radius = lualore.behaviors.config.home_radius  -- 5 blocks at night
	else
		base_radius = lualore.behaviors.config.daytime_home_radius  -- 30 blocks during day
	end

	if period == "morning" then
		return base_radius * 0.8
	elseif period == "afternoon" then
		return base_radius * 1.0
	elseif period == "evening" then
		return base_radius * 0.9
	else
		return lualore.behaviors.config.sleep_radius
	end
end

-- Where a villager should be heading right now, or nil to let the
-- daytime state machine decide. Doors are no longer part of this: the
-- villager opens whatever is in the way as it reaches it, so the route
-- is simply "the bed" rather than a chain of door waypoints.
function lualore.behaviors.update_movement_target(self)
	if not lualore.behaviors.has_house(self) then return end
	if not self.object then return end

	if lualore.behaviors.is_home_time()
			and not lualore.behaviors.is_at_house(self) then
		return lualore.behaviors.get_house_position(self)
	end

	return nil
end

function lualore.behaviors.check_stuck_and_recover(self, dtime)
	if not lualore.behaviors.has_house(self) then return end
	if not self.object then return end

	local pos = self.object:get_pos()
	if not pos then return end

	local house_pos = lualore.behaviors.get_house_position(self)
	local dist = vector.distance(pos, house_pos)
	local max_radius = lualore.behaviors.get_activity_radius(self) * 1.5

	if dist > max_radius then
		self.nv_stuck_timer = (self.nv_stuck_timer or 0) + dtime

		if self.nv_stuck_timer >= lualore.behaviors.config.stuck_teleport_threshold then
			local teleport_pos = {
				x = house_pos.x + math.random(-3, 3),
				y = house_pos.y,
				z = house_pos.z + math.random(-3, 3)
			}
			self.object:set_pos(teleport_pos)
			self.nv_stuck_timer = 0
		end
	else
		self.nv_stuck_timer = 0
	end
end

function lualore.behaviors.flee_to_house_on_low_health(self)
	if not self.health then return false end
	if not lualore.behaviors.has_house(self) then return false end

	if self.health < (self.hp_max or 20) * 0.3 then
		if self.object then
			local house_pos = lualore.behaviors.get_house_position(self)
			return house_pos
		end
	end

	return false
end


--------------------------------------------------------------------
-- SOCIAL INTERACTIONS (Villager-to-Villager)
--------------------------------------------------------------------
function lualore.behaviors.find_nearby_villagers(self, radius)
	if not self.object then return {} end
	local pos = self.object:get_pos()
	if not pos then return {} end

	radius = radius or lualore.behaviors.config.social_detection_radius
	local objects = minetest.get_objects_inside_radius(pos, radius)
	local nearby_villagers = {}

	for _, obj in ipairs(objects) do
		if obj ~= self.object then
			local ent = obj:get_luaentity()
			if ent and ent.name and string.match(ent.name, "lualore:") and ent.type == "npc" then
				table.insert(nearby_villagers, ent)
			end
		end
	end

	return nearby_villagers
end

function lualore.behaviors.find_npc_to_socialize_with(self)
	local nearby = lualore.behaviors.find_nearby_villagers(self, lualore.behaviors.config.npc_seek_radius)
	if #nearby == 0 then return nil end

	local pos = self.object:get_pos()
	if not pos then return nil end

	local current_time = minetest.get_gametime()
	if not self.nv_social_partner_cooldowns then
		self.nv_social_partner_cooldowns = {}
	end

	local closest_npc = nil
	local closest_dist = 999

	for _, npc in ipairs(nearby) do
		if npc.object then
			local npc_pos = npc.object:get_pos()
			if npc_pos then
				local dist = vector.distance(pos, npc_pos)
				local npc_id = tostring(npc.object)
				-- No entry means "never socialised with this one", which is
				-- not a cooldown. Defaulting the stamp to 0 made
				-- `now - 0 < 300` true for the first five minutes of world
				-- time, so on a fresh world nobody would socialise with
				-- anybody - exactly while a new village is being watched.
				local last_time = self.nv_social_partner_cooldowns[npc_id]
				local on_cooldown = last_time ~= nil
					and (current_time - last_time)
						< lualore.behaviors.config.social_interaction_cooldown

				if dist > 2 and dist < closest_dist and not on_cooldown then
					closest_dist = dist
					closest_npc = npc
				end
			end
		end
	end

	return closest_npc
end

function lualore.behaviors.should_socialize(self)
	if not self.nv_last_social_time then
		self.nv_last_social_time = 0
	end

	local current_time = minetest.get_gametime()
	return (current_time - self.nv_last_social_time) >= 10
end

function lualore.behaviors.emit_social_particles(pos1, pos2)
	local mid_pos = {
		x = (pos1.x + pos2.x) / 2,
		y = (pos1.y + pos2.y) / 2 + 1,
		z = (pos1.z + pos2.z) / 2,
	}

	minetest.add_particlespawner({
		amount = 40,
		time = 1,
		minpos = {x = mid_pos.x - 0.3, y = mid_pos.y, z = mid_pos.z - 0.3},
		maxpos = {x = mid_pos.x + 0.3, y = mid_pos.y + 0.5, z = mid_pos.z + 0.3},
		minvel = {x = 0, y = 0.5, z = 0},
		maxvel = {x = 0, y = 1.0, z = 0},
		minacc = {x = 0, y = 0, z = 0},
		maxacc = {x = 0, y = 0, z = 0},
		minexptime = 1,
		maxexptime = 2,
		minsize = 0.25,
		maxsize = 0.5,
		texture = "lualore_mood_happy.png",
		glow = 5,
	})
end

function lualore.behaviors.handle_social_interactions(self)
	if not lualore.behaviors.should_socialize(self) then return end

	local nearby = lualore.behaviors.find_nearby_villagers(self)
	if #nearby == 0 then return end

	local pos1 = self.object:get_pos()
	if not pos1 then return end

	if not self.nv_social_partner_cooldowns then
		self.nv_social_partner_cooldowns = {}
	end

	local current_time = minetest.get_gametime()

	for _, other in ipairs(nearby) do
		if other.object then
			local pos2 = other.object:get_pos()
			if pos2 then
				lualore.behaviors.emit_social_particles(pos1, pos2)

				if self.nv_mood == "happy" or self.nv_mood == "content" then
					if other.nv_mood_value then
						other.nv_mood_value = math.min(100, (other.nv_mood_value or 50) + 5)
					end
				end

				if self.nv_loneliness then
					self.nv_loneliness = math.max(0, self.nv_loneliness - 15)
				end

				-- Stamp per-pair cooldown so they won't seek each other for 5 minutes
				local other_id = tostring(other.object)
				self.nv_social_partner_cooldowns[other_id] = current_time

				-- Also stamp on the other villager so they won't come back either
				if not other.nv_social_partner_cooldowns then
					other.nv_social_partner_cooldowns = {}
				end
				other.nv_social_partner_cooldowns[tostring(self.object)] = current_time

				break
			end
		end
	end

	self.nv_last_social_time = current_time

	-- Force transition to WANDERING so villagers separate after socializing
	lualore.behaviors.transition_state(self, lualore.behaviors.states.WANDERING)
end

--------------------------------------------------------------------
-- FOOD SHARING SYSTEM (Visual Drop)
--------------------------------------------------------------------
function lualore.behaviors.find_hungry_villager_nearby(self)
	if not self.object then return nil end
	local pos = self.object:get_pos()
	if not pos then return nil end

	local radius = lualore.behaviors.config.food_share_detection_radius
	local objects = minetest.get_objects_inside_radius(pos, radius)

	for _, obj in ipairs(objects) do
		if obj ~= self.object then
			local ent = obj:get_luaentity()
			if ent and ent.name and string.match(ent.name, "lualore:") and ent.type == "npc" then
				if ent.nv_hunger and ent.nv_hunger > 85 then
					return ent
				end
			end
		end
	end

	return nil
end

function lualore.behaviors.should_share_food(self)
	if not self.nv_last_food_share_time then
		self.nv_last_food_share_time = 0
	end

	if not self.nv_hunger or self.nv_hunger > 30 then
		return false
	end

	if self.nv_food_drop_pending then
		return false
	end

	local current_time = minetest.get_gametime()
	return (current_time - self.nv_last_food_share_time) >= lualore.behaviors.config.food_share_cooldown
end

function lualore.behaviors.emit_eat_particles(pos)
	minetest.add_particlespawner({
		amount = 20,
		time = 0.6,
		minpos = {x = pos.x - 0.2, y = pos.y + 1.2, z = pos.z - 0.2},
		maxpos = {x = pos.x + 0.2, y = pos.y + 1.5, z = pos.z + 0.2},
		minvel = {x = -0.5, y = 0.2, z = -0.5},
		maxvel = {x = 0.5, y = 0.8, z = 0.5},
		minacc = {x = 0, y = -2, z = 0},
		maxacc = {x = 0, y = -2, z = 0},
		minexptime = 0.4,
		maxexptime = 0.8,
		minsize = 0.3,
		maxsize = 0.6,
		texture = "farming_bread.png",
		glow = 2,
	})
end

function lualore.behaviors.handle_food_sharing(self)
	if not lualore.behaviors.should_share_food(self) then return end

	local hungry_villager = lualore.behaviors.find_hungry_villager_nearby(self)
	if not hungry_villager then return end

	local pos1 = self.object:get_pos()
	local pos2 = hungry_villager.object:get_pos()
	if not pos1 or not pos2 then return end

	-- Cost the giver a bit of hunger
	self.nv_hunger = math.min(100, (self.nv_hunger or 1) + 15)
	self.nv_last_food_share_time = minetest.get_gametime()
	self.nv_food_drop_pending = true

	-- Drop the food item visually between the two villagers
	local drop_pos = {
		x = pos1.x + (pos2.x - pos1.x) * 0.4,
		y = pos1.y + 0.5,
		z = pos1.z + (pos2.z - pos1.z) * 0.4,
	}

	local food_obj = minetest.add_item(drop_pos, "farming:bread")

	-- Freeze the hungry villager briefly so they "notice" the food
	if hungry_villager.object then
		hungry_villager.nv_walking_to_food = true
		hungry_villager.nv_food_target = drop_pos
		hungry_villager.nv_food_pickup_time = minetest.get_gametime() + lualore.behaviors.config.food_drop_duration
	end

	-- After 2 seconds: remove the item, feed the hungry villager, emit eat particles
	minetest.after(lualore.behaviors.config.food_drop_duration, function()
		if food_obj and food_obj:is_valid() then
			food_obj:remove()
		end

		if hungry_villager and hungry_villager.object and hungry_villager.object:is_valid() then
			hungry_villager.nv_hunger = math.max(1, (hungry_villager.nv_hunger or 1) - 40)
			hungry_villager.nv_walking_to_food = nil
			hungry_villager.nv_food_target = nil
			hungry_villager.nv_food_pickup_time = nil

			if hungry_villager.health and hungry_villager.hp_max then
				hungry_villager.health = math.min(hungry_villager.hp_max, hungry_villager.health + 3)
			end

			if hungry_villager.nv_mood_value then
				hungry_villager.nv_mood_value = math.min(100, (hungry_villager.nv_mood_value or 50) + 15)
			end

			local eat_pos = hungry_villager.object:get_pos()
			if eat_pos then
				lualore.behaviors.emit_eat_particles(eat_pos)
			end

			minetest.sound_play("default_item_smoke", {
				pos = eat_pos or drop_pos,
				gain = 0.4,
				max_hear_distance = 10,
			}, true)
		end

		if self and self.object and self.object:is_valid() then
			self.nv_food_drop_pending = nil
		end
	end)
end

-- Called from the main step to walk the hungry villager toward dropped food
function lualore.behaviors.handle_walk_to_food(self)
	if not self.nv_walking_to_food then return false end
	if not self.nv_food_target then return false end
	if not self.object then return false end

	local pos = self.object:get_pos()
	if not pos then return false end

	local dist = vector.distance(pos, self.nv_food_target)
	if dist > 1.2 then
		self._target = self.nv_food_target
		self.state = "walk"
		self:set_animation("walk")
		lualore.behaviors.steer(self, self.nv_food_target, self.nv_last_dtime)
	else
		self._target = nil
		self.state = "stand"
		self:set_animation("stand")
	end

	return true
end

--------------------------------------------------------------------
-- GREETING PARTICLES
--------------------------------------------------------------------
function lualore.behaviors.emit_greeting_particles(self, player_pos)
	local pos = self.object:get_pos()
	if not pos then return end

	local color = "green"
	if self.state == "attack" or self.type == "monster" then
		color = "red"
	end

	minetest.add_particlespawner({
		amount = 24,
		time = 0.5,
		minpos = {x = pos.x - 0.3, y = pos.y + 1.5, z = pos.z - 0.3},
		maxpos = {x = pos.x + 0.3, y = pos.y + 2.0, z = pos.z + 0.3},
		minvel = {x = 0, y = 0.2, z = 0},
		maxvel = {x = 0, y = 0.5, z = 0},
		minacc = {x = 0, y = 0, z = 0},
		maxacc = {x = 0, y = 0, z = 0},
		minexptime = 0.5,
		maxexptime = 1,
		minsize = 0.25,
		maxsize = 0.4,
		texture = "default_cloud.png^[colorize:" .. color .. ":150",
		glow = 8,
	})
end

function lualore.behaviors.check_nearby_players(self)
	if not self.object then return end
	local pos = self.object:get_pos()
	if not pos then return end

	if not self.nv_last_player_greeting_time then
		self.nv_last_player_greeting_time = 0
	end

	local current_time = minetest.get_gametime()
	if (current_time - self.nv_last_player_greeting_time) < 30 then
		return
	end

	local players = minetest.get_connected_players()
	for _, player in ipairs(players) do
		local player_pos = player:get_pos()
		if player_pos then
			local dist = vector.distance(pos, player_pos)
			if dist < 3 and dist > 1 then
				lualore.behaviors.emit_greeting_particles(self, player_pos)
				self.nv_last_player_greeting_time = current_time
				break
			end
		end
	end
end

--------------------------------------------------------------------
-- STATE MACHINE BEHAVIOR HANDLERS
--------------------------------------------------------------------

-- Get duration for current state
function lualore.behaviors.get_state_duration(state)
	if state == lualore.behaviors.states.WANDERING then
		return lualore.behaviors.config.state_wander_duration
	elseif state == lualore.behaviors.states.SOCIALIZING then
		return lualore.behaviors.config.state_social_duration
	elseif state == lualore.behaviors.states.RESTING then
		return lualore.behaviors.config.state_rest_duration
	elseif state == lualore.behaviors.states.WORKING then
		return lualore.behaviors.config.state_work_duration
	end
	return 60
end

-- Get next state in cycle.
-- The villager jobs module decides the working day when it is loaded and
-- enabled; `self` may be nil, and a nil answer from it means "no job" -
-- either way we fall through to the original wander/socialise cycle, so
-- turning jobs off restores exactly the old behaviour.
function lualore.behaviors.get_next_state(self, current_state)
	if self and lualore.jobs and lualore.jobs.pick_state then
		local picked = lualore.jobs.pick_state(self, current_state)
		if picked then
			return picked
		end
	end
	if current_state == lualore.behaviors.states.WANDERING then
		return lualore.behaviors.states.SOCIALIZING
	elseif current_state == lualore.behaviors.states.SOCIALIZING then
		return lualore.behaviors.states.WANDERING  -- After socializing, wander away
	elseif current_state == lualore.behaviors.states.RESTING
			or current_state == lualore.behaviors.states.WORKING then
		return lualore.behaviors.states.WANDERING
	end
	return lualore.behaviors.states.WANDERING
end

-- Transition to new state
function lualore.behaviors.transition_state(self, new_state)
	-- New job, new route.
	if lualore.path then
		lualore.path.reset(self)
	end
	if new_state ~= lualore.behaviors.states.WORKING then
		self.nv_at_station = false
		self.nv_work_spot = nil
	end
	self.nv_behavior_state = new_state
	self.nv_state_timer = 0
	self.nv_state_target_reached = false
	self._target = nil
	self.state = "stand"
end

-- WANDERING STATE: Free roam with natural movement
function lualore.behaviors.handle_wandering_state(self)
	if not self.object then return false end

	-- Clear any forced targets to allow natural mobs_redo wandering
	if self._target then
		self._target = nil
	end

	return false
end

-- SOCIALIZING STATE: Seek nearby villagers (aggressive version)
function lualore.behaviors.handle_socializing_state(self)
	if not self.object then return false end
	local pos = self.object:get_pos()
	if not pos then return false end

	-- Look for nearby villagers - continuously update target, not just once
	local target_npc = lualore.behaviors.find_npc_to_socialize_with(self)
	if target_npc and target_npc.object then
		local npc_pos = target_npc.object:get_pos()
		if npc_pos then
			local dist = vector.distance(pos, npc_pos)

			-- If very close, stand and socialize
			if dist <= 3 then
				self._target = nil
				self.state = "stand"
				self:set_animation("stand")
				return true
			end

			-- Move towards the villager. Any door in the way is opened by
			-- handle_doors(), so we head straight for them.
			self._target = npc_pos
			self.state = "walk"
			self:set_animation("walk")
			lualore.behaviors.steer(self, npc_pos, self.nv_last_dtime)
			return true
		end
	end

	-- No villagers nearby, just wander
	self._target = nil
	return false
end

-- RESTING STATE: Stand still or minimal movement
function lualore.behaviors.handle_resting_state(self)
	if not self.object then return false end

	-- Clear targets and just stand
	self._target = nil
	self.state = "stand"
	self:set_animation("stand")

	return true
end

-- WORKING STATE: go to the claimed workstation and stay at it
function lualore.behaviors.handle_working_state(self)
	if not self.object then return false end

	-- A job may point the villager at a spot away from the station
	-- itself - the farmer works the rows of his field rather than
	-- standing at the stake all day.
	local work_pos = self.nv_work_spot or self.nv_work_pos
	if not work_pos then
		-- No station: behave exactly as an unemployed villager does.
		self.nv_at_station = false
		return false
	end

	local pos = self.object:get_pos()
	if not pos then return false end

	-- How close counts as "there". Standing next to an anvil is the
	-- default; a farmer wants to be on top of the plant he is working,
	-- so his job asks for a tighter reach.
	local reach = self.nv_work_reach or 2.2
	local dist = vector.distance(pos, work_pos)
	if dist > reach then
		self.nv_at_station = false
		self._target = work_pos
		self.state = "walk"
		self:set_animation("walk")
		lualore.behaviors.steer(self, work_pos, self.nv_last_dtime)
		-- false so update() still runs the stuck check on the way there,
		-- the same reason the walk-home branch returns false
		return false
	end

	-- Arrived: face the work and stay put. handle_doors got us through
	-- any door on the way in.
	self.nv_at_station = true
	self._target = nil
	self.state = "stand"
	self:set_animation("stand")
	-- Arrived: just face the work. No route needed, and the old one is
	-- finished with.
	if lualore.path then
		lualore.path.reset(self)
	end
	self.object:set_yaw(minetest.dir_to_yaw(vector.direction(pos, work_pos)))
	return true
end

-- Main state handler dispatcher
function lualore.behaviors.handle_state_behavior(self)
	local state = self.nv_behavior_state or lualore.behaviors.states.SOCIALIZING

	if state == lualore.behaviors.states.WANDERING then
		return lualore.behaviors.handle_wandering_state(self)
	elseif state == lualore.behaviors.states.SOCIALIZING then
		return lualore.behaviors.handle_socializing_state(self)
	elseif state == lualore.behaviors.states.RESTING then
		return lualore.behaviors.handle_resting_state(self)
	elseif state == lualore.behaviors.states.WORKING then
		return lualore.behaviors.handle_working_state(self)
	end

	return false
end

--------------------------------------------------------------------
-- DAYTIME BEHAVIOR (State-based system)
--------------------------------------------------------------------
function lualore.behaviors.handle_daytime_movement(self)
	if not lualore.behaviors.is_day_time() then
		return false
	end

	if not self.object then return false end
	local pos = self.object:get_pos()
	if not pos then return false end

	if self.order == "stand" or self.following then
		return false
	end

	-- Handle current state behavior
	return lualore.behaviors.handle_state_behavior(self)
end

--------------------------------------------------------------------
-- NIGHTTIME BEHAVIOR (Modified to ignore NPCs)
--------------------------------------------------------------------
function lualore.behaviors.handle_night_time_movement_with_avoidance(self)
	if not lualore.behaviors.should_go_to_bed(self) then
		return false
	end
	if not self.object then return false end
	local pos = self.object:get_pos()
	if not pos then return false end
	if self.order == "stand" or self.following then
		return false
	end

	local house_pos = lualore.behaviors.get_house_position(self)
	if not house_pos then return false end

	self.nv_at_station = false
	self.nv_work_spot = nil

	if lualore.behaviors.is_at_house(self) then
		-- Home. Settle by the bed instead of drifting straight back out:
		-- mobs_redo would otherwise roll its walk chance and wander off,
		-- which is what made villagers bob in and out all night.
		self.nv_sleeping = true
		self._target = nil
		self.object:set_velocity({x = 0, y = 0, z = 0})
		self.state = "stand"
		self:set_animation("stand")
		return true
	end

	-- Not home yet: head for the bed. Doors on the way are opened by
	-- handle_doors(), so there is no waypoint juggling here any more.
	self.nv_sleeping = false
	self._target = house_pos
	self.state = "walk"
	self:set_animation("walk")
	lualore.behaviors.steer(self, house_pos, self.nv_last_dtime)

	-- false so the caller still runs the stuck check on the way home
	return false
end

--------------------------------------------------------------------
-- OBSTACLE DETECTION
--------------------------------------------------------------------
function lualore.behaviors.check_path_obstacles(self)
	if not self.object then return false end
	if not self._target then return false end

	local pos = self.object:get_pos()
	if not pos then return false end

	-- Check if there's an obstacle in front of us
	local dir = vector.direction(pos, self._target)
	local check_pos = vector.add(pos, vector.multiply(dir, 1.5))
	check_pos = vector.round(check_pos)

	local node = minetest.get_node(check_pos)
	local node_def = minetest.registered_nodes[node.name]

	if node_def then
		-- Check if node is not walkable (like glass, fences, walls)
		if not node_def.walkable then
			return false
		end

		-- Check if it's a door - doors are OK
		if minetest.get_item_group(node.name, "door") > 0 then
			return false
		end

		-- Check if it's a fence, glass pane, or similar obstacle
		if node.name:match("fence") or
		   node.name:match("pane") or
		   node.name:match("glass") or
		   node.name:match("bars") or
		   node.name:match("wall") then
			-- Found an obstacle, clear target to find new path
			self._target = nil
			self.state = "stand"
			self:set_animation("stand")
			return true
		end
	end

	return false
end

--------------------------------------------------------------------
-- MAIN UPDATE FUNCTION
--------------------------------------------------------------------
function lualore.behaviors.update(self, dtime)
	lualore.behaviors.init_house(self)
	-- Stashed so the steering helper can age its route without every
	-- call site having to pass dtime down.
	self.nv_last_dtime = dtime

	-- Check for obstacles in path
	if lualore.behaviors.check_path_obstacles(self) then
		return
	end

	-- Open the door ahead (and shut the one behind). This never blocks
	-- movement - the villager keeps walking while the door swings.
	local nav_target = self._target
	if lualore.behaviors.is_home_time() and lualore.behaviors.has_house(self) then
		nav_target = lualore.behaviors.get_house_position(self)
	end
	lualore.behaviors.handle_doors(self, dtime, nav_target)

	-- Food pickup overrides all other movement
	if lualore.behaviors.handle_walk_to_food(self) then
		return
	end

	-- Going home overrides all state behavior
	if lualore.behaviors.is_home_time() then
		if lualore.behaviors.handle_night_time_movement_with_avoidance(self) then
			return
		end
	else
		-- Daytime: out of bed and back to the village
		self.nv_sleeping = false

		-- Update state timer and handle transitions
		self.nv_state_timer = (self.nv_state_timer or 0) + dtime

		local current_state = self.nv_behavior_state or lualore.behaviors.states.WANDERING
		local state_duration = lualore.behaviors.get_state_duration(current_state)

		-- Check if it's time to transition to next state
		if self.nv_state_timer >= state_duration then
			local next_state = lualore.behaviors.get_next_state(self, current_state)
			lualore.behaviors.transition_state(self, next_state)
		end

		-- Handle daytime movement with state-based behavior
		if lualore.behaviors.handle_daytime_movement(self) then
			return
		end
	end

	lualore.behaviors.check_stuck_and_recover(self, dtime)

	if lualore.behaviors.is_day_time() then
		if math.random() < 0.05 then
			lualore.behaviors.handle_social_interactions(self)
		end

		if math.random() < 0.03 then
			lualore.behaviors.handle_food_sharing(self)
		end

		if math.random() < 0.02 then
			lualore.behaviors.check_nearby_players(self)
		end
	end

	local flee_target = lualore.behaviors.flee_to_house_on_low_health(self)
	if flee_target then
	end
end

--------------------------------------------------------------------
-- SERIALIZATION HELPERS
--------------------------------------------------------------------
function lualore.behaviors.get_save_data(self)
	return {
		nv_house_pos = self.nv_house_pos,
		nv_home_radius = self.nv_home_radius,
		nv_sleeping = self.nv_sleeping,
		nv_stuck_timer = self.nv_stuck_timer,
		nv_last_social_time = self.nv_last_social_time,
		nv_last_food_share_time = self.nv_last_food_share_time,
		nv_last_player_greeting_time = self.nv_last_player_greeting_time,
		nv_door_opened = self.nv_door_opened,
		nv_door_from = self.nv_door_from,
		nv_door_opened_at = self.nv_door_opened_at,
		-- State machine data
		nv_behavior_state = self.nv_behavior_state,
		nv_state_timer = self.nv_state_timer,
		nv_state_target_reached = self.nv_state_target_reached,
		nv_spawn_pos = self.nv_spawn_pos,
	}
end

function lualore.behaviors.load_save_data(self, data)
	if not data then return end

	self.nv_house_pos = data.nv_house_pos
	self.nv_home_radius = data.nv_home_radius
	self.nv_sleeping = data.nv_sleeping
	self.nv_stuck_timer = data.nv_stuck_timer or 0
	self.nv_last_social_time = data.nv_last_social_time or 0
	self.nv_last_food_share_time = data.nv_last_food_share_time or 0
	self.nv_last_player_greeting_time = data.nv_last_player_greeting_time or 0
	self.nv_door_opened = data.nv_door_opened
	self.nv_door_from = data.nv_door_from
	self.nv_door_opened_at = data.nv_door_opened_at or 0
	-- State machine data
	self.nv_behavior_state = data.nv_behavior_state or lualore.behaviors.states.SOCIALIZING
	self.nv_state_timer = data.nv_state_timer or 0
	self.nv_state_target_reached = data.nv_state_target_reached or false
	self.nv_spawn_pos = data.nv_spawn_pos
end

print(S("[MOD] Native Villages - Enhanced villager behaviors loaded"))
