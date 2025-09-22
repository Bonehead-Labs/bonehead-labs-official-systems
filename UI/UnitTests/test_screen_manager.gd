extends "res://addons/gut/test.gd"

const ManagerPath: String = "res://UI/ScreenManager/UIScreenManager.gd"
const ScreenScenePath: String = "res://UI/ScreenManager/TestScreen.tscn"
const TransitionPlayerPath: String = "res://UI/ScreenManager/TransitionPlayerStub.tscn"

var manager: _UIScreenManager
var screen_scene: PackedScene
var transition_player_scene: PackedScene

class EventBusStub extends Node:
    var calls: Array = []

    func pub(topic: StringName, payload: Dictionary) -> void:
        calls.append({"topic": topic, "payload": payload})

var event_bus: EventBusStub

func before_each() -> void:
    screen_scene = load(ScreenScenePath)
    transition_player_scene = load(TransitionPlayerPath)
    manager = load(ManagerPath).new()
    manager.name = "UIScreenManager"
    get_tree().root.add_child(manager)
    await manager.ready
    event_bus = EventBusStub.new()
    event_bus.name = "EventBus"
    get_tree().root.add_child(event_bus)

func after_each() -> void:
    if is_instance_valid(manager):
        manager.queue_free()
        await get_tree().process_frame
    if is_instance_valid(event_bus):
        event_bus.queue_free()
        await get_tree().process_frame

func test_push_screen_activates_control() -> void:
    manager.register_screen(StringName("menu"), screen_scene)
    var ctx := {StringName("transition"): ""} as Dictionary[StringName, Variant]
    var err := manager.push_screen(StringName("menu"), ctx)
    assert_eq(err, OK)
    assert_eq(manager.peek_screen(), StringName("menu"))
    var screen: Control = manager.get_child(manager.get_child_count() - 1)
    assert_true(screen is Control)
    var script := screen as Node
    assert_eq(script.get("entered_count"), 1)

func test_replace_and_pop_screen() -> void:
    manager.register_screen(StringName("menu"), screen_scene)
    manager.register_screen(StringName("settings"), screen_scene)
    assert_eq(manager.push_screen(StringName("menu")), OK)
    assert_eq(manager.replace_screen(StringName("settings")), OK)
    assert_eq(manager.peek_screen(), StringName("settings"))
    assert_eq(manager.pop_screen(), OK)
    assert_eq(manager.peek_screen(), StringName("menu"))

func test_transition_player_emits_signal() -> void:
    manager.register_screen(StringName("menu"), screen_scene)
    var transition := FlowTransition.new()
    transition.name = "fade"
    transition.enter_animation = "enter"
    transition.exit_animation = "exit"
    var library := FlowTransitionLibrary.new()
    library.default_transition = transition
    manager.transition_library = library
    var player := transition_player_scene.instantiate()
    manager.add_child(player)
    manager.transition_player_path = manager.get_path_to(player)
    var received := false
    manager.transition_finished.connect(func(id: StringName, _metadata: Dictionary):
        if id == StringName("menu"):
            received = true
    )
    assert_eq(manager.push_screen(StringName("menu"), {StringName("transition"): "fade"} as Dictionary[StringName, Variant]), OK)
    assert_true(received)

func test_event_bus_published_on_push() -> void:
    manager.register_screen(StringName("menu"), screen_scene)
    assert_eq(manager.push_screen(StringName("menu")), OK)
    assert_eq(event_bus.calls.size(), 1)
    var call := event_bus.calls[0]
    assert_eq(call.topic, EventTopics.UI_SCREEN_PUSHED)
    assert_eq(call.payload.get(StringName("id")), StringName("menu"))
