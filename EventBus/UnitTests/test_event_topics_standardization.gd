extends "res://addons/gut/test.gd"

## Test EventBus topic standardization
## Verifies that all hardcoded event topics are properly defined in EventTopics.gd

func test_all_hardcoded_topics_are_defined() -> void:
	"""Test that all hardcoded event topics found in the codebase are defined in EventTopics.gd."""
	
	# List of hardcoded topics found in the codebase
	var hardcoded_topics := [
		"debug/crash_detected",
		"debug/warning", 
		"debug/error",
		"world/portal_used",
		"world/time_paused",
		"world/time_resumed", 
		"world/time_scale_changed",
		"world/prop_damaged",
		"world/prop_destroyed",
		"world/prop_respawned",
		"world/hazard_entered",
		"world/hazard_exited",
		"world/hazard_damage",
		"world/level_load_started",
		"world/level_load_failed",
		"world/level_load_success",
		"world/level_push_started",
		"world/level_push_failed",
		"world/level_push_success",
		"world/level_pop_started",
		"world/level_pop_failed",
		"world/level_pop_success",
		"world/checkpoint_registered",
		"world/checkpoint_activated",
		"world/interacted",
		"item/picked_up",
		"shop/purchased",
		"enemy/spawned_from_spawner",
		"enemy/attack_start",
		"enemy/attack_end"
	]
	
	# Check that all hardcoded topics are defined in EventTopics
	for topic_string in hardcoded_topics:
		var topic = StringName(topic_string)
		assert_true(EventTopics.is_valid(topic), "Topic '%s' should be defined in EventTopics.gd" % topic_string)

func test_event_topics_constants_exist() -> void:
	"""Test that all EventTopics constants are properly defined."""
	
	# Test debug topics
	assert_not_null(EventTopics.DEBUG_CRASH_DETECTED, "DEBUG_CRASH_DETECTED should be defined")
	assert_not_null(EventTopics.DEBUG_WARNING, "DEBUG_WARNING should be defined")
	assert_not_null(EventTopics.DEBUG_ERROR, "DEBUG_ERROR should be defined")
	
	# Test world topics
	assert_not_null(EventTopics.WORLD_PORTAL_USED, "WORLD_PORTAL_USED should be defined")
	assert_not_null(EventTopics.WORLD_TIME_PAUSED, "WORLD_TIME_PAUSED should be defined")
	assert_not_null(EventTopics.WORLD_TIME_RESUMED, "WORLD_TIME_RESUMED should be defined")
	assert_not_null(EventTopics.WORLD_TIME_SCALE_CHANGED, "WORLD_TIME_SCALE_CHANGED should be defined")
	assert_not_null(EventTopics.WORLD_PROP_DAMAGED, "WORLD_PROP_DAMAGED should be defined")
	assert_not_null(EventTopics.WORLD_PROP_DESTROYED, "WORLD_PROP_DESTROYED should be defined")
	assert_not_null(EventTopics.WORLD_PROP_RESPAWNED, "WORLD_PROP_RESPAWNED should be defined")
	assert_not_null(EventTopics.WORLD_HAZARD_ENTERED, "WORLD_HAZARD_ENTERED should be defined")
	assert_not_null(EventTopics.WORLD_HAZARD_EXITED, "WORLD_HAZARD_EXITED should be defined")
	assert_not_null(EventTopics.WORLD_HAZARD_DAMAGE, "WORLD_HAZARD_DAMAGE should be defined")
	assert_not_null(EventTopics.WORLD_LEVEL_LOAD_STARTED, "WORLD_LEVEL_LOAD_STARTED should be defined")
	assert_not_null(EventTopics.WORLD_LEVEL_LOAD_FAILED, "WORLD_LEVEL_LOAD_FAILED should be defined")
	assert_not_null(EventTopics.WORLD_LEVEL_LOAD_SUCCESS, "WORLD_LEVEL_LOAD_SUCCESS should be defined")
	assert_not_null(EventTopics.WORLD_LEVEL_PUSH_STARTED, "WORLD_LEVEL_PUSH_STARTED should be defined")
	assert_not_null(EventTopics.WORLD_LEVEL_PUSH_FAILED, "WORLD_LEVEL_PUSH_FAILED should be defined")
	assert_not_null(EventTopics.WORLD_LEVEL_PUSH_SUCCESS, "WORLD_LEVEL_PUSH_SUCCESS should be defined")
	assert_not_null(EventTopics.WORLD_LEVEL_POP_STARTED, "WORLD_LEVEL_POP_STARTED should be defined")
	assert_not_null(EventTopics.WORLD_LEVEL_POP_FAILED, "WORLD_LEVEL_POP_FAILED should be defined")
	assert_not_null(EventTopics.WORLD_LEVEL_POP_SUCCESS, "WORLD_LEVEL_POP_SUCCESS should be defined")
	assert_not_null(EventTopics.WORLD_CHECKPOINT_REGISTERED, "WORLD_CHECKPOINT_REGISTERED should be defined")
	assert_not_null(EventTopics.WORLD_CHECKPOINT_ACTIVATED, "WORLD_CHECKPOINT_ACTIVATED should be defined")
	assert_not_null(EventTopics.WORLD_INTERACTED, "WORLD_INTERACTED should be defined")
	
	# Test items topics
	assert_not_null(EventTopics.ITEMS_PICKED_UP, "ITEMS_PICKED_UP should be defined")
	assert_not_null(EventTopics.SHOP_PURCHASED, "SHOP_PURCHASED should be defined")
	
	# Test enemy topics
	assert_not_null(EventTopics.ENEMY_SPAWNED_FROM_SPAWNER, "ENEMY_SPAWNED_FROM_SPAWNER should be defined")
	assert_not_null(EventTopics.ENEMY_ATTACK_START, "ENEMY_ATTACK_START should be defined")
	assert_not_null(EventTopics.ENEMY_ATTACK_END, "ENEMY_ATTACK_END should be defined")

func test_event_topics_string_values() -> void:
	"""Test that EventTopics constants have the correct string values."""
	
	# Test debug topics
	assert_eq(EventTopics.DEBUG_CRASH_DETECTED, &"debug/crash_detected", "DEBUG_CRASH_DETECTED should have correct value")
	assert_eq(EventTopics.DEBUG_WARNING, &"debug/warning", "DEBUG_WARNING should have correct value")
	assert_eq(EventTopics.DEBUG_ERROR, &"debug/error", "DEBUG_ERROR should have correct value")
	
	# Test world topics
	assert_eq(EventTopics.WORLD_PORTAL_USED, &"world/portal_used", "WORLD_PORTAL_USED should have correct value")
	assert_eq(EventTopics.WORLD_TIME_PAUSED, &"world/time_paused", "WORLD_TIME_PAUSED should have correct value")
	assert_eq(EventTopics.WORLD_TIME_RESUMED, &"world/time_resumed", "WORLD_TIME_RESUMED should have correct value")
	assert_eq(EventTopics.WORLD_TIME_SCALE_CHANGED, &"world/time_scale_changed", "WORLD_TIME_SCALE_CHANGED should have correct value")
	assert_eq(EventTopics.WORLD_PROP_DAMAGED, &"world/prop_damaged", "WORLD_PROP_DAMAGED should have correct value")
	assert_eq(EventTopics.WORLD_PROP_DESTROYED, &"world/prop_destroyed", "WORLD_PROP_DESTROYED should have correct value")
	assert_eq(EventTopics.WORLD_PROP_RESPAWNED, &"world/prop_respawned", "WORLD_PROP_RESPAWNED should have correct value")
	assert_eq(EventTopics.WORLD_HAZARD_ENTERED, &"world/hazard_entered", "WORLD_HAZARD_ENTERED should have correct value")
	assert_eq(EventTopics.WORLD_HAZARD_EXITED, &"world/hazard_exited", "WORLD_HAZARD_EXITED should have correct value")
	assert_eq(EventTopics.WORLD_HAZARD_DAMAGE, &"world/hazard_damage", "WORLD_HAZARD_DAMAGE should have correct value")
	assert_eq(EventTopics.WORLD_LEVEL_LOAD_STARTED, &"world/level_load_started", "WORLD_LEVEL_LOAD_STARTED should have correct value")
	assert_eq(EventTopics.WORLD_LEVEL_LOAD_FAILED, &"world/level_load_failed", "WORLD_LEVEL_LOAD_FAILED should have correct value")
	assert_eq(EventTopics.WORLD_LEVEL_LOAD_SUCCESS, &"world/level_load_success", "WORLD_LEVEL_LOAD_SUCCESS should have correct value")
	assert_eq(EventTopics.WORLD_LEVEL_PUSH_STARTED, &"world/level_push_started", "WORLD_LEVEL_PUSH_STARTED should have correct value")
	assert_eq(EventTopics.WORLD_LEVEL_PUSH_FAILED, &"world/level_push_failed", "WORLD_LEVEL_PUSH_FAILED should have correct value")
	assert_eq(EventTopics.WORLD_LEVEL_PUSH_SUCCESS, &"world/level_push_success", "WORLD_LEVEL_PUSH_SUCCESS should have correct value")
	assert_eq(EventTopics.WORLD_LEVEL_POP_STARTED, &"world/level_pop_started", "WORLD_LEVEL_POP_STARTED should have correct value")
	assert_eq(EventTopics.WORLD_LEVEL_POP_FAILED, &"world/level_pop_failed", "WORLD_LEVEL_POP_FAILED should have correct value")
	assert_eq(EventTopics.WORLD_LEVEL_POP_SUCCESS, &"world/level_pop_success", "WORLD_LEVEL_POP_SUCCESS should have correct value")
	assert_eq(EventTopics.WORLD_CHECKPOINT_REGISTERED, &"world/checkpoint_registered", "WORLD_CHECKPOINT_REGISTERED should have correct value")
	assert_eq(EventTopics.WORLD_CHECKPOINT_ACTIVATED, &"world/checkpoint_activated", "WORLD_CHECKPOINT_ACTIVATED should have correct value")
	assert_eq(EventTopics.WORLD_INTERACTED, &"world/interacted", "WORLD_INTERACTED should have correct value")
	
	# Test items topics
	assert_eq(EventTopics.ITEMS_PICKED_UP, &"item/picked_up", "ITEMS_PICKED_UP should have correct value")
	assert_eq(EventTopics.SHOP_PURCHASED, &"shop/purchased", "SHOP_PURCHASED should have correct value")
	
	# Test enemy topics
	assert_eq(EventTopics.ENEMY_SPAWNED_FROM_SPAWNER, &"enemy/spawned_from_spawner", "ENEMY_SPAWNED_FROM_SPAWNER should have correct value")
	assert_eq(EventTopics.ENEMY_ATTACK_START, &"enemy/attack_start", "ENEMY_ATTACK_START should have correct value")
	assert_eq(EventTopics.ENEMY_ATTACK_END, &"enemy/attack_end", "ENEMY_ATTACK_END should have correct value")

func test_all_array_includes_new_topics() -> void:
	"""Test that the ALL array includes all the new topics."""
	
	# Check that new topics are in the ALL array
	assert_true(EventTopics.ALL.has(EventTopics.DEBUG_CRASH_DETECTED), "ALL should include DEBUG_CRASH_DETECTED")
	assert_true(EventTopics.ALL.has(EventTopics.DEBUG_WARNING), "ALL should include DEBUG_WARNING")
	assert_true(EventTopics.ALL.has(EventTopics.DEBUG_ERROR), "ALL should include DEBUG_ERROR")
	
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_PORTAL_USED), "ALL should include WORLD_PORTAL_USED")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_TIME_PAUSED), "ALL should include WORLD_TIME_PAUSED")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_TIME_RESUMED), "ALL should include WORLD_TIME_RESUMED")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_TIME_SCALE_CHANGED), "ALL should include WORLD_TIME_SCALE_CHANGED")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_PROP_DAMAGED), "ALL should include WORLD_PROP_DAMAGED")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_PROP_DESTROYED), "ALL should include WORLD_PROP_DESTROYED")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_PROP_RESPAWNED), "ALL should include WORLD_PROP_RESPAWNED")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_HAZARD_ENTERED), "ALL should include WORLD_HAZARD_ENTERED")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_HAZARD_EXITED), "ALL should include WORLD_HAZARD_EXITED")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_HAZARD_DAMAGE), "ALL should include WORLD_HAZARD_DAMAGE")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_LEVEL_LOAD_STARTED), "ALL should include WORLD_LEVEL_LOAD_STARTED")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_LEVEL_LOAD_FAILED), "ALL should include WORLD_LEVEL_LOAD_FAILED")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_LEVEL_LOAD_SUCCESS), "ALL should include WORLD_LEVEL_LOAD_SUCCESS")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_LEVEL_PUSH_STARTED), "ALL should include WORLD_LEVEL_PUSH_STARTED")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_LEVEL_PUSH_FAILED), "ALL should include WORLD_LEVEL_PUSH_FAILED")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_LEVEL_PUSH_SUCCESS), "ALL should include WORLD_LEVEL_PUSH_SUCCESS")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_LEVEL_POP_STARTED), "ALL should include WORLD_LEVEL_POP_STARTED")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_LEVEL_POP_FAILED), "ALL should include WORLD_LEVEL_POP_FAILED")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_LEVEL_POP_SUCCESS), "ALL should include WORLD_LEVEL_POP_SUCCESS")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_CHECKPOINT_REGISTERED), "ALL should include WORLD_CHECKPOINT_REGISTERED")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_CHECKPOINT_ACTIVATED), "ALL should include WORLD_CHECKPOINT_ACTIVATED")
	assert_true(EventTopics.ALL.has(EventTopics.WORLD_INTERACTED), "ALL should include WORLD_INTERACTED")
	
	assert_true(EventTopics.ALL.has(EventTopics.ITEMS_PICKED_UP), "ALL should include ITEMS_PICKED_UP")
	assert_true(EventTopics.ALL.has(EventTopics.SHOP_PURCHASED), "ALL should include SHOP_PURCHASED")
	
	assert_true(EventTopics.ALL.has(EventTopics.ENEMY_SPAWNED_FROM_SPAWNER), "ALL should include ENEMY_SPAWNED_FROM_SPAWNER")
	assert_true(EventTopics.ALL.has(EventTopics.ENEMY_ATTACK_START), "ALL should include ENEMY_ATTACK_START")
	assert_true(EventTopics.ALL.has(EventTopics.ENEMY_ATTACK_END), "ALL should include ENEMY_ATTACK_END")

func test_no_duplicate_topics() -> void:
	"""Test that there are no duplicate topics in the ALL array."""
	var topic_counts := {}
	
	for topic in EventTopics.ALL:
		if topic_counts.has(topic):
			topic_counts[topic] += 1
		else:
			topic_counts[topic] = 1
	
	var duplicates := []
	for topic in topic_counts.keys():
		if topic_counts[topic] > 1:
			duplicates.append(topic)
	
	assert_eq(duplicates.size(), 0, "No duplicate topics should exist in ALL array. Found: " + str(duplicates))
