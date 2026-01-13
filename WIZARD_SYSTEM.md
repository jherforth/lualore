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

**Spell 2: Inverted Controls** (Red Particles)
- Reverses player movement controls for 5 seconds
- Red spiral particles around the player
- Does not cause damage
- Cooldown: 2.5 seconds

**Drops:**
- 2-5 Mese Crystals
- 1-3 Diamonds

### White Wizard
**Stats:** HP: 100-150 | Armor: 150 | Melee Damage: 3 (wizards rarely use melee)

**Spell 1: Sick Curse** (Green Particles)
- Lasts 15 seconds
- Randomly freezes player movement for 1 second (every 3-5 seconds)
- Green particle bursts when frozen
- Causes small damage over time
- Cooldown: 2.5 seconds

**Spell 2: Hyper Curse** (White Particles)
- Lasts 15 seconds
- Increases player speed by 200%
- Increases jump height
- Makes controls harder to manage
- Cooldown: 2.5 seconds

**Drops:**
- 2-5 Mese Crystals
- 1-3 Diamonds

### Gold Wizard
**Stats:** HP: 100-150 | Armor: 150 | Melee Damage: 3 (wizards rarely use melee)

**Spell 1: Levitate** (Blue Particles)
- Causes player to float upward for 3 seconds
- Reaches up to 10 nodes high
- Player then drops, taking fall damage
- Blue spiral particles during levitation
- Cooldown: 2.5 seconds

**Spell 2: Transformation Curse** (Yellow Particles) *Requires Animalia mod*
- Transforms player into an opossum model for 15 seconds
- Yellow spiral particles during transformation
- Player retains movement but with smaller size
- If Animalia mod is not installed, this spell will not work
- Cooldown: 2.5 seconds

**Drops:**
- 2-5 Mese Crystals
- 1-3 Diamonds
- 3-7 Gold Lumps

### Black Wizard
**Stats:** HP: 100-150 | Armor: 150 | Melee Damage: 3 (wizards rarely use melee)

**Spell: Blindness** (Black Particles)
- Creates thick black particles blocking player's vision for 10 seconds
- Particles are attached to player's view
- Makes it extremely difficult to see
- Does not cause damage
- Cooldown: 2.5 seconds

**Drops:**
- 2-5 Mese Crystals
- 1-3 Diamonds
- 2-5 Obsidian

## Spawn Mechanics

### Automatic Spawning
- Wizards spawn together as a group of 4 in cave castles
- Only spawns in generated caves (Y < 0)
- Requires significant obsidian presence (50+ blocks) to detect castle
- Each castle spawns wizards only once (tracked in mod storage)
- Wizards are positioned in a circle around the castle center

### Manual Spawning (Testing)
Players with "give" privilege can spawn wizards using these commands:

**Spawn entire boss group:**
```
/spawn_wizards
```
Spawns all 4 wizards around you in a circle (requires at least 3 to succeed)

**Spawn individual wizard:**
```
/spawn_wizard <type>
```
Where `<type>` is: red, white, gold, or black

Examples:
- `/spawn_wizard red` - Spawns Red Wizard
- `/spawn_wizard black` - Spawns Black Wizard

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
- Don't panic if transformed - you can still fight

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
- `cave_wizards.lua` - Wizard entity registration and spawning
- `WIZARD_SYSTEM.md` - This documentation file

### Modified Files
- `init.lua` - Added wizard system loading
- `cavebuildings.lua` - Cave castle decoration registration
- `villagers.lua` - Already had wizard class definitions

## Technical Details

### Spell Effect System
All spell effects are tracked in a global `player_effects` table that updates every 0.1 seconds via globalstep. Effects automatically clean up when expired.

### Particle System
Spells use cloud particles with color modifiers:
- Purple: Teleport
- Red: Control inversion
- Green: Sick curse
- White: Hyper speed
- Blue: Levitation
- Yellow: Transformation
- Black: Blindness

### Spell Cooldowns
All spells have a 2.5-second cooldown, making wizards aggressive spell casters who constantly pressure players with magic attacks.

## Dependencies
- `mobs_redo` (required for mob system)
- `animalia` (optional - required for Gold Wizard's transformation spell)
- `default` (for particle textures and item drops)

## Notes
- Wizard spawning is saved to mod storage to prevent duplicates
- Storage saves every 60 seconds
- Each wizard has unique drops making them worth hunting
- Wizards provide a challenging boss fight when all 4 are fought together
