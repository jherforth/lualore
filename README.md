# Lua Lore

A comprehensive villager and lore mod for Luanti (formerly Minetest) that adds living, breathing villages across multiple biomes with an advanced NPC mood and interaction system.

## Features

### 🏘️ Multiple Biome Villages

The mod generates villages in six distinct biomes, each with unique architecture and culture:

- **Grassland Villages** - Traditional settlements with farming communities
- **Desert Villages** - Sandy oasis towns with exotic markets
- **Savanna Villages** - Tribal communities with ceremonial shrines
- **Lake Villages** - Fishing communities built near water
- **Ice Villages** - Hardy settlements in frozen tundra
- **Jungle Villages** - Dangerous jungle tribes with unique customs

### 👥 Diverse Villager Classes

Each village is populated with various NPC types, each with unique behaviors, trades, and roles:

- **Hostile** - Aggressive NPCs that attack on sight
- **Raider** - Combat-focused NPCs that attack players and other NPCs
- **Ranger** - Defensive NPCs that protect villages from monsters
- **Jeweler** - Traders specializing in precious gems and metals
- **Farmer** - Agricultural workers who trade crops and food
- **Blacksmith** - Craftsmen trading tools, weapons, and materials
- **Fisherman** - Aquatic specialists trading fish and fishing supplies
- **Cleric** - Mystical NPCs with magical items
- **Bum** - Humble NPCs with modest trades
- **Entertainer** - Social NPCs that enhance village atmosphere
- **Witch** - Hostile magic users with dual attacks: melee punches (7 damage, within 1 block) and frequent teleportation spells (10 blocks random direction, 1-5 blocks range, 2s cooldown)

### 🎭 Advanced Mood System

NPCs feature a sophisticated emotional system with visual and audio feedback:

#### Moods
- **😊 Happy** - High mood value (80+)
- **🙂 Content** - Good mood (60-79)
- **😐 Neutral** - Average mood (40-59)
- **😢 Sad** - Low mood (20-39)
- **😠 Angry** - Very low mood (0-19)
- **🍖 Hungry** - When hunger exceeds 80
- **💔 Lonely** - When loneliness exceeds 80
- **😨 Scared** - When fear exceeds 70

#### Desires
NPCs display their needs through visual indicators:
- **🍞 Food** - When hungry (hunger > 70)
- **💰 Trade** - When they want to trade
- **👥 Companionship** - When lonely (loneliness > 60)
- **🛡️ Safety** - When scared (fear > 50)
- **💤 Rest** - When health is low (< 15)

#### Mood Factors
NPC mood is calculated based on:
- **Hunger** - Increases over time, decreases when fed
- **Loneliness** - Increases without interaction, decreases with player contact
- **Fear** - Increases during combat, decreases when safe
- **Health** - Lower health negatively affects mood
- **Ownership** - Tamed NPCs receive a mood bonus

### 🔊 Dynamic Sound System

NPCs emit sounds based on their emotional state:

- **Mood Sounds** - angry, content, happy, hungry, lonely, neutral, sad, scared
- **Action Sounds** - trade (when trading), villager_fed (when fed), rest (when needing rest)
- **Conditions**:
  - Plays when player is within 3 nodes of NPC
  - Configurable repeat delay (default: 10 seconds)
  - Trade and feed sounds override mood sounds
  - Rest desire rotates with mood sounds

**Configuration**: Edit `nativevillages.mood.sound_repeat_delay` in `npcmood.lua` to adjust sound frequency.

### 💱 Trading System

Interact with villagers to trade items:

1. **Initiate Trade** - Hold a desired trade item and approach the NPC
2. **Trade Indicator** - NPCs show a trade desire icon when interested
3. **Execute Trade** - Right-click while sneaking OR punch with the trade item
4. **Receive Items** - NPCs drop items from their loot table

**Trade Benefits**:
- Reduces loneliness (-25)
- Reduces hunger (-15)
- Improves overall mood
- Resets interaction timer

### 🍞 Feeding System

Keep villagers happy by feeding them:

- **Bread** - Reduces hunger significantly, heals +5 HP
- **Apple** - Reduces hunger moderately, heals +5 HP
- Plays special "villager_fed" sound
- Resets hunger to 1
- Resets interaction timer

### 🚪 Smart Doors System

Doors in villages automatically detect and respond to nearby NPCs:

- **Automatic Opening** - Doors open when NPCs approach within 2.5 blocks
- **Automatic Closing** - Doors close 3 seconds after all NPCs leave
- **Multi-NPC Support** - Multiple NPCs can use the same door without conflicts
- **Selective Opening** - Only opens for friendly NPCs, not hostile mobs
- **Quiet Operation** - Door sounds play at 30% volume to reduce noise

**Configuration**: Edit `smart_doors.lua` to adjust detection radius and timing.

### 🏗️ Village Buildings

Villages are compact settlements that fit within 1-2 mapchunks (80-160 nodes across), creating well-organized communities rather than sprawling cities.

Each biome features unique structures:

- **Grassland**: Houses, stables, ponds, ceremonial blots, altars
- **Desert**: Adobe houses, markets, wells, stables, cages
- **Savanna**: Thatched huts, shrines, thrones, wells, witch houses
- **Lake**: Waterfront houses, harbours, fish traps
- **Ice**: Igloos, sledges, log piles, pelt storage
- **Jungle**: Tribal houses, cages, towers, ritual pits, shrines

**Village Generation:**
- Villages generate naturally in their respective biomes
- Each village is limited to 1-2 mapchunks for compact, organized layouts
- Central buildings (churches, markets, stables) are rare and only appear in established villages
- Building placement uses noise-based distribution for natural, organic clustering

### 📦 Special Items & Blocks

The mod includes numerous decorative and functional items:

- **Food Items**: Catfish (raw/cooked), chicken (raw/cooked), cheese, butter, milk
- **Decorative**: Carpets, blankets, barrels, shrines, altars, vessels
- **Functional**: Fish traps, sledges, cages, hookah
- **Special**: Dried human meat, toad bags, pearls, fireballs

### 🐾 Custom Entities

- **Animals**: Grassland cows, grassland cats, desert chickens, ice dogs, lions (male/female), catfish, toads
- **Special NPCs**: Slave traders, dancers, lion trainers, chicken breeders, cow herders
- **Tamed Zombies**: Witches can trade special zombie-taming items

## Installation

1. Download or clone this repository
2. Place the `nativevillages` folder in your Luanti mods directory
3. Enable the mod in your world settings
4. Requires the `mobs` mod (mobs_redo) as a dependency

## Dependencies

- **mobs** (mobs_redo) - Required
- **default** - Required
- **farming** - Required
- **intllib** - Optional (for translations)

## Configuration

### Visual Indicators
Toggle mood indicators in `villagers/systems/npcmood.lua`:
```lua
nativevillages.mood.enable_visual_indicators = true  -- false to disable
```

### Sound Repeat Delay
Adjust how often NPCs play sounds in `villagers/systems/npcmood.lua`:
```lua
nativevillages.mood.sound_repeat_delay = 10  -- seconds between sounds
```

### Village Size
Adjust village compactness in `villagers/systems/village_noise.lua`:
```lua
-- For single mapchunk villages (80 nodes)
spread = {x = 80, y = 80, z = 80}

-- For current size (1-2 mapchunks, 100-160 nodes) - DEFAULT
spread = {x = 100, y = 100, z = 100}

-- For larger villages (2-3 mapchunks, 160-240 nodes)
spread = {x = 150, y = 150, z = 150}
```

### Smart Doors
Adjust door detection in `villagers/systems/smart_doors.lua`:
```lua
DOOR_CHECK_INTERVAL = 1.0     -- Check for NPCs every second
DOOR_DETECTION_RADIUS = 2.5   -- How close NPCs need to be
DOOR_CLOSE_DELAY = 3          -- Seconds to wait before closing
```

### Village Spawning
Village generation is currently disabled by default. Enable it by uncommenting the `minetest.register_on_generated` section in `villagers/systems/villagers.lua`.

## Usage

### Interacting with Villagers

- **Right-click** - Basic interaction (reduces loneliness)
- **Right-click + Sneak** - Attempt trade with held item
- **Punch with trade item** - Alternative trade method
- **Right-click with food** - Feed the villager

### Taming Villagers

Villagers can be tamed using appropriate items (varies by class):
- Tamed villagers follow you
- They receive mood bonuses
- Can be ordered to follow or stand still
- Can be captured with nets or lassos

### Reading Mood Indicators

Point at the mood indicator sprite above an NPC's head to see:
- Current mood emoji
- Health points
- Hunger level

## Technical Details

### Mood System Architecture

- Updates every 5 seconds for performance
- Persistent data saved with NPCs
- Error handling prevents crashes
- Modular design for easy extension

### Sound System

- 3-node detection radius
- 5-node hearing radius
- Per-NPC sound timers
- Configurable repeat delays
- Positional 3D audio

### File Structure

```
lualore/
├── init.lua                          # Main mod initialization and load order
├── mod.conf                          # Mod metadata and dependencies
├── intllib.lua                       # Internationalization library
├── villagers/                        # All villager and village systems
│   ├── HOW_TO_MODIFY_TRADES.md      # Trading system documentation
│   ├── REPOPULATE_VILLAGERS.md      # Villager spawning guide
│   ├── blocks/                       # Biome-specific decorative blocks
│   │   ├── jungleblocks.lua
│   │   ├── savannablocks.lua
│   │   ├── arcticblocks.lua
│   │   ├── grasslandblocks.lua
│   │   ├── lakeblocks.lua
│   │   └── desertblocks.lua
│   ├── buildings/                    # Biome-specific building generators
│   │   ├── junglebuildings.lua
│   │   ├── savannabuildings.lua
│   │   ├── icebuildings.lua
│   │   ├── grasslandbuildings.lua
│   │   ├── lakebuildings.lua
│   │   └── desertbuildings.lua
│   ├── systems/                      # Core villager and village systems
│   │   ├── npcmood.lua              # Mood and sound system
│   │   ├── villagers.lua            # Villager definitions and behavior
│   │   ├── villager_behaviors.lua   # NPC AI and interaction logic
│   │   ├── house_spawning.lua       # Villager spawn system
│   │   ├── village_noise.lua        # Village generation parameters
│   │   ├── village_commands.lua     # Admin commands
│   │   ├── smart_doors.lua          # Automatic door system
│   │   └── witch_magic.lua          # Witch abilities
│   └── extras/                       # Optional fun content
│       ├── explodingtoad.lua        # Explosive toad entity
│       └── loot.lua                 # Loot tables and drops
├── wizards/                          # Cave wizard system
│   ├── WIZARD_SYSTEM.md             # Wizard documentation
│   ├── cave_wizards.lua             # Wizard entity definitions
│   ├── wizard_magic.lua             # Wizard abilities
│   └── cavebuildings.lua            # Underground structures
├── models/                           # 3D models (.b3d)
├── textures/                         # Textures and sprites
├── sounds/                           # Sound effects (.ogg)
└── schematics/                       # Building structures (.mts)
```

## Credits

This mod builds upon various Luanti modding techniques and community contributions, including code and snippets, and sometimes just good old inspiration, from the following:

- FreeLikeGNU's Witches https://content.luanti.org/packages/FreeLikeGNU/witches
- Shaft's Automatic Door Opening https://content.luanti.org/packages/shaft/auto_door
- Liil's Native Villages https://content.luanti.org/packages/Liil/nativevillages (forked from)
- Bosapara's Emoji https://content.luanti.org/packages/bosapara/emoji

## License

See LICENSE file for details.

## Contributing

Contributions are welcome! Please ensure:
- Code follows existing style conventions
- Test in multiple biomes
- Document new features
- Include translation strings

## Changelog

### Recent Updates
- **Witch Dual-Attack System**: Witches are now hostile monsters with melee punches (within 1 block, 7 damage) and frequent magic teleportation (1-5 blocks, 10 blocks displacement, 2s cooldown)
- Added dynamic sound system with mood-based audio
- Implemented configurable sound repeat delays
- Enhanced NPC interaction feedback
- Improved mood calculation and persistence
- Added visual mood indicators with desires
- Expanded trading system

---

**Note**: This mod is designed for Luanti (the open-source voxel game engine formerly known as Minetest).
