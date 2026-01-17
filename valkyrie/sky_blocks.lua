local S = minetest.get_translator("lualore")

lualore.sky_wings = {}

local active_wings = {}

local wing_types = {
	green = {
		description = "Green Valkyrie Wings",
		texture = "green_valkyrie_wings.png",
		max_uses = 600,  -- 30 seconds at 20 ticks/sec
		speed_mult = 1.1,
		color = "#00FF00",
		lift_power = 0.8
	},
	blue = {
		description = "Blue Valkyrie Wings",
		texture = "blue_valkyrie_wings.png",
		max_uses = 900,  -- 45 seconds at 20 ticks/sec
		speed_mult = 1.2,
		color = "#00FFFF",
		lift_power = 1.0
	},
	violet = {
		description = "Violet Valkyrie Wings",
		texture = "violet_valkyrie_wings.png",
		max_uses = 900,  -- 45 seconds at 20 ticks/sec
		speed_mult = 1.35,
		color = "#9000FF",
		lift_power = 1.2
	},
	gold = {
		description = "Gold Valkyrie Wings",
		texture = "gold_valkyrie_wings.png",
		max_uses = 1200,  -- 60 seconds at 20 ticks/sec
		speed_mult = 1.5,
		color = "#FFD700",
		lift_power = 1.5
	}
}

local function attach_wings(parent_obj, wing_type)
    if not parent_obj then return end

    local wing_data = wing_types[wing_type]
    if not wing_data then return end

    local pos = parent_obj:get_pos()
    local wing_entity = minetest.add_entity(pos, "lualore:wing_visual")

    if wing_entity then
        wing_entity:set_attach(
            parent_obj,
            "",  -- Attach to root bone
            {x=0, y=10, z=5},  -- Position: up a bit, behind body (adjusted for 180 rotation)
            {x=0, y=180, z=0}  -- Rotation: vertical wings aligned with player facing forward
        )

        wing_entity:get_luaentity().wing_type = wing_type
        wing_entity:set_properties({
            textures = {wing_data.texture}
        })

        return wing_entity
    end
end

local function remove_wings(player)
	if not player or not player:is_player() then return end

	local pos = player:get_pos()
	local objects = minetest.get_objects_inside_radius(pos, 2)

	for _, obj in ipairs(objects) do
		local ent = obj:get_luaentity()
		if ent and ent.name == "lualore:wing_visual" then
			obj:remove()
		end
	end
end

local function activate_wings(player, wing_type, itemstack, index)
	if not player or not player:is_player() then return false end

	local player_name = player:get_player_name()
	local wing_data = wing_types[wing_type]

	if not wing_data then return false end

	if active_wings[player_name] then
		minetest.chat_send_player(player_name, S("Wings already active!"))
		return false
	end

	local wing_entity = attach_wings(player, wing_type)

	active_wings[player_name] = {
		wing_type = wing_type,
		wing_entity = wing_entity,
		was_flying = false,
		original_physics = player:get_physics_override(),
		wield_index = index
	}

	-- Enable flight physics
	player:set_physics_override({
		gravity = 0.3,  -- Reduced gravity for easier flight
		speed = 1.2     -- Slightly faster movement
	})

	-- Set initial standing pose with wings (facing forward)
	player:set_bone_override("Body", {position = {x=0, y=6.3, z=0}, rotation = {x=0, y=180, z=0}})
	player:set_bone_override("Head", {position = {x=0, y=6.3, z=0}, rotation = {x=0, y=0, z=0}})

	minetest.chat_send_player(player_name, S("Wings equipped! Use jump to fly up, sneak to descend."))

	return true
end

local function deactivate_wings(player, player_name, broken)
	if not active_wings[player_name] then return end

	local wing_data = active_wings[player_name]

	if player and player:is_player() then
		remove_wings(player)

		-- Restore original physics
		if wing_data.original_physics then
			player:set_physics_override(wing_data.original_physics)
		else
			-- Fallback to default physics
			player:set_physics_override({
				gravity = 1,
				speed = 1
			})
		end

		-- Reset all bone overrides to default
		player:set_bone_override("Body", {position = {x=0, y=6.3, z=0}, rotation = {x=0, y=0, z=0}})
		player:set_bone_override("Head", {position = {x=0, y=6.3, z=0}, rotation = {x=0, y=0, z=0}})
		player:set_bone_override("Arm_Left", {position = {x=-3, y=6.3, z=1}, rotation = {x=0, y=0, z=0}})
		player:set_bone_override("Arm_Right", {position = {x=3, y=6.3, z=1}, rotation = {x=0, y=0, z=0}})

		-- Ensure bones are fully reset with a slight delay
		minetest.after(0.1, function()
			if player and player:is_player() then
				player:set_bone_override("Body", {position = {x=0, y=6.3, z=0}, rotation = {x=0, y=0, z=0}})
				player:set_bone_override("Head", {position = {x=0, y=6.3, z=0}, rotation = {x=0, y=0, z=0}})
				player:set_bone_override("Arm_Left", {position = {x=-3, y=6.3, z=1}, rotation = {x=0, y=0, z=0}})
				player:set_bone_override("Arm_Right", {position = {x=3, y=6.3, z=1}, rotation = {x=0, y=0, z=0}})
			end
		end)

		if broken then
			-- Remove the broken wings from inventory
			local inv = player:get_inventory()
			if inv and wing_data.wield_index then
				local list = inv:get_list("main")
				if list and list[wing_data.wield_index] then
					list[wing_data.wield_index] = ItemStack("")
					inv:set_list("main", list)
				end
			end
			minetest.chat_send_player(player_name, S("Your wings have broken!"))
		else
			minetest.chat_send_player(player_name, S("Wings deactivated!"))
		end
	end

	active_wings[player_name] = nil
end

for wing_type, wing_data in pairs(wing_types) do
	minetest.register_tool("lualore:" .. wing_type .. "_wings", {
		description = S(wing_data.description),
		inventory_image = wing_data.texture,
		stack_max = 1,
		on_use = function(itemstack, user, pointed_thing)
			if not user or not user:is_player() then return itemstack end

			local player_name = user:get_player_name()

			-- If wings are active, deactivate them
			if active_wings[player_name] then
				deactivate_wings(user, player_name, false)
				return itemstack
			end

			-- Find the wielded item index
			local inv = user:get_inventory()
			local wield_index = user:get_wield_index()

			-- Activate wings
			if activate_wings(user, wing_type, itemstack, wield_index) then
				-- Don't consume or modify the itemstack here - wear is added during flight
			end

			return itemstack
		end
	})
end

minetest.register_entity("lualore:wing_visual", {
    initial_properties = {
        physical = false,
        collide_with_objects = false,
        pointable = false,
        visual = "upright_sprite",  -- Change to upright_sprite for basic PNG display
        textures = {"green_valkyrie_wings.png"},  -- Default; overridden later
        visual_size = {x=2, y=2},  -- Scale to fit (tweak for your PNG size; e.g., wider for wings)
        static_save = false,
    },

    wing_type = "green",

    on_activate = function(self, staticdata)
        self.object:set_armor_groups({immortal = 1})
    end,

    on_step = function(self, dtime)
        local parent = self.object:get_attach()
        if not parent then
            self.object:remove()
            return
        end
    end,
})

minetest.register_globalstep(function(dtime)
	for player_name, wing_data in pairs(active_wings) do
		local player = minetest.get_player_by_name(player_name)

		if not player then
			active_wings[player_name] = nil
		else
			local wing_info = wing_types[wing_data.wing_type]

			-- Add wear to wings every tick
			local inv = player:get_inventory()
			if inv and wing_data.wield_index then
				local list = inv:get_list("main")
				if list and list[wing_data.wield_index] then
					local itemstack = list[wing_data.wield_index]
					if itemstack and itemstack:get_name() == "lualore:" .. wing_data.wing_type .. "_wings" then
						-- Add wear based on max_uses
						local wear_per_use = 65535 / wing_info.max_uses
						local new_wear = itemstack:get_wear() + wear_per_use

						if new_wear >= 65535 then
							-- Wings are broken
							deactivate_wings(player, player_name, true)
						else
							itemstack:set_wear(new_wear)
							list[wing_data.wield_index] = itemstack
							inv:set_list("main", list)

							-- Warn when low durability
							local durability_percent = (1 - (new_wear / 65535)) * 100
							if durability_percent <= 10 and durability_percent > 9 then
								minetest.chat_send_player(player_name, S("Wings are almost broken!"))
							end
						end
					else
						-- Wings item was removed from slot
						deactivate_wings(player, player_name, false)
					end
				else
					deactivate_wings(player, player_name, false)
				end
			end

			-- Only continue flight mechanics if wings are still active
			if active_wings[player_name] then
				local vel = player:get_velocity()
				local ctrl = player:get_player_control()
				local player_pos = player:get_pos()

				-- Always allow flight controls
				if ctrl.jump then
					player:add_velocity({x=0, y=wing_info.lift_power, z=0})
				elseif ctrl.sneak then
					if vel.y > -5 then
						player:add_velocity({x=0, y=-0.8, z=0})
					end
				end

				local is_moving = vel and (math.abs(vel.x) > 0.3 or math.abs(vel.z) > 0.3 or math.abs(vel.y) > 0.5)

				if is_moving then
					if not wing_data.was_flying then
						wing_data.was_flying = true
					end

					player:set_bone_override("Body", {position = {x=0, y=6.3, z=0}, rotation = {x=-90, y=180, z=0}})
					player:set_bone_override("Head", {position = {x=0, y=6.3, z=0}, rotation = {x=90, y=180, z=0}})

					if not ctrl.jump and not ctrl.sneak then
						if vel.y < -1 then
							local drag = vector.multiply(vel, {x=0, y=0.3, z=0})
							player:add_velocity(drag)
						end
					end

					local look_dir = player:get_look_dir()
					if ctrl.up or ctrl.down or ctrl.left or ctrl.right then
						local move_dir = vector.multiply(look_dir, wing_info.speed_mult * 0.5)
						move_dir.y = 0
						player:add_velocity(move_dir)
					end

					minetest.add_particlespawner({
						amount = 3,
						time = 0.1,
						minpos = vector.subtract(player_pos, {x=0.5, y=0, z=0.5}),
						maxpos = vector.add(player_pos, {x=0.5, y=0.5, z=0.5}),
						minvel = {x=-1, y=-1, z=-1},
						maxvel = {x=1, y=0, z=1},
						minacc = {x=0, y=-0.3, z=0},
						maxacc = {x=0, y=-0.3, z=0},
						minexptime = 0.3,
						maxexptime = 0.8,
						minsize = 1.5,
						maxsize = 2.5,
						texture = "lualore_particle_star.png^[colorize:" .. wing_info.color .. ":200",
						glow = 10
					})
				else
					if wing_data.was_flying then
						player:set_bone_override("Body", {position = {x=0, y=6.3, z=0}, rotation = {x=0, y=180, z=0}})
						player:set_bone_override("Head", {position = {x=0, y=6.3, z=0}, rotation = {x=0, y=0, z=0}})
						player:set_bone_override("Arm_Left", {position = {x=-3, y=6.3, z=1}, rotation = {x=0, y=0, z=0}})
						player:set_bone_override("Arm_Right", {position = {x=3, y=6.3, z=1}, rotation = {x=0, y=0, z=0}})
						wing_data.was_flying = false
					end
				end
			end
		end
	end
end)

minetest.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
	deactivate_wings(player, player_name, false)
end)

minetest.register_on_dieplayer(function(player)
	local player_name = player:get_player_name()
	deactivate_wings(player, player_name, false)
end)

minetest.log("action", "[lualore] Sky wings system loaded")
