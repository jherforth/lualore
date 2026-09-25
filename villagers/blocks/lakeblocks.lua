local S = minetest.get_translator("lualore")

minetest.register_node("lualore:fishtrap", {
    description = S"Fish Trap",
    visual_scale = 1,
    mesh = "Fishtrap.b3d",
    tiles = {"texturefishtrap.png"},
    inventory_image = "afishtrap.png",
    paramtype = "light",
    paramtype2 = "facedir",
    groups = {choppy = 3},
    drawtype = "mesh",
    collision_box = {
        type = "fixed",
        fixed = {
            {-0.25, -0.5, -0.5, 0.25, 0.12, 0.5},
            --[[{-0.25, -0.5, -0.5, 0.25, 0.12, 0.5},
            {-0.25, -0.5, -0.5, 0.25, 0.12, 0.5}]]
        }
    },
    selection_box = {
        type = "fixed",
        fixed = {
            {-0.25, -0.5, -0.5, 0.25, 0.12, 0.5}
        }
    },
    sounds = default.node_sound_wood_defaults()
})

minetest.register_craft({
	type = "fuel",
	recipe = "lualore:fishtrap",
	burntime = 3,
})

minetest.register_node("lualore:hangingfish", {
    description = S"Hangning Fish",
    visual_scale = 1,
    mesh = "Hangingfish.b3d",
    tiles = {"texturehangingfish.png"},
    inventory_image = "ahangingfish.png",
    paramtype = "light",
    paramtype2 = "facedir",
    groups = {choppy = 3},
    drawtype = "mesh",
    collision_box = {
        type = "fixed",
        fixed = {
            {-1, -0.5, -0.2, 1, 0.9, 0.2},
            --[[{-1, -0.5, -0.2, 1, 0.9, 0.2},
            {-1, -0.5, -0.2, 1, 0.9, 0.2}]]
        }
    },
    selection_box = {
        type = "fixed",
        fixed = {
            {-1, -0.5, -0.2, 1, 0.9, 0.2}
        }
    },
    sounds = default.node_sound_wood_defaults()
})

minetest.register_craft({
	type = "fuel",
	recipe = "lualore:hangingfish",
	burntime = 3,
})

minetest.register_craftitem("lualore:pearl", {
	description = S("Pearl"),
	inventory_image = "lualore_pearl.png",

})

-- ------------------------------------------------------------------
-- Catfish
-- ------------------------------------------------------------------
-- The fisherman has always dropped lualore:catfish_raw (see the class
-- table in villagers/systems/villagers.lua), but the item was never
-- registered - so every fisherman drop and every fisherman trade handed
-- over an unknown item, which is to say nothing at all.
--
-- There is no catfish artwork yet, so both use the hanging-fish
-- inventory image, the cooked one tinted. Drop proper textures in as
-- lualore_catfish_raw.png / _cooked.png and swap these two lines.
minetest.register_craftitem("lualore:catfish_raw", {
	description = S("Raw Catfish"),
	inventory_image = "ahangingfish.png",
	groups = {food_fish_raw = 1, flammable = 1},
	on_use = minetest.item_eat(2),
})

minetest.register_craftitem("lualore:catfish_cooked", {
	description = S("Cooked Catfish"),
	inventory_image = "ahangingfish.png^[colorize:#c86400:110",
	groups = {food_fish = 1, flammable = 1},
	on_use = minetest.item_eat(6),
})

minetest.register_craft({
	type = "cooking",
	output = "lualore:catfish_cooked",
	recipe = "lualore:catfish_raw",
	cooktime = 4,
})
