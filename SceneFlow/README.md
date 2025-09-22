# FlowManager

`FlowManager` is the scene stack controller for Bonehead Labs systems. Register the script as an autoload named `FlowManager` and use it to push, replace, or pop scenes while passing typed payload metadata between transitions.

## Setup

1. Enable the provided autoload setup script (see `SceneFlow/setup`).
2. Ensure `EventBus` and `EventTopics` are available as autoloads (already present in the repository).
3. Optional: toggle `FlowManager.analytics_enabled = true` once your analytics layer is configured via `SettingsService`.

## Public API

All functions are strongly typed and return `Error` codes when appropriate.

- `push_scene(scene_path: String, payload_data: Variant = null, metadata: Dictionary = {}) -> Error`
  - Loads the new scene, appends it to the stack, and forwards payload metadata.
- `replace_scene(scene_path: String, payload_data: Variant = null, metadata: Dictionary = {}) -> Error`
  - Swaps the active scene without altering stack depth.
- `pop_scene(payload_data: Variant = null, metadata: Dictionary = {}) -> Error`
  - Returns to the previous stack entry, optionally providing a payload to the restored scene.
- `peek_scene() -> FlowStackEntry`
  - Returns the active stack entry (scene path + payload metadata).
- `clear_stack(keep_active: bool = true) -> void`
  - Removes history while optionally preserving the active entry.

### FlowStackEntry & FlowPayload

Each stack entry contains a `FlowPayload`:

```gdscript
class FlowPayload:
    var data: Variant
    var metadata: Dictionary
    var source_scene: StringName
    var created_ms: int
```

Destination scenes can implement an optional `receive_flow_payload(payload: FlowPayload)` method. The payload is also exposed via `get_meta("flow_payload")` on the active scene after a transition.

## Signals

- `about_to_change(scene_path: String, entry: FlowStackEntry)`
- `scene_changed(scene_path: String, entry: FlowStackEntry)`
- `scene_error(scene_path: String, error_code: int, message: String)`

Use signals to drive loading screens, transition effects, or error telemetry.

## Analytics Topics

When `analytics_enabled` is `true`, FlowManager publishes structured payloads to `EventBus` using the following topics:

- `EventTopics.FLOW_SCENE_PUSHED`
- `EventTopics.FLOW_SCENE_REPLACED`
- `EventTopics.FLOW_SCENE_POPPED`
- `EventTopics.FLOW_SCENE_ERROR`

Each payload includes `scene_path`, `source_scene`, `stack_size`, `payload metadata`, and a timestamp, plus context (e.g., `previous_scene`, `popped_scene`). Gate analytics behind user consent via `SettingsService`.

## Error Handling

Failed transitions emit `scene_error` and publish (optional) analytics. `pop_scene` returns `ERR_DOES_NOT_EXIST` when the stack has no previous entry. Invalid scene paths surface `ERR_INVALID_PARAMETER` or `ERR_FILE_NOT_FOUND` and leave the stack unchanged.

## Integration Notes

- FlowManager is synchronous for core transitions; asynchronous loading is introduced in later milestones.
- Combine with the shared transition FX library when available by listening to `about_to_change` and `scene_changed`.
- To propagate checkpoint state, subscribe to `scene_changed` and coordinate with `World.CheckpointManager` (milestone 4).
