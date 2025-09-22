class_name _InputGlyphService
extends Node

## InputGlyphService manages action glyph textures per device kind.

signal glyph_registered(device_kind: StringName, action: StringName)
signal glyph_removed(device_kind: StringName, action: StringName)
signal last_device_changed(kind: StringName, device_id: int)

var _glyphs: Dictionary[StringName, Dictionary[StringName, Texture2D]] = {}
var _last_device_kind: StringName = StringName("keyboard")
var _last_device_id: int = 0
const INPUT_SERVICE_PATH: NodePath = NodePath("/root/InputService")

func _ready() -> void:
    _connect_input_service()

func register_glyph(device_kind: StringName, action: StringName, texture: Texture2D) -> void:
    if texture == null:
        push_warning("InputGlyphService.register_glyph: texture is null for %s/%s" % [device_kind, action])
        return
    var table := _glyphs.get(device_kind, {} as Dictionary[StringName, Texture2D]) as Dictionary[StringName, Texture2D]
    table[action] = texture
    _glyphs[device_kind] = table
    emit_signal("glyph_registered", device_kind, action)

func unregister_glyph(device_kind: StringName, action: StringName) -> void:
    if not _glyphs.has(device_kind):
        return
    var table := _glyphs[device_kind]
    if table.erase(action):
        emit_signal("glyph_removed", device_kind, action)
    if table.is_empty():
        _glyphs.erase(device_kind)

func get_glyph(action: StringName, device_kind: StringName = StringName()) -> Texture2D:
    var kind := device_kind if device_kind != StringName() else _last_device_kind
    var table := _glyphs.get(kind, null)
    if table == null:
        return null
    return table.get(action, null)

func get_last_device_kind() -> StringName:
    return _last_device_kind

func get_last_device_id() -> int:
    return _last_device_id

func _connect_input_service() -> void:
    var input_service := get_node_or_null(INPUT_SERVICE_PATH)
    if input_service == null:
        return
    if input_service.has_signal("last_active_device_changed") and not input_service.last_active_device_changed.is_connected(_on_last_device_changed):
        input_service.last_active_device_changed.connect(_on_last_device_changed)

func _on_last_device_changed(kind: String, device_id: int) -> void:
    _last_device_kind = StringName(kind)
    _last_device_id = device_id
    emit_signal("last_device_changed", _last_device_kind, _last_device_id)
