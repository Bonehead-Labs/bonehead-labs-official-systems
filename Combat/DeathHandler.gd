class_name DeathHandler
extends Node

## Component that handles entity death - animations, loot, respawning, analytics.
## Provides comprehensive death handling with FlowManager integration.

const EventTopics = preload("res://EventBus/EventTopics.gd")

signal death_started(entity: Node, death_info: Dictionary)
signal death_animation_started(entity: Node, animation_name: String)
signal death_animation_completed(entity: Node, animation_name: String)
signal loot_dropped(entity: Node, loot_items: Array)
signal respawn_started(entity: Node, respawn_position: Vector2)
signal respawn_completed(entity: Node, respawn_position: Vector2)

@export var death_animation_scene: PackedScene
@export var death_animation_duration: float = 2.0
@export var auto_drop_loot: bool = true
@export var loot_table_path: String = ""
@export var respawn_enabled: bool = false
@export var respawn_delay: float = 3.0
@export var respawn_position: Vector2 = Vector2.ZERO
@export var respawn_scene_transition: bool = false
@export var respawn_transition_name: String = "fade"

# Analytics and debugging
@export var emit_analytics: bool = true
@export var emit_debug_info: bool = false

var _parent_entity: Node = null
var _health_component: Variant = null
var _is_dying: bool = false
var _death_animation_instance: Node = null
var _respawn_timer: float = 0.0

func _ready() -> void:
	_resolve_entity()
	_resolve_health_component()
	_connect_signals()

func _resolve_entity() -> void:
	_parent_entity = get_parent()
	if not _parent_entity:
		push_warning("DeathHandler: No parent entity found")

func _resolve_health_component() -> void:
	if _parent_entity:
		_health_component = _parent_entity.get_node_or_null("HealthComponent")
		if not _health_component:
			push_warning("DeathHandler: No HealthComponent found on entity")

func _connect_signals() -> void:
	if _health_component and _health_component.has_signal("died"):
		_health_component.died.connect(_on_entity_died)

func _process(delta: float) -> void:
	if _respawn_timer > 0.0:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_perform_respawn()

## Handle entity death
func handle_death(entity: Node, damage_info: Variant = null) -> void:
	if _is_dying:
		return

	_is_dying = true

	var death_info = {
		"entity": entity,
		"damage_info": damage_info,
		"position": entity.global_position,
		"faction": "unknown",
		"timestamp": Time.get_ticks_msec()
	}

	# Get faction info
	if entity.has_node("HurtboxComponent"):
		var hurtbox = entity.get_node("HurtboxComponent")
		death_info["faction"] = hurtbox.faction

	death_started.emit(entity, death_info)

	# Emit analytics
	if emit_analytics:
		_emit_death_analytics(death_info)

	# Start death sequence
	_start_death_sequence(entity, death_info)

## Start the death animation and effects
func _start_death_sequence(entity: Node, death_info: Dictionary) -> void:
	# Play death animation
	if death_animation_scene:
		_play_death_animation(entity, death_info)
	else:
		# No animation, proceed directly to cleanup
		_complete_death_sequence(entity, death_info)

## Play death animation
func _play_death_animation(entity: Node, death_info: Dictionary) -> void:
	var animation_name = "death"

	death_animation_started.emit(entity, animation_name)

	if emit_debug_info:
		print("DeathHandler: Starting death animation for ", entity.name)

	# Create animation instance
	_death_animation_instance = death_animation_scene.instantiate()
	entity.add_child(_death_animation_instance)

	# Position at entity location
	_death_animation_instance.global_position = entity.global_position

	# Set up animation completion callback
	var timer = get_tree().create_timer(death_animation_duration)
	timer.timeout.connect(func():
		death_animation_completed.emit(entity, animation_name)
		_complete_death_sequence(entity, death_info)
	)

## Complete the death sequence (animation done, drop loot, start respawn)
func _complete_death_sequence(entity: Node, death_info: Dictionary) -> void:
	if emit_debug_info:
		print("DeathHandler: Completing death sequence for ", entity.name)

	# Drop loot
	if auto_drop_loot:
		_drop_loot(entity, death_info)

	# Hide or disable the entity
	_set_entity_dead_state(entity, true)

	# Start respawn if enabled
	if respawn_enabled:
		_start_respawn(entity, death_info)
	else:
		# No respawn, entity stays dead
		_is_dying = false

## Drop loot for the entity
func _drop_loot(entity: Node, death_info: Dictionary) -> void:
	var loot_items = []

	# Generate loot based on loot table or entity properties
	if loot_table_path != "":
		loot_items = _generate_loot_from_table(loot_table_path, entity)
	else:
		loot_items = _generate_default_loot(entity)

	if not loot_items.is_empty():
		loot_dropped.emit(entity, loot_items)

		# Actually spawn the loot items in the world
		_spawn_loot_items(entity.global_position, loot_items, death_info)

	if emit_debug_info:
		print("DeathHandler: Dropped ", loot_items.size(), " loot items for ", entity.name)

## Generate loot from a loot table
func _generate_loot_from_table(_table_path: String, _entity: Node) -> Array:
	# TODO: Implement loot table system integration
	# For now, return empty array
	push_warning("DeathHandler: Loot table system not yet implemented")
	return []

## Generate default loot based on entity properties
func _generate_default_loot(_entity: Node) -> Array:
	# TODO: Implement default loot generation based on entity type, level, etc.
	# For now, return empty array
	return []

## Spawn loot items in the world
func _spawn_loot_items(_position: Vector2, loot_items: Array, _death_info: Dictionary) -> void:
	# TODO: Implement actual loot spawning
	# This would create pickup nodes for each loot item
	for item in loot_items:
		if emit_debug_info:
			print("DeathHandler: Would spawn loot item: ", item)

## Set the entity's dead/alive state
func _set_entity_dead_state(entity: Node, dead: bool) -> void:
	# Disable physics/movement
	if entity is CharacterBody2D:
		entity.velocity = Vector2.ZERO
		entity.set_physics_process(not dead)

	# Disable hurtbox
	if entity.has_node("HurtboxComponent"):
		var hurtbox = entity.get_node("HurtboxComponent")
		hurtbox.set_enabled(not dead)

	# Hide visual components
	if entity.has_node("AnimatedSprite2D"):
		var sprite = entity.get_node("AnimatedSprite2D")
		sprite.visible = not dead
	elif entity.has_node("Sprite2D"):
		var sprite = entity.get_node("Sprite2D")
		sprite.visible = not dead

## Start the respawn process
func _start_respawn(entity: Node, _death_info: Dictionary) -> void:
	if emit_debug_info:
		print("DeathHandler: Starting respawn for ", entity.name, " in ", respawn_delay, " seconds")

	respawn_started.emit(entity, respawn_position)
	_respawn_timer = respawn_delay

## Perform the actual respawn
func _perform_respawn() -> void:
	if not _parent_entity:
		return

	if emit_debug_info:
		print("DeathHandler: Performing respawn for ", _parent_entity.name)

	# Reset entity state
	_reset_entity_for_respawn(_parent_entity)

	# Move to respawn position
	_parent_entity.global_position = respawn_position

	# Re-enable entity
	_set_entity_dead_state(_parent_entity, false)

	# Reset health
	if _health_component:
		_health_component.set_health(_health_component.get_max_health())

	# Clear status effects
	if _parent_entity.has_node("StatusEffectManager"):
		var status_manager = _parent_entity.get_node("StatusEffectManager")
		status_manager.clear_all_effects()

	respawn_completed.emit(_parent_entity, respawn_position)
	_is_dying = false

## Reset entity to respawn-ready state
func _reset_entity_for_respawn(entity: Node) -> void:
	# Reset velocity
	if entity is CharacterBody2D:
		entity.velocity = Vector2.ZERO

	# Reset any custom state
	if entity.has_method("_on_respawn"):
		entity._on_respawn()

## Handle entity death signal from HealthComponent
func _on_entity_died(_source: Node, damage_info: Variant) -> void:
	handle_death(_parent_entity, damage_info)

## Emit death analytics
func _emit_death_analytics(death_info: Dictionary) -> void:
	if not Engine.has_singleton("EventBus"):
		return

	var payload = {
		"entity_name": death_info.get("entity", {}).name if death_info.get("entity") else "unknown",
		"entity_type": death_info.get("entity", {}).get_class() if death_info.get("entity") else "unknown",
		"faction": death_info.get("faction", "unknown"),
		"position": death_info.get("position", Vector2.ZERO),
		"damage_source": death_info.get("damage_info", {}).get("source_name", "unknown") if death_info.get("damage_info") else "unknown",
		"damage_type": "unknown",
		"timestamp_ms": death_info.get("timestamp", Time.get_ticks_msec())
	}

	# Add damage type if available
	if death_info.get("damage_info") and death_info["damage_info"].has("type"):
		var _damage_type_enum = death_info["damage_info"]["type"]
		payload["damage_type"] = "unknown"  # Simplified for now

	Engine.get_singleton("EventBus").call("pub", &"combat/entity_death", payload)

## Configure respawn settings
func set_respawn_enabled(enabled: bool, delay: float = 3.0, position: Vector2 = Vector2.ZERO) -> void:
	respawn_enabled = enabled
	respawn_delay = delay
	respawn_position = position

## Get current death state
func is_entity_dying() -> bool:
	return _is_dying

## Force immediate death (bypasses normal death sequence)
func force_death(entity: Node = null) -> void:
	if not entity:
		entity = _parent_entity
	if entity and _health_component:
		_health_component.kill()

## Force immediate respawn
func force_respawn() -> void:
	if _respawn_timer > 0.0:
		_respawn_timer = 0.0
		_perform_respawn()
