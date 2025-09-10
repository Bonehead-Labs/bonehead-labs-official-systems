extends Node

## Example script demonstrating how to use the SaveService
## This shows all the main features and how to integrate them into your game

var player_data: PlayerData

func _ready() -> void:
	# Wait for SaveService autoload to be ready
	call_deferred("_setup_demo")

func _setup_demo() -> void:
	# Create and setup player data
	player_data = PlayerData.new()
	add_child(player_data)
	
	# Connect to SaveService signals for debugging/feedback
	SaveService.profile_changed.connect(_on_profile_changed)
	SaveService.error.connect(_on_save_error)
	SaveService.autosave_triggered.connect(_on_autosave)
	SaveService.checkpoint_created.connect(_on_checkpoint_created)
	
	# Example usage
	await get_tree().create_timer(1.0).timeout  # Wait for setup
	_demonstrate_save_system()

func _demonstrate_save_system() -> void:
	print("=== SaveService Demo ===")
	
	# 1. Set up a profile
	print("\n1. Setting up profile...")
	var success = SaveService.set_current_profile("demo_player")
	if not success:
		print("Failed to create profile!")
		return
	
	# 2. Configure some player data
	print("\n2. Setting up player data...")
	player_data.player_name = "TestPlayer"
	player_data.level = 5
	player_data.experience = 250
	player_data.health = 75.0
	player_data.position = Vector3(10, 5, -3)
	player_data.inventory = ["sword", "potion", "key"]
	player_data.settings = {"volume": 0.8, "difficulty": "normal"}
	
	# 3. Save the game
	print("\n3. Saving game...")
	success = SaveService.save_game("demo_save")
	if success:
		print("Game saved successfully!")
	else:
		print("Save failed!")
		return
	
	# 4. Modify data and create checkpoint
	print("\n4. Creating checkpoint...")
	player_data.gain_experience(100)
	player_data.add_to_inventory("magic_ring")
	SaveService.create_checkpoint("before_boss")
	
	# 5. List available saves
	print("\n5. Available saves:")
	var saves = SaveService.list_saves()
	for save_name in saves:
		print("  - ", save_name)
	
	# 6. List checkpoints
	print("\n6. Available checkpoints:")
	var checkpoints = SaveService.list_checkpoints()
	for checkpoint in checkpoints:
		print("  - ", checkpoint)
	
	# 7. Demonstrate loading
	print("\n7. Testing load...")
	# Modify data first to show the load works
	player_data.player_name = "Modified"
	player_data.level = 99
	
	success = SaveService.load_game("demo_save")
	if success:
		print("Game loaded! Player name: ", player_data.player_name, ", Level: ", player_data.level)
	else:
		print("Load failed!")
	
	# 8. Show statistics
	print("\n8. Save system statistics:")
	var stats = SaveService.get_save_statistics()
	for key in stats:
		print("  ", key, ": ", stats[key])

func _on_profile_changed(profile_id: String) -> void:
	print("Profile changed to: ", profile_id)

func _on_save_error(code: String, message: String) -> void:
	print("SaveService Error [", code, "]: ", message)

func _on_autosave() -> void:
	print("Auto-save triggered!")

func _on_checkpoint_created(checkpoint_name: String) -> void:
	print("Checkpoint created: ", checkpoint_name)

# Input handling for manual testing
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # Enter key
		print("\n--- Manual Save ---")
		SaveService.save_game("manual_save")
	
	elif event.is_action_pressed("ui_cancel"):  # Escape key
		print("\n--- Manual Load ---")
		SaveService.load_game("manual_save")
	
	elif event.is_action_pressed("ui_select"):  # Space key
		print("\n--- Create Checkpoint ---")
		SaveService.create_checkpoint("manual_checkpoint")

# Example of handling save/load in a menu system
func save_to_slot(slot_number: int) -> bool:
	var save_name = "slot_%d" % slot_number
	return SaveService.save_game(save_name)

func load_from_slot(slot_number: int) -> bool:
	var save_name = "slot_%d" % slot_number
	if SaveService.has_save(save_name):
		return SaveService.load_game(save_name)
	return false

func get_save_slots() -> Array:
	var slots = []
	for i in range(1, 6):  # 5 save slots
		var save_name = "slot_%d" % i
		slots.append({
			"slot": i,
			"exists": SaveService.has_save(save_name),
			"name": save_name
		})
	return slots

# Example of profile management
func switch_profile(profile_name: String) -> bool:
	return SaveService.set_current_profile(profile_name)

func get_available_profiles() -> PackedStringArray:
	return SaveService.list_profiles()

func delete_profile(profile_name: String) -> bool:
	return SaveService.delete_profile(profile_name)
