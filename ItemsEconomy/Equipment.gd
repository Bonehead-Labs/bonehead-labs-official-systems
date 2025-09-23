extends Node
class_name Equipment

@export var slots: Array[String] = ["head", "body", "weapon"]
var _equipped: Dictionary = {}

signal equipped(slot: String, item_id: String)
signal unequipped(slot: String, item_id: String)

func equip(slot: String, item_id: String) -> bool:
	if not slots.has(slot) or item_id.is_empty():
		return false
	var prev: String = String(_equipped.get(slot, ""))
	_equipped[slot] = item_id
	if not prev.is_empty():
		unequipped.emit(slot, prev)
	equipped.emit(slot, item_id)
	return true

func get_equipped(slot: String) -> String:
	return String(_equipped.get(slot, ""))

func save_data() -> Dictionary:
	return {"equipped": _equipped.duplicate(true)}

func load_data(data: Dictionary) -> bool:
	_equipped = data.get("equipped", {}).duplicate(true)
	return true

