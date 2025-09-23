extends RefCounted
class_name LeverInteractable

## Lever interactable that can be pulled.

var _is_pulled: bool = false

signal lever_pulled()
signal lever_reset()

func can_interact(_interactor: Node) -> bool:
    return true

func interact(_interactor: Node) -> bool:
    _is_pulled = not _is_pulled

    if _is_pulled:
        lever_pulled.emit()
    else:
        lever_reset.emit()

    return true

func get_prompt() -> String:
    return "Pull Lever" if not _is_pulled else "Reset Lever"

func is_pulled() -> bool:
    return _is_pulled

func pull() -> void:
    if not _is_pulled:
        _is_pulled = true
        lever_pulled.emit()

func reset() -> void:
    if _is_pulled:
        _is_pulled = false
        lever_reset.emit()
