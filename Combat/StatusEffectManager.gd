class_name StatusEffectManager
extends Node

## Manager for status effects including DoT, buffs, debuffs with timers.
## Supports stacking rules and provides hooks for movement/ability systems.

const EventTopics = preload("res://EventBus/EventTopics.gd")

signal status_effect_applied(effect_id: String, stacks: int)
signal status_effect_expired(effect_id: String)
signal status_effect_stacks_changed(effect_id: String, old_stacks: int, new_stacks: int)

# Status effect data structure
class StatusEffect:
	var id: String
	var name: String
	var description: String
	var duration: float
	var remaining_time: float
	var max_stacks: int = 1
	var current_stacks: int = 1
	var tick_interval: float = 0.0  # For DoT effects
	var last_tick_time: float = 0.0
	var metadata: Dictionary = {}
	var on_apply: Callable = Callable()
	var on_tick: Callable = Callable()
	var on_expire: Callable = Callable()
	var on_stack: Callable = Callable()

	func _init(p_id: String, p_name: String = "", p_description: String = "") -> void:
		id = p_id
		name = p_name if p_name else p_id
		description = p_description

	func update(delta: float) -> void:
		remaining_time -= delta

		# Handle ticking effects (DoT, HoT)
		if tick_interval > 0.0 and current_stacks > 0:
			last_tick_time += delta
			if last_tick_time >= tick_interval:
				if on_tick.is_valid():
					on_tick.call(self)
				last_tick_time = 0.0

	func is_expired() -> bool:
		return remaining_time <= 0.0

	func refresh_duration(new_duration: float) -> void:
		remaining_time = new_duration

	func add_stacks(amount: int) -> int:
		var old_stacks = current_stacks
		current_stacks = min(current_stacks + amount, max_stacks)
		return current_stacks - old_stacks

	func remove_stacks(amount: int) -> int:
		var old_stacks = current_stacks
		current_stacks = max(current_stacks - amount, 0)
		return old_stacks - current_stacks

var _active_effects: Dictionary = {}  # effect_id -> StatusEffect
var _effect_instances: Array[StatusEffect] = []

func _ready() -> void:
	# Set up processing
	set_process(true)

func _process(delta: float) -> void:
	_update_effects(delta)
	_cleanup_expired_effects()

## Apply a status effect
func apply_effect(effect: StatusEffect) -> bool:
	var effect_id = effect.id

	if _active_effects.has(effect_id):
		# Effect already exists - handle stacking
		var existing_effect = _active_effects[effect_id]

		# Refresh duration
		existing_effect.refresh_duration(effect.duration)

		# Add stacks
		var stacks_added = existing_effect.add_stacks(effect.current_stacks)
		if stacks_added > 0:
			status_effect_stacks_changed.emit(effect_id, existing_effect.current_stacks - stacks_added, existing_effect.current_stacks)
			if existing_effect.on_stack.is_valid():
				existing_effect.on_stack.call(existing_effect, stacks_added)

		return true
	else:
		# New effect
		_active_effects[effect_id] = effect
		_effect_instances.append(effect)

		# Call apply callback
		if effect.on_apply.is_valid():
			effect.on_apply.call(effect)

		status_effect_applied.emit(effect_id, effect.current_stacks)

		# EventBus analytics
		_emit_status_event("applied", effect)

		return true

## Remove a status effect
func remove_effect(effect_id: String) -> bool:
	if not _active_effects.has(effect_id):
		return false

	var effect = _active_effects[effect_id]
	_active_effects.erase(effect_id)
	_effect_instances.erase(effect)

	# Call expire callback
	if effect.on_expire.is_valid():
		effect.on_expire.call(effect)

	status_effect_expired.emit(effect_id)

	# EventBus analytics
	_emit_status_event("expired", effect)

	return true

## Check if entity has a specific status effect
func has_effect(effect_id: String) -> bool:
	return _active_effects.has(effect_id)

## Get a status effect by ID
func get_effect(effect_id: String) -> StatusEffect:
	return _active_effects.get(effect_id, null)

## Get all active effects
func get_active_effects() -> Array[StatusEffect]:
	return _effect_instances.duplicate()

## Get effect stacks
func get_effect_stacks(effect_id: String) -> int:
	var effect = get_effect(effect_id)
	return effect.current_stacks if effect else 0

## Clear all status effects
func clear_all_effects() -> void:
	var effect_ids = _active_effects.keys()
	for effect_id in effect_ids:
		remove_effect(effect_id)

## Create common status effects

static func create_dot_effect(damage_per_tick: float, tick_interval: float, duration: float) -> StatusEffect:
	var effect = StatusEffect.new("dot", "Damage Over Time", "Deals damage periodically")
	effect.duration = duration
	effect.tick_interval = tick_interval
	effect.metadata["damage_per_tick"] = damage_per_tick
	effect.on_tick = func(effect_instance):
		var damage = effect_instance.metadata.get("damage_per_tick", 0.0) * effect_instance.current_stacks
		# This would need to be connected to the health system
		print("DoT tick: ", damage, " damage")
	return effect

static func create_speed_buff(multiplier: float, duration: float) -> StatusEffect:
	var effect = StatusEffect.new("speed_buff", "Speed Boost", "Increases movement speed")
	effect.duration = duration
	effect.metadata["speed_multiplier"] = multiplier
	return effect

static func create_speed_debuff(multiplier: float, duration: float) -> StatusEffect:
	var effect = StatusEffect.new("speed_debuff", "Slowed", "Reduces movement speed")
	effect.duration = duration
	effect.metadata["speed_multiplier"] = multiplier
	return effect

static func create_damage_buff(multiplier: float, duration: float) -> StatusEffect:
	var effect = StatusEffect.new("damage_buff", "Damage Boost", "Increases damage dealt")
	effect.duration = duration
	effect.metadata["damage_multiplier"] = multiplier
	return effect

static func create_damage_reduction_buff(multiplier: float, duration: float) -> StatusEffect:
	var effect = StatusEffect.new("damage_reduction", "Damage Reduction", "Reduces damage taken")
	effect.duration = duration
	effect.metadata["damage_multiplier"] = multiplier  # < 1.0 for reduction
	return effect

static func create_stun_effect(duration: float) -> StatusEffect:
	var effect = StatusEffect.new("stun", "Stunned", "Unable to move or act")
	effect.duration = duration
	return effect

static func create_invulnerability_effect(duration: float) -> StatusEffect:
	var effect = StatusEffect.new("invulnerable", "Invulnerable", "Immune to damage")
	effect.duration = duration
	return effect

## Movement system hooks

func get_movement_speed_modifier() -> float:
	var modifier = 1.0
	for effect in _effect_instances:
		if effect.metadata.has("speed_multiplier"):
			modifier *= effect.metadata["speed_multiplier"]
	return modifier

func get_damage_dealt_modifier() -> float:
	var modifier = 1.0
	for effect in _effect_instances:
		if effect.id == "damage_buff" and effect.metadata.has("damage_multiplier"):
			modifier *= effect.metadata["damage_multiplier"]
	return modifier

func get_damage_taken_modifier() -> float:
	var modifier = 1.0
	for effect in _effect_instances:
		if effect.id == "damage_reduction" and effect.metadata.has("damage_multiplier"):
			modifier *= effect.metadata["damage_multiplier"]
	return modifier

func is_stunned() -> bool:
	return has_effect("stun")

func is_invulnerable() -> bool:
	return has_effect("invulnerable")

## Private methods

func _update_effects(delta: float) -> void:
	for effect in _effect_instances:
		effect.update(delta)

func _cleanup_expired_effects() -> void:
	var expired_effects = []
	for effect in _effect_instances:
		if effect.is_expired():
			expired_effects.append(effect)

	for effect in expired_effects:
		remove_effect(effect.id)

func _emit_status_event(action: String, effect: StatusEffect) -> void:
	if Engine.has_singleton("EventBus"):
		var payload := {
			"effect_id": effect.id,
			"effect_name": effect.name,
			"stacks": effect.current_stacks,
			"duration": effect.duration,
			"remaining": effect.remaining_time,
			"action": action,
			"entity_position": get_parent().global_position if get_parent() else Vector2.ZERO,
			"timestamp_ms": Time.get_ticks_msec()
		}
		Engine.get_singleton("EventBus").call("pub", &"combat/status_effect_" + action, payload)
