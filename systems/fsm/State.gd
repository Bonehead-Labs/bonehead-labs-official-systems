class_name FSMState
extends RefCounted

## Base class for scriptable states.
## Override lifecycle hooks as needed.

var machine: StateMachine
var owner: Node
var context: Dictionary[StringName, Variant] = {}

func setup(state_machine: StateMachine, state_owner: Node, state_context: Dictionary[StringName, Variant]) -> void:
    machine = state_machine
    owner = state_owner
    context = state_context

func enter(_payload: Dictionary[StringName, Variant] = {}) -> void:
    pass

func exit(_payload: Dictionary[StringName, Variant] = {}) -> void:
    pass

func update(_delta: float) -> void:
    pass

func physics_update(_delta: float) -> void:
    pass

func handle_event(_event: StringName, _data: Variant = null) -> void:
    pass

func can_transition_to(_state: StringName) -> bool:
    return true

func emit_event(event: StringName, data: Variant = null) -> void:
    if machine:
        machine.emit_state_event(event, data)
