extends Node

## Example script demonstrating how to use the SaveService
## 
## This comprehensive example shows all the main features of the SaveService
## and how to integrate them into your game. It demonstrates:
## 
## [b]Key Features:[/b]
## - Profile management (creating, switching, deleting profiles)
## - Save/load operations (manual and automatic)
## - Checkpoint system (creating and managing checkpoints)
## - Error handling and signal connections
## - Save slot management (multiple save slots)
## - Statistics and debugging information
## 
## [b]Usage:[/b] Add this script to a Node in your scene to see the demo in action.
## Press Enter to save, Escape to load, Space to create checkpoint.

var player_data: PlayerData

## Initialize the demo
## 
## Sets up the demo after the SaveService autoload is ready.
func _ready() -> void:
	# Wait for SaveService autoload to be ready
	call_deferred("_setup_demo")

## Setup the demo environment
## 
## Creates player data, connects to SaveService signals, and starts
## the demonstration after a brief delay.
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

## Demonstrate all SaveService features
## 
## This method walks through all the main features of the SaveService
## in a logical order, showing how to use each feature.
func _demonstrate_save_system() -> void:
	print("=== SaveService Demo ===")
	
	# 1. Set up a profile
	print("\n1. Setting up profile...")
	var success: bool = SaveService.set_current_profile("demo_player")
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
	var saves: PackedStringArray = SaveService.list_saves()
	for save_name in saves:
		print("  - ", save_name)
	
	# 6. List checkpoints
	print("\n6. Available checkpoints:")
	var checkpoints: PackedStringArray = SaveService.list_checkpoints()
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
	var stats: Dictionary = SaveService.get_save_statistics()
	for key in stats:
		print("  ", key, ": ", stats[key])

## Handle profile change events
## 
## Called when the active profile changes.
## 
## [b]profile_id:[/b] ID of the new active profile
func _on_profile_changed(profile_id: String) -> void:
	print("Profile changed to: ", profile_id)

## Handle SaveService error events
## 
## Called when an error occurs in the SaveService.
## 
## [b]code:[/b] Error code identifier
## [b]message:[/b] Human-readable error message
func _on_save_error(code: String, message: String) -> void:
	print("SaveService Error [", code, "]: ", message)

## Handle auto-save events
## 
## Called when the auto-save timer triggers.
func _on_autosave() -> void:
	print("Auto-save triggered!")

## Handle checkpoint creation events
## 
## Called when a checkpoint is successfully created.
## 
## [b]checkpoint_name:[/b] Name of the created checkpoint
func _on_checkpoint_created(checkpoint_name: String) -> void:
	print("Checkpoint created: ", checkpoint_name)

## Input handling for manual testing
## 
## Provides keyboard shortcuts for testing save/load functionality.
## 
## [b]event:[/b] Input event to process
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

## Example of handling save/load in a menu system
## 
## These functions demonstrate how to implement a save slot system
## commonly found in game menus.

## Save to a specific slot number
## 
## [b]slot_number:[/b] Slot number (1-5)
## 
## [b]Returns:[/b] true if save succeeded, false otherwise
func save_to_slot(slot_number: int) -> bool:
	var save_name: String = "slot_%d" % slot_number
	return SaveService.save_game(save_name)

## Load from a specific slot number
## 
## [b]slot_number:[/b] Slot number (1-5)
## 
## [b]Returns:[/b] true if load succeeded, false otherwise
func load_from_slot(slot_number: int) -> bool:
	var save_name: String = "slot_%d" % slot_number
	if SaveService.has_save(save_name):
		return SaveService.load_game(save_name)
	return false

## Get information about all save slots
## 
## [b]Returns:[/b] Array of dictionaries with slot information
func get_save_slots() -> Array:
	var slots: Array = []
	for i in range(1, 6):  # 5 save slots
		var save_name: String = "slot_%d" % i
		slots.append({
			"slot": i,
			"exists": SaveService.has_save(save_name),
			"name": save_name
		})
	return slots

## Example of profile management
## 
## These functions demonstrate how to implement profile management
## in a game with multiple player profiles.

## Switch to a different profile
## 
## [b]profile_name:[/b] Name of the profile to switch to
## 
## [b]Returns:[/b] true if profile switch succeeded, false otherwise
func switch_profile(profile_name: String) -> bool:
	return SaveService.set_current_profile(profile_name)

## Get list of available profiles
## 
## [b]Returns:[/b] Array of profile names
func get_available_profiles() -> PackedStringArray:
	return SaveService.list_profiles()

## Delete a profile and all its saves
## 
## [b]profile_name:[/b] Name of the profile to delete
## 
## [b]Returns:[/b] true if profile deletion succeeded, false otherwise
func delete_profile(profile_name: String) -> bool:
	return SaveService.delete_profile(profile_name)
