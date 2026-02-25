-- villager_behaviors.lua
-- Enhanced villager AI: sleep, daily routines, social interactions, food sharing, door usage

local S = minetest.get_translator("lualore")

lualore.behaviors = {}

--------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------
lualore.behaviors.config = {
	home_radius = 20,
	sleep_radius = 3,
	social_detection_radius = 5,
	food_share_detection_radius = 8,
	social_interaction_cooldown = 45,
	food_share_cooldown = 60,
	stuck_teleport_threshold = 300,
	npc_seek_radius = 20,  -- Increased search radius
	-- State-based behavior durations (in seconds)
	state_wander_duration = 45,
	state_social_duration = 90,  -- Much longer socializing time
	state_rest_duration = 25,
	-- Distance limits
	spawn_wander_radius = 25,
	max_distance_from_spawn = 40,
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

--------------------------------------------------------------------
-- STATE MACHINE DEFINITIONS
--------------------------------------------------------------------
lualore.behaviors.states = {
	WANDERING = "wandering",
	SOCIALIZING = "socializing",
	RESTING = "resting",
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
-- DOOR INTERACTION SYSTEM (Simplified using smart_doors.lua)
--------------------------------------------------------------------

-- Check if a node is a closed door
local function is_closed_door(node_name)
	return node_name and (
		node_name:match("^doors:door_.*_b$") or
		node_name:match("^doors:hidden$")
	)
end

-- Find the nearest door in the general direction of target
function lualore.behaviors.find_nearest_door_to_target(self, target_pos)
	if not self.object or not target_pos then return nil end
	local pos = self.object:get_pos()
	if not pos then return nil end

	local direction = vector.direction(pos, target_pos)
	local distance_to_target = vector.distance(pos, target_pos)

	-- Only check for doors if target is far enough away
	if distance_to_target < 3 then return nil end

	-- Search in a corridor towards the target
	local max_search_dist = math.min(15, distance_to_target)
	local nearest_door = nil
	local nearest_dist = 999

	-- Check positions in the direction of target
	for i = 2, max_search_dist do
		local check_pos = vector.add(pos, vector.multiply(direction, i))
		check_pos = vector.round(check_pos)

		-- Check this position and adjacent positions (including vertical)
		for dy = -1, 2 do
			for dx = -1, 1 do
				for dz = -1, 1 do
					local scan_pos = {
						x = check_pos.x + dx,
						y = check_pos.y + dy,
						z = check_pos.z + dz
					}

					local node = minetest.get_node(scan_pos)
					if is_closed_door(node.name) then
						local dist = vector.distance(pos, scan_pos)
						if dist < nearest_dist and dist > 1.5 then
							nearest_dist = dist
							nearest_door = scan_pos
						end
					end
				end
			end
		end

		-- If we found a door, stop searching (only path to first door)
		if nearest_door then
			break
		end
	end

	return nearest_door
end

-- Handle waiting at closed doors
function lualore.behaviors.handle_door_waiting(self)
	if not self.object then return false end
	local pos = self.object:get_pos()
	if not pos then return false end

	-- Initialize door waiting state
	if not self.nv_waiting_for_door then
		self.nv_waiting_for_door = false
		self.nv_door_wait_start = 0
		self.nv_waiting_door_pos = nil
	end

	-- Check if there's a closed door nearby (within 4 blocks)
	local found_closed_door = false
	local door_pos = nil

	for dx = -3, 3 do
		for dy = -1, 2 do
			for dz = -3, 3 do
				local check_pos = {
					x = math.floor(pos.x) + dx,
					y = math.floor(pos.y) + dy,
					z = math.floor(pos.z) + dz
				}
				local node = minetest.get_node(check_pos)
				if is_closed_door(node.name) then
					local dist = vector.distance(pos, check_pos)
					if dist < 4 then
						found_closed_door = true
						door_pos = check_pos
						break
					end
				end
			end
			if found_closed_door then break end
		end
		if found_closed_door then break end
	end

	local current_time = minetest.get_gametime()

	if found_closed_door then
		-- Start or continue waiting
		if not self.nv_waiting_for_door then
			self.nv_waiting_for_door = true
			self.nv_door_wait_start = current_time
			self.nv_waiting_door_pos = door_pos

			-- Stop movement while waiting
			if self.object then
				self.object:set_velocity({x=0, y=0, z=0})
			end
			self.state = "stand"
			self:set_animation("stand")
		end

		-- Check timeout (8 seconds - longer to give smart doors time to open)
		local wait_time = current_time - self.nv_door_wait_start
		if wait_time > 8 then
			-- Timeout - give up on this door
			self.nv_waiting_for_door = false
			self.nv_waiting_door_pos = nil
			self._target = nil  -- Clear target to find new path
			return false
		end

		-- Check if door has opened
		local node = minetest.get_node(door_pos)
		if not is_closed_door(node.name) then
			-- Door opened! Continue movement
			self.nv_waiting_for_door = false
			self.nv_waiting_door_pos = nil
			return false
		end

		-- Still waiting
		return true
	else
		-- No closed door nearby, reset waiting state
		if self.nv_waiting_for_door then
			self.nv_waiting_for_door = false
			self.nv_waiting_door_pos = nil
		end
		return false
	end
end


--------------------------------------------------------------------
-- NIGHT-TIME BED PATHFINDING (Simplified - no sleeping animation)
--------------------------------------------------------------------
function lualore.behaviors.should_go_to_bed(self)
	return lualore.behaviors.is_night_time() and lualore.behaviors.has_house(self)
end

function lualore.behaviors.is_at_house(self)
	if not lualore.behaviors.has_house(self) then return false end
	if not self.object then return false end

	local pos = self.object:get_pos()
	if not pos then return false end

	local house_pos = lualore.behaviors.get_house_position(self)
	local dist = vector.distance(pos, house_pos)

	return dist <= lualore.behaviors.config.sleep_radius
end


--------------------------------------------------------------------
-- DAILY ROUTINE & MOVEMENT
--------------------------------------------------------------------
function lualore.behaviors.get_activity_radius(self)
	local period = lualore.behaviors.get_time_period()
	local base_radius = self.nv_home_radius or lualore.behaviors.config.home_radius

	if period == "morning" then
		return base_radius * 0.5
	elseif period == "afternoon" then
		return base_radius * 1.2
	elseif period == "evening" then
		return base_radius * 0.7
	else
		return lualore.behaviors.config.sleep_radius
	end
end

function lualore.behaviors.update_movement_target(self)
	if not lualore.behaviors.has_house(self) then return end
	if not self.object then return end

	local period = lualore.behaviors.get_time_period()

	if period == "night" then
		if not self.nv_sleeping and not lualore.behaviors.is_at_house(self) then
			local target = lualore.behaviors.get_house_position(self)

			-- Check for doors in the path
			if target and not self.nv_waiting_for_door then
				local door_pos = lualore.behaviors.find_nearest_door_to_target(self, target)
				if door_pos then
					-- Store the final destination
					self.nv_final_destination = target
					-- Return door position as intermediate waypoint
					return door_pos
				end
			end

			-- If we have a final destination and reached the door, continue to final destination
			if self.nv_final_destination then
				local pos = self.object:get_pos()
				if pos and self._target then
					local dist_to_waypoint = vector.distance(pos, self._target)
					if dist_to_waypoint < 2 then
						-- Reached door waypoint, now go to final destination
						local final_dest = self.nv_final_destination
						self.nv_final_destination = nil
						return final_dest
					end
				end
			end

			return target
		end
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

	local closest_npc = nil
	local closest_dist = 999

	for _, npc in ipairs(nearby) do
		if npc.object then
			local npc_pos = npc.object:get_pos()
			if npc_pos then
				local dist = vector.distance(pos, npc_pos)
				if dist > 2 and dist < closest_dist then
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
	return (current_time - self.nv_last_social_time) >= lualore.behaviors.config.social_interaction_cooldown
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

				break
			end
		end
	end

	self.nv_last_social_time = minetest.get_gametime()
end

--------------------------------------------------------------------
-- FOOD SHARING SYSTEM
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

	local current_time = minetest.get_gametime()
	return (current_time - self.nv_last_food_share_time) >= lualore.behaviors.config.food_share_cooldown
end

function lualore.behaviors.emit_food_share_particles(pos1, pos2)
	local mid_pos = {
		x = (pos1.x + pos2.x) / 2,
		y = (pos1.y + pos2.y) / 2 + 1,
		z = (pos1.z + pos2.z) / 2,
	}

	minetest.add_particlespawner({
		amount = 64,
		time = 1.5,
		minpos = {x = mid_pos.x - 0.3, y = mid_pos.y, z = mid_pos.z - 0.3},
		maxpos = {x = mid_pos.x + 0.3, y = mid_pos.y + 0.5, z = mid_pos.z + 0.3},
		minvel = {x = 0, y = 0.3, z = 0},
		maxvel = {x = 0, y = 0.8, z = 0},
		minacc = {x = 0, y = 0, z = 0},
		maxacc = {x = 0, y = 0, z = 0},
		minexptime = 1,
		maxexptime = 2,
		minsize = 0.2,
		maxsize = 0.4,
		texture = "default_cloud.png^[colorize:blue:100",
		glow = 3,
	})
end

function lualore.behaviors.handle_food_sharing(self)
	if not lualore.behaviors.should_share_food(self) then return end

	local hungry_villager = lualore.behaviors.find_hungry_villager_nearby(self)
	if not hungry_villager then return end

	local pos1 = self.object:get_pos()
	local pos2 = hungry_villager.object:get_pos()
	if not pos1 or not pos2 then return end

	self.nv_hunger = math.min(100, (self.nv_hunger or 1) + 15)
	hungry_villager.nv_hunger = math.max(1, (hungry_villager.nv_hunger or 1) - 30)

	if hungry_villager.health and hungry_villager.hp_max then
		hungry_villager.health = math.min(hungry_villager.hp_max, hungry_villager.health + 3)
	end

	lualore.behaviors.emit_food_share_particles(pos1, pos2)

	if hungry_villager.nv_mood_value then
		hungry_villager.nv_mood_value = math.min(100, (hungry_villager.nv_mood_value or 50) + 10)
	end

	self.nv_last_food_share_time = minetest.get_gametime()
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
	end
	return 60
end

-- Get next state in cycle (daytime only cycles through 3 states)
function lualore.behaviors.get_next_state(current_state)
	if current_state == lualore.behaviors.states.WANDERING then
		return lualore.behaviors.states.SOCIALIZING
	elseif current_state == lualore.behaviors.states.SOCIALIZING then
		return lualore.behaviors.states.RESTING
	elseif current_state == lualore.behaviors.states.RESTING then
		return lualore.behaviors.states.SOCIALIZING  -- Go back to socializing instead of wandering
	end
	return lualore.behaviors.states.SOCIALIZING  -- Default to socializing
end

-- Transition to new state
function lualore.behaviors.transition_state(self, new_state)
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

			-- Move towards the villager - always update target
			-- Check for doors in path
			if not self.nv_waiting_for_door then
				local door_pos = lualore.behaviors.find_nearest_door_to_target(self, npc_pos)
				if door_pos then
					self.nv_final_destination = npc_pos
					self._target = door_pos
					self.state = "walk"
					self:set_animation("walk")
					local dir = vector.direction(pos, door_pos)
					local yaw = minetest.dir_to_yaw(dir)
					self.object:set_yaw(yaw)
					return true
				end
			end

			self._target = npc_pos
			self.state = "walk"
			self:set_animation("walk")
			local dir = vector.direction(pos, npc_pos)
			local yaw = minetest.dir_to_yaw(dir)
			self.object:set_yaw(yaw)
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

-- Main state handler dispatcher
function lualore.behaviors.handle_state_behavior(self)
	local state = self.nv_behavior_state or lualore.behaviors.states.SOCIALIZING

	if state == lualore.behaviors.states.WANDERING then
		return lualore.behaviors.handle_wandering_state(self)
	elseif state == lualore.behaviors.states.SOCIALIZING then
		return lualore.behaviors.handle_socializing_state(self)
	elseif state == lualore.behaviors.states.RESTING then
		return lualore.behaviors.handle_resting_state(self)
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

	-- Check for door waypoint completion first
	if self.nv_final_destination and self._target then
		local dist_to_waypoint = vector.distance(pos, self._target)
		if dist_to_waypoint < 2 then
			-- Reached door, continue to final destination
			self._target = self.nv_final_destination
			self.nv_final_destination = nil
			self.state = "walk"
			self:set_animation("walk")

			local dir = vector.direction(pos, self._target)
			local yaw = minetest.dir_to_yaw(dir)
			self.object:set_yaw(yaw)
			return true
		end
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

	if lualore.behaviors.is_at_house(self) then
		return true
	end

	local house_pos = lualore.behaviors.get_house_position(self)
	if house_pos and self.object then
		local pos = self.object:get_pos()
		if pos then
			if self.order ~= "stand" and not self.following then
				-- Check for door waypoint completion first
				if self.nv_final_destination and self._target then
					local dist_to_waypoint = vector.distance(pos, self._target)
					if dist_to_waypoint < 2 then
						-- Reached door, continue to final destination
						self._target = self.nv_final_destination
						self.nv_final_destination = nil
						self.state = "walk"
						self:set_animation("walk")

						local dir = vector.direction(pos, self._target)
						local yaw = minetest.dir_to_yaw(dir)
						self.object:set_yaw(yaw)
						return false
					end
				end

				local dist = vector.distance(pos, house_pos)
				if dist > 1 then
					-- Check for doors in path to house
					if not self.nv_waiting_for_door then
						local door_pos = lualore.behaviors.find_nearest_door_to_target(self, house_pos)
						if door_pos then
							self.nv_final_destination = house_pos
							self._target = door_pos
							self.state = "walk"
							self:set_animation("walk")

							local dir = vector.direction(pos, door_pos)
							local yaw = minetest.dir_to_yaw(dir)
							self.object:set_yaw(yaw)
							return false
						end
					end

					self._target = house_pos
					self.state = "walk"
					self:set_animation("walk")

					local dir = vector.direction(pos, house_pos)
					local yaw = minetest.dir_to_yaw(dir)
					self.object:set_yaw(yaw)
				end
			end
		end
	end

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

	-- Check for obstacles in path
	if lualore.behaviors.check_path_obstacles(self) then
		return
	end

	-- Check if NPC is waiting for a door to open
	if lualore.behaviors.handle_door_waiting(self) then
		-- NPC is waiting, don't do anything else
		return
	end

	-- Night time overrides all state behavior
	if lualore.behaviors.is_night_time() then
		if lualore.behaviors.handle_night_time_movement_with_avoidance(self) then
			return
		end
	else
		-- Daytime: Update state timer and handle transitions
		self.nv_state_timer = (self.nv_state_timer or 0) + dtime

		local current_state = self.nv_behavior_state or lualore.behaviors.states.WANDERING
		local state_duration = lualore.behaviors.get_state_duration(current_state)

		-- Check if it's time to transition to next state
		if self.nv_state_timer >= state_duration then
			local next_state = lualore.behaviors.get_next_state(current_state)
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
		nv_final_destination = self.nv_final_destination,
		nv_waiting_for_door = self.nv_waiting_for_door,
		nv_door_wait_start = self.nv_door_wait_start,
		nv_waiting_door_pos = self.nv_waiting_door_pos,
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
	self.nv_final_destination = data.nv_final_destination
	self.nv_waiting_for_door = data.nv_waiting_for_door or false
	self.nv_door_wait_start = data.nv_door_wait_start or 0
	self.nv_waiting_door_pos = data.nv_waiting_door_pos
	-- State machine data
	self.nv_behavior_state = data.nv_behavior_state or lualore.behaviors.states.SOCIALIZING
	self.nv_state_timer = data.nv_state_timer or 0
	self.nv_state_target_reached = data.nv_state_target_reached or false
	self.nv_spawn_pos = data.nv_spawn_pos
end

print(S("[MOD] Native Villages - Enhanced villager behaviors loaded"))
