local S = minetest.get_translator("lualore")

lualore.sky_liberation = {}

local storage = minetest.get_mod_storage()
local MUSIC_COOLDOWN = 3600

local function get_last_music_time()
	local time_str = storage:get_string("last_liberation_music")
	if time_str and time_str ~= "" then
		return tonumber(time_str) or 0
	end
	return 0
end

local function set_last_music_time(time)
	storage:set_string("last_liberation_music", tostring(time))
end

local function can_play_music()
	local current_time = os.time()
	local last_time = get_last_music_time()
	return (current_time - last_time) >= MUSIC_COOLDOWN
end

local function play_liberation_music(pos)
	if not can_play_music() then
		minetest.log("action", "[lualore] Liberation music on cooldown, skipping")
		return false
	end

	set_last_music_time(os.time())
	minetest.log("action", "[lualore] Playing liberation music at full volume")
	return true
end

local function spawn_liberation_particles(pos)
	minetest.add_particlespawner({
		amount = 100,
		time = 2,
		minpos = vector.subtract(pos, {x=0.5, y=0, z=0.5}),
		maxpos = vector.add(pos, {x=0.5, y=2.0, z=0.5}),
		minvel = {x=-2, y=1, z=-2},
		maxvel = {x=2, y=4, z=2},
		minacc = {x=0, y=-0.5, z=0},
		maxacc = {x=0, y=-0.5, z=0},
		minexptime = 1.5,
		maxexptime = 3.0,
		minsize = 1.5,
		maxsize = 3.0,
		texture = "lualore_particle_star.png^[colorize:#FFFF00:150",
		glow = 14
	})

	minetest.add_particlespawner({
		amount = 50,
		time = 2,
		minpos = vector.subtract(pos, {x=0.5, y=0, z=0.5}),
		maxpos = vector.add(pos, {x=0.5, y=2.0, z=0.5}),
		minvel = {x=-1, y=0.5, z=-1},
		maxvel = {x=1, y=2, z=1},
		minacc = {x=0, y=0, z=0},
		maxacc = {x=0, y=0, z=0},
		minexptime = 2.0,
		maxexptime = 4.0,
		minsize = 2.0,
		maxsize = 4.0,
		texture = "lualore_particle_circle.png^[colorize:#FFFFFF:200",
		glow = 12
	})
end

local function free_sky_folk(sky_folk_entity)
	if not sky_folk_entity or not sky_folk_entity.object then
		return false
	end

	if sky_folk_entity.liberated then
		return false
	end

	sky_folk_entity.type = "npc"
	sky_folk_entity.passive = true
	sky_folk_entity.attack_players = false
	sky_folk_entity.attack = nil
	sky_folk_entity.liberated = true

	sky_folk_entity.base_texture = {"sky_folk_freed.png"}
	sky_folk_entity.textures = {"sky_folk_freed.png"}

	sky_folk_entity.object:set_properties({
		textures = {"sky_folk_freed.png"}
	})

	minetest.after(0.1, function()
		if sky_folk_entity and sky_folk_entity.object then
			sky_folk_entity.object:set_properties({
				textures = {"sky_folk_freed.png"}
			})
		end
	end)

	local pos = sky_folk_entity.object:get_pos()
	if pos then
		spawn_liberation_particles(pos)
	end

	minetest.log("action", "[lualore] Sky Folk liberated at " .. minetest.pos_to_string(pos))
	return true
end

function lualore.sky_liberation.check_and_liberate(death_pos)
	local search_radius = 100

	local objects = minetest.get_objects_inside_radius(death_pos, search_radius)

	local valkyries_found = false
	local sky_folk_to_free = {}

	for _, obj in ipairs(objects) do
		local ent = obj:get_luaentity()
		if ent and ent.name then
			if ent.name:match("lualore:.*_valkyrie") then
				valkyries_found = true
				break
			elseif ent.name == "lualore:sky_folk" and not ent.liberated then
				table.insert(sky_folk_to_free, ent)
			end
		end
	end

	if not valkyries_found and #sky_folk_to_free > 0 then
		minetest.log("action", "[lualore] All valkyries defeated! Liberating " .. #sky_folk_to_free .. " Sky Folk")

		play_liberation_music(death_pos)

		for _, sky_folk in ipairs(sky_folk_to_free) do
			free_sky_folk(sky_folk)
		end

		local players = minetest.get_connected_players()
		for _, player in ipairs(players) do
			local player_pos = player:get_pos()
			if player_pos and vector.distance(player_pos, death_pos) <= search_radius then
				minetest.chat_send_player(player:get_player_name(),
					S("The Valkyries have been defeated! The Sky Folk are free!"))
			end
		end

		return true
	end

	return false
end

function lualore.sky_liberation.serialize_sky_folk_data(self)
	return {
		liberated = self.liberated or false
	}
end

function lualore.sky_liberation.deserialize_sky_folk_data(self, data)
	if not data then return end

	if data.liberated then
		self.liberated = true
		self.type = "npc"
		self.passive = true
		self.attack_players = false
		self.attack = nil

		self.base_texture = {"sky_folk_freed.png"}
		self.textures = {"sky_folk_freed.png"}

		self.object:set_properties({
			textures = {"sky_folk_freed.png"}
		})

		minetest.after(0.1, function()
			if self and self.object then
				self.object:set_properties({
					textures = {"sky_folk_freed.png"}
				})
			end
		end)

		minetest.log("action", "[lualore] Sky Folk restored as liberated")
	end
end

minetest.log("action", "[lualore] Sky Liberation system loaded")
