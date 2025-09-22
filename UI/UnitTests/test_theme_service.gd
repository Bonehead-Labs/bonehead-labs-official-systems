extends "res://addons/gut/test.gd"

const ThemeServicePath: String = "res://UI/Theme/ThemeService.gd"
const LocalizationHelperPath: String = "res://UI/Theme/LocalizationHelper.gd"

var service: _ThemeService
var localization: _ThemeLocalization

func before_each() -> void:
    service = load(ThemeServicePath).new()
    service.name = "ThemeService"
    get_tree().root.add_child(service)
    await service.ready
    localization = load(LocalizationHelperPath).new()
    localization.name = "ThemeLocalization"
    get_tree().root.add_child(localization)
    await localization.ready

func after_each() -> void:
    if is_instance_valid(service):
        service.queue_free()
        await get_tree().process_frame
    if is_instance_valid(localization):
        localization.queue_free()
        await get_tree().process_frame

func test_default_color_lookup() -> void:
    var primary := service.get_color(StringName("accent"))
    assert_true(primary is Color)
    assert_gt(primary.a, 0.0)

func test_high_contrast_toggle_changes_color() -> void:
    var default_color := service.get_color(StringName("background"))
    service.enable_high_contrast(true)
    var contrast_color := service.get_color(StringName("background"))
    assert_ne(default_color, contrast_color)
    assert_true(service.is_high_contrast_enabled())

func test_spacing_and_fonts() -> void:
    assert_eq(service.get_spacing(StringName("md")), 12.0)
    assert_eq(service.get_font_size(StringName("body")), 16)

func test_focus_stylebox_reflects_high_contrast() -> void:
    var default_style := service.get_focus_stylebox()
    assert_true(default_style is StyleBoxFlat)
    var default_color := (default_style as StyleBoxFlat).border_color
    service.enable_high_contrast(true)
    var contrast_style := service.get_focus_stylebox()
    var contrast_color := (contrast_style as StyleBoxFlat).border_color
    assert_ne(default_color, contrast_color)

func test_localization_helper_falls_back_to_default() -> void:
    var token := StringName("ui/example/token")
    var translated := localization.translate(token, "Fallback")
    assert_eq(translated, "Fallback")
    var formatted := localization.translate_with_args(token, {"value": 5}, "Score: %{value}")
    assert_eq(formatted, "Score: 5")
