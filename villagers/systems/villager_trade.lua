-- villager_trade.lua
-- ===================================================================
-- TRADING - a counter to haggle over, not a handful of loot
-- ===================================================================
-- Trading used to be: hold the one item a villager wanted, punch them,
-- and receive a random roll of their death-drop table on the ground. You
-- could not see what was on offer, the villager had to be in the mood,
-- and what you got was a lottery.
--
-- Now each villager keeps a short list of standing offers - so much of
-- this for so much of that - and right-clicking while sneaking opens
-- them. The offers are fixed per villager (rolled from their position,
-- so they survive a reload and the same villager always deals in the
-- same things), and how many they will show you depends on their mood
-- and on how well the village knows you.
--
-- Trades are limited per villager per day, which keeps a village from
-- being an infinite goods machine and gives a reason to know more than
-- one of them.
-- ===================================================================

lualore = lualore or {}
lualore.trade = {}

local S = minetest.get_translator("lualore")

local FORM = "lualore:trade"

-- Most trades one villager will do in an in-game day.
local DAILY_TRADES = 4

-- How many offers are visible, before mood and standing.
local BASE_OFFERS = 2
local MAX_OFFERS = 4

-- ------------------------------------------------------------------
-- What each trade deals in
-- ------------------------------------------------------------------
-- `want` is what the player hands over, `offer` is what they get back.
-- Villagers buy raw and sell worked, so trading in circles between them
-- does not pay.
local POOLS = {
	farmer = {
		{want = {"farming:wheat", 8},        offer = {"farming:bread", 3}},
		{want = {"default:apple", 10},       offer = {"default:gold_lump", 1}},
		{want = {"default:gold_lump", 1},    offer = {"farming:wheat", 10}},
		{want = {"farming:bread", 2},        offer = {"default:sapling", 3}},
	},
	blacksmith = {
		{want = {"default:iron_lump", 5},    offer = {"default:steel_ingot", 3}},
		{want = {"default:coal_lump", 10},   offer = {"default:steel_ingot", 2}},
		{want = {"default:steel_ingot", 6},  offer = {"default:steel_pick", 1}},
		{want = {"default:steel_ingot", 5},  offer = {"default:steel_axe", 1}},
	},
	fisherman = {
		{want = {"farming:string", 5},       offer = {"lualore:catfish_raw", 4}},
		{want = {"lualore:catfish_raw", 8},  offer = {"lualore:pearl", 1}},
		{want = {"default:paper", 8},        offer = {"default:clay_lump", 5}},
		{want = {"default:clay_lump", 6},    offer = {"farming:string", 4}},
	},
	cleric = {
		{want = {"default:mese_crystal_fragment", 9}, offer = {"default:mese_crystal", 1}},
		{want = {"default:gold_ingot", 3},   offer = {"default:mese_crystal", 1}},
		{want = {"farming:bread", 8},        offer = {"default:mese_crystal_fragment", 4}},
		{want = {"default:obsidian", 4},     offer = {"default:mese_crystal", 2}},
	},
	jeweler = {
		{want = {"default:gold_lump", 7},    offer = {"default:gold_ingot", 5}},
		{want = {"lualore:pearl", 3},        offer = {"default:diamond", 1}},
		{want = {"default:mese_crystal", 3}, offer = {"default:gold_ingot", 6}},
		{want = {"default:gold_ingot", 4},   offer = {"lualore:pearl", 2}},
	},
	entertainer = {
		{want = {"default:gold_lump", 3},    offer = {"wool:white", 6}},
		{want = {"farming:string", 10},      offer = {"default:paper", 8}},
		{want = {"default:paper", 6},        offer = {"default:gold_lump", 1}},
	},
	ranger = {
		{want = {"default:apple", 8},        offer = {"default:sapling", 5}},
		{want = {"farming:string", 6},       offer = {"default:flint", 4}},
		{want = {"default:flint", 6},        offer = {"default:steel_sword", 1}},
	},
	bum = {
		{want = {"farming:bread", 2},        offer = {"default:flint", 4}},
		{want = {"default:apple", 4},        offer = {"default:stick", 10}},
	},
}

-- Drop any offer naming an item this game does not have, once.
local pools_checked = nil

local function pool_for(class)
	if not pools_checked then
		pools_checked = {}
		for name, offers in pairs(POOLS) do
			local kept = {}
			for _, offer in ipairs(offers) do
				if minetest.registered_items[offer.want[1]]
						and minetest.registered_items[offer.offer[1]] then
					kept[#kept + 1] = offer
				else
					minetest.log("info", "[lualore] trade: " .. name ..
						" offer dropped, missing item")
				end
			end
			pools_checked[name] = kept
		end
	end
	return pools_checked[class] or {}
end

-- ------------------------------------------------------------------
-- A villager's own offers
-- ------------------------------------------------------------------
-- Rolled from the bed position, so they are the same every time this
-- villager is loaded without having to be saved, and two villagers of
-- the same trade in one village still deal in different things.
local function offer_seed(self)
	local anchor = self.nv_house_pos or (self.object and self.object:get_pos())
	if not anchor then
		return 1
	end
	return math.abs(math.floor(anchor.x) * 73856093
		+ math.floor(anchor.z) * 19349663) % 2147483647
end

-- How many of them this player gets to see.
local function visible_count(self, player)
	local count = BASE_OFFERS
	local mood = self.nv_mood
	if mood == "happy" or mood == "content" then
		count = count + 1
	end
	if lualore.standing and lualore.standing.get then
		local value = lualore.standing.get(player:get_player_name(),
			self.object:get_pos())
		if value >= 50 then
			count = count + 1
		end
	end
	return math.min(count, MAX_OFFERS)
end

function lualore.trade.offers_for(self)
	if self.nv_offers then
		return self.nv_offers
	end
	local class = lualore.jobs and lualore.jobs.get_class(self)
	local pool = pool_for(class)
	if #pool == 0 then
		self.nv_offers = {}
		return self.nv_offers
	end

	-- Shuffle a copy with the villager's own seed.
	local pr = PcgRandom(offer_seed(self))
	local order = {}
	for i = 1, #pool do
		order[i] = pool[i]
	end
	for i = #order, 2, -1 do
		local j = pr:next(1, i)
		order[i], order[j] = order[j], order[i]
	end
	self.nv_offers = order
	return order
end

-- ------------------------------------------------------------------
-- Daily limit
-- ------------------------------------------------------------------
local function trades_left(self)
	local today = minetest.get_day_count and minetest.get_day_count() or 0
	if self.nv_trade_day ~= today then
		self.nv_trade_day = today
		self.nv_trades_today = 0
	end
	return DAILY_TRADES - (self.nv_trades_today or 0)
end

-- ------------------------------------------------------------------
-- The window
-- ------------------------------------------------------------------
local open_with = {} -- player name -> villager entity

local function colour_for(has, needs)
	return has >= needs and "#88FF88" or "#FF8888"
end

function lualore.trade.show(player, self)
	local player_name = player:get_player_name()
	local offers = lualore.trade.offers_for(self)
	local shown = math.min(visible_count(self, player), #offers)
	local left = trades_left(self)

	local class = (lualore.jobs and lualore.jobs.get_class(self)) or "villager"
	local title = class:gsub("^%l", string.upper)

	local rows = ""
	local y = 1.5
	for i = 1, shown do
		local offer = offers[i]
		local want_name, want_count = offer.want[1], offer.want[2]
		local get_name, get_count = offer.offer[1], offer.offer[2]
		local held = lualore.inv.count(player, want_name)
		local affordable = held >= want_count and left > 0

		rows = rows
			.. "item_image[0.4," .. y .. ";1,1;" .. want_name .. "]"
			.. "label[1.6," .. (y + 0.3) .. ";"
				.. minetest.formspec_escape(lualore.inv.display_name(want_name))
				.. " x" .. want_count .. "]"
			.. "label[1.6," .. (y + 0.75) .. ";"
				.. minetest.colorize(colour_for(held, want_count),
					"you have " .. held) .. "]"
			.. "label[5.1," .. (y + 0.5) .. ";" .. minetest.colorize("#AAAAAA", "->") .. "]"
			.. "item_image[5.8," .. y .. ";1,1;" .. get_name .. "]"
			.. "label[7.0," .. (y + 0.5) .. ";"
				.. minetest.formspec_escape(lualore.inv.display_name(get_name))
				.. " x" .. get_count .. "]"

		if affordable then
			rows = rows .. "button[10.5," .. (y + 0.1) .. ";1.8,0.8;trade_"
				.. i .. ";" .. minetest.formspec_escape(S("Trade")) .. "]"
		else
			rows = rows .. "box[10.5," .. (y + 0.1) .. ";1.8,0.8;#33333366]"
				.. "label[10.75," .. (y + 0.5) .. ";"
				.. minetest.colorize("#888888", left > 0 and S("short") or S("done"))
				.. "]"
		end
		y = y + 1.35
	end

	if shown == 0 then
		rows = "label[0.4,2;" .. minetest.colorize("#AAAAAA",
			S("This one has nothing to trade.")) .. "]"
		y = 3.2
	end

	local footer
	if left <= 0 then
		footer = minetest.colorize("#FF8888",
			S("They have traded all they will today."))
	elseif shown < #offers then
		footer = minetest.colorize("#AAAAAA",
			S("@1 trades left today. Get to know them better and they will show you more.",
				left))
	else
		footer = minetest.colorize("#AAAAAA", S("@1 trades left today.", left))
	end

	local height = y + 1.6
	local fs = "formspec_version[3]"
		.. "size[12.8," .. height .. "]"
		.. "background9[0,0;12.8," .. height .. ";lualore_mood_bg.png;false;2]"
		.. "box[0,0;12.8,0.8;#1a2a3a]"
		.. "label[0.4,0.45;" .. minetest.formspec_escape(
			S("@1 - offers", title)) .. "]"
		.. "box[0,0.85;12.8,0.04;#334455]"
		.. rows
		.. "box[0," .. (y + 0.15) .. ";12.8,0.04;#334455]"
		.. "label[0.4," .. (y + 0.6) .. ";" .. footer .. "]"

	open_with[player_name] = self
	minetest.show_formspec(player_name, FORM, fs)
end

-- ------------------------------------------------------------------
-- Doing the trade
-- ------------------------------------------------------------------
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORM then
		return
	end
	local player_name = player:get_player_name()
	local self = open_with[player_name]

	if fields.quit then
		open_with[player_name] = nil
		return true
	end
	if not self or not self.object then
		return true
	end

	-- The villager has to still be there to trade with.
	local vpos = self.object:get_pos()
	if not vpos or vector.distance(player:get_pos(), vpos) > 6 then
		minetest.chat_send_player(player_name, S("You have walked away."))
		open_with[player_name] = nil
		minetest.close_formspec(player_name, FORM)
		return true
	end

	local index
	for key in pairs(fields) do
		local n = key:match("^trade_(%d+)$")
		if n then
			index = tonumber(n)
			break
		end
	end
	if not index then
		return true
	end

	local offers = lualore.trade.offers_for(self)
	local offer = offers[index]
	if not offer or index > visible_count(self, player) then
		return true
	end

	if trades_left(self) <= 0 then
		minetest.chat_send_player(player_name,
			S("They shake their head. \"Enough business for one day.\""))
		lualore.trade.show(player, self)
		return true
	end

	local want_name, want_count = offer.want[1], offer.want[2]
	if not lualore.inv.take(player, want_name, want_count) then
		minetest.chat_send_player(player_name, S("You do not have @1 x@2.",
			lualore.inv.display_name(want_name), want_count))
		lualore.trade.show(player, self)
		return true
	end

	lualore.inv.give(player, offer.offer[1], offer.offer[2])
	self.nv_trades_today = (self.nv_trades_today or 0) + 1

	minetest.chat_send_player(player_name, S("Traded @1 x@2 for @3 x@4.",
		lualore.inv.display_name(want_name), want_count,
		lualore.inv.display_name(offer.offer[1]), offer.offer[2]))

	if self.object then
		minetest.sound_play("trade",
			{pos = vpos, gain = 0.6, max_hear_distance = 8}, true)
	end
	-- The villager is pleased, and the village notices.
	if lualore.mood and lualore.mood.on_trade then
		lualore.mood.on_trade(self, player)
	end
	if lualore.standing and lualore.standing.earn then
		lualore.standing.earn(player, self, "trade")
	end

	-- Reopen so the counts update and they can trade again.
	lualore.trade.show(player, self)
	return true
end)

minetest.register_on_leaveplayer(function(player)
	open_with[player:get_player_name()] = nil
end)

-- ------------------------------------------------------------------
-- Persistence
-- ------------------------------------------------------------------
-- Offers are re-rolled from the bed position, so only the day's tally
-- needs saving.
function lualore.trade.get_save_data(self)
	return {
		nv_trade_day = self.nv_trade_day,
		nv_trades_today = self.nv_trades_today,
	}
end

function lualore.trade.on_activate_extra(self, data)
	if not data then
		return
	end
	self.nv_trade_day = data.nv_trade_day
	self.nv_trades_today = data.nv_trades_today
end

minetest.log("action", "[lualore] Villager trading window loaded")
