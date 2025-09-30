class_name AbilityManager
extends Node

## Central coordinator that manages ability lifecycle, input routing, updates, and motion arbitration.

const AbilityScript = preload("res://PlayerController/Ability.gd")

signal ability_registered(ability_id: StringName, ability: AbilityScript)
signal ability_unregistered(ability_id: StringName)
signal ability_started(ability_id: StringName)
signal ability_ended(ability_id: StringName)
signal ability_failed(ability_id: StringName, reason: String)

@export var verbose: bool = false
@export var default_abilities: Dictionary = {}
@export var auto_activate_ids: Array[StringName] = []

var _controller: Node = null
var _event_bus: Node = null
var _abilities: Dictionary[StringName, AbilityScript] = {}
var _registration_order: Array[StringName] = []
var _active_ids: Array[StringName] = []
var _active_lookup: Dictionary[StringName, bool] = {}
var _motion_owner: StringName = StringName()
var _motion_velocity: Vector2 = Vector2.ZERO
var _failed_events: Array[Dictionary] = []

func setup(controller: Node) -> void:
	_controller = controller
	_event_bus = Engine.get_singleton("EventBus") if Engine.has_singleton("EventBus") else null
	_auto_register_defaults()

func has_controller() -> bool:
	return _controller != null

func register_ability(ability_id: StringName, ability: AbilityScript, auto_activate: bool = false) -> void:
	if ability_id == StringName():
		push_error("AbilityManager: ability id cannot be empty")
		return
	if _abilities.has(ability_id):
		push_warning("AbilityManager: ability '%s' already registered" % [ability_id])
		return
	ability.setup(_controller, ability_id)
	_abilities[ability_id] = ability
	_registration_order.append(ability_id)
	ability_registered.emit(ability_id, ability)
	if verbose:
		print("[AbilityManager] Registered ability", ability_id)
	if auto_activate:
		activate_ability(ability_id)

func unregister_ability(ability_id: StringName) -> void:
	if not _abilities.has(ability_id):
		return
	deactivate_ability(ability_id)
	_abilities.erase(ability_id)
	_registration_order.erase(ability_id)
	ability_unregistered.emit(ability_id)
	if verbose:
		print("[AbilityManager] Unregistered ability", ability_id)

func activate_ability(ability_id: StringName) -> void:
	var ability: AbilityScript = _abilities.get(ability_id, null)
	if ability == null:
		return
	if _active_lookup.get(ability_id, false):
		return
	ability.activate()
	_active_lookup[ability_id] = true
	_active_ids.append(ability_id)
	ability_started.emit(ability_id)
	_publish_lifecycle(EventTopics.PLAYER_ABILITY_STARTED, ability_id, {})
	if verbose:
		print("[AbilityManager] Activated ability", ability_id)


func deactivate_ability(ability_id: StringName) -> void:
	if not _active_lookup.get(ability_id, false):
		return
	var ability: AbilityScript = _abilities.get(ability_id, null)
	if ability == null:
		return
	ability.deactivate()
	_active_lookup.erase(ability_id)
	_active_ids.erase(ability_id)
	if _motion_owner == ability_id:
		_motion_owner = StringName()
		_motion_velocity = Vector2.ZERO
	ability_ended.emit(ability_id)
	_publish_lifecycle(EventTopics.PLAYER_ABILITY_ENDED, ability_id, {})
	if verbose:
		print("[AbilityManager] Deactivated ability", ability_id)

func get_ability(ability_id: StringName) -> AbilityScript:
	return _abilities.get(ability_id, null)

func has_active_ability(ability_id: StringName) -> bool:
	return _active_lookup.get(ability_id, false)

func handle_input_action(action: StringName, edge: String, device: int, event: InputEvent) -> void:
	for ability_id in _registration_order:
		if not _active_lookup.get(ability_id, false):
			continue
		var ability: AbilityScript = _abilities[ability_id]
		ability.handle_input_action(action, edge, device, event)

func handle_input_axis(axis: StringName, value: float, device: int) -> void:
	for ability_id in _registration_order:
		if not _active_lookup.get(ability_id, false):
			continue
		var ability: AbilityScript = _abilities[ability_id]
		ability.handle_input_axis(axis, value, device)

func process_frame(delta: float) -> void:
	for ability_id in _registration_order:
		if not _active_lookup.get(ability_id, false):
			continue
		var ability: AbilityScript = _abilities[ability_id]
		ability.on_update(delta)
	_evaluate_motion_override()

func process_physics(delta: float) -> void:
	for ability_id in _registration_order:
		if not _active_lookup.get(ability_id, false):
			continue
		var ability: AbilityScript = _abilities[ability_id]
		ability.on_physics_update(delta)
	_evaluate_motion_override()

func motion_owner() -> StringName:
	return _motion_owner

func motion_velocity() -> Vector2:
	return _motion_velocity

func has_motion_override() -> bool:
	return _motion_owner != StringName()

func blocks_logic() -> bool:
	for ability_id in _registration_order:
		if not _active_lookup.get(ability_id, false):
			continue
		if _abilities[ability_id].blocks_state_kind(StringName("logic")):
			return true
	return false

func blocks_physics() -> bool:
	for ability_id in _registration_order:
		if not _active_lookup.get(ability_id, false):
			continue
		if _abilities[ability_id].blocks_state_kind(StringName("physics")):
			return true
	return false

func serialize_state() -> Dictionary:
	var data: Dictionary = {}
	for ability_id in _registration_order:
		var ability: AbilityScript = _abilities[ability_id]
		var key: String = String(ability_id)
		data[key] = {
			"active": ability.is_active(),
			"state": ability.serialize_state()
		}
	return data

func deserialize_state(data: Dictionary) -> void:
	for key in data.keys():
		var ability_id: StringName = StringName(key)
		var entry: Dictionary = data[key]
		var ability: AbilityScript = _abilities.get(ability_id, null)
		if ability == null:
			continue
		var should_activate: bool = entry.get("active", false)
		if should_activate:
			activate_ability(ability_id)
		else:
			deactivate_ability(ability_id)
		ability.deserialize_state(entry.get("state", {}))

func report_failure(ability_id: StringName, reason: String, details: Dictionary = {}) -> void:
	_failed_events.append({
		"ability_id": ability_id,
		"reason": reason,
		"details": details,
		"timestamp_ms": Time.get_ticks_msec()
	})
	ability_failed.emit(ability_id, reason)
	_publish_lifecycle(EventTopics.PLAYER_ABILITY_FAILED, ability_id, {
		StringName("reason"): reason,
		StringName("details"): details
	})
	if verbose:
		print("[AbilityManager] Ability", ability_id, "failed:", reason)

func get_failures() -> Array[Dictionary]:
	return _failed_events.duplicate()

func _evaluate_motion_override() -> void:
	var winner: StringName = StringName()
	var winner_priority: float = -INF
	var winner_velocity: Vector2 = Vector2.ZERO
	for ability_id in _registration_order:
		if not _active_lookup.get(ability_id, false):
			continue
		var ability: AbilityScript = _abilities[ability_id]
		if not ability.is_overriding_motion():
			continue
		var priority: float = ability.motion_priority()
		if priority > winner_priority or (priority == winner_priority and winner == StringName()):
			winner = ability_id
			winner_priority = priority
			winner_velocity = ability.motion_velocity()
	_motion_owner = winner
	_motion_velocity = winner_velocity
	if verbose and winner != StringName():
		print("[AbilityManager] Motion override ->", winner, winner_velocity)

func _auto_register_defaults() -> void:
	for key in default_abilities.keys():
		var ability_id: StringName = StringName(str(key))
		var entry = default_abilities[key]
		var script: Script = null
		if entry is Script:
			script = entry
		elif entry is String:
			script = load(entry) as Script
		if script == null:
			push_warning("AbilityManager: default ability '%s' could not load script" % [ability_id])
			continue
		var ability: AbilityScript = script.new() as AbilityScript
		var auto_activate: bool = auto_activate_ids.has(ability_id)
		register_ability(ability_id, ability, auto_activate)

func _publish_lifecycle(topic: StringName, ability_id: StringName, payload: Dictionary) -> void:
	if _event_bus == null or topic == StringName():
		return
	var data: Dictionary[StringName, Variant] = payload.duplicate(true) as Dictionary[StringName, Variant]
	data[StringName("ability_id")] = ability_id
	data[StringName("timestamp_ms")] = Time.get_ticks_msec()
	_event_bus.call_deferred("pub", topic, data)
