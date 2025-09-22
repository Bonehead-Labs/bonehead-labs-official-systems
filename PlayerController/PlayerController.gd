class_name _PlayerController2D
extends CharacterBody2D

## Flexible 2D player controller driven by MovementConfig and a reusable StateMachine.

signal player_spawned(position: Vector2)
signal player_jumped()
signal player_landed()
signal state_changed(previous: StringName, current: StringName)
signal state_event(event: StringName, data: Variant)
signal interaction_available_changed(available: bool)
signal ability_registered(ability_id: StringName, ability: Node)
signal ability_unregistered(ability_id: StringName)

const EventTopics = preload("res://EventBus/EventTopics.gd")
const MovementConfigScript = preload("res://PlayerController/MovementConfig.gd")
const StateMachineScript = preload("res://systems/fsm/StateMachine.gd")
const IdleStateScript = preload("res://PlayerController/states/PlayerStateIdle.gd")
const MoveStateScript = preload("res://PlayerController/states/PlayerStateMove.gd")
const JumpStateScript = preload("res://PlayerController/states/PlayerStateJump.gd")
const FallStateScript = preload("res://PlayerController/states/PlayerStateFall.gd")
const InteractionDetectorScript = preload("res://PlayerController/InteractionDetector.gd")
const AbilityScript = preload("res://PlayerController/Ability.gd")

const STATE_IDLE := StringName("idle")
const STATE_MOVE := StringName("move")
const STATE_JUMP := StringName("jump")
const STATE_FALL := StringName("fall")

@export var movement_config: MovementConfigScript
@export var manual_input_enabled: bool = false
@export var manual_input_vector: Vector2 = Vector2.ZERO
@export var state_machine_path: NodePath
@export var enable_interaction_detector: bool = true
@export var interaction_detector_range: float = 32.0

var _velocity: Vector2 = Vector2.ZERO
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false
var _state_machine: StateMachine
var _input_service_connected: bool = false
var _axis_values: Dictionary[StringName, float] = {}
var _interaction_detector: InteractionDetectorScript = null
var _abilities: Dictionary[StringName, Node] = {}

func _ready() -> void:
    if movement_config == null:
        movement_config = MovementConfigScript.new()
    _resolve_state_machine()
    _setup_interaction_detector()
    _connect_input_service()
    _was_on_floor = is_on_floor()

func _process(delta: float) -> void:
    if _state_machine:
        _state_machine.update_state(delta)

    # Update active abilities
    for ability in _abilities.values():
        ability.update_state(delta)

func _physics_process(delta: float) -> void:
    if movement_config == null:
        return
    if _state_machine:
        _refresh_state_context()
        _state_machine.physics_update_state(delta)
    velocity = _velocity
    move_and_slide()
    _update_after_physics(delta)

func spawn(spawn_position: Vector2) -> void:
    """Teleport the player to a spawn position and emit analytics hooks."""
    global_position = spawn_position
    _velocity = Vector2.ZERO
    player_spawned.emit(spawn_position)
    _emit_player_event(EventTopics.PLAYER_SPAWNED, {
        StringName("position"): spawn_position
    } as Dictionary[StringName, Variant])

func set_manual_input(vector: Vector2) -> void:
    manual_input_vector = vector

func enable_manual_input(enabled: bool) -> void:
    manual_input_enabled = enabled

func set_config(config: MovementConfigScript) -> void:
    movement_config = config
    _refresh_state_context()

func get_controller_velocity() -> Vector2:
    return _velocity

func register_additional_state(state_id: StringName, resource: Resource) -> void:
    """Register a custom ability state with the underlying StateMachine."""
    if _state_machine:
        _state_machine.register_state(state_id, resource)

func transition_to_state(state_id: StringName, payload: Dictionary[StringName, Variant] = {}) -> Error:
    """Request a transition to a specific state, typically used by abilities."""
    if _state_machine == null:
        return ERR_DOES_NOT_EXIST
    return _state_machine.transition_to(state_id, payload)

func get_current_state() -> StringName:
    return _state_machine.get_current_state() if _state_machine else StringName()

func enable_gameplay_input(enabled: bool) -> void:
    """Enable or disable gameplay input context."""
    if Engine.has_singleton("InputService"):
        var input_service := Engine.get_singleton("InputService") as Object
        if input_service and input_service.has_method("enable_context"):
            input_service.call("enable_context", "gameplay", enabled)

func is_platformer_mode() -> bool:
    return movement_config != null and movement_config.movement_mode == 0  # MovementMode.PLATFORMER

func is_top_down_mode() -> bool:
    return movement_config != null and movement_config.movement_mode == 1  # MovementMode.TOP_DOWN

func get_movement_input() -> Vector2:
    var input_vector := manual_input_vector if manual_input_enabled else _sample_input()
    if input_vector.length() > 1.0:
        input_vector = input_vector.normalized()
    return _apply_deadzone(input_vector)

func move_platformer_horizontal(input_dir: float, delta: float, is_airborne: bool) -> void:
    var target_speed: float = input_dir * movement_config.max_speed
    var accel: float = movement_config.air_acceleration if is_airborne else movement_config.acceleration
    var decel: float = movement_config.air_deceleration if is_airborne else movement_config.deceleration
    if abs(target_speed) > abs(_velocity.x):
        _velocity.x = move_toward(_velocity.x, target_speed, accel * delta)
    else:
        _velocity.x = move_toward(_velocity.x, target_speed, decel * delta)
    if not is_airborne and is_equal_approx(input_dir, 0.0) and movement_config.friction > 0.0:
        _velocity.x = move_toward(_velocity.x, 0.0, movement_config.friction * delta)

func move_top_down(input_vector: Vector2, delta: float) -> void:
    var target_velocity := input_vector * movement_config.max_speed
    _velocity.x = _move_component(_velocity.x, target_velocity.x, delta, movement_config.acceleration, movement_config.deceleration)
    _velocity.y = _move_component(_velocity.y, target_velocity.y, delta, movement_config.acceleration, movement_config.deceleration)
    if input_vector.length_squared() == 0.0 and movement_config.friction > 0.0:
        _velocity.x = move_toward(_velocity.x, 0.0, movement_config.friction * delta)
        _velocity.y = move_toward(_velocity.y, 0.0, movement_config.friction * delta)

func apply_gravity(delta: float) -> void:
    if not is_platformer_mode():
        return
    _velocity.y += movement_config.gravity * delta
    if _velocity.y > movement_config.max_fall_speed:
        _velocity.y = movement_config.max_fall_speed

func start_jump() -> void:
    _velocity.y = movement_config.jump_velocity
    player_jumped.emit()
    _emit_player_event(EventTopics.PLAYER_JUMPED, {} as Dictionary[StringName, Variant])
    _jump_buffer_timer = 0.0
    _coyote_timer = 0.0

func consume_jump_request() -> bool:
    if not is_platformer_mode() or not movement_config.allow_jump:
        return false
    if _jump_buffer_timer <= 0.0:
        return false
    if not is_on_floor() and _coyote_timer <= 0.0:
        return false
    _jump_buffer_timer = 0.0
    _coyote_timer = 0.0
    return true

func refresh_coyote_timer() -> void:
    if is_platformer_mode():
        _coyote_timer = movement_config.coyote_time

func set_motion_velocity(velocity_value: Vector2) -> void:
    _velocity = velocity_value

func get_motion_velocity() -> Vector2:
    return _velocity

func _exit_tree() -> void:
    _disconnect_input_service()

func _setup_interaction_detector() -> void:
    if not enable_interaction_detector or Engine.is_editor_hint():
        return

    _interaction_detector = InteractionDetectorScript.new()
    _interaction_detector.interaction_range = interaction_detector_range
    _interaction_detector.interaction_available_changed.connect(_on_interaction_available_changed)
    add_child(_interaction_detector)

func is_interaction_available() -> bool:
    return _interaction_detector != null and _interaction_detector.is_interaction_available()

func get_current_interactable() -> Node:
    return _interaction_detector.get_current_interactable() if _interaction_detector else null

func interact() -> void:
    if _interaction_detector:
        _interaction_detector.interact()

func _on_interaction_available_changed(available: bool) -> void:
    interaction_available_changed.emit(available)

func register_ability(ability_id: StringName, ability: Node) -> void:
    if _abilities.has(ability_id):
        push_warning("Ability '%s' is already registered" % ability_id)
        return

    ability.setup(self, ability_id)
    _abilities[ability_id] = ability
    ability_registered.emit(ability_id, ability)

func unregister_ability(ability_id: StringName) -> void:
    if not _abilities.has(ability_id):
        push_warning("Ability '%s' is not registered" % ability_id)
        return

    var ability := _abilities[ability_id]
    _abilities.erase(ability_id)
    ability.deactivate()
    ability_unregistered.emit(ability_id)

func get_ability(ability_id: StringName) -> Node:
    return _abilities.get(ability_id, null)

func activate_ability(ability_id: StringName) -> void:
    var ability := get_ability(ability_id)
    if ability:
        ability.activate()

func deactivate_ability(ability_id: StringName) -> void:
    var ability := get_ability(ability_id)
    if ability:
        ability.deactivate()

func _resolve_state_machine() -> void:
    if state_machine_path.is_empty():
        _ensure_state_machine_child()
    var node := get_node_or_null(state_machine_path)
    if node is StateMachine:
        _state_machine = node
        _register_builtin_states()
        _refresh_state_context()
        if not _state_machine.state_changed.is_connected(_on_state_changed):
            _state_machine.state_changed.connect(_on_state_changed)
        if not _state_machine.state_event.is_connected(_on_state_event):
            _state_machine.state_event.connect(_on_state_event)
        if _state_machine.get_current_state() == StringName():
            _state_machine.transition_to(STATE_IDLE)

func _ensure_state_machine_child() -> void:
    if state_machine_path.is_empty():
        var existing := find_child("StateMachine", true, false)
        if existing is StateMachine:
            state_machine_path = existing.get_path()
            return
        var machine := StateMachineScript.new() as StateMachine
        machine.name = "StateMachine"
        add_child(machine)
        await machine.ready
        state_machine_path = machine.get_path()

func _register_builtin_states() -> void:
    if _state_machine == null:
        return
    if not _state_machine.has_state(STATE_IDLE):
        _state_machine.register_state(STATE_IDLE, IdleStateScript)
    if not _state_machine.has_state(STATE_MOVE):
        _state_machine.register_state(STATE_MOVE, MoveStateScript)
    if is_platformer_mode():
        if not _state_machine.has_state(STATE_JUMP):
            _state_machine.register_state(STATE_JUMP, JumpStateScript)
        if not _state_machine.has_state(STATE_FALL):
            _state_machine.register_state(STATE_FALL, FallStateScript)
    else:
        _state_machine.unregister_state(STATE_JUMP)
        _state_machine.unregister_state(STATE_FALL)
    var current := _state_machine.get_current_state()
    if current == StringName() or not _state_machine.has_state(current):
        _state_machine.transition_to(STATE_IDLE)

func _refresh_state_context() -> void:
    if _state_machine == null:
        return
    var context := {
        StringName("movement_config"): movement_config,
        StringName("controller"): self
    } as Dictionary[StringName, Variant]
    _state_machine.set_context(context)
    _register_builtin_states()

func _sample_input() -> Vector2:
    if movement_config == null:
        return Vector2.ZERO
    if _input_service_connected and Engine.has_singleton("InputService"):
        var x: float = clamp(_axis_values.get(StringName("move_x"), 0.0), -1.0, 1.0)
        var y: float = clamp(_axis_values.get(StringName("move_y"), 0.0), -1.0, 1.0)
        if not movement_config.allow_vertical_input:
            y = 0.0
        return Vector2(x, y)
    if movement_config.use_axis_input:
        var horizontal := Input.get_axis(movement_config.axis_negative_action, movement_config.axis_positive_action)
        var vertical := Input.get_axis(movement_config.axis_vertical_negative_action, movement_config.axis_vertical_positive_action)
        if not movement_config.allow_vertical_input:
            vertical = 0.0
        return Vector2(horizontal, vertical)
    var input_vector := Vector2.ZERO
    if Input.is_action_pressed(movement_config.move_left_action):
        input_vector.x -= 1.0
    if Input.is_action_pressed(movement_config.move_right_action):
        input_vector.x += 1.0
    if movement_config.allow_vertical_input:
        if Input.is_action_pressed(movement_config.move_up_action):
            input_vector.y -= 1.0
        if Input.is_action_pressed(movement_config.move_down_action):
            input_vector.y += 1.0
    return input_vector

func _apply_deadzone(input_vector: Vector2) -> Vector2:
    var deadzone: float = movement_config.movement_input_deadzone if movement_config else 0.0
    if deadzone <= 0.0:
        return input_vector
    return Vector2(
        0.0 if abs(input_vector.x) < deadzone else input_vector.x,
        0.0 if abs(input_vector.y) < deadzone else input_vector.y
    )

func _move_component(current: float, target: float, delta: float, accel: float, decel: float) -> float:
    if abs(target) > abs(current):
        return move_toward(current, target, accel * delta)
    return move_toward(current, target, decel * delta)

func _update_after_physics(delta: float) -> void:
    if not is_platformer_mode():
        _jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)
        _was_on_floor = true
        return
    var on_floor := is_on_floor()
    if on_floor and not _was_on_floor:
        player_landed.emit()
        _emit_player_event(EventTopics.PLAYER_LANDED, {} as Dictionary[StringName, Variant])
    if on_floor:
        _coyote_timer = movement_config.coyote_time
    else:
        _coyote_timer = max(_coyote_timer - delta, 0.0)
    _jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)
    _was_on_floor = on_floor

func _connect_input_service() -> void:
    if Engine.is_editor_hint() or _input_service_connected:
        return
    if Engine.has_singleton("InputService"):
        var input_service := Engine.get_singleton("InputService") as Object
        if input_service and input_service.has_signal("action_event"):
            input_service.action_event.connect(_on_action_event)
            _input_service_connected = true
        if input_service and input_service.has_signal("axis_event"):
            input_service.axis_event.connect(_on_axis_event)
            _input_service_connected = true
        if input_service and input_service.has_method("enable_context"):
            input_service.call("enable_context", "gameplay", true)

func _disconnect_input_service() -> void:
    if not _input_service_connected or Engine.is_editor_hint():
        return
    if Engine.has_singleton("InputService"):
        var input_service := Engine.get_singleton("InputService") as Object
        if input_service and input_service.has_signal("action_event"):
            input_service.action_event.disconnect(_on_action_event)
        if input_service and input_service.has_signal("axis_event"):
            input_service.axis_event.disconnect(_on_axis_event)
    _input_service_connected = false

func _on_action_event(action: StringName, edge: String, device: int, event: InputEvent) -> void:
    if action == movement_config.jump_action and edge == "pressed":
        _record_jump_buffer()

    # Handle interact input
    if action == movement_config.interact_action and edge == "pressed":
        interact()

    # Forward to abilities
    for ability in _abilities.values():
        ability.handle_input_action(action, edge, device, event)

func _on_axis_event(axis: StringName, value: float, device: int) -> void:
    if not _input_service_connected:
        return
    _axis_values[axis] = clamp(value, -1.0, 1.0)

    # Forward to abilities
    for ability in _abilities.values():
        ability.handle_input_axis(axis, value, device)

func _record_jump_buffer() -> void:
    if not is_platformer_mode() or not movement_config.allow_jump:
        return
    _jump_buffer_timer = movement_config.jump_buffer_time

func _on_state_changed(previous: StringName, current: StringName) -> void:
    state_changed.emit(previous, current)
    _emit_player_event(EventTopics.PLAYER_STATE_CHANGED, {
        StringName("previous"): previous,
        StringName("current"): current
    } as Dictionary[StringName, Variant])

    # Notify abilities of state change
    for ability in _abilities.values():
        ability.handle_state_event(StringName("state_changed"), {
            StringName("previous"): previous,
            StringName("current"): current
        })

func _on_state_event(event: StringName, data: Variant) -> void:
    state_event.emit(event, data)

    # Forward to abilities
    for ability in _abilities.values():
        ability.handle_state_event(event, data)

func _emit_player_event(topic: StringName, payload: Dictionary[StringName, Variant]) -> void:
    if Engine.has_singleton("EventBus"):
        payload[StringName("timestamp_ms")] = Time.get_ticks_msec()
        Engine.get_singleton("EventBus").call("pub", topic, payload)
