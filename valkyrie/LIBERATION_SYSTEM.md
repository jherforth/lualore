# Sky Folk Liberation System

## Overview
When all Valkyries in an area (50 block radius) are defeated, the Sky Folk are liberated from their control.

## Features

### 1. Liberation Detection
- Triggers when the last Valkyrie in an area dies
- Checks a 50-block radius for remaining Valkyries
- Only activates if Sky Folk are present and not already liberated

### 2. Victory Music
- Plays "Skyforge Valkyrie.mp3" when liberation occurs
- Music has a 1-hour cooldown to prevent spam
- All players within 100 blocks can hear the triumphant music

### 3. Sky Folk Transformation
When liberated, each Sky Folk NPC:
- Changes from `type = "monster"` to `type = "npc"`
- Becomes peaceful (stops attacking players)
- Texture changes from `sky_folk.png` to `sky_folk_freed.png`
- Spawns golden particle burst effects
- Liberation state persists across server restarts

### 4. Visual Effects
Each freed Sky Folk displays:
- 100 golden star particles rising upward
- 50 white circular particles
- Bright glowing effects (glow level 12-14)
- 2-4 second particle duration

### 5. Player Notifications
Players in the area receive chat messages:
- "The Valkyries have been defeated! The Sky Folk are free!" (with music)
- "The Sky Folk are free!" (when music is on cooldown)

## Technical Details
- Uses mod_storage to track music cooldown timer
- Liberation state is serialized and saved with each Sky Folk entity
- 0.5 second delay after Valkyrie death before checking (allows cleanup)
- Music cooldown: 3600 seconds (1 hour)

## Usage
The system works automatically. Simply defeat all Valkyries in an area to liberate the Sky Folk!
