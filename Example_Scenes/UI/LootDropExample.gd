class_name LootDropExample
extends Control

## LootDropExample demonstrates how ItemDatabase would be used in a real game
## This shows loot drops, item spawning, and database integration

@onready var _inventory_demo: InventoryTemplateDemo = %InventoryDemo
@onready var _loot_button: Button = %LootButton
@onready var _spawn_button: Button = %SpawnButton
@onready var _status_label: Label = %StatusLabel

var _loot_drops: Array[Dictionary] = []

func _ready() -> void:
	_loot_button.pressed.connect(_on_loot_requested)
	_spawn_button.pressed.connect(_on_spawn_requested)
	_update_status()

func _on_loot_requested() -> void:
	# Simulate a loot drop using ItemDatabase
	_loot_drops = ItemDatabase.get_random_items(3, "common")  # Get 3 random common items
	
	var loot_text = "Loot Drop:\n"
	for item in _loot_drops:
		loot_text += "• %s (%s)\n" % [item.get("display_name", "Unknown"), item.get("rarity", "unknown")]
	
	_status_label.text = loot_text
	_spawn_button.disabled = _loot_drops.is_empty()

func _on_spawn_requested() -> void:
	if _loot_drops.is_empty():
		return
	
	# Add loot to inventory
	for item in _loot_drops:
		_inventory_demo._inventory_lite.add_item(item, 1)
	
	_status_label.text = "Added %d items to inventory!" % _loot_drops.size()
	_loot_drops.clear()
	_spawn_button.disabled = true

func _update_status() -> void:
	var stats = ItemDatabase.get_stats()
	_status_label.text = "ItemDatabase Stats:\nItems: %d\nCategories: %s\nRarities: %s" % [
		stats.total_items,
		", ".join(stats.categories),
		", ".join(stats.rarities)
	]
