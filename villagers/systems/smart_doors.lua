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

local function get_door_base_and_state(node_name)
	local base, suffix = node_name:match("^(doors:door_.-)(_[abcd])$")
	if base and suffix and suffix_to_state[suffix] then
		return base, suffix_to_state[suffix]
	end
	return nil, nil
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
	if not base then return end

	local currently_open = (state % 2 == 1)
	if currently_open == want_open then return end

	-- Determine new state
	local new_state = want_open and (state + 1) or (state - 1)

	local dir = node.param2
	local t = door_transform[new_state]
	if not t or not t[dir + 1] then return end

	local entry = t[dir + 1]
	local new_name = base .. entry.v

	if not minetest.registered_nodes[new_name] then return end

	local sound_def = minetest.registered_nodes[new_name]
	if want_open and sound_def.sound_open then
		minetest.sound_play(sound_def.sound_open, {pos = pos, gain = 0.3, max_hear_distance = 10})
	elseif not want_open and sound_def.sound_close then
		minetest.sound_play(sound_def.sound_close, {pos = pos, gain = 0.3, max_hear_distance = 10})
	end

	minetest.swap_node(pos, {name = new_name, param1 = node.param1, param2 = entry.p2})
	minetest.get_meta(pos):set_int("state", new_state)
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
