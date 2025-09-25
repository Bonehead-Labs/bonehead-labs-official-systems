class_name FSMState
extends RefCounted

## Base class for scriptable states.
## Override lifecycle hooks as needed.

var machine: StateMachine
var owner: Node
var context: Dictionary[StringName, Variant] = {}

func setup(state_machine: StateMachine, state_owner: Node, state_context: Dictionary[StringName, Variant]) -> void:
    machine = state_machine
    owner = state_owner
    context = state_context

func enter(_payload: Dictionary[StringName, Variant] = {}) -> void:
    pass

func exit(_payload: Dictionary[StringName, Variant] = {}) -> void:
    pass

func update(_delta: float) -> void:
    pass

func physics_update(_delta: float) -> void:
    pass

func handle_event(_event: StringName, _data: Variant = null) -> void:
    pass

func can_transition_to(_state: StringName) -> bool:
    return true

## Emit a state event (consolidated pattern)
func emit_event(event: StringName, data: Variant = null) -> void:
    if machine:
        machine.emit_state_event(event, data)

## Emit event and publish to EventBus (consolidated pattern)
func emit_event_with_bus(event: StringName, data: Dictionary = {}, bus_topic: StringName = StringName("")) -> void:
    # Emit to state machine
    emit_event(event, data)
    
    # Publish to EventBus if available and topic provided
    if not bus_topic.is_empty() and Engine.has_singleton("EventBus"):
        var event_bus := Engine.get_singleton("EventBus") as Object
        if event_bus and event_bus.has_method("pub"):
            event_bus.call("pub", bus_topic, data)

## Safe transition with validation (consolidated pattern)
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
    
    var result = machine.transition_to(state, payload)
    if result != OK:
        push_warning("FSMState: Transition to '%s' failed with error %s" % [state, result])
        return false
    
    return true

## Get context value with type safety (consolidated pattern)
func get_context_value(key: StringName, default_value: Variant = null, expected_type: int = TYPE_NIL) -> Variant:
    if not context.has(key):
        return default_value
    
    var value = context[key]
    if expected_type != TYPE_NIL and typeof(value) != expected_type:
        push_warning("FSMState: Context value '%s' has wrong type, expected %s, got %s" % [key, expected_type, typeof(value)])
        return default_value
    
    return value

## Validate required context keys (consolidated pattern)
func validate_context(required_keys: Array[StringName]) -> bool:
    var missing_keys: Array[StringName] = []
    
    for key in required_keys:
        if not context.has(key):
            missing_keys.append(key)
    
    if not missing_keys.is_empty():
        push_error("FSMState: Missing required context keys: %s" % missing_keys)
        return false
    
    return true

## Emit state entry event with common pattern
func emit_state_entered(state_name: StringName, payload: Dictionary[StringName, Variant] = {}) -> void:
    emit_event_with_bus(
        StringName("state_entered"),
        {
            StringName("state"): state_name,
            StringName("payload"): payload
        },
        StringName("")  # No EventBus topic for internal events
    )

## Emit state exit event with common pattern
func emit_state_exited(state_name: StringName, payload: Dictionary[StringName, Variant] = {}) -> void:
    emit_event_with_bus(
        StringName("state_exited"),
        {
            StringName("state"): state_name,
            StringName("payload"): payload
        },
        StringName("")  # No EventBus topic for internal events
    )
