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

func register_screen(id: StringName, scene: PackedScene) -> void:
    if scene == null:
        push_warning("UIScreenManager.register_screen: scene is null for id %s" % id)
        return
    _screens[id] = scene

func unregister_screen(id: StringName) -> void:
    _screens.erase(id)

func has_screen(id: StringName) -> bool:
    return _screens.has(id)

func push_screen(id: StringName, context: Dictionary[StringName, Variant] = _empty_context()) -> Error:
    if not _screens.has(id):
        return ERR_DOES_NOT_EXIST
    var scene := _screens[id]
    var instance := scene.instantiate()
    if not (instance is Control):
        instance.queue_free()
        return ERR_INVALID_DATA
    var entry := ScreenEntry.new(id, instance, _duplicate_context(context))
    _perform_exit_transition(_peek_entry())
    add_child(instance)
    instance.visible = false
    _stack.append(entry)
    _activate_entry(entry)
    screen_pushed.emit(id)
    _publish_event(EventTopics.UI_SCREEN_PUSHED, id)
    _emit_stack_change()
    return OK

func replace_screen(id: StringName, context: Dictionary[StringName, Variant] = _empty_context()) -> Error:
    if _stack.is_empty():
        return push_screen(id, context)
    if not _screens.has(id):
        return ERR_DOES_NOT_EXIST
    var previous: ScreenEntry = _stack.pop_back()
    var scene := _screens[id]
    var instance := scene.instantiate()
    if not (instance is Control):
        instance.queue_free()
        _stack.append(previous)
        return ERR_INVALID_DATA
    _perform_exit_transition(previous)
    previous.node.queue_free()
    var entry := ScreenEntry.new(id, instance, _duplicate_context(context))
    add_child(instance)
    instance.visible = false
    _stack.append(entry)
    _activate_entry(entry)
    screen_replaced.emit(id)
    _publish_event(EventTopics.UI_SCREEN_PUSHED, id)
    _emit_stack_change()
    return OK

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

func clear_screens() -> void:
    while _stack.size() > 1:
        var entry: ScreenEntry = _stack.pop_back()
        _perform_exit_transition(entry)
        entry.node.queue_free()
    if _stack.size() == 1:
        _activate_entry(_stack[-1])
    _emit_stack_change()

func peek_screen() -> StringName:
    var entry := _peek_entry()
    return entry.id if entry else StringName()

func _activate_entry(entry: ScreenEntry) -> void:
    if entry == null:
        return
    entry.node.visible = true
    _ensure_transition_player()
    _play_transition(entry, true)
    _call_screen_method(entry.node, StringName("receive_context"), entry.context)
    _call_screen_method(entry.node, StringName("on_screen_entered"), entry.context)

func _perform_exit_transition(entry: ScreenEntry) -> void:
    if entry == null:
        return
    _play_transition(entry, false)
    _call_screen_method(entry.node, StringName("on_screen_exited"), entry.context)
    entry.node.visible = false

func _play_transition(entry: ScreenEntry, is_enter: bool) -> void:
    if transition_library == null:
        return
    _ensure_transition_player()
    if _transition_player == null or not _transition_player.has_method("play_transition"):
        return
    var metadata := entry.context
    var transition_name: String = metadata.get(StringName("transition"), "")
    var transition := transition_library.get_transition(StringName(transition_name))
    if transition == null:
        return
    _pending_transition_id = entry.id
    _pending_transition_metadata = metadata
    _transition_player.call("play_transition", transition, is_enter)

func _ensure_transition_player() -> void:
    if _transition_player and is_instance_valid(_transition_player):
        return
    if transition_player_path.is_empty():
        return
    var player := get_node_or_null(transition_player_path)
    if player == null:
        return
    _transition_player = player
    if _transition_player.has_signal("transition_finished") and not _transition_player.transition_finished.is_connected(_on_transition_finished):
        _transition_player.transition_finished.connect(_on_transition_finished)

func _on_transition_finished(_transition: FlowTransition, direction: String) -> void:
    if _pending_transition_id == StringName():
        return
    var metadata := _pending_transition_metadata.duplicate(true)
    metadata[StringName("direction")] = direction
    transition_finished.emit(_pending_transition_id, metadata)
    _pending_transition_id = StringName()
    _pending_transition_metadata.clear()

func _peek_entry() -> ScreenEntry:
    return _stack[-1] if _stack.size() > 0 else null

func _emit_stack_change() -> void:
    screen_stack_changed.emit(_stack.size())

func _publish_event(topic: StringName, id: StringName) -> void:
    if Engine.has_singleton("EventBus"):
        var payload := {
            StringName("id"): id,
            StringName("timestamp_ms"): Time.get_ticks_msec(),
            StringName("stack_size"): _stack.size()
        }
        Engine.get_singleton("EventBus").call("pub", topic, payload)

func _call_screen_method(node: Node, method: StringName, data: Dictionary[StringName, Variant]) -> void:
    if node.has_method(method):
        node.call(method, data)

func _duplicate_context(source: Dictionary[StringName, Variant]) -> Dictionary[StringName, Variant]:
    var copy := {} as Dictionary[StringName, Variant]
    for key in source.keys():
        copy[key] = source[key]
    return copy

static func _empty_context() -> Dictionary[StringName, Variant]:
    return {} as Dictionary[StringName, Variant]
