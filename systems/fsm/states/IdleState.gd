extends FSMState

var ticks: int = 0

func enter(_payload: Dictionary[StringName, Variant] = {}) -> void:
    ticks = 0
    emit_event(StringName("entered_idle"))

func update(delta: float) -> void:
    ticks += 1
    if context.has(StringName("threshold")) and ticks >= int(context[StringName("threshold")]):
        machine.transition_to(StringName("move"), {StringName("reason"): StringName("threshold_reached")})

func handle_event(event: StringName, _data: Variant = null) -> void:
    if event == StringName("move_requested"):
        machine.transition_to(StringName("move"))
