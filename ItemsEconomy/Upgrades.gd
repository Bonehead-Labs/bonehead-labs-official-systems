extends Node
class_name Upgrades

var _levels: Dictionary = {}

signal upgraded(stat: String, new_level: int)

func level(stat: String) -> int:
	return int(_levels.get(stat, 0))

func add_level(stat: String, amount: int = 1) -> int:
	var new_lvl: int = level(stat) + amount
	_levels[stat] = new_lvl
	upgraded.emit(stat, new_lvl)
	return new_lvl

func save_data() -> Dictionary:
	return {"levels": _levels.duplicate(true)}

func load_data(data: Dictionary) -> bool:
	_levels = data.get("levels", {}).duplicate(true)
	return true

