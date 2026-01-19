-- init.lua
-- lualore — Final perfected version

lualore = {}

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

-- Internationalization
local S
if minetest.get_translator then
    S = minetest.get_translator("lualore")
else
    S = dofile(modpath .. "/intllib.lua")
end
mobs.intllib = S

-- Global serialization safety net (keeps your world from corrupting on rare bugs)
local original_serialize = minetest.serialize
minetest.serialize = function(data)
    local success, result = pcall(original_serialize, data)
    if success then
        return result
    else
        minetest.log("error", "[lualore] Serialization failed: " .. result)
        return original_serialize({})
    end
end

-- Check for custom spawn file
local spawn_file = io.open(modpath .. "/spawn.lua", "r")
if spawn_file then
    mobs.custom_spawn_lualore = true
    spawn_file:close()
end

-- ===================================================================
-- LOAD ORDER (critical for dependencies and noise sharing)
-- ===================================================================

-- 1. Nodes & blocks (must come first)
dofile(modpath .. "/villagers/blocks/jungleblocks.lua")
dofile(modpath .. "/villagers/blocks/savannablocks.lua")
dofile(modpath .. "/villagers/blocks/arcticblocks.lua")
dofile(modpath .. "/villagers/blocks/grasslandblocks.lua")
dofile(modpath .. "/villagers/blocks/lakeblocks.lua")
dofile(modpath .. "/villagers/blocks/desertblocks.lua")

-- 2. Village system (noise parameters for building placement)
dofile(modpath .. "/villagers/systems/village_noise.lua")

-- 3. Buildings (they use the noise tables from above)
dofile(modpath .. "/villagers/buildings/junglebuildings.lua")
dofile(modpath .. "/villagers/buildings/icebuildings.lua")
dofile(modpath .. "/villagers/buildings/grasslandbuildings.lua")
dofile(modpath .. "/villagers/buildings/lakebuildings.lua")
dofile(modpath .. "/villagers/buildings/desertbuildings.lua")
dofile(modpath .. "/villagers/buildings/savannabuildings.lua")
dofile(modpath .. "/wizards/cavebuildings.lua")

-- 4. Systems (villagers, mood, spawning)
dofile(modpath .. "/villagers/systems/npcmood.lua")
dofile(modpath .. "/villagers/systems/villager_behaviors.lua")
dofile(modpath .. "/villagers/systems/smart_doors.lua")
dofile(modpath .. "/villagers/systems/witch_magic.lua")
dofile(modpath .. "/wizards/wizard_magic.lua")
dofile(modpath .. "/wizards/wizard_wands.lua")
dofile(modpath .. "/villagers/systems/villagers.lua")
dofile(modpath .. "/villagers/systems/house_spawning.lua")
dofile(modpath .. "/villagers/systems/village_commands.lua")
dofile(modpath .. "/wizards/cave_wizards.lua")

-- 6. Optional/fun extras
dofile(modpath .. "/villagers/extras/explodingtoad.lua")
dofile(modpath .. "/villagers/extras/loot.lua")

-- 7. Valkyrie and Sky Folk systems
dofile(modpath .. "/valkyrie/valkyrie_strikes.lua")
dofile(modpath .. "/valkyrie/sky_liberation.lua")
dofile(modpath .. "/valkyrie/sky_blocks.lua")
dofile(modpath .. "/valkyrie/sky_valkyries.lua")
dofile(modpath .. "/valkyrie/sky_folk.lua")
dofile(modpath .. "/valkyrie/sky_villages.lua")
dofile(modpath .. "/valkyrie/floating_buildings.lua")

-- 8. Custom mob spawning (if exists)
if mobs.custom_spawn_lualore then
    dofile(modpath .. "/spawn.lua")
end

-- ===================================================================
-- Final message
-- ===================================================================

minetest.log("action", "[lualore] Successfully loaded — " ..
    "6 biomes | perfect villages | villagers | cave wizards | sky valkyries | sky folk | exploding toads")
print(S("[MOD] lualore loaded — a living world awaits you"))
