# Player Controller (2D)

## Overview

- `PlayerController.gd`: `CharacterBody2D`-based movement component driven by `MovementConfig` and backed by the shared `StateMachine` module.
- `MovementConfig.gd`: Resource describing locomotion parameters, input bindings, and movement mode (platformer or top-down).
- `states/`: Built-in locomotion states (`idle`, `move`, `jump`, `fall`) consuming shared helpers so abilities can extend the FSM.
- `Debug/PlayerStateDebugger.gd`: Optional overlay label that mirrors the active FSM state (and most recent events) for quick instrumentation.

## Signals

### Movement Signals
- `player_spawned(position: Vector2)`
- `player_jumped()`
- `player_landed()`
- `state_changed(previous: StringName, current: StringName)`
- `state_event(event: StringName, data: Variant)`

### Interaction Signals
- `interaction_available_changed(available: bool)` - Emitted when interaction availability changes

### Ability Signals
- `ability_registered(ability_id: StringName, ability: AbilityScript)` - Emitted when an ability is registered
- `ability_unregistered(ability_id: StringName)` - Emitted when an ability is unregistered

### Combat Signals
- `player_damaged(amount: float, source: Node, remaining_health: float)` - Emitted when player takes damage
- `player_healed(amount: float, source: Node, new_health: float)` - Emitted when player is healed
- `player_died(source: Node)` - Emitted when player dies

## Autoload Requirements

| Autoload | Purpose |
| --- | --- |
| (optional) `InputService` | Rebind-aware inputs; controller reads Godot `InputMap` directly |
| (optional) `EventBus` | Analytics event publishing |
| (optional) `SaveService` | Persistent player state and combat stats |

## Usage

```gdscript
var controller := preload("res://PlayerController/PlayerController.gd").new()
controller.movement_config = preload("res://PlayerController/configs/default_movement.tres")
add_child(controller)
controller.spawn(Vector2.ZERO)
```

`MovementConfig` supports axis or action-based input. Toggle `use_axis_input` to read from a negative/positive action pair instead of discrete buttons. For top-down or isometric projects, set:

- `movement_mode = MovementConfig.MovementMode.TOP_DOWN`
- `allow_vertical_input = true`
- `allow_jump = false` (optional)

Platformer defaults remain unchanged—gravity, coyote time, jump buffering, and air control continue to be data driven.

Manual overrides (`enable_manual_input`, `set_manual_input`) help AI, cutscenes, and tests drive the same movement pipeline.

## State Machine Integration

The controller seeds a local `StateMachine` with reusable locomotion states:

- `idle`: Grounded with no directional input.
- `move`: Grounded locomotion (platformer or top-down).
- `jump`: Upward launch with coyote/buffer safety.
- `fall`: Airborne descent with landing hand-off.

States pull context via `MovementConfig` and the controller’s public helpers (`move_platformer_horizontal`, `move_top_down`, `start_jump`, `consume_jump_request`, etc.). Ability systems can extend the FSM without touching internals:

```gdscript
var dash_state_script := preload("res://Abilities/DashState.gd")
player_controller.register_additional_state(StringName("dash"), dash_state_script)
player_controller.transition_to_state(StringName("dash"))
```

`state_changed` / `state_event` signals fan out to analytics via `EventBus` and can power debug overlays.

## Debug Overlay Hook

Drop `Debug/PlayerStateDebugger.gd` onto a `Label` inside your debug UI, point `controller_path` at the runtime controller, and enable `show_last_event` to display the most recent FSM event next to the active state.

## Animation Driver

- Script: `Animation/PlayerAnimationDriver.gd`
- Purpose: mirror controller state changes and events to either an `AnimationPlayer` or `AnimatedSprite2D`.
- Exported dictionaries map `StringName` states/events to animation names; optional fallback covers unmapped transitions.
- Supports temporary overrides via `set_animation_override()` for cutscenes or scripted moments, with `clear_animation_override()` to restore FSM-driven playback.
- Hook it up by assigning `controller_path`, `animation_player_path` and/or `animated_sprite_path`, then providing state/event mappings.

## Camera Rig

- Scene: `Camera/PlayerCameraRig.tscn` (root `Node2D` + child `Camera2D`).
- Script: `Camera/PlayerCameraRig.gd` handles smoothing, velocity-based lookahead, FlowManager transition pauses, and cutscene overrides.
- Configure `target_path` (usually the PlayerController node), adjust `smoothing_speed`/`lookahead_distance`, and optionally wire a FlowManager via `flow_manager_path`.
- Cutscenes call `begin_cutscene(target, suspend_follow := true)` and `end_cutscene()`; listeners can react via `cutscene_mode_changed` and `follow_suspended_changed` signals.

## Interaction System

The interaction system enables players to interact with objects in the game world using area-based detection.

### Setting Up Interactions

1. **Enable Interaction Detection**: Set `enable_interaction_detector = true` on the PlayerController
2. **Configure Range**: Adjust `interaction_detector_range` (default: 32.0 pixels)
3. **Create Interactable Objects**: Any `Area2D` in the "interactable" group can be detected

### Creating Interactable Objects

```gdscript
class_name TreasureChest extends Area2D

func _ready() -> void:
    add_to_group("interactable")
    # Set up collision shape
    var shape := RectangleShape2D.new()
    shape.size = Vector2(32, 32)
    var collision := CollisionShape2D.new()
    collision.shape = shape
    add_child(collision)

func interact(interactor: Node) -> void:
    print("Chest opened by: ", interactor.name)
    # Your interaction logic here
```

### Handling Interaction Events

```gdscript
# Connect to interaction signals
player_controller.interaction_available_changed.connect(_on_interaction_changed)

func _on_interaction_changed(available: bool) -> void:
    interaction_prompt.visible = available
    if available:
        var interactable := player_controller.get_current_interactable()
        if interactable and interactable.has_method("get_interaction_prompt"):
            interaction_prompt.text = interactable.get_interaction_prompt()

# Handle interaction input
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("interact") and player_controller.is_interaction_available():
        player_controller.interact()
```

### EventBus Integration

Interaction events are automatically published:

- `player/interaction_detected` - When an interactable enters range
- `player/interaction_lost` - When an interactable leaves range
- `player/interaction_executed` - When player performs an interaction

## Ability System

The ability system allows modular abilities to extend player functionality and integrate with the FSM.

### Creating Abilities

Extend the `PlayerAbility` base class:

```gdscript
class_name DashAbility extends PlayerAbility

@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0

var _dash_timer: float = 0.0
var _cooldown_timer: float = 0.0

func _on_input_action(action: StringName, edge: String, _device: int, _event: InputEvent) -> void:
    if action == "dash" and edge == "pressed" and can_dash():
        start_dash()

func can_dash() -> bool:
    return not is_dashing() and _cooldown_timer <= 0.0

func is_dashing() -> bool:
    return _dash_timer > 0.0

func start_dash() -> void:
    var direction := get_controller().get_movement_input()
    if direction.length() < 0.1:
        direction = Vector2.RIGHT  # Default direction

    direction = direction.normalized()
    var dash_velocity := direction * dash_speed
    get_controller().set_motion_velocity(dash_velocity)

    _dash_timer = dash_duration
    emit_ability_event("dash_started", {"direction": direction, "speed": dash_speed})

func _on_update(delta: float) -> void:
    if is_dashing():
        _dash_timer -= delta
        if _dash_timer <= 0.0:
            end_dash()

func end_dash() -> void:
    get_controller().set_motion_velocity(Vector2.ZERO)
    _cooldown_timer = dash_cooldown
    emit_ability_event("dash_ended", {})
```

### Registering Abilities

```gdscript
func _ready() -> void:
    # Create and register ability
    var dash_ability := DashAbility.new()
    player_controller.register_ability("dash", dash_ability)

    # Activate the ability
    player_controller.activate_ability("dash")
```

### Ability Lifecycle

- **Setup**: Called when ability is registered with controller
- **Activation**: Ability becomes active and receives updates/input
- **Deactivation**: Ability stops receiving updates/input
- **Updates**: Active abilities receive `_process()` updates
- **Input Forwarding**: Active abilities receive input events
- **State Events**: Active abilities receive FSM state change notifications

### Built-in Example Abilities

- `abilities/DashAbility.gd` - Quick directional dash with cooldown

## EventBus Integration

The PlayerController publishes comprehensive analytics events:

### Movement Events
- `player/moved` - Position and velocity updates
- `player/jumped` - Jump initiation
- `player/landed` - Ground contact
- `player/state_changed` - FSM state transitions

### Interaction Events
- `player/interaction_detected` - Interactable object detected
- `player/interaction_lost` - Interactable object lost
- `player/interaction_executed` - Player performed interaction

### Ability Events
- `player/ability_used` - Ability activation with metadata

All events include timestamps and player position for analytics and debugging.

## Advanced Usage

### Custom States with Abilities

Abilities can create custom FSM states:

```gdscript
class_name DashState extends PlayerMovementState

var _dash_ability: DashAbility

func setup(state_machine: StateMachine, state_owner: Node, state_context: Dictionary[StringName, Variant]) -> void:
    super.setup(state_machine, state_owner, state_context)
    _dash_ability = state_context.get("dash_ability", null)

func update(delta: float) -> void:
    if _dash_ability and not _dash_ability.is_dashing():
        machine.transition_to("fall", {})
    # Continue with dash physics
```

### Multi-Ability Coordination

Abilities can communicate through the controller's state event system:

```gdscript
# In one ability
emit_ability_event("stamina_consumed", {"amount": 25})

# In another ability
func _on_state_event(event: StringName, data: Variant) -> void:
    if event == "ability_stamina_consumed":
        reduce_available_stamina(data.get("amount", 0))
```

## Testing

Run unit tests to verify functionality:

```bash
# Run all PlayerController tests
godot --headless --script res://addons/gut/gut_cmdln.gd -gtest=test_player_controller

# Run interaction tests
godot --headless --script res://addons/gut/gut_cmdln.gd -gtest=test_interaction_detector

# Run ability tests
godot --headless --script res://addons/gut/gut_cmdln.gd -gtest=test_abilities
```

## Combat System Integration

The PlayerController provides comprehensive damage intake methods that forward to the Combat system via signals and EventBus events.

### Damage Handling

```gdscript
# Apply damage to the player
player_controller.take_damage(25.0, enemy_node, "physical")

# Heal the player
player_controller.heal(10.0, health_pack_node)

# Make player invulnerable
player_controller.set_invulnerable(2.0)  # 2 seconds

# Check player status
if player_controller.is_alive():
    print("Health: ", player_controller.get_health(), "/", player_controller.get_max_health())

if player_controller.is_invulnerable():
    print("Player is invulnerable!")
```

### Combat Signals

The controller emits detailed combat signals for Combat system integration:

```gdscript
func _ready():
    player_controller.player_damaged.connect(_on_player_damaged)
    player_controller.player_died.connect(_on_player_died)

func _on_player_damaged(amount: float, source: Node, remaining_health: float):
    # Handle damage effects (screen shake, sound, particles)
    camera_shake(amount)
    play_damage_sound()

    # Forward to Combat system
    CombatSystem.on_player_damaged(amount, source, remaining_health)

func _on_player_died(source: Node):
    # Handle death (game over screen, respawn logic)
    show_game_over_screen()
    CombatSystem.on_player_death(source)
```

### Invulnerability System

```gdscript
# Temporary invulnerability after taking damage
func _on_player_damaged(amount, source, remaining_health):
    if not player_controller.is_invulnerable():
        player_controller.set_invulnerable(1.5)  # 1.5 seconds of invulnerability
        start_damage_flash_animation()
```

## Save/Load Integration

The PlayerController implements the `ISaveable` interface and automatically registers with SaveService for persistent state.

### Saved Data Structure

```json
{
  "position": {"x": 100.5, "y": 250.0},
  "health": 85.0,
  "max_health": 100.0,
  "velocity": {"x": 0.0, "y": 0.0},
  "is_invulnerable": false,
  "invulnerability_timer": 0.0,
  "current_state": "idle",
  "abilities": {
    "dash": {
      "active": true,
      "custom_data": {"cooldown_remaining": 0.5}
    }
  }
}
```

### Save/Load Events

```gdscript
func _ready():
    # Connect to SaveService signals
    SaveService.after_save.connect(_on_save_completed)
    SaveService.after_load.connect(_on_load_completed)
    SaveService.error.connect(_on_save_error)

func _on_save_completed(save_id: String, success: bool):
    if success:
        print("Player state saved to: ", save_id)
        show_save_confirmation()
    else:
        show_save_error_message()

func _on_load_completed(save_id: String, success: bool):
    if success:
        print("Player state loaded from: ", save_id)
        update_ui_after_load()
    else:
        show_load_error_message()
```

### Custom Ability Save/Load

Abilities can implement their own save/load logic:

```gdscript
class_name CustomAbility extends PlayerAbility

func save_data() -> Dictionary:
    return {
        "mana_cost": mana_cost,
        "cooldown_remaining": _cooldown_timer,
        "level": ability_level
    }

func load_data(data: Dictionary) -> bool:
    mana_cost = data.get("mana_cost", 10)
    _cooldown_timer = data.get("cooldown_remaining", 0.0)
    ability_level = data.get("level", 1)
    return true
```

## Serialization Contract

### Save Data Contract
- **position**: Required `{"x": float, "y": float}` - Player world position
- **health**: Required `float` - Current health value
- **max_health**: Required `float` - Maximum health capacity
- **velocity**: Optional `{"x": float, "y": float}` - Current movement velocity
- **is_invulnerable**: Optional `bool` - Invulnerability status
- **invulnerability_timer**: Optional `float` - Remaining invulnerability time
- **current_state**: Optional `String` - FSM state name
- **abilities**: Optional `Dictionary` - Active ability states

### Load Failure Handling
The controller handles various load failure scenarios:

```gdscript
func load_data(data: Dictionary) -> bool:
    # Validate required data
    if not data.has("position"):
        push_error("Save data missing required 'position' field")
        return false

    # Handle missing optional data gracefully
    _health = data.get("health", _max_health)
    _is_invulnerable = data.get("is_invulnerable", false)

    # Validate data ranges
    if _health < 0.0 or _health > _max_health:
        push_warning("Invalid health value in save data, clamping")
        _health = clamp(_health, 0.0, _max_health)

    return true
```

### Error Scenarios
- **Missing position data**: Load fails, returns `false`
- **Invalid health values**: Values clamped to valid ranges with warning
- **Missing ability references**: Abilities skipped with warning
- **State machine errors**: Invalid states logged, defaults used

## Best Practices

### Combat Integration
- Always check `is_alive()` before applying effects
- Use `is_invulnerable()` to prevent damage during cutscenes
- Forward combat events to dedicated Combat system
- Consider damage type for different effects (physical, magical, etc.)

### Save/Load Considerations
- Save frequently during safe moments (level transitions, checkpoints)
- Validate loaded data for corrupted save files
- Handle missing ability data gracefully (new abilities added)
- Consider player feedback for save/load operations

### Performance
- Combat calculations happen in `_physics_process()` for consistency
- Save operations are deferred to avoid frame drops
- Ability updates only occur for active abilities
- Event emissions are batched where possible
