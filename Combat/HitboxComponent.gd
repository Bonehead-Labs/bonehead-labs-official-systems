class_name HitboxComponent
extends Area2D

## Component that defines areas that can deal damage to hurtboxes.
## Activates when enabled and deals damage to overlapping hurtboxes.

const EventTopics = preload("res://EventBus/EventTopics.gd")
const DamageInfoScript = preload("res://Combat/DamageInfo.gd")

signal hitbox_activated(hitbox: Variant)
signal hitbox_deactivated(hitbox: Variant)
signal damage_dealt(hurtbox: Variant, damage_info: Variant)

@export var faction: String = "neutral"
@export var damage_amount: float = 10.0
@export var damage_type: DamageInfoScript.DamageType = DamageInfoScript.DamageType.PHYSICAL
@export var source_node_path: NodePath = ^".."
@export var knockback_force: Vector2 = Vector2.ZERO
@export var knockback_duration: float = 0.2

# Activation control
@export var auto_activate: bool = false
@export var activation_duration: float = 0.5

var _source_node: Node = null
var _is_active: bool = false
var _activation_timer: float = 0.0
var _damage_dealt_this_activation: Dictionary = {}  # hurtbox -> bool

func _ready() -> void:
	# Set up area properties
	monitorable = true   # Hitboxes need to be monitorable by hurtboxes
	monitoring = false  # Hitboxes don't monitor, they are monitored

	# Resolve source node
	_resolve_source_node()

	# Auto-activate if enabled
	if auto_activate:
		activate()

func _resolve_source_node() -> void:
	if source_node_path.is_empty():
		_source_node = get_parent()
	else:
		_source_node = get_node_or_null(source_node_path)

	if not _source_node:
		push_warning("HitboxComponent: No source node found at path: ", source_node_path)

func _process(delta: float) -> void:
	if _is_active and activation_duration > 0.0:
		_activation_timer -= delta
		if _activation_timer <= 0.0:
			deactivate()

## Activate the hitbox - starts dealing damage
func activate() -> void:
	if _is_active:
		return

	_is_active = true
	_activation_timer = activation_duration
	_damage_dealt_this_activation.clear()

	hitbox_activated.emit(self)

	# EventBus analytics
	_emit_hitbox_event(EventTopics.COMBAT_HITBOX_ACTIVATED)

## Deactivate the hitbox - stops dealing damage
func deactivate() -> void:
	if not _is_active:
		return

	_is_active = false
	_activation_timer = 0.0
	_damage_dealt_this_activation.clear()

	hitbox_deactivated.emit(self)

	# EventBus analytics
	_emit_hitbox_event(EventTopics.COMBAT_HITBOX_DEACTIVATED)

## Check if hitbox is currently active
func is_active() -> bool:
	return _is_active

## Create damage info for this hitbox
func create_damage_info() -> Variant:
	var damage_info := DamageInfoScript.create_damage(damage_amount, damage_type, _source_node)
	var source_name := ""
	if _source_node:
		source_name = String(_source_node.name)
	damage_info.source_name = source_name

	if knockback_force != Vector2.ZERO:
		damage_info = damage_info.with_knockback(knockback_force, knockback_duration)

	return damage_info

## Deal damage to a specific hurtbox (used by hurtboxes when they detect overlap)
func deal_damage_to(hurtbox: Variant) -> bool:
	if not _is_active or not hurtbox.enabled:
		return false

	# Check if we've already dealt damage to this hurtbox during this activation
	if _damage_dealt_this_activation.get(hurtbox, false):
		return false

	var damage_info = create_damage_info()
	var damage_applied = hurtbox._health_component.take_damage(damage_info) if hurtbox._health_component else false

	if damage_applied:
		_damage_dealt_this_activation[hurtbox] = true
		damage_dealt.emit(hurtbox, damage_info)

		# EventBus analytics (handled by hurtbox)
		# hurtbox._emit_hurtbox_event("combat/hurtbox_hit", self, damage_info)

	return damage_applied

## Reset damage tracking (useful for multi-hit attacks)
func reset_damage_tracking() -> void:
	_damage_dealt_this_activation.clear()

## Set damage parameters dynamically
func set_damage(amount: float, type: DamageInfoScript.DamageType = damage_type) -> void:
	damage_amount = amount
	damage_type = type

## Set knockback parameters dynamically
func set_knockback(force: Vector2, duration: float = knockback_duration) -> void:
	knockback_force = force
	knockback_duration = duration

## Get activation progress (0.0 to 1.0, where 1.0 is fully timed out)
func get_activation_progress() -> float:
	if not _is_active or activation_duration <= 0.0:
		return 0.0
	return 1.0 - (_activation_timer / activation_duration)

func _emit_hitbox_event(topic: StringName) -> void:
	if Engine.has_singleton("EventBus"):
		var payload := {
			"hitbox_faction": faction,
			"damage_amount": damage_amount,
			"damage_type": "unknown",  # Simplified for now
			"hitbox_position": global_position,
			"timestamp_ms": Time.get_ticks_msec()
		}
		Engine.get_singleton("EventBus").call("pub", topic, payload)

## Enable/disable hitbox monitoring (for editor use)
func set_monitoring_enabled(enabled: bool) -> void:
	set_deferred("monitoring", enabled)

## Get the source node
func get_source_node() -> Node:
	return _source_node

## Check if this hitbox can damage a specific faction
func can_damage_faction(_other_faction: String) -> bool:
	# For now, all hitboxes can damage all factions
	# This could be extended with faction relationships
	return true
