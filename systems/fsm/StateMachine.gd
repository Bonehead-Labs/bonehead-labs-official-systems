class_name StateMachine
extends Node

## Script-based finite state machine.

signal state_entered(state: StringName)
signal state_exited(state: StringName)
signal state_changed(previous: StringName, current: StringName)
signal state_event(event: StringName, data: Variant)

@export var initial_state: StringName
@export var state_scripts: Dictionary[StringName, Script] = {}

var _current_state: StringName = StringName()
var _current_instance: FSMState
var _states: Dictionary[StringName, Script] = {}
var _context: Dictionary[StringName, Variant] = {}

func _ready() -> void:
    _states = state_scripts.duplicate(true)
    if initial_state != StringName():
        transition_to(initial_state)

func transition_to(state: StringName, payload: Dictionary[StringName, Variant] = {}) -> Error:
    if not _states.has(state):
        return ERR_DOES_NOT_EXIST
    if _current_instance and not _current_instance.can_transition_to(state):
        return ERR_INVALID_STATE
    var previous := _current_state
    if _current_instance:
        _current_instance.exit(payload)
        state_exited.emit(previous)
    _current_state = state
    _current_instance = _instantiate_state(state)
    if _current_instance == null:
        return ERR_CANT_CREATE
    _current_instance.enter(payload)
    state_entered.emit(state)
    state_changed.emit(previous, state)
    return OK

func update_state(delta: float) -> void:
    if _current_instance:
        _current_instance.update(delta)

func physics_update_state(delta: float) -> void:
    if _current_instance:
        _current_instance.physics_update(delta)

func emit_state_event(event: StringName, data: Variant = null) -> void:
    state_event.emit(event, data)

func handle_event(event: StringName, data: Variant = null) -> void:
    if _current_instance:
        _current_instance.handle_event(event, data)

func set_context(context: Dictionary[StringName, Variant]) -> void:
    _context = context.duplicate(true)

func get_context() -> Dictionary[StringName, Variant]:
    return _context.duplicate(true)

func _instantiate_state(state: StringName) -> FSMState:
    var resource := _states[state]
    var instance: FSMState = null
    if resource is Script:
        instance = resource.new()
    elif resource is PackedScene:
        var scene_node := (resource as PackedScene).instantiate()
        if scene_node is FSMState:
            instance = scene_node
    if instance == null:
        push_error("StateMachine: state %s is not FSMState" % state)
        return null
    var ctx := _context.duplicate(true) as Dictionary[StringName, Variant]
    instance.setup(self, get_parent(), ctx)
    return instance

func get_current_state() -> StringName:
    return _current_state

func has_state(state: StringName) -> bool:
    return _states.has(state)

func register_state(id: StringName, script: Script) -> void:
    _states[id] = script

func unregister_state(id: StringName) -> void:
    _states.erase(id)
    if _current_state == id:
        if _current_instance:
            _current_instance.exit({})
        _current_state = StringName()
        _current_instance = null
