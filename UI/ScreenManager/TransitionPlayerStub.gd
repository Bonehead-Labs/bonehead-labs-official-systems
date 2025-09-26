extends CanvasLayer

const FlowTransition = preload("res://SceneFlow/Transitions/TransitionResource.gd")

signal transition_finished(transition: FlowTransition, direction: String)

## Play a transition (stub implementation)
## 
## Immediately emits the transition_finished signal without
## actually playing any transition. Used for testing.
## 
## [b]transition:[/b] Transition resource to play (unused)
## [b]is_enter:[/b] true for enter transition, false for exit
func play_transition(transition: FlowTransition, is_enter: bool) -> void:
    transition_finished.emit(transition, "enter" if is_enter else "exit")
