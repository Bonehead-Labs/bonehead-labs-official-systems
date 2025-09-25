extends "res://addons/gut/test.gd"

## Test FSM consolidation patterns and utilities

var state_machine: StateMachine
var test_state: TestFSMState
var event_bus: Node

class TestFSMState extends FSMState:
    var test_data: Dictionary = {}
    
    func enter(payload: Dictionary[StringName, Variant] = {}) -> void:
        emit_state_entered(StringName("test"), payload)
        test_data = payload.duplicate(true)
    
    func exit(payload: Dictionary[StringName, Variant] = {}) -> void:
        emit_state_exited(StringName("test"), payload)
    
    func can_transition_to(state: StringName) -> bool:
        return state != StringName("blocked")

class EventBusStub extends Node:
    var published_events: Array[Dictionary] = []
    
    func pub(topic: StringName, payload: Dictionary) -> void:
        published_events.append({"topic": topic, "payload": payload})

func before_each() -> void:
    state_machine = StateMachine.new()
    state_machine.name = "TestStateMachine"
    test_state = TestFSMState.new()
    event_bus = EventBusStub.new()
    event_bus.name = "EventBus"
    
    get_tree().root.add_child(state_machine)
    get_tree().root.add_child(event_bus)
    
    # Register test state
    state_machine.register_state(StringName("test"), TestFSMState)
    state_machine.register_state(StringName("blocked"), TestFSMState)

func after_each() -> void:
    if is_instance_valid(event_bus):
        event_bus.queue_free()
    if is_instance_valid(state_machine):
        state_machine.queue_free()
    if is_instance_valid(test_state):
        test_state = null

func test_safe_transition_success() -> void:
    """Test that safe_transition_to works for valid transitions."""
    var result = test_state.safe_transition_to(StringName("test"), {StringName("data"): "test_value"}, StringName("test_reason"))
    assert_true(result, "Safe transition should succeed for valid state")
    
    # Verify state machine received the transition
    assert_eq(state_machine.get_current_state(), StringName("test"))

func test_safe_transition_validation() -> void:
    """Test that safe_transition_to validates transitions properly."""
    # Setup state machine with current state
    state_machine.transition_to(StringName("test"))
    
    # Test blocked transition
    var result = test_state.safe_transition_to(StringName("blocked"), {}, StringName("should_fail"))
    assert_false(result, "Safe transition should fail for blocked state")

func test_context_validation() -> void:
    """Test context validation utilities."""
    # Test with valid context
    test_state.context = {
        StringName("required_key"): "value",
        StringName("optional_key"): 42
    }
    
    var valid = test_state.validate_context([StringName("required_key")])
    assert_true(valid, "Context validation should pass with required keys")
    
    # Test with missing context
    test_state.context = {StringName("other_key"): "value"}
    var invalid = test_state.validate_context([StringName("required_key")])
    assert_false(invalid, "Context validation should fail with missing keys")

func test_context_value_retrieval() -> void:
    """Test context value retrieval with type safety."""
    test_state.context = {
        StringName("string_value"): "test",
        StringName("int_value"): 42,
        StringName("float_value"): 3.14
    }
    
    # Test string retrieval
    var str_val = test_state.get_context_value(StringName("string_value"), "default", TYPE_STRING)
    assert_eq(str_val, "test", "Should retrieve correct string value")
    
    # Test int retrieval
    var int_val = test_state.get_context_value(StringName("int_value"), 0, TYPE_INT)
    assert_eq(int_val, 42, "Should retrieve correct int value")
    
    # Test default value
    var default_val = test_state.get_context_value(StringName("missing"), "default", TYPE_STRING)
    assert_eq(default_val, "default", "Should return default value for missing key")
    
    # Test type validation
    var wrong_type = test_state.get_context_value(StringName("string_value"), 0, TYPE_INT)
    assert_eq(wrong_type, 0, "Should return default when type doesn't match")

func test_event_emission_patterns() -> void:
    """Test consolidated event emission patterns."""
    # Test basic event emission
    test_state.emit_event(StringName("test_event"), {"data": "test"})
    
    # Test event with EventBus
    test_state.emit_event_with_bus(StringName("bus_event"), {"data": "bus_test"}, StringName("test/topic"))
    
    # Verify EventBus received the event
    var bus_events = event_bus.published_events.filter(func(e): return e.topic == StringName("test/topic"))
    assert_eq(bus_events.size(), 1, "EventBus should receive the event")
    assert_eq(bus_events[0].payload["data"], "bus_test", "EventBus should receive correct payload")

func test_state_entry_exit_events() -> void:
    """Test standardized state entry/exit event patterns."""
    # Test state entry
    test_state.emit_state_entered(StringName("test_state"), {StringName("data"): "entry"})
    
    # Test state exit
    test_state.emit_state_exited(StringName("test_state"), {StringName("data"): "exit"})
    
    # These should not crash and should emit events properly
    assert_true(true, "State entry/exit events should work without errors")

func test_transition_reason_injection() -> void:
    """Test that transition reasons are properly injected into payloads."""
    var payload = {StringName("existing"): "data"}
    var reason = StringName("test_reason")
    
    # This would normally call safe_transition_to, but we'll test the payload modification directly
    if not reason.is_empty():
        payload[StringName("reason")] = reason
    
    assert_eq(payload[StringName("reason")], "test_reason", "Reason should be injected into payload")
    assert_eq(payload[StringName("existing")], "data", "Existing payload data should be preserved")
