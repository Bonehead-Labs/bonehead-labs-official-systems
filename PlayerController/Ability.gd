class_name Ability
extends RefCounted

## Base contract for modular player abilities managed by AbilityManager.

const EventTopics = preload("res://EventBus/EventTopics.gd")

var _controller: Node = null
var _ability_id: StringName = StringName()
var _is_active: bool = false
var _was_setup: bool = false

func setup(controller: Node, ability_id: StringName) -> void:
	_controller = controller
	_ability_id = ability_id
	_was_setup = true
	_on_setup()

func activate() -> void:
	if not _was_setup:
		push_warning("Ability %s activated before setup" % [_ability_id])
	if _is_active:
		return
	_is_active = true
	_on_activated()

func deactivate() -> void:
	if not _is_active:
		return
	_is_active = false
	_on_deactivated()

func is_active() -> bool:
	return _is_active

func handle_input_action(action: StringName, edge: String, device: int, event: InputEvent) -> void:
	if not _is_active:
		return
	on_input_action(action, edge, device, event)

func handle_input_axis(axis: StringName, value: float, device: int) -> void:
	if not _is_active:
		return
	on_input_axis(axis, value, device)

func on_update(_delta: float) -> void:
	pass

func on_physics_update(_delta: float) -> void:
	pass

func on_input_action(_action: StringName, _edge: String, _device: int, _event: InputEvent) -> void:
	pass

func on_input_axis(_axis: StringName, _value: float, _device: int) -> void:
	pass

func is_overriding_motion() -> bool:
	return false

func motion_priority() -> float:
	return 0.0

func motion_velocity() -> Vector2:
	return Vector2.ZERO

func blocks_state_kind(_kind: StringName) -> bool:
	return false

func get_controller() -> Node:
	return _controller

func get_ability_id() -> StringName:
	return _ability_id

func emit_lifecycle_event(event_bus: Node, topic: StringName, payload: Dictionary[StringName, Variant]) -> void:
	if event_bus == null:
		return
	payload[StringName("ability_id")] = _ability_id
	payload[StringName("timestamp_ms")] = Time.get_ticks_msec()
	event_bus.call_deferred("pub", topic, payload)

func emit_debug_log(message: String, level: String = "INFO", extra: Dictionary = {}) -> void:
	if Engine.has_singleton("EventBus"):
		var payload: Dictionary[StringName, Variant] = extra.duplicate(true) as Dictionary[StringName, Variant]
		payload[StringName("message")] = message
		payload[StringName("level")] = level
		payload[StringName("ability_id")] = _ability_id
		payload[StringName("source")] = StringName("Ability.%s" % [_ability_id])
		Engine.get_singleton("EventBus").call_deferred("pub", EventTopics.DEBUG_LOG, payload)

func serialize_state() -> Dictionary:
	return {}

func deserialize_state(_data: Dictionary) -> void:
	pass

func _on_setup() -> void:
	pass

func _on_activated() -> void:
	pass

func _on_deactivated() -> void:
	pass
