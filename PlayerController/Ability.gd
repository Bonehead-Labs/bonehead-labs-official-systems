class_name PlayerAbility
extends RefCounted

## Base class for player abilities that can be registered with the FSM.
## Abilities can hook into state changes, input events, and provide custom behavior.

const EventTopics = preload("res://EventBus/EventTopics.gd")

var _controller: Node = null
var _ability_id: StringName = StringName()
var _is_active: bool = false

## Called when the ability is registered with a controller.
func setup(controller: Node, ability_id: StringName) -> void:
	_controller = controller
	_ability_id = ability_id

## Called when the ability is activated.
func activate() -> void:
	_is_active = true
	_on_activated()

## Called when the ability is deactivated.
func deactivate() -> void:
	_is_active = false
	_on_deactivated()

## Returns whether this ability is currently active.
func is_active() -> bool:
	return _is_active

## Called by FSM when a state transition occurs.
## Return true to allow the transition, false to block it.
func can_transition_to_state(_state_id: StringName, _payload: Dictionary[StringName, Variant] = {}) -> bool:
	return true

## Called by FSM during state updates.
func update_state(delta: float) -> void:
	if _is_active:
		_on_update(delta)

## Called by FSM when handling state events.
func handle_state_event(event: StringName, data: Variant) -> void:
	if _is_active:
		_on_state_event(event, data)

## Called by controller when input actions occur.
func handle_input_action(action: StringName, edge: String, device: int, event: InputEvent) -> void:
	if _is_active:
		_on_input_action(action, edge, device, event)

## Called by controller when axis input occurs.
func handle_input_axis(axis: StringName, value: float, device: int) -> void:
	if _is_active:
		_on_input_axis(axis, value, device)

## Override these methods in derived classes:

func _on_activated() -> void:
	pass

func _on_deactivated() -> void:
	pass

func _on_update(_delta: float) -> void:
	pass

func _on_state_event(_event: StringName, _data: Variant) -> void:
	pass

func _on_input_action(_action: StringName, _edge: String, _device: int, _event: InputEvent) -> void:
	pass

func _on_input_axis(_axis: StringName, _value: float, _device: int) -> void:
	pass

## Utility methods for derived classes:

func get_controller() -> Node:
	return _controller

func get_ability_id() -> StringName:
	return _ability_id

func emit_ability_event(event: StringName, data: Variant = null) -> void:
	if _controller:
		_controller.state_event.emit(StringName("ability_" + _ability_id + "_" + event), data)

func _emit_analytics_event(topic: StringName, payload: Dictionary[StringName, Variant]) -> void:
	if Engine.has_singleton("EventBus"):
		payload[StringName("ability_id")] = _ability_id
		payload[StringName("timestamp_ms")] = Time.get_ticks_msec()
		if _controller:
			payload[StringName("player_position")] = _controller.global_position
		Engine.get_singleton("EventBus").call("pub", topic, payload)
