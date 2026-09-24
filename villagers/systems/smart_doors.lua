-- smart_doors.lua
-- Opens all doors at 6AM and closes them at 10PM

lualore.smart_doors = {}

local DAY_START      = 0.25    -- 6AM
local DAY_END        = 0.9167  -- 10PM
local CHECK_INTERVAL = 10      -- Globalstep poll interval in seconds

--------------------------------------------------------------------
-- DOOR TRANSFORM TABLE (mirrors doors mod exactly)
-- state 0 = closed left-hinge  (_a)
-- state 1 = open   left-hinge  (_a, different param2)
-- state 2 = closed right-hinge (_b)
-- state 3 = open   right-hinge (_b, different param2)
--------------------------------------------------------------------

local door_transform = {
	[0] = { {v = "_a", p2 = 3}, {v = "_a", p2 = 0}, {v = "_a", p2 = 1}, {v = "_a", p2 = 2} },
	[1] = { {v = "_c", p2 = 1}, {v = "_c", p2 = 2}, {v = "_c", p2 = 3}, {v = "_c", p2 = 0} },
	[2] = { {v = "_b", p2 = 1}, {v = "_b", p2 = 2}, {v = "_b", p2 = 3}, {v = "_b", p2 = 0} },
	[3] = { {v = "_d", p2 = 3}, {v = "_d", p2 = 0}, {v = "_d", p2 = 1}, {v = "_d", p2 = 2} },
}

-- Suffix-to-state map so we can identify a door's current state from node name alone
local suffix_to_state = { _a = 0, _c = 1, _b = 2, _d = 3 }

-- Any mod's upright door, not just minetest_game's: the village and sky
-- schematics also carry everness:door_crystal_wood_*, which the old
-- "^doors:door_" pattern never matched, so those houses were left out of
-- the sweep entirely. Trapdoors and gates do not match (no _a.._d suffix
-- on a "mod:door_" name) and are left alone.
local function get_door_base_and_state(node_name)
	if not node_name then
		return nil, nil
	end
	local base, suffix = node_name:match("^([%w_]+:door_.-)(_[abcd])$")
	if base and suffix and suffix_to_state[suffix] then
		return base, suffix_to_state[suffix]
	end
	return nil, nil
end

-- Public: is this node an upright door, and is it open?
-- Closed doors are the _a and _b variants (states 0 and 2); _c and _d are
-- the open ones. Hinge side is whatever the schematic stored, so BOTH
-- closed variants have to be recognised.
function lualore.smart_doors.is_door(node_name)
	if node_name == "doors:hidden" then
		return false -- the invisible upper half, present open or closed
	end
	return (get_door_base_and_state(node_name)) ~= nil
end

function lualore.smart_doors.is_open(node_name)
	local _, state = get_door_base_and_state(node_name)
	if not state then
		return nil
	end
	return state % 2 == 1
end

function lualore.smart_doors.is_closed(node_name)
	local open = lualore.smart_doors.is_open(node_name)
	return open == false
end

local function is_daytime()
	local tod = minetest.get_timeofday()
	return tod >= DAY_START and tod < DAY_END
end

--------------------------------------------------------------------
-- TOGGLE A SINGLE DOOR
--------------------------------------------------------------------

local function toggle_door(pos, node, want_open)
	local base, state = get_door_base_and_state(node.name)
	if not base then return false end

	local currently_open = (state % 2 == 1)
	if currently_open == want_open then return false end

	-- Determine new state
	local new_state = want_open and (state + 1) or (state - 1)

	local dir = node.param2
	local t = door_transform[new_state]
	if not t or not t[dir + 1] then return false end

	local entry = t[dir + 1]
	local new_name = base .. entry.v

	if not minetest.registered_nodes[new_name] then return false end

	local sound_def = minetest.registered_nodes[new_name]
	if want_open and sound_def.sound_open then
		minetest.sound_play(sound_def.sound_open, {pos = pos, gain = 0.3, max_hear_distance = 10})
	elseif not want_open and sound_def.sound_close then
		minetest.sound_play(sound_def.sound_close, {pos = pos, gain = 0.3, max_hear_distance = 10})
	end

	minetest.swap_node(pos, {name = new_name, param1 = node.param1, param2 = entry.p2})
	-- keep the doors mod's own bookkeeping in step, so a player clicking
	-- the door afterwards toggles it from the right state
	minetest.get_meta(pos):set_int("state", new_state)
	return true
end

--------------------------------------------------------------------
-- PUBLIC API (used by the villagers, see villager_behaviors.lua)
--------------------------------------------------------------------

-- Open or close one door. Returns true when the door actually changed.
function lualore.smart_doors.set(pos, want_open)
	if not pos then
		return false
	end
	return toggle_door(pos, minetest.get_node(pos), want_open) == true
end

-- Nearest closed upright door around a position, or nil. Uses the engine
-- side node search rather than a Lua triple loop: villagers ask for this
-- several times a second each.
function lualore.smart_doors.find_closed_near(pos, radius)
	local minp = {x = pos.x - radius, y = pos.y - 1, z = pos.z - radius}
	local maxp = {x = pos.x + radius, y = pos.y + 2, z = pos.z + radius}
	local found = minetest.find_nodes_in_area(minp, maxp, {"group:door"})
	local best, best_dist
	for _, dpos in ipairs(found) do
		if lualore.smart_doors.is_closed(minetest.get_node(dpos).name) then
			local dist = vector.distance(pos, dpos)
			if not best_dist or dist < best_dist then
				best, best_dist = dpos, dist
			end
		end
	end
	return best, best_dist
end

--------------------------------------------------------------------
-- TIME-BASED DOOR SWEEP
--------------------------------------------------------------------

local function update_doors_near_players(want_open)
	local players = minetest.get_connected_players()
	local visited = {}

	for _, player in ipairs(players) do
		local ppos = player:get_pos()
		local minp = vector.subtract(ppos, 128)
		local maxp = vector.add(ppos, 128)

		local positions = minetest.find_nodes_in_area(minp, maxp, {"group:door"})
		for _, pos in ipairs(positions) do
			local key = minetest.pos_to_string(pos)
			if not visited[key] then
				visited[key] = true
				local node = minetest.get_node(pos)
				if node.name ~= "doors:hidden" then
					toggle_door(pos, node, want_open)
				end
			end
		end
	end
end

--------------------------------------------------------------------
-- GLOBALSTEP SCHEDULER
--------------------------------------------------------------------

local elapsed_accum = 0
local last_was_day  = nil

minetest.register_globalstep(function(dtime)
	elapsed_accum = elapsed_accum + dtime
	if elapsed_accum < CHECK_INTERVAL then return end
	elapsed_accum = 0

	local now_day = is_daytime()

	if last_was_day == nil then
		update_doors_near_players(now_day)
		last_was_day = now_day
		return
	end

	if now_day ~= last_was_day then
		update_doors_near_players(now_day)
		last_was_day = now_day
	end
end)

--------------------------------------------------------------------
-- CANCEL ANY LEGACY NODE TIMERS ON DOOR NODES
--------------------------------------------------------------------

minetest.register_lbm({
	label = "Cancel legacy door node timers",
	name = "lualore:cancel_door_timers",
	nodenames = {"group:door"},
	run_at_every_load = true,
	action = function(pos, node)
		local timer = minetest.get_node_timer(pos)
		if timer:is_started() then
			timer:stop()
		end
	end,
})

minetest.register_on_mods_loaded(function()
	for name, _ in pairs(minetest.registered_nodes) do
		if name:match("^doors:door_") then
			minetest.override_item(name, {on_timer = nil})
		end
	end
	minetest.log("action", "[lualore] Legacy door timers cleared")
end)

minetest.log("action", "[lualore] Time-based door system loaded (open 6AM, close 10PM)")
