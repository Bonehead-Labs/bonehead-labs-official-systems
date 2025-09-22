extends CanvasLayer

const FlowTransition = preload("res://SceneFlow/Transitions/TransitionResource.gd")

signal transition_finished(transition: FlowTransition, direction: String)

var calls: Array = []

func play_transition(transition: FlowTransition, is_enter: bool) -> void:
    calls.append({"transition": transition, "is_enter": is_enter})
    call_deferred("_emit_complete", transition, is_enter)

func _emit_complete(transition: FlowTransition, is_enter: bool) -> void:
    transition_finished.emit(transition, is_enter ? "enter" : "exit")

func is_playing() -> bool:
    return false
