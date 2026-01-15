# How to Modify Villager Trade Items

## Where Trade Items Are Defined

Trade items are defined in **TWO locations** and both must match:

### 1. `villagers.lua` (lines 43-223) - For NEW villagers

This controls what newly spawned villagers will accept.

**Location**: `/villagers.lua`

**Example**:
```lua
farmer = {
    type = "npc",
    passive = true,
    damage = 3,
    hp_min = 40,
    hp_max = 70,
    armor = 100,
    attack_type = "dogfight",
    attacks_monsters = false,
    attack_npcs = false,
    reach = 1,
    drops = {
        {name = "farming:wheat", chance = 1, min = 0, max = 2},
        {name = "farming:bread", chance = 1, min = 0, max = 1}
    },
    trade_items = {"farming:bread", "farming:wheat"},  ⬅️ EDIT HERE
},
```

### 2. `npcmood.lua` (lines 130-139) - For EXISTING villagers

This is the fallback for villagers already in the world.

**Location**: `/npcmood.lua`

**Example**:
```lua
local class_trade_items = {
    farmer = {"farming:bread", "farming:wheat"},  ⬅️ EDIT HERE
    blacksmith = {"default:iron_lump", "default:coal_lump"},
    jeweler = {"default:gold_lump"},
    fisherman = {"nativevillages:catfish_cooked", "nativevillages:catfish_raw"},
    ranger = {"farming:bread", "default:apple"},
    cleric = {"default:mese_crystal"},
    entertainer = {"default:gold_lump"},
    witch = {"nativevillages:driedhumanmeat", "default:mese_crystal_fragment"},
}
```

---

## Current Trade Items (Default)

| Villager Class | Accepts Items |
|----------------|---------------|
| Farmer | `farming:bread`, `farming:wheat` |
| Blacksmith | `default:iron_lump`, `default:coal_lump` |
| Jeweler | `default:gold_lump` |
| Fisherman | `nativevillages:catfish_raw`, `nativevillages:catfish_cooked` |
| Ranger | `farming:bread`, `default:apple` |
| Cleric | `default:mese_crystal_fragment` |
| Entertainer | `default:gold_lump` |
| Witch | `nativevillages:driedhumanmeat`, `default:mese_crystal_fragment` |
| Bum | (none - no trading) |
| Hostile | (none - no trading) |
| Raider | (none - no trading) |

---

## How to Modify Trade Items

### Example: Make Farmers Accept Apples

**Step 1: Edit `villagers.lua`** (line ~123)

Find the farmer definition:
```lua
farmer = {
    -- ... other properties ...
    trade_items = {"farming:bread", "farming:wheat"},
},
```

Change to:
```lua
farmer = {
    -- ... other properties ...
    trade_items = {"farming:bread", "farming:wheat", "default:apple"},
},
```

**Step 2: Edit `npcmood.lua`** (line ~131)

Find the class_trade_items table:
```lua
local class_trade_items = {
    farmer = {"farming:bread", "farming:wheat"},
    -- ... other classes ...
}
```

Change to:
```lua
local class_trade_items = {
    farmer = {"farming:bread", "farming:wheat", "default:apple"},
    -- ... other classes ...
}
```

**Step 3: Restart server or reload mod**

New farmers AND existing farmers will now accept apples!

---

## How to Add a New Item Type

### Example: Add Diamonds to Jeweler

**villagers.lua** (line ~106):
```lua
jeweler = {
    -- ... other properties ...
    trade_items = {"default:gold_lump", "default:diamond"},
},
```

**npcmood.lua** (line ~133):
```lua
local class_trade_items = {
    -- ... other classes ...
    jeweler = {"default:gold_lump", "default:diamond"},
    -- ... other classes ...
}
```

Now jewelers will accept both gold lumps and diamonds!

---

## How to Make a Non-Trader Accept Items

### Example: Make Bums Accept Bread

Currently bums have empty trade_items:

**villagers.lua** (line ~178):
```lua
bum = {
    -- ... other properties ...
    trade_items = {},  ⬅️ Empty!
},
```

Change to:
```lua
bum = {
    -- ... other properties ...
    trade_items = {"farming:bread"},
},
```

**npcmood.lua** (line 130-139):

Add bum to the fallback table:
```lua
local class_trade_items = {
    farmer = {"farming:bread", "farming:wheat"},
    blacksmith = {"default:iron_lump", "default:coal_lump"},
    jeweler = {"default:gold_lump"},
    fisherman = {"nativevillages:catfish_cooked", "nativevillages:catfish_raw"},
    ranger = {"farming:bread", "default:apple"},
    cleric = {"default:mese_crystal"},
    entertainer = {"default:gold_lump"},
    witch = {"nativevillages:driedhumanmeat", "default:mese_crystal_fragment"},
    bum = {"farming:bread"},  ⬅️ ADD THIS LINE
}
```

Now bums will accept bread!

---

## How to Stop a Trader from Trading

### Example: Make Jewelers Not Accept Gold

**villagers.lua** (line ~106):
```lua
jeweler = {
    -- ... other properties ...
    trade_items = {},  ⬅️ Make it empty
},
```

**npcmood.lua** (line ~133):

Either remove jeweler from the list or set it empty:
```lua
local class_trade_items = {
    farmer = {"farming:bread", "farming:wheat"},
    blacksmith = {"default:iron_lump", "default:coal_lump"},
    jeweler = {},  ⬅️ Empty list
    -- ... or just remove this line entirely
}
```

Now jewelers won't show trade desire for any items!

---

## Testing Your Changes

### After Editing:

1. **Restart your server** (or `/reload` if supported)
2. **Find the villager type you modified**
3. **Hold the new item** you added
4. **Stand within 4 blocks** of the villager
5. **Wait 5 seconds** (mood update cycle)
6. **Check debug.txt** for:
   ```
   [npcmood] Player holding: default:apple
   [npcmood] NPC trade items: farming:bread, farming:wheat, default:apple
   [npcmood] TRADE MATCH! default:apple == default:apple
   ```
7. **Villager should show trade emotion** (icon above head)

### Testing Existing Villagers:

The fallback system will automatically update existing villagers when you approach them with an item. You'll see in debug.txt:
```
[npcmood] NPC has no nv_trade_items, mob name: nativevillages:grassland_farmer
[npcmood] Detected class: farmer
[npcmood] Set trade items from class: farming:bread, farming:wheat, default:apple
```

---

## Common Item Names

Here are common Minetest item names you might want to use:

### Food Items
- `farming:bread`
- `farming:wheat`
- `default:apple`
- `farming:seed_wheat`
- `farming:carrot`
- `farming:potato`

### Raw Materials
- `default:iron_lump`
- `default:coal_lump`
- `default:gold_lump`
- `default:copper_lump`
- `default:tin_lump`
- `default:diamond`

### Crafted Items
- `default:steel_ingot`
- `default:gold_ingot`
- `default:bronze_ingot`

### Special Items
- `default:mese_crystal`
- `default:mese_crystal_fragment`
- `default:obsidian_shard`

### Mod-Specific Items (from this mod)
- `nativevillages:catfish_raw`
- `nativevillages:catfish_cooked`
- `nativevillages:driedhumanmeat`
- `nativevillages:chicken_raw`
- `nativevillages:chicken_cooked`

---

## Important Notes

### ⚠️ Both Locations Must Match!

Always edit BOTH files:
- `villagers.lua` - for new villagers
- `npcmood.lua` - for existing villagers

If they don't match, you'll have inconsistent behavior!

### ⚠️ Lua Syntax

Make sure to use proper Lua syntax:
```lua
trade_items = {"item1", "item2", "item3"},  ⬅️ Note the comma at end!
```

Common mistakes:
- ❌ `trade_items = {item1, item2}` (missing quotes)
- ❌ `trade_items = {"item1" "item2"}` (missing comma)
- ✅ `trade_items = {"item1", "item2"}` (correct!)

### ⚠️ Server Restart Required

After editing, you must:
- Restart your server, OR
- Use `/reload` command (if available), OR
- Use `/clearobjects` to remove old villagers (drastic!)

Changes won't apply to already-loaded villagers until they're unloaded and reloaded.

---

## Quick Reference Table

| File | Line Range | Purpose |
|------|------------|---------|
| `villagers.lua` | 43-223 | Defines trade items for NEW villagers |
| `npcmood.lua` | 130-139 | Fallback for EXISTING villagers |

**Remember**: Edit both files and restart server for changes to take effect!

---

## Summary

To modify what items villagers accept:

1. ✅ Edit `villagers.lua` (line ~43-223) - find the class, change `trade_items = {...}`
2. ✅ Edit `npcmood.lua` (line ~130-139) - find the class in fallback table
3. ✅ Keep both lists identical
4. ✅ Restart server
5. ✅ Test with existing and new villagers

Both new and existing villagers will use your updated trade items!
