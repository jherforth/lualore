-- sky_folk_compass.lua
-- Shows an on-screen directional arrow pointing toward the sky folk
-- that a player has an active quest with.

lualore.sky_folk_compass = {}

local _trackers = {}

local HUD_SIZE  = 96
local HUD_SCALE = 1.0

local function deg_to_rad(d) return d * math.pi / 180 end

local function get_yaw_to_target(player, target_pos)
	local ppos = player:get_pos()
	if not ppos then return nil end
	local dx = target_pos.x - ppos.x
	local dz = target_pos.z - ppos.z
	local angle_to_target = math.atan2(dz, dx)
	local player_yaw     = player:get_look_horizontal()
	local rel = angle_to_target - (math.pi / 2 - player_yaw)
	return rel
end

local function choose_arrow_texture(rel_rad)
	local deg = math.deg(rel_rad) % 360
	if deg < 0 then deg = deg + 360 end

	if deg < 22.5 or deg >= 337.5 then
		return "lualore_particle_arrow_up.png"
	elseif deg < 67.5 then
		return "lualore_particle_arrow_up.png^[transform3"
	elseif deg < 112.5 then
		return "lualore_particle_arrow_up.png^[transform1"
	elseif deg < 157.5 then
		return "lualore_particle_arrow_up.png^[transform7"
	elseif deg < 202.5 then
		return "lualore_particle_arrow_down.png"
	elseif deg < 247.5 then
		return "lualore_particle_arrow_down.png^[transform3"
	elseif deg < 292.5 then
		return "lualore_particle_arrow_up.png^[transform2"
	else
		return "lualore_particle_arrow_down.png^[transform7"
	end
end

local function remove_hud(player_name)
	local t = _trackers[player_name]
	if not t then return end
	local player = minetest.get_player_by_name(player_name)
	if player and t.hud_arrow then
		player:hud_remove(t.hud_arrow)
	end
	if player and t.hud_dist then
		player:hud_remove(t.hud_dist)
	end
	_trackers[player_name] = nil
end

function lualore.sky_folk_compass.start(player, sky_folk_entity)
	if not player or not player:is_player() then return end
	local player_name = player:get_player_name()

	remove_hud(player_name)

	local arrow_id = player:hud_add({
		hud_elem_type = "image",
		position      = {x = 0.5, y = 0.85},
		offset        = {x = 0, y = 0},
		text          = "lualore_particle_arrow_up.png",
		scale         = {x = HUD_SCALE, y = HUD_SCALE},
		alignment     = {x = 0, y = 0},
	})

	local dist_id = player:hud_add({
		hud_elem_type = "text",
		position      = {x = 0.5, y = 0.85},
		offset        = {x = 0, y = HUD_SIZE * 0.7},
		text          = "",
		number        = 0xFFFFFF,
		scale         = {x = 100, y = 100},
		alignment     = {x = 0, y = 0},
	})

	_trackers[player_name] = {
		entity    = sky_folk_entity,
		hud_arrow = arrow_id,
		hud_dist  = dist_id,
	}
end

function lualore.sky_folk_compass.stop(player_name)
	remove_hud(player_name)
end

local update_timer = 0

minetest.register_globalstep(function(dtime)
	update_timer = update_timer + dtime
	if update_timer < 0.25 then return end
	update_timer = 0

	for player_name, t in pairs(_trackers) do
		local player = minetest.get_player_by_name(player_name)
		if not player then
			_trackers[player_name] = nil
		else
			local ent = t.entity
			local obj = ent and ent.object
			if not obj or not obj:get_pos() then
				remove_hud(player_name)
			else
				local target_pos = obj:get_pos()
				local ppos = player:get_pos()
				local dist = ppos and math.floor(vector.distance(ppos, target_pos)) or 0

				local rel = get_yaw_to_target(player, target_pos)
				if rel then
					local tex = choose_arrow_texture(rel)
					player:hud_change(t.hud_arrow, "text", tex)
				end

				player:hud_change(t.hud_dist, "text", dist .. "m")
			end
		end
	end
end)

minetest.log("action", "[lualore] Sky Folk compass system loaded")
