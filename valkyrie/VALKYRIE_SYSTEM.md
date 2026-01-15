# Sky Valkyrie Sentinel Boss Fight System

## Overview
The floating islands contain four powerful Valkyrie Sentinels that spawn together as a boss fight. Each sentinel is an elite sky warrior with unique aerial strikes, featuring wind gusts, spear-like thrusts, and divine trials with dramatic visual effects and gameplay mechanics. They use the standard SAM character model with armored textures and flowing capes.

## Valkyrie Types & Strikes

### Blue Valkyrie (Fury Sentinel)
**Stats:** HP: 100-150 | Armor: 150 | Melee Damage: 8 (aggressive close-range fighters)

**Strike 1: Wind Dash** (Purple Wind Trail Particles)
- Dashes forward like a spear thrust, knocking the player 15 blocks away in a random direction
- Minor impact damage (2-4 hearts)
- Cooldown: 2.5 seconds

**Strike 2: Tempest Spin** (Red Whirlwind Particles)
- Spins with dual blades, reversing player movement controls for 5 seconds
- Red whirlwind-shaped particles envelop the player
- No additional damage
- Cooldown: 2.5 seconds

**Drops:**
- 2-5 Mese Crystals
- 1-3 Diamonds
- 1-2 Aether Shards (new sky resource)

### Violet Valkyrie (Gale Sentinel)
**Stats:** HP: 100-150 | Armor: 150 | Melee Damage: 8 (aggressive close-range fighters)

**Strike 1: Frost Bind** (Green Ice Shard Particles)
- Lasts 15 seconds
- Randomly freezes player movement for 1 second (every 3-5 seconds)
- Green ice shard particle bursts when frozen
- Causes small frostbite damage over time (1 heart total)
- Cooldown: 2.5 seconds

**Strike 2: Sky Surge** (White Gale Burst Particles)
- Lasts 15 seconds
- Boosts player speed by 200% and jump height
- White gale burst particles trail the player
- Makes aerial navigation trickier on islands
- Cooldown: 2.5 seconds

**Drops:**
- 2-5 Mese Crystals
- 1-3 Diamonds
- 1-2 Aether Shards

### Gold Valkyrie (Thunder Sentinel)
**Stats:** HP: 100-150 | Armor: 150 | Melee Damage: 8 (aggressive close-range fighters)

**Strike 1: Thunder Lift** (Blue Lightning Bolt Particles)
- Hurls spear energy, lifting player upward for 3 seconds (up to 10 nodes)
- Player drops afterward, taking fall damage
- Blue lightning bolt particles surge around the player
- Cooldown: 2.5 seconds

**Strike 2: Storm Compress** (Yellow Thunder Cloud Particles)
- Compresses air, shrinking player model to half size for 15 seconds
- Reduces speed to 50% and jump to 70%
- Narrows field of view to 50% (tunnel vision)
- Yellow thunder cloud particles during shrink; gold sparks when expanding
- Cooldown: 2.5 seconds

**Drops:**
- 2-5 Mese Crystals
- 1-3 Diamonds
- 3-7 Gold Lumps
- 2-3 Aether Shards

### Green Valkyrie (Eclipse Sentinel)
**Stats:** HP: 100-150 | Armor: 150 | Melee Damage: 8 (aggressive close-range fighters)

**Strike: Shadow Veil** (Black Storm Cloud Particles)
- Summons swirling black storm clouds obscuring vision for 10 seconds
- Particles whirl around the player's field of view
- Multiple layers create chaotic sky storm effect
- Vision heavily obscured but not blocked
- No damage
- Cooldown: 2.5 seconds

**Drops:**
- 2-5 Mese Crystals
- 1-3 Diamonds
- 2-5 Obsidian

## Spawn Mechanics

### Automatic Spawning
- Valkyries spawn together as a group of 4 in sky fortresses on floating islands
- Only spawns in generated floating islands (Y > 100)
- Requires significant cloudstone or aether block presence (50+ blocks) to detect fortress
- Each fortress spawns valkyries only once (tracked in mod storage)
- Valkyries positioned in a defensive circle around the fortress center

### Manual Spawning (Testing)
Players with "give" privilege can spawn valkyries using these commands:

**Spawn entire boss group:**
/spawn_valkyries
Spawns all 4 valkyries around you in a circle (requires at least 3 to succeed)

**Spawn individual valkyrie:**
/spawn_valkyrie <type>
Where `<type>` is: blue, violet, gold, or green

Examples:
- `/spawn_valkyrie blue` - Spawns Blue Valkyrie
- `/spawn_valkyrie green` - Spawns Green Valkyrie

## Combat Strategy

### General Tips
- Each valkyrie alternates between their two strikes (except Black Valkyrie who has one)
- **Strike range: 4-20 blocks** - Valkyries charge in for melee but use strikes at distance
- **Valkyries pursue aggressively** - They close gaps with dashes if you retreat beyond 10 blocks
- **Strike cooldown: 2.5 seconds** - Frequent aerial assaults keep pressure high
- **Solid melee damage (8)** - Their warrior training makes them deadly up close
- All valkyries are aggressive and challenge players on sight
- Valkyries have high HP (100-150) and strong armor (150)
- Valkyries do not spawn in regular villages or caves, only sky fortresses
- Dodge their charges and use island terrain for cover

### Countering Each Valkyrie

**Blue Valkyrie:**
- Sidestep Wind Dash to avoid knockback into voids
- Counter Tempest Spin by sheathing sword and sprint-jumping away
- Watch purple trails signaling incoming dash

**Violet Valkyrie:**
- Break line of sight during Sky Surge to regain control mid-air
- Time attacks around Frost Bind freezes
- Use fire items or warmth to counter chill damage

**Gold Valkyrie:**
- Feather fall or water bucket for Thunder Lift drops
- Hug island edges or low platforms to limit lift height
- If compressed, prioritize evasion over attack

**Green Valkyrie:**
- Rely on audio cues and peripheral vision in Shadow Veil
- Lure to lit areas or use torches for contrast
- Fight with back to solid island ground

### Recommended Gear
- Strong armor (diamond or better, with feather falling enchant if available)
- Healing items (bread, golden apples, or sky potions)
- Ranged weapons (bows) and melee sword for mix
- Elytra or glider mods for aerial mobility
- Water bucket (negates fall damage)
- Torches for illuminating dark storm effects

## Files Modified/Created

### New Files
- `valkyrie_strikes.lua` - Strike system and effects
- `sky_valkyries.lua` - Valkyrie entity registration and spawning
- `VALKYRIE_SYSTEM.md` - This documentation file

### Modified Files
- `init.lua` - Added valkyrie system loading
- `floating_islands.lua` - Sky fortress decoration registration
- `villagers.lua` - Added valkyrie class definitions (SAM model compatible)

## Technical Details

### Strike Effect System
All strike effects tracked in a global `player_effects` table, updating every 0.1 seconds via globalstep. Effects auto-clean on expiration.

### Particle System
Strikes use custom sky-themed particles:
- Purple: Wind Dash (trail particles)
- Red: Tempest Spin (whirlwind particles)
- Green: Frost Bind (ice shard particles)
- White: Sky Surge (gale burst particles)
- Blue: Thunder Lift (lightning bolt particles)
- Yellow: Storm Compress (thunder cloud particles shrinking, gold sparks expanding)
- Black: Shadow Veil (storm cloud particles swirling)

Custom particle textures:
- `lualore_particle_windtrail.png` - Trail for dashes
- `lualore_particle_whirlwind.png` - Whirlwind for spins
- `lualore_particle_iceshard.png` - Ice shards for binds
- `lualore_particle_gale.png` - Gale bursts for surges
- `lualore_particle_lightning.png` - Bolts for lifts
- `lualore_particle_thundercloud.png` - Clouds for compress
- `lualore_particle_stormswirl.png` - Swirls for veils

### Strike Cooldowns
All strikes have a 2.5-second cooldown for relentless sky battles.

## Dependencies
- `mobs_redo` (required for mob system)
- `default` (for particle textures and item drops)
- Floating islands mod (for biome integration)

## Notes
- Valkyrie spawning saved to mod storage to prevent duplicates
- Storage saves every 60 seconds
- Unique drops reward sky adventures
- Group fights test aerial combat skills on precarious islands
- Kid-friendly: Effects disorient but emphasize dodging and strategy over gore
