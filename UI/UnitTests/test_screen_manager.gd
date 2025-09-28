extends "res://addons/gut/test.gd"

const ManagerPath: String = "res://UI/ScreenManager/UIScreenManager.gd"
const ScreenScenePath: String = "res://UI/ScreenManager/TestScreen.tscn"
const TransitionPlayerPath: String = "res://UI/ScreenManager/TransitionPlayerStub.tscn"
const SettingsTemplatePath: String = "res://UI/Templates/SettingsTemplate.tscn"
const ThemeServicePath: String = "res://UI/Theme/ThemeService.gd"
const ThemeLocalizationPath: String = "res://UI/Theme/LocalizationHelper.gd"

var manager: _UIScreenManager
var screen_scene: PackedScene
var transition_player_scene: PackedScene
var theme_service: _ThemeService
var theme_localization: _ThemeLocalization

class EventBusStub extends Node:
    var calls: Array = []

    func pub(topic: StringName, payload: Dictionary) -> void:
        calls.append({"topic": topic, "payload": payload})

var event_bus: EventBusStub
var template_events: Array[Dictionary] = []
var template_close_result: Error

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
    theme_service = null
    theme_localization = null
    template_events.clear()
    template_close_result = ERR_BUG

func after_each() -> void:
    if is_instance_valid(manager):
        manager.queue_free()
        await get_tree().process_frame
    if is_instance_valid(event_bus):
        event_bus.queue_free()
        await get_tree().process_frame
    if is_instance_valid(theme_service):
        theme_service.queue_free()
        await get_tree().process_frame
    if is_instance_valid(theme_localization):
        theme_localization.queue_free()
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

func test_push_template_populates_controls_and_emits_events() -> void:
    await _install_theme_dependencies()
    manager.register_screen(StringName("root"), screen_scene)
    assert_eq(manager.push_screen(StringName("root")), OK)

    manager.register_template(StringName("settings_template"), load(SettingsTemplatePath))
    var content: Dictionary = _build_settings_template_content()
    var context := {
        StringName("template_id"): StringName("demo_template")
    } as Dictionary[StringName, Variant]

    var err := manager.push_template(StringName("settings_template"), content, context)
    assert_eq(err, OK)
    assert_eq(manager.peek_screen(), StringName("demo_template"))
    assert_eq(event_bus.calls.size(), 2)
    var pushed_call := event_bus.calls[1]
    assert_eq(pushed_call.topic, EventTopics.UI_SCREEN_PUSHED)
    assert_eq(pushed_call.payload.get(StringName("id")), StringName("demo_template"))

    var template_node: _UITemplate = manager.get_node("demo_template") as _UITemplate
    assert_not_null(template_node)
    template_node.template_event.connect(_record_template_event)

    await get_tree().process_frame

    var toggle_path := "Layout/Sections/SectionList/display_section/toggle_fullscreen"
    var toggle_button: CheckButton = template_node.get_node(toggle_path) as CheckButton
    assert_not_null(toggle_button)
    toggle_button.emit_signal("toggled", true)

    var slider_path := "Layout/Sections/SectionList/audio_section/adjust_music_volume"
    var slider: Range = template_node.get_node(slider_path) as Range
    assert_not_null(slider)
    slider.emit_signal("value_changed", 0.42)

    var apply_button: Button = template_node.get_node("Layout/Footer/ActionBar/apply_changes") as Button
    assert_not_null(apply_button)
    apply_button.emit_signal("pressed")

    var close_button: Button = template_node.get_node("Layout/Footer/ActionBar/close_menu") as Button
    assert_not_null(close_button)
    close_button.emit_signal("pressed")
    await get_tree().process_frame
    assert_eq(template_close_result, OK)
    assert_eq(manager.peek_screen(), StringName("root"))

    var event_ids: Array = []
    for entry in template_events:
        event_ids.append(entry.get("id"))
    assert_true(event_ids.has(StringName("toggle_fullscreen")))
    assert_true(event_ids.has(StringName("adjust_music_volume")))
    assert_true(event_ids.has(StringName("apply_changes")))
    assert_true(event_ids.has(StringName("close_menu")))

    var template_event_calls := event_bus.calls.filter(func(call): return call.topic == _EventTopics.UI_TEMPLATE_EVENT)
    assert_eq(template_event_calls.size(), template_events.size())

func _install_theme_dependencies() -> void:
    theme_service = load(ThemeServicePath).new()
    theme_service.name = "ThemeService"
    get_tree().root.add_child(theme_service)
    await theme_service.ready

    theme_localization = load(ThemeLocalizationPath).new()
    theme_localization.name = "ThemeLocalization"
    get_tree().root.add_child(theme_localization)
    await get_tree().process_frame

func _record_template_event(event_id: StringName, payload: Dictionary) -> void:
    var entry := {
        "id": event_id,
        "payload": payload.duplicate(true)
    }
    template_events.append(entry)
    if event_id == StringName("close_menu"):
        template_close_result = manager.pop_screen()

func _build_settings_template_content() -> Dictionary:
    return {
        StringName("title"): {
            StringName("fallback"): "Settings"
        },
        StringName("description"): {
            StringName("fallback"): "Adjust gameplay and audio options."
        },
        StringName("sections"): [
            {
                "id": "display_section",
                "title": {
                    "fallback": "Display"
                },
                "controls": [
                    {
                        "type": "toggle",
                        "id": "toggle_fullscreen",
                        "text": {
                            "fallback": "Full Screen"
                        },
                        "value": false,
                        "event": "toggle_fullscreen"
                    },
                    {
                        "type": "button",
                        "id": "show_resolution",
                        "text": {
                            "fallback": "Change Resolution"
                        },
                        "event": "show_resolution"
                    }
                ]
            },
            {
                "id": "audio_section",
                "title": {
                    "fallback": "Audio"
                },
                "controls": [
                    {
                        "type": "slider",
                        "id": "adjust_music_volume",
                        "text": {
                            "fallback": "Music Volume"
                        },
                        "min": 0.0,
                        "max": 1.0,
                        "step": 0.05,
                        "value": 0.8,
                        "event": "adjust_music_volume"
                    }
                ]
            }
        ],
        StringName("actions"): [
            {
                "id": "apply_changes",
                "text": {
                    "fallback": "Apply"
                },
                "event": "apply_changes"
            },
            {
                "id": "close_menu",
                "text": {
                    "fallback": "Close"
                },
                "event": "close_menu"
            }
        ]
    }
