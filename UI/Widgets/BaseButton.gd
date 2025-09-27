extends Button

const ROOT_THEME_SERVICE_PATH: NodePath = NodePath("/root/ThemeService")
const ROOT_LOCALIZATION_PATH: NodePath = NodePath("/root/ThemeLocalization")

@export var label_token: StringName
@export var label_fallback: String = ""
@export var accent_color_token: StringName = StringName("accent")
@export var size_token: StringName = StringName("body")

var _missing_theme_logged: bool = false
var _missing_localization_logged: bool = false

func _ready() -> void:
    if not _ensure_theme_service():
        return
    _apply_theme()
    _update_text()
    _connect_theme_changed()

func _exit_tree() -> void:
    var theme_service := _theme_service()
    if theme_service and theme_service.theme_changed.is_connected(_on_theme_changed):
        theme_service.theme_changed.disconnect(_on_theme_changed)

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
        var font_size := theme_service.get_font_size(size_token)
        add_theme_font_size_override("font_size", font_size)
        add_theme_color_override("font_color", theme_service.get_color(StringName("text_primary")))
        add_theme_color_override("font_color_hover", theme_service.get_color(accent_color_token))
        add_theme_stylebox_override("focus", theme_service.get_focus_stylebox())

func _update_text() -> void:
    var localization := _localization()
    if label_token != StringName() and localization:
        text = localization.translate(label_token, label_fallback)
    elif not label_fallback.is_empty():
        text = label_fallback
    elif label_token != StringName() and localization == null:
        _report_missing_localization()

func _theme_service() -> _ThemeService:
    return get_node_or_null(ROOT_THEME_SERVICE_PATH) as _ThemeService

func _localization() -> _ThemeLocalization:
    return get_node_or_null(ROOT_LOCALIZATION_PATH) as _ThemeLocalization

func _ensure_theme_service() -> bool:
    if _theme_service() == null:
        if not _missing_theme_logged:
            _missing_theme_logged = true
            push_error("BaseButton: ThemeService autoload not found. Add ThemeService before instantiating BaseButton.")
        return false
    return true

func _report_missing_localization() -> void:
    if _missing_localization_logged:
        return
    _missing_localization_logged = true
    push_error("BaseButton: ThemeLocalization autoload not found. Token translation is unavailable.")
