extends "res://addons/gut/test.gd"

const ThemeServicePath: String = "res://UI/Theme/ThemeService.gd"
const LocalizationPath: String = "res://UI/Theme/LocalizationHelper.gd"
const InputServicePath: String = "res://InputService/InputService.gd"
const RebindPanelScenePath: String = "res://UI/Rebind/InputRebindPanel.tscn"

var theme_service: _ThemeService
var localization: _ThemeLocalization
var input_service: _InputService
var settings_stub: SettingsServiceStub
var save_stub: SaveServiceStub
var panel_scene: PackedScene

class SettingsServiceStub extends Node:
    var store: Dictionary[StringName, Variant] = {}
    var saved: bool = false

    func set_value(key: StringName, value: Variant) -> void:
        store[key] = value

    func get_value(key: StringName, default_value: Variant = null) -> Variant:
        return store.get(key, default_value)

    func save() -> void:
        saved = true

class SaveServiceStub extends Node:
    func register_saveable(_obj: Object) -> void:
        pass

func before_each() -> void:
    panel_scene = load(RebindPanelScenePath)

    theme_service = load(ThemeServicePath).new()
    theme_service.name = "ThemeService"
    get_tree().root.add_child(theme_service)
    await theme_service.ready

    localization = load(LocalizationPath).new()
    localization.name = "ThemeLocalization"
    get_tree().root.add_child(localization)
    await localization.ready

    save_stub = SaveServiceStub.new()
    save_stub.name = "SaveService"
    get_tree().root.add_child(save_stub)

    input_service = load(InputServicePath).new()
    input_service.name = "InputService"
    get_tree().root.add_child(input_service)
    await input_service.ready

    settings_stub = SettingsServiceStub.new()
    settings_stub.name = "SettingsService"
    get_tree().root.add_child(settings_stub)
    await get_tree().process_frame

func after_each() -> void:
    for node in [settings_stub, input_service, save_stub, localization, theme_service]:
        if is_instance_valid(node):
            node.queue_free()
            await get_tree().process_frame

func test_rebind_updates_binding_and_settings() -> void:
    var panel: Control = panel_scene.instantiate()
    get_tree().root.add_child(panel)
    await panel.ready

    var rebind_panel := panel as _InputRebindPanel
    var action := StringName("jump")

    input_service.begin_rebind(action)
    var event := InputEventKey.new()
    event.keycode = KEY_J
    input_service._input(event)
    await get_tree().process_frame

    var key := StringName("input_bindings/%s" % action)
    assert_true(settings_stub.store.has(key))
    var display_text := rebind_panel._events_to_text(InputMap.action_get_events(action))
    assert_string_contains(display_text, "J")

    panel.queue_free()

func test_load_saved_bindings_on_ready() -> void:
    var action := StringName("ui_accept")
    InputMap.action_erase_events(action)
    var event := InputEventKey.new()
    event.keycode = KEY_ENTER
    InputMap.action_add_event(action, event)
    var serialized := [] as Array[Dictionary[StringName, Variant]]
    serialized.append({StringName("type"): StringName("key"), StringName("keycode"): KEY_ENTER} as Dictionary[StringName, Variant])
    settings_stub.store[StringName("input_bindings/%s" % action)] = serialized

    var panel: Control = panel_scene.instantiate()
    get_tree().root.add_child(panel)
    await panel.ready

    var rebind_panel := panel as _InputRebindPanel
    var text := rebind_panel._events_to_text(InputMap.action_get_events(action))
    assert_string_contains(text, "Enter")
    panel.queue_free()
