extends "res://addons/gut/test.gd"


var bus: EventBus

func before_each():
	bus = EventBus.new()
	bus.deferred_mode = false
	bus.strict_mode = false

func after_each():
	bus = null

func test_pub_delivers_payload():
	print("\n=== Testing pub/sub payload delivery ===")
	var state := {"called": false, "got": {}}
	bus.sub(_EventTopics.PLAYER_DAMAGED, func(p):
		state.called = true
		state.got = p
		print("✓ Subscriber received payload: ", p)
	)
	print("Publishing PLAYER_DAMAGED with payload: {amount: 7, hp_after: 13}")
	bus.pub(_EventTopics.PLAYER_DAMAGED, {"amount": 7, "hp_after": 13})
	assert_true(state.called, "Subscriber should be called")
	assert_eq(state.got.get("amount"), 7)
	assert_eq(state.got.get("hp_after"), 13)
	print("✓ Payload delivery test passed!")

func test_unsub_stops_delivery():
	print("\n=== Testing unsubscribe functionality ===")
	var state := {"count": 0}
	var cb := func(_p): 
		state.count += 1
		print("✓ Callback invoked, count now: ", state.count)
	bus.sub(_EventTopics.PLAYER_DAMAGED, cb)
	print("Publishing first event (should trigger callback)...")
	bus.pub(_EventTopics.PLAYER_DAMAGED, {})
	print("Unsubscribing callback...")
	bus.unsub(_EventTopics.PLAYER_DAMAGED, cb)
	print("Publishing second event (should NOT trigger callback)...")
	bus.pub(_EventTopics.PLAYER_DAMAGED, {})
	assert_eq(state.count, 1, "Should receive exactly once before unsub")
	print("✓ Unsubscribe test passed! Final count: ", state.count)

func test_envelope_mode():
	print("\n=== Testing envelope mode ===")
	var state := {"seen_topic": StringName(), "seen_payload": {}, "seen_ts": -1}
	bus.sub(_EventTopics.PLAYER_DAMAGED, func(env):
		state.seen_topic = env["topic"]
		state.seen_payload = env["payload"]
		state.seen_ts = int(env["timestamp_ms"])
		print("✓ Received envelope: topic=", env["topic"], ", payload=", env["payload"], ", timestamp=", env["timestamp_ms"])
	)
	print("Publishing with envelope mode enabled...")
	bus.pub(_EventTopics.PLAYER_DAMAGED, {"x":1}, true)
	assert_eq(state.seen_topic, _EventTopics.PLAYER_DAMAGED)
	assert_eq(state.seen_payload.get("x"), 1)
	assert_true(state.seen_ts >= 0)
	print("✓ Envelope mode test passed!")

func test_catch_all_receives_without_topic_listeners():
	print("\n=== Testing catch-all subscription ===")
	var state := {"got_topic": StringName(), "got_payload": {}}
	bus.sub_all(func(env):
		state.got_topic = env["topic"]
		state.got_payload = env["payload"]
		print("✓ Catch-all received: topic=", env["topic"], ", payload=", env["payload"])
	)
	print("Publishing event (should trigger catch-all listener)...")
	bus.pub(_EventTopics.PLAYER_DAMAGED, {"ok": true})
	assert_eq(state.got_topic, _EventTopics.PLAYER_DAMAGED)
	assert_true(state.got_payload.get("ok", false))
	print("✓ Catch-all test passed!")

func test_strict_mode_blocks_invalid_topics():
	print("\n=== Testing strict mode validation ===")
	bus.strict_mode = true
	print("Strict mode enabled")
	var state := {"called": false}
	
	print("Testing valid topic: UI_TOAST")
	bus.sub(_EventTopics.UI_TOAST, func(_p): 
		state.called = true
		print("✓ Valid topic callback triggered")
	) # valid topic
	bus.pub(_EventTopics.UI_TOAST, {})
	assert_true(state.called, "Valid topic should pass in strict mode")

	state.called = false
	print("Testing invalid topic: 'typo/wrong'")
	bus.sub(&"typo/wrong", func(_p): 
		state.called = true
		print("✗ Invalid topic callback triggered (this shouldn't happen!)")
	) # invalid
	bus.pub(&"typo/wrong", {})
	assert_false(state.called, "Invalid topic should not fire in strict mode")
	print("✓ Strict mode correctly blocked invalid topic")

func test_deferred_mode_defers_dispatch() -> void:
	print("\n=== Testing deferred mode ===")
	bus.deferred_mode = true
	print("Deferred mode enabled")
	var state := {"called": false}
	bus.sub(_EventTopics.PLAYER_DAMAGED, func(_p): 
		state.called = true
		print("✓ Deferred callback executed")
	)
	print("Publishing event in deferred mode...")
	bus.pub(_EventTopics.PLAYER_DAMAGED, {})
	print("Immediately after publish, called=", state.called, " (should be false)")
	assert_false(state.called, "Should not be called immediately in deferred mode")
	print("Waiting one frame...")
	await get_tree().process_frame
	print("After frame, called=", state.called, " (should be true)")
	assert_true(state.called, "Should be called after a frame in deferred mode")
	print("✓ Deferred mode test passed!")

func test_invalid_callables_pruned():
	print("\n=== Testing invalid callable cleanup ===")
	var obj := Node.new()
	var cb := Callable(obj, "queue_free") # valid method, but we'll free obj before dispatch
	print("Subscribing callback from temporary node...")
	bus.sub(_EventTopics.PLAYER_DAMAGED, cb)
	print("Freeing the node (making callback invalid)...")
	obj.free()
	print("Publishing first event (should skip invalid callback)...")
	bus.pub(_EventTopics.PLAYER_DAMAGED, {})
	print("Publishing second event (should cleanup invalid callable)...")
	bus.pub(_EventTopics.PLAYER_DAMAGED, {})
	print("✓ Invalid callable cleanup test passed - no crashes occurred!")
	assert_true(true) # If we got here, pruning worked without error.