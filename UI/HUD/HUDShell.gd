class_name _HUDShell
extends Control

## HUDShell orchestrates pluggable HUD panels and action glyph bindings.

signal panel_shown(id: StringName)
signal panel_hidden(id: StringName)

@export var panel_root_path: NodePath

var _panels: Dictionary[StringName, PackedScene] = {}
var _active_panels: Dictionary[StringName, PanelEntry] = {}
var _icon_bindings: Array[IconBinding] = []
const INPUT_GLYPH_SERVICE_PATH: NodePath = NodePath("/root/InputGlyphService")

class PanelEntry extends RefCounted:
    var id: StringName
    var node: Control
    var context: Dictionary[StringName, Variant]
    var created_ms: int

    func _init(panel_id: StringName, panel_node: Control, panel_context: Dictionary[StringName, Variant]) -> void:
        id = panel_id
        node = panel_node
        context = panel_context
        created_ms = Time.get_ticks_msec()

class IconBinding extends RefCounted:
    var node: TextureRect
    var action: StringName
    var fallback: Texture2D

    func _init(binding_node: TextureRect, binding_action: StringName, binding_fallback: Texture2D) -> void:
        node = binding_node
        action = binding_action
        fallback = binding_fallback

func _ready() -> void:
    _connect_glyph_events()

func register_panel(id: StringName, scene: PackedScene) -> void:
    if scene == null:
        push_warning("HUDShell.register_panel: scene is null for %s" % id)
        return
    _panels[id] = scene

func unregister_panel(id: StringName) -> void:
    _panels.erase(id)
    if _active_panels.has(id):
        hide_panel(id)

func show_panel(id: StringName, context: Dictionary[StringName, Variant] = _empty_context()) -> Error:
    if not _panels.has(id):
        return ERR_DOES_NOT_EXIST
    if _active_panels.has(id):
        var entry := _active_panels[id]
        entry.context = _duplicate_context(context)
        _call_panel_method(entry.node, StringName("receive_context"), entry.context)
        entry.node.visible = true
        panel_shown.emit(id)
        return OK
    var scene := _panels[id]
    var instance := scene.instantiate()
    if not (instance is Control):
        instance.queue_free()
        return ERR_INVALID_DATA
    var entry := PanelEntry.new(id, instance, _duplicate_context(context))
    var root := _resolve_panel_root()
    root.add_child(instance)
    _active_panels[id] = entry
    _call_panel_method(instance, StringName("receive_context"), entry.context)
    _call_panel_method(instance, StringName("on_panel_shown"), entry.context)
    entry.node.visible = true
    panel_shown.emit(id)
    return OK

func hide_panel(id: StringName) -> Error:
    if not _active_panels.has(id):
        return ERR_DOES_NOT_EXIST
    var entry := _active_panels[id]
    entry.node.visible = false
    _call_panel_method(entry.node, StringName("on_panel_hidden"), entry.context)
    entry.node.queue_free()
    _active_panels.erase(id)
    panel_hidden.emit(id)
    return OK

func register_action_icon(texture_rect: TextureRect, action: StringName, fallback: Texture2D = null) -> void:
    if texture_rect == null:
        return
    var binding := IconBinding.new(texture_rect, action, fallback)
    _icon_bindings.append(binding)
    _update_icon(binding)

func unregister_action_icon(texture_rect: TextureRect) -> void:
    for i in range(_icon_bindings.size())[::-1]:
        if _icon_bindings[i].node == texture_rect:
            _icon_bindings.remove_at(i)

func _connect_glyph_events() -> void:
    var glyph_service := _glyph_service()
    if glyph_service == null:
        return
    if glyph_service.has_signal("glyph_registered") and not glyph_service.glyph_registered.is_connected(_on_glyph_changed):
        glyph_service.glyph_registered.connect(_on_glyph_changed)
    if glyph_service.has_signal("glyph_removed") and not glyph_service.glyph_removed.is_connected(_on_glyph_changed):
        glyph_service.glyph_removed.connect(_on_glyph_changed)
    if glyph_service.has_signal("last_device_changed") and not glyph_service.last_device_changed.is_connected(_on_device_changed):
        glyph_service.last_device_changed.connect(_on_device_changed)

func _on_glyph_changed(_device_kind: StringName, _action: StringName) -> void:
    _refresh_icons()

func _on_device_changed(_kind: StringName, _device_id: int) -> void:
    _refresh_icons()

func _refresh_icons() -> void:
    for binding in _icon_bindings:
        _update_icon(binding)

func _update_icon(binding: IconBinding) -> void:
    if binding.node == null:
        return
    var glyph_service := _glyph_service()
    var texture := glyph_service.get_glyph(binding.action) if glyph_service else null
    if texture:
        binding.node.texture = texture
    else:
        binding.node.texture = binding.fallback

func _resolve_panel_root() -> Control:
    if panel_root_path.is_empty():
        return self
    var node := get_node_or_null(panel_root_path)
    return node if node else self

func _call_panel_method(node: Node, method: StringName, context: Dictionary[StringName, Variant]) -> void:
    if node.has_method(method):
        node.call(method, context)

func _glyph_service() -> _InputGlyphService:
    return get_node_or_null(INPUT_GLYPH_SERVICE_PATH) as _InputGlyphService

func _duplicate_context(source: Dictionary[StringName, Variant]) -> Dictionary[StringName, Variant]:
    var copy := {} as Dictionary[StringName, Variant]
    for key in source.keys():
        copy[key] = source[key]
    return copy

static func _empty_context() -> Dictionary[StringName, Variant]:
    return {} as Dictionary[StringName, Variant]
