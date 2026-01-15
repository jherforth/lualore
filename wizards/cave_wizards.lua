-- cave_wizards.lua
-- Boss wizard entities for cave castle
-- Four wizards spawn together as a boss fight

local S = minetest.get_translator("lualore")

-- Track spawned wizard groups to prevent duplicates
local spawned_wizard_groups = {}
local storage = minetest.get_mod_storage()

local function load_spawned_groups()
	local data = storage:get_string("spawned_wizard_groups")
	if data and data ~= "" then
		spawned_wizard_groups = minetest.deserialize(data) or {}
	end
end

local save_timer = 0
minetest.register_globalstep(function(dtime)
	save_timer = save_timer + dtime
	if save_timer >= 60 then
		save_timer = 0
		storage:set_string("spawned_wizard_groups", minetest.serialize(spawned_wizard_groups))
	end
end)

load_spawned_groups()

--------------------------------------------------------------------
-- WIZARD ENTITY DEFINITIONS
--------------------------------------------------------------------

local wizard_types = {
	{
		name = "redwizard",
		texture = "redwizard.png",
		armor_item = "3d_armor:chestplate_bronze",
		do_custom = lualore.wizard_magic.red_do_custom,
		drops = {
			{name = "default:mese_crystal", chance = 1, min = 2, max = 5},
			{name = "default:diamond", chance = 1, min = 1, max = 3}
		}
	},
	{
		name = "whitewizard",
		texture = "whitewizard.png",
		armor_item = "3d_armor:chestplate_steel",
		do_custom = lualore.wizard_magic.white_do_custom,
		drops = {
			{name = "default:mese_crystal", chance = 1, min = 2, max = 5},
			{name = "default:diamond", chance = 1, min = 1, max = 3}
		}
	},
	{
		name = "goldwizard",
		texture = "goldwizard.png",
		armor_item = "3d_armor:chestplate_gold",
		do_custom = lualore.wizard_magic.gold_do_custom,
		drops = {
			{name = "default:mese_crystal", chance = 1, min = 2, max = 5},
			{name = "default:diamond", chance = 1, min = 1, max = 3},
			{name = "default:gold_lump", chance = 1, min = 3, max = 7}
		}
	},
	{
		name = "blackwizard",
		texture = "blackwizard.png",
		armor_item = "3d_armor:chestplate_mithril",
		do_custom = lualore.wizard_magic.black_do_custom,
		drops = {
			{name = "default:mese_crystal", chance = 1, min = 2, max = 5},
			{name = "default:diamond", chance = 1, min = 1, max = 3},
			{name = "default:obsidian", chance = 1, min = 2, max = 5}
		}
	}
}

-- Helper function to update wizard armor visual based on HP
local function update_wizard_armor(self, wizard_texture, armor_item)
	if not self or not self.object then return end

	-- Calculate armor visibility based on HP percentage
	local hp = self.health or 0
	local max_hp = self.hp_max or 150
	local hp_percent = hp / max_hp

	-- Show armor only if HP is above 30% (armor "breaks" when wizard is low health)
	if hp_percent > 0.3 and armor_item then
		-- Get armor texture from item name
		-- Format: 3d_armor:chestplate_type -> 3d_armor_chestplate_type.png
		local armor_texture = armor_item:gsub(":", "_") .. ".png"

		-- Combine wizard texture with armor overlay
		self.object:set_properties({
			textures = {wizard_texture .. "^" .. armor_texture}
		})
	else
		-- No armor - just base texture (armor broke or depleted)
		self.object:set_properties({
			textures = {wizard_texture}
		})
	end
end

-- Register each wizard as a mob
for _, wizard in ipairs(wizard_types) do
	local mob_name = "lualore:" .. wizard.name

	mobs:register_mob(mob_name, {
		type = "monster",
		passive = false,
		damage = 3,
		attack_type = "dogfight",
		attacks_monsters = false,
		attack_npcs = true,
		attack_players = true,
		owner_loyal = false,
		pathfinding = true,
		hp_min = 100,
		hp_max = 150,
		armor = 150,
		reach = 1,
		collisionbox = {-0.35, 0.0, -0.35, 0.35, 1.8, 0.35},
		stepheight = 1.1,
		visual = "mesh",
		mesh = "character.b3d",
		textures = {{wizard.texture}},
		visual_size = {x=1.1, y=1.1},
		makes_footstep_sound = true,
		sounds = {},
		walk_velocity = 1.5,
		walk_chance = 30,
		run_velocity = 3.5,
		jump = true,
		drops = wizard.drops,
		water_damage = 0,
		lava_damage = 4,
		light_damage = 0,
		follow = {},
		view_range = 20,
		fear_height = 0,
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

		on_activate = function(self, staticdata, dtime_s)
			-- Store wizard texture and armor info
			self.wizard_base_texture = wizard.texture
			self.wizard_armor_item = wizard.armor

			-- Initialize armor visual
			update_wizard_armor(self, wizard.texture, wizard.armor_item)
		end,

		on_punch = function(self, hitter, tflp, tool_capabilities, dir)
			-- Call the default on_punch behavior first
			if self.object then
				-- Update armor visual after taking damage
				minetest.after(0.1, function()
					if self and self.object then
						update_wizard_armor(self, wizard.texture, wizard.armor_item)
					end
				end)
			end
		end,

		do_custom = function(self, dtime)
			local success, err = pcall(function()
				-- Always try to cast spells first
				wizard.do_custom(self, dtime)

				-- Periodically update armor visual (every 2 seconds)
				if not self.armor_update_timer then
					self.armor_update_timer = 0
				end

				self.armor_update_timer = self.armor_update_timer + dtime
				if self.armor_update_timer >= 2 then
					self.armor_update_timer = 0
					update_wizard_armor(self, wizard.texture, wizard.armor_item)
				end

				-- Keep distance from target
				if self.attack then
					local pos = self.object:get_pos()
					local target_pos = self.attack:get_pos()

					if pos and target_pos then
						local distance = vector.distance(pos, target_pos)

						-- If too close, back away
						if distance < 6 then
							local direction = vector.direction(target_pos, pos)
							local velocity = vector.multiply(direction, 2)
							self.object:set_velocity(velocity)
						elseif distance > 18 then
							-- If too far, move closer slowly
							local direction = vector.direction(pos, target_pos)
							local velocity = vector.multiply(direction, 1)
							self.object:set_velocity(velocity)
						end
					end
				end
			end)
			if not success then
				minetest.log("warning", "[lualore] wizard do_custom error: " .. tostring(err))
			end
		end,

		on_die = function(self, pos)
			if self.object then
				-- Death particles
				minetest.add_particlespawner({
					amount = 100,
					time = 1,
					minpos = {x = pos.x - 0.5, y = pos.y, z = pos.z - 0.5},
					maxpos = {x = pos.x + 0.5, y = pos.y + 2, z = pos.z + 0.5},
					minvel = {x = -2, y = 0, z = -2},
					maxvel = {x = 2, y = 3, z = 2},
					minacc = {x = 0, y = -5, z = 0},
					maxacc = {x = 0, y = -5, z = 0},
					minexptime = 0.5,
					maxexptime = 2,
					minsize = 1,
					maxsize = 3,
					collisiondetection = false,
					texture = "default_cloud.png^[colorize:purple:200",
					glow = 14,
				})

				self.object:remove()
			end
			return true
		end,
	})

	-- Register spawn egg
	local display_name = wizard.name:gsub("^%l", string.upper)
	mobs:register_egg(mob_name,
		S(display_name),
		wizard.texture)
end

--------------------------------------------------------------------
-- WIZARD GROUP SPAWNING IN CAVE CASTLE
--------------------------------------------------------------------

local function get_castle_key(pos)
	return math.floor(pos.x/100) .. "," .. math.floor(pos.y/100) .. "," .. math.floor(pos.z/100)
end

local function find_cave_castle_center(minp, maxp)
	-- Look for dm_statue nodes (the prize/spawn point in the castle)
	local statue_positions = minetest.find_nodes_in_area(
		minp,
		maxp,
		{"caverealms:dm_statue"}
	)

	-- If we found a statue, spawn wizards around it
	if #statue_positions > 0 then
		-- Use the first statue as the spawn center
		local statue_pos = statue_positions[1]

		-- Spawn wizards slightly above the statue position
		local spawn_center = {
			x = statue_pos.x,
			y = statue_pos.y + 8,
			z = statue_pos.z + 3
		}

		minetest.log("action", "[lualore] Found dm_statue at " .. minetest.pos_to_string(statue_pos))
		return spawn_center
	end

	return nil
end

local function spawn_wizard_boss_group(center_pos)
	-- Spawn all 4 wizards around the center in a circle
	local wizards = {"redwizard", "whitewizard", "goldwizard", "blackwizard"}
	local radius = 6
	local spawned_count = 0

	for i, wizard_name in ipairs(wizards) do
		local angle = (i / #wizards) * math.pi * 2
		local spawn_pos = {
			x = center_pos.x + math.cos(angle) * radius,
			y = center_pos.y,
			z = center_pos.z + math.sin(angle) * radius
		}

		-- Try to find a valid spawn position
		local valid_pos = nil

		-- First, try the exact calculated position
		local node = minetest.get_node(spawn_pos)
		local node_above = minetest.get_node({x=spawn_pos.x, y=spawn_pos.y+1, z=spawn_pos.z})
		local node_below = minetest.get_node({x=spawn_pos.x, y=spawn_pos.y-1, z=spawn_pos.z})

		-- Check if we have air to spawn in and solid ground below
		if (node.name == "air" or node.name == "ignore") and
		   (node_above.name == "air" or node_above.name == "ignore") and
		   (node_below.name ~= "air" and node_below.name ~= "ignore") then
			valid_pos = spawn_pos
		else
			-- Try to find a better position nearby
			for dy = -2, 5 do
				local test_pos = {x=spawn_pos.x, y=spawn_pos.y+dy, z=spawn_pos.z}
				local test_node = minetest.get_node(test_pos)
				local test_above = minetest.get_node({x=test_pos.x, y=test_pos.y+1, z=test_pos.z})
				local test_below = minetest.get_node({x=test_pos.x, y=test_pos.y-1, z=test_pos.z})

				if (test_node.name == "air" or test_node.name == "ignore") and
				   (test_above.name == "air" or test_above.name == "ignore") and
				   (test_below.name ~= "air" and test_below.name ~= "ignore") then
					valid_pos = test_pos
					break
				end
			end
		end

		-- Spawn the wizard
		if valid_pos then
			local obj = minetest.add_entity(valid_pos, "lualore:" .. wizard_name)
			if obj then
				spawned_count = spawned_count + 1
				minetest.log("action", "[lualore] Spawned " .. wizard_name .. " at " .. minetest.pos_to_string(valid_pos))
			else
				minetest.log("warning", "[lualore] Failed to spawn " .. wizard_name .. " - entity creation failed")
			end
		else
			minetest.log("warning", "[lualore] Failed to spawn " .. wizard_name .. " - no valid position found")
		end
	end

	return spawned_count >= 3
end

-- Spawn wizards when cave castle is generated
minetest.register_on_generated(function(minp, maxp, blockseed)
	-- Only check caves
	if minp.y > 0 then return end

	minetest.after(10, function()
		local center = find_cave_castle_center(minp, maxp)
		if center then
			local castle_key = get_castle_key(center)

			if not spawned_wizard_groups[castle_key] then
				local success = spawn_wizard_boss_group(center)
				if success then
					spawned_wizard_groups[castle_key] = true
					minetest.log("action", "[lualore] Wizard boss group spawned in cave castle at " .. minetest.pos_to_string(center))
				end
			end
		end
	end)
end)

-- Chat command to manually spawn wizard boss group (for testing)
minetest.register_chatcommand("spawn_wizards", {
	params = "",
	description = "Spawn the wizard boss group near you",
	privs = {give = true},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return false, "Player not found" end

		local pos = player:get_pos()

		-- Log attempt
		minetest.log("action", "[lualore] " .. name .. " attempting to spawn wizard boss group at " .. minetest.pos_to_string(pos))

		local success = spawn_wizard_boss_group(pos)

		if success then
			return true, "Wizard boss group spawned! (At least 3 wizards)"
		else
			return false, "Failed to spawn wizard boss group - check debug.txt for details"
		end
	end,
})

-- Alternative simpler command that spawns individual wizards
minetest.register_chatcommand("spawn_wizard", {
	params = "<wizard_type>",
	description = "Spawn a single wizard (red, white, gold, or black)",
	privs = {give = true},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return false, "Player not found" end

		local wizard_map = {
			red = "redwizard",
			white = "whitewizard",
			gold = "goldwizard",
			black = "blackwizard"
		}

		local wizard_name = wizard_map[param:lower()]
		if not wizard_name then
			return false, "Invalid wizard type. Use: red, white, gold, or black"
		end

		local pos = player:get_pos()
		pos.y = pos.y + 1

		local obj = minetest.add_entity(pos, "lualore:" .. wizard_name)
		if obj then
			return true, wizard_name .. " spawned!"
		else
			return false, "Failed to spawn " .. wizard_name
		end
	end,
})

-- Spawn wizards at nearest statue
minetest.register_chatcommand("spawn_wizards_at_statue", {
	params = "<radius>",
	description = "Spawn wizard boss group at nearest statue (default radius: 100)",
	privs = {give = true},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return false, "Player not found" end

		local pos = player:get_pos()
		local radius = tonumber(param) or 100

		local statues = minetest.find_nodes_in_area(
			{x = pos.x - radius, y = pos.y - radius, z = pos.z - radius},
			{x = pos.x + radius, y = pos.y + radius, z = pos.z + radius},
			{"caverealms:dm_statue"}
		)

		if #statues > 0 then
			local statue_pos = statues[1]
			local spawn_pos = {x = statue_pos.x, y = statue_pos.y + 1, z = statue_pos.z}

			local success = spawn_wizard_boss_group(spawn_pos)
			if success then
				return true, "Wizard boss group spawned at statue! Location: " ..
				            minetest.pos_to_string(statue_pos)
			else
				return false, "Failed to spawn wizard boss group at statue"
			end
		else
			return false, "No statues found within " .. radius .. " nodes"
		end
	end,
})

print(S("[MOD] Lualore - Cave wizards loaded"))
