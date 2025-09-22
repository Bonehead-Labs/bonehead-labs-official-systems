extends "res://PlayerController/states/PlayerMovementState.gd"

func enter(payload: Dictionary[StringName, Variant] = {}) -> void:
    emit_event(StringName("move_entered"), payload)

func physics_update(delta: float) -> void:
    if controller == null or movement_config == null:
        return
    var input_vector := get_input_vector()
    if is_platformer():
        controller.move_platformer_horizontal(input_vector.x, delta, false)
        if controller.consume_jump_request():
            machine.transition_to(StringName("jump"))
            return
        if not controller.is_on_floor():
            machine.transition_to(StringName("fall"))
            return
        if is_equal_approx(input_vector.x, 0.0):
            machine.transition_to(StringName("idle"))
    else:
        controller.move_top_down(input_vector, delta)
        if input_vector.length_squared() == 0.0:
            machine.transition_to(StringName("idle"))
