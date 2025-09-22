class_name FlowTransitionLibrary
extends Resource

const FlowTransition = preload("res://SceneFlow/Transitions/TransitionResource.gd")

@export var default_transition: FlowTransition
@export var transitions: Array[FlowTransition] = []

func get_transition(name: StringName) -> FlowTransition:
    for t in transitions:
        if t.name == String(name):
            return t.duplicate_transition()
    if default_transition:
        return default_transition.duplicate_transition()
    return null

func has_transition(name: StringName) -> bool:
    for t in transitions:
        if t.name == String(name):
            return true
    return default_transition != null

func add_transition(transition: FlowTransition) -> void:
    if not transition:
        return
    for i in range(transitions.size()):
        if transitions[i].name == transition.name:
            transitions[i] = transition
            return
    transitions.append(transition)

func remove_transition(name: StringName) -> void:
    for i in range(transitions.size()):
        if transitions[i].name == String(name):
            transitions.remove_at(i)
            return
