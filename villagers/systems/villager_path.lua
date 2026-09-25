-- villager_path.lua
-- ===================================================================
-- PATHING - walking round things, and through doorways in order
-- ===================================================================
-- Villagers used to navigate by pointing at their goal and walking.
-- mobs_redo only pathfinds while a mob is attacking, so a villager
-- heading home met a wall and stayed there. Luanti has a perfectly good
-- A* in the engine, so there is no pathfinder written here - this drives
-- minetest.find_path and hands back the next corner to steer for.
--
-- DOORWAYS ARE THE WHOLE PROBLEM. The engine's pathfinder asks whether a
-- node is `walkable`, and a door node is - open or shut, because what
-- swings aside is the door's collision box, not its walkability. A* will
-- therefore never, under any circumstances, route through a doorway. A
-- bed inside a house is simply unreachable as far as the engine is
-- concerned.
--
-- So a trip indoors is walked as an ordered journey, in legs:
--
--   1. TO THE DOOR   - path to the square outside the doorway. This is
--                      ordinary A* and works, because that square is
--                      outside the building.
--   2. THROUGH IT    - aim at the square on the far side. The door
--                      handler opens the door as we come up to it; we
--                      wait at the threshold until it is actually open
--                      rather than shoving at it.
--   3. TO THE GOAL   - path from inside to the bed. Ordinary A* again,
--                      now that we are in the same room as it.
--
-- Leaving in the morning is the same journey in reverse, and falls out
-- of the same code: the goal is outside, the doorway is between, so the
-- legs are found the same way.
--
-- Which way a doorway runs is worked out from the world - the axis whose
-- two opposite neighbours are both standable - and never from the
-- direction the villager happens to be coming from. Deriving it from the
-- villager's heading is what broke the first version of this: approach a
-- door diagonally and the "square outside the door" landed inside a
-- wall, the route to it failed, and the villager fell back to walking
-- straight at its goal through the building.
-- ===================================================================

lualore = lualore or {}
lualore.path = {}

local REPATH_EVERY = 1.5    -- seconds between searches for one villager
local SEARCH_DISTANCE = 24  -- how far the engine may search
local MAX_GOAL = 48         -- further than this, just walk that way
local NEAR_GOAL = 1.8       -- close enough to a goal to go direct
-- Close enough to a route corner to start aiming at the next one. Kept
-- tight on purpose: the route is a chain of adjacent nodes, so a wide
-- radius skips two or three of them at once and the villager ends up
-- aiming diagonally across a corner - into the corner block. Aiming only
-- ever at the adjacent node is what makes it hug the route.
local WAYPOINT_HIT = 0.7
local STUCK_AFTER = 3.0     -- seconds of no progress before re-planning
local DOOR_SEARCH = 10      -- how far from a goal to look for its door
local THRESHOLD_HIT = 1.0   -- close enough to the threshold to step through

local MAX_JUMP = 1
local MAX_DROP = 3

local function block(pos)
	return {x = math.floor(pos.x + 0.5), y = math.floor(pos.y + 0.5),
		z = math.floor(pos.z + 0.5)}
end

local function walkable(pos)
	local def = minetest.registered_nodes[minetest.get_node(pos).name]
	return def ~= nil and def.walkable == true
end

-- Can a villager stand here: solid under, clear at head height.
local function standable(pos)
	if walkable(pos) or walkable({x = pos.x, y = pos.y + 1, z = pos.z}) then
		return false
	end
	return walkable({x = pos.x, y = pos.y - 1, z = pos.z})
end

-- ------------------------------------------------------------------
-- Doorways
-- ------------------------------------------------------------------
local AXES = {{x = 1, z = 0}, {x = 0, z = 1}}

-- Which way this doorway runs, and the standable square either side.
-- Read off the world, so it is right however the door was placed and
-- whichever direction the villager arrives from.
function lualore.path.doorway(door)
	for _, axis in ipairs(AXES) do
		local a = {x = door.x + axis.x, y = door.y, z = door.z + axis.z}
		local b = {x = door.x - axis.x, y = door.y, z = door.z - axis.z}
		-- Allow a step up or down on either side; thresholds are rarely level.
		for _, dy in ipairs({0, -1, 1}) do
			local pa = {x = a.x, y = a.y + dy, z = a.z}
			local pb = {x = b.x, y = b.y + dy, z = b.z}
			if standable(pa) and standable(pb) then
				return axis, pa, pb
			end
		end
	end
	return nil
end

local function doors_near(pos, radius)
	local found = minetest.find_nodes_in_area(
		{x = pos.x - radius, y = pos.y - 2, z = pos.z - radius},
		{x = pos.x + radius, y = pos.y + 3, z = pos.z + radius},
		{"group:door"})
	local out = {}
	for _, dpos in ipairs(found) do
		if minetest.get_node(dpos).name ~= "doors:hidden" then
			out[#out + 1] = dpos
		end
	end
	return out
end

local function is_open(door)
	local doors_api = lualore.smart_doors
	if doors_api and doors_api.is_open then
		local open = doors_api.is_open(minetest.get_node(door).name)
		if open ~= nil then
			return open
		end
	end
	return false
end

-- ------------------------------------------------------------------
-- Journeys
-- ------------------------------------------------------------------
local function clear_route(self)
	self.nv_route = nil
	self.nv_route_index = nil
end

function lualore.path.reset(self)
	clear_route(self)
	self.nv_journey = nil
	self.nv_path_stuck = 0
	self.nv_path_last_pos = nil
	self.nv_repath_timer = nil
end

local function compute(from, to)
	local ok, path = pcall(minetest.find_path, from, to,
		SEARCH_DISTANCE, MAX_JUMP, MAX_DROP, "A*_noprefetch")
	if ok and path and #path > 0 then
		return path
	end
	return nil
end

-- Plan the trip to a goal A* says it cannot reach. Finds the doorway
-- that serves it and which side of it we are on.
--
-- Which side we are on is decided by asking the pathfinder, not by
-- measuring. Straight-line distance is worthless here: stand west of a
-- house whose door faces south and the square INSIDE the door is nearer
-- to you than the one outside it, because the wall between does not
-- count towards the measurement. Picking by distance sent villagers to
-- the wrong side of their own front door and they pressed into the wall
-- instead.
local PROBE_DOORS = 3 -- how many candidate doorways to test with A*

local function plan_journey(self, pos, goal)
	local here = block(pos)
	local there = block(goal)

	-- Doors around the goal first - the way into where we are going -
	-- then any near us, which covers walking out of a building.
	local candidates = doors_near(there, DOOR_SEARCH)
	for _, d in ipairs(doors_near(here, 6)) do
		candidates[#candidates + 1] = d
	end
	if #candidates == 0 then
		return nil
	end

	-- Nearest the goal first, and only probe a few: each probe is an A*.
	table.sort(candidates, function(a, b)
		return vector.distance(a, there) < vector.distance(b, there)
	end)

	local best, best_cost
	local probed = 0
	for _, door in ipairs(candidates) do
		local axis, side_a, side_b = lualore.path.doorway(door)
		if axis and probed < PROBE_DOORS then
			probed = probed + 1
			-- The side we can actually reach is the way in; the other is
			-- the way through.
			local entry, exit, route
			route = compute(here, block(side_a))
			if route then
				entry, exit = side_a, side_b
			else
				route = compute(here, block(side_b))
				if route then
					entry, exit = side_b, side_a
				end
			end

			if entry then
				local cost = #route + vector.distance(exit, there)
				if not best_cost or cost < best_cost then
					best_cost = cost
					best = {door = door, entry = entry, exit = exit, route = route}
				end
			end
		end
	end

	if not best then
		return nil
	end
	-- The axis we will cross on, so the crossing can tell whether the
	-- villager is lined up with the gap.
	local axis = {
		x = (best.exit.x > best.entry.x) and 1 or ((best.exit.x < best.entry.x) and -1 or 0),
		z = (best.exit.z > best.entry.z) and 1 or ((best.exit.z < best.entry.z) and -1 or 0),
	}
	return {
		goal = {x = goal.x, y = goal.y, z = goal.z},
		door = best.door,
		entry = best.entry,
		exit = best.exit,
		axis = axis,
		route = best.route,
		stage = "to_door",
	}
end

-- Follow a stored A* route towards `target`, or plan one. Returns the
-- next corner, or nil when there is no route to be had.
local function route_step(self, pos, target, dtime)
	local goal_moved = self.nv_route_target
		and vector.distance(self.nv_route_target, target) > 2

	if self.nv_route and not goal_moved then
		local route = self.nv_route
		local index = self.nv_route_index or 1
		while index <= #route and vector.distance(pos, route[index]) < WAYPOINT_HIT do
			index = index + 1
		end
		self.nv_route_index = index
		if index <= #route then
			return route[index]
		end
		clear_route(self)
		return target
	end

	self.nv_repath_timer = (self.nv_repath_timer or 0) + (dtime or 0)
	if self.nv_repath_timer < REPATH_EVERY and not goal_moved then
		return nil
	end
	self.nv_repath_timer = 0

	local route = compute(block(pos), block(target))
	if not route then
		return nil
	end
	self.nv_route = route
	self.nv_route_index = 1
	self.nv_route_target = {x = target.x, y = target.y, z = target.z}
	return route[1]
end

-- ------------------------------------------------------------------
-- The one function the behaviour module calls
-- ------------------------------------------------------------------
-- Give it where the villager wants to end up; it gives back the point to
-- walk at right now. Never nil - worst case it hands the goal back,
-- which is the behaviour this replaced.
function lualore.path.next_step(self, goal, dtime)
	local pos = self.object and self.object:get_pos()
	if not pos or not goal then
		return goal
	end

	local dist = vector.distance(pos, goal)
	if dist <= NEAR_GOAL or dist > MAX_GOAL then
		lualore.path.reset(self)
		return goal
	end

	-- Track progress, so a route that is not working gets torn up.
	local last = self.nv_path_last_pos
	if last and vector.distance(pos, last) < 0.3 then
		self.nv_path_stuck = (self.nv_path_stuck or 0) + (dtime or 0)
	else
		self.nv_path_stuck = 0
		self.nv_path_last_pos = {x = pos.x, y = pos.y, z = pos.z}
	end

	local journey = self.nv_journey
	if journey and vector.distance(journey.goal, goal) > 2 then
		journey = nil
		lualore.path.reset(self)
	end

	-- ---------------------------------------------------------------
	-- On a journey through a doorway
	-- ---------------------------------------------------------------
	if journey then
		if journey.stage == "to_door" then
			if vector.distance(pos, journey.entry) <= THRESHOLD_HIT then
				journey.stage = "at_door"
				clear_route(self)
			else
				local step = route_step(self, pos, journey.entry, dtime)
				if step then
					return step
				end
				-- No route even to the doorway: walk at it.
				return journey.entry
			end
		end

		if journey.stage == "at_door" then
			-- Stand on the threshold until the door is actually open. The
			-- door handler opens what a villager is walking up to; shoving
			-- at a shut door is what made them jitter in the doorway.
			if is_open(journey.door) then
				journey.stage = "through"
			else
				self.nv_waiting_at_door = true
				return journey.door
			end
		end

		if journey.stage == "through" then
			self.nv_waiting_at_door = nil
			if vector.distance(pos, journey.exit) <= THRESHOLD_HIT then
				journey.stage = "to_goal"
				journey.crossed = true
				clear_route(self)
			else
				-- Line up with the gap first. A doorway is one node wide;
				-- a villager standing half a node to the side and aiming
				-- at the far square walks into the wall beside the door,
				-- which is exactly what it looks like from outside - a
				-- villager shoving at a doorframe. Aiming at the door node
				-- itself pulls it onto the axis, because that node is the
				-- gap.
				local axis = journey.axis or {x = 0, z = 0}
				local off
				if axis.x ~= 0 then
					off = math.abs(pos.z - journey.door.z)
				else
					off = math.abs(pos.x - journey.door.x)
				end
				if off > 0.35 then
					return {x = journey.door.x, y = pos.y, z = journey.door.z}
				end
				-- Straight through. Two nodes, no pathing: A* cannot
				-- describe this step by definition.
				return journey.exit
			end
		end

		if journey.stage == "to_goal" then
			if vector.distance(pos, goal) <= NEAR_GOAL then
				lualore.path.reset(self)
				return goal
			end
			local step = route_step(self, pos, goal, dtime)
			if step then
				return step
			end
			-- Through the door but still no route: another doorway, maybe.
			local next_leg = plan_journey(self, pos, goal)
			if next_leg then
				self.nv_journey = next_leg
				clear_route(self)
				return next_leg.entry
			end
			return goal
		end
	end

	-- ---------------------------------------------------------------
	-- Ordinary travel
	-- ---------------------------------------------------------------
	local stuck = (self.nv_path_stuck or 0) >= STUCK_AFTER
	if stuck then
		clear_route(self)
		self.nv_path_stuck = 0
		self.nv_repath_timer = REPATH_EVERY
	end

	local step = route_step(self, pos, goal, dtime)
	if step then
		return step
	end

	-- A* says there is no way. That is what a doorway looks like.
	local plan = plan_journey(self, pos, goal)
	if plan then
		self.nv_journey = plan
		-- The plan already found the way to the doorway while working out
		-- which side we were on; no need to search for it twice.
		self.nv_route = plan.route
		self.nv_route_index = 1
		self.nv_route_target = {x = plan.entry.x, y = plan.entry.y, z = plan.entry.z}
		return plan.route[1] or plan.entry
	end

	return goal
end

-- Is this villager mid-crossing? The door handler asks, so it does not
-- shut a door somebody is walking through.
function lualore.path.crossing(self)
	local journey = self.nv_journey
	if not journey then
		return nil
	end
	if journey.stage == "to_door" or journey.stage == "at_door"
			or journey.stage == "through" then
		return journey.door
	end
	return nil
end

minetest.log("action", "[lualore] Villager pathing loaded")
