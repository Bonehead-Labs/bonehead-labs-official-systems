extends FSMState

var duration: float = 0.0

## Enter the move state
## 
## Initializes the move state by resetting the duration timer
## and emitting an entry event with payload data.
## 
## [b]payload:[/b] Optional data passed during transition
func enter(payload: Dictionary[StringName, Variant] = {}) -> void:
    duration = 0.0
    emit_event(StringName("entered_move"), payload)

## Update the move state
## 
## Tracks the duration of the move state and transitions
## back to idle after 1 second.
## 
## [b]delta:[/b] Time elapsed since last frame
func update(delta: float) -> void:
    duration += delta
    if duration > 1.0:
        machine.transition_to(StringName("idle"))

## Exit the move state
## 
## Emits an exit event with payload data when leaving
## the move state.
## 
## [b]payload:[/b] Optional data passed during transition
func exit(payload: Dictionary[StringName, Variant] = {}) -> void:
    emit_event(StringName("exited_move"), payload)
