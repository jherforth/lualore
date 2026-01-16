# Valkyrie System Testing Guide

## Quick Test Commands

### Spawn a Valkyrie
```
/spawn_valkyrie blue
/spawn_valkyrie violet
/spawn_valkyrie gold
/spawn_valkyrie green
```

### Get Valkyrie Debug Info
```
/valkyrie_info
```
This shows:
- Distance to nearby Valkyries
- Number of assigned strikes
- Current strike being used
- Strike timer status

### Spawn a Full Sky Village
```
/spawn_skyvillage
```
Spawns 10-15 Sky Folk and 1 random Valkyrie for testing the protection system.

### Spawn Sky Folk
```
/spawn_skyfolk
```

## What to Look For

### Valkyrie Flying Pose
- **Horizontal Flying**: When moving, Valkyries rotate 90 degrees forward (like elytra flight)
- **Body Rotation**: Body tilts horizontal, head counter-rotates to face forward
- **Arms Extended**: Arms spread wide like wings (180 degrees when flying)
- **Idle Pose**: When stationary, Valkyries return to upright stance with slight wing flutter

### Wing Visibility
- Valkyries should have colored wing overlays on their character model
- Wings should be visible in the color matching their type (blue, violet, gold, green)
- Wing particles trail from both sides as they move
- Check the debug.txt log for messages like: "Set Valkyrie texture: [texture]^[wing_texture]"

### Flying Mechanics
- **Horizontal Flight**: Valkyries tilt forward 90° when moving (no more walking on air!)
- **Idle Hover**: Smooth sine-wave bobbing up and down when stationary
- **Wing Flapping**: Arms animate with flapping motion (20° amplitude)
- **Dash Attack**: Glide toward players at 8-25 block range with upward angle
- **Fall Reduction**: 30% reduced fall velocity when dropping

### Strike Usage
- Valkyries use strikes at 4-25 block range from players
- Each Valkyrie has 2 random strikes assigned from the 7 available
- Strikes alternate (Strike 1, then Strike 2, repeat)
- Strike cooldown is 2.5 seconds between uses
- You'll see chat message: "Valkyrie unleashes a strike!"
- Check debug.txt for: "Valkyrie used strike on [player]"

### Strike Effects

**Strike 1: Wind Dash** - Purple particles, knockback 15 blocks, 4-8 damage

**Strike 2: Tempest Spin** - Red whirlwind particles, reverses movement controls for 5 seconds

**Strike 3: Frost Bind** - Green ice particles, freezes player randomly for 1 second over 15 seconds, DoT

**Strike 4: Sky Surge** - White gale particles, 200% speed boost and higher jump for 15 seconds

**Strike 5: Thunder Lift** - Blue lightning particles, launches player upward 10 nodes (fall damage after)

**Strike 6: Storm Compress** - Yellow particles, shrinks player to half size, 50% speed, tunnel vision for 15 seconds

**Strike 7: Shadow Veil** - Black particles, heavily obscures vision for 10 seconds

## Testing Sky Folk Protection

1. Spawn a sky village: `/spawn_skyvillage`
2. Attack a Sky Folk NPC
3. Watch nearby Valkyries become enraged:
   - +50% speed boost
   - +2 melee damage
   - More aggressive pursuit

## Testing Wing Items (Glider System)

### How to Use Wings
1. Kill a Valkyrie to get their wings
2. Right-click to equip the wings
3. **Visible Wings**: A wing entity attaches to your back
4. **Controls**:
   - **Jump**: Ascend (add lift)
   - **Sneak**: Descend faster
   - **WASD**: Control horizontal direction
   - **Mouse**: Look where you want to glide
5. **Flying Pose**: Your character tilts horizontal when moving (like elytra)
6. **Auto-Glide**: Wings provide drag to slow falling

### Wing Types & Stats
- **Green Wings**: 30s duration, 0.8 lift power, 10% speed
- **Blue Wings**: 45s duration, 1.0 lift power, 20% speed
- **Violet Wings**: 45s duration, 1.2 lift power, 35% speed
- **Gold Wings**: 60s duration, 1.5 lift power, 50% speed

### Wing Visual
- Wings attach as a separate entity on your back
- Wings rotate with your flight pose
- Colored particles trail behind you
- Wings disappear when timer expires

## Troubleshooting

### Valkyrie Wings Not Visible
- Check that texture files exist: `blue_valkyrie_wings.png`, `violet_valkyrie_wings.png`, etc.
- Look in debug.txt for texture loading errors
- Verify texture overlay is working: texture should be "base^wings"

### Player Wings Not Rendering
- Wings should appear as a separate attached entity
- Check debug.txt for "lualore:wing_visual" entity creation
- Try re-equipping wings
- Make sure you haven't hit the entity limit

### Valkyries Not Flying Horizontally
- Look for arm/body bone position calls in debug output
- Verify `is_moving` detection is working (velocity > 0.5)
- Arms should be at ±180° when flying, ±10° when idle
- Body should be at 90° X rotation when flying

### Strikes Not Firing
- Use `/valkyrie_info` to check strike count (should be 2)
- Verify you're in range (4-25 blocks)
- Check debug.txt for:
  - "Assigned strikes: X and Y" on spawn
  - "Attempting strike N at distance D" when trying
  - "Strike function is nil" (indicates bug)
  - "Valkyrie successfully used strike" (working correctly)
- Strike timer now accumulates continuously (not reset by distance)
- Cooldown between strikes is 2.5 seconds

### Not Flying Properly
- Valkyries have `fly = true` and `fly_in = {"air"}`
- Hover mechanics use sine wave for vertical bobbing
- Bone animations move arms for wing flapping effect
- Check that they're not stuck on terrain

## Performance Notes

- Wing particles spawn every 0.1 seconds while flying
- Strike particles vary by effect (20-200 particles)
- Multiple Valkyries can strain servers - test with 1-2 first
- Hover calculation runs every frame in do_custom
