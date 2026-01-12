-- villagers.lua
local S = minetest.get_translator("lualore")

--------------------------------------------------------------------
-- Biome / spawn configuration
--------------------------------------------------------------------
local biome_spawn_config = {
	grassland = {
		nodes = {"default:dirt_with_grass", "default:cobble", "default:dirt_with_coniferous_litter", "default:clay"},
		markers = {"beds:bed_bottom"},
		stay_near = {"beds:bed_bottom"}
	},
	desert = {
		nodes = {"default:desert_sand", "group:wool"},
		markers = {"lualore:hookah", "lualore:desertcrpet"},
		stay_near = {"lualore:hookah", "lualore:desertcrpet"}
	},
	savanna = {
		nodes = {"default:dry_dirt_with_dry_grass"},
		markers = {"lualore:savannashrine"},
		stay_near = {"lualore:savannashrine"}
	},
	lake = {
		nodes = {"default:dirt", "default:sand"},
		markers = {"lualore:fishtrap"},
		stay_near = {"lualore:fishtrap"}
	},
	ice = {
		nodes = {"default:snowblock", "default:ice", "default:snow"},
		markers = {"lualore:sledge"},
		stay_near = {"lualore:sledge"}
	},
	cannibal = {
		nodes = {"default:dirt_with_grass", "default:dirt_with_rainforest_litter"},
		markers = {"lualore:cannibalshrine"},
		stay_near = {"lualore:cannibalshrine"}
	}
}

--------------------------------------------------------------------
-- Villager class definitions
--------------------------------------------------------------------
local villager_classes = {
	hostile = {
		type = "monster",
		passive = false,
		damage = 8,
		hp_min = 70,
		hp_max = 100,
		armor = 100,
		attack_type = "dogfight",
		attacks_monsters = true,
		attack_npcs = true,
		reach = 2,
		drops = {},
		trade_items = {},
	},
	raider = {
		type = "monster",
		passive = false,
		damage = 6,
		hp_min = 60,
		hp_max = 90,
		armor = 100,
		attack_type = "dogfight",
		attacks_monsters = true,
		attack_npcs = true,
		reach = 2,
		drops = {
			{name = "default:iron_lump", chance = 1, min = 0, max = 2}
		},
		trade_items = {},
	},
	ranger = {
		type = "npc",
		passive = true,
		damage = 5,
		hp_min = 50,
		hp_max = 80,
		armor = 120,
		attack_type = "dogfight",
		attacks_monsters = true,
		attack_npcs = false,
		reach = 2,
		drops = {
			{name = "default:copper_lump", chance = 1, min = 0, max = 1},
			{name = "default:tin_lump", chance = 1, min = 0, max = 1}
		},
		trade_items = {"farming:bread", "default:apple"},
	},
	jeweler = {
		type = "npc",
		passive = true,
		damage = 2,
		hp_min = 30,
		hp_max = 50,
		armor = 80,
		attack_type = "dogfight",
		attacks_monsters = true,
		attack_npcs = false,
		reach = 1,
		drops = {
			{name = "default:gold_lump", chance = 1, min = 0, max = 1},
			{name = "default:diamond", chance = 2, min = 0, max = 1}
		},
		trade_items = {"farming:bread","default:gold_lump"},
	},
	farmer = {
		type = "npc",
		passive = true,
		damage = 3,
		hp_min = 40,
		hp_max = 70,
		armor = 100,
		attack_type = "dogfight",
		attacks_monsters = true,
		attack_npcs = false,
		reach = 1,
		drops = {
			{name = "farming:wheat", chance = 1, min = 0, max = 2},
			{name = "farming:bread", chance = 1, min = 0, max = 1}
		},
		trade_items = {"farming:bread", "farming:wheat"},
	},
	blacksmith = {
		type = "npc",
		passive = true,
		damage = 4,
		hp_min = 70,
		hp_max = 100,
		armor = 150,
		attack_type = "dogfight",
		attacks_monsters = true,
		attack_npcs = false,
		reach = 1,
		drops = {
			{name = "default:iron_lump", chance = 1, min = 0, max = 2},
			{name = "default:steel_ingot", chance = 1, min = 0, max = 1}
		},
		trade_items = {"farming:bread","default:iron_lump", "default:coal_lump"},
	},
	fisherman = {
		type = "npc",
		passive = true,
		damage = 2,
		hp_min = 35,
		hp_max = 60,
		armor = 90,
		attack_type = "dogfight",
		attacks_monsters = true,
		attack_npcs = false,
		reach = 1,
		drops = {
			{name = "lualore:catfish_raw", chance = 1, min = 0, max = 2}
		},
		trade_items = {"farming:bread", "default:paper"},
	},
	cleric = {
		type = "npc",
		passive = true,
		damage = 3,
		hp_min = 50,
		hp_max = 75,
		armor = 100,
		attack_type = "dogfight",
		attacks_monsters = true,
		attack_npcs = false,
		reach = 2,
		drops = {
			{name = "default:mese_crystal", chance = 1, min = 0, max = 1}
		},
		trade_items = {"farming:bread","default:mese_crystal"},
	},
	bum = {
		type = "npc",
		passive = true,
		damage = 1,
		hp_min = 20,
		hp_max = 40,
		armor = 70,
		attack_type = "dogfight",
		attacks_monsters = true,
		attack_npcs = false,
		reach = 1,
		drops = {
			{name = "default:stick", chance = 1, min = 0, max = 2}
		},
		trade_items = {"farming:bread", "default:apple"},
	},
	entertainer = {
		type = "npc",
		passive = true,
		damage = 2,
		hp_min = 30,
		hp_max = 55,
		armor = 80,
		attack_type = "dogfight",
		attacks_monsters = true,
		attack_npcs = false,
		reach = 1,
		drops = {
			{name = "default:gold_lump", chance = 1, min = 0, max = 1}
		},
		trade_items = {"farming:bread","default:gold_lump"},
	},
	witch = {
		type = "monster",
		passive = false,
		damage = 7,
		hp_min = 60,
		hp_max = 90,
		armor = 110,
		attack_type = "dogfight",
		attacks_monsters = true,
		attack_npcs = false,
		reach = 1,  -- Melee attack range
		drops = {
			{name = "default:mese_crystal", chance = 1, min = 0, max = 1},
			{name = "lualore:zombietame", chance = 3, min = 0, max = 1}
		},
		trade_items = {},  -- Witches don't trade
	},
}

local class_order = {"hostile", "raider", "ranger", "jeweler", "farmer", "blacksmith",
                     "fisherman", "cleric", "bum", "entertainer", "witch"}

--------------------------------------------------------------------
-- Register a single villager mob
--------------------------------------------------------------------
local function register_villager(class_name, class_def, biome_name, biome_config)
	local mob_name = "lualore:" .. biome_name .. "_" .. class_name

	-- Determine which do_custom function to use
	local custom_function
	if class_name == "witch" then
		-- Witches use magic-based custom function
		custom_function = function(self, dtime)
			if lualore.witch_magic then
				lualore.witch_magic.do_custom(self, dtime)
			end
		end
	else
		-- Regular villagers use standard behavior
		custom_function = function(self, dtime)
			-- Wrap in error handler to prevent crashes
			local success, err = pcall(function()
				-- Update mood system
				if lualore.mood then
					lualore.mood.update_mood(self, dtime)
				end

				-- Update enhanced behaviors
				if lualore.behaviors then
					lualore.behaviors.update(self, dtime)
				end
			end)

			if not success then
				minetest.log("warning", "[lualore] do_custom error: " .. tostring(err))
			end
		end
	end

	mobs:register_mob(mob_name, {
		type = class_def.type,
		passive = class_def.passive,
		damage = class_def.damage,
		attack_type = class_def.attack_type,
		attacks_monsters = class_def.attacks_monsters,
		attack_npcs = class_def.attack_npcs,
		owner_loyal = true,
		pathfinding = true,
		hp_min = class_def.hp_min,
		hp_max = class_def.hp_max,
		armor = class_def.armor,
		reach = class_def.reach,
		collisionbox = {-0.35, 0.0, -0.35, 0.35, 1.8, 0.35},
		stepheight = 1.1,
		visual = "mesh",
		mesh = "character.b3d",
		textures = {
			{class_name .. "1.png"},
			{class_name .. "2.png"},
		},
		visual_size = {x=1, y=1},
		makes_footstep_sound = true,
		sounds = {},
		walk_velocity = 1,
		walk_chance = 15,
		run_velocity = 3,
		jump = true,
		drops = class_def.drops,
		water_damage = 0,
		lava_damage = 2,
		light_damage = 0,
		follow = {},
		stay_near = {biome_config.stay_near, 5},
		view_range = 15,
		owner = "",
		order = "follow",
		fear_height = 3,
		nv_trade_items = class_def.trade_items or {},
		animation = {
			speed_normal = 30,
			stand_start = 0,
			stand_end = 79,
			walk_start = 168,
			walk_end = 187,
			punch_start = 189,
			punch_end = 198,
			die_start = 162,
			die_end = 166,
			die_speed = 15,
			die_loop = false,
			die_rotate = true,
		},

		do_custom = custom_function,

		on_activate = function(self, staticdata, dtime_s)
			-- Wrap everything in error handler to prevent crashes
			local success, err = pcall(function()
				-- Deserialize saved data
				if staticdata and staticdata ~= "" then
					local success, data = pcall(minetest.deserialize, staticdata)
					if success and data then
						self.health = data.health or self.health
						self.owner = data.owner or ""
						self.tamed = data.tamed or false
						self.nametag = data.nametag or ""

						-- Restore mood data
						if lualore.mood and data.mood then
							lualore.mood.on_activate_extra(self, data.mood)
						end

						-- Restore behavior data
						if lualore.behaviors and data.behaviors then
							lualore.behaviors.load_save_data(self, data.behaviors)
						end
					end
				end

				-- Initialize mood system
				if lualore.mood then
					lualore.mood.init_npc(self)
				end

				-- Initialize behaviors system
				if lualore.behaviors then
					lualore.behaviors.init_house(self)
				end
			end)

			if not success then
				minetest.log("warning", "[lualore] on_activate error: " .. tostring(err))
			end
		end,

		get_staticdata = function(self)
			-- Catch all serialization errors and return empty string
			local success, result = pcall(function()
				-- Prevent death entity issues
				if self.state == "die" or self.dead then
					return ""
				end

				-- Serialize minimal essential data
				local tmp = {
					health = self.health or 0,
					owner = self.owner or "",
					tamed = self.tamed or false,
					nametag = self.nametag or "",
				}

				-- Add mood data if available
				if lualore.mood then
					tmp.mood = lualore.mood.get_staticdata_extra(self)
				end

				-- Add behavior data if available
				if lualore.behaviors then
					tmp.behaviors = lualore.behaviors.get_save_data(self)
				end

				return minetest.serialize(tmp)
			end)

			if success then
				return result
			else
				-- Log error and return empty string to prevent crash
				minetest.log("warning", "[lualore] Serialization error: " .. tostring(result))
				return ""
			end
		end,

		on_die = function(self, pos)
			-- Clean up mood indicator
			if self.nv_mood_indicator_id then
				local indicator = minetest.get_objects_by_id(self.nv_mood_indicator_id)
				if indicator and indicator[1] then
					indicator[1]:remove()
				end
				self.nv_mood_indicator_id = nil
			end

			-- Clean up entity immediately on death to prevent serialization issues
			if self.object then
				self.object:remove()
			end
			return true
		end,

		on_punch = function(self, hitter, time_from_last_punch, tool_capabilities, dir)
			minetest.log("action", "[lualore] on_punch called")

			-- Check if hitter is a player
			if not hitter or not hitter:is_player() then
				minetest.log("action", "[lualore] Not a player punch")
				return
			end

			local item = hitter:get_wielded_item()
			local item_name = item:get_name()
			local player_name = hitter:get_player_name()

			minetest.log("action", "[lualore] Player: " .. player_name .. " Item: " .. item_name)
			minetest.log("action", "[lualore] Has trade_items: " .. tostring(self.nv_trade_items ~= nil))
			minetest.log("action", "[lualore] Wants trade: " .. tostring(self.nv_wants_trade))

			-- Check if player is holding a trade item this villager wants
			if self.nv_trade_items then
				local wants_this_item = false
				for _, trade_item in ipairs(self.nv_trade_items) do
					if item_name == trade_item then
						wants_this_item = true
						break
					end
				end

				minetest.log("action", "[lualore] Wants this item: " .. tostring(wants_this_item))

				if wants_this_item and self.nv_wants_trade then
					-- Take the item from player (if not creative)
					if not mobs.is_creative(player_name) then
						item:take_item()
						hitter:set_wielded_item(item)
					end

					-- Drop a random item from the villager's drop table
					local pos = self.object:get_pos()
					if pos and self.drops then
						pos.y = pos.y + 0.5
						local drop_list = {}

						-- Build list of possible drops based on chance
						for _, drop_def in ipairs(self.drops) do
							if math.random(1, drop_def.chance) == 1 then
								local count = math.random(drop_def.min, drop_def.max)
								if count > 0 then
									table.insert(drop_list, {name = drop_def.name, count = count})
								end
							end
						end

						-- Drop the items
						if #drop_list > 0 then
							for _, drop in ipairs(drop_list) do
								minetest.add_item(pos, {name = drop.name, count = drop.count})
							end
							minetest.chat_send_player(player_name, S("Trade successful!"))
						else
							minetest.chat_send_player(player_name, S("Villager has nothing to trade right now."))
						end
					end

					-- Reset trade interest after successful trade
					self.nv_wants_trade = false
					self.nv_trade_interest_timer = 0

					-- Update mood for positive interaction
					if lualore.mood then
						lualore.mood.on_interact(self, hitter)
					end

					return
				end
			end

			-- If not a valid trade, do nothing (no damage)
			return
		end,

		on_rightclick = function(self, clicker)
			local item = clicker:get_wielded_item()
			local name = clicker:get_player_name()
			local item_name = item:get_name()
			local is_sneaking = clicker:get_player_control().sneak

			-- SNEAK + RIGHT-CLICK: Trading
			if is_sneaking and self.nv_trade_items then
				local wants_this_item = false
				for _, trade_item in ipairs(self.nv_trade_items) do
					if item_name == trade_item then
						wants_this_item = true
						break
					end
				end

				if wants_this_item and self.nv_wants_trade then
					-- Take the item from player (if not creative)
					if not mobs.is_creative(name) then
						item:take_item()
						clicker:set_wielded_item(item)
					end

					-- Drop a random item from the villager's drop table
					local pos = self.object:get_pos()
					if pos and self.drops then
						pos.y = pos.y + 0.5
						local drop_list = {}

						-- Build list of possible drops based on chance
						for _, drop_def in ipairs(self.drops) do
							if math.random(1, drop_def.chance) == 1 then
								local count = math.random(drop_def.min, drop_def.max)
								if count > 0 then
									table.insert(drop_list, {name = drop_def.name, count = count})
								end
							end
						end

						-- Drop the items
						if #drop_list > 0 then
							for _, drop in ipairs(drop_list) do
								minetest.add_item(pos, {name = drop.name, count = drop.count})
							end
							minetest.chat_send_player(name, S("Trade successful!"))
						else
							minetest.chat_send_player(name, S("Villager has nothing to trade right now."))
						end
					end

					-- Reset trade interest after successful trade
					self.nv_wants_trade = false
					self.nv_trade_interest_timer = 0

					-- Update mood for positive interaction
					if lualore.mood then
						lualore.mood.on_interact(self, clicker)
					end

					return
				elseif wants_this_item and not self.nv_wants_trade then
					minetest.chat_send_player(name, S("Villager is not interested in trading right now."))
					return
				end
			end

			-- Feed with bread (reduces hunger and heals)
			if item_name == "farming:bread" then
				minetest.log("action", "[lualore] Bread feeding triggered")

				if lualore.mood then
					minetest.log("action", "[lualore] mood module exists, calling on_feed")
					lualore.mood.on_feed(self, clicker, 40)
				else
					minetest.log("error", "[lualore] mood module is nil!")
				end

				if not mobs.is_creative(name) then
					item:take_item()
					clicker:set_wielded_item(item)
				end

				minetest.chat_send_player(name, S("Villager fed!"))
				return
			end

			-- Feed with apple (reduces hunger less but still heals)
			if item_name == "default:apple" then
				minetest.log("action", "[lualore] Apple feeding triggered")

				if lualore.mood then
					minetest.log("action", "[lualore] mood module exists, calling on_feed")
					lualore.mood.on_feed(self, clicker, 25)
				else
					minetest.log("error", "[lualore] mood module is nil!")
				end

				if not mobs.is_creative(name) then
					item:take_item()
					clicker:set_wielded_item(item)
				end

				minetest.chat_send_player(name, S("Villager fed!"))
				return
			end

			-- feed to heal npc
			if mobs:feed_tame(self, clicker, 8, true, true) then
				return
			end

			-- capture npc with net or lasso
			if mobs:capture_mob(self, clicker, 0, 15, 25, false, nil) then return end

			-- protect npc with mobs:protector
			if mobs:protect(self, clicker) then return end

			-- owner can toggle follow / stand
			if self.owner and self.owner == name then
				if self.order == "follow" then
					self.attack = nil
					self.order = "stand"
					self.state = "stand"
					self:set_animation("stand")
					self:set_velocity(0)
					minetest.chat_send_player(name, S("Slavetrader stands still."))
				else
					self.order = "follow"
					minetest.chat_send_player(name, S("Slavetrader will follow you."))
				end
			end
		end,
	})

	mobs:register_egg(mob_name,
		S(biome_name:gsub("^%l", string.upper) .. " " .. class_name:gsub("^%l", string.upper)),
		"character.png")
end

--------------------------------------------------------------------
-- Register all biome + class combinations
--------------------------------------------------------------------
for biome_name, biome_config in pairs(biome_spawn_config) do
	for class_name, class_def in pairs(villager_classes) do
		register_villager(class_name, class_def, biome_name, biome_config)
	end
end

--------------------------------------------------------------------
-- Village detection & spawning
--------------------------------------------------------------------
local villages_spawned = {}

local function find_village_center(pos, biome_markers, radius)
	local marker_positions = minetest.find_nodes_in_area(
		{x=pos.x-radius, y=pos.y-10, z=pos.z-radius},
		{x=pos.x+radius, y=pos.y+10, z=pos.z+radius},
		biome_markers
	)

	if #marker_positions > 0 then
		local center = {x=0, y=0, z=0, count=0}
		for _, mpos in ipairs(marker_positions) do
			center.x = center.x + mpos.x
			center.y = center.y + mpos.y
			center.z = center.z + mpos.z
			center.count = center.count + 1
		end

		center.x = math.floor(center.x / center.count)
		center.y = math.floor(center.y / center.count)
		center.z = math.floor(center.z / center.count)

		return {x=center.x, y=center.y, z=center.z}
	end

	return nil
end

local function get_village_key(pos)
	return math.floor(pos.x/50) .. "," .. math.floor(pos.z/50)
end

local function spawn_villagers_near(center_pos, biome_name)
	local biome_config = biome_spawn_config[biome_name]
	if not biome_config then return end

	local spawn_radius = 15
	local class_index = 0

	for _, class_name in ipairs(class_order) do
		local mob_name = "lualore:" .. biome_name .. "_" .. class_name

		local angle = (class_index / #class_order) * math.pi * 2
		local distance = math.random(5, spawn_radius)

		local spawn_pos = {
			x = center_pos.x + math.cos(angle) * distance,
			y = center_pos.y,
			z = center_pos.z + math.sin(angle) * distance
		}

		local ground_pos = minetest.find_node_near(spawn_pos, 5, biome_config.nodes)
		if ground_pos then
			ground_pos.y = ground_pos.y + 1
			minetest.add_entity(ground_pos, mob_name)
		end

		class_index = class_index + 1
	end
end

-- Automatic village spawning temporarily disabled
-- minetest.register_on_generated(function(minp, maxp, blockseed)
-- 	for biome_name, biome_config in pairs(biome_spawn_config) do
-- 		local center_pos = find_village_center(
-- 			{x=(minp.x+maxp.x)/2, y=(minp.y+maxp.y)/2, z=(minp.z+maxp.z)/2},
-- 			biome_config.markers,
-- 			40
-- 		)

-- 		if center_pos then
-- 			local village_key = get_village_key(center_pos)

-- 			if not villages_spawned[village_key] then
-- 				villages_spawned[village_key] = true
-- 				minetest.after(2, function()
-- 					spawn_villagers_near(center_pos, biome_name)
-- 				end)
-- 			end
-- 		end
-- 	end
-- end)

--------------------------------------------------------------------
-- Migration entities for old/renamed mob types
--------------------------------------------------------------------
-- Register a dummy entity that self-removes to handle old entity names
local old_entity_names = {
	"lualore:grassland_friendly",
	"lualore:desert_friendly",
	"lualore:savanna_friendly",
	"lualore:lake_friendly",
	"lualore:ice_friendly",
}

for _, old_name in ipairs(old_entity_names) do
	minetest.register_entity(old_name, {
		initial_properties = {
			physical = false,
			collisionbox = {0, 0, 0, 0, 0, 0},
			visual = "sprite",
			visual_size = {x=0.01, y=0.01},
			textures = {"blank.png"},
			is_visible = false,
			static_save = false,
		},
		on_activate = function(self, staticdata, dtime_s)
			-- Remove immediately - this is just to prevent errors
			self.object:remove()
		end,
	})
end

print(S("[MOD] Luanti Villagers - Villagers loaded"))
