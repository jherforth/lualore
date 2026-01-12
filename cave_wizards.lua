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
		name = "redWizard",
		texture = "redWizard.png",
		do_custom = lualore.wizard_magic.red_do_custom,
		drops = {
			{name = "default:mese_crystal", chance = 1, min = 2, max = 5},
			{name = "default:diamond", chance = 1, min = 1, max = 3}
		}
	},
	{
		name = "whiteWizard",
		texture = "whiteWizard.png",
		do_custom = lualore.wizard_magic.white_do_custom,
		drops = {
			{name = "default:mese_crystal", chance = 1, min = 2, max = 5},
			{name = "default:diamond", chance = 1, min = 1, max = 3}
		}
	},
	{
		name = "goldWizard",
		texture = "goldenWizard.png",
		do_custom = lualore.wizard_magic.gold_do_custom,
		drops = {
			{name = "default:mese_crystal", chance = 1, min = 2, max = 5},
			{name = "default:diamond", chance = 1, min = 1, max = 3},
			{name = "default:gold_lump", chance = 1, min = 3, max = 7}
		}
	},
	{
		name = "blackWizard",
		texture = "blackWizard.png",
		do_custom = lualore.wizard_magic.black_do_custom,
		drops = {
			{name = "default:mese_crystal", chance = 1, min = 2, max = 5},
			{name = "default:diamond", chance = 1, min = 1, max = 3},
			{name = "default:obsidian", chance = 1, min = 2, max = 5}
		}
	}
}

-- Register each wizard as a mob
for _, wizard in ipairs(wizard_types) do
	local mob_name = "lualore:" .. wizard.name

	mobs:register_mob(mob_name, {
		type = "monster",
		passive = false,
		damage = 8,
		attack_type = "dogfight",
		attacks_monsters = false,
		attack_npcs = true,
		attack_players = true,
		owner_loyal = false,
		pathfinding = true,
		hp_min = 100,
		hp_max = 150,
		armor = 150,
		reach = 2,
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

		do_custom = function(self, dtime)
			local success, err = pcall(function()
				wizard.do_custom(self, dtime)
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
	mobs:register_egg(mob_name,
		S(wizard.name:gsub("^%l", string.upper)),
		wizard.texture)
end

--------------------------------------------------------------------
-- WIZARD GROUP SPAWNING IN CAVE CASTLE
--------------------------------------------------------------------

local function get_castle_key(pos)
	return math.floor(pos.x/100) .. "," .. math.floor(pos.y/100) .. "," .. math.floor(pos.z/100)
end

local function find_cave_castle_center(minp, maxp)
	-- Look for castle-specific blocks (obsidian, unique structures)
	local castle_markers = minetest.find_nodes_in_area(
		minp,
		maxp,
		{"default:obsidian"}
	)

	-- Need significant obsidian presence to indicate a castle
	if #castle_markers > 50 then
		-- Find the center of the obsidian cluster
		local center = {x=0, y=0, z=0}
		for _, pos in ipairs(castle_markers) do
			center.x = center.x + pos.x
			center.y = center.y + pos.y
			center.z = center.z + pos.z
		end
		center.x = math.floor(center.x / #castle_markers)
		center.y = math.floor(center.y / #castle_markers)
		center.z = math.floor(center.z / #castle_markers)

		return center
	end

	return nil
end

local function spawn_wizard_boss_group(center_pos)
	-- Spawn all 4 wizards around the center in a circle
	local wizards = {"redWizard", "whiteWizard", "goldWizard", "blackWizard"}
	local radius = 8
	local spawned_count = 0

	for i, wizard_name in ipairs(wizards) do
		local angle = (i / #wizards) * math.pi * 2
		local spawn_pos = {
			x = center_pos.x + math.cos(angle) * radius,
			y = center_pos.y + 1,
			z = center_pos.z + math.sin(angle) * radius
		}

		-- Try to find solid ground nearby
		local ground_pos = minetest.find_node_near(spawn_pos, 5, {"group:stone", "default:obsidian", "group:cracky"})
		if ground_pos then
			ground_pos.y = ground_pos.y + 1
			local obj = minetest.add_entity(ground_pos, "lualore:" .. wizard_name)
			if obj then
				spawned_count = spawned_count + 1
				minetest.log("action", "[lualore] Spawned " .. wizard_name .. " at " .. minetest.pos_to_string(ground_pos))
			end
		end
	end

	return spawned_count == 4
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
	privs = {server = true},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return false, "Player not found" end

		local pos = player:get_pos()
		local success = spawn_wizard_boss_group(pos)

		if success then
			return true, "Wizard boss group spawned!"
		else
			return false, "Failed to spawn wizard boss group"
		end
	end,
})

print(S("[MOD] Lualore - Cave wizards loaded"))
