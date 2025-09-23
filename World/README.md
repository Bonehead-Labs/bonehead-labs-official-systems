# World System

Comprehensive world management system providing checkpoints, interactables, level transitions, hazards, and physics/time management.

## Components

- **CheckpointManager** (`CheckpointManager.gd`): Singleton for managing checkpoints with SaveService integration
- **Interactable System**: Interface and base classes for interactive objects
  - `IInteractable.gd`: Interface for interactable behavior
  - `InteractableBase.gd`: Base Area2D with composition support
  - `interactables/Door.gd`, `interactables/Lever.gd`, `interactables/Chest.gd`, `interactables/Button.gd`: Specific interactable implementations
- **Level Management**:
  - `LevelLoader.gd`: Helper for FlowManager-based scene transitions
  - `portals/Portal.gd`: Portal nodes with entry conditions and payloads
- **Environmental Hazards**:
  - `hazards/HazardVolume.gd`: Area2D dealing periodic or instant damage
- **Destructible Objects**:
  - `destructibles/DestructibleProp.gd`: Props with health and loot integration
- **Physics & Time**:
  - `PhysicsLayers.gd`: Central physics layer definitions and collision matrix
  - `WorldTimeManager.gd`: Time management with pause/resume and extension points

## Quick Start

### Checkpoint System
```gdscript
# Register a checkpoint
CheckpointManager.register_checkpoint("start_area", player.global_position, {"level": "tutorial"})

# Activate a checkpoint
CheckpointManager.activate_checkpoint("start_area")

# Listen for checkpoint events
CheckpointManager.checkpoint_activated.connect(func(id, data):
    print("Activated checkpoint: ", id)
)
```

### Interactable Objects
```gdscript
# Create a door
var door_base = InteractableBase.new()
var door_interactable = DoorInteractable.new()
door_base.set_interactable(door_interactable)
add_child(door_base)

# Connect to signals
door_base.interacted.connect(func(interactor, interactable):
    print("Door interacted with!")
)
```

### Level Transitions
```gdscript
# Load a new level
LevelLoader.load_level("res://levels/level2.tscn", {"from_checkpoint": true})

# Create a portal
var portal = Portal.new()
portal.target_scene = "res://levels/boss_room.tscn"
portal.set_entry_condition("has_item", "boss_key")
add_child(portal)
```

### Hazard Volumes
```gdscript
# Create a damage-over-time hazard
var hazard = HazardVolume.new()
hazard.damage_per_second = 15.0
hazard.damage_type = "fire"
add_child(hazard)
```

### Destructible Props
```gdscript
# Create a breakable crate
var crate = DestructibleProp.new()
crate.max_health = 50.0
crate.loot_table_path = "res://loot_tables/basic_crate.tres"
add_child(crate)

# Deal damage to it
crate.take_damage({"amount": 25.0, "type": "physical", "source": player})
```

### Physics Layers
```gdscript
# Apply physics settings to a node
PhysicsLayers.apply_physics_settings(node)

# Check collision between layers
var can_collide = PhysicsLayers.should_collide(PhysicsLayers.LAYER_PLAYER, PhysicsLayers.LAYER_ENEMIES)
```

### World Time
```gdscript
# Pause/resume world time
WorldTimeManager.pause_time()
WorldTimeManager.resume_time()

# Change time scale (slow motion, etc.)
WorldTimeManager.set_time_scale(0.5)

# Get current game time
var current_time = WorldTimeManager.get_game_time()
```

## EventBus Integration

All components emit events through EventBus:

- **Checkpoint Events**:
  - `world/checkpoint_registered`: When a checkpoint is registered
  - `world/checkpoint_activated`: When a checkpoint is activated

- **Interaction Events**:
  - `world/interacted`: When an interactable is used
  - `world/hazard_entered`: When entering a hazard
  - `world/hazard_exited`: When exiting a hazard
  - `world/hazard_damage`: When hazard deals damage

- **Portal Events**:
  - `world/portal_used`: When a portal is activated

- **Destruction Events**:
  - `world/prop_damaged`: When a destructible is damaged
  - `world/prop_destroyed`: When a destructible is destroyed
  - `world/prop_respawned`: When a destructible respawns

- **Time Events**:
  - `world/time_paused`: When world time is paused
  - `world/time_resumed`: When world time is resumed
  - `world/time_scale_changed`: When time scale changes

## SaveService Integration

Components that need persistence implement save/load:

- `CheckpointManager`: Saves all checkpoints and current state
- `WorldTimeManager`: Saves game time, scale, and pause state
- `DestructibleProp`: Saves health and destruction state (when respawning)

## Architecture Notes

### Composition over Inheritance
The interactable system uses composition - `InteractableBase` holds an `IInteractable` instance, allowing for flexible behavior without complex inheritance hierarchies.

### Event-Driven Design
All systems emit events for loose coupling. Other systems can respond to world changes without direct dependencies.

### Extensible Time System
`WorldTimeManager` provides a foundation that can be extended for day/night cycles, time-based puzzles, or time travel mechanics.

### Physics Layer Management
`PhysicsLayers` provides centralized collision management and automatic setup helpers for consistent physics behavior across the game.

## Extension Points

### Custom Interactables
```gdscript
class_name CustomInteractable
extends RefCounted

func interact(interactor: Node) -> bool:
    # Custom interaction logic
    return true

func get_prompt() -> String:
    return "Custom Action"
```

### Time-of-Day System
Extend `WorldTimeManager` to add:
- Day/night lighting changes
- Time-based enemy behavior
- Scheduled world events

### Advanced Physics Setup
Use `PhysicsLayers.apply_physics_settings()` in custom setup scripts to automatically configure collision layers and masks based on node naming conventions.

## Integration with Other Systems

- **Player Controller**: InteractableBase integrates with InteractionDetector
- **Combat System**: Hazards and destructibles use HealthComponent
- **Items & Economy**: Chests can contain loot from LootTable resources
- **Scene Flow**: LevelLoader and Portals work with FlowManager
- **Save Service**: CheckpointManager and WorldTimeManager persist state

This World System provides a solid foundation for creating rich, interactive game worlds with proper separation of concerns and extensibility.
