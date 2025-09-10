class_name _ISaveable
extends RefCounted

## Interface for objects that can be saved/loaded by the SaveService
## Implement this interface in classes that need to persist data

## Serialize the object's data to a Dictionary
## Return a Dictionary containing all data that should be saved
func save_data() -> Dictionary:
	push_error("ISaveable.save_data() must be implemented")
	return {}

## Deserialize data from a Dictionary to restore object state
## @param _data: Dictionary containing the saved data
## @return: true if load was successful, false otherwise
func load_data(_data: Dictionary) -> bool:
	push_error("ISaveable.load_data() must be implemented")
	return false

## Get a unique identifier for this saveable object
## Used to identify the object in save files
func get_save_id() -> String:
	push_error("ISaveable.get_save_id() must be implemented")
	return ""

## Get the save priority (lower numbers save first)
## Useful for ensuring dependencies are saved in correct order
func get_save_priority() -> int:
	return 100  # Default priority
