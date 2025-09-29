# AudioService Implementation Guide

This document explains how AudioService is implemented and used in the example scenes, serving as a practical guide for integrating audio into your own projects.

## Overview

AudioService is a comprehensive audio management system that provides:
- **Bus/Mixer Control** - Volume and mute management for Master, Music, SFX, and UI buses
- **Sound Library** - Centralized registration and playback of audio assets
- **SFX Pools** - Efficient 2D, 3D, and UI sound effect management
- **Music Crossfade** - Smooth transitions between music tracks
- **Audio Ducking** - Automatic music volume reduction during SFX/UI playback
- **SaveService Integration** - Persistent volume and mute settings

## Quick Start

### 1. Setup AudioService as Autoload

In your project settings, add AudioService as an autoload singleton:
```
AudioService → res://AudioService/AudioService.gd
```

### 2. Initialize Audio Assets

Audio initialization typically happens in your main level or bootstrap scene:

```gdscript
# Example from LevelDemo.gd
func _initialize_audio() -> void:
    if AudioService.is_initialized():
        return
        
    # Bulk load audio files from directory
    var results := AudioService.load_sounds_from_directory(
        "res://audio/sfx/",           # Directory path
        ["ogg", "wav", "mp3"],       # File extensions
        "sfx_",                      # Sound ID prefix
        AudioService.BUS_SFX,        # Default bus
        "SFX",                       # Default kind
        false                        # Not recursive
    )
    
    # Register specific sounds with custom settings
    AudioService.register_sound("theme", 
        load("res://audio/theme.ogg"), 
        AudioService.BUS_MUSIC, 
        "MUSIC"
    )
    
    # Mark initialization complete
    AudioService.mark_initialized()
```

### 3. Play Audio

```gdscript
# Music with crossfade
AudioService.play_music_by_id("theme", 1.5, true)  # fade 1.5s, looped

# 2D SFX at position
AudioService.play_sfx("explosion", {"pos": Vector2(100, 100), "vol_db": -3})

# 3D SFX at node
AudioService.play_at_node3d("footstep", player_node)

# UI sounds
AudioService.play_ui("click")

# Random sound from group
var hit_sounds = ["hit1", "hit2", "hit3"]
AudioService.play_random_sound(hit_sounds, {"vol_db": -5.0})
```

## Implementation Patterns

### Audio Initialization

**Pattern 1: Bulk Loading**
```gdscript
# Load all audio files from a directory
AudioService.load_sounds_from_directory(
    "res://audio/sfx/",
    ["ogg", "wav"],
    "sfx_",
    AudioService.BUS_SFX,
    "SFX"
)
```

**Pattern 2: Configuration-Based Loading**
```gdscript
var config = {
    "directory": "res://audio/",
    "sounds": {
        "theme": {"file": "theme.ogg", "bus": "Music", "kind": "MUSIC"},
        "click": {"file": "click.ogg", "bus": "UI", "kind": "UI"},
        "explosion": {"file": "explosion.ogg", "bus": "SFX", "kind": "SFX"}
    }
}
AudioService.load_sounds_from_config(config)
```

**Pattern 3: Individual Registration**
```gdscript
AudioService.register_sound("jump", load("res://audio/jump.ogg"))
AudioService.register_sound("land", load("res://audio/land.ogg"))
```

### Volume Control

**Direct Bus Control:**
```gdscript
AudioService.set_bus_volume_db(AudioService.BUS_MASTER, -6.0)
AudioService.set_bus_mute(AudioService.BUS_MUSIC, true)
```

**Convenience Methods:**
```gdscript
AudioService.set_master_volume(-6.0)
AudioService.set_music_volume(-3.0)
AudioService.set_sfx_volume(-2.0)
AudioService.set_ui_volume(-1.0)
```

### Spatial Audio

**2D Positional Audio:**
```gdscript
# At specific position
AudioService.play_at_position2d("explosion", Vector2(100, 200))

# At node position
AudioService.play_at_node2d("footstep", player_node)
```

**3D Positional Audio:**
```gdscript
# At specific position
AudioService.play_at_position3d("explosion", Vector3(0, 0, 0))

# At node position
AudioService.play_at_node3d("footstep", player_node)
```

## Example Scene Implementation

### LevelDemo.gd - Main Level Integration

The main level handles audio initialization and provides audio methods for other systems:

```gdscript
class_name LevelDemo extends Node2D

# Audio configuration
const SAMPLE_AUDIO_PATH = "res://AudioService/sample-audio/"
const MUSIC_TRACK = "sample-track.mp3"
const HIT_SOUNDS = ["Hit_1.wav", "Hit_2.wav", "Hit_3.wav"]

var _hit_sound_group: Array[StringName] = []

func _ready() -> void:
    _initialize_audio()
    _start_background_music()

func _initialize_audio() -> void:
    # Bulk load SFX files
    var results := AudioService.load_sounds_from_directory(
        SAMPLE_AUDIO_PATH,
        ["mp3", "wav"],
        "demo_",
        AudioService.BUS_SFX,
        "SFX",
        false
    )
    
    # Register music separately
    var music_stream = load(SAMPLE_AUDIO_PATH + MUSIC_TRACK)
    AudioService.register_sound("demo_music", music_stream, AudioService.BUS_MUSIC, "MUSIC")
    
    # Build sound groups for random selection
    for hit_sound in HIT_SOUNDS:
        _hit_sound_group.append("demo_" + hit_sound.get_basename())
    
    AudioService.mark_initialized()

func _start_background_music() -> void:
    AudioService.play_music_by_id("demo_music", 1.0, true)

# Provide audio methods for other systems
func play_random_hit() -> void:
    AudioService.play_random_sound(_hit_sound_group, {"vol_db": -5.0}, "sfx")
```

### PauseMenuDemo.gd - UI Integration

The pause menu handles volume controls directly with AudioService:

```gdscript
func _show_settings_menu() -> void:
    # Get current volumes directly from AudioService
    var master_db: float = AudioService.get_master_volume()
    var music_db: float = AudioService.get_music_volume()
    
    # Create volume sliders with current values
    # ... UI setup code ...

func _on_settings_dialog_event(event_id: StringName, payload: Dictionary) -> void:
    match event_id:
        StringName("master_volume"):
            var db: float = _slider_to_db(payload.get("value", 0.5))
            AudioService.set_master_volume(db)
        StringName("music_volume"):
            var db: float = _slider_to_db(payload.get("value", 0.5))
            AudioService.set_music_volume(db)
```

### PlayerStateAttack.gd - Gameplay Integration

Gameplay systems can access audio through the level or directly:

```gdscript
func _play_attack_sound() -> void:
    # Option 1: Through level (for level-specific sounds)
    var level_demo = _find_level_demo()
    if level_demo != null:
        level_demo.play_random_hit()
    
    # Option 2: Direct AudioService call (for global sounds)
    # AudioService.play_sfx("attack", {"vol_db": -3.0})
```

## Best Practices

### 1. Initialization Timing
- Initialize audio early in your main scene's `_ready()` function
- Use `AudioService.is_initialized()` to prevent duplicate initialization
- Call `AudioService.mark_initialized()` when setup is complete

### 2. Sound Organization
- Use consistent naming conventions (e.g., `sfx_explosion`, `ui_click`)
- Group related sounds with prefixes
- Use the `kind` parameter for categorization

### 3. Volume Management
- Use convenience methods for common volume changes
- Implement volume controls in your settings UI
- Leverage SaveService integration for persistent settings

### 4. Spatial Audio
- Use 2D audio for UI and screen-space effects
- Use 3D audio for world-space effects
- Attach audio to nodes for automatic position updates

### 5. Performance
- Use bulk loading for large audio libraries
- Leverage SFX pools for frequently played sounds
- Use random sound selection for variety

## Configuration Options

### Ducking Settings
```gdscript
AudioService.duck_enabled = true
AudioService.duck_amount_db = -8.0
AudioService.duck_attack_s = 0.04
AudioService.duck_hold_s = 0.20
AudioService.duck_release_s = 0.35
```

### Pool Sizes
```gdscript
AudioService.sfx2d_initial_size = 12
AudioService.sfx3d_initial_size = 12
AudioService.ui_initial_size = 6
AudioService.sfx2d_max_size = 48
AudioService.sfx3d_max_size = 48
AudioService.ui_max_size = 24
```

### Music Settings
```gdscript
AudioService.music_crossfade_seconds = 1.25
AudioService.music_loop_default = true
```

## EventBus Integration

AudioService automatically publishes events when `mirror_to_eventbus` is enabled:

```gdscript
# Subscribe to audio events
EventBus.sub(EventTopics.AUDIO_VOLUME_SET, _on_volume_changed)
EventBus.sub(EventTopics.AUDIO_MUTE_SET, _on_mute_changed)
EventBus.sub(EventTopics.AUDIO_SFX_PLAY, _on_sfx_played)

func _on_volume_changed(data: Dictionary) -> void:
    print("Volume changed: ", data.bus, " = ", data.db, " dB")

func _on_sfx_played(data: Dictionary) -> void:
    print("SFX played: ", data.id, " (", data.kind, ")")
```

## Troubleshooting

### Common Issues

**Sounds not playing:**
- Check if AudioService is initialized
- Verify sound IDs are registered
- Check bus volumes and mute states

**Volume not persisting:**
- Ensure SaveService is configured as autoload
- Check save/load priority settings

**Spatial audio not working:**
- Verify 3D audio settings in project
- Check listener positioning
- Ensure proper bus routing

### Debug Information

```gdscript
# Check initialization status
print("AudioService initialized: ", AudioService.is_initialized())

# Check registered sounds
print("Has sound 'explosion': ", AudioService.has_sound("explosion"))

# Check bus states
print("Master volume: ", AudioService.get_master_volume(), " dB")
print("Music muted: ", AudioService.is_music_muted())
```

## Migration from AudioDemo

If you were previously using AudioDemo, here's how to migrate:

**Before (AudioDemo):**
```gdscript
var audio_demo = AudioDemo.new()
add_child(audio_demo)
audio_demo.start_music()
audio_demo.play_random_hit()
```

**After (Direct AudioService):**
```gdscript
# Initialize audio in your level
_initialize_audio()

# Play music directly
AudioService.play_music_by_id("theme", 1.0, true)

# Play random sounds
AudioService.play_random_sound(hit_sounds, {"vol_db": -5.0})
```

This approach provides better separation of concerns and eliminates unnecessary wrapper classes while maintaining all functionality.
