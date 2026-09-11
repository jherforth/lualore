# Cave Wizard Boss Fight System

## Overview
The cave castle contains four powerful wizards that spawn together as a boss fight. Each wizard has unique spells with different visual effects and gameplay mechanics.

## Wizard Types & Spells

### Red Wizard
**Stats:** HP: 100-150 | Armor: 150 | Melee Damage: 3 (wizards rarely use melee)

**Spell 1: Teleport** (Purple Particles)
- Teleports the player 15 blocks away in a random direction
- No damage, purely positional disruption
- Cooldown: 2.5 seconds

**Spell 2: Inverted Controls** (Red X-Shaped Particles)
- Reverses player movement controls for 5 seconds
- Red X-shaped particles around the player
- Does not cause damage
- Cooldown: 2.5 seconds

**Drops:**
- 2-5 Mese Crystals
- 1-3 Diamonds

### White Wizard
**Stats:** HP: 100-150 | Armor: 150 | Melee Damage: 3 (wizards rarely use melee)

**Spell 1: Sick Curse** (Green Organic Blob Particles)
- Lasts 15 seconds
- Randomly freezes player movement for 1 second (every 3-5 seconds)
- Green organic blob-shaped particle bursts when frozen
- Causes small damage over time
- Cooldown: 2.5 seconds

**Spell 2: Hyper Curse** (White Star Particles)
- Lasts 15 seconds
- Increases player speed by 200%
- Increases jump height
- White star-shaped particles around the player
- Makes controls harder to manage
- Cooldown: 2.5 seconds

**Drops:**
- 2-5 Mese Crystals
- 1-3 Diamonds

### Gold Wizard
**Stats:** HP: 100-150 | Armor: 150 | Melee Damage: 3 (wizards rarely use melee)

**Spell 1: Levitate** (Blue Up Arrow Particles)
- Causes player to float upward for 3 seconds
- Reaches up to 10 nodes high
- Player then drops, taking fall damage
- Blue upward arrow particles rising around the player
- Cooldown: 2.5 seconds

**Spell 2: Shrinking Curse** (Yellow Down Arrow Particles)
- Shrinks player model to half size for 15 seconds
- Reduces player speed to 50% and jump height to 70%
- Shrinks field of view to 50% (tunnel vision effect)
- Yellow downward arrow particles when shrinking
- Yellow upward arrow particles when returning to normal size
- Makes player harder to control and vulnerable
- Cooldown: 2.5 seconds

**Drops:**
- 2-5 Mese Crystals
- 1-3 Diamonds
- 3-7 Gold Lumps

### Black Wizard
**Stats:** HP: 100-150 | Armor: 150 | Melee Damage: 3 (wizards rarely use melee)

**Spell: Blindness** (Black Circle Particles)
- Creates swirling black circle particles that obscure vision for 10 seconds
- Particles zoom around the player's field of view making it hard to see
- Multiple particle layers create a chaotic visual effect
- Vision is heavily obscured but not completely blocked
- Does not cause damage
- Cooldown: 2.5 seconds

**Drops:**
- 2-5 Mese Crystals
- 1-3 Diamonds
- 2-5 Obsidian

## Spawn Mechanics

### Automatic Spawning
- Cave castles are placed on a deterministic grid: every
  `lualore_cave_castle_spacing` x `lualore_cave_castle_spacing` nodes (default
  400) has one candidate position, jittered inside the middle half of the cell,
  so castles can never be closer than half the spacing. No more stacked or
  missing placement from the old decoration system.
- A candidate only spawns a castle when a suitable cave floor is found: enough
  open space above (12+ nodes of air), no lava underneath, and between
  `lualore_cave_castle_y_top` (default -120) and
  `lualore_cave_castle_y_bottom` (default -1200).
- After placement the crypt is carved open with a VoxelManip, so the statue
  room and its stairwell from the plaza are always reachable.
- The four wizards spawn around the statue inside the crypt. Spawning is
  retried a few times, and each castle only spawns its group once (tracked in
  mod storage).
- Cave castles from worlds generated before this update are not tracked; use
  the commands below to spawn/respawn wizards at those.

### Manual Spawning (Testing)
Players with "give" privilege can spawn wizards using these commands:

**Spawn entire boss group:**
```
/spawn_wizards
```
Spawns up to 4 wizards around you in a circle

**Spawn individual wizard:**
```
/spawn_wizard <type>
```
Where `<type>` is: red, white, gold, or black

Examples:
- `/spawn_wizard red` - Spawns Red Wizard
- `/spawn_wizard black` - Spawns Black Wizard

**Spawn at nearest statue (works for old castles too):**
```
/spawn_wizards_at_statue [radius]
```
Finds the nearest `caverealms:dm_statue` and spawns the boss group around it
(default radius: 100; opens a small chamber if the crypt is still buried)

### Admin Commands (server privilege)
- `/find_castle [radius]` - locate the nearest recorded cave castle (default 512)
- `/castle_probe [radius]` - diagnose cave castle placement around you (default
  1000): counts candidates with a suitable cave floor vs none vs not-generated-yet,
  and reports whether your own column could host a castle
- `/spawn_cavecastle` - place a cave castle at your position (debug)
- `/spawn_castle_wizards [radius]` - spawn/respawn the boss group at the nearest
  recorded castle (default 256)
- `/clear_castle_records` - reset wizard spawn records so groups can spawn again

## Combat Strategy

### General Tips
- Each wizard alternates between their two spells (except Black Wizard who has one)
- **Spell range: 4-20 blocks** - Wizards prefer to keep their distance
- **Wizards actively avoid close combat** - They will back away if you get within 6 blocks
- **Spell cooldown: 2.5 seconds** - Wizards cast spells frequently
- **Minimal melee damage (3)** - Their strength is in magic, not physical combat
- All wizards are aggressive and will attack players on sight
- Wizards have high HP (100-150) and strong armor (150)
- Wizards do not spawn in regular villages, only in cave castles
- If you try to rush them, they will retreat while continuing to cast spells

### Countering Each Wizard

**Red Wizard:**
- Stay close to avoid being teleported to dangerous locations
- Be prepared for disorienting movement with inverted controls
- Watch for purple spell particles indicating teleport incoming

**White Wizard:**
- Keep distance during Hyper Curse to avoid losing control
- Be ready to stop moving when Sick Curse freezes you
- Bring healing items for curse damage

**Gold Wizard:**
- Watch for blue particles and prepare for fall damage
- Stay near walls or low ceilings to prevent high levitation
- If shrunken, retreat to safety - reduced speed and FOV make you vulnerable

**Black Wizard:**
- Use sound cues when blinded
- Retreat to safe area when you see black spell particles
- Fight near walls to maintain spatial awareness when blind

### Recommended Gear
- Strong armor (diamond or better)
- Healing items (bread, apples, or potions)
- Ranged weapons for maintaining distance
- Torches for navigation in caves
- Water bucket (negates fall damage from levitate)

## Files Modified/Created

### New Files
- `wizard_magic.lua` - Spell system and effects
- `cave_wizards.lua` - Wizard entity registration
- `WIZARD_SYSTEM.md` - This documentation file

### Modified Files
- `init.lua` - Added wizard system loading
- `cavebuildings.lua` - Cave castle grid placement, crypt carving and wizard spawning
- `villagers.lua` - Already had wizard class definitions

## Technical Details

### Spell Effect System
All spell effects are tracked in a global `player_effects` table that updates every 0.1 seconds via globalstep. Effects automatically clean up when expired.

### Particle System
Spells use custom-shaped particles with color modifiers:
- Purple: Teleport (cloud particles)
- Red: Control inversion (X-shaped particles)
- Green: Sick curse (organic blob particles)
- White: Hyper speed (star-shaped particles)
- Blue: Levitation (upward arrow particles)
- Yellow: Shrinking curse (downward arrow particles when shrinking, upward when returning to normal)
- Black: Blindness (circle particles that swirl with velocity to obscure but not block vision)

Custom particle textures:
- `lualore_particle_x.png` - X shape for inverted controls
- `lualore_particle_blob.png` - Organic blob for sickness
- `lualore_particle_star.png` - Star for hyper speed
- `lualore_particle_arrow_up.png` - Upward arrow for levitation
- `lualore_particle_arrow_down.png` - Downward arrow for shrinking
- `lualore_particle_circle.png` - Circle for blindness

### Spell Cooldowns
All spells have a 2.5-second cooldown, making wizards aggressive spell casters who constantly pressure players with magic attacks.

## Dependencies
- `mobs_redo` (required for mob system)
- `default` (for particle textures and item drops)

## Notes
- Castle records and wizard spawn flags are saved to mod storage whenever
  they change
- Placement is tuned through `settingtypes.txt` (spacing, chance, Y band,
  crypt carving)
- Each wizard has unique drops making them worth hunting
- Wizards provide a challenging boss fight when all 4 are fought together
