extends "res://PlayerController/states/PlayerMovementState.gd"

func enter(payload: Dictionary[StringName, Variant] = {}) -> void:
    emit_event(StringName("fall_entered"), payload)

func physics_update(delta: float) -> void:
    if controller == null or movement_config == null:
        return
    var input_vector := get_input_vector()
    controller.move_platformer_horizontal(input_vector.x, delta, true)
    controller.apply_gravity(delta)
    if controller.is_on_floor():
        controller.refresh_coyote_timer()
        if is_equal_approx(input_vector.x, 0.0):
            machine.transition_to(StringName("idle"))
        else:
            machine.transition_to(StringName("move"))
