-- job_cleric.lua
-- ===================================================================
-- THE CLERIC - keeps the village well, and will take you in
-- ===================================================================
-- At his altar he tends the village: villagers within earshot are healed
-- a little and their loneliness eased, which quietly props up the whole
-- mood system.
--
-- For a player, the altar is the thing that turns a village from a shop
-- into somewhere to come back to. Offer a mese crystal and the village
-- becomes where you wake up when you die, plus a blessing that wears off
-- after a few minutes.
-- ===================================================================

local S = minetest.get_translator("lualore")

local cleric = lualore.jobs and lualore.jobs.classes and lualore.jobs.classes.cleric
if not cleric then
	minetest.log("warning", "[lualore] job_cleric: no cleric class to attach to")
	return
end

local storage = minetest.get_mod_storage()

local TEND_RADIUS = 8
local TEND_EVERY = 5       -- seconds between blessings of the flock
local OFFERING = "default:mese_crystal"
local BLESSING_TIME = 240  -- seconds

-- ------------------------------------------------------------------
-- Wards: where a player wakes up
-- ------------------------------------------------------------------
local wards = {}

local function load_wards()
	local raw = storage:get_string("village_wards")
	if raw and raw ~= "" then
		local ok, data = pcall(minetest.deserialize, raw)
		if ok and type(data) == "table" then
			wards = data
		end
	end
end

local function save_wards()
	storage:set_string("village_wards", minetest.serialize(wards))
end

load_wards()

minetest.register_on_respawnplayer(function(player)
	local ward = wards[player:get_player_name()]
	if not ward then
		return false
	end
	player:set_pos(ward)
	minetest.chat_send_player(player:get_player_name(),
		S("The village calls you back."))
	return true -- we placed them; the engine should not
end)

-- ------------------------------------------------------------------
-- Tending the flock
-- ------------------------------------------------------------------
local function blessing_particles(pos)
	minetest.add_particlespawner({
		amount = 16,
		time = 1.2,
		minpos = {x = pos.x - 0.6, y = pos.y, z = pos.z - 0.6},
		maxpos = {x = pos.x + 0.6, y = pos.y + 1.4, z = pos.z + 0.6},
		minvel = {x = -0.2, y = 0.4, z = -0.2},
		maxvel = {x = 0.2, y = 0.9, z = 0.2},
		minacc = {x = 0, y = 0.1, z = 0},
		maxacc = {x = 0, y = 0.3, z = 0},
		minexptime = 1,
		maxexptime = 2,
		minsize = 0.6,
		maxsize = 1.4,
		texture = "lualore_particle_star.png",
		glow = 12,
	})
end

cleric.on_work = function(self, job_def, pos)
	local now = minetest.get_gametime()
	if (self.nv_tend_at or 0) > now then
		return
	end
	self.nv_tend_at = now + TEND_EVERY

	blessing_particles(self.nv_work_pos or pos)

	if not (lualore.behaviors and lualore.behaviors.find_nearby_villagers) then
		return
	end
	local tended = 0
	for _, other in ipairs(lualore.behaviors.find_nearby_villagers(self, TEND_RADIUS)) do
		if other ~= self then
			if other.health and other.hp_max and other.health < other.hp_max then
				other.health = math.min(other.hp_max, other.health + 2)
				if other.object then
					other.object:set_hp(other.health)
				end
			end
			other.nv_loneliness = math.max(0, (other.nv_loneliness or 0) - 10)
			other.nv_mood_value = math.min(100, (other.nv_mood_value or 50) + 4)
			tended = tended + 1
		end
	end
	if tended > 0 then
		minetest.sound_play("content",
			{pos = pos, gain = 0.25, max_hear_distance = 12}, true)
	end
end

cleric.on_interact = function(self, player)
	local player_name = player:get_player_name()
	local ward = wards[player_name]
	if ward then
		minetest.chat_send_player(player_name, S(
			"The cleric inclines his head. \"You are already spoken for here. Fall, and the village will have you back.\""))
	else
		minetest.chat_send_player(player_name, S(
			"The cleric gestures at his altar. \"Lay a mese crystal on it and this village will hold your name.\""))
	end
	return true
end

-- ------------------------------------------------------------------
-- The altar
-- ------------------------------------------------------------------
if minetest.registered_nodes["lualore:village_altar"] then
	minetest.override_item("lualore:village_altar", {
		on_rightclick = function(pos, node, clicker, itemstack)
			if not clicker or not clicker:is_player() then
				return itemstack
			end
			local player_name = clicker:get_player_name()

			local nearby = lualore.jobs and lualore.jobs.villager_near
				and lualore.jobs.villager_near(pos, "cleric", 8)
			if not nearby then
				minetest.chat_send_player(player_name,
					S("The altar is quiet. No cleric keeps it."))
				return itemstack
			end

			if itemstack:get_name() ~= OFFERING then
				minetest.chat_send_player(player_name,
					S("The cleric shakes his head. \"A mese crystal, laid on the stone.\""))
				return itemstack
			end

			-- The village centre is a better place to wake than the altar
			-- itself, which may be tucked against a wall.
			local where = pos
			if lualore.villages and lualore.villages.find_near then
				local rec = lualore.villages.find_near(pos, 90)
				if rec then
					where = {x = rec.x, y = (rec.y or pos.y) + 1, z = rec.z}
				end
			end
			wards[player_name] = {x = where.x, y = where.y, z = where.z}
			save_wards()

			if not (mobs and mobs.is_creative and mobs.is_creative(player_name)) then
				itemstack:take_item()
			end

			blessing_particles(pos)
			minetest.sound_play("magic",
				{pos = pos, gain = 0.7, max_hear_distance = 16}, true)
			minetest.chat_send_player(player_name, minetest.colorize("#FFDD88",
				S("The village will call you back when you fall.")))

			-- A short blessing on top, so the offering is felt at once.
			clicker:set_physics_override({speed = 1.2})
			minetest.after(BLESSING_TIME, function()
				local still = minetest.get_player_by_name(player_name)
				if still then
					still:set_physics_override({speed = 1})
					minetest.chat_send_player(player_name,
						S("The cleric's blessing fades."))
				end
			end)

			if lualore.standing and lualore.standing.earn then
				lualore.standing.earn(clicker, nearby, "job")
			end
			return itemstack
		end,
	})
end

minetest.log("action", "[lualore] Cleric job loaded")
