class_name ChaseState
extends FSMState

## State for enemy chase behavior - pursues alert target.

var _enemy: EnemyBase
var _config: EnemyConfig
var _last_known_target_position: Vector2
var _chase_timer: float = 0.0
var _max_chase_time: float = 30.0  # Give up after this many seconds
var _path_update_timer: float = 0.0

func setup(state_machine: StateMachine, state_owner: Node, state_context: Dictionary[StringName, Variant]) -> void:
    super.setup(state_machine, state_owner, state_context)
    _enemy = state_context[&"enemy"]
    _config = state_context[&"config"]

func enter(payload: Dictionary[StringName, Variant] = {}) -> void:
    _chase_timer = 0.0
    _path_update_timer = 0.0

    if _enemy.is_alerted():
        _last_known_target_position = _enemy.get_alert_target().global_position
    else:
        # No target, return to patrol
        machine.transition_to(&"patrol", {&"reason": &"no_target"})

    # Emit event
    emit_event(&"chase_started", {
        &"reason": payload.get(&"reason", &"unknown"),
        &"target_position": _last_known_target_position
    })

func update(delta: float) -> void:
    _chase_timer += delta

    # Check if we should give up chasing
    if _chase_timer >= _max_chase_time:
        machine.transition_to(&"patrol", {&"reason": &"timeout"})
        return

    # Check if we lost the target
    if not _enemy.is_alerted():
        machine.transition_to(&"patrol", {&"reason": &"lost_target"})
        return

    var target = _enemy.get_alert_target()
    if not target:
        machine.transition_to(&"patrol", {&"reason": &"no_target"})
        return

    # Update last known position
    _last_known_target_position = target.global_position

    # Check if in attack range
    if _enemy.can_attack_target(target):
        machine.transition_to(&"attack", {&"target": target})
        return

    # Move toward target
    var chase_speed = _config.chase_speed if _config else 120.0
    _enemy.move_toward(_last_known_target_position, chase_speed)
    _enemy.flip_sprite_to_face(_last_known_target_position)

func physics_update(delta: float) -> void:
    # Path update logic would go here if using navigation
    _path_update_timer += delta
    if _path_update_timer >= (_config.path_update_interval if _config else 0.5):
        _path_update_timer = 0.0
        # Update path to target if using navigation

func handle_event(event: StringName, _data: Variant = null) -> void:
    match event:
        &"target_lost":
            machine.transition_to(&"investigate", {&"last_position": _last_known_target_position})
        &"damaged":
            # Increase priority when damaged
            _chase_timer = 0.0  # Reset timeout
            emit_event(&"chase_intensified", {&"reason": &"damaged"})

func exit(_payload: Dictionary[StringName, Variant] = {}) -> void:
    _enemy.stop_moving()

    emit_event(&"chase_ended", {
        &"duration": _chase_timer,
        &"reason": _payload.get(&"reason", &"unknown")
    })

## Get the current chase duration
func get_chase_duration() -> float:
    return _chase_timer

## Get the last known target position
func get_last_known_target_position() -> Vector2:
    return _last_known_target_position

## Set maximum chase time
func set_max_chase_time(time: float) -> void:
    _max_chase_time = time
