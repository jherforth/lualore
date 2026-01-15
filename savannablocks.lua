local S = minetest.get_translator("lualore")

minetest.register_node("lualore:savannavshrine", {
    description = S"Savanna Shrine",
    visual_scale = 1,
    mesh = "Savannashrine.b3d",
    tiles = {"texturesavannashrine.png"},
    inventory_image = "asavannashrine.png",
    paramtype = "light",
    paramtype2 = "facedir",
    groups = {choppy = 3},
    walkable = false,
    drawtype = "mesh",
    collision_box = {
        type = "fixed",
        fixed = {
            {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
            --[[{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
            {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}]]
        }
    },
    selection_box = {
        type = "fixed",
        fixed = {
            {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}
        }
    },
    sounds = default.node_sound_wood_defaults()
})

minetest.register_craft({
	type = "cooking",
	output = "default:bronzeblock",
	recipe = "lualore:savannashrine",
})

