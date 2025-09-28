extends Node

## ItemDatabase - Central registry for all game items
## This autoload singleton provides access to all item definitions loaded from JSON

class_name _ItemDatabase

# Signal emitted when database is loaded
signal database_loaded()

# Dictionary to store all items by ID: {item_id: Dictionary}
var _items: Dictionary = {}

# Categorized item lists for easy filtering
var _items_by_category: Dictionary = {}
var _items_by_rarity: Dictionary = {}

# Database loading state
var _is_loaded: bool = false

## Check if the database is loaded
func is_loaded() -> bool:
	return _is_loaded

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_load_database()

## Load all items from the database
func _load_database() -> void:
	_items.clear()
	_items_by_category.clear()
	_items_by_rarity.clear()
	
	print("ItemDatabase: Loading items from JSON...")
	_load_items_from_json("res://ItemsEconomy/Items/items.json")
	
	_is_loaded = true
	emit_signal("database_loaded")
	print("ItemDatabase: Loaded %d items" % _items.size())

## Load items from a JSON file
func _load_items_from_json(json_path: String) -> void:
	if not FileAccess.file_exists(json_path):
		push_error("ItemDatabase: JSON file not found: " + json_path)
		return
	
	var file = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("ItemDatabase: Failed to open JSON file: " + json_path)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("ItemDatabase: Failed to parse JSON: " + json.get_error_message())
		return
	
	var items_data = json.data
	if not items_data is Dictionary:
		push_error("ItemDatabase: JSON root must be a dictionary")
		return
	
	var loaded_count = 0
	for item_id in items_data.keys():
		var item_data = items_data[item_id]
		if item_data is Dictionary:
			print("ItemDatabase: Loading item: ", item_id, " - ", item_data.get("display_name", "Unknown"))
			_register_item(item_data)
			loaded_count += 1
		else:
			push_warning("ItemDatabase: Invalid item data for: " + item_id)
	
	print("ItemDatabase: Successfully loaded %d items from JSON" % loaded_count)

## Register an item in the database
func _register_item(item_data: Dictionary) -> void:
	var item_id = item_data.get("id", "")
	if item_id.is_empty():
		push_warning("ItemDatabase: Item missing ID, skipping")
		return
	
	_items[item_id] = item_data
	
	# Categorize by tags (first tag becomes category)
	var tags = item_data.get("tags", [])
	if not tags.is_empty():
		var category = tags[0]
		if not _items_by_category.has(category):
			_items_by_category[category] = []
		_items_by_category[category].append(item_id)
	
	# Categorize by rarity
	var rarity = item_data.get("rarity", "common")
	if not _items_by_rarity.has(rarity):
		_items_by_rarity[rarity] = []
	_items_by_rarity[rarity].append(item_id)

## Get an item by ID
func get_item(item_id: String) -> Dictionary:
	if not _is_loaded:
		push_warning("ItemDatabase: Database not loaded yet")
		return {}
	
	if not _items.has(item_id):
		push_warning("ItemDatabase: Item not found: " + item_id)
		return {}
	
	return _items[item_id]

## Get all items
func get_all_items() -> Dictionary:
	return _items.duplicate()

## Get items by category
func get_items_by_category(category: String) -> Array[String]:
	if not _items_by_category.has(category):
		return []
	return _items_by_category[category].duplicate()

## Get items by rarity
func get_items_by_rarity(rarity: String) -> Array[String]:
	if not _items_by_rarity.has(rarity):
		return []
	return _items_by_rarity[rarity].duplicate()

## Get all categories
func get_categories() -> Array[String]:
	return _items_by_category.keys()

## Get all rarities
func get_rarities() -> Array[String]:
	return _items_by_rarity.keys()

## Check if an item exists
func has_item(item_id: String) -> bool:
	return _items.has(item_id)

## Get random items for loot generation
func get_random_items(count: int, rarity_filter: String = "") -> Array[Dictionary]:
	var available_items = []
	
	if rarity_filter.is_empty():
		available_items = _items.values()
	else:
		var item_ids = get_items_by_rarity(rarity_filter)
		for item_id in item_ids:
			available_items.append(_items[item_id])
	
	var loot: Array[Dictionary] = []
	for i in range(min(count, available_items.size())):
		var random_item = available_items[randi() % available_items.size()]
		loot.append(random_item)
	
	return loot

## Get database statistics
func get_stats() -> Dictionary:
	return {
		"total_items": _items.size(),
		"categories": _items_by_category.keys(),
		"rarities": _items_by_rarity.keys(),
		"is_loaded": _is_loaded
	}
