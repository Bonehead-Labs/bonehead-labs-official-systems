# SaveService - Comprehensive Save System for Godot 4

A robust, feature-complete save system for Godot 4 that handles profiles, serialization, validation, auto-save, checkpoints, and more.

> **Note**: The main SaveService class is named `_SaveService` to avoid conflicts when used as an autoload. The ISaveable interface is named `_ISaveable` for the same reason. These are implementation details - you'll access the service through the `SaveService` autoload.

## Features

- ✅ **Profile Management** - Multiple save profiles with validation
- ✅ **ISaveable Interface** - Clean interface for saveable objects
- ✅ **Serialization/Deserialization** - Automatic JSON-based save/load
- ✅ **Save Pipeline** - Robust save operations with error handling
- ✅ **Load Pipeline** - Safe load operations with validation
- ✅ **Auto-Save & Checkpoints** - Automatic saving and checkpoint system
- ✅ **Strict Mode / Validation** - Optional strict validation for data integrity
- ✅ **Singleton Autoload** - Ready to use as a global service

## Quick Start

### 1. Setup (Already Done)

The SaveService is already configured as a singleton autoload in `project.godot`. It's available globally as `SaveService`.

### 2. Create a Saveable Object

Implement the `_ISaveable` interface in your classes (or just implement the required methods):

```gdscript
class_name MyGameData
extends Node

# Your game data
var player_name: String = "Player"
var level: int = 1
var score: int = 0

# ISaveable implementation
func save_data() -> Dictionary:
    return {
        "player_name": player_name,
        "level": level,
        "score": score
    }

func load_data(data: Dictionary) -> bool:
    player_name = data.get("player_name", "Player")
    level = data.get("level", 1)
    score = data.get("score", 0)
    return true

func get_save_id() -> String:
    return "game_data"

func get_save_priority() -> int:
    return 10  # Lower numbers save first

func _ready():
    # Register with SaveService
    SaveService.register_saveable(self)
```

### 3. Basic Usage

```gdscript
# Set up a profile
SaveService.set_current_profile("player1")

# Save the game
SaveService.save_game("my_save")

# Load the game
SaveService.load_game("my_save")

# Check if a save exists
if SaveService.has_save("my_save"):
    SaveService.load_game("my_save")
```

## API Reference

### Profile Management

```gdscript
# Create/switch to a profile
SaveService.set_current_profile("profile_name") -> bool

# Get current profile
SaveService.get_current_profile() -> String

# List all profiles
SaveService.list_profiles() -> PackedStringArray

# Delete a profile (cannot delete active profile)
SaveService.delete_profile("profile_name") -> bool
```

### Saveable Registration

```gdscript
# Register an object that implements ISaveable
SaveService.register_saveable(saveable: ISaveable)

# Unregister an object
SaveService.unregister_saveable(saveable: ISaveable)

# Get all registered saveables
SaveService.get_registered_saveables() -> Array[ISaveable]
```

### Save/Load Operations

```gdscript
# Save game to a specific save slot
SaveService.save_game("save_name") -> bool

# Load game from a save slot
SaveService.load_game("save_name") -> bool

# Check if a save exists
SaveService.has_save("save_name") -> bool

# List all saves in current profile
SaveService.list_saves() -> PackedStringArray

# Delete a save
SaveService.delete_save("save_name") -> bool
```

### Checkpoints

```gdscript
# Create a checkpoint
SaveService.create_checkpoint("checkpoint_name") -> bool

# Load a checkpoint
SaveService.load_checkpoint("checkpoint_name") -> bool

# List checkpoints
SaveService.list_checkpoints() -> PackedStringArray
```

### Auto-Save Configuration

```gdscript
# Enable/disable auto-save
SaveService.enable_auto_save(true)

# Set auto-save interval (seconds)
SaveService.set_auto_save_interval(300.0)  # 5 minutes

# Set maximum number of checkpoints to keep
SaveService.set_max_checkpoints(10)
```

### Configuration

```gdscript
# Enable/disable strict mode
SaveService.set_strict_mode(true)

# Get system statistics
var stats = SaveService.get_save_statistics()
```

## Signals

Connect to these signals for feedback and custom behavior:

```gdscript
# Profile management
SaveService.profile_changed.connect(_on_profile_changed)

# Save/Load operations
SaveService.before_save.connect(_on_before_save)
SaveService.after_save.connect(_on_after_save)
SaveService.before_load.connect(_on_before_load)
SaveService.after_load.connect(_on_after_load)

# Auto-save and checkpoints
SaveService.autosave_triggered.connect(_on_autosave)
SaveService.checkpoint_created.connect(_on_checkpoint_created)

# Error handling
SaveService.error.connect(_on_save_error)
```

## File Structure

```
user://saves/
├── profile1/
│   ├── main.json          # Main save file
│   ├── autosave.json      # Auto-save file
│   ├── meta.json          # Metadata
│   └── checkpoints/
│       ├── checkpoint_1.json
│       └── checkpoint_2.json
└── profile2/
    └── ...
```

## Save Data Format

```json
{
    "meta": {
        "schema_version": 1,
        "app_version": "0.1.0",
        "profile_id": "player1",
        "timestamp": 1234567890,
        "save_count": 2
    },
    "saveables": {
        "player_data": {
            "priority": 10,
            "data": {
                "player_name": "TestPlayer",
                "level": 5,
                "experience": 250
            }
        },
        "game_state": {
            "priority": 20,
            "data": {
                "current_scene": "level_1",
                "game_time": 3600
            }
        }
    }
}
```

## Best Practices

### 1. Save Priority

Use save priorities to control the order of save/load operations:

- **1-10**: Critical game state (player data, progress)
- **11-50**: Important systems (inventory, settings)
- **51-100**: Less critical data (statistics, achievements)

### 2. Error Handling

Always connect to the error signal for debugging:

```gdscript
func _ready():
    SaveService.error.connect(_on_save_error)

func _on_save_error(code: String, message: String):
    print("Save Error [", code, "]: ", message)
    # Handle the error appropriately
```

### 3. Strict Mode

- **Enabled** (default): Strict validation, fails on errors
- **Disabled**: More permissive, continues on non-critical errors

Use strict mode during development, consider disabling for release if you need more flexibility.

### 4. Profile Naming

Profile IDs must match: `^[A-Za-z0-9_\-]{1,24}$`
- Only letters, numbers, underscore, and hyphen
- 1-24 characters long

## Examples

See the `Examples/` directory for:
- `PlayerData.gd` - Complete ISaveable implementation
- `SaveServiceExample.gd` - Comprehensive usage examples

## Testing

Unit tests are available in `UnitTests/test_save_service.gd`. Run with GUT test framework.

## Configuration Options

```gdscript
# In SaveService.gd, you can modify these constants:
const SCHEMA_VERSION := 1              # Bump when data format changes
const APP_VERSION := "0.1.0"           # Your app version

# Runtime configuration:
SaveService.strict_mode = true         # Enable strict validation
SaveService.auto_save_enabled = true   # Enable auto-save
SaveService.auto_save_interval = 300.0 # Auto-save every 5 minutes
SaveService.max_checkpoints = 10       # Keep 10 checkpoints max
```

## Error Codes

Common error codes you might encounter:

- `INVALID_PROFILE_ID` - Profile name doesn't match requirements
- `NO_PROFILE` - No profile selected
- `SAVE_NOT_FOUND` - Trying to load non-existent save
- `SCHEMA_MISMATCH` - Save file schema version mismatch
- `DUPLICATE_SAVE_ID` - Multiple objects with same save ID
- `FILE_WRITE_FAILED` / `FILE_READ_FAILED` - File system errors

## Migration from Old ProfileManager

If you were using the old ProfileManager.gd, all functionality has been integrated into SaveService:

- `ProfileManager.set_current_profile()` → `SaveService.set_current_profile()`
- `ProfileManager.list_profiles()` → `SaveService.list_profiles()`
- All the same functionality, plus much more!
