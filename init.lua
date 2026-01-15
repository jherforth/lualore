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
dofile(modpath .. "/cannibalblocks.lua")
dofile(modpath .. "/savannablocks.lua")
dofile(modpath .. "/arcticblocks.lua")
dofile(modpath .. "/grasslandblocks.lua")
dofile(modpath .. "/lakeblocks.lua")
dofile(modpath .. "/desertblocks.lua")

-- 2. Village system (noise parameters for building placement)
dofile(modpath .. "/village_noise.lua")

-- 3. Buildings (they use the noise tables from above)
dofile(modpath .. "/junglebuildings.lua")
dofile(modpath .. "/icebuildings.lua")
dofile(modpath .. "/grasslandbuildings.lua")
dofile(modpath .. "/lakebuildings.lua")
dofile(modpath .. "/desertbuildings.lua")
dofile(modpath .. "/savannabuildings.lua")
dofile(modpath .. "/wizards/cavebuildings.lua")

-- 4. Systems (villagers, mood, spawning)
dofile(modpath .. "/npcmood.lua")
dofile(modpath .. "/villager_behaviors.lua")
dofile(modpath .. "/smart_doors.lua")
dofile(modpath .. "/witch_magic.lua")
dofile(modpath .. "/wizards/wizard_magic.lua")
dofile(modpath .. "/villagers.lua")
dofile(modpath .. "/house_spawning.lua")
dofile(modpath .. "/village_commands.lua")
dofile(modpath .. "/wizards/cave_wizards.lua")

-- 6. Optional/fun extras
dofile(modpath .. "/explodingtoad.lua")
dofile(modpath .. "/loot.lua")

-- 7. Custom mob spawning (if exists)
if mobs.custom_spawn_lualore then
    dofile(modpath .. "/spawn.lua")
end

-- ===================================================================
-- Final message
-- ===================================================================

minetest.log("action", "[lualore] Successfully loaded — " ..
    "6 biomes | perfect villages | villagers | cave wizards | exploding toads")
print(S("[MOD] lualore loaded — a living world awaits you"))
