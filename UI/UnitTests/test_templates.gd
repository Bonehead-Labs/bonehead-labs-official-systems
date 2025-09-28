extends "res://addons/gut/test.gd"

const DialogTemplatePath: String = "res://UI/Templates/DialogTemplate.tscn"
const ThemeServicePath: String = "res://UI/Theme/ThemeService.gd"
const ThemeLocalizationPath: String = "res://UI/Theme/LocalizationHelper.gd"

var theme_service: _ThemeService
var theme_localization: _ThemeLocalization
var captured_events: Array[Dictionary] = []

func before_each() -> void:
    captured_events.clear()
    await _install_theme_dependencies()

func after_each() -> void:
    if is_instance_valid(theme_service):
        theme_service.queue_free()
        await get_tree().process_frame
    if is_instance_valid(theme_localization):
        theme_localization.queue_free()
        await get_tree().process_frame

func test_dialog_template_binds_content_and_emits_events() -> void:
    var dialog_scene: PackedScene = load(DialogTemplatePath)
    var dialog: _DialogTemplate = dialog_scene.instantiate() as _DialogTemplate
    dialog.name = "TestDialog"
    get_tree().root.add_child(dialog)
    await dialog.ready

    var content: Dictionary = _build_dialog_content()
    dialog.template_event.connect(_on_template_event)
    dialog.apply_content(content)

    var title_label: Label = dialog.get_node("Header/Title") as Label
    assert_eq(title_label.text, "Demo Dialog")

    var body_container: VBoxContainer = dialog.get_node("Body") as VBoxContainer
    assert_gt(body_container.get_child_count(), 0)

    var confirm_button: Button = dialog.get_node("Footer/ActionBar/confirm") as Button
    var cancel_button: Button = dialog.get_node("Footer/ActionBar/cancel") as Button
    confirm_button.emit_signal("pressed")
    cancel_button.emit_signal("pressed")

    assert_eq(captured_events.size(), 2)
    assert_eq(captured_events[0].get("id"), StringName("confirm"))
    assert_eq(captured_events[1].get("id"), StringName("cancel"))

    dialog.queue_free()
    await get_tree().process_frame

func test_data_binder_applies_text_and_populates_container() -> void:
    var label := Label.new()
    var descriptor := {
        StringName("token"): StringName("demo/token"),
        StringName("fallback"): "Fallback"
    }
    _UITemplateDataBinder.apply_text(label, descriptor, Callable(self, "_resolve_descriptor"))
    assert_eq(label.text, "resolved:demo/token")

    var container := VBoxContainer.new()
    _UITemplateDataBinder.populate_container(container, [1, 2, 3], Callable(self, "_spawn_label"))
    assert_eq(container.get_child_count(), 3)
    assert_eq((container.get_child(0) as Label).text, "1")

func _install_theme_dependencies() -> void:
    theme_service = load(ThemeServicePath).new()
    theme_service.name = "ThemeService"
    get_tree().root.add_child(theme_service)
    await theme_service.ready

    theme_localization = load(ThemeLocalizationPath).new()
    theme_localization.name = "ThemeLocalization"
    get_tree().root.add_child(theme_localization)
    await get_tree().process_frame

func _build_dialog_content() -> Dictionary:
    return {
        StringName("title"): {
            StringName("fallback"): "Demo Dialog"
        },
        StringName("description"): {
            StringName("fallback"): "Testing dialog template."
        },
        StringName("content"): [
            {
                "type": "label",
                "text": {
                    "fallback": "Primary body copy"
                }
            }
        ],
        StringName("actions"): [
            {
                "id": "confirm",
                "text": {
                    "fallback": "Confirm"
                }
            },
            {
                "id": "cancel",
                "text": {
                    "fallback": "Cancel"
                }
            }
        ]
    }

func _on_template_event(event_id: StringName, payload: Dictionary) -> void:
    captured_events.append({
        "id": event_id,
        "payload": payload.duplicate(true)
    })

func _resolve_descriptor(descriptor: Variant) -> String:
    if descriptor is Dictionary and descriptor.has(StringName("token")):
        return "resolved:%s" % descriptor[StringName("token")]
    if descriptor is Dictionary and descriptor.has(StringName("text")):
        return String(descriptor[StringName("text")])
    return String(descriptor)

func _spawn_label(entry: Variant) -> Node:
    var label := Label.new()
    label.text = String(entry)
    return label
