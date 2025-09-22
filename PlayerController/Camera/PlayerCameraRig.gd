class_name PlayerCameraRig
extends Node2D

## Smooth-follow camera rig for PlayerController scenes with lookahead and cutscene hooks.

signal cutscene_mode_changed(enabled: bool)
signal follow_suspended_changed(suspended: bool)

@export var camera_path: NodePath
@export var target_path: NodePath
@export var follow_offset: Vector2 = Vector2.ZERO
@export var smoothing_enabled: bool = true
@export var smoothing_speed: float = 6.0
@export var lookahead_enabled: bool = true
@export var lookahead_distance: Vector2 = Vector2(80.0, 40.0)
@export var flow_manager_path: NodePath

var _camera: Camera2D
var _target: Node2D
var _cutscene_target: Node2D
var _suspensions: Dictionary = {}
var _last_known_target_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	_resolve_camera()
	_resolve_target()
	_connect_flow_manager()

func _physics_process(delta: float) -> void:
	if _is_follow_suspended():
		return
	var active_target := _active_target()
	if active_target == null:
		return
	if _is_target_invalid(active_target):
		_resolve_target()
		active_target = _active_target()
		if active_target == null:
			return
	var target_position := active_target.global_position
	if _cutscene_target == null and lookahead_enabled:
		target_position += _compute_lookahead(active_target)
	target_position += follow_offset
	_last_known_target_position = target_position
	if smoothing_enabled:
		var weight: float = clamp(smoothing_speed * delta, 0.0, 1.0)
		global_position = global_position.lerp(target_position, weight)
	else:
		global_position = target_position

func set_target(target: Node2D) -> void:
	_target = target
	if target:
		target_path = target.get_path()
	else:
		target_path = NodePath()

func begin_cutscene(target: Node2D, suspend_follow: bool = false, reason: StringName = StringName("cutscene")) -> void:
	_cutscene_target = target
	cutscene_mode_changed.emit(true)
	if suspend_follow:
		suspend_follow_for(reason)

func end_cutscene(reason: StringName = StringName("cutscene")) -> void:
	_cutscene_target = null
	cutscene_mode_changed.emit(false)
	resume_follow_for(reason)

func suspend_follow_for(reason: StringName) -> void:
	_suspensions[reason] = true
	follow_suspended_changed.emit(_is_follow_suspended())

func resume_follow_for(reason: StringName) -> void:
	if _suspensions.has(reason):
		_suspensions.erase(reason)
		follow_suspended_changed.emit(_is_follow_suspended())

func clear_all_suspensions() -> void:
	_suspensions.clear()
	follow_suspended_changed.emit(false)

func get_camera() -> Camera2D:
	return _camera

func get_last_known_target_position() -> Vector2:
	return _last_known_target_position

func _active_target() -> Node2D:
	if _cutscene_target:
		return _cutscene_target
	return _target

func _is_follow_suspended() -> bool:
	return not _suspensions.is_empty()

func _compute_lookahead(target: Node2D) -> Vector2:
	if not lookahead_enabled:
		return Vector2.ZERO
	if target.has_method("get_motion_velocity"):
		var velocity: Variant = target.call("get_motion_velocity")
		if velocity is Vector2:
			if velocity.length_squared() <= 0.01:
				return Vector2.ZERO
			return velocity.normalized() * lookahead_distance
	elif target is CharacterBody2D:
		var body := target as CharacterBody2D
		if body.velocity.length_squared() > 0.01:
			return body.velocity.normalized() * lookahead_distance
	return Vector2.ZERO

func _resolve_camera() -> void:
	if camera_path != NodePath():
		var node := get_node_or_null(camera_path)
		if node is Camera2D:
			_camera = node
			return
	var camera := find_child("Camera2D", true, false)
	if camera is Camera2D:
		_camera = camera
		camera_path = _camera.get_path()
	elif _camera == null:
		push_warning("PlayerCameraRig requires a Camera2D child.")

func _resolve_target() -> void:
	if target_path != NodePath():
		var node := get_node_or_null(target_path)
		if node is Node2D:
			_target = node
			return
	if _target and not is_instance_valid(_target):
		_target = null

func _connect_flow_manager() -> void:
	var flow_manager: Object = null
	if flow_manager_path != NodePath():
		var node := get_node_or_null(flow_manager_path)
		if node:
			flow_manager = node
	elif Engine.has_singleton("FlowManager"):
		flow_manager = Engine.get_singleton("FlowManager")
	if flow_manager == null:
		return
	if flow_manager.has_signal("about_to_change"):
		flow_manager.connect("about_to_change", Callable(self, "_on_flow_about_to_change"))
	if flow_manager.has_signal("scene_changed"):
		flow_manager.connect("scene_changed", Callable(self, "_on_flow_scene_changed"))

func _on_flow_about_to_change(_scene_path: String, _entry: Variant) -> void:
	suspend_follow_for(StringName("flow_transition"))

func _on_flow_scene_changed(_scene_path: String, _entry: Variant) -> void:
	resume_follow_for(StringName("flow_transition"))

func _is_target_invalid(node: Node2D) -> bool:
	return not is_instance_valid(node)