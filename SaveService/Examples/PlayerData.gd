class_name PlayerData
extends Node

## Example implementation of ISaveable interface
## 
## This class demonstrates how to create a saveable object that can
## be saved and loaded by the SaveService. It shows best practices
## for implementing the save protocol.
## 
## [b]Key Concepts:[/b]
## - [b]Serialization:[/b] Converting object state to Dictionary for saving
## - [b]Deserialization:[/b] Restoring object state from saved Dictionary
## - [b]Data Validation:[/b] Checking saved data for validity
## - [b]Default Values:[/b] Providing fallbacks for missing data
## - [b]Priority System:[/b] Ensuring objects save in correct order

# Player data that should be saved
var player_name: String = "Player"
var level: int = 1
var experience: int = 0
var health: float = 100.0
var position: Vector3 = Vector3.ZERO
var inventory: Array[String] = []
var settings: Dictionary = {}

## Save the player's current state to a Dictionary
## 
## Converts all important player data into a Dictionary that can
## be saved to disk. This is called by SaveService during save operations.
## 
## [b]Returns:[/b] Dictionary containing all player data
## 
## [b]Important:[/b] Only save essential data. Avoid saving temporary
## values, cached data, or references to other objects.
func save_data() -> Dictionary:
	return {
		"player_name": player_name,
		"level": level,
		"experience": experience,
		"health": health,
		"position": {
			"x": position.x,
			"y": position.y,
			"z": position.z
		},
		"inventory": inventory,
		"settings": settings
	}

## Load the player's state from a saved Dictionary
## 
## Restores the player's state from previously saved data.
## This is called by SaveService during load operations.
## 
## [b]data:[/b] Dictionary containing saved player data
## 
## [b]Returns:[/b] true if load succeeded, false otherwise
## 
## [b]Important:[/b] Always validate the data structure and provide
## sensible defaults for missing or invalid data.
func load_data(data: Dictionary) -> bool:
	if not data.has("player_name"):
		return false
	
	player_name = data.get("player_name", "Player")
	level = data.get("level", 1)
	experience = data.get("experience", 0)
	health = data.get("health", 100.0)
	
	# Load position with validation
	if data.has("position"):
		var pos_data: Dictionary = data.position
		position = Vector3(
			pos_data.get("x", 0.0),
			pos_data.get("y", 0.0),
			pos_data.get("z", 0.0)
		)
	
	inventory = data.get("inventory", [])
	settings = data.get("settings", {})
	
	return true

## Get unique identifier for this saveable object
## 
## Returns a unique string that identifies this object in save files.
## This must be consistent across save/load cycles.
## 
## [b]Returns:[/b] Unique string identifier
func get_save_id() -> String:
	return "player_data"

## Get save priority for this object
## 
## Lower numbers are saved first. Player data should be saved early
## since other objects might depend on it.
## 
## [b]Returns:[/b] Priority value (10 = high priority)
func get_save_priority() -> int:
	return 10  # High priority - save early

## Example usage and SaveService integration
## 
## This section shows how to register the object with SaveService
## and handle save/load events.
func _ready() -> void:
	# Wait for SaveService to be ready (it's an autoload)
	call_deferred("_register_with_save_service")

## Register this object with the SaveService
## 
## This method registers the player data object with the SaveService
## so it will be included in save/load operations.
func _register_with_save_service() -> void:
	# Register this object with the SaveService
	SaveService.register_saveable(self)
	
	# Connect to save service signals if needed
	SaveService.after_save.connect(_on_save_completed)
	SaveService.after_load.connect(_on_load_completed)

## Handle save completion events
## 
## Called when a save operation completes. Useful for UI feedback
## or additional processing after saving.
## 
## [b]save_id:[/b] ID of the save slot that was saved
## [b]success:[/b] Whether the save operation succeeded
func _on_save_completed(save_id: String, success: bool) -> void:
	if success:
		print("Player data saved successfully to: ", save_id)
	else:
		print("Failed to save player data")

## Handle load completion events
## 
## Called when a load operation completes. Useful for UI feedback
## or additional processing after loading.
## 
## [b]save_id:[/b] ID of the save slot that was loaded
## [b]success:[/b] Whether the load operation succeeded
func _on_load_completed(save_id: String, success: bool) -> void:
	if success:
		print("Player data loaded successfully from: ", save_id)
		print("Player: ", player_name, " Level: ", level)
	else:
		print("Failed to load player data")

## Helper methods for game logic
## 
## These methods demonstrate how to modify player data in ways
## that will be automatically saved when the game is saved.

## Gain experience points and check for level up
## 
## [b]amount:[/b] Experience points to add
func gain_experience(amount: int) -> void:
	experience += amount
	# Check for level up
	while experience >= level * 100:
		experience -= level * 100
		level += 1
		print("Level up! Now level ", level)

## Take damage and check for death
## 
## [b]amount:[/b] Damage amount to subtract from health
func take_damage(amount: float) -> void:
	health = max(0.0, health - amount)
	if health <= 0:
		print("Player died!")

## Add an item to the inventory
## 
## [b]item:[/b] Item name to add
func add_to_inventory(item: String) -> void:
	inventory.append(item)

## Remove an item from the inventory
## 
## [b]item:[/b] Item name to remove
## 
## [b]Returns:[/b] true if item was found and removed, false otherwise
func remove_from_inventory(item: String) -> bool:
	var index: int = inventory.find(item)
	if index >= 0:
		inventory.remove_at(index)
		return true
	return false
