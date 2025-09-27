extends "res://addons/gut/test.gd"

const MenuBuilderPath: String = "res://UI/Layouts/MenuBuilder.gd"
const MenuSchemaPath: String = "res://UI/Layouts/menu_schema.example.gd"
const ThemeServicePath: String = "res://UI/Theme/ThemeService.gd"
const ThemeLocalizationPath: String = "res://UI/Theme/LocalizationHelper.gd"

var theme_service: _ThemeService
var localization_service: _ThemeLocalization
var active_builder: _MenuBuilder
var active_menu: Control

var apply_invocations: int = 0
var close_invocations: int = 0
var toggle_log: Array[bool] = []
var volume_values: Array[float] = []
var last_payload: Dictionary = {}

func before_each() -> void:
    apply_invocations = 0
    close_invocations = 0
    toggle_log.clear()
    volume_values.clear()
    last_payload = {}
    active_builder = null
    active_menu = null
    theme_service = load(ThemeServicePath).new()
    theme_service.name = "ThemeService"
    get_tree().root.add_child(theme_service)
    await theme_service.ready
    localization_service = load(ThemeLocalizationPath).new()
    localization_service.name = "ThemeLocalization"
    get_tree().root.add_child(localization_service)
    await get_tree().process_frame

func after_each() -> void:
    if is_instance_valid(active_menu):
        active_menu.queue_free()
        active_menu = null
    if is_instance_valid(active_builder):
        active_builder.queue_free()
        active_builder = null
    if is_instance_valid(theme_service):
        theme_service.queue_free()
    if is_instance_valid(localization_service):
        localization_service.queue_free()
    await get_tree().process_frame

func test_build_menu_creates_sections_and_connects_actions() -> void:
    var schema_resource: Resource = load(MenuSchemaPath)
    var schema: Dictionary = schema_resource.MENU_SCHEMA.duplicate(true)
    active_builder = load(MenuBuilderPath).new()
    get_tree().root.add_child(active_builder)
    active_builder.action_callbacks = {
        StringName("apply_changes"): Callable(self, "_on_apply_changes"),
        StringName("close_menu"): Callable(self, "_on_close_menu"),
        StringName("toggle_fullscreen"): Callable(self, "_on_toggle_fullscreen"),
        StringName("adjust_music_volume"): Callable(self, "_on_adjust_music_volume"),
        StringName("show_resolution"): Callable(self, "_on_show_resolution")
    }
    active_menu = active_builder.build_menu(schema)
    assert_not_null(active_menu)
    assert_true(active_builder.get_last_error().is_empty())
    get_tree().root.add_child(active_menu)
    await get_tree().process_frame

    var title_label: Label = active_menu.get_node("Layout/HeaderSlot/TitleLabel") as Label
    assert_eq(title_label.text, "Settings")

    var action_bar: BoxContainer = active_menu.get_node("Layout/FooterSlot/ActionBar") as BoxContainer
    assert_eq(action_bar.get_child_count(), 2)

    var apply_button: Button = active_builder.get_control(StringName("apply_button")) as Button
    assert_not_null(apply_button)
    apply_button.emit_signal("pressed")
    assert_eq(apply_invocations, 1)

    var close_button: Button = active_builder.get_control(StringName("close_button")) as Button
    close_button.emit_signal("pressed")
    assert_eq(close_invocations, 1)

    var toggle_control: CheckButton = active_builder.get_control(StringName("fullscreen_toggle")) as CheckButton
    toggle_control.emit_signal("toggled", true)
    assert_eq(toggle_log.size(), 1)
    assert_true(toggle_log[0])

    var slider_control: Range = active_builder.get_control(StringName("music_volume_slider")) as Range
    slider_control.emit_signal("value_changed", 0.45)
    assert_eq(volume_values.size(), 1)
    var difference: float = abs(volume_values[0] - 0.45)
    assert_lt(difference, 0.001)
    assert_eq(last_payload.get("setting", ""), "music_volume")

func test_validate_config_reports_unknown_action() -> void:
    active_builder = load(MenuBuilderPath).new()
    var invalid_schema: Dictionary = {
        "shell_scene": "res://UI/Layouts/PanelShell.tscn",
        "sections": [
            {
                "layout": "vbox",
                "controls": [
                    {
                        "factory": "button",
                        "id": "mystery",
                        "action": "missing_action"
                    }
                ]
            }
        ],
        "actions": {}
    }
    var errors: Array[String] = active_builder.validate_config(invalid_schema)
    assert_false(errors.is_empty())
    var found: bool = false
    for message in errors:
        if message.find("missing_action") != -1:
            found = true
            break
    assert_true(found)

func test_validate_bindings_detects_missing_callback() -> void:
    active_builder = load(MenuBuilderPath).new()
    var schema: Dictionary = {
        "shell_scene": "res://UI/Layouts/PanelShell.tscn",
        "sections": [],
        "actions": {
            "apply_changes": {
                "callback": "apply_changes"
            }
        }
    }
    var errors: Array[String] = active_builder.validate_bindings(schema)
    assert_false(errors.is_empty())
    assert_true(errors[0].find("apply_changes") != -1)

func _on_apply_changes() -> void:
    apply_invocations += 1

func _on_close_menu() -> void:
    close_invocations += 1

func _on_toggle_fullscreen(enabled: bool) -> void:
    toggle_log.append(enabled)

func _on_adjust_music_volume(value: float, payload: Dictionary) -> void:
    volume_values.append(value)
    last_payload = payload

func _on_show_resolution() -> void:
    # Intentionally empty; test asserts the connection succeeds without error
    pass
