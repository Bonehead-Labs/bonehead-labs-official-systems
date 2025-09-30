class_name DashAbility
extends "../Ability.gd"

## Example ability that gives the player a dash movement.
## Press dash action to perform a quick dash in the current movement direction.

@export var dash_speed: float = 700.0
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
        # Maintain dash velocity during dash window by keeping controller velocity consistent
        var cur: Vector2 = get_controller().get_motion_velocity()
        var old_vel: Vector2 = get_controller().get("velocity")
        get_controller().set("velocity", cur)
        print("[DashAbility] _on_update: dashing, timer=", _dash_timer, " motion_vel=", cur, " old_vel=", old_vel, " new_vel=", get_controller().get("velocity"))
        if _dash_timer <= 0.0:
            _end_dash()
    elif _cooldown_timer > 0.0:
        _cooldown_timer -= delta
        print("[DashAbility] _on_update: cooldown=", _cooldown_timer)

func _on_input_action(action: StringName, edge: String, _device: int, _event: InputEvent) -> void:
    print("[DashAbility] _on_input_action called: action=", action, " edge=", edge, " device=", _device)
    if action == StringName("dash") and edge == "pressed":
        print("[DashAbility] dash input received; can_dash=", can_dash(), " _is_dashing=", _is_dashing, " _cooldown_timer=", _cooldown_timer)
        if EventBus and EventBus.has_method("pub"):
            EventBus.call("pub", EventTopics.DEBUG_LOG, {"msg": "DashAbility dash input", "level": "INFO", "source": "DashAbility"})
        if can_dash():
            print("[DashAbility] can_dash() returned true, calling _start_dash()")
            _start_dash()
        else:
            print("[DashAbility] can_dash() returned false, not starting dash")

func can_dash() -> bool:
    return not _is_dashing and _cooldown_timer <= 0.0

func _start_dash() -> void:
    _is_dashing = true
    _dash_timer = dash_duration

    # Get current movement direction
    var input_vector: Vector2 = get_controller().get_movement_input()
    print("[DashAbility] _start_dash: input_vector=", input_vector, " length=", input_vector.length())
    if input_vector.length() < 0.1:
        # If no input, dash in facing direction (simplified - could check sprite flip)
        input_vector = Vector2.RIGHT
        print("[DashAbility] _start_dash: no input, using RIGHT")

    input_vector = input_vector.normalized()
    print("[DashAbility] _start_dash: normalized input=", input_vector)

    # Apply dash velocity and push directly into controller velocity to avoid FSM stomp
    var dash_velocity: Vector2 = input_vector * dash_speed
    print("[DashAbility] _start_dash: dash_velocity=", dash_velocity, " dash_speed=", dash_speed)
    
    var controller = get_controller()
    print("[DashAbility] _start_dash: controller=", controller, " has set_motion_velocity=", controller.has_method("set_motion_velocity"))
    
    controller.set_motion_velocity(dash_velocity)
    controller.set("velocity", dash_velocity)
    
    print("[DashAbility] _start_dash: after set - motion_vel=", controller.get_motion_velocity(), " velocity=", controller.get("velocity"))

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
    var controller = get_controller()
    print("[DashAbility] _end_dash: before reset - motion_vel=", controller.get_motion_velocity(), " velocity=", controller.get("velocity"))
    controller.set_motion_velocity(Vector2.ZERO)
    print("[DashAbility] _end_dash: after reset - motion_vel=", controller.get_motion_velocity(), " velocity=", controller.get("velocity"))
    print("[DashAbility] end dash; cooldown=", _cooldown_timer)

    emit_ability_event("ended", {})

func is_on_cooldown() -> bool:
    return _cooldown_timer > 0.0

func is_dashing() -> bool:
    return _is_dashing

func get_cooldown_progress() -> float:
    if dash_cooldown <= 0.0:
        return 0.0
    return _cooldown_timer / dash_cooldown

func get_dash_progress() -> float:
    if dash_duration <= 0.0:
        return 0.0
    return _dash_timer / dash_duration
