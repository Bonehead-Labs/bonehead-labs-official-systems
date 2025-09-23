extends Resource
class_name ItemDef

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var rarity: String = "common"
@export var tags: Array[String] = []
@export var max_stack: int = 99
@export var icon: Texture2D

func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"rarity": rarity,
		"tags": tags.duplicate(),
		"max_stack": max_stack
	}
