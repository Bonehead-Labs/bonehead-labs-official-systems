class_name HealthComponent
extends Node

## Component that manages health, damage, and invulnerability for any entity.
## Implements ISaveable for persistence and emits typed signals for combat events.

const EventTopics = preload("res://EventBus/EventTopics.gd")
const DamageInfoScript = preload("res://Combat/DamageInfo.gd")
const StatusEffectManagerScript = preload("res://Combat/StatusEffectManager.gd")

signal health_changed(old_health: float, new_health: float)
signal max_health_changed(old_max: float, new_max: float)
signal damaged(amount: float, source: Node, damage_info: DamageInfoScript)
signal healed(amount: float, source: Node, damage_info: DamageInfoScript)
signal died(source: Node, damage_info: DamageInfoScript)
signal invulnerability_changed(is_invulnerable: bool)

var _max_health: float = 100.0

@export var max_health: float = 100.0:
	set(value):
		var old_max: float = _max_health
		_max_health = max(0.0, value)
		_health = min(_health, _max_health)
		if old_max != _max_health:
			max_health_changed.emit(old_max, _max_health)

@export var invulnerability_duration: float = 0.5
@export var auto_register_with_save_service: bool = true
@export var status_effect_manager_path: NodePath = ^"../StatusEffectManager"

var _health: float = 100.0
var _is_invulnerable: bool = false
var _invulnerability_timer: float = 0.0
var _status_effect_manager: Variant = null

func _ready() -> void:
	_health = max_health
	_resolve_status_effect_manager()
	if auto_register_with_save_service:
		_register_with_save_service()

func _process(delta: float) -> void:
	if _is_invulnerable and _invulnerability_timer > 0.0:
		_invulnerability_timer -= delta
		if _invulnerability_timer <= 0.0:
			set_invulnerable(false)

## Apply damage to this entity
## 
## Processes damage information and applies it to the entity's health.
## Handles invulnerability, status effects, and death detection.
## 
## [b]damage_info:[/b] DamageInfo instance containing damage details
## 
## [b]Returns:[/b] true if damage was applied, false if blocked or invalid
## 
## [b]Usage:[/b]
## [codeblock]
## # Apply basic damage
## var damage = DamageInfo.create_damage(25.0, DamageInfo.DamageType.FIRE)
## health_component.take_damage(damage)
## 
## # Apply damage with status effects
## var poison_damage = DamageInfo.create_damage(15.0).with_status_effect("poison")
## health_component.take_damage(poison_damage)
## [/codeblock]
func take_damage(damage_info: DamageInfoScript) -> bool:
	if not damage_info.validate():
		push_error("Invalid damage info provided")
		return false

	if _is_invulnerable and damage_info.type != DamageInfoScript.DamageType.TRUE:
		# Invulnerable - emit event but don't apply damage
		_emit_damage_event(EventTopics.PLAYER_DAMAGED, damage_info.amount, damage_info.source, damage_info)
		return false

	var actual_damage: float = damage_info.amount
	var old_health: float = _health

	# Apply damage
	_health = max(0.0, _health - actual_damage)

	# Auto-invulnerability if configured
	if invulnerability_duration > 0.0 and damage_info.type != DamageInfoScript.DamageType.TRUE:
		set_invulnerable(true, invulnerability_duration)

	# Emit signals
	damaged.emit(actual_damage, damage_info.source, damage_info)
	health_changed.emit(old_health, _health)

	# Apply status effects from damage
	if _status_effect_manager and damage_info.status_effects.size() > 0:
		for effect_name in damage_info.status_effects:
			var effect: Variant = _create_status_effect_from_name(effect_name, damage_info.metadata)
			if effect:
				_status_effect_manager.apply_effect(effect)

	# EventBus analytics - use generic combat damage topic
	_emit_damage_event(EventTopics.COMBAT_HIT, actual_damage, damage_info.source, damage_info)

	# Check for death
	if _health <= 0.0 and old_health > 0.0:
		_die(damage_info.source, damage_info)

	return true

## Apply healing to this entity
## 
## Processes healing information and applies it to the entity's health.
## Healing is capped at maximum health.
## 
## [b]damage_info:[/b] DamageInfo instance with HEALING type or negative amount
## 
## [b]Returns:[/b] true if healing was applied, false if invalid or no healing needed
## 
## [b]Usage:[/b]
## [codeblock]
## # Apply basic healing
## var healing = DamageInfo.create_healing(30.0)
## health_component.heal(healing)
## 
## # Apply healing with source
## var potion_healing = DamageInfo.create_healing(50.0, potion_node)
## health_component.heal(potion_healing)
## [/codeblock]
func heal(damage_info: DamageInfoScript) -> bool:
	if not damage_info.validate():
		push_error("Invalid healing info provided")
		return false

	var actual_heal: float = damage_info.amount
	if actual_heal <= 0.0:
		return false

	var old_health: float = _health
	_health = min(max_health, _health + actual_heal)

	# Emit signals
	healed.emit(actual_heal, damage_info.source, damage_info)
	health_changed.emit(old_health, _health)

	# EventBus analytics - use generic combat heal topic
	_emit_damage_event(EventTopics.COMBAT_HEAL, actual_heal, damage_info.source, damage_info)

	return true

## Kill this entity immediately
## 
## Instantly reduces health to zero and triggers death.
## Useful for scripted deaths, environmental hazards, or special abilities.
## 
## [b]source:[/b] Node that caused the death (optional)
## [b]damage_info:[/b] DamageInfo instance for death context (optional)
## 
## [b]Usage:[/b]
## [codeblock]
## # Kill entity immediately
## health_component.kill()
## 
## # Kill with context
## health_component.kill(trap_node, trap_damage)
## [/codeblock]
func kill(source: Node = null, damage_info: DamageInfoScript = null) -> void:
	if _health <= 0.0:
		return

	var old_health: float = _health
	_health = 0.0

	health_changed.emit(old_health, _health)
	_die(source, damage_info)

## Set invulnerability state
## 
## Controls whether the entity can take damage. When enabled with a duration,
## invulnerability automatically expires after the specified time.
## 
## [b]invulnerable:[/b] Whether the entity should be invulnerable
## [b]duration:[/b] How long to remain invulnerable (-1 for permanent until manually disabled)
## 
## [b]Usage:[/b]
## [codeblock]
## # Temporary invulnerability
## health_component.set_invulnerable(true, 2.0)  # 2 seconds
## 
## # Permanent invulnerability
## health_component.set_invulnerable(true)
## 
## # Disable invulnerability
## health_component.set_invulnerable(false)
## [/codeblock]
func set_invulnerable(invulnerable: bool, duration: float = -1.0) -> void:
	var was_invulnerable: bool = _is_invulnerable
	_is_invulnerable = invulnerable

	if invulnerable and duration > 0.0:
		_invulnerability_timer = duration
	elif not invulnerable:
		_invulnerability_timer = 0.0

	if was_invulnerable != _is_invulnerable:
		invulnerability_changed.emit(_is_invulnerable)

## Get current health value
## 
## [b]Returns:[/b] Current health value
## 
## [b]Usage:[/b]
## [codeblock]
## var current_hp = health_component.get_health()
## print("Current health: ", current_hp)
## [/codeblock]
func get_health() -> float:
	return _health

## Get maximum health value
## 
## [b]Returns:[/b] Maximum health value
## 
## [b]Usage:[/b]
## [codeblock]
## var max_hp = health_component.get_max_health()
## print("Max health: ", max_hp)
## [/codeblock]
func get_max_health() -> float:
	return max_health

## Get health as a percentage
## 
## Returns the current health as a percentage of maximum health.
## 
## [b]Returns:[/b] Health percentage (0.0 to 1.0)
## 
## [b]Usage:[/b]
## [codeblock]
## var health_pct = health_component.get_health_percentage()
## health_bar.value = health_pct * 100  # For UI bar
## 
## if health_pct < 0.25:
##     print("Critical health!")
## [/codeblock]
func get_health_percentage() -> float:
	return _health / max_health if max_health > 0.0 else 0.0

## Check if entity is alive
## 
## [b]Returns:[/b] true if health > 0, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## if health_component.is_alive():
##     # Entity is alive, continue normal behavior
## else:
##     # Entity is dead, handle death logic
## [/codeblock]
func is_alive() -> bool:
	return _health > 0.0

## Check if entity has full health
## 
## [b]Returns:[/b] true if health equals maximum health, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## if health_component.is_full_health():
##     print("Entity is at full health")
##     # Maybe disable healing effects
## [/codeblock]
func is_full_health() -> bool:
	return _health >= max_health

## Check if entity is at critical health
## 
## Determines if the entity's health is below a critical threshold.
## 
## [b]threshold:[/b] Critical health threshold as percentage (default: 0.25 = 25%)
## 
## [b]Returns:[/b] true if health is below threshold, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## if health_component.is_critical_health(0.2):  # 20% threshold
##     # Trigger critical health effects
##     play_critical_health_sound()
##     show_low_health_warning()
## [/codeblock]
func is_critical_health(threshold: float = 0.25) -> bool:
	return get_health_percentage() <= threshold

## Check if entity is currently invulnerable
## 
## [b]Returns:[/b] true if invulnerable, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## if health_component.is_invulnerable():
##     # Entity is invulnerable, maybe show visual effect
##     show_invulnerability_effect()
## [/codeblock]
func is_invulnerable() -> bool:
	return _is_invulnerable

## Set current health value
## 
## Directly sets the health value, clamped to valid range (0 to max_health).
## 
## [b]new_health:[/b] New health value to set
## 
## [b]Usage:[/b]
## [codeblock]
## # Set specific health value
## health_component.set_health(75.0)
## 
## # Set health from save data
## health_component.set_health(save_data.get("health", 100.0))
## [/codeblock]
func set_health(new_health: float) -> void:
	var old_health: float = _health
	_health = clamp(new_health, 0.0, max_health)
	if old_health != _health:
		health_changed.emit(old_health, _health)

## Restore entity to full health
## 
## Sets health to maximum value. Useful for healing items, respawn, etc.
## 
## [b]Usage:[/b]
## [codeblock]
## # Full heal from potion
## health_component.restore_full_health()
## 
## # Full heal on respawn
## func respawn():
##     health_component.restore_full_health()
##     position = spawn_point
## [/codeblock]
func restore_full_health() -> void:
	set_health(max_health)

## Get remaining invulnerability time
## 
## Returns how much invulnerability time is left.
## 
## [b]Returns:[/b] Remaining invulnerability time in seconds (0 if not invulnerable)
## 
## [b]Usage:[/b]
## [codeblock]
## var remaining = health_component.get_invulnerability_time()
## if remaining > 0:
##     print("Invulnerable for ", remaining, " more seconds")
## [/codeblock]
func get_invulnerability_time() -> float:
	return _invulnerability_timer if _is_invulnerable else 0.0

## Private methods

func _die(source: Node, damage_info: DamageInfoScript) -> void:
	died.emit(source, damage_info)

	# EventBus analytics - use generic combat death topic
	_emit_damage_event(EventTopics.COMBAT_ENTITY_DEATH, 0.0, source, damage_info)

	# TODO: Could emit additional events for game over, respawn, etc.

func _create_status_effect_from_name(effect_name: String, metadata: Dictionary) -> Variant:
	"""Create a status effect from a string name and metadata."""
	match effect_name.to_lower():
		"burning", "burn":
			var duration = metadata.get("burn_duration", 5.0)
			var damage_per_tick = metadata.get("burn_damage", 5.0)
			var effect = StatusEffectManagerScript.create_dot_effect(damage_per_tick, 1.0, duration)
			effect.name = "Burning"
			effect.description = "Deals fire damage over time"
			return effect
		"poison", "poisoned":
			var duration = metadata.get("poison_duration", 8.0)
			var damage_per_tick = metadata.get("poison_damage", 3.0)
			var effect = StatusEffectManagerScript.create_dot_effect(damage_per_tick, 2.0, duration)
			effect.name = "Poisoned"
			effect.description = "Deals poison damage over time"
			return effect
		"stun", "stunned":
			var duration = metadata.get("stun_duration", 2.0)
			return StatusEffectManagerScript.create_stun_effect(duration)
		"slow", "slowed":
			var duration = metadata.get("slow_duration", 4.0)
			var multiplier = metadata.get("slow_multiplier", 0.5)
			return StatusEffectManagerScript.create_speed_debuff(multiplier, duration)
		"speed_boost", "haste":
			var duration = metadata.get("boost_duration", 5.0)
			var multiplier = metadata.get("boost_multiplier", 1.5)
			return StatusEffectManagerScript.create_speed_buff(multiplier, duration)
		_:
			push_warning("Unknown status effect: ", effect_name)
			return null

func _emit_damage_event(topic: StringName, amount: float, source: Node, damage_info: DamageInfoScript) -> void:
	if Engine.has_singleton("EventBus"):
		var entity = get_parent()
		var payload := {
			"target": entity,
			"amount": amount,
			"source": source,
			"type": DamageInfoScript.DamageType.keys()[damage_info.type] if damage_info else "unknown",
			"entity_name": entity.name if entity else "unknown",
			"entity_type": entity.get_class() if entity else "unknown",
			"position": entity.global_position if entity else Vector2.ZERO,
			"timestamp_ms": Time.get_ticks_msec()
		}
		Engine.get_singleton("EventBus").call("pub", topic, payload)

func _resolve_status_effect_manager() -> void:
	if status_effect_manager_path.is_empty():
		_status_effect_manager = get_parent().get_node_or_null("StatusEffectManager")
	else:
		_status_effect_manager = get_node_or_null(status_effect_manager_path)

	# Optional - no warning if not found, as it might not be needed for all entities

func _register_with_save_service() -> void:
	if Engine.has_singleton("SaveService"):
		var save_service := Engine.get_singleton("SaveService") as Object
		if save_service and save_service.has_method("register_saveable"):
			save_service.call("register_saveable", self)

## ISaveable Implementation

## Save health component data for persistence
## 
## Implements ISaveable interface. Saves all health-related state.
## 
## [b]Returns:[/b] Dictionary containing health data
## 
## [b]Usage:[/b] Called automatically by SaveService during save operations
func save_data() -> Dictionary:
	return {
		"health": _health,
		"max_health": max_health,
		"is_invulnerable": _is_invulnerable,
		"invulnerability_timer": _invulnerability_timer
	}

## Load health component data from save file
## 
## Implements ISaveable interface. Restores health state from saved data.
## 
## [b]data:[/b] Dictionary containing saved health data
## 
## [b]Returns:[/b] true if load succeeded, false otherwise
## 
## [b]Usage:[/b] Called automatically by SaveService during load operations
func load_data(data: Dictionary) -> bool:
	_health = data.get("health", max_health)
	max_health = data.get("max_health", 100.0)
	_is_invulnerable = data.get("is_invulnerable", false)
	_invulnerability_timer = data.get("invulnerability_timer", 0.0)

	# Ensure health is valid
	_health = clamp(_health, 0.0, max_health)

	health_changed.emit(_health, _health)  # Signal that health was loaded
	return true

## Get unique save identifier
## 
## Implements ISaveable interface. Uses parent node name for uniqueness.
## 
## [b]Returns:[/b] Unique string identifier for this health component
## 
## [b]Usage:[/b] Called automatically by SaveService for identification
func get_save_id() -> String:
	# Use parent node name for uniqueness
	var parent: Node = get_parent()
	var parent_name: String = String(parent.name) if parent else "health_component"
	return "health_" + parent_name

## Get save priority
## 
## Implements ISaveable interface. Health components save after main entity data.
## 
## [b]Returns:[/b] Priority value (15 = medium priority)
## 
## [b]Usage:[/b] Called automatically by SaveService for ordering
func get_save_priority() -> int:
	return 15  # After main entity data but before secondary systems
