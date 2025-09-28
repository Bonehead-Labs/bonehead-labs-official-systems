class_name _HUDOverlayTemplate
extends _UITemplate

const KEY_OBJECTIVE: StringName = StringName("objective")
const KEY_STATUS: StringName = StringName("status")
const KEY_NOTIFICATIONS: StringName = StringName("notifications")
const KEY_BARS: StringName = StringName("bars")

@export var objective_label_path: NodePath = NodePath("Root/LeftColumn/Objective")
@export var status_label_path: NodePath = NodePath("Root/LeftColumn/Status")
@export var notification_container_path: NodePath = NodePath("Root/RightColumn/Notifications")
@export var bar_container_path: NodePath = NodePath("Root/BottomColumn/Bars")

var _objective_label: Label
var _status_label: Label
var _notification_container: VBoxContainer
var _bar_container: VBoxContainer

func _on_template_ready() -> void:
    _objective_label = get_node_or_null(objective_label_path) as Label
    _status_label = get_node_or_null(status_label_path) as Label
    _notification_container = get_node_or_null(notification_container_path) as VBoxContainer
    _bar_container = get_node_or_null(bar_container_path) as VBoxContainer

func _apply_content(content: Dictionary) -> void:
    if _objective_label != null and content.has(KEY_OBJECTIVE):
        _UITemplateDataBinder.apply_text(_objective_label, content[KEY_OBJECTIVE], Callable(self, "resolve_text"))
    if _status_label != null and content.has(KEY_STATUS):
        _UITemplateDataBinder.apply_text(_status_label, content[KEY_STATUS], Callable(self, "resolve_text"))
    if _notification_container != null:
        var notifications: Array = []
        if content.get(KEY_NOTIFICATIONS) is Array:
            notifications = content[KEY_NOTIFICATIONS]
        _UITemplateDataBinder.populate_container(_notification_container, notifications, Callable(self, "_create_notification"))
    if _bar_container != null:
        var bars: Array = []
        if content.get(KEY_BARS) is Array:
            bars = content[KEY_BARS]
        _UITemplateDataBinder.populate_container(_bar_container, bars, Callable(self, "_create_bar"))

func _create_notification(descriptor: Variant) -> Node:
    var label: Label = _WidgetFactory.create_label({})
    _UITemplateDataBinder.apply_text(label, descriptor, Callable(self, "resolve_text"))
    return label

func _create_bar(descriptor: Variant) -> Node:
    var container: VBoxContainer = _WidgetFactory.create_vbox({}) as VBoxContainer
    container.add_theme_constant_override(StringName("separation"), 2)
    var label: Label = _WidgetFactory.create_label({})
    container.add_child(label)
    var bar: ProgressBar = ProgressBar.new()
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    container.add_child(bar)
    if descriptor is Dictionary:
        var data: Dictionary = descriptor as Dictionary
        if data.has(StringName("label")):
            _UITemplateDataBinder.apply_text(label, data[StringName("label")], Callable(self, "resolve_text"))
        elif data.has(StringName("text")):
            _UITemplateDataBinder.apply_text(label, data[StringName("text")], Callable(self, "resolve_text"))
        else:
            label.visible = false
        var bar_config: Dictionary = {
            StringName("value"): data.get(StringName("value"), 0.0),
            StringName("max" ): data.get(StringName("max"), 1.0)
        }
        _UITemplateDataBinder.apply_progress(bar, bar_config)
    else:
        label.visible = false
    return container
