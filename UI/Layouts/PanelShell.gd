class_name _PanelShell
extends PanelContainer

const ROOT_THEME_SERVICE_PATH: NodePath = NodePath("/root/ThemeService")

@export var header_slot_path: NodePath = NodePath("Layout/HeaderSlot")
@export var body_slot_path: NodePath = NodePath("Layout/BodySlot")
@export var footer_slot_path: NodePath = NodePath("Layout/FooterSlot")

var _header_slot: Control
var _body_slot: Control
var _footer_slot: Control
var _missing_theme_logged: bool = false

func _ready() -> void:
    _resolve_slots()
    if not _ensure_theme_service():
        return
    _apply_theme()
    _connect_theme_changed()

func _exit_tree() -> void:
    var theme_service := _theme_service()
    if theme_service and theme_service.theme_changed.is_connected(_on_theme_changed):
        theme_service.theme_changed.disconnect(_on_theme_changed)

## Assign a control to the header slot.
##
## [param control] Control to add. Existing children are freed before the new control is added.
func set_header(control: Control) -> void:
    _populate_slot(_header_slot, control)

## Assign a control to the body slot.
##
## [param control] Control to add. Existing children are freed before the new control is added.
func set_body(control: Control) -> void:
    _populate_slot(_body_slot, control)

## Assign a control to the footer slot.
##
## [param control] Control to add. Existing children are freed before the new control is added.
func set_footer(control: Control) -> void:
    _populate_slot(_footer_slot, control)

## Remove all header content.
func clear_header() -> void:
    _clear_slot(_header_slot)

## Remove all body content.
func clear_body() -> void:
    _clear_slot(_body_slot)

## Remove all footer content.
func clear_footer() -> void:
    _clear_slot(_footer_slot)

## Retrieve the header slot container.
##
## [return] Header slot as a Control. Returns null if the slot could not be resolved.
func get_header_slot() -> Control:
    return _header_slot

## Retrieve the body slot container.
##
## [return] Body slot as a Control. Returns null if the slot could not be resolved.
func get_body_slot() -> Control:
    return _body_slot

## Retrieve the footer slot container.
##
## [return] Footer slot as a Control. Returns null if the slot could not be resolved.
func get_footer_slot() -> Control:
    return _footer_slot

func _resolve_slots() -> void:
    _header_slot = get_node_or_null(header_slot_path) as Control
    _body_slot = get_node_or_null(body_slot_path) as Control
    _footer_slot = get_node_or_null(footer_slot_path) as Control
    if _header_slot == null:
        push_error("PanelShell: header slot path is invalid. Ensure Layout/HeaderSlot exists or update the exported path.")
    if _body_slot == null:
        push_error("PanelShell: body slot path is invalid. Ensure Layout/BodySlot exists or update the exported path.")
    if _footer_slot == null:
        push_error("PanelShell: footer slot path is invalid. Ensure Layout/FooterSlot exists or update the exported path.")

func _populate_slot(slot: Control, control: Control) -> void:
    if slot == null or control == null:
        return
    _clear_slot(slot)
    if control.get_parent():
        control.get_parent().remove_child(control)
    slot.add_child(control)

func _clear_slot(slot: Control) -> void:
    if slot == null:
        return
    for child in slot.get_children():
        if child is Node:
            (child as Node).queue_free()

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
    var surface_color := theme_service.get_color(StringName("surface"))
    var border_color := theme_service.get_color(StringName("surface_alt"))
    var padding := theme_service.get_spacing(StringName("lg"))
    var separation := theme_service.get_spacing(StringName("md"))
    var style := StyleBoxFlat.new()
    style.bg_color = surface_color
    style.border_color = border_color
    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1
    style.set_corner_radius_all(6)
    style.content_margin_left = padding
    style.content_margin_right = padding
    style.content_margin_top = padding
    style.content_margin_bottom = padding
    add_theme_stylebox_override("panel", style)
    if _body_slot:
        _body_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _body_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var layout := _header_slot.get_parent() if _header_slot else null
    if layout is BoxContainer:
        layout.add_theme_constant_override("separation", int(separation))

func _theme_service() -> _ThemeService:
    return get_node_or_null(ROOT_THEME_SERVICE_PATH) as _ThemeService

func _ensure_theme_service() -> bool:
    if _theme_service() == null:
        if not _missing_theme_logged:
            _missing_theme_logged = true
            push_error("PanelShell: ThemeService autoload not found. Add ThemeService before instantiating PanelShell.")
        return false
    return true
