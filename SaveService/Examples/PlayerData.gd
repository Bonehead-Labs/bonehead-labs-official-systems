class_name PlayerData
extends Node

## Example implementation of ISaveable interface
## Demonstrates how to create a saveable object

# Player data that should be saved
var player_name: String = "Player"
var level: int = 1
var experience: int = 0
var health: float = 100.0
var position: Vector3 = Vector3.ZERO
var inventory: Array[String] = []
var settings: Dictionary = {}

# ISaveable implementation
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

func load_data(data: Dictionary) -> bool:
	if not data.has("player_name"):
		return false
	
	player_name = data.get("player_name", "Player")
	level = data.get("level", 1)
	experience = data.get("experience", 0)
	health = data.get("health", 100.0)
	
	# Load position
	if data.has("position"):
		var pos_data = data.position
		position = Vector3(
			pos_data.get("x", 0.0),
			pos_data.get("y", 0.0),
			pos_data.get("z", 0.0)
		)
	
	inventory = data.get("inventory", [])
	settings = data.get("settings", {})
	
	return true

func get_save_id() -> String:
	return "player_data"

func get_save_priority() -> int:
	return 10  # High priority - save early

# Example usage
func _ready() -> void:
	# Wait for SaveService to be ready (it's an autoload)
	call_deferred("_register_with_save_service")

func _register_with_save_service() -> void:
	# Register this object with the SaveService
	SaveService.register_saveable(self)
	
	# Connect to save service signals if needed
	SaveService.after_save.connect(_on_save_completed)
	SaveService.after_load.connect(_on_load_completed)

func _on_save_completed(save_id: String, success: bool) -> void:
	if success:
		print("Player data saved successfully to: ", save_id)
	else:
		print("Failed to save player data")

func _on_load_completed(save_id: String, success: bool) -> void:
	if success:
		print("Player data loaded successfully from: ", save_id)
		print("Player: ", player_name, " Level: ", level)
	else:
		print("Failed to load player data")

# Helper methods for game logic
func gain_experience(amount: int) -> void:
	experience += amount
	# Check for level up
	while experience >= level * 100:
		experience -= level * 100
		level += 1
		print("Level up! Now level ", level)

func take_damage(amount: float) -> void:
	health = max(0.0, health - amount)
	if health <= 0:
		print("Player died!")

func add_to_inventory(item: String) -> void:
	inventory.append(item)

func remove_from_inventory(item: String) -> bool:
	var index = inventory.find(item)
	if index >= 0:
		inventory.remove_at(index)
		return true
	return false
