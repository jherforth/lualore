-- smart_doors.lua
-- Opens all doors at 6AM and closes them at 10PM

lualore.smart_doors = {}

local DAY_START      = 0.25    -- 6AM
local DAY_END        = 0.9167  -- 10PM
local CHECK_INTERVAL = 10      -- Globalstep poll interval in seconds

--------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------

local function is_daytime()
	local tod = minetest.get_timeofday()
	return tod >= DAY_START and tod < DAY_END
end

local function is_door_open(pos)
	local state = minetest.get_meta(pos):get_int("state")
	return state % 2 == 1
end

local function is_registered_door(node_name)
	return doors and doors.registered_doors and doors.registered_doors[node_name]
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
				if is_registered_door(node.name) then
					local currently_open = is_door_open(pos)
					if want_open and not currently_open then
						doors.door_toggle(pos, node, nil)
					elseif not want_open and currently_open then
						doors.door_toggle(pos, node, nil)
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
