-- smart_doors.lua
-- Opens all doors at 6AM and closes them at 10PM

lualore.smart_doors = {}

local DAY_START   = 0.25    -- 6AM
local DAY_END     = 0.9167  -- 10PM
local CHECK_INTERVAL = 10   -- Globalstep poll interval in seconds

--------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------

local function is_closed_door(node_name)
	return node_name and (
		node_name:match("^doors:door_.*_b$") or
		node_name:match("^doors:hidden$")
	)
end

local function is_open_door(node_name)
	return node_name and node_name:match("^doors:door_.*_a$")
end

local function get_open_door_name(closed_name)
	return closed_name:gsub("_b$", "_a")
end

local function get_closed_door_name(open_name)
	return open_name:gsub("_a$", "_b")
end

local function is_daytime()
	local tod = minetest.get_timeofday()
	return tod >= DAY_START and tod < DAY_END
end

local function open_door(pos, node)
	local open_name = get_open_door_name(node.name)
	if minetest.registered_nodes[open_name] then
		minetest.swap_node(pos, {name = open_name, param1 = node.param1, param2 = node.param2})
		local def = minetest.registered_nodes[open_name]
		if def and def.sound_open then
			minetest.sound_play(def.sound_open, {pos = pos, gain = 0.3, max_hear_distance = 10})
		end
		return true
	end
	return false
end

local function close_door(pos, node)
	local closed_name = get_closed_door_name(node.name)
	if minetest.registered_nodes[closed_name] then
		minetest.swap_node(pos, {name = closed_name, param1 = node.param1, param2 = node.param2})
		local def = minetest.registered_nodes[closed_name]
		if def and def.sound_close then
			minetest.sound_play(def.sound_close, {pos = pos, gain = 0.3, max_hear_distance = 10})
		end
		return true
	end
	return false
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

		if want_open then
			local positions = minetest.find_nodes_in_area(minp, maxp, {"group:door"})
			for _, pos in ipairs(positions) do
				local key = minetest.pos_to_string(pos)
				if not visited[key] then
					visited[key] = true
					local node = minetest.get_node(pos)
					if is_closed_door(node.name) then
						open_door(pos, node)
					end
				end
			end
		else
			local positions = minetest.find_nodes_in_area(minp, maxp, {"group:door"})
			for _, pos in ipairs(positions) do
				local key = minetest.pos_to_string(pos)
				if not visited[key] then
					visited[key] = true
					local node = minetest.get_node(pos)
					if is_open_door(node.name) then
						close_door(pos, node)
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------
-- GLOBALSTEP SCHEDULER
--------------------------------------------------------------------

local elapsed_accum = 0
local last_was_day = nil

minetest.register_globalstep(function(dtime)
	elapsed_accum = elapsed_accum + dtime
	if elapsed_accum < CHECK_INTERVAL then return end
	elapsed_accum = 0

	local now_day = is_daytime()

	if last_was_day == nil then
		-- First tick: bring all doors to the correct state without firing transitions
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
