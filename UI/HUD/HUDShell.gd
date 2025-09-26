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

## Register a panel scene for later instantiation
## 
## Registers a PackedScene that can be instantiated and shown as a HUD panel.
## The scene must contain a Control node as its root.
## 
## [b]id:[/b] Unique identifier for the panel
## [b]scene:[/b] PackedScene containing the panel UI
## 
## [b]Usage:[/b]
## [codeblock]
## # Register a health bar panel
## var health_scene = preload("res://ui/panels/HealthBar.tscn")
## hud_shell.register_panel("health_bar", health_scene)
## [/codeblock]
func register_panel(id: StringName, scene: PackedScene) -> void:
    if scene == null:
        push_warning("HUDShell.register_panel: scene is null for %s" % id)
        return
    _panels[id] = scene

## Unregister a panel scene
## 
## Removes a panel from the registry and hides it if currently active.
## 
## [b]id:[/b] Unique identifier of the panel to remove
## 
## [b]Usage:[/b]
## [codeblock]
## # Remove a panel from the registry
## hud_shell.unregister_panel("health_bar")
## [/codeblock]
func unregister_panel(id: StringName) -> void:
    _panels.erase(id)
    if _active_panels.has(id):
        hide_panel(id)

## Show a registered panel
## 
## Instantiates and displays a registered panel, or updates an existing
## panel's context if already active. The panel receives context data
## and lifecycle callbacks.
## 
## [b]id:[/b] Unique identifier of the panel to show
## [b]context:[/b] Data to pass to the panel (optional)
## 
## [b]Returns:[/b] OK if successful, ERR_DOES_NOT_EXIST if panel not registered, ERR_INVALID_DATA if instantiation fails
## 
## [b]Usage:[/b]
## [codeblock]
## # Show a health bar with player data
## var context = {"player": player_node, "max_health": 100}
## hud_shell.show_panel("health_bar", context)
## [/codeblock]
func show_panel(id: StringName, context: Dictionary[StringName, Variant] = _empty_context()) -> Error:
    if not _panels.has(id):
        return ERR_DOES_NOT_EXIST
        
    # Update existing panel if already active
    if _active_panels.has(id):
        var existing_entry: PanelEntry = _active_panels[id]
        existing_entry.context = _duplicate_context(context)
        _call_panel_method(existing_entry.node, StringName("receive_context"), existing_entry.context)
        existing_entry.node.visible = true
        panel_shown.emit(id)
        return OK
    
    # Create new panel instance
    var scene: PackedScene = _panels[id]
    var instance: Node = scene.instantiate()
    if not (instance is Control):
        instance.queue_free()
        return ERR_INVALID_DATA
        
    var entry: PanelEntry = PanelEntry.new(id, instance, _duplicate_context(context))
    var root: Control = _resolve_panel_root()
    root.add_child(instance)
    _active_panels[id] = entry
    
    # Initialize the panel
    _call_panel_method(instance, StringName("receive_context"), entry.context)
    _call_panel_method(instance, StringName("on_panel_shown"), entry.context)
    entry.node.visible = true
    panel_shown.emit(id)
    return OK

## Hide and destroy a panel
## 
## Hides a currently active panel, calls its cleanup method, and removes
## it from the active panels list. The panel node is queued for deletion.
## 
## [b]id:[/b] Unique identifier of the panel to hide
## 
## [b]Returns:[/b] OK if successful, ERR_DOES_NOT_EXIST if panel not active
## 
## [b]Usage:[/b]
## [codeblock]
## # Hide a panel
## hud_shell.hide_panel("health_bar")
## [/codeblock]
func hide_panel(id: StringName) -> Error:
    if not _active_panels.has(id):
        return ERR_DOES_NOT_EXIST
        
    var entry: PanelEntry = _active_panels[id]
    entry.node.visible = false
    _call_panel_method(entry.node, StringName("on_panel_hidden"), entry.context)
    entry.node.queue_free()
    _active_panels.erase(id)
    panel_hidden.emit(id)
    return OK

## Register a texture rect to display input action glyphs
## 
## Binds a TextureRect to automatically display the appropriate input
## glyph for a given action. The glyph updates when input devices change.
## 
## [b]texture_rect:[/b] TextureRect node to display the glyph
## [b]action:[/b] Input action name to get glyph for
## [b]fallback:[/b] Texture to show if no glyph is available (optional)
## 
## [b]Usage:[/b]
## [codeblock]
## # Bind a jump button icon
## var jump_icon = $JumpButton/Icon
## hud_shell.register_action_icon(jump_icon, "jump", fallback_texture)
## [/codeblock]
func register_action_icon(texture_rect: TextureRect, action: StringName, fallback: Texture2D = null) -> void:
    if texture_rect == null:
        return
        
    var binding: IconBinding = IconBinding.new(texture_rect, action, fallback)
    _icon_bindings.append(binding)
    _update_icon(binding)

## Unregister a texture rect from input glyph binding
## 
## Removes the binding between a TextureRect and input action glyphs.
## The texture rect will no longer update automatically.
## 
## [b]texture_rect:[/b] TextureRect node to unregister
## 
## [b]Usage:[/b]
## [codeblock]
## # Remove glyph binding
## hud_shell.unregister_action_icon(jump_icon)
## [/codeblock]
func unregister_action_icon(texture_rect: TextureRect) -> void:
    for i in range(_icon_bindings.size() - 1, -1, -1):
        if _icon_bindings[i].node == texture_rect:
            _icon_bindings.remove_at(i)

## Connect to InputGlyphService events
## 
## Establishes connections to InputGlyphService signals for automatic
## glyph updates when input devices or glyphs change.
func _connect_glyph_events() -> void:
    var glyph_service: _InputGlyphService = _glyph_service()
    if glyph_service == null:
        return
        
    if glyph_service.has_signal("glyph_registered") and not glyph_service.glyph_registered.is_connected(_on_glyph_changed):
        glyph_service.glyph_registered.connect(_on_glyph_changed)
    if glyph_service.has_signal("glyph_removed") and not glyph_service.glyph_removed.is_connected(_on_glyph_changed):
        glyph_service.glyph_removed.connect(_on_glyph_changed)
    if glyph_service.has_signal("last_device_changed") and not glyph_service.last_device_changed.is_connected(_on_device_changed):
        glyph_service.last_device_changed.connect(_on_device_changed)

## Handle glyph registration/removal events
## 
## Refreshes all icon bindings when glyphs are registered or removed.
## 
## [b]_device_kind:[/b] Device type that changed (unused)
## [b]_action:[/b] Action that changed (unused)
func _on_glyph_changed(_device_kind: StringName, _action: StringName) -> void:
    _refresh_icons()

## Handle input device change events
## 
## Refreshes all icon bindings when the active input device changes.
## 
## [b]_kind:[/b] Device type that changed (unused)
## [b]_device_id:[/b] Device ID that changed (unused)
func _on_device_changed(_kind: StringName, _device_id: int) -> void:
    _refresh_icons()

## Refresh all icon bindings
## 
## Updates all registered icon bindings with current glyph textures.
func _refresh_icons() -> void:
    for binding in _icon_bindings:
        _update_icon(binding)

## Update a single icon binding
## 
## Sets the texture for an icon binding based on the current glyph
## or fallback texture if no glyph is available.
## 
## [b]binding:[/b] IconBinding to update
func _update_icon(binding: IconBinding) -> void:
    if binding.node == null:
        return
        
    var glyph_service: _InputGlyphService = _glyph_service()
    var texture: Texture2D = glyph_service.get_glyph(binding.action) if glyph_service else null
    if texture:
        binding.node.texture = texture
    else:
        binding.node.texture = binding.fallback

## Resolve the root node for panel instantiation
## 
## Returns the configured panel root node or self if no path is set.
## 
## [b]Returns:[/b] Control node to use as panel parent
func _resolve_panel_root() -> Control:
    if panel_root_path.is_empty():
        return self
        
    var node: Node = get_node_or_null(panel_root_path)
    return node if node else self

## Call a method on a panel node if it exists
## 
## Safely calls a method on a panel node, ignoring if the method doesn't exist.
## 
## [b]node:[/b] Panel node to call method on
## [b]method:[/b] Method name to call
## [b]context:[/b] Context data to pass to the method
func _call_panel_method(node: Node, method: StringName, context: Dictionary[StringName, Variant]) -> void:
    if node.has_method(method):
        node.call(method, context)

## Get the InputGlyphService singleton
## 
## Retrieves the InputGlyphService singleton for glyph operations.
## 
## [b]Returns:[/b] InputGlyphService instance or null if not found
func _glyph_service() -> _InputGlyphService:
    return get_node_or_null(INPUT_GLYPH_SERVICE_PATH) as _InputGlyphService

## Duplicate a context dictionary
## 
## Creates a shallow copy of a context dictionary for panel isolation.
## 
## [b]source:[/b] Source dictionary to copy
## 
## [b]Returns:[/b] Shallow copy of the source dictionary
func _duplicate_context(source: Dictionary[StringName, Variant]) -> Dictionary[StringName, Variant]:
    var copy: Dictionary[StringName, Variant] = {} as Dictionary[StringName, Variant]
    for key in source.keys():
        copy[key] = source[key]
    return copy

## Get an empty context dictionary
## 
## Returns a properly typed empty context dictionary.
## 
## [b]Returns:[/b] Empty Dictionary[StringName, Variant]
static func _empty_context() -> Dictionary[StringName, Variant]:
    return {} as Dictionary[StringName, Variant]
