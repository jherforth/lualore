-- npcmood.lua
local S = minetest.get_translator("lualore")

lualore.mood = {}

--------------------------------------------------------------------
-- CONFIGURATION SETTINGS
--------------------------------------------------------------------

-- Visual mood indicators (set to true to show sprites above NPCs)
lualore.mood.enable_visual_indicators = true

-- Sound timing (seconds between sounds for each NPC)
-- Lower = more frequent sounds, Higher = less frequent sounds
lualore.mood.sound_repeat_delay = 14

-- Sound volume settings
-- sound_volume: Master volume for mood sounds (0.0 = silent, 1.0 = full volume)
-- Recommended range: 0.3 to 0.7 for ambient NPC sounds
lualore.mood.sound_volume = 0.3

-- Sound distance settings (in nodes/blocks)
-- sound_max_distance: Maximum distance player can hear NPC sounds
-- sound_fade_distance: Distance where sounds start to fade out
-- NPCs beyond max_distance won't be heard at all
lualore.mood.sound_max_distance = 8       -- Can hear up to 8 blocks away
lualore.mood.sound_fade_distance = 4      -- Starts fading at 4 blocks

--------------------------------------------------------------------

lualore.mood.trade_items = {}

lualore.mood.moods = {
	happy   = {texture = "lualore_mood_happy.png"},
	content = {texture = "lualore_mood_content.png"},
	neutral = {texture = "lualore_mood_neutral.png"},
	sad     = {texture = "lualore_mood_sad.png"},
	angry   = {texture = "lualore_mood_angry.png"},
	hungry  = {texture = "lualore_mood_hungry.png"},
	lonely  = {texture = "lualore_mood_lonely.png"},
	scared  = {texture = "lualore_mood_scared.png"},
}

lualore.mood.desires = {
	food          = {texture = "lualore_desire_food.png",          priority = 1},
	trade         = {texture = "lualore_desire_trade.png",         priority = 2},
	companionship = {texture = "lualore_desire_companionship.png", priority = 3},
	safety        = {texture = "lualore_desire_safety.png",        priority = 4},
	rest          = {texture = "lualore_desire_rest.png",          priority = 5},
}

--------------------------------------------------------------------
-- NPC mood initialisation
--------------------------------------------------------------------
function lualore.mood.init_npc(self)
	if not self.nv_mood then
		self.nv_mood               = "neutral"
		self.nv_mood_value         = 50
		self.nv_hunger             = 1
		self.nv_loneliness         = 0
		self.nv_fear               = 0
		self.nv_last_fed           = 0
		self.nv_last_interaction   = 0
		self.nv_current_desire     = nil
		self.nv_mood_timer         = 0
		self.nv_mood_indicator     = nil
		self.nv_sound_timer        = 0
	end
end

--------------------------------------------------------------------
-- Helper: get mood name from numeric value
--------------------------------------------------------------------
function lualore.mood.get_mood_from_value(value)
	if value >= 80 then return "happy"
	elseif value >= 60 then return "content"
	elseif value >= 40 then return "neutral"
	elseif value >= 20 then return "sad"
	else return "angry" end
end

--------------------------------------------------------------------
-- Desire calculation
--------------------------------------------------------------------
function lualore.mood.calculate_desire(self)
	local desires = {}

	if self.nv_hunger > 70 then
		table.insert(desires, {name = "food", urgency = self.nv_hunger})
	end
	if self.nv_loneliness > 60 then
		table.insert(desires, {name = "companionship", urgency = self.nv_loneliness})
	end
	if self.nv_fear > 50 then
		table.insert(desires, {name = "safety", urgency = self.nv_fear})
	end
	if self.health and self.health < 15 then
		table.insert(desires, {name = "rest", urgency = 100 - self.health})
	end
	if self.nv_wants_trade then
		table.insert(desires, {name = "trade", urgency = 85})
	end

	if #desires == 0 then return nil end

	table.sort(desires, function(a, b) return a.urgency > b.urgency end)
	return desires[1].name
end

--------------------------------------------------------------------
-- Check for nearby trade items
--------------------------------------------------------------------
function lualore.mood.check_nearby_trade_items(self)
	if not self.object then
		return false
	end

	-- Fill in the trade list for anything that spawned before villagers.lua
	-- started stamping it on activation. This used to be a second copy of
	-- the class trade tables living here, which had already drifted out of
	-- step with the real ones; it now reads the single published table.
	if not self.nv_trade_items or #self.nv_trade_items == 0 then
		local class_name = lualore.jobs and lualore.jobs.get_class(self)
			or (self.name or ""):match("_([^_]+)$")
		local items = class_name and lualore.jobs
			and lualore.jobs.trade_items_for(class_name)
		if items then
			-- a private copy: the published table is shared by every
			-- villager of this class
			self.nv_trade_items = table.copy(items)
		end
	end

	if not self.nv_trade_items or #self.nv_trade_items == 0 then
		-- Still no trade items - this NPC doesn't trade
		return false
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
					for _, trade_item in ipairs(self.nv_trade_items) do
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
-- Play mood sound if player is nearby (with 3D positional audio)
--------------------------------------------------------------------
function lualore.mood.play_sound_if_nearby(self, dtime)
	if not self.object then return end
	local pos = self.object:get_pos()
	if not pos then return end

	self.nv_sound_timer = (self.nv_sound_timer or 0) + dtime
	if self.nv_sound_timer < lualore.mood.sound_repeat_delay then
		return
	end

	local nearby_players = minetest.get_connected_players()
	for _, player in ipairs(nearby_players) do
		local player_pos = player:get_pos()
		if player_pos then
			local distance = vector.distance(pos, player_pos)
			-- Only play if within max hearing distance
			if distance <= lualore.mood.sound_max_distance then
				local sound_to_play = nil

				if self.nv_wants_trade then
					sound_to_play = "trade"
				elseif self.nv_current_desire == "rest" then
					sound_to_play = "rest"
				elseif self.nv_mood then
					sound_to_play = self.nv_mood
				end

				if sound_to_play then
					-- Calculate distance-based volume falloff with steeper curve
					local distance_ratio = math.min(1, distance / lualore.mood.sound_fade_distance)
					-- Use exponential falloff for more rapid sound decay
					local distance_gain = math.max(0, 1.0 - (distance_ratio * distance_ratio * 0.95))
					local final_gain = lualore.mood.sound_volume * distance_gain

					minetest.sound_play(sound_to_play, {
						pos = pos,
						max_hear_distance = lualore.mood.sound_max_distance,
						gain = final_gain,
						pitch = 1.0,
						loop = false,
					}, true)  -- true = ephemeral (3D positional audio)
					self.nv_sound_timer = 0
				end
				break
			end
		end
	end
end

--------------------------------------------------------------------
-- Mood update (called from do_custom)
--------------------------------------------------------------------
function lualore.mood.update_mood(self, dtime)
	lualore.mood.init_npc(self)

	-- Mark as fully activated after first update cycle
	self.nv_activation_timer = (self.nv_activation_timer or 0) + dtime
	if self.nv_activation_timer >= 2 then
		self.nv_fully_activated = true
	end

	-- Sound timer runs every frame
	lualore.mood.play_sound_if_nearby(self, dtime)

	self.nv_mood_timer = (self.nv_mood_timer or 0) + dtime
	if self.nv_mood_timer < 5 then return end
	self.nv_mood_timer = 0

	-- ---- trade interest -------------------------------------------------
	local player_has_trade_item = lualore.mood.check_nearby_trade_items(self)
	if player_has_trade_item then
		self.nv_wants_trade = true
		self.nv_trade_interest_timer = 0
	else
		self.nv_trade_interest_timer = (self.nv_trade_interest_timer or 0) + 5
		if self.nv_trade_interest_timer > 10 then
			self.nv_wants_trade = false
		end
	end

	-- ---- basic needs ---------------------------------------------------
	local time_factor = 5
	self.nv_hunger           = math.min(100, (self.nv_hunger or 1) + time_factor * 0.1)
	self.nv_last_fed         = (self.nv_last_fed or 0) + time_factor
	self.nv_last_interaction = (self.nv_last_interaction or 0) + time_factor

	if self.nv_last_interaction > 120 then
		self.nv_loneliness = math.min(100, (self.nv_loneliness or 0) + 5)
	else
		self.nv_loneliness = math.max(0, (self.nv_loneliness or 0) - 2)
	end

	if self.state == "attack" then
		self.nv_fear = math.min(100, (self.nv_fear or 0) + 15)
	elseif self.attack and self.attack:is_player() then
		self.nv_fear = math.min(100, (self.nv_fear or 0) + 15)
	elseif (self.following and self.following ~= self.owner) then
		self.nv_fear = math.min(100, (self.nv_fear or 0) + 10)
	else
		self.nv_fear = math.max(0, (self.nv_fear or 0) - 5)
	end

	-- ---- mood value ----------------------------------------------------
	local mood_value = 50
	mood_value = mood_value - (self.nv_hunger - 50) * 0.5
	mood_value = mood_value - (self.nv_loneliness - 30) * 0.3
	mood_value = mood_value - self.nv_fear * 0.4

	if self.owner and self.owner ~= "" then mood_value = mood_value + 10 end
	if self.health then mood_value = mood_value + (self.health - 50) * 0.2 end

	self.nv_mood_value = math.max(0, math.min(100, mood_value))

	-- ---- final mood string ---------------------------------------------
	local old_mood = self.nv_mood
	self.nv_mood = lualore.mood.get_mood_from_value(self.nv_mood_value)

	if self.nv_hunger > 80 then self.nv_mood = "hungry"
	elseif self.nv_fear > 70 then self.nv_mood = "scared"
	elseif self.nv_loneliness > 80 then self.nv_mood = "lonely" end

	self.nv_current_desire = lualore.mood.calculate_desire(self)
	lualore.mood.update_indicator(self)
end

--------------------------------------------------------------------
-- Cleanup mood indicator
--------------------------------------------------------------------
function lualore.mood.cleanup_indicator(self)
	if self.nv_mood_indicator then
		self.nv_mood_indicator:remove()
		self.nv_mood_indicator = nil
	end
end

--------------------------------------------------------------------
-- Mood indicator (floating icon above head)
--------------------------------------------------------------------
function lualore.mood.update_indicator(self)
	if not lualore.mood.enable_visual_indicators then return end
	if not self.object then return end
	if not self.nv_fully_activated then return end

	-- Remove old indicator
	if self.nv_mood_indicator then
		self.nv_mood_indicator:remove()
		self.nv_mood_indicator = nil
	end

	local pos = self.object:get_pos()
	if not pos then return end

	local mood_data   = lualore.mood.moods[self.nv_mood] or lualore.mood.moods.neutral
	local desire_data = self.nv_current_desire and lualore.mood.desires[self.nv_current_desire]

	local texture = mood_data.texture
	if desire_data and math.random(100) < 60 then
		texture = desire_data.texture
	end

	-- Create new indicator
	self.nv_mood_indicator = minetest.add_entity(pos, "lualore:mood_indicator")
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

		-- Store reference to parent NPC for info display
		local luaent = self.nv_mood_indicator:get_luaentity()
		if luaent then
			luaent.parent_npc = self
		end
	end
end

--------------------------------------------------------------------
-- Interaction callbacks
--------------------------------------------------------------------
function lualore.mood.on_feed(self, clicker, food_value)
	self.nv_hunger           = 1
	self.nv_last_fed         = 0
	self.nv_last_interaction = 0

	if self.health then
		self.health = math.min(self.hp_max or 20, self.health + 5)
	end

	if self.object then
		local pos = self.object:get_pos()
		if pos then
			-- Use higher volume for feeding sound since it's an action feedback
			minetest.sound_play("villager_fed", {
				pos = pos,
				max_hear_distance = lualore.mood.sound_max_distance,
				gain = lualore.mood.sound_volume * 1.4,  -- 40% louder than mood sounds
				pitch = 1.0,
				loop = false,
			}, true)  -- true = ephemeral (3D positional audio)
		end
	end

	lualore.mood.update_mood(self, 0)
end

function lualore.mood.on_interact(self, clicker)
	self.nv_last_interaction = 0
	self.nv_loneliness       = math.max(0, (self.nv_loneliness or 0) - 20)
	lualore.mood.update_mood(self, 0)
end

function lualore.mood.on_trade(self, clicker)
	self.nv_last_interaction = 0
	self.nv_loneliness       = math.max(0, (self.nv_loneliness or 0) - 25)
	self.nv_hunger           = math.max(0, (self.nv_hunger or 50) - 15)

	if self.object then
		local pos = self.object:get_pos()
		if pos then
			minetest.sound_play("trade", {
				pos = pos,
				max_hear_distance = 5,
				gain = 0.7,
			})
		end
	end

	lualore.mood.update_mood(self, 0)
end

--------------------------------------------------------------------
-- Serialization (only plain data)
--------------------------------------------------------------------
function lualore.mood.get_staticdata_extra(self)
	return {
		nv_mood               = self.nv_mood,
		nv_mood_value         = self.nv_mood_value,
		nv_hunger             = self.nv_hunger,
		nv_loneliness         = self.nv_loneliness,
		nv_fear               = self.nv_fear,
		nv_last_fed           = self.nv_last_fed,
		nv_last_interaction   = self.nv_last_interaction,
		nv_current_desire     = self.nv_current_desire,
		nv_sound_timer        = self.nv_sound_timer,
	}
end

function lualore.mood.on_activate_extra(self, data)
	if not data then return end
	self.nv_mood               = data.nv_mood or "neutral"
	self.nv_mood_value         = data.nv_mood_value or 50
	self.nv_hunger             = data.nv_hunger or 1
	self.nv_loneliness         = data.nv_loneliness or 0
	self.nv_fear               = data.nv_fear or 0
	self.nv_last_fed           = data.nv_last_fed or 0
	self.nv_last_interaction   = data.nv_last_interaction or 0
	self.nv_current_desire     = data.nv_current_desire
	self.nv_sound_timer        = data.nv_sound_timer or 0
end

--------------------------------------------------------------------
-- Mood-indicator entity
--------------------------------------------------------------------
minetest.register_entity("lualore:mood_indicator", {
	initial_properties = {
		physical      = false,
		collisionbox  = {-0.25, -0.25, -0.25, 0.25, 0.25, 0.25},
		visual        = "sprite",
		visual_size   = {x=0.25, y=0.25},
		textures      = {"lualore_mood_neutral.png"},
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

		-- Update infotext when pointed at
		if self.parent_npc then
			local npc = self.parent_npc
			local mood_name = npc.nv_mood or "neutral"
			local hunger = math.floor(npc.nv_hunger or 1)
			local health = math.floor(npc.health or 20)

			local mood_emoji = {
				happy = "😊",
				content = "🙂",
				neutral = "😐",
				sad = "😢",
				angry = "😠",
				hungry = "🍞",
				lonely = "💭",
				scared = "😨"
			}

			local info = string.format("%s HP:%d Hunger:%d",
				mood_emoji[mood_name] or "😐",
				health,
				hunger
			)

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










