-- sky_folk_tracker.lua
-- Adds a "Lore" tab to the player's main inventory formspec so the player
-- can review their active Sky Folk quest at any time by pressing I (or
-- whatever key opens their inventory).
--
-- Also provides /quest as a direct chat command shortcut.

lualore.sky_folk_tracker = {}

--------------------------------------------------------------------
-- Helpers
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

--------------------------------------------------------------------
-- Build the standalone Lore formspec
--------------------------------------------------------------------
local function build_lore_formspec(player)
	local pname = player:get_player_name()

	if not lualore.sky_folk_pins or not lualore.sky_folk_pins.has(pname) then
		return
			"formspec_version[3]" ..
			"size[8.5,5.0]" ..
			"background9[0,0;8.5,5.0;lualore_mood_bg.png;false;2]" ..
			"box[0,0;8.5,0.7;#1a2a3a]" ..
			"label[0.3,0.42;Lore — Active Quest]" ..
			"label[0.3,1.8;" ..
				minetest.colorize("#AAAAAA", "You have no active quest.") ..
			"]" ..
			"label[0.3,2.5;" ..
				minetest.colorize("#666666", "Liberate a Sky Folk and accept their quest offer.") ..
			"]"
	end

	local quest = lualore.sky_folk_pins.get_quest(pname)
	if not quest then
		return
			"formspec_version[3]" ..
			"size[8.5,5.0]" ..
			"background9[0,0;8.5,5.0;lualore_mood_bg.png;false;2]" ..
			"box[0,0;8.5,0.7;#1a2a3a]" ..
			"label[0.3,0.42;Lore — Active Quest]" ..
			"label[0.3,2.0;" .. minetest.colorize("#AAAAAA", "Quest data unavailable.") .. "]"
	end

	local rows = ""
	local row_y = 1.5
	for _, req in ipairs(quest.required_items) do
		local have = count_in_inv(player, req.name)
		local clr  = have >= req.count and "#88FF88" or "#FF8888"
		rows = rows ..
			"item_image[0.3," .. row_y .. ";0.9,0.9;" .. req.name .. "]" ..
			"label[1.35," .. (row_y + 0.35) .. ";" ..
				minetest.formspec_escape(item_display_name(req.name)) ..
				" x" .. req.count .. "]" ..
			"label[6.8," .. (row_y + 0.35) .. ";" ..
				minetest.colorize(clr, have .. " / " .. req.count) .. "]"
		row_y = row_y + 1.1
	end

	local panel_h = math.max(row_y + 1.2, 5.0)

	return
		"formspec_version[3]" ..
		"size[8.5," .. panel_h .. "]" ..
		"background9[0,0;8.5," .. panel_h .. ";lualore_mood_bg.png;false;2]" ..
		"box[0,0;8.5,0.7;#1a2a3a]" ..
		"label[0.3,0.42;Lore — Active Quest]" ..
		"label[0.3,0.95;" ..
			minetest.colorize("#FFDD88", minetest.formspec_escape(quest.name)) ..
		"]" ..
		"box[0,1.2;8.5,0.03;#334455]" ..
		rows ..
		"box[0," .. (row_y - 0.05) .. ";8.5,0.03;#334455]" ..
		"label[0.3," .. (row_y + 0.35) .. ";" ..
			minetest.colorize("#AAAAAA", "Follow the waypoint marker to return.") ..
		"]"
end

--------------------------------------------------------------------
-- Public API (kept for compatibility with quest accept/decline code)
--------------------------------------------------------------------
function lualore.sky_folk_tracker.show(player)
	-- no-op: the Lore tab is always accessible via inventory / /quest
end

function lualore.sky_folk_tracker.hide(player)
	-- no-op
end

--------------------------------------------------------------------
-- /quest chat command — opens the lore panel directly
--------------------------------------------------------------------
minetest.register_chatcommand("quest", {
	params      = "",
	description = "Show your active Sky Folk quest",
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then return false, "Player not found." end
		local fs = build_lore_formspec(player)
		if fs then
			minetest.show_formspec(name, "lualore:quest_lore", fs)
		end
		return true
	end,
})

--------------------------------------------------------------------
-- Hook the default inventory formspec to inject a Lore tab
-- We use register_on_player_receive_fields to intercept the tab
-- button, and override_item to inject the tab into the sfinv page.
--------------------------------------------------------------------

-- Check which inventory mod is available
local has_sfinv   = minetest.get_modpath("sfinv")   ~= nil
local has_unified = minetest.get_modpath("unified_inventory") ~= nil

if has_sfinv then
	sfinv.register_page("lualore:lore", {
		title = "Lore",
		get = function(self, player, context)
			local pname = player:get_player_name()
			local content = ""

			if not lualore.sky_folk_pins or not lualore.sky_folk_pins.has(pname) then
				content =
					"label[0.3,0.5;" ..
						minetest.colorize("#AAAAAA", "No active quest.") ..
					"]" ..
					"label[0.3,1.1;" ..
						minetest.colorize("#666666",
							"Liberate a Sky Folk and accept their quest offer.") ..
					"]"
			else
				local quest = lualore.sky_folk_pins.get_quest(pname)
				if quest then
					content = "label[0.3,0.2;" ..
						minetest.colorize("#FFDD88",
							minetest.formspec_escape(quest.name)) .. "]"
					local row_y = 0.7
					for _, req in ipairs(quest.required_items) do
						local have = count_in_inv(player, req.name)
						local clr  = have >= req.count and "#88FF88" or "#FF8888"
						content = content ..
							"item_image[0.3," .. row_y .. ";0.9,0.9;" .. req.name .. "]" ..
							"label[1.35," .. (row_y + 0.35) .. ";" ..
								minetest.formspec_escape(item_display_name(req.name)) ..
								" x" .. req.count .. "]" ..
							"label[5.5," .. (row_y + 0.35) .. ";" ..
								minetest.colorize(clr, have .. " / " .. req.count) .. "]"
						row_y = row_y + 1.1
					end
					content = content ..
						"label[0.3," .. (row_y + 0.2) .. ";" ..
							minetest.colorize("#AAAAAA",
								"Follow the waypoint to return.") .. "]"
				end
			end

			return sfinv.make_formspec(player, context,
				"box[0,0;7.5,4.5;#111a22]" .. content,
				true)
		end,
	})

elseif has_unified then
	unified_inventory.register_page("lualore_lore", {
		get_formspec = function(player)
			local pname = player:get_player_name()
			local fs = "background[0.06,0.99;7.89,7.49;unified_inventory_form.png]"

			if not lualore.sky_folk_pins or not lualore.sky_folk_pins.has(pname) then
				fs = fs ..
					"label[0.3,1.5;" ..
						minetest.colorize("#AAAAAA", "No active quest.") .. "]"
			else
				local quest = lualore.sky_folk_pins.get_quest(pname)
				if quest then
					fs = fs ..
						"label[0.3,1.0;" ..
							minetest.colorize("#FFDD88",
								minetest.formspec_escape(quest.name)) .. "]"
					local row_y = 1.6
					for _, req in ipairs(quest.required_items) do
						local have = count_in_inv(player, req.name)
						local clr  = have >= req.count and "#88FF88" or "#FF8888"
						fs = fs ..
							"item_image[0.3," .. row_y .. ";0.9,0.9;" .. req.name .. "]" ..
							"label[1.35," .. (row_y + 0.35) .. ";" ..
								minetest.formspec_escape(item_display_name(req.name)) ..
								" x" .. req.count .. "]" ..
							"label[5.5," .. (row_y + 0.35) .. ";" ..
								minetest.colorize(clr, have .. " / " .. req.count) .. "]"
						row_y = row_y + 1.1
					end
				end
			end
			return { formspec = fs }
		end,
	})

	unified_inventory.register_button("lualore_lore", {
		type    = "image",
		image   = "lualore_desire_trade.png",
		tooltip = "Lore — Active Quest",
		action  = function(player)
			unified_inventory.set_inventory_formspec(player, "lualore_lore")
		end,
	})

else
	-- Fallback: no inventory mod detected, /quest command is the only access point.
	-- We show a simple standalone formspec via /quest (already registered above).
	minetest.log("action",
		"[lualore] No sfinv or unified_inventory found — Lore accessible via /quest only.")
end

minetest.log("action", "[lualore] Sky Folk tracker (Lore tab) loaded")
