class_name _UITemplateDataBinder
extends RefCounted

## UITemplateDataBinder applies lightweight bindings between dictionaries and nodes.
##
## Templates call these helpers to focus on content rather than manual property
## assignments. All helpers perform type checks and fail gracefully to reduce
## runtime noise during authoring.

static func apply_text(target: Label, descriptor: Variant, resolver: Callable) -> void:
    if target == null:
        return
    var text: String = _resolve_text(descriptor, resolver)
    target.text = text
    target.visible = not text.is_empty()

static func apply_rich_text(target: RichTextLabel, descriptor: Variant, resolver: Callable) -> void:
    if target == null:
        return
    var text: String = _resolve_text(descriptor, resolver)
    target.text = text
    target.visible = not text.is_empty()

static func apply_toggle_state(target: CheckButton, descriptor: Variant) -> void:
    if target == null:
        return
    if descriptor is bool:
        target.button_pressed = descriptor

static func apply_slider_value(target: Range, descriptor: Dictionary) -> void:
    if target == null or descriptor == null:
        return
    if descriptor.has(StringName("min")):
        target.min_value = float(descriptor[StringName("min")])
    if descriptor.has(StringName("max")):
        target.max_value = float(descriptor[StringName("max")])
    if descriptor.has(StringName("step")):
        target.step = float(descriptor[StringName("step")])
    if descriptor.has(StringName("value")):
        target.value = float(descriptor[StringName("value")])

static func apply_texture(target: TextureRect, descriptor: Variant) -> void:
    if target == null:
        return
    if descriptor is Texture2D:
        target.texture = descriptor
        return
    if descriptor is String and descriptor != "":
        if ResourceLoader.exists(descriptor, "Texture2D"):
            var resource: Resource = ResourceLoader.load(descriptor)
            if resource is Texture2D:
                target.texture = resource

static func apply_progress(target: ProgressBar, descriptor: Dictionary) -> void:
    if target == null or descriptor == null:
        return
    if descriptor.has(StringName("value")):
        target.value = float(descriptor[StringName("value")])
    if descriptor.has(StringName("max")):
        target.max_value = float(descriptor[StringName("max")])
    if descriptor.has(StringName("text")):
        target.tooltip_text = String(descriptor[StringName("text")])
    target.visible = true

static func populate_container(container: Node, entries: Array, factory: Callable) -> void:
    if container == null or factory == null or not factory.is_valid():
        return
    if container is Container or container is Control or container is Node:
        for child in container.get_children():
            child.queue_free()
    if entries == null:
        return
    for entry in entries:
        var node: Variant = factory.call(entry)
        if node == null:
            continue
        if node is Node:
            (container as Node).add_child(node)

static func _resolve_text(descriptor: Variant, resolver: Callable) -> String:
    if descriptor is String:
        return descriptor
    if descriptor is StringName:
        return String(descriptor)
    if descriptor is int or descriptor is float:
        return str(descriptor)
    if descriptor is Dictionary and resolver != null and resolver.is_valid():
        return String(resolver.call(descriptor))
    if resolver != null and resolver.is_valid():
        return String(resolver.call({"text": descriptor}))
    return ""
