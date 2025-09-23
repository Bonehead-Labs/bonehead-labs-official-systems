extends Node
class_name Shop

@export var stock: Array = [] # Array of {id: String, price: int}

signal purchased(buyer: Node, item_id: String, price: int)

func buy(buyer: Node, item_id: String, price: int) -> bool:
	if buyer == null or item_id.is_empty() or price < 0:
		return false
	var wallet = buyer.get_node_or_null("Wallet")
	var inv = buyer.get_node_or_null("InventoryLite")
	if wallet == null or inv == null:
		return false
	var withdraw_ok: bool = bool(wallet.call("withdraw", "gold", price))
	if not withdraw_ok:
		return false
	var add_ok: bool = bool(inv.call("add_item_by_id", item_id, 1, 99))
	if not add_ok:
		wallet.call("deposit", "gold", price)
		return false
	purchased.emit(buyer, item_id, price)
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").call("pub", &"shop/purchased", {"buyer": String(buyer.name), "item_id": item_id, "price": price})
	return true
