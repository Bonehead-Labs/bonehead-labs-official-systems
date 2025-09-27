extends "res://addons/gut/test.gd"

const ThemeServicePath: String = "res://UI/Theme/ThemeService.gd"
const LocalizationHelperPath: String = "res://UI/Theme/LocalizationHelper.gd"
const WidgetFactory = preload("res://UI/Widgets/WidgetFactory.gd")

var theme_service: _ThemeService
var localization: _ThemeLocalization

func before_each() -> void:
    theme_service = load(ThemeServicePath).new()
    theme_service.name = "ThemeService"
    get_tree().root.add_child(theme_service)
    await theme_service.ready
    localization = load(LocalizationHelperPath).new()
    localization.name = "ThemeLocalization"
    get_tree().root.add_child(localization)
    await localization.ready

func after_each() -> void:
    if is_instance_valid(theme_service):
        theme_service.queue_free()
        await get_tree().process_frame
    if is_instance_valid(localization):
        localization.queue_free()
        await get_tree().process_frame

func test_button_uses_high_contrast_colors() -> void:
    var button := WidgetFactory.create_button({
        "label_token": StringName("ui/button/ok"),
        "label_fallback": "OK"
    })
    get_tree().root.add_child(button)
    assert_eq(button.text, "OK")
    var default_color := button.get_theme_color("font_color")
    theme_service.enable_high_contrast(true)
    await get_tree().process_frame
    var contrast_color := button.get_theme_color("font_color")
    assert_neq(default_color, contrast_color)
    button.queue_free()

func test_toggle_receives_focus_style() -> void:
    var toggle := WidgetFactory.create_toggle({"label_fallback": "Toggle"})
    get_tree().root.add_child(toggle)
    var focus_style := toggle.get_theme_stylebox("focus")
    assert_true(focus_style is StyleBox)
    toggle.queue_free()

func test_slider_applies_theme_colors() -> void:
    var slider := WidgetFactory.create_slider({})
    get_tree().root.add_child(slider)
    var grabber := slider.get_theme_stylebox("grabber")
    assert_true(grabber is StyleBox)
    slider.queue_free()

func test_label_translates_text() -> void:
    var label := WidgetFactory.create_label({
        "label_token": StringName("ui/label/score"),
        "label_fallback": "Score"
    })
    get_tree().root.add_child(label)
    assert_eq(label.text, "Score")
    label.queue_free()

func test_panel_uses_theme_surface() -> void:
    var panel := WidgetFactory.create_panel({})
    get_tree().root.add_child(panel)
    var style := panel.get_theme_stylebox("panel")
    assert_true(style is StyleBox)
    panel.queue_free()

func test_layout_helpers_apply_spacing() -> void:
    var vbox := WidgetFactory.create_vbox({})
    get_tree().root.add_child(vbox)
    assert_gt(vbox.get_theme_constant("separation"), 0)
    vbox.queue_free()
    var hbox := WidgetFactory.create_hbox({})
    get_tree().root.add_child(hbox)
    assert_gt(hbox.get_theme_constant("separation"), 0)
    hbox.queue_free()

func test_factory_reports_missing_theme_service() -> void:
    theme_service.queue_free()
    await get_tree().process_frame
    var panel := WidgetFactory.create_panel({})
    assert_true(panel is PanelContainer)
    var last_error := WidgetFactory.get_last_error()
    assert_true(last_error.begins_with("WidgetFactory.create_panel"))
    panel.queue_free()

func test_factory_clears_error_when_dependencies_return() -> void:
    WidgetFactory.create_panel({})
    assert_eq(WidgetFactory.get_last_error(), "")
