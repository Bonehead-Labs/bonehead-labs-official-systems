extends "res://addons/gut/test.gd"

## Test SaveService EventBus integration
## Verifies that SaveService publishes appropriate events to EventBus

var save_service: _SaveService
var event_bus: _EventBus
var mock_saveable: MockSaveable

class MockSaveable extends RefCounted:
	# Implements _ISaveable interface
	
	var save_id: String = "test_saveable"
	var save_priority: int = 10
	var saved_data: Dictionary = {}
	
	func save_data() -> Dictionary:
		return {"test_value": 42, "timestamp": Time.get_ticks_msec()}
	
	func load_data(data: Dictionary) -> bool:
		saved_data = data
		return true
	
	func get_save_id() -> String:
		return save_id
	
	func get_save_priority() -> int:
		return save_priority

func before_each() -> void:
	# Create mock EventBus
	event_bus = _EventBus.new()
	add_child(event_bus)
	
	# Create SaveService
	save_service = _SaveService.new()
	add_child(save_service)
	
	# Create mock saveable
	mock_saveable = MockSaveable.new()
	save_service.register_saveable(mock_saveable)
	
	# Set up profile
	save_service.set_profile("test_profile")

func after_each() -> void:
	if save_service:
		save_service.queue_free()
	if event_bus:
		event_bus.queue_free()
	if mock_saveable:
		mock_saveable = null

func test_save_game_publishes_events() -> void:
	"""Test that save_game publishes SAVE_REQUEST and SAVE_COMPLETED events."""
	# Clear any existing events
	event_bus._events.clear()
	
	# Perform save
	var result = save_service.save_game("test_save")
	
	# Verify save succeeded
	assert_true(result, "Save should succeed")
	
	# Check for SAVE_REQUEST event
	var save_request_events = event_bus._events.filter(
		func(e): return e.topic == EventTopics.SAVE_REQUEST
	)
	assert_eq(save_request_events.size(), 1, "Should publish one SAVE_REQUEST event")
	
	var request_event = save_request_events[0]
	assert_eq(request_event.payload["slot"], "test_save", "Request should have correct slot")
	assert_eq(request_event.payload["profile"], "test_profile", "Request should have correct profile")
	assert_eq(request_event.payload["reason"], "manual", "Request should have manual reason")
	
	# Check for SAVE_COMPLETED event
	var save_completed_events = event_bus._events.filter(
		func(e): return e.topic == EventTopics.SAVE_COMPLETED
	)
	assert_eq(save_completed_events.size(), 1, "Should publish one SAVE_COMPLETED event")
	
	var completed_event = save_completed_events[0]
	assert_eq(completed_event.payload["slot"], "test_save", "Completed should have correct slot")
	assert_eq(completed_event.payload["profile"], "test_profile", "Completed should have correct profile")
	assert_true(completed_event.payload["ok"], "Completed should indicate success")
	assert_eq(completed_event.payload["reason"], "manual", "Completed should have manual reason")

func test_load_game_publishes_events() -> void:
	"""Test that load_game publishes LOAD_REQUEST and LOAD_COMPLETED events."""
	# First create a save to load
	save_service.save_game("test_load")
	event_bus._events.clear()
	
	# Perform load
	var result = save_service.load_game("test_load")
	
	# Verify load succeeded
	assert_true(result, "Load should succeed")
	
	# Check for LOAD_REQUEST event
	var load_request_events = event_bus._events.filter(
		func(e): return e.topic == EventTopics.LOAD_REQUEST
	)
	assert_eq(load_request_events.size(), 1, "Should publish one LOAD_REQUEST event")
	
	var request_event = load_request_events[0]
	assert_eq(request_event.payload["slot"], "test_load", "Request should have correct slot")
	assert_eq(request_event.payload["profile"], "test_profile", "Request should have correct profile")
	assert_eq(request_event.payload["reason"], "manual", "Request should have manual reason")
	
	# Check for LOAD_COMPLETED event
	var load_completed_events = event_bus._events.filter(
		func(e): return e.topic == EventTopics.LOAD_COMPLETED
	)
	assert_eq(load_completed_events.size(), 1, "Should publish one LOAD_COMPLETED event")
	
	var completed_event = load_completed_events[0]
	assert_eq(completed_event.payload["slot"], "test_load", "Completed should have correct slot")
	assert_eq(completed_event.payload["profile"], "test_profile", "Completed should have correct profile")
	assert_true(completed_event.payload["ok"], "Completed should indicate success")
	assert_eq(completed_event.payload["reason"], "manual", "Completed should have manual reason")

func test_checkpoint_creation_publishes_events() -> void:
	"""Test that create_checkpoint publishes SAVE_REQUEST and SAVE_COMPLETED events."""
	# Clear any existing events
	event_bus._events.clear()
	
	# Create checkpoint
	var result = save_service.create_checkpoint("test_checkpoint")
	
	# Verify checkpoint creation succeeded
	assert_true(result, "Checkpoint creation should succeed")
	
	# Check for SAVE_REQUEST event
	var save_request_events = event_bus._events.filter(
		func(e): return e.topic == EventTopics.SAVE_REQUEST
	)
	assert_eq(save_request_events.size(), 1, "Should publish one SAVE_REQUEST event")
	
	var request_event = save_request_events[0]
	assert_eq(request_event.payload["slot"], "test_checkpoint", "Request should have correct slot")
	assert_eq(request_event.payload["profile"], "test_profile", "Request should have correct profile")
	assert_eq(request_event.payload["reason"], "checkpoint", "Request should have checkpoint reason")
	
	# Check for SAVE_COMPLETED event
	var save_completed_events = event_bus._events.filter(
		func(e): return e.topic == EventTopics.SAVE_COMPLETED
	)
	assert_eq(save_completed_events.size(), 1, "Should publish one SAVE_COMPLETED event")
	
	var completed_event = save_completed_events[0]
	assert_eq(completed_event.payload["slot"], "test_checkpoint", "Completed should have correct slot")
	assert_eq(completed_event.payload["profile"], "test_profile", "Completed should have correct profile")
	assert_true(completed_event.payload["ok"], "Completed should indicate success")
	assert_eq(completed_event.payload["reason"], "checkpoint", "Completed should have checkpoint reason")

func test_auto_save_publishes_events() -> void:
	"""Test that auto-save publishes events through save_game."""
	# Enable auto-save
	save_service.enable_auto_save(true)
	save_service.set_auto_save_interval(0.1)  # Very short interval for testing
	
	# Clear any existing events
	event_bus._events.clear()
	
	# Wait for auto-save to trigger
	await get_tree().create_timer(0.2).timeout
	
	# Check for SAVE_REQUEST event
	var save_request_events = event_bus._events.filter(
		func(e): return e.topic == EventTopics.SAVE_REQUEST
	)
	assert_true(save_request_events.size() >= 1, "Should publish at least one SAVE_REQUEST event from auto-save")
	
	# Check for SAVE_COMPLETED event
	var save_completed_events = event_bus._events.filter(
		func(e): return e.topic == EventTopics.SAVE_COMPLETED
	)
	assert_true(save_completed_events.size() >= 1, "Should publish at least one SAVE_COMPLETED event from auto-save")
	
	# Disable auto-save
	save_service.enable_auto_save(false)

func test_event_payload_structure() -> void:
	"""Test that event payloads have the correct structure."""
	# Perform save
	save_service.save_game("payload_test")
	
	# Find the SAVE_REQUEST event
	var save_request_events = event_bus._events.filter(
		func(e): return e.topic == EventTopics.SAVE_REQUEST
	)
	assert_gt(save_request_events.size(), 0, "Should have SAVE_REQUEST event")
	
	var request_event = save_request_events[0]
	var payload = request_event.payload
	
	# Verify required fields
	assert_true(payload.has("slot"), "Payload should have 'slot' field")
	assert_true(payload.has("profile"), "Payload should have 'profile' field")
	assert_true(payload.has("reason"), "Payload should have 'reason' field")
	
	# Verify field types
	assert_true(payload["slot"] is String, "'slot' should be String")
	assert_true(payload["profile"] is String, "'profile' should be String")
	assert_true(payload["reason"] is String, "'reason' should be String")

func test_no_events_when_eventbus_unavailable() -> void:
	"""Test that SaveService works without EventBus without crashing."""
	# Remove EventBus singleton
	remove_child(event_bus)
	event_bus.queue_free()
	event_bus = null
	
	# Perform save - should not crash
	var result = save_service.save_game("no_eventbus_test")
	assert_true(result, "Save should succeed even without EventBus")
	
	# Perform load - should not crash
	var load_result = save_service.load_game("no_eventbus_test")
	assert_true(load_result, "Load should succeed even without EventBus")
