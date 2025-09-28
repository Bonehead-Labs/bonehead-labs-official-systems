class_name _UITemplate
extends Control

## UITemplate provides a reusable base for scene-driven UI screens.
##
## Templates are Godot scenes composed visually in the editor. They expose
## `apply_content` for data population, emit `template_event` when interactions
## occur, and relay updates through EventBus when available. Derived templates
## are encouraged to organise structure in the editor and keep scripts focused on
## binding data.
##
## [b]Usage:[/b]
## [codeblock]
## var dialog := load("res://UI/Templates/DialogTemplate.tscn").instantiate()
## dialog.template_id = StringName("settings_dialog")
## dialog.apply_content({
##     StringName("title"): {"text": "Settings"},
##     StringName("actions"): [
##         {"id": "close", "text": {"fallback": "Close"}}
##     ]
## })
## dialog.template_event.connect(_on_template_event)
## [/codeblock]
signal template_event(event_id: StringName, payload: Dictionary)
signal template_ready(template: _UITemplate)

@export var template_id: StringName

var _theme_service: _ThemeService
var _theme_localization: _ThemeLocalization
var _event_bus: _EventBus
var _pending_content: Dictionary = {}

func _ready() -> void:
    _refresh_services()
    _subscribe_theme_changes()
    template_ready.emit(self)
    _on_template_ready()
    _consume_pending_content()

## Apply content data to the template.
##
## Derived classes override `_apply_content` to map incoming dictionaries to the
## scene structure. The base implementation guards against null data and ensures
## localisation helpers are refreshed before binding.
##
## [b]content:[/b] Dictionary of template data.
func apply_content(content: Dictionary) -> void:
    if content == null or content.is_empty():
        return
    _pending_content = content.duplicate(true)
    if not is_inside_tree():
        return
    _consume_pending_content()

## Hook for derived templates to react when added to the scene tree.
func _on_template_ready() -> void:
    pass

## Internal method overridden by derived templates to bind data.
func _apply_content(_content: Dictionary) -> void:
    pass

## Emit a template event and publish to EventBus when present.
##
## [b]event_id:[/b] Identifier describing the interaction.
## [b]payload:[/b] Additional event context (optional).
func emit_template_event(event_id: StringName, payload: Dictionary = {}) -> void:
    template_event.emit(event_id, payload)
    if _event_bus == null:
        return
    var envelope: Dictionary[StringName, Variant] = {
        StringName("template_id"): template_id,
        StringName("event_id"): event_id,
        StringName("payload"): payload.duplicate(true)
    }
    _event_bus.pub(_EventTopics.UI_TEMPLATE_EVENT, envelope)

## Convenience helper to publish events using the shared EventBus.
##
## [b]topic:[/b] Event topic to publish.
## [b]payload:[/b] Event payload dictionary.
func publish_event(topic: StringName, payload: Dictionary) -> void:
    if _event_bus == null:
        return
    _event_bus.pub(topic, payload)

func _subscribe_theme_changes() -> void:
    if _theme_service == null:
        return
    if not _theme_service.theme_changed.is_connected(_on_theme_changed):
        _theme_service.theme_changed.connect(_on_theme_changed)

## Called when ThemeService signals a change so templates can refresh styling.
func _on_theme_changed() -> void:
    pass

func _consume_pending_content() -> void:
    if _pending_content.is_empty():
        return
    var data: Dictionary = _pending_content.duplicate(true)
    _pending_content.clear()
    _refresh_services()
    _apply_content(data)

func _refresh_services() -> void:
    var tree: SceneTree = _scene_tree()
    if tree == null:
        return
    var root: Node = tree.root
    if root == null:
        return
    _theme_service = root.get_node_or_null(NodePath("/root/ThemeService")) as _ThemeService
    _theme_localization = root.get_node_or_null(NodePath("/root/ThemeLocalization")) as _ThemeLocalization
    _event_bus = root.get_node_or_null(NodePath("/root/EventBus")) as _EventBus

func _scene_tree() -> SceneTree:
    var loop: MainLoop = Engine.get_main_loop()
    if loop is SceneTree:
        return loop as SceneTree
    return null

## Resolve a text descriptor through ThemeLocalization.
##
## [b]descriptor:[/b] String, number, or dictionary containing `token`/`fallback`.
##
## [b]Returns:[/b] Resolved string ready for display.
func resolve_text(descriptor: Variant) -> String:
    if descriptor is String:
        return descriptor
    if descriptor is StringName:
        return String(descriptor)
    if descriptor is int or descriptor is float:
        return str(descriptor)
    if descriptor is Dictionary:
        var data: Dictionary = descriptor as Dictionary
        var fallback: String = String(data.get(StringName("fallback"), ""))
        var token: StringName = data.get(StringName("token"), StringName()) as StringName
        if token == StringName():
            return String(data.get(StringName("text"), fallback))
        if _theme_localization != null:
            var translated: String = _theme_localization.translate(token, fallback)
            if not translated.is_empty():
                return translated
        return fallback
    return ""
