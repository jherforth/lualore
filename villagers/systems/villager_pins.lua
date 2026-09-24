-- villager_pins.lua
-- ===================================================================
-- WAYPOINT PINS - "there's a ruin out east, past the ridge"
-- ===================================================================
-- A small waypoint marker a villager can put on a player's screen. The
-- Sky Folk have their own pin system (valkyrie/sky_folk_pins.lua) but it
-- holds exactly one pin per player and is wired into the quest
-- lifecycle, so rather than bend that out of shape this is a separate,
-- simpler thing: several named pins per player, no quest attached, and
-- they clear themselves when you arrive.
--
-- Pins survive a restart, because being told where a ruin is and then
-- losing the note to a server hiccup is a poor trade for a loaf.
-- ===================================================================

lualore = lualore or {}
lualore.pins = {}

local storage = minetest.get_mod_storage()
local S = minetest.get_translator("lualore")

-- How near you must get before the pin considers itself delivered.
local ARRIVE_DIST = 12

-- pins[player_name][id] = {pos, label, colour, hud}
local pins = {}
local dirty = false

-- ------------------------------------------------------------------
-- Persistence (positions and labels only; hud ids are per session)
-- ------------------------------------------------------------------
local function save()
	if not dirty then
		return
	end
	dirty = false
	local out = {}
	for player_name, set in pairs(pins) do
		out[player_name] = {}
		for id, pin in pairs(set) do
			out[player_name][id] = {pos = pin.pos, label = pin.label,
				colour = pin.colour}
		end
	end
	storage:set_string("villager_pins", minetest.serialize(out))
end

local function load()
	local raw = storage:get_string("villager_pins")
	if raw and raw ~= "" then
		local ok, data = pcall(minetest.deserialize, raw)
		if ok and type(data) == "table" then
			pins = data
		end
	end
end

load()

minetest.register_on_shutdown(save)

-- ------------------------------------------------------------------
-- HUD
-- ------------------------------------------------------------------
local function add_hud(player, pin)
	if pin.hud then
		return
	end
	local ok, id = pcall(function()
		return player:hud_add({
			hud_elem_type = "waypoint",
			name = pin.label or "Marked",
			text = "m",
			number = pin.colour or 0xFFDD88,
			world_pos = pin.pos,
			precision = 1,
		})
	end)
	if ok then
		pin.hud = id
	end
end

local function remove_hud(player, pin)
	if pin.hud then
		pcall(function() player:hud_remove(pin.hud) end)
		pin.hud = nil
	end
end

-- ------------------------------------------------------------------
-- API
-- ------------------------------------------------------------------
function lualore.pins.set(player, id, pos, label, colour)
	if not player or not pos then
		return
	end
	local player_name = player:get_player_name()
	pins[player_name] = pins[player_name] or {}
	local existing = pins[player_name][id]
	if existing then
		remove_hud(player, existing)
	end
	local pin = {pos = {x = pos.x, y = pos.y, z = pos.z},
		label = label, colour = colour}
	pins[player_name][id] = pin
	add_hud(player, pin)
	dirty = true
	return pin
end

function lualore.pins.clear(player, id)
	local player_name = player:get_player_name()
	local set = pins[player_name]
	if not set or not set[id] then
		return
	end
	remove_hud(player, set[id])
	set[id] = nil
	dirty = true
end

function lualore.pins.list(player_name)
	return pins[player_name] or {}
end

function lualore.pins.count(player_name)
	local n = 0
	for _ in pairs(pins[player_name] or {}) do
		n = n + 1
	end
	return n
end

-- ------------------------------------------------------------------
-- Session handling
-- ------------------------------------------------------------------
minetest.register_on_joinplayer(function(player)
	local set = pins[player:get_player_name()]
	if not set then
		return
	end
	for _, pin in pairs(set) do
		pin.hud = nil
		add_hud(player, pin)
	end
end)

minetest.register_on_leaveplayer(function(player)
	local set = pins[player:get_player_name()]
	if not set then
		return
	end
	for _, pin in pairs(set) do
		pin.hud = nil
	end
	save()
end)

-- Clear a pin once the player gets there. Checked on a slow timer -
-- this is a signpost, not a tracker.
local check_timer = 0
minetest.register_globalstep(function(dtime)
	check_timer = check_timer + dtime
	if check_timer < 3 then
		return
	end
	check_timer = 0

	for _, player in ipairs(minetest.get_connected_players()) do
		local player_name = player:get_player_name()
		local set = pins[player_name]
		if set then
			local pos = player:get_pos()
			for id, pin in pairs(set) do
				if vector.distance(pos, pin.pos) <= ARRIVE_DIST then
					minetest.chat_send_player(player_name,
						S("You have found what you were told about: @1.",
							pin.label or "the place"))
					remove_hud(player, pin)
					set[id] = nil
					dirty = true
				end
			end
		end
	end

	save()
end)
