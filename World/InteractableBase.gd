extends Area2D
class_name InteractableBase

## Base class for interactable objects using composition.

const IInteractableScript = preload("res://World/IInteractable.gd")

var _interactable: IInteractableScript
var _is_highlighted: bool = false

signal interacted(interactor: Node, interactable: InteractableBase)
signal highlighted(interactor: Node, interactable: InteractableBase)
signal unhighlighted(interactor: Node, interactable: InteractableBase)

@export var interaction_range: float = 50.0

func set_interactable(interactable: IInteractableScript) -> void:
    _interactable = interactable

func get_interactable() -> IInteractableScript:
    return _interactable

func can_interact(interactor: Node) -> bool:
    if _interactable == null:
        return false
    return _interactable.can_interact(interactor)

func interact(interactor: Node) -> bool:
    if _interactable == null:
        return false

    var success: bool = _interactable.interact(interactor)
    if success:
        interacted.emit(interactor, self)

        if Engine.has_singleton("EventBus"):
            Engine.get_singleton("EventBus").call("pub", &"world/interacted", {
                "interactor": String(interactor.name) if interactor else "unknown",
                "interactable": name,
                "position": global_position
            })

    return success

func get_prompt() -> String:
    if _interactable == null:
        return "Interact"
    return _interactable.get_prompt()

func get_icon() -> Texture2D:
    if _interactable == null:
        return null
    return _interactable.get_icon()

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
    if can_interact(body):
        _is_highlighted = true
        highlighted.emit(body, self)

func _on_body_exited(body: Node) -> void:
    if _is_highlighted:
        _is_highlighted = false
        unhighlighted.emit(body, self)
