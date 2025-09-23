extends Node
class_name Crafting

signal crafted(recipe_id: String, success: bool)

func craft(_inventory: Node, _recipe_id: String) -> bool:
	# Stub implementation; integrate with RNGService and SaveService as needed
	crafted.emit(_recipe_id, true)
	return true

