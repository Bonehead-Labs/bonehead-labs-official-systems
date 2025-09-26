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
## 
## Adds a status effect to the entity. If the effect already exists,
## it will refresh the duration and add stacks according to stacking rules.
## 
## [b]effect:[/b] StatusEffect instance to apply
## 
## [b]Returns:[/b] true if effect was applied successfully, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## # Apply a poison effect
## var poison = StatusEffectManager.create_dot_effect(5.0, 1.0, 10.0)
## status_manager.apply_effect(poison)
## 
## # Apply a speed buff
## var speed_boost = StatusEffectManager.create_speed_buff(1.5, 30.0)
## status_manager.apply_effect(speed_boost)
## [/codeblock]
func apply_effect(effect: StatusEffect) -> bool:
	var effect_id: String = effect.id

	if _active_effects.has(effect_id):
		# Effect already exists - handle stacking
		var existing_effect: StatusEffect = _active_effects[effect_id]

		# Refresh duration
		existing_effect.refresh_duration(effect.duration)

		# Add stacks
		var stacks_added: int = existing_effect.add_stacks(effect.current_stacks)
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
## 
## Removes a status effect from the entity and calls its expire callback.
## 
## [b]effect_id:[/b] ID of the effect to remove
## 
## [b]Returns:[/b] true if effect was removed, false if not found
## 
## [b]Usage:[/b]
## [codeblock]
## # Remove specific effect
## status_manager.remove_effect("poison")
## 
## # Remove all debuffs
## for effect in status_manager.get_active_effects():
##     if effect.id.ends_with("_debuff"):
##         status_manager.remove_effect(effect.id)
## [/codeblock]
func remove_effect(effect_id: String) -> bool:
	if not _active_effects.has(effect_id):
		return false

	var effect: StatusEffect = _active_effects[effect_id]
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
## 
## [b]effect_id:[/b] ID of the effect to check for
## 
## [b]Returns:[/b] true if effect is active, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## if status_manager.has_effect("poison"):
##     print("Entity is poisoned")
## 
## # Check for multiple effects
## if status_manager.has_effect("stun") or status_manager.has_effect("sleep"):
##     print("Entity is incapacitated")
## [/codeblock]
func has_effect(effect_id: String) -> bool:
	return _active_effects.has(effect_id)

## Get a status effect by ID
## 
## [b]effect_id:[/b] ID of the effect to retrieve
## 
## [b]Returns:[/b] StatusEffect instance or null if not found
## 
## [b]Usage:[/b]
## [codeblock]
## var poison = status_manager.get_effect("poison")
## if poison:
##     print("Poison stacks: ", poison.current_stacks)
##     print("Time remaining: ", poison.remaining_time)
## 
## # Modify effect properties
## var speed_boost = status_manager.get_effect("speed_buff")
## if speed_boost:
##     speed_boost.metadata["speed_multiplier"] = 2.0
## [/codeblock]
func get_effect(effect_id: String) -> StatusEffect:
	return _active_effects.get(effect_id, null)

## Get all active status effects
## 
## [b]Returns:[/b] Array of all active StatusEffect instances
## 
## [b]Usage:[/b]
## [codeblock]
## var effects = status_manager.get_active_effects()
## print("Active effects: ", effects.size())
## 
## # List all effect names
## for effect in effects:
##     print("- ", effect.name, " (", effect.current_stacks, " stacks)")
## 
## # Filter by type
## var debuffs = effects.filter(func(e): return e.id.ends_with("_debuff"))
## [/codeblock]
func get_active_effects() -> Array[StatusEffect]:
	return _effect_instances.duplicate()

## Get effect stack count
## 
## [b]effect_id:[/b] ID of the effect to check
## 
## [b]Returns:[/b] Number of stacks (0 if effect not found)
## 
## [b]Usage:[/b]
## [codeblock]
## var poison_stacks = status_manager.get_effect_stacks("poison")
## if poison_stacks > 3:
##     print("Severely poisoned!")
## 
## # Check for maximum stacks
## var buff_stacks = status_manager.get_effect_stacks("damage_buff")
## if buff_stacks >= 5:
##     print("Maximum damage buff reached")
## [/codeblock]
func get_effect_stacks(effect_id: String) -> int:
	var effect: StatusEffect = get_effect(effect_id)
	return effect.current_stacks if effect else 0

## Clear all status effects
## 
## Removes all active status effects from the entity.
## 
## [b]Usage:[/b]
## [codeblock]
## # Clear all effects (e.g., on death)
## status_manager.clear_all_effects()
## 
## # Clear effects on respawn
## func respawn():
##     status_manager.clear_all_effects()
##     health_component.restore_full_health()
## [/codeblock]
func clear_all_effects() -> void:
	var effect_ids: Array = _active_effects.keys()
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

## Get movement speed modifier
## 
## Calculates the combined speed modifier from all active effects.
## 
## [b]Returns:[/b] Speed multiplier (1.0 = normal speed)
## 
## [b]Usage:[/b]
## [codeblock]
## var speed_modifier = status_manager.get_movement_speed_modifier()
## var final_speed = base_speed * speed_modifier
## 
## # Apply to movement system
## character.velocity = input_direction * base_speed * speed_modifier
## [/codeblock]
func get_movement_speed_modifier() -> float:
	var modifier: float = 1.0
	for effect in _effect_instances:
		if effect.metadata.has("speed_multiplier"):
			modifier *= effect.metadata["speed_multiplier"]
	return modifier

## Get damage dealt modifier
## 
## Calculates the combined damage multiplier for outgoing damage.
## 
## [b]Returns:[/b] Damage multiplier (1.0 = normal damage)
## 
## [b]Usage:[/b]
## [codeblock]
## var damage_modifier = status_manager.get_damage_dealt_modifier()
## var final_damage = base_damage * damage_modifier
## 
## # Apply to damage calculation
## damage_info.amount = base_damage * damage_modifier
## [/codeblock]
func get_damage_dealt_modifier() -> float:
	var modifier: float = 1.0
	for effect in _effect_instances:
		if effect.id == "damage_buff" and effect.metadata.has("damage_multiplier"):
			modifier *= effect.metadata["damage_multiplier"]
	return modifier

## Get damage taken modifier
## 
## Calculates the combined damage reduction for incoming damage.
## 
## [b]Returns:[/b] Damage multiplier (1.0 = normal damage, <1.0 = reduction)
## 
## [b]Usage:[/b]
## [codeblock]
## var damage_reduction = status_manager.get_damage_taken_modifier()
## var final_damage = incoming_damage * damage_reduction
## 
## # Apply to damage calculation
## damage_info.amount = base_damage * damage_reduction
## [/codeblock]
func get_damage_taken_modifier() -> float:
	var modifier: float = 1.0
	for effect in _effect_instances:
		if effect.id == "damage_reduction" and effect.metadata.has("damage_multiplier"):
			modifier *= effect.metadata["damage_multiplier"]
	return modifier

## Check if entity is stunned
## 
## [b]Returns:[/b] true if entity has stun effect, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## if status_manager.is_stunned():
##     # Disable movement and abilities
##     character.set_physics_process(false)
##     return
## 
## # Check before allowing actions
## if not status_manager.is_stunned():
##     character.perform_action()
## [/codeblock]
func is_stunned() -> bool:
	return has_effect("stun")

## Check if entity is invulnerable
## 
## [b]Returns:[/b] true if entity has invulnerability effect, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## if status_manager.is_invulnerable():
##     # Skip damage calculation
##     return
## 
## # Check before taking damage
## if not status_manager.is_invulnerable():
##     health_component.take_damage(damage_info)
## [/codeblock]
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
