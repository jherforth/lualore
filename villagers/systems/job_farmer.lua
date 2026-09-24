-- job_farmer.lua
-- ===================================================================
-- THE FARMER - works a real field you can also harvest yourself
-- ===================================================================
-- The farmer walks the rows of the plot his field stake describes,
-- harvesting what is ripe, sowing what has been cleared, and coaxing
-- along what is still growing. What he gathers goes into his stock, and
-- he will hand it over to a player who asks - once a day.
--
-- Growth itself is left to the farming mod's own ABM. He nudges a crop
-- on now and then, which is what makes him look busy, but a field keeps
-- working with no farmer anywhere near it. That is deliberate: the plot
-- is ordinary farmland, so you can harvest it, extend it, or ignore the
-- villager entirely.
--
-- This file only fills in the farmer's entry in lualore.jobs.classes.
-- The framework - claiming the stake, walking to it, the working day -
-- is villager_jobs.lua.
-- ===================================================================

local S = minetest.get_translator("lualore")

local farmer = lualore.jobs and lualore.jobs.classes and lualore.jobs.classes.farmer
if not farmer then
	minetest.log("warning", "[lualore] job_farmer: no farmer class to attach to")
	return
end

-- How often a tended crop is actually pushed a stage on. Harvesting is
-- never throttled; this only governs the "tending" nudge, so the field
-- mostly grows at the farming mod's own pace rather than the villager's.
local TEND_CHANCE = 3 -- one in three

-- Close enough to be working a particular plant, rather than the two
-- nodes that is right for standing at an anvil. Without this the farmer
-- reaches half the field from one spot and barely moves.
farmer.work_reach = 1.2

-- ------------------------------------------------------------------
-- Crop stages
-- ------------------------------------------------------------------
-- minetest_game's crops are foo_1 .. foo_N, and N differs per crop
-- (wheat has 8, cotton has 8, others vary), so the top stage is found
-- by asking the registry rather than assuming.
local top_stage = {}

local function crop_info(node_name)
	if not node_name then
		return nil
	end
	local base, digits = node_name:match("^(.*_)(%d+)$")
	if not base then
		return nil
	end
	-- Make sure this is actually a plant and not just a node whose name
	-- happens to end in a number.
	if minetest.get_item_group(node_name, "plant") == 0
			and minetest.get_item_group(node_name, "growing") == 0 then
		return nil
	end
	local max = top_stage[base]
	if not max then
		max = tonumber(digits)
		for stage = max + 1, 16 do
			if minetest.registered_nodes[base .. stage] then
				max = stage
			else
				break
			end
		end
		top_stage[base] = max
	end
	return base, tonumber(digits), max
end

local function drops_of(node_name)
	local ok, drops = pcall(minetest.get_node_drops, node_name, "")
	if ok and type(drops) == "table" then
		return drops
	end
	-- Fall back to the crop's own name without the stage suffix.
	local base = node_name:match("^(.*)_%d+$")
	return base and {base} or {}
end

local function harvest_particles(pos)
	minetest.add_particlespawner({
		amount = 12,
		time = 0.4,
		minpos = {x = pos.x - 0.3, y = pos.y, z = pos.z - 0.3},
		maxpos = {x = pos.x + 0.3, y = pos.y + 0.5, z = pos.z + 0.3},
		minvel = {x = -0.4, y = 0.6, z = -0.4},
		maxvel = {x = 0.4, y = 1.4, z = 0.4},
		minacc = {x = 0, y = -2, z = 0},
		maxacc = {x = 0, y = -2, z = 0},
		minexptime = 0.4,
		maxexptime = 0.9,
		minsize = 0.7,
		maxsize = 1.6,
		texture = "farming_wheat.png",
	})
end

-- ------------------------------------------------------------------
-- Reading the plot
-- ------------------------------------------------------------------
-- One pass over the field, sorting every column into what it needs.
local function survey(bounds)
	local ripe, growing, bare = {}, {}, {}
	for x = bounds.minx, bounds.maxx do
		for z = bounds.minz, bounds.maxz do
			local ground = minetest.get_node({x = x, y = bounds.y, z = z}).name
			if minetest.get_item_group(ground, "soil") > 0 then
				local above = {x = x, y = bounds.y + 1, z = z}
				local name = minetest.get_node(above).name
				local _, stage, max = crop_info(name)
				if stage then
					if stage >= max then
						ripe[#ripe + 1] = above
					else
						growing[#growing + 1] = above
					end
				elseif name == "air" then
					bare[#bare + 1] = above
				end
			end
		end
	end
	return ripe, growing, bare
end

-- ------------------------------------------------------------------
-- The work tick
-- ------------------------------------------------------------------
local function plot_of(self)
	local stake = self.nv_work_pos
	if not stake or not lualore.field_plot then
		return nil
	end
	if minetest.get_node(stake).name ~= "lualore:field_stake" then
		return nil
	end
	return lualore.field_plot.bounds(stake)
end

-- Do the job at the spot we walked to, then choose the next one. The
-- behaviour module walks us to nv_work_spot, so setting it here is what
-- sends the farmer up and down the rows.
farmer.on_work = function(self, job_def, pos)
	local bounds = plot_of(self)
	if not bounds then
		self.nv_work_spot = nil
		return
	end

	local spot = self.nv_work_spot
	if spot then
		local name = minetest.get_node(spot).name
		local base, stage, max = crop_info(name)
		if base and stage >= max then
			-- Ripe: gather it and put the field back to seed.
			for _, itemstr in ipairs(drops_of(name)) do
				local stack = ItemStack(itemstr)
				if not stack:is_empty() then
					lualore.jobs.add_stock(self, stack:get_name(), stack:get_count())
				end
			end
			minetest.set_node(spot, {name = base .. "1"})
			harvest_particles(spot)
			minetest.sound_play("default_grass_footstep",
				{pos = spot, gain = 0.4, max_hear_distance = 12}, true)
		elseif base then
			-- Still growing: a nudge, sometimes.
			if math.random(TEND_CHANCE) == 1 then
				minetest.set_node(spot, {name = base .. (stage + 1)})
			end
		elseif name == "air" and bounds.crop
				and minetest.registered_nodes[bounds.crop .. "_1"] then
			-- Cleared ground: sow it again. This is what makes a field
			-- the player has harvested fill itself back in.
			minetest.set_node(spot, {name = bounds.crop .. "_1"})
		end
	end

	-- Where next? Ripe crops first, then bare ground to sow, then
	-- whatever is still coming along.
	local ripe, growing, bare = survey(bounds)
	local pool = (#ripe > 0 and ripe) or (#bare > 0 and bare) or growing
	if #pool == 0 then
		self.nv_work_spot = nil
		return
	end
	local target = pool[math.random(#pool)]
	-- Stand on the soil, not inside the crop.
	self.nv_work_spot = {x = target.x, y = bounds.y + 1, z = target.z}
end

-- ------------------------------------------------------------------
-- Talking to the farmer
-- ------------------------------------------------------------------
farmer.on_interact = function(self, player)
	local player_name = player:get_player_name()
	local total = lualore.jobs.stock_count(self)

	if total <= 0 then
		minetest.chat_send_player(player_name,
			S("The farmer shrugs. \"Nothing gathered yet - come back when the field is ripe.\""))
		return true
	end

	if not lualore.jobs.can_share(self) then
		minetest.chat_send_player(player_name,
			S("The farmer pats his basket. \"You have had your share today.\""))
		return true
	end

	local given = lualore.jobs.give_stock(self, player)
	lualore.jobs.mark_shared(self)

	local parts = {}
	for _, entry in ipairs(given) do
		local def = minetest.registered_items[entry.name]
		local label = def and def.description and def.description:match("^([^\n]+)")
			or entry.name
		parts[#parts + 1] = entry.count .. " " .. label
	end

	if #parts == 0 then
		minetest.chat_send_player(player_name,
			S("The farmer shrugs. \"Nothing gathered yet - come back when the field is ripe.\""))
		return true
	end

	minetest.chat_send_player(player_name, S("The farmer hands you @1.",
		table.concat(parts, ", ")))

	if lualore.mood and lualore.mood.on_interact then
		lualore.mood.on_interact(self, player)
	end
	if lualore.standing and lualore.standing.earn then
		lualore.standing.earn(player, self, "job")
	end
	return true
end

minetest.log("action", "[lualore] Farmer job loaded")
