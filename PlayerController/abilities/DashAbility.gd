class_name DashAbility
extends "res://PlayerController/Ability.gd"

## Dash ability that overrides player motion for a fixed burst.

@export var dash_speed: float = 700.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0
@export var motion_priority_value: float = 100.0

var _dash_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _is_dashing: bool = false
var _dash_direction: Vector2 = Vector2.ZERO

func _on_activated() -> void:
	_reset_state()

func _on_deactivated() -> void:
	_is_dashing = false
	_dash_timer = 0.0

func on_update(delta: float) -> void:
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_end_dash()
	elif _cooldown_timer > 0.0:
		_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)

func on_input_action(action: StringName, edge: String, device: int, _event: InputEvent) -> void:
	if action != StringName("dash") or edge != "pressed":
		return
	if not can_dash():
		emit_debug_log("Dash blocked (cooldown or active)", "DEBUG", {StringName("cooldown"): _cooldown_timer})
		return
	_start_dash(device)

func can_dash() -> bool:
	return not _is_dashing and _cooldown_timer <= 0.0

func is_overriding_motion() -> bool:
	return _is_dashing

func motion_priority() -> float:
	return motion_priority_value

func motion_velocity() -> Vector2:
	return _dash_direction * dash_speed if _is_dashing else Vector2.ZERO

func blocks_state_kind(kind: StringName) -> bool:
	return _is_dashing and kind == StringName("physics")

func serialize_state() -> Dictionary:
	return {
		"cooldown": _cooldown_timer,
		"is_dashing": _is_dashing,
		"dash_timer": _dash_timer,
		"dash_direction": _dash_direction
	}

func deserialize_state(data: Dictionary) -> void:
	_cooldown_timer = data.get("cooldown", 0.0)
	_is_dashing = data.get("is_dashing", false)
	_dash_timer = data.get("dash_timer", 0.0)
	_dash_direction = data.get("dash_direction", Vector2.ZERO)
	if _is_dashing and _dash_timer <= 0.0:
		_is_dashing = false

func _start_dash(_device: int) -> void:
	_is_dashing = true
	_dash_timer = dash_duration
	_dash_direction = _resolve_dash_direction()
	_cooldown_timer = dash_cooldown
	emit_debug_log("Dash started", "INFO", {StringName("direction"): _dash_direction, StringName("speed"): dash_speed})
	var event_bus: Node = null
	if Engine.has_singleton("EventBus"):
		event_bus = Engine.get_singleton("EventBus")
	emit_lifecycle_event(event_bus, EventTopics.PLAYER_ABILITY_USED, {
		StringName("ability_type"): StringName("dash"),
		StringName("direction"): _dash_direction,
		StringName("speed"): dash_speed
	})

func _end_dash() -> void:
	_is_dashing = false
	_dash_timer = 0.0
	_dash_direction = Vector2.ZERO

func _reset_state() -> void:
	_is_dashing = false
	_dash_timer = 0.0
	_cooldown_timer = 0.0
	_dash_direction = Vector2.ZERO

func _resolve_dash_direction() -> Vector2:
	var controller = get_controller()
	if controller == null:
		return Vector2.RIGHT
	var input_vector: Vector2 = controller.get_movement_input() if controller.has_method("get_movement_input") else Vector2.ZERO
	if input_vector.length() < 0.1:
		var facing: float = signf(controller.get("scale").x) if controller.has_method("get") else 1.0
		return Vector2(facing if facing != 0.0 else 1.0, 0.0).normalized()
	return input_vector.normalized()
