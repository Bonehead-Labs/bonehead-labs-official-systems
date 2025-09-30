extends FSMState

class_name PlayerMovementState

var controller: _PlayerController2D
var movement_config: MovementConfig

func setup(state_machine: StateMachine, state_owner: Node, state_context: Dictionary[StringName, Variant]) -> void:
    super.setup(state_machine, state_owner, state_context)
    if state_context.has(StringName("controller")) and state_context[StringName("controller")] is _PlayerController2D:
        controller = state_context[StringName("controller")] as _PlayerController2D
    if state_context.has(StringName("movement_config")) and state_context[StringName("movement_config")] is MovementConfig:
        movement_config = state_context[StringName("movement_config")] as MovementConfig

func get_input_vector() -> Vector2:
    return controller.get_movement_input() if controller else Vector2.ZERO

func is_platformer() -> bool:
    return controller != null and controller.is_platformer_mode()

func is_top_down() -> bool:
    return controller != null and controller.is_top_down_mode()

func should_consume_jump() -> bool:
    return controller != null and controller.consume_jump_request()

func emit_state_event(event: StringName, data: Variant = null) -> void:
    if machine:
        machine.emit_state_event(event, data)
