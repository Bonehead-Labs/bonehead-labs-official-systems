extends RefCounted

const AUTOLOAD_NAME: StringName = &"FlowManager"
const SCRIPT_PATH: String = "res://SceneFlow/FlowManager.gd"
const AUTOLOAD_SETTING: String = "autoload/%s" % AUTOLOAD_NAME

## Registers the FlowManager autoload in an idempotent fashion.
static func ensure_registered(save_settings: bool = true) -> void:
	if not Engine.is_editor_hint():
		return
	var existing := _get_current_entry()
	if existing and existing.get("path", "") == SCRIPT_PATH:
		return
	ProjectSettings.set_setting(AUTOLOAD_SETTING, {"path": SCRIPT_PATH, "singleton": true})
	if save_settings:
		ProjectSettings.save()

## Removes the FlowManager autoload if it matches this module's script path.
static func ensure_removed(save_settings: bool = true) -> void:
	if not Engine.is_editor_hint():
		return
	var existing := _get_current_entry()
	if existing and existing.get("path", "") != SCRIPT_PATH:
		return
	if ProjectSettings.has_setting(AUTOLOAD_SETTING):
		ProjectSettings.clear(AUTOLOAD_SETTING)
	if save_settings:
		ProjectSettings.save()

static func _get_current_entry() -> Dictionary:
	if ProjectSettings.has_setting(AUTOLOAD_SETTING):
		var value := ProjectSettings.get_setting(AUTOLOAD_SETTING)
		return value if typeof(value) == TYPE_DICTIONARY else {}
	return {}
