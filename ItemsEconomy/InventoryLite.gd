extends Node
class_name InventoryLite

@export var capacity: int = 20

# {item_id: {"def": Dictionary, "quantity": int}}
var _items: Dictionary = {}

signal item_added(item_id: String, quantity: int)
signal item_removed(item_id: String, quantity: int)
signal inventory_changed()

func add_item(item_data: Dictionary, quantity: int = 1) -> bool:
	if item_data.is_empty() or item_data.get("id", "").is_empty() or quantity <= 0:
		push_warning("InventoryLite.add_item: invalid params")
		return false
	var item_id = item_data.get("id", "")
	var current_slots: int = _items.size()
	var entry: Dictionary = _items.get(item_id, {})
	var is_new: bool = entry.is_empty()
	if is_new and current_slots >= capacity:
		return false
	var new_qty: int = int(entry.get("quantity", 0)) + quantity
	var max_stack: int = item_data.get("max_stack", 99)
	if new_qty > max_stack:
		var overflow: int = new_qty - max_stack
		new_qty = max_stack
		# Overflow not handled (no auto-new-stack in Lite)
		push_warning("InventoryLite: stack overflow for %s by %d" % [item_id, overflow])
	_items[item_id] = {"def": item_data, "quantity": new_qty}
	item_added.emit(item_id, quantity)
	inventory_changed.emit()
	return true

func add_item_by_id(item_id: String, quantity: int, max_stack: int = 99) -> bool:
	if item_id.is_empty() or quantity <= 0:
		return false
	var current_slots: int = _items.size()
	var entry: Dictionary = _items.get(item_id, {})
	var is_new: bool = entry.is_empty()
	if is_new and current_slots >= capacity:
		return false
	var new_qty: int = int(entry.get("quantity", 0)) + quantity
	if new_qty > max_stack:
		var overflow: int = new_qty - max_stack
		new_qty = max_stack
		push_warning("InventoryLite: stack overflow for %s by %d" % [item_id, overflow])
	_items[item_id] = {"def": entry.get("def", null), "quantity": new_qty}
	item_added.emit(item_id, quantity)
	inventory_changed.emit()
	return true

func remove_item(item_id: String, quantity: int = 1) -> bool:
	if item_id.is_empty() or quantity <= 0:
		return false
	if not _items.has(item_id):
		return false
	var entry: Dictionary = _items[item_id]
	var left: int = int(entry.get("quantity", 0)) - quantity
	if left <= 0:
		_items.erase(item_id)
	else:
		entry["quantity"] = left
		_items[item_id] = entry
	item_removed.emit(item_id, quantity)
	inventory_changed.emit()
	return true

func count(item_id: String) -> int:
	if not _items.has(item_id):
		return 0
	return int(_items[item_id].get("quantity", 0))

func has_item(item_id: String, min_quantity: int = 1) -> bool:
	return count(item_id) >= min_quantity

func list_items() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for item_id in _items.keys():
		var entry: Dictionary = _items[item_id]
		var item_data = entry.get("def", {})
		list.append({
			"id": item_id,
			"quantity": int(entry.get("quantity", 0)),
			"display_name": item_data.get("display_name", item_id)
		})
	return list

# SaveService hooks
func save_data() -> Dictionary:
	var data: Array = []
	for item_id in _items.keys():
		var entry: Dictionary = _items[item_id]
		data.append({"id": item_id, "quantity": int(entry.get("quantity", 0))})
	return {"items": data}

func load_data(data: Dictionary) -> bool:
	_items.clear()
	var arr: Array = data.get("items", [])
	for e in arr:
		var item_id: String = String(e.get("id", ""))
		var qty: int = int(e.get("quantity", 0))
		if item_id.is_empty() or qty <= 0:
			continue
		# Item data resolution left to game (registry); store id+qty only
		_items[item_id] = {"def": null, "quantity": qty}
	inventory_changed.emit()
	return true
