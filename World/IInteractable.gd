class_name IInteractable
extends RefCounted

## Interface for interactable objects in the world.

## Check if the object can be interacted with by the given interactor.
func can_interact(_interactor: Node) -> bool:
    return true

## Perform the interaction with the given interactor.
func interact(_interactor: Node) -> bool:
    return false

## Get the interaction prompt text for UI display.
func get_prompt() -> String:
    return "Interact"

## Get the interaction icon for UI display.
func get_icon() -> Texture2D:
    return null

## Get the interaction range for this object.
func get_interaction_range() -> float:
    return 50.0
