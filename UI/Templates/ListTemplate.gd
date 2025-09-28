class_name _ListTemplate
extends _UITemplate

const KEY_TITLE: StringName = StringName("title")
const KEY_DESCRIPTION: StringName = StringName("description")
const KEY_ITEMS: StringName = StringName("items")

@export var title_label_path: NodePath = NodePath("Header/Title")
@export var description_label_path: NodePath = NodePath("Header/Description")
@export var items_container_path: NodePath = NodePath("Items/ItemList")

var _title_label: Label
var _description_label: Label
var _items_container: VBoxContainer

func _on_template_ready() -> void:
    _title_label = get_node_or_null(title_label_path) as Label
    _description_label = get_node_or_null(description_label_path) as Label
    _items_container = get_node_or_null(items_container_path) as VBoxContainer

func _apply_content(content: Dictionary) -> void:
    if _title_label != null and content.has(KEY_TITLE):
        _UITemplateDataBinder.apply_text(_title_label, content[KEY_TITLE], Callable(self, "resolve_text"))
    if _description_label != null and content.has(KEY_DESCRIPTION):
        _UITemplateDataBinder.apply_text(_description_label, content[KEY_DESCRIPTION], Callable(self, "resolve_text"))
    _populate_items(content.get(KEY_ITEMS, []))

func _populate_items(items_variant: Variant) -> void:
    if _items_container == null:
        return
    var items: Array = []
    if items_variant is Array:
        items = items_variant as Array
    _UITemplateDataBinder.populate_container(_items_container, items, Callable(self, "_create_item"))

func _create_item(descriptor: Variant) -> Node:
    if descriptor is Dictionary:
        var data: Dictionary = descriptor as Dictionary
        var button: Button = _WidgetFactory.create_button({})
        var text_value: Variant = data.get(StringName("text"), data.get(StringName("label"), ""))
        button.text = resolve_text(text_value)
        if data.has(StringName("tooltip")):
            button.tooltip_text = resolve_text(data[StringName("tooltip")])
        if data.has(StringName("icon")) and data[StringName("icon")] is Texture2D:
            button.icon = data[StringName("icon")]
        var event_id: StringName = data.get(StringName("event"), data.get(StringName("id"), StringName())) as StringName
        var payload: Dictionary = data.get(StringName("payload"), {}) as Dictionary
        if data.has(StringName("id")):
            button.name = String(event_id)
        button.pressed.connect(func():
            emit_template_event(event_id, payload)
        )
        return button
    var default_button: Button = _WidgetFactory.create_button({})
    default_button.text = resolve_text({StringName("text"): descriptor})
    return default_button
