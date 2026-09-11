-- castle_village.lua
-- An abandoned village around each underground wizard castle.
--
-- The cave ground around the castle is sculpted with a single VoxelManip
-- pass (flattening the area to the castle floor level, terracing lower
-- ground up, foundationing chasms, carving room out of rock walls while
-- keeping some natural pillars and the cavern ceiling), and 3-16 ruined
-- houses are then placed procedurally from nodes: crumbling mossy walls,
-- doorways facing the castle, broken windows, partial roofs, embedded
-- glow-obsidian lamps and loot chests.
--
-- Settings: lualore_cave_village, _village_radius, _village_houses,
-- _village_chests. Command: /build_castle_village [radius].

lualore = lualore or {}

local S = minetest.get_translator("lualore")

-- ------------------------------------------------------------------
-- Configuration
-- ------------------------------------------------------------------
local function setting_number(key, default, lo, hi)
	local value = tonumber(minetest.settings:get(key))
	if value == nil then
		value = default
	end
	return math.max(lo, math.min(hi, value))
end

local ENABLED  = minetest.settings:get_bool("lualore_cave_village", true)
local RADIUS   = math.floor(setting_number("lualore_cave_village_radius", 46, 26, 80))
local HOUSES   = math.floor(setting_number("lualore_cave_village_houses", 9, 3, 16))
local CHESTS   = minetest.settings:get_bool("lualore_cave_village_chests", true)

-- ------------------------------------------------------------------
-- Materials (caverealms palette with safe fallbacks)
-- ------------------------------------------------------------------
local function first_registered(list, fallback)
	for _, name in ipairs(list) do
		if minetest.registered_nodes[name] then
			return name
		end
	end
	return fallback
end

local M = {
	cobble     = "default:cobble",
	mossy      = "default:mossycobble",
	stonebrick = "default:stonebrick",
	stone      = "default:stone",
	gravel     = "default:gravel",
	wood       = "default:wood",
	moss   = first_registered({ "caverealms:stone_with_moss" }, "default:mossycobble"),
	lichen = first_registered({ "caverealms:stone_with_lichen" }, "default:cobble"),
	algae  = first_registered({ "caverealms:stone_with_algae" }, "default:mossycobble"),
	glow   = first_registered({ "caverealms:glow_obsidian_brick",
		"caverealms:glow_obsidian" }, "default:mese_lamp"),
	glow2  = first_registered({ "caverealms:glow_obsidian_brick_2",
		"caverealms:glow_obsidian_2" }, nil),
	glass = first_registered({ "default:glass" }, nil),
	salt  = first_registered({ "caverealms:stone_with_salt" }, nil),
}

local PLANTS = {}
for _, name in ipairs({ "caverealms:fungus", "caverealms:mycena",
		"caverealms:mushroom_sapling" }) do
	if minetest.registered_nodes[name] then
		PLANTS[#PLANTS + 1] = name
	end
end

-- content id cache (filled once at load)
local CID = { air = minetest.get_content_id("air"),
	ignore = minetest.get_content_id("ignore") }
CID.water = minetest.get_content_id("default:water_source")
for key, name in pairs(M) do
	CID[key] = name and minetest.get_content_id(name) or nil
end
for i, name in ipairs(PLANTS) do
	CID["plant" .. i] = minetest.get_content_id(name)
end

-- ------------------------------------------------------------------
-- Deterministic helpers
-- ------------------------------------------------------------------
local function coord_hash(x, z)
	return (x * 73856093 + z * 19349663) % 2147483647
end

local function seed_for(center)
	local h = coord_hash(center.x, center.z)
	h = (h + math.abs(center.y) * 15485863) % 2147483647
	return h
end

local LOOT = {
	{ name = "default:torch",       chance = 0.55, min = 2, max = 6 },
	{ name = "default:coal_lump",   chance = 0.70, min = 2, max = 8 },
	{ name = "default:flint",       chance = 0.50, min = 1, max = 4 },
	{ name = "default:iron_lump",   chance = 0.50, min = 1, max = 3 },
	{ name = "default:copper_lump", chance = 0.40, min = 1, max = 3 },
	{ name = "default:steel_ingot", chance = 0.30, min = 1, max = 2 },
	{ name = "default:gold_lump",   chance = 0.18, min = 1, max = 2 },
	{ name = "default:mese_crystal", chance = 0.12, min = 1, max = 2 },
	{ name = "default:diamond",     chance = 0.08, min = 1, max = 1 },
}

-- ------------------------------------------------------------------
-- The builder
-- ------------------------------------------------------------------
local function build_castle_village(center, rot, opts)
	opts = opts or {}
	if not ENABLED and not opts.force then
		return false, "disabled"
	end
	local cc = lualore.cave_castle
	if not cc or not cc.get_geometry or not cc.castle_bounds then
		return false, "cave castle API missing"
	end

	local g = cc.get_geometry()
	local bounds = cc.castle_bounds(center, rot)
	local floor_y = center.y + g.plaza -- walkable level around the castle
	local cx, cz = center.x, center.z
	local rng = PcgRandom(seed_for(center))

	local R = RADIUS
	local half_ext = math.max(bounds.ext_x, bounds.ext_z) / 2
	local ex_minx, ex_maxx = bounds.minx - 2, bounds.maxx + 2
	local ex_minz, ex_maxz = bounds.minz - 2, bounds.maxz + 2

	local Y_LO, Y_HI = floor_y - 8, floor_y + 12
	local minp = { x = cx - R, y = Y_LO, z = cz - R }
	local maxp = { x = cx + R, y = Y_HI, z = cz + R }

	local vm = minetest.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local data = vm:get_data()
	local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })

	local function set_cell(x, y, z, key)
		local pos = { x = x, y = y, z = z }
		if key and CID[key] and area:containsp(pos) then
			data[area:indexp(pos)] = CID[key]
		end
	end

	local function fill_mat(x, z)
		local n = coord_hash(x, z) % 100
		if n < 50 then return "mossy"
		elseif n < 85 then return "cobble"
		else return "stone" end
	end

	local function ground_mat(x, z, rr)
		local n = coord_hash(x, z) % 100
		if rr >= half_ext + 1 and rr <= half_ext + 5 then
			-- worn ring-path around the castle
			return (n < 88) and "cobble" or "mossy"
		end
		if n < 42 then return "cobble"
		elseif n < 62 then return "mossy"
		elseif n < 76 then return "moss"
		elseif n < 86 then return "lichen"
		elseif n < 94 then return "gravel"
		else return "algae" end
	end

	-- ground_ok: columns where a building may stand (walkable ground at
	-- floor_y, inside the village interior)
	local width = 2 * R + 1
	local ground_ok = {}
	local function gkey(x, z)
		return (x - cx + R) + (z - cz + R) * width
	end

	-- ------------------------------------------------------------------
	-- Phase 1: sculpt the cave ground
	-- ------------------------------------------------------------------
	local function sculpt_column(x, z, rr)
		if not area:containsp({ x = x, y = floor_y, z = z }) then
			return -- map edge: read area is smaller than requested
		end
		local interior = rr <= R - 6
		local clear_h = interior and 7 or 2

		-- topmost non-air node in the band (liquids count as ground and get
		-- covered / cleared over below)
		local solid
		for y = Y_HI, Y_LO, -1 do
			if not area:containsp({ x = x, y = y, z = z }) then
				break
			end
			local id = data[area:index(x, y, z)]
			if id ~= CID.air and id ~= CID.ignore then
				solid = y
				break
			end
		end

		if not interior then
			-- blend zone: only tidy ground already near village level
			if solid and solid >= floor_y - 1 and solid <= floor_y + 3 then
				for y = solid + 1, floor_y - 1 do set_cell(x, y, z, fill_mat(x, z)) end
				set_cell(x, floor_y, z, ground_mat(x, z, rr))
				set_cell(x, floor_y + 1, z, "air")
				set_cell(x, floor_y + 2, z, "air")
			end
			return
		end

		if solid and solid > floor_y + 3 then
			-- rock rising through the village: keep a few as natural pillars
			if coord_hash(x, z) % 23 == 0 then
				return
			end
			for y = floor_y + 1, floor_y + clear_h do set_cell(x, y, z, "air") end
			set_cell(x, floor_y, z, ground_mat(x, z, rr))
			ground_ok[gkey(x, z)] = true
		elseif solid and solid >= floor_y - 1 then
			-- ground at (or just below) village level
			for y = solid + 1, floor_y - 1 do set_cell(x, y, z, fill_mat(x, z)) end
			set_cell(x, floor_y, z, ground_mat(x, z, rr))
			for y = floor_y + 1, floor_y + clear_h do set_cell(x, y, z, "air") end
			ground_ok[gkey(x, z)] = true
		elseif solid then
			-- lower terrain: terrace it up to village level
			for y = solid + 1, floor_y - 1 do set_cell(x, y, z, fill_mat(x, z)) end
			set_cell(x, floor_y, z, ground_mat(x, z, rr))
			for y = floor_y + 1, floor_y + clear_h do set_cell(x, y, z, "air") end
			ground_ok[gkey(x, z)] = true
		else
			-- nothing solid in the band: foundation pillar over void / lava
			for y = floor_y - 7, floor_y do
				set_cell(x, y, z, fill_mat(x, z))
			end
			set_cell(x, floor_y, z, ground_mat(x, z, rr))
			for y = floor_y + 1, floor_y + clear_h do set_cell(x, y, z, "air") end
			ground_ok[gkey(x, z)] = true
		end
	end

	for x = cx - R, cx + R do
		for z = cz - R, cz + R do
			if not (x >= ex_minx and x <= ex_maxx and z >= ex_minz and z <= ex_maxz) then
				local rr = math.max(math.abs(x - cx), math.abs(z - cz))
				sculpt_column(x, z, rr)
			end
		end
	end

	-- ------------------------------------------------------------------
	-- Phase 2: buildings
	-- ------------------------------------------------------------------
	local chest_places = {}
	local occupied = { { ex_minx, ex_maxx, ex_minz, ex_maxz } }

	local function box_overlaps(a, b)
		return a[1] <= b[2] and a[2] >= b[1] and a[3] <= b[4] and a[4] >= b[3]
	end

	local function wall_mat()
		local n = rng:next(1, 100)
		if n <= 45 then return "stonebrick"
		elseif n <= 70 then return "moss"
		elseif n <= 85 then return "lichen"
		elseif n <= 95 then return "stone"
		else return "algae" end
	end

	local function rubble_mat()
		local n = rng:next(1, 100)
		if n <= 40 then return "cobble"
		elseif n <= 70 then return "mossy"
		else return "gravel" end
	end

	local function scatter_rubble(around_x0, around_x1, around_z0, around_z1, count)
		for _ = 1, count do
			local x = rng:next(around_x0, around_x1)
			local z = rng:next(around_z0, around_z1)
			if ground_ok[gkey(x, z)] then
				local n = rng:next(1, 100)
				if n <= 70 then
					set_cell(x, floor_y + 1, z, rubble_mat())
				elseif n <= 90 and #PLANTS > 0 then
					set_cell(x, floor_y + 1, z, "plant" .. rng:next(1, #PLANTS))
				elseif M.salt then
					set_cell(x, floor_y + 1, z, "salt")
				end
			end
		end
	end

	local function build_house(x0, x1, z0, z1, pcx, pcz)
		local w, d = x1 - x0 + 1, z1 - z0 + 1

		-- floor: worn planks with mossy patches
		for x = x0 + 1, x1 - 1 do
			for z = z0 + 1, z1 - 1 do
				local n = rng:next(1, 100)
				if n <= 55 then set_cell(x, floor_y, z, "wood")
				elseif n <= 65 then set_cell(x, floor_y, z, "mossy") end
			end
		end

		-- doorway faces the castle
		local door_cell
		if math.abs(cx - pcx) >= math.abs(cz - pcz) then
			door_cell = { x = (cx < pcx) and x0 or x1, z = pcz }
		else
			door_cell = { x = pcx, z = (cz < pcz) and z0 or z1 }
		end
		-- keep the door off the corners
		door_cell.x = math.max(x0 + 1, math.min(x1 - 1, door_cell.x))
		door_cell.z = math.max(z0 + 1, math.min(z1 - 1, door_cell.z))

		-- an extra collapsed gap in a random wall (not the door)
		local gap_cell
		do
			local side = rng:next(1, 4)
			if side == 1 then gap_cell = { x = rng:next(x0 + 1, x1 - 1), z = z0 }
			elseif side == 2 then gap_cell = { x = rng:next(x0 + 1, x1 - 1), z = z1 }
			elseif side == 3 then gap_cell = { x = x0, z = rng:next(z0 + 1, z1 - 1) }
			else gap_cell = { x = x1, z = rng:next(z0 + 1, z1 - 1) } end
		end

		local function is_cell(cell, x, z)
			return cell and cell.x == x and cell.z == z
		end

		local wall_h = rng:next(2, 4)
		local perimeter = {}
		for x = x0, x1 do
			perimeter[#perimeter + 1] = { x, z0 }
			perimeter[#perimeter + 1] = { x, z1 }
		end
		for z = z0 + 1, z1 - 1 do
			perimeter[#perimeter + 1] = { x0, z }
			perimeter[#perimeter + 1] = { x1, z }
		end

		for _, cell in ipairs(perimeter) do
			local x, z = cell[1], cell[2]
			local h = math.max(1, math.min(5, wall_h + rng:next(-1, 1)))
			for y = 1, h do
				local door = (y <= 2) and is_cell(door_cell, x, z)
				local gap = (y <= 2) and is_cell(gap_cell, x, z)
				if door or gap then
					set_cell(x, floor_y + y, z, "air")
				else
					local n = rng:next(1, 100)
					if y == h and n <= 22 then
						-- crumbled top
					elseif n <= 6 then
						-- small hole
					elseif y == 2 and n <= 18 then
						-- window (some still have glass)
						if M.glass and rng:next(1, 2) == 1 then
							set_cell(x, floor_y + y, z, "glass")
						else
							set_cell(x, floor_y + y, z, "air")
						end
					else
						set_cell(x, floor_y + y, z, wall_mat())
					end
				end
			end
		end

		-- partial wooden roof at the top of the walls
		local roof_y = floor_y + wall_h + 2
		for x = x0 + 1, x1 - 1 do
			for z = z0 + 1, z1 - 1 do
				local n = rng:next(1, 100)
				if n <= 55 then set_cell(x, roof_y, z, "wood")
				elseif n <= 65 then set_cell(x, roof_y, z, "mossy") end
			end
		end

		-- an embedded glow-obsidian lamp in one wall
		if rng:next(1, 100) <= 60 then
			local cell = perimeter[rng:next(1, #perimeter)]
			local vi = area:index(cell[1], floor_y + 2, cell[2])
			local id = data[vi]
			if id ~= CID.air and (not CID.glass or id ~= CID.glass) then
				data[vi] = CID.glow
			end
		end

		-- loot chest
		if CHESTS and rng:next(1, 100) <= 60 then
			chest_places[#chest_places + 1] = {
				x = rng:next(x0 + 1, x1 - 1),
				y = floor_y + 1,
				z = rng:next(z0 + 1, z1 - 1),
			}
		end

		scatter_rubble(x0, x1, z0, z1, 3)
	end

	local function build_ruin(x0, x1, z0, z1)
		-- two broken perpendicular wall runs
		for x = x0, x1 do
			local h = rng:next(1, 3)
			for y = 1, h do
				if rng:next(1, 100) <= 85 then
					set_cell(x, floor_y + y, z0, wall_mat())
				end
			end
		end
		for z = z0 + 1, z1 do
			local h = rng:next(0, 2)
			for y = 1, h do
				if rng:next(1, 100) <= 80 then
					set_cell(x0, floor_y + y, z, wall_mat())
				end
			end
		end
		if CHESTS and rng:next(1, 100) <= 30 then
			chest_places[#chest_places + 1] = {
				x = rng:next(x0 + 1, x1 - 1),
				y = floor_y + 1,
				z = rng:next(z0 + 1, z1 - 1),
			}
		end
		scatter_rubble(x0, x1, z0, z1, 6)
	end

	-- plot placement: a ring of buildings between the castle and the edge
	local ring_lo = math.floor(half_ext) + 5
	local ring_hi = R - 8
	local placed = 0
	if ring_hi > ring_lo + 3 then
		for _ = 1, HOUSES * 12 do
			if placed >= HOUSES then
				break
			end
			local w = rng:next(5, 8)
			local d = rng:next(4, 7)
			local angle = rng:next(0, 359) / 360 * (2 * math.pi)
			local rr = rng:next(ring_lo + math.floor(math.max(w, d) / 2), ring_hi)
			local pcx = cx + math.floor(math.cos(angle) * rr + 0.5)
			local pcz = cz + math.floor(math.sin(angle) * rr + 0.5)
			local x0 = pcx - math.floor((w - 1) / 2)
			local x1 = pcx + math.floor(w / 2)
			local z0 = pcz - math.floor((d - 1) / 2)
			local z1 = pcz + math.floor(d / 2)

			-- stay inside the sculpted interior
			if x0 >= cx - (R - 8) and x1 <= cx + (R - 8)
					and z0 >= cz - (R - 8) and z1 <= cz + (R - 8) then
				-- whole plot (with margin) must have solid ground
				local ok = true
				for x = x0 - 1, x1 + 1 do
					for z = z0 - 1, z1 + 1 do
						if not ground_ok[gkey(x, z)] then
							ok = false
						end
					end
				end
				local box = { x0 - 2, x1 + 2, z0 - 2, z1 + 2 }
				if ok then
					for _, other in ipairs(occupied) do
						if box_overlaps(box, other) then
							ok = false
							break
						end
					end
				end
				if ok then
					occupied[#occupied + 1] = box
					if rng:next(1, 100) <= 30 then
						build_ruin(x0, x1, z0, z1)
					else
						build_house(x0, x1, z0, z1, pcx, pcz)
					end
					placed = placed + 1
				end
			end
		end
	end

	-- a broken well (once, if a spot can be found)
	if rng:next(1, 100) <= 80 then
		for _ = 1, 8 do
			local angle = rng:next(0, 359) / 360 * (2 * math.pi)
			local rr = rng:next(ring_lo, ring_hi)
			local wx = cx + math.floor(math.cos(angle) * rr + 0.5)
			local wz = cz + math.floor(math.sin(angle) * rr + 0.5)
			local ok = true
			for x = wx - 1, wx + 1 do
				for z = wz - 1, wz + 1 do
					if not ground_ok[gkey(x, z)] then
						ok = false
					end
				end
			end
			if ok then
				for _, other in ipairs(occupied) do
					if not (wx + 1 < other[1] or wx - 1 > other[2]
							or wz + 1 < other[3] or wz - 1 > other[4]) then
						ok = false
						break
					end
				end
			end
			if ok then
				for x = wx - 1, wx + 1 do
					for z = wz - 1, wz + 1 do
						if x == wx and z == wz then
							set_cell(x, floor_y + 1, z, "air")
							set_cell(x, floor_y, z, "air")
							set_cell(x, floor_y - 1, z, "air")
							set_cell(x, floor_y - 2, z, "water")
						else
							local n = rng:next(1, 100)
							if n <= 90 then
								set_cell(x, floor_y + 1, z, "stonebrick")
							end
						end
					end
				end
				break
			end
		end
	end

	-- glow-obsidian waypoint posts along the castle ring-path
	for i = 0, 5 do
		local angle = i / 6 * (2 * math.pi) + rng:next(-20, 20) / 100
		local rr = math.floor(half_ext) + 6
		local px = cx + math.floor(math.cos(angle) * rr + 0.5)
		local pz = cz + math.floor(math.sin(angle) * rr + 0.5)
		local blocked = false
		for _, other in ipairs(occupied) do
			if px >= other[1] and px <= other[2]
					and pz >= other[3] and pz <= other[4] then
				blocked = true
				break
			end
		end
		if not blocked and ground_ok[gkey(px, pz)] then
			local n = rng:next(1, 100)
			if n <= 75 then
				set_cell(px, floor_y + 1, pz, "glow")
				if n <= 35 and M.glow2 then
					set_cell(px, floor_y + 2, pz, "glow2")
				end
			end
		end
	end

	-- loose rubble and fungi between the buildings
	for _ = 1, 30 do
		local angle = rng:next(0, 359) / 360 * (2 * math.pi)
		local rr = rng:next(ring_lo, ring_hi)
		local x = cx + math.floor(math.cos(angle) * rr + 0.5)
		local z = cz + math.floor(math.sin(angle) * rr + 0.5)
		if ground_ok[gkey(x, z)] then
			local inside = false
			for _, other in ipairs(occupied) do
				if x >= other[1] and x <= other[2] and z >= other[3] and z <= other[4] then
					inside = true
					break
				end
			end
			if not inside then
				local n = rng:next(1, 100)
				if n <= 45 then
					set_cell(x, floor_y + 1, z, rubble_mat())
				elseif n <= 70 and #PLANTS > 0 then
					set_cell(x, floor_y + 1, z, "plant" .. rng:next(1, #PLANTS))
				elseif n <= 80 and M.salt then
					set_cell(x, floor_y + 1, z, "salt")
				end
			end
		end
	end

	-- ------------------------------------------------------------------
	-- Apply, then place and fill the chests (they need metadata)
	-- ------------------------------------------------------------------
	vm:set_data(data)
	vm:write_to_map(true)
	vm:update_liquids()

	for _, p in ipairs(chest_places) do
		minetest.set_node(p, { name = "default:chest" })
		local meta = minetest.get_meta(p)
		meta:set_string("infotext", S("Abandoned storage"))
		local inv = meta:get_inventory()
		if inv then
			for _ = 1, rng:next(3, 6) do
				local item = LOOT[rng:next(1, #LOOT)]
				if rng:next(1, 100) <= item.chance * 100 then
					inv:add_item("main", item.name .. " " .. rng:next(item.min, item.max))
				end
			end
		end
	end

	minetest.log("action", string.format(
		"[lualore] Abandoned village built around cave castle at %s (%d buildings, %d chests)",
		minetest.pos_to_string(center), placed, #chest_places))

	return true, placed
end

lualore.build_castle_village = build_castle_village

-- ------------------------------------------------------------------
-- Chat command (also works for castles generated before this feature)
-- ------------------------------------------------------------------
minetest.register_chatcommand("build_castle_village", {
	params = "[radius]",
	description = S("Build an abandoned village around the nearest recorded cave castle (default 256)."),
	privs = { server = true },
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Player not found."
		end
		local cc = lualore.cave_castle
		if not cc or not cc.get_records then
			return false, "Cave castle system not loaded."
		end
		local pos = player:get_pos()
		local radius = tonumber(param) or 256
		cc.get_records()
		local nearest, nearest_dist
		for _, rec in pairs(cc.get_records()) do
			if type(rec) == "table" and rec.x then
				local dist = vector.distance(pos, { x = rec.x, y = rec.y or pos.y, z = rec.z })
				if dist <= radius and (nearest_dist == nil or dist < nearest_dist) then
					nearest, nearest_dist = rec, dist
				end
			end
		end
		if not nearest then
			return false, string.format("No recorded cave castle within %d nodes.", radius)
		end
		local ok, res = pcall(build_castle_village,
			{ x = nearest.x, y = nearest.y, z = nearest.z }, nearest.rot, { force = true })
		if not ok then
			return false, "Village build failed: " .. tostring(res)
		end
		if res then
			return true, string.format("Abandoned village built around castle at %s (%d buildings).",
				minetest.pos_to_string({ x = nearest.x, y = nearest.y, z = nearest.z }), res)
		end
		return false, "Village build did not run."
	end,
})
