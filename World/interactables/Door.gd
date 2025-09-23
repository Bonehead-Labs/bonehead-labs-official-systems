extends RefCounted
class_name DoorInteractable

## Door interactable that can be opened/closed.

var _is_open: bool = false
var _locked: bool = false

signal door_opened()
signal door_closed()
signal door_locked()
signal door_unlocked()

func can_interact(_interactor: Node) -> bool:
    return not _locked

func interact(_interactor: Node) -> bool:
    if _locked:
        return false

    _is_open = not _is_open

    if _is_open:
        door_opened.emit()
        return true
    else:
        door_closed.emit()
        return true

func get_prompt() -> String:
    if _locked:
        return "Locked"
    return "Open Door" if not _is_open else "Close Door"

func lock() -> void:
    _locked = true
    door_locked.emit()

func unlock() -> void:
    _locked = false
    door_unlocked.emit()

func is_open() -> bool:
    return _is_open

func is_locked() -> bool:
    return _locked
