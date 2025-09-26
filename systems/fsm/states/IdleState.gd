extends FSMState

var ticks: int = 0

## Enter the idle state
## 
## Initializes the idle state by resetting the tick counter
## and emitting an entry event.
## 
## [b]_payload:[/b] Optional data passed during transition (unused)
func enter(_payload: Dictionary[StringName, Variant] = {}) -> void:
    ticks = 0
    emit_event(StringName("entered_idle"))

## Update the idle state
## 
## Increments the tick counter and checks if the threshold
## has been reached to transition to move state.
## 
## [b]_delta:[/b] Time elapsed since last frame (unused)
func update(_delta: float) -> void:
    ticks += 1
    if context.has(StringName("threshold")) and ticks >= int(context[StringName("threshold")]):
        machine.transition_to(StringName("move"), {StringName("reason"): StringName("threshold_reached")})

## Handle events in idle state
## 
## Processes events that can trigger state transitions
## from the idle state.
## 
## [b]event:[/b] Event name/identifier
## [b]_data:[/b] Optional event data (unused)
func handle_event(event: StringName, _data: Variant = null) -> void:
    if event == StringName("move_requested"):
        machine.transition_to(StringName("move"))
