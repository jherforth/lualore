local S = minetest.get_translator("lualore")

mobs:register_mob("lualore:toad", {
stepheight = 3,
	type = "monster",
	passive = false,
	attack_type = "explode",
	explosion_radius = 2,
	explosion_damage__radius = 6,
	explosion_timer = 2,
	attack_npcs = false,
	attack_animals = false,
	reach = 3,
	damage = 18,
	hp_min = 15,
	hp_max = 30,
	armor = 100,
	collisionbox = {-0.268, -0.01, -0.268,  0.268, 0.25, 0.268},
	visual = "mesh",
	mesh = "Toad.b3d",
	drawtype = "front",
	textures = {
		{"texturetoad.png"},

	},
sounds = {
		random = "",},
	makes_footstep_sound = true,
	walk_velocity = 1.5,
	run_velocity = 2,
	runaway = true,
        runaway_from = {"animalworld:bear", "animalworld:crocodile", "animalworld:tiger", "animalworld:spider", "animalworld:spidermale", "animalworld:shark", "animalworld:hyena", "animalworld:kobra", "animalworld:monitor", "animalworld:snowleopard", "animalworld:volverine", "livingfloatlands:deinotherium", "livingfloatlands:carnotaurus", "livingfloatlands:lycaenops", "livingfloatlands:smilodon", "livingfloatlands:tyrannosaurus", "livingfloatlands:velociraptor", "animalworld:divingbeetle", "animalworld:scorpion"},
	jump = true,
	jump_height = 6,
	sounds = {
		attack = "lualore_toad",
		random = "lualore_toad2",
		damage = "lualore_toad",
		death = "lualore_toad",
		distance = 10,
	},
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
	},
	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
	fear_height = 6,
	animation = {
		speed_normal = 50,
		stand_start = 1,
		stand_end = 100,
                walk_speed = 100,
		walk_start = 100,
		walk_end = 200,
		fly_start = 300, -- swim animation
		fly_end = 400,
	},
	fly_in = {"default:water_source", "default:river_water_source", "default:water_flowing", "default:river_water_flowing"},
	floats = 0,
	follow = {"fishing:bait:worm", "ethereal:worm", "animalworld:ant", "animalworld:termite"},
	view_range = 13,
	get_staticdata = function(self)
		local success, result = pcall(function()
			if self.state == "die" or self.dead then
				return ""
			end
			local tmp = {
				health = self.health or 0,
				owner = self.owner or "",
				tamed = self.tamed or false,
				nametag = self.nametag or "",
			}
			return minetest.serialize(tmp)
		end)
		if success then
			return result
		else
			minetest.log("warning", "[lualore] Serialization error: " .. tostring(result))
			return ""
		end
	end,
	on_die = function(self, pos)
		if self.object then
			self.object:remove()
		end
		return true
	end,
	on_rightclick = function(self, clicker)

		if mobs:feed_tame(self, clicker, 8, true, true) then return end
		if mobs:protect(self, clicker) then return end
		if mobs:capture_mob(self, clicker, 0, 25, 0, false, nil) then return end
	end,
	do_custom = function(self, dtime)
		-- Toads nose doors open too
		if lualore.behaviors then
			lualore.behaviors.handle_doors(self, dtime, self._target)
		end
	end,
})


if minetest.get_modpath("ethereal") then
	spawn_on = "ethereal:prairie_dirt", "default:dirt_with_grass", "ethereal:green_dirt"
end

if not mobs.custom_spawn_lualore then
mobs:spawn({
	name = "lualore:toad",
	nodes = {"default:dirt_with_grass"}, {"default:dirt_with_rainforest_litter"}, {"default:dry_dirt_with_dry_grass"},
	neighbors = {"group:grass", "group:normal_grass"},
	min_light = 0,
	interval = 60,
	chance = 2000, -- 15000
	active_object_count = 1,
	min_height = 1,
	max_height = 15,
        day_toogle = false
})
end


mobs:register_egg("lualore:toad", S("Toad"), "atoad.png", 0)


mobs:alias_mob("lualore:toad", "lualore:toad") -- compatibility


mobs:register_mob("lualore:toadtamed", {
stepheight = 3,
	type = "NPC",
	passive = false,
	attack_type = "explode",
	explosion_radius = 4,
	explosion_damage__radius = 12,
	explosion_timer = 4,
	attack_npcs = false,
	attack_animals = false,
	attack_monsters = true,
	reach = 3,
	damage = 550,
	hp_min = 25,
	hp_max = 50,
	armor = 100,
	collisionbox = {-0.268, -0.01, -0.268,  0.268, 0.25, 0.268},
	visual = "mesh",
	mesh = "Toad.b3d",
	drawtype = "front",
	textures = {
		{"texturetoad.png"},

	},
sounds = {
		random = "",},
	makes_footstep_sound = true,
        owner_loyal = true,
	owner = "",
	order = "follow",
	pathfinding = true,
	walk_velocity = 1.5,
	run_velocity = 2,
	runaway = false,
        runaway_from = {"animalworld:bear", "animalworld:crocodile", "animalworld:tiger", "animalworld:spider", "animalworld:spidermale", "animalworld:shark", "animalworld:hyena", "animalworld:kobra", "animalworld:monitor", "animalworld:snowleopard", "animalworld:volverine", "livingfloatlands:deinotherium", "livingfloatlands:carnotaurus", "livingfloatlands:lycaenops", "livingfloatlands:smilodon", "livingfloatlands:tyrannosaurus", "livingfloatlands:velociraptor", "animalworld:divingbeetle", "animalworld:scorpion"},
	jump = true,
	jump_height = 6,
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 1},
	},
	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
	fear_height = 6,
	animation = {
		speed_normal = 50,
		stand_start = 1,
		stand_end = 100,
                walk_speed = 100,
		walk_start = 100,
		walk_end = 200,
		fly_start = 300, -- swim animation
		fly_end = 400,
	},
	fly_in = {"default:water_source", "default:river_water_source", "default:water_flowing", "default:river_water_flowing"},
	floats = 0,
	follow = {"fishing:bait:worm", "ethereal:worm", "animalworld:ant", "animalworld:termite"},
	view_range = 13,
	get_staticdata = function(self)
		local tmp = {}
		for tag, stat in pairs(self) do
			local tstat = type(stat)
			local ttag = type(tag)
			if tstat ~= "function" and tstat ~= "userdata"
				and ttag ~= "function" and ttag ~= "userdata"
				and tag ~= "object" then
				tmp[tag] = stat
			end
		end
		return minetest.serialize(tmp)
	end,

on_rightclick = function(self, clicker)

		-- feed to heal npc
		if mobs:feed_tame(self, clicker, 8, true, true) then return end

		-- capture npc with net or lasso
		if mobs:capture_mob(self, clicker, nil, 5, 80, false, nil) then return end

		-- protect npc with mobs:protector
		if mobs:protect(self, clicker) then return end

		local item = clicker:get_wielded_item()
		local name = clicker:get_player_name()




		-- by right-clicking owner can switch npc between follow and stand
		if self.owner and self.owner == name then

			if self.order == "follow" then

				self.attack = nil
				self.order = "stand"
				self.state = "stand"
				self:set_animation("stand")
				self:set_velocity(0)

				minetest.chat_send_player(name, S("Exploding Toad stands still."))
			else
				self.order = "follow"

				minetest.chat_send_player(name, S("Exploding Toad will follow you."))
			end
		end
	end,
	do_custom = function(self, dtime)
		-- Tamed toads nose doors open too
		if lualore.behaviors then
			lualore.behaviors.handle_doors(self, dtime, self._target)
		end
	end,
})



mobs:register_egg("lualore:toadtamed", S("Tamed Exploding Toad"), "atoad.png", 0)


mobs:alias_mob("lualore:toadtamed", "lualore:toadtamed") -- compatibility

minetest.register_node("lualore:toadbag", {
	description = S"Bag full of toads!",
	tiles = {
		"lualore_toadbag_top.png",
		"lualore_toadbag_bottom.png",
		"lualore_toadbag_right.png",
		"lualore_toadbag_left.png",
		"lualore_toadbag_back.png",
		"lualore_toadbag_front.png"
	},
	groups = {crumbly = 3},
	drop = "lualore:toadtamed 9",
	sounds = default.node_sound_dirt_defaults(),
})




