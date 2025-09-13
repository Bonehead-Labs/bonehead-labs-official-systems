# InputService — Quickstart and Examples

This service centralizes input for actions, axes, context gating, runtime rebinding, and optional EventBus mirroring. It also persists user bindings via `SaveService`.

## Autoloads

Ensure these are autoloaded in `project.godot`:
- `EventBus` — event hub
- `EventTopics` — typed topics registry
- `SaveService` — persistence layer
- `InputConfig` — game-defined actions/contexts/axes
- `InputService` — this service

## Concepts

- **Actions**: Named inputs defined in `Project Settings > Input Map`. This service emits edges (pressed/released) and supports rebinding.
- **Axes**: Virtual axes mapped from two actions (e.g., `move_left`/`move_right` → `move_x`).
- **Contexts**: Togglable groups of actions, e.g., `gameplay` vs `ui`.
- **Rebinding**: Capture the next key/mouse button/joy button and apply it to an action.
- **Device tracking**: Track last active device and joypad connections.
- **EventBus mirroring**: Optionally publish inputs to `EventBus` using topics in `EventTopics.gd`.

## Signals (connect directly)

- `action_event(action: StringName, edge: String, device: int, event: InputEvent)`
- `axis_event(axis: StringName, value: float, device: int)`
- `rebind_started(action)`, `rebind_finished(action)`, `rebind_failed(action, reason)`
- `device_changed(device_id, connected, kind)`, `last_active_device_changed(kind, device_id)`

## EventBus Topics (subscribe via EventBus)

- `EventTopics.INPUT_ACTION` — payload `{ action, edge, device, ts }`
- `EventTopics.INPUT_AXIS` — payload `{ axis, value, device, ts }`
- `EventTopics.INPUT_REBIND_STARTED` — `{ action }`
- `EventTopics.INPUT_REBIND_FINISHED` — `{ action }`
- `EventTopics.INPUT_REBIND_FAILED` — `{ action, reason }`
- `EventTopics.INPUT_DEVICE_CHANGED` — `{ device_id, connected, kind }`

---

## Examples

### 1) Listen for actions directly

```gdscript
# In any node
func _ready() -> void:
	InputService.action_event.connect(_on_action)

func _on_action(action: StringName, edge: String, device: int, e: InputEvent) -> void:
	if action == &"jump" and edge == "pressed":
		print("Jump!")
```

### 2) Read an axis each frame

```gdscript
func _process(_delta: float) -> void:
	var x := InputService.axis_value(&"move_x")
	# move your character using x
```

### 3) Toggle contexts

```gdscript
# Disable gameplay actions and enable UI-only
InputService.enable_context(&"gameplay", false)
InputService.enable_context(&"ui", true)
```

### 4) Runtime rebinding with Esc to cancel

```gdscript
func _ready() -> void:
	InputService.rebind_finished.connect(func(a): print("Rebound:", a))
	InputService.rebind_failed.connect(func(a, r): print("Rebind failed:", a, r))

# Begin capture for the "jump" action
InputService.begin_rebind(&"jump")
# Press a key/mouse button/joy button to bind, or Esc to cancel
```

### 5) Subscribe via EventBus instead of signals

```gdscript
func _ready() -> void:
	EventBus.sub(EventTopics.INPUT_ACTION, _on_input_action)

func _on_input_action(payload: Dictionary) -> void:
	if payload.action == &"pause" and payload.edge == "pressed":
		print("Toggle pause")
```

### 6) Persist and restore bindings (handled automatically)

- On startup, `InputService` registers with `SaveService` and exposes data via `save_data()` / `load_data()`.
- To manually trigger save/load:

```gdscript
# After selecting a profile in SaveService
SaveService.save_game("controls")
SaveService.load_game("controls")
```

### 7) Device tracking

```gdscript
InputService.last_active_device_changed.connect(func(kind, id): print(kind, id))
```

---

## Configuration knobs

- `InputService.mirror_to_eventbus: bool` — mirror inputs to EventBus (default: true)
- `InputService.emit_axis_events: bool` — emit `axis_event` when axis changes (default: true)
- `InputService.process_always: bool` — process while paused (default: false)
- `InputService.rebind_capture_escape_cancels: bool` — Esc cancels rebind (default: true)

## InputConfig

Customize in `InputService/InputConfig.gd`:
- `ACTIONS`: list of action names to watch
- `CONTEXTS`: map context → [actions]
- `AXES`: map axis → { neg: action_name, pos: action_name }