-- village_placement.lua
-- ===================================================================
-- VILLAGES - deterministic grid placement (replaces the decoration scatter)
-- ===================================================================
-- Villages used to be registered as schematic decorations: 4 houses +
-- church + market + stable, for 6 biomes = 42 decorations that all shared
-- one global noise. That made building density almost impossible to tune:
--
--   1. The engine places `sidelen^2 * noise_value` decorations at random
--      x/z positions per sidelen division (the noise is sampled ONCE per
--      division, at its centre). Every one of the decorations rolled this
--      independently, so the real density was 7 stacked scatter systems
--      per biome - tweaking the single noise `scale` moved all of them at
--      once, in coarse integer steps.
--   2. Positions were random with no spacing rule, so as soon as a
--      division rolled more than one building the structures overlapped
--      and overwrote each other (they all blit with force_placement).
--      Raising density produced mush; lowering it produced lone houses
--      instead of villages.
--   3. `all_floors` made every matching floor of the chosen column a
--      candidate, so houses could end up in caves or on ledges.
--
-- The replacement works like this:
--
--   * The world is divided into a grid of `spacing` x `spacing` cells.
--     Each cell has ONE candidate position, jittered in the middle half
--     of the cell, so two villages can never be closer than half the
--     spacing.
--   * A cell spawns a village if it passes the `chance` roll, the biome
--     at the candidate maps to a village palette (see
--     villagers/buildings/*.lua), and the terrain is flat enough.
--   * The layout is PLANNED COMPLETELY before anything is placed:
--     optional central buildings (church first, then market/stable)
--     around the centre, then houses on a ring with spacing checks, so
--     buildings can never overlap. Any unreadable (not yet generated)
--     node aborts the attempt with "retry" - a failed attempt can never
--     leave a half-built village behind.
--
-- All tuning lives in minetest.conf / settingtypes.txt:
--   lualore_villages                (bool,  default true)
--   lualore_village_spacing         (int,   default 400)
--   lualore_village_chance          (float, default 0.8)
--   lualore_village_houses_min      (int,   default 4)
--   lualore_village_houses_max      (int,   default 8)
--   lualore_village_radius          (int,   default 22)
--   lualore_village_central_chance  (float, default 0.45)
--   lualore_village_y_max           (int,   default 200)
--   lualore_village_y_min           (int,   default -2)
-- ===================================================================

local S = minetest.get_translator("lualore")

lualore = lualore or {}
lualore.village_palettes = lualore.village_palettes or {}

-- Mod storage reference, fetched at load time (calling
-- minetest.get_mod_storage() later can return nil on some engines).
local storage = minetest.get_mod_storage()

-- ------------------------------------------------------------------
-- Configuration
-- ------------------------------------------------------------------
local function setting_number(key, default)
	local value = tonumber(minetest.settings:get(key))
	if value == nil then
		return default
	end
	return value
end

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

local ENABLED    = minetest.settings:get_bool("lualore_villages", true)
local SPACING    = clamp(math.floor(setting_number("lualore_village_spacing", 400)), 200, 5000)
local CHANCE     = clamp(setting_number("lualore_village_chance", 0.8), 0.0, 1.0)
local HOUSES_MIN = clamp(math.floor(setting_number("lualore_village_houses_min", 4)), 1, 20)
local HOUSES_MAX = clamp(math.floor(setting_number("lualore_village_houses_max", 8)), 1, 20)
if HOUSES_MAX < HOUSES_MIN then
	HOUSES_MAX = HOUSES_MIN
end
local RADIUS     = clamp(math.floor(setting_number("lualore_village_radius", 22)), 8, 60)
local CENTRAL_CHANCE = clamp(setting_number("lualore_village_central_chance", 0.45), 0.0, 1.0)
local Y_MAX      = math.floor(setting_number("lualore_village_y_max", 200))
local Y_MIN      = math.floor(setting_number("lualore_village_y_min", -2))
if Y_MIN > Y_MAX then
	Y_MIN, Y_MAX = Y_MAX, Y_MIN
end

local MODPATH = minetest.get_modpath("lualore")
local ROTATIONS = {0, 90, 180, 270}

-- ------------------------------------------------------------------
-- Node helpers
-- ------------------------------------------------------------------
local function get_name(pos)
	return minetest.get_node(pos).name
end

local function is_unknown(name)
	return name == "ignore" or name == "unknown"
end

local function is_walkable(name)
	local def = minetest.registered_nodes[name]
	return def ~= nil and def.walkable == true
end

local function is_liquid(name)
	local def = minetest.registered_nodes[name]
	return def ~= nil and def.liquidtype ~= nil and def.liquidtype ~= "none"
end

local function passable(name, water_ok)
	return name == "air" or (water_ok and is_liquid(name))
end

-- ------------------------------------------------------------------
-- Schematic sizes (read once, then cached)
-- ------------------------------------------------------------------
local size_cache = {}

local function get_size(file)
	if size_cache[file] ~= nil then
		return size_cache[file]
	end
	local path = MODPATH .. "/schematics/" .. file
	local ok, schem = pcall(minetest.read_schematic, path, {write_yslice_prob = "none"})
	if ok and type(schem) == "table" and type(schem.size) == "table" then
		local size = {x = schem.size.x, y = schem.size.y, z = schem.size.z}
		size_cache[file] = size
		return size
	end
	size_cache[file] = false
	minetest.log("warning", "[lualore] Could not read village schematic " .. file)
	return nil
end

-- Footprint of a rotated schematic (same swap the engine uses).
local function rotated_extent(size, rot)
	if rot == 90 or rot == 270 then
		return size.z, size.x
	end
	return size.x, size.z
end

-- Minimum corner (base layer) so the building ends up centred on (cx, cz).
local function placement_origin(cx, cz, size, rot)
	if rot == 90 or rot == 270 then
		return cx - math.floor((size.z - 1) / 2), cz - math.floor((size.x - 1) / 2)
	end
	return cx - math.floor((size.x - 1) / 2), cz - math.floor((size.z - 1) / 2)
end

-- ------------------------------------------------------------------
-- Palettes (defined by villagers/buildings/*.lua)
-- ------------------------------------------------------------------
local ordered_palettes = nil

local function get_palettes()
	if ordered_palettes then
		return ordered_palettes
	end
	ordered_palettes = {}
	local names = {}
	for name in pairs(lualore.village_palettes) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		ordered_palettes[#ordered_palettes + 1] = lualore.village_palettes[name]
	end
	return ordered_palettes
end

-- Biome names can be namespaced ("mod:biome"). Match the full name first,
-- then fall back to comparing the part after the ":" so a palette entry of
-- "grassland" still matches a biome registered as "everness:grassland".
local function biome_matches(pattern, biome)
	if pattern == biome then
		return true
	end
	local a = pattern:match(":([^:]+)$") or pattern
	local b = biome:match(":([^:]+)$") or biome
	return a == b
end

local function palette_for_pos(x, z)
	local data = minetest.get_biome_data({x = x, y = 64, z = z})
	if not data then
		return nil
	end
	local biome = minetest.get_biome_name(data.biome)
	if not biome then
		return nil
	end
	for _, palette in ipairs(get_palettes()) do
		for _, name in ipairs(palette.biomes) do
			if biome_matches(name, biome) then
				return palette
			end
		end
	end
	return nil
end

-- Scanning window of a palette, intersected with the global band.
local function palette_window(palette)
	local top = math.min(Y_MAX, palette.y_max or Y_MAX)
	local bottom = math.max(Y_MIN, palette.y_min or Y_MIN)
	if top < bottom then
		return nil
	end
	return top, bottom
end

-- ------------------------------------------------------------------
-- Terrain scanning
-- ------------------------------------------------------------------
-- Topmost walkable floor in the column between `top` and `bottom`.
-- Returns floor_y, or nil + "retry" when the area is not generated yet.
local function find_floor(x, z, top, bottom)
	for y = top, bottom, -1 do
		local name = get_name({x = x, y = y, z = z})
		if is_unknown(name) then
			return nil, "retry"
		end
		if is_walkable(name) then
			return y
		end
	end
	return nil
end

-- Floor close to a reference height (used for flatness and building spots).
local function find_floor_near(x, z, ref, slack, top, bottom)
	local hi = math.min(ref + slack, top)
	local lo = math.max(ref - slack, bottom)
	return find_floor(x, z, hi, lo)
end

-- Village centre must be a natural surface of the palette...
local function center_ok(x, z, y, palette)
	local name = get_name({x = x, y = y, z = z})
	local match = false
	for _, surface in ipairs(palette.surface) do
		if surface == name then
			match = true
			break
		end
	end
	if not match then
		return false
	end
	for dy = 1, 3 do
		local above = get_name({x = x, y = y + dy, z = z})
		if is_unknown(above) then
			return "retry"
		end
		if not passable(above, palette.water_ok) then
			return false
		end
	end
	return true
end

-- ...and the area around it flat enough for a village.
local function area_ok(x, z, floor_y, palette, top, bottom)
	local r1 = 10
	local r2 = math.max(14, math.floor(RADIUS * 0.7))
	local samples = {
		{0, 0},
		{r1, 0}, {-r1, 0}, {0, r1}, {0, -r1},
		{r2, r2}, {-r2, r2}, {r2, -r2}, {-r2, -r2},
	}
	local good = 0
	for _, off in ipairs(samples) do
		local y, err = find_floor_near(x + off[1], z + off[2], floor_y, 3, top, bottom)
		if err == "retry" then
			return "retry"
		end
		if y and math.abs(y - floor_y) <= 2 then
			good = good + 1
		end
	end
	return good >= 7
end

-- A building footprint must sit on (near-)level ground.
local function footprint_ok(minx, minz, ext_x, ext_z, floor_y, top, bottom)
	local checks = {
		{minx, minz},
		{minx + ext_x - 1, minz},
		{minx, minz + ext_z - 1},
		{minx + ext_x - 1, minz + ext_z - 1},
		{minx + math.floor((ext_x - 1) / 2), minz + math.floor((ext_z - 1) / 2)},
	}
	for _, c in ipairs(checks) do
		local y, err = find_floor_near(c[1], c[2], floor_y, 2, top, bottom)
		if err == "retry" then
			return "retry"
		end
		if not y or math.abs(y - floor_y) > 2 then
			return false
		end
	end
	return true
end

local function boxes_overlap(a, b)
	return a.minx - 1 <= b.maxx and b.minx - 1 <= a.maxx
		and a.minz - 1 <= b.maxz and b.minz - 1 <= a.maxz
end

-- ------------------------------------------------------------------
-- Deterministic hashing (stable per world seed)
-- ------------------------------------------------------------------
local world_salt = nil

local function get_world_salt()
	if world_salt then
		return world_salt
	end
	local salt = 0
	local seed = minetest.get_mapgen_setting("seed") or ""
	for i = 1, #seed do
		salt = (salt * 131 + string.byte(seed, i)) % 2147483647
	end
	world_salt = (salt * 31 + 192837465) % 2147483647
	return world_salt
end

local function hash_mix(n, value)
	return (n * 48271 + (value % 2147483647)) % 2147483647
end

local function cell_hash(cell_x, cell_z, salt)
	local h = hash_mix(get_world_salt(), cell_x)
	h = hash_mix(h, cell_z)
	h = hash_mix(h, salt)
	return h
end

-- Candidate position of a grid cell; nil when the cell misses its roll.
local function cell_candidate(cell_x, cell_z)
	local h = cell_hash(cell_x, cell_z, 23)
	if h > CHANCE * 2147483647 then
		return nil
	end
	local margin = math.floor(SPACING / 4)
	local span = math.max(1, SPACING - 2 * margin)
	local jitter_x = margin + (hash_mix(h, 101) % span)
	local jitter_z = margin + (hash_mix(h, 211) % span)
	return cell_x * SPACING + jitter_x, cell_z * SPACING + jitter_z,
		cell_hash(cell_x, cell_z, 907)
end

-- ------------------------------------------------------------------
-- Planning & building
-- ------------------------------------------------------------------
local function plan_building(plans, palette, file, cx, cz, floor_y, rot, top, bottom)
	local size = get_size(file)
	if not size then
		return false
	end
	local minx, minz = placement_origin(cx, cz, size, rot)
	local ext_x, ext_z = rotated_extent(size, rot)
	local box = {minx = minx, maxx = minx + ext_x - 1, minz = minz, maxz = minz + ext_z - 1}
	for _, other in ipairs(plans) do
		if boxes_overlap(box, other) then
			return false
		end
	end
	local ok = footprint_ok(minx, minz, ext_x, ext_z, floor_y, top, bottom)
	if ok == "retry" then
		return "retry"
	end
	if not ok then
		return false
	end
	box.file = file
	box.rot = rot
	box.floor_y = floor_y
	box.base_y = floor_y + (palette.offset or 0)
	plans[#plans + 1] = box
	return true
end

-- Plan and execute one village. Returns false (no valid spot),
-- "retry" (area not generated yet) or true, houses, centrals, floor_y.
-- `scan_top`/`scan_bottom` clamp the scan to what the triggering chunk
-- can actually read, so we never wait on sky blocks that never generate.
local function build_village(center_x, center_z, palette, seed, scan_top, scan_bottom)
	local top, bottom = palette_window(palette)
	if not top then
		return false
	end
	local full_top, full_bottom = top, bottom
	if scan_top then
		top = math.min(top, scan_top)
	end
	if scan_bottom then
		bottom = math.max(bottom, scan_bottom)
	end
	if top < bottom then
		return "retry"
	end

	local floor_y, err = find_floor(center_x, center_z, top, bottom)
	if err == "retry" then
		return "retry"
	end
	if not floor_y then
		-- A clipped window means the real surface lives in another chunk.
		if top ~= full_top or bottom ~= full_bottom then
			return "retry"
		end
		return false
	end

	local cok = center_ok(center_x, center_z, floor_y, palette)
	if cok == "retry" then
		return "retry"
	end
	if not cok then
		return false
	end

	local aok = area_ok(center_x, center_z, floor_y, palette, top, bottom)
	if aok == "retry" then
		return "retry"
	end
	if not aok then
		return false
	end

	local pr = PcgRandom(seed)
	local plans = {}

	-- 1. Central buildings: church first, then market and stable.
	local centrals = {
		{file = palette.church, offsets = {{0, 0}, {0, -18}, {0, 18}, {-18, 0}, {18, 0}}},
		{file = palette.market, offsets = {{0, 18}, {18, 0}, {-18, 0}, {0, -18}, {0, 0}}},
		{file = palette.stable, offsets = {{-18, 0}, {0, -18}, {0, 18}, {18, 0}, {0, 0}}},
	}
	local central_count = 0
	for _, central in ipairs(centrals) do
		if central.file and pr:next(0, 9999) < CENTRAL_CHANCE * 10000 then
			for _, off in ipairs(central.offsets) do
				local bx = center_x + off[1]
				local bz = center_z + off[2]
				local y, ferr = find_floor_near(bx, bz, floor_y, 2, top, bottom)
				if ferr == "retry" then
					return "retry"
				end
				if y and math.abs(y - floor_y) <= 2 then
					local result = plan_building(plans, palette, central.file, bx, bz, y,
						ROTATIONS[pr:next(1, 4)], top, bottom)
					if result == "retry" then
						return "retry"
					end
					if result then
						central_count = central_count + 1
						break
					end
				end
			end
		end
	end

	-- 2. Houses on a ring around the centre (evenly spread + jitter).
	local target = pr:next(HOUSES_MIN, HOUSES_MAX)
	local base_angle = pr:next(0, 9999) / 10000 * math.pi * 2
	local r_in = math.max(9, math.floor(RADIUS * 0.5))
	local r_span = math.max(1, RADIUS - r_in)
	local house_count = 0
	for i = 1, target do
		local slot = base_angle + (i - 1) * (math.pi * 2 / target) + (pr:next(-40, 40) / 100)
		for _ = 1, 6 do
			local radius = r_in + pr:next(0, r_span)
			local bx = center_x + math.floor(math.cos(slot) * radius + 0.5)
			local bz = center_z + math.floor(math.sin(slot) * radius + 0.5)
			local y, ferr = find_floor_near(bx, bz, floor_y, 2, top, bottom)
			if ferr == "retry" then
				return "retry"
			end
			if y and math.abs(y - floor_y) <= 2 then
				local file = palette.houses[pr:next(1, #palette.houses)]
				local result = plan_building(plans, palette, file, bx, bz, y,
					ROTATIONS[pr:next(1, 4)], top, bottom)
				if result == "retry" then
					return "retry"
				end
				if result then
					house_count = house_count + 1
					break
				end
			end
			slot = slot + 0.45 -- nudge along the ring and try again
		end
	end

	if #plans == 0 then
		return false
	end

	-- 3. Executing a fully validated plan can no longer fail.
	for _, plan in ipairs(plans) do
		minetest.place_schematic(
			{x = plan.minx, y = plan.base_y, z = plan.minz},
			MODPATH .. "/schematics/" .. plan.file,
			tostring(plan.rot), nil, true)
	end

	return true, house_count, central_count, floor_y
end

-- ------------------------------------------------------------------
-- Records (for /find_village and debugging)
-- ------------------------------------------------------------------
local function load_records()
	local data = storage:get_string("villages")
	if data ~= "" then
		local records = minetest.deserialize(data)
		if type(records) == "table" then
			return records
		end
	end
	return {}
end

local function record_village(center_x, floor_y, center_z, palette, houses, centrals)
	local records = load_records()
	records[minetest.pos_to_string({x = center_x, y = floor_y, z = center_z})] = {
		x = center_x, y = floor_y, z = center_z,
		palette = palette.name or "?",
		houses = houses,
		centrals = centrals,
	}
	storage:set_string("villages", minetest.serialize(records))
end

-- ------------------------------------------------------------------
-- Placement driver
-- ------------------------------------------------------------------
local tried = {}   -- cell_key -> true once resolved (built or dismissed)
local pending = {} -- cell_key -> remaining retry budget
local warned_biomes = {} -- biome name -> true once its "no palette" line was logged
local logged_first_scan = false

local function attempt_cell(cell_x, cell_z, minp, maxp)
	local key = cell_x .. ":" .. cell_z
	if tried[key] then
		return
	end

	local cx, cz, seed = cell_candidate(cell_x, cell_z)
	if not cx then
		tried[key] = true
		return
	end

	local is_retry = pending[key] ~= nil

	-- Only the chunk containing the candidate starts a build normally;
	-- chunks catching a pending retry may help it finish.
	if not is_retry and (cx < minp.x or cx > maxp.x or cz < minp.z or cz > maxp.z) then
		return
	end

	local palette = palette_for_pos(cx, cz)
	if not palette then
		tried[key] = true
		local data = minetest.get_biome_data({x = cx, y = 64, z = cz})
		local biome = data and minetest.get_biome_name(data.biome) or "?"
		if not warned_biomes[biome] then
			warned_biomes[biome] = true
			minetest.log("action", "[lualore] Villages: no palette for biome '" ..
				biome .. "' (first seen at " .. cx .. "," .. cz .. ")")
		end
		return
	end

	local result, houses, centrals, floor_y =
		build_village(cx, cz, palette, seed, maxp.y, minp.y)
	if result == "retry" then
		local left = (pending[key] or 40) - 1
		if left > 0 then
			pending[key] = left
			minetest.after(0.7, function()
				attempt_cell(cell_x, cell_z, minp, maxp)
			end)
		else
			pending[key] = nil
			-- Leave the cell undecided: if the missing chunks generate
			-- later (e.g. the player was flying when this trigger ran),
			-- their own on_generated will pick the village up again.
			minetest.log("info", "[lualore] Village cell " .. key ..
				" postponed (surroundings not readable yet)")
		end
		return
	end

	pending[key] = nil
	tried[key] = true
	if result then
		record_village(cx, floor_y, cz, palette, houses, centrals)
		minetest.log("action", string.format(
			"[lualore] Village built (%s) at %d,%d,%d - %d houses, %d central buildings",
			palette.name or "?", cx, floor_y, cz, houses, centrals))
	end
end

if ENABLED then
	minetest.register_on_generated(function(minp, maxp, blockseed)
		if next(lualore.village_palettes) == nil then
			return
		end
		if maxp.y < Y_MIN or minp.y > Y_MAX then
			return
		end

		if not logged_first_scan then
			logged_first_scan = true
			minetest.log("action", string.format(
				"[lualore] Village scan active (chunk y %d..%d, %d palettes)",
				minp.y, maxp.y, #get_palettes()))
		end

		-- Cells whose jittered candidate can fall inside this chunk
		local c0x = math.floor((minp.x - SPACING * 3 / 4) / SPACING)
		local c1x = math.floor((maxp.x - SPACING / 4) / SPACING)
		local c0z = math.floor((minp.z - SPACING * 3 / 4) / SPACING)
		local c1z = math.floor((maxp.z - SPACING / 4) / SPACING)
		for cell_x = c0x, c1x do
			for cell_z = c0z, c1z do
				attempt_cell(cell_x, cell_z, minp, maxp)
			end
		end
	end)
end

-- ------------------------------------------------------------------
-- Public API for other systems / commands
-- ------------------------------------------------------------------
lualore.villages = {
	-- Build a village at (x, z) right now. Returns the same values as the
	-- internal builder: true/false/"retry"[, houses, centrals, floor_y].
	build_at = function(x, z, palette_name, seed)
		local palette = palette_name and lualore.village_palettes[palette_name]
			or palette_for_pos(x, z)
		if not palette then
			return false
		end
		return build_village(x, z, palette, seed or (get_world_salt() + os.time() % 100000))
	end,
	get_palettes = get_palettes,
}

-- ------------------------------------------------------------------
-- Chat commands (tuning / debugging)
-- ------------------------------------------------------------------
minetest.register_chatcommand("spawn_village", {
	params = "[palette]",
	description = S("Build a village at your position (tuning aid). Optional palette: grassland, desert, ice, jungle, lake, savanna."),
	privs = {server = true},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false
		end
		local pos = player:get_pos()
		local palette
		if param and param ~= "" then
			palette = lualore.village_palettes[param]
			if not palette then
				return false, "Unknown palette '" .. param ..
					"' (use: grassland, desert, ice, jungle, lake, savanna)"
			end
		else
			palette = palette_for_pos(pos.x, pos.z)
			if not palette then
				return false, "No village palette for this biome - pass one explicitly, e.g. /spawn_village grassland"
			end
		end
		local result, houses, centrals, floor_y = lualore.villages.build_at(
			math.floor(pos.x), math.floor(pos.z), palette.name)
		if result == "retry" then
			return false, "Area is not fully generated yet - try again in a second."
		end
		if not result then
			return false, "No suitable flat spot found here."
		end
		record_village(math.floor(pos.x), floor_y, math.floor(pos.z), palette, houses, centrals)
		return true, string.format("Village built: %d houses, %d central buildings.", houses, centrals)
	end,
})

minetest.register_chatcommand("find_village", {
	params = "[radius]",
	description = S("Find the nearest recorded village (default radius 512)."),
	privs = {},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false
		end
		local pos = player:get_pos()
		local radius = tonumber(param) or 512
		local records = load_records()
		local best, best_dist
		for _, rec in pairs(records) do
			if type(rec) == "table" and rec.x then
				local dist = vector.distance(pos, {x = rec.x, y = rec.y or pos.y, z = rec.z})
				if dist <= radius and (best_dist == nil or dist < best_dist) then
					best, best_dist = rec, dist
				end
			end
		end
		if not best then
			return false, "No recorded village within " .. radius .. " nodes."
		end
		return true, string.format(
			"Nearest village: %s at %d,%d,%d (%.0f nodes away, %d houses, %d central buildings)",
			best.palette or "?", best.x, best.y, best.z, best_dist,
			best.houses or 0, best.centrals or 0)
	end,
})

minetest.register_chatcommand("clear_village_records", {
	params = "",
	description = S("Forget village placement records (does not remove built villages)."),
	privs = {server = true},
	func = function(name, param)
		local records = load_records()
		local count = 0
		for _ in pairs(records) do
			count = count + 1
		end
		storage:set_string("villages", "")
		return true, "Cleared " .. count .. " village records."
	end,
})

minetest.register_chatcommand("village_probe", {
	params = "[radius]",
	description = S("Diagnose village placement around you (default 1000)."),
	privs = {server = true},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Player not found."
		end
		local pos = player:get_pos()
		local px, pz = math.floor(pos.x), math.floor(pos.z)
		local radius = tonumber(param) or 1000
		radius = math.max(100, math.min(radius, 3000))

		local stats = {cells = 0, cand = 0, no_palette = 0, no_floor = 0,
			retry = 0, center_bad = 0, area_bad = 0, ok = 0}
		local biomes, unmatched, examples = {}, {}, {}

		local c0x = math.floor((px - radius) / SPACING) - 1
		local c1x = math.floor((px + radius) / SPACING) + 1
		local c0z = math.floor((pz - radius) / SPACING) - 1
		local c1z = math.floor((pz + radius) / SPACING) + 1

		for cell_x = c0x, c1x do
			for cell_z = c0z, c1z do
				stats.cells = stats.cells + 1
				local cx, cz = cell_candidate(cell_x, cell_z)
				if cx then
					local dx, dz = cx - px, cz - pz
					if dx * dx + dz * dz <= radius * radius then
						stats.cand = stats.cand + 1
						local data = minetest.get_biome_data({x = cx, y = 64, z = cz})
						local biome = data and minetest.get_biome_name(data.biome) or "<nil>"
						biomes[biome] = true
						local palette = palette_for_pos(cx, cz)
						if not palette then
							stats.no_palette = stats.no_palette + 1
							unmatched[biome] = true
						else
							local top, bottom = palette_window(palette)
							local floor_y, err = nil, "none"
							if top then
								floor_y, err = find_floor(cx, cz, top, bottom)
							end
							if err == "retry" then
								stats.retry = stats.retry + 1
							elseif not floor_y then
								stats.no_floor = stats.no_floor + 1
							else
								local cok = center_ok(cx, cz, floor_y, palette)
								if cok == "retry" then
									stats.retry = stats.retry + 1
								elseif not cok then
									stats.center_bad = stats.center_bad + 1
								else
									local aok = area_ok(cx, cz, floor_y, palette, top, bottom)
									if aok == "retry" then
										stats.retry = stats.retry + 1
									elseif not aok then
										stats.area_bad = stats.area_bad + 1
									else
										stats.ok = stats.ok + 1
										if #examples < 3 then
											examples[#examples + 1] = string.format(
												"(%d,%d) %s y=%d", cx, cz, palette.name, floor_y)
										end
									end
								end
							end
						end
					end
				end
			end
		end

		local record_count = 0
		for _ in pairs(load_records()) do
			record_count = record_count + 1
		end

		local function key_list(t)
			local out = {}
			for key in pairs(t) do
				out[#out + 1] = tostring(key)
			end
			table.sort(out)
			return out
		end

		local my_data = minetest.get_biome_data({x = px, y = 64, z = pz})
		local my_biome = my_data and minetest.get_biome_name(my_data.biome) or "<nil>"
		local my_palette = palette_for_pos(px, pz)
		local my_line
		if my_palette then
			local top, bottom = palette_window(my_palette)
			local floor_y, err = nil, "none"
			if top then
				floor_y, err = find_floor(px, pz, top, bottom)
			end
			my_line = string.format("your column: biome=%s palette=%s floor=%s",
				my_biome, my_palette.name,
				floor_y and tostring(floor_y) or (err == "retry" and "unloaded" or "none"))
		else
			my_line = "your column: biome=" .. my_biome .. " -> NO PALETTE for this biome"
		end

		local lines = {
			string.format("[village_probe] %s spacing=%d chance=%.2f records=%d",
				ENABLED and "enabled" or "DISABLED", SPACING, CHANCE, record_count),
			my_line,
			string.format("cells=%d candidates=%d | noPalette=%d noFloor=%d retry=%d centerBad=%d areaBad=%d BUILDABLE=%d",
				stats.cells, stats.cand, stats.no_palette, stats.no_floor,
				stats.retry, stats.center_bad, stats.area_bad, stats.ok),
			"biomes at candidates: " .. table.concat(key_list(biomes), ", "),
		}
		local un = key_list(unmatched)
		if #un > 0 then
			lines[#lines + 1] = "NO PALETTE for: " .. table.concat(un, ", ")
		end
		if #examples > 0 then
			lines[#lines + 1] = "would build at: " .. table.concat(examples, " | ")
		elseif stats.cand > 0 then
			lines[#lines + 1] = "No candidate in range would build right now."
		end
		return true, table.concat(lines, "\n")
	end,
})

-- One startup log line so the server log shows which config is live.
do
	local palette_names = {}
	for key in pairs(lualore.village_palettes) do
		palette_names[#palette_names + 1] = key
	end
	table.sort(palette_names)
	minetest.log("action", string.format(
		"[lualore] Villages %s: spacing=%d chance=%.2f band=%d..%d, palettes: %s",
		ENABLED and "enabled" or "DISABLED", SPACING, CHANCE, Y_MIN, Y_MAX,
		#palette_names > 0 and table.concat(palette_names, ", ")
			or "NONE - village building files did not load!"))
end
