-- village_ground.lua
-- ===================================================================
-- VILLAGE GROUND - organic outline, ground texture, vegetation, paths
-- ===================================================================
-- village_placement.lua terraforms a village site and then blits the
-- schematics. On its own that leaves a perfectly round plate of a single
-- ground node: readable, but sterile. This module supplies the three
-- passes that make a site look grown rather than stamped:
--
--   1. SHAPE - a per-village outline built from a handful of angular
--      harmonics, so the flattened core is a lobed blob instead of a
--      circle and the ramp band that blends it into the terrain varies
--      in width around it. The outline is radial (radius as a function
--      of the angle only), so it is always one closed area that still
--      contains the house ring - no detached islands, no house left
--      standing on a slope.
--   2. TEXTURE - coherent noise patches of accent ground nodes (worn
--      dirt, gravel, dry grass ...) over the uniform floor, plus trodden
--      earth against the building walls and faint paths running from
--      every building to the village centre.
--   3. VEGETATION - grass, flowers, shrubs and the odd bush scattered by
--      a meadow noise, thinning out towards doorsteps and paths.
--
-- Only the columns the terraformer actually re-laid are dressed, so
-- natural ground inside the ramp band keeps whatever the mapgen put
-- there.
--
-- Settings:
--   lualore_village_organic        (bool,  default true)
--   lualore_village_ground_noise   (bool,  default true)
--   lualore_village_vegetation     (bool,  default true)
--   lualore_village_paths          (bool,  default true)
--   lualore_village_plant_density  (float, default 0.22)
-- ===================================================================

lualore = lualore or {}

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

local ORGANIC    = minetest.settings:get_bool("lualore_village_organic", true)
local TEXTURE    = minetest.settings:get_bool("lualore_village_ground_noise", true)
local VEGETATION = minetest.settings:get_bool("lualore_village_vegetation", true)
local PATHS      = minetest.settings:get_bool("lualore_village_paths", true)
local DENSITY    = clamp(setting_number("lualore_village_plant_density", 0.22), 0.0, 1.0)

-- ------------------------------------------------------------------
-- Small helpers
-- ------------------------------------------------------------------
local atan2 = math.atan2 or math.atan

-- Deterministic value in [0,1) for a column + salt. Used instead of a
-- sequential PRNG so the dressing never depends on iteration order.
local function hash01(x, z, salt)
	local h = (x * 73856093 + z * 19349663 + salt * 83492791) % 2147483647
	h = (h * 48271 + 11) % 2147483647
	return h / 2147483647
end

local function col_key(x, z)
	return (x + 32768) * 65536 + (z + 32768)
end

-- ------------------------------------------------------------------
-- Noise fields (created on first use: the world seed must be known)
-- ------------------------------------------------------------------
local noise_factory = minetest.get_value_noise or minetest.get_perlin

local PATCH_NP = {offset = 0, scale = 1, spread = {x = 11, y = 11, z = 11},
	seed = 45109, octaves = 2, persistence = 0.5, lacunarity = 2.0, flags = "defaults"}
local PICK_NP = {offset = 0, scale = 1, spread = {x = 23, y = 23, z = 23},
	seed = 45110, octaves = 1, persistence = 0.5, lacunarity = 2.0, flags = "defaults"}
local MEADOW_NP = {offset = 0, scale = 1, spread = {x = 17, y = 17, z = 17},
	seed = 45111, octaves = 2, persistence = 0.6, lacunarity = 2.0, flags = "defaults"}

local noises = nil
local noise_failed = false

local function get_noises()
	if noises then
		return noises
	end
	if noise_failed or not noise_factory then
		return nil
	end
	local ok, patch, pick, meadow = pcall(function()
		return noise_factory(PATCH_NP), noise_factory(PICK_NP), noise_factory(MEADOW_NP)
	end)
	if not ok or not patch then
		noise_failed = true
		minetest.log("warning",
			"[lualore] Village ground: noise unavailable, falling back to hashes")
		return nil
	end
	noises = {patch = patch, pick = pick, meadow = meadow}
	return noises
end

-- Raw sample (get_2d / get2d, depending on engine version). The position
-- table is reused: the engine reads it during the call and a big village
-- asks for tens of thousands of samples.
local sample_pos = {x = 0, y = 0}

local function noise_at(obj, x, z)
	local fn = obj.get_2d or obj.get2d
	sample_pos.x, sample_pos.y = x, z
	return fn(obj, sample_pos)
end

-- How wide a noise field's values spread depends on the engine version and
-- on the octave count, and the spread is narrow either way: over a village-
-- sized area a two-octave field of these parameters sat around 0.53 +- 0.15
-- once mapped naively into 0..1, so asking for "the lowest 15% of the
-- field" by comparing against 0.15 painted 0.1% of the ground. Rather than
-- guess a correction factor, every site calibrates: sample the field over
-- the site, sort, and read the thresholds straight off that distribution.
-- Coverage then means what it says, whatever the engine hands us.
local function calibrate(obj, cx, cz, reach)
	local vals = {}
	local step = math.max(1, math.floor(reach / 8)) -- ~17x17 samples
	for x = cx - reach, cx + reach, step do
		for z = cz - reach, cz + reach, step do
			vals[#vals + 1] = noise_at(obj, x, z)
		end
	end
	table.sort(vals)
	return vals
end

local function quantile(vals, q)
	local n = #vals
	if n == 0 then
		return 0
	end
	return vals[clamp(math.floor(q * (n - 1)) + 1, 1, n)]
end

-- Map a raw sample into 0..1 using the site's own low/high marks.
local function rescale(value, lo, hi)
	if hi <= lo then
		return 0.5
	end
	return clamp((value - lo) / (hi - lo), 0, 1)
end

-- ------------------------------------------------------------------
-- 1. SITE SHAPE
-- ------------------------------------------------------------------
-- Relative weights of the outline harmonics: the low orders make the big
-- lobes, the high orders ruffle the edge. Each village rolls its own
-- amplitudes from these, which are then normalised to AMP_BUDGET - so
-- however the roll comes out, the outline can bulge at most that fraction
-- beyond the nominal radius. That bound is what keeps the terraformer's
-- voxel area (and the map it has to read) from ballooning on the widest
-- villages, where an unnormalised roll reached +38%.
local HARMONICS = {
	{k = 2, weight = 0.40},
	{k = 3, weight = 0.29},
	{k = 5, weight = 0.20},
	{k = 7, weight = 0.11},
}

local AMP_BUDGET = 0.24

local shape_mt = {}
shape_mt.__index = shape_mt

-- Flat-core radius at an angle.
local function radius_at(self, a)
	local w = 0
	for i = 1, #self.terms do
		local t = self.terms[i]
		w = w + t.amp * math.sin(t.k * a + t.phase)
	end
	-- Bulge outwards more readily than inwards: the houses need the core,
	-- and an outline that kept hitting `min_r` would show flat arcs there -
	-- circle segments, which is exactly the look this is meant to avoid.
	if w < 0 then
		w = w * 0.55
	end
	local r = self.core_r * (1 + w)
	if r < self.min_r then
		r = self.min_r
	end
	return r
end

-- Flat-core radius and ramp width in the direction of (dx, dz).
function shape_mt:profile(dx, dz)
	if #self.terms == 0 then
		return self.core_r, self.band_w
	end
	local a = atan2(dz, dx)
	return radius_at(self, a),
		self.band_w * (1 + 0.35 * math.sin(3 * a + self.band_phase))
end

-- core_r: nominal radius of the flattened plain
-- min_r:  radius the outline may never dip below (must cover the houses)
-- band_w: nominal width of the blending ramp outside the core
local function new_shape(seed, core_r, min_r, band_w)
	min_r = math.min(min_r, core_r)
	if not ORGANIC then
		local shape = setmetatable({
			core_r = core_r, min_r = min_r, band_w = band_w,
			terms = {}, band_phase = 0, seed = seed,
		}, shape_mt)
		shape.max_reach = math.ceil(core_r + band_w + 1)
		return shape
	end

	local pr = PcgRandom(seed or 1)
	local terms = {}
	local rolled = 0
	for _, h in ipairs(HARMONICS) do
		local amp = h.weight * (pr:next(55, 145) / 100)
		rolled = rolled + amp
		terms[#terms + 1] = {
			k = h.k,
			amp = amp,
			phase = pr:next(0, 62831) / 10000,
		}
	end
	for _, t in ipairs(terms) do
		t.amp = t.amp * AMP_BUDGET / rolled
	end
	local shape = setmetatable({
		core_r = core_r,
		min_r = min_r,
		band_w = band_w,
		terms = terms,
		band_phase = pr:next(0, 62831) / 10000,
		seed = seed,
	}, shape_mt)

	-- How far this outline actually reaches, by walking it. The harmonics
	-- would only all peak together in the worst case, and sizing the
	-- terraformer's voxel area off that bound would read (and rewrite) a
	-- good deal of map for nothing.
	local widest = min_r
	for i = 0, 71 do
		local r = radius_at(shape, i * math.pi / 36)
		if r > widest then
			widest = r
		end
	end
	shape.max_reach = math.ceil(widest + band_w * 1.35 + 1)
	return shape
end

-- ------------------------------------------------------------------
-- 2. PALETTE STYLES (what the ground and the greenery are made of)
-- ------------------------------------------------------------------
-- Palettes may define `ground` and `plants` (see villagers/buildings/*).
-- Anything they leave out falls back to the generic lists below, and
-- every node is checked against the node registry on first use, so a
-- palette may freely name blocks from mods a world might not have.
--
-- One trap when choosing ground nodes: minetest_game runs a "Grass spread"
-- ABM that turns any lit, uncovered `default:dirt` into whichever
-- `group:spreading_dirt_type` sits next to it. Paving a path or a worn yard
-- with plain dirt therefore looks right for a few minutes and is then
-- quietly grassed back over. The palettes here use nodes the ABM leaves
-- alone - gravel, sand, permafrost and the `_with_` surface variants,
-- which are spreading types themselves and so stay put.
local GENERIC_ACCENTS = {
	{"default:dirt_with_dry_grass", 8},
	{"default:gravel", 3, bare = true},
}

local GENERIC_PLANTS = {
	{"default:grass_2", 6}, {"default:grass_3", 6}, {"default:grass_4", 4},
	{"default:grass_1", 3}, {"default:grass_5", 3},
	{"flowers:dandelion_yellow", 1}, {"flowers:geranium", 1},
}

local function filter_weighted(list, out)
	if type(list) ~= "table" then
		return out
	end
	for _, entry in ipairs(list) do
		local name = entry[1] or entry.name
		local weight = entry[2] or entry.weight or 1
		if name and minetest.registered_nodes[name] and weight > 0 then
			out[#out + 1] = {name = name, weight = weight, bare = entry.bare}
		end
	end
	return out
end

-- First registered node of the candidate list. Iterated with select() on
-- purpose: most calls pass an optional palette field first, and `{...}`
-- would drop everything after a nil argument.
local function first_registered(...)
	for i = 1, select("#", ...) do
		local name = select(i, ...)
		if name and minetest.registered_nodes[name] then
			return name
		end
	end
	return nil
end

local style_cache = {}

local function resolve_style(palette)
	local key = palette.name or tostring(palette)
	if style_cache[key] then
		return style_cache[key]
	end
	local ground = palette.ground or {}
	local plants = palette.plants or {}

	local base = first_registered(ground.base,
		palette.surface and palette.surface[1]) or "default:dirt"

	local accents = filter_weighted(ground.accents, {})
	if #accents == 0 and ground.accents == nil then
		accents = filter_weighted(GENERIC_ACCENTS, {})
	end
	local coverage = 0
	for _, a in ipairs(accents) do
		coverage = coverage + a.weight
	end
	coverage = clamp(coverage / 100, 0, 0.6)

	local list = filter_weighted(plants.list, {})
	if #list == 0 and plants.list == nil then
		list = filter_weighted(GENERIC_PLANTS, {})
	end
	local plant_total = 0
	for _, p in ipairs(list) do
		plant_total = plant_total + p.weight
	end

	local bush = nil
	if plants.bush then
		local stem = first_registered(plants.bush.stem)
		local leaves = first_registered(plants.bush.leaves)
		if stem and leaves then
			bush = {stem = stem, leaves = leaves,
				chance = plants.bush.chance or 0.012}
		end
	end

	local style = {
		base = base,
		accents = accents,
		accent_coverage = coverage,
		worn = first_registered(ground.worn, "default:gravel") or base,
		path = first_registered(ground.path, ground.worn, "default:gravel") or base,
		plants = list,
		plant_total = plant_total,
		density = clamp(DENSITY * (plants.density or 1.0), 0, 1),
		bush = bush,
	}
	style_cache[key] = style
	return style
end

-- ------------------------------------------------------------------
-- 3. DRESSING THE SITE
-- ------------------------------------------------------------------
-- Chebyshev distance from a column to the nearest building footprint
-- (0 = inside one).
local function box_distance(boxes, x, z)
	local best = 1e9
	for i = 1, #boxes do
		local b = boxes[i]
		local dx = 0
		if x < b.minx then
			dx = b.minx - x
		elseif x > b.maxx then
			dx = x - b.maxx
		end
		local dz = 0
		if z < b.minz then
			dz = b.minz - z
		elseif z > b.maxz then
			dz = z - b.maxz
		end
		local d = dx > dz and dx or dz
		if d < best then
			if d == 0 then
				return 0
			end
			best = d
		end
	end
	return best
end

-- Faint trodden trails from every building to the village centre. The
-- line swings sideways so nothing reads as a ruler-straight road, and
-- the swing fades out at both ends so it meets the doorstep and the
-- centre cleanly.
local function mark_paths(site, marks)
	for i, b in ipairs(site.plans) do
		local bx = math.floor((b.minx + b.maxx) / 2)
		local bz = math.floor((b.minz + b.maxz) / 2)
		local dx, dz = site.cx - bx, site.cz - bz
		local steps = math.max(math.abs(dx), math.abs(dz))
		if steps > 0 then
			local phase = hash01(bx, bz, 17 + i) * 6.283
			local along_x = math.abs(dx) >= math.abs(dz)
			for s = 0, steps do
				local t = s / steps
				local swing = math.sin(s * 0.22 + phase) * 2.0 * math.sin(t * math.pi)
				local off = math.floor(swing + 0.5)
				local x = bx + math.floor(dx * t + 0.5)
				local z = bz + math.floor(dz * t + 0.5)
				if along_x then
					z = z + off
				else
					x = x + off
				end
				for ox = -1, 1 do
					for oz = -1, 1 do
						if ox * ox + oz * oz <= 1 then
							marks[col_key(x + ox, z + oz)] = true
						end
					end
				end
			end
		end
	end
end

local function weighted_pick(list, total, roll)
	local acc = 0
	local target = roll * total
	for i = 1, #list do
		acc = acc + list[i].weight
		if target < acc then
			return list[i]
		end
	end
	return list[#list]
end

local function add(batch, name, pos)
	local list = batch[name]
	if not list then
		list = {}
		batch[name] = list
	end
	list[#list + 1] = pos
end

local function flush(batch)
	local count = 0
	for name, list in pairs(batch) do
		count = count + #list
		if minetest.bulk_set_node then
			minetest.bulk_set_node(list, {name = name})
		else
			for _, pos in ipairs(list) do
				minetest.set_node(pos, {name = name})
			end
		end
	end
	return count
end

-- A small bush: stem, leaf cap and up to four leaf sides.
local function plant_bush(batch, style, x, y, z)
	local function free(px, py, pz)
		return minetest.get_node({x = px, y = py, z = pz}).name == "air"
	end
	if not (free(x, y + 1, z) and free(x, y + 2, z)) then
		return false
	end
	add(batch, style.bush.stem, {x = x, y = y + 1, z = z})
	add(batch, style.bush.leaves, {x = x, y = y + 2, z = z})
	for _, off in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
		local px, pz = x + off[1], z + off[2]
		if free(px, y + 2, pz) then
			add(batch, style.bush.leaves, {x = px, y = y + 2, z = pz})
		end
	end
	return true
end

-- site = {cx, cz, palette, seed, columns = {{x=,y=,z=}, ...}, plans = {boxes}}
-- `columns` are exactly the columns the terraformer re-laid, `y` being
-- the new surface height of each one.
local function dress(site)
	local columns = site.columns
	if not columns or #columns == 0 then
		return 0, 0
	end
	if not (TEXTURE or VEGETATION or PATHS) then
		return 0, 0
	end
	local style = resolve_style(site.palette)
	local n = get_noises()
	local salt = math.floor((site.seed or 1) % 65536)
	local boxes = site.plans or {}

	local marks = {}
	if PATHS and #boxes > 0 then
		mark_paths(site, marks)
	end

	local accent_total = 0
	for _, a in ipairs(style.accents) do
		accent_total = accent_total + a.weight
	end

	-- Calibrate the noise fields against this site (see `calibrate`).
	local patch_max, patch_jitter, pick_lo, pick_hi, meadow_lo, meadow_hi
	if n then
		local reach = math.max(16, site.shape and site.shape.max_reach or 40)
		local patch_vals = calibrate(n.patch, site.cx, site.cz, reach)
		patch_max = quantile(patch_vals, style.accent_coverage)
		-- edge roughening, in the units of this field
		patch_jitter = (quantile(patch_vals, 0.9) - quantile(patch_vals, 0.1)) * 0.12
		local pick_vals = calibrate(n.pick, site.cx, site.cz, reach)
		pick_lo, pick_hi = quantile(pick_vals, 0.05), quantile(pick_vals, 0.95)
		local meadow_vals = calibrate(n.meadow, site.cx, site.cz, reach)
		meadow_lo, meadow_hi = quantile(meadow_vals, 0.1), quantile(meadow_vals, 0.9)
	end

	local ground_batch, plant_batch = {}, {}
	local plant_spots = {}

	for _, col in ipairs(columns) do
		local x, y, z = col.x, col.y, col.z
		local dist = box_distance(boxes, x, z)
		if dist > 0 then
			local on_path = marks[col_key(x, z)] == true
			local bare = false
			local node = nil

			-- --- ground texture -------------------------------------
			if on_path then
				node = style.path
				bare = true
			elseif TEXTURE and dist <= 1 then
				-- trodden earth against the walls
				if hash01(x, z, salt + 3) < 0.75 then
					node = style.worn
					bare = true
				end
			elseif TEXTURE and accent_total > 0 then
				local accented, pick
				if n then
					-- coherent patches, their borders roughened by a small
					-- per-node jitter so they are not smooth curves
					local jitter = (hash01(x, z, salt + 5) - 0.5) * patch_jitter
					accented = noise_at(n.patch, x, z) + jitter < patch_max
					pick = rescale(noise_at(n.pick, x, z), pick_lo, pick_hi)
				else
					accented = hash01(x, z, salt + 5) < style.accent_coverage
					pick = hash01(x, z, salt + 6)
				end
				if accented then
					local accent = weighted_pick(style.accents, accent_total, pick)
					node = accent.name
					bare = accent.bare == true
				end
			end
			if node and node ~= style.base then
				add(ground_batch, node, {x = x, y = y, z = z})
			end

			-- --- vegetation -----------------------------------------
			if VEGETATION and not bare and not on_path and dist > 1
					and #style.plants > 0 then
				-- meadow noise makes the greenery clump into thickets and
				-- worn-thin spots instead of an even sprinkle
				local meadow = n
					and rescale(noise_at(n.meadow, x, z), meadow_lo, meadow_hi)
					or 0.5
				local density = style.density * (0.3 + 1.4 * meadow)
				if dist <= 3 then
					density = density * 0.35 -- swept yards around the houses
				end
				if hash01(x, z, salt + 9) < density then
					plant_spots[#plant_spots + 1] = {x = x, y = y, z = z}
				end
			end
		end
	end

	local ground_count = flush(ground_batch)

	-- Plants sit on top of whatever now lies on the surface, so they are
	-- placed after the ground pass and only where the air is still free
	-- (a schematic may overhang its own footprint).
	local plant_count = 0
	for _, p in ipairs(plant_spots) do
		if minetest.get_node({x = p.x, y = p.y + 1, z = p.z}).name == "air" then
			if style.bush and hash01(p.x, p.z, salt + 21) < style.bush.chance then
				if plant_bush(plant_batch, style, p.x, p.y, p.z) then
					plant_count = plant_count + 1
				end
			else
				local plant = weighted_pick(style.plants, style.plant_total,
					hash01(p.x, p.z, salt + 13))
				add(plant_batch, plant.name, {x = p.x, y = p.y + 1, z = p.z})
				plant_count = plant_count + 1
			end
		end
	end
	flush(plant_batch)

	return ground_count, plant_count
end

-- ------------------------------------------------------------------
-- Public API (used by village_placement.lua)
-- ------------------------------------------------------------------
lualore.village_ground = {
	new_shape = new_shape,
	dress = dress,
	resolve_style = resolve_style,
	enabled = {
		organic = ORGANIC,
		texture = TEXTURE,
		vegetation = VEGETATION,
		paths = PATHS,
		density = DENSITY,
	},
}
