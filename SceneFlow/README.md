# FlowManager

`FlowManager` is the scene stack controller for Bonehead Labs systems. Register the script as an autoload named `FlowManager` and use it to push, replace, or pop scenes while passing typed payload metadata between transitions.

## Setup

1. Enable the provided autoload setup script (see `SceneFlow/setup`).
2. Ensure `EventBus` and `EventTopics` are available as autoloads (already present in the repository).
3. Optional: toggle `FlowManager.analytics_enabled = true` once your analytics layer is configured via `SettingsService`.

## Public API

All functions are strongly typed and return `Error` codes when appropriate.

- `push_scene(scene_path: String, payload_data: Variant = null, metadata: Dictionary = {}) -> Error`
  - Loads the new scene synchronously, appends it to the stack, and forwards payload metadata.
- `replace_scene(scene_path: String, payload_data: Variant = null, metadata: Dictionary = {}) -> Error`
  - Swaps the active scene synchronously without altering stack depth.
- `pop_scene(payload_data: Variant = null, metadata: Dictionary = {}) -> Error`
  - Returns to the previous stack entry, optionally providing a payload to the restored scene.
- `push_scene_async(scene_path: String, payload_data: Variant = null, metadata: Dictionary = {}) -> Error`
  - Starts an asynchronous scene load using `FlowAsyncLoader`; completion is signalled via `loading_finished`.
- `replace_scene_async(scene_path: String, payload_data: Variant = null, metadata: Dictionary = {}) -> Error`
  - Asynchronous replacement that keeps the current scene active until loading succeeds.
- `cancel_pending_load() -> void`
  - Cancels the current asynchronous load (if any) and emits `loading_cancelled`.
- `has_pending_load() -> bool`
  - Returns `true` when FlowManager is processing an asynchronous load.
- `configure_loading_screen(scene: PackedScene, parent_path: NodePath = NodePath()) -> void`
  - Registers a loading screen scene (must extend `FlowLoadingScreen`) and optional parent attachment path.
- `clear_loading_screen() -> void`
  - Removes previously configured loading screen data and frees any instantiated instance.
- `configure_transition_library(library: FlowTransitionLibrary, player_scene: PackedScene) -> void`
  - Registers the shared transition definitions and player scene for playback.
- `clear_transition_library() -> void`
  - Removes transition configuration and frees any instantiated player.
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
- `loading_started(scene_path: String, handle: FlowAsyncLoader.LoadHandle)`
- `loading_progress(scene_path: String, progress: float, metadata: Dictionary)`
- `loading_finished(scene_path: String, handle: FlowAsyncLoader.LoadHandle)`
- `loading_cancelled(scene_path: String, handle: FlowAsyncLoader.LoadHandle)`
- `transition_complete(scene_path: String, metadata: Dictionary)`

Use signals to drive loading screens, transition effects, or error telemetry.

## Asynchronous Loading

`FlowAsyncLoader` powers the asynchronous API surface. Pending loads expose deterministic seed snapshots (via an optional `RNGService.snapshot_seed` hook), progress reporting, and cancellation safeguards.

- Call `push_scene_async` / `replace_scene_async` to enqueue a load.
- Observe `loading_progress` for 0.0–1.0 updates (forwarded to any configured `FlowLoadingScreen`).
- Cancel via `cancel_pending_load` when needed (e.g., user aborted navigation).

### Loading Screen Contract

Create a scene that extends `FlowLoadingScreen` to participate in the lifecycle:

```gdscript
func begin_loading(handle: FlowAsyncLoader.LoadHandle) -> void
func update_progress(progress: float, metadata: Dictionary) -> void
func finish_loading(success: bool, metadata: Dictionary = {}) -> void
```

Register it using `configure_loading_screen(scene, parent_path)`. FlowManager instantiates the scene once and attaches it either to the supplied `parent_path` or the current scene/root. The instance receives lifecycle callbacks and is freed automatically after successful completion.

### Failure Handling

If an async load fails (or the activated scene returns an error):

- FlowManager leaves the previous stack entry active (reinstating replacements).
- `scene_error` is emitted with the relevant error code.
- Analytics dispatch `FLOW_LOADING_FAILED` with error context.
- The loading screen receives `finish_loading(false, ...)` enabling custom messaging.

## Transition FX

Configure the shared transition library to re-use the same resources across FlowManager and UI navigation.

```gdscript
var library := load("res://SceneFlow/Transitions/MyTransitions.tres")
var player_scene := load("res://SceneFlow/Transitions/TransitionPlayer.tscn")
FlowManager.configure_transition_library(library, player_scene)
```

Set the desired transition per operation by embedding metadata in the payload:

```gdscript
FlowManager.push_scene_async("res://scenes/Level01.tscn", null, {"transition": "warp"})
```

Transitions emit `transition_complete` when playback (enter/exit) finishes and, when analytics are enabled, publish `FLOW_TRANSITION_COMPLETED` diagnostics.

## World & Save Hooks

- `configure_checkpoint_manager({"node": checkpoint_manager, "method": "on_scene_transition"})`
  - Registers a checkpoint manager interface. FlowManager calls the supplied method after each successful scene change (push, replace, pop, async).
- `configure_save_on_transition({"enabled": true, "save_id": "flow_autosave", "settings_key": &"flow/autosave"})`
  - Requests `SaveService.save_game(save_id)` before unloading the active scene when the optional settings gate permits it.
- `clear_checkpoint_manager()` / `clear_save_on_transition()` reset the integrations.

Both integrations are skipped in editor contexts. The checkpoint payload includes `operation`, `scene_path`, `previous_scene`, and duplicated metadata dictionaries for further processing.

## Analytics Topics

When `analytics_enabled` is `true`, FlowManager publishes structured payloads to `EventBus` using the following topics:

- `EventTopics.FLOW_SCENE_PUSHED`
- `EventTopics.FLOW_SCENE_REPLACED`
- `EventTopics.FLOW_SCENE_POPPED`
- `EventTopics.FLOW_SCENE_ERROR`
- `EventTopics.FLOW_LOADING_STARTED`
- `EventTopics.FLOW_LOADING_PROGRESS`
- `EventTopics.FLOW_LOADING_COMPLETED`
- `EventTopics.FLOW_LOADING_FAILED`
- `EventTopics.FLOW_LOADING_CANCELLED`
- `EventTopics.FLOW_TRANSITION_COMPLETED`

Each payload includes `scene_path`, `source_scene`, `stack_size`, `payload metadata`, and a timestamp, plus context (e.g., `previous_scene`, `popped_scene`). Gate analytics behind user consent via `SettingsService`.

## Error Handling

Failed transitions emit `scene_error` and publish (optional) analytics. `pop_scene` returns `ERR_DOES_NOT_EXIST` when the stack has no previous entry. Invalid scene paths surface `ERR_INVALID_PARAMETER` or `ERR_FILE_NOT_FOUND` and leave the stack unchanged.

## Integration Notes

- FlowManager is synchronous for core transitions; asynchronous loading is introduced in later milestones.
- Combine with the shared transition FX library when available by listening to `about_to_change` and `scene_changed`.
- To propagate checkpoint state, subscribe to `scene_changed` and coordinate with `World.CheckpointManager` (milestone 4).
