extends RefCounted
class_name ChestInteractable

## Chest interactable that can contain loot.

var _is_open: bool = false
var _is_locked: bool = false
var _loot_table_path: String = ""

signal chest_opened()
signal chest_closed()
signal chest_locked()
signal chest_unlocked()

func can_interact(_interactor: Node) -> bool:
    return not _is_locked

func interact(_interactor: Node) -> bool:
    if _is_locked:
        return false

    if not _is_open:
        _open_chest()
        return true
    else:
        _close_chest()
        return true

func get_prompt() -> String:
    if _is_locked:
        return "Locked"
    if not _is_open:
        return "Open Chest"
    return "Close Chest"

func lock() -> void:
    _is_locked = true
    chest_locked.emit()

func unlock() -> void:
    _is_locked = false
    chest_unlocked.emit()

func set_loot_table(path: String) -> void:
    _loot_table_path = path

func get_loot_table() -> String:
    return _loot_table_path

func _open_chest() -> void:
    _is_open = true
    chest_opened.emit()

    # TODO: Generate loot from loot table and add to inventory
    # This would integrate with Items & Economy system

func _close_chest() -> void:
    _is_open = false
    chest_closed.emit()

func is_open() -> bool:
    return _is_open

func is_locked() -> bool:
    return _is_locked

func is_empty() -> bool:
    # TODO: Check if chest has items
    return true
