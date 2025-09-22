class_name _FlowManager
extends Node

const FlowAsyncLoader = preload("res://SceneFlow/AsyncSceneLoader.gd")
const FlowLoadingScreen = preload("res://SceneFlow/LoadingScreenContract.gd")
const FlowTransitionLibrary = preload("res://SceneFlow/Transitions/TransitionLibrary.gd")
const FlowTransitionPlayer = preload("res://SceneFlow/Transitions/TransitionPlayer.gd")
const FlowTransition = preload("res://SceneFlow/Transitions/TransitionResource.gd")

## FlowManager is an autoload singleton responsible for high-level scene navigation.
## It provides a stack-based API for pushing, popping, and replacing scenes.

const ERROR_NO_PREVIOUS_SCENE: Error = ERR_DOES_NOT_EXIST
const OP_PUSH: StringName = StringName("push")
const OP_REPLACE: StringName = StringName("replace")
const OP_POP: StringName = StringName("pop")

## Emitted immediately before a scene transition occurs.
signal about_to_change(scene_path: String, entry: FlowStackEntry)
## Emitted after a scene has been successfully loaded and payload delivered.
signal scene_changed(scene_path: String, entry: FlowStackEntry)
## Emitted when a scene transition fails along with the error code and message.
signal scene_error(scene_path: String, error_code: int, message: String)
## Emitted when an asynchronous load starts.
signal loading_started(scene_path: String, handle: FlowAsyncLoader.LoadHandle)
## Emitted periodically with loading progress (0.0 - 1.0).
signal loading_progress(scene_path: String, progress: float, metadata: Dictionary)
## Emitted after an asynchronous load completes successfully.
signal loading_finished(scene_path: String, handle: FlowAsyncLoader.LoadHandle)
## Emitted when an asynchronous load is cancelled.
signal loading_cancelled(scene_path: String, handle: FlowAsyncLoader.LoadHandle)
## Emitted when transition playback finishes.
signal transition_complete(scene_path: String, metadata: Dictionary)

class FlowPayload extends RefCounted:
	var data: Variant
	var metadata: Dictionary
	var source_scene: StringName
	var created_ms: int

	func _init(payload_data: Variant, payload_metadata: Dictionary, payload_source_scene: StringName) -> void:
		self.data = payload_data
		var safe_metadata := payload_metadata if payload_metadata is Dictionary else {}
		self.metadata = safe_metadata.duplicate(true)
		self.source_scene = payload_source_scene
		self.created_ms = Time.get_ticks_msec()

class FlowStackEntry extends RefCounted:
	var scene_path: String
	var payload: FlowPayload
	var created_ms: int

	func _init(entry_scene_path: String, entry_payload: FlowPayload) -> void:
		self.scene_path = entry_scene_path
		self.payload = entry_payload
		self.created_ms = Time.get_ticks_msec()

var _stack: Array[FlowStackEntry] = []
## When true, FlowManager will publish analytics events to EventBus.
var analytics_enabled: bool = false
var _async_loader: FlowAsyncLoader = FlowAsyncLoader.new()
var _loading_screen_scene: PackedScene = null
var _loading_screen_parent_path: NodePath = NodePath()
var _loading_screen_instance: FlowLoadingScreen = null
var _transition_library: FlowTransitionLibrary = null
var _transition_player_scene: PackedScene = null
var _transition_player: Node = null
var _transition_metadata: Dictionary = {}
var _checkpoint_manager_node: Object = null
var _checkpoint_manager_path: NodePath = NodePath()
var _checkpoint_manager_autoload: StringName = StringName()
var _checkpoint_manager_method: StringName = StringName("on_scene_transition")
var _save_on_transition_enabled: bool = false
var _save_transition_slot: String = "flow_autosave"
var _save_settings_key: StringName = StringName()
var _save_service_node: Object = null
var _settings_service_node: Object = null
var _pending_load: FlowAsyncLoader.LoadHandle = null
var _pending_entry: FlowStackEntry = null
var _pending_operation: StringName = StringName()
var _pending_previous_entry: FlowStackEntry = null
var _pending_metadata: Dictionary = {}

func _ready() -> void:
    if _stack.is_empty():
        var current_scene := get_tree().current_scene
        if current_scene:
            var entry := FlowStackEntry.new(current_scene.scene_file_path, FlowPayload.new(null, {}, current_scene.scene_file_path))
            _stack.append(entry)
    _ensure_transition_player()
    set_process(true)

func _process(_delta: float) -> void:
	if not has_pending_load():
		return
	_async_loader.poll(_pending_load)
	if _pending_load.status == FlowAsyncLoader.LoadStatus.LOADING:
		loading_progress.emit(_pending_load.scene_path, _pending_load.progress, _pending_metadata)
		_update_loading_screen(_pending_load.progress, _pending_metadata)
		_emit_loading_event(EventTopics.FLOW_LOADING_PROGRESS)
		return
	if _pending_load.status == FlowAsyncLoader.LoadStatus.LOADED:
		_finalize_pending_load(true)
	elif _pending_load.status == FlowAsyncLoader.LoadStatus.FAILED:
		_finalize_pending_load(false)
	elif _pending_load.status == FlowAsyncLoader.LoadStatus.CANCELLED:
		_handle_load_cancelled()

## Pushes a scene onto the stack and transitions to it.
## @param scene_path Resource path to the scene to activate.
## @param payload_data Optional payload forwarded to the destination scene.
## @param metadata Optional dictionary of metadata accompanying the payload.
## @return Error code from the scene change operation.
func push_scene(scene_path: String, payload_data: Variant = null, metadata: Dictionary = {}) -> Error:
	var previous_entry := peek_scene()
	_maybe_save_before_transition(previous_entry, OP_PUSH)
	var entry := _create_entry(scene_path, payload_data, metadata)
	_stack.append(entry)
	var err := _change_to(entry)
	if err != OK:
		_stack.pop_back()
		return err
	var previous_scene: String = ""
	if _stack.size() > 1:
		previous_scene = _stack[_stack.size() - 2].scene_path
	_emit_stack_event(EventTopics.FLOW_SCENE_PUSHED, entry, {
		"previous_scene": previous_scene
	})
	_notify_checkpoint_manager(OP_PUSH, previous_entry, entry)
	return err

## Replaces the current scene with a new one.
## @param scene_path Resource path to the replacement scene.
## @param payload_data Optional payload forwarded to the destination scene.
## @param metadata Optional dictionary of metadata accompanying the payload.
## @return Error code from the scene change operation.
func replace_scene(scene_path: String, payload_data: Variant = null, metadata: Dictionary = {}) -> Error:
	var previous_entry := _stack[-1] if _stack.size() > 0 else null
	_maybe_save_before_transition(previous_entry, OP_REPLACE)
	var new_entry := _create_entry(scene_path, payload_data, metadata)
	if _stack.is_empty():
		_stack.append(new_entry)
	else:
		_stack[_stack.size() - 1] = new_entry
	var active := _stack[_stack.size() - 1]
	var err := _change_to(active)
	if err != OK:
		if previous_entry != null:
			_stack[_stack.size() - 1] = previous_entry
		else:
			_stack.clear()
		return err
	var previous_scene: String = previous_entry.scene_path if previous_entry != null else ""
	_emit_stack_event(EventTopics.FLOW_SCENE_REPLACED, active, {
		"previous_scene": previous_scene
	})
	_notify_checkpoint_manager(OP_REPLACE, previous_entry, active)
	return err

## Pops the current scene and returns to the previous one.
## @param payload_data Optional payload forwarded to the restored scene.
## @param metadata Optional dictionary of metadata accompanying the payload.
## @return Error code indicating success or failure.
func pop_scene(payload_data: Variant = null, metadata: Dictionary = {}) -> Error:
	if _stack.size() <= 1:
		return ERROR_NO_PREVIOUS_SCENE
	var removed := _stack[_stack.size() - 1]
	_maybe_save_before_transition(removed, OP_POP)
	_stack.pop_back()
	var target := _stack[_stack.size() - 1]
	if payload_data != null or metadata.size() > 0:
		target.payload = FlowPayload.new(payload_data, metadata, StringName(removed.scene_path))
	var err := _change_to(target)
	if err != OK:
		_stack.append(removed)
		return err
	_emit_stack_event(EventTopics.FLOW_SCENE_POPPED, target, {
		"popped_scene": removed.scene_path
	})
	_notify_checkpoint_manager(OP_POP, removed, target)
	return err

## Peeks at the current stack entry.
## @return FlowStackEntry describing the active scene.
func peek_scene() -> FlowStackEntry:
	if _stack.is_empty():
		return null
	return _stack[_stack.size() - 1]

## Clears the stack, optionally retaining the active scene.
## @param keep_active Whether to keep the active scene entry.
func clear_stack(keep_active: bool = true) -> void:
	if keep_active and _stack.size() > 0:
		var top := _stack[-1]
		_stack = [top]
	else:
		_stack.clear()

func _create_entry(scene_path: String, payload_data: Variant, metadata: Dictionary) -> FlowStackEntry:
	var source := _last_scene_path()
	var payload := FlowPayload.new(payload_data, metadata, source)
	return FlowStackEntry.new(scene_path, payload)

func _last_scene_path() -> StringName:
	if _stack.is_empty():
		var current_scene := _get_active_scene()
		if current_scene == null:
			return StringName()
		return StringName(current_scene.scene_file_path)
	return StringName(_stack[_stack.size() - 1].scene_path)

func _change_to(entry: FlowStackEntry) -> Error:
	if entry.scene_path.is_empty():
		_emit_scene_error(entry.scene_path, ERR_INVALID_PARAMETER, "Scene path is empty.")
		return ERR_INVALID_PARAMETER
	if not ResourceLoader.exists(entry.scene_path):
		_emit_scene_error(entry.scene_path, ERR_FILE_NOT_FOUND, "Scene path not found: %s" % entry.scene_path)
		return ERR_FILE_NOT_FOUND
	var packed := ResourceLoader.load(entry.scene_path)
	if packed == null or not packed is PackedScene:
		_emit_scene_error(entry.scene_path, ERR_FILE_CANT_OPEN, "Scene could not be loaded as PackedScene.")
		return ERR_FILE_CANT_OPEN
	var err := _activate_entry(entry, packed)
	if err != OK:
		_emit_scene_error(entry.scene_path, err, "change_scene_to_packed failed")
	return err

func _activate_entry(entry: FlowStackEntry, packed: PackedScene) -> Error:
    about_to_change.emit(entry.scene_path, entry)
    _play_transition(false, entry)
    var err := _perform_scene_change(packed)
    if err != OK:
        return err
    _deliver_payload(entry)
    _play_transition(true, entry)
    scene_changed.emit(entry.scene_path, entry)
    return OK

func _deliver_payload(entry: FlowStackEntry) -> void:
	var payload := entry.payload
	if payload == null:
		return
	var active_scene := _get_active_scene()
	if active_scene == null:
		return
	active_scene.set_meta(&"flow_payload", payload)
	if active_scene.has_method("receive_flow_payload"):
		active_scene.call_deferred("receive_flow_payload", payload)

func _finalize_pending_load(success: bool) -> void:
	if success:
		_complete_pending_load_success()
	else:
		_handle_load_failure()

func _complete_pending_load_success() -> void:
	var handle := _pending_load
	if handle == null:
		return
	var entry := _pending_entry
	var packed := handle.result
	var err := OK
	if _pending_operation == OP_PUSH:
		_stack.append(entry)
		err = _activate_entry(entry, packed)
	elif _pending_operation == OP_REPLACE:
		if _stack.is_empty():
			_stack.append(entry)
		else:
			_stack[_stack.size() - 1] = entry
		err = _activate_entry(entry, packed)
	else:
		err = ERR_UNCONFIGURED
	if err == OK:
		loading_finished.emit(handle.scene_path, handle)
		_emit_loading_event(EventTopics.FLOW_LOADING_COMPLETED, {"duration_ms": Time.get_ticks_msec() - handle.created_ms})
		_notify_checkpoint_manager(_pending_operation, _pending_previous_entry, entry)
		_hide_loading_screen(true, {"scene_path": entry.scene_path})
		_reset_pending_state()
		return
	if _pending_operation == OP_PUSH and _stack.size() > 0:
		_stack.pop_back()
	elif _pending_operation == OP_REPLACE and _pending_previous_entry != null and _stack.size() > 0:
		_stack[_stack.size() - 1] = _pending_previous_entry
	_emit_scene_error(entry.scene_path, err, "Async scene activation failed")
	_emit_loading_event(EventTopics.FLOW_LOADING_FAILED, {"error": err})
	_hide_loading_screen(false, {"scene_path": entry.scene_path, "error": err})
	_reset_pending_state()

func _handle_load_failure() -> void:
	var handle := _pending_load
	if handle == null:
		return
	_emit_loading_event(EventTopics.FLOW_LOADING_FAILED, {"error": handle.error})
	if _pending_operation == OP_REPLACE and _pending_previous_entry != null and _stack.size() > 0:
		_stack[_stack.size() - 1] = _pending_previous_entry
	_hide_loading_screen(false, {"scene_path": handle.scene_path, "error": handle.error})
	_emit_scene_error(handle.scene_path, handle.error, "Async scene load failed")
	_reset_pending_state()

func _handle_load_cancelled() -> void:
	var handle := _pending_load
	if handle == null:
		return
	loading_cancelled.emit(handle.scene_path, handle)
	_emit_loading_event(EventTopics.FLOW_LOADING_CANCELLED)
	_hide_loading_screen(false, {"scene_path": handle.scene_path, "cancelled": true})
	_reset_pending_state()

func _reset_pending_state() -> void:
	_pending_load = null
	_pending_entry = null
	_pending_previous_entry = null
	_pending_operation = StringName()
	_pending_metadata = {}

func _ensure_loading_screen(handle: FlowAsyncLoader.LoadHandle) -> void:
    if _loading_screen_scene == null:
        return
    if _loading_screen_instance and is_instance_valid(_loading_screen_instance):
        _loading_screen_instance.begin_loading(handle)
        return
    var parent := _resolve_loading_screen_parent()
    if parent == null:
        return
    var instance := _loading_screen_scene.instantiate()
    if not (instance is FlowLoadingScreen):
        push_warning("FlowManager expected FlowLoadingScreen but received %s" % [instance])
        instance.queue_free()
        return
    _loading_screen_instance = instance
    parent.add_child(instance)
    _loading_screen_instance.begin_loading(handle)

func _update_loading_screen(progress: float, metadata: Dictionary) -> void:
	if _loading_screen_instance and is_instance_valid(_loading_screen_instance):
		_loading_screen_instance.update_progress(progress, metadata)

func _hide_loading_screen(success: bool, metadata: Dictionary) -> void:
    if _loading_screen_instance and is_instance_valid(_loading_screen_instance):
        _loading_screen_instance.finish_loading(success, metadata)
        if success:
            _loading_screen_instance.queue_free()
            _loading_screen_instance = null
    if success:
        _play_transition(true, _pending_entry)

func _resolve_loading_screen_parent() -> Node:
    if _loading_screen_parent_path.is_empty():
        var scene := get_tree().current_scene
        return scene if scene else get_tree().root
    var node := get_node_or_null(_loading_screen_parent_path)
    return node if node else get_tree().root

func _emit_loading_event(topic: StringName, extra: Dictionary = {}) -> void:
    if not analytics_enabled:
        return
    var payload := _build_loading_payload(extra)
    _emit_analytics(topic, payload)

func _build_loading_payload(extra: Dictionary) -> Dictionary:
    var handle := _pending_load
    var payload := {
        "scene_path": StringName(handle.scene_path) if handle else StringName(),
        "operation": String(_pending_operation),
        "progress": handle.progress if handle else 0.0,
        "metadata": _pending_metadata.duplicate(true),
        "seed": handle.seed_snapshot if handle else 0,
        "timestamp_ms": Time.get_ticks_msec(),
        "stack_size": _stack.size()
    }
    for key in extra.keys():
        payload[key] = extra[key]
    return payload

func _resolve_checkpoint_manager() -> Object:
    if Engine.is_editor_hint():
        return null
    if _checkpoint_manager_node:
        if _checkpoint_manager_node is Node and not is_instance_valid(_checkpoint_manager_node):
            _checkpoint_manager_node = null
        else:
            return _checkpoint_manager_node
    if not _checkpoint_manager_path.is_empty():
        var node := get_node_or_null(_checkpoint_manager_path)
        if node:
            _checkpoint_manager_node = node
            return _checkpoint_manager_node
    if not _checkpoint_manager_autoload.is_empty():
        var name := String(_checkpoint_manager_autoload)
        if Engine.has_singleton(name):
            _checkpoint_manager_node = Engine.get_singleton(name)
            return _checkpoint_manager_node
    return null

func _resolve_save_service() -> Object:
    if Engine.is_editor_hint():
        return null
    if _save_service_node:
        if _save_service_node is Node and not is_instance_valid(_save_service_node):
            _save_service_node = null
        else:
            return _save_service_node
    if Engine.has_singleton("SaveService"):
        _save_service_node = Engine.get_singleton("SaveService")
        return _save_service_node
    return null

func _resolve_settings_service() -> Object:
    if Engine.is_editor_hint():
        return null
    if _settings_service_node:
        if _settings_service_node is Node and not is_instance_valid(_settings_service_node):
            _settings_service_node = null
        else:
            return _settings_service_node
    if Engine.has_singleton("SettingsService"):
        _settings_service_node = Engine.get_singleton("SettingsService")
        return _settings_service_node
    return null

func _settings_allows_save() -> bool:
    if _save_settings_key == StringName():
        return true
    var settings_service := _resolve_settings_service()
    if settings_service == null:
        return true
    if settings_service.has_method("get_bool"):
        return settings_service.get_bool(_save_settings_key, true)
    if settings_service.has_method("get_value"):
        return bool(settings_service.get_value(_save_settings_key, true))
    return true

func _maybe_save_before_transition(prev_entry: FlowStackEntry, operation: StringName) -> void:
    if not _save_on_transition_enabled:
        return
    if Engine.is_editor_hint():
        return
    if prev_entry == null:
        return
    if not _settings_allows_save():
        return
    var save_service := _resolve_save_service()
    if save_service == null or not save_service.has_method("save_game"):
        return
    save_service.save_game(_save_transition_slot)
    # Intentionally no analytics emission here; SaveService handles its own telemetry.

func _notify_checkpoint_manager(operation: StringName, previous_entry: FlowStackEntry, active_entry: FlowStackEntry) -> void:
    if Engine.is_editor_hint():
        return
    var manager := _resolve_checkpoint_manager()
    if manager == null or not manager.has_method(_checkpoint_manager_method):
        return
    var payload := {
        "operation": String(operation),
        "scene_path": active_entry.scene_path if active_entry else "",
        "previous_scene": previous_entry.scene_path if previous_entry else "",
        "metadata": active_entry.payload.metadata.duplicate(true) if active_entry and active_entry.payload else {},
        "previous_metadata": previous_entry.payload.metadata.duplicate(true) if previous_entry and previous_entry.payload else {},
        "timestamp_ms": Time.get_ticks_msec()
    }
    manager.call(_checkpoint_manager_method, payload)

func _ensure_transition_player() -> void:
    if _transition_player and is_instance_valid(_transition_player):
        return
    if _transition_player_scene == null:
        return
    var parent := _resolve_loading_screen_parent()
    if parent == null:
        parent = get_tree().root
    var instance := _transition_player_scene.instantiate()
    _transition_player = instance
    parent.add_child(instance)
    if _transition_player.has_signal("transition_finished"):
        _transition_player.transition_finished.connect(_on_transition_finished)

func _play_transition(is_enter: bool, entry: FlowStackEntry) -> void:
    if _transition_library == null:
        return
    var transition_name := entry.payload.metadata.get("transition", "") if entry and entry.payload else ""
    var transition := _transition_library.get_transition(StringName(transition_name))
    if transition == null:
        return
    _ensure_transition_player()
    if not (_transition_player and _transition_player.has_method("play_transition")):
        return
    _transition_metadata = {
        "transition_name": transition.name,
        "enter": is_enter,
        "scene_path": entry.scene_path,
        "payload_metadata": entry.payload.metadata.duplicate(true) if entry and entry.payload else {}
    }
    _transition_player.play_transition(transition, is_enter)

func _emit_stack_event(topic: StringName, entry: FlowStackEntry, extra: Dictionary = {}) -> void:
    if not analytics_enabled:
        return
    var payload := {
        "scene_path": entry.scene_path,
        "source_scene": entry.payload.source_scene if entry.payload else StringName(),
        "stack_size": _stack.size(),
        "timestamp_ms": Time.get_ticks_msec(),
        "metadata": entry.payload.metadata.duplicate(true) if entry.payload and entry.payload.metadata else {}
    }
    for key in extra.keys():
        payload[key] = extra[key]
    _emit_analytics(topic, payload)

func _on_transition_finished(transition: FlowTransition, direction: String) -> void:
    var metadata := _transition_metadata.duplicate(true)
    metadata["direction"] = direction
    metadata["transition_name"] = transition.name
    transition_complete.emit(StringName(metadata.get("scene_path", "")), metadata)
    if analytics_enabled:
        _emit_analytics(EventTopics.FLOW_TRANSITION_COMPLETED, metadata)
    _transition_metadata = {}

func _perform_scene_change(packed: PackedScene) -> Error:
	return get_tree().change_scene_to_packed(packed)

func _get_active_scene() -> Node:
	return get_tree().current_scene

func _emit_analytics(topic: StringName, payload: Dictionary) -> void:
	if not analytics_enabled:
		return
	if Engine.has_singleton("EventBus"):
		EventBus.pub(topic, payload)

func _emit_scene_error(scene_path: String, error_code: int, message: String) -> void:
	scene_error.emit(scene_path, error_code, message)
	_emit_analytics(EventTopics.FLOW_SCENE_ERROR, {
		"scene_path": scene_path,
		"error_code": error_code,
		"message": message,
		"stack_size": _stack.size(),
		"timestamp_ms": Time.get_ticks_msec()
	})
func configure_loading_screen(scene: PackedScene, parent_path: NodePath = NodePath()) -> void:
	_loading_screen_scene = scene
	_loading_screen_parent_path = parent_path
	if _loading_screen_instance and not is_instance_valid(_loading_screen_instance):
		_loading_screen_instance = null

func clear_loading_screen() -> void:
	if _loading_screen_instance and is_instance_valid(_loading_screen_instance):
		_loading_screen_instance.queue_free()
	_loading_screen_instance = null
	_loading_screen_scene = null
	_loading_screen_parent_path = NodePath()

func configure_transition_library(library: FlowTransitionLibrary, player_scene: PackedScene = null) -> void:
    _transition_library = library
    _transition_player_scene = player_scene
    if _transition_player:
        if _transition_player.has_signal("transition_finished") and _transition_player.transition_finished.is_connected(_on_transition_finished):
            _transition_player.transition_finished.disconnect(_on_transition_finished)
        if is_instance_valid(_transition_player):
            _transition_player.queue_free()
        _transition_player = null

func clear_transition_library() -> void:
	_transition_library = null
	_transition_player_scene = null
	if _transition_player and is_instance_valid(_transition_player):
		_transition_player.queue_free()
	_transition_player = null

func configure_checkpoint_manager(config: Dictionary = {}) -> void:
	clear_checkpoint_manager()
	if config.has("node"):
		_checkpoint_manager_node = config.get("node")
	if config.has("node_path"):
		_checkpoint_manager_path = config.get("node_path", NodePath())
	if config.has("autoload"):
		_checkpoint_manager_autoload = StringName(config.get("autoload", ""))
	_checkpoint_manager_method = StringName(config.get("method", "on_scene_transition"))

func clear_checkpoint_manager() -> void:
	_checkpoint_manager_node = null
	_checkpoint_manager_path = NodePath()
	_checkpoint_manager_autoload = StringName()
	_checkpoint_manager_method = StringName("on_scene_transition")

func configure_save_on_transition(config: Dictionary = {}) -> void:
	_save_on_transition_enabled = bool(config.get("enabled", false))
	_save_transition_slot = String(config.get("save_id", _save_transition_slot))
	_save_settings_key = StringName(config.get("settings_key", ""))
	if config.has("node"):
		_save_service_node = config.get("node")
	if not _save_on_transition_enabled:
		_save_service_node = null

func clear_save_on_transition() -> void:
	_save_on_transition_enabled = false
	_save_service_node = null
	_save_settings_key = StringName()

func has_pending_load() -> bool:
	return _pending_load != null and _pending_load.status == FlowAsyncLoader.LoadStatus.LOADING

func push_scene_async(scene_path: String, payload_data: Variant = null, metadata: Dictionary = {}) -> Error:
	if has_pending_load():
		return ERR_BUSY
	var previous_entry := peek_scene()
	_maybe_save_before_transition(previous_entry, OP_PUSH)
	var handle := _async_loader.start(scene_path, metadata)
	if handle.status == FlowAsyncLoader.LoadStatus.FAILED:
		return handle.error
	_pending_entry = _create_entry(scene_path, payload_data, metadata)
	_pending_previous_entry = previous_entry
	_pending_operation = OP_PUSH
	_pending_load = handle
	_pending_metadata = metadata.duplicate(true)
	loading_started.emit(scene_path, handle)
	_ensure_loading_screen(handle)
	_play_transition(false, _pending_entry)
	_emit_loading_event(EventTopics.FLOW_LOADING_STARTED)
	return OK

func replace_scene_async(scene_path: String, payload_data: Variant = null, metadata: Dictionary = {}) -> Error:
	if has_pending_load():
		return ERR_BUSY
	var previous_entry := peek_scene()
	_maybe_save_before_transition(previous_entry, OP_REPLACE)
	var handle := _async_loader.start(scene_path, metadata)
	if handle.status == FlowAsyncLoader.LoadStatus.FAILED:
		return handle.error
	_pending_entry = _create_entry(scene_path, payload_data, metadata)
	_pending_previous_entry = previous_entry
	_pending_operation = OP_REPLACE
	_pending_load = handle
	_pending_metadata = metadata.duplicate(true)
	loading_started.emit(scene_path, handle)
	_ensure_loading_screen(handle)
	_play_transition(false, _pending_entry)
	_emit_loading_event(EventTopics.FLOW_LOADING_STARTED)
	return OK

func cancel_pending_load() -> void:
	if not has_pending_load():
		return
	_async_loader.cancel(_pending_load)
	_handle_load_cancelled()
