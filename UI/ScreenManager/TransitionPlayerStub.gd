extends CanvasLayer

const FlowTransition = preload("res://SceneFlow/Transitions/TransitionResource.gd")

signal transition_finished(transition: FlowTransition, direction: String)

func play_transition(transition: FlowTransition, is_enter: bool) -> void:
    transition_finished.emit(transition, is_enter ? "enter" : "exit")
