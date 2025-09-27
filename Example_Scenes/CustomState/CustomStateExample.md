# Custom State Example - Extending the PlayerController

This example demonstrates how to extend the PlayerController system with custom states using the extensible state machine architecture. We'll walk through the complete process of creating and integrating a custom state.

## High-Level Concept

The PlayerController uses a flexible state machine system that allows you to add custom states without modifying the core system. This follows the **Open/Closed Principle** - the system is open for extension but closed for modification.

### Key Benefits:
- **Clean Separation**: Custom states are separate from core movement logic
- **Reusable**: States can be shared across different player types
- **Non-Intrusive**: No modifications to the core PlayerController code
- **Flexible**: Easy to add different state types and behaviors

## Architecture Overview

```
PlayerController (Core System)
├── Built-in States (idle, move, jump, fall)
├── State Machine (manages transitions)
└── Custom States (attack, dash, etc.) ← You add these
```

The state machine automatically handles:
- State transitions and validation
- Context sharing between states
- Event emission and handling
- Lifecycle management (enter/exit/update)

## Implementation Guide

### Step 1: Create the State Script

Create your custom state script that extends the movement state base class:

```gdscript
extends "res://PlayerController/states/PlayerMovementState.gd"

## Your custom state implementation
var state_duration: float = 1.0
var state_timer: float = 0.0

func enter(payload: Dictionary[StringName, Variant] = {}) -> void:
    emit_state_entered(StringName("your_state"), payload)
    
    # Initialize your state
    state_timer = state_duration
    
    # Apply any visual/audio effects
    if controller:
        # Your state-specific setup here
        pass

func exit(payload: Dictionary[StringName, Variant] = {}) -> void:
    emit_state_exited(StringName("your_state"), payload)
    
    # Clean up your state
    if controller:
        # Your state-specific cleanup here
        pass

func update(delta: float) -> void:
    # Update your state logic
    state_timer -= delta
    if state_timer <= 0.0:
        # Transition to another state when done
        safe_transition_to(StringName("idle"), {}, StringName("state_finished"))

func physics_update(delta: float) -> void:
    # Handle movement during your state
    var input_vector := get_input_vector()
    if is_platformer():
        controller.move_platformer_horizontal(input_vector.x, delta, false)
    else:
        controller.move_top_down(input_vector, delta)
```

### Step 2: Register the State

In your player script, register the custom state:

```gdscript
extends _PlayerController2D

# Import your custom state
const YourStateScript = preload("res://path/to/YourState.gd")
const STATE_YOUR_STATE := StringName("your_state")

func _ready() -> void:
    super._ready()
    
    # Register the custom state
    register_additional_state(STATE_YOUR_STATE, YourStateScript)
    
    # Connect input handling
    _connect_your_input()

func _connect_your_input() -> void:
    # Connect to InputService
    var input_service = _get_autoload_singleton(StringName("InputService"))
    if input_service and input_service.has_signal("action_event"):
        input_service.action_event.connect(_on_action_event)

func _on_action_event(action: StringName, edge: String, _device: int, _event: InputEvent) -> void:
    if action == StringName("your_action") and edge == "pressed":
        _handle_your_input()

func _handle_your_input() -> void:
    var current_state = get_current_state()
    if current_state == "idle" or current_state == "move":
        transition_to_state(STATE_YOUR_STATE, {"custom_data": "value"})
```

### Step 3: Configure Input

Add your action to `InputService/InputConfig.gd`:

```gdscript
const ACTIONS := [
    "move_left", "move_right", "move_up", "move_down",
    "jump", "pause", "interact", "your_action",  # Add your action
    "ui_accept", "ui_cancel"
]

const CONTEXTS := {
    "gameplay": ["move_left","move_right","move_up","move_down","jump","pause","interact","your_action"],
    "ui":       ["ui_accept","ui_cancel"]
}
```

### Step 4: Set Up Input Mapping

1. **Open Project Settings** → `Input Map` tab
2. **Add Your Action**:
   - Click `+` to add new action
   - Name it `your_action` (case-sensitive)
   - Click `Add`
3. **Assign Input Key**:
   - Select your action
   - Click `+` next to it
   - Choose `Key` from dropdown
   - Press desired key
4. **Optional Gamepad**:
   - Add `Joy Button` for gamepad support

## Key Concepts Demonstrated

### State Lifecycle
- **Enter**: Initialize state-specific data and effects
- **Update**: Handle per-frame logic and timers
- **Physics Update**: Handle movement and physics
- **Exit**: Clean up state-specific data and effects

### State Machine Integration
- **Automatic Transitions**: State machine handles all transitions
- **Context Sharing**: Access to controller and movement config
- **Event System**: Proper event emission and handling
- **Validation**: Transition validation and error handling

### Input Integration
- **InputService**: Primary input handling through InputService
- **EventBus**: Fallback input handling through EventBus
- **Action Mapping**: Clean separation of input and state logic

## State Flow Pattern

```
idle/move → your_state (on input)
your_state → idle (when state completes + no movement)
your_state → move (when state completes + movement input)
```

## Extending the Pattern

This template can be adapted for any custom state. You can easily create:

### Different State Types
- **Dash State**: Quick movement with cooldown
- **Block State**: Defensive state with damage reduction
- **Charge State**: Charging up for powerful abilities
- **Stun State**: Temporary inability to act
- **Interact State**: Handling interactions with objects

### Advanced Features
- **State Chaining**: Link states together (combo systems)
- **Conditional Transitions**: Different paths based on context
- **Animation Integration**: Connect to AnimationPlayer nodes
- **Sound Integration**: Trigger audio via EventBus
- **Hit Detection**: Integrate with combat systems

### State Parameters
```gdscript
# Pass data between states
transition_to_state(STATE_YOUR_STATE, {
    "state_type": "special",
    "duration": 2.0,
    "custom_data": {"key": "value"}
})
```

## Key Design Principles

1. **Single Responsibility**: Each state handles one specific behavior
2. **Open/Closed**: System is open for extension, closed for modification
3. **Dependency Inversion**: States depend on abstractions, not concretions
4. **Interface Segregation**: States only use what they need from the controller
5. **Clean Architecture**: Clear separation between state logic and system logic

## Troubleshooting

- **State not working**: Check that action name matches exactly (case-sensitive)
- **No visual feedback**: Ensure player node has visual component (Sprite2D, etc.)
- **Console errors**: Verify all autoloads (InputService, EventBus) are configured
- **State not registering**: Check that `register_additional_state()` is called after `super._ready()`
- **Transitions failing**: Verify state names match exactly and transitions are valid

## Summary

This example demonstrates the power and flexibility of the PlayerController's state machine system, providing a clean, extensible way to add complex player behaviors without modifying the core system. The pattern shown here can be adapted for any custom state you need to implement.
