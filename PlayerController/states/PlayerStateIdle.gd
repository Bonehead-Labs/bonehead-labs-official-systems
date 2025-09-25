extends "res://PlayerController/states/PlayerMovementState.gd"

func enter(payload: Dictionary[StringName, Variant] = {}) -> void:
    emit_state_entered(StringName("idle"), payload)
    if controller and is_platformer():
        controller.refresh_coyote_timer()

func physics_update(delta: float) -> void:
    if controller == null or movement_config == null:
        return
    var input_vector := get_input_vector()
    if is_platformer():
        controller.move_platformer_horizontal(input_vector.x, delta, false)
        if controller.consume_jump_request():
            safe_transition_to(StringName("jump"), {}, StringName("jump_requested"))
            return
        if not controller.is_on_floor():
            safe_transition_to(StringName("fall"), {}, StringName("not_on_floor"))
            return
        if not is_equal_approx(input_vector.x, 0.0):
            safe_transition_to(StringName("move"), {}, StringName("input_detected"))
            return
    else:
        controller.move_top_down(input_vector, delta)
        if input_vector.length_squared() > 0.0:
            safe_transition_to(StringName("move"), {}, StringName("input_detected"))
            return
