-- job_ranger.lua
-- ===================================================================
-- THE RANGER - walks the bounds
-- ===================================================================
-- He has no workstation. His job is the round itself: a circuit of the
-- village edge, which puts an armed villager out where trouble arrives
-- rather than leaving everyone milling about the square. The class is
-- already set up to fight (attacks_monsters), so this only has to move
-- him; mobs_redo does the rest when something shows up.
-- ===================================================================

local S = minetest.get_translator("lualore")

local ranger = lualore.jobs and lualore.jobs.classes and lualore.jobs.classes.ranger
if not ranger then
	minetest.log("warning", "[lualore] job_ranger: no ranger class to attach to")
	return
end

-- Marks the class as working by walking, so the framework gives him his
-- own doorstep as an anchor instead of hunting for a node to stand at.
ranger.patrol = true
ranger.work_reach = 2.5

local PATROL_RADIUS = 16
local PATROL_POINTS = 6

ranger.on_work = function(self, job_def, pos)
	local anchor = self.nv_house_pos
	if not anchor then
		return
	end

	-- Next point on the circuit. Keeping the index on the villager means
	-- he walks a round rather than wandering at random.
	local step = ((self.nv_patrol_step or 0) % PATROL_POINTS) + 1
	self.nv_patrol_step = step

	local angle = (step / PATROL_POINTS) * math.pi * 2
	local target = {
		x = anchor.x + math.floor(math.cos(angle) * PATROL_RADIUS + 0.5),
		y = anchor.y,
		z = anchor.z + math.floor(math.sin(angle) * PATROL_RADIUS + 0.5),
	}

	-- Only walk to somewhere that exists: the ground under a patrol point
	-- may be a cliff, a pond, or thin air at the village edge.
	for dy = 2, -3, -1 do
		local probe = {x = target.x, y = target.y + dy, z = target.z}
		local node = minetest.get_node(probe)
		local def = minetest.registered_nodes[node.name]
		if def and def.walkable and node.name ~= "ignore" then
			self.nv_work_spot = {x = probe.x, y = probe.y + 1, z = probe.z}
			return
		end
	end
	-- Nowhere to stand: skip this point, try the next one next time.
	self.nv_work_spot = nil
end

ranger.on_interact = function(self, player)
	minetest.chat_send_player(player:get_player_name(), S(
		"The ranger keeps her eyes on the treeline. \"Quiet so far. Keep it that way.\""))
	if lualore.mood and lualore.mood.on_interact then
		lualore.mood.on_interact(self, player)
	end
	return true
end

minetest.log("action", "[lualore] Ranger job loaded")
