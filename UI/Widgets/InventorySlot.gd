class_name InventorySlot
extends Button

## Custom widget for inventory slots with proper centering and layout control

signal slot_clicked(slot_data: Dictionary)

@export var slot_size: Vector2 = Vector2(140, 140)  # Increased size for better layout

var _icon_rect: TextureRect
var _name_label: Label
var _quantity_label: Label
var _slot_data: Dictionary = {}

func _init() -> void:
	custom_minimum_size = slot_size
	focus_mode = Control.FOCUS_ALL
	text = ""
	
	# Create the main container with proper anchoring
	var main_container = Control.new()
	main_container.name = "MainContainer"
	main_container.anchor_left = 0.0
	main_container.anchor_right = 1.0
	main_container.anchor_top = 0.0
	main_container.anchor_bottom = 1.0
	main_container.offset_left = 0
	main_container.offset_right = 0
	main_container.offset_top = 0
	main_container.offset_bottom = 0
	main_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse events
	add_child(main_container)
	
	# Create the icon with proper centering using anchors
	_icon_rect = TextureRect.new()
	_icon_rect.name = "Icon"
	_icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.anchor_left = 0.5
	_icon_rect.anchor_right = 0.5
	_icon_rect.anchor_top = 0.4
	_icon_rect.anchor_bottom = 0.4
	_icon_rect.offset_left = -32  # Half of 64
	_icon_rect.offset_right = 32
	_icon_rect.offset_top = -32
	_icon_rect.offset_bottom = 32
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.add_child(_icon_rect)
	
	# Create the quantity label (above icon)
	_quantity_label = Label.new()
	_quantity_label.name = "QuantityLabel"
	_quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quantity_label.visible = false
	_quantity_label.anchor_left = 0.1
	_quantity_label.anchor_right = 0.9
	_quantity_label.anchor_top = 0.1
	_quantity_label.anchor_bottom = 0.25
	_quantity_label.offset_left = 0
	_quantity_label.offset_right = 0
	_quantity_label.offset_top = 0
	_quantity_label.offset_bottom = 0
	_quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.add_child(_quantity_label)
	
	# Create the name label (below icon)
	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.clip_contents = true
	_name_label.anchor_left = 0.05
	_name_label.anchor_right = 0.95
	_name_label.anchor_top = 0.65
	_name_label.anchor_bottom = 0.85
	_name_label.offset_left = 0
	_name_label.offset_right = 0
	_name_label.offset_top = 0
	_name_label.offset_bottom = 0
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.add_child(_name_label)
	
	# Connect the button press
	pressed.connect(_on_slot_pressed)

func set_slot_data(data: Dictionary) -> void:
	_slot_data = data
	
	# Set the icon
	var icon = data.get("icon", null)
	if icon != null:
		_icon_rect.texture = icon
	else:
		_icon_rect.texture = null
	
	# Set the name
	var name_text = data.get("name", data.get("label", ""))
	_name_label.text = name_text
	
	# Set the quantity
	var quantity = data.get("quantity", 0)
	if quantity > 1:
		_quantity_label.text = "x%d" % quantity
		_quantity_label.visible = true
	else:
		_quantity_label.visible = false
	
	# Set the tooltip
	var tooltip = data.get("tooltip", "")
	if tooltip is Dictionary:
		tooltip_text = tooltip.get("fallback", "")
	else:
		tooltip_text = str(tooltip)
	
	# Set disabled state
	disabled = data.get("state", "") == "disabled"

func _on_slot_pressed() -> void:
	slot_clicked.emit(_slot_data)
