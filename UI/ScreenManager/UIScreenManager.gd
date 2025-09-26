class_name _UIScreenManager
extends Control

## UIScreenManager handles layered UI navigation with reusable transitions.

signal screen_pushed(id: StringName)
signal screen_replaced(id: StringName)
signal screen_popped(id: StringName)
signal screen_stack_changed(size: int)
signal transition_finished(id: StringName, metadata: Dictionary)

@export var transition_player_path: NodePath
@export var transition_library: FlowTransitionLibrary

var _screens: Dictionary[StringName, PackedScene] = {}
var _stack: Array[ScreenEntry] = []
var _transition_player: Node = null
var _pending_transition_id: StringName = StringName()
var _pending_transition_metadata: Dictionary = {}

class ScreenEntry extends RefCounted:
    var id: StringName
    var node: Control
    var context: Dictionary[StringName, Variant]
    var created_ms: int

    func _init(screen_id: StringName, screen_node: Control, screen_context: Dictionary[StringName, Variant]) -> void:
        id = screen_id
        node = screen_node
        context = screen_context
        created_ms = Time.get_ticks_msec()

## Register a screen scene for navigation
## 
## Registers a PackedScene that can be instantiated and navigated to.
## The scene must contain a Control node as its root.
## 
## [b]id:[/b] Unique identifier for the screen
## [b]scene:[/b] PackedScene containing the screen UI
## 
## [b]Usage:[/b]
## [codeblock]
## # Register a main menu screen
## var menu_scene = preload("res://ui/screens/MainMenu.tscn")
## screen_manager.register_screen("main_menu", menu_scene)
## [/codeblock]
func register_screen(id: StringName, scene: PackedScene) -> void:
    if scene == null:
        push_warning("UIScreenManager.register_screen: scene is null for id %s" % id)
        return
    _screens[id] = scene

## Unregister a screen scene
## 
## Removes a screen from the registry. The screen cannot be
## navigated to after unregistration.
## 
## [b]id:[/b] Unique identifier of the screen to remove
## 
## [b]Usage:[/b]
## [codeblock]
## # Remove a screen from registry
## screen_manager.unregister_screen("old_menu")
## [/codeblock]
func unregister_screen(id: StringName) -> void:
    _screens.erase(id)

## Check if a screen is registered
## 
## [b]id:[/b] Screen identifier to check
## 
## [b]Returns:[/b] true if screen is registered, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## # Check before navigation
## if screen_manager.has_screen("settings"):
##     screen_manager.push_screen("settings")
## [/codeblock]
func has_screen(id: StringName) -> bool:
    return _screens.has(id)

## Push a screen onto the navigation stack
## 
## Adds a new screen to the top of the navigation stack, hiding
## the current screen and showing the new one with transitions.
## 
## [b]id:[/b] Unique identifier of the screen to push
## [b]context:[/b] Data to pass to the screen (optional)
## 
## [b]Returns:[/b] OK if successful, ERR_DOES_NOT_EXIST if screen not registered, ERR_INVALID_DATA if instantiation fails
## 
## [b]Usage:[/b]
## [codeblock]
## # Push settings screen with player data
## var context = {"player": player_node, "return_to": "main_menu"}
## screen_manager.push_screen("settings", context)
## [/codeblock]
func push_screen(id: StringName, context: Dictionary[StringName, Variant] = _empty_context()) -> Error:
    if not _screens.has(id):
        return ERR_DOES_NOT_EXIST
        
    var scene: PackedScene = _screens[id]
    var instance: Node = scene.instantiate()
    if not (instance is Control):
        instance.queue_free()
        return ERR_INVALID_DATA
        
    var entry: ScreenEntry = ScreenEntry.new(id, instance, _duplicate_context(context))
    _perform_exit_transition(_peek_entry())
    add_child(instance)
    instance.visible = false
    _stack.append(entry)
    _activate_entry(entry)
    screen_pushed.emit(id)
    _publish_event(EventTopics.UI_SCREEN_PUSHED, id)
    _emit_stack_change()
    return OK

## Replace the current screen with a new one
## 
## Replaces the top screen on the stack with a new screen,
## maintaining the same stack depth.
## 
## [b]id:[/b] Unique identifier of the screen to replace with
## [b]context:[/b] Data to pass to the new screen (optional)
## 
## [b]Returns:[/b] OK if successful, ERR_DOES_NOT_EXIST if screen not registered, ERR_INVALID_DATA if instantiation fails
## 
## [b]Usage:[/b]
## [codeblock]
## # Replace current screen with game over
## screen_manager.replace_screen("game_over", {"score": final_score})
## [/codeblock]
func replace_screen(id: StringName, context: Dictionary[StringName, Variant] = _empty_context()) -> Error:
    if _stack.is_empty():
        return push_screen(id, context)
        
    if not _screens.has(id):
        return ERR_DOES_NOT_EXIST
        
    var previous: ScreenEntry = _stack.pop_back()
    var scene: PackedScene = _screens[id]
    var instance: Node = scene.instantiate()
    if not (instance is Control):
        instance.queue_free()
        _stack.append(previous)
        return ERR_INVALID_DATA
        
    _perform_exit_transition(previous)
    previous.node.queue_free()
    var entry: ScreenEntry = ScreenEntry.new(id, instance, _duplicate_context(context))
    add_child(instance)
    instance.visible = false
    _stack.append(entry)
    _activate_entry(entry)
    screen_replaced.emit(id)
    _publish_event(EventTopics.UI_SCREEN_PUSHED, id)
    _emit_stack_change()
    return OK

## Pop the current screen from the navigation stack
## 
## Removes the top screen from the stack and returns to the
## previous screen with transitions.
## 
## [b]Returns:[/b] OK if successful, ERR_DOES_NOT_EXIST if no screen to pop
## 
## [b]Usage:[/b]
## [codeblock]
## # Return to previous screen
## screen_manager.pop_screen()
## [/codeblock]
func pop_screen() -> Error:
    if _stack.size() <= 1:
        return ERR_DOES_NOT_EXIST
        
    var current: ScreenEntry = _stack.pop_back()
    _perform_exit_transition(current)
    var previous: ScreenEntry = _stack[_stack.size() - 1]
    current.node.queue_free()
    _activate_entry(previous)
    screen_popped.emit(current.id)
    _publish_event(EventTopics.UI_SCREEN_POPPED, current.id)
    _emit_stack_change()
    return OK

## Clear all screens except the root screen
## 
## Removes all screens from the stack except the first one,
## returning to the root screen.
## 
## [b]Usage:[/b]
## [codeblock]
## # Return to main menu from anywhere
## screen_manager.clear_screens()
## [/codeblock]
func clear_screens() -> void:
    while _stack.size() > 1:
        var entry: ScreenEntry = _stack.pop_back()
        _perform_exit_transition(entry)
        entry.node.queue_free()
    if _stack.size() == 1:
        _activate_entry(_stack[-1])
    _emit_stack_change()

## Get the ID of the current top screen
## 
## [b]Returns:[/b] ID of the current screen or empty StringName if no screens
## 
## [b]Usage:[/b]
## [codeblock]
## # Check current screen
## var current_screen = screen_manager.peek_screen()
## if current_screen == "main_menu":
##     # Handle main menu specific logic
## [/codeblock]
func peek_screen() -> StringName:
    var entry: ScreenEntry = _peek_entry()
    return entry.id if entry else StringName()

## Activate a screen entry
## 
## Makes a screen visible, plays enter transition, and calls
## screen lifecycle methods.
## 
## [b]entry:[/b] ScreenEntry to activate
func _activate_entry(entry: ScreenEntry) -> void:
    if entry == null:
        return
        
    entry.node.visible = true
    _ensure_transition_player()
    _play_transition(entry, true)
    _call_screen_method(entry.node, StringName("receive_context"), entry.context)
    _call_screen_method(entry.node, StringName("on_screen_entered"), entry.context)

## Perform exit transition for a screen entry
## 
## Plays exit transition and calls screen exit lifecycle method.
## 
## [b]entry:[/b] ScreenEntry to exit
func _perform_exit_transition(entry: ScreenEntry) -> void:
    if entry == null:
        return
        
    _play_transition(entry, false)
    _call_screen_method(entry.node, StringName("on_screen_exited"), entry.context)
    entry.node.visible = false

## Play transition for a screen entry
## 
## Plays the appropriate transition (enter or exit) for a screen
## based on its context metadata.
## 
## [b]entry:[/b] ScreenEntry to transition
## [b]is_enter:[/b] true for enter transition, false for exit
func _play_transition(entry: ScreenEntry, is_enter: bool) -> void:
    if transition_library == null:
        return
        
    _ensure_transition_player()
    if _transition_player == null or not _transition_player.has_method("play_transition"):
        return
        
    var metadata: Dictionary[StringName, Variant] = entry.context
    var transition_name: String = metadata.get(StringName("transition"), "")
    var transition: FlowTransition = transition_library.get_transition(StringName(transition_name))
    if transition == null:
        return
        
    _pending_transition_id = entry.id
    _pending_transition_metadata = metadata
    _transition_player.call("play_transition", transition, is_enter)

## Ensure transition player is available
## 
## Sets up the transition player node and connects to its signals
## if not already done.
func _ensure_transition_player() -> void:
    if _transition_player and is_instance_valid(_transition_player):
        return
        
    if transition_player_path.is_empty():
        return
        
    var player: Node = get_node_or_null(transition_player_path)
    if player == null:
        return
        
    _transition_player = player
    if _transition_player.has_signal("transition_finished") and not _transition_player.transition_finished.is_connected(_on_transition_finished):
        _transition_player.transition_finished.connect(_on_transition_finished)

## Handle transition finished events
## 
## Called when a transition completes, emits the transition_finished
## signal with metadata.
## 
## [b]_transition:[/b] Transition that finished (unused)
## [b]direction:[/b] Direction of the transition ("enter" or "exit")
func _on_transition_finished(_transition: FlowTransition, direction: String) -> void:
    if _pending_transition_id == StringName():
        return
        
    var metadata: Dictionary[StringName, Variant] = _pending_transition_metadata.duplicate(true)
    metadata[StringName("direction")] = direction
    transition_finished.emit(_pending_transition_id, metadata)
    _pending_transition_id = StringName()
    _pending_transition_metadata.clear()

## Get the top screen entry from the stack
## 
## [b]Returns:[/b] Top ScreenEntry or null if stack is empty
func _peek_entry() -> ScreenEntry:
    return _stack[-1] if _stack.size() > 0 else null

## Emit stack change signal
## 
## Notifies listeners that the screen stack size has changed.
func _emit_stack_change() -> void:
    screen_stack_changed.emit(_stack.size())

## Publish screen event to EventBus
## 
## Publishes a screen-related event to the EventBus with
## screen ID, timestamp, and stack size information.
## 
## [b]topic:[/b] Event topic to publish
## [b]id:[/b] Screen ID involved
func _publish_event(topic: StringName, id: StringName) -> void:
    if Engine.has_singleton("EventBus"):
        var payload: Dictionary[StringName, Variant] = {
            StringName("id"): id,
            StringName("timestamp_ms"): Time.get_ticks_msec(),
            StringName("stack_size"): _stack.size()
        }
        Engine.get_singleton("EventBus").call("pub", topic, payload)

## Call a method on a screen node if it exists
## 
## Safely calls a method on a screen node, ignoring if the method doesn't exist.
## 
## [b]node:[/b] Screen node to call method on
## [b]method:[/b] Method name to call
## [b]data:[/b] Data to pass to the method
func _call_screen_method(node: Node, method: StringName, data: Dictionary[StringName, Variant]) -> void:
    if node.has_method(method):
        node.call(method, data)

## Duplicate a context dictionary
## 
## Creates a shallow copy of a context dictionary for screen isolation.
## 
## [b]source:[/b] Source dictionary to copy
## 
## [b]Returns:[/b] Shallow copy of the source dictionary
func _duplicate_context(source: Dictionary[StringName, Variant]) -> Dictionary[StringName, Variant]:
    var copy: Dictionary[StringName, Variant] = {} as Dictionary[StringName, Variant]
    for key in source.keys():
        copy[key] = source[key]
    return copy

## Get an empty context dictionary
## 
## Returns a properly typed empty context dictionary.
## 
## [b]Returns:[/b] Empty Dictionary[StringName, Variant]
static func _empty_context() -> Dictionary[StringName, Variant]:
    return {} as Dictionary[StringName, Variant]
