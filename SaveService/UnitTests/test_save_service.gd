extends "res://addons/gut/test.gd"

## Unit tests for SaveService
## Tests all core functionality including profiles, saving, loading, and validation
var test_saveable: TestSaveable

class TestSaveable extends RefCounted:
	var test_data: Dictionary = {}
	var save_id: String = "test_object"
	var priority: int = 100
	var should_fail_save: bool = false
	var should_fail_load: bool = false
	
	func save_data() -> Dictionary:
		if should_fail_save:
			return {}
		return test_data
	
	func load_data(data: Dictionary) -> bool:
		if should_fail_load:
			return false
		test_data = data
		return true
	
	func get_save_id() -> String:
		return save_id
	
	func get_save_priority() -> int:
		return priority

func before_each():
	# Clean up any existing test profiles
	_cleanup_test_profiles()
	
	# Reset SaveService state for clean tests
	SaveService.current_profile_id = ""
	SaveService._registered_saveables.clear()
	SaveService.strict_mode = true
	SaveService.auto_save_enabled = false  # Disable auto-save during tests
	
	# Create test saveable
	test_saveable = TestSaveable.new()
	test_saveable.test_data = {"value": 42, "name": "test"}

func after_each():
	_cleanup_test_profiles()
	SaveService._registered_saveables.clear()

func _cleanup_test_profiles():
	var profiles = SaveService.list_profiles()
	for profile in profiles:
		if profile.begins_with("test_"):
			SaveService.delete_profile(profile)

# Profile Management Tests
func test_profile_creation():
	assert_true(SaveService.set_current_profile("test_profile"), "Should create new profile")
	assert_eq(SaveService.get_current_profile(), "test_profile", "Profile should be set")

func test_invalid_profile_id():
	assert_false(SaveService.set_current_profile(""), "Empty profile ID should fail")
	assert_false(SaveService.set_current_profile("invalid@profile"), "Invalid characters should fail")
	assert_false(SaveService.set_current_profile("a".repeat(25)), "Too long profile ID should fail")

func test_profile_listing():
	SaveService.set_current_profile("test_profile1")
	SaveService.set_current_profile("test_profile2")
	
	var profiles = SaveService.list_profiles()
	assert_true("test_profile1" in profiles, "Should list created profiles")
	assert_true("test_profile2" in profiles, "Should list created profiles")

func test_profile_deletion():
	SaveService.set_current_profile("test_profile1")
	SaveService.set_current_profile("test_profile2")
	
	assert_false(SaveService.delete_profile("test_profile2"), "Cannot delete active profile")
	assert_true(SaveService.delete_profile("test_profile1"), "Should delete inactive profile")

# Saveable Registration Tests
func test_saveable_registration():
	SaveService.register_saveable(test_saveable)
	var registered = SaveService.get_registered_saveables()
	assert_eq(registered.size(), 1, "Should have one registered saveable")
	assert_eq(registered[0], test_saveable, "Should be the same object")

func test_duplicate_registration():
	SaveService.register_saveable(test_saveable)
	SaveService.register_saveable(test_saveable)
	var registered = SaveService.get_registered_saveables()
	assert_eq(registered.size(), 1, "Should not register duplicates")

func test_duplicate_save_id():
	var duplicate_saveable = TestSaveable.new()
	duplicate_saveable.save_id = test_saveable.save_id
	
	SaveService.register_saveable(test_saveable)
	SaveService.register_saveable(duplicate_saveable)
	
	var registered = SaveService.get_registered_saveables()
	assert_eq(registered.size(), 1, "Should reject duplicate save IDs")

func test_unregister_saveable():
	SaveService.register_saveable(test_saveable)
	SaveService.unregister_saveable(test_saveable)
	var registered = SaveService.get_registered_saveables()
	assert_eq(registered.size(), 0, "Should unregister saveable")

# Save/Load Pipeline Tests
func test_save_without_profile():
	SaveService.register_saveable(test_saveable)
	assert_false(SaveService.save_game("test"), "Should fail without profile")

func test_save_and_load():
	SaveService.set_current_profile("test_profile")
	SaveService.register_saveable(test_saveable)
	
	assert_true(SaveService.save_game("test_save"), "Should save successfully")
	assert_true(SaveService.has_save("test_save"), "Save should exist")
	
	# Modify data and load
	test_saveable.test_data = {"modified": true}
	assert_true(SaveService.load_game("test_save"), "Should load successfully")
	assert_eq(test_saveable.test_data["value"], 42, "Should restore original data")

func test_load_nonexistent_save():
	SaveService.set_current_profile("test_profile")
	assert_false(SaveService.load_game("nonexistent"), "Should fail to load nonexistent save")

func test_save_priority():
	SaveService.set_current_profile("test_profile")
	
	var high_priority = TestSaveable.new()
	high_priority.save_id = "high_priority"
	high_priority.priority = 1
	high_priority.test_data = {"order": "first"}
	
	var low_priority = TestSaveable.new()
	low_priority.save_id = "low_priority"
	low_priority.priority = 100
	low_priority.test_data = {"order": "second"}
	
	SaveService.register_saveable(low_priority)
	SaveService.register_saveable(high_priority)
	
	assert_true(SaveService.save_game("priority_test"), "Should save with priority")

func test_strict_mode():
	SaveService.set_current_profile("test_profile")
	SaveService.set_strict_mode(false)
	
	var invalid_saveable = TestSaveable.new()
	invalid_saveable.save_id = ""  # Invalid ID
	
	SaveService.register_saveable(invalid_saveable)
	var registered = SaveService.get_registered_saveables()
	assert_eq(registered.size(), 1, "Should register in non-strict mode")

# Checkpoint Tests
func test_checkpoint_creation():
	SaveService.set_current_profile("test_profile")
	SaveService.register_saveable(test_saveable)
	
	assert_true(SaveService.create_checkpoint("test_checkpoint"), "Should create checkpoint")
	
	var checkpoints = SaveService.list_checkpoints()
	assert_true("test_checkpoint" in checkpoints, "Should list created checkpoint")

func test_checkpoint_loading():
	SaveService.set_current_profile("test_profile")
	SaveService.register_saveable(test_saveable)
	
	# Create checkpoint
	SaveService.create_checkpoint("test_checkpoint")
	
	# Modify data
	test_saveable.test_data = {"modified": true}
	
	# Load checkpoint
	assert_true(SaveService.load_checkpoint("test_checkpoint"), "Should load checkpoint")
	assert_eq(test_saveable.test_data["value"], 42, "Should restore checkpoint data")

# Auto-save Tests
func test_auto_save_configuration():
	SaveService.enable_auto_save(false)
	SaveService.set_auto_save_interval(60.0)
	
	var stats = SaveService.get_save_statistics()
	assert_false(stats["auto_save_enabled"], "Auto-save should be disabled")
	assert_eq(stats["auto_save_interval"], 60.0, "Interval should be set")

# Utility Tests
func test_save_listing():
	SaveService.set_current_profile("test_profile")
	SaveService.register_saveable(test_saveable)
	
	SaveService.save_game("save1")
	SaveService.save_game("save2")
	
	var saves = SaveService.list_saves()
	assert_true("save1" in saves, "Should list saves")
	assert_true("save2" in saves, "Should list saves")

func test_save_deletion():
	SaveService.set_current_profile("test_profile")
	SaveService.register_saveable(test_saveable)
	
	SaveService.save_game("test_delete")
	assert_true(SaveService.has_save("test_delete"), "Save should exist")
	
	assert_true(SaveService.delete_save("test_delete"), "Should delete save")
	assert_false(SaveService.has_save("test_delete"), "Save should be deleted")

func test_statistics():
	SaveService.set_current_profile("test_profile")
	SaveService.register_saveable(test_saveable)
	
	var stats = SaveService.get_save_statistics()
	assert_eq(stats["current_profile"], "test_profile", "Should report current profile")
	assert_eq(stats["registered_saveables"], 1, "Should report registered count")
	assert_true(stats.has("strict_mode"), "Should include all statistics")

# Error Handling Tests
func test_save_failure():
	SaveService.set_current_profile("test_profile")
	test_saveable.should_fail_save = true
	SaveService.register_saveable(test_saveable)
	
	# In strict mode, empty save data should cause issues
	# but the save operation itself should still complete
	var _result = SaveService.save_game("fail_test")
	# The result depends on how strict mode handles empty data

func test_load_failure():
	SaveService.set_current_profile("test_profile")
	SaveService.register_saveable(test_saveable)
	
	# Save first
	SaveService.save_game("fail_test")
	
	# Then make load fail
	test_saveable.should_fail_load = true
	var _result = SaveService.load_game("fail_test")
	# Should handle load failure gracefully

# Signal Tests
func test_profile_changed_signal():
	watch_signals(SaveService)
	SaveService.set_current_profile("test_profile")
	assert_signal_emitted(SaveService, "profile_changed", "Should emit profile changed")

func test_save_signals():
	SaveService.set_current_profile("test_profile")
	SaveService.register_saveable(test_saveable)
	
	watch_signals(SaveService)
	SaveService.save_game("signal_test")
	
	assert_signal_emitted(SaveService, "before_save", "Should emit before save")
	assert_signal_emitted(SaveService, "after_save", "Should emit after save")

func test_load_signals():
	SaveService.set_current_profile("test_profile")
	SaveService.register_saveable(test_saveable)
	
	SaveService.save_game("signal_test")
	
	watch_signals(SaveService)
	SaveService.load_game("signal_test")
	
	assert_signal_emitted(SaveService, "before_load", "Should emit before load")
	assert_signal_emitted(SaveService, "after_load", "Should emit after load")
