class_name _DialogShell
extends "res://UI/Layouts/PanelShell.gd"

@export var title_label_path: NodePath = NodePath("Layout/HeaderSlot/TitleLabel")
@export var description_label_path: NodePath = NodePath("Layout/HeaderSlot/DescriptionLabel")
@export var action_bar_path: NodePath = NodePath("Layout/FooterSlot/ActionBar")

var _title_label: Label
var _description_label: Label
var _action_bar: BoxContainer

func _ready() -> void:
    super()
    _resolve_dialog_nodes()
    if _theme_service() == null:
        return
    _apply_dialog_theme()

func _on_theme_changed() -> void:
    super._on_theme_changed()
    _apply_dialog_theme()

## Set the dialog title text.
##
## [param text] Display text for the title label.
func set_title(text: String) -> void:
    if _title_label == null:
        return
    _title_label.text = text
    _title_label.visible = not text.is_empty()

## Set the dialog description text.
##
## [param text] Display text for the description label.
func set_description(text: String) -> void:
    if _description_label == null:
        return
    _description_label.text = text
    _description_label.visible = not text.is_empty()

## Replace footer actions with the provided controls.
##
## [param actions] Array of controls to arrange horizontally in the footer.
func set_actions(actions: Array[Control]) -> void:
    if _action_bar == null:
        return
    _clear_slot(_action_bar)
    for action in actions:
        if action == null:
            continue
        if action.get_parent():
            action.get_parent().remove_child(action)
        _action_bar.add_child(action)

## Append a single action control to the footer.
##
## [param action] Control to append to the action bar.
func add_action(action: Control) -> void:
    if _action_bar == null or action == null:
        return
    if action.get_parent():
        action.get_parent().remove_child(action)
    _action_bar.add_child(action)

## Remove all footer actions.
func clear_actions() -> void:
    _clear_slot(_action_bar)

func _resolve_dialog_nodes() -> void:
    _title_label = get_node_or_null(title_label_path) as Label
    _description_label = get_node_or_null(description_label_path) as Label
    _action_bar = get_node_or_null(action_bar_path) as BoxContainer
    if _action_bar:
        _action_bar.alignment = BoxContainer.ALIGNMENT_END
    if _title_label:
        _title_label.visible = not _title_label.text.is_empty()
    if _description_label:
        _description_label.visible = not _description_label.text.is_empty()

func _apply_dialog_theme() -> void:
    var theme_service := _theme_service()
    if theme_service == null or _action_bar == null:
        return
    var spacing := theme_service.get_spacing(StringName("sm"))
    _action_bar.add_theme_constant_override("separation", int(spacing))
*** End File
