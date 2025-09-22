class_name Chest
extends Area2D

## Example interactable chest that can be opened by the player.
## Demonstrates the interaction system with EventBus integration.

signal chest_opened(item_id: String, quantity: int)
signal chest_closed()

@export var item_id: String = "gold_coin"
@export var item_quantity: int = 10
@export var is_opened: bool = false
@export var auto_close_after: float = 2.0

var _close_timer: float = 0.0

func _ready() -> void:
    # Add to interactable group
    add_to_group("interactable")

    # Set up collision
    var shape := RectangleShape2D.new()
    shape.size = Vector2(32, 32)
    var collision := CollisionShape2D.new()
    collision.shape = shape
    add_child(collision)

func _process(delta: float) -> void:
    if is_opened and auto_close_after > 0.0:
        _close_timer -= delta
        if _close_timer <= 0.0:
            close()

func interact(_interaction_detector: Node) -> void:
    if is_opened:
        close()
    else:
        open()

func open() -> void:
    if is_opened:
        return

    is_opened = true
    _close_timer = auto_close_after

    # Visual feedback (could animate sprite here)
    modulate = Color.GREEN

    # Emit signals
    chest_opened.emit(item_id, item_quantity)

    # EventBus analytics
    if Engine.has_singleton("EventBus"):
        var event_bus := Engine.get_singleton("EventBus")
        event_bus.call("pub", "chest_opened", {
            "chest_id": name,
            "item_id": item_id,
            "quantity": item_quantity,
            "position": global_position,
            "timestamp_ms": Time.get_ticks_msec()
        })

func close() -> void:
    if not is_opened:
        return

    is_opened = false
    _close_timer = 0.0

    # Visual feedback
    modulate = Color.WHITE

    # Emit signal
    chest_closed.emit()

    # EventBus analytics
    if Engine.has_singleton("EventBus"):
        var event_bus := Engine.get_singleton("EventBus")
        event_bus.call("pub", "chest_closed", {
            "chest_id": name,
            "position": global_position,
            "timestamp_ms": Time.get_ticks_msec()
        })

func is_interactable() -> bool:
    return true

func get_interaction_prompt() -> String:
    return "Open Chest" if not is_opened else "Close Chest"

func get_interaction_icon() -> Texture2D:
    # Could return different icons for open/closed states
    return null
