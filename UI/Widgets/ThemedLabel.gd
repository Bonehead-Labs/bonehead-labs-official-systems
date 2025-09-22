extends Label

@export var label_token: StringName
@export var label_fallback: String = ""
@export var size_token: StringName = StringName("body")
@export var color_token: StringName = StringName("text_primary")

func _ready() -> void:
    _apply_theme()
    _update_text()
    _connect_theme_changed()

func _connect_theme_changed() -> void:
    var theme_service := _theme_service()
    if theme_service and not theme_service.theme_changed.is_connected(_on_theme_changed):
        theme_service.theme_changed.connect(_on_theme_changed)

func _on_theme_changed() -> void:
    _apply_theme()
    _update_text()

func _apply_theme() -> void:
    var theme_service := _theme_service()
    if theme_service:
        add_theme_font_size_override("font_size", theme_service.get_font_size(size_token))
        add_theme_color_override("font_color", theme_service.get_color(color_token))

func _update_text() -> void:
    var localization := _localization()
    if label_token != StringName() and localization:
        text = localization.translate(label_token, label_fallback)
    elif not label_fallback.is_empty():
        text = label_fallback

func _theme_service():
    return Engine.get_singleton("ThemeService") if Engine.has_singleton("ThemeService") else null

func _localization():
    return Engine.get_singleton("ThemeLocalization") if Engine.has_singleton("ThemeLocalization") else null
