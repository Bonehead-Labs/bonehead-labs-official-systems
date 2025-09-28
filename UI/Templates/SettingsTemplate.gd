class_name _SettingsTemplate
extends _UITemplate

const KEY_TITLE: StringName = StringName("title")
const KEY_DESCRIPTION: StringName = StringName("description")
const KEY_SECTIONS: StringName = StringName("sections")
const KEY_ACTIONS: StringName = StringName("actions")

@export var title_label_path: NodePath = NodePath("Header/Title")
@export var description_label_path: NodePath = NodePath("Header/Description")
@export var sections_container_path: NodePath = NodePath("Sections/SectionList")
@export var footer_container_path: NodePath = NodePath("Footer/ActionBar")

var _title_label: Label
var _description_label: Label
var _sections_container: VBoxContainer
var _footer_container: Container

func _on_template_ready() -> void:
    _title_label = get_node_or_null(title_label_path) as Label
    _description_label = get_node_or_null(description_label_path) as Label
    _sections_container = get_node_or_null(sections_container_path) as VBoxContainer
    _footer_container = get_node_or_null(footer_container_path) as Container

func _apply_content(content: Dictionary) -> void:
    if _title_label != null and content.has(KEY_TITLE):
        _UITemplateDataBinder.apply_text(_title_label, content[KEY_TITLE], Callable(self, "resolve_text"))
    if _description_label != null and content.has(KEY_DESCRIPTION):
        _UITemplateDataBinder.apply_text(_description_label, content[KEY_DESCRIPTION], Callable(self, "resolve_text"))
    _populate_sections(content.get(KEY_SECTIONS, []))
    _populate_footer_actions(content.get(KEY_ACTIONS, []))

func _populate_sections(sections_variant: Variant) -> void:
    if _sections_container == null:
        return
    var section_entries: Array = []
    if sections_variant is Array:
        section_entries = sections_variant as Array
    _UITemplateDataBinder.populate_container(_sections_container, section_entries, Callable(self, "_create_section"))

func _create_section(config: Variant) -> Node:
    if not (config is Dictionary):
        return _WidgetFactory.create_vbox({})
    var data: Dictionary = config as Dictionary
    var container: VBoxContainer = _WidgetFactory.create_vbox({}) as VBoxContainer
    container.name = String(data.get(StringName("id"), "section"))

    if data.has(KEY_TITLE):
        var header_label: Label = _WidgetFactory.create_label({})
        header_label.add_theme_font_size_override(StringName("font_size"), 18)
        _UITemplateDataBinder.apply_text(header_label, data[KEY_TITLE], Callable(self, "resolve_text"))
        container.add_child(header_label)
    if data.has(KEY_DESCRIPTION):
        var description_label: Label = _WidgetFactory.create_label({})
        var description_text := data[KEY_DESCRIPTION]
        _UITemplateDataBinder.apply_text(description_label, description_text, Callable(self, "resolve_text"))
        description_label.add_theme_color_override(StringName("font_color"), _muted_color())
        container.add_child(description_label)

    var controls_variant: Variant = data.get(StringName("controls"), [])
    if controls_variant is Array:
        for control_data in controls_variant:
            container.add_child(_create_control(control_data))
    return container

func _create_control(config: Variant) -> Control:
    if config is Dictionary:
        var data: Dictionary = config as Dictionary
        var control_type: StringName = data.get(StringName("type"), StringName("label")) as StringName
        var control: Control
        match control_type:
            StringName("toggle"):
                control = _create_toggle(data)
            StringName("slider"):
                control = _create_slider(data)
            StringName("button"):
                control = _create_button(data)
            StringName("label"):
                control = _create_label_control(data)
            StringName("scene"):
                control = _create_scene_control(data)
            _:
                control = _create_label_control({StringName("text"): data})
        var identifier: StringName = data.get(StringName("id"), StringName()) as StringName
        if control != null and identifier != StringName():
            control.name = String(identifier)
        return control
    elif config is Control:
        return config
    return _create_label_control({StringName("text"): config})

func _create_toggle(data: Dictionary) -> Control:
    var toggle: CheckButton = _WidgetFactory.create_toggle({})
    _UITemplateDataBinder.apply_text(toggle, data.get(StringName("text"), data.get(StringName("label"), "")), Callable(self, "resolve_text"))
    _UITemplateDataBinder.apply_toggle_state(toggle, data.get(StringName("value"), data.get(StringName("state"), false)))
    var event_id: StringName = data.get(StringName("event"), data.get(StringName("id"), StringName())) as StringName
    var payload: Dictionary = data.get(StringName("payload"), {}) as Dictionary
    toggle.toggled.connect(func(pressed: bool):
        var enriched: Dictionary = payload.duplicate(true)
        enriched[StringName("value")] = pressed
        emit_template_event(event_id, enriched)
    )
    return toggle

func _create_slider(data: Dictionary) -> Control:
    var slider: HSlider = _WidgetFactory.create_slider({})
    var slider_config: Dictionary = {
        StringName("min"): data.get(StringName("min"), 0.0),
        StringName("max"): data.get(StringName("max"), 1.0),
        StringName("step"): data.get(StringName("step"), 0.01),
        StringName("value"): data.get(StringName("value"), 0.5)
    }
    _UITemplateDataBinder.apply_slider_value(slider, slider_config)
    var label_text: Variant = data.get(StringName("text"), data.get(StringName("label"), ""))
    if label_text != "":
        slider.tooltip_text = resolve_text(label_text)
    var event_id: StringName = data.get(StringName("event"), data.get(StringName("id"), StringName("value_changed"))) as StringName
    var payload: Dictionary = data.get(StringName("payload"), {}) as Dictionary
    slider.value_changed.connect(func(value: float):
        var enriched: Dictionary = payload.duplicate(true)
        enriched[StringName("value")] = value
        emit_template_event(event_id, enriched)
    )
    return slider

func _create_button(data: Dictionary) -> Control:
    var button: Button = _WidgetFactory.create_button({})
    _UITemplateDataBinder.apply_text(button, data.get(StringName("text"), data.get(StringName("label"), "")), Callable(self, "resolve_text"))
    var event_id: StringName = data.get(StringName("event"), data.get(StringName("id"), StringName())) as StringName
    var payload: Dictionary = data.get(StringName("payload"), {}) as Dictionary
    button.pressed.connect(func():
        emit_template_event(event_id, payload)
    )
    return button

func _create_label_control(data: Dictionary) -> Control:
    var label: Label = _WidgetFactory.create_label({})
    _UITemplateDataBinder.apply_text(label, data.get(StringName("text"), data.get(StringName("value"), "")), Callable(self, "resolve_text"))
    return label

func _create_scene_control(data: Dictionary) -> Control:
    var scene_path: String = String(data.get(StringName("path"), ""))
    if scene_path.is_empty() or not ResourceLoader.exists(scene_path, "PackedScene"):
        push_warning("SettingsTemplate: control scene '%s' not found" % scene_path)
        return _create_label_control({StringName("text"): "Missing control"})
    var scene: PackedScene = ResourceLoader.load(scene_path) as PackedScene
    if scene == null:
        return _create_label_control({StringName("text"): "Invalid control"})
    var instance: Node = scene.instantiate()
    if instance is Control:
        return instance as Control
    instance.queue_free()
    return _create_label_control({StringName("text"): "Invalid control"})

func _populate_footer_actions(actions_variant: Variant) -> void:
    if _footer_container == null:
        return
    var action_entries: Array = []
    if actions_variant is Array:
        action_entries = actions_variant as Array
    _UITemplateDataBinder.populate_container(_footer_container, action_entries, Callable(self, "_create_button"))

func _muted_color() -> Color:
    if _theme_service != null:
        return _theme_service.get_color(StringName("text_muted"))
    return Color(0.7, 0.7, 0.7)
