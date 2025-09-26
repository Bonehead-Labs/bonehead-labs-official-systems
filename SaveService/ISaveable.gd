class_name _ISaveable
extends RefCounted

## Interface for objects that can be saved/loaded by the SaveService
## Implement this interface in classes that need to persist data

## Serialize the object's data to a Dictionary
## 
## Converts the object's current state into a Dictionary that can be
## saved to disk. This is the core method for data persistence.
## 
## [b]Returns:[/b] Dictionary containing all data that should be saved
## 
## [b]Usage:[/b]
## [codeblock]
## func save_data() -> Dictionary:
##     return {
##         "health": current_health,
##         "position": {"x": position.x, "y": position.y},
##         "inventory": item_ids,
##         "level": current_level
##     }
## [/codeblock]
## 
## [b]Important:[/b] Only save essential data. Avoid saving temporary
## values, cached data, or references to other objects.
func save_data() -> Dictionary:
	push_error("ISaveable.save_data() must be implemented")
	return {}

## Deserialize data from a Dictionary to restore object state
## 
## Restores the object's state from previously saved data.
## This is called when loading a saved game.
## 
## [b]_data:[/b] Dictionary containing the saved data
## 
## [b]Returns:[/b] true if load was successful, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## func load_data(data: Dictionary) -> bool:
##     if not data.has("health"):
##         return false  # Invalid save data
##     
##     current_health = data.get("health", 100.0)
##     var pos_data = data.get("position", {})
##     position = Vector2(pos_data.get("x", 0), pos_data.get("y", 0))
##     
##     return true  # Successfully loaded
## [/codeblock]
## 
## [b]Important:[/b] Always validate the data structure and provide
## sensible defaults for missing or invalid data.
func load_data(_data: Dictionary) -> bool:
	push_error("ISaveable.load_data() must be implemented")
	return false

## Get a unique identifier for this saveable object
## 
## Returns a unique string identifier used to distinguish this
## object from others in the save file. Must be consistent
## across save/load cycles.
## 
## [b]Returns:[/b] Unique string identifier
## 
## [b]Usage:[/b]
## [codeblock]
## func get_save_id() -> String:
##     return "player_data"  # Simple identifier
##     
## # Or for multiple instances:
## func get_save_id() -> String:
##     return "enemy_%d" % enemy_id  # Unique per instance
## [/codeblock]
## 
## [b]Important:[/b] This ID must be unique within your save system.
## Use descriptive names that won't conflict with other objects.
func get_save_id() -> String:
	push_error("ISaveable.get_save_id() must be implemented")
	return ""

## Get the save priority (lower numbers save first)
## 
## Determines the order in which objects are saved. Lower numbers
## are saved first, which is useful for ensuring dependencies are
## saved in the correct order.
## 
## [b]Returns:[/b] Priority value (lower = saved first)
## 
## [b]Usage:[/b]
## [codeblock]
## func get_save_priority() -> int:
##     return 10   # High priority - save first
##     return 50   # Medium priority
##     return 100  # Low priority - save last
## [/codeblock]
## 
## [b]Common Priorities:[/b]
## - 10: Core game state (player, world state)
## - 50: Game objects (enemies, items, NPCs)
## - 100: UI state, temporary data
## 
## [b]Important:[/b] Objects that other objects depend on should
## have lower priority numbers.
func get_save_priority() -> int:
	return 100  # Default priority
