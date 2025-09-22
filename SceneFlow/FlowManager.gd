class_name _FlowManager
extends Node

## FlowManager is an autoload singleton responsible for high-level scene navigation.
## It provides a stack-based API for pushing, popping, and replacing scenes.

const ERROR_NO_PREVIOUS_SCENE: int = ERR_DOES_NOT_EXIST

class FlowStackEntry extends RefCounted:
	var scene_path: String
	var created_ms: int

	func _init(scene_path: String) -> void:
		self.scene_path = scene_path
		self.created_ms = Time.get_ticks_msec()

var _stack: Array[FlowStackEntry] = []

func _ready() -> void:
	if _stack.is_empty():
		var current_scene := get_tree().current_scene
		if current_scene:
			_stack.append(FlowStackEntry.new(current_scene.scene_file_path))

## Pushes a scene onto the stack and transitions to it.
## @param scene_path Resource path to the scene to activate.
## @return Error code from the scene change operation.
func push_scene(scene_path: String) -> Error:
	var entry := FlowStackEntry.new(scene_path)
	_stack.append(entry)
	var err := _change_to(entry)
	if err != OK:
		_stack.pop_back()
	return err

## Replaces the current scene with a new one.
## @param scene_path Resource path to the replacement scene.
## @return Error code from the scene change operation.
func replace_scene(scene_path: String) -> Error:
	if _stack.is_empty():
		_stack.append(FlowStackEntry.new(scene_path))
	else:
		_stack[_stack.size() - 1] = FlowStackEntry.new(scene_path)
	var entry := _stack[_stack.size() - 1]
	var err := _change_to(entry)
	if err != OK and _stack.size() == 1:
		_stack.clear()
	return err

## Pops the current scene and returns to the previous one.
## @return Error code indicating success or failure.
func pop_scene() -> Error:
	if _stack.size() <= 1:
		return ERROR_NO_PREVIOUS_SCENE
	_stack.pop_back()
	var target := _stack[_stack.size() - 1]
	return _change_to(target)

## Peeks at the current stack entry.
## @return FlowStackEntry describing the active scene.
func peek_scene() -> FlowStackEntry:
	return _stack[-1] if _stack.size() > 0 else null

## Clears the stack, optionally retaining the active scene.
## @param keep_active Whether to keep the active scene entry.
func clear_stack(keep_active: bool = true) -> void:
	if keep_active and _stack.size() > 0:
		var top := _stack[-1]
		_stack = [top]
	else:
		_stack.clear()

func _change_to(entry: FlowStackEntry) -> Error:
	if entry.scene_path.is_empty():
		return ERR_INVALID_PARAMETER
	if not ResourceLoader.exists(entry.scene_path):
		return ERR_FILE_NOT_FOUND
	var packed := ResourceLoader.load(entry.scene_path)
	if packed == null or not packed is PackedScene:
		return ERR_FILE_CANT_OPEN
	var err := get_tree().change_scene_to_packed(packed)
	if err != OK:
		return err
	return OK
