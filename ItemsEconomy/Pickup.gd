extends Area2D
class_name ItemPickup

@export var item_id: String = ""
@export var quantity: int = 1

signal picked_up(by: Node, item_id: String, quantity: int)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body:
		return
	var inv_node = body.get_node_or_null("InventoryLite")
	if inv_node and not item_id.is_empty() and quantity > 0:
		var ok: bool = false
		if inv_node.has_method("add_item_by_id"):
			ok = inv_node.call("add_item_by_id", item_id, quantity, 99)
		if ok:
			picked_up.emit(body, item_id, quantity)
			if Engine.has_singleton("EventBus"):
				Engine.get_singleton("EventBus").call("pub", &"item/picked_up", {"item_id": item_id, "quantity": quantity, "by": String(body.name)})
			queue_free()
