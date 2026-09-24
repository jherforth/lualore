-- job_entertainer.lua
-- ===================================================================
-- THE ENTERTAINER - the village's mood, made visible
-- ===================================================================
-- He performs at whichever biome prop stands nearest his bed - the
-- hookah, the sledge, a shrine - and everyone within earshot cheers up.
-- Mechanically he is the counterweight to the whole mood system: a
-- village with an entertainer working stays happier than one without,
-- and you can see him doing it.
--
-- Watching costs nothing and earns a little standing, but only now and
-- then, so you cannot stand in front of him all afternoon and become
-- kin by loitering.
-- ===================================================================

local S = minetest.get_translator("lualore")

local player_watch = {}

local entertainer = lualore.jobs and lualore.jobs.classes
	and lualore.jobs.classes.entertainer
if not entertainer then
	minetest.log("warning",
		"[lualore] job_entertainer: no entertainer class to attach to")
	return
end

local CROWD_RADIUS = 8
local SHOW_EVERY = 6     -- seconds between flourishes
local WATCH_REWARD_GAP = 90 -- seconds before watching pays again

local TUNES = {"happy", "content", "trade"}

local function flourish(pos)
	minetest.add_particlespawner({
		amount = 18,
		time = 1.0,
		minpos = {x = pos.x - 0.8, y = pos.y + 0.2, z = pos.z - 0.8},
		maxpos = {x = pos.x + 0.8, y = pos.y + 1.8, z = pos.z + 0.8},
		minvel = {x = -0.6, y = 0.5, z = -0.6},
		maxvel = {x = 0.6, y = 1.3, z = 0.6},
		minacc = {x = 0, y = -0.4, z = 0},
		maxacc = {x = 0, y = -0.2, z = 0},
		minexptime = 0.8,
		maxexptime = 1.8,
		minsize = 0.7,
		maxsize = 1.8,
		texture = "lualore_particle_star.png",
		glow = 10,
	})
end

entertainer.on_work = function(self, job_def, pos)
	local now = minetest.get_gametime()
	if (self.nv_show_at or 0) > now then
		return
	end
	self.nv_show_at = now + SHOW_EVERY

	-- Turn on the spot as he performs.
	if self.object then
		self.object:set_yaw((self.nv_show_yaw or 0) + 1.1)
		self.nv_show_yaw = (self.nv_show_yaw or 0) + 1.1
	end
	flourish(pos)
	minetest.sound_play(TUNES[math.random(#TUNES)],
		{pos = pos, gain = 0.4, max_hear_distance = 16}, true)

	-- Cheer the neighbours.
	if lualore.behaviors and lualore.behaviors.find_nearby_villagers then
		for _, other in ipairs(lualore.behaviors.find_nearby_villagers(self, CROWD_RADIUS)) do
			if other ~= self then
				other.nv_mood_value = math.min(100, (other.nv_mood_value or 50) + 8)
				other.nv_loneliness = math.max(0, (other.nv_loneliness or 0) - 12)
			end
		end
	end

	-- And anyone watching.
	for _, player in ipairs(minetest.get_connected_players()) do
		local ppos = player:get_pos()
		if ppos and vector.distance(ppos, pos) <= CROWD_RADIUS then
			local player_name = player:get_player_name()
			if (player_watch[player_name] or 0) <= now then
				player_watch[player_name] = now + WATCH_REWARD_GAP
				if lualore.standing and lualore.standing.earn then
					lualore.standing.earn(player, self, "show")
				end
			end
		end
	end
end

entertainer.on_interact = function(self, player)
	minetest.chat_send_player(player:get_player_name(), S(
		"The entertainer sweeps you a bow. \"Stay a while - the village is merrier for an audience.\""))
	if lualore.mood and lualore.mood.on_interact then
		lualore.mood.on_interact(self, player)
	end
	return true
end

minetest.log("action", "[lualore] Entertainer job loaded")
