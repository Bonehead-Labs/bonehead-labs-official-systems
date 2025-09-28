class_name DialogTemplateDemo
extends Control

## DialogTemplateDemo demonstrates the DialogTemplate system in action.
## This scene shows how to instantiate, populate, and interact with DialogTemplate.

const DIALOG_TEMPLATE: PackedScene = preload("res://UI/Templates/DialogTemplate.tscn")

const LOG_LIMIT: int = 6

@onready var _template_host: Control = %TemplateHost
@onready var _event_log: RichTextLabel = %EventLog
@onready var _refresh_button: Button = %RefreshButton

var _dialog: _DialogTemplate
var _log_lines: PackedStringArray = PackedStringArray()

func _ready() -> void:
	randomize()
	_refresh_button.pressed.connect(_on_refresh_requested)
	_spawn_template()
	_append_log("DialogTemplateDemo ready. Use buttons to emit events.")

func _exit_tree() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		if _dialog.template_event.is_connected(_on_template_event):
			_dialog.template_event.disconnect(_on_template_event)
		_dialog.queue_free()


func _spawn_template() -> void:
	if _template_host == null:
		return
	for child in _template_host.get_children():
		child.queue_free()
	_dialog = DIALOG_TEMPLATE.instantiate() as _DialogTemplate
	if _dialog == null:
		push_error("DialogTemplateDemo: unable to instantiate DialogTemplate.")
		return
	_dialog.template_id = StringName("dialog_template_demo")
	_dialog.template_event.connect(_on_template_event)
	_template_host.add_child(_dialog)
	_dialog.apply_content(_build_dialog_content())

func _build_dialog_content(tip_descriptor: Variant = null) -> Dictionary:
	var tip: Variant = tip_descriptor
	if tip == null:
		tip = _random_tip()
	var next_tip := _random_tip()
	return {
		StringName("title"): {
			StringName("fallback"): "Dialog Template"
		},
		StringName("description"): {
			StringName("fallback"): "This panel is populated via apply_content()."
		},
		StringName("content"): [
			{
				"type": "label",
				"text": {
					StringName("fallback"): "Design templates visually, then feed data dictionaries at runtime."
				}
			},
			{
				"type": "label",
				"text": tip
			}
		],
		StringName("actions"): [
			{
				"id": "accept",
				"text": {
					StringName("fallback"): "Accept"
				},
				"payload": {
					StringName("value"): 1
				}
			},
			{
				"id": "decline",
				"text": {
					StringName("fallback"): "Decline"
				},
				"payload": {
					StringName("value"): 0
				}
			},
			{
				"id": "refresh_tip",
				"text": {
					StringName("fallback"): "New Tip"
				},
				"payload": {
					StringName("tip"): next_tip
				}
			}
		]
	}

func _random_tip() -> Dictionary:
	var tips: Array = [
		{
			StringName("fallback"): "Templates emit template_event so screens can react to UI actions."
		},
		{
			StringName("fallback"): "Use WidgetFactory helpers inside templates for consistent theming."
		},
		{
			StringName("fallback"): "Apply ThemeLocalization tokens by passing dictionaries with token/fallback."
		}
	]
	var index := randi() % tips.size()
	return tips[index]

func _on_template_event(event_id: StringName, payload: Dictionary) -> void:
	_append_log("%s -> %s" % [String(event_id), JSON.stringify(payload)])
	match event_id:
		StringName("refresh_tip"):
			var tip_descriptor: Variant = payload.get(StringName("tip"), null)
			_dialog.apply_content(_build_dialog_content(tip_descriptor))
		_:
			pass

func _on_refresh_requested() -> void:
	if _dialog == null:
		return
	_dialog.apply_content(_build_dialog_content())
	_append_log("Content refreshed via outer button.")

func _append_log(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > LOG_LIMIT:
		_log_lines.remove_at(0)
	if _event_log != null:
		_event_log.text = "\n".join(_log_lines)
