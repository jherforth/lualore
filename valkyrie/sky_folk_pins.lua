-- sky_folk_pins.lua
-- Persistent world-space waypoint pins for active Sky Folk quests.
-- When a player accepts a quest the pin records the Sky Folk's last known
-- position.  A HUD waypoint (image + distance text) is shown at all times
-- so the player can navigate back.  On return a fresh liberated Sky Folk
-- that already carries the quest is spawned at the pin position.

lualore.sky_folk_pins = {}

local _pins    = {}          -- [player_name] = { pos, quest, hud_icon, hud_dist, hud_label }
local mod_store = minetest.get_mod_storage()

local ICON_TEX   = "lualore_desire_trade.png"
local PIN_RADIUS = 6          -- metres, close enough to "return"

--------------------------------------------------------------------
-- Persistence helpers
--------------------------------------------------------------------
local function save_pins()
	local out = {}
	for pname, pin in pairs(_pins) do
		out[pname] = {
			pos   = pin.pos,
			quest = pin.quest,
		}
	end
	mod_store:set_string("quest_pins", minetest.serialize(out))
end

local function load_pins()
	local raw = mod_store:get_string("quest_pins")
	if raw and raw ~= "" then
		local ok, data = pcall(minetest.deserialize, raw)
		if ok and data then
			for pname, v in pairs(data) do
				_pins[pname] = { pos = v.pos, quest = v.quest }
			end
		end
	end
end

load_pins()

--------------------------------------------------------------------
-- HUD helpers
--------------------------------------------------------------------
local function add_hud(player, pin)
	local arrow_id = player:hud_add({
		hud_elem_type = "waypoint",
		name          = "Quest Pin",
		text          = "m",
		number        = 0xFFDD88,
		world_pos     = pin.pos,
		precision     = 0,
	})

	local icon_id = player:hud_add({
		hud_elem_type = "image",
		position      = {x = 0.5, y = 0.82},
		offset        = {x = 0, y = 0},
		text          = ICON_TEX,
		scale         = {x = 1.0, y = 1.0},
		alignment     = {x = 0, y = 0},
	})

	local label_id = player:hud_add({
		hud_elem_type = "text",
		position      = {x = 0.5, y = 0.82},
		offset        = {x = 0, y = 68},
		text          = "Return to Sky Folk",
		number        = 0xFFDD88,
		scale         = {x = 100, y = 100},
		alignment     = {x = 0, y = 0},
	})

	pin.hud_waypoint = arrow_id
	pin.hud_icon     = icon_id
	pin.hud_label    = label_id
end

local function remove_hud(player, pin)
	if not player or not pin then return end
	if pin.hud_waypoint then pcall(function() player:hud_remove(pin.hud_waypoint) end) end
	if pin.hud_icon     then pcall(function() player:hud_remove(pin.hud_icon)     end) end
	if pin.hud_label    then pcall(function() player:hud_remove(pin.hud_label)    end) end
	pin.hud_waypoint = nil
	pin.hud_icon     = nil
	pin.hud_label    = nil
end

--------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------

-- Called when a player accepts a quest (but lacks items).
-- pos     = Sky Folk's current world position
-- quest   = the quest table (name, description, required_items, rewards)
function lualore.sky_folk_pins.set(player, pos, quest)
	if not player or not player:is_player() then return end
	local pname = player:get_player_name()

	local existing = _pins[pname]
	if existing then
		remove_hud(player, existing)
	end

	local pin = {
		pos   = vector.new(pos.x, pos.y, pos.z),
		quest = quest,
	}
	_pins[pname] = pin
	add_hud(player, pin)
	save_pins()
end

-- Remove the pin (quest fulfilled or declined).
function lualore.sky_folk_pins.clear(player_name)
	local pin = _pins[player_name]
	if not pin then return end
	local player = minetest.get_player_by_name(player_name)
	if player then remove_hud(player, pin) end
	_pins[player_name] = nil
	save_pins()
end

-- Returns true if the player has an active pin.
function lualore.sky_folk_pins.has(player_name)
	return _pins[player_name] ~= nil
end

-- Returns the stored quest for the pin, or nil.
function lualore.sky_folk_pins.get_quest(player_name)
	local pin = _pins[player_name]
	return pin and pin.quest or nil
end

-- Restore HUD elements for online players on mod reload (pins loaded from storage).
minetest.register_on_joinplayer(function(player)
	local pname = player:get_player_name()
	local pin = _pins[pname]
	if pin then
		add_hud(player, pin)
	end
end)

minetest.register_on_leaveplayer(function(player)
	local pname = player:get_player_name()
	local pin = _pins[pname]
	if pin then
		remove_hud(player, pin)
	end
end)

--------------------------------------------------------------------
-- Proximity check — respawn Sky Folk at pin when player returns
--------------------------------------------------------------------
local check_timer = 0

minetest.register_globalstep(function(dtime)
	check_timer = check_timer + dtime
	if check_timer < 2.0 then return end
	check_timer = 0

	for pname, pin in pairs(_pins) do
		local player = minetest.get_player_by_name(pname)
		if not player then goto continue end

		local ppos = player:get_pos()
		if not ppos then goto continue end

		local dist = vector.distance(ppos, pin.pos)
		if dist <= PIN_RADIUS then
			-- Player is back — spawn a liberated Sky Folk at the pin
			local spawn_pos = vector.new(pin.pos.x, pin.pos.y, pin.pos.z)

			-- Make sure the spawn node is accessible
			local node = minetest.get_node(spawn_pos)
			if node.name ~= "air" and node.name ~= "ignore" then
				spawn_pos.y = spawn_pos.y + 1
			end

			local obj = minetest.add_entity(spawn_pos, "lualore:sky_folk")
			if obj then
				local ent = obj:get_luaentity()
				if ent then
					ent.liberated = true
					ent.sf_quest  = pin.quest
					ent.nv_has_active_quest = true
					if lualore.sky_folk_mood then
						lualore.sky_folk_mood.update_indicator(ent)
					end
				end
			end

			-- Remove the pin so we don't keep re-spawning
			remove_hud(player, pin)
			_pins[pname] = nil
			save_pins()

			minetest.chat_send_player(pname,
				"The Sky Folk awaits you. Right-click them to fulfill your quest.")
		end

		::continue::
	end
end)

minetest.log("action", "[lualore] Sky Folk pins system loaded")
