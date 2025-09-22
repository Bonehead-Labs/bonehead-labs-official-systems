class_name _PlayerController2D
extends CharacterBody2D

## Flexible 2D player controller driven by MovementConfig.

signal player_spawned(position: Vector2)
signal player_jumped()
signal player_landed()
signal state_changed(previous: StringName, current: StringName)
signal state_event(event: StringName, data: Variant)

const EventTopics = preload("res://EventBus/EventTopics.gd")

@export var movement_config: MovementConfig
@export var manual_input_enabled: bool = false
@export var manual_input_vector: Vector2 = Vector2.ZERO
@export var state_machine_path: NodePath

var _velocity: Vector2
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false
var _state_machine: StateMachine

func _ready() -> void:
    _velocity = Vector2.ZERO
    if movement_config == null:
        movement_config = MovementConfig.new()
    _resolve_state_machine()

func _process(delta: float) -> void:
    if _state_machine:
        _state_machine.update_state(delta)

func spawn(position: Vector2) -> void:
    global_position = position
    _velocity = Vector2.ZERO
    player_spawned.emit(position)
    _emit_player_event(EventTopics.PLAYER_SPAWNED, {
        StringName("position"): position
    } as Dictionary[StringName, Variant])

func _physics_process(delta: float) -> void:
    if movement_config == null:
        return
    if _state_machine:
        _state_machine.physics_update_state(delta)
    _apply_horizontal(delta)
    _apply_vertical(delta)
    velocity = _velocity
    move_and_slide()
    _post_move(delta)

func _apply_horizontal(delta: float) -> void:
    var input_dir := _get_horizontal_input()
    var target_speed := input_dir * movement_config.max_speed
    var accel := movement_config.acceleration if is_on_floor() else movement_config.air_acceleration
    var decel := movement_config.deceleration if is_on_floor() else movement_config.air_deceleration
    if abs(target_speed) > abs(_velocity.x):
        _velocity.x = move_toward(_velocity.x, target_speed, accel * delta)
    else:
        _velocity.x = move_toward(_velocity.x, target_speed, decel * delta)
    if is_on_floor() and is_equal_approx(input_dir, 0.0) and movement_config.friction > 0.0:
        _velocity.x = move_toward(_velocity.x, 0.0, movement_config.friction * delta)

func _apply_vertical(delta: float) -> void:
    _update_coyote(delta)
    _update_jump_buffer()
    if _should_start_jump():
        _velocity.y = movement_config.jump_velocity
        player_jumped.emit()
        _emit_player_event(EventTopics.PLAYER_JUMPED, {} as Dictionary[StringName, Variant])
        _jump_buffer_timer = 0.0
        _coyote_timer = 0.0
    else:
        _velocity.y += movement_config.gravity * delta
    if _velocity.y > movement_config.max_fall_speed:
        _velocity.y = movement_config.max_fall_speed

func _post_move(delta: float) -> void:
    if is_on_floor():
        if _was_on_floor == false:
            player_landed.emit()
            _emit_player_event(EventTopics.PLAYER_LANDED, {} as Dictionary[StringName, Variant])
        _coyote_timer = movement_config.coyote_time
    else:
        _coyote_timer = max(_coyote_timer - delta, 0.0)
    _was_on_floor = is_on_floor()
    if Input.is_action_just_pressed(movement_config.jump_action):
        _jump_buffer_timer = movement_config.jump_buffer_time
    else:
        _jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

func _update_coyote(delta: float) -> void:
    if is_on_floor():
        _coyote_timer = movement_config.coyote_time
    else:
        _coyote_timer = max(_coyote_timer - delta, 0.0)

func _update_jump_buffer() -> void:
    if Input.is_action_just_pressed(movement_config.jump_action):
        _jump_buffer_timer = movement_config.jump_buffer_time

func _should_start_jump() -> bool:
    if _jump_buffer_timer <= 0.0:
        return false
    if _coyote_timer > 0.0:
        return true
    return false

func _get_horizontal_input() -> float:
    if manual_input_enabled:
        return clamp(manual_input_vector.x, -1.0, 1.0)
    if movement_config.use_axis_input:
        return clamp(Input.get_axis(movement_config.axis_negative_action, movement_config.axis_positive_action), -1.0, 1.0)
    var input_value := 0.0
    if Input.is_action_pressed(movement_config.move_left_action):
        input_value -= 1.0
    if Input.is_action_pressed(movement_config.move_right_action):
        input_value += 1.0
    return clamp(input_value, -1.0, 1.0)

func set_manual_input(vector: Vector2) -> void:
    manual_input_vector = vector

func enable_manual_input(enabled: bool) -> void:
    manual_input_enabled = enabled

func set_config(config: MovementConfig) -> void:
    movement_config = config

func get_velocity() -> Vector2:
    return _velocity

func _resolve_state_machine() -> void:
    if state_machine_path.is_empty():
        return
    var node := get_node_or_null(state_machine_path)
    if node is StateMachine:
        _state_machine = node
        var context := {
            StringName("movement_config"): movement_config,
            StringName("controller"): self
        } as Dictionary[StringName, Variant]
        _state_machine.set_context(context)
        if not _state_machine.state_changed.is_connected(_on_state_changed):
            _state_machine.state_changed.connect(_on_state_changed)
        if not _state_machine.state_event.is_connected(_on_state_event):
            _state_machine.state_event.connect(_on_state_event)

func _on_state_changed(previous: StringName, current: StringName) -> void:
    state_changed.emit(previous, current)
    _emit_player_event(EventTopics.PLAYER_STATE_CHANGED, {
        StringName("previous"): previous,
        StringName("current"): current
    } as Dictionary[StringName, Variant])

func _on_state_event(event: StringName, data: Variant) -> void:
    state_event.emit(event, data)
    _emit_player_event(EventTopics.PLAYER_STATE_CHANGED, {
        StringName("event"): event,
        StringName("data"): data
    } as Dictionary[StringName, Variant])

func _emit_player_event(topic: StringName, payload: Dictionary[StringName, Variant]) -> void:
    if Engine.has_singleton("EventBus"):
        payload[StringName("timestamp_ms")] = Time.get_ticks_msec()
        Engine.get_singleton("EventBus").call("pub", topic, payload)
*** End Patch
