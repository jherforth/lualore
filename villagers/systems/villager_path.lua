-- villager_path.lua
-- ===================================================================
-- PATHING - walking round things instead of into them
-- ===================================================================
-- Villagers used to navigate by pointing themselves at their goal and
-- walking. mobs_redo only pathfinds while a mob is attacking something,
-- so a villager heading home met a wall and stayed there, shuffling,
-- until the stuck timer eventually teleported it. That is what made them
-- look stupid around buildings.
--
-- Luanti has a perfectly good A* in the engine (minetest.find_path), so
-- there is no custom pathfinder here: this module drives that one, keeps
-- the result on the villager, and hands back the next corner to steer
-- for. Everything else - the yaw, the walking - stays exactly as it was.
--
-- Two details make it actually work:
--
--   * DOORS. A shut door is a walkable node, so A* routes around the
--     house rather than through the doorway. When a path fails we look
--     for a shut door near the goal and aim at that instead; the door
--     handler opens it on arrival, and the next attempt finds the way
--     through. The villager solves the maze by opening it.
--   * FAILING SOFT. If the engine cannot find a route we fall back to
--     walking straight at the goal, which is what it always did. A
--     villager that cannot path is no worse off than before.
-- ===================================================================

lualore = lualore or {}
lualore.path = {}

-- Pathing is not free, so it is rationed: at most one search per
-- villager per interval, and only for goals worth searching to.
local REPATH_EVERY = 2.0    -- seconds between searches for one villager
local SEARCH_DISTANCE = 24  -- how far the engine may search
local MAX_GOAL = 48         -- further than this, just walk that way
local NEAR_GOAL = 2.5       -- close enough to stop pathing and go direct
local WAYPOINT_HIT = 1.2    -- close enough to a corner to aim at the next
local STUCK_AFTER = 3.0     -- seconds of no progress before re-planning

local MAX_JUMP = 1
local MAX_DROP = 3

local function ground_of(pos)
	return {x = math.floor(pos.x + 0.5), y = math.floor(pos.y + 0.5),
		z = math.floor(pos.z + 0.5)}
end

-- ------------------------------------------------------------------
-- Doorways
-- ------------------------------------------------------------------
-- The engine's pathfinder asks whether a node is `walkable`, and every
-- door node is - open or shut, because the door's own collision box is
-- what actually swings out of the way, not its walkability. So A* will
-- never route through a doorway, and a villager that reached a door and
-- opened it would then stand there with nowhere to go.
--
-- Doorways are therefore handled by hand: get to the door, open it (the
-- door handler does that on approach), then step through along the axis
-- we crossed. Once inside, ordinary pathing works again.

-- The axis we would cross this door on, as a unit step.
local function door_axis(pos, door)
	local dx, dz = door.x - pos.x, door.z - pos.z
	if math.abs(dx) >= math.abs(dz) then
		return {x = (dx >= 0) and 1 or -1, y = 0, z = 0}
	end
	return {x = 0, y = 0, z = (dz >= 0) and 1 or -1}
end

-- Any door close enough to use, open or shut.
local function door_near(pos, radius)
	local found = minetest.find_nodes_in_area(
		{x = pos.x - radius, y = pos.y - 1, z = pos.z - radius},
		{x = pos.x + radius, y = pos.y + 2, z = pos.z + radius},
		{"group:door"})
	local best, best_dist
	for _, dpos in ipairs(found) do
		local name = minetest.get_node(dpos).name
		if name ~= "doors:hidden" then
			local dist = vector.distance(pos, dpos)
			if not best_dist or dist < best_dist then
				best, best_dist = dpos, dist
			end
		end
	end
	return best
end

-- If a doorway is right here and the goal lies beyond it, return the
-- point on the far side to walk at. Nil when no door applies.
function lualore.path.doorway_step(self, pos, goal)
	local door = door_near(pos, 2.5)
	if not door then
		return nil
	end
	local axis = door_axis(pos, door)
	-- Only if going through actually takes us towards the goal.
	local to_goal = {x = goal.x - door.x, z = goal.z - door.z}
	if (axis.x * to_goal.x + axis.z * to_goal.z) <= 0 then
		return nil
	end

	local doors_api = lualore.smart_doors
	local shut = doors_api and doors_api.is_closed
		and doors_api.is_closed(minetest.get_node(door).name)
	if shut then
		-- Walk up to it; the door handler opens what we stand next to.
		return {x = door.x, y = pos.y, z = door.z}
	end
	-- Open: aim past the threshold so we actually cross it.
	return {x = door.x + axis.x * 1.5, y = pos.y, z = door.z + axis.z * 1.5}
end

-- A door on the way to somewhere A* says it cannot reach, plus the spot
-- on our side of it to walk to - the door node itself is not standable
-- as far as the pathfinder is concerned.
local function door_approach(self, pos, goal)
	local doors_api = lualore.smart_doors
	local door = nil
	if doors_api and doors_api.find_closed_near then
		-- The door into the place we are trying to get to comes first.
		door = doors_api.find_closed_near(goal, 8) or doors_api.find_closed_near(pos, 6)
	end
	door = door or door_near(goal, 8) or door_near(pos, 6)
	if not door then
		return nil, nil
	end
	local axis = door_axis(pos, door)
	local approach = {x = door.x - axis.x, y = door.y, z = door.z - axis.z}
	return door, approach
end

local function clear_path(self)
	self.nv_path = nil
	self.nv_path_index = nil
	self.nv_path_goal = nil
end

-- Ask the engine for a route. Returns a list of positions, or nil.
local function compute(self, from, to)
	local ok, path = pcall(minetest.find_path, from, to,
		SEARCH_DISTANCE, MAX_JUMP, MAX_DROP, "A*_noprefetch")
	if ok and path and #path > 0 then
		return path
	end
	return nil
end

-- ------------------------------------------------------------------
-- The one function the behaviour module calls
-- ------------------------------------------------------------------
-- Give it where the villager wants to end up; it gives back the point
-- to actually walk at right now. Never returns nil - worst case it
-- hands the goal straight back, which is the old behaviour.
function lualore.path.next_step(self, goal, dtime)
	local pos = self.object and self.object:get_pos()
	if not pos or not goal then
		return goal
	end

	local dist = vector.distance(pos, goal)
	-- Close enough, or so far that searching is a waste: walk at it.
	if dist <= NEAR_GOAL or dist > MAX_GOAL then
		clear_path(self)
		return goal
	end

	-- A doorway right here beats any route, because no route will ever
	-- go through one (see the note above).
	local through = lualore.path.doorway_step(self, pos, goal)
	if through then
		clear_path(self)
		return through
	end

	-- Are we actually getting anywhere? If not, the route is stale.
	local last = self.nv_path_last_pos
	if last then
		if vector.distance(pos, last) < 0.35 then
			self.nv_path_stuck = (self.nv_path_stuck or 0) + (dtime or 0)
		else
			self.nv_path_stuck = 0
			self.nv_path_last_pos = {x = pos.x, y = pos.y, z = pos.z}
		end
	else
		self.nv_path_last_pos = {x = pos.x, y = pos.y, z = pos.z}
		self.nv_path_stuck = 0
	end

	local goal_moved = self.nv_path_goal
		and vector.distance(self.nv_path_goal, goal) > 2
	local stuck = (self.nv_path_stuck or 0) >= STUCK_AFTER

	-- Follow the route we already have.
	if self.nv_path and not goal_moved and not stuck then
		local path = self.nv_path
		local index = self.nv_path_index or 1
		-- Step past any corners we have already reached.
		while index <= #path and vector.distance(pos, path[index]) < WAYPOINT_HIT do
			index = index + 1
		end
		self.nv_path_index = index
		if index <= #path then
			return path[index]
		end
		-- Route walked to the end; head for the goal itself.
		clear_path(self)
		return goal
	end

	-- Time for a new one?
	self.nv_repath_timer = (self.nv_repath_timer or 0) + (dtime or 0)
	if self.nv_path and not stuck and self.nv_repath_timer < REPATH_EVERY then
		return self.nv_path[self.nv_path_index or 1] or goal
	end
	if self.nv_repath_timer < REPATH_EVERY and not goal_moved and not stuck then
		return goal
	end
	self.nv_repath_timer = 0
	self.nv_path_stuck = 0

	local from = ground_of(pos)
	local to = ground_of(goal)
	local path = compute(self, from, to)

	if not path then
		-- No way through. Head for the doorway instead: not the door
		-- node, which the pathfinder will not stand on, but the square
		-- in front of it on our side.
		local door, approach = door_approach(self, pos, goal)
		if approach then
			local door_path = compute(self, from, ground_of(approach))
			if door_path then
				self.nv_path = door_path
				self.nv_path_index = 1
				self.nv_path_goal = goal
				return door_path[1]
			end
			-- Cannot even route to the doorway: walk at it directly.
			clear_path(self)
			return approach
		end
		clear_path(self)
		return goal
	end

	self.nv_path = path
	self.nv_path_index = 1
	self.nv_path_goal = {x = goal.x, y = goal.y, z = goal.z}
	return path[1]
end

-- Called when a villager changes what it is doing, so it does not walk
-- the remains of an old route.
function lualore.path.reset(self)
	clear_path(self)
	self.nv_path_stuck = 0
	self.nv_path_last_pos = nil
	self.nv_repath_timer = nil
end

minetest.log("action", "[lualore] Villager pathing loaded")
