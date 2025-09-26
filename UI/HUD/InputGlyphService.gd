class_name _InputGlyphService
extends Node

## InputGlyphService manages action glyph textures per device kind.

signal glyph_registered(device_kind: StringName, action: StringName)
signal glyph_removed(device_kind: StringName, action: StringName)
signal last_device_changed(kind: StringName, device_id: int)

var _glyphs: Dictionary = {}
var _last_device_kind: StringName = StringName("keyboard")
var _last_device_id: int = 0
const INPUT_SERVICE_PATH: NodePath = NodePath("/root/InputService")

func _ready() -> void:
    _connect_input_service()

## Register a glyph texture for a device and action
## 
## Associates a texture with a specific input action for a device type.
## The glyph will be used when displaying input prompts for that action.
## 
## [b]device_kind:[/b] Type of input device ("keyboard", "gamepad", "mouse")
## [b]action:[/b] Input action name
## [b]texture:[/b] Texture to display for this action/device combination
## 
## [b]Usage:[/b]
## [codeblock]
## # Register keyboard glyph for jump action
## var jump_texture = preload("res://ui/glyphs/keyboard_space.png")
## glyph_service.register_glyph("keyboard", "jump", jump_texture)
## [/codeblock]
func register_glyph(device_kind: StringName, action: StringName, texture: Texture2D) -> void:
    if texture == null:
        push_warning("InputGlyphService.register_glyph: texture is null for %s/%s" % [device_kind, action])
        return
        
    var table: Dictionary[StringName, Texture2D] = _glyphs.get(device_kind, {} as Dictionary[StringName, Texture2D]) as Dictionary[StringName, Texture2D]
    table[action] = texture
    _glyphs[device_kind] = table
    emit_signal("glyph_registered", device_kind, action)

## Unregister a glyph texture
## 
## Removes the association between a device/action and its glyph texture.
## 
## [b]device_kind:[/b] Type of input device
## [b]action:[/b] Input action name
## 
## [b]Usage:[/b]
## [codeblock]
## # Remove glyph for jump action
## glyph_service.unregister_glyph("keyboard", "jump")
## [/codeblock]
func unregister_glyph(device_kind: StringName, action: StringName) -> void:
    if not _glyphs.has(device_kind):
        return
        
    var table: Dictionary = _glyphs[device_kind]
    if table.erase(action):
        emit_signal("glyph_removed", device_kind, action)
    if table.is_empty():
        _glyphs.erase(device_kind)

## Get glyph texture for an action
## 
## Retrieves the glyph texture for a specific action and device type.
## If no device type is specified, uses the last active device.
## 
## [b]action:[/b] Input action name
## [b]device_kind:[/b] Device type (optional, defaults to last active device)
## 
## [b]Returns:[/b] Glyph texture or null if not found
## 
## [b]Usage:[/b]
## [codeblock]
## # Get glyph for jump action
## var jump_glyph = glyph_service.get_glyph("jump")
## if jump_glyph:
##     button.texture = jump_glyph
## [/codeblock]
func get_glyph(action: StringName, device_kind: StringName = StringName()) -> Texture2D:
    var kind: StringName = device_kind if device_kind != StringName() else _last_device_kind
    var table: Dictionary = _glyphs.get(kind, {})
    if table == null:
        return null
    return table.get(action, null)

## Get the last active device type
## 
## Returns the type of the most recently used input device.
## 
## [b]Returns:[/b] Device type string ("keyboard", "gamepad", "mouse")
func get_last_device_kind() -> StringName:
    return _last_device_kind

## Get the last active device ID
## 
## Returns the ID of the most recently used input device.
## 
## [b]Returns:[/b] Device ID number
func get_last_device_id() -> int:
    return _last_device_id

## Connect to InputService for device tracking
## 
## Establishes connection to InputService to track the last active
## input device for automatic glyph selection.
func _connect_input_service() -> void:
    var input_service: Node = get_node_or_null(INPUT_SERVICE_PATH)
    if input_service == null:
        return
        
    if input_service.has_signal("last_active_device_changed") and not input_service.last_active_device_changed.is_connected(_on_last_device_changed):
        input_service.last_active_device_changed.connect(_on_last_device_changed)

## Handle input device change events
## 
## Updates the tracked device information when the active input
## device changes and notifies listeners.
## 
## [b]kind:[/b] New device type
## [b]device_id:[/b] New device ID
func _on_last_device_changed(kind: String, device_id: int) -> void:
    _last_device_kind = StringName(kind)
    _last_device_id = device_id
    emit_signal("last_device_changed", _last_device_kind, _last_device_id)
