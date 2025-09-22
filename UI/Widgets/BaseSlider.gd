extends HSlider

const ROOT_THEME_SERVICE_PATH: NodePath = NodePath("/root/ThemeService")

@export var accent_color_token: StringName = StringName("accent")
@export var track_color_token: StringName = StringName("surface_alt")

func _ready() -> void:
    _apply_theme()
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

func _apply_theme() -> void:
    var theme_service := _theme_service()
    if theme_service == null:
        return
    var accent := theme_service.get_color(accent_color_token)
    var track := theme_service.get_color(track_color_token)
    add_theme_stylebox_override("grabber", _create_circle(accent))
    add_theme_stylebox_override("grabber_highlight", _create_circle(accent.lightened(0.1)))
    add_theme_stylebox_override("slider", _create_bar(track, accent))

func _create_circle(color: Color) -> StyleBox:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(999)
    style.content_margin_left = 6
    style.content_margin_right = 6
    style.content_margin_top = 6
    style.content_margin_bottom = 6
    return style

func _create_bar(track: Color, accent: Color) -> StyleBox:
    var style := StyleBoxFlat.new()
    style.bg_color = track
    style.border_color = accent
    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1
    style.set_corner_radius_all(4)
    return style

func _theme_service() -> _ThemeService:
    return get_node_or_null(ROOT_THEME_SERVICE_PATH) as _ThemeService
