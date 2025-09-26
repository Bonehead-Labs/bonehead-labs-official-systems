class_name FSMState
extends RefCounted

## Base class for scriptable states.
## Override lifecycle hooks as needed.

var machine: StateMachine
var owner: Node
var context: Dictionary[StringName, Variant] = {}

## Initialize the state with machine, owner, and context
## 
## Sets up the state with references to the state machine,
## owner node, and shared context data.
## 
## [b]state_machine:[/b] The StateMachine instance managing this state
## [b]state_owner:[/b] The Node that owns this state
## [b]state_context:[/b] Shared context data dictionary
## 
## [b]Usage:[/b]
## [codeblock]
## # Called automatically by StateMachine
## state.setup(machine, player_node, context_data)
## [/codeblock]
func setup(state_machine: StateMachine, state_owner: Node, state_context: Dictionary[StringName, Variant]) -> void:
    machine = state_machine
    owner = state_owner
    context = state_context

## Called when entering this state
## 
## Override this method to implement state entry logic.
## Called once when transitioning to this state.
## 
## [b]_payload:[/b] Optional data passed during transition
## 
## [b]Usage:[/b]
## [codeblock]
## func enter(payload: Dictionary[StringName, Variant] = {}) -> void:
##     # Initialize state-specific resources
##     # Set up animations, timers, etc.
##     emit_state_entered("idle", payload)
## [/codeblock]
func enter(_payload: Dictionary[StringName, Variant] = {}) -> void:
    pass

## Called when exiting this state
## 
## Override this method to implement state exit logic.
## Called once when transitioning away from this state.
## 
## [b]_payload:[/b] Optional data passed during transition
## 
## [b]Usage:[/b]
## [codeblock]
## func exit(payload: Dictionary[StringName, Variant] = {}) -> void:
##     # Clean up state-specific resources
##     # Stop animations, clear timers, etc.
##     emit_state_exited("idle", payload)
## [/codeblock]
func exit(_payload: Dictionary[StringName, Variant] = {}) -> void:
    pass

## Called every frame while this state is active
## 
## Override this method to implement per-frame update logic.
## Called every frame in _process() when this state is active.
## 
## [b]_delta:[/b] Time elapsed since last frame
## 
## [b]Usage:[/b]
## [codeblock]
## func update(delta: float) -> void:
##     # Update timers, animations, etc.
##     # Check for transition conditions
## [/codeblock]
func update(_delta: float) -> void:
    pass

## Called every physics frame while this state is active
## 
## Override this method to implement physics update logic.
## Called every frame in _physics_process() when this state is active.
## 
## [b]_delta:[/b] Time elapsed since last physics frame
## 
## [b]Usage:[/b]
## [codeblock]
## func physics_update(delta: float) -> void:
##     # Update physics, movement, collisions
##     # Apply forces, check ground, etc.
## [/codeblock]
func physics_update(_delta: float) -> void:
    pass

## Handle custom events sent to this state
## 
## Override this method to implement event handling logic.
## Called when events are sent to the state machine.
## 
## [b]_event:[/b] Event name/identifier
## [b]_data:[/b] Optional event data
## 
## [b]Usage:[/b]
## [codeblock]
## func handle_event(event: StringName, data: Variant = null) -> void:
##     match event:
##         "jump_requested":
##             if can_jump():
##                 safe_transition_to("jump")
## [/codeblock]
func handle_event(_event: StringName, _data: Variant = null) -> void:
    pass

## Check if transition to another state is allowed
## 
## Override this method to implement transition validation logic.
## Called before attempting any state transition.
## 
## [b]_state:[/b] Target state name
## 
## [b]Returns:[/b] true if transition is allowed, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## func can_transition_to(state: StringName) -> bool:
##     match state:
##         "jump":
##             return is_on_floor()
##         "attack":
##             return not is_attacking
##     return true
## [/codeblock]
func can_transition_to(_state: StringName) -> bool:
    return true

## Emit a state event to the state machine
## 
## Sends an event to the state machine for processing.
## This is the primary way for states to communicate.
## 
## [b]event:[/b] Event name/identifier
## [b]data:[/b] Optional event data
## 
## [b]Usage:[/b]
## [codeblock]
## # Emit a custom event
## emit_event("animation_finished", {"animation": "walk"})
## [/codeblock]
func emit_event(event: StringName, data: Variant = null) -> void:
    if machine:
        machine.emit_state_event(event, data)

## Emit event to state machine and optionally publish to EventBus
## 
## Sends an event to the state machine and optionally publishes
## it to the EventBus for decoupled communication.
## 
## [b]event:[/b] Event name/identifier
## [b]data:[/b] Event data dictionary
## [b]bus_topic:[/b] EventBus topic to publish to (optional)
## 
## [b]Usage:[/b]
## [codeblock]
## # Emit to state machine and EventBus
## emit_event_with_bus("player_died", {"reason": "fall"}, "player/death")
## [/codeblock]
func emit_event_with_bus(event: StringName, data: Dictionary = {}, bus_topic: StringName = StringName("")) -> void:
    # Emit to state machine
    emit_event(event, data)
    
    # Publish to EventBus if available and topic provided
    if not bus_topic.is_empty() and Engine.has_singleton("EventBus"):
        var event_bus: Object = Engine.get_singleton("EventBus") as Object
        if event_bus and event_bus.has_method("pub"):
            event_bus.call("pub", bus_topic, data)

## Safely transition to another state with validation
## 
## Attempts to transition to another state with proper validation
## and error handling. Includes transition reason in payload.
## 
## [b]state:[/b] Target state name
## [b]payload:[/b] Data to pass to the target state
## [b]reason:[/b] Reason for the transition (optional)
## 
## [b]Returns:[/b] true if transition succeeded, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## # Safe transition with reason
## if safe_transition_to("jump", {}, "input_detected"):
##     print("Successfully transitioned to jump state")
## [/codeblock]
func safe_transition_to(state: StringName, payload: Dictionary[StringName, Variant] = {}, reason: StringName = StringName("")) -> bool:
    if not machine:
        push_warning("FSMState: No state machine available for transition")
        return false
    
    if not can_transition_to(state):
        push_warning("FSMState: Transition to '%s' not allowed from current state" % state)
        return false
    
    # Add reason to payload if provided
    if not reason.is_empty():
        payload[StringName("reason")] = reason
    
    var result: Error = machine.transition_to(state, payload)
    if result != OK:
        push_warning("FSMState: Transition to '%s' failed with error %s" % [state, result])
        return false
    
    return true

## Get a context value with type safety
## 
## Retrieves a value from the shared context with optional
## type checking and default value fallback.
## 
## [b]key:[/b] Context key to retrieve
## [b]default_value:[/b] Value to return if key not found
## [b]expected_type:[/b] Expected type for validation (optional)
## 
## [b]Returns:[/b] Context value or default if not found/invalid type
## 
## [b]Usage:[/b]
## [codeblock]
## # Get typed context value
## var player = get_context_value("player", null, TYPE_OBJECT)
## var speed = get_context_value("speed", 100.0, TYPE_FLOAT)
## [/codeblock]
func get_context_value(key: StringName, default_value: Variant = null, expected_type: int = TYPE_NIL) -> Variant:
    if not context.has(key):
        return default_value
    
    var value: Variant = context[key]
    if expected_type != TYPE_NIL and typeof(value) != expected_type:
        push_warning("FSMState: Context value '%s' has wrong type, expected %s, got %s" % [key, expected_type, typeof(value)])
        return default_value
    
    return value

## Validate that required context keys are present
## 
## Checks that all required context keys exist and reports
## any missing keys as errors.
## 
## [b]required_keys:[/b] Array of context keys that must be present
## 
## [b]Returns:[/b] true if all keys present, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## # Validate required context
## var required = ["player", "movement_config"]
## if not validate_context(required):
##     return
## [/codeblock]
func validate_context(required_keys: Array[StringName]) -> bool:
    var missing_keys: Array[StringName] = []
    
    for key in required_keys:
        if not context.has(key):
            missing_keys.append(key)
    
    if not missing_keys.is_empty():
        push_error("FSMState: Missing required context keys: %s" % missing_keys)
        return false
    
    return true

## Emit state entry event
## 
## Emits a standardized state entry event with state name
## and payload data for debugging and monitoring.
## 
## [b]state_name:[/b] Name of the state being entered
## [b]payload:[/b] Optional payload data
## 
## [b]Usage:[/b]
## [codeblock]
## # Emit entry event
## emit_state_entered("idle", {"reason": "input_stopped"})
## [/codeblock]
func emit_state_entered(state_name: StringName, payload: Dictionary[StringName, Variant] = {}) -> void:
    emit_event_with_bus(
        StringName("state_entered"),
        {
            StringName("state"): state_name,
            StringName("payload"): payload
        },
        StringName("")  # No EventBus topic for internal events
    )

## Emit state exit event
## 
## Emits a standardized state exit event with state name
## and payload data for debugging and monitoring.
## 
## [b]state_name:[/b] Name of the state being exited
## [b]payload:[/b] Optional payload data
## 
## [b]Usage:[/b]
## [codeblock]
## # Emit exit event
## emit_state_exited("idle", {"reason": "input_detected"})
## [/codeblock]
func emit_state_exited(state_name: StringName, payload: Dictionary[StringName, Variant] = {}) -> void:
    emit_event_with_bus(
        StringName("state_exited"),
        {
            StringName("state"): state_name,
            StringName("payload"): payload
        },
        StringName("")  # No EventBus topic for internal events
    )
