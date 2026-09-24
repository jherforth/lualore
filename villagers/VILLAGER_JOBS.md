# 🛠️ Villager Jobs

Villagers claim a workstation near their bed and spend their working day at it, returning
home at dusk. Implemented in `villagers/systems/villager_jobs.lua`, with the WORKING state
itself living alongside the other behaviour states in `villager_behaviors.lua`.

## The working day

| Period | Working | Socialising | Wandering |
| --- | --- | --- | --- |
| Morning (6–8am) | 70% | 10% | 20% |
| Afternoon (8am–4pm) | 55% | 20% | 25% |
| Evening (4–6pm) | 15% | 50% | 35% |

These are weights rolled at each state change, not a script, so a village never looks
clockwork — some villagers are always out and about. Dusk (7pm) onwards is not in the table
at all: going home is handled earlier in the behaviour update than the state machine, so the
bed routine always wins over work, mid-shift or not.

A villager with no workstation behaves exactly as it always did.

## Workstations

| Class | Works at |
| --- | --- |
| Blacksmith | `lualore:anvil`, `default:furnace` |
| Cleric | `lualore:village_altar`, `default:bookshelf` |
| Fisherman | `lualore:fishtrap`, `lualore:hangingfish` |
| Jeweler | `vessels:shelf`, `lualore:grasslandbarrel` |
| Entertainer | `lualore:hookah`, `lualore:sledge`, `lualore:jungleshrine`, `lualore:savannavshrine`, `lualore:desertcrpet` |
| Farmer | `lualore:field_stake` |
| Bum, Ranger | nothing — their work is walking, and arrives in a later phase |
| Witch | deliberately has no job; her whole tick belongs to `witch_magic.lua` |

Listed in priority order: the first type with a free instance near the bed wins. Node names
that no mod registered are dropped at first use and logged, so a class whose workstation
does not exist yet simply has no job rather than erroring.

### Where the workstations come from

Most of them a village already contains. Three did not exist anywhere — no building
schematic in this mod holds an anvil, an altar or a single tilled block — so they are
defined in `villagers/blocks/workstations.lua` and placed by
`villagers/systems/village_workstations.lua`:

| Node | Placed | Craftable |
| --- | --- | --- |
| `lualore:anvil` | with a `default:furnace` beside it, 6–16 nodes out | 8 steel ingots |
| `lualore:village_altar` | two nodes clear of the church, else near the centre | 8 stone brick + a mese crystal |
| `lualore:field_stake` | on the corner of each tilled plot, 12–26 nodes out | 2 sticks + wood |

A **farm plot** is 5×5: a water source in the middle so minetest_game's soil ABM keeps the
ground wet (dry soil reverts to dirt and takes the crops with it), the stake on one corner,
and `farming:soil_wet` with a wheat crop on the other 23 columns. Villages get one plot, or
two on a third of seeds. Ice villages get none — a wheat field on an ice sheet reads as a
mistake — but deserts do, as an oasis.

Nothing is placed unless the ground is level, open to the sky, clear of every building
footprint and free of anything already standing there. A village with no room simply gets
nothing rather than an anvil in somebody's front room.

Placement runs **after** the ground-dressing pass, because dressing plants over every free
column and would otherwise bury the lot.

### Who lives in a village

Beds used to pick a class uniformly at random, which left a six-house village with a better
than even chance of having no blacksmith, and nothing stopped it rolling four farmers. A
village now deals from a tiered deck:

1. **farmer, blacksmith, cleric** — shuffled, so every village of three houses or more has
   all three
2. **fisherman, jeweler, entertainer, ranger** — if there is room
3. **farmer, bum, farmer, bum, witch** — filler

Measured over 400 villages: three- and six-house villages get no duplicate trades at all and
always have a smith and a farmer; twelve-house villages hold one of everything with at most
three farmers. The overall spread stays farmer 25%, bum 16%, everything else 8%.

`/populate_village` deals from the same deck.

- A villager searches **once**, on entering the working state, within **20 nodes** of its
  bed. That radius is not arbitrary: `check_stuck_and_recover` teleports a villager home
  once it strays past roughly 45 nodes, so a station inside 20 can never trigger it.
- Finding nothing, it waits 5 minutes before looking again, so an unhoused villager never
  loops on the search.
- Claims are stored in mod storage under `job_stations`, keyed by **bed** position — beds
  survive an unload, entity ids do not, so a villager re-adopts its own workplace after a
  restart. The claimed node also carries a `lualore_station` meta field and an infotext, so
  you can see whose workplace it is by looking at it.
- Claims are released when the villager dies.

## Commands

| Command | Privs | What it does |
| --- | --- | --- |
| `/jobs [radius]` | server | Lists nearby villagers with their class, behaviour state, distance and claimed workstation (default radius 40). |
| `/furnish_village [radius]` | server | Adds the anvil, forge, altar and farm plots to the village you are standing in (default radius 34). Needed for villages that already exist — new ones are furnished as they generate. |

## Settings

| Setting | Default | Meaning |
| --- | --- | --- |
| `lualore_villager_jobs` | `true` | Off restores the original wander/socialise day exactly: the schedule defers to the old two-state cycle and the job tick becomes a no-op. |
| `lualore_village_workstations` | `true` | Off stops new villages being furnished. `/furnish_village` still works. |

## Notes

- Villagers now carry `nv_class` on the entity. Everything used to re-derive the class by
  matching on the entity name; `lualore.jobs.get_class(self)` is the single accessor, and
  still falls back to the name match for anything that predates the field.
- `nv_trade_items` and `drops` come off the mob prototype, which is **shared by every
  instance of a class across all six biomes**. Never mutate them in place — a villager takes
  a private copy of its trade list on activation. Job output goes in `nv_stock`, never in
  `drops`.
- The job tick runs at most every 2 seconds, with its phase staggered per villager so a
  village does not tick as one block, and skips entirely when no player is within 40 nodes.
  The shared player-position list is refreshed by a single globalstep rather than per mob.
- Job state (`nv_class`, `nv_work_pos`, `nv_stock`) is saved with the villager. It must stay
  plain data: `get_staticdata` returns an empty string if serialisation throws, and an empty
  staticdata silently costs the villager its bed *and* its mood.

## Prerequisites that shipped with this

Three bugs made any of this impossible, and were hurting the mod on their own:

1. **Village props were unknown nodes.** Every `.mts` schematic stores the prop names under
   the old `nativevillages:` namespace. `villagers/blocks/aliases.lua` maps all eight onto
   this mod's nodes (`cannibalshrine` is a rename to `lualore:jungleshrine`, the rest are
   namespace swaps). Existing worlds heal themselves as mapblocks reload.
2. **Every village in every biome spawned grassland villagers.** Biome detection looks for a
   prop near the bed; it was looking for `lualore:` names the schematics never place, three
   of which matched no registered node at all. There is now one marker table, in
   `aliases.lua`, that both `house_spawning.lua` and `village_commands.lua` read.
3. **`lualore:catfish_raw` was never registered**, so the fisherman's only drop and trade
   reward was an unknown item. Raw and cooked catfish now exist in `lakeblocks.lua`, with a
   cooking recipe. They borrow the hanging-fish artwork until proper textures exist.

Also folded in: the two duplicated copies of the trade code became one, which is what finally
called `lualore.mood.on_trade` — a function that had never run, so trades gave no hunger
relief and never played the trade sound.
