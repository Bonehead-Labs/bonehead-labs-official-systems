class_name DashAbility
extends "../Ability.gd"

## Example ability that gives the player a dash movement.
## Press dash action to perform a quick dash in the current movement direction.

@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0

var _dash_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _is_dashing: bool = false

func _on_activated() -> void:
    _dash_timer = 0.0
    _cooldown_timer = 0.0
    _is_dashing = false

func _on_deactivated() -> void:
    _is_dashing = false

func _on_update(delta: float) -> void:
    if _is_dashing:
        _dash_timer -= delta
        if _dash_timer <= 0.0:
            _end_dash()
    elif _cooldown_timer > 0.0:
        _cooldown_timer -= delta

func _on_input_action(action: StringName, edge: String, _device: int, _event: InputEvent) -> void:
    if action == StringName("dash") and edge == "pressed" and can_dash():
        _start_dash()

func can_dash() -> bool:
    return not _is_dashing and _cooldown_timer <= 0.0

func _start_dash() -> void:
    _is_dashing = true
    _dash_timer = dash_duration

    # Get current movement direction
    var input_vector: Vector2 = get_controller().get_movement_input()
    if input_vector.length() < 0.1:
        # If no input, dash in facing direction (simplified - could check sprite flip)
        input_vector = Vector2.RIGHT

    input_vector = input_vector.normalized()

    # Apply dash velocity
    var dash_velocity: Vector2 = input_vector * dash_speed
    get_controller().set_motion_velocity(dash_velocity)

    # Emit ability event
    emit_ability_event("started", {
        "direction": input_vector,
        "speed": dash_speed,
        "duration": dash_duration
    })

    # Analytics
    _emit_analytics_event(EventTopics.PLAYER_ABILITY_USED, {
        "ability_type": "dash",
        "direction": input_vector,
        "speed": dash_speed
    })

func _end_dash() -> void:
    _is_dashing = false
    _cooldown_timer = dash_cooldown

    # Reset velocity to prevent continued dashing
    get_controller().set_motion_velocity(Vector2.ZERO)

    emit_ability_event("ended", {})

func is_on_cooldown() -> bool:
    return _cooldown_timer > 0.0

func get_cooldown_progress() -> float:
    if dash_cooldown <= 0.0:
        return 0.0
    return _cooldown_timer / dash_cooldown

func get_dash_progress() -> float:
    if dash_duration <= 0.0:
        return 0.0
    return _dash_timer / dash_duration
