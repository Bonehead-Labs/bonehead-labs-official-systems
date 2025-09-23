extends RefCounted
class_name ButtonInteractable

## Button interactable that can be pressed.

var _is_pressed: bool = false
var _one_time_use: bool = false

signal button_pressed()
signal button_released()
signal button_activated()

func can_interact(_interactor: Node) -> bool:
    if _one_time_use and _is_pressed:
        return false
    return true

func interact(_interactor: Node) -> bool:
    if _one_time_use and _is_pressed:
        return false

    _is_pressed = true
    button_pressed.emit()
    button_activated.emit()

    # Auto-release for non-toggle buttons
    if not _one_time_use:
        _is_pressed = false
        button_released.emit()

    return true

func get_prompt() -> String:
    if _one_time_use and _is_pressed:
        return "Already Used"
    return "Press Button"

func is_pressed() -> bool:
    return _is_pressed

func set_one_time_use(use: bool) -> void:
    _one_time_use = use

func press() -> void:
    if not _is_pressed:
        _is_pressed = true
        button_pressed.emit()
        button_activated.emit()

func release() -> void:
    if _is_pressed and not _one_time_use:
        _is_pressed = false
        button_released.emit()
