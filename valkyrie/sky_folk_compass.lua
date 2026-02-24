-- sky_folk_compass.lua
-- Thin compatibility shim.
-- Navigation is now handled by sky_folk_pins (world-space waypoint) and
-- sky_folk_tracker (HUD icon + fly-out panel).  This module keeps the
-- same public API so existing call-sites don't break.

lualore.sky_folk_compass = {}

function lualore.sky_folk_compass.start(player, sky_folk_entity)
	-- Pins system handles the waypoint; nothing extra needed here.
end

function lualore.sky_folk_compass.stop(player_name)
	-- Pins are cleared via lualore.sky_folk_pins.clear(); nothing extra needed.
end

minetest.log("action", "[lualore] Sky Folk compass (shim) loaded")
