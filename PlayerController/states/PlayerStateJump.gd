extends "res://PlayerController/states/PlayerMovementState.gd"

func enter(_payload: Dictionary[StringName, Variant] = {}) -> void:
    if controller == null or movement_config == null:
        return
    controller.start_jump()
    emit_event(StringName("jump_started"))

func physics_update(delta: float) -> void:
    if controller == null or movement_config == null:
        return
    var input_vector := get_input_vector()
    controller.move_platformer_horizontal(input_vector.x, delta, true)
    controller.apply_gravity(delta)
    if controller.get_motion_velocity().y >= 0.0:
        machine.transition_to(StringName("fall"))
