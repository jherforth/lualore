# Lua Lore

A villager and lore mod for Luanti that adds living villages across multiple biomes with NPCs that have moods, trades, and unique behaviors. Explore floating sky cities, discover underground wizard castles, and interact with diverse communities.

## Features

### 🏘️ Biome Villages

Villages generate naturally in six distinct biomes:

- **Grassland** - Farming communities with traditional architecture
- **Desert** - Oasis settlements with markets and exotic trades
- **Savanna** - Tribal villages with ceremonial shrines
- **Lake** - Fishing communities built near water
- **Ice** - Hardy settlements in frozen tundra
- **Jungle** - Tribal communities with unique customs

### 👥 Villager Types

Villages are populated with different NPCs, each with their own trades and behaviors:

- **Farmers** - Trade crops and food
- **Blacksmiths** - Trade tools and weapons
- **Jewelers** - Trade gems and metals
- **Fishermen** - Trade fish and aquatic items
- **Clerics** - Trade mystical items
- **Rangers** - Protect villages from monsters
- **Entertainers** - Add atmosphere to villages
- **Witches** - Hostile magic users with teleportation abilities
- **Raiders & Hostile NPCs** - Dangerous enemies

### 🎭 Villager Moods

NPCs have emotions that affect their behavior. They display mood icons above their heads and make sounds based on how they feel. Villagers can be happy, content, neutral, sad, angry, hungry, lonely, or scared.

Feed them bread or apples to keep them happy, and trade with them to reduce their loneliness.

### 💱 Trading

Hold an item a villager wants and approach them. They'll show a trade icon when interested. Right-click while sneaking or punch with the trade item to complete the trade.

### 🧙 Cave Wizards

Deep underground in rare cave castles, you'll find powerful wizards of four colors:

- **Black Wizards** - Wield dark magic
- **White Wizards** - Channel pure energy
- **Red Wizards** - Command fire magic
- **Gold Wizards** - Master precious magic

Defeat them to obtain their magical wands, which grant you powerful abilities. Each wand type has unique magical properties for combat and exploration.

### 🛡️ Valkyries & Sky Folk

High above the clouds, floating sky villages hold an ancient secret. Valkyries of four colors guard imprisoned Sky Folk:

- **Blue Valkyries**
- **Green Valkyries**
- **Violet Valkyries**
- **Gold Valkyries**

Defeat the Valkyries to free the Sky Folk. Once liberated, they'll mark the location of other captive Sky Folk with magical pins and send you on quests to free their companions. Free enough Sky Folk and earn special rewards.

### 🏗️ Village Buildings

Each biome has unique structures including houses, churches, markets, stables, shrines, and special decorative elements. Villages generate naturally and feature authentic architecture for their environment.

### 🚪 Smart Doors

Village doors automatically open when NPCs approach and close after they pass through.

## Installation

1. Download or clone this repository
2. Place the folder in your Luanti mods directory
3. Enable the mod in your world settings

## Dependencies

- **mobs** (mobs_redo), **default**, **farming**, **3d_armour** - Required
- **caverealms**, **everness**, **ethereal** - Required for biome support
- **intllib** - Optional (for translations)
- **OR** play on an **Asuna**, which includes all dependencies

## Usage

- **Right-click** - Interact with villagers
- **Right-click + Sneak** - Trade with held item
- **Right-click with food** - Feed villagers
- Some villagers can be tamed and will follow you

## File Structure

```
lualore/
├── init.lua                          # Main mod initialization
├── mod.conf                          # Mod metadata and dependencies
├── intllib.lua                       # Internationalization support
├── villagers/                        # Villager and village systems
│   ├── HOW_TO_MODIFY_TRADES.md      # Trading documentation
│   ├── REPOPULATE_VILLAGERS.md      # Spawning guide
│   ├── blocks/                       # Biome-specific decorative blocks
│   │   ├── arcticblocks.lua
│   │   ├── desertblocks.lua
│   │   ├── grasslandblocks.lua
│   │   ├── jungleblocks.lua
│   │   ├── lakeblocks.lua
│   │   └── savannablocks.lua
│   ├── buildings/                    # Biome-specific structures
│   │   ├── desertbuildings.lua
│   │   ├── grasslandbuildings.lua
│   │   ├── icebuildings.lua
│   │   ├── junglebuildings.lua
│   │   ├── lakebuildings.lua
│   │   └── savannabuildings.lua
│   ├── systems/                      # Core systems
│   │   ├── house_spawning.lua       # Villager spawning
│   │   ├── npcmood.lua              # Mood and emotions
│   │   ├── smart_doors.lua          # Automatic doors
│   │   ├── village_commands.lua     # Admin commands
│   │   ├── village_noise.lua        # Generation settings
│   │   ├── villager_behaviors.lua   # AI and interactions
│   │   ├── villagers.lua            # Villager definitions
│   │   └── witch_magic.lua          # Witch abilities
│   └── extras/                       # Additional content
│       ├── explodingtoad.lua
│       └── loot.lua
├── wizards/                          # Underground wizard system
│   ├── WIZARD_SYSTEM.md
│   ├── cave_wizards.lua             # Wizard entities
│   ├── cavebuildings.lua            # Cave castles
│   ├── wizard_magic.lua             # Wizard abilities
│   └── wizard_wands.lua             # Magical wands
├── valkyrie/                         # Sky realm system
│   ├── CHANGELOG.md
│   ├── LIBERATION_SYSTEM.md
│   ├── SKY_FOLK.md
│   ├── TESTING_GUIDE.md
│   ├── VALKYRIE_SYSTEM.md
│   ├── floating_buildings.lua       # Sky structures
│   ├── sky_blocks.lua               # Sky materials
│   ├── sky_folk.lua                 # Sky folk entities
│   ├── sky_folk_compass.lua         # Navigation tool
│   ├── sky_folk_mood.lua            # Sky folk emotions
│   ├── sky_folk_pins.lua            # Location markers
│   ├── sky_folk_quests.lua          # Quest system
│   ├── sky_folk_tracker.lua         # Liberation tracking
│   ├── sky_liberation.lua           # Liberation mechanics
│   ├── sky_valkyries.lua            # Valkyrie entities
│   ├── sky_villages.lua             # Sky village generation
│   ├── valkyrie_chest.lua           # Reward system
│   └── valkyrie_strikes.lua         # Combat system
├── models/                           # 3D models (.b3d, .obj)
├── textures/                         # Textures and sprites
├── sounds/                           # Sound effects (.ogg)
└── schematics/                       # Building schematics (.mts)
```

## Credits

Built upon contributions from the Luanti modding community:

- FreeLikeGNU's Witches
- Shaft's Automatic Door Opening
- Liil's Native Villages (forked from)
- Bosapara's Emoji

## License

See LICENSE file for details.

## Contributing

Contributions are welcome! Please follow existing code conventions, test in multiple biomes, and document new features.

---

**Note**: This mod is designed for Luanti (formerly Minetest).
