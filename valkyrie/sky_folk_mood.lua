-- sky_folk_mood.lua
local S = minetest.get_translator("lualore")

lualore.sky_folk_mood = {}

--------------------------------------------------------------------
-- CONFIGURATION SETTINGS
--------------------------------------------------------------------

lualore.sky_folk_mood.enable_visual_indicators = true

lualore.sky_folk_mood.sound_repeat_delay = 18

lualore.sky_folk_mood.sound_volume = 0.25

lualore.sky_folk_mood.sound_max_distance = 10
lualore.sky_folk_mood.sound_fade_distance = 5

--------------------------------------------------------------------

local sky_folk_sounds = {"skyfolk1", "skyfolk2", "skyfolk3", "skyfolk4"}

local trade_items = {"farming:bread", "default:feather", "default:mese_crystal_fragment"}


lualore.sky_folk_mood.moods = {
	happy   = {texture = "lualore_mood_happy.png"},
	content = {texture = "lualore_mood_content.png"},
}

lualore.sky_folk_mood.desires = {
	trade = {texture = "lualore_desire_trade.png"},
}

--------------------------------------------------------------------
-- NPC mood initialisation
--------------------------------------------------------------------
function lualore.sky_folk_mood.init_npc(self)
	self.nv_mood           = "happy"
	self.nv_mood_value     = 100
	self.nv_wants_trade    = false
	self.nv_current_desire = nil
	self.nv_mood_timer     = 0
	self.nv_mood_indicator = nil
	self.nv_sound_timer    = 0
end

--------------------------------------------------------------------
-- Helper: get mood name from numeric value
--------------------------------------------------------------------
function lualore.sky_folk_mood.get_mood_from_value(value)
	if value >= 60 then return "happy"
	else return "content" end
end

--------------------------------------------------------------------
-- Desire calculation
--------------------------------------------------------------------
function lualore.sky_folk_mood.calculate_desire(self)
	if self.nv_wants_trade then
		return "trade"
	end
	return nil
end

--------------------------------------------------------------------
-- Check for nearby trade items
-- Prefers quest-based item detection when a quest is assigned
--------------------------------------------------------------------
function lualore.sky_folk_mood.check_nearby_trade_items(self)
	if not self.object then return false end

	if lualore.sky_folk_quests and self.sf_quest then
		return lualore.sky_folk_quests.player_nearby_has_quest_item(self)
	end

	local pos = self.object:get_pos()
	if not pos then return false end

	local objects = minetest.get_objects_inside_radius(pos, 4)
	for _, obj in ipairs(objects) do
		if obj:is_player() then
			local wielded = obj:get_wielded_item()
			if wielded then
				local name = wielded:get_name()
				if name and name ~= "" then
					for _, trade_item in ipairs(trade_items) do
						if name == trade_item then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

--------------------------------------------------------------------
-- Play sound if player is nearby (3D positional audio)
--------------------------------------------------------------------
function lualore.sky_folk_mood.play_sound_if_nearby(self, dtime)
	if not self.object then return end
	local pos = self.object:get_pos()
	if not pos then return end

	self.nv_sound_timer = (self.nv_sound_timer or 0) + dtime
	if self.nv_sound_timer < lualore.sky_folk_mood.sound_repeat_delay then
		return
	end

	local nearby_players = minetest.get_connected_players()
	for _, player in ipairs(nearby_players) do
		local player_pos = player:get_pos()
		if player_pos then
			local distance = vector.distance(pos, player_pos)
			if distance <= lualore.sky_folk_mood.sound_max_distance then
				local sound_name = sky_folk_sounds[math.random(1, #sky_folk_sounds)]

				local distance_ratio = math.min(1, distance / lualore.sky_folk_mood.sound_fade_distance)
				local distance_gain = math.max(0, 1.0 - (distance_ratio * distance_ratio * 0.95))
				local final_gain = lualore.sky_folk_mood.sound_volume * distance_gain

				minetest.sound_play(sound_name, {
					pos = pos,
					max_hear_distance = lualore.sky_folk_mood.sound_max_distance,
					gain = final_gain,
					pitch = 1.0,
					loop = false,
				}, true)
				self.nv_sound_timer = 0
				break
			end
		end
	end
end

--------------------------------------------------------------------
-- Mood update (called from do_custom when liberated)
--------------------------------------------------------------------
function lualore.sky_folk_mood.update_mood(self, dtime)
	lualore.sky_folk_mood.init_npc_if_needed(self)

	self.nv_activation_timer = (self.nv_activation_timer or 0) + dtime
	if self.nv_activation_timer >= 2 then
		self.nv_fully_activated = true
	end

	lualore.sky_folk_mood.play_sound_if_nearby(self, dtime)

	self.nv_mood_timer = (self.nv_mood_timer or 0) + dtime
	if self.nv_mood_timer < 5 then return end
	self.nv_mood_timer = 0

	local player_has_trade_item = lualore.sky_folk_mood.check_nearby_trade_items(self)
	if player_has_trade_item then
		self.nv_wants_trade = true
		self.nv_trade_interest_timer = 0
	else
		self.nv_trade_interest_timer = (self.nv_trade_interest_timer or 0) + 5
		if self.nv_trade_interest_timer > 10 then
			self.nv_wants_trade = false
		end
	end

	self.nv_mood_value = 100
	self.nv_mood = lualore.sky_folk_mood.get_mood_from_value(self.nv_mood_value)

	self.nv_current_desire = lualore.sky_folk_mood.calculate_desire(self)
	lualore.sky_folk_mood.update_indicator(self)
end

--------------------------------------------------------------------
-- Guard: only init fields that are missing (for on_activate restore)
--------------------------------------------------------------------
function lualore.sky_folk_mood.init_npc_if_needed(self)
	if self.nv_mood == nil then
		self.nv_mood           = "happy"
	end
	if self.nv_mood_value == nil then
		self.nv_mood_value     = 100
	end
	if self.nv_wants_trade == nil then
		self.nv_wants_trade    = false
	end
	if self.nv_current_desire == nil then
		self.nv_current_desire = nil
	end
	if self.nv_mood_timer == nil then
		self.nv_mood_timer     = 0
	end
	if self.nv_mood_indicator == nil then
		self.nv_mood_indicator = nil
	end
	if self.nv_sound_timer == nil then
		self.nv_sound_timer    = 0
	end
end

--------------------------------------------------------------------
-- Cleanup mood indicator
--------------------------------------------------------------------
function lualore.sky_folk_mood.cleanup_indicator(self)
	if self.nv_mood_indicator then
		self.nv_mood_indicator:remove()
		self.nv_mood_indicator = nil
	end
end

--------------------------------------------------------------------
-- Mood indicator (floating icon above head)
--------------------------------------------------------------------
function lualore.sky_folk_mood.update_indicator(self)
	if not lualore.sky_folk_mood.enable_visual_indicators then return end
	if not self.object then return end
	if not self.nv_fully_activated then return end

	if self.nv_mood_indicator then
		self.nv_mood_indicator:remove()
		self.nv_mood_indicator = nil
	end

	local pos = self.object:get_pos()
	if not pos then return end

	local mood_data   = lualore.sky_folk_mood.moods[self.nv_mood] or lualore.sky_folk_mood.moods.happy
	local desire_data = self.nv_current_desire and lualore.sky_folk_mood.desires[self.nv_current_desire]

	local texture = mood_data.texture
	if self.nv_has_active_quest then
		texture = lualore.sky_folk_mood.desires.trade.texture
	elseif desire_data and math.random(100) < 60 then
		texture = desire_data.texture
	end

	self.nv_mood_indicator = minetest.add_entity(pos, "lualore:sky_folk_mood_indicator")
	if self.nv_mood_indicator then
		self.nv_mood_indicator:set_attach(
			self.object,
			"",
			{x=0, y=20, z=0},
			{x=0, y=0, z=0}
		)
		self.nv_mood_indicator:set_properties({
			textures = {texture},
		})

		local luaent = self.nv_mood_indicator:get_luaentity()
		if luaent then
			luaent.parent_npc = self
		end
	end
end

--------------------------------------------------------------------
-- Trade interaction callback
--------------------------------------------------------------------
function lualore.sky_folk_mood.on_trade(self, clicker)
	self.nv_wants_trade = false
	self.nv_trade_interest_timer = 0

	if self.object then
		local pos = self.object:get_pos()
		if pos then
			local sound_name = sky_folk_sounds[math.random(1, #sky_folk_sounds)]
			minetest.sound_play(sound_name, {
				pos = pos,
				max_hear_distance = lualore.sky_folk_mood.sound_max_distance,
				gain = lualore.sky_folk_mood.sound_volume * 1.4,
				pitch = 1.0,
				loop = false,
			}, true)
		end
	end

	lualore.sky_folk_mood.update_mood(self, 0)
end

--------------------------------------------------------------------
-- Serialization
--------------------------------------------------------------------
function lualore.sky_folk_mood.get_staticdata_extra(self)
	return {
		nv_mood           = self.nv_mood,
		nv_mood_value     = self.nv_mood_value,
		nv_wants_trade    = self.nv_wants_trade,
		nv_current_desire = self.nv_current_desire,
		nv_sound_timer    = self.nv_sound_timer,
	}
end

function lualore.sky_folk_mood.on_activate_extra(self, data)
	if not data then return end
	self.nv_mood           = data.nv_mood or "happy"
	self.nv_mood_value     = data.nv_mood_value or 100
	self.nv_wants_trade    = data.nv_wants_trade or false
	self.nv_current_desire = data.nv_current_desire
	self.nv_sound_timer    = data.nv_sound_timer or 0
end

--------------------------------------------------------------------
-- Sky Folk mood indicator entity
--------------------------------------------------------------------
minetest.register_entity("lualore:sky_folk_mood_indicator", {
	initial_properties = {
		physical      = false,
		collisionbox  = {-0.25, -0.25, -0.25, 0.25, 0.25, 0.25},
		visual        = "sprite",
		visual_size   = {x=0.25, y=0.25},
		textures      = {"lualore_mood_happy.png"},
		is_visible    = true,
		pointable     = true,
		static_save   = false,
		glow          = 5,
	},

	on_step = function(self, dtime)
		if not self.object then return end

		local parent = self.object:get_attach()
		if not parent then
			self.object:remove()
			return
		end

		if self.parent_npc then
			local npc = self.parent_npc
			local mood_name = npc.nv_mood or "happy"
			local wants_trade = npc.nv_wants_trade or false

			local info = mood_name
			if wants_trade then
				if npc.sf_quest then
					info = mood_name .. " (seeks: " .. npc.sf_quest.name .. ")"
				else
					info = mood_name .. " (wants to trade)"
				end
			end

			self.object:set_properties({
				infotext = info
			})
		end
	end,

	get_staticdata = function(self)
		return ""
	end,

	on_activate = function(self, staticdata)
	end,
})

minetest.log("action", "[lualore] Sky Folk mood system loaded")
