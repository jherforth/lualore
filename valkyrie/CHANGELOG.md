# Valkyrie System Changelog

## Latest Update - Horizontal Flight & Improved Wings

### Valkyrie Flying Improvements

#### Horizontal Flight Pose (Like Minecraft Elytra)
- **Body Rotation**: Valkyries now rotate 90° forward when moving
- **Head Counter-Rotation**: Head rotates -90° to keep facing forward
- **Arm Extension**: Arms spread to ±180° when flying (wings extended)
- **Idle Stance**: Returns to normal upright pose when stationary
- **Dynamic Switching**: Automatically switches between flying and idle poses based on velocity

#### Fixed Arm Positioning
- Arms no longer clip into head
- Proper offset positioning: `{x=±3, y=6.3, z=1}`
- Wing flapping animation uses 20° amplitude
- Different angles for flying vs idle (180° vs 10°)

### Player Wing System Overhaul

#### Visual Wing Attachment
- **Separate Entity**: Wings now render as an attached entity on player's back
- **Proper Visibility**: Wings are actually visible (not just texture overlay)
- **Auto-Cleanup**: Wings automatically remove when expired or player dies
- **Position**: Attached at `{x=0, y=5, z=-2}` behind player

#### Glider-Style Flight Mechanics
Inspired by hangglider mod but with ascent capability:

**Controls:**
- **Jump**: Provides lift (ascend)
- **Sneak**: Faster descent
- **WASD**: Directional movement
- **Mouse Look**: Control glide direction

**Physics:**
- **Lift Power**: Each wing type has different lift (0.8 to 1.5)
- **Auto-Glide**: Drag reduces fall speed by 30%
- **Speed Multiplier**: Horizontal movement boost (1.1x to 1.5x)
- **Horizontal Flight Pose**: Player rotates 90° forward when moving

**Wing Stats:**
- Green: 30s, 0.8 lift, 1.1x speed
- Blue: 45s, 1.0 lift, 1.2x speed
- Violet: 45s, 1.2 lift, 1.35x speed
- Gold: 60s, 1.5 lift, 1.5x speed

### Strike System Improvements

#### Enhanced Debugging
- **Strike Assignment Logging**: Logs which strikes (1-7) are assigned on spawn
- **Function Type Validation**: Verifies strikes are actual functions
- **Attempt Logging**: Logs every strike attempt with distance
- **Success/Failure Tracking**: Clear logs for successful strikes vs cooldown failures

#### Fixed Strike Triggering
- **Continuous Timer**: Strike timer now accumulates continuously (not reset by distance)
- **Better Range Check**: Strikes trigger at 4-25 block range
- **Function Validation**: Checks if strike function exists and is valid before calling
- **Auto-Reassignment**: If strikes are missing, automatically assigns new ones

#### Improved Strike Cooldown
- Per-strike cooldown tracking (not global)
- 2.5 second cooldown per strike
- Better feedback to players when struck

### Debug Commands Enhanced

#### `/valkyrie_info` Improvements
- Shows distance to Valkyrie
- Displays number of assigned strikes (should be 2)
- Shows current strike index
- Displays strike timer value

#### `/spawn_valkyrie` Improvements
- Reports number of strikes assigned on spawn
- Logs strike count to debug.txt
- Better error messages

### Testing Guide Updates
- Added horizontal flight testing instructions
- Documented new wing controls
- Added troubleshooting for bone positioning
- Enhanced strike debugging steps
- Wing attachment troubleshooting

## Technical Changes

### Bone Positions
```lua
-- Flying (moving):
Body:  {x=0, y=6.3, z=0}, rotation {x=90, y=0, z=0}
Head:  {x=0, y=6.3, z=0}, rotation {x=-90, y=0, z=0}
Arms:  {x=±3, y=6.3, z=1}, rotation {x=0, y=0, z=±(180+wing_angle)}

-- Idle (stationary):
Body:  {x=0, y=6.3, z=0}, rotation {x=0, y=0, z=0}
Head:  {x=0, y=6.3, z=0}, rotation {x=0, y=0, z=0}
Arms:  {x=±3, y=6.3, z=1}, rotation {x=0, y=0, z=±(10+wing_angle)}
```

### Wing Entity
```lua
entity_name: "lualore:wing_visual"
mesh: "character.b3d"
attachment_offset: {x=0, y=5, z=-2}
properties: {physical=false, pointable=false, immortal}
```

### Movement Detection
```lua
is_moving = velocity.x > 0.5 OR velocity.z > 0.5 OR velocity.y > 0.5
```

## Known Issues & Future Improvements

### Current Limitations
- Wing entity uses character.b3d mesh (may need custom wing mesh)
- Wing attachment position may need fine-tuning per texture
- Strike cooldown is per-function reference (works but could be cleaner)

### Potential Enhancements
- Add wing flapping animation to wing entity
- Custom wing mesh model for better visuals
- Stamina system for sustained flight
- Wind effects while flying
- More strike variety (currently 7)
