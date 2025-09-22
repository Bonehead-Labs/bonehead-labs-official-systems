extends RefCounted

const AUTOLOAD_NAME: StringName = &"ThemeService"
const SCRIPT_PATH: String = "res://UI/Theme/ThemeService.gd"
const AUTOLOAD_SETTING: String = "autoload/%s" % AUTOLOAD_NAME

## Registers the ThemeService autoload in an idempotent fashion.
static func ensure_registered(save_settings: bool = true) -> void:
    if not Engine.is_editor_hint():
        return
    var existing := _get_current_entry()
    if existing.size() > 0 and existing.get("path", "") == SCRIPT_PATH:
        return
    ProjectSettings.set_setting(AUTOLOAD_SETTING, {"path": SCRIPT_PATH, "singleton": true})
    if save_settings:
        ProjectSettings.save()

## Removes the ThemeService autoload if it matches this module's script path.
static func ensure_removed(save_settings: bool = true) -> void:
    if not Engine.is_editor_hint():
        return
    var existing := _get_current_entry()
    if existing.size() > 0 and existing.get("path", "") != SCRIPT_PATH:
        return
    if ProjectSettings.has_setting(AUTOLOAD_SETTING):
        ProjectSettings.clear(AUTOLOAD_SETTING)
    if save_settings:
        ProjectSettings.save()

static func _get_current_entry() -> Dictionary:
    if not ProjectSettings.has_setting(AUTOLOAD_SETTING):
        return {}
    var value: Variant = ProjectSettings.get_setting(AUTOLOAD_SETTING)
    if typeof(value) == TYPE_DICTIONARY:
        return value as Dictionary
    return {}
