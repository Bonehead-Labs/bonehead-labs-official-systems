class_name FlowTransition
extends Resource

@export var name: String = ""
@export var enter_animation: String = ""
@export var exit_animation: String = ""
@export var duration_ms: int = 0
@export var metadata: Dictionary = {}

func duplicate_transition() -> FlowTransition:
    var copy := FlowTransition.new()
    copy.name = name
    copy.enter_animation = enter_animation
    copy.exit_animation = exit_animation
    copy.duration_ms = duration_ms
    copy.metadata = metadata.duplicate(true)
    return copy
