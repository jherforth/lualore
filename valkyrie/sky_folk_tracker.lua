-- sky_folk_tracker.lua
-- Displays a persistent trade icon in the top-left corner when the player
-- has an active quest pin.  Right-clicking the icon (via chat command alias
-- or formspec button) opens a small fly-out panel showing the required items
-- and how many the player currently holds.

lualore.sky_folk_tracker = {}

local _hud_ids = {}   -- [player_name] = { hud_icon }

local ICON_TEX = "lualore_desire_trade.png"

--------------------------------------------------------------------
-- HUD icon management
--------------------------------------------------------------------
local function show_icon(player)
	local pname = player:get_player_name()
	if _hud_ids[pname] then return end

	local icon_id = player:hud_add({
		hud_elem_type = "image",
		position      = {x = 0.02, y = 0.06},
		offset        = {x = 0, y = 0},
		text          = ICON_TEX,
		scale         = {x = 1.5, y = 1.5},
		alignment     = {x = -1, y = -1},
	})

	_hud_ids[pname] = { hud_icon = icon_id }
end

local function hide_icon(player)
	local pname = player:get_player_name()
	local t = _hud_ids[pname]
	if not t then return end
	if t.hud_icon then pcall(function() player:hud_remove(t.hud_icon) end) end
	_hud_ids[pname] = nil
end

--------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------

function lualore.sky_folk_tracker.show(player)
	show_icon(player)
end

function lualore.sky_folk_tracker.hide(player)
	hide_icon(player)
end

--------------------------------------------------------------------
-- Build and open the fly-out formspec
--------------------------------------------------------------------
local function item_display_name(item_name)
	local def = minetest.registered_items[item_name]
	if def and def.description and def.description ~= "" then
		local first = def.description:match("^([^\n]+)") or def.description
		return first
	end
	local short = item_name:match(":(.+)$") or item_name
	return short:gsub("_", " "):gsub("^%l", string.upper)
end

local function count_in_inv(player, item_name)
	local inv  = player:get_inventory()
	local main = inv:get_list("main")
	local total = 0
	for _, stack in ipairs(main) do
		if stack:get_name() == item_name then
			total = total + stack:get_count()
		end
	end
	return total
end

function lualore.sky_folk_tracker.open_panel(player)
	if not player or not player:is_player() then return end
	local pname = player:get_player_name()

	if not lualore.sky_folk_pins or not lualore.sky_folk_pins.has(pname) then
		minetest.chat_send_player(pname, "You have no active quest.")
		return
	end

	local quest = lualore.sky_folk_pins.get_quest(pname)
	if not quest then return end

	local function color(have, need)
		return have >= need and "#88FF88" or "#FF8888"
	end

	local rows = ""
	local row_y = 1.5
	for _, req in ipairs(quest.required_items) do
		local have  = count_in_inv(player, req.name)
		local clr   = color(have, req.count)
		rows = rows ..
			"item_image[0.3," .. row_y .. ";0.9,0.9;" .. req.name .. "]" ..
			"label[1.35," .. (row_y + 0.35) .. ";" ..
				minetest.formspec_escape(item_display_name(req.name)) ..
				" x" .. req.count .. "]" ..
			"label[6.8," .. (row_y + 0.35) .. ";" ..
				minetest.colorize(clr, have .. " / " .. req.count) .. "]"
		row_y = row_y + 1.1
	end

	local panel_h = row_y + 1.0

	local fs =
		"formspec_version[3]" ..
		"size[8.5," .. panel_h .. "]" ..
		"background9[0,0;8.5," .. panel_h .. ";lualore_mood_bg.png;false;2]" ..
		"box[0,0;8.5,0.7;#1a2a3a]" ..
		"label[0.3,0.42;Active Quest]" ..
		"label[0.3,0.95;" .. minetest.colorize("#FFDD88",
			minetest.formspec_escape(quest.name)) .. "]" ..
		"box[0,1.2;8.5,0.03;#334455]" ..
		rows ..
		"box[0," .. (row_y - 0.05) .. ";8.5,0.03;#334455]" ..
		"label[0.3," .. (row_y + 0.35) .. ";" ..
			minetest.colorize("#AAAAAA",
				"Follow the waypoint in the sky to return.") .. "]"

	minetest.show_formspec(pname, "lualore:quest_tracker", fs)
end

--------------------------------------------------------------------
-- Chat command to open the panel (/quest)
--------------------------------------------------------------------
minetest.register_chatcommand("quest", {
	params      = "",
	description = "Show your active Sky Folk quest",
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then return false, "Player not found." end
		lualore.sky_folk_tracker.open_panel(player)
		return true
	end,
})

--------------------------------------------------------------------
-- Keep icon in sync with pin state for joining players
--------------------------------------------------------------------
minetest.register_on_joinplayer(function(player)
	local pname = player:get_player_name()
	minetest.after(1.0, function()
		if lualore.sky_folk_pins and lualore.sky_folk_pins.has(pname) then
			local p = minetest.get_player_by_name(pname)
			if p then show_icon(p) end
		end
	end)
end)

minetest.register_on_leaveplayer(function(player)
	local pname = player:get_player_name()
	_hud_ids[pname] = nil
end)

minetest.log("action", "[lualore] Sky Folk tracker HUD loaded")
