class_name InventoryTemplateDemo
extends Control

## InventoryTemplateDemo demonstrates the InventoryTemplate system in action.
## This scene shows how to instantiate, populate, and interact with InventoryTemplate.

const INVENTORY_TEMPLATE: PackedScene = preload("res://UI/Templates/InventoryTemplate.tscn")

const LOG_LIMIT: int = 6

@onready var _template_host: Control = %TemplateHost
@onready var _event_log: RichTextLabel = %EventLog
@onready var _refresh_button: Button = %RefreshButton
@onready var _toggle_button: Button = %ToggleButton

var _inventory: _InventoryTemplate
var _log_lines: PackedStringArray = PackedStringArray()
var _inventory_lite: InventoryLite
var _is_inventory_visible: bool = true

func _ready() -> void:
	randomize()
	_refresh_button.pressed.connect(_on_refresh_requested)
	_toggle_button.pressed.connect(_on_toggle_requested)
	_setup_inventory()
	_spawn_template()
	_update_toggle_button_text()
	_append_log("InventoryTemplateDemo ready. Click items to see events.")

func _exit_tree() -> void:
	if _inventory != null and is_instance_valid(_inventory):
		if _inventory.template_event.is_connected(_on_template_event):
			_inventory.template_event.disconnect(_on_template_event)
		_inventory.queue_free()

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("inventory"):
		_toggle_inventory()

func _toggle_inventory() -> void:
	_is_inventory_visible = !_is_inventory_visible
	_template_host.visible = _is_inventory_visible
	_update_toggle_button_text()
	_append_log("Inventory %s" % ("shown" if _is_inventory_visible else "hidden"))

func _on_toggle_requested() -> void:
	_toggle_inventory()

func _update_toggle_button_text() -> void:
	if _toggle_button != null:
		_toggle_button.text = "Hide Inventory" if _is_inventory_visible else "Show Inventory"

func _setup_inventory() -> void:
	_inventory_lite = InventoryLite.new()
	_inventory_lite.capacity = 20
	_inventory_lite.inventory_changed.connect(_on_inventory_changed)
	
	# Add some sample items using ItemDatabase
	_add_sample_items_from_database()

func _add_sample_items_from_database() -> void:
	# JSON LOADING METHOD - SIMPLE AND RELIABLE
	print("=== JSON LOADING METHOD ===")
	
	# Wait for ItemDatabase to load if not ready
	if not ItemDatabase.is_loaded():
		print("Waiting for ItemDatabase to load...")
		await ItemDatabase.database_loaded
		print("ItemDatabase loaded!")
	
	# Check what's in the database
	var stats = ItemDatabase.get_stats()
	print("ItemDatabase stats: ", stats)
	
	# Get items from the database
	var sword_data = ItemDatabase.get_item("sword_iron")
	var potion_data = ItemDatabase.get_item("potion_health")
	var gem_data = ItemDatabase.get_item("gem_ruby")
	var arrow_data = ItemDatabase.get_item("arrow_wooden")
	
	print("Retrieved items from database:")
	print("  sword_iron: ", not sword_data.is_empty(), " - ", sword_data.get("display_name", "Unknown") if not sword_data.is_empty() else "null")
	print("  potion_health: ", not potion_data.is_empty(), " - ", potion_data.get("display_name", "Unknown") if not potion_data.is_empty() else "null")
	print("  gem_ruby: ", not gem_data.is_empty(), " - ", gem_data.get("display_name", "Unknown") if not gem_data.is_empty() else "null")
	print("  arrow_wooden: ", not arrow_data.is_empty(), " - ", arrow_data.get("display_name", "Unknown") if not arrow_data.is_empty() else "null")
	
	# If we have items, add them to inventory
	if not sword_data.is_empty() and not potion_data.is_empty() and not gem_data.is_empty() and not arrow_data.is_empty():
		print("All items loaded successfully! Adding to inventory...")
		_inventory_lite.add_item(sword_data, 1)
		_inventory_lite.add_item(potion_data, 3)
		_inventory_lite.add_item(gem_data, 2)
		_inventory_lite.add_item(arrow_data, 25)
		
		# Add some empty slots for variety
		_inventory_lite.add_item_by_id("empty_slot_1", 0)
		_inventory_lite.add_item_by_id("empty_slot_2", 0)
		
		print("Items added to inventory. Current inventory items: ", _inventory_lite.list_items().size())
	else:
		print("ERROR: Some items failed to load from database!")

# OPTIONAL PROGRAMMATIC METHOD - COMMENTED OUT IN FAVOR OF JSON
# This method shows how to create items programmatically if needed
# func _create_item_def(id: String, display_name: String, description: String, rarity: String, tags: Array[String], max_stack: int) -> Dictionary:
# 	return {
# 		"id": id,
# 		"display_name": display_name,
# 		"description": description,
# 		"rarity": rarity,
# 		"tags": tags,
# 		"max_stack": max_stack,
# 		"icon_path": "res://icon.svg"
# 	}

func _spawn_template() -> void:
	if _template_host == null:
		return
	for child in _template_host.get_children():
		child.queue_free()
	_inventory = INVENTORY_TEMPLATE.instantiate() as _InventoryTemplate
	if _inventory == null:
		push_error("InventoryTemplateDemo: unable to instantiate InventoryTemplate.")
		return
	_inventory.template_id = StringName("inventory_template_demo")
	_inventory.template_event.connect(_on_template_event)
	_template_host.add_child(_inventory)
	_inventory.apply_content(_build_inventory_content())

func _build_inventory_content() -> Dictionary:
	var items = _inventory_lite.list_items()
	var slots: Array = []
	
	for item in items:
		# Get the item definition to access the proper icon
		var item_data = ItemDatabase.get_item(item["id"])
		var item_icon = load("res://icon.svg")  # Default fallback icon
		if not item_data.is_empty():
			var icon_path = item_data.get("icon_path", "")
			if not icon_path.is_empty():
				var loaded_icon = load(icon_path)
				if loaded_icon != null:
					item_icon = loaded_icon
		
		var slot_data: Dictionary = {
			"id": item["id"],
			"name": item["display_name"],
			"quantity": item["quantity"],
			"icon": item_icon,
			"tooltip": _build_tooltip(item),
			"payload": {
				"item_id": item["id"],
				"quantity": item["quantity"]
			}
		}
		slots.append(slot_data)
	
	# Add some empty slots to fill the grid
	var empty_slots_needed = 20 - slots.size()
	for i in range(empty_slots_needed):
		slots.append({
			"id": "empty_%d" % i,
			"name": "",
			"quantity": 0,
			"icon": null,
			"state": "disabled"
		})
	
	return {
		StringName("title"): {
			StringName("fallback"): "Inventory (%d/%d)" % [_inventory_lite._items.size(), _inventory_lite.capacity]
		},
		StringName("columns"): 4,  # 4 columns for better grid layout
		StringName("slots"): slots
	}

func _build_tooltip(item: Dictionary) -> Dictionary:
	# Get additional info from JSON data for richer tooltip
	var item_data = ItemDatabase.get_item(item["id"])
	var tooltip = "%s\nQuantity: %d" % [item["display_name"], item["quantity"]]
	
	if not item_data.is_empty():
		var description = item_data.get("description", "")
		if not description.is_empty():
			tooltip += "\n\n" + description
		
		var tags = item_data.get("tags", [])
		if not tags.is_empty():
			tooltip += "\n\nTags: " + ", ".join(tags)
		
		var rarity = item_data.get("rarity", "common")
		if rarity != "common":
			tooltip += "\nRarity: " + rarity.capitalize()
	
	return {
		StringName("fallback"): tooltip
	}

func _on_template_event(event_id: StringName, payload: Dictionary) -> void:
	_append_log("%s -> %s" % [String(event_id), JSON.stringify(payload)])
	
	# Handle item interactions
	if event_id == StringName("empty_0") or event_id == StringName("empty_1"):
		_append_log("Clicked empty slot - nothing happens")
	elif payload.has("item_id"):
		var item_id = payload["item_id"]
		if item_id.begins_with("empty"):
			_append_log("Clicked empty slot - nothing happens")
		else:
			_append_log("Clicked item: %s (qty: %d)" % [item_id, payload.get("quantity", 0)])

func _on_inventory_changed() -> void:
	if _inventory != null:
		_inventory.apply_content(_build_inventory_content())

func _on_refresh_requested() -> void:
	if _inventory == null:
		return
	_inventory.apply_content(_build_inventory_content())
	_append_log("Inventory refreshed via outer button.")

func _append_log(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > LOG_LIMIT:
		_log_lines.remove_at(0)
	if _event_log != null:
		_event_log.text = "\n".join(_log_lines)
