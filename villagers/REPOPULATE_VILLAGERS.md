# Village Repopulation Guide

When upgrading from an older version of this mod, existing villagers may be lost. Use these commands to repopulate your villages.

## Commands

### `/populate_village [radius]`

Scans for beds and spawns villagers to repopulate a village.

**Usage:**
```
/populate_village          (scans 50 blocks around you)
/populate_village 80       (scans 80 blocks around you)
```

**Requirements:**
- Requires `server` privilege
- Radius must be between 10 and 200 blocks

**What it does:**
1. Scans the area for all beds within the radius
2. Auto-detects the biome type based on nearby village marker blocks
3. Spawns appropriate villagers for each bed (one villager per double bed)
4. Links each villager to their bed (they'll treat nearby area as home)
5. Skips beds that already have villagers assigned

**Villager Types Spawned:**
- Farmer, Blacksmith, Fisherman, Cleric
- Bum, Entertainer, Witch, Jeweler, Ranger

**Biomes Detected:**
- Grassland (default)
- Desert (hookah, carpet)
- Ice/Arctic (sledge)
- Lake (fishtrap, hanging fish)
- Savanna (shrine)
- Jungle (jungle shrine)

### `/reset_village_tracking`

Clears the internal tracking of which beds have villagers. Use this if you want to completely repopulate a village or if the tracking data got corrupted.

**Usage:**
```
/reset_village_tracking
```

**Requirements:**
- Requires `server` privilege

**Warning:** This doesn't remove existing villagers, it only clears the tracking data. If you want a clean repopulation:
1. Remove existing villagers manually (or use `/clearobjects`)
2. Run `/reset_village_tracking`
3. Run `/populate_village`

## Example Workflow

After upgrading the mod and losing villagers:

1. Stand in the center of a village
2. Run `/populate_village 60` to scan a 60-block radius
3. The command will report:
   - Biome type detected
   - Number of beds found
   - Number of villagers spawned
   - Number of beds skipped (already populated)

## Notes

- The system prevents double-spawning for double beds (2 bed blocks = 1 villager)
- Villagers are spawned 6-10 blocks away from their bed (outside the house)
- Each villager remembers their home position and stays within 20 blocks of it
- The tracking data is saved automatically every 60 seconds
- If biome detection fails, it defaults to Grassland villagers
