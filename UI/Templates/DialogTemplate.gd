class_name _DialogTemplate
extends _UITemplate

const BODY_KEY_TITLE: StringName = StringName("title")
const BODY_KEY_DESCRIPTION: StringName = StringName("description")
const BODY_KEY_CONTENT: StringName = StringName("content")
const BODY_KEY_ACTIONS: StringName = StringName("actions")

@export var title_label_path: NodePath = NodePath("Layout/Header/Title")
@export var description_label_path: NodePath = NodePath("Layout/Header/Description")
@export var body_container_path: NodePath = NodePath("Layout/Body")
@export var action_bar_path: NodePath = NodePath("Layout/Footer/ActionBar")

var _title_label: Label
var _description_label: Label
var _body_container: Control
var _action_bar: Container

func _on_template_ready() -> void:
	_cache_references()

func _apply_content(content: Dictionary) -> void:
	if _title_label != null and content.has(BODY_KEY_TITLE):
		_UITemplateDataBinder.apply_text(_title_label, content[BODY_KEY_TITLE], Callable(self, "resolve_text"))
	if _description_label != null and content.has(BODY_KEY_DESCRIPTION):
		_UITemplateDataBinder.apply_text(_description_label, content[BODY_KEY_DESCRIPTION], Callable(self, "resolve_text"))
	_apply_body(content.get(BODY_KEY_CONTENT, []))
	_apply_actions(content.get(BODY_KEY_ACTIONS, []))

func _apply_body(content_entries: Variant) -> void:
	if _body_container == null:
		return
	var entries: Array = []
	if content_entries is Array:
		entries = content_entries as Array
	_UITemplateDataBinder.populate_container(_body_container, entries, Callable(self, "_create_body_entry"))

func _create_body_entry(entry: Variant) -> Node:
	if entry is Control:
		return entry
	if entry is Dictionary:
		var data: Dictionary = entry as Dictionary
		var entry_type: StringName = data.get(StringName("type"), StringName("label")) as StringName
		match entry_type:
			StringName("label"):
				return _build_label_entry(data)
			StringName("rich_text"):
				return _build_rich_text_entry(data)
			StringName("scene"):
				return _build_scene_entry(data)
	if entry is String:
		return _build_label_entry({StringName("text"): entry})
	return _WidgetFactory.create_vbox({})

func _build_label_entry(data: Dictionary) -> Control:
	var label: Label = _WidgetFactory.create_label({})
	_UITemplateDataBinder.apply_text(label, data.get(StringName("text"), data.get(StringName("value"), "")), Callable(self, "resolve_text"))
	return label

func _build_rich_text_entry(data: Dictionary) -> Control:
	var rich_text: RichTextLabel = RichTextLabel.new()
	rich_text.fit_content = false
	rich_text.scroll_active = false
	_UITemplateDataBinder.apply_rich_text(rich_text, data.get(StringName("text"), ""), Callable(self, "resolve_text"))
	return rich_text

func _build_scene_entry(data: Dictionary) -> Control:
	var scene_path: String = String(data.get(StringName("path"), ""))
	if scene_path.is_empty():
		return _WidgetFactory.create_vbox({})
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_warning("DialogTemplate: content scene '%s' not found" % scene_path)
		return _WidgetFactory.create_vbox({})
	var scene: PackedScene = ResourceLoader.load(scene_path) as PackedScene
	if scene == null:
		return _WidgetFactory.create_vbox({})
	var instance: Node = scene.instantiate()
	if instance is Control:
		return instance as Control
	instance.queue_free()
	return _WidgetFactory.create_vbox({})

func _apply_actions(actions_variant: Variant) -> void:
	if _action_bar == null:
		return
	var actions: Array = []
	if actions_variant is Array:
		actions = actions_variant as Array
	_UITemplateDataBinder.populate_container(_action_bar, actions, Callable(self, "_create_action_button"))

func _create_action_button(data: Variant) -> Node:
	if not (data is Dictionary):
		return _WidgetFactory.create_button({"text": String(data)})
	var action: Dictionary = data as Dictionary
	var button: Button = _WidgetFactory.create_button({})
	var text_descriptor: Variant = action.get(StringName("text"), action.get(StringName("label"), ""))
	var text: String = _resolve_text_descriptor(text_descriptor)
	button.text = text
	var action_id: StringName = action.get(StringName("id"), StringName()) as StringName
	if action_id == StringName():
		action_id = StringName(button.name)
	else:
		button.name = String(action_id)
	var payload: Dictionary = action.get(StringName("payload"), {}) as Dictionary
	if action.has(StringName("tooltip")):
		button.tooltip_text = String(resolve_text(action[StringName("tooltip")]))
	if action.get(StringName("kind"), StringName()) == StringName("primary"):
		button.add_theme_color_override(StringName("font_color"), _primary_color())
	button.pressed.connect(func():
		emit_template_event(action_id, payload)
		if action.has(StringName("topic")) and action[StringName("topic")] is StringName:
			publish_event(action[StringName("topic")], payload)
	)
	return button

func _primary_color() -> Color:
	if _theme_service != null:
		return _theme_service.get_color(StringName("accent"))
	return Color.WHITE

func _resolve_text_descriptor(descriptor: Variant) -> String:
	if descriptor is String:
		return descriptor
	if descriptor is StringName:
		return String(descriptor)
	if descriptor is int or descriptor is float:
		return str(descriptor)
	if descriptor is Dictionary:
		return String(resolve_text(descriptor))
	return String(resolve_text({"text": descriptor}))

func _cache_references() -> void:
	_title_label = get_node_or_null(title_label_path) as Label
	_description_label = get_node_or_null(description_label_path) as Label
	_body_container = get_node_or_null(body_container_path) as Control
	_action_bar = get_node_or_null(action_bar_path) as Container
