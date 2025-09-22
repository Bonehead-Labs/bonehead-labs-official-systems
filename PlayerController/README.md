# Player Controller (2D)

## Overview

- `PlayerController.gd`: `CharacterBody2D`-based movement component driven by `MovementConfig`
- `MovementConfig.gd`: Resource describing speed, acceleration, gravity, input actions, and jump behaviour

## Signals

- `player_spawned(position: Vector2)`
- `player_jumped()`
- `player_landed()`

## Autoload Requirements

| Autoload | Purpose |
| --- | --- |
| (optional) `InputService` | Rebind-aware inputs; controller reads Godot `InputMap` directly |

## Usage

```gdscript
var controller := preload("res://PlayerController/PlayerController.gd").new()
controller.movement_config = preload("res://PlayerController/configs/default_movement.tres")
add_child(controller)
controller.spawn(Vector2.ZERO)
```

`MovementConfig` supports axis or action-based input. Toggle `use_axis_input` to read from a negative/positive action pair instead of discrete buttons.

Manual overrides (`enable_manual_input`, `set_manual_input`) help AI and tests drive the same movement pipeline.
