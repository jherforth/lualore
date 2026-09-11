# 🏘️ Village Placement & Density

Villages are placed by `villagers/systems/village_placement.lua`. The six
`villagers/buildings/*.lua` files only define **palettes** (which biomes,
which surface nodes, which schematics per biome).

## Why the old system was replaced

Villages used to be schematic **decorations**: 4 houses + church + market +
stable registered separately for 6 biomes, all sharing one global noise. That
made building density nearly impossible to tune:

1. **Density was multiplied.** The engine places `sidelen² × noise_value`
   decorations per `sidelen` division, at *random* positions — and the noise
   is sampled only once per division (at its centre). Each of the 42
   decorations rolled this independently, so a single `scale` tweak moved
   seven stacked scatter systems at once, in coarse integer steps.
2. **No spacing rule.** As soon as a division rolled 2+ buildings they
   overlapped and overwrote each other (all blits use `force_placement`).
   More density produced mush; less produced lone houses, not villages.
3. **`all_floors`** made every matching floor of the chosen column a
   candidate — houses could land in caves or on ledges.

## How it works now

- The world is divided into a grid of `spacing × spacing` cells. Each cell has
  **one** candidate position, jittered in the middle half of the cell — two
  villages can never be closer than half the spacing.
- A cell spawns a village when it passes the `chance` roll, the biome at the
  candidate maps to a palette, and the terrain around it is flat enough
  (±2 nodes over the area; houses individually need a level footprint).
- The layout is **planned completely before anything is placed**: church,
  market and stable first (rolled separately), then houses evenly spread on a
  ring around the centre, each nudged until it fits without overlapping any
  other footprint. Unreadable (not yet generated) nodes abort with a retry —
  a failed attempt can never leave a half-built village.
- Villagers still spawn from the beds inside the placed schematics
  (`house_spawning.lua`), unchanged except for a slightly longer delay so it
  always runs after placement.

## Settings

| Setting | Default | Meaning |
| --- | --- | --- |
| `lualore_villages` | `true` | Enable automatic placement. |
| `lualore_village_spacing` | `400` | Nodes between grid cells. Lower = more villages. |
| `lualore_village_chance` | `0.8` | Fraction of cells that attempt a village. |
| `lualore_village_houses_min` | `4` | Minimum houses per village. |
| `lualore_village_houses_max` | `8` | Maximum houses per village. |
| `lualore_village_radius` | `22` | How far houses scatter from the centre. |
| `lualore_village_central_chance` | `0.45` | Chance per central building (church/market/stable). |
| `lualore_village_y_max` | `200` | Top of the surface search band. |
| `lualore_village_y_min` | `-2` | Bottom of the surface search band. |

Tuning recipes:

- **More villages:** lower `lualore_village_spacing` (350, 250) and/or raise
  `lualore_village_chance` to `1.0`.
- **Bigger villages:** raise `lualore_village_houses_max` (10–12) and
  `lualore_village_radius` (28–32).
- **Fewer fancy buildings:** lower `lualore_village_central_chance`.
- Settings apply to **newly generated chunks** only. Use `/spawn_village`
  to preview changes immediately.
- If you see no villages at all, run `/village_probe` and check the startup
  log line `[lualore] Villages enabled: ... palettes: ...`. Both tell you
  whether the driver is live, what biome you are in, and where placement
  stops. Already-generated terrain never gets retroactive villages.

## Commands

| Command | Privs | What it does |
| --- | --- | --- |
| `/spawn_village [palette]` | server | Builds a village at your position right now (palette = grassland, desert, ice, jungle, lake, savanna; guessed from the biome if omitted). |
| `/find_village [radius]` | — | Nearest recorded village (default radius 512). |
| `/village_probe [radius]` | server | Diagnoses placement around you (default radius 1000): shows your biome vs palette, and counts candidates that fail at each stage (no palette / no floor / unloaded / not flat) vs how many would build. |
| `/clear_village_records` | server | Forgets placement records (does not remove built villages). |
| `/populate_village [radius]` | server | Existing bed-based villager repopulation (unchanged). |

## Palettes

Each palette in `villagers/buildings/*.lua` has:

```lua
lualore.village_palettes.grassland = {
    name = "grassland",
    biomes = {"grassland"},                      -- biome names that select it
    surface = {"default:dirt_with_grass", ...},  -- natural ground nodes
    offset = -6,          -- schematic base sunk into the ground (foundation)
    y_min = ..., y_max = ...,                    -- optional search band override
    water_ok = false,     -- lake shores allow water around them
    houses = {"grasslandhouse1.mts", ...},
    church = "grasslandchurch.mts",
    market = "grasslandmarket.mts",
    stable = "grasslandstable.mts",
}
```

Adding a biome is just adding a table like this (or extra entries to an
existing `houses` list).

## Notes

- A palette can list several biome names, and namespaced names match their
  last segment (`"grassland"` also matches `everness:grassland`). If your
  game renames a biome (for example `grassland` -> `grassytwo`), add the new
  name to the relevant `biomes` list. The server log prints
  `[lualore] Villages: no palette for biome 'X'` the first time an
  unrecognized biome gets a candidate, so renames never fail silently.
- Already-generated terrain keeps whatever it had before this system (old
  decoration buildings stay where they are); the new placer only affects
  newly generated chunks.
- Lake palettes use a narrow search band (`-2..4`) and allow water around the
  village, so the stilt houses stay near the waterline as before.
- The legacy noise definitions in `villagers/systems/village_noise.lua` are
  no longer used by village placement (kept only so nothing that references
  `lualore.global_village_noise` breaks).
