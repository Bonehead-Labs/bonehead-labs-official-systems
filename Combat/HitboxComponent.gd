class_name HitboxComponent
extends Area2D

## Component that defines areas that can deal damage to hurtboxes.
## Activates when enabled and deals damage to overlapping hurtboxes.

const EventTopics = preload("res://EventBus/EventTopics.gd")
const DamageInfoScript = preload("res://Combat/DamageInfo.gd")
const FactionManagerScript = preload("res://Combat/FactionManager.gd")

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

## Activate the hitbox
## 
## Enables the hitbox to start dealing damage to overlapping hurtboxes.
## Resets damage tracking to allow fresh damage dealing.
## 
## [b]Usage:[/b]
## [codeblock]
## # Activate hitbox for attack
## hitbox.activate()
## 
## # Activate with custom duration
## hitbox.activation_duration = 1.0
## hitbox.activate()
## [/codeblock]
func activate() -> void:
	if _is_active:
		return

	_is_active = true
	_activation_timer = activation_duration
	_damage_dealt_this_activation.clear()

	hitbox_activated.emit(self)

	# EventBus analytics
	_emit_hitbox_event(EventTopics.COMBAT_HITBOX_ACTIVATED)

## Deactivate the hitbox
## 
## Disables the hitbox and stops it from dealing damage.
## Clears damage tracking for the next activation.
## 
## [b]Usage:[/b]
## [codeblock]
## # Deactivate hitbox after attack
## hitbox.deactivate()
## 
## # Deactivate all hitboxes on entity
## for hitbox in get_tree().get_nodes_in_group("hitboxes"):
##     hitbox.deactivate()
## [/codeblock]
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
## 
## [b]Returns:[/b] true if hitbox is active and can deal damage, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## if hitbox.is_active():
##     print("Hitbox is dealing damage")
## else:
##     print("Hitbox is inactive")
## [/codeblock]
func is_active() -> bool:
	return _is_active

## Create damage info for this hitbox
## 
## Generates a DamageInfo instance based on the hitbox's configuration.
## 
## [b]Returns:[/b] DamageInfo instance with hitbox parameters
## 
## [b]Usage:[/b]
## [codeblock]
## # Create damage info for custom damage dealing
## var damage_info = hitbox.create_damage_info()
## damage_info.amount = 50.0  # Override amount
## target.take_damage(damage_info)
## [/codeblock]
func create_damage_info() -> Variant:
	var damage_info: DamageInfoScript = DamageInfoScript.create_damage(damage_amount, damage_type, _source_node)
	var source_name: String = ""
	if _source_node:
		source_name = String(_source_node.name)
	damage_info.source_name = source_name

	if knockback_force != Vector2.ZERO:
		damage_info = damage_info.with_knockback(knockback_force, knockback_duration)

	return damage_info

## Deal damage to a specific hurtbox
## 
## Attempts to deal damage to a hurtbox. This is called by hurtboxes
## when they detect overlap with this hitbox.
## 
## [b]hurtbox:[/b] The hurtbox to damage
## 
## [b]Returns:[/b] true if damage was successfully applied, false otherwise
## 
## [b]Usage:[/b] Called automatically by hurtboxes during overlap detection
func deal_damage_to(hurtbox: Variant) -> bool:
	if not _is_active or not hurtbox.enabled:
		return false

	# Check if we've already dealt damage to this hurtbox during this activation
	if _damage_dealt_this_activation.get(hurtbox, false):
		return false

	var damage_info: DamageInfoScript = create_damage_info()
	var damage_applied: bool = hurtbox._health_component.take_damage(damage_info) if hurtbox._health_component else false

	if damage_applied:
		_damage_dealt_this_activation[hurtbox] = true
		damage_dealt.emit(hurtbox, damage_info)

		# EventBus analytics (handled by hurtbox)
		# hurtbox._emit_hurtbox_event("combat/hurtbox_hit", self, damage_info)

	return damage_applied

## Reset damage tracking
## 
## Clears the record of which hurtboxes have been damaged during
## this activation. Useful for multi-hit attacks or continuous damage.
## 
## [b]Usage:[/b]
## [codeblock]
## # Reset for multi-hit attack
## hitbox.reset_damage_tracking()
## hitbox.activate()  # Can damage same targets again
## 
## # Reset for continuous damage
## hitbox.reset_damage_tracking()  # Allow repeated damage
## [/codeblock]
func reset_damage_tracking() -> void:
	_damage_dealt_this_activation.clear()

## Set damage parameters dynamically
## 
## Updates the damage amount and type for this hitbox.
## 
## [b]amount:[/b] New damage amount
## [b]type:[/b] New damage type (default: current type)
## 
## [b]Usage:[/b]
## [codeblock]
## # Set basic damage
## hitbox.set_damage(25.0)
## 
## # Set damage with type
## hitbox.set_damage(30.0, DamageInfo.DamageType.FIRE)
## 
## # Upgrade weapon damage
## hitbox.set_damage(hitbox.damage_amount * 1.5)
## [/codeblock]
func set_damage(amount: float, type: DamageInfoScript.DamageType = damage_type) -> void:
	damage_amount = amount
	damage_type = type

## Set knockback parameters dynamically
## 
## Updates the knockback force and duration for this hitbox.
## 
## [b]force:[/b] New knockback force vector
## [b]duration:[/b] New knockback duration (default: current duration)
## 
## [b]Usage:[/b]
## [codeblock]
## # Set knockback
## hitbox.set_knockback(Vector2(100, -50), 0.3)
## 
## # Increase knockback force
## hitbox.set_knockback(hitbox.knockback_force * 1.2)
## 
## # Remove knockback
## hitbox.set_knockback(Vector2.ZERO)
## [/codeblock]
func set_knockback(force: Vector2, duration: float = knockback_duration) -> void:
	knockback_force = force
	knockback_duration = duration

## Get activation progress
## 
## Returns how much of the activation duration has elapsed.
## 
## [b]Returns:[/b] Progress from 0.0 (just activated) to 1.0 (fully timed out)
## 
## [b]Usage:[/b]
## [codeblock]
## var progress = hitbox.get_activation_progress()
## if progress > 0.5:
##     print("Hitbox is halfway through activation")
## 
## # Use for UI progress bars
## progress_bar.value = hitbox.get_activation_progress()
## [/codeblock]
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
## 
## Returns the node that owns this hitbox (usually the entity that deals damage).
## 
## [b]Returns:[/b] Source node reference
## 
## [b]Usage:[/b]
## [codeblock]
## var source = hitbox.get_source_node()
## if source:
##     print("Hitbox belongs to: ", source.name)
## [/codeblock]
func get_source_node() -> Node:
	return _source_node

## Check if this hitbox can damage a specific faction
## 
## Uses FactionManager to determine if this hitbox's faction can damage
## the target faction based on faction relationships.
## 
## [b]_other_faction:[/b] Target faction to check
## 
## [b]Returns:[/b] true if damage is allowed, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## if hitbox.can_damage_faction("enemy"):
##     print("Hitbox can damage enemy faction")
## 
## # Check before dealing damage
## if hitbox.can_damage_faction(target.faction):
##     hitbox.deal_damage_to(target)
## [/codeblock]
func can_damage_faction(_other_faction: String) -> bool:
	# Use FactionManager for proper faction relationships
	if Engine.has_singleton("FactionManager"):
		var faction_manager: Object = Engine.get_singleton("FactionManager")
		if faction_manager and faction_manager.has_method("can_damage"):
			return faction_manager.can_damage(faction, _other_faction)

	# Fallback: only damage different factions
	return faction != _other_faction
