class_name _FlowManager
extends Node

const FlowAsyncLoader = preload("res://SceneFlow/AsyncSceneLoader.gd")
const FlowLoadingScreen = preload("res://SceneFlow/LoadingScreenContract.gd")

## FlowManager is an autoload singleton responsible for high-level scene navigation.
## It provides a stack-based API for pushing, popping, and replacing scenes.

const ERROR_NO_PREVIOUS_SCENE: int = ERR_DOES_NOT_EXIST

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

class FlowPayload extends RefCounted:
	var data: Variant
	var metadata: Dictionary
	var source_scene: StringName
	var created_ms: int

	func _init(data: Variant, metadata: Dictionary, source_scene: StringName) -> void:
		self.data = data
		var safe_metadata := metadata if metadata is Dictionary else {}
		self.metadata = safe_metadata.duplicate(true)
		self.source_scene = source_scene
		self.created_ms = Time.get_ticks_msec()

class FlowStackEntry extends RefCounted:
	var scene_path: String
	var payload: FlowPayload
	var created_ms: int

	func _init(scene_path: String, payload: FlowPayload) -> void:
		self.scene_path = scene_path
		self.payload = payload
		self.created_ms = Time.get_ticks_msec()

var _stack: Array[FlowStackEntry] = []
## When true, FlowManager will publish analytics events to EventBus.
var analytics_enabled: bool = false
var _async_loader: FlowAsyncLoader = FlowAsyncLoader.new()
var _loading_screen_scene: PackedScene = null
var _loading_screen_parent_path: NodePath = NodePath()
var _loading_screen_instance: FlowLoadingScreen = null
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
	return err

## Replaces the current scene with a new one.
## @param scene_path Resource path to the replacement scene.
## @param payload_data Optional payload forwarded to the destination scene.
## @param metadata Optional dictionary of metadata accompanying the payload.
## @return Error code from the scene change operation.
func replace_scene(scene_path: String, payload_data: Variant = null, metadata: Dictionary = {}) -> Error:
	var new_entry := _create_entry(scene_path, payload_data, metadata)
	var previous_entry := _stack[-1] if _stack.size() > 0 else null
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
	return err

## Pops the current scene and returns to the previous one.
## @param payload_data Optional payload forwarded to the restored scene.
## @param metadata Optional dictionary of metadata accompanying the payload.
## @return Error code indicating success or failure.
func pop_scene(payload_data: Variant = null, metadata: Dictionary = {}) -> Error:
	if _stack.size() <= 1:
		return ERROR_NO_PREVIOUS_SCENE
	var removed := _stack[_stack.size() - 1]
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
	var err := _perform_scene_change(packed)
	if err != OK:
		return err
	_deliver_payload(entry)
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
	if _pending_operation == StringName("push"):
		_stack.append(entry)
		err = _activate_entry(entry, packed)
	elif _pending_operation == StringName("replace"):
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
		_hide_loading_screen(true, {"scene_path": entry.scene_path})
		_reset_pending_state()
		return
	if _pending_operation == StringName("push") and _stack.size() > 0:
		_stack.pop_back()
	elif _pending_operation == StringName("replace") and _pending_previous_entry != null and _stack.size() > 0:
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
	if _pending_operation == StringName("replace") and _pending_previous_entry != null and _stack.size() > 0:
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

func has_pending_load() -> bool:
	return _pending_load != null and _pending_load.status == FlowAsyncLoader.LoadStatus.LOADING

func push_scene_async(scene_path: String, payload_data: Variant = null, metadata: Dictionary = {}) -> Error:
	if has_pending_load():
		return ERR_BUSY
	var handle := _async_loader.start(scene_path, metadata)
	if handle.status == FlowAsyncLoader.LoadStatus.FAILED:
		return handle.error
	_pending_entry = _create_entry(scene_path, payload_data, metadata)
	_pending_previous_entry = null
	_pending_operation = StringName("push")
	_pending_load = handle
	_pending_metadata = metadata.duplicate(true)
	loading_started.emit(scene_path, handle)
	_ensure_loading_screen(handle)
	_emit_loading_event(EventTopics.FLOW_LOADING_STARTED)
	return OK

func replace_scene_async(scene_path: String, payload_data: Variant = null, metadata: Dictionary = {}) -> Error:
	if has_pending_load():
		return ERR_BUSY
	var handle := _async_loader.start(scene_path, metadata)
	if handle.status == FlowAsyncLoader.LoadStatus.FAILED:
		return handle.error
	_pending_entry = _create_entry(scene_path, payload_data, metadata)
	_pending_previous_entry = _stack[-1] if _stack.size() > 0 else null
	_pending_operation = StringName("replace")
	_pending_load = handle
	_pending_metadata = metadata.duplicate(true)
	loading_started.emit(scene_path, handle)
	_ensure_loading_screen(handle)
	_emit_loading_event(EventTopics.FLOW_LOADING_STARTED)
	return OK

func cancel_pending_load() -> void:
	if not has_pending_load():
		return
	_async_loader.cancel(_pending_load)
	_handle_load_cancelled()
