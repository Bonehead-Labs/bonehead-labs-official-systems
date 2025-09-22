class_name HurtboxComponent
extends Area2D

## Component that defines areas on entities that can receive damage.
## Connects to HealthComponent and applies damage when overlapping with hitboxes.

const EventTopics = preload("res://EventBus/EventTopics.gd")
const DamageInfoScript = preload("res://Combat/DamageInfo.gd")

signal hurtbox_hit(hitbox: Variant, damage_info: Variant)
signal damage_taken(amount: float, source: Node, damage_info: Variant)

@export var health_component_path: NodePath = ^".."
@export var faction: String = "neutral"
@export var enabled: bool = true

# Collision filtering
@export var friendly_fire: bool = false  # Allow damage from same faction
@export var immune_factions: Array[String] = []  # Factions that cannot damage this hurtbox

var _health_component: Variant = null
var _overlapping_hitboxes: Array[Variant] = []

func _ready() -> void:
	# Set up area properties
	monitorable = false  # Hurtboxes don't need to be monitorable
	monitoring = true    # But they need to monitor for hitboxes

	# Connect signals
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	# Find health component
	_resolve_health_component()

func _resolve_health_component() -> void:
	if health_component_path.is_empty():
		_health_component = get_parent()
	else:
		_health_component = get_node_or_null(health_component_path)

	if not _health_component:
		push_warning("HurtboxComponent: No HealthComponent found at path: ", health_component_path)
		return

	# Connect to health component signals if needed
	_health_component.damaged.connect(_on_health_damaged)

func _on_area_entered(area: Area2D) -> void:
	if not enabled:
		return

	var hitbox = area
	if not hitbox or not hitbox.has_method("is_active"):
		return

	# Check faction filtering
	if not _can_take_damage_from(hitbox):
		return

	# Add to overlapping hitboxes
	if not _overlapping_hitboxes.has(hitbox):
		_overlapping_hitboxes.append(hitbox)

	# Apply damage if hitbox is active
	if hitbox.is_active():
		_apply_hitbox_damage(hitbox)

func _on_area_exited(area: Area2D) -> void:
	var hitbox = area
	if hitbox and _overlapping_hitboxes.has(hitbox):
		_overlapping_hitboxes.erase(hitbox)

func _can_take_damage_from(hitbox: Variant) -> bool:
	# Check faction compatibility
	if hitbox.faction == faction and not friendly_fire:
		return false

	if immune_factions.has(hitbox.faction):
		return false

	return true

func _apply_hitbox_damage(hitbox: Variant) -> void:
	if not _health_component:
		push_warning("HurtboxComponent: Cannot apply damage - no HealthComponent available")
		return

	var damage_info = hitbox.create_damage_info()
	if not damage_info:
		return

	# Apply damage
	var damage_applied = _health_component.take_damage(damage_info)

	if damage_applied:
		# Emit signals
		hurtbox_hit.emit(hitbox, damage_info)
		damage_taken.emit(damage_info.amount, damage_info.source, damage_info)

		# EventBus analytics
		_emit_hurtbox_event("combat/hurtbox_hit", hitbox, damage_info)

func _on_health_damaged(_amount: float, _source: Node, _damage_info: Variant) -> void:
	# This is called when any damage is applied to the health component
	# We can use this to track damage sources, etc.
	pass

func _emit_hurtbox_event(topic: StringName, hitbox: Variant, damage_info: Variant) -> void:
	if Engine.has_singleton("EventBus"):
		var payload := {
			"hurtbox_faction": faction,
			"hitbox_faction": hitbox.faction,
			"damage_amount": damage_info.amount,
			"damage_type": "unknown",
			"source_type": damage_info.source.get_class() if damage_info.source else "unknown",
			"hurtbox_position": global_position,
			"hitbox_position": hitbox.global_position,
			"timestamp_ms": Time.get_ticks_msec()
		}
		if damage_info and damage_info.type != null:
			payload["damage_type"] = "unknown"  # Simplified for now
		Engine.get_singleton("EventBus").call("pub", topic, payload)

## Enable/disable the hurtbox
func set_enabled(value: bool) -> void:
	enabled = value
	set_deferred("monitoring", value)

## Check if hurtbox can be damaged by a specific faction
func can_take_damage_from_faction(other_faction: String) -> bool:
	if other_faction == faction and not friendly_fire:
		return false
	return not immune_factions.has(other_faction)

## Get all currently overlapping active hitboxes
func get_overlapping_hitboxes() -> Array[Variant]:
	var active_hitboxes: Array[Variant] = []
	for hitbox in _overlapping_hitboxes:
		if hitbox.is_active():
			active_hitboxes.append(hitbox)
	return active_hitboxes

## Force damage application from a specific hitbox (bypasses collision filtering)
func force_damage(hitbox: Variant) -> void:
	if not enabled or not _health_component:
		return

	var damage_info = hitbox.create_damage_info()
	if damage_info and _health_component.take_damage(damage_info):
		hurtbox_hit.emit(hitbox, damage_info)
		damage_taken.emit(damage_info.amount, damage_info.source, damage_info)
		_emit_hurtbox_event(&"combat/hurtbox_hit", hitbox, damage_info)
