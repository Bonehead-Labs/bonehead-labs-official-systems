extends "res://addons/gut/test.gd"

const FLOW_MANAGER_PATH: String = "res://SceneFlow/FlowManager.gd"
const SCENE_ALPHA_PATH: String = "res://SceneFlow/TestScenes/SceneAlpha.tscn"
const SCENE_BETA_PATH: String = "res://SceneFlow/TestScenes/SceneBeta.tscn"
const TRANSITION_PLAYER_STUB_PATH: String = "res://SceneFlow/TestScenes/TransitionPlayerStub.tscn"

const FlowManagerScript = preload("res://SceneFlow/FlowManager.gd")
const AsyncSceneLoaderScript = preload("res://SceneFlow/AsyncSceneLoader.gd")
const TransitionLibraryScript = preload("res://SceneFlow/Transitions/TransitionLibrary.gd")
const TransitionResourceScript = preload("res://SceneFlow/Transitions/TransitionResource.gd")

class TestFlowManager extends FlowManagerScript:
	var fake_scene: Node = null
	var forced_error: Error = OK
	var instantiated_scenes: Array[Node] = []

	func _perform_scene_change(packed: PackedScene) -> Error:
		if forced_error != OK:
			return forced_error
		fake_scene = packed.instantiate()
		if fake_scene.has_method("set_scene_file_path"):
			fake_scene.set_scene_file_path(packed.resource_path)
		instantiated_scenes.append(fake_scene)
		return OK

	func _get_active_scene() -> Node:
		return fake_scene

	func cleanup_instances() -> void:
		for s in instantiated_scenes:
			if is_instance_valid(s):
				s.free()
		instantiated_scenes.clear()
		fake_scene = null

class StubAsyncLoader extends FlowAsyncLoader:
	var steps: Array = []
	var cancelled: bool = false
	var handle: FlowAsyncLoader.LoadHandle = null

	func configure_steps(step_definitions: Array) -> void:
		steps = []
		for d in step_definitions:
			steps.append(d.duplicate(true))

	func start(scene_path: String, metadata: Dictionary = {}) -> FlowAsyncLoader.LoadHandle:
		handle = FlowAsyncLoader.LoadHandle.new(scene_path, metadata)
		handle.status = FlowAsyncLoader.LoadStatus.LOADING
		handle.progress = 0.0
		handle.error = OK
		cancelled = false
		return handle

	func poll(active_handle: FlowAsyncLoader.LoadHandle) -> void:
		if active_handle == null or active_handle != handle:
			return
		if cancelled:
			handle.status = FlowAsyncLoader.LoadStatus.CANCELLED
			return
		if steps.is_empty():
			return
		var step: Dictionary = _pop_front()
		handle.progress = float(step.get("progress", handle.progress))
		handle.error = step.get("error", handle.error)
		handle.result = step.get("result", handle.result)
		handle.status = step.get("status", handle.status)

	func cancel(active_handle: FlowAsyncLoader.LoadHandle) -> void:
		if active_handle == null or active_handle != handle:
			return
		cancelled = true
		handle.status = FlowAsyncLoader.LoadStatus.CANCELLED

	func has_pending_requests() -> bool:
		return handle != null and handle.status == FlowAsyncLoader.LoadStatus.LOADING

	func clear() -> void:
		steps.clear()
		handle = null
		cancelled = false

	func _pop_front() -> Dictionary:
		if steps.is_empty():
			return {}
		var value: Dictionary = steps[0] as Dictionary
		steps.remove_at(0)
		return value

class StubCheckpointManager extends Node:
	var calls: Array = []
	func on_scene_transition(payload: Dictionary) -> void:
		calls.append(payload.duplicate(true))

class StubSaveService extends Node:
	var saves: Array = []
	func save_game(save_id: String) -> bool:
		saves.append(save_id)
		return true

func _configure_transition_library() -> void:
	var library := FlowTransitionLibrary.new()
	var transition := FlowTransition.new()
	transition.name = "fade"
	transition.enter_animation = "enter"
	transition.exit_animation = "exit"
	library.default_transition = transition
	var player_scene := load(TRANSITION_PLAYER_STUB_PATH)
	manager.configure_transition_library(library, player_scene)

var manager: TestFlowManager
var analytics_events: Array = []
var push_callable: Callable
var error_callable: Callable

func before_each() -> void:
	analytics_events.clear()
	push_callable = Callable(self, "_on_flow_push")
	error_callable = Callable(self, "_on_flow_error")

	manager = TestFlowManager.new()
	get_tree().root.add_child(manager)
	await manager.ready
	manager.analytics_enabled = false
	manager.clear_stack(false)

func after_each() -> void:
	EventBus.unsub(EventTopics.FLOW_SCENE_PUSHED, push_callable)
	EventBus.unsub(EventTopics.FLOW_SCENE_ERROR, error_callable)
	if is_instance_valid(manager):
		manager.cleanup_instances()
		manager.queue_free()
		await get_tree().process_frame

func _on_flow_push(payload: Dictionary) -> void:
	analytics_events.append({"topic": EventTopics.FLOW_SCENE_PUSHED, "payload": payload})

func _on_flow_error(payload: Dictionary) -> void:
	analytics_events.append({"topic": EventTopics.FLOW_SCENE_ERROR, "payload": payload})

func test_push_scene_tracks_payload() -> void:
	var metadata := {"tag": "alpha"}
	var err := manager.push_scene(SCENE_ALPHA_PATH, {"value": 42}, metadata)
	assert_eq(err, OK)
	var entry := manager.peek_scene()
	assert_not_null(entry)
	assert_eq(entry.scene_path, SCENE_ALPHA_PATH)
	assert_eq(entry.payload.metadata.get("tag"), "alpha")
	assert_eq(entry.payload.data.get("value"), 42)
	var active_scene := manager._get_active_scene()
	assert_not_null(active_scene)
	assert_eq(active_scene.get("last_payload"), entry.payload)


func test_replace_scene_emits_signals() -> void:
	var flags := {"about": false, "changed": false}
	manager.about_to_change.connect(func(scene_path: String, _entry):
		flags["about"] = flags["about"] or scene_path == SCENE_BETA_PATH
	)
	manager.scene_changed.connect(func(scene_path: String, _entry):
		flags["changed"] = flags["changed"] or scene_path == SCENE_BETA_PATH
	)
	assert_eq(manager.push_scene(SCENE_ALPHA_PATH), OK)
	var err := manager.replace_scene(SCENE_BETA_PATH)
	assert_eq(err, OK)
	assert_true(flags["about"], "about_to_change should fire for replacement")
	assert_true(flags["changed"], "scene_changed should fire for replacement")
	assert_eq(manager.peek_scene().scene_path, SCENE_BETA_PATH)

func test_pop_scene_restores_previous_payload() -> void:
	assert_eq(manager.push_scene(SCENE_ALPHA_PATH, "alpha"), OK)
	assert_eq(manager.push_scene(SCENE_BETA_PATH, "beta"), OK)
	var err := manager.pop_scene("return", {"reason": "test"})
	assert_eq(err, OK)
	var entry := manager.peek_scene()
	assert_eq(entry.scene_path, SCENE_ALPHA_PATH)
	assert_eq(entry.payload.data, "return")
	assert_eq(entry.payload.metadata.get("reason"), "test")
	assert_eq(entry.payload.source_scene, SCENE_BETA_PATH)
	assert_eq(manager._get_active_scene().get("last_payload"), entry.payload)

func test_analytics_events_fire_when_enabled() -> void:
	EventBus.sub(EventTopics.FLOW_SCENE_PUSHED, push_callable)
	EventBus.sub(EventTopics.FLOW_SCENE_ERROR, error_callable)
	manager.analytics_enabled = true

	assert_eq(manager.push_scene(SCENE_ALPHA_PATH), OK)
	assert_eq(analytics_events.size(), 1)
	assert_eq(analytics_events[0]["topic"], EventTopics.FLOW_SCENE_PUSHED)
	assert_eq(analytics_events[0]["payload"]["scene_path"], SCENE_ALPHA_PATH)

	var invalid_path := "res://SceneFlow/TestScenes/NotReal.tscn"
	var err := manager.replace_scene(invalid_path)
	assert_eq(err, ERR_FILE_NOT_FOUND)
	assert_eq(analytics_events.size(), 2)
	assert_eq(analytics_events[1]["topic"], EventTopics.FLOW_SCENE_ERROR)
	assert_eq(analytics_events[1]["payload"]["scene_path"], invalid_path)

func test_push_scene_async_completes_successfully() -> void:
	var loader_stub := StubAsyncLoader.new()
	var packed := load(SCENE_ALPHA_PATH)
	loader_stub.configure_steps([
		{"progress": 0.5, "status": FlowAsyncLoader.LoadStatus.LOADING},
		{"progress": 1.0, "status": FlowAsyncLoader.LoadStatus.LOADED, "result": packed}
	])
	manager._async_loader = loader_stub
	var progress_calls: Array = []
	var flags := {"finished": false}
	manager.loading_progress.connect(func(_path: String, progress: float, _meta: Dictionary):
		progress_calls.append(progress)
	)
	manager.loading_finished.connect(func(_path: String, _handle: FlowAsyncLoader.LoadHandle):
		flags["finished"] = true
	)
	var err := manager.push_scene_async(SCENE_ALPHA_PATH, {"async": true})
	assert_eq(err, OK)
	manager._process(0.0)
	manager._process(0.0)
	assert_true(flags["finished"])
	assert_false(manager.has_pending_load())
	assert_eq(progress_calls.size(), 1)
	assert_eq(progress_calls[0], 0.5)
	var entry := manager.peek_scene()
	assert_not_null(entry)
	assert_eq(entry.scene_path, SCENE_ALPHA_PATH)


func test_replace_scene_async_failure_rolls_back() -> void:
	assert_eq(manager.push_scene(SCENE_ALPHA_PATH), OK)
	var loader_stub := StubAsyncLoader.new()
	loader_stub.configure_steps([
		{"status": FlowAsyncLoader.LoadStatus.FAILED, "error": ERR_CANT_OPEN}
	])
	manager._async_loader = loader_stub
	var flags := {"error": false}
	manager.scene_error.connect(func(scene_path: String, error_code: int, _message: String):
		if scene_path == SCENE_BETA_PATH and error_code == ERR_CANT_OPEN:
			flags["error"] = true
	)
	var err := manager.replace_scene_async(SCENE_BETA_PATH)
	assert_eq(err, OK)
	manager._process(0.0)
	assert_false(manager.has_pending_load())
	assert_true(flags["error"])
	var entry := manager.peek_scene()
	assert_not_null(entry)
	assert_eq(entry.scene_path, SCENE_ALPHA_PATH)

func test_cancel_pending_async_load() -> void:
	var loader_stub := StubAsyncLoader.new()
	loader_stub.configure_steps([
		{"progress": 0.25, "status": FlowAsyncLoader.LoadStatus.LOADING}
	])
	manager._async_loader = loader_stub
	var flags := {"cancelled": false}
	manager.loading_cancelled.connect(func(_path: String, _handle: FlowAsyncLoader.LoadHandle):
		flags["cancelled"] = true
	)
	var err := manager.push_scene_async(SCENE_ALPHA_PATH)
	assert_eq(err, OK)
	manager.cancel_pending_load()
	assert_false(manager.has_pending_load())
	assert_true(flags["cancelled"])

func test_transition_complete_signal_on_push() -> void:
	_configure_transition_library()
	var events: Array = []
	manager.transition_complete.connect(func(scene_path: String, metadata: Dictionary):
		events.append({"scene": scene_path, "direction": metadata.get("direction", ""), "name": metadata.get("transition_name", "")})
	)
	var err := manager.push_scene(SCENE_ALPHA_PATH, null, {"transition": "fade"})
	assert_eq(err, OK)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(events.size(), 2)
	assert_eq(events[0]["direction"], "exit")
	assert_eq(events[1]["direction"], "enter")
	assert_eq(events[0]["name"], "fade")
	assert_eq(events[1]["scene"], SCENE_ALPHA_PATH)

func test_transition_complete_signal_on_async_load() -> void:
	_configure_transition_library()
	var loader_stub := StubAsyncLoader.new()
	var packed := load(SCENE_ALPHA_PATH)
	loader_stub.configure_steps([
		{"progress": 1.0, "status": FlowAsyncLoader.LoadStatus.LOADED, "result": packed}
	])
	manager._async_loader = loader_stub
	var events: Array = []
	manager.transition_complete.connect(func(scene_path: String, metadata: Dictionary):
		events.append({"scene": scene_path, "direction": metadata.get("direction", "")})
	)
	var err := manager.push_scene_async(SCENE_ALPHA_PATH, null, {"transition": "fade"})
	assert_eq(err, OK)
	manager._process(0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(manager.has_pending_load())
	assert_true(events.size() >= 1)
	assert_eq(events.back()["direction"], "enter")

func test_checkpoint_manager_notified_on_push() -> void:
	var checkpoint := StubCheckpointManager.new()
	get_tree().root.add_child(checkpoint)
	manager.configure_checkpoint_manager({"node": checkpoint})
	var err := manager.push_scene(SCENE_ALPHA_PATH)
	assert_eq(err, OK)
	assert_eq(checkpoint.calls.size(), 1)
	var payload: Dictionary = checkpoint.calls[0]
	assert_eq(payload.get("operation"), "push")
	assert_eq(payload.get("scene_path"), SCENE_ALPHA_PATH)
	checkpoint.queue_free()

func test_save_service_invoked_before_transition() -> void:
	var save_stub := StubSaveService.new()
	manager.configure_save_on_transition({"enabled": true, "save_id": "flow_test", "node": save_stub})
	var err := manager.push_scene(SCENE_ALPHA_PATH)
	assert_eq(err, OK)
	assert_eq(save_stub.saves.size(), 1)
	assert_eq(save_stub.saves[0], "flow_test")
