class_name HealthComponent
extends Node

## Component that manages health, damage, and invulnerability for any entity.
## Implements ISaveable for persistence and emits typed signals for combat events.

const EventTopics = preload("res://EventBus/EventTopics.gd")
const DamageInfoScript = preload("res://Combat/DamageInfo.gd")

signal health_changed(old_health: float, new_health: float)
signal max_health_changed(old_max: float, new_max: float)
signal damaged(amount: float, source: Node, damage_info: DamageInfoScript)
signal healed(amount: float, source: Node, damage_info: DamageInfoScript)
signal died(source: Node, damage_info: DamageInfoScript)
signal invulnerability_changed(is_invulnerable: bool)

@export var max_health: float = 100.0:
	set(value):
		var old_max := _max_health
		_max_health = max(0.0, value)
		_health = min(_health, _max_health)
		if old_max != _max_health:
			max_health_changed.emit(old_max, _max_health)

@export var invulnerability_duration: float = 0.5
@export var auto_register_with_save_service: bool = true

var _health: float = 100.0
var _is_invulnerable: bool = false
var _invulnerability_timer: float = 0.0

func _ready() -> void:
	_health = max_health
	if auto_register_with_save_service:
		_register_with_save_service()

func _process(delta: float) -> void:
	if _is_invulnerable and _invulnerability_timer > 0.0:
		_invulnerability_timer -= delta
		if _invulnerability_timer <= 0.0:
			set_invulnerable(false)

## Apply damage to this entity
func take_damage(damage_info: DamageInfoScript) -> bool:
	if not damage_info.validate():
		push_error("Invalid damage info provided")
		return false

	if _is_invulnerable and damage_info.type != DamageInfoScript.DamageType.TRUE:
		# Invulnerable - emit event but don't apply damage
		_emit_damage_event(EventTopics.PLAYER_DAMAGED, damage_info.amount, damage_info.source, damage_info)
		return false

	var actual_damage := damage_info.amount
	var old_health := _health

	# Apply damage
	_health = max(0.0, _health - actual_damage)

	# Auto-invulnerability if configured
	if invulnerability_duration > 0.0 and damage_info.type != DamageInfoScript.DamageType.TRUE:
		set_invulnerable(true, invulnerability_duration)

	# Emit signals
	damaged.emit(actual_damage, damage_info.source, damage_info)
	health_changed.emit(old_health, _health)

	# EventBus analytics
	_emit_damage_event(EventTopics.PLAYER_DAMAGED, actual_damage, damage_info.source, damage_info)

	# Check for death
	if _health <= 0.0 and old_health > 0.0:
		_die(damage_info.source, damage_info)

	return true

## Apply healing to this entity
func heal(damage_info: DamageInfoScript) -> bool:
	if not damage_info.validate():
		push_error("Invalid healing info provided")
		return false

	var actual_heal := damage_info.amount
	if actual_heal <= 0.0:
		return false

	var old_health := _health
	_health = min(max_health, _health + actual_heal)

	# Emit signals
	healed.emit(actual_heal, damage_info.source, damage_info)
	health_changed.emit(old_health, _health)

	# EventBus analytics
	_emit_damage_event(EventTopics.PLAYER_HEALED, actual_heal, damage_info.source, damage_info)

	return true

## Kill this entity immediately
func kill(source: Node = null, damage_info: DamageInfoScript = null) -> void:
	if _health <= 0.0:
		return

	var old_health := _health
	_health = 0.0

	health_changed.emit(old_health, _health)
	_die(source, damage_info)

## Set invulnerability state
func set_invulnerable(invulnerable: bool, duration: float = -1.0) -> void:
	var was_invulnerable := _is_invulnerable
	_is_invulnerable = invulnerable

	if invulnerable and duration > 0.0:
		_invulnerability_timer = duration
	elif not invulnerable:
		_invulnerability_timer = 0.0

	if was_invulnerable != _is_invulnerable:
		invulnerability_changed.emit(_is_invulnerable)

## Get current health
func get_health() -> float:
	return _health

## Get maximum health
func get_max_health() -> float:
	return max_health

## Get health as a percentage (0.0 to 1.0)
func get_health_percentage() -> float:
	return _health / max_health if max_health > 0.0 else 0.0

## Check if entity is alive (health > 0)
func is_alive() -> bool:
	return _health > 0.0

## Check if entity has full health
func is_full_health() -> bool:
	return _health >= max_health

## Check if entity is at critical health (configurable threshold)
func is_critical_health(threshold: float = 0.25) -> bool:
	return get_health_percentage() <= threshold

## Check if entity is invulnerable
func is_invulnerable() -> bool:
	return _is_invulnerable

## Set current health (clamped to valid range)
func set_health(new_health: float) -> void:
	var old_health := _health
	_health = clamp(new_health, 0.0, max_health)
	if old_health != _health:
		health_changed.emit(old_health, _health)

## Restore full health
func restore_full_health() -> void:
	set_health(max_health)

## Get remaining invulnerability time
func get_invulnerability_time() -> float:
	return _invulnerability_timer if _is_invulnerable else 0.0

## Private methods

func _die(source: Node, damage_info: DamageInfoScript) -> void:
	died.emit(source, damage_info)

	# EventBus analytics
	_emit_damage_event(EventTopics.PLAYER_DIED, 0.0, source, damage_info)

	# TODO: Could emit additional events for game over, respawn, etc.

func _emit_damage_event(topic: StringName, amount: float, source: Node, damage_info: DamageInfoScript) -> void:
	if Engine.has_singleton("EventBus"):
		var payload := {
			"amount": amount,
			"hp_after": _health,
			"source_type": source.get_class() if source else "unknown",
			"damage_type": DamageInfoScript.DamageType.keys()[damage_info.type],
			"entity_position": get_parent().global_position if get_parent() else Vector2.ZERO,
			"timestamp_ms": Time.get_ticks_msec()
		}
		Engine.get_singleton("EventBus").call("pub", topic, payload)

func _register_with_save_service() -> void:
	if Engine.has_singleton("SaveService"):
		var save_service := Engine.get_singleton("SaveService") as Object
		if save_service and save_service.has_method("register_saveable"):
			save_service.call("register_saveable", self)

## ISaveable Implementation

func save_data() -> Dictionary:
	return {
		"health": _health,
		"max_health": max_health,
		"is_invulnerable": _is_invulnerable,
		"invulnerability_timer": _invulnerability_timer
	}

func load_data(data: Dictionary) -> bool:
	_health = data.get("health", max_health)
	max_health = data.get("max_health", 100.0)
	_is_invulnerable = data.get("is_invulnerable", false)
	_invulnerability_timer = data.get("invulnerability_timer", 0.0)

	# Ensure health is valid
	_health = clamp(_health, 0.0, max_health)

	health_changed.emit(_health, _health)  # Signal that health was loaded
	return true

func get_save_id() -> String:
	# Use parent node name for uniqueness
	var parent_name := get_parent().name if get_parent() else "health_component"
	return "health_" + parent_name

func get_save_priority() -> int:
	return 15  # After main entity data but before secondary systems
