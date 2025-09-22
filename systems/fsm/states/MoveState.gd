extends FSMState

var duration: float = 0.0

func enter(payload: Dictionary[StringName, Variant] = {}) -> void:
    duration = 0.0
    emit_event(StringName("entered_move"), payload)

func update(delta: float) -> void:
    duration += delta
    if duration > 1.0:
        machine.transition_to(StringName("idle"))

func exit(payload: Dictionary[StringName, Variant] = {}) -> void:
    emit_event(StringName("exited_move"), payload)
