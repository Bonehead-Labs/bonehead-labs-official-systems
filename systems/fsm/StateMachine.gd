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

## Transition to a different state
## 
## Changes the current state to the specified state, calling
## exit on the current state and enter on the new state.
## 
## [b]state:[/b] Name of the state to transition to
## [b]payload:[/b] Data to pass to both exit and enter methods
## 
## [b]Returns:[/b] OK if successful, error code if failed
## 
## [b]Usage:[/b]
## [codeblock]
## # Transition to jump state
## var result = state_machine.transition_to("jump", {"force": 10.0})
## if result != OK:
##     print("Transition failed: ", result)
## [/codeblock]
func transition_to(state: StringName, payload: Dictionary[StringName, Variant] = {}) -> Error:
    if not _states.has(state):
        return ERR_DOES_NOT_EXIST
        
    if _current_instance and not _current_instance.can_transition_to(state):
        return ERR_INVALID_PARAMETER
        
    var previous: StringName = _current_state
    
    # Exit current state
    if _current_instance:
        _current_instance.exit(payload)
        state_exited.emit(previous)
    
    # Transition to new state
    _current_state = state
    _current_instance = _instantiate_state(state)
    if _current_instance == null:
        return ERR_CANT_CREATE
        
    # Enter new state
    _current_instance.enter(payload)
    state_entered.emit(state)
    state_changed.emit(previous, state)
    return OK

## Update the current state
## 
## Calls the update method on the current state instance.
## Should be called from _process() or similar.
## 
## [b]delta:[/b] Time elapsed since last frame
## 
## [b]Usage:[/b]
## [codeblock]
## # In _process()
## func _process(delta: float) -> void:
##     state_machine.update_state(delta)
## [/codeblock]
func update_state(delta: float) -> void:
    if _current_instance:
        _current_instance.update(delta)

## Physics update the current state
## 
## Calls the physics_update method on the current state instance.
## Should be called from _physics_process() or similar.
## 
## [b]delta:[/b] Time elapsed since last physics frame
## 
## [b]Usage:[/b]
## [codeblock]
## # In _physics_process()
## func _physics_process(delta: float) -> void:
##     state_machine.physics_update_state(delta)
## [/codeblock]
func physics_update_state(delta: float) -> void:
    if _current_instance:
        _current_instance.physics_update(delta)

## Emit a state event
## 
## Emits a state event signal for external listeners.
## 
## [b]event:[/b] Event name/identifier
## [b]data:[/b] Optional event data
## 
## [b]Usage:[/b]
## [codeblock]
## # Emit custom event
## state_machine.emit_state_event("animation_finished", {"anim": "walk"})
## [/codeblock]
func emit_state_event(event: StringName, data: Variant = null) -> void:
    state_event.emit(event, data)

## Handle an event by forwarding to current state
## 
## Forwards an event to the current state for processing.
## 
## [b]event:[/b] Event name/identifier
## [b]data:[/b] Optional event data
## 
## [b]Usage:[/b]
## [codeblock]
## # Handle input event
## state_machine.handle_event("jump_pressed")
## [/codeblock]
func handle_event(event: StringName, data: Variant = null) -> void:
    if _current_instance:
        _current_instance.handle_event(event, data)

## Set the shared context for all states
## 
## Updates the shared context data that is passed to all states.
## The context is deep copied to prevent external modification.
## 
## [b]context:[/b] Dictionary containing shared context data
## 
## [b]Usage:[/b]
## [codeblock]
## # Set shared context
## var context = {"player": player_node, "config": movement_config}
## state_machine.set_context(context)
## [/codeblock]
func set_context(context: Dictionary[StringName, Variant]) -> void:
    _context = context.duplicate(true)

## Get a copy of the shared context
## 
## Returns a deep copy of the current shared context data.
## 
## [b]Returns:[/b] Copy of the shared context dictionary
## 
## [b]Usage:[/b]
## [codeblock]
## # Get current context
## var context = state_machine.get_context()
## var player = context.get("player")
## [/codeblock]
func get_context() -> Dictionary[StringName, Variant]:
    return _context.duplicate(true)

## Instantiate a state from its resource
## 
## Creates a new instance of a state from its registered resource.
## Supports both Script and PackedScene resources.
## 
## [b]state:[/b] State name to instantiate
## 
## [b]Returns:[/b] New FSMState instance or null if instantiation fails
func _instantiate_state(state: StringName) -> FSMState:
    var resource: Variant = _states[state]
    var instance: FSMState = null
    
    if resource is Script:
        var script_instance: Variant = (resource as Script).new()
        if script_instance is FSMState:
            instance = script_instance as FSMState
    elif resource is PackedScene:
        var scene_node: Variant = (resource as PackedScene).instantiate()
        if scene_node is FSMState:
            instance = scene_node as FSMState
            
    if instance == null:
        push_error("StateMachine: state %s is not FSMState" % state)
        return null
        
    var ctx: Dictionary[StringName, Variant] = _context.duplicate(true) as Dictionary[StringName, Variant]
    instance.setup(self, get_parent(), ctx)
    return instance

## Get the current state name
## 
## [b]Returns:[/b] Name of the currently active state
## 
## [b]Usage:[/b]
## [codeblock]
## # Check current state
## var current = state_machine.get_current_state()
## if current == "idle":
##     # Handle idle state logic
## [/codeblock]
func get_current_state() -> StringName:
    return _current_state

## Check if a state is registered
## 
## [b]state:[/b] State name to check
## 
## [b]Returns:[/b] true if state is registered, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## # Check if state exists
## if state_machine.has_state("jump"):
##     state_machine.transition_to("jump")
## [/codeblock]
func has_state(state: StringName) -> bool:
    return _states.has(state)

## Register a state with the state machine
## 
## Adds a new state to the state machine registry.
## The resource can be a Script or PackedScene.
## 
## [b]id:[/b] Unique identifier for the state
## [b]resource:[/b] Script or PackedScene containing the state logic
## 
## [b]Usage:[/b]
## [codeblock]
## # Register a script state
## var jump_script = preload("res://states/JumpState.gd")
## state_machine.register_state("jump", jump_script)
## 
## # Register a scene state
## var idle_scene = preload("res://states/IdleState.tscn")
## state_machine.register_state("idle", idle_scene)
## [/codeblock]
func register_state(id: StringName, resource: Resource) -> void:
    _states[id] = resource

## Unregister a state from the state machine
## 
## Removes a state from the registry. If the state is currently
## active, it will be exited and the state machine will be reset.
## 
## [b]id:[/b] State identifier to remove
## 
## [b]Usage:[/b]
## [codeblock]
## # Remove a state
## state_machine.unregister_state("old_state")
## [/codeblock]
func unregister_state(id: StringName) -> void:
    _states.erase(id)
    if _current_state == id:
        if _current_instance:
            _current_instance.exit({})
        _current_state = StringName()
        _current_instance = null
