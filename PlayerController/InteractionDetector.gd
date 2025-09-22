class_name _InteractionDetector
extends Area2D

## Area2D-based interaction detector for player controller.
## Detects objects in the "interactable" group and provides interaction interface.

signal interaction_detected(interactable: Node, interactable_position: Vector2)
signal interaction_lost(interactable: Node)
signal interaction_available_changed(available: bool)

const EventTopics = preload("res://EventBus/EventTopics.gd")

@export var interaction_range: float = 32.0
@export var interaction_group: StringName = StringName("interactable")
@export var debug_visualization: bool = false

var _current_interactable: Node = null
var _last_interaction_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Set up collision shape
	var shape := CircleShape2D.new()
	shape.radius = interaction_range

	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = shape
	add_child(collision_shape)

	# Configure area properties
	monitorable = false  # We don't need to be detected, we detect others
	monitoring = true
	collision_layer = 0  # Don't collide with physics layers
	collision_mask = 0   # We'll use groups instead

	# Connect signals
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	# Set up debug visualization if enabled
	if debug_visualization and Engine.is_editor_hint():
		_setup_debug_visualization()

func _setup_debug_visualization() -> void:
	var debug_shape := CollisionShape2D.new()
	debug_shape.shape = CircleShape2D.new()
	debug_shape.shape.radius = interaction_range
	debug_shape.debug_color = Color.YELLOW
	debug_shape.visible = true
	add_child(debug_shape)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group(interaction_group):
		_update_current_interactable(area)

func _on_area_exited(area: Area2D) -> void:
	if area == _current_interactable:
		_clear_current_interactable()

func _update_current_interactable(area: Area2D) -> void:
	var was_available := is_interaction_available()

	_current_interactable = area
	_last_interaction_position = area.global_position

	interaction_detected.emit(_current_interactable, _last_interaction_position)

	var is_now_available := is_interaction_available()
	if was_available != is_now_available:
		interaction_available_changed.emit(is_now_available)

	# Emit EventBus event for analytics
	_emit_interaction_event(&"player/interaction_detected", {
		StringName("interactable_type"): _current_interactable.get_class(),
		StringName("interactable_name"): _current_interactable.name,
		StringName("distance"): global_position.distance_to(_last_interaction_position)
	})

func _clear_current_interactable() -> void:
	if _current_interactable == null:
		return

	var was_available := is_interaction_available()

	var old_interactable := _current_interactable
	_current_interactable = null
	_last_interaction_position = Vector2.ZERO

	interaction_lost.emit(old_interactable)

	var is_now_available := is_interaction_available()
	if was_available != is_now_available:
		interaction_available_changed.emit(is_now_available)

	# Emit EventBus event for analytics
	_emit_interaction_event(&"player/interaction_lost", {
		StringName("interactable_type"): old_interactable.get_class(),
		StringName("interactable_name"): old_interactable.name
	})

func is_interaction_available() -> bool:
	return _current_interactable != null and is_instance_valid(_current_interactable)

func get_current_interactable() -> Node:
	return _current_interactable

func get_interaction_position() -> Vector2:
	return _last_interaction_position

func interact() -> void:
	if not is_interaction_available():
		return

	# Call interact method on the interactable if it exists
	if _current_interactable.has_method("interact"):
		_current_interactable.call("interact", self)

	# Emit EventBus event for analytics
	_emit_interaction_event(&"player/interaction_executed", {
		StringName("interactable_type"): _current_interactable.get_class(),
		StringName("interactable_name"): _current_interactable.name,
		StringName("interaction_position"): _last_interaction_position
	})

func _emit_interaction_event(topic: StringName, payload: Dictionary[StringName, Variant]) -> void:
	if Engine.has_singleton("EventBus"):
		payload[StringName("timestamp_ms")] = Time.get_ticks_msec()
		payload[StringName("player_position")] = global_position
		Engine.get_singleton("EventBus").call("pub", topic, payload)
